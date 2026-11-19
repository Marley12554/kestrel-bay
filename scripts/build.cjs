'use strict';
const fs=require('node:fs'),vm=require('node:vm'),path=require('node:path');
const root=path.resolve(__dirname,'..'),html=fs.readFileSync(path.join(root,'Kestrel Bay.html'),'utf8');
new vm.Script(html.split('<script>')[1].split('</script>')[0]);
const output=path.join(root,'dist');fs.mkdirSync(output,{recursive:true});
fs.writeFileSync(path.join(output,'index.html'),html);fs.writeFileSync(path.join(output,'.nojekyll'),'');
console.log('Built dist/index.html from Kestrel Bay.html');
