from PIL import Image, ImageDraw, ImageFont

BASE = "/Users/a1/Library/Mobile Documents/com~apple~CloudDocs/TaskFlow/TaskFlow/Assets.xcassets/AppIcon.appiconset"

EMOJI = "🔗"

def make_icon(size):
    s = size
    mask = Image.new("L", (s, s), 0)
    ImageDraw.Draw(mask).rounded_rectangle([(0,0),(s-1,s-1)], radius=int(s*0.225), fill=255)

    # Apple Music 정확한 컬러 — 대각선 그라디언트
    bg = Image.new("RGBA", (s, s))
    px = bg.load()
    for y in range(s):
        for x in range(s):
            t = (x + y) / (2 * (s - 1))
            # #FF6369 → #D4001E
            r = int(255 + (212 - 255) * t)
            g = int( 99 + (  0 -  99) * t)
            b = int( 99 + ( 30 -  99) * t)
            px[x, y] = (r, g, b, 255)

    bg.putalpha(mask)
    img = Image.new("RGBA", (s,s), (0,0,0,0))
    img.paste(bg, (0,0), bg)

    # 이모지 렌더링 — Apple Color Emoji는 em size가 달라 3배로 설정
    font_size = int(s * 1.6)
    try:
        font = ImageFont.truetype("/System/Library/Fonts/Apple Color Emoji.ttc", font_size)
    except:
        font = ImageFont.load_default()

    draw = ImageDraw.Draw(img)
    draw.text((s//2, s//2), EMOJI, font=font, anchor="mm", embedded_color=True)

    final = Image.new("RGBA", (s,s), (0,0,0,0))
    final.paste(img, (0,0), mask)
    return final


sizes = {
    "AppIcon-1024.png":           1024,
    "AppIcon-mac-16x16@1x.png":   16,
    "AppIcon-mac-16x16@2x.png":   32,
    "AppIcon-mac-32x32@1x.png":   32,
    "AppIcon-mac-32x32@2x.png":   64,
    "AppIcon-mac-128x128@1x.png": 128,
    "AppIcon-mac-128x128@2x.png": 256,
    "AppIcon-mac-256x256@1x.png": 256,
    "AppIcon-mac-256x256@2x.png": 512,
    "AppIcon-mac-512x512@1x.png": 512,
    "AppIcon-mac-512x512@2x.png": 1024,
}

cache = {}
for fname, px in sizes.items():
    if px not in cache:
        cache[px] = make_icon(px)
    cache[px].save(f"{BASE}/{fname}", "PNG")
    print(f"saved {fname}")
print("done")
