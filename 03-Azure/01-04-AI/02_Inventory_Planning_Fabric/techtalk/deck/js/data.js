/* Every number on the slides, with its source.
   Seed data: setup/Setup-InventoryDataAgent.ipynb (cells 2 and 3 build the seven Lakehouse tables;
   the same rows are in data/*.parquet). Derived values are computed here from those rows and say so. */
window.TALK = {
  // setup/Setup-InventoryDataAgent.ipynb, cell 2: products, stores, signals, orders. Cell 3: 72 inventory rows.
  lakehouse: [
    { table: 'Inventory', rows: 72, what: 'onHand, reorderPoint, safetyStock' },
    { table: 'DemandHistory', rows: 288, what: 'weekly units, retail stores only' },
    { table: 'ExternalSignals', rows: 8, what: 'weather, search, competitor, supply' },
    { table: 'Products', rows: 12, what: 'unitCost, leadTimeDays, supplierId' },
    { table: 'Stores', rows: 6, what: '4 retail stores, 2 warehouses' },
    { table: 'Suppliers', rows: 4, what: 'name, region, reliabilityScore' },
    { table: 'ReplenishmentOrders', rows: 4, what: 'past orders and approvers' },
  ],

  // P004 Leaf Blower X2 (notebook cell 2: unitCost 95, leadTimeDays 21, supplier S02, baseWeeklyUnits 20).
  // reorderPoint = ceil(20 x 21 / 7) = 60, safetyStock = ceil(60 x 0.5) = 30 (cell 3).
  p004: { name: 'Leaf Blower X2', sku: 'P004', unitCost: 95, leadTimeDays: 21, reorderPoint: 60, safetyStock: 30 },

  // DemandHistory for P004 at the Seattle store (cell 3): round(20 / 4) = 5 a week, and the last two
  // weeks x 1.4 = 7 (the "recent demand spike" in the notebook). Weeks start 1 Jun to 6 Jul 2026.
  weekly: [
    { week: '1 Jun', units: 5 }, { week: '8 Jun', units: 5 }, { week: '15 Jun', units: 5 },
    { week: '22 Jun', units: 5 }, { week: '29 Jun', units: 7 }, { week: '6 Jul', units: 7 },
  ],
  weeklyAverage: 5.7, // (4 x 5 + 2 x 7) / 6 = 5.67, the average the Challenge 3 reorder rule uses

  // ExternalSignals rows SIG01, SIG02, SIG07 (cell 2). SIG07 names P004's own supplier, PowerTool Depot.
  signals: [
    { id: 'SIG01', type: 'weather', headline: 'Prolonged heatwave and early spring across the Pacific Northwest', score: 0.80 },
    { id: 'SIG02', type: 'search_trend', headline: 'Sharp spike in online searches for leaf blowers and lawn tools', score: 0.75 },
    { id: 'SIG07', type: 'supply', headline: 'Supplier delay reported at PowerTool Depot', score: 0.65 },
  ],

  // Inventory overrides for the story SKUs (cell 2): P004 Seattle 6, Portland 8.
  // Derived: days on the shelf = onHand / (7 units a week / 7) = onHand days at the latest weekly rate.
  runway: [
    { store: 'Seattle', onHand: 6 },
    { store: 'Portland', onHand: 8 },
  ],

  // The Challenge 1 test question and its expected answer (challenge-01.md, task 4g; images/challenge-00-agent-test.png).
  question: 'How many Leaf Blower X2 units are on hand at the Portland and Seattle stores, and are they below safety stock?',
  answer: [
    { store: 'Portland', id: 'ST03', onHand: 8, safetyStock: 30, reorderPoint: 60 },
    { store: 'Seattle', id: 'ST04', onHand: 6, safetyStock: 30, reorderPoint: 60 },
  ],

  // walkthrough/challenge-03/solution-03.md, sample recommendation table. avg daily = avg weekly / 7.
  // 30-day demand: P004 5.67 / 7 x 30 = 24.3, P006 4.67 / 7 x 30 = 20 (P006 sells 4 a week, then 6).
  refill: [
    { sku: 'P004', product: 'Leaf Blower X2', store: 'Seattle', onHand: 6, demand30: 24, order: 18 },
    { sku: 'P004', product: 'Leaf Blower X2', store: 'Portland', onHand: 8, demand30: 24, order: 16 },
    { sku: 'P006', product: 'Hedge Trimmer', store: 'Portland', onHand: 12, demand30: 20, order: 8 },
  ],

  // challenges/challenge-04.md: the sample table, the $20 fallback in the instructions, MODIFY 1 50, YES.
  // Unit costs from Products (P004 $95, P006 $85), also stated in challenge-05.md troubleshooting.
  po: {
    lines: [
      { sku: 'P004', store: 'Seattle', qty: 18, cost: 95 },
      { sku: 'P004', store: 'Portland', qty: 16, cost: 95 },
      { sku: 'P006', store: 'Portland', qty: 8, cost: 85 },
    ],
    fallback: 20,
    guessTotal: 840,     // 42 units x $20
    countedTotal: 3910,  // 18 x 95 + 16 x 95 + 8 x 85
    modifyQty: 50,       // MODIFY 1 50
    modifiedLine: 4750,  // 50 x 95
    modifiedTotal: 6950, // 4750 + 1520 + 680
  },

  // challenges/challenge-05.md and walkthrough/challenge-05/solution-05.md.
  workflow: { supportedUntil: '30 November 2026', retires: '1 December 2026' },
};
