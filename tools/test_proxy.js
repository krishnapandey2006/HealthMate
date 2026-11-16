#!/usr/bin/env node
/**
 * Smoke test for a running HealthMate proxy.
 *
 * Usage:
 *   node tools/healthmate_server.js        # in another terminal
 *   node tools/test_proxy.js
 *
 * Override the target with HEALTHMATE_PROXY_URL when testing a deployment.
 */

const baseUrl = (process.env.HEALTHMATE_PROXY_URL || 'http://localhost:8787').replace(/\/+$/, '');

async function get(path) {
  const response = await fetch(`${baseUrl}${path}`, {
    headers: { Accept: 'application/json' },
    signal: AbortSignal.timeout(15000),
  });
  const text = await response.text();
  let body;
  try {
    body = JSON.parse(text);
  } catch {
    throw new Error(`${path} returned non-JSON (HTTP ${response.status}): ${text.slice(0, 120)}`);
  }
  return { status: response.status, body };
}

async function main() {
  console.log(`Checking HealthMate proxy at ${baseUrl}`);

  const health = await get('/api/health');
  if (health.status !== 200 || health.body.status !== 'ok') {
    throw new Error(`/api/health is not healthy: HTTP ${health.status} ${JSON.stringify(health.body)}`);
  }
  const sources = health.body.sources || {};
  for (const name of ['news', 'geocode', 'facilities']) {
    if (!sources[name]) {
      throw new Error(`/api/health is missing the "${name}" source`);
    }
  }
  console.log(`  health: ok`);
  console.log(`  news: ${sources.news}`);
  console.log(`  geocode: ${sources.geocode}`);
  console.log(`  facilities: ${sources.facilities}`);

  const healthAgain = await get('/api/health');
  if (healthAgain.status !== 200) {
    throw new Error('/api/health failed on the second request');
  }
  console.log('  repeat request: ok');

  console.log('Proxy smoke test passed.');
}

main().catch((error) => {
  console.error(`Proxy smoke test failed: ${error.message}`);
  console.error(`Is the proxy running? Try: node tools/healthmate_server.js`);
  process.exitCode = 1;
});
