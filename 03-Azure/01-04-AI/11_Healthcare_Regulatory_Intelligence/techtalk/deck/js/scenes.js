/* Scenes for "Follow the paragraph". Each beat is a list of [ms, fn(live)] steps.
   Steps set absolute state (show, hide, or a state class) and never start their own timers. */
(() => {
  const Q = s => Beat.$(Beat.el(), s);
  const QA = s => Beat.$$(Beat.el(), s);
  const D = window.DATA;

  // State classes that steps add besides .on; every reset removes them.
  const STATE = ['lit', 'hot', 'hit', 'calm', 'fit', 'miss', 'test', 'used', 'focus', 'merged', 'good', 'bad', 'is-v2', 'best', 'zero'];
  const clear = sec => sec.querySelectorAll(STATE.map(c => '.' + c).join(',')).forEach(e => e.classList.remove(...STATE));
  const enter = (e, d) => { if (d !== undefined) e.style.setProperty('--d', `${d}ms`); e.classList.remove('enter'); void e.getBoundingClientRect(); e.classList.add('enter'); };
  const mark = (e, c, live, d) => { if (!e) return; e.classList.add(c); if (live) enter(e, d); };
  const show = (s, l, d) => Beat.show(typeof s === 'string' ? Q(s) : s, l, d);
  const showAll = (s, l, gap = 0, d0 = 0) => QA(s).forEach((e, i) => Beat.show(e, l, d0 + i * gap));
  const head = [
    [0, l => { show('.kicker', l); show('.title', l, 120); }],
    [400, l => show('.subtitle', l, 0)],
  ];

  window.SCENES = {
    // ------------------------------------------------------------------ 1 cover
    cover: {
      beats: [[
        [0, l => { show('.cv-kicker', l); show('h1', l, 150); show('.cv-sub', l, 700); }],
        [500, l => { show('.under', l, 0); show('.sheet', l, 100); }],
        [1100, l => { show('.cv-rule', l, 0); show('.cv-name', l, 100); show('.cv-meta', l, 250); }],
        [1300, l => QA('.sheet .pp').forEach((e, i) => show(e, l, i * 160))],
        [2600, l => show('.cv-knot', l)],
        [2700, l => show('.sheet .hl', l)],
        [3800, l => show('.cv-lead', l)],
        [4400, l => show('.cv-note', l)],
      ]],
    },

    // ------------------------------------------------------------------ 2 monday
    monday: {
      beats: [
        [
          ...head,
          ...[0, 1, 2, 3, 4, 5, 6, 7, 8, 9].map(i => [1000 + i * 180, l => show(`.card.c${i}`, l)]),
        ],
        [
          [0, l => show('.f1', l)],
          [700, l => show('.f2', l)],
          [1400, l => show('.f3', l)],
          [2100, l => show('.f4', l)],
          [3400, l => show('.q1', l)],
          [3800, l => show('.q2', l)],
          [4200, l => show('.q3', l)],
          [5400, l => show('.moral', l)],
        ],
      ],
    },

    // ------------------------------------------------------------------ chapters
    chapter: {
      beats: [[
        [0, l => show('.page', l, 0)],
        [300, l => { show('.rh-l', l, 0); show('.rh-r', l, 0); }],
        [450, l => show('.rh-line', l, 0)],
        [600, l => show('h1', l, 0)],
        [1300, l => show('.cbar', l, 0)],
        [1500, l => show('.quote', l, 0)],
        [2100, l => { show('.fn-line', l, 0); show('.fn', l, 100); }],
      ]],
    },

    // ------------------------------------------------------------------ 4 tracing
    tracing: {
      beats: [
        [
          ...head,
          [900, l => { show('.sa', l, 0); show('.sb', l, 160); }],
          [1500, l => { show('.la', l); show('.lb', l, 150); }],
          [7000, l => QA('.sa .chrome').forEach((e, i) => mark(e, 'on', l, i * 250))],
          [7600, l => QA('.sb .chrome').forEach((e, i) => mark(e, 'on', l, i * 250))],
          [9400, l => mark(Q('.sb'), 'merged', l, 0)],
          [11200, l => show('.dup', l)],
          [12600, l => show('.ledger', l, 0)],
          ...['r0', 'r1', 'r2', 'r3', 'r4'].map((r, i) => [13200 + i * 450, l => {
            show(`.${r}`, l);
            const n = Q(`.${r} .n`); Beat.count(n, D.monitor.run1[n.dataset.to], l, 900);
          }]),
          [13200, l => show('.col.c1', l)],
        ],
        [
          [0, l => show('.col.c2', l)],
          [400, l => show('.w2', l)],
          [800, l => show('.w3', l)],
          [1200, l => show('.w4', l)],
          [2200, l => show('.nothing', l)],
          [3400, l => show('.moral', l)],
        ],
      ],
      init(sec) {
        // Run 2 values come from data.js.
        sec.querySelector('.w2').textContent = D.monitor.run2.newDocs;
        sec.querySelector('.w3').textContent = D.monitor.run2.duplicates;
        sec.querySelector('.w4').textContent = D.monitor.run2.events;
      },
      reset(sec) { clear(sec); sec.querySelectorAll('.n').forEach(n => { n.textContent = '0'; }); },
    },

    // ------------------------------------------------------------------ 5 redline
    redline: {
      beats: [
        [
          ...head,
          [800, l => show('.doc', l, 0)],
          [1400, l => show('.v1c', l, 0)],
          [6000, l => show('.run3', l)],
          [7000, l => show('.i1', l)],
          [7900, l => show('.d2', l)],
          [8500, l => show('.i2', l)],
          [9500, l => show('.d3', l)],
          [10100, l => show('.i3', l)],
          [11100, l => show('.d4', l)],
          [11700, l => show('.i4', l)],
          ...[0, 1, 2, 3].map(i => [12700 + i * 200, l => {
            const e = QA('.rp .pl')[i]; e.textContent = e.dataset.v2; e.classList.add('is-v2'); Beat.go(e, l, 'flipping');
          }]),
          [13600, l => { const b = Q('.vbadge'); b.textContent = b.dataset.v2; Beat.go(b, l, 'flipping'); }],
          [14400, l => { const s = Q('.v1c .s1'); s.textContent = 'Superseded on 2027-01-12. Do not use for new decisions.'; s.classList.replace('cur', 'sup'); Beat.go(s, l, 'flipping'); }],
          [15200, l => show('.v2c', l, 0)],
        ],
        [
          [0, l => show('.agent', l, 0)],
          [1400, l => show('.h3', l)],
          [2600, l => show('.vr', l)],
          [4200, l => show('.moral', l)],
        ],
      ],
      reset(sec) {
        clear(sec);
        sec.querySelectorAll('[data-v1]').forEach(e => { e.textContent = e.dataset.v1; });
        const s = sec.querySelector('.v1c .s1'); s.textContent = 'Current'; s.classList.replace('sup', 'cur');
      },
    },

    // ------------------------------------------------------------------ 7 citation
    citation: {
      beats: [
        [
          ...head,
          [800, l => show('.ask', l, 0)],
          [1500, l => { show('.ccard', l, 0); show('.src', l, 200); }],
          [2600, l => QA('.ccard .r1').forEach(e => Beat.show(e, l))],
          [3100, l => QA('.ccard .r2').forEach(e => Beat.show(e, l))],
          [3600, l => QA('.ccard .r3').forEach(e => Beat.show(e, l))],
          ...[1, 2, 3, 4, 5].flatMap(i => {
            const t = 4200 + (i - 1) * 2300;
            return [
              [t, l => Beat.stream(Q(`.st.s${i}`), l, 60)],
              [t + 700, l => show(`.cc.c${i}`, l)],
              [t + 1000, l => show(`.art .t${i}`, l)],
              [t + 1800, l => mark(Q(`.src .q${i}`), 'lit', l, 0)],
            ];
          }),
          [15900, l => QA('.ccard .r4').forEach(e => Beat.show(e, l))],
        ],
        [
          [0, l => show('.n1', l, 0)],
          [1000, l => Beat.stream(Q('.n2'), l, 70)],
          [2600, l => show('.moral', l)],
        ],
      ],
      reset(sec) { clear(sec); },
    },

    // ------------------------------------------------------------------ 8 letter
    letter: {
      beats: [
        [
          ...head,
          [800, l => show('.letter', l, 0)],
          [3200, l => show('.fb', l, 0)],
          [3900, l => Beat.go(Q('.scan'), l)],
          [5800, l => show('.fres', l)],
        ],
        [
          [0, l => show('.u1', l)],
          [500, l => show('.l1', l)],
          [1300, l => show('.x1', l, 0)],
          [3000, l => show('.u2', l)],
          [3500, l => show('.l2', l)],
          [4300, l => show('.x2', l, 0)],
          [6000, l => show('.l3', l)],
          [6800, l => show('.x3', l, 0)],
          [7600, l => show('.rsk', l)],
          [9400, l => show('.u4', l)],
          [9900, l => show('.l4', l)],
          [10700, l => show('.x4', l, 0)],
        ],
        [
          [0, l => show('.d4', l)],
          [700, l => show('.notours', l)],
          [1800, l => show('.verdict', l, 0)],
          [3200, l => show('.moral', l)],
        ],
      ],
      reset(sec) { clear(sec); sec.querySelector('.scan').classList.remove('go'); },
    },

    // ------------------------------------------------------------------ 9 ladder
    ladder: (() => {
      // Row k is being checked against rule j (rule j fits when j === k). k = 5 is the settled end.
      const scan = (k, j, l) => {
        const rules = QA('.rule'), acts = QA('.act');
        rules.forEach((r, i) => {
          r.classList.remove('miss', 'test', 'fit', 'used');
          const n = i + 1;
          if (k > 4) { r.classList.add('fit'); return; }
          if (n < j) r.classList.add('miss');
          else if (n === j) r.classList.add(j === k ? 'fit' : 'test');
          else if (n < k) r.classList.add('used');
        });
        acts.forEach((a, i) => a.classList.toggle('focus', i + 1 === k));
        if (k <= 4 && j === k) {
          const a = acts[k - 1];
          Beat.show(a.querySelector('.ar'), l); Beat.show(a.querySelector('.ad'), l, 250); Beat.show(a.querySelector('.ao'), l, 500);
        }
      };
      const tour = [];
      let t = 0;
      for (let k = 1; k <= 4; k++) {
        for (let j = 1; j <= k; j++) { const kk = k, jj = j; tour.push([t, l => scan(kk, jj, l)]); t += 800; }
        t += 1800;
      }
      tour.push([t, l => scan(5, 0, l)]);
      tour.push([t + 600, l => show('.moral', l)]);
      return {
        beats: [
          [
            ...head,
            [800, l => show('.rules', l, 0)],
            [1200, l => QA('.rule').forEach((e, i) => Beat.show(e, l, i * 160))],
            [1900, l => show('.today', l)],
            [2600, l => QA('.act').forEach((e, i) => Beat.show(e, l, i * 160))],
          ],
          tour,
        ],
        reset(sec) { clear(sec); },
      };
    })(),

    // ------------------------------------------------------------------ 10 runsheet
    runsheet: {
      beats: [
        [
          ...head,
          [800, l => show('.sheet', l, 0)],
          ...D.settings.flatMap((s, r) => {
            const t0 = 1600 + r * 3000;
            return [
              [t0, l => show(`.srow.w${r}`, l, 0)],
              ...Array.from({ length: s.runs }, (_, i) => [t0 + 500 + i * 260, l => {
                Beat.show(Q(`.srow.w${r} .b${i}`), l);
                Q(`.srow.w${r} .sc .n`).textContent = String(Math.min(i + 1, s.right));
              }]),
              [t0 + 500 + s.runs * 260 + 200, l => show(`.srow.w${r} .tk`, l)],
            ];
          }),
        ],
        [
          [0, l => { mark(Q('.srow.w0'), 'zero', l); mark(Q(`.srow.w${D.settings.length - 1}`), 'best', l); }],
          [900, l => show('.note', l)],
          [2200, l => show('.moral', l)],
        ],
      ],
      init(sec) {
        const sheet = sec.querySelector('.sheet');
        D.settings.forEach((s, r) => {
          const boxes = Array.from({ length: s.runs }, (_, i) => {
            const ok = i < s.right;
            return `<p class="box ${ok ? 'pass' : 'fail'} k-pop b${i}" style="left:${440 + i * 54}px" aria-label="${ok ? 'right' : 'missed'}">${ok ? '\u2713' : '\u00D7'}</p>`;
          }).join('');
          sheet.insertAdjacentHTML('beforeend', `<div class="srow k-rise w${r}" style="top:${52 + r * 92}px"><p class="sn">${s.name}</p>${boxes}<p class="sc"><span class="n">0</span><small> of ${s.runs}</small></p><p class="tk k-fade">about ${s.tokens.toLocaleString('en-US')}</p></div>`);
        });
      },
      reset(sec) { clear(sec); sec.querySelectorAll('.sc .n').forEach(n => { n.textContent = '0'; }); },
    },

    // ------------------------------------------------------------------ 11 provenance
    provenance: {
      beats: [
        [
          ...head,
          [800, l => { show('.draft', l, 0); show('.src2', l, 200); }],
          [1800, l => QA('.draft .s').forEach((e, i) => Beat.show(e, l, i * 300))],
        ],
        [
          [0, l => show('.h1', l)],
          [900, l => show('.t1', l)],
          [1900, l => mark(Q('.s1'), 'good', l)],
          [3400, l => show('.h2', l)],
          [4300, l => show('.t2', l)],
          [5300, l => mark(Q('.s2'), 'good', l)],
          [7000, l => Beat.go(Q('.scan2'), l)],
          [8900, l => mark(Q('.s3'), 'bad', l)],
          [9600, l => show('.cmt', l, 0)],
          [11200, l => show('.moral', l)],
        ],
      ],
      reset(sec) { clear(sec); sec.querySelector('.scan2').classList.remove('go'); },
    },

    // ------------------------------------------------------------------ 13 ripple (the wow scene)
    ripple: {
      beats: [
        [
          ...head,
          [800, l => show('.alert', l, 0)],
          ...[1, 2, 3, 4, 5, 6, 7].map(i => [1700 + i * 160, l => show(`.rec.r${i}`, l, 0)]),
        ],
        [
          // p2: what changes. Both EU labels.
          [0, l => mark(Q('.e2'), 'hot', l, 0)],
          [500, l => { show('.k2', l); show('.w2', l); }],
          [1500, l => show('.bk', l)],
          [1900, l => mark(Q('.r1'), 'hit', l, 0)],
          [2100, l => show('.n1', l)],
          [2500, l => mark(Q('.r2'), 'hit', l, 0)],
          [2700, l => show('.n2', l)],
          // p3: by when. The variation deadline gives both labels their date.
          [4400, l => mark(Q('.e3'), 'hot', l, 0)],
          [4900, l => { show('.k3', l); show('.w3', l); }],
          [6000, l => { show('.d1', l); show('.o1', l, 200); }],
          [6300, l => { show('.d2', l); show('.o2', l, 200); }],
          // p4: the DHPC procedure.
          [8000, l => mark(Q('.e4'), 'hot', l, 0)],
          [8500, l => { show('.k4', l); show('.w4', l); }],
          [9600, l => mark(Q('.r3'), 'hit', l, 0)],
          [9900, l => { show('.d3', l); show('.o3', l, 200); }],
          // p5: the risk management plan, which had no date.
          [11600, l => mark(Q('.e5'), 'hot', l, 0)],
          [12100, l => { show('.k5', l); show('.w5', l); }],
          [13200, l => mark(Q('.r4'), 'hit', l, 0)],
          [13400, l => show('.n4', l)],
          [13800, l => { show('.d4', l); show('.o4', l, 200); }],
          // The records this alert does not change stay quiet.
          ...[5, 6, 7].map((i, n) => [15600 + n * 300, l => { mark(Q(`.r${i}`), 'calm', l); show(`.m${i}`, l); }]),
        ],
        [
          [0, l => show('.sign', l, 0)],
          [500, l => show('.sg', l)],
          [1500, l => show('.sr', l)],
          [2000, l => { show('.tk', l); Beat.pulse(Q('.bs'), l); }],
          [2600, l => show('.sha', l)],
          [3800, l => show('.moral', l)],
        ],
      ],
      reset(sec) { clear(sec); },
    },

    // ------------------------------------------------------------------ 14 refusals
    refusals: (() => {
      const tamper = (i, l) => { Beat.show(Q(`.x${i}`), l); Beat.show(Q(`.y${i}`), l, 350); };
      const revert = i => { Beat.hide(Q(`.x${i}`)); Beat.hide(Q(`.y${i}`)); };
      return {
        beats: [
          [
            ...head,
            [800, l => show('.json', l, 0)],
            [1100, l => show('.json pre', l, 0)],
            [1700, l => show('.cmd', l, 0)],
          ],
          [
            [0, l => tamper(1, l)], [1100, l => show('.s1', l, 0)], [3600, () => revert(1)],
            [4000, l => tamper(2, l)], [5100, l => show('.s2', l, 0)], [7600, () => revert(2)],
            [8000, l => tamper(3, l)], [9100, l => show('.s3', l, 0)], [11600, () => revert(3)],
          ],
          [
            [0, l => tamper(4, l)], [1100, l => show('.s4', l, 0)], [3600, () => revert(4)],
            [4000, l => show('.again', l)], [5000, l => show('.s5', l, 0)],
            [6600, l => show('.moral', l)],
          ],
        ],
        reset(sec) { clear(sec); },
      };
    })(),

    // ------------------------------------------------------------------ 15 contents (sign-off)
    contents: {
      beats: [[
        [0, l => show('.page', l, 0)],
        [500, l => show('.m1', l)],
        [1500, l => show('.m2', l)],
        [2600, l => show('.toc-h', l)],
        ...[0, 1, 2, 3, 4, 5, 6].map(i => [3000 + i * 450, l => {
          const r = QA('.toc')[i];
          Beat.show(r.querySelector('.n'), l); Beat.show(r.querySelector('.tt'), l, 60);
          Beat.show(r.querySelector('.dots'), l, 200); Beat.show(r.querySelector('.dur'), l, 600);
        }]),
        [6600, l => show('.sigtxt', l)],
        [7400, l => show('.sigline', l)],
        [8000, l => { show('.who', l); show('.path', l, 200); }],
        [9200, l => show('.seal', l)],
      ]],
    },
  };
})();
