startGame();state='play';resetInput();
// Route requests enqueue work; they must never run an entire search in updateMarine.
let wholeRoutes=0;const oldRoute=seaRoute;seaRoute=()=>{wholeRoutes++;throw Error('Synchronous marine search in live update');};
for(let i=0;i<300;i++)update(1/60);assert.equal(wholeRoutes,0);seaRoute=oldRoute;
assert.ok(marineNavigation.lastSteps<=marineNavigation.maxSteps);
console.log('Live simulation never invokes synchronous full marine searches');
// A deliberately expensive route yields across updates and shares the global allowance.
marineNavigation.queue=[];const c=cars.find(c=>c.marine);c.routePending=null;const oldPath=c.route.slice();requestSeaRoute(c,{x:64000,y:2500});
assert.equal(c.route.length,oldPath.length);assert.ok(c.routePending);workMarineNavigation();assert.ok(marineNavigation.lastSteps<=40);assert.ok(c.routePending,'Long jobs must yield rather than block a frame');
const first=c.routePending;requestSeaRoute(c,{x:50000,y:3000});assert.equal(c.routePending,first,'Pending searches cannot be restarted every frame');
assert.equal(marineNavigation.queue.filter(t=>t.car===c).length,1);
// Pending work rotates between units rather than letting the first search monopolize time.
const progress=[0,0,0],tasks=progress.map((_,i)=>({car:{dead:false},search:(function*(){for(let j=0;j<100;j++){progress[i]++;yield;}return [];})()}));
const savedCars=cars;cars=tasks.map(t=>t.car);for(const t of tasks)t.car.routePending=t;marineNavigation.queue=tasks.slice();workMarineNavigation();
assert.ok(progress.every(n=>n>0));assert.ok(Math.max(...progress)-Math.min(...progress)<=1);assert.ok(progress.reduce((a,b)=>a+b,0)<=40);
cars=savedCars;marineNavigation.queue=[];c.routePending=null;
console.log('Long routes are deferred, deduplicated, globally capped and scheduled fairly');
// Offscreen military/prison guards retain their post until the player is nearby.
let paths=0;const oldFoot=footPath;footPath=(...args)=>{paths++;return oldFoot(...args);};
const remote=guard('troop',28000,8000,[{x:28600,y:8000},{x:28600,y:8900}]);Object.assign(player,{x:8400,y:11968,z:0,veh:null});
for(let i=0;i<180;i++){time+=1/60;updGuard(remote,1/60);}assert.equal(paths,0);assert.equal(remote.x,28000);
Object.assign(player,{x:28200,y:8000});baseAlert=0;remote.investigate=null;remote.suspicion=0;const before={x:remote.x,y:remote.y};updGuard(remote,1/60);assert.ok(distance(remote,before)>0);footPath=oldFoot;
console.log('Remote guard pathfinding sleeps; nearby guards immediately resume');
// Visibility queries share one exact light/position sample; moving or changing lights invalidates it.
worldClock.phase=400;Object.assign(player,{x:32600,y:9000,z:0,veh:null});worldLights=[makeLight(32500,9000,20,0,0,800,.4,[1,1,1],{})];let rays=0;const oldSight=lineOfSight;lineOfSight=(...args)=>{rays++;return oldSight(...args);};
const value=illuminationAt(player);for(let i=0;i<20;i++)assert.equal(illuminationAt(player),value);assert.equal(rays,1);player.x++;illuminationAt(player);assert.equal(rays,2);worldLights=worldLights.slice();illuminationAt(player);assert.equal(rays,3);lineOfSight=oldSight;
console.log('Shared night visibility avoids duplicate shadow/LOS work and invalidates correctly');

// An urgent pursuit replaces an obsolete background patrol search immediately.
cars=[c];npcs=c.crew;c.routePending=null;c.role='marinePatrol';requestSeaRoute(c,{x:64000,y:2500});const patrolTask=c.routePending;
wanted=3;crimeThreat=2;Object.assign(player,{x:c.x+500,y:c.y,z:SWIM_FEET,veh:null,inWater:true});policeFix={x:player.x,y:player.y,z:player.z,seen:true};updateMarine(c,1/60);
assert.notEqual(c.routePending,patrolTask);assert.equal(c.role,'shoreContainment');assert.equal(c.routePending.role,'shoreContainment');console.log('Urgent marine response replaces stale patrol work without waiting for it');

// An alarm without a visual fix must not cancel/restart the same job every frame.
c.prisonLaunch=true;c.lastContact=null;prisonAlert=2;wanted=0;policeFix=null;Object.assign(player,{x:c.x+5000,y:c.y,z:SWIM_FEET,inWater:true,veh:null});c.routePending=null;c.role='marinePatrol';c.routeAt=-Infinity;updateMarine(c,1/60);const waiting=c.routePending;assert.ok(waiting.responding);updateMarine(c,1/60);assert.equal(c.routePending,waiting);console.log('Unconfirmed prison alarms retain their bounded search without per-frame restarts');
