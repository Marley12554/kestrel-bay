const clashes=[];
for(let i=0;i<buildings.length;i++)for(let j=i+1;j<buildings.length;j++){
 const a=buildings[i],b=buildings[j];if(Math.abs(a.x-b.x)<(a.w+b.w)/2+3&&Math.abs(a.y-b.y)<(a.d+b.d)/2+3)clashes.push([a.name,b.name]);
}
console.log('Overlapping footprints',clashes);assert.equal(clashes.length,0);
const inaccessible=[];for(const b of buildings){b.entryDoor.open=true;const angle=b.door.a,inside={x:b.door.x+Math.cos(angle)*38,y:b.door.y+Math.sin(angle)*38};navigationZ=0;if(!walkClear(b.door.x,b.door.y,inside.x,inside.y))inaccessible.push(b.name);b.entryDoor.open=false;}
console.log('Blocked entry paths',inaccessible);assert.equal(inaccessible.length,0);
const remote=buildings.filter(b=>nearestRoad(b.door.x,b.door.y).d>=600);console.log('Remote entrances',remote.map(b=>[b.name,nearestRoad(b.door.x,b.door.y).d]));assert.equal(remote.length,0);
// Slabs occlude sight between occupied floors, clear glass admits sight, intact glass blocks bodies.
const h=buildingNamed('The Mariner Grand'),p=planFor(h,3),glassPane=p.windows.find(w=>w.side==='north');
assert.equal(lineOfSight({x:h.x,y:h.y,z:88},{x:h.x,y:h.y,z:132}),false);
assert.ok(architectureBlocks(h,glassPane.x,glassPane.y,132,24));
glassPane.broken=true;assert.ok(!architectureBlocks(h,glassPane.x,glassPane.y,143,12));glassPane.broken=false;
// Shots use the shipped firing and projectile pipeline, including height and lock/glass contacts.
started=true;state='play';player.veh=null;resetInput();const shotRoom=p.rooms.find(r=>r.side<0&&r.x<h.x),shotDoor=shotRoom.door;
Object.assign(player,{x:shotDoor.x,y:shotDoor.y+18,z:132,vz:0,reloadT:0,fireT:0});interior=physicalContext(player);selectSlot(1);resetLook(-Math.PI/2);keys.KeyJ=true;updPlayer(1/60);keys.KeyJ=false;updBullets(.05);assert.ok(shotDoor.broken&&shotDoor.open);
const escape=p.windows.find(w=>w.escape);Object.assign(player,{x:escape.x-18,y:escape.y,z:132,fireT:0});resetLook(0);keys.KeyJ=true;updPlayer(1/60);keys.KeyJ=false;updBullets(.05);assert.ok(escape.broken);selectSlot(0);moveFoot(player,26,0,7);verticalFoot(player,1/60);assert.ok(player.x>h.x+h.w/2&&Math.abs(player.z-132)<.01);console.log('Actual gunfire breaks room lock and exit glass; player steps onto the real landing');

// Officers breach the correct locked guest room, not every door on the floor.
started=true;state='play';wanted=3;heat=60;crimeThreat=2;cars=[];npcs=[];player.veh=null;
const room=p.rooms.find(r=>r.side<0&&r.x>h.x),d=room.door;
Object.assign(player,{x:d.x,y:d.y-45,z:132});interior=physicalContext(player);policeFix={x:player.x,y:player.y,z:132,seen:true};
const officer=newNpc('cop',d.x,d.y+18);officer.z=132;npcs=[officer];
for(let i=0;i<240;i++){time+=1/60;updOfficer(officer,1/60);}
assert.ok(d.open&&d.broken);assert.ok(officer.y<d.y);console.log('Officer breached and entered occupied guest room');
// Fire escape descent retains real heights, including the last landing to street.
const x=h.x+h.w/2+39;Object.assign(player,{x,y:h.y+65,z:132,vz:0});
for(let floor=2;floor>=0;floor--){
 moveFoot(player,h.x+h.w/2+(floor%2===0?35:65)-player.x,0,7);
 const start=h.y+(floor%2===0?-65:65),end=h.y+(floor%2===0?65:-65),dy=(start-end)/140;
 for(let i=0;i<140;i++){moveFoot(player,0,dy,7);verticalFoot(player,1/60);}
 console.log('Descent',floor,player.x,player.y,player.z);
 assert.ok(Math.abs(player.z-floor*44)<5,'stair descent missed floor '+floor);
}
for(let i=0;i<20;i++)verticalFoot(player,1/60);assert.ok(Math.abs(player.z)<.01);console.log('Continuous fire escape descent reaches street');
// Bridge cars are supported on the visible deck, boats can pass beneath it.
const bridge=roads.find(e=>e.bridge&&e.len>6000),point=lanePoint(bridge,1,bridge.len*.5,0),z=bridgeHeight(bridge,bridge.len*.5);
assert.equal(supportHeight(point.x,point.y,z),z);assert.ok(z>80);assert.ok(waterAt(point.x,point.y));console.log('Physical bridge support and water below pass');

// Map click coordinates select a normal navigation target; the HUD uses that target on its next draw.
ob=null;mapProjection={x:0,y:0,s:.01};mapCanvas.getBoundingClientRect=()=>({left:0,top:0});
setMapWaypoint({clientX:h.x*.01,clientY:h.y*.01});assert.equal(navTarget.title,'The Mariner Grand');updateNav(1);assert.ok(navRoute.length>2);drawHud();assert.ok($('objective-text').textContent.startsWith('Navigate to The Mariner Grand'));console.log('Map click, navigation route and next-frame HUD pass');

const lobbyCar=newCar('sedan',h.x,h.y,0,'parked');stepCar(lobbyCar,0,0,true,false,1/60);assert.equal(lobbyCar.z,0,'Ground-floor cars must not snap to an upper floor');console.log('Ground vehicle floor support stays on its current level');
