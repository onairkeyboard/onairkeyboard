// OnAir keyboard window. The program (AutoHotkey) sends JSON messages: "init" (texts, settings,
// state, apps, links), then "state", "apps", "settings", "view", "assign" and "bug" updates.
// The page sends commands ({cmd: ...}); every change takes effect at once, there is no Save.
'use strict';

const host = window.chrome && window.chrome.webview;
const S = {
  texts: {}, settings: {}, state: {}, apps: [], links: {}, bug: null, version: '',
  view: 'main', section: 'source', showAll: false, assignMsg: {}, copied: ''
};
const ACTIONS = ['PushToTalk', 'HandsFree', 'Cancel', 'CommandMode'];
const TYPES = { PushToTalk: 'hold', CommandMode: 'hold', HandsFree: 'toggle', Cancel: 'reset' };
const LOCKS = ['ScrollLock', 'NumLock', 'CapsLock'];
const SECTIONS = ['source', 'shortcuts', 'indicator', 'sound', 'general', 'diag', 'about', 'obs'];
const VISIBLE_APPS = 9;

// --- Helpers ---

function t(key, ...args) {
  let s = S.texts[key];
  if (s === undefined) return key;
  args.forEach((v, i) => { s = s.split('{' + (i + 1) + '}').join(v); });
  return s;
}

function send(cmd, extra) {
  if (host) host.postMessage(Object.assign({ cmd }, extra || {}));
}

function set(key, value) { send('set', { key, value }); }

// h('div.class#id', {attrs, on: {click}}, ...children)
function h(spec, attrs, ...children) {
  const m = spec.match(/^([a-z0-9]+)((?:[.#][\w-]+)*)$/i);
  const el = document.createElement(m[1]);
  for (const part of (m[2].match(/[.#][\w-]+/g) || [])) {
    if (part[0] === '.') el.classList.add(part.slice(1)); else el.id = part.slice(1);
  }
  if (attrs && (typeof attrs !== 'object' || attrs instanceof Node || Array.isArray(attrs))) {
    children.unshift(attrs);
    attrs = null;
  }
  for (const [k, v] of Object.entries(attrs || {})) {
    if (v === undefined || v === null || v === false) continue;
    if (k === 'on') for (const [ev, fn] of Object.entries(v)) el.addEventListener(ev, fn);
    else if (k === 'checked' || k === 'value' || k === 'disabled' || k === 'selected') el[k] = v;
    else el.setAttribute(k, v === true ? '' : v);
  }
  for (const c of children.flat(Infinity)) {
    if (c === null || c === undefined || c === false) continue;
    el.append(c instanceof Node ? c : document.createTextNode(String(c)));
  }
  return el;
}

const SVG_NS = 'http://www.w3.org/2000/svg';
function icon(name, size) {
  const paths = {
    mic: ['rect:9,3,6,11,3', 'M5 11a7 7 0 0 0 14 0', 'M12 18v3'],
    pause: ['M9 5v14', 'M15 5v14'],
    info: ['circle:12,12,10', 'M12 16v-4', 'M12 8h.01'],
    warn: ['M10.3 3.9L1.8 18a2 2 0 0 0 1.7 3h17a2 2 0 0 0 1.7-3L13.7 3.9a2 2 0 0 0-3.4 0z', 'M12 9v4', 'M12 17h.01'],
    check: ['M20 6L9 17l-5-5'],
    arrow: ['M5 12h14', 'M13 6l6 6-6 6'],
    close: ['M6 6l12 12', 'M18 6L6 18']
  };
  const svg = document.createElementNS(SVG_NS, 'svg');
  svg.setAttribute('width', size || 20);
  svg.setAttribute('height', size || 20);
  svg.setAttribute('viewBox', '0 0 24 24');
  svg.setAttribute('fill', 'none');
  svg.setAttribute('stroke', 'currentColor');
  svg.setAttribute('stroke-width', '2');
  svg.setAttribute('stroke-linecap', 'round');
  svg.setAttribute('stroke-linejoin', 'round');
  svg.setAttribute('aria-hidden', 'true');
  for (const p of paths[name]) {
    let el;
    if (p.startsWith('rect:')) {
      const [x, y, w, hh, r] = p.slice(5).split(',');
      el = document.createElementNS(SVG_NS, 'rect');
      Object.entries({ x, y, width: w, height: hh, rx: r }).forEach(([k, v]) => el.setAttribute(k, v));
    } else if (p.startsWith('circle:')) {
      const [cx, cy, r] = p.slice(7).split(',');
      el = document.createElementNS(SVG_NS, 'circle');
      Object.entries({ cx, cy, r }).forEach(([k, v]) => el.setAttribute(k, v));
    } else {
      el = document.createElementNS(SVG_NS, 'path');
      el.setAttribute('d', p);
    }
    svg.append(el);
  }
  return svg;
}

function link(text, onclick, cls) {
  return h('a' + (cls ? '.' + cls : ''), { href: '#', on: { click: (e) => { e.preventDefault(); onclick(); } } }, text);
}

function external(text, url) { return link(text, () => send('open', { url })); }

function logos() {
  return [h('img.logo.light', { src: 'logo-bright.svg', alt: 'OnAir keyboard' }),
    h('img.logo.dark', { src: 'logo-dark.svg', alt: 'OnAir keyboard' })];
}

// The logo with the version under it (a link to About): main view and the advanced side menu
function brand() {
  return h('div.brand', logos(),
    h('a.ver', { href: '#', title: t('section.about'), on: { click: (e) => { e.preventDefault(); go('advanced', 'about'); } } },
      S.version ? 'v' + S.version : ''));
}

// hint: an explanation behind an "i" next to the label
function checkbox(text, value, onchange, hint, attrs) {
  const box = h('label.check',
    h('input', Object.assign({ type: 'checkbox', checked: !!value, on: { change: (e) => onchange(e.target.checked) } }, attrs || {})),
    h('span', text));
  return hint ? h('div.line', box, tip(hint, t('tip.more', text))) : box;
}

function note(text, kind) {
  return h('div.note' + (kind === 'ok' ? '.ok' : ''), { role: kind === 'ok' ? null : 'note' },
    icon(kind === 'ok' ? 'check' : 'warn', 20), h('span', text));
}

// --- Explanations: an "i" whose bubble shows on hover, on keyboard focus or pinned by a click
// (touch); Esc and a click elsewhere close it. Placed above the icon, below when there is no
// room, and kept 16 px inside the window. ---

let tipSeq = 0;

function tip(text, label, focusKey) {
  const id = 'tip' + (++tipSeq);
  const wrap = h('span.tip',
    h('button', { type: 'button', 'aria-label': label, 'aria-describedby': id, 'aria-expanded': 'false',
      'data-focus': focusKey || null, on: { click: (e) => { e.preventDefault(); e.stopPropagation(); pinTip(wrap); } } },
      icon('info', 18)),
    h('span.bubble', { id, role: 'tooltip' }, text));
  wrap.addEventListener('mouseenter', () => placeTip(wrap));
  wrap.addEventListener('focusin', () => placeTip(wrap));
  wrap.addEventListener('mouseleave', () => wrap.classList.remove('hush'));
  wrap.addEventListener('focusout', () => { wrap.classList.remove('hush'); closeTip(wrap); });
  return wrap;
}

function pinTip(wrap) {
  const open = !wrap.classList.contains('open');
  document.querySelectorAll('.tip.open').forEach(closeTip);
  if (!open) return;
  wrap.classList.remove('hush');
  wrap.classList.add('open');
  wrap.firstChild.setAttribute('aria-expanded', 'true');
  placeTip(wrap);
}

function closeTip(wrap) {
  wrap.classList.remove('open');
  wrap.firstChild.setAttribute('aria-expanded', 'false');
}

function placeTip(wrap) {
  const b = wrap.querySelector('.bubble');
  wrap.classList.remove('below');
  b.style.transform = '';
  b.style.removeProperty('--ax');
  requestAnimationFrame(() => {
    let r = b.getBoundingClientRect();
    if (!r.width) return;
    if (r.top < 8) {
      wrap.classList.add('below');
      r = b.getBoundingClientRect();
    }
    let dx = 0;
    if (r.right > window.innerWidth - 16) dx = window.innerWidth - 16 - r.right;
    if (r.left + dx < 16) dx = 16 - r.left;
    if (dx) {
      b.style.transform = 'translateX(' + Math.round(dx) + 'px)';
      b.style.setProperty('--ax', Math.round(24 - dx) + 'px');
    }
  });
}

document.addEventListener('keydown', (e) => {
  if (e.key !== 'Escape') return;
  const shown = document.querySelectorAll('.tip.open, .tip:hover, .tip:focus-within');
  shown.forEach((w) => { closeTip(w); w.classList.add('hush'); });
  if (shown.length) e.stopPropagation();
});
document.addEventListener('click', () => document.querySelectorAll('.tip.open').forEach(closeTip));

// Keeps the keyboard focus on the same control across a re-render
function keepFocus(fn) {
  const a = document.activeElement;
  const key = a && a.dataset ? a.dataset.focus : null;
  fn();
  if (key) {
    const el = document.querySelector('[data-focus="' + key + '"]');
    if (el) el.focus();
  }
}

// --- Views ---

function go(view, section) {
  S.view = view;
  if (section) S.section = section;
  S.copied = '';
  send('view', { view });
  send('layout', { layout: view === 'main' || view === 'support' ? 'main' : 'wide' });
  render();
  const main = document.querySelector('main, .page');
  if (main) main.scrollTop = 0;
}

function render() {
  document.documentElement.lang = S.lang || 'en';
  const app = document.getElementById('app');
  keepFocus(() => {
    app.replaceChildren(({
      main: viewMain, advanced: viewAdvanced, about: viewAdvanced, howto: viewHowto,
      support: viewSupport, bug: viewBug
    }[S.view] || viewMain)());
  });
}

// Re-renders one region if it's on screen, otherwise nothing (a scrolled list keeps its place)
function refresh(region) {
  const el = document.querySelector('[data-region="' + region + '"]');
  if (!el) return;
  const builders = { card: statusCard, apps: appsSection, shortcuts: shortcutRows, ducktest: duckButton, ducknow: duckNow };
  const scrolled = el.querySelector('.scroll');
  const top = scrolled ? scrolled.scrollTop : 0;
  keepFocus(() => {
    const fresh = builders[region]();
    el.replaceWith(fresh);
    const list = fresh.querySelector('.scroll');
    if (list) list.scrollTop = top;
  });
}

function statusCard() {
  const st = S.state, src = S.settings.source;
  let cls = '', title, sub, button = null, iconName = 'mic';
  if (st.paused) {
    title = t('card.paused'); sub = t('card.paused_sub'); iconName = 'pause';
    button = h('button.primary', { 'data-focus': 'resume', on: { click: () => send('pause') } }, t('btn.resume'));
  } else if (st.onAir) {
    cls = '.on'; title = t('card.on_air');
    sub = src === 'Microphone' || (src === 'Both' && st.who !== 'Wispr Flow')
      ? t('card.on_air_mic', st.who) : t('card.on_air_keys');
  } else {
    title = t('card.quiet');
    if (src === 'Shortcuts' && !st.wispr) sub = t('card.no_wispr');
    else if (src === 'Shortcuts' && !st.hasShortcuts) sub = t('card.no_shortcuts');
    else if (src === 'Shortcuts') sub = t('card.quiet_keys');
    else if (!(S.settings.apps || []).length) sub = t('card.no_apps');
    else sub = t('card.quiet_mic');
  }
  return h('div.card' + cls, { 'data-region': 'card', role: 'status', 'aria-live': 'polite' },
    h('div.icon', icon(iconName, 26)),
    h('div.body', h('div.title', title), h('div.sub', { title: sub }, sub)),
    button);
}

function lockSelect(focusKey) {
  return h('select', { id: 'lock', 'data-focus': focusKey, 'aria-describedby': S.settings.lock === 'CapsLock' ? 'caps-warning' : null,
    on: { change: (e) => set('lock', e.target.value) } },
    LOCKS.map((l) => h('option', { value: l, selected: S.settings.lock === l }, t('lock.' + l))));
}

function appsSection() {
  if (S.settings.source === 'Shortcuts') {
    return h('div.section', { 'data-region': 'apps' },
      h('h2', t('main.keys_title')),
      h('p.muted', t('main.keys_text')),
      link(t('main.keys_link'), () => go('advanced', 'shortcuts'), 'more'));
  }
  const apps = S.apps;
  const shown = S.showAll ? apps : apps.slice(0, VISIBLE_APPS);
  const box = apps.length
    ? h('div.apps' + (S.showAll ? '.scroll' : ''), shown.map((a) =>
        h('label.app', { title: a.name },
          h('input', { type: 'checkbox', checked: !!a.checked, 'data-focus': 'app:' + a.id,
            on: { change: (e) => set('app', { id: a.id, checked: e.target.checked ? 1 : 0 }) } }),
          h('span.name', a.name),
          a.live ? h('span.badge', t('main.now')) : null)))
    : h('p.muted', t('main.no_history'));
  return h('div.section', { 'data-region': 'apps' },
    h('div.line',
      h('h2', t('main.apps_title')),
      tip(t('main.apps_hint'), t('tip.apps'), 'tip:apps'),
      apps.length > VISIBLE_APPS
        ? link(S.showAll ? t('main.show_less') : t('main.show_all', apps.length), () => { S.showAll = !S.showAll; refresh('apps'); }, 'more')
        : null),
    box);
}

// --- Lowering other sounds (main view and the Sound section) ---

// The slider and its value; the value follows the slider at once, the setting is sent on release
function levelSlider(id) {
  const s = S.settings;
  const value = h('span.pct' + (s.duck ? '' : '.off'), { 'aria-hidden': 'true' }, s.duckLevel + '%');
  const input = h('input', { type: 'range', id, min: 0, max: 50, step: 1, value: String(s.duckLevel), disabled: !s.duck,
    'aria-labelledby': 'duck-label', 'aria-valuetext': t('sound.level_value', s.duckLevel), 'data-focus': id,
    on: {
      input: (e) => { value.textContent = e.target.value + '%'; e.target.setAttribute('aria-valuetext', t('sound.level_value', e.target.value)); },
      change: (e) => set('duckLevel', parseInt(e.target.value, 10))
    } });
  return { input, value };
}

// "Test lowering"; while lowered on air it says so ("Lowered now") and can't be pressed
function duckButton() {
  const s = S.settings, st = S.state;
  const label = st.duckTesting ? t('btn.duck_testing') : st.ducked ? t('btn.duck_now') : t('btn.test_duck');
  return h('button.test', { 'data-region': 'ducktest', 'data-focus': 'duck-test',
    disabled: !s.duck || st.ducked || st.duckTesting, on: { click: () => send('testDuck') } }, label);
}

function duckCheckbox() {
  const s = S.settings;
  return h('label.check',
    h('input', { type: 'checkbox', checked: !!s.duck, 'data-focus': 'duck', on: { change: (e) => set('duck', e.target.checked ? 1 : 0) } }),
    h('span.label#duck-label', t('main.sound')));
}

function soundBlock() {
  const slider = levelSlider('duck-level');
  return h('div.block',
    h('div.line', duckCheckbox(), tip(t('main.sound_tip'), t('tip.sound'), 'tip:sound')),
    h('div.ctl.indent', slider.input, slider.value, duckButton()));
}

function ledBlock() {
  return h('div.block',
    h('div.line', h('label.label', { for: 'lock' }, t('main.led')), tip(t('main.led_tip'), t('tip.led'), 'tip:led')),
    h('div.ctl', lockSelect('lock-main'),
      h('button.test', { 'data-focus': 'test-main', on: { click: () => send('testLed') } }, t('btn.test_led'))),
    S.settings.lock === 'CapsLock' ? h('p.msg.warning#caps-warning', t('indicator.caps_warning')) : null);
}

function viewMain() {
  return h('div.page.main',
    h('div.header', brand(), statusCard()),
    appsSection(),
    h('div.two', soundBlock(), ledBlock()),
    h('footer',
      h('div.links',
        link(t('nav.howto'), () => go('howto')),
        link(t('nav.bug'), () => send('bug')),
        link(t('nav.support'), () => go('support'))),
      link(t('nav.advanced'), () => go('advanced'), 'strong')));
}

function viewAdvanced() {
  const sec = S.view === 'about' ? 'about' : S.section;
  const nav = h('nav.side', { 'aria-label': t('nav.sections') },
    brand(),
    SECTIONS.map((id) => {
      const soon = id === 'obs';
      return h('button' + (id === sec ? '.on' : ''), {
        disabled: soon, 'aria-current': id === sec ? 'page' : null, 'data-focus': 'nav:' + id,
        on: { click: () => { S.view = 'advanced'; S.section = id; render(); } }
      }, h('span', t('section.' + id)), soon ? h('span.soon', t('section.soon')) : null);
    }),
    link('← ' + t('nav.simple'), () => go('main'), 'back'));
  const builders = { source: secSource, shortcuts: secShortcuts, indicator: secIndicator, sound: secSound,
    general: secGeneral, diag: secDiag, about: secAbout };
  return h('div.split', nav, h('main.pane', (builders[sec] || secSource)()));
}

function head(title, text) {
  return h('div.head', h('h1', title), text ? h('p.muted', text) : null);
}

function secSource() {
  const s = S.settings;
  return [
    head(t('source.title'), t('source.text')),
    h('div.choices', { role: 'radiogroup', 'aria-label': t('source.title') },
      ['Microphone', 'Shortcuts', 'Both'].map((id) => h('button.choice' + (s.source === id ? '.on' : ''), {
        role: 'radio', 'aria-checked': s.source === id ? 'true' : 'false', 'data-focus': 'src:' + id,
        on: { click: () => set('source', id) }
      }, h('span.dot'), h('span.what', h('b', t('source.' + id)), h('span', t('source.' + id + '_text')))))),
    s.source === 'Both'
      ? h('div.row',
          h('label', { for: 'grace' }, t('source.grace')),
          h('input', { id: 'grace', type: 'number', min: 1, max: 60, value: s.graceS,
            on: { change: (e) => set('graceS', parseInt(e.target.value, 10) || 6) } }),
          h('span', t('source.seconds')))
      : null,
    s.source !== 'Microphone' ? note(t('source.keys_note')) : null
  ];
}

function shortcutRows() {
  const s = S.settings, st = S.state;
  const issues = {};
  for (const i of s.issues || []) if (!issues[i.action] || i.level === 'error') issues[i.action] = i;
  return h('div.keys', { 'data-region': 'shortcuts' }, ACTIONS.map((a) => {
    const waiting = st.assigning === a;
    const text = (s.shortcuts || {})[a] || '';
    const issue = S.assignMsg[a] || issues[a];
    return h('div.key',
      h('div.top',
        h('span.line', h('b', t('action.' + a)), a === 'Cancel' ? tip(t('keys.escape_hint'), t('tip.more', t('action.Cancel')), 'tip:escape') : null),
        h('span.muted', t('type.' + TYPES[a]))),
      h('div.line',
        h('span.combo' + (waiting ? '.wait' : text ? '.mono' : '.none'), { 'aria-live': 'polite' },
          waiting ? t('assign.prompt') : text || t('shortcut.none')),
        h('button.small', { 'data-focus': 'assign:' + a, on: { click: () => send(waiting ? 'cancelAssign' : 'assign', { action: a }) } },
          waiting ? t('btn.cancel') : t('btn.assign')),
        h('button.small.icon', { 'aria-label': t('btn.clear') + ': ' + t('action.' + a), title: t('btn.clear'),
          'data-focus': 'clear:' + a, disabled: !text && !waiting, on: { click: () => send('clear', { action: a }) } }, icon('close', 16))),
      issue ? h('div.msg.' + issue.level, issue.text) : null);
  }));
}

function secShortcuts() {
  const s = S.settings;
  return [
    head(t('keys.title'), t('keys.text')),
    note(t('keys.order_note')),
    s.source === 'Microphone'
      ? h('p.muted', t('keys.unused'), ' ', link(t('keys.change_source'), () => { S.section = 'source'; render(); }))
      : null,
    shortcutRows(),
    checkbox(t('keys.pause_in_wispr'), s.pauseInWispr, (v) => set('pauseInWispr', v ? 1 : 0), t('keys.pause_in_wispr_hint'))
  ];
}

function secIndicator() {
  const s = S.settings;
  return [
    head(t('indicator.title'), t('indicator.text')),
    h('div.list', { role: 'radiogroup', 'aria-label': t('main.led') }, LOCKS.map((l) =>
      h('label.check',
        h('input', { type: 'radio', name: 'lock', value: l, checked: s.lock === l, 'data-focus': 'lock:' + l,
          on: { change: () => set('lock', l) } }),
        h('span', t('lock.' + l + (l === 'ScrollLock' ? '_rec' : '')))))),
    s.lock === 'CapsLock' ? h('p.msg.warning', t('indicator.caps_warning')) : null,
    h('div.buttons', h('button', { 'data-focus': 'test-adv', on: { click: () => send('testLed') } }, t('btn.test_led')),
      tip(t('indicator.keyboard_hint'), t('tip.led'), 'tip:keyboard')),
    checkbox(t('indicator.tray_state'), s.trayState, (v) => set('trayState', v ? 1 : 0))
  ];
}

function secGeneral() {
  const s = S.settings;
  return [
    head(t('general.title')),
    h('div.stack',
      h('label.label', { for: 'language' }, t('general.language')),
      h('div.row', h('select', { id: 'language', 'data-focus': 'language', on: { change: (e) => set('language', e.target.value) } },
        h('option', { value: 'auto', selected: s.language === 'auto' }, t('lang.auto', t('lang.name.' + s.autoLanguage))),
        h('option', { value: 'pl', selected: s.language === 'pl' }, 'Polski'),
        h('option', { value: 'en', selected: s.language === 'en' }, 'English')))),
    checkbox(t('general.autostart'), s.autostart, (v) => set('autostart', v ? 1 : 0),
      s.autostartManaged ? null : t('general.autostart_dev'))
  ];
}

function secDiag() {
  const s = S.settings;
  return [
    head(t('diag.title'), t('diag.text')),
    checkbox(t('diag.debug'), s.debug, (v) => set('debug', v ? 1 : 0), t('diag.debug_hint')),
    h('div.buttons',
      h('button', { on: { click: () => send('showLog') } }, t('diag.show_log')),
      h('button', { on: { click: () => send('openConfig') } }, t('diag.open_config')),
      h('button.primary', { on: { click: () => send('bug') } }, t('nav.bug')),
      tip(t('diag.ini_hint'), t('tip.more', t('diag.open_config')), 'tip:ini'))
  ];
}

// Whole milliseconds, back to the nearest allowed value; text that isn't a number keeps the old one
function parseMs(text, maxMs, oldMs) {
  const v = parseFloat(String(text).replace(',', '.'));
  if (isNaN(v)) return oldMs;
  return Math.min(maxMs, Math.max(0, Math.round(v)));
}

function timeField(key, id, label, tipText, maxMs) {
  const s = S.settings;
  return h('div.stack',
    h('div.line', h('label.small.strong', { for: id }, label), tip(tipText, t('tip.more', label), 'tip:' + id)),
    h('div.line',
      h('input.sec', { id, type: 'text', inputmode: 'numeric', value: String(s[key]), disabled: !s.duck, 'data-focus': id,
        on: { change: (e) => { const ms = parseMs(e.target.value, maxMs, s[key]); e.target.value = String(ms); set(key, ms); } } }),
      h('span.muted', t('sound.unit'), ' ', h('span.small', t('sound.range', maxMs)))));
}

function duckExample() {
  const level = S.settings.duckLevel;
  if (level <= 0) return t('sound.example_0');
  return t('sound.example', Math.round(60 * level / 100));
}

// The lowered apps, or why nothing is
function duckNow() {
  const s = S.settings, st = S.state, names = st.duckedApps || [];
  return h('div.now', { 'data-region': 'ducknow', 'aria-live': 'polite' },
    !s.duck ? h('span.strong', t('sound.off'))
      : st.ducked && names.length ? [h('span.strong', t('sound.now')), names.map((n) => h('span.tag', n))]
        : h('span.strong', t('sound.none')));
}

function secSound() {
  const s = S.settings;
  const dim = s.duck ? '' : '.dim';
  const slider = levelSlider('duck-level-adv');
  return [
    head(t('sound.title'), t('sound.text')),
    h('div.line', duckCheckbox(), tip(t('sound.tip', duckExample()), t('tip.sound'), 'tip:duck')),
    h('div.box' + dim,
      h('div.ctl',
        h('div.scale', slider.input, h('div.ends.small.muted', h('span', t('sound.scale_min')), h('span', t('sound.scale_max')))),
        slider.value,
        duckButton())),
    h('div.times' + dim,
      timeField('duckDown', 'duck-down', t('sound.down'), t('sound.down_tip'), 2000),
      timeField('duckUp', 'duck-up', t('sound.up'), t('sound.up_tip'), 5000),
      timeField('duckDelay', 'duck-delay', t('sound.delay'), t('sound.delay_tip'), 10000)),
    h('div' + dim, checkbox(t('sound.system'), s.duckSystem, (v) => set('duckSystem', v ? 1 : 0), t('sound.system_tip'),
      { disabled: !s.duck, 'data-focus': 'duck-system' })),
    duckNow(),
    note(t('sound.wispr_note'))
  ];
}

function secAbout() {
  const L = S.links;
  return [
    head(t('about.title', S.version)),
    h('div.stack', h('h2', t('about.why_title')), h('p', t('about.why'))),
    h('div.stack', h('h2', t('about.oss_title')), h('p', t('about.oss')), external(L.repo, L.repo)),
    h('p', t('about.website'), ' ', external(L.websiteName, L.website)),
    h('p', t('about.author')),
    h('p.small.muted', t('about.disclaimer')),
    h('p.path', t('about.config', S.settings.configPath))
  ];
}

function viewHowto() {
  const L = S.links;
  const steps = [
    { app: 'SayoDevice', what: t('howto.step1'), detail: [t('howto.step1_text'), ' ',
      external(t('howto.preset'), L.sayoPreset), ' · ', external('sayodevice.com', L.sayoApp)] },
    { app: 'Wispr Flow', what: t('howto.step2'), detail: t('howto.step2_text') },
    { app: 'OnAir keyboard', what: t('howto.step3'), detail: t('howto.step3_text'), last: true }
  ];
  const row = [];
  steps.forEach((s, i) => {
    if (i) row.push(h('div.arrow', icon('arrow', 28)));
    row.push(h('div.step' + (s.last ? '.last' : ''),
      h('div.who', h('span.n', String(i + 1)), h('span', s.app)),
      h('div.what', s.what),
      h('div.detail', s.detail)));
  });
  return h('div.page.howto',
    h('div.head', h('h1', t('howto.title')), h('p.muted', t('howto.text'))),
    h('div.steps', row),
    h('p.bighint', t('howto.speak')),
    h('div.notes2', note(t('howto.why_last')), note(t('howto.mic_order'), 'ok')),
    h('p.small.muted', t('howto.tray_tip')),
    h('footer',
      link('← ' + t('nav.back'), () => go('main')),
      h('span', t('howto.more'), ' ', external(L.websiteName, L.website))));
}

function viewSupport() {
  return h('div.page',
    logos(),
    h('div.hello', t('support.hello')),
    h('p', t('support.cta')),
    h('div.buttons', (S.links.support || []).map((l, i) =>
      h('button' + (i === 0 ? '.primary' : ''), { on: { click: () => send('open', { url: l.url }) } }, l.name))),
    h('footer', link('← ' + t('nav.back'), () => go('main')), h('span')));
}

function viewBug() {
  const b = S.bug || {};
  const copy = (text, what) => { send('copy', { text }); S.copied = what; render(); };
  return h('div.page',
    head(t('bug.title'), t('bug.intro')),
    h('div.field', h('span.name.muted', t('bug.address')), h('span.value', b.email || ''),
      h('button.small', { on: { click: () => copy(b.email, 'address') } }, t('bug.copy_address'))),
    h('div.field', h('span.name.muted', t('bug.subject')), h('span.value', b.subject || ''),
      h('button.small', { on: { click: () => copy(b.subject, 'subject') } }, t('bug.copy_subject'))),
    note(t('bug.notice')),
    b.logExists
      ? h('p', t('bug.log'), ' ', link(t('bug.log_show'), () => send('showLog')), ' ', h('span.muted', t('bug.log_drag')))
      : h('p.muted', t('bug.log_off'), ' ', link(t('bug.log_turn_on'), () => { set('debug', 1); })),
    h('label.label', { for: 'body' }, t('bug.text_label')),
    h('textarea', { id: 'body', readonly: true, value: b.body || '' }),
    h('div.row',
      h('button.primary', { on: { click: () => copy(b.body, 'text') } }, t('bug.copy_text')),
      S.copied ? h('span.done', { role: 'status' }, t('bug.copied_' + S.copied)) : null,
      h('span.grow'),
      link('← ' + t('nav.back'), () => go('main'))));
}

// --- Messages from the program ---

if (host) {
  host.addEventListener('message', (e) => {
    const m = e.data;
    switch (m.type) {
      case 'init':
        Object.assign(S, { texts: m.texts, settings: m.settings, state: m.state, apps: m.apps, links: m.links,
          version: m.version, lang: m.lang, bug: m.bug });
        if (m.view === 'about') { S.view = 'advanced'; S.section = 'about'; } else S.view = m.view || S.view;
        render();
        break;
      case 'state': {
        const before = S.state.assigning;
        S.state = m.state;
        if (S.state.assigning && S.state.assigning !== before) delete S.assignMsg[S.state.assigning];
        refresh('card');
        refresh('shortcuts');
        refresh('ducktest');
        refresh('ducknow');
        break;
      }
      case 'apps': S.apps = m.apps; refresh('apps'); break;
      case 'settings': S.settings = m.settings; render(); break;
      case 'assign':  // the result of assigning a shortcut: an error or a warning for that action
        if (m.text) S.assignMsg[m.action] = { level: m.level, text: m.text };
        else delete S.assignMsg[m.action];
        refresh('shortcuts');
        break;
      case 'bug': S.bug = m.bug; go('bug'); break;
      case 'view':
        if (m.view === 'about') go('advanced', 'about'); else go(m.view);
        break;
    }
  });
  send('ready');
}
