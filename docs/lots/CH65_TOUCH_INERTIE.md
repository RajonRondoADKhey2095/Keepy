# CH65 — Le toucher de la planche : ce que la mesure a dit avant que le code bouge

> Retour device de Mathieu après CH64, mot pour mot : « le touch est trop
> sensible, il part dans tous les sens », « il faut ralentir la conséquence
> du touch, même la vitesse », « on n'arrive pas à calculer ses
> trajectoires ». Précisé sur relance : **deux** problèmes distincts —
> (a) la poussée est trop brutale au démarrage, (b) impossible de garder
> une vitesse stable en tournant.
>
> Le modèle d'inertie CH61 (push 17,2165 / brake 10,3433 / croisière
> 10,0 u/s) était marqué INTOUCHABLE « sauf raison mesurée et
> argumentée ». Ce retour EST cette raison. Ce lot a donc commencé par
> une **recon instrumentée sur l'arbre livré**, et n'a touché une ligne
> qu'après.

## Section 1 — RECON : les mesures, avant toute modification

Sonde jetable `SkateTuneRecon`, conduite **par le vrai canal d'entrée**
(`SkateTouchInput._unhandled_input`, vrais `InputEvent`), jamais par
`SkateBoardBody.hold()` — la leçon CH58. Headless : rien n'y lit un pixel,
une instance de `MultiMesh`, un viewport ni un shader.

Référence : `origin/staging` `737c77b`, importée à part, **154 `.scn` des
deux côtés** avant toute comparaison.

### 1.1 — Le modèle tel que `configure()` le résout (inchangé par ce lot)

```
cruise 10,0000 u/s | accel_u 3,2000 | brake_u 3,2000 | coast_u 18,0433
push 17,2165 u/s²  | brake 10,3433 | drag_k 0,038416 1/u | roll_stop 1,2805
camera : BOARD_YAW_RATE_MAX 110,0 °/s, BOARD_HEADING_LAMBDA 1,80
writer : SLOP_PX 16,0
```

### 1.2 — (a) La courbe d'accélération au démarrage

Doigt posé et tenu **dans la slop** (pas de cap, tout droit), depuis l'arrêt :

| | référence | CH65 |
|---|---|---|
| vitesse gagnée au tick 1 | **0,2656 u/s** (2,7 % de la croisière en UNE frame) | 0,0217 u/s (0,2 %) |
| 50 % de la croisière | frame 20 — 0,333 s | frame 26 — 0,433 s |
| 99 % de la croisière | frame 41 — 0,683 s | frame 47 — 0,783 s |

**Verdict recon** : la plainte est fondée, mais pas là où on l'attendrait.
0,683 s pour atteindre 10 u/s n'est pas absurde ; ce qui est brutal est que
le throttle passait de 0 à 1 **entre deux frames**, donc l'accélération de
0 à 17,2165 u/s² d'un coup — un **jerk infini**. C'est un défaut de
l'ENTRÉE, pas de la physique.

### 1.3 — La sensibilité brute, EN AMONT de tout taux borné

⚠️ **Première correction d'une prémisse du brief** : `BOARD_YAW_RATE_MAX`
(110 °/s, CH64) est un plafond **de la CAMÉRA**, pas de la planche. La
planche n'avait **aucun** plafond de lacet : `rotation.y = atan2(...)`,
posé, sans taux entre le doigt et le nez.

Le cap est la DIRECTION de l'offset du doigt, donc son gain angulaire vaut
`atan(1/r)` — inversement proportionnel à la distance parcourue, donc
**maximal exactement là où un pouce se repose**. Mesuré, et la mesure
reproduit l'arithmétique à la 4ᵉ décimale :

| offset | °/px (mesuré) | `atan(1/r)` |
|---|---|---|
| 17 px | **3,3665** | 3,3665 |
| 40 px | 1,4321 | 1,4321 |
| 140 px | 0,4092 | 0,4092 |
| 200 px | 0,2865 | 0,2865 |

Un tremblement de pouce à un offset de 20 px, 5 Hz, sur le cap **commandé** :

| amplitude | référence | CH65 |
|---|---|---|
| ±3 px | **17,06°** crête à crête | 8,59° |
| ±6 px | **33,40°** | 17,08° |
| ±10 px | **53,13°** | 28,09° |

Trois pixels, c'est moins d'un millimètre sur le téléphone de Mathieu.
**« Il part dans tous les sens » est cette ligne.**

### 1.4 — Ce qu'un pouce qui BOUGE fait au lacet de la planche

C'est la mesure décisive, et personne ne l'avait prise : `SkateInputProbe`
PHASE T tient le doigt **immobile**, et un doigt immobile est borné par la
boucle caméra — jamais par la planche.

| geste | référence | CH65 |
|---|---|---|
| pouce balayé à 150 px/s | 73,9 °/s | 79,4 |
| pouce balayé à **400 px/s** | **163,6 °/s** | **85,0** |
| pouce balayé à **800 px/s** | **326,4 °/s** | **85,0** |
| UN drag coalescé, tout droit → plein travers | **90° en UNE frame (5 400 °/s)** | **1,4° (85 °/s)** |

À toute vitesse de pouce qu'un joueur emploie réellement, **la planche
tournait plus vite que la caméra n'avait le droit de suivre** — d'une fois
et demie à trois fois. Le cadre ne pouvait pas montrer où la planche était
allée. **« On n'arrive pas à calculer ses trajectoires » est cette ligne.**
Un plafond posé sur la caméra que l'objet filmé peut dépasser n'est un
plafond sur rien.

Et le tremblement, de bout en bout, dans le lacet réel de la planche à la
croisière :

| tremblement | référence | CH65 |
|---|---|---|
| ±3 px | 2,46° crête à crête, pire taux 36,8 °/s | 1,23°, 18,2 °/s |
| ±10 px | 8,16°, **122,7 °/s** (au-dessus du cap caméra) | 4,09°, 60,6 °/s |

### 1.5 — (b) La vitesse en virage : LA MESURE CONTREDIT LE RESSENTI

Virage à fond tenu, entré à la croisière, sur sol **plat** (témoins publiés :
resté dans la région OUI, jamais sur un module, `y` de 0,0000 à 0,0000) :

| | référence | CH65 |
|---|---|---|
| `\|v\|` minimum | 8,5742 — **86,5 %** de l'entrée | 9,6779 — 97,6 % |
| vitesse AVANT (le long du nez) minimum | **0,2845 — 2,9 %** de l'entrée, dès la frame 1 | 9,5423 — 96,2 % |
| dérive en régime établi | **75,5°** | **9,4°** |
| throttle sur tout le virage | min 1,0000 / max 1,0000 | min 1,0000 / max 1,0000 |

**Deux conclusions, et elles tranchent les deux hypothèses du brief :**

1. **L'hypothèse « bug de couplage entre le cap et le throttle » est
   MORTE, par mesure** : le throttle ne quitte jamais 1,0000 de tout le
   virage.
2. **La vitesse ne chute pas** — `|v|` tient à 86,5 %. Ce qui s'effondre
   est la composante **le long du nez** : 2,9 %. La planche voyageait à
   **75,5° de dérive**, c'est-à-dire quasiment en travers, aussi longtemps
   que le doigt tenait le virage, parce que **rien dans ce modèle ne
   résistait au déplacement latéral**. Des roues, si. « La vitesse tombe en
   virage » était la seule forme que ce défaut pouvait prendre vu d'un
   téléphone.

## Section 2 — Ce que le lot a livré, et pourquoi chaque pièce

Cinq changements. Trois côté ENTRÉE (le brief demandait de privilégier
lisser l'entrée plutôt que réduire la physique), deux côté modèle.

| # | pièce | fichier | ce qu'elle répond |
|---|---|---|---|
| 1 | **rampe de throttle** `THROTTLE_LAMBDA 9.0` | `SkateTouchInput` | (a) le jerk infini. La montée est à la presse, la RETOMBÉE au relâchement est **immédiate** — une rampe descendante pousserait une planche qu'on a lâchée |
| 2 | **filtre du doigt** `FINGER_LAMBDA 14.0` | `SkateTouchInput` | le gain `atan(1/r)`. Filtre le doigt du CAP seulement : `_trace` marche toujours sur le doigt BRUT, sinon le chemin filtré étant plus court on relèverait en silence `TRICK_SWEEP_DEG` |
| 3 | **plafond de lacet** `YAW_RATE_MAX 85 °/s`, `PIVOT_RATE_MAX 240 °/s` sous 0,15–0,45 de la croisière | `SkateBoardBody` | la moitié que CH64 avait laissée : la caméra était plafonnée, la planche non |
| 4 | **poussée le long du NEZ** (au lieu du cap commandé) + **porte d'alignement** | `SkateBoardBody` | (b) l'essentiel de la dérive, et une planche ne se pousse pas de travers |
| 5 | **grip latérale** `GRIP_LAMBDA 8.0` + **plafond de VITESSE** | `SkateBoardBody` | les roues ; et « la croisière reste le plafond », littéralement |

### 2.1 — La pièce que la recon n'avait pas prévue, et qui fait le gros du travail

Poser un plafond de lacet crée un cas qui n'existait pas quand le nez
suivait le doigt instantanément : **le nez et le cap commandé diffèrent**.
Pousser le long du cap pendant que le nez est ailleurs, c'est une planche
bousculée en travers par ses propres jambes.

Mesuré : `SkateInertiaProbe` PHASE L gare la planche nez au nord et vise le
sud ; avec la poussée sur le cap, le run-up authored de CH54 (**3,20 u**)
a mesuré **9,798 u**. Avec la poussée sur le nez : **3,370 u** contre
3,309 u en référence — la rampe de throttle ne coûte donc que **0,061 u**,
soit **1,9 %** du 3,20 u authored.

⚠️ **Et c'est une passe rouge qui a corrigé l'attribution du mérite.**
Neutraliser `GRIP_LAMBDA` à 0,0 est revenu **ALL GREEN**. Mesuré plutôt
qu'argumenté, dérive en virage à fond :

| | dérive | vitesse avant conservée |
|---|---|---|
| arbre livré (avant CH65) | **75,5°** | 2,9 % |
| CH65, poussée sur le nez, **grip 0,0** | **19,5°** | 94,3 % |
| CH65, grip 2,0 | 15,6° | 96,1 % |
| CH65, **grip 8,0 (livré)** | **8,9°** | 98,5 % |
| CH65, grip 12,0 | 6,7° | 97,4 % |

**Le gros de la cure est le déplacement de la poussée sur le nez**
(75,5 → 19,5), la grip fait le reste (19,5 → 8,9). Le gate a été resserré
de 25° à **14°**, seuil qui SÉPARE réellement les deux ; à 25 il ne
séparait rien, ce qui est précisément pourquoi la passe rouge était verte.

### 2.2 — Le plafond de vitesse, et le défaut qu'il a fallu introduire pour le voir

Une version intermédiaire du lot (grip + plafond de lacet, poussée encore
sur le cap commandé) a fait monter la planche à **14,56 u/s** contre une
croisière de 10,0, **sur sol dont la sonde asserte qu'il est plat**. Le
plafond était pris le long du cap commandé (`along = v·cap`), et le nez
retardant de ~46°, `10 / cos(46,6°) = 14,56`. Le plafond mesurait la
direction de la poussée et l'appelait la vitesse.

Corrigé en plafonnant la VITESSE (`max(was, cruise)`, pour qu'une planche
arrivée plus vite par une transition garde ce que la gravité lui a donné).
⚠️ **Arithmétiquement absent d'une course en ligne droite** : `along` y vaut
`|v|` et le trim existant s'arrête déjà exactement à la croisière.

### 2.3 — Le nez tourne vite à l'arrêt, et c'est mesuré, pas une préférence

Un plafond plat à 85 °/s coûte 180/85 = **2,12 s** pour repartir dans
l'autre sens, et la porte d'alignement (à raison) ne donne aucune poussée
tant que le nez vise ailleurs : `SkateDriveProbe` a mesuré **0,004 u
parcourus en 90 ticks**. Monter sur une planche garée et repartir dans
l'autre sens est l'essentiel de ce qu'on fait dans un park de cette taille.

Le plafond est donc celui de la CROISIÈRE, interpolé depuis 240 °/s à
l'arrêt sur la bande **0,15 → 0,45** de la croisière (1,5 à 4,5 u/s).
⚠️ **La bande est basse et étroite pour tuer une boucle** : avec un genou à
0,70, PHASE T lisait **150,2 / 114,3 / 97,2 / 85,0 / 85,0 / 112,1** °/s —
la dernière fenêtre PLUS RAPIDE que la précédente, parce que le virage
avait dépensé assez de vitesse pour remonter dans la rampe. Bornée, mais
non convergente. Sur 0,15–0,45, tout ce qu'un joueur appellerait rouler est
sur un **85 °/s plat sans terme de vitesse dedans** : la boucle n'existe
plus. PHASE T lit désormais **146,2 / 105,2 / 102,9 / 85,0 / 85,0 / 85,0**.

### 2.4 — Le cap est devenu une grandeur PAR TICK, et c'est un changement de contrat

Le filtre du doigt est avancé par un `tick(delta)` **appelé par son
lecteur** (`HubTransport._advance_board`), pas par le moteur : le writer
est un ENFANT de `HubTransport`, donc laisser faire le moteur ferait lire
au parent un filtre vieux d'une frame — un décalage qui dépendrait de
l'endroit de l'arbre où quelqu'un a mis le nœud.

Conséquence assumée : **un banc qui délivre un drag et lit le cap dans la
foulée lit ZÉRO.** C'est le contrat, pas un accident : un pouce ne peut pas
demander un cap plus vite que la planche ne peut en être informée. Toutes
les sondes du dépôt ont reçu leur `physics_frame`.

## Section 3 — ROUGE AVANT VERT : six passes

Chaque mécanisme neutralisé un par un, sonde propriétaire relancée, fichier
restauré et vérifié **byte-identique** par `cmp`.

| # | neutralisé | rouges attendus | rouges obtenus |
|---|---|---|---|
| R1 | `GRIP_LAMBDA` → 0,0 | dérive + vitesse avant | **2**, exactement |
| R2 | plafond de lacet → set instantané | PHASE T (établi) + PHASE W ×3 | **4**, exactement |
| R3 | rampe de throttle → pas | PHASE C ×2 | **2**, exactement |
| R4 | filtre du doigt → suivi instantané | gate de tremblement | **1** — et il lit **33,40°**, le chiffre exact de l'arbre livré |
| R5 | porte d'alignement → 1,0 | PHASE G ×2 | **2**, exactement |
| R6 | plafond de vitesse → aucun | plafond de croisière | **1** — 10,011 u/s contre 10,0 |

⚠️ **Deux de ces passes sont revenues VERTES d'abord** (R1 et R6), et les
deux ont livré une trouvaille au lieu d'un haussement d'épaules : R1 que le
mérite était mal attribué et le gate trop lâche (25° → 14°), R6 que le gate
à ±2 % laissait passer un franchissement réel du plafond (10,011 > 10,0) —
resserré à `croisière + 0,005`, qui est de la marge flottante et pas de la
tolérance.

## Section 4 — Défauts de banc trouvés en route, chacun avec l'allure d'un résultat

1. **La station du banc ne tenait pas dans la région.** Depuis (0, 0, 35)
   un run-up de 90 frames pose la planche sur la funbox à z = 45,5 ;
   PHASE V a lu **14,56 u/s** en mesurant une planche qui DESCENDAIT une
   transition. Pire, **asymétriquement** : l'arbre livré dérive en travers
   à 2,2 u/s et n'y arrive jamais, donc les deux arbres étaient mesurés sur
   des sols différents. Station déplacée à (0, 0, 18) face au sud, et
   **chaque phase publie désormais son propre containment**.
2. **Un `0,00` qui ressemblait à une planche parfaitement stable.** Une
   ligne de PHASE J lisait 0,00° crête à crête : la planche n'avait jamais
   été montée (course perdue contre le hop de sortie de la phase
   précédente). Le témoin « ran 0.00 u » publié à côté de chaque lecture
   est ce qui l'a dit ; le montage est désormais réessayé, borné.
3. **Un banc qui gare une planche sans dire dans quel sens.** Inoffensif
   tant que le nez suivait le doigt instantanément ; depuis CH65 c'est un
   demi-tour de 2,1 s et une COURBE. `SkatePhysicsProbe` lisait la face de
   la funbox à x = −8,03 au lieu de 2,20, et un run neutralisé passait à
   3,009 u d'un volume qu'il devait traverser — deux lectures qui
   ressemblent à des défauts de collider.
4. **« Une planche coincée contre un mur ne tourne pas » — c'est FAUX**, et
   `SkateInertiaProbe` PHASE S l'a dit. La garde d'immobilisation du banc
   comptait le pivot comme un progrès sans borne, donc elle n'attrapait
   plus aucun mur. Bornée par `POINTED_ENOUGH` : tourner n'est un progrès
   que tant qu'il reste à tourner.
5. **Un doigt tenu à contre-sens n'est pas un demi-tour, c'est un CERCLE.**
   Sous la caméra de poursuite le cap commandé tourne avec le nez : tracé
   tick par tick, il marche (0,0,−1) → (1,0,−1) → (1,0,0) → (0,0,1). Gater
   « la distance parcourue à contre-sens » gatait un arc, et rapportait
   10,467 u sur une planche qui faisait exactement ce qu'il fallait.
6. **La pose de poursuite doit être ARRIVÉE avant qu'un doigt veuille dire
   quelque chose.** `mount_board()` ne fait que DÉMARRER le fondu ; un banc
   qui appuie la frame suivante pilote avec la base de la caméra du HUB.
7. **`SkateInputProbe` part de (12, 52)**, à 8 u du bord nord du lobe : le
   run-up de PHASE W sortait de la région, `_fence` appelait `stop()`, et le
   balayage mesurait ensuite une planche **à l'arrêt** — qui lit 240 °/s, le
   taux de pivot debout, et ressemble exactement à un plafond cassé
   (v = 9,915 u/s au tick 60, **0,000 au tick 89**).
8. **Une sonde dont le script ne parse pas ne tombe pas vite** : une
   réécriture a supprimé `_settle_chase`, et le run a traîné jusqu'au
   timeout **sans une seule ligne de sortie**. Le `--quit-after 2` l'a
   nommé en quelques secondes.

## Section 5 — Ce qu'un banc headless ne peut PAS signer

⚠️ **Écrit en tête parce que le lot précédent était vert partout et faux
quand même** (CH62). Rien ici ne dit que la planche est agréable. Ce que
les mesures signent :

* que la réponse est une **courbe** — bornée, monotone, continue — et
  qu'elle **BOUGE** (PHASE T gate que le pivot debout est mesurablement
  plus rapide que le cap de croisière, sinon une constante passerait
  chacun des autres gates) ;
* qu'un effet est **CÂBLÉ**, relu sur l'objet vivant pendant que le vrai
  mécanisme tourne, par le vrai canal de doigt ;
* que les chiffres ont **bougé dans le sens demandé**, et de combien.

**Le RESSENTI reste entièrement à valider par Mathieu sur device.** Une
courbe d'accélération plus douce en sonde ne garantit pas qu'elle sera
perçue comme telle, et 85 °/s peut se révéler trop lent à la main. Les
quatre nombres qui portent le ressenti sont `THROTTLE_LAMBDA`,
`FINGER_LAMBDA`, `YAW_RATE_MAX` et `GRIP_LAMBDA` ; chacun est une
constante unique, commentée avec sa famille mesurée, et un changement est
un commit — jamais un réglage in-app (CH64 est le lot qui a supprimé
ceux-là).
