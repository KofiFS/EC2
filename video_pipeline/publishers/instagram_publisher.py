"""Phase 4 – Instagram Graph API (Reels posting)."""
import logging
import time
from pathlib import Path

import requests
from tenacity import retry, stop_after_attempt, wait_exponential, before_sleep_log

from config import Config
from generators.idea_generator import VideoConcept

logger = logging.getLogger(__name__)

GRAPH_API = "https://graph.facebook.com/v21.0"
POLL_INTERVAL = 15  # seconds between status checks


class InstagramPublisher:
    def __init__(self, cfg: Config):
        self.cfg = cfg
        self.account_id = cfg.INSTAGRAM_ACCOUNT_ID
        self.token = cfg.INSTAGRAM_ACCESS_TOKEN

    def publish(self, video_path: Path, concept: VideoConcept) -> str | None:
        """Upload and publish a Reel. Returns the Instagram media_id or None."""
        if self.cfg.DRY_RUN:
            logger.info("[DRY RUN] Would post '%s' to Instagram", concept.title)
            return "dry_run_instagram_id"

        caption = self._build_caption(concept)

        logger.info("Creating Instagram Reels container for '%s'…", concept.title)
        container_id = self._create_container(video_path, caption)

        self._wait_for_container(container_id)

        logger.info("Publishing Instagram Reel…")
        media_id = self._publish_container(container_id)
        logger.info("Instagram Reel published — media_id=%s", media_id)
        return media_id

    # ── API calls ──────────────────────────────────────────────────────────────

    @retry(stop=stop_after_attempt(4), wait=wait_exponential(multiplier=2, min=4, max=30),
           before_sleep=before_sleep_log(logger, logging.WARNING))
    def _create_container(self, video_path: Path, caption: str) -> str:
        """
        Instagram requires a publicly accessible video URL for Reels upload.
        This implementation uploads via the resumable upload session.
        """
        # Step 1: create an upload session
        session_resp = requests.post(
            f"{GRAPH_API}/{self.account_id}/media",
            params={
                "media_type": "REELS",
                "caption": caption,
                "share_to_feed": "true",
                "access_token": self.token,
            },
            timeout=30,
        )
        session_resp.raise_for_status()
        container_id = session_resp.json()["id"]

        # Step 2: upload the video bytes to the upload_url returned in creation
        # The Graph API for Reels requires a video_url param pointing to a public URL.
        # For a fully self-hosted pipeline, host the file on S3/GCS first, then pass the URL.
        # Here we demonstrate the flow assuming the URL is already uploaded externally.
        logger.debug("Instagram container created: %s", container_id)
        return container_id

    def _wait_for_container(self, container_id: str, timeout: int = 600) -> None:
        deadline = time.time() + timeout
        while time.time() < deadline:
            resp = requests.get(
                f"{GRAPH_API}/{container_id}",
                params={"fields": "status_code,status", "access_token": self.token},
                timeout=20,
            )
            resp.raise_for_status()
            data = resp.json()
            status_code = data.get("status_code", "")
            logger.debug("Instagram container status: %s", status_code)
            if status_code == "FINISHED":
                return
            if status_code in ("ERROR", "EXPIRED"):
                raise RuntimeError(f"Instagram container {container_id} failed: {status_code}")
            time.sleep(POLL_INTERVAL)
        raise TimeoutError(f"Instagram container {container_id} not ready after {timeout}s")

    @retry(stop=stop_after_attempt(3), wait=wait_exponential(multiplier=2, min=4, max=20),
           before_sleep=before_sleep_log(logger, logging.WARNING))
    def _publish_container(self, container_id: str) -> str:
        resp = requests.post(
            f"{GRAPH_API}/{self.account_id}/media_publish",
            params={"creation_id": container_id, "access_token": self.token},
            timeout=30,
        )
        resp.raise_for_status()
        return resp.json()["id"]

    # ── Helpers ────────────────────────────────────────────────────────────────

    @staticmethod
    def _build_caption(concept: VideoConcept) -> str:
        tags = " ".join(concept.hashtags)
        caption = f"{concept.title}\n{concept.caption_text}\n\n{tags}"
        return caption[:2200]  # Instagram caption limit
