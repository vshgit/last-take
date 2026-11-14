const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const html = fs.readFileSync(path.join(__dirname, 'web_shell.html'), 'utf8');
const script = html.split('<script>')[1].split('</script>')[0];

async function scenario(blocked) {
  const elements = Object.fromEntries(['canvas','loader','message','progress','play'].map(id => [id, {
    style: {}, addEventListener(event, fn) { this[event] = fn; }, focus() { this.focused = true; },
  }]));
  let began = 0, resumed = 0;
  const audio = {state: 'suspended', async resume() { resumed++; if (!blocked) this.state = 'running'; }};
  const win = new EventTarget();
  const context = {
    window: win, document: {getElementById: id => elements[id], addEventListener() {}},
    location: {href: 'https://test.invalid/', origin: 'https://test.invalid'},
    DecompressionStream, ReadableStream, Response, URL, Event, console, setTimeout, clearTimeout,
  };
  win.fetch = async () => new Response(JSON.stringify({'index.wasm': {size: 4, chunks: []}}));
  context.Engine = class {
    static getMissingFeatures() { return []; }
    async startGame() {
      win.lastTakeAudioContextCreated(audio);
      win.lastTakeBegin = () => began++;
      win.lastTakeGameReady = true;
      win.dispatchEvent(new Event('lasttake-ready'));
    }
  };
  vm.runInNewContext(script, context);
  await elements.play.click();
  assert.equal(began, 0, 'Loading must not begin a silent game automatically');
  assert.equal(resumed, 0, 'Audio activation belongs to the fresh start gesture');
  assert.equal(elements.play.textContent, 'НАЧАТЬ ИГРУ');
  await elements.play.onclick();
  assert.equal(resumed, 1);
  if (blocked) {
    assert.equal(began, 0, 'Blocked audio must not silently start the scene');
    assert.notEqual(elements.loader.style.display, 'none');
    assert.equal(elements.play.disabled, false, 'User can retry audio activation');
  } else {
    assert.equal(began, 1);
    assert.equal(elements.loader.style.display, 'none');
    assert.equal(elements.canvas.focused, true);
  }
}
(async () => {
  assert(!html.includes('Карточки на столе'));
  await scenario(false);
  await scenario(true);
  console.log('WEB_SHELL_CHECKS_PASSED: fresh audio gesture, ready handshake, blocked-audio retry, removed tagline');
})().catch(error => { console.error(error); process.exitCode = 1; });
