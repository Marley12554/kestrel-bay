// Full encounters use the shipped movement, line of sight, bullets and interaction code.
function resetEncounter(){
 started=true;state='play';mapOpen=false;cars=[];npcs=[];bullets=[];ob=null;follower=null;interior=null;elevatorTrip=null;theft=null;clearPolice();resetInput();policeViews.length=0;heat=60;wanted=3;crimeThreat=2;navigationZ=0;airUnit=null;airDispatch=0;spikes=[];
 Object.assign(player,{x:32600,y:9000,z:0,vz:0,hp:100,armor:0,veh:null,bust:0,stamina:100,inWater:false,submerged:false,swimming:false});resetLook(0);
}
function run(seconds,fn){for(let i=0;i<Math.ceil(seconds*60);i++){time+=1/60;frameDt=1/60;fn(1/60,i);}}
function cop(x,y){const n=newNpc('cop',x,y);n.z=0;n.fire=0;npcs.push(n);return n;}
resetEncounter();finishedJobs.clear();assert.ok(missionList.every(available));finishedJobs.add('finale');assert.ok(available(missionList.find(m=>m.id==='finale')));console.log('Every operation unlocked from a fresh save and completed operations replayable');
// Screenshot regression: a clearly exposed officer across an open court must react at one star.
resetEncounter();heat=13;wanted=1;crimeThreat=0;const observer=cop(player.x,player.y+650);policeFix={x:player.x,y:player.y,z:0,seen:false};const oldDistance=distance(observer,player);
run(8,dt=>{updOfficer(observer,dt);updateArrest(dt);});assert.ok(distance(observer,player)<oldDistance-500);assert.equal(bullets.length,0);assert.ok(player.bust>0||state==='busted');console.log('One-star officer spots and closes a 163 ft open-ground gap without lethal fire');
// Sustained circular movement is predictable, but cover still blocks the same weapons.
resetEncounter();cop(player.x-450,player.y-80);cop(player.x-420,player.y+120);let shots=0,peakShooters=0;
run(10,(dt,i)=>{
 const a=i*dt*MOVEMENT.sprint/65;player.x=32600+Math.cos(a)*65;player.y=9000+Math.sin(a)*65;
 policeFix={x:player.x,y:player.y,z:0,seen:true};
 const before=bullets.length;for(const n of npcs)updOfficer(n,dt);shots+=Math.max(0,bullets.length-before);peakShooters=Math.max(peakShooters,npcs.filter(n=>n.aim||n.burst>0).length);updBullets(dt);
});console.log('Circular sprint encounter',{hp:player.hp,shots,peakShooters});assert.ok(shots>=12&&player.hp<=70,'Steady circles must not give invulnerability');assert.ok(peakShooters<=2);
resetEncounter();cop(player.x-550,player.y-30);cop(player.x-520,player.y+40);
run(7,(dt)=>{player.y-=MOVEMENT.sprint*dt;policeFix={x:player.x,y:player.y,z:0,seen:true};for(const n of npcs)updOfficer(n,dt);updBullets(dt);});console.log('Straight sprint under fire',{hp:player.hp});assert.ok(player.hp<90);
resetEncounter();Object.assign(player,{x:27000,y:11470,z:0});const blocked=cop(27000,11770);assert.ok(!seesPlayer(blocked,1200));policeFix={x:blocked.x-100,y:blocked.y,z:0,seen:false};run(1,dt=>{officerCombat(blocked,dt,distance(blocked,player),seesPlayer(blocked,1200));updBullets(dt);});assert.equal(player.hp,100);assert.equal(bullets.length,0);console.log('Actual exterior walls still stop sight and gunfire');
// Car occupant cannot invalidate a nearby arrest by remaining seated.
resetEncounter();const car=newCar('sedan',player.x,player.y,0,'player');car.owned=true;cars=[car];player.veh=car;policeFix={x:player.x,y:player.y,z:0,seen:true};const grabber=cop(car.x,car.y-95);run(2.3,dt=>{updOfficer(grabber,dt);updateArrest(dt);});assert.equal(player.veh,null);assert.ok(player.bust>0||state==='busted');assert.ok(distance(grabber,player)<35);attemptVehicleEntry(car);assert.equal(player.veh,null,'Cannot instantly re-enter while the officer holds the door');console.log('Officer walks to the door, grabs, extracts and holds the door through the arrest');
resetEncounter();const moving=newCar('sedan',player.x,player.y,0,'player');cars=[moving];player.veh=moving;const denied=cop(moving.x,moving.y-30);moving.spd=45;assert.equal(extractionGoal(denied,2),null);assert.equal(player.veh,moving);
moving.spd=0;extractionGoal(denied,.4);assert.ok(moving.grabbed);moving.spd=70;extractionGoal(denied,.8);assert.equal(moving.grabbed,null);assert.equal(player.veh,moving);console.log('Accelerating interrupts extraction; moving cars cannot be remotely grabbed');
// Three successful rounds are required, real cop occupants come out before boarding.
resetEncounter();const cruiser=newCar('cop',player.x,player.y+40,0,'cop');cruiser.role='pursuit';cars=[cruiser];cruiserCrew(cruiser);attemptVehicleEntry(cruiser);assert.ok(theft);assert.equal(player.veh,null);
for(let round=0;round<3;round++){assert.equal(theft.round,round);theft.phase=theft.center;theftHit();assert.equal(player.veh,null);}
assert.equal(theft.stage,'boarding');assert.equal(npcs.filter(n=>n.kind==='ped').length,0);assert.equal(npcs.filter(n=>n.kind==='cop'&&!n.boarded).length,2);assert.ok(npcs.every(n=>n.ejectedUntil>time&&!n.cruiser));run(.9,updateTheft);assert.equal(player.veh,cruiser);assert.equal(theft,null);assert.equal(cruiser.owned,true);console.log('Three timed rounds, physical officer ejection and boarding delay replace instant cop-car escape');
exitCar();attemptVehicleEntry(cruiser);assert.equal(player.veh,cruiser);assert.equal(theft,null);
resetEncounter();const lockedCar=newCar('sport',player.x,player.y+40,0,'parked');cars=[lockedCar];attemptVehicleEntry(lockedCar);theft.phase=0;theftHit();assert.equal(theft,null);assert.equal(player.veh,null);assert.equal(lockedCar.beingStolen,false);
attemptVehicleEntry(lockedCar);hurtPlayer(1);assert.equal(theft,null);attemptVehicleEntry(lockedCar);player.x+=120;updateTheft(.1);assert.equal(theft,null);player.x-=120;attemptVehicleEntry(lockedCar);setMap(true);assert.equal(theft,null);setMap(false);console.log('A miss, damage, distance or opening the map abandons the theft immediately');
// Whole-car visibility includes free-look and history, with minimum time to encounter.
resetEncounter();Object.assign(eye,{x:player.x,y:player.y,z:22.5,yaw:-Math.PI/2,pitch:0,lx:.9,ly:1.5});assert.ok(visiblePoliceSpawn({x:player.x,y:player.y-2200,z:0},0));view.yaw=Math.PI;assert.ok(visiblePoliceSpawn({x:player.x,y:player.y-2200,z:0},0),'Actual camera cannot be replaced with car heading');assert.ok(!fairPoliceSpawn({x:player.x-500,y:player.y,z:0},0));
player.veh=newCar('interceptor',player.x,player.y,0,'player');player.veh.spd=1600;assert.ok(!fairPoliceSpawn({x:player.x+8000,y:player.y+1000,z:0},0));console.log('Visible front spawns and close hidden spawns rejected, including high closing speed');
// Cross the complete long bridge using the real road controller and seeded far-end patrol.
resetEncounter();seedPatrols();const bridge=roads.find(e=>e.bridge&&e.a.id==='bridgeN1'),start=lanePoint(bridge,1,200);
Object.assign(player,{...start,z:bridgeHeight(bridge,200),a:Math.atan2(bridge.dy,bridge.dx)});const sports=roadCar('interceptor',bridge,1,200,'player');sports.spd=1600;player.veh=sports;cars.push(sports);policeFix={...player,veh:undefined,seen:true};
const exit=bridgeExit(policeFix);assert.ok(exit&&exit.x>44000&&exit.remaining>18000);const waiting=cars.find(c=>c.kind==='cop'&&distance(c,exit)<1000);assert.ok(waiting,'A real far-end unit must exist before player enters bridge');
const tail=roadCar('cop',bridge,1,70,'cop');tail.role='pursuit';cars.push(tail);waiting.role='pursuit';waiting.parkedAtPost=false;
coordinatePolice([tail,waiting]);assert.equal(waiting.tactic,'bridge-exit');assert.equal(tail.tactic,'tail');const post=pursuitTarget(waiting);assignRoute(waiting,routeTo(waiting.x,waiting.y,post.x,post.y));waiting.goal=post;
run(4,dt=>driveAI(waiting,dt));console.log('Bridge post approach',{position:[waiting.x,waiting.y],exit:[exit.x,exit.y],speed:waiting.spd,stuck:waiting.stuck,leg:waiting.leg.e.name,stop:waiting.leg.stop,distance:distance(waiting,exit),atStop:waiting.atStop});assert.ok(distance(waiting,exit)<70,'Far-end unit actually drives into position');assert.ok(waiting.atStop);assert.ok(distance(waiting,player)>18000);console.log('Real bridge exit reserved and reached while the sports car is still several spans away');
// Render pulse speeds up across the countdown and preserves the original paint.
resetEncounter();const burning=newCar('sport',player.x,player.y,0,'parked');burning.onFire=true;burning.hp=10;const original=burning.col;
function cycles(from,to){let changes=0,last=0;for(let elapsed=from;elapsed<to;elapsed+=.01){burning.fireRemaining=10-elapsed;const high=vehicleWarningPulse(burning)>.59;if(high&&!last)changes++;last=high;}return changes;}
const early=cycles(0,2),late=cycles(8,10);assert.ok(late>early*2);assert.notEqual(vehiclePaint(burning),original);assert.equal(burning.col,original);console.log('Warning pulse cycles',{firstTwoSeconds:early,lastTwoSeconds:late});

// The same cop theft must survive the complete update loop, including dispatch/arrest.
resetEncounter();heat=wanted=crimeThreat=0;const fullCar=newCar('cop',player.x,player.y+45,0,'cop');fullCar.role='pursuit';cars=[fullCar];cruiserCrew(fullCar);attemptVehicleEntry(fullCar);update(1/60);
for(let i=0;i<3;i++){theft.phase=theft.center;theftHit();}
let theftStage=theft?.stage;for(let frame=0;frame<54;frame++){update(1/60);if(theft?.stage!==theftStage){console.log('Full-loop theft transition',{stage:theft?.stage,hp:player.hp,bust:player.bust,state,position:[player.x,player.y],vehicle:player.veh?.type,notes:toasts.at(-1)?.text});theftStage=theft?.stage;}}
assert.equal(player.veh,fullCar,'Full update loop must board a stolen cop car after ejection');console.log('Full update-loop cop theft passes');
// Production dispatch, vehicle physics and spike placement must agree with the director.
resetEncounter();seedPatrols();const liveSpan=roads.find(e=>e.bridge&&e.a.id==='bridgeN1'),liveSports=roadCar('interceptor',liveSpan,1,200,'player');
liveSports.owned=true;liveSports.spd=1550;liveSports.vx=liveSpan.dx*1550;liveSports.vy=liveSpan.dy*1550;cars.push(liveSports);player.veh=liveSports;Object.assign(player,{x:liveSports.x,y:liveSports.y,z:liveSports.z,a:liveSports.a});heat=119;wanted=5;policeFix={x:player.x,y:player.y,z:player.z,a:player.a,seen:true};dispatch={confirmed:true,age:0};lastCrime=time;keys.KeyW=true;
for(let frame=0;frame<240;frame++)update(1/60);keys.KeyW=false;
const held=policeDirector.assignments.find(a=>a.tactic==='bridge-exit');console.log('Production bridge response',{jobs:policeDirector.assignments.map(a=>a.tactic),distance:held&&distance(held.car,held.goal),spikes:spikes.length,playerSpeed:liveSports.spd});
assert.ok(held&&distance(held.car,held.goal)<80&&held.car.parkedAtPost,'A real dispatcher must stage the far bridge approach before the sports car arrives');assert.ok(spikes.some(s=>distance(s,held.car)<200));assert.ok(player.veh===liveSports&&state==='play');
console.log('Production update-loop bridge interception and physical spikes pass');

resetEncounter();const armored=specialVehicle('tank',player.x,player.y+45,0,'military');ejectOccupants(armored);time+=1;for(const n of npcs)updNpc(n,1/60);assert.ok(npcs.some(n=>n.kind==='troop'&&n.patrol.length));console.log('Military vehicle ejection leaves a functioning soldier');

resetEncounter();const empty=roadCar('cop',roads.find(e=>!e.bridge),1,100,'cop');empty.role='pursuit';cruiserCrew(empty);cars=[empty];empty.x+=200;for(const n of npcs)updNpc(n,1/60);assert.ok(npcs.every(n=>n.x===empty.x&&n.y===empty.y));for(const n of npcs)n.state='dead';empty.spd=200;driveAI(empty,1/60);assert.equal(empty.spd,0);console.log('Boarded crews travel with the cruiser; an empty cruiser cannot drive itself');

// Response-cap rotation may retire a distant reserve, never the far bridge holding unit.
resetEncounter();const fixSpan=roads.find(e=>e.bridge&&e.a.id==='bridgeN1'),fixPosition=lanePoint(fixSpan,1,200);Object.assign(player,{...fixPosition,z:120,a:Math.atan2(fixSpan.dy,fixSpan.dx)});policeFix={x:player.x,y:player.y,z:120,a:player.a,seen:true};dispatch={confirmed:true,age:20};heat=119;wanted=5;
const protectedPost=roadCar('cop',fixSpan,1,fixSpan.len-100,'cop');protectedPost.role='pursuit';protectedPost.tactic='bridge-exit';cars=[protectedPost];
for(let i=0;i<5;i++){const reserve=roadCar('cop',fixSpan,1,300+i*100,'cop');reserve.role='staged';reserve.stageTime=time;reserve.tactic='reserve';cars.push(reserve);}
policeReplan=1;copT=0;updWanted(1/60);assert.equal(protectedPost.role,'pursuit');console.log('Response cap preserves a reserved bridge interception');
