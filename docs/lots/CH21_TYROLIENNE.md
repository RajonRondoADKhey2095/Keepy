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
