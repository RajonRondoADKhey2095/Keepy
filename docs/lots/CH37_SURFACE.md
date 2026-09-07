# CH37 — Socle multi-altitude, LOT 1 SURFACE : l'accesseur et ses clients (7 septembre 2026)

> Fichier de chantier créé par le lot CH37. Le plan exécuté ici est
> `docs/lots/CH35_MULTI_ALTITUDE.md`, section **CH35-C tâche B** — six
> vagues, chaque site avec sa preuve de non-fuite. Ce lot **n'a rien
> reconçu** : les écarts au plan sont nommés un par un ci-dessous.

## CH37-1 — LOT 1 SURFACE : `HubSurface`, et le hub qui ne bouge pas

Base : `origin/staging` `182734d`, arbre `550c543` vérifié par
`git rev-parse ^{tree}` (pas par nom : la collision s'est reproduite quatre
fois dans ce dépôt). `git fetch --all --prune` au début — aucune branche
jumelle `ch37`, `origin/claude/ch36-altitude-frame-ceiling-42qeal` porte
**le même arbre que `staging`** (donc déjà mergée, `merge-base
--is-ancestor` le confirme), et `main` n'est en avance que d'un commit CI.
Godot 4.3 éditeur provisionné en session (50 276 070 o = `Content-Length`),
import complet **154 `.scn` des deux côtés, 0 erreur**, compté avant toute
comparaison.

### Ce que le lot livre, et ce qu'il ne livre pas

**Aucun relief.** Zéro domaine enregistré en jeu ; seules les sondes en
enregistrent. `height_at` vaut donc `0.0` partout dans le hub livré, et
tout ce lot est un **no-op arithmétique** — c'est le critère central, et
c'est ce que la phase G de `SurfaceProbe` re-mesure une par une sur toutes
les grandeurs des six phases précédentes.

Ce qui est publié : `scripts/hub/HubSurface.gd`, une **requête** au patron
`HubWater` (elle ne refuse aucun tap, ne clampe rien, ne bouge rien), et
les sites d'écriture de `y` branchés dessus.

### `HubSurface` — les points durs du contrat

* **`ground(flat)` est l'orthographe UNIQUE d'un point sol.** Les sites
  l'appellent ; aucun ne compose `height_at` avec un `Vector3(x, h, z)`
  écrit à la main. Ce dépôt a payé deux fois pour l'inverse (un pas de
  porte qui ne scalait pas avec sa cabane, deux `LAKE_WATER_RADIUS` pour
  deux corps différents).
* **L'échantillon lit une GRILLE, jamais une formule.** Le mesh que le lot
  2 construira sera bâti DEPUIS cette grille avec une diagonale de
  triangulation FIXE, et `height_at` fait le barycentrique sur la MÊME
  diagonale — les pieds tombent sur le triangle que le joueur voit. Une
  fonction analytique ne sert qu'à REMPLIR la grille.
* **`PackedFloat32Array`, refusé sinon** — pas converti. Le mesh est
  float32 ; deux précisions sont deux surfaces (piège `rotation.y` float32
  du CH30). `register_domain` rend `-1` sur un `PackedFloat64Array`.
* **Frontière domaine/domaine INTERDITE** (AABB disjointes, assertées) :
  aucun point n'est jamais dans deux domaines, donc **il n'y a aucun blend
  à écrire**.
* **Frontière domaine / h = 0 : C0 EXACT**, `|h| < 1e-4` sur tout le
  périmètre marché à 0,5 u. Une MARCHE est refusée : le hop de 0,45 u ne
  distingue pas une marche d'une pente, et une falaise sans état est un
  joueur enterré. Le jour où une marche est voulue, c'est une TRANSITION
  DE NIVEAU — le métier de `scripts/nav`, pas de l'accesseur.
* **Aucune bande `CozyPalette` ne peut traverser un domaine** — les
  constantes sont LUES dans `CozyPalette` (`AUTUMN/MOOR/CIRCUIT_EDGE_Z` et
  leur `_EDGE_W`, `COVE_RECT` + `COVE_EDGE_W`, `LAVENDER_FIELDS`), jamais
  recopiées. Motif : sur un sol unlit un versant n'a aucun ombrage, donc
  une ligne de couleur y serait le SEUL trait et un versant bicolore lit
  comme deux terrasses (mesuré au CH35-C, tâche A, réponse 5).
* **`intersect_ray` rend EXACTEMENT
  `Plane(Vector3.UP, 0.0).intersects_ray` quand la table est vide** — le
  même appel, pas une approximation. C'est ce qui permet au tap d'échanger
  l'un contre l'autre avec un hub byte-identique ; vérifié sur 20 rayons,
  **écart pire cas 0.000000000**.
* **`normal_at` : absent**, délibérément. Le hop est un arc sur une ligne
  de base, donc rien dans le hub n'a besoin d'une normale de surface.

### Les six vagues, et ce que chacune a prouvé

| vague | fichiers | preuve |
|---|---|---|
| 0 socle | `HubSurface.gd` + `SurfaceProbe.gd/.tscn` | phases A/B vertes ; `ProbeTimeoutAudit` **78 → 79**, toujours PASSED |
| 1 la marche | `KeepyHopper.gd` | phase C : montée **1,2265 → 3,0000 u** en 3 hops, chaque atterrissage sur la surface à `0.00000000`, mi-hop `3,4231 = lerp(3,0000 ; 2,6461) + 0,6000` ; **grep-gate** conforme |
| 2 la caméra | `HubCamera.gd` | phase D : `(0.000031 ; 10.59999 ; 8.9)` contre un `ground + OFFSET` de `(0 ; 10,6 ; 8,9)`, **0,000032 u** d'écart, après 120 frames du lissage ORDINAIRE |
| 3 le tap | `HubTapInput.gd` | phase TAP : gate de source + balayage — le MÊME pixel à caméra GELÉE désigne ailleurs pour **6 pixels sur 7**, pire cas **3,640 u** |
| 4 retours au sol | `KeepyHopper.gd`, `HubWorld.gd` | grep-gate : exactement **9 lectures de delta** restantes, **0 écriture plate** ; monté à `h + lift = 3,3500`, véhicule à `3,0000`, démonté à `3,0000` |
| 5 pluie + ombre | `CozyScatter.gd` | phase E : colonne de pluie `3,0000`, ombre `3,0250 = h + 0,025` ; l'ombre SAIT rétrécir (1,5600 → 1,1700 à un mètre) et **ne rétrécit pas** debout sur une colline de 3 u |

Vague 6 (noisettes) : **non faite**, elle est optionnelle au brief.
Acteurs et critters : hors lot — `V6CrittersProbe` est INCONCLUSIVE
structurel, donc ingatable ici.

### ⚠️ TROIS ÉCARTS AU PLAN, tous nommés

**1. Le delta de `_advance` est écrit en XZ, explicitement.** Le plan donne
`_target = ground(point)` à `hop_to` et garde `here` plat en appelant le
delta « XZ : une lecture, pas une écriture ». Avec une hauteur à un bout et
pas à l'autre, **ce n'est plus vrai** : le delta gagne un `y`, le pas se
raccourcit sur une pente (or `HOP_DISTANCE`, la diagonale à 66 hops et
toutes les mesures de traversée de ce dépôt sont des distances XZ) et,
pire, **`ARRIVE_EPSILON` cesse de fonctionner** — `here` est plat, donc une
cible 3 u plus haut garde un `delta.y` de 3 pour toujours et la marche ne
se termine JAMAIS. Inerte aujourd'hui (h ≡ 0), latent le jour où un
domaine existe. Le delta jette donc `y` explicitement, avec le motif écrit
dans le code. `here` est intact et la liste du grep-gate est inchangée.

**Corollaire honnête** : le delta étant plat, `_target.y` n'est jamais lu,
donc `ground()` à `hop_to` est l'**orthographe** d'un point sol et pas un
comportement. Le comportement vit dans `_begin_hop`, qui re-lit la surface
aux deux bouts de chaque arc.

**2. Trois familles de sites que la table CH35-C ne liste pas**, branchées
pour la règle qu'elle énonce elle-même (« aucun littéral 0.0 de ligne de
base ne survit ») : les cinq `leave_*` de siège (tourniquet, balançoire,
hibou, tyrolienne, porteur) — exactement le cas de `leave_ride` que la
table LISTE ; le `_hop_from_y` de `climb_tree` ; et `tree_foot_point()`,
qui RETOURNE un point sol et est le seul endroit où ses deux consommateurs
le lisent.

**3. `_badger_rest()` branché à l'accesseur, pas à ses deux appelants**
(`:2131` et `:3032`, que la table cite). Elle retourne un point sol lu par
les deux ; publier une fois plutôt que brancher deux consommateurs est la
règle de ce dépôt.

### ⚠️ UNE PHASE DE SONDE EST PASSÉE VERTE CONTRE LE CORRECTIF NEUTRALISÉ

La première version de la phase TAP restait **VERTE** avec `HubSurface`
remis à un `Plane` nu. Seule la passe rouge-avant-vert l'a dit. Deux
causes, toutes deux inscrites dans la sonde :

* **`tapped_ground` ne porte pas toujours le point sol** — un tap près d'un
  arbre émet LA POSITION DE L'ARBRE (`HubTapInput:468`). Les nombres
  comparés étaient deux positions d'arbres.
* **Comparer une passe « à plat » à une passe « avec relief » déplace AUSSI
  la caméra**, puisque la vague 2 l'a mise sur la surface : les deux effets
  se compensent en partie. Mesuré : **0,143 u** de différence, contre
  **5,673 u** pour la comparaison honnête (le même rayon, la même pose,
  contre le plan nu).

D'où la pose de caméra GELÉE, et d'où un BALAYAGE de pixels plutôt qu'un
seul : n'importe quel pixel peut router vers un prop dans les deux passes
et se lire comme « aucune différence ».

C'est le mode de faux-vert que ce dépôt documente déjà huit fois, retrouvé
une neuvième. **Le blind check en tête de chaque phase n'est pas
décoratif** : à la passe rouge où la grille d'échantillonnage est décalée
d'un pas, c'est lui qui rougit et refuse de laisser la phase B asserter
quoi que ce soit sur un monde plat.

### ⚠️ UNE SONDE À PHASES DOIT NETTOYER SON FIXTURE ENTRE PHASES

La phase C3 tue le tween du hop à la main pour lire l'arc à `t = 0,5`, ce
qui laisse le corps en `HOPPING` avec une destination encore armée. La
phase GATE s'est alors fait REFUSER son `mount_vehicle` par le garde
« est-ce que quelque chose d'autre écrit le corps », et la phase D a trouvé
Keepy en train de s'éloigner en pleine mesure : **cinq rouges, dont pas un
seul ne parlait de la surface**. D'où `_settle()`. Un fixture laissé sale
entre deux phases est une sonde qui mesure ses propres restes.

### Rouge-avant-vert — chaque passe, son compte, et `cmp` après restauration

| neutralisation | rouges | ce qu'ils disent |
|---|---|---|
| early-return de `intersect_ray` retiré | **1** | l'identité au plan, écart pire cas 0,001922578 |
| grille d'échantillonnage décalée d'un pas | **3** | dont le BLIND CHECK de la phase B |
| `_on_hop_finished` remis à 0.0 | **3** | atterrissage + pose de repos |
| `_begin_hop` remis à 0.0 | **6** | dont le blind check de l'arc |
| `_wanted()` remis à plat | **3** | caméra épinglée à `y = 7,6` exactement comme prédit |
| `Plane` nu remis dans `HubTapInput` | **3** | dont le comportemental : **0 pixel sur 7** bouge |
| `mount_vehicle` remis à plat | **4** | et le grep-gate **NOMME** la ligne fautive (1726) |
| `lift` remis à `p.y` | **1** | l'ombre est DÉJÀ rétrécie au repos (0,9750) et un mètre plus haut ne la bouge plus |
| pluie et ombre remises à plat | **2** | toutes deux à `0.0000` sous une colline de 3 u |

Après chaque passe, le fichier est restauré et vérifié **byte-identique par
`cmp`**, et la sonde repasse verte.

### Interdictions du brief, tenues

`VehicleDrive.gd` : `git diff` vide. `KartBody.gd:218` : aucune ligne (lot
3). `SEA_RADIUS` / `SEA_CENTRE` : non touchés. CH36
(`FRAME_TOP_AT_APLOMB`, `SEAT_MAX_Y`, `FrameCeilingProbe`, overlay) : non
retouché. `HubTrees` `SEAT_MAX_Y` et `KEEPY_WATERLINE_Y` : lot 2. Aucun
asset créé, supprimé, renommé ou dédupliqué. `ChargerAudit` et
`AirEnemyLandingLaneAudit` non lancés. `LakeZoneProbe` /
`V6CrittersProbe` non rouverts. Toute mesure offscreen sous
`xvfb-run --rendering-driver opengl3`, jamais `--headless` seul.

### Les gates de non-fuite — et les DEUX que le plan prescrivait qui n'en sont pas

Rejoués sur deux arbres : la branche (worktree figé sur le commit final) et
`origin/staging` importé à part. **154 `.scn` des deux côtés, comptés avant
toute comparaison.**

| gate | résultat |
|---|---|
| table des rides, 12 sondes | **12/12 comptes de rouges identiques** |
| `SeesawProbe` (rouge ATTENDU) | `draw nodes 157, expected 144` — la même ligne, le même nombre, des deux côtés |
| `WaterTintProbe` (rouge ATTENDU) | **9 rouges des deux côtés** |
| `TurnstileProbe` / `StreamRideProbe` / `ZiplineRideProbe` | 2 / 2 / 1 rouges pré-existants, identiques des deux côtés |
| `KartTraceProbe` | **byte-identique**, 335 lignes de trace |
| `YachtTraceProbe` (le char) | **byte-identique** |
| `ChaseAudit` | **verdict identique : 13 checks, 0 failures → PASS** |
| `CozyCapture` 5 stations × SUN/RAIN | **10/10 `COZY_STATS` strictement identiques** hors champs d'acteur (voir ci-dessous) |
| `ProbeTimeoutAudit` | 78 → **79**, PASSED |
| export Web | 0 `SCRIPT ERROR` ; **`index.wasm` 35 376 909 o / md5 `af4a8fc2925d992348eb30deeeb54360`** et `index.js` md5 `4e08904b1b7107858246af44b602067b` — les deux valeurs d'identité publiées dans `CLAUDE.md` ; 582 `Storing File`, **0** sous `scripts/dev/`, `assets_source/`, `docs/`, `web/` |

#### ⚠️ `CabinProbe` a divergé — 8 rouges contre 2 — et c'était la MACHINE

Premier passage : **8 rouges sur la référence, 2 sur la branche**. Les six
de plus étaient la séquence du baiser (`her face stays clear`, `the lean is
undone`, `every heart frees itself (6 left)`), et les deux runs avaient
partagé la machine avec d'autres sondes.

Rejouée **SEULE sur chaque arbre**, l'une après l'autre, rien d'autre en
cours : **2 rouges des deux côtés, littéralement les mêmes deux lignes avec
les mêmes nombres** (`every heart frees itself (1 left)`, `one mark per
cabin (2 marks, 1 cabins)`). La divergence était de la contention, pas du
code — et elle n'aurait pas été tranchée en relisant le diff.

#### ⚠️ LE `md5` D'UNE CAPTURE NE GATE RIEN ICI, ET LE PLAN LE PRESCRIVAIT

Les 10 `md5` de `CozyCapture` divergent entre les deux arbres — **10 sur
10**. Avant d'appeler ça une fuite, la métrique a été retournée contre
elle-même : **deux runs du MÊME arbre, mêmes arguments**, rendent
`7951f559…` et `9f2e076f…` — deux md5 différents, et tous deux différents
du run précédent sur ce même arbre. **Un md5 de capture ne peut pas
distinguer deux arbres puisqu'il ne distingue pas deux runs d'un seul.**
Idem pour le relevé chiffré de `ChaseAudit` : **170 lignes divergent sur le
même arbre**, contre 272 entre les deux — le même ordre de grandeur, pendant
que le VERDICT (13/0 PASS) est stable des deux côtés.

La cause est nommable, et c'est le hub lui-même : **depuis le CH25 l'ours
MARCHE** vers le feu de camp. Sa pose dépend du nombre de frames réellement
simulées avant la capture, donc de la charge de la machine — et sa pose
colore `centre_pixel` et tous les compteurs de frame. Mesuré : entre deux
runs de la même référence l'ours se déplace de **1,27 u**, contre **0,17 u**
entre les deux arbres. **Le bruit est plus grand que le signal.**

Le gate a donc été remplacé par une métrique qui, elle, décrit la SCÈNE et
pas les pixels : le `COZY_STATS` que `CozyCapture` imprime déjà. Hors des
champs que la mesure de bruit désigne (`bear`, `centre_pixel`, `perf.*`),
**les 10 stations sont STRICTEMENT IDENTIQUES** — les 350 batches de
`per_multimesh`, les 4 572 instances, les 341 029 triangles, `mesh_nodes`,
`tris_mesh`, `tris_multimesh`, `keepy_at`, `keepy_now`, `ground_tint`,
`ground_wet`, `overlay`, `draw_calls_est`, `viewport`. Si ce lot avait
déplacé quoi que ce soit du décor, de la caméra ou du corps, ces 350 batches
l'auraient dit.

**Ce qui reste non prouvé, et il faut le lire comme tel** : les pixels
eux-mêmes ne sont pas comparés (ni PIL ni numpy dans ce sandbox), et
llvmpipe ne prouve de toute façon pas le shading WebGL2 de Safari iOS. La
mesure device de CH35-B tâche 4 reste préalable à la montagne, comme le
CH35-C le disait déjà.
