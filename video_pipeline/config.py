import os
from pathlib import Path
from dotenv import load_dotenv

load_dotenv()

class Config:
    # Anthropic
    ANTHROPIC_API_KEY: str = os.getenv("ANTHROPIC_API_KEY", "")
    CLAUDE_MODEL: str = os.getenv("CLAUDE_MODEL", "claude-opus-4-7")

    # Video generation
    VIDEO_PROVIDER: str = os.getenv("VIDEO_PROVIDER", "kling")
    KLING_API_KEY: str = os.getenv("KLING_API_KEY", "")
    KLING_API_SECRET: str = os.getenv("KLING_API_SECRET", "")
    RUNWAY_API_KEY: str = os.getenv("RUNWAY_API_KEY", "")

    # TikTok
    TIKTOK_ACCESS_TOKEN: str = os.getenv("TIKTOK_ACCESS_TOKEN", "")
    TIKTOK_OPEN_ID: str = os.getenv("TIKTOK_OPEN_ID", "")

    # Instagram
    INSTAGRAM_ACCESS_TOKEN: str = os.getenv("INSTAGRAM_ACCESS_TOKEN", "")
    INSTAGRAM_ACCOUNT_ID: str = os.getenv("INSTAGRAM_ACCOUNT_ID", "")

    # Pipeline
    VIDEO_DURATION: int = int(os.getenv("VIDEO_DURATION", "15"))
    IDEAS_PER_RUN: int = int(os.getenv("IDEAS_PER_RUN", "10"))
    OUTPUT_DIR: Path = Path(os.getenv("OUTPUT_DIR", "output"))
    ASSETS_DIR: Path = Path(os.getenv("ASSETS_DIR", "assets"))
    DB_PATH: Path = Path(os.getenv("DB_PATH", "pipeline.db"))
    DRY_RUN: bool = os.getenv("DRY_RUN", "false").lower() == "true"

    # Scheduler
    POST_TIMES: list[str] = os.getenv("POST_TIMES", "14:00").split(",")
    POSTS_PER_DAY: int = int(os.getenv("POSTS_PER_DAY", "1"))

    def validate(self) -> None:
        errors = []
        if not self.ANTHROPIC_API_KEY:
            errors.append("ANTHROPIC_API_KEY is required")
        if self.VIDEO_PROVIDER == "kling" and not (self.KLING_API_KEY and self.KLING_API_SECRET):
            errors.append("KLING_API_KEY and KLING_API_SECRET are required when VIDEO_PROVIDER=kling")
        if self.VIDEO_PROVIDER == "runway" and not self.RUNWAY_API_KEY:
            errors.append("RUNWAY_API_KEY is required when VIDEO_PROVIDER=runway")
        if errors and not self.DRY_RUN:
            raise EnvironmentError("Config errors:\n" + "\n".join(f"  • {e}" for e in errors))

config = Config()
