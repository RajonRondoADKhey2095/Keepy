# CH29 — La Crique : cinquième zone, réseau étendu, char à voile

> Version **cadrée** de la section « CH29 — LA CRIQUE » du journal carte
> blanche ([`docs/CARTE_BLANCHE_JOURNAL.md`](../CARTE_BLANCHE_JOURNAL.md),
> conservé tel quel, verbatim). Ce fichier reprend ce qu'une session future
> qui toucherait à la Crique, au réseau de transport ou au char à voile doit
> savoir, sans repasser par le récit heure par heure.
>
> Session carte blanche nocturne du 5 au 6 septembre 2026, seule sur le
> dépôt, branche `claude/hub-fifth-zone-transport-3nkix4` sur
> `origin/staging` (`05fd142`, V8 karting lot 2). **Rien du karting n'a
> bougé** (`git diff --stat origin/staging -- scripts/hub/kart
> scripts/hub/HubKarting.gd` vide). **Aucun personnage créé.** `main`
> intouché.

## Ce qui est livré

Une cinquième zone du hub, **« la Crique »**, à l'EST de la Lande aux
Moulins, accessible **à pied** par un couloir dans le bord est de la Lande.
Sable pâle chaud, mer turquoise concave, phare rouge et blanc (le repère),
palmiers, parasols, transats, chaise de maître-nageur, bouées, coquillages,
bois flotté, oyats. Une interaction propre à la zone (les châteaux de
sable), une réaction météo double (les châteaux fondent, le phare s'allume
et balaie), le réseau existant étendu (troisième ligne de montgolfière
« Corail », directe plateau → Crique), un **nouveau moyen de transport**
(le **char à voile**, glisse libre et continue au sol, vitesse au vent),
la persistance en **schéma 2** de `WorldSave` avec migration 1 → 2, et un
**terrier de dune** avec son `ModelSlot` inerte pour un futur habitant.

## La géométrie — une seule propriétaire, `HubRegion`

| chose | valeur | où |
|---|---|---|
| rect de la Crique | x 44..74, z −130..−90 | `COVE_MIN` / `COVE_MAX` |
| couloir | x 38..44, z −100..−92 | `COVE_CORRIDOR_MIN/MAX` |
| porte | (41, 0, −96) | `HubWorld.COVE_GATE` |
| mer | disque r 48 centré (108, 0, −110) | `SEA_CENTRE` / `SEA_RADIUS` |
| rive | x = 60,0 au milieu, 64,4 aux bords (concave : une crique) | `shore_distance()` |
| phare | (56, 0, −124), trou r 1,9 dans la région | `LIGHTHOUSE_AT` / `_holes` |
| zone | `zone_of()` = **4** | |

**La mer a été déplacée de 8 u vers l'ouest après mesure** : centrée à
(116, −110) elle était hors cadre depuis le dock et depuis l'embouchure du
couloir (`CoveRecon`, `unproject_position` sur la vraie caméra : le cadre
fait ~7 u de large au z de Keepy et ne s'élargit qu'en avant). Une plage
dont l'eau n'est jamais dans l'image est un parking.

La mer est **marchable** jusqu'à `COVE_MAX.x = 74` (l'eau est un lieu,
décision du 26 août 2026) : Keepy patauge 14 u au large, `HubWater`
répond `&"sea"` (teinte des pieds), `clamp_to()` ramène tout tap du large
sur x = 74.

### Le graphe des zones est devenu un ARBRE

`HubWorld._gates_between(a, b)` était une chaîne linéaire 0–1–2–3 et son
commentaire le disait : « a zone OFF the chain needs one [planner] ». La
Crique est la première zone hors chaîne : elle pend de la Lande (2) par sa
propre porte. Deux tables dès la première entrée (`BRANCH_OF = {4: 2}`,
`BRANCH_GATE = {4: COVE_GATE}`) : un trajet qui PART d'une zone-branche
passe d'abord sa porte, un trajet qui y ARRIVE parcourt la chaîne jusqu'à
la zone-mère puis la porte. Un second embranchement est une ligne de plus.
Mesuré (`CoveProbe` PHASE REGION) : 2→4 = [COVE], 4→0 = [COVE, MOOR,
CORRIDOR], 4→3 = [COVE, CIRCUIT], 1→4 = [MOOR, COVE], et la chaîne
0→3 / 3→0 inchangée (régression). PHASE WALK : une marche réelle
Lande → Crique passe la porte et finit en zone 4 ; Crique → plateau passe
les trois portes dans l'ordre et finit en zone 0 sans jamais atterrir hors
région.

### `zone_of()` demande la Crique EN PREMIER

Le couloir commence sur la ligne x = 38, qui est aussi le bord de la
Lande : un point sur cette ligne doit lire comme le couloir dans lequel il
ouvre, pas comme la Lande qu'il quitte.

## Le sol et la mer — shaders

* `cozy_ground.gdshader` : une **bande de sable** dans un rectangle
  (`cove_rect`, feathering au bruit comme les autres bandes), ondulations
  diagonales douces, **sable mouillé** vers la rive (`shore` par distance
  au centre de la mer), et sous le disque un **fond marin** qui fonce de la
  rive vers le large — c'est ce que l'alpha de l'eau laisse voir, et c'est
  ce qui fait le dégradé « peu profond → profond » de toute plage du
  registre. Le rectangle peint (`CozyPalette.COVE_RECT`, x 44..180,
  z −200..−86) court loin au-delà de la zone marchable exprès : tout ce
  qui est sous la mer doit être sable ou fond, jamais pelouse — et les
  rayures tondues du Circuit passaient sous la brume au sud de z = −150
  (capture « sea », première passe).
* `cozy_water.gdshader` : un uniforme `rim_width` (défaut 0,10 = ce que
  tous les lacs dessinaient, byte-identique) ; la mer passe 0,035 pour
  qu'un disque de 48 u ait une ligne d'écume de 1,7 u et non un tablier
  blanc de 4,8 u. `CozyPalette.water_material()` prend `rim_width` et une
  paire de tons optionnels (`SEA_SHALLOW` / `SEA_DEEP`).

## `HubCove` — le module

Nœud `World/Cove` (entre `Transport` et `Trees`), sur le patron
`HubTransport` / `HubKarting` : construit dans `_ready()`, `setup(keepy,
weather)` par `HubWorld`, **accesseurs statiques** (`footprints()`) lus
par `CozyScatter`. Il possède : la mer, le phare + sa lampe + son faisceau,
les trois emplacements de château, parasols/transats/chaise/bois flotté,
trois bouées, le panneau de jonction dans la Lande (35.5, −90), et le
terrier avec son slot.

### Les châteaux de sable — l'interaction de la zone

Trois disques de sable mouillé (`CASTLE_SPOTS`, à 2,0–3,5 u de la rive,
gaté contre `shore_distance`). Canal `HubTapInput.tapped_castle(point,
index)`, demandé sur `aim` juste après les véhicules. **Patron bateau** :
`accepts_castle_tap()` répond −1 pendant que le château MONTE (tween
borné), donc un tap pendant retombe au sol et annule l'intention ; aucune
phase non bornée (Keepy ne monte sur rien).

Un tap → marche jusqu'au **point d'approche** (1,45 u côté terre) → le
château **sort du sable** (échelle 0 → 0,62, `TRANS_BACK`, 1,3 s, cinq
bouffées de sable en `MeshInstance3D` tweenés) ; un 2e tap → 0,84 ; un 3e →
1,0 **et le drapeau**. Un 4e tap fait tourner le drapeau (jamais un tap
avalé). Sous **pluie** (18 s) et **orage** (8 s) tout château **fond**
(échelle vers 0, plus vite en hauteur qu'en largeur) puis disparaît ; le
progrès de fonte n'est pas sauvé (un château rechargé est entier — la
moins mauvaise des deux erreurs).

⚠️ **L'intention est armée APRÈS `hop_to()`, pas avant.** Une marche de
longueur nulle (le 2e et le 3e tap : il est déjà au point d'approche) émet
`became_idle` **synchroniquement** dans `hop_to()`, et `_on_keepy_idle`
efface toutes les intentions. Armée avant, l'intention mourait avant le
`_try_castle()` immédiat ; `CoveProbe` « second tap: stage 2 » l'a trouvé
(0,620 au lieu de 0,84). C'est le pendant de la doctrine « une marche de
longueur nulle n'émet pas d'atterrissage » : elle émet `became_idle`, et
c'est **aussi** un signal qui efface.

### La météo — la zone n'est pas inerte

* la **lampe** du phare passe d'un tint 1,0 à (1,9 ; 1,75 ; 1,15) avec le
  poids pluie + orage (unlit : l'émission est inerte, l'albédo au-dessus
  de 1 est le truc du gland doré) ; le **faisceau** est UN quad alpha de
  11 u dont l'alpha EST le poids météo (0 au soleil), qui tourne à
  0,22 tr/s ;
* les **bouées** tanguent et gîtent avec le `wind` (orage = ×3 le soleil) ;
* la mer réutilise le paramètre `rain` du shader d'eau (grise, anneaux) ;
* le sable mouillé suit `wet` (le sol de toute la carte), la neige couvre.

Gaté (`CoveProbe` PHASE WEATHER) : lampe 0 au soleil → > 0,99 sous
pluie → 0 au retour du soleil ; le faisceau tourne ; un château **rétrécit
en 2 s** de pluie (blind : il a bougé), l'orage l'efface et la sauvegarde
l'oublie ; il se reconstruit après (rien de coincé).

### Le terrier — P2, livré

`burrow_0.glb` (180 tri) à (47.5, 0, −124.5), ouverture vers la mer (+x) :
un monticule de dune, une ouverture sombre encadrée de bois flotté, une
serviette pliée, un seau rouge et une pelle, trois coquillages sur le
seuil. Il **se tient seul** : un lieu habité dont l'occupant est absent.

**Le `ModelSlot`** : nœud `World/Cove/Burrow/BurrowSlot` (`ModelSlot`,
`scripts/world/ModelSlot.gd`), enfant du terrier, à `BURROW_SLOT_OFFSET =
(0, 0, 2.0)` local = sur le seuil, 2 u devant l'ouverture, `rotation.y = 0`
local donc **face à la mer (+x monde)** comme le terrier (gaté : `basis.z.x
> 0.9`). Vide, inerte, aucun code de comportement. Contrat pour l'habitant
futur : `model_scene` posé par Mathieu, échelle visée **0,80 × Keepy**
(`BURROW_SLOT_KEEPY_RATIO`, fourchette 0,75–0,85 du brief ; références :
chat et castor 1,20×, faon 1,35×), origine du modèle **aux pieds** (le
slot est au sol, y = 0), face à +Z modèle. `model_scale` se règle contre le
rig vivant (doctrine `CLAUDE.md` : re-mesurer, jamais copier).

## Le transport

### Ligne « Corail » — le réseau existant étendu

Troisième entrée de `HubTransport.LINES` : `balloon_2.glb` (rose, déjà
dans le dépôt, jamais utilisé), docks **(−13, 0, −33)** [plateau, bord
sud, DANS LE CADRE DU SPAWN] et **(52, 0, −98)** [Crique, à l'embouchure
du couloir, le phare cadré devant]. Directe plateau → Crique : le trajet
le plus long de la carte (spawn → 5e zone, quatre portes) est celui qu'une
ligne devait fermer, et une chaîne de trois vols ne l'aurait pas fait.

Le dock plateau vient d'un **balayage** (`CoveRecon`, grille 1 u sur tout
le plateau : région, sec, hors chemins, dégagement de toute emprise) :
derrière le spawn — où est le dock Or — rien ne dégage plus de 1,7 u ;
(−13, −33) dégage 2,90 u et est cadré depuis la plaza (le dock Or dégage
3,20, le dock Ciel/vallon 6,68 — mesurés dans la même passe). Gaté : les
deux docks Corail dégagent toute emprise de ≥ 2,6 u ; les lignes Or et
Ciel sont byte-identiques.

Vol mesuré (`CoveProbe` PHASE BALLOON) : **636 frames = 10,6 s** du tap
aux pieds sur le sable, atterrissage en zone 4, marchable, sec.

### Le char à voile — le nouveau moyen de déplacement

Créneau non couvert : **libre et continu au sol**. Montgolfière = trajet
fixe point-à-point ; Sautillon = bond ; char = **glisse**. Implémenté
comme un second « véhicule » du modificateur de hop de `KeepyHopper` —
**aucun nouvel état**, la caméra figée du hub inchangée :

* `mount_vehicle(vehicle, lift, glide_step, glide_s)` : quand
  `glide_step > 0`, chaque hop est **plat** (`_hop_height = 0`), long de
  `glide_step`, sans squash ni pitch, et le véhicule est écrit sous lui au
  sol à échelle ONE ; une chaîne de hops = un roulement continu ;
* `set_vehicle_speed(f)` : le facteur vent, poussé chaque frame par
  `HubTransport` (`yacht_speed_factor() = clamp(0,85 + 0,15·wind, 0,85,
  1,25)`) — soleil 1,00, pluie 1,12, orage 1,25 (cap), neige 0,97 ;
  appliqué au **hop suivant** (un hop en vol n'est jamais retimé) ;
* le dernier segment court garde la **vitesse**, pas la durée ;
* constantes dans `HubTransport` : `YACHT_PARK (48, 0, −112)`,
  `YACHT_SEAT_Y 0,66` (pattern `RIDE_SEAT_Y` : le siège écrit une fois),
  `YACHT_GLIDE_DISTANCE 3,2` / `YACHT_GLIDE_S 0,30` = **10,7 u/s** au
  soleil (×2,0 la marche, ×1,35 le Sautillon), 13,3 u/s cap orage — la
  vitesse de vol des montgolfières, déjà lisible sous cette caméra.

Portes : `tapped_vehicle` existant ; `HubTransport.vehicle_at(point)` dit
LEQUEL (balle ou char) ; **seul le véhicule monté se retire** du tap, donc
un tap sur l'autre = **échange** (la balle est lâchée là où il est). Un tap
sur lui-même à l'arrêt = descendre (règle de la balle). **Il n'est PAS
re-garé** par la règle hors-champ : là où on le laisse il reste, à travers
les sessions (`WorldSave.cove_yacht`, écrit à chaque descente, lu au boot ;
hors région → au parc).

Borné par construction : le char est un modificateur de hop, toute
destination est clampée par `HubRegion`, les portes s'appliquent. Gaté
(`CoveProbe` PHASE YACHT, 32 checks) : monte, siège à 0,66 exactement,
glisse plate (écart max 0,000 en y), zéro squash, char au sol et sous lui à
CHAQUE frame (101/101), **10,59 u/s** mesuré contre 10,67 attendu, orage
**12,71 u/s** (ratio 1,20 pour 1,25 — le dernier segment court et le
premier hop non retimé expliquent l'écart, toléré 0,12), une glisse vers
(400, −110) s'arrête sur x = 74 sans jamais quitter la région, une glisse
Crique → Lande passe la porte et arrive montée, descente sur soi, position
sauvée, non re-garé après 120 frames loin de lui, un `HubTransport` neuf le
remet où il a été laissé, échange balle → char.

⚠️ **Durcissement trouvé par la sonde** : `HubWorld._hop_via_corridor`
passait le point BRUT à `hop_to()` dans le cas intra-zone (seule la cible
servait au calcul de zone). Tous les appelants passent déjà un point
clampé (`HubTapInput` clampe avant d'émettre) — mais la sonde, appelant
`_on_tapped_ground((400, −110))` en direct, a roulé le char **130 u hors
carte**. Le monde clampe désormais lui-même une seconde fois.

## Persistance — `WorldSave` schéma 2

Premier vrai bump. `SCHEMA_VERSION = 2`, bloc `cove = {yacht: [x, z] |
null, castles: {"<spot>": 1..3}, visited: bool}`, trois stats
(`castles_built`, `yacht_rides`, `cove_visits`). `_migrate(1 → 2)` écrit
les défauts du bloc et ne réinterprète aucun champ v1. Gaté (`CoveProbe`
PHASE SAVE, 17 checks) : **un vrai document v1** (ressources, arbre,
stats, kart, champs réservés) boote en `migrated` avec tout intact et une
crique vide ; re-sauvé il est schéma 2 et boote `loaded` ; le bloc fait
l'aller-retour ; un `cove` malformé (yacht à une coordonnée, stade 9, clé
non numérique, `visited: "yes"`) est **filtré pièce par pièce** sans perdre
le document ; schéma 3 reste « future ».

`V4SaveProbe` : les trois fixtures « document du schéma courant » nomment
`SaveScript.SCHEMA_VERSION` au lieu du littéral 1 — elles suivent le bump ;
le test « pré-versionné → migrated » et « 99 → future » sont inchangés.

## Le décor — `CozyScatter._cove()`

Seed `SEED + 404`, dans l'ordre : une ligne de palmiers **sud** dans la
région (la ligne nord a été retirée : la caméra est 8,9 u au nord de Keepy,
et pour quiconque sur la moitié nord de la plage la ligne se tenait ENTRE
l'objectif et le corps — capture « corridor », première passe : une
couronne plein cadre), un palmier à l'embouchure **sud** du couloir, deux
lignes de dunes HORS région (nord et sud) et une frange sur la plaine de
sable au sud, oyats sur l'arrière-plage, coquillages et étoiles denses vers
l'eau mais jamais sur la bande mouillée ni sous la mer, rochers pâles. Le
mur de forêt à l'est de la Lande (`_is_cove_wall`) est en palmiers et
jamais dans la mer ; une **quatrième haie** (`hedge4`) ferme la bande
x 38,5..43,5 entre Lande et Crique, cyprès côté Lande, palmiers côté
Crique, avec un trou plus large au NORD du couloir qu'au sud (la caméra
d'un corps dans le couloir est dans cette bande). Les collines de
l'horizon qui tombaient sur la plage ou sa mer sont filtrées **après** le
tirage (la séquence aléatoire et toutes les autres collines sont
exactement ce qu'elles étaient). Route `COVE_ROAD` : quitte la route de la
Lande au hameau, passe **au nord du repos du castor** (la première trace
passait dedans — trouvé par la sonde), plonge vers le couloir, s'arrête à
la marche du dock.

**Palmiers à `visibility_range_end = 95`** quelle que soit la famille (mur
compris) : 226 tri pièce contre 140 le cyprès ; depuis le spawn, à 110+ u
et 91 % de brume, ils coûtaient **6 334 primitives** (70 801 → 77 135
mesurés). L'horizon de la Crique est à 30 u de quiconque s'y tient.

## Assets — `docs/carte_blanche/blender/cove.py`

22 GLB, bpy 4.2 headless, contrat habituel (Y-up, COLOR_0 par coin, un
matériau plat `KHR_materials_unlit`, sans texture). Triangles : palm 226
(×3), lighthouse 446, lamp 20, umbrella 68 (×2), deckchair 68 (×2),
lifeguard 100, buoy 108, shell 21 / 100, starfish 10, driftwood 126,
dunegrass 18 (×2), sandcastle 484, castleflag 7, burrow 180, yacht_hull
196, yacht_sail 27. Déterministe : deux générations rendent des GLB
byte-identiques sauf ce qui a changé.

⚠️ **Les couleurs de sommet s'interpolent entre anneaux** : la tour du
phare, un seul cylindre de 0,5 à 6,7 peint en bandes rouge/blanc, a rendu
**entièrement rouge** (planche Godot, première passe) — les seuls sommets
étaient aux deux bouts. Reconstruite en quatre segments empilés, un par
bande. Une bande de couleur exige ses propres anneaux de sommets.

**Blender ne rend pas dans ce sandbox** (`libEGL.so.1` absent, `apt` sans
réseau). La planche de contact est une sonde Godot jetable (`CoveSheet`,
SubViewport 1800×1000, quatre azimuts/élévations, brume coupée) — de toute
façon le seul rendu qui compte est celui du moteur.

## Mesures

### Temps de trajet (headless, `--fixed-fps 60`, hopper réel)

| trajet | avant (à pied) | après | gain |
|---|---|---|---|
| spawn → centre de la Crique | **30,6 s** (référence `origin/staging` : spawn → (36, −96) bord est de la Lande = 25,8 s) | marche au dock 6,5 s + vol Corail 10,1 s + 1,7 s = **18,3 s** | −40 % |
| Crique → porte du Circuit | 15,3 s | char à voile **7,5 s** (soleil) | −51 % |
| Lande (centre) → Crique | 11,9 s | char **5,9 s** | −50 % |
| porte du Circuit → Lande (centre) | (walk ≈ 10 s, référence) | char **2,4 s** | |

Références sur `origin/staging` importé à part : spawn → dock Ciel 26,6 s,
spawn → Circuit centre 37,1 s, spawn → Lande centre 25,5 s, dock Ciel →
(36, −96) 8,5 s, porte Circuit → (36, −96) 10,5 s. La marche elle-même
n'a pas changé (aucune constante de `KeepyHopper` touchée).

### Triangles `gpu` (`RenderingServer`, liste opaque, LOD du moteur)

| station | avant (`origin/staging`) | après | delta |
|---|---|---|---|
| spawn (0, 0) | 70 801 | **73 861** (77 135 avant le range des palmiers) | +3 060 : le dock Corail, son panneau et la montgolfière rose, DANS le cadre du spawn par choix |
| Lande est (30, −100) | 44 525 | **51 803** | +7 278 : la Crique est là, à 15 u |
| embouchure du couloir (44, −96) | — | 51 799 | |
| dock Crique (52, −98) | — | 48 350 | |
| milieu de plage (56, −110) | — | 37 605 | |

Le plafond publié de 50 000 est **déjà dépassé au spawn sur `staging`**
(70,8 k, et l'index du dépôt le dit « en cours de ré-arbitrage ») ; ce lot
ne le répare pas et ne le cache pas. La Crique elle-même tient sous 50 k
depuis toutes ses stations ; la Lande est à 51,8 k depuis son bord est.

### Sondes

* `CoveProbe` (nouvelle, `ProbeWatchdog.arm` en première instruction,
  840 s) : neuf phases, **163 checks** en un seul run. Cinq passes
  rouge-avant-vert, fichiers restaurés byte-identiques (`cmp`) :
  `SCHEMA_VERSION` remis à 1 → 4 rouges (migration, schéma 2, et deux
  fixtures v2 lues comme « future ») ; `_show_castle` retiré du build →
  9 rouges (tout ce qui mesure un château dessiné) ; `is_gliding()` forcé
  faux → 7 rouges (arc, squash, allure, facteur orage, échange) ; fonte
  neutralisée → 5 rouges ; `BRANCH_OF` vidé → 4 rouges (les quatre
  routages vers/depuis la Crique, la chaîne restant verte).
* Table complète des 73 sondes du dépôt rejouée sur les DEUX arbres
  (branche et `origin/staging` importé à part, mêmes flags) : **l'ensemble
  des sondes non vertes est identique des deux côtés, assertion pour
  assertion** (19 rouges/inconclusives/timeouts pré-existants sur
  `staging`, les mêmes sur la branche ; `JumpDodgeRewardAudit`, Chased,
  rouge sur la référence seulement — tirage aléatoire). Zéro régression.
  Tableau ligne à ligne dans le journal.

## Ce qui n'a pas été fait, et pourquoi

* **Pas de « point de Sautillon »** : la balle est un nœud unique re-garé
  à un parc ; un second parc serait un second scalaire pour un objet qui
  n'en a qu'un. Le réseau est étendu par la ligne Corail.
* **Pas de GPUParticles3D** malgré le brief : le dépôt n'en contient aucun
  et `CozyScatter` documente « no GPUParticles3D on purpose ». Les
  bouffées de sable sont des `MeshInstance3D` tweenés.
* **Fonte non persistée** ; **aucun son** ; le faisceau du phare est un
  alpha à tester sur device à plusieurs azimuts (doctrine `CLAUDE.md`).
* **Un `.import` par GLB neuf** est commité (les paramètres d'import par
  défaut, identiques à ceux des décors existants).
