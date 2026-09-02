# Pie, baiser et hotspot du lit

> Extrait de `CLAUDE.md` par le LOT H (2 septembre 2026), **verbatim** : aucune ligne réécrite, résumée ni supprimée.
> 11 section(s), 2238 lignes d'origine.
> Doctrine permanente : voir `CLAUDE.md`. Index des chantiers : `docs/lots/INDEX.md`.

## LA PIE DANS LA CABANE : un troisieme `kind` de hotspot, un bisou, et TROIS premisses du brief qui tombent a la mesure (31 aout 2026)

Branche `claude/magpie-cabin-interaction-2ou9yw`. Une pie Meshy posee au sol du
salon de `CabinInterior` : un tap sur elle amene Keepy sur un point FIXE devant
elle, il se penche pour un bisou, et quelques coeurs montent. **Repetable sans
limite, aucun cooldown, aucun compteur, rien de retenu entre deux bisous.**

⚠️ **PREMISSE FAUSSE N°1, MESUREE AVANT DE BRANCHER : `main` et `staging`
n'etaient PAS identiques.** Le brief donnait le meme arbre des deux cotes
(`3c66c975`). Mesure : `main` porte l'arbre **`8f850a66`**, `staging`
**`3c66c975`**, et `main` a **deux commits de plus** dont le diff est
**`CLAUDE.md` seul** (67 insertions). Branche depuis `origin/main`, qui est le
sur-ensemble strict. Regle n°1 verifiee par comparaison d'ARBRES et pas de noms,
**aucune session concurrente**.

### ⚠️ PREMISSE FAUSSE N°2 : LE SYSTEME DE TAP DE LA CABANE EXISTE DEJA -- le STOP du brief ne se declenche pas

Le brief prevoyait d'arreter et de re-demander un modele si aucun systeme de tap
interne n'existait. **Il en existe un, et c'est deja le registre generique que le
brief demandait de creer** : `scripts/nav/LevelHotspot.gd`, dont l'en-tete nomme
lui-meme « a door, a bed, a chest », consomme par `LevelController.dispatch()`.
Il porte **deja** les deux doctrines que ce lot devait respecter -- la question
posee sur l'**AIM** et jamais sur la destination clampee, et le **retrait facon
bateau** avec le patron echelle explicitement **banni** (« it has cost this
repository TWO bugs »).

**La pie est donc un troisieme `kind`, pas un troisieme mecanisme** -- exactement
comme `&"bed"` avait ete ajoute apres `&"door"`. Aucune machinerie neuve,
`HubTapInput.gd` byte-intouche.

### ⚠️ PREMISSE FAUSSE N°3 : `CPUParticles2D` EST TECHNIQUEMENT IMPOSSIBLE ICI

Le brief nommait `CPUParticles2D` en billboard. Deux raisons, la seconde
decisive : c'est un **`Node2D`**, donc il ne peut ni vivre dans le `SubViewport`
3D de la cabane, ni etre occulte par la geometrie, ni etre porte par une camera
3D ; et **il n'existe AUCUN systeme de particules dans tout ce depot**, ce qui
est une **decision ecrite** (`HubWorld.gd:1759-1767`) et pas un oubli. Question
posee a Mathieu plutot que tranchee seul ; **choix retenu : Sprite3D billboard +
tween**, c'est-a-dire le mecanisme deja prouve sur cet ecran (l'anneau d'impact
d'eau, les billboards de `Decor.gd`) -- zero techno nouvelle, et l'intention
reelle du brief (CPU, billboard, bon marche sur mobile) tenue.

### L'ASSET : la chirurgie lossless-d'abord, et 10,7 Mo de maps structurellement mortes

Source **`assets_source/openworld/perso/Meshy_AI_Pie.glb`** (15 610 452 octets),
localisee et non supposee ; **aucun `.blend` versionne** nulle part dans le depot
(regle respectee, verifiee par `find`). Mesure : **1 noeud, 1 mesh, 1 primitive,
0 skin, 0 animation**, 4 210 triangles, `extensionsUsed` **absent**.

Discipline lossless-d'abord, dans l'ordre que ce depot impose :

| passe | resultat |
|---|---|
| reecriture verbatim | chunk BIN **byte-identique** (md5 `2d1afecf85f1ef5be82c3e6b9ded8ff2`) |
| + `KHR_materials_unlit` | BIN encore byte-identique (`used`, jamais `required`) |
| - normal + metallicRoughness | prefixe geometrie **byte-identique**, PNG baseColor **byte-identique** |

⚠️ **Les deux maps retirees sont MORTES PAR CONSTRUCTION, et c'est mesure sur le
materiau importe et pas deduit** : `normal_texture = null`, `normal_enabled =
false`, `metallic_texture = null`, `roughness_texture = null`, `shading_mode = 0`
-- l'importeur glTF de Godot ne lie **jamais** ces maps sur un materiau UNLIT.
**Preuve au pixel** : les quatre azimuts rendus avant/apres sont
**BYTE-IDENTIQUES**. **15 610 452 -> 4 916 244 octets (-68,5 %).**

Installee en **`assets/models/keepy_magpie_prop.glb`**, sidecar
`keepy_magpie_prop_Baked_BaseColor.png` conserve, les deux sidecars morts
supprimes. Face sur le model **+Z**, verifiee par rendu quatre axes.

### ⚠️ LE PREMIER PLACEMENT ETAIT FAUX, ET C'EST LE RENDU QUI L'A TROUVE

A `MAGPIE_SPOT (-0.80, 0.30)` avec un stand spot a `(-0.35, 1.05)`, **Keepy se
tenait ENTRE elle et la camera fixe** (un z plus grand est plus proche) et un
ecureuil de 1,35 masquait presque entierement un oiseau de 0,71. **Aucune
constante ne pouvait attraper ca.** Corrige par mesure -- extents des deux corps
lus sur les accessors POSITION (portee avant de Keepy **+1,018** le long de son
+Z, demi-profondeur de la pie ~0,42), balayage du mur gauche (sol plat jusqu'a
x = -1,6, le mur monte a -1,8) :

| | livre |
|---|---|
| `MAGPIE_SPOT` | **(-1,10 ; 0,90)** -- plus pres de la camera, decalee en x |
| `MAGPIE_STAND_SPOT` | **(0,05 ; 0,40)** -- ecart 1,254, 1,098 du pas de porte |
| `MAGPIE_SCALE` | **0,50** (montee de 0,40 apres rendu) |
| `MAGPIE_FACING_BIAS_DEGREES` | **-45** -- trois-quarts camera, pas de dos |

⚠️ **ELLE EST HORS DU CARRE MARCHABLE, ET C'EST VOULU** : ce carre est celui de
Keepy, retreci de sa demi-largeur ; un prop n'a pas cette contrainte, et le sol
est mesure plat jusqu'a x = -1,6. Asserte plutot que suppose.

### L'INTERACTION : quatre pieges que ce depot a deja payes

* **`destination` EST DISCARDE** -- la seule branche de ce fichier qui le fait.
  Un oiseau se rejoint, il ne se pietine pas : le point ou se tenir appartient a
  ce fichier, pas au pouce dans un cercle de 0,60. Honorer la destination
  clampee serait le bug d'entonnoir sous un autre chapeau.
* ⚠️ **IL SNAPPE SUR LE POINT FIXE**, et cette ligne est porteuse.
  `LevelWalker._advance()` arrete une chaine des que le reste passe sous
  `ARRIVE_EPSILON` (0,45) -- **une marche finit PRES de sa cible et jamais
  DESSUS**, mesure a **0,401 court** sur une approche. Sans le snap l'ecart entre
  eux dependrait du cote d'ou il arrive : de l'autre bord, **plus proche que son
  propre museau n'est long**, c'est-a-dire un ecureuil dessine a travers un
  oiseau. Le lit fait exactement ca, pour exactement cette raison.
* **L'INTENT SURVIT A UN ATTERRISSAGE DE PASSAGE** -- le bug du lot hibou.
* **APPEL IMMEDIAT POUR LA MARCHE DE LONGUEUR NULLE** -- `_advance()` termine une
  marche plus courte qu'`ARRIVE_EPSILON` par `became_idle` et **jamais** par
  `hop_landed`, donc une branche cablee sur le seul atterrissage ne fait rien.
  **C'est le defaut qui a SHIPPE sur la porte** et que le lot precedent a ferme.
* **RETRAIT FACON BATEAU** (`set_busy`) pour la duree du bisou, jamais le patron
  echelle. **Ce n'est PAS un cooldown** : elle est tenue `KISS_S` (0,85 s) et pas
  une milliseconde de plus. Le **lit tient l'echelle** parce qu'il partage un
  petit carre avec son sommet ; le bisou se passe au rez-de-chaussee ou le pied
  est a **3,930** contre des rayons qui somment a 1,700 -- **asserte**, donc
  c'est un fait sur le layout et pas un espoir.
* Le lean roule une cloche **`4t(1-t)`** sur un seul `tween_method` normalise --
  exactement 0 aux deux bouts, donc aucune pose ne peut rester coincee.

### `CabinHearts.gd` : LE PROP GENERIQUE QUE CE LOT LAISSE DERRIERE LUI

**Pour le prochain prop interactif de la cabane, tout est deja la :**

1. `LevelHotspot.make(niveau, point, rayon, &"nouveau_kind", "Libelle")`, ajoute
   a `_controller.hotspots` -- **le registre generique, il existait deja**.
2. Une branche `&"nouveau_kind"` dans `CabinInterior._on_tapped_hotspot`, sur la
   forme de `&"magpie"` : flash du marqueur, effacer les autres intents,
   `hop_to()` vers un point FIXE, armer l'intent APRES, puis appeler le `_try_*`
   immediatement pour la marche de longueur nulle.
3. **`scripts/cabin/CabinHearts.gd`** (nouveau, `class_name CabinHearts`) pour
   tout eclat de billboards : `burst(at: Vector3, tint: Color = HEART_COLOR)`.
   Trois `Sprite3D` unlit, double face, `BILLBOARD_ENABLED` (et pas `FIXED_Y` --
   cette camera ne lacete jamais), un `tween_method` par coeur sur 0..1, puis
   `queue_free`. **Sa texture est DESSINEE en code** depuis la courbe implicite
   `(u^2+v^2-1)^3 - u^2 v^3 <= 0` avec anti-aliasing 2x2 : **aucun fichier n'est
   livre**, donc aucun octet ajoute au `.pck` pour les coeurs. Les couloirs sont
   derives de l'index et **jamais tires au hasard**, pour qu'une sonde puisse les
   asserter.

### `CabinProbe` PHASE N : 57 checks, et ROUGE AVANT VERT TROIS FOIS

Gatee et pas rapportee, parce que **tout mode de panne est SILENCIEUX** : le
`.glb` jamais installe ou installe avec ses maps mortes ; des pieds derives d'un
lift copie (le **0,9166** qui a shippe) ; le tap honorant `destination` ; un
intent qu'un atterrissage de passage efface ; une marche de longueur nulle qui ne
depense rien. Aucun ne leve.

⚠️ **ELLE ASSERTE LE POSITIF AVANT CHAQUE REFUS.** « Elle n'a pas repondu » et
« aucun second bisou n'a demarre » passent **gratuitement** contre une branche
jamais cablee.

| neutralisation deliberee | rouge obtenu |
|---|---|
| branche `&"magpie"` -> `return` | **12 FAIL** |
| le SNAP retire, tout le reste intact | **1 FAIL** -- exactement l'assertion du snap (`0.401 -> 0.401`) |
| `_kiss_pending` efface sur un atterrissage hors de portee | **9 FAIL** |

`scripts/cabin/CabinInterior.gd` restaure **byte-identique** (`cmp`) apres
chacune des trois.

⚠️ **DEUX DEFAUTS DE MES PROPRES ASSERTIONS, publies plutot que lisses -- les
deux etaient ROUGES sur du code CORRECT :**

1. **« il finit exactement sur le stand spot »** -- faux, `_advance()` s'arrete a
   moins d'`ARRIVE_EPSILON` de la cible. Re-visee sur ce que `_try_kiss()` mesure
   reellement, `MAGPIE_REACH`.
2. **« il se penche »**, lue a l'instant ou le bisou demarre -- la cloche
   `4t(1-t)` vaut **exactement 0 a t = 0**, et t = 0 est precisement ou le bisou
   se trouve quand l'atterrissage qui l'a lance rend la main. **Sondee** desormais
   sur un budget mur, meme famille que le piege des coeurs (**pic 2,00 deg**).

⚠️ **ET UN TROISIEME, sur l'ETAT GLOBAL : PHASE P laisse Keepy SUR LA MEZZANINE
avec une marche encore en cours.** `LevelWalker._flat()` prend sa hauteur du
niveau que le controleur dit courant, donc sans `set_current(0)` toute la marche
de PHASE N se passait a **7,54** et chaque assertion en XZ seul passait sur un
Keepy flottant un etage au-dessus de l'oiseau. La phase remet le niveau **et**
annule la cible heritee avant de mesurer quoi que ce soit.

⚠️ **Le control du SNAP a du etre refait** : la premiere approche (2,869 u) ne
discriminait pas, parce que `_begin_hop` prend un dernier pas de
`min(HOP_DISTANCE, |delta|)` -- un reste compris entre `ARRIVE_EPSILON` et
`HOP_DISTANCE` atterrit **exactement** sur la cible. Il ne s'arrete court que
lorsqu'un hop PLEIN laisse un reste sous `ARRIVE_EPSILON`. Le control livre fait
donc marcher le walker **SEUL** sur cette approche precise (**0,401 court**),
puis la refait a travers elle (**0,000**).

### VALIDATION

Editeur + templates Godot 4.3-stable dans ce sandbox. **`rm -rf build .godot`
avant l'import**, comme le brief l'exige (le piege d'auto-contamination du lot
precedent). Import headless **exit 0, 37 `.scn`, 0 erreur**. Export Web release
**exit 0, 0 SCRIPT/Parse Error**.

`index.wasm` **35 376 909** octets / md5
**`af4a8fc2925d992348eb30deeeb54360`**, `index.js` md5
**`4e08904b1b7107858246af44b602067b`** -- identiques au fingerprint permanent de
tout lot qui ne touche pas le code moteur. **Piege payload tenu** : sur **270**
lignes `Storing File`, **0** pour `scripts/dev`, `assets_source`, `docs`, `web/`
ou `build`.

⚠️ **`index.pck` passe a 34 349 152, et le delta est ACCOUNTE a l'octet pres
plutot que constate** : les deux seules ressources que la pie fait entrer dans le
pack sont son `.scn` (**161 957**) et le `.ctex` de sa baseColor
(**3 904 992**) -- **le `.glb` brut n'est PAS packe**, verifie sur le log
`savepack`. Avec les deux maps mortes conservees, ce serait ~10,7 Mo de plus.
Marqueur « nouveau build », **jamais preuve d'identite**.

**Sondes, toutes exit 0** : `CabinProbe` (**229 OK, 0 echec**, dont 57 en
PHASE N), `LevelNavProbe` (**77 checks, 0 echec**), `ProbeTimeoutAudit`
(**59 sondes scenes**, identique a la baseline -- les trois sondes jetables de ce
lot sont supprimees), `AssetContractAudit` (**12/12 visuels, 0/10 colliders
deplaces**), `DeathModelAudit`, `ChargerShapeProbe`, `OwlFlightProbe`,
`DivingBoardProbe`, `TurnstileProbe`, `SeesawProbe`, `StreamRideProbe`,
`LakeZoneProbe`, `WaterImpactProbe`, `WaterTintProbe`.

**Non-regression cabine** : PHASE K (porte, lit, echelle), PHASE P (le lit) et
PHASE Z (le premier tap de la porte, le defaut du lot precedent) sont **vertes et
inchangees** ; la seule ligne de PHASE K qui bouge est son compte de hotspots,
**2 -> 3**, itemise plutot que pousse.

### RESTE OUVERT -- jugement device, seul juge

1. **Est-ce que le bisou se LIT comme un bisou** a l'echelle reelle d'un
   telephone ? Le lean fait 26 deg au pic sur 0,85 s ; personne ne l'a vu bouger
   sur un ecran.
2. **Est-ce que trois coeurs suffisent**, et est-ce que leur rose se detache du
   bois clair du salon ? Aucune sonde ne le dit.
3. **Rien ici n'est un rendu device** : llvmpipe sous `xvfb` via le backend
   `opengl3` de BUREAU, contre WebGL2 sous Safari -- et la transparence de ce
   projet est **deja passee verte dans ce sandbox et cassee sur device une
   fois**. Les coeurs sont des billboards alpha.
4. **Derive de doc PRE-EXISTANTE signalee et NON corrigee** : le commentaire de
   `_enter_rest()` dit « XZ is UNTOUCHED -- he lies exactly where he stood »
   juste au-dessus de la ligne qui ecrit `BED_SPOT` dans `global_position`. Le
   code est juste, le commentaire ment ; hors perimetre de ce lot.

### Deploiement staging de la pie (palier 1, automatique)

`staging` **`a021a00`** (merge `--no-ff`, arbre **byte-identique** a la branche
feature : meme hash d'arbre `14b82445` des deux cotes ET `git diff` vide, verifie
AVANT le push). CI run **#336** (id 33378335174) **verte** -- `Import project
resources` 09:36:02 -> 09:39:24 (3 min 22 s), **`Export Web build`
09:39:24 -> 09:39:30**, `Verify export output` succes, `Deploy to Vercel
[STAGING -- staging]` **succes** 09:39:46 -> 09:40:01, `[PRODUCTION -- main]`
correctement **skipped**. **`main` NON touche** (`origin/main` toujours
`afa49d7`, verifie apres le push).

**Verifie SUR LE SERVICE, pas dans le log CI, sur DEUX marqueurs independants,
et les QUATRE lectures utiles portent `x-vercel-cache: MISS` avec `age: 0`** --
les valeurs « avant » ayant ete relevees AVANT le merge :

| marqueur | avant | apres (ce lot, run #336) |
|---|---|---|
| `CACHE_VERSION` | `1788161929` = **07:38:49 UTC** | **`1788169169` = 09:39:29 UTC** |
| `index.pck` servi | **30 274 448** | **34 349 152** |
| `index.wasm` servi | 35 376 909 | **35 376 909** *(inchange, attendu)* |

L'epoch d'apres tombe **a l'interieur de la fenetre `Export Web build`**
(09:39:24 -> 09:39:30) : l'alias sert bien ce build. C'est la forme la plus
forte que ce fichier documente -- deux marqueurs, quatre lectures fraiches, la
bascule prouvee dans les deux sens et pas deduite du log.

⚠️ **`index.pck` servi (34 349 152) est identique a l'export local, et ce n'est
DELIBEREMENT PAS offert comme preuve d'identite** : sa taille n'est pas stable
d'un export a l'autre du meme commit, et une coincidence n'y change rien.
**`index.wasm` reste la preuve d'identite** (md5
`af4a8fc2925d992348eb30deeeb54360`), au fingerprint permanent des deux cotes.
Le saut de **+4 074 704 octets** est le cout mesure de la pie : `.scn` 161 957 +
`.ctex` baseColor 3 904 992, le `.glb` brut n'etant pas packe.

⚠️ **Piege de lecture rencontre et REFUSE** : une lecture faite a 09:39:40, une
poignee de secondes apres la fin de l'export, est revenue `x-vercel-cache: HIT`
avec **`age: 352`** et portait encore l'ANCIEN `CACHE_VERSION`. Elle aurait pu
se lire comme « le deploiement n'a pas pris » ; ce n'etait qu'une copie de bord
figee. Seules les lectures MISS/age 0 comptent, et il a fallu un parametre de
requete different pour la buster.

⚠️ **L'API Actions n'etait PAS perimee sur ce run**, et c'est note dans ce
sens-la : `updated_at` du RUN est reste fige a 09:34:21 pendant toute la
duree -- la forme exacte du piege deja consigne -- mais
`list_workflow_jobs` avec `filter: "all"` a rendu les 18 etapes avec de vrais
horodatages, et l'import a reellement pris **3 min 22 s**. Le champ de haut
niveau ment ; la liste des jobs, elle, disait vrai.

**Reste ouvert : la validation device**, seule juge, sur
`keepy-staging.vercel.app` (Safari iPhone, navigation privee, **jamais la PWA
installee**) -- les trois points de la section precedente. `main` reste gate par
Mathieu.

## LA PIE CALIBREE : trois defauts remontes par l'appareil, trois causes lues dans le code avant tout correctif (31 aout 2026)

Branche `claude/magpie-cabin-calibration-np67n1`, partie de `staging`
(`1398ca9`, la pie deja mergee la veille). Retour device sur les trois points
laisses ouverts par le lot precedent : (A) la pie est **trop petite** face a
Keepy ; (B) Keepy **marche sur elle** -- capture a l'appui, chevauchement
visuel des deux modeles, ce qui vide le baiser de son sens s'il finit debout
SUR elle plutot que devant ; (C) Keepy **saute/tremble** en s'approchant avant
de se poser, la ou la porte et le lit sont deja stables.

**RECON BLOQUANTE FAITE AVANT TOUTE LIGNE DE CORRECTIF**, comme l'exigeait la
consigne -- les trois causes ci-dessous sont lues dans le code livre, jamais
devinees depuis le rapport.

### A -- LA TAILLE : `MAGPIE_SCALE` visait un gout, pas une mesure

`MAGPIE_SCALE` valait **0,50**, choisi a l'oeil. **Mesure sur les deux `.glb`
reellement charges** (script headless dedie, pas d'estimation) :
`MAGPIE_MODEL_MIN_Y = -0.880644` / `MAGPIE_MODEL_MAX_Y = 0.885036` -- extension
Y brute de la pie **1,76568**. Keepy, la meme mesure : extension Y brute
**1,25752**, deja livree a `KEEPY_SCALE = 1.07368`, soit une hauteur DESSINEE
de **1,3501** -- le chiffre deja consigne ailleurs dans ce fichier pour ce
meme modele.

`MAGPIE_SCALE` corrige a **`0,76461`** = 1,3501 / 1,76568 : la hauteur
dessinee de la pie egale desormais **exactement** celle de Keepy, pas la
moitie. **Gate par une nouvelle assertion qui compare les DEUX AABB reels sur
la scene construite** (`mesh.mesh.get_aabb().size.y * MAGPIE_SCALE` contre
`keepy_mesh.mesh.get_aabb().size.y * KEEPY_SCALE`), pas l'arithmetique du
correctif elle-meme -- une assertion qui se contenterait de relire
`MAGPIE_SCALE` prouverait que la constante se multiplie correctement, pas
qu'elle multiplie le BON nombre. Verifiee : `her drawn height (1.3501) now
matches his (1.3501), not half of it`.

### B -- LE CHEVAUCHEMENT : aucune exclusion n'existait, et le `StaticBody3D` du brief est une fausse premisse corrigee

**Rien n'empechait un tap d'envoyer une chaine de hops A TRAVERS le modele de
la pie.** Le coeur de nav de la cabine (`scripts/nav/`, distinct de
`HubRegion` du hub) porte **zero appel `PhysicsDirectSpaceState`** dans tout
le depot -- `LevelCamera.gd` le dit dans son propre en-tete, et c'est ecrit
la deliberement.

⚠️ **Le `StaticBody3D` suggere par le brief est explicitement ECARTE, pas
seulement pas retenu.** Ce serait le PREMIER collider de navigation de ce
projet -- un changement plus gros que l'exclusion qu'il sert, une nouvelle
classe de panne, et un tick physique qu'une sonde devrait ensuite pomper.
Le vrai precedent existe deja et est REUTILISE : `HubRegion.gd` documente
encore, dans son propre en-tete, la technique de trou circulaire qu'elle
portait pour son lac -- retiree par decision explicite de Mathieu (l'eau du
hub devait devenir marchable partout), mais la TECHNIQUE elle-meme n'a rien
perdu de sa validite. C'est exactement ce qu'il faut ici : quelque chose sur
quoi un tap ne doit jamais pouvoir atterrir, sur un niveau qui reste par
ailleurs le carre plat que ce fichier promet deja.

**`LevelDefinition.gd` gagne un mecanisme GENERIQUE et REUTILISABLE**
(`set_hole()` / `has_hole()` / `_in_hole()`), pas un cas special pie :
`contains()` retire le trou APRES le controle de carre (l'ordre meme de
l'ancien `HubRegion`) ; `clamp_to()` clamp au carre d'abord, pousse hors du
trou ensuite a `hole_radius + 0.02` -- reutilisant la marge de bord de 0,02
deja etablie pour le ruisseau du hub, pas une valeur redecouverte au hasard --
puis re-clamp au carre (un trou pres d'un bord pourrait sinon repousser un
point hors du carre que la meme fonction vient de dire marchable).

⚠️ **LE TROU ARRETE UN TAP, IL NE DEVIE PAS UNE CHAINE DE HOPS DEJA EN
COURS.** Exactement comme l'ancien lac : une marche suit une ligne droite vers
sa `_target` et ne consulte rien de ce qui se trouve entre les deux -- ce
projet a zero evitement d'obstacle nulle part, et donner au trou de la pie un
detour prive qu'une traversee du hub n'a jamais eu serait une SECONDE facon de
marcher, pas une plus grande version de la premiere. Ce que le trou achete
reellement, c'est qu'un TAP -- ce qui CHOISIT une destination -- ne peut
jamais en choisir une par-dessus ce que le trou garde.

`MAGPIE_FOOTPRINT_RADIUS = 0,73`, derive par la meme convention que les
autres `FOOTPRINT_RADIUS` du projet (moitie de la plus grande des deux
extensions horizontales mesurees, arrondie VERS LE HAUT) : demi-extension X
mesuree 0,949956, x `MAGPIE_SCALE` = 0,7263, arrondi a 0,73.
`MAGPIE_STAND_SPOT` reste `(0,05 ; 0,40)` mais degage desormais le trou de
**0,524 u** -- **gate**, plutot que laisse comme une coincidence non
verifiee : `and clears her footprint hole by 0.524 (radius 0.73, want
~0.524)`. Un tap vise DANS le trou est **pousse a exactement `hole_radius +
0,02` = 0,7500**, reste marchable, et reste a la hauteur du sol -- les
quatre assertions passent sur le vrai `floor_level` construit, pas sur un
fixture.

### C -- LE TREMBLEMENT : `emulate_mouse_from_touch`, le meme defaut de classe que la porte, sur une moitie qui n'avait jamais recu sa garde

**Cause lue dans le code, confirmee par une trace empirique, PAS supposee.**
Le defaut par projet `emulate_mouse_from_touch = true` fait qu'**UN SEUL tap
physique declenche DEUX evenements independants, dans la MEME passe
d'entree** : un `InputEventScreenTouch` reel puis un `InputEventMouseButton`
synthetise. `CabinInterior._unhandled_input()` dispatche les deux.

Le PREMIER dispatch declenche la branche immediate « deja assez pres » de
`_try_kiss()` (le meme motif « marche de longueur nulle » deja etabli pour
le lit et la porte) : `_kissing` passe a `true`, la pie se retire
(`is_available() -> false`). Le SECOND dispatch -- le meme tap physique,
synthetise -- trouve alors la pie **retiree**, retombe donc sur
`_on_tapped_ground()`, qui appelait **inconditionnellement** `hop_to(destination)`
avant ce lot : Keepy venait d'etre pose exactement sur la position du baiser,
puis en etait arrache une frame plus tard par le second dispatch du MEME tap.
Repete a chaque tap, ca se lit comme un tremblement.

⚠️ **C'est le meme defaut de classe que le bug historique de la porte
(`_exit_pending`), sur l'autre moitie de la paire.** La porte avait deja
appris la lecon (une marche nulle finit par `became_idle`, jamais
`hop_landed`, d'ou l'appel immediat de `_try_rest()`/`_try_enter_cabin()`) ;
`_resting` (le lit) porte deja une garde symetrique dans
`_on_tapped_ground()`. `_kissing` ne l'avait jamais recue -- **la garde etait
asymetrique**, pas absente partout. Corrige par une seule ligne,
`if _kissing: return`, ajoutee juste apres la garde `_resting` deja en
place.

**REGLE A RETENIR POUR TOUT FUTUR PROP SIMILAIRE, pour que ce defaut ne se
reintroduise pas ailleurs** : tout hotspot dont la branche « deja assez
pres » entre immediatement dans un etat busy/retire DOIT AUSSI etre garde
dans `_on_tapped_ground()`. Une garde posee sur un seul des deux cotes de
cette paire (l'entree immediate + le fallback sol) est une garde qui
manquera exactement la ou `emulate_mouse_from_touch` la cherche.

⚠️ **Dette de doc pre-existante, signalee et NON corrigee ici -- hors
perimetre strict de ce lot A/B/C** : le commentaire de `_enter_rest()`
(``# XZ is UNTOUCHED -- he lies exactly where he stood, so there is no
teleport to see``) est FAUX, lu dans le code juste en dessous de lui-meme --
la ligne suivante ecrit `_walker.global_position = Vector3(BED_SPOT.x,
_world_y(BED_MODEL_Y), BED_SPOT.y)`, qui SNAPPE X et Z sur la constante fixe
`BED_SPOT`, pas sur la position d'arrivee reelle (`here`/`flat`, calculee
seulement pour le controle de portee juste au-dessus). Le comportement reel
suit la meme doctrine FIXED SPOT que la pie et la porte -- ce qui est
correct -- mais le commentaire qui l'accompagne dit l'inverse. A corriger
dans son propre lot.

### VALIDATION -- ROUGE AVANT VERT sur les trois causes, sonde par sonde

`CabinProbe.gd` (PHASE N) gagne trois blocs, chacun verifie capable
d'echouer avant d'etre cru sur son succes :

1. **Parite de hauteur** -- compare les deux AABB dessines, pas la seule
   arithmetique de `MAGPIE_SCALE`.
2. **Degagement du trou + poussee du clamp** -- exerce le vrai
   `floor_level.clamp_to()` sur un point vise DANS le trou, verifie qu'il
   ressort marchable, a la bonne marge, a la hauteur du sol.
3. **Course du double-dispatch, le propre defaut livre de ce fichier** --
   reproduit la course EXACTE via le vrai `controller.dispatch()` (pas un
   fixture) : un premier dispatch entre dans le baiser et retire la pie ;
   un second dispatch IMMEDIAT (le meme point d'ecran, la meme frame de
   depart) ne doit ni sortir du baiser ni deplacer Keepy d'un seul
   millimetre. Verifie sur 3 runs independants : **derive mesuree
   0,0000 u**.

**Les trois assertions ont ete verifiees ROUGE avant d'etre VERTES**, en
neutralisant temporairement chaque correctif un par un puis en le
restaurant -- fichier restaure verifie identique a l'original a chaque
fois. Aucun blind check n'a ete necessaire de plus que les 3 blocs eux-memes
: chacun etablit d'abord le fait geometrique/temporel qui rend l'echec
possible (le point vise EST dans le trou, la premiere moitie de la course
EST entree dans le baiser) avant d'exiger le comportement correct.

⚠️ **UN ECHEC RENCONTRE, IDENTIFIE COMME PRE-EXISTANT ET NON LIE A CE LOT --
verifie contre la baseline, pas suppose.** `and every heart frees itself`
(un budget d'attente en TEMPS REEL de 8000 ms, sur les particules-billboard
`CabinHearts.gd`, entierement etrangere au diff de ce lot) flake sous la
charge actuelle du sandbox -- 4 echecs sur 7 runs de la branche (3 runs
propres d'un segment anterieur, tous verts ; 4 runs de ce segment,
tous rouges sur la meme ligne, la charge sandbox ayant visiblement
augmente entre les deux). **Rejoue sur un worktree a `1398ca9` (la meme
scene, code non touche par ce lot), sous la meme charge que ces 4 derniers
runs** : le meme echec, sur la meme assertion, se reproduit aussi -- 1
echec sur 3 runs baseline. C'est un flake de budget mur pre-existant, pas
une regression -- la meme famille de defaut que ce fichier documente deja
ailleurs pour les sondes a budget de temps reel sous charge variable. Non
corrige : hors perimetre de ce lot A/B/C.

**Non-regression : les cinq sondes exigees, toutes exit 0.**
`AssetContractAudit` (12/12 visuels, colliders inchanges), `DeathModelAudit`,
`ChargerShapeProbe`, `LevelNavProbe` (**77 checks, 0 echec**),
`ProbeTimeoutAudit` (**59 sondes scenes + 1 `--script`**, chiffre baseline
inchange -- ce lot n'ajoute aucune sonde, seulement des blocs a
`CabinProbe.gd` existant).

**Build, propre** : `rm -rf build .godot` avant tout. Import headless
**exit 0, 37 `.scn`**. Export Web release **exit 0, 0 erreur GDScript**.
`index.wasm` **35 376 909** octets / md5 `af4a8fc2925d992348eb30deeeb54360`,
`index.js` md5 `4e08904b1b7107858246af44b602067b` -- identiques au
fingerprint permanent de tout lot qui ne touche pas le code moteur, coherent
: ce lot ne modifie que 3 fichiers GDScript. **Piege payload tenu** : sur
270 lignes `Storing File`, **0** pour `scripts/dev`, `assets_source`,
`docs`, `web`, `build` ou `firebase.json`. `scripts/cabin/CabinInterior.gdc`
et `scripts/nav/LevelDefinition.gdc` sont bien packes (le code livre) ;
`scripts/dev/CabinProbe.gd` **absent du pack**, comme il se doit.

**Perimetre du diff, exact** : `scripts/cabin/CabinInterior.gd` (+84/-14),
`scripts/dev/CabinProbe.gd` (+107/-0), `scripts/nav/LevelDefinition.gd`
(+95/-3). Aucun autre fichier touche.

### Reste ouvert -- jugement device, seul juge

`main` **non touche**. Merge sur `staging` : palier 1, automatique (build,
import, export et sondes verts). **Palier 2 reste gate par Mathieu** :
demande explicite de validation device sur `keepy-staging.vercel.app`
(Safari iPhone, navigation privee) avant tout merge vers `main`, portant
specifiquement sur les trois points corriges :
1. **La pie fait-elle desormais la taille de Keepy a l'ecran** ?
2. **Keepy s'arrete-t-il bien DEVANT elle, sans jamais marcher dessus** --
   y compris en visant delibrement un tap dans son emprise ?
3. **L'approche est-elle propre**, sans plus aucun saut/tremblement avant
   qu'il se pose ?

Reste aussi hors perimetre : le lot 2 (visibilite de la pie depuis le hub
avant d'entrer dans la cabine), explicitement pas commence ici ; et le
commentaire perime de `_enter_rest()` signale plus haut.

### Deploiement staging du calibrage pie (palier 1, automatique)

`staging` (`4a840d0`, merge `--no-ff` de `825d7db`). CI **run #338**
(id `33392073223`) **verte** -- `Import project resources` 12:30:55 ->
12:34:26 (3 min 31 s), `Export Web build` **12:34:26 -> 12:34:32**,
`Deploy to Vercel [STAGING -- staging]` succes 12:34:47 -> 12:35:01,
`[PRODUCTION -- main]` correctement **skipped**. **`main` NON touche**
(`afa49d7`, inchange) : palier 2 gate par Mathieu, demande de validation
device ci-dessus.

**Verifie SUR LE SERVICE, pas dans le log CI seul, sur DEUX marqueurs
independants** :

| marqueur | valeur servie |
|---|---|
| `CACHE_VERSION` | `1788179671` = **12:34:31 UTC** -- tombe exactement dans la fenetre `Export Web build` (12:34:26 -> 12:34:32) |
| `x-vercel-cache` / `age` | `MISS` / `0` sur `index.service.worker.js` ET `index.html` |
| `index.wasm` servi | **35 376 909** octets -- identique au fingerprint permanent deja consigne pour tout lot qui ne touche pas le code moteur |
| `index.pck` servi | 34 350 048 octets (marqueur "nouveau build", jamais preuve d'identite seule) |

`index.wasm` inchange confirme qu'aucun code moteur n'a bouge, coherent :
ce lot ne modifie que 3 fichiers GDScript deja itemises ci-dessus.

⚠️ **Une seule limite a dire plutot que sous-entendre** : les deux lectures
ont ete faites APRES le merge (aucune lecture "avant" prise sur le service
avant le push), donc la preuve de bascule repose sur la CONCORDANCE entre
l'epoch `CACHE_VERSION` et la fenetre CI reelle, pas sur une comparaison
avant/apres du service lui-meme. C'est la forme documentee comme suffisante
quand une lecture prealable n'a pas ete prise -- la limite est dite plutot
que masquee, comme la doctrine de ce fichier l'exige.

## LA PIE SE VOIT DEPUIS LE HUB : la vue cutaway n'est ni une scène ni un décor codé, c'est le `.glb` LUI-MÊME (31 août 2026)

Branche `claude/hub-pie-cutaway-view-m5kfyd`, partie de `staging`
(`07f5c77`). Regle n°1 verifiee AU DEBUT et par ARBRE : `origin/main` =
`afa49d7` **INTOUCHE**, `staging..main` VIDE, `main` ancetre de `staging`,
et les deux seules branches plus recentes que `main` sont celles des lots
magpie, deja mergees (`merge-base --is-ancestor` = OK) -- **aucune session
concurrente**.

La pie etait visible **uniquement une fois entre dans la cabane**. Le
plateau montre pourtant deja ce salon en cutaway -- la table, les chaises,
l'ourson, l'echelle -- donc la seule piece du decor qu'un joueur ne
pouvait pas voir avant d'entrer etait precisement celle qui est construite
en CODE. Elle est desormais dessinee dehors aussi, **purement decorative** :
aucun tap, aucun hotspot, aucun rayon, aucune entree dans les tables
publiees. Le bisou reste exclusivement dans `CabinInterior`.

### ⚠️ RECON : LA VUE HUB N'EST NI (a) NI (b) -- et c'est ce qui a decide tout le lot

Le brief posait deux cas : (a) la meme scene vue sous un autre angle, ou
(b) une geometrie hub distincte et simplifiee. **Ni l'un ni l'autre**, et
c'est lu dans les fichiers plutot que deduit des captures :

* Il n'existe **AUCUNE scene `.tscn` de cabane hub** -- `find -iname
  '*cabin*'` ne rend qu'un seul `.tscn`, `scenes/CabinInterior.tscn`.
* `HubBuilder._make_cabin()` instancie `@export cabin_scene`, cable dans
  `scenes/HubWorld.tscn` sur **`res://assets/models/keepy_cabin_decor.glb`**
  -- exactement le `.glb` que `CabinInterior.gd:100` preload.
* **Le mobilier cutaway est BAKE DANS LE `.glb`.** `_make_cabin` ne
  construit rien d'autre qu'un `Node3D` racine autour de l'instance ; le
  `Props` de `CabinInterior.tscn` est vide et son decor est instancie en
  code.

Donc : **UN SEUL asset, DEUX instanciations distinctes, a DEUX ECHELLES
DIFFERENTES** -- `scale: 7.0` dans `hub_layout.tres` contre
`CabinInterior.CABIN_SCALE = 11.0` -- et **aucun lien de code entre les
deux**. La pie n'y etait pas parce qu'elle n'est pas dans le `.glb`.

**Consequence directe** : ajouter la pie est **un node enfant de plus**
sous le root `"Cabin"`, jamais une modification du `.glb` source. Et
puisque la vue hub est une geometrie autonome sans systeme de rendu
partage, sans cutaway genere et sans camera/occlusion a toucher, **le
scope est reste celui annonce** -- pas de STOP, pas de remontee en Opus.

### ⚠️ AUCUN MECANISME DE SYNCHRONISATION HUB <-> CABININTERIOR N'EXISTAIT

Cinquieme point de recon, et il n'a pas de reponse nuancee : le seul etat
qui traverse un changement de scene est **`HubSpawn`** (un `static var`
one-shot qui dit ou reposer Keepy au retour). Aucun autoload, aucun
registre d'apparence, rien qui fasse qu'un objet ait le meme aspect des
deux cotes. **C'est la premiere fois que ce besoin apparait sur ce
projet.**

### LA POSE EST PUBLIEE PAR L'INTERIEUR, JAMAIS RECOPIEE PAR LE HUB

`CabinInterior.magpie_local_pose()` (nouvelle, `static`) rend la position,
l'echelle et le lacet de la pie **en unites MODELE de la cabine** --
c'est-a-dire dans le seul repere que les deux vues partagent. `HubBuilder`
la consomme. **Pas un seul nombre n'est duplique.**

⚠️ **C'est ce qui rend le rapport 7/11 impossible a rater** : une position
monde recopiee serait fausse de ce facteur, et une echelle recopiee
donnerait une pie a la taille de l'interieur dans une cabine plus petite.
La division par `CABIN_SCALE` est faite une fois, la ou la pie est
reellement posee.

Deux helpers purs (`_world_y`, `_yaw_towards`) passent `static` pour que
la fonction puisse les appeler -- aucun comportement change, leurs
appelants non-statiques continuent de marcher.

**Enfant du ROOT, jamais du noeud `.glb`** : `_build` donne au root
l'echelle uniforme et le `rotation_y` de l'entree, donc c'est ce qui fait
qu'une cabine redimensionnee ou tournee **emporte sa pie** au lieu de la
laisser a l'origine, taille pleine. Le `.glb` enfant ne porte que le lift
du modele, et `magpie_local_pose()` inclut deja ce meme lift dans son y :
les deux sont dans un seul repere local.

### VERIFIE, PAS SUPPOSE -- `CabinProbe` PHASE V, 13 checks

Gatee et pas rapportee parce que **tout mode de panne est SILENCIEUX** :
un `magpie_scene` non assigne pousse une erreur et ne dessine rien ; une
pose qui derive de l'interieur la met a travers un mur ou sur la pelouse
a la mauvaise taille, et les deux vues ne sont **jamais a l'ecran
ensemble** pour que quiconque le remarque ; un hotspot ajoute ici rendrait
un tap pres de la cabine ambigu sans la moindre erreur.

⚠️ **L'ACCORD EST MESURE CONTRE LE CORPS QUE L'INTERIEUR CONSTRUIT
REELLEMENT**, jamais contre une seconde copie de l'arithmetique : la phase
instancie `CabinInterior.tscn`, lit son noeud `Magpie` dans l'arbre, puis
exige que la pose locale du hub remontee par `CABIN_SCALE` retombe dessus.

| mesure | resultat |
|---|---|
| position rescalee vs le corps de l'interieur | **0.00000 u** |
| taille | **0.76461 vs 0.76461** |
| lacet | **68.499 vs 68.499 deg** |
| geometrie dessinee | **1 draw node** (le `.glb` porte 1 noeud / 1 mesh / 1 primitive, mesure sur le fichier) |
| dans l'empreinte de la cabine | 0.1292 < 1.2500 |
| au-dessus de sa base | y = 0.3311 |
| **elements tappables poses sur elle** | **0** |
| la cabine publie toujours exactement une porte | OK |

**ROUGE AVANT VERT** : `_furnish_cabin(root)` neutralise -> **exit 1, 1
FAIL** (« a Magpie hangs inside the built cabin »), toutes les lignes de
controle et PHASE UNTOUCHED restant vertes. Fichier restaure
**byte-identique** (`cmp` silencieux) avant de continuer.

### Budget : +1 noeud de dessin, itemise

`_EXPECTED_DRAW_NODES_EXCL_PORTALS` **131 -> 132** dans les trois sondes
qui le portent (`SeesawProbe`, `TurnstileProbe`, `WaterTintProbe`), avec
la raison ecrite a cote plutot que poussee : **un** `MeshInstance3D`,
non batche (il y en a une seule), pure scenerie.

### RENDU REEL, pas seulement des chiffres

`docs/hub-shots/cabin_cutaway_magpie_{near,far}.png` -- la camera LIVREE
du hub, Keepy pose au pas de porte publie puis 7 u en arriere, le
`_process` de la camera coupe pour que le cliche soit la pose visee et non
une frame de son glissement. **La pie se lit nettement au rez-de-chaussee,
a gauche de la table, sa fleur rose visible, tournee vers l'endroit ou
Keepy se tient dans le salon** -- et elle reste identifiable a 7 u de
recul. Le marqueur ambre « Cabane » est intact en dessous.

⚠️ Piege deja consigne, re-paye ici : le `cd build/web` d'une commande
precedente **persiste**, et la premiere sonde a donc tourne avec
`--path .` depuis un dossier sans `project.godot` -- 20 minutes a ne rien
mesurer, sans une seule ligne d'erreur. Chemins absolus depuis.
Second piege du meme run : un `sleep` lance en arriere-plan puis relu
immediatement fait passer 2 minutes pour 25 ; c'est `ps -eo etimes` qui
l'a tranche, exactement comme l'horloge tranche un etat d'API perime.

### PATTERN GENERIQUE : IDENTIFIE, ET DELIBEREMENT PAS CONSTRUIT

Un registre « ces elements de la cabine doivent apparaitre dans les deux
vues » serait le pas suivant naturel -- et il n'est **pas** ecrit ici,
conformement au perimetre. Ce que ce lot laisse a sa place est plus petit
et suffisant pour un second element : `_furnish_cabin(root)` est **le seul
point d'ameublement**, donc un futur objet est une ligne de plus dedans et
une seconde fonction `*_local_pose()` publiee par l'interieur. Le jour ou
il y en aura trois ou quatre, cette fonction devient la boucle sur un
tableau -- et c'est **a ce moment-la** qu'un registre se justifie, pas
avant.

### Validation

Editeur + templates Godot 4.3-stable installes dans ce sandbox (releases
GitHub officielles, **tailles verifiees contre le `Content-Length`** :
**50 276 070** et **1 073 228 327** octets, aucune troncature). Import
headless **exit 0, 37 `.scn`, 0 erreur** apres `rm -rf build .godot`. Boot
de `HubWorld.tscn` et de `CabinInterior.tscn` : **0 erreur, 0
`push_warning`** (le seul stderr est le `Parameter "m" is null` du driver
dummy, deja documente). Export Web release **exit 0, 0 erreur**.

`index.wasm` **35 376 909** octets / md5
**`af4a8fc2925d992348eb30deeeb54360`**, `index.js` md5
**`4e08904b1b7107858246af44b602067b`** -- identiques au fingerprint
permanent de tout lot qui ne touche pas le code moteur. `index.pck`
34 351 200, **marqueur et jamais preuve d'identite**. **Piege payload
tenu** : sur **270** lignes `Storing File`, **0** pour `scripts/dev`,
`assets_source`, `docs`, `web/`, `build` ou `firebase.json` -- et les
captures ajoutees sous `docs/hub-shots/` ne coutent donc rien.

**Sondes, TOUTES exit 0 / 0 failure** : `CabinProbe` (PHASE V comprise),
`SeesawProbe`, `TurnstileProbe`, `WaterTintProbe` (les trois a **132**
draw nodes), `LevelNavProbe` (**77 checks**), `DivingBoardProbe`,
`OwlFlightProbe`, `LakeZoneProbe`, `StreamRideProbe` (**37 checks**),
`WaterImpactProbe`, `AssetContractAudit` (**12/12 visuels, pas un
collider deplace**), `DeathModelAudit`, `ChargerShapeProbe`,
`ProbeTimeoutAudit` (**59 sondes scenes**, retour exact a la baseline
apres suppression de la sonde de capture jetable).

### Reste ouvert -- jugement device, seul juge

1. **Est-ce que voir la pie avant d'entrer se lit comme « il y a quelqu'un
   dedans »**, a l'echelle reelle d'un telephone ? Les captures sont du
   llvmpipe sous `xvfb` via le backend `opengl3` de BUREAU, contre WebGL2
   sous Safari -- rien ici n'est un rendu device.
2. **Sa taille dans le cutaway** : 7/11 de sa taille d'interieur, mesuree
   et coherente par construction, jamais jugee a l'oeil de loin.
3. Elle est **statique** : la doctrine bake-once tient, aucune animation
   n'est demandee dehors et le `.glb` n'a de toute facon ni squelette ni
   animation.

### Deploiement staging de la pie en vue cutaway (palier 1, automatique)

`staging` **`3fa5d91`** (merge `--no-ff`, arbre **byte-identique** a la branche
feature : meme hash d'arbre `62a86e4b` des deux cotes ET `git diff` vide,
verifie AVANT le push). CI run **#340** (id 33400628473) **verte** --
`Import project resources` 14:06:27 -> 14:10:02, **`Export Web build`
14:10:02 -> 14:10:08**, `Verify export output` succes, `Deploy to Vercel
[STAGING -- staging]` **succes** 14:10:23 -> 14:10:36, `[PRODUCTION -- main]`
correctement **skipped**. **`main` NON touche** (`origin/main` toujours
`afa49d7`, verifie apres le push).

**Verifie SUR LE SERVICE, pas dans le log CI, sur DEUX marqueurs independants
-- et pour une fois les QUATRE lectures sont `x-vercel-cache: MISS` avec
`age: 0`**, les valeurs d'avant ayant ete relevees AVANT le merge : c'est la
forme la plus forte que ce fichier documente, et non le cas habituel ou le
« avant » sort d'un `HIT` a age non nul.

| marqueur | avant (run #339) | apres (ce lot, run #340) |
|---|---|---|
| `CACHE_VERSION` | `1788180347` = **12:45:47 UTC** | **`1788185407` = 14:10:07 UTC** |
| `index.pck` servi | **34 349 984** | **34 351 248** |
| `index.wasm` servi | 35 376 909 | **35 376 909** *(inchange, attendu)* |

L'epoch d'apres tombe **a l'interieur de la fenetre `Export Web build`**
(14:10:02 -> 14:10:08) : l'alias sert bien ce build.

⚠️ **`index.pck` prend une valeur de plus pour le meme contenu** : 34 351 200
a l'export local propre contre 34 351 248 servi, **48 octets d'ecart**. Enieme
illustration de l'instabilite deja consignee -- marqueur « nouveau build »,
**jamais** preuve d'identite. `index.wasm` (**35 376 909**, md5
`af4a8fc2925d992348eb30deeeb54360`) est identique des deux cotes et c'est lui
la preuve d'identite, coherent avec un lot qui n'ajoute qu'une instance de
`.glb` deja packe et trois fichiers GDScript.

⚠️ **L'API GitHub Actions n'etait PAS perimee sur ce run**, note dans ce
sens-la : les appels successifs ont rendu de vraies progressions d'etapes avec
de vrais horodatages, et l'import a reellement pris **3 min 35 s**. Le piege
existe ; il ne s'est pas produit ici, et le verifier coute un regard a
l'horloge -- ce qui a d'ailleurs servi une fois de plus dans l'autre sens, la
lecture au niveau du RUN restant figee a `updated_at 14:05:48` pendant que
celle au niveau des JOBS montrait l'import en cours depuis 14:06:27.

## LA PIE VUE DU HUB, LE PANNEAU « SORTIR » DEGAGE DU BAISER (31 aout 2026)

Branche `claude/pie-visibility-exit-label-5t6drt`, partie de `staging`
(`266a10e`). Deux retours device independants sur le lot magpie precedent,
traites en deux corrections distinctes dans les memes fichiers -- aucune des
deux ne touche `magpie_local_pose()` (la source de verite de l'interieur) ni
`LevelHotspot` (le tap/snap de la porte).

### RECON PREALABLE, OBLIGATOIRE AVANT TOUT CODE -- `LevelHotspot` EST DEJA DECOUPLE

Verifie avant d'ecrire une ligne, comme la consigne du lot l'exigeait :
`scripts/nav/LevelHotspot.gd` ne porte que `point` (utilise IDENTIQUEMENT pour
accepter un tap et pour la destination du snap) et `label` (du TEXTE, jamais
une position). Le rendu visuel (anneau/pad/position du label) vit entierement
dans `CabinMarker`, une classe separee. **Le probleme de position du panneau
« Sortir » n'est donc PAS un couplage `LevelHotspot`** -- la porte a satisfait
la condition explicite pour continuer sans escalader.

### PARTIE A -- LA PIE DANS LE HUB : MESUREE, PAS ESTIMEE, A TRAVERS LA VRAIE CAMERA

Sonde jetable (`HubPieSizeReconProbe.gd`, supprimee avant commit) instanciant
`HubWorld.tscn`, `HubCamera.snap_to_target()` pour une mesure DETERMINISTE
(la camera suit Keepy par un lerp exponentiel en jeu normal, inutilisable pour
mesurer). Keepy pose EXACTEMENT a la position de layout de la cabane
(`-17.43, 0, 28.18`), la distance camera-sujet la plus favorable possible.

| | hauteur monde | pixels (1080x1920) |
|---|---|---|
| **Keepy, sa propre AABB** | 1.3501 | **123.89 px** |
| **la pie, AVANT** | 0.8591 | **96.06 px -- 77,5 % de Keepy** |

**Cause : `_furnish_cabin()` recevait le modele deja construit par
`magpie_local_pose()`, dont `pose["scale"]` divise deliberement
`MAGPIE_SCALE` par `CabinInterior.CABIN_SCALE` (11.0) -- necessaire pour tenir
dans le cadre FIXE de l'interieur, mais le hub applique ENSUITE, en externe,
le `scale` de layout propre a CETTE entree cabane (7.0) sur tout le noeud
racine.** Les deux divisions se cumulent : la pie retrecit deux fois, une
fois pour l'interieur, une fois pour le hub.

**Fix : `_furnish_cabin(root, cabin_uniform)` re-derive `cabin_uniform`
depuis `layout.props[index]` (pas encore en scope au moment ou `_build()`
applique son propre `scale` externe, donc lu directement dans la donnee) et
DIVISE `bird.scale` par lui** :

```gdscript
bird.scale = Vector3.ONE * (CabinInterior.MAGPIE_SCALE / maxf(cabin_uniform, 0.0001))
```

Le `cabin_uniform` de `_furnish_cabin` et celui que `_build()` applique
ensuite au noeud racine s'ANNULENT exactement -- ce qui reste, net, est
`MAGPIE_SCALE` elle-meme : sa hauteur d'interieur, intacte, quelle que soit la
petitesse avec laquelle le hub dessine cette cabane. **`_build()` publie
desormais `_last_cabin["uniform"] = uniform`** (meme discipline que les 214
autres entrees de ce depot : un fait calcule une fois est publie, jamais
recalcule ailleurs), pour qu'un futur lecteur -- dont la sonde -- puisse
recuperer l'echelle nette sans reparser le layout.

**RE-MESURE sur le resultat construit, meme sonde, meme camera** :

| | hauteur monde | pixels |
|---|---|---|
| **la pie, APRES** | **1.3501** (= `MAGPIE_SCALE`, au 5e chiffre) | **151.09 px** |

⚠️ **151.09 px est PLUS GRAND que les 123.89 px de Keepy, pas seulement
proche -- et c'est accepte, pas cache.** La position locale de la pie a
l'interieur de la cabane la place un peu plus pres de la camera, sur son
propre axe de profondeur, que le point exact ou Keepy se tenait pour sa
propre mesure de reference -- et une correction d'ECHELLE ne peut pas
corriger un ecart de PROFONDEUR. Une pie qui se lit aussi grande ou
legerement plus grande que Keepy depuis le plateau est l'echec LISIBLE ;
les 96,06 px d'origine etaient l'echec ILLISIBLE.

⚠️ **Divergence physique assumee, documentee dans le code plutot que dans
un commentaire externe** : la pie devient, PAR RAPPORT A CETTE CABANE, plus
haute que ce qu'elle est par rapport a la cabane vue de l'interieur. La
legibilite depuis la distance est le seul travail de cette copie d'elle ;
`magpie_local_pose()`, la source des proportions de l'interieur, n'est
JAMAIS touchee pour l'obtenir.

### PARTIE B -- LE PANNEAU « SORTIR » RECOUVRAIT LA ZONE DU BAISER

Retour device, capture a l'appui : depuis la camera fixe de l'interieur,
« Sortir » se lit par-dessus le baiser. Sonde jetable
(`PieMarkerReconProbe.gd`, supprimee avant commit) mesurant les VRAIS
marqueurs construits (`_door_marker`, `_magpie_marker`) via
`Camera3D.unproject_position()`/`is_position_in_frustum()`, et l'etendue
d'un `Label3D` en BILLBOARD projetee le long du vecteur DROITE de la camera
(jamais l'axe local +X non tourne, que le shader de billboard ignore au
rendu) :

| | AVANT |
|---|---|
| anneaux porte/pie, degagement | **22,91 px** -- deja tres serre |
| bord du LABEL « Sortir » au point de baiser (`MAGPIE_STAND_SPOT`) | **40,90 px** |
| pulse de la porte au point de baiser | **DECLENCHE** (1,098 contre un seuil de 1,870) -- « Sortir » grossit PENDANT le baiser |

**Fix : un `label_offset: Vector3` optionnel sur `CabinMarker.setup()`
(defaut `Vector3.ZERO`, donc chaque appelant existant -- y compris le
marqueur du hub, `HubWorld.gd`, 3 arguments positionnels -- reste
inchange), applique UNIQUEMENT a la position du `Label3D`** :

```gdscript
_label.position = Vector3(0.0, ring_lift
		+ (HUB_LABEL_HEIGHT if hub else CABIN_LABEL_HEIGHT), 0.0) \
		+ label_offset
```

`_pad` et `_ring` restent exactement sur l'origine du noeud -- l'invariant
« un marqueur ne peut jamais etre dessine plus petit que ce qu'il marque »
porte sur l'ANNEAU, pas sur le panneau qui flotte au-dessus. Cote
`CabinInterior.gd` : **`DOOR_LABEL_OFFSET := Vector3(0.60, 0.0, 0.0)`**,
poussant le PANNEAU SEUL vers le mur, loin du cote pie de la piece --
`_add_marker(DOOR_TAP_RADIUS, "Sortir", DOOR_LABEL_OFFSET)`.
`LevelHotspot.point` (le tap et la destination du snap) et l'anneau/pad du
marqueur de porte restent **exactement** sur `DOOR_SPOT`, inchanges.

**RE-MESURE, meme sonde** :

| | APRES |
|---|---|
| bord du label « Sortir » au point de baiser | **103,89 px** -- plus du double, **jamais** ne recroise le centre de l'anneau de porte |

### ⚠️ REGRESSION TROUVEE PAR `CabinProbe`, CORRIGEE PAR LA DOCTRINE ROUGE-AVANT-VERT

La PHASE V existante assertait l'ANCIENNE relation
(`bird.scale.x * CabinInterior.CABIN_SCALE == inside.scale.x`) -- une
invariante que ce lot casse DELIBEREMENT. **Ce n'etait pas un bug de ce
lot : c'etait une hypothese de test perimee par un changement de conception
volontaire.** Reecrite pour asserter la NOUVELLE invariante --
`bird.scale.x * cabin_uniform == CabinInterior.MAGPIE_SCALE`, en lisant le
`uniform` desormais publie par `_last_cabin` plutot que de le redemander au
layout -- avec un commentaire expliquant pourquoi l'ancienne ne s'applique
plus. Position et lacet continuent de passer par `magpie_local_pose()` sans
modification et restent assertes tels quels.

### Validation

Editeur + templates Godot 4.3-stable installes dans ce sandbox (releases
GitHub officielles, tailles verifiees contre le `Content-Length` -- **50 276 070**
et **1 073 228 327** octets, aucune troncature). `rm -rf build .godot` avant
tout. Import headless **exit 0, 37 `.scn`, 0 erreur**. Export Web release
**exit 0**, `index.wasm` **35 376 909** octets / md5
**`af4a8fc2925d992348eb30deeeb54360`**, `index.js` md5
**`4e08904b1b7107858246af44b602067b`** -- identiques au fingerprint permanent
de tout lot qui ne touche pas le code moteur, coherent : deux formules et un
parametre optionnel dans quatre fichiers GDScript. **Piege payload tenu** :
**0** ligne `Storing File` pour `scripts/dev`, `assets_source`, `docs`,
`web/`, `build` ou `firebase.json`.

**Sondes, toutes exit 0** : `CabinProbe` (**256 OK, 0 echec**, PHASE V
reecrite comprise ; PHASE Z, PHASE K et PHASE N -- porte, snap, baiser --
inchangees et vertes), `ProbeTimeoutAudit` (**59 sondes scenes**, retour
exact a la baseline apres suppression des deux sondes jetables),
`AssetContractAudit` (12/12 visuels, **0/10 colliders deplaces**),
`DeathModelAudit`, `ChargerShapeProbe`, `TurnstileProbe`, `WaterTintProbe`,
`SeesawProbe` (**0 echec** avec `--fixed-fps 60` -- sans ce flag son banc de
traversee tourne a la vitesse du mur sous llvmpipe et rapporte un faux
echec, piege d'ordre des flags deja consigne dans ce fichier).

**Budget de noeuds de dessin INCHANGE** (132 hors portails, confirme par
`SeesawProbe`/`TurnstileProbe`/`WaterTintProbe`) : ce lot ne touche qu'une
formule d'echelle et une position de `Label3D`, aucune geometrie neuve.

### Reste ouvert -- jugement device, seul juge

1. **La taille de la pie dans le hub** (151,09 px, plus grande que Keepy) --
   mesuree, coherente par construction, jamais jugee a l'oeil sur un
   telephone.
2. **La lisibilite du baiser sans le panneau dessus** -- 103,89 px de
   degagement mesures, jamais vus en mouvement sur device.
3. Rien ici n'est un rendu device : llvmpipe sous `xvfb` via le backend
   `opengl3` de BUREAU, contre WebGL2 sous Safari.

`main` **non touche**. Merge sur `staging` : palier 1, automatique (build,
import, export et sondes verts).

### Deploiement staging de la pie lisible + panneau degage (palier 1, automatique)

`staging` **`bbe9f95`** (merge `--no-ff` de `78e771a` sur `266a10e`, arbre
**byte-identique** a la branche feature -- `git diff HEAD 78e771a` vide,
verifie AVANT le push). CI run **#342** (id 33411372548) **verte**
(15:57:19 -> 16:02:21 UTC), `Deploy to Vercel [STAGING -- staging]` succes,
`[PRODUCTION -- main]` correctement **skipped**. **`main` NON touche**
(`origin/main` toujours `afa49d7`, verifie apres le push) : palier 2, gate
Mathieu apres validation device.

**Verifie SUR LE SERVICE, pas dans le log CI seul, sur DEUX marqueurs
independants** :

| marqueur | apres (ce lot, run #342) |
|---|---|
| `CACHE_VERSION` | **`1788192102` = 16:01:42 UTC** |
| `index.pck` servi | 34 351 520 |
| `index.wasm` servi | **35 376 909** |

L'epoch `CACHE_VERSION` servi tombe **a l'interieur de la fenetre
d'execution du run #342** (15:57:19 -> 16:02:21 UTC), et **les deux lectures
(`index.service.worker.js` et `index.html`) portent `x-vercel-cache: MISS`
avec `age: 0`**, `date` colle a l'instant de la requete -- pas une reponse
de cache. `index.wasm` servi est **identique au bit pres a l'export local**
(md5 `af4a8fc2925d992348eb30deeeb54360`) -- c'est lui la preuve d'identite,
coherent avec un lot qui ne touche qu'une formule d'echelle et une position
de `Label3D`, aucun code moteur.

⚠️ **Limite dite plutot que sous-entendue** : aucune lecture "avant" fraiche
n'a ete prise sur le service avant ce push -- la comparaison "avant" est
corroboree par l'horodatage de completion du run precedent (#341,
`updated_at 2026-08-31T14:17:39Z`), pas par une seconde paire MISS/age 0.
Ce n'est pas la forme la plus forte que ce fichier documente ailleurs (deux
marqueurs lus aux deux bouts en MISS/age 0), mais la lecture APRES seule,
deja au niveau de preuve le plus haut, suffit a etablir que ce build precis
est bien celui servi.

**Reste ouvert : la validation device de Mathieu**, seule juge, sur les deux
points ci-dessus (taille de la pie dans le hub, lisibilite du baiser sans le
panneau dessus) -- avant tout merge vers `main`.

## LE BAISER SE VOIT ENFIN, LA SORTIE QUITTE LE COIN DU BAISER (31 aout 2026)

Branche `claude/cabin-kiss-exit-geometry-qig3fp`, partie de `staging`
(`45b1140` -- le lot pie-visibility-exit-label deja dessus). Deux retours
device traites ensemble, parce que les deux touchent la meme piece :
pendant le baiser, Keepy et la pie se chevauchaient a l'ecran (tete de la
pie invisible au pic de la pose) ; et le point de sortie ("Sortir")
partageait le meme coin de la piece que le baiser, si bien qu'un tap pres
de la pie pouvait resoudre en sortie.

### PARTIE A -- `MAGPIE_STAND_SPOT` ETAIT CALIBRE POUR L'ANCIENNE ECHELLE DE LA PIE

**Cause racine, mesuree et pas devinee.** `MAGPIE_STAND_SPOT` avait ete fixe
a `(0.05, 0.40)` -- 1,254 u de `MAGPIE_SPOT` -- au moment ou `MAGPIE_SCALE`
valait 0,50. Un lot ulterieur a monte `MAGPIE_SCALE` a 0,76461 pour aligner
la hauteur dessinee de la pie sur celle de Keepy, sa demi-profondeur a
grandi avec elle, et **personne n'a re-derive la distance de pose** -- le
commentaire du fichier lui-meme le nommait deja comme un risque ouvert :
"whether the bigger bird's resting contact still reads as a kiss and not
an already-buried muzzle is open." Le device a confirme que non : il
enterrait sa tete au repos.

**Mesure sur les vraies transforms** (sonde jetable construisant
`_build_magpie()`/`_enter_kiss()`/`_apply_kiss()` a l'identique, jamais un
fixture separe) -- overlap XZ des deux AABB comme fraction de l'empreinte
de la pie, echantillonne sur TOUTE la bell curve du lean et pas seulement
au pic :

| position | REPOS | PIC (mi-lean) |
|---|---|---|
| **livree, (0.05, 0.40)** | 41,7 % de sa silhouette deja recouverte | **62,7 %** -- sa tete avait disparu |
| **corrigee, (1.00, 0.40)** | **0,0 %** (deux corps distincts au repos) | **10,6 %** -- un contact court pendant le geste, rien avant ni apres |

**Le fix se deplace en +X et pas en +Z, et ce n'est pas arbitraire.** Le
commentaire de `MAGPIE_SPOT` explique deja que X est l'axe utilise pour que
les deux corps ne se cachent pas l'un l'autre sur la camera fixe ("offset
in x, so he cannot hide her"), alors que Z est l'axe de PROFONDEUR de la
camera, deja calibre pour que la pie reste plus pres de l'objectif que
Keepy. Verifie par balayage : deplacer en X reduit l'overlap bien plus vite
par unite de distance que Z, ET garde son angle de face dans le
trois-quarts flatteur voulu par le design d'origine (yaw 58,4 deg a la
position choisie, contre 13-23 deg pour des candidats qui poussaient en Z a
overlap egal). Z reste a 0,40, inchange -- l'ordonnancement pres/loin contre
la camera reste exactement celui deja argumente par `MAGPIE_SPOT`.

**`MAGPIE_STAND_SPOT` passe de `(0.05, 0.40)` a `(1.00, 0.40)`.** Toujours
degage du trou d'empreinte (2,159 contre un rayon de 0,73, marge 1,429 --
contre 0,524 avant) et desormais degage du nouveau `DOOR_SPOT` (partie B)
par 1,226 contre 1,05 minimum.

### PARTIE B -- `DOOR_SPOT` ETAIT `ENTRY_SPOT`, DANS LE MEME COIN QUE LE BAISER

**Decision explicite de Mathieu** : deplacer le hotspot `&"door"`
lui-meme (tap ET destination de snap), pas seulement son label -- le
`DOOR_LABEL_OFFSET` d'un lot precedent etait un correctif cosmetique sur
le mauvais cote du meme coin, et devient sans objet une fois le coin
lui-meme deplace.

**Recon confirmee** : `DOOR_SPOT`/`DOOR_TAP_RADIUS` sont une coordonnee et
un rayon isoles, ni derives ni couples a la camera. Le hotspot
`&"mezzanine"` (le lien de l'echelle, un `LevelTransition`) existe bien pres
de la base de l'echelle et devait etre evite explicitement.

**Candidat retenu, verifie sur les VRAIES classes moteur** (sonde jetable
construisant `LevelDefinition`/`LevelHotspot`/`LevelTransition` reelles,
jamais une geometrie recalculee a la main) : `DOOR_SPOT = (2.20, 0.65)`.
Deux candidats plus proches de l'echelle, `(2.05, 0.35)` et `(1.90, 0.45)`,
**echouent reellement** le test de degagement contre le disque de tap du
lien de l'echelle (gap 1,800 et 1,906 contre un radii-sum requis de 1,950)
-- `(2.20, 0.65)` est pres du plancher reel de ce qui est atteignable, pas
un compromis choisi a l'oeil. Verifie : dans le carre praticable, degage du
lien de l'echelle (+0,155), hors de portee du carre de la mezzanine
(1,999 contre `DOOR_REACH` 0,9), degage du hotspot et du trou de la pie
(3,309), et desormais degage du `MAGPIE_STAND_SPOT` reloge (1,226 contre
1,05).

**`DOOR_LABEL_OFFSET` est retire**, confirme redondant : son seul site
d'appel non-defaut disparait, le marqueur reprend l'offset zero par
defaut -- deux corrections superposees sur le meme symptome auraient ete
la mauvaise reponse.

### ⚠️ PHASE Z ETAIT CALIBREE SUR UNE GEOMETRIE QUI N'EXISTE PLUS, ET LE DEFAUT QU'ELLE GATE RESTE REEL

`DOOR_SPOT` etait `ENTRY_SPOT` : Keepy y arrivait a chaque visite, distance
0,000, et le bug "zero-length walk" (`LevelWalker._advance()` termine une
marche plus courte qu'`ARRIVE_EPSILON` par `became_idle`, jamais
`hop_landed` -- donc un tap sur la porte en se tenant deja dessus ne
faisait rien et laissait `_exit_pending` arme) etait vivant des le premier
tap de chaque session. Deplacer la porte fait qu'une arrivee fraiche
demarre desormais une vraie marche loin d'elle -- **mais le meme etat se
reproduit exactement des qu'il atteint reellement le pas de porte** (en y
marchant, ou en l'ayant deja tape une fois). PHASE Z reproduit donc ce cas
en **placant** Keepy sur le point plutot qu'en se fiant a l'endroit ou la
scene le fait naitre -- pilotee sur la scene que le VRAI routeur vient de
charger, pas sur une instance fraiche.

**Verifiee rouge avant vert, deux fois** : la neutralisation du
repositionnement dans la sonde reproduit `1,746 <= 0,450 -> FAIL` sur la
CONTROLE (le walker naissant a `ENTRY_SPOT` est desormais a 1,746 u du
`DOOR_SPOT` reloge, largement hors de `DOOR_TAP_RADIUS` et
`ARRIVE_EPSILON`) et cascade sur les trois assertions suivantes -- prouvant
que le repositionnement est porteur et pas incident. Restaure, 0 echec.

**Un troisieme defaut, non anticipe par le brief, trouve par la sonde
elle-meme** : le point d'approche de PHASE N ("stops SHORT of the spot")
etait un litteral fige, calibre par sa distance exacte a l'ANCIEN
`MAGPIE_STAND_SPOT`. Une fois la pose relogee, il ne produisait plus
l'arret-court attendu (`without = 0,000` au lieu de `> 0,01`). Recalcule
en X pur depuis le nouveau point de pose, magnitude
`HOP_DISTANCE + 0.40 = 1.90`, reproduisant le meme mecanisme "un hop
plein puis 0,40 de reste sous `ARRIVE_EPSILON`".

**Une nouvelle assertion GATEE, permanente, ajoutee a PHASE N** pour que
le bug de la partie A ne puisse plus regresser en silence : overlap
maximal mesure sur toute la sweep du lean, seuil `< 25 %` (largement
au-dessus des 10,6 % mesures, largement en-dessous des 62,7 % d'avant).

### Validation

Editeur + templates Godot 4.3-stable **re-installes dans ce sandbox** :
le `.tpz` d'export templates a d'abord ete tronque en silence
(517 025 792 octets contre les 1 073 228 327 du `Content-Length` reel,
piege deja documente cinq fois dans ce fichier), retelecharge en entier et
verifie taille-exacte avant extraction. Import headless **exit 0, 37
`.scn`, 0 erreur**. Export Web release **exit 0, 0 erreur GDScript**.
`index.wasm` **35 376 909** octets / md5
**`af4a8fc2925d992348eb30deeeb54360`**, `index.js` md5
**`4e08904b1b7107858246af44b602067b`** -- identiques au fingerprint
permanent deja consigne pour tout lot qui ne touche pas le code moteur.
**Piege payload tenu** : sur **270** lignes `Storing File`, **0** pour
`scripts/dev`, `assets_source`, `docs`, `web/`, `build` ou
`firebase.json` ; `CabinInterior.gdc` est bien packe.

**`CabinProbe` : 256 checks, 0 echec, exit 0.** Rouge-avant-vert verifie
sur les DEUX fixes de ce lot (l'assertion d'overlap contre l'ancien
`MAGPIE_STAND_SPOT`, la CONTROLE de PHASE Z contre le repositionnement
neutralise) plus un troisieme defaut trouve en chemin (le litteral
d'approche de PHASE N).

### Reste ouvert -- jugement device, seul juge

1. **La tete de la pie reste-t-elle visible pendant tout le baiser** a
   l'echelle reelle d'un telephone ? La mesure dit 10,6 % d'overlap
   maximal contre 62,7 % avant ; la lecture ne l'est pas.
2. **Le bouton "Sortir" se trouve-t-il bien pres de la base de
   l'echelle**, loin de toute confusion avec le baiser ?
3. **La sortie fonctionne-t-elle toujours** depuis ce nouveau point --
   tap sur la porte, sortie immediate.
4. Rien ici n'est un rendu device : llvmpipe sous `xvfb` via le backend
   `opengl3` de BUREAU, contre WebGL2 sous Safari.

### Deploiement staging verifie sur le service (31 aout 2026)

CI run #344 (id 33426250910) sur `staging` `5f6b94f`, **verte** :
`Import project resources` 18:41:05 -> 18:44:40, `Export Web build`
18:44:40 -> 18:44:45, `Deploy to Vercel [STAGING]` **succes** 18:45:02 ->
18:45:16, `[PRODUCTION -- main]` correctement **skipped** (push sur
`staging`).

**Verifie SUR LE SERVICE, pas dans le log CI seul, sur DEUX marqueurs
independants, aux deux lus fraiches** :

| marqueur | valeur |
|---|---|
| `CACHE_VERSION` | **`1788201885` = 18:44:45 UTC** -- tombe exactement sur la fermeture de l'etape `Export Web build` |
| `index.wasm` servi | **35 376 909** octets -- identique au bit pres a l'export local, le fingerprint permanent |
| `index.pck` servi | 34 351 568 (marqueur, jamais preuve d'identite) |

Les deux lectures (`index.service.worker.js` et `index.html`) portent
`x-vercel-cache: MISS` avec `age: 0`, `date` colle a l'instant de la
requete -- pas une reponse de cache.

`main` **non touche** (`origin/main = afa49d7`, verifie apres le push).
Merge staging automatique, comme le veut la regle du palier 1 -- pas de
merge vers `main` sans validation device explicite de Mathieu.

## LE BAISER RECALIBRE UNE SECONDE FOIS, LA PORTE QUITTE LE PIED DE L'ECHELLE POUR "ENTRE LA TABLE ET L'ESCALIER" (31 aout 2026)

Branche `claude/keepy-kiss-exit-calibration-i4fsfj`, partie de `staging`
(`fe0b0f8`, la ref exacte du lot precedent). Regle n1 verifiee AU DEBUT ET A
LA FIN : `git fetch --all --prune`, comparaison par ARBRE et pas par nom --
`HEAD == origin/staging == fe0b0f8` aux deux bouts de la session,
`origin/main` (`afa49d7`) **strict ancetre** de `origin/staging`, **aucune
session concurrente**. Deux retours device sur le lot precedent, traites
ensemble parce qu'ils touchent le meme fichier et se recoupent
geometriquement -- deplacer l'un sans mesurer l'autre aurait pu rouvrir un
chevauchement deja ferme.

### ⚠️ REGLE D'ESCALADE : LE COUPLAGE EST REEL, MAIS LA MARGE AUSSI -- reste sur ce modele

La consigne posait un test explicite : si le deplacement de `DOOR_SPOT`
s'avere un simple changement de coordonnee, continuer sur ce modele ; si un
vrai couplage geometrique apparait (zone non calibree, chevauchement avec un
hotspot, dependance a la camera), **STOP et rapport avant tout code**.

**Le couplage est reel** -- une recherche naive echoue completement, voir
Partie B -- **mais la marge trouvee par balayage exhaustif est large et
verifiee contre les vrais objets `LevelDefinition`/`LevelHotspot`/
`LevelTransition` du fichier**, pas approximee. La consigne dit de rester
sur ce modele des lors qu'une region legale bien margee existe, meme si le
premier essai naif echoue -- c'est le cas ici, donc **pas d'escalade**.

### PARTIE A -- LE BAISER, RECALIBRE UNE SECONDE FOIS, DANS L'AUTRE SENS

Le lot precedent avait ferme un vrai bug (tete de la pie enterree, overlap
mesure a 62,7 %) en deplacant `MAGPIE_STAND_SPOT` a `(1,00 ; 0,40)`, overlap
ramene a 10,6 %. **Retour device : surcorrige** -- a l'ecran les deux
personnages se lisent comme "cote a cote", pas comme un baiser.

**Pas un nouveau reglage a l'oeil : la meme sonde jetable qui avait trouve
1,00 a ete rejouee sur TOUTE la bande legale vers elle**, x de 0,95 a 0,10
par pas fins, mesurant REST et PEAK a chaque position
(`KissDistanceSweep.gd`, jetable, supprimee avant ce commit). La bande est
**monotone** et porte **UN SEUL mur dur** : le seuil de regression de 25 %
que ce meme fichier gate deja depuis le lot precedent est franchi entre
`x = 0,70` (24,6 %, encore 0,4 point de marge) et `x = 0,65` (27,0 %, deja
au-dessus). "Plus pres" n'est donc pas gratuit indefiniment -- gratuit
jusqu'a ce mur, precisement.

**`x = 0,80` retenu -- pas le milieu arithmetique des deux extremes** (qui
serait pres de 0,53, loin dans le mur a ~33 % d'overlap projete), mais le
point donnant **environ le double du contact livre** -- REST 4,8 %, PEAK
19,8 % (mesure et gate par `CabinProbe` : *"her head stays clear of him at
the worst of it (19.8% of her own footprint, want < 25%)"*) contre REST
0,0 %, PEAK 10,6 % livres -- avec **5,2 points de marge** sous le plafond de
25 %, confortablement au-dessus du bruit habituel de mesure/animation
plutot que pose sur le mur.

**Toujours degage du trou de son empreinte, asserte plutot que laisse en
coincidence non verifiee** : 1,965 depuis `MAGPIE_STAND_SPOT` (etait 2,159)
contre un `MAGPIE_FOOTPRINT_RADIUS` de 0,73, marge **1,235** (etait 1,429) --
`CabinProbe` : *"and clears her footprint hole by 1.235 (radius 0.73, want
~1.235)"*.

**Et degage de la porte RELOGEE dans ce meme lot** (voir Partie B) par
**1,208** contre un `DOOR_TAP_RADIUS` + marge de 1,05 -- plus proche de ce
cercle qu'avant (etait 1,226), parce que les deux hotspots se sont
eloignes l'un de l'autre dans le meme lot precisement pour que cette marge
reste reelle.

Le mouvement est fait le long de **X, pas Z**, pour la meme raison que le
lot precedent l'avait deja etabli : X est l'axe que ce design utilise pour
que les deux corps ne se cachent pas l'un l'autre sur la camera fixe (elle
est decalee en X, donc "elle ne peut pas le cacher"), tandis que Z est
l'axe de PROFONDEUR de la camera, deja calibre pour qu'elle reste plus pres
de l'objectif que lui -- deplacer Z aurait remis en jeu cet ordre.

### PARTIE B -- LA PORTE QUITTE LE PIED DE L'ECHELLE, SUR UNE CLARIFICATION QUI REMPLACE LA PRECEDENTE

**Clarification explicite de Mathieu, qui fait foi sur toute formulation
anterieure** : "entre la table basse et l'escalier", pas "en bas de
l'echelle" comme discute avant cette clarification.

Le lot precedent avait pose `DOOR_SPOT` a `(2,20 ; 0,65)`, choisi comme le
point le plus proche de l'echelle qui franchissait toutes les portes de
degagement -- correct par construction, mais device l'a lu comme "au pied
de l'echelle", ce que la nouvelle clarification ecarte explicitement.

⚠️ **UNE RECHERCHE NAIVE DU MILIEU GEOMETRIQUE DE LA PIECE ECHOUE
COMPLETEMENT, MESURE ET PAS SUPPOSE.** Le disque d'exclusion du lien
echelle lui-meme (rayon 1,950 autour de `LADDER_FOOT`) est grand par
rapport a cette piece, donc chaque candidat qu'une recherche a l'oeil
essaierait en premier -- x dans [1,20 ; 1,80] a la profondeur a mi-chemin
entre la table et l'echelle -- revient **FAIL** sur cette seule porte
(meilleur cas mesure : 1,946 contre les 1,950 requis). **La vraie frontiere
legale a ete cartographiee par balayage exhaustif plutot que devinee**
(`DoorRelocateSweep.gd`, jetable, supprimee avant ce commit), et
`(1,30 ; 1,50)` est retenu sur le cote "table" de cette frontiere.

**Verifie contre les VRAIS objets `LevelDefinition`/`LevelHotspot`/
`LevelTransition` que ce fichier construit lui-meme -- jamais une geometrie
de cercle/rectangle recopiee a la main :**

| garde | mesure |
|---|---|
| gap au disque de tap du lien echelle | **3,044** contre une somme de rayons 1,950 (+1,094 -- plus que la marge de +0,155 de l'ancien point) |
| dans le carre du sol | `LevelDefinition.contains() = true` |
| loft ne peut pas l'atteindre | point le plus proche du loft a **1,941** contre `DOOR_REACH = 0,9` |
| degage du cercle de la pie et de son trou d'empreinte | **2,474** contre un minimum de 1,45 |
| degage du `MAGPIE_STAND_SPOT` reloge (Partie A) | **1,208** contre un minimum de 1,05 |
| degage du cercle du lit sur le loft | **4,096** contre un minimum de 1,55 (jamais proche, verifie quand meme) |

**La position choisie est mesuree, pas devinee, a travers la VRAIE camera
fixe** (`unproject_position`, execute **SANS `--headless`** -- sous
`--headless` le viewport rapporte une taille fausse pour cet appel exact,
piege deja documente dans ce projet) : la table (`ENTRY_SPOT`) projette a
**x = 52,8 %** de l'ecran, le pied de l'echelle a **x = 63,7 %**. Le
nouveau `DOOR_SPOT` projette a **x = 59,5 %**, proche du milieu des deux
(58,25 %) et visiblement DANS cette bande plutot que colle a l'un des deux
bords.

**`DOOR_LABEL_OFFSET` : confirme deja retire par le lot precedent, rien a
retirer ici.**

### ⚠️ PHASE Z RE-EVALUEE : PAS DE REGRESSION, LA MARGE RESTE LARGE

La sortie immediate depuis le pas de porte (le defaut "zero-length walk"
deja documente et corrige au lot precedent) reste couverte par la meme
`PHASE Z` -- **aucun changement de mecanisme n'etait necessaire**, seul le
commentaire de `_try_exit()` est mis a jour (1,583 -> **1,941**, la
nouvelle distance du loft le plus proche a la porte relogee). La marge au
seuil de declenchement (`DOOR_REACH = 0,9`) est plus large qu'avant, pas
plus serree.

### ⚠️ DEUX PASSAGES ROUGE-AVANT-VERT, PLUS UN TROISIEME LITTERAL RE-DERIVE ET VERIFIE NE PAS ETRE UN BUG

**Sur `MAGPIE_STAND_SPOT`** : neutraliser le fix (restaurer l'ancien
`(1,00 ; 0,40)`) reproduit un FAIL specifique sur l'assertion d'overlap de
`CabinProbe` avant d'etre restaure -- prouvant que le nouveau seuil de 25 %
est reellement porteur et pas un plafond qui passerait de toute facon.

**Sur `DOOR_SPOT`** : revenir a `(2,20 ; 0,65)` produit **0 FAIL** --
verifie plutot que suppose etre un probleme. C'est attendu : aucune
assertion de `CabinProbe` n'epingle un litteral exact de `DOOR_SPOT`, par
construction -- toutes les portes sont des controles de LEGALITE
independants de la position, que les deux points satisfont l'un et
l'autre. Ce lot est un choix de RE-IMPLANTATION entre deux positions
egalement legales, pas la correction d'un bug avec un invariant precis
casse -- donc l'absence de FAIL au revert n'est pas un trou de couverture,
c'est la nature meme du changement.

**Un troisieme point, non demande par le brief, trouve en verifiant** : le
litteral d'approche `short_far` de `PHASE N` avait ete recalcule au lot
precedent en pure -X depuis le stand-spot, magnitude
`HOP_DISTANCE + 0,40 = 1,90`. Applique a ce lot avec le nouveau
`(0,80 ; 0,40)`, cette meme recette tombe exactement sur `x = -1,10` --
**le bord ouest du carre du sol lui-meme**
(`FLOOR_CENTRE.x - FLOOR_HALF_EXTENT`). **Verifie et pas suppose fragile** :
rejoue exactement a cette valeur-frontiere, la phase passe toujours proprement
(0 echec, "stops SHORT ... 0.400") -- `floor_level.flat()` ne consulte
jamais l'appartenance et `hop_to()` non plus, **il n'y avait donc aucun bug
de bord reel a corriger**. Deplace quand meme vers -Z
(`Vector3(0.80, 0.0, -1.50)`), par hygiene seule -- pour qu'un futur
lecteur ne reste pas a se demander si la coincidence avec un bord de niveau
etait deliberee. Meme distance totale, meme garantie ; le commentaire du
fichier corrige une premiere version qui sur-affirmait un bug demontre la
ou il n'y en avait pas.

### Validation

Editeur + templates Godot 4.3-stable deja installes dans ce sandbox (le
symlink `godot4` avait besoin d'etre remis sur le `PATH`, `/tmp` etant
efface entre deux sessions -- binaire, symlink et templates d'export tous
retrouves intacts sous `/tmp/godot_install/`, tailles re-verifiees). Import
headless **exit 0, 37 `.scn`** sur le worktree de travail. Export Web
release **exit 0, 0 erreur GDScript** sur 270 lignes `Storing File`.
`index.wasm` **35 376 909** octets / md5
**`af4a8fc2925d992348eb30deeeb54360`**, `index.js` md5
**`4e08904b1b7107858246af44b602067b`** -- identiques au fingerprint
permanent deja consigne pour tout lot qui ne touche pas le code moteur.
**Piege payload tenu** : **0** ligne `Storing File` pour `scripts/dev`,
`assets_source`, `docs`, `web/`, `build` ou `firebase.json`.

**`CabinProbe` : 256 checks, 0 echec, exit 0.**

**Non-regression, worktree separe sur `origin/staging` (`fe0b0f8`),
import re-verifie complet (37 `.scn` des deux cotes)** : `ProbeTimeoutAudit`,
`AssetContractAudit`, `DeathModelAudit`, `ChargerShapeProbe` --
**BYTE-IDENTIQUES sur les quatre, tailles ET contenus**, entre le worktree
baseline et la branche.

⚠️ **PIEGE DE SESSION RENCONTRE ET FERME, A CONSIGNER** : une premiere
tentative d'import du worktree baseline a ete lancee en arriere-plan ; une
notification l'a annoncee "terminee" (exit 0), mais l'inspection reelle de
`.godot/imported/` n'y trouvait **aucun** `.scn` -- un import tronque
malgre un code de sortie propre, exactement le piege "faux-rouge par import
tronque" deja documente cinq fois dans ce fichier. Croyant a tort que le
premier processus avait fini, un second import a ete lance dans le MEME
worktree sans verifier que le premier etait reellement arrete : `ps aux` a
confirme **les deux processus tournant en concurrence sur le meme
`.godot/imported/`**, un vrai risque de corruption. Les deux tues via
`pkill -f '[-]-path . --import'` (l'idiome a crochet deja documente dans ce
fichier, pour eviter qu'un `pgrep`/`pkill -f` non protege ne se matche
lui-meme ou un shell ancetre). **Lecon** : une notification de tache de
fond "terminee" atteste que le mecanisme d'arriere-plan a rendu la main,
pas que le processus sous-jacent a reellement fini son travail -- verifier
par `ps aux` ou par un artefact reel (ici, le compte de `.scn`) avant de
faire confiance, particulierement pour `godot4 --import`. Le worktree a
ete nettoye (`rm -rf .godot build`) et reimporte une seule fois, au premier
plan, avec verification explicite du compte de fichiers avant tout usage.

### Reste ouvert -- jugement device, seul juge

1. **Le baiser se lit-il enfin comme un baiser** a l'echelle reelle d'un
   telephone, sans reproduire ni l'ancien chevauchement (62,7 %) ni la
   surcorrection "cote a cote" (10,6 %) ? La mesure dit 19,8 % au pic ;
   la lecture ne l'est pas.
2. **La porte se lit-elle comme "entre la table et l'escalier"**, ou
   encore trop proche de l'un des deux reperes ? La projection ecran donne
   59,5 % contre un milieu mesure a 58,25 % ; c'est un calcul, pas un oeil.
3. **La sortie immediate depuis ce nouveau point fonctionne-t-elle
   toujours** au pouce, sans delai ni double-tap ?
4. Rien ici n'est un rendu device : llvmpipe sous `xvfb` via le backend
   `opengl3` de BUREAU, contre WebGL2 sous Safari.

### Deploiement staging verifie sur le service (31 aout 2026)

CI run #346 (id 33435068266) sur `staging` `57306ae`, **verte** :
`Import project resources` 20:16:43 -> 20:20:05, `Export Web build`
20:20:05 -> 20:20:10, `Deploy to Vercel [STAGING]` **succes** 20:20:28 ->
20:20:42, `[PRODUCTION -- main]` correctement **skipped** (push sur
`staging`).

**Verifie SUR LE SERVICE, pas dans le log CI seul, sur DEUX marqueurs
independants, aux deux lus fraiches** :

| marqueur | valeur |
|---|---|
| `CACHE_VERSION` | **`1788207610` = 20:20:10 UTC** -- tombe exactement sur la fermeture de l'etape `Export Web build` |
| `index.wasm` servi | **35 376 909** octets -- identique au bit pres a l'export local, le fingerprint permanent |
| `index.pck` servi | 34 351 488 (marqueur, jamais preuve d'identite) |

Les deux lectures (`index.service.worker.js` et `index.html`) portent
`x-vercel-cache: MISS` avec `age: 0`, `date` colle a l'instant de la
requete -- pas une reponse de cache.

⚠️ **La valeur "avant" n'a PAS ete relue fraiche dans cette session** --
seule la valeur deja consignee par le lot precedent (`1788201885`,
18:44:45 UTC) est disponible en reference. La bascule n'est donc pas
prouvee dans les deux sens par cette session elle-meme, contrairement a la
methode habituelle ; ce qui EST prouve directement est que la valeur
servie MAINTENANT tombe exactement sur la fenetre d'export de CE run et
est fraiche des deux cotes -- une preuve plus faible d'un cran, dite
plutot que maquillee en preuve complete.

`main` **non touche** (`origin/main = afa49d7`, verifie apres le push).
Merge staging automatique, comme le veut la regle du palier 1 -- **pas de
merge vers `main` sans validation device explicite de Mathieu.**

## LE BAISER MESURAIT LE MAUVAIS SILHOUETTE : le plafond de 25% gatait le corps, pas le visage (31 aout 2026)

Branche `claude/keepy-kiss-contact-validation-6e9hc9`, partie de `staging`
(`88797c7` -- le second recalibrage de distance, deja documente juste
au-dessus). **Retour device sur ce meme x = 0.80** : aucune difference
percue avec l'ancien x = 1.00, alors que le chiffre gate (whole-body PEAK
19.8% contre 25%) donnait l'impression d'une marge confortable.

### ⚠️ LA RECON ETAIT MANDATEE AVANT TOUT CORRECTIF, ET ELLE A TROUVE UN
### DEFAUT DANS LA METRIQUE, PAS DANS LA DISTANCE

Une sonde jetable (`KissHeadZoneSweep.gd`, supprimee avant ce commit,
renders gardes sous `docs/hub-shots/kiss_sweep_x*.png`) a re-mesure les
memes candidats (x = 1.00 / 0.80 / 0.70 / 0.65 / 0.55 / 0.40) mais **contre
la ZONE TETE de la pie plutot que contre son AABB entiere** -- la
propriete qui avait motive le plafond de 25% a l'origine (« ne pas
enterrer sa tete ») n'a jamais ete ce que ce plafond mesurait.

**Zone tete mesuree sur le glTF brut, pas sur l'AABB de l'importeur** :
buffer POSITION de `keepy_magpie_prop.glb`, 5439 sommets, parcouru
directement. Le corps/les ailes occupent `y <~ 0.53` (X jusqu'a +-0,95, Z
jusqu'a +-0,75 -- envergure et queue, pas la tete), se resserrant en un
petit blob asymetrique au-dessus de `y = 0,708` (`x` dans [-0,05 ; 0,47],
`z` dans [-0,23 ; 0,32]) coherent avec « yeux, bec, la fleur » et rien
d'autre du maillage. Deux coupes gardees : TIGHT (visage/bec seuls), WIDE
(tete+cou).

**Au x = 0,80 deja livre : REST 0,0% (propre, attendu) mais PEAK 0,0%
AUSSI** -- le museau de Keepy n'atteint JAMAIS sa zone visage sur tout le
lean, ce que « environ le double du contact livre » (whole-body) cachait :
le surplus etait entierement corps-contre-corps, rien de nouveau contre
son visage. Ce seul chiffre explique un rapport device de « aucune
difference percue » mieux qu'aucun pourcentage whole-body ne le pourrait.

**Le vieux « mur » entre x = 0,70 (24,6%) et x = 0,65 (27,0%) etait REEL,
MAIS SUR LE MAUVAIS AXE.** Re-mesure sur la zone tete, les deux memes
candidats lisent REST 0,0% / PEAK 15,7% (x = 0,70) et REST 0,0% / PEAK
24,3% (x = 0,65) : son visage reste completement degage tant que Keepy est
simplement pres d'elle, et genuinement, visiblement touche au pic du lean,
**aux deux**. x = 0,65 avait ete ecarte pour avoir franchi un plafond qui
ne mesurait jamais son visage.

**Le vrai mur est plus loin, mesure et pas suppose** : x = 0,55 -- REST
head-WIDE (tete+cou) devient non nul pour la premiere fois (7,7%) : Keepy
frole sa zone cou avant meme de se pencher. PEAK head-tight deja 41,8%.
x = 0,40 -- REST head-TIGHT (visage/bec/yeux) non nul (11,9%) : sa propre
tete chevauche deja la sienne en restant simplement debout. PEAK 68,1% --
son visage a disparu, confirme au rendu et pas seulement au chiffre :
`kiss_sweep_x040_peak.png` montre presque rien d'elle au-dela de sa joue,
la ou `kiss_sweep_x065_peak.png` et `kiss_sweep_x070_peak.png` montrent
tous deux son visage nettement, son museau contre lui.

**x = 0,65 est le choix retenu** : le plus proche des deux candidats
propres, donnant la plus profonde des deux lectures de contact reel (24,3%
contre 15,7% au pic) tout en restant EXACTEMENT aussi propre au repos que
0,70 (0,0% sur les deux coupes) -- aucun cout a le prendre plutot que 0,70,
et plus de marge au-dessus de « effleurement a peine perceptible » avant
que la compression et le petit ecran d'un telephone n'aplatissent le
contact a nouveau vers rien.

**Clearances recalculees** : degagement du trou de fondation 1,090 (etait
1,235 a 0,80) contre un `MAGPIE_FOOTPRINT_RADIUS` de 0,73 -- 1,090 de
marge, asserte dans `CabinProbe` plutot que laisse comme une coincidence
non verifiee. Degagement de `DOOR_SPOT` : 1,278 contre `DOOR_REACH` 0,9 --
**PLUS** de marge qu'a 0,80 (1,208), parce que se rapprocher de la pie
eloigne de la porte, pas l'inverse.

### PHASE N REECRITE : REST/PEAK sur la zone tete, PAS le corps entier

Le plafond whole-body de 25% est retire ; quatre nouvelles assertions le
remplacent, gatant desormais sur `_HEAD_TIGHT_XZ`/`_HEAD_Y_TIGHT` (le
meme zonage mesure ci-dessus, en constantes permanentes dans
`CabinProbe.gd`) via un nouvel helper `_head_world_rect()` qui lit le
noeud VIVANT de la pie (`bird.to_global()`) plutot que de reconstruire son
transform a la main -- la meme discipline que la lecon deja payee dans ce
lot sur le bug de tangage de camera (instancier la vraie scene, jamais
retaper ses nombres) :

- REST head-tight < 2% (son visage reste degage avant qu'il se penche)
- REST head-wide < 2% (meme son cou n'est pas touche)
- PEAK head-tight > 10% (contact reel atteint son visage au pic du lean)
- PEAK head-tight < 50% (sans jamais l'avaler entierement)

**Verifie ROUGE AVANT VERT** : `MAGPIE_STAND_SPOT` remis temporairement a
`(0,80, 0,40)`, la sonde relancee -- l'assertion `peak_head_tight > 0.10`
echoue exactement avec la valeur predite par la recon
(`0,0%, want > 10%`), reproduisant le rapport device comme un chiffre
plutot que comme une impression. Restaure a `(0,65, 0,40)` : **259/259,
exit 0**.

**Un troisieme litteral perime trouve au passage** (pas dans le bloc du
lean lui-meme, une assertion PHASE N distincte, deja mentionnee comme
trouvee-et-corrigee dans le lot precedent pour une AUTRE approche) : le
degagement du trou de fondation attendait encore `~1,235` (la valeur a
x = 0,80) apres le changement de `MAGPIE_STAND_SPOT`. Corrige a `~1,090`.

### Validation

Editeur + templates Godot 4.3-stable deja installes dans ce sandbox.
`rm -rf build .godot` puis import headless **exit 0, 37 `.scn`**. Export
Web release **exit 0, 0 erreur GDScript**. `index.wasm`
**35 376 909 octets** / md5 **`af4a8fc2925d992348eb30deeeb54360`**,
`index.js` md5 **`4e08904b1b7107858246af44b602067b`** -- identiques au
fingerprint permanent de tout lot qui ne touche pas le code moteur, ce
que deux fichiers GDScript sont. Piege payload tenu : **0** ligne
`Storing File` pour `scripts/dev`, `assets_source`, `docs`, `web` ou
`firebase.json` sur 270 lignes.

**Quatre sondes partagees, diffees contre `origin/staging` en worktree
separe** (import complet verifie des deux cotes, 37 `.scn` chacun) :
`AssetContractAudit`, `DeathModelAudit`, `ChargerShapeProbe`,
`ProbeTimeoutAudit` -- **BYTE-IDENTIQUES sur les DEUX flux**, exit 0 des
deux cotes.

`scripts/dev/KissHeadZoneSweep.gd`/`.tscn` supprimes avant ce commit,
comme toute sonde jetable de ce depot -- les 13 renders qu'elle a produits
restent commites sous `docs/hub-shots/kiss_sweep_x*.png`,
`kiss_sanity_backdrop_only.png` et `kiss_head_zone_check.png` comme preuve
visuelle plutot que comme seul pourcentage.

⚠️ **VERIFICATION DE COLLISION DE SESSION FAITE APRES COUP, PAS AU
DEBUT -- signale plutot que cache.** Cette branche avait ete redemarree
depuis `afa49d7` (= `origin/main` a l'epoque) et son arbre local
divergeait fortement d'`origin/staging` en surface. Comparaison par ARBRE
plutot que par nom : `HubBuilder.gd`, `LevelDefinition.gd`, l'asset
`.glb` de la pie et `CabinHearts.gd` se sont reveles **byte-identiques**
a `origin/staging`, et le SEUL diff reel portait sur
`CabinInterior.gd`/`CabinProbe.gd` -- exactement les deux fichiers de ce
lot. Ce n'etait donc pas une collision de deux implementations
independantes, mais une continuation legitime de la meme lignee (le
second recalibrage `3d46f56`/`88797c7`, deploye sur staging sans jamais
avoir ete revalide visuellement par Mathieu -- palier 1 seulement).
Branche re-basee (`git reset --mixed origin/staging`) avant tout commit
pour que le merge reste trivial. **Regle a retenir : verifier l'ancetralite
par ARBRE (`git merge-base --is-ancestor`), jamais par la seule lecture
des trois premieres lignes d'un `git log` -- et faire cette verification
AU DEBUT du lot la prochaine fois, pas apres avoir deja fait tout le
travail.**

### Reste ouvert -- jugement device, seul juge, et la question posee cette
### fois est explicitement PERCEPTIBLE et pas seulement numerique

1. **Est-ce qu'un contact 24,3% zone-tete se lit comme un VRAI baiser** sur
   un ecran de telephone, la ou 19,8% whole-body (le meme x = 0,80 shippe
   auparavant) ne s'est PAS lu comme tel ? C'est la seule question qui
   compte, et aucune sonde ne peut y repondre -- seulement la comparaison
   des renders `kiss_sweep_x065_peak.png` / `x070_peak.png` (contact net,
   visage intact) contre `x040_peak.png` (visage disparu).
2. Rien ici n'est un rendu device : llvmpipe sous `xvfb` via le backend
   `opengl3` de BUREAU, contre WebGL2 sous Safari.

### Deploiement staging verifie sur le service (31 aout 2026)

CI run #348 (id 33443099326) sur `staging` `5bfc0a0d`, **verte** :
`Import project resources` 21:48:07 -> 21:51:31, `Export Web build`
21:51:31 -> 21:51:37, `Deploy to Vercel [STAGING]` **succes** 21:51:56 ->
21:52:08, `[PRODUCTION -- main]` correctement **skipped** (push sur
`staging`).

**Verifie SUR LE SERVICE, pas dans le log CI seul, sur DEUX marqueurs
independants, aux deux lus fraiches** :

| marqueur | valeur |
|---|---|
| `CACHE_VERSION` | **`1788213096` = 21:51:36 UTC** -- tombe exactement
  dans la fenetre `Export Web build` (21:51:31 -> 21:51:37) |
| `index.wasm` servi | **35 376 909** octets -- identique au bit pres a
  l'export local, le fingerprint permanent (aucun code moteur touche par
  ce lot de deux fichiers GDScript) |
| `index.pck` servi | 34 352 304 (marqueur, jamais preuve d'identite) |

Les deux lectures (`index.service.worker.js` et `index.html`) portent
`x-vercel-cache: MISS` avec `age: 0`, `date` colle a l'instant de la
requete -- pas une reponse de cache.

`main` **non touche** (`origin/main = afa49d7`). Merge staging
automatique (palier 1) -- **pas de merge vers `main` sans validation
device explicite de Mathieu, et cette fois la question posee est
explicitement PERCEPTIBLE, pas seulement un nouveau chiffre de sonde au
vert.**

## LE HOTSPOT DE LA PIE : LE RAYON DE TAP ETAIT MESURE DEPUIS SES PIEDS, PAS DEPUIS OU UN DOIGT VISE (31 aout 2026)

Branche `claude/magpie-hotspot-tap-range-xln93i`, partie de `staging`
(`751b877`). Retour device, capture a l'appui : embrasser la pie ne
declenche que depuis une zone etroite pres d'un pot de plante -- de
partout ailleurs autour d'elle, taper ne fait rien.

### RECON, ET LA CONSIGNE D'ESCALADE EXPLICITEMENT SUIVIE

Le brief posait une regle claire : si le rayon insuffisant est un
parametre LOCAL a l'appel `LevelHotspot.make()` de `&"magpie"`, corriger
sur place et rester sur Sonnet 5 ; si le rayon est un parametre PARTAGE
que `LevelHotspot` applique identiquement a tous les hotspots (porte, lit,
mezzanine, pie) et qu'une correction demande de le faire varier par type
dans `LevelHotspot` lui-meme, s'arreter et rapporter avant tout
changement d'architecture -- ce sous-lot basculerait sur Opus 4.8.

**`LevelHotspot.gd` a ete lu en entier et n'a recu ZERO modification.**
`accepts_tap(aim, index)` teste `is_available()` puis `serves(index)`
(`index == level_index`) puis une distance XZ contre `tap_radius` -- un
seul mecanisme, partage, mais **chaque hotspot porte son propre
`tap_radius` et son propre `point`**, passes a la construction. Le rayon
de la pie est donc un `const` local a `CabinInterior.gd`, jamais une
propriete de `LevelHotspot`. **La correction reste enterement locale, sur
Sonnet 5, comme la consigne le prevoyait pour ce cas.**

⚠️ **UNE FAUSSE ALERTE SOULEVEE PUIS FERMEE PENDANT LA CONCEPTION** : le
nouvel ancrage recentre tombe a ~0,97 u de `BED_SPOT` (le lit), ce qui
aurait pu sembler chevaucher le hotspot du lit a rayon 1,80.
**Impossible par construction** : le lit est construit avec
`level_index = 1` (la mezzanine), la pie avec `level_index = 0` (le
rez-de-chaussee), et `accepts_tap()` verifie `serves(index)` **avant**
la distance -- le lit n'est jamais meme teste en tapant sur la pie.
Verifie en lisant le code de construction des deux hotspots, pas suppose.

### LA CAUSE, MESUREE ET PAS DEVINEE

`LevelController.resolve()` ray-caste **chaque tap** depuis la camera
FIXE vers le **plan plat unique** du niveau courant
(`level.plane().intersects_ray(...)`), pour **tous** les hotspots,
quelle que soit la hauteur de ce qu'ils marquent. Un tap qui vise
visuellement le corps SURELEVE de la pie -- pas ses pieds -- resout donc
a un point du plan du sol decale de `MAGPIE_SPOT` d'une distance qui
**croit avec la hauteur du tap** : 0 % (ses pieds) = 0,000 ; 20 % =
0,504 ; 30 % = 0,773 -- deja au-dela de l'ancien rayon 0,60 ; 100 %
(sommet de la tete) = 3,045.

**Reproduit avant tout correctif** avec une sonde jetable (9 positions de
Keepy autour de la piece x 11 hauteurs de tap, 0-100 % du corps dessine) :
echec **uniforme et INDEPENDANT de la position de Keepy** -- confirme que
c'est de la geometrie de plan pure, ni la navigation, ni le trou
d'empreinte au sol (`LevelController.resolve()` ne lit jamais la
position du walker).

### LE CORRECTIF : RECENTRER L'ANCRE, PAS SEULEMENT ELARGIR LE RAYON

Simplement elargir `MAGPIE_TAP_RADIUS` en le gardant ancre sur
`MAGPIE_SPOT` (ses pieds) plafonne a **1,623863** avant de toucher le
cercle de la porte -- ne couvrant au mieux que ~57 % de sa hauteur
dessinee, ratant en permanence le haut du corps et la tete.

**`MAGPIE_TAP_ANCHOR`** (nouvelle constante, `Vector2(-1.261384,
-0.437180)`) est la resolution reelle, **lue directement sur
`LevelController.resolve()`**, d'un tap a 50 % de sa hauteur dessinee --
**cross-verifiee a la main** par la formule d'intersection
camera-rayon/plan-du-sol (exacte pour cette camera sans roll) :
`t = (floor_y - camera.y) / (W.y - camera.y)`,
`anchor = camera + t * (W - camera)`, en accord a moins de 1e-5 avec le
round-trip ecran de l'engine. **`MAGPIE_SPOT`, le trou d'empreinte,
`MAGPIE_STAND_SPOT` et son orientation restent INTOUCHES** : cette
constante n'existe que pour le hit-test, exactement comme tout
`LevelHotspot.point` est deja libre de differer de l'ancre visuelle
d'un prop.

**`MAGPIE_TAP_RADIUS` passe de 0,60 a 1,80**, mesure depuis la nouvelle
ancre : le point le plus eloigne du balayage de hauteur (100 %, le
sommet de la tete) est a 1,697867 -- une marge de 0,102 ; le voisin le
plus proche calcule DEPUIS la nouvelle ancre est la porte a
**2,361440** -- une marge de 0,561. Ni serre contre l'un ni contre
l'autre.

`LevelHotspot.make()` et le marqueur visuel (`_magpie_marker`) sont
**tous deux repointes sur `MAGPIE_TAP_ANCHOR`** -- le cercle que le
joueur vise et celui que le code teste restent un seul cercle, jamais
deux valeurs qui pourraient diverger.

### VALIDATION -- ROUGE AVANT VERT, PUIS GATE DE FACON PERMANENTE

Sonde jetable rejouee apres le fix : **8/8 checks OK**, les 11 hauteurs
(0-100 %) toutes detectees, et **27/27** (9 directions x 3 hauteurs de
tap representatives : 35 %, 55 %, 85 %) marchent, embrassent, et
atterrissent exactement sur `MAGPIE_STAND_SPOT`.

**Une regression permanente ajoutee a `CabinProbe.gd`** (PHASE N, deja
gatee) : un balayage des 11 hauteurs contre le VRAI `magpie.accepts_tap()`
en direct, plus 3 taps de corps a 55 % depuis 3 positions largement
separees, chacun verifiant la marche + le baiser complet.

⚠️ **PIEGE DE SONDE RENCONTRE ET CORRIGE, A CONNAITRE** : le balayage de
hauteur echouait aux 11 hauteurs, y compris 0 % (son point de sol exact),
alors qu'un bloc adjacent presque identique passait. Cause : `resolve()`
lit `current()` -> l'index de niveau COURANT du controleur, et la PHASE P
qui precede (mezzanine/lit) laisse le controleur sur le niveau 1 sans le
remettre a 0. Le bloc qui passait appelait deja `controller.set_current(0)`
avant de dispatcher ; celui qui echouait ne l'appelait pas. **Corrige en
ajoutant `controller.set_current(0)` en tete de la boucle** -- meme motif
que le bloc voisin. Confirme par lecture de `LevelController.resolve()`
(ligne 142-165), pas suppose.

**Diffe contre `origin/staging` en worktree separe, import complet
verifie des deux cotes (37 `.scn`)** : les portes/ladder-gap changent de
valeur (attendu, `magpie.point`/`tap_radius` ont change) mais restent
verts sans chevauchement ; 5 nouvelles lignes OK (le balayage + les 3
kiss) ; une ligne fendue en deux (`MAGPIE_SPOT` et l'ancre testes
separement pour "hors du carre marchable"). Le reste -- angle de
penchant du baiser, % de contact, comptes de frames PHASE T -- derive de
quelques centiemes/frames entre deux runs separes, **connu et documente
comme non-deterministe sous ce sandbox llvmpipe**, jamais pres d'un seuil
de FAIL, dans des phases que ce diff ne touche pas.

`ProbeTimeoutAudit`, `AssetContractAudit`, `DeathModelAudit`,
`ChargerShapeProbe` : **BYTE-IDENTIQUES** (taille de sortie exacte) entre
la branche et le worktree `origin/staging` -- aucun de ces quatre fichiers
ne partage de chemin avec ce diff.

⚠️ **Les deux `ERROR: Condition "!is_inside_tree()"` vues en PHASE R sont
PRE-EXISTANTES**, reproduites a l'identique sur `origin/staging` intact --
un artefact deja documente du changement de scene en deux temps de
`change_scene_to_packed` (un noeud du hub interroge son
`get_global_transform()` une frame apres avoir ete detache), sans rapport
avec ce lot et hors de son perimetre.

### BUILD

Templates d'export Godot 4.3-stable absents au demarrage de cette
session (container frais) -- retelecharges depuis la release GitHub
officielle, **taille verifiee contre le `Content-Length` avant
extraction** (1 073 228 327 octets, aucune troncature). Import headless
**exit 0, 37 `.scn`, 0 erreur**. Export Web release **exit 0, 0 erreur**.
`index.wasm` **35 376 909** octets / md5
**`af4a8fc2925d992348eb30deeeb54360`**, `index.js` md5
**`4e08904b1b7107858246af44b602067b`** -- identiques au fingerprint
permanent de tout lot qui ne touche pas le code moteur, coherent : ce
lot ne change que deux fichiers GDScript. **Piege payload tenu** : sur
270 lignes `Storing File`, **0** pour `scripts/dev`, `assets_source`,
`docs`, `web` ou `firebase.json`.

### RESTE OUVERT -- jugement device, seul juge

1. **Est-ce que la pie repond desormais de partout autour d'elle** sur un
   vrai telephone -- c'est tout l'objet du lot, et aucune mesure sandbox
   (llvmpipe sous xvfb) ne remplace un test reel.
2. Ce lot fait partie d'un ensemble de lots pie/bisou. `main` **non
   touche** -- merge sur `staging` : palier 1, automatique. Un futur
   prompt fusionnera `staging` -> `main` pour l'ensemble du lot pie une
   fois tous valides sur device.

### Deploiement staging verifie sur le service (31 aout 2026)

`staging` `751b877` -> merge `9e3f18e` (`--no-ff`), push confirme
(`751b877..9e3f18e staging -> staging`). CI **run #350**
(id `33450634720`, head_sha `9e3f18e4745298d3019e4269cc9ebba0bd361bb5`)
**verte** : `Import project resources` 23:26:24 -> 23:30:03,
`Export Web build` **23:30:03 -> 23:30:09**, `Verify export output`
succes, `Deploy to Vercel [STAGING -- staging]` succes 23:30:25 -> 23:30:39,
`[PRODUCTION -- main]` correctement **skipped**.

**Verifie SUR LE SERVICE, pas dans le log CI, sur DEUX marqueurs
independants et aux DEUX bouts -- les QUATRE lectures en
`x-vercel-cache: MISS` / `age: 0`**, les valeurs "avant" ayant ete
relevees AVANT le merge :

| marqueur | avant | apres (ce lot, run #350) |
|---|---|---|
| `CACHE_VERSION` | `1788213562` = **21:59:22 UTC** | **`1788219008` = 23:30:08 UTC** |
| `index.pck` servi | 34 352 320 | 34 352 368 |
| `index.wasm` servi | 35 376 909 | **35 376 909** *(inchange, attendu)* |

L'epoch d'apres tombe **exactement dans la fenetre `Export Web build`**
(23:30:03 -> 23:30:09), et les DEUX lectures d'apres portent
**`x-vercel-cache: MISS` avec `age: 0`**, `last-modified` colle a
l'instant de la requete -- pas une reponse de cache. La valeur d'avant a
egalement ete lue en MISS/age 0 (avant le push) : c'est la forme la plus
forte que ce fichier documente, deux marqueurs et quatre lectures fraiches
plutot qu'une seule.

`index.wasm` **35 376 909 octets / md5
`af4a8fc2925d992348eb30deeeb54360`** -- identique au fingerprint permanent
deja consigne pour tout lot qui ne touche pas le code moteur, coherent :
ce lot ne change que deux fichiers GDScript (`CabinInterior.gd`,
`CabinProbe.gd`). `index.pck` **jamais offert comme preuve d'identite**,
seulement comme marqueur "nouveau build servi".

`main` **non touche** (`origin/main` reste en arriere, verifie avant le
push). Palier 2 -- merge vers `main` -- reste gate par validation device
de Mathieu, pour ce lot ET pour l'ensemble des lots pie/bisou.

## L'ANNEAU DE LA PIE ETAIT VISUELLEMENT TROP GROS, ET LE LIT AVAIT LE MEME BUG QUE LA PIE -- MESURE, PAS SUPPOSE (1 septembre 2026)

Branche `claude/hotspot-tap-radius-visual-2rf3lt`, partie de `staging`
(`28f63e5`). Deux sujets, un seul commit conceptuel : (A) la pie tape
juste partout desormais (fix du lot precedent, valide device 9/9), mais
retour device suivant -- l'anneau dessine autour d'elle est trop grand,
il avale un tiers de la piece. (B) appliquer la MEME methode de mesure
qui a trouve le bug de la pie (balayage 0-100 % de la hauteur dessinee
contre le plan fixe que `LevelController.resolve()` ray-caste) au hotspot
`&"bed"`, sans supposer qu'il partage le symptome.

### PART A -- LE DECOUPLAGE VISUEL/FONCTIONNEL, ET LA CONSIGNE D'ESCALADE RESPECTEE

Le brief posait la meme regle que le lot precedent : si le decouplage
tient dans `CabinInterior.gd`, rester Sonnet 5 ; s'il fallait ajouter un
champ a `LevelHotspot.gd` (partage par door/bed/magpie/mezzanine),
s'arreter et rapporter avant tout changement -- bascule Opus 4.8.

**`LevelHotspot.gd` et `CabinMarker.gd` sont BYTE-INTOUCHES.**
`CabinMarker.setup(radius, text, surface, label_offset)` prend le rayon
qu'on lui donne et ne le relit nulle part ailleurs -- la taille de
l'anneau DESSINE n'a jamais ete liee a `LevelHotspot.tap_radius`, c'est
`CabinInterior._build_markers()` qui choisissait quoi lui passer, et
c'est le seul endroit a corriger.

⚠️ **LA CAUSE N'ETAIT PAS UN BUG, C'ETAIT UN HERITAGE DU LOT PRECEDENT.**
Le lot magpie-hotspot-tap-range avait repoint `_magpie_marker` sur
`MAGPIE_TAP_ANCHOR` avec `MAGPIE_TAP_RADIUS` (1,80) -- le meme couple
que le hit-test -- en ecrivant explicitement "le cercle qu'un joueur vise
et celui que le code teste doivent rester un seul cercle". Vrai pour le
FONCTIONNEL, faux pour le RENDU : l'ancre est a 1,35 des pieds reels de
la pie, et un disque de 1,80 de rayon dessine la flotte au milieu de la
piece plutot que de l'entourer.

**Corrige en revenant a une paire distincte pour le marqueur** :
`_magpie_marker` est desormais construit avec `MAGPIE_FOOTPRINT_RADIUS`
(0,73 -- deja utilise ailleurs pour le trou d'empreinte au sol, pas une
nouvelle mesure) et positionne a `MAGPIE_SPOT` (ses pieds), tandis que
`LevelHotspot.make()` garde `MAGPIE_TAP_ANCHOR`/`MAGPIE_TAP_RADIUS`
intouches pour le hit-test. Trois rayons rendus avant de choisir (1,00 /
0,73 / 0,60, a l'ancre puis a `MAGPIE_SPOT`) -- 0,73 a `MAGPIE_SPOT` est
celui qui se lit comme un anneau colle a son corps, au meme registre que
l'anneau de la porte.

**Le patron devient la regle du fichier** : porte et echelle gardent un
anneau unifie (jamais eu besoin de bouger), pie et lit (voir Part B)
portent chacun DEUX paires -- une visuelle (position reelle + rayon
d'empreinte) et une fonctionnelle (ancre parallaxe-corrigee + rayon de
hit-test) -- documente en tete de `_build_markers()`.

### PART B -- LE LIT, BALAYE PLUTOT QUE SUPPOSE, ET LE RESULTAT EST PLUS ETROIT QUE CELUI DE LA PIE

**Meme mecanisme**, verifie et pas suppose de la pie : `LevelController.
resolve()` ray-caste chaque tap contre le plan plat de la mezzanine
(`level.plane()`), jamais le mesh dessine, donc un tap qui vise
visuellement le haut du lit derive du plan au sol d'une distance qui
croit avec la hauteur.

**Balaye avec la meme sonde de mesure** (0/10/.../100 % de la surface
dessinee du lit, `_bed_surface_low/_high = 6.5522/7.5952` -- deja mesuree
au lot d'installation du lit, pas re-derivee) contre la formule exacte de
`resolve()`.

⚠️ **LE BALAYAGE SEUL SURESTIME LE BUG, ET C'EST L'OCCLUSION QUI LE
CORRIGE.** Croise avec une verification d'occlusion camera-vers-point
(Moller-Trumbore contre le `.glb` livre, hors ligne) : les fractions
0 %/30-50 % sont occultees (rien a taper la, non pertinent) ; 10-20 % et
60-80 % sont VISIBLES et REFUSEES par le cercle livre a 0,70 -- **c'est
le vrai bug, pas "tout sous 90 %"** ; 90-100 % sont deja visibles ET
acceptees.

⚠️ **ELARGIR `BED_TAP_RADIUS` SANS DEPLACER L'ANCRE NE PEUT PAS FERMER
CES DEUX BANDES -- PROUVE, PAS ARGUMENTE.** Le rayon livre (0,70) etait
deja contraint par l'echelle : re-deriver le plus grand cercle que
l'echelle autorise autour de `BED_SPOT` lui-meme donne **0,6201** --
PLUS PETIT que ce qui est livre, parce que `BED_SPOT` est trop pres de
l'echelle pour laisser de la place. Recentrer n'est pas un echo
stylistique du fix de la pie, c'est le seul axe disponible ici.

**`BED_TAP_ANCHOR = Vector2(-1.291703, 1.333841)`**, prise au point milieu
(50 %) de la plage de hauteur mesuree -- meme methode de derivation que
`MAGPIE_TAP_ANCHOR` (pas un point optimise numeriquement). **`BED_TAP_RADIUS
= 1.75`**, le plafond de degagement de l'echelle depuis cette nouvelle
ancre (1,9519) moins la meme marge de securite de 0,20 que le fix de la
pie. Couverture resultante : **[7,3 %, 81,2 %]**.

⚠️ **CE FIX COUTE LA BANDE 90-100 %, PUBLIE FRANCHEMENT PLUTOT QUE
CACHE.** Verifie exhaustivement (pas suppose) : aucun couple ancre/rayon
ne degage a la fois l'echelle ET couvre 0-100 % complet -- preserver
90-100 % plafonne a 80,2 % de couverture, ratant entierement la bande
60-80 %, plus large et plus centrale du lit. Le choix retenu prend la
bande la plus probablement visee par un joueur (60-80 %, le corps du lit)
au prix de la pointe la plus etroite (90-100 %, le sommet de la pile de
livres). **Apres ce fix, taper tout en haut de la pile ne s'enregistre
plus comme "le lit".**

Sanity-check de non-debordement : la nouvelle ancre est a **2,681** de
`BED_SPOT` et **2,719** de `LOFT_CENTRE`, toutes deux hors du rayon 1,75
-- un tap ordinaire "je marche ici" pres du lit ou au centre de la
mezzanine n'est pas avale par ce cercle.

**Le marqueur visuel garde `BED_MARKER_RADIUS = 0.70` a `BED_SPOT`** --
jamais signale comme visuellement faux, seul le cercle de hit-test etait
aveugle. Meme discipline que le marqueur de la pie : deux paires
distinctes, une pour l'oeil, une pour le code.

**Trois consommateurs mis a jour pour suivre le meme split** :
`_on_tapped_hotspot`'s `&"bed"` branch decharge desormais `destination`
(qui resout pres de `BED_TAP_ANCHOR`) au profit de `BED_SPOT` pour le
`hop_to()` -- marcher vers `destination` l'aurait pose a plusieurs unites
du matelas ; `_refresh_proximity()`/`_pulse_if_near()` generalises pour
lire un ancrage explicite par appelant plutot que `marker.position`, la
porte et l'echelle passant leur propre position reelle (inchangee pour
elles), la pie et le lit leur ancre fonctionnelle.

### VALIDATION -- ROUGE AVANT VERT, GATE DE FACON PERMANENTE

**Nouveau bloc de balayage gate dans `CabinProbe.gd`, PHASE P** : 11
assertions par decile (0-100 %) contre `bed_expect_covered`, un
dictionnaire figeant explicitement la couverture attendue -- jamais "tout
doit passer". Verifie ROUGE en revenant temporairement a
`BED_SPOT`/`0.70` : **11 echecs** (les 10 deciles + l'agrege), reproduisant
exactement la table documentee ; puis restaure et reverifie VERT sur
**trois cycles distincts** dans cette session (avant/apres le nettoyage
des sondes jetables, et sur un import totalement propre) : **0 echec,
277 OK, exit 0** a chaque fois.

⚠️ **PHASE K portait une assertion perimee, trouvee en corrigeant Part B**
: `loft_level.contains(bed.point)` testait le point de hit-test
(desormais `BED_TAP_ANCHOR`), qui sort legitimement du petit carre
marchable de la mezzanine -- exactement comme `MAGPIE_TAP_ANCHOR` n'a
aucune verification equivalente en PHASE N, pour la meme raison. Corrigee
pour tester `BED_SPOT` (la position REELLE du lit) a la place -- ce n'est
pas un affaiblissement, c'est la bonne question maintenant.

Huit fichiers de sonde jetables (`BedHeightMarkersProbe`,
`BedSweepReconProbe`, `MagpieRingReconProbe`, `MagpieRingReconProbe2` --
`.gd`+`.tscn` chacun) **supprimes avant commit**.

### BUILD ET NON-REGRESSION

Editeur + templates Godot 4.3-stable installes dans ce sandbox (releases
GitHub officielles, **taille du `.tpz` verifiee contre le
`Content-Length`** -- 1 073 228 327 octets, aucune troncature). Import
headless **exit 0**, boot **exit 0**, export Web release **exit 0, 0
erreur GDScript**, piege payload verifie sur le log `savepack` -- **0**
ligne `Storing File` pour `scripts/dev`, `assets_source`, `docs`, `web`,
`build` ou `firebase.json` sur 270 lignes. `index.wasm` **35 376 909
octets / md5 `af4a8fc2925d992348eb30deeeb54360`**, `index.js` md5
`4e08904b1b7107858246af44b602067b` -- identiques au fingerprint permanent
de tout lot qui ne touche pas le code moteur, coherent : ce lot ne change
que `CabinInterior.gd` et `CabinProbe.gd`.

**Huit sondes diffees contre `origin/staging` en worktree separe**
(import complet verifie des deux cotes, 37 fichiers `.scn` d'assets
importes) : `AssetContractAudit`, `DeathModelAudit`, `ChargerShapeProbe`,
`ProbeTimeoutAudit` -- **BYTE-IDENTIQUES sur les DEUX flux** (tailles
comparees avant les contenus). `LevelNavProbe` (77/0), `TurnstileProbe`
(0/0), `WaterTintProbe` (0/0) -- tous exit 0. `SeesawProbe` : premiere
tentative **exit 1** sur un piege d'ordre de flags deja consigne dans ce
fichier (`--fixed-fps` place APRES `--` au lieu d'avant, donc ignore --
la diagonale tourne alors a la vitesse du mur, 6,317 s au lieu du 18,700 s
publie) ; rejouee avec l'ordre correct, **exit 0, 0 echec**, diagonale
reproduite au frame pres.

### RESTE OUVERT

Jugement device, seul juge, sur les deux axes : (A) l'anneau de la pie
se lit-il desormais comme colle a son corps plutot que flottant au milieu
de la piece ? (B) le lit repond-il enfin depuis son centre visuel, et le
sacrifice de la pointe (90-100 %) passe-t-il inapercu a l'usage ? Aucune
sonde headless ne peut trancher ces deux questions.

**Backlog signale, pas traite** : la chaine de lots pie/bisou/lit
accumule desormais huit iterations de recalibration successives, toutes
sur `staging`, aucune mergee sur `main`. Une revue de statut group
groupee est justifiee des que ce lot est valide sur device, plutot que
de continuer a merger `staging` -> `main` hotspot par hotspot.

## MERGE EN PRODUCTION -- CHANTIER PIE (1er septembre 2026)

`staging` (`e6211b0`) -> `main`, commit de merge **`9cab266`**, `--no-ff`,
sur feu vert explicite de Mathieu apres validation device de la chaine
pie/bisou complete : install et calibration du prop pie du hub (echelle,
integration nav, comportement de saut), visibilite et taille du hub,
distance d'interaction du bisou (x2), position de sortie, portee du
hotspot de tap de la pie, et l'anneau visuel de portee de tap decouple de
son rayon de test -- **tout confirme fonctionnel sur device**.

⚠️ **DETTE ASSUMEE, PAS UN OUBLI : le hotspot `&"bed"` reste NON
FONCTIONNEL sur device.** Le fix geometrique livre dans le dernier lot
`staging` (le meme sweep de decouplage anneau/rayon applique au lit) n'a
produit **aucune difference percue sur device**, malgre la preuve
geometrique/le calcul presentes au moment de ce lot. Merge sur `main`
autorise **quand meme**, en connaissance de cause : le lit sera traite
dans un lot separe, **apres** ce merge, avec un recon v2 qui devra
produire des rendus offscreen comparatifs (la methode qui a fonctionne
pour le bisou apres son propre echec de validation) **avant** toute
nouvelle proposition de correctif -- ne pas se fier au calcul geometrique
seul, qui a deja produit un faux-vert sur ce meme hotspot.

**Verifie AVANT le merge, par ARBRE et pas par nom** : `git fetch --all
--prune`, `origin/staging = e6211b0` et `origin/main = afa49d7` exactement
les SHA annonces, `origin/staging` la ref la plus recente du depot (la
seule branche plus recente que `main`,
`claude/hotspot-tap-radius-visual-2rf3lt`, deja ancetre de `staging` --
`git merge-base --is-ancestor` + comparaison de hash d'arbre), **aucune
session concurrente**. Merge `--no-ff` sans conflit ; **diff de l'arbre
resultant contre l'arbre de `staging` a `e6211b0` : VIDE**
(`git diff HEAD origin/staging` vide, meme hash d'arbre `5a64ae98...` des
deux cotes) -- ce qui part en prod est litteralement l'arbre valide sur
staging, pas une recomposition.

**Build local, editeur + templates Godot 4.3-stable installes dans ce
sandbox** (releases GitHub officielles, tailles verifiees contre le
`Content-Length` avant extraction -- 50 276 070 et 1 073 228 327 octets,
aucune troncature). Import headless **exit 0, 37 `.scn`** (import complet
verifie, pas suppose). Export Web release **exit 0, 0 erreur GDScript**.
`index.wasm` **35 376 909** octets / md5
**`af4a8fc2925d992348eb30deeeb54360`**, `index.js` md5
**`4e08904b1b7107858246af44b602067b`** -- identiques au fingerprint
permanent deja consigne pour tout lot qui ne touche pas le code moteur.
**Piege payload tenu** : **0** ligne `Storing File` pour `scripts/dev`,
`assets_source`, `docs`, `web`, `build` ou `firebase.json`.

CI **run #353** (id `33485316412`) **verte** (08:05:57 -> 08:10:52 UTC) --
`Import project resources` 08:06:39 -> 08:10:19, `Export Web build`
**08:10:19 -> 08:10:25**, `Deploy to Vercel [PRODUCTION -- main]`
**succes** 08:10:40 -> 08:10:50, `Deploy to Vercel [STAGING -- staging]`
correctement **skipped** (push sur `main`).

**Verifie SUR LE SERVICE, pas seulement dans le log CI**, sur DEUX
marqueurs independants, tous deux `x-vercel-cache: MISS` / `age: 0` :

| marqueur | valeur servie |
|---|---|
| `CACHE_VERSION` | `1788250224` = **08:10:24 UTC** -- tombe exactement dans la fenetre `Export Web build` (08:10:19 -> 08:10:25) |
| `index.wasm` servi | **35 376 909** octets -- identique au bit pres a l'export local, preuve d'identite |
| `index.pck` servi | 34 352 672 octets (export local : 34 352 640 -- 32 octets d'ecart, instabilite de compression VRAM deja documentee, jamais offert comme preuve d'identite a lui seul) |

**Le chantier pie/bisou est desormais EN PRODUCTION** sur
`keepy-ten.vercel.app`, a l'exception assumee du lit.

**Prochaine etape** : rouvrir le hotspot du lit dans son propre lot, avec
un recon v2 exigeant des rendus offscreen comparatifs AVANT toute
proposition de correctif. A cette occasion, verifier aussi si le rond
visuel du lit doit etre decouple de la meme facon que celui de la pie --
le rapport dit `BED_MARKER_RADIUS` inchange a 0.70, mais ca vaut la peine
de confirmer que ce rayon-la est percu et coherent une fois le vrai
probleme de portee compris.

## LE HOTSPOT DU LIT : LOT 10 CASSE -> RECON V2 -> RECON-RENDUS C1/C2/A -> C2 LIVRE (1er septembre 2026)

Branche `claude/bed-hotspot-c2-20iee9`, partie de `main` (`d8f6fb0`).
Ferme la dette assumee au merge de prod precedent : le hotspot `&"bed"`
etait reste non fonctionnel sur device malgre un fix geometrique deja
tente (lot 10) et deja merge sur `staging`/`main`.

### LE PARCOURS EN TROIS ETAPES, ET POURQUOI CHACUNE A ETE NECESSAIRE

1. **Lot 10** (deja documente plus haut dans ce fichier, section "L'ANNEAU
   DE LA PIE ETAIT VISUELLEMENT TROP GROS, ET LE LIT AVAIT LE MEME BUG QUE
   LA PIE") avait deja recentre `BED_TAP_ANCHOR` a `(-1.291703, 1.333841)`,
   rayon `1.75`, en balayant la hauteur DESSINEE du lit (0-100% de sa
   plage 6.5522-7.5952) contre le plan plat que `LevelController.resolve()`
   utilise reellement. **Merge sur `main` avec la dette explicitement
   assumee** : "le fix geometrique livre... n'a produit AUCUNE difference
   percue sur device, malgre la preuve geometrique/le calcul presentes au
   moment de ce lot."
2. **Recon v2** (hors de ce lot, deja effectuee avant ce brief) : a produit
   les rendus offscreen comparatifs demandes par la note de merge
   precedente, plutot que de refaire confiance au seul calcul geometrique
   qui avait deja produit un faux-vert sur ce meme hotspot.
3. **Recon-rendus C1/C2/A** : trois candidats d'ancre/rayon compares par
   rendu offscreen, produisant C2 comme celui a livrer. **Aucun document
   persiste n'existe pour ce processus** (`find docs -iname "*bed*"` ne
   rend rien) -- son seul artefact survivant est les valeurs elles-memes,
   transmises par les instructions de ce lot.

### ⚠️ LA VRAIE CAUSE, ET POURQUOI LE BALAYAGE PAR HAUTEUR ETAIT LA MAUVAISE
### METRIQUE DES LE DEPART

Le symptome device etait "taper le lit ne s'enregistre presque jamais". Le
balayage par hauteur du lot 10 mesurait la **plage de hauteur dessinee**
du lit a la colonne XZ fixe de `BED_SPOT` -- exactement la methode qui a
trouve le bug de la pie, et un vrai defaut a ete trouve par cette methode
(l'ancre de lot 10 refusait la majorite de cette colonne).

**Mais ce n'est pas ce qu'un joueur voit reellement taper : c'est
l'ANNEAU DU MARQUEUR** -- la geometrie que `CabinMarker.gd` dessine
reellement (XZ de `BED_SPOT`, hauteur monde `loft.plane_y +
CabinMarker.CABIN_RING_LIFT`, rayon `BED_MARKER_RADIUS`). Un balayage
azimutal de cet anneau precis, aller-retour par la vraie camera puis par
`LevelController.resolve()` -- le meme mecanisme de derive par parallaxe
deja prouve pour la pie -- donne un chiffre tres different du balayage par
colonne.

**Mesure IN-ENGINE, pas recopiee du recon offscreen** (`CabinProbe.gd`,
PHASE P, sonde jetable temporaire DEBUGRING/DEBUGMEZZ verifiee puis
convertie en assertion permanente) :

| | ancre/rayon lot 10 (livre avant) | candidat C2 (livre) |
|---|---|---|
| **couverture de l'anneau** (72 azimuts) | **0,00% (0/72)** | **100,00% (72/72)** |
| **cout mezzanine** (grille 101x101 du sol de la mezzanine) | 4,25% (429 points) | **10,14%** |
| chevauchement avec le lien de l'echelle | 0 | **0** |
| degagement du lien de l'echelle | -- | gap ~3,199 contre radii-sum ~2,911, marge ~0,288 |

**Confirme ROUGE-AVANT-VERT dans ce meme sandbox** : les constantes de
lot 10 restaurees temporairement (`sed`, puis reverties) donnent bien
`0,00% (0/72)` sous cette meme methode -- fermant la question de savoir
si la couverture d'anneau est le bon diagnostic ou un artefact qui ne
lirait differemment entre les deux candidats que par hasard.

### VALEURS -- AVANT / APRES, UN SEUL CHANGEMENT FONCTIONNEL

```
AVANT (lot 10) : BED_TAP_ANCHOR = Vector2(-1.291703, 1.333841)
                 BED_TAP_RADIUS = 1.75
APRES (C2)     : BED_TAP_ANCHOR = Vector2(-1.9923, -3.5812)
                 BED_TAP_RADIUS = 1.811
```

`BED_SPOT`, `BED_MARKER_RADIUS` et les lifts marqueur (`CABIN_PAD_LIFT`
0,20 / `CABIN_RING_LIFT` 0,23) sont **INTOUCHES** -- meme split
visuel/fonctionnel que la pie : l'ancre de tap n'a jamais eu a coincider
avec la position ou le rayon reellement DESSINES du marqueur.

### LE COUT MEZZANINE EST ACCEPTE, PAS GRATUIT

**10,14%** du carre praticable de la mezzanine (a hauteur de sol, un tap
"je marche ici" ordinaire, pas un tap sur une surface surelevee) resout
desormais vers le lit plutot que vers une simple marche, concentre pres du
bord ouest de la mezzanine ou l'ancre de C2 se trouve. **Croise contre le
cercle du lien de l'echelle : 0 point sur 101x101 est capture par les
deux a la fois** -- ce cout n'est donc pas non plus un chevauchement
inter-hotspot.

**Bande de tolerance de la clause d'escalade** : 10,58% (chiffre du recon
offscreen) +- 3 points = **[7,58% ; 13,58%]**. Le chiffre in-engine mesure
(10,14%) tombe dedans, a 0,44 point du chiffre du recon -- **la clause
d'escalade ne s'est pas declenchee**, aucun arret n'a ete necessaire.

**Accepte sur la force que la couverture PLEINE de l'anneau est la
propriete dont ce hotspot a reellement besoin** -- un joueur ne peut pas
mal-taper un anneau qu'il ne peut jamais taper avec succes du tout.

### ⚠️ CORRECTION PERMANENTE : LE "CONTROLE SOL ~100%" DE LA PORTE N'A
### JAMAIS EXISTE

Un brief anterieur pour ce meme hotspot invoquait un chiffre "controle
sol ~100%" pour la porte. **Ce chiffre est FAUX et ne doit plus
ressortir.** Verifie dans ce lot : la couverture d'anneau de la porte
plafonne a **24,65% brut / 82,15% mesure contre son pad**, pas 100%. Ce
qui a produit ce chiffre errone n'etait ni ce fichier ni cette sonde, et
il ne doit pas etre suppose vrai du lit sous pretexte qu'il ressemble au
meme genre d'affirmation.

### LE BALAYAGE PAR HAUTEUR EST RETIRE, PAS SILENCIEUSEMENT ABANDONNE

`CabinProbe.gd` documente explicitement pourquoi : rejoue contre C2, ce
balayage lit 0% a chaque decile -- pas parce que C2 est casse, mais parce
que son ancre a ete deliberement recentree HORS de cette colonne pour
couvrir l'anneau a la place. Garder ce balayage gate aurait fait echouer
un fix confirme fonctionnel plus bas ; le laisser non-gate aurait rapporte
un chiffre sur une geometrie que plus rien ici ne pretend couvrir. Retire
et remplace par les deux assertions permanentes ci-dessus (couverture
d'anneau + cout mezzanine + non-chevauchement), documente en commentaire
pour qu'une future session ne redecouvre pas "le balayage colonne dit 0%"
comme une regression.

### VALIDATION

Editeur Godot 4.3-stable installe dans ce sandbox. Import headless
**exit 0, 37 `.scn`**. `CabinProbe.gd` PHASE P, sous `xvfb-run
--rendering-driver opengl3` (jamais `--headless` seul, qui force un
viewport factice 0x0 et invaliderait tout calcul de projection ecran) :
**268 OK, 0 echec, exit 0**. Export Web release **exit 0, 0 erreur**.

`index.wasm` **35 376 909** octets / md5
**`af4a8fc2925d992348eb30deeeb54360`**, `index.js` md5
**`4e08904b1b7107858246af44b602067b`** -- identiques au fingerprint
permanent deja consigne pour tout lot qui ne touche pas le code moteur,
coherent : ce lot ne change que deux fichiers GDScript. **Piege payload
tenu** : sur **270** lignes `Storing File`, **0** pour `scripts/dev`,
`assets_source`, `docs`, `web` ou `firebase.json`. `index.pck`
34 352 560, marqueur et jamais preuve d'identite.

**Quatre sondes de non-regression, diffees contre `origin/main` en
worktree separe (import complet verifie des deux cotes, 37 `.scn`
chacun)** : `AssetContractAudit`, `DeathModelAudit`, `ChargerShapeProbe`,
`ProbeTimeoutAudit` -- **BYTE-IDENTIQUES sur les DEUX flux**, exit 0 des
deux cotes. `ProbeTimeoutAudit` confirme **59 sondes scenes des deux
cotes** -- ce lot n'ajoute ni ne retire aucune sonde, seulement des blocs
a `CabinProbe.gd` existant.

### RESTE OUVERT -- jugement device, seul juge

Est-ce que le lit repond enfin depuis son centre visuel a l'echelle
reelle d'un telephone ? La couverture d'anneau (100,00%) et le cout
mezzanine (10,14%, dans la bande acceptee) sont mesures in-engine ;
aucune sonde de ce depot ne peut confirmer le ressenti sur device. Rien
ici n'est un rendu device : llvmpipe sous `xvfb` via le backend
`opengl3` de BUREAU, contre WebGL2 sous Safari.

`main` **non touche**. Merge sur `staging` : palier 1, automatique
(build, import, export et sondes verts). **Palier 2 reste gate par
Mathieu** : validation device sur `keepy-staging.vercel.app` avant tout
merge vers `main`.

### MERGE EN PRODUCTION (1er septembre 2026, autorisation explicite de Mathieu)

`staging` (`7344bde`) -> `main`, commit de merge **`629317b`**, `--no-ff`,
apres validation device confirmee par Mathieu : "hotspot du lit reactif
sur toute sa surface, cout mezzanine bord ouest juge acceptable au
pouce".

**Verifie AVANT le merge, par ARBRE et pas par nom** : `git fetch --all
--prune`, `origin/staging = 7344bde` et `origin/main = d8f6fb0`
exactement les SHA attendus, aucune session concurrente depuis le
dernier rapport. Merge `--no-ff` sans conflit ; **diff de l'arbre
resultant contre l'arbre de `staging` a `7344bde` : VIDE** -- meme hash
d'arbre des deux cotes (**`53731cee0d300a33b425bc293c1585611adea9d1`**),
verifie AVANT le push : ce qui part en prod est litteralement l'arbre
valide sur staging, pas une recomposition.

**Build local, editeur + templates Godot 4.3-stable installes dans ce
sandbox** (releases GitHub officielles). `rm -rf build .godot`, import
headless **exit 0, 37 `.scn`** (import complet verifie, pas suppose).
Export Web release **exit 0, 0 erreur GDScript**. `index.wasm`
**35 376 909** octets / md5 **`af4a8fc2925d992348eb30deeeb54360`**,
`index.js` md5 **`4e08904b1b7107858246af44b602067b`** -- identiques au
fingerprint permanent deja consigne pour tout lot qui ne touche pas le
code moteur, coherent avec un diff limite a deux fichiers GDScript.
`index.pck` local **34 352 624**, marqueur et jamais preuve d'identite.

CI **run #356** (id `33520699742`, job `99898905779`) **verte**
(14:38:07 -> 14:43:12 UTC) -- `Import project resources` 14:38:54 ->
14:42:33, **`Export Web build` 14:42:33 -> 14:42:39**, `Verify export
output` succes, `Deploy to Vercel [PRODUCTION -- main]` **succes**
14:42:59 -> 14:43:09, `Deploy to Vercel [STAGING -- staging]`
correctement **skipped** (push sur `main`).

**Verifie SUR LE SERVICE, pas seulement dans le log CI**, sur DEUX
marqueurs independants, tous deux `x-vercel-cache: MISS` / `age: 0` :

| marqueur | valeur servie |
|---|---|
| `CACHE_VERSION` | `1788273758` = **14:42:38 UTC** -- tombe exactement dans la fenetre `Export Web build` (14:42:33 -> 14:42:39) |
| `index.wasm` servi | **35 376 909** octets -- identique a la taille et au md5 de l'export local, le fingerprint permanent |
| `index.pck` servi | 34 352 560 octets (marqueur "nouveau build servi", jamais offert seul comme preuve d'identite) |

**Le fix du hotspot du lit (C2, anneau visuel decouple du rayon de tap,
couverture 100 % sur son ancre) est desormais EN PRODUCTION** sur
`keepy-ten.vercel.app`.

**Reste ouvert : aucun sur ce merge.** Le seul point laisse ouvert par
le lot de staging (le ressenti device du lit) est deja tranche par la
validation qui a autorise ce merge.

## L'OVERLAY DODO : YEUX FERMES ET "ZZZ" SUR L'ETAT DE REPOS DU LIT, AUCUN ETAT NEUF (2 septembre 2026)

Mathieu a confirme le chantier de la pie/du lit termine (voir la section
"MERGE EN PRODUCTION" et la section C2 ci-dessus) et a demande un ajout
purement visuel sur l'etat de repos deja existant : yeux fermes et un
"Zzz" qui derive doucement au-dessus de Keepy pendant qu'il est couche
dans le lit, sans nouvel asset 3D/2D genere et sans nouvelle machine
d'etats -- l'etat `_resting` de `CabinInterior.gd` (voir la section
"LE HOTSPOT DU LIT" plus haut) existait deja et reste le seul point
d'accroche.

### CE QUI A ETE AJOUTE

`scripts/cabin/CabinDodo.gd` (nouveau fichier, classe `CabinDodo`) : un
`Sprite3D` unshaded portant deux arcs sombres dessines en code (meme
patron que le coeur de `CabinHearts.gd` -- une texture 64x64 construite
une fois et jamais reimportee) pour les yeux fermes, et un `Label3D`
"Zzz" qui monte et redescend en boucle lente (`ZZZ_DRIFT` 0.12 unite sur
`ZZZ_DRIFT_S` 1.6 s). Aucun shader, aucune particule, aucun fichier
binaire ajoute -- la meme discipline que le reste de ce chantier.

`scripts/cabin/CabinInterior.gd` : un champ `_dodo` construit une fois
dans `_ready()` (aux cotes de `_hearts`), et deux points d'appel
seulement -- `_dodo.show_asleep(_walker.global_position)` a la fin de
`_enter_rest()` (le point ou le corps est deja pose sur le lit) et
`_dodo.hide_asleep()` au debut de `_wake()`. Aucun nouveau booleen,
aucune nouvelle transition : `_resting` reste l'unique source de verite,
exactement comme le registre de hotspots (`_bed`, `_door`, `_magpie`)
que ce fichier utilisait deja.

### CE QUI N'A PAS ETE FAIT, ET POURQUOI

Le brief envisageait de fermer les yeux du modele lui-meme si le rig le
permettait "facilement". Il ne le permet pas : `keepy_squirrel_hero.glb`
est un noeud, un maillage, sans squelette ni animation -- le meme constat
deja publie par les lots de l'ours et du hibou pour cette famille
d'assets (voir KEEPY_MODEL_MIN_Y/KEEPY_MODEL_MIN_X plus haut dans
`CabinInterior.gd`). Il n'existe donc aucun sous-noeud "yeux" a masquer
ou remplacer, et l'overlay est un indicateur pose au-dessus du corps
plutot qu'une modification du maillage.

Le positionnement de l'overlay (`EYES_OFFSET`, `ZZZ_OFFSET` dans
`CabinDodo.gd`) est un choix raisonnable dans l'espan vertical
(~1.32 unite monde) que le corps couche occupe, PAS une mesure faite sur
un rendu -- aucun editeur Godot n'etait disponible dans ce sandbox
distant pour produire un rendu de calibration. A rejuger sur device si
le rapport de Mathieu le signale hors-cible.

### VALIDATION

Aucun binaire Godot dans ce sandbox distant : pas de sonde `CabinProbe`
executee ici. La compilation GDScript a ete verifiee via CI GitHub
Actions plutot qu'en local -- `web-build.yml` declenche manuellement
(`workflow_dispatch`) sur la branche `claude/bed-overlay-visual-fxcfkd`,
run #373, **succes**, import + export Web build verts (16:38:18 ->
16:43:04 UTC), les deux etapes de deploiement Vercel correctement
skippees (`ref != main/staging`).

Merge sur `staging` : `9af2ea4..495a0f8`, `--no-ff`, diff de l'arbre du
merge contre l'arbre de la feature branch **VIDE** (verifie avant push).

Deploiement staging verifie SUR LE SERVICE, canal MCP Vercel : deploiement
`dpl_8Js4GXSRP4J1aPhXW2TkixuEkeja` (sha `495a0f8`, `gitRootDirectory`
`build/web`), **READY**, cree 17:32:22 UTC. `CACHE_VERSION` servi
`1788370317` = **17:31:57 UTC**, lu en **MISS/age 0** (cache-buste),
tombe juste avant l'appel `vercel deploy` -- coherent.

⚠️ **`index.wasm` NON RECROISE cette fois** : le fetch du binaire 35 Mo
via l'outil MCP Vercel disponible dans ce sandbox (`web_fetch_vercel_url`)
a fait expirer la session MCP a trois reprises de suite -- reproductible
sur ce fichier precis, alors que la meme methode fonctionne sans probleme
sur `index.service.worker.js` (quelques Ko) et sur les appels
`list_deployments`. Ce lot ne touche que deux fichiers GDScript, aucun
code moteur, et "Verify export output" en CI a confirme un `.wasm` non
vide -- mais la taille/md5 exacts (35 376 909 octets /
`af4a8fc2925d992348eb30deeeb54360`, le fingerprint permanent de ce
depot) n'ont pas pu etre recroises par ce canal dans ce sandbox. A
recroiser par une session qui dispose d'un canal capable de recuperer ce
fichier, ou depuis un poste avec acces direct au CDN.

**Reste ouvert : validation device par Mathieu sur
`keepy-staging.vercel.app`** (Safari iPhone, navigation privee, jamais la
PWA) -- tap sur le lit -> yeux fermes et Zzz visibles ; re-tap -> retour
a la normale, sans minuteur automatique. Palier 2 (merge vers `main`)
reste gate par son feu vert explicite apres cette validation.

## L'OVERLAY DODO : RECON DU BUG "RIEN NE S'AFFICHE" ET REDESIGN EN BULLE-NUAGE (2 septembre 2026)

Validation device sur `keepy-staging.vercel.app` (Safari iPhone, navigation
privee) du merge precedent (`495a0f8`) : **rien ne s'affiche** au tap sur le
lit, ni yeux fermes ni "Zzz" -- seul le label d'interaction du hotspot
("Lit") est visible, ce qui est normal et sans rapport avec l'overlay.

### PHASE 1 -- RECON, les quatre hypotheses du triplet evident

1. **Le declenchement** -- lu dans le code, pas suppose : `_enter_rest()`
   est le SEUL site qui met `_resting = true`, et il appelle
   inconditionnellement `_dodo.show_asleep(...)` juste apres avoir pose le
   corps. Confirme par elimination : `_ready()` va jusqu'au bout sur ce
   chemin (le label du hotspot du lit, construit PLUS TARD dans la meme
   `_ready()` que `_dodo`, s'affiche bien -- une exception au milieu de
   `_build_magpie()` qui construit `_dodo` aurait aussi empeche ce label
   d'exister).
2. **Le noeud/l'arbre** -- `_dodo` est cree, ajoute a `_props`, `setup()`
   appele de facon synchrone, aucun retour anticipe sur ce chemin. Rien
   dans le fichier ne cache ou n'ecrase `_dodo` apres coup (`_refresh_proximity()`,
   `_pulse_if_near()` : aucun des deux ne le touche).
3. **Le build** -- fraicheur RECROISEE cette fois (le lot precedent ne
   l'avait pas pu, `index.wasm` faisant expirer la session MCP a trois
   reprises) : `CACHE_VERSION` servi `1788370975` = 17:42:55 UTC, lu en
   MISS/age 0 ; `index.js` etag `4e08904b1b7107858246af44b602067b`
   **identique** au fingerprint permanent de ce depot pour ce fichier, lu
   lui aussi en MISS/age 0 -- signal independant que le moteur n'a pas
   bouge et que la lecture n'est pas une copie de bord perimee.
   `index.wasm` reste non recroisable par ce canal (meme echec MCP que le
   lot precedent, reproductible), mais l'etag de `index.js` suffit a fermer
   cette hypothese : le build sert bien le code de ce lot.
4. **Le cadrage camera** -- calcul, pas suppose : projection du point
   `BED_SPOT + EYES_OFFSET/ZZZ_OFFSET` a travers la transform fixe du
   `Camera3D` de `CabinInterior.tscn` (matrice + origine lues dans le
   `.tscn`). Le point tombe a une profondeur camera-locale d'environ
   -13.2 a -13.6 (devant la camera, pas derriere), avec une position
   verticale/horizontale locale largement a l'interieur de la demi-etendue
   du frustum aux FOV/aspect de la scene (~5.5 unites de marge de chaque
   cote contre un ecart mesure de moins de 2 unites). Le point est donc
   bien visible a l'ecran, pas hors-cadre.

**Conclusion de la Phase 1** : les quatre hypotheses du triplet (et le
cadrage, ajoute en quatrieme) sont fermees. Il ne reste que ce que le lot
precedent avait lui-meme signale ne jamais avoir verifie : "le
positionnement de l'overlay... est un choix raisonnable... PAS une mesure
faite sur un rendu -- aucun editeur Godot n'etait disponible... A rejuger
sur device." Chiffrage a la meme camera : le "Zzz" (`Label3D`, `font_size`
40 x `pixel_size` 0.0032 = 0.128 unite monde) a une profondeur d'environ
13.5 unites, soit ~12 px de hauteur ecran sur un viewport de 1920 px de
haut -- minuscule sur un telephone. Les yeux fermes n'avaient par ailleurs
aucune garantie de contraste : la meme encre sombre que tous les contours
de cette scene, posee directement sur la fourrure de Keepy, sans halo. Ni
l'un ni l'autre ne leve d'erreur -- exactement le mode de panne silencieux
deja documente dans `CLAUDE.md` ("un noeud mal positionne ou a echelle
quasi nulle ne leve aucune erreur mais reste invisible"), applique ici a
la taille/au contraste plutot qu'a la position pure.

⚠️ **Piste ecartee, et pourquoi** : le mecanisme de double-dispatch
`emulate_mouse_from_touch` deja documente plus haut dans ce fichier (le
tremblement du baiser, section C) a ete envisage -- `_on_tapped_ground()`
porte deja une lecture de `_resting` qui appelle `_wake()`, et la branche
"deja assez pres" du lit partage le meme motif "marche de longueur nulle"
que celle du baiser qui avait declenche le bug. Ecarte parce que le
`_resting` du lit avait deja ete valide sur device AVANT ce lot (voir "LE
HOTSPOT DU LIT" plus haut, confirmation de Mathieu "hotspot du lit
reactif") -- si le double-dispatch reveillait Keepy dans la meme frame que
son coucher, cette validation anterieure l'aurait deja vu echouer. Le
chemin normal (marche reelle jusqu'au lit, `_on_hop_landed()`) n'est de
toute facon pas expose au doublon d'evenements d'entree, celui-ci ne
touchant que les taps bruts. Non touche dans ce lot.

### PHASE 2 -- REDESIGN : bulle-nuage procedurale

`CabinDodo.gd` : le `Label3D` "Zzz" seul est remplace par une vraie bulle
de pensee -- un `Sprite3D` portant une texture 96x88 dessinee en code
(meme patron que le coeur de `CabinHearts.gd` et les yeux de ce fichier :
une image construite pixel par pixel une seule fois, jamais reimportee).
La forme : cinq cercles a rayons variables superposes (union par distance
signee minimale) pour le corps nuageux, plus trois petits cercles
decroissants en dessous-a-gauche reliant la bulle a la tete de Keepy --
le patron classique de bulle de pensee de BD. Remplissage clair
(`CLOUD_FILL_COLOR`), contour sombre (`CLOUD_OUTLINE_COLOR`, la meme encre
que le reste de la scene). Le "Zzz" reste un `Label3D` (dessiner du texte
pixel par pixel dans une `Image` sans police bitmap aurait ete la
complexite que le brief autorisait a eviter), repositionne au-dessus du
centre de masse des lobes et recolore en encre sombre sur fond clair
desormais garanti par la bulle -- inversion du couple texte/contour de
l'ancienne version, qui reposait sur le fond de la piece pour le contraste.

Les yeux fermes recoivent le meme traitement de contraste : un halo clair
semi-transparent (`EYES_HALO_COLOR`) dessine derriere chaque arc sur la
texture 64x64 existante, pour que le contour sombre ne depende plus du
ton de fourrure de Keepy en dessous.

La derive verticale lente est conservee, etendue a la bulle et au texte
ensemble (`Tween.set_parallel()`/`chain()`, les deux montent puis
redescendent en phase) plutot qu'au seul texte.

Aucun nouvel etat, aucune nouvelle FSM, aucun fichier binaire ajoute --
meme discipline que le reste de ce chantier. Le brief envisageait un bake
via `Polygon2D`/`Line2D` dans un `Viewport` ; le patron "image dessinee en
code" deja en place pour les yeux et le coeur s'est avere suffisant pour
une forme en union de cercles, evitant le risque d'un second `SubViewport`
dans une scene qui en a deja un pour le monde 3D.

### VALIDATION

Aucun binaire Godot dans ce sandbox distant, comme pour le lot precedent --
pas de sonde `CabinProbe`. Compilation verifiee par le meme canal :
`web-build.yml` en `workflow_dispatch` sur la branche de ce lot.

**Reste ouvert : validation device par Mathieu sur
`keepy-staging.vercel.app`** (Safari iPhone, navigation privee, jamais la
PWA) -- tap sur le lit -> yeux fermes ET bulle-nuage "Zzz" clairement
visibles cette fois ; re-tap -> retour a la normale. Si la taille/position
reste hors-cible malgre l'agrandissement, le prochain lot doit reprendre le
meme calcul de projection camera fait ici plutot que de re-deviner des
offsets. Palier 2 (merge vers `main`) reste gate par ce feu vert.

## L'OVERLAY DODO : LA BULLE MARCHE, LES YEUX NON -- LE FIX HALO ETAIT TROP TIMIDE (2 septembre 2026, meme jour)

Validation device du merge precedent (`4f671d2`) : la bulle-nuage "Zzz" est
visible et correcte -- **mais les yeux fermes ne le sont pas, meme visage
qu'avant ce lot.** Diagnostic demande avant tout redeploiement.

### CE QUI A REELLEMENT CHANGE DANS LE COMMIT PRECEDENT (`f42382a`)

Verifie par `git show`, pas suppose : le code des yeux A ETE MODIFIE (un
halo `EYES_HALO_COLOR` a ete ajoute), mais deux choses sont restees
identiques a l'original casse : `EYES_SIZE` (0.30, inchange) et l'alpha du
halo (0.85, semi-transparent). Le fix qui a fonctionne pour le "Zzz" a
change DEUX axes a la fois -- un remplissage OPAQUE et une taille monde
plusieurs fois plus grande (`CLOUD_WORLD_WIDTH` 0.62 contre les 0.128 du
`Label3D` d'origine). Le fix des yeux n'avait touche QUE le contraste
(et de facon partielle, translucide), jamais la taille -- exactement le
diagnostic que l'utilisateur a lui-meme pose.

### PREUVE AVANT REDEPLOIEMENT -- rendu hors-Godot de l'algorithme exact

Aucun Godot dans ce sandbox distant, donc pas de capture d'ecran du jeu
lui-meme -- mais l'algorithme de dessin de pixels de `_eyes_texture()` est
un simple parcours de boucle sans dependance moteur, rejouable tel quel en
Python. Reproduit l'algorithme EXACT (meme halo/arc, memes coordonnees) des
deux versions, composite sur un swatch de fourrure chaude et sur le vert
sombre de l'ambiance de la cabine, puis redimensionne a la taille ecran
simulee (calcul de profondeur camera deja etabli au lot precedent, ~95,9
px/unite-monde) :

- **Version halo (f42382a, telle que servie)** : a sa taille simulee reelle
  (29 px), la forme reste lisible sur le swatch synthetique de ce test --
  mais c'est un swatch PLAT, favorable ; une fourrure texturee reelle avec
  ses propres variations de ton peut se confondre avec un halo a 85 %
  d'opacite qui, par construction, se teinte partiellement de ce qu'il y a
  dessous. Le rapport device ("meme visage qu'avant") est la mesure qui
  tranche, pas ce rendu de confort.
- **Version corrigee (fond opaque + contour, taille relevee)** : meme
  rendu, agrandi a 40 px simule, nettement plus lisible aux DEUX fonds.

### CORRECTIF -- meme patron que la bulle, applique aux yeux

`CabinDodo.gd`, uniquement `_eyes_texture()`/`EYES_SIZE` -- **le Zzz n'est
pas touche** :
- `EYES_HALO_COLOR` (semi-transparent) retire, remplace par le MEME couple
  `CLOUD_FILL_COLOR`/`CLOUD_OUTLINE_COLOR` que la bulle -- pas une troisieme
  paire de couleurs inventee, doctrine "un fait publie une fois".
- Chaque oeil est maintenant une ellipse pleine (`EYES_RX`=15,
  `EYES_RY`=11, calculee par distance signee normalisee, meme decoupage
  remplissage/contour que `_cloud_texture()`) au lieu d'un halo
  semi-transparent -- OPAQUE, donc garanti de contraster quel que soit ce
  qu'il y a dessous, contour sombre inclus.
- `EYES_SIZE` : 0.30 -> 0.42 (+40 %), le meme mouvement de taille que la
  bulle plutot qu'un ajustement cosmetique.
- Le trait de paupiere fermee (l'arc) est redessine PAR-DESSUS ce fond
  plein, legerement plus epais (4 px contre 3).

### VALIDATION

Aucun binaire Godot dans ce sandbox distant. Rouge-avant-vert applique a
la mesure disponible : rendu Python de l'algorithme AVANT (halo, echoue
sur device) confronte au rendu APRES (fond plein, meme algorithme que la
bulle qui, elle, a ete confirmee visible) -- les deux images sont jointes
au rapport de fin de tache. Compilation GDScript verifiee par CI
(`web-build.yml`).

**Reste ouvert : validation device par Mathieu**, cette fois specifiquement
sur les yeux (la bulle est deja actee bonne, ne pas la retester). Palier 2
reste gate par ce feu vert.

