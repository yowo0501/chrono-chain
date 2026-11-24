"""Authored 8-way city: diagonal boulevards, broad landings, connected lamp districts."""
from pathlib import Path
from collections import deque
import json, math
ROOT=Path(__file__).resolve().parents[1]
W,H=128,64
grid=[['#']*W for _ in range(H)]
zones=[
 ('분수 광장',25,43,11,8,'plaza'),('빵집 앞 거리',18,26,9,6,'bakery'),
 ('상점 거리',49,43,10,6,'market'),('수로 산책길',50,56,10,4,'quay'),
 ('시계 회랑',48,25,10,7,'arcade'),('서쪽 뒷골목',10,10,7,6,'alley'),
 ('빵집 뒤 골목',32,12,8,5,'alley'),('북쪽 뒷골목',60,10,8,5,'alley'),
 ('동쪽 굽은 골목',80,23,8,7,'alley'),('버려진 공터',103,12,11,7,'lot'),
 ('창고 뒷길',115,32,8,7,'warehouse'),('화물 적재장',107,53,11,6,'yard'),
 ('강변 거리',79,55,10,5,'quay'),('돌다리 교차로',76,41,9,7,'bridge'),
 ('옛 공방 거리',97,38,8,6,'workshop'),('남문 진입로',20,57,9,3,'gate')]
def carve(x,y):
 if 1<x<W-2 and 1<y<H-2: grid[y][x]='.'
def disk(cx,cy,r):
 for y in range(math.floor(cy-r),math.ceil(cy+r)+1):
  for x in range(math.floor(cx-r),math.ceil(cx+r)+1):
   if (x-cx)**2+(y-cy)**2 <= r*r: carve(x,y)
for _,cx,cy,rx,ry,kind in zones:
 for y in range(cy-ry,cy+ry+1):
  for x in range(cx-rx,cx+rx+1):
   if ((x-cx)/rx)**2+((y-cy)/ry)**2 < 1.14: carve(x,y)
links=[(0,1,2.6),(0,4,3),(0,2,3),(0,15,3),(15,3,2.5),(2,3,3),
 (1,4,2.7),(1,5,2),(1,6,2),(5,6,2),(6,4,2.3),(6,7,2),
 (4,7,2.5),(4,8,2.6),(7,8,2),(7,9,2.3),(8,9,2.5),
 (9,10,2.5),(8,10,2),(8,13,2.5),(4,13,2.8),(2,13,3),
 (13,14,2.5),(14,10,2.5),(14,11,2.5),(10,11,2.5),
 (13,12,2.7),(12,11,2.7),(3,12,2.5),(2,12,2.4)]
routes=[]
for a,b,r in links:
 ax,ay=zones[a][1:3]; bx,by=zones[b][1:3]
 steps=math.ceil(math.hypot(bx-ax,by-ay)*2)
 for step in range(steps+1):
  t=step/steps; disk(ax+(bx-ax)*t,ay+(by-ay)*t,r)
 routes.append({'from':a,'to':b,'width':round(r*2,1)})
decor=[]
def prop(kind,x,y,w,h):
 decor.append(dict(kind=kind,x=x,y=y,w=w,h=h))
 for yy in range(y,y+h):
  for xx in range(x,x+w):grid[yy][xx]='#'
# All landmarks sit off the broad diagonal corridors.
prop('fountain',20,38,4,3)
for args in [('bakery',9,20,6,4),('shop',40,36,6,4),('shop',51,35,6,4),
 ('arch',42,17,5,4),('warehouse',109,23,7,5),('warehouse',110,43,7,4),
 ('house',3,3,4,4),('house',24,5,5,3),('warehouse',95,4,6,4),
 ('house',87,30,5,4),('shop',96,30,5,4),('arch',12,54,4,3),
 ('crate',105,50,2,2),('bench',28,39,2,1),('bench',18,47,2,1)]:prop(*args)
# Infill is restricted to already-solid ground; it cannot block a route.
occupied={(x,y) for d in decor for y in range(d['y']-1,d['y']+d['h']+1) for x in range(d['x']-1,d['x']+d['w']+1)}
for y in range(3,H-9):
 for x in range(3,W-10):
  w=4+(x+y)%3;h=4
  cells={(xx,yy) for yy in range(y,y+h) for xx in range(x,x+w)}
  if cells&occupied or any(grid[yy][xx]!='#' for xx,yy in cells):continue
  if sum(grid[y+h][xx]=='.' for xx in range(x,x+w)) < w-1:continue
  prop('warehouse' if x>90 else 'shop' if 35<x<65 else 'house',x,y,w,h)
  occupied.update((xx,yy) for yy in range(y-1,y+h+1) for xx in range(x-1,x+w+1))
for y in (61,62):
 for x in range(34,96):grid[y][x]='W'
lamps=[(z[1],z[2]) for z in zones]
for x,y in lamps:
 assert grid[y][x]=='.',(x,y)
 grid[y][x]='L'
# Connectivity includes the same corner rule as gameplay.
offsets=[(0,-1),(-1,0),(1,0),(0,1),(-1,-1),(1,-1),(-1,1),(1,1)]
def neighbors(x,y):
 for dx,dy in offsets:
  nx,ny=x+dx,y+dy
  if not(0<=nx<W and 0<=ny<H) or grid[ny][nx] not in '.L':continue
  if dx and dy and (grid[y][nx] not in '.L' or grid[ny][x] not in '.L'):continue
  yield nx,ny
seen={(25,45)};q=deque(seen)
while q:
 for p in neighbors(*q.popleft()):
  if p not in seen:seen.add(p);q.append(p)
# Tiny isolated paving left by frontages is solidified before ownership is assigned.
for y in range(H):
 for x in range(W):
  if grid[y][x]=='.' and (x,y) not in seen:grid[y][x]='#'
assert all(p in seen for p in lamps)
owner=[[-1]*W for _ in range(H)];q=deque()
for i,(x,y) in enumerate(lamps):owner[y][x]=i;q.append((x,y))
while q:
 x,y=q.popleft()
 for nx,ny in neighbors(x,y):
  if owner[ny][nx]<0:owner[ny][nx]=owner[y][x];q.append((nx,ny))
for y in range(H):
 for x in range(W):
  if owner[y][x]<0:owner[y][x]=min(range(16),key=lambda i:(x-lamps[i][0])**2+(y-lamps[i][1])**2)
for d in decor:
 area=owner[d['y']+d['h']][d['x']+d['w']//2]
 for y in range(d['y'],d['y']+d['h']):
  for x in range(d['x'],d['x']+d['w']):owner[y][x]=area
areas=[]
for i,(name,cx,cy,rx,ry,kind) in enumerate(zones):
 cells=[(x,y) for y in range(H) for x in range(W) if grid[y][x]=='.' and owner[y][x]==i]
 spawn=min(cells,key=lambda p:abs(p[0]-cx-3)+abs(p[1]-cy-2))
 areas.append(dict(name=name,kind=kind,lamp=[cx,cy],spawn=list(spawn)))
data=dict(name='밤의 도시 · 두 사람의 길',layout_version='duo-eight-way-1',
 tiles=[''.join(r) for r in grid],area_tiles=[''.join('0123456789ABCDEF'[a] for a in r) for r in owner],
 areas=areas,decor=decor,routes=routes,start=[25,45],boss_tile=[25,42],initial_dark_areas=[5,6,7,8],
 enemy_spawns=[areas[i]['spawn'] for i in (5,7,10)],enemy_step_seconds=.36,enemy_idle_seconds=.25,
 dark_spawn_seconds=45,max_active_symbols=9,lamp_break_seconds=9,lamp_break_enabled=False,
 light_hp_multiplier=1,light_attack_multiplier=1,dark_hp_multiplier=1.05,dark_attack_multiplier=1.05,
 boss_hp=520,boss_attack=19,boss_reduction_per_dark_lamp=0,map_scale=1,
 dark_encounter=dict(safe_steps=3,chance_per_step=.14,maximum_steps=14))
(ROOT/'data/field_map.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(f'DUO CITY: {W}x{H}, {len(links)} routes, {len(seen)} connected cells, 16 lamps, 3 initial enemies')
