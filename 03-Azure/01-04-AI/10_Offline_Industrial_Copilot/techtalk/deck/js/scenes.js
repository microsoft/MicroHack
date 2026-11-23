/* Pull the cable: scene engine and choreography.

   Each built slide is a short storyboard of beats. Beat 0 plays when the slide is entered; each click
   (an invisible Reveal fragment) plays the next beat and the slide then waits, with a small cue, for the
   next click. Steps only animate when they arrive live: a step back, a return, the overview, reduced
   motion and print show the settled state at once. One clock per slide: it pauses with the deck, the tab
   or the Pause button, and is stopped when the slide is left. */
(() => {
  const T = window.TALK;
  const $ = (r, s) => r.querySelector(s);
  const $$ = (r, s) => [...r.querySelectorAll(s)];
  const params = new URLSearchParams(location.search);
  const printing = params.has('print-pdf') || params.has('export');
  const reduced = matchMedia('(prefers-reduced-motion: reduce)');
  const still = () => printing || reduced.matches || params.has('static');

  // ------------------------------------------------------------------ helpers used by the scenes
  // Show an element (or a selector inside the scene). Live arrivals animate, after an optional delay.
  const show = (el, live, d) => {
    if (!el) return;
    el.classList.add('on');
    if (live) { if (d !== undefined) el.style.setProperty('--d', `${d}ms`); el.classList.remove('enter'); void el.getBoundingClientRect(); el.classList.add('enter'); }
  };
  const hide = el => el && el.classList.remove('on', 'enter');
  const pulse = (el, live, d) => { if (!el || !live) return; if (d !== undefined) el.style.setProperty('--d', `${d}ms`); el.classList.remove('enter'); void el.getBoundingClientRect(); el.classList.add('enter'); };
  const go = (el, live, cls = 'go') => { if (!el || !live) return; el.classList.remove(cls); void el.getBoundingClientRect(); el.classList.add(cls); };

  // Split a text into word spans that stream in like tokens. Returns the time the stream takes.
  const PER_WORD = 55;
  const prepStream = el => {
    if (el.dataset.ready) return;
    el.innerHTML = el.dataset.text.split(' ').map(w => `<span class="w k-tok">${w}</span>`).join(' ');
    el.dataset.ready = '1';
  };
  const stream = (el, live) => {
    prepStream(el);
    $$(el, '.w').forEach((w, i) => show(w, live, i * PER_WORD));
    return el.dataset.text.split(' ').length * PER_WORD;
  };

  // Count a number up; settles at once when not live.
  const count = (el, to, live, ms = 1400, dec = 0) => {
    const fmt = v => v.toFixed(dec);
    if (!live) { el.textContent = fmt(to); return; }
    const sec = el.closest('section'); let t0 = null, held = 0, last = 0;
    const tick = now => {
      if (t0 === null) { t0 = now; last = now; }
      if (sec.classList.contains('motion-paused')) held += now - last;
      last = now;
      const p = Math.min(1, (now - t0 - held) / ms), e = 1 - Math.pow(1 - p, 3);
      el.textContent = fmt(to * e);
      if (p < 1 && sec.classList.contains('present')) requestAnimationFrame(tick); else el.textContent = fmt(to);
    };
    requestAnimationFrame(tick);
  };

  // The isometric edge box, drawn into a <g class="edge">. Shared by the cover and "Pull the cable".
  const edgeBox = (g, cx, cy, s, cableEnd, traces = true) => {
    const w = 150 * s, h = 75 * s, d = 95 * s, P = (...a) => a.map(v => v.toFixed(1)).join(' ');
    const port = [cx + 0.72 * w, cy + 2 * h - 0.72 * h + 0.55 * d];
    const along = (t, depth) => [cx + t * w, cy + 2 * h - t * h + depth * d];
    let vents = '';
    for (let i = 0; i < 6; i++) {
      const x = cx - w * 0.6 + i * w * 0.07, y = cy + h + i * h * 0.07;
      vents += `M${P(x, y)} l${P(w * 0.3, -h * 0.3)} `;
    }
    const leds = [0.14, 0.24, 0.34, 0.44].map((t, i) => { const [x, y] = along(t, 0.3); return `<circle class="box-led blink" cx="${x.toFixed(1)}" cy="${y.toFixed(1)}" r="${(3.6 * s).toFixed(1)}" style="--d:${i * 0.4}s"/>`; }).join('');
    const [px, py] = port;
    const cable = `M${P(px + 12 * s, py + 2 * s)} C${P(px + 80 * s, py + 14 * s)} ${P(cableEnd[0] - 140, cableEnd[1] - 90)} ${P(cableEnd[0], cableEnd[1])}`;
    g.innerHTML = `
      <ellipse class="box-floor" cx="${cx}" cy="${(cy + 2 * h + d + 10).toFixed(1)}" rx="${(w * 1.7).toFixed(1)}" ry="${(h * 0.55).toFixed(1)}"/>
      <ellipse class="box-halo live" cx="${cx}" cy="${(cy + h + d * 0.5).toFixed(1)}" rx="${(w * 1.9).toFixed(1)}" ry="${(w * 1.4).toFixed(1)}"/>
      <g class="traces" ${traces ? '' : 'style="display:none"'}>
        <path class="trace" d="M${P(cx - w * 0.85, cy + h + d * 0.55)} H${P(cx - w * 1.35)} V${P(cy + h - d * 0.1)} H${P(cx - w * 1.6)}"/>
        <path class="trace" d="M${P(cx - w * 0.45, cy + 1.55 * h + d * 0.75)} H${P(cx - w * 1.15)} V${P(cy + 2 * h + d * 0.95)} H${P(cx - w * 1.4)}"/>
        <path class="trace" d="M${P(cx, cy + 2)} V${P(cy - h * 0.55)} H${P(cx + w * 0.42)} V${P(cy - h * 0.9)}"/>
        <path class="trace-current" d="M${P(cx - w * 0.85, cy + h + d * 0.55)} H${P(cx - w * 1.35)} V${P(cy + h - d * 0.1)} H${P(cx - w * 1.6)} M${P(cx, cy + 2)} V${P(cy - h * 0.55)} H${P(cx + w * 0.42)} V${P(cy - h * 0.9)}"/>
        <rect class="trace-pad" x="${(cx - w * 1.6 - 6).toFixed(1)}" y="${(cy + h - d * 0.1 - 3).toFixed(1)}" width="6" height="6"/>
        <rect class="trace-pad" x="${(cx - w * 1.4 - 6).toFixed(1)}" y="${(cy + 2 * h + d * 0.95 - 3).toFixed(1)}" width="6" height="6"/>
        <rect class="trace-pad" x="${(cx + w * 0.42 - 3).toFixed(1)}" y="${(cy - h * 0.9 - 6).toFixed(1)}" width="6" height="6"/>
      </g>
      <polygon class="box-left" points="${P(cx - w, cy + h, cx, cy + 2 * h, cx, cy + 2 * h + d, cx - w, cy + h + d)}"/>
      <polygon class="box-right" points="${P(cx, cy + 2 * h, cx + w, cy + h, cx + w, cy + h + d, cx, cy + 2 * h + d)}"/>
      <polygon class="box-top" points="${P(cx, cy, cx + w, cy + h, cx, cy + 2 * h, cx - w, cy + h)}"/>
      <clipPath id="clip-top-${g.closest('section').dataset.scene}"><polygon points="${P(cx, cy, cx + w, cy + h, cx, cy + 2 * h, cx - w, cy + h)}"/></clipPath>
      <path class="box-vent" d="${vents}"/>
      <polygon class="box-chip" points="${P(cx + w * 0.12, cy + h * 0.78, cx + w * 0.46, cy + h * 1.12, cx + w * 0.12, cy + h * 1.46, cx - w * 0.22, cy + h * 1.12)}"/>
      <g clip-path="url(#clip-top-${g.closest('section').dataset.scene})"><rect class="box-sheen live" x="${(cx - w).toFixed(1)}" y="${cy}" width="${(w * 0.8).toFixed(1)}" height="${(2 * h).toFixed(1)}" transform="skewX(-30)"/></g>
      ${leds}
      <g class="cable-g"><path class="cable-body" d="${cable}"/><path class="cable-core" d="${cable}"/><path class="cable-data live" d="${cable}"/></g>
      <g class="plug-g"><rect class="plug" x="${(px - 2 * s).toFixed(1)}" y="${(py - 8 * s).toFixed(1)}" width="${(26 * s).toFixed(1)}" height="${(16 * s).toFixed(1)}" rx="3" transform="rotate(8 ${px.toFixed(1)} ${py.toFixed(1)})"/></g>
      <polygon class="box-port" points="${P(px - 4 * s, py - 6 * s, px + 8 * s, py - 12 * s, px + 8 * s, py + 2 * s, px - 4 * s, py + 8 * s)}"/>`;
    return port;
  };

  // ------------------------------------------------------------------ scenes
  const S = {};
  const K = ':is([class^="k-"], [class*=" k-"])';

  S.cover = {
    init(el) { edgeBox($(el, '.edge'), 940, 190, 1.25, [1330, 640]); },
    beats: [[
      [0, l => $$(el(), '.cv-copy :is([class^="k-"], [class*=" k-"]), .cv-foot').forEach(x => show(x, l))],
    ]],
  };

  S.chapter = {
    beats: [[
      [0, l => $$(el(), K).forEach(x => show(x, l))],
    ]],
  };

  S.q214 = {
    init(el) { $$(el, '.stream').forEach(prepStream); },
    beats: [
      [
        [0, l => $$(el(), '.kicker, .title, .subtitle').forEach(x => show(x, l))],
        [700, l => show($(el(), '.tablet'), l)],
        [1500, l => show($(el(), '.status'), l)],
        [3200, l => { show($(el(), '.bubble.q'), l); stream($(el(), '.bubble.q .stream'), l); }],
        [6600, l => $$(el(), '.cloudside .link.k-draw, .hops [class*="k-"]').forEach(x => show(x, l))],
        [9000, l => go($(el(), '.t-cloud'), l)],
        [10300, l => { const k = $(el(), '.link-last'); show(k, l); k.classList.add('flicker'); pulse(k, l); }],
        [11200, l => { hide($(el(), '.link-last')); show($(el(), '.dead-link'), l); show($(el(), '.fail-tag'), l); }],
        [12000, l => show($(el(), '.bubble.wait'), l)],
      ],
      [
        [0, () => el().classList.add('b1')],
        [700, l => { show($(el(), '.dev-hop'), l); pulse($(el(), '.devside .ring'), l); $$(el(), '.dev-label').forEach(x => show(x, l, 300)); }],
        [1300, l => show($(el(), '.link.dev'), l)],
        [2300, l => { const t = $(el(), '.t-dev'); if (l) { t.classList.add('back'); go(t, l); } }],
        [4300, l => { hide($(el(), '.bubble.wait')); show($(el(), '.bubble.a'), l); stream($(el(), '.bubble.a .stream'), l); }],
        [6600, l => show($(el(), '.bubble.a .src'), l)],
        [7600, l => show($(el(), '.moral'), l)],
      ],
    ],
    reset(el) { el.classList.remove('b1'); $$(el, '.travel').forEach(t => t.classList.remove('go', 'back')); },
  };

  S.arch = {
    beats: [
      [
        [0, l => $$(el(), '.kicker, .title, .subtitle').forEach(x => show(x, l))],
        [1200, l => { show($(el(), '.bound'), l); show($(el(), '.bound-label'), l, 700); }],
        [2600, l => show($(el(), '.flbar'), l)],
        [3800, l => { $$(el(), '.core').forEach(x => show(x, l)); pulse($(el(), '.core-ring'), l, 200); }],
        ...[0, 1, 2, 3].flatMap(i => [
          [5200 + i * 1600, l => show($(el(), `.f${i}`), l)],
          [5650 + i * 1600, l => { show($(el(), `.t${i}`), l); pulse($(el(), `.r${i}`), l); }],
        ]),
        [7700, l => show($(el(), '.t1b'), l)],
        [12000, () => el().classList.add('alive')],
        [12000, l => show($(el(), '.foot'), l)],
      ],
      [
        [0, l => show($(el(), '.cloud-card'), l)],
        [1100, l => { show($(el(), '.export'), l); $$(el(), '.export-label').forEach(x => show(x, l, 600)); }],
        [2400, l => go($(el(), '.onnx-chip'), l)],
        [3800, l => { const t = $(el(), '.t3'); if (l) { t.classList.remove('hit'); void t.getBoundingClientRect(); t.classList.add('hit'); } pulse($(el(), '.r3'), l); }],
        [5400, l => { el().classList.add('gone'); show($(el(), '.gone-note'), l); }],
      ],
    ],
    reset(el) { el.classList.remove('alive', 'gone'); $(el, '.onnx-chip').classList.remove('go'); $(el, '.t3').classList.remove('hit'); },
  };

  S.bench = {
    init(el) {
      $(el, '.lanes').innerHTML = T.bench.map((m, i) => `
        <div class="lane k-rise" data-i="${i}" style="top:${232 + i * 128}px">
          <div class="frame k-fade"></div>${m.chosen ? '<span class="chosen k-pop">chosen</span>' : ''}
          <p class="name">${m.name}</p><p class="meta">${m.meta}</p>
          <div class="track"></div><div class="bar k-growx ${m.tps < 10 ? 'slow' : ''}" style="width:${(m.tps / 30 * 300).toFixed(0)}px"></div>
          <p class="tps k-fade"><b class="n">0</b>tok/s · first token ${m.ft.toFixed(2)} s</p>
          ${m.fastest ? '<span class="fast k-pop">fastest</span>' : ''}
          ${m.tools === null ? `<span class="stamp k-drop">${m.error}</span>` :
            `<div class="dots">${Array.from({ length: 8 }, (_, j) => `<span class="dot k-pop ${j < m.tools ? 'ok' : 'no'}"></span>`).join('')}</div>
             <p class="tools-n k-fade"><b>${m.tools}/8</b>right tool</p>`}
          <p class="qual k-land">${m.quality}/13<small>right facts</small></p>
        </div>`).join('');
    },
    beats: [
      [
        [0, l => $$(el(), '.kicker, .title, .subtitle').forEach(x => show(x, l))],
        [1000, l => show($(el(), '.c-speed'), l)],
        ...[0, 1, 2].map(i => [1400 + i * 300, l => show($(el(), `.lane[data-i="${i}"]`), l)]),
        [3200, l => $$(el(), '.lane').forEach((ln, i) => {
          show($(ln, '.bar'), l, i * 120); show($(ln, '.tps'), l, i * 120);
          count($(ln, '.tps .n'), T.bench[i].tps, l, 1400, 1);
        })],
        [5200, l => show($(el(), '.fast'), l)],
        [5200, l => show($(el(), '.foot'), l)],
      ],
      [
        [0, l => show($(el(), '.c-tools'), l)],
        [600, l => $$(el(), '.lane[data-i="0"] .dot').forEach((d, j) => show(d, l, j * 110))],
        [1800, l => show($(el(), '.stamp'), l)],
        [2600, l => $$(el(), '.lane[data-i="2"] .dot').forEach((d, j) => show(d, l, j * 110))],
        [3800, l => $$(el(), '.tools-n').forEach((x, i) => show(x, l, i * 150))],
      ],
      [
        [0, l => show($(el(), '.c-qual'), l)],
        [400, l => $$(el(), '.qual').forEach((x, i) => show(x, l, i * 300))],
        [2400, () => el().classList.add('b2')],
        [3000, l => { show($(el(), '.lane[data-i="0"] .frame'), l); show($(el(), '.chosen'), l, 300); }],
        [4300, l => show($(el(), '.moral'), l)],
      ],
    ],
    reset(el) { el.classList.remove('b2'); $$(el, '.tps .n').forEach(n => n.textContent = '0'); },
  };

  // The router: 23 dots in four columns, the scan of light flips the four misses.
  const COLX = [150, 340, 530, 720], ROW0 = 268, ROWH = 40;
  S.router = {
    init(el) {
      const H = T.holdout, grid = $(el, '.grid');
      let html = '', order = 0;
      H.columns.forEach((c, ci) => {
        html += `<div class="col k-rise" style="left:${COLX[ci] - 75}px" data-c="${ci}"><p class="h">${c.label}</p><p class="n">${c.n} requests</p></div>`;
        for (let r = 0; r < c.n; r++) {
          const miss = H.misses.find(m => m.col === c.key && m.row === r);
          html += `<div class="rd k-pop ${miss ? 'no flip' : 'ok'}" data-o="${order++}" ${miss ? `data-miss="${miss.id}"` : ''} style="left:${COLX[ci]}px;top:${ROW0 + r * ROWH}px">${miss ? `<span class="tag">${miss.id}</span>` : ''}</div>`;
        }
      });
      grid.innerHTML = html;
      $(el, '.misses').innerHTML = H.misses.map(m => `<div class="miss k-rise" data-id="${m.id}"><span class="id">${m.id}</span><span>“${m.text}”<span class="got">went to machine status</span></span></div>`).join('');
    },
    beats: [
      [
        [0, l => $$(el(), '.kicker, .title, .subtitle').forEach(x => show(x, l))],
        [1000, l => $$(el(), '.col').forEach((c, i) => show(c, l, i * 150))],
        [1500, l => show($(el(), '.score'), l)],
        [2400, l => $$(el(), '.rd').forEach((d, i) => show(d, l, i * 130))],
        // the counter follows the dots as they land; each step sets the count so far, so a click can skip ahead safely
        ...Array.from({ length: 23 }, (_, i) => [2650 + i * 130, () => {
          $(el(), '.cnt').textContent = String($$(el(), '.rd').slice(0, i + 1).filter(d => !d.dataset.miss).length);
        }]),
        [6200, l => $$(el(), '.miss').forEach((m, i) => show(m, l, i * 280))],
        [7600, l => show($(el(), '.foot'), l)],
      ],
      [
        [0, l => show($(el(), '.scanbar'), l)],
        // the bar moves 760 px in 1800 ms from x = 60; each miss flips as the light reaches its column
        ...T.holdout.misses.map((m, k) => {
          const x = COLX[T.holdout.columns.findIndex(c => c.key === m.col)];
          return [Math.round((x - 60) / 760 * 1800) + k % 2 * 120, l => {
            const d = $$(el(), '.rd[data-miss]')[k];
            d.classList.replace('no', 'ok'); $(d, '.tag').textContent = `${d.dataset.miss} ✓`; go(d, l, 'flipping');
            $(el(), '.cnt').textContent = String(T.holdout.without.correct + k + 1);
          }];
        }),
        [2000, () => {
          $(el(), '.big').classList.add('win'); $(el(), '.cnt').textContent = String(T.holdout.with.correct);
          $(el(), '.secs').innerHTML = `<b>${T.holdout.with.seconds} s</b> with the router, ${T.holdout.without.seconds} s without`;
        }],
        [2600, () => { el().classList.add('b1'); $$(el(), '.miss .got').forEach((g, i) => { g.textContent = `now: ${T.holdout.misses[i].want}`; }); }],
        [3400, l => show($(el(), '.how'), l)],
      ],
    ],
    reset(el) {
      el.classList.remove('b1');
      $$(el, '.rd').forEach(d => { d.classList.remove('flipping'); if (d.dataset.miss) { d.classList.replace('ok', 'no'); $(d, '.tag').textContent = d.dataset.miss; } });
      $(el, '.cnt').textContent = '0'; $(el, '.big').classList.remove('win');
      $(el, '.secs').textContent = '778 s for the set, all four tools shown';
      $$(el, '.miss .got').forEach(g => g.textContent = 'went to machine status');
    },
  };

  // Beams from each citation chip to its section of the procedure, measured in slide coordinates.
  const layoutBeams = sec => {
    const r0 = sec.getBoundingClientRect(), k = r0.width / 1280;
    if (!k) return;
    const pt = (e, side) => { const r = e.getBoundingClientRect(); return [((side === 'r' ? r.right : r.left) - r0.left) / k, (r.top + r.height / 2 - r0.top) / k]; };
    $$(sec, '.chip').forEach((c, i) => {
      const s = $(sec, `.doc .s${c.dataset.sec}`), beam = $(sec, `.beam.b${i}`);
      if (!s || !beam) return;
      const [x1, y1] = pt(c, 'r'), [x2] = pt(s, 'l'), r = s.getBoundingClientRect();
      const y2 = (r.top + Math.min(r.height / 2, 16) - r0.top) / k;
      beam.setAttribute('d', `M${x1.toFixed(1)} ${y1.toFixed(1)} C${(x1 + 90).toFixed(1)} ${y1.toFixed(1)} ${(x2 - 90).toFixed(1)} ${y2.toFixed(1)} ${(x2 + 2).toFixed(1)} ${y2.toFixed(1)}`);
    });
  };
  S.sop = {
    init(el) { $$(el, '.stream').forEach(prepStream); },
    beats: [
      [
        [0, l => $$(el(), '.kicker, .title, .subtitle').forEach(x => show(x, l))],
        [900, l => show($(el(), '.chat'), l)],
        [1600, l => stream($(el(), '.s-q'), l)],
        [3600, l => show($(el(), '.doc'), l)],
        [4800, l => stream($(el(), '.s-a'), l)],
        [7000, l => $$(el(), '.chip').forEach(c => show(c, l))],
        [8000, l => { layoutBeams(el()); $$(el(), '.beam').forEach(b => show(b, l)); }],
        ...[0, 1, 2].map(i => [8700 + i * 200, () => $(el(), `.doc .s${i}`).classList.add('lit')]),
      ],
      [
        [0, l => $$(el(), '.score .ch').forEach((x, i) => show(x, l, i * 80))],
        [600, l => $$(el(), '.score .rh').forEach((x, i) => show(x, l, i * 500))],
        [900, l => $$(el(), '.score .v').forEach((x, i) => show(x, l, (i < 4 ? 0 : 900) + (i % 4) * 160))],
      ],
    ],
    reset(el) { $$(el, '.doc .sec').forEach(s => s.classList.remove('lit')); },
  };

  S.onnx = {
    init(el) {
      const h = T.onnx.sha256.split('').map(c => `<span class="c">${c}</span>`).join('');
      $(el, '.h-cl').innerHTML = h; $(el, '.h-ed').innerHTML = h;
      $(el, '.h-cl').classList.add('k-fade'); $(el, '.h-ed').classList.add('k-fade');
      $(el, '.pred tbody').innerHTML = T.onnx.predictions.map(p => `<tr class="k-rise"><td>${p[0]}</td><td class="f">${p[1]}</td><td>${p[2]}</td><td class="ms">${p[3]}</td></tr>`).join('');
    },
    beats: [
      [
        [0, l => $$(el(), '.kicker, .title, .subtitle').forEach(x => show(x, l))],
        [900, l => $$(el(), '.side').forEach(x => show(x, l))],
        [2400, l => show($(el(), '.arcpath'), l)],
        [3400, l => go($(el(), '.onnx-chip'), l)],
        [5100, l => { show($(el(), '.h-cl'), l); show($(el(), '.h-ed'), l, 200); }],
        // the two fingerprints are compared character by character
        ...Array.from({ length: 64 }, (_, i) => [6300 + i * 24, () => { $$(el(), '.h-cl .c')[i].classList.add('m'); $$(el(), '.h-ed .c')[i].classList.add('m'); }]),
        [8100, l => { $(el(), '.arcpath').classList.add('same'); show($(el(), '.eq'), l); }],
      ],
      [
        [0, l => show($(el(), '.acc'), l)],
        [900, l => $$(el(), '.pred tr').forEach((r, i) => show(r, l, i * 260))],
        [2700, l => show($(el(), '.lat'), l)],
        [3300, l => show($(el(), '.foot'), l)],
      ],
    ],
    reset(el) { $$(el, '.hash .c').forEach(c => c.classList.remove('m')); $(el, '.arcpath').classList.remove('same'); $(el, '.onnx-chip').classList.remove('go'); },
  };

  S.pull = {
    init(el) {
      const port = edgeBox($(el, '.edge'), 780, 190, 1, [1090, 780], false);
      $(el, '.edge').classList.add('k-bloom');
      const sparks = Array.from({ length: 9 }, (_, i) => { const a = (i / 9) * Math.PI * 2, r1 = 10, r2 = 34 + (i % 3) * 10; return `<line class="spark" x1="${(port[0] + Math.cos(a) * r1).toFixed(1)}" y1="${(port[1] + Math.sin(a) * r1).toFixed(1)}" x2="${(port[0] + Math.cos(a) * r2).toFixed(1)}" y2="${(port[1] + Math.sin(a) * r2).toFixed(1)}" style="transform-origin:${port[0].toFixed(1)}px ${port[1].toFixed(1)}px;--d:${i * 25}ms"/>`; }).join('');
      $(el, '.edge').insertAdjacentHTML('beforeend', sparks);
      $(el, '.regions').innerHTML = T.offline.regions.map((r, i) => `<g class="k-rise rg" data-i="${i}"><circle class="region-dot" cx="1018" cy="${228 + i * 30}" r="4"/><text class="region" x="1032" y="${233 + i * 30}">${r}</text></g>`).join('');
      const rows = [...T.offline.checks, T.offline.restart];
      $(el, '.checks').innerHTML = rows.map((c, i) => `<div class="row k-rise ${i === 5 ? 'r-restart' : ''}" data-i="${i}"><span class="lamp"></span><span class="rn">${c[0]}<span class="rs">${c[1]}</span></span><span class="rt">${c[2]}</span></div>`).join('');
    },
    beats: [
      [
        [0, l => $$(el(), '.kicker, .title, .subtitle').forEach(x => show(x, l))],
        [800, l => show($(el(), '.edge'), l)],
        [1800, l => { show($(el(), '.inet-h'), l); $$(el(), '.rg').forEach((g, i) => show(g, l, i * 90)); }],
        [2800, l => $$(el(), '.row:not(.r-restart)').forEach((r, i) => { r.classList.add('ok'); show(r, l, i * 150); })],
        [4000, l => show($(el(), '.verdict'), l)],
      ],
      [
        [0, l => { el().classList.add('unplugged'); $$(el(), '.spark').forEach(s => pulse(s, l)); }],
        ...T.offline.regions.map((_, i) => [900 + i * 160, () => $$(el(), `.rg[data-i="${i}"] .region, .rg[data-i="${i}"] .region-dot`).forEach(x => x.classList.add('down'))]),
        [2500, l => show($(el(), '.err'), l)],
        [3500, () => { $(el(), '.inet').textContent = 'not reachable (offline)'; $(el(), '.inet').classList.add('red'); }],
        [4300, () => $$(el(), '.row:not(.r-restart)').forEach(r => { r.classList.remove('ok'); r.classList.add('chk'); })],
        ...[0, 1, 2, 3, 4].map(i => [5600 + i * 1300, () => { const r = $(el(), `.row[data-i="${i}"]`); r.classList.replace('chk', 'ok'); $(r, '.rt').classList.add('shown'); }]),
        [12400, () => { $(el(), '.inet').innerHTML = 'not reachable (offline) · <span class="green">every answer came from the device</span>'; }],
      ],
      [
        [0, () => { el().classList.add('power-off'); $$(el(), '.row:not(.r-restart)').forEach(r => { r.classList.remove('ok'); r.classList.add('off'); $(r, '.rt').classList.remove('shown'); }); }],
        [1800, l => { el().classList.remove('power-off'); const r = $(el(), '.r-restart'); r.classList.add('chk'); show(r, l); }],
        [3600, () => { const r = $(el(), '.r-restart'); r.classList.replace('chk', 'ok'); $(r, '.rt').classList.add('shown'); }],
        ...[0, 1, 2, 3, 4].map(i => [4300 + i * 260, () => {
          const r = $(el(), `.row[data-i="${i}"]`), c = T.offline.checks[i];
          r.classList.remove('off'); r.classList.add('ok'); $(r, '.rs').textContent = c[3]; $(r, '.rt').textContent = c[4]; $(r, '.rt').classList.add('shown');
        }]),
        [6000, l => { el().classList.add('green'); show($(el(), '.hero'), l); }],
      ],
    ],
    reset(el) {
      el.classList.remove('unplugged', 'power-off', 'green');
      $$(el, '.down').forEach(x => x.classList.remove('down'));
      $(el, '.inet').textContent = 'reachable'; $(el, '.inet').classList.remove('red');
      $$(el, '.row').forEach((r, i) => {
        r.classList.remove('ok', 'chk', 'off'); $(r, '.rt').classList.remove('shown');
        const c = i < 5 ? T.offline.checks[i] : T.offline.restart; $(r, '.rs').textContent = c[1]; $(r, '.rt').textContent = c[2];
      });
    },
  };

  S.closing = {
    beats: [[
      [0, l => $$(el(), K).forEach(x => show(x, l))],
      [2600, () => el().classList.add('cut')],
    ]],
    reset(el) { el.classList.remove('cut'); },
  };

  S.thanks = { beats: [[]] };

  // ------------------------------------------------------------------ the engine
  let current = null;              // the section the clock belongs to
  const el = () => current;
  const sceneOf = sec => S[sec.dataset.scene];
  const markers = sec => $$(sec, ':scope > .fragment.beat');
  const shownBeats = sec => markers(sec).filter(m => m.classList.contains('visible')).length;
  const lastBeat = sec => sceneOf(sec).beats.length - 1;

  const clock = {
    steps: [], handles: [], t0: 0, elapsed: 0, running: false,
    start(steps) { this.stop(); this.steps = steps.map(([at, fn]) => ({ at, fn, done: false })); this.elapsed = 0; this.resume(); },
    resume() {
      this.running = true; this.t0 = performance.now() - this.elapsed;
      for (const s of this.steps) if (!s.done) this.handles.push(setTimeout(() => { s.done = true; s.fn(true); this.check(); }, Math.max(0, s.at - this.elapsed)));
      this.check();
    },
    pause() { if (!this.running) return; this.elapsed = performance.now() - this.t0; this.clear(); this.running = false; },
    stop() { this.clear(); this.running = false; this.steps = []; this.elapsed = 0; },
    clear() { this.handles.forEach(clearTimeout); this.handles = []; },
    flush() { this.clear(); for (const s of this.steps) if (!s.done) { s.done = true; s.fn(false); } this.running = false; },
    pending() { return this.steps.some(s => !s.done); },
    check() { if (!this.pending()) this.running = false; ui(); },
  };

  function resetScene(sec) {
    $$(sec, '.on, .enter').forEach(x => x.classList.remove('on', 'enter'));
    const sc = sceneOf(sec); if (sc.reset) sc.reset(sec);
  }

  // Show a resting point at once: beats 0..n, nothing animates.
  function settle(sec, n) {
    if (sec === current) clock.stop();
    const prev = current; current = sec;
    resetScene(sec);
    sceneOf(sec).beats.slice(0, n + 1).forEach(b => b.forEach(([, fn]) => fn(false)));
    sec.dataset.beat = String(n);
    current = prev === null ? sec : prev;
    if (sec === Reveal.getCurrentSlide()) current = sec;
    ui();
  }

  function play(sec, n) {
    current = sec; sec.dataset.beat = String(n);
    sec.classList.remove('motion-paused');
    clock.start(sceneOf(sec).beats[n]);
  }

  function enter(sec) {
    clock.stop(); current = sec;
    if (!sec.dataset.scene) return ui();
    sec.classList.toggle('static', still());
    const c = shownBeats(sec);
    if (still()) { settle(sec, c); return; }
    if (c === 0) { resetScene(sec); play(sec, 0); } else settle(sec, c);
    syncPause();
  }

  function replay(sec) {
    const n = shownBeats(sec);
    resetScene(sec); current = sec; sec.dataset.beat = String(n);
    // replay from the start up to the current resting point, beat after beat
    let offset = 0; const steps = [];
    sceneOf(sec).beats.slice(0, n + 1).forEach((b, i) => {
      b.forEach(([at, fn]) => steps.push([offset + at, fn]));
      offset += Math.max(0, ...b.map(([at]) => at)) + (i < n ? 1500 : 0);
    });
    sec.classList.remove('motion-paused');
    clock.start(steps);
  }

  let jumping = false;
  function showAll(sec) {
    const ms = markers(sec), last = ms.length;
    if (shownBeats(sec) < last) { const { h, v } = Reveal.getIndices(sec); jumping = true; Reveal.slide(h, v, last - 1); jumping = false; }
    settle(sec, lastBeat(sec));
  }

  function ui() {
    const sec = current; if (!sec || !sec.dataset.scene) return;
    const ctl = $(sec, '.ctl'); if (!ctl) return;
    const paused = !clock.running && clock.pending();
    $(ctl, '[data-a="pause"]').textContent = paused ? 'Resume' : 'Pause';
    $(ctl, '[data-a="pause"]').disabled = !clock.pending() || still();
    $(ctl, '[data-a="replay"]').disabled = still();
    $(ctl, '[data-a="all"]').disabled = +sec.dataset.beat >= lastBeat(sec) && !clock.pending();
    sec.classList.toggle('waiting', !clock.pending() && +sec.dataset.beat < lastBeat(sec) && !still());
  }

  // The deck, the tab or the Pause button can hold the scene.
  let userPaused = false;
  function syncPause() {
    const sec = current; if (!sec) return;
    const hold = userPaused || document.hidden || (Reveal.isReady() && (Reveal.isPaused() || Reveal.isOverview()));
    if (hold && clock.running) clock.pause();
    else if (!hold && !clock.running && clock.pending()) clock.resume();
    sec.classList.toggle('motion-paused', hold);
    ui();
  }

  // Controls on every built slide.
  $$(document, '.reveal .slides > section[data-scene]').forEach(sec => {
    const sc = sceneOf(sec);
    // invisible markers must match the beats
    if (markers(sec).length !== sc.beats.length - 1) console.warn('beat markers do not match', sec.dataset.scene);
    if (sec.hasAttribute('data-noctl') || printing) return;
    sec.insertAdjacentHTML('beforeend', `<div class="ctl" role="group" aria-label="Animation controls"><span class="cue">Click to continue</span><button type="button" data-a="pause">Pause</button><button type="button" data-a="replay">Replay</button><button type="button" data-a="all">Show all</button></div>`);
    const ctl = $(sec, '.ctl');
    ctl.addEventListener('keydown', e => { if (e.key === ' ' || e.key === 'Enter') e.stopPropagation(); });
    ctl.addEventListener('click', e => {
      const a = e.target.closest('button'); if (!a) return; e.stopPropagation();
      if (a.dataset.a === 'pause') { userPaused = clock.running; if (!userPaused && clock.pending()) userPaused = false; syncPause(); }
      if (a.dataset.a === 'replay') { userPaused = false; replay(sec); syncPause(); }
      if (a.dataset.a === 'all') { userPaused = false; clock.stop(); showAll(sec); sec.classList.remove('motion-paused'); }
      a.blur();
    });
  });

  // Scene setup.
  $$(document, '.reveal .slides > section[data-scene]').forEach(sec => { const sc = sceneOf(sec); if (sc.init) sc.init(sec); });

  Reveal.initialize({
    width: 1280, height: 720, margin: 0, center: false,
    controls: true, progress: true, slideNumber: false, hash: true,
    transition: 'fade', backgroundTransition: 'fade',
    pdfSeparateFragments: false,
    plugins: [RevealNotes],
  });

  Reveal.on('ready', () => {
    if (printing) $$(document, '.reveal .slides > section[data-scene]').forEach(s => { s.classList.add('static'); current = s; settle(s, lastBeat(s)); });
    enter(Reveal.getCurrentSlide());
  });
  Reveal.on('slidechanged', ({ currentSlide }) => { userPaused = false; enter(currentSlide); });
  Reveal.on('fragmentshown', e => {
    const f = e.fragment, sec = f && f.closest('section');
    if (jumping || !f.classList.contains('beat') || sec !== Reveal.getCurrentSlide()) return;
    const n = markers(sec).indexOf(f) + 1;
    if (still()) { settle(sec, n); return; }
    clock.flush();              // a click finishes whatever was still building, then the next beat plays
    userPaused = false; play(sec, n); syncPause();
  });
  Reveal.on('fragmenthidden', e => {
    const f = e.fragment, sec = f && f.closest('section');
    if (jumping || !f.classList.contains('beat')) return;
    settle(sec, markers(sec).indexOf(f));
  });
  Reveal.on('overviewshown', () => { clock.stop(); $$(document, '.reveal .slides > section[data-scene]').forEach(s => settle(s, lastBeat(s))); });
  Reveal.on('overviewhidden', () => enter(Reveal.getCurrentSlide()));
  Reveal.on('paused', syncPause);
  Reveal.on('resumed', syncPause);
  document.addEventListener('visibilitychange', syncPause);
  reduced.addEventListener('change', () => enter(Reveal.getCurrentSlide()));
  window.addEventListener('beforeprint', () => $$(document, '.reveal .slides > section[data-scene]').forEach(s => settle(s, lastBeat(s))));
  window.TalkDeck = { settle, replay, showAll, clock, busy: () => clock.pending() };
})();
