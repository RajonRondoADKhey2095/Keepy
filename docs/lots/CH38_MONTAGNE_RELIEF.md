# CH38 — Zone montagne, LOT 2 PARTIE A : le relief nu (7 septembre 2026)

> Fichier de chantier créé par le lot CH38. Le lot 1 SURFACE
> (`docs/lots/CH37_SURFACE.md`) avait publié `HubSurface` **sans aucun
> domaine enregistré en jeu** — un no-op arithmétique. Ce lot enregistre
> le **premier domaine réel**, et rien d'autre : pas un semis, pas un
> prop, pas une goutte d'eau, pas un critter, pas un transport.

## CH38-1 — LOT 2 PARTIE A : la crête ouest

Base : `origin/staging` `24bbb19`, arbre `857fb20` vérifié par
`git rev-parse ^{tree}` — **pas par nom**, la collision s'est reproduite
quatre fois dans ce dépôt. `git fetch origin` **au début**, pas à la fin :
`origin/claude/keepy-mountain-terrain-lot2-l73mst` portait l'arbre de
`main` (`8f4dc2e`), c'est-à-dire de l'historique déjà mergé et **rien de
ce lot** ; la branche a donc été repartie de `staging`, qui porte CH37
dont ce lot dépend. `main` n'est en avance que d'un commit CI
(`08229cc`, workflow d'audit Vercel), qui ne touche aucune ressource
Godot. Éditeur Godot 4.3 provisionné en session (50 276 070 o =
`Content-Length` annoncé), templates d'export 1 073 228 327 o **vérifiés
contre le `Content-Length` avant extraction** — le premier téléchargement
était sorti à **0 octet avec un exit 0 et un code HTTP 302** (`curl` sans
`-L`), exactement la forme du piège documenté.

### L'emplacement, et pourquoi celui-là

La direction est de Mathieu : « au-delà des arbres visibles depuis
(x = −34,6 ; z = 35,0) », relevé d'overlay au coin nord-ouest du plateau.
La caméra ne tourne jamais (`HubCamera.OFFSET`), donc depuis cette station
l'œil descend le flanc ouest en −z, et ce qui ferme la vue est le mur de
forêt que `CozyScatter` plante **hors région**.

Le brief demandait un espace *réellement* libre, pas un rectangle prêt à
coller. Les huit dégagements ont été **mesurés sur le layout et les
constantes livrées**, pas supposés :

| ce qu'il faut éviter | où c'est | marge |
|---|---|---|
| props du layout | l'entrée la plus à l'ouest est **x = −34,9** | le domaine commence à −35 : **il ne porte aucun prop** |
| berge du petit lac | (−25,1 ; −5,3), `LAKE_BANK_RADIUS` 9,05 → x = −34,15 | **0,85 u** (la plus serrée) |
| lobe spawn-lake | x ∈ [−22, −2] | hors de portée |
| grand lac | x ∈ [−0,5 ; 31,5] | hors de portée |
| bande palette automne | z ∈ [−46, −32] (`AUTUMN_EDGE_Z ± _W`) | le domaine s'arrête à z = −12 : **20 u** |
| lande / circuit / crique | z ≤ −79, ou x ≥ 41 | hors de portée |
| champs de lavande | x ∈ [−32, −8] et [22, 36] | hors de portée |
| AABB de zones | automne est x ∈ [−33, 33] — le domaine est à l'**OUEST** | disjoint |
| lobe nord et lobe de structure | (0 ; 35) r 12 et (25,2 ; 35) r 3 | tous deux à l'est de x = −12 |
| anneau de collines décor | `CozyScatter._hills` tire à r ∈ [78, 176] | coin le plus loin : r = **65,5** |

**AABB retenue : x ∈ [−63, −35], z ∈ [−12, 18]**, soit 28 × 30 u.
Son bord EST **est** le bord ouest du plateau (x = −35). Ce n'est pas une
coïncidence à ranger plus tard : la hauteur au périmètre est **exactement
0**, donc une marche franchit x = −35 **sans la moindre marche**, et la
crête n'a besoin ni de porte, ni de couloir, ni de numéro de zone —
`zone_of` continue de répondre 0.

Depuis la station de Mathieu, le sommet est à **32 u devant et 14,4 u de
côté**, pour un cadre large de `0,414 × (D + 8,9) = 16,9 u` à cette
distance : **dans le cadre**, et derrière la ligne d'arbres qu'il
regardait — la composition que la direction demandait.

### ⚠️ Ce que le lot déplace sans l'avoir écrit

`CozyScatter._forest_wall` refuse tout candidat dont
`HubRegion.contains()` est vrai. Rendre ce rectangle marchable **retire
donc les arbres du mur qui s'y trouvaient** et pousse les autres à 2 u
(`WALL_CLEARANCE`) de son bord. **Aucune ligne de `CozyScatter` n'a
changé** ; c'est la région qu'il lit qui a changé. À l'ouest de x = −63 la
boîte du mur s'arrête de toute façon à `WALL_OUTER = 62`, si bien que la
crête ouest se découpe sur le **ciel** et sur l'anneau de collines
lointain — ce qui est le « crête contre un fond » que CH35-C réclame, et
non un mur de vert.

### La largeur est fixée par la TRAVERSÉE, pas par le relief

Le hub se tient à **22 s** de coin à coin (le balayage de l'en-tête de
`HubRegion` : demi-extension 40 coûte 21,533 s, 41 coûte 22,100 s et a été
refusée). La diagonale livrée, (−35, −35) → (35, 35), vaut 98,995 u pour
66 hops / 18,700 s, soit **0,18890 s/u**.

Un rectangle boulonné sur un BORD **allonge** la pire paire — à la
différence d'un lobe centré SUR un bord, dont l'en-tête de `HubRegion`
explique qu'il n'allonge aucune diagonale entre coins. Les deux nouvelles
paires ont donc été chiffrées **avant** que la forme soit dessinée :

| paire | distance | ~secondes |
|---|---|---|
| (35, 35) → (−63, −12) | 108,69 u | 20,53 s |
| (35, −35) → (−63, 18) | 111,41 u | **21,05 s** |

`x = −63` est le bord ouest le plus lointain qui garde les deux sous 22 s
avec de la marge. Une première version à x = −71 a été abandonnée sur ce
seul calcul, et c'est elle qui a fixé la hauteur du relief — voir plus
bas. ⚠️ **Cet abandon a été VÉRIFIÉ par la mesure, pas laissé au
calcul** : la passe rouge-avant-vert qui réélargit le rectangle à x = −71
fait **marcher** cette paire au hopper et sort à **22,383 s**, rouge, au
même endroit que le calcul l'annonçait.

⚠️ **Un rapport n'est pas une mesure.** `MountainProbe` PHASE F **marche**
la paire sur le vrai hopper, et marche la diagonale livrée dans le même
run comme témoin : un banc incapable de restituer un chiffre déjà au
dossier n'a pas qualité à en publier un neuf.

### La forme, et les quatre nombres qui la bornent

CH35-C a mesuré ce qu'un sol **UNLIT** peut dire d'une pente : rien. Il n'y
a aucun ombrage sur un flanc, donc un versant n'a pas d'indice propre et ne
se lit que comme une silhouette contre quelque chose de plus lointain.
D'où une COLLINE et pas un pic :

* **pente marchable ≤ 30°** — mesurée sur les **triangles dessinés**, pas
  sur la fonction analytique : **27,834° au pire**, à (−53,3 ; −2,3) ;
* **point le plus haut 4,500 u**, sous les 9 u qu'un pied à 30 u peut
  encore voir (CH36 `FRAME_TOP_AT_APLOMB` = 7,968 : un sommet plus haut
  sort du cadre d'une caméra qui ne s'incline jamais) ;
* **rien de non marchable sur ce domaine** — donc ni le régime « flancs
  courts ≤ 45° » ni le plafond « 55° avec `cozy_ground` » n'ont d'objet
  ici ; il n'y a pas de second régime à gater ;
* **périmètre exactement 0** — les deux bosses sont des **cosinus
  surélevés à SUPPORT COMPACT** contenus dans l'AABB : valeur *et* dérivée
  première nulles à r = R, donc le raccord est **C1** et pas seulement le
  C0 que `register_domain` exige. Une gaussienne aurait demandé un terme
  de fenêtrage, et ce terme est lui-même une pente que personne n'a
  demandée.

Le plafond de pente est ce qui **cape la hauteur** : un cosinus surélevé
de rayon R et de hauteur A culmine à `A·π/(2R)`, donc R = 14 et 30°
admettent A ≤ 5,15, et 4,5 laisse la marge que la sonde gate.

⚠️ **DEUX BOSSES QUI SE RECOUVRENT ADDITIONNENT LEURS GRADIENTS**, et
c'est ce qui a coûté trois itérations. Chaque version qui posait une
petite bosse de 1,5 u **dans le flanc** de la grande a mesuré **33,0°** —
au-dessus du plafond, alors que chaque bosse prise seule était largement
en dessous (23° et 17°). La seconde bosse a donc été écartée à **12,04 u**
du sommet principal : une silhouette à deux sommets valait une entrée de
plus, elle ne valait pas de dépenser le budget de pente dans le
recouvrement.

| bosse | centre | rayon | hauteur |
|---|---|---|---|
| principale | (−49 ; 3) | 14 | 4,5 |
| épaulement | (−57 ; 12) | 6 | 1,4 |

### Le maillage EST la requête

La grille est remplie **une fois** par `HubMountain.height()`, puis cette
grille est la seule chose que qui que ce soit lit : `HubSurface`
l'échantillonne, et `_build_mesh` écrit le **même réseau** avec la **même
triangulation** — diagonale b-c, coins de cellule a(0,0) b(1,0) c(0,1)
d(1,1), soit les triangles (a, c, b) et (b, c, d). Les pieds de Keepy sont
donc sur le triangle **dessiné**, pas sur une surface analytique que le
triangle approcherait. Le mesh est construit **depuis la grille
enregistrée**, relue dans `HubSurface` — pas depuis un second appel à
`height()` : si les deux divergeaient un jour, il faudrait qu'ils
divergent sur le même tableau.

⚠️ **ENROULEMENT HORAIRE VU DE DESSUS**, écrit noir sur blanc parce que ce
dépôt a déjà perdu un ruban entier sur l'autre choix : Godot tient les
faces horaires pour faces **avant** et `cozy_ground.gdshader` est
`cull_back`. `MountainProbe` PHASE C lit la normale de **chaque** triangle
plutôt que de croire ce paragraphe — 0 sur 1 680 enroulé à l'envers.

**Matériau : `CozyPalette.ground_material()`**, la même famille que le sol
plat. Il n'ombre que depuis la **position monde**, donc là où la crête est
à h = 0 elle peint exactement ce que peint le plan sous elle : le liseré
coplanaire est **invisible** au lieu d'être un z-fight.

### Maille 1,0 u — et pourquoi pas plus fin

Le sol est **unlit** : une facette n'a aucune arête d'ombrage pour se
trahir, et la seule chose qu'une maille plus fine achète est de la
résolution de **silhouette**. 28 × 30 u à 1,0 u font **1 680 triangles**,
un sixième des 10 000 que ce lot s'autorise — le reste est gardé en marge
plutôt que dépensé en facettes qu'aucun renderer d'ici ne peut montrer.

### Le budget triangles, gaté DÈS LE PREMIER COMMIT

Doctrine CH35-B Q7 : un plafond ajouté après coup ne défend rien. Celui-ci
est dans `HubMountain.TRIANGLE_BUDGET` depuis le commit qui crée le
fichier, et `MountainProbe` PHASE E le gate.

La mesure est un **delta**, obtenu en **cachant la crête et en relisant la
MÊME frame** — c'est exactement la question que le plafond pose (« que
coûte le relief nu »). La ligne lue est `engine_prims`, c'est-à-dire
`VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME` : la liste **OPAQUE au LOD que
le moteur a choisi**, celle qu'un device paiera — CH23 a établi qu'un
plafond gaté sur une autre des trois lignes ne défend rien.

**8 stations × 2 hauteurs de caméra, xvfb + `opengl3`, viewport
1080 × 1920 :**

| station | caméra | avec | sans | delta |
|---|---|---|---|---|
| (−38,0 ; 3,0) | plate | 49 647 | 47 967 | **+1 680** |
| (−41,2 ; 10,8) | plate | 49 439 | 47 759 | +1 680 |
| (−49,0 ; 14,0) | plate | 40 087 | 38 407 | +1 680 |
| (−56,8 ; 10,8) | plate | 34 994 | 33 314 | +1 680 |
| (−60,0 ; 3,0) | plate | 32 477 | 30 797 | +1 680 |
| (−56,8 ; −4,8) | plate | 33 849 | 32 169 | +1 680 |
| (−49,0 ; −8,0) | plate | 36 193 | 34 513 | +1 680 |
| (−41,2 ; −4,8) | plate | 41 481 | 39 801 | +1 680 |
| (−38,0 ; 3,0) | haute | 49 767 | 48 087 | +1 680 |
| (−41,2 ; 10,8) | haute | 49 649 | 47 905 | **+1 744** ← pire |
| (−49,0 ; 14,0) | haute | 41 277 | 39 597 | +1 680 |
| (−56,8 ; 10,8) | haute | 35 529 | 33 849 | +1 680 |
| (−60,0 ; 3,0) | haute | 33 605 | 31 925 | +1 680 |
| (−56,8 ; −4,8) | haute | 33 966 | 32 286 | +1 680 |
| (−49,0 ; −8,0) | haute | 36 433 | 34 753 | +1 680 |
| (−41,2 ; −4,8) | haute | 43 081 | 41 401 | +1 680 |

**Pire ajout : +1 744 primitives, plafond 10 000.** Le domaine entier ne
fait que 1 680 triangles, donc il est **toujours entièrement dans le
frustum** depuis ses propres stations ; les 64 de plus à (−41,2 ; 10,8)
caméra haute sont un autre objet que le champ de vision élargi fait
entrer, pas le relief.

⚠️ **« AZIMUT » VEUT DIRE OÙ LE JOUEUR SE TIENT**, pas où la caméra
regarde : `HubCamera` ne tourne jamais. Les huit stations sont les points
d'un cercle de rayon 11 u autour du sommet, ramenés dans l'AABB.

⚠️ **LA SECONDE CAMÉRA N'EST PAS UNE POURSUITE**, et le brief le
permettait à cette condition : **aucun véhicule ne passe près de ce
domaine** — le kart est au circuit (z ≤ −134), le char à voile à la Crique
(x ≥ 38). Il n'y avait donc pas de caméra de poursuite à lire. Ce qui est
mesuré à sa place est le même rig figé **levé de 4 u**, c'est-à-dire la vue
la plus large de la crête qui existe dans ce jeu.

⚠️ **Un zéro se publierait comme un zéro** : PHASE E asserte que le
compteur est rempli (pire frame 49 649) et que le relief coûte quelque
chose. Un delta de 0 voudrait dire que la crête n'a jamais été dessinée,
pas qu'elle est gratuite.

**Contexte** : la station de référence que Mathieu a mesurée sur device
affichait déjà **TRI gpu 55 722** sans la montagne, au-dessus du plafond
hub de 50 000, et **la mesure device complète (CH35-B tâche 4) n'a pas été
faite**. Ce lot avance sans elle, en connaissance de cause : c'est
exactement le pari que le test iPhone de l'étape suivante vérifie.

### Les rendus, et la station la plus faible

Vérification par **RENDU offscreen** aux conditions CH35-C (xvfb +
`opengl3`, SUN et RAIN, viewport 1080 × 1920), quatre stations :

| station | ce que la capture montre |
|---|---|
| **(−34,6 ; 35)** — celle de Mathieu | la crête monte sur le tiers gauche du cadre, **découpée sur le ciel**, la ligne d'arbres du mur passant devant et derrière. C'est la composition que la direction demandait. |
| **(−36 ; 8)** — la couture du plateau | le flanc monte à gauche avec des arbres posés dessus, le petit lac à droite : le relief se lit **par sa silhouette**, sans aucun ombrage, exactement comme CH35-C l'annonçait |
| **(−49 ; 3)** — le sommet | l'arête de la crête se détache nettement du fond, puis la descente, la forêt et la brume. Sous la pluie la lecture est meilleure encore (la brume donne la profondeur) |
| **(−49 ; 14)** — le pied nord, à 11 u du sommet | ⚠️ **la lecture la plus faible du domaine.** Le versant occupe ~90 % du cadre. Il y a bien une crête contre le ciel et des arbres à droite — ce n'est donc pas le « versant plein cadre sans rien derrière » que la contrainte interdit — mais c'est un grand aplat vert sans repère d'échelle. |

Ce que ce dernier point dit, et il faut le dire franchement : **la seule
chose qui manque à cette station est du décor sur le flanc** — de
l'occlusion, une échelle, un repère. C'est le contenu du **lot 2 PARTIE
B**, et ce lot l'interdit par construction. La forme respecte toutes les
contraintes chiffrées ; c'est la station à regarder en premier sur device.

⚠️ **`unproject_position` sur la VRAIE caméra** plutôt qu'un angle
d'élévation calculé : depuis la station la plus proche, le sommet se
projette au plus haut à **y = 385,8** d'un cadre de 1 920. Il n'est
**jamais coupé** par le haut. C'est la même méthode qui, au CH36, avait
trouvé un plafond de cadre faux de 1,01 u.

⚠️ **UN DÉFAUT D'OUTIL TROUVÉ PAR LA PREMIÈRE CAPTURE** : `CozyCapture`
posait `keepy.global_position = _at`, c'est-à-dire **y = 0**. Sans domaine
c'était juste ; avec un domaine, le personnage est **enterré dans le
relief** — les premières captures du sommet le montrent avec les oreilles
au ras du sol. Corrigé en `HubSurface.ground(_at)`, l'orthographe unique
que tout écrivain d'un y de sol utilise depuis CH37. Une capture fausse
aurait contaminé chaque mesure du lot 2 PARTIE B.

### `MountainProbe` — rouge avant vert, sur chaque assertion neuve

Sept phases, `ProbeWatchdog` armé en **première instruction** (900 s,
verdict INCONCLUSIVE explicite au dépassement), et un run complet
**ALL GREEN, 0 rouge**.

Elle tourne sous **xvfb + `--rendering-driver opengl3`** parce que PHASE E
lit un compteur que le driver dummy ne remplit pas et PHASE D un frustum
qu'il rapporte 0×0 : en `--headless` les deux passeraient **en ne mesurant
rien**. PHASE F, qui marche ~2 500 frames de physique, réduit d'abord le
`SubViewport` à 96 × 160 (`stretch = false` **d'abord** : un conteneur qui
étire ignore une taille explicite et se contente d'un warning) et le
restaure ensuite — le viewport ne touche pas la physique, et sous llvmpipe
c'est la différence entre une minute et vingt.

| phase | ce qu'elle gate | mesure |
|---|---|---|
| BLIND | `height_at` = 0 hors domaine, **et 0 partout tant qu'aucun domaine n'est enregistré** — prouvé AVANT que quoi que ce soit s'y appuie | 0,000000 / 4,5000 / 4,5000 restauré |
| A | `contains` / `domain_at` / `height_at` sur les 899 nœuds, les quatre bords, la couture du plateau | 0 nœud dehors, écart au nœud 0,000000000, couture plate à 0,000000000 sur ses 61 points |
| B | le raccord C0 remarché ici en plus de `register_domain` | **exactement 0**, et une grille levée de 0,01 u **EST refusée** (index −1) alors que la même non levée est acceptée |
| C | le mesh dessiné : sommets, triangulation, enroulement, pentes | 1 680 tris, écart sommet 0,000000000, écart **à l'intérieur** des triangles 0,000000852, **0 sur 1 680** enroulé à l'envers, pire pente **27,834°** |
| D | la ligne œil → sommet, et le cadre | 5 stations sur 8 regardent le sommet, **0 bloquée**, dénivelé vu d'un pied à 30 u = 4,500 u, **0 sommet coupé**, plus haut y écran 385,8 / 1 920 |
| E | le budget | **+1 744** pire cas, plafond 10 000 |
| F | la pire traversée, **marchée** sur le vrai hopper | **20,967 s** (1 258 frames, arrêt à 0,414 u de la cible), plafond 22,0 |

⚠️ **LE BANC REPRODUIT D'ABORD UN CHIFFRE DÉJÀ AU DOSSIER.** PHASE F
marche la diagonale livrée dans le **même run** : **1 122 frames =
18,700 s**, la valeur publiée **à la frame près**. Un banc incapable de
restituer un chiffre déjà mesuré n'a pas qualité à en publier un neuf.

**Passes rouge-avant-vert** — chaque neutralisation faite dans le fichier
**livré**, le run relancé en entier, puis restauration vérifiée
**byte-identique par `cmp`** :

| ce qui est neutralisé | rouges attendus | rouges obtenus |
|---|---|---|
| amplitude de la bosse 4,5 → 9,0 | la pente | **1** — `worst drawn slope 46.560 deg`, et rien d'autre |
| enroulement (a, c, b) → (a, b, c) | l'enroulement | **1** — `1680 wound the other way` |
| `TRIANGLE_BUDGET` 10 000 → 100 | le budget | **1** — `worst added primitives 1744 … ceiling 100` |
| `MOUNTAIN_MIN.x` −63 → −71 | la traversée | **1** — `walked in 22.383 s, ceiling 22.0` |
| `_ready` qui n'enregistre plus rien | le blind check | **2** — `with the domain the SAME point reads 0.0000` **et** `the ridge node draws one surface` |

⚠️ **LE NOMBRE DE ROUGES FAIT PARTIE DE L'ASSERTION.** La passe « pente »
en a rendu **un seul**, et c'est correct : à 9,0 u le sommet égale
exactement le plafond de 9 u visible, donc les deux assertions de hauteur
passent encore, tout juste. Un second rouge aurait voulu dire que la sonde
mesure la même chose deux fois.

### Le delta NET, mesuré sur DEUX ARBRES

Le +1 744 ci-dessus est le coût du **relief seul** — la question que le
plafond pose. Ce n'est pas la même question que « qu'est-ce que ce lot
change à la frame », parce que rendre le rectangle marchable **retire
aussi** les arbres du mur de forêt qui s'y trouvaient. Ce second chiffre a
donc été mesuré comme la doctrine l'exige : sur **deux arbres**, la branche
et `origin/staging` importée à part, **154 `.scn` comptés des deux côtés
avant toute comparaison** et 0 erreur d'import — un import tronqué produit
un faux rouge qui ressemble exactement à une régression.

Même banc (`CozyCapture`, xvfb + `opengl3`, SUN, 1080 × 1920) :

| station | `staging` | branche | delta **net** |
|---|---|---|---|
| (−34,6 ; 35) celle de Mathieu | 53 605 | 54 198 | **+593** |
| (−49 ; 14) pied nord | 37 898 | 38 921 | **+1 023** |
| (−49 ; 3) sommet | 37 822 | 38 481 | **+659** |
| (−36 ; 8) couture | 51 390 | 51 369 | **−21** |

Le lot ajoute donc **entre −21 et +1 023 primitives** à la frame réelle,
pour un relief qui en dessine 1 680 : le mur de forêt qui s'écarte en rend
la moitié à trois stations sur quatre, et **plus que tout** à la couture.

Les cinq restaurations ont été vérifiées **byte-identiques par `cmp`**, pas
relues.

⚠️ **La passe « domaine jamais enregistré » en rend DEUX, et les deux sont
justes** : le blind check (le jeu n'a rien enregistré) et le mesh (`_ready`
n'en construit plus). PHASE A reste **verte** dans cette passe, et c'est
correct — elle appelle `HubMountain.register()` elle-même, donc elle teste
le contrat du domaine et pas le câblage de la scène. Ce sont deux
questions différentes, et il fallait deux assertions.

## Ce que ce lot ne fait PAS, et où c'est écrit

Zéro semis, zéro prop, zéro arbre, zéro eau, zéro critter, zéro transport
sur ce domaine : c'est le lot 2 **PARTIE B**. Non touchés, vérifiés au
`git status` : `VehicleDrive.gd`, `KartBody.gd`, `SEA_RADIUS` /
`SEA_CENTRE`, tout CH36 (`FRAME_TOP_AT_APLOMB`, `SEAT_MAX_Y`, l'overlay) et
tout CH37 (`HubSurface`, `KeepyHopper`, `HubCamera`, `HubTapInput`,
`CozyScatter`) — **l'enregistrement du domaine passe par un nœud NEUF**,
`HubMountain`, et pas par une ligne ajoutée chez eux. Aucun asset généré,
supprimé, renommé ni dédupliqué. `LakeZoneProbe`, `V6CrittersProbe`,
`ChargerAudit` et `AirEnemyLandingLaneAudit` n'ont pas été rouverts ;
`WaterTintProbe` et `SeesawProbe` restent à leurs rouges préexistants et ne
sont présentées vertes nulle part.

Le seul fichier hors périmètre strict qui bouge est `CozyCapture.gd`, d'une
ligne, parce que sans elle **toutes** les captures du lot suivant
montreraient le personnage enterré — voir plus haut.

## Ce que ce lot laisse ouvert

1. **La mesure device.** C'est l'étape qui vérifie le pari : le terrain nu
   sur iPhone via `keepy-staging.vercel.app/?keepydev=1`, overlay POS +
   BUILD + TRI, **avant** toute suite. La station (−49 ; 14), le pied nord,
   est celle à regarder en premier.
2. **La station la plus faible n'a pas de gate.** « Un versant remplit
   ~90 % du cadre » n'est pas mesuré par une assertion : PHASE D gate la
   ligne de vue et le cadrage du sommet, pas la surface occupée. C'est la
   doctrine « la métrique peut être la mauvaise » qui s'applique ici, et le
   lot le dit plutôt que de la maquiller.
3. **Le nœud `Mountain` est le PREMIER enfant de `World`** pour que son
   `_ready` précède celui de `Props` et de `CozyScatter` — l'ordre des
   `_ready` en Godot suit l'ordre de l'arbre. Rien ne gate cet ordre
   aujourd'hui ; un lot qui réordonnerait la scène casserait le semis en
   silence.
