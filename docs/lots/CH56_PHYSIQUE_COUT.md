# CH56 — LOT 0 : ce que coûte un tick de physique, mesuré

**9 septembre 2026.** Lot de **mesure seule**. Aucun collider ajouté à un
module, aucune scène de jeu modifiée, aucun script de gameplay touché. Le
livrable est `scripts/dev/PhysicsCostProbe.gd` (+ `.tscn`), sonde
**permanente**, et ce fichier.

CH55 §7.1 s'arrêtait sur une phrase : « **AUCUNE MILLISECONDE N'A ÉTÉ
MESURÉE DANS CE LOT** [...] le tableau 4.3 est une échelle, pas une
prédiction », et §4.4 concluait « ce n'est pas décidable sans une mesure,
et cette mesure n'existe pas ». Voici la mesure.

---

## 0. LA BASE, ET LA GARDE DE CONCURRENCE

Branche ouverte sur `main` (`2876f27`) et **re-basée sur `origin/staging`**
(`cf2b1fd`) avant la première lecture : `git log origin/staging..origin/main`
est **vide** — `main` est intégralement contenu dans `staging`, c'est un
retard et pas une divergence. CH50 → CH55 vivent sur `staging`.

Garde faite **au début et par ARBRE**, jamais par nom :

| ref | verdict |
|---|---|
| `origin/claude/physics-cost-probe-v5q67p` (mon homonyme) | arbre `9a1d2a9` = celui de `main`, **aucun travail dessus** |
| `origin/claude/keepy-hub-physics-foundation-siqdqo` | `merge-base --is-ancestor` → **déjà dans `staging`** (CH55) |
| `claude/skateboard-drivability-north-lgmqk8`, `…budget-nord-v5a3id`, `…trick-minijeu-xyuy9a`, `…zone0-nord-ezbguf` | toutes **ancêtres de `staging`** (CH54, CH53, CH52, CH50) |

Aucune session concurrente vivante.

---

## 1. LES TROIS PRÉMISSES DE CONFIG, LUES ET NON SUPPOSÉES

CH55 §7.3 et §7.4 déduisaient tout le modèle de coût de l'**absence** de
deux réglages. Une absence est une bonne raison d'attendre un défaut et une
mauvaise raison d'en publier un, donc `PhysicsCostProbe` PHASE C les relit
**sur le moteur qui tourne** et lit `export_presets.cfg` **sur le disque** :

```
ticks/s 60   max_steps/frame 8   jitter_fix 0.50   gravity 9.80
engine 'DEFAULT'   run_on_separate_thread false
export_presets.cfg: 'variant/thread_support=true' present = false
```

Les trois points du brief sont **confirmés**, et ils sont désormais gatés
en permanence (C1, C2, C3, C5) plutôt que déduits une fois.

---

## 2. ⚠️ LE PREMIER INSTRUMENT PROPOSÉ EST FAUX — `TIME_PHYSICS_PROCESS` EST UN **MAXIMUM PAR SECONDE**

CH55 §5 prescrivait de publier `Performance.TIME_PHYSICS_PROCESS`. La
première version de la sonde l'a fait, sur 240 ticks, et a rendu ceci :

| forme | N=0 | N=6 | N=20 | N=100 |
|---|---|---|---|---|
| convexe | 0,4360 | 0,6640 | 0,6640 | **4,9134** |
| trimesh | **19,2070** | 20,0890 | 20,0890 | 20,0890 |

Deux choses sautent aux yeux et **aucune des deux n'est un résultat** : les
valeurs se répètent **au dix-millième près** entre cinq constructions
fraîches (spread 0,0000), et un monde à **zéro** collider statique lit
**19,2 ms** pendant qu'un monde à cent en lit 4,9. **Un moniteur dont la
lecture BAISSE quand le monde grandit ne mesure pas le monde.**

La sonde ne le conclut pas de mémoire : elle **compte les changements de
valeur**. Sur 75 fenêtres de 600 ticks (10 s simulées chacune), le moniteur
change **au plus 4 fois** — c'est-à-dire environ **une fois par seconde**.
C'est un **maximum glissant publié une fois par seconde**, pas un coût par
tick, et le moyenner revient à moyenner une poignée de pics périmés.

**Gate permanent MON1** : `changes ≤ secondes + 2`. Le moniteur reste
**imprimé** dans chaque tableau (colonne `monMAX`) et **jamais utilisé**.

**L'instrument retenu** est l'horloge murale sur la fenêtre mesurée,
divisée par le nombre de ticks. Sous `--fixed-fps 60` la boucle principale
est **désynchronisée du temps réel** : une itération = un pas de physique,
et `max_physics_steps_per_frame` **ne peut pas s'engager**. La ligne N=0 de
la courbe B publie ce que coûte « tout le reste » : **0,0086 ms/tick**.

---

## 3. CE QUE LA SONDE PROUVE AVANT DE PUBLIER QUOI QUE CE SOIT

### 3.1 Contrôle d'instrument (PHASE I) — le banc restitue un chiffre au dossier

La géométrie n'est pas un cube : ce sont les **cinq modules livrés**,
construits par `SkateparkMesh` via `HubSkatepark._mesh_for()` — la table
de correspondance n'est **pas retapée**, une instance de `HubSkatepark`
est créée hors arbre et sa propre méthode appelée.

```
funbox        20 tris   trimesh 1 shape   convex 12 piece(s)
rail          36 tris   trimesh 1 shape   convex  4 piece(s)
quarterpipe   50 tris   trimesh 1 shape   convex 15 piece(s)
bowl         312 tris   trimesh 1 shape   convex 32 piece(s)
park total 468 triangles (on file: 468)
```

**468 = le chiffre de CH53, à l'unité.** Un banc incapable de le restituer
n'aurait pas qualité à publier un chiffre neuf.

### 3.2 ⚠️ ET CE CONTRÔLE A REFUSÉ DE PUBLIER **DEUX FOIS**, sur la décomposition convexe

D5 tranche « pièces convexes, jamais un trimesh ». Encore faut-il que le
banc en construise.

1. **`Mesh.convex_decompose()` N'EXISTE PAS sur `ArrayMesh` en 4.3.** Le
   premier jet est mort sur `Nonexistent function 'convex_decompose' in
   base 'ArrayMesh'`. L'entrée exposée est
   `MeshInstance3D.create_multiple_convex_collisions()`.
2. **Appelée sans réglages, elle n'est PAS une décomposition.**
   `MeshConvexDecompositionSettings.max_convex_hulls` vaut **1** par
   défaut : les quatre familles sont revenues à **un hull chacune**, et le
   gate I3 est sorti **ROUGE** (« 0 of 4 kinds came back as more than one
   hull »). Porter le plafond à 32 **n'a rien changé** — `max_concavity`
   vaut **1,0** par défaut, la valeur la plus permissive qui soit, et VHACD
   accepte un profil balayé concave comme « assez convexe ». Il faut les
   **deux** boutons, et c'est le second qui travaille.

Sans ce gate, tout le lot aurait publié le prix d'**un hull par module** en
l'appelant le prix des pièces de D5.

### 3.3 Le témoin est le SERVEUR, jamais l'arbre de scène

Compter des nœuds prouve qu'une sonde a construit des nœuds. Ce qu'il faut
prouver est que le **`PhysicsServer3D`** les tient. Deux canaux
indépendants, à chaque point mesuré :

* **W1 — le registre du serveur** : l'arbre est **parcouru** pour tout
  `CollisionObject3D` (jamais la liste que la sonde s'est constituée : un
  registre bâti sur « ce que je crois avoir créé » ne peut pas rapporter un
  corps fuité du point précédent), et chaque RID est interrogé par
  `body_get_space()` / `body_get_shape_count()`.
* **W2 — une requête vivante** : `intersect_shape` d'une sphère de 400 u
  sur tout le banc. ⚠️ Elle est lancée **depuis `_physics_process`** et
  jamais depuis une phase : un `PhysicsDirectSpaceState3D` refuse de
  répondre pendant un flush, et le refus est **une ligne d'erreur plus un
  résultat VIDE** — c'est-à-dire indiscernable de « l'espace ne contient
  rien », c'est-à-dire du blind check qui passe.

À N=100 convexe, les deux lisent **1 562 formes** (1 560 + sol + capsule).

### 3.4 Blind check (PHASE V), **ordonné positif d'abord**

```
void      : server bodies 0 shapes 0 | query hits 0 | active 0 pairs 0 islands 0
+1 actor  : server bodies 2 shapes 2 | query hits 2 | active 1 pairs 1 islands 1 | on_floor true
void again: server bodies 0 shapes 0 | query hits 0
```

Le zéro du début et celui de la fin ne valent que par l'étape du milieu :
un corps est ajouté et **les quatre témoins doivent BOUGER** (V4→V7). Les
trois moniteurs `PHYSICS_3D_*` bougent tous (`0→1`), et la capsule est
`on_floor` — la narrowphase a réellement tourné.

⚠️ **V7 est sorti ROUGE une fois sur un banc qui marchait** : la capsule
naissait à y=2,0 et met ~0,64 s à tomber, plus que le temps de repos de la
phase. « Il n'est pas au sol » était **vrai** et voulait dire « il tombe
encore ». Corrigé à la source (naissance à 0,6 u), pas en relâchant le
gate.

Et à **chaque** point de chaque courbe, la sonde exige `contacts > 0` :
une capsule en chute libre n'exerce aucune narrowphase et publierait le
coût d'un moteur qu'on n'a jamais fait travailler. Toutes les lignes
lisent **600/600**.

---

## 4. ⚠️ LE PLANCHER DE BRUIT GLOBAL EST LE MAUVAIS PLANCHER

Première version : un plancher unique, le pire spread du banc — **0,3328
ms**, tiré du point B_100. Gate MOD4 rouge sur un `+0,2234` parfaitement
réel, parce que le tremblement auquel on le comparait venait d'**un autre
point**, quatorze fois plus grand.

C'est mot pour mot ce que `CLAUDE.md` (CH41) interdit : « *la mesure est
gatée PAR STATION contre le tremblement DE CETTE STATION [...] Un gate
global (pire delta contre pire tremblement) est soit gratuit, soit faux.* »

Corrigé : `_floor_between([points])`. Chaque comparaison porte le
tremblement **des deux points qu'elle compare**. Le pire spread du banc
reste **publié**, comme information.

Deux estimations indépendantes du plancher sont publiées à chaque run :
le **spread entre 5 constructions fraîches** par point, et la **dérive
d'une moitié de fenêtre à l'autre** à l'intérieur d'un même run — la
seconde voit une dérive que la première ne peut pas voir.

---

## 5. LA COURBE — headless, `--fixed-fps 60`, Xeon 2,80 GHz, 5 répétitions × 600 ticks

### 5.1 Courbe A — N colliders STATIQUES, **une** capsule mobile

Le travail par tick de la sonde est **constant** ici (un seul
`move_and_slide`), donc toute pente appartient au moteur.

| N | convexe ms/tick | spread | formes | trimesh ms/tick | spread | formes |
|---|---|---|---|---|---|---|
| 0 | 0,2125 | 0,0037 | 2 | 0,2120 | 0,0122 | 2 |
| 1 | 0,2205 | 0,0305 | 14 | 0,2450 | 0,0299 | 3 |
| 6 | 0,2215 | 0,0213 | 92 | 0,2488 | 0,0299 | 8 |
| 20 | 0,2261 | 0,0224 | 314 | 0,2249 | 0,0160 | 22 |
| **100** | **0,2225** | 0,0284 | **1 562** | **0,2268** | 0,0135 | 102 |

**Montée sur cent modules : +0,0100 (convexe), +0,0149 (trimesh) — c'est
la TAILLE DU TREMBLEMENT à ces stations (0,0284 / 0,0135).** Le banc
publie donc une **BORNE SUPÉRIEURE** et pas une pente :

* **un module statique convexe coûte au plus 0,00028 ms/tick** ;
* **une PIÈCE convexe au plus 0,000018 ms/tick** (1 560 formes à N=100) ;
* **un module statique trimesh au plus 0,00017 ms/tick**.

Ce n'est pas un échec de mesure et la sonde le prouve : **le même
instrument bouge de 3,42 ms sur le balayage identique de la courbe B**.

### 5.2 Courbe B — N corps MOBILES contre le park réel (5 modules, convexe)

| N | ms/tick | min | max | spread | pairs | islands |
|---|---|---|---|---|---|---|
| 0 | **0,0089** | 0,0085 | 0,0090 | 0,0005 | 0 | 0 |
| 1 | 0,2278 | 0,2227 | 0,2413 | 0,0186 | 1 | 1 |
| 6 | 0,4524 | 0,4129 | 0,5301 | 0,1172 | 16 | 6 |
| 20 | 0,9410 | 0,9281 | 1,1209 | 0,1928 | 50 | 20 |
| 100 | **3,6518** | 3,4421 | 3,7038 | 0,2617 | 122 | 100 |

* **le PREMIER corps mobile coûte +0,2189 ms/tick** (tremblement de station
  0,0186 → **RÉSOLU**) ;
* **chaque corps supplémentaire 0,0344 ms/tick**, soit **6,3× moins**.

⚠️ **Ces deux nombres décrivent deux choses différentes, et il faut les
deux.** Le premier corps est celui qui roule **sur la funbox** et résout un
contact à chaque tick ; les 99 autres marchent sur un plan. **Un corps qui
RÉSOUT un contact n'est pas un corps qui marche**, et un modèle qui
n'emporterait que la pente marginale sous-facturerait d'un facteur 6.

### 5.3 Reproductibilité

Trois runs headless successifs, seuls sur la machine (jamais en parallèle —
`CLAUDE.md` : *« une sonde à séquence temporelle se rejoue à charge
comparable, ou son verdict n'est pas comparable »*, et j'ai commis puis
corrigé cette erreur en cours de lot) :

| | run A | run B | run C |
|---|---|---|---|
| pièce du corps marginal | 0,03459 | 0,03437 | 0,03435 |
| premier corps | +0,2189 | +0,2300 | +0,2152 |
| `VehicleDrive.step()` marginal | 0,00456 | 0,00441 | 0,00455 |
| rapport physique / incumbent | ×7,58 | ×7,79 | ×7,54 |

---

## 6. D5 PRICÉ **EN CONTACT** — et le banc ne sépare pas les deux formes

La courbe A monte N en ajoutant des modules que la capsule **ne touche
jamais** : c'est délibéré (pression de broadphase et travail de narrowphase
sont deux coûts, et un banc qui les monterait ensemble ne pourrait pas dire
lequel il a mesuré). Conséquence : sa colonne trimesh compare deux formes
que la capsule ne rencontre qu'à travers **une funbox de 20 triangles**.

PHASE T les compare donc là où la différence vit : une capsule **DANS le
bol**, le module de **312 triangles** qui fait les deux tiers du park,
même station, même mouvement, même fenêtre, seule la forme change.

| forme | ms/tick | spread | formes |
|---|---|---|---|
| pièces convexes (32 hulls) | 0,5744 | 0,1750 | 34 |
| trimesh (312 triangles) | 0,4984 | 0,0713 | 3 |

**Différence −0,0760 ms/tick, plancher de station 0,4963. SOUS LE
PLANCHER.** Reproduit sur trois runs (−0,076 / −0,097 / −0,085), toujours
sous le plancher, **et toujours du même signe** : à cette échelle le
trimesh n'est pas plus cher, il serait plutôt marginalement moins cher (une
forme contre trente-quatre).

> **Conséquence pour D5 : l'arbitrage tient, et il ne tient PAS sur un
> argument de coût.** Il tient entièrement sur le piège silencieux —
> `ConcavePolygonShape3D.backface_collision` vaut **`false`** (relu par la
> sonde, publié à chaque run), donc un trimesh mal enroulé est un sol à
> travers lequel on tombe sans une erreur. C'est CH39 transposé. Si un lot
> futur veut rouvrir D5, ce qu'il doit produire est un argument sur
> l'enroulement, pas un chiffre : **le chiffre est là et il ne tranche
> pas**.

---

## 7. ⚠️ LA QUESTION QUI REND « AFFORDABLE » DÉCIDABLE : CONTRE QUOI ?

CH55 §1.3 : « *Le hub n'a pas « pas de physique ». Il a une physique
cinématique maison, sur trois véhicules, dont deux validés device.* »
`VehicleDrive.step()` est un intégrateur de vitesse complet — braquage sur
le cap, décomposition avant/latéral, adhérence exponentielle, scrub, frein,
marche arrière, clôture `Rect2` à rebond — et le hub le **paie déjà** à
chaque tick où un véhicule est piloté.

PHASE K le fait tourner **exactement comme `SledBody` l'appelle** (position
plate, yaw du nœud, vélocité monde, la même `WORLD_FENCE`, le même
`KartTuning.steer_rate() * STEER_RATIO`), même balayage, même fenêtre,
même pièce que la courbe B.

| N | incumbent ms/tick | courbe B ms/tick |
|---|---|---|
| 0 | 0,0089 | 0,0089 |
| 1 | 0,0152 | 0,2278 |
| 6 | 0,0392 | 0,4524 |
| 20 | 0,1006 | 0,9410 |
| 100 | 0,4670 | 3,6518 |

* **marginal** : 0,00456 (incumbent) contre 0,03459 (physique) → **×7,58** ;
* **premier corps** : +0,0063 contre +0,2189 → **×34,7**.

> **C'est le seul rapport de tout le lot qui n'a PAS besoin d'une lecture
> device** : les deux moitiés ont tourné sur la même machine, dans la même
> fenêtre, donc la machine se simplifie.

Honnêteté sur ce que le rapport contient : `VehicleDrive` **ne fait aucune
détection de collision** (son mur est un `Rect2` analytique), là où
`move_and_slide()` fait jusqu'à quatre balayages de forme plus l'accrochage
au sol. Le ×7,58 est donc le prix du **travail en plus**, pas une
inefficacité — et ce travail en plus est exactement ce que le lot 1 veut
acheter.

---

## 8. ⚠️ LA PIÈCE OÙ ON MESURE FAIT PARTIE DE LA MESURE — et `xvfb` ne peut pas la faire

Le brief demandait `xvfb-run --rendering-driver opengl3`, **pas
`--headless`**, en citant le faux vert d'un compteur headless. La sonde a
tourné sous les deux, et **sous `xvfb` elle refuse de publier**.

Ce n'est pas une opinion, c'est PHASE R, la première phase après le blind
check : la pièce **avec** un corps mobile contre la pièce **sans**, cinq
répétitions chacune. C'est le plus petit delta que la sonde compte publier
— une pièce qui ne le voit pas ne verra rien en dessous non plus.

| driver | pièce sans corps | avec un corps | signal | tremblement | verdict |
|---|---|---|---|---|---|
| **headless** | 0,0085 | 0,2352 | **+0,2266** | 0,0213 | **RÉSOLU** |
| **xvfb + opengl3** | 7,9657 | 8,2251 | +0,2593 | **2,5000** | **NON RÉSOLU** |
| xvfb, run précédent | 10,4941 | 7,0417 | **−3,4524** | 4,1161 | non résolu |

**Sous llvmpipe, le signe du signal change d'un run à l'autre.** La cause
est mesurée et nommée : le rasteriseur logiciel redessine une fenêtre
1080×1920 vide **à chaque itération**, à ~8,5 ms avec ±2 ms de tremblement,
et **tout le soulèvement de cent corps de la courbe B vaut 2,1 ms**. Deux
assertions du lot sont sorties ROUGES sur un banc parfaitement sain avant
que PHASE R n'existe.

**Ce que la sonde fait de ça n'est ni un vert ni un rouge : `EXIT 3`, « NO
VERDICT ».** C'est le raisonnement de `ProbeWatchdog` pour son code 2,
appliqué à une autre absence de verdict : un banc dont le tremblement
dépasse la grandeur mesurée n'a rien vérifié et rien réfuté, et le
rapporter comme une violation serait rapporter une trouvaille jamais faite.

> ⚠️ **DOCTRINE, et elle contredit une consigne de brief pour une raison
> mesurée** : la règle `CLAUDE.md` « toute sonde qui lit un pixel tourne
> sous `xvfb`, toute sonde qui ne lit que des transforms tourne en
> headless » a un **troisième cas** que ce lot vient de payer — une sonde
> qui mesure du **TEMPS CPU** doit tourner là où rien d'autre n'en consomme,
> c'est-à-dire **en headless**, et le driver dummy ne peut pas la tromper
> parce qu'elle ne lit aucun pixel : ses témoins sont le serveur physique et
> une requête d'espace, dont **aucun** n'a de rapport avec le rendu.

### 8.1 Et la pièce refusée, mesurée (PHASE Z)

CH55 proposait de mesurer « dans le monde du hub ». La sonde ne l'affirme
pas fausse, elle la mesure : `HubWorld` est instancié et chronométré.

```
driver X11: HubWorld renders at 120,28 ms/frame (8,3 FPS on THIS machine)
at that frame time a real-time engine runs 7,22 physics steps per frame
```

**7,22 pas de physique par frame rendue, contre un
`max_physics_steps_per_frame` de 8.** C'est exactement la condition sous
laquelle `TIME_PHYSICS_PROCESS` cesse d'être un nombre par tick, et la
raison mesurée pour laquelle le banc est nu : sous `--fixed-fps 60` ce
clamp **ne peut pas s'engager**, donc chaque lecture du §5 est **UN** tick.

---

## 9. LA QUESTION DE CH55 §7.5, FERMÉE : `Area3D.monitoring` NE COÛTE RIEN DE MESURABLE

`HubPortal.gd` affirme que `monitoring = false` économise « *a broadphase
entry per frame* », et CH55 §7.5 trouvait la formulation douteuse (une
forme reste dans la broadphase de toute façon ; ce que `monitoring` achète
est l'appairage et le rappel), en notant que c'était gratuit à vérifier au
lot 0.

PHASE M, cent `Area3D` portant **la forme exacte de `HubPortal`**
(`CylinderShape3D` r 1,35 / h 3,0, centre y 1,5) :

| monitoring | N | ms/tick |
|---|---|---|
| false | 3 | 0,2346 |
| false | 100 | 0,2415 |
| true | 3 | 0,2399 |
| true | 100 | 0,2330 |

**Écart à N=100 : +0,0037 / −0,0085 / −0,0408 sur trois runs, plancher de
station 0,0307 à 0,0439. Sous le plancher, et de signe instable.**

⚠️ **Et la phase porte son témoin, sans quoi elle serait gratuite** : une
aire qui ne recouvre rien n'a rien à rapporter, `monitoring` ou pas. La
sonde exige donc qu'au moins une aire ait **réellement tenu la capsule**
(`get_overlapping_bodies()`), et gate là-dessus — **11 à 12 recouvrements**
observés.

**Conclusion : `monitoring = false` sur `HubPortal` est un choix de
CORRECTION (le portail refuse le recouvrement, il ne répond qu'à un
atterrissage — son en-tête le dit), pas une économie mesurable.** La
phrase de coût dans son en-tête est à lire comme une justification *a
posteriori*, pas comme un fait. Signalé, non corrigé : c'est un
commentaire, il ne change aucun comportement.

---

## 10. LE MODÈLE DE COÛT

Tout ce qui suit est de l'arithmétique sur le §5, sur **cette** machine.

### 10.1 Où est le coût

| poste | ms/tick | ce que ça pèse |
|---|---|---|
| boucle + 5 modules statiques, **aucun** corps mobile | **0,0086** | le sol du modèle |
| + les 5 colliders de modules (bornés) | ≤ 0,0014 | **négligeable, mesuré** |
| + **UN** corps mobile qui résout un contact | **+0,2189** | **~96 % du total** |
| chaque corps mobile de plus | +0,0344 | |

> **Le coût n'est ni dans les colliders, ni dans la forme de collision. Il
> est dans le CORPS MOBILE, et surtout dans le PREMIER.** C'est la
> découverte structurante du lot, et elle est bonne pour la forme B : la
> forme B ajoute **exactement un corps mobile**, ce qui est le minimum
> qu'un moteur physique puisse coûter dans ce monde.

### 10.2 Le facteur d'amplification, confirmé

WASM mono-thread (§1) et physique à 60 Hz fixes → coût par frame rendue =
`ms/tick × (60 / FPS)`. Forme B = **0,2278 ms/tick** :

| FPS | pas/frame | forme B ms/frame | % de la frame |
|---|---|---|---|
| 60 | 1,00 | 0,2278 | **1,37 %** |
| 56 (lecture device fraîche de Mathieu) | 1,07 | 0,2440 | 1,37 % |
| 50 (plancher CH52) | 1,20 | 0,2733 | 1,37 % |
| 46 | 1,30 | 0,2971 | 1,37 % |

### 10.3 ⚠️ LE SEUL INCONNU QUI DÉCIDE, ET IL EST NOMMÉ

Tout le §5 est un build x86 natif sur un Xeon 2,80 GHz ; le téléphone
exécute du WASM mono-thread. Appelons **F** ce rapport. Il est **INCONNU**
et **ce lot ne peut pas le mesurer** (CH55 §7.6 le disait déjà).

| F | forme B ms/tick | ms/frame à 50 FPS | % d'une frame de 20 ms |
|---|---|---|---|
| 1 | 0,2278 | 0,2733 | 1,4 % |
| 3 | 0,6833 | 0,8200 | 4,1 % |
| 5 | 1,1389 | 1,3666 | 6,8 % |
| 10 | 2,2777 | 2,7333 | **13,7 %** |
| 20 | 4,5555 | 5,4666 | **27,3 %** |

**Une seule lecture device fixe F** : la même scène avec et sans un corps
physique.

### 10.4 Combien de corps mobiles rentrent (à 50 FPS, sur CETTE machine)

| budget ms/frame | ms/tick permis | corps mobiles |
|---|---|---|
| 0,10 | 0,0833 | **0** |
| 0,25 | 0,2083 | **0** |
| 0,50 | 0,4167 | 6 |
| 1,00 | 0,8333 | 19 |
| 2,00 | 1,6667 | 43 |

⚠️ **Les deux premières lignes rendent ZÉRO, et ce n'est pas la pente qui
les tue : c'est l'INTERCEPT.** Le premier corps coûte 0,219 ms/tick, donc
0,263 ms/frame — au-dessus des budgets de 0,10 et 0,25 ms **avant même
d'avoir un second corps**. Un budget de physique dans ce hub s'achète par
tranches d'un premier corps, pas par corps.

---

## 11. VERDICT : **AFFORDABLE, ET LA CONDITION EST UNE LECTURE DEVICE — PAS UN AUTRE LOT DE MESURE**

Le lot avait le droit de dire non. Il ne le dit pas, et voici pourquoi, en
séparant ce qui est mesuré de ce qui ne l'est pas.

**Ce qui est mesuré et qui plaide POUR :**

1. **Un collider statique ne coûte rien.** Cent modules — **1 560 formes
   convexes** — restent sous le tremblement du banc. Les cinq colliders du
   park coûtent au plus **0,0014 ms/tick**.
2. **La forme de collision ne coûte rien non plus**, même sur le bol de
   312 triangles. D5 est un arbitrage de sûreté, pas de budget.
3. **Zéro primitive, zéro draw call** : un collider ne dessine rien. C'est
   exactement la monnaie dont CH52 §8.3 mesure qu'il n'en reste **aucune**
   au bord nord, et la physique localisée n'en dépense **pas une**.
4. **La forme B ajoute UN corps mobile.** À 1,37 % d'une frame sur cette
   machine, et **×7,6 seulement** ce que le hub paie déjà par véhicule
   cinématique — un rapport qui, lui, ne dépend pas de la machine.

**Ce qui n'est pas mesuré et qui pourrait faire tomber la réponse :**

5. **F.** À F = 10, la forme B mange **13,7 %** d'une frame de 20 ms, sur
   une frame que CH52 déclare pleine. C'est le seul chiffre qui décide, et
   il se lit sur un téléphone, pas ici.

**Donc :**

> **LOT 1 est autorisé à être TENTÉ, et il porte son propre gate device.**
> Il n'ajoute aucune primitive, aucun draw call, un seul corps mobile, et
> cinq colliders dont le coût est mesuré négligeable. Le lot 1 doit livrer
> **derrière un interrupteur** (`DevTools`) de sorte qu'une seule lecture
> device — même station, physique ON puis OFF — mesure **F** et rende la
> question définitivement décidable.
>
> **CE QUI N'EST PAS AFFORDABLE, et le chiffre le dit** : tout ce qui
> MULTIPLIE les corps mobiles. La forme A (le pied physique) ajoute un
> corps qui résout des contacts en permanence, c'est-à-dire un second
> **premier corps** (+0,219 ms/tick), et des PNJ physiques en ajouteraient
> un chacun. À F = 10 et 50 FPS, **quatre** corps mobiles dépassent 20 %
> d'une frame. Le décor solide reste hors de question pour la raison de
> CH55 (un `MultiMesh` ne peut pas collider, donc un draw call par prop,
> sur un budget de zéro) — et ce lot n'y change rien.

---

## 12. ZONES D'INCERTITUDE — dites, pas maquillées

1. **F n'est pas mesuré**, et il est le seul nombre qui décide. Tout le
   §10.3 est une sensibilité, pas une prédiction.
2. **Le banc est NU.** Il ne mesure aucune contention avec le rendu réel du
   hub, et il ne le peut pas ici (PHASE Z : 8,3 FPS sous llvmpipe). Sur
   device, la physique et le rendu partagent un thread : le coût mesuré
   s'**ajoute**, mais un cache pollué par la physique pourrait coûter plus
   que la somme. Non mesuré, non nul.
3. **Les pièces convexes sont celles de VHACD, pas celles que le lot 3
   écrirait.** 12 hulls pour une funbox de 20 triangles est du sur-découpage,
   et le bol **plafonne à 32** (le vrai chiffre est ≥ 32). Le nombre
   transférable est donc **le coût par PIÈCE** (≤ 0,000018 ms/tick), pas le
   coût par module — et il est si petit que le sur-découpage ne change rien
   à la conclusion.
4. ⚠️ **Un bol décomposé en hulls convexes est GÉOMÉTRIQUEMENT FAUX** : une
   cuvette ouverte devient un tas de solides pleins, c'est-à-dire un bol
   qu'on ne peut pas descendre. Ce lot n'en mesure que le **coût**, jamais
   la justesse. **Le lot 3 doit ÉCRIRE À LA MAIN ses pièces** (un anneau de coins),
   pas les laisser deviner par VHACD — et c'est déjà ce que D5 dit en citant
   `SledBody.PIECE_TRIS`.
5. **Le « premier corps » est cher parce qu'il résout un contact**, et le
   contact mesuré est une funbox. Un corps qui roulerait dans le bol
   pourrait coûter davantage (PHASE T mesure 0,57 ms/tick pour cette
   configuration, capsule dans la cuvette). **La borne haute honnête pour un
   carrier en contact permanent est donc ~0,57 ms/tick, pas 0,23.**
6. **Aucun pixel n'a été rendu, aucun device n'a été touché**, et rien du
   gameplay n'a été essayé : personne n'a encore vu une planche s'arrêter
   contre un module.
7. **`max_physics_steps_per_frame` n'a jamais été exercé** : `--fixed-fps`
   l'empêche par construction. La contre-réaction positive que CH55 §4.2
   décrit (une frame lente accumule, la suivante exécute deux pas, donc
   coûte plus) est **arithmétiquement reconduite ici, pas observée**.
8. Le rapport ×7,58 contre l'incumbent compare un `move_and_slide()` **qui
   détecte des collisions** à un intégrateur **qui n'en détecte aucune**.
   C'est le prix du travail en plus ; ce n'est pas une inefficacité de
   Godot.

---

## 13. NEXT STEPS

| # | quoi | pourquoi |
|---|---|---|
| 1 | **Lecture device de Mathieu au park, overlay ouvert** — `FPS min` + `TRI gpu` en (−10 ; 51) | déjà next-step #1 de CH52, de CH53 et de CH55, toujours pas faite ; c'est aussi la moitié de la mesure de **F** |
| 2 | **LOT 1**, la funbox seule + la planche en `CharacterBody3D`, **derrière `DevTools`** | l'interrupteur est ce qui transforme le lot en **mesure de F** au lieu d'un pari |
| 3 | Rejouer `PhysicsCostProbe` sur l'arbre du lot 1 et comparer à ce fichier | la sonde est permanente précisément pour ça |
| 4 | Décisions **D3** (espace physique / `own_world_3d`) et **D6** (caméra de poursuite) | non tranchées, et D6 est un `ChaseAudit` du lobe à lui seul (CH52 §8.5) |

---

## 14. DOCS STATUS

Ce fichier, plus une ligne dans `docs/lots/INDEX.md`. **Une seule doctrine
réellement nouvelle** est remontée dans `CLAUDE.md` : le troisième cas de
la règle headless/xvfb — **une sonde qui mesure du TEMPS CPU se lance en
headless**, parce que dans ce sandbox le rasteriseur logiciel a un
tremblement propre plus grand que tout le signal, et parce qu'un banc dont
le plancher dépasse sa grandeur doit rendre **une absence de verdict** et
non un rouge. Les autres trouvailles (le moniteur `TIME_PHYSICS_PROCESS`
est un maximum par seconde ; `create_multiple_convex_collisions()` sans
réglages n'est pas une décomposition) sont des **pièges d'API Godot 4.3** et
vivent ici, dans le fichier de leur chantier, comme la règle d'écriture
additive l'exige.

`ProbeTimeoutAudit` : **90 scènes de sonde** contre 89 avant ce lot —
`PhysicsCostProbe` est la seule ajoutée, elle arme `ProbeWatchdog` en
première instruction, et l'audit reste **PASSED**.
