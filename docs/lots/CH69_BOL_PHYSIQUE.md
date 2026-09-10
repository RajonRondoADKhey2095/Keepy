# CH69 — Le bol devient physique : une dalle de 0,40 u, une porte de trois secteurs, et le couplage de CH67 élucidé

*10 septembre 2026. Branche `claude/bowl-slab-extension-dr7sfl`, basée sur
`origin/staging` `2b539c7` (CH68, arbre `18eff66`). Garde de concurrence par
ARBRE, faite AU DÉBUT : `origin/main` (`28adc89`, arbre `94e85f7`) est
ancêtre de `origin/staging`, aucune branche distante n'est plus récente que
`staging`, et la branche désignée ne portait aucun commit propre — elle a
donc été repartie de `staging` et non de `main`, CH66/CH67/CH68 n'étant pas
encore promus en palier 2.*

> **Décision de Mathieu** : le bol doit devenir physique **et** rester dans
> le skatepark visuel — pas hors dalle sur la pelouse d'entrée ; agrandir la
> dalle est accepté et voulu.
>
> Ce que ce lot livre : le bol est **solide** (105 hulls), il a une
> **entrée au sol** (trois secteurs de son anneau qui ne sont ni dessinés ni
> solides), la dalle gagne **0,40 u à l'ouest** (7,20 u², +2 %), et la
> planche y **entre en roulant** par le vrai canal du doigt avec le blind
> check de CH67 — la même approche sur un secteur PLEIN est arrêtée à la
> jupe.
>
> Ce qu'il ne livre pas, et le dit avec les chiffres : le bol ne reste pas
> dans la MOITIÉ NORD du park. La mesure dit pourquoi, et combien ça
> coûterait.

## Section 1 — LE BALAYAGE, ET LES SEPT CONTRAINTES

### 1.1 — Le banc reproduit le dossier avant de publier quoi que ce soit

Le modèle est un **rectangle en plan par module**, lu sur la SURFACE 0 du
nœud construit (D5 : le coping vit en surface 1) et non retapé depuis
`MODULES`. Il est exact pour cette question — un quarterpipe et le bol sont
tous deux des prismes sur leur contour en plan **au voisinage de y = 0**, et
c'est là que deux solides posés sur le même sol se rencontrent.

| grandeur | CH66 / CH68 | ce banc |
|---|---|---|
| rim du bol au coin est de la lèvre du quarterpipe 2,10 | 2,907 u (0,693 dedans) | **2,907 u (0,693 dedans)** |
| rim du bol au coin ouest du pied du quarterpipe 1,45 | 2,915 u (0,685 dedans) | **2,915 u (0,685 dedans)** |
| retombée du grand quarterpipe (`SkateAirProbe`, arbre de référence) | (−4,20 ; 57,58) | **(−4,20 ; 0,00 ; 57,58)** |

⚠️ **Le modèle est CONSERVATEUR, et le contrôle est à SENS UNIQUE.** Un
quarterpipe n'est un prisme sur son rectangle qu'à y = 0 : à y = 0,30 la
transition s'est déjà éloignée du pied (`z = h sin a`, `y = h(1 − cos a)`
donne z = 1,081 sur 2,10). Le rectangle réclame donc du solide là où la
rampe est de l'air. La jupe du bol, elle, est **VERTICALE** sur toute sa
hauteur. Le gate est donc « le modèle ne RATE jamais un solide que le
serveur trouve » — le sens qui laisserait passer un chevauchement :
**0 server-only sur 720 points de rim à y 0,02 et 0 à y 0,30**, contre 8 et
33 model-only qui sont la courbure de la rampe et se rétractent quand on
descend.

### 1.2 — Les sept contraintes

| # | contrainte | énoncé | d'où elle vient |
|---|---|---|---|
| K1 | OVERLAP | zéro échantillon partagé avec un module solide | CH66 |
| KB | DÉGAGEMENT | ≥ `SkateparkMesh.DECK_LENGTH` = **0,92 u** de tout solide | ce lot |
| K2 | PARKING | `\|C − (3 ; 60)\| ≥ 5,60` (empreinte 4,40 + `SKATE_FOOTPRINT` 1,20) | CH68 |
| K3 | RETOMBÉE | `\|C − retombée\| ≥ rayon + 0,92` | CH68, resserré à la longueur de planche |
| K4 | RÉGION | les 36 points du rim dans `HubRegion.contains()` | CH68 |
| K5 | DALLE | le rim **sur** la dalle, marge 0,05 u | CH68, **renforcé** |
| K6 | DISQUES DE SCORE | disjoints d'au moins `KeepyHopper.ARRIVE_EPSILON` | **une sonde**, section 1.4 |

⚠️ **KB N'EST PAS UN CHIFFRE ROND, C'EST LA PLANCHE.** CH68 s'arrête sur
« aucune des 56 positions ne garde un seul mètre de dégagement » en disant
lui-même que « 0,801 u serait injouable » est un jugement et pas une mesure.
Le plancher défendable est publié dans le dépôt : `DECK_LENGTH = 0,92`, la
plus grande dimension de la planche. Un intervalle plus étroit que ça est
une fente où un deck ne peut pas tourner.

⚠️ **K5 PASSE D'UNE TOLÉRANCE À UNE MARGE, ET C'EST STRICTEMENT PLUS FORT.**
CH68 avait dû **mesurer K5 avant de l'écrire** : exiger le rim entièrement
sur la dalle condamnait le bol LIVRÉ, qui débordait déjà de 0,100 u — un
seuil qui condamne l'état expédié ne prouve rien. Dès lors que la dalle est
le LEVIER, cette tolérance n'a plus de raison d'être : le point le plus à
l'ouest du rim tombe à −10,350 pour un bord de dalle à −10,400, donc le gate
lit « le béton de chaque module est SUR la dalle » avec 0,050 u de reste.

### 1.3 — Le résultat, et les deux réponses

**19 865 candidats, pas 0,25 u.** Objectif : minimiser le BÉTON AJOUTÉ.

| plancher de dégagement | **partout** (béton ajouté, dégagement obtenu, stations qui le cadrent) | **z ≥ 50 (la moitié nord du park)** |
|---|---|---|
| 0,00 (chevauchement nul seul) | (−6,25 ; 44,75) — **0,00 u²**, 0,450 u, **31** stations | (−9,00 ; 56,00) — **62,42 u²**, 0,040 u, 5 stations |
| 0,46 (une demi-planche) | (−6,50 ; 44,75) — 2,70 u², 0,700 u, 32 | (−9,00 ; 56,50) — 73,75 u², 0,511 u, 3 |
| **0,92 (une planche)** | **(−6,75 ; 45,00) — 7,20 u², 0,950 u, 30** | (−8,75 ; 57,00) — **80,16 u²**, 0,924 u, **2** |
| 1,50 | (−7,50 ; 45,25) — 20,70 u², 1,650 u, 30 | (−8,75 ; 57,75) — 96,96 u², 1,656 u, 2 |
| 2,00 | (−8,00 ; 44,75) — 29,70 u², 2,158 u, 32 | (−8,75 ; 58,25) — 108,16 u², 2,147 u, 2 |

Les **stations** sont l'arithmétique de cadrage que `HubSkatepark` publie
en en-tête (`|x − x_j| + rayon ≤ tan 22,5° × (z_j + 8,9 − z)`, plus la
bande caméra de CLAUDE.md : le bol ne compte que s'il est DEVANT le
joueur, jamais dans les 8,9 u derrière lui), évaluée sur la place de
parking plus un treillis de 2 u sur la dalle à venir — **133 stations**.

⚠️ **LA DALLE N'A PAS BESOIN DE GRANDIR POUR QUE LE BOL SOIT LÉGAL.** Ligne
1 : avec la dalle telle que CH64 l'a laissée, il existe une place à
chevauchement nul, rim sur le béton, disques disjoints — **0 u² ajoutés**.
Ce que les 0,40 u de béton achètent, c'est le DÉGAGEMENT : 0,450 → 0,950 u,
c'est-à-dire le passage d'un demi-deck à un deck. Le lot ne présente donc
pas l'extension comme une nécessité, mais comme un prix chiffré (**1 u de
dégagement ≈ 1 u de béton**, ce qui reproduit exactement la table de
CH68 § 2.5).

⚠️ **ET LA MOITIÉ NORD A ÉTÉ MESURÉE, PAS ÉCARTÉE.** Elle est POSSIBLE.
Elle coûte **80,16 u² (+20,5 %)** — dix fois le prix — et elle pose le bol à
**8,75 u de l'axe du park**, là où la caméra du hub peut le montrer depuis
**2 stations debout sur 133**, contre **30** pour la place retenue. C'est
l'arithmétique de cadrage que `HubSkatepark` porte déjà en en-tête : le
cadre vaut ±3,69 u au z du joueur, donc un module LARGE ne se lit que très
au SUD de lui — et il n'y a plus de « très au sud » au nord des rampes.

### 1.4 — ⚠️ LA SEPTIÈME CONTRAINTE EST VENUE D'UNE SONDE, PAS DU BALAYAGE

La première réponse du balayage, **(−6,75 ; 45,75)**, a été implémentée,
et `SkateparkProbe` **G5** est sortie rouge : *« no two scoring discs
overlap (tightest gap −0,21 u) »*. `HubSkatepark.landed_within` choisit le
module le plus proche dont le `tap_radius` couvre l'atterrissage ; deux
disques qui se recouvrent font une bande de sol où **quel** module on a
marqué est un accident d'un centimètre. Le disque du bol (3,0) tombait à
5,391 u de celui du grand quarterpipe (2,6) pour 5,600 requis.

Le balayage a donc été refait avec K6 — et avec une **MARGE**, parce que la
réponse sous un K6 nu était (−6,75 ; 45,50), disjointe de **treize
millimètres** : un gate posé sur sa propre limite n'est pas un gate. La
marge est `KeepyHopper.ARRIVE_EPSILON` (0,45), la distance à laquelle une
glisse se termine — deux disques ne sont jamais plus proches que la
précision de l'atterrissage lui-même. Le minimum se déplace alors de 0,75 u
vers le sud, **pour le même béton**, et le jeu de disques respire à
0,462 u.

Les deux blind checks du banc le rejouent : il condamne (−6,75 ; 45,75)
**outright** à −0,209 u (le −0,21 de G5, reproduit), et il montre que c'est
la MARGE et non K6 qui refuse (−6,75 ; 45,50).

## Section 2 — CE QUI EST LIVRÉ

### 2.1 — La dalle devient deux COINS

`SLAB_WIDTH`/`SLAB_DEPTH` centrés sur `PARK_CENTRE` ne savent pas grandir
d'un seul côté : élargir de 0,40 u à l'ouest en portant la largeur à 20,40
aurait posé 0,40 u de béton à l'EST que rien ne demandait et que le semis
aurait nettoyé pour rien. La dalle est donc `SLAB_MIN`/`SLAB_MAX` —
**x [−10,40 ; 10,00], z [41,00 ; 59,00]**, soit 20,40 × 18,00 — et la
largeur, la profondeur et le centre se lisent dessus. `PARK_CENTRE` ne
bouge pas : le marqueur de minimap, le layout et l'arithmétique de caméra
sont tous écrits contre lui.

⚠️ **ET JUSQU'À CE LOT, RIEN NE RELISAIT UNE DIMENSION DE DALLE.**
`SLAB_WIDTH` avait **un** lecteur dans tout le dépôt (`SkateEdgeProbe`,
pour l'abscisse d'une station) et **aucun gate**. Une constante que rien ne
relit survit aux lots : `SkatePhysicsProbe` PHASE X mesure désormais, pour
les cinq modules, la marge de leur BÉTON (surface 0) au rectangle de la
dalle et gate qu'elle est positive.

| module | béton x | béton z | marge à la dalle |
|---|---|---|---|
| funbox | [−2,200 ; 2,200] | [43,180 ; 47,820] | +2,180 |
| rail | [3,256 ; 5,144] | [45,616 ; 51,384] | +4,616 |
| quarterpipe 2,10 | [−7,700 ; −0,700] | [50,500 ; 52,600] | +2,700 |
| quarterpipe 1,45 | [2,000 ; 8,000] | [52,550 ; 54,000] | +2,000 |
| **bol** | **[−10,350 ; −3,150]** | **[41,400 ; 48,600]** | **+0,050** |

### 2.2 — Le roll-in : trois secteurs qui ne sont NI dessinés NI solides

CH66 laissait le bol dehors pour deux raisons mesurées. La première était le
chevauchement (une question de layout, réglée par la section 1). La seconde
est que **un anneau solide à jupe VERTICALE n'a aucune entrée au sol** : on
n'y arrive que par les airs. La porte est taillée comme celle d'un vrai
bol — un canal droit à travers le mur, du niveau du sol au niveau du sol —
et ici c'est littéralement **trois secteurs d'azimut absents**.

⚠️ **TROIS, ET LE NOMBRE EST CELUI DE LA PLANCHE.** Un secteur vaut
`2πr / 24 = 0,942 u` d'arc à la lèvre contre un deck de **0,92 u** : une
fente qu'un rider ne peut pas viser et où il ne pourrait pas tourner une
fois dedans. Trois donnent **2,83 u** à la lèvre et 1,77 u au pied du dish.
(CH67 avait construit et roulé exactement cette porte avant que le bol soit
retiré faute de place ; l'arc est son chiffre, re-dérivé ici depuis
`DECK_LENGTH` au lieu d'être recopié.)

⚠️ **ET ELLE N'INTRODUIT AUCUNE POSITION DE SOMMET NOUVELLE**, ce qui est
ce qui garde `SkatePhysicsProbe` PHASE G identique à elle-même. La porte
RETIRE des faces ; les deux **jambages** qui ferment la coupe sont des
éventails sur la polyligne du profil depuis le pied de la jupe — exactement
la section dont les pièces de collision sont taillées — donc chaque point
qu'ils dessinent est déjà un coin de pièce. L'égalité « l'union des pièces
EST le béton dessiné, centre du plancher mis à part » tient donc telle
quelle, avec **105 pièces au lieu de 120**.

Le mesh du bol passe de 600 à **535 triangles** (283 de béton contre 312,
252 de coping contre 288) : la porte est un gain de géométrie.

L'azimut de la porte n'est pas un index tapé à la main : `MODULES` publie
`rollin_aim = (0 ; 50)` — d'où le rider ARRIVE — et `bowl_gate_first()` le
convertit dans le repère du module (le nœud porte le yaw, donc la porte
tournerait avec lui). Le relèvement vaut 36,5°, la bouche est centrée à
37,5°, et PHASE G gate que **l'arc de la bouche CONTIENT le relèvement**.

### 2.3 — Le collider, et le gate qui n'a pas changé

`HubSkatepark.pieces_for()` rend l'anneau. Ce qui n'a **pas** changé est le
périmètre : PHASE X asserte toujours que le bol porte des pièces **SI ET
SEULEMENT SI** son anneau ne partage aucun échantillon avec un module
solide — un layout qui le repousserait dans une rampe rougit au lieu
d'expédier un mur dans une transition. Mesuré sur l'arbre livré : **les dix
paires de modules ont des AABB DISJOINTES**, et l'anneau partage **0**
échantillon.

Inventaire : 3 `Area3D` de portail inertes, **5** corps statiques,
1 `CharacterBody3D`, **139 formes** (3 + 3 + 12 + 12 + 105 + les 3 portails
+ la capsule).

### 2.4 — PHASE Y roule le collider LIVRÉ, et gagne le test que le module existe pour

Le corps temporaire de CH66 a disparu. Le scan sur `LAYER_PARK` est
désormais **non ambigu, et c'est asserté** : plus aucune AABB de module
n'entre dans celle du bol (CH66 avait dû passer par une couche privée après
avoir mesuré 56 faux « serveur » venus des quarterpipes que l'ancienne AABB
avalait).

| test | mesure |
|---|---|
| anneau contre serveur (1 521 points) | **0 désaccord** |
| ENTRER PAR LES AIRS (lâché au-dessus de la lèvre) | pose sur la PELOUSE, y 0,0000, `on_module` false, tick 23 |
| **ROLL-IN par le doigt, à travers la porte** | franchit le rim **à y 0,0000**, atteint **r 0,030** (fond plat à 2,25), **0 pop, 0 fence** |
| **BLIND : le même geste sur un secteur PLEIN** | **ARRÊTÉ à r 4,035** pour une jupe à 3,60 |
| ROULER + REMONTER (roue libre 4 u/s) | tenu à 0,161, jamais au-delà de r 2,47, revenu au fond, 0 pop |
| REMONTER, doigt tenu (plafond 4 u/s) | monte plus haut que la roue libre, pas par-dessus la lèvre, 0 pop |
| RESSORTIR (croisière) | tenu dans les deux dernières facettes, **exactement 1 pop**, retombe hors de l'anneau, dans la région |

⚠️ **ET UNE ASSERTION DE VALEUR TENAIT LIEU D'ASSERTION D'ÉVÉNEMENT.** La
première version publiait « y au rim 0,0000 » pour un run qui **n'avait
jamais atteint le rim** : un franchissement absent retombait sur zéro, et le
seuil `y ≤ 0,02` passait gratuitement. La sonde publie maintenant *si* le
rim a été franchi, et le gate exige les deux.

## Section 3 — ⚠️ LE COUPLAGE NON ÉLUCIDÉ DE CH67 EST ÉLUCIDÉ : C'EST `park_span()`

CH67 § 4 signale, sans l'expliquer, que **la POSITION du bol seule** déplace
les vitesses d'arrivée de `SkateInertiaProbe` PHASE E de +0,13 u/s sur les
quatre échelons, « de façon parfaitement reproductible des deux côtés », et
conclut : « Le mécanisme n'est PAS établi. »

Le mécanisme est une chaîne de trois appels, et il est entièrement dans le
dépôt :

```
HubSkatepark.park_span()      # la plus grande distance entre deux centres
    -> HubTransport.skate_coast_u()          # de modules, empreintes comprises
        -> SkateBoardBody.configure(coast)   # d'où la décélération est RÉSOLUE
```

`park_span()` est une fonction de `MODULES` : déplacer le bol change la
paire la plus large du park, donc la distance de roue libre, donc la
décélération, donc la vitesse à laquelle la planche ARRIVE au pied d'une
rampe. Mesuré aux deux bouts de ce lot :

| | référence `origin/staging` | branche |
|---|---|---|
| `park_span()` / `skate_coast_u()` | **18,043 u** | **23,201 u** (+28,6 %) |
| arrivées PHASE E | 2,98 / 5,09 / 7,02 / **8,97** u/s | 3,21 / 5,28 / 7,27 / **9,19** u/s |
| retombée du grand quarterpipe | (−4,20 ; 57,58) | **(−2,94 ; 57,33)** |

C'est **voulu par construction** — « une planche relâchée à la croisière
s'arrête dans le park où elle a été poussée », et le park est plus large —
mais c'est un changement de TOUCHER qui porte sur tout le hub, pas
seulement sur le skatepark. **Une sonde ne signe pas un ressenti** (CH62) :
il est nommé ici et il est à valider device.

⚠️ **ET IL A FAIT SORTIR UNE JAMBE DE SON RÉGIME.** À 9,19 u/s, la rampe de
1,45 atteint **2,023**, soit **139 % de sa lèvre** : la planche est passée
par-dessus et son apogée est celle de la GRAVITÉ, plus celle de la
transition. Le rapport que PHASE E(2) publiait, **1,669**, était une jambe
sur le béton contre une jambe en l'air ; les trois échelons restés sur la
rampe lisent 1,142 / 1,044 / 1,107. C'est la doctrine CH41 exactement — une
jambe d'un couple A/B publie la grandeur qui la définit aux DEUX bouts et
gate que son régime n'a pas basculé — et l'échelon qui sort est désormais
imprimé, nommé et laissé hors du gate, avec une garde `counted >= 2` pour
que « rien n'était comparable » ne devienne pas l'issue de tout le monde.

## Section 4 — ROUGE AVANT VERT

Chaque mécanisme neutralisé, la sonde relancée, le fichier restauré et
vérifié **byte-identique par `cmp`**.

| # | neutralisé | attendu | obtenu |
|---|---|---|---|
| R1 | `SLAB_MIN.x` −10,40 → −10,00 (la dalle de CH64) | **1** : le gate de dalle neuf | **1**, et le chiffre exact : *« tightest [4 bowl] at −0,350 u »* |
| R2 | `BOWL_GATE_SECTORS` 3 → 0 (la porte refermée) | 4 (2 en PHASE G, 2 en PHASE Y) | **2 en PHASE G**, puis **la sonde S'ARRÊTE** |
| R3 | le bol rendu à (−0,5 ; 55,5), la place de CH53 | 6 nommés | **9** |

**R1** est le contrôle de la seule constante que ce lot ajoute au monde et
que rien ne relisait avant lui. Il rend exactement le débord prédit.

⚠️ **R2 N'A PAS PU ATTEINDRE LA MOITIÉ QU'IL VISAIT, ET C'EST LE GATE
D'INSTRUMENT QUI L'EN A EMPÊCHÉ.** Les deux rouges attendus en PHASE G sont
tombés — *BLIND CHECK 4* (l'anneau non gaté correspond de nouveau au mesh,
donc la porte n'est plus « réellement manquante ») et l'arc de la bouche
(6,5° de décalage contre un demi-arc devenu 0,0°) — et
`SkatePhysicsProbe` a répondu *« INSTRUMENT FAILED — every number below
would be worthless. Stopping. »*, ce qui est exactement ce pour quoi cette
sortie existe. Les deux rouges de PHASE Y que la prédiction annonçait sont
donc **inatteignables par cette neutralisation**, et il n'en existe pas
d'autre : la porte est publiée par `build_args()` et lue par le mesh comme
par les pièces, si bien que toute désynchronisation des deux rougit
l'égalité de PHASE G avant d'atteindre une roulade. **Le rouge-avant-vert
de la ROULADE est donc dans le run lui-même** : le blind check de PHASE Y
fait la même approche sur un secteur PLEIN et la planche est **arrêtée à
r 4,035** contre **0,030** par la porte.

⚠️ **R3 A RENDU TROIS ROUGES DE PLUS QUE PRÉDIT, ET LES TROIS SONT LE MÊME
DÉFAUT VU AILLEURS.** Prédits et obtenus : le gate de dalle (−0,100), le
gate « unwired IFF overlap » (**774 échantillons partagés**, le chiffre de
CH67 R3 au chiffre près), les AABB intruses de PHASE Y (2), l'anneau contre
le serveur, et V[4]. **Non prédits** : **V[3]**, parce que le bol remis en
place entre dans l'AABB du PETIT quarterpipe et fait mentir le scan d'un
module que le lot ne touche pas ; et **les DEUX assertions du blind check
de PHASE V**, qui retirent le grand quarterpipe de sa couche et exigent que
le serveur ne trouve plus rien dans son AABB — avec le bol dedans, il
trouve encore quelque chose. Un chevauchement n'abîme donc pas seulement le
module qui chevauche : **il empoisonne le blind check d'un autre**, et
c'est la raison la plus concrète qu'on puisse donner à « aucun module ne
partage un échantillon avec un autre ».

Une prédiction fausse dans le sens « il y en a plus que prévu » se
publie : ce que la prédiction avait raté, ce sont les phases qui lisent le
SERVEUR sur l'AABB d'un module et supposent qu'elle ne contient que lui.

## Section 5 — LA TABLE CROISÉE, DEUX ARBRES

Référence : `origin/staging` `2b539c7` (arbre `18eff66`), copie importée à
part dans `/home/user/keepy-base`, **154 `.scn` = 154 `.scn`** comptés des
deux côtés avant toute comparaison.

| sonde | driver | branche | référence | écart |
|---|---|---|---|---|
| `SkatePhysicsProbe` | headless | **ALL GREEN — 161 assertions** | ALL GREEN — 148 | **+13** (le gate de dalle, la porte, la roulade et son blind check) ; 139 formes contre 34 |
| `SkateAirProbe` | headless | **ALL GREEN** | ALL GREEN | retombée (−2,94 ; 57,33) contre (−4,20 ; 57,58) — section 3 ; **1 pop des deux côtés** |
| `SkateInertiaProbe` | headless | **ALL GREEN** | ALL GREEN | arrivées +0,22 u/s, coast 23,201 contre 18,043 — section 3 |
| `SkateTrickProbe` | headless | **ALL GREEN** | ALL GREEN | identique |
| `SkateTraverseProbe` | headless | **ALL GREEN** | ALL GREEN | diagonale 66 hops / 18,700 s reproduite, pire traversée 20,967 s |
| `SkateparkProbe` | xvfb | **ALL GREEN** | ALL GREEN | G5 a rougi une fois, section 1.4 |
| `SkateEdgeProbe` | xvfb | **ALL GREEN** | ALL GREEN | identique |
| `SkateDriveProbe` | xvfb | **ALL GREEN** | ALL GREEN | identique |
| `SeesawProbe` | headless | **61 OK / 2 FAIL** | **61 OK / 2 FAIL** | **PARITÉ EXACTE** — les deux rouges pré-existants que CH67 a trouvés |
| `ProbeTimeoutAudit` | headless | **98 scènes** | 98 scènes | identique |

⚠️ **LES 98 SONT LE CONTRÔLE DE PROPRETÉ DU LOT.** Pendant le travail
l'audit lisait **99** : les deux sondes jetables (le balayage de position,
le banc de proxys de perf) y comptaient. Elles sont supprimées, et le
retour à 98 — le chiffre exact de CH67 et de CH68 — est ce qui le prouve.

⚠️ **ET UN RUN INVALIDE, RAPPORTÉ PARCE QU'IL A COÛTÉ ONZE MINUTES.**
`SkateparkProbe` lancée en `--headless` s'est arrêtée sur son propre
contrôle d'instrument (« the dummy driver's four false greens ») et est
restée à 100 % de CPU sans une ligne de plus. C'est une sonde **xvfb** —
son en-tête le dit — et un verdict lu sous le mauvais driver n'est pas un
verdict. Relancée sous `xvfb --rendering-driver opengl3` : ALL GREEN.

## Section 6 — LES PROXYS DE PERF (mesure seule, aucune correction)

Le brief met la perf HORS SCOPE et demande des proxys avant/après. Sept
stations, **monde gelé**, chaque station lue en la QUITTANT et en y revenant
(CH62 : une caméra gelée ne réévalue pas ce qu'elle voit tant qu'elle ne
BOUGE pas), chaque lecture faite deux fois. **Les quatorze paires de
lectures sont identiques au chiffre près : tremblement 0 partout.**

| station | prims AVANT | prims APRÈS | Δ | calls avant → après |
|---|---|---|---|---|
| spawn (0 ; 0) | 72 304 | 72 342 | **+38** | 311 → 311 |
| (0 ; 42) | 86 604 | 87 072 | **+468** | 371 → 373 |
| (0 ; 51) | 89 117 | 88 969 | **−148** | 390 → 390 |
| (3 ; 60) parking | 91 164 | 90 998 | **−166** | 421 → 421 |
| (0 ; 63) | 89 118 | 88 970 | **−148** | 410 → 410 |
| (−10 ; 51) | 91 131 | 91 617 | **+486** | 363 → 365 |
| (−6,75 ; 49,5) le bol | 90 972 | 90 824 | **−148** | 373 → 373 |

Comptes de scène (déterministes, ce sont eux qui comparent proprement) :
nœuds **718 → 718**, triangles de scène **360 794 → 360 849 (+55)**.

**Le park lui-même s'ALLÈGE de 65 triangles** (820 → 755) : la porte retire
trois secteurs de dish, de jupe et de coping et n'en rend que dix triangles
de jambages. Les +55 de la scène sont donc le **TAPIS REBATTU** —
l'empreinte du bol a déménagé de (−0,5 ; 55,5) à (−6,75 ; 45), celle de la
dalle a bougé de 0,20 u avec son centre, et `CozyScatter` tire ses
candidats dans un flux RNG partagé (CLAUDE.md, CH53). C'est le plancher de
bruit de toute comparaison de tapis, et il explique aussi les deux stations
à +468 et +486 : ce sont des touffes redistribuées, pas du béton.

**Une dalle plus grande ne coûte RIEN au compteur** : la dalle est
**16 triangles** avant comme après (`SkateparkMesh.slab` en pose quatre
quads de kerb et trois de peinture quelle que soit sa taille), et le
collider du bol dessine zéro primitive et zéro draw call — mesuré par
PHASE B, qui retire les **5** corps et leurs **136** formes et relit la même
frame.

⚠️ **PROXYS LLVMPIPE, ET RIEN D'AUTRE.** Ce sandbox n'a pas de GPU ; le FPS
device reste le chantier ouvert de CH67.

## Section 7 — CE QUE CE LOT NE SIGNE PAS

* **Que le bol soit AMUSANT.** CH62 : un banc headless ne voit ni une
  sensation ni un plaisir. Il signe que la planche entre en roulant, tourne
  au fond, remonte, ressort par la lèvre, ne traverse jamais et n'est jamais
  coincée. Que ça se joue n'appartient qu'à Mathieu.
* **Que la nouvelle place du bol se LISE.** Le cadrage est mesuré (30
  stations sur 133 contre 2 pour la moitié nord) par l'arithmétique de
  caméra que `HubSkatepark` publie ; il n'est pas rendu.
* **Le toucher de la planche après le changement de roue libre.** +28,6 %
  de distance de coast est un vrai changement de ressenti, dérivé et non
  réglé — section 3.
* **Le FPS device.** Toujours ouvert depuis CH67. Les proxys de la
  section 6 sont des proxys llvmpipe et rien d'autre.
* **Les 8 props sans collider du couloir de course** (CH67 NEXT STEPS #4).
  Hors scope ; ce lot ne les déplace pas et ne pose de béton sur aucun.

## Section 8 — PROTOCOLE DEVICE

1. Ouvrir `keepy-staging.vercel.app`, monter au skatepark et taper la
   planche garée au nord (3 ; 60).
2. **Voir la dalle élargie** : rouler vers le sud-ouest. Le béton va
   maintenant jusqu'à **x = −10,40** (il s'arrêtait à −10,00), et la cuvette
   à anneau blanc s'y trouve entièrement posée, au sud-ouest de la grande
   rampe, à la hauteur de la funbox.
3. **Entrer dans le bol EN ROULANT** : se placer entre la funbox et la
   grande rampe, vers (−1,4 ; 49), nez sur la cuvette, doigt tenu. Il y a
   une **ouverture dans le mur du bol**, face au nord-est, large de trois
   facettes — la planche passe **à travers**, au niveau du sol, sans
   sauter.
4. **Tourner dans la cuvette, remonter, ressortir** : doigt tenu dans le
   mur opposé, la planche monte et retombe ; à la croisière elle passe
   par-dessus la lèvre avec un pop.
5. À reporter : (a) la porte se VOIT-elle depuis l'approche, ou faut-il la
   chercher ? (b) la planche roule-t-elle plus loin qu'avant quand on lâche
   le doigt (la distance de roue libre a augmenté de 28,6 %) — est-ce
   agréable ou flottant ? (c) le FPS au park (overlay Perf), à comparer
   aux 30 relevés sur CH66. (d) le bol se trouve-t-il tout seul depuis la
   place de parking, ou faut-il savoir qu'il est là ?
