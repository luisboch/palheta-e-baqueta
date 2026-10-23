"""Etapas do pipeline, em ordem. Etapa nova = arquivo novo + entrada aqui.

A tabela de etapas da documentação é gerada desta lista (tools/generators.py).
"""

from pbq.stages.base import Stage
from pbq.stages.beats import Beats
from pbq.stages.chart import ChartFile
from pbq.stages.drums_chart import DrumsChart
from pbq.stages.ingest import Ingest
from pbq.stages.presence import Presence
from pbq.stages.separate import Separate

STAGES: list[type[Stage]] = [Ingest, Separate, Presence, Beats, DrumsChart, ChartFile]
