// Scratch harness: drive headless Chrome over CDP to capture exact-width
// screenshots of the Flutter web build and click through routes.
const { spawn } = require('child_process');
const fs = require('fs');
const path = require('path');
const WebSocket = require('ws');

const CHROME = 'C:/Program Files/Google/Chrome/Application/chrome.exe';
const PORT = 9333;
const URL = process.env.SHOT_URL || 'http://localhost:8090/';
const OUT = process.env.SHOT_OUT || path.join(__dirname, '..', 'shots');
const SCRIPTS = process.env.SHOT_SCRIPT || '';

function sleep(ms) { return new Promise((r) => setTimeout(r, ms)); }

async function json(pathname) {
  const res = await fetch(`http://127.0.0.1:${PORT}${pathname}`, { signal: AbortSignal.timeout(15000) });
  return res.json();
}

async function waitForTarget(timeoutMs = 45000) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    try {
      const targets = await json('/json/list');
      const page = targets.find((t) => t.type === 'page' && t.webSocketDebuggerUrl);
      if (page) return page;
    } catch {}
    await sleep(400);
  }
  throw new Error('no chrome page target');
}

let id = 0;
class Session {
  constructor(ws) { this.ws = ws; this.pending = new Map(); }
  send(method, params = {}) {
    const msgId = ++id;
    return new Promise((resolve, reject) => {
      this.pending.set(msgId, { resolve, reject });
      this.ws.send(JSON.stringify({ id: msgId, method, params }));
    });
  }
}

function semanticsTexts() {
  return `(() => {
    const out = [];
    const walk = (root) => {
      for (const el of root.querySelectorAll('*')) {
        const role = (el.getAttribute('role') || el.tagName || '').toLowerCase();
        const label = (el.getAttribute('aria-label') || el.textContent || '').trim();
        if (label) {
          const r = el.getBoundingClientRect();
          if (r.width > 0 && r.height > 0) {
            out.push({ role, label: label.slice(0, 60), x: Math.round(r.x + r.width/2), y: Math.round(r.y + r.height/2), w: Math.round(r.width), h: Math.round(r.height) });
          }
        }
        if (el.shadowRoot) walk(el.shadowRoot);
      }
    };
    walk(document);
    return out;
  })()`;
}

async function main() {
  fs.mkdirSync(OUT, { recursive: true });
  const udd = path.join(path.resolve(OUT), '.chrome-profile');
  fs.rmSync(udd, { recursive: true, force: true });
  const chrome = spawn(CHROME, [
    '--headless=new', '--disable-gpu', `--remote-debugging-port=${PORT}`,
    `--user-data-dir=${udd}`, '--no-first-run', '--no-default-browser-check',
    '--disable-features=Translate', 'about:blank',
  ], { stdio: 'ignore' });
  chrome.on('error', (e) => console.log('SPAWN ERR', e.message));
  chrome.on('exit', (code) => console.log('CHROME EXIT', code));

  const target = await waitForTarget();
  const ws = new WebSocket(target.webSocketDebuggerUrl, { perMessageDeflate: false });
  await new Promise((r, j) => { ws.on('open', r); ws.on('error', j); });
  const s = new Session(ws);
  ws.on('message', (buf) => {
    const m = JSON.parse(buf.toString());
    if (m.id && s.pending.has(m.id)) {
      const { resolve, reject } = s.pending.get(m.id);
      s.pending.delete(m.id);
      m.error ? reject(new Error(m.error.message)) : resolve(m.result);
    }
  });

  await s.send('Page.enable');
  await s.send('Runtime.enable');
  await s.send('Emulation.setDeviceMetricsOverride', { width: 390, height: 844, deviceScaleFactor: 1, mobile: true });
  await s.send('Page.navigate', { url: URL });
  await sleep(6000);

  const script = SCRIPTS ? JSON.parse(fs.readFileSync(SCRIPTS, 'utf8')) : [{ shot: 'home', w: 390, h: 844 }];
  for (const step of script) {
    if (step.size) {
      await s.send('Emulation.setDeviceMetricsOverride', { width: step.w || 390, height: step.h || 844, deviceScaleFactor: 1, mobile: (step.w || 390) < 900 });
      await sleep(step.after || 900);
    }
    if (step.wait) await sleep(step.wait);
    if (step.js) {
      const r = await s.send('Runtime.evaluate', { expression: step.js, returnByValue: true });
      console.log('JS', step.js.slice(0, 40), '->', JSON.stringify(r.result.value));
      await sleep(step.after || 800);
    }
    if (step.click) {
      const nodes = await s.send('Runtime.evaluate', { expression: semanticsTexts(), returnByValue: true });
      const list = nodes.result.value || [];
      const want = String(step.click).toLowerCase();
      let hits = list.filter((n) => n.label.toLowerCase().includes(want));
      if (step.exact) hits = hits.filter((n) => n.label.toLowerCase() === want);
      hits.sort((a, b) => a.label.length - b.label.length || a.w * a.h - b.w * b.h);
      if (!hits.length) { console.log('MISS click:', step.click, '| seen:', list.map((n) => n.label).slice(0, 25).join(' / ')); }
      else {
        const n = hits[0];
        console.log('CLICK', step.click, '->', n.label, `@${n.x},${n.y}`);
        for (const type of ['mousePressed', 'mouseReleased']) {
          await s.send('Input.dispatchMouseEvent', { type, x: n.x, y: n.y, button: 'left', clickCount: 1 });
        }
        await sleep(step.after || 1200);
      }
    }
    if (step.into) {
      const nodes = await s.send('Runtime.evaluate', { expression: semanticsTexts(), returnByValue: true });
      const want = String(step.into).toLowerCase();
      const matches = (nodes.result.value || []).filter((n) => n.label.toLowerCase().includes(want));
      const box = matches
        .sort((a, b) => (b.role.includes('textbox') - a.role.includes('textbox')) || a.w * a.h - b.w * b.h)[0];
      if (!box) console.log('MISS into:', step.into);
      else {
        await s.send('Input.dispatchMouseEvent', { type: 'mousePressed', x: box.x, y: box.y, button: 'left', clickCount: 1 });
        await s.send('Input.dispatchMouseEvent', { type: 'mouseReleased', x: box.x, y: box.y, button: 'left', clickCount: 1 });
        await sleep(400);
        for (const ch of String(step.text)) {
          await s.send('Input.dispatchKeyEvent', { type: 'char', text: ch, unmodifiedText: ch });
        }
        console.log('TYPE into', step.into, '=', step.text);
        await sleep(step.after || 400);
      }
    }
    if (step.tab) {
      await s.send('Input.dispatchKeyEvent', { type: 'keyDown', key: 'Tab', code: 'Tab', windowsVirtualKeyCode: 9 });
      await s.send('Input.dispatchKeyEvent', { type: 'keyUp', key: 'Tab', code: 'Tab', windowsVirtualKeyCode: 9 });
      await sleep(300);
    }
    if (step.scroll) {
      await s.send('Input.dispatchMouseEvent', { type: 'mouseWheel', x: 200, y: 400, deltaX: 0, deltaY: step.scroll });
      await sleep(700);
    }
    if (step.shot !== undefined) {
      await s.send('Emulation.setDeviceMetricsOverride', {
        width: step.w || 390, height: step.h || 844, deviceScaleFactor: 1, mobile: (step.w || 390) < 900,
      });
      await sleep(step.resizeWait || 1200);
      const png = await s.send('Page.captureScreenshot', { format: 'png' });
      const file = path.join(OUT, `${step.shot}.png`);
      fs.writeFileSync(file, Buffer.from(png.data, 'base64'));
      console.log('SHOT', file);
    }
  }

  ws.close();
  chrome.kill();
  process.exit(0);
}

main().catch((e) => { console.error('FAIL', e.message); process.exit(1); });
