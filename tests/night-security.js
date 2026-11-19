startGame();resetInput();state='play';
const near=(a,b,e=1e-6)=>assert.ok(Math.abs(a-b)<e,`${a} != ${b}`);
// Exact full cycle and operation-only lock; normal gameplay time remains separate.
worldClock.phase=0;worldClock.locked=false;updateWorldClock(299);assert.ok(!isNight());updateWorldClock(1);assert.ok(isNight());updateWorldClock(299);assert.ok(isNight());updateWorldClock(1);near(worldClock.phase,0);assert.ok(!isNight());
lockPrisonNight();const night=worldClock.phase;updateWorldClock(700);near(worldClock.phase,night);cleanupJob();updateWorldClock(1);near(worldClock.phase,(night+1)%600);console.log('Exactly 300 seconds day / 300 seconds night; operation lock releases');
// Ambient populations cannot be generated inside either secured jurisdiction.
for(const where of [{x:37000,y:23500},{x:28000,y:8000}]){
 cars=cars.filter(c=>c.kind!=='traffic');npcs=npcs.filter(n=>n.kind!=='ped');Object.assign(player,{...where,z:0,veh:null});
 for(let i=0;i<100;i++){spawnTraffic(true);spawnPed(true);}
 assert.ok(cars.every(c=>c.kind!=='traffic'||!restrictedLand(c.x,c.y)));
 assert.ok(npcs.every(n=>n.kind!=='ped'||!restrictedLand(n.x,n.y)));
}
console.log('Prison and military zones exclude ambient civilian cars and pedestrians');
// Circuit routing must have an actual connection. E alone cannot cut power or grant a card.
ob=null;Object.assign(player,{x:L.prisonPower.x,y:L.prisonPower.y,z:0,veh:null});inventory.key=inventory.prisonCard=false;L.prisonPower.disabled=false;prisonAccess.gateOpen=false;
startJob(missionList.find(m=>m.id==='island'));setObjective('power',L.prisonPower,'Test');actOnObjective();assert.ok(circuit);assert.ok(!L.prisonPower.disabled);assert.ok(!inventory.prisonCard&&!inventory.key);assert.ok(circuitState(circuitSolution).complete);assert.ok(!circuitState(Array(12).fill(5)).complete);
const savedTiles=circuit.tiles.slice();cancelCircuit();openCircuit('power',L.prisonPower);assert.deepEqual(circuit.tiles,savedTiles);for(let i=0;i<3;i++)testCircuit();assert.ok(prisonAlert>=2);assert.ok(npcs.some(n=>n.kind==='guard'&&n.investigate));circuit.tiles=circuit.solution.slice();testCircuit();assert.ok(L.prisonPower.disabled);assert.equal(ob.stage,'gate');assert.ok(!prisonAccess.gateOpen);updDefenses(1/60);assert.ok(facilityGates.find(g=>g.zone==='prison').active);assert.ok(!inventory.prisonCard);console.log('Circuit routing, alarm escalation, resume, and independent gate/card access');
// Checkpoint restores sabotage and gate state and locks the retry to night.
Object.assign(player,{x:L.prisonGate.x,y:L.prisonGate.y});openCircuit('gate',L.prisonGate);circuit.tiles=circuit.solution.slice();testCircuit();assert.equal(ob.stage,'cell');const cp=checkpoint;failJob('Test retry');assert.ok(!worldClock.locked);prisonAccess.gateOpen=false;L.prisonPower.disabled=false;checkpoint=cp;startJob(missionList.find(m=>m.id==='island'));assert.equal(ob.stage,'cell');assert.ok(worldClock.locked&&L.prisonPower.disabled&&prisonAccess.gateOpen);failJob('Finish');checkpoint=null;
// Real light cones and collision agree: a fence blocks the beam; dark targets have shorter detection.
cars=[];npcs=[];worldClock.phase=400;worldClock.locked=false;
Object.assign(player,{x:35150,y:24600,z:0,veh:null,crouching:false});
const across=makeLight(35300,24600,20,Math.PI,0,800,.35,[1,1,1],{});assert.ok(lightStrength(across,player,false)>.2);assert.equal(lightStrength(across,player,true),0);
Object.assign(player,{x:32600,y:9000,z:0});worldLights=[];const darkRange=visibleRange({},1000);const lamp=makeLight(32500,9000,20,0,0,800,.45,[1,1,1],{});worldLights=[lamp];assert.ok(lightStrength(lamp,player)>.5);assert.ok(visibleRange({},1000)>darkRange*3);worldClock.phase=150;assert.equal(visibleRange({},1000),1000);
console.log('Walls block beams and night detection uses actual illumination');
// Troops and prison guards use velocity prediction and fast, reloadable bursts.
for(const kind of ['guard','troop']){
 npcs=[];bullets=[];time=100;const n=guard(kind,32600,9500,[{x:32600,y:9500}]);Object.assign(player,{x:32600,y:9000,z:0,veh:null});
 for(let i=0;i<110;i++){time+=1/60;player.x+=64/60;officerCombat(n,1/60,distance(n,player),true,true);}
 assert.ok(n.trackVx>60);assert.ok(bullets.length>=3);assert.ok(bullets.every(b=>hyp(b.vx,b.vy)>1600));assert.ok(n.ammo<12||n.reloadUntil>time);
}
console.log('Both guard types lead moving targets with modern burst combat');
// Fixed patrols consist of navigable legs rather than walking through cell buildings.
npcs=[];cars=[];spawnSecurity();for(const n of npcs.filter(n=>n.kind==='guard'))for(let i=0;i<n.patrol.length;i++){navigationZ=n.z||0;
 const a=n.patrol[i],b=n.patrol[(i+1)%n.patrol.length];assert.ok(walkClear(a.x,a.y,b.x,b.y),`Blocked prison patrol: ${JSON.stringify([a,b])}`);
}
assert.ok(cars.some(c=>c.kind==='service'&&c.authorized));console.log('Prison patrol legs and authorized delivery route are physically accessible');

// Closed cells physically block passage; releasing the actual inmate opens the cell.
ob=null;npcs=[];cars=[];const cellPlan=planFor(buildingNamed('Cellblock B'),0),cellDoor=cellPlan.eliDoor;
cellDoor.open=false;cellDoor.broken=false;const cellProbe={x:cellDoor.x-20,y:cellDoor.y,z:0,vz:0};moveFoot(cellProbe,40,0,6);assert.ok(cellProbe.x<cellDoor.x-4);
const control=cellPlan.items.find(i=>i.id==='mate');Object.assign(player,{x:control.x,y:control.y,z:0,veh:null});interior=physicalContext(player);releaseEli(control);
assert.ok(cellDoor.open);moveFoot(cellProbe,40,0,6);assert.ok(cellProbe.x>cellDoor.x+20);const fromCell=distance(follower,player);
for(let i=0;i<180;i++){time+=1/60;updFollower(1/60);}assert.ok(distance(follower,player)<25);assert.ok(fromCell>100);console.log('Released inmate actually walks out through the physically opened cell door');

// Full update-loop boarding uses actual E input, an owned parked boat and a real pier.
ob=null;npcs=[];cars=[];follower=null;checkpoint=null;clearPolice();wanted=heat=crimeThreat=0;state='play';resetInput();
const escapeJob=missionList.find(m=>m.id==='island');ob={job:escapeJob,stage:'extract',target:L.prisonDock,text:'Escort Eli',timer:null,progress:0};worldClock.phase=400;worldClock.locked=true;
const extractionBoat=specialVehicle('boat',33300,23620,Math.PI);extractionBoat.owned=true;extractionBoat.persistent=true;
Object.assign(player,{x:33300,y:23540,z:6,vz:0,veh:null,inWater:false,swimming:false,submerged:false,hp:100});makeFollower('Eli',33300,23525);follower.z=6;interior=null;
keys.KeyE=true;actQ=true;update(1/60);keys.KeyE=false;assert.equal(player.veh,extractionBoat);assert.equal(ob.stage,'extract');assert.ok(!follower.boarded);
for(let i=0;i<100;i++)update(1/60);assert.equal(ob.stage,'escape');assert.ok(follower.boarded);assert.equal(state,'play');
Object.assign(extractionBoat,{x:L.safe.x,y:L.safe.y,spd:0});update(1/60);assert.equal(ob,null);assert.ok(finishedJobs.has('island'));assert.ok(!worldClock.locked);console.log('Full update-loop E entry, dockside escort boarding and automatic arrival completion pass');
