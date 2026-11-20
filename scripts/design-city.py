"""Bake the street graph, waterfronts and street-facing parcels in metres.
The same graph drives pavement, traffic, pursuit, map and mission navigation.
No external GIS service or assets are needed to reproduce the city.
"""
from pathlib import Path
from math import sin, cos, pi, hypot
import random, json

rng = random.Random(1907)
nodes, roads, parcels, land, parks, walks, marks = [], [], [], [], [], [], {}
node_ids, special, street_names = {}, {}, []
def node(x,z,y=2.6):
    key = tuple(round(n,2) for n in (x,y,z))
    if key not in node_ids:
        node_ids[key]=len(nodes)
        nodes.append(key)
    return node_ids[key]
def road(a,b,name,width=13,kind="street"):
    if a!=b:
        roads.append([a,b,width,name,kind])
def island(name,polygon,surface):
    land.append([name,polygon,surface])
def landmark(name,p):
    marks[name]=p
def lot(x,z,w,d,floors,style,face=1,title="",tier=""):
    if min(w,d)<9: return
    i=len(parcels)
    parcels.append(dict(x=round(x,2),z=round(z,2),w=round(w,2),d=round(d,2),floors=floors,
                        style=style,face=face,title=title,tier=tier,seed=rng.randrange(100000)))
    if title:
        special[title]=i
        landmark(title,[x,2.65,z+face*(d/2+1.1)])
def chain(coords,name,width=13,kind="street"):
    ids=[node(*p) for p in coords]
    for a,b in zip(ids,ids[1:]): road(a,b,name,width,kind)
    return ids
def quad_strip(name, rows, colors, region, xnames):
    # Each row contains physical intersections. Blocks are inscribed between
    # the extreme embankments of both cross-streets, including angled streets.
    count=len(rows[0])
    for r,row in enumerate(rows):
        for c,(x,z) in enumerate(row):
            if c+1<count and not (region=="Manhattan" and 24<r<31 and c in (1,2)):
                road(node(x,z),node(*row[c+1]),name(r),14)
            if r+1<len(rows) and not (region=="Manhattan" and 24<=r<31 and c==2):
                road(node(x,z),node(*rows[r+1][c]),xnames[c],18 if c in (1,3) else 14)
    for r,(south,north) in enumerate(zip(rows,rows[1:])):
        for c in range(count-1):
            if region=="Manhattan" and 24<=r<31 and c in (1,2):continue
            if region=="Manhattan" and (r,c) in [(18,2),(19,2),(5,2)]: continue
            lo=max(south[c][0],north[c][0])+12
            hi=min(south[c+1][0],north[c+1][0])-12
            south_z=min(south[c][1],south[c+1][1])-10
            north_z=max(north[c][1],north[c+1][1])+10
            if hi-lo<13 or south_z-north_z<20:continue
            for row_index,face in enumerate([1,-1]):
                available=south_z-north_z
                depth=min(available*.45,46 if region=="Manhattan" else 34)
                z=south_z-depth/2 if face==1 else north_z+depth/2
                n=max(1,round((hi-lo)/45))
                for j in range(n):
                    width=(hi-lo)/n-2.8
                    x=lo+(j+.5)*(hi-lo)/n
                    style=rng.choice(colors)
                    floors=rng.randint(2,7)
                    title=tier=""
                    if region=="Manhattan":
                        floors=rng.randint(9,29) if r<5 or 14<=r<=22 else rng.randint(4,13)
                        if c in (1,2,3) and (r<4 or 14<=r<=22):
                            floors+=rng.randrange(6,17)
                        if (r,c,row_index,j)==(15,1,0,0):
                            title,tier,floors,style="Empire State Building","empire",86,"deco"
                        elif (r,c,row_index,j)==(1,0,0,0):
                            title,tier,floors="One World Trade Center","needle",95
                        elif (r,c,row_index,j)==(1,4,0,0):title,style,floors="Battery House Hotel","hotel",6
                        elif (r,c,row_index,j)==(6,1,0,0):title,style="Voss Development","office"
                        elif (r,c,row_index,j)==(7,2,0,0):title,style="Public Archive","archive"
                        elif (r,c,row_index,j)==(19,1,1,0):title,style="Oriole Theatre","theatre"
                        elif (r,c,row_index,j)==(25,0,0,0):title,style="Linden House","apartments"
                    lot(x,z,width,depth,floors,style,face,title,tier)

# Local geography follows the east bank of the East River, with the older
# waterfront grid physically continuous with the preserved Breakwater hotel.
xs=[-135,-75,-15,55,125]
zs=[125,65,-5,-65,-125]
for z in zs:
    chain([(x,z) for x in xs],"Water Street" if z==65 else "Old Harbor",13)
for x in xs:
    chain([(x,z) for z in zs],"Dock Street",13)
for z in (96,28,-35,-95):
    for x in (-105,-45,20,91):
        if (x,z) in [(-45,28),(20,96)]:continue
        named={(-45,96):("Copper Kettle","coffee"),(91,96):("Southbank Garage","garage"),
               (-105,-35):("Dockworkers Hall","union"),(91,-95):("Harrow House","apartments")}
        title,style=named.get((x,z),("",rng.choice(["apartments","stores","coffee","warehouse"])))
        lot(x,z,36 if x>0 else 35,31,rng.randint(2,5),style,1,title)

# Manhattan cross streets and a Broadway diagonal. Its crossings make two
# triangular plazas; park transverse roads remain around the park perimeter.
mrows=[]
for r in range(38):
    z=185-120*r
    if r==1:z=65
    center=-1200+max(0,r-5)*10
    half=235+min(r,4)*35- max(0,r-32)*24
    row=[]
    for c in range(6):
        x=center+half*(c/2.5-1)
        bend=sin(r*.75+c*.7)*21 if r<8 else 0
        row.append((round(x+bend,1),z))
    mrows.append(row)
quad_strip(lambda r:("Canal Street" if r==6 else "Houston Street" if r==8 else f"{max(1,(r-8)*3+10)} Street"),
           mrows,["deco","office","apartments","bookshop","theatre","archive"],"Manhattan",
           ["West Street","Eighth Avenue","Seventh Avenue","Fifth Avenue","Park Avenue","FDR Drive"])
east=[(r[-1][0]+30,r[-1][1]) for r in mrows]
west=[(r[0][0]-35,r[0][1]) for r in mrows]
island("Manhattan",west+[(west[-1][0]+80,west[-1][1]-145),(east[-1][0]-40,east[-1][1]-165)]+east[::-1]+[(-1130,300),(-1280,333)],"city")
chain([mrows[18][2],mrows[19][3],mrows[20][3]],"Broadway",17)
chain([mrows[5][2],mrows[6][3]],"Park Row",14)
for row,col,title in [(19,2,"Times Square"),(1,4,"Lower Manhattan"),(37,2,"Uptown"),(14,3,"Midtown")]:
    x,z=mrows[row][col]
    landmark(title,[x,2.65,z])
px=(mrows[27][1][0]+mrows[27][3][0])/2
parks.append(["Central Park",[[mrows[24][1][0]+11,mrows[24][1][1]-10],[mrows[24][3][0]-11,mrows[24][3][1]-10],
                 [mrows[31][3][0]-11,mrows[31][3][1]+10],[mrows[31][1][0]+11,mrows[31][1][1]+10]]])
landmark("Central Park",[px,2.65,mrows[27][1][1]])
walks.append([[px-54+r*6+sin(r)*33,mrows[24][1][1]-r*118] for r in range(8)])
walks.append([[px-115,mrows[27][1][1]+32],[px,mrows[27][1][1]],[px+123,mrows[27][1][1]-29]])

# Brooklyn and Queens curve along the shore, with canals, piers and a rail yard.
brows=[]
for r in range(23):
    z=-125-r*102
    edge=-135+max(0,r-2)*28
    row=[(edge+c*(65+min(5,r)*12),z) for c in range(6)]
    if r==0:row=[(x,-125) for x in [-135,-75,-15,55,125,220]]
    brows.append(row)
quad_strip(lambda r:"Flushing Avenue" if r==6 else "Vernon Boulevard" if r>13 else "Kent Avenue",
           brows,["warehouse","apartments","stores","coffee","studio"],"Brooklyn",
           ["Waterfront Drive","Kent Avenue","Wythe Avenue","Bedford Avenue","Union Avenue","Atlantic Avenue"])
# Outer Queens extends the end-to-end route to about five road miles.
qrows=[]
for r in range(10):
    z=brows[-1][0][1]-r*139
    edge=brows[-1][0][0]+r*38
    qrows.append([(edge+c*125,z) for c in range(6)])
quad_strip(lambda r:"Queens Boulevard",qrows,["apartments","stores","garage","bookshop"],"Queens",
           ["Shore Road","Jackson Avenue","Northern Boulevard","Steinway Street","Broadway East","Ditmars Boulevard"])
landmark("Astoria",[*[qrows[-1][-1][0]],2.65,qrows[-1][-1][1]])
coast=[(-175,140),(-266,135),(-275,-25),(-175,-69),(-175,-175)]+[(r[0][0]-45,r[0][1]) for r in brows[1:]+qrows[1:]]
inland=[(r[-1][0]+43,r[-1][1]) for r in brows+qrows[1:]]
island("Brooklyn and Queens",coast+[(coast[-1][0]+75,coast[-1][1]-100),(inland[-1][0]-50,inland[-1][1]-115)]+inland[::-1]+[(278,50),(226,128),(170,139)],"city")
# Bridge approaches meet the street at grade. Piers and ramps have distinct elevations.
ma=mrows[1][-1]
bridge=chain([(-135,65),(-175,65),(-235,65,8.3),(-315,65,13),(-398,65,19),
              (-558,65,19),(-690,65,19),(-776,65,14),(-849,65,7.3),(ma[0],65)],"Brooklyn Bridge",16,"bridge")
chain([(-135,125),(-249,118),(-249,7),(-135,-5)],"Ferry Road",12)
landmark("Brooklyn Bridge",[-537,19,65])
# Second crossing links the same two boroughs farther north, allowing real alternate routes.
a=mrows[13][-1]; b=brows[13][0]
chain([a,(a[0]+85,a[1]-4,7),(a[0]+195,a[1]-10,18),((a[0]+b[0])/2,(a[1]+b[1])/2,24),
       (b[0]-175,b[1]+9,17),(b[0]-65,b[1]+3,6),b],"Williamsburg Bridge",15,"bridge")
landmark("Pier 04",[4,1.9,171])
landmark("Breakwater Hotel",[-45,2.65,40])
# A service dock opens onto an exterior yard; walls isolate secure areas.
island("Blackwater",[(-550,690),(-515,627),(-355,609),(-290,658),(-280,828),(-335,898),(-504,890),(-561,832)],"stone")
landmark("Blackwater Service Dock",[-410,1.7,596])
for x,z,w,d,style,title in [(-477,681,38,38,"office","Blackwater Administration"),(-350,683,39,43,"infirmary","Prison Infirmary"),
                            (-471,787,43,61,"cells","Cellblock A"),(-357,789,44,62,"cells","Cellblock B"),
                            (-416,851,48,27,"stores","Prison Workshops")]:
    lot(x,z,w,d,2,style,-1,title)
landmark("Custody gate",[-412,2.65,660])
landmark("Substation",[-448,2.65,650])
landmark("Cell control",[-358,2.65,782])
island("Fort Halcyon",[(470,260),(657,220),(937,204),(1255,255),(1290,342),(1190,482),(725,514),(490,439)],"stone")
chain([(125,125),(220,125),(272,142,5),(365,184,12),(457,227,7),(537,266),(607,290)],"Navy Causeway",12,"bridge")
landmark("Fort Halcyon",[660,2.65,315])
landmark("Fort radar",[701,2.65,304])
lot(647,350,36,33,2,"office",1,"Fort Command")
lot(745,342,62,49,1,"garage",1,"Naval Air Station")
landmark("Airstrip",[1035,2.65,400])
landmark("Marina landing",[97,2.65,124])
landmark("Forest meeting",[px+50,2.65,mrows[27][1][1]+22])
landmark("Drydock Six",[124,2.65,73])
# Columbus Circle distributes the traffic before it reaches the park edge.
cx,cz=mrows[24][1]
hub=node(cx,cz)
spokes=[e for e in roads if e[0]==hub or e[1]==hub]
ring=[node(cx+14*cos(i*pi/8),cz+14*sin(i*pi/8)) for i in range(16)]
for i in range(16):road(ring[i],ring[(i+1)%16],"Columbus Circle",7)
for e in spokes:
    side=0 if e[0]==hub else 1
    other=nodes[e[1-side]]
    e[side]=min(ring,key=lambda i:hypot(nodes[i][0]-other[0],nodes[i][2]-other[2]))
# Compact the unused former hub so closest-point queries cannot pick an island.
for e in roads:
    for k in (0,1):
        if e[k]>hub:e[k]-=1
bridge=[i-(i>hub) for i in bridge]
nodes.pop(hub)
landmark("Columbus Circle",[cx,2.65,cz])
# Every adjacency uses shared junction IDs. Data is the source of truth.
out=dict(nodes=nodes,roads=roads,parcels=parcels,land=land,parks=parks,walks=walks,marks=marks,special=special,bridge=bridge)
path=Path(__file__).resolve().parents[1]/"godot-prototype/bay/data/new_york.json"
path.write_text(json.dumps(out,separators=(",",":"))+"\n")
print(f"{len(parcels)} parcels, {len(roads)} road links, {len(nodes)} junctions")

# Bake a single north-up cartographic texture. Both map views use the same
# geographic rectangle, so setting a waypoint is the inverse of drawing it.
bounds = (-1850, -4540, 3740, 5580)
svg = ['<svg xmlns="http://www.w3.org/2000/svg" width="1870" height="2790" viewBox="-1850 -4540 3740 5580">',
       '<rect x="-1850" y="-4540" width="3740" height="5580" fill="#294858"/>']
def polygon_svg(points, fill):
    coords = " ".join(f"{x},{z}" for x,z in points)
    return f'<polygon points="{coords}" fill="{fill}"/>'
for _, poly, surface in land:
    svg.append(polygon_svg(poly, "#9d9c86" if surface == "stone" else "#bdbaa3"))
for _, poly in parks:
    svg.append(polygon_svg(poly, "#708772"))
for p in parcels:
    svg.append(f'<rect x="{p["x"]-p["w"]/2:.1f}" y="{p["z"]-p["d"]/2:.1f}" width="{p["w"]}" height="{p["d"]}" fill="#96998c"/>')
for a,b,width,_,kind in roads:
    ax,_,az = nodes[a]
    bx,_,bz = nodes[b]
    color = "#deb77c" if kind == "bridge" else "#ede7d4"
    svg.append(f'<path d="M {ax} {az} L {bx} {bz}" stroke="{color}" stroke-width="{width*.69:.1f}" fill="none"/>')
svg.append('</svg>')
path.with_name("street_atlas.svg").write_text("\n".join(svg)+"\n")
