"""Etapas do pipeline, em ordem. Etapa nova = arquivo novo + entrada aqui.

A tabela de etapas da documentação é gerada desta lista (tools/generators.py).
"""

from pbq.stages.base import Stage
from pbq.stages.guitar_split import GuitarSplit
from pbq.stages.ingest import Ingest
from pbq.stages.presence import Presence
from pbq.stages.separate import Separate

STAGES: list[type[Stage]] = [Ingest, Separate, GuitarSplit, Presence]
