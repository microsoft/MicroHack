import express from "express";
import sql from "mssql";

const app = express();
app.use(express.json());
app.use(express.static("public"));

const port = process.env.PORT || 3000;
  
// --- SQL config (SQL Auth) ---
function getSqlConfig() {
  const server = process.env.SQL_SERVER;     // e.g. <mi-public-endpoint>,3342 (if using MI public endpoint)
  const database = process.env.SQL_DATABASE; // your DB name
  const user = process.env.SQL_USER;         // SQL login
  const password = process.env.SQL_PASSWORD; // SQL password

  if (!server || !database || !user || !password) {
    throw new Error("Missing SQL env vars. Set SQL_SERVER, SQL_DATABASE, SQL_USER, SQL_PASSWORD.");
  }

  return {
    server,
    database,
    user,
    password,
    options: {
      encrypt: true,
      trustServerCertificate: false
    },
    pool: {
      max: 10,
      min: 0,
      idleTimeoutMillis: 30000
    }
  };
}

let poolPromise = null;
async function getPool() {
  if (!poolPromise) {
    const cfg = getSqlConfig();
    poolPromise = sql.connect(cfg);
  }
  return poolPromise;
}

app.get("/health", (_req, res) => res.json({ ok: true }));

app.post("/api/purchase", async (req, res) => {
  try {
    const customerName = String(req.body.customerName ?? "").trim();
    const email = String(req.body.email ?? "").trim();
    const amountRaw = req.body.amount;

    // Basic validation
    if (!customerName || customerName.length > 200) {
      return res.status(400).json({ ok: false, message: "CustomerName is required (max 200 chars)." });
    }
    if (!email || email.length > 320 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      return res.status(400).json({ ok: false, message: "Valid Email is required (max 320 chars)." });
    }
    const amount = Number.parseInt(amountRaw, 10);
    if (!Number.isFinite(amount) || amount <= 0) {
      return res.status(400).json({ ok: false, message: "Amount must be a positive integer." });
    }

    const pool = await getPool();
    const request = pool.request();

    // Call stored procedure
    const result = await request
      .input("CustomerName", sql.NVarChar(200), customerName)
      .input("Email", sql.NVarChar(320), email)
      .input("Amount", sql.Int, amount)
      .execute("dbo.usp_PurchaseSpaceRanger");

    // If your proc returns anything, we pass it through; otherwise just OK.
    const recordset = result?.recordset ?? null;

    res.json({
      ok: true,
      message: "Order submitted successfully!",
      data: recordset
    });
  } catch (err) {
    console.error("Purchase error:", err);
    res.status(500).json({
      ok: false,
      message: "Server error while submitting the order."
    });
  }
});

app.listen(port, () => {
  console.log(`Fabric Space Ranger app running on port ${port}`);
});