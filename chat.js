(() => {
  // ===== 設定 =====
  const RENDER_WS_URL = 'wss://YOUR-APP-NAME.onrender.com';
  const WS_URL = (location.hostname === 'localhost' || location.hostname === '127.0.0.1')
    ? `ws://${location.host}` : https://chat-server-isoe.onrender.com;

  // ===== 状態 =====
  let ws = null;
  let myUsername = '';
  let currentRoom = { code: null, name: '', icon: '💬' };
  let replyTarget = null;   // { id, username, text }
  let editTarget = null;    // { id, text }
  let ctxTarget = null;     // { msgId, isSelf, text }
  let joinedRooms = [];     // [{ code, name, icon }]
  let selectedEmoji = '💬';
  const readObserver = new IntersectionObserver(onVisible, { threshold: 0.5 });

  // ===== DOM =====
  const $ = id => document.getElementById(id);
  const screens = ['screen-login','screen-home','screen-create','screen-join','screen-chat'];

  function showScreen(id) {
    screens.forEach(s => $(s).classList.add('hidden'));
    $(id).classList.remove('hidden');
  }
  window.showScreen = showScreen;

  // ===== ローカルストレージ（ログイン保持） =====
  function loadSaved() {
    const s = localStorage.getItem('chat_session');
    return s ? JSON.parse(s) : null;
  }
  function saveSession(username, password) {
    localStorage.setItem('chat_session', JSON.stringify({ username, password }));
  }
  function clearSession() { localStorage.removeItem('chat_session'); }

  // ===== WebSocket 接続 =====
  function connect(onOpen) {
    if (ws && ws.readyState !== WebSocket.CLOSED) { onOpen(); return; }
    ws = new WebSocket(WS_URL);
    ws.addEventListener('open', onOpen);
    ws.addEventListener('message', e => { try { handle(JSON.parse(e.data)); } catch {} });
    ws.addEventListener('close', () => showBanner('接続が切れました。再読み込みしてください。'));
    ws.addEventListener('error', () => {
      $('auth-error').textContent = 'サーバーに接続できません';
    });
  }

  function wsSend(obj) {
    if (ws && ws.readyState === WebSocket.OPEN) ws.send(JSON.stringify(obj));
  }

  // ===== メッセージハンドラ =====
  function handle(data) {
    switch (data.type) {
      case 'authOk':    onAuthOk(data); break;
      case 'authError': $('auth-error').textContent = data.text; break;
      case 'roomCreated': onRoomCreated(data); break;
      case 'roomJoined':  onRoomJoined(data); break;
      case 'roomError':
        $('create-error').textContent = data.text;
        $('join-error').textContent = data.text;
        break;
      case 'history':         onHistory(data.messages); break;
      case 'message':         renderMessage(data); scrollBottom(); break;
      case 'system':          renderSystem(data.text); if (data.count !== undefined) $('online-count').textContent = data.count; scrollBottom(); break;
      case 'messageEdited':   onEdited(data); break;
      case 'messageRecalled': onRecalled(data); break;
      case 'readUpdate':      onReadUpdate(data); break;
      case 'error':           showBanner(data.text); break;
    }
  }

  // ===== 認証 =====
  let currentTab = 'login';
  window.switchTab = function(tab) {
    currentTab = tab;
    $('tab-login').classList.toggle('active', tab === 'login');
    $('tab-register').classList.toggle('active', tab === 'register');
    $('auth-btn').textContent = tab === 'login' ? 'ログイン' : '新規登録';
    $('auth-error').textContent = '';
  };

  window.doAuth = function() {
    const username = $('auth-username').value.trim();
    const password = $('auth-password').value;
    $('auth-error').textContent = '';
    if (!username || !password) { $('auth-error').textContent = 'すべて入力してください'; return; }
    connect(() => {
      wsSend({ type: 'auth', username, password, isRegister: currentTab === 'register' });
      if ($('remember-me').checked) saveSession(username, password);
    });
  };

  function onAuthOk(data) {
    myUsername = data.username;
    joinedRooms = data.joinedRooms || [];
    $('home-username').textContent = myUsername;
    renderRoomList();
    showScreen('screen-home');
  }

  window.doLogout = function() {
    clearSession();
    myUsername = '';
    joinedRooms = [];
    currentRoom = { code: null, name: '', icon: '💬' };
    if (ws) { ws.close(); ws = null; }
    showScreen('screen-login');
  };

  // ===== ルーム一覧 =====
  function renderRoomList() {
    const list = $('room-list');
    if (!joinedRooms.length) { list.innerHTML = '<p class="empty-msg">まだルームがありません</p>'; return; }
    list.innerHTML = '';
    joinedRooms.forEach(r => {
      const div = document.createElement('div');
      div.className = 'room-item';
      div.innerHTML = `<div class="room-icon-circle">${r.icon}</div><span class="room-item-name">${esc(r.name)}</span><span class="room-item-arrow">›</span>`;
      div.onclick = () => enterRoom(r.code, r.name, r.icon);
      list.appendChild(div);
    });
  }

  // ===== ルーム作成 =====
  const EMOJIS = ['💬','🎉','🎮','📚','🎵','🏆','🌟','🔥','💡','🎨','🏠','🌈','🐱','🐶','🍕','☕','✈️','💪','🎯','🤝','🌸','🦁','🦋','🌺','🎸','🎲','🧩','🚀','💎','🌙'];

  function initEmojiGrid() {
    const grid = $('emoji-grid');
    grid.innerHTML = '';
    EMOJIS.forEach(e => {
      const btn = document.createElement('button');
      btn.className = 'emoji-btn' + (e === selectedEmoji ? ' selected' : '');
      btn.textContent = e;
      btn.type = 'button';
      btn.onclick = () => {
        selectedEmoji = e;
        document.querySelectorAll('.emoji-btn').forEach(b => b.classList.remove('selected'));
        btn.classList.add('selected');
        $('icon-preview').textContent = e;
      };
      grid.appendChild(btn);
    });
  }

  window.updatePreview = function() {
    const name = $('create-name').value || 'ルーム名';
    $('icon-preview-name').textContent = name;
    $('icon-preview').textContent = selectedEmoji;
  };

  window.doCreateRoom = function() {
    const name = $('create-name').value.trim();
    const password = $('create-password').value;
    $('create-error').textContent = '';
    if (!name) { $('create-error').textContent = 'ルーム名を入力してください'; return; }
    wsSend({ type: 'createRoom', name, icon: selectedEmoji, password });
  };

  function onRoomCreated(data) {
    joinedRooms.push({ code: data.code, name: data.name, icon: data.icon });
    renderRoomList();
    alert(`ルームを作成しました！\nルームコード: ${data.code}`);
    showScreen('screen-home');
    $('create-name').value = '';
    $('create-password').value = '';
  }

  // ===== ルーム参加 =====
  window.doJoinRoom = function() {
    const code = $('join-code').value.trim().toUpperCase();
    const password = $('join-password').value;
    $('join-error').textContent = '';
    if (!code) { $('join-error').textContent = 'ルームコードを入力してください'; return; }
    wsSend({ type: 'joinRoom', code, password });
  };

  function onRoomJoined(data) {
    if (!joinedRooms.find(r => r.code === data.code)) {
      joinedRooms.push({ code: data.code, name: data.name, icon: data.icon });
    }
    renderRoomList();
    showScreen('screen-home');
    $('join-code').value = '';
    $('join-password').value = '';
    enterRoom(data.code, data.name, data.icon);
  }

  // ===== チャット入室 =====
  function enterRoom(code, name, icon) {
    currentRoom = { code, name, icon };
    $('chat-room-icon').textContent = icon;
    $('chat-room-name').textContent = name;
    $('message-list').innerHTML = '';
    cancelReply();
    cancelEdit();
    wsSend({ type: 'enterRoom', code });
    showScreen('screen-chat');
  }

  window.leaveRoom = function() {
    currentRoom = { code: null };
    showScreen('screen-home');
  };

  // ===== 履歴 =====
  function onHistory(messages) {
    messages.forEach(m => renderMessage(m, true));
    scrollBottom();
  }

  // ===== メッセージ描画 =====
  function renderMessage(data, isHistory = false) {
    if (!data || !data.id) return;
    const isSelf = data.username === myUsername;
    const row = document.createElement('div');
    row.className = `msg-row ${isSelf ? 'self' : 'other'}`;
    row.dataset.msgId = data.id;
    row.dataset.username = data.username;
    row.dataset.text = data.text || '';

    // アバター（他人）
    if (!isSelf) {
      const av = document.createElement('div');
      av.className = 'msg-avatar';
      av.textContent = data.username.charAt(0);
      row.appendChild(av);
    }

    const group = document.createElement('div');
    group.className = 'msg-group';

    // ユーザー名（他人）
    if (!isSelf) {
      const un = document.createElement('div');
      un.className = 'msg-username';
      un.textContent = data.username;
      group.appendChild(un);
    }

    // 返信引用
    if (data.replyTo) {
      const q = document.createElement('div');
      q.className = 'reply-quote';
      q.innerHTML = `<span class="reply-quote-name">${esc(data.replyTo.username)}</span>${esc(data.replyTo.text)}`;
      group.appendChild(q);
    }

    // バブル
    const bubble = document.createElement('div');
    bubble.className = 'msg-bubble';
    if (data.recalled) {
      bubble.classList.add('recalled');
      bubble.textContent = `${data.username} がメッセージを取り消しました`;
    } else {
      bubble.textContent = data.text;
    }
    group.appendChild(bubble);

    // 編集済みラベル
    if (data.edited && !data.recalled) {
      const el = document.createElement('span');
      el.className = 'edited-label';
      el.textContent = '編集済み';
      el.title = '編集前の内容を見る';
      el.onclick = () => openHistoryModal(data.editHistory || []);
      group.appendChild(el);
    }

    // 時刻 + 既読
    const meta = document.createElement('div');
    meta.className = 'msg-meta';
    meta.style.cssText = 'display:flex;align-items:center;gap:4px;' + (isSelf ? 'justify-content:flex-end;' : '');
    const timeEl = document.createElement('span');
    timeEl.className = 'msg-time';
    timeEl.textContent = data.time || '';
    meta.appendChild(timeEl);

    // 既読表示
    const readEl = document.createElement('span');
    readEl.className = 'read-badge';
    readEl.dataset.msgId = data.id;
    const readBy = Array.isArray(data.readBy) ? data.readBy : [];
    updateReadBadge(readEl, readBy, myUsername);
    meta.appendChild(readEl);
    group.appendChild(meta);

    // ···ボタン
    if (!data.recalled) {
      const actBtn = document.createElement('button');
      actBtn.className = 'msg-actions-btn';
      actBtn.textContent = '···';
      actBtn.title = 'アクション';
      actBtn.onclick = (e) => { e.stopPropagation(); openCtxMenu(e, data.id, isSelf, data.text); };
      row.appendChild(actBtn);
    }

    row.appendChild(group);
    $('message-list').appendChild(row);

    // 既読オブザーバーに登録（自分のメッセージ以外、取り消されてないもの）
    if (!isSelf && !data.recalled) readObserver.observe(row);
  }

  // 既読バッジ更新
  function updateReadBadge(el, readBy, self) {
    const others = readBy.filter(u => u !== self);
    if (others.length === 0) { el.textContent = ''; el.style.cursor = 'default'; return; }
    el.textContent = `既読 ${others.length}`;
    el.style.cssText = 'font-size:.62rem;color:#aaa;cursor:pointer;text-decoration:underline dotted;';
    el.onclick = (e) => { e.stopPropagation(); showReadersTooltip(e, others); };
  }

  // 既読者ツールチップ
  let tooltipEl = null;
  function showReadersTooltip(e, readers) {
    if (tooltipEl) tooltipEl.remove();
    tooltipEl = document.createElement('div');
    tooltipEl.style.cssText = 'position:fixed;background:#333;color:#fff;font-size:.75rem;border-radius:8px;padding:6px 10px;z-index:9999;pointer-events:none;line-height:1.6;max-width:200px;';
    tooltipEl.innerHTML = '<strong>既読</strong><br>' + readers.map(esc).join('<br>');
    document.body.appendChild(tooltipEl);
    const rect = e.target.getBoundingClientRect();
    tooltipEl.style.left = Math.min(rect.left, window.innerWidth - 210) + 'px';
    tooltipEl.style.top = (rect.top - tooltipEl.offsetHeight - 8) + 'px';
    setTimeout(() => { document.addEventListener('click', removeTooltip, { once: true }); }, 50);
  }
  function removeTooltip() { if (tooltipEl) { tooltipEl.remove(); tooltipEl = null; } }

  // 既読イベント（IntersectionObserver）
  function onVisible(entries) {
    entries.forEach(entry => {
      if (!entry.isIntersecting) return;
      const row = entry.target;
      const msgId = row.dataset.msgId;
      if (!msgId || !currentRoom.code) return;
      wsSend({ type: 'readMessage', msgId });
      readObserver.unobserve(row);
    });
  }

  // 既読更新受信
  function onReadUpdate(data) {
    const badge = document.querySelector(`.read-badge[data-msg-id="${data.msgId}"]`);
    if (!badge) return;
    updateReadBadge(badge, data.readBy, myUsername);
  }

  // ===== システムメッセージ =====
  function renderSystem(text) {
    const el = document.createElement('div');
    el.className = 'msg-system';
    el.textContent = text;
    $('message-list').appendChild(el);
  }

  // ===== コンテキストメニュー =====
  function openCtxMenu(e, msgId, isSelf, text) {
    ctxTarget = { msgId, isSelf, text };
    const menu = $('ctx-menu');
    menu.classList.remove('hidden');
    // 自分のメッセージだけ編集・取り消しを表示
    document.querySelectorAll('.ctx-own').forEach(el => {
      el.style.display = isSelf ? '' : 'none';
    });
    // 画面端に収まるよう位置調整
    const x = Math.min(e.clientX, window.innerWidth - 170);
    const y = Math.min(e.clientY, window.innerHeight - 180);
    menu.style.left = x + 'px';
    menu.style.top = y + 'px';
    setTimeout(() => document.addEventListener('click', closeCtxMenu, { once: true }), 50);
  }

  function closeCtxMenu() { $('ctx-menu').classList.add('hidden'); }

  window.ctxAction = function(action) {
    if (!ctxTarget) return;
    closeCtxMenu();
    if (action === 'reply') {
      const row = document.querySelector(`.msg-row[data-msg-id="${ctxTarget.msgId}"]`);
      const username = row ? row.dataset.username : '?';
      setReply({ id: ctxTarget.msgId, username, text: ctxTarget.text });
    } else if (action === 'copy') {
      navigator.clipboard.writeText(ctxTarget.text).then(() => showToast('コピーしました'));
    } else if (action === 'edit') {
      const row = document.querySelector(`.msg-row[data-msg-id="${ctxTarget.msgId}"]`);
      setEdit(ctxTarget.msgId, ctxTarget.text);
    } else if (action === 'recall') {
      if (confirm('このメッセージを取り消しますか？')) {
        wsSend({ type: 'recallMessage', msgId: ctxTarget.msgId });
      }
    }
  };

  // ===== 返信 =====
  function setReply(target) {
    cancelEdit();
    replyTarget = target;
    $('reply-bar').classList.remove('hidden');
    $('reply-bar-text').textContent = `${target.username}: ${target.text}`;
    $('message-input').focus();
  }
  window.cancelReply = function() {
    replyTarget = null;
    $('reply-bar').classList.add('hidden');
  };

  // ===== 編集 =====
  function setEdit(msgId, text) {
    cancelReply();
    editTarget = { msgId, text };
    $('edit-bar').classList.remove('hidden');
    $('edit-bar-text').textContent = text;
    $('message-input').value = text;
    $('message-input').focus();
  }
  window.cancelEdit = function() {
    editTarget = null;
    $('edit-bar').classList.add('hidden');
    $('message-input').value = '';
  };

  // ===== メッセージ送信 =====
  window.sendMessage = function() {
    const text = $('message-input').value.trim();
    if (!text || !currentRoom.code) return;

    if (editTarget) {
      wsSend({ type: 'editMessage', msgId: editTarget.msgId, newText: text });
      cancelEdit();
    } else {
      wsSend({ type: 'message', text, replyTo: replyTarget });
      cancelReply();
      $('message-input').value = '';
    }
    $('message-input').focus();
  };

  $('message-input').addEventListener('keydown', e => {
    if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); sendMessage(); }
  });

  // ===== 編集受信 =====
  function onEdited(data) {
    const row = document.querySelector(`.msg-row[data-msg-id="${data.msgId}"]`);
    if (!row) return;
    row.dataset.text = data.newText;
    const bubble = row.querySelector('.msg-bubble');
    if (bubble) bubble.textContent = data.newText;
    // 編集済みラベル
    let el = row.querySelector('.edited-label');
    if (!el) {
      el = document.createElement('span');
      el.className = 'edited-label';
      el.textContent = '編集済み';
      el.title = '編集前の内容を見る';
      const meta = row.querySelector('.msg-meta');
      if (meta) meta.parentNode.insertBefore(el, meta);
    }
    el.onclick = () => openHistoryModal(data.editHistory || []);
  }

  // ===== 取り消し受信 =====
  function onRecalled(data) {
    const row = document.querySelector(`.msg-row[data-msg-id="${data.msgId}"]`);
    if (!row) return;
    const bubble = row.querySelector('.msg-bubble');
    if (bubble) {
      bubble.classList.add('recalled');
      bubble.textContent = `${data.username} がメッセージを取り消しました`;
    }
    const actBtn = row.querySelector('.msg-actions-btn');
    if (actBtn) actBtn.remove();
    readObserver.unobserve(row);
  }

  // ===== 編集履歴モーダル =====
  window.openHistoryModal = function(history) {
    const list = $('history-list');
    list.innerHTML = '';
    if (!history.length) { list.innerHTML = '<p style="color:#999;font-size:.85rem">履歴がありません</p>'; }
    history.forEach(h => {
      const div = document.createElement('div');
      div.className = 'history-item';
      const d = new Date(h.editedAt);
      const t = d.toLocaleString('ja-JP', { month:'numeric', day:'numeric', hour:'2-digit', minute:'2-digit' });
      div.innerHTML = `<div>${esc(h.text)}</div><div class="history-item-time">${t}</div>`;
      list.appendChild(div);
    });
    $('history-modal').classList.remove('hidden');
  };
  window.closeHistoryModal = function(e) {
    if (!e || e.target === $('history-modal') || !e.target) {
      $('history-modal').classList.add('hidden');
    }
  };

  // ===== ユーティリティ =====
  function scrollBottom() {
    const ml = $('message-list');
    ml.scrollTop = ml.scrollHeight;
  }

  function showBanner(text) {
    const b = document.createElement('div');
    b.className = 'banner';
    b.textContent = text;
    $('screen-chat').insertBefore(b, $('screen-chat').firstChild);
  }

  let toastTimer = null;
  function showToast(text) {
    let t = document.getElementById('toast');
    if (!t) {
      t = document.createElement('div');
      t.id = 'toast';
      t.style.cssText = 'position:fixed;bottom:80px;left:50%;transform:translateX(-50%);background:#333;color:#fff;padding:8px 18px;border-radius:20px;font-size:.82rem;z-index:9999;pointer-events:none;opacity:0;transition:opacity .2s;';
      document.body.appendChild(t);
    }
    t.textContent = text;
    t.style.opacity = '1';
    if (toastTimer) clearTimeout(toastTimer);
    toastTimer = setTimeout(() => { t.style.opacity = '0'; }, 2000);
  }

  function esc(str) {
    return String(str || '').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');
  }

  // ===== 初期化 =====
  function init() {
    // 絵文字グリッド初期化
    initEmojiGrid();

    // ログイン維持チェック
    const saved = loadSaved();
    if (saved) {
      connect(() => {
        wsSend({ type: 'auth', username: saved.username, password: saved.password, isRegister: false });
        $('auth-username').value = saved.username;
        $('remember-me').checked = true;
      });
    }

    // Enterキーで送信（ログイン・参加フォーム）
    $('auth-password').addEventListener('keydown', e => { if (e.key === 'Enter') doAuth(); });
    $('join-code').addEventListener('keydown', e => { if (e.key === 'Enter') doJoinRoom(); });
    $('join-password').addEventListener('keydown', e => { if (e.key === 'Enter') doJoinRoom(); });
    $('create-name').addEventListener('keydown', e => { if (e.key === 'Enter') doCreateRoom(); });
  }

  init();
})();
