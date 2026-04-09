# /// script
# requires-python = ">=3.10"
# dependencies = [
#     "mutagen",
#     "musicbrainzngs",
# ]
# ///

"""
Script de tagging automatique des MP3 téléchargés via yt-dlp.

Étape 1 : Parse le nom de fichier pour extraire artiste/titre
Étape 2 : Nettoie le bruit YouTube (Official Video, [4K], etc.)
Étape 3 : Interroge MusicBrainz pour compléter les métadonnées (album, année, genre)
Étape 4 : Écrit les tags ID3 avec mutagen

Usage : cd ~/Music && uv run tag_music.py [--dry-run] [--force]
"""

import re
import sys
import time
from pathlib import Path

import musicbrainzngs
from mutagen.id3 import ID3, TIT2, TPE1, TALB, TDRC, TCON, ID3NoHeaderError

# MusicBrainz demande un User-Agent avec une app identifiée + contact
musicbrainzngs.set_useragent("yt-dlp-tagger", "0.1", "https://github.com/placeholder")

# === NETTOYAGE DU NOM DE FICHIER ===

# Patterns YouTube à supprimer du titre
# On les compile une seule fois pour la perf
NOISE_PATTERNS: list[re.Pattern[str]] = [
    re.compile(p, re.IGNORECASE) for p in [
        # Vidéo
        r"\(official\s*(music\s*)?video\)",
        r"\(official\s*audio\)",
        r"\(official\s*HD\s*video\)",
        r"\(clip\s+officiel\)",
        r"\(audio\s+officiel\)",
        r"\(lyric\s*s?\s*video\)",
        r"\(visuali[sz]er\)",
        r"\(promo\s+video\)",
        r"\[official\s*(music\s*)?video\]",
        # Qualité
        r"\[4K\]",
        r"\[HD[^\]]*\]",
        r"\(HD[^\)]*\)",
        # Remaster
        r"\(remastered\s*\d{0,4}\)",
        # Live
        r"\([^)]*live[^)]*\)",
        r"\([^)]*shepperton[^)]*\)",
        # Divers
        r"\|\s*A COLORS SHOW",
        r"｜\s*A COLORS SHOW",
    ]
]

# Caractères Unicode spéciaux que yt-dlp utilise pour remplacer les interdits
UNICODE_REPLACEMENTS: dict[str, str] = {
    "：": ":",
    "⧸": "/",
    "＂": '"',
    "｜": "|",
}


def clean_noise(text: str) -> str:
    """Supprime les annotations YouTube du titre."""
    for pattern in NOISE_PATTERNS:
        text = pattern.sub("", text)
    return text.strip().rstrip("-").strip()


def normalize_unicode(text: str) -> str:
    """Remplace les caractères Unicode yt-dlp par leurs équivalents ASCII."""
    for uni, ascii_char in UNICODE_REPLACEMENTS.items():
        text = text.replace(uni, ascii_char)
    return text


def parse_filename(filename: str) -> tuple[str | None, str]:
    """
    Parse un nom de fichier pour en extraire artiste et titre.

    Cherche le pattern "Artiste - Titre" en priorité.
    Si pas trouvé, retourne None pour l'artiste et le nom nettoyé comme titre.

    Retourne : (artiste, titre)
    """
    # Enlever l'extension
    name = Path(filename).stem

    # Normaliser les caractères Unicode
    name = normalize_unicode(name)

    # Nettoyer le bruit YouTube
    name = clean_noise(name)

    # Essayer "Artiste - Titre" (avec variantes de tiret)
    # On split sur " - " en prenant seulement le premier tiret
    # pour gérer "Artist - Title - Subtitle"
    match = re.match(r"^(.+?)\s*[-–—]\s+(.+)$", name)
    if match:
        artist = match.group(1).strip()
        title = match.group(2).strip()

        # Gérer "ft." / "feat." dans le titre → on le garde dans le titre
        # mais on nettoie l'artiste
        return artist, title

    # Pas de pattern artiste-titre → tout est titre
    return None, name.strip()


# === MUSICBRAINZ ===

def search_musicbrainz(artist: str | None, title: str) -> dict[str, str]:
    """
    Cherche sur MusicBrainz les métadonnées d'un morceau.

    Retourne un dict avec les clés trouvées parmi :
    artist, title, album, year, genre
    """
    result: dict[str, str] = {}

    try:
        if artist:
            # Recherche avec artiste + titre → plus précis
            query = f'recording:"{title}" AND artist:"{artist}"'
        else:
            # Recherche par titre seul → moins précis mais mieux que rien
            query = f'recording:"{title}"'

        data = musicbrainzngs.search_recordings(query=query, limit=1)

        recordings = data.get("recording-list", [])
        if not recordings:
            return result

        rec = recordings[0]

        # Titre
        if "title" in rec:
            result["title"] = rec["title"]

        # Artiste
        artist_credit = rec.get("artist-credit", [])
        if artist_credit:
            # artist-credit est une liste, le premier élément a le nom
            result["artist"] = artist_credit[0].get("artist", {}).get("name", "")

        # Album (premier release trouvé)
        releases = rec.get("release-list", [])
        if releases:
            release = releases[0]
            result["album"] = release.get("title", "")
            # Année depuis la date de release
            date = release.get("date", "")
            if date:
                result["year"] = date[:4]  # "2019-01-15" → "2019"

        # Genre (tags MusicBrainz)
        tags = rec.get("tag-list", [])
        if tags:
            # Prendre le tag avec le plus de votes
            best_tag = max(tags, key=lambda t: int(t.get("count", 0)))
            result["genre"] = best_tag["name"].title()

    except Exception as e:
        print(f"    ⚠ MusicBrainz error: {e}")

    return result


# === DÉTECTION DES FICHIERS DÉJÀ TAGGÉS ===

def is_already_tagged(filepath: Path) -> bool:
    """
    Vérifie si un fichier a déjà des tags ID3 écrits par ce script.

    On regarde si le tag TIT2 (titre) existe. S'il est là,
    c'est qu'on est déjà passé dessus → on skip.
    """
    try:
        tags = ID3(filepath)
        return "TIT2" in tags
    except ID3NoHeaderError:
        return False
    except Exception:
        return False


# === ÉCRITURE DES TAGS ID3 ===

def write_tags(filepath: Path, artist: str | None, title: str,
               album: str | None = None, year: str | None = None,
               genre: str | None = None) -> None:
    """
    Écrit les tags ID3 dans le fichier MP3.

    ID3 = le standard de métadonnées embarquées dans les fichiers MP3.
    Chaque info est stockée dans un "frame" identifié par un code :
      - TIT2 = titre
      - TPE1 = artiste
      - TALB = album
      - TDRC = année
      - TCON = genre
    """
    try:
        tags = ID3(filepath)
    except ID3NoHeaderError:
        # Pas de header ID3 → on en crée un vide
        tags = ID3()

    tags.add(TIT2(encoding=3, text=[title]))

    if artist:
        tags.add(TPE1(encoding=3, text=[artist]))
    if album:
        tags.add(TALB(encoding=3, text=[album]))
    if year:
        tags.add(TDRC(encoding=3, text=[year]))
    if genre:
        tags.add(TCON(encoding=3, text=[genre]))

    tags.save(filepath)


# === MAIN ===

def main() -> None:
    dry_run = "--dry-run" in sys.argv
    force = "--force" in sys.argv
    music_dir = Path(__file__).parent

    all_mp3 = sorted(music_dir.glob("*.mp3"))
    print(f"Trouvé {len(all_mp3)} fichiers MP3")

    # Filtrer les fichiers déjà taggés (sauf si --force)
    if force:
        mp3_files = all_mp3
        print("Mode --force : on retag tout\n")
    else:
        mp3_files = [f for f in all_mp3 if not is_already_tagged(f)]
        skipped = len(all_mp3) - len(mp3_files)
        if skipped:
            print(f"  {skipped} déjà taggés → skip")
        if not mp3_files:
            print("Rien à faire, tous les fichiers sont déjà taggés !")
            return
        print(f"  {len(mp3_files)} à tagger\n")

    if dry_run:
        print("=== MODE DRY-RUN — aucune modification ne sera faite ===\n")

    stats = {"tagged": 0, "mb_found": 0, "mb_not_found": 0, "errors": 0}

    for i, filepath in enumerate(mp3_files, 1):
        filename = filepath.name
        artist, title = parse_filename(filename)

        print(f"[{i}/{len(mp3_files)}] {filename}")
        print(f"  Parsé → artiste: {artist or '???'} | titre: {title}")

        # Chercher sur MusicBrainz
        mb = search_musicbrainz(artist, title)

        # MusicBrainz rate limit : max 1 requête/seconde
        time.sleep(1.1)

        if mb:
            stats["mb_found"] += 1
            # Préférer les données MusicBrainz si disponibles
            final_artist = mb.get("artist", artist)
            final_title = mb.get("title", title)
            album = mb.get("album")
            year = mb.get("year")
            genre = mb.get("genre")
            print(f"  MusicBrainz → {final_artist} - {final_title}")
            if album:
                print(f"    Album: {album} ({year or '?'})")
            if genre:
                print(f"    Genre: {genre}")
        else:
            stats["mb_not_found"] += 1
            final_artist = artist
            final_title = title
            album = year = genre = None
            print(f"  MusicBrainz → rien trouvé, on garde le parsing")

        if not dry_run:
            try:
                write_tags(filepath, final_artist, final_title, album, year, genre)
                stats["tagged"] += 1
                print(f"  ✓ Tags écrits")
            except Exception as e:
                stats["errors"] += 1
                print(f"  ✗ Erreur écriture: {e}")
        print()

    # Résumé
    print("=" * 50)
    print(f"Fichiers traités : {len(mp3_files)}")
    print(f"Tags écrits      : {stats['tagged']}")
    print(f"MusicBrainz OK   : {stats['mb_found']}")
    print(f"MusicBrainz vide : {stats['mb_not_found']}")
    print(f"Erreurs          : {stats['errors']}")


if __name__ == "__main__":
    main()
