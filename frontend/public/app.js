const $ = (s) => document.querySelector(s);
const esc = (v) => String(v ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const data = (d) => (d ? d.split('-').reverse().join('/') : '-');
const reais = (v) => Number(v).toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' });

let auth = sessionStorage.getItem('auth');
let cache = {};
let nota = null;

async function api(path, { method = 'GET', body } = {}) {
  const r = await fetch('/api' + path, {
    method,
    headers: { Authorization: 'Basic ' + auth, 'Content-Type': 'application/json' },
    body: body ? JSON.stringify(body) : undefined,
  });
  if (r.status === 401) { sair(); throw new Error('Sessão expirada. Entre novamente.'); }
  const txt = await r.text();
  const json = txt ? JSON.parse(txt) : null;
  if (!r.ok) throw new Error((json && (json.erro || json.message)) || 'Erro ' + r.status);
  return json;
}

let timer;
function aviso(msg, erro = false) {
  const t = $('#toast');
  t.textContent = msg;
  t.className = 'show' + (erro ? ' err' : '');
  clearTimeout(timer);
  timer = setTimeout(() => (t.className = ''), 5000);
}

/* ---------- mascaras de campo ---------- */
function mascaraCpf(v) {
  const d = v.replace(/\D/g, '').slice(0, 11);
  return d.replace(/^(\d{3})(\d)/, '$1.$2').replace(/^(\d{3})\.(\d{3})(\d)/, '$1.$2.$3').replace(/\.(\d{3})(\d)/, '.$1-$2');
}
document.addEventListener('input', (e) => {
  const el = e.target;
  if (el.dataset.num !== undefined) el.value = el.value.replace(/\D/g, '');
  if (el.dataset.cpf !== undefined) el.value = mascaraCpf(el.value);
});

/* ---------- login ---------- */
$('#loginForm').addEventListener('submit', async (e) => {
  e.preventDefault();
  const f = new FormData(e.target);
  auth = btoa(f.get('email') + ':' + f.get('senha'));
  try {
    const me = await api('/me');
    sessionStorage.setItem('auth', auth);
    entrar(me);
  } catch (err) {
    auth = null;
    $('#loginErro').textContent = err.message === 'Sessão expirada. Entre novamente.'
      ? 'E-mail ou senha incorretos.' : err.message;
  }
});

function entrar(me) {
  $('#login').hidden = true;
  $('#app').hidden = false;
  $('#quem').textContent = me.nome;
  ir('livros');
}

function sair() {
  sessionStorage.removeItem('auth');
  auth = null;
  $('#app').hidden = true;
  $('#login').hidden = false;
  $('#loginErro').textContent = '';
}
$('#sair').addEventListener('click', sair);

/* ---------- navegacao ---------- */
const telas = { livros, leitores, emprestimos, atrasados };

function ir(nome) {
  nota = null;
  document.querySelectorAll('#nav button').forEach((b) => b.classList.toggle('on', b.dataset.v === nome));
  telas[nome]().catch((e) => aviso(e.message, true));
}
$('#nav').addEventListener('click', (e) => { if (e.target.dataset.v) ir(e.target.dataset.v); });

const tabela = (cab, linhas, vazio) => linhas.length
  ? `<div class="tablewrap"><table><thead><tr>${cab}</tr></thead><tbody>${linhas.join('')}</tbody></table></div>`
  : `<p class="vazio">${vazio}</p>`;

/* ---------- livros ---------- */
async function livros() {
  const lista = await api('/livros');
  cache.livros = lista;
  $('#view').innerHTML = `
    <h1 class="page">Livros</h1>
    <form id="f" class="form">
      <input type="hidden" name="id">
      <label>Título<input name="titulo" required></label>
      <label>Autor<input name="autor" required></label>
      <label>ISBN<input name="isbn" data-num inputmode="numeric" maxlength="13" pattern="\\d{10}|\\d{13}" title="ISBN com 10 ou 13 números"></label>
      <label>Exemplares<input name="total" data-num inputmode="numeric" maxlength="4" required></label>
      <div class="actions">
        <button class="primary">Salvar livro</button>
        <button type="button" id="cancelar" hidden>Cancelar</button>
      </div>
    </form>
    ${tabela('<th>Título</th><th>Autor</th><th>ISBN</th><th class="num">Disponíveis</th><th class="num">Total</th><th></th>',
      lista.map((l) => `<tr><td>${esc(l.titulo)}</td><td>${esc(l.autor)}</td><td>${esc(l.isbn || '-')}</td>
        <td class="num">${l.exemplaresDisponiveis}</td><td class="num">${l.exemplaresTotal}</td>
        <td class="acoes"><button class="small" data-ed="${l.id}">Editar</button><button class="small danger" data-del="${l.id}">Excluir</button></td></tr>`),
      'Nenhum livro cadastrado. Preencha o formulário acima para adicionar o primeiro.')}`;

  const f = $('#f');
  f.addEventListener('submit', async (e) => {
    e.preventDefault();
    const v = Object.fromEntries(new FormData(f));
    const body = { titulo: v.titulo, autor: v.autor, isbn: v.isbn, exemplaresTotal: Number(v.total) };
    try {
      await api(v.id ? '/livros/' + v.id : '/livros', { method: v.id ? 'PUT' : 'POST', body });
      aviso(v.id ? 'Livro atualizado.' : 'Livro cadastrado.');
      livros();
    } catch (err) { aviso(err.message, true); }
  });
  $('#cancelar').addEventListener('click', livros);
  $('#view').onclick = async (e) => {
    const ed = e.target.dataset.ed, del = e.target.dataset.del;
    if (ed) {
      const l = cache.livros.find((x) => x.id == ed);
      f.id.value = l.id; f.titulo.value = l.titulo; f.autor.value = l.autor;
      f.isbn.value = l.isbn || ''; f.total.value = l.exemplaresTotal;
      $('#cancelar').hidden = false; f.titulo.focus();
    }
    if (del && confirm('Excluir este livro?')) {
      try { await api('/livros/' + del, { method: 'DELETE' }); aviso('Livro excluído.'); livros(); }
      catch (err) { aviso(err.message, true); }
    }
  };
}

/* ---------- leitores ---------- */
async function leitores() {
  const lista = await api('/leitores');
  $('#view').onclick = null;
  $('#view').innerHTML = `
    <h1 class="page">Leitores</h1>
    <form id="f" class="form">
      <label>Nome<input name="nome" required></label>
      <label>CPF<input name="cpf" data-cpf required inputmode="numeric" maxlength="14" placeholder="000.000.000-00" pattern="\\d{3}\\.\\d{3}\\.\\d{3}-\\d{2}" title="CPF no formato 123.456.789-00"></label>
      <label>E-mail<input name="email" type="email"></label>
      <div class="actions"><button class="primary">Salvar leitor</button></div>
    </form>
    ${tabela('<th>Nome</th><th>E-mail</th><th>Situação</th>',
      lista.map((l) => `<tr><td>${esc(l.nome)}</td><td>${esc(l.email || '-')}</td><td>${l.ativo ? 'Ativo' : 'Inativo'}</td></tr>`),
      'Nenhum leitor cadastrado. O CPF é guardado criptografado no banco.')}`;
  $('#f').addEventListener('submit', async (e) => {
    e.preventDefault();
    const v = Object.fromEntries(new FormData(e.target));
    v.cpf = v.cpf.replace(/\D/g, '');
    try { await api('/leitores', { method: 'POST', body: v }); aviso('Leitor cadastrado.'); leitores(); }
    catch (err) { aviso(err.message, true); }
  });
}

/* ---------- emprestimos ---------- */
async function emprestimos() {
  const [lv, lt, em] = await Promise.all([api('/livros'), api('/leitores'), api('/emprestimos')]);
  const opc = (arr, rot) => arr.map((x) => `<option value="${x.id}">${esc(rot(x))}</option>`).join('');
  $('#view').innerHTML = `
    <h1 class="page">Empréstimos</h1>
    ${nota ? `<p class="nota ${nota.multa ? 'multa' : ''}" role="status">${esc(nota.texto)}</p>` : ''}
    <form id="f" class="form">
      <label>Livro<select name="livroId" required>${opc(lv, (l) => l.exemplaresDisponiveis > 0 ? `${l.titulo} (${l.exemplaresDisponiveis} disp.)` : `${l.titulo} (sem exemplares)`)}</select></label>
      <label>Leitor<select name="leitorId" required>${opc(lt, (l) => l.nome)}</select></label>
      <label>Prazo em dias<input name="prazoDias" data-num inputmode="numeric" maxlength="3" value="7"></label>
      <div class="actions"><button class="primary">Registrar empréstimo</button></div>
    </form>
    ${tabela('<th>Livro</th><th>Leitor</th><th>Retirada</th><th>Devolução prevista</th><th>Situação</th><th class="num">Multa</th><th></th>',
      em.map((e) => `<tr><td>${esc(e.titulo)}</td><td>${esc(e.leitor)}</td><td>${data(e.data_emprestimo)}</td>
        <td>${data(e.data_prevista)}</td>
        <td><span class="tag ${e.status === 'ABERTO' ? 'aberto' : ''}">${e.status === 'ABERTO' ? 'Aberto' : 'Devolvido'}</span></td>
        <td class="num ${Number(e.multa) > 0 ? 'atraso' : ''}">${Number(e.multa) > 0 ? reais(e.multa) : '-'}</td>
        <td class="acoes">${e.status === 'ABERTO' ? `<button class="small" data-dev="${e.id}">Registrar devolução</button>` : ''}</td></tr>`),
      'Nenhum empréstimo registrado.')}`;
  $('#f').addEventListener('submit', async (ev) => {
    ev.preventDefault();
    const v = Object.fromEntries(new FormData(ev.target));
    try {
      await api('/emprestimos', { method: 'POST', body: { livroId: +v.livroId, leitorId: +v.leitorId, prazoDias: +v.prazoDias || 7 } });
      aviso('Empréstimo registrado.'); emprestimos();
    } catch (err) { aviso(err.message, true); }
  });
  $('#view').onclick = async (ev) => {
    const id = ev.target.dataset.dev;
    if (!id) return;
    try {
      const r = await api(`/emprestimos/${id}/devolucao`, { method: 'POST' });
      const msg = r.diasAtraso > 0 ? `Devolução registrada. ${r.diasAtraso} dias de atraso, multa de ${reais(r.multa)}.` : 'Devolução registrada. Sem multa.';
      nota = { texto: msg, multa: r.diasAtraso > 0 };
      aviso(msg);
      emprestimos();
    } catch (err) { aviso(err.message, true); }
  };
}

/* ---------- atrasados ---------- */
async function atrasados() {
  const lista = await api('/emprestimos/atrasados');
  $('#view').onclick = null;
  $('#view').innerHTML = `
    <h1 class="page">Empréstimos atrasados</h1>
    ${tabela('<th>Livro</th><th>Leitor</th><th>Devolução prevista</th><th class="num">Dias de atraso</th><th class="num">Multa estimada</th>',
      lista.map((e) => `<tr><td>${esc(e.titulo)}</td><td>${esc(e.leitor)}</td><td>${data(e.data_prevista)}</td><td class="num atraso">${e.dias_atraso}</td><td class="num atraso">${reais(e.multa_estimada)}</td></tr>`),
      'Nenhum empréstimo atrasado no momento.')}`;
}

/* ---------- inicio ---------- */
if (auth) api('/me').then(entrar).catch(() => {});
