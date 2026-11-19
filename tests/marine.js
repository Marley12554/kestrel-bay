startGame();state='play';worldClock.phase=150;resetInput();
assert.equal(cars.filter(c=>c.marine).length,7);assert.equal(cars.filter(c=>c.prisonLaunch).length,2);
const launches=cars.filter(c=>c.marine);for(const c of launches){assert.ok(waterHullClear(c,c.x,c.y));assert.equal(c.crew.length,2);}
const launch=launches.find(c=>!c.prisonLaunch);const route=seaRoute(launch,{x:33300,y:23620});assert.ok(route.length>4,'Long crossing needs a real coastal water route');let last=launch;for(const p of route){assert.ok(waterSegment(launch,last,p),'Every routed hull segment clears land and bridge supports');last=p;}
assert.ok(!waterSegment(launch,{x:6500,y:24000},{x:17000,y:14000}));console.log('Seven persistent launches; actual swept-hull route from harbor to prison');
// Movement integrates along the valid water path without teleporting to the player.
cars=[launch];npcs=launch.crew;wanted=3;crimeThreat=2;heat=60;Object.assign(player,{x:launch.x+1200,y:launch.y,z:SWIM_FEET,veh:null,inWater:true,submerged:false});policeFix={x:player.x,y:player.y,z:player.z,a:0,seen:true};
let moved=0;for(let i=0;i<120;i++){time+=1/60;const before={x:launch.x,y:launch.y};updateMarine(launch,1/60);assert.ok(distance(before,launch)<15);assert.ok(waterHullClear(launch,launch.x,launch.y));moved+=distance(before,launch);}
assert.ok(moved>30);assert.equal(launch.role,'shoreContainment');console.log('Marine response travels physically through water with shore containment role');
// A stopped boat is boardable after sustained close contact. Accelerating cancels.
const water={x:32640,y:23760};assert.ok(waterAt(water.x,water.y));
Object.assign(launch,{x:water.x,y:water.y,a:0,spd:0,route:[],routeAt:time});
const target=specialVehicle('boat',water.x+105,water.y,0,'player');target.owned=true;player.veh=target;Object.assign(player,{x:target.x,y:target.y,z:target.z});cars=[launch,target];npcs=launch.crew;wanted=3;crimeThreat=0;
for(let i=0;i<60;i++){time+=1/60;updateMarine(launch,1/60);}assert.ok(launch.boarder);assert.equal(player.veh,target);target.spd=180;time+=1/60;updateMarine(launch,1/60);assert.ok(!launch.boarder);assert.equal(player.veh,target);
target.spd=0;for(let i=0;i<180&&player.veh;i++){time+=1/60;updateMarine(launch,1/60);}assert.equal(player.veh,null);assert.ok(player.inWater);console.log('Physical boarding has a warning period, cancels on acceleration, and forces an idle occupant out');
// No marine officer remotely arrests a swimmer from inside their launch.
wanted=3;player.bust=0;launch.crew.forEach(n=>{n.boarded=true;n.cruiser=launch;});for(let i=0;i<120;i++)updateArrest(1/60);assert.equal(player.bust,0);console.log('No arrest through water or from a boarded crew member');
