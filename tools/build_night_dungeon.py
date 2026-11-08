"""Deterministic authored 128x64 city; geodesic lamp districts follow streets."""
import json
from collections import deque
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
W, H = 128, 64
grid = [["#"] * W for _ in range(H)]
zones = [
    ("분수 광장", 21, 43, 13, 9, "plaza", True),
    ("빵집 앞 거리", 18, 23, 14, 7, "bakery", True),
    ("상점 거리", 49, 40, 15, 7, "market", True),
    ("수로 산책길", 51, 56, 18, 4, "quay", True),
    ("시계 회랑", 51, 20, 12, 6, "arcade", True),
    ("서쪽 뒷골목", 8, 8, 5, 5, "alley", False),
    ("빵집 뒤 골목", 31, 8, 9, 4, "alley", False),
    ("북쪽 뒷골목", 65, 8, 10, 4, "alley", False),
    ("동쪽 굽은 골목", 82, 25, 7, 10, "alley", False),
    ("버려진 공터", 105, 12, 15, 8, "lot", False),
    ("창고 뒷길", 115, 33, 9, 9, "warehouse", False),
    ("화물 적재장", 107, 54, 15, 6, "yard", False),
    ("강변 거리", 77, 54, 10, 5, "quay", True),
    ("돌다리 교차로", 76, 39, 9, 7, "bridge", True),
    ("옛 공방 거리", 96, 39, 8, 7, "workshop", False),
    ("남문 진입로", 19, 57, 12, 3, "gate", True),
]

def carve(x, y):
    if 1 < x < W-2 and 1 < y < H-2:
        grid[y][x] = "."

def rect(x, y, w, h):
    for yy in range(y, y+h):
        for xx in range(x, x+w):
            carve(xx, yy)

def route(points, radius):
    for (ax, ay), (bx, by) in zip(points, points[1:]):
        assert ax == bx or ay == by
        for y in range(min(ay,by)-radius, max(ay,by)+radius+1):
            for x in range(min(ax,bx)-radius, max(ax,bx)+radius+1):
                carve(x,y)

for i, (_,cx,cy,rx,ry,kind,_) in enumerate(zones):
    for y in range(cy-ry,cy+ry+1):
        for x in range(cx-rx,cx+rx+1):
            # Plaza is octagonal, lot oval, streets asymmetric L / stepped rooms.
            if kind == "plaza" and abs(x-cx)+abs(y-cy) > rx+ry-5:
                continue
            if kind == "lot" and ((x-cx)/rx)**2+((y-cy)/ry)**2 > 1.05:
                continue
            if kind in ("alley","workshop") and x > cx+2 and y < cy-2:
                continue
            carve(x,y)

# Different widths and bends, loops and cross-links rather than a repeated grid.
for points,radius in [
    ([(21,43),(21,23)],3), ([(21,43),(49,43),(49,40)],3),
    ([(21,43),(19,43),(19,57)],3), ([(19,57),(51,57)],2),
    ([(51,56),(51,40)],2), ([(51,56),(77,56)],2),
    ([(49,40),(76,40)],3), ([(49,40),(49,20)],2),
    ([(18,23),(51,23),(51,20)],2),
    ([(8,8),(8,17),(18,17),(18,23)],1),
    ([(8,8),(31,8)],1), ([(31,8),(31,15),(27,15),(27,23)],1),
    ([(31,8),(41,8),(41,20)],1),
    ([(51,20),(60,20),(60,8),(65,8)],2),
    ([(65,8),(82,8),(82,25)],1), ([(82,8),(105,8),(105,12)],2),
    ([(51,20),(69,20),(69,25),(82,25)],1),
    ([(82,25),(76,25),(76,39)],2),
    ([(76,39),(96,39),(115,39),(115,33)],2),
    ([(105,12),(117,12),(117,33)],2),
    ([(82,25),(99,25),(99,33),(115,33)],1),
    ([(77,54),(77,39)],2), ([(77,54),(107,54)],2),
    ([(96,39),(96,48),(107,48),(107,54)],1),
    ([(115,33),(120,33),(120,54),(107,54)],2),
]:
    route(points,radius)

decor = []
def prop(kind,x,y,w,h):
    assert x > 1 and y > 1 and x+w < W-1 and y+h < H-1
    decor.append(dict(kind=kind,x=x,y=y,w=w,h=h))
    for yy in range(y,y+h):
        for xx in range(x,x+w):
            grid[yy][xx] = "#"

# Individually placed frontages and landmarks; no flowerbeds.
for args in [
    ("fountain",16,38,5,4),
    ("bakery",10,17,6,5), ("house",23,17,6,5),
    ("shop",37,34,6,5), ("shop",47,33,7,5), ("shop",56,34,6,5),
    ("house",10,34,5,4), ("house",26,34,6,5),
    ("house",6,48,6,5), ("shop",27,48,6,4),
    ("arch",45,14,5,4), ("house",55,14,5,4),
    ("house",3,3,5,3), ("house",24,4,5,3),
    ("warehouse",56,3,6,4), ("warehouse",108,25,7,5),
    ("warehouse",115,44,7,5), ("warehouse",108,48,6,4),
    ("house",88,33,6,5), ("shop",98,33,5,4),
    ("house",69,47,5,4), ("house",82,48,5,4),
    ("arch",11,54,4,3),
    ("crate",96,9,2,2), ("crate",109,15,2,2),
    ("crate",101,18,2,2), ("crate",113,51,2,2),
    ("crate",103,57,2,2), ("crate",83,30,2,2),
    ("bench",24,40,2,1), ("bench",15,46,2,1),
    ("bench",44,57,2,1), ("bench",74,57,2,1),
]:
    prop(*args)

# Street-facing infill: occupy only already-solid ground, preserving every route.
occupied_props={(x,y) for d in decor for y in range(d["y"],d["y"]+d["h"]) for x in range(d["x"],d["x"]+d["w"])}
for y in range(3,54):
    for x in range(3,120):
        w=4+(x+y)%3
        h=4+(x*3+y)%2
        cells=[(xx,yy) for yy in range(y,y+h) for xx in range(x,x+w)]
        if any(grid[yy][xx]!="#" or (xx,yy) in occupied_props for xx,yy in cells):
            continue
        if sum(grid[y+h][xx]=="." for xx in range(x,x+w)) < w-1:
            continue
        kind="warehouse" if x>90 else "shop" if 34<x<66 else "house"
        prop(kind,x,y,w,h)
        occupied_props.update((xx,yy) for yy in range(y-1,y+h+1) for xx in range(x-1,x+w+1))

# River alongside the southern promenade; the walkable bank stays continuous.
for y in [61,62]:
    for x in range(34,94):
        grid[y][x]="W"

lamps = [(cx,cy) for _,cx,cy,*_ in zones]
for x,y in lamps:
    assert grid[y][x] == ".", (x,y)
    grid[y][x] = "L"

# Multi-source flood along actual walkable routes creates connected irregular areas.
owner = [[-1]*W for _ in range(H)]
q = deque()
for i,(x,y) in enumerate(lamps):
    owner[y][x]=i
    q.append((x,y))
while q:
    x,y=q.popleft()
    for nx,ny in [(x-1,y),(x+1,y),(x,y-1),(x,y+1)]:
        if 0<=nx<W and 0<=ny<H and grid[ny][nx] in (".","L") and owner[ny][nx]<0:
            owner[ny][nx]=owner[y][x]
            q.append((nx,ny))
for y in range(H):
    for x in range(W):
        assert grid[y][x] in ("#","W") or owner[y][x]>=0, (x,y)
        if owner[y][x]<0:
            owner[y][x]=min(range(len(zones)),key=lambda i:(x-lamps[i][0])**2+(y-lamps[i][1])**2)

# A facade belongs to the street at its entrance, avoiding half-dark buildings.
for item in decor:
    area=owner[item["y"]+item["h"]][item["x"]+item["w"]//2]
    for y in range(item["y"],item["y"]+item["h"]):
        for x in range(item["x"],item["x"]+item["w"]):
            owner[y][x]=area

areas=[]
for i,(name,cx,cy,rx,ry,kind,lit) in enumerate(zones):
    candidates=[(x,y) for y in range(H) for x in range(W)
                if grid[y][x]=="." and owner[y][x]==i]
    spawn=min(candidates,key=lambda p:abs(p[0]-cx-3)+abs(p[1]-cy-2))
    areas.append(dict(name=name,kind=kind,lamp=[cx,cy],spawn=list(spawn)))
data=dict(
    name="밤의 도시",tiles=["".join(row) for row in grid],
    area_tiles=["".join("0123456789ABCDEF"[a] for a in row) for row in owner],
    areas=areas,decor=decor,start=[21,44],boss_tile=[21,43-1],
    initial_dark_areas=[5,6,7,8],  # Prototype: only four lamps need relighting.
    enemy_spawns=[areas[i]["spawn"] for i in [5,6,7,9,10]],
    enemy_step_seconds=.30,enemy_idle_seconds=.10,
    dark_spawn_seconds=35.0,max_active_symbols=12,lamp_break_seconds=9.0,
    light_hp_multiplier=1.0,light_attack_multiplier=1.0,
    dark_hp_multiplier=1.05,dark_attack_multiplier=1.05,
    boss_hp=900,boss_attack=28,boss_reduction_per_dark_lamp=0,
    map_scale=1,dark_encounter=dict(safe_steps=2,chance_per_step=.18,maximum_steps=12))
(ROOT/"data/field_map.json").write_text(json.dumps(data,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
print(f"{W}x{H}; {len(areas)} irregular districts; {sum(r.count('.') for r in grid)} walkable tiles")
