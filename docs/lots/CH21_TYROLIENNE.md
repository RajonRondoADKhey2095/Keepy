# Tyrolienne — recon (3 septembre 2026)

> Chantier ouvert par ce lot. **RECON PURE : aucun code de jeu écrit,
> aucune entrée de layout ajoutée, aucun fichier de `scripts/hub/`,
> `scripts/nav/`, `scenes/` ni `resources/` touché.** Le seul ajout est
> `scripts/dev/ZiplineReconProbe.{gd,tscn}` et sept rendus sous
> `docs/renders/zipline_recon/`.
> Doctrine permanente : voir `CLAUDE.md`. Index : `docs/lots/INDEX.md`.

## RECON 1 — LE PATRON ÉCHELLE EST UN MÉCANISME DE ROUTAGE DE TAP, ET RIEN D'AUTRE

**Question posée** : l'interdiction du « patron ÉCHELLE » désigne-t-elle un
mécanisme technique de gating, ou une contrainte plus large qui engloberait
un **escalier-décor** menant à la tyrolienne ?

**Réponse mesurée : un mécanisme de routage de tap, exclusivement.** La
définition tient en deux lignes de `CH18_CABANE_NAV.md`, verbatim :

> « Copier l'ECHELLE aurait ete le bug : elle emet `tapped_ladder` quoi que
> fasse Keepy et `HubWorld` le jette »

C'est tout le patron. Un **canal de tap dédié**, émis **inconditionnellement**
— pas de `is_available()`, pas de retrait — et un écouteur qui **jette** le
signal dans les états qu'il ne sait pas traiter. Le mode de panne est unique :
le joueur tape en pleine interaction et **rien ne se passe**, sans sortie.

Le patron BATEAU est exactement son inverse, et il est implémenté trois fois
dans le dépôt sous trois noms :

| prop | le retrait | fichier |
|---|---|---|
| bateau | `BoatMooring.accepts_boarding_tap()` → `false` pendant tout le ride | `BoatMooring.gd` |
| hibou | `HubTapInput.owl_available = false` pendant tout le vol | `HubWorld._on_tapped_owl` |
| cabane | `cabin_available` → `false` pour toute la visite | `CH18` |

Dans les trois cas le MÊME tap retombe sur `tapped_ground` et **DEVIENT la
sortie**. `HubTapInput._handle_point` le dit dans son propre commentaire :
« accepts_boarding_tap() is false for the whole of a ride, so a tap then
falls through to tapped_ground -- which is what turns it into an eject. One
tap, one signal, either way. »

**C'est mesuré des deux côtés, pas argumenté** :

| cassure délibérée | rouge obtenu |
|---|---|
| `LevelTransition.is_available()` forcé à `true` (= patron ÉCHELLE) | **2 FAIL** |
| retrait de la cabane neutralisé | **3 FAIL**, dont « un tap ON THE DOORSTEP a terminé la visite » qui échoue avec Keepy **toujours dedans 240 frames plus tard** |

### Conséquence pour l'escalier

**L'interdiction ne l'atteint pas.** Elle porte sur ce qui **possède un canal
de tap**. Un escalier-décor que Keepy gravit dans une chorégraphie n'émet
aucun signal, n'a pas d'`is_available()` à mal câbler, et n'a donc aucune
manière d'avaler un tap. Il est dans la même classe que les barreaux du
plongeoir — de la géométrie le long de laquelle un corps est **écrit** — pas
dans la classe que l'interdiction nomme.

### ⚠️ MAIS LE PIÈGE ADJACENT EST RÉEL, ET IL FAUT LE NOMMER

Le tableau des trois dérogations de `CH18` montre que tourniquet, balançoire
et hibou partagent une propriété : **« taps pendant : interceptés, jamais une
destination »**. Une tyrolienne est une interaction **multi-temps** (marche
jusqu'au pied → montée → le blaireau rejoint → trajet → arrivée). Copier
cette propriété telle quelle sur toute la séquence donnerait au joueur une
fenêtre de plusieurs secondes où **chaque tap est jeté**. Ce n'est pas le
patron ÉCHELLE par le nom ; c'en est le **symptôme**.

### ARCHITECTURE PROPOSÉE — trois portes, chacune traitée séparément

Elle est écrite pour qu'aucune ambiguïté avec le patron interdit ne subsiste,
plutôt que pour trancher au plus court.

1. **DÉPART (marche d'approche).** Un signal `tapped_zipline`, gaté par
   `zipline_available` sur le modèle exact du bateau. Le retrait s'engage
   **au tap**. Pendant la marche vers le pied, Keepy est en `HOPPING`
   ordinaire : tout tap retombe sur `tapped_ground` et **annule l'intention**
   — littéralement la ligne `_boarding = false` qui existe déjà dans
   `_on_tapped_ground`. Sortie complète, à tout instant.
2. **MONTÉE + TRAJET.** Le corps est possédé (`State.ON_ZIPLINE`). Le tap
   retombe toujours sur `tapped_ground` (le retrait tient) et arrive dans une
   branche d'état qui le **jette** — comme celle du hibou, et **légitimement
   pour la même raison qu'elle** : le trajet est **borné par un tween qui se
   termine toujours à un point connu**. C'est cette bornitude, et rien
   d'autre, qui rend le rejet sûr ; c'est ce que la formule « une planche dont
   le seul autre sens est déjà traité par état » dit réellement.
3. **ARRIVÉE.** `zipline_available` est rendu, et le point d'arrivée est
   **vérifié dégagé du hotspot de départ ET de tous les autres**. Mesuré sur
   les deux finalistes : **+13,237 u** (portail le plus proche) et
   **+11,483 u** (tap échelle). Le contrôle revient par un
   `leave_zipline(landing)` sur le modèle de `leave_ride` / `leave_owl` :
   **la destination survit au saut**, un tap achète la descente ET la marche.

**Et la dernière ambiguïté est supprimée par construction : l'escalier ne
porte AUCUN hotspot.** La seule cible de tap est le blaireau. Il n'y a rien à
taper sur les marches, donc rien qui puisse y avaler un tap.

## RECON 2 — GÉOMÉTRIE : LE CADRE DÉCIDE, PAS LE SOL

⚠️ **DEUX PRÉMISSES DE MA PROPRE RECON SONT TOMBÉES SUR MESURE, dans cet
ordre.** Elles sont publiées parce que chacune aurait produit une tyrolienne
livrable et fausse.

### Prémisse tombée n°1 — le site de tour que j'avais choisi est HORS CADRE

Un balayage python du layout donnait `(6,50 / 0,25)` comme meilleur
dégagement du premier plan. Projeté par la **vraie `HubCamera`** avec Keepy
au spawn : **écran (1316, 1046) sur 1080×1920 — dehors.**

La cause est mesurée, pas déduite : `HubWorld.tscn` pose
`keep_aspect = 0` (KEEP_WIDTH) et `fov = 45`, donc **45° est l'angle
HORIZONTAL**, demi-angle 22,5°. La demi-largeur visible à la distance de
caméra du spawn ne fait que quelques unités. **Au-delà d'environ 3 u de côté,
un prop planté « devant Keepy » n'est simplement pas à l'écran.**

Le site est donc **SCANNÉ** par la sonde et non plus choisi : région, **dans
le cadre au spawn (base ET sommet de mât)**, ≥ 1,30 u de toute empreinte,
≥ 1,00 u de tout disque de tap/déclenchement existant, ≥ 2,00 u du ruban du
ruisseau. **295 sites** satisfont les cinq contraintes.

| # | site | empreinte | hotspot | ruisseau |
|---|---|---|---|---|
| **1** | **(−0,25 / −3,50)** | **+2,358** (portail r=1,35 @ (0, −7,20)) | **+2,358** (portail) | +12,916 |
| 2 | (−0,25 / −3,25) | +2,251 | +2,608 | +12,696 |
| 3 | (0,00 / −3,50) | +2,174 | +2,350 | +13,036 |

Retenu : **(−0,25 / −3,50)**. Au spawn sa base tombe à l'écran **(518, 903)**
et son pont à **(512, 429)** — plein centre du cadre. C'est littéralement
« l'emplacement où Keepy apparaît au premier plan de la pelouse » du brief.

### Prémisse tombée n°2 — une longue tyrolienne NE LIT PAS comme une descente

Premier jeu de finalistes : les trois plus longues courses propres,
**33 à 42 u**, corridors mesurés à +0,807 / +1,054 / +1,021 — tout vert. Les
rendus les ont refusées :

* à **3,6 u de chute sur 38 u** la pente vaut **5,37°** : sur l'image le
  câble est un **fil horizontal en haut du cadre**, indiscernable d'une
  clôture ;
* le brouillard de cette scène est `fog_density = 0.016` exponentiel, donc à
  38 u l'occlusion vaut `1 − exp(−38×0,016)` = **45,6 %** — le point
  d'arrivée est déjà à moitié effacé ;
* et la **caméra ne tourne jamais** : elle ne peut de toute façon pas tenir
  les deux extrémités d'une course de 38 u dans un cadre de 22,5° de
  demi-largeur.

**Une course qu'on ne peut pas VOIR descendre n'est pas une tyrolienne,
quoi qu'en dise la géométrie.** La bande lisible est donc devenue une
contrainte constante de la sonde (`_READABLE_MIN_RUN` 14 / `_READABLE_MAX_RUN`
22, cap −Z uniquement), et non un commentaire.

Géométrie révisée : **pont 5,50 / arrivée 0,90, soit 4,60 u de chute** —
pente **13,4° à 15,1°** au lieu de 5,4°.

### PHASE A — les silhouettes sont MESURÉES, jamais lues sur `ground_footprints()`

`ground_footprints()` répond « peut-on ATTERRIR ici ». Un câble à quatre
mètres pose l'autre question. **424 volumes** relevés en AABB monde sur
l'arbre CONSTRUIT, **instances de `MultiMesh` comprises** (un balayage qui ne
cherche que des `MeshInstance3D` rendrait un plateau sans un seul arbre) :

| famille | n | sommet max | rayon max |
|---|---|---|---|
| `Cabin` | 2 | **11,131** | 6,625 |
| landmarks (nœuds sans nom) | 15 | 9,464 | 1,352 |
| `TreeCrown` | 44 | **3,933** | 1,796 |
| `Owl` | 1 | 2,037 | 0,766 |
| `DivingBoard` | 7 | 1,900 | 1,932 |
| `Turnstile` | 3 | 0,980 | 1,757 |
| `Rock` | 48 | 0,930 | 0,997 |
| `Bush` | 68 | 0,868 | 0,890 |
| `Seesaw` | 2 | 0,690 | 1,800 |

⚠️ **Le tronc footprint 0,24 pendant que sa couronne s'étale sur 1,796 et
flotte à hauteur de câble** — c'est exactement l'écart que le lot bateau
avait déjà payé sur ses points d'eject, et c'est lui qui décide les corridors
ci-dessous.

### LES DEUX FINALISTES, et pourquoi il n'y en a que deux

**3 104** arrivées satisfont les six contraintes ; **502** tombent dans la
bande lisible. Meilleur corridor par tiers d'azimut, test **ÉCHANTILLONNÉ**
(0,25 u de pas) :

| | **A_east** | **B_south** | **C_west** |
|---|---|---|---|
| départ → arrivée | (−0,25 / −3,50) → **(14,50 / −16,00)** | (−0,25 / −3,50) → **(9,50 / −17,50)** | — |
| course | **19,334 u** | **17,061 u** | — |
| chute / pente | 4,600 u / **13,38°** | 4,600 u / **15,09°** | — |
| corridor pire écart | **+4,102 u** (îlot @ (17,37 / −12,46)) | **+2,777 u** (îlot @ (6,84 / −20,53)) | — |
| empreinte à l'arrivée | +1,319 (ponton r=1,30) | +1,317 (ponton r=1,30) | — |
| hotspot à l'arrivée | **+13,237** (portail) | **+11,483** (tap échelle) | — |
| surface | **dans le grand lac est** | **dans le grand lac est** | — |
| chaîne de hops | 13 hops = **3,6400 s** | 12 hops = **3,3600 s** | — |
| plancher de vitesse | **5,3116 u/s** | **5,0775 u/s** | — |
| trajet à 12 u/s | 1,6112 s | 1,4217 s | — |

⚠️ **`C_west` N'EXISTE PAS, et c'est un résultat.** Aucune arrivée du tiers
ouest ne tombe dans la bande lisible en direction −Z : cet anneau devant le
spawn est occupé par la rangée de portails, la couronne d'arbres et le lobe
ouest du grand lac. La seule option ouest du grand éventail est
(−12,50 / −6,00) à **12,50 u** — sous le plancher de lisibilité.

**Les deux finalistes arrivent SUR L'EAU, à un ponton.** Ce n'est pas un
défaut : `HubRegion` ne soustrait plus aucun plan d'eau (« Water is a PLACE,
not a hole », décision explicite de Mathieu), le bateau flotte déjà sur deux
d'entre eux, et les cinq pontons du lac est sont précisément les amers de
cette zone. C'est même le meilleur argument gameplay des deux : **la zone lac
ne se rejoint aujourd'hui qu'en 12 à 13 hops.**

### Vitesse : le plancher est MESURÉ, pas choisi

Règle du bateau reprise telle quelle : un ride qui perd contre une chaîne de
hops est une façon plus lente de voyager qui a juste l'air plus jolie. Le
plancher vaut **5,31 u/s** (A) et **5,08 u/s** (B) — quantifié, parce qu'un
demi-hop coûte un hop entier. À **12 u/s** le trajet dure **1,42 à 1,61 s**,
soit 2,3× la chaîne de hops. `RIDE_SPEED` du bateau vaut 8,0 pour un plancher
de 5,83 ; le même rapport ici donnerait ~7,3 u/s, mais une tyrolienne qui
descend a le droit d'être plus rapide qu'une barque — **à trancher sur
device, pas ici**.

### ⚠️ UN DÉFAUT DE MA PROPRE SONDE, TROUVÉ PAR LA MESURE ET PUBLIÉ

La première passe autorisant l'eau a rendu la course sud **BLOQUÉE à
−10,530 u**. Le bloqueur était `@MeshInstance3D@111 @ (15,50 / −19,00)`,
sommet **0,01** — **le disque d'eau du grand lac lui-même**, une galette de
20 u de rayon et d'un centimètre d'épaisseur posée à plat. Le rider la
survole à y = 0,00 en fin de descente, donc le test de bande de hauteur
répondait « dedans » et l'écart horizontal « dix mètres à l'intérieur d'un
disque de dix mètres ». Les deux avaient raison ; **la question était
fausse — un câble ne peut pas être obstrué par un plancher.**

Corrigé par `_OBSTACLE_MIN_HEIGHT = 0.20` : un volume plus mince que ça est
une SURFACE, pas un obstacle. **Ce qui a rendu le défaut visible est le
désaccord entre les deux tests** — l'écran rapide disait +10,901 pour la même
course, 21 unités d'écart. Sans le second test le rejet aurait été silencieux
et aurait éliminé toute arrivée au-dessus de l'eau.

### ⚠️ RESTE OUVERT, SIGNALÉ PLUTÔT QUE CORRIGÉ

Le site retenu **(−0,25 / −3,50)** est dégagé de 2,358 u au sol, mais sur le
rendu **son mât passe devant l'anneau et le label du portail Quizz** (0 /
−7,20) : les deux sont sur la même ligne de caméra. Le jeu de contraintes
scanné ne contient aucun terme d'**occultation**, seulement des distances au
sol — donc il ne pouvait pas le voir. C'est une correction de quelques
dixièmes en X, pas un changement de conception, mais elle demande un
re-rendu.

## RECON 3 — AUCUNE POSE DE SUSPENSION N'EXISTE, SUR AUCUN DES DEUX RIGS

Lu directement dans le chunk JSON des `.glb`, pas dans l'éditeur.

| | ours livré (`assets/models/keepy_bear_walker.glb`) | blaireau (`Meshy_AI_Meshy_Merged_Animations.glb`, **SUPPRIMÉ**) |
|---|---|---|
| clips | **`Running`** 0,633333 s / 72 canaux, **`Walking`** 1,033333 s / 72 canaux | **les mêmes deux**, mêmes durées, mêmes 72 canaux |
| skin | `Armature`, **24 joints** Mixamo | `Armature`, **24 joints** |
| pose d'accroche | **AUCUNE** | **AUCUNE** |
| géométrie | — | 5 623 triangles / 10 047 sommets, étendue POSITION 1,700000 |

Joints disponibles : `Hips, LeftUpLeg, LeftLeg, LeftFoot, LeftToeBase,
RightUpLeg, RightLeg, RightFoot, RightToeBase, Spine02, Spine01, Spine,
LeftShoulder, LeftArm, LeftForeArm, LeftHand, RightShoulder, RightArm,
RightForeArm, RightHand, neck, Head, head_end, headfront`.

**La pose de tyrolienne doit donc être FABRIQUÉE.** Deux voies existent dans
le dépôt, et le brief en nomme une qui n'est pas là où il la situe :

* **`ModelSlot.gd` ne contient AUCUN tween** — vérifié, zéro `create_tween`.
  Le patron de pose procédurale de Battle vit dans **`FighterView.gd`**, qui
  tweene `position` / `rotation_degrees` / `scale` **du slot entier**. C'est
  du **corps entier** : aucun bras ne se lève.
* **La pose d'os est possible mais INÉDITE ICI.** `grep` sur tout le dépôt :
  **zéro occurrence de `set_bone_pose*`**. Le squelette n'est jamais lu que
  par `get_bone_global_pose()` (mesure d'échelle du lot B).

**Recommandation** : voie corps entier, via le mécanisme que
`HubActorWalker._freeze()` porte déjà — il tient une pose statique en
`pause()` sur son **propre duplicata** du clip. Il suffirait de le `seek()`
sur la frame de `Walking` où les bras sont les plus hauts (à MESURER, ce n'est
pas fait) au lieu de la frame 0, puis de basculer le corps en arrière sous le
câble par un tween de `rotation_degrees`. La pose d'os reste le repli si le
rendu device refuse — mais elle serait une première pour ce projet et
demanderait sa propre passe rouge-avant-vert.

## RECON 4 — `RIDE_SEAT_Y` N'EST PAS RÉUTILISABLE ; LE PATRON À DEUX CORPS EST CELUI DE LA BALANÇOIRE

**`RIDE_SEAT_Y = 0.14` est un float unique, avec UN SEUL site de lecture** —
`KeepyHopper._place_on_route()` ligne 1173, `global_position = Vector3(where.x,
RIDE_SEAT_Y, where.z)`. C'est la hauteur d'assise du rider **du bateau**, et
rien d'autre. Il n'a **aucune notion d'occupant**, aucun décalage latéral, et
il est écrit sur le corps de `KeepyHopper` lui-même : **un second occupant n'a
littéralement aucun chemin à travers lui.** Non extensible.

**Le patron à deux corps existe déjà, et c'est la BALANÇOIRE.** Sa forme,
relue dans `HubWorld._apply_tilt` / `_bear_follow_seesaw` :

1. Le porteur **publie** `seat_y` et `ride_x` depuis la passe qui l'a DESSINÉ
   (`HubBuilder.seesaws()`) — jamais recopiés en aval.
2. Le siège de Keepy vit dans `KeepyHopper` (`_seesaw_seat`, `follow_seesaw()`),
   choisi par le côté où il a atterri.
3. Le siège de l'ours vit dans `HubWorld` (`_bear_seat`,
   `_bear_follow_seesaw()`), forcé au côté **OPPOSÉ** : `seat_x = -side * ride_x`.
4. ⚠️ **LES DEUX RIDERS SONT ÉCRITS DANS LE MÊME APPEL QUE LA TRANSFORM DU
   PORTEUR**, jamais depuis leur propre `_process`. C'est **mesuré** : un
   rider qui échantillonnait le prop sur son propre callback était **une frame
   entière en retard — 12,0° au pic de la poussée du tourniquet** — et
   `process_priority` n'y change rien, les pas de Tween tombant après le
   `_process` de tout nœud.
5. Les deux gates sont **délibérément différents** : Keepy par
   `is_on_seesaw() and _seesaw_ride.pivot == pivot`, l'ours par
   `_bear_pivot == pivot` **seul** — pour qu'une re-pompe, qui remplace le
   tween en cours de ride, continue de le porter.

**Ce que la tyrolienne ajoute, et qu'aucun des deux n'a** : les deux
occupants **avancent** le long d'une route. Le « siège » devient donc
`(abscisse sur le câble, décalage latéral, hauteur sous le câble)` dans le
repère d'une **nacelle**, et c'est la nacelle que la route écrit. C'est la
forme du signal `ride_moved` du bateau (un porteur mobile publié à un
écouteur, `KeepyHopper` ne touchant jamais l'arbre du prop) **croisée** avec
les deux sièges de la balançoire. Rien à inventer : les deux moitiés existent
et sont validées device.

## ⚠️ PRÉMISSE DU BRIEF TOMBÉE — L'ASSET BLAIREAU N'EXISTE PLUS DANS LE DÉPÔT

Le brief décrit « le blaireau (asset riggé, marche fonctionnelle) ». **Il a
été SUPPRIMÉ le 1er septembre 2026**, commit `c9362a9` « assets: identify the
bear rig by offscreen render, drop the badger », et `CH20_OURS.md` en porte le
compte rendu : deux copies byte-identiques (md5 `dbc6fbcb116a793012c7fe92e0ad2082`,
14 485 536 octets chacune) retirées, **27,6 Mo de source morte**.

Vérifié plutôt que supposé : le fichier a été ré-extrait de
`c9362a9^:assets_source/openworld/perso/…` et son md5 **reproduit exactement**
celui consigné. Il est donc **récupérable**, mais ce n'est pas gratuit — il
porte **2 images embarquées** dans ses 14,5 Mo, et `assets/models/*` est packé
intégralement (`export_filter="all_resources"`).

Le seul animal riggé et marcheur du dépôt aujourd'hui est **l'ours**
(`keepy_bear_walker.glb`), déjà en poste : `HubWorld._setup_bear()` le plante
à `BEAR_REST (0 / 37)` derrière la balançoire du lobe nord.

**Trois options, aucune tranchée ici** :

| | ce que ça coûte | ce que ça donne |
|---|---|---|
| **a. restaurer le blaireau** | +14,5 Mo dans le `.pck` (à mesurer, pas supposé) | le brief à la lettre, deux animaux distincts |
| **b. un SECOND `HubActorWalker` sur l'ours** | zéro payload (« une ressource n'est packée qu'une fois ») | deux ours dans le hub |
| **c. déplacer l'ours existant** | zéro payload | perd le second rider de la balançoire (lot E) |

`HubActorWalker` est **générique par construction** — son propre en-tête :
« Nothing in here names a bear, a seesaw or the hub » — donc l'animal est une
donnée d'une ligne et **la chorégraphie ne dépend pas du choix**. C'est
pourquoi ce lot s'arrête ici plutôt que de trancher : le reste du travail est
identique dans les trois cas.

## RECON 5 — LES DEUX POINTS DÉFINITIFS DE MATHIEU, MESURÉS TELS QUELS

> **Points relevés par Mathieu lui-même, in-game, via l'overlay de position :
> P1 (27,70 / 9,20) et P2 (25,20 / 35,00). FIXES, non renégociables.** Cette
> section ne cherche pas de meilleur site — elle mesure CES DEUX POINTS-LÀ.
> Recon pure, comme RECON 1-4 : aucune structure implémentée, aucune entrée
> de layout ajoutée. Sonde : `scripts/dev/TyrolienneFixedPointsProbe.{gd,tscn}`.
> Neuf rendus sous `docs/renders/tyrolienne_fixed_points/`.

### Godot n'était pas installé dans ce sandbox — téléchargé pour ce lot

Aucun binaire `godot4` n'existait sur la machine de recon. Récupéré depuis
`https://github.com/godotengine/godot/releases/download/4.3-stable/Godot_v4.3-stable_linux.x86_64.zip`
(la même version que `.github/workflows/web-build.yml`, `GODOT_VERSION:
"4.3-stable"`) — **taille vérifiée contre le `Content-Length` avant
extraction** (50 276 070 octets, conforme, cf. le piège de téléchargement
tronqué déjà documenté dans `CLAUDE.md`). Import complet du projet ensuite
fait à partir d'un `.godot` vidé : **36 `.scn` importés, 0 erreur** — compté
avant toute mesure, comme la doctrine l'exige.

### Distance, altitude, orientation — mesurées sur l'arbre construit

| | valeur |
|---|---|
| distance P1 → P2 | **25,921 u** |
| altitude de P1 et de P2 | **0,000 u** — le plateau est un plan plat ; aucune fonction de hauteur de terrain n'existe nulle part dans ce dépôt (grep sur `HubRegion`/`HubBuilder`, zéro résultat), donc l'altitude n'est pas "supposée à zéro", elle est **mesurée comme une absence** |
| cap P1 → P2 | **−5,53°** (0° = +Z) — le corridor part quasiment plein +Z |

⚠️ **CE CAP EST LA DONNÉE QUI DÉCIDE TOUT LE RESTE DE CETTE SECTION.** Il est
quasiment l'INVERSE de la contrainte de cap que RECON 2 avait posée pour ses
deux finalistes (`bearing >= 90° depuis la tour, cap −Z` — la seule direction
dans laquelle `HubCamera`, qui ne tourne jamais, peut voir quoi que ce soit).
Un tracé qui part vers +Z n'est PAS le cas que la bande 14-22u / pente ≥13°
documentait : cette bande vient d'un tracé de cap opposé, et le brief avait
raison de la traiter comme hypothèse et pas comme verdict acquis — elle ne
s'applique tout simplement pas telle quelle ici (voir plus bas).

### Clearance des deux points — le rayon "4,03u déjà mesuré sur DivingBoard" N'EXISTE PAS

**Prémisse tombée, mesurée avant d'être crue.** Grep exhaustif sur tout le
dépôt (`.gd`, `.md`, `.tscn`, `.json`) : aucune constante, aucun commentaire,
aucun rendu ne porte ce chiffre pour un quelconque plongeoir. La seule
mesure de rayon jamais publiée pour la famille `DivingBoard` est celle de
RECON 2 ci-dessus (**1,932 u**, sur l'arbre construit de CETTE session) —
confirmée à nouveau sur l'arbre construit de CE lot : **1,932 u**. Le
chiffre du brief est traité ci-dessous comme un candidat NON VÉRIFIÉ parmi
d'autres, jamais comme une donnée acquise.

**P1 (27,70 / 9,20)** — dans la région (`HubRegion.contains() = true`).
Silhouette bâtie la plus proche : une simple pétale de fleur
(`FlowerPetal0 @ (28,34 / 6,89)`, sommet 0,64u), à **+2,127 u** en clearance
brute (rayon 0).

| rayon de structure candidat | clearance nette | |
|---|---|---|
| 0,000 (point) | +2,127 | OK |
| 1,500 | +0,627 | OK |
| **1,932 (max DivingBoard MESURÉ, cette session)** | **+0,195** | **TIGHT** |
| 2,500 | −0,373 | **CONFLICT** |
| 3,500 (ancienne estimation doctrine) | −1,373 | **CONFLICT** |
| 4,030 (chiffre du brief, NON VÉRIFIÉ, absent du dépôt) | −1,903 | **CONFLICT** |

**P2 (25,20 / 35,00)** — dans la région (le point tombe exactement sur le
bord du carré, `|z| = 35 = PLATEAU_HALF_EXTENT`, cas limite inclusif vérifié
plutôt que supposé). Silhouette la plus proche : une couronne d'arbre
(`TreeCrown @ (23,75 / 23,88)`, sommet 1,85u), à **+10,419 u** — marge
confortable même au rayon 4,03u non vérifié (**+6,389, OK**). **Aucun
conflit côté P2, à aucun rayon candidat testé.**

### Conflit à traiter — P1 SEUL, trois options chiffrées, tranchées par Mathieu

Le conflit n'existe qu'au rayon 1,932u et au-delà, contre UNE SEULE pétale
de fleur (un élément de décor `MultiMesh`, pas une structure interactive) :

1. **Réduire l'emprise de la structure** — un mât/tour de rayon ≤ ~1,6 u à
   P1 clearance +0,5 u ou mieux. Coût : plus fin que le chiffre du brief
   (qui n'a de toute façon aucune source dans ce dépôt).
2. **Déplacer le prop gênant** — retirer/déplacer cette unique instance de
   `FlowerPetal0` du batch `MultiMesh` des fleurs. Coût : une entrée de
   décor cosmétique, zéro incidence gameplay ; rouvre la clearance à
   n'importe quel rayon, 4,03u compris.
3. **Nudge minimal de P1** — quelques dixièmes, à l'écart de (28,34 / 6,89).
   **Non appliqué ici** : le point est déclaré fixe par Mathieu, donc cette
   option n'est présentée que pour arbitrage explicite de sa part, jamais
   comme une correction prise d'initiative.

### Corridor P1 → P2 — câble NIVELÉ, pas de pente (bidirectionnel = même structure aux deux bouts)

Le brief demande un câble **bidirectionnel**, donc les deux tours sont la
MÊME structure — rien à interpoler entre un "départ plus haut" et une
"arrivée plus basse" comme RECON 2 (qui, elle, mesurait une descente à sens
unique). La sonde teste donc un câble à hauteur CONSTANTE, une fois par
delta de plateforme demandé (+ deux valeurs plus hautes pour border le
seuil) :

| delta H | pire écart corridor | contre | à s= (% du trajet) |
|---|---|---|---|
| 1,0 u | **+0,546 u** | `Rock @ (25,64 / 15,94)`, sommet 0,80 | 6,79 u (26,2 %) — TIGHT mais dégagé |
| 2,0 u | **+0,921 u** | landmark non nommé `@ (29,01 / 13,44)`, sommet 7,07 | 4,03 u (15,5 %) — OK |
| 3,0 u | +0,921 u (identique) | idem | idem — OK |
| 4,0 u | +0,921 u (identique) | idem | idem — OK |
| 6,0 u | +0,921 u (identique) | idem | idem — OK |
| 8,0 u | +0,921 u (identique) | idem | idem — OK |

**Aucun conflit de corridor à aucune hauteur testée.** Le même landmark
(un pilier de décor rocheux, visible sur les rendus) reste le facteur
limitant de H=2 à H=8 sans bouger — sa propre étendue verticale couvre tout
cet intervalle de hauteur de câble une fois `_RIDER_DROP` (1,10 u)
soustrait, donc monter la plateforme au-delà de 2u n'achète RIEN de plus en
clearance. H=1u reste clair mais avec une marge nettement plus mince (contre
un rocher différent, plus proche du sol).

### Lisibilité — MESURÉE, pas supposée, et le résultat est ASYMÉTRIQUE

⚠️ **`HubCamera` ne tourne jamais et ne voit que ce qui est à Z PLUS BAS
qu'elle-même — fait déjà documenté par RECON 2, reconfirmé ici par le
rendu, pas par le raisonnement.** Le cap de ce tracé (−5,53°, quasiment plein
+Z) en fait une conséquence directe :

* **Depuis P1 (tour sud, z=9,2) : P2 est invisible, À TOUTE HAUTEUR.**
  `H08__at_P1.png` le montre : Keepy au pied du mât, la caméra dans sa pose
  de repos ne montre que la base du poteau et rien au-delà — P2 est
  géométriquement DERRIÈRE le champ visible de cette caméra, quelle que soit
  la hauteur de plateforme. Ce n'est pas un défaut de hauteur, c'est une
  contrainte structurelle de la caméra que RECON 2 avait déjà nommée pour un
  tracé de cap opposé, et qui joue ici dans l'autre sens.
* **Depuis P2 (tour nord, z=35,0) : tout le corridor est visible, et lit
  BIEN dès H=1-2u.** `H01__at_P2.png` et `H02__at_P2.png` montrent un câble
  orange net qui traverse une bonne partie du cadre en diagonale, grâce au
  raccourci de perspective sur 25,9u de distance — la hauteur RÉELLE du
  câble (1 à 2u) reste faible, mais son extrémité lointaine (celle du côté
  P1) se projette haut dans le cadre du simple fait de la distance. C'est
  net dès le rayon 1u, largement avant tout renfort de hauteur.
* **Vue de survol synthétique (`north_over_corridor`, PAS une position de
  caméra de jeu réelle — juste un contrôle) : confirme le même écart.** À
  H=1-2u les deux mâts sont à peine perceptibles contre la lisière
  d'arbres ; à H=8u le corridor lit clairement comme un "portique" à deux
  montants de même hauteur, câble bien horizontal (`H08__north_over_corridor.png`).
* **Brouillard** : `fog_density = 0,016` (même valeur que RECON 2).
  Occlusion à 25,921u : `1 − exp(−25,921 × 0,016)` = **34,0 %** — moins sévère
  que les 45,6 % à 38u qui avaient fait tomber les tracés longs de RECON 2,
  mais non négligeable ; visible sur les rendus par l'assombrissement de
  l'extrémité P1 vue depuis P2.

**La bande "14-22u / pente ≥13°" ne s'applique PAS ici, et ce n'est pas un
manque de données : elle mesurait la lisibilité d'une DESCENTE à sens
unique vue depuis l'amont (cap −Z). Ce tracé-ci est bidirectionnel, à
niveau constant, de cap quasi +Z — un mécanisme différent, une question de
lisibilité différente (hauteur en pixels + contraste + brouillard, pas
pente), et c'est pour ça que le brief demandait un test par rendu plutôt
qu'une formule.**

### Hauteur de plateforme recommandée

**H ≈ 4u**, provisoire et à valider device :

* le corridor n'a **aucun coût de clearance supplémentaire entre H=2 et
  H=8** (même obstacle, même marge +0,921u) — donc la hauteur ne se choisit
  pas sur la clearance au-delà de 2u ;
* la lisibilité côté P2 (le seul côté d'où le corridor se voit du tout) est
  déjà bonne dès H=1-2u grâce à la perspective, donc la hauteur ne se
  choisit pas non plus uniquement là-dessus ;
* **4u donne une présence structurelle nette** (un mât visible, cohérent
  avec les autres structures du plateau) sans monter jusqu'à des hauteurs
  du niveau du plongeoir (deck 1,8u — un tout autre ordre de grandeur —
  d'où le choix de rester dans la bande basse plutôt que de viser haut par
  réflexe) ni payer le "portique" plus massif de H=8 dont rien dans les
  contraintes mesurées n'impose la taille.

### ⚠️ SIGNALÉ, PAS RÉSOLU — l'asymétrie de visibilité P1→P2

Aucun conflit chiffré ici, mais une question de conception à trancher par
Mathieu avant l'implémentation : la tour de DÉPART (côté par lequel on
grimpe pour partir vers l'autre) ne montrera JAMAIS sa destination à
l'écran, dans un sens comme dans l'autre du trajet bidirectionnel — qui que
ce soit à P1 regardant vers P2 ne voit rien, et symétriquement quelqu'un à
P2 voit tout de suite tout le corridor vers P1. Ce n'est pas nécessairement
un défaut ("on ne voit pas sa destination avant de partir" existe déjà pour
d'autres trajets sur ce plateau sous cette même caméra), mais c'est une
propriété du choix de points fixes de Mathieu qui mérite d'être vue plutôt
que découverte après coup.

## Sonde et rendus

`scripts/dev/ZiplineReconProbe.{gd,tscn}` — **0 assertion, 0 gate**. Elle
instancie `scenes/HubWorld.tscn` livrée (jamais un fixture — le piège
`SubstituteModel.tscn`), désactive `SubViewportContainer.stretch` le temps de
la passe pour mesurer et photographier à **1080×1920** et non à la surface
étirée 1920×1920, et **asserte le rect non dégénéré** pour échouer bruyamment
sous le driver DUMMY au lieu de passer gratuitement.

⚠️ **Elle DOIT tourner sous `xvfb-run -a godot4 --rendering-driver opengl3`**,
jamais `--headless` : PHASE B projette des points monde vers l'écran et
PHASE D lit des pixels.

Rendus sous `docs/renders/zipline_recon/` (exclus du pack : `exclude_filter`
couvre `docs/*`) : `ALL_three_runs`, `A_east__run`, `A_east__arrival`,
`B_south__run`, `B_south__arrival`.

---

## PALIER 1 — LA STRUCTURE SEULE (3 septembre 2026)

> **Ce que ce lot livre : deux tours et un câble, visibles en jeu sur
> staging. Rien d'autre.** Aucune interaction, aucun canal de tap, aucun
> déplacement de personnage, aucune chorégraphie, aucun blaireau — tout
> cela est le palier 2, et une phase de sonde gate le fait que ce lot n'en
> a rien câblé. Prémisses de RECON 5 reprises telles quelles ; les lignées
> de recon antérieures (RECON 2 notamment, qui mesurait une DESCENTE à sens
> unique de cap opposé) ne s'appliquent pas à ce tracé et n'ont pas été
> relues comme si elles s'appliquaient.

### Les décisions figées par Mathieu, et ce que ce lot en a fait

| décision | traitement dans le code |
|---|---|
| P1 = (27,7 / 9,2), P2 = (25,2 / 35,0) | **une seule entrée de layout**, `"position"` + `"far_end"`. Mesurées AS-BUILT à 25,921 u d'écart, cap −5,53°, altitude 0 des deux côtés |
| câble NIVELÉ à 2,0 u | `ZIPLINE_CABLE_HEIGHT`. La sonde asserte `Δy = 0` exactement entre les deux ancrages, pas « à peu près » |
| emprise ≤ 1,932 u | budget de conception de tout le prop. **Mesuré as-built à 1,7880 u**, donc 0,144 u de marge |
| déplacer la fleur | `FlowerPetal0` déplacée de **1,443 u**, de (28,336 / 6,894) à (28,86 / 5,55) |
| asymétrie de visibilité acceptée | rien tenté pour la compenser |
| patron ÉCHELLE interdit | **aucun hotspot sur les escaliers**, et la PHASE F le gate par le texte source |

### ⚠️ LE RAYON DE STRUCTURE EST 1,932 u — le « 4,03 u » N'A JAMAIS EXISTÉ

RECON 5 l'avait déjà écrit ; ce lot le redit parce que c'est le premier à
BÂTIR contre ce nombre. Un « 4,03 u déjà mesuré sur DivingBoard » a circulé
dans plusieurs briefs successifs. **Grep exhaustif du dépôt : zéro
occurrence.** Le seul rayon jamais publié pour cette famille est **1,932 u**,
mesuré deux fois sur l'arbre construit. À P1, une tour de 4,03 u aurait
mordu de **1,9 u** dans le décor voisin — et l'aurait fait sans qu'aucune
erreur ne se lève, parce que rien dans ce moteur ne se plaint qu'un prop en
chevauche un autre.

C'est la seule doctrine de ce lot promue dans `CLAUDE.md` : un chiffre
fantôme qui survit à plusieurs sessions coûte plus cher qu'une mesure.

### ⚠️ L'EMPRISE NAÏVE ÉTAIT FAUSSE DE 3 cm, ET C'EST LA SONDE QUI L'A TROUVÉ

Premier jet du rayon circonscrit :

```
hypot(DECK_HALF + STEP_COUNT * STEP_DEPTH,
      STRINGER_HALF_SPAN + STRINGER_THICKNESS * 0.5)
```

Faux. **Un limon est une boîte INCLINÉE** : sa face inférieure est un
rectangle couché sur la pente, donc le coin qui touche réellement le sol est
poussé plus loin en arrière de `STRINGER_DEPTH/2 × (run / longueur de
pente)`. Sur la première géométrie testée (marches de 0,28) ça faisait
**1,8288 annoncé contre 1,8665 réel** — 3,8 cm de sous-déclaration.

Ce que ça aurait coûté sans la mesure : `FOOTPRINT_RADIUS` est ce que
**tout** test d'atterrissage du plateau lit. Un footprint plus petit que le
prop, c'est Keepy posé **dans** l'escalier, sans erreur ni sonde rouge.

Trouvé parce que la sonde mesure les **HUIT COINS transformés** de chaque
pièce dessinée, et pas l'AABB monde (qui, sur une pièce inclinée, est la
boîte axis-aligned AUTOUR de l'inclinaison et SUR-déclare) ni la constante
relue contre elle-même (qui aurait été verte par construction). La PHASE C
gate en plus que **le footprint publié couvre le dessiné**, dans ce sens-là.

Corrigé en réduisant la marche de 0,28 à **0,26** — pas seulement en
rectifiant le littéral : le vrai chiffre à 0,28 (1,8665) tenait dans le
budget mais avec 6,5 cm de marge, et la géométrie a été resserrée pour en
récupérer 14,4. Chiffres au dossier : **0,26 → 1,7880 · 0,28 → 1,8665 ·
0,30 → 1,9452** (celui-là dépasse).

### La fleur : 1,443 u, et le critère qui a décidé du chiffre

Le conflit n'était PAS un chevauchement de footprints — à sa place
d'origine la fleur laissait déjà **+0,288 u** de jeu au disque de la tour.
Le vrai défaut était ailleurs : elle se tenait à **0,411 u de l'axe de
l'escalier**, c'est-à-dire dans le débouché même de la volée.

Critère retenu, et il n'invente aucun nombre : **le pied de l'escalier, sur
toute la largeur de la volée, doit être un point où `HubWorld` accepterait
de poser Keepy** — la règle que ce fichier applique déjà, `distance ≥ rayon
du footprint + KEEPY_CLEARANCE`, avec `KEEPY_CLEARANCE = 0,66` **lu dans
`HubWorld.gd`** et jamais retapé.

| état | marge au pied de l'escalier P1 | par |
|---|---|---|
| fleur à (28,336 / 6,894) | **−0,931 u** (bloqué) | la fleur elle-même |
| fleur à (28,86 / 5,55) | **+0,283 u** | un buisson à (29,869 / 7,138) |
| tour P2, inchangée | **+12,065 u** | l'arbre le plus proche, à 12 u |

Le déplacement est **minimal sous ce critère**, pas esthétique : un balayage
au pas de 2 cm a cherché le plus court déplacement satisfaisant à la fois la
marge de couloir, l'absence de chevauchement avec les autres props et
`HubRegion.contains()`. La fleur atterrit entre trois buissons
(jeux +0,163 / +0,275 / +0,976), donc dans le même semis qu'avant plutôt
qu'isolée sur une pelouse.

**La fleur est DÉPLACÉE, jamais supprimée** — l'entrée existe toujours, même
variante, même échelle, même rotation.

### ⚠️ BLIND CHECK — pourquoi la PHASE A rejoue l'ancienne position

« Rien ne bloque le pied de l'escalier » est une assertion d'**ABSENCE**, et
ce dépôt a déjà mesuré trois assertions de cette forme passer **VERTES**
contre un mécanisme jamais câblé. La PHASE A remet donc la fleur à
(28,336 / 6,894) dans la liste des footprints et **exige que le test
ÉCHOUE** (il rend −0,931). Ce n'est qu'après ça que le vert sur le layout
livré compte pour quelque chose.

### ⚠️ CETTE SONDE DOIT TOURNER SOUS `opengl3`, PAS `--headless`

Contre-exemple au réflexe « une sonde qui ne lit que des transforms tourne
en headless » : **la PHASE C lit des transforms de `MultiMesh`**, et le
driver DUMMY les rend à l'**IDENTITÉ**, en silence. Toutes les pièces
batchées des deux tours se mesureraient alors à l'origine du monde, l'emprise
sortirait à **0,0000 u**, et le budget de 1,932 serait annoncé
confortablement tenu sur un prop que la sonde n'a jamais vu.

La PHASE 0 existe pour que se tromper de commande échoue **bruyamment** : elle
relit une transform d'instance dont l'origine est connue loin du zéro et
asserte qu'elle revient déplacée.

```
xvfb-run -a godot4 --rendering-driver opengl3 --fixed-fps 60 \
  --path . res://scripts/dev/ZiplineStructureProbe.tscn
```

### Ce qui est construit, et pourquoi c'est cette forme-là

**Une entrée, deux tours.** `&"zipline"` est authored par ses deux bouts,
comme `&"stream"` et `&"divingboard"`, et pour la même raison : deux entrées
qui se feraient face seraient **deux orthographes du même cap**, libres de
diverger. Un câble qui partirait d'une tour et raterait l'autre est une
panne que cette forme ne sait pas exprimer. Le type refuse donc
`rotation_y` et `scale`.

**Conséquence structurelle, et elle est unique dans ce fichier** : une
entrée `&"zipline"` a **DEUX positions au sol**. `ground_footprints()` rend
donc **deux** footprints pour elle, et le contrôle de marchabilité de
`_build` teste les deux — tous deux à travers `_zipline_ends()`, **une seule
lecture** des deux points.

**Par tour** : 2 jambes arrière (sol → deck), 2 mâts avant (sol → 2,0 u, ils
portent le câble : une seule pièce fait les deux métiers, donc le mât et
l'ancrage ne peuvent pas diverger), une traverse de tête, une plateforme,
4 marches, 2 limons. **Le deck est DÉRIVÉ** : `cable_height − rider_drop`
= 0,90 u, donc le départ, le vol et l'arrivée sont au même niveau. Une
hauteur de deck choisie séparément aurait été une seconde réponse à « à
quelle hauteur vole un passager ».

**Le câble est un CYLINDRE, pas un ruban SurfaceTool.** Le ruban du stream
existe parce que sa trace est une courbe large qu'il faut suivre, et qu'un
quad plat a une orientation qui doit être juste pour l'angle d'où on le
regarde. Ce câble-ci est droit, fait 0,07 u de large, et se voit d'une
caméra qui ne tourne jamais : un cylindre fin est juste depuis tous les
azimuts **par construction**, coûte 32 triangles, et reste **opaque** — donc
il n'entre jamais dans la passe transparente, où ce projet a déjà payé une
fois pour un ordre d'écriture de profondeur.

**Couleurs : aucune nouvelle.** Deck et marches en `PONTOON_COLOR`, ossature
en `BOAT_HULL_COLOR` (le couple exact du plongeoir), câble en
`BOAT_RIM_COLOR` — déjà la couleur « ce qu'on attrape » des poignées de
balançoire et des barres du tourniquet. C'est aussi la seule des trois à
franchir le plancher de contraste du sol du hub : **luminance relative
0,563 contre 0,0799 rendu, soit 4,72:1**, largement au-delà de 3,0:1, ce
dont un fil de 0,07 u tendu sur 24 u a besoin pour être vu du tout.

### Draw nodes : 132 → 141, itemisés

Cinq `MeshInstance3D` en propre (une plateforme et une traverse à chaque
bout, plus **l'unique** câble) et **quatre** `MultiMeshInstance3D` partagés :
jambes, mâts, marches, limons — un nœud chacun quel que soit le nombre de
tours. C'est tout l'écart entre **+9 et +25** : huit jambes, quatre mâts,
huit marches et quatre limons coûtent quatre nœuds à eux tous. Relevé dans
`TurnstileProbe` et `WaterTintProbe`, les deux sondes qui gatent ce budget.

### Sonde

`scripts/dev/ZiplineStructureProbe.{gd,tscn}` — **gate un contrat
permanent**, donc elle entre dans le dépôt et compte (ce n'est pas une sonde
de mesure jetable).

| phase | ce qu'elle gate |
|---|---|
| 0 | le renderer rend des transforms de `MultiMesh` déplacées — sinon la PHASE C mesure du vide |
| A | **blind check** : le test de couloir échoue bien avec la fleur remise à sa place d'origine |
| B | les deux tours sont AS-BUILT sur P1 et P2, span 25,921, altitude 0, et elles se font face (`dot = −1`) |
| C | emprise as-built ≤ 1,932 aux deux bouts, identique des deux côtés, et le footprint publié **couvre** le dessiné |
| D | câble nivelé, à 2,0, ancré sur les deux têtes ; le cylindre **dessiné** a exactement la longueur de la portée publiée et son centre |
| E | aucun prop ne chevauche une tour ; le pied des DEUX escaliers est posable ; les deux tours sont dans la région |
| F | **aucun canal de tap** : `HubWorld.gd`, `HubTapInput.gd` et `KeepyHopper.gd` ne mentionnent pas la tyrolienne, et `ziplines()` publie bien les cinq faits que le palier 2 lira |
| G | 141 draw nodes hors portails |

### Ce que ce lot NE peut PAS trancher

Si deux tours et un fil entre elles **se lisent** comme une tyrolienne sur
un écran de 6 pouces, sous une caméra qui ne tourne jamais et depuis
laquelle P1 ne montre pas P2 du tout. RECON 5 a mesuré cette asymétrie et
Mathieu l'a acceptée ; aucune sonde de ce dépôt ne score la lisibilité à
l'intérieur d'une bande de luminance. **C'est la validation device qui
tranche**, et c'est le seul gate qui reste avant `main`.

## PALIER 2 — LE BLAIREAU, LA PORTE DE TAP ET LE TRAJET À DEUX CORPS (3 septembre 2026)

> **Ce que ce lot livre** : la tyrolienne est jouable dans les deux sens.
> Le blaireau attend à une extrémité, un tap sur LUI amène Keepy au pied de
> la tour, les deux traversent ensemble sur une nacelle, et le blaireau
> reste à l'extrémité atteinte — d'où le trajet retour. Prémisses de
> PALIER 1 reprises telles quelles ; **la géométrie des tours et du câble
> n'a pas été retouchée**, la seule addition au prop est la nacelle.

### Le décompte du blaireau — L'ASSET N'ÉTAIT SUR AUCUNE BASE UTILISABLE

Le brief situe le blaireau restauré dans `assets_source/`. **Il n'y était
pas.** Vérifié par ARBRE et non par nom, sur les cent premières refs de
`origin` : `keepy_badger_walker.glb` n'existe que sur
`claude/badger-restore-716m11` (blob `dc8a62d6…`), **branche non mergée**,
et ni `origin/staging` ni `origin/main` ne le portent. C'est exactement le
cas CH20 LOT A de l'ours, que `CLAUDE.md` documente : *« si un lot nomme un
asset dans son brief, vérifier par ARBRE que cet asset existe sur sa propre
base »*. Ce lot a donc commencé par merger cette branche.

⚠️ **Et le piège shell qui a failli le cacher** : `git rev-parse ref:path`
**imprime son argument verbatim** quand il n'arrive pas à le résoudre, au
lieu de ne rien rendre. Un balayage écrit `h=$(git rev-parse "$r:$p"); [ -n "$h" ] && echo …`
déclare donc **toutes** les refs porteuses. Seule la ref dont la sortie est
un vrai sha de 40 caractères l'est.

md5 relevé après merge : `dbc6fbcb116a793012c7fe92e0ad2082`,
14 485 536 octets — **reproduit exactement** celui que RECON 3 avait
consigné en le ré-extrayant de `c9362a9^`.

### L'ÉCHELLE DU BLAIREAU EST DÉRIVÉE, ET LE BANC A ÉTÉ PROUVÉ AVANT D'ÊTRE CRU

Mesure os par os (`Skeleton3D.get_bone_global_pose()` sur les 24 joints,
**dans l'espace propre du rig** via `rig.global_transform.affine_inverse()`
— mesurer à travers `skel.global_transform` puis multiplier par l'échelle
l'applique DEUX FOIS, le bug que CH20 LOT B a fait et publié) :

| rig | étendue de repos mesurée | référence au dossier |
|---|---|---|
| **ours** | **1,671344** | 1,671335 → **9 µu d'écart** |
| **blaireau** | **1,660387** | — (nouveau) |

⚠️ **C'est la reproduction du chiffre de l'ours qui donne au banc le droit
de publier celui du blaireau**, et c'est la règle « reproduire d'abord un
chiffre déjà au dossier avec le banc qu'on s'apprête à utiliser ».

L'échelle, elle, n'a **aucun paramètre libre** :

```
BADGER_SCALE = KEEPY_DRAWN_HEIGHT / BADGER_REST_SPAN
             = 1,3501 / 1,660387 = 0,813125
```

**Le raisonnement, et il est géométrique** : les deux passagers pendent au
MÊME barreau, à 60 cm l'un de l'autre sur un écran de six pouces. Deux
corps de hauteurs différentes accrochés à une seule poignée se lisent comme
« l'un des deux pendouille » ; la même hauteur se lit comme une paire. Donc
la hauteur dessinée du blaireau **EST** celle de Keepy, déjà au dossier.
Écrit comme la division et non comme son résultat, pour qu'il ne puisse pas
dériver d'une moitié. Effet de bord voulu : le blaireau sort visiblement
plus petit que l'ours (1,8901 dessiné), ce qui garde les deux animaux
distincts à l'écran — la raison même pour laquelle CH20 LOT K l'a restauré.

### ⚠️ LA POSE DE SUSPENSION : RECON 3 AVAIT NOMMÉ LE MAUVAIS CLIP

RECON 3 recommandait de `seek()` **`Walking`** sur la frame où les bras
sont les plus hauts. Mesuré sur 129 échantillons de chaque clip, hauteur
moyenne des deux mains au-dessus des hanches, dans l'espace du rig :

| clip | meilleure frame | lift |
|---|---|---|
| `Walking` (blaireau) | t = 0,718 s | **+0,036 u** |
| `Running` (blaireau) | **t = 0,351302 s** | **+0,289 u** |
| `Walking` (ours) | t = 0,751 s | **−0,023 u** |

`Walking` balance les bras **le long du corps** : sa meilleure frame est à
peine au-dessus des hanches, et sur l'OURS la même mesure est **négative**
— les mains ne montent jamais au-dessus des hanches du tout. `Running` à
0,351302 s est la **seule** pose que l'un ou l'autre rig livre avec les
bras réellement levés. Une prémisse de recon tombée sur sa propre mesure,
pas une recon suivie.

Mécanisme : `HubActorWalker.freeze_at(clip, time)`, généralisation de
`_freeze()`. **Rien n'est écrit sur la ressource** — `play` / `seek` /
`pause` sont per-PLAYER, contrairement à un `loop_mode` qui est
per-RESOURCE et fuirait vers toute autre instance du même glb. La pose d'os
(`set_bone_pose`) reste inédite dans ce dépôt et n'a pas été ouverte.

### ⚠️ LE `rider_drop` DE PALIER 1 NE PEUT PAS PORTER UN CORPS DE 1,3501

`ZIPLINE_RIDER_DROP` 1,10 est documenté en PALIER 1 comme « à quelle
distance sous le câble un passager pend ». **L'arithmétique le refuse** :
un corps dont les PIEDS sont à `2,0 − 1,10 = 0,90` a le crâne à **2,25**,
soit **0,25 u À TRAVERS le câble de 2,0** dont il est censé pendre. Rien
dans ce moteur ne s'en plaint ; c'est le genre de chose qui ne se voit que
sur device, et depuis un seul azimut.

Et le sens inverse est fermé aussi : sous un câble à 2,0, un corps de
1,3501 ne peut pas avoir les pieds plus haut que **0,6499**, barreau et
dégagement à zéro. **Il n'existe aucune hauteur de suspension à 0,90.**

Résolution — **le passager pend PAR LES MAINS**, donc son crâne est juste
sous le barreau, pas sous le câble :

```
pieds = cable_height − bar_drop − hang_clearance − hauteur
      = 2,0 − 0,24 − 0,05 − 1,3501 = 0,3599
```

Le deck est à 0,90 : embarquer est donc **un pas hors de la plateforme et
une chute de 0,54 u sur la poignée** — ce qu'est une tyrolienne.
`ZIPLINE_RIDER_DROP` garde son seul vrai métier (la dérivation du deck) et
n'est pas relitigé.

### ⚠️ LE COULOIR A DÛ ÊTRE REMESURÉ DEUX FOIS, ET LA PREMIÈRE MÉTRIQUE ÉTAIT LA MAUVAISE

RECON 5 avait balayé le couloir avec un passager à **0,90**. Il est
maintenant à **0,3599**, et décalé latéralement de ±0,30 : la ligne que
RECON 5 a dégagée n'est pas celle que deux corps parcourent.

**Première réécriture : fausse, et verte-puis-rouge pour une mauvaise
raison.** Elle mesurait `ground_footprints()`, c'est-à-dire le disque de
**MARCHABILITÉ** — « où un corps n'a pas le droit de se TENIR » — qui est à
la fois **rembourré et infiniment haut**. Contre lui, chaque fleur du
plateau était un obstacle pour quelque chose qui passe un mètre au-dessus,
et la phase rapportait **−0,438 u** contre des props qu'un passager franchit
en altitude. C'est littéralement le défaut que `CLAUDE.md` nomme : *« LA
MÉTRIQUE PEUT ÊTRE LA MAUVAISE, ET LE CHIFFRE VERT AVEC »*.

**Métrique retenue** : la GÉOMÉTRIE DESSINÉE dont la bande de hauteur
recoupe celle des passagers. La sonde parcourt l'arbre construit, prend
l'AABB réelle de chaque `MeshInstance3D` **et de chaque instance de
`MultiMesh`**, ne garde que celles dont l'étendue verticale entre dans
`[0,3599 ; 1,7100]`, et mesure le dégagement à plat depuis la ligne du
passager le plus proche.

⚠️ **Et les parties de la tyrolienne elle-même sont exclues PAR ANCÊTRE, pas
par nom.** `add_child` **renomme** un second enfant appelé `"Deck"` : le
deck de la tour lointaine arrive sous le nom `@MeshInstance3D@161`, et un
filtre par nom le laissait passer **comme obstacle**, à −1,41.

**Deux props seulement gênaient réellement** — mesuré, pas supposé :

| prop | dégagement avant | après | déplacement |
|---|---|---|---|
| **landmark** (29,346 / 12,760), variante 2 | **−0,9915** | **+0,1588** | **1,150 u** → (30,491 / 12,871) |
| **Rock#29** (25,637 / 15,944) | **−0,7761** | **+0,1743** | **0,950 u** → (24,691 / 15,852) |

C'est le précédent PALIER 1 exactement : ce lot-là avait déplacé
`FlowerPetal0` de 1,443 u pour le même couloir. Le landmark est celui que
RECON 5 nommait déjà **facteur limitant** ; il reste bien en vue, 1,15 u
plus à l'est.

### DEUX CORPS SUR UNE NACELLE — LE PATRON BALANÇOIRE, CROISÉ AVEC `ride_moved`

RECON 4 avait tranché que `RIDE_SEAT_Y` (float nu, un seul lecteur, écrit
sur le corps de `KeepyHopper`, aucune notion d'occupant) **n'a aucun chemin
pour un second passager**. Le siège devient donc un **vecteur dans le repère
de la nacelle** : `(latéral, hauteur, abscisse)`, et les deux sièges sont le
même fait au signe près.

⚠️ **LES DEUX PASSAGERS SONT ÉCRITS DANS LE MÊME APPEL QUE LA NACELLE**,
`_apply_zip`, et nulle part ailleurs. Ni dans le `_process` du blaireau, ni
sur un signal. Mesure de la balançoire, restituée par la passe rouge :
neutraliser cette seule ligne fait sortir la sonde à **9,307817 u de retard
du blaireau** — le corps reste sur place pendant que la nacelle traverse.

### LES TROIS PORTES, ET CE QUE CHACUNE COÛTE

| porte | mécanisme | ce qui reste possible au joueur |
|---|---|---|
| **1. approche** | `tapped_zipline` gaté par `ZiplineDoor`, retrait au tap | Keepy est en `HOPPING` ordinaire : tout tap retombe sur `tapped_ground` et **annule** `_zipping` |
| **2. trajet** | `State.ON_ZIPLINE`, tap jeté dans la branche d'état | légitime **uniquement** parce que le trajet est **BORNÉ** par un tween linéaire finissant sur l'ancrage de la tour d'arrivée — la licence du hibou, non extensible à une phase non bornée |
| **3. arrivée** | `set_riding(false, arrivée)` + `leave_zipline` | modèle `leave_ride` : **la destination survit à la chute**, un tap achète le trajet ET la marche |

**L'escalier ne porte aucun hotspot**, et la PHASE F de
`ZiplineStructureProbe` le gate par le texte source — elle a été
**INVERSÉE** ce lot : elle assertait « aucun canal de tap nulle part », ce
qui est désormais faux par construction. Ce qui survit à l'inversion est la
moitié qui relevait de la doctrine : le canal existe, il passe par une porte
qui **se retire**, et rien ne fait de la marche une cible de tap.

### ⚠️ LA PASSE ROUGE A TROUVÉ QUE LE RETRAIT ÉTAIT PORTÉ PAR DEUX MÉCANISMES

Premier essai : neutraliser `_riding` seul. **UN rouge là où TROIS étaient
attendus** — et `CLAUDE.md` dit que le nombre d'échecs attendus fait partie
de l'assertion. Cause : `set_riding(true)` pose AUSSI `_at_end = −1`, et
`is_available_at()` comme `accepts_boarding_tap()` refusent déjà sur ce
second fait. La chaîne complète :

| passe rouge | résultat | ce que ça établit |
|---|---|---|
| `_riding` retiré seul | **1 FAIL** | le drapeau est réellement lu |
| `_at_end = −1` retiré seul, `_riding` gardé | **0 FAIL** | **le booléen partagé SEUL ferme les deux extrémités** — la règle du brief, prouvée |
| **les deux** retirés (patron ÉCHELLE complet) | **3 FAIL** | les trois assertions de retrait savent échouer |
| l'écriture du blaireau retirée de `_apply_zip` | **1 FAIL**, retard 9,307817 u | le second passager est bien écrit dans l'appel du porteur |
| l'écriture `_apply_zip(0.0)` immédiate retirée | **1 FAIL**, dot −1,0000 | voir ci-dessous |

Fichiers restaurés et vérifiés **byte-identiques** (`cmp`) après chaque
passe.

### ⚠️ UNE FRAME DE TRAJET RETOUR À L'ENVERS, TROUVÉE PAR LA SONDE

Le premier pas d'un `Tween` tombe à la frame SUIVANTE. Sur un trajet
**retour**, la nacelle porte encore le cap du trajet aller jusqu'à ce pas —
donc une frame de chaque retour dessinait **deux passagers face à l'arrière
de leur propre câble**. Corrigé par un `_apply_zip(0.0)` immédiat à
l'ouverture du trajet, qui est le même « placé tout de suite plutôt
qu'attendre le pas suivant » que le montage de l'ours fait déjà.

### PAYLOAD — MESURÉ AUX DEUX BOUTS, PAS ESTIMÉ

Export web complet des DEUX arbres (baseline = `origin/staging` `b0e0a8f`
dans un worktree séparé, import complet vérifié ; `rm -rf build` avant
chaque export, zéro ligne `Storing File: res://build/`) :

| | baseline | palier 2 | delta |
|---|---|---|---|
| **`index.pck`** | **43 304 320** | **55 139 728** | **+11 835 408 octets (+11,29 Mio, +27,3 %)** |
| `index.wasm` | 35 376 909 | **35 376 909** | 0 — md5 `af4a8fc2925d992348eb30deeeb54360` des deux côtés |
| `index.js` | 331 495 | **331 495** | 0 — md5 `4e08904b1b7107858246af44b602067b` |

Le delta est **entièrement** le blaireau, et il s'itemise exactement :

| part packée | octets |
|---|---|
| `keepy_badger_walker.glb-…scn` | 264 451 |
| `keepy_badger_walker_texture_0.png-….ctex` (**ÉMISSION**) | **5 778 528** |
| `keepy_badger_walker_texture_0_1.png-….ctex` (albédo) | 5 778 528 |
| les deux `.import` | ~3 901 |
| **total** | **11 835 408** ✔ |

⚠️ **LA MOITIÉ ÉMISSION EST DE LA CHARGE MORTE, ET C'EST CHIFFRÉ.**
`HubActorWalker._force_unshaded()` force chaque surface en
`SHADING_MODE_UNSHADED`, et `CLAUDE.md` établit que **l'émission est INERTE
sur une surface unshaded**. Les **5 778 528 octets** de
`texture_0.ctex` sont donc téléchargés par chaque joueur mobile et ne
dessinent rien : **48,8 % du delta de ce lot, 10,5 % du `.pck` de
baseline**. Désactiver le map à l'import ne rendrait rien (un `.ctex` non
référencé est packé quand même) ; **il faut retirer l'`emissiveTexture` du
`.glb` d'`assets/models/`**, ce qui est la méthode que `CLAUDE.md`
documente et qui a déjà économisé jusqu'à 10,7 Mo sur un autre asset.

**NON FAIT DANS CE LOT, DÉLIBÉRÉMENT** : la méthode exige sa propre preuve
au pixel (rendus offscreen byte-identiques à plusieurs azimuts), et elle
touche une copie dérivée d'un asset que Mathieu vient de restaurer. Le
chiffre est publié pour qu'il soit tranché en un mot. La source
d'`assets_source/` reste **byte-identique** (`dbc6fbcb116a793012c7fe92e0ad2082`).

Vérifié aussi : **zéro** ligne `Storing File: res://assets_source/` dans le
log de `savepack` — `exclude_filter` tient, et le `.glb` de 14,5 Mo ne part
qu'**une** fois, par `assets/models/`.

### Draw nodes : 141 → 144, itemisés

La nacelle est **trois** `MeshInstance3D` : une poulie sur le fil, une tige,
et le barreau auquel les deux passagers pendent. Une seule maille aurait
laissé deux corps se balancer sous un point. Relevé et gaté dans les
**quatre** sondes qui portent ce budget (`ZiplineStructureProbe`,
`TurnstileProbe`, `WaterTintProbe`, `SeesawProbe`).

⚠️ **Le blaireau n'est PAS dans ce compte et ne peut pas y être** : comme
l'ours, il vit sous `World/` et non sous `World/Props`, que ce budget est le
seul sous-arbre à parcourir. Son coût est **UN** `MeshInstance3D` (la maille
skinnée unique du rig), publié ici plutôt que porté par une assertion qui,
structurellement, ne peut pas l'observer.

### Sonde

`scripts/dev/ZiplineRideProbe.{gd,tscn}` — **gate un contrat permanent**,
donc elle entre dans le dépôt et compte. **`--headless` est le bon driver
ici** et c'est délibéré : elle ne lit ni pixel, ni transform de `MultiMesh`,
ni point d'écran, ni shader — la nacelle est un `Node3D` ordinaire, les
sièges sont de l'arithmétique, le couloir est un test de distance. Sa sœur
`ZiplineStructureProbe`, elle, lit des `MultiMesh` et exige `opengl3`.
`--fixed-fps 60` est **requis** des deux côtés.

| phase | ce qu'elle gate |
|---|---|
| REGISTRY | la nacelle est bâtie et garée sur l'ancrage proche ; le blaireau est au sol, au point de repos de l'extrémité 0, **hors de l'axe de l'escalier** ; la porte est ouverte à 0 et **fermée à 1** ; le disque de tap suit l'acteur VIVANT |
| SEATS | sièges en miroir, à la même hauteur, DANS le barreau ; crâne **sous** le barreau et sous le câble ; pieds décollés du sol et **sous le deck**. **Blind check** : un corps 0,5 u plus grand pend 0,5 u plus bas |
| CORRIDOR | 210 pièces dessinées recoupent la bande des passagers ; toutes dégagées de **+0,159 u** au pire. **Blind check** : élargir les passagers de 0,659 u rend −0,500 |
| CANCEL | porte 1 — un tap ordinaire pendant l'approche **annule**, la marche n'embarque pas, la porte n'a jamais fermé |
| TRIP | porte 2 — marche réelle par la chaîne de signaux livrée ; **les deux extrémités fermées**, tap refusé aux deux tours ; retard des **DEUX** passagers < 0,0005 u avec **blind check** de 9,31 u parcourus ; un tap en trajet n'ouvre pas de second trajet ; aucun portail ne s'ouvre |
| ARRIVAL | porte 3 — nacelle garée sur l'ancrage lointain à 0,000000 u ; blaireau au sol au repos de l'extrémité 1 ; la porte nomme **1** et plus **0** ; Keepy redescend sur du sol marchable, hors de l'emprise de la tour ; un tap ordinaire le remet en marche |
| RETURN | **l'autre sens** : un tap à l'extrémité 1 embarque, le trajet court 1 → 0, la nacelle **s'est retournée** (dot 1,0000), et la paire est de retour à 0 |
| UNTOUCHED | bateau, hibou, trois échelles, trois plongeoirs, balançoire, tourniquet, trois portails, l'ours : tous encore publiés |

### Ce que ce lot NE peut PAS trancher

Si deux petits animaux pendus à un fil **se lisent** comme une paire qui
prend une tyrolienne, sur un écran de six pouces, sous une caméra qui ne
tourne jamais, depuis une extrémité qui ne voit pas l'autre. Aucune sonde de
ce dépôt ne score la lisibilité à l'intérieur d'une bande de luminance.
**C'est la validation device qui tranche**, et c'est le seul gate qui reste
avant `main` — auquel s'ajoute, cette fois, un arbitrage de payload que
seul Mathieu peut rendre : **+11,29 Mio, dont 5,78 Mio inertes**.

## PALIER 2 SUITE — LE MAP D'ÉMISSION DU BLAIREAU RETIRÉ, TRANCHÉ EN UN MOT (3 septembre 2026)

L'arbitrage laissé en suspens ci-dessus a été tranché : retirer le map. Ce
lot ne touche que la copie installée du blaireau — `assets_source/` reste
byte-identique (`dbc6fbcb116a793012c7fe92e0ad2082`, revérifié après coup).

### La méthode — celle déjà écrite dans `CLAUDE.md`, appliquée sans variante

`Material_1` du blaireau ne porte que deux textures : `emissiveTexture`
(image 0) et `pbrMetallicRoughness.baseColorTexture` (image 1) — pas de
normal, pas de metallicRoughness séparé. Confirmé en dumpant le chunk JSON
du `.glb` : `emissiveFactor=[1,1,1]`, plus un boost
`KHR_materials_specular.specularColorFactor=[2,2,2]` qui ne s'applique lui
non plus jamais (même surface unshaded). Script Python (`struct`+`json`
manuels, pas de dépendance) :

1. Découper le chunk BIN à l'octet près, du `byteOffset` de la bufferView de
   l'image d'émission jusqu'au `byteOffset` de la bufferView SUIVANTE (donc
   en emportant le padding d'alignement inter-chunks, pas seulement le
   `byteLength` déclaré — sans ça, la bufferView restante se retrouve décalée
   de quelques octets et le PNG suivant devient illisible).
2. Décaler tous les `byteOffset` postérieurs de la longueur coupée.
3. Retirer l'entrée `bufferViews`, `images` et `textures` correspondantes,
   et réindexer chaque référence restante (`images[].bufferView`,
   `accessors[].bufferView`, `textures[].source`,
   `material.pbrMetallicRoughness.baseColorTexture.index`) — aucun
   `sparse accessor` sur cet asset, donc pas de cas à couvrir en plus.
4. Recoller un GLB valide (magic, JSON paddé à 4 octets avec des espaces,
   BIN paddé à 4 octets avec des zéros, longueur totale repatchée).

Vérifié avant d'écraser le fichier installé : `pygltflib` charge le résultat
sans erreur (155 accessors, 1 mesh, 1 skin, 2 animations — **identique** à
l'avant, aucune donnée de squelette ni d'animation touchée), et le MD5 de
l'image restante dans le nouveau `.glb` est **byte-identique** au MD5 de
l'image baseColor originale — la seule chose qui a changé est que l'image
d'émission n'existe plus.

`keepy_badger_walker.glb` : **14 485 536 → 7 552 692 octets** (quasi moitié,
cohérent : les deux textures pesaient à un octet près la même chose).
Siblings extraits par l'import Godot (`gltf/embedded_image_handling=1`,
Extract) : les DEUX anciens PNG (`_texture_0.png` = émission,
`_texture_0_1.png` = baseColor, noms attribués par collision sur le nom
d'image partagé `"texture_0"` dans le `.glb` d'origine) supprimés — pas
seulement l'émission — parce qu'un unique PNG restant se réextrait sous le
nom `_texture_0.png`, **sans le suffixe** : laisser l'ancien fichier de ce
nom (qui contenait l'émission) aurait silencieusement mélangé un octet
d'émission périmé avec un nouveau baseColor au prochain import qui touche
autre chose. Reproduit la même bascule de nommage que `CLAUDE.md` documente
déjà pour le hero écureuil.

### PREUVE AU PIXEL — byte-identique aux quatre azimuts, pas juste "proche"

Sonde jetable `scripts/dev/BadgerEmissionAudit.{gd,tscn}` (supprimée avant
ce commit, per la règle sonde-jetable) : bâtit l'acteur via
`HubActorWalker` exactement comme `HubWorld._badger_rest()` le fait —
même `model_scene`, même `BADGER_SCALE` (0,813125), même
`_force_unshaded()` — et capture `get_viewport().get_texture().get_image()`
à yaw 0°/90°/180°/270°, sous `xvfb-run --rendering-driver opengl3` (jamais
`--headless` seul, pour la raison DUMMY-driver déjà documentée : un premier
essai avec `--headless` en plus du flag opengl3 a fini en `Terminated` au
timeout, symptôme de `--headless` écrasant le driver en silence — retiré, le
rendu a immédiatement fonctionné).

**Blind check d'abord** : yaw 0° contre yaw 90° du même run diffèrent
(max 230, moyenne 4,66 sur 0-255) — la sonde SAIT voir une différence quand
il y en a une, donc un résultat "identique" ensuite n'est pas gratuit.

**Résultat, les quatre azimuts, MD5 du PNG entier avant/après** :

| azimut | avant | après |
|---|---|---|
| 0° | `b49f7d65d1ea12b67808e6979b0c1766` | **identique** |
| 90° | `3eb80b9353e5616099de74fcba8ffb2f` | **identique** |
| 180° | `c724a1144b8592c19f96e7f6cbd3a942` | **identique** |
| 270° | `13361eaed990308b9c1c58873bd15ffb` | **identique** |

Byte-identique, pas seulement visuellement proche — confirme au pixel près
ce que `_force_unshaded` (shading_mode UNSHADED) prédisait : le canal
d'émission ne rendait littéralement rien.

### PAYLOAD — mesuré aux deux bouts, sur le `.pck` réel, pas sur le filtre

Export release Web complet, gabarit 4.3-stable, deux worktrees comparés
(`git stash` avant/après plutôt qu'un vrai worktree séparé — les deux états
tiennent dans la même branche et `build/`+`.godot/` sont nettoyés entre les
deux pour éviter l'auto-contamination documentée) :

| | `index.pck` | `index.wasm` |
|---|---|---|
| avant (badger avec émission) | 55 139 728 | 35 376 909 |
| après (émission retirée) | **49 360 672** | 35 376 909 (inchangé) |
| delta | **-5 779 056 octets (-5,51 Mio)** | 0 |

`index.wasm` byte-identique aux deux bouts (35 376 909, le contrôle
d'identité documenté) confirme qu'aucun code moteur n'a bougé — seul l'asset
a changé. Le TOC du `.pck` lui-même (parsé directement, format GDPC v2, pas
de log `savepack` à défaut) confirme **une seule** entrée `.ctex` pour le
blaireau après coup
(`keepy_badger_walker_texture_0.png-…95948e28…ctex`, **5 778 528 octets** —
exactement le chiffre publié au Palier 2 sous forme d'estimation, ici
mesuré) là où il y en avait deux avant. Le delta mesuré (5 779 056) dépasse
ce chiffre de 528 octets — le fichier `.import` de la texture retirée
(283 octets) et la réduction du JSON du matériau dans le `.scn` importé
expliquent l'écart, pas une erreur de mesure.

### AUTRE CHARGE MORTE DÉJÀ INSTALLÉE — REPÉRÉE, CHIFFRÉE, **NON TOUCHÉE**

Scan de tous les `.glb` d'`assets/models/` (15 fichiers) pour tout matériau
portant `emissiveTexture`/`normalTexture`/`occlusionTexture`/
`metallicRoughnessTexture` — puis mesure du poids RÉEL de chaque `.ctex`
correspondant dans le `.pck` déjà exporté ci-dessus (celui qui contient
encore ces quatre assets intacts), par lecture directe du TOC du pack
(format GDPC v2 : magic, `pack_format`/version, `pack_flags`+`file_base`,
16 uint32 réservés, `file_count`, puis par fichier
chemin+offset+taille+md5+flags) plutôt que par estimation :

| asset | canal mort | matériau | taille `.pck` (octets) |
|---|---|---|---|
| `keepy_bear_walker.glb` | `emissiveTexture` | **PAS** `KHR_materials_unlit` dans le `.glb` — unshaded forcé à l'exécution par `HubActorWalker._force_unshaded()`, **exactement le même mécanisme que le blaireau avant ce lot** (même forme de matériau : `emissiveFactor=[1,1,1]`, même boost `KHR_materials_specular=[2,2,2]`) | **4 330 988** |
| `keepy_cabin_decor.glb` | `normalTexture` | `KHR_materials_unlit` déclaré dans le `.glb` | **8 619 000** |
| `keepy_hibou_pursuer.glb` | `emissiveTexture` | `KHR_materials_unlit` déclaré | 353 606 |
| `keepy_hibou_pursuer.glb` | `metallicRoughnessTexture` | `KHR_materials_unlit` déclaré | 408 840 |
| `keepy_hibou_pursuer.glb` | `normalTexture` | `KHR_materials_unlit` déclaré | 527 212 |
| `keepy_owl_decor.glb` | `normalTexture` | `KHR_materials_unlit` déclaré | **4 767 746** |
| **TOTAL** | | | **19 007 392** |

Soit **19,0 Mio** de charge morte supplémentaire déjà dans `main`/`staging`,
avant même de compter ce lot. Le cas du **bear** est le plus proche parent
du blaireau — identique dans sa forme (même `HubActorWalker`, même
émission jamais rendue) — et serait probablement la prochaine cible la
moins ambiguë si un futur lot en reçoit le mandat. Les trois autres
(`cabin_decor`, `hibou_pursuer`, `owl_decor`) sont déjà `KHR_materials_unlit`
dans leur `.glb` — l'importeur glTF ne lie même pas ces maps à l'import
(règle déjà documentée), donc leur suppression n'a **aucun risque de
différence rendue** à prouver, seulement le même exercice mécanique de
découpe binaire fait ici. **Aucune des deux catégories n'a été touchée dans
ce lot** — chiffré et publié pour arbitrage, comme demandé.

### Sonde

`BadgerEmissionAudit.{gd,tscn}` était une mesure ponctuelle (comparer deux
états d'un seul asset, une fois) et non un contrat permanent — supprimée
avant ce commit, per la règle sonde-jetable. Rien de nouveau n'entre dans
`scripts/dev/` pour ce lot.

## LOT — RETOUR DEVICE : ÉCHELLE DU BLAIREAU, ET LE POINT NORD DIAGNOSTIQUÉ SANS ÊTRE TOUCHÉ (3 septembre 2026)

### Sujet 1 — le blaireau était scalé pile à la hauteur de Keepy, et ça ne lisait pas comme "plus imposant"

`BADGER_SCALE` avait été dérivée au lot précédent pour matcher EXACTEMENT
`KEEPY_DRAWN_HEIGHT` (1,3501) — raisonnement volontaire pour la scène où
les deux passagers pendent côte à côte à UNE seule barre de tyrolienne.
Retour device de Mathieu (captures à l'appui) : au sol, où le blaireau
passe l'essentiel de son temps à l'écran, il lit comme trop petit à côté de
Keepy plutôt que comme "plus imposant".

Nouvelle dérivation, par MOYENNE GÉOMÉTRIQUE sur les trois acteurs du
casting (Keepy, blaireau, ours) plutôt qu'un chiffre choisi à l'œil :

    k = sqrt(BEAR_DRAWN_HEIGHT / KEEPY_DRAWN_HEIGHT) = sqrt(1,890073 / 1,3501) = 1,183195
    BADGER_DRAWN_HEIGHT = k * KEEPY_DRAWN_HEIGHT = 1,597431   (était 1,3501)
    BADGER_SCALE        = BADGER_DRAWN_HEIGHT / BADGER_REST_SPAN = 0,962085  (était 0,813125)

Le pas Keepy→blaireau et le pas blaireau→ours sont ainsi le MÊME saut
multiplicatif (+18,3% chacun) — ni disproportionné, ni à peine perceptible,
et le blaireau reste chiffrablement plus petit que l'ours (1,597431 <
1,890073). Preuve visuelle : rendu offscreen xvfb+opengl3, Keepy et
blaireau côte à côte, avant/après (spike jetable, supprimé avant ce
commit) — le blaireau dépasse nettement la tête de Keepy dans le rendu
"après" là où il était à peu près à égalité dans le rendu "avant".

Effets de bord mesurés et corrigés : `BADGER_SIDE_OFFSET` (0,95, inchangée)
voit sa marge de dégagement contre le rail de l'escalier de la tyrolienne
passer de +0,23u à +0,175u sous le gabarit élargi — resserrée mais pas un
conflit, donc laissée telle quelle. Les deux passagers ne partagent plus
une même hauteur : `_zip_seat` du côté blaireau lit désormais
`BADGER_DRAWN_HEIGHT` et non plus `KEEPY_DRAWN_HEIGHT`. Fait remarquable
retrouvé par le calcul : la hauteur de la TÊTE sous la barre est
INDÉPENDANTE de la taille du corps (elle s'annule dans la formule du
siège) — les deux têtes restent donc alignées sous la même barre, seuls
les PIEDS bougent (Keepy à 0,3599, le blaireau, plus grand, à 0,112569).
`ZiplineRideProbe` (PHASE SEATS, PHASE TRIP, `_corridor_rows`) a été
réécrite pour asserter cela directement plutôt que de supposer l'égalité
de hauteur — 0 échec après correction (un premier passage a trouvé 1 échec
réel : un plancher de "hors sol" à 0,2u codé en dur, sous la hauteur de
pied du blaireau à 0,112569 ; corrigé pour dériver le plancher du siège de
chaque corps plutôt que d'un chiffre partagé arbitraire).

### Sujet 2 — le point nord P2 : DIAGNOSTIQUÉ, NON CORRIGÉ (cas b confirmé)

Sonde jetable (`P2NorthDiagSpike`, supprimée avant ce commit) lisant
directement l'arbre construit :

    P2 tower position:  (25.2, 0, 35.0)   -- EXACTEMENT sur PLATEAU_HALF_EXTENT
    P2 stair_foot:       (25.037, 0, 36.682)
    HubRegion.contains(stair_foot) = FALSE
    HubRegion.clamp_to(stair_foot) = (25.037, 0, 35.0)   -- manque 1.682u
    anneau r=0.5/1.0/1.5 autour du stair_foot : 0% marchable
    anneau r=0.5..2.0 autour de P2 lui-même   : 52.8% marchable (coupé pile à l'arête)

Root cause : `_build_zipline_tower` construit l'escalier VERS L'ARRIÈRE de
chaque tour relativement à son propre `forward` ("vers l'autre tour"). Pour
la tour de P1 (sud), l'arrière pointe vers l'intérieur du plateau — sans
souci. Pour la tour de P2 (nord), le même `forward` pointe VERS P1 (sud),
donc son "arrière" pointe encore plus au NORD que P2 — et P2 est déjà posé
pile sur le bord (z=35=`PLATEAU_HALF_EXTENT`). Même les jambes arrière de
la tour (z=35,547) débordent du monde jouable de 0,547u, en plus de
l'escalier (débord 1,682u). Le lobe nord existant (centré (0,35), rayon
12) ne couvre pas ce point : distance P2↔centre du lobe = 25,2u, très
au-delà du rayon 12.

Les deux autres hypothèses écartées PAR MESURE et non par supposition :
RECON 5 (déjà au dossier) mesurait ZÉRO conflit de clearance décor à P2 à
tout rayon candidat testé (+10,419u de marge à la silhouette la plus
proche) — pas de cas (a). Les deux props déplacés au palier 2
(`landmark` à (29,346/12,760)→(30,491/12,871), `Rock#29` à
(25,637/15,944)→(24,691/15,852)) sont à z≈12,8-15,9, au milieu du couloir
P1→P2, à plus de 19u de P2 — pas de cas (c). C'est le cas (b) : une
contrainte de bord du monde, pas un objet ni un prop.

**Aucun code touché pour ce sujet**, conformément à la consigne — options
chiffrées pour arbitrage de Mathieu :

1. **Un petit lobe HubRegion dédié à P2** (même forme que le lobe nord
   existant : un disque à cheval sur le bord), rayon ~3,0u centré sur P2
   lui-même — couvre le stair_foot (débord 1,682u) avec marge de
   manœuvre. Coût : ~14u² de sol neuf (0,3% du carré), un recon dédié pour
   confirmer (mesuré, pas supposé) que ça ne déplace pas la diagonale pire
   cas 18,700s — l'argument "un lobe posé sur un bord n'allonge aucune
   diagonale entre coins" qui a déjà validé le lobe nord existant
   s'applique probablement ici aussi, mais reste à VÉRIFIER par sonde
   avant d'être cru. Portée comparable au recon+lot du lobe nord du
   28 août.
2. **Réorienter/raccourcir l'escalier de la seule tour P2** — évite de
   toucher `HubRegion`, mais casse la symétrie "une structure, deux tours,
   un seul bâtisseur" documentée comme délibérée dans
   `_make_zipline()`, et ne réglerait que l'atteinte du pied d'escalier —
   pas la liberté de manœuvre générale autour de la tour (les jambes
   arrière débordent aussi). Plus invasif que l'option 1, non recommandé.

Aucune des deux n'est implémentée ici.

## LOT — LE LOBE HubRegion DÉDIÉ À P2 : LE DÉBORD NORD RÉSORBÉ (3 septembre 2026)

Suite directe du **Sujet 2** du lot précédent, qui avait diagnostiqué le
point nord sans y toucher et laissé deux options chiffrées à l'arbitrage.
**L'option 1 est retenue et implémentée** : un lobe `HubRegion` dédié,
disque à cheval sur le bord, centré sur P2 lui-même. L'option 2
(réorienter l'escalier de la seule tour P2) reste écartée pour les raisons
déjà au dossier — elle casse la symétrie « une structure, deux tours, un
seul bâtisseur » ET ne réglerait pas les jambes arrière.

### La recon a été faite AVANT de toucher `HubRegion`, comme exigé

Sonde jetable `P2LobeReconSpike` (headless, `--fixed-fps 60`, supprimée
avant ce commit), lancée sur l'arbre `staging` **non modifié**.

⚠️ **Le banc a d'abord dû restituer un chiffre déjà au dossier**, faute de
quoi il n'avait pas qualité à en publier un neuf :

    square diagonal (published 66 hops / 18.700 s)   66 hops  1122 frames  18.700 s
    -> bench REPRODUCES the published diagonal (18.700 s)

Puis le balayage du rayon, sur le hopper réel. La cible n'est **pas** la
pointe +Z du disque mais son **point le plus éloigné DU COIN OPPOSÉ** —
c'est la paire qu'un lobe crée réellement, et viser la pointe aurait mesuré
un trajet plus court en l'appelant le pire :

| rayon | trajet coin lointain → pointe | verdict |
|---|---|---|
| 2,0 | 63 hops / 17,850 s | plus court que la diagonale |
| 2,5 | 63 hops / 17,850 s | plus court |
| **3,0** | **64 hops / 18,133 s** | **plus court — retenu** |
| 3,5 | 64 hops / 18,133 s | plus court |
| 4,0 | 64 hops / 18,133 s | plus court |
| 5,0 | 65 hops / 18,417 s | plus court |
| *(référence)* lobe nord existant | 60 hops / 17,000 s | plus court |

**La diagonale reste le pire trajet du hub à TOUS les rayons balayés**, y
compris très au-delà de celui retenu. C'est le même argument qui avait rendu
le lobe nord abordable le 28 août — un lobe boulonné près d'un BORD
n'allonge aucune diagonale entre COINS — mais il est ici **mesuré et non
transporté** : le lot D avait justement mesuré qu'un carré élargi, lui,
dépense tout le budget (40 → 21,533 s, 41 → 22,100 s contre 22 s).

### Le sol neuf est VIDE, et ça a été balayé et non supposé

À 5,0 u de P2 — soit bien au-delà du rayon retenu, donc un rayon plus petit
est propre par construction :

    props whose footprint reaches within 5.0 u of P2:
      (25.2, 0, 35)  r=1.783  gap to P2 = -1.7831 u    <- la tour elle-même, rien d'autre
    water bodies reaching within 5.0 u of P2:
      lake (15.5, 0, -19) r=16.0  gap = 38.8643 u
      lake (-12, 0, -19.5) r=10.0  gap = 55.9855 u
      0 within reach
    existing north lobe centre (0, 0, 35) r=12.0 -- P2 is 25.200 u away (rim gap 13.200)

**Aucun prop, aucune eau, aucune autre structure.** Et les deux lobes sont
**disjoints de 10,200 u de bord à bord** (gate dans la sonde), donc aucun
des deux ne peut masquer la couverture de l'autre.

### Le rayon 3,0 est MESURÉ, et la marge est le sujet — pas le minimum

Les cinq points que la tour pose réellement au sol, relus sur l'arbre
construit :

| partie | position | r depuis P2 | `contains()` AVANT |
|---|---|---|---|
| `stair_foot` | (25.037, 36.68212) | 1,6900 | **false** |
| stringer foot | (25.45505, 36.72263) | **1,7414** | **false** |
| stringer foot | (24.61896, 36.64161) | **1,7414** | **false** |
| jambe arrière | (25.69439, 35.60048) | 0,7778 | **false** |
| jambe arrière | (24.59952, 35.49439) | 0,7778 | **false** |

La chose la plus éloignée est à **1,7414 u**, et l'emprise circonscrite
publiée (`ZIPLINE_FOOTPRINT_RADIUS`) vaut **1,78308**. Rayon 3,0 laisse donc
**1,2586 u** de sol marchable au-delà de la partie la plus large du prop —
soit près de **deux `KEEPY_CLEARANCE` (0,66)** de manœuvre, pas un liseré qui
admet l'escalier de justesse. Le lot vise explicitement la marge, comme le
brief l'exigeait.

### ⚠️ UN GAIN QUI N'AVAIT PAS ÉTÉ ANTICIPÉ : L'ANNEAU DE DÉPÔT ÉTAIT AMPUTÉ

`HubWorld._ride_exit_point` dépose un rider sur un anneau de
`clear_radius + TURNSTILE_EXIT_MARGIN` = **2,6331 u** autour de la tour, et
**écarte tout candidat que la région ne contient pas**. À P2, tout l'arc
NORD était donc jeté : un rider arrivant de P1 ne pouvait être déposé que
côté plateau. Avec le lobe, l'anneau entier (**360/360**) est dans la
région, avec **0,3669 u** de reste sous le rayon du lobe. Gaté dans la
sonde plutôt que laissé au hasard — c'est une conséquence du rayon, pas une
coïncidence.

### La forme retenue : une TABLE, dès la première entrée

`HubRegion.STRUCTURE_LOBE_RADIUS` + `_structure_lobes`, publiée par
`structure_lobes()`. `contains()` boucle dessus, `clamp_to()` ajoute un
candidat par entrée — **aucun nouveau TYPE de cas**, exactement la propriété
qui avait fait choisir l'union pour le lobe nord.

⚠️ **Un `Array` et pas un scalaire, dès l'entrée unique.** Ce dépôt a déjà
payé l'autre choix : le plongeoir avait une géométrie générique derrière un
singleton, une seconde planche a été **dessinée et jamais grimpable**, et
défaire ça a coûté son propre lot. Une seconde structure posée sur un bord
est désormais **une ligne dans cette table et rien d'autre**.

⚠️ **Le centre est une SECONDE ORTHOGRAPHE du `far_end` du layout**, et il
est **gaté** au lieu d'être cru. `HubRegion` ne peut pas lire le layout —
`HubBuilder` lui demande `contains()` PENDANT qu'il construit — donc le
centre y est un littéral. C'est exactement le régime des centres de lacs, et
il est traité pareil : `ZiplineStructureProbe` PHASE H compare la ligne de
table à la tour que le bâtisseur a réellement plantée.

### ⚠️ ROUGE AVANT VERT — DEUX passes, et le compte d'échecs faisait partie de l'assertion

**Passe 1 — le terme de lobe neutralisé dans `contains()`** (`if false and …`),
`ZiplineStructureProbe` relancée sous `xvfb + opengl3` :

    --- 16 failure(s) ---

**16, exactement le nombre prédit, et chacun sur l'assertion attendue** :
les 5 parties au sol + l'agrégat (6), les 5 anneaux autour de P2 (5), les
2 anneaux autour du pied d'escalier (2), l'anneau r=1,5 (1), le clamp « plus
proche » (1), le clamp « laissé sur place » (1). Aucun ailleurs.

⚠️ **Et les chiffres du rouge reproduisent le diagnostic déjà au dossier** :
`the full ring around the stair foot at r=0.5 is walkable (0/360)` — le lot
précédent avait mesuré « anneau r=0,5/1,0/1,5 autour du stair_foot : 0%
marchable ». `181/360` autour de P2 (50,3 %) contre les « 52,8 % » publiés,
la différence étant que l'ancienne mesure moyennait une plage de rayons.
Fichier restauré et vérifié **byte-identique** (`cmp`).

**Passe 2 — l'assertion de TRAVERSÉE**, qui est neuve elle aussi et devait
prouver qu'elle sait voir un lobe devenu le pire cas. `STRUCTURE_LOBE_RADIUS`
poussé à 30,0, `SeesawProbe` relancée :

    far corner -> structure lobe (25.2, 0, 35) r=30.0  82 hops  1394 frames  23.233 s
    FAIL  ... costs 23.233 s, still SHORTER than the diagonal 18.700 s

Elle tire. Les 4 autres rouges de cette passe sont du **collatéral attendu**
et non des défauts : un disque de rayon 30 avale le lobe nord, donc la
`PHASE LOBE` existante voit sa pointe, son aire de demi-disque et son coin
de carré changer. Restauré et vérifié byte-identique.

### ⚠️ BLIND CHECK PERMANENT, parce que « tout est couvert » passe GRATUITEMENT

La PHASE H rejoue **en permanence** la région telle qu'elle shippait avant
ce lot (carré ∪ lobe nord ∪ shore pad) et **EXIGE que le test de couverture
y échoue** avant de laisser la région livrée le passer :

    OK  BLIND CHECK: without the structure-lobe term, ALL 5 ground parts of the P2 tower
        are outside the region (5)
    OK  BLIND CHECK: and the manoeuvring ring at r=2.0 is only 181/360 walkable without it

La région héritée est **réécrite dans la sonde** plutôt qu'atteinte par un
interrupteur dans `HubRegion` : une sonde capable d'éteindre la région
livrée est une sonde capable de la laisser éteinte.

### PREUVE PAR RENDU OFFSCREEN — Keepy a réellement fait le tour

Sonde jetable `P2ManoeuvreCaptureSpike` (`xvfb + opengl3`, viewport
1080x1920, supprimée avant ce commit). Huit stations à 2,4 u autour de la
tour, **atteintes par `hop_to` sur le hopper réel** via la destination que
`clamp_to` renvoie vraiment — pas par une table de flottants.

    -> the OLD region moved 3 of the 8 stations; the shipped one honours 8 of 8
    -> Keepy ARRIVED at 8 of the 8 stations on the shipped region

Les trois stations que l'ancienne région déplaçait : az045 (**1,697 u**),
az090 (**2,400 u**), az135 (**1,697 u**) — toutes rabattues sur z = 35.

Les rendus le montrent sans ambiguïté : sur `before_az090.png` Keepy est
plaqué au bord, **dans** l'escalier de la tour, incapable de passer
derrière ; sur `after_az090.png` il se tient franchement **au nord de la
tour**, au-delà de l'escalier, sur du sol qui n'existait pas.

⚠️ Le résidu de **0,337 u** sur az045/az135 n'est pas un défaut de région :
c'est le comportement déjà documenté d'une marche qui **finit PRÈS de sa
cible, jamais DESSUS** (0,401 u mesuré ailleurs au dossier). Les stations
visées exactement (az000, az090) tombent à 0,000.

### Sondes

| sonde | résultat |
|---|---|
| `ZiplineStructureProbe` (xvfb+opengl3) | **82 checks, 0 échec** — PHASE H neuve, 25 checks |
| `SeesawProbe` (headless, `--fixed-fps 60`) | **60 checks, 0 échec** — diagonale toujours **18,700 s**, lobe P2 à **18,133 s** |

Aucune sonde permanente ajoutée : les deux spikes de mesure sont supprimées
avec ce lot, donc `ProbeTimeoutAudit` retrouve son compte de scènes (65,
inchangé).

### Ce que ce lot NE peut PAS trancher

Si **3,0 u se SENT comme de la place** autour de la tour sur un écran de
6 pouces. La sonde mesure des distances et des anneaux ; que le tour de la
tour se fasse *confortablement* au doigt reste l'appel device de Mathieu.
Et le lobe reste **derrière le spawn** — `HubCamera` ne lace jamais — donc
ce sol neuf se voit dans les mêmes conditions que celui du lobe nord.

## PALIER 2 SUITE 2 — LES QUATRE AUTRES CANAUX MORTS, TRANCHÉS (3 septembre 2026)

Les 19,0 Mio de charge morte repérés et chiffrés à la fin de la section
précédente (« AUTRE CHARGE MORTE DÉJÀ INSTALLÉE — REPÉRÉE, CHIFFRÉE, NON
TOUCHÉE ») ont reçu leur arbitrage : les quatre retirer. Même méthode que le
blaireau, appliquée sans variante, un asset à la fois. `assets_source/`
untouched pour les quatre, revérifié par hash après coup.

### bear_walker — LA MÊME COMPLICATION QUE LE BLAIREAU N'AVAIT PAS

`HubActorWalker._force_unshaded()` (le mécanisme partagé bear/badger) porte
un avertissement écrit AVANT ce lot : « pour ce rig en particulier, c'est
actuellement un no-op sur les pixels [...] et cette carte est
byte-identique à sa carte d'albédo ». Ce paragraphe est générique au fichier
partagé, pas spécifique au blaireau — donc vérifié pour l'ours plutôt que
supposé hérité.

Mesuré (`pygltflib` + dump JSON) : même forme de matériau que le blaireau
(`metallicFactor=1`, `emissiveFactor=[1,1,1]`,
`KHR_materials_specular.specularColorFactor=[2,2,2]`, pas de
`KHR_materials_unlit`). **Complication réelle, isolée avant chirurgie** : les
PNG émission et albédo bruts ne sont **PAS byte-identiques**
(`916fbd3a...` / 4 955 175 o contre `28b0bd6f...` / 4 955 241 o) — contrairement
au blaireau. Décodés en pixels (PIL, RGBA), **0 pixel différent sur
2 048×2 048** : la différence n'est qu'un ré-encodage PNG (compression),
jamais un pixel. Le canal reste mort pour la même raison que le blaireau :
`_force_unshaded` bascule sur l'albédo, pixel-identique à l'émission.

### cabin_decor / hibou_pursuer / owl_decor — mécaniquement inertes, vérifié plutôt que supposé

Les trois portent `KHR_materials_unlit` dans le `.glb` — la règle déjà
documentée (« l'importeur glTF ne lie JAMAIS `normal_texture` ni
`metallic_texture` sur un matériau UNLIT ») s'applique sans variante.
Confirmé en plus, en lisant `ModelSlot.gd` et `CabinInterior.gd` : ni l'un
ni l'autre n'applique de surface override sur le corps du modèle installé
— seul `Pursuer.gd` duplique un matériau, et c'est celui des YEUX (des
`SphereMesh` de la scène, pas du `.glb`), jamais le corps. Le matériau qui
dessine réellement ces trois assets est donc **exactement** celui que
l'importeur a lié depuis le `.glb`, sans détour.

`keepy_hibou_pursuer.glb` portait 3 canaux morts sur le MÊME matériau
(`emissiveTexture`, `normalTexture`,
`pbrMetallicRoughness.metallicRoughnessTexture`) — traité en une seule
passe de chirurgie plutôt que trois, `strip_glb_textures.py` retirant les
trois bufferViews en une fois (offsets non adjacents : 4, 5, 7 — coupés en
ordre décroissant d'offset, chacun avec son padding d'alignement jusqu'au
bufferView suivant dans l'ordre ORIGINAL, la même règle que pour un seul
canal).

### La méthode — script généralisé, pas retapé à la main 4 fois

`strip_glb_textures.py` (scratch, non committé) généralise exactement la
méthode déjà écrite dans `CLAUDE.md` et appliquée au blaireau : découpe du
(des) bufferView(s) mort(s) avec padding d'alignement jusqu'au bufferView
suivant dans l'ordre des offsets ORIGINAUX (pas l'ordre du tableau JSON),
décalage de tous les offsets postérieurs, réindexation de
`accessors[].bufferView`, `images[].bufferView`, `textures[].source` et de
chaque référence de texture restante sur le matériau. Un garde refuse la
chirurgie si la texture visée est encore référencée ailleurs (aucun cas
rencontré ici : chaque asset a un seul matériau).

Vérifié pour les 4 avant d'écraser le fichier installé : `pygltflib`
charge chaque résultat sans erreur, `len(accessors)`/`len(meshes)`/
`len(skins)`/`len(animations)` identiques à l'avant (155/1/1/2 pour l'ours,
4/1/0/0 pour les trois autres), et le MD5 de chaque image restante dans le
nouveau `.glb` est byte-identique au MD5 de l'image correspondante dans
l'original.

Siblings extraits par l'import Godot : contrairement au blaireau (collision
de nom sur `"texture_0"` partagé), ces 4 assets nomment déjà chaque image
distinctement (`normal`, `Baked_BaseColor`, `Baked_Emit`,
`Baked_MetallicRoughness`) — pas de collision, donc pas de bascule de nom à
gérer : seuls les fichiers PNG/JPG + `.import` du canal retiré sont
supprimés, l'image restante réextrait sous son nom déjà stable, revérifiée
byte-identique à l'originale après réimport.

### PREUVE AU PIXEL — sonde jetable unique pour les 4, byte-identique aux 16 rendus

`scripts/dev/DeadChannelPixelProbe.{gd,tscn}` (supprimée avant ce commit,
règle sonde-jetable) : rend UN asset, aux 4 azimuts, à travers exactement
le chemin de code réel qui le dessine —

* **bear** : via `HubActorWalker` (même `BEAR_SCALE`, même
  `_force_unshaded`), exactement le protocole du blaireau ;
* **cabin/owl/hibou** : `.glb` chargé et instancié directement — ce
  qu'`ModelSlot._install_model()` et `CabinInterior._build_backdrop()`
  font tous deux, sans override matériau sur le corps (lu, pas supposé,
  voir ci-dessus).

Sous `xvfb-run --rendering-driver opengl3` (jamais `--headless` seul).
**Blind check d'abord**, sur les 4 : yaw 0° contre yaw 90° du même run
rendent des MD5 différents à chaque fois (couleurs moyennes mesurées
distinctes, ex. ours R 82,6 contre 62,5) — la sonde SAIT voir une
différence.

**Résultat, MD5 du PNG entier, avant/après, aux 4 azimuts** :

| asset | 0° | 90° | 180° | 270° |
|---|---|---|---|---|
| bear | `1c9cdf78...` id. | `37be3361...` id. | `37431f7d...` id. | `40dc2204...` id. |
| cabin | `11da66ee...` id. | `5620aa2f...` id. | `6d3bcea8...` id. | `d6dc4af6...` id. |
| owl | `5385f11f...` id. | `0552f5e8...` id. | `83261de6...` id. | `3931f5f7...` id. |
| hibou | `68ac6fa3...` id. | `ae943624...` id. | `8af46b08...` id. | `4effde02...` id. |

Byte-identique, pas seulement visuellement proche, sur les 16 rendus.

### PAYLOAD — mesuré aux deux bouts sur le `.pck` réel, TOC parsé directement

Export release Web complet, deux états comparés par `git stash`
(avant/après, `build/`+`.godot/` nettoyés entre les deux) :

| | `index.pck` | `index.wasm` | `index.js` |
|---|---|---|---|
| avant (4 canaux présents) | 49 361 200 | 35 376 909 | 331 495 |
| après (4 canaux retirés) | **30 350 032** | 35 376 909 (inchangé) | 331 495 (inchangé) |
| delta | **-19 011 168 octets (-18,13 Mio)** | 0 | 0 |

`index.wasm` (`af4a8fc2...`) et `index.js` (`4e08904b...`) byte-identiques
aux deux bouts, et identiques au md5 déjà publié dans `CLAUDE.md` — aucun
code moteur n'a bougé.

TOC du `.pck` parsé directement (format GDPC v2, comme pour le blaireau),
delta par asset, chaque ligne mesurée aux deux bouts plutôt qu'estimée :

| asset | canal(aux) retiré(s) | `.pck` avant | `.pck` après | delta |
|---|---|---|---|---|
| bear_walker | emissiveTexture | 8 928 313 | 4 596 955 | **-4 331 358** |
| cabin_decor | normalTexture | 15 426 496 | 6 807 217 | **-8 619 279** |
| hibou_pursuer | emissive+metallic+normal | 3 018 980 | 1 728 458 | **-1 290 522** |
| owl_decor | normalTexture | 8 880 513 | 4 112 492 | **-4 768 021** |
| **TOTAL (assets seuls)** | | | | **-19 009 180** |

Le delta total mesuré sur le `.pck` complet (-19 011 168) dépasse ce sous-total
de 1 988 octets — la réduction du nombre d'entrées de la table des matières
elle-même (286 → 274 fichiers, 12 de moins : 6 `.ctex` + 6 `.import`), au-delà
des seuls octets de contenu, explique l'écart, pas une erreur de mesure —
même forme que le +528 octets déjà documenté pour le blaireau.

### `assets_source/` — byte-identique pour les 4, revérifié

| asset source | MD5 |
|---|---|
| `assets_source/openworld/animated/keepy_bear_walker.glb` | `4632d433...` inchangé |
| `assets_source/openworld/decor/Meshy_AI_cabane keepy.glb` | `0ea8689a...` inchangé |
| `assets_source/openworld/perso/Meshy_AI_Ember_Eyed_Owlet_0828125359_texture.glb` | `3e606d9d...` inchangé |
| `assets_source/pursuer/owl_pursuer_decimated.glb` | `a450da3a...` inchangé |

### Sonde

`DeadChannelPixelProbe.{gd,tscn}` était une mesure ponctuelle (comparer
deux états de 4 assets, une fois chacun) et non un contrat permanent —
supprimée avant ce commit, per la règle sonde-jetable. Rien de nouveau
n'entre dans `scripts/dev/` pour ce lot.

## LOT — RATIO EXACT 1,6x, ET UN SECOND DÉFAUT DÉCOUVERT PAR LA MESURE, PAS PAR LE BRIEF (3 septembre 2026, même jour)

### Sujet 1 — la moyenne géométrique cède la place à un ratio EXACT

Le lot précédent (même jour) dérivait `BADGER_DRAWN_HEIGHT` par MOYENNE
GÉOMÉTRIQUE sur les trois acteurs (Keepy, blaireau, ours), pour un résultat
de 1,597431 (`BADGER_SCALE` 0,962085). Mathieu a demandé un chiffre plus
simple et plus direct : le blaireau vaut EXACTEMENT 1,6 fois la hauteur de
Keepy, pas une moyenne géométrique avec l'ours.

`KEEPY_DRAWN_HEIGHT` revérifiée inchangée sur `origin/staging` (`b00b516`
ancêtre confirmé par `git merge-base --is-ancestor`) : toujours 1,3501.

    BADGER_DRAWN_HEIGHT = 1,6 * KEEPY_DRAWN_HEIGHT = 1,6 * 1,3501 = 2,16016
    BADGER_SCALE        = BADGER_DRAWN_HEIGHT / BADGER_REST_SPAN
                        = 2,16016 / 1,660387 = 1,300998

`BADGER_REST_SPAN` (1,660387) n'a pas bougé — c'est une mesure du rig à
l'échelle 1, indépendante de tout choix de ratio. Écrit comme la formule
`1.6 * KEEPY_DRAWN_HEIGHT`, pas comme son résultat typé, même règle que la
moyenne géométrique qu'elle remplace.

### Sujet 2 — l'inversion de taille blaireau/ours, SIGNALÉE, NON CORRIGÉE (rappel du brief)

À 2,16016, le blaireau dépasse l'ours (`BEAR_DRAWN_HEIGHT` 1,890073,
+14,3 %) — l'ordre Keepy < blaireau < ours du lot précédent devient
Keepy < ours < blaireau. Mathieu en a été informé avant de demander le
ratio 1,6x et n'a pas demandé de correction sur `BEAR_SCALE` : la constante
est intouchée. L'inversion est réelle et visible en jeu, pas seulement dans
un commentaire — voir le rendu du Sujet 4.

L'assertion `ZiplineRideProbe` qui gate cet ordre («&nbsp;while staying
SHORTER than the bear&nbsp;») a été RETOURNÉE pour refléter le nouvel ordre
accepté (`scale_drawn > BEAR_DRAWN_HEIGHT` au lieu de `<`) plutôt que
laissée à tester une relation que Mathieu a explicitement annulée — la
retourner est fidèle à sa décision, la laisser telle quelle aurait gaté
tout lot futur contre un fait devenu faux. ROUGE AVANT VERT respecté :
l'ancienne assertion a été observée échouer réellement (`FAIL while
staying SHORTER than the bear (2.1602 < 1.8901)`) avant d'être retournée,
puis la nouvelle a été observée passer (`OK and now TALLER than the bear
too (2.1602 > 1.8901)`).

### Sujet 3 — clearance escalier tyrolienne : resserrée, PAS un conflit

`BADGER_SIDE_OFFSET` (0,95) inchangée. La largeur du blaireau grandit avec
son échelle uniforme ; l'étendue latérale du rig à l'échelle 1 se déduit du
couple (largeur, échelle) déjà publié au lot précédent (0,710 u à
0,962085) : 0,710 / 0,962085 = 0,738 u à l'échelle 1. À la nouvelle échelle
1,300998, largeur = 0,738 * 1,300998 = 0,960 u.

    marge = BADGER_SIDE_OFFSET - largeur/2 - ZIPLINE_STRINGER_HALF_SPAN
          = 0,95 - 0,960/2 - 0,42 = 0,95 - 0,480 - 0,42 = +0,050 u

Toujours positive — **pas un conflit réel** — mais un cinquième de la marge
précédente (+0,175 u). Signalé dans le commentaire de `BADGER_SIDE_OFFSET`
comme un point à surveiller si le blaireau grandit encore, mais laissé tel
quel : +0,050 u est une marge réelle, non nulle, et rien ne demandait de
retoucher l'offset.

### Sujet 4 — DÉCOUVERT PAR LA MESURE, PAS DEMANDÉ PAR LE BRIEF : le blaireau passe sous le sol pendant la traversée de la tyrolienne

`ZiplineRideProbe` relancée (`godot4 --headless --fixed-fps 60`, sonde pure
transform donc légitimement headless per sa propre doctrine d'en-tête) :
**2 échecs réels**, tous deux la même cause.

`_zip_seat()` aligne les DEUX passagers sous la MÊME barre (`crown_y` =
`cable_height - bar_drop - hang_clearance` = 2,0 - 0,24 - 0,05 = 1,71,
constant, indépendant de la hauteur du corps — propriété déjà établie et
blind-checkée au lot précédent). Les PIEDS, eux, descendent avec la
hauteur du corps : `feet_y = crown_y - height`. Tant que `height` restait
sous 1,71 (le cas de Keepy à 1,3501 et du blaireau à l'ancien 1,597431),
les pieds restaient positifs. À 2,16016, `height` DÉPASSE `crown_y` :

    feet_y = 1,71 - 2,16016 = -0,45016

Mesuré directement par la sonde : `FAIL the badger's feet are off the
ground (-0.4502)` et `FAIL both are genuinely off the ground (0.360 >
0.180 / -0.450 > -0.225)`. Ce n'est pas une marge resserrée comme le Sujet
3 — c'est un passage SOUS le niveau du sol (0,0) pendant tout le trajet de
la tyrolienne (4,0 s, `ZIPLINE_RIDE_S`), visible et non un artefact de
sonde : la même formule est celle qui place effectivement le blaireau à
l'exécution (`HubWorld._zip_seat`), pas une approximation de commentaire.

**Cause verrouillée dans la géométrie partagée** : `bar_drop` et
`hang_clearance` viennent du MÊME dictionnaire `_zipline` pour les deux
passagers — une seule barre physique. Le trajet de Keepy est déjà validé
device ; changer `bar_drop`/`hang_clearance`/`cable_height` pour le
blaireau déplacerait aussi Keepy. Une résolution correcte (pose de
suspension distincte pour le blaireau, barre plus haute, ou tout autre
choix) est une décision de conception que ce lot n'a pas reçu mandat de
prendre — le brief demandait explicitement de vérifier la clearance
ESCALIER, pas la géométrie de la tyrolienne elle-même, et ce défaut n'a été
découvert qu'en re-testant `ZiplineRideProbe` après coup.

**Conséquence sur le déploiement** : `ZiplineRideProbe` gate un contrat
permanent (sa propre doctrine d'en-tête, section « WHY GATED AND NOT
MERELY REPORTED »). CLAUDE.md définit le palier 1 (merge vers `staging`)
comme gaté par « build/export verts, SONDES GATÉES vertes » — un critère
purement technique. Avec 2 échecs réels et nouveaux sur une sonde gatée,
ce lot n'est PAS techniquement valide au sens de cette règle. **Le merge
automatique vers `staging` est donc retenu pour ce lot**, contrairement à
la routine habituelle — la branche est poussée, prête, mais pas mergée,
en attente d'une décision de Mathieu sur la géométrie de la tyrolienne
pour un blaireau plus grand que la barre ne le permet.

### Sujet 5 — preuve visuelle

Rendu offscreen (`xvfb-run --rendering-driver opengl3`, sonde jetable
supprimée avant ce commit, `HubCamera.snap_to_target()` utilisée plutôt
qu'un `look_at()` manuel — la caméra du hub garde une ROTATION FIXE et ne
fait que suivre la position sol de Keepy, un `look_at()` la désynchronise
et ne s'en remet jamais). Keepy et le blaireau posés côte à côte au point
de spawn : le blaireau (à droite) domine nettement Keepy et dépasse même
le hibou statique du plateau, entrés tous deux dans le même cadrage par
coïncidence de position. Sous `docs/renders/badger_1_6x_rescale/
keepy_badger_side_by_side.png`.

### Sonde

`ZiplineRideProbe` modifiée (assertion bear/badger retournée, Sujet 2) —
contrat permanent existant, pas une sonde neuve. Rien d'autre n'entre dans
`scripts/dev/` pour ce lot ; le spike de rendu (`BadgerRescale16xSpike.
{gd,tscn}`) a été supprimé avant ce commit, per la règle sonde-jetable.

## LOT — SUSPENSION PAR CORPS, ET UN INSTRUMENT CHANGÉ EN COURS DE LOT (4 septembre 2026)

> Suite directe du Sujet 4 du lot précédent, qui avait mesuré le défaut et
> l'avait explicitement laissé ouvert en attente d'une décision de Mathieu.
> Décision reçue : **donner au blaireau une pose de suspension DISTINCTE de
> celle de Keepy**, plutôt que de partager `bar_drop`/`hang_clearance`.
> Doctrine permanente : voir `CLAUDE.md`. Index : `docs/lots/INDEX.md`.

### Le point de départ, reproduit avant d'être touché

`ZiplineRideProbe` relancée sur la base (`27461ac`, branche
`claude/badger-rescale-1-6x-aq4vxk`, non mergée) : **88 OK, 2 FAIL**, les
deux lignes exactes que le lot précédent avait publiées —
`FAIL the badger's feet are off the ground (-0.4502)` et
`FAIL both are genuinely off the ground (0.360 > 0.180 / -0.450 > -0.225)`.
Rien re-diagnostiqué : le défaut était au dossier, il a été reproduit puis
corrigé.

### Pourquoi `bar_drop`/`hang_clearance` RESTENT partagés

La barre est **un objet physique unique**. Les deux constantes décrivent la
ligne de crown que le chariot tend aux deux passagers —
`cable_height - bar_drop - hang_clearance` = 1,71 — et le trajet de Keepy
est validé device dessus. Elles n'ont pas bougé d'un micro-unité et le
`_zip_seat` de Keepy est appelé **avec exactement le même argument
qu'avant** (`KEEPY_DRAWN_HEIGHT`), donc sa géométrie est strictement
inchangée : la sonde le remesure et lit toujours 0,3599 / 1,7100.

Ce qui devient **par corps**, c'est la POSE accrochée à cette ligne.

### Le défaut avait DEUX moitiés, et le brief n'en nommait qu'une

**Moitié 1 — la hauteur debout n'est pas l'étendue suspendue.**
`_badger_follow_zipline` passait `BADGER_DRAWN_HEIGHT` (2,160160, la
*rest span* du rig) comme offset de crown. Or le blaireau n'est pas debout
sur la tyrolienne : il est figé sur `Running` @ 0,351302 et incliné. Son
crown réel au-dessus de son nœud n'a jamais valu 2,16.

**Moitié 2 — le nœud n'est pas la semelle.** Keepy pend droit : son nœud
EST sous ses pieds, donc l'ancienne formule était juste *par accident* de
son côté. Le blaireau, incliné, a son point le plus bas **au-dessus** de
son nœud. Deux erreurs qui se composaient.

D'où trois constantes là où Keepy n'en demande aucune :

    BADGER_HANG_PITCH_DEG   40.0        (était 12.0)
    BADGER_HANG_CROWN        1.444291   crown au-dessus du nœud, pose de vol
    BADGER_HANG_SOLE         0.138760   os le plus bas au-dessus du nœud
    BADGER_HANG_DRAWN_SOLE  -0.019240   SURFACE la plus basse, sous le nœud

### ⚠️ LE LEAN EST LE SEUL LEVIER, ET C'EST DE L'ARITHMÉTIQUE

La barre pend à `ZIPLINE_CABLE_HEIGHT - ZIPLINE_TROLLEY_STEM` = **1,76 du
sol**. À 12°, l'étendue suspendue DESSINÉE du blaireau mesure **1,984**.
Un corps dont l'étendue suspendue dépasse la hauteur de la barre au-dessus
du sol **ne peut pas** avoir son crown sous cette barre et ses pieds en
l'air : aucune valeur de `hang_clearance` ne referme ça, parce que le
déficit est entre le corps et **le SOL**, pas entre le corps et la barre.

Le lean est la seule variable qui raccourcit l'étendue VERTICALE d'un corps
sans déplacer la barre de Keepy. **Et il est libre ici, ce qui a été mesuré
et non supposé** : la mi-main de la pose est déjà à **0,932 u de la barre à
12°**, donc ce rig n'a jamais tenu la poignée et un lean plus fort ne casse
aucun contrat main-sur-barre. (Cet écart est réel et pré-existant ; il est
signalé ici et délibérément non poursuivi — ce n'était pas le sujet.)

**Le lean NÉGATIF a été mesuré aussi, et il est pire** : le nez en l'air
fait descendre les pieds (ils sont en avant du pivot dans la pose de
course). Semelle dessinée à -25° : **-0,588** ; à -55° : **-0,308**. Aucun
angle négatif ne sort du sol. Le sens positif n'est donc pas un choix.

### ⚠️ L'INSTRUMENT A CHANGÉ EN COURS DE LOT, ET ÇA A DÉPLACÉ LA RÉPONSE DE 10°

Premier balayage, lu sur les **OS** (`get_bone_global_pose`, l'instrument
qui a servi à `BADGER_REST_SPAN`) : 30° ressortait comme le lean le plus
faible avec une marge réelle, **+0,184**.

Second balayage, lu sur les **VERTICES SKINNÉS** — la silhouette qu'un
joueur voit : le MÊME 30° laisse **+0,019**, deux centimètres. Parce que la
semelle DESSINÉE de ce rig pend **0,158 u sous son os le plus bas** dans
cette pose. C'est le piège de la mauvaise métrique que ce dépôt documente,
commis et rattrapé à l'intérieur d'un seul lot.

Le balayage qui a tranché, sur pixels, nœud placé pour que le crown-os
tombe sur le 1,71 partagé :

| lean | semelle dessinée | crown dessiné | dégagement à la barre |
|---|---|---|---|
| 12° | **-0,258** (sous le sol) | 1,726 | — |
| 30° | +0,019 | 1,774 | — |
| 35° | +0,128 | 1,795 | — |
| **40°** | **+0,246** | **1,817** | **0,358** |
| 45° | +0,376 | 1,838 | — |

**40° est le lean le plus faible dont les semelles DESSINÉES dégagent le
sol d'une marge du même ordre que les 0,360 de Keepy**, dont le crown
dessiné reste sous le câble à 2,0, et dont le vertex le plus proche dégage
encore la poignée de 0,358 u — rien du blaireau ne traverse la barre qu'il
tient. Il pend encore **16 % plus long que Keepy** (1,571 dessiné contre
1,350), donc le rescale 1,6x lit toujours sur le seul écran où les deux
sont en l'air côte à côte.

Le banc s'est prouvé avant de publier : il a remesuré la rest span à
**2,160081** contre les **2,160160** au dossier — 79 micro-unités d'écart —
avant de sortir un seul chiffre neuf. 10 047 vertices skinnés à la main
(`Skin.get_bind_pose()` composé avec la pose globale de chaque os), portés
en monde et ramenés dans le repère de l'ACTEUR **une seule fois**.

### Le résultat, en monde

| passager | offset de crown | y du nœud | semelle dessinée | semelle en monde |
|---|---|---|---|---|
| Keepy | 1,350100 | 0,359900 | 0,000000 | **0,359900** |
| blaireau | 1,444291 | 0,265709 | -0,019240 | **0,246469** |

Les deux crowns toujours sur **1,71**, les deux semelles en l'air, les deux
sous le pont à 0,90 : l'embarquement du blaireau est simplement une chute
plus longue, pas une chute cassée.

### Les deux riders toujours écrits dans le MÊME appel

Vérifié, non supposé : `_apply_zip()` écrit le chariot, puis
`_keepy.follow_zipline()`, puis `_badger_follow_zipline()`, dans le même
appel de `tween_method`. Rien n'a été ajouté sur un `_process` ni sur un
signal. La sonde le gate toujours et lit **0,000000 u** de retard pour les
deux — le patron de la balançoire (12° d'erreur au pic pour un rider en
retard d'une frame) est intact.

### ⚠️ ROUGE AVANT VERT — TROIS passes, chacune sur une moitié différente

| neutralisation | rouges | ce qu'elle prouve |
|---|---|---|
| **A** — site d'appel remis à `BADGER_DRAWN_HEIGHT` | **7 FAIL** | la sonde voit un mauvais argument au site d'appel : semelle vive à **-0,469**, et les trois constantes ne matchent plus le rig |
| **B** — constantes de pose remises au modèle pré-fix (crown = hauteur debout, semelles = 0) | **9 FAIL** | reproduit **verbatim les deux lignes d'origine** (`-0.4502` et `0.360 > 0.180 / -0.450 > -0.225`) : la nouvelle suite SUBSUME l'ancienne et ajoute sept lignes |
| **C** — lean seul remis à 12° | **5 FAIL** | le lean est porteur, pas décoratif : le crown dessiné monte à **2,315**, à travers le câble |

Restauration **byte-identique** (`cmp`) après chacune, et vert de contrôle
relancé après les trois : sortie ligne-à-ligne identique au vert précédent.

### BLIND CHECKS — deux ajoutés, parce que la nouvelle assertion passait GRATUITEMENT

« Les pieds du blaireau sont en l'air » est satisfait **pour rien** par une
sonde qui oublie l'offset de semelle : avec la semelle lue à 0, le NŒUD du
blaireau est à +0,0071, positif, vert, pendant que le rig dessiné est
ailleurs. Deux gardes permanentes ajoutées :

* la sonde rejoue **l'état livré-et-cassé** (`BADGER_DRAWN_HEIGHT` passé
  comme offset de crown) et exige que la même mesure sorte **négative**
  (-0,4694) — elle prouve qu'elle sait voir un corps enterré ;
* elle exige que la semelle DESSINÉE et la semelle-os **soient différentes**
  (0,1580 u d'écart), sans quoi la troisième constante serait décorative et
  le lot suivant regaterait la mauvaise.

Plus une garde d'échantillonnage : le compte de frames réellement lues (90)
et le compte de vertices réellement skinnés (10 047) sont eux-mêmes assertés,
parce qu'un rig jamais lu ferait passer tout le bloc pour rien.

### Ce que la sonde mesure maintenant sur le RIG VIVANT

Les os sur **chaque** frame échantillonnée du trajet (90) — ce qu'une sonde
gatée peut s'offrir 90 fois — et la **silhouette skinnée une fois en plein
vol**, qui est la lecture sur laquelle le dégagement au sol est jugé. Les
trois constantes typées sont recomparées au rig à chaque run :

    BADGER_HANG_DRAWN_SOLE  -0.019240 mesuré vs -0.019240 typé
    BADGER_HANG_SOLE         0.138760 mesuré vs  0.138760 typé
    BADGER_HANG_CROWN        1.444291 mesuré vs  1.444291 typé

`ZiplineRideProbe` : **99 OK, 0 FAIL** (était 88 OK / 2 FAIL).
`ZiplineStructureProbe` (sœur, sous `opengl3` per son propre en-tête) :
**82 OK, 0 FAIL**. `ProbeTimeoutAudit` : **64 scènes de sonde**, revenu à
sa baseline après suppression des bancs jetables.

### PREUVE PAR RENDU — cinq instants, deux caméras

`docs/renders/badger_suspension/`, sous `xvfb-run --rendering-driver
opengl3` (le rect du conteneur est **asserté** non dégénéré, 1080x1920, et
la sonde échoue bruyamment sinon). Cinq instants du trajet — t = 0, 40, 80,
120, 155 frames — donc **pas seulement départ et arrivée**. Semelle
dessinée mesurée **+0,246469 aux cinq**, le câble étant de niveau.

Deux caméras par instant, délibérément :

* `player_t*.png` — la **HubCamera livrée**, ce qu'un joueur voit
  réellement : les deux corps glissent le long du fil, nettement en l'air
  au-dessus du plateau, le blaireau visiblement le plus gros des deux ;
* `elevation_t*.png` — une **élévation latérale** perpendiculaire au câble,
  où la ligne de sol est sans ambiguïté. Une vue trois-quarts ne peut pas
  trancher « ce pied est-il au-dessus du sol ou devant lui », qui est
  exactement la question.

⚠️ **Et les deux vues ne disent PAS la même chose sur la POSE.** En
élévation, le lean à 40° lit comme un blaireau qui pique du nez. Dans le
cadrage livré — caméra très plongeante, rotation fixe — il lit comme un
corps aligné sur le fil, et pas du tout comme une chute. **C'est le cadrage
livré qui décide**, l'élévation n'est qu'un instrument de mesure. Signalé
parce qu'un futur lot qui regarderait l'élévation seule conclurait à un
défaut qui n'existe pas à l'écran.

### ⚠️ CLEARANCE ESCALIER — REMESURÉE, ET LA VALEUR PUBLIÉE EST FAUSSE : IL Y A INTERSECTION

Le brief demandait de remesurer les **+0,050 u** publiés au lot précédent
et de signaler si ça avait bougé. Ça n'a pas bougé : **ça n'a jamais été
juste**.

Les +0,050 venaient d'une DÉRIVATION de largeur (0,710 u à l'échelle
0,962085 → 0,738 à l'échelle 1 → 0,960 à 1,300998), c'est-à-dire d'un
nombre **recopié d'un lot antérieur** — précisément ce dont `CLAUDE.md`
dit qu'il mérite plus de défiance qu'un nombre mesuré sur place.

Mesuré cette fois sur la **silhouette skinnée dans le hub livré** (10 047
vertices) contre la **géométrie DESSINÉE de l'escalier** :

    ZiplineStringer#1   distance 0.0000 u   <- INTERSECTION
    ZiplineStep#0       distance 0.1198 u
    ZiplineStep#1       distance 0.2052 u
    Bush#62             distance 0.1721 u

Le corps du blaireau **traverse le limon proche**. Contre l'axe de
l'escalier : flanc proche à **0,142555** du centre, rail à 0,42, soit
**-0,277 u** au lieu des +0,050 annoncés.

⚠️ **ET CETTE MESURE EXIGE `opengl3`.** Sous `--headless`, les transforms
de `MultiMesh` rendent l'identité — les quatre `ZiplineStringer` lisaient
tous à l'origine du monde et sortaient du filtre de proximité, donnant un
premier rapport « dégagement confortable » contre **rien du tout**. Le
piège est au dossier depuis longtemps ; il s'est encore payé ici.

**NON CORRIGÉ, ET DÉLIBÉRÉMENT.** Le remède tient en une constante —
`BADGER_SIDE_OFFSET` 0,95 → **~1,32** met le flanc proche à 0,46 + 0,05 de
marge hors de la face externe du rail — mais il **déplace le blaireau sur
le plateau** : c'est un choix de placement visible, il touche le disque de
tap, le point de repos des deux extrémités et la région marchable, et rien
dans ce brief ne le demandait. Le sujet de ce lot est la SUSPENSION, pas la
station debout. Chiffré, signalé, laissé à Mathieu.

### Sondes

`ZiplineRideProbe` modifiée (contrat permanent existant). Trois bancs
jetables écrits et **supprimés avant ce commit** per la règle
sonde-jetable : `BadgerHangBench`, `ZiplineRideRenderSpike`,
`StairClearanceBench`. `ProbeTimeoutAudit` revenu à sa baseline, vérifié
des deux côtés (66 scènes bancs présents → 64 après suppression).

### Ce que ce lot NE peut PAS trancher

Si un blaireau incliné à 40° sur un fil **lit** comme un passager de
tyrolienne sur un écran de six pouces. Aucune sonde de ce dépôt ne score
ça, et l'élévation et le cadrage livré donnent deux lectures différentes.
C'est le gate device, et c'est celui qui reste.

## LOT — la station debout du blaireau dégagée de l'escalier (4 septembre 2026)

Suite directe du lot précédent, qui avait mesuré l'intersection et l'avait
**laissée** parce que la corriger déplace un corps sur le plateau. Mathieu a
tranché : corriger. Ce lot ne re-diagnostique donc pas, il dérive la valeur
par mesure et remonte ce que la mesure trouve en chemin — ce qui inclut le
fait que **la valeur indicative du rapport précédent est mauvaise**.

### ⚠️ ~1,32 EST UN PIRE ENDROIT QUE 0,95, ET LE BANC L'A DIT AVANT QU'ON L'ÉCRIVE

Le rapport précédent proposait `BADGER_SIDE_OFFSET` 0,95 → **~1,32** « à
affiner ». Le brief demandait explicitement de ne pas le recopier sans
vérifier qu'il dégage vraiment le limon. Il ne le dégage pas : il met le
blaireau **dans un buisson**.

`~1,32` était dérivé du RAIL SEUL — 0,46 de face externe plus 0,05 de marge.
Le rail n'est pas la seule chose autour du pied de l'escalier. La fenêtre
libre à l'extrémité 0 est bornée **des deux côtés** : le limon recule quand
l'offset grandit, et le buisson du layout centré en **(29,869 ; 7,138)**
avance à sa rencontre. Balayé au pas 0,005 sur la géométrie DESSINÉE :

| offset | partie la plus proche | dégagement |
|---|---|---|
| 0,950 | `ZiplineStringer#1` | **0,0428** (livré avant ce lot) |
| 1,000 | `ZiplineStringer#1` | 0,0888 |
| **1,100** | `ZiplineStringer#1` | **0,1886** ← livré |
| 1,200 | `Bush#62` | 0,0923 |
| 1,320 | `Bush#62` | **0,0014** ← la valeur indicative |
| 1,350 | `Bush#62` | 0,0000 (intersection) |
| 2,050 | `Bush#62` | 0,0000 |

**Donc l'offset se choisit par ARGMAX, pas par « plus loin de l'escalier ».**
À 1,100 les deux contraintes s'équilibrent presque — limon 0,1886, buisson
0,1916 — ce qui est la signature d'un vrai maximum de fenêtre et non d'une
valeur choisie puis justifiée. Le croisement exact tombe vers 1,1015 ; le
gain sur 1,100 vaut 1,5 mm, sous ce qui compte.

**Les deux extrémités lisent 0,1886 u**, et pas par chance : les deux tours
portent le même escalier, et l'extrémité 1 n'a **aucun buisson** — sa courbe
continue de monter au-delà (0,2911 à 1,20, 0,4985 à 1,40). C'est donc
l'extrémité 0 seule qui plafonne la constante partagée.

**0,1886 u est 4,4× la marge remplacée, et c'est le MAXIMUM que cette
constante peut acheter.** Aller au-delà exige de déplacer ce buisson —
une édition de décor que ce lot n'a pas demandée et n'a pas faite.

### ⚠️ LA MESURE FILÉE À 0,0000 SE REPRODUIT À 0,0428, ET L'ÉCART EST RAPPORTÉ PLUTÔT QUE LISSÉ

Le banc reproduit `ZiplineStep#0` à **0,1260** contre les **0,1198** au
dossier — accord à 6 mm, ce qui lui donne qualité à publier un chiffre neuf
per la règle « reproduire d'abord un chiffre déjà au dossier ». Mais il
reproduit `ZiplineStringer#1` à **0,0428** et non à 0,0000 : **frôlement
extrême, pas intersection stricte** sur la frame mesurée. La conclusion du
lot précédent tient entièrement (une marge de 4 cm sous un corps de 2,2 u de
haut n'est pas une marge), mais le nombre exact diffère et il est écrit ici
tel que mesuré plutôt qu'aligné sur le rapport antérieur.

⚠️ **Et un second canal de mesure a été essayé puis JETÉ, ce qui vaut
d'être nommé parce qu'il avait l'air plus rigoureux que le premier** : les
8 coins de chaque boîte testés contre l'AABB propre du blaireau, pour
attraper une arête qui traverse entre deux vertices. Il a rapporté
**0,0000 pour TOUTES les parties à TOUS les offsets jusqu'à 2,05** — l'AABB
d'un corps animé est surtout de l'air, donc un coin dedans ne prouve rien
d'un coin dans le corps. Ce qui l'a démasqué : il était **incapable de
reproduire le 0,1198 filé**. Le canal gardé est vertex-contre-boîte, celui
sur lequel les nombres au dossier ont été pris.

### LA POSE NE RESPIRE PAS — vérifié avant de croire une lecture d'une frame

Une clearance lue sur une frame est une loterie si l'idle bouge. Mesuré sur
**40 frames consécutives** : 0,0428 .. 0,0428, **écart 0,0000 u**. Le rig au
repos est statique, la lecture d'une frame est donc légitime. Vérifié plutôt
que supposé, parce que l'échec aurait été silencieux et vert.

### RÉPERCUSSIONS — les trois qu'on demandait, plus une quatrième trouvée

**1. `BADGER_SIDE_OFFSET` est ISOLÉ à la tyrolienne.** Un seul site de
lecture dans tout le dépôt (`HubWorld._badger_rest`), lui-même appelé au
spawn (extrémité 0), pour l'orientation, et à l'arrivée d'un trajet. Aucun
point de repos hors tyrolienne ne le partage. Vérifié par recherche, pas
supposé.

**2. Le disque de tap suit le corps — mais le CLAMP ne suit pas, et c'était
déjà cassé.** `ZiplineDoor.rider_position()` lit l'acteur vivant, donc le
disque se recentre tout seul. Le trou est ailleurs, et il est silencieux :
le disque est interrogé sur `aim` **non clampé** (règle anti-entonnoir),
mais ce que `HubTapInput` **émet** est la destination **clampée**, que
`_try_zip` re-teste contre le même rayon. Un tap accepté peut donc envoyer
Keepy sur un point clampé **hors de portée d'embarquement** : oui du disque,
pas d'embarquement, aucune erreur. Mesuré sur tout l'intervalle d'offsets,
rayon 1,80 :

| offset | extrémité 0 pire / perdu | extrémité 1 pire / perdu |
|---|---|---|
| 0,95 | 1,8000 / ~0 % | **2,4020 / 3,56 %** |
| 1,10 | 1,8000 / ~0 % | **2,3925 / 3,88 %** |
| 1,32 | 1,8000 / ~0 % | 2,3785 / 4,75 % |

⚠️ **LE DÉFAUT EST PRÉEXISTANT ET QUASI PLAT EN OFFSET.** L'extrémité 1 se
tient 1,68 u au-delà du bord du plateau, sur un lobe de structure de rayon
3,0 : une part de son disque surplombe du sol que le clamp doit rapatrier.
Ça ne vient pas de ce lot, et le déplacement **améliore** le pire cas
(2,4020 → 2,3925). L'extrémité 0 est saine (son « perdu » est du bruit
flottant exactement au rayon). Le réparer demande d'élargir le lobe P2 ou
de rétrécir le disque — un changement de région que personne n'a demandé
ici. **Rapporté, et ce qui est GATÉ est la non-régression**, pas une valeur
absolue que ce lot n'a pas cassée.

**3. La région marchable reste confortable aux deux bouts.** `contains()`
vrai, `clamp_to()` ne déplace rien, marge au bord mesurée par recherche
radiale sur 72 azimuts : **≈ 6,0 u** à l'extrémité 0 et **≈ 0,95 u** à
l'extrémité 1 (contre 6,19 et 1,06 à 0,95 — le blaireau se rapproche du
bord de 0,15 u, ce qui est le déplacement lui-même et rien de plus).

**4. Trouvée en chemin : le lot précédent croyait le buisson à 0,1721 u.**
Le banc le lit à **0,3221 u** à l'offset 0,95. La divergence est du même
ordre que celle sur le limon et de la même origine — deux passes, deux
définitions du corps mesuré.

### Sondes

`ZiplineStructureProbe` gagne une **PHASE I** (contrat permanent, sous
`opengl3` per son propre en-tête, qui est exactement pourquoi elle et non
`ZiplineRideProbe` : les limons et les marches sont batchés) :

* la silhouette **skinnée** du blaireau (10 047 vertices, posée par le rig
  vivant) contre chaque partie **dessinée** à moins de 8 u, aux **deux**
  extrémités, gate **0,15 u** — 21 % de coussin sous le 0,1886 tel que
  construit, et un facteur 4,4 au-dessus du 0,95 rejeté ;
* la **non-régression** du disque de tap face au clamp de région, la
  référence à 0,95 étant **recalculée en direct** plutôt que recopiée ;
* trois **blind checks** : une silhouette non lue rendrait toute distance
  infinie ; un corps grossi de 0,20 u au-delà de la marge doit faire
  rapporter une intersection ; le même test de disque planté au-dessus du
  vide doit rapporter 56,569 u.

**ROUGE AVANT VERT, sur la version définitive de la phase.** Constante
remise à 0,95 : **exactement UNE** assertion échoue, celle attendue
(`0,0428 u, gate 0,15`), les blind checks restant verts — le nombre d'échecs
attendus faisait partie de l'assertion. Fichier restauré et vérifié
**byte-identique** au `cmp`.

Totaux : `ZiplineStructureProbe` **91 OK / 0 FAIL** (82 en baseline
reproduite + 9 neuves), `ZiplineRideProbe` **99 OK / 0 FAIL** inchangée,
`ProbeTimeoutAudit` **64 scènes**, revenu à sa baseline après suppression
des trois bancs jetables (`BadgerOffsetBench`, `DiscReachBench`,
`BadgerOffsetRenderBench`).

### Preuve par rendu

`docs/renders/badger_offset/`, sous `xvfb-run --rendering-driver opengl3`,
le rect du conteneur **asserté** non dégénéré (1080x1920) et chaque capture
gatée sur sa fraction de pixels non-fond — un rendu du driver dummy est une
valeur plate et sortirait à 0.

Huit images : les **deux extrémités** × les **deux offsets**, donc un
avant/après et pas seulement un après, × **deux caméras**. La HubCamera
livrée (`player_*.png`) montre ce qu'un joueur voit — le blaireau debout
près de l'escalier, Keepy à côté, la tour et le câble derrière. La vue en
plan orthographique (`plan_*.png`) est un **instrument** et non une image du
jeu : elle seule tranche « à côté du rail » contre « par-dessus le rail »,
et c'est elle qui montre à 0,95 la patte avant du blaireau **posée sur le
limon**, et à 1,100 la même patte **à côté**.

### Ce que ce lot ne tranche pas

Si 0,1886 u de dégagement **lit** comme un blaireau debout à côté de son
escalier sur un écran de six pouces, ou si le corps déplacé de 0,15 u vers
l'extérieur change quelque chose au cadrage. Aucune sonde ne score ça.
C'est le gate device, et il reste.

## LOT — TIER 3 : LE TRAJET SOLO, ET LE CHANGEMENT DE DOCTRINE SUR L'ESCALIER (4 septembre 2026)

> **Ce lot part de `staging` (464a08c inclus). Changement de doctrine
> ASSUMÉ, pas une incohérence : voir ci-dessous.**

### Le changement de doctrine, en un mot

RECON 1, en tête de ce fichier, a réglé une question précise et l'a réglée
correctement : le patron ÉCHELLE interdit est **un mécanisme de routage de
tap** — un canal émis inconditionnellement et jeté par son écouteur — et
non « un escalier ne peut jamais porter de hotspot ». Le PALIER 2 a ensuite
lu cette conclusion plus large qu'elle ne l'était : « le seul objet
tapable à une tour est le blaireau ». C'était une description de la forme
du palier 2, pas une règle permanente.

Mathieu a demandé explicitement, pour ce lot, un second hotspot **sur la
STRUCTURE elle-même** (tour/escalier), aux deux extrémités, pour un trajet
**solo** dans le sens opposé à l'accompagné. Ce n'est **pas** une reprise du
patron ÉCHELLE : le nouveau canal (`tapped_zipline_solo`,
`ZiplineDoor.accepts_structure_tap`) se retire exactement sur les termes du
bateau — `_riding` partagé, faux pour tout le trajet, aux deux bouts, dans
les deux sens — donc un tap pendant un trajet retombe sur `tapped_ground`
au lieu d'être avalé. Le patron ÉCHELLE nommait un canal **sans** ce
retrait ; en avoir un ici est exactement ce qui en fait un second bateau et
non une échelle. `ZiplineDoor.gd` porte la note de doctrine complète dans
son en-tête, et `ZiplineStructureProbe.gd` PHASE F a été réécrite dans le
même sens plutôt que supprimée : ce qui reste interdit est un canal **sans
retrait**, pas la présence d'un canal sur l'escalier.

**CLAUDE.md vérifié** : la règle « aucun hotspot sur l'escalier » n'y a
jamais été promue en doctrine générale — elle n'existe que dans ce fichier
de chantier (RECON 1, PALIER 2, `ZiplineDoor.gd`, `HubTapInput.gd`). Aucune
correction n'est donc nécessaire dans `CLAUDE.md`.

### Le nouveau design

1. **Trajet accompagné** (inchangé dans son déclenchement) : un tap sur le
   blaireau, toujours au sud au repos, walk + boarding + trajet vers
   l'autre bout.
2. **⚠️ NOUVEAU COMPORTEMENT DE RETOUR — le blaireau ne s'arrête plus jamais
   au nord.** Dès que le trajet accompagné arrive à l'extrémité qui n'est
   pas `BADGER_HOME_END` (0, le sud), `HubWorld._on_zip_trip_finished`
   **enchaîne automatiquement** une seconde étape, blaireau seul, retour
   vers le sud — sans que la porte ne se rouvre entre les deux : `_riding`
   reste vrai du premier embarquement jusqu'à ce que cette seconde étape
   se termine. Keepy, lui, descend normalement à la fin de la PREMIÈRE
   étape (son `leave_zipline` ne dépend pas de ce que fait le blaireau
   ensuite).
3. **Trajet solo (nouveau)** : un tap sur la structure d'une tour — le
   point publié par `ZiplineDoor.structure_point(index)`, le centre de la
   tour tel que construit, PAS le point où se tient le blaireau — envoie
   Keepy **seul** vers l'autre bout. Disponible aux **deux** extrémités dès
   que le câble est libre ; au nord c'est le SEUL moyen de déclencher un
   trajet, puisque le blaireau n'y stationne plus jamais.

### Pourquoi les deux disques ne peuvent PAS être géométriquement disjoints

Mesuré, pas supposé, avant de choisir un rayon : le point où le blaireau
attend est à **2,0165 u** du centre de la tour
(`sqrt((ZIPLINE_DECK_HALF+run)² + BADGER_SIDE_OFFSET²)`, avec
`run = ZIPLINE_STEP_DEPTH × ZIPLINE_STEP_COUNT = 1,04`). Le disque du
blaireau (`BOARD_TAP_RADIUS = 1,8`, un chiffre déjà posé et validé device,
pas retouché ici) laisse donc au maximum **0,2165 u** de rayon disponible
pour un disque structure qui l'éviterait par la seule distance — une cible
de moins de 22 cm, invisible à l'échelle de ce plateau.

**Choix retenu : l'exclusion se fait en CODE, pas par la géométrie.**
`ZiplineDoor.accepts_structure_tap(point)` teste chaque tour (rayon
`STRUCTURE_TAP_RADIUS = 2,0`, choisi pour couvrir
`ZiplineStructureProbe.STRUCTURE_RADIUS_BUDGET` 1,932 avec une marge) et,
**seulement à l'extrémité où un blaireau attend**, exclut tout point que le
canal blaireau accepterait déjà. Résultat pour le joueur : taper
directement sur le blaireau embarque avec lui ; taper ailleurs sur la tour
ou l'escalier embarque seul. À l'extrémité nord, sans blaireau, tout le
disque est la cible solo.

⚠️ **Piège rencontré en écrivant la sonde de cette exclusion** : le point
même où se tient le blaireau (2,0165 u du centre) est déjà **hors** du
rayon structure (2,0) — donc un premier jet de `PHASE F2` qui testait
l'exclusion sur ce point précis restait vert **même après avoir supprimé la
ligne d'exclusion**, parce que le filtre de rayon suffisait seul à refuser
ce point. Un point choisi **dans la lentille de recouvrement réelle**
(mesuré à 1,0 u du blaireau vers la tour : 1,0165 u de la tour, 1,0 u du
blaireau, dans les deux disques) a été nécessaire pour que la sonde puisse
réellement échouer quand l'exclusion est retirée — encore un cas du blind
check qui n'était pas optionnel.

### La carte doit être re-parquée avant chaque embarquement, pas supposée en place

Le blaireau n'embarque jamais que depuis l'extrémité où il attend, donc
`_try_zip_badger` pouvait jusqu'ici supposer la nacelle déjà à la bonne
ancre. Un trajet solo casse cette hypothèse : Keepy peut taper la structure
nord alors que la nacelle a été laissée au sud par un trajet précédent (ou
l'inverse). `HubWorld._park_carrier_at(end_index)` — nouvelle fonction
partagée — replace explicitement la nacelle sur l'ancre demandée **avant**
`board_zipline`, dans les deux `_try_zip_*`, plutôt que de faire confiance à
sa dernière position : `board_zipline` lit la position de la nacelle **au
moment de l'appel** pour viser l'arc d'embarquement, donc une nacelle mal
placée aurait fait arquer Keepy vers du vide.

### Sondes

`ZiplineDoor.gd` gagne `accepts_structure_tap`, `structure_point`, et le
const `STRUCTURE_TAP_RADIUS`. `HubTapInput.gd` renomme
`tapped_zipline` → `tapped_zipline_badger` et ajoute `tapped_zipline_solo`,
tous deux retirés sur les mêmes termes du bateau. `HubWorld.gd` renomme
`_on_tapped_zipline`/`_try_zip` → `_on_tapped_zipline_badger`/
`_try_zip_badger`, ajoute `_on_tapped_zipline_solo`/`_try_zip_solo`, un
flag jumeau `_zipping_solo`, `BADGER_HOME_END`, `_park_carrier_at`, et la
logique de chaînage du retour automatique dans `_on_zip_trip_finished`.
`_apply_zip` lit désormais `_zip_trip["keepy"]`/`["badger"]` plutôt que de
supposer les deux corps toujours présents.

**`ZiplineRideProbe.gd`** (headless, sans lecture de pixels ni de
MultiMesh) : `PHASE SOLO SOUTH` (nouvelle, sud → nord solo, blaireau
inchangé pendant tout le trajet, échantillonné à chaque frame), `PHASE
TRIP` étendue (exclusion des quatre hotspots pendant le trajet accompagné),
`PHASE ARRIVAL` étendue (le retour automatique du blaireau observé pendant
qu'il tourne — porte fermée aux quatre canaux, `_zip_trip` badger-only
1 → 0 — puis attente de la réouverture réelle avant de vérifier le
blaireau au repos au sud), `PHASE RETURN` repensée en trajet solo nord →
sud (le seul moyen de revenir puisque le blaireau ne stationne plus au
nord). Total : **126 OK / 0 FAIL**.

**`ZiplineStructureProbe.gd`** : PHASE F réécrite (le canal structure existe
et se retire ; seul un canal SANS retrait reste interdit) et **PHASE F2**
nouvelle (l'exclusion des deux disques, blind check inclus). Total :
**102 OK / 0 FAIL**.

**ROUGE AVANT VERT, sur les deux mécanismes neufs.** Chaînage du retour
désactivé (`if false and had_badger …`) : **5 échecs**, tous dans les
assertions qui existent pour ça (porte fermée pendant le retour, trajet
badger-only, blaireau jamais revenu). Ligne d'exclusion retirée de
`accepts_structure_tap` : **exactement 1 échec**, celui de la lentille de
recouvrement. Les deux fichiers restaurés et vérifiés **byte-identiques**
au `cmp`.

### Build

`godot4 4.3.stable` téléchargé dans ce bac à sable pour ce lot (absent par
défaut ici, contrairement au poste habituel documenté ailleurs dans ce
fichier) — taille vérifiée contre le `Content-Length` (50 276 070 octets,
`.zip` éditeur) et contre le `.tpz` des templates d'export
(1 073 228 327 octets), les deux déjà publiés dans `CLAUDE.md`. Import
complet, export Web relancé de bout en bout : `index.wasm`
**35 376 909 octets**, md5 `af4a8fc2925d992348eb30deeeb54360` ; `index.js`
md5 `4e08904b1b7107858246af44b602067b` — les deux identiques aux empreintes
déjà publiées pour un lot qui ne touche pas le code moteur.

## LOT BADGER_ENDPOINT_POSITION — le retour automatique du blaireau est RETIRÉ, sur demande explicite après test device (4 septembre 2026)

### ⚠️ RENVERSEMENT DE DÉCISION ASSUMÉ — pas une incohérence, un revirement normal

Le lot précédent (« solo zipline ride on the structure + badger's automatic
return home », commit `2b3c3b9`, mergé en `7938317`) implémentait
**explicitement**, sur demande de Mathieu au tour d'avant : « le blaireau
revient toujours au sud après un trajet accompagné ». `BADGER_HOME_END`
(constante à 0, le sud), le chaînage dans `_on_zip_trip_finished` et
`_park_carrier_at` en étaient la mécanique.

Mathieu a testé ce comportement sur device et a tranché l'inverse : **le
blaireau ne doit plus revenir automatiquement**. Ce lot traite ça comme un
revirement de design ordinaire — la même chose qui a déjà eu lieu pour la
taille du blaireau (voir `CH20_OURS.md` / `ZiplineRideProbe.gd` PHASE
REGISTRY, deux rescales le même jour) — et non comme une erreur à
documenter comme telle. Rien dans le lot précédent n'était un bug : la
mécanique de retour automatique fonctionnait exactement comme spécifiée.
C'est la spécification elle-même que Mathieu a changée après l'avoir vue
tourner en vrai.

### Le nouveau comportement

Le blaireau n'a plus de position « domicile ». Après un trajet accompagné,
il reste physiquement — monté, visible, à l'arrêt — à l'extrémité
**d'arrivée**, jusqu'au prochain trajet accompagné, qui part nécessairement
de **cette** extrémité (puisque c'est la seule où le blaireau se trouve).

### Ce qui a dû changer, et ce qui n'en avait pas besoin

**Retiré de `HubWorld.gd`** : la constante `BADGER_HOME_END`, et tout le
bloc dans `_on_zip_trip_finished` qui, à l'arrivée d'un trajet accompagné à
une extrémité autre que `BADGER_HOME_END`, réécrivait `_zip_trip` avec
`{"from": arrived, "to": BADGER_HOME_END, "keepy": false, "badger": true}`
et enchaînait un second `Tween` sans rouvrir la porte entre les deux
étapes. Le corps de `_on_zip_trip_finished` se réduit maintenant à :
poser le blaireau (s'il était du trajet) à l'extrémité `arrived`, puis
rouvrir la porte — `_zipline_door.set_riding(false, arrived if had_badger
else badger_at)` — sur cette même extrémité, sans aucune deuxième étape.

**`badger_at`, la correction que la suppression naïve du chaînage aurait
manquée** : `_zipline_door.set_riding(false, BADGER_HOME_END)` était
correct pour TOUT trajet, accompagné ou solo, précisément parce que
`BADGER_HOME_END` était une constante — un trajet solo qui n'avait jamais
touché le blaireau pouvait quand même rouvrir la porte sur sa position
connue. Une fois la constante retirée, remplacer naïvement par
`set_riding(false, arrived)` aurait été **faux pour un trajet solo** :
`arrived` y nomme où KEEPY est allé, pas où le blaireau se trouve. Un
trajet solo lancé depuis la tour où le blaireau n'est pas aurait alors
réécrit la porte sur la mauvaise extrémité, silencieusement — jusqu'au
prochain tap sur le blaireau, introuvable là où la porte le disait. Fixé
en lisant `_zipline_door.waiting_end()` **avant** que `set_riding(true)`
ne l'écrase à -1 au début d'un trajet solo (`_try_zip_solo`), et en le
transportant dans `_zip_trip["badger_at"]` jusqu'à la réouverture.

**Rien d'autre n'a eu besoin de changer.** Point 3 du brief demandait de
vérifier — pas de supposer — que le canal de tap du blaireau
(`tapped_zipline_badger`) suit sa position réelle. Vérifié en lisant le
code plutôt qu'en le devinant : `ZiplineDoor.rider_position()` lit
`_rider.global_position` en direct (jamais un point mémorisé),
`accepts_boarding_tap` teste contre ce point live, et `_try_zip_badger`
lit `_zipline_door.waiting_end()` pour décider `from_end` plutôt qu'un
index câblé. Cette dynamique existait déjà **avant** ce lot — nécessaire
dès le tier 2 pour que le blaireau puisse traverser dans les deux sens —
donc retirer le chaînage de retour est la totalité du changement de
comportement ; aucune fonction n'a eu besoin de « devenir » sensible à
l'extrémité, elle l'était déjà.

### Le cas du point 5 du brief, et comment il est gaté

« Si le blaireau est au nord et Keepy au sud, Keepy ne doit voir/taper
AUCUN hotspot blaireau au sud — seul le hotspot structure reste
disponible. » `ZiplineDoor.accepts_structure_tap` exclut déjà un point
seulement `if i == _at_end and accepts_boarding_tap(point)` — c'est-à-dire
seulement à l'extrémité où le blaireau attend **réellement**. Une fois
`_at_end` correctement mis à jour sur l'extrémité d'arrivée (ce que ce lot
corrige), cette règle produit le comportement demandé **sans modification
supplémentaire** : au sud (vide), `accepts_structure_tap` n'exclut plus
rien et `accepts_boarding_tap` refuse tout point (aucun `_rider` proche) —
donc seul le canal structure répond. `ZiplineRideProbe.gd` PHASE ARRIVAL
gate exactement ça après le premier trajet.

### Sondes — `ZiplineRideProbe.gd`

**PHASE ARRIVAL réécrite en totalité.** L'ancienne version gatait le
chaînage automatique (porte fermée pendant tout le retour, `_zip_trip`
badger-only 1→0, attente de la réouverture réelle, blaireau retrouvé au
sud). La nouvelle gate l'absence de chaînage : réouverture immédiate,
`_zip_trip` vidé (pas seulement réécrit), blaireau enregistré et
physiquement présent à l'extrémité d'arrivée (nord), et — le point 5 du
brief — les quatre combinaisons de canal par extrémité (`is_available_at`,
`accepts_boarding_tap`, `accepts_structure_tap`) au sud vide et au nord
occupé.

**PHASE RETURN adaptée** : testait déjà un trajet solo nord → sud sur le
canal structure (c'était déjà, avant ce lot, le seul moyen de revenir
depuis le nord puisque tier 3 y avait déjà retiré tout blaireau
stationnaire — RECON de ce même fichier). Seul changement : le blaireau
que ce trajet doit voir NE PAS bouger est maintenant celui posé au nord
(`_badger_rest(1)`), pas un blaireau « déjà rentré » au sud.

**PHASE RETURN ACCOMPANIED, nouvelle.** Aucune phase de ce fichier n'avait
jamais fait démarrer un trajet accompagné depuis l'extrémité 1 — les trois
tiers précédents ne l'exerçaient que depuis l'extrémité 0, où le blaireau
attendait par construction au démarrage de la sonde. Ce lot ajoute
exactement ce cas : un second tap sur le blaireau, maintenant au nord,
qui doit démarrer un trajet 1→0, arriver, et reposer la porte sur
l'extrémité 0 sans chaîner de troisième étape — la symétrie que ce lot
prétend avoir livrée, effectivement mesurée plutôt que supposée par
architecture.

⚠️ **Piège rencontré en écrivant PHASE ARRIVAL, et laissé dans le
commentaire du fichier pour la prochaine session** : le premier jet
testait `_door.accepts_boarding_tap(P2)` en croyant tester « un tap sur le
point du blaireau ». `P1`/`P2` sont les **centres de tour**, pas la
position du blaireau — qui se tient mesurément à 2,0165 u du centre
(`ZiplineDoor.gd`, doctrine du tier 3), hors du rayon `BOARD_TAP_RADIUS`
(1,8). La sonde a échoué dès la première exécution (2 FAIL) exactement là
où elle aurait dû échouer si elle testait la bonne chose pour la mauvaise
raison — sauf qu'ici c'est le test lui-même qui confondait le centre de
tour et le point réel du blaireau. Corrigé en lisant
`_door.rider_position()` pour le point réel, et en corrigeant du même coup
l'assertion symétrique : le centre de tour, à 2,0165 u du blaireau, est
**hors** du disque d'exclusion et donc **accepté** par le canal structure
(`accepts_structure_tap(P2) == 1`), pas refusé comme le premier jet le
supposait.

**ROUGE AVANT VERT.** L'ancien `HubWorld.gd` (celui de `7938317`, avec
`BADGER_HOME_END` et le chaînage) restauré temporairement par-dessus le
fichier corrigé, sonde relancée contre lui : **18 échecs**, tous dans
PHASE ARRIVAL (les neuf assertions « pas de chaîne ») et en cascade dans
PHASE RETURN / PHASE RETURN ACCOMPANIED (qui supposent toutes deux un
blaireau déjà au nord après le premier trajet — faux sous l'ancien
comportement, où il est déjà reparti vers le sud). Fichier restauré depuis
la copie de travail et vérifié **byte-identique** au `cmp` contre la
version commitée. Sonde relancée une dernière fois contre le code
définitif : **137 OK / 0 FAIL**.

**`ZiplineStructureProbe.gd`** (partage `HubWorld.gd` mais ne teste rien
du chaînage) : relancée sans modification pour confirmer l'absence de
régression. **102 OK / 0 FAIL**, inchangé du lot précédent.

### Build

`godot4 4.3.stable` et les templates d'export (absents par défaut dans ce
bac à sable, comme pour le lot précédent — retéléchargés, tailles
vérifiées contre les mêmes `Content-Length` déjà publiés dans ce fichier :
50 276 070 octets éditeur, 1 073 228 327 octets `.tpz`). `.godot/imported`
compté aux deux bouts (38 `.scn`, stable entre le premier import et le
réimport post-nettoyage `build/.godot`) pour écarter un import tronqué.
Export Web complet : `index.wasm` **35 376 909 octets**, md5
`af4a8fc2925d992348eb30deeeb54360` ; `index.js` md5
`4e08904b1b7107858246af44b602067b` — identiques aux empreintes déjà
publiées, confirmant qu'aucun code moteur n'est touché par ce lot.
