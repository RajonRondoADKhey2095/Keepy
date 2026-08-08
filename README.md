# Keepy

3D endless-runner prototype built in Godot 4.x (GDScript, Compatibility
renderer). Keepy runs down three lanes, dodges obstacles, and collects
noisettes. Everything currently renders with Godot's built-in primitive
meshes -- no external 3D assets are required to run the project.

## Requirements

- Godot Engine 4.3+ (or newer 4.x), using the Compatibility
  (GL Compatibility) renderer.

## Tester le jeu (boucle web CI)

Ce projet ne se teste pas seulement dans l'editeur : chaque push sur `main`
declenche un build web automatise, servi ensuite via une URL jouable
directement dans Safari sur iPhone (ou n'importe quel navigateur).

**La boucle :**

```
push sur main
  -> GitHub Actions (.github/workflows/web-build.yml)
     -> Godot 4.3 headless : import + export-release "Web"
     -> verification que index.html / .wasm / .pck existent et sont non vides
     -> upload de build/web en artefact GitHub Actions
     -> deploiement sur Vercel (build/web + vercel.json, prod)
  -> URL Vercel mise a jour, jouable immediatement
```

- Suivre le run : onglet **Actions** du repo GitHub.
- L'URL de prod (une fois le projet Vercel cree, voir ci-dessous) :
  **`https://keepy.vercel.app`** (a confirmer/ajuster une fois le premier
  deploiement reussi -- Vercel peut retenir un nom legerement different si
  `keepy` est deja pris ailleurs).
- Ouvrir cette URL dans Safari iOS -> le jeu doit se charger et etre
  jouable au tap/swipe, sans ecran blanc.

### Mise en place ponctuelle (une seule fois, cote humain)

L'automatisation ne peut pas creer elle-meme le projet Vercel ni les
secrets GitHub (ce sont des actions qui exigent un compte/jeton humain) :

1. **Creer le projet Vercel** : soit via le dashboard Vercel
   ("Add New... -> Project", en important sans repo Git connecte -- le
   contenu est pousse par la CI, pas par l'integration Git de Vercel),
   soit en local avec `vercel link` depuis ce dossier (choisir/creer le
   projet `keepy` sous l'equipe `rajonrondoadkhey2095s-projects`).
2. Recuperer les 3 valeurs :
   - `VERCEL_TOKEN` : https://vercel.com/account/tokens -> New Token.
   - `VERCEL_ORG_ID` et `VERCEL_PROJECT_ID` : apres `vercel link`, dans
     `.vercel/project.json` (`orgId` et `projectId`), ou dans les
     Project Settings sur vercel.com (section General).
3. Dans GitHub : **Settings -> Secrets and variables -> Actions -> New
   repository secret**, ajouter les 3 : `VERCEL_TOKEN`, `VERCEL_ORG_ID`,
   `VERCEL_PROJECT_ID`.
4. Relancer le workflow (`Actions` -> `Web build & deploy` -> `Run
   workflow`), ou pousser un commit sur `main`.

Tant que ces secrets ne sont pas configures, le build Godot et la
verification des artefacts s'executent et reussissent normalement (et
l'artefact `keepy-web-build` reste telechargeable depuis le run) -- seule
la derniere etape (deploy Vercel) echoue explicitement, avec un message
clair indiquant le secret manquant.

## Running the game

1. Clone the repo.
2. Open `project.godot` in Godot 4.x.
3. Press F5 (or the Play button). The project boots straight into
   `scenes/TitleScreen.tscn`.
4. Controls:
   - Desktop: Left/Right arrow keys to switch lanes, Space to jump.
   - Touch: swipe left/right to switch lanes, swipe up to jump.

## Project structure

```
keepy/
├── project.godot
├── scenes/                      # All .tscn scene files
│   ├── TitleScreen.tscn         # Boot scene, "Jouer" button
│   ├── Game.tscn                # Gameplay root: world + HUD + game over screen
│   ├── Keepy.tscn                # Player character
│   ├── TrackSegment.tscn         # One pooled 20-unit track tile
│   ├── Obstacle.tscn              # Pooled hazard
│   ├── Noisette.tscn               # Pooled collectible
│   ├── HUD.tscn                     # In-run score display
│   └── GameOverScreen.tscn          # Game over overlay
├── scripts/
│   ├── autoload/GameState.gd     # Singleton: score, distance, speed, run state
│   ├── Game.gd                    # Wires up World / HUD / GameOverScreen
│   ├── player/
│   │   ├── Keepy.gd                  # Movement, lanes, jump
│   │   └── SwipeDetector.gd           # Touch swipe -> lane/jump signals
│   ├── track/
│   │   ├── TrackManager.gd             # Segment pooling + recycling
│   │   └── TrackSegment.gd              # Per-tile obstacle/noisette pool
│   ├── gameplay/
│   │   ├── Obstacle.gd                  # Area3D -> game over on contact
│   │   └── Noisette.gd                   # Area3D -> +1 score, pooled hide
│   ├── camera/CameraFollow.gd           # Smooth follow behind Keepy
│   └── ui/
│       ├── TitleScreen.gd
│       ├── HUD.gd
│       └── GameOverScreen.gd
└── assets/
    ├── models/    # Future Meshy .glb exports go here
    ├── textures/  # Texture maps for the above
    └── audio/     # SFX / music
```

## Architecture notes

- **World-moves-toward-player.** Keepy stays fixed on the Z axis;
  `TrackManager` moves the track segments (and their attached obstacles
  and noisettes, as their children) toward the player every physics
  frame instead of moving the player forward through the world. This
  keeps every transform's coordinates bounded near the origin
  indefinitely, avoiding the floating-point precision loss a genuinely
  unbounded player Z coordinate would eventually cause on a long run.
- **Object pooling.** `TrackManager` keeps a fixed pool of
  `TrackSegment` instances, repositioning and repopulating them instead
  of calling `queue_free()` / re-instantiating on every recycle. Each
  `TrackSegment` in turn owns a fixed pool of one obstacle slot and
  three noisette slots (one per lane) that are shown/hidden and
  repositioned rather than freed and recreated.
- **Primitive placeholders, swap-ready.** Every visual node (Keepy's
  capsule, obstacles' boxes, noisettes' spheres, track tiles) is a
  plain `MeshInstance3D` with a built-in Godot `Mesh` resource, sitting
  as a direct child of its logic node. Swapping in a Meshy-generated
  `.glb` later is a matter of replacing that one child node's mesh (or
  the whole child node) inside the relevant `.tscn` -- none of the
  gameplay scripts touch mesh data, so no logic changes are needed.
- **Score.** Tracked as `distance_score` (derived from distance
  travelled) plus `noisette_score` and
  `gland_score` (collectibles, each worth a different point value),
  summed into `GameState.score`. Kept as separate counters specifically
  so a pickup can never be silently overwritten by the next
  distance-based score tick or by another collectible type. `nut_count`
  and `gland_count` are a second, independent pair of RAW pickup counts
  (not point values) used only for the HUD display and the leaderboard
  submission -- they never feed back into `score`.

## Adding Meshy assets later

Full specification -- dimensions, orientation, triangle budgets, dark-mode
material constraints and the acceptance checklist -- is in
[`docs/MESHY_SPEC.md`](docs/MESHY_SPEC.md). The short version:

1. Drop the exported `.glb` in `assets/models/`, textures in
   `assets/textures/`. Naming: `keepy_<subject>_<variant>.glb`.
2. Open the owning scene, select the `ModelSlot` node (they keep their
   existing names: `MeshInstance3D`, `DodgeMesh`, `Silhouette`, ...) and
   set its **`Model Scene`** property to the imported `.glb`.
3. Fix any import rotation or unit scale with the slot's own
   **`Model Rotation Degrees`** / **`Model Scale`**, not by re-exporting
   and not by editing the slot's transform (that one is gameplay-driven).
4. Run the acceptance checklist in the spec.

No script changes are required, and **no collision shape may be touched**:
hitbox dimensions live in `scripts/world/Hitboxes.gd` and are written onto
the real shapes at `_ready()`, so a mesh swap has no path to them.
`scripts/dev/AssetContractAudit.tscn` asserts exactly that by installing a
substitute model into every slot and re-measuring every collider --
measured today, 12/12 visuals change and 0/10 colliders move.

      godot4 --headless --path . res://scripts/dev/AssetContractAudit.tscn

## Known limitations / next steps

- No audio yet (`assets/audio/` is empty).
- **Pacing.** Run speed is a step function of ELAPSED TIME, never of
  distance travelled (a distance ramp self-accelerates: going faster
  accrues distance faster, which raises the speed again). The curve is
  an explicit table of eight (start time, speed) paliers in
  `GameState.STAGE_START_S` / `STAGE_SPEEDS`, logarithmic in shape --
  12 m/s at the start, 26 m/s from 90s on, with short paliers and big
  steps early and longer paliers and small steps late. Obstacle spacing
  adapts to it: `TrackManager.MIN_OBSTACLE_GAP_S` keeps a fixed amount
  of REACTION TIME between two hazards, so the track opens up as the run
  accelerates instead of becoming unreadable. Dark mode is on its own
  clock (`GameState.DARK_FIRST_TRIGGER_S` = 36s, then swapping every
  `DARK_CYCLE_PERIOD_S` = 20s). All of it lives in one commented block
  at the top of `GameState.gd`, plus the spacing block in
  `TrackManager.gd`.
- **Closing speed.** Every hazard except one is carried toward the
  player by the world and by nothing else, so "the world's speed" and
  "the speed this thing arrives at" used to be the same number. They are
  not: `Obstacle.own_speed_factor` states an obstacle's own forward
  speed as a multiple of the world's, `Obstacle.closing_speed()` is the
  sum, and every distance <-> reaction-time conversion goes through it
  (`Obstacle.time_to_contact_s`, `TrackManager._row_closing_speed` /
  `_rows_for_seconds`). It is 0.0 for DODGE/JUMP/ENEMY/AIR_ENEMY, which
  is exactly the old arithmetic.
- **The CHARGER** (`Obstacle.Type.CHARGER`) is the one hazard with a
  speed of its own: it CLOSES on the player at 2.35x the world speed,
  in a straight line down its spawn lane, never tracking and never
  changing lane -- the escape is always a lane switch. Because it
  overtakes rows, the row grid cannot space it; it is scheduled on
  ARRIVAL TIME instead (`TrackManager._charger_arrival_fits`) against
  what is really on the track. Frequency ramps with speed via
  `CHARGER_COOLDOWN_EARLY_S`/`_LATE_S`, never before
  `CHARGER_MIN_START_S`.
- **The STOMPER** (`Obstacle.Type.STOMPER`) is the deliberate INVERSE of
  the CHARGER: jump is the only escape, lane switch never is. It stays
  jumpable (`Obstacle.blocks_jump` excludes it) but, once its late commit
  resolves at the same `Obstacle.ENEMY_REACTION_WINDOW_S` threshold
  ground ENEMY hard-locks at, it mirrors the player's own `position.x`
  exactly every physics frame for the rest of its life
  (`Obstacle._process_stomper`) -- the lateral gap to the player is
  therefore identically 0.0, not a tight timing window, which is what
  `Obstacle.blocks_lane_switch` states as code. Unlike the CHARGER it
  never overtakes rows, so it is scheduled on the ordinary row grid
  (`TrackManager._try_stomper_lane`), with its own progressive cooldown
  (`STOMPER_COOLDOWN_EARLY_S`/`_LATE_S`, never before
  `STOMPER_MIN_START_S`) mirroring the CHARGER's cadence. A dedicated
  generation-time exclusion (`_stomper_charger_margin_clear`) keeps it
  away from a nearby CHARGER in time -- the one hazard exempt from the
  row grid, and therefore the one that needed new code; DODGE needs none,
  already spaced from STOMPER by the shared row-grid counter.
- **The death model.** Not every hazard kills. The two STATIC ones
  (`DODGE`, `JUMP` -- things that spawn on a lane and sit there) are
  NON-FATAL: contact costs ground instead of ending the run. The four
  ACTIVE ones (`CHARGER`, `STOMPER`, `ENEMY`, `AIR_ENEMY` -- things that
  close on you, track your lane or land on it, each with its own
  multi-cue telegraph) still kill on contact. `Obstacle.is_fatal` is the
  single source of that split. A non-fatal contact is a STRIKE
  (`GameState.register_strike`): it slows the player to
  `STRIKE_SLOWDOWN_FACTOR` of the run's speed for a moment while the
  pursuer keeps going, so the gap closes by the difference, and it pulls
  the pursuer's lead down to `STRIKE_PURSUER_LEAD_CAP_S` -- under the
  visibility threshold, so the thing behind you is always on screen
  during a penalty. `STRIKE_CAPACITY` strikes and it has you: the second
  one IS being caught, reported as the same `DeathCause.PURSUER` as the
  lead draining to zero. A strike comes back after
  `TIME_TO_CLEAR_STRIKE_S` of clean play, or immediately when the combo
  chain reaches a multiple of `COMBO_TO_CLEAR_STRIKE` (which is
  `COMBO_TIER_SIZE`, so it lands on the tier boundaries the combo
  already teaches). All of it lives in one commented block at the top of
  `GameState.gd`; the HUD draws it as two pips above the pursuer gauge.
- **World speed vs player speed.** Because a stumble slows the player
  without slowing the run, `GameState.current_speed` (the run's pace, what
  the speed table says) and `GameState.scroll_speed()` (what the player is
  actually making good) are different questions. Anything happening NOW
  reads `scroll_speed()` -- how far the track moves this frame, and every
  obstacle's `closing_speed()`. Anything being LAID OUT for later
  (TrackManager's spacing) keeps reading `lookahead_speed()`: a stumble is
  over in ~1.5s, long before a row spawned during one is reached. At full
  speed `scroll_speed()` returns `current_speed` exactly, so nothing
  outside a stumble changes.
- Pacing changes are verified by measurement, not by re-reading the
  constants: `scripts/dev/PacingAudit.tscn` boots the real game headless
  and reports palier timings, distance per palier, dark-cycle
  transitions, the worst reaction budget per palier and the enemy lane
  lock margin. `ChargerAudit.tscn` does the same for the charger (real
  reaction window per palier, spacing measured at the player plane,
  spawn rate, and how many landed inside a rush window), and
  `ChargerShapeProbe.tscn` asserts its silhouette is oriented and
  grounded as designed.

      godot4 --headless --fixed-fps 60 --path . res://scripts/dev/PacingAudit.tscn
      godot4 --headless --fixed-fps 60 --path . res://scripts/dev/ChargerAudit.tscn
      godot4 --headless --path . res://scripts/dev/ChargerShapeProbe.tscn
      godot4 --headless --fixed-fps 60 --path . res://scripts/dev/StomperAudit.tscn
      godot4 --headless --fixed-fps 60 --path . res://scripts/dev/StomperConflictAudit.tscn
      godot4 --headless --fixed-fps 60 --path . res://scripts/dev/StrikeAudit.tscn

  `StrikeAudit` covers the death model: per skill profile, how often a run
  stumbles and into which hazard type, how long runs last, whether the
  player is caught or killed outright, and which recovery path gives
  strikes back. Its bots are PursuerAudit's, plus a per-profile miss
  chance -- without one they never touch a hazard at all (measured: zero
  collisions in 300s+ for two of the three), so they could not exercise
  the mechanic. A CONTROL phase re-asserts that every run.

  The two probes that sample real rendered pixels need a rendering driver
  rather than pure headless:

      xvfb-run -a godot4 --rendering-driver opengl3 --path . res://scripts/dev/ComboContrastAudit.tscn
      xvfb-run -a godot4 --rendering-driver opengl3 --path . res://scripts/dev/StrikeContrastAudit.tscn

  Add `-- --seed=<int>` to any of them for a reproducible run (see
  `scripts/dev/DevSeed.gd`); without it they stay exploratory, which is
  what makes a rare violation eventually surface.
- Persistent local best score (survives relaunch, `user://` via
  FileAccess/IndexedDB on Web) plus a global top-10 leaderboard
  (Firestore REST, project `keepy-8df91`, independent from `keepr-529cc`)
  -- see `scripts/autoload/Leaderboard.gd`. Both degrade gracefully with
  no network: the local record still works offline, and a failed
  submission/fetch just leaves the leaderboard section showing
  "indisponible" instead of blocking the game-over screen.
- `export_presets.cfg` is committed (Web preset only) so CI can build
  headless -- see "Tester le jeu" above. Add further per-platform
  presets locally as needed; the Web preset should stay in sync with
  whatever CI expects.
