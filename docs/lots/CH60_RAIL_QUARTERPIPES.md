# CH60 — LOT 3a : le rail et les deux quarterpipes deviennent solides

## Section 1 — la prémisse du brief est tombée à la première mesure

Le brief annonçait : « Les QUARTERPIPES sont CONCAVES », et faisait de la
qualité de leur décomposition convexe le point technique du lot.

**Ils ne l'étaient pas.** Mesuré en moteur sur le maillage livré, avant
d'écrire une ligne de collider (`QpReconProbe`, sonde jetable, supprimée) :

| facette | 1 | 2 | 3 | … | 11 | 12 |
|---|---|---|---|---|---|---|
| pente depuis l'horizontale | **86,25°** | 78,75° | 71,25° | … | 11,25° | **3,75°** |

Le profil livré montait **quasi verticalement là où le rider arrive** et
s'aplatissait **au lip**. C'est la **transposée exacte** d'un quarterpipe :
une bosse convexe, pas une transition. `quarterpipe()` écrivait

```gdscript
prof.append(Vector2(height - height * cos(a), height * sin(a)))
```

où `prof.x` est le **Z** du sommet et `prof.y` son **Y** (les deux appels
`_vertex` juste en dessous le disent). Cette orthographe donne
`z = h(1 − cos a)`, `y = h sin a`, dont la tangente vaut `cot(a)`.

Le commentaire au-dessus décrivait la forme que le code **ne construisait
pas** (« at a = 0 the point is (0, 0) with the surface horizontal ») et
nommait un centre d'arc — `(z = height, y = height)` — qui n'est pas le
centre du cercle réellement paramétré (`(z = height, y = 0)`).

## Section 2 — ⚠️ LE MAILLAGE PORTAIT SON PROPRE TÉMOIN À CHARGE, ET PERSONNE NE LE LISAIT

Ce n'est pas un avis sur ce à quoi le module devrait ressembler. **Les
normales de sommet de la boucle suivante n'ont jamais été fausses** : elles
courent `(0 ; 1 ; 0)` au pied à `(0 ; 0 ; −1)` au lip — plat-puis-vertical,
c'est-à-dire **exactement les normales du profil corrigé**.

Mesuré sur le maillage livré, facette par facette :

| | avant le fix | après le fix |
|---|---|---|
| pire écart normale stockée / normale de face vraie | **86,25°** | **3,75°** |
| forme de l'écart | **miroir exact** : la normale stockée à la facette *k* est la normale vraie de la facette *25 − k* | demi-facette (une normale lisse contre une facette plate) |

Deux lectures d'une même forme, dont l'une avait été transposée. Et le
shader décor (`cozy_decor.gdshader`) est un **toon shader qui lit `NORMAL`**
(`ndl = dot(n, sun_dir)`, deux bandes) : le park a donc été **OMBRÉ comme un
quarterpipe tout en étant GÉOMÉTRIQUEMENT une bosse**, depuis CH53. Le
correctif ne choisit pas entre les deux, il les remet d'accord.

**Doctrine tirée** (portée dans `CLAUDE.md`) : une normale de sommet est un
**témoin indépendant** de la géométrie qu'elle décrit, et ce dépôt en avait
un qui criait depuis sept lots.

## Section 3 — ce que le correctif ne bouge pas, mesuré des deux côtés

Les extrémités `(0 ; 0)` et `(height ; height)` sont les mêmes, donc :

| grandeur | staging | branche |
|---|---|---|
| park total | **468 triangles** | **468** |
| `nodes_scene` / `tris_scene` du hub | 715 / 346 624 | **715 / 346 624** |
| primitives ajoutées par le park, 4 stations | +56 / +50 / +468 / +468 | **identiques** |
| draw calls avec le park | 412 | **412** |
| projection écran des 5 modules, 4 stations | — | **identique au pixel** |
| recensement du tapis nord | 179 instances, 2 973 triangles | **identique** |
| `SkateTraverseProbe` (sortie complète) | — | **byte-identique** |
| `SkateDriveProbe` (sortie complète) | — | **byte-identique** |

Seuls **les comptes de pixels des quarterpipes** bougent — ce qui est le
changement lui-même : `m2` 7 328 → 6 471, `m3` 16 290 → 14 934 depuis
(3 ; 60). Une cuvette peint moins qu'une bosse. `m0` et `m4` bougent de
quelques centaines de pixels par **occlusion** (ils sont derrière).

Rendu avant/après depuis la caméra livrée, monde figé, trois stations :
**0,397 % / 0,683 % / 0,697 %** des pixels de la frame diffèrent, dans une
bande de 200 px de haut centrée sur les modules. Rien d'autre ne bouge.

## Section 4 — la décomposition, et pourquoi DOUZE est un minimum et pas un choix

Une fois le profil remis à l'endroit, la section transversale est la région
**sous une courbe CONVEXE croissante** : bornée en bas par `y = 0` de `z = 0`
à `z = height`, à droite par le dos vertical, et en haut par la polyligne
dessinée `P0..P12`. Ses sommets réflexes sont **`P1..P11`, onze**.

L'argument tient en trois lignes et se vérifie :

1. Une décomposition convexe doit résoudre chaque sommet réflexe, et une
   diagonale en résout au plus deux.
2. **Aucune diagonale ne joint deux points de l'arc** : la corde entre deux
   points d'une courbe convexe passe **au-dessus** d'elle, donc **hors** de
   la région.
3. `P0` n'est pas un apex non plus — la région n'est pas étoilée depuis lui :
   `f` convexe avec `f(0) = 0` donne `f(tz) ≤ t·f(z)`, dans le mauvais sens.

Donc **toute** diagonale finit en `B = (z = height, y = 0)`, en résout
**exactement un**, et onze diagonales coupent un polygone en **douze**
pièces. L'éventail depuis `B` est donc à la fois le plus simple et **un
optimum**.

⚠️ **ET IL EST EXACT CONTRE LE MAILLAGE DESSINÉ, pas contre l'arc idéal.**
Les cordes `P_s → P_{s+1}` passent au-dessus du vrai cercle — et le maillage
aussi, puisqu'il est facetté **sur les mêmes douze cordes**. Le collider est
le solide dessiné, jusqu'au dernier sommet.

| module | pièces | points par pièce | union distincte | sommets dessinés distincts |
|---|---|---|---|---|
| funbox | 3 | 8 / 6 / 6 | 12 | **12** |
| rail | 3 | 8 / 8 / 8 | 24 | **24** |
| quarterpipe (×2) | **12** | 6 ×12 | 28 | **28** |
| bol | **0** | — | 0 | 169 |

## Section 5 — l'égalité d'ensembles NE SUFFIT PAS, et PHASE V est la phase pour laquelle le lot existe

Douze cales qui seraient **toutes la même cale** porteraient les mêmes 28
points, passeraient PHASE G sans broncher, et laisseraient **onze douzièmes
d'une rampe en trou**. Une égalité de points dit que le collider est bâti sur
les coins dessinés ; elle ne dit pas que les pièces **PAVENT** la forme.

`SkatePhysicsProbe` **PHASE V** échantillonne donc les deux solides l'un
contre l'autre, sur une grille de **1 521 points** par module :

* le solide **DESSINÉ**, par **parité d'un rayon vertical** contre ses
  propres triangles (`get_faces()`) — la géométrie, jamais la formule qui
  l'a produite. Vers le haut, parce que chaque module d'ici est ouvert en
  `y = 0` et fermé partout où un rayon montant peut sortir ;
* le solide **COLLISIONNÉ**, par `intersect_point` sur le **SERVEUR
  PHYSIQUE** — pas les tableaux de pièces que la sonde pourrait recalculer :
  les hulls que le moteur a réellement construits, epsilons compris. Une
  cale de **0,0124 u d'épaisseur** au plus mince est exactement ce qu'un
  constructeur de hull peut laisser tomber en silence, et seul le serveur
  peut être interrogé là-dessus.

| module | échantillons | dans le dessiné | dans le serveur | **désaccords** |
|---|---|---|---|---|
| funbox | 1 521 | 1 079 | 1 079 | **0** |
| rail | 1 521 | 13 | 13 | **0** |
| quarterpipe 2 | 1 521 | 351 | 351 | **0** |
| quarterpipe 3 | 1 521 | 351 | 351 | **0** |

Les deux classificateurs sont **assertés votant dans les deux sens** avant
tout verdict, et le **blind check** retire un corps de la couche interrogée :
le serveur retombe à **0** et les **351** échantillons intérieurs deviennent
**351 désaccords**, puis l'accord revient à la restauration.

## Section 6 — ⚠️ UN QUARTERPIPE NE SE GATE PAS SUR SA HAUTEUR DESSINÉE

`SkateBoardBody` laisse `floor_max_angle` au 45° de Godot, avec une raison
écrite. Les facettes du profil valent 3,75 / 11,25 / 18,75 / 26,25 / 33,75 /
41,25 / **48,75** / … : la dernière sur laquelle un corps a le droit de se
tenir est donc la **sixième**, et le point le plus haut atteignable est
`P6 = (0,7071 ; 0,2929) × height` — **29 % de la montée dessinée, pas 100 %**.

| module | lip dessiné | plafond calculé (P6) | atteint, mesuré |
|---|---|---|---|
| quarterpipe 2 | 2,10 | 0,615 | **0,582** |
| quarterpipe 3 | 1,45 | 0,425 | **0,391** |
| funbox (deck) | 0,85 | — | **0,851** |

**La prémisse « les quarterpipes montent PLUS HAUT que la funbox » tombe
elle aussi** : dessinés oui, ridés non. Un gate écrit au lip aurait exigé
une montée qu'aucun corps cinématique sans inertie stockée ne peut faire —
et c'est le comportement juste d'un vrai quarterpipe : on monte, on cale, la
garde d'immobilisation lâche la cible, le joueur retape.

## Section 7 — le rail, qui doit bloquer ICI et pas LÀ

Le faisceau fait 0,12 de large et son dessous est à **0,56** ; la capsule de
la planche culmine à `2 × (DECK_WIDTH / 2)` = **0,26**. La planche **passe
donc sous le faisceau**, et la seule chose du module qui puisse l'arrêter
est une **jambe**.

Un gate qui n'aurait demandé que « le rail bloque » serait satisfait par un
collider **deux fois plus gros** que le rail dessiné ; un gate qui n'aurait
demandé que « la planche passe » serait satisfait par **aucun collider**.
PHASE J demande les deux, sur le même banc :

| essai | résultat |
|---|---|
| de face dans une jambe (départ 5,00 u) | **arrêtée à 0,506 u de son axe**, cible lâchée par la garde |
| même station, collider neutralisé | **traverse jusqu'à l'autre bord** |
| entre les jambes, collider en place | **passe**, à 0,394 u de la station d'arrivée, `max y 0,000` |

C'est aussi son propre contrôle d'instrument : deux verdicts opposés d'un
seul banc, donc aucun des deux n'est du genre gratuit.

## Section 8 — ⚠️ UN TEST VALIDE SUR UNE CLASSE DE FORMES EST UN TIRAGE AU SORT SUR UNE AUTRE

`SkateparkProbe` PHASE W porte, depuis CH53, un sous-test de **signe de
profondeur** qui dit de lui-même qu'« il marche sur un corps **fermé
CONVEXE** ». C'est vrai, et c'est **toute** sa validité : il suppose qu'aucune
surface ne peut **tourner le dos** à la caméra tout en étant **plus proche**
qu'une surface de face. Un corps concave casse exactement cette hypothèse.

Le quarterpipe corrigé l'a fait rougir : **0,2836 contre 0,2831**, une
égalité à 0,18 % publiée comme un maillage à l'envers.

**Il n'a pas été fait taire** (`CLAUDE.md` l'interdit) : le module a été
**reconstruit à l'envers** et les deux tests relus à **cinq stations**.

| module 2 | ratio conservé | signe de profondeur, par station |
|---|---|---|
| correct | **1,0000** ×5 | ok, ok, ok, **INVERTED**, **INVERTED** |
| à l'envers | **0,575 – 0,729** | ok, ok, **INVERTED** ×3 |

**Les deux ensembles de verdicts se RECOUVRENT.** Ce sous-test ne peut pas
distinguer un quarterpipe bien enroulé d'un quarterpipe retourné : sa réponse
suit la **STATION**, pas l'enroulement. Le juge CH39 (ratio conservé), lui,
les sépare complètement — parce qu'**un corps concave ne garde pas sa
silhouette sous inversion**, ce qui est précisément la cécité que le
sous-test avait été ajouté pour couvrir et qui ne s'applique pas ici.

⚠️ **ET CE N'EST PAS LA GÉOMÉTRIE DE CE LOT QUI EST SPÉCIALE.** Le même
balayage a pris le **BOL** — que CH60 ne touche pas, cuvette concave —
rapportant `INVERTED` à **0,2503 contre 0,2490** depuis (5 ; 60). **Le défaut
était déjà dans le park livré** ; le quarterpipe corrigé s'est seulement
trouvé à une station où il tire.

**Réparation** : le sous-test lit désormais **son propre plancher** (deux
rendus d'un même état) et **ne rend AUCUN verdict** en dessous ; chaque
module qu'il décline est passé au juge — et **le passage de relais est
PROUVÉ dans le même run** par une passe rouge (module 2 à l'envers : 0,7274,
attrapé ; restauré : 1,0000). Un contrôle d'instrument empêche
« non résolu » de devenir une porte de sortie : le sous-test doit encore
résoudre sur **au moins un** module — il en résout **4 sur 5**.

## Section 9 — la parallaxe au point haut, par un VRAI point d'écran

Garde-fou 1 du brief, et le 18e faux-signal du dépôt est la raison de la
méthode : CH57 a livré une branche **inatteignable** avec 43 assertions
vertes au-dessus, parce que son banc appelait l'API en direct. `PHASE M`
entre donc **où le doigt entre** — un **pixel de conteneur** à travers
`HubTapInput._handle_point` — donc la projection, le rayon sol, le clamp et
l'**ordre des branches** sont tous sous test.

| module | atteint | parallaxe | résidu bout-en-bout |
|---|---|---|---|
| funbox (deck) | 0,851 | **1,501 u** (CH58) | — |
| quarterpipe 2 | 0,577 | **0,929 u** | **0,0000 u** |
| quarterpipe 3 | 0,386 | **0,686 u** | **0,0000 u** |
| rail | 0,000 | cas plat (0,133 u) | — |
| rayon de self-tap | | **0,90 u** | |

**Les quarterpipes sont MOINS exigeants que la funbox, pas plus** : la
planche s'arrête bien sous les deux lips. Le résidu bout-en-bout — pixel →
`unproject` → échelle conteneur/viewport → grille de pixels → rayon sol →
clamp, contre ce que `_drawn_ground_point` compare — vaut **exactement
zéro** sur les deux.

La **parallaxe est publiée et non gatée** : c'est de combien une comparaison
plate naïve se tromperait, et CH58 a déjà empêché le code livré de faire
cette comparaison. Ce qui est gaté, c'est la **contribution du clamp** (la
seule façon dont un corps surélevé près d'un bord pourrait encore casser le
geste) et **ce qu'un doigt produit réellement**, par un doigt.

⚠️ **Deux défauts trouvés DANS CETTE SONDE par sa propre passe rouge**, tous
deux des entrées de `CLAUDE.md` :
1. elle lisait le point de comparaison **APRÈS** le tap — huit frames plus
   tard, il est descendu et la caméra a suivi : **0,97 u rapporté là où la
   vérité est 0,0000** ;
2. elle passait à PHASE T un hopper **encore en vol**, qui a mesuré **25 hops
   en 421 frames** et l'a appelé la diagonale publiée. La phase rend
   désormais le monde **au repos**, et le gate.

## Section 10 — le coût, re-mesuré contre CH56 plutôt que supposé

⚠️ **`PhysicsCostProbe` sous xvfb a rendu NO VERDICT et c'est le bon
comportement** : le tremblement propre de la salle (2,7199 ms) dépasse le
signal (0,1077 ms) — llvmpipe redessine la fenêtre à chaque itération. La
sonde le dit et renvoie vers `--headless`, où elle sort **ALL GREEN** sur
les deux arbres.

| courbe A (N modules statiques, convexe) | N=0 | N=1 | N=6 | N=20 | **N=100** | spread à N=100 |
|---|---|---|---|---|---|---|
| branche, ms/tick | 0,2445 | 0,2551 | 0,2591 | 0,2656 | **0,2690** | **0,0496** |
| formes | 2 | 14 | 78 | 258 | **1 282** | |

**Montée sur cent modules : +0,0245 ms/tick, pour un tremblement de station
de 0,0496.** À l'intérieur des barres d'erreur : le banc publie une **BORNE
SUPÉRIEURE**, pas une pente — **≤ 0,0000191 ms/tick par PIÈCE convexe**.
CH56 publiait **0,000018**. Le chiffre est reproduit.

Ce que ce lot ajoute réellement : le park passe de **3** formes convexes
(CH57) à **30**, soit **+27 pièces ≤ +0,00049 ms/tick** — **0,21 %** des
0,2278 ms/tick de la forme B, **0,0025 %** d'une frame de 20 ms à F = 1.
Gratuit, comme CH56 l'avait prédit.

⚠️ **Note de banc** : `PhysicsCostProbe` price la décomposition **du moteur**
(VHACD), pas celle qui est livrée. Elle rend 12 hulls pour la funbox, 4 pour
le rail, **8** pour le quarterpipe corrigé (**15** avant le fix) et 32 pour
le bol. La décomposition écrite à la main et livrée fait 3 / 3 / 12 / —,
**exacte** là où celle du moteur est approchée et — CH56 §12.4 le dit — n'a
jamais été vérifiée pour sa justesse.

**Zéro primitive, zéro draw call**, signé sous vrai driver (X11/llvmpipe),
banc immobile des deux côtés :

| | PHYS ON | répétition | PHYS OFF | répétition | delta |
|---|---|---|---|---|---|
| `nodes_scene` | 715 | 715 | 715 | 715 | **0** |
| `tris_scene` | 346 624 | 346 624 | 346 624 | 346 624 | **0** |
| `engine_prims` | 92 342 | 92 342 | 92 342 | 92 342 | **0** |
| `engine_calls` | 394 | 394 | 394 | 394 | **0** |

## Section 11 — la table croisée, sur DEUX arbres importés séparément

154 `.scn` importés des deux côtés, comptés avant toute comparaison
(`CLAUDE.md` : un import tronqué fabrique un faux rouge).

| sonde | driver | branche | référence `origin/staging` |
|---|---|---|---|
| `SkatePhysicsProbe` | headless | **ALL GREEN, 0 red** | ALL GREEN, 0 red |
| `SkatePhysicsProbe` | xvfb + opengl3 | PHASE B signée, delta 0 | — |
| `SkateDismountProbe` | xvfb + opengl3 | **ALL GREEN, 0 red** | ALL GREEN, 0 red |
| `SkateDriveProbe` | xvfb + opengl3 | **ALL GREEN, 0 red** | ALL GREEN, 0 red — **sortie byte-identique** |
| `SkateparkProbe` | xvfb + opengl3 | **ALL GREEN, 0 red** | ALL GREEN, 0 red |
| `SkateTraverseProbe` | headless | **ALL GREEN, 0 red** | ALL GREEN, 0 red — **sortie byte-identique** |
| `PhysicsCostProbe` | headless | **ALL GREEN, 0 red** | ALL GREEN, 0 red |
| `ProbeTimeoutAudit` | headless | **PASSED, 92 sondes** | PASSED, 92 — **listing byte-identique** |

Traversées, monde physique vivant, **re-marchées** et non supposées :

| trajet | publié | mesuré ici |
|---|---|---|
| diagonale du carré | 66 hops / 18,700 s | **66 / 1 122 frames / 18,700 s** (`SkateTraverseProbe`, les deux arbres) |
| pire paire CH38 | 20,967 s | **74 hops / 1 258 frames / 20,967 s** |
| plafond | 22,0 s | tenu |

⚠️ **Un piège écarté par la mesure** : `SkatePhysicsProbe` PHASE T rend
**1 123** frames (18,717 s) et non 1 122. Ce n'est pas une régression — la
**référence rend le même 1 123** ; c'est un effet de l'ordre des phases
(le hopper y part d'un état différent), et `SkateTraverseProbe`, qui marche
la diagonale en premier, rend **1 122 / 18,700 s exactement** des deux
côtés. Le gate de CH57 passe à 0,01666 < 0,01667 — **sur le fil**, signalé
et laissé tel quel plutôt que desserré sans mandat.

⚠️ **Et un faux écart d'audit** : `ProbeTimeoutAudit` a d'abord rendu 95
contre 93. Les deux chiffres étaient faux — 95 comptait les trois sondes
jetables de ce lot, et **93 comptait une copie de l'une d'elles que la
session avait posée dans l'arbre de référence pour un rendu comparatif**.
Les trois supprimées, les deux arbres rendent **92**, listing identique.

## Section 12 — le périmètre, tenu, et ce que le lot NE fait pas

* **Le bol reste hors du lot**, délibérément. `pieces_for()` rend **vide**
  pour lui, donc le périmètre est un **fait publié** et non une liste de
  noms qu'un lecteur doit retenir. CH56 §12.4 : une cuvette décomposée en
  hulls convexes est **géométriquement fausse**, et CH56 en a mesuré le
  coût sans jamais en vérifier la justesse. Lot 3b.
* **D1** : `HubSurface` reste la source unique du sol — 0 violation sur
  chaque tick de chaque roulé.
* **D2** : le collider reste au porteur ; Keepy n'en reçoit aucun, et la
  traversée le confirme.
* **D5** : pièces convexes, aucun trimesh.
* **CozyScatter** n'acquiert aucun collider.
* **`KeepyHopper`** intouché.
* **PHYS OFF** : PHASE O verte des deux côtés — la planche n'est pas un
  corps physique, il monte en `ON_VEHICLE` et non `ON_CARRIER`, la branche
  réordonnée par CH58 n'est même pas atteinte.
* **F n'a pas été re-mesuré**, comme le brief l'exige.
