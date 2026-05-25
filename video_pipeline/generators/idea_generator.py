"""Phase 1 – Generate 10 absurdist video concepts via Claude."""
import json
import logging
import re
from dataclasses import dataclass, field

import anthropic

from config import Config

logger = logging.getLogger(__name__)

SYSTEM_PROMPT = """You are the head writer for INTERDIMENSIONAL CABLE TV — a surreal, lo-fi broadcast network
that exists between dimensions. Your shows air on channels with names like "CH 47 ◉ PLUTONIAN HOME SHOPPING"
and appeal to beings who exist outside normal spacetime.

Think Rick & Morty's interdimensional cable segments: absurdist premises treated with complete seriousness,
trashy production value played straight, mundane concepts taken to cosmic extremes. Examples of tone:
• "Ants in My Eyes Johnson" Electronics: a man who can only feel ants and see pain
• "Ball Fondlers": elite action team, no context given
• "Gazorpazorpfield": a Garfield parody from another dimension

Every concept must feel like it was broadcast in another dimension and accidentally received on Earth.
Maintain internal consistency within each absurd premise. The humor comes from playing it completely straight."""

IDEA_SCHEMA = {
    "title": "string — fake show/segment name (ALL CAPS, punchy)",
    "channel": "string — e.g. 'CH 47 ◉ ZORBAX FAMILY NETWORK'",
    "hook": "string — exactly what happens in the first 3 seconds (the visual grab)",
    "scene_description": "string — detailed visual prompt for AI video generation, 2-3 sentences, highly specific",
    "voiceover_script": "string — 40-60 words of actual narration/dialogue, written as if read by a bored TV announcer or alien",
    "caption_text": "string — bold on-screen text overlay (like breaking news chyron), max 8 words",
    "hashtags": "array of 6-8 strings including mix of niche (#WeirdTikTok) and broad (#fyp) tags",
    "audio_vibe": "string — describe the music/sound design in one sentence"
}


@dataclass
class VideoConcept:
    title: str
    channel: str
    hook: str
    scene_description: str
    voiceover_script: str
    caption_text: str
    hashtags: list[str]
    audio_vibe: str
    raw: dict = field(default_factory=dict)

    @classmethod
    def from_dict(cls, d: dict) -> "VideoConcept":
        return cls(
            title=d.get("title", "UNTITLED BROADCAST"),
            channel=d.get("channel", "CH 00 ◉ UNKNOWN SIGNAL"),
            hook=d.get("hook", ""),
            scene_description=d.get("scene_description", ""),
            voiceover_script=d.get("voiceover_script", ""),
            caption_text=d.get("caption_text", ""),
            hashtags=d.get("hashtags", ["#fyp", "#WeirdTikTok"]),
            audio_vibe=d.get("audio_vibe", "ambient static"),
            raw=d,
        )

    def to_dict(self) -> dict:
        return {
            "title": self.title,
            "channel": self.channel,
            "hook": self.hook,
            "scene_description": self.scene_description,
            "voiceover_script": self.voiceover_script,
            "caption_text": self.caption_text,
            "hashtags": self.hashtags,
            "audio_vibe": self.audio_vibe,
        }


class IdeaGenerator:
    def __init__(self, cfg: Config):
        self.cfg = cfg
        self.client = anthropic.Anthropic(api_key=cfg.ANTHROPIC_API_KEY)

    def generate(self, count: int = 10) -> list[VideoConcept]:
        """Generate `count` video concepts. Returns list of VideoConcept objects."""
        if self.cfg.DRY_RUN:
            logger.info("[DRY RUN] Returning stub concepts")
            return [self._stub_concept(i) for i in range(count)]

        logger.info("Generating %d video concepts via Claude (%s)…", count, self.cfg.CLAUDE_MODEL)

        user_prompt = f"""Generate exactly {count} interdimensional cable TV video concepts.

Return ONLY a valid JSON array — no markdown, no commentary, just the raw JSON.
Each element must have ALL of these keys:
{json.dumps(IDEA_SCHEMA, indent=2)}

Make each concept wildly different from the others. Range from cosmic horror to absurdist comedy to
fake infomercials to alien nature documentaries. Keep it surreal but internally consistent."""

        response = self.client.messages.create(
            model=self.cfg.CLAUDE_MODEL,
            max_tokens=4096,
            system=[
                {
                    "type": "text",
                    "text": SYSTEM_PROMPT,
                    # Cache the large static system prompt — saves tokens on repeated runs
                    "cache_control": {"type": "ephemeral"},
                }
            ],
            messages=[{"role": "user", "content": user_prompt}],
        )

        raw_text = response.content[0].text.strip()
        concepts = self._parse_response(raw_text, count)
        logger.info("Generated %d concepts", len(concepts))
        return concepts

    def _parse_response(self, text: str, expected: int) -> list[VideoConcept]:
        # Strip any accidental markdown fences
        text = re.sub(r"^```(?:json)?\s*", "", text, flags=re.MULTILINE)
        text = re.sub(r"\s*```$", "", text, flags=re.MULTILINE)

        try:
            data = json.loads(text)
        except json.JSONDecodeError as exc:
            logger.error("Failed to parse Claude response as JSON: %s", exc)
            logger.debug("Raw response: %s", text[:500])
            raise

        if not isinstance(data, list):
            raise ValueError(f"Expected JSON array, got {type(data).__name__}")

        concepts = [VideoConcept.from_dict(item) for item in data[:expected]]
        return concepts

    @staticmethod
    def _stub_concept(index: int) -> VideoConcept:
        stubs = [
            {
                "title": "SNACK THAT ATE TUESDAY",
                "channel": "CH 47 ◉ ZORBAX FAMILY NETWORK",
                "hook": "A giant sentient Dorito adjusts its tie at a press podium",
                "scene_description": "VHS-quality footage of a 7-foot triangular corn chip in a grey business suit standing at a UN-style podium. Alien reporters flash cameras. Neon green 'LIVE' bug in corner. Retro scan lines.",
                "voiceover_script": "For too long, the snack community has been silenced. Today that changes. I am Chip Bravado, and I am running for Galactic Senate on a platform of crunch equality and seasonal flavor recognition. The triangle has spoken.",
                "caption_text": "LOCAL CHIP ENTERS POLITICS",
                "hashtags": ["#InterdimensionalTV", "#WeirdTikTok", "#SurrealHumor", "#fyp"],
                "audio_vibe": "Dramatic news theme with static interference",
            }
        ]
        data = stubs[index % len(stubs)].copy()
        data["title"] = f"{data['title']} #{index + 1}"
        return VideoConcept.from_dict(data)
