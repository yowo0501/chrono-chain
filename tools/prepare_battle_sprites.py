"""Pack generated pose crops into equal, nearest-neighbor Godot animation cells.

The generator did not respect equal grid boundaries; explicit crop rectangles
exclude neighboring poses. Original RGBA sources remain untouched.
"""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1] / "assets/sprites/battle"
SHEETS = {
    "chuheun": (4, 2, (192, 200), 0.34, [
        (65, 8, 361, 488), (448, 8, 720, 488),
        (744, 8, 1108, 488), (1110, 90, 1536, 490),
        (25, 536, 423, 999), (456, 545, 811, 985),
        (844, 490, 1074, 999), (1206, 518, 1483, 1007),
    ]),
    "yeonwoo": (4, 2, (192, 200), 0.34, [
        (52, 16, 353, 493), (418, 16, 717, 493),
        (733, 8, 1086, 495), (1086, 68, 1536, 493),
        (37, 516, 430, 993), (443, 530, 754, 992),
        (824, 511, 1083, 995), (1200, 516, 1437, 993),
    ]),
    "shadow": (3, 1, (192, 176), 0.26, [
        (168, 117, 530, 645), (674, 144, 1379, 645),
        (1609, 144, 2067, 654),
    ]),
}
for name, (cols, rows, cell, scale, rectangles) in SHEETS.items():
    source = Image.open(ROOT / f"{name}-source.png").convert("RGBA")
    sheet = Image.new("RGBA", (cols * cell[0], rows * cell[1]))
    for index, rect in enumerate(rectangles):
        pose = source.crop(rect)
        pose = pose.resize((round(pose.width * scale), round(pose.height * scale)), Image.Resampling.NEAREST)
        x = (index % cols) * cell[0] + (cell[0] - pose.width) // 2
        y = (index // cols) * cell[1] + cell[1] - 8 - pose.height
        sheet.paste(pose, (x, y))
    sheet.save(ROOT / f"{name}.png")
    print(f"Packed {name}: {sheet.size}")

# Integrated action cells share a foot anchor. Some generated poses extend beyond
# their nominal grid cell, so crop actual pose bounds rather than the nominal grid.
ACTION_POSES = {
    "chuheun": (0.405, [
        ([(48, 35, 478, 502)], (260, 495)),
        ([(550, 75, 1022, 502)], (752, 495)),
        ([(1090, 90, 1520, 502)], (1309, 495)),
        ([(15, 576, 501, 870), (15, 870, 463, 972)], (242, 960)),
        ([(477, 600, 1088, 966)], (726, 959)),
        ([(1115, 546, 1528, 970)], (1320, 960)),
    ]),
    "yeonwoo": (0.395, [
        ([(45, 15, 480, 499)], (250, 490)),
        ([(505, 24, 1048, 499)], (715, 490)),
        ([(1060, 70, 1520, 499)], (1270, 490)),
        ([(15, 545, 501, 880), (15, 880, 449, 965)], (240, 955)),
        ([(505, 575, 1170, 850), (465, 850, 970, 965)], (710, 955)),
        ([(1175, 520, 1525, 635), (1190, 635, 1525, 979)], (1360, 965)),
    ]),
}
for name, (scale, poses) in ACTION_POSES.items():
    source = Image.open(ROOT / f"{name}-action-source.png").convert("RGBA")
    sheet = Image.new("RGBA", (1152, 448))
    for index, (regions, anchor) in enumerate(poses):
        # All regions are extracted in the same coordinate system; no independent
        # chain asset is made. Hard alpha removes faint generator grid/halo pixels.
        bounds = (min(r[0] for r in regions), min(r[1] for r in regions),
                  max(r[2] for r in regions), max(r[3] for r in regions))
        pose = Image.new("RGBA", (bounds[2] - bounds[0], bounds[3] - bounds[1]))
        for region in regions:
            pose.paste(source.crop(region), (region[0] - bounds[0], region[1] - bounds[1]))
        pose.putalpha(pose.getchannel("A").point(lambda a: 255 if a >= 128 else 0))
        pose = pose.resize((round(pose.width * scale), round(pose.height * scale)), Image.Resampling.NEAREST)
        x = (index % 3) * 384 + 128 + round((bounds[0] - anchor[0]) * scale)
        y = (index // 3) * 224 + 216 + round((bounds[1] - anchor[1]) * scale)
        sheet.paste(pose, (x, y))
    sheet.save(ROOT / f"{name}-action.png")
    print(f"Packed integrated actions for {name}: {sheet.size}")
