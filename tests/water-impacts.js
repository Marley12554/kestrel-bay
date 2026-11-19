function resetWater(){
 started=true;state='play';mapOpen=false;cars=[];npcs=[];bullets=[];parts=[];ob=null;follower=null;interior=null;elevatorTrip=null;waterClimb=null;airUnit=null;airDispatch=0;clearPolice();resetInput();heat=wanted=0;crimeThreat=0;
 Object.assign(player,{x:32600,y:9000,z:0,vz:0,hp:100,veh:null,inWater:false,swimming:false,submerged:false,waterJump:false,waterJumpQueued:false,jumpHeld:false,bust:0,stamina:100,breath:100,fireT:0,reloadT:0});
}
function tickWater(seconds,fn=updPlayer){for(let i=0;i<Math.ceil(seconds*60);i++){time+=1/60;fn(1/60);}}
const bridge=roads.find(e=>e.bridge&&e.a.id==='bridgeN1'),a=Math.atan2(bridge.dy,bridge.dx),wet=lanePoint(bridge,1,2400,300);
assert.ok(waterAt(wet.x,wet.y));
// Floating bodies sit in the water with a head above the surface; Q no longer supplies invisibility.
resetWater();Object.assign(player,{...wet,z:0});tickWater(1);assert.ok(player.swimming);assert.ok(Math.abs(player.z-SWIM_FEET)<.01);assert.ok(footEye()>WATER_LEVEL&&footEye()<WATER_LEVEL+5);keys.KeyQ=true;tickWater(.3);assert.ok(!player.submerged);keys.KeyQ=false;
console.log('Surface float is at real water height; Q does not fake a dive');
// Pitch and movement produce genuine depth, which persists after releasing movement.
resetLook(a);view.pitch=-.8;keys.KeyW=true;tickWater(2);keys.KeyW=false;assert.ok(player.z<SWIM_FEET-40&&player.submerged);assert.ok(player.breath<85);assert.ok(footEye()<WATER_LEVEL-25);const depth=player.z;tickWater(.5);assert.ok(Math.abs(player.z-depth)<.01);console.log('Directional dive moves body/camera below water and holds depth');
// Look up and swim to expose the head and recover oxygen.
view.pitch=.9;keys.KeyW=true;tickWater(3);keys.KeyW=false;assert.ok(!player.submerged&&player.breath>85);assert.ok(Math.abs(player.z-SWIM_FEET)<.01);console.log('Swimming upward surfaces and restores oxygen');
// Jumping provides a real ballistic leap instead of a disabled action in water.
keys.Space=true;view.pitch=0;tickWater(.35);assert.ok(player.z>WATER_LEVEL&&player.waterJump);keys.Space=false;tickWater(1);assert.ok(player.swimming&&Math.abs(player.z-SWIM_FEET)<.01);console.log('Space leaps out of water and lands back into a float');
// A swimmer can jump onto a real low pier without swimming through its slab.
resetWater();Object.assign(player,{x:7600,y:23940,z:SWIM_FEET});refreshWaterState();resetLook(-Math.PI/2);keys.Space=true;keys.KeyW=true;tickWater(.55);keys.Space=keys.KeyW=false;tickWater(.5);assert.ok(!player.swimming&&player.y<23917.5&&player.y>23882.5&&Math.abs(player.z-6)<1);console.log('Water jump reaches the physical marina pier');
// No transparent-water advantage or walking on a hidden ocean floor at z=0.
resetWater();Object.assign(player,{...wet,z:SWIM_FEET-45});refreshWaterState();Object.assign(eye,{x:player.x,y:player.y,z:footEye()});const observer={...lanePoint(bridge,1,2400,92),z:120,kind:'cop'};assert.ok(!seesPlayer(observer,620));assert.ok(!lineOfSight(observer,player));assert.ok(!visibleFromCamera(wet.x,wet.y,120));
Object.assign(player,{z:SWIM_FEET});refreshWaterState();assert.ok(seesPlayer(observer,620),'A surfaced head must be visible through gaps in the bridge rail');assert.ok(lineOfSight(observer,player));
const watch=coastalGoal(observer,{...wet,z:SWIM_FEET});assert.ok(roadDistance(bridge,watch.x,watch.y)<bridge.width/2+25&&watch.z===120);const moved=coastalGoal(observer,{x:wet.x+bridge.dx*400,y:wet.y+bridge.dy*400,z:SWIM_FEET});assert.ok(distance(watch,moved)>350);console.log('Cops reacquire a surfaced head and track along the bridge edge');
// Bridge rescue ladders are genuine routes from water to the elevated sidewalk.
resetWater();const ladder=waterExits.find(e=>e.name==='Bridge rescue ladder'&&e.z===120);Object.assign(player,{x:ladder.x,y:ladder.y,z:SWIM_FEET});refreshWaterState();assert.equal(nearbyWaterExit(),ladder);useWaterExit(ladder);tickWater(4,dt=>{if(waterClimb)updateWaterClimb(dt);});assert.ok(!waterClimb&&Math.abs(player.z-120)<1);assert.ok(supportHeight(player.x,player.y,player.z)>110);console.log('Physical rescue ladder returns a swimmer to the bridge deck');
// Oxygen loss causes ordinary death while genuinely below the surface.
resetWater();Object.assign(player,{...wet,z:SWIM_FEET-50,breath:1});refreshWaterState();tickWater(6);assert.equal(state,'wasted');console.log('Actual submersion can drown the player');
// Reinforcements must travel from land instead of appearing on an exposed bridge.
resetWater();heat=119;wanted=5;const p=lanePoint(bridge,1,bridge.len*.5,25);Object.assign(player,{...p,z:120,a});policeFix={...p,z:120,a,seen:true};assert.ok(sendCruiser('pursuit',policeFix));const sent=cars.find(c=>c.kind==='cop');assert.ok(!sent.leg.e.bridge&&sent.z===0);assert.ok(distance(sent,player)>8*(CT.cop.maxV+MOVEMENT.sprint));assert.ok(!visiblePoliceSpawn(sent,sent.a));console.log('Bridge reinforcements use unseen land approaches with real travel time');
// Glancing along a rail loses only the small normal velocity, not all forward kinetic energy.
resetWater();const railPosition=lanePoint(bridge,1,3000,bridge.width/2+7),sport=newCar('sport',railPosition.x,railPosition.y,a+.02,'player');sport.z=120;sport.vx=bridge.dx*1150-bridge.dy*30;sport.vy=bridge.dy*1150+bridge.dx*30;sport.spd=1150;cars=[sport];player.veh=sport;tickWater(.7,dt=>updCar(sport,dt));console.log('Railing graze',{hp:sport.hp,speed:sport.spd,dead:sport.dead});assert.ok(sport.hp>sport.maxHp*.9&&!sport.dead&&sport.spd>900);console.log('High-speed railing graze preserves car health and forward motion');
// Clear full-speed bridge entry must not register a phantom collision or damage at a seam.
resetWater();const ramp=roads.find(e=>e.bridge&&isLand(e.a.x,e.a.y)),rampCar=roadCar('sport',ramp,1,20,'player');cars=[rampCar];player.veh=rampCar;rampCar.vx=ramp.dx*1100;rampCar.vy=ramp.dy*1100;rampCar.spd=1100;tickWater(1,dt=>updCar(rampCar,dt));assert.ok(rampCar.hp===rampCar.maxHp&&!rampCar.dead&&rampCar.z>80);console.log('Full-speed ramp entry causes no phantom damage');
// A real impact is capped; a wreck/fire gives a visible ten-second escape window.
resetWater();const damaged=newCar('sport',32600,9000,0,'player');cars=[damaged];player.veh=damaged;const hit=impactDamage(damaged,1400);assert.ok(hit>0&&hit<damaged.maxHp*.5&&damaged.hp>0);damaged.hp=damaged.maxHp*.12;updateVehicleCondition(damaged,0);assert.ok(damaged.onFire&&damaged.fireRemaining===10);const fx=new Mesh();drawVehicleCondition(fx,damaged);assert.ok(fx.data.length>0);damaged.hp=0;wreck(damaged);assert.ok(player.veh===damaged&&!damaged.exploded);tickWater(3,dt=>updCar(damaged,dt));assert.ok(!damaged.exploded&&state==='play');contextAction();assert.ok(!player.veh);Object.assign(player,{x:damaged.x+200,y:damaged.y});tickWater(8,dt=>updCar(damaged,dt));assert.ok(damaged.exploded&&state==='play');console.log('Impact/fire state warns visibly and permits escape before explosion');
// Blast damage respects height, so a lower-level explosion cannot kill you on a tall bridge.
resetWater();Object.assign(player,{x:32600,y:9000,z:200});explode(player.x,player.y,100,150,false,0);assert.equal(player.hp,100);console.log('Explosion range includes vertical separation');
