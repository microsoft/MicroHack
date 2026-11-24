/* Every number on the slides, with the file it comes from. Paths are relative to the hack folder
   (03-Azure/01-04-AI/03_Inventory_Planning_Agentic). Nothing here is invented: values are copied from
   the seed data, derived with the hack's own rules, or read off the recorded screenshots in images/. */
window.TALK = (() => {
  // src/data/products.json (name, category, unitCost, leadTimeDays, baseWeeklyUnits, baseOnHand)
  const products = [
    { id: 'P001', name: 'Lawn Mower Pro', cat: 'garden_and_lawn', cost: 180, lead: 14, weekly: 8, base: 40 },
    { id: 'P002', name: 'Garden Hose 50ft', cat: 'garden_and_lawn', cost: 25, lead: 7, weekly: 30, base: 150 },
    { id: 'P003', name: 'Fertilizer 20lb', cat: 'garden_and_lawn', cost: 18, lead: 10, weekly: 45, base: 200 },
    { id: 'P004', name: 'Leaf Blower X2', cat: 'outdoor_power_tools', cost: 95, lead: 21, weekly: 20, base: 30 },
    { id: 'P005', name: 'Chainsaw 16in', cat: 'outdoor_power_tools', cost: 140, lead: 21, weekly: 12, base: 25 },
    { id: 'P006', name: 'Hedge Trimmer', cat: 'outdoor_power_tools', cost: 85, lead: 18, weekly: 15, base: 28 },
    { id: 'P007', name: 'Interior Paint 1gal', cat: 'paint_and_supplies', cost: 22, lead: 7, weekly: 50, base: 300 },
    { id: 'P008', name: 'Paint Roller Set', cat: 'paint_and_supplies', cost: 12, lead: 5, weekly: 40, base: 250 },
    { id: 'P009', name: 'Painters Tape', cat: 'paint_and_supplies', cost: 6, lead: 5, weekly: 60, base: 400 },
    { id: 'P010', name: 'Smart Thermostat', cat: 'smart_home', cost: 110, lead: 12, weekly: 18, base: 90 },
    { id: 'P011', name: 'Video Doorbell', cat: 'smart_home', cost: 130, lead: 12, weekly: 16, base: 80 },
    { id: 'P012', name: 'Smart Plug 4-pack', cat: 'smart_home', cost: 28, lead: 9, weekly: 35, base: 180 },
  ];
  // src/data/stores.json
  const stores = [
    { id: 'ST01', name: 'Boston', type: 'retail' },
    { id: 'ST02', name: 'Brooklyn', type: 'retail' },
    { id: 'ST03', name: 'Portland', type: 'retail' },
    { id: 'ST04', name: 'Seattle', type: 'retail' },
    { id: 'WH01', name: 'Chicago', type: 'warehouse' },
    { id: 'WH02', name: 'Dallas', type: 'warehouse' },
  ];
  // src/data/inventory_overrides.json
  const overrides = { 'P004|ST03': 8, 'P004|ST04': 6, 'P004|WH01': 45, 'P004|WH02': 40, 'P005|ST03': 5, 'P005|ST04': 7, 'P006|ST03': 12 };

  // The same rules as _derive_inventory in src/inventory_store.py and _status in src/tools.py:
  // reorderPoint = ceil(weekly * lead / 7), safetyStock = ceil(reorderPoint * 0.5),
  // warehouses hold 4 x baseOnHand, CRITICAL when onHand < safetyStock, AT_RISK when onHand <= reorderPoint.
  const shelf = products.map(p => {
    const rp = Math.ceil(p.weekly * p.lead / 7), ss = Math.ceil(rp * 0.5);
    return stores.map(s => {
      const key = `${p.id}|${s.id}`;
      const onHand = key in overrides ? overrides[key] : (s.type === 'warehouse' ? p.base * 4 : p.base);
      const status = onHand < ss ? 'CRITICAL' : onHand <= rp ? 'AT_RISK' : 'OK';
      return { sku: p.id, loc: s.id, onHand, rp, ss, status };
    });
  });
  const flat = shelf.flat();
  const exposure = {
    cells: flat.length,                                            // 12 SKUs x 6 locations = 72
    exposed: flat.filter(c => c.status !== 'OK').length,           // 14, as the console header shows
    critical: flat.filter(c => c.status === 'CRITICAL').length,    // 5
    atRisk: flat.filter(c => c.status === 'AT_RISK').length,       // 9
  };

  // src/data/external_signals.json, SIG01
  const signal = { id: 'SIG01', type: 'weather', source: 'WeatherIQ', score: 0.80,
    headline: 'Prolonged heatwave and early spring across the Pacific Northwest',
    cats: ['outdoor_power_tools', 'garden_and_lawn'] };

  // _derive_demand in src/inventory_store.py for P004 (all four retail stores): 20 / 4 = 5 a store a week,
  // x 1.4 for outdoor power tools in the last two weeks = 7 a store, so 20 a week, then 28.
  // Weeks start on Mondays ending at the anchor 2026-07-06.
  const leafBlower = {
    weeks: [['1 Jun', 20], ['8 Jun', 20], ['15 Jun', 20], ['22 Jun', 20], ['29 Jun', 28], ['6 Jul', 28]],
    perDay: 4.0,      // average_daily_sales: 28 / 7
    thirty: 120,      // calc_reorder: round(4.0 * 30)
    onHandSeattle: 6, // inventory_overrides.json, P004 at ST04
    order: 114,       // max(0, 120 - 6), the first line of the recorded plan
  };

  // images/challenge-03-approve.png: the recorded manual run (Steps 1 to 4)
  const manualRun = {
    header: '12 SKUs · 6 locations · 14 exposed',
    lines: [
      ['Leaf Blower X2', 'ST04', 114, 95], ['Leaf Blower X2', 'ST03', 112, 95],
      ['Chainsaw 16in', 'ST03', 64, 140], ['Chainsaw 16in', 'ST04', 62, 140],
      ['Hedge Trimmer', 'ST03', 91, 85], ['Hedge Trimmer', 'ST04', 75, 85],
    ],
    total: 53220,
    scenario: 'A prolonged heatwave is hitting the Pacific Northwest. Check our exposure on outdoor power tools.',
  };

  // images/challenge-02-trace.png: the Foundry trace of inventory-optimisation-agent:1
  const trace = { invokeS: 1.17, toolMs: 753, spans: 2, toolCalls: 1, totalS: 1.2,
    calls: ['calc_reorder  P004  ST03', 'calc_reorder  P004  ST04', 'query_inventory  P005', 'query_inventory  P004'] };

  // images/challenge-05-reactive.png: the recorded event-driven run and its activity log
  const reactive = {
    headline: 'Heatwave intensifies across the Pacific Northwest',
    log: [['9:11:08 PM', 'signal received'], ['9:11:16 PM', 'step 1 sensed'], ['9:11:29 PM', 'step 2 planned'],
      ['9:11:35 PM', 'step 3 proposed'], ['9:11:35 PM', 'awaiting human approval']],
    secondsToGate: 27,  // 9:11:08 to 9:11:35
    lines: [['Leaf Blower X2', 'ST04', 114, 95, 10830], ['Chainsaw 16in', 'ST03', 64, 140, 8960], ['Hedge Trimmer', 'ST03', 91, 85, 7735]],
    total: 27525,
    orderBook: [['ORD-1004', 'submitted', 'Jordan Lee'], ['ORD-1003', 'rejected', 'Sam Rivera'], ['ORD-1002', 'completed', 'Sam Rivera']],
  };

  // README.md, challenge list (minutes)
  const day = [
    { n: 1, title: 'Set up and explore', min: 60, builds: 'the console' },
    { n: 2, title: 'Demand Sensing', min: 60, builds: 'agent 1' },
    { n: 3, title: 'Inventory Optimisation', min: 60, builds: 'agent 2 + trace' },
    { n: 4, title: 'Replenishment + approval', min: 75, builds: 'agent 3 + the gate' },
    { n: 5, title: 'Connect the loop', min: 45, builds: 'one-click loop', stretch: true },
    { n: 6, title: 'The loop starts itself', min: 60, builds: 'event trigger', stretch: true },
  ];

  return { products, stores, shelf, exposure, signal, leafBlower, manualRun, trace, reactive, day,
    watcherPollS: 3 };   // src/live.py: time.sleep(3) between change-feed polls
})();
