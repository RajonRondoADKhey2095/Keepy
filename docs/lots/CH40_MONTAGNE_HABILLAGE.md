# CH40 — Zone montagne, LOT 2 PARTIE B : l'habillage de la crête (7 septembre 2026)

> Fichier de chantier créé par le lot CH40. Le lot CH38
> (`docs/lots/CH38_MONTAGNE_RELIEF.md`) a livré le relief nu ; le lot CH39
> (`docs/lots/CH39_RELIEF_DIAGNOSTIC.md`) l'a rendu réellement dessiné et a
> laissé **deux constats non corrigés** que ce lot reprend : la crête est
> **chauve**, et le sol unlit ne porte **aucun signal de pente**. Pas de
> véhicule, pas de luge, aucune mécanique neuve.

## CH40-1 — Base, et la vérification de concurrence faite AU DÉBUT

`git fetch origin` en première commande. La branche de session pointait sur
`origin/main` (arbre `8f4dc2e`), c'est-à-dire **en retard de CH36, CH37,
CH38 et CH39**, qui vivent tous sur `staging` : la branche a été repartie de
`origin/staging` `fe679d8`. `origin/claude/ch39-relief-diagnostic-mw40bi`
est **ancêtre de `staging`** (`git merge-base --is-ancestor` : oui), donc
CH39 déjà mergé et pas une session concurrente —
**vérifié par ANCESTRALITÉ, pas par le nom**.

Éditeur Godot 4.3 provisionné en session (50 276 070 o = `Content-Length`
annoncé). ⚠️ **Les templates d'export sont arrivés TRONQUÉS au premier
essai** : 796 127 735 o pour 1 073 228 327 annoncés, `curl` sortant en 56
(« Recv failure: Connection reset by peer ») — exactement le piège au
dossier, cinquième occurrence. Repris par `curl -C -` et **vérifié contre
le `Content-Length` avant extraction**. Import complet : **154 `.scn`**,
0 erreur, le même compte que CH38.

## CH40-2 — ÉTAPE 0 : l'inventaire, et pourquoi rien n'a été généré

La règle du projet est absolue — aucun asset généré sans validation
explicite de Mathieu. L'inventaire a donc précédé toute autre chose, et il
a trouvé que **le dépôt possédait déjà toute la montagne** :

| asset | tri | hauteur | couleur effective | L | déjà utilisé par |
|---|---|---|---|---|---|
| `tree_4_conifer.glb` | 390 | 4,871 u | (0,06 ; 0,24 ; 0,10) | 0,036 | mur de forêt, layout `HubBuilder` |
| `cypress_0.glb` | 140 | 3,985 u | (0,02 ; 0,07 ; 0,03) | **0,005** | la Lande, mur de forêt |
| `cypress_1.glb` | 140 | 3,177 u | idem | 0,005 | idem |
| `palerock_0.glb` | 20 | 0,655 u | (0,41→0,50 ; 0,37→0,45 ; 0,29→0,36) | 0,113 → 0,176 | Lande, Crique |
| `palerock_1.glb` | 20 | 1,037 u | idem, jusqu'à (0,56 ; 0,50 ; 0,39) | jusqu'à 0,222 | idem |
| `pebble_0/1.glb` | 20 | 0,084 u | (0,36 ; 0,31 ; 0,25) | 0,082 | semis plateau |

**Ce qui rend le thème DISTINCT est mesuré, pas ressenti** : le conifère est
en vert-**bleu** (0,06 ; 0,24 ; **0,10**) là où l'arbre rond du plateau est
en vert-**jaune** (0,07 ; 0,25 ; **0,04**) — même luminance, autre teinte,
donc un autre bois et pas « encore la même chose ». Et `palerock` est **la
seule pierre du dépôt qui ne soit pas vert-mousse** : les `rock_*` sont à
(0,21-0,27 ; 0,35-0,43 ; 0,10-0,12), franchement verts.

⚠️ **Le gain de luminosité du cyprès est déjà au dossier et se transporte
tout seul.** `CozyPalette.FAMILY_GAIN` porte `4,4` pour `cypress_0` et
`cypress_1`, et il est clé sur le **nom de MESH** : les batches de ce lot
héritent du gain sans une ligne à eux. Sans lui, une flèche à L = 0,005 sur
un sol rendu à L = 0,0799 serait une silhouette noire.

⚠️ **Un `.glb` déjà livré coûte ZÉRO payload** (CH01) : réutiliser est
gratuit là où une copie décimée serait un fichier de plus. Aucun asset
généré, supprimé, renommé ni dédupliqué.

## CH40-3 — ÉTAPE 1 : la borne, et les deux corrections qui la rendent juste

`CozyScatter.COVER_MIN.x` valait **−37** et `HubRegion.MOUNTAIN_MIN.x` vaut
**−63** : les deux rectangles se recouvraient de **2 u** au bord est de la
crête. Mesuré sur l'arbre livré : **20 instances** sur les 840 u² du
domaine, toutes dans cette bande où le relief est déjà à h = 0, et **12 des
16 cases** d'une grille 4 × 4 sur le domaine **vides**.

La borne est désormais lue sur `HubRegion.MOUNTAIN_MIN.x`, pas retapée — une
troisième orthographe de −63 est exactement le chiffre fantôme que ce dépôt
a déjà payé. Le compte de candidats étant `aire × densité`, **toute autre
unité carrée du hub garde exactement la densité qu'elle avait**.

Deux corrections l'accompagnent, et ce sont elles qui la rendent correcte :

* **`_sprinkle` pose sa transform sur `HubSurface.ground(p)`, pris EN
  DERNIER.** Tous les tests au-dessus (disques d'eau, empreintes, épine du
  ruisseau, spawn) comparent des distances **3D** à des centres à y = 0 :
  lever `p` avant eux gonflerait chacune de ces distances de la hauteur de
  la colline et relâcherait silencieusement chaque garde. Hors domaine,
  `ground()` rend `p` inchangé — **mesuré : les 2 145 instances hors domaine
  sont toutes à y = 0,000000**.
* **`_shadow_at` n'émet aucun blob sur un domaine.** Ce disque est un quad
  **horizontal plat** à un y fixe ; sur une pente de 28° avec un rayon de
  1 u il flotte de 0,27 u sur la moitié aval et s'enterre d'autant sur
  l'amont. Il n'y a pas de bonne hauteur pour lui, donc le domaine n'en a
  aucun plutôt qu'un faux.

⚠️ **ET UN BLACKLIST DE NOMS S'EST TROMPÉ DÈS SON PREMIER RUN.** La sonde
listait d'abord les nœuds qui **ne sont pas** du décor pour compter les
autres ; elle disait `"Butterflies"` et le nœud s'appelle `"Butterflies1"`,
si bien qu'un essaim volant à 1,06 u au-dessus de la colline a été compté
comme du décor enterré. Corrigé à la racine : `CozyScatter` **publie**
`batch_nodes()`, la liste que `_flush` a réellement construite. Un lecteur
qui doit **reconnaître** son sujet aura tort le jour où un douzième nœud
fabriqué à la main apparaît.

**Résultat étape 1, densité pleine** : 373 instances sur le domaine,
**0,4440 / u²**, **0 case vide sur 16**, écart pire à la surface
**0,000000 u**.

## CH40-4 — ÉTAPE 2 : la composition, et pourquoi ce n'est pas un semis

CH38 a nommé lui-même la lecture la plus faible du domaine : depuis le pied
nord, le versant remplit ~90 % du cadre en « un grand aplat vert **sans
repère d'échelle** ». CH39 a mesuré pourquoi : `cozy_ground` est `unshaded`,
et la corrélation entre la pente sous un pixel et la luminance livrée vaut
**r² = 0,010** et **0,117**. Il n'y a donc rien à régler dans un matériau —
seuls une **silhouette contre un fond** et des **objets de taille connue**
peuvent dire qu'un sol est incliné. C'est un problème de **layout** :

| population | ce qu'elle fait | asset | n |
|---|---|---|---|
| **la couronne** | neuf pièces sur un anneau de 5 u autour du sommet, conifères et flèches alternés : le dôme lisse se termine en **ligne de crête dentelée** au lieu d'une courbe | `tree_4_conifer` / `cypress_0/1` | 5 + 4 |
| **l'épaule** | un conifère sur la seconde bosse, pour que la silhouette à deux sommets que CH38 a payée trois itérations **se lise** comme deux | `tree_4_conifer` | 1 |
| **le flanc** | quatre flèches dans la bande 0,5 → 2,4 u : un objet répété à quatre hauteurs est une échelle de perspective que le sol ne donne pas | `cypress_0/1` | 4 |
| **les blocs** | douze pierres pâles **biaisées au NORD**, exactement le versant que CH38 a désigné. Pierre claire sur vert sombre est le plus fort contraste de cette palette, et un bloc est le prop dont un joueur connaît déjà la taille | `palerock_0/1` | 12 |
| **l'éboulis** | des cailloux sur les hauts de pente **seulement** | `pebble_0/1` | 22 |

⚠️ **Rien sur le périmètre** : chaque bande exige h > 0, donc la couture C0
où le relief rejoint le hub plat reste nue — c'est le seul endroit où un
prop poserait moitié sur une pente, moitié sur un plan.

### ⚠️ La couronne a eu besoin de sa PROPRE séparation, et la première version a mesuré pourquoi

Neuf pièces sur un anneau de 5 u sont à `2 × 5 × sin(20°) = 3,42 u` l'une de
l'autre, et `RIDGE_SEP_TREE` en réserve 2,1 de chaque côté, soit **4,2 u** :
**l'anneau s'est refusé lui-même**. Sorti : **4 conifères sur 5 et 1 flèche
sur 4** — c'est-à-dire la ligne de crête que ce lot existe pour dessiner,
avec un trou dedans. `RIDGE_SEP_CROWN = 1,3` (2,6 u entre troncs) pour un
conifère dont le rayon tronc-à-pointe à l'échelle 0,7 vaut 0,88 u : c'est un
bosquet, pas une collision. Avec : **6 conifères, 8 flèches**.

## CH40-5 — La densité, publiée plutôt que ressentie

| ligne | ridge | référence | rapport |
|---|---|---|---|
| habillage seul | **0,0571 / u²** (48 pièces) | semis plateau hors herbe 0,076 | **0,75×** |
| habillage seul | 0,0571 / u² | props du vallon d'automne 0,091 | **0,63×** |
| tapis hérité | **0,1071 / u²** (90 pièces) | tapis plateau 0,4488 | 0,24× |
| **total domaine** | **0,1643 / u²** (138 pièces) | plateau 0,4488 | **0,37×** |

`DOMAIN_COVER_KEEP = 0,25` : un domaine enregistré ne garde qu'un quart du
tapis. **Mesuré, pas choisi** — au taux du plateau le domaine portait 377
instances, soit 6 641 triangles de touffes **avant** le premier conifère, sur
une colline où le device lit déjà 44 043 primitives. Et c'est aussi ce à quoi
un versant doit ressembler : une pelouse n'est pas une montagne. Le tirage
n'est fait **que** sur un candidat qui est sur un domaine, donc le flux RNG
hors crête est celui qu'il était.

**La seule ligne qui n'est PAS plus basse est l'arbre** : 14 conifères et
flèches sur 840 u² font 0,0167 / u² contre 0,014 dans le vallon, soit
**1,19×**. C'est délibéré et c'est tout le sujet — l'arbre est la seule pièce
qui fasse une **silhouette**, et la silhouette est le seul indice qu'ait une
pente unlit. Rogner là dépenserait l'économie sur la famille qui achète
précisément la lisibilité pour laquelle ce lot existe.

## CH40-6 — Le budget, dans le fichier dès le commit qui crée la passe

`CozyScatter.RIDGE_TRIANGLE_BUDGET = 6000`, et c'est de l'arithmétique, pas
du goût : la lecture device de Mathieu à la crête valait **44 043**
primitives avec le relief nu (CH39, station A) ; **44 043 + 6 000 = 50 043**,
soit la cible de 50 000 du hub à l'arrondi près. Le hub dépasse déjà cette
cible ailleurs (**55 722** mesurés au spawn, CH38), et la mesure device
complète que CH35-B tâche 4 doit toujours est ce qui dira si 50 000 est le
bon nombre. **La conception a été taillée pour tenir le plafond, pas
l'inverse** — la passe rouge qui remet le tapis à densité pleine sort à
**10 986 triangles** et le plafond la refuse.

Deux lectures, deux questions différentes :

* **SOUMIS** — arithmétique : chaque instance de décor du domaine × les
  triangles du mesh qu'elle dessine. Borne **haute** (le frustum et le LOD
  ne peuvent que retrancher), et la seule qui couvre aussi le tapis, parce
  qu'un batch de CELLULE est partagé avec du sol hors crête et ne peut pas
  être caché seul sans le corrompre (CH23). **5 875, plafond 6 000.**
* **MESURÉ** — la méthode CH38 : cacher les nœuds de l'habillage et relire
  la **même** frame, 8 stations × 2 hauteurs de caméra. **Pire ajout
  +1 854**, à (−56,8 ; 10,8) caméra haute.

### Le delta NET, mesuré sur DEUX ARBRES

`origin/staging` importée à part, **154 `.scn` comptés des deux côtés**,
0 erreur d'import. Même banc (`CozyCapture`, xvfb + `opengl3`, 1080 × 1920) :

| station | `staging` | étape 1 seule | livré | delta net |
|---|---|---|---|---|
| A (−46,4 ; 13,0) | 42 951 | 48 672 (+5 721) | **45 922** | **+2 971** |
| B (−50,4 ; 5,8) | 37 081 | 45 065 (+7 984) | **41 517** | **+4 436** |

La colonne du milieu est ce que la borne corrigée aurait coûté **sans** le
tapis aminci : c'est la mesure qui justifie `DOMAIN_COVER_KEEP`, et elle dit
que l'amincissement rend à peu près la moitié du coût. Projection device :
44 043 + 2 971 = **47 014** et 38 057 + 4 436 = **42 493**, tous deux sous
50 000.

## CH40-7 — La sonde : quatre phases neuves, et un faux-vert dans la sonde elle-même

`MountainProbe` passe de 7 à 11 phases, **78 assertions, ALL GREEN 0 red**.

| phase | ce qu'elle gate | mesure |
|---|---|---|
| **H** | la crête n'est plus chauve — gaté sur la **RÉPARTITION**, pas sur un total : chaque case d'une grille 4 × 4 doit porter quelque chose, ce qu'une bande de 2 u ne peut pas simuler. Blind d'abord : le même compteur passé sur le grand lac doit répondre 0 | 138 instances, 0 case vide sur 16, blind 0 |
| **I** | rien ne flotte, rien n'est enterré — **et le lift est un no-op partout ailleurs**, ce qui est la moitié qui prouve la première. Blind : une instance vivante levée de 0,5 u, relue par le même accesseur, remise, et **re-lue** | 0,000000 u sur le domaine, 0,000000 u hors, 0 blob sur 750 sur le relief |
| **J** | le contrat d'enregistrement **relu après la passe** (toujours enregistré, AABB inchangée) puis les deux lectures du coût | AABB x [−63, −35] z [−12, 18], 5 875 soumis, +1 854 pire |
| **K** | l'apex. ⚠️ **UN CONIFÈRE DE 4,871 u SUR UNE COURONNE À 4,5 u FAIT 9,37 u AVANT TOUTE ÉCHELLE**, au-dessus du plafond de cadre de 9 u de CH36 — et la moitié que personne ne tape est le sol sous lui. Mesuré sur le mesh **tel que construit**, puis la pièce la plus haute projetée par `unproject_position` sur le vrai rig | apex 7,056 u, écran y 228,4 / 1 920 |
| **L** | les pixels de l'habillage aux **deux stations device**, par masque d'identification, blind d'abord | 10,742 % et 15,474 % du cadre |

**PHASE G tourne désormais aussi à ces deux stations** : « la crête possède
encore le cadre avec des arbres devant » est mesuré et pas supposé —
**54,20 %** et **47,48 %**, contre 58,36 % au sommet avant habillage. Les
arbres mangent onze points de crête et n'en brouillent pas la lecture.

### ⚠️ ET LA PASSE ROUGE A TROUVÉ UN FAUX-VERT DANS CETTE SONDE — le onzième du dépôt

Avec la passe d'habillage arrêtée, `_ridge_nodes()` rend une liste **VIDE** :
« les cacher et relire » ne cachait **rien**, et le compteur bougeait quand
même de **+64** entre deux lectures. L'assertion
« MEASURED: the dressing costs something » est donc revenue **VERTE** sur une
colline nue. C'est exactement la famille CH39 : une assertion de **présence**
répondue par un instrument qui n'a jamais été branché sur son sujet.

Fermé par un **plancher de bruit mesuré** — deux lectures de plus au même
poste, **rien touché** (jusqu'à **140** primitives d'écart à la caméra haute)
— et par une assertion préalable qu'il y a des batches à cacher. La même
passe rouge rejouée rend alors **7 rouges au lieu de 5**.

**Ce qu'il faut en retenir, et ce n'est pas « il manquait une assertion »** :
un delta obtenu en éteignant quelque chose ne vaut rien tant que le banc n'a
pas publié **ce qu'il rend quand on n'éteint rien**.

### Les passes rouge-avant-vert

Chaque neutralisation faite dans le fichier **livré**, run relancé **en
entier**, restauration vérifiée **byte-identique par `cmp`** :

| ce qui est neutralisé | rouges attendus | rouges obtenus |
|---|---|---|
| `COVER_MIN.x` remis à −37 | la couverture | **3** — 20 instances contre un plancher de 40, **12 des 16 cases VIDES**, et la borne n'est plus celle de la région |
| le lift `HubSurface.ground()` retiré | le sol | **1** — une touffe **4,434 u sous la surface** à (−49,07 ; 4,03) |
| la garde d'ombre retirée | les blobs | **1** — 7 blobs sur 757 sur le relief |
| `RIDGE_TRIANGLE_BUDGET` 6 000 → 1 000 | le budget | **2** — SOUMIS 5 875 et MESURÉ 1 854 refusés tous les deux |
| échelle conifère max 0,82 → 2,0 | l'apex | **2** — apex **11,065 u**, ET la vraie caméra le met à **écran y −495,2**, hors du haut d'un cadre de 1 920 |
| la passe d'habillage ne tourne plus | la présence | **7**, et pas d'autres |
| `DOMAIN_COVER_KEEP` 0,25 → 1,0 | le budget | **1** — **10 986** triangles soumis contre 6 000 |

⚠️ **Deux rouges pour la passe d'échelle, et les deux sont justes** :
l'arithmétique et la caméra répondent séparément à la même question, ce qui
est exactement ce qu'on veut d'un plafond de cadre.

**PHASE F reste le témoin** : la pire paire marchée en **20,967 s** et la
diagonale livrée en **18,700 s**, à la frame près — les deux chiffres que
CH38 a publiés, restitués par le même banc dans le même run.

## CH40-8 — Les rendus, avant et après

Quatre conditions par arbre (SUN et RAIN, aux deux stations device),
`CozyCapture`, xvfb + `opengl3`, 1080 × 1920, Keepy posé par
`HubSurface.ground()`.

* **Station A (−46,4 ; 13,0), le pied nord.** Avant : le grand aplat vert
  que CH38 décrivait, sans un objet dessus. Après : les blocs pâles montent
  le versant en diagonale et donnent l'échelle et la parallaxe qui
  manquaient, la couronne de conifères découpe la crête contre le mur
  d'arbres ronds derrière, et la bande de cailloux dit la pente.
* **Station B (−50,4 ; 5,8), le sommet.** Après : le bosquet entoure le
  personnage, la crête retombe vers la forêt. Sous la pluie la lecture est
  meilleure encore — la brume sépare les plans.

⚠️ **Une flèche de la couronne passe devant Keepy à la station B.** C'est ce
à quoi ressemble le fait de se tenir DANS un bosquet, et non le piège de la
bande caméra : rien ici n'est planté dans une bande où le joueur marche à z
constant. Signalé plutôt que maquillé — c'est la première chose à regarder
sur device.

## Ce que ce lot ne fait PAS

Aucun asset généré, supprimé, renommé ni dédupliqué. Le domaine n'a pas été
agrandi, sa forme n'a pas changé, son emplacement non plus — **PHASE J relit
son AABB après la passe**. `VehicleDrive.gd`, `KartBody.gd:218`,
`SEA_RADIUS`, `SEA_CENTRE` : non touchés. Rien de CH36/CH37/CH38/CH39
retouché hors `CozyScatter` et `MountainProbe`. `LakeZoneProbe`,
`V6CrittersProbe`, `ChargerAudit`, `AirEnemyLandingLaneAudit` non rouverts ;
`WaterTintProbe` et `SeesawProbe` restent à leurs rouges préexistants et ne
sont présentées vertes nulle part. Aucun hérisson.

## Ce que ce lot laisse ouvert

1. **La validation device**, aux deux mêmes stations, overlay `?keepydev=1`.
   La projection sandbox dit 47 014 et 42 493 primitives ; c'est ce chiffre
   qu'il faut confronter.
2. **La marge du budget est de 125 triangles** (5 875 sur 6 000). C'est
   volontaire — le plafond a taillé la conception — mais un lot qui ajoute
   une seule pièce sur ce domaine passera au rouge, et c'est la réponse
   attendue.
3. **La mesure device complète CH35-B tâche 4** reste due, et c'est elle qui
   dira si le plafond de 50 000 est le bon nombre.
4. Lot 3 véhicule sur surface ; lot 4 luge.
