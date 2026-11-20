'use strict';

// Node 22+ and a local Chromium installation. Run against the exported game.
const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const os = require('node:os');
const path = require('node:path');
const {spawn} = require('node:child_process');
const pause = ms => new Promise(resolve => setTimeout(resolve, ms));
const url = new URL(process.env.KB_GAME_URL || 'http://127.0.0.1:8065/');
url.searchParams.set('qa', '1');
const chrome = process.env.CHROME_BIN || (process.platform === 'darwin'
  ? '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome' : 'google-chrome');

async function connect(port, processHandle) {
  let target;
  for (let i = 0; i < 100 && !target; i++) {
    if (processHandle.exitCode !== null) throw Error('Chrome exited during startup');
    try {
      const [number] = (await fs.readFile(port, 'utf8')).split('\n');
      const tabs = await (await fetch('http://127.0.0.1:' + number + '/json/list')).json();
      target = tabs.find(t => t.type === 'page');
    } catch { await pause(120); }
  }
  assert(target, 'No Chrome page available');
  const ws = new WebSocket(target.webSocketDebuggerUrl);
  const pending = new Map(), errors = [];
  let sequence = 0;
  await new Promise((resolve, reject) => { ws.onopen = resolve; ws.onerror = reject; });
  ws.onmessage = event => {
    const m = JSON.parse(event.data);
    if (m.id && pending.has(m.id)) {
      const {resolve, reject} = pending.get(m.id);
      pending.delete(m.id);
      if (m.error) reject(Error(m.error.message));
      else resolve(m.result);
    } else if (m.method === 'Runtime.exceptionThrown') {
      errors.push(m.params.exceptionDetails.exception?.description || m.params.exceptionDetails.text);
    } else if (m.method === 'Runtime.consoleAPICalled' && m.params.type === 'error') {
      errors.push(m.params.args.map(a => a.description || a.value).join(' '));
    }
  };
  function send(method, params = {}) {
    const id = ++sequence;
    return new Promise((resolve, reject) => {
      pending.set(id, {resolve, reject});
      ws.send(JSON.stringify({id, method, params}));
    });
  }
  async function value(expression) {
    const r = await send('Runtime.evaluate', {expression, returnByValue: true, awaitPromise: true});
    if (r.exceptionDetails) throw Error(r.exceptionDetails.exception?.description || expression);
    return r.result.value;
  }
  async function wait(expression, label, timeout = 12000) {
    const deadline = Date.now() + timeout;
    while (Date.now() < deadline) {
      if (await value('!!(' + expression + ')')) return;
      await pause(170);
    }
    throw Error(label + ': ' + JSON.stringify(await value('({boot:window.kbBootStages,state:window.kbGodotState?.drive,enter:window.kbGodotState?.enter_uv})')) + ' ' + errors.join('\n'));
  }
  async function screenshot(name) {
    if (!process.env.KB_SHOTS) return;
    const {data} = await send('Page.captureScreenshot', {format: 'png'});
    await fs.mkdir(process.env.KB_SHOTS, {recursive: true});
    await fs.writeFile(path.join(process.env.KB_SHOTS, name + '.png'), Buffer.from(data, 'base64'));
  }
  async function clickAt(x, y) {
    await send('Input.dispatchMouseEvent', {type:'mouseMoved',x,y});
    await send('Input.dispatchMouseEvent', {type:'mousePressed',x,y,button:'left',clickCount:1});
    await send('Input.dispatchMouseEvent', {type:'mouseReleased',x,y,button:'left',clickCount:1});
  }
  async function tapAt(x, y) {
    await send('Input.dispatchTouchEvent', {type:'touchStart',touchPoints:[{x,y,id:1}]});
    await pause(100);
    await send('Input.dispatchTouchEvent', {type:'touchEnd',touchPoints:[]});
  }
  async function atUV(uv, touch) {
    const box = await value('(()=>{const r=document.querySelector("canvas").getBoundingClientRect();return [r.left,r.top,r.width,r.height]})()');
    assert(uv?.length === 2 && uv.every(v => v > 0 && v < 1), 'Control outside the viewport: '+uv);
    return (touch ? tapAt : clickAt)(box[0]+uv[0]*box[2],box[1]+uv[1]*box[3]);
  }
  await send('Runtime.enable');
  await send('Page.enable');
  return {send,value,wait,screenshot,clickAt,atUV,errors,close:() => ws.close()};
}

async function enter(b, mobile) {
  await b.send('Emulation.setTouchEmulationEnabled', mobile ? {enabled:true,maxTouchPoints:5} : {enabled:false});
  await b.send('Emulation.setDeviceMetricsOverride', mobile
    ? {width:852,height:393,deviceScaleFactor:2,mobile:true}
    : {width:1280,height:800,deviceScaleFactor:1,mobile:false});
  await b.send('Page.navigate', {url:url.href});
  await b.send('Page.bringToFront');
  await b.wait('window.kbGodotState?.warmup.ready','city startup',80000);
  assert.equal(await b.value('kbGodotState.mobile'), mobile);
  await b.atUV(await b.value('kbGodotState.enter_uv'),mobile);
  await b.wait('kbGodotState.started','enter city');
}
async function touch(b) {
  await enter(b,true);
  const control = async name => b.atUV(await b.value('kbGodotState.touch_uv.' + name),true);
  await b.wait('kbGodotState.touch_uv.sprint','touch controls');
  const yaw = () => b.value('kbGodotState.yaw');
  const before = await yaw();
  const stick = {x:85,y:236,id:1}, look = {x:545,y:115,id:2};
  const touches = (type, points) => b.send('Input.dispatchTouchEvent',{type,touchPoints:points});
  await touches('touchStart',[stick]);
  await touches('touchMove',[{...stick,y:211}]);
  await touches('touchStart',[{...stick,y:211},look]);
  await pause(450);
  assert(Math.abs(await yaw()-before)<.015,'Planting the look thumb rotated the camera');
  await touches('touchMove',[{...stick,y:211},{...look,x:568}]);
  await b.wait('Math.abs(kbGodotState.yaw-('+before+'))>.04','independent look drag');
  const turn=await yaw();
  assert(Math.abs(turn-before)<.75,'Look drag jumped across the viewport');
  await touches('touchEnd',[{...look,x:568}]);
  await touches('touchEnd',[]);
  await pause(450);
  assert(Math.abs(await yaw()-turn)<.015,'Lifting the move thumb rotated the camera');
  await control('sprint');
  await b.wait('kbGodotState.touch_sprint','tap to sprint');
  await pause(300);
  assert(await b.value('kbGodotState.touch_sprint'));
  await control('sprint');
  await b.wait('!kbGodotState.touch_sprint','tap to end sprint');
  await control('map');
  await b.wait('kbGodotState.map_open && kbGodotState.audio_paused','touch map and audio pause');
  await b.screenshot('touch-map');
  console.log('Touch input passed at 852 by 393 CSS pixels with device scale 2');
}
async function desktop(b) {
  await enter(b,false);
  await b.atUV([.50,.55],false);
  await b.wait('document.pointerLockElement','mouse capture');
  await b.screenshot('waterfront');
  assert.equal(await b.value('kbGodotState.sounding_cruisers'),0);
  const key = async (type,key,code,id) => b.send('Input.dispatchKeyEvent',{type,key,code,windowsVirtualKeyCode:id});
  await key('keyDown','2','Digit2',50);await key('keyUp','2','Digit2',50);
  await b.wait('kbGodotState.slot===1','draw pistol');
  await b.value(`window.recordFrames=true;window.sampleFrames=[];
    requestAnimationFrame(function collect(t){sampleFrames.push(t);
      if(recordFrames)requestAnimationFrame(collect)})`);
  async function measureWindow(label, fire) {
    const start=await b.value('performance.now()');
    if(fire)await key('keyDown','j','KeyJ',74);
    await pause(1350);
    if(fire)await key('keyUp','j','KeyJ',74);
    const ms=await b.value(`sampleFrames.map((t,i)=>i&&t>${start}?t-sampleFrames[i-1]:0).filter(Boolean).sort((a,b)=>a-b)`);
    assert(ms.length>5,label+' froze rendering');
    console.log(label+' p95/worst ms',ms[Math.floor(ms.length*.95)].toFixed(1),ms.at(-1).toFixed(1));
  }
  await measureWindow('Standing at spawn',false);
  await measureWindow('First burst',true);
  await measureWindow('Second burst',true);
  await b.value('window.recordFrames=false');
  await key('keyDown','1','Digit1',49);await key('keyUp','1','Digit1',49);
  const command = name => b.value('kbGodotCommand(' + JSON.stringify(name) + ')');
  await command('riverbank');await pause(400);await b.screenshot('riverbank');
  async function toggleMap() {
    const key = {key:'m',code:'KeyM',windowsVirtualKeyCode:77};
    await b.send('Input.dispatchKeyEvent',{...key,type:'keyDown'});
    await b.send('Input.dispatchKeyEvent',{...key,type:'keyUp'});
  }
  async function choose(name) {
    const r = await b.value('kbGodotState.buttons['+JSON.stringify(name)+']');
    assert(r,'Missing button '+name);
    await b.clickAt(r[0]+r[2]/2,r[1]+r[3]/2);
  }
  await toggleMap();
  await b.wait('kbGodotState.map_open && kbGodotState.buttons["The Island Run"]','casebook');
  assert.equal(await b.value('Object.keys(kbGodotState.buttons).length'),12);
  await b.screenshot('operations');
  await choose('The Island Run');
  await pause(350);
  await choose('Accept operation');
  await b.wait('kbGodotState.job==="island" && kbGodotState.job_step==="marina" && kbGodotState.night','mainland objective');
  await command('blackwater');
  await pause(500);
  await b.screenshot('blackwater');
  await toggleMap();
  await b.wait('kbGodotState.map_open && kbGodotState.audio_paused','map pauses audio');
  await choose('After Hours');
  await b.wait('kbGodotState.buttons["Switch operation"]','switch operation');
  await choose('Switch operation');
  await b.wait('kbGodotState.job==="office"','office operation');
  for (const [spot, name] of [['billboards','times-square'],['observatory','observatory'],['park','central-park']]) {
    await command(spot); await pause(600); await b.screenshot(name);
  }
  await command('bridge_run');
  await b.wait('kbGodotState.drive?.active','start five-star night crossing');
  await b.screenshot('five-star-bridge');
  await b.value(`window.frameIntervals=[];window.longFrames=[];window.recordFrames=true;
    requestAnimationFrame(function measure(last) {
      requestAnimationFrame(function(next) {
        if (!window.recordFrames) return;
        const elapsed=next-last;
        frameIntervals.push(elapsed);
        if (elapsed>100) longFrames.push([Math.round(elapsed),kbGodotState.region,Math.round(kbGodotState.drive.elapsed)]);
        measure(next);
      });
    })`);
  await b.wait('!kbGodotState.drive?.active','finish crossing',215000);
  await b.value('window.recordFrames=false');
  const end=await b.value('kbGodotState');
  const intervals=(await b.value('frameIntervals')).sort((a,c)=>a-c);
  assert(end.drive.finished && end.drive.hotel && end.region==='Lower Manhattan','Failed to enter the downtown hotel');
  assert.equal(end.wanted,5);
  assert(intervals.length>100);
  const q = fraction => Number(intervals[Math.floor((intervals.length-1)*fraction)].toFixed(2));
  const metrics={frames:intervals.length,medianMs:q(.5),p95Ms:q(.95),p99Ms:q(.99),worstMs:q(1),over100ms:intervals.filter(t=>t>100).length};
  console.log('Five-star hotel arrival', JSON.stringify({seconds:end.drive.elapsed,distance:end.drive.distance,metrics,longFrames:await b.value('longFrames')}));
  await b.screenshot('arrival');
  await b.wait('kbGodotState.sounding_cruisers>0','responding cruisers emit their sirens');
  await command('chase');
  await b.wait('kbGodotState.wanted===0 && kbGodotState.sounding_cruisers===0','stand down and stop sirens');
  await command('boat');await pause(400);
  await key('keyDown','e','KeyE',69);await key('keyUp','e','KeyE',69);
  await b.wait('kbGodotState.boat_engine && kbGodotState.sounding_cruisers===0','boat motor in a quiet harbor');
}
(async()=>{
  const profile=await fs.mkdtemp(path.join(os.tmpdir(),'kestrel-chrome-'));
  const args=['--headless','--enable-gpu','--disable-background-networking','--no-first-run','--remote-debugging-port=0','--user-data-dir='+profile,'about:blank'];
  if(process.platform==='darwin')args.unshift('--use-angle=metal');
  const child=spawn(chrome,args,{stdio:'ignore'});
  let b, launched=false;
  try {
    await new Promise((resolve,reject)=>{child.once('spawn',resolve);child.once('error',reject);});
    launched=true;
    b=await connect(path.join(profile,'DevToolsActivePort'),child);
    if(!process.argv.includes('--desktop'))await touch(b);
    if(!process.argv.includes('--touch'))await desktop(b);
    assert.deepEqual(b.errors,[],'Browser reported errors');
  } finally {
    if(b)b.close();
    if(launched)child.kill();
    // Only remove this run's unique temporary browser profile after Chrome quits.
    if(launched && child.exitCode===null && child.signalCode===null)await new Promise(resolve=>child.once('exit',resolve));
    await fs.rm(profile,{recursive:true,force:true,maxRetries:3});
  }
})().catch(err=>{console.error(err);process.exitCode=1;});
