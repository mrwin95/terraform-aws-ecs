const sql = require("mssql");

const config = {
  user: "win_dec",
  password: "Thang@123",
  server: "10.20.0.20",
  database: "test2019",
  options: {
    encrypt: false,
    trustServerCertificate: false,
  },
};

async function testConnection() {
  try {
    const pool = await sql.connect(config);
    console.log("Connected to SQL");

    const result = await pool.request().query("SELECT @@VERSION AS Version");
    console.log("Query Result: ", result.recordset[0].Version);
    await pool.close();
  } catch (error) {
    console.error("SQL Connection error: ", error);
  }
}

testConnection();
