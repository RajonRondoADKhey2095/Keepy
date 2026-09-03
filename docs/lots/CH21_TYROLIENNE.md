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
