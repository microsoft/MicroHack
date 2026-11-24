/* Say it once: the scenes of the Contact Center Agents tech talk.

   The signature object is a voice: a real waveform from the telco pack's recorded calls (js/waves.js).
   It crosses the cover, runs along every chapter line, turns into words on slide 4, and on slide 12 plays a
   whole call in real time, folds into a whisper card and is picked up by a person in a warmer colour.

   Steps follow the beat engine's contract (js/beat-engine.js): they set absolute state, never start timers,
   and animate only when live. */
(() => {
  const T = window.TALK, W = window.WAVES;
  const K = ':is([class^="k-"], [class*=" k-"])';
  const { $, $$, el, show, hide, pulse, go, stream, prepStream, count } = new Proxy({}, { get: (_, k) => (...a) => window.Beat[k](...a) });
  const NS = 'http://www.w3.org/2000/svg';
  const q = s => $(el(), s), qq = s => $$(el(), s);
  const heads = l => qq('.kicker, .title, .subtitle').forEach(x => show(x, l));

  // ------------------------------------------------------------------ the waveform
  // Bars for samples [i0, i1) of a recording, laid out from x over width w, centred on y, half height h.
  // colour(i) returns a class per bar (who is speaking). Each bar carries --i for the staggered grow.
  const env = (call, t0, t1, every = 1) => {
    const w = W[call], a = Math.round(t0 / w.step), b = Math.round(t1 / w.step), out = [];
    for (let i = a; i < b; i += every) out.push({ v: Math.max(...w.env.slice(i, i + every)), t: i * w.step });
    return out;
  };
  const whoAt = (call, t) => { const tn = W[call].turns.find(u => t >= u.t0 - 0.3 && t <= u.t1 + 0.3); return tn ? tn.who : 'gap'; };
  const bars = (g, samples, x, y, w, h, cls = () => 'voice', fill = 0.62, min = 1.5) => {
    const step = w / samples.length, bw = Math.max(1, step * fill);
    g.innerHTML = samples.map((s, i) => {
      const bh = Math.max(min, s.v * h);
      return `<rect class="bar ${cls(s, i)}" style="--i:${i}" x="${(x + i * step + (step - bw) / 2).toFixed(1)}" y="${(y - bh).toFixed(1)}" width="${bw.toFixed(1)}" height="${(2 * bh).toFixed(1)}" rx="${(bw / 2).toFixed(1)}"/>`;
    }).join('');
    g.style.setProperty('--n', samples.length);
    return step;
  };
  // A deterministic, illustrative voice shape for things that were never recorded.
  const shape = (n, seed) => {
    let s = seed; const r = () => (s = (s * 9301 + 49297) % 233280) / 233280;
    return Array.from({ length: n }, (_, i) => ({ v: Math.max(0.05, Math.sin(Math.PI * (i + 0.5) / n) ** 0.6 * (0.35 + 0.65 * r())) }));
  };
  const words = (box, text, kind = 'k-say') => { box.innerHTML = text.split(' ').map(w => `<span class="w ${kind}">${w}</span>`).join(' '); return $$(box, '.w'); };

  const S = window.SCENES = {};

  // ------------------------------------------------------------------ 1 cover
  S.cover = {
    init(sec) {
      const t = W['KC-CALL-03'].turns[1];
      const step = bars($(sec, '.cv-wave'), env('KC-CALL-03', t.t0, t.t1), 680, 300, 528, 118);
      const tags = [
        { at: 8.0, y: 446, x: 800, k: 'intent', v: 'internet outage' },
        { at: 12.6, y: 492, x: 880, k: 'needs', v: 'alarm relies on the internet' },
        { at: 14.1, y: 538, x: 960, k: 'action', v: 'a person, straight away' },
      ];
      $(sec, '.cv-ticks').innerHTML = tags.map((g, i) => {
        const x = (680 + (g.at - t.t0) / 0.1 * step).toFixed(1);
        return `<path class="tick k-draw t${i}" pathLength="1" d="M${x} 428 V${g.y}"/><circle class="tick-dot k-pop d${i}" cx="${x}" cy="428" r="3.5"/>`;
      }).join('');
      $(sec, '.cv-tags').innerHTML = tags.map((g, i) => `<p class="tag k-pop g${i}" style="left:${g.x}px;top:${g.y}px"><b>${g.k}</b> ${g.v}</p>`).join('');
    },
    beats: [[
      [0, l => qq('.cv-copy ' + K).forEach(x => show(x, l))],
      [700, l => show(q('.cv-wave'), l)],
      ...[0, 1, 2].flatMap(i => [
        [2400 + i * 700, l => { show(q(`.t${i}`), l); show(q(`.d${i}`), l); }],
        [2900 + i * 700, l => show(q(`.g${i}`), l)],
      ]),
      [4400, l => show(q('.cv-foot'), l)],
    ]],
  };

  // ------------------------------------------------------------------ chapters: the call line with four parts
  const PARTS = ['Listen', 'Act, safely', 'Prove it', 'Hand over'];
  S.chapter = {
    init(sec) {
      const part = +sec.dataset.part, svg = $(sec, '.callline');
      const s = env('KC-CALL-01', 0.2, 64.0, 3), x0 = 72, w = 1136, seg = w / 4;
      const g = document.createElementNS(NS, 'g'); g.setAttribute('class', 'wave cl-wave'); svg.appendChild(g);
      bars(g, s, x0, 560, w, 30, (_, i) => {
        const p = Math.floor(i / s.length * 4) + 1;
        return p < part ? 'past' : p === part ? 'now' : 'later';
      });
      // index of each "now" bar inside its part, for the light that runs along it
      const now = $$(g, '.now'); now.forEach((b, j) => b.style.setProperty('--j', `${Math.round(500 + j / now.length * 2200)}ms`));
      svg.insertAdjacentHTML('beforeend', PARTS.map((name, i) =>
        `<text class="cl-label ${i + 1 === part ? 'cur' : ''}" x="${x0 + i * seg + 4}" y="624">${i + 1} · ${name}</text>`).join('') +
        `<g class="cl-head k-fade" style="--x0:${x0 + (part - 1) * seg}px;--x1:${x0 + part * seg - 6}px"><rect x="-1" y="516" width="2" height="88" rx="1"/><circle cx="0" cy="516" r="5"/></g>`);
    },
    beats: [[
      [0, l => qq('.ch-label, h1, .ch-sub').forEach(x => show(x, l))],
      [600, l => { show(q('.cl-wave'), l); show(q('.cl-head'), l); }],
    ]],
  };

  // ------------------------------------------------------------------ 3 the third call
  S.repeat = {
    init(sec) {
      const t = W['KC-CALL-02'].turns[1], s = env('KC-CALL-02', t.t0, t.t1);
      const rows = $(sec, '.rows');
      rows.innerHTML = [0, 1, 2].map(i => `<g class="wave r${i} ${i < 2 ? 'ghost' : ''} k-fade"></g>`).join('');
      [0, 1, 2].forEach(i => bars($(rows, `.r${i}`), s, 220, 236 + i * 92, 480, 38));
      $(sec, '.row-labels').innerHTML = ['Call 1', 'Call 2', 'Call 3'].map((x, i) =>
        `<p class="rl k-fade rl${i}" style="top:${222 + i * 92}px">${x}<small>${i < 2 ? 'illustrative' : 'recorded'}</small></p>`).join('');
      words($(sec, '.said'), T.repeat.line).forEach(w => { if (/^(third|time)$/.test(w.textContent)) w.classList.add('hot'); });
      $(sec, '.problems').innerHTML = T.repeat.problems.map((p, i) => `<li class="k-rise p${i} ${i === 2 ? 'hot' : ''}"><span class="n">${i + 1}</span>${p}</li>`).join('');
    },
    beats: [
      [
        [0, l => heads(l)],
        [1200, l => { show(q('.r0'), l); show(q('.rl0'), l); }],
        [2400, l => { show(q('.r1'), l); show(q('.rl1'), l); }],
        [3600, l => { show(q('.r2'), l); show(q('.rl2'), l); show(q('.said'), l, 600); }],
        ...Array.from({ length: T.repeat.line.split(' ').length }, (_, i) => [4400 + i * 120, l => show(qq('.said .w')[i], l)]),
        [8000, l => show(q('.foot'), l)],
      ],
      [
        ...[0, 1, 2, 3].map(i => [i * 900, l => show(q(`.p${i}`), l)]),
        [3200, () => el().classList.add('b1')],
        [4000, l => show(q('.moral'), l)],
      ],
    ],
    reset(sec) { sec.classList.remove('b1'); },
  };

  // ------------------------------------------------------------------ 4 from sound to an answer
  S.voice = {
    init(sec) {
      const v = T.voice, w = W['KC-CALL-01'], ask = w.turns[1], ans = w.turns[4];
      bars($(sec, '.w-ask'), env('KC-CALL-01', ask.t0, ask.t1), 72, 248, 360, 52);
      bars($(sec, '.w-ans'), env('KC-CALL-01', ans.t0 + 1.6, ans.t1), 848, 248, 360, 52, () => 'ai');
      bars($(sec, '.core-bars'), shape(9, 7), 616, 248, 48, 16, () => 'ai', 0.5, 2);
      $(sec, '.w-ans-l').textContent = 'Spoken answer';
      $(sec, '.core-l .mono').textContent = `${v.model} · voice ${v.voiceName}`;
      words($(sec, '.ask-words'), v.ask);
      $(sec, '.ans-words').dataset.text = v.answer; prepStream($(sec, '.ans-words'));
      $(sec, '.kb-label').textContent = `[${v.label}]`;
      $(sec, '.kb-text').innerHTML = v.passage.replace('part-month charge', '<mark>part-month charge</mark>');
      $(sec, '.h-speak .t').textContent = v.speak;
      $(sec, '.h-write .t').textContent = v.write;
      sec.insertAdjacentHTML('beforeend', `<div class="travel t-in" style="offset-path:path('M436 248 H594')"></div><div class="travel t-out ai" style="offset-path:path('M686 248 H846')"></div>`);
    },
    beats: [
      [
        [0, l => heads(l)],
        [1000, l => { show(q('.w-ask-l'), l); show(q('.w-ask'), l); }],
        ...Array.from({ length: T.voice.ask.split(' ').length }, (_, i) => [1800 + i * 300, l => show(qq('.ask-words .w')[i], l)]),
        [6800, l => go(q('.t-in'), l)],
        [7800, l => { show(q('.core'), l); pulse(q('.core-pulse'), l); show(q('.core-l'), l, 300); }],
        [9600, l => show(q('.b-down'), l)],
        [10600, l => show(q('.kb'), l)],
        [12000, () => el().classList.add('found')],
        [13400, l => show(q('.b-up'), l)],
        [14800, l => go(q('.t-out'), l)],
        [15600, l => { show(q('.w-ans-l'), l); show(q('.w-ans'), l); }],
        [16200, l => stream(q('.ans-words'), l, 90)],
        [19600, l => show(q('.foot'), l)],
      ],
      [
        [0, l => show(q('.h-speak'), l)],
        [900, l => show(q('.h-write'), l)],
        [2400, l => show(q('.moral'), l)],
      ],
    ],
    reset(sec) { sec.classList.remove('found'); $$(sec, '.travel').forEach(t => t.classList.remove('go')); },
  };

  // ------------------------------------------------------------------ 6 code decides, the agent talks
  const CX = [200, 420, 640, 860, 1080];
  S.crm = {
    init(sec) {
      const c = T.crm, all = [...c.calls, c.wrong];
      // the conversation: alternating caller and agent shapes along the top lane (illustrative)
      const talk = $(sec, '.talk'); let x = 72, k = 0, html = '';
      const raw = [70, 96, 60, 120, 54, 104, 66, 112, 58, 130, 64, 92, 72], fit = (1136 - 18 * (raw.length - 1)) / raw.reduce((a, b) => a + b, 0), widths = raw.map(v => v * fit);
      widths.forEach((wd, i) => { html += `<g class="wave seg k-fade s${i}" data-x="${x}"></g>`; x += wd + 18; });
      talk.innerHTML = html; x = 72;
      $$(talk, '.seg').forEach((g, i) => { bars(g, shape(Math.round(widths[i] / 7), 11 + i * 7), x, 232, widths[i], 22, () => (i % 2 ? 'ai' : 'voice')); g.style.setProperty('--d', '0ms'); x += widths[i] + 18; k++; });
      $(sec, '.drops').innerHTML = all.map((_, i) =>
        `<path class="drop k-draw dn${i}" pathLength="1" d="M${CX[i]} 262 V330"/><path class="drop k-draw dc${i}" pathLength="1" d="M${CX[i]} 452 V520"/><circle class="ring rr${i}" cx="${CX[i]}" cy="548" r="10"/>`).join('');
      $(sec, '.calls').innerHTML = all.map((a, i) =>
        `<div class="cap k-rise c${i} ${i === 4 ? 'wrong' : ''}" style="left:${CX[i] - 98}px"><div class="in"><p class="op">${a.op}</p><p class="arg">${a.arg}</p><p class="out k-pop">${a.out}</p></div></div>`).join('');
      $(sec, '.kbchip').innerHTML = `<span>${c.knowledge.replace(': ', '<br>')}</span>`;
    },
    beats: [
      [
        [0, l => heads(l)],
        [1000, l => { show(q('.lane-l'), l); qq('.seg').forEach((g, i) => show(g, l, i * 90)); }],
        [2200, l => { show(q('.crm-bar'), l); show(q('.crm-l'), l, 400); }],
        ...[0, 1, 2, 3].flatMap(i => {
          const t0 = 4200 + i * 2600 + (i > 0 ? 900 : 0);
          return [
            [t0, l => { show(q(`.dn${i}`), l); show(q(`.c${i}`), l, 400); }],
            [t0 + 700, l => { show(q(`.dc${i}`), l); }],
            [t0 + 1500, l => { pulse(q(`.rr${i}`), l); show(q(`.c${i} .out`), l); }],
          ];
        }),
        [6400, l => show(q('.kbchip'), l)],
        [15200, l => show(q('.foot'), l)],
      ],
      [
        [0, () => el().classList.add('b1')],
        [600, l => { show(q('.dn4'), l); show(q('.c4'), l, 400); }],
        [1300, l => show(q('.dc4'), l)],
        [2100, l => { pulse(q('.rr4'), l); show(q('.c4 .out'), l); }],
        [3400, l => show(q('.moral'), l)],
      ],
    ],
    reset(sec) { sec.classList.remove('b1'); },
  };

  // ------------------------------------------------------------------ 7 five tests, three layers
  const GX = [470, 690, 910], ROW = i => 222 + i * 56;
  S.safety = {
    init(sec) {
      const s = T.safety;
      $(sec, '.gates').innerHTML = GX.map((x, i) => `<rect class="gate k-fade g${i}" x="${x - 3}" y="188" width="6" height="290" rx="3"/>`).join('');
      $(sec, '.gate-l').innerHTML = [['Guardrail', 'shields, filters, blocklist'], ['Instructions', 'what the agent is told'], ['System design', 'the CRM']]
        .map(([h, sub], i) => `<p class="gl k-fade gl${i}" style="left:${GX[i] - 90}px"><b>${h}</b>${sub}</p>`).join('');
      $(sec, '.paths').innerHTML = s.tests.map((t, i) => {
        const stop = GX[t.layer] - 12, y = ROW(i);
        return `<path class="lane k-draw ln${i}" pathLength="1" d="M384 ${y} H${stop}"/>` +
          (t.backup ? `<path class="lane backup k-fade bk${i}" d="M${stop + 24} ${y} H${GX[t.backup] - 12}"/>` : '') +
          `<g class="stop k-pop st${i}"><circle cx="${GX[t.layer]}" cy="${y}" r="11"/><path d="M${GX[t.layer] - 4} ${y - 4} l8 8 M${GX[t.layer] + 4} ${y - 4} l-8 8"/></g>` +
          (t.backup ? `<g class="stop dim k-pop sb${i}"><circle cx="${GX[t.backup]}" cy="${y}" r="9"/></g>` : '');
      }).join('');
      $(sec, '.tests').innerHTML = s.tests.map((t, i) =>
        `<p class="test k-rise te${i}" style="top:${ROW(i) - 20}px"><span class="n">${i + 1}</span>${t.ask}</p><p class="res k-rise re${i}" style="top:${ROW(i) - 20}px">${t.result}</p>`).join('');
      sec.insertAdjacentHTML('beforeend', s.tests.map((t, i) => `<div class="travel tr${i}" style="offset-path:path('M384 ${ROW(i)} H${GX[t.layer] - 12}');--dur:${1100 + t.layer * 400}ms"></div>`).join(''));
      words($(sec, '.trap-line'), s.goodAnswer, 'tw').forEach(w => { if (w.textContent === 'guarantee') w.classList.add('hit'); });
    },
    beats: [
      [
        [0, l => heads(l)],
        ...[0, 1, 2].map(i => [1000 + i * 400, l => { show(q(`.g${i}`), l); show(q(`.gl${i}`), l); }]),
        ...[0, 1, 2, 3, 4].map(i => [3200 + i * 500, l => show(q(`.te${i}`), l)]),
        ...T.safety.tests.flatMap((t, i) => {
          const t0 = 7000 + i * 1700, dur = 1100 + t.layer * 400;
          return [
            [t0, l => { show(q(`.ln${i}`), l); go(q(`.tr${i}`), l); }],
            [t0 + dur, l => { show(q(`.st${i}`), l); show(q(`.re${i}`), l, 200); }],
            ...(t.backup ? [[t0 + dur + 400, l => { show(q(`.bk${i}`), l); show(q(`.sb${i}`), l, 600); }]] : []),
          ];
        }),
        [16400, l => show(q('.tally'), l)],
        [17200, l => show(q('.foot'), l)],
      ],
      [
        [0, l => show(q('.trap'), l)],
        [1800, () => el().classList.add('scan1')],
        [3000, l => { el().classList.add('blocked'); show(q('.trap-v'), l); }],
        [6000, () => {
          const s = el(); s.classList.remove('blocked'); s.classList.add('fixed');
          q('.term').textContent = 'we guarantee'; q('.trap-v').textContent = 'Passes: the honest answer gets through';
        }],
        [6100, l => pulse(q('.trap-v'), l)],
        [7400, l => show(q('.moral'), l)],
      ],
    ],
    reset(sec) {
      sec.classList.remove('scan1', 'blocked', 'fixed');
      $(sec, '.term').textContent = 'guarantee'; $(sec, '.trap-v').textContent = 'Blocked: the customer sees an error';
      $$(sec, '.travel').forEach(t => t.classList.remove('go'));
    },
  };

  // ------------------------------------------------------------------ 9 every call, not a sample
  const DX = d => 72 + (d - 1) * 114, RY = r => 222 + r * 62;
  S.week = {
    init(sec) {
      const c = T.week.contacts;
      $(sec, '.days').innerHTML = Array.from({ length: 10 }, (_, i) => `<p class="day k-fade dy${i}" style="left:${DX(i + 1)}px">${i + 1} Mar</p>`).join('');
      const perDay = {};
      $(sec, '.grid').innerHTML = c.map(([id, day, intent, area, ver], i) => {
        const r = perDay[day] = (perDay[day] ?? -1) + 1;
        const kind = ver === 1 ? 'miss' : intent === 'outage_fault' ? 'outage' : '';
        const glyph = shape(9, 3 + i * 13).map((s, j) => `<i style="height:${(4 + s.v * 22).toFixed(0)}px"></i>`).join('');
        return `<div class="ct k-pop ${kind}" data-i="${i}" style="left:${DX(day)}px;top:${RY(r)}px"><span class="gl">${glyph}</span><span class="lb">${ver === 1 ? id : kind === 'outage' ? area : ''}</span></div>`;
      }).join('');
      sec.insertAdjacentHTML('beforeend', `<div class="bracket k-fade"><span>the ZZ4 outage</span></div>`);
    },
    beats: [
      [
        [0, l => heads(l)],
        [900, l => qq('.day').forEach((d, i) => show(d, l, i * 60))],
        ...T.week.contacts.map((_, i) => [1500 + i * 110, l => show(qq('.ct')[i], l)]),
        [6000, l => show(q('.lens'), l)],
        [7200, l => show(q('.s1'), l)],
        [8200, l => show(q('.foot'), l)],
      ],
      [
        [0, l => { hide(q('.lens')); show(q('.s2'), l); go(q('.scan'), l); }],
        // the light crosses 1,000 px in 2,400 ms; each contact is scored as it reaches its column
        ...T.week.contacts.map(([, day], i) => [Math.round((DX(day) + 50 - 60) / 1150 * 2600), () => {
          qq('.ct')[i].classList.add('scored');
          q('.s2 .n').textContent = String(i + 1);
        }]),
        [2700, l => { el().classList.add('b1'); show(q('.bracket'), l); }],
        [3400, l => show(q('.s3'), l)],
        [4400, l => show(q('.s4'), l)],
        [5600, l => show(q('.moral'), l)],
      ],
    ],
    reset(sec) { sec.classList.remove('b1'); $$(sec, '.ct').forEach(x => x.classList.remove('scored')); $(sec, '.s2 .n').textContent = '0'; $(sec, '.scan').classList.remove('go'); },
  };

  // ------------------------------------------------------------------ 10 read the row, not the average
  S.evals = {
    init(sec) {
      const e = T.evals;
      $(sec, '.bars').innerHTML = e.rows.map((r, i) => `<div class="br k-rise br${i}" style="top:${184 + i * 52}px"><div class="in">
          <p class="nm">${r.name}<small>${r.note}</small></p>
          ${r.pct === null ? '<p class="err k-drop">Error</p>' : `<div class="trk"><div class="fill k-growx" style="width:${r.pct * 2.2}px"></div></div><p class="pc">${r.pct}%</p>`}
                  </div></div>`).join('');
      $(sec, '.a-q').textContent = `“${e.row.q}”`;
      $(sec, '.a-judge').innerHTML = e.row.judge.map((j, i) => `<p class="jr k-rise j${i}"><span class="x">${i ? 'Task completion' : 'Groundedness'}: fail</span> “${j}”</p>`).join('');
      $(sec, '.c-rows').innerHTML = `<p class="cr hd"><span></span><span class="ai">low</span><span>medium</span></p>` +
        e.compare.map((c, i) => `<p class="cr k-rise cr${i}"><span>${c.name}</span><b class="ai">${c.low}</b><b>${c.med}</b></p>`).join('');
    },
    beats: [
      [
        [0, l => heads(l)],
        [1200, l => { show(q('.hero'), l); count(q('.hero .n'), T.evals.overall, l, 1600); }],
        ...[0, 1, 2, 3].map(i => [3400 + i * 700, l => { show(q(`.br${i}`), l); const f = q(`.br${i} .fill, .br${i} .err`); show(f, l, 300); }]),
        [7000, l => show(q('.foot'), l)],
      ],
      [
        [0, () => el().classList.add('b1')],
        [500, l => show(q('.audit'), l)],
        [1800, l => show(q('.j0'), l)],
        [2800, l => show(q('.j1'), l)],
        [4200, l => show(q('.a-v'), l)],
      ],
      [
        [0, () => el().classList.add('b2')],
        [500, l => show(q('.cmp'), l)],
        ...[0, 1, 2].map(i => [1200 + i * 700, l => show(q(`.cr${i}`), l)]),
        [3600, l => show(q('.c-v'), l)],
        [4800, l => show(q('.moral'), l)],
      ],
    ],
    reset(sec) { sec.classList.remove('b1', 'b2'); $(sec, '.hero .n').textContent = '0'; },
  };

  // ------------------------------------------------------------------ 12 Margaret's call
  const CALL = 'KC-CALL-03', X0 = 72, WD = 1136;
  const audio = new Audio('media/KC-CALL-03.mp3'); audio.preload = 'auto';
  let soundOn = true, started = false;
  const stopAudio = () => { started = false; audio.pause(); try { audio.currentTime = 0; } catch (e) { /* not loaded yet */ } };
  const playAudio = () => { if (!soundOn) return; started = true; try { audio.currentTime = 0; } catch (e) { /* not loaded yet */ } audio.play().catch(() => { started = false; }); };
  S.call = {
    init(sec) {
      const w = W[CALL], s = env(CALL, 0, w.duration);
      sec.style.setProperty('--len', `${w.duration}s`);
      bars($(sec, '.w-call'), s, X0, 220, WD, 44, smp => (whoAt(CALL, smp.t) === 'customer' ? 'voice' : 'ai'), 0.66, 0.8);
      bars($(sec, '.w-human'), shape(150, 29), 660, 220, 548, 40, () => 'voice warm', 0.62, 0.8);
      $(sec, '.axis').innerHTML = [0, 10, 20, 30, 40, 50, 60].map(t =>
        `<text x="${(X0 + t / w.duration * WD).toFixed(1)}" y="292">${Math.floor(t / 60)}:${String(t % 60).padStart(2, '0')}</text>`).join('');
      $(sec, '.transcript').innerHTML = w.turns.map((u, i) =>
        `<div class="turn k-fade u${i} ${u.who}"><p class="who ${u.who === 'customer' ? 'voice' : 'ai'}">${u.who === 'customer' ? 'Margaret' : 'Agent'}</p><p class="tx"></p></div>`).join('');
      w.turns.forEach((u, i) => words($(sec, `.u${i} .tx`), u.text));
      $(sec, '.feed').insertAdjacentHTML('beforeend', T.call.feed.map((f, i) =>
        `<div class="fi k-rise f${i} ${f.tool ? 'tool' : ''} ${f.care ? 'care' : ''}"><p class="k">${f.k}<span class="src">${f.src}</span></p><p class="v">${f.v}</p></div>`).join(''));
      const c = T.call.card;
      $(sec, '.wc-h .mono').textContent = c.meta;
      $(sec, '.wc-who').textContent = c.who;
      $(sec, '.wc-flags').innerHTML = c.flags.map(f => `<span class="flag mono">${f}</span>`).join('');
      $(sec, '.wc-hap').innerHTML = c.happened.replace(/(\d{4}-\d\d-\d\d \d\d:\d\d)/, '<span class="nw">$1</span>');
      $(sec, '.wc-next').innerHTML = c.next.replace('free 4G backup hub', '<b class="ai">free 4G backup hub</b>') + ' <span class="src mono">KB-KC-005 p4</span>';
      $(sec, '.adv-q').innerHTML = `${T.call.handoff}<br>high priority · waiting`;
      $(sec, '.o-text').textContent = `“${c.opening}”`;
      sec.insertAdjacentHTML('beforeend', `<div class="travel t-hand" style="offset-path:path('M760 420 C800 420 820 372 900 372');--dur:1200ms"></div>`);
      // pause and resume the sound with the scene
      new MutationObserver(() => {
        if (!started) return;
        if (sec.classList.contains('motion-paused') || !sec.classList.contains('playing')) audio.pause();
        else if (audio.paused && !audio.ended) audio.play().catch(() => {});
      }).observe(sec, { attributes: true, attributeFilter: ['class'] });
    },
    beats: [
      [
        [0, l => heads(l)],
        [1500, l => { show(q('.axis'), l); show(q('.w-call'), l); show(q('.feed-h'), l, 400); if (l) { el().classList.add('playing'); playAudio(); } }],
        // one step per second for the clock
        ...Array.from({ length: 63 }, (_, sec) => [1500 + sec * 1000, () => { q('.clock').textContent = `0:${String(sec).padStart(2, '0')}`.replace(/^0:(6\d)$/, (m, s) => `1:${String(s - 60).padStart(2, '0')}`); }]),
        // the words appear as they are spoken
        ...W[CALL].turns.flatMap((u, i) => {
          const n = u.text.split(' ').length;
          return [[1500 + u.t0 * 1000, l => show(q(`.u${i}`), l)],
            ...Array.from({ length: n }, (_, j) => [1500 + Math.round((u.t0 + (j / n) * (u.t1 - u.t0)) * 1000), l => show(qq(`.u${i} .w`)[j], l)])];
        }),
        ...T.call.feed.map((f, i) => [1500 + f.at * 1000, l => show(q(`.f${i}`), l)]),
        [1500 + W[CALL].duration * 1000, l => { el().classList.remove('playing'); q('.clock').textContent = '1:02'; if (!l) stopAudio(); }],
        [1600 + W[CALL].duration * 1000, l => show(q('.foot'), l)],
      ],
      [
        [0, l => { stopAudio(); el().classList.remove('playing'); el().classList.add('fold'); }],
        [900, () => el().classList.add('folded')],
        [1000, l => { show(q('.call-l'), l); show(q('.wcard'), l); }],
        [2600, l => go(q('.t-hand'), l)],
        [3600, l => show(q('.adviser'), l)],
      ],
      [
        [0, l => { el().classList.add('human'); show(q('.w-human'), l); show(q('.human-l'), l, 300); q('.adv-q').innerHTML = `${T.call.handoff}<br>picked up`; }],
        [2200, l => show(q('.opening'), l)],
        [5200, l => show(q('.moral'), l)],
      ],
    ],
    reset(sec) {
      stopAudio();
      sec.classList.remove('playing', 'fold', 'folded', 'human');
      $(sec, '.clock').textContent = '0:00';
      $(sec, '.adv-q').innerHTML = `${T.call.handoff}<br>high priority · waiting`;
      $$(sec, '.travel').forEach(t => t.classList.remove('go'));
    },
  };
  window.CallSound = {
    audio,
    wire() {
      const sec = document.querySelector('section.call'), btn = sec.querySelector('.sound');
      btn.addEventListener('keydown', e => { if (e.key === ' ' || e.key === 'Enter') e.stopPropagation(); });
      btn.addEventListener('click', e => {
        e.stopPropagation(); soundOn = !soundOn;
        btn.setAttribute('aria-pressed', String(soundOn)); btn.textContent = soundOn ? 'Sound on' : 'Sound off';
        if (!soundOn) audio.pause();
        else if (sec.classList.contains('playing') && window.TalkDeck.clock.running) {
          started = true;
          try { audio.currentTime = Math.max(0, (performance.now() - window.TalkDeck.clock.t0 - 1500) / 1000); } catch (err) { /* not loaded yet */ }
          audio.play().catch(() => { started = false; });
        }
        btn.blur();
      });
      Reveal.on('slidechanged', ({ currentSlide }) => { if (currentSlide !== sec) stopAudio(); });
    },
  };

  // ------------------------------------------------------------------ 13 closing: the day on one line
  S.closing = {
    init(sec) {
      const svg = $(sec, '.dayline'), n = T.day.length, seg = 1136 / n;
      const all = env(CALL, 0.2, 61, 1);
      svg.innerHTML = T.day.map((_, i) => `<g class="wave dl k-fade dl${i}"></g>`).join('');
      T.day.forEach((_, i) => {
        const part = all.slice(Math.floor(i * all.length / n), Math.floor((i + 1) * all.length / n)).filter((_, j) => j % 3 === 0);
        bars($(svg, `.dl${i}`), part, 72 + i * seg + 6, 420, seg - 12, 30, () => (i % 2 ? 'ai' : 'voice'));
      });
      $(sec, '.steps').innerHTML = T.day.map(([num, name, mins], i) =>
        `<p class="stp k-rise sp${i}" style="left:${72 + i * seg + 6}px;width:${seg - 12}px"><span class="num">${num ? 'Challenge ' + num : 'Then'}</span>${name}<small>${mins}</small></p>`).join('');
    },
    beats: [[
      [0, l => show(q('.st'), l)],
      ...T.day.map((_, i) => [900 + i * 260, l => { show(q(`.dl${i}`), l); show(q(`.sp${i}`), l, 200); }]),
      [3600, l => { show(q('.cta'), l, 0); show(q('.repo'), l, 400); }],
    ]],
  };

  // ------------------------------------------------------------------ 14 thanks: the call ends, the line goes flat
  S.thanks = {
    init(sec) {
      const u = W[CALL].turns[6];
      bars($(sec, '.tk-wave'), env(CALL, u.t0, u.t1), 340, 300, 600, 70, () => 'ai', 0.6, 1);
    },
    beats: [[
      [0, l => show(q('.tk-wave'), l)],
      [1300, () => el().classList.add('calm')],
      [1500, l => show(q('.tk-cap'), l)],
      [1700, l => qq('h1, .tk-by, .tk-next').forEach((x, i) => show(x, l, i * 500))],
    ]],
    reset(sec) { sec.classList.remove('calm'); },
  };
})();
