'use strict';
// Run real game functions in a DOM-free harness. The browser still needs WebGL QA.
const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict'),path=require('node:path');
const root=path.resolve(__dirname,'..');
const source=fs.readFileSync(path.join(root,'Kestrel Bay.html'),'utf8').split('<script>')[1].split('</script>')[0];
new vm.Script(source); // syntax-check the shipped source, not a second implementation
for(const file of (process.argv.length>2?process.argv.slice(2):['geometry.js','response.js','campaign.js','pursuit-regressions.js'])){
 const noop=()=>{},context=new Proxy({}, {get:()=>noop});
 const element=()=>({getContext:type=>type==='webgl'?null:context,clientWidth:1280,clientHeight:800,addEventListener:noop,
  style:{setProperty:noop},classList:{add:noop,toggle:noop},dataset:{},replaceChildren:noop,append:noop,setAttribute:noop,querySelectorAll:()=>[]});
 const els=new Map(),document={addEventListener:noop,getElementById:id=>{if(!els.has(id))els.set(id,element());return els.get(id);},createElement:element,querySelectorAll:()=>[element(),element()],body:element()};
 const world=vm.createContext({console,assert,window:{},document,navigator:{},innerWidth:1280,innerHeight:800,
  performance:{now:()=>0},addEventListener:noop,requestAnimationFrame:noop,setTimeout:noop});
 const test=fs.readFileSync(path.join(__dirname,file),'utf8');
 console.log('\n'+file);
 vm.runInContext(source.replace(/\}\)\(\);\s*$/,`(()=>{${test}\n})();\n})();`),world,{timeout:120000});
}
console.log('\nAll acceptance checks passed.');
