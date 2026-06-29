(() => {
  // ======================================================
  // ★ RenderにデプロイしたらここのURLを書き換えてください ★
  // 例: 'wss://my-chat-app.onrender.com'
  // ======================================================
  const RENDER_WS_URL = 'wss://YOUR-APP-NAME.onrender.com';

  // ローカル（localhost）のときは自動的にローカルサーバーへ接続
  const WS_URL = location.hostname === 'localhost' || location.hostname === '127.0.0.1'
    ? `ws://${location.host}`
    : RENDER_WS_URL;

  const $ = id => document.getElementById(id);

  const loginScreen   = $('login-screen');
  const chatScreen    = $('chat-screen');
  const usernameInput = $('username-input');
  const joinBtn       = $('join-btn');
  const loginError    = $('login-error');
  const messageList   = $('message-list');
  const messageInput  = $('message-input');
  const sendBtn       = $('send-btn');
  const onlineCount   = $('online-count');

  let ws = null;
  let myUsername = '';

  function join() {
    const name = usernameInput.value.trim();
    if (!name) { loginError.textContent = 'ニックネームを入力してください'; return; }
    loginError.textContent = '';
    myUsername = name;
    connectWebSocket();
  }

  joinBtn.addEventListener('click', join);
  usernameInput.addEventListener('keydown', e => { if (e.key === 'Enter') join(); });

  function connectWebSocket() {
    try {
      ws = new WebSocket(WS_URL);
    } catch (e) {
      loginError.textContent = 'サーバーURLが正しくありません';
      return;
    }

    ws.addEventListener('open', () => {
      ws.send(JSON.stringify({ type: 'join', username: myUsername }));
      loginScreen.classList.add('hidden');
      chatScreen.classList.remove('hidden');
      messageInput.focus();
    });

    ws.addEventListener('message', e => {
      try { handleMessage(JSON.parse(e.data)); } catch {}
    });

    ws.addEventListener('close', () => {
      showBanner('接続が切れました。ページを再読み込みしてください。');
      sendBtn.disabled = true;
      messageInput.disabled = true;
    });

    ws.addEventListener('error', () => {
      loginError.textContent = 'サーバーに接続できませんでした。RenderのURLを確認してください。';
      ws = null;
    });
  }

  function handleMessage(data) {
    if (data.type === 'history') {
      data.messages.forEach(renderMessage);
      scrollToBottom();
      return;
    }
    if (data.type === 'system') {
      renderSystem(data.text);
      if (data.count !== undefined) onlineCount.textContent = data.count;
      scrollToBottom();
      return;
    }
    if (data.type === 'message') {
      renderMessage(data);
      scrollToBottom();
    }
  }

  function renderMessage(data) {
    const isSelf = data.username === myUsername;
    const row = document.createElement('div');
    row.className = `msg-row ${isSelf ? 'self' : 'other'}`;

    if (!isSelf) {
      const avatar = document.createElement('div');
      avatar.className = 'msg-avatar';
      avatar.textContent = data.username.charAt(0);
      row.appendChild(avatar);
    }

    const group = document.createElement('div');
    group.className = 'msg-group';

    if (!isSelf) {
      const nameEl = document.createElement('div');
      nameEl.className = 'msg-username';
      nameEl.textContent = data.username;
      group.appendChild(nameEl);
    }

    const bubble = document.createElement('div');
    bubble.className = 'msg-bubble';
    bubble.textContent = data.text;
    group.appendChild(bubble);

    if (data.time) {
      const time = document.createElement('div');
      time.className = 'msg-time';
      time.textContent = data.time;
      group.appendChild(time);
    }

    row.appendChild(group);
    messageList.appendChild(row);
  }

  function renderSystem(text) {
    const el = document.createElement('div');
    el.className = 'msg-system';
    el.textContent = text;
    messageList.appendChild(el);
  }

  function sendMessage() {
    const text = messageInput.value.trim();
    if (!text || !ws || ws.readyState !== WebSocket.OPEN) return;
    ws.send(JSON.stringify({ type: 'message', text }));
    messageInput.value = '';
    messageInput.focus();
  }

  sendBtn.addEventListener('click', sendMessage);
  messageInput.addEventListener('keydown', e => {
    if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); sendMessage(); }
  });

  function scrollToBottom() { messageList.scrollTop = messageList.scrollHeight; }

  function showBanner(text) {
    const banner = document.createElement('div');
    banner.className = 'banner';
    banner.textContent = text;
    chatScreen.insertBefore(banner, chatScreen.firstChild);
  }
})();
