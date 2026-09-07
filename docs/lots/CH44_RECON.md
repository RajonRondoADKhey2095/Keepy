# CH44 — Préparation minimap : RECON PURE (7 septembre 2026)

> Base : `origin/staging` au commit `998edc7` (fin CH43), arbre
> `3e213e6c89f5bba8f85af60811f98f324b61ed08`. Vérification de concurrence
> faite **au début** : `git fetch --all --prune`, aucune ref distante
> `ch44`/`minimap`, `origin/main` n'est en avance que d'un commit CI et
> son arbre est celui d'avant CH35→CH43.
>
> **AUCUNE ligne de gameplay écrite.** Trois sondes jetables ont été
> créées, exécutées, puis **supprimées avant le commit** ; l'arbre de
> travail est revenu byte-identique à `origin/staging` (`git status`
> vide, même hash d'arbre) avant que ce fichier ne soit ajouté.

## CH44-0 — Le banc, et pourquoi les chiffres d'ici sont mesurés

Godot 4.3.stable.official.77dcf97d8 installé dans le sandbox
(`Content-Length` **50 276 070**, exactement la taille que `CLAUDE.md`
documente — le téléchargement tronqué silencieux a donc été écarté par la
mesure et pas par la confiance). Import complet : **154 `.scn`**, zéro
erreur — c'est le même compte que CH40 publie pour un import complet des
deux côtés (127 `.glb` sous `assets/` + 27 sous `assets_source/`).

Deux régimes, tels que `CLAUDE.md` les impose :

* **headless** pour ce qui ne lit que des transforms (le dump d'arbre, les
  balayages de région) — avec le SubViewport **forcé à 1080 × 1920** et
  `stretch = false` sur son conteneur, et le rect **asserté** : il a lu
  `(1080, 1920)`, donc aucun frustum d'ici n'est celui d'un viewport 0×0 ;
* **`xvfb-run --rendering-driver opengl3`** pour tout ce qui lit un
  compteur moteur — sur le driver dummy les six compteurs sortent à **0**,
  et ce zéro est publié tel quel plus bas.

---

## AXE 1 — La zone est une DONNÉE. Mais le sol peint est une SECONDE ORTHOGRAPHE.

### La fonction

`HubRegion.zone_of()` — `scripts/hub/HubRegion.gd:612-621` :

```gdscript
static func zone_of(point: Vector3) -> int:
	if in_cove(point):    return 4
	if in_circuit(point): return 3
	if in_moor(point):    return 2
	if in_autumn(point):  return 1
	return 0
```

Chaque `in_*()` est **deux tests de rectangle nommés** (`HubRegion.gd:573-594`),
via `_in_rect()` (`:565`). **Aucun seuil codé en dur au fil du code** : la
zone est une donnée déclarée, dans un seul fichier, et l'ordre des tests
est lui-même documenté (la Crique d'abord, parce que son couloir démarre
sur l'arête est de la Lande, `x = 38`, et qu'un point sur cette ligne doit
lire comme le couloir dans lequel il entre).

### Où `zone_of` est réellement lu (production, hors sondes)

**Deux sites, et deux seulement** :

| site | ce qu'il en fait |
|---|---|
| `HubPerfOverlay.gd:239` | la ligne `POS x %.1f z %.1f zone %d` de l'overlay dev |
| `HubWorld.gd:3339-3340` | `_hop_via_corridor` : décide des portes à traverser |

Tout le reste (23 occurrences) est dans `scripts/dev/`.

### ⚠️ Les bornes de la RÉGION et les bornes du SOL PEINT sont deux jeux de littéraux distincts

C'est la réponse qui décide la forme du lot, et elle est **non** :
`CozyScatter` lit bien les constantes de `HubRegion` pour semer
(50 occurrences de `HubRegion.` dans ce fichier), mais **le shader de sol
porte ses propres bords**, écrits en dur dans `CozyPalette` :

| zone | borne LOGIQUE (`HubRegion`) | borne PEINTE (`CozyPalette`) | écart |
|---|---|---|---|
| Vallon (1) | `AUTUMN_MAX.y = -42.0` | `AUTUMN_EDGE_Z = -39.0` (+ `_W = 7.0`) | **3,0 u** |
| Lande (2) | `MOOR_MAX.y = -86.0` | `MOOR_EDGE_Z = -82.0` (+ `_W = 3.0`) | **4,0 u** |
| Circuit (3) | `CIRCUIT_MAX.y = -134.0` | `CIRCUIT_EDGE_Z = -132.0` (+ `_W = 3.0`) | **2,0 u** |
| Crique (4) | `COVE_MIN/MAX` = x[44, 74] z[-130, -90] | `COVE_RECT = (44, -200, 180, -86)` | **couvre 156 u de plus en x** |

Ce sont des **fondus** volontaires (le sol change de teinte avant la
frontière logique, sur une largeur `_W`), et pour la Crique c'est explicite
en commentaire (`CozyPalette.gd:62-65` : le rectangle peint « runs far past
the walkable cove on purpose »). Seule la mer ne l'est pas :
`ground_material()` lit `HubRegion.SEA_CENTRE` / `SEA_RADIUS` (`:342-343`),
un seul propriétaire.

**Conséquence pour le lot** : une carte qui dessine les zones à partir de
`HubRegion` dessinera des frontières qui ne sont pas exactement celles que
le joueur VOIT au sol, de 2 à 4 u. À l'échelle d'une minimap de 250 u de
côté rendue sur 256 px, 4 u valent **4,1 px** — probablement invisible,
mais c'est un arbitrage à poser, pas un détail à découvrir plus tard.

### Liste EXHAUSTIVE des zones, bornes au chiffre près (`HubRegion.gd:501-558`)

| # | nom | rectangle principal | couloir |
|---|---|---|---|
| 0 | le Plateau | *pas un rectangle* — voir AXE 2 | — |
| 1 | le Vallon d'automne | `AUTUMN` x[-33, 33] z[-78, -42] | `CORRIDOR` x[-33, -23] z[-42, -33] |
| 2 | la Lande aux Moulins | `MOOR` x[-38, 38] z[-126, -86] | `MOOR_CORRIDOR` x[6, 18] z[-86, -78] |
| 3 | le Circuit | `CIRCUIT` x[-50, 50] z[-200, -134] | `CIRCUIT_CORRIDOR` x[-14, -2] z[-134, -126] |
| 4 | la Crique | `COVE` x[44, 74] z[-130, -90] | `COVE_CORRIDOR` x[38, 44] z[-100, -92] |

**Mesuré** (balayage 0,5 u sur `zone_of` ∧ `contains`, sonde jetable) :

```
zone 0  x[-63.0,  35.0]  z[ -35.0,  47.0]   24 113 cellules
zone 1  x[-33.0,  33.0]  z[ -78.0, -33.0]    9 965
zone 2  x[-38.0,  38.0]  z[-126.0, -78.0]   12 694
zone 3  x[-50.0,  50.0]  z[-200.0,-126.0]   27 133
zone 4  x[ 38.0,  74.0]  z[-130.0, -90.0]    5 100
```

⚠️ **Le domaine montagne CH38 est DANS LA ZONE 0**, pas une zone à lui :
c'est un terme d'union (`MOUNTAIN_MIN/MAX`, `HubRegion.gd:343-344`) et non
une entrée du graphe — le balayage le confirme (zone 0 descend à x = −63).
`MountainProbe.gd:236` gate exactement ça.

**Le graphe n'est plus une chaîne** : `HubWorld.BRANCH_OF = {4: 2}` et
`BRANCH_GATE = {4: COVE_GATE}` (`HubWorld.gd:3287-3288`) ; les portes sont
`CORRIDOR_GATE (-28, -38.5)`, `MOOR_GATE (12, -82)`,
`CIRCUIT_GATE (-8, -130)`, `COVE_GATE (41, -96)`.

---

## AXE 2 — Aucune constante d'étendue globale. Le cadre est à CRÉER.

`grep` exhaustif : **aucun** `WORLD_MIN`, `WORLD_MAX`, `WORLD_EXTENT` ni
équivalent. `PLATEAU_HALF_EXTENT = 35.0` ne décrit que le carré central et
n'a que 3 lecteurs hors `HubRegion` lui-même.

### Ce qu'il faut agréger — 13 termes d'union (`HubRegion.contains`, `:630-682`)

carré ±35 · `AUTUMN` · `CORRIDOR` · `MOOR` · `MOOR_CORRIDOR` · `CIRCUIT` ·
`CIRCUIT_CORRIDOR` · `COVE` · `COVE_CORRIDOR` · `MOUNTAIN` x[-63,-35]
z[-12,18] · lobe nord (disque centre (0, 35) r 12) · lobes de structure
(1 entrée : centre (25.2, 35) r 3) · shore pad (r 20, **inerte**, entièrement
dans le carré) — moins 3 trous (Arbre-Mère r 2,7 · moulin r 2,1 ·
phare r 1,9).

### Les étendues, MESURÉES (balayage 0,5 u)

| ensemble | x | z |
|---|---|---|
| `HubRegion.contains` (à pied) | **[−63,0 ; 74,0]** | **[−200,0 ; 47,0]** |
| `SandYacht.drivable` (char à voile **et** luge) | [−63,0 ; 74,0] | **[−130,0 ; 47,0]** |
| `HubRegion.in_sea` (le disque mer) | [60,5 ; 155,5] | [−157,5 ; −62,5] |
| eau libre du voilier (`ground_factor == 0`) | [64,0 ; 152,0] | [−154,0 ; −66,0] |
| `KartTrack.fence()` (lu sur l'objet construit) | [−48,5 ; 48,5] | [−198,5 ; −135,5] |
| `SandYacht.WORLD_FENCE` = `SledBody.WORLD_FENCE` = `SailBoat.WORLD_FENCE` | [−220 ; 220] | [−320 ; 320] |

⚠️ **Le voilier sort du monde marchable de 82 u en x.** `SailBoat` n'a
**aucun mur dur** — seulement une traînée (`_ground_pull`, `SailBoat.gd:206`) ;
son unique borne dure est `WORLD_FENCE`, qui est un backstop, pas une
frontière (son propre commentaire le dit, `SandYacht.gd:107-110`). Une carte
cadrée sur `HubRegion` **perdra le voilier hors cadre** dès que le joueur
navigue vers le large.

⚠️ **`SandYacht.drivable` descend à z = −130, pas −126.** Le char et la luge
sont interdits du circuit (`drivable = contains ∧ ¬in_circuit`,
`SandYacht.gd:128-129`), mais la Crique descend à −130 : le calcul « à la
main » (−126, la Lande) est **faux**, et c'est le balayage qui l'a dit.

**Réponse au brief** : le cadre n'existe pas et doit être créé. Le cadre
minimal qui contient tout ce qui est atteignable **à pied ou en véhicule**
(voilier compris, `WORLD_FENCE` exclue comme backstop) est
**x [−63 ; 156], z [−200 ; 47]** — 219 × 247 u, ratio 0,887. Le cadre
« marchable seul » est **137 × 247** (ratio 0,555). **Les deux ne cadrent
pas pareil**, et choisir est un arbitrage à faire en chat, pas ici.

---

## AXE 3 — AUCUN groupe Godot. L'énumération est aujourd'hui obligatoire.

`grep add_to_group` sur tout `scripts/` : **deux** appels, et aucun n'est
dans le hub — `TrackManager.gd:540` (`"track_manager"`, jeu Chased) et
`Keepy.gd:93` (`"player"`, le Keepy de Chased, pas celui du hub). Le seul
groupe du dépôt est `LevelCamera.OCCLUDER_GROUP`, dans `scripts/nav`.
Zéro `groups = [...]` dans les `.tscn`.

### Ce que l'arbre CONSTRUIT contient (dump mesuré, pas déduit)

| classe | n | chemins sous `World` |
|---|---|---|
| `KeepyHopper` | 1 | `Keepy` |
| `SandYacht` | 1 | `Transport/Yacht` (48, −112) |
| `SailBoat` | 1 | `Transport/SailBoat` (65, −110) |
| `SledBody` | 1 | `Transport/Sled` (−49, 4.5, 3) |
| `KartBody` | 4 | `Karting/Kart_0..3` (grille, ~(−9,9 ; −145) → (−8,3 ; −138)) |
| `HubCritter` | **7** | 4 habitants + **3 pilotes** dans `Karting/Kart_1..3/Chassis/Rider` |
| `HubBoar` / `HubCat` / `HubFawn` / `HubBeaver` | 1 ch. | `Critters/Boar` · `/Cat` · `/Fawn` · `/Beaver` |
| `HubActorWalker` | 2 | **`@Node3D@228`** (ours, (0, 37)) et **`@Node3D@230`** (blaireau, (28.96, 7.62)) |
| `HubPortal` | 3 | `Props/HubPortal`, **`Props/@Area3D@10`**, **`Props/@Area3D@11`** |
| `KartTrack` | 1 | `Karting/Track` |
| `ModelSlot` | 2 | `Keepy/Yaw/Body`, `Cove/Burrow/BurrowSlot` |

⚠️ **CITER DES CHEMINS DE NŒUDS EST PIRE QU'UNE DETTE : LA MOITIÉ DES
CHEMINS N'EXISTE PAS.** L'ours et le blaireau ne reçoivent **jamais** de
`.name` (`HubWorld._setup_bear` `:1474-1483`, `_badger` `:2123-2132`) ; deux
portails sur trois non plus. Godot leur donne `@Node3D@228`, `@Area3D@10` —
des noms **dérivés du compteur d'instanciation**, qui bougent au premier
prop ajouté avant eux. La même mesure montre que la quasi-totalité des
75 enfants de `Props` sont dans ce cas (`@Node3D@16`, `@Node3D@22`, …).

**Ce qui EST publié proprement**, et qui est la vraie interface disponible :

* `HubBuilder` : `portals()`, `boat()`, `ziplines()`, `diving_boards()`,
  `spinning_props()`, `seesaws()`, `owls()`, `cabins()`, `pond_centre()`,
  `small_lake_centre()`, `islets()`, `ground_footprints()`, `cozy_trees()`,
  `stream_spine()` ;
* `HubTransport` : `yacht_node()`, `yacht_position()`, `sailboat()`,
  `sled()`, `ball_node()`, `line_count()`, les docks via `LINES` ;
* `HubKarting` : `player_kart()`, `racers`, `track`, `footprints()` ;
* `HubCritters` : `boar`, `cat`, `fawn`, `beaver` (membres typés publics) ;
* `HubCove` : `CASTLE_SPOTS`, `PROPS`, `BUOYS`, `SIGN_AT`, `BURROW_AT` ;
* `HubTrees.TREES` (5 perchoirs) + **54 `Carrier5..58`** (arbres grimpables) ;
* `HubCampfire.SITE` (19.9, 25.4) — **un seul feu**, malgré le nœud `Campfires`.

L'ours et le blaireau n'ont **aucun accesseur public** : `HubWorld._bear` et
`_badger` sont privés. Un marqueur pour eux demande une publication.

### Liste complète de ce qui mériterait un marqueur

**Mobile** : Keepy · char à voile · voilier · luge · balle sauteuse
(`Transport/HopBall`, (0.5 ; 4.4)) · 4 karts · 3 montgolfières
(`Balloon_0..2`) · bateau du ruisseau (`HubBuilder.boat()`) · sanglier ·
chat · faon · castor · ours · blaireau · pie (`Props/.../Magpie`) ·
3 oiseaux d'arbre (`Trees/Bird0..2`).
**Fixe, d'intérêt** : 3 portails (Chased/Quizz/Battle, (−5.4,−4.6) /
(0,−7.2) / (5.4,−4.6)) · cabane (−17.4 ; 28.2) · Arbre-Mère (0, −62) ·
moulin (14, −106) · phare (56, −124) · feu de camp (19.9 ; 25.4) ·
tyrolienne (2 tours) · tourniquet (−4 ; 17.2) · balançoire (0 ; 38.5) ·
3 plongeoirs · 6 docks de montgolfière + 3 pancartes · terrier (47.5 ; −124.5) ·
3 châteaux de sable · pancarte de jonction (35.5 ; −90) · 3 bouées ·
5 perchoirs + 54 arbres grimpables · circuit (`KartTrack.ideal_line()`,
200 échantillons, 230,7 u) · 4 portes de zone · 2 grands lacs, mare, petit
lac, ruisseau, mer.

⚠️ **Je ne garantis PAS cette liste exhaustive.** Elle est bâtie sur le
dump de l'arbre construit **au spawn, météo sun, sans aucune interaction** :
tout ce qui n'existe qu'après un état (un nid tombé, un marqueur de fouille
`DigMarker`, un tas du chat `PileMarker`, une noix au sol `Nuts_*`) n'y est
pas, et le chat se DÉPLACE et se CACHE. Le seul contrôle honnête serait un
second dump après une session de jeu, que cette recon n'a pas faite.

---

## AXE 4 — UN seul point d'insertion suffit. Et le bas de l'écran est libre.

### Il n'y a AUCUN `CanvasLayer` dans `HubWorld.tscn`

La racine est un `Control` plein écran en `mouse_filter = 2` (IGNORE), et
tout est **frère** sous elle. L'ordre de rendu est donc l'ordre de l'arbre
(`scenes/HubWorld.tscn:105-457`) :

`WorldViewport` (SubViewportContainer, `stretch = true`, SubViewport
1080 × 1920, `render_target_update_mode = 4`) → `WeatherOverlay` (ColorRect
plein écran, IGNORE) → `WorldHud` → `KartHud` → *(nœuds non-Control)* →
`FallbackButton` → `FallbackMenu` → `PerfOverlay` → `ConfirmDialog`.

### L'occupation réelle de l'écran

| widget | ancrage | rect (canvas 1080 de large) | quand |
|---|---|---|---|
| `FallbackButton` | TOP_RIGHT | x 884→1048, **y 32→116** | toujours |
| `WorldHud` | TOP_RIGHT | x 840→1048, **y 132→180** | à pied — **caché en conduite** |
| `PerfOverlay` | TOP_LEFT (preset 0) | x 24→700, y 80→268 | dev seulement |
| `KartHud._exit_button` | offset brut | (32, 150) | en conduite |
| `KartHud._panel` | CENTER_TOP | 380 de large centré, y 150 | en conduite |
| `KartHud._position_label` | offset brut | (36, 330) | en course |
| `KartHud._standings_box` | TOP_RIGHT | x −274, y 154 (+4 lignes × 46) | en course |
| `KartHud._clock_label` | TOP_RIGHT | x −274, y 346 | en course |
| jauge d'accélérateur (`_draw`) | bord droit | x = largeur − 60, **hauteur centrée** (260 px) | en conduite hors course |

`HubWorld.gd:3777-3781` et `:3979` : les quatre véhicules **cachent
`WorldHud`** en conduite (`_world_hud.visible = not driving`). Le coin haut
droit est donc partagé — `WorldHud` à pied, `_standings_box` en course.

**Le tiers BAS de l'écran est entièrement libre**, dans les deux modes.
Aucun widget n'y est ancré. Seule chose qui s'y dessine : le fantôme du
doigt (`KartHud._draw`), et il est dessiné **là où le pouce s'est posé** —
n'importe où (`KartTouchInput.gd:197`, `anchor = touch.position`).

### SafeArea : il n'expose AUCUN inset

`scripts/autoload/SafeArea.gd` fait **deux** choses, et ni l'une ni l'autre
n'est un inset exploitable en layout :

1. `_set_color()` peint le fond CSS derrière le canvas (`html`, `body`,
   `#status`) via `JavaScriptBridge` — pure cosmétique de la bande d'encoche ;
2. `fill_screen()` / `keep_game_framing()` basculent
   `window.content_scale_aspect` entre `EXPAND` et `KEEP`.

`HubWorld.gd:672-673` appelle **`set_default()` puis `fill_screen()`** : le
hub tourne donc en **EXPAND**. Conséquence chiffrée par le docblock de
SafeArea lui-même (mesure device 1170 × 2532) : le canvas passe de 1920 à
**~2337** de haut, et **la bande d'encoche (141 px mesurés) est DANS le
canvas** — il n'existe **aucune API dans ce dépôt** qui dise où elle est.
Un widget ancré en haut à moins de ~150 px du bord passe sous l'encoche.
C'est aussi pourquoi `FallbackButton` commence à y = 32 et `WorldHud` à
y = 132 : ce sont des valeurs choisies à la main, pas des insets calculés.

⚠️ **Et le piège `set_anchors_preset` est déjà documenté et déjà payé**
(V7, panneau chrono coupé sur device) : après un preset, `position` est un
**offset depuis l'ancre**. `KartHud` porte le commentaire et la correction
(`:80-90`).

### Réponse : UN point d'insertion

Un `Control` frère sous la racine `HubWorld`, **placé après `WeatherOverlay`**
(pour ne pas être teinté par la couche météo) et **avant ou après `KartHud`
selon la priorité voulue**, est visible à pied ET en véhicule : `KartHud`
est un frère `visible = false` hors conduite, il ne parente rien. Rien
n'est à dupliquer.

⚠️ **Il DOIT porter `mouse_filter = MOUSE_FILTER_IGNORE`.** Le défaut de
`Control`/`PanelContainer` est **STOP** ; `HubTapInput._unhandled_input` et
`KartTouchInput._unhandled_input` tournent tous deux **après** le picking
GUI. Un widget laissé au défaut avalerait le tap sous lui à pied **et**
l'ancre de direction en conduite — la panne exacte que `HubTapInput.gd:38-45`
documente.

---

## AXE 5 — Les trois approches, CHIFFRÉES sur le même banc

⚠️ **Le 55 722 du brief n'est PAS reproductible ici, et je ne le recopie
pas.** C'est une lecture **device** de Mathieu (CH38, ligne `TRI gpu` de
l'overlay, au spawn). Ce sandbox n'a pas de GPU : il rend sous llvmpipe via
xvfb, ce qui est un **autre renderer**, avec un autre LOD automatique. Ce
que je publie est mesuré **sur ce banc-là** — celui que CH38 et CH40 ont
eux-mêmes utilisé pour leurs deltas.

### Référence, hub tel que livré (spawn (0,0), sun, 1080 × 1920, xvfb + opengl3)

| lecture | valeur |
|---|---|
| `engine_prims` (SubViewport 3D — la ligne `TRI gpu`) | **70 493** |
| `engine_calls` / `engine_objects` | **295** / 295 |
| `engine_total_prims` (TOUS viewports) | **71 567** |
| `engine_total_calls` | **311** |
| `tris_frame` (replay frustum LOD0) | 255 229 |
| `tris_scene` | 341 833 |
| nœuds dessinables : `nodes_frame` / `nodes_scene` | 424 / 699 |
| recensement : `MeshInstance3D` / `MultiMeshInstance3D` sous `World` | **357** / **358** |
| pixel central de la capture (blind check, pas du noir dummy) | (0.89, 0.808, 0.612) |

**Le coût TOTAL de la couche 2D existante est donc de 71 567 − 70 493 =
1 074 primitives et 311 − 295 = 16 draw calls** (quad du
SubViewportContainer + WeatherOverlay + WorldHud + PerfOverlay +
FallbackButton, overlay dev visible hors-web).

### ⚠️ Aucune des trois approches ne bougera la ligne que Mathieu LIT

`HubPerfOverlay.snapshot()` lit `engine_prims` sur le **RID du SubViewport
3D** (`:92-96`). Une minimap en 2D vit dans le viewport racine : elle
n'entre **jamais** dans `TRI gpu`. Elle entre dans `engine_total_prims` /
`engine_total_calls` (`:97-98`) — **qui sont collectés mais que `_format()`
n'imprime PAS** (`:229-241`). Sur device, une minimap 2D serait donc
**invisible à tous les compteurs affichés**. Une minimap par SubViewport
serait invisible de la même façon.

### Les trois options, mesurées (plancher de bruit **0 prim / 0 call** entre deux frames intouchées)

| approche | Δ `engine_total_prims` | Δ `engine_total_calls` | Δ ligne `TRI gpu` |
|---|---|---|---|
| **`TextureRect` 256 × 256** | **+2** | **+1** | 0 |
| **`Control._draw`** — 40 cercles + 24 lignes + 2 rects | **+2 619** | **+43** | 0 |
| …le même, `queue_redraw()` à **chaque frame** | **+0** | **+0** | 0 |
| **`SubViewport` 256 × 256, caméra ORTHO 250 u, `world_3d` partagé** | **+74 085** | **+421** | 0 |
| …le même, `render_target_update_mode = UPDATE_DISABLED` | **0** | **0** | 0 |

Ce qu'il faut lire dedans, et qui n'était pas évident :

* **`draw_circle` ne se batche pas.** 43 draw calls pour 40 cercles : c'est
  **un draw call par marqueur**. Le coût d'un `_draw` est linéaire en
  nombre de marqueurs, pas en surface.
* **Redessiner ne coûte rien de plus.** C'est le nombre de commandes qui
  coûte, pas la fréquence : `_draw` à 60 Hz et `_draw` une fois donnent
  exactement les mêmes compteurs. La question « redessinée chaque frame ? »
  est donc **sans objet** pour ces deux compteurs. *(Ce banc ne mesure PAS
  le temps CPU du corps de `_draw` lui-même — voir la limite ci-dessous.)*
* **Le SubViewport ORTHO coûte PLUS CHER QUE LA VUE PRINCIPALE**
  (+74 085 contre 70 493) : une caméra orthographique qui couvre les 250 u
  de la carte a **tout** dans son frustum, et aucune réduction par
  distance. La taille du rendu (256 px) n'y change rien — c'est le
  **volume soumis** qui coûte, pas la résolution.
* **Et il se coupe entièrement** : `UPDATE_DISABLED` rend exactement la
  ligne de référence. Un rendu **à la demande** (`UPDATE_ONCE`) coûte zéro
  sur toutes les frames où il ne rafraîchit pas — c'est le seul chemin par
  lequel l'approche SubViewport redevient abordable.

### Ce que ce banc NE dit PAS

* **Rien du device.** llvmpipe/GL de bureau contre WebGL2 sous Safari : deux
  compilateurs, deux pilotes, et `CLAUDE.md` documente déjà un cas où ce
  dépôt est passé vert ici et cassé là-bas. Les *rapports* entre les trois
  options devraient traverser ; les valeurs absolues, non.
* **Rien du temps CPU.** Les compteurs comptent des primitives et des
  appels, pas des millisecondes. Un `_draw` qui recalcule 60 positions de
  marqueur par frame en GDScript a un coût CPU que ce banc ne voit pas.
* **Rien sur la mémoire** du render target d'un SubViewport.

---

## AXE 6 — Persistance du char à voile : où elle vit, et ce que la retirer coûte

### Le mécanisme

`user://keepy_world.json` (IndexedDB sur le web), un seul écrivain,
l'autoload `WorldSave` (`SAVE_PATH`, `:54`). Schéma **2**
(`SCHEMA_VERSION`, `:61`). Le champ :

```
"cove": {"yacht": [x, z] | null, "castles": {...}, "visited": bool}
```

* **écrit** : `HubTransport.exit_yacht()` → `WorldSave.cove_set_yacht(at)`
  (`HubTransport.gd:599`) — « où il descend est où le char sera » ;
* **lu** : `HubTransport._build_yacht()` (`:333-341`), avec un garde
  `SandYacht.drivable(saved)` qui renvoie au park un char sauvé sur la
  grille de karting (le cas que Mathieu a réellement produit).

### La constante de spawn EXISTE déjà

`HubTransport.YACHT_PARK = Vector3(48.0, 0.0, -112.0)` (`:94`), avec un cap
initial `PI / 2` (nez vers la mer). Mesuré :
`HubRegion.shore_distance(YACHT_PARK) = 12,033` — **12 u de sable sec, au
bord de la mer**. C'est exactement le « respawn au niveau de la mer »
demandé ; **rien de nouveau n'est à créer**.

### Les autres véhicules ne partagent RIEN

| véhicule | position persistée ? | où il réapparaît |
|---|---|---|
| char à voile | **OUI** (`cove.yacht`) | où il a été laissé |
| voilier | **non** (explicite, brief CH33) | `SAILBOAT_MOORING (65, −110)` |
| luge | **non** (explicite, brief CH41) | `SLED_PARK (−49, 3)` = sommet |
| balle sauteuse | non — règle « hors champ » | `BALL_PARK (0.5, 4.4)` |
| karts | non | grille, `KartTrack.start_pose()` |
| montgolfières | non — règle « hors champ » | dock 0 de leur ligne |

`grep WorldSave. scripts/hub/` : `cove_set_yacht` / `cove_yacht` sont les
**seuls** appels de position de véhicule du dépôt. Retirer la persistance du
char **ne peut pas casser les trois autres** : ils n'ont rien à casser.

### Le coût de la suppression, appelant par appelant

| fichier | lignes | ce qu'il devient |
|---|---|---|
| `WorldSave.gd:188-198` | 11 | `cove_yacht()` et `cove_set_yacht()` supprimées |
| `WorldSave.gd:233` | 1 | `_cove_defaults()` perd `"yacht": null` |
| `WorldSave.gd:489-496` | 8 | la branche de `_sanitise` disparaît |
| `WorldSave.gd:26`, `:182-185` | ~5 | docblocks du schéma |
| `HubTransport.gd:333-341` | 9 | `_build_yacht` fait `place(YACHT_PARK, PI/2)` — **2 lignes** |
| `HubTransport.gd:599` | 1 | l'écriture disparaît d'`exit_yacht` |
| `HubTransport.gd:87-90` | 4 | le docblock « où il est laissé, il reste » s'inverse |
| `CoveProbe.gd` | 8 sites | `:306`, `:315`, `:323`, `:336`, `:695`, `:722`, `:752`, `:897` |

**Ordre de grandeur : ~40 lignes de production retirées, ~10 ajoutées ;
8 assertions de sonde à réécrire.** Un lot court.

⚠️ **`yacht_rides` (le compteur de trajets, `HubTransport.gd:573`) est un
STAT, pas une position** : il reste, il est dans `STAT_KEYS` (`:179`), et
le confondre avec la persistance de position casserait un compteur que rien
ne demande de retirer.

⚠️ **Pas de bump de schéma nécessaire, mais un choix à poser.** Retirer la
branche de `_sanitise` fait tomber la clé au premier réécrit — une save
existante n'est jamais rejetée (le sanitiseur laisse tomber ce qu'il ne lit
pas, `:429-434`). Bumper à 3 pour l'annoncer serait plus explicite mais
coûte une entrée dans `_migrate` **et** dans les fixtures de `V4SaveProbe`
qui nomment `SCHEMA_VERSION` plutôt qu'un littéral. **Arbitrage à faire en
chat.**

⚠️ **Le garde `drivable` disparaît AVEC la persistance, et c'est correct** :
il n'existait que parce qu'une save pouvait porter un point illégal
(`HubTransport.gd:334-337`). Sans save, `YACHT_PARK` est légal par
construction — mais `CoveProbe` PHASE yacht `:695-700` teste exactement ce
garde, donc cette assertion doit être **retirée**, pas adaptée. Une
assertion qu'on adapte pour qu'elle reste verte est une assertion qu'on
fait taire.

---

## Ce que cette recon N'A PAS établi

1. **Aucun chiffre device.** Le `TRI gpu` réel d'un iPhone reste inconnu ;
   `55 722` est une lecture de CH38 que ce sandbox ne peut ni confirmer ni
   réfuter.
2. **L'exhaustivité de l'inventaire AXE 3** repose sur un dump au spawn
   sans interaction (voir l'avertissement de l'AXE 3).
3. **Le coût CPU** d'un `_draw` de minimap (calcul des positions de
   marqueur) n'est pas mesuré — seuls les compteurs de rendu le sont.
4. **La lisibilité** d'une minimap sous les quatre météos n'est pas
   évaluée. `CLAUDE.md` documente que le WCAG ne sépare rien à l'intérieur
   d'une bande de luminance et qu'aucune sonde du dépôt ne mesure la teinte.
5. **CH36 n'a pas de dossier** sous `docs/lots/` : la ligne POS de
   l'overlay est racontée dans `docs/CARTE_BLANCHE_JOURNAL.md:1729-1740`
   et l'index range CH36 sous la ligne CH35. Signalé, **non corrigé** —
   une recon ne réorganise pas l'index.

## Ce qu'on s'est retenu de corriger

* `CozyPalette.AUTUMN_EDGE_Z` et ses trois jumelles pourraient dériver de
  `HubRegion` (`AUTUMN_MAX.y + 3.0`) au lieu d'être des littéraux. **Non
  touché** : ce sont des bords de FONDU, pas des bords logiques, et les
  lier changerait le rendu du sol dans un lot qui ne doit rien changer.
* `HubPerfOverlay._format()` pourrait imprimer `engine_total_prims` /
  `engine_total_calls`, qu'il collecte déjà. **Non touché** — mais c'est
  la ligne qu'il faudra pour qu'une minimap soit mesurable sur device, et
  elle coûte une ligne.
* L'ours et le blaireau pourraient recevoir un `.name` et un accesseur.
  **Non touché** : c'est du gameplay, et c'est au lot d'implémentation.
