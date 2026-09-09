# CH61 — LOT 3c : la planche gagne une vraie vélocité (inertie, gravité, élan)

> Six sections. Le lot part d'un verdict device de Mathieu sur le build
> CH60 — « je sens bien la physicalité là où elle devait être
> implémentée, mais je n'arrive pas du tout à monter les rampes, je suis
> juste bloqué, ce n'est pas jouable en l'état » — et la première mesure
> a renversé la moitié du diagnostic que CH60 avait laissé au dossier.

## Section 1 — ⚠️ LA MOITIÉ DU DIAGNOSTIC DE CH60 EST TOMBÉE, ET ELLE EST TOMBÉE À L'ARITHMÉTIQUE DE SES PROPRES DEUX CHIFFRES

CH60 avait chiffré le plafond à l'avance — **0,577 u atteint sur un lip
dessiné à 2,10 u**, **0,386 u sur 1,45 u** — et l'avait lu comme « la
conséquence honnête d'un corps cinématique sans inertie ». Le brief de ce
lot reprend cette lecture.

Elle est fausse, et les deux chiffres de CH60 suffisent à le montrer. Mis
sur leurs propres lips :

| module | atteint | lip | fraction |
|---|---|---|---|
| quarterpipe 2 | 0,577 | 2,10 | **0,2748** |
| quarterpipe 3 | 0,386 | 1,45 | **0,2662** |

**La même FRACTION de deux rampes différentes, pas la même HAUTEUR.** Un
plafond d'énergie est une hauteur **ABSOLUE** — `v² / 2g`, qui à la
croisière CH54 de 10,0 u/s et à la gravité 26,0 de ce fichier vaut
**1,923 u**, au-dessus des **deux** lips. Un plafond qui change avec la
rampe est un plafond de **FORME**, et la section 6 de CH60 le nomme sans
en tirer la conclusion : `floor_max_angle` vaut le 45° de Godot, les
facettes du profil valent 3,75 / 11,25 / … / 86,25°, donc la dernière
facette tenable est la sixième et le point le plus haut atteignable vaut

```
P6 = height × (1 − cos 45°) = 0,29289 × height
```

0,2748 et 0,2662 sont ce nombre, moins l'offset de contact de la capsule.
**La planche n'a jamais manqué d'énergie. On lui disait, à chaque tick,
que la septième facette est un MUR.**

Le lot fait donc **les deux** choses, et l'une sans l'autre n'achète
rien : un corps avec de l'inertie contre un cap à 45° cale toujours à
29 %, et un cap relevé sous une allure dictée monte à la hauteur que
l'allure atteint, quelle que soit la vitesse d'arrivée. La décomposition
mesurée est en section 4.

## Section 2 — la loi de mouvement livrée

`SkateBoardBody.drive()` ne réécrit plus la vitesse horizontale depuis un
profil : elle **PERSISTE**, et quatre termes agissent dessus, dans cet
ordre.

1. **LE PUSH.** Un pied sur le sol, donc horizontal, plafonné à
   `cruise` **LE LONG DU CAP** — un skateur ne pousse pas plus vite que
   ses jambes ne battent, et c'est ça, pas une traînée, qui fait de la
   croisière une vitesse maximale — et **mis à l'échelle par `n.y` =
   cos(pente)**. Ce facteur n'est pas un goût : la force qu'un pied
   transmet au sol est bornée par le frottement, le frottement est
   proportionnel à la force normale, et la force normale sur une pente
   vaut `m g cos(pente)`. **En haut d'une transition il n'y a plus rien
   contre quoi pousser**, ce qui est exactement pourquoi la hauteur
   atteinte est fonction de la vitesse d'ARRIVÉE et non de combien de
   temps le doigt a tenu une cible au-delà de la rampe.
2. **LE BRAKE**, même forme, quand la cible est dans la distance
   d'arrêt. Il vise **zéro vitesse à la frontière `ARRIVE_EPSILON`** et
   non à la cible : sinon la planche franchit la frontière en portant
   encore la vitesse que le frein allait dépenser sur les 0,45 derniers
   u, `at_rest()` passe vrai sous une planche qui roule, et le tap qui
   veut dire « descends » arrive pendant qu'elle bouge.
3. **LE COAST**, un terme quadratique et un terme constant. Le constant
   est ce qui fait qu'une planche lâchée s'arrête en temps **fini** au
   lieu d'asymptoter — la patinoire que `CLAUDE.md` nomme.
4. **LA GRAVITÉ, EN DERNIER.** C'est la règle CH41, et ce dépôt l'a
   payée : « une force injectée AVANT `step()` gèle le véhicule face à la
   montée ». Ici le modèle de conduite EST les étapes 1 à 3, donc la
   gravité se compose **dans la vélocité qu'elles viennent d'écrire**.
   Quand quelque chose porte la planche, elle est appliquée
   **TANGENTIELLEMENT** — `g − n (g · n)` — et c'est tout le lot en une
   ligne : elle **retranche** à une montée et **ajoute** à une descente,
   dans le plan où la planche est réellement. Quand rien ne la porte,
   elle est appliquée entière et la planche est un projectile.

### ⚠️ LES TROIS NOMBRES DE CH54 SURVIVENT — ET ILS SONT RÉSOLUS **CONTRE LE COAST**, PAS DANS LE VIDE

CH54 a mesuré la conduite que Mathieu a demandée — une relance sur
`SKATE_ACCEL_U`, une croisière à `SKATE_CRUISE`, une sortie sur
`SKATE_BRAKE_U`. Ce lot garde les trois nombres et jette la dictée : ils
deviennent les **ACCÉLÉRATIONS** qui les produisent.

⚠️ **Et la première version les a pris à l'identité sans frottement,
`v² = v0² + 2ad`. Mesuré : la relance à plat sortait à 4,492 u contre les
3,20 u écrits par CH54.** Le push a désormais le coast contre lui tout du
long, donc la même accélération achète moins de terrain. Les nombres sans
frottement ne sont pas la conduite de CH54 avec de l'inertie ajoutée —
c'est une conduite plus lente qui porte ses étiquettes.

Les **DISTANCES** sont la chose écrite, les accélérations en découlent.
Avec `v dv/dx = A − k v²` la relance s'intègre en forme fermée :

```
A = k (V² − v0² E) / (1 − E),   E = exp(−2 k accel_u)          push  = A + roll_stop
B = k (V² − v0² F) / (F − 1),   F = exp(+2 k brake_u)          brake = B − roll_stop
```

et le coast lui-même se résout sur sa **distance** et non sur sa
décélération : avec `dv/dt = −(k v² + c)` et une part `s` de la
décélération à croisière portée par le terme quadratique,

```
x = V² ln(1/(1−s)) / (2 s D)   ⟹   D = V² ln(1/(1−s)) / (2 s coast_u)
```

⚠️ **L'écart entre les deux formes vaut un facteur 1,85 et il a été
mesuré, pas repéré.** Une première version posait `D = V²/(2 coast_u)` —
la formule à décélération constante — et la planche a coasté **33,166 u**
contre un park de 18,043 u. La formule est juste pour UN terme et fausse
pour deux : un terme quadratique contribue bien moins de **DISTANCE** que
sa part de la décélération à croisière, parce qu'il s'éteint comme le
carré d'une vitesse qui tombe.

**Ce qui est mesuré après (`SkateInertiaProbe` PHASE L, headless) :**

| grandeur | écrit par CH54 | mesuré sur la loi |
|---|---|---|
| relance jusqu'à 95 % de la croisière | 3,20 u | **3,309 u** |
| croisière atteinte | 10,00 u/s | **9,916 u/s** |
| sortie : distance restante au tap | — | **0,172 u**, à **0,238 u/s** (repos 0,240) |
| coast depuis la croisière | span du park **18,043 u** | **17,876 u** en 4,53 s |

Accélérations résolues : `push 17,2165`, `brake 10,3433`, `drag_k
0,03842`, `roll_stop 1,2805` u/s². Le push est **gaté supérieur** au
13,7109 sans frottement, et le brake **inférieur** — ce qui empêche un
lot ultérieur de « simplifier » la forme fermée en `v² = 2ad`.

⚠️ **La distance de coast n'est pas un quatrième goût** : c'est
`HubSkatepark.park_span()`, la plus grande distance entre deux centres de
modules plus l'empreinte de chacun des deux — **18,043 u**, lue et non
retapée. « Une planche lâchée à pleine vitesse s'arrête dans le park où
elle a été poussée » est donc une propriété du LAYOUT, et elle suit le
layout quand un module bouge.

## Section 3 — ⚠️ CE QUI A ÉTÉ FAIT DE `floor_max_angle`, ET POURQUOI C'EST UNE MESURE

CH57 l'avait laissé au 45° de Godot avec une raison écrite, et la raison
était vraie du seul module solide de l'époque : « la rampe de la funbox
fait 30,6°, donc c'est un SOL ; un mur de la caisse fait 90° et l'arrête.
Rien ici n'a besoin d'être réglé entre les deux. » CH60 a rendu les deux
quarterpipes solides et cette phrase a cessé de couvrir le park, en
silence.

L'angle n'est **pas** réglé vers un ressenti. Les solides de collision du
park ont exactement **DEUX populations** de faces, et l'écart entre elles
est toute la marge de conception. `SkateInertiaProbe` PHASE A les énumère
sur les **triangles DESSINÉS** des quatre modules solides, par leurs
**vraies normales de face** (le produit vectoriel des deux arêtes) et non
par les normales de sommet — CH60 a mesuré ces deux lectures en désaccord
de **jusqu'à 86,25°** sur ce maillage même.

⚠️ **Et la classification se fait sur `|n.y|`, ce qui évacue entièrement
la question de l'enroulement.** `CLAUDE.md`, CH39 : le côté sortant d'une
surface construite à la main se prend dans le MOTEUR, jamais dans les
maths — et une face de pente θ a `|n.y| = cos θ` quel que soit son
enroulement. Rien ici n'a besoin de savoir quel côté est dehors ; il a
besoin de savoir à quel point la face est raide.

| population | faces | extrême |
|---|---|---|
| **surfaces ridées** (deck, rampes, boîtes du rail, 12 cordes de chaque profil) | 140 | la plus raide **86,252°** (quarterpipe 3) |
| **murs** (chaque face latérale de chaque prisme, le dos vertical de chaque quarterpipe) | 198 | le plus doux **90,000°** |

La corde prédite pour la dernière facette vaut
`(12 − 0,5)/12 × 90 = 86,250°` — **mesurée 86,252**, donc le banc restitue
le chiffre de CH60 avant d'en publier un neuf.

**Tout angle strictement entre 86,252 et 90,000 admet la transition
ENTIÈRE et refuse CHAQUE mur. 88,0 est le milieu de cet écart**, et la
sonde le gate **strictement entre les deux** : le jour où un module
arrive avec une rampe plus raide que l'écart, la sonde rougit au lieu de
laisser la planche grimper silencieusement un mur.

Deux conséquences écrites plutôt que laissées à découvrir :

* ⚠️ **Ça ne desserre pas le terrain d'une unité.** La pelouse ne porte
  aucun collider (D1), donc cet angle n'est **jamais** consulté sur le
  sol : ce qui rattrape la planche en terrain libre reste `_hub_floor()`,
  c'est-à-dire `HubSurface` qui **surpasse** le moteur, exactement comme
  avant.
* **`floor_stop_on_slope` passe à `false`.** Le défaut Godot est `true`,
  qui épingle un corps à toute pente sur laquelle il se tient — le bon
  défaut pour un marcheur et l'exact contraire d'une transition, dont
  tout le comportement est qu'on en redescend. Ce qui fait redescendre la
  planche est la gravité tangentielle de `drive()` et rien d'autre, et
  c'est aussi ce qui fait que la descente **RELANCE** au lieu de
  simplement relâcher.

## Section 4 — TABLE HAUTEUR ATTEINTE PAR VITESSE D'ARRIVÉE

Le livrable chiffré du lot. `SkateInertiaProbe` PHASE E lance la planche
à 2,0 u du pied de chaque module avec une vélocité et **AUCUNE cible** —
rien ne pousse, rien ne freine, et ce qui est mesuré est purement ce que
la rampe fait d'un élan. **La vitesse publiée est celle mesurée AU PIED**,
jamais celle injectée : la planche coaste 2 u pour y arriver et les
termes de coast prennent leur part.

| vitesse au pied | funbox (lip 0,85) | quarterpipe (lip 2,10) | quarterpipe (lip 1,45) |
|---|---|---|---|
| **2,98 u/s** | 0,112 | 0,098 | 0,114 |
| **5,09 u/s** | 0,301 | 0,331 | 0,363 |
| **7,02 u/s** | 0,626 | 0,672 | 0,721 |
| **8,97 u/s** | **0,889** (104,6 % du deck) | **1,106** (52,7 %) | **1,176** (81,1 %) |
| *CH60, toutes vitesses* | 0,851 | **0,577 (27,5 %)** | **0,386 (26,6 %)** |

Et une montée **TAPÉE** — le joueur qui vise au-delà de la rampe, donc
avec le push sur les 9 u d'approche — atteint **1,428 u** sur le
quarterpipe de 2,10 (PHASE S), soit **68 % du lip contre 27,5 %**.

### ⚠️ CE QUI EST GATÉ EST LA **FORME** DE LA FONCTION, PAS UNE DE SES VALEURS

Un seul chiffre plus haut passerait pour une allure dictée plus grande et
ne dirait **rien** sur le fait que quoi que ce soit soit CONVERTI. Trois
assertions, et aucune seule ne suffit : **monotone** sur chaque barreau,
**écart réel** entre le plus lent et le plus rapide, et **au-dessus du
plafond CH60**.

### ⚠️ ET LE DISCRIMINANT EST UNE QUESTION QU'AUCUN MODULE SEUL NE PEUT SE VOIR POSER

`CLAUDE.md`, CH46 : « une sonde qui ne compare chaque chose qu'à elle-même
ne peut pas voir que deux choses se ressemblent ». Toute PHASE E demande
à un module de parler de lui-même, et un module cohérent avec lui-même
passerait sous **l'une ou l'autre** loi.

Les deux lois se séparent ainsi (PHASE E(2)) : sous un plafond de
**FORME**, la hauteur est une fraction du **LIP**, donc deux rampes de
hauteurs différentes rendent des hauteurs **différentes** pour une même
arrivée ; sous un plafond d'**ÉNERGIE**, la hauteur vaut `v²/2g`, qui ne
sait rien du lip, donc la même arrivée doit rendre **presque la même
hauteur** sur les deux.

| | rapport |
|---|---|
| rapport des lips (2,10 / 1,45) | **1,448** |
| rapport des hauteurs **CH60** (0,577 / 0,386) | **1,495** — un plafond de FORME |
| pire rapport **de cet arbre**, sur les quatre barreaux | **1,165** — un plafond d'ÉNERGIE |

### LA DÉCOMPOSITION : NI L'UNE NI L'AUTRE MOITIÉ N'EST DÉCORATIVE

PHASE R remet le cap à 45° **sur le corps vivant** et rejoue l'arrivée la
plus rapide. Cette phase avait d'abord été écrite pour exiger que la
montée **s'effondre sur les 0,577 / 0,386 publiés** — un levier, un
chiffre, cause prouvée.

⚠️ **Elle ne l'a pas fait, et la mesure EST le résultat.**

| | quarterpipe 2,10 | quarterpipe 1,45 |
|---|---|---|
| **sans inertie, cap 45°** (CH60, publié) | 0,577 | 0,386 |
| **inertie, cap 45°** (PHASE R, mesuré) | **0,855** | **0,771** |
| **inertie, cap 88°** (cet arbre, PHASE E) | **1,106** | **1,176** |

La raison n'est pas subtile une fois vue : **la planche de CH60 n'avait
pas d'inertie NON PLUS**, donc restaurer l'un des deux changements ne peut
pas restaurer son chiffre. Un corps qui porte de la vitesse dans la
facette que le moteur appelle un mur ne s'y arrête pas — il garde la
vitesse verticale que la montée lui a donnée et coaste un peu plus haut,
balistique.

**Chaque levier vaut à peu près la moitié**, et un lot qui n'aurait
expédié qu'un des deux aurait déplacé le chiffre en laissant les rampes
non ridables.

## Section 5 — LES DEUX PASSES ROUGES, ET LES TROIS PASSAGES GRATUITS QU'ELLES ONT TROUVÉS **DANS LA SONDE**

`CLAUDE.md`, CH46 : deux passes qui **ne se recouvrent pas** sont la
preuve que les deux moitiés sont réellement couvertes ; une seule passe
qui rougit tout ne distingue rien.

* **Passe A, à l'exécution** : PHASE R remet le cap à 45° sur le corps
  vivant. Rien à restaurer à la main, rien à `cmp`.
* **Passe B, au niveau fichier** : la persistance de la vélocité est
  neutralisée dans `SkateBoardBody.drive()` (`var vh := Vector3.ZERO`).
  **PHASE A reste verte, 6 assertions sur 6** — c'est de la géométrie
  pure, que l'inertie ne touche pas — pendant que PHASE L, PHASE E et
  PHASE R rougissent sur exactement les assertions attendues. Fichier
  restauré et vérifié **byte-identique** par `cmp`.

⚠️ **Et la passe B a trouvé trois défauts DANS LA SONDE, pas dans le
jeu** — ce à quoi une passe rouge sert :

1. **PHASE E(2) passait ALL GREEN sur deux zéros**. `worst ratio 0.000 <
   1.25` et `0.000 vs 1.448` : un rapport de deux zéros n'est pas une
   mesure de ressemblance, c'est l'absence de mesure. Ses deux
   instruments ne vérifiaient que des **CONSTANTES** (les lips, la paire
   publiée par CH60) — et une constante ne peut pas rougir.
2. **le retour de PHASE R** (« la montée REVIENT quand le cap est
   restauré ») était satisfait par deux zéros qui s'accordent.
3. **PHASE S** signait « la garde n'a pas coupé la montée » sur un run où
   rien n'avait grimpé.

Les trois portent désormais un **plancher**.

## Section 6 — LES GARDE-FOUS DU BRIEF, MESURÉS

### La garde d'immobilisation ne coupe pas une montée

CH57 mesurait le **déplacement à plat par tick**, et avec de l'inertie
cette lecture confond deux choses opposées : près d'un lip le mouvement
est presque **VERTICAL**, donc une montée légitime ne produit presque
aucun déplacement à plat ; et une planche qui oscille au pied d'une rampe
qu'elle ne peut pas monter en produit à chaque tick et ne serait
**jamais** lâchée — or c'est le cas « coincé » que le joueur rencontre.

La garde note désormais le **PROGRÈS VERS LA CIBLE** — le meilleur
`remaining` jamais atteint. `CLAUDE.md`, CH42 : « un braquage tenu dessine
un cercle, et un cercle finit où il commence », donc un run se note sur le
plus loin qu'il soit allé. Une montée l'améliore à chaque tick et n'est
jamais coupée ; une oscillation et un mur cessent tous deux de l'améliorer
et sont tous deux lâchés. Seuil et fenêtre inchangés (0,004 / 30 ticks).

**Mesuré, un banc, deux verdicts opposés (PHASE S)** : montée tapée sur le
quarterpipe de 2,10, **pic 1,428 u au tick 103, la cible toujours tenue au
point le plus haut**, 81 ticks passés au-dessus de 0,10 u ; et sur la face
est verticale de la funbox, **cible lâchée après 76 ticks**, planche
arrêtée à x 2,660 pour une face à 2,200.

### PARALLAXE RE-MESURÉE AU NOUVEAU POINT HAUT

`SkateDismountProbe` PHASE M, réécrite sur trois points, chacun forcé par
une mesure :

⚠️ **LE PIC, PAS LE POINT DE REPOS.** Avant ce lot la planche calait sur
une transition et y restait, donc les deux étaient le même endroit. Avec
de l'inertie un quarterpipe se comporte comme un quarterpipe : on monte,
on manque de vitesse, on redescend — et sa hauteur **au repos** sur une
transition est **zéro**. La phase aurait rapporté `climbed = false` et
pris la branche du RAIL, en passant, sur un module qu'on venait de rider
plus haut que quoi que ce soit dans ce park ne l'a jamais été.

⚠️ **UN REPOS SE TIENT VINGT TICKS AVANT D'ÊTRE CRU.** `at_rest()` vaut
« pas de cible et plus lent que l'idée que la garde se fait de
l'immobilité », et une planche **à l'apogée d'une montée** satisfait les
deux pendant un instant : elle a fait demi-tour, donc sa vitesse passe par
zéro. Mesuré sur ce banc même — le quarterpipe de 2,10 a rapporté « came
to rest at y 0.987 », qui est un point sur une facette à 58° où rien ne
peut tenir. C'était l'apogée, attrapée au tick où elle tournait.

| module | **pic atteint** | parallaxe AU PIC | contribution du clamp | rayon de self-tap |
|---|---|---|---|---|
| funbox (lip 0,85) | **1,152** | **2,139 u** | **0,000 u** | 0,90 |
| quarterpipe (lip 2,10) | **1,684** | **2,687 u** | **0,000 u** | 0,90 |
| quarterpipe (lip 1,45) | **1,614** | **2,867 u** | **0,000 u** | 0,90 |
| *sol plat (référence CH58)* | 0,000 | 0,133 u | 0,000 u | 0,90 |
| *deck funbox au repos* | 0,851 | 1,368 u | 0,000 u | 0,90 |

**La parallaxe est PUBLIÉE et le clamp est GATÉ**, pour la raison de
CH58 : la branche livrée compare déjà contre le **point sol DESSINÉ**
(`_drawn_ground_point`), donc une grande parallaxe est de combien une
comparaison plate naïve se tromperait, pas de combien le jeu se trompe.
Ce qui peut encore casser le geste sur un corps surélevé est le clamp —
**0,000 u aux trois pics**, donc **aucun défaut à traiter dans ce lot**.

### La descente reste possible depuis tout point atteint

Une transition n'offre **aucun REPOS surélevé** — exiger un démontage
depuis un point de repos que la physique interdit serait exiger un défaut,
exactement ce que CH60 a dit d'un gate écrit au faisceau du rail. Ce qui
est dû est l'exigence réelle du brief, et `_peak_gesture` la pose **au
sommet**, par un **VRAI pixel de conteneur** à travers
`HubTapInput._handle_point` :

1. le tap **résout** en un point sol (le canal est vivant à vitesse,
   au-dessus du sol, en pleine montée) ;
2. il **STEER** au lieu de l'éjecter d'une planche en mouvement — la
   règle de CH58 elle-même, pas une régression de celle-ci ;
3. la planche vient au repos et le **tap suivant** sur lui-même le pose à
   terre.

Vert sur les deux quarterpipes (sommets 1,684 et 1,614) et sur la funbox
(1,152). Sur le deck au repos, le résidu bout-en-bout d'un vrai doigt vaut
**0,0000 u**.

### Deux gates de CH57 confondaient deux choses que l'inertie sépare

* **« jamais au-dessus du lip — pas de volume fantôme »** existe CONTRE un
  collider plus gros que le solide dessiné : une planche debout sur du
  vide. Il MESURAIT une hauteur, et une hauteur au-dessus d'un lip a
  désormais une seconde cause parfaitement légitime — la planche est
  éjectée par le haut. Mesuré **1,551 u** sur la rampe de 1,45, rouge, sur
  un collider que PHASE V venait de prouver identique au maillage dessiné
  sur 1 521 échantillons. Le test est déplacé sur ce qu'il a toujours
  voulu dire : **rien ne doit TENIR la planche au-dessus du lip**. Il lit
  maintenant **held max 1,451 contre un lip de 1,450** — un millimètre —
  tout ce qui est au-dessus étant non porté.
* **« la transition l'a ARRÊTÉE »** n'est pas une propriété des
  quarterpipes, c'est une propriété de l'**ÉNERGIE contre le LIP**. À
  l'arrivée que cette conduite produit la planche a environ
  `v²/2g = 1,55 u` en main : la rampe de 2,10 l'arrête à **1,348** et
  celle de 1,45 **non** — elle sort par le haut, ce qui est le nom même du
  trick du module (« air »).

### Traversées, budget, et le hotspot qui a coûté quatre runs de banc

**Diagonale 66 hops / 1 122 frames / 18,700 s** et traversée du park
**3,967 s**, **identiques sur les deux arbres**, monde physique vivant —
sous le plafond de 22,0 s. Le lot **n'ajoute aucun corps mobile ni
collider** : `PhysicsCostProbe` est ALL GREEN des deux côtés, ses écarts
restant sous leurs propres planchers de station.

⚠️ **ET UN ARTEFACT DE BANC QUI A COÛTÉ QUATRE RUNS AVANT D'ÊTRE LU
PLUTÔT QUE DEVINÉ.** Chaque ligne à partir du troisième barreau de la
funbox revenait `arrived 0.00, peak 0.000` ; l'assertion de montage
disait que le rider n'était jamais monté ; l'impression d'état disait
**`state=7`**, soit `KeepyHopper.State.ON_SEESAW`.

`leave_board` pose le rider **À CÔTÉ** de la planche et cette pose est un
**saut**, et un saut qui **ATTERRIT** est offert à tous les hotspots que
`HubWorld` tient. Avant ce lot chaque conduite s'arrêtait court de son
module ; avec de l'inertie la planche passe **PAR-DESSUS** la funbox et
s'arrête à (0, 40), **dans le disque d'atterrissage de la balançoire**.
La balançoire a pris le rider, et `mount_carrier` a refusé chaque montage
ensuite — sa seule précondition est `_state == IDLE`.

**Rien n'était faux dans le jeu** : un tap qui pose une marche à côté de
la balançoire est CENSÉ l'offrir. Ce qui était faux est un banc qui posait
son rider dans le hotspot d'un autre prop et mesurait ensuite une planche
que personne ne ridait. Les trois bancs concernés
(`SkateInertiaProbe`, `SkateDismountProbe`, `SkatePhysicsProbe`) rendent
désormais la planche **sur pelouse libre** avant de poser le rider.
