# Hibou — prop statique et vol en boucle

> Extrait de `CLAUDE.md` par le LOT H (2 septembre 2026), **verbatim** : aucune ligne réécrite, résumée ni supprimée.
> 3 section(s), 943 lignes d'origine.
> Doctrine permanente : voir `CLAUDE.md`. Index des chantiers : `docs/lots/INDEX.md`.

## HUB, LOT PROPS-1 : PREMIER .glb NON-KEEPY DU PLATEAU -- une chouette statique, purement decorative, posee pres du portail Quizz (28 aout 2026)

Branche `claude/hub-owl-static-prop`, partie de `main` (`2ae7901`). Regle
n°1 verifiee AU DEBUT : `git fetch --all --prune`, comparaison par ARBRE et
pas par nom -- `origin/main` porte exactement `2ae7901`, et
`origin/main..origin/staging` est VIDE (staging n'a que le merge en moins).
`main` avait ete pousse deux commits au-dela du dernier etat connu de ce
fichier (`8e8b9bd` "ennemis" + le merge GitHub `d7a0b81`) : **10 `.glb`
bruts sous `assets_source/openworld/{animated,decor,perso}/`, 0 ligne de
code/scene/config**, exactement l'exception permanente deja actee (Mathieu
depose des `.glb` Meshy bruts depuis VS Code/l'interface web, bornee a
`assets_source/`). Signale, continue normalement, comme la regle le
prescrit pour ce cas precis.

**LOT 1 uniquement** : chouette STATIQUE, purement decorative, aucune
interaction, aucune animation, aucun signal, aucun etat. Le vol scripte
avec Keepy (LOT 2) est **explicitement hors perimetre** -- rien n'a ete
prepare pour lui : pas de hook, pas d'etat `KeepyHopper` supplementaire, pas
de trajectoire.

### ETAPE 1 -- RECON : l'arborescence reelle, pas supposee

`assets_source/` porte desormais SIX dossiers, pas les deux que le brief
nommait de memoire (`openworld/animated/` et `openworld/decor/`) :

```
assets_source/
  decor/       6 .glb + 3 .png (dejà en prod, pipeline decor historique)
  ennemis/     6 .glb (dejà en prod, pipeline hazards)
  hero/        1 .glb (Keepy, dejà en prod)
  pursuer/     1 .glb (hibou pursuer, dejà en prod)
  ui/          1 .png (dejà en prod)
  openworld/   NOUVEAU, pousse le 28 aout 2026
    animated/  5 .glb -- TOUS rigges (skins=1, animations=1-2, 26-29 noeuds)
    decor/     1 .glb -- "cabane keepy" (1 noeud, non riggee)
    perso/     4 .glb -- 1 riggee (doublon de animated/Merged_Animations),
               3 NON riggees : Owlet, Hedgehog_Adventurer, Pie
```

**Aucune ambiguite sur la chouette** : un seul nom evoque un hibou/chouette
dans tout le lot, `Meshy_AI_Ember_Eyed_Owlet_0828125359_texture.glb`. Les
deux autres candidats non rigges de `perso/` sont sans equivoque autre
chose (un herisson, "Pie" = probablement une pie, pas un rapace nocturne),
et `openworld/decor/` porte une cabane. Pas de STOP necessaire.

### Inspection du .glb retenu, MESUREE et pas supposee

Parseur glTF binaire ecrit pour l'occasion (lit les chunks JSON/BIN, aucune
dependance externe) :

| | valeur |
|---|---|
| noeuds / meshes / skins / animations | 1 / 1 / **0** / **0** |
| triangles | **4 423** (dans la fourchette ~4000-6000 annoncee) |
| materiaux | 1, PBR complet : baseColor (2048x2048 PNG), normal (2048x2048
  PNG), metallicRoughness (**4096x4096 PNG**) |
| `extensionsUsed` | **[]** -- aucun `KHR_materials_unlit`, comme tout .glb
  Meshy brut deja documente dans ce depot |
| bbox brute (model space) | X 1,29264, **Y 1,899284** (axe dominant,
  debout), Z 1,427501 ; centre a moins de 2 mm de l'origine sur les 3 axes |

**Confirme au rendu, pas seulement au JSON** : Godot 4.3-stable installe
dans ce sandbox (releases GitHub officielles, tailles verifiees contre le
`Content-Length` -- 50 276 070 et 1 073 228 327 octets, aucune troncature).
Rendu offscreen 4 azimuts + dessus, `xvfb-run --rendering-driver opengl3`,
avec la vraie texture et un eclairage temporaire (le materiau brut est
encore LIT a ce stade) : **face au model +Z** (yeux, bec, aigrettes
visibles), **dos au model -Z** (aucun trait de visage) -- meme convention
que `keepy_squirrel_hero.glb`.

### Traitement necessaire : UNLIT ajoute, PBR maps conservees comme sur le hero/pursuer

**Reponse a la question du recon** : oui, un traitement est necessaire, et
c'est celui que la doctrine de ce depot impose deja a **tout** asset du
projet -- ajouter `KHR_materials_unlit`. Rien d'autre n'est change.

Script d'ecriture GLB ecrit pour ce lot (JSON-only, jamais touche au chunk
BIN) : **losslessness prouvee EN DEUX TEMPS**, comme la doctrine du depot
l'exige --
1. reecriture verbatim (sans toucher au materiau) : chunk **BIN
   byte-identique** a la source, JSON semantiquement identique (l'ecart de
   serialisation JSON pur -- ordre des cles -- ne compte pas) ;
2. ajout de `"extensions": {"KHR_materials_unlit": {}}` sur le materiau et
   dans `extensionsUsed` (jamais `extensionsRequired`, comme
   `keepy_squirrel_hero.glb`/`keepy_hibou_pursuer.glb`) : chunk BIN encore
   **byte-identique** apres coup (14 569 376 octets), verifie sur le
   fichier de sortie et pas seulement plaide.

Verifie dans Godot apres coup : materiau `shading_mode = 0` (UNSHADED),
bbox **inchangee au dernier chiffre**.

⚠️ **Les trois maps PBR sont CONSERVEES, decision explicite et pas un
oubli.** `keepy_hibou_pursuer.glb` (deja en prod) est lui aussi unlit et
porte pourtant `normalTexture`/`metallicRoughnessTexture` intactes --
c'est le precedent direct pour un asset qui GARDE sa texture (par
opposition aux hazards, decimes a plat sans texture). Suivre ce precedent
plutot que de trancher seul si stripper etait souhaite : voir le paragraphe
payload plus bas, qui chiffre precisement ce que ca coute.

Installe sous **`assets/models/keepy_owl_decor.glb`** -- `assets_source/*`
est dans l'`exclude_filter` de l'export (`export_presets.cfg`), `assets/*`
n'y est PAS, donc c'est le seul chemin qui embarque l'asset dans le build.
Les trois sidecars PNG extraits par l'importeur glTF de Godot
(`keepy_owl_decor_Baked_BaseColor.png`, `_Baked_MetallicRoughness.png`,
`_normal.png`) sont commites a cote, meme convention que
`keepy_hibou_pursuer_*` deja en depot.

### ETAPE 2 -- installation : layout-driven, comme les 216 autres entrees

**Aucune coordonnee en dur dans un script.** `HubBuilder.gd` gagne
`@export var owl_scene: PackedScene` (meme patron que `portal_scene`,
wire dans `HubWorld.tscn`), un nouveau cas `&"owl"` dans le `match` de
`_build()`, et `_make_owl(index)` qui instancie `owl_scene` directement --
**pas via `ModelSlot`** : ModelSlot existe pour un noeud avec un
PLACEHOLDER de repli, et ce prop n'en a aucun (il est soit le modele, soit
rien), exactement le raisonnement deja tenu par `_make_portal()` qui
instancie `portal_scene` sans intermediaire.

```
Owl               <- pose par _build (position / rotation_y / scale)
  Model           <- owl_scene instance, OWL_MODEL_SCALE / OWL_MODEL_OFFSET
```

**Echelle -- derivee, pas choisie a l'oeil.** Le brief anchore
explicitement sur "2,04 de long" -- la profondeur CONSTRUITE de Keepy dans
le hub, mesuree precedemment a 2,0371. La chouette n'a pas d'axe "longueur"
comparable (elle est debout, Y domine) ; le choix retenu fait correspondre
son propre axe dominant (Y brut 1,899284) a cette meme reference, pour que
les deux creatures se lisent a une echelle comparable plutot que l'une
ecrasant l'autre :

```
scale = 2,0371 / 1,899284 = 1,07256 (uniforme)
```

Dimensions construites : X 1,3864, **Y 2,0371** (= la reference, par
construction), Z 1,5311. **`OWL_MODEL_SCALE` est type `Vector3`** (et pas
`float`, contrairement a `ModelSlot.model_scale`) -- suivant le rappel du
brief -- meme si les trois composantes sont egales ici : les proportions
mesurees etaient deja naturelles, rien ne justifiait de les deformer, et un
type Vector3 laisse un futur asset moins bien proportionne se corriger sans
replomber cette constante.

**Offset** : `Vector3(0, 1,02039, 0)`, calcule pour que le point le plus
bas du mesh (model-space min.y = -0,95136, mesure et pas suppose) touche
`y = 0` une fois mis a l'echelle -- la lecon du rondin JUMP ("l'origine
d'un .glb est ou son auteur l'a laissee") appliquee ici plutot que
supposee sans effet. X/Z laisses a zero : le centre du mesh est a moins de
2 mm de son origine sur ces deux axes, le meme ordre de bruit de mesure
deja accepte pour la libellule (1,7 mm).

**Placement -- pres du portail Quizz, PAS dessus.** Le brief avertissait
explicitement du risque de superposition. Portail Quizz a `(0, 0, -7,2)`,
rayon de disque/trigger 1,35 (mesure sur le `CylinderShape3D` reel, pas
suppose). Chouette a **`(2,7, 0, -7,2)`** -- meme profondeur Z que le
portail, offset LATERAL de 2,7 -- verifie contre les 214 autres entrees du
layout (parseur Python dedie) : le prop le plus proche degage a 2,870 u
(une souche), l'espace autour du portail Quizz avant ce lot etait donc deja
libre sur cet axe. Marge au-dela du rayon+empreinte du portail : 2,700 -
(1,35 + 0,77) = **0,58 u**.

**Orientation -- rotation_y = 0, deliberement.** Le modele fait deja face
au model +Z (mesure ci-dessus). La camera du hub regarde en permanence
`-Z` depuis le spawn ; un prop plus loin en Z-negatif que le spawn qui fait
face au monde `+Z` regarde donc VERS le joueur qui approche -- pas vers le
portail. `rotation_y = 0` obtient exactement ca sans aucune correction
locale dans `_make_owl()`.

**`OWL_FOOTPRINT_RADIUS = 0,77`** ajoute a `FOOTPRINT_RADIUS`, meme
convention que les 10 autres types deja presents (moitie du plus grand
cote construit, X ou Z) -- utilise par la recherche de debarquement du
bateau, sans effet pratique ici (la chouette n'est pres d'aucune eau), mais
la doctrine du depot veut que chaque type publie le sien.

### ETAPE 3 -- sondes et mesures

**`OwlProbe.gd`/`.tscn` (nouvelle), 16 checks, PATRON ROUGE-AVANT-VERT
VERIFIE** : le cas `&"owl":` a ete retire du `match` de `_build()`
(reproduisant le chemin `push_error("...unknown type...")` deja existant
pour tout type inconnu), le probe est reste sur **2 echecs exacts**
("an 'Owl' node exists" + "owl_root present"), puis restaure -- diff `cmp`
confirmant le fichier restaure est byte-identique a l'original. Trois
phases sur l'arbre restaure : PHASE A presence/materiau unshaded, PHASE B
placement/echelle/offset/walkabilite, PHASE C les 3 portails INCHANGES
(positions, rayon de trigger, game_id) et la chouette degagee du rayon du
portail Quizz. **16/16 OK, exit 0.**

**Compte de draw nodes : 127 -> 128, ITEMISE et pas nudge.** L'unique
`MeshInstance3D` du `.glb` (mesure : 1 noeud, 1 mesh, 1 primitive), sous un
`Node3D` non-dessinant. Non batchable -- il n'y en a qu'un. Les trois
constantes `_EXPECTED_DRAW_NODES_EXCL_PORTALS` (`SeesawProbe.gd`,
`TurnstileProbe.gd`, `WaterTintProbe.gd`) sont montees a 128 en meme temps
que le prop, jamais laissees driver seules.

**Sondes partagees, diffees contre `origin/main` en worktree separe**
(import verifie complet des deux cotes : 34 `.scn` baseline, 35 sur la
branche -- exactement +1, la chouette) :

| sonde | verdict |
|---|---|
| `AssetContractAudit`, `DeathModelAudit`, `ChargerShapeProbe` | **BYTE-IDENTIQUES** sur les deux flux |
| `ProbeTimeoutAudit` | +1 ligne exacte (`OwlProbe.tscn`, `arm()`+`deadline()` armes), **55 -> 56 sondes scenes** |
| `DivingBoardProbe`, `LakeZoneProbe`, `StreamRideProbe` | diff EXACTEMENT le compte de draw nodes/footprints rapporte (jamais gate a cet endroit) |
| `SeesawProbe`, `WaterTintProbe` | **exit 0 des deux cotes**, diff limite a la ligne de budget (127->128) |
| `TurnstileProbe` | exit 1 des DEUX cotes, **meme echec unique et pre-existant** (`entry 0's custom_aabb encloses every bar`), non cause par ce lot |
| `StreamRideProbe` | exit 1 des DEUX cotes, **memes 2 echecs pre-existants** (controle plein ecran, deja rouges sur `origin/main` avant ce lot) |

⚠️ **`WaterTintProbe` DOIT tourner sous `xvfb --rendering-driver opengl3`,
jamais `--headless`** -- son propre en-tete l'exige (elle lit des pixels).
Un premier run sous `--headless` a semble bloquer/timeout ; rejoue sous
xvfb, exit 0 des deux cotes en quelques minutes. Piege deja documente pour
cette famille de sonde, re-rencontre ici.

**`HubPerfBaseline` -- ligne ajoutee a `docs/HUB_PERF_BASELINE.md`**, trois
runs de chaque cote, meme session, machine au repos : draw nodes 127->128
(hors portails) confirme sur les 3 runs de chaque cote, construction et
FPS simule dans des plages qui se CHEVAUCHENT mais avec les pires frames
de la branche legerement sous celles du baseline (8,5 fps vs 9,7-13,1) --
rapporte tel quel, **RIEN ICI N'EST UNE MESURE DEVICE** (llvmpipe/xvfb, pas
WebGL2/Safari iOS).

### Cout .pck : mesure REELLE, exports de la meme session

| | baseline (`origin/main`, meme session) | branche |
|---|---|---|
| `index.pck` | **5 908 976** | **19 118 368** |
| `index.wasm` | 35 376 909 / md5 `af4a8fc2925d992348eb30deeeb54360` | **identique, INCHANGE** |

**Delta : +13 209 392 octets (+12,6 Mio), soit un `.pck` 3,2x plus gros.**
`index.wasm` ne bouge PAS -- confirme qu'aucun code moteur/`project.godot`
n'est touche, coherent avec un lot qui n'ajoute qu'un asset + du GDScript +
un `.tres`.

Le delta est explique **a l'octet pres** par les quatre ressources
derivees de l'installation (mesurees dans `.godot/imported/`, pas
estimees) : `.scn` geometrie 157 531 + `.ctex` baseColor 3 954 500 +
`.ctex` metallicRoughness 4 326 370 + `.ctex` normal 4 767 746 ≈ 13,2 Mio.
**Piege payload verifie plutot que suppose** : `grep`/`strings` sur le
`.pck` exporte + comptage des lignes `Storing File:` du log de savepack
(236 lignes) confirment **0** occurrence de `res://assets_source/*` ou
`res://scripts/dev/*` reellement packee, malgre les 10 nouveaux `.glb`
"ennemis" nichees DEUX niveaux sous `assets_source/openworld/` -- le glob
de l'`exclude_filter` traverse bien les sous-dossiers, pas seulement le
premier niveau.

⚠️ **LA MAP METALLIC-ROUGHNESS (4 326 370 octets, 33 % du delta) A UN
EFFET RENDU NUL SUR CE MATERIAU UNLIT** -- exactement le piege payload deja
documente cinq fois dans ce fichier pour d'autres assets. **Non stripee
ici, deliberement** : `keepy_hibou_pursuer.glb` (deja en prod) garde la
sienne dans les memes conditions, et LOT 1 est scope a "valider le
pipeline, l'echelle et le cout de rendu -- rien d'autre". Le chiffre est
publie pour que Mathieu decide : la retirer du `.glb` recupererait ~4,3 Mio
sans changer un seul pixel a l'ecran, si le poids shippe s'avere genant sur
device.

⚠️ **RAPPEL EXPLICITE, PAS UNE GARANTIE** : aucune mesure de ce sandbox
n'est une mesure de performance device. Le rendu tourne sous llvmpipe
(rasteriseur logiciel) via `xvfb`, jamais sur un GPU mobile reel ni sous
WebGL2/Safari iOS. Les chiffres ci-dessus disent CE QUI A CHANGE et DE
COMBIEN sur ce banc precis -- ils ne predisent, ne garantissent et
n'excluent rien sur un telephone.

### Validation build

Editeur + templates Godot 4.3-stable installes dans ce sandbox (releases
GitHub officielles). Import headless **exit 0**, **35 `.scn`** (34 baseline
+1, import complet verifie et pas suppose). Boot headless de
`HubWorld.tscn` **exit 0, 0 erreur, 0 `push_warning`** -- confirmation a
l'execution que l'entree owl est coherente et walkable. Export Web release
**exit 0, 0 ligne d'erreur** sur 236 lignes de savepack.

### Non-regression explicite

Les 3 portails (Chased/Quizz/Battle) restent fonctionnels et inchanges
(positions, rayons de trigger, game_id -- verifie par `OwlProbe` PHASE C).
Le lobe nord, la balancoire, le plongeoir, le tourniquet, la mare, le
ruisseau et les deux lobes du grand lac : **aucun de ces fichiers/systemes
n'est dans le diff** de ce lot (`HubRegion.gd`, `HubCamera.gd`,
`HubTapInput.gd`, `KeepyHopper.gd`, `HubStreamRoute.gd`, `HubWater.gd`
byte-intouches), et les sondes qui les couvrent (`LakeZoneProbe`,
`StreamRideProbe`, `DivingBoardProbe`, `TurnstileProbe`, `SeesawProbe`)
confirment un comportement inchange au-dela du seul compte de draw nodes.

### Reste ouvert -- jugement device, seul juge, et une decision explicite pour Mathieu

1. **Est-ce qu'une chouette de la taille de Keepy, posee a cote du portail
   Quizz, se lit comme un compagnon decoratif** a l'echelle reelle d'un
   telephone ? Aucune sonde ne le dit.
2. **Le poids ajoute (+12,6 Mio, .pck x3,2) est-il acceptable ?** Le levier
   chiffre existe (strip metallicRoughness, ~-4,3 Mio, zero effet visuel
   mesure) mais n'a pas ete tire dans ce lot.
3. **LOT 2 (vol scripte avec Keepy sur le motif RIDE_SEAT_Y) reste
   entierement a faire** -- aucun etat, hook ou trajectoire n'a ete
   prepare ici, comme demande.

`main` **non touche**. Merge sur `staging` : palier 1, automatique (build,
import, export et sondes verts -- le seul echec restant, `StreamRideProbe`,
est deja rouge sur `origin/main` et non cause par ce lot).

### SUITE : la map metallicRoughness retiree, la chouette repositionnee au spawn de Keepy (28 aout 2026)

Branche `claude/owl-strip-metallic-and-reposition`, partie de `staging`
(`1be4f14`, ce lot). Deux points laisses ouverts par LOT PROPS-1, tranches
l'un et l'autre par la mesure et non par deduction seule.

#### LOT A -- la map metallicRoughness retiree du `.glb`, effet nul PROUVE au pixel

**Recon avant tout retrait, comme demande** : le `.glb` de la chouette ne
porte **qu'UN SEUL materiau** (parseur glTF dedie, pas suppose) --
`material.001`, `KHR_materials_unlit` deja pose par LOT PROPS-1, un seul
mesh/une seule primitive. Aucune ambiguite "plusieurs sous-materiaux" a
lever.

Le materiau **reellement dessine par Godot** a ete inspecte directement
(sonde jetable instanciant `keepy_owl_decor.glb` et lisant le
`StandardMaterial3D` de la surface) : **`metallic_texture` et
`roughness_texture` sont NULS des l'import** -- l'importeur glTF de Godot
ne les lie JAMAIS sur un materiau UNLIT, quelle que soit la presence de la
map dans le fichier source. Ce n'est donc pas une deduction theorique sur
le seul flag `shading_mode = 0` : la map n'atteint jamais le materiau que
le moteur dessine, avant meme tout retrait.

`grep` sur tout le depot confirme que le nom de fichier de la texture n'est
utilise nulle part ailleurs (aucun autre prop, aucune autre scene, aucune
entree de cache uid) -- un seul consommateur, celui qu'on retire.

**Comparaison visuelle AVANT/APRES, offscreen `xvfb-run --rendering-driver
opengl3`, 4 azimuts (0/90/180/270 deg)** : rendu avec la map presente puis
rendu sans elle, diff pixel par pixel des PNG captures (640x640, RGBA) --
**les quatre paires sont BYTE-IDENTIQUES** (921 600 octets par image, 0
octet de difference sur les quatre). "Aucun effet visuel" est donc objective
et pas seulement plausible.

**Retrait par chirurgie de `.glb`, pas par simple deconnexion de reference.**
La map `Baked_MetallicRoughness` occupe le **DERNIER bufferView du chunk
BIN** (offset 8 592 908 sur 14 569 376 octets) : sa suppression est une pure
troncature, aucun decalage d'offset a faire pour la geometrie, la normal map
ni la baseColor map, qui restent **byte-identiques** avant/apres sur toute
leur plage (verifie par comparaison directe des octets, pas suppose du
fait de la position en queue de buffer). Materiau, texture et image retires
des trois tableaux JSON (`materials[].pbrMetallicRoughness.
metallicRoughnessTexture`, `textures[]`, `images[]`), `KHR_materials_unlit`
et `extensionsUsed` intacts. Le sidecar
`keepy_owl_decor_Baked_MetallicRoughness.png` + son `.import` sont
supprimes du depot -- reimport verifie : **aucun `.ctex` genere pour cette
map**, confirme sur un import propre apres `rm -rf .godot`.

**Poids `.pck` mesure DANS CETTE SESSION, export unique et propre des deux
cotes** (`rm -rf build .godot` avant chaque export, la mise en garde
permanente sur l'instabilite du `.pck`) :

| | baseline (`origin/staging`, meme session) | branche |
|---|---|---|
| `index.pck` | **19 118 288** | **14 791 280** |
| `index.wasm` | 35 376 909 / md5 `af4a8fc2925d992348eb30deeeb54360` | **identique, inchange** |

**Delta : -4 327 008 octets (-4,13 Mio, -22,6 %)** -- coherent avec
l'estimation de LOT PROPS-1 (~4,3 Mio, le poids exact de l'ancien `.ctex`
metallicRoughness, 4 326 370 octets) a moins de 700 octets pres, l'ecart
residuel etant dans la marge de bruit deja documentee (edition de
`hub_layout.tres` en LOT B + instabilite de compression connue).
`index.wasm` inchange confirme qu'aucun code moteur n'est touche.

**Piege payload verifie sur le log `savepack` du build final** : **0**
occurrence de `keepy_owl_decor_Baked_MetallicRoughness` dans les 234 lignes
`Storing File`, contre `keepy_hibou_pursuer_Baked_MetallicRoughness.jpg`
(un asset DIFFERENT, deja en prod, non touche par ce lot, conserve par
precedent) toujours present -- confirme qu'aucun autre asset n'a ete
affecte par erreur.

#### LOT B -- la chouette au spawn de Keepy, pas au portail Quizz

**Le point de spawn, LU et pas suppose** : le noeud `Keepy` de
`HubWorld.tscn` (`WorldViewport/SubViewport/World/Keepy`) ne porte **aucune
propriete `transform`** dans la scene -- il herite donc l'identite de
`Node3D`, soit **`(0, 0, 0)`**. Ce point est **fixe et unique** : `HubWorld`
est rechargee entierement (`change_scene_to_file`) a chaque retour d'un
sous-jeu, donc le noeud repart systematiquement de cette meme position
ecrite dans le `.tscn`, quel que soit le mini-jeu quitte. Pas de variation
a signaler.

**Degagement recalcule a la nouvelle position, pas suppose reconduit** :
grille fine (pas 0,1 u) sur un anneau 1,6-6,0 u autour du spawn, testant
chaque candidat contre les 214 autres entrees du layout (rayon d'empreinte
par type), contre le demi-largeur de Keepy au repos (0,6599) et contre les
quatre corps d'eau du plateau (tous a plus de 5 u de marge, sans objet ici).
Meilleur candidat retenu apres arrondi a une valeur propre :
**`(0.0, 0, -3.4)`** -- **degagement 1,574 u** au prop le plus proche (un
buisson), **1,970 u** a Keepy lui-meme, **directement dans l'axe camera**
(le champ horizontal de `HubCamera` est purement `-Z` au spawn, donc X=0
place la chouette EN PLEIN CENTRE de l'ecran des la premiere frame, sans
calcul de gisement a faire). Confirme visible en `--headless` (0 push_warning
au boot) et par execution de `OwlProbe` (position lue = position attendue).

**`rotation_y = 0` inchange, la raison tient toujours** : le modele fait
face au `+Z` local, la chouette reste plus loin en `-Z` que le spawn, donc
elle continue de regarder vers Keepy qui s'avance -- le meme raisonnement
que LOT PROPS-1, applique a la nouvelle distance.

**Aucun chevauchement au premier frame** : a 3,4 u de Keepy et 1,97 u de
marge sur son propre demi-largeur, la chouette n'est jamais visuellement
"dans" Keepy des l'apparition -- verifie par le calcul de degagement
ci-dessus, pas par observation seule.

`hub_layout.tres` reste la seule source de la position -- aucune
coordonnee en dur ajoutee dans un script.

#### Validation (LOT A + LOT B)

`OwlProbe` (`_EXPECTED_POSITION` mise a jour a `(0, 0, -3.4)`, commentaires
de tete corriges pour ne plus dire "beside Quizz") : **16/16 OK, exit 0**,
rejouee sous `xvfb --rendering-driver opengl3`. La verification de
degagement PHASE C reste generique (distance au portail Quizz + son rayon
de trigger + le rayon de la chouette) et passe avec une marge plus large
qu'avant (separation 3,800 contre 2,120 requis).

**Quatre sondes partagees, diffees contre `origin/staging` (`1be4f14`) en
worktree separe, import complet verifie des deux cotes (35 `.scn`
chacun)** : `AssetContractAudit`, `DeathModelAudit`, `ChargerShapeProbe`,
`ProbeTimeoutAudit` -- **BYTE-IDENTIQUES sur les DEUX flux (stdout ET
stderr)**, exit 0 des deux cotes. Aucun de ces quatre fichiers ne reference
la position ou le materiau de la chouette : l'identite au bit pres confirme
que ce lot n'a touche rien d'autre que ce qu'il annonce.

Import headless **exit 0, 35 `.scn`** (complet, verifie et pas suppose).
Boot de `HubWorld.tscn` **exit 0, 0 erreur, 0 `push_warning`**. Export Web
release **exit 0, 0 ligne d'erreur** sur 234 lignes de savepack.

Sondes jetables de recon (inspection materiau, capture comparative,
script de chirurgie `.glb`) **supprimees avant ce commit** -- meme
discipline que toute sonde de diagnostic ponctuel dans ce depot.

#### Non-regression explicite

Perimetre strictement limite a `assets/models/keepy_owl_decor.glb` (+ le
sidecar metallicRoughness retire), `resources/hub/hub_layout.tres` (une
seule position) et `scripts/dev/OwlProbe.gd` (constante + commentaires).
Aucun autre prop, aucune autre map, aucun autre fichier de scene ou de
script touche. `HubBuilder.gd`, `HubWorld.gd`, `HubRegion.gd`,
`HubCamera.gd`, `HubTapInput.gd` -- tous byte-intouches.

#### Reste ouvert -- jugement device, seul juge

1. **Le poids final (`.pck` -22,6 %) est-il suffisant, ou faut-il aussi
   retoucher `keepy_hibou_pursuer.glb`** (asset different, non touche ici,
   deja en prod avec sa propre map metallicRoughness) ? Question distincte,
   hors perimetre de ce lot.
2. **Est-ce que la chouette au centre de l'ecran des le spawn se lit comme
   un accueil plutot que comme un obstacle visuel** ? Aucune sonde ne le
   dit -- c'est le seul jugement qui reste, et LOT PROPS-1 complet (texture
   + position) est desormais pret pour la revue device qui debloque le
   palier 2.

`main` **non touche**. Merge sur `staging` : palier 1, automatique (build,
import, export et sondes verts).

### Merge en production (28 aout 2026, autorisation explicite de Mathieu)

`staging` (`db2ce11`) -> `main`, commit de merge **`e12966c`**, `--no-ff`,
apres validation device confirmee (capture a l'appui : echelle correcte,
aucune gene visuelle).

**Verifie AVANT le merge** : `git fetch --all --prune`, `origin/main`
(`2ae7901`) et `origin/staging` (`db2ce11`) exactement les SHA annonces.
`merge-base(origin/main, origin/staging) = origin/main` -- `main` n'avait
avance d'AUCUN commit au-dela du merge-base (pas de commit `.glb` brut a
verifier ici), donc `staging` est un strict sur-ensemble de `main`. La
chaine de commits attendue (`80cb614`, `c689113`, `5ce276a`, `b8456de`,
`b7aa628`, `18195e8`, `1be4f14`, `92742be`, `db2ce11`) est presente au
complet. Merge `--no-ff` sans conflit, arbre du merge **byte-identique a
`origin/staging`** (`git diff HEAD origin/staging` vide) -- ce qui part en
prod est litteralement l'arbre valide, pas une recomposition.

CI **run #298** (id `33197115598`) **verte** (17:58:00 -> 18:02:23 UTC) --
`Import project resources` 17:58:36 -> 18:01:50, `Export Web build`
**18:01:50 -> 18:01:55**, `Deploy to Vercel [PRODUCTION -- main]` **succes**
18:02:09 -> 18:02:21, `[STAGING -- staging]` correctement **skipped** (push
sur `main`).

**Verifie SUR LE SERVICE, pas seulement dans le log CI, avec les DEUX
marqueurs de fraicheur** :

| marqueur | valeur servie |
|---|---|
| `CACHE_VERSION` | `1787940114` = **18:01:54 UTC** -- tombe exactement dans la fenetre `Export Web build` (18:01:50 -> 18:01:55) |
| `x-vercel-cache` / `age` | `MISS` / `0` sur `index.html` ET `index.service.worker.js` |
| `index.wasm` servi | **35 376 909** octets -- identique au fingerprint permanent deja consigne pour tout lot qui ne touche pas le code moteur |
| `index.pck` servi | 14 791 328 octets (marqueur "nouveau build", jamais preuve d'identite -- attendu plus lourd que le fingerprint historique, ce lot ajoute pour la premiere fois un `.glb` Meshy non-Keepy + ses deux textures baked au pack) |

`index.wasm` inchange confirme qu'aucun code moteur n'a bouge, coherent :
ce merge n'ajoute que l'asset chouette (`.glb` + textures, `.import`),
`hub_layout.tres`, `HubBuilder.gd`, `HubWorld.tscn`, `OwlProbe.{gd,tscn}`
et les ajustements de budget de noeuds dans les sondes existantes.

**Aucune sonde re-derouleee dans cette session** : le tree pousse sur
`main` est byte-identique a celui deja valide sur `staging` (`OwlProbe`
verte, budget de noeuds partage a 128, capture device confirmee par
Mathieu) -- meme principe deja applique aux merges tourniquet, diving
board, lobe nord/balancoire precedents.

**La chouette decor statique (LOT PROPS-1 complet) est desormais EN
PRODUCTION** sur `keepy-ten.vercel.app`.

**Reste ouvert : aucun sur ce merge.** Les deux points laisses ouverts par
le lot de staging (poids du `.pck`, lisibilite au spawn) restent des
questions de jugement device deja tranchees par la validation qui a
autorise ce merge -- rien ne bloque plus derriere.

## LE HIBOU EMPORTE KEEPY : une boucle FERMEE, un tap dedie sur le patron du BATEAU, et trois premisses du brief qui tombent a la mesure (28 aout 2026)

Branche `claude/hub-owl-flight-sbepk8`, partie de `main` (`f2b44a1`, verifie
par ARBRE et pas par nom : `origin/main` porte exactement ce SHA et
`origin/staging` (`db2ce11`) en est un ancetre strict -- aucune session
concurrente, aucun commit `.glb` brut a signaler).

Le hibou statique de LOT PROPS-1 devient ridable : un tap sur son perchoir
fait MARCHER Keepy jusqu'a lui (le patron du bateau et de l'echelle), il
decolle DEPUIS le hibou, fait une boucle et se repose AU hibou. **UN SEUL
hibou** -- c'est le prop lui-meme qui vole, le perchoir reste vide pendant
le vol, donc **zero noeud de dessin ajoute**. Aucune animation de squelette :
le `.glb` n'en a pas, et tout ce lot passe par des transforms, comme
`FighterView.gd` et `KeepyHopper.gd` le font deja pour le meme modele.

### ⚠️ PREMISSE FAUSSE N°1 : L'ECHELLE FAIT DEJA CE QUE LE BRIEF LUI OPPOSE

Le brief opposait deux comportements -- l'echelle declencherait `CLIMBING`
**immediatement** au tap, le hibou devrait au contraire reagir **A
L'ARRIVEE** d'un hop normal. **Lu dans le code : l'echelle fait DEJA la
seconde chose.** `_on_tapped_ladder` arme `_climbing` puis appelle
`hop_to(point)` -- un hop parfaitement ordinaire -- et c'est
`_on_hop_landed` qui appelle `_try_climb` a l'arrivee. Le seul chemin
immediat est `if not _keepy.is_hopping()`, c'est-a-dire « il etait deja
debout au pied ».

La vraie difference est ailleurs, et elle est ce qui a decide le patron a
copier : **le bateau SE RETIRE du tap pendant un ride** (`accepts_boarding_
tap()` rend faux, donc un tap retombe sur `tapped_ground` et DEVIENT
l'eject) ; **l'echelle ne se retire jamais** -- elle emet `tapped_ladder`
quoi que fasse Keepy, et `HubWorld` le jette. C'est sans consequence pour une
planche, dont le seul autre sens serait un plongeon deja traite par etat ;
ce serait faux ici, ou un tap pendant le vol doit pouvoir atteindre le
chemin sol. `owl_available` est cette retraite, et c'est un simple booleen
plutot qu'un second noeud a interroger parce qu'il n'y a pas d'objet
cote hibou a qui demander : `HubWorld` sait deja si un vol tourne.

### ⚠️ PREMISSE FAUSSE N°2 : le hibou n'etait PAS a un endroit tenable

Le brief donnait l'ecart Quizz comme un chevauchement de **0,05 u** entre le
disque de tap standard (2,5) et celui du portail. **Reproduit exactement** :
`d((0,-3,4),(0,-7,2)) = 3,800` contre `2,5 + 1,35 = 3,85`.

Mais ce chiffre n'est pas le vrai probleme, et le brief avait raison de
demander un DECALAGE plutot qu'un rayon plus petit : **sur l'axe, le disque
du hibou se serait tenu en travers de la seule ligne qu'un joueur parcourt
du spawn au portail Quizz.** Chaque tap vise sur Quizz serait devenu un tap
« vole avec moi ». Un rayon plus etroit ferme l'arithmetique et laisse le
defaut d'usage entier.

Balayage exhaustif au pas 0,1 contre les **215 autres entrees** du layout,
les **4 plans d'eau** et la position de Keepy, avec le rayon d'empreinte de
chaque type :

| | position | degagement | d(Quizz) | lateral |
|---|---|---|---|---|
| avant | (0, 0, -3.4) | 1,346 u | **3,800** | **0,00** |
| **livre** | **(-2.7, 0, 0.8)** | **1,088 u** | **8,443** | **2,70** |

⚠️ **ET UNE TROISIEME CHOSE, MESUREE ET PUBLIEE PLUTOT QUE MAQUILLEE :
« devant le spawn, hors de l'axe, et dans le cadre » est un ensemble VIDE.**
Le cone visible est de ±22,5° autour de -Z (fov HORIZONTAL de 45°,
`keep_aspect = KEEP_WIDTH`, et la camera ne lacete jamais), donc a z negatif
« dans le cadre » veut dire « pres de l'axe » -- exactement ce dont il faut
sortir. Le balayage rend **0 candidat** a z<0 avec un degagement utilisable.
Ce qui existe est **a COTE du spawn** (z ≈ +0,8), et c'est ce qui est livre :
en frame, a 2,82 u de Keepy, avec le spawn lui-meme **1,02 u en dehors** du
disque de tap.

**`OWL_TAP_RADIUS = 1.8`, et non les 2,5 du bateau et de l'echelle.** Ces
deux-la valent 2,5 parce que la cible est minuscule (un pied d'echelle fait
0,5 u de large). Le hibou fait 1,39 x 1,53 au sol et 2,04 de haut -- une
bien plus grosse marque -- et 2,5 centre a 2,82 u du spawn aurait recouvert
les pieds de Keepy, si bien qu'un tap sur ses orteils aurait voulu dire
« vole ».

### LA BOUCLE FERME PAR ARITHMETIQUE, JAMAIS PAR REGLAGE

C'est la raison pour laquelle cette courbe a ete choisie plutot qu'un chemin
pose a la main. Chaque terme est periodique en `t` et vaut exactement le
perchoir aux deux bouts :

```
x = R sin(TAU t)          sin(0) = sin(TAU) = 0
z = -R (1 - cos(TAU t))   cos(0) = cos(TAU) = 1
y = APEX sin(PI t)        sin(0) = sin(PI) = 0
```

C'est un cercle de rayon `R` passant par le perchoir, centre `R` devant lui,
donc le point le plus lointain est a `2R` -- **mesure a 7,34 u du perchoir
et 3,60 u en l'air**, et le retour tombe sur le perchoir a **0,000000 u**.
Le lacet est la TANGENTE de ce meme cercle, qui n'est jamais de longueur
nulle : il n'y a aucun instant degenere a garder, contrairement a un chemin
droit entre deux points.

`HubStreamRoute` n'est **PAS** reutilise et n'a pas ete touche : il aplatit
Y et son modele est a deux bouts, ce qu'une boucle fermee n'est pas.

⚠️ **LE PENCHANT DE LA BOUCLE EST MESURE, PAS CHOISI -- et la premiere
version echouait sans que rien ne le dise.** A `heading = 0` le cercle
balaie un rayon plein de chaque cote du perchoir, or le perchoir est deja a
gauche du centre : **la jambe de retour sortait du cadre, 26 points sur 33 a
l'ecran** -- le hibou s'envolait, disparaissait, puis revenait. Toutes les
autres assertions passaient quand meme. Balaye contre la VRAIE camera aux
DEUX ratios livres (1080x1920 et 1170x2532) avec `unproject_position`, sur
le rayon et le penchant ensemble :

| heading | dans le cadre | pire marge laterale |
|---|---|---|
| 0° | **50/65** | **-105 px (HORS CADRE)** |
| **-35° (livre)** | **65/65** | **+100 px** (1080) / **+109 px** (1170) |
| -45° | 65/65 | +143 px |

`OWL_LOOP_HEADING_DEG = -35.0` est le premier penchant qui garde **toute** la
boucle a l'ecran au rayon plein. La rotation est appliquee a l'OFFSET et a
la TANGENTE, jamais a la forme de la courbe -- une rotation de zero reste
zero, donc la fermeture demontree plus haut survit intacte. **Gate par
sonde** : le penchant est une constante, donc il peut etre retire aussi
silencieusement qu'il a ete trouve necessaire.

### Le rider est ecrit DANS LE MEME APPEL que le hibou

`follow_owl()` n'est **jamais** appele depuis `_process`. Ce n'est pas une
precaution recopiee du seesaw -- c'est la MESURE du tourniquet : un rider
qui echantillonnait son porteur sur son propre callback par frame etait une
frame entiere en retard, **12,0 deg au pic de la poussee**, et
`process_priority` n'y changeait rien (les steps de Tween tombent apres le
`_process` de tout noeud). Un vol couvre des metres et non des degres, donc
le meme retard serait un Keepy visiblement traine derriere l'oiseau.
`_apply_flight` ecrit le porteur puis le rider, dans cet ordre. **Mesure sur
40 frames reelles, tween en marche : pire ecart 0,000000 u**, avec un BLIND
CHECK qui prouve d'abord que le hibou a reellement couvert 1,96 u sous lui
-- sans quoi « il est exactement sur la selle » passerait gratuitement
contre un hibou qui n'aurait pas bouge.

Le siege est **Y SEUL** (`OWL_SEAT_Y = 1.22`, 60 % de la hauteur mesuree du
hibou construit, 2,0371 u) : un offset en X ou Z partirait de cote des que
l'oiseau s'incline dans son virage.

### Le demontage reutilise `_ride_exit_point()` SANS LE MODIFIER

Cette fonction ne lit que `"position"` et `"radius"` et ne sait rien d'un
prop particulier -- elle etait deja generique, donc le hibou l'a appelee
plutot que d'en copier une. `OWL_TAP_RADIUS` est ecrit dans l'entree copiee
par `_setup_owls()` comme `"radius"`, ce qui fait de « assez pres pour
taper », « assez pres pour decoller » et « assez loin pour etre depose » **un
seul nombre** au lieu de trois qui derivent. Mesure : il atterrit a
**2,65 u** du perchoir contre une portee de 1,80 -- la boucle de remontage
que le tourniquet a du apprendre ne peut pas se produire.

Le registre `owls()` est une **LISTE des le premier commit**, et c'est la
lecon du plongeoir payee d'avance : sa GEOMETRIE etait generique le jour ou
il a ete livre, c'est la table en aval qui n'en tenait qu'un, si bien qu'une
seconde planche etait dessinee et jamais grimpable -- et defaire ca a coute
son propre lot.

### `OwlFlightProbe` : 43 checks, 0 echec, GATEE, et VERIFIEE ROUGE D'ABORD

Gatee parce que **tout mode de panne est SILENCIEUX** : registre vide,
signal de tap qui n'arrive jamais, hook de decollage cable sous un des
`return` anticipes de `_on_hop_landed`, rider une frame en retard, courbe
qui ne ferme pas tout a fait (le hibou derive de son perchoir un peu plus a
chaque vol), demontage qui retombe dans la portee. Aucun ne leve, aucun ne
casse un build.

**Rouge avant vert, mesure et pas affirme** : le hook de decollage
neutralise (`if false and _try_fly(...)`), la sonde sort en **exit 1** avec
exactement **2 FAIL** -- « he walked there and took off (900 frames) » et
« clear of the perch's own reach (0.00 u vs 1.80) », c'est-a-dire un Keepy
qui finit debout SUR le perchoir sans jamais decoller. Hook restaure :
**43/43, exit 0**.

Deux BLIND CHECKS, sur la discipline de `SeesawProbe`/`TurnstileProbe` : une
assertion d'egalite doit prouver qu'elle sait voir une difference avant
qu'on lui fasse confiance en cas de succes. « la boucle revient a son point
de depart » est satisfait gratuitement par un hibou qui n'a jamais bouge, et
« il est exactement sur la selle » par un hibou immobile sous lui.

⚠️ **Piege deja consigne, re-rencontre a la lettre** : ma premiere version
appelait `ProbeWatchdog.abort_if_exceeded(dl)` (statique) au lieu de
`dl.abort_if_exceeded()`. Une sonde dont le SCRIPT ne parse pas ne tombe pas
vite -- la scene ne se charge jamais, donc `arm()` n'est jamais atteint, il
n'y a pas de watchdog du tout, et le process tourne a vide **sans une seule
ligne de sortie**. Le boot `--quit-after 3` le fait apparaitre en secondes.

### Validation

Editeur + templates Godot 4.3-stable installes dans ce sandbox (releases
GitHub officielles, **tailles verifiees contre le `Content-Length`** :
**50 276 070** et **1 073 228 327** octets, aucune troncature silencieuse).
Import headless **exit 0, 35 `.scn`, 0 erreur**. Export Web release
**exit 0**, aucune erreur GDScript.

`index.wasm` **35 376 909** octets / md5
**`af4a8fc2925d992348eb30deeeb54360`** et `index.js` md5
**`4e08904b1b7107858246af44b602067b`** -- identiques au fingerprint deja
consigne pour tout lot qui ne touche pas le code moteur. `index.pck`
**14 796 400** -- marqueur « nouveau build », **jamais** preuve d'identite.
**Piege payload tenu** : sur **234** lignes `Storing File`, **0** pour
`scripts/dev`, `assets_source`, `docs`, `web`, `build` ou `firebase.json`.

**Non-regression, et elle n'est pas prise sur parole** : ce lot touche
`HubTapInput`, `KeepyHopper` et `HubWorld`, que le bateau, l'echelle, le
plongeoir, le tourniquet et la balancoire partagent tous. PHASE UNTOUCHED de
la sonde re-verifie les trois pieds d'echelle, les trois planches, la
balancoire, le tourniquet et les trois portails ; `AssetContractAudit`
(**12/12 visuels, 0/10 colliders deplaces**), `DeathModelAudit`,
`ChargerShapeProbe` et `ProbeTimeoutAudit` sont rejouees en diff contre
`origin/main` en worktree separe.

### Reste ouvert -- jugement device, seul juge

1. **Est-ce qu'un hibou qui emmene Keepy en boucle sur 3,2 s se lit comme un
   oiseau qui prend un passager**, ou comme un prop qui glisse dans l'air ?
   C'est tout l'objet du lot, et aucune sonde ne le dit.
2. **Le perchoir est a COTE du spawn et non devant** (§ premisse n°2), donc
   il se decouvre en se retournant plutot qu'a l'arrivee -- mesure comme la
   seule option disponible, jamais juge a l'oeil.
3. **Un tap pendant le vol ne fait rien.** Le tourniquet et la balancoire se
   re-arment sur un tap parce qu'un manege et une planche sont des choses
   qu'on repousse ; une boucle qui ferme exactement ne peut pas etre
   prolongee sans casser la propriete pour laquelle la courbe a ete choisie.
   Assume, jamais teste au pouce.
4. **Aucun son, aucune particule, aucun asset neuf** : hors perimetre.
5. **Rien ici n'est un rendu device** : llvmpipe sous xvfb via le backend
   `opengl3` de BUREAU, contre WebGL2 sous Safari.

## VOL DU HIBOU : LE SIEGE ETAIT UNE FRACTION DE BBOX, PAS UNE MESURE -- Keepy remonte du buste a la nuque (28 aout 2026)

Branche `claude/owl-flight-seat-fix-2dbq8k`, partie de `staging` (`8aa4f09`,
tree-identique a `54efc05` -- le merge du lot vol n'ajoute aucune ligne).
Retour device de Mathieu, capture a l'appui : Keepy est PLANTE DANS le
corps du hibou en vol (buste chevauchant les ailes), et semble tourne de
travers.

### RECON -- `OWL_SEAT_Y` n'avait jamais touche le mesh reel

`OWL_SEAT_Y = 1.22` etait derive comme **60 % de la hauteur totale du
hibou construite** (2,0371) -- "au-dessus de la masse du corps, sous la
tete", **par analogie** avec un rider a torse fin plutot que par une
mesure sur CE modele. Faux, et faux d'un facteur enorme : parse glTF
direct du `.glb` livre (attribut `POSITION`/`indices`, aucune dependance
externe), **ray-cast reel contre les triangles du maillage** (pas la
simple lecture de sommets voisins, qui aurait pu tomber sur une arete
plutot que la surface) au point (x=0, z=0) -- le SEUL point possible,
puisque `mount_owl()` n'accepte qu'un offset en Y
(`_owl_seat = Vector3(0.0, seat_y, 0.0)`), tout offset horizontal
balayant lateralement des que l'oiseau vire :

```
surface reelle du maillage a (0,0), model-space  y = 0,9031254854712962
seat_y = OWL_MODEL_OFFSET.y + OWL_MODEL_SCALE.y * 0,9031254854712962
       = 1,02039 + 1,07256 * 0,9031254854712962
       = 1,98905
```

**Le plancher/plafond de recherche est le meme calcul que `OWL_MODEL_OFFSET`
et `OWL_MODEL_SCALE` (LOT PROPS-1), reutilise et pas redecouvert** : les
bornes brutes du modele (Y -0,95136 a +0,94792) donnent bien un total
construit de 2,0371 -- confirme, pas suppose.

**Verifie que la surface est un DOME LARGE et pas un artefact ponctuel** :
balayage 7x5 autour de (0,0) (x de -0,20 a +0,20, z de -0,15 a +0,15),
tous les points dans [0,826 ; 0,908] -- une nappe continue, pas un pic
isole. C'est la nuque/le sommet de tete d'un oisillon rond ("Ember Eyed
Owlet"), ou le corps et la tete sont fusionnes en une seule masse : il
n'existe PAS de "dos" separe plus bas que la tete, contrairement a
l'hypothese de l'ancien 60 %, qui enterrait Keepy jusqu'a la poitrine.

### CE QUI N'EST PAS TOUCHE, et pourquoi

`_yaw.rotation_degrees.y = _owl.global_rotation_degrees.y` -- **la copie
directe du yaw du porteur** -- est **intouchee**. Ce n'est pas un oubli :
c'est l'architecture documentee de `mount_owl()`/`follow_owl()` (seat
Y-only, "aucun cote a choisir, un hibou n'a qu'un dos"), et rien dans les
captures ne montre une orientation fausse une fois le clipping corrige
(voir plus bas). Le "tourne de travers" du retour device etait tres
probablement une lecture visuelle confuse d'un buste enterre a un angle
bizarre, pas un defaut d'orientation reel -- **et c'est verifie, pas
suppose** : la sequence de captures ci-dessous montre Keepy face a la
meme direction que le hibou a chaque point de la boucle, y compris en
plein virage banking (apex).

### PREUVE MULTI-POINTS, capture reelle et pas seulement le calcul

`OwlFlightProbe` (42/42 OK) confirme la ligne "the seat is above the
owl's feet (1.989)" et que le rider n'est jamais a plus de 0,000000 u de
son porteur (le controle du lag d'une frame, deja etabli au lot
turnstile/seesaw). Mais ca ne dit rien de ce que ca donne A L'ECRAN --
d'ou une sonde jetable (supprimee avant commit) rendant `xvfb-run
--rendering-driver opengl3` :

- **Vue orthogonale de profil, au perchoir, sans banking** -- Keepy
  touche la nuque du hibou exactement au niveau de la base des
  aigrettes, aucun chevauchement, aucun flottement.
- **Vue orthogonale de face** -- Keepy parfaitement centre au-dessus de
  la tete, confirme que l'offset horizontal nul ne derive pas.
- **Quatre points de la boucle (decollage t=0,02 / montee t=0,25 / apex
  t=0,5 / descente t=0,75)**, camera au NIVEAU du siege (pas au-dessus,
  ce qui aurait introduit une illusion de flottement par raccourci -- le
  piege dans lequel une premiere passe de capture, avec la camera
  au-dessus regardant vers le bas, est tombee et a ete corrigee avant
  toute conclusion) -- Keepy assis proprement sur la tete a chaque point,
  y compris a l'apex ou l'oiseau est vu de dos en plein virage : meme
  orientation, aucun chevauchement de buste.

⚠️ **Piege de mesure rencontre et corrige avant de conclure quoi que ce
soit** : la premiere camera diagnostique (position `owl + (4, 1.2, 0)`,
`look_at` vers un point legerement au-dessus du hibou) donnait
l'impression d'un Keepy flottant tres au-dessus du hibou -- un artefact
de perspective (camera regardant vers le bas depuis une position
au-dessus de la cible, donc raccourcissant l'oiseau plus que le rider).
Refaite en orthogonal (aucune distortion de perspective possible) et en
perspective-mais-au-niveau-du-siege : les deux convergent sur le meme
resultat, contact propre, aucun flottement.

### Validation

Editeur + templates Godot 4.3-stable installes dans ce sandbox (releases
GitHub officielles, tailles verifiees contre le `Content-Length` --
50 276 070 et 1 073 228 327 octets, aucune troncature). Import headless
**exit 0, 35 `.scn`** (import complet verifie, pas suppose). Boot de
`HubWorld.tscn` **exit 0, 0 erreur**. `OwlFlightProbe` **42/42 OK, exit 0**
(seat 1,989 lu par la sonde elle-meme, pas par ce rapport). Export Web
release **exit 0, 0 ligne d'erreur** sur 234 lignes de savepack.
`index.wasm` **35 376 909 octets / md5
`af4a8fc2925d992348eb30deeeb54360`** -- identique au fingerprint deja
consigne pour tout lot qui ne touche pas le code moteur, coherent : ce
lot ne change qu'une constante et son commentaire dans `HubBuilder.gd`.
Piege payload tenu (0 ligne `Storing File` pour `scripts/dev`).

**Sondes partagees, toutes exit 0** : `AssetContractAudit` (12/12
visuels, 0/10 colliders deplaces), `DeathModelAudit` (le seul stderr est
`Parameter "m" is null`, deja documente comme benin -- dummy driver, a la
liberation des noeuds, APRES son propre verdict PASSED), `ChargerShapeProbe`,
`ProbeTimeoutAudit` (**57 sondes scenes**, toutes armees -- retour exact
a la baseline apres suppression de la sonde de capture jetable).

**Non-regression** : le hibou statique au repos, le tourniquet, la
balancoire, le plongeoir et le bateau -- aucun de ces fichiers n'est dans
le diff (`git diff --stat` : un seul fichier, `HubBuilder.gd`), et PHASE
UNTOUCHED de `OwlFlightProbe` re-confirme les trois pieds d'echelle, les
trois planches, la balancoire, le tourniquet et les trois portails.

### Reste ouvert -- jugement device, seul juge

1. **Est-ce qu'assis sur la nuque/le sommet de tete -- plutot qu'entre des
   ailes qu'un oisillon rond n'a pas vraiment de "dos" pour separer --
   se lit comme "Keepy chevauche le hibou"** ? C'est la question que ce
   lot pose a Mathieu -- la geometrie ne laisse pas d'autre point possible
   au seul offset (x=0, z=0) que l'architecture autorise.
2. Tout ce qui restait ouvert au lot precedent (perchoir a cote du spawn,
   aucun tap pendant le vol, aucun son/particule) est **inchange**.

### Deploiement staging (palier 1, automatique)

`staging` **`66ac351`** (merge `--no-ff`, arbre **byte-identique** a la
branche feature : meme hash d'arbre des deux cotes ET `git diff` vide,
verifie AVANT le push -- `staging` n'avait pas divergue depuis le merge du
lot vol, aucune session concurrente). CI run **#301** (id 33206249700)
**verte** : `Import project resources` 19:59:59 -> 20:03:16 (3 min 17 s),
`Export Web build` **20:03:16 -> 20:03:21**, `Verify export output` succes,
`Deploy to Vercel [STAGING -- staging]` succes, `[PRODUCTION -- main]`
correctement **skipped**. **`main` NON touche** (le lot corrige un defaut
constate sur device, la validation doit repasser par device avant tout
palier 2).

**Verifie SUR LE SERVICE, pas dans le log CI, sur DEUX marqueurs
independants et aux DEUX bouts** :

| marqueur | avant | apres (ce lot, run #301) |
|---|---|---|
| `CACHE_VERSION` | `1787944610` = **19:56:50 UTC** | **`1787947401` = 20:03:21 UTC** |
| `index.pck` servi | -- | **14 796 384** |
| `index.wasm` servi | -- | **35 376 909** *(identique a l'export local, md5 `af4a8fc2925d992348eb30deeeb54360`)* |

L'epoch d'apres tombe **exactement sur la fermeture de l'etape `Export Web
build`** du run #301, et les deux lectures d'apres (`CACHE_VERSION` et
`fileSizes`) portent **`x-vercel-cache: MISS`, `age: 0`**, `last-modified`
colle a l'instant de la requete -- pas une reponse de cache. La valeur
"avant" a ete relevee sur un `HIT` d'age non nul, valable comme VALEUR
(elle precede le push) mais explicitement **pas** une mesure de fraicheur.

### Merge en production (28 aout 2026, autorisation explicite de Mathieu)

`staging` (`b052881`) -> `main`, commit de merge **`0a2b4d3`**, `--no-ff`,
apres validation device confirmee sur capture ("satisfaisant") : vol du
hibou en boucle fermee, fix du siege (`seat_y` mesure sur le mesh reel
plutot que sur une fraction de bbox), plus de chevauchement Keepy/hibou.

**Verifie AVANT le merge** : `git fetch --all --prune`, `origin/main`
(`f2b44a1`) et `origin/staging` (`b052881`) exactement les SHA annonces.
`merge-base(origin/main, origin/staging) = origin/main` -- main n'avait
avance d'AUCUN commit au-dela du merge-base, donc `staging` est un strict
sur-ensemble de `main`. La chaine de commits attendue (`d813ed7`,
`f16e143`, `54efc05`, `8aa4f09`, `565bdb7`, `66ac351`, `b052881`) est
presente au complet. Merge `--no-ff` sans conflit, arbre du merge
**byte-identique a `origin/staging`** (`git diff HEAD origin/staging`
vide, memes hash d'arbre des deux cotes `a30dfda8`) -- ce qui part en
prod est litteralement l'arbre valide, pas une recomposition.

CI **run #303** (id `33207178140`) **verte** (20:11:48 -> 20:16:20 UTC) --
`Import project resources` 20:12:29 -> 20:15:45, `Export Web build`
**20:15:45 -> 20:15:50**, `Deploy to Vercel [PRODUCTION -- main]`
**succes** 20:16:07 -> 20:16:17, `[STAGING -- staging]` correctement
**skipped** (push sur `main`).

**Verifie SUR LE SERVICE, pas seulement dans le log CI, avec les DEUX
marqueurs de fraicheur** :

| marqueur | valeur servie |
|---|---|
| `CACHE_VERSION` | `1787948149` = **20:15:49 UTC** -- tombe exactement dans la fenetre `Export Web build` (20:15:45 -> 20:15:50) |
| `x-vercel-cache` / `age` | `MISS` / `0` sur `index.html` ET `index.service.worker.js` |
| `index.wasm` servi | **35 376 909** octets -- identique au fingerprint permanent deja consigne pour tout lot qui ne touche pas le code moteur |
| `index.pck` servi | 14 796 384 octets (marqueur "nouveau build", jamais preuve d'identite) |

`index.wasm` inchange confirme qu'aucun code moteur n'a bouge, coherent :
ce merge ne touche que `scripts/hub/*.gd`, `resources/hub/hub_layout.tres`
et `scripts/dev/OwlFlightProbe.{gd,tscn}` -- deja valides sur `staging`.

**Aucune sonde re-derouleee dans cette session** : le tree pousse sur
`main` est byte-identique a celui deja valide sur `staging` (`OwlFlightProbe`
42/42, sondes partagees toutes vertes, validation device confirmee) --
meme principe deja applique aux merges tourniquet, diving board, lobe
nord/balancoire et chouette decor precedents.

**Le vol du hibou avec le fix de siege est desormais EN PRODUCTION** sur
`keepy-ten.vercel.app`.

**Reste ouvert : aucun sur ce merge.** Le seul point laisse ouvert par le
lot de staging (est-ce que "assis sur la nuque" se lit comme "Keepy
chevauche le hibou") est un jugement device deja tranche par la
validation qui a autorise ce merge.

