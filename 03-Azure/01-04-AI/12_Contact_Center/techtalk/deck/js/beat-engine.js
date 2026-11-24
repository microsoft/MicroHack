/* Beat engine for Reveal.js talks. Proven in the "Pull the cable" deck (MicroHack Offline Industrial Copilot).

   Load order: reveal.js, plugin/notes.js, your scenes file (window.SCENES = {...}), this file, then
   startDeck({ ...Reveal options }). Use with assets/motion.css.

   Contract
   - A built slide is <section data-scene="name"> with one <span class="fragment beat"></span> per click
     beat, so beats.length - 1 markers. data-noctl hides the controls (cover, chapters, closing).
   - window.SCENES[name] = { init(sec)?, reset(sec)?, beats: [ [ [ms, fn(live)], ... ], ... ] }
     Beat 0 plays on arrival; each click plays the next beat; then the slide waits with a cue.
   - Steps change state only through Beat.show/hide/pulse/go or classes on Beat.el(). Every step must be
     idempotent and set absolute state (count = n, not count += 1): a click mid-beat, a step back,
     Show all, print and the overview run the remaining steps at once with live = false.
   - Never call setTimeout or setInterval inside a step: add another step, so Pause, Replay and slide
     changes control it. Use many small steps (one per dot, character or row) for staggers that matter.
   - Elements with a k-* class stay hidden until Beat.show gives them .on. They animate only when they
     arrive live (.enter), so settled states never replay.
*/
(() => {
  const $ = (r, s) => r.querySelector(s);
  const $$ = (r, s) => [...r.querySelectorAll(s)];
  const params = new URLSearchParams(location.search);
  const printing = params.has('print-pdf') || params.has('export');
  const reduced = matchMedia('(prefers-reduced-motion: reduce)');
  const still = () => printing || reduced.matches || params.has('static');

  // ------------------------------------------------------------------ helpers for scenes
  const restart = (e, cls) => { e.classList.remove(cls); void e.getBoundingClientRect(); e.classList.add(cls); };
  const show = (e, live, d) => {
    if (!e) return;
    e.classList.add('on');
    if (live) { if (d !== undefined) e.style.setProperty('--d', `${d}ms`); restart(e, 'enter'); }
  };
  const hide = e => e && e.classList.remove('on', 'enter');
  const pulse = (e, live, d) => { if (!e || !live) return; if (d !== undefined) e.style.setProperty('--d', `${d}ms`); restart(e, 'enter'); };
  const go = (e, live, cls = 'go') => { if (e && live) restart(e, cls); };
  // Never use [class*="k-"]: it also matches classes such as "link-last".
  const K = ':is([class^="k-"], [class*=" k-"])';

  // Words that stream in like tokens. Returns the duration.
  const prepStream = e => { if (e.dataset.ready) return; e.innerHTML = e.dataset.text.split(' ').map(w => `<span class="w k-tok">${w}</span>`).join(' '); e.dataset.ready = '1'; };
  const stream = (e, live, perWord = 55) => { prepStream(e); $$(e, '.w').forEach((w, i) => show(w, live, i * perWord)); return e.dataset.text.split(' ').length * perWord; };

  // A number that counts up live, is exact when settled, and holds while the slide is paused.
  const count = (e, to, live, ms = 1400, dec = 0) => {
    const fmt = v => v.toFixed(dec);
    if (!live) { e.textContent = fmt(to); return; }
    const sec = e.closest('section'); let t0 = null, held = 0, last = 0;
    const tick = now => {
      if (t0 === null) { t0 = now; last = now; }
      if (sec.classList.contains('motion-paused')) held += now - last;
      last = now;
      const p = Math.min(1, (now - t0 - held) / ms);
      e.textContent = fmt(to * (1 - Math.pow(1 - p, 3)));
      if (p < 1 && sec.classList.contains('present')) requestAnimationFrame(tick); else e.textContent = fmt(to);
    };
    requestAnimationFrame(tick);
  };

  // ------------------------------------------------------------------ engine
  const S = () => window.SCENES || {};
  let current = null;
  const el = () => current;
  const sceneOf = sec => S()[sec.dataset.scene];
  const markers = sec => $$(sec, ':scope > .fragment.beat');
  const shownBeats = sec => markers(sec).filter(m => m.classList.contains('visible')).length;
  const lastBeat = sec => sceneOf(sec).beats.length - 1;
  const sections = () => $$(document, '.reveal .slides > section[data-scene]');

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

  // A resting point at once: beats 0..n, nothing animates.
  function settle(sec, n) {
    if (sec === current) clock.stop();
    const prev = current; current = sec;
    resetScene(sec);
    sceneOf(sec).beats.slice(0, n + 1).forEach(b => b.forEach(([, fn]) => fn(false)));
    sec.dataset.beat = String(n);
    current = sec === Reveal.getCurrentSlide() || prev === null ? sec : prev;
    ui();
  }

  function play(sec, n) {
    current = sec; sec.dataset.beat = String(n);
    sec.classList.remove('motion-paused');
    clock.start(sceneOf(sec).beats[n]);
  }

  function enter(sec) {
    clock.stop(); current = sec;
    if (!sec.dataset.scene || !sceneOf(sec)) return ui();
    sec.classList.toggle('static', still());
    const c = shownBeats(sec);
    if (still()) { settle(sec, c); return; }
    if (c === 0) { resetScene(sec); play(sec, 0); } else settle(sec, c);
    syncPause();
  }

  // Replay from the start up to the current resting point, beat after beat.
  function replay(sec) {
    const n = shownBeats(sec);
    resetScene(sec); current = sec; sec.dataset.beat = String(n);
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
    const last = markers(sec).length;
    if (shownBeats(sec) < last) { const { h, v } = Reveal.getIndices(sec); jumping = true; Reveal.slide(h, v, last - 1); jumping = false; }
    settle(sec, lastBeat(sec));
  }

  function ui() {
    const sec = current; if (!sec || !sec.dataset.scene || !sceneOf(sec)) return;
    sec.classList.toggle('waiting', !clock.pending() && +sec.dataset.beat < lastBeat(sec) && !still());
    const ctl = $(sec, '.ctl'); if (!ctl) return;
    const paused = !clock.running && clock.pending();
    $(ctl, '[data-a="pause"]').textContent = paused ? 'Resume' : 'Pause';
    $(ctl, '[data-a="pause"]').disabled = !clock.pending() || still();
    $(ctl, '[data-a="replay"]').disabled = still();
    $(ctl, '[data-a="all"]').disabled = +sec.dataset.beat >= lastBeat(sec) && !clock.pending();
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

  function startDeck(options = {}) {
    sections().forEach(sec => {
      const sc = sceneOf(sec);
      if (!sc) { console.error('no scene for', sec.dataset.scene); return; }
      if (markers(sec).length !== sc.beats.length - 1) console.error(`beat markers do not match beats: ${sec.dataset.scene}`);
      if (sec.hasAttribute('data-noctl') || printing) return;
      sec.insertAdjacentHTML('beforeend', '<div class="ctl" role="group" aria-label="Animation controls"><span class="cue">Click to continue</span><button type="button" data-a="pause">Pause</button><button type="button" data-a="replay">Replay</button><button type="button" data-a="all">Show all</button></div>');
      const ctl = $(sec, '.ctl');
      ctl.addEventListener('keydown', e => { if (e.key === ' ' || e.key === 'Enter') e.stopPropagation(); });
      ctl.addEventListener('click', e => {
        const a = e.target.closest('button'); if (!a) return; e.stopPropagation();
        if (a.dataset.a === 'pause') { userPaused = clock.running; syncPause(); }
        if (a.dataset.a === 'replay') { userPaused = false; replay(sec); syncPause(); }
        if (a.dataset.a === 'all') { userPaused = false; clock.stop(); showAll(sec); sec.classList.remove('motion-paused'); }
        a.blur();
      });
    });
    sections().forEach(sec => { const sc = sceneOf(sec); if (sc && sc.init) sc.init(sec); });

    Reveal.initialize(Object.assign({
      width: 1280, height: 720, margin: 0, center: false,
      controls: true, progress: true, slideNumber: false, hash: true,
      transition: 'fade', backgroundTransition: 'fade', pdfSeparateFragments: false,
      plugins: window.RevealNotes ? [RevealNotes] : [],
    }, options));

    Reveal.on('ready', () => {
      if (printing) sections().forEach(s => { if (!sceneOf(s)) return; s.classList.add('static'); current = s; settle(s, lastBeat(s)); });
      enter(Reveal.getCurrentSlide());
    });
    Reveal.on('slidechanged', ({ currentSlide }) => { userPaused = false; enter(currentSlide); });
    Reveal.on('fragmentshown', e => {
      const f = e.fragment, sec = f && f.closest('section');
      if (jumping || !f.classList.contains('beat') || sec !== Reveal.getCurrentSlide()) return;
      const n = markers(sec).indexOf(f) + 1;
      if (still()) { settle(sec, n); return; }
      clock.flush();            // a click finishes whatever was still building, then the next beat plays
      userPaused = false; play(sec, n); syncPause();
    });
    Reveal.on('fragmenthidden', e => {
      const f = e.fragment, sec = f && f.closest('section');
      if (jumping || !f.classList.contains('beat')) return;
      settle(sec, markers(sec).indexOf(f));
    });
    Reveal.on('overviewshown', () => { clock.stop(); sections().forEach(s => sceneOf(s) && settle(s, lastBeat(s))); });
    Reveal.on('overviewhidden', () => enter(Reveal.getCurrentSlide()));
    Reveal.on('paused', syncPause);
    Reveal.on('resumed', syncPause);
    document.addEventListener('visibilitychange', syncPause);
    reduced.addEventListener('change', () => enter(Reveal.getCurrentSlide()));
    window.addEventListener('beforeprint', () => sections().forEach(s => sceneOf(s) && settle(s, lastBeat(s))));
  }

  // Helpers for scene files, and a small API for scripts/walk-deck.js and scripts/check-behaviour.js.
  window.Beat = { $, $$, el, show, hide, pulse, go, K, stream, prepStream, count };
  window.TalkDeck = { settle, replay, showAll, clock, busy: () => clock.pending() };
  window.startDeck = startDeck;
})();
