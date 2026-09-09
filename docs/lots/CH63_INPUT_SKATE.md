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
