# Audit visuel du hub 3D — RECON PURE (4 septembre 2026)

> Chantier ouvert par ce lot. **RECON PURE, LECTURE SEULE : aucun rendu,
> matériau, shader, position ni asset modifié ; aucun fichier supprimé.**
> Les seuls fichiers écrits sont ce document et une ligne d'index dans
> `CLAUDE.md` et `docs/lots/INDEX.md`. Les deux sondes qui ont produit les
> mesures (`HubVisualAuditProbe`, `HubVisualAuditPass2`) sont **jetables et
> supprimées avant le commit**, conformément à la règle « SONDE JETABLE =
> SUPPRIMÉE AVANT LE COMMIT » de `CLAUDE.md`.
>
> Base : `staging` (`464a08c`). Les branches CH21 non mergées
> (`claude/corridor-ab-clearance-recon-bdxrz5`,
> `claude/tyrolienne-recon-igte4f`) n'ont été ni lues ni mergées ; le CH21
> déjà présent sur `staging` fait partie de l'arbre mesuré.
>
> Doctrine permanente : voir `CLAUDE.md`. Index : `docs/lots/INDEX.md`.

## Convention de lecture : MESURÉ contre ESTIMÉ

Ce document distingue partout deux registres, et le dit à chaque fois :

* **MESURÉ** — produit par une sonde sous `xvfb-run --rendering-driver
  opengl3`, chiffre reproductible. Toute table sans mention est mesurée.
* **ESTIMÉ** — jugement porté à l'œil sur les captures, ou coût de
  développement évalué. Toujours préfixé **(estimé)**.

## Méthode, et ce qu'elle ne prouve pas

Le décor du hub est **procédural** : `scenes/HubWorld.tscn` ne contient ni
arbre ni rocher, tout est construit à l'exécution par
`scripts/hub/HubBuilder.gd` (155 Ko) à partir de
`resources/hub/hub_layout.tres`. **L'inventaire ne peut donc pas se lire dans
la scène — il a été mesuré sur l'arbre vivant.**

Les deux sondes tournent sous `xvfb-run --auto-servernum -s "-screen 0
1600x1000x24" -- godot4 --rendering-driver opengl3`, **jamais `--headless`
seul** : la lecture des transforms de `MultiMesh` et l'échantillonnage de
pixels sont précisément les deux choses que le driver DUMMY casse en
silence. Les deux gardes documentées sont armées : le rect du viewport est
asserté non dégénéré (1080x1920 puis 1280x720 forcé), et chaque capture
imprime la moyenne RGB de sa frame — treize moyennes non nulles, donc
treize images réellement rendues et non treize PNG noirs.

**Ce que ces captures ne prouvent pas** : rien du comportement shader en
WebGL2 sous Safari iOS. Elles sont valables pour la composition, l'échelle
et les silhouettes, et pour rien d'autre. Aucun verdict shader n'est tiré
d'elles ici.

⚠️ **Limite assumée de cet audit** : le total de triangles publié plus bas
est celui de **la scène entière**, pas celui de la **pire frame**. Le
frustum culling fait qu'une frame en dessine moins. Mesurer la pire frame
demande une sonde du type `TrackPropsAudit` phase 1, **qui n'a pas été
lancée ici**. Le chiffre de scène est le majorant, et c'est le seul contre
lequel un nouvel asset peut être arbitré sans re-mesure.

## Trois prémisses du brief mesurées — deux tombent

`CLAUDE.md` demande de reproduire un chiffre du dossier avant d'en publier
un neuf. Trois prémisses du brief ont été vérifiées avant tout le reste.

| prémisse du brief | verdict | mesure |
|---|---|---|
| « `model_scale` (Vector3, la normalisation non-uniforme existe) » | **FAUSSE** | `ModelSlot.model_scale` est un **`float`**, uniforme par construction (`scripts/world/ModelSlot.gd:97`). Toutes les échelles mesurées dans le hub sont uniformes : ours `(0.0113, 0.0113, 0.0113)`, blaireau `(0.0130, 0.0130, 0.0130)`. **Aucune normalisation non-uniforme n'existe dans le hub aujourd'hui.** |
| « aucun système de particules dans le repo » | **VRAIE** | 0 occurrence de `GPUParticles3D.new()`, `CPUParticles3D.new()`, `type="GPUParticles"` ou `type="CPUParticles"` dans `scenes/` et `scripts/`. Les seules occurrences du mot sont des **commentaires** expliquant pourquoi il n'y en a pas (`HubWorld.gd:2850`, `CabinHearts.gd:12`). |
| « `decimate_hazard.py` est le seul décimateur, donc aucun chemin pour du décor neuf » | **FAUSSE sur la prémisse, presque juste sur la conclusion** | Il existe **aussi `scripts/dev/decimate_decor.py`** (253 lignes), écrit pour du décor. Il est lui aussi hardcodé (`MODELS` à 4 sujets), donc la conclusion « pas de chemin pour un prop neuf » tient — mais **le coût de la généralisation change complètement**. Voir « Arbitrage pipeline ». |

## ÉTAPE 1 — INVENTAIRE MESURÉ

### 1.1 Localisation réelle des scènes

Chemins **constatés**, pas supposés :

| fichier | rôle |
|---|---|
| `scenes/HubWorld.tscn` | **LA scène du hub 3D.** `Control` → `SubViewportContainer` → `SubViewport` → `World: Node3D`. Contient `WorldEnvironment`, `Ground`, `Props`, `Keepy`, `Camera3D`. |
| `scenes/Hub.tscn` | **N'est pas le hub 3D** — c'est l'ancien menu 2D (`scripts/ui/Hub.gd`, `title_cover.png`). Hors périmètre. |
| `scenes/HubPortal.tscn` | Le portail instancié 3 fois par `HubBuilder`. |
| `scripts/hub/HubBuilder.gd` | Construit **tout** le décor à l'exécution (155 Ko). |
| `resources/hub/hub_layout.tres` | **214 entrées** de placement. |
| `scripts/world/ModelSlot.gd` | Le point de swap placeholder → `.glb`. |

Décompte des entrées du layout, **mesuré** sur le `.tres` :

    rock 48 | tree 44 | flower 34 | bush 34 | landmark 15 | stump 14
    pontoon 5 | portal 3 | islet 3 | divingboard 3 | greatlake 2
    zipline 1 | turnstile 1 | stream 1 | seesaw 1 | pond 1 | owl 1
    lake 1 | cabin 1 | boat 1                        --- TOTAL 214

### 1.2 Totaux du hub — le budget de référence

**MESURÉ**, sous opengl3, sur l'arbre vivant :

| grandeur | valeur |
|---|---|
| nœuds de dessin `MeshInstance3D` | **138** |
| nœuds de dessin `MultiMeshInstance3D` | **16** |
| **nœuds de dessin TOTAL** | **154** |
| triangles — GLB importés | **30 493** |
| triangles — primitives Godot | **30 204** |
| triangles — `ArrayMesh` construits en code | **464** |
| **TRIANGLES HUB TOTAL (scène entière)** | **61 161** |
| points de décor placés (instances comprises) | **456** |
| emprise XZ mesurée | x `[-35.28 .. 34.13]`, z `[-33.90 .. 44.39]` |
| matériaux **unlit** | **154 / 154** |
| nœuds portant une texture albédo | **6** (les 6 `.glb`) |
| nœuds portant normal / metallic / roughness / emission | **0** |

**Le budget de référence contre lequel tout nouvel asset sera arbitré est
donc 61 161 triangles.** Le seul plafond de frame publié dans ce dépôt est
les **50 000 triangles** de `docs/MESHY_SPEC.md` §7, justifié sur le
**renderer** (`gl_compatibility`, confirmé dans `project.godot:54` — donc
WebGL2 sous Safari mobile) et sur le device, pas sur le contenu de Chased.
**La scène du hub pèse 122 % de ce plafond.** Le culling en dessine moins
par frame ; le chiffre reste le majorant à ne pas aggraver sans compenser.

Confirmation de non-régression au passage : **`0` texture PBR morte** dans
tout le hub — les canaux normal/metallic/roughness/emission strippés par les
lots CH20/CH21 le sont restés, et l'importeur glTF n'en a relié aucune sur
les matériaux unlit, exactement comme `CLAUDE.md` le décrit.

### 1.3 Top 20 des consommateurs de triangles

**MESURÉ.** `(unitaire × instances)`.

| triangles | détail | nœud | source |
|---|---|---|---|
| 7 262 | 7 262 × 1 | `Props/Cabin/keepy_cabin_decor` | GLB `keepy_cabin_decor.glb` |
| 5 846 | 5 846 × 1 | ours (`keepy_bear_walker`) | GLB `keepy_bear_walker.glb` |
| 5 623 | 5 623 × 1 | blaireau (`keepy_badger_walker`) | GLB `keepy_badger_walker.glb` |
| 5 440 | 80 × 68 | `Props/Bush` | `SphereMesh` |
| 5 280 | 120 × 44 | `Props/TreeCrown` | `SphereMesh` |
| 4 423 | 4 423 × 1 | `Props/Owl` | GLB `keepy_owl_decor.glb` |
| 4 210 | 4 210 × 1 | `Props/Cabin/Magpie` | GLB `keepy_magpie_prop.glb` |
| 3 840 | 80 × 48 | `Props/Rock` | `SphereMesh` |
| 3 129 | 3 129 × 1 | `Keepy/Yaw/Body` | GLB `keepy_squirrel_hero.glb` |
| 2 112 | 48 × 44 | `Props/TreeTrunk` | `CylinderMesh` |
| 1 224 | 36 × 34 | `Props/FlowerStem` | `CylinderMesh` |
| 832 / 768 / 576 | 64 × 13 / 12 / 9 | `Props/FlowerPetal0..2` | `SphereMesh` |
| 576 × 4 | 576 × 1 chacun | 2 grands lacs (disque d'eau + disque de berge) | `CylinderMesh` |
| 540 | 36 × 15 | `Props/DivingBoardRung` | `CylinderMesh` |
| 320 × 4 | 320 × 1 chacun | anneaux de portail + anneau du lit | `TorusMesh` |
| 240 × 2 | 240 × 1 | petit lac (eau + berge) | `CylinderMesh` |

**Fait mesuré non évident** : les **disques d'eau et de berge plats**
totalisent **3 072 triangles**, soit **5,0 % du hub**, pour six cercles
horizontaux. `GREATLAKE_SEGMENTS = 96` sur un disque de 34,6 u de diamètre.

### 1.4 Dimensions unitaires par famille — la table d'échelle

**MESURÉ**, hauteur monde (Y), unitaire et non union de batch. Le ratio est
pris contre la hauteur mesurée de Keepy (**1,350 u** d'AABB monde).

| famille | X | **Y** | Z | base Y | n | ratio / Keepy | source |
|---|---|---|---|---|---|---|---|
| Cabane | 13,250 | **11,131** | 10,822 | 0,000 | 1 | **8,24×** | GLB |
| Landmark (3 variantes) | 2,441–3,707 | **7,093–9,464** | 2,777–3,706 | 0,000 à −0,033 | 15 | **5,25–7,01×** | primitives |
| Arbre (tronc + houppier) | 0,927–3,592 | **2,28–3,93** | idem | 0,000 | 44 | 1,69–2,91× | primitives |
| Blaireau | 0,910 | **2,160** | 0,773 | +0,051 | 1 | **1,60×** | GLB riggé |
| Hibou décor | 1,386 | **2,037** | 1,531 | −0,000 | 1 | **1,51×** | GLB |
| Mât de tyrolienne | 0,180 | 2,000 | 0,180 | 0,000 | 4 | 1,48× | primitive |
| Plongeoir | 2,130–3,864 | 1,900 | 2,874–4,050 | 0,000 | 3 | 1,41× | primitives |
| Ours | 1,083 | **1,890** | 0,441 | +0,039 | 1 | **1,40×** | GLB riggé |
| Pie | 1,713 | **1,350** | 1,830 | +1,645 | 1 | **1,00×** | GLB |
| **Keepy** | 1,320 | **1,350** | 2,037 | −0,000 | 1 | **1,00×** | GLB |
| Rocher | 1,995 | 1,094 | 1,995 | −0,164 à −0,075 | 48 | 0,81× | primitive |
| Tourniquet | 3,515 | 0,980 | 3,515 | 0,000 | 1 | 0,73× | primitives |
| Buisson (lobe) | 1,780 | 0,935 | 1,780 | −0,200 à −0,031 | 68 | 0,69× | primitive |
| Fleur (tige + corolle) | 0,125–0,578 | ~0,70 | idem | 0,000 | 34 | 0,52× | primitives |
| Balançoire | 3,600 | 0,690 | 0,620 | 0,000 | 1 | 0,51× | primitives |
| Souche | 0,860–1,349 | 0,441–0,657 | idem | 0,000 | 14 | 0,33–0,49× | primitives |
| Portail (anneau) | 2,700–3,565 | **0,300** | idem | −0,060 | 3 | **0,22×** | `TorusMesh` |
| Ponton | 2,816 | 0,050 | 2,802 | +0,045 | 5 | 0,04× | `BoxMesh` |
| Îlot | 6,000–6,800 | 0,030 | idem | +0,030 | 3 | 0,02× | primitive |
| Surfaces d'eau | 6,4–34,6 | 0,012–0,075 | idem | +0,005 à +0,020 | 6 | — | primitives |

⚠️ **Les deux modèles riggés ont été mesurés deux fois, et la première
mesure était fausse.** À travers l'armature Mixamo (`scale 0,01`),
`mesh.get_aabb()` rend **0,012 × 0,019 × 0,011** pour l'ours — le facteur 100
que `CLAUDE.md` documente. Les chiffres publiés ci-dessus viennent des
**os en pose de repos ramenés une seule fois** par
`skel.global_transform`, pas de l'AABB de maillage. **Corollaire honnête :
une boîte os-à-os s'arrête aux articulations, elle sous-estime la carrure et
n'atteint pas la plante du pied — les `base Y` de +0,039 et +0,051 de l'ours
et du blaireau ne sont donc PAS une preuve de flottement.**

### 1.5 Ancrage au sol — la prémisse « props flottants » ne survit pas

**MESURÉ par instance**, pas par batch. Le sol est le plan `y = 0`.

| batch | inst. | base Y min | base Y max | base Y moy | sous 0 | au-dessus de 0 |
|---|---|---|---|---|---|---|
| `TreeTrunk` | 44 | 0,000 | 0,000 | 0,000 | 0 | 0 |
| `FlowerStem` | 34 | 0,000 | 0,000 | 0,000 | 0 | 0 |
| `ZiplineLeg` / `ZiplineMast` | 4 / 4 | 0,000 | 0,000 | 0,000 | 0 | 0 |
| `Rock` | 48 | −0,164 | −0,075 | −0,119 | **48** | 0 |
| `Bush` | 68 | −0,200 | −0,031 | −0,100 | **52** | 0 |
| `ZiplineStringer` | 4 | −0,038 | −0,038 | −0,038 | 4 | 0 |
| `Pontoon` | 5 | +0,045 | +0,045 | +0,045 | 0 | 5 |
| `TreeCrown` | 44 | +0,739 | +1,587 | +1,172 | 0 | 44 |
| `ZiplineStep` | 8 | +0,080 | +0,620 | +0,350 | 0 | 8 |
| `DivingBoardRung` | 15 | +0,265 | +1,615 | +0,940 | 0 | 15 |

**Verdict : aucun prop flottant, aucun prop mal ancré.** Les seuls écarts au
plan sol sont **structurels et voulus** :

* `TreeCrown`, `ZiplineStep`, `DivingBoardRung`, `Bars`, `Grips` sont des
  **parties hautes** d'un objet dont la base est à 0 — un houppier ne touche
  pas le sol.
* `Rock` et `Bush` sont **délibérément enterrés** : le code place une sphère
  de rayon 0,6 à `y = 0,28` (donc base −0,12) et un lobe de buisson de rayon
  0,5 à `y = 0,2` (base −0,15). C'est ce qui fait qu'ils lisent comme
  *encastrés* et non posés. Ce n'est pas un défaut.
* Les 51 props de premier niveau (landmarks, souches, îlots, plans d'eau,
  plongeoirs, tourniquet, balançoire) mesurent une base entre **0,000 et
  −0,033** — l'écart maximal au sol sur tout le hub est de **33 mm**.

**Il n'y a donc rien à re-ancrer.** C'est un résultat, pas une absence de
résultat : la question posée par le brief a une réponse mesurée et négative.

## ÉTAPE 2 — CAPTURES

Treize captures, toutes produites en **un seul run** sous `xvfb-run
--rendering-driver opengl3`, viewport forcé à **1280 × 720**
(`SubViewportContainer.stretch = false` posé explicitement — laissé à `true`
il **ignore** un `vp.size` explicite, avec un simple `WARNING`).

Cadrage **dérivé de la mesure**, pas choisi à l'œil : centre `(−0,41 ; 4,11)`,
rayon `40,41`, hauteur max `11,13`, `fov 55°`, distance
`rayon / tan(fov/2) × 1,05`.

| tag | position œil (x, y, z) | moyenne RGB de la frame |
|---|---|---|
| `azimut_000` | (−0,41 ; 44,83 ; 69,31) | (0,135 ; 0,251 ; 0,126) |
| `azimut_045` | (45,70 ; 44,83 ; 50,22) | (0,128 ; 0,254 ; 0,132) |
| `azimut_090` | (64,80 ; 44,83 ; 4,11) | (0,127 ; 0,269 ; 0,154) |
| `azimut_135` | (45,70 ; 44,83 ; −42,00) | (0,126 ; 0,269 ; 0,152) |
| `azimut_180` | (−0,41 ; 44,83 ; −61,10) | (0,128 ; 0,283 ; 0,176) |
| `azimut_225` | (−46,52 ; 44,83 ; −42,00) | (0,129 ; 0,278 ; 0,168) |
| `azimut_270` | (−65,61 ; 44,83 ; 4,11) | (0,132 ; 0,271 ; 0,155) |
| `azimut_315` | (−46,52 ; 44,83 ; 50,22) | (0,131 ; 0,258 ; 0,134) |
| `rasante_sud` | (−0,41 ; **1,60** ; 54,62) | (0,175 ; 0,273 ; 0,134) |
| `rasante_est` | (50,10 ; **1,60** ; 4,11) | (0,151 ; 0,261 ; 0,116) |
| `dessus` | (−0,41 ; **84,86** ; 4,12) | (0,121 ; 0,268 ; 0,148) |
| `sol_nu` | (120 ; 30 ; 120), plein sud vertical | échantillon de sol pur |

Les treize moyennes sont non nulles et **varient entre elles** — la garde
anti-DUMMY est donc réellement passée, et pas passée gratuitement.

⚠️ **Les captures ne sont pas commitées.** Le brief impose `FILES : un seul
nouveau fichier`. Elles sont livrées directement dans la session. Les
conserver au dépôt supposerait `docs/renders/hub_visuel/` comme le CH21 —
c'est une décision de Mathieu, pas de ce lot.

## ÉTAPE 3 — ANALYSE, par impact décroissant

### a) Cohérence d'échelle — deux ruptures, et un point aveugle

**MESURÉ.** L'amplitude totale va de **0,030 u** (îlot) à **11,131 u**
(cabane), soit un facteur **371** entre le plus plat et le plus haut.

**Rupture 1 — le trou entre 3,93 et 7,09.** Il existe deux populations
d'arbres sans rien entre les deux : les 44 arbres `tree` culminent à
**3,93 u**, et les 15 `landmark` (dont la variante « épicéa étagé »)
démarrent à **7,09 u**. **Aucun élément de décor du hub n'occupe la bande
3,93 → 7,09 u.** Sur les rasantes, ça se lit exactement comme deux forêts
superposées sans transition — *(estimé à l'œil sur `rasante_sud`, la mesure
ne dit que le trou, pas sa lisibilité)*.

**Rupture 2 — les inversions zoologiques.** Trois, mesurées :

| constat mesuré | rapport |
|---|---|
| Blaireau **2,160** > Ours **1,890** | le blaireau est **1,14×** l'ours |
| Hibou décor **2,037** > Ours **1,890** | le hibou est **1,08×** l'ours |
| Pie **1,350** = Keepy **1,350** | une pie exactement à la taille du héros |

⚠️ **L'inversion blaireau/ours est une décision consignée, pas un bug.**
`CH21` la porte explicitement : *« badger rescaled bigger than Keepy —
device feedback overrode the zipline pairing rule »*, et le commit `27461ac`
la fixe à « an exact 1.6×-Keepy height » — ce que la mesure confirme au
millième (1,6 × 1,350 = 2,160). **Elle est signalée ici parce que c'est le
plus grand écart zoologique du hub, pas pour être défaite.**

**Point aveugle assumé** : la mesure ne dit rien de la lisibilité relative
d'un hibou de 2,037 u perché contre un ours de 1,890 u au sol — les deux ne
sont jamais dans le même cadre. C'est un **(estimé)** en attente d'un rendu
comparatif, exactement le piège « la métrique peut être la mauvaise » que
`CLAUDE.md` documente deux fois.

**Le plus fort outlier fonctionnel** : les **trois portails**, c'est-à-dire
les points d'entrée des trois jeux, sont les objets les plus **plats** du
hub après l'eau et les pontons — un anneau de **0,300 u** de haut sur un
socle de 0,060, soit **0,22 × Keepy**, dans un monde où les landmarks font
7 à 9,5 u. **La fonction et la présence visuelle sont inversées.**

### b) Ancrage au sol — rien à corriger

Traité en 1.5 : **écart maximal au sol de 33 mm sur 51 props de premier
niveau**, et les seuls enfoncements (rochers −0,119 moyen, buissons −0,100
moyen) sont l'encastrement voulu par le code. **La prémisse du brief tombe.**

### c) Densité et composition — un centre creux et une bande nord désertée

**MESURÉ.** Grille d'occupation 10×10 sur l'emprise, cellule 6,94 × 7,83 u,
456 points :

    x -35.3 ->                                    -> +34.1
      4    0    2    2    8   18    0    0    1    0   | z -33.9 .. -26.1   (35)
      3    7    0    2    0    0    7    6    0    1   | z -26.1 .. -18.2   (26)
      2    5    2    1    2    0    0    6    0    1   | z -18.2 .. -10.4   (19)
      1    6   13   11   10    6    2    0    3    8   | z -10.4 ..  -2.6   (60)
      2    7   12   16   19   22   12    6   12    8   | z  -2.6 ..   5.2  (116)
      7    3    5   11    5   14    9    6    6   23   | z   5.2 ..  13.1   (89)
      0    1    5    5   11    3    8    7    6    1   | z  13.1 ..  20.9   (47)
      0    0    3    2    5    3    9    1    4    0   | z  20.9 ..  28.7   (27)
      0    0    3    0    5    0    2    0   12    0   | z  28.7 ..  36.6   (22)
      0    0    0    0   10    4    1    0    0    0   | z  36.6 ..  44.4   (15)

**29 cellules sur 100 sont vides.**

Trois faits mesurés :

1. **Une bande centrale surchargée.** La ligne `z ∈ [−2,6 ; 5,2]` porte
   **116 des 456 points (25,4 %)** sur **10 % de la surface**. Avec la ligne
   suivante, `z ∈ [−2,6 ; 13,1]` porte **205 points, soit 45 %, sur 20 % de
   la surface**.
2. **Une moitié nord désertée.** `z > 20,9` porte **64 points (14,0 %)** sur
   **30 % de la surface**, et `z > 36,6` n'en porte que **15**. C'est
   pourtant là que vivent la balançoire (z = 38,5) et la station nord de la
   tyrolienne.
3. **Pas de point focal, et c'est mesurable.** Les 15 landmarks — les seuls
   objets de plus de 7 u — sont **tous à plus de 12,6 u du centre du
   plateau** (distances mesurées : 12,6 ; 12,7 ; 12,8 ; 20,9 ; 22,1 ; 24,5 ;
   30,4 ; 30,9 ; 32,0 ; 33,1 ; 34,0 ; 34,0). **Le disque central de rayon
   12,6 u ne contient aucune masse verticale.** Ce qui s'y trouve : trois
   anneaux de portail de 0,30 u de haut. La seule grande masse du hub, la
   cabane (11,131 u), est à **(−17,44 ; 28,23)**, soit **33,2 u du centre**,
   dans le coin nord-ouest.

*(Estimé, sur `dessus` et `azimut_000`)* : l'œil part effectivement vers la
cabane, qui est le seul objet à la fois grand, coloré et texturé — mais elle
est en périphérie, donc le regard **sort** du hub au lieu de s'y ancrer.

### d) Valeurs et palette — la bande morte n'est pas une exception, c'est la règle

**MESURÉ.** Sol du hub, albédo `(0,20 ; 0,40 ; 0,15)` → **L = 0,1035**.

Franchir **3,0:1** contre ce sol exige donc, **en espace albédo** :

* vers le haut : **L ≥ 0,4104**
* vers le bas : **L ≤ 0,0012**

⚠️ **Conclusion mesurée et lourde de conséquences : la bande basse est
inaccessible dans le hub.** `L ≤ 0,0012` est un noir quasi absolu ;
**aucune couleur utilisable ne l'atteint**. La couleur la plus sombre du hub
aujourd'hui (tronc d'épicéa, `L = 0,0117`) plafonne à **2,49:1**. Le hub
n'est donc **pas** coupé en deux bandes comme Chased — **il n'en a
qu'une seule, la haute.** Tout asset neuf qui doit se détacher du sol doit
monter, jamais descendre. *(Le seuil `L ≥ 0,549` de `CLAUDE.md`, transporté
de Chased, est plus exigeant que le `0,4104` propre au sol du hub : il reste
valable comme cible sûre.)*

Les 25 albédos distincts mesurés, triés par luminance :

| albédo | L | ratio / sol | n | bande | exemple |
|---|---|---|---|---|---|
| 1,000 1,000 1,000 | 1,0000 | 6,84:1 | 6 | HAUTE | les 6 GLB (couleur portée par la texture) |
| 0,930 0,860 0,420 | 0,6991 | 4,88:1 | 1 | HAUTE | `FlowerPetal0` |
| 0,251 0,878 0,816 | 0,5895 | 4,17:1 | 5 | HAUTE | eau (tous les plans) |
| 0,880 0,760 0,550 | 0,5631 | 3,99:1 | 6 | HAUTE | barres du tourniquet, poignées |
| 0,950 0,740 0,300 | 0,5572 | 3,96:1 | 4 | HAUTE | anneaux de portail |
| 0,720 0,660 0,880 | 0,4366 | 3,17:1 | 1 | **MORTE** | `FlowerPetal2` |
| 0,740 0,600 0,400 | 0,3452 | 2,58:1 | 1 | **MORTE** | intérieur de barque |
| 0,860 0,520 0,620 | 0,3424 | 2,56:1 | 1 | **MORTE** | `FlowerPetal1` |
| 0,560 0,560 0,500 | 0,2695 | 2,08:1 | 10 | **MORTE** | chapeau de cairn |
| 0,380 0,580 0,300 | 0,2421 | 1,90:1 | 15 | **MORTE** | houppier d'épicéa |
| 0,440 0,450 0,400 | 0,1662 | 1,41:1 | 15 | **MORTE** | pierre de cairn |
| 0,460 0,430 0,310 | 0,1544 | 1,33:1 | 3 | **MORTE** | îlots |
| 0,360 0,440 0,320 | 0,1450 | 1,27:1 | 10 | **MORTE** | dalle levée |
| **0,200 0,400 0,150** | **0,1035** | **1,00:1** | 1 | — | **le sol** |
| 0,210 0,390 0,160 | 0,0994 | **1,03:1** | 1 | **MORTE** | **`Bush` (68 lobes)** |
| 0,190 0,350 0,140 | 0,0795 | 1,19:1 | 1 | **MORTE** | tige de fleur |
| 0,170 0,340 0,130 | 0,0740 | **1,24:1** | 1 | **MORTE** | **`TreeCrown` (44)** |
| 0,380 0,270 0,170 | 0,0695 | 1,28:1 | 9 | **MORTE** | pontons, marches, deck |
| 0,260 0,300 0,230 | 0,0672 | 1,31:1 | 5 | **MORTE** | soubassement de dalle |
| 0,260 0,270 0,240 | 0,0575 | **1,43:1** | 3 | **MORTE** | **`Rock` (48)** |
| 0,130 0,280 0,120 | 0,0498 | 1,54:1 | 4 | **MORTE** | socles de portail |
| 0,330 0,210 0,120 | 0,0459 | 1,60:1 | 27 | **MORTE** | coque de barque, cadres |
| 0,220 0,210 0,150 | 0,0358 | 1,79:1 | 4 | **MORTE** | berges des grands lacs |
| 0,200 0,130 0,080 | 0,0185 | 2,24:1 | 15 | **MORTE** | tronc d'arbre |
| 0,150 0,100 0,060 | 0,0117 | 2,49:1 | 5 | BASSE* | tronc d'épicéa |

\* « BASSE » au sens du seuil `0,0165` de Chased ; **contre le sol du hub
elle ne vaut que 2,49:1**, donc sous le plancher de 3,0.

**Le chiffre qui résume l'audit : 20 des 25 albédos du hub — et
particulièrement les trois familles les plus nombreuses — tombent dans la
bande morte.** Les 160 props les plus nombreux se lisent entre **1,03:1 et
1,43:1** contre le sol qu'ils occupent :

* **68 lobes de buisson à 1,03:1** — la valeur est à 3 % de celle du sol.
* **44 houppiers à 1,24:1.**
* **48 rochers à 1,43:1.**

Ce que le WCAG ne dit pas, et `CLAUDE.md` insiste : **aucune sonde de ce
dépôt ne mesure la séparation par la teinte**, qui est ce qui fait
réellement le travail à l'intérieur d'une bande. Deux objets à 1,04:1
peuvent être parfaitement distincts. **Donc : ces chiffres établissent que
la palette du hub ne s'appuie pas du tout sur la luminance, pas qu'elle est
illisible.** *(Estimé sur `rasante_sud` : les buissons lisent effectivement
comme des taches sombres indifférenciées, les rochers un peu mieux.)*

**Luminance RENDUE, mesurée séparément.** Sur un échantillon de sol nu
(1 200 px, à 30 u, loin de tout prop) : `(0,1608 ; 0,3294 ; 0,1137)`,
**L = 0,0690**. `CLAUDE.md` publie **0,0799** pour le sol rendu du hub —
les deux sont du même ordre, l'écart vient de la distance
d'échantillonnage. Le plancher 3,0:1 en luminance **rendue** vaut donc
**L ≥ 0,3070**.

⚠️ **Observation à consigner, non résolue ici.** Le rendu mesuré
`(0,161 ; 0,329 ; 0,114)` vaut ≈ **0,80×** l'albédo `(0,20 ; 0,40 ; 0,15)`,
sur les trois canaux — ce qui est la signature d'un **fog qui atténue** vers
la couleur de fog `(0,062 ; 0,115 ; 0,044)`. Le run tourne pourtant sous
`gl_compatibility`, le renderer du device. **Cela ne contredit pas la
contrainte connue et ne l'infirme pas** : desktop GL et WebGL2 sont deux
implémentations, et ce lot n'a **rien mesuré sur device**. C'est signalé
comme un écart à vérifier, pas comme un résultat.

### e) Silhouettes — quatre archétypes pour 75 % du décor

**MESURÉ** sur le layout et sur `_batch_spec()` :

| famille | entrées | construction | formes primitives |
|---|---|---|---|
| `rock` | 48 | 1 `SphereMesh` écrasée | **1** |
| `tree` | 44 | `CylinderMesh` + `SphereMesh` | **2** |
| `bush` | 34 | 2 instances d'**une** `SphereMesh` | **1** |
| `flower` | 34 | `CylinderMesh` + `SphereMesh` | **2** |
| **total** | **160 / 214 = 74,8 %** | | **2 formes distinctes** |

**160 des 214 entrées du layout sont des assemblages de sphères et de
cylindres**, tirés de **deux** maillages primitifs.

⚠️ **Et la variation annoncée par le layout est en partie un no-op mesurable.**
Chaque entrée porte un `rotation_y` aléatoire (mesuré : 2,9° à 350,8°). Mais
`Rock` et `Bush` sont des **sphères de révolution** : **faire tourner une
sphère autour de Y ne change strictement rien à l'image.** Sur les 116
instances de ces deux familles, la seule variation réellement visible est
l'échelle (0,64 → 1,38 mesurée sur le `.tres`). **48 rochers identiques à
huit tailles près, 68 lobes de buisson identiques à huit tailles près.**

Les 15 landmarks sont, eux, correctement variés — trois variantes
délibérément non confusibles (`_make_landmark_spire` en aiguille étagée,
`_make_landmark_cairn` en blocs empilés gris, `_make_landmark_slabs` en deux
dalles verticales inégales), et le code le documente comme tel.

*(Estimé sur les 8 azimuts)* : la silhouette d'ensemble est dominée par les
verticales grises des cairns et des dalles, qui sont les seules masses
mi-claires du champ. Les arbres, plus sombres que le sol contre le fond
noir-vert, ne participent quasiment pas au profil.

**Redondance de valeur, mesurée** : le hub n'utilise que **trois paliers**
— un socle sombre (L 0,018–0,104 : sol, arbres, buissons, rochers, troncs),
un palier gris moyen (L 0,145–0,270 : landmarks), et un palier saturé
(L 0,557–0,589 : eau et anneaux). Plus les 6 GLB texturés, hors palette.

### f) Contraintes connues — rappelées, non contournées

Rappelées ici comme contraintes du constat, **sans qu'aucune solution
proposée plus bas ne cherche à les contourner** :

1. **Fog de profondeur non fonctionnel en Compatibility / WebGL2** (Godot
   #97875, #92019). Le hub configure pourtant `fog_enabled = true`,
   `fog_density = 0,016`. **Aucune proposition de ce document ne repose sur
   le fog pour séparer un plan d'un autre.** *(Voir l'observation en d) : le
   fog atténue bien sous desktop GL ici ; non vérifié sur device.)*
2. **Aucun système de particules dans le dépôt** — vérifié, 0 occurrence
   réelle. **Aucune proposition n'en introduit** : ce serait mettre une
   technologie de rendu non éprouvée et un effet non éprouvé sur le même
   commit, ce que `HubWorld.gd:2850` refuse explicitement.
3. **Aucune PoC WebGL2 mobile.** Rien de ce document n'est validé device.
4. **Matériaux unlit — l'émission est inerte, seul l'albédo porte le
   signal.** Confirmé par la mesure : 154/154 nœuds unlit. **Aucune fiche de
   la liste B ne demande de canal émissif** ; toute cible de palette y est
   exprimée en albédo.
5. **`export_filter="all_resources"`** — tout asset déposé dans `res://` part
   dans le `.pck`, référencé ou non. Un `.glb` de la liste B coûte son
   payload dès le dépôt.

## ÉTAPE 4 — LISTE A : corrections SANS nouvel asset

Triées par impact décroissant. Les coûts de développement sont **(estimés)**,
les problèmes constatés sont mesurés.

### A1 — Les trois familles majeures ne portent aucune séparation de luminance

* **Problème (mesuré)** : `Bush` 1,03:1, `TreeCrown` 1,24:1, `Rock` 1,43:1
  contre le sol. 160 props, soit 75 % du décor, sous 1,5:1.
* **Correction proposée** : porter **une seule** des trois familles dans la
  bande haute (`L ≥ 0,4104`, ou `0,549` pour la marge de `CLAUDE.md`),
  **pas les trois**. Candidat le plus défendable : **`Rock`**, dont
  `(0,26 ; 0,27 ; 0,24)` est déjà neutre — un gris clair minéral à
  `L ≈ 0,42` sépare 48 objets du sol sans reverdir le marécage.
* **Fichiers** : `scripts/hub/HubBuilder.gd`, 1 constante (`ROCK_COLOR`).
* **Coût (estimé)** : 1 ligne + un balayage d'albédo mesuré + une sonde de
  contraste. **Un demi-lot.**
* **Risque de régression** : **élevé au sens artistique, nul au sens
  technique.** Ça change l'identité du hub ; `CLAUDE.md` documente deux fois
  qu'un réglage de couleur validé en sandbox a été démenti sur device.
  **Validation device obligatoire, à plusieurs azimuts.**
* **Impact visuel attendu (estimé)** : le plus élevé de toute la liste A.
* ⚠️ **Ne PAS monter les trois familles.** Le sol est à `L = 0,1035` ; porter
  buissons, houppiers et rochers au-dessus de `0,41` inverserait la
  hiérarchie et rendrait le sol le point le plus sombre du hub.

### A2 — 3 072 triangles de disques d'eau plats, pour une finesse inutile

* **Problème (mesuré)** : `GREATLAKE_SEGMENTS = 96` sur un disque de rayon
  17,3 u donne une **sagitta de 0,0093 u**. Le bassin déjà accepté au dépôt
  tourne à 24 segments pour un rayon 3,2, soit **0,027 u** — trois fois plus
  grossier et jugé bon. Coût mesuré : `6 × n` triangles par disque, donc
  **576 par disque, 4 disques, 2 304 triangles**.
* **Correction proposée** : `GREATLAKE_SEGMENTS` **96 → 56**, qui donne une
  sagitta de **0,0272 u**, c'est-à-dire **exactement la finesse du bassin
  déjà validé**. Gain : `4 × (576 − 336)` = **−960 triangles (−1,6 % du
  hub)**.
* **Fichiers** : `scripts/hub/HubBuilder.gd`, 1 constante.
* **Coût (estimé)** : 1 ligne. **Le meilleur ratio de la liste.**
* **Risque** : faible et **mesurable** — un rendu comparatif aux 8 azimuts
  tranche au pixel.
* **Impact visuel attendu** : **nul par construction**, c'est le but.

### A3 — La rotation aléatoire de 116 props est un no-op géométrique

* **Problème (mesuré)** : `Rock` et `Bush` sont des sphères de révolution.
  Le `rotation_y` du layout (2,9° → 350,8°) **ne change aucun pixel** sur
  ces 116 instances. La seule variation réelle est l'échelle uniforme.
* **Correction proposée** : remplacer, dans `_batch_prop()`, l'échelle
  uniforme par une **échelle non uniforme par instance** (par exemple
  `Vector3(s·a, s·b, s·c)` avec `a,b,c ∈ [0,75 ; 1,3]` tirés du même seed).
  Une sphère aplatie ou étirée **puis** tournée en Y devient réellement
  variée. Zéro triangle ajouté.
* **Fichiers** : `scripts/hub/HubBuilder.gd`, `_batch_prop()`, ~10 lignes.
* **Coût (estimé)** : ~10 lignes + une sonde qui **prouve d'abord que le
  chiffre bouge** (blind check obligatoire : une assertion « les silhouettes
  diffèrent » passe gratuitement contre un mécanisme non câblé).
* **Risque** : faible. Les rochers sont enterrés de 0,119 u en moyenne ; une
  échelle Y réduite les enfoncerait davantage — **le re-calcul de l'offset
  d'enfouissement doit suivre l'échelle**, sinon on recrée le défaut « une
  moitié de somme recopiée » que `CLAUDE.md` documente.
* **Impact visuel attendu (estimé)** : élevé sur 116 objets, pour 10 lignes.

### A4 — Le disque central de rayon 12,6 u ne contient aucune masse verticale

* **Problème (mesuré)** : les 15 landmarks sont tous au-delà de 12,6 u du
  centre ; la cabane est à 33,2 u ; le centre ne porte que trois anneaux de
  0,300 u de haut.
* **Correction proposée sans nouvel asset** : déplacer **2 landmarks
  existants** vers `r ≈ 8–11 u`, en arrière de l'arc des portails
  (les portails sont à `(−5,4 ; −4,6)`, `(0 ; −7,2)`, `(5,4 ; −4,6)`).
* **Fichiers** : `resources/hub/hub_layout.tres`, 2 entrées `position`.
* **Coût (estimé)** : 2 lignes.
* **Risque** : **réel et non trivial.** Une masse de 8 à 9,5 u près des
  portails peut occulter la ligne de vue caméra et casser le cadrage du tap.
  `PursuerFramingAudit` et le patron de `LakeMoveCaptureProbe` donnent la
  méthode ; **ce déplacement doit être gaté par une sonde de cadrage**, pas
  jugé à l'œil.
* **Impact visuel attendu (estimé)** : moyen — ça remplit le trou sans
  créer un vrai point focal (c'est ce que fait B1).

### A5 — La moitié nord porte 14 % du décor sur 30 % de la surface

* **Problème (mesuré)** : `z > 20,9` → 64 points sur 456 ; `z > 36,6` → 15.
  La bande centrale `z ∈ [−2,6 ; 13,1]` porte 45 % du décor sur 20 % de la
  surface.
* **Correction proposée** : redistribuer **~30 entrées existantes**
  (`rock`, `bush`, `flower`) de la bande centrale vers `z ∈ [22 ; 40]`.
  Aucun prop créé, aucun supprimé — **uniquement des `position` réécrites**.
* **Fichiers** : `resources/hub/hub_layout.tres`, ~30 entrées.
* **Coût (estimé)** : un demi-lot, l'essentiel étant la vérification.
* **Risque** : **le vrai coût est là.** Tout point déplacé doit rester
  compatible avec `HubRegion` (plateau ±35, lobe nord r = 12 en (0 ; 35),
  lobes de structure r = 3) et ne bloquer ni la balançoire (z = 38,5) ni la
  station nord de la tyrolienne. **Une sonde de containment est
  obligatoire** — un prop posé sur un point non marchable est invisible au
  test et bloquant au jeu.
* **Impact visuel attendu (estimé)** : moyen-élevé sur les vues nord.

### A6 — Les berges des grands lacs forment un anneau noir de 1,79:1

* **Problème (mesuré)** : berge `(0,22 ; 0,21 ; 0,15)`, `L = 0,0358`, contre
  une eau à `L = 0,5895`. L'anneau lit comme un trait noir dur.
  *(Estimé sur `dessus` : effet « disque de UI » plus que berge.)*
* **Correction proposée** : monter la berge vers `L ≈ 0,12–0,18` — pas
  jusqu'à la bande haute, qui la mettrait en concurrence avec l'eau.
* **Fichiers** : `HubBuilder.gd`, 1 constante.
* **Coût (estimé)** : 1 ligne + balayage.
* **Risque** : faible. **Mais l'eau est à alpha 0,95 et `CLAUDE.md` interdit
  formellement de prédire un rendu d'alpha par forme fermée** — si la berge
  bouge, le contraste eau/berge se **balaye**, il ne se calcule pas.
* **Impact visuel attendu (estimé)** : moyen.

### A7 — Six nœuds texturés dans un hub qui en compte 154 unlit et plats

* **Problème (mesuré)** : cabane, ours, blaireau, hibou, pie et Keepy portent
  `albedo_color = (1 ; 1 ; 1)` **plus une texture albédo** ; les 148 autres
  nœuds portent une couleur plate unique. `docs/MESHY_SPEC.md` §8.3 consigne
  pourtant : *« Imported decor props are flat, untextured and unlit — by
  decision »*. **Les 6 assets installés s'écartent de cette décision
  écrite.** *(Estimé, et c'est le constat visuel le plus fort de l'audit :
  sur `rasante_sud` et `azimut_180`, la cabane et l'ours lisent comme
  collés depuis un autre jeu.)*
* **Correction possible sans nouvel asset** : `ModelSlot.apply_material()`
  existe déjà et poserait un albédo plat sur un slot.
* **Fichiers** : `HubBuilder.gd` (`_make_cabin`, `_make_owl`), ou le
  `.glb` à la source.
* **Coût (estimé)** : faible techniquement.
* ⚠️ **Risque : le plus élevé de toute la liste A, et je ne le recommande
  pas.** Aplatir la cabane détruirait un asset déjà validé sur device et
  perdrait 7 262 triangles de détail payés. **La divergence est signalée
  parce qu'elle est mesurée et documentée à l'envers dans MESHY_SPEC, pas
  parce qu'elle doit être résolue dans ce sens-là.** La résolution
  symétrique — enrichir le décor procédural pour rejoindre les GLB — est
  exactement ce que propose la liste B.

### Récapitulatif liste A

| # | impact (estimé) | coût (estimé) | triangles | risque |
|---|---|---|---|---|
| A2 | nul (voulu) | **1 ligne** | **−960** | faible, mesurable |
| A3 | élevé | ~10 lignes | 0 | faible |
| A1 | **le plus élevé** | demi-lot | 0 | élevé (device) |
| A5 | moyen-élevé | demi-lot | 0 | moyen (containment) |
| A4 | moyen | 2 lignes | 0 | moyen (cadrage) |
| A6 | moyen | 1 ligne | 0 | faible (balayage) |
| A7 | — | faible | — | **le plus élevé — signalé, non recommandé** |

## ÉTAPE 4 — LISTE B : assets 3D à produire

**Contrainte de budget qui gouverne toute la liste** : le hub mesure
**61 161 triangles** contre le seul plafond publié du dépôt, **50 000**
(`MESHY_SPEC` §7). **Il est déjà à 122 %.** Toute fiche ci-dessous chiffre
donc son coût **et** la compensation qui le finance.

Toutes les dimensions sont **dérivées de l'inventaire de l'étape 1**, jamais
estimées à l'œil. Toutes les cibles de palette sont en **albédo**, jamais en
émission (matériaux unlit). Tous les prompts Meshy sont **descriptifs, sans
langage instructionnel, et décrivent un objet autonome unique**.

Triées par **ratio impact / coût décroissant**.

---

### B1 — `rocher_marecage` (2 variantes)

* **Rôle** : **remplissage + silhouette**. Casser 48 sphères identiques.
* **Emplacement** : aucun nouveau. Remplace le batch `Rock` **en place**,
  sur les 48 positions existantes du layout.
* **Justification (analyse c + e)** : `rock` est la famille la plus nombreuse
  (48 entrées), sa rotation Y est un no-op mesuré, et sa silhouette est
  **une** sphère écrasée.
* **Dimensions cibles** : **2,00 × 1,10 × 2,00 u** — dérivées du rocher
  mesuré (`1,995 × 1,094 × 1,995`), pour que les 48 positions et
  l'enfouissement de −0,119 u restent valides sans retoucher le layout.
* **Budget triangles** : **≤ 80 par variante.** Justification : le batch
  actuel coûte `80 × 48 = 3 840`. À 80, **deux variantes réparties sur 48
  instances coûtent exactement 3 840 — l'opération est neutre au triangle
  près.** À 100, elle coûte +960, ce que A2 finance exactement.
* **Palette** : **bande haute**, `L ≥ 0,4104` (cible sûre `0,549`). Teintes
  admissibles : gris minéral froid désaturé, gris-vert lichen très clair.
  **Pas de brun** — il rejoindrait la bande morte des troncs.
* **Prompt Meshy** :

      A single weathered swamp boulder, low and broad, flattened on top,
      with a few irregular fractured facets and one shallow moss-filled
      crevice along its side. Pale cool grey stone, matte and desaturated,
      no vegetation on top. Isolated object, resting on nothing, seen as
      one solid mass.

---

### B2 — `souche_racines`

* **Rôle** : **remplissage** des bandes vides du nord.
* **Emplacement** : `z ∈ [22 ; 40]`, en priorité les cellules mesurées à 0 —
  notamment `x ∈ [−35 ; −14]` pour `z > 28,7` (6 cellules vides mesurées) et
  la bande `z ∈ [36,6 ; 44,4]` (15 points sur 10 cellules). Coordonnées XZ
  indicatives : `(−22 ; 30)`, `(−14 ; 38)`, `(10 ; 33)`, `(24 ; 30)`.
* **Justification (analyse c)** : `z > 20,9` porte **14,0 % du décor sur
  30 % de la surface**, et c'est là que vivent la balançoire et la station
  nord de la tyrolienne.
* **Dimensions cibles** : **1,20 × 0,80 × 1,20 u** — au-dessus de la souche
  mesurée (`0,86–1,35 × 0,44–0,66`) pour lire à la distance des vues nord,
  et sous le rocher (1,10) pour ne pas créer un troisième palier.
* **Budget triangles** : **≤ 150.** À 10 exemplaires : **1 500 triangles,
  soit 2,5 % du hub.** Financé par A2 (−960) plus une réduction de
  `TreeCrown` de 120 à 100 triangles (−880), soit −1 840 pour +1 500.
* **Palette** : **bande haute**, `L ≥ 0,4104`. Bois flotté gris-blanchi,
  ou bois clair délavé. **Pas le brun `(0,20 ; 0,13 ; 0,08)` du tronc
  existant** (`L = 0,0185`, en pleine bande morte).
* **Prompt Meshy** :

      A single hollow tree stump with thick gnarled roots splaying outward
      and gripping the ground, the trunk snapped off at knee height with a
      ragged jagged rim. Bleached driftwood grey, dry and weathered, bare
      of leaves and moss. One isolated object.

---

### B3 — `arbre_totem_central`

* **Rôle** : **point focal.** Le seul de la liste.
* **Emplacement** : **`(0 ; −13)`**, l'isthme sec entre les deux grands lacs.
* **Justification (analyse c)** : cellule mesurée à **0 point**, et
  vérification faite que le point est hors des deux plans d'eau — distance
  au grand lac 1 `(15,5 ; −19)` r 16 : **16,6 u** ; au grand lac 2
  `(−12 ; −19,5)` r 11,3 : **13,6 u**. Il est **derrière** l'arc des trois
  portails (z −4,6 à −7,2), donc il les cadre au lieu de les masquer.
  Il comble le **disque central de 12,6 u vide** établi en c).
* **Dimensions cibles** : **9,0 × 14,0 × 9,0 u.** Dérivation : **1,48 ×** le
  plus haut landmark mesuré (9,464) pour dominer sans ambiguïté, **1,26 ×**
  la cabane (11,131) pour reprendre le rôle d'ancre que la cabane occupe
  aujourd'hui depuis un coin, et **10,4 ×** Keepy. **Il comble aussi la
  rupture d'échelle 3,93 → 7,09** en occupant le haut du spectre.
* **Budget triangles** : **≤ 2 200.** Justification : **3,6 % du hub**, et
  **30 % du coût de la cabane** (7 262) pour une masse 1,26 × plus haute —
  défendable parce qu'un objet unique n'est jamais instancié. **Doit être
  financé** : A2 (−960) + `TreeCrown` 120 → 100 (−880) + `Bush` 80 → 64
  (−1 088) = **−2 928 pour +2 200**, soit un hub à **60 433**, en dessous du
  chiffre d'aujourd'hui.
* **Palette** : **tronc en bande haute** (`L ≥ 0,4104`, bois clair délavé) —
  c'est lui qui porte la silhouette contre le sol. Houppier libre de
  descendre vers `L ≈ 0,24` (celui de l'épicéa) : à cette taille, c'est la
  **masse** qui sépare, pas la luminance.
* ⚠️ **Contrainte de production** : Meshy n'est pas fiable sur l'assemblage
  multi-parties. **Un tronc + houppier en une seule pièce**, ou deux fiches
  séparées assemblées côté code.
* **Prompt Meshy** :

      A single ancient swamp tree, one thick pale twisted trunk widening
      into a heavy buttressed base, splitting high up into a broad dense
      rounded canopy. Bark bleached driftwood grey, canopy deep muted
      green. Bare of flowers and fruit. One isolated tree, nothing around
      it, one continuous piece.

---

### B4 — `roseaux_berge`

* **Rôle** : **silhouette**, transition eau → sol.
* **Emplacement** : sur les anneaux de berge des 4 plans d'eau — grands lacs
  `(15,5 ; −19)` r 16 et `(−12 ; −19,5)` r 11,3, petit lac `(−25,1 ; −5,3)`
  r 9,05, bassin `(20,7 ; 7,4)` r 3,62. En touffes, pas en ceinture continue.
* **Justification (analyse d + e)** : la berge mesure **1,79:1** contre le
  sol et lit comme un trait noir dur ; c'est la seule transition du hub entre
  la valeur la plus haute (eau, `L = 0,5895`) et le socle sombre, et elle se
  fait sur **0 objet**.
* **Dimensions cibles** : **0,90 × 1,30 × 0,90 u.** Dérivation : **plus haut
  qu'un buisson** (0,935) pour dépasser l'anneau de berge, **plus bas que
  Keepy** (1,350) pour ne jamais masquer le personnage sur la rive.
* **Budget triangles** : **≤ 120.** À 12 touffes : **1 440**, soit 2,4 %.
  Financé par A3 si l'on renonce à monter `Bush` en variantes, ou par une
  passe `Rock` 80 → 64 (−768) plus A2 (−960).
* **Palette** : **bande haute**, `L ≥ 0,4104`. Vert-jaune pâle de roseau sec,
  ou beige paille. **Surtout pas le vert `(0,21 ; 0,39 ; 0,16)` du buisson**
  (`L = 0,0994`, à 1,03:1 du sol).
* **Prompt Meshy** :

      A single clump of tall marsh reeds, a dozen slender straight blades
      of unequal height fanning out from one narrow base, a few bent over
      near the tips, with two seed heads. Dry pale straw yellow-green.
      One isolated tuft, no ground, no water.

---

### B5 — `arbre_mort_penche`

* **Rôle** : **silhouette de fond.** Casser l'horizon plat.
* **Emplacement** : périmètre, `r ∈ [28 ; 34]` du centre, dans les cellules
  vides mesurées des colonnes extrêmes — XZ indicatifs `(−32 ; −8)`,
  `(31 ; 20)`, `(−30 ; −20)`, `(28 ; −28)`.
* **Justification (analyse e)** : toutes les verticales du hub sont
  **strictement verticales** (troncs, mâts, cairns, dalles). Une diagonale
  est la seule chose absente du vocabulaire de silhouette.
* **Dimensions cibles** : **3,50 × 6,00 × 3,50 u** (penché ~25°). Dérivation :
  **occupe la bande 3,93 → 7,09 laissée vide** par la rupture d'échelle
  mesurée en a) — c'est sa raison d'être dimensionnelle.
* **Budget triangles** : **≤ 250.** À 4 exemplaires : **1 000**, soit 1,6 %.
* **Palette** : **bande haute**, `L ≥ 0,4104`, bois mort gris argent.
* **Prompt Meshy** :

      A single dead leaning tree, a bare slanted trunk with four or five
      broken angular branches and no leaves, the bark peeled away in
      patches. Silver-grey weathered wood, dry and pale. One isolated
      trunk, nothing attached to it.

---

### Tri final de la liste B, par ratio impact / coût (estimé)

| rang | asset | impact | triangles | rôle | financement |
|---|---|---|---|---|---|
| 1 | **B1** `rocher_marecage` ×2 | élevé (48 props) | **0 net à ≤80** | silhouette | neutre |
| 2 | **B2** `souche_racines` | élevé (zones vides) | +1 500 | remplissage | A2 + `TreeCrown` |
| 3 | **B3** `arbre_totem_central` | **le plus élevé** | +2 200 | **point focal** | A2 + crown + bush |
| 4 | **B4** `roseaux_berge` | moyen | +1 440 | silhouette | A2 + `Rock` |
| 5 | **B5** `arbre_mort_penche` | moyen | +1 000 | fond | à financer |

**Si les cinq sont produits** : +6 140 triangles bruts. **Aucune combinaison
ne tient sans les réductions de la liste A.** C'est la conclusion la plus
contraignante de cet audit, et elle est mesurée : **le hub n'a pas de
place libre.**

## Arbitrage pipeline — les deux voies, chiffrées

**⚠️ La prémisse du brief est fausse et ça change le chiffrage.** Il
n'existe pas un décimateur mais **deux** :

| script | lignes | source | sujets hardcodés |
|---|---|---|---|
| `scripts/dev/decimate_hazard.py` | 459 | `assets_source/ennemis` | 6 hazards |
| **`scripts/dev/decimate_decor.py`** | **253** | `assets_source/decor` | **4 sujets de décor** |

Les deux sont hardcodés par un dict `MODELS`, donc **la conclusion du brief
tient : aucun chemin de décimation n'existe pour un prop de décor neuf.**
Mais `decimate_decor.py` est **déjà écrit pour du décor**, et sa machinerie
est **déjà générique** : `geometry(path)`, `weld(verts, faces, tolerance)`,
`write_glb(path, verts, faces, color)`, `srgb_to_linear(c)` ne connaissent
aucun sujet. **Seuls `SRC`, `MODELS`, `COLORS` et `main()` sont spécifiques.**

### Voie 1 — contraindre Meshy à sortir bas-poly directement

* **Coût dev** : **zéro.**
* **Chiffrage du résultat (mesuré, pas supposé)** : l'en-tête de
  `decimate_decor.py` consigne que les `.glb` de décor Meshy **arrivent à
  4 130 – 5 230 triangles** et 12–18 Mo de PNG. Les GLB installés le
  confirment : cabane **7 262**, ours **5 846**, blaireau **5 623**, hibou
  **4 423**, pie **4 210**.
* **Conséquence** : les budgets de la liste B vont de **80 à 2 200**
  triangles. Une sortie Meshy bas-poly telle que le dépôt l'a mesurée est
  donc **2× trop lourde pour B3 (le plus permissif) et 50× trop lourde pour
  B1**. **Cette voie seule n'atteint aucun budget de la liste B sauf B3, et
  encore de justesse.**
* **Autre coût** : le payload. `export_filter="all_resources"` embarque tout ;
  un `.glb` texturé de 12–18 Mo par asset est sans rapport avec le `.pck` de
  4,23 Mo.
* **Moins de contrôle** : confirmé, mais ce n'est pas le problème principal —
  **le problème est que le chiffre ne descend pas assez bas.**

### Voie 2 — généraliser `decimate_decor.py` en outil générique

* **Nature du travail** : remplacer `SRC` / `MODELS` / `COLORS` / `main()`
  par une interface `--input <glb> --color <hex> --target <n> --out <path>`.
  **Aucun algorithme nouveau** : le welding (qui est la partie difficile —
  Meshy sort des amas de coques fermées séparées qu'un décimateur quadrique
  ne peut pas traverser) et l'écriture GLB existent et sont éprouvés.
* **Coût dev (estimé)** : **40 à 60 lignes modifiées, aucune ligne
  d'algorithme.** Environ **un tiers de lot**, dont l'essentiel est la
  vérification : reproduire les sorties actuelles des 4 sujets **à
  l'identique** avant de croire la version générique — c'est le seul garde-
  fou qui vaut ici (rouge avant vert : neutraliser un sujet doit faire
  échouer la comparaison).
* **Réutilisable** : oui, pour tous les lots d'assets futurs.
* **Limite héritée, à connaître avant d'arbitrer** : `decimate_decor.py`
  **ne transporte pas les UV** — son propre en-tête le dit, et `CLAUDE.md`
  le redit. Aucun asset texturé ne survit. **Cette limite est sans effet sur
  la liste B**, dont les cinq fiches demandent des albédos plats unlit, mais
  elle exclut définitivement tout asset dont le caractère tient à sa texture.

**Ce document ne tranche pas. Mathieu arbitre.** Le seul élément que la
mesure impose : **la voie 1 seule ne permet pas de produire B1, B2, B4 ni
B5 dans leur budget.**

## Prochaines mesures que ce lot n'a PAS faites

Nommées pour qu'elles ne soient pas confondues avec des résultats :

1. **La pire frame.** 61 161 est le total de scène. Une sonde du type
   `TrackPropsAudit` phase 1 donnerait le coût réel après culling.
2. **La séparation par la teinte.** Aucune sonde du dépôt ne la mesure, et
   c'est elle qui travaille à l'intérieur d'une bande.
3. **Le fog sur device.** L'écart de 0,80× mesuré ici sous desktop GL n'est
   pas transportable en WebGL2.
4. **Un rendu comparatif hibou / ours / blaireau** — les trois ne sont
   jamais dans le même cadre, donc l'inversion d'échelle mesurée n'a pas
   encore de verdict de lisibilité.

## Ce que ce lot a écrit

* `docs/lots/CH22_HUB_VISUEL.md` — ce fichier.
* Une ligne d'index dans `CLAUDE.md` et dans `docs/lots/INDEX.md`.

**Rien d'autre.** Les deux sondes ont été supprimées avant le commit ;
`ProbeTimeoutAudit` retrouve donc son chiffre de baseline. Aucun fichier de
`scripts/hub/`, `scripts/world/`, `scenes/`, `resources/` ni `assets/` n'a
été touché, et **aucun fichier n'a été supprimé.**
