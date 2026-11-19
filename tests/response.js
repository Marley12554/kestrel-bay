function reset(){started=true;state='play';mapOpen=false;cars=[];npcs=[];bullets=[];heat=wanted=0;ob=null;follower=null;clearPolice();resetInput();incidentLedger.clear();airUnit=null;airDispatch=0;spikes=[];Object.assign(player,{x:32600,y:9000,z:0,vz:0,hp:100,veh:null,bust:0,stamina:100,fireT:0,reloadT:0});interior=null;elevatorTrip=null;resetLook(-Math.PI/2);}
function tick(t,fn){for(let i=0;i<Math.round(t*60);i++){time+=1/60;frameDt=1/60;fn(1/60);}}
reset();keys.KeyW=keys.ShiftLeft=true;let start=player.y;tick(2,updPlayer);assert.ok(Math.abs((start-player.y)/2-135)<.01);console.log('Sprint',135,'units/s');
const speeds={};
for(const type of ['sedan','taxi','van','muscle','sport','cop','interceptor']){
 reset();const c=newCar(type,31000,15000,0,'player');
 // A long unobstructed test road excludes terrain/traffic from the ratio measurement.
 const oldPaved=paved,oldSolid=solidCar,oldSupport=supportHeight;paved=()=>true;solidCar=()=>false;supportHeight=()=>0;
 tick(25,dt=>stepCar(c,1,0,false,false,dt));paved=oldPaved;solidCar=oldSolid;supportHeight=oldSupport;
 speeds[type]=c.spd;assert.ok(c.spd>CT[type].maxV*.90);
}
assert.ok(speeds.interceptor/speeds.cop>1.15&&speeds.interceptor/speeds.cop<1.25);console.log('Measured mph',Object.fromEntries(Object.entries(speeds).map(([k,v])=>[k,Math.round(v*.17045)])),'sports/cruiser ratio',speeds.interceptor/speeds.cop);
reset();const victim=newNpc('ped',player.x+10,player.y);const inc=incidentFor(38,victim);for(let i=0;i<3;i++)reportCrime(38,{x:victim.x,y:victim.y,incident:inc});assert.equal(heat,38);const inc2=incidentFor(45,victim);reportCrime(45,{x:victim.x,y:victim.y,incident:inc2});assert.equal(heat,45);console.log('Incident dedupe',heat);
reset();wanted=3;heat=60;player.bust=.7;player.veh=newCar('sedan',player.x,player.y,0,'player');tick(.5,dt=>{updateArrest(dt);updPlayer(dt);});assert.ok(player.bust<.1);console.log('Arrest decays in vehicle');
reset();wanted=3;heat=60;
const hotel=buildingNamed('The Mariner Grand');Object.assign(player,{x:hotel.x+200,y:hotel.y,z:132});interior=physicalContext(player);policeFix={x:player.x,y:player.y,z:132,seen:true};
const officer=newNpc('cop',hotel.x+hotel.w/2+39,hotel.y-65);npcs=[officer];officer.z=0;
tick(12,dt=>updOfficer(officer,dt));console.log('Officer upstairs',officer.x,officer.y,officer.z,physicalContext(officer)?.floor,officer.stairRoute?.points.length);
assert.ok(officer.z>=130,'Officer must climb real stair flights');assert.ok(physicalContext(officer)?.building===hotel,'Officer must enter through upper window');
reset();wanted=3;heat=60;
const c=newCar('cop',32600,9200,0,'cop');c.role='staged';cars=[c];const n=newNpc('cop',32600,9260);n.cruiser=c;npcs=[n];player.veh=newCar('sport',32600,8500,0,'player');policeFix={x:player.x,y:player.y,z:0,seen:true};tick(2,dt=>updOfficer(n,dt));assert.ok(n.boarded);assert.equal(c.role,'pursuit');console.log('Physical reboarding passed');
reset();wanted=3;heat=60;player.veh=newCar('interceptor',32600,9000,0,'player');policeFix={x:player.x,y:player.y,z:0,a:0,seen:true};tick(9,updateAirAndSpikes);assert.ok(airUnit&&airUnit.kind==='airPolice');console.log('Helicopter dispatched');
reset();wanted=3;heat=60;const e=roads.find(e=>e.name.includes('Airfield Road'));const p=lanePoint(e,1,e.len*.5,0),block=roadCar('cop',e,1,e.len*.5,'cop');block.role='block';block.parkedAtPost=true;cars=[block];Object.assign(player,{x:p.x+500,y:p.y,z:0});player.veh=newCar('interceptor',player.x,player.y,0,'player');policeFix={x:player.x,y:player.y,seen:true};tick(.1,updateAirAndSpikes);assert.ok(spikes.length);const s=spikes[0];Object.assign(player.veh,{x:s.x,y:s.y,z:s.z});cars.push(player.veh);tick(.1,updateAirAndSpikes);assert.equal(player.veh.tires,4);console.log('Physical spikes puncture tires');

reset();wanted=3;heat=60;Object.assign(player,{x:35460,y:23080,z:0});policeFix={x:player.x,y:player.y,z:0,seen:true};const offroadCop=newCar('cop',35460,23500,-Math.PI/2,'cop');offroadCop.role='pursuit';cars=[offroadCop];const initialDistance=distance(offroadCop,player);tick(1.5,dt=>ramPursuit(offroadCop,dt));assert.ok(distance(offroadCop,player)<initialDistance-180);assert.ok(!onRoad(offroadCop.x,offroadCop.y));console.log('Cruiser crossed passable ground off the road');
reset();wanted=3;heat=60;const targetHotel=buildingNamed('The Mariner Grand');Object.assign(player,{x:targetHotel.x,y:targetHotel.y,z:132});interior=physicalContext(player);policeFix={x:player.x,y:player.y,z:132,seen:true};const lead=newCar('cop',targetHotel.x-700,targetHotel.y,0,'cop'),cutoff=newCar('cop',targetHotel.x+700,targetHotel.y,Math.PI,'cop');lead.role=cutoff.role='pursuit';cars=[lead,cutoff];pursuitTarget(lead);const interception=pursuitTarget(cutoff);assert.ok(cutoff.cutoff);assert.equal(interception.x,targetHotel.x+targetHotel.w/2+100);assert.equal(interception.z,0);console.log('Second cruiser covers the real lower fire exit');

reset();const cityCamera=streetCameras.find(c=>inside(c.x,c.y,cityIsland)),power=securitySites.find(s=>s.id==='prisonPower');Object.assign(player,{x:cityCamera.x+20,y:cityCamera.y+20,z:0});power.disabled=true;assert.ok(cameraTracking(),'Prison power must not disable Meridian surveillance');power.disabled=false;console.log('Prison sabotage leaves city cameras operational');
