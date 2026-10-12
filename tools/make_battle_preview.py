"""Encode the actual Godot renderer captures; no simulated gameplay artwork."""
from pathlib import Path
from PIL import Image

root = Path(__file__).resolve().parents[2] / 'battle-preview/v3'
for folder, output in [('frames', 'battle-v3.gif'), ('idle', 'idle-v3.gif')]:
    files = sorted((root / folder).glob('*.png'))
    frames = []
    for path in files:
        with Image.open(path) as source:
            frames.append(source.convert('RGB').resize((768,672), Image.Resampling.LANCZOS))
    frames[0].save(root / output, save_all=True, append_images=frames[1:],
                   duration=60, loop=0, optimize=False)
    print(output, len(frames), 'frames', (root/output).stat().st_size, 'bytes')
