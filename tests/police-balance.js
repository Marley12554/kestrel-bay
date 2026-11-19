// Exercise production controllers, not a second simulation of their decisions.
function clean(){time=100;started=true;state='play';mapOpen=false;cars=[];npcs=[];bullets=[];parts=[];ob=null;interior=null;elevatorTrip=null;theft=null;clearPolice();resetInput();policeViews.length=0;wanted=5;heat=119;crimeThreat=3;worldClock.phase=150;airUnit=null;airDispatch=0;Object.assign(player,{x:32600,y:9000,z:0,hp:100,armor:0,veh:null,bust:0,submerged:false,inWater:false,swimming:false});}
function advance(seconds,fn){for(let i=0;i<seconds*60;i++){time+=1/60;frameDt=1/60;fn(1/60,i);}}
clean();const civilian=newCar('compact',32600,9000,0,'player');player.veh=civilian;cars=[civilian];Object.assign(civilian,{spd:220,vx:220});
// This broad lawn is physically clear, not a fabricated traversable road.
let lawn=null;
for(let x=15000;x<21000&&!lawn;x+=100)for(let y=15000;y<18000;y+=100){if(!waterAt(x,y)&&!onRoad(x,y,200)&&!physicalSolid(x,y,0,32)&&!physicalSolid(x+1400,y,0,32)&&!physicalContext({x,y,z:0})){lawn={x,y};break;}}
assert.ok(lawn);Object.assign(civilian,lawn);Object.assign(player,lawn);
const units=[[-260,0],[-300,-180],[-350,180],[-400,300]].map(([x,y])=>{const c=newCar('cop',lawn.x+x,lawn.y+y,0,'cop');c.role='pursuit';cars.push(c);return c;});
policeFix={...lawn,z:0,a:0,seen:true};coordinatePolice(units);
assert.deepEqual(units.map(c=>c.tactic),['tail','contact','flank-left','flank-right']);
let direct=0;for(const c of units){const before={x:c.x,y:c.y};if(ramPursuit(c,.1)&&distance(c,before)>0)direct++;}assert.ok(direct>=3,'Multiple units must drive across open grass');
console.log('Open-ground director assigns tail/contact/two flanks; multiple physical cruisers leave the road');
// Supporting police do not globally forbid a useful contact maneuver.
clean();const slow=newCar('compact',32600,9000,-Math.PI/2,'player'),contact=newCar('cop',32625,9037,-Math.PI/2,'cop'),support=newCar('cop',32680,9080,-Math.PI/2,'cop');
Object.assign(slow,{spd:200,vy:-200});Object.assign(contact,{spd:245,vy:-245,role:'pursuit',tactic:'contact'});support.role='pursuit';player.veh=slow;cars=[slow,contact,support];Object.assign(player,{x:slow.x,y:slow.y});policeFix={x:player.x,y:player.y,z:0,a:slow.a,seen:true};
assert.ok(ramPursuit(contact,1/60));assert.ok(contact.pitAttempt,'Other cruisers do not suppress a safe PIT');
// Ordinary combat affords reaction time but sustained exposure still causes damage.
clean();let shots=0;for(const [x,y] of [[-210,-20],[-190,40]]){const n=newNpc('cop',player.x+x,player.y+y);n.fire=0;npcs.push(n);}
let firstSecond,atFive;advance(9,(dt,i)=>{for(const n of npcs)officerCombat(n,dt,distance(n,player),true);shots=Math.max(shots,bullets.length);updBullets(dt);if(i===59)firstSecond=player.hp;if(i===299)atFive=player.hp;});
console.log('Exposed ordinary response',{firstSecond,atFive,atNine:player.hp});assert.ok(firstSecond>=70,'No one-second firing-squad death');assert.ok(atFive>0,'Player has time to reach cover');assert.ok(player.hp<80,'Open exposure is still dangerous');
const watcher=npcs[0];player.veh=newCar('sedan',player.x,player.y,0,'player');officerCombat(watcher,1/60,200,true);player.veh=null;time+=.01;officerCombat(watcher,1/60,200,true);const grace=watcher.reacquireUntil;assert.ok(grace>time);player.veh={};officerCombat(watcher,1/60,200,true);player.veh=null;time+=.1;officerCombat(watcher,1/60,200,true);assert.equal(watcher.reacquireUntil,grace,'Seat hopping cannot renew the reacquisition delay');
// Leaning is a ground-vehicle control, uses a real left-window muzzle, and shares pistol ammunition.
clean();const car=newCar('sedan',32600,9000,0,'player');player.veh=car;cars=[car];keys.KeyQ=true;selectSlot(1);inventory.mag=12;player.fireT=0;player.reloadT=0;updateLean(.5);camera();mouse.down=true;updateWeapon(1/60,true);mouse.down=false;
assert.ok(leaning());assert.equal(inventory.mag,11);assert.equal(bullets.length,1);const muzzle=windowMuzzle();assert.ok(muzzle.y<car.y-car.wid/2);assert.ok(bullets[0].y<car.y-car.wid/2);
look(50,50);assert.ok(angD(view.yaw,car.a)<=.121);assert.ok(view.pitch<=.6);const hp=player.hp,exposed=windowPose().head;assert.ok(projectileAt({o:'c',dmg:8},exposed.x,exposed.y,exposed.z));assert.equal(player.hp,hp-8,'Exposed leaning torso can be hit');
keys.KeyQ=false;updateLean(.5);assert.ok(!leaning());player.fireT=0;mouse.down=true;updateWeapon(.1,true);mouse.down=false;assert.equal(bullets.length,1,'Retracted driver cannot shoot');car.type='heli';keys.KeyQ=true;assert.ok(!leaning(),'Q remains aircraft descent');
console.log('Q window aim, pistol ammo, left-side limits, exposed torso and aircraft exclusion pass');
// The copter only reports a player in its physical, unoccluded cone.
clean();worldClock.phase=400;airUnit={x:32600,y:8600,z:620,a:Math.PI/2,beamYaw:Math.PI/2,beamPitch:Math.atan2(15-608,400)};let beam=helicopterBeam();assert.ok(lightStrength(beam,player)>.1);airUnit.beamYaw=0;assert.equal(lightStrength(helicopterBeam(),player),0);
const office=buildingNamed('The Mariner Grand');Object.assign(player,{x:office.x+office.w*.25,y:office.y+office.d*.25,z:0});airUnit={x:player.x+30,y:player.y,z:620,a:Math.PI,beamYaw:Math.PI,beamPitch:Math.atan2(15-608,30)};assert.equal(lightStrength(helicopterBeam(),player),0,'A real building ceiling blocks aerial tracking');
console.log('Copter uses the visible search cone and real occlusion, without a weapon');
// Dynamic light transforms are fresh at every movement tick, and source identities persist.
clean();worldClock.phase=400;const lit=newCar('sport',32600,9000,0,'player');cars=[lit];player.veh=lit;updateWorldLights();const first=worldLights.find(l=>l.owner===lit);lit.x+=30;time+=1/120;updateWorldLights();const second=worldLights.find(l=>l.owner===lit);assert.equal(second.id,first.id);assert.equal(second.x-first.x,30,'Headlights cannot lag behind a fast car');
for(const s of beamSlots){s.light=null;s.weight=0;}Object.assign(eye,{x:lit.x,y:lit.y,z:70});selectShadowLights(.25);const index=beamSlots.findIndex(s=>s.light?.owner===lit);assert.ok(index>=0);const retained=beamSlots[index].light.id;
worldLights.push(...Array.from({length:12},(_,i)=>makeLight(lit.x+i*5,lit.y,20,0,0,500,.4,[1,1,1],{})));time+=1;selectShadowLights(.1);assert.equal(beamSlots[index].light.id,retained,'Player headlight keeps its slot in a crowd');
worldLights=[];selectShadowLights(.05);assert.ok(beamSlots[index].weight>0&&beamSlots[index].weight<1,'Source removal fades instead of popping');
const pools=streetLightGeometry();assert.ok(pools.length>20&&pools.some(c=>c.data.length>1000));assert.ok(pools.every(c=>c.data.every((v,i)=>i%7!==6||v===20)));
console.log('Per-tick headlights, stable shadow slots, smooth retirement and cached citywide street pools pass');

// Three stars dispatch the unarmed spotter for ordinary cars too.
clean();const ordinary=newCar('compact',32600,9000,0,'player');cars=[ordinary];player.veh=ordinary;wanted=3;policeFix={x:player.x,y:player.y,z:0,a:0,seen:true};advance(10,dt=>updateAirAndSpikes(dt));assert.ok(airUnit,'Ordinary cars can receive air support at three stars');assert.equal(bullets.length,0);
console.log('Three-star ordinary-car chase dispatches an unarmed copter from outside view');
// Boat crew never fires while on patrol or pursuing a swimmer.
clean();seedMarinePatrols();const launch=cars.find(c=>c.marine&&!c.prisonLaunch);cars=[launch];npcs=launch.crew;Object.assign(player,{x:launch.x+100,y:launch.y,z:SWIM_FEET,inWater:true,swimming:true});policeFix={x:player.x,y:player.y,z:player.z,seen:true};advance(1,dt=>{updateMarine(launch,dt);for(const n of launch.crew)updNpc(n,dt);});assert.equal(bullets.length,0);assert.ok(launch.crew.every(n=>!n.weaponDrawn&&!n.aim));
console.log('Marine pursuit is containment/boarding, without routine boat gunfire');

// Actual slow-car physics plus mild weaving must not defeat every contact unit.
clean();Object.assign(player,lawn);const weaving=newCar('compact',lawn.x,lawn.y,0,'player');Object.assign(weaving,{spd:220,vx:220});player.veh=weaving;cars=[weaving];
const pursuing=[[-140,-35],[-230,55],[-360,150]].map(([x,y])=>{const c=newCar('cop',lawn.x+x,lawn.y+y,0,'cop');Object.assign(c,{role:'pursuit',spd:260,vx:260});cars.push(c);return c;});
let closest=Infinity,attempts=0;advance(8,(dt,i)=>{stepCar(weaving,1,Math.sin(i*.07)*.04,false,false,dt);Object.assign(player,{x:weaving.x,y:weaving.y,z:weaving.z||0});policeFix={x:player.x,y:player.y,z:player.z,a:weaving.a,seen:true};if(i%30===0)coordinatePolice(pursuing);for(const c of pursuing){ramPursuit(c,dt);if(c.pitAttempt)attempts++;closest=Math.min(closest,distance(c,weaving));carCollide(c,weaving);}});
console.log('Physical compact-car weave',{closest,attempts,hp:weaving.hp,pits:pursuing.filter(c=>c.pitCooldown>time).length});assert.ok(closest<85&&attempts>0,'A slight weave in a slow car must still receive a real contact attempt');
assert.ok(weaving.hp<weaving.maxHp,'Coordinated pressure must produce physical vehicle contact in this fixed slow-car scenario');
// A road interceptor holds a reachable, fixed post instead of chasing a moving marker.
clean();const roadRunner=newCar('sedan',32600,9000,-Math.PI/2,'player');Object.assign(roadRunner,{spd:700,vy:-700});player.veh=roadRunner;cars=[roadRunner];
const roadTeam=[[32600,9280],[32600,6500],[32600,6000]].map(([x,y])=>{const c=newCar('cop',x,y,-Math.PI/2,'cop');c.role='pursuit';const p=roadAnchor(x,y,c.a);c.leg={e:p.e,dir:p.dir};c.route=[];cars.push(c);return c;});
policeFix={x:player.x,y:player.y,z:0,a:roadRunner.a,seen:true};coordinatePolice(roadTeam);const interceptor=roadTeam.find(c=>c.tactic==='intercept');assert.ok(interceptor&&interceptor.tacticGoal?.e);const heldPoint=interceptor.tacticGoal;assert.ok(Number.isFinite(policeTravelDistance(interceptor,heldPoint)));
roadRunner.y-=100;player.y-=100;policeFix.y-=100;time+=.72;coordinatePolice(roadTeam);assert.equal(interceptor.tactic,'intercept');assert.equal(interceptor.tacticGoal,heldPoint,'Replanning must retain the committed intercept point');
console.log('Road interception chooses a connected post and holds it across moving-target replans');
