"""Build exactly Manhattan tax block 812 between Broadway, Sixth, W36 and W37.

Survey geometry: NYC DoITT / TUM CityGML. Landmark elevations: NYC Landmarks
Preservation Commission LP-1766, pp. 4-6. The upper office bay dimensions of
the other parcels are estimates within their surveyed exterior surfaces.
"""
from pathlib import Path
import sys, math, importlib.util
import xml.etree.ElementTree as ET
import numpy as np
from shapely.geometry import Polygon, box
from shapely.geometry.polygon import orient
import shapely

root=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(root/"scripts/survey"),str(root/"scripts")]
from grade import Grade, EAST, NORTH, DATUM, CACHE, polygons

def module(name, filename):
    spec=importlib.util.spec_from_file_location(name,filename)
    m=importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m

model=module("herald_builder",root/"scripts/survey/build-herald.py")
surface=module("midtown_builder",root/"scripts/mesh-midtown.py")
stage=root/"dist/unreal-staging"
model.FINISH.update({"RetailGlazing":("749092",.16,0),"IndigoCloth":("37516c",.94,0),
                     "OchreCloth":("b0824f",.94,0),"RussetCloth":("874e44",.92,0)})
bins={"1015241","1015242","1015243","1015244"}

class NativeTile(surface.Tile):
    """Cut the old CityGML walls where the source game draws its authored replacements."""
    def write_face(self,rings,base,color,street,tag=255):
        outer=rings[0]
        if street or tag!=255 or base==0 or np.ptp(outer[:,2])<.1:
            return super().write_face(rings,base,color,street,tag)
        relative=outer[:,:2]-[EAST-208.099,NORTH-573.891]
        local=relative @ np.array([[.873,-.488],[-.488,-.873]])
        if local[:,0].max()<32 or local[:,0].min()>126 or local[:,1].max()<-31 or local[:,1].min()>30:
            return super().write_face(rings,base,color,street,tag)
        cuts=[(0,64.40,65.25,-30.18,28.74,26.29),(1,28.41,29.36,32.54,65.25,26.29),
              (1,-30.6,-29.3,46.95,65.25,4.98),(0,96.05,96.56,11.49,29.15,22.66),(1,28.92,29.26,96.2,125.51,22.66)]
        for axis,lo,hi,start,end,height in cuts:
            if not (local[:,axis].min()>=lo and local[:,axis].max()<=hi):continue
            along=1-axis
            if local[:,along].max()<start or local[:,along].min()>end:continue
            anchor=outer[0,:2]
            k=np.argmax(abs(local[:,along]-local[0,along]))
            delta=local[k,along]-local[0,along]
            if abs(delta)<.01:continue
            direction=(outer[k,:2]-anchor)/delta
            uv=Polygon(np.column_stack((local[:,along],outer[:,2]-base)))
            if not uv.is_valid:uv=uv.buffer(0)
            if uv.is_empty:continue
            for part in polygons(uv.difference(box(start,-500,end,height))):
                rebuilt=[]
                for ring in [part.exterior,*part.interiors]:
                    coords=np.array(ring.coords)[:-1]
                    xy=anchor+(coords[:,0]-local[0,along])[:,None]*direction
                    rebuilt.append(np.column_stack((xy,coords[:,1]+base)))
                super().write_face(rebuilt,base,color,street,tag)
            return
        super().write_face(rings,base,color,street,tag)

def cylinder(face,u,b,t,offset,rings):
    points=[]
    for h,r in rings:
        ring=[face.pt(u+math.cos(a)*r*(.977+.023*math.cos(20*a)),b+(t-b)*h,offset+math.sin(a)*r*(.977+.023*math.cos(20*a))) for a in np.arange(80)*math.tau/80]
        if points:
            for i in range(80): face.mesh.face("IndianaStone",[points[i-1],points[i],ring[i],ring[i-1]])
        points=ring

def classical(f,street,base,roof):
    w=f.length
    # Separate podium, colonnade, entablature and attic at pedestrian scale.
    h=roof-base
    podium=base+.26*h
    cap=base+.79*h
    for low,high,d in [(base-.3,base+.7,.12),(podium-.42,podium,.48),(cap,cap+1.1,.52),(roof-.45,roof,.44)]:
        f.slab(0,w,low,high,d,0,"Granite" if low<base else "IndianaStone")
    cols={"Broadway":8,"36th":9,"Sixth":6}[street]
    centers=np.linspace(w*.105,w*.895,cols)
    doors=(street!="36th")
    for i,u in enumerate(np.linspace(w*.095,w*.905,10 if not doors else 7)):
        door=doors and i==3
        half=1.05 if door else .68
        sill=base+.15 if door else base+1.3
        f.slab(u-half,u+half,sill,podium-.85,.14,.01,"Bronze" if door else "DarkSash")
        for x in np.linspace(u-half+.1,u+half-.1,4):
            f.slab(x-.022,x+.022,sill,podium-.85,.20,.14,"Bronze")
    for u in centers:
        r=min(1.05,(centers[1]-centers[0])*.24)
        f.slab(u-1.22*r,u+1.22*r,podium,podium+.42,.94,-.12,"IndianaStone")
        cylinder(f,u,podium+.28,cap,.22 if street=="36th" else 1.05,
                 [(0,r*1.15),(.025,r*1.22),(.043,r),(.28,r*.98),(.86,r*.84),(.89,r*.93),(.96,r*1.18),(1,r*1.30)])
    for u in np.linspace(.25*w,.75*w,3):
        # Arched banking hall openings behind the monumental order.
        rx=w*.053
        sill=podium+1
        spring=cap-2.4-rx
        arc=[f.pt(u+rx*math.cos(a),spring+rx*math.sin(a),.05) for a in np.linspace(0,math.pi,22)]
        outline=[f.pt(u-rx,sill,.05),f.pt(u+rx,sill,.05)]+arc
        f.mesh.face("Window",outline,[(0,j,j+1) for j in range(1,len(outline)-1)])
        for x in [-.55,0,.55]:
            f.slab(u+x*rx-.035,u+x*rx+.035,sill,spring+rx*math.sqrt(1-x*x),.12,.05,"Bronze")
    for offset in np.arange(.4,w,.86):
        f.slab(offset,offset+.20,cap+.98,cap+1.32,.58,.25,"IndianaStone")

def notions_shop(f,facet,grade):
    """Original garment-district tenant within the measured low-rise parcel."""
    width=f.length
    def ground(u):
        xy=f.a+f.along*u+[EAST,NORTH]
        return float(grade.surface(*xy))+DATUM
    floor=max(ground(0),ground(width))
    ceiling=floor+3.85
    door=(width*.12,width*.12+1.18)
    windows=[(door[1]+.32,width*.54),(width*.54+.19,width-.38)]
    cutouts=[box(*[door[0],floor-.5,door[1],floor+2.6])]
    cutouts.extend(box(l,floor+.38,r,floor+2.94) for l,r in windows)
    f.cut_stone(facet.difference(shapely.union_all(cutouts)),"BuffBrick")
    for l,r in windows:
        f.reveal(l,r,floor+.38,floor+2.94,.03,-.21,"DarkSash")
        f.rect(l,r,floor+.38,floor+2.94,-.12,"RetailGlazing")
        for x in np.linspace(l,r,3):f.slab(x-.034,x+.034,floor+.38,floor+2.94,.045,-.21,"Bronze")
        f.slab(l,r,floor+.37,floor+.44,.12,-.24,"IndianaStone")
    f.reveal(*door,floor,floor+2.6,.02,-.24,"Bronze")
    f.slab(.1,width-.1,ceiling-.7,ceiling-.12,.18,-.02,"KioskIron")
    # These surfaces have real depth when approached head-on from Sixth Avenue.
    def deck(l,r,front,back,z,material):
        f.mesh.face(material,[f.pt(l,z,front),f.pt(r,z,front),f.pt(r,z,back),f.pt(l,z,back)])
    depth=-5.4
    deck(.03,width-.03,.12,depth,floor+.016,"Granite")
    deck(.03,width-.03,.02,depth,ceiling,"Soffit")
    f.rect(.03,width-.03,floor,ceiling,depth,"Lining")
    for x in (.03,width-.03):
        f.mesh.face("Lining",[f.pt(x,floor,0),f.pt(x,floor,depth),f.pt(x,ceiling,depth),f.pt(x,ceiling,0)])
    for k in range(4):
        x=width*(.17+.205*k)
        deck(x-.56,x+.56,-1.1,-1.22,ceiling-.04,"Light")
        for row in range(4):
            y=floor+.50+row*.51
            deck(x-.92,x+.92,-4.82,-5.36,y,"Cabinet")
            for j in range(6):
                left=x-.8+j*.27
                f.slab(left,left+.20,y+.015,y+.27,-4.98,-5.24,["Bronze","Spandrel","Reveal","OfficeBlind"][(k+row+j)%4])
    f.slab(width*.54,width*.84,floor,floor+.91,-2.68,-3.42,"Cabinet")
    for row,(l,r) in enumerate(windows):
        x=(l+r)*.5
        f.slab(x-1.6,x+1.6,floor+.46,floor+.61,-.88,-1.55,"Cabinet")
        for stack in range(6):
            left=x-1.45+stack*.49
            for layer in range(3+(stack%2)):
                y=floor+.61+layer*.085
                f.slab(left,left+.43,y,y+.078,-.96-layer*.014,-1.46,
                       ("IndigoCloth","OchreCloth","RussetCloth")[(stack+layer+row)%3])
    # Level shop floor connects to the surveyed sidewalk through this threshold.
    l,r=door
    f.mesh.face("Granite",[f.pt(l,ground(l)+.018,.38),f.pt(r,ground(r)+.018,.38),f.pt(r,floor+.016,-.25),f.pt(l,floor+.016,-.25)])
    sign=f.pt(width*.51,ceiling-.41,.20)
    return {"text":"SELVEDGE  /  FABRIC & NOTIONS","position":sign,"normal":[f.out[0],0,-f.out[1]],"lamps":[f.pt(width*t,ceiling-.12,-2.2) for t in (.29,.73)]}

def add_building(b,mesh,grade,labels):
    bin_id=b.findtext(".//stringAttribute[@name='building_identification_number']/value")
    def rings(face):
        return [np.fromstring(r.text,sep=" ").reshape(-1,3)[:-1] for r in face.iter("posList")]
    foot=shapely.union_all([Polygon(rings(f)[0][:,:2]) for f in b.findall(".//GroundSurface//Polygon")])
    center=foot.centroid
    floor=float(b.findtext(".//lowerCorner").split()[2])
    shift=grade.height(center.x,center.y)+DATUM-floor
    bank=bin_id=="1015241"
    wall_caps=[]
    for kind in ("RoofSurface","WallSurface"):
        for poly in b.findall(".//"+kind+"//lod2MultiSurface//Polygon"):
            r=rings(poly)[0]
            if len(r)<3:continue
            if kind=="RoofSurface":
                flat=Polygon(r[:,:2])
                if flat.area<.1:continue
                coords,ids=model.triangulate(flat)
                normal=np.cross(r[1]-r[0],r[2]-r[0])
                if abs(normal[2])<1e-5:continue
                ht=r[0,2]-((coords-r[0,:2])@normal[:2])/normal[2]+shift
                mesh.face("Roof",np.column_stack((coords[:,0]-EAST,ht-DATUM,NORTH-coords[:,1])),ids)
                continue
            # Project the actual surveyed facet into its own elevation.
            a=r[0,:2]
            delta=r[:,:2]-a
            direction=delta[np.argmax(np.linalg.norm(delta,axis=1))]
            if np.linalg.norm(direction)<.02:continue
            direction=direction/np.linalg.norm(direction)
            if (np.array([direction[1],-direction[0]]) @ (a-[center.x,center.y]))<0:direction=-direction
            along=delta@direction
            start=a+along.min()*direction
            end=a+along.max()*direction
            f=model.Elevation(start-[EAST,NORTH],end-[EAST,NORTH],mesh)
            uv=Polygon(np.column_stack((along-along.min(),r[:,2]+shift)))
            if not uv.is_valid:uv=uv.buffer(0)
            if uv.is_empty or uv.area<.1:continue
            if bank:
                f.cut_stone(uv,"IndianaStone")
                if len(uv.bounds)==4 and f.length>15 and np.ptp(r[:,2])>6:
                    wall_caps.append((r[:,:2].mean(axis=0),r[:,2].max()+shift))
                continue
            if bin_id=="1015243" and f.out[0]>.8 and f.length>12 and np.ptp(r[:,2])>5:
                labels.append(notions_shop(f,uv,grade))
                continue
            lo,hi=r[:,2].min()+shift,r[:,2].max()+shift
            bays=max(1,round(f.length/2.9))
            windows=[]
            for z in np.arange(floor+shift+1,hi-1,3.45):
                for j in range(bays):
                    x=f.length*(j+.5)/bays
                    half=min(.83,f.length/bays*.32)
                    hole=box(x-half,z,x+half,z+1.84)
                    if not uv.contains(hole):continue
                    windows.append(hole)
                    f.reveal(x-half,x+half,z,z+1.84,0,-.19,"Reveal")
                    f.rect(x-half,x+half,z,z+1.84,-.19,["Window","CoolWindow","Window","WarmWindow"][(j+int(z))%4])
                    f.slab(x-half-.07,x+half+.07,z-.11,z+.02,.09,-.17,"IndianaStone")
            f.cut_stone(uv.difference(shapely.union_all(windows)),"BuffBrick" if bin_id=="1015242" else "IndianaStone")
    if bank:
        ring=np.array(orient(foot.simplify(.27),sign=1).exterior.coords)
        for a,b in zip(ring,ring[1:]):
            f=model.Elevation(a-[EAST,NORTH],b-[EAST,NORTH],mesh)
            if f.length<19:continue
            street="Broadway" if f.out[0]<-.8 else "36th" if f.out[1]<-.67 else "Sixth" if f.out[0]>.8 else ""
            if street:
                midpoint=(a+b)/2
                top=min(wall_caps,key=lambda hit:np.linalg.norm(hit[0]-midpoint))[1]
                classical(f,street,grade.height(*midpoint)+DATUM,top)

def main():
    grade=Grade(stage/"grade.json")
    mesh=model.Mesh()
    found=set()
    labels=[]
    for _,obj in ET.iterparse(CACHE/"Buildings.xml",events=("end",)):
        if obj.tag!="Building":continue
        bid=obj.findtext(".//stringAttribute[@name='building_identification_number']/value")
        if bid in bins:
            add_building(obj,mesh,grade,labels)
            found.add(bid)
        obj.clear()
    if found!=bins:raise ValueError("Missing surveyed buildings: "+str(bins-found))
    if len(labels)!=1: raise ValueError(f"Expected one Sixth Avenue shop, found {len(labels)}")
    import json
    (stage/"west36-labels.json").write_text(json.dumps(labels))
    mesh.save(stage/"West36.glb")
    if "--facades-only" not in sys.argv: surface.build(grade,stage/"midtown.glb",bins,NativeTile)

if __name__=="__main__": main()
