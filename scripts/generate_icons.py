import os
import math
from PIL import Image, ImageDraw

def render_logo(size=1024):
    # Oversample 2x for ultra smooth antialiasing
    scale = 2
    S = size * scale
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # 1. Background rounded rect / circle
    # Colors
    c_bg = (248, 245, 239, 255)       # Sand #F8F5EF
    c_teal = (31, 92, 87, 255)        # Primary Teal #1F5C57
    c_teal_dark = (20, 61, 57, 255)   # Dark Teal #143D39
    c_coral = (224, 122, 79, 255)     # Warm Coral #E07A4F

    # Draw rounded background
    r = int(S * 0.22)
    draw.rounded_rectangle([(0, 0), (S - 1, S - 1)], radius=r, fill=c_bg)

    # Nest logo area: inset with 14% padding so Android round icons don't clip
    margin = S * 0.14
    box_w = S - (2 * margin)
    box_h = S - (2 * margin)
    ox = margin
    oy = margin

    def X(f): return ox + f * box_w
    def Y(f): return oy + f * box_h

    # Figures:
    # Left Parent (Teal)
    pr = box_w * 0.12
    draw.ellipse([X(0.32) - pr, Y(0.38) - pr, X(0.32) + pr, Y(0.38) + pr], fill=c_teal)
    draw.ellipse([X(0.32) - pr * 1.05, Y(0.56) - pr * 1.2, X(0.32) + pr * 1.05, Y(0.56) + pr * 1.2], fill=c_teal)

    # Right Parent (Teal)
    draw.ellipse([X(0.68) - pr, Y(0.38) - pr, X(0.68) + pr, Y(0.38) + pr], fill=c_teal)
    draw.ellipse([X(0.68) - pr * 1.05, Y(0.56) - pr * 1.2, X(0.68) + pr * 1.05, Y(0.56) + pr * 1.2], fill=c_teal)

    # Center Child (Warm Coral)
    cr = box_w * 0.095
    draw.ellipse([X(0.50) - cr, Y(0.44) - cr, X(0.50) + cr, Y(0.44) + cr], fill=c_coral)
    draw.ellipse([X(0.50) - cr, Y(0.60) - cr, X(0.50) + cr, Y(0.60) + cr], fill=c_coral)

    # Nest Bowl (Cubic Bezier curve from (0.14, 0.62) to (0.86, 0.62))
    stroke_w = int(box_w * 0.08)
    bowl_pts = []
    p0 = (X(0.14), Y(0.62))
    p1 = (X(0.18), Y(0.90))
    p2 = (X(0.82), Y(0.90))
    p3 = (X(0.86), Y(0.62))
    steps = 100
    for i in range(steps + 1):
        t = i / steps
        bx = (1-t)**3 * p0[0] + 3*(1-t)**2*t * p1[0] + 3*(1-t)*t**2 * p2[0] + t**3 * p3[0]
        by = (1-t)**3 * p0[1] + 3*(1-t)**2*t * p1[1] + 3*(1-t)*t**2 * p2[1] + t**3 * p3[1]
        bowl_pts.append((bx, by))

    for pt in bowl_pts:
        draw.ellipse([pt[0] - stroke_w/2, pt[1] - stroke_w/2, pt[0] + stroke_w/2, pt[1] + stroke_w/2], fill=c_teal_dark)

    # Nest Rim (Quadratic Bezier curve from (0.10, 0.62) to (0.90, 0.62) with control at (0.50, 0.66))
    rim_pts = []
    q0 = (X(0.10), Y(0.62))
    q1 = (X(0.50), Y(0.66))
    q2 = (X(0.90), Y(0.62))
    for i in range(steps + 1):
        t = i / steps
        rx = (1-t)**2 * q0[0] + 2*(1-t)*t * q1[0] + t**2 * q2[0]
        ry = (1-t)**2 * q0[1] + 2*(1-t)*t * q1[1] + t**2 * q2[1]
        rim_pts.append((rx, ry))

    for pt in rim_pts:
        draw.ellipse([pt[0] - stroke_w/2, pt[1] - stroke_w/2, pt[0] + stroke_w/2, pt[1] + stroke_w/2], fill=c_teal)

    # Downsample with Lanczos
    return img.resize((size, size), Image.Resampling.LANCZOS)

def main():
    base_dir = os.path.abspath(".")
    android_res = os.path.join(base_dir, "android", "app", "src", "main", "res")

    android_sizes = {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }

    master = render_logo(1024)

    # Save to Android
    for folder, dim in android_sizes.items():
        target_dir = os.path.join(android_res, folder)
        os.makedirs(target_dir, exist_ok=True)
        target_path = os.path.join(target_dir, "ic_launcher.png")
        resized = master.resize((dim, dim), Image.Resampling.LANCZOS)
        resized.save(target_path, "PNG")
        print(f"Saved {target_path} ({dim}x{dim})")

    # Also save 512x512 play store icon in assets/icons/icon.png
    assets_icon_dir = os.path.join(base_dir, "assets", "icons")
    os.makedirs(assets_icon_dir, exist_ok=True)
    master.resize((512, 512), Image.Resampling.LANCZOS).save(os.path.join(assets_icon_dir, "icon.png"), "PNG")

    # Save to iOS AppIcon.appiconset
    ios_icons = os.path.join(base_dir, "ios", "Runner", "Assets.xcassets", "AppIcon.appiconset")
    if os.path.exists(ios_icons):
        for fname in os.listdir(ios_icons):
            if fname.endswith(".png"):
                full_path = os.path.join(ios_icons, fname)
                try:
                    with Image.open(full_path) as current:
                        w, h = current.size
                    master.resize((w, h), Image.Resampling.LANCZOS).save(full_path, "PNG")
                    print(f"Saved iOS {fname} ({w}x{h})")
                except Exception as e:
                    print(f"Error updating {fname}: {e}")

if __name__ == "__main__":
    main()
