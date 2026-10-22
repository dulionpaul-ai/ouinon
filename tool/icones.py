"""Icônes de Ouinon (logo n° 3, choix de Paul du 22/10/2026) : un rond
coupé en deux, moitié citron (oui), moitié corail (non), sur fond sombre.

Lancement depuis la racine du dépôt : python3 tool/icones.py
Écrit les icônes Android (classiques, adaptatives, monochrome) et iPhone.
"""

import json
from pathlib import Path

from PIL import Image, ImageDraw

FOND = (0x17, 0x17, 0x1A, 255)
CITRON = (0xD4, 0xFF, 0x3A, 255)
CORAIL = (0xFF, 0x6B, 0x5E, 255)
BLANC = (255, 255, 255, 255)
SUR = 8  # suréchantillonnage, pour des bords lisses

RES = Path("android/app/src/main/res")
IOS = Path("ios/Runner/Assets.xcassets/AppIcon.appiconset")


def logo(draw, cote, largeur, gauche=CITRON, droite=CORAIL):
    """Les deux demi-disques, centrés, sur `largeur` pixels de large
    (dessin d'origine : rayon 70, écart 12, soit 152 de large)."""
    echelle = largeur / 152
    r = 70 * echelle
    ecart = 6 * echelle
    cx, cy = cote / 2, cote / 2
    draw.pieslice(
        [cx - ecart - r, cy - r, cx - ecart + r, cy + r], 90, 270, fill=gauche
    )
    draw.pieslice(
        [cx + ecart - r, cy - r, cx + ecart + r, cy + r], 270, 90, fill=droite
    )


def image(cote, fond, largeur_logo, rayon=0, gauche=CITRON, droite=CORAIL):
    grand = cote * SUR
    img = Image.new("RGBA", (grand, grand), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    if fond is not None:
        if rayon:
            d.rounded_rectangle([0, 0, grand - 1, grand - 1], rayon * SUR, fill=fond)
        else:
            d.rectangle([0, 0, grand, grand], fill=fond)
    logo(d, grand, largeur_logo * SUR, gauche, droite)
    return img.resize((cote, cote), Image.LANCZOS)


DENSITES = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}

for nom, f in DENSITES.items():
    dossier = RES / f"mipmap-{nom}"
    dossier.mkdir(parents=True, exist_ok=True)
    # Icône classique (avant Android 8) : carré arrondi.
    c = round(48 * f)
    image(c, FOND, c * 0.6, rayon=c * 0.22).save(dossier / "ic_launcher.png")
    # Icône adaptative : 108 dp, logo dans la zone sûre (66 dp).
    c = round(108 * f)
    image(c, None, 58 * f).save(dossier / "ic_launcher_foreground.png")
    image(c, None, 58 * f, gauche=BLANC, droite=BLANC).save(
        dossier / "ic_launcher_monochrome.png"
    )

adaptative = RES / "mipmap-anydpi-v26"
adaptative.mkdir(exist_ok=True)
(adaptative / "ic_launcher.xml").write_text(
    """<?xml version="1.0" encoding="utf-8"?>
<!-- Icône adaptative (tool/icones.py) : logo sur fond sombre ; monochrome
     pour les icônes à thème d'Android 13. -->
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
    <monochrome android:drawable="@mipmap/ic_launcher_monochrome"/>
</adaptive-icon>
"""
)
(RES / "values" / "colors.xml").write_text(
    """<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#17171A</color>
    <color name="fond_sombre">#0F0F12</color>
</resources>
"""
)

# iPhone : carrés pleins, sans transparence (iOS arrondit lui-même).
contenu = json.loads((IOS / "Contents.json").read_text())
for entree in contenu["images"]:
    taille = float(entree["size"].split("x")[0])
    echelle = int(entree["scale"].rstrip("x"))
    cote = round(taille * echelle)
    image(cote, FOND, cote * 0.6).convert("RGB").save(IOS / entree["filename"])

print("Icônes écrites.")
