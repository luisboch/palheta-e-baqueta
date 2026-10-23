"""`pbq watch`: processa em segundo plano as músicas que chegam em data/input.

Laço (a cada `watch.interval` segundos):
  1. Scanner.scan()                 → evento "queued" para músicas novas
  2. pipeline nas músicas pendentes → "progress" durante, "ready" / "failed" no fim,
                                      "queue" com o tamanho da fila
  3. data/queue.json: retrato da fila (pendentes, atual, etapa, fração), para o jogo que
     acabou de abrir mostrar o andamento sem esperar o próximo evento.

- O pendrive não é assunto do worker: o CLI `pbq drive` copia os MP3s para data/input quando
  o usuário pede, e daqui em diante é igual a um MP3 posto em input à mão.
- Lock exclusivo em data/.worker.lock (fcntl.flock) com o PID: um worker por vez, e o jogo
  sabe a quem mandar SIGSTOP/SIGCONT durante a partida.
- Prioridade baixa (os.nice) e threads do torch limitadas, para o jogo continuar fluido.
- Fila vazia: descarta as etapas (e os modelos carregados).
- Música com etapa obrigatória falhando não é tentada de novo até o worker reiniciar.
"""

from __future__ import annotations

import fcntl
import logging
import os
import time
from collections.abc import Callable
from typing import IO, Any

from pbq import events
from pbq.config import Config
from pbq.fsutil import write_json
from pbq.library import write_index
from pbq.manifest import Song, now
from pbq.pipeline import DONE, FAILED, process_song
from pbq.scan import Scanner
from pbq.stages import STAGES
from pbq.stages.base import Stage

log = logging.getLogger(__name__)

LOCK = ".worker.lock"
EVENTS = "events.jsonl"
QUEUE = "queue.json"
PROGRESS_INTERVAL = 1.0  # segundos entre eventos "progress": o suficiente para uma barra fluida


class Worker:
    def __init__(
        self,
        config: Config,
        stage_classes: list[type[Stage]] | None = None,
        clock: Callable[[], float] = time.monotonic,
    ):
        self.config = config
        self.opts = config.section("watch")
        self.stage_classes = stage_classes or STAGES
        self.events_path = config.paths.state / EVENTS
        self.queue_path = config.paths.state / QUEUE
        self.scanner = Scanner(config)
        self.clock = clock
        self._stages: list[Stage] | None = None
        self._announced: set[str] = set()
        self._failed: set[str] = set()
        self._lock: IO[str] | None = None
        self._last_progress = float("-inf")

    def run_forever(self) -> None:
        if not self.acquire_lock():
            log.error("já existe um worker rodando (%s)", self.config.paths.state / LOCK)
            return
        os.nice(self.opts.get("nice", 19))
        if threads := self.opts.get("torch_threads"):
            # Lido pelo torch quando ele é importado (só dentro das etapas).
            os.environ.setdefault("OMP_NUM_THREADS", str(threads))
        events.rotate(self.events_path)

        interval = self.opts.get("interval", 5)
        log.info("worker: observando %s a cada %ss", self.config.paths.input, interval)
        while True:
            self.run_once()
            time.sleep(interval)

    def acquire_lock(self) -> bool:
        path = self.config.paths.state / LOCK
        path.parent.mkdir(parents=True, exist_ok=True)
        f = path.open("a+")  # "w" esvaziaria o PID do worker que já tem o lock
        try:
            fcntl.flock(f, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            f.close()
            return False
        f.truncate(0)
        f.write(str(os.getpid()))
        f.flush()
        self._lock = f  # mantém aberto: o lock dura enquanto o processo viver
        return True

    def run_once(self) -> int:
        """Uma volta do laço; retorna quantas músicas ficaram prontas."""
        songs = self.scanner.scan()
        pending = [s for s in songs if s.id not in self._failed and not self._complete(s)]
        for song in pending:
            if song.id not in self._announced:
                self._announced.add(song.id)
                self.emit("queued", id=song.id, label=song.label)
        if not pending:
            self._stages = None  # fila vazia: libera os modelos
            self.write_queue([], None)
            return 0

        ready = 0
        for i, song in enumerate(pending):
            self.emit("queue", pending=len(pending) - i)
            current = {"id": song.id, "label": song.label, "stage": None, "fraction": 0.0}
            self.write_queue(pending[i:], current)
            log.info("== %s [%s]", song.label, song.id)
            result = process_song(song, self.stages(), progress=self._reporter(song, pending[i:]))
            if result == DONE:
                ready += 1
                write_index(self.config)
                self.emit("ready", id=song.id, label=song.label)
            elif result == FAILED:
                self._failed.add(song.id)
                stage = next(
                    s
                    for s in self.stages()
                    if s.required and song.stages.get(s.name, {}).get("status") == "failed"
                )
                self.emit(
                    "failed",
                    id=song.id,
                    label=song.label,
                    stage=stage.name,
                    error=song.stages[stage.name].get("error"),
                )
        self.emit("queue", pending=0)
        self.write_queue([], None)
        return ready

    def stages(self) -> list[Stage]:
        if self._stages is None:
            self._stages = [cls(self.config) for cls in self.stage_classes]
        return self._stages

    def emit(self, type: str, **data: Any) -> None:
        events.emit(self.events_path, type, **data)

    def write_queue(self, pending: list[Song], current: dict[str, Any] | None) -> None:
        write_json(
            self.queue_path,
            {
                "updated": now(),
                "pending": [{"id": s.id, "label": s.label} for s in pending],
                "current": current,
            },
        )

    def _reporter(self, song: Song, pending: list[Song]) -> Callable[[str, float], None]:
        """Andamento da música → evento "progress" + queue.json, no máximo 1 por PROGRESS_INTERVAL.

        Início e fim de etapa sempre passam: a etapa atual muda na tela na hora.
        """

        def report(stage: str, fraction: float) -> None:
            t = self.clock()
            if fraction not in (0.0, 1.0) and t - self._last_progress < PROGRESS_INTERVAL:
                return
            self._last_progress = t
            fraction = round(fraction, 3)
            self.emit("progress", id=song.id, label=song.label, stage=stage, fraction=fraction)
            self.write_queue(
                pending, {"id": song.id, "label": song.label, "stage": stage, "fraction": fraction}
            )

        return report

    def _complete(self, song: Song) -> bool:
        # Todas as etapas, não só a última: uma etapa pode deixar de estar "feita" sozinha (ex.:
        # batidas da reserva quando o beat_this volta), e o pipeline refaz ela e as seguintes.
        return all(stage.is_done(song) for stage in self.stages())
