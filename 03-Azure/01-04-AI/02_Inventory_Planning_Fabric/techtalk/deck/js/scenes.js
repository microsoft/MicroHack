/* Ask the shelf: the scenes. The beat engine (beat-engine.js) runs them.
   Each scene: beats of [ms, fn(live)] steps. Steps set absolute state and never start their own timers.
   The shelf of boxes is built by the same helpers on every slide where it appears. */
(() => {
  const T = window.TALK;
  const q = s => Beat.$(Beat.el(), s);
  const qa = s => Beat.$$(Beat.el(), s);
  const head = l => qa('.kicker, .title, .subtitle').forEach(x => Beat.show(x, l));
  const money = v => '$' + Math.round(v).toLocaleString('en-US');

  // A money value that counts between two amounts live, exact when settled, and holds while paused.
  const countMoney = (e, from, to, live, ms = 1300) => {
    if (!live) { e.textContent = money(to); return; }
    const sec = e.closest('section'); let t0 = null, held = 0, last = 0;
    const tick = now => {
      if (t0 === null) { t0 = now; last = now; }
      if (sec.classList.contains('motion-paused')) held += now - last;
      last = now;
      const p = Math.min(1, (now - t0 - held) / ms);
      e.textContent = money(from + (to - from) * (1 - Math.pow(1 - p, 3)));
      if (p < 1 && sec.classList.contains('present')) requestAnimationFrame(tick); else e.textContent = money(to);
    };
    requestAnimationFrame(tick);
  };

  // n boxes in a row, sitting with their bottom on y. Returns HTML.
  const row = (n, x0, y, w, h, step, cls = '', from = 0) =>
    Array.from({ length: n }, (_, i) => `<span class="bx k-pop ${cls}" data-i="${from + i}" style="left:${x0 + i * step}px;top:${y - h}px;width:${w}px;height:${h}px"></span>`).join('');

  window.SCENES = {
    // ---------------------------------------------------------------- 1 cover: 30 boxes drain to 6
    cover: {
      init(sec) {
        // bottom board first, so boxes 0 to 5 (the six that stay) sit on the bottom left
        const boards = [378, 248, 118];
        let html = '';
        boards.forEach((b, k) => { for (let i = 0; i < 10; i++) html += `<span class="slot k-fade" style="left:${14 + i * 39}px;top:${b - 48}px;width:34px;height:46px"></span>`; });
        boards.forEach((b, k) => { html += row(10, 14, b - 2, 34, 46, 39, '', k * 10); });
        Beat.$(sec, '.cv-boxes').innerHTML = html;
      },
      beats: [[
        [0, l => Beat.show(q('.mast'), l)],
        [0, l => qa('.cv-title, .cv-sub, .byline').forEach(x => Beat.show(x, l))],
        [600, l => qa('.upright, .board').forEach(x => Beat.show(x, l))],
        [700, l => qa('.cv-boxes .slot').forEach(x => Beat.show(x, l))],
        ...Array.from({ length: 30 }, (_, i) => [1100 + i * 45, l => Beat.show(qa('.cv-boxes .bx')[i], l)]),
        [2600, l => Beat.show(q('.cv-tag'), l)],
        // the stock drains, top shelf first, until six are left
        ...Array.from({ length: 24 }, (_, k) => [4200 + k * 140, () => {
          const i = 29 - k;
          qa('.cv-boxes .bx')[i].classList.add('gone');
          q('.cv-n').textContent = String(i);
        }]),
        [7700, () => q('.cv-tag').classList.add('low')],
      ]],
      reset(sec) { Beat.$$(sec, '.bx').forEach(b => b.classList.remove('gone')); Beat.$(sec, '.cv-n').textContent = '30'; Beat.$(sec, '.cv-tag').classList.remove('low'); },
    },

    // ---------------------------------------------------------------- chapters: the shelf fills a little more each time
    chapter: {
      init(sec) {
        const s = Beat.$(sec, '.cp-shelf'), on = +s.dataset.on, gh = +s.dataset.ghost;
        let html = row(on, 72, 470, 40, 36, 46);
        for (let i = 0; i < gh; i++) html += `<span class="slot want k-fade" style="left:${72 + (on + i) * 46}px;top:434px;width:40px;height:36px"></span>`;
        s.innerHTML = html;
      },
      beats: [[
        [0, l => qa('.cp-title, .cp-sub, .cp-edge, .cp-tag').forEach(x => Beat.show(x, l))],
        ...Array.from({ length: 24 }, (_, i) => [900 + i * 60, l => Beat.show(qa('.cp-shelf > *')[i], l)]),
      ]],
    },

    // ---------------------------------------------------------------- 2 the plan: history, then the signals
    plan: {
      init(sec) {
        const c = Beat.$(sec, '.chart'), base = 340, k = 36;
        Beat.$(c, '.grid').innerHTML = [0, 2, 4, 6, 8].map(v => `<div class="gl k-fade ${v ? '' : 'base'}" style="top:${base - v * k}px"><span>${v}</span></div>`).join('');
        Beat.$(c, '.bars').innerHTML = T.weekly.map((w, i) => `
          <div class="bar k-growy ${w.units > 5 ? 'hot' : ''}" data-i="${i}" style="left:${60 + i * 100}px;top:${base - w.units * k}px;height:${w.units * k}px"><span class="v">${w.units}</span></div>
          <p class="wk k-fade" data-i="${i}" style="left:${60 + i * 100}px;top:${base + 10}px">${w.week}</p>`).join('');
        Beat.$(sec, '.sg-list').innerHTML = T.signals.map((s, i) => `
          <div class="sg k-rise ${s.id === 'SIG07' ? 'mine' : ''}" style="top:${40 + i * 108}px">
            <p class="sg-m"><span>${s.id} · ${s.type}</span>${s.id === 'SIG07' ? '<b>P004\'s own supplier</b>' : ''}<span>score ${s.score.toFixed(2)}</span></p>
            <p class="sg-t">${s.headline}</p></div>`).join('');
      },
      beats: [
        [
          [0, l => head(l)],
          [900, l => Beat.show(q('.ch-head'), l)],
          [1200, l => qa('.gl').forEach((g, i) => Beat.show(g, l, i * 80))],
          ...[0, 1, 2, 3].map(i => [1800 + i * 260, l => { Beat.show(q(`.bar[data-i="${i}"]`), l); Beat.show(q(`.wk[data-i="${i}"]`), l); }]),
          ...[4, 5].map(i => [3900 + (i - 4) * 400, l => { Beat.show(q(`.bar[data-i="${i}"]`), l); Beat.show(q(`.wk[data-i="${i}"]`), l); }]),
          [6200, l => Beat.show(q('.avg'), l)],
          [7000, l => Beat.show(q('.foot'), l)],
        ],
        [
          [0, l => Beat.show(q('.spike'), l)],
          [900, l => Beat.show(q('.sg-head'), l)],
          ...[0, 1, 2].map(i => [1400 + i * 900, l => Beat.show(qa('.sg')[i], l)]),
          [4600, l => Beat.show(q('.moral'), l)],
        ],
      ],
    },

    // ---------------------------------------------------------------- 3 runway: days pass, boxes sell, the shelf runs dry
    runway: (() => {
      const X0 = 250, STEP = 42, W = 36, H = 34, TOPS = [270, 380], DAYS = 21;
      const setDay = d => {
        const c = q('.cursor');
        c.style.left = `${X0 + d * STEP - 3}px`;
        Beat.$(c, '.cur-l b').textContent = String(d);
        T.runway.forEach((r, li) => {
          for (let s = 0; s < DAYS; s++) {
            const slot = q(`.slot[data-l="${li}"][data-s="${s}"]`), box = q(`.bx[data-l="${li}"][data-s="${s}"]`);
            const passed = s < d;
            if (box) box.classList.toggle('gone', passed);
            slot.classList.toggle('out', passed && s >= r.onHand);
          }
          q(`.lane-l[data-l="${li}"] .oh`).textContent = String(Math.max(0, r.onHand - d));
        });
      };
      return {
        init(sec) {
          let html = '';
          [0, 7, 14].forEach(d => { html += `<span class="tick" style="left:${X0 + d * STEP + W / 2}px">${d}</span>`; });
          html += `<span class="tick" style="left:${X0 + 21 * STEP + W / 2}px">21: arrives</span>`;
          Beat.$(sec, '.axis').insertAdjacentHTML('beforeend', html);
          Beat.$(sec, '.lanes').innerHTML = T.runway.map((r, li) => {
            const y = TOPS[li];
            let h = `<p class="lane-l k-rise" data-l="${li}" style="top:${y - 8}px"><b>${r.store}</b><span>on hand <span class="oh">${r.onHand}</span></span></p>`;
            for (let s = 0; s < DAYS; s++) h += `<span class="slot k-fade" data-l="${li}" data-s="${s}" style="left:${X0 + s * STEP}px;top:${y}px;width:${W}px;height:${H}px"></span>`;
            for (let s = 0; s < r.onHand; s++) h += `<span class="bx k-pop" data-l="${li}" data-s="${s}" style="left:${X0 + s * STEP}px;top:${y}px;width:${W}px;height:${H}px"></span>`;
            h += `<span class="bx ord k-pop arr" data-l="${li}" style="left:${X0 + DAYS * STEP}px;top:${y}px;width:${W}px;height:${H}px"></span>`;
            h += `<p class="outl k-rise" data-l="${li}" style="left:${X0 + r.onHand * STEP}px;top:${y + H + 8}px">empty for ${DAYS - r.onHand} days</p>`;
            return h;
          }).join('');
        },
        beats: [
          [
            [0, l => head(l)],
            [900, l => qa('.axis, .tick').forEach(x => Beat.show(x, l))],
            [1300, l => qa('.lane-l').forEach((x, i) => Beat.show(x, l, i * 200))],
            [1700, l => qa('.slot').forEach(x => Beat.show(x, l))],
            ...Array.from({ length: 8 }, (_, s) => [2200 + s * 120, l => qa(`.bx[data-s="${s}"]`).forEach(b => Beat.show(b, l))]),
            [3600, l => qa('.bx.arr').forEach((b, i) => Beat.show(b, l, i * 200))],
            [4400, l => Beat.show(q('.foot'), l)],
          ],
          [
            [0, () => { q('.cursor').classList.add('on'); setDay(0); }],
            ...Array.from({ length: DAYS }, (_, k) => [700 + k * 340, () => setDay(k + 1)]),
            [8200, l => qa('.outl').forEach((x, i) => Beat.show(x, l, i * 300))],
            [9200, l => Beat.show(q('.moral'), l)],
          ],
        ],
        reset(sec) {
          Beat.$$(sec, '.gone').forEach(b => b.classList.remove('gone'));
          Beat.$$(sec, '.slot.out').forEach(b => b.classList.remove('out'));
          Beat.$$(sec, '.lane-l .oh').forEach((o, i) => { o.textContent = String(T.runway[i].onHand); });
          const c = Beat.$(sec, '.cursor'); c.style.left = `${X0 - 3}px`; Beat.$(c, '.cur-l b').textContent = '0';
        },
      };
    })(),

    // ---------------------------------------------------------------- 5 query: words to columns, then the answer
    query: {
      init(sec) {
        const W = 440, max = 60, px = v => 130 + v / max * W;
        Beat.$(sec, '.bullets').innerHTML = T.answer.map((a, i) => `
          <div class="brow" style="top:${446 + i * 84}px" data-i="${i}">
            <p class="st k-fade">${a.store}</p>
            <div class="trk k-fade"></div>
            <div class="fill k-growx" style="width:${a.onHand / max * W}px"></div>
            <div class="tk k-fade" style="left:${px(a.safetyStock) - 1}px"></div>
            <p class="tl k-fade" style="left:${px(a.safetyStock)}px">safety stock ${a.safetyStock}</p>
            <p class="tl end k-fade" style="left:${px(max)}px">reorder point ${a.reorderPoint}</p>
            <p class="val k-land">${a.onHand}</p>
            <span class="crit k-drop">CRITICAL</span>
          </div>`).join('');
        Beat.$$(sec, '.col').forEach((c, i) => { c.style.left = `${72 + i * 290}px`; });
      },
      beats: [
        [
          [0, l => head(l)],
          [900, l => Beat.show(q('.q'), l)],
          ...[1, 2, 3, 4].map((n, i) => [3200 + i * 1700, l => { q(`.ph[data-n="${n}"]`).classList.add('hit'); Beat.show(q(`.col[data-n="${n}"]`), l, 250); }]),
          [9000, l => Beat.show(q('.foot'), l)],
        ],
        [
          [0, l => Beat.show(q('.sql'), l)],
          [900, l => Beat.show(q('.ans-h'), l)],
          ...[0, 1].map(i => [1300 + i * 700, l => qa(`.brow[data-i="${i}"] :is(.st, .trk, .fill, .tk, .tl)`).forEach(x => Beat.show(x, l))]),
          ...[0, 1].map(i => [3000 + i * 400, l => { Beat.show(q(`.brow[data-i="${i}"] .val`), l); Beat.show(q(`.brow[data-i="${i}"] .crit`), l, 300); }]),
        ],
      ],
      reset(sec) { Beat.$$(sec, '.ph').forEach(p => p.classList.remove('hit')); },
    },

    // ---------------------------------------------------------------- 6 corrections: fluent answers, struck through
    corr: {
      init(sec) {
        const items = [
          { tag: 'Challenge 2 · demand sensing', said: 'I couldn\'t verify inventory, so this is based on external signals only.', what: 'gpt-5.4-mini skipped the Fabric Data Agent and answered from the web alone.', fix: 'Make the call mandatory in the instructions, or set tool choice to required.' },
          { tag: 'Challenges 1 and 3 · any agent', said: 'I found no data for Outdoor Power Tools.', what: 'The query filtered on a friendly label. The stored value is outdoor_power_tools.', fix: 'Map labels to snake_case in the Data Agent instructions, or ask by SKU, for example P004.' },
          { tag: 'Challenge 3 · optimisation', said: 'Suggested reorder quantity: <b class="d">0</b>. Average daily sales are <b class="d">0</b>.', what: 'It asked for sales at the warehouses. DemandHistory records sales at retail stores only.', fix: 'Query demand at the stores, then divide weekly units by 7.' },
        ];
        Beat.$(sec, '.items').innerHTML = items.map((it, i) => `
          <div class="it" data-i="${i}" style="left:${i * 396}px">
            <p class="it-tag k-rise">${it.tag}</p>
            <p class="said k-rise">The agent said</p>
            <p class="qt k-rise"><span>“${it.said}”</span></p>
            <p class="fx k-rise"><b>What happened</b>${it.what}</p>
            <p class="fx fix k-rise"><b>The fix</b>${it.fix}</p>
          </div>`).join('');
      },
      beats: [
        [
          [0, l => head(l)],
          [900, l => Beat.show(q('.box-h'), l)],
          ...[0, 1, 2].map(i => [1500 + i * 800, l => qa(`.it[data-i="${i}"] :is(.it-tag, .said, .qt)`).forEach((x, k) => Beat.show(x, l, k * 120))]),
          [4400, l => Beat.show(q('.foot'), l)],
        ],
        [
          ...[0, 1, 2].flatMap(i => [
            [i * 1500, () => q(`.it[data-i="${i}"] .qt`).classList.add('struck')],
            [i * 1500 + 600, l => qa(`.it[data-i="${i}"] .fx`).forEach((x, k) => Beat.show(x, l, k * 250))],
          ]),
          [5200, l => Beat.show(q('.moral'), l)],
        ],
      ],
      reset(sec) { Beat.$$(sec, '.qt').forEach(x => x.classList.remove('struck')); },
    },

    // ---------------------------------------------------------------- 8 loop: three agents ask one Lakehouse
    loop: (() => {
      const LEFT = [72, 470, 868], FX = LEFT.map(x => x + 20 + 50);
      return {
        init(sec) {
          const ag = [
            { nm: 'demand-sensing-agent', vb: 'Senses the signal', ds: 'Live web signals against the governed stock position.', out: 'critically exposed', web: 'on' },
            { nm: 'inventory-optimisation-agent', vb: 'Plans the refill', ds: 'Stock, reorder points and sales, then one reorder rule.', out: 'a reorder table', web: 'remove' },
            { nm: 'replenishment-action-agent', vb: 'Proposes the order', ds: 'Unit costs from Products, then it waits for a person.', out: 'a PO, after YES', web: 'remove' },
          ];
          Beat.$(sec, '.agents').innerHTML = ag.map((a, i) => `
            <div class="ag k-rise" data-i="${i}" style="left:${LEFT[i]}px">
              <p class="n">${i + 1}</p><p class="nm">${a.nm}</p><p class="vb">${a.vb}</p><p class="ds">${a.ds}</p>
              <p class="out k-land"><small>hands on</small>${a.out}</p>
              <div class="chips"><span class="chip fab">Fabric IQ</span><span class="chip web ${a.web === 'remove' ? 'rm' : ''}"><s>Web Search</s></span></div>
            </div>`).join('');
          Beat.$(sec, '.threads').innerHTML = FX.map((x, i) => `<path class="thr k-draw" data-i="${i}" pathLength="1" d="M${x} 518 V438"/>`).join('');
          Beat.$$(sec, '.travel.up').forEach((t, i) => { t.style.offsetPath = `path('M${FX[i]} 518 V438')`; t.style.setProperty('--dur', '1100ms'); });
        },
        beats: [
          [
            [0, l => head(l)],
            ...[0, 1, 2].map(i => [900 + i * 500, l => Beat.show(q(`.ag[data-i="${i}"]`), l)]),
            [2600, l => qa('.arrow').forEach((x, i) => Beat.show(x, l, i * 200))],
            [3200, l => Beat.show(q('.lake'), l)],
            [4000, l => qa('.thr').forEach((x, i) => Beat.show(x, l, i * 200))],
            [5000, l => Beat.show(q('.foot'), l)],
          ],
          [
            ...[0, 1, 2].flatMap(i => [
              [i * 1900, l => Beat.go(q(`.travel.u${i}`), l)],
              [i * 1900 + 1100, l => Beat.show(q(`.ag[data-i="${i}"] .out`), l)],
            ]),
            [6200, () => qa('.chip.web.rm').forEach(c => c.classList.add('removed'))],
            [7400, l => Beat.show(q('.moral'), l)],
          ],
        ],
        reset(sec) { Beat.$$(sec, '.chip.web').forEach(c => c.classList.remove('removed')); Beat.$$(sec, '.travel').forEach(t => t.classList.remove('go')); },
      };
    })(),

    // ---------------------------------------------------------------- 9 refill: the gap on each shelf is filled
    refill: (() => {
      const TOP = [280, 370, 460], X = 330, ST = 28, W = 24, H = 26;
      return {
        init(sec) {
          Beat.$(sec, '.rows').innerHTML = T.refill.map((r, i) => {
            const y = TOP[i];
            let h = `<p class="rl k-rise" data-i="${i}" style="top:${y}px"><span>${r.sku} · ${r.product}</span><b>${r.store}</b></p>`;
            for (let s = r.onHand; s < r.demand30; s++) h += `<span class="slot want k-fade" data-i="${i}" style="left:${X + s * ST}px;top:${y + 16}px;width:${W}px;height:${H}px"></span>`;
            h += row(r.onHand, X, y + 16 + H, W, H, ST, 'oh').replace(/class="bx/g, `data-r="${i}" class="bx`);
            h += row(r.order, X + r.onHand * ST, y + 16 + H, W, H, ST, 'ord').replace(/class="bx/g, `data-r="${i}" class="bx`);
            h += `<p class="rn k-fade" data-i="${i}" style="top:${y + 50}px">on hand ${r.onHand} · 30-day demand ${r.demand30}</p>`;
            h += `<p class="ro k-rise" data-i="${i}" style="top:${y}px"><span>order</span><b class="n">0</b></p>`;
            h += `<span class="crit k-drop" data-i="${i}" style="top:${y + 26}px">CRITICAL</span>`;
            return h;
          }).join('');
        },
        beats: [
          [
            [0, l => head(l)],
            [900, l => Beat.show(q('.formula'), l)],
            [1300, l => Beat.show(q('.formula-2'), l)],
            ...[0, 1, 2].map(i => [2000 + i * 400, l => {
              Beat.show(q(`.rl[data-i="${i}"]`), l);
              qa(`.bx.oh[data-r="${i}"]`).forEach((b, k) => Beat.show(b, l, 300 + k * 60));
            }]),
            [3900, l => qa('.slot.want').forEach(x => Beat.show(x, l))],
            [4500, l => qa('.rn').forEach((x, i) => Beat.show(x, l, i * 150))],
            [5200, l => Beat.show(q('.foot'), l)],
          ],
          [
            ...[0, 1, 2].flatMap(i => [
              [i * 1500, l => { Beat.show(q(`.ro[data-i="${i}"]`), l); Beat.count(q(`.ro[data-i="${i}"] .n`), T.refill[i].order, l, 1200); }],
              ...Array.from({ length: T.refill[i].order }, (_, k) => [i * 1500 + k * 60, l => Beat.show(qa(`.bx.ord[data-r="${i}"]`)[k], l)]),
            ]),
            [4700, l => qa('.crit').forEach((x, i) => Beat.show(x, l, i * 200))],
            [5800, l => Beat.show(q('.moral'), l)],
          ],
        ],
        reset(sec) { Beat.$$(sec, '.ro .n').forEach(n => { n.textContent = '0'; }); },
      };
    })(),

    // ---------------------------------------------------------------- 10 receipt: the trace prints, then each span is read
    receipt: (() => {
      const LINES = [
        { t: 'FOUNDRY  ·  TRACES', c: 'c h' },
        { t: 'inventory-optimisation-agent', c: 'c' },
        { t: '', c: 'rule' },
        { t: 'Invoke Agent', c: 'h' },
        { t: '  invoke_agent inventory-optimisation-agent:<version>', c: '' },
        { t: '  Execute Tool', c: 'h', rt: 'tens of s' },
        { t: '    mcp_inventoryhackagent.', c: '' },
        { t: '    DataAgent_inventory_hack_agent', c: '' },
        { t: '  Chat', c: 'h', rt: 'under 1 s' },
        { t: '    gpt-5.4-mini', c: '' },
        { t: '', c: 'rule' },
        { t: 'Input + Output on every span', c: 'c' },
      ];
      const Y = i => 20 + i * 30;
      const AN = [
        { line: 3, html: '<b>One run</b> of the agent, with the version that answered.' },
        { line: 5, html: '<b>The question</b> the agent sent to your Data Agent, in plain English, and the rows Fabric returned.', bar: 300, bl: 'tens of seconds: it writes and runs a query' },
        { line: 8, html: '<b>The model</b> turning those rows into the reorder table.', bar: 6, bl: 'under a second' },
      ];
      return {
        init(sec) {
          Beat.$(sec, '.lines').innerHTML = LINES.map((ln, i) => `<p class="ln k-rise ${ln.c}" style="top:${Y(i) + (ln.c === 'rule' ? 11 : 0)}px">${ln.t.replace(/</g, '&lt;').replace(/>/g, '&gt;')}${ln.rt ? `<span class="rt">${ln.rt}</span>` : ''}</p>`).join('');
          Beat.$(sec, '.notesR').innerHTML = AN.map((a, k) => {
            const y = 172 + Y(a.line);
            return `<div class="lead k-growx" data-k="${k}" style="top:${y + 11}px"></div>
              <div class="an k-rise" data-k="${k}" style="top:${y}px"><p>${a.html}</p>${a.bar ? `<div class="tb" style="width:${a.bar}px"></div><p class="tbl">${a.bl}</p>` : ''}</div>`;
          }).join('');
        },
        beats: [
          [
            [0, l => head(l)],
            [900, l => Beat.show(q('.paper'), l)],
            ...LINES.map((_, i) => [1400 + i * 380, l => Beat.show(qa('.ln')[i], l)]),
            [6200, l => Beat.show(q('.foot'), l)],
          ],
          [
            ...AN.map((_, k) => [k * 1600, l => { Beat.show(q(`.lead[data-k="${k}"]`), l); Beat.show(q(`.an[data-k="${k}"]`), l, 300); }]),
            [5200, l => Beat.show(q('.moral'), l)],
          ],
        ],
      };
    })(),

    // ---------------------------------------------------------------- 12 the guess and the count (the wow)
    po: (() => {
      const P = T.po;
      const setLine = (i, qty, cost, state) => {
        const tr = qa('table.lines tbody tr')[i];
        Beat.$(tr, '.qty span').textContent = String(qty);
        Beat.$(tr, '.cost span').textContent = money(cost);
        Beat.$(tr, '.lt').textContent = money(qty * cost);
        Beat.$(tr, '.cost').className = `r cost ${state}`;
      };
      // slots on the two boards: bottom board 28 to 55, top board 0 to 27. Six on hand, then fifty on order.
      const slotXY = s => ({ x: (s % 28) * 16, y: s < 28 ? 40 : 92 });
      const order = Array.from({ length: P.modifyQty }, (_, k) => 34 + k <= 55 ? 34 + k : k - 22);
      return {
        init(sec) {
          Beat.$(sec, 'table.lines tbody').innerHTML = P.lines.map((ln, i) => `
            <tr class="k-rise"><td class="m">${i + 1}</td><td class="m">${ln.sku}</td><td>${ln.store}</td>
            <td class="r qty"><span>${ln.qty}</span></td><td class="r cost guess"><span>${money(P.fallback)}</span></td><td class="r lt">${money(ln.qty * P.fallback)}</td></tr>`).join('');
          let html = '';
          for (let s = 28; s < 34; s++) { const p = slotXY(s); html += `<span class="bx k-pop oh" style="left:${p.x}px;top:${p.y - 20}px;width:14px;height:20px"></span>`; }
          order.forEach(s => { const p = slotXY(s); html += `<span class="bx ord k-pop" style="left:${p.x}px;top:${p.y - 20}px;width:14px;height:20px"></span>`; });
          Beat.$(sec, '.po-boxes').innerHTML = html;
        },
        beats: [
          [
            [0, l => head(l)],
            [900, l => Beat.show(q('.doc'), l)],
            ...[0, 1, 2].map(i => [1600 + i * 450, l => Beat.show(qa('table.lines tbody tr')[i], l)]),
            [3200, l => countMoney(q('.tv'), 0, P.guessTotal, l, 900)],
            [3900, l => Beat.show(q('.hmm'), l)],
            [4600, l => qa('.po-bay .board').forEach(x => Beat.show(x, l))],
            [5000, l => qa('.po-bay .bx.oh').forEach((b, k) => Beat.show(b, l, k * 80))],
            [5600, l => { Beat.show(q('.po-tag'), l); Beat.show(q('.foot'), l); }],
          ],
          [
            [0, () => Beat.hide(q('.hmm'))],
            [300, l => Beat.show(q('.ledger'), l)],
            [1300, l => Beat.show(q('.thread'), l)],
            ...[0, 1, 2].map(i => [2200 + i * 500, l => { setLine(i, P.lines[i].qty, P.lines[i].cost, 'counted'); Beat.go(qa('td.cost span')[i], l, 'flipping'); }]),
            [3900, l => { q('.total').classList.add('counted'); countMoney(q('.tv'), P.guessTotal, P.countedTotal, l); }],
            [5400, l => Beat.show(q('.gap'), l)],
          ],
          [
            [0, () => Beat.hide(q('.gap'))],
            [0, l => Beat.show(q('.r1'), l)],
            [1000, l => { setLine(0, P.modifyQty, P.lines[0].cost, 'counted'); qa('td.qty')[0].classList.add('changed'); Beat.go(qa('td.qty span')[0], l, 'flipping'); }],
            [1500, l => countMoney(q('.tv'), P.countedTotal, P.modifiedTotal, l)],
            [3100, l => Beat.show(q('.r2'), l)],
            [3900, l => { Beat.show(q('.stamp'), l); q('.total').classList.add('signed'); }],
            [4600, () => { q('.pt').textContent = `on hand 6 + on order ${P.modifyQty}`; }],
            ...order.map((_, k) => [4600 + k * 45, l => Beat.show(qa('.po-bay .bx.ord')[k], l)]),
          ],
        ],
        reset(sec) {
          P.lines.forEach((ln, i) => {
            const tr = Beat.$$(sec, 'table.lines tbody tr')[i];
            Beat.$(tr, '.qty span').textContent = String(ln.qty); Beat.$(tr, '.cost span').textContent = money(P.fallback);
            Beat.$(tr, '.lt').textContent = money(ln.qty * P.fallback); Beat.$(tr, '.cost').className = 'r cost guess'; Beat.$(tr, '.qty').classList.remove('changed');
          });
          Beat.$(sec, '.tv').textContent = '$0'; Beat.$(sec, '.total').classList.remove('counted', 'signed');
          Beat.$(sec, '.pt').textContent = 'on hand 6';
          Beat.$$(sec, '.flipping').forEach(x => x.classList.remove('flipping'));
        },
      };
    })(),

    // ---------------------------------------------------------------- 13 flow: the chain runs, the gate loops
    flow: (() => {
      const N = [
        { b: 'Start', pill: true, x: 72, w: 96 },
        { b: 'demand-sensing-agent', s: 'senses', x: 202, w: 230 },
        { b: 'inventory-optimisation-agent', s: 'plans', x: 466, w: 230 },
        { b: 'replenishment-action-agent', s: 'proposes, then waits', x: 730, w: 230, gate: true },
        { b: 'End', pill: true, x: 994, w: 96 },
      ];
      return {
        init(sec) {
          let html = N.map((n, i) => `<div class="nd k-pop ${n.pill ? 'pill' : ''} ${n.gate ? 'gate' : ''}" data-i="${i}" style="left:${n.x}px;width:${n.w}px"><b>${n.b}</b>${n.s ? `<span>${n.s}</span>` : ''}</div>`).join('');
          for (let i = 0; i < N.length - 1; i++) html += `<div class="lk k-growx" data-i="${i}" style="left:${N[i].x + N[i].w}px;width:${N[i + 1].x - N[i].x - N[i].w}px"></div>`;
          Beat.$(sec, '.chain').innerHTML = html;
        },
        beats: [
          [
            [0, l => head(l)],
            ...N.map((_, i) => [900 + i * 350, l => { Beat.show(q(`.nd[data-i="${i}"]`), l); if (i) Beat.show(q(`.lk[data-i="${i - 1}"]`), l); }]),
            ...N.map((_, i) => [3200 + i * 800, () => q(`.nd[data-i="${i}"]`).classList.add('lit')]),
            [5400, l => Beat.show(q('.loop-arc'), l)],
            [6000, l => Beat.show(q('.loop-l'), l)],
            [6800, l => Beat.show(q('.cond'), l)],
            [7400, l => Beat.show(q('.foot'), l)],
          ],
          [
            [0, l => qa('.dt, .keep').forEach(x => Beat.show(x, l))],
            [2400, l => Beat.show(q('.moral'), l)],
          ],
        ],
        reset(sec) { Beat.$$(sec, '.nd').forEach(n => n.classList.remove('lit')); },
      };
    })(),

    // ---------------------------------------------------------------- 14 close: three sentences, a full shelf
    close: {
      init(sec) { Beat.$(sec, '.cl-shelf').innerHTML = row(6, 72, 500, 40, 36, 46) + row(18, 72 + 6 * 46, 500, 40, 36, 46, 'ord', 6); },
      beats: [[
        [0, l => qa('.cl-l').forEach(x => Beat.show(x, l))],
        [2800, l => Beat.show(q('.cl-edge'), l)],
        ...Array.from({ length: 24 }, (_, i) => [3300 + i * 70, l => Beat.show(qa('.cl-shelf .bx')[i], l)]),
        [5200, l => Beat.show(q('.cl-tag'), l)],
      ]],
    },
  };
})();
