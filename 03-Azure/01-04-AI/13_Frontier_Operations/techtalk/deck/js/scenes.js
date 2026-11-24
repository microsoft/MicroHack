/* First light: the choreography of each slide, for js/beat-engine.js.

   Every built slide is a short storyboard of beats. Beat 0 plays on arrival; each click plays the next
   beat. Steps set absolute state and never start their own timers. Elements that travel between two
   positions use CSS transitions on a class; mv() turns transitions off when a step runs settled
   (a step back, Show all, print), so settled states never animate. */
(() => {
  const T = window.TALK;
  const get = p => p.split('.').reduce((o, k) => (o == null ? undefined : o[k]), T);
  const fmt = n => Number(n).toLocaleString('en-GB');

  // Fill every data-v element from data.js. A path ending in F is the same number, formatted.
  document.querySelectorAll('[data-v]').forEach(e => {
    const p = e.dataset.v;
    e.textContent = p.endsWith('F') ? fmt(get(p.slice(0, -1))) : get(p);
  });

  const B = () => window.Beat;
  const q = s => B().$(B().el(), s);
  const qa = s => B().$$(B().el(), s);
  const show = (e, l, d) => B().show(e, l, d);
  const pulse = (e, l, d) => B().pulse(e, l, d);
  const go = (e, l, c) => B().go(e, l, c);
  const flip = (e, l) => go(e, l, 'flipping');
  const K = ':is([class^="k-"], [class*=" k-"])';
  const head = [0, l => qa(':scope > .kicker, :scope > .title, :scope > .subtitle').forEach(x => show(x, l))];

  // Move an element between two states with its CSS transition when live, at once when settled.
  const mv = (e, cls, on, live) => {
    if (!e) return;
    const sec = e.closest('section');
    if (live) { sec.classList.remove('notrans'); void e.getBoundingClientRect(); } else sec.classList.add('notrans');
    e.classList.toggle(cls, on);
  };
  const html = (parent, markup) => { parent.insertAdjacentHTML('beforeend', markup); return parent.lastElementChild; };

  const S = {};

  // ---------------------------------------------------------------- 1 cover
  S.cover = {
    beats: [[
      [0, l => { show(q('.horizon'), l); show(q('.cv-glow'), l); }],
      [300, l => { show(q('.cv-event'), l); show(q('.cv-title'), l); }],
      [700, l => show(q('.cv-sun'), l)],
      [1000, l => show(q('.cv-sub'), l)],
      [2000, l => show(q('.cv-rays'), l, 0)],
      [2600, l => qa('.cv-cross .trail').forEach((x, i) => show(x, l, i * 260))],
      [3700, l => qa('.cv-cross .task').forEach((x, i) => show(x, l, i * 260))],
      [4600, l => { show(q('.gate'), l); show(q('.cv-gate-label'), l, 300); }],
      [5400, l => show(q('.cv-foot'), l)],
    ]],
  };

  // ---------------------------------------------------------------- chapters
  S.chapter = {
    beats: [[
      [0, l => { show(q('.horizon'), l); qa('svg ellipse.k-fade').forEach(x => show(x, l)); }],
      [300, l => { show(q('.ch-label'), l); show(q('.ch-title'), l); show(q('.course'), l, 200); }],
      [800, l => show(q('.sun-dot'), l)],
      [900, l => show(q('.ch-sub'), l)],
      [2600, l => qa('.mark-label').forEach((x, i) => show(x, l, i * 120))],
      [3000, l => show(q('.ch-list'), l)],
    ]],
  };

  // ---------------------------------------------------------------- 3 the month by hand
  S.month = {
    init(sec) {
      const b = sec.querySelector('.blocks');
      for (let r = 0; r < 4; r++) for (let c = 0; c < 3; c++) html(b, `<div class="blk k-pop" style="left:${c * 140}px;top:${r * 70}px"></div>`);
      sec.querySelectorAll('.cal-h, .cal-r').forEach(x => x.classList.add('k-fade'));
    },
    beats: [
      [
        head,
        [700, l => qa('.cal-h, .cal-r').forEach(x => show(x, l))],
        [900, l => show(qa('.steps li')[0], l)],
        ...[...Array(12)].map((_, i) => [1300 + i * 420, l => show(qa('.blk')[i], l)]),
        [2500, l => show(qa('.steps li')[1], l)],
        [4100, l => show(qa('.steps li')[2], l)],
        [5700, l => show(qa('.steps li')[3], l)],
      ],
      [
        [0, l => { show(q('.month-hero'), l); B().count(q('.month-hero .n'), T.month.personDays, l, 1200); }],
        [1800, l => show(q('.moral'), l)],
      ],
    ],
  };

  // ---------------------------------------------------------------- 4 rule or judgement
  const ORDER = ['mm', 'tol', 'mis', 'mil', 'dup', 'cn'];   // the handbook's order, for the sorted table
  const rowOf = k => T.statement.rows.findIndex(r => r[3] === (k === 'dup' ? 'dup2' : k));
  const TAGS = ORDER.slice().sort((a, b) => rowOf(a) - rowOf(b));   // top to bottom on the statement
  S.sort = {
    init(sec) {
      const rows = sec.querySelector('.rows');
      T.statement.rows.forEach((r, i) => {
        const k = r[3] ? r[3].replace(/2$/, '') : '';
        html(rows, `<div class="row k-rise${k ? ' pl' : ''}${k === 'mis' ? ' ghost' : ''}" data-k="${k}" style="top:${i * 25}px"><span class="r">${r[0]}</span><span class="ds">${r[1]}</span><span class="a">${r[2]}</span></div>`);
      });
      const tags = sec.querySelector('.tags');
      ORDER.forEach((k, i) => {
        const y0 = 208 + rowOf(k) * 25, y1 = 214 + i * 56;
        html(tags, `<p class="tag k-pop" data-k="${k}" style="--y0:${y0}px;--y1:${y1}px;--td:${i * 110}ms">${T.statement.planted[k].rule}</p>`);
        html(tags, `<p class="act k-rise" data-k="${k}" style="--y1:${y1}px">${T.statement.planted[k].act}</p>`);
        html(tags, `<div class="link-h k-fade" data-k="${k}" style="--y1m:${y1 + 19}px"></div>`);
      });
    },
    reset(sec) { sec.classList.add('notrans'); sec.classList.remove('sorted'); sec.querySelectorAll('.row').forEach(r => r.classList.remove('hl')); },
    beats: [
      [
        head,
        [700, l => show(q('.stmt'), l)],
        ...T.statement.rows.map((_, i) => [1000 + i * 90, l => show(qa('.row')[i], l)]),
        ...TAGS.map((k, j) => [3600 + j * 1400, l => {
          qa(`.row[data-k="${k}"]`).forEach(r => r.classList.add('hl'));
          show(q(`.tag[data-k="${k}"]`), l);
        }]),
      ],
      [
        [0, l => { mv(B().el(), 'sorted', true, l); show(q('.rule-h'), l); show(q('.judge-h'), l, 200); }],
        ...ORDER.map((k, i) => [1700 + i * 260, l => { show(q(`.link-h[data-k="${k}"]`), l); show(q(`.act[data-k="${k}"]`), l, 120); }]),
        [4200, l => show(q('.moral'), l)],
      ],
    ],
  };

  // ---------------------------------------------------------------- 6 files in, finished work out
  S.run = {
    reset(sec) { sec.querySelector('.run-stat .n').textContent = '0'; },
    beats: [
      [
        head,
        [700, l => { show(q('.files-h'), l); show(q('.file.f1'), l); }],
        [1000, l => show(q('.file.f2'), l)],
        [1500, l => show(q('.ws'), l)],
        [2300, l => { go(q('.t-f1'), l); go(q('.t-f2'), l); }],
        [3400, l => show(qa('.log li')[0], l)],
        [5400, l => show(qa('.log li')[1], l)],
        [7400, l => show(qa('.log li')[2], l)],
      ],
      [
        [0, l => show(qa('.log li')[3], l)],
        [2400, l => show(qa('.log li')[4], l)],
        [4800, l => show(qa('.log li')[5], l)],
        [5600, l => go(q('.t-up'), l)],
        [6600, l => show(q('.book'), l)],
        ...[0, 1, 2, 3].map(i => [7000 + i * 200, l => show(qa('.sheet')[i], l)]),
        [7800, l => { show(q('.run-stat'), l); B().count(q('.run-stat .n'), T.firstRun.seconds, l, 1100); }],
        [9200, l => show(q('.moral'), l)],
      ],
    ],
  };

  // ---------------------------------------------------------------- 7 the skill
  const MARKS = [
    { k: 'mm', ref: 'INV-41007', cat: 'Amount mismatch', ok: true },
    { k: 'tol', ref: 'INV-41009', cat: 'Within tolerance', ok: false, said: 'said "Amount mismatch"' },
    { k: 'mis', ref: 'INV-41006', cat: 'Missing on statement', ok: true },
    { k: 'mil', ref: 'INV-41013', cat: 'Missing in ledger', ok: true },
    { k: 'dup', ref: 'INV-41002', cat: 'Possible duplicate', ok: true },
    { k: 'cn', ref: 'CN-478', cat: 'Credit to confirm', ok: false, said: 'said "Unmatched on statement"' },
  ];
  const MX = MARKS.map((_, i) => 290 + 918 * (i + 0.5) / 6);            // column centres
  const scanAt = x => 1400 + Math.round(2800 * (x - 72) / 1136);          // when the scan passes x
  S.skill = {
    init(sec) {
      const m = sec.querySelector('.marks');
      MARKS.forEach((d, i) => html(m, `<div class="mk" style="left:${MX[i] - 75}px"><p class="ref k-rise">${d.ref}</p><div class="dot k-pop"></div><p class="cat k-rise"></p></div>`));
    },
    reset(sec) {
      sec.classList.add('notrans');
      sec.querySelectorAll('.mk').forEach((e, i) => {
        e.classList.remove('up');
        const c = e.querySelector('.cat'), d = MARKS[i];
        c.textContent = d.ok ? d.cat : d.said; c.className = `cat k-rise${d.ok ? '' : ' wrong'}${c.classList.contains('on') ? ' on' : ''}`;
      });
      const n = sec.querySelector('.sc-n'); n.textContent = String(T.skill.before); n.classList.remove('done');
      sec.querySelector('.sc-cap').textContent = `Without the skill · ${T.statement.partner}`;
    },
    beats: [
      [
        head,
        [700, l => show(q('.horizon'), l)],
        [1100, l => qa('.zone').forEach((x, i) => show(x, l, i * 200))],
        ...MARKS.flatMap((d, i) => {
          const t = 1700 + i * 900, mk = () => qa('.mk')[i];
          const steps = [[t, l => { show(mk().querySelector('.ref'), l); show(mk().querySelector('.dot'), l); }]];
          if (d.ok) steps.push([t + 300, l => mv(mk(), 'up', true, l)]);
          steps.push([t + 500, l => show(mk().querySelector('.cat'), l)]);
          return steps;
        }),
        [7800, l => { show(q('.score'), l); show(q('.sc-cap'), l, 200); }],
      ],
      [
        [0, l => show(q('.skillcard'), l)],
        [1400, l => go(q('.scan'), l)],
        ...MARKS.map((d, i) => (d.ok ? null : [scanAt(MX[i]), l => {
          const mk = qa('.mk')[i], c = mk.querySelector('.cat');
          mv(mk, 'up', true, l);
          c.textContent = d.cat; c.classList.remove('wrong'); c.classList.add('fixed'); flip(c, l);
        }])).filter(Boolean),
        [4700, l => { const n = q('.sc-n'); n.textContent = String(T.skill.after); n.classList.add('done'); flip(n, l); }],
        [5300, l => { q('.sc-cap').textContent = `With the skill · ${T.statement.partner}`; flip(q('.sc-cap'), l); }],
        [5900, l => show(q('.sc-more'), l)],
        [7400, l => show(q('.moral'), l)],
      ],
    ],
  };

  // ---------------------------------------------------------------- 8 five helpers
  const HY = [0, 1, 2, 3, 4].map(i => 175 + i * 86);        // helper tops
  const NG = 1;                                               // Northgate Freight
  const bpath = y => `M236 372 C350 372 360 ${y + 25} 470 ${y + 25}`;
  S.fan = {
    init(sec) {
      const briefs = sec.querySelector('.briefs'), merges = sec.querySelector('.merges');
      const helpers = sec.querySelector('.helpers'), travels = sec.querySelector('.travels');
      T.fan.partners.forEach((p, i) => {
        const y = HY[i], c = y + 25;
        briefs.insertAdjacentHTML('beforeend', `<path class="bline k-draw" pathLength="1" d="${bpath(y)}"/>`);
        merges.insertAdjacentHTML('beforeend', `<path class="mline k-draw${i === NG ? ' bad' : ''}" pathLength="1" d="M940 ${c} C972 ${c} 970 372 1000 372"/>`);
        html(helpers, `<p class="helper k-pop" style="top:${y}px">${p}</p>`);
        html(helpers, `<div class="res k-pop${i === NG ? ' bad' : ''}" style="top:${y}px"><b></b><span></span></div>`);
        html(travels, `<div class="travel" style="offset-path:path('${bpath(y)}');--dur:1000ms"></div>`);
      });
      html(travels, `<div class="travel redo-t" style="offset-path:path('${bpath(HY[NG])}');--dur:1100ms"></div>`);
    },
    reset(sec) {
      sec.querySelectorAll('.res').forEach((r, i) => {
        const bad = i === NG;
        r.classList.toggle('bad', bad);
        r.querySelector('b').textContent = bad ? `${T.fan.northgate} of 6` : '6 of 6';
        r.querySelector('span').textContent = bad ? 'IN- references not matched' : 'matches the answer key';
      });
      sec.querySelectorAll('.mline')[NG].classList.add('bad');
      const n = sec.querySelector('.ft-n'); n.textContent = String(T.fan.score); n.classList.remove('done');
    },
    beats: [
      [
        head,
        [600, l => { show(q('.lead-core'), l); show(q('.lead-in'), l, 400); pulse(q('.ring'), l, 500); }],
        [1000, l => show(q('.lead-l'), l)],
        [1600, l => show(q('.brief'), l)],
        [3400, l => { qa('.bline').forEach((x, i) => show(x, l, i * 60)); qa('.travels .travel:not(.redo-t)').forEach((x, i) => { x.style.setProperty('--d', `${i * 60}ms`); go(x, l); }); }],
        [3800, l => qa('.helper').forEach((x, i) => show(x, l, i * 80))],
        ...[0, 2, 3, 4, NG].map((i, j) => [5400 + j * 1300, l => { show(qa('.res')[i], l); show(qa('.mline')[i], l); }]),
        [11800, l => show(q('.ws-book'), l)],
        [12400, l => show(q('.fan-total'), l)],
      ],
      [
        [0, l => go(q('.redo-t'), l)],
        [1600, l => {
          const r = qa('.res')[NG]; r.classList.remove('bad');
          r.querySelector('b').textContent = '6 of 6'; r.querySelector('span').textContent = 'redone with the skill\'s rules';
          flip(r, l);
        }],
        [2300, l => qa('.mline')[NG].classList.remove('bad')],
        [2900, l => { const n = q('.ft-n'); n.textContent = String(T.fan.redoScore); n.classList.add('done'); flip(n, l); }],
        [3400, l => show(q('.redo'), l)],
        [4800, l => show(q('.moral'), l)],
      ],
    ],
  };

  // ---------------------------------------------------------------- 10 the ERP and its key
  const CALLX = [0, 1, 2, 3, 4, 5].map(i => 72 + (1136 - 60) / 6 * i + (1136 - 60) / 12);   // call centres
  S.erp = {
    reset(sec) { sec.querySelector('.nn').textContent = '0'; sec.querySelectorAll('.call').forEach(c => c.classList.remove('seen')); },
    beats: [
      [
        head,
        [700, l => { show(q('.agent-core'), l); show(q('.agent-l'), l, 300); }],
        [1300, l => { show(q('.w1'), l); show(q('.tbx'), l, 300); }],
        [2100, l => { show(q('.w2'), l); show(q('.erpbox'), l, 500); }],
        [3000, l => show(q('.nokey'), l)],
        [4000, l => show(q('.conn'), l)],
        [4800, l => { show(q('.w3'), l); show(q('.key-l'), l, 700); }],
        [6400, l => show(q('.trace-h'), l)],
        ...[0, 1, 2, 3, 4, 5].flatMap(i => [
          [6800 + i * 1500, l => go(q('.t-call'), l)],
          [8000 + i * 1500, l => {
            show(qa('.call')[i], l);
            if (i >= 3) { show(q('.notes-n'), l); q('.nn').textContent = String(i - 2); }
          }],
        ]),
      ],
      [
        [0, l => show(q('.find'), l)],
        [900, l => go(q('.scanx'), l)],
        ...CALLX.map((x, i) => [900 + Math.round(2200 * (x - 72) / 1136), l => qa('.call')[i].classList.add('seen')]),
        [3400, l => show(q('.zero'), l)],
        [4800, l => show(q('.moral'), l)],
      ],
    ],
  };

  // ---------------------------------------------------------------- 11 prepare, approve, submit
  S.portal = {
    init(sec) { B().prepStream(sec.querySelector('.stream')); },
    reset(sec) {
      sec.querySelectorAll('.hub-t .td').forEach(c => c.classList.remove('flag', 'okrow'));
      const r6 = sec.querySelector('.r6'); r6.classList.remove('bad'); r6.querySelector('.tick').textContent = '✓';
    },
    beats: [
      [
        head,
        [800, l => { show(q('.bub.ag'), l); B().stream(q('.stream'), l); }],
        [5000, l => show(q('.bub.me'), l)],
        [7400, l => show(q('.bub.rep'), l)],
        [8400, l => show(q('.chat-stat'), l)],
      ],
      [
        [0, l => show(q('.hub'), l)],
        [1400, l => go(q('.hub-scan'), l)],
        [2000, l => qa('.hub-t .td').slice(8, 12).forEach(c => c.classList.add('okrow'))],
        [2800, l => qa('.hub-t .td').slice(4, 8).forEach(c => c.classList.add('okrow'))],
        [3600, l => {
          const cells = qa('.hub-t .td'); cells.slice(0, 4).forEach(c => c.classList.add('okrow'));
          cells[1].classList.remove('okrow'); cells[1].classList.add('flag');
          const r6 = q('.r6'); r6.classList.add('bad'); r6.querySelector('.tick').textContent = '✗'; flip(r6.querySelector('.tick'), l);
        }],
        [4300, l => show(q('.stamp'), l)],
        [4800, l => show(q('.audit-l'), l)],
      ],
      [
        [0, l => show(q('.fix'), l)],
        [2000, l => show(q('.moral'), l)],
      ],
    ],
  };

  // ---------------------------------------------------------------- 12 audit, then enforce
  const HOSTS = [
    { h: 'www.bing.com', s: 'a web search', x: 72, w: 170, audit: 'would', enforce: 'deny' },
    { h: '*.azurewebsites.net', s: 'the back office', x: 257, w: 230, audit: 'allow', enforce: 'allow' },
    { h: '*.monitor.azure.com', s: 'the harness\'s own traces', x: 502, w: 220, audit: 'would', enforce: 'allow' },
    { h: '*.applicationinsights.azure.com', s: 'the harness\'s own traces', x: 737, w: 270, audit: 'would', enforce: 'allow' },
    { h: 'Foundry', s: 'built-in rule', x: 1022, w: 186, audit: 'allow', enforce: 'allow' },
  ];
  const DEC = { allow: 'Allow', would: 'AuditWouldDeny', deny: 'Deny' };
  const W0 = [640, 386], H_BOT = 272, LINE_Y = 330;
  const atLine = cx => W0[0] + (cx - W0[0]) * (W0[1] - LINE_Y) / (W0[1] - H_BOT);
  const setDec = (sec, i, mode) => { const d = sec.querySelectorAll('.host .dec')[i]; d.textContent = DEC[mode]; d.className = `dec k-fade ${mode}`; };
  S.trust = {
    init(sec) {
      const hosts = sec.querySelector('.hosts'), reqs = sec.querySelector('.reqs');
      HOSTS.forEach((h, i) => {
        const cx = h.x + h.w / 2;
        html(hosts, `<div class="host k-pop" style="left:${h.x}px;width:${h.w}px"><p class="h">${h.h}</p><p class="s">${h.s}</p><p class="dec"></p></div>`);
        reqs.insertAdjacentHTML('beforeend', `<path class="req k-draw" pathLength="1" d="M${W0[0]} ${W0[1]} L${cx} ${H_BOT}"/>`);
        html(sec, `<div class="travel t-req" style="offset-path:path('M${W0[0]} ${W0[1]} L${cx} ${H_BOT}');--dur:1200ms"></div>`);
      });
      const bx = atLine(HOSTS[0].x + HOSTS[0].w / 2);
      reqs.insertAdjacentHTML('beforeend', `<path class="req denied cutpath k-draw" pathLength="1" d="M${W0[0]} ${W0[1]} L${bx} ${LINE_Y}"/>`);
      const b = sec.querySelector('.bounce'); b.style.left = `${Math.round(bx - 24)}px`; b.style.top = `${LINE_Y - 14}px`;
      sec.querySelectorAll('.host .dec').forEach(d => d.classList.add('k-fade'));
    },
    reset(sec) {
      HOSTS.forEach((h, i) => setDec(sec, i, h.audit));
      sec.querySelectorAll('.host .dec').forEach(d => d.classList.add('k-fade'));
      sec.querySelector('.fence').classList.remove('enforce');
      sec.querySelector('.mode-v').textContent = 'Audit'; sec.querySelector('.c-audit').classList.remove('off');
      sec.querySelectorAll('.req')[0].style.display = '';
    },
    beats: [
      [
        head,
        [600, l => { show(q('.fence'), l); show(q('.fence-l'), l, 400); show(q('.mode'), l, 600); }],
        [1400, l => show(q('.wsx'), l)],
        ...HOSTS.map((_, i) => [1900 + i * 150, l => show(qa('.host')[i], l)]),
        [2900, l => { qa('.req:not(.cutpath)').forEach((x, i) => show(x, l, i * 200)); qa('.t-req').forEach((x, i) => { x.style.setProperty('--d', `${i * 200}ms`); go(x, l); }); }],
        ...HOSTS.map((_, i) => [4600 + i * 700, l => show(qa('.host .dec')[i], l)]),
        [8400, l => show(q('.c-audit'), l)],
      ],
      [
        [0, l => { q('.mode-v').textContent = 'Enforce'; flip(q('.mode-v'), l); q('.fence').classList.add('enforce'); }],
        [1000, l => [2, 3].forEach(i => { setDec(B().el(), i, 'allow'); show(qa('.host .dec')[i], l); flip(qa('.host .dec')[i], l); })],
        [2200, l => { qa('.req')[0].style.display = 'none'; show(q('.cutpath'), l); }],
        [3200, l => { setDec(B().el(), 0, 'deny'); show(qa('.host .dec')[0], l); flip(qa('.host .dec')[0], l); show(q('.bounce'), l); }],
        [4000, l => pulse(qa('.host .dec')[1], l)],
        [4600, l => { q('.c-audit').classList.add('off'); show(q('.c-enf'), l); }],
      ],
      [
        [0, l => show(q('.inject'), l)],
        [2600, l => go(q('.t-lift'), l)],
        [3300, l => show(q('.needs'), l)],
        [5000, l => show(q('.moral'), l)],
      ],
    ],
  };

  // ---------------------------------------------------------------- 13 prove it
  const BAR_MAX = 280, hOf = s => Math.round(BAR_MAX * s / T.models.big.s);
  S.prove = {
    init(sec) {
      sec.querySelector('.c-mini').style.setProperty('--h', `${hOf(T.models.mini.s)}px`);
      sec.querySelector('.c-big').style.setProperty('--h', `${hOf(T.models.big.s)}px`);
      sec.querySelectorAll('.c-t, .c-m, .c-k').forEach(x => x.classList.add('k-fade'));
    },
    reset(sec) { sec.querySelectorAll('.c-t .n').forEach(n => { n.textContent = '0'; }); },
    beats: [
      [
        head,
        [600, l => { show(q('.horizon'), l); show(q('.axis-l'), l, 300); }],
        ...[['.c-mini', T.models.mini.s, 1200], ['.c-big', T.models.big.s, 2600]].map(([c, s, t]) => [t, l => {
          const col = q(c);
          show(col.querySelector('.bar'), l); show(col.querySelector('.c-m'), l); show(col.querySelector('.c-k'), l, 200);
          show(col.querySelector('.c-t'), l, 300); B().count(col.querySelector('.c-t .n'), s, l, 1200);
        }]),
        [4400, l => qa('.c-sc').forEach((x, i) => show(x, l, i * 200))],
        [6400, l => show(q('.strata-h'), l)],
        ...['.s1', '.s2', '.s3'].map((s, i) => [6800 + i * 900, l => { show(q(`.strata ${s}`), l); show(qa('.legend li')[i], l, 200); }]),
      ],
      [
        [0, l => show(q('.frame'), l)],
        [900, l => show(q('.verdict'), l)],
        [2800, l => show(q('.moral'), l)],
      ],
    ],
  };

  // ---------------------------------------------------------------- 14 the month crosses the line
  const STEPS = [
    { x: 200, t: 'Download statements and the ledger export', b: 'getLedger, from the ERP', s: 'no export to download' },
    { x: 455, t: 'Compare them line by line', b: `${T.month5.score} of ${T.month5.of} · ${T.month5.time}`, s: 'five subagents, with the skill', gate: 2 },
    { x: 710, t: 'Chase every difference', b: 'A note on each exception', s: 'in the ERP, no key in the trace' },
    { x: 965, t: `Type each query into ${T.company.portal}`, b: `${T.portal.fixedQ} queries · ${T.portal.fixedS} s`, s: 'every field checked first', gate: 4 },
  ];
  const GONE = [[0, 1, 2], [3, 4, 5], [6, 7, 8], [9, 10]];
  S.cross = {
    init(sec) {
      const st = sec.querySelector('.steps4');
      STEPS.forEach(d => html(st, `<div class="st" style="--x:${d.x}px"><div class="card k-rise"><i>By hand</i>${d.t}</div><div class="ev k-rise"><b>${d.b}</b><span>${d.s}</span></div></div>`));
      const pb = sec.querySelector('.pd-blocks');
      for (let i = 0; i < 12; i++) html(pb, `<div class="pd k-pop" style="left:${i * 40}px"></div>`);
      // Gates and their labels sit on each gated column's centre.
      STEPS.forEach(d => {
        if (!d.gate) return;
        const cx = d.x + 118;
        sec.querySelector(`.g${d.gate}`).setAttribute('d', `M${cx} 381 L${cx + 11} 392 L${cx} 403 L${cx - 11} 392Z`);
        sec.querySelector(`.r${d.gate}`).setAttribute('cx', cx);
        const lab = sec.querySelector(`.gl${d.gate}`); lab.style.left = `${d.x}px`; lab.style.width = '236px'; lab.style.textAlign = 'center';
      });
    },
    reset(sec) {
      sec.classList.add('notrans'); sec.classList.remove('risen');
      sec.querySelectorAll('.st').forEach(s => { s.classList.remove('up', 'atgate'); s.querySelector('i').textContent = 'By hand'; });
      sec.querySelectorAll('.pd').forEach(p => p.classList.remove('gone', 'kept'));
      sec.querySelector('.pd-l').textContent = `${T.month.personDays} person-days a month`;
    },
    beats: [
      [
        head,
        [700, l => show(q('.horizon'), l)],
        [1100, l => qa('.zl').forEach((x, i) => show(x, l, i * 200))],
        ...STEPS.map((_, i) => [1700 + i * 700, l => show(qa('.st .card')[i], l)]),
        [4800, l => { show(q('.pdays'), l); qa('.pd').forEach((p, i) => show(p, l, i * 70)); }],
        [6400, l => qa('.gate').forEach((g, i) => show(g, l, i * 300))],
      ],
      [
        ...(() => {
          const steps = []; let t = 0;
          STEPS.forEach((d, i) => {
            const st = () => qa('.st')[i];
            if (d.gate) {
              steps.push([t, l => mv(st(), 'atgate', true, l)]);
              steps.push([t + 1500, l => { pulse(q(`.r${d.gate}`), l); show(q(`.gl${d.gate}`), l); }]);
              t += 3400;
            }
            steps.push([t, l => { mv(st(), 'up', true, l); st().querySelector('i').textContent = 'Agent-run'; }]);
            steps.push([t + 1500, l => show(st().querySelector('.ev'), l)]);
            steps.push([t + 1600, l => GONE[i].forEach(k => { const p = qa('.pd')[k]; p.classList.remove('enter'); mv(p, 'gone', true, l); })]);
            t += 2900;
          });
          steps.push([t, l => { qa('.pd')[11].classList.add('kept'); q('.pd-l').textContent = 'what people keep: the review and the approval'; }]);
          return steps;
        })(),
      ],
      [
        [0, l => mv(B().el(), 'risen', true, l)],
        [700, l => pulse(q('.bz'), l)],
        [1800, l => show(q('.outcome'), l)],
        [3000, l => show(q('.oc-side'), l)],
        [4800, l => show(q('.moral'), l)],
      ],
    ],
  };

  // ---------------------------------------------------------------- 15 sign-off
  S.end = {
    beats: [[
      [0, l => { show(q('.horizon'), l); show(q('svg ellipse.k-fade'), l); }],
      [500, l => show(q('.gate'), l)],
      [900, l => show(q('.end-sun'), l)],
      ...[0, 1, 2, 3].map(i => [1800 + i * 3000, l => show(qa('.rl')[i], l)]),
      [12600, l => show(q('.end-next'), l)],
      [14400, l => show(q('.end-foot'), l)],
    ]],
  };

  window.SCENES = S;
})();
