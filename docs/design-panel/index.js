/* index workbench: direction switching, HUD sample toggle, export.
   Selection persists locally but is NON-BINDING (labeled in UI). */

const DIRS = {
  A: {
    file: "direction-a.html",
    note: "A — AFTER-HOURS DUSK: apricot pools over petrol shadow; plum dusk beyond glass. Cinematic, cheerful.",
    floor: "2 / 4", timer: "1:47", state: "RACE",
    tokens:
`/* FRIDAY 5PM — Direction A: AFTER-HOURS DUSK (proposal, non-binding) */
BG_PLUM_DUSK      = #141019  // world ambience, ceiling mass
SURFACE_WALNUT    = #1f1a28  // furniture / raised panels
PAPER_CREAM       = #f2e9d8  // signage fill, paper props
APRICOT_POOL      = #ffb36b  // troffer warm pools (desk clusters)
PETROL_TEAL       = #2e6b74  // shadow masses, stairwell tint
ORANGE_PRIMARY    = #ff9a1a  // CTA / exit signs (existing identity)
TEXT_MUTED        = #b3a894
// Godot: OmniLight3D light_color=#ffb36b range<=6, shadow OFF (cull-group floors only)
// env: ambient #141019, filmic tonemap, glow OFF (sunset contrast is albedo+halo, not bloom)`
  },
  B: {
    file: "direction-b.html",
    note: "B — TOYBOX OFFICE: chunky milky-mint world, butter-cream props, ink outlines, coral controls.",
    floor: "2 / 4", timer: "1:47", state: "RACE",
    tokens:
`/* FRIDAY 5PM — Direction B: TOYBOX OFFICE (proposal, non-binding) */
MILKY_MINT        = #e9f4ee  // floor base, world light
BUTTER_CREAM      = #f6ead2  // desks, blunt forms
INK_OUTLINE       = #26323b  // UI strokes, signage outline
CORAL_CONTROL     = #ff6f61  // buttons, boost state (existing token)
MINT_BOARD        = #cfe8dd  // cards, specimen sheet bg
TEXT_MUTED        = #5f707a
// Godot: flat albedo + bevel via ArrayMesh/glTF later (still Godot, no engine swap)
// UI: StyleBoxFlat corner_radius 18-22, 2px INK borders, coral fill`
  },
  C: {
    file: "direction-c.html",
    note: "C — CORPORATE EMERGENCY: charcoal + safety orange, tabular countdown, over-serious safety posters.",
    floor: "2 / 4", timer: "1:47", state: "RACE",
    tokens:
`/* FRIDAY 5PM — Direction C: CORPORATE EMERGENCY (proposal, non-binding) */
CHARCOAL          = #1d2126  // world ambience
PANEL_CHARCOAL    = #262b31  // HUD panels
BONE_WHITE        = #ece8df  // signage letters, paper
SAFETY_ORANGE     = #ff6a13  // floor numbers, route arrows, CTA
SIGNAL_GREEN      = #3ddc84  // sparing: only "go/escape" states
TEXT_MUTED        = #9aa3ab
// Godot: Label3D signage (modulate #ece8df), emissive ONLY on exit signs
// UI: corner_radius 2, condensed display font, tabular-nums timer`
  }
};

const KEY = "friday-evac-panel-dir";
const root = document.documentElement;
const statusEl = document.getElementById("dir-status");
const cards = Array.from(document.querySelectorAll(".dir-card"));
let current = "A";

function applyDir(key, persist) {
  if (!DIRS[key]) return;
  current = key;
  root.dataset.dir = key;
  cards.forEach(c => c.setAttribute("aria-checked", String(c.dataset.pick === key)));
  const d = DIRS[key];
  const note = document.querySelector("#preview [data-note]");
  if (note) note.textContent = d.note;
  statusEl.textContent =
    `Previewing ${key}. Non-binding — confirm in conversation before any game-wide restyle. Full page: ${d.file}`;
  if (persist) { try { localStorage.setItem(KEY, key); } catch (e) {} }
}

cards.forEach(card => {
  card.addEventListener("click", () => applyDir(card.dataset.pick, true));
  card.addEventListener("keydown", e => {
    if (e.key === "ArrowRight" || e.key === "ArrowLeft") {
      e.preventDefault();
      const idx = cards.indexOf(card);
      const next = cards[(idx + (e.key === "ArrowRight" ? 1 : cards.length - 1)) % cards.length];
      next.focus(); applyDir(next.dataset.pick, true);
    }
  });
});

let saved = null;
try { saved = localStorage.getItem(KEY); } catch (e) {}
applyDir(saved && DIRS[saved] ? saved : "A", false);

/* HUD sample state toggle: READY <-> BOOST (illustrative values only) */
const slots = {
  state: document.querySelector('[data-slot="state"]'),
  speed: document.querySelector('[data-slot="speed"]'),
  timer: document.querySelector('[data-slot="timer"]'),
  boost: document.querySelector('[data-slot="boost"]')
};
let boosting = false;

function renderSample() {
  slots.state.textContent = boosting ? "BOOST" : "RACE";
  slots.speed.textContent = boosting ? "52" : "34";
  slots.timer.textContent = boosting ? "1:44" : "1:47";
  slots.boost.textContent = boosting ? "BOOSTING!" : "BOOST READY [SPACE]";
  slots.boost.classList.toggle("boosting", boosting);
}

const btnReady = document.getElementById("btn-ready");
const btnBoost = document.getElementById("btn-boost");
btnReady.addEventListener("click", () => { boosting = false; renderSample(); });
btnBoost.addEventListener("click", () => { boosting = true; renderSample(); });
renderSample();

/* Export recipe for the CURRENT direction */
const dlg = document.getElementById("export-dialog");
document.getElementById("dialog-close").addEventListener("click", () => dlg.close());
document.getElementById("dialog-copy").addEventListener("click", async () => {
  const ta = dlg.querySelector("textarea");
  ta.select();
  let ok = false;
  try { ok = await navigator.clipboard.writeText(ta.value); } catch (e) {}
  try { ok = ok || document.execCommand("copy"); } catch (e) {}
  const b = document.getElementById("dialog-copy");
  b.textContent = ok ? "Copied ✓" : "Use Ctrl/Cmd+C";
  setTimeout(() => { b.textContent = "Copy selection"; }, 1500);
});

wireExport("btn-export", () => DIRS[current].tokens);
