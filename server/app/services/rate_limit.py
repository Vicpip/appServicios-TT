"""Límite de peticiones por IP (ventana deslizante, en memoria).

El proyecto no tenía mecanismo de rate limiting. Este es el más simple que
sirve para el endpoint público de ligas: un proceso uvicorn = un contador. Con
varios workers el límite efectivo es por worker (aceptable para este uso).
"""
import threading
import time
from collections import defaultdict, deque


class SlidingWindowLimiter:
    def __init__(self) -> None:
        self._hits: dict[str, deque[float]] = defaultdict(deque)
        self._lock = threading.Lock()

    def allow(self, key: str, limit: int, window_seconds: int) -> bool:
        now = time.monotonic()
        with self._lock:
            hits = self._hits[key]
            while hits and now - hits[0] > window_seconds:
                hits.popleft()
            if len(hits) >= limit:
                return False
            hits.append(now)
            if len(self._hits) > 10_000:  # evita crecer sin límite
                for k in [k for k, v in self._hits.items() if not v]:
                    del self._hits[k]
            return True

    def reset(self) -> None:
        with self._lock:
            self._hits.clear()


public_link_limiter = SlidingWindowLimiter()
