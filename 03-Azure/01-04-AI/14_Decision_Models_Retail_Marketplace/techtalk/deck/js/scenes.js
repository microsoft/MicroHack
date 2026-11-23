/* Launch Day at Zava: scenes for the beat engine (js/beat-engine.js).
   Every step sets absolute state and never starts its own timer: the engine replays, pauses, settles
   and prints them. Numbers come from js/data.js (TALK_DATA: recorded runs; TALK_WALK: walkthroughs). */
(() => {
  const D = window.TALK_DATA, W = window.TALK_WALK;
  const q = s => Beat.$(Beat.el(), s);
  const qa = s => Beat.$$(Beat.el(), s);
  const esc = s => String(s).replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
  const nice = s => String(s).replace(/_/g, ' ');
  const pct = p => `${Math.round(p * 100)}%`;
  const svgNS = 'http://www.w3.org/2000/svg';
  const svgEl = (tag, attrs = {}, parent) => { const e = document.createElementNS(svgNS, tag); for (const k in attrs) e.setAttribute(k, attrs[k]); if (parent) parent.appendChild(e); return e; };
  const LANE = { publish: 'var(--publish)', auto_fix: 'var(--fix)', review: 'var(--person)', reject: 'var(--reject)' };
  const OUTCOMES = Object.keys(LANE);

  // Show several elements; their own --d (inline) staggers them.
  const show = (l, ...sels) => sels.forEach(s => qa(s).forEach(e => Beat.show(e, l)));
  const head = l => show(l, ':scope > .kicker', ':scope > .title', ':scope > .subtitle');

  // Draw a settled state without CSS transitions; a live step lets them run.
  const snap = (el, live, fn) => { if (live) return fn(); el.classList.add('snap'); fn(); void el.offsetWidth; el.classList.remove('snap'); };
  const place = (e, x, y, live) => snap(e, live, () => { e.style.left = `${x}px`; e.style.top = `${y}px`; });
  const flash = (gate, outcome, live) => { gate.style.setProperty('--fc', LANE[outcome] || 'var(--model)'); Beat.go(gate, live, 'flash'); };

  // A number that counts from one value to another live, holds while paused and is exact when settled.
  let ctSeq = 0;
  const countUp = (e, from, to, live, ms, fmt) => {
    if (!live) { e.dataset.ct = ''; e.textContent = fmt(to); return; }
    const id = String(++ctSeq), sec = e.closest('section'); e.dataset.ct = id;
    let t0 = null, held = 0, last = 0;
    const tick = now => {
      if (e.dataset.ct !== id) return;
      if (t0 === null) { t0 = now; last = now; }
      if (sec.classList.contains('motion-paused')) held += now - last;
      last = now;
      const p = Math.min(1, (now - t0 - held) / ms);
      e.textContent = fmt(from + (to - from) * (1 - Math.pow(1 - p, 3)));
      if (p < 1 && sec.classList.contains('present')) requestAnimationFrame(tick); else e.textContent = fmt(to);
    };
    requestAnimationFrame(tick);
  };
  const int = v => Math.round(v).toLocaleString('en');
  const dec = n => v => v.toFixed(n);

  // A manual choice finishes whatever was still building, then takes over the slide.
  const takeOver = () => { TalkDeck.clock.flush(); TalkDeck.clock.check(); };

  // Tags: paper listings that move through the gate into a lane.
  const tagHTML = (t, i) => `<div class="ttag k-pop" data-i="${i}"><b>${t.id} · €${t.price.toFixed(2)}</b><span>${esc(t.title)}</span></div>`;
  const resetTag = (e, x, y) => { OUTCOMES.forEach(o => e.classList.remove(o)); e.classList.remove('pick', 'flipping'); place(e, x, y, false); };
  const slotIndex = (i) => D.tour.slice(0, i).filter(x => x.outcome === D.tour[i].outcome).length;

  const S = {};

  // ------------------------------------------------------------------ 1 cover
  const CV = { start: [640, 351], gate: [767, 351], tops: { publish: 176, auto_fix: 278, review: 380, reject: 482 } };
  S.cover = {
    init(sec) { Beat.$(sec, '.tags').innerHTML = D.tour.map(tagHTML).join(''); },
    reset(sec) { Beat.$$(sec, '.ttag').forEach(e => resetTag(e, ...CV.start)); Beat.$(sec, '.gate').classList.remove('alive'); },
    beats: [[
      [0, l => show(l, '.cv-clock', '.cv-title')],
      [700, l => show(l, '.cv-sub')],
      [900, l => show(l, '.gate', '.cv-by')],
      [1300, l => show(l, '.gate-label', '.lane')],
      ...D.tour.flatMap((t, i) => {
        const T = 3200 + i * 2600, tag = () => q(`.ttag[data-i="${i}"]`);
        return [
          [T, l => Beat.show(tag(), l)],
          [T + 500, l => place(tag(), ...CV.gate, l)],
          [T + 1250, l => flash(q('.gate'), t.outcome, l)],
          [T + 1400, l => { const e = tag(); e.classList.add(t.outcome); place(e, 914 + slotIndex(i) * 150, CV.tops[t.outcome] + 34, l); }],
        ];
      }),
      [16200, () => q('.gate').classList.add('alive')],
    ]],
  };

  // ------------------------------------------------------------------ chapters (one scene, three slides)
  S.chapter = {
    init(sec) {
      const pos = +sec.dataset.pos, x = Math.round(pos * 1136);
      const lit = Beat.$(sec, '.lit'), here = Beat.$(sec, '.here');
      lit.style.width = `${x}px`; lit.classList.add('k-growx'); lit.style.animationDuration = '1700ms';
      here.style.left = `${x}px`; here.classList.add('k-pop');
      Beat.$$(sec, '.flaps b').forEach(b => { b.dataset.f = b.textContent; });
    },
    reset(sec) { Beat.$$(sec, '.flaps b:not(.sep)').forEach(b => { b.textContent = '\u00a0'; b.classList.remove('flipping'); }); },
    beats: [[
      [0, l => show(l, '.ch-board-label', '.flaps')],
      [200, l => show(l, '.ch-label', '.ch-title', '.ch-sub', '.weekend')],
      ...[0, 1, 2, 3, 4].map(i => [900 + i * 170, l => {
        const b = qa('.flaps b')[i]; if (!b || b.classList.contains('sep')) return;
        b.textContent = b.dataset.f; Beat.go(b, l, 'flipping');
      }]),
      [1500, l => show(l, '.lit')],
      [3100, l => show(l, '.here')],
    ]],
  };

  // ------------------------------------------------------------------ 3 numbers
  const COLS = [['publish', 'Publish everything'], ['hand', 'Check everything by hand'], ['gate', 'Your gate on Monday']];
  const TONE = {
    publish: { live: 'publish', bad: 'reject', hours: '', cost: '' },
    hand: { live: 'reject', bad: 'publish', hours: 'reject', cost: 'reject' },
    gate: { live: 'publish', bad: 'person', hours: 'person', cost: 'publish' },
  };
  S.numbers = {
    init(sec) {
      COLS.forEach(([k, label]) => {
        const col = Beat.$(sec, `.col[data-col="${k}"]`), V = W.scenarios[k];
        col.innerHTML = `${k === 'gate' ? '<i class="frame k-fade"></i>' : ''}<button type="button" class="chd k-rise" aria-pressed="false">${label}</button>` +
          ['live', 'bad', 'hours', 'cost'].map((m, j) => `<p class="cv k-rise ${TONE[k][m] ? 'c-' + TONE[k][m] : ''}" data-m="${m}" style="top:${46 + j * 50}px;--d:${150 + j * 110}ms">${V[m]}</p>`).join('');
        Beat.$(col, '.chd').addEventListener('click', () => {
          takeOver();
          const board = Beat.$(sec, '.board'), on = !col.classList.contains('focus');
          Beat.$$(sec, '.col').forEach(c => { c.classList.toggle('focus', on && c === col); Beat.$(c, '.chd').setAttribute('aria-pressed', String(on && c === col)); });
          board.classList.toggle('focusing', on);
        });
      });
    },
    reset(sec) {
      Beat.$$(sec, '.hero .n').forEach(n => { n.textContent = '0'; });
      Beat.$(sec, '.board').classList.remove('focusing');
      Beat.$$(sec, '.col').forEach(c => { c.classList.remove('focus'); Beat.$(c, '.chd').setAttribute('aria-pressed', 'false'); });
    },
    beats: [
      [
        [0, l => head(l)],
        [900, l => { show(l, '.hero.h1'); countUp(q('.h1 .n'), 0, 10000, l, 1600, int); }],
        [1700, l => { show(l, '.hero.h2'); countUp(q('.h2 .n'), 0, 3, l, 700, int); }],
        [2500, l => { show(l, '.hero.h3'); countUp(q('.h3 .n'), 0, 2, l, 700, int); }],
        [3400, l => show(l, '.foot')],
      ],
      [
        [0, l => show(l, '.board .rl')],
        [400, l => show(l, '.col.c0 .chd', '.col.c0 .cv')],
        [1700, l => Beat.go(q('.col.c0 [data-m="bad"]'), l, 'stampin')],
        [12000, l => show(l, '.col.c1 .chd', '.col.c1 .cv')],
        [13300, l => qa('.col.c1 [data-m="hours"], .col.c1 [data-m="cost"]').forEach(e => Beat.go(e, l, 'stampin'))],
      ],
      [
        [0, l => show(l, '.col.c2 .frame', '.col.c2 .chd', '.col.c2 .cv')],
        [1800, l => show(l, '.moral')],
      ],
    ],
  };

  // ------------------------------------------------------------------ 4 three tools
  S.tools = {
    init(sec) {
      const T = D.three_tools, L = T.listing, text = L.description;
      const spelled = '06 one two 34 56 78';
      Beat.$(sec, '.pt-id').textContent = `${L.id} · €${L.price.toFixed(2)} · filed under ${nice(L.seller_category)}`;
      Beat.$(sec, '.pt-text').innerHTML = esc(text).replace(spelled, `<span class="hit">${spelled}</span>`);
      Beat.$(sec, '.tl-q span').textContent = T.question;
      const m = /\b0\d{9}\b/.exec(text);
      Beat.$(sec, '.t-rule .tv').innerHTML = m ? `<span class="c-reject">match: ${esc(m[0])}</span>` : '<span class="c-reject">no match</span>';
      Beat.$(sec, '.t-rule .tm').textContent = m ? 'The pattern found a number.' : 'Ran just now, in this browser. The seller spelled the number out.';
      Beat.$(sec, '.t-llm .tv').innerHTML = `${T.llm.value === true ? 'true' : esc(T.llm.value)} <small>(no probability)</small>`;
      Beat.$(sec, '.t-llm .tm').textContent = `${T.llm.latency_ms.toLocaleString('en')} ms · ${T.llm.output_tokens} output tokens`;
      Beat.$(sec, '.t-dm .tv').textContent = `P(yes) = ${T.decision.probability.toFixed(3)}`;
      Beat.$(sec, '.t-dm .tm').textContent = `${T.decision.latency_ms} ms · ${T.decision.output_tokens} output tokens`;
      const max = Math.max(T.llm.latency_ms, T.decision.latency_ms);
      [['.t-llm', T.llm], ['.t-dm', T.decision]].forEach(([s, r]) => {
        const race = Beat.$(sec, `${s} .race`);
        race.style.setProperty('--w', `${Math.max(3, r.latency_ms / max * 100)}%`); race.style.setProperty('--dur', `${r.latency_ms}ms`);
      });
    },
    reset(sec) { Beat.$(sec, '.hit').classList.remove('lit'); Beat.$$(sec, '.race').forEach(r => r.classList.remove('go', 'done')); Beat.$(sec, '.scan').classList.remove('go'); },
    beats: [
      [
        [0, l => head(l)],
        [400, l => show(l, '.big-tag')],
        [800, l => show(l, '.tl-q')],
        [2400, l => show(l, '.foot')],
      ],
      [
        [0, l => show(l, '.t-rule')],
        [600, l => Beat.go(q('.scan'), l)],
        [2200, l => show(l, '.t-rule .tv')],
        [2700, l => { show(l, '.t-rule .tm'); q('.hit').classList.add('lit'); }],
      ],
      [
        [0, l => show(l, '.t-llm', '.t-dm')],
        [900, l => qa('.race').forEach(r => { r.classList.remove('go', 'done'); if (l) { void r.offsetWidth; r.classList.add('go'); } else r.classList.add('done'); })],
        [900 + D.three_tools.decision.latency_ms, l => show(l, '.t-dm .tv', '.t-dm .tm')],
        [900 + D.three_tools.llm.latency_ms, l => show(l, '.t-llm .tv', '.t-llm .tm')],
        [4800, l => show(l, '.moral')],
      ],
    ],
  };

  // ------------------------------------------------------------------ 5 contract
  const focusGroup = n => {
    const sec = Beat.el();
    Beat.$$(sec, '.grp').forEach(g => g.classList.toggle('focus', g.classList.contains(`g${n}`)));
    sec.classList.toggle('focusing', !!n);
  };
  S.contract = {
    reset(sec) { sec.classList.remove('focusing'); Beat.$$(sec, '.grp').forEach(g => g.classList.remove('focus')); Beat.$(sec, '.t-req').classList.remove('go'); },
    beats: [
      [
        [0, l => head(l)],
        [600, l => show(l, '.req')],
        [2400, l => show(l, '.foot')],
        [7000, () => focusGroup(1)],
        [17000, () => focusGroup(2)],
        [29000, () => focusGroup(3)],
        [42000, () => focusGroup(0)],
      ],
      [
        [0, l => { focusGroup(0); Beat.go(q('.t-req'), l); }],
        [900, l => show(l, '.res')],
        [1100, l => { const R = W.contract; countUp(q('.a1'), 0, R.contact, l, 1200, dec(4)); countUp(q('.a2'), 0, R.banned, l, 1200, dec(4)); countUp(q('.a3'), 0, R.input_tokens, l, 1000, int); countUp(q('.a4'), 0, R.output_tokens, l, 600, int); }],
      ],
      [
        [0, l => show(l, '.myrules')],
        [1500, l => show(l, '.moral')],
      ],
    ],
  };

  // ------------------------------------------------------------------ 6 question types
  const barsHTML = (rows, second) => rows.map(([k, p], i) => `<span class="bar${second && i === 1 ? ' second' : ''}"><span>${esc(nice(k))}</span><span class="tr"><span class="fl" data-w="${p}"></span></span><span class="p">${pct(p)}</span></span>`).join('');
  const fill = (sel, live) => { const sec = Beat.el(); snap(sec, live, () => Beat.$$(sec, `${sel} .fl`).forEach(f => { f.style.width = `${Math.max(1, f.dataset.w * 100)}%`; })); };
  S.types = {
    init(sec) {
      const T = D.types;
      const set = (s, ask, r) => { Beat.$(sec, `${s} .ask`).textContent = ask; Beat.$(sec, `${s} .who`).textContent = `${r.id} · ${r.title}`; };
      set('.ty-yes', 'Does it ask shoppers to contact the seller outside the marketplace?', T.yes_no);
      set('.ty-ch', 'Which category does the product belong to?', T.choice);
      set('.ty-sc', 'How useful is it to a shopper deciding whether to buy?', T.score);
      Beat.$(sec, '.ty-ch .bars').innerHTML = barsHTML(T.choice.answer.distribution.slice(0, 4), true);
      Beat.$(sec, '.ty-sc .bars').innerHTML = barsHTML(T.score.answer.distribution, false);
      Beat.$$(sec, '.type').forEach(b => b.addEventListener('click', () => {
        takeOver();
        const on = !b.classList.contains('zoom');
        Beat.$$(sec, '.type').forEach(x => { x.classList.toggle('zoom', on && x === b); x.setAttribute('aria-pressed', String(on && x === b)); });
        sec.classList.toggle('zooming', on);
      }));
    },
    reset(sec) {
      Beat.$(sec, '.gauge .n').textContent = '0.000';
      snap(sec, false, () => Beat.$$(sec, '.fl').forEach(f => { f.style.width = '0'; }));
      sec.classList.remove('zooming'); Beat.$$(sec, '.type').forEach(x => { x.classList.remove('zoom'); x.setAttribute('aria-pressed', 'false'); });
    },
    beats: [
      [
        [0, l => head(l)],
        [900, l => show(l, '.ty-yes')],
        [1500, l => countUp(q('.gauge .n'), 0, D.types.yes_no.answer.probability, l, 1400, dec(3))],
        [2600, l => show(l, '.foot')],
      ],
      [
        [0, l => show(l, '.ty-ch')],
        [600, l => fill('.ty-ch', l)],
        [6000, l => show(l, '.ty-sc')],
        [6600, l => fill('.ty-sc', l)],
      ],
      [
        [0, () => { const sec = Beat.el(), b = q('.ty-ch'); sec.classList.add('zooming'); qa('.type').forEach(x => { x.classList.toggle('zoom', x === b); x.setAttribute('aria-pressed', String(x === b)); }); }],
        [1200, l => show(l, '.moral')],
      ],
    ],
  };

  // ------------------------------------------------------------------ 7 Ignite
  S.ignite = {
    beats: [
      [
        [0, l => head(l)],
        [500, l => show(l, '.ig-hero')],
        [900, l => Beat.show(qa('.ig-h')[0], l)],
        ...[0, 1, 2, 3].map(i => [1300 + i * 320, l => Beat.show(qa('.fact.f1')[i], l)]),
        [3200, l => show(l, '.foot')],
      ],
      [
        [0, l => Beat.show(qa('.ig-h')[1], l)],
        ...[0, 1, 2, 3].map(i => [300 + i * 320, l => Beat.show(qa('.fact.f2')[i], l)]),
        [2400, l => show(l, '.moral')],
      ],
    ],
  };

  // ------------------------------------------------------------------ 9 gate tour
  const TR = { start: [420, 361], gate: [459, 361], tops: { publish: 186, auto_fix: 288, review: 390, reject: 492 } };
  const CAPTION = t => {
    if (t.outcome !== t.expected) return `Sure enough to act, but Zava's answer key says <b class="c-person">${esc(nice(t.expected === 'publish' ? 'smart home' : t.expected))}</b>.`;
    return { publish: 'Every check passes. Live in under a minute, no person needed.',
      auto_fix: 'Filed in the wrong aisle. The model is sure enough to fix the category itself.',
      review: 'The model is unsure about quality, so <b class="c-person">a person decides</b>.',
      reject: 'A phone number spelled out to dodge a rule. Rejected, with the reason.' }[t.outcome];
  };
  const inspect = (sec, i) => {
    const t = D.tour[i], a = t.answers[0];
    Beat.$(sec, '.in-id').textContent = `${t.id} · €${t.price.toFixed(2)} · filed under ${nice(t.seller_category)}`;
    Beat.$(sec, '.in-title').textContent = t.title;
    Beat.$(sec, '.in-desc').textContent = t.description.replace(/\s+/g, ' ');
    Beat.$(sec, '.in-q').textContent = a.name;
    Beat.$(sec, '.in-p').textContent = a.kind === 'yes_no' ? `P(yes) ${a.probability.toFixed(3)}` : `${nice(a.value)} ${(a.probability * 100).toFixed(1)}%`;
    Beat.$(sec, '.in-why').innerHTML = CAPTION(t);
    Beat.$$(sec, '.chips .chip').forEach(b => b.setAttribute('aria-pressed', String(+b.dataset.i === i)));
    Beat.$$(sec, '.ttag').forEach(e => e.classList.toggle('pick', +e.dataset.i === i && e.classList.contains('on')));
  };
  const tourSteps = (i, T) => {
    const t = D.tour[i], tag = () => q(`.ttag[data-i="${i}"]`);
    return [
      [T, l => { Beat.show(tag(), l); inspect(Beat.el(), i); Beat.pulse(q('.inspect'), l); }],
      [T + 700, l => place(tag(), ...TR.gate, l)],
      [T + 1450, l => flash(q('.gate'), t.outcome, l)],
      [T + 1600, l => { const e = tag(); e.classList.add(t.outcome); place(e, 612 + slotIndex(i) * 160, TR.tops[t.outcome] + 34, l); }],
    ];
  };
  S.tour = {
    init(sec) {
      Beat.$(sec, '.tags').innerHTML = D.tour.map(tagHTML).join('') + '<p class="policy-flag k-pop" style="left:930px;top:338px">Zava says: smart home</p>';
      Beat.$(sec, '.chips').innerHTML = D.tour.map((t, i) => `<button type="button" class="chip" data-i="${i}" aria-pressed="false" title="${esc(t.title)}">${t.id}</button>`).join('');
      Beat.$$(sec, '.chips .chip').forEach(b => b.addEventListener('click', () => { takeOver(); inspect(sec, +b.dataset.i); }));
    },
    reset(sec) {
      Beat.$$(sec, '.ttag').forEach(e => resetTag(e, ...TR.start));
      Beat.$(sec, '.in-id').textContent = 'Waiting for the first listing';
      ['.in-title', '.in-desc', '.in-q', '.in-p', '.in-why'].forEach(s => { Beat.$(sec, s).textContent = ''; });
      Beat.$$(sec, '.chips .chip').forEach(b => b.setAttribute('aria-pressed', 'false'));
    },
    beats: [
      [
        [0, l => head(l)],
        [600, l => show(l, '.inspect', '.gate', '.lane')],
        [1500, l => show(l, '.chips')],
        [2200, l => show(l, '.foot')],
        ...tourSteps(0, 3500),
        ...tourSteps(1, 15000),
      ],
      [...tourSteps(2, 0), ...tourSteps(3, 12000)],
      [
        ...tourSteps(4, 0),
        [3200, l => { show(l, '.policy-flag'); const e = q('.ttag[data-i="4"]'); e.classList.remove('auto_fix'); e.classList.add('review'); Beat.go(e, l, 'flipping'); }],
        [4400, l => show(l, '.moral')],
      ],
    ],
  };

  // ------------------------------------------------------------------ 10 the dial
  const X0 = 40, X1 = 1112, AXIS = 262;
  const px = p => X0 + p * (X1 - X0);
  const dialSet = (sec, v, live) => {
    const st = sec._dial;
    st.v = { no: Math.max(0, v.no), yes: Math.min(1, v.yes) };
    const { no, yes } = st.v;
    snap(sec, live, () => {
      st.zone.setAttribute('x', px(no)); st.zone.setAttribute('width', Math.max(0, px(yes) - px(no)));
      for (const k of ['no', 'yes']) {
        const { g, label } = st.lines[k];
        g.style.transform = `translate(${px(st.v[k])}px, 22px)`;
        g.setAttribute('aria-valuenow', st.v[k]); g.setAttribute('aria-valuetext', `${k} line at ${st.v[k].toFixed(2)}`);
        label.textContent = `${k} ${k === 'no' ? '<=' : '>='} ${st.v[k].toFixed(2)}`;
      }
    });
    const P = D.dial.pairs;
    const c = { clear: P.filter(([p]) => p <= no).length, flag: P.filter(([p]) => p >= yes).length, miss: P.filter(([p, y]) => p <= no && y).length };
    c.person = P.length - c.clear - c.flag;
    for (const k in c) Beat.$(sec, `[data-c="${k}"]`).textContent = c[k];
    Beat.$(sec, '[data-c="miss"]').className = `v ${c.miss ? 'c-reject' : 'c-publish'}`;
  };
  S.dial = {
    init(sec) {
      const svg = Beat.$(sec, 'svg.dialsvg'), dd = D.dial, st = sec._dial = { lines: {} };
      Beat.$(sec, '.dial-q').innerHTML = `Question <b class="mono">${esc(dd.question)}</b>: does the listing claim a feature the manufacturer doesn't mention? <span class="c-reject">Red dots</span> really do.`;
      st.zone = svgEl('rect', { class: 'zone-person', y: 20, height: AXIS - 20 }, svg);
      svgEl('line', { class: 'axis', x1: X0, x2: X1, y1: AXIS, y2: AXIS }, svg);
      for (const t of [0, 0.2, 0.4, 0.6, 0.8, 1]) { svgEl('line', { class: 'axis', x1: px(t), x2: px(t), y1: AXIS, y2: AXIS + 8 }, svg); svgEl('text', { x: px(t), y: AXIS + 28, 'text-anchor': 'middle' }, svg).textContent = t.toFixed(1); }
      svgEl('text', { x: X1, y: AXIS + 28, 'text-anchor': 'end', dy: 20 }, svg).textContent = 'probability of yes';
      let seed = 7; const rnd = () => (seed = (seed * 16807) % 2147483647) / 2147483647;
      const dots = svgEl('g', { class: 'dots k-dots' }, svg);
      const good = svgEl('g', {}, dots), bad = svgEl('g', {}, dots);
      for (const [p, y] of dd.pairs) svgEl('circle', { class: `dot${y ? ' bad' : ''}`, cx: px(p), cy: 40 + rnd() * (AXIS - 60), r: y ? 7 : 3.2, style: `--dd:${Math.round(p * 1800)}ms` }, y ? bad : good);
      for (const k of ['no', 'yes']) {
        const g = svgEl('g', { class: `handle ${k}`, tabindex: 0, role: 'slider', 'aria-label': `${k} line`, 'aria-valuemin': 0, 'aria-valuemax': 1 }, svg);
        svgEl('line', { class: `line ${k}`, x1: 0, x2: 0, y1: 14, y2: AXIS - 22 }, g);
        svgEl('rect', { x: -48, y: -20, width: 96, height: 30 }, g);
        const label = svgEl('text', { x: 0, y: 1, 'text-anchor': 'middle' }, g);
        st.lines[k] = { g, label };
        const move = p => {
          const v = { ...st.v, [k]: p };
          if (k === 'no') v.no = Math.min(v.no, v.yes - 0.01); else v.yes = Math.max(v.yes, v.no + 0.01);
          dialSet(sec, v, true);
        };
        const fromX = clientX => { const r = svg.getBoundingClientRect(); move(Math.round(Math.min(1, Math.max(0, ((clientX - r.left) / r.width * 1152 - X0) / (X1 - X0))) * 100) / 100); };
        g.addEventListener('pointerdown', e => { takeOver(); svg.classList.add('dragging'); g.setPointerCapture(e.pointerId); fromX(e.clientX); });
        g.addEventListener('pointermove', e => { if (g.hasPointerCapture(e.pointerId)) fromX(e.clientX); });
        g.addEventListener('pointerup', e => { svg.classList.remove('dragging'); g.releasePointerCapture(e.pointerId); });
        g.addEventListener('keydown', e => {
          const d = { ArrowLeft: -1, ArrowDown: -1, ArrowRight: 1, ArrowUp: 1 }[e.key]; if (!d) return;
          e.preventDefault(); e.stopPropagation(); takeOver();
          move(Math.round((st.v[k] + d * (e.shiftKey ? 0.05 : 0.01)) * 100) / 100);
        });
      }
      dialSet(sec, dd.default, false);
    },
    reset(sec) { dialSet(sec, D.dial.default, false); },
    beats: [
      [
        [0, l => head(l)],
        [600, l => show(l, '.dialsvg')],
        [900, l => show(l, '.counts')],
        [1300, l => show(l, '.dots')],
        [3400, l => show(l, '.foot')],
      ],
      [
        [0, l => dialSet(Beat.el(), D.dial.tuned, l)],
        [1500, l => show(l, '.moral')],
      ],
    ],
  };

  // ------------------------------------------------------------------ 11 calibration
  const CX = 60, CW = 540, CY = 20, CH = 340;
  const grow = (sec, which, on, live) => snap(sec, live, () => {
    for (const b of sec._bars) {
      const r = b[which], h = on ? (which === 'said' ? b.row.mean_p : b.row.observed) * CH : 0;
      r.style.height = `${h}px`; r.style.y = `${CY + CH - h}px`;
    }
  });
  S.calib = {
    init(sec) {
      const C = D.calibration, svg = Beat.$(sec, 'svg.rel');
      for (let i = 0; i <= 10; i += 2) {
        svgEl('line', { class: 'grid', x1: CX, x2: CX + CW, y1: CY + CH - i / 10 * CH, y2: CY + CH - i / 10 * CH }, svg);
        svgEl('text', { x: CX - 10, y: CY + CH - i / 10 * CH + 5, 'text-anchor': 'end' }, svg).textContent = `${i * 10}%`;
        svgEl('text', { x: CX + i / 10 * CW, y: CY + CH + 40, 'text-anchor': 'middle' }, svg).textContent = `${i * 10}%`;
      }
      svgEl('text', { x: CX + CW / 2, y: CY + CH + 64, 'text-anchor': 'middle' }, svg).textContent = 'what the model said (probability of yes)';
      svgEl('rect', { class: 'hl k-fade', x: CX + 0.1 * CW, y: CY, width: 0.4 * CW, height: CH, rx: 8 }, svg);
      svgEl('line', { class: 'diag', x1: CX, y1: CY + CH, x2: CX + CW, y2: CY }, svg);
      sec._bars = C.table.map(row => {
        const x = CX + parseFloat(row.bin) * CW, w = CW / 20 - 5;
        const said = svgEl('rect', { class: 'said', x: x + 4, width: w, y: CY + CH, height: 0 }, svg);
        const happened = svgEl('rect', { class: 'happened', x: x + CW / 20 + 1, width: w, y: CY + CH, height: 0 }, svg);
        svgEl('text', { class: 'nl', x: x + CW / 20, y: CY + CH + 18, 'text-anchor': 'middle' }, svg).textContent = `n=${row.n}`;
        return { row, said, happened };
      });
      const maybe = C.table.filter(r => parseFloat(r.bin) >= 0.1 && parseFloat(r.bin) < 0.5);
      Beat.$(sec, '.cal-n').textContent = maybe.reduce((s, r) => s + r.n, 0);
      Beat.$(sec, '.cal-src').textContent = `unsupported_claim on Monday's 516 listings, recorded Microsoft-Decision-1.1 run. ECE ${C.ece.toFixed(3)}, Brier ${C.brier.toFixed(3)}.`;
    },
    reset(sec) { grow(sec, 'said', false, false); grow(sec, 'happened', false, false); Beat.$(sec, '.b-v .n').textContent = '0.0'; },
    beats: [
      [
        [0, l => head(l)],
        [500, l => show(l, '.rel')],
        [1500, l => show(l, '.legend')],
        [2500, l => grow(Beat.el(), 'said', true, l)],
        [6500, l => grow(Beat.el(), 'happened', true, l)],
        [7500, l => show(l, '.foot')],
      ],
      [
        [0, l => show(l, '.hl')],
        [600, l => show(l, '.cal-maybe')],
      ],
      [
        [0, l => show(l, '.bound')],
        [400, l => countUp(q('.b-v .n'), 0, D.upper_bound_1_in_387 * 100, l, 1400, dec(1))],
        [1800, l => show(l, '.moral')],
      ],
    ],
  };

  // ------------------------------------------------------------------ 12 compare
  const C6 = W.compare;
  const METRICS = [
    { k: 'acc', label: 'Outcome accuracy', v: C6.accuracy_pct, f: v => `${v}%`, better: 'high', say: 'The chat model is the most accurate. Case closed?' },
    { k: 'bad', label: 'Bad listings published', v: C6.bad_published, f: v => `${v}`, better: 'low', say: 'It still publishes <b class="c-reject">3</b> bad listings. The same model through the Decisions API publishes <b class="c-publish">0</b>.' },
    { k: 'lat', label: 'Latency (p50)', v: C6.latency_p50_ms, f: v => `${v.toLocaleString('en')} ms`, better: 'low', say: 'Ten times slower: it writes about 190 tokens of JSON to say what a decision model says with a few probabilities.' },
    { k: 'cost', label: 'Cost per 10,000 listings', v: C6.cost_per_10k_usd, f: v => `$${v.toFixed(2)}`, better: 'low', say: 'And about four times the cost.' },
    { k: 'prob', label: 'Probabilities for a dial', v: C6.probabilities, f: v => (v ? 'yes' : 'no'), better: 'high', say: 'No probabilities: no dial, and no way to send "unsure" to a person.' },
  ];
  const cmpShow = (sec, k, live) => {
    const m = METRICS.find(x => x.k === k), max = Math.max(...m.v);
    const best = m.better === 'high' ? Math.max(...m.v) : Math.min(...m.v), worst = m.better === 'high' ? Math.min(...m.v) : Math.max(...m.v);
    snap(sec, live, () => Beat.$$(sec, '.mbar').forEach((b, i) => {
      const v = m.v[i];
      b.className = `mbar${v === best ? ' best' : ''}${v === worst ? ' worst' : ''}`;
      Beat.$(b, '.fill').style.width = `${max ? Math.max(2, v / max * 100) : 2}%`;
      Beat.$(b, '.fill').style.background = v === best ? 'var(--publish)' : v === worst ? 'var(--reject)' : 'var(--model)';
      Beat.$(b, '.val').textContent = m.f(v);
    }));
    Beat.$$(sec, '.metrics .chip').forEach(b => b.setAttribute('aria-pressed', String(b.dataset.k === k)));
    Beat.$(sec, '.verdict').innerHTML = m.say;
  };
  S.compare = {
    init(sec) {
      Beat.$(sec, '.metrics').innerHTML = METRICS.map(m => `<button type="button" class="chip" data-k="${m.k}" aria-pressed="false">${m.label}</button>`).join('');
      Beat.$(sec, '.mbars').innerHTML = C6.models.map((n, i) => `<div class="mbar" data-i="${i}"><p class="name">${n}</p><div class="track"><div class="fill"></div></div><p class="val">·</p></div>`).join('');
      Beat.$$(sec, '.metrics .chip').forEach(b => b.addEventListener('click', () => { takeOver(); cmpShow(sec, b.dataset.k, true); }));
    },
    reset(sec) {
      snap(sec, false, () => Beat.$$(sec, '.mbar').forEach(b => { b.className = 'mbar'; Beat.$(b, '.fill').style.width = '0'; Beat.$(b, '.val').textContent = '·'; }));
      Beat.$$(sec, '.metrics .chip').forEach(b => b.setAttribute('aria-pressed', 'false'));
      Beat.$(sec, '.verdict').innerHTML = '<span class="dim">Hypothesis: the most accurate model should run the gate.</span>';
    },
    beats: [
      [
        [0, l => head(l)],
        [600, l => show(l, '.metrics', '.mbars')],
        [2600, l => cmpShow(Beat.el(), 'acc', l)],
        [3200, l => show(l, '.foot')],
      ],
      [
        [0, l => cmpShow(Beat.el(), 'bad', l)],
        [10000, l => cmpShow(Beat.el(), 'lat', l)],
      ],
      [
        [0, l => cmpShow(Beat.el(), 'cost', l)],
        [8000, l => cmpShow(Beat.el(), 'prob', l)],
        [9400, l => show(l, '.moral')],
      ],
    ],
  };

  // ------------------------------------------------------------------ 14 the wow: sellers strike back
  const AT = { start: [470, 286], gate: [545, 286], live: [712, 184], review: [712, 320] };
  const A = W.attack;
  const btns = (audit, fix) => { q('.act-audit').disabled = !audit; q('.act-fix').disabled = !fix; };
  S.attack = {
    init(sec) {
      const words = A.clause.split(' ');
      Beat.$(sec, '.ins').innerHTML = words.map(w => `<span class="w k-rise"> ${esc(w)}</span>`).join('');
      const next = want => () => { if (Reveal.getCurrentSlide() === sec && +sec.dataset.beat === want) Reveal.next(); };
      Beat.$(sec, '.act-audit').addEventListener('click', next(0));
      Beat.$(sec, '.act-fix').addEventListener('click', next(1));
    },
    reset(sec) {
      const tag = Beat.$(sec, '.ttag');
      OUTCOMES.forEach(o => tag.classList.remove(o)); place(tag, ...AT.start, false);
      Beat.$(sec, '.note').classList.remove('lit'); Beat.$(sec, '.scan').classList.remove('go');
      Beat.$(sec, '.readout .n').textContent = A.before_p.toFixed(2); Beat.$(sec, '.readout').classList.remove('caught');
      const st = Beat.$(sec, '.stamp'); st.textContent = 'An attack got through'; st.style.color = ''; st.style.borderColor = '';
      Beat.$(sec, '.im-v .n').textContent = String(A.bad_after);
      Beat.$(sec, '.act-audit').disabled = false; Beat.$(sec, '.act-fix').disabled = true;
    },
    beats: [
      [
        [0, l => { head(l); btns(true, false); }],
        [400, l => show(l, '.at-card')],
        [500, l => show(l, '.gate', '.lane')],
        [900, l => show(l, '.at-btns')],
        [1000, l => show(l, '.qpanel')],
        [1200, l => show(l, '.readout')],
        [2200, l => show(l, '.ttag')],
        [2800, l => place(q('.ttag'), ...AT.gate, l)],
        [3500, l => flash(q('.gate'), 'publish', l)],
        [3650, l => { const e = q('.ttag'); e.classList.add('publish'); place(e, ...AT.live, l); }],
        [4400, l => show(l, '.foot')],
      ],
      [
        [0, l => { btns(false, true); Beat.go(q('.at-card .scan'), l); }],
        [1300, () => q('.note').classList.add('lit')],
        [1700, l => show(l, '.stamp')],
        [2300, l => Beat.go(q('.lane.publish'), l, 'hot')],
        [2500, l => { const e = q('.ttag'); e.classList.remove('publish'); place(e, ...AT.gate, l); }],
        [3200, l => show(l, '.at-why')],
      ],
      [
        [0, () => btns(false, false)],
        ...A.clause.split(' ').map((_, i) => [300 + i * 120, l => { const w = qa('.ins .w')[i]; if (w) Beat.show(w, l); }]),
        [2000, l => flash(q('.gate'), 'model', l)],
        [2300, l => { countUp(q('.readout .n'), A.before_p, A.after_p, l, 1100, dec(2)); q('.readout').classList.add('caught'); }],
        [3400, l => { const e = q('.ttag'); e.classList.add('review'); place(e, ...AT.review, l); }],
        [3500, l => { flash(q('.gate'), 'review', l); Beat.pulse(q('.pay'), l); }],
        [4300, l => { const st = q('.stamp'); st.textContent = 'Caught: a person decides'; st.style.color = 'var(--person)'; st.style.borderColor = 'var(--person)'; Beat.go(st, l, 'flipping'); }],
        [4600, l => { show(l, '.impact'); countUp(q('.im-v .n'), A.bad_before, A.bad_after, l, 1400, int); }],
        [6000, l => show(l, '.moral')],
      ],
    ],
  };

  // ------------------------------------------------------------------ 15 the pattern
  const PATTERN = {
    zava: { stages: [['Prepare the state', 'Seller text kept apart from the manufacturer\'s facts; the photo'],
      ['Ask atomic questions', 'Six yes/no, category (choice), quality (score)'], ['Apply the lines', 'no 0.20, a person, yes 0.80, tuned from costs'],
      ['Rules in code', 'Price against reference, unknown product to a person, precedence'], ['Escalate the unsure', 'Unsure or failed: the reviewer queue'],
      ['Log the outcome', 'Probabilities, lines, outcome, the reviewer\'s call']],
      ledger: ['request: ZM-0352', 'evidence: structured v1', 'questions: v2 (your fix)', 'model: Microsoft-Decision-1.1', 'contact: 0.999', 'outcome: reject'],
      src: 'Zava: the hack, an illustrative audit record for one real listing (ZM-0352).' },
    bank: { stages: [['Prepare the state', 'Customer message, disputed transaction, card status'],
      ['Ask atomic questions', 'Reason (choice), still has the card?, urgency (score)'], ['Apply the lines', 'Fraud at 0.30 or more: the fraud team at once'],
      ['Rules in code', 'Amount limits, deadlines, eligibility. Never moves money'], ['Escalate the unsure', 'Refund proposals: an agent approves'],
      ['Log the outcome', 'Probabilities, lines, the agent\'s decision, chargeback result']],
      ledger: ['request: dispute 4471', 'evidence: message + txn v2', 'questions: v1', 'model: Microsoft-Decision-1.1', 'reason: duplicate 0.97', 'outcome: refund proposal, agent'],
      src: 'Illustrative design, not a measured result. The stages stay the same; the questions and rules change.' },
    mfg: { stages: [['Prepare the state', 'Camera photo of the part, part spec, station'],
      ['Ask atomic questions', 'Visible crack?, defect type (choice), severity (score)'], ['Apply the lines', 'Crack at 0.90 or more: stop. 0.10 to 0.90: inspector'],
      ['Rules in code', 'Tolerances from sensors; two cracks in a row stop the line'], ['Escalate the unsure', '"Cannot tell": retake the photo, then an inspector'],
      ['Log the outcome', 'Probabilities, photo ID, inspector\'s verdict, scrap result']],
      ledger: ['request: part 88-1203', 'evidence: photo + spec v3', 'questions: v2', 'model: Microsoft-Decision-1.1', 'crack: 0.42', 'outcome: inspector'],
      src: 'Illustrative design, not a measured result. The stages stay the same; the questions and rules change.' },
  };
  const ppRender = (sec, s) => {
    const P = PATTERN[s];
    Beat.$$(sec, '.scen .chip').forEach(b => b.setAttribute('aria-pressed', String(b.dataset.s === s)));
    Beat.$$(sec, '.stage').forEach((x, i) => { Beat.$(x, '.h').textContent = P.stages[i][0]; Beat.$(x, '.d').textContent = P.stages[i][1]; });
    Beat.$$(sec, '.ledger p').forEach((x, i) => { const [k, ...v] = P.ledger[i].split(': '); x.innerHTML = `<span>${k}</span>: ${esc(v.join(': '))}`; });
    Beat.$(sec, '.pp-src').textContent = P.src;
  };
  const ppLight = (sec, n) => {
    Beat.$$(sec, '.stage').forEach((x, i) => x.classList.toggle('lit', i < n));
    Beat.$$(sec, '.ledger p').forEach((x, i) => x.classList.toggle('lit', i < n));
  };
  const ppFlip = (sec, s, live) => { ppRender(sec, s); ppLight(sec, 6); Beat.$$(sec, '.stage').forEach((x, i) => { x.style.setProperty('--d', `${i * 90}ms`); Beat.go(x, live, 'flipping'); }); };
  S.pattern = {
    init(sec) {
      Beat.$(sec, '.stages').innerHTML = [0, 1, 2, 3, 4, 5].map(i => `<div class="stage"><p class="n">${i + 1}</p><p class="h"></p><p class="d"></p></div>`).join('');
      Beat.$(sec, '.ledger').innerHTML = [0, 1, 2, 3, 4, 5].map(() => '<p></p>').join('');
      const x = i => 72 + 88 + i * 192;
      sec.insertAdjacentHTML('beforeend', [0, 1, 2, 3, 4, 5].map(i => `<div class="travel t-seg" data-i="${i}" style="offset-path:path('M${i ? x(i - 1) : 40} 228 H${x(i)}');--dur:800ms"></div>`).join(''));
      Beat.$$(sec, '.scen .chip').forEach(b => b.addEventListener('click', () => { takeOver(); ppFlip(sec, b.dataset.s, true); }));
      ppRender(sec, 'zava');
    },
    reset(sec) { ppRender(sec, 'zava'); ppLight(sec, 0); Beat.$$(sec, '.travel').forEach(t => t.classList.remove('go')); },
    beats: [
      [
        [0, l => head(l)],
        [400, l => show(l, '.scen')],
        [700, l => show(l, '.ledger')],
        ...[0, 1, 2, 3, 4, 5].flatMap(i => [
          [1500 + i * 4500, l => Beat.go(q(`.t-seg[data-i="${i}"]`), l)],
          [2300 + i * 4500, () => ppLight(Beat.el(), i + 1)],
        ]),
        [26000, l => show(l, '.foot')],
      ],
      [[0, l => ppFlip(Beat.el(), 'bank', l)]],
      [
        [0, l => ppFlip(Beat.el(), 'mfg', l)],
        [1600, l => show(l, '.moral')],
      ],
    ],
  };

  // ------------------------------------------------------------------ 16 the mission
  const STOPS = [['Friday evening', '1 · Safety check', 'Banned? Contact outside Zava?', ''], ['Saturday', '2 · Truth check', 'Fix Priya\'s question', ''],
    ['Sunday morning', '3 · Shelf check', 'Which aisle? Smart bulbs?', ''], ['Sunday afternoon', '4 · Go-live dial', 'Then open Monday, just once', ''],
    ['Monday', '5 · Sellers strike back', 'Stretch', 'stretch'], ['Any time', '6 · Under the hood', 'Optional', 'optional']];
  S.mission = {
    init(sec) {
      Beat.$(sec, '.stops').innerHTML = STOPS.map(([w, h, d, c], i) => `<div class="stop k-pop ${c}" style="left:${72 + i * 191}px"><p class="when">${w}</p><i class="dot"></i><p class="what">${h}</p><p class="q">${d}</p></div>`).join('');
    },
    reset(sec) { Beat.$$(sec, '.lamp').forEach(x => x.classList.remove('lit')); Beat.$(sec, '.t-rail').classList.remove('go'); },
    beats: [
      [
        [0, l => head(l)],
        [500, l => show(l, '.rail-line')],
        [800, l => Beat.go(q('.t-rail'), l)],
        ...STOPS.map((_, i) => [900 + i * 900, l => Beat.show(qa('.stop')[i], l)]),
      ],
      [
        [0, l => show(l, '.trk')],
        ...[0, 1, 2].map(i => [1300 + i * 500, () => qa('.lamp')[i].classList.add('lit')]),
        [3100, l => show(l, '.moral')],
      ],
    ],
  };

  // ------------------------------------------------------------------ 17 sign-off
  const TAKE = ['<b>Closed questions</b>: you define the answers before the model runs.',
    '<b>One idea per question</b>, a way out, and the maths in code.',
    '<b>Lines from costs</b>, and a person for the unsure middle.',
    '<b>Measure once</b>, on data you didn\'t tune on, and say how bad it could be.',
    '<b>Hybrid wins</b>: decision models for gates, LLMs to write, people to decide.'];
  const L1 = 'A probability isn\'t a decision.', L2 = 'Your rules are.';
  const typeTo = (sec, n) => {
    const a = L1.slice(0, n), b = n > L1.length ? L2.slice(0, n - L1.length) : '';
    Beat.$(sec, '.typed').innerHTML = esc(a) + (n > L1.length ? `<br><span class="l2">${esc(b)}</span>` : '');
  };
  S.signoff = {
    init(sec) {
      Beat.$(sec, '.takeaways').innerHTML = TAKE.map((t, i) => `<p class="tw k-wipe" style="top:${122 + i * 60}px"><i>${i + 1}</i>${t}</p>`).join('');
      sec.insertAdjacentHTML('beforeend', TAKE.map((_, i) => `<div class="travel t-take" data-i="${i}" style="offset-path:path('M24 ${137 + i * 60} H190');--dur:900ms"></div>`).join(''));
    },
    reset(sec) { typeTo(sec, 0); Beat.$(sec, '.so-line').classList.remove('typing', 'done'); Beat.$$(sec, '.travel').forEach(t => t.classList.remove('go')); },
    beats: [[
      [0, l => show(l, '.kicker')],
      [300, l => show(l, '.gate')],
      ...TAKE.flatMap((_, i) => {
        const T = 1600 + i * 2600;
        return [[T, l => Beat.go(q(`.t-take[data-i="${i}"]`), l)], [T + 650, l => flash(q('.gate'), 'model', l)], [T + 750, l => Beat.show(qa('.tw')[i], l)]];
      }),
      [14200, () => q('.so-line').classList.add('typing')],
      ...Array.from({ length: L1.length + L2.length }, (_, i) => [14300 + i * 55 + (i >= L1.length ? 500 : 0), () => typeTo(Beat.el(), i + 1)]),
      [17600, () => { const e = q('.so-line'); e.classList.remove('typing'); e.classList.add('done'); }],
      [17900, l => show(l, '.so-foot')],
    ]],
  };

  // Every reset first stops counters that may still be running from an earlier pass.
  for (const sc of Object.values(S)) {
    const r = sc.reset;
    sc.reset = sec => { Beat.$$(sec, '[data-ct]').forEach(e => { e.dataset.ct = ''; }); if (r) r(sec); };
  }
  window.SCENES = S;

  // Space or Enter on a control works the control and does not also move the deck.
  document.addEventListener('keydown', e => {
    const t = e.target;
    if (t.closest && t.closest('.reveal button, .reveal [role="slider"]') && [' ', 'Enter'].includes(e.key)) e.stopPropagation();
  }, true);
})();
