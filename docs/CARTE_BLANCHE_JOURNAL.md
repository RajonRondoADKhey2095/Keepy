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

---

# V2 — deuxième map et météo vivante

Même branche jetable, même preview `keepy-cozy.vercel.app`, append seulement.

## Ouverture V2

- **Tag `cozy-v1` posé sur `20986d1`** (bypass auth preview, HEAD de `origin/claude/carte-blanche-cozy-02o8dm` au fetch de 03:45 UTC). Point de retour si la v2 part en vrille : `git checkout cozy-v1`.
- **Hash de départ** : `20986d1`. Outillage reposé dans un sandbox neuf (Godot 4.3 éditeur 50 276 070 octets, templates 1 073 228 327 octets vérifiés contre `Content-Length` au premier essai, `bpy` 5.0.1) ; import complet mesuré à 534 `.scn`, zéro erreur.
- **Direction de la deuxième map — « le Vallon d'automne »**, en cinq lignes :
  1. **Où** : au-delà des deux grands lacs, `z ≤ −42` (la direction que la caméra regarde depuis le spawn : c'est la bande haute du cadre, au-dessus des lacs, la seule place où « une silhouette au loin » est physiquement dans l'image avec cette caméra fixe à +2,4° au-dessus de l'horizon).
  2. **Quoi** : un biome d'AUTOMNE — sol ocre/rouille couvert de feuilles mortes, arbres orange / rouge / or, fougères et champignons géants, citrouilles, aucune eau. Le contraste avec le plateau (vert printemps, cinq plans d'eau) est un contraste de TEINTE sur toute l'image, pas une variation de densité.
  3. **Repère** : un arbre géant (« l'Arbre-Mère ») planté sur l'axe du spawn à `(0, −62)`, houppier orange de ~14 u de large : depuis le spawn il dépasse au-dessus du mur de forêt, pile au-dessus du portail Quizz.
  4. **Accès** : la seule terre entre les lacs et le bord (`x ∈ [−35, −22]`, 13 u de large à l'ouest du lac de spawn) porte un chemin de terre qui perce le mur de forêt à `z ≈ −38` ; le mur reste fermé partout ailleurs entre les deux zones (bande `z ∈ [−42, −36]` pour `x > −22`).
  5. **Même altitude, même navigation** : la région reçoit un rectangle et un couloir (`HubRegion`), aucune falaise ni escalier ; la zone existante n'est pas touchée.

## Checkpoint P0 — le ruisseau est de retour, la barque navigue dessus

**Cause mesurée, pas supposée.** Le ruban du ruisseau est enroulé en ANTI-HORAIRE vu de dessus (normale du premier triangle `(0, 1, 0)` par la règle de la main droite, sonde headless jetable `CozyStreamProbe`, supprimée avant commit). **Godot 4 tient les faces HORAIRES pour faces avant.** L'ancien `StandardMaterial3D` dessinait avec `CULL_DISABLED`, donc personne ne l'avait jamais vu ; le shader cozy est `cull_back`, et le ruban entier était culled — nœud visible, dans l'arbre, AABB juste, matériau juste, zéro pixel. Capture avant/après à Keepy `(0, 20)` : aucune eau dans la bande `z ≈ 10` avant, le ruisseau complet après.

**Ce qui est fait** (`HubBuilder._make_stream`, `cozy_water.gdshader`, `CozyPalette.water_material`) :
- ruban ré-enroulé en horaire ; `UV.x` porte la coordonnée latérale (0 rive gauche, 1 rive droite) ;
- mode `ribbon` du shader d'eau : liseré d'écume sur les deux rives lu dans `UV.x` (le disque lit son rayon, le ruban lit son UV — même shader, même famille que le lac) ;
- **rive de sable** sous le ruban (`StreamBank`, +0,42 u de chaque côté, y = 0,055 : au-dessus des chemins à 0,03, sous l'eau à 0,095), purement visuelle, même matériau toon teinté `BANK` que les berges des lacs.
- **Tracé, largeur (1,2), `STREAM_SURFACE_Y`, `RIDE_SEAT_Y` : INTOUCHÉS.** J'ai regardé élargir le ruban et refusé : `KeepyHopper` dérive le point de débarquement de `_ride_half_width + BANK_MARGIN`, donc changer la largeur déplace la fin du ride de quelques centimètres — « ride exact » prime.

**Preuve du ride** (`CozyCapture --ride=auto`, xvfb + opengl3 + `--fixed-fps 60`) : tap sur la barque amarrée à l'ouest `(−18,54, −0,73)` ; trace de Keepy toutes les 30 frames : `y = 0,140` (= `RIDE_SEAT_Y`) et `is_riding = true` de la frame 30 à la frame 300, arrivée `(17,52, 0,24, 6,61)` à la frame 330, `is_riding = false` (débarqué). Ouest → est complet, gate de retrait intacte (`BoatMooring.set_riding`).

⚠️ **Piège de sonde payé** : `_setup_ride()` amarre la barque à l'extrémité la plus PROCHE de Keepy au boot (ouest depuis le spawn : 18,5 u contre 18,8), pas à la position du layout. Un premier essai qui tapait la position du layout `(17,58, 6,67)` a fait marcher Keepy jusqu'à une barque absente — `_boarding` relâché par `became_idle`, aucun ride, et rien ne le dit. `--ride=auto` lit maintenant `Mooring.boat_position()`.

**Preuve du P0 sur le service** (04:22 UTC) : déploiement CI `dpl_AoviAqAyrjdUb15KBAa3kmXAmutK` (`gitRootDirectory = build/web`, sha `44a683a`, `READY`) ; `GET https://keepy-cozy.vercel.app/` → 200, `x-vercel-cache: MISS`, `age: 0`, `fileSizes` : `index.pck` 30 852 224 (export local 30 852 208 — les 16 octets de variance documentés), `index.wasm` 35 376 909 (identique). Le déploiement natif (`branchAlias`) existe aussi, sans l'alias `keepy-cozy`, sans effet.

## Checkpoint P1 — le Vallon d'automne (04:35 UTC)

**Ce qui est fait.**
- **Famille Blender `autumn.py`** (`docs/carte_blanche/blender/`, planche `docs/carte_blanche/autumn_sheet.png`) : 17 GLB — 4 arbres d'automne (orange / rouge / or / rouille, 190 tri), 2 LOD lointains (72 tri), **l'Arbre-Mère** (1 024 tri, 18,5 u de haut, houppier ~16 u, contreforts de racines), 2 fougères (35 tri), 2 champignons géants (190 tri, à pois / brun), 2 citrouilles (247 tri), 1 tronc creux (160), 2 tas de feuilles (80), 1 lanterne sur poteau (48). Même contrat que v1 : COLOR_0 + `KHR_materials_unlit`, 3 à 86 Ko pièce. Vérifiés à l'import par `CozyGlbInspect` (AABB, couleurs).
- **`HubRegion`** : rectangle `x ∈ [−33, 33] × z ∈ [−78, −42]` + couloir `x ∈ [−33, −23] × z ∈ [−42, −33]` (recouvre le carré du plateau à `z ≥ −35`, donc connexe), **un trou** (tronc de l'Arbre-Mère, r = 2,7) refusé par `contains()` et dont `clamp_to()` propose le bord. Sondé : `(0, −60)` → `(0, −59,28)` ; `(0, −38)` (haie) → `(0, −35)` ; `(−34, −38)` → `(−33, −38)` ; `(0, −79)` → `(0, −78)`. Le plateau existant n'a pas changé d'un point.
- **Sol** : masque automne dans `cozy_ground.gdshader` (seuil `z = −39`, fondu 7 u, bord déchiqueté par le bruit à grande échelle), trois ocres `AUTUMN_A/B/C` dans `CozyPalette` — un seul quad, zéro géométrie ajoutée.
- **Route** (`CozyScatter.AUTUMN_ROAD`, Catmull-Rom, même extrusion que les chemins v1, refactorisée en `_extrude_path`) : plaza → entre le parterre Chased et l'arbre `(−9,87, −4,07)` → entre la souche `(−15,6, −5,2)` et le plongeoir 3 → longe la rive du lac de spawn (`x = −25`, rive à `−23,3`) entre les arbres `(−21,9, −25,5)` et `(−28,5, −27,8)` → couloir → Arbre-Mère. Premier tracé refusé en capture : il frôlait l'arbre du layout `(−30,4, −23,6)` et une lanterne était plantée dedans. 6 lanternes côté droit à partir de `z < −28`.
- **Scatter automne** : 22 arbres (hors clairière r = 9,5 et hors route), 131 fougères, 47 tas de feuilles, 20 citrouilles en 4 potagers, 7 + 7 champignons géants (dont un anneau au bord de la clairière), 2 troncs creux, l'Arbre-Mère en `MeshInstance3D` avec un vent lent. **Haie** dédiée entre les deux zones (bande `z ∈ [−41,5, −36,5]`, `x > −21,5`, 26 arbres : verts côté plateau, automne côté vallon) parce que le mur générique n'y met presque rien (2 u de dégagement de chaque côté d'une bande de 6 u). Le mur de forêt descend jusqu'à `z = −100` et devient automne sous `z = −40` ; les collines du secteur `z < −55` reculent à `r ≥ 126` — la jupe d'une colline (jusqu'à 40 u) enterrait les troncs du mur lointain et laissait une **canopée flottante** à l'horizon (capture 1).
- **Tas de feuilles refaits deux fois** : lumpy + facettes plates + 4 couleurs saturées sous le toon → **lisaient comme des rochers de lave** (capture 1) ; aplatis, lissés, dégradé centre/bord, échelle 0,6–1,05 → des amas.
- **Navigation trans-zone** (`HubWorld._hop_via_corridor`, 20 lignes) : la région n'est plus convexe, et `KeepyHopper` saute en ligne droite en ne clampant que sa DESTINATION. Mesuré avant : une marche `(−25, −30) → (−6, −56)` passait par `(−19,3, −37,8)`, dans la haie. Un tap qui change de zone marche d'abord jusqu'à la **porte du couloir** `(−28, −38,5)`, puis repart vers la cible sur `became_idle`. Mesuré après (headless, `--walk`) : `(−10, −10) → (−6, −56)` passe par `(−26,7, −39,5)` à la frame 420 et arrive à la frame 780. Les taps intra-zone sont inchangés.

**Depuis le spawn** (`docs/carte_blanche/capture_v2_p1_spawn.png`) : l'Arbre-Mère dépasse du mur de forêt pile au-dessus du portail Quizz, la bande orange se lit derrière les lacs. Couloir : `capture_v2_p1_corridor.png`. Vallon : `capture_v2_p1_hollow.png`.

**Métriques** (`CozyCapture` au spawn, scène entière).

| | cp 4 (v1) | **P1** |
|---|---|---|
| triangles scène | 139 878 | **173 759** (+34 k : Arbre-Mère 1 k, mur automne + haie ~18 k, scatter ~15 k) |
| MultiMeshInstance3D | 119 | **182** |
| MeshInstance3D | 151 | **153** |
| draw calls estimés | 270 | **335** |
| instances MultiMesh | 2 194 | 2 573 |
| `index.pck` | 30 849 552 | **31011632** (+~161 Ko, les 17 GLB) |

**Ce qui coûtera le plus cher à rejouer vers `staging`** : la région en L et le détour par la porte (deux fichiers de la navigation, `HubRegion` et `HubWorld`, qui portent des sondes gatées à refaire passer — `LevelNavProbe`, les sondes de clamp), et la haie, dont la densité dépend d'une constante posée à l'œil sur une capture llvmpipe. Le shader sol et la route sont gratuits. Le mur à 208 + 135 arbres est le poste GPU à mesurer sur device.

**Non fait, assumé** : pas de son ; le couloir est le seul accès (un tap sur le vallon depuis le spawn traverse le lac de spawn à la nage vers la porte — c'est déjà le comportement du plateau pour tout tap derrière un lac) ; aucun PNJ n'habite encore le vallon (les PNJ sont figés hors météo).

**Preuve du P1 sur le service** : déploiement CI `dpl_HwhijEYBRac9A9YCskdLfDgXPMKM` (`gitRootDirectory = build/web`, sha `6f43fd4`, `READY`, 04:30 UTC).

## Checkpoint P2 — météo vivante (04:52 UTC)

**Architecture** (ordre imposé respecté : état + cycle + forçage + lumière d'abord, réactions ensuite, précipitations en dernier).
- **`CozyWeather.gd`** (nœud sous `World`) : cycle `SOLEIL 70 s → PLUIE 40 s → ORAGE 30 s → SOLEIL 50 s → NEIGE 40 s` (3 min 50 s la boucle), **fondu 6 s** entre deux états par interpolation d'un « look » complet (dictionnaire), mémoire d'humidité qui sèche en 25 s après la pluie, éclairs à l'orage (flash 1 → 0 en ~0,15 s, toutes les 2,5–7 s, seed fixe). `force(kind)` / `force_auto()`. Signal `weather_changed`.
- **Un seul lieu pour la palette** : `CozyPalette.weather_look(kind)` porte les 4 looks (ciel, haze + densité, teinte globale, vent, couché d'herbe, pluie, neige, overlay, force des ombres, papillons cachés, teinte des nuages) ; `CozyPalette.apply_weather(look)` est l'**unique écrivain** des matériaux qu'elle cache (décor statique / vent / teintés, nuages, sol, eaux, papillons, ombres, précipitations). `CozyWeather` ne touche que le ciel du `WorldEnvironment` et l'overlay.
- **Lumière** = teinte d'albédo `weather_tint` dans chaque shader (haze recalculé avec) **+ un `ColorRect` 2D `WeatherOverlay`** au-dessus du viewport monde (`mouse_filter = IGNORE`) : c'est lui qui teinte aussi les six GLB Meshy (matériaux figés, unlit, donc hors d'atteinte de toute lumière) et qui porte le flash d'éclair (blanc α 0,35 sur 2-3 frames). Mesuré (pixels, sonde `--root`) : herbe `165,206,104` soleil → `96,136,54` pluie → `70,100,43` orage → `218,228,250` neige ; eau `150,205,213` → `98,116,136` orage.
- **Forçage** : ligne « Météo (preview) : Soleil / Pluie / Orage / Neige / Auto » dans le menu existant, visible **uniquement** sous `Auth.is_untrusted_preview_domain()` (même test de hostname que le bypass invité — invisible sur staging/prod par construction) ou hors web (captures).

**Le monde réagit.**
- **PNJ — l'ours** : sur `weather_changed`, s'il est IDLE à son repos et hors trajet (pas de pivot balançoire, pas de `_bear_pending`, pas de trajet feu), il marche (`HubActorWalker.walk_to`, le marcheur déjà prouvé par les lots balançoire/feu) jusque **sous l'arbre voisin** `(5,3 ; 33,7)` ; au retour du soleil, s'il est IDLE à l'abri, il rentre à `BEAR_REST`. Mesuré (headless, pluie forcée, 700 frames) : ours à `(5,30 ; 33,70)`. **Aucun déplacement autonome ailleurs** : le badger et le hibou ne bougent pas (le retour automatique du blaireau a déjà été retiré par un lot précédent — `b4afe5d` — et je n'ai pas réintroduit de trajet non gaté ; l'ours n'a que deux points et ne part que d'un état IDLE vérifié).
- **Eau** (shader seulement) : sous la pluie vitesse ×4, échelle des rides ÷1,7, mélange vers un gris-bleu opaque (α 0,95 — l'eau « pleine », lue comme montée), **anneaux de gouttes** (troisième octave rapide seuillée), liseré d'écume élargi. Géométrie, `STREAM_SURFACE_Y`, `RIDE_SEAT_Y` : intouchés.
- **Végétation** : `wind_scale` ×1,8 pluie / ×3 orage, **`lean`** (couché constant en xz proportionnel à la hauteur, orage `(0,26 ; 0,10)`) sur tout ce qui a du vent (herbe, fleurs, houppiers), **neige** posée sur les faces vers le haut (`n.y`), sol enneigé par seuil de bruit, sol **humide** (assombri, saturé ×1,35) pendant et 25 s après la pluie.
- **Papillons** : `hidden` → sommets écrasés sur leur centre (aucun script, aucune visibilité à basculer), 1,0 dès que la pluie/neige domine, reviennent au soleil.
- **Ombres portées** : force 0,35 pluie / 0,15 orage / 0,5 neige.

**Précipitations (timebox 45 min, 04:43 → 04:50, 7 min).** `cozy_precip.gdshader` + un MultiMesh de **900 quads** (`CozyScatter._precipitation`) qui suit Keepy (seule écriture par frame : la position du nœud). Tout est dans le vertex shader depuis `INSTANCE_CUSTOM` (phase, jitter x/z, taille) : chute par `fract(phase + TIME × vitesse / hauteur)` dans une boîte 14 × 9 u, goutte = trait vertical 0,018 × 0,55 u à 9 u/s, flocon = carré 0,07 u à 1,1 u/s avec dérive sinusoïdale, quad orienté face caméra par `INV_VIEW_MATRIX[0]`, collapsé à zéro quand ni pluie ni neige. Première capture propre, aucune retouche. **Même famille que les papillons v1 (INSTANCE_CUSTOM sous Compatibility) : à prouver sur Safari, comme eux.**

**Captures** : `capture_v2_p2_rain.png`, `capture_v2_p2_snow.png` (fenêtre complète, overlay inclus), `capture_v2_p2_storm_3d.png` (viewport 3D seul — l'overlay et le flash ne sont pas dedans).

**Métriques** (spawn, pluie forcée, scène entière).

| | P1 | **P2** |
|---|---|---|
| triangles scène | 173 759 | **175 559** (+1 800 : les 900 quads) |
| MultiMeshInstance3D | 182 | **183** |
| MeshInstance3D | 153 | 153 |
| draw calls estimés | 335 | **336** |
| `index.pck` | 31 011 632 | **31025904** |

**Ce qui coûtera le plus cher à rejouer vers `staging`** : rien de structurel — `CozyWeather` + `apply_weather` sont additifs, et le seul point de contact avec le jeu existant est `_on_weather_changed` (20 lignes, gaté sur l'état IDLE de l'ours). Le vrai coût est la **preuve device** : trois shaders reçoivent des uniforms mis à jour chaque frame (coût CPU nul mais 10+ `set_shader_parameter` par frame sur ~30 matériaux — à mesurer sur iPhone), et l'overlay 2D en alpha plein écran est un coût de fillrate mobile à confirmer.

**Non fait, assumé** : pas de son ; le hibou, la pie et le blaireau ne réagissent pas ; les chemins et berges restent sable sous la neige (lisibilité du chemin, choix assumé après capture) ; la pluie/neige ne tombe que dans une boîte de 14 u autour de Keepy (invisible au loin, par construction).

## RÉCOLTE v2 — ce qui mérite un lot cadré vers `staging`, ce qui est à jeter

**Si Mathieu ne devait garder QU'UNE chose de toute la branche (v1 + v2) : le système météo** — `CozyWeather` + `weather_look`/`apply_weather` + les uniforms `weather_tint`/`wind_scale`/`lean`/`snow`/`wet`/`rain` + l'overlay. C'est le rapport valeur/risque le plus fort de la nuit : ~350 lignes additives, zéro géométrie, zéro fichier figé touché, un seul point de contact (l'ours, gaté), et c'est ce qui fait que le monde a l'air VIVANT plutôt que joli. Il se rejoue sur la palette actuelle de `main` (les uniforms se posent sur n'importe quel shader du hub) ; les looks sont à re-régler sur le sol sombre, pas à reconcevoir.

**À rejouer proprement, par ordre de valeur / risque.**
1. **Météo** (ci-dessus). Lot cadré : d'abord état + cycle + overlay + forçage, preuve device des 4 états, puis les réactions une par une.
2. **Le ruisseau visible** (P0) : correctif d'enroulement de 6 lignes, vaut pour tout ruban `SurfaceTool` du dépôt sous un shader `cull_back` — **doctrine à consigner** : Godot tient les faces HORAIRES pour faces avant ; un ruban CCW sous `cull_back` disparaît sans erreur.
3. **Le Vallon d'automne** : la partie chère est la **région en L** (`HubRegion` + détour `_hop_via_corridor`), à rejouer avec ses sondes de clamp (`LevelNavProbe`, blind check « la haie refuse ») ; la partie gratuite est le shader sol à masque + la famille Blender `autumn.py` + la route Catmull-Rom. Le mur/haie à 208 + 135 + 26 arbres est le poste GPU à mesurer sur device AVANT de fixer les densités.
4. **Les 17 GLB automne** : réutilisables tels quels (contrat v1), l'Arbre-Mère (1 024 tri, 86 Ko) est un landmark prêt à l'emploi.

**À jeter ou à refaire autrement.**
- **Le détour par une porte unique** : c'est un pansement sur l'absence de planificateur ; deux zones de plus et il faut un vrai graphe de waypoints. À refaire en `HubRegion.route(a, b)` qui rend une liste de points.
- **Les tas de feuilles** : trois versions pour un résultat moyen ; la bonne réponse est probablement un decal sol (un disque texturé alpha) plutôt qu'un mesh.
- **La haie entre zones** : sa densité est une constante posée à l'œil ; à dériver de la largeur de la bande.
- **`CozyCapture`** a grossi (ride, walk, nav, weather, root) : c'est une sonde de nuit multi-usages, pas une sonde gatée. À découper ou à supprimer.
- **Le flash d'éclair par overlay** : lisible mais brutal ; une vraie version passerait par le ciel + `weather_tint` sur 3 frames avec une courbe, et un son.

**Preuve du P2 sur le service** (04:50 UTC) : déploiement CI `dpl_D9tEPfnmr4z2tKXy4FbNpzrc5GJW` (`gitRootDirectory = build/web`, sha `d94b51f`, `READY`) ; `GET https://keepy-cozy.vercel.app/index.service.worker.js` → 200, `x-vercel-cache: MISS`, `age: 0`, `CACHE_VERSION = 1788583791` (04:49:51 UTC, après le push de 04:45:40 — donc l'export de CE commit). Tag `cozy-v1` : local seulement, le push d'un tag est refusé par le proxy git de ce sandbox (`remote end hung up`) ; le hash `20986d1` suffit.

---

# V3 — transport rapide et troisième map

Même branche jetable, même preview `keepy-cozy.vercel.app`, append seulement.

## Ouverture V3

- **Hash de départ (point de retour v2)** : `f50960e` (HEAD de `origin/claude/carte-blanche-cozy-02o8dm` au fetch de 06:05 UTC, 5 sept 2026). Aucun tag (le push d'un tag est refusé par le proxy git du sandbox, constaté en v2, pas retenté). Outillage reposé dans un sandbox neuf : Godot 4.3 éditeur 50 276 070 octets, templates 1 073 228 327 octets (vérifiés contre `Content-Length`), `bpy` 5.0.1 ; import complet 584 fichiers, 92 `.scn`, zéro erreur.
- **Le réseau de transport, en cinq lignes.**
  1. **Famille A — des LIGNES DE MONTGOLFIÈRE** : une ligne = deux docks + une montgolfière qui attend à l'un des deux. Un tap sur le dock où elle attend embarque et vole jusqu'au dock jumeau ; un tap sur le dock VIDE l'appelle (elle traverse à vide, se pose, et repart avec Keepy). Les deux docks se retirent du tap pendant tout un trajet (patron barque, par un nœud `HubTransport`, jamais un flag) ; un trajet est borné par un tween qui finit toujours sur un dock (licence tyrolienne pour jeter les taps entre-temps). Re-amarrage sur la règle de la barque : loin des deux docks et les deux hors cadre, la montgolfière est déplacée sans animation vers le dock le plus proche.
  2. **Où** : ligne « Or » `(10,5 ; 14,5)` — à 18 u au sud-est de la plaza, seul dégagement ≥ 3 u du plateau qui ne masque ni un portail ni Keepy (une montgolfière de 7 u de haut posée devant un portail l'aurait occulté depuis cette caméra fixe) — vers `(11 ; −55)` au bord est de la clairière de l'Arbre-Mère. Une deuxième ligne desservira la troisième map (P2). Un chemin de terre part de la plaza vers le dock, un panneau-flèche au bord de chaque dock pointe le jumeau, un fanion à la couleur de la ligne : c'est toute la « signalétique ».
  3. **Famille B — le « Sautillon », un ballon sauteur** garé à `(−6,5 ; 0,5)` à gauche de la plaza. Un tap dessus : Keepy marche et grimpe ; ensuite CHAQUE tap-to-move ordinaire devient un bond plus long et plus haut (2,7 u / 0,34 s contre 1,5 u / 0,28 s : ×1,4), aucun nouveau contrôle. Ce n'est pas un état de `KeepyHopper` mais un MODIFICATEUR du hop ; toute interaction de prop (barque, échelle, hibou, tyrolienne, tourniquet, balançoire, montgolfière) dépose le ballon là où il se tenait ; un tap sur soi-même à l'arrêt le dépose aussi ; règle de re-parking de la barque.
  4. **Pourquoi des montgolfières et pas des rails** : aucun chemin de géométrie à tracer (un ruban de 70 u à travers lacs et haie aurait coûté un lot à lui seul), le trajet SE VOIT (5,2 u de croisière, dans le cadre pour cette caméra à +2,4°), il dure 7-9 s, il survole ce que la marche contourne, et la météo s'y applique (tangage et dérive proportionnels au `wind` du look courant).
  5. **Ce qui ne bouge pas** : aucun ride existant modifié ; `KeepyHopper` gagne un état `ON_CARRIER` (copie du vol du hibou : porteur puis porté dans le MÊME appel) et le modificateur véhicule ; `HubTapInput` gagne deux canaux (`tapped_balloon`, `tapped_vehicle`) sur les termes de la barque (`aim`, jamais la destination clampée).

## Checkpoint P0 — overlay de performance (06:22 UTC, déployé seul)

**Ce qui est fait.** `HubPerfOverlay` (PanelContainer + Label, `mouse_filter = IGNORE`, sous le badge invité), visible par défaut sous `Auth.is_untrusted_preview_domain()` ou hors web, bouton « Perf (preview) : ON/OFF » dans le menu (même gate que la ligne météo). Quatre lignes : FPS (courant, min glissant 3 s) ; TRI `gpu` / `lod0 cadre` / `scene` ; DRAW `calls` / `obj` moteur, batches en cadre / total, instances en cadre ; METEO. `CozyCapture` écrit le snapshot de l'overlay dans `COZY_STATS.perf`.

**Deux lectures indépendantes de la même frame, et elles ne disent pas la même chose — mesuré, puis lu dans la source de Godot 4.3** (`drivers/gles3/rasterizer_scene_gles3.cpp`, `_fill_render_list`) :

| lecture | spawn, soleil | ce que c'est |
|---|---|---|
| `gpu` (`viewport_get_render_info … PRIMITIVES_IN_FRAME`) | **52 472** | ce que le renderer a compté : liste OPAQUE seulement (l'eau, les ombres, la pluie, les papillons sont dans la liste alpha et ne sont PAS comptés), et **au LOD que le moteur a choisi** — les GLB importés portent des LOD automatiques, et à 11,7 u de caméra le moteur en sert un plus grossier |
| `lod0 cadre` (replay AABB × frustum, LOD0, × instances) | **102 803** | ce que ce script demande au GPU si aucun LOD ne s'applique : le même test de culling que Godot (`AABB::intersects_convex_shape`), toutes listes |
| `scene` | 175 559 | le chiffre de tous les tableaux précédents de ce journal |
| draw calls moteur / objets | 138 / 138 | contre 132 nœuds en cadre par le replay (les 6 de plus : Label3D des portails et le sol, hors du replay) |

**Conséquence pour le plafond de 50 000** : la frame réelle au spawn est à ~52 k primitives opaques rendues, soit au plafond — pas à 175 k. Le débat « justifier ou invalider le plafond » doit se tenir sur la ligne `gpu` (celle que le device affichera), avec `lod0 cadre` comme borne haute. Le chiffre sandbox (12 FPS sous llvmpipe 1080×1920) n'est PAS le chiffre device ; l'overlay existe pour que Mathieu lise le vrai au réveil.

**Preuve sur le service** : voir le tableau de preuves en fin de section P1 (une seule lecture Vercel par checkpoint, jamais de polling).

## Checkpoint P1 — transport : la ligne « Or » et le Sautillon (06:57 UTC)

**Preuve du P0 sur le service** : déploiement CI `dpl_ALhhH9wzqp2CVNkxy1QkcLwoSwhU` (`gitRootDirectory = build/web`, sha `a977e23`, `READY`, 06:26:50 UTC) ; `GET https://keepy-cozy.vercel.app/index.service.worker.js` à 07:00:27 → `x-vercel-cache: MISS`, `age: 0`, `CACHE_VERSION = 1788589585` (06:26:25 UTC, à l'intérieur de l'export de CE run). Le déploiement natif (branchAlias) coexiste, sans l'alias, sans effet.

**Ce qui est fait.**
- **Famille A — `HubTransport`** (nœud sous `World`, entre `Props` et `CozyScatter` pour que le scatter lise ses emprises) : docks (GLB `dock_0`, deck r 1,9 + marche), panneau-flèche `docksign_0` posé SUR LE CÔTÉ du deck et pointant le jumeau (une première pose côté jumeau était cachée derrière la montgolfière depuis cette caméra — capture `capture_v3_p1_dock.png`), fanion `BoxMesh` teinté à la couleur de la ligne, montgolfière `balloon_0` (396 tri, gores or/crème, nacelle, cordes). **Vol** : `tween_method` normalisé, horizontale en cosinus, verticale en plateau (`sin(πt)·1,45` clampé), vitesse 13 u/s + 2,4 s de montée/descente → 7,8 s pour 69,5 u ; tangage, lacet et dérive latérale ∝ `wind` du look météo ; le porté est écrit dans le MÊME appel que le porteur (`follow_carrier`), y compris à la frame d'arrivée. Montgolfière posée : bob de 6 cm et gîte ∝ vent en `_process`. **Croisière 4,0 u, mesurée et pas choisie** : à 5,2 u la capture de vol montrait une nacelle sous une corde, l'enveloppe entière hors cadre (rien n'est visible au-dessus de y ≈ 8 à l'aplomb de Keepy : rayon haut à +2,4° sur 8,9 u depuis 7,6 u) ; à 4,0 nacelle, jupe et moitié basse de l'enveloppe restent dans l'image, au-dessus de toute canopée sur la ligne (arbres du layout ×0,8 ≈ 4,5 u, haie et arbres d'automne ≈ 5 u ; plancher de nacelle à 4,16). Ça reste un compromis de caméra figée, pas une solution.
- **Portes** : `HubTapInput.tapped_balloon` (les DEUX docks d'une ligne, montgolfière présente ou non ; `accepts_balloon_tap` rend −1 pendant tout un trajet) et `tapped_vehicle` (le ballon garé ; retiré tant qu'il est monté). Tous deux lus sur `aim`, jamais sur la destination clampée. `HubWorld` : intention `_ballooning` (marche, puis `_try_balloon` à chaque atterrissage ET immédiatement), `_balloon_wait` (survit à `became_idle` : attendre EST être à l'arrêt ; annulé par tout autre tap), `_on_balloon_trip_finished` → `leave_carrier(_ride_exit_point(dock, 2,6))` — l'anneau de sortie du tourniquet, inchangé. Un tap pendant le vol est jeté dans `_on_tapped_ground` sur la licence tyrolienne (tween borné, atterrissage sur un dock connu). Re-amarrage : `HubTransport.update(here)` depuis `_process` de `HubWorld`, à côté de `_mooring.update`.
- **Famille B — le Sautillon** (`hopball_0`, 360 tri, garé à `(0,5 ; 4,4)`) : `KeepyHopper.mount_vehicle(node, lift)` / `dismount_vehicle()` — pas un état : `_begin_hop` prend 2,7 u / 1,15 u / 0,34 s au lieu de 1,5 / 0,6 / 0,28, `_apply_hop` et `_on_hop_finished` ajoutent `_vehicle_lift` (1,02) et écrivent le ballon sous lui avec son squash. **Les six entrées de state porté (`board`, `mount_turnstile`, `mount_seesaw`, `mount_owl`, `board_zipline`, `climb_board`) appellent `dismount_vehicle()` en première ligne** : aucun ride existant ne voit jamais le ballon. Tap sur soi à l'arrêt (< 0,9 u) = descendre ; re-parking sur la règle barque ; `_set_keepy_wet` ignoré tant qu'il est perché.
- **Emplacement du ballon, mesuré contre le cadre** : le premier candidat `(−6,5 ; 0,5)` (dégagement 2,17 u, à gauche du hibou) était **hors cadre au spawn** — à la profondeur de Keepy, l'image ne fait que ~7 u de large. `(0,5 ; 4,4)` est juste derrière lui, dans le bas du cadre (sol visible jusqu'à z ≈ 6,2), entre le chemin de la cabane et le nouveau chemin du dock.
- **Docks, mesurés au dégagement** (script Python sur le layout + lacs + chemins + ruisseau + repos des acteurs) : le plateau n'a AUCUN point à ≥ 2,6 u de dégagement qui soit à la fois près du spawn et dans le cadre au spawn — une montgolfière de 7 u posée devant un portail l'aurait occulté (la nacelle est PLUS PRÈS de la caméra que l'anneau). `(10,5 ; 14,5)` : dégagement 3,2 u, à 18 u au sud-est de la plaza, découvert en marchant ; `(11 ; −55)` : bord est de la clairière de l'Arbre-Mère (13 u du tronc, 3,5 u hors de la clairière). `CozyScatter._blocked` / `_autumn_blocked` lisent `HubTransport.footprints()` (r 2,9) ; un chemin de terre part de la plaza vers le dock.

**Preuves (headless, `--fixed-fps 60`, traces toutes les 30 frames).**

| test | résultat |
|---|---|
| `--at=10.5,11 --balloon=0` | monte à la frame 30 (y 0,36 = deck + siège + bob), croisière y 5,41 (avant le passage à 4,0), `is_on_carrier` vrai de 30 à 480, `balloon_at` −1 puis 1, dépose à `(11 ; 0 ; −58,45)` à la frame 510 (anneau de sortie, FORWARD = nord), montgolfière posée y 0,10-0,22 (bob) |
| `--at=0,0 --ball --walk=10,-3` | grimpe à la frame ~50 (y 1,02), 16,9 u en 150 frames (**7,35 u/s contre 5,36 à pied, ×1,4**), y 1,02 à l'arrêt, ballon sous lui à chaque échantillon |
| `--ride=auto` (barque, régression) | trace byte-identique à la v2 : monte à la frame 210 (`y 0,14`), débarque après 390 |
| `--at=-10,-10 --walk=-6,-56` (couloir, régression) | passe `(−26,7 ; −39,5)` à 420, arrive à 780 — identique à la v2 |

**Deux défauts de ma propre passe, trouvés par la trace et pas par relecture** : (1) `_on_hop_finished` n'avait PAS reçu le `+ _vehicle_lift` (le remplacement textuel a raté un commentaire entre les lignes) → Keepy à y = 0 sur le ballon à l'arrêt ; (2) `_begin_hop` n'avait pas reçu les constantes véhicule → 5,2 u/s « sur le ballon », soit la marche. Les deux visibles à la première trace, invisibles à la première relecture.

**Métriques** (`CozyCapture`, opengl3 sous xvfb, overlay P0).

| | P2 (v2) | **P1 (v3)** |
|---|---|---|
| triangles scène | 175 559 | **176 624** (+1 065 : 2 docks, 2 panneaux, montgolfière, ballon) |
| nœuds visuels | 336 | 343 |
| `gpu` au spawn | 52 472 | **52 648** |
| `lod0 cadre` au spawn | 102 803 | 102 430 |
| `gpu` au dock `(8 ; 20)` | — | 56 133 (181 calls) |
| `gpu` en vol au-dessus du grand lac | — | 37 473 (105 calls) |
| `gpu` au dock du vallon | — | 22 469 (31 calls) |
| `index.pck` | 31 025 904 | **31 201 888** (+176 Ko : 6 GLB transport + 14 GLB Provence déjà dans l'arbre) |

Sandbox : 12 FPS sous llvmpipe 1080×1920 — ce n'est pas le chiffre device.

**Captures** : `capture_v3_p1_dock.png` (dock Or depuis le sud), `capture_v3_p1_flight.png` (en vol à 4,0 u au-dessus du grand lac), `capture_v3_p1_spawn_ball.png` (le Sautillon derrière Keepy au spawn), `capture_v3_p1_hollow_dock.png` (arrivée au vallon).

**Non fait, assumé** : pas de son ; la montgolfière n'a pas de flamme ni d'ombre portée (l'ombre du héros suit, rétrécie, sur le sol — lisible comme la sienne) ; l'appel à vide n'a pas de « voyant » (le joueur voit la montgolfière venir, c'est l'indicateur) ; pas de PNJ aux stations.

## Checkpoint P2 — la troisième map : « la Lande aux Moulins », et la ligne « Ciel » (07:25 UTC)

**Direction, en cinq lignes.**
1. **Où** : au-delà du vallon, `z ∈ [−126 ; −86]`, `x ∈ [−38 ; 38]`, couloir `x ∈ [6 ; 18] × z ∈ [−86 ; −78]` à l'est de l'axe de l'Arbre-Mère. Même altitude, même navigation, région étendue de deux rectangles (`HubRegion.MOOR_*`), un trou pour le pied du moulin. **Nord encore, et pas à l'est** : mesuré sur la caméra, une zone latérale n'est JAMAIS dans le cadre avant qu'on y soit (±22,5° de demi-angle horizontal ; à z = −60 le bord du cadre est à x ≈ 28 depuis le spawn) — seule la bande haute de l'image, dans l'axe, peut « suggérer de loin ». Le vallon y était pour cette raison ; la lande est derrière lui.
2. **Quoi** : un registre PROVENCE — lande mauve (trois teintes `MOOR_A/B/C`), **champs de lavande en RANGS PEINTS DANS LE SOL** (trois rectangles `LAVENDER_FIELDS` partagés par le shader et le scatter, rayures violet/terre au pas de 2,4 u) avec des touffes 3D clairsemées SUR les rangs, cyprès sombres en files, oliviers, murets de pierre sèche au bord des champs, roches blanchies, un puits et quatre ruches au coude de la route. Contraste de TEINTE avec le plateau (vert) ET le vallon (orange) : violet / crème / vert-noir.
3. **Repère** : **le moulin** `(14 ; −106)` — tour blanche 7,5 u + toit rouge, quatre ailes de 4,6 u (GLB séparé `sails_0`, tournées en `_process` à 0,35 rad/s × (0,6 + 0,4 × `wind` météo) : elles tournent plus vite dans l'orage). Depuis la clairière de l'Arbre-Mère, il est dans l'axe de la route, au-dessus de la trouée de la haie (`capture_v3_p2_from_hollow.png`) ; depuis le spawn, une silhouette blanche à 87 % de haze, à droite de l'Arbre-Mère (`capture_v3_p2_spawn.png`) — « suggéré », pas plus, et c'est tout ce que cette caméra permet.
4. **Accès** : la route (`MOOR_ROAD`, Catmull-Rom, même extrusion) contourne la clairière par l'est, franchit le couloir, passe le hameau et finit au pied du moulin. **Navigation à deux portes** : `_hop_via_corridor` est généralisé — `HubRegion.zone_of()` (0 plateau, 1 vallon, 2 lande), `_gates_between(a, b)` rend la liste ordonnée des portes de la chaîne 0–1–2, `_via_queue` les enchaîne sur `became_idle`. Mesuré (headless, `--walk=0,-108` depuis le spawn) : porte 1 `(−27,5 ; −37,8)` à la frame 540, porte 2 `(11 ; −84)` à 1260, arrivée `(0,06 ; −107,9)` à 1620 — 27 s de marche, contre ~17 s par Or + marche + Ciel.
5. **Desserte** : ligne « Ciel » (`balloon_1`, bleu/crème) `(−14 ; −50)` à l'ouest de la clairière → `(−6 ; −110)` aux champs de l'ouest. Prouvée : monte à la frame 30, croisière 4,21 u, `(−10,8 ; 4,2 ; −73,7)` à la frame 210 (`capture_v3_p2_ciel_flight.png` — la haie d'automne dessous, les rangs violets devant).

**La haie n° 2** (bande `z ∈ [−85,5 ; −80,5]`, hors couloir ± 1,5 u) : automne côté vallon, cyprès/olivier côté lande (36 arbres). Le mur de forêt descend à `z = −140` et devient cyprès/olivier en bande proche sous `z < −84` ; les collines du secteur `z < −95` reculent à `r ≥ 168`.

**⚠️ Le coût, mesuré par l'overlay, et ce qui a été coupé.**

| frame au spawn (`gpu`) | valeur |
|---|---|
| P1 (avant la lande) | 52 648 |
| lande brute | **103 283** (+50 k, pour des pixels dissous à 87 % par le haze — la lande est dans l'axe de la caméra, à 95+ u) |
| + `visibility_range_end` sur tous les batches du scatter sauf mur et haies (82 u ; 95 u pour les familles d'automne, parce que la bande orange derrière les lacs fait partie du cadre du spawn par conception v2), `visibility_range_fade_mode = DISABLED` (culling CPU pur, fonctionne en Compatibility) | 79 555 |
| + mur lointain de la lande en `tree_6_far` (72 tri) au lieu de `cypress_1` (140), `WALL_FAR_Z` −150 → −140 | **65 005** |

Reste +12 k au spawn contre P1 : la bande proche du mur (195 arbres, cyprès/oliviers à 140-164 tri) et la haie n° 2 — c'est l'horizon, il est gardé. Première version de la bordure : des taches de litière d'automne jusqu'à 8 u DANS la lande (`autumn` = 1 partout sous z < −46, et le fondu `moor` ondulait de ± 4,5 u) → bord `−82` / largeur 3 / ondulation ± 2,5 (`capture_v3_p2_hamlet.png` après).

**Autres frames** (`gpu` / calls) : hameau `(6 ; −90)` 42 909 / 35 ; champs `(−20 ; −90)` 55 103 / 39 ; clairière vers le nord `(8 ; −64)` 64 175 / 69 ; en vol Ciel 57 934 / 47. Scène entière **235 852** (+59 k sur P1 — le mur étendu et la lande ; la frame ne les voit jamais tous). `index.pck` : **31202048** (export local ; +160 octets sur P1 pour 14 GLB Provence déjà comptés, donc surtout les 3 lavandes refaites et les captures ne comptent pas — `docs/*` est exclu).

**Assets** : famille Blender `provence.py` (planche `docs/carte_blanche/provence_sheet.png`) — 14 GLB de 20 à 252 tri, 3 à 19 Ko. Deux pièges payés dans le script : une boucle géométrique sur le rayon des étages du cyprès qui ne convergeait jamais vers la hauteur demandée (processus infini, tué par PID — `pkill -f` a tué mon propre shell deux fois, exactement comme CLAUDE.md le dit), et une tour de moulin ROUGE parce que le sommet de son cylindre à deux anneaux partageait le y de l'anneau du toit : la couleur interpolait sur toute la hauteur. Lavande refaite à 124-176 tri (monticule subdiv 0, 4-6 épis) parce que 126 touffes à 300 tri auraient coûté 38 k.

**Non fait, assumé** : pas de PNJ dans la lande ; pas de son du moulin ; les touffes de lavande lisent comme des galettes vertes à épis (les rangs peints font le travail de loin, les touffes sont à repeindre en gris-mauve) ; la lande n'a pas de point d'eau (choix : le contraste avec les cinq eaux du plateau).

## RÉCOLTE v3 — ce qui mérite un lot cadré vers `staging`, ce qui est à jeter, et ce que je rejouerais EN PREMIER

**Ce que je rejouerais EN PREMIER de toute la branche v1 + v2 + v3 : l'overlay de performance (P0).** Ce n'est pas le plus beau, c'est le seul lot qui rend les autres DÉCIDABLES : il a déjà réfuté un chiffre de ce journal (175 k « triangles scène » sont 52 k primitives rendues, LOD compris), attrapé un +50 k invisible dès la première frame de la lande, et il mettra le vrai FPS iPhone sous les yeux de Mathieu au réveil. ~200 lignes, zéro dépendance, gaté par hostname ; sa seule dette est le message d'aide (« gpu / lod0 / scene ») à documenter dans le menu. **Lot cadré : ajouter la ligne au `docs/PROBE_AUDIT.md` et faire de `gpu` le chiffre du plafond.**

**À rejouer proprement, par ordre de valeur / risque.**
1. **L'overlay** (ci-dessus).
2. **`ON_CARRIER` + `HubTransport` (montgolfières)** : ~450 lignes additives, aucune modification des rides existants (les six entrées de state appellent seulement `dismount_vehicle()`), portes sur le patron barque, trajets bornés. Lot cadré : une seule ligne d'abord, preuve device des trois gestes (embarquer / appeler / tap pendant le vol jeté), PUIS le re-amarrage hors cadre. À régler sur device : `CRUISE_HEIGHT` (4,0 est un compromis de caméra figée), `FLIGHT_SPEED` 13, et le rayon de tap 2,6.
3. **Le Sautillon (véhicule)** : 90 lignes dans `KeepyHopper`, le modificateur le plus simple possible et le plus amusant à l'écran. Risque réel : l'interaction avec `_on_hop_landed` (portails, tourniquet, balançoire) n'est prouvée que par les traces des rides existants, pas par un tour complet sur device. À prouver en premier sur iPhone : descendre par un tap sur soi, monter un tourniquet depuis le ballon (il doit rester au sol).
4. **La navigation à N portes** (`zone_of`, `_gates_between`, `_via_queue`) : 40 lignes, remplace le pansement v2. Mais c'est toujours une chaîne 0–1–2 : la quatrième zone hors chaîne exige `HubRegion.route(a, b)`.
5. **La lande** : shader (masque + rangs peints : gratuit et c'est ce qui fait le champ), famille `provence.py`, `_moor()` ; le poste cher est le mur étendu. **Le `visibility_range_end` sur les batches du scatter est à garder même sans la lande** : il vaut sur le plateau vu depuis le vallon.

**À jeter ou à refaire autrement.**
- **L'appel à vide** de la montgolfière : correct mais sans feedback (le joueur attend 8 s sans rien à l'écran s'il regarde ailleurs). Une vraie version anime le fanion ou fait sonner une cloche au dock.
- **Le panneau-flèche** : 38 tri, lisible en capture, jamais prouvé lisible sur iPhone à cette distance de caméra. Si Mathieu ne le voit pas, la couleur des fanions doit porter seule la lecture « où ça mène ».
- **Les touffes de lavande 3D** : à repeindre (monticule gris-mauve) ou à retirer au profit des rangs peints seuls.
- **`CozyCapture`** a encore grossi (`--balloon`, `--ball`) : c'est définitivement une sonde de nuit ; à découper en trois sondes gatées (capture, ride, nav) ou à supprimer avec la branche.
- **Doctrine à consigner si un lot cadré passe** (CLAUDE.md non touché ici) : (a) `viewport_get_render_info` ne compte que la liste OPAQUE et applique les LOD auto des GLB importés — c'est LE chiffre du plafond, pas le compte de scène ; (b) à la profondeur de Keepy le cadre fait ~7 u de large et rien au-dessus de y ≈ 8 à son aplomb n'est visible — tout prop « près du spawn » ou « porté en l'air » se vérifie par `unproject_position` avant d'être placé ; (c) `visibility_range_end` fonctionne en Compatibility comme culling CPU et coupe ce que le haze a déjà effacé ; (d) `pkill -f` / `pgrep -f` tuent le shell qui les lance dès que le motif apparaît dans le heredoc de la même commande — tuer par PID lu dans `ps`.

## Preuves de déploiement v3 sur le service (une lecture par checkpoint, jamais de polling)

| checkpoint | sha | `CACHE_VERSION` servi (epoch → UTC) | lecture |
|---|---|---|---|
| P0 | `a977e23` (push 06:22:07) | `1788589585` → 06:26:25 | 07:00:27, `x-vercel-cache: MISS`, `age: 0` ; déploiement `dpl_ALhhH9wzqp2CVNkxy1QkcLwoSwhU`, `gitRootDirectory = build/web`, `READY` |
| P1 | `691f604` (push 06:57:47) | `1788591792` → 07:03:12 | 07:12:01, `MISS`, `age: 0` |
| P2 | `a848cbf` (push 07:06:58) | `1788592296` → 07:11:36 | 07:15:36, `MISS`, `age: 0` |

Une lecture intermédiaire (07:03:23) est venue en `HIT` avec `age: 176` — c'était ma propre lecture précédente figée en bord, écartée comme mesure (doctrine CLAUDE.md). Chaque `CACHE_VERSION` tombe à l'intérieur de la fenêtre d'export du run de SON push.
