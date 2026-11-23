/* Launch Day at Zava, tech talk scenes.
   Each scene has one clock: steps are scheduled when its slide is entered, stopped when it is left,
   and can be paused, replayed or jumped to the final state. Manual interaction takes over. */
(() => {
  const D = window.TALK_DATA;
  const $ = (root, sel) => root.querySelector(sel);
  const $$ = (root, sel) => [...root.querySelectorAll(sel)];
  const fmtPct = p => `${Math.round(p * 100)}%`;
  const fmt2 = p => p.toFixed(2);
  const nice = s => String(s).replace(/_/g, ' ');
  const esc = s => String(s).replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
  const svgNS = 'http://www.w3.org/2000/svg';
  const svgEl = (tag, attrs = {}, parent) => { const e = document.createElementNS(svgNS, tag); for (const k in attrs) e.setAttribute(k, attrs[k]); if (parent) parent.appendChild(e); return e; };

  let motion = !matchMedia('(prefers-reduced-motion: reduce)').matches;

  // ------------------------------------------------------------------ clock
  class Clock {
    constructor(onChange) { this.handles = []; this.steps = []; this.elapsed = 0; this.running = false; this.onChange = onChange; }
    start(steps, from = 0) { this.stop(); this.steps = steps.map(([at, run]) => ({ at, run, done: false })); this.elapsed = from; this.resume(); }
    resume() {
      this.running = true; this.t0 = performance.now() - this.elapsed;
      for (const s of this.steps) {
        if (s.done) continue;
        this.handles.push(setTimeout(() => { s.done = true; s.run(false); if (!this.pending()) this.running = false; this.onChange(); }, Math.max(0, s.at - this.elapsed)));
      }
      if (!this.pending()) this.running = false;
      this.onChange();
    }
    pause() { if (!this.running) return; this.elapsed = performance.now() - this.t0; this.clear(); this.running = false; this.paused = true; this.onChange(); }
    stop() { this.clear(); this.running = false; this.paused = false; }
    clear() { this.handles.forEach(clearTimeout); this.handles = []; }
    pending() { return this.steps.some(s => !s.done); }
    nextIn() { const now = this.running ? performance.now() - this.t0 : this.elapsed; const n = this.steps.find(s => !s.done); return n ? Math.max(0, n.at - now) : null; }
  }

  // ------------------------------------------------------------------ helpers shared by scenes
  const beat = (el, n) => el.classList.add(n);
  const clearBeats = el => [...el.classList].filter(c => /^b\d$/.test(c)).forEach(c => el.classList.remove(c));
  const focus = (el, targets) => {
    $$(el, '.focus').forEach(x => x.classList.remove('focus'));
    if (!targets) { el.classList.remove('focusing'); return; }
    el.classList.add('focusing'); [].concat(targets).forEach(t => t && t.classList.add('focus'));
  };
  const instantly = (el, fn) => { el.classList.add('no-motion'); fn(); void el.offsetWidth; requestAnimationFrame(() => requestAnimationFrame(() => el.classList.remove('no-motion'))); };

  // ------------------------------------------------------------------ scenes
  const S = {};

  // 1 · Title: five real listings pass the gate and land in their lane.
  S.title = {
    init(el) {
      const flow = $(el, '.flow');
      D.tour.forEach((t, i) => {
        const c = document.createElement('div');
        c.className = 'card'; c.dataset.i = i;
        c.innerHTML = `<b>${t.id}</b>${esc(t.title.length > 34 ? t.title.slice(0, 32) + '…' : t.title)}`;
        flow.appendChild(c);
      });
    },
    reset(el) { $$(el, '.card').forEach(c => { c.className = 'card'; c.style.left = '0px'; c.style.top = '220px'; c.style.width = ''; }); },
    place(el, i) {
      const lanes = { publish: 30, auto_fix: 132, review: 234, reject: 336 };
      const t = D.tour[i], c = $(el, `.card[data-i="${i}"]`);
      const before = D.tour.slice(0, i).filter(x => x.outcome === t.outcome).length;
      c.classList.add('in', 'placed', t.outcome);
      c.style.left = `${222 + before * 168}px`; c.style.top = `${lanes[t.outcome] + 28}px`; c.style.width = '152px';
    },
    steps(el) {
      const out = [];
      D.tour.forEach((t, i) => {
        const at = 5000 + i * 3200;
        out.push([at, () => { const c = $(el, `.card[data-i="${i}"]`); c.classList.add('in'); c.style.left = '70px'; }]);
        out.push([at + 1300, () => this.place(el, i)]);
      });
      return out;
    },
    final(el) { D.tour.forEach((_, i) => this.place(el, i)); },
  };

  // 2 · Numbers: three facts, then the scorecard for three ways to open.
  const SCEN = {
    publish: { live: ['100%', 'publish'], bad: ['1,851', 'reject'], hours: ['0', ''], cost: ['€0', ''] },
    hand: { live: ['0%', 'reject'], bad: ['0', 'publish'], hours: ['333', 'reject'], cost: ['€10,000', 'reject'] },
    gate: { live: ['75%', 'publish'], bad: ['19', 'person'], hours: ['61', 'person'], cost: ['€1,842', 'publish'] },
  };
  S.numbers = {
    init(el) { $$(el, '[data-scenario]').forEach(b => b.addEventListener('click', () => { Deck.manual(el); this.show(el, b.dataset.scenario); })); },
    reset(el) { $$(el, '[data-k]').forEach(v => { v.textContent = '·'; v.className = 'v num'; }); $$(el, '[data-scenario]').forEach(b => b.setAttribute('aria-pressed', 'false')); },
    show(el, name) {
      $$(el, '[data-scenario]').forEach(b => b.setAttribute('aria-pressed', String(b.dataset.scenario === name)));
      for (const [k, [v, c]] of Object.entries(SCEN[name])) { const e = $(el, `[data-k="${k}"]`); e.textContent = v; e.className = `v num ${c ? 'c-' + c : ''}`; }
    },
    steps(el) { return [[3000, () => beat(el, 'b1')], [18000, () => { beat(el, 'b2'); this.show(el, 'publish'); }], [30000, () => this.show(el, 'hand')], [42000, () => this.show(el, 'gate')]]; },
    final(el) { beat(el, 'b1'); beat(el, 'b2'); this.show(el, 'gate'); },
  };

  // 3 · Three tools: the rule really runs here; model answers are from the recorded runs.
  S.tools = {
    init(el) {
      const T = D.three_tools, text = T.listing.description;
      $(el, '#tl-id').textContent = T.listing.id;
      $(el, '#tl-text').textContent = text;
      $(el, '#tl-q').textContent = T.question;
      const m = /\b0\d{9}\b/.exec(text);
      $(el, '#tl-rule').innerHTML = m ? `<span class="c-reject">match: ${esc(m[0])}</span>` : '<span class="c-reject">✗ no match</span>';
      $(el, '#tl-rule-meta').textContent = m ? 'The pattern found a number.' : 'Ran just now, in this browser. The seller spelled the number out.';
      $(el, '#tl-llm').innerHTML = `${T.llm.value === true ? 'true' : esc(T.llm.value)} <span class="small muted">(no probability)</span>`;
      $(el, '#tl-llm-meta').textContent = `${T.llm.latency_ms.toLocaleString('en')} ms · ${T.llm.output_tokens} output tokens`;
      $(el, '#tl-dm').textContent = `P(yes) = ${T.decision.probability.toFixed(3)}`;
      $(el, '#tl-dm-meta').textContent = `${T.decision.latency_ms} ms · ${T.decision.output_tokens} output tokens`;
    },
    reset(el) { focus(el, null); },
    steps(el) {
      return [[2000, () => beat(el, 'b1')], [22000, () => beat(el, 'b2')], [34000, () => beat(el, 'b3')],
        [46000, () => beat(el, 'b4')], [58000, () => focus(el, $$(el, '.tool')[2])]];
    },
    final(el) { ['b1', 'b2', 'b3', 'b4'].forEach(b => beat(el, b)); focus(el, null); },
  };

  // 4 · Contract: focus tour through request and response, then the rules.
  S.contract = {
    reset(el) { focus(el, null); },
    steps(el) {
      const g = n => $(el, `.grp[data-g="${n}"]`);
      return [[10000, () => focus(el, g(1))], [22000, () => focus(el, g(2))], [37000, () => focus(el, g(3))],
        [52000, () => focus(el, g(4))], [67000, () => { focus(el, null); beat(el, 'b5'); }]];
    },
    final(el) { focus(el, null); beat(el, 'b5'); },
  };

  // 5 · Question types, from real answers.
  const barsHTML = rows => rows.map(([k, p]) => `<div class="bar"><span>${esc(nice(k))}</span><span class="track"><span class="fill" data-w="${p}"></span></span><span class="p num">${fmtPct(p)}</span></div>`).join('');
  S.types = {
    init(el) {
      const T = D.types;
      $(el, '#ty-yes-q').textContent = 'Does it ask shoppers to contact the seller outside the marketplace?';
      $(el, '#ty-yes-who').textContent = `${T.yes_no.id} · ${T.yes_no.title}`;
      $(el, '#ty-ch-q').textContent = 'Which category does the product belong to?';
      $(el, '#ty-ch-who').textContent = `${T.choice.id} · ${T.choice.title}`;
      $(el, '#ty-ch-bars').innerHTML = barsHTML(T.choice.answer.distribution.slice(0, 4));
      $(el, '#ty-sc-q').textContent = 'How useful is it to a shopper deciding whether to buy?';
      $(el, '#ty-sc-who').textContent = `${T.score.id} · ${T.score.title}`;
      $(el, '#ty-sc-bars').innerHTML = barsHTML(T.score.answer.distribution);
      $$(el, '.type').forEach(b => b.addEventListener('click', () => {
        Deck.manual(el); this.final(el);
        const on = b.classList.contains('focus'); focus(el, on ? null : b);
      }));
    },
    reset(el) { focus(el, null); $(el, '#ty-yes-v').textContent = '·'; $$(el, '.fill').forEach(f => f.style.width = '0'); },
    fill(el, sel) { $$(el, `${sel} .fill`).forEach(f => f.style.width = `${Math.max(1, f.dataset.w * 100)}%`); },
    steps(el) {
      return [[1500, () => { beat(el, 'b1'); $(el, '#ty-yes-v').textContent = D.types.yes_no.answer.probability.toFixed(3); }],
        [9500, () => { beat(el, 'b2'); this.fill(el, '#ty-ch-bars'); }],
        [17500, () => { beat(el, 'b3'); this.fill(el, '#ty-sc-bars'); }], [26000, () => beat(el, 'b4')]];
    },
    final(el) { ['b1', 'b2', 'b3', 'b4'].forEach(b => beat(el, b)); $(el, '#ty-yes-v').textContent = D.types.yes_no.answer.probability.toFixed(3); this.fill(el, '.types'); },
  };

  // 6 · Ignite tiles.
  S.ignite = {
    steps(el) { return [[2000, () => beat(el, 'b1')], [14000, () => beat(el, 'b2')], [26000, () => beat(el, 'b3')], [38000, () => beat(el, 'b4')]]; },
    final(el) { ['b1', 'b2', 'b3', 'b4'].forEach(b => beat(el, b)); },
  };

  // 7 · The dial, on 511 real rehearsal answers.
  const X0 = 40, X1 = 1112, AXIS = 262;
  const px = p => X0 + p * (X1 - X0);
  S.dial = {
    init(el) {
      const svg = $(el, 'svg.dial'), dd = D.dial;
      $(el, '#dial-q').innerHTML = `Question <b class="mono">${esc(dd.question)}</b>: does the listing claim a feature the manufacturer doesn't mention? <span class="c-reject">Red dots</span> really do.`;
      this.zone = svgEl('rect', { class: 'zone-person', y: 20, height: AXIS - 20 }, svg);
      svgEl('line', { class: 'axis', x1: X0, x2: X1, y1: AXIS, y2: AXIS }, svg);
      for (const t of [0, 0.2, 0.4, 0.6, 0.8, 1]) { svgEl('line', { class: 'axis', x1: px(t), x2: px(t), y1: AXIS, y2: AXIS + 8 }, svg); svgEl('text', { x: px(t), y: AXIS + 28, 'text-anchor': 'middle' }, svg).textContent = t.toFixed(1); }
      svgEl('text', { x: X1, y: AXIS + 28, 'text-anchor': 'end', dy: 18 }, svg).textContent = 'P(yes)';
      let seed = 7; const rnd = () => (seed = (seed * 16807) % 2147483647) / 2147483647;
      const dots = svgEl('g', {}, svg), bad = svgEl('g', {}, svg);
      for (const [p, y] of dd.pairs) svgEl('circle', { class: `dot${y ? ' bad' : ''}`, cx: px(p), cy: 40 + rnd() * (AXIS - 60), r: y ? 7 : 3.2 }, y ? bad : dots);
      this.lines = {};
      for (const k of ['no', 'yes']) {
        const g = svgEl('g', { class: `handle ${k}`, tabindex: 0, role: 'slider', 'aria-label': `${k} line`, 'aria-valuemin': 0, 'aria-valuemax': 1 }, svg);
        svgEl('line', { class: `line ${k}`, x1: 0, x2: 0, y1: 14, y2: AXIS }, g);
        svgEl('rect', { x: -44, y: -20, width: 88, height: 30 }, g);
        const label = svgEl('text', { x: 0, y: 1, 'text-anchor': 'middle' }, g);
        this.lines[k] = { g, label };
        this.drag(el, svg, g, k);
      }
    },
    drag(el, svg, g, k) {
      const setFrom = clientX => {
        const r = svg.getBoundingClientRect();
        const p = Math.min(1, Math.max(0, ((clientX - r.left) / r.width * 1152 - X0) / (X1 - X0)));
        this.move(el, k, Math.round(p * 100) / 100);
      };
      g.addEventListener('pointerdown', e => { Deck.manual(el); svg.classList.add('dragging'); g.setPointerCapture(e.pointerId); setFrom(e.clientX); });
      g.addEventListener('pointermove', e => { if (g.hasPointerCapture(e.pointerId)) setFrom(e.clientX); });
      g.addEventListener('pointerup', e => { svg.classList.remove('dragging'); g.releasePointerCapture(e.pointerId); });
      g.addEventListener('keydown', e => {
        const d = { ArrowLeft: -1, ArrowDown: -1, ArrowRight: 1, ArrowUp: 1 }[e.key];
        if (!d) return;
        e.preventDefault(); e.stopPropagation(); Deck.manual(el);
        this.move(el, k, Math.round((this.v[k] + d * (e.shiftKey ? 0.05 : 0.01)) * 100) / 100);
      });
    },
    move(el, k, p) {
      const v = { ...this.v, [k]: p };
      if (k === 'no') v.no = Math.min(v.no, v.yes - 0.01); else v.yes = Math.max(v.yes, v.no + 0.01);
      this.set(el, v);
    },
    set(el, v) {
      this.v = { no: Math.max(0, v.no), yes: Math.min(1, v.yes) };
      const { no, yes } = this.v;
      this.zone.setAttribute('x', px(no)); this.zone.setAttribute('width', Math.max(0, px(yes) - px(no)));
      for (const k of ['no', 'yes']) {
        const { g, label } = this.lines[k];
        g.setAttribute('transform', `translate(${px(this.v[k])},${k === 'no' ? 22 : 22})`);
        g.setAttribute('aria-valuenow', this.v[k]); g.setAttribute('aria-valuetext', `${k} line at ${fmt2(this.v[k])}`);
        label.textContent = `${k} ${k === 'no' ? '≤' : '≥'} ${fmt2(this.v[k])}`;
      }
      const P = D.dial.pairs;
      const c = { clear: P.filter(([p]) => p <= no).length, flag: P.filter(([p]) => p >= yes).length, miss: P.filter(([p, y]) => p <= no && y).length };
      c.person = P.length - c.clear - c.flag;
      for (const k in c) $(el, `[data-c="${k}"]`).textContent = c[k];
      $(el, '[data-c="miss"]').className = `v num ${c.miss ? 'c-reject' : 'c-publish'}`;
    },
    reset(el) { this.set(el, D.dial.default); },
    steps(el) { return [[22000, () => this.set(el, D.dial.tuned)]]; },
    final(el) { this.set(el, D.dial.tuned); },
  };

  // 8 · Gate tour, real outcomes with the default dial.
  const CAPTION = t => {
    if (t.outcome !== t.expected) return `Sure enough to act, but Zava's answer key says <b>${esc(nice(t.expected))}</b> (it's a smart home device). A <b class="c-person">policy</b> question, not a model problem.`;
    return { publish: 'Every check passes. Live in under a minute, no person needed.',
      auto_fix: 'Filed in the wrong aisle. The model is sure enough to fix the category itself.',
      review: 'The model is unsure about quality, so a person decides.',
      reject: 'A phone number spelled out to dodge a rule. Rejected, with the reason.' }[t.outcome];
  };
  S.tour = {
    init(el) {
      $(el, '#tc-chips').innerHTML = D.tour.map((t, i) => `<button class="chip" data-i="${i}" aria-pressed="false" title="${esc(t.title)}">${t.id}</button>`).join('');
      $$(el, '#tc-chips .chip').forEach(b => b.addEventListener('click', () => { Deck.manual(el); this.show(el, +b.dataset.i); }));
      $$(el, 'svg.routes path[data-exit]').forEach(p => p.setAttribute('pathLength', 1));
    },
    reset(el) {
      $(el, '#tc-id').textContent = ''; $(el, '#tc-title').textContent = 'Waiting for the first listing…'; $(el, '#tc-desc').textContent = '';
      $(el, '#tc-q').textContent = 'the gate'; $(el, '#tc-p').textContent = '·'; $(el, '#tc-v').textContent = ''; $(el, '#tc-caption').innerHTML = '';
      $$(el, 'svg.routes path[data-exit]').forEach(p => p.classList.remove('on'));
      $$(el, '.exit').forEach(x => { x.classList.remove('on'); $(x, '.why').textContent = ''; });
      $$(el, '#tc-chips .chip').forEach(b => b.setAttribute('aria-pressed', 'false'));
    },
    show(el, i) {
      const t = D.tour[i], a = t.answers[0];
      this.reset(el);
      $(el, '#tc-id').textContent = `${t.id} · €${t.price} · filed under ${nice(t.seller_category)}`;
      $(el, '#tc-title').textContent = t.title; $(el, '#tc-desc').textContent = t.description;
      $(el, '#tc-q').textContent = nice(a.name);
      $(el, '#tc-p').textContent = a.kind === 'yes_no' ? `P(yes) ${a.probability.toFixed(3)}` : fmtPct(a.probability);
      $(el, '#tc-v').textContent = a.value != null ? nice(a.value) : '';
      const path = $(el, `svg.routes path[data-exit="${t.outcome}"]`);
      path.classList.remove('on'); void path.getBoundingClientRect(); path.classList.add('on');
      const ex = $(el, `.exit[data-exit="${t.outcome}"]`); ex.classList.add('on');
      $(ex, '.why').textContent = t.reasons.join('; ') || 'nothing in it breaks the policy';
      $(el, '#tc-caption').innerHTML = CAPTION(t);
      $$(el, '#tc-chips .chip').forEach(b => b.setAttribute('aria-pressed', String(+b.dataset.i === i)));
    },
    steps(el) { return D.tour.map((_, i) => [15000 + i * 12000, () => this.show(el, i)]); },
    final(el) { this.show(el, D.tour.length - 1); },
  };

  // 9 · Audit: manual reveal only (an audience question).
  S.audit = {
    manualOnly: true,
    init(el) {
      $(el, '#au-audit').addEventListener('click', () => this.audit(el));
      $(el, '#au-fix').addEventListener('click', () => this.fix(el));
    },
    reset(el) {
      const b = $(el, '#au-before'); b.className = 'verdict-card ok';
      $(b, '.big').textContent = '✅ Published';
      $(el, '#au-after').classList.remove('shown'); $(el, '#au-impact').classList.remove('shown');
      $(el, '#au-audit').disabled = false; $(el, '#au-fix').disabled = true;
    },
    audit(el) {
      const b = $(el, '#au-before'); b.className = 'verdict-card alarm'; $(b, '.big').textContent = '🏴‍☠️ An attack got through';
      $(el, '#au-audit').disabled = true; $(el, '#au-fix').disabled = false; $(el, '#au-fix').focus();
    },
    fix(el) {
      $(el, '#au-before').classList.add('shrink'); $(el, '#au-after').classList.add('shown'); $(el, '#au-impact').classList.add('shown');
      $(el, '#au-fix').disabled = true;
    },
    steps() { return []; },
    final(el) { this.audit(el); this.fix(el); },
  };

  // 10 · Compare: same three bars, changing measure.
  const MODELS = ['Microsoft-Decision-1.1', 'gpt-6-luna Decisions', 'gpt-6-luna chat'];
  const METRICS = [
    { k: 'acc', label: 'Outcome accuracy', v: [92.6, 84.7, 97.9], f: v => `${v}%`, better: 'high',
      say: 'The chat model is the most accurate. Case closed?' },
    { k: 'bad', label: 'Bad listings published', v: [2, 0, 3], f: v => `${v}`, better: 'low',
      say: 'It still publishes <b class="c-reject">3</b> bad listings. The same model through the Decisions API publishes <b class="c-publish">0</b>.' },
    { k: 'lat', label: 'Latency (p50)', v: [270, 567, 2799], f: v => `${v.toLocaleString('en')} ms`, better: 'low',
      say: 'Ten times slower: it writes ~190 tokens of JSON to say what a decision model says with a few probabilities.' },
    { k: 'cost', label: 'Cost per 10,000 listings', v: [0.53, 1.99, 2.06], f: v => `$${v.toFixed(2)}`, better: 'low',
      say: 'And about four times the cost.' },
    { k: 'prob', label: 'Probabilities for a dial', v: [1, 1, 0], f: v => (v ? 'yes' : 'no'), better: 'high',
      say: 'No probabilities: no dial, and no way to send “unsure” to a person. <b>Most accurate isn’t the same as best.</b>' },
  ];
  S.compare = {
    init(el) {
      $(el, '#cm-metrics').innerHTML = METRICS.map(m => `<button class="chip" data-k="${m.k}" aria-pressed="false">${m.label}</button>`).join('');
      $(el, '#cm-bars').innerHTML = MODELS.map((n, i) => `<div class="mbar" data-i="${i}"><div class="name">${n}</div><div class="track"><div class="fill"></div></div><div class="val num">·</div></div>`).join('');
      $$(el, '#cm-metrics .chip').forEach(b => b.addEventListener('click', () => { Deck.manual(el); this.show(el, b.dataset.k); }));
    },
    reset(el) {
      $$(el, '.mbar').forEach(b => { b.className = 'mbar'; $(b, '.fill').style.width = '0'; $(b, '.val').textContent = '·'; });
      $$(el, '#cm-metrics .chip').forEach(b => b.setAttribute('aria-pressed', 'false'));
      $(el, '#cm-verdict').innerHTML = '<span class="muted">Hypothesis: the most accurate model should run the gate.</span>';
    },
    show(el, k) {
      const m = METRICS.find(x => x.k === k), max = Math.max(...m.v);
      const best = m.better === 'high' ? Math.max(...m.v) : Math.min(...m.v), worst = m.better === 'high' ? Math.min(...m.v) : Math.max(...m.v);
      $$(el, '.mbar').forEach((b, i) => {
        const v = m.v[i];
        b.className = `mbar${v === best ? ' best' : ''}${v === worst ? ' worst' : ''}`;
        $(b, '.fill').style.width = `${max ? Math.max(2, v / max * 100) : 2}%`;
        $(b, '.fill').style.background = v === best ? 'var(--publish)' : v === worst ? 'var(--reject)' : 'var(--model)';
        $(b, '.val').textContent = m.f(v);
      });
      $$(el, '#cm-metrics .chip').forEach(b => b.setAttribute('aria-pressed', String(b.dataset.k === k)));
      $(el, '#cm-verdict').innerHTML = m.say;
    },
    steps(el) { return METRICS.map((m, i) => [8000 + i * 12000, () => this.show(el, m.k)]); },
    final(el) { this.show(el, 'prob'); },
  };

  // 11 · Calibration: reliability chart from the recorded run.
  const CX = 60, CW = 540, CY = 20, CH = 360;
  S.calib = {
    init(el) {
      const C = D.calibration, svg = $(el, 'svg.rel');
      for (let i = 0; i <= 10; i += 2) {
        svgEl('line', { class: 'grid', x1: CX, x2: CX + CW, y1: CY + CH - i / 10 * CH, y2: CY + CH - i / 10 * CH }, svg);
        svgEl('text', { x: CX - 10, y: CY + CH - i / 10 * CH + 5, 'text-anchor': 'end' }, svg).textContent = `${i * 10}%`;
        svgEl('text', { x: CX + i / 10 * CW, y: CY + CH + 40, 'text-anchor': 'middle' }, svg).textContent = `${i * 10}%`;
      }
      svgEl('text', { x: CX + CW / 2, y: CY + CH + 60, 'text-anchor': 'middle' }, svg).textContent = 'what the model said (probability of yes)';
      this.hl = svgEl('rect', { class: 'hl', x: CX + 0.1 * CW, y: CY, width: 0.4 * CW, height: CH, rx: 8 }, svg);
      svgEl('line', { class: 'diag', x1: CX, y1: CY + CH, x2: CX + CW, y2: CY }, svg);
      this.bars = C.table.map(row => {
        const lo = parseFloat(row.bin), x = CX + lo * CW;
        const said = svgEl('rect', { class: 'said', x: x + 4, width: CW / 10 / 2 - 5, y: CY + CH, height: 0 }, svg);
        const hap = svgEl('rect', { class: 'happened', x: x + CW / 20 + 1, width: CW / 10 / 2 - 5, y: CY + CH, height: 0 }, svg);
        svgEl('text', { x: x + CW / 20, y: CY + CH + 18, 'text-anchor': 'middle', style: 'font-size:12px' }, svg).textContent = `n=${row.n}`;
        return { row, said, hap };
      });
      const n = C.table.filter(r => parseFloat(r.bin) >= 0.1 && parseFloat(r.bin) < 0.5);
      $(el, '#cal-n').textContent = n.reduce((s, r) => s + r.n, 0);
      $(el, '#cal-ub').textContent = `${(D.upper_bound_1_in_387 * 100).toFixed(1)}%`;
      $(el, '#cal-src').textContent = `unsupported_claim on Monday's 516 listings, recorded Microsoft-Decision-1.1 run · ECE ${C.ece.toFixed(3)} · Brier ${C.brier.toFixed(3)}`;
    },
    grow(on) {
      for (const { row, said, hap } of this.bars) {
        const hs = on ? row.mean_p * CH : 0, ho = on ? row.observed * CH : 0;
        said.setAttribute('height', hs); said.setAttribute('y', CY + CH - hs);
        hap.setAttribute('height', ho); hap.setAttribute('y', CY + CH - ho);
      }
    },
    reset() { this.grow(false); },
    steps(el) { return [[15000, () => { beat(el, 'b1'); this.grow(true); }], [30000, () => beat(el, 'b3')], [45000, () => beat(el, 'b4')]]; },
    final(el) { ['b1', 'b3', 'b4'].forEach(b => beat(el, b)); this.grow(true); },
  };

  // 12 · Production pattern: one payload through six stages; the audit record fills in.
  const PATTERN = {
    zava: { stages: [['Prepare the state', 'Seller text kept apart from the manufacturer’s facts; the photo'],
      ['Ask atomic questions', 'Six yes/no · category (choice) · quality (score)'], ['Apply the lines', 'no ≤ 0.20 · a person · yes ≥ 0.80, tuned from costs'],
      ['Rules in code', 'Price vs reference · unknown product → person · precedence'], ['Escalate the unsure', 'Unsure or failed → the reviewer queue'],
      ['Log the outcome', 'Probabilities, lines, outcome, the reviewer’s call']],
      ledger: ['request: ZM-0352', 'evidence: structured v1', 'questions: v2 (your fix)', 'model: Microsoft-Decision-1.1', 'contact: 0.999', 'outcome: reject'] },
    bank: { stages: [['Prepare the state', 'Customer message · disputed transaction · card status'],
      ['Ask atomic questions', 'Reason (choice) · still has the card? · urgency (score)'], ['Apply the lines', 'Fraud ≥ 0.30 → fraud team at once'],
      ['Rules in code', 'Amount limits · deadlines · eligibility. Never moves money'], ['Escalate the unsure', 'Refund proposals → an agent approves'],
      ['Log the outcome', 'Probabilities, lines, the agent’s decision, chargeback result']],
      ledger: ['request: dispute 4471', 'evidence: message + txn v2', 'questions: v1', 'model: Microsoft-Decision-1.1', 'reason: duplicate 0.97', 'outcome: refund proposal → agent'] },
    mfg: { stages: [['Prepare the state', 'Camera photo of the part · part spec · station'],
      ['Ask atomic questions', 'Visible crack? · defect type (choice) · severity (score)'], ['Apply the lines', 'Crack ≥ 0.90 → stop · 0.10–0.90 → inspector'],
      ['Rules in code', 'Tolerances from sensors · two cracks in a row to stop the line'], ['Escalate the unsure', '“Cannot tell” → retake the photo, then an inspector'],
      ['Log the outcome', 'Probabilities, photo ID, inspector’s verdict, scrap result']],
      ledger: ['request: part 88-1203', 'evidence: photo + spec v3', 'questions: v2', 'model: Microsoft-Decision-1.1', 'crack: 0.42', 'outcome: inspector'] },
  };
  S.pattern = {
    init(el) {
      this.scen = 'zava';
      $$(el, '.scen .chip').forEach(b => b.addEventListener('click', () => { Deck.manual(el); this.render(el, b.dataset.s); this.light(el, 6); }));
      this.render(el, 'zava');
    },
    render(el, s) {
      this.scen = s; const P = PATTERN[s];
      $$(el, '.scen .chip').forEach(b => b.setAttribute('aria-pressed', String(b.dataset.s === s)));
      $(el, '#pp-stages').innerHTML = P.stages.map(([h, d], i) => `<div class="stage"><div class="n">${i + 1}</div><div class="h">${h}</div><div class="d">${d}</div></div>`).join('');
      $(el, '#pp-ledger').innerHTML = P.ledger.map(x => { const [k, ...v] = x.split(': '); return `<div><span>${k}</span>: ${esc(v.join(': '))}</div>`; }).join('');
      $(el, '#pp-src').textContent = s === 'zava' ? 'Zava: the hack (illustrative audit record for one real listing).' : 'Illustrative design, not a measured result. The stages stay the same; the questions and rules change.';
    },
    light(el, n) { $$(el, '.stage').forEach((x, i) => x.classList.toggle('on', i < n)); $$(el, '#pp-ledger div').forEach((x, i) => x.classList.toggle('on', i < n)); },
    reset(el) { this.render(el, 'zava'); this.light(el, 0); },
    steps(el) { return [0, 1, 2, 3, 4, 5].map(i => [4000 + i * 6000, () => this.light(el, i + 1)]); },
    final(el) { this.light(el, 6); },
  };

  // 13 · Mission timeline.
  S.mission = {
    steps(el) { return [[1500, () => beat(el, 'b1')], [2000, () => beat(el, 'b2')], [3200, () => beat(el, 'b3')], [4400, () => beat(el, 'b4')],
      [5600, () => beat(el, 'b5')], [7000, () => beat(el, 'b6')], [10000, () => beat(el, 'b7')]]; },
    final(el) { ['b1', 'b2', 'b3', 'b4', 'b5', 'b6', 'b7'].forEach(b => beat(el, b)); },
  };

  // 14 · Close.
  S.close = {
    steps(el) { return [[3000, () => beat(el, 'b1')], [7000, () => beat(el, 'b2')], [11000, () => beat(el, 'b3')], [15000, () => beat(el, 'b4')], [19000, () => beat(el, 'b5')], [24000, () => beat(el, 'b6')]]; },
    final(el) { ['b1', 'b2', 'b3', 'b4', 'b5', 'b6'].forEach(b => beat(el, b)); },
  };

  // ------------------------------------------------------------------ deck controller
  const Deck = {
    current: null,
    clock: new Clock(() => Deck.cue()),
    scene(el) { return S[el.dataset.scene]; },
    reset(el) { const s = this.scene(el); clearBeats(el); instantly(el, () => s.reset && s.reset(el)); },
    final(el) { const s = this.scene(el); clearBeats(el); instantly(el, () => { s.reset && s.reset(el); s.final(el); }); },
    enter(el, { now = false } = {}) {
      this.clock.stop(); this.current = el; el.dataset.mode = 'auto';
      const s = this.scene(el);
      if (Reveal.isPrintView()) return this.final(el);
      if (!motion) { if (s.manualOnly) this.reset(el); else this.final(el); el.dataset.mode = 'still'; return this.cue(); }
      this.reset(el);
      const steps = s.steps(el);
      if (!steps.length) { el.dataset.mode = 'manual'; return this.cue(); }
      this.clock.start(steps, now ? Math.max(0, steps[0][0] - 400) : 0);
    },
    manual(el) { if (this.current !== el) return; this.clock.stop(); el.dataset.mode = 'manual'; this.cue(); },
    cue() {
      const el = this.current; if (!el) return;
      const c = $(el, '.cue'), pause = $(el, '[data-act="pause"]'); if (!c) return;
      const n = this.clock.nextIn();
      pause.textContent = this.clock.paused ? 'Resume' : 'Pause';
      pause.disabled = !(this.clock.running || this.clock.paused);
      if (el.dataset.mode === 'manual') c.textContent = this.scene(el).manualOnly ? 'click to reveal' : 'you have control';
      else if (el.dataset.mode === 'still') c.textContent = 'motion off';
      else if (this.clock.paused) c.textContent = 'paused';
      else c.textContent = n == null ? '' : `next in ${Math.ceil(n / 1000)} s`;
    },
    controls(el) {
      const bar = document.createElement('div');
      bar.className = 'scene-controls';
      bar.innerHTML = '<span class="cue" aria-live="off"></span><button type="button" data-act="replay">Replay</button><button type="button" data-act="now">Replay now</button><button type="button" data-act="pause">Pause</button><button type="button" data-act="final">Show result</button><button type="button" data-act="motion" aria-pressed="true" title="Turn scheduled animations on or off">Motion: on</button>';
      bar.addEventListener('click', e => {
        const act = e.target.dataset.act; if (!act) return;
        if (act === 'motion') { motion = !motion; paintMotion(); this.enter(el); return; }
        if (act === 'replay') this.enter(el);
        if (act === 'now') this.enter(el, { now: true });
        if (act === 'pause') { if (this.clock.paused) { this.clock.paused = false; this.clock.resume(); } else this.clock.pause(); }
        if (act === 'final') { this.clock.stop(); this.final(el); el.dataset.mode = 'manual'; this.cue(); }
      });
      el.appendChild(bar);
    },
  };
  window.Deck = Deck;

  // Space/Enter on a control must not also advance the deck; arrows on a slider move the slider.
  document.addEventListener('keydown', e => {
    const t = e.target;
    if (t.closest && t.closest('.reveal button, .reveal [role="slider"]') && [' ', 'Enter'].includes(e.key)) e.stopPropagation();
  }, true);

  const paintMotion = () => $$(document, '[data-act="motion"]').forEach(b => { b.textContent = `Motion: ${motion ? 'on' : 'off'}`; b.setAttribute('aria-pressed', String(motion)); });

  Reveal.initialize({
    width: 1280, height: 720, margin: 0.04, center: false, hash: true, controls: true, progress: true, slideNumber: 'c/t',
    transition: 'fade', backgroundTransition: 'fade', plugins: [RevealNotes], pdfSeparateFragments: false,
  }).then(() => {
    $$(document, '.reveal .slides section[data-scene]').forEach(el => {
      const s = Deck.scene(el); if (s.init) s.init(el);
      Deck.controls(el);
      if (Reveal.isPrintView()) Deck.final(el); else Deck.reset(el);
    });
    paintMotion();
    if (!Reveal.isPrintView()) Deck.enter(Reveal.getCurrentSlide());
    Reveal.on('slidechanged', e => Deck.enter(e.currentSlide));
    setInterval(() => Deck.cue(), 500);
  });
})();
