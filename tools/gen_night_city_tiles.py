"""
Generates a minimal "night city" 16x16 tileset for the field demo.

Tiles (left to right):
  0 road            - flat dark asphalt with a faint lane-line texture
  1 sidewalk        - lighter gray with a paving-slab grid
  2 wall            - building exterior, dark brick-ish
  3 window_lit      - wall + warm lit window (blocks)
  4 window_dark     - wall + unlit window (blocks)
  5 lamp            - sidewalk base + streetlamp post & glow (blocks)

Output: assets/tilesets/night_city_tiles.png (96x16)
"""
from PIL import Image

TILE = 16
NAMES = ["road", "sidewalk", "wall", "window_lit", "window_dark", "lamp"]

ASPHALT = (32, 32, 42, 255)
ASPHALT_LINE = (46, 46, 58, 255)
SIDEWALK = (86, 86, 98, 255)
SIDEWALK_LINE = (70, 70, 82, 255)
WALL = (40, 34, 46, 255)
WALL_LINE = (52, 44, 58, 255)
WINDOW_LIT = (255, 205, 90, 255)
WINDOW_LIT_EDGE = (200, 150, 60, 255)
WINDOW_DARK = (18, 20, 34, 255)
WINDOW_DARK_EDGE = (48, 48, 66, 255)
LAMP_POST = (60, 60, 70, 255)
LAMP_GLOW = (255, 235, 170, 255)


def blank():
    return Image.new("RGBA", (TILE, TILE), (0, 0, 0, 0))


def rect(img, x0, y0, x1, y1, color):
    d = img.load()
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if 0 <= x < TILE and 0 <= y < TILE:
                d[x, y] = color


def tile_road():
    img = blank()
    rect(img, 0, 0, 15, 15, ASPHALT)
    for y in (3, 11):
        for x in range(0, 16, 4):
            rect(img, x, y, x + 1, y, ASPHALT_LINE)
    return img


def tile_sidewalk():
    img = blank()
    rect(img, 0, 0, 15, 15, SIDEWALK)
    for x in range(0, 16, 8):
        rect(img, x, 0, x, 15, SIDEWALK_LINE)
    for y in range(0, 16, 8):
        rect(img, 0, y, 15, y, SIDEWALK_LINE)
    return img


def tile_wall():
    img = blank()
    rect(img, 0, 0, 15, 15, WALL)
    for i, y in enumerate((4, 9, 14)):
        offset = 0 if i % 2 == 0 else 4
        for x in range(offset, 16, 8):
            rect(img, x, y, x + 7, y, WALL_LINE)
    return img


def tile_window(lit):
    img = tile_wall()
    edge = WINDOW_LIT_EDGE if lit else WINDOW_DARK_EDGE
    fill = WINDOW_LIT if lit else WINDOW_DARK
    rect(img, 4, 4, 11, 11, edge)
    rect(img, 5, 5, 10, 10, fill)
    if lit:
        rect(img, 7, 5, 8, 10, WINDOW_LIT_EDGE)
    return img


def tile_lamp():
    img = tile_sidewalk()
    rect(img, 7, 6, 8, 15, LAMP_POST)
    rect(img, 5, 4, 10, 6, LAMP_POST)
    rect(img, 6, 1, 9, 4, LAMP_GLOW)
    return img


def main():
    tiles = [tile_road(), tile_sidewalk(), tile_wall(), tile_window(True), tile_window(False), tile_lamp()]
    sheet = Image.new("RGBA", (TILE * len(tiles), TILE), (0, 0, 0, 0))
    for i, t in enumerate(tiles):
        sheet.paste(t, (i * TILE, 0))
    out = "assets/tilesets/night_city_tiles.png"
    sheet.save(out)
    print("saved", out, sheet.size, NAMES)


if __name__ == "__main__":
    main()
