'use strict';
(function () {
  const $ = (id) => document.getElementById(id);
  const state = { csrf: '', role: '', status: '', selected: null, lastId: null, canned: [], meta: null, ws: null, retry: 1000 };

  async function api(method, path, body) {
    const res = await fetch('/admin/v1/support' + path, {
      method, credentials: 'same-origin',
      headers: Object.assign({ 'Content-Type': 'application/json' }, state.csrf ? { 'X-CSRF-Token': state.csrf } : {}),
      body: body === undefined ? undefined : JSON.stringify(body),
    });
    if (res.status === 401) { showLogin(); throw new Error('unauthenticated'); }
    if (res.status === 204) return null;
    const data = await res.json().catch(() => ({}));
    if (!res.ok) throw new Error((data.error && data.error.message) || ('HTTP ' + res.status));
    return data;
  }

  const fa = (n) => String(n).replace(/\d/g, (d) => '۰۱۲۳۴۵۶۷۸۹'[d]);
  const when = (iso) => { const d = new Date(iso); return fa(d.toLocaleDateString('fa-IR')) + ' ' + fa(d.toLocaleTimeString('fa-IR', { hour: '2-digit', minute: '2-digit' })); };
  const statusText = { open: 'منتظر پاسخ', waiting_user: 'منتظر کاربر', closed: 'بسته' };

  function showLogin() { $('login').classList.remove('hidden'); $('app').classList.add('hidden'); if (state.ws) { state.ws.close(); state.ws = null; } }

  async function start(me) {
    state.csrf = me.csrf; state.role = me.role;
    $('login').classList.add('hidden'); $('app').classList.remove('hidden');
    $('who').textContent = me.display_name;
    const h = $('hours'); h.textContent = me.within_hours ? 'در ساعت کاری' : 'خارج از ساعت کاری'; h.className = 'badge ' + (me.within_hours ? 'on' : 'off');
    $('admin-box').classList.toggle('hidden', me.role !== 'admin');
    const c = await api('GET', '/canned');
    state.canned = c.canned;
    const sel = $('canned'); sel.length = 1;
    c.canned.filter((x) => x.active).forEach((x) => sel.add(new Option(x.title, x.key)));
    await loadQueue(); connect();
  }

  async function loadQueue() {
    const data = await api('GET', '/conversations' + (state.status ? '?status=' + state.status : ''));
    const ul = $('queue'); ul.textContent = '';
    data.conversations.forEach((c) => {
      const li = document.createElement('li'); li.dataset.id = c.id;
      if (c.id === state.selected) li.className = 'selected';
      const top = document.createElement('div');
      top.textContent = (statusText[c.status] || c.status) + (c.assigned_to ? ' · ' + c.assigned_to : '');
      if (c.operator_unread > 0) { const b = document.createElement('span'); b.className = 'unread'; b.textContent = fa(c.operator_unread); top.append(' ', b); }
      const meta = document.createElement('div'); meta.className = 'meta'; meta.textContent = when(c.last_message_at);
      li.append(top, meta); li.addEventListener('click', () => openConv(c.id)); ul.append(li);
    });
  }

  function bubble(m) {
    const d = document.createElement('div'); d.className = 'bubble ' + (m.sender === 'user' ? 'user' : 'operator'); d.dataset.id = m.id;
    d.textContent = m.body;
    const s = document.createElement('small'); s.textContent = (m.operator_display_name ? m.operator_display_name + ' · ' : '') + when(m.created_at); d.append(s);
    return d;
  }

  async function openConv(id) {
    state.selected = id; state.lastId = null;
    $('empty').classList.add('hidden'); $('conversation').classList.remove('hidden');
    const c = await api('GET', '/conversations/' + id);
    state.meta = c.device_meta || null;
    $('conv-title').textContent = 'گفتگو ' + id.slice(0, 8);
    const st = $('conv-status'); st.textContent = statusText[c.status] || c.status;
    const e = c.entitlement || {};
    const facts = [e.premium ? 'پریمیوم تا ' + when(e.ends_at) : 'رایگان'];
    if (c.device_meta) facts.push('نسخه ' + c.device_meta.app_version + ' · ' + c.device_meta.market + ' · ' + c.device_meta.model + ' · اندروید ' + c.device_meta.os_version);
    $('facts').textContent = facts.join('   |   ');
    $('conversation').dataset.user = c.user_id;
    const box = $('messages'); box.textContent = '';
    await loadMessages(true);
    await loadQueue();
  }

  async function loadMessages(initial) {
    if (!state.selected) return;
    const data = await api('GET', '/conversations/' + state.selected + '/messages' + (state.lastId && !initial ? '?after=' + state.lastId : ''));
    const box = $('messages');
    data.messages.forEach((m) => { if (!box.querySelector('[data-id="' + m.id + '"]')) box.append(bubble(m)); state.lastId = m.id; });
    box.scrollTop = box.scrollHeight;
    if (state.lastId) api('POST', '/conversations/' + state.selected + '/read', { up_to_message_id: state.lastId }).catch(() => {});
  }

  function connect() {
    const ws = new WebSocket((location.protocol === 'https:' ? 'wss://' : 'ws://') + location.host + '/admin/v1/support/ws');
    state.ws = ws;
    ws.onopen = () => { state.retry = 1000; $('live').textContent = 'زنده'; $('live').className = 'badge on'; };
    ws.onmessage = (ev) => {
      let f; try { f = JSON.parse(ev.data); } catch (e) { return; }
      loadQueue().catch(() => {});
      if (f.conversation_id && f.conversation_id === state.selected) loadMessages(false).catch(() => {});
    };
    ws.onclose = () => { $('live').textContent = 'قطع'; $('live').className = 'badge off'; if (state.csrf) setTimeout(connect, state.retry = Math.min(state.retry * 2, 30000)); };
  }

  $('login-form').addEventListener('submit', async (e) => {
    e.preventDefault(); $('login-error').textContent = '';
    try {
      const me = await api('POST', '/login', { username: $('username').value, password: $('password').value });
      $('password').value = '';
      await start(await api('GET', '/me').then((m) => Object.assign(m, { csrf: me.csrf })));
    } catch (err) { $('login-error').textContent = err.message === 'unauthenticated' ? 'نام کاربری یا رمز درست نیست' : err.message; }
  });
  $('logout').addEventListener('click', async () => { await api('POST', '/logout').catch(() => {}); state.csrf = ''; showLogin(); });
  document.querySelectorAll('.filters button').forEach((b) => b.addEventListener('click', () => {
    document.querySelectorAll('.filters button').forEach((x) => x.classList.remove('active')); b.classList.add('active');
    state.status = b.dataset.status; loadQueue();
  }));
  $('canned').addEventListener('change', () => {
    const c = state.canned.find((x) => x.key === $('canned').value); if (!c) return;
    const market = (state.meta && state.meta.market) || 'مارکت';
    $('reply').value = c.body.replace(/\{market\}/g, market); $('canned').value = '';
  });
  $('reply-form').addEventListener('submit', async (e) => {
    e.preventDefault(); const body = $('reply').value.trim(); if (!body || !state.selected) return;
    $('reply').value = '';
    try { await api('POST', '/conversations/' + state.selected + '/messages', { body }); await loadMessages(false); await loadQueue(); }
    catch (err) { $('reply').value = body; alert(err.message); }
  });
  $('assign').addEventListener('click', () => api('POST', '/conversations/' + state.selected + '/assign', {}).then(loadQueue));
  $('close').addEventListener('click', () => api('POST', '/conversations/' + state.selected + '/close', {}).then(() => { $('conversation').classList.add('hidden'); $('empty').classList.remove('hidden'); state.selected = null; return loadQueue(); }));
  $('grant-form').addEventListener('submit', async (e) => {
    e.preventDefault();
    try { await api('POST', '/users/' + $('conversation').dataset.user + '/grant', { days: Number($('grant-days').value), reason: $('grant-reason').value }); alert('انجام شد'); $('grant-reason').value = ''; }
    catch (err) { alert(err.message); }
  });

  api('GET', '/me').then(start).catch(showLogin);
})();
