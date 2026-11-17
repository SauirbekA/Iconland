#!/usr/bin/env python3
"""Register a theme page in web/themes.json + web/i18n/*.json and make its thumbnail.

    scripts/add-theme.py spec.json [--thumb snapshot.png]

spec.json:
{
  "id": "woods", "page": "woods.html", "adaptive": false,
  "zh": {"name": "森林", "desc": "..."},
  "groups": [ ...themes.json "groups" (zh-CN labels)... ],
  "en": {"name": ..., "desc": ..., "groups": [...], "params": {...}},
  "ru": {...}
}
The thumbnail is cropped to 16:9-ish (520x290), saved as web/thumbs/<id>.webp and embedded in web/thumbs-data.js.
"""
import base64, io, json, re, sys
from pathlib import Path

from PIL import Image

WEB = Path(__file__).resolve().parent.parent / "web"


def dump(path, obj):
    path.write_text(json.dumps(obj, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def main():
    spec = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
    thumb = sys.argv[sys.argv.index("--thumb") + 1] if "--thumb" in sys.argv else None
    tid = spec["id"]

    if thumb:
        im = Image.open(thumb).convert("RGB")
        w, h = im.size
        tw, th = 520, 290
        scale = max(tw / w, th / h)
        im = im.resize((round(w * scale), round(h * scale)), Image.LANCZOS)
        # Crop from the top-right area where Mac desktop icons usually live, so the adaptive look shows.
        x0 = max(0, im.width - tw - round(im.width * 0.04))
        im = im.crop((x0, 0, x0 + tw, th))
        buf = io.BytesIO()
        im.save(buf, "WEBP", quality=82, method=6)
        data = buf.getvalue()
        (WEB / "thumbs" / f"{tid}.webp").write_bytes(data)
        js = (WEB / "thumbs-data.js").read_text(encoding="utf-8")
        m = re.match(r"(window\.DESKLAND_THUMBS = Object\.freeze\()(\{.*\})(\);?\s*)$", js, re.S)
        thumbs = json.loads(m.group(2))
        thumbs[tid] = "data:image/webp;base64," + base64.b64encode(data).decode()
        (WEB / "thumbs-data.js").write_text(m.group(1) + json.dumps(thumbs, separators=(",", ":")) + m.group(3), encoding="utf-8")

    reg_path = WEB / "themes.json"
    reg = json.loads(reg_path.read_text(encoding="utf-8"))
    entry = {
        "id": tid,
        **({"adaptive": True} if spec.get("adaptive") else {}),
        "name": spec["zh"]["name"],
        "desc": spec["zh"]["desc"],
        "page": spec["page"],
        "status": "ready",
        "product": "free",
        "thumb": f"url(thumbs/{tid}.webp) center / cover no-repeat, {spec.get('fallback', '#7a9')}",
        "thumbSource": "custom",
        "groups": spec["groups"],
    }
    reg["themes"] = [t for t in reg["themes"] if t["id"] != tid] + [entry]
    dump(reg_path, reg)

    for code in ("en", "ru"):
        p = WEB / "i18n" / f"{code}.json"
        j = json.loads(p.read_text(encoding="utf-8"))
        j.setdefault("themes", {})[tid] = spec[code]
        dump(p, j)
    print(f"registered {tid}")


if __name__ == "__main__":
    main()
