"""Phase 2 – Generate video clips via Kling AI or Runway ML."""
import logging
import time
from pathlib import Path

import jwt
import requests
from tenacity import retry, stop_after_attempt, wait_exponential, before_sleep_log

from config import Config
from generators.idea_generator import VideoConcept

logger = logging.getLogger(__name__)

KLING_BASE = "https://api.klingai.com"
RUNWAY_BASE = "https://api.dev.runwayml.com/v1"

# Poll interval and max wait for async video generation APIs
POLL_INTERVAL = 10   # seconds
MAX_WAIT = 600       # 10 minutes


class VideoGenerator:
    def __init__(self, cfg: Config):
        self.cfg = cfg
        self.provider = cfg.VIDEO_PROVIDER.lower()

    def generate(self, concept: VideoConcept, out_dir: Path) -> Path:
        """Generate a raw video clip from the concept's scene_description.
        Returns the local path to the downloaded .mp4 file."""
        out_dir.mkdir(parents=True, exist_ok=True)
        slug = concept.title[:40].replace(" ", "_").lower()
        out_path = out_dir / f"{slug}_raw.mp4"

        if self.cfg.DRY_RUN:
            logger.info("[DRY RUN] Skipping video generation for '%s'", concept.title)
            self._write_placeholder(out_path)
            return out_path

        if self.provider == "kling":
            url = self._generate_kling(concept)
        elif self.provider == "runway":
            url = self._generate_runway(concept)
        else:
            raise ValueError(f"Unknown VIDEO_PROVIDER: {self.provider!r}")

        self._download(url, out_path)
        logger.info("Raw video saved → %s", out_path)
        return out_path

    # ── Kling AI ───────────────────────────────────────────────────────────────

    def _kling_token(self) -> str:
        payload = {
            "iss": self.cfg.KLING_API_KEY,
            "exp": int(time.time()) + 1800,
            "nbf": int(time.time()) - 5,
        }
        return jwt.encode(payload, self.cfg.KLING_API_SECRET, algorithm="HS256")

    @retry(stop=stop_after_attempt(4), wait=wait_exponential(multiplier=2, min=4, max=30),
           before_sleep=before_sleep_log(logger, logging.WARNING))
    def _generate_kling(self, concept: VideoConcept) -> str:
        headers = {
            "Authorization": f"Bearer {self._kling_token()}",
            "Content-Type": "application/json",
        }
        payload = {
            "model_name": "kling-v2-6",
            "prompt": concept.scene_description,
            "negative_prompt": "blurry, low quality, text, watermark, realistic photography",
            "cfg_scale": 0.5,
            "mode": "std",
            "aspect_ratio": "9:16",
            "duration": str(min(self.cfg.VIDEO_DURATION, 10)),  # Kling max 10s on std
        }
        logger.info("Submitting Kling task for '%s'…", concept.title)
        resp = requests.post(f"{KLING_BASE}/v1/videos/text2video", json=payload, headers=headers, timeout=30)
        resp.raise_for_status()
        task_id = resp.json()["data"]["task_id"]
        logger.info("Kling task_id: %s — polling…", task_id)
        return self._poll_kling(task_id, headers)

    def _poll_kling(self, task_id: str, headers: dict) -> str:
        deadline = time.time() + MAX_WAIT
        while time.time() < deadline:
            resp = requests.get(f"{KLING_BASE}/v1/videos/text2video/{task_id}", headers=headers, timeout=20)
            resp.raise_for_status()
            data = resp.json()["data"]
            status = data.get("task_status", "")
            logger.debug("Kling status: %s", status)
            if status == "succeed":
                works = data.get("task_result", {}).get("videos", [])
                if works:
                    return works[0]["url"]
                raise RuntimeError("Kling succeeded but returned no video URLs")
            if status == "failed":
                raise RuntimeError(f"Kling task failed: {data.get('task_status_msg', 'unknown')}")
            time.sleep(POLL_INTERVAL)
        raise TimeoutError(f"Kling task {task_id} did not complete within {MAX_WAIT}s")

    # ── Runway ML ─────────────────────────────────────────────────────────────

    @retry(stop=stop_after_attempt(4), wait=wait_exponential(multiplier=2, min=4, max=30),
           before_sleep=before_sleep_log(logger, logging.WARNING))
    def _generate_runway(self, concept: VideoConcept) -> str:
        headers = {
            "Authorization": f"Bearer {self.cfg.RUNWAY_API_KEY}",
            "Content-Type": "application/json",
            "X-Runway-Version": "2024-11-06",
        }
        payload = {
            "model": "gen4_turbo",
            "promptText": concept.scene_description,
            "ratio": "768:1280",  # 9:16 portrait
            "duration": min(self.cfg.VIDEO_DURATION, 10),
        }
        logger.info("Submitting Runway task for '%s'…", concept.title)
        resp = requests.post(f"{RUNWAY_BASE}/text_to_video", json=payload, headers=headers, timeout=30)
        resp.raise_for_status()
        task_id = resp.json()["id"]
        logger.info("Runway task_id: %s — polling…", task_id)
        return self._poll_runway(task_id, headers)

    def _poll_runway(self, task_id: str, headers: dict) -> str:
        deadline = time.time() + MAX_WAIT
        while time.time() < deadline:
            resp = requests.get(f"{RUNWAY_BASE}/tasks/{task_id}", headers=headers, timeout=20)
            resp.raise_for_status()
            task = resp.json()
            status = task.get("status", "")
            logger.debug("Runway status: %s", status)
            if status == "SUCCEEDED":
                outputs = task.get("output", [])
                if outputs:
                    return outputs[0]
                raise RuntimeError("Runway succeeded but returned no output URLs")
            if status == "FAILED":
                raise RuntimeError(f"Runway task failed: {task.get('failure', 'unknown')}")
            time.sleep(POLL_INTERVAL)
        raise TimeoutError(f"Runway task {task_id} did not complete within {MAX_WAIT}s")

    # ── Helpers ────────────────────────────────────────────────────────────────

    @staticmethod
    def _download(url: str, dest: Path) -> None:
        logger.info("Downloading video from %s…", url[:80])
        with requests.get(url, stream=True, timeout=120) as r:
            r.raise_for_status()
            with open(dest, "wb") as f:
                for chunk in r.iter_content(chunk_size=1 << 20):
                    f.write(chunk)

    @staticmethod
    def _write_placeholder(path: Path) -> None:
        """Create a minimal placeholder so downstream processing can run."""
        path.write_bytes(b"")
