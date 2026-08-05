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
  travelled, which also ramps the run speed) plus `noisette_score`
  (collectibles), summed into `GameState.score`. Kept as two separate
  counters specifically so a noisette pickup can never be silently
  overwritten by the next distance-based score tick.

## Adding Meshy assets later

When 3D models are ready:

1. Drop the exported `.glb` file in `assets/models/`, and any
   accompanying textures in `assets/textures/`.
2. Naming convention: `keepy_<subject>_<variant>.glb`
   (e.g. `keepy_player_default.glb`, `keepy_obstacle_rock.glb`,
   `keepy_noisette_gold.glb`), with matching textures named
   `keepy_<subject>_<variant>_albedo.png` / `_normal.png` / etc.
3. In the relevant scene (`Keepy.tscn`, `Obstacle.tscn`,
   `Noisette.tscn`, `TrackSegment.tscn`), replace the placeholder
   `MeshInstance3D`'s mesh with the imported model (or swap the whole
   node for the imported scene, instanced as a child), keeping the
   collision shape's size roughly matched to the new visual so the
   gameplay feel doesn't shift.
4. No script changes should be required -- all gameplay logic reads
   positions and collisions, never mesh geometry directly.

## Known limitations / next steps

- No audio yet (`assets/audio/` is empty).
- No difficulty-curve tuning pass beyond a linear speed ramp
  (`GameState.SPEED_RAMP_PER_METER`).
- No persistent high score (in-memory only, resets on relaunch).
- `export_presets.cfg` is committed (Web preset only) so CI can build
  headless -- see "Tester le jeu" above. Add further per-platform
  presets locally as needed; the Web preset should stay in sync with
  whatever CI expects.
