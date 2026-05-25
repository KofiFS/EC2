#!/usr/bin/env python3
"""Interdimensional Cable TV — autonomous short-form video pipeline.

Usage:
  python main.py run       # Run the pipeline once right now
  python main.py schedule  # Start the cron scheduler (blocks)
  python main.py ideas     # Generate and print ideas only (no video)
"""
import json
import logging
import sys
import time
from pathlib import Path

import schedule

from config import config
from database import Database, VideoStatus
from generators.idea_generator import IdeaGenerator, VideoConcept
from generators.video_generator import VideoGenerator
from processors.media_processor import MediaProcessor
from publishers.tiktok_publisher import TikTokPublisher
from publishers.instagram_publisher import InstagramPublisher

# ── Logging ────────────────────────────────────────────────────────────────────

def _setup_logging() -> None:
    log_dir = Path("logs")
    log_dir.mkdir(exist_ok=True)
    fmt = "%(asctime)s  %(levelname)-8s  %(name)s  %(message)s"
    logging.basicConfig(
        level=logging.INFO,
        format=fmt,
        handlers=[
            logging.StreamHandler(sys.stdout),
            logging.FileHandler(log_dir / "pipeline.log"),
        ],
    )

logger = logging.getLogger("pipeline")


# ── Pipeline ───────────────────────────────────────────────────────────────────

class VideoPipeline:
    def __init__(self) -> None:
        config.validate()
        self.db = Database(config.DB_PATH)
        self.idea_gen = IdeaGenerator(config)
        self.video_gen = VideoGenerator(config)
        self.processor = MediaProcessor(config)
        self.publishers: list = []
        if config.TIKTOK_ACCESS_TOKEN:
            self.publishers.append(TikTokPublisher(config))
        if config.INSTAGRAM_ACCESS_TOKEN:
            self.publishers.append(InstagramPublisher(config))

    # ── Phase 1 ───────────────────────────────────────────────────────────────

    def generate_ideas(self) -> list[VideoConcept]:
        logger.info("=== Phase 1: Generating %d concepts ===", config.IDEAS_PER_RUN)
        concepts = self.idea_gen.generate(config.IDEAS_PER_RUN)
        for c in concepts:
            vid_id = self.db.insert_concept(c.to_dict())
            logger.info("  [%d] %s / %s", vid_id, c.channel, c.title)
        return concepts

    # ── Phase 2 ───────────────────────────────────────────────────────────────

    def generate_videos(self, concepts: list[VideoConcept]) -> dict[int, Path]:
        logger.info("=== Phase 2: Generating %d video clips ===", len(concepts))
        raw_dir = config.OUTPUT_DIR / "raw"
        results: dict[int, Path] = {}

        pending = self.db.get_pending(VideoStatus.PENDING)
        id_map = {row["title"]: row["id"] for row in pending}

        for concept in concepts:
            vid_id = id_map.get(concept.title)
            if vid_id is None:
                continue
            self.db.update_status(vid_id, VideoStatus.GENERATING)
            try:
                raw_path = self.video_gen.generate(concept, raw_dir)
                self.db.update_status(vid_id, VideoStatus.GENERATED, raw_video=str(raw_path))
                results[vid_id] = raw_path
                logger.info("  [%d] Raw clip → %s", vid_id, raw_path)
            except Exception as exc:
                logger.error("  [%d] Video generation failed: %s", vid_id, exc)
                self.db.update_status(vid_id, VideoStatus.FAILED, error=str(exc))

        return results

    # ── Phase 3 ───────────────────────────────────────────────────────────────

    def process_videos(
        self, raw_map: dict[int, Path], concepts: list[VideoConcept]
    ) -> dict[int, Path]:
        logger.info("=== Phase 3: Post-production for %d clips ===", len(raw_map))
        final_dir = config.OUTPUT_DIR / "final"
        concept_by_title = {c.title: c for c in concepts}
        results: dict[int, Path] = {}

        for vid_id, raw_path in raw_map.items():
            row = self.db.get_by_id(vid_id)
            if not row:
                continue
            concept_data = json.loads(row["concept"])
            concept = concept_by_title.get(concept_data["title"])
            if concept is None:
                from generators.idea_generator import VideoConcept
                concept = VideoConcept.from_dict(concept_data)

            self.db.update_status(vid_id, VideoStatus.PROCESSING)
            try:
                final_path = self.processor.process(raw_path, concept, final_dir)
                self.db.update_status(vid_id, VideoStatus.PROCESSED, final_video=str(final_path))
                results[vid_id] = final_path
                logger.info("  [%d] Final MP4 → %s", vid_id, final_path)
            except Exception as exc:
                logger.error("  [%d] Processing failed: %s", vid_id, exc)
                self.db.update_status(vid_id, VideoStatus.FAILED, error=str(exc))

        return results

    # ── Phase 4 ───────────────────────────────────────────────────────────────

    def post_videos(
        self, final_map: dict[int, Path], concepts: list[VideoConcept]
    ) -> int:
        posts_made = 0
        limit = config.POSTS_PER_DAY

        logger.info("=== Phase 4: Posting (limit=%d) ===", limit)
        concept_by_title = {c.title: c for c in concepts}

        for vid_id, final_path in list(final_map.items())[:limit]:
            row = self.db.get_by_id(vid_id)
            if not row:
                continue
            concept_data = json.loads(row["concept"])
            concept = concept_by_title.get(concept_data["title"])
            if concept is None:
                from generators.idea_generator import VideoConcept
                concept = VideoConcept.from_dict(concept_data)

            self.db.update_status(vid_id, VideoStatus.POSTING)
            tiktok_id = instagram_id = None
            try:
                for publisher in self.publishers:
                    if isinstance(publisher, TikTokPublisher):
                        tiktok_id = publisher.publish(final_path, concept)
                    elif isinstance(publisher, InstagramPublisher):
                        instagram_id = publisher.publish(final_path, concept)

                self.db.update_status(
                    vid_id, VideoStatus.POSTED,
                    tiktok_id=tiktok_id,
                    instagram_id=instagram_id,
                )
                posts_made += 1
                logger.info(
                    "  [%d] Posted — TikTok=%s  Instagram=%s",
                    vid_id, tiktok_id, instagram_id,
                )
            except Exception as exc:
                logger.error("  [%d] Posting failed: %s", vid_id, exc)
                self.db.update_status(vid_id, VideoStatus.FAILED, error=str(exc))

        return posts_made

    # ── Full run ───────────────────────────────────────────────────────────────

    def run_once(self) -> None:
        logger.info("╔══ PIPELINE RUN STARTING ══╗")
        ideas_gen = videos_gen = posted = errors = 0
        try:
            concepts = self.generate_ideas()
            ideas_gen = len(concepts)

            raw_map = self.generate_videos(concepts)
            videos_gen = len(raw_map)
            errors += ideas_gen - videos_gen

            final_map = self.process_videos(raw_map, concepts)
            errors += videos_gen - len(final_map)

            posted = self.post_videos(final_map, concepts)
        except Exception as exc:
            logger.error("Pipeline run failed: %s", exc, exc_info=True)
            errors += 1
        finally:
            self.db.log_run(ideas_gen, videos_gen, posted, errors)
            logger.info("╚══ DONE — ideas=%d  videos=%d  posted=%d  errors=%d ══╝",
                        ideas_gen, videos_gen, posted, errors)


# ── Scheduler ──────────────────────────────────────────────────────────────────

def run_scheduler(pipeline: VideoPipeline) -> None:
    for t in config.POST_TIMES:
        t = t.strip()
        schedule.every().day.at(t).do(pipeline.run_once)
        logger.info("Scheduled daily run at %s", t)

    logger.info("Scheduler running. Press Ctrl-C to stop.")
    while True:
        schedule.run_pending()
        time.sleep(30)


# ── Entry point ────────────────────────────────────────────────────────────────

def main() -> None:
    _setup_logging()
    cmd = sys.argv[1] if len(sys.argv) > 1 else "run"

    pipeline = VideoPipeline()

    if cmd == "run":
        pipeline.run_once()

    elif cmd == "schedule":
        run_scheduler(pipeline)

    elif cmd == "ideas":
        concepts = pipeline.generate_ideas()
        print(json.dumps([c.to_dict() for c in concepts], indent=2, ensure_ascii=False))

    else:
        print(__doc__)
        sys.exit(1)


if __name__ == "__main__":
    main()
