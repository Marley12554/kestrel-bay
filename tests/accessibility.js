started=true;state='play';cars=[];npcs=[];resetInput();player.veh=null;
function placeAccess(x,y,z){Object.assign(player,{x,y,z,vz:0,inWater:false,swimming:false,waterJump:false,jumpHeld:false});}
function travelAccess(x,y,frames=180){for(let i=0;i<frames;i++){const dx=x-player.x,dy=y-player.y,d=hyp(dx,dy);if(d<.05)break;const step=Math.min(d,MOVEMENT.jog/60);moveFoot(player,dx/d*step,dy/d*step,7);verticalFoot(player,1/60);}}
let checked=0;
for(const b of buildings.filter(b=>b.floors>3))for(const floor of [...new Set([0,1,b.recordsFloor,b.floors-1])]){
 const plan=planFor(b,floor),sx=b.lift.x,sy=b.lift.y,z=floor*44;b.lift.z=z;
 const apron={x:sx-28,y:sy-80,w:56,d:58};
 assert.ok(!plan.walls.some(r=>r.kind==='furniture'&&rectOverlap(r,apron)),`${b.name} floor ${floor}: blocked elevator apron`);
 for(const offset of [-5,0,5]){placeAccess(sx+offset,sy,z);travelAccess(sx+offset,sy-67);assert.ok(Math.abs(player.y-(sy-67))<.1,`${b.name} floor ${floor}: cannot leave elevator`);assert.ok(Math.abs(player.z-z)<.1);travelAccess(sx+offset,sy);assert.ok(Math.abs(player.y-sy)<.1,`${b.name} floor ${floor}: cannot enter elevator`);}
 checked++;
}
console.log('Clear elevator exit/re-entry on representative lobby, upper, records and top floors:',checked);
// Entry works at three approach offsets, with the rendered frame and body collision in agreement.
let doors=0;for(const b of buildings){b.entryDoor.open=true;const co=Math.cos(b.door.a),si=Math.sin(b.door.a);
 for(const offset of [-8,0,8]){placeAccess(b.door.x-si*offset,b.door.y+co*offset,0);const goal={x:b.door.x+co*42,y:b.door.y+si*42};travelAccess(goal.x,goal.y);assert.ok(distance(player,goal)<.1,`Blocked ${b.front} entry: ${b.name}`);assert.ok(Math.abs(player.z)<.1);}
 doors++;
}console.log('Offset public-door approaches pass for every building:',doors);
const h=buildingNamed('The Mariner Grand'),edge=h.x+h.w/2,plan=planFor(h,3),escape=plan.windows.find(w=>w.escape);escape.broken=true;
// Exit across the façade seam, turn along the walkway, and return through the same opening.
placeAccess(edge-22,h.y,132);travelAccess(edge+ESCAPE.center,h.y);assert.ok(player.x>edge+14);travelAccess(edge+ESCAPE.center,h.y+65);assert.ok(Math.abs(player.y-h.y-65)<.1&&Math.abs(player.z-132)<.1);
travelAccess(edge+ESCAPE.center,h.y);travelAccess(edge-22,h.y);assert.ok(Math.abs(player.x-edge+22)<.1&&Math.abs(player.z-132)<.1);console.log('Broken escape window, façade seam and window-side walkway are traversable both ways');
// A slightly penetrated contact skin must settle onto the landing, not fall through it.
placeAccess(edge+ESCAPE.inner,h.y+46,131);player.vz=-24;moveFoot(player,0,12,7);for(let i=0;i<30;i++)verticalFoot(player,1/60);assert.ok(Math.abs(player.z-132)<.1);console.log('Falling contact at a landing lip resolves onto its top');
// Normal broken windows have a real sill: walk up and over without a precisely timed jump.
const pane=plan.windows.find(w=>w.side==='north'&&!w.escape);pane.broken=true;
placeAccess(pane.x,pane.y+24,132);travelAccess(pane.x,pane.y-10);assert.ok(player.y<pane.y-8,'Broken sill cannot remain an invisible barrier');assert.ok(!keys.Space);console.log('Broken normal window sills step over naturally without jump timing');
// A genuine elevator trip arrives in the same shaft and permits an ordinary walk out.
inventory.key=true;elevatorTrip=null;h.lift.z=0;placeAccess(h.lift.x,h.lift.y-39,0);requestElevator(h,3);
for(let i=0;i<600&&elevatorTrip;i++)updateArchitecture(1/60);assert.equal(elevatorTrip,null);assert.equal(player.z,132);travelAccess(h.lift.x,h.lift.y-67);assert.ok(Math.abs(player.y-h.lift.y+67)<.1&&Math.abs(player.z-132)<.1);console.log('Real elevator arrival opens onto a clear, walkable floor');
