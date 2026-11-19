const { Pool } = require('pg');
const { createServer } = require('./app');

const version = process.env.APP_VERSION || 'dev';
const port = Number(process.env.PORT || 3000);

const db = new Pool({
  host: process.env.DB_HOST,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
  connectionTimeoutMillis: 2000,
  query_timeout: 2000
});
db.on('error', (error) => console.error(error.message));

async function start() {
  await db.query('CREATE TABLE IF NOT EXISTS projects (id integer PRIMARY KEY, name text NOT NULL)');
  await db.query(
    'INSERT INTO projects VALUES ($1, $2), ($3, $4) ON CONFLICT DO NOTHING',
    [1, 'Site vitrine', 2, 'Portail client']
  );
  createServer({ db, version }).listen(port, '0.0.0.0', () => {
    console.log(`websolutions-api ${version} en écoute sur ${port}`);
  });
}

start().catch((error) => {
  console.error(error.message);
  process.exit(1);
});
