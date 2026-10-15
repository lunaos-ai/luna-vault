const { test } = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const path = require('node:path');
const source = fs.readFileSync(path.join(__dirname, '../src/authenticator-bridge.js'), 'utf8');
const uri = 'otpauth://totp/PushCI:test?secret=JBSWY3DPEHPK3PXP&issuer=PushCI';

function bridge(origin = 'https://app.pushci.dev', iframe = false) {
  const sent = [], published = [], listeners = [];
  const window = { addEventListener: (_, cb) => listeners.push(cb), postMessage: (data, target) => published.push({ data, target }) };
  window.top = iframe ? {} : window;
  const runtime = { sendMessage: (data, callback) => {
    sent.push(data); callback({ ok: true, error: uri });
  }};
  vm.runInNewContext(source, { location: new URL(origin), window, URL, chrome: { runtime } });
  const message = (data, extra = {}) => listeners.forEach(fn => fn({ data, source: window, origin, ...extra }));
  return { sent, published, message, window, runtime };
}

test('serves only top-level trusted HTTPS origins', () => {
  for (const origin of ['https://app.pushci.dev', 'https://staging.pushci.dev', 'https://amliq.finance']) {
    assert.equal(bridge(origin).sent[0].type, 'VV_PING_NATIVE');
  }
  for (const origin of ['https://evil.invalid', 'https://app.pushci.dev.evil.invalid', 'http://app.pushci.dev']) {
    assert.equal(bridge(origin).sent.length, 0);
  }
  assert.equal(bridge('https://app.pushci.dev', true).sent.length, 0);
});

test('supports late-mounted pages and correlates native handoff responses', () => {
  const b = bridge();
  b.message({ type: 'VV_AUTHENTICATOR_CHECK' });
  assert.equal(b.sent.filter(x => x.type === 'VV_PING_NATIVE').length, 2);
  b.message({ type: 'VV_SAVE_AUTHENTICATOR', requestId: 'request-1', otpauthURI: uri });
  assert.equal(b.sent.at(-1).payload.otpauthURI, uri);
  assert.equal(b.published.at(-1).data.requestId, 'request-1');
  assert.equal(b.published.at(-1).data.code, 'review_in_app');
  assert.equal(b.published.at(-1).target, 'https://app.pushci.dev');
  assert.equal(JSON.stringify(b.published).includes('secret='), false);
});

test('ignores cross-origin messages, other windows and invalid payloads', () => {
  const b = bridge();
  const request = { type: 'VV_SAVE_AUTHENTICATOR', requestId: 'request-1', otpauthURI: uri };
  b.message(request, { origin: 'https://evil.invalid' });
  b.message(request, { source: {} });
  b.message({ ...request, otpauthURI: 'https://example.com/?secret=x' });
  b.message({ ...request, otpauthURI: 'otpauth://hotp/test?secret=abc' });
  b.message({ ...request, requestId: {} });
  b.message({ ...request, otpauthURI: 'x'.repeat(16_385) });
  assert.equal(b.sent.length, 1);
});

test('redacts native failures and prevents overlapping imports', () => {
  const b = bridge();
  let reply;
  b.runtime.sendMessage = (data, callback) => { b.sent.push(data); reply = callback; };
  b.message({ type: 'VV_SAVE_AUTHENTICATOR', requestId: 'a', otpauthURI: uri });
  b.message({ type: 'VV_SAVE_AUTHENTICATOR', requestId: 'b', otpauthURI: uri });
  assert.equal(b.sent.length, 2);
  reply({ ok: false, error: uri });
  assert.equal(b.published.at(-1).data.ok, false);
  assert.equal(JSON.stringify(b.published).includes('secret='), false);
});
