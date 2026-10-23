"""Etapas do pipeline, em ordem. Etapa nova = arquivo novo + entrada aqui.

A tabela de etapas da documentação é gerada desta lista (tools/docs_check.py).
"""

from pbq.stages.base import Stage
from pbq.stages.ingest import Ingest

STAGES: list[type[Stage]] = [Ingest]
