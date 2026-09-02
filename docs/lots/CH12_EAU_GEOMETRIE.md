# Eau — géométrie des cinq corps, lake, stream, spawn-lake

> Extrait de `CLAUDE.md` par le LOT H (2 septembre 2026), **verbatim** : aucune ligne réécrite, résumée ni supprimée.
> 5 section(s), 1425 lignes d'origine.
> Doctrine permanente : voir `CLAUDE.md`. Index des chantiers : `docs/lots/INDEX.md`.

## HUB : NOUVEAU TYPE `lake` -- un grand plan d'eau bleu clair, 2,5x le pond, dans la couronne exterieure (25 aout 2026)

Branche `claude/keepy-lake-type-4bxvqc`, partie de `main` (`6b4b46f`, la ref la
plus recente du depot : `main..staging` est VIDE, `staging` est entierement
mergee -- aucune session concurrente). **CONTRAINTE DURE TENUE** :
`HubTapInput.gd` (`PLATEAU_HALF_EXTENT` reste **35.0**), `HubCamera.gd`,
`KeepyHopper.gd` et `HubWorld.tscn` **ne sont PAS dans le diff**, verifie par
`git diff --stat` et pas suppose.

### R1 -- le pond, lu dans le code plutot que decrit

`_make_pond()` construit **DEUX disques plats**, tous deux `CylinderMesh` et
jamais `PlaneMesh` (un plan est simple face, et un spectateur qui verrait cet
ecran depuis sous l'horizon trouverait l'eau simplement absente) :

| disque | rayon | hauteur | y | segments | couleur |
|---|---|---|---|---|---|
| berge (opaque) | **3,62** | 0,05 | 0,03 | **24** | `POND_BANK_COLOR` `(0,22, 0,21, 0,15)` |
| eau (alpha) | **3,20** | 0,06 | 0,05 | **24** | `POND_WATER_COLOR` `(0,16, 0,30, 0,36, 0,55)` |

Les hauteurs sont ce qui le sort du z-fight : le sol est un `PlaneMesh` a
**exactement y = 0**, le dessous de la berge est a 0,005 et celui de l'eau a
0,02, donc ni l'un ni l'autre n'est jamais coplanaire avec lui. Et
`material.transparency = TRANSPARENCY_ALPHA` est **pose explicitement** : le
canal alpha d'`albedo_color` est ignore tant que `transparency` reste a
`DISABLED`, donc l'eau rendrait en teal opaque plat **sans aucune erreur pour
le dire**.

⚠️ **Les props de bordure du pond ne sont PAS une coincidence de placement,
et ce n'est pas non plus un mecanisme de code** : `hub_layout.tres` pose
**quatre souches** a d = 3,99 / 4,09 / 4,13 / 4,16 du centre, soit
**0,37 a 0,54 au-dela de la berge de 3,62**. C'est de la donnee, pas de la
geometrie generee -- `_make_pond()` ne sait rien d'une rive. Cette marge de
0,37-0,54 est le PRECEDENT que la rive du lac reproduit.

### R2 -- ce qui est batche, et pourquoi le lac ne l'est pas

Batches en `MultiMeshInstance3D`, un par paire **(mesh, couleur)** et non par
type semantique : `tree` (2 batches), `rock`, `bush` (2 instances d'UN batch),
`flower` (tige + 3 batches de corolle). Individuels : `portal` (c'est un
`Area3D` auquel `HubWorld` connecte un signal), `landmark` (3 a 5 meshes,
batcher echangerait 31 noeuds contre ~12 et perdrait la lisibilite par
variante), **`pond`** (une seule instance, rien a batcher, et la seule surface
alpha de l'ecran) et **`stump`** -- dont l'en-tete de `HubBuilder.gd` dit
explicitement que la raison est un calcul cout/benefice (13 noeuds economises
sur ~220 liberes) **et pas** sa couleur fixe, laquelle est au contraire le cas
le plus simple a batcher.

**`lake` rejoint la liste des individuels pour la raison du pond : il y en a
UN.** Il n'y a rien a batcher.

### R3 -- l'anneau exterieur est PLEIN, et c'est le vrai resultat de la recon

Douze landmarks, pas huit (le lot D en a ajoute quatre au far-ring) :

| anneau | rayon | azimuts |
|---|---|---|
| interieur | ~12,6-12,8 | 0 / 92,5 / 177,3 / 271,8 |
| median | ~20,9-22,1 | 47,0 / 133,0 / 227,5 / 313,0 |
| **far-ring (lot D)** | **~30,2-30,9** | **67,5 / 157,5 / 247,5 / 337,5** |

⚠️ **Balayage exhaustif (azimut 0-360 par 0,1 deg x rayon 20,0-33,0 par 0,1) :
il n'existe AUCUNE position, a AUCUNE taille >= 2,5x, ou un disque de cette
envergure ne recouvre pas au moins un prop de scatter.** A 3,0x et a 2,81x il
n'existe meme aucune position LEGALE (le disque ne peut pas degager les
landmarks et tenir dans les bornes en meme temps) ; a 2,69x le meilleur point
recouvre **8** props ; a **2,50x** le meilleur en recouvre **3**. Le blocage
n'est pas un prop en particulier, c'est la densite que les lots A/B/C ont
installee.

**Le secteur le plus libre est l'OUEST**, entre le landmark median a
az 227,5 et le rock a az 290,7. Le bord haut de la taille est fixe par la
borne `|x| + rayon_berge <= 34,2`, pas par les props.

### Ce qui est livre

`&"lake"` : **eau r = 8,00, berge r = 9,05** -- le pond a **2,50x exactement,
sur les deux disques**, donc la rive garde sa proportion au lieu de devenir un
cheveu sur un disque bien plus grand. Centre **(-25,10 ; -5,30)**, r 25,65,
az 281,9.

⚠️ **Les HAUTEURS ne sont PAS mises a l'echelle** (0,05 / 0,06, y 0,03 / 0,05,
identiques au pond) : une dalle d'eau de taille lac epaisse de 0,15 montrerait
sa propre tranche, la seule chose qu'une surface d'eau plate ne doit pas faire.
`_make_pond()` et `_make_lake()` appellent desormais **le meme
`_make_water_body()`** -- les deux ne peuvent donc plus diverger ni sur ces
hauteurs ni sur le piege `TRANSPARENCY_ALPHA`.

**Tessellation 40 et non 24, et le critere est la deviation ABSOLUE de facette,
qui grandit avec le rayon.** Calcule, pas estime :

| disque | rayon | segments | sagitta |
|---|---|---|---|
| eau pond | 3,20 | 24 | 0,0274 |
| berge pond | 3,62 | 24 | 0,0310 |
| **eau lac aux 24 du pond** | 8,00 | 24 | **0,0684** *(2,5x pire, visiblement facette)* |
| **eau lac livree** | 8,00 | **40** | **0,0247** |
| **berge lac livree** | 9,05 | **40** | **0,0279** |

A 40 le lac est donc **marginalement PLUS PLAT par facette que le pond** malgre
2,5x le rayon, pour 16 segments de plus. Ca reste une tessellation basse et
explicite (regle §7.2), simplement calibree sur la taille au lieu d'etre heritee
d'un disque plus petit.

### La teinte : DIFFERENTE, et l'ecart est plus grand RENDU qu'AUTORISE

`LAKE_WATER_COLOR = Color(0.30, 0.46, 0.82, 0.55)`, constante **LOCALE** au hub
comme toutes les couleurs de decor du plateau -- rien n'est promu dans
`SwampPalette`. La berge **reutilise `POND_BANK_COLOR`** : une berge est une
berge, exactement le raisonnement qui fait partager au `stump` la couleur
d'ecorce des arbres.

| | autorise (albedo) | **rendu, mesure** |
|---|---|---|
| eau pond | hsv(198,0 / 0,556 / 0,360) | `rgb(39,57,56)` = hsv(**176,7** / 0,316 / 0,224) |
| eau lac | hsv(221,5 / 0,634 / 0,820) | `rgb(56,76,110)` = hsv(**217,8** / 0,491 / 0,431) |
| **ecart de teinte** | **23,5 deg** | **41,1 deg** |

Mesure sur des PIXELS, a **distance camera IDENTIQUE** (25,08 u, donc 33,1 % de
fog des deux cotes -- Keepy pose 15 u au +Z de chaque plan d'eau, la camera du
hub ne lacetant jamais). **Les deux fenetres d'echantillon sont a 100 % de
l'objet** : 2 valeurs 8 bits distinctes pour le pond, 3 pour le lac (le degrade
de fog en travers du disque), zero pixel de sol ou de ciel -- donc aucune des
deux mesures n'est contaminee et l'ecart entre elles EST la couleur de l'objet.
L'ecart de teinte est **plus grand rendu qu'autorise**, parce que le sol vert
qui transparait a travers l'alpha tire le teal du pond vers le vert alors que le
bleu plus fort du lac y resiste.

### Placement -- les invariants sont mesures, pas argumentes

| contrainte | valeur |
|---|---|
| tout point du lac : `\|x\|` max | **34,15** *(borne auto-imposee 34,2 ; garde-fou 35,0)* |
| tout point du lac : `\|z\|` max | 14,35 |
| props a l'interieur de l'eau (r 8,0) | **0** |
| props a l'interieur de la berge (r 9,05) | **0** |
| landmark le plus proche, degagement de la berge | **+4,20** |
| portail le plus proche, degagement de la berge | +10,66 |
| pond | a l'oppose du plateau, aucune interaction |

**Fog a la position choisie, formule `1 - exp(-d*0,016)` sur la distance
CAMERA-objet et non sur le rayon :** **37,9 %** vu du centre du plateau
(29,82 u), **29,4 %** sur sa rive proche, 60,1 % depuis le bord oppose. Le lac
est donc **moins delave que les landmarks du far-ring** (47,4 % projetes au
lot D pour r ~30,5) et dans la meme bande que l'anneau median (39,3 %) --
c'est ce que le rayon 25,7 achete contre 30.

⚠️ **TROIS PROPS SONT DEPLACES, PAS SUPPRIMES, et c'est le cout reel du lot.**
Aucune position ne recouvrait zero prop (R3). Deux rochers et un arbre dont le
centre tombait dans l'eau sont **relocalises sur la rive** : un lac occupe du
sol, donc ce qui s'y tenait passe au bord, et le plateau garde son compte.
S'y ajoutent **2 rochers neufs**, ce qui donne **4 rochers de rive** -- le meme
idiome que les 4 souches du pond, et le bas de la fourchette 4-6 demandee.
**Aucun nouveau TYPE de bordure** : ce sont des entrees `&"rock"` ordinaires,
donc elles coutent 4 INSTANCES dans le batch `Rock` existant et **zero noeud**.

Une souche preexistante tombait **sur la berge** (d = 8,50, entre l'eau 8,0 et
la berge 9,05) : poussee a d = 9,50 comme les quatre rochers, soit **0,45
au-dela de la berge -- exactement la marge 0,37-0,54 des souches du pond**.
Cinq props de rive au total, tous a d = 9,50.

**Le garde-fou de bornes n'a rien eu a recabler** (il lit le dictionnaire du
layout, jamais l'arbre de scene) et **il est reste SILENCIEUX au boot** : la
confirmation a l'execution que les 168 entrees sont atteignables.

### Cout : +2 noeuds, exactement le nombre predit

Mesure des DEUX cotes dans cette session, worktree separe sur `origin/main`,
meme machine, meme commande, 3 runs chacun :

| | draw hors portails | total | construction |
|---|---|---|---|
| AVANT (`6b4b46f`) | **72** | **78** | 47,3-51,1 ms |
| **APRES** | **74** | **80** | 43,3-46,6 ms |

**+2 : la berge et l'eau.** Les 8 batches `MultiMesh` sont **intouches**.
Marge sous le plafond de 260 : **188 -> 186**. Draw nodes identiques sur
**six** runs consecutifs. Tout le reste est dans le bruit documente de ce
sandbox (la construction BAISSE en ajoutant deux noeuds -- c'est le plancher de
bruit, pas un gain). Ligne complete et lecture detaillee :
`docs/HUB_PERF_BASELINE.md`.

### Validation

Editeur + templates Godot 4.3-stable installes dans ce sandbox (releases GitHub
officielles, **tailles verifiees contre le `Content-Length`** -- 50 276 070 et
1 073 228 327 octets, aucune troncature silencieuse). Import headless
**exit 0**, **24 `.scn`** (import complet verifie, pas suppose). Boot headless
de `HubWorld.tscn` **exit 0, aucun `push_warning`, aucune erreur**. Export Web
release **exit 0, 0 ligne d'erreur**.

`index.wasm` **35 376 909 octets** / md5
**`af4a8fc2925d992348eb30deeeb54360`**, `index.js` md5
**`4e08904b1b7107858246af44b602067b`** -- identiques au fingerprint deja
consigne pour tout lot qui ne touche pas le code moteur. `index.pck`
**5 834 608** (export unique et propre, `build/` ET `.godot/` supprimes avant --
a lire avec la mise en garde permanente sur son instabilite, jamais offert comme
preuve). **Piege payload tenu** : **0** ligne `Storing File` pour
`assets_source`, `scripts/dev`, `docs`, `web` ou `build`, sur 219.

Sondes : `ProbeTimeoutAudit` (**38 sondes scenes**, retour exact a la baseline
apres suppression de la sonde de capture jetable), `AssetContractAudit`
(**12/12 visuels, 0/10 colliders deplaces**), `DeathModelAudit`,
`ChargerShapeProbe` -- **toutes exit 0**. **Non-applicabilite VERIFIEE par
grep** : aucune sonde de `scripts/dev/` ne reference `HubWorld`, `HubBuilder`,
`HubTapInput` ni `hub_layout`, hormis `HubPerfBaseline` qui ne tape jamais.

⚠️ **DEUX rendus reels captures** (1080x1920, `xvfb-run --rendering-driver
opengl3`, sonde jetable supprimee avant commit) : le lac s'affiche comme un
grand disque bleu a rive sombre, **bord lisse, aucun facettage visible**, et
nettement bleu contre le vert du plateau. Vu du centre il est **hors cadre** --
la camera ne lacete jamais (fov horizontal 45 deg) et le lac est lateral,
exactement comme le pond ; il entre dans le champ quand Keepy se deplace vers
lui, ce que la seconde capture confirme.

⚠️ **Piege de sonde re-rencontre, deja consigne pour `DecorStabilityAudit`** :
une capture qui `await RenderingServer.frame_post_draw` en boucle sous llvmpipe
**depasse 10 minutes sans rien produire**. Reecrite en pilotant `_process` avec
un compteur de frames : deux captures en quelques secondes. Deuxieme piege du
meme run : les chemins de noeuds de `HubWorld.tscn` sont
`WorldViewport/SubViewport/World`, et la camera s'y appelle **`Camera3D`** et
non `HubCamera` -- un `get_node()` faux rend `null` et le `set_process(null)`
qui suit **spamme sans jamais s'arreter**.

### Reste ouvert -- jugement device, seul juge

1. **Est-ce qu'un disque bleu clair de 16 unites de large se lit comme de
   l'EAU** a l'echelle reelle d'un telephone, ou comme une tache peinte ? La
   teinte, la sagitta et l'alpha sont mesures ; la lecture ne l'est pas.
2. **La rive** : la berge reprend la couleur du pond, donc c'est un anneau
   sombre de 1,05 de large la ou le pond en a 0,42. Proportionnel et assume,
   jamais juge a l'oeil.
3. **Le lac est LATERAL**, a ~6 taps de cote depuis le centre (l'asymetrie de
   visee deja mesuree au lot D : un tap vers l'avant traverse tout le plateau,
   un tap de cote ne porte que ~5,15 u). Il se decouvre en s'en approchant, pas
   depuis le centre.
4. **3 props deplaces** -- mesure comme le minimum possible a 2,5x, mais c'est
   une modification d'un decor deja valide sur device.

### Deploiement staging du lot lake (palier 1, automatique)

`staging` **`47dac76`** (merge `--no-ff`, arbre **byte-identique** a la branche
feature : meme hash d'arbre `fd0cd689` des deux cotes, verifie AVANT le push).
CI run **#229** (id `32862216768`). **`main` NON touche** (`origin/main`
toujours `6b4b46f`, verifie apres le push) : palier 2, gate Mathieu apres
validation device.

**Verifie SUR LE SERVICE, pas dans le log CI, et sur DEUX marqueurs
independants** :

| marqueur | avant | apres |
|---|---|---|
| `CACHE_VERSION` | `1787664307` = **13:25:07** (run #227) | **`1787669738` = 14:55:38** *(dans la fenetre du run #229, demarre 14:52:15)* |
| `.pck` servi | 5 833 632 | **5 834 592** |
| `.wasm` servi | 35 376 909 | 35 376 909 *(inchange, attendu)* |

Les deux lectures « avant » et les deux lectures « apres » sont
`x-vercel-cache: MISS` avec `age: 0` -- aucun bout n'est une copie CDN gelee.

⚠️ **Le piege de lecture HIT/age s'est reproduit DEUX fois en cours de run et a
ete REFUSE les deux fois** (14:53:01 age 102, 14:53:36 age 137) : un HIT avec
un `age` non nul n'est pas une mesure de fraicheur, donc ces lectures n'ont pas
ete comptees comme la preuve « c'est encore l'ancienne valeur ».

⚠️ **Le piege du run gele s'est reproduit aussi** : l'API Actions tenait le run
#229 a `status: in_progress`, `updated_at` bloque a 14:52:21, bien apres que le
deploiement soit tombe. C'est le `CACHE_VERSION` servi qui a tranche, comme aux
runs #201, #202 et #226.

⚠️ **`curl` direct vers `*.vercel.app` reste refuse par le proxy de ce sandbox**
(un poll de 30 s x 10 n'a rien emis) : le canal MCP Vercel est le seul
disponible ici, comme deja consigne.

Le `.pck` servi (5 834 592) est 16 octets sous l'export local propre de cette
session (5 834 608) -- l'instabilite deja documentee, pas un autre build.

## HUB : NOUVEAU TYPE `stream` -- un ruisseau relie la mare au lac, et la MESURE a corrige DEUX fois la consigne (25 aout 2026)

Branche `claude/stream-pond-lake-connector-ocs0ko`, partie de `main`
(`92d00be`, le merge du lot lake -- `main..staging` VIDE, `origin/main` est
donc la ref la plus a jour du depot, aucune session concurrente).
**CONTRAINTE DURE TENUE** : `HubTapInput.gd`, `HubCamera.gd`,
`KeepyHopper.gd` et `HubWorld.tscn` **ne sont PAS dans le diff**, verifie par
`git diff --stat`. Aucune collision ajoutee : le ruisseau est purement
visuel, comme tout le decor du plateau.

### R1 -- ruban SurfaceTool, PAS CSGPolygon3D : quatre raisons, dans l'ordre ou elles ont tranche

1. ⚠️ **Il n'existe PAS UN SEUL noeud CSG dans tout le depot** -- `grep`
   sur `*.gd`/`*.tscn`/`*.tres` : **zero occurrence**, et `SurfaceTool`/
   `ArrayMesh`/`Curve3D`/`Path3D` non plus (la seule mention d'`ArrayMesh`
   est un commentaire de `TrackSegment.gd`). Tout le decor du hub est une
   primitive construite en code. Un ruisseau n'est pas l'endroit ou
   introduire un second paradigme.
2. **CSG est un solveur a l'execution** : un `CSGShape3D` garde un brush et
   le re-evalue, et il porte un `use_collision` qu'il faudrait tenir
   explicitement a `false` contre la regle permanente « rien sur le plateau
   n'a de physique ». Un `ArrayMesh` est cuit une fois, ici, et n'a aucun
   drapeau qui puisse devenir un collider par defaut.
3. **Controle des segments.** Le mode Path de `CSGPolygon3D` subdivise par
   un `path_interval`, une poignee INDIRECTE sur ce qui compte vraiment --
   la deviation de facette d'une courbe. `STREAM_SAMPLES_PER_SPAN` la fixe
   directement, exactement comme `LAKE_SEGMENTS` avait ete calibre sur son
   rayon.
4. **Un noeud CSG n'est pas un `MeshInstance3D`**, donc il ne passerait pas
   par `_unshaded()` -- et le fait que ce fichier n'ait qu'UNE seule usine a
   materiau est ce qui tient toutes les surfaces du plateau.

### R2 -- le schema : `PackedVector3Array`, VERIFIE par ecriture/relecture AVANT d'y batir quoi que ce soit

Un projet Godot jetable a servi a tester la serialisation reelle, pas a la
supposer. **Les trois formes imbriquees dans un `Dictionary` dans un
`Array[Dictionary]` exporte font l'aller-retour**, en ecriture par
`ResourceSaver` **et** en `.tres` ECRIT A LA MAIN (le cas qui compte, puisque
`hub_layout.tres` s'edite en texte) :

| forme ecrite a la main | rechargee en | valeurs |
|---|---|---|
| `[Vector3(...), Vector3(...)]` | `TYPE_ARRAY` (28) | exactes |
| `PackedVector3Array(...)` | `TYPE_PACKED_VECTOR3_ARRAY` (36) | exactes |
| `Array[Vector3]([...])` | `TYPE_ARRAY` (28) | exactes |

**`PackedVector3Array` retenu** : type par construction (un flottant egare
ou un `Vector2` dans la liste est une erreur de parse, pas une forme
silencieusement differente), et il tient sur une seule ligne du fichier.

⚠️ **`&"stream"` est le SEUL type qui porte une TRACE au lieu d'une
POSITION** -- il n'a ni `position`, ni `rotation_y`, ni `scale`, et
`HubBuilder` `push_warning` si l'un des trois apparait plutot que de
translater silencieusement tout le cours d'eau.

### R3 -- positions LUES, pas supposees

| | centre | rive eau | rive berge |
|---|---|---|---|
| mare (`&"pond"`) | **(20,70 ; 7,40)** | 3,20 | 3,62 |
| lac (`&"lake"`) | **(-25,10 ; -5,30)** | 8,00 | 9,05 |

Centre a centre **47,528** (azimut -164,50 deg). **Bord de berge a bord de
berge : 47,528 - 3,62 - 9,05 = 34,858.**

### R4 -- ⚠️ LE TRAJET DIRECT EST ENCOMBRE : 20 props dans le couloir +-2,0

Le segment direct rive-a-rive traverse **20 props**, dont **une fleur a
0,075 de l'axe** -- litteralement au milieu du lit. Le plus proche par type :
fleur idx 70 (13,48 ; 5,32) a 0,075 ; arbre idx 103 (-15,72 ; -3,15) a 0,435 ;
rocher idx 20 (4,62 ; 2,49) a 0,435 ; buisson idx 36 (5,92 ; 4,42) a 1,078 ;
landmark idx 56 (-12,75 ; -0,40) a 1,422 ; souche idx 152 (17,61 ; 4,72) a
1,757. Un trace courbe etait donc bien necessaire.

⚠️ **PREMIERE CORRECTION DE LA CONSIGNE, MESUREE : « 2-3 points de controle
intermediaires » NE SUFFIT PAS.** Le brief le donnait comme estimation ; la
mesure la contredit. Recherche exhaustive (Dijkstra bottleneck sur une
grille au pas 0,25, puis plus-court-chemin sous contrainte de clearance,
puis descente locale sur la spline reelle) :

| points de controle | meilleure clearance atteignable |
|---|---|
| **3** | **-0,407** -- un prop est 0,41 A L'INTERIEUR de l'eau, **impossible** |
| 4 | +0,039 -- faisable, marge nulle |
| 7 | +0,172 |
| **12 (livre)** | **+0,419** |

**12 points de controle**, donc, et ce n'est pas un compromis : une seule
entree de layout, une seule ligne de `PackedVector3Array`, et c'est ce a
quoi ressemble un ruisseau qui meandre.

### ⚠️ SECONDE CORRECTION, ET C'EST LE RENDU QUI L'A TROUVEE : la clearance NE SUFFIT PAS COMME METRIQUE

**Une premiere trace a 12 points passait la clearance a +0,391 et etait
POURTANT defectueuse.** La capture offscreen montre un **pincement en
eventail** : le ruban se replie sur lui-meme. Cause mesuree :

> **Un ruban dont le rayon de courbure descend sous sa propre demi-largeur
> SE REPLIE** -- le bord interieur se croise et la surface pince. La
> metrique de clearance ne peut PAS voir ca : l'axe reste parfaitement
> valide.

Rayon de courbure minimum de cette premiere trace : **0,089** contre une
demi-largeur de 0,60, aux deux endroits ou la simplification RDP d'un
trajet de grille 8-connexe avait laisse des zigzags a 45 deg.

⚠️ **Piege de raisonnement dans lequel ce lot est tombe et dont il est
ressorti par la mesure** : ces paires de points rapprochees avaient ete
gardees parce que les FUSIONNER faisait chuter la clearance de +0,391 a
+0,094 -- elles etaient reellement porteuses pour CETTE metrique. Elles
etaient aussi exactement ce qui cassait le ruban. **Une contrainte mesuree
n'est pas une contrainte suffisante tant qu'on n'a pas regarde le rendu.**

Corrige en lissant le trajet de grille AVANT la simplification, puis en
optimisant contre les **deux** metriques simultanement. Trace livree :
**clearance +0,4191, rayon de courbure minimum 1,403** -- soit **2,3x la
demi-largeur**, un repli est geometriquement impossible. Verifie a l'oeil
sur un nouveau rendu : le pincement a disparu.

### Ce qui est livre

`&"stream"`, **une** entree, **12 points de controle**, largeur **1,2** :

```
PackedVector3Array(17.58, 0, 6.67, 16.1, 0, 8.01, 11.59, 0, 8.54,
  7.65, 0, 10.37, 5.43, 0, 9.95, -1.73, 0, 10, -3.9, 0, 10.14,
  -6.34, 0, 7.89, -11.14, 0, 5.97, -12.35, 0, 4.41, -14.58, 0, 3.42,
  -18.54, 0, -0.73)
```

**Centripete et pas uniforme.** Le Catmull-Rom uniforme fait de l'overshoot
dans un virage serre, et **mesure sur ce plateau cet overshoot seul poussait
le ruban 0,4 unite dans des props que la trace etait routee pour degager**.
La forme centripete (alpha = 0,5) est celle qui ne produit ni cusp ni
auto-intersection.

**Extremites exactement sur les rives EAU** (r = 3,2043 contre 3,20 et
7,9949 contre 8,00 -- l'ecart est l'arrondi a 2 decimales du fichier de
layout). Le ruban traverse donc l'anneau de berge depuis l'exterieur et
s'arrete la ou l'eau commence : **il couvre la rive au lieu de laisser un
trou, et il ne superpose jamais une surface alpha a une autre**.

**Hauteur `y = 0,095`**, au-dessus du sol (0), des berges (dessus 0,055) et
de l'eau (dessus 0,08) -- jamais coplanaire avec quoi que ce soit.
**Epaisseur ZERO, dessine double face** (`CULL_DISABLED`) :
`_make_water_body` explique deja pourquoi une surface d'eau plate ne doit
jamais montrer sa propre tranche ; un ruban sans epaisseur ne le peut pas,
et le double face repond par construction a l'objection « un plan est simple
face » qui avait impose `CylinderMesh` aux deux disques.

### La troisieme teinte d'eau : chaque paire separee sur un axe DIFFERENT

| | HSV | lecture |
|---|---|---|
| mare | hsv(198,0 / 0,556 / **0,36**) | teal sombre |
| lac | hsv(**221,5** / 0,634 / 0,82) | bleu clair |
| **ruisseau** | hsv(**190,9** / 0,512 / **0,86**) | cyan vif |

**ruisseau vs mare** : 7,1 deg de teinte -- separes par la **VALEUR**
(0,86 contre 0,36, la moitie de l'echelle).
**ruisseau vs lac** : valeur quasi identique -- separes par la **TEINTE**
(30,6 deg, ce qui franchit la frontiere cyan/bleu).

S'appuyer sur un seul axe pour les deux paires en aurait fait s'effondrer
une : une mare plus claire se lit comme le lac, un lac decale vers le cyan
se lit comme le ruisseau. Constante **LOCALE** au hub, comme toute couleur
de decor ici.

### AUCUN prop n'est deplace -- contrairement au lot lake

**Clearance minimale +0,4191**, mesuree sur le maillage **REELLEMENT
CONSTRUIT** par `HubWorld.tscn` (sonde jetable qui lit les sommets de
l'`ArrayMesh` livre, pas mon modele) :

| prop | empreinte | d au BORD du ruban | clearance |
|---|---|---|---|
| landmark (0,60 ; 12,60) | 1,66 | 2,075 | **+0,419** |
| rocher (-13,90 ; 2,10) | 0,44 | 0,858 | +0,421 |
| rocher (-18,68 ; 1,70) | 0,71 | 1,129 | +0,421 |
| fleur (0,52 ; 8,68) | 0,22 | 0,646 | +0,424 |
| arbre (11,70 ; 7,30) | 0,16 | 0,591 | +0,431 |

⚠️ **L'empreinte utilisee est celle AU SOL, pas la silhouette** : un tronc
d'arbre fait **0,24**, son houppier 0,95 mais il flotte a 2 m de haut. Un
tronc dans l'eau est un bug ; un houppier au-dessus de l'eau est du decor,
et c'est ce que fait un vrai arbre au bord d'un ruisseau. **La distinction
est reelle et les deux chiffres sont publies plutot qu'un seul** -- quatre
houppiers surplombent le ruban de **0,044 a 0,525**, rapportes et non gates.
Les 0,42 de marge sont par ailleurs dans la meme famille que les 0,37-0,54
deja documentes pour les souches de rive de la mare.

**Ecart aux portails : 9,25 / 12,70 / 14,28** -- le ruisseau arque devant la
place des portails (`max|z|` du bord = 10,985) et n'en approche aucun.

### Garde-fou de bornes : il A FALLU l'adapter, et c'est dit explicitement

⚠️ **La doc du lot lake affirmait que le garde-fou « inspecte des noeuds ».
C'est FAUX** -- il lit `entry.get("position")` **dans le dictionnaire du
layout**, avant meme que le noeud existe. C'est pour ca que le passage en
MultiMesh n'avait rien eu a y recabler.

Mais il **fallait bien l'adapter ici**, pour une autre raison : un
`&"stream"` n'a pas de `position`, donc il serait retombe sur `Vector3.ZERO`
et aurait passe le controle **gratuitement** -- un trou silencieux dans le
seul garde-fou qui attrape un prop inatteignable. Le controle parcourt
desormais **tous les points de la trace** pour ce type. L'ordre est
preserve : il reste APRES le dispatch de type, donc un type inconnu produit
toujours une erreur et **aucun** avertissement.

**Bornes mesurees sur le ruban livre : `max|x| = 18,98`, `max|z| = 10,99`**
(bord, pas axe) contre un garde-fou a 35,0. Le boot headless de
`HubWorld.tscn` ne produit **aucun** `push_warning` -- confirmation A
L'EXECUTION que les 169 entrees sont atteignables.

### COUT : +1 noeud de dessin, exactement

| | avant (lot lake) | ce lot |
|---|---|---|
| noeuds de dessin, hors portails | **74** | **75** |
| noeuds de dessin, total | **80** | **81** |
| triangles du ruisseau | -- | **176** (88 quads, 528 sommets) |
| construction | 43,3-46,6 ms | 46,2-49,7 ms |

**Individuel et non batche** : il y en a UN, et son maillage est un ruban
unique construit pour sa propre trace -- il n'existe aucun mesh partage
qu'un `MultiMesh` pourrait repeter. **176 triangles est moins que ce que
coutent les deux disques du lac a eux seuls.** Marge sous le plafond de
260 : **179**.

### Validation

Editeur + templates Godot 4.3-stable installes dans ce sandbox (releases
GitHub officielles, **tailles verifiees contre le `Content-Length`** --
50 276 070 et 1 073 228 327 octets, aucune troncature silencieuse). Import
headless **exit 0**, **24 `.scn`** (import complet verifie, pas suppose --
le piege du faux-rouge par import tronque est controle). Boot headless de
`HubWorld.tscn` **exit 0, 0 erreur, 0 `push_warning`**. Export Web release
**exit 0**.

`index.wasm` **35 376 909 octets**, md5
**`af4a8fc2925d992348eb30deeeb54360`** ; `index.js` md5
**`4e08904b1b7107858246af44b602067b`** -- identiques au fingerprint deja
consigne pour tout lot qui ne touche pas le code moteur. `index.pck`
**5 838 128** (export unique et propre, `build/` ET `.godot/` supprimes
avant -- a lire avec la mise en garde permanente sur son instabilite,
jamais offert comme preuve). **Piege payload tenu** : sur 219 lignes
`Storing File`, **0** pour `assets_source`, `scripts/dev`, `docs`, `web`,
`build` ou `firebase.json`.

Sondes : `ProbeTimeoutAudit` (**38 sondes scenes**, retour exact a la
baseline apres suppression des deux sondes jetables), `AssetContractAudit`
(**12/12 visuels, 0/10 colliders deplaces**), `DeathModelAudit`,
`ChargerShapeProbe` -- **toutes exit 0**. **Non-applicabilite VERIFIEE par
grep, pas supposee** : aucune sonde de `scripts/dev/` ne reference
`HubWorld`, `HubBuilder`, `HubTapInput` ni `hub_layout`, hormis
`HubPerfBaseline` -- qui ne tape jamais et ne peut donc pas voir un
ruisseau.

⚠️ **Piege de sonde rencontre, a connaitre** : ma sonde de mesure
reconstruisait l'axe du ruban en moyennant des paires de sommets tirees de
la liste de triangles, et son DERNIER point moyennait deux sommets du
**meme bord** -- elle rapportait un rayon de courbure de 0,707 la ou le
ruban en a 1,403. Un defaut de la sonde qui ressemblait exactement a un
defaut du ruban. Corrige, et re-mesure.

### Reste ouvert -- jugement device, seul juge

1. **Est-ce qu'un ruban cyan de 1,2 de large se lit comme de l'EAU QUI
   COURT** a l'echelle reelle d'un telephone, ou comme une bande peinte ?
   La teinte, la courbure et la clearance sont mesurees ; la lecture ne
   l'est pas.
2. **Les trois teintes d'eau restent-elles distinguables** quand deux
   d'entre elles ne sont pas dans le meme cadre ? La separation est
   mesuree en HSV, jamais jugee a l'oeil sur device.
3. **Les embouchures** : le ruban s'arrete au bord de l'eau et couvre
   l'anneau de berge. Verifie au rendu offscreen, pas sur device.
4. **Les quatre houppiers qui surplombent le ruisseau** (0,044 a 0,525) --
   argumente comme naturel, jamais juge a l'oeil.
5. **Le ruisseau arque devant la place des portails.** Il ne les approche
   pas (9,25 minimum), mais c'est un ajout visuel notable sur l'ecran par
   lequel passe l'acces a tous les jeux.

### Deploiement staging du ruisseau (palier 1, automatique)

`staging` **`7e7822c`** (merge `--no-ff`, arbre **byte-identique** a la branche
feature : meme hash d'arbre `afdcddcf` des deux cotes, verifie AVANT le push).
CI run **#232** (id 32873944898). **`main` NON touche** (`origin/main` toujours
`92d00be`, verifie apres le push) : palier 2, gate Mathieu apres validation
device.

**Verifie SUR LE SERVICE et sur DEUX marqueurs independants**, chacun lu aux
deux bouts :

| marqueur | avant (run #230) | apres (ce lot, run #232) |
|---|---|---|
| `CACHE_VERSION` | `1787670247` = **15:04:07** | **`1787676542` = 16:49:02** *(dans la fenetre du run #232, demarre 16:46:19)* |
| `index.pck` servi | **5 834 576** | **5 838 064** |
| `index.wasm` servi | 35 376 909 | 35 376 909 *(inchange, attendu)* |

Les quatre lectures utiles portent `x-vercel-cache: MISS` et `age: 0`. La
valeur AVANT du `CACHE_VERSION` a ete relevee **avant le merge**, donc la
bascule est prouvee dans les deux sens et pas deduite du log CI.

⚠️ **Le piege de lecture s'est reproduit et a ete REFUSE** : une lecture faite
~45 s apres le push est revenue `x-vercel-cache: HIT` avec **`age: 45`** --
une copie CDN figee avant le deploiement. **Un HIT avec un `age` non nul n'est
pas une mesure de fraicheur**, donc elle n'a pas ete comptee ; les lectures
suivantes ont ete cache-bustees par un parametre de requete.

⚠️ **L'API GitHub Actions a de nouveau servi des reponses PERIMEES** : deux
appels `list_workflow_jobs` successifs avec `filter: "all"` ont rendu une
reponse **byte-identique**, figee sur « Import project resources /
in_progress » a 16:46:45, bien apres que le build ait avance. Enieme
reproduction du piege deja consigne ; c'est le `CACHE_VERSION` servi qui a
tranche, comme aux runs #201, #202, #226 et #229.

## HUB LAKE-1 : LE CLAMP DEVIENT UNE FORME, et la « presqu'ile » du brief N'A AUCUNE LONGUEUR (26 aout 2026)

Branche `claude/lake-zone-geometry-access-ses541`, partie de `staging`
(`7ec444f`). **CONTRAINTES DURES TENUES, verifiees par `git diff --stat` et
pas affirmees** : `KeepyHopper.gd` et `HubCamera.gd` ne sont PAS dans le
diff — donc `HOP_DISTANCE` (1.5), `HOP_DURATION` (0.28), `RIDE_SPEED`,
`OFFSET`, `fov` et la rotation de camera sont intouches. Le clamp carre
reste a **35.0** : l'extension passe par la FORME, jamais par le scalaire.

**Ni bateau, ni geste de drag, ni trajectoire dessinee** — c'est le lot
LAKE-2, hors perimetre. Ce lot est validable A PIED.

### 1. `HubRegion.gd` — un seul proprietaire de la forme

```
Region = ( carre(+-35) OU pad de berge ) ET PAS l'eau du grand lac
```

Deux sites l'interrogent, aucun ne redit la regle :
`HubTapInput._handle_point` -> `clamp_to()`, `HubBuilder._build` ->
`contains()`. `PLATEAU_HALF_EXTENT` **demenage** dans `HubRegion` plutot
que d'exister en double — c'est deja la raison pour laquelle il n'avait
qu'un proprietaire.

La soustraction EST la reponse a « un tap sur le lac ne doit pas envoyer
Keepy dedans » : l'eau est un TROU dans la region, donc un tap dessus est
ramene a la rive exactement comme un tap au-dela du carre est ramene au
bord. `clamp_to()` projette au plus proche point valide (candidats :
bord du carre, bord du pad, ligne d'eau, et leurs combinaisons) — un point
hors region est TOUJOURS tire dedans, jamais ignore.

⚠️ **UNE SEULE eau est soustraite, et l'asymetrie est deliberee.** La mare
et le petit lac sont marchables depuis leur livraison — la barque
s'embarque depuis la tete du ruisseau, qui est SUR la rive d'eau de la
mare — et le leur retirer serait un changement de gameplay que ce lot n'a
ni demande ni pu valider.

### ⚠️ 2. LA PRESQU'ILE DU BRIEF N'EXISTE PAS — mesure, pas une opinion

Le brief decrivait « une bande marchable RELIANT le plateau (bord 35 u) a
la berge proche du lac ». **Il n'y a rien a relier, et ce sont les deux
nombres figes qui le disent** : un lac de rayon 20 centre a 54 a sa berge
proche a **34**, alors que la frontiere du carre le long de ce meme azimut
est a **35/|axis.x| = 35,782**. La rive commence DANS le carre.

Mesure sur une grille de 0,1 u plutot qu'argumentee :

| | u² |
|---|---|
| carre RETIRE par la nouvelle eau | **27,6** |
| pad de berge AJOUTE au-dela du carre | **91,6** |

L'extension est donc reelle mais c'est un **LOBE QUI SUIT LA RIVE**, pas
une chaussee, et le gain net est plus petit que le pad seul ne le suggere.
Consigne ici pour qu'une future session ne le redecouvre pas.

⚠️ **Consequence non prevue par le brief : les deux lacs se touchent.** Le
grand lac (r 20 a 54) et le petit (r 8 a 25,65) laissent **0,347 u** entre
leurs eaux et **2,003 u de chevauchement de berges** — force par les
nombres figes, pas choisi, et le petit lac n'est pas touche. Deux disques
opaques a la meme hauteur z-fighteraient : les dalles du grand lac passent
donc SOUS celles du petit. Ordre livre, gate par sonde :

```
sol 0 < grande berge 0,013 < grande eau 0,027 < ilot 0,060
    < ponton 0,095 < petite berge 0,055 / petite eau 0,080
```

Au rendu, ca se lit comme une baie dont la rive rejoint la grande eau —
verifie a l'oeil sur capture, pas seulement calcule.

### 3. `SHORE_PAD_RADIUS = 20` — balaye, pas choisi

| pad | marchable neuf | pire traversee |
|---|---|---|
| 12 | 12,8 u² | 15,867 s |
| 16 | 38,8 u² | 17,283 s |
| **20 (livre)** | **91,6 u²** | **18,133 s** |
| 24 | 179,6 u² | 18,983 s — **passe les 22 s mais BAT la diagonale** |
| 28 | 311,9 u² | 20,117 s |

20 est le plus grand pad qui laisse la **diagonale du carre** comme pire
traversee du hub. Au-dela le budget de 22 s tient encore, mais la promesse
plus simple (« la diagonale du plateau est la plus longue marche du jeu »)
tombe.

### 4. Geometrie : trois types neufs, aucun asset Meshy

**`&"greatlake"`** — memes deux disques que la mare, r 20 / berge 21,30,
**96 segments** (la deviation de facette d'un disque est `r(1-cos(pi/n))`
et grandit avec r : les 40 segments du petit lac a r=8 donnent 0,0247, et
les reutiliser a r=20 donnerait **0,0617**, visiblement facette ; 96
ramene a **0,0107**). Teinte **hsv(254,6 / 0,62 / 0,60)**, indigo profond :

| | teinte | valeur |
|---|---|---|
| mare | 198,0 | 0,36 |
| petit lac | 221,5 | 0,82 |
| ruisseau | 190,9 | 0,86 |
| **grand lac** | **254,6** | **0,60** |

33,1° de teinte du plus proche des trois **et** 0,22 de valeur. La berge
reutilise `POND_BANK_COLOR` : une berge est une berge.

**`&"islet"`** — 3 ilots affleurants, un landmark chacun, les trois
silhouettes (spire / cairn / slabs) donc aucune paire identique. Eau libre
**5,6 a 8,3 u** jusqu'a la rive et **10,0 a 11,1 u** entre eux : navigable
pour LAKE-2. ⚠️ **Couleur CORRIGEE PAR LE RENDU** : la premiere passe
utilisait l'olive sombre des berges et les ilots se lisaient comme des
TROUS dans l'eau. Un galet clair `(0,46, 0,43, 0,31)` les rend a nouveau
comme de la terre.

**`&"pontoon"`** — 5 pontons, **batches en UN seul noeud**, face
superieure a `0,095` (la valeur de `STREAM_SURFACE_Y`, relue et non
recopiee). **Aucune fonction dans ce lot** : ils marquent ou l'embarquement
aura lieu.

⚠️ **`KeepyHopper` aplatit y a 0 sur CHAQUE ecriture de position**
(`_apply_hop` et `_on_hop_finished`), donc il n'existe aucune hauteur
d'atterrissage dans son API — et ce lot n'en ajoute pas. Un ilot 3 cm au-
dessus de l'eau se lit comme affleurant ; un vrai quai souleve casserait.

**Le sol n'a besoin d'AUCUN mesh neuf** : le `PlaneMesh` du plateau fait
deja 600x600. Le lobe est du sol de plateau ordinaire ; seule la region de
tap le rend atteignable.

### 5. `"offshore": true` — le garde-fou est INVERSE, jamais eteint

Les ilots, leurs landmarks et le lac sont volontairement hors d'atteinte a
pied. Une entree le DECLARE, et le controle devient l'inverse : une entree
`offshore` qui se revele marchable est signalee elle aussi. Un drapeau qui
ne ferait que taire des choses serait un moyen de taire une vraie erreur.
Le controle lit toujours les **DONNEES** du layout et jamais l'arbre
construit — c'est ce qui fait qu'un type a trace multi-points (`stream`) ne
passe pas au travers.

### 6. VALIDATION — `LakeZoneProbe`, 22 checks, 0 echec, exit 0

⚠️ **Elle DOIT tourner sous `xvfb`, pas `--headless`** : PHASE TAP pilote
le vrai `_handle_point`, qui a besoin d'un rect de conteneur reel ; sous le
driver DUMMY ce rect est 0x0 et la fonction sort avant de projeter quoi que
ce soit. Le rect est **asserte non degenere**, donc la sonde echoue
bruyamment au lieu de passer gratuitement.

| # | verdict | methode |
|---|---|---|
| **[a]** | **pire traversee du lobe 18,133 s** < 22 s | vrai `KeepyHopper`, `--fixed-fps 60`, frames comptees entre `hop_to()` et `became_idle` — **MESURE** |
| **[b]** | **diagonale 66 hops / 1122 frames / 18,700 s**, reproduit le chiffre publie a la frame pres, et reste le pire cas | idem, rejouee AVANT tout chiffre neuf — **MESURE** |
| **[c]** | pire `\|axe\|` atteignable **46,36** contre un sol de demi-taille **300** | balayage de la region ; la demi-taille est LUE sur le `PlaneMesh` de la scene — **MESURE** |
| **[d]** | **3/3 taps sur l'eau resolvent en terre ferme** | vrai `HubTapInput._handle_point` sur fenetre reelle 1080x1920 — **MESURE** |
| **[e]** | draw nodes hors portails **78 -> 96** (+18), 9 MultiMesh, tous `TRANSFORM_3D` | comptage de l'arbre `Props` vivant, avant/apres dans la meme session — **MESURE** |
| **[f]** | ligne ajoutee a `docs/HUB_PERF_BASELINE.md` | `HubPerfBaseline` x3 des deux cotes — **MESURE** |
| **[g]** | capture offscreen reelle, verdict ci-dessous | `xvfb-run --rendering-driver opengl3`, vraie camera du hub — **MESURE** |

Les +18 sont **comptes un par un** et non deduits : 2 disques de lac, 3
ilots, 3 landmarks (4+5+3), 1 `MultiMeshInstance3D` de pontons. Marge sous
le plafond de 260 : **182 -> 164**.

⚠️ **Le balayage Python independant et la sonde tombent sur le MEME
18,133 s** pour le pire lobe — deux chemins qui ne partagent aucune ligne
de code.

⚠️ **DEUX defauts trouves dans la SONDE, tous deux capables d'un faux
vert** : ses extremes de lobe etaient d'abord ecrits a la main et
**tombaient dans le carre** (elle chronometrait le plateau en l'appelant le
lobe) ; et PHASE TAP emet le vrai `tapped_ground`, auquel `HubWorld` repond
par un vrai `hop_to()` — sans attendre l'inactivite, PHASE CROSSING
mesurait la fin de cette chaine et rapportait la diagonale a **54 hops /
15,200 s** contre 66 / 18,700 publie. Les deux sont corriges et commentes.

**[g] VERDICT DE LISIBILITE, et il porte une limite structurelle.** Capture
depuis le lobe nord-ouest : le lac se lit clairement comme une grande eau
indigo distincte du vert, les ilots pales se lisent comme de la terre, le
spire et les slabs sont identifiables, et la jonction des deux lacs se lit
comme une langue de terre entre deux eaux. ⚠️ **Mais SEULS 2 ilots sur 3
tiennent dans un cadre** : la camera a une rotation FIXE et 45° de fov
HORIZONTAL, et le troisieme ilot est a −39,4° de l'axe depuis le meilleur
point de rive. Mesure (`unproject_position` sur les 4 points de vue),
structurel a la camera et non au placement — et c'est precisement ce que
la barque de LAKE-2 resoudra.

**Autres sondes, toutes exit 0** : `ProbeTimeoutAudit` (**42 sondes
scenes**, la nouvelle comprise, toutes armees ; la sonde de capture etait
jetable et est supprimee avant commit), `AssetContractAudit` (**12/12
visuels, pas un collider deplace**), `DeathModelAudit`,
`ChargerShapeProbe`. Import headless **exit 0**, **24 `.scn`**. Boot
headless de `HubWorld.tscn` **exit 0, 0 erreur, 0 `push_warning`** — la
confirmation A L'EXECUTION que les 203 entrees sont coherentes avec leur
drapeau `offshore`. Export Web release **exit 0, 0 erreur**. `index.wasm`
**35 376 909** / md5 `af4a8fc2925d992348eb30deeeb54360`, `index.js` md5
`4e08904b1b7107858246af44b602067b`. Piege payload tenu : sur **225** lignes
`Storing File`, **0** pour `assets_source`, `scripts/dev`, `docs`, `web`,
`build` ou `firebase.json`.

### ⚠️ 7. DOCTRINE : `index.pck` N'EST PAS UNE PREUVE D'IDENTITE DE BUILD

Trois tailles ont ete observees pour **deux** etats de contenu —
**5 853 728 / 5 853 744 / 5 853 760** — dont **16 octets d'ecart sur un
commit de COMMENTAIRE SEUL**. Elle reste valable comme marqueur « un
nouveau build a ete servi », et c'est ainsi qu'elle est utilisee dans les
tables de deploiement. **L'inference du lot G — « le `.pck` servi est
identique au bit pres a mon export local, donc c'est bien mon build » — est
INVALIDE et ne doit pas etre rejouee.** `index.wasm` est le controle
d'identite.

### Un prop deplace, et la premiere tentative etait FAUSSE

Un arbre existant tombait dans la nouvelle eau a `(-33,76 ; -10,30)`. Le
premier deplacement l'a mis a `(-31,35 ; -10,18)` — soit **7,93 du centre
du PETIT lac, donc dans SON eau**. Trouve sur un rendu, pas par
raisonnement. Livre a `(-29,90 ; -13,73)`, degage des deux berges, 0,551 du
prop le plus proche.

⚠️ **Six props se tenaient DEJA dans l'eau du petit lac avant ce lot**
(mesure : deux arbres, deux rochers, deux fleurs, plus un buisson dans sa
berge). C'est livre et valide sur device, donc laisse tel quel — ce lot se
contente de ne pas en ajouter un septieme. A traiter dans son propre lot si
ca doit l'etre.

### Reste ouvert — jugement device, seul juge

1. **Un disque indigo de 40 u de large se lit-il comme un LAC** a l'echelle
   reelle d'un telephone, ou comme une tache violette ? La teinte, la
   sagitta et l'alpha sont mesures ; la lecture ne l'est pas.
2. **Les ilots se lisent-ils comme des iles** et leurs landmarks comme des
   reperes, a 20-30 u sous 30-40 % de fog ?
3. **Seuls 2 ilots sur 3 tiennent dans un cadre** (mesure ci-dessus).
   Acceptable si LAKE-2 emmene le joueur vers le troisieme ; a trancher.
4. **Le lobe de rive est a ~6-8 taps de cote** — l'asymetrie de visee deja
   mesuree au lot D (un tap vers l'avant traverse tout le plateau, un tap
   de cote ne porte que ~5,15 u) s'applique en plein a lui.
5. **Les pontons n'ont aucune fonction** : ils doivent se lire comme une
   promesse, pas comme un controle mort.

### Deploiement staging (palier 1, automatique)

`staging` **`73d45d2`** (merge `--no-ff`, arbre **byte-identique** a la
branche feature : meme hash d'arbre des deux cotes ET `git diff` vide,
verifie AVANT le push). CI run **#242** (id 32941388112) **verte** —
`Deploy to Vercel [STAGING -- staging]` succes (07:12:21 -> 07:12:31 UTC),
`[PRODUCTION -- main]` correctement **skipped**. **`main` NON touche**
(`origin/main` toujours `ae13b99`) : palier 2, gate Mathieu apres
validation device.

**Verifie SUR LE SERVICE, pas dans le log CI** (`keepy-staging.vercel.app`,
via le canal MCP Vercel — l'egress direct du sandbox reste refuse sur ce
domaine) :

| marqueur | avant | apres |
|---|---|---|
| `CACHE_VERSION` | `1787698811` = **25 aout 23:00:11** (run #241) | **`1787728327` = 26 aout 07:12:07** |
| `index.pck` servi | *(non lu avant le merge — voir ci-dessous)* | **5 862 224** |
| `index.wasm` servi | — | **35 376 909** *(inchange, attendu)* |

L'epoch d'apres tombe **a l'interieur de l'etape `Export Web build`** du
run #242 (07:12:03 -> 07:12:08). Les trois lectures utiles portent
`x-vercel-cache: MISS` avec `age: 0`.

⚠️ **Honnetete sur la couverture : la bascule n'est prouvee DANS LES DEUX
SENS que sur le `CACHE_VERSION`.** Le `.pck` servi n'a ete lu qu'APRES le
merge, donc il vaut ici comme second marqueur independant de l'etat courant,
pas comme preuve de transition. Les lots precedents lisaient les deux aux
deux bouts ; celui-ci ne le fait pas, et c'est dit plutot que suggere.

⚠️ **Le piege HIT/age s'est reproduit et a ete REFUSE** : une relecture a
07:11:34, pendant que le job tournait, est revenue `x-vercel-cache: HIT`
avec **`age: 151`** — une copie de bord figee par ma PROPRE lecture
d'avant-merge. Elle n'a donc pas ete comptee comme la preuve « c'est encore
l'ancienne valeur ».

⚠️ **Le `.pck` servi (5 862 224) est identique a l'export local de cette
session — et ce n'est DELIBEREMENT PAS offert comme preuve d'identite**,
conformement a la doctrine du §7 ci-dessus. C'est un marqueur « un nouveau
build a ete servi », rien de plus ; `index.wasm` est le controle d'identite.

## LAKE-MOVE-1 : LE GRAND LAC ENTRE DANS LE PLATEAU -- (15,5 ; -19) rayon 16, et le LOBE MEURT AVEC LE DEPLACEMENT (26 aout 2026)

Branche `claude/lake-move-1-relocate-3sisc6`, partie de `staging` (`d13047b`).
Decision de Mathieu prise sur les mesures de la recon LAKE-MOVE : **P2f est le
SEUL candidat nettement visible depuis le centre du plateau** (39 % du disque au
cadre, 50,4 % des positions), et 16 est le rayon MAXIMUM qui tient entierement
dans le carre. **Le placement n'a pas ete re-arbitre.**

**CONTRAINTES DURES TENUES, verifiees par `git diff --stat` et pas affirmees** :
`KeepyHopper.gd`, `HubCamera.gd` et `HubTapInput.gd` **ne sont PAS dans le
diff**. `PLATEAU_HALF_EXTENT` reste **35.0**. **Aucune couleur, aucun alpha
touche nulle part** -- la recolorisation est le lot suivant, et melanger les deux
rendrait tout diagnostic impossible.

### Ce qui bouge, et pourquoi le centre cesse d'etre polaire

`HubRegion` tenait le lac en **azimut 282 + distance 54 + rayon 20**. C'etait la
formulation la plus courte tant qu'il etait dehors, droit derriere le petit lac.
Il est desormais a **(15,5 ; -19) rayon 16**, et le layout enonce ce centre en
cartesien : un azimut ici serait une **seconde orthographe du meme point**, libre
de deriver d'un arrondi que personne ne verrait avant qu'une berge ne tranche un
prop. `LAKE_CENTRE_X`/`LAKE_CENTRE_Z` deviennent la source ; l'azimut
(**39,207 deg**) et la distance (**24,520**) sont **publies, derives**.

⚠️ **DEFAUT LATENT FERME AU PASSAGE, et il aurait ete silencieux** : rien
n'assertait que la position `greatlake` du layout et les constantes de
`HubRegion` decrivaient le MEME point. Ce sont deux nombres independants
construisant deux objets differents -- **le disque DESSINE et le trou
MARCHABLE**. Bouger l'un sans l'autre aurait fait cesser l'eau qu'on voit
d'etre l'eau ou l'on ne peut pas marcher, **sans aucune erreur**. Gate
maintenant (PHASE REGION).

### ⚠️ LE LOBE DE RIVE MEURT, ET IL EMPORTE 7 PROPS QUE LE BRIEF NE COMPTAIT PAS

Le `SHORE_PAD_RADIUS = 20` centre sur la berge proche ajoutait **91,6 u2** de sol
marchable AU-DELA du carre. Avec la berge proche desormais a **8,520** du centre,
le pad s'etend au plus a **28,520** contre un demi-cote de 35 : **entierement
contenu, 0 u2 ajoute**. Mesure, pas deduit -- la sonde balaye la region et trouve
**0 point au-dela du carre** (contre 1 070 avant).

**Consequence que le brief ne prevoyait pas : 7 props vivaient dans ce lobe**
(`|x| > 35`, jusqu'a 42,01) et deviennent inatteignables. Ils sont **relocalises
comme les autres**. Total reel : **25 props dans l'eau + 7 dans le lobe = 32
props, plus 3 landmarks**, jamais supprimes.

Le pad est **garde a 20 plutot que zero** : il est le terme generique de l'union,
il ne coute rien tant qu'il est contenu, et un lot futur qui repousse un lac
hors d'un bord recupere le lobe gratuitement. **L'assertion de sonde est
INVERSEE, pas supprimee** -- elle exigeait que le pad depasse, elle exige
desormais qu'il soit contenu, donc c'est elle qui parlera le jour ou ca change.

### La zone lac demenage EN BLOC, echelle 0,8 sur les positions

3 ilots + leurs 3 landmarks + 5 pontons gardent leurs positions **relatives**,
mises a l'echelle 16/20 = **0,8** (mises a l'echelle, pas translatees -- le
brief avait raison, un rayon plus petit ne peut pas porter les memes offsets).

⚠️ **Les RAYONS d'ilot ne sont deliberement PAS mis a l'echelle** : chaque ilot
porte encore son landmark avec la marge qu'il avait livree. Les deux options ont
ete mesurees -- rayons a l'echelle : eau libre 4,48-6,64 a la rive et 7,99-8,84
entre ilots ; **rayons inchanges (livre)** : **3,802-6,001** a la rive et
**6,668-7,562** entre ilots. Contre une coque de **0,78** de long, les deux sont
amplement navigables pour LAKE-2 ; l'option livree garde les ilots lisibles.

### Separations d'eau, MESUREES

| paire | avant | apres |
|---|---|---|
| **grand lac <-> petit lac (eau)** | **+0,347** *(ils se touchaient)* | **+18,849** |
| grand lac <-> petit lac (berges) | **-2,003** *(chevauchement)* | **+16,499** |
| grand lac <-> mare (eau) | -- | **+7,707** |
| grand lac <-> ruisseau (bords) | -- | **+9,158** |
| mare <-> ruisseau | -0,596 | **-0,596** *(intouche)* |
| ruisseau <-> petit lac | -0,605 | **-0,605** *(intouche)* |

La contrainte d'origine du chantier est levee : **plus aucun contact**. La
chaine mare-ruisseau-petit lac, elle, **subsiste** et continue d'exiger son
echelle de saturation a trois crans -- aucun deplacement du grand lac ne la
resout, comme la recon l'avait dit.

### ⚠️ RISQUE MESURE ET NON CORRIGE : la berge passe SUR la dalle du portail Battle

C'est le seul cout du placement que la recon n'avait pas chiffre, et il est
publie plutot que maquille. Portail Battle a **17,589** du centre du lac :

| | valeur |
|---|---|
| **eau** vs dalle du portail (rayon 1,35) | **+0,239** -- degage |
| **berge** (17,30) vs dalle du portail | **-1,061** -- **elle passe dessus** |
| portail Quizz, berge | +0,831 -- degage |
| portail Chased, berge | +6,731 -- degage |

**L'anneau du portail se dessine PAR-DESSUS la berge** (torus au-dessus du sol,
berge a y 0,011-0,0185) et **reste entierement lisible au rendu** -- verifie a
l'image, capture `portal_row`, pas seulement calcule. Rien n'est marchable dans
l'eau. **Non corrige** : le degager demanderait un centre a `x >= 18`,
c'est-a-dire un AUTRE placement que celui qui a ete choisi. **Decision de
Mathieu.**

### ⚠️ KEEPY MARCHE SUR L'EAU, ET CE LOT AGGRAVE LE DEFAUT -- mesure avant/apres

La recon l'avait etabli : **aucun evitement d'obstacle n'existe dans le depot**,
le hopper suit une corde droite et ne consulte rien. Ce lot ne le corrige pas
(chantier a part entiere) mais **le mesure**. Meme jeu de 10 trajets, meme
binaire, meme machine, `--fixed-fps 60`, `origin/staging` en worktree separe :

| trajet | hops | grand lac AVANT | grand lac APRES |
|---|---|---|---|
| (-35,-35) -> (35,35) *(la diagonale)* | 66 | **0** | **0** |
| **(-35,35) -> (35,-35)** *(l'anti-diagonale)* | 66 | **0** | **21** |
| **(0,0) -> (35,-35)** | 33 | **0** | **21** |
| (0,0) -> (-35,-35) | 33 | 0 | 0 |
| (0,0) -> (35,0) | 24 | 0 | 0 |
| **(0,0) -> (0,-35)** | 24 | **0** | **5** |
| (-35,-5) -> (-15,-5) *(petit lac)* | 14 | 10 petit lac | 10 petit lac |
| (14,7) -> (28,8) *(mare)* | 10 | 4 mare | 4 mare |
| (-2,4) -> (-2,16) *(ruisseau)* | 8 | 0 | 0 |
| (-35,-20) -> (-12,10) | 25 | 11 petit lac | 11 petit lac |
| **TOTAL** | **303** | **0 grand lac** | **47 grand lac (15,5 %)** |

Le banc **reproduit d'abord les quatre trajets publies par la recon au bond
pres** (10/14 et 11/25 sur le petit lac, 4/10 sur la mare) -- un banc incapable
de restituer un chiffre au dossier n'a pas qualite a en publier un neuf. Les
lignes petit lac / mare / ruisseau sont **byte-identiques** des deux cotes : ce
lot ne touche a aucune de ces trois eaux.

⚠️ **La diagonale principale reste a ZERO bond sur l'eau, et c'est
l'anti-diagonale qui prend 21** -- l'estimation « ~27 bonds sur 66 sur une
traversee » du brief visait la bonne echelle mais pas le bon trajet : la
diagonale `(-35,-35)->(35,35)` passe a **24,4 u** du centre du lac, bien au-dela
de 16.

### VALIDATION

Editeur + templates Godot 4.3-stable installes dans ce sandbox (releases GitHub
officielles, **tailles confirmees contre le `Content-Length`** : 50 276 070 et
1 073 228 327 octets, aucune troncature). Import headless **exit 0**, **24
`.scn`** des deux cotes (import complet verifie, pas suppose). Boot headless de
`HubWorld.tscn` **exit 0, 0 erreur, 0 `push_warning`** -- la confirmation A
L'EXECUTION que les 203 entrees sont coherentes avec leur drapeau `offshore`.
Export Web release **exit 0, 0 erreur**. `index.wasm` **35 376 909** / md5
`af4a8fc2925d992348eb30deeeb54360`, `index.js` md5
`4e08904b1b7107858246af44b602067b`. `index.pck` 5 863 056 (marqueur, **jamais
preuve d'identite**). Piege payload tenu : sur **225** lignes `Storing File`,
**0** pour `assets_source`, `scripts/dev`, `docs`, `web`, `build` ou
`firebase.json`.

**`LakeZoneProbe` : 27 checks, 0 echec, exit 0** (sous `xvfb`, jamais
`--headless` -- PHASE TAP a besoin d'un rect de conteneur reel).
`ProbeTimeoutAudit` **45 sondes scenes** (retour exact a la baseline apres
retrait des deux sondes jetables), `AssetContractAudit` (**12/12 visuels, pas un
collider deplace**), `DeathModelAudit`, `ChargerShapeProbe` -- **toutes exit 0**.

| # | verdict | methode |
|---|---|---|
| **[a]** | **diagonale 66 hops / 1122 frames / 18,700 s, INCHANGEE et toujours le pire cas** ; pire traversee passant DANS l'eau 18,700 s aussi | vrai `KeepyHopper`, `--fixed-fps 60` -- **MESURE** |
| **[b]** | grand lac <-> petit lac **+0,347 -> +18,849** ; chaine mare/ruisseau/petit lac **-0,596 / -0,605 inchangee** | geometrie sur le layout livre -- **MESURE** |
| **[c]** | ruisseau et mare ni recouverts ni touches (**+9,158** et **+7,707**) | idem -- **MESURE** |
| **[d]** | **3/3 marches centre -> portail restent AU SEC** (5 hops, 0 atterrissage dans l'eau chacune) | vrai hopper, gate dans la sonde -- **MESURE** |
| **[e]** | draw nodes hors portails **96 -> 96**, total **102 -> 102**, 9 MultiMesh tous `TRANSFORM_3D` | comptage de l'arbre `Props` vivant des deux cotes -- **MESURE** |
| **[f]** | ligne ajoutee a `docs/HUB_PERF_BASELINE.md` | `HubPerfBaseline` x3 des deux cotes -- **MESURE** |
| **[g]** | **le lac se voit clairement du centre** | 4 captures offscreen 1080x1920, vraie camera du hub -- **MESURE** |

**[e] est un ZERO delta et c'est le resultat attendu** : ce lot relocalise des
entrees, il n'en cree ni n'en detruit aucune. Marge sous le plafond de 260 :
**164**, inchangee.

**[g] VERDICT.** Capture depuis le centre du plateau : **le lac occupe tout le
quadrant haut-droit**, distinct du vert, avec sa berge, un ilot pale et son
spire dedans, et les trois anneaux de portail lisibles devant. La plainte
d'origine -- « on ne voit pas le lac » -- est fermee A L'IMAGE. Trois autres
points de vue (rangee de portails, rive est, rive nord) montrent les ilots avec
leurs landmarks, les deux pontons de rive poses sur la berge, et **aucun prop
dans l'eau** (verifie par mesure aussi : **0** entree non-`offshore` a moins de
16 du centre).

⚠️ **`worst reachable |axis|` passe de 46,36 a 35,00** : c'est le lobe qui
disparait, mesure et attendu, contre un sol de demi-taille 300.

### Densite : degressive, comme la doctrine l'exige

| bande | AVANT | APRES |
|---|---|---|
| r 0-10 | 12,01 | **12,01** |
| r 10-20 | 6,93 | **5,86** |
| r 20-27 | 3,20 | **2,91** |
| r 27-35 | 1,47 | **2,75** |

Toujours strictement decroissante du centre vers l'exterieur. Les 32 props
partent dans les secteurs les plus libres mesures par la recon (az 330-360 et
60-90, elargis a 298-360 / 0-8 / 55-100 pour ne pas creer un ilot de densite),
en grappes pour buissons et fleurs, echelle et lacet inchanges. Separation
minimale relocalise-vs-tout : **0,498** (membres de grappe, comparable aux
0,555 deja livres) ; degagement d'eau le pire parmi les relocalises :
**+0,412**. `max |x| = 34,15`, `max |z| = 33,90`, sous la borne 34,2.

**Landmarks : min landmark-a-landmark 11,390** contre 13,108 livre -- plus
serre, et c'est la geometrie qui l'impose (le trou de rayon 16 mange un coin de
90 deg sur chacun des trois anneaux). **Regle « jamais deux silhouettes
identiques adjacentes » tenue** : dans l'ordre des azimuts on lit desormais
337,5 v1 -> **4,5 v0** -> **78,0 v2** -> **90,5 v0** -> 92,5 v1 -> 133 v0.

### Liste nominative des relocalisations

**Zone lac (12, echelle 0,8 autour du nouveau centre)** : greatlake
(-52,82;-11,23)->(15,500;-19,000) ; ilots+landmarks (-50,48;-3,06)->(17,372;-12,464),
(-63,65;-13,14)->(6,836;-20,528), (-47,34;-19,35)->(19,884;-25,496) ; pontons
(-31,72;-12,70)->(32,380;-20,176), (-33,98;-1,63)->(30,572;-11,320),
(-51,26;-5,80)->(16,748;-14,656), (-60,65;-12,61)->(9,236;-20,104),
(-48,82;-17,15)->(18,700;-23,736).

**Landmarks du plateau (3)** : v0 (0,00;-12,60)->(2,668;-33,895) ; v2
(15,65;-14,59)->(33,257;-7,069) ; v0 (28,45;-11,79)->(24,499;0,214).

**Scatter (32)** -- 25 tires de l'eau : tree (2,54;-10,02)->(-9,150;-22,579),
(6,37;-9,85)->(-4,864;-32,623), (9,69;-8,22)->(-4,916;-28,293),
(13,50;-5,40)->(-15,382;-23,505), (4,90;-13,20)->(32,686;-3,045),
(4,41;-21,31)->(-14,680;-30,331), (5,03;-20,70)->(0,518;-30,863),
(12,27;-20,78)->(-3,078;-30,357) ; bush (12,74;-9,10)->(-8,389;-19,556),
(11,73;-9,59)->(-10,516;-19,380), (3,28;-20,15)->(-6,503;-21,030),
(2,40;-19,84)->(29,785;4,998), (21,44;-19,21)->(27,719;5,473),
(20,84;-19,69)->(30,404;2,806) ; rock (8,60;-13,30)->(-4,207;-25,133),
(13,94;-19,72)->(-19,023;-26,294), (14,70;-20,22)->(-16,266;-26,760),
(13,35;-21,21)->(-7,198;-28,845), (16,26;-4,22)->(33,637;0,285),
(20,86;-10,67)->(-13,593;-18,711), (21,67;-9,07)->(29,234;-5,170),
(4,85;-22,89)->(-27,292;-15,055), (3,23;-23,25)->(-12,846;-24,240) ; stump
(6,58;-23,06)->(30,265;-1,506), (3,04;-12,43)->(-11,871;-15,057).
**7 tires du lobe mort** : tree (-36,74;-25,93)->(-13,717;-21,226),
(-35,66;-25,03)->(-21,942;-25,532) ; rock (-42,01;9,15)->(-6,792;-25,097),
(-36,45;7,14)->(-1,916;-26,616) ; bush (-37,34;5,03)->(29,869;7,138) ; flower
(-37,29;3,43)->(28,336;6,894), (-38,06;9,65)->(-9,713;-31,580).

### Reste ouvert -- jugement device, seul juge

1. **Le lac se lit-il comme un LAC** a l'echelle reelle d'un telephone, ou comme
   une grande tache pale au milieu du plateau ? Il occupe **16,42 % du plateau**
   -- c'est le prix accepte, et personne ne l'a encore vu sur un ecran.
2. **La berge sur la dalle du portail Battle** (chevauchement mesure 1,06 u,
   anneau lisible au rendu). Le degager demande un autre centre.
3. **47 bonds sur 303 marchent sur l'eau** contre 0 avant. Mesure, assume, sans
   correctif possible dans ce lot.
4. **Les landmarks a 11,390 l'un de l'autre** contre 13,108 livre -- plus
   serres, impose par la geometrie du trou.
5. ⚠️ **Le FPS simule BAISSE** (27,1-27,3 -> 24,6-26,3, trois runs de chaque
   cote, plages disjointes). Cause la plus probable : le lac est desormais DANS
   LE CADRE depuis le centre, donc un grand disque alpha est entre dans un
   budget de fill rate qui etait de l'herbe vide. **Sous llvmpipe, le pire
   proxy possible pour un GPU de telephone** -- ce chiffre sur-estime le cout
   device d'un facteur inconnu.
6. **Aucune couleur n'a bouge.** Le grand lac garde son `#CCFFFD` a 0,85, choisi
   quand il TOUCHAIT le petit lac. Il en est maintenant a 18,849 u : la premisse
   de l'echelle de saturation a change pour ce corps, et c'est exactement ce que
   le lot de recolorisation suivant doit reprendre.

## SPAWN-LAKE-1 : UN SECOND LOBE D'EAU DEVANT LE SPAWN, ET UNE SEULE TEINTE POUR TOUTE L'EAU DU PLATEAU (26 aout 2026)

Branche `claude/spawn-lake-second-lobe-jcd2qi`, partie de `staging`
(`e6e9083`). Regle n°1 verifiee AU DEBUT : `git fetch --all --prune`, tri
des refs distantes par date, comparaison d'ARBRES et pas de noms —
`origin/staging` est la ref la plus recente du depot, la branche de recon
`claude/spawn-lake-recon-phbzq6` porte **exactement l'arbre de
`origin/staging`** (donc deja mergee), **aucune session concurrente**.
`origin/main` = `ae13b99`, conforme au brief.

**CONTRAINTES DURES TENUES, verifiees par `git diff --stat` et pas
affirmees** : `KeepyHopper.gd`, `HubCamera.gd`, `HubTapInput.gd` et
`resources/world/swamp_palette.tres` **ne sont PAS dans le diff**.
`PLATEAU_HALF_EXTENT` reste **35.0**. Le grand lac de LAKE-MOVE-1 n'est ni
deplace ni redimensionne. Geometrie et couleur sont **deux commits
distincts**, comme demande.

Decision de Mathieu, prise sur les mesures de la recon SPAWN-LAKE et **non
re-arbitree ici** : r=16 devant le spawn est infaisable (0 centre sur 66 ne
degage a la fois les portails ET les eaux en place ; 14 et 12 n'ont aucun
centre), donc **r=10 a (-12,00 ; -19,50)**, le plus grand rayon propre et
le plus proche du spawn des 142 candidats.

### ⚠️ LA PREMISSE « LES BERGES SERONT A 0,205 » EST FAUSSE — les deux paires de berges SE CHEVAUCHENT

C'est le premier chiffre du brief a ne pas survivre a la mesure, et il vaut
la peine d'etre dit precisement parce que **la conclusion visuelle qu'il
portait reste juste, pour une raison plus forte**.

Le `0,205` de la recon est la distance entre la **BERGE du grand lac** et
l'**EAU du candidat** — le candidat n'y avait pas de berge, c'etait un
disque nu dessine par la sonde. Un vrai corps de la famille `greatlake`
porte `GREATLAKE_BANK_MARGIN = 1,30`, donc son anneau va jusqu'a **11,30** :

| paire | eau <-> eau | berge <-> eau du voisin | **berge <-> berge** |
|---|---|---|---|
| nouveau lobe <-> **grand lac** | **+1,5045** | +0,2045 | **-1,0955 (CHEVAUCHENT)** |
| nouveau lobe <-> **petit lac** | **+1,3197** | **+0,0197** | **-1,0303 (CHEVAUCHENT)** |
| nouveau lobe <-> mare | +29,14 | +27,84 | +27,42 |
| nouveau lobe <-> ruisseau | +9,2767 | — | — |

**Aucune berge ne couvre jamais l'eau du voisin** (les deux colonnes du
milieu sont positives), donc rien d'opaque ne vient mordre une surface
alpha. Ce qui se chevauche, ce sont deux anneaux **opaques de la meme
couleur** (`POND_BANK_COLOR`), a des hauteurs differentes : le plus haut
gagne, la couture est invisible, et le resultat est une **rive commune plus
large** entre les deux lobes — exactement ce que l'intention « deux lobes
d'une seule masse » demande.

⚠️ **MAIS LA MESURE DIT AUSSI QUE LE BRIEF SE TROMPE DE NOMBRE DE MASSES.**
Le nouveau lobe est **PLUS PRES du petit lac (1,3197) que du grand lac
(1,5045)**, et sa berge n'est qu'a **0,0197** de l'eau du petit lac. Avec
une couleur uniforme, la chaine ne se coupe donc pas en deux : elle se
**FERME**. mare — ruisseau — petit lac — **nouveau lobe** — grand lac
forment un seul systeme quasi continu, et non les DEUX masses que le brief
annonce. Publie tel quel, non corrige : ecarter le lobe du petit lac
voudrait dire un autre centre, c'est-a-dire re-arbitrer le placement que le
brief interdit explicitement de re-arbitrer.

### ⚠️ LE BRIEF SUPPOSAIT QUE `HubRegion` GERAIT DEJA L'EXCLUSION — c'etait vrai pour UN lac

`HubRegion` soustrayait **un** disque, code en dur. Un second corps de la
meme famille n'y serait pas entre, et un tap sur sa surface aurait envoye
Keepy marcher dedans — sans erreur. La soustraction devient donc une
**LISTE** (`_lakes`), `in_lake_water`/`contains`/`clamp_to` bouclent
dessus, et un troisieme lobe serait une ligne de plus dans cette table.

Le builder **demande son rayon a `HubRegion`** au lieu d'en porter une
copie : le trou marchable et le disque dessine doivent etre un seul cercle,
et deux nombres pour un cercle est exactement comme une dalle de berge
finit par trancher un prop que personne n'avait prevenu. Un centre que
`HubRegion` ne connait pas est une **erreur** et ne dessine rien.

### EVICTION : 29 entrees, 0 supprimee

Critere : toute entree dont **l'empreinte au sol** touche la nouvelle eau —
**2 landmarks + 27 props**, exactement les chiffres de la recon (23 par le
centre, +4 par l'empreinte seule). Relocalisees dans les secteurs
reellement libres, **mesures et pas supposes** : les azimuts 330-360 que le
brief proposait sont justement ceux que le nouveau lobe mange (son centre
est a l'azimut 328,4), et 30-60 sont sous le grand lac. L'arc libre reel
est **az 60-100 et 115-275**.

| contrainte | valeur mesuree |
|---|---|
| separation d'empreinte impliquant une relocalisee | **+0,4936** (LAKE-MOVE-1 : 0,498) |
| pire degagement d'eau parmi les relocalisees | **+0,4409** (LAKE-MOVE-1 : 0,412) |
| `max abs(x)` / `max abs(z)` | **31,583 / 32,682** (borne 34,2) |
| landmark <-> landmark minimum | **11,391** (inchange, paire pre-existante) |

**Densite strictement degressive**, et c'est ce qui a fixe les quotas (19
entrees en bande 20-27, 8 en bande 27-35) : apres eviction seule la bande
20-27 tombait SOUS la bande 27-35, donc tout renvoyer vers l'exterieur
aurait casse la doctrine.

| bande | avant | apres |
|---|---|---|
| r 0-10 | 12,10 | **12,10** |
| r 10-20 | 5,84 | **4,99** |
| r 20-27 | 2,90 | **3,39** |
| r 27-35 | 2,76 | **2,95** |

**Regle « jamais deux silhouettes de landmark identiques adjacentes »
tenue**, bouclage compris : 4,5 v0 -> 78,0 v2 -> 90,5 v0 -> 92,5 v1 ->
**113,5 v2** -> 133,0 v0 -> 157,5 v1 -> 177,3 v2 -> **193,0 v1** -> 227,5
v0 -> 247,5 v2 -> 271,8 v1 -> (retour 4,5 v0).

### COULEUR UNIFORME : #40E0D0 sur les CINQ corps

La famille B de WATER-HUE-2 est **supprimee**, pas ajustee. Elle separait
quatre corps par la SATURATION uniquement parce que trois se touchent ;
Mathieu a juge le resultat sur device (ruisseau delave, grand lac
« glacier »). `#40E0D0` etait deja, exactement, l'albedo du petit lac.

**Consequence dite franchement : la couleur partagee laisse l'ALPHA comme
SEUL levier.**

### ⚠️ L'ALPHA EST BALAYE, JAMAIS RESOLU — et deux corps NE PASSENT PAS

`scripts/dev/WaterAlphaSweep.tscn` (nouvelle, **rapporte, ne gate rien**)
mesure chaque pas de 0,05 contre le sol du hub, par **masque de rendu** par
corps (une passe d'identification rend la cible en blanc opaque, fog coupe,
le reste en noir ; un pixel appartient au corps ssi il revient exactement
255,255,255). Une fenetre fixe est inutilisable ici : l'eau est alpha sur sa
propre berge et le ruisseau est un ruban vu de biais.

⚠️ **Les corps sont identifies par leur CENTRE de layout, jamais par leur
couleur** — la couleur a cesse d'etre un identifiant a l'instant ou les
cinq corps ont pris le meme albedo. Meme correction appliquee a
`LakeZoneProbe` (sa pile de hauteurs matchait sur `GREATLAKE_WATER_COLOR`,
qui designe desormais DEUX lobes).

Sol du hub mesure par vue : **Lrel 0,0741 a 0,0815**.

| corps | alpha livre | pire vue ou le corps est SUJET |
|---|---|---|
| mare | **0,95** | 3,22:1 *(0,90 -> 2,99, sous le plancher)* |
| petit lac | **0,95** | 3,04:1 *(0,90 -> 2,82)* |
| **grand lac** | **0,95** | **3,14:1** dans sa propre vue |
| **nouveau lobe** | **0,95** | **3,22:1** dans sa propre vue |
| ruisseau | **0,90** | 3,09:1 *(0,85 -> 2,91)* |

**Le ruisseau est le seul sous 0,95, et ce n'est pas un arrondi** : il n'a
pas de berge sous lui et se melange directement sur le SOL, la ou les
quatre disques se melangent sur leur propre anneau olive sombre.

⚠️ **LES DEUX GRANDS LOBES NE FRANCHISSENT PAS 3,0:1 DANS TOUTES LES VUES
OU ILS SONT VISIBLES, ET AUCUN ALPHA JUSQU'A 1,00 N'Y CHANGE RIEN.** Publie
plutot que sauve :

| vue | corps | distance camera | fog | meilleur (a=1,00) |
|---|---|---|---|---|
| pond | grand lac | 49,6 u | 54,8 % | **2,54:1** |
| twolobes | grand lac | 41,7 u | 48,7 % | **2,89:1** |
| laketail | nouveau lobe | 45,1 u | 51,4 % | **2,68:1** |
| twolobes | nouveau lobe | 42,2 u | 49,1 % | **2,87:1** |

C'est le **fog exponentiel** (`hub_fog_density` 0,016 vers un vert quasi
noir), pas la couleur : a ces distances il a deja remplace la moitie de la
surface avant que l'alpha ait son mot a dire, et il fait la meme chose a
tout objet opaque a cette portee. **0,95 est le plus petit pas qui franchit
le plancher la ou le corps est le SUJET** ; pousser a 1,00 achete un echec
ET coute la translucidite qui fait qu'un lac se lit comme un trou dans le
sol plutot que comme une marque dessus — le defaut deja signale a 0,96 sur
le petit lac par WATER-HUE-2. La couleur n'a **pas** ete deviee en douce
pour sauver le chiffre.

**Passe de CONFIRMATION** : la sonde accepte `--alphas=0.90,0.95` et a ete
rejouee sur les **constantes reellement livrees** plutot que sur un
override d'execution. Elle reproduit la table au centieme.

### VALIDATION

Editeur + templates Godot 4.3-stable installes dans ce sandbox (releases
GitHub officielles, **tailles verifiees contre le `Content-Length`** :
50 276 070 et 1 073 228 327 octets, aucune troncature). Import headless
**exit 0**, **24 `.scn`** des deux cotes. Boot headless de `HubWorld.tscn`
**exit 0, 0 erreur, 0 `push_warning`** — la confirmation A L'EXECUTION que
les 204 entrees sont coherentes avec leur drapeau `offshore`. Export Web
release **exit 0**, **0 SCRIPT/Parse Error**.

`index.wasm` **35 376 909** octets / md5
**`af4a8fc2925d992348eb30deeeb54360`**, `index.js` md5
**`4e08904b1b7107858246af44b602067b`** — identiques au fingerprint deja
consigne pour tout lot qui ne touche pas le code moteur. `index.pck`
5 864 288 (**marqueur, jamais preuve d'identite** : le meme arbre a donne
5 864 272 a l'export precedent, 16 octets d'ecart, enieme illustration de
l'instabilite deja consignee). **Piege payload verifie sur le pack et pas
sur le filtre** : sur **225** lignes `Storing File`, **0** pour
`res://scripts/dev`, `res://assets_source`, `res://docs`, `res://web/`,
`res://build` ou `firebase.json`, et **0** occurrence de `WaterAlphaSweep`
dans le `.pck`.

| # | verdict | methode |
|---|---|---|
| **[a]** | **diagonale 66 hops / 1 122 frames / 18,700 s, INCHANGEE**, et toujours le pire cas ; anti-diagonale 18,700 s aussi | vrai `KeepyHopper`, `--fixed-fps 60` — **MESURE des deux cotes** |
| **[b]** | **11 / 350 atterrissages sur le nouveau lobe (3,1 %)**, sur la seule diagonale du carre ; **0 / 15** sur les 3 allers spawn -> portail | 13 trajets, vrai hopper — **MESURE** |
| **[c]** | aucun portail recouvert : chased **+3,65**, quizz **+4,53**, battle **+10,26** (dalle 1,35 contre la BERGE) | geometrie sur le layout livre — **MESURE** |
| **[d]** | ni mare (+29,14), ni ruisseau (+9,28), ni petit lac (+1,32) recouverts — **mais berge du lobe a +0,0197 de l'eau du petit lac**, voir plus haut | idem — **MESURE** |
| **[e]** | **16/16 taps resolus sur la terre ferme** (8 azimuts par lobe), tous projetes dans le viewport | `HubTapInput._handle_point` livre, fenetre reelle sous `xvfb` — **MESURE** |
| **[f]** | draw nodes hors portails **96 -> 98** (+2 : la berge et l'eau du lobe), total **102 -> 104**, 9 MultiMesh tous `TRANSFORM_3D` | comptage de l'arbre `Props` vivant des deux cotes — **MESURE** |
| **[g]** | ligne ajoutee a `docs/HUB_PERF_BASELINE.md` : construction 47,55-63,07 -> 48,91-51,81 ms, **FPS 14,3-15,0 -> 14,4-15,4 (les plages SE CHEVAUCHENT, pas de baisse)** | `HubPerfBaseline` x3 des deux cotes, lances UN A LA FOIS — **MESURE** |
| **[h]** | 3 vues avant/apres sous `docs/hub-shots/{before,after}_{spawn,junction,chain}.png` | offscreen 1080x1920, vraie camera du hub, `xvfb` + `opengl3` — **MESURE** |
| **[i]** | eau totale **1 086,82 -> 1 400,98 u2**, **22,180 % -> 28,591 %** des 4 900 ; 314,16 u2 = **6,411 %** de sol marchable perdu | geometrie — **MESURE** |

⚠️ **CONTRE-INTUITIF ET PUBLIE TEL QUEL : le FPS simule ne BAISSE PAS**,
contrairement a LAKE-MOVE-1 ou l'arrivee du grand lac dans le cadre avait
coute 27,1-27,3 -> 24,6-26,3. Explication la plus probable : la sonde
echantillonne depuis le CENTRE du plateau, ou le grand lac occupe deja le
cadre — le second lobe ajoute donc de l'alpha a un budget qui payait deja
de l'eau, pas a de l'herbe vide. ⚠️ **Et ces 14-15 fps ne sont PAS
comparables aux 27 des lignes precedentes du fichier** : autre sandbox.
Seule la paire AVANT/APRES d'un meme bloc partage une machine.

**Sondes, toutes exit 0** : `LakeZoneProbe` (sous `xvfb`, PHASE REGION /
GEOMETRY / TAP / CROSSING), `ProbeTimeoutAudit` (**48 sondes scenes** : 47
+ `WaterAlphaSweep`, retour exact a la baseline apres retrait des deux
sondes jetables), `AssetContractAudit` (**12/12 visuels, 0/10 colliders
deplaces**), `DeathModelAudit`, `ChargerShapeProbe`.

⚠️ **UNE ASSERTION QUE J'AI ECRITE EST PARTIE ROUGE, ET C'ETAIT LA SONDE**
— « chaque rive de lobe est marchable » echouait sur **7 des 32 points de
rive testes**. Cause mesuree et non devinee : `Vector3` est en **float32**,
`in_lake_water` compare STRICTEMENT au rayon, et un point construit comme
`centre + dir*rayon` retombe **9,54e-07 A L'INTERIEUR** de son propre
cercle. Ce que la region promet reellement, c'est que la sortie de
`clamp_to` est de la terre — et `clamp_to` decale de 0,001, precisement
pour ca. L'assertion gate donc la promesse au lieu d'un cas de bord
irrepresentable.

### RESTE OUVERT — jugement device, seul juge

1. **Est-ce que deux lobes turquoise separes par 1,5 u lisent comme UNE
   masse en deux lobes**, ou comme deux lacs qu'on a rates de peu ? C'est
   l'intention explicite du lot, et aucune sonde ne la juge.
2. ⚠️ **La chaine se ferme** (voir plus haut) : avec la teinte unique, les
   cinq corps forment probablement un seul systeme continu et non deux
   masses. Mesure, publie, **non corrige**.
3. **Les deux grands lobes a 2,54-2,89:1 vus d'en face du plateau.**
   Mesure, argumente par le fog, sans correctif possible a couleur fixe.
4. **28,6 % du plateau est de l'eau** et **11 bonds sur 350 marchent dessus
   en plus**. Marcher sur l'eau n'a toujours aucun correctif : il faudrait
   un evitement dans `KeepyHopper`, qui n'existe nulle part.
5. Inchange et toujours ouvert : la berge du grand lac qui passe sur la
   dalle du portail Battle (1,061 u), et les 6 props dans l'eau du petit
   lac.

### Deploiement staging de SPAWN-LAKE-1 (palier 1, automatique)

`staging` **`ab37db0`** (merge `--no-ff`, arbre **byte-identique** a la branche
feature : meme hash d'arbre `5044abdf` des deux cotes, `git diff` vide, verifie
AVANT le push). CI run **#255** (id 33009737566) **verte** -- `Import project
resources` 20:19:11 -> 20:21:27, `Export Web build` **20:21:27 -> 20:21:32**,
`Deploy to Vercel [STAGING -- staging]` **succes** (20:21:48 -> 20:24:29),
`[PRODUCTION -- main]` correctement **skipped**. **`main` NON touche**
(`origin/main` toujours `ae13b990...`, verifie apres le push) : palier 2, gate
Mathieu apres validation device.

**Verifie SUR LE SERVICE, pas dans le log CI, sur DEUX marqueurs independants
et dans les DEUX sens** :

| marqueur | avant | apres |
|---|---|---|
| `CACHE_VERSION` | `1787771357` = **19:09:17** (run #254) | **`1787775691` = 20:21:31** *(a l'interieur de l'etape `Export Web build`, 20:21:27 -> 20:21:32)* |
| `index.pck` servi | **NON MESURE** *(voir ci-dessous)* | **5 864 560** |
| `index.wasm` servi | 35 376 909 | 35 376 909 *(inchange, attendu)* |

⚠️ **Le second marqueur n'a de valeur « avant » sur AUCUNE lecture, et c'est
un manque de cette session plutot qu'un chiffre a citer** : `index.html` n'a
pas ete relu sur le service avant le merge, donc l'`index.pck` servi par le
build precedent n'existe nulle part. Il n'est pas reconstitue depuis un log de
CI ni depuis un export local -- ce serait un chiffre d'une autre provenance
presente comme une mesure du service. La bascule reste prouvee par le
`CACHE_VERSION`, lu aux deux bouts.

Les deux lectures « apres » portent **`x-vercel-cache: MISS` et `age: 0`**,
`last-modified` colle a l'instant de la requete. L'epoch servi tombe **dans la
fenetre d'export du run #255** : l'alias sert bien ce build.

⚠️ **La valeur « avant » du `CACHE_VERSION` a ete lue sur un `HIT` a
`age: 4070`, et c'est dit plutot que maquille** : elle est valable comme
**VALEUR** (elle est anterieure au push, donc c'est bien l'ancien build), mais
**ce n'etait PAS une mesure de fraicheur** au sens de la regle permanente. La
bascule est prouvee par la lecture MISS/age 0 d'apres et par l'horodatage de
l'epoch, pas par cette lecture-la.

⚠️ **`index.pck` a de nouveau trois valeurs pour le meme contenu de jeu** :
**5 864 288** a l'export local propre de cette session, **5 864 560** servi par
la CI. C'est l'instabilite permanente deja consignee -- le `.pck` est un
marqueur « nouveau build », **jamais** une preuve d'identite. La preuve
d'identite est `index.wasm` (**35 376 909**, md5
`af4a8fc2925d992348eb30deeeb54360`), identique des deux cotes comme il doit
l'etre pour un lot qui ne touche pas le code moteur.

⚠️ **L'API GitHub Actions a de nouveau servi un etat PERIME** : `get_workflow_run`
rendait `status: "in_progress"` avec `updated_at` fige a **20:18:34** alors que
le deploiement etait deja tombe (l'export s'etait termine a 20:21:32 et l'alias
servait deja le nouveau `CACHE_VERSION` a 20:24:41). **C'est le marqueur servi
qui a tranche**, comme aux runs #201, #202, #226, #229 et #232 ; l'appel
`list_workflow_jobs` avec `filter: "all"` a ensuite confirme
`conclusion: success` et le detail des 18 etapes. Enieme reproduction du piege
deja consigne : ne jamais conclure d'un seul appel, et ne jamais lire un etat
de CI sans regarder son horodatage.

