/* Three agents and a yes: the choreography of every slide.

   Each built slide is a list of beats; each beat is a list of [ms, step(live)] pairs (see relay-engine.js).
   Steps set absolute state and never start their own timers, so a click mid-beat, a step back, Show all,
   reduced motion and print land on the same settled picture.

   The signature object is the baton: a lime capsule that carries the replenishment decision from agent to
   agent. place() moves it with a "hop" animation (paused with the slide) or jumps it when not live. */
(() => {
  const T = window.TALK;
  const q = s => Beat.$(Beat.el(), s);
  const qa = s => Beat.$$(Beat.el(), s);
  const show = (sel, d) => l => qa(sel).forEach(e => Beat.show(e, l, d));
  const each = (sel, gap, base = 0) => l => qa(sel).forEach((e, i) => Beat.show(e, l, base + i * gap));
  const nth = (sel, i, fn) => l => { const e = qa(sel)[i]; if (e) fn(e, l); };
  const add = (sel, c) => () => qa(sel).forEach(e => e.classList.add(c));
  const drop = (sel, c) => () => qa(sel).forEach(e => e.classList.remove(c));
  const go = (sel, c = 'go') => l => qa(sel).forEach(e => Beat.go(e, l, c));
  const pulse = sel => l => qa(sel).forEach(e => Beat.pulse(e, l));
  const all = (...fns) => l => fns.forEach(f => f(l));

  // ------------------------------------------------------------------ the baton
  const place = (e, x, y, live, dur = 1200) => {
    if (!e) return;
    const small = e.classList.contains('sm');
    const tx = `${x - (small ? 13 : 19)}px`, ty = `${y - (small ? 5.5 : 8)}px`;
    const fx = e.style.getPropertyValue('--tx') || tx, fy = e.style.getPropertyValue('--ty') || ty;
    e.style.setProperty('--fx', live ? fx : tx); e.style.setProperty('--fy', live ? fy : ty);
    e.style.setProperty('--tx', tx); e.style.setProperty('--ty', ty);
    e.style.setProperty('--dur', `${dur}ms`);
    e.classList.add('on');
    if (live) Beat.go(e, true, 'hop'); else e.classList.remove('hop');
  };
  const baton = () => q('.baton');
  const hop = (x, y, dur) => l => place(baton(), x, y, l, dur);
  const jump = (x, y) => () => place(baton(), x, y, false);
  const resetBaton = sec => sec.querySelectorAll('.baton').forEach(b => { b.classList.remove('on', 'hop'); ['--tx', '--ty', '--fx', '--fy'].forEach(p => b.style.removeProperty(p)); });
  const clear = (sec, classes) => classes.forEach(c => sec.querySelectorAll(`.${c}`).forEach(e => e.classList.remove(c)));
  const stopTravel = sec => sec.querySelectorAll('.travel, .scan').forEach(e => e.classList.remove('go'));

  // A number that counts up live (with thousands separators) and is exact when settled.
  const countTo = (e, to, live, ms = 1300) => {
    const fmt = v => Math.round(v).toLocaleString('en-US');
    if (!e) return;
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

  const head = [[0, show('.kicker, .title')], [400, show('.subtitle')]];

  // ------------------------------------------------------------------ shelf geometry
  const COL0 = 300, COLW = 96, ROW0 = 206, ROWH = 30;
  const scanAt = c => Math.round((COL0 + c * COLW + 42 - 290) / 590 * 2400);

  window.SCENES = {
    // ================================================================ 1 cover
    cover: {
      beats: [[
        [0, show('.cv-event, h1')],
        [600, show('.cv-sub')],
        [900, show('.cv-by, .cv-meta')],
        [1200, show('.n1')], [1500, show('.e1')], [1800, show('.n2')], [2100, show('.e2')],
        [2400, show('.n3')], [2700, show('.e3')], [3000, show('.n4')],
        [3300, all(show('.sats'), each('.nlabel', 120))],
        [4000, go('.t1')],
        [7200, l => { const b = baton(); b.classList.add('sm'); place(b, 1046, 538, false); if (l) Beat.pulse(b, l); }],
        [7300, add('.gate', 'holding')],
      ]],
      reset(sec) { resetBaton(sec); stopTravel(sec); clear(sec, ['holding']); },
    },

    // ================================================================ chapters: the baton slides to this part's station
    chapter: {
      beats: [[
        [0, show('.ch-kick, h1')],
        [500, show('.ch-sub')],
        [900, show('.trk')],
        [1000, each('.stn', 150)],
        [1300, each('.slab', 100)],
        [1600, l => {
          const n = +Beat.el().dataset.part;
          qa('.stn').forEach((e, i) => e.classList.toggle('done', i < n - 1));
          qa('.slab').forEach((e, i) => e.classList.toggle('past', i < n - 1));
          place(baton(), n === 1 ? 110 : 320 * (n - 1), 460, false);
        }],
        [1900, l => place(baton(), 320 * +Beat.el().dataset.part, 460, l, 1500)],
        [3400, l => {
          const n = +Beat.el().dataset.part, s = qa('.stn')[n - 1];
          s.classList.remove('done'); s.classList.add('lit'); qa('.slab')[n - 1].classList.add('cur');
        }],
      ]],
      reset(sec) { resetBaton(sec); clear(sec, ['lit', 'done', 'cur', 'past']); },
    },

    // ================================================================ 3 shelf: 72 shelves, then the signal, then the rule
    shelf: {
      init(sec) {
        const grid = sec.querySelector('.grid');
        let html = T.stores.map((s, c) => `<p class="colh k-fade" style="left:${COL0 + c * COLW}px;top:162px">${s.name}<small>${s.id}</small></p>`).join('');
        T.shelf.forEach((row, r) => {
          const p = T.products[r];
          html += `<div class="grow k-rise" style="position:absolute;left:0;top:${ROW0 + r * ROWH}px;width:880px;height:16px">`;
          html += `<p class="rowl" style="top:0">${p.name}</p>`;
          row.forEach((cell, c) => {
            const scale = 2 * cell.rp, fill = Math.min(cell.onHand / scale, 1) * 100;
            html += `<div class="cell ${cell.status}" data-col="${c}" style="left:${COL0 + c * COLW}px;top:0">` +
              `<i class="fill" style="width:${fill.toFixed(1)}%"></i><b class="tk" style="left:50%"></b>` +
              `<b class="tk ss" style="left:${(cell.ss / scale * 100).toFixed(1)}%"></b><span class="num">${cell.onHand}</span></div>`;
          });
          html += '</div>';
        });
        grid.innerHTML = html;
      },
      beats: [
        [...head,
          [1000, each('.colh', 80)],
          ...T.shelf.map((_, r) => [1500 + r * 200, nth('.grow', r, (e, l) => Beat.show(e, l))]),
          [4200, show('.legend')],
        ],
        [
          [0, show('.band')],
          [500, show('.sig')],
          [1300, show('.sig .cats')],
        ],
        [
          [0, go('.scan')],
          ...T.stores.map((_, c) => [scanAt(c), () => qa(`.cell[data-col="${c}"]`).forEach(e => e.classList.add('judged'))]),
          [2700, l => { Beat.show(q('.tally .big'), l); Beat.count(q('.tally .n'), T.exposure.exposed, l, 1200); }],
          [3300, l => { q('.tally .nc').textContent = T.exposure.critical; Beat.show(q('.tally .r1'), l); }],
          [3700, l => { q('.tally .na').textContent = T.exposure.atRisk; Beat.show(q('.tally .r2'), l); }],
          [4400, show('.tally .note')],
          [5400, show('.moral')],
        ],
      ],
      reset(sec) { stopTravel(sec); clear(sec, ['judged']); sec.querySelector('.tally .n').textContent = '0'; },
    },

    // ================================================================ 4 rule: 28 / 7 x 30 - 6 = 114
    rule: {
      init(sec) {
        const L = T.leafBlower;
        sec.querySelector('.bars').innerHTML = L.weeks.map(([wk, v], i) => {
          const h = v / 28 * 250, x = 110 + i * 76;
          return `<div class="bar k-growy" style="left:${x}px;height:${h}px"></div>` +
            `<p class="bv k-fade" style="left:${x}px;top:${540 - h - 26}px">${v}</p>` +
            `<p class="bw k-fade" style="left:${x - 6}px">${wk}</p>`;
        }).join('');
      },
      beats: [
        [...head,
          [900, show('.axis, .base')],
          ...T.leafBlower.weeks.map((_, i) => [1300 + i * 250, l => { Beat.show(qa('.bar')[i], l); Beat.show(qa('.bv')[i], l, 300); Beat.show(qa('.bw')[i], l); }]),
          [3300, show('.code')],
        ],
        [
          [0, l => qa('.bar').at(-1).classList.add('hot')],
          [600, show('.e1')],
          [2200, show('.e2')],
          [3800, show('.e3')],
          [5400, show('.e4')],
          [7000, l => { Beat.show(q('.e5'), l); Beat.count(q('.e5 .n'), T.leafBlower.order, l, 1100); }],
          [8600, show('.receipt')],
          [9800, show('.moral')],
        ],
      ],
      reset(sec) { clear(sec, ['hot']); sec.querySelector('.e5 .n').textContent = '0'; },
    },

    // ================================================================ 6 switchboard: tools plug into agents
    board: {
      beats: [
        [...head,
          [900, show('.a1')], [1150, show('.a2')], [1400, show('.a3')],
          [2000, each('.tool', 120)],
          [3200, show('.c1 .cord')],
          [4500, l => [0, 1, 2].forEach(i => qa('.tool')[i].classList.add('lit'))],
          [5400, show('.c2 .cord')],
          [6800, l => [1, 2, 3, 4].forEach(i => qa('.tool')[i].classList.add('lit'))],
          [7600, show('.c3 .cord')],
          [8800, show('.b1')],
        ],
        [
          [0, show('.cw')],
          [1200, add('.tool.write', 'lit')],
          [1300, l => { Beat.show(q('.lock'), l); Beat.pulse(q('.lring'), l); }],
          [2200, show('.b2')],
          [3200, show('.moral')],
        ],
      ],
      reset(sec) { clear(sec, ['lit']); },
    },

    // ================================================================ 7 tool call: out, back, out, back; then the trace
    call: {
      beats: [
        [...head,
          [1000, show('.bl')], [1300, show('.br')],
          [2600, all(show('.m1'), go('.h1'))],
          [4000, all(show('.m2'), go('.h2'))],
          ...[0, 1, 2, 3].map(i => [5300 + i * 300, () => qa('.cl')[i].classList.add('ok')]),
          [6800, all(show('.m3'), go('.h3'))],
          [8200, all(show('.m4'), go('.h4'))],
        ],
        [
          [0, show('.wgrid, .wax')],
          [300, show('.w1')],
          [1400, show('.w2')],
          [2500, show('.badges')],
          [3500, show('.moral')],
        ],
      ],
      reset(sec) { stopTravel(sec); clear(sec, ['ok']); },
    },

    // ================================================================ 8 handoff: the same card changes shape at each station
    hand: (() => {
      const X = [130, 385, 640, 895, 1140], Y = 242;
      const state = n => l => { const c = q('.card'); c.dataset.s = String(n); Beat.go(q(`.card .s${n}`), l, 'flipping'); };
      const at = i => () => { const s = qa('.stn'); s.forEach((e, k) => { e.classList.toggle('lit', k === i); e.classList.toggle('done', k < i); }); };
      return {
        beats: [
          [...head,
            [900, show('.trk')],
            [1000, each('.stn', 150)],
            [1400, each('.slb', 100)],
            [1900, each('.elb', 100)],
            [2500, l => { place(baton(), X[0], Y, false); if (l) Beat.pulse(baton(), l); }],
            [2600, at(0)],
            [3000, show('.card')],
          ],
          [
            [0, hop(X[1], Y)], [1200, all(at(1), state(2))],
            [7000, hop(X[2], Y)], [8200, all(at(2), state(3))],
            [13600, hop(X[3], Y)], [14800, all(at(3), state(4))],
            [16200, show('.moral')],
          ],
        ],
        reset(sec) { resetBaton(sec); clear(sec, ['lit', 'done', 'flipping']); sec.querySelector('.card').dataset.s = '1'; },
      };
    })(),

    // ================================================================ 10 two locks
    locks: {
      beats: [
        [...head,
          [900, show('.path')],
          [1000, show('.agent')],
          [1800, show('.pcard')],
          [2400, show('.soft')],
          [3200, show('.wall')],
          [3700, show('.ccard')],
        ],
        [
          [0, go('.tk')],
          [1050, l => { Beat.go(q('.soft'), l, 'flick'); Beat.show(q('.req'), l); }],
          [2400, show('.tok')],
          [2450, pulse('.wr')],
          [2700, show('.stamp')],
          [3300, show('.stl')],
          [4100, show('.tpanel')],
          [4600, show('.t1')], [5200, show('.t2')], [5800, show('.t3')],
          [6800, show('.moral')],
        ],
      ],
      reset(sec) { stopTravel(sec); clear(sec, ['flick']); },
    },

    // ================================================================ 11 event: any writer, same reaction, same gate
    event: (() => {
      const tour = k => {
        const b = k * 5200, src = `.s${k + 1}`;
        return [
          [b, l => { qa('.node').forEach(e => e.classList.remove('lit')); Beat.$(Beat.el(), src).classList.add('lit'); Beat.go(q(`.r${k + 1}`), l); }],
          [b + 700, l => { q('.n1').classList.add('lit'); }],
          [b + 1700, add('.n2', 'lit')],
          [b + 2600, add('.n3', 'lit')],
          [b + 3000, l => { const g = q('.gate'); g.classList.add('holding'); }],
        ];
      };
      return {
        beats: [
          [...head,
            [1000, each('.src', 150)],
            [1600, show('.g1')],
            [2000, show('.n1')], [2400, show('.g2')], [2700, show('.n2')],
            [3100, show('.g3')], [3400, show('.n3')], [3800, show('.g4')],
            [4000, show('.n4')],
          ],
          [
            ...tour(0), ...tour(1), ...tour(2),
            [16000, show('.f1')], [16500, show('.f2')], [17000, show('.f3')],
            [18000, show('.moral')],
          ],
        ],
        reset(sec) { stopTravel(sec); clear(sec, ['lit', 'holding']); },
      };
    })(),

    // ================================================================ 12 the wow: the whole relay, then a person says yes
    relay: (() => {
      const Y = 270;
      const light = (st, lab, tl) => () => { [st, lab, tl].filter(Boolean).forEach(s => qa(s).forEach(e => e.classList.add('lit'))); };
      const pass = st => () => { const e = q(st); e.classList.remove('lit'); e.classList.add('done'); };
      return {
        init(sec) {
          const appr = sec.querySelector('.appr');
          const stop = e => { if (e.key === ' ' || e.key === 'Enter') e.stopPropagation(); };
          sec.querySelectorAll('.btns button').forEach(b => b.addEventListener('keydown', stop));
          sec.querySelector('.btns .ok').addEventListener('click', e => {
            e.stopPropagation(); e.currentTarget.blur();
            appr.classList.remove('rejected');
            if (sec.dataset.beat === '0') Reveal.next();
          });
          sec.querySelector('.btns .rej').addEventListener('click', e => {
            e.stopPropagation(); e.currentTarget.blur();
            if (sec.dataset.beat === '0') appr.classList.toggle('rejected');
          });
        },
        beats: [
          [...head,
            [900, show('.trk')],
            [1000, l => ['.st0', '.st1', '.st2', '.st3', '.st4', '.st5'].forEach((s, i) => Beat.show(q(s), l, i * 200))],
            [1300, each('.slab', 140)],
            [2200, each('.tl', 120)],
            [2800, show('.log')],
            [3000, show('.appr')],
            [3800, l => { place(baton(), 130, Y, false); if (l) Beat.pulse(baton(), l); Beat.show(q('.x1'), l); q('.l0').classList.add('lit'); }],
            [4600, hop(350, Y)], [5800, light('.st1', '.l1', '.t1')], [6600, show('.x2')],
            [7400, all(pass('.st1'), hop(580, Y))], [8600, light('.st2', '.l2', '.t2')], [9400, show('.x3')],
            [10200, all(pass('.st2'), hop(810, Y))], [11400, light('.st3', '.l3', '.t3')],
            [11800, show('.p0')], [12100, show('.p1')], [12400, show('.p2')], [12700, show('.p3')],
            [13400, show('.x4')],
            [14200, all(pass('.st3'), hop(966, Y))],
            [15400, l => { Beat.pulse(q('.rg'), l); q('.gate').classList.add('holding'); q('.l4').classList.add('lit'); }],
            [15800, l => { Beat.show(q('.x5'), l); Beat.show(q('.g27'), l); }],
            [16400, show('.btns')],
          ],
          [
            [0, l => { q('.appr').classList.remove('rejected'); Beat.go(q('.btns .ok'), l, 'pressed'); }],
            [500, () => { const g = q('.gate'); g.classList.remove('holding'); g.classList.add('open'); q('.t4').classList.add('lit'); }],
            [900, all(add('.trk.after', 'lit'), hop(1170, Y))],
            [2100, l => { q('.book').classList.add('lit'); q('.l5').classList.add('lit'); Beat.pulse(q('.bb'), l); }],
            [2400, add('.appr', 'approved')],
            [2500, show('.c0')],
            [2900, show('.c1')],
            [3300, each('.c2', 120)],
            [3800, show('.x6')],
            [4800, show('.moral')],
          ],
        ],
        reset(sec) { resetBaton(sec); clear(sec, ['lit', 'done', 'holding', 'open', 'approved', 'rejected', 'pressed']); },
      };
    })(),

    // ================================================================ 13 the day: the baton runs the six challenges
    day: (() => {
      const X = T.day.map((_, i) => 150 + i * 196);
      return {
        init(sec) {
          sec.querySelector('.days').innerHTML = T.day.map((d, i) =>
            `<div class="stn k-pop${d.stretch ? ' ghost' : ''}" style="left:${X[i] - 28}px"></div>` +
            `<p class="num k-pop" style="left:${X[i] - 28}px">${d.n}</p>` +
            `<p class="bl k-rise" style="left:${X[i] - 95}px">${d.builds}</p>` +
            `<p class="ttl k-rise" style="left:${X[i] - 88}px">${d.title}</p>` +
            `<p class="min k-rise${d.stretch ? ' st' : ''}" style="left:${X[i] - 95}px">${d.min} min${d.stretch ? ' · stretch' : ''}</p>`).join('');
        },
        beats: [[
          ...head,
          [900, show('.trk')],
          [1000, l => qa('.stn').forEach((e, i) => { Beat.show(e, l, i * 100); Beat.show(qa('.num')[i], l, i * 100); })],
          [1600, jump(96, 328)],
          ...X.flatMap((x, i) => [
            [1800 + i * 1300, hop(x, 328, 1000)],
            [2800 + i * 1300, l => {
              qa('.stn').forEach((e, k) => { e.classList.toggle('lit', k === i); e.classList.toggle('done', k < i); });
              ['.bl', '.ttl', '.min'].forEach(s => Beat.show(qa(s)[i], l));
            }],
          ]),
          [9300, hop(1190, 328, 900)],
          [10200, show('.brk, .brl')],
          [11200, show('.moral')],
        ]],
        reset(sec) { resetBaton(sec); clear(sec, ['lit', 'done']); },
      };
    })(),

    // ================================================================ 14 sign-off: the relay in miniature opens its gate
    outro: {
      beats: [[
        [0, show('.trk')],
        [300, l => ['.o1', '.o2', '.o3', '.o4'].forEach((s, i) => Beat.show(q(s), l, i * 150))],
        [1200, l => { place(baton(), 380, 240, false); if (l) Beat.pulse(baton(), l); }],
        [1400, hop(440, 240, 800)], [2200, l => { q('.o1').classList.add('lit'); Beat.show(q('.w1'), l); }],
        [2400, all(() => q('.o1').classList.replace('lit', 'done'), hop(560, 240, 800))], [3200, l => { q('.o2').classList.add('lit'); Beat.show(q('.w2'), l); }],
        [3400, all(() => q('.o2').classList.replace('lit', 'done'), hop(680, 240, 800))], [4200, () => q('.o3').classList.add('lit')],
        [4400, all(() => q('.o3').classList.replace('lit', 'done'), hop(811, 240, 900))],
        [5400, l => { q('.o4').classList.add('open'); Beat.show(q('.w3'), l); }],
        [5800, hop(940, 240, 900)],
        [6800, show('.w4')],
        [7600, show('.hl')],
        [8600, show('.by, .where')],
      ]],
      reset(sec) { resetBaton(sec); clear(sec, ['lit', 'done', 'open']); },
    },
  };
})();
