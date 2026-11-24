"""Encode unmodified Godot screenshots as a real-speed animation preview."""
from pathlib import Path
import argparse
from PIL import Image

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--frames', default='.godot/field-modern-frames')
parser.add_argument('--output', default='tests/preview-field-modern.gif')
parser.add_argument('--duration-ms', type=float, default=20)
args = parser.parse_args()
paths = sorted((root / args.frames).glob('*.png'))
frames = [Image.open(path).convert('RGB') for path in paths]
# GIF stores centiseconds. Distribute rounding so a 60fps clip retains its duration.
durations = [10 * (round((i + 1) * args.duration_ms / 10) - round(i * args.duration_ms / 10))
             for i in range(len(frames))]
frames[0].save(root / args.output, save_all=True,
               append_images=frames[1:], duration=durations, loop=0, optimize=False)
print(f'FIELD WALK GIF: {len(frames)} frames, {len(frames) * args.duration_ms / 1000:.2f}s')
