# Carte blanche — qualité visuelle de l'environnement (journal)

Branche jetable `claude/carte-blanche-cozy-02o8dm`, jamais mergée. Append seulement.

## Ouverture

- **Base** : `a05ceba` (`origin/main` HEAD au 5 sept 2026 00:30 UTC, arbre `3e3f1a2`, byte-identique).
- **Preview** : `https://keepy-cozy.vercel.app` (alias dédié posé par le workflow sur cette branche ; ni `keepy-staging` ni `keepy-ten` touchés). Preuve de déploiement : voir checkpoint 0.
- **Blender** : **OK** — `pip install bpy` (5.0.1) en 33 s, export GLB en 5 ms, rendu EEVEE sous `xvfb-run` en 41 s après install de `libegl1` (le premier rendu a échoué sur `libEGL.so.1` absent). Verdict rendu à 00:37 UTC, 3 min dans la timebox. Les rendus Blender sont dans le journal comme contrôle de FORME ; le contrôle de RENDU passe par une capture Godot sous `xvfb --rendering-driver opengl3` depuis la vraie caméra du hub.
- **Palette : voie A (clair et chaud), assumée jusqu'au bout.** Cinq lignes :
  1. Les six GLB texturés (Keepy, ours, blaireau, hibou, cabane, pie) sont déjà DIURNES — CH22 note que la cabane est « le seul objet à la fois grand, coloré et texturé ». Ce sont les seuls objets finis du hub, et c'est le décor sombre qui jure avec eux, pas l'inverse.
  2. Tout est unlit : la profondeur ne peut venir que de la VALEUR et de la TEINTE. Un sol à L = 0,10 (CH22 : 20 albédos sur 25 en bande morte, une seule bande utile) ne laisse aucune marge en dessous ; un sol clair ouvre les deux bandes.
  3. Le registre AC est un registre de valeurs claires et de teintes saturées-douces ; le transposer par les formes seules (voie B) laisserait le premier verdict device (« prototype sombre ») intact.
  4. Le swamp de Chased n'est pas touché : `SwampPalette` reste la palette du mini-jeu, le hub reçoit sa propre palette (un mini-jeu de poursuite dans une forêt inquiétante reste cohérent avec un hub accueillant — c'est le contraste jour/nuit d'un vrai jeu, pas une incohérence).
  5. Risque assumé : les 3 anneaux de portail (orange saturé), les eaux turquoise et la palette bois des props interactifs (figés) ont été réglés contre un sol sombre ; ils seront relus sur le nouveau sol, et le décor s'adapte à eux, jamais l'inverse.

## Checkpoint 0 — déploiement preview

- Le workflow `web-build.yml` ne déclenchait que sur `main` et `staging`. Ajouté sur cette branche : déclencheur `push` sur `claude/carte-blanche-cozy-02o8dm` et un step de déploiement preview qui réutilise les secrets existants et pose l'alias `keepy-cozy.vercel.app` (même mécanisme que staging).
- Ce commit ne contient aucun changement de jeu : il sert uniquement à prouver la chaîne build → deploy → alias.
- **PREUVE** (00:42 UTC) : run `33933481799` `conclusion: success` (export 00:39:29 → 00:39:35, step preview 00:39:50) ; déploiement Vercel `dpl_9XfY7iYxF35KdC7WcW2mPLTrvZqS` (`gitRootDirectory = build/web`, `READY`) ; `GET https://keepy-cozy.vercel.app/` → 200, `x-vercel-cache: MISS`, `age: 0`, corps = `index.html` Godot avec `index.pck` 30 543 984 octets. Le déploiement natif Vercel (branchAlias, dépôt brut) existe aussi pour cette branche, comme sur `main` : il ne porte pas l'alias `keepy-cozy`, donc sans effet.
- Outillage sandbox posé : Godot 4.3 éditeur (50 276 070 octets, conforme) + templates d'export (1 073 228 327 octets, vérifiés contre `Content-Length`), `bpy` 5.0.1.

## Checkpoint 1 — le hub passe en voie A : sol, végétation, arbres, mur de forêt, eaux (00:57 UTC)

**Ce qui est fait.**
- **Pipeline Blender** : `bpy` headless, une famille = un script paramétré (`trees.py`, `ground_props.py` dans le scratchpad, copiés sous `docs/carte_blanche/blender/` au checkpoint suivant), N variantes en sortie, **couleurs de sommets** (COLOR_0) baked par script au lieu de textures, puis réécriture du GLB en **un seul matériau plat `KHR_materials_unlit`, sans texture ni PBR** (même contrat que `decimate_decor.py`). Vérifié à l'import Godot par une sonde (`CozyGlbInspect`) : COLOR_0 survit, en linéaire, matériau importé `shading 0` + `vertex_color_use_as_albedo`.
- **30 GLB** sous `assets/models/decor/` : 7 arbres (4 ronds, 1 haut, 1 conifère à étages, 1 LOD lointain à 72 tri), 4 rochers, 3 buissons, 3 touffes d'herbe, 4 fleurs, 2 champignons, 2 souches, 3 feuilles mortes, 2 galets. 4 à 210 triangles pièce, 1,5 à 18 Ko pièce.
- **Shader décor** `cozy_decor.gdshader` : unshaded (règle du dépôt), **toon 2 bandes + rim light** calculés depuis une direction fixe (aucune lumière de scène, donc identique llvmpipe / WebGL2), **haze de profondeur écrit à la main** (fog moteur non fonctionnel en WebGL2 → `fog_enabled = false` dans `HubWorld._apply_swamp_palette`), vent en vertex (touffes, fleurs, houppiers, sans `inverse()` de matrice), deux faces (herbe, feuilles) avec normale retournée.
- **Shader sol** `cozy_ground.gdshader` : un seul quad 600×600, trois verts mélangés par une `NoiseTexture2D` seamless (deux échelles), même haze. **Piège payé** : une distance interpolée par sommet sur un quad de 600 u vaut ~300 u partout → sol entièrement couleur ciel à la première capture. Corrigé en interpolant la position vue et en prenant la longueur par fragment.
- **HubBuilder** : `tree` / `rock` / `bush` / `flower` / `stump` routés vers les GLB (variante par hash de position, distorsion A3 conservée), specs de batch à 3 éléments (mesh, couleur, matériau), `use_colors` posé AVANT `instance_count` (sinon le buffer est réalloué), teinte par instance ±7 % ; landmarks recolorés et passés au toon (`_toon_node`) ; eaux, berges et îlots recolorés via `CozyPalette` (Keepy hérite de la teinte d'eau par `HubWater` qui lit `POND_WATER_COLOR`, comme avant).
- **CozyScatter** (nouveau nœud après `Props`) : couvre-sol seedé (908 touffes, 72 fleurs, 72 feuilles, 43 galets, 12 champignons, 13 buissons/rochers de plus) en évitant eaux, `ground_footprints()`, tracé du ruisseau et spawn ; **mur de forêt** hors région (107 arbres détaillés en bande proche, 203 LOD derrière, rien au sud de z = 50 : jamais dans le cadre). Batches par **cellule de 28 u** pour que le frustum culling coupe des cellules entières.
- Palette : ciel/haze (0,74 ; 0,87 ; 0,95), sol (0,55 ; 0,78 ; 0,36) ± patches, eau (0,42 ; 0,78 ; 0,86 ; α 0,82), berges sable (0,86 ; 0,78 ; 0,56).

**Métriques (sonde `CozyCapture`, opengl3 sous xvfb, scène entière, pas la frame).**

| | baseline `main` | checkpoint 1 |
|---|---|---|
| triangles scène | 61 107 | **109 127** |
| MultiMeshInstance3D | 17 | 110 |
| draw calls estimés (surfaces) | 166 | **259** |
| MeshInstance3D | 149 | 149 |
| `index.pck` | 30 543 984 | **30 705 072** (+161 Ko) |

Dépassement du plafond de 50 000 assumé et visible : ×2,2 sur la scène entière ; le mur de forêt et l'herbe sont découpés en cellules, donc la frame en voit une fraction — **non mesuré par frame** (la sonde compte la scène). À décider par Mathieu sur device.

**Fragile / à regarder en priorité sur device.**
1. Le shader décor et le shader sol sur WebGL2 Safari : `FRONT_FACING`, `smoothstep`, `INV_VIEW_MATRIX` sont standard, mais rien n'est prouvé hors llvmpipe.
2. 259 draw calls : si ça rame sur iPhone, la première coupe est `CELL` (28 → 40) et `WALL_SECTORS`.
3. Les disques sombres des portails (`HubPortal.tscn`, figé) lisent comme des trous dans le sol clair — écart noté, non corrigé (hors périmètre).
4. Le cairn (landmark variante 1) est presque blanc sous haze : à réchauffer.
5. L'eau est encore un disque plat (priorité 4).

## Checkpoint 2 — eau animée, ombres portées, arbres HD, collines d'horizon (01:10 UTC)

**Preuve du checkpoint 1 sur le service** : run `33934633094` `success` (01:02:41), preview `keepy-cozy.vercel.app` reconstruite.

**Ce qui est fait.**
- **Eau** (`cozy_water.gdshader`) : deux tons mélangés par le bruit seamless partagé avec le sol, deux échelles qui défilent, fines lignes de crête, **liseré d'écume au bord** (rayon modèle passé en uniform par `_make_water_body`, 0 pour le ruban du ruisseau), haze. Première version trop chargée (caustiques blancs) → crêtes ×0,22, échelle 7 → 11 u, vitesse 0,035 → 0,025.
- **Ombres portées** (`cozy_shadow.gdshader`) : un quad alpha par arbre / buisson / rocher / souche / landmark du layout (pas les landmarks `offshore`, qui flotteraient sur le lac) et par arbre du mur, décalé à l'opposé du soleil. **Un seul MultiMesh, 2 triangles par ombre.** C'est ce qui ancre visuellement les props sur le sol clair.
- **Arbres HD** pour le layout (`tree_7..10_hi`, 550–630 tri, icosphère subdiv 3 + lobes subdiv 2) ; les 190-tri restent pour le mur proche, 72-tri pour le mur lointain. Conifère refait (390 tri, palette plus claire) et ramené à 0,72× dans le layout.
- **Collines d'horizon** : 26 sphères écrasées (22–40 u de large) entre 78 et 118 u, teinte vert pâle, dissoutes à ~85 % par le haze — la bande haute du cadre lit comme un paysage au lieu d'un aplat.
- Sol : troisième octave fine (1,7 u, ±6 %) pour un moucheté près de la caméra. Cairn réchauffé.
- Scripts Blender copiés sous `docs/carte_blanche/blender/` (exclus de l'export via `docs/*`), planches de contrôle et captures avant/après sous `docs/carte_blanche/`.

**Métriques.**

| | baseline | cp 1 | **cp 2** |
|---|---|---|---|
| triangles scène | 61 107 | 109 127 | **135 187** |
| MultiMeshInstance3D | 17 | 110 | 112 |
| draw calls estimés | 166 | 259 | **261** |
| `index.pck` | 30 543 984 | 30 705 072 | **30831840** |

**Fragile / à regarder sur device.** L'eau (alpha + `TIME`) est le shader le plus exposé aux différences WebGL2 ; les ombres sont alpha-blended et triées comme un objet unique contre l'eau (elles n'y sont jamais dessus, par construction). Les captures de contrôle ne peuvent pas montrer le vent ni l'animation de l'eau.

## Checkpoint 3 — papillons, ombre du héros, cairns en pierres, nuages (01:20 UTC)

**Preuve du checkpoint 2 sur le service** : run `33935026373` `success` (01:09:15).

**Ce qui est fait.**
- **Papillons** (`cozy_butterfly.gdshader`, 3 GLB de 10 triangles) : 21 papillons, **tout est dans le vertex shader** (battement d'ailes par pliage des sommets |x| > 0,02 autour de l'axe du corps, circuit circulaire à hauteur ondulante, orientation tangente) à partir d'`INSTANCE_CUSTOM` (phase, rayon, sens, cadence) — un draw call par couleur, zéro script par frame. Centrés sur les fleurs posées par `CozyScatter`. **Piège payé** : sans `use_colors = true` sur le MultiMesh, `COLOR` lit noir dans le shader même quand le mesh porte des couleurs de sommets — première capture : des taches noires.
- **Ombre du héros** : un quad alpha suit la position au sol de Keepy (lecture seule de `global_position`, rien de Keepy n'est touché), rétrécit en l'air.
- **Ombres portées** repositionnées : un disque décalé à l'opposé du soleil tombe DERRIÈRE un buisson depuis cette caméra et ne se voit jamais (capture 6 : seuls les arbres en montraient) → disque surtout sous l'objet, poussé de 0,12 r vers la caméra, rayon buisson/rocher élargi, alpha 0,40.
- **Cairn et dalles** : les boîtes grises deviennent des pierres GLB empilées (mêmes hauteurs, mêmes inclinaisons, mousse sur le dessus par les couleurs de sommets) — la silhouette d'orientation est conservée, la lecture « béton » disparaît.
- **Nuages** : 9 nuages de 3 lobes chacun, matériau toon sans haze. **Piège payé** : posés à y = 30–48 ils étaient entièrement HORS CADRE — la caméra ne laisse que ~2,5° de ciel au-dessus de l'horizon ; ramenés à y = 9–17 à 150–200 u, ils affleurent l'horizon derrière les collines. Dérive lente en `_process`.
- **Mouvement prouvé** : diff pixel entre deux captures (frames 40 et 100) → 31 599 pixels changent (herbe, eau, papillons), zéro en l'absence d'animation.

**Métriques.**

| | baseline | cp 2 | **cp 3** |
|---|---|---|---|
| triangles scène | 61 107 | 135 187 | **140 165** |
| MultiMeshInstance3D | 17 | 112 | 116 |
| MeshInstance3D | 149 | 149 | 150 |
| draw calls estimés | 166 | 261 | **266** |
| `index.pck` | 30 543 984 | 30 831 840 | **30 844 480** |

**À regarder sur device.** Les papillons (INSTANCE_CUSTOM en Compatibility/WebGL2), la dérive des nuages, l'ombre de Keepy pendant un bond.

## Checkpoint 4 — chemins, parterres de portail, moucheté cellulaire (01:27 UTC)

**Preuve du checkpoint 3 sur le service** : à lire dans le rapport final (run lancé 01:11).

**Ce qui est fait.**
- **Chemins de terre** : un disque usé au spawn (rayon 2,3) et quatre rubans (spawn → les trois portails, spawn → porte de la cabane, cette dernière lue dans `HubBuilder.cabins()["door"]`, jamais recopiée), courbe de Bézier à contrôle latéral, bords ondulés lisses, matériau toon teinté `PATH`. Le couvre-sol les évite (`_on_path` dans `_blocked`). Trois pièges payés en quatre captures : (1) quatre rubans coplanaires qui se chevauchaient au spawn → étoile de hachures, réglé par le disque de plaza 4 mm plus bas et des départs hors plaza ; (2) le disque enroulé dans le mauvais sens dessinait en face arrière, donc dans la bande d'ombre du toon (gris) ; (3) **des hachures le long de chaque ruban courbé** — diagnostic z-fight sol → faux (persistait à y = 0,15) ; cause réelle : une normale PAR SEGMENT donnait deux sommets de bord différents à chaque jointure, donc des triangles coplanaires se recouvrant à chaque virage. Normales par ÉCHANTILLON, sommets partagés → propre.
- **Parterres** : 13 fleurs en anneau (r = 2,05) autour de chaque portail, une couleur par portail (jaune Quizz, rose Chased, violet Battle).
- **Sol** : texture cellulaire seamless (Voronoi `RETURN_DISTANCE2_SUB`) à 2,6 u, ±5 %, pour un tapis de trèfle près de la caméra.
- **Arbres du layout ramenés à 0,80×** (0,92 avant) : les houppiers HD sont 1,6× plus larges que les anciennes sphères et masquaient Keepy derrière un arbre depuis la caméra fixe (capture nw2). À 0,80 la parité d'emprise est approchée ; l'occlusion reste possible et n'est pas résolue (voir RÉCOLTE).

**Métriques.**

| | baseline | cp 3 | **cp 4** |
|---|---|---|---|
| triangles scène | 61 107 | 140 165 | **139 878** |
| MultiMeshInstance3D | 17 | 116 | 119 |
| MeshInstance3D | 149 | 150 | 151 |
| draw calls estimés | 166 | 266 | **270** |
| `index.pck` | 30 543 984 | 30 844 480 | **30 849 552** (+306 Ko sur la nuit) |

## RÉCOLTE — ce qui mérite un lot cadré vers `staging`, et ce qui est à jeter

**Verdict d'ensemble.** La voie A tient : la palette claire réconcilie enfin le décor avec les six GLB texturés, et le hub lit comme un jeu au premier regard (captures `docs/carte_blanche/capture_cp4_spawn.png` contre `capture_baseline_spawn.png`). Rien de ceci n'est validé device : tout ce qui suit est classé sur ce que les captures llvmpipe prouvent, pas sur ce que Safari fera.

**À rejouer proprement, par ordre de valeur / risque.**
1. **Le pipeline Blender → GLB vertex-coloré unlit** (`docs/carte_blanche/blender/`). C'est l'acquis structurel de la nuit : une famille = un script, N variantes, aucune texture, 1,5–50 Ko par asset, et il remplace Meshy pour tout ce qui est décor géométrique simple. À intégrer avec une sonde qui gate COLOR_0 + `KHR_materials_unlit` à l'import (`CozyGlbInspect` en est l'embryon). **Doctrine à consigner** (CLAUDE.md non touché, comme demandé) : construire en Y-haut puis `stand()` avant export, sinon tout sort couché ; `use_colors` avant `instance_count` ; sans `use_colors`, COLOR lit noir.
2. **Le shader décor** (toon 2 bandes + rim + haze manuel + vent). Il ne dépend d'aucune lumière ni du fog moteur, donc il est exactement aussi prévisible sur WebGL2 que les matériaux unlit actuels. Le lot cadré doit d'abord le prouver sur device avec UN batch (les arbres du layout), pas tout d'un coup.
3. **Sol shader + chemins + ombres portées** : le trio qui ancre les objets. Coût quasi nul (un quad, un mesh de chemins, un MultiMesh de quads alpha). Les chemins doivent partir du layout dans un lot propre (ici ils sont dérivés à la volée des portails et de la porte).
4. **CozyScatter** (couvre-sol, mur de forêt, collines, nuages, papillons). À rejouer AVEC un budget : le mur (309 arbres) et l'herbe (898 touffes) sont les deux gros postes ; un lot cadré doit mesurer la frame sur device et fixer `CELL`, `WALL_*_PER_U2`, `GRASS_PER_U2` en conséquence. Les papillons (`INSTANCE_CUSTOM`) sont à prouver sur device avant d'être gardés.
5. **Eau** : le shader est simple et remplace un disque plat ; garder, mais **régler l'alpha par balayage device** (doctrine CLAUDE.md : le rendu n'est pas affine en alpha), et vérifier à plusieurs azimuts puisque c'est de la transparence.

**À jeter ou à refaire autrement.**
- **Les 44 arbres du layout à leur position actuelle** : ils ont été placés pour des houppiers de r = 0,95 ; avec des houppiers ronds ils masquent parfois Keepy. Le vrai lot doit soit re-placer les arbres avec un test `unproject_position` d'occlusion, soit garder un rayon de houppier ≤ 1,0 u, soit ajouter un fondu d'occlusion. Ce n'est pas résolu ici.
- **Les landmarks en pierres empilées** : lisibles, mais la variante « aiguille » (tronc + trois cônes) reste une primitive ; un vrai lot les remplacerait par des GLB Blender dédiés (un grand conifère, un menhir, un cairn) au lieu de rochers étirés.
- **Le placement des papillons et des parterres dérivé des fleurs du scatter** : fragile (un changement de seed les déplace). À ancrer sur le layout.
- **`CozyCapture`** est une sonde de nuit : elle ne gate rien. À convertir en sonde gatée (pixel centre non-ciel, compte de batches, budget) ou à supprimer.
- **La ligne `fog_enabled = false` dans `HubWorld._apply_swamp_palette`** est la seule modification hors de mes fichiers avec la scène ; elle doit être portée par un vrai `HubPalette` si la voie A est retenue, et retirée sinon.
- **Écart figé noté, non corrigé** : les disques intérieurs des portails (vert sombre) lisent comme des trous dans le sol clair ; le sol s'adapte, pas le portail (hors périmètre).
