function setupWindow(){started=true;state='play';mapOpen=false;time+=2;cars=[];npcs=[];bullets=[];parts=[];ob=null;interior=null;elevatorTrip=null;clearPolice();resetInput();worldClock.phase=150;Object.assign(player,{x:32600,y:9000,z:0,veh:null,hp:100,armor:0});const c=newCar('sedan',player.x,player.y,0,'player');c.col='#db7777';cars=[c];player.veh=c;resetLook(0);keys.KeyQ=true;selectSlot(1);inventory.mag=12;player.fireT=player.reloadT=0;updateLean(1);return c;}
for(const yaw of [-2.4,-1.25,-.3])for(const range of [110,330,950]){
 const c=setupWindow();view.yaw=c.a+yaw;view.pitch=-.08;camera();view.pitch=-Math.atan2(eye.z-17,range);camera();
 const n=newNpc('ped',eye.x+eye.fx*eye.cp*range,eye.y+eye.fy*eye.cp*range);n.z=0;npcs=[n];
 const aim=windowAim(true);assert.equal(aim.target.kind,'npc','Center ray must see the target in the reticle');
 const before=n.hp;mouse.down=true;updateWeapon(1/60,true);mouse.down=false;const b=bullets[0];assert.ok(b);
 const dir={x:eye.fx*eye.cp,y:eye.fy*eye.cp,z:eye.sp},t=((aim.target.x-b.x)*dir.x+(aim.target.y-b.y)*dir.y+(aim.target.z-b.z)*dir.z)/(b.vx*dir.x+b.vy*dir.y+b.vz*dir.z);
 assert.ok(t>0);const p=project(b.x+b.vx*t,b.y+b.vy*t,b.z+b.vz*t);assert.ok(hyp(p.x-W/2,p.y-H/2)<4,'Actual shot must cross the reticle within pistol spread');
 const gunTip=windowMuzzle();assert.ok(hyp(gunTip.x-b.x,gunTip.y-b.y,gunTip.z-b.z)<.001,'Rendered barrel and projectile must share the muzzle');
 for(let i=0;i<85&&n.hp===before;i++)updBullets(1/60);assert.ok(n.hp<before,'The production projectile must actually hit the selected target');
}
console.log('Nine near/far/angled camera rays converge through the reticle and actually hit targets');
const car=setupWindow();view.yaw=-1.25;camera();const pose=windowPose();
assert.ok(pose.hip.y>car.y-car.wid*.42,'Seated hips remain inside the cabin');assert.ok(pose.head.y>=car.y-car.wid/2-4.01,'Head peeks just beyond the window');assert.ok(distance(pose.hip,pose.shoulder)<18,'Torso connects the seat to the window');assert.ok(hyp(eye.x-pose.head.x,eye.y-pose.head.y)>140,'Window camera must leave room around the car');const headOnScreen=project(pose.head.x,pose.head.y,pose.head.z);assert.ok(headOnScreen&&headOnScreen.x>W*.5&&headOnScreen.x<W*.9&&headOnScreen.y<H*.9,'Seated peek stays visible beside the reticle');
selectSlot(0);const unarmed=new Mesh();drawCar(unarmed,car);const gunColor=rgb('#303b43');const countGun=m=>m.data.filter((_,i)=>i%7===3&&Math.abs(m.data[i]-gunColor[0])<1e-9&&Math.abs(m.data[i+1]-gunColor[1])<1e-9&&Math.abs(m.data[i+2]-gunColor[2])<1e-9).length;
assert.equal(countGun(unarmed),0,'Unarmed peek cannot render a pistol');const mag=inventory.mag;mouse.down=true;updateWeapon(.1,true);mouse.down=false;assert.equal(bullets.length,0);assert.equal(inventory.mag,mag);
selectSlot(1);const armed=new Mesh();drawCar(armed,car);assert.ok(countGun(armed)>0);assert.ok(armed.data.length>unarmed.data.length);
console.log('Wider camera, seated body continuity, rolled-down window and selected-slot pistol display pass');
// A camera can see over cover while the actual barrel cannot. Display that obstruction.
view.pitch=-.05;camera();const intended=windowAim(true),cover={x:intended.origin.x+intended.dir.x*18,y:intended.origin.y+intended.dir.y*18,z:intended.origin.z+intended.dir.z*18};
const coverBox=solidBox(cover.x,cover.y,7,7,4,{z:cover.z-2});time+=.1;const blocked=windowAim(true);assert.ok(blocked.blocked&&blocked.impact.distance<30,'Muzzle-side cover must block the shot and reticle');
coverBox.active=false;console.log('Muzzle-side cover is detected separately from the camera target');
setupWindow();const cruiser=newCar('cop',player.x+250,player.y,Math.PI,'cop');cars.push(cruiser);
for(const phase of [0,5,12,150,288,299]){worldClock.phase=phase;updateWorldLights();assert.ok(worldLights.every(l=>l.kind!=='headlight'),'No vehicle beams during the day, including dawn/dusk');selectShadowLights(.25);assert.ok(beamSlots.every(s=>s.light?.kind!=='headlight'));const mesh=new Mesh();drawCar(mesh,cruiser);assert.ok(mesh.data.every((v,i)=>i%7!==6||v!==8.35),'Daytime headlamp fixtures must not glow');}
worldClock.phase=400;updateWorldLights();assert.equal(worldLights.filter(l=>l.kind==='headlight').length,2);selectShadowLights(.5);const nightMesh=new Mesh();drawCar(nightMesh,cruiser);assert.ok(nightMesh.data.some((v,i)=>i%7===6&&v===8.35));worldClock.phase=0;updateWorldLights();selectShadowLights(.001);assert.ok(beamSlots.every(s=>s.light?.kind!=='headlight'),'Night beams cannot persist into dawn during a slot fade');
worldClock.phase=400;updateWorldLights();const normal=actorMesh().data.length;worldLights.push(makeLight(player.x,player.y,50,0,0,500,.4,[1,1,1],{}));assert.equal(actorMesh().data.length,normal,'A light source cannot create a floating white emissive box');
console.log('Day/dawn/dusk vehicle lights stay off; night beams and real fixtures work without floating source boxes');
// Vehicle targets use the same chassis/cabin volumes as live bullets.
const shooter=setupWindow();view.yaw=-1.25;view.pitch=-.12;camera();view.pitch=-Math.atan2(eye.z-12,350);camera();const vanTarget=newCar('van',eye.x+eye.fx*eye.cp*350,eye.y+eye.fy*eye.cp*350,-.3,'parked');cars.push(vanTarget);assert.equal(windowAim(true).target.kind,'vehicle');const oldHP=vanTarget.hp;mouse.down=true;updateWeapon(1/60,true);mouse.down=false;for(let i=0;i<85&&vanTarget.hp===oldHP;i++)updBullets(1/60);assert.ok(vanTarget.hp<oldHP,'Reticle-selected vehicle receives the physical projectile');
console.log('Vehicle reticle targeting agrees with actual chassis/cabin hits');
