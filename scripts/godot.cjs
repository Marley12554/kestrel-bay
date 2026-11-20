'use strict';

const fs = require('node:fs');
const path = require('node:path');
const http = require('node:http');
const {spawnSync} = require('node:child_process');
const root = path.resolve(__dirname, '..');
const project = path.join(root, 'godot-prototype');
const output = path.join(root, 'dist', 'site');
const godot = process.env.GODOT_BIN || (process.platform === 'darwin' ? '/Applications/Godot.app/Contents/MacOS/Godot' : 'godot');

function run(args) {
  const result = spawnSync(godot, ['--headless', '--path', project, ...args], {
    encoding: 'utf8', timeout: args.includes('res://tests/drive.gd') ? 540000 : 240000, maxBuffer: 12 * 1024 * 1024
  });
  const logs = (result.stdout || '') + (result.stderr || '');
  if (result.error) throw result.error;
  const errors = /SCRIPT ERROR:|^ERROR:/m.test(logs);
  if (errors || result.status !== 0) {
    console.error(logs.slice(-10000));
    throw Error('Godot returned an error during ' + args.join(' '));
  }
  console.log(logs.split('\n').filter(line => /CHECKS|ROUTE DRIVE|RIGHT TURN|CITY BAKE/i.test(line)).join('\n'));
}
function importProject() {
  run(['--editor', '--import', '--quit']);
}
function build() {
  fs.mkdirSync(output, {recursive: true});
  importProject();
  run(['--export-release', 'Web', path.join(output, 'index.html')]);
  for (const name of ['index.pck', 'index.wasm', 'index.js']) {
    if (!fs.statSync(path.join(output, name)).size) throw Error('Missing export ' + name);
  }
  const shell = path.join(output, 'index.html');
  const html = fs.readFileSync(shell, 'utf8');
  const classic = '<a href="./classic/" style="color:#eed7ac">Play Kestrel Bay Classic</a>';
  let page = html.replace('</body>', '<noscript>' + classic + '</noscript>\n</body>');
  page = page.replace("setStatusMode('notice');", "setStatusMode('notice');\nconst alternate=document.createElement('a');alternate.href='./classic/';alternate.textContent='Play Kestrel Bay Classic';alternate.style.color='#eed7ac';statusNotice.append(document.createElement('br'),alternate);");
  fs.writeFileSync(shell, page);
  buildClassic();
  fs.writeFileSync(path.join(output, '.nojekyll'), '');
  console.log('Ready to serve dist/site');
}
function buildClassic() {
  const html=fs.readFileSync(path.join(root,'Kestrel Bay.html'),'utf8');
  new (require('node:vm').Script)(html.split('<script>')[1].split('</script>')[0]);
  const directory=path.join(output,'classic');
  fs.mkdirSync(directory,{recursive:true});
  fs.writeFileSync(path.join(directory,'index.html'),html);
}
function serve() {
  const mime = {'.html':'text/html','.js':'text/javascript','.wasm':'application/wasm','.pck':'application/octet-stream','.png':'image/png','.svg':'image/svg+xml'};
  if (!fs.existsSync(path.join(output,'index.html'))) throw Error('Build the game first');
  const server = http.createServer((req,res)=>{
    let url;
    try { url = decodeURIComponent(new URL(req.url,'http://localhost').pathname); }
    catch { res.writeHead(400).end(); return; }
    const file = path.resolve(output,'.'+url+(url.endsWith('/')?'index.html':''));
    if (!file.startsWith(output + path.sep)) { res.writeHead(403).end(); return; }
    fs.stat(file,(err,stat)=>{
      if (err || !stat.isFile()) { res.writeHead(404).end(); return; }
      res.writeHead(200,{'Content-Type':mime[path.extname(file)] || 'application/octet-stream','Content-Length':stat.size,'Cache-Control':'no-store'});
      fs.createReadStream(file).pipe(res);
    });
  });
  const port = Number(process.env.PORT || 8065);
  server.listen(port,'127.0.0.1',()=>console.log('Kestrel Bay listening on http://127.0.0.1:'+port+'/'));
}
module.exports={build,buildClassic};
if(require.main===module) {
  const action=process.argv[2];
  if (action==='test') {
    importProject();
    for(const test of ['smoke','playable','response','city','containment','drive']) {
      run(['--fixed-fps','60','--script','res://tests/'+test+'.gd','--','--qa']);
    }
    run(['--fixed-fps','60','--script','res://tests/drive.gd','--','--qa','--bridge']);
  } else if (action==='build') build();
  else if (action==='serve') serve();
  else if (action==='bake') run(['--script','res://bay/bake.gd']);
  else throw Error('Use test, bake, build, or serve.');
}
