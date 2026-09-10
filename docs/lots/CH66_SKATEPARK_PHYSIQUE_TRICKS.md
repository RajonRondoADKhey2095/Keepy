# CH66 — Fin du chantier physique du skatepark : l'audit des colliders, le bol prouvé et laissé dehors, et les tricks rendus ATTEIGNABLES par un pouce

*10 septembre 2026. Branche `claude/skatepark-physics-tricks-43wqbt`, basée
sur `origin/main` `28adc89` (CH65 promu, arbre `94e85f7`, byte-identique à
`origin/staging`). Garde de concurrence par ARBRE : aucune branche distante
plus récente que `main` hormis celle-ci ; `claude/diagnostic-bol-fps-ai8hv1`
(CH63 diag) n'est ancêtre ni de `main` ni de `staging` et ne porte que des
scripts de diagnostic déjà remplacés — laissée telle quelle.*

> Deux chantiers, dans l'ordre que le brief impose : **2** d'abord (les
> tricks livrés en CH64 n'ont jamais été vus sur device — mesurer AVANT de
> toucher), puis **1** (l'audit des colliders, puis le bol en dernier).
> Ce que les sondes signent est l'ARITHMÉTIQUE : une fenêtre en secondes
> contre un geste en pixels. Ce qu'elles ne signent pas — la facilité
> réelle du cercle au pouce, le FPS device, le ressenti du pop — est
> nommé en section 6 et reste à Mathieu seul.

## Section 1 — CHANTIER 2 : les tricks étaient INATTEIGNABLES, et le chiffre le dit

### 1.1 — La mesure, sur l'arbre livré, par le vrai canal

`SkateAirProbe` (permanente, headless pour la physique, xvfb pour le
cadre) conduit la planche par `SkateBench` — de vrais `InputEvent` sur
`SkateTouchInput._unhandled_input`, jamais `hold()` — jusqu'à chaque
quarterpipe, doigt tenu, à la croisière, et compte tick par tick.

**Le geste, pricé sur le reconnaisseur lui-même** (un cercle nourri à
1 px par événement, jusqu'au tick où `trick` sort) :

| rayon | travel jusqu'au trick | @250 px/s | @400 px/s | @600 px/s | @800 px/s |
|---|---|---|---|---|---|
| 30 px | 171,0 px | 0,684 s | 0,427 s | 0,285 s | 0,214 s |
| **40 px** | **224,8 px** | 0,899 s | **0,562 s** | 0,375 s | 0,281 s |
| 60 px | 324,0 px | 1,296 s | 0,810 s | 0,540 s | 0,405 s |
| 80 px | 431,7 px | 1,727 s | 1,079 s | 0,720 s | 0,540 s |

224,8 px pour 300° à r 40 reproduit l'arithmétique de l'arc à un segment
près (5,236 × 40 + 8 = 217,4). **Pouce de référence** publié dans la
sonde : r 40 px (≈ 8 mm sur l'écran de Mathieu), 400 px/s (une glissade
vive mais ordinaire ; une pichenette est à 800 et plus), **plus 0,20 s de
réaction** — il faut VOIR le décollage avant de commencer à tracer. Besoin :
**0,762 s de fenêtre**.

**La fenêtre, sur l'arbre livré (avant ce lot)** :

| rampe | quitte la surface à | v verticale | ticks sans appui | ticks ARMÉS (une seule aire) | fenêtre | verdict |
|---|---|---|---|---|---|---|
| quarterpipe 2,10 | y 1,986 (sous la lèvre) | **3,76 u/s** | 15 | **10 = 0,17 s** | 0,25 s | INATTEIGNABLE |
| quarterpipe 1,45 | y 1,421 | 5,50 u/s | 36 | **31 = 0,52 s** | 0,60 s | INATTEIGNABLE |

Le grand quarterpipe sortait la planche à **0,13 u au-dessus de sa lèvre**,
la reposait SUR l'arête de la lèvre 15 ticks plus tard, puis la laissait
tomber derrière (2,1 u) : deux aires courtes, aucune où un cercle tient.
**L'hypothèse (a) du brief est la bonne, et largement** : le code des
tricks est juste (54/0 en CH64, 0 rouge ici sur les phases G/A/L/F/H), et
aucun pouce humain ne trace 225 px en 0,17 s. CH64 avait prouvé le
reconnaisseur sur un **pop synthétique** (`velocity.y = 6,0`, 0,46 s
d'air) avec un cercle livré **trois points par tick** (0,2 s la boucle) —
tout était vrai, et rien ne posait la question du joueur.

Ce qui a été vérifié au passage, contre le rapport CH65 et pas sur parole :

* **le filtre du doigt n'atteint pas le trick** — PHASE F livre un cercle
  de 60 px en DEUX ticks de writer : le doigt filtré n'a parcouru que
  34,5 px des 376,5 du doigt brut, et le trick sort quand même (1) ;
* **grip et poussée-nez CH65 ne changent pas la trajectoire d'envol d'une
  approche droite** (arithmétiquement nulles : `lat` = 0, `align` = 1) ;
  à 20° hors axe, la lèvre prend une frame de plus d'air (+5 ticks) et un
  pic un peu plus bas (2,034 contre 2,228 avant pop) — mesuré, PHASE O.

### 1.2 — Ce qui a été livré : trois élargissements, chacun mesuré

| # | pièce | fichier | ce qu'elle achète |
|---|---|---|---|
| 1 | **le POP** `POP_SPEED 5,0` | `SkateBoardBody` | +5 u/s vertical au tick où la planche quitte un module qu'elle RIDAIT (≥ 6 ticks d'appui) en montant (> 1 u/s) depuis une facette **à moins de 10° de la verticale** (`POP_MAX_NORMAL_Y = cos 80°`) : la DERNIÈRE facette d'une transition (86,25° sur les quarterpipes, 81° sur le bol), jamais celle du dessous (78,75°). Un ollie à la lèvre, gaté par PHASE P sur la géométrie publiée. |
| 2 | **la polyligne s'ouvre au premier tick libre** | `SkateTouchInput.set_free()` | le dwell (`AIR_ARM_TICKS 6`) décide toujours si l'air compte ; il ne jette plus les 0,1 s de cercle tracés pendant lui. Un saut qui n'arme jamais lâche sa polyligne sans tirer. |
| 3 | **la grâce d'atterrissage** `GRACE_TICKS 15`, `GRACE_MIN_SWEEP_DEG 90` | `SkateTouchInput` | un cercle nettement engagé au contact (≥ 90° tracés) a 0,25 s de plus pour se fermer ; cap gelé pendant ce temps (comme en l'air), ancre déplacée sous le doigt à la fin. Moins de 90° : coupé au contact, comme avant. |

`TRICK_SWEEP_DEG` reste à 300 : le geste n'était pas trop exigeant, la
fenêtre était trop courte. Le modèle CH61 (push/brake/coast/grip/plafonds)
est byte-identique : le pop est UNE addition verticale sur UN tick, et
`SkateInertiaProbe` PHASE L ne peut pas le voir (aucune course à plat ne
quitte un module en montant).

**Le pop, balayé et non goûté** (fenêtre = polyligne vivante, sans grâce) :

| pop | QP 2,10 : fenêtre | QP 1,45 : fenêtre | marge contre 0,762 s |
|---|---|---|---|
| 0 (livré avant) | 0,25 s | 0,60 s | −0,51 / −0,16 |
| 4,0 | 0,767 s | 0,833 s | **+0,005** / +0,071 |
| **5,0 (livré)** | **0,833 s** | **0,850 s** | **+0,071 / +0,088** |

4,0 passait le grand quarterpipe **d'un tiers de tick** — un seuil qui ne
sépare rien (CLAUDE.md, CH65). 5,0 laisse plus de quatre ticks des deux
côtés ; le pic passe de 2,23 à **3,39 u** sur le grand (1,3 u au-dessus de
la lèvre — un air qui se VOIT, ce qui est en soi du feedback) et 3,46 sur
le petit ; la retombée reste dans la région (le grand jette à z 57,6 vers
le nord, le petit à z 47,3 vers le sud, sur l'emprise du rail).

### 1.3 — De bout en bout, par le vrai canal : le trick SORT

PHASE E rejoue la vraie rampe, la vraie sonde de doigt, et le pouce de
référence (12 ticks de réaction après le premier tick libre, puis un
cercle de r 40 à 400 px/s, 6,67 px par tick) :

| | horaire | antihoraire |
|---|---|---|
| quarterpipe 2,10 | **KICKFLIP en l'air**, tick 46 après la sortie | HEELFLIP en l'air |
| quarterpipe 1,45 | **KICKFLIP en l'air**, tick 51 | HEELFLIP **dans la grâce**, 6 ticks après le contact |

Le HUD imprime le nom (`SkateHud.trick_text()`), le pop audio part, le
deck tourne. **Le NÉGATIF** (pour que le gate puisse échouer) : un grand
cercle lent (r 80 à 250 px/s, 1,73 s) **ne tire pas** (fenêtre 65 ticks).
Et PHASE R rejoue le **vrai premier lancement** — planche montée là où le
jeu la gare (`SKATE_PARK` (3 ; 60), nez au nord), pivot vers le sud, tout
droit dans le 1,45 : lèvre atteinte 0,97 s après le pivot, **1 pop, 48
ticks armés, pic 3,525**, et **la caméra est encore 32,7° derrière** au
décollage (le pivot de 180° coûte 1,6 s à 110 °/s à la caméra, la course
0,97 s) — la planche reste dans le cadre (x 480-533, y 760-1050 sur
1080×1920 sous xvfb). D'où le protocole : **rouler une boucle d'abord**.

PHASE G, sur pop synthétique pour contrôler exactement ce qui est tracé
avant le contact : 200° tracés → grâce ouverte (15 ticks), cap gelé, le
cercle se ferme au sol au tick 12, UN kickflip, ancre sous le doigt, **le
deck tourne à la vitesse de l'AIR (19 ticks) et non claqué en 7** — un
flip qui COMMENCE au sol doit se voir (`_flip_slow`, gain ×3 réservé au
flip surpris par le contact) ; 60° tracés → coupé au contact ; 200° puis
doigt immobile → la grâce expire, rien ne tire, ancre sous le doigt.

### 1.4 — Le cadre, et un artefact de banc qui ne l'était pas tout à fait

Sous xvfb (1080×1920), la planche reste dans l'image pendant tout l'air du
grand quarterpipe (y 778-1113) et pendant le vrai premier lancement. La
station axiale du petit quarterpipe (garée à (5 ; 62), 0,6 u du bord du
lobe, nez au sud) ne peut PAS être filmée de derrière : la pose de
poursuite est hors région et `keep_inside` (CH64) la rabat — la caméra
n'y converge jamais (`forward·facing` = −0,83). La physique ne lit pas la
caméra, donc la FENÊTRE y reste valable ; le CADRE est signé par PHASE R,
la vraie station. Dit dans la sonde, pas maquillé.

## Section 2 — CHANTIER 1 : l'audit, MESURÉ (SkatePhysicsProbe PHASE X)

Inventaire de tout `CollisionObject3D` de l'arbre du hub, confirmé sur le
serveur (PHASE W), et chevauchement des solides DESSINÉS échantillonné sur
l'intersection des AABB (6 912 points par paire) :

| élément | physique ? | forme | état mesuré |
|---|---|---|---|
| funbox | **oui** | 3 hulls convexes (deck + 2 rampes) | collider = dessiné, 1 521/1 521 échantillons (PHASE V) |
| rail | **oui** | 3 boîtes (poutre + 2 pieds) | idem |
| quarterpipe 2,10 | **oui** | 12 wedges | idem |
| quarterpipe 1,45 | **oui** | 12 wedges | idem |
| **bol** | **NON** | — | 312 tri de béton, 288 de coping ; voir section 3 |
| coping / cornières (surface 1) | non, par conception | décor | 2,4 cm au-dessus du solide au plus (D5 : le décor est une seconde surface) |
| dalle 20×18 | non (D1) | 16 tri à 3-7 mm | `HubSurface` reste le sol |
| 3 portails | `Area3D` inertes | cylindres | `monitoring = false`, jamais de contact (CH55) |
| planche | `CharacterBody3D` | capsule couchée | le seul corps mobile |
| Keepy à pied, décor, arbres, pelouse | non | — | D2 : zéro collider hors du porteur |

**8 objets de collision, 34 formes, et le bol n'en ajoute aucune** — gaté.
Aucune paire de modules SOLIDES ne partage un échantillon. **Le bol, lui,
chevauche les deux quarterpipes** :

| paire | AABB communes | échantillons dans les DEUX solides | sommet du chevauchement |
|---|---|---|---|
| bol × quarterpipe 2,10 | 3,46 × 1,37 × 0,80 u | **968 / 6 912 (14,0 %)** | y 1,18 |
| bol × quarterpipe 1,45 | 1,16 × 1,37 × 1,48 u | **140 / 6 912 (2,0 %)** | y 0,37 |

Le bord du bol (r 3,60) passe à 2,87 u du coin est de la lèvre du grand
quarterpipe (0,73 u DEDANS) et à 2,92 u du coin du pied du petit (0,68 u
dedans). C'est la disposition CH53, pas un défaut de mesh : la jupe
verticale du bol perce le flanc est du grand quarterpipe sur 1,18 u de
haut. Dessiné, ça se voit peu (deux bétons sombres, caméra basse) ;
solide, ce serait **un mur de 1,35 u à l'intérieur de la rampe**.

## Section 3 — Le bol : la géométrie est FAITE et PROUVÉE, le collider reste dehors, et le gate le dit

### 3.1 — La décomposition exacte (SkateparkMesh.bowl_pieces)

CH56 §12.4 refusait le bol parce que VHACD **remplit** une cuvette ouverte.
L'objection vise l'outil. Ce que le bol EST, comme solide, c'est un
**ANNEAU** de béton : entre la surface du dish (le profil publié
`bowl_profile`, révolu) et la jupe verticale à r = 3,6, au-dessus de
y = 0. Le fond plat (r < 2,25) est la PELOUSE — D1, `HubSurface`, exactement
comme le sol sous les quarterpipes — et ne reçoit aucune pièce.

Dans un secteur d'azimut, la section de l'anneau est celle du quarterpipe :
la région sous une courbe convexe croissante, bornée par y = 0, la jupe
et la polyligne P0..P5. Le même éventail depuis le coin B = (r 3,6 ; y 0)
résout ses sommets rentrants, un prisme convexe par segment de profil
balayé sur UN secteur (faces planes : deux cordes de même rayon sont
parallèles). **24 × 5 = 120 pièces**. Un secteur par pièce est le MAXIMUM :
une coque sur deux secteurs corderait à travers la surface intérieure
concave — l'objection CH56, ressortie à deux secteurs de large.

Gaté, PHASE G : **l'union des 120 pièces est l'ensemble des 168 sommets
dessinés du béton, le centre du fan de plancher seul en dehors** (asserté
égal à 1) ; blind check 3 : un dish 2 % plus profond ne colle plus.

### 3.2 — Ridé sur un corps TEMPORAIRE (PHASE Y), et le vidage des contacts a tranché

Le ring est accroché à un `StaticBody3D` le temps de la phase (couche park
+ une couche à lui, pour que les scans ne comptent pas les tranches de
quarterpipe que l'AABB du bol contient — 56 faux « serveur » mesurés
avant), puis retiré et le serveur re-scanné vide.

| test | mesure |
|---|---|
| ring vs serveur (1 521 points, classificateur POLYGONAL à 24 côtés, hulls sans marge) | **0 désaccord** |
| ENTRER : lâchée à 0,6 u au-dessus de la lèvre, centre du dish | atterrit sur la PELOUSE (y 0,000, `on_module` false) au tick 23 |
| ROULER + REMONTER (roue libre à 4 u/s vers le mur) | tenue par le mur à 0,139 u, jamais au-delà de r 2,45 (jupe 3,60), revenue au fond au tick 77, 0 pop |
| REMONTER, doigt tenu dans le mur (plafond 4 u/s) | monte à 0,501 (plus haut que la roue libre), pas par-dessus la lèvre, **0 pop**, pas à travers, revenue au tick 125 |
| RESSORTIR (croisière) | tenue dans les deux dernières facettes (origine à 0,88-1,04 selon la charge machine : le bout avant de la capsule ride la facette raide en avance sur l'origine), **exactement 1 pop** — et c'est le pop qui prouve la lèvre (garde `cos 80°`) —, pic 3,26-3,36, retombe HORS de l'anneau (r 19,4), dans la région |
| retrait | le serveur ne trouve plus rien sur la couche (0) |

⚠️ **Le 0,139 u de la roue libre a d'abord été lu comme un défaut, et le
VIDAGE des contacts l'a démenti** (CLAUDE.md, CH57 : « un piège de moteur
ne se relit pas, il se vide »). Normales lues tick par tick :
`(−0,16 ; 0,99)` puis `(−0,45 ; 0,89)` — les facettes de 9° et 27°, des
sols. La planche perd 3,97 → 3,03 u/s sur la pelouse (le coast), 3,03 →
2,06 sur la facette de 9°, arrive à la facette de 27° avec 0,16 u
d'énergie et monte 0,139 — sur son **BOUT AVANT**, la capsule de 0,92 u
enjambant une transition de 1,35 u de rayon. Cinématique de la gravité,
rien n'accroche. Un essai à 12 anneaux (facettes de 7,5°) a donné le même
0,133 : ce n'était pas la finesse du profil.

⚠️ **Et c'est ce banc qui a durci le POP, deux fois** :

1. **double pop** sur une sortie : la planche effleure l'arête de la lèvre
   UN tick en sortant et repart en montant → +10 u/s, pic 5,28. Parade :
   `POP_MIN_HELD_TICKS 6` — on pope depuis un module qu'on RIDE, pas d'un
   module qu'on frôle ; le compte survit aux scintillements d'un tick du
   drapeau de sol aux joints de facettes (une remise à zéro à chaque
   scintillement ne popait plus jamais sur les cinq facettes courtes du bol).
2. **pop de bosse** : poussée dans le mur, la capsule saute de la facette
   de 9° puis rebondit sur les coins de 27-45° à 1,9 u/s vertical — un
   « décollage » qui n'est pas un ollie. Parade, en deux temps : d'abord
   « facette plus raide que 60° » (`n.y < 0,5`), qui a fermé le bol — puis
   **`SkateInertiaProbe` PHASE E a rougi sur l'arbre vert** : une planche
   en roue libre à 8,97 u/s dans le grand quarterpipe, à un mètre sous la
   lèvre (tenue à 1,106, facette de 61°), popait du mur à 1,866 et
   retombait dans la transition — un « pop de décrochage », et la
   signature d'énergie (même arrivée, même hauteur sur les deux rampes)
   passait de 1,165 à 2,014. Le pop est donc un **pop de LÈVRE** :
   `POP_MAX_NORMAL_Y = cos 80°`, la dernière facette de chaque transition
   qualifie (86,25° et 81°), celle du dessous (78,75°) non ; une planche
   qui manque de vitesse sur le mur redescend comme avant ce lot. La
   géométrie qui rend ce nombre juste est assertée (PHASE P), pas lue.

### 3.3 — Pourquoi il reste dehors, et comment ça se rouvre

`HubSkatepark.pieces_for()` rend toujours vide pour le bol, pour DEUX raisons
mesurées, aucune géométrique :

1. **le chevauchement de section 2** : un mur de 1,35 u dans le flanc est
   du grand quarterpipe ;
2. **aucune entrée au sol** : une jupe verticale de 1,35 u. Un bol solide
   ne se rejoint que par les airs, et la seule aire qui y mène (la
   retombée du grand quarterpipe, à 3,8-3,9 u de l'axe) atterrit sur le
   REBORD, pas dans la cuvette.

Les deux sont des questions de DISPOSITION (déplacer le bol d'environ 1 u
au nord-ouest — ce qui touche aussi la place de parking (3 ; 60) et la
règle d'emprise 5,6 u de CH53 — et lui donner un roll-in), c'est-à-dire un
lot de layout que le brief de ce lot ne couvre pas et que Mathieu a validé
par cadre. **PHASE X gate le périmètre sur la MESURE** : `pieces_for(bol)`
vide **si et seulement si** l'anneau partage des échantillons avec un
module solide. Le lot qui déplacera le bol verra la ligne rougir et lui
dire de retourner `bowl_pieces()`.

Coût si un jour il est câblé : 120 pièces × ≤ 0,000019 ms/tick (CH56/CH60)
= 0,0023 ms/tick, zéro primitive, zéro draw call.

## Section 4 — ROUGE AVANT VERT

Chaque mécanisme neutralisé dans une copie isolée de l'arbre, sonde
relancée, fichier restauré et vérifié byte-identique par `cmp` :

| # | neutralisé | sonde | rouges attendus | obtenus |
|---|---|---|---|---|
| R1 | `POP_SPEED` → 0,0 | SkateAirProbe | les fenêtres, le premier lancement, un trick de bout en bout | **4** : V[2] 0,367 s, V[3] 0,583 s, R 32 ticks armés, E[3] heelflip jamais — et E[2] tire encore : sans pop le grand quarterpipe enchaîne DEUX aires courtes (la lèvre, puis la chute derrière) et la grâce ferme le cercle sur la seconde ; dit ici parce qu'un compte de rouges se prédit |
| R2 | `GRACE_TICKS` → 0 | SkateAirProbe | E[3] antihoraire (tirait dans la grâce) + PHASE G | **7** : E[3] + G(a) ×5 + G(c) |
| R3 | `set_free()` neutralisé (polyligne ouverte à l'armement) | SkateAirProbe | le gate structurel « ouverte au premier tick libre » ×2 | **2**, exactement : ouverte au tick 105 = armement (au lieu de 101) |
| R4 | cap gelé en grâce → `in_air()` seul | SkateAirProbe | G(a) « la planche n'a pas tourné » | **1** : 0,29 rad de virage pendant la grâce |
| R5 | `_flip_slow` jamais posé | SkateAirProbe | G(a) le flip au sol à la vitesse de l'air | **1** : 6 ticks au lieu de 19 (et SkateTrickProbe PHASE F) |
| R6 | `POP_MAX_NORMAL_Y` → 1,0 | SkatePhysicsProbe | Y HELD : la poussée dans le mur du bol pope | **1** : pops 1 (rejouée après le passage à cos 80° : même rouge, même ligne) |
| R7 | `POP_MIN_HELD_TICKS` → 0 | SkatePhysicsProbe | Y EXIT : double pop | **2** : pops 2, pic 5,87 |

⚠️ **Un gate de sonde a d'abord rougi sur l'arbre VERT** : « la polyligne
s'ouvre au premier tick libre » exigeait le tick de l'arête du CORPS, et
elle s'ouvre un tick de contrôle plus tard (HubTransport lit le corps,
puis le fait avancer — là où `set_air` a toujours lu). Le gate accepte
`+1` et dit pourquoi ; c'est R3 qui prouve qu'il sépare encore (105
contre 101).

## Section 5 — La table croisée, deux arbres

⚠️ **UN ROUGE PRÉ-EXISTANT SUR `origin/main`, TROUVÉ PAR LA TABLE.**
`ChaseAudit` PHASE CALM était rouge sur l'arbre de RÉFÉRENCE :
« (blind) the carve really turned the board — 20 deg ». Le gate lisait
`angle_difference(début, fin)` ; CH64 avait laissé « add the summed
absolute turning so a 360 is not a 0 » en commentaire au-dessus d'un
`+ 0.0`. Avec le plafond de lacet CH65 (85 °/s), 240 frames de virage à
fond font **340°**, qui se lisent **20°** enroulés — CLAUDE.md CH42, mot
pour mot : « un braquage tenu dessine un cercle, et un cercle finit où il
commence ». CH65 n'avait pas rejoué `ChaseAudit`. Le gate somme désormais
le virage frame par frame (l'écart bout à bout reste imprimé) ; rejoué
sur les DEUX arbres avec la sonde corrigée.

Référence : `origin/main` `28adc89` (= `origin/staging`, arbre `94e85f7`),
copie importée à part (`/home/user/keepy-base`), **154 `.scn` = 154 `.scn`**
comptés des deux côtés avant toute comparaison.

| sonde | driver | branche | référence (`origin/main` 28adc89) | écart |
|---|---|---|---|---|
| `SkateTrickProbe` | headless | **54 / 0** | 54 / 0 | identique ; PHASE F re-gatée (un flip posé au sol tourne à la vitesse de l'air, 19-20 ticks) |
| `SkateInputProbe` | xvfb | **86 / 0** | 86 / 0 | identique |
| `SkateInertiaProbe` | headless | **102 / 0** | 102 / 0 | identique — la signature d'énergie (PHASE E/E2) est byte-pour-byte celle de la référence depuis que le pop est un pop de LÈVRE ; à 60° elle sortait 3 rouges (ratio 2,014) |
| `SkateTraverseProbe` | headless | **36 / 0** | 36 / 0 | identique (diagonale 66 hops / 18,700 s) |
| `SkateDriveProbe` | xvfb | **29 / 0** | 29 / 0 | identique |
| `SkateDismountProbe` | xvfb | **37 / 0** | 37 / 0 | identique |
| `SkateFeelProbe` | xvfb | **121 / 0** | 121 / 0 | identique |
| `SkateparkProbe` | xvfb | **57 / 0** | 57 / 0 | identique (zéro triangle, zéro draw call ajoutés : le ring n'est pas câblé) |
| `ChaseAudit` | xvfb | **33 / 0 PASS** | 33 / **1 FAIL** avec la sonde livrée, 33 / 0 avec la sonde corrigée | le rouge pré-existant de la section 5 (340° lus 20°) ; station skatepark identique (15 280 / 16 158 / 19 027 prims aux azimuts 0/45/90, les chiffres CH64) |
| `SkatePhysicsProbe` | headless | **148 / 0** seule (PHASES X, Y et le bol en G neuves ; PHASE I +0,008 ms/tick pour un plancher 0,024) ; 146 / 2 sur machine partagée (PHASE I, et le gate EXIT du bol depuis re-écrit sur les deux dernières facettes) | 121 / 0 seule ; 120 / 1 sur machine partagée (PHASE I : 0,107 contre un budget 0,10, plancher 0,052) | +27 assertions ; PHASE I est un banc de TEMPS et rougit des deux côtés dès que trois Godot partagent les quatre cœurs (branche : 0,203 pour un plancher 0,104 en table, **−0,009 pour un plancher 0,103 seule**) |
| `PhysicsCostProbe` | xvfb | NO VERDICT (18 ok) | NO VERDICT (18 ok) | les deux arbres, comme en CH64 : le plancher de bruit de ce sandbox |
| `ProbeTimeoutAudit` | headless | **97 scènes** | 96 scènes | +1 : `SkateAirProbe` (budget 1 200 s, dit pourquoi) |
| `SkateAirProbe` (neuve) | headless / xvfb | **40 / 0** headless, **42 / 0** xvfb (les deux gates de cadre) | — | sept passes rouges, section 4 |

Un runner par arbre, les deux en parallèle (plus, par moments, une
troisième sonde) : tout ce qui gate une DURÉE (PHASE I, `PhysicsCostProbe`)
s'est lu sur machine partagée et a été rejoué seul là où ça compte ; tout
ce qui gate une position, un compte ou un pixel est identique des deux
côtés.

## Section 6 — Ce que ce lot ne signe pas

* **Que le cercle est FACILE au pouce.** Le pouce de référence (r 40 px à
  400 px/s après 0,2 s de réaction) est une hypothèse publiée, pas une
  mesure du pouce de Mathieu. Si le device dit que c'est encore trop
  court, les trois nombres sont `POP_SPEED`, `GRACE_TICKS` et
  `TRICK_SWEEP_DEG`, chacun un commit.
* **Le ressenti du pop** (5 u/s = 1,3 u au-dessus de la grande lèvre) et
  **le FPS device** (le ring du bol n'est pas câblé : zéro coût ajouté ;
  PHASE I lit le park au repos sous son plancher, −0,009 ms/tick pour un
  plancher de 0,103).
* **Le premier lancement depuis la place de parking se fait caméra à
  33° du nez** : mesuré, dans le cadre, mais c'est la caméra CH64 (hors
  scope) qui décide si c'est lisible.
* **La poussée en l'air** (`push × n.y` avec n = UP quand rien ne tient la
  planche) est un trait du modèle CH61 : le doigt tenu accélère la planche
  horizontalement pendant l'air, jusqu'à la croisière — c'est ce qui la
  fait survoler la rampe au lieu de retomber dedans. Constaté, laissé tel
  quel (validé device sous cette forme depuis CH64), signalé ici.

## Section 7 — Protocole device

Ce que la sonde ne signe pas, et qui n'appartient qu'à Mathieu : la
facilité réelle du cercle au pouce, la lisibilité du pop, le FPS.

1. Ouvrir `keepy-staging.vercel.app`, aller au skatepark (lobe nord), taper
   la planche garée au nord du park (3 ; 60). Le rider monte, la caméra
   passe en poursuite.
2. **Rouler une boucle d'abord** : doigt tenu, faire un tour tranquille sur
   la dalle (5 secondes). La caméra se cale derrière la planche — au
   premier lancement direct depuis la place de parking elle est encore à
   33° du nez (mesuré).
3. **Le petit quarterpipe (1,45), le plus facile** : se placer au nord du
   park, à ~8 u de la petite rampe (celle de droite en regardant vers le
   sud, à x ≈ 5), nez au sud, doigt tenu DROIT (sans glisser) pendant 1 s
   pour être à la croisière. La planche monte la rampe, quitte la lèvre,
   fait un saut net d'environ 1,5 u au-dessus (le pop), retombe 5-7 u plus
   loin vers le sud, du côté du rail.
4. **Le trick** : dès que la planche quitte la lèvre (on la voit monter),
   SANS lever le doigt, tracer UN petit cercle avec le pouce — environ 1 cm
   de diamètre, en un demi-seconde environ, sens horaire = KICKFLIP,
   antihoraire = HEELFLIP. Le cercle peut se finir juste après le contact
   au sol : il compte encore un quart de seconde après l'atterrissage.
5. **Ce qui doit se voir** : le mot KICKFLIP ou HEELFLIP en gros en haut de
   l'écran (2 secondes), le deck qui fait un tour sur lui-même (un tiers
   de seconde), et le pop sonore. Si le mot apparaît, le trick est passé ;
   si le deck tourne sans le mot, dire lequel des deux manque.
6. **Le grand quarterpipe (2,10)** : à gauche (x ≈ −4), sa transition
   regarde le SUD — il faut l'aborder en roulant vers le NORD : descendre
   au sud du park, faire demi-tour, tenir le doigt droit 1 s, monter. Le
   pop y est le même (+1,3 u au-dessus de la lèvre), la retombée est
   derrière la rampe, au nord, à côté du bol.
7. **Deux cercles enchaînés dans un même saut** = deux tricks (le deck fait
   deux tours). Un cercle tracé AU SOL = un virage, jamais un trick.
8. À reporter : (a) le trick sort-il au moins une fois sur trois ? (b) le
   cercle est-il naturel ou faut-il « pichenetter » ? (c) le saut de 1,3 u
   se voit-il ? (d) le FPS pendant un saut (overlay Perf) ; (e) la planche
   traverse-t-elle toujours les murs du bol (attendu : oui, pas de
   collider, section 3).
