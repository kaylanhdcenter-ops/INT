// Executado na aba do terminal pelo Publicar-Tela.ps1. Somente controles da página.
function painel(acao, dados) {
  const norm = v => String(v ?? '').normalize('NFD').replace(/[\u0300-\u036f]/g, '')
    .trim().replace(/\s+/g, ' ').toLowerCase();
<<<<<<< Updated upstream
  if (!['http:','https:'].includes(location.protocol)) return null;
  const terminal = new URL('//' + dados.endereco, location.href);
  if (location.origin !== terminal.origin) return null;
=======
  if (!['http:','https:'].includes(location.protocol) ||
      new URL('//' + dados.endereco,location.href).origin !== location.origin) return null;
>>>>>>> Stashed changes
  const docs = [document];
  for (const doc of docs) {
    for (const frame of doc.querySelectorAll('iframe,frame')) {
      try { if (frame.contentDocument && !docs.includes(frame.contentDocument)) docs.push(frame.contentDocument); } catch {}
    }
  }
  const all = (css, root) => (root ? [root] : docs).flatMap(d => [...d.querySelectorAll(css)]);
  const vis = el => el.getClientRects().length && el.ownerDocument.defaultView.getComputedStyle(el).visibility !== 'hidden' &&
    (!el.ownerDocument.defaultView.frameElement || vis(el.ownerDocument.defaultView.frameElement));
  const one = list => list.length === 1 ? list[0] : null;
  const names = e => [e.innerText, e.getAttribute('aria-label'), e.title, e.alt,
    ...(e.matches('input[type=button],input[type=submit]') ? [e.value] : [])].map(norm).filter(Boolean);
  const matches = (e, labels) => names(e).some(n => labels.map(norm).includes(n));
  const buttons = 'button,a,[role=button],[role=tab],[role=menuitem],[role=treeitem],input[type=button],input[type=submit]';
  const usable = e => vis(e) && !e.matches(':disabled,[aria-disabled=true]');
  function action(labels, root) {
    const found = all(buttons, root).filter(e => usable(e) && matches(e, labels));
    if (found.length) return one(found);
    return one(all('li,span,div,label', root).filter(e => usable(e) && !e.children.length &&
      (e.onclick || e.ownerDocument.defaultView.getComputedStyle(e).cursor === 'pointer') && matches(e, labels)));
  }
  const click = el => { if (!el) return false; el.click(); return true; };
  const headings = 'h1,h2,h3,h4,legend,[role=heading],[role=tab][aria-selected=true],nav [aria-current=page]';
  const active = labels => all(headings).some(e => vis(e) && matches(e, labels));
  function menuLabel(labels, preferText = false) {
    const selector = buttons + ',li,div,span,p,strong,b,em,label,dt,dd,td,summary,[aria-expanded],[onclick],[title],[aria-label]';
    let candidates = all(selector).filter(e => usable(e) && matches(e, labels));
    if (preferText) {
      const exact = candidates.filter(e => labels.map(norm).includes(norm(e.innerText)));
      candidates = exact.length ? exact : candidates.filter(e => !norm(e.innerText));
    }
    // A legenda pode ser só texto dentro do item que recebe o evento.
    // Prefira a barra lateral ao cartão de mesmo nome na página Overview.
    const sidebar = e => {
      if (e.closest('nav,aside,[role=navigation],[role=menu],[role=tree]')) return true;
      if (e.closest('main,[role=main]')) return false;
      for (let p=e.parentElement; p && p !== e.ownerDocument.body; p=p.parentElement) {
        if (p.querySelector('main,[role=main]')) break;
        const s = norm(p.innerText);
        if (s.includes('overview') && (s.includes('person management') || s.includes('event search'))) return true;
      }
      return false;
    };
    const inMenu = candidates.filter(sidebar);
    const pool = inMenu.length ? inMenu : candidates.filter(e =>
      !e.closest(headings) || e.closest(buttons + ',summary,[aria-expanded],[onclick]'));
    const leaves = pool.filter(e => !pool.some(other => other !== e && e.contains(other)));
    const controls = new Map();
    for (const leaf of leaves) {
      const item = leaf.closest(buttons + ',li,[onclick]') || leaf;
      if (!controls.has(item) || labels.map(norm).includes(norm(leaf.innerText))) controls.set(item,leaf);
    }
    return one([...controls.values()]);
  }
  function menuSelected(labels) {
    if (active(labels)) return true;
    const item = menuLabel(labels);
    const mark = item?.closest('[aria-current=page],[aria-selected=true],[aria-expanded=true],.active,.is-active,.selected,.router-link-active');
    return !!mark && (mark === item || matches(mark,labels));
  }
  function noticeTab() {
    // No Preference, as duas abas são irmãs. A barra lateral pode repetir o nome.
    const selector = buttons + ',li,span,div,label';
    const screens = all(selector).filter(e => usable(e) && dados.tela.map(norm).includes(norm(e.innerText)));
    const notices = all(selector).filter(e => usable(e) && dados.rotulos.map(norm).includes(norm(e.innerText)));
    const leaves = notices.filter(e => !notices.some(child => e !== child && e.contains(child)));
    const siblings = new Set();
    for (const screen of screens) {
      for (let bar = screen.parentElement; bar && !bar.matches('body,main,[role=main]'); bar = bar.parentElement) {
        if (bar.querySelector('main,[role=main],[role=tabpanel],form')) break;
        const peers = leaves.filter(e => bar.contains(e));
        if (peers.length) {
          if (peers.length === 1) siblings.add(peers[0]);
          break;
        }
      }
    }
    return siblings.size ? one([...siblings]) : menuLabel(dados.rotulos,true);
  }
  function menuTarget(labels, expand, preferText = false) {
    let el = menuLabel(labels, preferText);
    if (!el) return null;
    if (expand) {
      // Alguns firmwares usam uma seta separada do texto para abrir o submenu.
      const row = el.closest('li,[role=treeitem],[role=menuitem]') || el.parentElement;
      const toggle = row && one(all('[aria-expanded=false]',row).filter(e =>
        usable(e) && (!e.closest('li,[role=treeitem],[role=menuitem]') ||
          e.closest('li,[role=treeitem],[role=menuitem]') === row)));
      if (toggle && (toggle.contains(el) || labels.map(norm).includes(norm(row.innerText)))) el = toggle;
    }
    return el;
  }
  function menuPoint(labels, expand) {
    const el = menuTarget(labels, expand);
    if (!el) return null;
    el.scrollIntoView({block:'nearest',inline:'nearest',behavior:'instant'});
    const rect = el.getBoundingClientRect();
    let doc = el.ownerDocument, win = doc.defaultView;
    let x = (Math.max(0,rect.left) + Math.min(win.innerWidth,rect.right)) / 2;
    let y = (Math.max(0,rect.top) + Math.min(win.innerHeight,rect.bottom)) / 2;
    const hit = doc.elementFromPoint(x,y);
    if (!hit || !(el.contains(hit) || (hit.contains(el) && matches(hit,labels)))) return null;
    while (win.frameElement) {
      const frame = win.frameElement, box = frame.getBoundingClientRect();
      x = box.left + (frame.clientLeft + x) * box.width / frame.offsetWidth;
      y = box.top + (frame.clientTop + y) * box.height / frame.offsetHeight;
      doc = frame.ownerDocument;
      if (doc.elementFromPoint(x,y) !== frame) return null;
      win = doc.defaultView;
    }
    return {x,y};
  }
  function smartSettingsVisible() {
    const titles = ['face recognition parameters','parâmetros de reconhecimento facial'].map(norm);
    return all('h1,h2,h3,h4,h5,legend,[role=heading],span,div,p,b,strong,label,td').some(e =>
      titles.includes(norm(e.textContent)) && vis(e) && titles.includes(norm(e.innerText)));
  }
  function scope(el) {
    // Atuar no conteúdo do painel, inclusive em formulários dentro de iframes.
    return el?.closest('dialog,[role=dialog],form,section,[role=tabpanel],main,[role=main]') || null;
  }
  const save = ['Save','Salvar'];
  const sleepNames = ['Sleep','Repouso','Suspensão'];
  const associated = e => [...(e.labels || [])].map(l => l.innerText).concat([
    e.getAttribute('aria-label'), e.placeholder, e.title,
    ...String(e.getAttribute('aria-labelledby') || '').split(/\s+/).map(id => e.ownerDocument.getElementById(id)?.innerText)
  ]).map(norm);
  function sleepControl() {
    const semantic = 'input[type=checkbox],[role=switch],[role=checkbox],[aria-pressed]';
    const named = all(semantic).filter(e =>
      (vis(e) || [...(e.labels || [])].some(vis)) && associated(e).some(v => sleepNames.map(norm).includes(v)));
    if (named.length) return one(named.filter(e => !named.some(p => p !== e && p.contains(e))));

    // O painel também pode exibir o texto Sleep em uma coluna ao lado da chave.
    const labels = all('label,span,div,td,th,dt,p').filter(e =>
      vis(e) && sleepNames.map(norm).includes(norm(e.innerText)));
    const controls = new Set();
    for (const label of labels.filter(e => !labels.some(child => child !== e && e.contains(child)))) {
      for (let row = label; row && row !== label.ownerDocument.body; row = row.parentElement) {
        // Pare antes de incluir outra linha do formulário, como "Sleep after".
        if (!sleepNames.map(norm).includes(norm(row.innerText))) break;
        let found = all(semantic + ',[class*="switch" i],[class*="toggle" i]',row).filter(vis);
        if (!found.length) found = all('button,a,span,div,i',row).filter(e => thumbState(e) !== null);
        // A trilha, o botão e o indicador interno podem compor uma única chave.
        const outer = found.filter(e => !found.some(p => p !== e && p.contains(e)));
        if (!outer.length) continue;
        if (outer.length !== 1) return null;
        controls.add(outer[0]);
        break;
      }
    }
    return one([...controls]);
  }
  function thumbState(track) {
    // Chave horizontal sem atributos de estado: confira a posição do indicador circular.
    const box = track.getBoundingClientRect();
    const style = el => el.ownerDocument.defaultView.getComputedStyle(el);
    if (box.height <= 0 || box.width < 1.5 * box.height || box.width > 3 * box.height ||
        style(track).direction !== 'ltr' || !vis(track)) return null;
    const thumbs = [...track.children].filter(el => {
      const r = el.getBoundingClientRect();
      return vis(el) && parseFloat(style(el).borderTopLeftRadius) > 0 &&
        r.height >= box.height * 0.6 && r.height <= box.height &&
        Math.abs(r.width - r.height) <= 2 && r.left >= box.left - 1 && r.right <= box.right + 1 &&
        Math.abs((r.top + r.bottom) - (box.top + box.bottom)) <= 4;
    });
    const thumb = one(thumbs);
    if (!thumb) return null;
    const r = thumb.getBoundingClientRect();
    const left = r.left - box.left, right = box.right - r.right;
    if (Math.min(left,right) > box.height / 4 || Math.abs(left-right) < box.height / 2) return null;
    return left > right;
  }
  function state(el) {
    if (!el) return null;
    for (const attr of ['aria-checked','aria-pressed']) {
      if (el.hasAttribute(attr)) return ({true:true,false:false})[el.getAttribute(attr)] ?? null;
    }
    const input = el.matches('input[type=checkbox]') ? el : one(all('input[type=checkbox]',el));
    if (input) return input.indeterminate ? null : input.checked;
    const semantic = one(all('[aria-checked],[aria-pressed]',el));
    if (semantic) return state(semantic);
    for (const [base,checked] of [['el-switch','is-checked'],['ant-switch','ant-switch-checked'],
        ['ivu-switch','ivu-switch-checked'],['layui-form-switch','layui-form-onswitch']]) {
      if (el.classList.contains(base)) return el.classList.contains(checked);
    }
    if (el.matches('.switch-on,.switch-open,.switch-checked,.toggle-on,.is-checked')) return true;
    if (el.matches('.switch-off,.switch-close,.switch-closed,.toggle-off,.is-unchecked')) return false;
    return thumbState(el);
  }
  function fileMatches(root) {
    // Nome exato, incluindo extensão. Exclui campos de upload e miniaturas ocultas.
    const name = dados.nome;
    return all('img,[title],[aria-label],span,td,li,div,button,a,label,figcaption',root).filter(e => vis(e) &&
      [e.title,e.alt,e.getAttribute('aria-label'),!e.children.length && e.textContent?.trim()].includes(name));
  }
<<<<<<< Updated upstream
  const dialog = () => one(all('dialog[open],[role=dialog],.modal.show').filter(vis));
  const importLabels = ['Import','Importar','Upload','Enviar imagem','Import Image','Importar imagem'];
  const modalSelector = 'dialog[open],[role=dialog],.modal.show,.el-dialog,.ant-modal,.layui-layer';
  function libraryRoot() {
    const libraryModal = one(all(modalSelector).filter(d => vis(d) &&
      (matches(d,dados.biblioteca) || all(headings + ',div,span',d).some(e => vis(e) && matches(e,dados.biblioteca)))));
    if (libraryModal) return libraryModal;
    const anchors = all(headings).filter(e => vis(e) && matches(e,dados.biblioteca));
    for (const el of anchors) {
      const linked = el.hasAttribute('aria-controls') && el.ownerDocument.getElementById(el.getAttribute('aria-controls'));
      if (linked && vis(linked)) return linked;
      if (!el.matches('[role=tab]') && scope(el)) return scope(el);
    }
    if (!menuSelected(dados.biblioteca)) return null;
    const doc = (anchors[0] || menuLabel(dados.biblioteca))?.ownerDocument;
    if (!doc) return null;
    return one(all('[role=tabpanel]',doc).filter(vis)) || one(all('main,[role=main]',doc).filter(vis)) || doc.body;
  }
  function uploadDialog(root) {
    return one(all(modalSelector,root.ownerDocument).filter(d => vis(d) && !d.contains(root) &&
      (d.querySelector('input[type=file]') || all(headings,d).some(e => matches(e,importLabels)))));
=======
  const modal = 'dialog[open],[role=dialog],.modal.show,.el-dialog,.ant-modal,.layui-layer';
  const dialogs = () => all(modal).filter(vis);
  const importLabels = ['Import','Importar','Upload','Import Image','Importar imagem','+ Import','+ Importar'];
  function libraryModal() {
    return one(dialogs().filter(d => matches(d,dados.biblioteca) ||
      all(headings + ',div,span',d).some(e => vis(e) && matches(e,dados.biblioteca))));
  }
  function libraryRoot() {
    const popup = libraryModal();
    if (popup) return popup;
    const anchor = one(all(headings).filter(e => vis(e) && matches(e,dados.biblioteca)));
    const linked = anchor?.ownerDocument.getElementById(anchor.getAttribute('aria-controls'));
    if (linked && vis(linked)) return linked;
    if (scope(anchor)) return scope(anchor);
    const doc = menuSelected(dados.biblioteca) && menuLabel(dados.biblioteca)?.ownerDocument;
    return doc && (one(all('[role=tabpanel]',doc).filter(vis)) || one(all('main',doc).filter(vis)) || doc.body);
  }
  function uploadDialog(root) {
    return one(dialogs().filter(d => d.ownerDocument === root.ownerDocument && !d.contains(root) &&
      (d.querySelector('input[type=file]') || matches(d,importLabels) ||
        all(headings + ',.el-dialog__title,.ant-modal-title',d).some(e => matches(e,importLabels)))));
>>>>>>> Stashed changes
  }
  function setValue(el, value) {
    const win = el.ownerDocument.defaultView;
    const proto = el.tagName === 'SELECT' ? win.HTMLSelectElement.prototype : win.HTMLInputElement.prototype;
    Object.getOwnPropertyDescriptor(proto,'value').set.call(el,value);
    el.dispatchEvent(new win.Event('input',{bubbles:true}));
    el.dispatchEvent(new win.Event('change',{bubbles:true}));
  }
  function loginHandler() {
    const password = one(all('input[type=password]').filter(vis));
    if (!password || !usable(password) || password.readOnly || password.autocomplete === 'new-password') return null;
    const doc = password.ownerDocument;
    if (doc.location.origin !== location.origin) return null;
    const form = password.form;
    const root = form || password.closest('[role=form],dialog,[role=dialog],main') || doc.body;
    const users = all('input:not([type]),input[type=text],input[type=email],select',root).filter(vis);
    const identified = users.filter(e => [e.name,e.id,e.autocomplete,...associated(e)].some(n =>
      /^(username|user|userid|usuario|nome de usuario|loginname|account|conta|login|user name)$/i.test(norm(n))));
    const user = one(identified.length ? identified : users);
    if (!user || ((user.readOnly || user.disabled) && user.value !== 'admin')) return null;
    const labels = ['Login','Log in','Sign in','Entrar','Acessar','Iniciar sessão','Conectar'];
    const candidates = all(buttons + ',[onclick]',root).filter(vis);
    const named = candidates.filter(e => matches(e,labels) || labels.map(norm).includes(norm(e.value)));
    const submit = one(named.length ? named : candidates.filter(e => form && e.form === form && e.type === 'submit'));
    if (!submit || (submit.form && submit.form !== form)) return null;
    if (!named.length && !matches(root.querySelector('h1,h2,legend') || root,labels) &&
        password.autocomplete !== 'current-password') return null;
    if (user.tagName === 'SELECT' && ![...user.options].some(o => o.value === 'admin' && !o.disabled)) return null;
    function destinationOK() {
      if (!form) return !submit.hasAttribute('formaction');
      const method = submit.getAttribute('formmethod') || form.method;
      if (submit.type === 'submit' && password.name && norm(method) === 'get') return false;
      const target = submit.getAttribute('formaction') || form.getAttribute('action') || doc.URL;
      return new URL(target,doc.baseURI).origin === location.origin;
    }
    if (!destinationOK()) return null;
    return async function(secret) {
      if (![password,user,submit].every(e => e.isConnected && vis(e)) || !destinationOK()) return false;
      if (user.value !== 'admin') setValue(user,'admin');
      setValue(password,secret);
      // Alguns painéis habilitam Entrar depois de validar os campos.
      for (let i=0; i<10 && !usable(submit); i++) await new Promise(resolve => setTimeout(resolve,100));
      if (user.value !== 'admin' || !password.value || !usable(submit) || !destinationOK() ||
          ![password,user,submit].every(e => e.isConnected)) return false;
      submit.click();
      return true;
    };
  }
  const addTitles = ['Add Program','Adicionar programa','+ Add Program','+ Adicionar programa'];
  const editorTitles = [...addTitles,'Edit Program','Editar programa','HD'];
  function field() {
    const inputs = all('input:not([type]),input[type=text]').filter(usable);
    const named = inputs.filter(e => [...associated(e),norm(e.name),norm(e.previousElementSibling?.innerText)]
      .some(n => /^(program[ _-]?name|nome do programa|nome da programacao)\s*[:*]?$/.test(n)));
    if (named.length) return one(named);
    const form = one(dialogs().filter(d => matches(d,editorTitles) ||
      all(headings + ',.el-dialog__title,.ant-modal-title',d).some(e => vis(e) && matches(e,editorTitles))));
    return form && one(inputs.filter(e => form.contains(e)));
  }
  function programRoot() {
    const f = field();
    if (f && f.value !== 'HD') return null;
    const anchor = f || one(all(headings).filter(e => vis(e) && matches(e,['HD'])));
    return anchor?.closest(modal) || anchor?.closest('form,[role=tabpanel]') || scope(anchor);
  }
  const editor = () => !!programRoot();
  const hdRows = () => all('tr,[role=row]').filter(r => vis(r) && [...r.children].some(c => c.innerText?.trim() === 'HD'));
  function openHD() {
    if (editor()) return true;
    const rows = hdRows();
    if (rows.length > 1) return false;
    const edit = rows.length ? action(['Edit','Editar'],rows[0]) || action(['HD'],rows[0]) : action(['HD']);
    return click(edit);
  }
  function addImageButton(root, labels = ['Add image','Adicionar imagem']) {
    const allowed = [...labels,'+','＋'];
    const named = action(allowed,root);
    if (named) return named;
    const icons = all('.el-icon-plus,.anticon-plus,.fa-plus,.ivu-icon-md-add,.h-icon-plus,.h-icon-add,.icon-plus,.icon-add,[data-icon=plus],use[href$="#icon-plus"]',root).filter(vis);
    const targets = icons.map(e => e.closest(buttons + ',label,[onclick]') || e.closest('svg')?.parentElement || e);
    return one([...new Set(targets)].filter(e => root.contains(e) && usable(e) &&
      (!names(e).length || matches(e,allowed))));
  }
  function picker() {
    const root = programRoot();
    const choices = dialogs().filter(d => d !== root && !(root && d.contains(root)));
    return one(choices.filter(d => !choices.some(inner => d !== inner && d.contains(inner))));
  }
  function imageInProgram() {
    const root = programRoot();
    return !!root && !picker() && fileMatches(root).some(e =>
      !e.closest('[role=listbox]') && (!e.closest(modal) || e.closest(modal).contains(root)));
  }
  function schedule() {
    const keys = {
      day:['day','dia','dia da semana','weekday'], program:['program','programa','program name','nome do programa'],
      start:['start','inicio','start time','hora inicial'], end:['end','fim','end time','hora final']
    };
    const days = [['sun','sunday','domingo','dom'],['mon','monday','segunda','segunda-feira','seg'],
      ['tue','tuesday','terca','terca-feira','ter'],['wed','wednesday','quarta','quarta-feira','qua'],
      ['thu','thursday','quinta','quinta-feira','qui'],['fri','friday','sexta','sexta-feira','sex'],
      ['sat','saturday','sabado','sab']];
    const tables = all('table').filter(t => vis(t) && t.rows.length >= 2);
    const plans = [];
    for (const t of tables) {
      const headers = [...t.rows[0].cells].map(c => norm(c.innerText));
      const cols = Object.fromEntries(Object.entries(keys).map(([key,names]) => [key,headers.findIndex(h => names.includes(h))]));
      if (Object.values(cols).some(i => i < 0)) continue;
      const rows = [...t.rows].slice(1).filter(vis);
      if (rows.length !== 7) return null;
      const plan = rows.map(r => {
        const cell = key => r.cells[cols[key]];
        if (Object.keys(keys).some(k => !cell(k))) return null;
        const control = k => one([...cell(k).querySelectorAll('select,input:not([type=hidden])')].filter(vis));
        const p = control('program'), s = control('start'), e = control('end');
        const program = (p?.selectedOptions?.[0]?.textContent ?? cell('program').innerText).trim();
        const start = (s?.value ?? cell('start').innerText).trim(), end = (e?.value ?? cell('end').innerText).trim();
        const day = days.findIndex(a => a.includes(norm(cell('day').innerText)));
        const ok = program === 'HD' && /^00:00(:00)?$/.test(start) && /^24:00(:00)?$/.test(end);
        const hd = p?.options && one([...p.options].filter(o => !o.disabled && o.text.trim() === 'HD'));
        const editable = hd && [s,e].every(i => i?.tagName === 'INPUT' && ['time','text'].includes(i.type) && !i.readOnly) &&
          e.type !== 'time' && [p,s,e].every(usable);
        return {p,s,e,hd,day,program,ok,editable};
      });
      if (plan.some(r => !r || r.day < 0) || new Set(plan.map(r => r.day)).size !== 7) return null;
      plans.push(plan);
    }
    return one(plans);
  }
  switch (acao) {
    case 'ready': return document.readyState !== 'loading';
    case 'loginHandler': return loginHandler();
    case 'access': {
      if (all('input[type=password]').some(vis)) return 'login';
      const menus = ['Configuration','Configuração','Configurações','Notice Publication','Publicação de avisos',
        'Screen Display','Logout','Log out','Sair'];
      if (active(menus) || all(buttons + ',li,span').some(e => vis(e) && matches(e,menus)) ||
          menuLabel(['Configuration','Configuração','Configurações'])) return 'panel';
      return null;
    }
    case 'success': return all('[role=status],[role=alert],.toast,.el-message,.ant-message-notice').some(e => vis(e) &&
      /^(saved successfully|successfully saved|save successful|salvo com sucesso|salva com sucesso|alterações salvas|configurações salvas)[.!]?$/i.test(e.innerText.trim()));
    case 'screenSaveResult': {
      const messages = all('[role=status],[role=alert],[role=alertdialog],dialog[open],[role=dialog],.toast,.el-message,.ant-message-notice,.layui-layer-content,.el-message-box,.tips');
      for (const el of messages.filter(vis)) {
        const msg = norm(el.innerText).replace(/\s+(ok|fechar|close)$/,'').trim();
        if (/\b(failed|failure|error|falha|erro|not saved|nao (foi )?salv[oa])\b/.test(msg)) return 'falha';
        if (/^(?:(?:parameters|settings|configuration)\s+)?(?:saved(?: successfully)?|save successful|save succeeded|successfully saved|(?:alteracoes |configuracoes )?salv[oa]s?(?: com sucesso)?)[.!]?$/.test(msg)) {
          const popup = el.closest(modal + ',[role=alertdialog],.el-message-box');
          if (popup) click(action(['OK','Close','Fechar'],popup));
          return 'salvo';
        }
      }
      return null;
    }
    case 'clickNotice': return click(noticeTab());
    case 'noticeReached': {
      const el = noticeTab();
      const selected = el?.closest('[role=tab],li,a,button') || el;
      if (selected?.matches('[aria-selected=true],[aria-current=page],.active,.is-active,.selected')) return true;
      return !sleepControl() && (active(dados.rotulos) || !!action(addTitles) || !!menuLabel(dados.biblioteca,true));
    }
    case 'active': return dados.rotulos.some(n => dados.biblioteca.includes(n)) ? !!libraryRoot() : active(dados.rotulos);
    case 'menuPoint': return menuPoint(dados.rotulos, dados.proximos?.length);
    case 'clickScreenMenu': {
      const el = menuTarget(dados.rotulos, dados.proximos?.length, true);
      if (!el || el.closest(':disabled,[aria-disabled=true]')) return false;
      // O clique segue o elemento mesmo se o menu rolar ou mudar de posição.
      return click(el);
    }
    case 'screenReached': {
      if (dados.proximos?.length) {
        if (dados.preference && !dados.clicado && smartSettingsVisible()) return false;
        return !!menuLabel(dados.proximos,true);
      }
      return !smartSettingsVisible() && (menuSelected(dados.rotulos) || state(sleepControl()) !== null);
    }
    case 'menuReached': return dados.proximos?.length
      ? !!menuLabel(dados.proximos)
      : dados.tela === 'library' ? !!libraryRoot()
      : menuSelected(dados.rotulos) || state(sleepControl()) !== null;
    case 'click': return click(action(dados.rotulos));
    case 'sleep': return state(sleepControl());
    case 'sleepReady': return state(sleepControl()) !== null;
    case 'sleepOff': return state(sleepControl()) === false;
    case 'disable': {
      if (smartSettingsVisible()) return false;
      const el = sleepControl();
      if (state(el) !== true || el.closest(':disabled,[aria-disabled=true],.is-disabled')) return false;
      const target = el.matches('input,[role=switch],[role=checkbox],[aria-pressed]') ? el :
        one(all('[role=switch],[role=checkbox],[aria-pressed]',el).filter(vis)) || one(all('input[type=checkbox]',el)) || el;
      return !target.matches(':disabled,[aria-disabled=true]') && click(target);
    }
    case 'saveSleep': {
      if (smartSettingsVisible()) return false;
      const el = sleepControl();
      if (state(el) !== false) return false;
      const root = el.closest('form,section,fieldset,[role=tabpanel]');
      return click((root && action(save,root)) || action(save,el.ownerDocument));
    }
    case 'media': {
      const root = libraryRoot();
      return !!root && !uploadDialog(root) && fileMatches(root).some(e =>
<<<<<<< Updated upstream
        !e.closest('label,[role=alert],[role=status],.el-upload-list,.ant-upload-list'));
    }
    case 'openImport': {
      const root = libraryRoot();
      return !!root && !uploadDialog(root) && click(action(importLabels,root));
    }
    case 'confirmImport': {
      const root = libraryRoot();
      const d = root && uploadDialog(root);
=======
        !e.closest('label,[role=status],[role=alert],.el-upload-list,.ant-upload-list'));
    }
    case 'openImport': {
      const root = libraryRoot();
      return !!root && !uploadDialog(root) && click(action(importLabels,root) || addImageButton(root,importLabels));
    }
    case 'uploadPlus': {
      const root = libraryRoot(), d = root && uploadDialog(root);
      return !!d && click(addImageButton(d,['Choose file','Selecionar arquivo','Browse','Procurar']));
    }
    case 'confirmImport': {
      const root = libraryRoot(), d = root && uploadDialog(root);
>>>>>>> Stashed changes
      return !!d && click(action([...importLabels,'OK','Confirm','Confirmar'],d));
    }
    case 'file': {
      const root = libraryRoot();
      if (!root) return null;
      return one(all('input[type=file]:not(:disabled)',uploadDialog(root) || root)
        .filter(e => !e.accept || /image|\.(jpg|jpeg|png|bmp|gif|webp|tiff?)/i.test(e.accept)));
    }
    case 'editor': return editor();
    case 'openHD': return openHD();
    case 'programList': return !dialogs().length && !!action(addTitles);
    case 'closeLibrary': {
      const d = libraryModal();
      return !!d && click(action(['Close','Fechar','Back','Voltar','×'],d));
    }
    case 'checkProgramList': return hdRows().length > 0 || !!action(['HD']) ||
      all('.pagination,.el-pagination,.ant-pagination,[aria-label*=pagination i],[aria-busy=true]').some(vis);
    case 'addProgram': return !dialogs().length && click(action(addTitles));
    case 'nameHD': {
      const f = field();
      if (!f || f.readOnly) return false;
      setValue(f,'HD'); return f.value === 'HD';
    }
    case 'confirmName': {
      const root = programRoot();
      return !!root && root.matches(modal) && !addImageButton(root) &&
        click(action(['OK','Next','Avançar','Confirm','Confirmar'],root));
    }
    case 'inProgram': return imageInProgram();
    case 'addImage': { const root = programRoot(); return !!root && !picker() && click(addImageButton(root)); }
    case 'pick': {
      const d = picker();
      if (!d) return false;
      const targets = fileMatches(d).map(e => {
        const row = e.closest('tr,[role=row],li,figure');
        const check = row && one(all('input[type=checkbox],input[type=radio]',row));
        return check || e.closest('button,a,label,[role=option],[role=button],[onclick]') || row || e;
      });
      const target = one([...new Set(targets)]);
      return !!target && !target.matches(':disabled,[aria-disabled=true]') &&
        (target.checked === true || target.getAttribute('aria-selected') === 'true' || click(target));
    }
    case 'acceptPicker': { const d = picker(); return !!d && click(action(['OK','Confirm','Confirmar','Adicionar','Add'],d)); }
    case 'saveProgram': { const root = programRoot(); return !!root && !picker() && click(action(save,root)); }
    case 'schedule': {
      const plan = schedule();
      if (!plan) return null;
      const conflicts = [...new Set(plan.filter(r => r.program && !['hd','-','nenhum','none','sem programa'].includes(norm(r.program))).map(r => r.program))];
      return {ok:plan.every(r => r.ok), editable:plan.every(r => r.ok || r.editable), conflicts};
    }
    case 'fillSchedule': {
      const plan = schedule();
      if (!plan || !plan.every(r => r.ok || r.editable)) return false;
      const allowed = dados.aprovados || [];
      if (plan.some(r => r.program && !['hd','-','nenhum','none','sem programa'].includes(norm(r.program)) && !allowed.includes(r.program))) return false;
      for (const row of plan.filter(r => !r.ok)) {
        if (![row.p,row.s,row.e].every(e => e.isConnected)) return false;
        setValue(row.p,row.hd.value); setValue(row.s,'00:00'); setValue(row.e,'24:00');
      }
      return schedule()?.every(r => r.ok) || false;
    }
    case 'saveSchedule': return schedule()?.every(r => r.ok) && click(action(save));
  }
  return null;
}
