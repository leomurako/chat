(() => {
  'use strict';

  /* =====================================================
     設定
  ===================================================== */
  const RENDER_WS_URL = 'https://chat-server-isoe.onrender.com';
  function resolveWsUrl() {
    const h = location.hostname;
    return (h === 'localhost' || h === '127.0.0.1') ? `ws://${location.host}` : RENDER_WS_URL;
  }

  /* =====================================================
     状態変数
  ===================================================== */
  let ws            = null;
  let myUsername    = '';
  let currentRoom   = { code: null, name: '', icon: '💬' };
  let replyTarget   = null;
  let editTarget    = null;
  let ctxTarget     = null;
  let joinedRooms   = [];
  let selectedEmoji = '💬';
  let currentTab    = 'login';
  let readObserver  = null;
  let pendingImage  = null;   // { dataUrl, name }
  let typingTimer   = null;   // 自分のタイピングタイマー
  let typingUsers   = new Set();  // 現在タイピング中のユーザー名
  let typingClearTimers = {};     // { username: timerID }

  const $ = id => document.getElementById(id);
  const SCREENS = ['screen-login','screen-home','screen-create','screen-join','screen-chat'];

  /* =====================================================
     グローバル関数（window.xxx）を最初に全部登録
     ── どこかで例外が起きても関数自体は定義されている
  ===================================================== */

  window.showScreen = function(id) {
    try {
      SCREENS.forEach(s => { const el=$(s); if(el) el.classList.add('hidden'); });
      const t=$(id); if(t) t.classList.remove('hidden');
    } catch(e) { console.error('showScreen',e); }
  };

  window.switchTab = function(tab) {
    try {
      currentTab = tab;
      const tl=$('tab-login'), tr=$('tab-register'), btn=$('auth-btn'), err=$('auth-error');
      if(tl) tl.classList.toggle('active', tab==='login');
      if(tr) tr.classList.toggle('active', tab==='register');
      if(btn) btn.textContent = tab==='login' ? 'ログイン' : '新規登録';
      if(err) err.textContent = '';
    } catch(e) { console.error('switchTab',e); }
  };

  window.doAuth = function() {
    try {
      const u=$('auth-username'), p=$('auth-password'), err=$('auth-error');
      if(!u||!p) return;
      const username=u.value.trim(), password=p.value;
      if(err) err.textContent='';
      if(!username||!password) { if(err) err.textContent='すべて入力してください'; return; }
      connect(() => {
        wsSend({ type:'auth', username, password, isRegister: currentTab==='register' });
        const rem=$('remember-me');
        if(rem&&rem.checked) saveSession(username,password);
      });
    } catch(e) { console.error('doAuth',e); const err=$('auth-error'); if(err) err.textContent='エラーが発生しました'; }
  };

  window.doLogout = function() {
    try {
      clearSession(); myUsername=''; joinedRooms=[];
      currentRoom={code:null,name:'',icon:'💬'};
      if(ws) { try{ws.close();}catch(_){} ws=null; }
      window.showScreen('screen-login');
    } catch(e) { console.error('doLogout',e); }
  };

  window.updatePreview = function() {
    try {
      const n=$('create-name'), pn=$('icon-preview-name'), pi=$('icon-preview');
      if(pn) pn.textContent = n?(n.value||'ルーム名'):'ルーム名';
      if(pi) pi.textContent = selectedEmoji;
    } catch(e) { console.error('updatePreview',e); }
  };

  window.doCreateRoom = function() {
    try {
      const n=$('create-name'), p=$('create-password'), err=$('create-error');
      const name=n?n.value.trim():'';
      if(err) err.textContent='';
      if(!name) { if(err) err.textContent='ルーム名を入力してください'; return; }
      wsSend({ type:'createRoom', name, icon:selectedEmoji, password:p?p.value:'' });
    } catch(e) { console.error('doCreateRoom',e); }
  };

  window.doJoinRoom = function() {
    try {
      const c=$('join-code'), p=$('join-password'), err=$('join-error');
      const code=c?c.value.trim().toUpperCase():'';
      if(err) err.textContent='';
      if(!code) { if(err) err.textContent='ルームコードを入力してください'; return; }
      wsSend({ type:'joinRoom', code, password:p?p.value:'' });
    } catch(e) { console.error('doJoinRoom',e); }
  };

  window.leaveRoom = function() {
    try {
      stopTyping();
      wsSend({ type:'leaveRoomView' });
      currentRoom={code:null,name:'',icon:'💬'};
      window.cancelImage();
      hideTypingIndicator();
      typingUsers.clear();
      window.showScreen('screen-home');
    } catch(e) { console.error('leaveRoom',e); }
  };

  window.sendMessage = function() {
    try {
      const inp=$('message-input');
      if(!inp||!currentRoom.code) return;
      const text=inp.value.trim();

      if(editTarget) {
        if(!text) return;
        wsSend({ type:'editMessage', msgId:editTarget.msgId, newText:text });
        window.cancelEdit(); inp.focus(); return;
      }
      if(pendingImage) {
        const img=pendingImage;
        window.cancelImage();
        uploadAndSend(img, text);
        inp.value=''; stopTyping(); inp.focus(); return;
      }
      if(!text) return;
      wsSend({ type:'message', text, replyTo:replyTarget });
      window.cancelReply();
      inp.value=''; stopTyping(); inp.focus();
    } catch(e) { console.error('sendMessage',e); }
  };

  window.cancelReply = function() {
    try { replyTarget=null; const b=$('reply-bar'); if(b) b.classList.add('hidden'); }
    catch(e) { console.error('cancelReply',e); }
  };

  window.cancelEdit = function() {
    try { editTarget=null; const b=$('edit-bar'),i=$('message-input'); if(b) b.classList.add('hidden'); if(i) i.value=''; }
    catch(e) { console.error('cancelEdit',e); }
  };

  window.cancelImage = function() {
    try {
      pendingImage=null;
      const b=$('image-preview-bar'),i=$('image-input');
      if(b) b.classList.add('hidden');
      if(i) i.value='';
    } catch(e) { console.error('cancelImage',e); }
  };

  window.onImageSelected = function(event) {
    try {
      const file = event.target.files && event.target.files[0];
      if(!file) return;
      if(file.size > 5*1024*1024) { showToast('画像は5MBまでです'); window.cancelImage(); return; }
      const allowed=['image/jpeg','image/png','image/gif','image/webp'];
      if(!allowed.includes(file.type)) { showToast('jpg/png/gif/webpのみ対応しています'); window.cancelImage(); return; }

      const reader=new FileReader();
      reader.onload=function(e) {
        pendingImage={ dataUrl:e.target.result, name:file.name };
        const thumb=$('image-preview-thumb'), name=$('image-preview-name'), bar=$('image-preview-bar');
        if(thumb) thumb.src=e.target.result;
        if(name) name.textContent=file.name;
        if(bar) bar.classList.remove('hidden');
      };
      reader.readAsDataURL(file);
    } catch(e) { console.error('onImageSelected',e); }
  };

  window.openImageModal = function(url) {
    try {
      const m=$('image-modal'),i=$('image-modal-img');
      if(!m||!i) return; i.src=url; m.classList.remove('hidden');
    } catch(e) { console.error('openImageModal',e); }
  };

  window.closeImageModal = function(e) {
    try { const m=$('image-modal'); if(!m) return; if(!e||e.target===m) m.classList.add('hidden'); }
    catch(e) { console.error('closeImageModal',e); }
  };

  window.ctxAction = function(action) {
    try {
      if(!ctxTarget) return;
      closeCtxMenu();
      if(action==='reply') {
        const row=document.querySelector(`.msg-row[data-msg-id="${cssEsc(ctxTarget.msgId)}"]`);
        setReply({ id:ctxTarget.msgId, username:row?row.dataset.username:'?', text:ctxTarget.text });
      } else if(action==='copy') {
        if(navigator.clipboard&&navigator.clipboard.writeText) {
          navigator.clipboard.writeText(ctxTarget.text).then(()=>showToast('コピーしました')).catch(()=>showToast('コピー失敗'));
        } else showToast('このブラウザはコピーに非対応です');
      } else if(action==='edit') {
        setEditMode(ctxTarget.msgId, ctxTarget.text);
      } else if(action==='recall') {
        if(confirm('このメッセージを取り消しますか？')) wsSend({ type:'recallMessage', msgId:ctxTarget.msgId });
      }
    } catch(e) { console.error('ctxAction',e); }
  };

  window.openHistoryModal = function(history) {
    try {
      const list=$('history-list'); if(!list) return;
      list.innerHTML='';
      if(!history||!history.length) {
        list.innerHTML='<p style="color:#999;font-size:.85rem">履歴がありません</p>';
      } else {
        history.forEach(h => {
          const div=document.createElement('div');
          div.className='history-item';
          const d=new Date(h.editedAt);
          const t=isNaN(d)?'' : d.toLocaleString('ja-JP',{month:'numeric',day:'numeric',hour:'2-digit',minute:'2-digit'});
          div.innerHTML=`<div>${esc(h.text)}</div><div class="history-item-time">${t}</div>`;
          list.appendChild(div);
        });
      }
      const m=$('history-modal'); if(m) m.classList.remove('hidden');
    } catch(e) { console.error('openHistoryModal',e); }
  };

  window.closeHistoryModal = function(e) {
    try { const m=$('history-modal'); if(!m) return; if(!e||e.target===m) m.classList.add('hidden'); }
    catch(e) { console.error('closeHistoryModal',e); }
  };

  window.requestNotificationPermission = function() {
    try {
      if(typeof Notification==='undefined') { showToast('このブラウザは通知に非対応です'); return; }
      if(Notification.permission==='granted') { showToast('すでに通知が有効です'); return; }
      Notification.requestPermission().then(p => {
        updateNotifBtn();
        if(p==='granted') showToast('通知を有効にしました');
        else if(p==='denied') showToast('通知がブロックされています（ブラウザ設定から変更できます）');
      });
    } catch(e) { console.error('requestNotificationPermission',e); }
  };

  /* =====================================================
     WebSocket
  ===================================================== */
  function connect(onOpen) {
    try {
      if(ws && ws.readyState===1) { onOpen(); return; }
      if(ws) { try{ws.close();}catch(_){} ws=null; }
      ws=new WebSocket(resolveWsUrl());
      ws.addEventListener('open', ()=>{ try{onOpen();}catch(e){console.error('onOpen',e);} });
      ws.addEventListener('message', e=>{ try{handle(JSON.parse(e.data));}catch(err){console.error('msg parse',err);} });
      ws.addEventListener('close', ()=>{ showBanner('接続が切れました。再読み込みしてください。'); });
      ws.addEventListener('error', ()=>{ const el=$('auth-error'); if(el) el.textContent='サーバーに接続できません'; });
    } catch(e) { console.error('connect',e); }
  }

  function wsSend(obj) {
    try {
      if(ws&&ws.readyState===1) ws.send(JSON.stringify(obj));
      else console.warn('wsSend skip (not open)', obj.type);
    } catch(e) { console.error('wsSend',e); }
  }

  /* =====================================================
     メッセージハンドラ
  ===================================================== */
  function handle(data) {
    switch(data.type) {
      case 'authOk':        onAuthOk(data); break;
      case 'authError':     { const el=$('auth-error'); if(el) el.textContent=data.text; break; }
      case 'roomCreated':   onRoomCreated(data); break;
      case 'roomJoined':    onRoomJoined(data); break;
      case 'roomError':     { const ce=$('create-error'),je=$('join-error'); if(ce) ce.textContent=data.text; if(je) je.textContent=data.text; break; }
      case 'history':       onHistory(data.messages); break;
      case 'message':       renderMessage(data); scrollBottom(); break;
      case 'system':        renderSystem(data.text); if(data.count!=null){const oc=$('online-count');if(oc)oc.textContent=data.count;} scrollBottom(); break;
      case 'messageEdited': onEdited(data); break;
      case 'messageRecalled': onRecalled(data); break;
      case 'readUpdate':    onReadUpdate(data); break;
      case 'unreadUpdate':  onUnreadUpdate(data); break;
      case 'typing':        onTyping(data); break;
      case 'error':         showBanner(data.text); break;
    }
  }

  /* =====================================================
     認証
  ===================================================== */
  function onAuthOk(data) {
    myUsername=data.username;
    joinedRooms=data.joinedRooms||[];
    const hu=$('home-username'); if(hu) hu.textContent=myUsername;
    updateNotifBtn();
    renderRoomList();
    window.showScreen('screen-home');
  }

  /* =====================================================
     ルーム一覧
  ===================================================== */
  function renderRoomList() {
    const list=$('room-list'); if(!list) return;
    if(!joinedRooms.length) { list.innerHTML='<p class="empty-msg">まだルームがありません</p>'; return; }
    list.innerHTML='';
    joinedRooms.forEach(r => {
      const div=document.createElement('div');
      div.className='room-item';
      const badge = (r.unreadCount&&r.unreadCount>0)
        ? `<span class="unread-badge">${r.unreadCount>99?'99+':r.unreadCount}</span>`
        : '';
      div.innerHTML=`<div class="room-icon-circle">${esc(r.icon)}</div><span class="room-item-name">${esc(r.name)}</span>${badge}<span class="room-item-arrow">›</span>`;
      div.addEventListener('click', ()=>enterRoom(r.code,r.name,r.icon));
      list.appendChild(div);
    });
  }

  /* =====================================================
     ルーム作成・参加
  ===================================================== */
  const EMOJIS=['💬','🎉','🎮','📚','🎵','🏆','🌟','🔥','💡','🎨','🏠','🌈','🐱','🐶','🍕','☕','✈️','💪','🎯','🤝','🌸','🦁','🦋','🌺','🎸','🎲','🧩','🚀','💎','🌙'];

  function initEmojiGrid() {
    const grid=$('emoji-grid'); if(!grid) return;
    grid.innerHTML='';
    EMOJIS.forEach(e=>{
      const btn=document.createElement('button');
      btn.className='emoji-btn'+(e===selectedEmoji?' selected':'');
      btn.textContent=e; btn.type='button';
      btn.addEventListener('click',()=>{
        selectedEmoji=e;
        document.querySelectorAll('.emoji-btn').forEach(b=>b.classList.remove('selected'));
        btn.classList.add('selected');
        const pi=$('icon-preview'); if(pi) pi.textContent=e;
      });
      grid.appendChild(btn);
    });
  }

  function onRoomCreated(data) {
    joinedRooms.push({ code:data.code, name:data.name, icon:data.icon, unreadCount:0 });
    renderRoomList();
    showToast(`ルームを作成しました（コード: ${data.code}）`);
    window.showScreen('screen-home');
    const n=$('create-name'),p=$('create-password');
    if(n) n.value=''; if(p) p.value='';
  }

  function onRoomJoined(data) {
    if(!joinedRooms.find(r=>r.code===data.code)) joinedRooms.push({ code:data.code, name:data.name, icon:data.icon, unreadCount:0 });
    renderRoomList();
    const c=$('join-code'),p=$('join-password');
    if(c) c.value=''; if(p) p.value='';
    enterRoom(data.code, data.name, data.icon);
  }

  /* =====================================================
     チャット画面
  ===================================================== */
  function enterRoom(code, name, icon) {
    currentRoom={code,name,icon};
    const ci=$('chat-room-icon'),cn=$('chat-room-name'),ml=$('message-list');
    if(ci) ci.textContent=icon; if(cn) cn.textContent=name; if(ml) ml.innerHTML='';
    window.cancelReply(); window.cancelEdit(); window.cancelImage();
    hideTypingIndicator(); typingUsers.clear();
    // 該当ルームの未読をリセット
    const room=joinedRooms.find(r=>r.code===code);
    if(room) room.unreadCount=0;
    renderRoomList();
    wsSend({ type:'enterRoom', code });
    window.showScreen('screen-chat');
  }

  function onHistory(messages) {
    (messages||[]).forEach(m=>renderMessage(m,true));
    scrollBottom();
  }

  /* =====================================================
     メッセージ描画
  ===================================================== */
  function renderMessage(data) {
    if(!data||!data.id) return;
    const ml=$('message-list'); if(!ml) return;
    const isSelf=data.username===myUsername;

    const row=document.createElement('div');
    row.className=`msg-row ${isSelf?'self':'other'}`;
    row.dataset.msgId=data.id;
    row.dataset.username=data.username||'';
    row.dataset.text=data.text||'';

    // アバター（他人のみ）
    if(!isSelf) {
      const av=document.createElement('div');
      av.className='msg-avatar';
      av.textContent=(data.username||'?').charAt(0);
      row.appendChild(av);
    }

    const group=document.createElement('div');
    group.className='msg-group';

    // ユーザー名（他人のみ）
    if(!isSelf) {
      const un=document.createElement('div');
      un.className='msg-username';
      un.textContent=data.username;
      group.appendChild(un);
    }

    // 返信引用
    if(data.replyTo) {
      const q=document.createElement('div');
      q.className='reply-quote';
      q.innerHTML=`<span class="reply-quote-name">${esc(data.replyTo.username)}</span>${esc(data.replyTo.text||'📷 画像')}`;
      group.appendChild(q);
    }

    // バブル本体
    const bubble=document.createElement('div');
    bubble.className='msg-bubble';

    if(data.recalled) {
      bubble.classList.add('recalled');
      bubble.textContent=`${data.username} がメッセージを取り消しました`;
    } else if(data.imageUrl) {
      // 画像メッセージ
      bubble.style.padding='4px';
      const img=document.createElement('img');
      img.className='msg-image';
      img.src=data.imageUrl;
      img.alt='送信された画像';
      img.loading='lazy';
      img.addEventListener('click',()=>window.openImageModal(data.imageUrl));
      img.addEventListener('error',()=>{ img.alt='画像を読み込めませんでした'; });
      bubble.appendChild(img);
      // テキストも一緒に送られていれば下に表示
      if(data.text) {
        const txt=document.createElement('p');
        txt.style.cssText='margin:4px 6px 2px;font-size:.9rem;line-height:1.5;';
        txt.textContent=data.text;
        bubble.appendChild(txt);
      }
    } else {
      bubble.textContent=data.text;
    }
    group.appendChild(bubble);

    // 編集済みラベル
    if(data.edited&&!data.recalled&&!data.imageUrl) {
      const el=document.createElement('span');
      el.className='edited-label';
      el.textContent='編集済み';
      el.title='編集前の内容を見る';
      el.addEventListener('click',()=>window.openHistoryModal(data.editHistory||[]));
      group.appendChild(el);
    }

    // 時刻 + 既読バッジ
    const meta=document.createElement('div');
    meta.className='msg-meta';
    const timeEl=document.createElement('span');
    timeEl.className='msg-time';
    timeEl.textContent=data.time||'';
    meta.appendChild(timeEl);
    const readEl=document.createElement('span');
    readEl.className='read-badge';
    readEl.dataset.msgId=data.id;
    updateReadBadge(readEl, Array.isArray(data.readBy)?data.readBy:[]);
    meta.appendChild(readEl);
    group.appendChild(meta);

    // ···アクションボタン
    if(!data.recalled) {
      const actBtn=document.createElement('button');
      actBtn.className='msg-actions-btn';
      actBtn.textContent='···';
      actBtn.addEventListener('click',e=>{ e.stopPropagation(); openCtxMenu(e,data.id,isSelf,data.text||''); });
      row.appendChild(actBtn);
    }

    row.appendChild(group);
    ml.appendChild(row);

    // 既読観測（他人のメッセージ、かつ非取り消し）
    if(!isSelf&&!data.recalled&&readObserver) {
      try { readObserver.observe(row); } catch(_) {}
    }

    // バックグラウンドのブラウザ通知
    if(!isSelf&&!data.recalled&&document.hidden) {
      pushNotification(`${data.username}`, data.imageUrl?'📷 画像を送りました':data.text, currentRoom.icon);
    }
  }

  /* =====================================================
     既読
  ===================================================== */
  function updateReadBadge(el, readBy) {
    const others=readBy.filter(u=>u!==myUsername);
    if(!others.length) { el.textContent=''; el.style.cursor='default'; el.onclick=null; return; }
    el.textContent=`既読 ${others.length}`;
    el.style.cssText='font-size:.62rem;color:#aaa;cursor:pointer;text-decoration:underline dotted;';
    el.onclick=e=>{ e.stopPropagation(); showReadersTooltip(e,others); };
  }

  let tooltipEl=null;
  function showReadersTooltip(e, readers) {
    try {
      if(tooltipEl) tooltipEl.remove();
      tooltipEl=document.createElement('div');
      tooltipEl.style.cssText='position:fixed;background:#333;color:#fff;font-size:.75rem;border-radius:8px;padding:6px 10px;z-index:9999;pointer-events:none;line-height:1.6;max-width:200px;';
      tooltipEl.innerHTML='<strong>既読</strong><br>'+readers.map(esc).join('<br>');
      document.body.appendChild(tooltipEl);
      const rect=e.target.getBoundingClientRect();
      const tw=tooltipEl.offsetWidth;
      tooltipEl.style.left=Math.max(4,Math.min(rect.left,window.innerWidth-tw-4))+'px';
      tooltipEl.style.top=Math.max(4,rect.top-tooltipEl.offsetHeight-8)+'px';
      setTimeout(()=>document.addEventListener('click',removeTooltip,{once:true}),50);
    } catch(err) { console.error('showReadersTooltip',err); }
  }
  function removeTooltip() { if(tooltipEl){tooltipEl.remove();tooltipEl=null;} }

  function onVisible(entries) {
    entries.forEach(entry=>{
      if(!entry.isIntersecting) return;
      const row=entry.target;
      const msgId=row.dataset.msgId;
      if(!msgId||!currentRoom.code) return;
      wsSend({ type:'readMessage', msgId });
      if(readObserver) readObserver.unobserve(row);
    });
  }

  function onReadUpdate(data) {
    const badge=document.querySelector(`.read-badge[data-msg-id="${cssEsc(data.msgId)}"]`);
    if(!badge) return;
    updateReadBadge(badge, data.readBy||[]);
  }

  /* =====================================================
     未読バッジ（他ルームへの通知）
  ===================================================== */
  function onUnreadUpdate(data) {
    const room=joinedRooms.find(r=>r.code===data.roomCode);
    if(room) {
      room.unreadCount=(room.unreadCount||0)+1;
      renderRoomList();
    }
    // ブラウザ通知
    pushNotification(`${data.roomIcon} ${data.roomName}`, `${data.fromUser}: ${data.preview}`);
  }

  /* =====================================================
     タイピング中
  ===================================================== */
  function onTyping(data) {
    if(data.username===myUsername) return;
    if(data.isTyping) {
      typingUsers.add(data.username);
      // 5秒後に自動削除（通信が途切れた場合のフォールバック）
      if(typingClearTimers[data.username]) clearTimeout(typingClearTimers[data.username]);
      typingClearTimers[data.username]=setTimeout(()=>{
        typingUsers.delete(data.username);
        delete typingClearTimers[data.username];
        renderTypingIndicator();
      }, 5000);
    } else {
      typingUsers.delete(data.username);
      if(typingClearTimers[data.username]) { clearTimeout(typingClearTimers[data.username]); delete typingClearTimers[data.username]; }
    }
    renderTypingIndicator();
  }

  function renderTypingIndicator() {
    const el=$('typing-indicator'), txt=$('typing-text');
    if(!el||!txt) return;
    const users=[...typingUsers];
    if(!users.length) { el.classList.add('hidden'); return; }
    el.classList.remove('hidden');
    if(users.length===1) txt.textContent=`${users[0]} が入力中`;
    else txt.textContent=`${users.slice(0,-1).join('、')}、${users[users.length-1]} が入力中`;
  }

  function hideTypingIndicator() {
    const el=$('typing-indicator'); if(el) el.classList.add('hidden');
  }

  // 自分のタイピング通知（500ms debounce）
  function onInputChange() {
    if(!currentRoom.code) return;
    wsSend({ type:'typing', isTyping:true });
    if(typingTimer) clearTimeout(typingTimer);
    typingTimer=setTimeout(stopTyping, 2500);
  }

  function stopTyping() {
    if(typingTimer) { clearTimeout(typingTimer); typingTimer=null; }
    if(currentRoom.code) wsSend({ type:'typing', isTyping:false });
  }

  /* =====================================================
     画像アップロード
  ===================================================== */
  async function uploadAndSend(img, text) {
    try {
      showToast('画像をアップロード中...');
      const res=await fetch('/upload',{
        method:'POST',
        headers:{'Content-Type':'application/json'},
        body:JSON.stringify({ dataUrl:img.dataUrl })
      });
      if(!res.ok) { const e=await res.json(); showToast(e.error||'アップロード失敗'); return; }
      const { url }=await res.json();
      wsSend({ type:'message', text, imageUrl:url, replyTo:replyTarget });
      window.cancelReply();
    } catch(e) {
      console.error('uploadAndSend',e);
      showToast('アップロードに失敗しました');
    }
  }

  /* =====================================================
     システムメッセージ
  ===================================================== */
  function renderSystem(text) {
    const ml=$('message-list'); if(!ml) return;
    const el=document.createElement('div');
    el.className='msg-system'; el.textContent=text;
    ml.appendChild(el);
  }

  /* =====================================================
     コンテキストメニュー
  ===================================================== */
  function openCtxMenu(e, msgId, isSelf, text) {
    ctxTarget={msgId,isSelf,text};
    const menu=$('ctx-menu'); if(!menu) return;
    menu.classList.remove('hidden');
    document.querySelectorAll('.ctx-own').forEach(el=>{ el.style.display=isSelf?'':'none'; });
    const x=Math.min(e.clientX,window.innerWidth-170);
    const y=Math.min(e.clientY,window.innerHeight-180);
    menu.style.left=x+'px'; menu.style.top=y+'px';
    setTimeout(()=>document.addEventListener('click',closeCtxMenu,{once:true}),50);
  }
  function closeCtxMenu() { const m=$('ctx-menu'); if(m) m.classList.add('hidden'); }

  /* =====================================================
     返信・編集モード
  ===================================================== */
  function setReply(target) {
    window.cancelEdit();
    replyTarget=target;
    const bar=$('reply-bar'),txt=$('reply-bar-text'),inp=$('message-input');
    if(bar) bar.classList.remove('hidden');
    if(txt) txt.textContent=`${target.username}: ${target.text||'📷 画像'}`;
    if(inp) inp.focus();
  }

  function setEditMode(msgId, text) {
    window.cancelReply();
    editTarget={msgId,text};
    const bar=$('edit-bar'),txt=$('edit-bar-text'),inp=$('message-input');
    if(bar) bar.classList.remove('hidden');
    if(txt) txt.textContent=text;
    if(inp) { inp.value=text; inp.focus(); }
  }

  /* =====================================================
     編集・取り消し受信
  ===================================================== */
  function onEdited(data) {
    const row=document.querySelector(`.msg-row[data-msg-id="${cssEsc(data.msgId)}"]`);
    if(!row) return;
    row.dataset.text=data.newText;
    const bubble=row.querySelector('.msg-bubble');
    if(bubble&&bubble.firstChild&&bubble.firstChild.nodeType===3) bubble.firstChild.textContent=data.newText;
    else if(bubble&&!bubble.querySelector('img')) bubble.textContent=data.newText;
    let el=row.querySelector('.edited-label');
    if(!el) {
      el=document.createElement('span');
      el.className='edited-label'; el.textContent='編集済み'; el.title='編集前の内容を見る';
      const meta=row.querySelector('.msg-meta');
      if(meta&&meta.parentNode) meta.parentNode.insertBefore(el,meta);
    }
    el.onclick=()=>window.openHistoryModal(data.editHistory||[]);
  }

  function onRecalled(data) {
    const row=document.querySelector(`.msg-row[data-msg-id="${cssEsc(data.msgId)}"]`);
    if(!row) return;
    const bubble=row.querySelector('.msg-bubble');
    if(bubble) { bubble.className='msg-bubble recalled'; bubble.innerHTML=''; bubble.textContent=`${data.username} がメッセージを取り消しました`; }
    const actBtn=row.querySelector('.msg-actions-btn'); if(actBtn) actBtn.remove();
    if(readObserver) { try{readObserver.unobserve(row);}catch(_){} }
  }

  /* =====================================================
     ブラウザ通知
  ===================================================== */
  function pushNotification(title, body) {
    try {
      if(typeof Notification==='undefined') return;
      if(Notification.permission!=='granted') return;
      if(!document.hidden) return; // フォアグラウンドなら不要
      new Notification(title, { body, icon:'/favicon.ico' });
    } catch(e) { console.warn('pushNotification',e); }
  }

  function updateNotifBtn() {
    try {
      const btn=$('notif-btn'); if(!btn) return;
      if(typeof Notification==='undefined') { btn.style.display='none'; return; }
      if(Notification.permission==='granted') { btn.textContent='🔔'; btn.title='通知：有効'; btn.style.opacity='1'; }
      else { btn.textContent='🔕'; btn.title='通知を有効にする'; btn.style.opacity='.6'; }
    } catch(e) {}
  }

  /* =====================================================
     ユーティリティ
  ===================================================== */
  function scrollBottom() { const ml=$('message-list'); if(ml) ml.scrollTop=ml.scrollHeight; }

  function showBanner(text) {
    const sc=$('screen-chat'); if(!sc) return;
    // 重複バナーを防ぐ
    if(sc.querySelector('.banner')) return;
    const b=document.createElement('div');
    b.className='banner'; b.textContent=text;
    sc.insertBefore(b,sc.firstChild);
  }

  let toastTimer=null;
  function showToast(text) {
    let t=document.getElementById('toast');
    if(!t) {
      t=document.createElement('div'); t.id='toast';
      t.style.cssText='position:fixed;bottom:80px;left:50%;transform:translateX(-50%);background:#333;color:#fff;padding:8px 18px;border-radius:20px;font-size:.82rem;z-index:9999;pointer-events:none;opacity:0;transition:opacity .2s;white-space:nowrap;';
      document.body.appendChild(t);
    }
    t.textContent=text; t.style.opacity='1';
    if(toastTimer) clearTimeout(toastTimer);
    toastTimer=setTimeout(()=>{ t.style.opacity='0'; },2200);
  }

  function esc(str) {
    return String(str||'').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');
  }

  function cssEsc(str) {
    if(window.CSS&&window.CSS.escape) return window.CSS.escape(str);
    return String(str).replace(/([^\w-])/g,'\\$1');
  }

  function loadSaved() {
    try { const s=localStorage.getItem('chat_session'); return s?JSON.parse(s):null; }
    catch(e) { return null; }
  }
  function saveSession(u,p) { try { localStorage.setItem('chat_session',JSON.stringify({username:u,password:p})); }catch(e){} }
  function clearSession() { try { localStorage.removeItem('chat_session'); }catch(e){} }

  /* =====================================================
     初期化（DOMContentLoaded後）
  ===================================================== */
  function init() {
    try {
      // IntersectionObserver（安全にガード）
      if(typeof IntersectionObserver!=='undefined') {
        try { readObserver=new IntersectionObserver(onVisible,{threshold:0.5}); }
        catch(e) { console.error('IO init failed',e); }
      }

      initEmojiGrid();
      updateNotifBtn();

      // ログイン保持
      const saved=loadSaved();
      if(saved) {
        connect(()=>{
          wsSend({type:'auth',username:saved.username,password:saved.password,isRegister:false});
          const u=$('auth-username'),r=$('remember-me');
          if(u) u.value=saved.username; if(r) r.checked=true;
        });
      }

      // キーボードイベント
      const pwEl=$('auth-password');
      if(pwEl) pwEl.addEventListener('keydown',e=>{ if(e.key==='Enter') window.doAuth(); });
      const jcEl=$('join-code');
      if(jcEl) jcEl.addEventListener('keydown',e=>{ if(e.key==='Enter') window.doJoinRoom(); });
      const jpEl=$('join-password');
      if(jpEl) jpEl.addEventListener('keydown',e=>{ if(e.key==='Enter') window.doJoinRoom(); });
      const cnEl=$('create-name');
      if(cnEl) cnEl.addEventListener('keydown',e=>{ if(e.key==='Enter') window.doCreateRoom(); });

      // メッセージ入力
      const miEl=$('message-input');
      if(miEl) {
        miEl.addEventListener('keydown',e=>{ if(e.key==='Enter'&&!e.shiftKey){e.preventDefault();window.sendMessage();} });
        miEl.addEventListener('input',onInputChange);
      }

      console.log('チャットアプリ初期化完了');
    } catch(e) { console.error('init',e); }
  }

  if(document.readyState==='loading') document.addEventListener('DOMContentLoaded',init);
  else init();
})();
