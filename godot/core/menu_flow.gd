## O caminho dos menus até a partida (ADR 0022): que tela vem depois de cada uma e para onde o
## "voltar" leva, com 1 ou 2 jogadores. As telas são nomes; o App liga cada nome à sua cena.
##
## 1 jogador:  menu → música → instrumento → partida
## 2 jogadores: menu → modo (Banda ou Duelo) → música → instrumento → partida
class_name MenuFlow
extends RefCounted

const MAIN := "main"
const MODE := "mode"
const SONGS := "songs"
const INSTRUMENTS := "instruments"
const MANAGE := "manage"
const PLAY := "play"
const MODES_2P: Array[String] = ["coop", "versus"]  ## Banda e Duelo (ADR 0017)

var players := 1
var mode := "solo"
## O último modo de 2 jogadores: volta marcado na próxima vez.
var mode_2p := "coop"


## Começa com 1 ou 2 jogadores; devolve a próxima tela.
func start(count: int) -> String:
	players = clampi(count, 1, 2)
	mode = "solo" if players == 1 else mode_2p
	return SONGS if players == 1 else MODE


## Banda ("coop") ou Duelo ("versus"); devolve a próxima tela.
func choose_mode(id: String) -> String:
	if id in MODES_2P:
		mode_2p = id
	mode = mode_2p
	return next(MODE)


func next(screen: String) -> String:
	match screen:
		MODE:
			return SONGS
		SONGS:
			return INSTRUMENTS
		INSTRUMENTS:
			return PLAY
	return MAIN


func back(screen: String) -> String:
	match screen:
		SONGS:
			return MODE if players == 2 else MAIN
		INSTRUMENTS, PLAY:
			return SONGS
	return MAIN
