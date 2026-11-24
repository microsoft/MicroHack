/* Measured numbers shown in the talk. Every value comes from a recorded run of the hack
   (23 November 2026, Snapdragon X Elite laptop, Foundry Local 0.14.0) and is also in the walkthroughs:
   bench    walkthrough/challenge-02/solution-02.md (benchmark.py)
   holdout  walkthrough/challenge-05/solution-05.md (check_routing.py holdout, with and without the router)
   onnx     walkthrough/challenge-05/solution-05.md (studio export, predict_fault)
   offline  walkthrough/challenge-06/solution-06.md (copilot.py with the internet blocked, then after a restart) */
window.TALK = {
  bench: [
    { name: 'phi-4-mini', meta: 'GPU · 3.8 GB', tps: 21.5, ft: 0.75, tools: 7, quality: 13, chosen: true },
    { name: 'qwen2.5-1.5b', meta: 'NPU · 1.1 GB · 47 s to load', tps: 3.8, ft: 1.18, tools: null, error: 'HTTP 500 with tools', quality: 13 },
    { name: 'qwen3-1.7b', meta: 'GPU · 1.4 GB', tps: 27.1, ft: 0.85, tools: 1, quality: 9, fastest: true },
  ],
  holdout: {
    // expected tool -> number of requests; misses list the requests phi-4-mini got wrong without the router
    columns: [
      { key: 'status', label: 'Machine status', n: 5 },
      { key: 'fault', label: 'Fault classifier', n: 5 },
      { key: 'sop', label: 'SOP search', n: 8 },
      { key: 'ticket', label: 'Ticket', n: 5 },
    ],
    misses: [
      { id: 'H07', col: 'fault', row: 2, text: 'Run a diagnosis on CNC-07.', want: 'fault classifier' },
      { id: 'H09', col: 'fault', row: 4, text: 'Classify the condition of PRESS-02.', want: 'fault classifier' },
      { id: 'H20', col: 'ticket', row: 2, text: 'Write up a high priority work order for CMP-01…', want: 'ticket' },
      { id: 'H22', col: 'ticket', row: 4, text: 'Create a service request for CONV-03…', want: 'ticket' },
    ],
    without: { correct: 19, seconds: 778 },
    with: { correct: 23, seconds: 230 },
  },
  onnx: {
    sha256: '112BB6233897B107C0C95BE6CC6593896C9732C32CE5C731DD9BA8B027378B1F',
    predictions: [
      ['CNC-07', 'bearing_wear', '0.98', '10.48 ms'],
      ['CMP-01', 'overheating', '1.00', '1.08 ms'],
      ['CNC-03', 'normal', '0.99', '0.70 ms'],
      ['LATHE-05', 'bearing_wear', '0.67', '0.30 ms'],
      ['PRESS-02', 'low_lubrication', '0.65', '0.33 ms'],
    ],
  },
  offline: {
    regions: ['westeurope', 'northeurope', 'francecentral', 'germanywestcentral', 'uksouth', 'swedencentral', 'eastus', 'uaenorth'],
    // name, detail, time offline, detail after restart, time after restart
    checks: [
      ['Local model answers', 'phi-4-mini on the laptop GPU', '1.74 s', 'phi-4-mini on the laptop GPU', 'ok'],
      ['Machine status', 'CNC-07 · FAULT · E-SPN-214', '8.9 s', 'CNC-07 · FAULT · E-SPN-214', '11.7 s'],
      ['Fault prediction', 'ONNX · bearing wear, 98%', '8.4 s', 'ONNX · bearing wear, 98%', '7.9 s'],
      ['SOP answer with sources', 'SOP-CNC-001 rev C', '14.4 s', 'SOP-CNC-001 rev C', '13.8 s'],
      ['Ticket, after approval', 'MT-1003 · high priority', '4.9 s', 'MT-1004 · high priority', '4.7 s'],
    ],
    restart: ['Service restarted, still offline', 'models load from the local cache', '5 s + 3 s'],
  },
};
