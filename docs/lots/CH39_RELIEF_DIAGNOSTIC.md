# CH39 — Le relief disparaît quand Keepy marche dessus : diagnostic, puis cause (7 septembre 2026)

> Fichier de chantier créé par le lot CH39. Le lot CH38 (lot 2 partie A,
> `docs/lots/CH38_MONTAGNE_RELIEF.md`) a livré la crête ouest **et
> `MountainProbe` ALL GREEN, 0 rouge, sur 7 phases**. Le relief était
> pourtant invisible dès qu'on marchait dessus. Ce lot est un
> **diagnostic** : rien n'a été corrigé avant que la cause soit prouvée à
> variable unique.

## CH39-1 — Le symptôme, reproduit avant d'être expliqué

Base : `origin/staging` `60eaa9a`, arbre `4fab084` vérifié par
`git rev-parse ^{tree}`, **pas par nom**. `git fetch --all --prune` **au
début**. `origin/claude/keepy-mountain-terrain-lot2-l73mst` porte l'arbre
`4fab084`, **exactement celui de `staging`** : c'est CH38 déjà mergé, pas
une session concurrente. `main` est en avance d'un commit CI qui ne touche
aucune ressource Godot.

Rapport device de Mathieu (iPhone, Safari, staging, build
`1788777694|6177421`), deux stations, l'overlay `?keepydev=1` :

| station | ce qu'il voit | FPS | TRI gpu |
|---|---|---|---|
| A = (−46,4 ; 13,0) | un dôme net, découpé contre les arbres | 56 | 44 043 |
| B = (−50,4 ; 5,8) | **plus aucun relief**, sol parfaitement plat | 58 | 38 057 |

⚠️ **L'overlay n'affiche PAS le `y`** (`HubPerfOverlay._format` écrit
`POS x %.1f z %.1f zone %d`). « Je n'étais pas en hauteur » est donc une
**impression visuelle**, pas une lecture — c'est-à-dire le symptôme
lui-même, à traiter comme une hypothèse et non comme une donnée.

La sandbox reproduit les deux images **à l'identique** (rendus offscreen
1080×1920, caméra figée du jeu, `xvfb-run --rendering-driver opengl3`,
Keepy posé aux deux coordonnées exactes) : dôme à la station A, champ
plat à la station B. Le diagnostic porte donc sur le vrai défaut.

## CH39-2 — Les cinq hypothèses du brief, chacune tranchée par une mesure

Sonde de recon jetable `RidgeVisibilityRecon` (9 phases), **supprimée
avant le commit** conformément à la doctrine ; ses chiffres vivent ici.

| # | hypothèse | verdict | la preuve |
|---|---|---|---|
| 1 | culling du `MeshInstance3D` | **CONFIRMÉE — mais pas celui-là** | pas de frustum, pas d'AABB : `visible_in_tree` vrai, `custom_aabb` nulle, `extra_cull_margin` 0,000, transform identité. C'est le **test de face** ; voir CH39-3 |
| 2 | incohérence mesh / `height_at` | **ÉCARTÉE** | chute de rayon Möller–Trumbore sur les **triangles dessinés** (instrument indépendant de `_sample`), 51 points : écart pire **0,000007933 u**. Aux deux stations, dessiné = requête au chiffre près (0,7164 et 3,9484) |
| 3 | le plan y = 0 passe devant | **ÉCARTÉE** | masquer le `PlaneMesh` 600×600 change le compte de pixels de la crête de **rien du tout** : 13 898 → 13 898 (A), 14 → 14 (B) |
| 4 | le mesh n'est pas où le domaine le déclare | **ÉCARTÉE** | sommets en **monde** : x [−63,000 ; −35,000], y [0,000 ; 4,500], z [−12,000 ; 18,000] — identiques à `MOUNTAIN_MIN/MAX`. 0 sommet sous y = 0 |
| 5 | Keepy marche à y = 0 | **ÉCARTÉE** | **marché**, pas téléporté : atterri à (−46,4000 ; **0,7164** ; 13,0000) et (−50,4000 ; **3,9484** ; 5,8000). Mathieu était bien à **3,95 u de haut** |

⚠️ **Et la caméra suivait.** `HubCamera._wanted()` rend
`HubSurface.ground(target) + OFFSET` : l'œil était à **7,600 u au-dessus
du sol local aux DEUX stations**. Le cadre est ancré à la surface, donc
monter la colline ne change rien à la façon dont le sol rencontre l'image
— ce qui explique qu'un joueur à 3,95 u de haut ne le sente pas.

## CH39-3 — LA CAUSE, prouvée à variable unique : le maillage est enroulé à l'envers

PHASE 8 avait éliminé le sur-dessin. Entre un triangle soumis et un
fragment, il ne reste que le **test de face**. Deux rendus du même cadre,
même station, même caméra, **un seul jeton de différence** dans le shader
d'identification — `cull_back` contre `cull_disabled` :

| station | `cull_back` | `cull_disabled` | rapport |
|---|---|---|---|
| A (−46,4 ; 13,0) | 13 898 px | 315 181 px | **× 22,7** |
| B (−50,4 ; 5,8) | **14 px** | 317 646 px | **× 22 689** |

**Godot tient les faces HORAIRES-À-L'ÉCRAN pour faces AVANT.** Un triangle
de treillis dont le produit vectoriel main droite pointe vers +Y se lit
**anti-horaire depuis n'importe quelle caméra au-dessus** : c'est la face
ARRIÈRE, et `cull_back` la jette. `HubMountain.build_mesh()` émettait
`(a, cc, b)` puis `(b, cc, d)` — exactement cet enroulement-là.

Les seuls survivants étaient les triangles tournés **DOS à l'œil** : le
flanc lointain, vu **à travers** le flanc proche invisible. De trente
unités, ça ressemble à un dôme propre ; debout dessus, ça ne ressemble à
rien. **Le « dôme net découpé contre les arbres » de la station A était
l'arrière de la colline vu par transparence.**

Correctif : `(a, b, cc)` puis `(b, d, cc)`. Le produit vectoriel main
droite d'une surface marchable vaut donc **−Y** ici, et ce n'est pas une
convention de signe à ranger : c'est celle du moteur.

Après correctif, aux deux mêmes stations : `cull_back` = `cull_disabled`
(× 1,0), la crête possède **60,8 %** et **61,3 %** du cadre, et masquer le
nœud change **51,8 %** / **59,2 %** de l'image (contre 3,74 % / 0,54 %
avant). Les rendus le montrent : à la station B la crête bascule
visiblement et le plateau lointain apparaît derrière ; à la station A le
flanc proche est enfin dessiné et Keepy se tient dessus.

⚠️ **Ce n'est pas un défaut de `HubSurface` (CH37).** Le socle n'a pas
bougé : sa requête était juste à 8 × 10⁻⁶ u près, sa registration juste,
son raccord C0 juste. Le défaut est dans le **constructeur de maillage**
de CH38, et il n'existe nulle part ailleurs — `add_surface_from_arrays`
n'apparaît qu'une fois dans tout le code de jeu.

## CH39-4 — Pourquoi `MountainProbe` était verte : le DIXIÈME faux-vert, et ses cinq mécanismes

Aucune des 7 phases ne lisait un **pixel**. Chacune était verte pour sa
propre raison, et c'est l'empilement qui rend le cas instructif :

* **PHASE C — l'assertion d'enroulement était ÉCRITE À L'ENVERS, et son
  propre commentaire disait le contraire.** Le commentaire nommait la
  règle du moteur (« Godot takes CLOCKWISE faces for FRONT faces ») ; le
  code exigeait `n.y > 0` avec `n = (b−a) × (c−a)`, c'est-à-dire la
  convention **MATHÉMATIQUE** du « haut », qui est la **négation exacte**
  de la règle citée. Verte **1 680 fois sur 1 680** sur une colline
  entièrement jetée.
* **PHASE D** — « la ligne œil-sommet dégage le terrain » raycaste
  `height_at`, donc la **grille**. Une requête ne sait rien du côté d'un
  triangle qui fait face à l'œil.
* **PHASE E** — `VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME` compte les
  primitives **SOUMISES**. Le back-face culling est **en aval** de ce
  compteur : la colline coûtait ses 1 680 triangles à chaque frame et
  n'en dessinait aucun. La ligne « and the ridge DOES cost something (a 0
  would mean it never drew) » était **vraie et signifiait le contraire**
  de ce qu'on y lisait.
* **PHASE F** — marche la surface, donc la grille encore.
* **PHASE BLIND** — prouvait que `height_at` sait répondre 0, ce qui est
  une propriété de la **requête**, pas du rendu.

**Le mécanisme à nommer n'est pas « il manquait une assertion ».** C'est
qu'un lot entier a gaté un objet **VISUEL** sur de la géométrie et un
compteur, et qu'aucun des deux ne peut distinguer une surface dessinée
d'une surface soumise puis jetée.

### PHASE G, et pourquoi elle n'est pas un seuil de pixels

Ajoutée à `MountainProbe`. Elle rend la crête par une **passe
d'identification** (magenta plat, `fog_disabled`, un pixel appartient à la
crête **ssi** il revient exactement (255, 0, 255) — un masque, jamais une
fenêtre), et elle gate sur :

1. **BLIND d'abord** : crête masquée, le compteur doit lire **0**. Une
   assertion de présence ne vaut rien tant que l'instrument n'a pas été
   vu répondre zéro.
2. **Couverture** : ≥ 10 % du cadre depuis une station debout dessus
   (mesuré 60,40 % et 20,71 % ; l'enroulement cassé donnait **0,00 %** et
   **0,70 %**).
3. **LE VRAI GATE — le test de face ne jette RIEN** : `cull_back` et
   `cull_disabled` doivent couvrir les mêmes pixels à 1 % près. **Aucun
   seuil à régler**, valable à toute station sur toute forme, et il tombe
   bruyamment sur un maillage retourné : mesuré **100,00 %** et **96,64 %**
   de rejet avec l'enroulement livré.

**Rouge avant vert** : enroulement d'origine remis, la sonde sort
**5 rouges — PHASE C (1 680/1 680) et les 4 de PHASE G — et aucun autre**,
les deux assertions BLIND restant vertes. Fichier restauré et vérifié
**byte-identique** (`cmp`). Avec le correctif : **ALL GREEN — 0 red**, run
complet, PHASE F comprise, et le banc reproduit la diagonale publiée à
**18,700 s** exactement.

## CH39-5 — Ce que le diagnostic a trouvé sans le corriger

* **La crête est CHAUVE.** `CozyScatter.COVER_MIN/MAX` vaut
  x ∈ [−37 ; 37] ; le domaine est x ∈ [−63 ; −35]. Le recouvrement fait
  **2 u** au bord est. Mesuré : **21 instances** dans le rectangle, **0**
  enterrée (elles sont toutes là où h ≈ 0). Il n'y a donc ni touffe, ni
  fleur, ni caillou sur la colline — aucun objet dont la taille,
  l'occultation ou la parallaxe puisse dire « ce sol est incliné ». C'est
  la **PARTIE B**, pas ce lot.
* **Le matériau ne porte aucun signal de pente, et c'est structurel.**
  `cozy_ground.gdshader` est `unshaded` et écrit `ALBEDO` depuis
  `world_pos.xz` et `length(view_pos)` **seulement** — ni `NORMAL`, ni
  `world_pos.y` dans son `fragment()`. Corrélation de Pearson mesurée,
  après correctif, entre la pente sous un pixel et la luminance livrée :
  **r = +0,098 (r² = 0,010)** à la station A, **r = −0,342 (r² = 0,117)**
  à la station B — le résidu vient du terme de brume, pas d'un ombrage.
  Le relief lit donc par **silhouette et occultation**, exactement comme
  CH35-C l'avait posé. Ce n'est pas un défaut à corriger ici ; c'est la
  contrainte sous laquelle la partie B devra composer.
* **Le maillage n'a ni `ARRAY_NORMAL` ni `ARRAY_TEX_UV`.** Sans
  conséquence sous un matériau unlit, et laissé tel quel : le corriger
  serait du payload pour rien. À rouvrir le jour où une surface de sol
  cesse d'être unlit.

## Suite

Le relief est maintenant réellement dessiné et réellement marchable.
**Partie B (semis, props, atmosphère) seulement une fois que Mathieu a
confirmé le relief sur device** ; lot 3 véhicule sur surface ; lot 4 luge.
