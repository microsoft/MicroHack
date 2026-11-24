/* Every number shown on the slides, with the file it comes from.
   Paths are relative to the hack folder 03-Azure/01-04-AI/11_Healthcare_Regulatory_Intelligence.
   Nothing here was measured for the talk: these are the hack's own recorded runs and data. */
window.DATA = {
  // walkthrough/challenge-01/solution-01.md, "Expected monitor output (Monday)" and the repeat run.
  monitor: {
    run1: { pages: 15, indexPages: 5, linksNotFollowed: 2, newDocs: 9, duplicates: 1, events: 9 },
    run2: { newDocs: 0, duplicates: 10, events: 0 },
    // walkthrough/challenge-02/solution-02.md, "Expected answer after Tuesday's crawl" (run 3).
    run3: { updated: 1, newDocs: 0, duplicates: 9, events: 1 },
  },

  // walkthrough/challenge-03/solution-03.md, "Model settings: why medium reasoning".
  // impact-agent on EU-SA-2027-004 (3 runs), US-EL-2027-007 (2) and UK-REG-2027-001 (2).
  // The order of passes and misses within a row is not recorded: the slide sorts passes first.
  settings: [
    { name: 'Reasoning off, temperature 0', right: 3, runs: 7, tokens: 1600 },
    { name: 'Reasoning low (portal default)', right: 6, runs: 7, tokens: 2300 },
    { name: 'Reasoning medium', right: 7, runs: 7, tokens: 9500 },
  ],

  // challenges/challenge-03.md (note under Part A): medium about a minute, low about 20 seconds.
  latency: { mediumSeconds: 60, lowSeconds: 20 },
};
