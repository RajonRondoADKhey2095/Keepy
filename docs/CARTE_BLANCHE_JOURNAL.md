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
