"""Phase 3 – Post-production via FFmpeg.

Adds:
  • SRT subtitles from voiceover script
  • Channel-flip transition between scenes
  • TV static / VHS noise overlay
  • Channel bug (top-left corner)
  • Background audio track
  • Letterbox/pad to 9:16 (1080×1920)
  • Final 15-second vertical MP4
"""
import logging
import math
import re
import subprocess
import tempfile
from pathlib import Path

from generators.idea_generator import VideoConcept
from config import Config

logger = logging.getLogger(__name__)

# Target dimensions for TikTok / Instagram Reels
TARGET_W = 1080
TARGET_H = 1920

# SRT caption chunk size (words per subtitle card)
WORDS_PER_CARD = 6


class MediaProcessor:
    def __init__(self, cfg: Config):
        self.cfg = cfg
        self.assets = cfg.ASSETS_DIR

    def process(self, raw_video: Path, concept: VideoConcept, out_dir: Path) -> Path:
        """Full post-production pipeline. Returns path to finished MP4."""
        out_dir.mkdir(parents=True, exist_ok=True)
        slug = concept.title[:40].replace(" ", "_").lower()
        out_path = out_dir / f"{slug}_final.mp4"

        if self.cfg.DRY_RUN:
            logger.info("[DRY RUN] Skipping FFmpeg processing for '%s'", concept.title)
            out_path.write_bytes(b"")
            return out_path

        srt_path = out_dir / f"{slug}.srt"
        self._write_srt(concept.voiceover_script, srt_path, self.cfg.VIDEO_DURATION)

        audio_track = self._pick_audio(concept.audio_vibe)
        self._run_ffmpeg(raw_video, srt_path, audio_track, concept, out_path)
        logger.info("Processed video → %s", out_path)
        return out_path

    # ── SRT generation ─────────────────────────────────────────────────────────

    @staticmethod
    def _write_srt(script: str, srt_path: Path, duration: float) -> None:
        words = script.split()
        chunks: list[list[str]] = []
        for i in range(0, len(words), WORDS_PER_CARD):
            chunks.append(words[i : i + WORDS_PER_CARD])

        seconds_per_chunk = duration / max(len(chunks), 1)
        lines = []
        for idx, chunk in enumerate(chunks):
            start = idx * seconds_per_chunk
            end = min((idx + 1) * seconds_per_chunk, duration)
            lines.append(str(idx + 1))
            lines.append(f"{_fmt_srt_ts(start)} --> {_fmt_srt_ts(end)}")
            lines.append(" ".join(chunk))
            lines.append("")

        srt_path.write_text("\n".join(lines), encoding="utf-8")
        logger.debug("SRT written → %s (%d cards)", srt_path, len(chunks))

    # ── Audio selection ────────────────────────────────────────────────────────

    def _pick_audio(self, vibe: str) -> Path | None:
        audio_dir = self.assets / "audio"
        if not audio_dir.exists():
            return None
        tracks = list(audio_dir.glob("*.mp3")) + list(audio_dir.glob("*.wav")) + list(audio_dir.glob("*.aac"))
        if not tracks:
            return None
        # Naive keyword matching — extend as needed
        vibe_lower = vibe.lower()
        for track in tracks:
            name = track.stem.lower()
            if any(kw in vibe_lower for kw in ["news", "drama", "serious"]) and "news" in name:
                return track
            if any(kw in vibe_lower for kw in ["ambient", "static", "noise"]) and "static" in name:
                return track
        return tracks[0]  # fallback to first available

    # ── FFmpeg pipeline ────────────────────────────────────────────────────────

    def _run_ffmpeg(
        self,
        raw: Path,
        srt: Path,
        audio: Path | None,
        concept: VideoConcept,
        out: Path,
    ) -> None:
        channel_text = concept.channel.replace("'", "\\'").replace(":", "\\:")
        caption_text = concept.caption_text.replace("'", "\\'").replace(":", "\\:")
        duration = self.cfg.VIDEO_DURATION

        # Build filter_complex step by step
        # 1. Scale & pad input to 9:16
        vf_parts = [
            f"scale={TARGET_W}:{TARGET_H}:force_original_aspect_ratio=decrease,"
            f"pad={TARGET_W}:{TARGET_H}:(ow-iw)/2:(oh-ih)/2:black,"
            f"setsar=1",
        ]

        # 2. Channel-flip transition — white flash at t=0.5s (simulates channel change)
        vf_parts.append(
            "geq=r='if(between(t,0.4,0.6),255,r(X,Y))':"
            "g='if(between(t,0.4,0.6),255,g(X,Y))':"
            "b='if(between(t,0.4,0.6),255,b(X,Y))'"
        )

        # 3. VHS scan-line / noise overlay
        vf_parts.append(
            "noise=alls=8:allf=t+u,"  # temporal + uniform noise
            "curves=vintage"          # retro colour grade
        )

        # 4. Channel bug (top-left)
        vf_parts.append(
            f"drawtext=text='{channel_text}':fontsize=28:fontcolor=white@0.85:"
            f"x=20:y=20:box=1:boxcolor=black@0.5:boxborderw=6:font=Mono"
        )

        # 5. Breaking-news chyron (bottom)
        vf_parts.append(
            f"drawtext=text='{caption_text}':fontsize=42:fontcolor=white:"
            f"x=(w-text_w)/2:y=h-100:box=1:boxcolor=red@0.9:boxborderw=10:"
            f"font=Sans:fontweight=bold"
        )

        # 6. Subtitles (SRT) — positioned in lower-middle
        escaped_srt = str(srt).replace("\\", "/").replace(":", "\\:")
        vf_parts.append(
            f"subtitles='{escaped_srt}':force_style='FontName=Sans,FontSize=22,"
            f"PrimaryColour=&H00FFFFFF,OutlineColour=&H00000000,Outline=2,"
            f"Alignment=2,MarginV=140'"
        )

        vf = ",".join(vf_parts)

        cmd: list[str] = [
            "ffmpeg", "-y",
            "-i", str(raw),
        ]

        # Audio input
        if audio:
            cmd += ["-i", str(audio)]
            audio_filter = (
                f"[1:a]volume=0.3,atrim=0:{duration},asetpts=PTS-STARTPTS[bg];"
                "[0:a]volume=1.0[src];"
                "[src][bg]amix=inputs=2:duration=first[aout]"
            )
            cmd += [
                "-filter_complex", audio_filter,
                "-map", "0:v",
                "-map", "[aout]",
            ]
        else:
            # If raw clip has audio, keep it; otherwise add silence
            cmd += [
                "-f", "lavfi", "-i", f"anullsrc=r=44100:cl=stereo:d={duration}",
                "-map", "0:v",
                "-map", "2:a",
            ]

        cmd += [
            "-vf", vf,
            "-t", str(duration),
            "-c:v", "libx264",
            "-preset", "fast",
            "-crf", "23",
            "-c:a", "aac",
            "-b:a", "192k",
            "-movflags", "+faststart",
            "-pix_fmt", "yuv420p",
            str(out),
        ]

        logger.debug("FFmpeg cmd: %s", " ".join(cmd))
        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode != 0:
            logger.error("FFmpeg stderr:\n%s", result.stderr[-2000:])
            raise RuntimeError(f"FFmpeg failed (code {result.returncode})")


# ── Helpers ────────────────────────────────────────────────────────────────────

def _fmt_srt_ts(seconds: float) -> str:
    h = int(seconds // 3600)
    m = int((seconds % 3600) // 60)
    s = int(seconds % 60)
    ms = int(round((seconds - math.floor(seconds)) * 1000))
    return f"{h:02d}:{m:02d}:{s:02d},{ms:03d}"
