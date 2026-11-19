const test = require('node:test');
const assert = require('node:assert/strict');
const { route } = require('../src/app');

const version = 'test';
const healthyDb = {
  query: async (sql) => (sql.startsWith('SELECT id')
    ? { rows: [{ id: 1, name: 'Site vitrine' }] }
    : { rows: [{ '?column?': 1 }] })
};
const brokenDb = { query: async () => { throw new Error('connexion refusée'); } };

test('GET /health renvoie 200 quand la base répond', async () => {
  const result = await route('GET', '/health', { db: healthyDb, version });
  assert.equal(result.status, 200);
  assert.deepEqual(result.body, { status: 'ok', version: 'test', database: 'ok' });
});

test('GET /health renvoie 503 quand la base est indisponible', async () => {
  const result = await route('GET', '/health', { db: brokenDb, version });
  assert.equal(result.status, 503);
  assert.equal(result.body.database, 'down');
});

test('GET /api/projects renvoie la liste des projets', async () => {
  const result = await route('GET', '/api/projects', { db: healthyDb, version });
  assert.equal(result.status, 200);
  assert.deepEqual(result.body.projects, [{ id: 1, name: 'Site vitrine' }]);
});

test('une route inconnue renvoie 404', async () => {
  const result = await route('GET', '/inconnue', { db: healthyDb, version });
  assert.equal(result.status, 404);
});
