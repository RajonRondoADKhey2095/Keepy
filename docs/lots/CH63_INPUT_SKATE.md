# CH63 LOT 1 — la capture d'input de la planche

> Cinq sections. Le lot livre une **seconde façon de piloter la planche**
> — drag continu pour le cap, tap court pour la poussée — derrière un
> interrupteur in-app TAP / DRAG, **sans toucher au modèle de conduite**.
> Ce qu'il prouve est la CAPTURE, pas le ressenti : le cap capté alimente
> encore le `set_target()` déjà livré, par un adaptateur explicitement
> temporaire. La caméra de poursuite, le refactor de `drive()`, le
> `ChaseAudit` et le reciblage des quatre sondes skate sont le LOT 2,
> hors scope ici et non entamés.

## Section 1 — CE QUE LE LOT LIVRE

**`SkateTouchInput`** — le patron d'ancre de `KartTouchInput`, copié et
non réinventé : le premier doigt posé devient l'ancre où qu'il tombe, un
glissement écrit un cap, un relâchement sans glissement émet `pushed`.

**UNE seule constante sépare les deux gestes**, et c'est délibéré : sous
`SLOP_PX` il n'y a pas de cap et un relâchement est une poussée ; au-delà
il y a un cap et le relâchement n'en est pas une. « Ce qui compte comme un
drag » et « ce qui compte encore comme un tap » sont la même question posée
des deux côtés ; deux constantes laisseraient s'ouvrir entre elles un trou
ou un recouvrement que rien ne signalerait. `_dragged` **s'enclenche** : un
glissement qui revient par l'ancre reste un drag.

⚠️ **Ce fichier RECONNAÎT un geste, ce que `KartTouchInput` refuse
explicitement de faire** (« nothing here is a gesture that has to be
RECOGNISED »). C'est une vraie propriété perdue, et elle est nommée plutôt
que subie : le brief demande deux sens sur un doigt, donc un seuil n'est
pas évitable — seulement nommable. Il est unique, et `SkateInputProbe`
PHASE C le gate **des deux côtés** (une gigue de 5 px est encore un tap,
un glissement de 120 px ne l'est plus).

**Le mapping écran → monde n'est écrit nulle part.** Il est DÉRIVÉ de la
base de la caméra livrée à chaque appel : écran +x = sa droite aplatie,
écran −y = son avant aplati. Le lacet de la caméra du hub vaut 0 dans la
scène, donc une constante tirée de cette lecture serait juste aujourd'hui
et silencieusement **en miroir** le jour où un lot fait tourner la caméra —
avec pour symptôme une planche qui braque de travers.

**`HubTapInput`** — un quatrième court-circuit de la même forme que les
trois véhicules pilotés, posé sur le ride **ET** sur le schéma. C'est lui
qui ferme la branche de tap de CH57 pendant un drag, donc ce qui fait qu'un
doigt a **un** sens. `_handle_point` et `_on_tapped_ground` ne sont pas
touchés : les dix états et dix-huit sondes qui les partagent ne sont pas
dans ce diff.

**`HubWorld`** — « Contrôle skate : TAP / DRAG », derrière
`DevTools.enabled()`, et il **ne recharge PAS la scène**. L'interrupteur
physique trois lignes plus haut, lui, le doit : il décide de quel TYPE DE
NŒUD la planche est faite, un choix de construction qu'aucun drapeau vivant
ne peut reprendre. Un schéma de contrôle ne décide que du writer armé —
`HubTransport.sync_board_input()` le bascule sur un monde vivant, en plein
ride si Mathieu le veut — et un rechargement coûterait précisément la
position et le ride sur lesquels l'A/B doit se sentir.

**L'adaptateur est temporaire et étiqueté tel quel.** `BOARD_DRAG_LEAD`
est le seul nombre qu'il écrit, et c'est une **MARGE, pas un goût** :
`drive()` freine au lieu de pousser dès que la cible entre dans la
distance d'arrêt (`v²/2b + ARRIVE_EPSILON`, soit `SKATE_BRAKE_U + 0,45` à
la croisière), donc une destination plus proche ferait **décélérer** un
geste qui veut dire « va ». Le double de la distance d'arrêt tient la
planche hors de sa propre fenêtre de freinage à toute vitesse
atteignable, et PHASE D gate **la propriété** (un drag tenu atteint la
croisière) et non le chiffre.

⚠️ **Tant qu'un doigt tient un cap, la garde d'immobilisation EST le
doigt.** Une carotte qui avance avec la planche ne laisse jamais
`remaining` s'améliorer, donc le `set_target()` de chaque tick est ce qui
empêche la garde de progrès de CH61 de tirer une demi-seconde après le
début de chaque drag. C'est écrit plutôt que découvert : cette garde existe
pour terminer une poussée que personne ne regarde, et sous ce schéma
quelqu'un regarde — il lève le doigt. Ce qui termine encore un drag dans un
mur est `_fence`, intouché, qui efface la cible au bord de la région.

## Section 2 — LE MAPPING, CONFIRMÉ EN PIXELS RENDUS

Exigence du brief (le lacet caméra « lu à 0 dans le code, jamais vérifié à
l'écran ») et double exigence de `CLAUDE.md` : « un mot de convention de
côté ne vaut rien sans une capture », et un objet destiné à être VU se gate
sur au moins un PIXEL (CH39).

Résultat, passe d'identification masquée sous `xvfb-run --rendering-driver
opengl3`, rider **à pied** (donc caméra immobile), planche peinte en
`(1 ; 0 ; 1)` unlit `disable_fog`, appartenance ssi la couleur revient
exactement, **blind check à 0 px** planche cachée :

| doigt | cap monde | distance | encre | centroïde | hors-centre |
|---|---|---|---|---|---|
| DROITE `(140 ; 0)` | `(1 ; 0 ; 0)` | 3,0 u | 163 px | (877 ; 1099) | **(+337 ; +139)** |
| GAUCHE `(−140 ; 0)` | `(−1 ; 0 ; 0)` | 3,0 u | 148 px | (202 ; 1097) | **(−338 ; +137)** |
| HAUT `(0 ; −140)` | `(0 ; 0 ; −1)` | 6,0 u | 66 px | (540 ; 792) | **(0 ; −168)** |
| BAS `(0 ; +140)` | `(0 ; 0 ; +1)` | 4,0 u | 373 px | (542 ; 1508) | **(+2 ; +548)** |

`cos` contre la direction du doigt : **0,925 / 0,926 / 1,000 / 1,000**. Le
lacet est bien nul À L'ÉCRAN, et le mapping livré est celui qu'un pouce
attend.

⚠️ **La distance de pose est une ÉCHELLE et pas un nombre, parce que le
cadre est étroit.** À 6 u de côté la phase a rapporté **ZÉRO pixel** pour
DROITE et pour GAUCHE, sur un mapping que PHASE D venait de mesurer juste à
cos 0,9998 : la planche n'était simplement pas dans l'image. C'est la
doctrine « un prop planté à plus de ~3 u de côté de Keepy n'est PAS à
l'écran », retrouvée par l'intérieur, et c'est une propriété du cadre
`KEEP_WIDTH` et non de quoi que ce soit que ce lot ait écrit.

## Section 3 — TROIS DÉFAUTS DE LA SONDE, CHACUN AVEC L'ALLURE D'UN RÉSULTAT

**(a) La sonde visait un POINT MONDE.** `AIM_AWAY` de
`SkateDismountProbe` (8 u devant), que cette sonde-là utilise correctement
puisqu'elle émet `tapped_ground` directement et n'en fait jamais un pixel.
Projeté, il tombe à **x = 1138 sur un canvas large de 1080** : hors
conteneur, donc `_handle_point` sortait à son test de rect et l'instrument
lisait « la route livrée est morte » à propos d'une route parfaitement
vivante. **Un doigt choisit un PIXEL, donc le banc en choisit un aussi.**

**(b) PHASE D mesurait la RÉGION.** À 180 frames la planche couvre 16,4 u
et, depuis `OPEN_GROUND`, atteint le bord du lobe skate (centre (0 ; 35),
rayon 28) : `_fence` refuse le pas, efface la cible, la planche glisse le
long du bord — `cos 0,858` contre un mapping correct. À 60 frames :
**cos 0,9998**, et la phase asserte désormais que le run est resté dans la
région.

**(c) PHASE M a mesuré deux fois autre chose.** D'abord **le retard de la
caméra** : elle lisait la position DESSINÉE d'une planche à laquelle la
caméra est collée, donc ce qui restait dans les pixels était le lissage
`FOLLOW_LAMBDA` plus la perspective — « vers le bas de l'écran » sortait à
**cos 0,416** sur un mapping exact. Puis, cadre immobilisé, **la MÉTÉO** :
la position dessinée était récupérée par une simple DIFFÉRENCE contre une
frame sans la planche, et le hub est un monde vivant — **11 375 pixels
échantillonnés diffèrent entre deux frames dont on n'a RIEN touché**,
l'encre de la planche vaut 16 000 à 38 000, et les quatre centroïdes sont
revenus à moins de 3 px du même point (sur Keepy, qui respire). C'est
« un delta sous son plancher de bruit n'est pas une mesure », atteint par
l'intérieur.

## Section 4 — ROUGE AVANT VERT, ET UNE PASSE ROUGE QUI EST REVENUE VERTE

**Passe 1 — le court-circuit neutralisé.** Prédiction : trois rouges, tous
en PHASE R. Mesuré : **exactement ces trois-là et rien d'autre** —
« la route `tapped_ground` livrée n'a PAS tiré », « un tap sur son propre
corps dessiné ne le fait PAS descendre », « et il n'a atteint aucune route
sol ». Fichier restauré **byte-identique** (`cmp`).

⚠️ **Passe 2 — le garde d'événement émulé neutralisé : ALL GREEN, deux
fois.** Il attendait un rouge sur « exactement une poussée ». Une
explication tracée a été écrite pour dire pourquoi, **et elle était fausse
aussi** : le garde a été neutralisé une seconde fois, avec la phase censée
l'attraper en place (PHASE E, ajoutée exprès), et le run est **redevenu
ALL GREEN**.

Ce qui EST mesuré, par un écouteur jetable et non par une lecture du moteur :
un `parse_input_event(ScreenTouch)` arrive comme
`InputEventMouseButton device=-1` **PUIS** comme `InputEventScreenTouch
device=0` — `emulate_mouse_from_touch` est vrai et le projet ne le pose
nulle part —, et `HubTapInput` lit les DEUX relâchements, ce qui est
pourquoi chaque tap d'écran de cette sonde fait tirer `tapped_ground`
**deux fois**. Le jumeau émulé est réel et il est **PREMIER**. Ce que le
garde achète contre lui n'est simplement pas atteignable depuis ce banc,
**donc ce lot ne prétend pas qu'il est gaté** — il est gardé comme la
défense propre du writer livré.

PHASE E reste utile pour une autre raison : les phases C, D et M appellent
toutes le handler **directement**, donc aucune ne verrait un writer qui ne
reçoit jamais un drag livré par le moteur. C'est « un fixture qui diverge
du réel sur un axe ne protège pas de cet axe », et l'axe est la LIVRAISON.

## Section 5 — CE QUI EST VERT, ET CE QUI RESTE AU LOT 2

`SkateInputProbe` : **57 assertions, ALL GREEN**, sous `xvfb-run
--rendering-driver opengl3 --fixed-fps 60`.

`SkateDismountProbe` (CH58, la sonde qui POSSÈDE la route de tap livrée,
et le seul chemin partagé que ce lot touche) : **90 assertions, ALL
GREEN** sur l'arbre du lot.

`ProbeTimeoutAudit` : **94 → 95 scènes**, exactement +1 pour la sonde
permanente, aucune sonde jetable laissée derrière (les deux écrites pour
le diagnostic — routage d'événements, dégagement des stations — ont été
supprimées avant le commit).

⚠️ **Ce que cette sonde ne peut PAS signer**, écrit ici plutôt que
sous-entendu : elle ne dit rien du RESSENTI. Elle signe qu'un cap est
capté, qu'il pointe où le doigt pointe (en pixels rendus), qu'une poussée
est un signal séparé, que la route livrée est **fermée** pendant un drag
et **rouverte** dès que l'interrupteur revient sur TAP. Savoir si conduire
au pouce est meilleur que taper au sol appartient à Mathieu, sur device.

**Reste au LOT 2, non entamé** : la bascule vers la caméra de poursuite
(et le `ChaseAudit` que `CLAUDE.md` exige avec elle — CH30 y a trouvé deux
défauts réels dans un hub que deux audits visuels avaient déclaré sain), le
refactor de `drive()` pour lire un cap plutôt qu'une destination, la
suppression de l'adaptateur, et le reciblage des quatre sondes skate
(`SkateDismountProbe`, `SkateInertiaProbe`, `SkateFeelProbe`,
`SkatePhysicsProbe`) sur le nouveau modèle.

# LOT 2 — LE THROTTLE CONTINU, ET LA PLANCHE PASSE À LA POURSUITE

*10 septembre 2026. Branche `claude/skatepark-throttle-continuous-45swg6`,
basée sur `origin/staging` (arbre `114891c…`, LOT 1 déjà mergé).*

## Section 1 — L'ERREUR DE SPEC DU LOT 1, DITE EN PREMIER

Le LOT 1 a livré « drag tenu = un cap, tap court = une POUSSÉE ». La
moitié poussée était une mauvaise lecture du brief : **Mathieu ne veut
aucune tape répétée**. Le contrat réel est un throttle **tenu** — doigt
posé, la planche est propulsée en continu ; doigt levé, roue libre et
l'inertie CH61 prend le relais telle quelle.

Le signal `pushed` **disparaît**. Ce qui le remplace n'est pas un second
geste, c'est l'**absence** d'un geste : le throttle est l'état du doigt.
C'est exactement le schéma de `KartTouchInput` (`input.throttle` tenu,
l'offset du doigt lu comme un axe), copié plutôt que réinventé, avec deux
différences qui sont des propriétés d'une planche et pas des goûts :
l'offset écrit un **CAP** (une direction absolue, pas un taux de braquage
— une planche n'a pas de colonne de direction), et le throttle est la
**présence** du doigt plutôt qu'un 1.0 permanent, parce qu'une planche
sans doigt dessus doit rouler libre.

## Section 2 — ⚠️ LE LOT 1 A LIVRÉ UN PATRON ÉCHELLE, ET IL FALLAIT LE FERMER

Trouvé en écrivant ce lot, pas signalé par une sonde. `HubTapInput`
court-circuite **tout** point pendant qu'une planche en mode DRAG est
montée — c'est ce qui donne « un doigt, un sens ». Mais le démontage
livré (« un tap sur son propre corps dessiné, planche à l'arrêt ») vit
**SOUS** ce court-circuit, dans `HubWorld`. Donc sous le schéma DRAG du
LOT 1, **il n'existait aucun moyen de descendre de la planche** : un
joueur enfermé dans un prop qui avale chacun de ses taps, c'est-à-dire
littéralement le PATRON ÉCHELLE que `CLAUDE.md` bannit.

Le LOT 2 le ferme avec le geste qui ne coûte rien d'autre : **un tap court
qui n'a jamais quitté la slop = SORTIE** (`signal tapped`). Sous la caméra
de poursuite il n'existe de toute façon plus de pixel fixe qui veut dire
« lui », donc c'est un tap **n'importe où**.

⚠️ **ET LE GESTE NE PEUT PAS ÊTRE SON PROPRE ÉTALON.** La porte est gatée
sur « la planche est à l'arrêt » — la règle du schéma TAP livré, pas une
nouvelle. Mesuré : le throttle s'ouvre **à l'appui**, donc au moment du
relâchement un tap a déjà poussé la planche pendant ses deux ou trois
ticks — **~0,6 u/s contre un seuil de repos de 0,24** — et un tap sur une
planche parfaitement immobile n'aurait **jamais** démonté. D'où
`SkateTouchInput.pressed`, émis **avant** que le throttle ne s'ouvre (une
ligne d'écart, et l'inverser recrée exactement le défaut), et
`HubTransport` échantillonne le repos **là**.

## Section 3 — CE QUI A QUITTÉ `SkateBoardBody`, ET CE QUI L'A SUIVI

`drive()` lit désormais **un CAP et un THROTTLE**, écrits par
`hold(heading, throttle)`. Le throttle est **SIGNÉ** : `+1` pousse le long
du cap, `0` roue libre, `-1` dépense le frein contre la vélocité — un seul
champ plutôt que deux, pour la raison de `KartInput` (un pouce ne peut pas
demander les deux, et deux champs laisseraient l'un survivre à l'autre).

Sont partis, chacun pour sa raison :

* **le run-out sur `remaining`** — il n'y a plus de cible à être « dedans » ;
* **la garde d'immobilisation (stall guard)** — une cible que personne ne
  regarde devait être lâchée ; un throttle tenu a un doigt qui le regarde,
  et ce doigt se lève.

⚠️ **MAIS LA DESTINATION N'A PAS DISPARU — ELLE A DÉMÉNAGÉ.** L'A/B
TAP / DRAG doit rester jouable mid-ride, donc le schéma TAP doit se
comporter exactement comme CH54/CH57 l'ont livré : taper un point, y
rouler, s'y arrêter. C'est maintenant un adaptateur **dans l'autre sens**
(une destination transformée en cap + throttle), et il vit dans
`HubTransport` parce que c'est le seul fichier qui possède encore le
concept de destination. **Le run-out et la garde l'ont suivi**, avec
`BOARD_ARRIVE` (lu sur `KeepyHopper`) et `BOARD_STALL_STEP` (lu sur
`SkateBoardBody.REST_STEP`) : une seule orthographe des deux nombres.

Il reste **UN modèle de conduite avec DEUX façons d'être interrogé**, pas
deux modèles.

⚠️ **LA GARDE DE `_fence` A DÛ DEVENIR UN SIGNAL.** La barrière de région
n'a plus personne à qui parler : elle émet `fenced`, et l'adaptateur lâche
sa destination dessus. Et c'est **sûr** uniquement parce que le cap est
**ÉCRIT et pas intégré** : l'arithmétique CH42 (`le gain de braquage est
proportionnel à v_fwd, donc un mur supprime la direction`) a déjà coûté
trois véhicules à ce dépôt, et elle mord un modèle dont le taux de virage
est mis à l'échelle par la vitesse avant qu'un mur mange. Le cap de cette
planche vient droit du pouce : une planche épinglée contre la région garde
**tous** ses degrés d'autorité.

## Section 4 — LA CAMÉRA, ET POURQUOI ELLE SUIT LE SCHÉMA ET PAS LE MONTAGE

Option A tranchée par Mathieu : `enter_drive`, le patron des véhicules
pilotés, **pas** `enter_ride` de CH62 pour la pose.

⚠️ **MAIS ELLE EST DÉCIDÉE PAR `sync_board_input()`, PAS PAR
`mount_board()`**, et ce n'est pas de l'élargissement de périmètre — c'est
la règle de `CLAUDE.md` lue honnêtement. La table des caméras se décide
sur le **PILOTAGE CONTINU**, et *lequel des deux schémas est sélectionné*
est exactement la question de savoir si cette planche est pilotée en
continu. Sous DRAG elle l'est → pose de poursuite ; sous TAP elle est
tapée vers une destination comme celle de CH54 → pose **FIXE**, inchangée
en tout point. Deux conséquences, dites plutôt que découvertes : l'A/B
reste un test du **schéma de contrôle** seulement si chaque schéma est
jugé avec la caméra que `CLAUDE.md` lui donne ; et le bouton mid-ride
déplace la caméra mid-ride, en **blend** de 0,9 s dans les deux sens, pas
en coupe.

⚠️ **ET `enter_ride` EST TOUJOURS APPELÉ, POUR UNE SEULE CHOSE.** C'est lui
qui publie le `rush` lissé, et `SkateStreaks` lit exactement ça
(`ride_rush() * ride_blend()`) — `CLAUDE.md`, un fait est publié une fois.
Ses trois termes de **POSE** sont inertes tant qu'une conduite tourne, et
c'est de l'arithmétique et pas une promesse : `HubCamera._process` prend
la branche conduite, qui ne lit jamais `_ride_offset()` et n'écrit jamais
`fov_gain`. Supprimer l'appel aurait tué **silencieusement** les traînées
de vitesse — un effet livré et validé device — dans un lot qui ne parlait
pas d'elles.

## Section 5 — LE ChaseAudit, ET LA STATION QU'IL N'AVAIT PAS

`CLAUDE.md` exige cet audit **avec** une caméra de poursuite. Ses cinq
stations sont les cinq zones où roulent les trois véhicules antérieurs ;
**aucune** n'est le lobe nord, c'est-à-dire là où ce véhicule-ci vit
réellement et où CH52 a relevé **zéro budget de frame**. Une sixième
station a donc été ajoutée, au **skatepark** — littéral **gaté** contre
`HubSkatepark.PARK_CENTRE` (un initialiseur de `const` de ce moteur ne
peut pas prendre un membre d'un `const Vector2` d'une autre classe), au
régime des centres de lacs.

`ChaseAudit` : **14 checks, 0 échec, PASS**, 192 frames
(6 stations × 8 azimuts × 4 météos), contre 13 checks / 160 frames sur
la baseline. Ce que le skatepark rend, en primitives sur la ligne `gpu` :

| azimut | 0 | 45 | 90 | 135 | 180 | 225 | 270 | 315 |
|---|---|---|---|---|---|---|---|---|
| gpu | 16 851 | 17 451 | 20 034 | 55 698 | **85 289** | 61 754 | 31 191 | 18 219 |

Ciel au pire **36,6 %** (aucun trou dans le monde), aucune frame noire.
Le pire azimut du park (85 289, plein sud, vers le plateau) reste **sous**
la pire frame du hub entier (**102 478**, storm/cove/270), et sous les
102 803 que `CLAUDE.md` publie déjà comme borne LOD0 du spawn. Aucun
enroulement fautif (8 rubans construits à la main, l'ancre StreamBank
comprise), aucun `visibility_range_end` sous la bande lisible de 73 u,
aucun arbre sous 0,15 de luminance effective.

## Section 6 — ⚠️ LE FAUX ROUGE DU LOT, ET IL VIVAIT DANS UN COMPTEUR

`SkateFeelProbe` PHASE B est sortie **1 rouge** sur la branche et verte sur
la baseline : `total_prims` ON 72 203 contre OFF 72 205, **delta −2**,
reproductible **à l'intérieur du run** (les deux lectures identiques). De
quoi lire « le lot coûte −2 primitives à l'arrêt », ce qui n'a aucun sens.

Deux relances du **même arbre** ont donné 72 203 / 72 203 → **ALL GREEN**.
`CLAUDE.md` : *un gate qui ne se reproduit pas sur un seul arbre ne peut
rien dire de deux.* Mais la cause a été **mesurée** plutôt que supposée,
par une sonde jetable (supprimée avant le commit) :

```
label visible=true  chars=241
FPS 9  (min 1)
TRI gpu 70 923   lod0 cadre 256 453   scene 346 624
...
total_prims  with 72203   without 71853   -> le label vaut 350 primitives
```

**`total_prims` compte le TEXTE de l'overlay de perf** : 350 primitives de
quads de glyphes, dont la première ligne est `FPS 9  (min 1)`. **Un chiffre
de moins dans une lecture de FPS = deux primitives de moins**, et c'est
pire que du bruit — c'est **auto-référentiel** (l'overlay imprime le
nombre même qui est gaté, une frame en retard). Le test de tremblement de
la sonde ne peut pas l'attraper : ses deux lectures sont à 8 frames
d'écart, ce qui ne suffit pas à faire tourner un chiffre de FPS.

Correctif : la sonde **mute le Label de l'overlay sur les DEUX mondes**
avant de lire, avec le blind check que `CLAUDE.md` impose (le mute doit
avoir **retiré** quelque chose, sinon « l'overlay est hors du compte » et
« l'overlay n'y a jamais été » se lisent pareil). Après : **71 853 des deux
côtés, delta 0, deux runs de suite**.

## Section 7 — ROUGE AVANT VERT : SIX PASSES, ET UNE EST REVENUE VERTE

| # | neutralisation | rouges attendus | rouges obtenus |
|---|---|---|---|
| 1 | le throttle ne s'ouvre jamais (`throttle = 0.0` à l'appui) | le throttle et tout ce qu'il propulse | **12**, tous throttle/déplacement |
| 2 | `tapped.emit()` supprimé | le geste de sortie, des deux côtés | **4**, exactement les assertions de sortie |
| 3 | le latch de cap du LOT 1 restauré | le suivi continu du doigt | **1** — « un doigt revenu dans la slop n'écrit aucun cap » |
| 4 | le run-out de l'adaptateur TAP retiré | la distance d'arrêt du schéma TAP | **1** — « L le roll ENDS at the tap (**17,344 u** de dépassement) » |
| 5 | la garde d'immobilisation de l'adaptateur retirée | les deux assertions de garde | **2**, sur `SkatePhysicsProbe` |
| 6 | `fenced.emit()` supprimé | ? | **0** — sur `SkatePhysicsProbe` ET `SkateDismountProbe` |

⚠️ **LA PASSE 6 EST REVENUE VERTE, ET CE N'EST PAS QUE LE FIL EST INUTILE.**
La garde d'immobilisation atteint le **même état final trente ticks plus
tard**, donc une sonde qui demande seulement « la destination a-t-elle fini
par disparaître » ne peut pas les distinguer. Ce qui les sépare, c'est
**QUAND**. D'où une PHASE F neuve dans `SkateInputProbe`, qui gate le
**tick** : blind check d'abord (un tick **dans** la région ne lâche rien),
puis le corps posé hors région et un seul `drive()`. Passe 6 rejouée avec
la phase en place : **1 rouge**, exactement celui-là.

Chaque fichier neutralisé a été restauré et vérifié **byte-identique**
(`cmp` + `md5sum`).

## Section 8 — LA TABLE CROISÉE, DEUX ARBRES, MÊME MACHINE, RUNS SÉPARÉS

Import complet vérifié des deux côtés **avant** toute comparaison :
**154 `.scn` = 154 `.scn`** (`CLAUDE.md` : compter les `.scn` des deux
côtés avant de comparer quoi que ce soit).

| sonde | branche | baseline `origin/staging` | écart |
|---|---|---|---|
| `SkateInputProbe` | **79 / 0 red** | 57 / 0 red *(version LOT 1)* | +22, contrat réécrit + PHASE F |
| `SkateInertiaProbe` | **86 / 0** | 86 / 0 | identique |
| `SkatePhysicsProbe` | **122 / 0** | 121 / 0 | +1 (`BOARD_STALL_STEP` = `REST_STEP`) |
| `SkateDismountProbe` | **90 / 0** | 90 / 0 | identique |
| `SkateFeelProbe` | **136 / 0** | 135 / 0 | +1 (instrument du mute d'overlay) |
| `ChaseAudit` | **14 / 0 PASS** | 13 / 0 PASS | +1 (station skatepark) |
| `ProbeTimeoutAudit` | **95 scènes** | 95 scènes | identique — aucune sonde jetable laissée |

## Section 9 — CE QUE CE LOT NE SIGNE PAS

* **Le RESSENTI.** Les sondes signent qu'un doigt tenu propulse, que le cap
  suit le doigt, que lever ne freine pas, qu'il existe une sortie et que la
  route livrée reste fermée pendant un drag et rouverte dès le retour sur
  TAP. Savoir si c'est **agréable** appartient à Mathieu, sur device.
* **Le TAUX DE VIRAGE.** Le facing est écrit **directement** depuis le
  pouce, sans taux entre les deux — c'est la lecture littérale de « la
  direction suit la position du doigt en continu ». Ce qui l'empêche de
  lire comme un claquement n'est pas un lissage ici : la **vélocité** est
  intégrée (un cap inversé dépense `push` contre l'élan au lieu de le
  téléporter) et la caméra de poursuite retarde le cap de
  `DRIVE_HEADING_LAMBDA`. **Si device dit que c'est encore trop sec, un
  taux de virage est le premier bouton** — et il appartient à un lot de
  feeling avec un nombre mesuré sur un téléphone, pas inventé ici.
* **Le cercle du doigt tenu de côté.** Sous la poursuite, la base caméra
  **lace avec la planche** : tenir le doigt à droite fait tourner la
  planche, ce qui tourne la caméra, ce qui déplace où « droite » pointe —
  un **cercle régulier**, exactement ce que fait un braquage tenu sur tout
  véhicule à caméra de poursuite de ce dépôt. « Haut de l'écran » est le
  point fixe de cette boucle, et c'est le seul offset contre lequel
  PHASE D peut mesurer le mapping plutôt que la caméra ; **les côtés sont
  gatés en PIXELS par PHASE M, caméra garée**.

## Section 10 — ⚠️ LA BOUCLE A UN TAUX, ET LA PRÉDICTION ÉTAIT FAUSSE D'UN FACTEUR 3

`CLAUDE.md`, CH42 : *un braquage tenu dessine un cercle*. Sous la
poursuite, le mapping du cap est une **boucle de contre-réaction** (le
doigt écrit le cap depuis la base caméra, la caméra retarde ensuite vers
le cap de la planche), et un taux que personne n'a mesuré est un taux que
personne ne peut prédire depuis un téléphone. PHASE T le mesure et le
**publie**.

L'arithmétique évidente — un retard du premier ordre à
`DRIVE_HEADING_LAMBDA` tenant un offset `φ` tourne à `ω = λ·φ` — prédit
**324 °/s** pour un doigt tenu à 90°. **Mesuré, six fenêtres d'une seconde,
doigt tenu plein travers :**

```
30,2   107,1   104,7   105,8   106,5   105,8   deg/s
```

**~106 °/s**, soit un facteur **3,1 en dessous** de la prédiction : l'offset
effectif entre l'avant caméra et le cap se stabilise à **~29°** et non à
90°, parce que la pose de poursuite ne regarde pas le long de
`_drive_heading` mais **vers un point en avant du véhicule**. Un tour
complet en **3,4 s**, soit un rayon d'environ **5,4 u** à la croisière —
c'est un **carve**, pas une toupie. La prédiction aurait fait rejeter le
schéma sur du papier.

⚠️ **ET LA PREMIÈRE VERSION DE CETTE PHASE A LU L'INVERSE.** Deux fenêtres
au lieu de six : **30,2 puis 107,1**, et elle a déclaré la boucle
**divergente**. La boucle montait simplement encore — elle part d'une
planche qui pointe où la caméra pointe (retard nul) et le retard doit se
construire avant que le taux ne le fasse. **Un test de convergence dont la
fenêtre est plus courte que le transitoire mesure le transitoire.**

Ce qui est **gaté** est seulement que la boucle **converge** (la dernière
seconde n'est pas plus rapide que la précédente) et qu'aucune fenêtre ne
passe le plafond du retard : le **taux lui-même est un nombre de
ressenti**, et un seuil inventé ici serait un goût déguisé en contrat.
