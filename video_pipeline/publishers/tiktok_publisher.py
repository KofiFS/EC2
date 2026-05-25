"""Phase 4 – TikTok Content Posting API v2."""
import logging
import time
from pathlib import Path

import requests
from tenacity import retry, stop_after_attempt, wait_exponential, before_sleep_log

from config import Config
from generators.idea_generator import VideoConcept

logger = logging.getLogger(__name__)

TIKTOK_API = "https://open.tiktokapis.com/v2"
CHUNK_SIZE = 10 * 1024 * 1024  # 10 MB per chunk


class TikTokPublisher:
    def __init__(self, cfg: Config):
        self.cfg = cfg
        self.headers = {
            "Authorization": f"Bearer {cfg.TIKTOK_ACCESS_TOKEN}",
            "Content-Type": "application/json; charset=UTF-8",
        }

    def publish(self, video_path: Path, concept: VideoConcept) -> str | None:
        """Upload and post the video. Returns the TikTok publish_id or None on dry-run."""
        if self.cfg.DRY_RUN:
            logger.info("[DRY RUN] Would post '%s' to TikTok", concept.title)
            return "dry_run_tiktok_id"

        caption = self._build_caption(concept)
        file_size = video_path.stat().st_size

        logger.info("Initialising TikTok upload for '%s' (%d bytes)…", concept.title, file_size)
        upload_url, publish_id = self._init_upload(file_size, caption)

        self._upload_chunks(video_path, upload_url, file_size)
        status = self._wait_for_publish(publish_id)
        logger.info("TikTok posted — publish_id=%s  status=%s", publish_id, status)
        return publish_id

    # ── API calls ──────────────────────────────────────────────────────────────

    @retry(stop=stop_after_attempt(4), wait=wait_exponential(multiplier=2, min=4, max=30),
           before_sleep=before_sleep_log(logger, logging.WARNING))
    def _init_upload(self, file_size: int, caption: str) -> tuple[str, str]:
        chunk_size = min(CHUNK_SIZE, file_size)
        total_chunks = max(1, -(-file_size // chunk_size))  # ceiling division

        body = {
            "post_info": {
                "title": caption,
                "privacy_level": "SELF_ONLY",  # change to PUBLIC_TO_EVERYONE when ready
                "disable_duet": False,
                "disable_comment": False,
                "disable_stitch": False,
                "video_cover_timestamp_ms": 1000,
            },
            "source_info": {
                "source": "FILE_UPLOAD",
                "video_size": file_size,
                "chunk_size": chunk_size,
                "total_chunk_count": total_chunks,
            },
        }
        resp = requests.post(f"{TIKTOK_API}/post/publish/video/init/", json=body, headers=self.headers, timeout=30)
        resp.raise_for_status()
        data = resp.json()["data"]
        return data["upload_url"], data["publish_id"]

    def _upload_chunks(self, video_path: Path, upload_url: str, file_size: int) -> None:
        chunk_size = min(CHUNK_SIZE, file_size)
        offset = 0
        with open(video_path, "rb") as f:
            chunk_index = 0
            while True:
                chunk = f.read(chunk_size)
                if not chunk:
                    break
                end = offset + len(chunk) - 1
                headers = {
                    "Content-Type": "video/mp4",
                    "Content-Range": f"bytes {offset}-{end}/{file_size}",
                    "Content-Length": str(len(chunk)),
                }
                resp = requests.put(upload_url, data=chunk, headers=headers, timeout=120)
                resp.raise_for_status()
                logger.debug("TikTok chunk %d uploaded (%d–%d)", chunk_index, offset, end)
                offset += len(chunk)
                chunk_index += 1

    def _wait_for_publish(self, publish_id: str, timeout: int = 300) -> str:
        deadline = time.time() + timeout
        while time.time() < deadline:
            resp = requests.post(
                f"{TIKTOK_API}/post/publish/status/fetch/",
                json={"publish_id": publish_id},
                headers=self.headers,
                timeout=20,
            )
            resp.raise_for_status()
            data = resp.json().get("data", {})
            status = data.get("status", "PROCESSING_UPLOAD")
            logger.debug("TikTok publish status: %s", status)
            if status in ("PUBLISH_COMPLETE",):
                return status
            if "FAIL" in status or "ERROR" in status:
                raise RuntimeError(f"TikTok publish failed: {status}")
            time.sleep(10)
        raise TimeoutError(f"TikTok publish {publish_id} timed out after {timeout}s")

    # ── Helpers ────────────────────────────────────────────────────────────────

    @staticmethod
    def _build_caption(concept: VideoConcept) -> str:
        tags = " ".join(concept.hashtags)
        caption = f"{concept.title} | {concept.channel}\n{tags}"
        return caption[:2200]  # TikTok caption limit
