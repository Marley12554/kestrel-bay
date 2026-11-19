function resetScene(){
 started=true;state='play';mapOpen=false;cars=[];npcs=[];bullets=[];ob=null;follower=null;interior=null;elevatorTrip=null;clearPolice();resetInput();heat=60;wanted=3;crimeThreat=2;navigationZ=0;airUnit=null;
 Object.assign(player,{x:32600,y:9000,z:0,vz:0,hp:100,veh:null,bust:0,stamina:100});
}
function ticks(seconds,fn){for(let i=0;i<Math.ceil(seconds*60);i++){time+=1/60;fn(1/60,i);}}
const close=(a,b,epsilon=.005)=>assert.ok(Math.abs(a-b)<epsilon,`${a} != ${b}`);
close(CT.cop.maxV,1380);close(CT.sport.maxV,1080);close(CT.interceptor.maxV,1490.4);
close(CT.interceptor.maxV/CT.cop.maxV,1.08);
console.log('Both performance top speeds reduced 10%; cruiser unchanged; striped car retains 8% lead');
// Real bridge routing over a slightly angled segment join, at full civilian speed.
resetScene();const span=roads.find(e=>e.bridge&&e.a.id==='bridgeN1'),after=roads.find(e=>e.bridge&&e.a===span.b);
assert.ok(span&&after);const route=[span,after,...roads.filter(e=>e.bridge&&e.a===after.b)];
const target=roadCar('sport',span,1,span.len-850,'player'),cruiser=roadCar('cop',span,1,span.len-1600,'cop');
cruiser.role='pursuit';target.spd=1180;target.z=cruiser.z=120;player.veh=target;cars=[target,cruiser];let index=0,progress=span.len-850,replan=0;const trace=[];
const startGap=distance(cruiser,target);
ticks(7,(dt,i)=>{
 progress+=target.spd*dt;while(progress>route[index].len&&index<route.length-1){progress-=route[index].len;index++;}
 const e=route[index],p=lanePoint(e,1,progress);Object.assign(target,{...p,a:Math.atan2(e.dy,e.dx),vx:e.dx*target.spd,vy:e.dy*target.spd,z:bridgeHeight(e,progress)});
 Object.assign(player,{x:target.x,y:target.y,z:target.z,a:target.a});policeFix={x:target.x,y:target.y,z:target.z,a:target.a,seen:true};
 replan-=dt;if(replan<=0){replan=.72;const goal=pursuitTarget(cruiser);assignRoute(cruiser,routeTo(cruiser.x,cruiser.y,goal.x,goal.y,cruiser.a,true));cruiser.goal=goal;}
 driveAI(cruiser,dt);assert.ok(!cruiser.pitAttempt,'No bridge PIT');
 if(i>100&&distance(cruiser,target)>200)trace.push(cruiser.spd);
});
console.log('Bridge pursuit',{startGap,finishGap:distance(cruiser,target),minClosingSpeed:Math.min(...trace),peak:Math.max(...trace)});
assert.ok(distance(cruiser,target)<startGap-300,'Cruiser must actually close the gap');
assert.ok(Math.min(...trace)>target.spd*.95,'Cruiser must not brake/fall back at a straight bridge join');
// Close pursuit also matches target velocity instead of braking each time distance decreases.
resetScene();const runner=newCar('sedan',32600,8000,-Math.PI/2,'player'),tail=newCar('cop',32600,8280,-Math.PI/2,'cop');runner.spd=700;runner.vy=-700;tail.spd=850;tail.vy=-850;tail.role='pursuit';player.veh=runner;cars=[runner,tail];
const chaseSpeeds=[];
ticks(2,(dt)=>{runner.y-=700*dt;Object.assign(player,{x:runner.x,y:runner.y});policeFix={x:runner.x,y:runner.y,z:0,a:runner.a,seen:true};assert.ok(ramPursuit(tail,dt));chaseSpeeds.push(tail.spd);});
assert.ok(Math.min(...chaseSpeeds)>680);console.log('Close pursuit keeps pace instead of repeated braking');
// A moderate-speed PIT requires real quarter-panel contact and is rate limited.
resetScene();const pitVictim=newCar('sedan',32600,9000,-Math.PI/2,'player'),pitCop=newCar('cop',32625,9037,-Math.PI/2,'cop');
Object.assign(pitVictim,{spd:300,vy:-300});Object.assign(pitCop,{spd:345,vy:-345,role:'pursuit'});player.veh=pitVictim;Object.assign(player,{x:pitVictim.x,y:pitVictim.y});cars=[pitVictim,pitCop];policeFix={x:player.x,y:player.y,z:0,a:pitVictim.a,seen:true};
ramPursuit(pitCop,1/60);assert.ok(pitCop.pitAttempt);const oldHeading=pitVictim.a;carCollide(pitCop,pitVictim);assert.ok(Math.abs(pitVictim.a-oldHeading)>.2);assert.ok(pitCop.pitCooldown>time);console.log('Moderate-speed PIT needs physical contact and has a cooldown');
resetScene();crimeThreat=0;const lethalCar=newCar('sedan',32600,9000,0,'player'),victim=newNpc('ped',32620,9000);lethalCar.spd=200;lethalCar.vx=200;cars=[lethalCar];npcs=[victim];player.veh=lethalCar;carRun(lethalCar,1/60);assert.equal(victim.state,'dead');assert.ok(crimeThreat>=2);console.log('Fatal vehicle assault enables an armed response');

// Reboarded officers are passengers, not distant on-foot blockers; crews can dismount again.
resetScene();const stopped=newCar('cop',32600,9050,0,'cop');stopped.role='pursuit';stopped.atStop=true;cars=[stopped];policeFix={x:player.x,y:player.y,z:0,seen:true};
for(let i=0;i<8;i++){const n=newNpc('cop',i<2?stopped.x:32600,i<2?stopped.y:10000+i*30);n.boarded=true;n.state='boarded';n.cruiser=i<2?stopped:{};n.seat=i%2;npcs.push(n);}
navigationZ=132;assert.ok(deployOfficers(stopped));const crew=npcs.filter(n=>n.cruiser===stopped);assert.equal(crew.length,2);assert.ok(crew.every(n=>!n.boarded&&n.z===0));
for(const n of crew){n.boarded=true;n.state='boarded';}stopped.role='pursuit';stopped.atStop=true;assert.ok(deployOfficers(stopped));assert.equal(npcs.filter(n=>n.cruiser===stopped).length,2);console.log('Arrived cruiser deploys its reused crew despite other boarded officers');
// A stopped cruiser on an elevated deck deploys at the deck's actual height.
resetScene();const p=lanePoint(span,1,1500),z=bridgeHeight(span,1500);Object.assign(player,{x:p.x,y:p.y,z});const elevated=roadCar('cop',span,1,1450,'cop');elevated.z=z;elevated.role='pursuit';elevated.atStop=true;cars=[elevated];policeFix={x:p.x,y:p.y,z,seen:true};assert.ok(deployOfficers(elevated));assert.ok(npcs.some(n=>!n.boarded&&n.cruiser===elevated&&n.z===z));const walkingOfficer=npcs.find(n=>n.cruiser===elevated&&!n.boarded),beforeWalk={x:walkingOfficer.x,y:walkingOfficer.y};moveFoot(walkingOfficer,span.dx*30,span.dy*30,6);assert.ok(distance(walkingOfficer,beforeWalk)>25,'Officers must be able to walk on a deck above water');console.log('Elevated cruiser dismount and on-deck foot movement use correct floor');
// The ramp is solid from underneath, walkable from above, and has a real edge barrier.
resetScene();const ramp=roads.find(e=>e.bridge&&isLand(e.a.x,e.a.y)),r=lanePoint(ramp,1,150,0),rz=bridgeHeight(ramp,150);
assert.ok(physicalSolid(r.x,r.y,0,24),'Ramp must obstruct a lower-level body crossing it');assert.ok(!physicalSolid(r.x,r.y,rz,24),'Deck is walkable on top');
Object.assign(player,{x:r.x,y:r.y,z:rz});moveFoot(player,ramp.dx*15,ramp.dy*15,7);verticalFoot(player,1/60);assert.ok(player.z>=rz,'Ramp ascent is not blocked by its own collision');
const middle=lanePoint(span,1,1200,0);Object.assign(player,{...middle,z:120});moveFoot(player,-span.dy*300,span.dx*300,7);assert.ok(roadDistance(span,player.x,player.y)<span.width/2+25,'Bridge barrier must stop a player from walking off');console.log('Bridge underside, ramp ascent and edge barriers collide');
// A high landing and its connecting platform have guards; stairs still provide a descent route.
resetScene();const hotel=buildingNamed('The Mariner Grand'),east=hotel.x+hotel.w/2;
Object.assign(player,{x:east+45,y:hotel.y+65,z:132});moveFoot(player,160,0,7);assert.ok(player.x<east+90);Object.assign(player,{x:east+10,y:hotel.y,z:132});moveFoot(player,80,0,7);assert.ok(player.x<east+20);assert.ok(player.z===132);console.log('Fire escape landing and window-side platform guards prevent walking off');
// An actual fall completes in simulation time; it cannot acquire a floor above its feet.
Object.assign(player,{x:east+180,y:hotel.y,z:132,vz:0});let fall=0;while(player.z>0&&fall<3){verticalFoot(player,1/60);fall+=1/60;}assert.ok(fall<1.3&&player.z===0);console.log('Three-story fall lasts',fall.toFixed(2),'seconds');
// Pausing the map suspends both loops and one-shot audio timelines; close resumes once.
resetScene();const savedAudio=AC;const calls=[];AC={state:'running',suspend(){calls.push('suspend');this.state='suspended';},resume(){calls.push('resume');this.state='running';}};
setMap(true);assert.equal(AC.state,'suspended');syncAudioState();assert.deepEqual(calls,['suspend']);setMap(false);assert.equal(AC.state,'running');assert.deepEqual(calls,['suspend','resume']);AC=savedAudio;console.log('Map pauses and resumes the audio clock');
const crossings=[];for(const e of roads.filter(e=>e.bridge))for(const f of roads.filter(f=>!f.bridge)){
 const rx=e.b.x-e.a.x,ry=e.b.y-e.a.y,sx=f.b.x-f.a.x,sy=f.b.y-f.a.y,cross=rx*sy-ry*sx;if(Math.abs(cross)<.001)continue;
 const dx=f.a.x-e.a.x,dy=f.a.y-e.a.y,t=(dx*sy-dy*sx)/cross,u=(dx*ry-dy*rx)/cross;
 if(t<=.001||t>=.999||u<=.001||u>=.999)continue;
 crossings.push({bridge:e.name,road:f.name,x:e.a.x+rx*t,y:e.a.y+ry*t,clearance:bridgeHeight(e,e.len*t)-4});
}console.log('Road crossing clearances',crossings);assert.ok(crossings.every(c=>c.clearance>32));