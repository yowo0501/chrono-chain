"""Pack ImageGen animation art with stable foot anchors and chain attachment metadata.

Only atlas extraction, alpha cleanup, nearest sampling and alignment happen here.
Character poses are drawn in the preserved generated source sheets.
"""
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1] / 'assets/sprites/battle'
CELL = (384, 240)
ANCHOR = (128, 232)

def extract(source, regions, anchor, scale):
    bounds = (min(r[0] for r in regions), min(r[1] for r in regions),
              max(r[2] for r in regions), max(r[3] for r in regions))
    crop = Image.new('RGBA', (bounds[2]-bounds[0], bounds[3]-bounds[1]))
    for r in regions:
        crop.paste(source.crop(r), (r[0]-bounds[0], r[1]-bounds[1]))
    crop.putalpha(crop.getchannel('A').point(lambda a: 255 if a >= 128 else 0))
    crop = crop.resize((round(crop.width*scale), round(crop.height*scale)), Image.Resampling.NEAREST)
    cell = Image.new('RGBA', CELL)
    cell.paste(crop, (ANCHOR[0]+round((bounds[0]-anchor[0])*scale),
                      ANCHOR[1]+round((bounds[1]-anchor[1])*scale)))
    return cell

def pack(name, suffix, poses):
    source = Image.open(ROOT / f'{name}-{suffix}-source.png').convert('RGBA')
    sheet = Image.new('RGBA', (CELL[0]*4, CELL[1]*4))
    cells = []
    for i, (regions, anchor, scale) in enumerate(poses):
        cell = extract(source, regions, anchor, scale)
        cells.append(cell)
        sheet.paste(cell, ((i%4)*CELL[0], (i//4)*CELL[1]))
    return sheet, cells

def grid_poses(rows, xs, feet, scales):
    poses = []
    for row in range(4):
        for col in range(4):
            x0, x1 = [0, 314, 628, 942, 1254][col:col+2]
            poses.append(([(x0, rows[row], x1, rows[row+1])],
                          (xs[row][col], feet[row]), scales[row]))
    return poses

motions = {
    'chuheun': grid_poses([0,320,635,946,1254],
        [[153,481,791,1110]]*2 + [[162,480,794,1105]]*2,
        [305,620,932,1244], [.55,.55,.60,.60]),
    'yeonwoo': grid_poses([0,340,670,960,1254],
        [[153,467,787,1111]]*2 + [[168,488,793,1092]]*2,
        [329,657,952,1238], [.50,.50,.57,.57]),
}
expressive = {
    'chuheun': [
        ([(27,0,340,332)],(177,323),.56),
        ([(342,0,636,332)],(485,323),.56),
        ([(634,0,940,332)],(774,323),.56),
        ([(941,0,1254,332)],(1076,323),.56),
        ([(9,335,354,632)],(163,625),.56),
        ([(357,335,637,632)],(488,625),.56),
        ([(647,335,938,632)],(795,625),.56),
        ([(969,335,1254,632)],(1106,625),.56),
        ([(74,636,286,954)],(180,950),.53),
        ([(363,640,607,954)],(480,950),.53),
        ([(656,633,906,954)],(789,950),.53),
        ([(1028,610,1165,639),(976,639,1234,954)],(1103,950),.53),
        ([(44,954,295,1254)],(170,1244),.53),
        ([(350,960,609,1254)],(479,1244),.53),
        ([(664,960,919,1254)],(791,1244),.53),
        ([(980,960,1235,1254)],(1112,1244),.53),
    ],
    'yeonwoo': [
        ([(31,0,326,327)],(194,316),.53),
        ([(352,0,631,327)],(498,316),.53),
        ([(642,0,936,327)],(801,316),.53),
        ([(944,0,1254,327)],(1108,316),.53),
        ([(22,328,356,629)],(200,620),.53),
        ([(363,328,643,629)],(505,620),.53),
        ([(676,328,954,629)],(824,620),.53),
        ([(964,328,1254,629)],(1121,620),.53),
        ([(42,632,295,940)],(180,934),.52),
        ([(358,632,618,940)],(501,934),.52),
        ([(684,632,924,940)],(810,934),.52),
        ([(972,632,1242,940)],(1120,934),.52),
        ([(43,941,313,1254)],(190,1237),.52),
        ([(355,941,629,1254)],(501,1237),.52),
        ([(684,941,937,1254)],(813,1237),.52),
        ([(984,941,1254,1254)],(1128,1237),.52),
    ],
}
tips = {'chuheun': {2:(928,149), 4:(344,454), 5:(618,444)},
        'yeonwoo': {2:(925,108), 4:(346,412), 5:(610,498)}}
metadata = {}
for name in motions:
    sheet, _ = pack(name, 'motion', motions[name])
    sheet.save(ROOT / f'{name}-motion.png')
    sheet, cells = pack(name, 'expressive', expressive[name])
    # Preserve the user's approved impact drawing exactly, including its chain.
    old = Image.open(ROOT / f'{name}-action.png').convert('RGBA')
    impact = Image.new('RGBA', CELL)
    impact.paste(old.crop((384,224,768,448)), (0,16))
    sheet.paste(impact, (3*CELL[0],0))
    sheet.save(ROOT / f'{name}-expressive.png')
    joins = {}
    for frame, (x,y) in tips[name].items():
        _, (ax,ay), scale = expressive[name][frame]
        joins[str(frame)] = [round((x-ax)*scale), round((y-ay)*scale)]
    joins['3'] = [139,-98] if name == 'chuheun' else [180,-120]
    metadata[name] = joins
    print(name, '16 motion + 16 expressive frames', joins)

# Extract an actual linked steel segment from the approved impact artwork.
# Two alternating links tile by overlap, so link thickness never stretches.
source = Image.open(ROOT / 'chuheun-action-source.png').convert('RGBA')
chain = source.crop((936,706,1000,730))
chain.putalpha(chain.getchannel('A').point(lambda a: 255 if a>=128 else 0))
chain = chain.resize((26,10), Image.Resampling.NEAREST)
chain.save(ROOT / 'chain-extension.png')
(ROOT / 'chain-joins.json').write_text(json.dumps(metadata, indent=2), encoding='utf-8')
