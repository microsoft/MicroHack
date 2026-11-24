/* First light: every number shown on the slides, with the file it comes from.
   Paths are relative to the hack folder (03-Azure/01-04-AI/13_Frontier_Operations).
   Elements with data-v="path.to.value" are filled from here when the deck loads. */
window.TALK = {
  // README.md, "The idea": four people, three days, every month.
  // challenges/challenge-07.md, Part D: the example values for the business case (400 pounds a person-day).
  // walkthrough/challenge-07/solution-07.md, "The business case, worked": 4,800 pounds today, about 250 pounds of review.
  month: { people: 4, days: 3, personDays: 12, dayCost: 400, today: '4,800', withAgent: '250' },

  // data/packs/distribution/pack.json and handbook.md: company, people, tolerance, period.
  company: {
    name: 'Ashgrove Supply', portal: 'Supplier Hub', tolerance: 'GBP 2.00', period: 'February 2027',
    expert: 'Graham Holt', approver: 'Dana Okoro', approverRole: 'Financial Controller',
  },

  // data/packs/distribution/statements/brightwell.csv (14 lines) and walkthrough/expected-results.md
  // (the six planted lines for Brightwell Packaging, with category and action).
  statement: {
    partner: 'Brightwell Packaging', lines: 14,
    rows: [
      ['INV-41001', 'Bin liners', '3,527.88'],
      ['INV-41002', 'Hi-vis vests', '3,476.55', 'dup'],
      ['INV-41003', 'Corrugated cartons', '589.74'],
      ['INV-41004', 'Bin liners', '1,149.52'],
      ['INV-41005', 'Nitrile gloves', '575.97'],
      ['INV-41006', 'not on their statement', '', 'mis'],
      ['INV-41007', 'Hand towels', '2,354.87', 'mm'],
      ['INV-41008', 'Bin liners', '1,824.19'],
      ['INV-41009', 'Packing tape', '1,879.38', 'tol'],
      ['INV-41010', 'Bin liners', '3,642.65'],
      ['INV-41011', 'Nitrile gloves', '2,402.03'],
      ['INV-41012', 'Hand towels', '2,507.16'],
      ['INV-41002', 'Hi-vis vests', '3,476.55', 'dup2'],
      ['INV-41013', 'Printer paper', '1,044.80', 'mil'],
      ['CN-478', 'Credit note: returned goods', '-273.01', 'cn'],
    ],
    planted: {
      mm:  { rule: 'Amount mismatch: 12.50 over', act: 'Raise price dispute' },
      tol: { rule: 'Within tolerance: 1.00', act: 'Nothing to chase' },
      mis: { rule: 'Missing on statement', act: 'Ask supplier to confirm invoice' },
      mil: { rule: 'Missing in ledger', act: 'Request copy invoice' },
      dup: { rule: 'Same reference twice', act: 'Raise duplicate-charge dispute' },
      cn:  { rule: 'Credit note', act: 'Confirm credit note' },
    },
  },

  // walkthrough/challenge-01/solution-01.md: first run, Brightwell, gpt-5.4-mini.
  firstRun: { seconds: 56, tokens: 222069 },

  // walkthrough/challenge-02/solution-02.md and images/challenge-02-score-before.png / -score-after.png.
  skill: {
    before: 4, after: 6, of: 6, beforeS: 56, afterS: 42, beforeTok: '148,232', afterTok: '239,080',
    apiBefore: 15, apiAfter: 30, apiOf: 30,
  },

  // challenges/challenge-03.md and walkthrough/challenge-03/solution-03.md: five suppliers, one request.
  // Northgate's four misses come from images/challenge-03-score-after-redo.png (26 of 30, all four Northgate's).
  fan: {
    seconds: 91, tokens: '698,295', score: 26, of: 30, northgate: 2,
    redoS: 23, redoScore: 30, spans: 124, chats: 35, tools: 40, traceS: 92,
    partners: ['Brightwell Packaging', 'Northgate Freight', 'Osric Office Supplies', 'Kellerman Hygiene', 'Tamsin Workwear'],
  },

  // walkthrough/challenge-04/solution-04.md and challenges/challenge-04.md: the ERP through the toolbox.
  erp: { seconds: 22, tokens: '70,736', exceptions: 5, notes: 3 },

  // walkthrough/challenge-05/solution-05.md, challenges/challenge-05.md and images/challenge-05-portal-cases.png.
  portal: {
    firstS: 510, firstTok: '1.26M', fixedS: 167, fixedQ: 2,
    billedBefore: '15 to 31 min', billedAfter: '3 min 34 s',
  },

  // walkthrough/challenge-06/solution-06.md: egress in Audit and Enforce, the hidden instruction.
  trust: { enforceS: 6, injectS: 53, injectScore: 6 },

  // walkthrough/challenge-07/solution-07.md and challenges/challenge-07.md, Parts A to C.
  models: {
    mini: { name: 'gpt-5.4-mini', s: 46, score: 6, tokens: 189488 },
    big: { name: 'gpt-5.4', s: 76, score: 6, tokens: 169072 },
    split: { cached: 85, input: 12, output: 3 },
    quota: '50K',
  },

  // walkthrough/challenge-03/solution-03.md and solution-07.md: API run, five suppliers, with the skill.
  month5: { time: '3 min 39 s', score: 30, of: 30 },
};
