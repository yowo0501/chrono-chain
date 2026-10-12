"""Check rendered fixed regions and encode the real-time Godot capture."""
from pathlib import Path
from PIL import Image, ImageChops

root = Path(__file__).resolve().parents[2] / 'battle-preview/v4'
poses = [Image.open(root/f'fixed-{i}.png').convert('RGB') for i in range(6)]
for name,box in [('head',(103,274,143,322)),('feet',(79,403,166,434))]:
    first = poses[0].crop(box)
    for i,pose in enumerate(poses[1:],1):
        assert ImageChops.difference(first,pose.crop(box)).getbbox() is None, f'{name} moved at pose {i}'
    print(name,'pixel-identical at all 6 spin angles')

frames=[]
for path in sorted((root/'frames').glob('*.png')):
    with Image.open(path) as source:
        frames.append(source.convert('RGB').resize((768,672),Image.Resampling.LANCZOS))
frames[0].save(root/'battle-v4.gif',save_all=True,append_images=frames[1:],duration=50,loop=0,optimize=False)
print('battle-v4.gif',len(frames),'frames at real 50 ms cadence')
