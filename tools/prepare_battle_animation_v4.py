"""Extract the calm idle atlas and fixed-body wrist rig from ImageGen artwork.

This only packs supplied artwork and separates the wrist at its cuff for the
game's small pivot animation. It does not synthesize replacement character art.
"""
from pathlib import Path
import json
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1] / 'assets/sprites/battle'
CELL = (384, 240)
ANCHOR = (128, 232)

def aligned(source, crop, foot, factor):
    part = source.crop(crop)
    part = part.resize((round(part.width*factor),round(part.height*factor)),Image.Resampling.NEAREST)
    result = Image.new('RGBA',CELL)
    result.paste(part,(ANCHOR[0]+round((crop[0]-foot[0])*factor),
                       ANCHOR[1]+round((crop[1]-foot[1])*factor)))
    return result

source = Image.open(ROOT/'chuheun-idle-calm-source.png').convert('RGBA')
source.putalpha(source.getchannel('A').point(lambda a: 255 if a>=128 else 0))
atlas = Image.new('RGBA',(CELL[0]*3,CELL[1]*2))
feet = [(246,488),(764,488),(1292,488),(252,985),(764,985),(1294,985)]
for i, foot in enumerate(feet):
    x,y = i%3*512,i//3*512
    cell = aligned(source,(x,y,x+512,y+512),foot,.37)
    atlas.paste(cell,(i%3*CELL[0],i//3*CELL[1]))
atlas.save(ROOT/'chuheun-idle-calm.png')

source = Image.open(ROOT/'yeonwoo-windup-fixed-source.png').convert('RGBA')
source.putalpha(source.getchannel('A').point(lambda a:255 if a>=128 else 0))
# Separate exactly the existing wrist/three chain links; the upper arm, hair,
# head, torso, legs and feet are one unchanged layer throughout every spin.
mask = Image.new('L',source.size)
ImageDraw.Draw(mask).polygon([(282,731),(346,755),(335,803),(335,854),
    (309,891),(283,923),(255,988),(235,1003),(211,990),(213,952),
    (251,887),(239,859),(240,827),(273,765)],fill=255)
alpha = source.getchannel('A')
from PIL import ImageChops
wrist = source.copy()
wrist.putalpha(ImageChops.multiply(alpha,mask))
body = source.copy()
body.putalpha(ImageChops.subtract(alpha,mask))
factor = 160/1380
foot = (565,1454)
crop = (150,70,925,1465)
for part,name in [(body,'body'),(wrist,'wrist')]:
    aligned(part,crop,foot,factor).save(ROOT/f'yeonwoo-windup-{name}.png')
rig = {
    'pivot':[(317-foot[0])*factor,(751-foot[1])*factor],
    'tip':[(234-foot[0])*factor,(978-foot[1])*factor],
    'cycle_seconds':1.6,
}
(ROOT/'yeonwoo-windup-rig.json').write_text(json.dumps(rig,indent=2),encoding='utf-8')
print('Calm idle: 6 frames; Yeonwoo: fixed body + cuff-pivot wrist',rig)
