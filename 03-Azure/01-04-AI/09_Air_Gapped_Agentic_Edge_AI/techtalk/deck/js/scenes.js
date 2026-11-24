/* Nothing crosses the line: drawings and choreography for each sheet.

   The beat engine (beat-engine.js, from the wow-reveal-presentations skill) runs these scenes. Each
   scene is a list of beats; each beat is a list of [ms, fn(live)] steps that set absolute state.
   This file also draws the shared parts once at load: the air-gap line, the title blocks and the
   drawing-index boxes. Beat is only used inside steps, so it exists by the time they run. */
(() => {
  const T = window.TALK;
  const q = s => Beat.$(Beat.el(), s);
  const qa = s => Beat.$$(Beat.el(), s);
  const show = (e, l, d) => Beat.show(e, l, d);
  const heads = l => qa('.kicker, .title, .subtitle').forEach(x => show(x, l));
  const all = (s, l, stagger = 0) => qa(s).forEach((x, i) => show(x, l, stagger ? i * stagger : undefined));

  // ------------------------------------------------------------------ shared drawing parts
  // The air gap: two rules with section hatching between them, an optional gate and its seal.
  const gapMarkup = g => {
    const x = +g.dataset.x, y1 = +g.dataset.y1, y2 = +g.dataset.y2, w = 8, H = 24;
    const gate = g.dataset.gate ? +g.dataset.gate : null;
    const rule = dx => gate === null ? `M${x + dx} ${y1} V${y2}` : `M${x + dx} ${y1} V${gate - H} M${x + dx} ${gate + H} V${y2}`;
    const hatch = (a, b) => `<rect class="gap-hatch k-fade gh" x="${x - w}" y="${a}" width="${2 * w}" height="${b - a}"/>`;
    let s = `<path class="gap-rule k-draw gr" pathLength="1" d="${rule(-w)}"/><path class="gap-rule k-draw gr" pathLength="1" d="${rule(w)}"/>`;
    if (gate === null) s += hatch(y1, y2);
    else {
      s += hatch(y1, gate - H) + hatch(gate + H, y2);
      s += `<path class="gap-jamb k-fade gj" d="M${x - w - 6} ${gate - H} H${x + w + 6} M${x - w - 6} ${gate + H} H${x + w + 6}"/>`;
      s += `<rect class="gap-seal k-pop gs" x="${x - w}" y="${gate - H}" width="${2 * w}" height="${2 * H}"/>`;
    }
    if (!g.dataset.notag) s += `<text class="gap-tag k-fade gt" x="${x}" y="${y1 - 10}">AIR GAP</text>`;
    g.innerHTML = s;
  };
  const gapIn = l => { qa('.gr').forEach((e, i) => show(e, l, i * 150)); qa('.gh, .gj, .gt').forEach(e => show(e, l, 700)); };

  // A revision cloud around a rectangle, drawn clockwise so every arc bulges outward.
  const cloud = (x1, y1, x2, y2, s = 18) => {
    let d = `M${x1.toFixed(1)} ${y1.toFixed(1)}`;
    const side = (len, dx, dy) => {
      const n = Math.max(2, Math.round(len / s)), c = len / n, r = (c / 1.6).toFixed(1);
      for (let i = 0; i < n; i++) d += ` a${r} ${r} 0 0 1 ${(dx * c).toFixed(1)} ${(dy * c).toFixed(1)}`;
    };
    side(x2 - x1, 1, 0); side(y2 - y1, 0, 1); side(x2 - x1, -1, 0); side(y2 - y1, 0, -1);
    return d;
  };

  // A number that runs from one value to another live, and is exact when settled.
  const run = (e, from, to, live, ms = 1600, dec = 0) => {
    const fmt = v => v.toFixed(dec);
    if (!live) { e.textContent = fmt(to); return; }
    const sec = e.closest('section'); let t0 = null, held = 0, last = 0;
    const tick = now => {
      if (t0 === null) { t0 = now; last = now; }
      if (sec.classList.contains('motion-paused')) held += now - last;
      last = now;
      const p = Math.min(1, (now - t0 - held) / ms);
      e.textContent = fmt(from + (to - from) * (1 - Math.pow(1 - p, 3)));
      if (p < 1 && sec.classList.contains('present')) requestAnimationFrame(tick); else e.textContent = fmt(to);
    };
    requestAnimationFrame(tick);
  };

  const secs = [...document.querySelectorAll('.reveal .slides > section')];
  document.querySelectorAll('g.gapline').forEach(gapMarkup);
  secs.forEach(sec => {
    if (!sec.dataset.sheet) return;
    const n = String(sec.dataset.sheet).padStart(2, '0');
    sec.insertAdjacentHTML('beforeend', `<div class="tblock" aria-hidden="true">
      <div><p class="l">Title</p><p class="v">Nothing crosses the line</p></div>
      <div><p class="l">Drawing</p><p class="v">AG-09</p></div>
      <div><p class="l">Sheet</p><p class="v">${n} / ${secs.length}</p></div>
      <div class="rev"><p class="l">Rev</p><p class="v">${sec.dataset.rev || 'A'}</p></div></div>`);
  });
  document.querySelectorAll('g.idxbox').forEach(g => {
    g.innerHTML = '<rect class="ln k-draw ibox" pathLength="1" x="736" y="236" width="456" height="62"/><g class="k-pop itri"><path class="rtri" d="M1212 255 l11 19 h-22 z"/><text class="rtri-n" x="1212" y="271"></text></g>';
  });

  // ------------------------------------------------------------------ scenes
  const S = {};

  S.cover = {
    beats: [[
      [0, l => all('.cv-event, h1, .cv-sub', l)],
      [1000, l => all('.cv-l', l)],
      [1200, l => gapIn(l)],
      [1900, l => show(q('.cv-tb'), l)],
      [2800, l => all('.cv-r', l, 300)],
      [3600, l => all('.cv-x, .cv-rt', l)],
      [4400, l => all('.cv-lead', l)],
      [4900, l => show(q('.cv-start'), l)],
      [5200, l => { Beat.go(q('.cv-travel'), l); show(q('.cv-route'), l); }],
      [7300, l => { show(q('.cv-bundle'), l); show(q('.cv-stamp'), l, 250); }],
    ]],
    reset(sec) { sec.querySelector('.cv-travel').classList.remove('go'); },
  };

  // The index boxes the current sheet; the box is placed from the row's real position.
  S.chapter = {
    beats: [[
      [0, l => all('.ch-label, h1, .ch-sub, .ih, .row', l)],
      [1300, l => {
        const sec = Beat.el(), i = +q('.idxbox').dataset.row, idx = q('.idx'), row = Beat.$$(sec, '.idx .row')[i];
        const y = idx.offsetTop + row.offsetTop, h = row.offsetHeight;
        q('.ibox').setAttribute('y', y); q('.ibox').setAttribute('height', h);
        q('.itri path').setAttribute('d', `M1212 ${y + h / 2 - 12} l11 19 h-22 z`);
        q('.itri text').setAttribute('y', y + h / 2 + 4); q('.itri text').textContent = String(i + 1);
        show(q('.ibox'), l);
      }],
      [2300, l => show(q('.itri'), l)],
    ]],
  };

  S.gap = {
    beats: [
      [
        [0, heads],
        [900, l => { all('.sides', l); gapIn(l); }],
        [2200, l => all('.m0, .m1', l, 200)],
        ...[0, 1, 2].flatMap(i => [
          [4300 + i * 2600, l => show(q(`.r${i}`), l)],
          [5300 + i * 2600, l => all(`.x${i}, .t${i}, .u${i}`, l)],
        ]),
        [11400, l => show(q('.foot'), l)],
      ],
      [
        [0, () => Beat.el().classList.add('b1')],
        [400, l => show(q('.plist'), l)],
        [1700, l => show(q('.inq'), l)],
        [2700, l => show(q('.inq-t'), l)],
        [4000, l => show(q('.moral'), l)],
      ],
    ],
    reset(sec) { sec.classList.remove('b1'); },
  };

  // Times at which the pen (4200 ms over the loop) reaches the end of each numbered segment.
  const LEGEND = ['publish telemetry', 'filter at the broker', 'anomaly to the agent', 'call with the SAT token', 'inference on CPU', 'command, via the broker'];
  S.plan = {
    init(sec) { sec.querySelector('.legend').innerHTML = LEGEND.map((t, i) => `<p class="k-rise lg${i + 1}"><span>${i + 1}</span>${t}</p>`).join(''); },
    beats: [
      [
        [0, heads],
        [900, l => { show(q('.node'), l); show(Beat.$$(Beat.el(), '.rt')[0], l, 600); }],
        [1600, l => all('.room', l)],
        [2300, l => Beat.$$(Beat.el(), '.rt').slice(1).forEach((x, i) => show(x, l, i * 150))],
        [2900, l => all('.pp', l, 120)],
        [4600, l => { gapIn(l); show(q('.arcl'), l, 600); show(q('.arcn'), l, 900); }],
        [6200, l => show(q('.foot'), l)],
      ],
      [
        [0, l => Beat.go(q('.loop-pen'), l)],
        [350, l => all('.lp1, .nb1, .lg1', l)],
        [1050, l => all('.lp2, .nb2, .lg2', l)],
        [2150, l => all('.lp3, .nb3, .lg3', l)],
        [2700, l => all('.lp4, .nb4, .lg4', l)],
        [4150, l => all('.lp5, .nb5, .lg5', l)],
        [4400, l => Beat.go(q('.cmd-pen'), l)],
        [5200, l => all('.lp6, .nb6, .lg6', l)],
        [6000, l => show(q('.moral'), l)],
      ],
    ],
    reset(sec) { sec.querySelectorAll('.travel').forEach(t => t.classList.remove('go')); },
  };

  // Five items cross through one gate at y = 365; each lands in its store and shows its check.
  const GATE = 365, rowTop = i => 192 + i * 72, route = i => { const y = rowTop(i) + 29; return `M520 ${y} C552 ${y} 554 ${GATE} 580 ${GATE} C606 ${GATE} 608 ${y} 640 ${y}`; };
  const cross = i => [l => { Beat.go(q(`.tv${i}`), l); show(q(`.ro${i}`), l); }];
  const land = i => [l => { q(`.st${i}`).classList.add('full'); show(q(`.gk${i}`), l); show(q(`.tk${i}`), l); }];
  S.manifest = {
    init(sec) {
      const m = T.manifest;
      sec.querySelector('.mrows').innerHTML = m.map((r, i) => `
        <div class="mrow k-rise mr" style="top:${rowTop(i)}px"><p class="n">${r.name}</p><p class="d">${r.detail}</p><span class="tick k-fade tk${i}">CROSSED ✓</span></div>
        <div class="store k-fade sto st${i}" style="top:${rowTop(i)}px"><p class="n">${r.store}</p><p class="d">${r.where}</p></div>
        <p class="gck k-fade gk${i}" style="top:${rowTop(i) + 21}px">✓ ${r.check}</p>`).join('');
      sec.querySelector('.routes').innerHTML = m.map((_, i) => `<path class="ln thin soft k-draw ro${i}" pathLength="1" d="${route(i)}"/>`).join('');
      sec.querySelector('.travels').innerHTML = m.map((_, i) => `<div class="travel parcel tv${i}" style="offset-path:path('${route(i)}');--dur:1500ms"></div>`).join('');
    },
    beats: [
      [
        [0, heads],
        [900, l => { all('.mh, .sh', l); gapIn(l); }],
        [1600, l => all('.mr', l, 150)],
        [2600, l => all('.sto', l, 120)],
        [4200, ...cross(0)],
        [5800, ...land(0)],
      ],
      [1, 2, 3, 4].flatMap((i, k) => [[k * 1800, ...cross(i)], [k * 1800 + 1600, ...land(i)]]),
      [
        [0, l => show(q('.ra'), l)],
        [900, l => all('.xa, .ta', l)],
        [1700, l => show(q('.rb'), l)],
        [2600, l => all('.xb, .tb', l)],
        [3700, l => all('.moral, .foot', l)],
      ],
    ],
    reset(sec) { sec.querySelectorAll('.store').forEach(s => s.classList.remove('full')); sec.querySelectorAll('.travel').forEach(t => t.classList.remove('go')); },
  };

  // The catalog as 177 dots; the picked one is phi-4-mini (its position is illustrative).
  const PICK = 44;
  S.store7 = {
    init(sec) {
      const M = T.model;
      sec.querySelector('.dots').innerHTML = Array.from({ length: M.catalog }, (_, i) =>
        `<circle class="dot k-pop d${i}" cx="${76 + (i % 15) * 22}" cy="${214 + Math.floor(i / 15) * 20}" r="4.5"/>`).join('');
      sec.querySelector('.mid').textContent = M.id;
      sec.querySelector('.msize').textContent = `${M.sizeGB} GB`;
      sec.querySelector('.s0d').textContent = `${M.sizeGB} GB, about ${M.cacheMin} minutes`;
      sec.querySelector('.s2d').textContent = M.store;
      sec.querySelector('.s3d').textContent = M.storeRef;
    },
    beats: [
      [
        [0, heads],
        [900, l => show(q('.cat-h'), l)],
        [1200, l => qa('.dot').forEach((d, i) => show(d, l, i * 8))],
        [3400, () => { qa('.dot').forEach((d, i) => d.classList.toggle('dim', i !== PICK)); q(`.d${PICK}`).classList.add('pick'); }],
        [3900, l => all('.pick-l, .pick-t', l)],
        [4900, l => show(q('.resolve'), l)],
        [6300, l => { gapIn(l); show(q('.src7'), l, 400); }],
        [7300, l => show(q('.xin'), l)],
        [8100, l => show(q('.st0'), l)],
        ...[1, 2, 3, 4].map(i => [8100 + i * 800, l => { show(qa('.sa')[i - 1], l); show(q(`.st${i}`), l, 250); }]),
        [11800, l => show(q('.foot'), l)],
      ],
      [
        [0, l => { Beat.el().classList.add('sealed'); show(q('.gs'), l); }],
        [800, l => show(q('.sealn'), l)],
        [1700, l => show(q('.loopb'), l)],
        [2800, l => show(q('.moral'), l)],
      ],
    ],
    reset(sec) { sec.classList.remove('sealed'); sec.querySelectorAll('.dot').forEach(d => d.classList.remove('dim', 'pick')); },
  };

  // The decoded token, with a leader from each field to its note.
  const FIELDS = [224, 264, 302, 322, 362, 402, 442];
  const NOTES = [[224, 0], [264, 1], [312, 2], [386, 5], [442, 6]];
  S.sat = {
    init(sec) {
      const s = T.sat, k = t => `<span class="k">${t}</span>`;
      const rows = [`${k('aud')}  ["${s.aud}"]`, `${k('iss')}  ${s.iss}`, `${k('sub')}  ${s.sub[0]}`, `     ${s.sub[1]}`,
        `${k('iat')}  ${s.iat}`, `${k('exp')}  ${s.exp}`, `${k('pod')}  ${s.pod}`];
      sec.querySelector('.fields').innerHTML = rows.map((r, i) => `<p class="fld k-fade f${i}" style="top:${FIELDS[i] - 9}px">${r}</p>`).join('');
      const notes = [`<b>aud</b> must equal satAuth.audience`, `<b>iss</b> the cluster's own API server,<br>not a cloud identity provider`,
        `<b>sub</b> the only authorized subject,<br>role ${s.role}`, `<b>exp - iat</b> one hour; the agent<br>re-reads the file on every request`,
        `<b>automountServiceAccountToken: false</b><br>only this audience-bound token is mounted`];
      sec.querySelector('.notes8').innerHTML = notes.map((n, i) => `<p class="note k-fade a${i}" style="left:832px;top:${NOTES[i][0] - 9}px">${n}</p>`).join('');
      sec.querySelector('.leads').innerHTML = NOTES.map(([y, f], i) => `<g class="k-fade ld${i}"><circle class="lead-dot" cx="784" cy="${FIELDS[f]}" r="3"/></g><path class="ln thin k-draw ll${i}" pathLength="1" d="M784 ${FIELDS[f]} H802 V${y} H824"/>`).join('');
      sec.querySelector('.b2d').textContent = `usage: ${s.promptTokens} + ${s.completionTokens} tokens`;
    },
    beats: [
      [
        [0, heads],
        [800, l => { gapIn(l); all('.entra, .cfg', l, 300); }],
        [1800, l => show(q('.card'), l)],
        ...FIELDS.map((_, i) => [2600 + i * 450, l => show(q(`.f${i}`), l)]),
        ...NOTES.map(([, f], i) => [2900 + f * 450 + 300, l => all(`.ld${i}, .ll${i}, .a${i}`, l)]),
        [5900, l => all('.dimv, .dimt', l)],
        [6900, l => show(q('.foot'), l)],
      ],
      [
        [0, l => show(q('.b0'), l)],
        [900, l => show(qa('.bnd')[0], l)],
        [1300, l => show(q('.b1'), l)],
        [2300, l => show(qa('.bnd')[1], l)],
        [2700, l => show(q('.b2'), l)],
        [3800, l => show(q('.rq'), l)],
        [4600, l => all('.xq, .rqn', l)],
      ],
    ],
  };

  // A strip chart of the recorded ticks; the dataflow drops a reading when temp <= 85.0 and vibration <= 7.5.
  // Value labels go under the points where the trace climbs past them.
  const BELOW = [331, 333, 358, 359];
  const PX = [130, 200, 270, 340, 410, 530, 600, 670, 740], PY = t => 540 - (t - 50) * 5;
  const passes = ([, t, v]) => !(t <= T.filter.temp && v <= T.filter.vib);
  S.filter = {
    init(sec) {
      sec.querySelector('.ylabels').innerHTML = [50, 70, 90, 110].map(t => `<text class="axis-l k-fade ax" x="88" y="${PY(t) + 4}" text-anchor="end">${t}</text><path class="ln thin k-fade ax" d="M92 ${PY(t)} H100"/>`).join('');
      let pts = '', rows = '', k = 0;
      T.ticks.forEach((tk, i) => {
        const [n, t] = tk, x = PX[i], y = PY(t);
        if (i > 0 && i !== 5) pts += `<path class="ln thin soft k-draw sg${i}" pathLength="1" d="M${PX[i - 1]} ${PY(T.ticks[i - 1][1])} L${x} ${y}"/>`;
        pts += `<circle class="pt k-pop p${i}" cx="${x}" cy="${y}" r="5"/><circle class="ring rg${i}" cx="${x}" cy="${y}" r="7" style="color:var(--ink)"/>`;
        pts += `<text class="pv k-fade v${i}" x="${x}" y="${BELOW.includes(n) ? y + 20 : y - 12}">${t.toFixed(1)}</text><text class="axis-l k-fade xl${i}" x="${x}" y="558" text-anchor="middle">${n}</text>`;
        if (passes(tk)) rows += `<p class="tr k-rise tr${i}">tick ${n} · ${t.toFixed(1)} °C · ${tk[2]} mm/s</p>`;
      });
      sec.querySelector('.pts').innerHTML = pts;
      sec.querySelector('.rows').innerHTML = rows;
      sec.querySelector('.costs').innerHTML = T.warnings.map((w, i) => `<p class="note k-fade cl${i}" style="left:904px;top:${458 + i * 40}px"><b>${w.ms.toFixed(1)} ms</b></p><div class="bar k-growx cb${i}" style="left:904px;top:${476 + i * 40}px;width:${Math.round(w.ms / 9000 * 300)}px"></div>`).join('');
    },
    beats: [
      [
        [0, heads],
        [900, l => all('.ax', l)],
        [1900, l => all('.th', l)],
        [2700, l => show(q('.topic'), l)],
        ...T.ticks.flatMap((tk, i) => [
          [3500 + i * 700, l => all(`.sg${i}, .p${i}, .v${i}, .xl${i}`, l)],
          [3850 + i * 700, l => {
            if (passes(tk)) { Beat.pulse(q(`.rg${i}`), l); show(q(`.tr${i}`), l); }
            else { q(`.p${i}`).classList.add('drop'); q(`.v${i}`).classList.add('drop'); }
          }],
        ]),
        [10100, l => show(q('.drop-n'), l)],
        [10600, l => show(q('.foot'), l)],
      ],
      [
        [0, l => show(q('.cost-h'), l)],
        [500, l => all('.cl0, .cb0', l)],
        [1100, l => all('.cl1, .cb1', l)],
        [2100, l => show(q('.cost-n'), l)],
        [3200, l => show(q('.moral'), l)],
      ],
    ],
    reset(sec) { sec.querySelectorAll('.drop').forEach(e => e.classList.remove('drop')); },
  };

  // The namespace as a room: four doors on the inner side, none toward the internet.
  const DOORS = [250, 330, 410, 490], DH = 16;
  S.wall = {
    init(sec) {
      const segs = [200, ...DOORS.flatMap(y => [y - DH, y + DH]), 560];
      const side = x => { let d = ''; for (let i = 0; i < segs.length; i += 2) d += `M${x} ${segs[i]} V${segs[i + 1]} `; return d; };
      let w = `<path class="ln k-draw wo" pathLength="1" d="M700 200 H380 V560 H700"/><path class="ln k-draw wo" pathLength="1" d="M688 212 H392 V548 H688"/>`;
      w += `<path class="ln k-draw wo" pathLength="1" d="${side(700)}"/><path class="ln k-draw wo" pathLength="1" d="${side(688).replace('M688 200', 'M688 212').replace('V560', 'V548')}"/>`;
      w += `<rect class="gap-hatch k-fade wh" x="380" y="200" width="320" height="12"/><rect class="gap-hatch k-fade wh" x="380" y="548" width="320" height="12"/><rect class="gap-hatch k-fade wh" x="380" y="212" width="12" height="336"/>`;
      for (let i = 0; i < segs.length; i += 2) { const a = Math.max(segs[i], 212), b = Math.min(segs[i + 1], 548); if (b > a) w += `<rect class="gap-hatch k-fade wh" x="688" y="${a}" width="12" height="${b - a}"/>`; }
      sec.querySelector('.walls').innerHTML = w;
      const dests = [
        ['kube-system  :53 UDP and TCP', 'CoreDNS: every name lookup'],
        ['azure-iot-operations  :1883, :18883', 'MQTT broker: anomalies in, commands out'],
        ['foundry-local-operator, istio-system  :80 :443 :8080', 'internal gateway and phi-4-mini'],
        ['edge-agents  podSelector: {}', 'pods in the same namespace'],
      ];
      sec.querySelector('.doors').innerHTML = DOORS.map((y, i) => `<path class="ln k-draw dl${i}" pathLength="1" d="M700 ${y} H774" marker-end="url(#ah)"/><g class="k-pop dn${i}"><circle class="fillw ln thin" cx="738" cy="${y - 14}" r="9"/><text class="rtri-n" x="738" y="${y - 10}">${i + 1}</text></g>`).join('');
      sec.querySelector('.dests').innerHTML = dests.map((d, i) => `<div class="part k-pop dd${i}" style="left:780px;top:${DOORS[i] - 28}px;width:430px"><p class="n">${d[0].replace('  ', ' &nbsp;')}</p><p class="d">${d[1]}</p></div>`).join('');
      sec.querySelector('.cl').setAttribute('d', cloud(772, 216, 1218, 284, 18));
    },
    beats: [
      [
        [0, heads],
        [900, l => { all('.wo', l, 120); all('.wh', l); show(q('.wl'), l, 600); }],
        [1900, l => all('.rm', l, 150)],
        [2400, l => all('.ch', l, 150)],
        ...DOORS.map((_, i) => [3300 + i * 1100, l => { show(q(`.dl${i}`), l); show(q(`.dn${i}`), l, 300); show(q(`.dd${i}`), l, 500); }]),
        [8000, l => show(q('.wr'), l)],
        [8800, l => all('.wx, .wrt', l)],
        [9400, l => show(q('.foot'), l)],
      ],
      [
        [0, l => show(q('.cl'), l)],
        [1300, l => all('.tri', l, 200)],
        [1800, l => show(q('.wn'), l)],
        [3200, l => show(q('.moral'), l)],
      ],
    ],
  };

  // The wow: sealed, a probe stops at the line; a fault crosses the inside loop and the PLC acts.
  const NODEX = [401, 551, 701, 851, 1001, 1151];
  S.seal = {
    init(sec) {
      const F = T.fault, C = T.critical, S2 = T.sop;
      sec.querySelector('.err').innerHTML = T.probe.error.join('<br>');
      sec.querySelector('.fA').innerHTML = `bearingTempC <b>${F.temp}</b><br>vibrationMmPerSec <b>${F.vib}</b><br>coolantFlowLpm <b>${F.coolant}</b>`;
      sec.querySelector('.fB').innerHTML = `&gt;= ${S2.critTemp} °C or &gt;= ${S2.critVib.toFixed(1)} mm/s<br>or coolant &lt; ${S2.critCoolant.toFixed(1)} LPM<br>call <b>${C.tool}</b>`;
      sec.querySelector('.fC').innerHTML = `tool <b>${C.tool}</b><br>spindle_rpm_delta_pct <b>${C.delta}</b><br>interlock_mode <b>${C.mode}</b>`;
      sec.querySelector('.was').innerHTML = `was <b>${T.rpm.before}</b>, delta <b>${C.delta} %</b><br>coolantBoost=<b>True</b><br>from the simulator log`;
    },
    beats: [
      [
        [0, heads],
        [700, l => show(q('.st12'), l)],
        [1300, l => { show(q('.so'), l); gapIn(l); show(q('.gs'), l, 900); }],
        [2300, l => all('.nd', l, 120)],
        [3200, l => all('.ar', l, 100)],
        [3800, l => show(q('.tgt'), l)],
        [5200, l => { show(q('.probe'), l); show(q('.pt'), l); Beat.go(q('.probe-pen'), l); }],
        [6700, l => all('.px, .err', l)],
        [7400, l => show(q('.foot'), l)],
      ],
      [
        [0, l => show(q('.cA'), l)],
        [900, l => Beat.go(q('.fault-pen'), l)],
        ...NODEX.map((x, i) => [900 + Math.round((x - 401) / 750 * 3600), () => qa('.nd')[i].classList.add('lit')]),
        [900 + 2160, l => show(q('.cB'), l)],
        [900 + 2880, l => { all('.dim12', l); Beat.count(q('.lat'), T.critical.ms, l, 1800, 1); }],
        [6000, l => show(q('.cC'), l)],
      ],
      [
        [0, l => { show(q('.rpm'), l); run(q('.rv'), T.rpm.before, T.rpm.after, l, 1700); }],
        [1900, l => show(q('.was'), l)],
        [2500, l => show(q('.hold'), l)],
        [3500, l => show(q('.moral'), l)],
      ],
    ],
    reset(sec) {
      sec.querySelectorAll('.travel').forEach(t => t.classList.remove('go'));
      sec.querySelectorAll('.nd').forEach(n => n.classList.remove('lit'));
      sec.querySelector('.rv').textContent = String(T.rpm.before);
      sec.querySelector('.lat').textContent = '0.0';
    },
  };

  // Recorded decisions with revision clouds on the empty fields, then the guard path (illustrative failure).
  const LOGTOP = [180, 276, 372];
  S.guard = {
    init(sec) {
      const rows = [...T.warnings.map(w => ({ ...w, kind: 'warning' })),
        { ...T.fault, ...T.critical, priority: 'missing', kind: 'critical', critical: true }];
      sec.querySelector('.logs').innerHTML = rows.map((r, i) => `<div class="logrow k-rise lg" style="top:${LOGTOP[i]}px"><p class="h">${r.temp} °C, ${r.vib} mm/s: ${r.kind}</p>tool ${r.tool} &nbsp;delta ${r.delta} &nbsp;boost ${r.boost}<br>interlock_mode ${r.critical ? r.mode : `<span class="nul">${r.mode}</span>`} &nbsp;priority <span class="nul">${r.priority}</span> &nbsp;${r.ms.toFixed(1)} ms</div>`).join('');
    },
    beats: [
      [
        [0, heads],
        [900, l => all('.lg', l, 300)],
        [2600, l => {
          const g = q('.clouds');
          g.innerHTML = qa('.nul').map((s, i) => {
            const row = s.offsetParent, x = row.offsetLeft + s.offsetLeft, y = row.offsetTop + s.offsetTop;
            return `<path class="rcloud k-draw cd" pathLength="1" style="--d:${i * 250}ms" d="${cloud(x - 5, y - 3, x + s.offsetWidth + 5, y + s.offsetHeight + 3, 9)}"/>`;
          }).join('');
          qa('.cd').forEach(c => show(c, l));
        }],
        [4300, l => show(q('.nn'), l)],
        [4800, l => show(q('.foot'), l)],
      ],
      [
        [0, l => all('.gp', l, 200)],
        [1000, l => all('.gm', l)],
        [1700, l => all('.gg, .exc', l)],
        [2500, l => show(q('.grule'), l)],
        [3500, l => { show(q('.ill'), l); q('.gmod').classList.add('dead'); Beat.el().classList.add('failed'); }],
        [4200, l => Beat.go(q('.guard-pen'), l)],
        [6700, l => show(q('.moral'), l)],
      ],
    ],
    reset(sec) { sec.classList.remove('failed'); sec.querySelector('.gmod').classList.remove('dead'); sec.querySelector('.guard-pen').classList.remove('go'); sec.querySelector('.clouds').innerHTML = ''; },
  };

  S.real = {
    beats: [
      [
        [0, heads],
        [900, l => show(q('.hd'), l)],
        [1300, l => all('.rr', l, 500)],
        [4400, l => show(q('.foot'), l)],
      ],
      [
        [0, l => {
          const tbl = q('.tbl'), tr = q('.cross'), c = tr.children[2];
          const x = tbl.offsetLeft + tr.offsetLeft + c.offsetLeft, y = tbl.offsetTop + tr.offsetTop + c.offsetTop;
          q('.cl14').setAttribute('d', cloud(x + 4, y + 4, x + c.offsetWidth - 4, y + c.offsetHeight - 4, 14));
          show(q('.cl14'), l);
        }],
        [1300, l => show(q('.tri14'), l)],
        [1700, l => show(q('.n14'), l)],
        [2900, l => show(q('.moral'), l)],
      ],
    ],
  };

  S.signoff = {
    init(sec) {
      sec.querySelector('.sheets').innerHTML = T.waits.map(([n, name, m]) => `<div class="k-rise sr"><span class="no">${n}</span><span>${name}</span><span class="w">about ${m} min</span></div>`).join('');
    },
    beats: [[
      [0, l => all('.so-h, h2', l)],
      [1200, l => gapIn(l)],
      [1800, l => show(q('.so-r'), l)],
      [2500, l => show(q('.so-x'), l)],
      [2900, l => { show(q('.so-l'), l); show(q('.so-b'), l, 900); }],
      [3400, l => show(q('.big-block'), l)],
      [3800, l => all('.sr', l, 250)],
      [5400, l => show(q('.w1'), l)],
      [6000, l => show(q('.w2'), l)],
      [6800, l => show(q('.w3'), l)],
      [7800, l => show(q('.iss'), l)],
    ]],
  };

  window.SCENES = S;
})();
