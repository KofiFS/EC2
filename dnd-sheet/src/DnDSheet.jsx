import { useState, useEffect, useRef, useCallback } from "react";
import { storage } from "./storage.js";

const STORAGE_KEY = "dnd-char-arc-elf";

const INITIAL_CHARACTER = {
  name: "Arc-Elf Tanner",
  class: "Warlock 3 / Lock",
  race: "Orc/Elf",
  background: "Watching",
  proficiencyBonus: 2,
  abilities: {
    strength: 11,
    dexterity: 12,
    constitution: 14,
    intelligence: 12,
    wisdom: 13,
    charisma: 14,
  },
  combat: {
    ac: 12,
    initiative: 1,
    speed: 30,
    hp: 26,
    maxHp: 26,
    tempHp: 0,
    hitDice: "3d6",
  },
  deathSaves: { successes: 0, failures: 0 },
  savingThrows: {
    strength: { prof: false },
    dexterity: { prof: false },
    constitution: { prof: false },
    intelligence: { prof: false },
    wisdom: { prof: true },
    charisma: { prof: true },
  },
  skills: {
    acrobatics: { ability: "dexterity", prof: false },
    animalHandling: { ability: "wisdom", prof: false },
    arcana: { ability: "intelligence", prof: false },
    athletics: { ability: "strength", prof: false },
    deception: { ability: "charisma", prof: true },
    history: { ability: "intelligence", prof: false },
    insight: { ability: "wisdom", prof: true },
    intimidation: { ability: "charisma", prof: true },
    investigation: { ability: "intelligence", prof: true },
    medicine: { ability: "wisdom", prof: false },
    nature: { ability: "intelligence", prof: false },
    perception: { ability: "wisdom", prof: false },
    performance: { ability: "charisma", prof: false },
    persuasion: { ability: "charisma", prof: false },
    religion: { ability: "intelligence", prof: false },
    sleightOfHand: { ability: "dexterity", prof: false },
    stealth: { ability: "dexterity", prof: true },
    survival: { ability: "wisdom", prof: false },
  },
  features: [
    "Agonizing Blast",
    "Mask of Many Faces",
    "Otherworldly Leap",
    "Adrenaline Rush",
    "Darkvision 120ft",
    "Relentless Endurance",
    "Steps of the Fey",
  ],
  equipment: [
    "Snake Staff",
    "Leather Armor",
    "2× Daggers",
    "Thieves' Tools",
    "Bedroll",
    "2× Pouches",
    "101 gp",
    "Traveler's Clothes",
    "Disguise Set",
  ],
  proficiencies: "Thieves' Tools, Simple Weapons, Light Armor",
  spellcasting: {
    ability: "CHA",
    saveDC: 12,
    attackBonus: 4,
  },
  spells: {
    cantrips: ["Minor Illusion", "Thunderclap"],
    level1: ["Charm Person", "Unseen Servant", "Illusory Script", "Sleep", "Faerie Fire"],
    level2: ["Hold Person", "Phantasmal Force", "Mirror Step", "Calm Emotions"],
    level3: [],
    level4: [],
    level5: [],
  },
  notes: "",
};

const SKILL_LABELS = {
  acrobatics: "Acrobatics", animalHandling: "Animal Handling", arcana: "Arcana",
  athletics: "Athletics", deception: "Deception", history: "History",
  insight: "Insight", intimidation: "Intimidation", investigation: "Investigation",
  medicine: "Medicine", nature: "Nature", perception: "Perception",
  performance: "Performance", persuasion: "Persuasion", religion: "Religion",
  sleightOfHand: "Sleight of Hand", stealth: "Stealth", survival: "Survival",
};

const ABILITY_SHORT = { strength: "STR", dexterity: "DEX", constitution: "CON", intelligence: "INT", wisdom: "WIS", charisma: "CHA" };

function getMod(score) {
  return Math.floor((score - 10) / 2);
}
function fmtMod(n) {
  return n >= 0 ? `+${n}` : `${n}`;
}

// rng helper — one place so dice behaviour is easy to reason about
function rollDie(sides) {
  return Math.floor(Math.random() * sides) + 1;
}

// ── Inline editable field ──
function EditField({ value, onChange, style = {}, inputStyle = {}, multiline = false, type = "text" }) {
  const [editing, setEditing] = useState(false);
  const [local, setLocal] = useState(value);

  useEffect(() => { setLocal(value); }, [value]);

  const commit = () => { setEditing(false); onChange(local); };

  if (editing) {
    if (multiline) return (
      <textarea
        autoFocus
        value={local}
        onChange={e => setLocal(e.target.value)}
        onBlur={commit}
        style={{ ...inputStyle, background: "rgba(201,136,42,0.15)", border: "1px solid #c9882a", borderRadius: 4, color: "inherit", fontFamily: "inherit", fontSize: "inherit", padding: "2px 6px", width: "100%", resize: "vertical" }}
      />
    );
    return (
      <input
        autoFocus
        type={type}
        value={local}
        onChange={e => setLocal(type === "number" ? Number(e.target.value) : e.target.value)}
        onBlur={commit}
        onKeyDown={e => e.key === "Enter" && commit()}
        style={{ ...inputStyle, background: "rgba(201,136,42,0.15)", border: "1px solid #c9882a", borderRadius: 4, color: "inherit", fontFamily: "inherit", fontSize: "inherit", padding: "2px 6px", textAlign: style.textAlign || "left", width: "100%" }}
      />
    );
  }
  return (
    <span
      onClick={() => setEditing(true)}
      style={{ cursor: "text", borderBottom: "1px dashed rgba(201,136,42,0.4)", display: "inline-block", ...style }}
      title="Tap to edit"
    >{value}</span>
  );
}

// ── Ability block ──
function AbilityBlock({ name, score, onChange, onRoll }) {
  const mod = getMod(score);
  return (
    <div style={{
      background: "linear-gradient(135deg,#3d1a05,#5c2b0a)",
      border: "1.5px solid #c9882a", borderRadius: 8,
      padding: "8px 10px", textAlign: "center", flex: 1,
      minWidth: 0
    }}>
      <div style={{ fontFamily: "Cinzel,serif", fontSize: "0.5rem", letterSpacing: 2, color: "#c9882a88", textTransform: "uppercase", marginBottom: 2 }}>{name}</div>
      <EditField
        value={score}
        onChange={v => onChange(Number(v))}
        type="number"
        style={{ fontFamily: "'Cinzel Decorative',serif", fontSize: "1.5rem", color: "#e8b84b", textShadow: "0 0 10px rgba(201,136,42,0.5)", textAlign: "center", display: "block", width: "100%" }}
        inputStyle={{ width: "60px", textAlign: "center" }}
      />
      <div
        onClick={() => onRoll(`${name} Check`, mod)}
        title="Tap to roll a d20 check"
        style={{ fontFamily: "Cinzel,serif", fontSize: "0.7rem", color: "#f0d090", background: "rgba(201,136,42,0.2)", borderRadius: 3, padding: "1px 4px", display: "inline-block", marginTop: 2, cursor: "pointer" }}
      >
        🎲 {fmtMod(mod)}
      </div>
    </div>
  );
}

// ── Dice roll result overlay ──
function DiceOverlay({ roll, onClose }) {
  if (!roll) return null;
  const accent = roll.crit ? "#e8b84b" : roll.fail ? "#7a1c1c" : "#c9882a";
  return (
    <div
      onClick={onClose}
      style={{
        position: "fixed", inset: 0, zIndex: 200,
        background: "rgba(10,4,2,0.78)",
        display: "flex", flexDirection: "column",
        alignItems: "center", justifyContent: "center",
        animation: "overlayFade 0.18s ease",
        cursor: "pointer", padding: 24,
      }}
    >
      <div style={{ fontFamily: "Cinzel,serif", fontSize: "0.7rem", letterSpacing: 3, color: "#c9882a", textTransform: "uppercase", marginBottom: 14 }}>
        {roll.label}
      </div>
      <div style={{
        position: "relative",
        width: 132, height: 132,
        clipPath: "polygon(50% 0%, 100% 38%, 82% 100%, 18% 100%, 0% 38%)",
        background: `radial-gradient(circle at 38% 30%, ${roll.crit ? "#5c3a0a" : "#3d1a05"}, #1a0a02)`,
        border: `2px solid ${accent}`,
        display: "flex", alignItems: "center", justifyContent: "center",
        animation: `diceTumble 0.5s cubic-bezier(0.18,0.89,0.32,1.28)${roll.crit ? ", critPulse 1.2s ease-in-out 0.5s infinite" : roll.fail ? ", failShake 0.35s ease 0.45s" : ""}`,
        boxShadow: `0 0 34px ${accent}66`,
      }}>
        <span style={{ fontFamily: "'Cinzel Decorative',serif", fontSize: "3.4rem", color: roll.crit ? "#ffe9a8" : roll.fail ? "#e88" : "#e8b84b", textShadow: `0 0 16px ${accent}` }}>
          {roll.d20}
        </span>
      </div>
      <div style={{ fontFamily: "'Cinzel Decorative',serif", fontSize: "2rem", color: "#f0d090", marginTop: 16 }}>
        {roll.total}
      </div>
      <div style={{ fontFamily: "Cinzel,serif", fontSize: "0.7rem", color: "#8b5e1a", marginTop: 2 }}>
        d20 ({roll.d20}) {roll.mod >= 0 ? "+" : "−"} {Math.abs(roll.mod)}
      </div>
      {roll.crit && <div style={{ fontFamily: "'Cinzel Decorative',serif", fontSize: "1.1rem", color: "#e8b84b", marginTop: 12, letterSpacing: 2 }}>★ CRITICAL ★</div>}
      {roll.fail && <div style={{ fontFamily: "'Cinzel Decorative',serif", fontSize: "1.1rem", color: "#c66", marginTop: 12, letterSpacing: 2 }}>✗ FUMBLE ✗</div>}
      <div style={{ fontFamily: "Cinzel,serif", fontSize: "0.55rem", color: "#5c3a0a", marginTop: 22, letterSpacing: 2 }}>TAP ANYWHERE TO DISMISS</div>
    </div>
  );
}

// ── Quick dice tray (raw dice, no modifier) ──
const DICE = [4, 6, 8, 10, 12, 20, 100];
function DiceTray({ onRoll, onClose }) {
  return (
    <div style={{ position: "fixed", inset: 0, zIndex: 150, display: "flex", alignItems: "flex-end", justifyContent: "center" }}>
      <div onClick={onClose} style={{ position: "absolute", inset: 0, background: "rgba(10,4,2,0.5)", animation: "overlayFade 0.18s ease" }} />
      <div style={{
        position: "relative", width: "100%", maxWidth: 480,
        background: "linear-gradient(135deg,#1a0a02,#3d1a05)",
        borderTop: "2px solid #c9882a", borderRadius: "16px 16px 0 0",
        padding: "16px 16px 22px", animation: "diceTumble 0.3s ease",
      }}>
        <div style={{ fontFamily: "Cinzel,serif", fontSize: "0.6rem", letterSpacing: 3, color: "#c9882a", textTransform: "uppercase", textAlign: "center", marginBottom: 14 }}>
          Roll the Bones
        </div>
        <div style={{ display: "grid", gridTemplateColumns: "repeat(4,1fr)", gap: 10 }}>
          {DICE.map(d => (
            <button key={d} onClick={() => onRoll(d)} style={{
              fontFamily: "'Cinzel Decorative',serif", fontSize: "1rem", color: "#e8b84b",
              background: "linear-gradient(135deg,#3d1a05,#5c2b0a)", border: "1.5px solid #c9882a",
              borderRadius: 10, padding: "14px 0", cursor: "pointer",
              boxShadow: "0 0 10px rgba(201,136,42,0.2)",
            }}>d{d}</button>
          ))}
          <button onClick={onClose} style={{
            fontFamily: "Cinzel,serif", fontSize: "0.7rem", color: "#8b5e1a",
            background: "transparent", border: "1.5px solid #5c2b0a",
            borderRadius: 10, padding: "14px 0", cursor: "pointer", letterSpacing: 1,
          }}>Close</button>
        </div>
      </div>
    </div>
  );
}

// ── Roll log drawer ──
function RollLog({ log, onClose, onClear }) {
  return (
    <div style={{ position: "fixed", inset: 0, zIndex: 150, display: "flex", justifyContent: "flex-end" }}>
      <div onClick={onClose} style={{ position: "absolute", inset: 0, background: "rgba(10,4,2,0.5)", animation: "overlayFade 0.18s ease" }} />
      <div style={{
        position: "relative", width: "78%", maxWidth: 320, height: "100%",
        background: "linear-gradient(160deg,#1a0a02,#0f0804)",
        borderLeft: "2px solid #c9882a", padding: "16px 14px",
        overflowY: "auto", animation: "overlayFade 0.2s ease",
      }}>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 14 }}>
          <span style={{ fontFamily: "Cinzel,serif", fontSize: "0.6rem", letterSpacing: 3, color: "#c9882a", textTransform: "uppercase" }}>Roll History</span>
          <button onClick={onClear} style={{ fontFamily: "Cinzel,serif", fontSize: "0.5rem", letterSpacing: 1, color: "#8b5e1a", background: "transparent", border: "1px solid #5c2b0a", borderRadius: 4, padding: "3px 8px", cursor: "pointer" }}>CLEAR</button>
        </div>
        {log.length === 0 && (
          <div style={{ fontFamily: "Cinzel,serif", fontSize: "0.65rem", color: "#5c3a0a", textAlign: "center", marginTop: 30 }}>
            No rolls yet.<br />Tap a skill, save, or ability to roll.
          </div>
        )}
        {log.map((r, i) => (
          <div key={i} style={{
            display: "flex", alignItems: "center", gap: 10, padding: "8px 4px",
            borderBottom: "1px dashed rgba(139,94,26,0.25)",
          }}>
            <span style={{
              fontFamily: "'Cinzel Decorative',serif", fontSize: "1.1rem", minWidth: 34, textAlign: "center",
              color: r.crit ? "#e8b84b" : r.fail ? "#c66" : "#f0d090",
            }}>{r.total}</span>
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ fontFamily: "Cinzel,serif", fontSize: "0.62rem", color: "#e8b84b", overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>{r.label}</div>
              <div style={{ fontFamily: "Cinzel,serif", fontSize: "0.5rem", color: "#8b5e1a" }}>
                {r.die ? `d${r.die}` : "d20"} ({r.d20}){r.mod !== undefined && r.die === undefined ? ` ${r.mod >= 0 ? "+" : "−"} ${Math.abs(r.mod)}` : ""}
                {r.crit ? " · CRIT" : r.fail ? " · FUMBLE" : ""}
              </div>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

// ── Save status badge ──
function SaveBadge({ state }) {
  const map = {
    saving: { text: "✶ SAVING", color: "#c9882a", bg: "rgba(201,136,42,0.15)", border: "rgba(201,136,42,0.4)" },
    saved: { text: "✓ SAVED", color: "#4caf50", bg: "rgba(76,175,80,0.15)", border: "rgba(76,175,80,0.3)" },
    error: { text: "⚠ NOT SAVED", color: "#c66", bg: "rgba(122,28,28,0.2)", border: "rgba(122,28,28,0.5)" },
    idle: { text: "✓ SAVED", color: "#4caf50", bg: "rgba(76,175,80,0.1)", border: "rgba(76,175,80,0.2)" },
  };
  const v = map[state] || map.idle;
  return (
    <span style={{
      fontFamily: "Cinzel,serif", fontSize: "0.5rem", letterSpacing: 2,
      color: v.color, background: v.bg, border: `1px solid ${v.border}`,
      borderRadius: 20, padding: "2px 8px", whiteSpace: "nowrap",
      transition: "all 0.3s",
    }}>{v.text}</span>
  );
}

// ── Main App ──
export default function DnDSheet() {
  const [char, setChar] = useState(INITIAL_CHARACTER);
  const [loaded, setLoaded] = useState(false);
  const [saveState, setSaveState] = useState("idle");
  const [tab, setTab] = useState("stats");
  const [addingFeature, setAddingFeature] = useState(false);
  const [newFeature, setNewFeature] = useState("");
  const [addingItem, setAddingItem] = useState(false);
  const [newItem, setNewItem] = useState("");
  const [addingSpell, setAddingSpell] = useState(null);
  const [newSpell, setNewSpell] = useState("");

  // Dice state
  const [roll, setRoll] = useState(null);
  const [rollLog, setRollLog] = useState([]);
  const [showTray, setShowTray] = useState(false);
  const [showLog, setShowLog] = useState(false);
  const rollTimer = useRef(null);

  // ── Load saved character once on mount ──
  useEffect(() => {
    const result = storage.get(STORAGE_KEY);
    if (result?.value) {
      try {
        // merge over defaults so older saves missing a field still work
        const parsed = JSON.parse(result.value);
        setChar(prev => ({ ...prev, ...parsed }));
      } catch { /* corrupt save — keep defaults */ }
    }
    const savedLog = storage.get(STORAGE_KEY + "-rolls");
    if (savedLog?.value) {
      try { setRollLog(JSON.parse(savedLog.value)); } catch { /* ignore */ }
    }
    setLoaded(true);
  }, []);

  // ── Autosave: debounced write whenever the character changes ──
  useEffect(() => {
    if (!loaded) return;
    setSaveState("saving");
    const t = setTimeout(() => {
      const ok = storage.set(STORAGE_KEY, JSON.stringify(char));
      setSaveState(ok ? "saved" : "error");
    }, 500);
    return () => clearTimeout(t);
  }, [char, loaded]);

  // ── Persist roll log ──
  useEffect(() => {
    if (!loaded) return;
    storage.set(STORAGE_KEY + "-rolls", JSON.stringify(rollLog.slice(0, 40)));
  }, [rollLog, loaded]);

  // clear any pending dice timer on unmount
  useEffect(() => () => clearTimeout(rollTimer.current), []);

  const update = useCallback((updater) => {
    setChar(prev => updater(prev));
  }, []);

  // ── Dice helpers ──
  const rollCheck = useCallback((label, mod) => {
    const d20 = rollDie(20);
    const total = d20 + mod;
    const entry = { label, d20, mod, total, crit: d20 === 20, fail: d20 === 1 };
    setRoll(entry);
    setRollLog(prev => [entry, ...prev].slice(0, 40));
    clearTimeout(rollTimer.current);
    rollTimer.current = setTimeout(() => setRoll(null), 2400);
  }, []);

  const rollRaw = useCallback((sides) => {
    const d = rollDie(sides);
    const entry = { label: `d${sides}`, d20: d, total: d, die: sides, crit: sides === 20 && d === 20, fail: sides === 20 && d === 1 };
    setRoll(entry);
    setRollLog(prev => [entry, ...prev].slice(0, 40));
    setShowTray(false);
    clearTimeout(rollTimer.current);
    rollTimer.current = setTimeout(() => setRoll(null), 2400);
  }, []);

  const setAbility = (key, val) => update(c => ({ ...c, abilities: { ...c.abilities, [key]: val } }));
  const setCombat = (key, val) => update(c => ({ ...c, combat: { ...c.combat, [key]: val } }));
  const toggleSave = (key) => update(c => ({ ...c, savingThrows: { ...c.savingThrows, [key]: { ...c.savingThrows[key], prof: !c.savingThrows[key].prof } } }));
  const toggleSkill = (key) => update(c => ({ ...c, skills: { ...c.skills, [key]: { ...c.skills[key], prof: !c.skills[key].prof } } }));
  const toggleDS = (type) => update(c => {
    const cur = c.deathSaves[type];
    return { ...c, deathSaves: { ...c.deathSaves, [type]: cur >= 3 ? 0 : cur + 1 } };
  });

  const TABS = [
    { id: "stats", label: "Stats" },
    { id: "skills", label: "Skills" },
    { id: "combat", label: "Combat" },
    { id: "spells", label: "Spells" },
    { id: "gear", label: "Gear" },
  ];

  const s = char;
  const pb = s.proficiencyBonus;

  const getSaveMod = (key) => getMod(s.abilities[key]) + (s.savingThrows[key].prof ? pb : 0);
  const getSkillMod = (key) => {
    const sk = s.skills[key];
    return getMod(s.abilities[sk.ability]) + (sk.prof ? pb : 0);
  };

  const styles = {
    app: {
      minHeight: "100vh",
      background: "#0f0804",
      backgroundImage: "radial-gradient(ellipse at top, #1a0a02 0%, #0a0402 100%)",
      fontFamily: "'Crimson Text',Georgia,serif",
      color: "#1a1008",
      maxWidth: 480,
      margin: "0 auto",
      position: "relative",
    },
    header: {
      background: "linear-gradient(135deg,#1a0a02,#3d1a05)",
      borderBottom: "2px solid #c9882a",
      padding: "14px 16px 10px",
      position: "sticky", top: 0, zIndex: 50,
    },
    charName: {
      fontFamily: "'Cinzel Decorative',serif",
      fontSize: "1.4rem", fontWeight: 900,
      color: "#e8b84b",
      textShadow: "0 0 20px rgba(201,136,42,0.4)",
      lineHeight: 1,
    },
    charSub: {
      fontFamily: "Cinzel,serif",
      fontSize: "0.6rem", letterSpacing: 2,
      color: "#c9882a88",
      marginTop: 3,
    },
    tabBar: {
      display: "flex",
      background: "#0f0804",
      borderBottom: "1px solid #3d1a05",
      position: "sticky", top: 66, zIndex: 49,
    },
    tabBtn: (active) => ({
      flex: 1, padding: "10px 4px",
      fontFamily: "Cinzel,serif", fontSize: "0.6rem",
      letterSpacing: 1.5, textTransform: "uppercase",
      border: "none", cursor: "pointer",
      background: active ? "linear-gradient(180deg,#3d1a05,#1a0a02)" : "transparent",
      color: active ? "#e8b84b" : "#8b5e1a",
      borderBottom: active ? "2px solid #c9882a" : "2px solid transparent",
      transition: "all 0.2s",
    }),
    page: {
      padding: "16px",
      background: "#f5ead6",
      backgroundImage: "linear-gradient(160deg,#f8eedc 0%,#eedfc0 100%)",
      minHeight: "calc(100vh - 110px)",
    },
    sectionTitle: {
      fontFamily: "Cinzel,serif", fontSize: "0.55rem",
      letterSpacing: 3, textTransform: "uppercase",
      color: "#7a1c1c",
      borderBottom: "1px solid rgba(201,136,42,0.4)",
      paddingBottom: 4, marginBottom: 10, marginTop: 16,
    },
    card: {
      background: "rgba(245,234,214,0.7)",
      border: "1px solid rgba(201,136,42,0.3)",
      borderRadius: 8, padding: "10px 12px",
      marginBottom: 10,
    },
    addBtn: {
      fontFamily: "Cinzel,serif", fontSize: "0.6rem",
      letterSpacing: 1.5, textTransform: "uppercase",
      background: "linear-gradient(135deg,#3d1a05,#5c2b0a)",
      border: "1px solid #c9882a", borderRadius: 4,
      color: "#e8b84b", padding: "5px 12px",
      cursor: "pointer", marginTop: 8,
    },
    removeBtn: {
      background: "none", border: "none",
      color: "#7a1c1c", cursor: "pointer",
      fontSize: "0.85rem", padding: "0 4px",
      lineHeight: 1,
    },
    hpBtn: {
      width: 36, height: 36, borderRadius: "50%",
      border: "1.5px solid #c9882a",
      background: "linear-gradient(135deg,#3d1a05,#5c2b0a)",
      color: "#e8b84b", fontSize: "1.2rem",
      cursor: "pointer", display: "flex",
      alignItems: "center", justifyContent: "center",
      fontWeight: 900,
    },
    rollRow: {
      display: "flex", alignItems: "center", gap: 8,
      padding: "4px 4px", borderRadius: 4,
      borderBottom: "1px dashed rgba(139,94,26,0.2)",
      cursor: "pointer",
    },
  };

  // small reusable proficiency dot
  const ProfDot = ({ on, onClick }) => (
    <div
      onClick={onClick}
      title="Toggle proficiency"
      style={{
        width: 12, height: 12, borderRadius: "50%", flexShrink: 0, cursor: "pointer",
        background: on ? "radial-gradient(circle at 35% 35%,#e8b84b,#c9882a)" : "#e8d4a8",
        border: `1.5px solid ${on ? "#c9882a" : "#8b5e1a"}`,
        boxShadow: on ? "0 0 6px rgba(201,136,42,0.5)" : "none",
      }}
    />
  );

  // ── STATS TAB ──
  const StatsTab = () => (
    <div>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 8 }}>
        <div>
          <div style={styles.charName}>
            <EditField value={s.name} onChange={v => update(c => ({ ...c, name: v }))} style={{ color: "#7a1c1c", fontSize: "1.1rem" }} />
          </div>
          <div style={{ fontFamily: "Cinzel,serif", fontSize: "0.6rem", color: "#8b5e1a", marginTop: 2 }}>
            <EditField value={s.class} onChange={v => update(c => ({ ...c, class: v }))} style={{ color: "#8b5e1a" }} />
            {" · "}
            <EditField value={s.race} onChange={v => update(c => ({ ...c, race: v }))} style={{ color: "#8b5e1a" }} />
          </div>
        </div>
        <div style={{ textAlign: "right" }}>
          <div style={{ fontFamily: "Cinzel,serif", fontSize: "0.55rem", color: "#8b5e1a" }}>Prof Bonus</div>
          <div style={{ fontFamily: "'Cinzel Decorative',serif", fontSize: "1.3rem", color: "#7a1c1c" }}>
            +<EditField value={pb} onChange={v => update(c => ({ ...c, proficiencyBonus: Number(v) }))} type="number" style={{ color: "#7a1c1c" }} />
          </div>
        </div>
      </div>

      <div style={styles.sectionTitle}>Ability Scores</div>
      <div style={{ display: "grid", gridTemplateColumns: "repeat(3,1fr)", gap: 8, marginBottom: 4 }}>
        {Object.entries(s.abilities).map(([key, val]) => (
          <AbilityBlock key={key} name={ABILITY_SHORT[key]} score={val} onChange={v => setAbility(key, v)} onRoll={rollCheck} />
        ))}
      </div>

      <div style={styles.sectionTitle}>Saving Throws</div>
      <div style={styles.card}>
        {Object.entries(s.savingThrows).map(([key]) => {
          const mod = getSaveMod(key);
          const label = key.charAt(0).toUpperCase() + key.slice(1).replace(/([A-Z])/g, " $1");
          return (
            <div key={key} style={styles.rollRow} onClick={() => rollCheck(`${label} Save`, mod)}>
              <ProfDot on={s.savingThrows[key].prof} onClick={(e) => { e.stopPropagation(); toggleSave(key); }} />
              <span style={{ fontFamily: "Cinzel,serif", fontSize: "0.65rem", fontWeight: 700, color: "#3d2b0a", minWidth: 28 }}>{fmtMod(mod)}</span>
              <span style={{ fontSize: "0.8rem", color: "#1a1008", textTransform: "capitalize", flex: 1 }}>{key.replace(/([A-Z])/g, ' $1')}</span>
              <span style={{ color: "#c9882a", fontSize: "0.7rem" }}>🎲</span>
            </div>
          );
        })}
      </div>

      <div style={styles.sectionTitle}>Features & Traits</div>
      <div style={{ display: "flex", flexWrap: "wrap", gap: 4, marginBottom: 8 }}>
        {s.features.map((f, i) => (
          <div key={i} style={{ display: "flex", alignItems: "center", background: "linear-gradient(135deg,#3d1a05,#5c2b0a)", border: "1px solid #c9882a", borderRadius: 4, padding: "3px 8px", gap: 4 }}>
            <span style={{ fontFamily: "Cinzel,serif", fontSize: "0.6rem", color: "#e8b84b" }}>{f}</span>
            <button style={styles.removeBtn} onClick={() => update(c => ({ ...c, features: c.features.filter((_, j) => j !== i) }))}>×</button>
          </div>
        ))}
      </div>
      {addingFeature ? (
        <div style={{ display: "flex", gap: 6 }}>
          <input autoFocus value={newFeature} onChange={e => setNewFeature(e.target.value)}
            onKeyDown={e => { if (e.key === "Enter" && newFeature.trim()) { update(c => ({ ...c, features: [...c.features, newFeature.trim()] })); setNewFeature(""); setAddingFeature(false); } }}
            placeholder="Feature name…"
            style={{ flex: 1, background: "rgba(201,136,42,0.1)", border: "1px solid #c9882a", borderRadius: 4, color: "#1a1008", fontFamily: "inherit", padding: "4px 8px" }}
          />
          <button style={styles.addBtn} onClick={() => { if (newFeature.trim()) { update(c => ({ ...c, features: [...c.features, newFeature.trim()] })); setNewFeature(""); setAddingFeature(false); } }}>Add</button>
          <button style={{ ...styles.addBtn, background: "transparent", color: "#8b5e1a" }} onClick={() => setAddingFeature(false)}>Cancel</button>
        </div>
      ) : (
        <button style={styles.addBtn} onClick={() => setAddingFeature(true)}>+ Add Feature</button>
      )}

      <div style={styles.sectionTitle}>Notes</div>
      <textarea
        value={s.notes}
        onChange={e => update(c => ({ ...c, notes: e.target.value }))}
        placeholder="Session notes, lore, reminders…"
        style={{ width: "100%", minHeight: 80, background: "rgba(245,234,214,0.5)", border: "1px solid rgba(201,136,42,0.3)", borderRadius: 6, fontFamily: "'Crimson Text',serif", fontSize: "0.9rem", color: "#1a1008", padding: "8px 10px", resize: "vertical" }}
      />
    </div>
  );

  // ── SKILLS TAB ──
  const SkillsTab = () => (
    <div>
      <div style={styles.sectionTitle}>Skills</div>
      <div style={{ ...styles.card, padding: "6px 10px" }}>
        {Object.entries(s.skills).map(([key]) => {
          const mod = getSkillMod(key);
          const sk = s.skills[key];
          return (
            <div key={key} style={styles.rollRow} onClick={() => rollCheck(SKILL_LABELS[key], mod)}>
              <ProfDot on={sk.prof} onClick={(e) => { e.stopPropagation(); toggleSkill(key); }} />
              <span style={{ fontFamily: "Cinzel,serif", fontSize: "0.65rem", fontWeight: 700, color: "#3d2b0a", minWidth: 28 }}>{fmtMod(mod)}</span>
              <span style={{ fontSize: "0.8rem", color: "#1a1008", flex: 1 }}>{SKILL_LABELS[key]}</span>
              <span style={{ fontFamily: "Cinzel,serif", fontSize: "0.5rem", color: "#8b5e1a" }}>{ABILITY_SHORT[sk.ability]}</span>
              <span style={{ color: "#c9882a", fontSize: "0.7rem" }}>🎲</span>
            </div>
          );
        })}
      </div>
      <div style={{ ...styles.card, marginTop: 12 }}>
        <div style={{ fontFamily: "Cinzel,serif", fontSize: "0.55rem", letterSpacing: 2, color: "#7a1c1c", marginBottom: 6 }}>PASSIVE WISDOM (PERCEPTION)</div>
        <div style={{ fontFamily: "'Cinzel Decorative',serif", fontSize: "1.8rem", color: "#3d2b0a" }}>
          {10 + getSkillMod("perception")}
        </div>
      </div>
    </div>
  );

  // ── COMBAT TAB ──
  const CombatTab = () => (
    <div>
      <div style={{ display: "grid", gridTemplateColumns: "repeat(3,1fr)", gap: 10, marginBottom: 14 }}>
        {[
          { label: "Armor Class", key: "ac" },
          { label: "Initiative", key: "initiative" },
          { label: "Speed", key: "speed" },
        ].map(({ label, key }) => (
          <div key={key} style={{ textAlign: "center" }}>
            <div style={{ width: 64, height: 64, borderRadius: "50%", background: "linear-gradient(135deg,#3d1a05,#5c2b0a)", border: "2px solid #c9882a", display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", margin: "0 auto 4px", boxShadow: "0 0 12px rgba(201,136,42,0.25)" }}>
              <EditField value={s.combat[key]} onChange={v => setCombat(key, Number(v))} type="number"
                style={{ fontFamily: "'Cinzel Decorative',serif", fontSize: "1.2rem", color: "#e8b84b", textAlign: "center", display: "block" }}
                inputStyle={{ width: 44, textAlign: "center" }}
              />
            </div>
            <span style={{ fontFamily: "Cinzel,serif", fontSize: "0.5rem", letterSpacing: 1.5, color: "#8b5e1a", textTransform: "uppercase" }}>{label}</span>
            {key === "initiative" && (
              <button onClick={() => rollCheck("Initiative", s.combat.initiative)} style={{ display: "block", margin: "4px auto 0", fontFamily: "Cinzel,serif", fontSize: "0.5rem", letterSpacing: 1, color: "#e8b84b", background: "linear-gradient(135deg,#3d1a05,#5c2b0a)", border: "1px solid #c9882a", borderRadius: 4, padding: "2px 8px", cursor: "pointer" }}>🎲 ROLL</button>
            )}
          </div>
        ))}
      </div>

      {/* HP */}
      <div style={{ ...styles.card, background: "linear-gradient(135deg,rgba(122,28,28,0.1),rgba(122,28,28,0.05))", border: "1.5px solid #7a1c1c", textAlign: "center", marginBottom: 10 }}>
        <div style={{ fontFamily: "Cinzel,serif", fontSize: "0.55rem", letterSpacing: 2, color: "#7a1c1c", marginBottom: 4 }}>HIT POINTS</div>
        <div style={{ display: "flex", alignItems: "center", justifyContent: "center", gap: 12 }}>
          <button style={styles.hpBtn} onClick={() => setCombat("hp", Math.max(0, s.combat.hp - 1))}>−</button>
          <div>
            <EditField value={s.combat.hp} onChange={v => setCombat("hp", Number(v))} type="number"
              style={{ fontFamily: "'Cinzel Decorative',serif", fontSize: "3rem", color: "#7a1c1c", lineHeight: 1 }}
              inputStyle={{ width: 70, textAlign: "center" }}
            />
            <span style={{ fontFamily: "Cinzel,serif", fontSize: "1rem", color: "#8b5e1a" }}>
              {" / "}
              <EditField value={s.combat.maxHp} onChange={v => setCombat("maxHp", Number(v))} type="number" style={{ color: "#8b5e1a" }} inputStyle={{ width: 40 }} />
            </span>
          </div>
          <button style={styles.hpBtn} onClick={() => setCombat("hp", Math.min(s.combat.maxHp, s.combat.hp + 1))}>+</button>
        </div>
        <div style={{ display: "flex", gap: 8, justifyContent: "center", marginTop: 8 }}>
          {[-10,-5,-1,"+1","+5","+10"].map(v => (
            <button key={v} onClick={() => {
              const delta = typeof v === "number" ? v : parseInt(v);
              setCombat("hp", Math.max(0, Math.min(s.combat.maxHp, s.combat.hp + delta)));
            }} style={{ fontFamily: "Cinzel,serif", fontSize: "0.55rem", padding: "3px 8px", background: typeof v === "number" ? "rgba(122,28,28,0.15)" : "rgba(61,43,10,0.15)", border: `1px solid ${typeof v === "number" ? "#7a1c1c" : "#c9882a"}`, borderRadius: 4, color: typeof v === "number" ? "#7a1c1c" : "#3d2b0a", cursor: "pointer" }}>
              {v}
            </button>
          ))}
        </div>
      </div>

      {/* Temp HP */}
      <div style={{ ...styles.card, textAlign: "center" }}>
        <div style={{ fontFamily: "Cinzel,serif", fontSize: "0.55rem", letterSpacing: 2, color: "#8b5e1a", marginBottom: 4 }}>TEMP HP</div>
        <div style={{ display: "flex", alignItems: "center", justifyContent: "center", gap: 12 }}>
          <button style={{ ...styles.hpBtn, width: 30, height: 30 }} onClick={() => setCombat("tempHp", Math.max(0, s.combat.tempHp - 1))}>−</button>
          <EditField value={s.combat.tempHp} onChange={v => setCombat("tempHp", Number(v))} type="number"
            style={{ fontFamily: "'Cinzel Decorative',serif", fontSize: "1.8rem", color: "#3d2b0a" }}
            inputStyle={{ width: 50, textAlign: "center" }}
          />
          <button style={{ ...styles.hpBtn, width: 30, height: 30 }} onClick={() => setCombat("tempHp", s.combat.tempHp + 1)}>+</button>
        </div>
      </div>

      {/* Hit Dice */}
      <div style={{ ...styles.card, display: "flex", alignItems: "center", gap: 10 }}>
        <span style={{ fontFamily: "Cinzel,serif", fontSize: "0.55rem", letterSpacing: 2, color: "#8b5e1a", textTransform: "uppercase" }}>Hit Dice</span>
        <EditField value={s.combat.hitDice} onChange={v => setCombat("hitDice", v)}
          style={{ fontFamily: "Cinzel,serif", fontSize: "0.9rem", fontWeight: 700, color: "#3d2b0a" }}
        />
      </div>

      {/* Death Saves */}
      <div style={styles.sectionTitle}>Death Saves</div>
      <div style={{ ...styles.card, display: "flex", gap: 20, justifyContent: "center" }}>
        {[["successes","#2d7a2d","Successes"], ["failures","#7a1c1c","Failures"]].map(([type, color, label]) => (
          <div key={type} style={{ textAlign: "center" }}>
            <div style={{ fontFamily: "Cinzel,serif", fontSize: "0.5rem", letterSpacing: 2, color: "#8b5e1a", marginBottom: 6 }}>{label.toUpperCase()}</div>
            <div style={{ display: "flex", gap: 6 }}>
              {[0,1,2].map(i => (
                <div key={i} onClick={() => toggleDS(type)} style={{
                  width: 18, height: 18, borderRadius: "50%", cursor: "pointer",
                  background: i < s.deathSaves[type] ? color : "#e8d4a8",
                  border: `2px solid ${color}`,
                  transition: "all 0.2s",
                }} />
              ))}
            </div>
          </div>
        ))}
      </div>
    </div>
  );

  // ── SPELLS TAB ──
  const SpellsTab = () => {
    const levelLabels = { cantrips: "Cantrips", level1: "1st Level", level2: "2nd Level", level3: "3rd Level", level4: "4th Level", level5: "5th Level" };
    return (
      <div>
        <div style={{ display: "flex", gap: 8, marginBottom: 12 }}>
          {[["Ability", s.spellcasting.ability], ["Save DC", s.spellcasting.saveDC], ["Atk Bonus", `+${s.spellcasting.attackBonus}`]].map(([l, v], i) => (
            <div key={l} style={{ flex: 1, textAlign: "center", border: "1px solid rgba(201,136,42,0.4)", borderRadius: 6, padding: "6px", background: "rgba(201,136,42,0.06)" }}>
              <div style={{ fontFamily: "'Cinzel Decorative',serif", fontSize: "1rem", color: "#7a1c1c" }}>
                {i === 0 ? (
                  <EditField value={s.spellcasting.ability} onChange={v => update(c => ({ ...c, spellcasting: { ...c.spellcasting, ability: v } }))} style={{ color: "#7a1c1c" }} />
                ) : i === 1 ? (
                  <EditField value={s.spellcasting.saveDC} onChange={v => update(c => ({ ...c, spellcasting: { ...c.spellcasting, saveDC: Number(v) } }))} type="number" style={{ color: "#7a1c1c" }} />
                ) : (
                  <span>+<EditField value={s.spellcasting.attackBonus} onChange={v => update(c => ({ ...c, spellcasting: { ...c.spellcasting, attackBonus: Number(v) } }))} type="number" style={{ color: "#7a1c1c" }} /></span>
                )}
              </div>
              <div style={{ fontFamily: "Cinzel,serif", fontSize: "0.5rem", letterSpacing: 1.5, color: "#8b5e1a", textTransform: "uppercase" }}>{l}</div>
            </div>
          ))}
        </div>
        <button onClick={() => rollCheck("Spell Attack", s.spellcasting.attackBonus)} style={{ ...styles.addBtn, width: "100%", marginTop: 0, marginBottom: 4 }}>🎲 Roll Spell Attack</button>

        {Object.entries(s.spells).map(([lvl, spells]) => (
          <div key={lvl} style={{ border: "1px solid rgba(201,136,42,0.3)", borderRadius: 8, overflow: "hidden", marginBottom: 10 }}>
            <div style={{ background: "linear-gradient(135deg,#3d1a05,#5c2b0a)", padding: "6px 12px", fontFamily: "Cinzel,serif", fontSize: "0.6rem", letterSpacing: 2, color: "#e8b84b", textTransform: "uppercase" }}>
              {levelLabels[lvl]}
            </div>
            <div style={{ padding: "6px 12px", background: "rgba(245,234,214,0.5)" }}>
              {spells.map((spell, i) => (
                <div key={i} style={{ display: "flex", alignItems: "center", gap: 6, padding: "3px 0", borderBottom: "1px dashed rgba(139,94,26,0.2)" }}>
                  <span style={{ color: "#c9882a", fontSize: "0.6rem" }}>✦</span>
                  <span style={{ fontSize: "0.85rem", flex: 1 }}>{spell}</span>
                  <button style={styles.removeBtn} onClick={() => update(c => ({ ...c, spells: { ...c.spells, [lvl]: c.spells[lvl].filter((_, j) => j !== i) } }))}>×</button>
                </div>
              ))}
              {addingSpell === lvl ? (
                <div style={{ display: "flex", gap: 6, marginTop: 4 }}>
                  <input autoFocus value={newSpell} onChange={e => setNewSpell(e.target.value)}
                    onKeyDown={e => { if (e.key === "Enter" && newSpell.trim()) { update(c => ({ ...c, spells: { ...c.spells, [lvl]: [...c.spells[lvl], newSpell.trim()] } })); setNewSpell(""); setAddingSpell(null); } }}
                    placeholder="Spell name…"
                    style={{ flex: 1, background: "rgba(201,136,42,0.1)", border: "1px solid #c9882a", borderRadius: 4, color: "#1a1008", fontFamily: "inherit", padding: "3px 8px", fontSize: "0.8rem" }}
                  />
                  <button style={styles.addBtn} onClick={() => { if (newSpell.trim()) { update(c => ({ ...c, spells: { ...c.spells, [lvl]: [...c.spells[lvl], newSpell.trim()] } })); setNewSpell(""); setAddingSpell(null); } }}>+</button>
                  <button style={{ ...styles.removeBtn, fontSize: "1rem" }} onClick={() => setAddingSpell(null)}>×</button>
                </div>
              ) : (
                <button style={{ ...styles.addBtn, fontSize: "0.55rem", padding: "3px 8px", marginTop: 4 }} onClick={() => { setAddingSpell(lvl); setNewSpell(""); }}>+ Add</button>
              )}
            </div>
          </div>
        ))}
      </div>
    );
  };

  // ── GEAR TAB ──
  const GearTab = () => (
    <div>
      <div style={styles.sectionTitle}>Equipment</div>
      <div style={styles.card}>
        {s.equipment.map((item, i) => (
          <div key={i} style={{ display: "flex", alignItems: "center", gap: 8, padding: "4px 0", borderBottom: "1px dashed rgba(139,94,26,0.2)" }}>
            <span style={{ color: "#c9882a", fontSize: "0.7rem" }}>⚔</span>
            <span style={{ flex: 1, fontSize: "0.85rem" }}>{item}</span>
            <button style={styles.removeBtn} onClick={() => update(c => ({ ...c, equipment: c.equipment.filter((_, j) => j !== i) }))}>×</button>
          </div>
        ))}
        {addingItem ? (
          <div style={{ display: "flex", gap: 6, marginTop: 6 }}>
            <input autoFocus value={newItem} onChange={e => setNewItem(e.target.value)}
              onKeyDown={e => { if (e.key === "Enter" && newItem.trim()) { update(c => ({ ...c, equipment: [...c.equipment, newItem.trim()] })); setNewItem(""); setAddingItem(false); } }}
              placeholder="Item name…"
              style={{ flex: 1, background: "rgba(201,136,42,0.1)", border: "1px solid #c9882a", borderRadius: 4, color: "#1a1008", fontFamily: "inherit", padding: "4px 8px" }}
            />
            <button style={styles.addBtn} onClick={() => { if (newItem.trim()) { update(c => ({ ...c, equipment: [...c.equipment, newItem.trim()] })); setNewItem(""); setAddingItem(false); } }}>Add</button>
            <button style={{ ...styles.addBtn, background: "transparent", color: "#8b5e1a" }} onClick={() => setAddingItem(false)}>Cancel</button>
          </div>
        ) : (
          <button style={styles.addBtn} onClick={() => setAddingItem(true)}>+ Add Item</button>
        )}
      </div>

      <div style={styles.sectionTitle}>Proficiencies &amp; Languages</div>
      <div style={styles.card}>
        <EditField
          value={s.proficiencies}
          onChange={v => update(c => ({ ...c, proficiencies: v }))}
          multiline
          style={{ fontSize: "0.85rem", display: "block", width: "100%" }}
          inputStyle={{ fontSize: "0.85rem" }}
        />
      </div>

      <button
        onClick={() => { if (confirm("Reset to original character? This cannot be undone.")) { update(() => INITIAL_CHARACTER); } }}
        style={{ ...styles.addBtn, background: "rgba(122,28,28,0.2)", borderColor: "#7a1c1c", color: "#7a1c1c", marginTop: 16, width: "100%" }}
      >
        ↺ Reset to Original
      </button>
    </div>
  );

  const tabContent = { stats: <StatsTab />, skills: <SkillsTab />, combat: <CombatTab />, spells: <SpellsTab />, gear: <GearTab /> };

  return (
    <div style={styles.app}>
      <link href="https://fonts.googleapis.com/css2?family=Cinzel+Decorative:wght@400;700;900&family=Cinzel:wght@400;600;700&family=Crimson+Text:ital,wght@0,400;0,600;1,400&display=swap" rel="stylesheet" />

      {/* Sticky header */}
      <div style={styles.header}>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
          <div>
            <div style={styles.charName}>{s.name}</div>
            <div style={styles.charSub}>{s.class} · {s.race}</div>
          </div>
          <SaveBadge state={saveState} />
        </div>
      </div>

      {/* Tab bar */}
      <div style={styles.tabBar}>
        {TABS.map(t => (
          <button key={t.id} style={styles.tabBtn(tab === t.id)} onClick={() => setTab(t.id)}>
            {t.label}
          </button>
        ))}
      </div>

      {/* Page */}
      <div style={styles.page}>
        {tabContent[tab]}
      </div>

      {/* Floating dice controls */}
      <div style={{ position: "sticky", bottom: 0, pointerEvents: "none", height: 0 }}>
        <div style={{ position: "absolute", right: 14, bottom: 16, display: "flex", flexDirection: "column", gap: 10, pointerEvents: "auto" }}>
          <button
            onClick={() => setShowLog(true)}
            title="Roll history"
            style={{
              width: 44, height: 44, borderRadius: "50%", cursor: "pointer",
              background: "linear-gradient(135deg,#1a0a02,#3d1a05)", border: "1.5px solid #c9882a",
              color: "#e8b84b", fontSize: "1.1rem", boxShadow: "0 4px 14px rgba(0,0,0,0.5)",
            }}
          >📜</button>
          <button
            onClick={() => setShowTray(true)}
            title="Roll dice"
            style={{
              width: 56, height: 56, borderRadius: "50%", cursor: "pointer",
              background: "radial-gradient(circle at 35% 30%,#5c2b0a,#3d1a05)", border: "2px solid #c9882a",
              color: "#e8b84b", fontSize: "1.6rem", boxShadow: "0 4px 18px rgba(201,136,42,0.4)",
            }}
          >🎲</button>
        </div>
      </div>

      {showTray && <DiceTray onRoll={rollRaw} onClose={() => setShowTray(false)} />}
      {showLog && <RollLog log={rollLog} onClose={() => setShowLog(false)} onClear={() => setRollLog([])} />}
      <DiceOverlay roll={roll} onClose={() => setRoll(null)} />
    </div>
  );
}
