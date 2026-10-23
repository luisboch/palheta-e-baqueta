"""Extrai artista/título de títulos no estilo de vídeo (portado do kraoke, sem mudanças de regra).

Ex.: "Cezar & Paulinho ｜ Chalana ｜ Oficial [Alma Sertaneja II]"
     "Vontade Dividida - César Menotti e Fabiano (Memórias Anos 80 e 90)"

É heurístico: a etapa de letras usa também o texto livre (`query`) e a duração,
então um erro aqui não impede de achar a letra.
"""

from __future__ import annotations

import re
import unicodedata
from typing import Any

FULLWIDTH = str.maketrans({"｜": "|", "⧸": "/", "：": ":", "–": "-", "—": "-"})

BRACKETS = re.compile(r"\s*[(\[][^)\]]*[)\]]")
HASHTAG = re.compile(r"\s*#\S+")
SEP = re.compile(r"\s+(?:-{1,2}|\|)\s+")
FEAT = re.compile(r"\s+(?:part\.?|participação|feat\.?|featuring|ft\.?)\s+(.+)$", re.I)
FEAT_BRACKET = re.compile(r"(?:part\.?|participação|feat\.?|featuring|ft\.?)\s+(.+)", re.I)
# Enfeites de título de vídeo, em português e inglês ("DVD Bem Sertanejo", "Official Music Video",
# "Remastered 2011"). Tirados do começo e do fim de cada trecho. "Live" não entra: seria cortado
# de títulos como "Live Forever"; ao vivo é detectado à parte (LIVE).
NOISE = (
    r"(?:ao vivo|oficial|official|"
    r"(?:music |lyrics? |official )?v[ií]deo(?: clip| oficial| official)?|clipe(?: oficial)?|"
    r"dvd|ac[uú]stico|acoustic(?: version)?|lyrics?|letra|"
    r"[aá]udio(?: oficial| official)?|visuali[sz]er|"
    r"remaster(?:ed)?(?: version)?(?: \d{4})?|\d{4} remaster(?:ed)?|hd|hq|4k)"
)
LEADING_NOISE = re.compile(rf"^{NOISE}\b[\s,:]*", re.I)
TRAILING_NOISE = re.compile(rf"(?:\s+{NOISE})+$", re.I)
# Ao vivo: "Ao Vivo" em qualquer lugar; "live" só em contexto claro: "(Live …)", um trecho
# que é só "Live" ("… - Live") ou "Live at/in/from …". Nunca "- Live Tonight" (título).
LIVE = re.compile(
    r"\bao vivo\b|[(\[]\s*live\b|[|-]\s*live\s*(?:$|[(\[])|\blive (?:at|in|from|session)\b",
    re.I,
)
MEDLEY = re.compile(r"pou?t[\s-]?pourri", re.I)
ARTIST_LIKE = re.compile(r"\s&\s|\se\s")
# Sufixos comuns de nome de canal ("MarisaMonteVEVO", "Radar Records Oficial").
CHANNEL_SUFFIX = re.compile(r"(?:vevo|oficial|official|tv|music|musica|channel|canal)+$")


def parse_youtube_music(description: str) -> dict[str, str] | None:
    """Música e artista da descrição automática do YouTube Music, quando houver.

    Faixas "Provided to YouTube by <gravadora>" trazem uma linha "Música · Artista · Outros".
    É a fonte mais confiável que o MP3 tem: o TIT2 vem só com a música (nada para o
    parse_title separar) e o TPE1 mistura artistas e gravadora ("Chrystian & Ralf, Continental").
    Só o primeiro artista é usado; os seguintes muitas vezes são a gravadora.
    """
    if not description.startswith("Provided to YouTube by"):
        return None
    blocks = description.split("\n\n")
    parts = [p.strip() for p in blocks[1].split(" · ")] if len(blocks) > 1 else []
    if len(parts) < 2 or not parts[0] or not parts[1]:
        return None
    return {"title": parts[0], "artist": parts[1]}


def normalize(s: str) -> str:
    s = unicodedata.normalize("NFKD", s.casefold())
    return " ".join("".join(c for c in s if not unicodedata.combining(c)).split())


def _compact(s: str) -> str:
    """Só letras e números, sem acento nem caixa: "MARISAMONTE" == "Marisa Monte"."""
    return re.sub(r"[\W_]+", "", normalize(s))


def _is_channel_of(channel: str, part: str) -> bool:
    """O canal que publicou (TPE1) é o do artista deste trecho?"""
    c, p = channel, _compact(part)
    return len(c) >= 4 and len(p) >= 4 and (c in p or p in c)


def _strip_noise(part: str) -> str:
    while m := LEADING_NOISE.match(part):
        part = part[m.end() :]
    part = TRAILING_NOISE.sub("", part)
    return part.strip(" -,:")


def parse_title(raw: str, uploader: str = "") -> dict[str, Any]:
    s = raw.translate(FULLWIDTH).replace("@", "")
    live = bool(LIVE.search(s))
    medley = bool(MEDLEY.search(s))
    s = HASHTAG.sub("", s)

    featuring: list[str] = []
    bracketed: list[str] = []
    for b in BRACKETS.findall(s):
        b = b.strip()[1:-1].strip()
        if m := FEAT_BRACKET.match(b):
            featuring.append(m.group(1).strip())
        else:
            bracketed.append(b)
    s = " ".join(BRACKETS.sub("", s).split())

    parts: list[str] = []
    for p in SEP.split(s):
        if m := FEAT.search(p):
            featuring.append(m.group(1).strip())
            p = p[: m.start()]
        # "Michel Teló - Pot Pourri - ..." / "Guilherme & Santiago Pot Pourri A Noite..."
        for q in MEDLEY.split(p):
            if q := _strip_noise(q):
                parts.append(q)

    artist: str | None = None
    title = parts[0] if parts else raw
    if len(parts) >= 2:
        a, b = parts[0], parts[1]
        channel = CHANNEL_SUFFIX.sub("", _compact(uploader))
        if _is_channel_of(channel, a):
            artist, title = a, b
        elif _is_channel_of(channel, b) or (ARTIST_LIKE.search(b) and not ARTIST_LIKE.search(a)):
            artist, title = b, a
        elif not ARTIST_LIKE.search(a) and (
            inner := next((x for x in bracketed if ARTIST_LIKE.search(x)), None)
        ):
            # "VONTADE DIVIDIDA | MITOS ( Eduardo Costa & Ralf )"
            artist, title = inner, a
        else:
            artist, title = a, b

    if len(parts) >= 4:
        # "Artista - Música 1 - Música 2 - Música 3"
        title = " / ".join(p for p in parts if p != artist)
    medley = medley or "/" in title or len(parts) >= 4
    title = title.strip(" :-")

    return {
        "title": title,
        "artist": artist,
        "featuring": featuring,
        "live": live,
        "medley": medley,
        "query": " ".join(x for x in (artist, title) if x),
        "title_raw": raw,
        "uploader": uploader or None,
    }
