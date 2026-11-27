// Executado na aba do terminal pelo Publicar-Tela.ps1. Somente controles da página.
function painel(acao, dados) {
  const norm = v => String(v ?? '').normalize('NFD').replace(/[\u0300-\u036f]/g, '')
    .trim().replace(/\s+/g, ' ').toLowerCase();
  const origin = new URL(dados.url);
  if (origin.protocol !== 'https:' || location.origin !== origin.origin) return null;
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
  function menuLabel(labels) {
    const selector = buttons + ',li,div,span,p,strong,b,em,label,dt,dd,td,summary,[aria-expanded],[onclick],[title],[aria-label]';
    const candidates = all(selector).filter(e => usable(e) && matches(e, labels));
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
  function menuPoint(labels, expand) {
    let el = menuLabel(labels);
    if (!el) return null;
    if (expand) {
      // Alguns firmwares usam uma seta separada do texto para abrir o submenu.
      const row = el.closest('li,[role=treeitem],[role=menuitem]') || el.parentElement;
      const toggle = row && one(all('[aria-expanded=false]',row).filter(e =>
        usable(e) && (!e.closest('li,[role=treeitem],[role=menuitem]') ||
          e.closest('li,[role=treeitem],[role=menuitem]') === row)));
      if (toggle && (toggle.contains(el) || matches(row,labels))) el = toggle;
    }
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
  const dialog = () => one(all('dialog[open],[role=dialog],.modal.show').filter(vis));
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
  const editorTitles = ['HD','Edit Program','Editar programa','Add Program','Adicionar programa'];
  const field = () => one(all('input:not([type]),input[type=text]').filter(e => usable(e) &&
    associated(e).some(n => ['program name','nome do programa','nome da programacao'].includes(n))));
  const editor = () => (field()?.value === 'HD' || active(['HD']) ||
    (active(editorTitles) && all('input').some(e => vis(e) && e.value === 'HD')));
  function programRoot() {
    if (!editor()) return null;
    if (field()?.value === 'HD') return scope(field());
    return scope(one(all(headings).filter(e => vis(e) && matches(e,['HD']))));
  }
  function openHD() {
    if (editor()) return true;
    const rows = all('tr,[role=row]').filter(r => vis(r) && [...r.children].some(c => c.innerText?.trim() === 'HD'));
    if (rows.length > 1) return false;
    const edit = rows.length ? action(['Edit','Editar','HD'],rows[0]) : action(['HD']);
    return click(edit);
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
    case 'active': return active(dados.rotulos);
    case 'menuPoint': return menuPoint(dados.rotulos, dados.proximos?.length);
    case 'menuReached': return dados.proximos?.length
      ? !!menuLabel(dados.proximos)
      : menuSelected(dados.rotulos) || state(sleepControl()) !== null;
    case 'click': return click(action(dados.rotulos));
    case 'sleep': return state(sleepControl());
    case 'sleepReady': return state(sleepControl()) !== null;
    case 'sleepOff': return state(sleepControl()) === false;
    case 'disable': {
      const el = sleepControl();
      if (state(el) !== true || el.closest(':disabled,[aria-disabled=true],.is-disabled')) return false;
      const target = el.matches('input,[role=switch],[role=checkbox],[aria-pressed]') ? el :
        one(all('[role=switch],[role=checkbox],[aria-pressed]',el).filter(vis)) || one(all('input[type=checkbox]',el)) || el;
      return !target.matches(':disabled,[aria-disabled=true]') && click(target);
    }
    case 'saveSleep': {
      const el = sleepControl();
      if (state(el) !== false) return false;
      const root = el.closest('form,section,fieldset,[role=tabpanel]');
      return click((root && action(save,root)) || action(save,el.ownerDocument));
    }
    case 'media': {
      const root = scope(one(all(headings).filter(e => vis(e) && matches(e,dados.biblioteca))));
      return !!root && fileMatches(root).length > 0;
    }
    case 'file': {
      const root = scope(one(all(headings).filter(e => vis(e) && matches(e,dados.biblioteca))));
      if (!root) return null;
      return one(all('input[type=file]:not(:disabled)',root)
        .filter(e => !e.accept || /image|\.(jpg|jpeg|png|bmp|gif|webp|tiff?)/i.test(e.accept)));
    }
    case 'editor': return editor();
    case 'openHD': return openHD();
    case 'nameHD': {
      const f = field();
      if (!f || (f.value && f.value !== 'HD')) return false;
      setValue(f,'HD'); return f.value === 'HD';
    }
    case 'inProgram': {
      const root = programRoot();
      return !!root && !dialog() && fileMatches(root).length > 0;
    }
    case 'addImage': { const root = programRoot(); return !!root && click(action(['+','Add image','Adicionar imagem'],root)); }
    case 'pick': {
      const d = dialog();
      if (!d) return false;
      const targets = fileMatches(d).map(e => e.closest('button,a,label,[role=option],[role=button]') || (e.onclick ? e : null));
      return click(one([...new Set(targets.filter(Boolean))]));
    }
    case 'acceptPicker': { const d = dialog(); return d && click(action(['OK','Confirm','Confirmar','Adicionar','Add'],d)); }
    case 'saveProgram': { const root = programRoot(); return !!root && !dialog() && click(action(save,root)); }
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
