"""Icônes de Ouinon : le « rond dissocié » (thème des deux toi, 26/10/2026),
un rond coupé en deux, moitié gauche ambre (le soir, celui qui décide)
plus haute, moitié droite bleu-vert (le jour, celui qui exécute) plus
basse, sur fond sombre. Reprend le logo n° 3 de Paul (rond coupé en deux,
22/10/2026, réduit de 5 %), avec les couleurs des deux toi et le décalage.

Lancement depuis la racine du dépôt : python3 tool/icones.py
Écrit les icônes Android (classiques, adaptatives, monochrome) et iPhone.
"""

import json
from pathlib import Path

from PIL import Image, ImageDraw

FOND = (0x17, 0x17, 0x1A, 255)
TAILLE = 0.95  # part du logo d'origine (réduit de 5 %)
AMBRE = (0xF2, 0xA5, 0x41, 255)
BLEU_VERT = (0x5F, 0xE0, 0xC9, 255)
BLANC = (255, 255, 255, 255)
SUR = 8  # suréchantillonnage, pour des bords lisses

RES = Path("android/app/src/main/res")
IOS = Path("ios/Runner/Assets.xcassets/AppIcon.appiconset")


def logo(draw, cote, largeur, gauche=AMBRE, droite=BLEU_VERT):
    """Les deux demi-disques, centrés, sur `largeur` pixels de large
    (dessin d'origine : rayon 70, écart 12, soit 152 de large ; moitié
    gauche montée de 8, moitié droite descendue de 8)."""
    echelle = largeur / 152
    r = 70 * echelle
    ecart = 6 * echelle
    dy = 8 * echelle
    cx, cy = cote / 2, cote / 2
    draw.pieslice(
        [cx - ecart - r, cy - dy - r, cx - ecart + r, cy - dy + r],
        90,
        270,
        fill=gauche,
    )
    draw.pieslice(
        [cx + ecart - r, cy + dy - r, cx + ecart + r, cy + dy + r],
        270,
        90,
        fill=droite,
    )


def image(cote, fond, largeur_logo, rayon=0, gauche=AMBRE, droite=BLEU_VERT):
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
    image(c, FOND, c * 0.6 * TAILLE, rayon=c * 0.22).save(dossier / "ic_launcher.png")
    # Icône adaptative : 108 dp, logo dans la zone sûre (66 dp).
    c = round(108 * f)
    image(c, None, 58 * f * TAILLE).save(dossier / "ic_launcher_foreground.png")
    image(c, None, 58 * f * TAILLE, gauche=BLANC, droite=BLANC).save(
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
    image(cote, FOND, cote * 0.6 * TAILLE).convert("RGB").save(IOS / entree["filename"])

print("Icônes écrites.")
