import pytest

from pbq.titles import parse_title, parse_youtube_music


@pytest.mark.parametrize(
    "raw, uploader, artist, title",
    [
        (
            "Bruno & Marrone - Dormi na Praça (Ao Vivo)",
            "Bruno & Marrone",
            "Bruno & Marrone",
            "Dormi na Praça",
        ),
        ("Cezar & Paulinho ｜ Chalana ｜ Oficial [Alma Sertaneja II]", "", "Cezar & Paulinho", "Chalana"),
        ("Michel Teló - Índia ｜ DVD Bem Sertanejo", "", "Michel Teló", "Índia"),
        (
            "Vontade Dividida -  César Menotti e Fabiano (Memórias Anos 80 e 90)",
            "",
            "César Menotti e Fabiano",
            "Vontade Dividida",
        ),
        (
            "Um Degrau Na Escada - DVD Chico Rey e Parana - Cantos e Cordas",
            "",
            "Chico Rey e Parana",
            "Um Degrau Na Escada",
        ),
        (
            "João Bosco & Vinícius -- Esperando você chegar -- Vídeo Oficial",
            "",
            "João Bosco & Vinícius",
            "Esperando você chegar",
        ),
        (
            "Althaír & Alexandre - Laço Aberto  (Ao vivo em Vitória⧸Es)",
            "Radar Records Oficial",
            "Althaír & Alexandre",
            "Laço Aberto",
        ),
        ("Majestade o Sabiá (Ao Vivo)", "", None, "Majestade o Sabiá"),
        (
            "Althaír & Alexandre - Tá Nervoso Vai Pesca! (Ao vivo em Vitória⧸Es) Oficial",
            "",
            "Althaír & Alexandre",
            "Tá Nervoso Vai Pesca!",
        ),
        (
            "VONTADE DIVIDIDA ｜ MITOS ( Eduardo Costa & Ralf ) #mitos #vontadedividida",
            "",
            "Eduardo Costa & Ralf",
            "VONTADE DIVIDIDA",
        ),
        (
            "Edy Britto & Samuel, @EduardoCosta - Fui Dando Porrada (Vídeo Oficial)",
            "",
            "Edy Britto & Samuel, EduardoCosta",
            "Fui Dando Porrada",
        ),
        (
            "Guilherme & Santiago Pot Pourri A Noite do Nosso Amor Noite Maravilhosa [DVD Tudo Tem Um Porque]",
            "",
            "Guilherme & Santiago",
            "A Noite do Nosso Amor Noite Maravilhosa",
        ),
        (
            "Michel Teló - Pot Pourri - Pense em Mim ⧸ Coração Está em Pedaços ｜ DVD Bem Sertanejo",
            "",
            "Michel Teló",
            "Pense em Mim / Coração Está em Pedaços",
        ),
        (
            "Milionário e José Rico - Decida - Jogo Do Amor - Tribunal Do Amor (ao vivo)",
            "",
            "Milionário e José Rico",
            "Decida / Jogo Do Amor / Tribunal Do Amor",
        ),
    ],
)
def test_artist_title(raw, uploader, artist, title):
    meta = parse_title(raw, uploader)
    assert (meta["artist"], meta["title"]) == (artist, title)


def test_featuring():
    meta = parse_title("Cezar & Paulinho Part. Zé Neto & Cristiano - Tijolada ｜ DVD 40 Anos")
    assert meta["artist"] == "Cezar & Paulinho"
    assert meta["featuring"] == ["Zé Neto & Cristiano"]
    assert not meta["medley"]


def test_featuring_in_brackets():
    meta = parse_title("Renato Teixeira - Quando o amor se vai (part. Pena Branca)")
    assert (meta["artist"], meta["title"]) == ("Renato Teixeira", "Quando o amor se vai")
    assert meta["featuring"] == ["Pena Branca"]


@pytest.mark.parametrize(
    "raw",
    [
        "Chitãozinho & Xororó, Bruna Viola - Caipira ⧸ Majestade O Sabiá",
        "Pot-Pourri： Espinhos da Vida⧸Pedaço de Minha Vida - César Menotti e Fabiano (Memórias Anos 80 e 90)",
        "Milionário e José Rico - Decida - Jogo Do Amor - Tribunal Do Amor - Meu Martírio (ao vivo)",
        "Guilherme & Santiago Pot Pourri A Noite do Nosso Amor Noite Maravilhosa [DVD Tudo Tem Um Porque]",
    ],
)
def test_medley(raw):
    assert parse_title(raw)["medley"]


def test_live():
    assert parse_title("Bruno & Marrone - Dormi na Praça (Ao Vivo)")["live"]
    assert not parse_title("Trio Parada Dura - Passe Livre")["live"]


# --- títulos em inglês (nomes inventados) ---------------------------------------------


@pytest.mark.parametrize(
    "raw, artist, title",
    [
        ("Nova Band - Paper Lanterns (Official Music Video)", "Nova Band", "Paper Lanterns"),
        ("Nova Band - Paper Lanterns | Official Music Video", "Nova Band", "Paper Lanterns"),
        ("Nova Band - Paper Lanterns Official Video", "Nova Band", "Paper Lanterns"),
        ("Nova Band - Paper Lanterns [Lyrics]", "Nova Band", "Paper Lanterns"),
        ("Nova Band - Paper Lanterns (Lyric Video)", "Nova Band", "Paper Lanterns"),
        ("Nova Band - Paper Lanterns - Remastered 2011", "Nova Band", "Paper Lanterns"),
        ("Nova Band - Paper Lanterns (2009 Remaster)", "Nova Band", "Paper Lanterns"),
        ("Nova Band - Paper Lanterns (Visualizer)", "Nova Band", "Paper Lanterns"),
        ("Nova Band - Paper Lanterns HD", "Nova Band", "Paper Lanterns"),
        ("Nova Band - Paper Lanterns (Official Audio)", "Nova Band", "Paper Lanterns"),
        ("Nova Band - Paper Lanterns (Acoustic Version)", "Nova Band", "Paper Lanterns"),
        ("Nova Band - Live Tonight (Official Video)", "Nova Band", "Live Tonight"),
        ("Nova Band - Lyrical Sky", "Nova Band", "Lyrical Sky"),
    ],
)
def test_english_noise(raw, artist, title):
    meta = parse_title(raw)
    assert (meta["artist"], meta["title"]) == (artist, title)


def test_english_featuring():
    meta = parse_title("Nova Band ft. Sol Rivera - Paper Lanterns (Official Audio)")
    assert (meta["artist"], meta["title"], meta["featuring"]) == (
        "Nova Band",
        "Paper Lanterns",
        ["Sol Rivera"],
    )
    meta = parse_title("Nova Band - Paper Lanterns (feat. Sol Rivera) [Official Lyric Video]")
    assert (meta["title"], meta["featuring"]) == ("Paper Lanterns", ["Sol Rivera"])
    meta = parse_title("Nova Band - Paper Lanterns (featuring Sol Rivera)")
    assert meta["featuring"] == ["Sol Rivera"]


@pytest.mark.parametrize(
    "raw, live",
    [
        ("Nova Band - Live Tonight (Official Video)", False),  # "Live" faz parte do título
        ("Nova Band - Paper Lanterns (Live)", True),
        ("Nova Band - Paper Lanterns (Live at River Hall)", True),
        ("Nova Band - Paper Lanterns - Live", True),
        ("Nova Band - Paper Lanterns Live from Lisbon", True),
        ("Dupla Tal - Estrada (Ao Vivo)", True),
    ],
)
def test_live_detection(raw, live):
    assert parse_title(raw)["live"] is live


@pytest.mark.parametrize(
    "raw, uploader, artist, title",
    [
        # canal sem espaço: "Música (Clipe Oficial) - Artista" continua certo
        ("Canção Azul (Clipe Oficial) - Cantora Exemplo", "CANTORAEXEMPLO", "Cantora Exemplo", "Canção Azul"),
        ("Canção Azul - Cantora Exemplo", "CantoraExemploVEVO", "Cantora Exemplo", "Canção Azul"),
        ("Cantora Exemplo - Canção Azul", "Cantora Exemplo Oficial", "Cantora Exemplo", "Canção Azul"),
        # canal que não tem a ver com os nomes não decide nada
        ("Cantora Exemplo - Canção Azul", "Gravadora X", "Cantora Exemplo", "Canção Azul"),
    ],
)
def test_uploader_matching_ignores_spaces(raw, uploader, artist, title):
    meta = parse_title(raw, uploader)
    assert (meta["artist"], meta["title"]) == (artist, title)


def test_youtube_music_description():
    # Faixa "Topic" do YouTube Music: TIT2 só com a música, TPE1 com artista + gravadora.
    desc = (
        "Provided to YouTube by WM Brazil\n\nChora peito · Chrystian & Ralf · Continental\n\n"
        "Chrystian & Ralf (Vol. 4)\n\n℗ 1986 Warner Music Brasil Ltda.\n\nAuto-generated by YouTube."
    )
    assert parse_youtube_music(desc) == {"title": "Chora peito", "artist": "Chrystian & Ralf"}
    assert parse_youtube_music("10 Gaúcho De Passo Fundo (Teixeirinha|1960)\n\nFaixa do LP") is None
    assert parse_youtube_music("Provided to YouTube by X\n\nsó o título") is None
    assert parse_youtube_music("") is None
