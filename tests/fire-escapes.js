// Walk generated flights without jump input, including body clearance at landing edges.
started=true;state='play';cars=[];npcs=[];player.veh=null;waterClimb=null;resetInput();
const flights=architecture.stairs.filter(r=>!r.landing),failures=[];let cityFlights=0,townFlights=0;
for(const r of flights){
 const city=inside(r.b.x,r.b.y,cityIsland);if(city)cityFlights++;else townFlights++;
 for(const offset of [-3,0,3]){
  const sign=Math.sign(r.endY-r.startY),end=r.b.y+sign*65,start=end-sign*33;
  Object.assign(player,{x:r.cx+offset,y:start,z:surfaceHeight(r,r.cx,start),vz:0,inWater:false,swimming:false,waterJump:false});
  for(let step=0;step<24;step++){moveFoot(player,0,sign*2,7);verticalFoot(player,2/MOVEMENT.jog);if((player.y-end)*sign>=0)break;}
  if((player.y-end)*sign<-1||Math.abs(player.z-r.z-44)>1){
   failures.push({building:r.b.name,city,floor:r.floor,offset,y:player.y-r.b.y,z:player.z-r.z,goal:end-r.b.y});
  }
 }
}
console.log('Fire-escape ascent audit',{flights:flights.length,cityFlights,townFlights,failures:failures.length,samples:failures.slice(0,10)});
assert.equal(failures.length,0,'Every generated stair/landing transition must be walkable without jumping');

function walkTo(x,y){
 for(let frame=0;frame<150;frame++){
  const dx=x-player.x,dy=y-player.y,d=hyp(dx,dy);if(d<.1)break;
  const step=Math.min(d,MOVEMENT.jog/60);moveFoot(player,dx/d*step,dy/d*step,7);verticalFoot(player,1/60);
 }
 assert.ok(hyp(x-player.x,y-player.y)<.1,'Must reach the next landing without jumping');
}
for(const name of ['The Mariner Grand','Southbank Garage']){
 const b=buildingNamed(name),route=flights.filter(r=>r.b===b&&r.floor<3).sort((a,b)=>a.floor-b.floor),first=route[0],sign=Math.sign(first.endY-first.startY);
 Object.assign(player,{x:first.cx,y:b.y-sign*65,z:0,vz:0});
 for(const r of route){const dir=Math.sign(r.endY-r.startY);walkTo(r.cx,b.y-dir*65);walkTo(r.cx,b.y+dir*65);assert.ok(Math.abs(player.z-r.z-44)<1);}
 for(const r of [...route].reverse()){const dir=Math.sign(r.endY-r.startY);walkTo(r.cx,b.y+dir*65);walkTo(r.cx,b.y-dir*65);assert.ok(Math.abs(player.z-r.z)<1);}
 assert.ok(!keys.Space&&Math.abs(player.z)<1);console.log('Complete no-jump ascent, landing turns and descent',name,route.length,'flights');
}
// Sprinting and slower frames still keep the whole foot supported through each turn.
for(const dt of [1/60,1/30,1/20]){
 const b=buildingNamed('The Mariner Grand'),edge=b.x+b.w/2;Object.assign(player,{x:edge+ESCAPE.center,y:b.y,z:0,vz:0});
 const points=[[ESCAPE.center,-65,0],[ESCAPE.inner,-65,0],[ESCAPE.inner,65,44],[ESCAPE.outer,65,44],[ESCAPE.outer,-65,88],[ESCAPE.inner,-65,88],[ESCAPE.inner,65,132]];
 for(const [offset,offsetY,z] of points){const x=edge+offset,y=b.y+offsetY;for(let i=0;i<120;i++){const d=hyp(x-player.x,y-player.y);if(d<.1)break;const step=Math.min(d,MOVEMENT.sprint*dt);moveFoot(player,(x-player.x)/d*step,(y-player.y)/d*step,7);verticalFoot(player,dt);}assert.ok(hyp(player.x-x,player.y-y)<.1&&Math.abs(player.z-z)<.1,`Sprint stair turn failed at ${1/dt} fps`);}
 console.log('Sprint ascent and landing turns without jumps at',Math.round(1/dt),'fps');
}
