'use strict';
// Deliberately separate from build.cjs and the production Pages deployment.
const fs = require('node:fs');
const path = require('node:path');
const http = require('node:http');
const {spawnSync} = require('node:child_process');
const root = path.resolve(__dirname,'..');
const project = path.join(root,'godot-prototype');
const output = path.join(root,'dist','godot-test');
const godot = process.env.GODOT_BIN || (process.platform==='darwin' ? '/Applications/Godot.app/Contents/MacOS/Godot' : 'godot');
function run(args) {
  const result = spawnSync(godot,['--headless','--path',project,...args],{stdio:['inherit','pipe','pipe'],encoding:'utf8',timeout:120000,maxBuffer:16*1024*1024});
  if (result.stdout) process.stdout.write(result.stdout);
  if (result.stderr) process.stderr.write(result.stderr);
  if (result.error) throw result.error;
  if (/SCRIPT ERROR:|^ERROR:/m.test((result.stdout || '')+(result.stderr || ''))) throw Error('Godot reported an error; validation stopped.');
  if (result.status!==0) process.exit(result.status || 1);
}
const mode = process.argv[2] || 'build';
if (mode==='build') {
  fs.mkdirSync(output,{recursive:true});
  run(['--editor','--import','--quit']);
  run(['--export-release','Web',path.join(output,'index.html')]);
  if (!fs.existsSync(path.join(output,'index.wasm'))) throw Error('Web engine missing');
  fs.writeFileSync(path.join(output,'.nojekyll'),'');
  console.log('Built isolated web prototype: dist/godot-test/index.html');
} else if (mode==='test') {
  run(['--fixed-fps','60','--script','res://tests/smoke.gd']);
  run(['--fixed-fps','60','--script','res://tests/playable.gd']);
  run(['--fixed-fps','60','--script','res://tests/response.gd']);
} else if (mode==='serve') {
  if (!fs.existsSync(path.join(output,'index.html'))) throw Error('Run the build first.');
  const mime = {'.html':'text/html','.js':'text/javascript','.wasm':'application/wasm','.pck':'application/octet-stream','.png':'image/png','.svg':'image/svg+xml'};
  const server = http.createServer((req,res)=>{
    let name;
    try { name = decodeURIComponent(new URL(req.url,'http://localhost').pathname); }
    catch { res.writeHead(400).end(); return; }
    const file = path.resolve(output,'.'+name+(name.endsWith('/')?'index.html':''));
    if (file!==output && !file.startsWith(output+path.sep)) { res.writeHead(403).end(); return; }
    fs.stat(file,(err,stat)=>{
      if (err || !stat.isFile()) { res.writeHead(404).end(); return; }
      res.writeHead(200,{'Content-Type':mime[path.extname(file)] || 'application/octet-stream','Content-Length':stat.size,'Cache-Control':'no-store'});
      fs.createReadStream(file).pipe(res);
    });
  });
  const port = Number(process.env.KB_PROTOTYPE_PORT || 8064);
  server.listen(port,'127.0.0.1',()=>console.log(`Godot prototype: http://127.0.0.1:${port}/`));
} else throw Error('Use build, test, or serve.');
