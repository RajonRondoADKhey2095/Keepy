# CH41 — La luge électrique : le premier véhicule sur surface

> Lot 3 de la série multi-altitude (CH35 → CH37 socle → CH38/CH39/CH40 relief
> → **CH41 véhicule**). Base `origin/staging` au commit `5015ba2`.

## CH41-0 — La question du lot, et la réponse en une ligne

Ce n'est **pas** une descente sur rails. C'est un **quatrième véhicule** :
tapé, monté, piloté au pouce comme le kart et le char à voile, libre d'aller
partout sur la carte, dont la seule différence est qu'**une pente le pousse**.
Il est garé au sommet de la crête ouest parce que c'est là qu'une luge se
gare, pas parce que la crête est une piste.

Le socle est le **composite Q2-B** que `docs/lots/CH35_MULTI_ALTITUDE.md`
recommandait : `SurfaceDrive`, un `RefCounted` qui possède un `VehicleDrive`
et l'accès au sol, et qui fait le rebase une fois pour toutes. **Kart, char
à voile et voilier ne sont PAS migrés** — trois conduites validées device,
zéro ligne touchée, `KartBody.gd:218` intact.

## CH41-1 — LE VERROU : VehicleDrive.gd N'A PAS ÉTÉ OUVERT

**Voie prise : la voie 1 du brief, `max_speed` modulé par instance.** Le
fichier `scripts/hub/kart/VehicleDrive.gd` est **byte-identique** à
`origin/staging`.

CH35 Q2 nommait l'ouverture de ce fichier comme légitime « si la descente
exige une accélération gravitaire au-delà du cap avec un rappel `off_lambda`
qui se sent ». Mesuré, ce n'est pas le cas, et pour deux raisons distinctes :

1. **`off_lambda` est un AMORTISSEMENT, pas un plafond.** Avec une
   accélération constante `a`, la vitesse ne s'arrête pas à `max_speed` :
   elle se stabilise à `max_speed + a / off_lambda`. Mesuré, plafond laissé
   plat : **10,358 u/s contre `MAX_SPEED_FLAT` 8,50** — la pente passe le
   cap moteur toute seule, sans que rien ne soit touché.
2. **`max_speed` est une variable d'instance que `SailBoat` module déjà
   chaque frame.** La luge lève son propre plafond avec la pente
   (`MAX_SPEED_FLAT` → `MAX_SPEED_DOWNHILL`, interpolé sur
   `GRADE_FOR_FULL_CAP`). Mesuré : **15,253 u/s**, soit **+47,3 %** sur
   l'amortissement seul et **×1,79** le cap moteur.

Les deux chiffres sont produits par `SledProbe` PHASE E, dans le même run,
sur la même descente : la version « plafond plat » n'est **pas** un second
véhicule, c'est la même arithmétique avec les trois lignes du verrou
retirées (`_drive_pinned`). C'est ce qui en fait une mesure de **ces
lignes-là**.

## CH41-2 — ⚠️ CH35 Q2 SE TROMPAIT SUR L'ORDRE, ET ÇA GÈLE LE VÉHICULE

CH35 Q2 prescrit d'injecter la force de pente dans la vélocité **AVANT**
`step()`. C'est ce que la première version faisait, et `SledProbe` PHASE E
l'a mesurée : **0,000 u/s et 0,00 u parcourus en 240 frames**, à l'arrêt
face à la montée sur le flanc le plus raide.

Le mécanisme, et il n'est pas dans une constante :

* la force rend `v_fwd` **négatif** avant que le modèle ne le regarde ;
* `VehicleDrive` prend alors sa branche « reversing and the throttle comes
  back » — `move_toward(v_fwd, 0.0, brake_decel * delta)` — qui ramène le
  recul à **exactement zéro et jamais au-delà** ;
* la branche d'accélération qui l'aurait poussé en avant **n'est jamais
  atteinte** ;
* et à vitesse nulle ce modèle ne donne **aucune autorité de braquage**
  (son `ratio`).

Résultat : un joueur garé sur un flanc, sans direction et sans moyen de
repartir. C'est **le blocage du char à voile** (`SandYacht._wall` étape 3),
atteint par l'autre bout — et cette fois par l'ordre des opérations, pas par
un mur.

**Correction : la force est injectée APRÈS `step()`.** Le modèle voit
`v_fwd = 0`, l'accélère sur sa branche ordinaire, et la pente reprend
ensuite sa part. Mesuré après correction : **2,109 u parcourus à 1,236 u/s
de moyenne** — la luge grimpe au pas au lieu de coller. Rien d'autre ne
bouge : la vitesse terminale d'une descente reste `cap + force / off_lambda`
(la force est ajoutée hors de l'amortissement dans les deux ordres), et un
hub plat ajoute toujours exactement zéro. Le coût est **une frame de retard
sur la force** — la différence entre une intégration explicite et
semi-implicite, soit 0,17 u/s sur le sol le plus raide de cette carte.

`SledProbe` PHASE E gate le départ arrêté face à la montée : le jour où
quelqu'un remet l'injection devant `step()`, la sonde tombe sur cette
phrase.

### Et une relation entre deux constantes de feeling, publiée et gatée

Au repos, le modèle offre `cap × ACCEL_LAMBDA` d'accélération ; la pente
pousse `SLOPE_GAIN × g·sinθ·cosθ`. Si la seconde l'emporte, la luge ne peut
pas quitter l'arrêt face à la montée. Les deux sont publiées
(`SledBody.climb_authority()`, `SledBody.slope_force()`) et l'inégalité est
gatée sur la pente la plus raide que la surface possède réellement :
**10,5312 u/s² contre 13,6000 — 77 % utilisés**. `ACCEL_LAMBDA` a dû passer
de 0,90 à **1,6** pour cela, ce qui est aussi l'identité du véhicule (un
moteur électrique délivre son couple à l'arrêt). Un réglage post-iPhone qui
monte `SLOPE_GAIN` au-delà **échoue bruyamment** au lieu d'expédier une
colline sur laquelle la luge peut être piégée.

## CH41-3 — `HubSurface.normal_at`, et pourquoi il arrive maintenant

CH37 écrivait : « `normal_at` est délibérément absent — il arrive avec le lot
qui incline un corps, ou pas du tout ». C'est ce lot.

`gradient_at` est la primitive, `normal_at` en dérive : **une seule
dérivation dans le dépôt, pas deux**. Et c'est la dérivée **analytique** de
`_sample` — constante à l'intérieur d'un triangle parce que `_sample` y est
linéaire — donc **exactement la normale de face du mesh dessiné**, pas une
approximation par différences finies (qui aurait été un second avis sur la
surface, le piège que ce fichier ferme dans son propre docblock).

`SledProbe` PHASE A le vérifie contre le **mesh committé**, face par face :
**1 680 triangles comparés, pire écart 1,224 × 10⁻⁴** sur un gradient de
0,528, soit 0,013° d'inclinaison — le bruit float32 entre un produit
vectoriel et une division des mêmes valeurs. Le blind check (l'autre
diagonale de la même cellule) lit **9,2 × 10⁻³**, un ordre de grandeur plus
loin : le test sait distinguer une mauvaise triangulation.

**Conséquence livrée : la normale est FACETTÉE et le consommateur doit la
lisser lui-même.** Deux triangles voisins de la crête diffèrent de ~6°
d'assiette (cosinus surélevé, A = 4,5, R = 14, pas 1,0) : écrite telle
quelle dans un châssis, elle claquerait une fois par mètre parcouru.
`SledBody.CHASSIS_LAMBDA` lisse le **CORPS** et laisse la géométrie exacte —
le même partage que le gîte du char à voile. Lisser dans `HubSurface` aurait
détruit son contrat (« les pieds se posent sur le triangle que le joueur
voit »).

## CH41-4 — Le mesh : procédural, 60 triangles, et l'inventaire d'abord

**Aucun asset n'a été généré, supprimé, renommé ni dédupliqué.** Inventaire
fait avant d'écrire une ligne : `assets/models/decor/` porte 107 `.glb`, et
**rien de forme luge** — les plus proches sont `deckchair_0`, `driftwood_0`
et `yacht_hull_0`, et aucun n'en est une. Le mesh est donc construit en
GDScript (`SledBody.build_mesh`) : deux patins à nez relevé, une plate-forme,
un capot moteur et un dossier. **Cinq boîtes, 60 triangles.**

Couleurs de sommet lues directement par `COLOR` du shader décor : crème
(0,96 ; 0,95 ; 0,90) pour la grande surface — la moitié de la silhouette qui
porte contre un flanc unlit — et rouge (0,86 ; 0,28 ; 0,24) pour les patins
et le capot.

### L'enroulement, et il est DÉCIDÉ, pas écrit à la main

`_quad()` reçoit la direction **sortante** et émet celui des deux ordres qui
met la normale main-droite **contre** elle. Se tromper n'est alors pas
possible, et `SledProbe` PHASE H relit le mesh committé pour le prouver au
lieu de croire le commentaire.

⚠️ **Et le piège est PIRE que CH39 ici, pas meilleur** : le shader décor est
`cull_disabled`, donc une coque à l'envers aurait l'air parfaitement normale
en sandbox **et sur device**. Rien ne s'en serait jamais plaint. C'est
pourquoi la phase rend aussi la luge à travers un matériau `cull_back` : le
test de face doit ne **rien** jeter.

## CH41-5 — Le budget, et il n'est pas dans le budget de CH40

**Le fait de comptabilité d'abord, parce qu'il change la réponse.**
`CozyScatter.RIDGE_TRIANGLE_BUDGET = 6000` est lu par `MountainProbe`
PHASE J sur les **batches du semis** : la lecture SOUMISE parcourt
`CozyScatter.batch_nodes()`, la lecture MESURÉE est le delta obtenu en
cachant les batches de l'habillage. **Un `Node3D` construit à la main n'est
dans aucune des deux** — il est présent dans les DEUX frames du delta
mesuré, donc il s'en annule exactement.

La luge n'« explose » donc pas la marge de 125 triangles de CH40 : elle
n'est pas dans cette ligne comptable du tout. Ce qui compte est ce qu'elle
coûte à la **frame**, et c'est mesuré séparément, même méthode et mêmes
stations que CH38/CH40 : 8 azimuts × 2 hauteurs de caméra, cacher le nœud et
relire la même frame, **contre le tremblement propre du compteur**.

| lecture | valeur |
|---|---|
| triangles du mesh | **60** |
| pire ajout mesuré, 8 stations × 2 caméras | voir `SledProbe` PHASE I |
| marge publiée par CH40 | 125 triangles |

**Aucune révision de budget n'est demandée**, et c'est une conclusion, pas
un contournement : 60 ≤ 125, donc la luge tiendrait dans la marge de CH40
**même si** elle y était comptée, ce qui n'est pas le cas. La sonde gate les
deux lectures.

### Ce qui n'a PAS été fait, et pourquoi

**La luge n'a pas d'empreinte au sol** (`HubTransport.footprints()`), à la
différence de la balle, du char et du voilier. `CozyScatter._blocked()` est
consulté **avant** les tirages RNG de variante, d'échelle et de lacet : un
`continue` supplémentaire décale **tout le flux aléatoire du semis en aval**,
donc tout le décor du hub. Cela invaliderait les 5 875 triangles soumis, le
+1 854 mesuré et la répartition 4 × 4 que CH40 vient de publier — un prix
sans commune mesure avec le bénéfice (une touffe d'herbe peut pousser au
travers du patin, au quart de densité du domaine). C'est réversible en une
ligne le jour où un lot possède le semis.

## CH41-6 — La caméra de poursuite en pente, exercée pour la première fois

Doctrine CH30 par héritage direct : pilotage continu → **poursuite**. La pose
a été rebasée sur `ground()` au CH37 et **aucun véhicule ne l'avait encore
exercée sur un domaine**.

La géométrie est étroite et il fallait la mesurer : la pose est
`ground(véhicule) − cap × DRIVE_BACK + DRIVE_UP`. La hauteur vient de sous
le **véhicule**, puis la caméra recule de 7,6 u **horizontalement**. En
descente, le sol derrière est **plus haut** que celui sous elle : le
dégagement vaut `DRIVE_UP` moins la montée sur 7,6 u, et sur un flanc à
27,8° cette montée fait **4,01 u contre un `DRIVE_UP` de 4,40**.

`SledProbe` PHASE J balaie tout le réseau du domaine × 8 caps
(> 5 000 paires) et publie le pire dégagement, avec un blind check : le même
balayage 4 u plus bas **doit** trouver du sol.

## CH41-7 — Ce que ce lot laisse ouvert

1. **Réglage des constantes de feeling après essai iPhone.** Elles sont
   groupées et nommées en tête de `SledBody.gd` pour ça. La seule qui n'est
   pas libre est `SLOPE_GAIN` — voir CH41-2, la relation est gatée.
2. **La descente est courte** : le flanc fait 14 u de rayon et la jambe
   descendante l'épuise en 17,5 u / 1,5 s. Le relief n'a **pas** été touché
   (interdiction du brief) ; un agrandissement serait un lot séparé et
   budgété.
3. **La mesure device complète CH35-B tâche 4** reste due.
4. **Aucune persistance** : pas de champ `WorldSave`, pas de bump de schéma.
   La luge est retrouvée à `SLED_PARK` à chaque démarrage.
5. **L'empreinte au sol du semis**, si un futur lot possède `CozyScatter`.
