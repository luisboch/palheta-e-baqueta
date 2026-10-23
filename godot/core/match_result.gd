## Placar de 2 jogadores: Banda (coop) e Duelo (batalha). Regras no ADR 0017.
##
## Banda: os pontos somam (cada um com o próprio multiplicador, como no solo); o multiplicador da
## Banda é a média dos dois, arredondada para baixo; as estrelas saem da precisão da Banda.
## Duelo: vence quem fizer mais pontos; pontos iguais, empate.
class_name MatchResult
extends RefCounted

## Precisão mínima da Banda para 2, 3, 4 e 5 estrelas (abaixo da primeira, 1 estrela).
const STAR_THRESHOLDS := [0.65, 0.78, 0.88, 0.95]
const MAX_STARS := 5
const TIE := 0  ## leader()/winner(): ninguém na frente


static func band_score(p1: Scoring, p2: Scoring) -> int:
	return p1.score + p2.score


## Média dos multiplicadores, para baixo: a Banda só chega a 4× com os dois em 4×.
static func band_multiplier(p1: Scoring, p2: Scoring) -> int:
	return (p1.multiplier() + p2.multiplier()) / 2


## Notas acertadas pela Banda sobre as tocadas (0-1); sem notas tocadas ainda, 1.
static func band_accuracy(p1: Scoring, p2: Scoring) -> float:
	var total := p1.hits + p1.misses + p2.hits + p2.misses
	return float(p1.hits + p2.hits) / total if total else 1.0


## 1 a 5 estrelas pela precisão (0-1).
static func stars(accuracy: float) -> int:
	var out := 1
	for threshold: float in STAR_THRESHOLDS:
		if accuracy >= threshold:
			out += 1
	return out


## Fração dos pontos da Banda feita por cada um ([p1, p2], soma 1); sem pontos, metade cada.
static func contributions(p1: Scoring, p2: Scoring) -> Array[float]:
	var total := band_score(p1, p2)
	if total == 0:
		return [0.5, 0.5]
	return [float(p1.score) / total, float(p2.score) / total]


## Quem está na frente no Duelo: 1, 2 ou TIE.
static func leader(p1: Scoring, p2: Scoring) -> int:
	if p1.score > p2.score:
		return 1
	if p2.score > p1.score:
		return 2
	return TIE


## Vencedor do Duelo ao fim da música (mesma regra da liderança): 1, 2 ou TIE.
static func winner(p1: Scoring, p2: Scoring) -> int:
	return leader(p1, p2)
