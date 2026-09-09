# CH55 — Fondation physique du hub : RECON PURE

**9 septembre 2026.** Lot de **conception seule**. Aucun collider ajouté,
aucune scène modifiée, aucun script de gameplay touché, aucune sonde créée
ni supprimée. Le livrable est ce fichier.

---

## 0. LA BASE, ET LA GARDE DE CONCURRENCE

Branche ouverte sur `main` (`2876f27`) et **avancée en fast-forward sur
`origin/staging`** (`8374145`) avant la première lecture : **CH50 à CH54
vivent sur `staging` et `main` ne porte NI `HubSkatepark.gd`, NI
`SkateparkMesh.gd`, NI `SkateHud.gd`, NI le lobe r=28.** Une recon menée
sur `main` aurait lu un hub où le sujet du brief n'existe pas.
`merge-base --is-ancestor main origin/staging` → vrai : un retard, pas une
divergence.

Garde faite **au début et par ARBRE**, jamais par nom :

| ref | verdict |
|---|---|
| `origin/claude/keepy-hub-physics-foundation-siqdqo` | pointait sur `main`, arbre `9a1d2a9` = celui de `main`, **aucun travail dessus** |
| `origin/claude/skateboard-drivability-north-lgmqk8` | ancêtre de `staging` → **déjà mergée** (CH54) |
| `origin/claude/skatepark-modules-budget-nord-v5a3id` | ancêtre de `staging` → **déjà mergée** (CH53) |
| `origin/claude/skatepark-trick-minijeu-xyuy9a` | ancêtre de `staging` → **déjà mergée** (CH51) |
| grep `phys|found|collid|character|rigid` sur toutes les refs distantes | **une seule** hors la mienne (`keepy-five-new-characters`, sujet sans rapport) |

Aucune session concurrente vivante.

---

## 1. RECENSEMENT DE L'EXISTANT

### 1.1 Fichiers lus intégralement ou par plages ciblées

`KeepyHopper.gd` (2 391 l.) · `HubTapInput.gd` (546) · `HubRegion.gd` (872)
· `HubSurface.gd` (369) · `HubTransport.gd` (1 025) · `HubSkatepark.gd`
(404) · `SkateparkMesh.gd` (419) · `HubWorld.gd` (4 677, par plages) ·
`HubWorld.tscn` (489) · `HubPortal.gd` + `HubPortal.tscn` · `HubBuilder.gd`
(en-tête) · `CozyScatter.gd` (`_sprinkle`, `_forest_wall`, `_blocked`) ·
`kart/VehicleDrive.gd` (228) · `SandYacht.gd` · `SledBody.gd` ·
`HubKarting.gd` (en-tête) · `HubNuts.gd` (en-tête) · `nav/LevelDefinition.gd`
· `nav/LevelCamera.gd` · `player/Keepy.gd` + `scenes/Keepy.tscn` ·
`world/Hitboxes.gd` · `track/TrackSegment.gd` · `project.godot` ·
`export_presets.cfg` · `docs/lots/CH51`, `CH52`, `CH53`, `CH54`, `CH50`,
`CH38`.

### 1.2 ⚠️ LA PRÉMISSE « AUCUN COLLIDER NULLE PART » EST FAUSSE, ET DEUX FOIS

**Le brief demandait de vérifier par lecture plutôt que de croire le
rapport CH51. La vérification a trouvé deux choses que CH51 §1.3 ne dit
pas.**

**(a) Il y a TROIS colliders dans le hub aujourd'hui, et ce sont les
portails.** `scenes/HubPortal.tscn` est un **`Area3D`** portant un
**`CollisionShape3D`** (`CylinderShape3D`, rayon **1,35**, hauteur
**3,0**, centre y = 1,5), instancié **3 fois** depuis
`resources/hub/hub_layout.tres`. Ils sont **délibérément inertes** —
`HubPortal._ready()` pose `monitoring = false` et `monitorable = false`,
et l'en-tête explique pourquoi le `body_entered` est refusé (un hop
traverse le volume en plein vol, un portail déclenché par recouvrement
avalerait un joueur qui ne fait que passer). **Et la forme est gardée
comme SOURCE UNIQUE du rayon** : `_ready()` lit `cylinder.radius` et
`push_error` si la forme n'est pas un cylindre.

> **C'est la base à réutiliser que le brief demandait de signaler.** Le
> patron « une forme de collision est la source de vérité de la géométrie,
> et l'événement physique est refusé » est déjà écrit, déjà gaté, déjà
> livré. `HubSkatepark.landed_within()` en est la copie explicite
> (« HubPortal's exact shape »), sans la forme.

**(b) Il y a un moteur physique Godot complet et validé AILLEURS dans le
dépôt : Keepy Chased.** `scenes/Keepy.tscn` est un **`CharacterBody3D`**
(`collision_layer = 2`, `collision_mask = 1`, `CapsuleShape3D` r 0,5 /
h 1,6) et `scripts/player/Keepy.gd` fait `move_and_slide()` en
`_physics_process`, avec `GRAVITY = 26.0`, `JUMP_VELOCITY = 9.0` et un
dégagement de saut **dérivé** (`JUMP_PEAK_HEIGHT = v²/2g = 1,558 u`).
`scenes/TrackSegment.tscn` est un `StaticBody3D` et `scenes/Obstacle.tscn`
un `Area3D`. Et `scripts/world/Hitboxes.gd` est **le contrat unique des
dimensions de collider**, réécrit sur les formes à chaque `_ready()` parce
que « les constantes sont la source de vérité, les scènes ne le sont pas ».

> **Conséquence pour ce lot : la fondation ne s'invente pas, elle se
> transpose.** Chased a déjà le patron `CharacterBody3D` + `StaticBody3D` +
> un fichier propriétaire des dimensions + un audit
> (`AssetContractAudit`) qui re-mesure chaque collider après avoir
> installé un modèle de substitution. Rien de tout cela n'existe côté hub,
> et rien de tout cela n'a besoin d'être écrit deux fois.

**Ce qui reste vrai de CH51 §1.3, vérifié à la lecture** :

* **aucun `PhysicsBody3D` n'est jamais construit dans le hub** — grep
  `(CharacterBody3D|RigidBody3D|StaticBody3D|Area3D|CollisionShape3D).new()`
  sur `scripts/hub`, `scripts/nav`, `scripts/world`, `scripts/cabin` :
  **zéro résultat** ;
* **aucune requête physique nulle part** — `intersect_ray` n'apparaît en
  production que comme `HubSurface.intersect_ray()`, qui est une **marche
  de rayon arithmétique** sur la grille (`RAY_STEP` 0,25, 6 bissections,
  `RAY_MAX_T` 200), pas un `PhysicsDirectSpaceState` ;
* **le sol n'est pas un collider** : `HubTapInput._handle_point` projette
  le rayon caméra et interroge `HubSurface`, jamais l'espace physique ;
* `HubBuilder.gd` l'affirme et le dit grepé : *« tree / rock / bush /
  flower / stump / pond / lake / stream / boat have never had a
  CollisionShape3D — grepped, not assumed. […] The only Area3D on this
  screen belongs to HubPortal »* ;
* `nav/LevelCamera.gd` et `nav/LevelDefinition.gd` refusent explicitement
  d'ajouter *« this project's FIRST navigation collider »* et donnent la
  raison : *« a physics tick a probe would then have to pump »*.

### 1.3 ⚠️ ET IL Y A DÉJÀ UN `move_and_slide` ÉCRIT À LA MAIN, SUR TROIS VÉHICULES VALIDÉS DEVICE

`kart/VehicleDrive.step()` est un **intégrateur de vitesse par frame
complet** appelé depuis `_physics_process` (`HubKarting:542`,
`HubTransport:966`) : braquage sur le cap, décomposition avant/latéral,
adhérence exponentielle, scrub, frein, marche arrière, `position +=
velocity * delta`, `position.y = 0.0`, et une **clôture `Rect2` avec
rebond** (`fence_bounce`) sur les quatre côtés.

Et la réponse au mur est, littéralement, un `move_and_slide` à deux axes :
`SandYacht._wall()` / `SledBody._wall()` essaient (1) le pas complet,
(2) **x seul** en annulant `velocity.z`, (3) **z seul** en annulant
`velocity.x`, (4) refus avec `velocity = -velocity * WALL_BOUNCE`. Le
prédicat de mur est **`HubRegion.contains()`**, une fonction analytique —
donc un « collider » sans collider.

> **Le hub n'a pas « pas de physique ». Il a une physique cinématique
> maison, sur trois véhicules, dont deux validés sur device par Mathieu
> (CH30 char à voile, CH33 voilier, CH41 luge).** Toute fondation
> standard devra dire ce qu'elle fait de celle-là : la remplacer est une
> régression sur du code validé device (règle CLAUDE.md sur les modes
> partagés), la laisser est **deux systèmes de collision** dans le même
> monde.

### 1.4 Tous les sites qui bornent un déplacement SANS collision, aujourd'hui

**Le bornage de destination — `HubRegion.clamp_to()`, 11 appels en
production :**

| site | ce qu'il borne | redondant / conflictuel avec un vrai collider ? |
|---|---|---|
| `HubTapInput:399` | **LE** site : un tap devient une destination | **ni l'un ni l'autre.** Un clamp répond « où peut-il se TENIR » ; un collider répond « qu'est-ce qui l'arrête en route ». Les deux questions restent distinctes (doctrine AIM vs DESTINATION CLAMPÉE) |
| `HubWorld:3340` `_hop_via_corridor` | la destination finale, après les portes de zone | inchangé |
| `HubWorld:1756` | le point de berge de `leave_ride()` — **le seul site du dépôt qui passe `blocked` à `_is_clear`** | **redondant** si les props ont des colliders ; à laisser tel quel (il choisit un point, il n'évite pas une trajectoire) |
| `HubKarting:391/393` | le point de dépose en sortant du kart | inchangé |
| `HubTransport:850` `_step_off` | idem pour les quatre autres véhicules | inchangé |
| `HubBoar:326/327`, `HubFawn:263/365/372` | les cibles de marche des PNJ | **conflictuel à terme** : un PNJ qui marche vers un point atteignable mais bloqué se coincerait ; aucun PNJ n'a de collider dans aucun plan ci-dessous |
| `LevelController:175` (`LevelDefinition.clamp_to`) | le tap dans la cabane, autre plan d'altitude | inchangé |

**Le bornage de trajectoire — il n'en existe QUE trois formes, et aucune
n'est une collision :**

1. **`HubRegion._holes`** — trois disques soustraits de `contains()` :
   tronc de l'arbre-mère, moulin, phare. Ils agissent sur **la
   destination** (`contains` / `clamp_to`), **jamais sur la trajectoire** —
   `LevelDefinition.gd:60` le dit en majuscules pour son propre trou.
2. **`HubRegion.contains()` comme MUR DUR** pour les trois véhicules pilotés
   (`SandYacht.drivable`, `SailBoat`, `SledBody.drivable`) via `_wall()`.
   **C'est le seul endroit du hub où quelque chose arrête réellement un
   corps en mouvement.**
3. **Les empreintes au moment de la CONSTRUCTION** — `CozyScatter._blocked(p,
   own_radius)` refuse un candidat qui chevauche une empreinte publiée par
   `HubTransport.footprints()`, `HubCove.footprints()`,
   `HubSkatepark.footprints()`, `HubTrees.footprints()`, le circuit, les
   chemins, l'eau. **C'est de la non-interpénétration résolue une fois, à
   la pose, et un vrai collider ne la remplace pas** : elle empêche deux
   props de se chevaucher visuellement, ce qu'aucune physique de
   personnage ne fait.

**Et rien ne dévie un hop.** `_advance()` calcule `delta = _target − here`
en **XZ**, `_begin_hop` fait `_hop_to = here + delta.normalized() * step`,
et le tween écrit `global_position` : **une marche va tout droit et ne
consulte rien.** `_is_clear(point, blocked)` existe mais n'est nourri
qu'une fois dans tout le dépôt.

### 1.5 Le sol, et qui le possède

`HubSurface` est **le propriétaire publié de la hauteur du sol** :
`height_at(flat)` → `ground(flat)` → `gradient_at` → `normal_at`, sur une
grille `PackedFloat32Array` par domaine, avec la **même triangulation que
le maillage dessiné** (« les pieds atterrissent sur le triangle que le
joueur voit »). Un seul domaine est enregistré en jeu : `HubMountain`, la
crête ouest (`MOUNTAIN_MIN/MAX`, x [−63, −35], z [−12, 18]). Partout
ailleurs `height_at ≡ 0,0` **par contrat**.

> **C'est le point d'architecture le plus lourd de ce lot.** Un moteur
> physique veut posséder le sol (une forme, un plancher, une normale). Ce
> dépôt a déjà un propriétaire du sol, il est arithmétique, il est publié,
> et CH37 existe précisément pour qu'il n'y en ait qu'un. **Deux
> orthographes du sol est la faute que ce dépôt paie le plus souvent**
> (deux `LAKE_WATER_RADIUS`, un pas de porte qui ne scalait pas, un
> `SEAT_MAX_Y` faux de 1,008 u pendant deux lots).

### 1.6 Ce que le monde contient de mobile, et ce qu'il contient de batché

* **Corps mobiles simultanés attendus** : Keepy (1) + 4 karts (joueur +
  `OPPONENTS` = 3) + 3 montgolfières (`LINES`) + Sautillon + char à voile +
  voilier + luge + planche + 4 critters (sanglier, chat, faon, castor) +
  ours + blaireau + pie + hibou ≈ **21**, plus les noisettes en vol
  (intégrateur maison, nombre variable).
* **Décor** : batché en `MultiMeshInstance3D` par paire (mesh, couleur) —
  **306 batches de décor au sol publiés par `CozyScatter.batch_nodes()`**
  (CH52), 945 instances d'herbe après la garde CH53, ~4 572 instances au
  total (`COZY_STATS`).

> ⚠️ **UN `MultiMesh` NE PEUT PAS PORTER DE COLLIDER.** Il n'y a pas de
> collision par instance en Godot. Tout prop qui doit devenir solide doit
> **quitter son batch** et devenir un nœud individuel — c'est-à-dire
> **un draw call de plus chacun**. Et CH52 §8.3 conclut que le budget
> disponible au bord nord est de **zéro primitive et zéro draw call**.
> **Le coût d'une collision sur le décor du hub n'est pas d'abord un coût
> de simulation : c'est un coût de DRAW CALLS, et il n'y en a pas un
> seul à dépenser.**

---

## 2. MODÈLE DE COHABITATION — hop et physique

### 2.1 Les deux modèles ne se mélangent pas dans une frame, mais ils se relaient déjà douze fois

`KeepyHopper.State` a **douze** valeurs (`IDLE, HOPPING, RIDING, CLIMBING,
ON_BOARD, DIVING, ON_TURNSTILE, ON_SEESAW, ON_OWL_FLIGHT, ON_ZIPLINE,
ON_CARRIER, ON_TREE`). L'en-tête du RIDING donne la doctrine du dépôt mot
pour mot : *« A third state, not a second movement system. […] RIDING
replaces where the body is written from »*. Et `hop_to()` **refuse** depuis
tout état autre que `IDLE`/`HOPPING`.

**Un mode physique est donc un treizième état, pas un second système.** Ce
n'est pas une opinion : c'est le seul patron que ce fichier connaisse, et
`_advance()` / `_begin_hop()` sont intacts après onze applications.

### 2.2 Deux formes possibles, et elles n'ont pas le même prix

**Forme A — `KeepyHopper` DEVIENT un `CharacterBody3D`.**
`move_and_slide()` n'est appelé que dans l'état physique ; ailleurs le nœud
se comporte comme un `Node3D` écrit par des tweens.
*Le piège, et il est structurel* : **le collider existe dans TOUS les
états.** Un corps qui grimpe un arbre, pend d'une tyrolienne ou est assis
sur une balançoire porterait une capsule dans l'espace physique, où elle
bloquerait et serait bloquée. Il faudrait donc éteindre
`collision_layer`/`collision_mask` par état — **une propriété de plus à
gater sur douze états**, et le mode de panne est silencieux.
*Et c'est la seule forme qui touche la garantie de traversée* (§3).

**Forme B — le collider appartient au PORTEUR, jamais au personnage.**
Le repo a déjà le contrat : `mount_carrier(carrier, seat)` /
`follow_carrier()` / `leave_carrier(landing)`, appliqué à la montgolfière,
au hibou, à la tyrolienne, à l'ours, et **« carrier-then-carried, in the
SAME call »** (`HubTransport._physics_process` : le véhicule se pilote, puis
`_keepy.call("follow_carrier")` immédiatement, jamais une frame plus tard).
Une planche physique serait un `CharacterBody3D` que `_physics_process`
avance, et Keepy est **écrit** sur son siège.
*Ce que ça achète* : le personnage n'acquiert **aucun** collider ; les onze
autres états ne bougent pas d'une ligne ; la garantie de traversée est
intacte **par construction** (le hopper n'est jamais un corps physique) ;
la transition est le `mount`/`dismount` déjà validé sur quatre véhicules.
*Ce que ça ne couvre pas* : « Keepy à pied cogne un mur ». C'est la forme A,
et c'est une décision séparée.

> **Recommandation : B d'abord, A jamais sans son propre chantier.** B est
> une fondation réutilisable au sens du brief — tout véhicule, tout module,
> tout prop solide y passe — et elle est *additive*. A est une migration du
> modèle de déplacement du joueur : c'est CH18 (treize sections) dans une
> autre dimension.

### 2.3 La frontière : **c'est un ÉTAT, jamais une géographie**

Le brief demande ce qui se passe au bord du disque nord. **Réponse : rien,
et il faut que ce soit rien.**

Une frontière géographique (« physique dedans, hop dehors ») exige de
commuter le composant actif du joueur **au milieu d'une marche**, à un
moment décidé par une position. Ce dépôt n'a **aucun** patron pour ça, et
il en a un excellent pour l'autre : les portes de zone
(`HubWorld._gates_between`, `_hop_via_corridor`) ne changent pas le
composant, elles insèrent des **étapes** dans la file de marche.

La frontière du mode physique est donc `mount` / `dismount` :
`is_on_vehicle()` est vrai ou faux, et `HubTapInput` a déjà **une condition
par VÉHICULE PILOTÉ** (`karting.is_driving()`,
`transport.is_driving_yacht()`, `is_driving_sailboat()`) qui court-circuite
tout le routage de tap. Le mode physique en ajoute une, à la même place.

⚠️ **Un défaut connu à contourner, pas à corriger dans ce chantier** :
`leave_carrier()` sur une distance non nulle n'émet **ni `became_idle` ni
`carrier_dismounted`** — seulement `hop_landed` (CLAUDE.md, *signalé et non
corrigé* : le changer toucherait deux conduites validées device). Toute
transition **lit l'ÉTAT** (`is_on_carrier` / `is_on_vehicle` / `is_hopping`),
jamais le signal.

---

## 3. IMPACT SUR LES GARANTIES EXISTANTES

### 3.1 La garantie de traversée, et le chiffre exact de sa marge

Chiffres sourcés, pas répétés (`CH50_ZONE0_NORD.md` §, tableau de la
traversée marchée sur le vrai `KeepyHopper`) :

| trajet | longueur | frames | secondes | plafond |
|---|---|---|---|---|
| pire paire créée par CH50 (−63, −12) → (22,43 ; 51,74) | 106,590 u | 1 207 | **20,117 s** | 22,0 |
| **pire paire du hub**, témoin CH38 (35, −35) → (−63, 18) | 111,414 u | 1 258 | **20,967 s** | 22,0 |
| contrôle : diagonale publiée | 98,995 u | 1 122 | **18,700 s** | — |

Taux publié : **0,18890 s/u**.

> **La marge est de 22,0 − 20,967 = 1,033 s, soit 62 frames à 60 Hz, soit
> — au taux du dépôt — 5,469 u de CHEMIN SUPPLÉMENTAIRE. Toute la
> garantie tient dans 5,5 u de détour, sur une traversée de 111,4 u.**
> (La paire CH50 en offre 9,968 u ; c'est la paire CH38 qui contraint.)

Les deux cas que le brief demande de chiffrer :

**Cas 1 — les colliders ne sont actifs QU'EN MODE PHYSIQUE (forme B).**
Le hopper n'est jamais un corps physique ; un tween écrit
`global_position` et **aucun collider n'est consulté par un tween**.
**Risque sur la traversée : nul, et il est structurel, pas statistique.**
Rien à re-marcher, rien à re-mesurer. C'est la propriété qui justifie à
elle seule de recommander B.

**Cas 2 — le pied devient physique (forme A).**
Chaque collider devient un détour potentiel, et **20,967 s devient une
borne INFÉRIEURE** : un corps qui glisse le long d'un mur couvre moins de
sol par tick qu'un corps qui va tout droit. Le budget entier est de
**5,469 u**. Deux aggravations mesurées se cumulent dessus :

* **la pire paire traverse la crête ouest** (x = −63 est dans
  `MOUNTAIN_MIN/MAX`), le seul relief réel de la carte. `_advance()`
  mesure le pas **en XZ** ; sur une pente le sol parcouru par hop reste
  1,5 u XZ aujourd'hui parce que le tween ne suit pas la surface, mais un
  `move_and_slide` avec `up_direction` réelle **perd** de l'avance XZ dans
  la montée. Ce terme n'est pas chiffré ici et il n'est pas nul ;
* **les pentes du relief vont jusqu'à 30°** (plafond CH35-C pour un sol
  marchable), et deux bosses qui se recouvrent ont mesuré **33,0°** (CH38).
  `floor_max_angle` par défaut vaut 45°, donc rien ne glisse — mais chaque
  degré de pente coûte du `cos θ` sur l'avance XZ.

> **Verdict chiffré du cas 2 : un seul obstacle qui impose plus de 5,5 u
> de détour cumulé sur la paire CH38 casse le plafond de 22,0 s, et il n'y
> a aucun budget pour un second.** La forme A n'est donc pas décidable sans
> (a) un choix explicite de Mathieu sur le plafond, ou (b) la règle
> « aucun collider bloquant sur le sol marchable » — auquel cas la forme A
> n'apporte rien que la forme B n'apporte déjà.

### 3.2 `_forest_wall` et `_sprinkle` : **inchangés, et c'est eux qui sauvent le plan**

* **`_sprinkle`** (`CozyScatter:318`, `:457`) refuse tout candidat
  **hors** `HubRegion.contains()` : il sème **DANS** la région (herbe,
  fleurs, feuilles, cailloux, champignons, buissons, rochers). Ces objets
  sont, par construction, **sur le chemin du joueur**. Leur donner des
  colliders est exactement ce qui ferait exploser les 5,469 u — et ils sont
  batchés, donc **impossibles à collider sans les débatcher** (§1.6).
  → **Règle qui en découle, et elle est permanente : le semis au sol
  n'acquiert JAMAIS de collider.** Il n'en a pas ; il n'en aura pas.
* **`_forest_wall`** (`:1036`, `:1061`) refuse tout candidat où
  `contains()` est vrai **ou** à moins de `WALL_CLEARANCE = 2,0` u de la
  région. Le mur se tient donc **hors** du monde jouable, avec 2 u de
  dégagement mesuré (CH50 : le plus proche arbre à 2,161 u).
  → **Inchangé, et rendu redondant par avance** : la limite du monde est
  déjà tenue par `clamp_to`, et un éventuel collider de bord se tiendrait
  **entre** le joueur et le mur. Les arbres du mur n'ont jamais besoin
  d'être solides.
* **`_blocked()`** (empreintes à la pose) : **ni redondant ni
  conflictuel.** Il répond « deux props se chevauchent-ils » à la
  construction ; aucune physique de personnage ne répond à cette question.
  Il reste, et il reste le seul.

### 3.3 Les autres garanties touchées

| garantie | effet |
|---|---|
| **`HubPortal.landed_within`** — un portail ne répond qu'à un ATTERRISSAGE | **à préserver littéralement.** Un mode physique produit des contacts continus ; brancher un portail dessus rouvrirait le défaut que l'en-tête refuse (avalé en passant). Le mode physique doit **n'émettre aucun `hop_landed`**, comme RIDING, CLIMBING, ON_OWL_FLIGHT et ON_ZIPLINE |
| **`HubSkatepark.note_landing`** — proxy d'atterrissage, filtré par `roll_remaining() > ARRIVE_EPSILON` | **c'est la dette que la physique rembourse** (CH53 §, CH54 §7.4). En physique le score peut enfin classer par ARITHMÉTIQUE (a-t-il quitté la surface et y est-il revenu), donc conforme à CH43 |
| **caméra FIGÉE** (`HubCamera.OFFSET (0 ; 7,6 ; 8,9)`, `FRAME_TOP_AT_APLOMB = 7,968 u`) | un air sur le quarterpipe haut (2,10 u) reste très loin du plafond de cadre. **Mais un véhicule PILOTÉ en continu amène la poursuite**, et CH52 §8.5 dit que le budget nord **ne vaut pas** pour elle |
| **`WorldSave.award_from_activity`** garde-fou de stock | inchangé, la conversion reste derrière une fonction |
| **90 sondes** dans `scripts/dev/` | une fondation qui touche un mode partagé (caméra, entrée, `KeepyHopper`) exige de **rejouer la table des rides sur DEUX arbres** (CLAUDE.md) — c'est le coût de clôture de tout lot forme A, et de zéro lot forme B qui ne touche que le porteur |

---

## 4. COÛT PERF — ce qui est chiffrable, et ce qui ne l'est pas

### 4.1 La configuration réelle, lue et non supposée

`project.godot` **n'a aucune section `[physics]`** → tous les défauts
Godot 4.3 : `physics_ticks_per_second = 60`,
`max_physics_steps_per_frame = 8`, `physics_jitter_fix = 0.5`,
`default_gravity = 9.8`, moteur `GodotPhysics3D`,
`physics/3d/run_on_separate_thread = false`.

`export_presets.cfg` **ne contient aucune ligne `variant/thread_support`**
→ défaut, c'est-à-dire **WASM mono-thread**. Donc :

> **Sur device, chaque milliseconde de physique tombe sur LE MÊME THREAD
> que la soumission du rendu et que tous les `_process` du hub. Il n'existe
> aucun thread physique à activer.**

Le monde 3D du hub vit dans un `SubViewport` **sans `own_world_3d`** → il
hérite du `World3D` du viewport parent, donc **le même espace physique que
tout ce que la fenêtre racine porte**. Aujourd'hui sans conséquence (Chased
remplace la scène), mais Chased réserve déjà **layer 1** (sol) et
**layer 2** (joueur) : un choix de layers pour le hub doit les éviter, ou
le `SubViewport` doit passer en `own_world_3d = true` — ce qui est un
changement **qui affecte le rendu** et exige donc une preuve au pixel.

### 4.2 Le facteur d'amplification, et il va dans le mauvais sens

La physique tourne à **60 Hz fixes, décorrélés du rendu**. Le coût physique
**par frame rendue** vaut donc `coût_par_tick × (60 / FPS)` :

| FPS observés | pas de physique par frame rendue |
|---|---|
| 60 | 1,00 |
| 50 (plancher proposé par CH52 §8.2) | 1,20 |
| **46** (lecture device de Mathieu à z ≈ 62,2) | **1,30** |
| 34 (voir §6.2 — chiffre non sourcé) | 1,76 |

> **Plus la frame est lente, PLUS on paie de physique dedans.** C'est
> l'inverse de l'intuition, et avec `max_physics_steps_per_frame = 8` et
> `physics_jitter_fix = 0.5` c'est une **contre-réaction positive** : une
> frame qui dépasse le vsync accumule du temps, la suivante exécute deux
> pas, donc coûte plus, donc dépasse davantage.

### 4.3 Le chiffrage honnête : **la monnaie du budget nord ne sait pas compter des millisecondes CPU**

CH52 §8.1 publie une pente marginale de **≥ 0,199 ms par 1 000
primitives**, explicitement une **borne inférieure**, obtenue de deux
points device (46 FPS à z ≈ 62,2, 60 FPS ailleurs — le 60 étant censuré
par le vsync). **Il n'existe dans tout ce dépôt AUCUNE mesure de
millisecondes CPU, et aucune conversion entre du CPU et des primitives.**

Ce qu'on peut néanmoins écrire, en ordre de grandeur et en le disant :

| coût physique par tick | ms par frame à 46 FPS | équivalent-primitives à la pente CH52 | part d'un budget de 16,67 ms |
|---|---|---|---|
| 0,05 ms | 0,065 | ≈ 327 | 0,39 % |
| **0,1 ms** | **0,130** | **≈ 655** | **0,78 %** |
| 0,5 ms | 0,652 | ≈ 3 276 | 3,91 % |
| **1,0 ms** | **1,304** | **≈ 6 553** | **7,83 %** |

> **1 ms de physique par tick coûte, à 46 FPS, à peu près autant que
> 6 550 primitives — c'est-à-dire PLUS que la totalité des 6 000
> primitives que CH52 a accordées au park entier.** Et CH52 §8.3 conclut
> que le budget net disponible au bord nord est de **zéro**.

Ce qui est chiffrable en **comptes**, sans mesure :

* **Forme B, un seul corps** : `move_and_slide()` fait au plus
  `max_slides = 4` itérations de récupération, chacune un test de mouvement
  de forme, plus l'accrochage au sol → **≤ 5 requêtes de balayage par
  tick**, soit ≤ 300/s pour la planche. En valeur absolue, c'est peu.
* **Les cinq modules en collider** : 468 triangles au total (funbox 20,
  rail 36, quarterpipe 50 + 50, **bol 312 — les deux tiers**). Le
  quarterpipe est un **profil balayé concave** (`QP_SEGMENTS = 12`) et le
  bol un **plat creux** (24 azimuts × 5 anneaux) : **aucun des deux n'est
  convexe.** Donc soit `ConcavePolygonShape3D` (trimesh — la paire
  capsule-vs-trimesh est la plus chère de GodotPhysics3D, et le balayage
  parcourt les 312 triangles du bol), soit une **décomposition en pièces
  convexes**, que `SkateparkMesh` **ne publie pas** aujourd'hui (aucun
  `PIECE_TRIS` / `PIECE_COUNT`, contrairement à `SledBody`).
* **⚠️ `ConcavePolygonShape3D.backface_collision` vaut `false` par
  défaut** : un trimesh dont l'enroulement est faux est **un sol à travers
  lequel on tombe, en silence**. C'est le piège CH39 (la crête ouest
  invisible) transposé à la collision. Bonne nouvelle mesurée :
  `SkateparkMesh._tri()` est *« THE ONLY PLACE AN INDEX ORDER IS
  DECIDED »* et corrige l'ordre contre un vecteur `facing`. Donc
  l'enroulement du collider hérite du gate de RENDU — et les deux
  instruments testent la même propriété, ce qui est la forme que la
  doctrine approuve.
* **Le décor** : 306 batches `MultiMesh`, ~4 572 instances,
  **collision impossible sans débatcher**, et le budget draw call est
  **zéro** (§1.6). Chiffre décisif, et il ferme la question.

### 4.4 Verdict perf, sans le minimiser

> **Le budget est incompatible avec un moteur physique GÉNÉRALISÉ, et il
> l'est pour une raison de draw calls avant d'être une raison de
> simulation.** Le décor solide du hub coûterait un nœud (donc un draw
> call) par prop, et CH52 mesure zéro draw call disponible au bord nord.
>
> **Un moteur physique LOCALISÉ (un corps porteur + cinq colliders
> statiques, forme B) n'ajoute aucune primitive et aucun draw call**
> (un collider ne dessine rien), et son coût est entièrement CPU — **un
> coût que personne ici n'a jamais mesuré, dans une frame que CH52
> déclare pleine.** Le seuil est bas : au-delà de ~0,1 ms/tick on dépense
> l'équivalent de 655 primitives sur un budget net de zéro.
>
> **Conclusion : ce n'est pas décidable sans une mesure, et cette mesure
> n'existe pas. C'est le lot 0 du §5, et il peut tuer toute la chaîne.**

---

## 5. DÉCOUPAGE PROPOSÉ EN LOTS

Esprit CH52 (mesure seule) → CH53 (implémentation). Chaque lot a un critère
de validation **indépendant** et peut refuser le suivant.

**LOT 0 — L'INSTRUMENT. Mesure seule, zéro fichier de gameplay.**
Une sonde qui crée N `StaticBody3D` + 1 `CharacterBody3D` dans le monde du
hub, pousse `move_and_slide()` sur M ticks, et publie
`Performance.TIME_PHYSICS_PROCESS`, `PHYSICS_3D_ACTIVE_OBJECTS`,
`PHYSICS_3D_COLLISION_PAIRS`, `PHYSICS_3D_ISLAND_COUNT` pour
N ∈ {0, 1, 6, 20, 100}, en trimesh **et** en pièces convexes.
*Critère* : (a) le **plancher de bruit** du banc publié — deux lectures à
N inchangé (doctrine CH40 : un delta sans son plancher ne vaut rien) ;
(b) le compteur **répond** (N = 0 → 0 objet actif : le blind check) ;
(c) la ms/tick publiée pour chaque N. **Tourne en `--headless`** (la
physique est du CPU, et une sonde qui ne lit aucun pixel doit être
headless, doctrine inverse du driver DUMMY).
*Ce lot peut conclure « non affordable » et il faut qu'il en ait le
droit.*

**LOT 1 — UN SEUL COLLIDER, ET IL EST LE TEST DE VÉRITÉ.**
La **funbox** seule (20 triangles, une boîte + un plan incliné :
entièrement décomposable en convexes) reçoit un vrai collider, et la
**planche** devient un `CharacterBody3D` sous le contrat porteur existant.
Aucun changement de score, aucun état neuf dans `KeepyHopper`, aucun canal
de tap touché.
*Critère* : (a) la planche est réellement arrêtée/soulevée par le
collider ; (b) le profil d'allure de `SkateDriveProbe` PHASE P est
**inchangé** hors module (1,967 s sur 16 u) ; (c) le recensement de
primitives CH53 est **inchangé aux cinq stations** — un collider ne
dessine rien, donc un +1 draw call signifierait une erreur ; (d) les
compteurs du lot 0 lisent sur le vrai hub ce qu'ils prédisaient.

**LOT 2 — LA PHASE AÉRIENNE, ET LE SCORE QUI CESSE D'ÊTRE UN PROXY.**
Gravité et arc balistique réel sur la lèvre du quarterpipe ; le score
classe par **arithmétique** (a-t-il quitté la surface, y est-il revenu),
c'est-à-dire la dette CH53 §4.2 / CH43 remboursée.
*Critère* : le proxy et la classification réelle **divergent** sur un
ensemble d'atterrissages **publié**. Blind check obligatoire : s'ils ne
divergent jamais, la physique n'a rien changé et le lot est un no-op
déguisé.

**LOT 3 — LES QUATRE AUTRES MODULES.**
Pièces convexes publiées par `SkateparkMesh` (`*_pieces()`, `PIECE_TRIS` /
`PIECE_COUNT` sur le patron `SledBody`), **gatées contre le maillage
dessiné** et non contre la formule.
*Critère* : (a) chaque pièce testée convexe contre **son propre** centre
(doctrine CH41 : un test d'enroulement contre un centre de masse suppose
la convexité) ; (b) `PIECE_COUNT × PIECE_TRIS` = `triangle_count()`
asserté ; (c) budget primitives et draw calls inchangés.

**LOT 4 — LE PIED. GATÉ PAR UNE DÉCISION DE MATHIEU, PAS PAR UN CRITÈRE
TECHNIQUE.**
`KeepyHopper` devient un `CharacterBody3D`, colliders actifs uniquement
dans les états de marche.
*Critère* : les **deux** traversées publiées **re-marchées** (20,967 et
20,117 contre 22,0), **plus** la diagonale reproduite **à la frame près**
(1 122 frames / 18,700 s) comme contrôle d'instrument — un banc incapable
de la restituer n'a pas qualité à publier un chiffre neuf. Plus la table
des rides rejouée sur **deux arbres**.

---

## 6. DÉCISIONS À PRENDRE PAR MATHIEU

**D1 — QUI POSSÈDE LE SOL ?** (la plus lourde)
(a) `HubSurface` continue de le posséder : la physique ne sert qu'au
blocage **latéral** contre les props, le Y reste snappé sur
`HubSurface.ground()` après le slide. Doctrine préservée, mais ce n'est pas
« de la physique standard » de bout en bout.
(b) La physique le possède : un `HeightMapShape3D` par domaine
`HubSurface` + un plan pour le reste. **Crée une seconde orthographe du
sol**, exige un gate permanent point par point contre `height_at`, et un
hook dans `register_domain`.

**D2 — LE COLLIDER APPARTIENT AU PORTEUR OU AU PERSONNAGE ?**
(B, recommandée : risque nul sur la traversée, additive) ou (A : dépense
les 5,469 u de marge et exige un gate de collision par état).

**D3 — L'ESPACE PHYSIQUE.** Partager le `World3D` racine avec les layers
1/2 déjà réservés par Chased, ou passer le `SubViewport` en
`own_world_3d = true` — ce dernier affecte le rendu et exige une preuve au
pixel.

**D4 — SI LE PIED DEVIENT PHYSIQUE : que devient le plafond de 22,0 s ?**
Il ne peut pas être garanti sans pathfinding. Soit le plafond bouge (et
c'est une décision de design), soit **le sol marchable ne reçoit aucun
collider bloquant** — auquel cas la forme A n'apporte rien de plus que B.

**D5 — TRIMESH OU PIÈCES CONVEXES ?** Trimesh = une ligne par module, la
paire de collision la plus chère, et `backface_collision` en piège
silencieux. Convexe = un accesseur publié par module et un gate, mais
c'est le patron que ce dépôt applique déjà (`SledBody.PIECE_TRIS`).

**D6 — LA CAMÉRA RESTE-T-ELLE FIGÉE ?** Une planche physique **pilotée au
pouce** est un véhicule piloté en continu, donc la **poursuite** par la
table de doctrine caméra — et CH52 §8.5 est explicite : le budget du lobe
nord **ne vaut pas** pour une poursuite. Ce serait un `ChaseAudit` du lobe,
un lot à lui seul, avant toute physique.

---

## 7. ZONES D'INCERTITUDE — dites, pas maquillées

1. **AUCUNE MILLISECONDE N'A ÉTÉ MESURÉE DANS CE LOT.** Le §4 est de
   l'arithmétique sur des constantes lues et une pente que CH52 publie
   elle-même comme **borne inférieure**. Le tableau 4.3 est une échelle,
   pas une prédiction. Rien ici n'est un verdict de perf.
2. **⚠️ LE « 34-50 FPS SELON MÉTÉO ET STATION » DU BRIEF N'A AUCUNE
   SOURCE DANS LE DÉPÔT.** Grep exhaustif : la chaîne `34-49 FPS`
   apparaît **une seule fois**, dans `CH54_SKATE_CONDUITE.md:258`, créditée
   à un « relevé CH52/CH53 » — et **ni CH52 ni CH53 ne contient un 34 ni un
   49**. Les seules lectures device au dossier sont **46 FPS à z ≈ 62,2** et
   **60 FPS ailleurs** (CH52 §8.1), le 60 étant explicitement **censuré**
   par le vsync. Aucune lecture n'est indexée par la météo. C'est un
   chiffre fantôme au sens de CLAUDE.md, et je ne calcule rien dessus.
3. **Le partage du `World3D`** est déduit de l'**absence** de
   `own_world_3d` dans `HubWorld.tscn`, pas testé à l'exécution.
4. **Le mono-thread WASM** est déduit de l'**absence** de
   `variant/thread_support` dans `export_presets.cfg`, pas testé.
5. **L'affirmation de `HubPortal`** selon laquelle `monitoring = true`
   coûterait *« a broadphase entry per frame »* n'est **pas mesurée** — et
   la formulation est douteuse : une forme reste dans la broadphase même
   sans monitoring ; ce que `monitoring = false` économise est
   l'appairage et le rappel, pas l'entrée. À vérifier au lot 0, où c'est
   gratuit.
6. **Ce sandbox n'a pas de GPU, mais il a un CPU** : une sonde de coût
   physique y mesure honnêtement (la physique est du CPU, llvmpipe n'y
   change rien). **Le rapport entre ce CPU et celui d'un téléphone est
   inconnu**, donc le lot 0 publie un ordre de grandeur et une COURBE en N,
   jamais un chiffre device.
7. **Le terme de pente sur l'avance XZ** (§3.1 cas 2) n'est pas chiffré.
   Il n'est pas nul et il tombe sur la seule paire qui contraint.
8. **Rien n'a été rendu.** Aucune capture, aucun pixel. Ce lot n'a rien
   construit à regarder.

---

## 8. NEXT STEPS

| # | quoi | pourquoi |
|---|---|---|
| 1 | **Décisions D1 et D2** de Mathieu | rien ne peut commencer avant : D1 décide qui possède le sol, D2 décide si la garantie de traversée est en jeu |
| 2 | **LOT 0**, la sonde de coût physique | la seule chose qui transforme le §4 en budget ; elle a le droit de conclure « non » |
| 3 | Lecture device de Mathieu à **(−10 ; 51)**, overlay ouvert, `FPS min` + `TRI gpu` notés | déjà next-step #1 de CH52 **et** de CH53, toujours pas fait — c'est le seul point qui lèverait la censure du modèle device, et tout le §4 en dépend |
| 4 | Si D6 = poursuite : `ChaseAudit` du lobe nord **avant** toute physique | CH52 §8.5 : le budget mesuré ne vaut pas pour une caméra de poursuite |

---

## 9. DOCS STATUS

Ce fichier, plus une ligne dans `docs/lots/INDEX.md`. **Aucune doctrine
nouvelle ajoutée à `CLAUDE.md`** : les quatre règles que ce lot dégage
(le semis n'acquiert jamais de collider ; un `MultiMesh` ne peut pas
collider donc le coût est en draw calls ; la frontière d'un mode physique
est un état et jamais une géographie ; `backface_collision` est le piège
CH39 transposé) sont des **conséquences** de doctrines déjà écrites, pas
des découvertes — et elles vivent ici, dans le fichier de leur chantier,
comme la règle d'écriture additive l'exige. Elles remonteront dans
`CLAUDE.md` le jour où un lot d'implémentation les paie.
