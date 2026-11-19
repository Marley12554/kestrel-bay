function dockScene(x,y,inCar=false,patrols=true){
 started=true;state='play';mapOpen=false;cars=[];npcs=[];bullets=[];parts=[];ob=null;follower=null;interior=null;elevatorTrip=null;theft=null;clearPolice();resetInput();heat=wanted=crimeThreat=baseAlert=prisonAlert=0;airUnit=null;spikes=[];Object.assign(player,{x,y,z:0,vz:0,hp:100,armor:0,veh:null,bust:0,stamina:100,inWater:false,swimming:false,submerged:false});resetLook(-Math.PI/2);if(patrols)seedPatrols();if(inCar){const c=newCar('sport',x,y,0,'player');c.owned=true;player.veh=c;cars.push(c);}reportCrime(119,player);crimeThreat=2;lastCrime=time;
}
function groundResponse(){return cars.filter(c=>c.kind==='cop'&&!c.dead&&distance(c,player)<900).length+npcs.filter(n=>n.kind==='cop'&&!n.boarded&&n.state!=='dead'&&distance(n,player)<900).length;}

for(const [x,y,inCar] of [[7600,22100,false],[7600,22100,true],[7770,23370,false]]){
 dockScene(x,y,inCar);let first=null,engaged=null;
 for(let frame=0;frame<2400&&state==='play';frame++){
  update(1/60);if(first===null&&groundResponse())first=(frame+1)/60;
  if(npcs.some(n=>n.kind==='cop'&&!n.boarded&&n.state!=='dead'&&n.lastContact&&seesPlayer(n,1200))){engaged=(frame+1)/60;break;}
 }
 console.log('Dock response',{x,y,inCar,first,engaged,wanted,responders:cars.filter(c=>c.kind==='cop'&&c.role!=='patrol').length});
 assert.ok(first!==null&&first<=35,'An idle five-star dock suspect must get a real ground response');
 assert.ok(engaged!==null&&engaged<=40,'Arriving police must dismount and actually spot/engage the suspect');
}
// Inbound backups must survive the exact far-spawn distance/cleanup boundary that caused the failure.
dockScene(7600,22100,false,false);wanted=5;assert.ok(sendCruiser('pursuit',policeFix));const inbound=cars.find(c=>c.kind==='cop'),start=distance(inbound,player);assert.ok(start>=8*(CT.cop.maxV+MOVEMENT.sprint)&&!visiblePoliceSpawn(inbound,inbound.a));manage();assert.ok(cars.includes(inbound));assert.equal(npcs.filter(n=>n.cruiser===inbound&&n.boarded).length,2);
let arrived=false;for(let frame=0;frame<3000&&state==='play';frame++){update(1/60);if(groundResponse()){arrived=true;break;}}
console.log('Far-spawned dock backup',{start,arrived,retained:cars.includes(inbound),units:cars.filter(c=>c.kind==='cop').length});assert.ok(arrived,'Backups must physically reach the dock even without pre-existing patrols');
// A distant inbound fleet counts toward the target response instead of being recalled/replaced every tick.
dockScene(7600,22100,false,false);wanted=5;dispatch={confirmed:true,age:10};for(let i=0;i<5;i++)assert.ok(sendCruiser('pursuit',policeFix));const original=[...cars];for(let frame=0;frame<120;frame++)update(1/60);assert.ok(original.every(c=>cars.includes(c)&&c.role!=='return'));assert.equal(cars.filter(c=>c.kind==='cop').length,5);console.log('Five distant inbound cruisers survive cleanup and are not churned into repeated replacements');
// Patrol activation uses connected road travel; the nearest available town patrols respond beyond 6,000 units.
dockScene(7600,22100);wanted=5;assert.ok(cars.filter(c=>c.kind==='cop').every(c=>distance(c,player)>6000));mobilizePatrols(policeFix);assert.equal(cars.filter(c=>c.role==='pursuit').length,5);assert.ok(cars.filter(c=>c.role==='pursuit').every(c=>c.route.length||c.leg.stop!==undefined));console.log('Remote town/dock reports mobilize real patrols with routes immediately');

// Normal dispatch processing cannot send the reserved far-end bridge patrol back down the span.
dockScene(7600,22100,true);const bridge=roads.find(e=>e.bridge&&e.a.id==='bridgeN1'),point=lanePoint(bridge,1,200),sports=player.veh;Object.assign(sports,{...point,z:bridgeHeight(bridge,200),a:Math.atan2(bridge.dy,bridge.dx),spd:1550,vx:bridge.dx*1550,vy:bridge.dy*1550});Object.assign(player,{x:sports.x,y:sports.y,z:sports.z,a:sports.a});reportCrime(1,player);for(let i=0;i<180;i++)update(1/60);const held=cars.find(c=>c.tactic==='bridge-exit');assert.ok(held&&distance(held,held.tacticGoal)<80);console.log('Bridge far-end unit holds its post during the normal dispatch delay');

// Cargo scenery must leave both real approach lanes driveable.
for(const e of roads.filter(e=>e.name==='Drydock Road'))for(const dir of [-1,1])for(let t=40;t<e.len-40;t+=20){const c=roadCar('cop',e,dir,t,'cop');assert.ok(!carWall(c,c.x,c.y,c.a),'Cargo blocks a Drydock Road approach lane');}console.log('Both Drydock Road lanes have collision clearance past the container yard');

// Nearby patrols are not made blind by a distant response quota.
dockScene(7600,22100,false,false);wanted=5;dispatch={confirmed:true,age:10};for(let i=0;i<4;i++)assert.ok(sendCruiser('pursuit',policeFix));const nearbyRoad=roadAnchor(player.x,player.y),local=roadCar('cop',nearbyRoad.e,1,Math.max(50,nearbyRoad.t-400),'cop');local.role='patrol';local.parkedAtPost=true;cruiserCrew(local);cars.push(local);mobilizePatrols(policeFix);assert.equal(local.role,'pursuit');console.log('A nearby patrol responds despite four distant incoming cruisers');

assert.equal(policeTravelDistance(local,{x:37100,y:23500}),Infinity);console.log('Patrol selection does not invent a road connection to the prison island');

local.role='return';mobilizePatrols(policeFix);assert.equal(local.role,'pursuit');console.log('A returning cruiser re-engages when it is near the reported suspect');
