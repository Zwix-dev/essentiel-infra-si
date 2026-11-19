const http = require('node:http');

// Logique des routes, sans dépendance réseau : testable avec une fausse base.
async function route(method, url, { db, version }) {
  if (method === 'GET' && url === '/health') {
    try {
      await db.query('SELECT 1');
      return { status: 200, body: { status: 'ok', version, database: 'ok' } };
    } catch {
      return { status: 503, body: { status: 'error', version, database: 'down' } };
    }
  }

  if (method === 'GET' && url === '/api/projects') {
    const result = await db.query('SELECT id, name FROM projects ORDER BY id');
    return { status: 200, body: { projects: result.rows } };
  }

  return { status: 404, body: { error: 'route introuvable' } };
}

function createServer(deps) {
  return http.createServer(async (req, res) => {
    let result;
    try {
      result = await route(req.method, req.url, deps);
    } catch (error) {
      console.error(error.message);
      result = { status: 500, body: { error: 'erreur interne' } };
    }
    res.writeHead(result.status, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify(result.body));
  });
}

module.exports = { route, createServer };
