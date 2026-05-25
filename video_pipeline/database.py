"""Phase 2 – SQLite state tracking for the pipeline."""
import json
import sqlite3
import logging
from datetime import datetime
from pathlib import Path
from enum import Enum

logger = logging.getLogger(__name__)


class VideoStatus(str, Enum):
    PENDING = "pending"
    GENERATING = "generating"
    GENERATED = "generated"
    PROCESSING = "processing"
    PROCESSED = "processed"
    POSTING = "posting"
    POSTED = "posted"
    FAILED = "failed"


class Database:
    def __init__(self, db_path: Path):
        self.path = db_path
        self.conn = sqlite3.connect(str(db_path), check_same_thread=False)
        self.conn.row_factory = sqlite3.Row
        self._migrate()

    def _migrate(self) -> None:
        self.conn.executescript("""
            CREATE TABLE IF NOT EXISTS videos (
                id          INTEGER PRIMARY KEY AUTOINCREMENT,
                title       TEXT NOT NULL,
                channel     TEXT,
                concept     TEXT NOT NULL,           -- JSON blob of VideoConcept
                status      TEXT NOT NULL DEFAULT 'pending',
                raw_video   TEXT,                    -- path to AI-generated clip
                final_video TEXT,                    -- path to processed MP4
                tiktok_id   TEXT,
                instagram_id TEXT,
                error       TEXT,
                created_at  TEXT NOT NULL,
                updated_at  TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS run_log (
                id         INTEGER PRIMARY KEY AUTOINCREMENT,
                run_at     TEXT NOT NULL,
                ideas_gen  INTEGER DEFAULT 0,
                videos_gen INTEGER DEFAULT 0,
                posted     INTEGER DEFAULT 0,
                errors     INTEGER DEFAULT 0
            );
        """)
        self.conn.commit()

    # ── Video records ──────────────────────────────────────────────────────────

    def insert_concept(self, concept_dict: dict) -> int:
        now = datetime.utcnow().isoformat()
        cur = self.conn.execute(
            "INSERT INTO videos (title, channel, concept, status, created_at, updated_at) VALUES (?,?,?,?,?,?)",
            (concept_dict["title"], concept_dict.get("channel", ""), json.dumps(concept_dict), VideoStatus.PENDING, now, now),
        )
        self.conn.commit()
        return cur.lastrowid

    def update_status(self, video_id: int, status: VideoStatus, **kwargs) -> None:
        fields = {"status": status, "updated_at": datetime.utcnow().isoformat()}
        fields.update(kwargs)
        set_clause = ", ".join(f"{k}=?" for k in fields)
        self.conn.execute(
            f"UPDATE videos SET {set_clause} WHERE id=?",
            (*fields.values(), video_id),
        )
        self.conn.commit()

    def get_pending(self, status: VideoStatus = VideoStatus.PENDING) -> list[sqlite3.Row]:
        return self.conn.execute(
            "SELECT * FROM videos WHERE status=? ORDER BY created_at ASC", (status,)
        ).fetchall()

    def get_by_id(self, video_id: int) -> sqlite3.Row | None:
        return self.conn.execute("SELECT * FROM videos WHERE id=?", (video_id,)).fetchone()

    # ── Run log ────────────────────────────────────────────────────────────────

    def log_run(self, ideas_gen: int, videos_gen: int, posted: int, errors: int) -> None:
        self.conn.execute(
            "INSERT INTO run_log (run_at, ideas_gen, videos_gen, posted, errors) VALUES (?,?,?,?,?)",
            (datetime.utcnow().isoformat(), ideas_gen, videos_gen, posted, errors),
        )
        self.conn.commit()

    def close(self) -> None:
        self.conn.close()
