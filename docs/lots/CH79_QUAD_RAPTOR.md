# CH79 — Le quad raptor, sixième véhicule et première MONTURE du hub

| | |
|---|---|
| **date** | 12 septembre 2026 |
| **branche** | `claude/bouncing-ball-quad-raptor-d3mag6` |
| **base** | `origin/staging` (= `20cf6b8`), après CH78 |
| **fichiers neufs** | `scripts/hub/QuadRaptorBody.gd`, `scripts/dev/QuadProbe.gd` + `.tscn` |
| **fichiers touchés** | `HubTransport.gd`, `HubWorld.gd`, `HubTapInput.gd`, `MinimapProbe.gd` |
| **palier** | 1 — `staging` |

## 1. Recon bloquant — les trois questions du brief, tranchées

### 1.1 « Le karting a-t-il un contrôle réellement continu ? » — OUI, et il n'est pas seul

`KartTouchInput` est le schéma, et il est **le seul endroit où il vit** :
accélérateur automatique, le PREMIER doigt posé devient l'ANCRE, glisser à
gauche/droite braque proportionnellement, glisser **haut** demande de
l'allure et **bas** la marche arrière — **UN axe** (CH43), jamais un geste
à reconnaître, et la sortie est un **bouton de HUD** et pas un swipe.

### 1.2 « Le karting est-il confiné ? » — OUI, mais la référence libre existe déjà

Le kart est enfermé sur son circuit (zone 3, `KartTrack`). **Mais trois
véhicules conduits en continu roulent déjà librement sur le terrain du
hub** — le char à voile (CH30), le voilier (CH33) et la **luge** (CH41) —
et la navigabilité d'un véhicule terrestre est **déjà publiée** :

```gdscript
SandYacht.drivable(p)  ==  HubRegion.contains(p) and not HubRegion.in_circuit(p)
```

⚠️ **Il n'y avait donc RIEN à valider de neuf sur la navigabilité.** La
question du brief — « la collision du véhicule a-t-elle besoin de sa
propre validation, distincte de `ZoneNavProbe` ? » — a une réponse
antérieure au lot : un véhicule conduit **n'utilise pas le routeur
piéton** (il n'a pas de destination à router), et la non-convexité de la
région est absorbée par le **glissement séparé par axe** de
`SandYacht._wall()`, trois tentatives dans le même ordre, qui borne le
yacht, le voilier et la luge depuis CH30 sur ce même terrain. CH77 a
élargi la région ; une région plus large ne peut qu'agrandir cet ensemble.

Le quad **hérite de ce prédicat par lecture** (`QuadRaptorBody.drivable()`
rend `SandYacht.drivable()`), jamais par recopie.

### 1.3 « Où le joueur choisit-il un transport ? » — nulle part, et c'est le patron

Il n'y a **pas de garage**. Chaque véhicule est **garé là où il
appartient**, tapé dans le monde, marqué sur la minimap : le ballon sur le
plateau de spawn, le char à voile dans la Crique, le voilier au mouillage,
la luge au sommet de la crête ouest, la planche au skatepark. La monture,
elle, est **la chose qu'on prend pour traverser la carte**, et la carte se
traverse depuis là où le joueur démarre : elle est garée **sur le plateau
de spawn**.

### 1.4 `is_afoot()` — UN seul appelant, et c'est le bon

Exposé par CH73, lu par **`HubTapInput._orbit_licensed()` et rien
d'autre**. Son docblock dit que ce qu'il signifie est le **SCHÉMA DE
CONTRÔLE** et pas la posture. Monter la monture met Keepy `ON_CARRIER`,
exactement comme le kart, le yacht, le voilier et la luge — donc
`is_afoot()` bascule **sans une ligne de code d'état parallèle**. Gaté.

## 2. Ce qui est construit, et ce qui est REPRIS

| pièce | d'où elle vient |
|---|---|
| cinématique + requête de sol | `SurfaceDrive` (CH41), *le composite que CH35 Q2-B destine explicitement au véhicule NEUF* |
| modèle de conduite | `VehicleDrive`, celui des cinq autres, configuré avec les nombres de cette bête |
| écrivain d'entrée | `KartTouchInput`, inchangé |
| caméra | `ChaseTuning.vehicle()`, le défaut des quatre autres |
| porteur du rider | `mount_carrier()` → `ON_CARRIER` |
| mur | `SandYacht._wall()`, forme SledBody (hauteur de sol au refus) |
| porte (monter / conduire / descendre) | `HubTransport`, la forme de `mount_sled` / `exit_sled` |
| boîtes du maillage | `SledBody._box`, **appelée et non copiée** — CH39 y décide l'enroulement |

⚠️ **Rien de neuf dans le patron de contrôle**, ce que le brief demandait
en toutes lettres.

## 3. Le park — mesuré, pas choisi

`HubParkRecon`, grille 0,5 u, 365 disques publiés, **posé au monde que
CH78 laisse derrière lui** (le disque du ballon à son NOUVEAU park —
interroger un monde qui n'existe plus est comment un lot expédie un prop
dans un autre).

Six contraintes → **7 501 candidats** :

| on retire | candidats |
|---|---|
| **drivable** | **7 501** ⟵ INACTIVE |
| la zone 0 | 28 465 |
| le sec | 10 773 |
| le dégagement des disques | 17 549 |
| **la dalle / le circuit** | **7 501** ⟵ INACTIVE |
| les 6 u de dégagement de départ | 12 994 |

⚠️ **DEUX DES SIX NE RETRANCHENT RIEN** — la zone 0 implique déjà le sol
conduisible et exclut déjà le circuit et la dalle. Ce qui borne vraiment
est le dégagement des disques et les **6 u de sortie** : *un véhicule garé
qui ne peut pas partir n'est pas garé, il est coincé.*

Quatre propriétés choisissent ensuite le point, chacune un nombre :

1. dégagé de tout disque publié par `ARRIVE_EPSILON`, et son propre disque
   **tient dans la région** sur 16 azimuts à la même marge (CH21) ;
2. dans le cône de cadre du spawn avec 0,5 u de reste ;
3. à au moins `QUAD_FOOTPRINT + HubWorld.KEEPY_CLEARANCE` (1,6 + 0,66) du
   point de spawn, sinon **Keepy démarre la session DEDANS** ;
4. à au moins `QUAD_TAP_RADIUS` de l'axe nord-sud de la place, pour que le
   disque de montée n'enjambe jamais la marche hors de la place et ne vole
   pas un tap destiné au sol.

⚠️ **Les trois points PLUS PROCHES ((0,5 ; 1), (−0,5 ; −1), (−0,5 ; −2),
tous à moins de 2,1 u) échouent à (3), et les deux à 3,5 u échouent à
(4)** — donc la réponse est celle d'une règle énoncée et pas le premier
endroit plausible.

**`QUAD_PARK = Vector3(3.5, 0.0, -7.5)`** — 8,276 u du spawn, 0,517 u de
dégagement. Son miroir (−3,5 ; −7,5) obtient le même score sur les quatre :
l'égalité est tranchée par le seul fait qui les distingue — **CH78 a mis le
ballon à x = −8**, donc les deux véhicules tapables sont de part et d'autre
de l'axe et un tap près de l'un ne peut jamais être lu comme l'autre.

## 4. Deux tables de dispatch désarmées

⚠️ `vehicle_position()` et `vehicle_tap_radius()` finissaient toutes deux
par **`return ball_position()` / `BALL_TAP_RADIUS`** — la forme exacte que
CH76 documente : *une table de dispatch devient fausse au membre suivant,
en silence*. Un `VEHICLE_QUAD` ajouté sans branche aurait reçu la position
du ballon. **Les deux ont une branche explicite, gatée par PHASE M.**

⚠️ **Dette préexistante trouvée et fermée** : `mount_yacht()` et
`mount_sailboat()` ne testaient pas `_driving_sled` (CH41 avait ajouté le
drapeau à sa propre garde, pas aux deux plus anciennes). **INERTE** — un
rider de luge est `ON_CARRIER` et `_on_tapped_vehicle` refuse là-dessus
avant d'y arriver — mais fermée quand même : une garde qui nomme quatre
drapeaux sur cinq **se lit comme la table complète** et le véhicule suivant
hérite du trou (doctrine ON_CARRIER de `CLAUDE.md`).

⚠️ **Dette préexistante trouvée et NON fermée, signalée** : `HubTapInput`
porte quatre shunts de véhicule conduit (kart, yacht, voilier, planche) et
**la LUGE n'y est pas**. Inerte pour les mêmes raisons. Non corrigée : ce
fichier est le chemin de tap piéton, et élargir le changement au-delà du
véhicule du lot achète du risque et aucune mesure. Le quad, lui, **a son
shunt** — non par redondance mais parce que la licence d'avaler un point
appartient à « un véhicule est piloté » et pas à un état qu'un autre lot
peut élargir.

## 5. Le placeholder

Boîtes primitives, couleurs de sommet, matériau décor — **unlit comme tout
le reste, donc les couleurs écrites SONT celles qui s'affichent**. Sept
boîtes pour la coque (corps, cou, tête, museau, deux segments de queue,
selle) et quatre pattes qui **balancent**, chacune un nœud à elle.

**132 triangles au total** (84 + 48), mesuré et publié en DEUX nombres.

⚠️ **La silhouette est le sujet, pas l'anatomie** : sur une carte unlit un
flanc n'a aucun indice de pente (CH35-C), donc le contour est la seule
chose qui dise « animal » plutôt que « caisse » — c'est pourquoi un
placeholder porte une queue et un cou. Teinte **choisie en luminance
contre le sol** : le sol du hub rend à L 0,0799 et ses bandes d'herbe sont
des verts moyens, donc une monture verte serait une silhouette sans arête
sur la seule surface où elle se tient toujours. Turquoise + ocre.

⚠️ **La démarche court sur la DISTANCE PARCOURUE, pas sur le temps**, et
elle est avancée **après le mur** : un placeholder dont les pattes pédalent
à l'arrêt se lit comme un bug, et une monture tenue contre une haie a
parcouru zéro.

⚠️ **Pas de vignette de minimap**, et c'est le choix de la planche pour sa
raison : une entrée de `THUMBS` est un **PORTRAIT cuit sur le monde
construit** (CH48), donc en déclarer une ici cuirait une photo d'un
PLACEHOLDER que le lot Meshy devrait penser à re-cuire.

## 6. Les nombres de conduite, et lesquels sont du goût

⚠️ **La croisière est DÉRIVÉE de la marche, pas tapée** :
`WALK_PACE = HOP_DISTANCE / HOP_DURATION = 5,357 u/s`, et
`MAX_SPEED_FLAT = WALK_PACE × PACE_RATIO`.

⚠️ **`PACE_RATIO = 2,2` EST UN NOMBRE DE GOÛT, ET C'EST DIT** — parce que
CH70 est le lot où une constante de goût était devenue en silence un
plancher sur lequel un autre s'appuyait. Rien n'en dérive un contrat
aujourd'hui : 2,2 place la monture **au-dessus du char à voile (1,99) et
sous le kart de circuit (2,43)**, donc la chose la plus rapide du plateau
est une monture et la chose la plus rapide du jeu reste le kart sur sa
piste.

Ce qui n'est **pas** du goût : `ACCEL_LAMBDA`, qui décide si la monture
peut quitter l'arrêt face à une montée — la relation de `SledBody`,
republiée en CODE (`climb_authority()`) et gatée.

`SLOPE_GAIN = 0,55` contre les 2,6 de la luge, et c'est toute la
différence entre les deux : **une luge est une chose que la gravité
conduit, un animal est une chose qui monte à pied.**

## 7. QuadProbe — 71 assertions, 0 rouge

`xvfb-run --rendering-driver opengl3`, **jamais headless** : la sonde
envoie de vraies coordonnées d'écran dans `HubTapInput`, qui jette tout
point hors de son rect — et sous le driver dummy ce rect est dégénéré,
donc chaque tap serait silencieusement jeté et chaque assertion de la
forme « il n'a pas bougé » passerait en vert. PHASE I asserte le rect
avant quoi que ce soit.

### Les chiffres livrés

| | mesuré |
|---|---|
| croisière | **11,519 u/s** contre 11,786 authored, 95 % atteints à la frame 103 (1,72 s) |
| départ | rampe 2,759 → 3,672 → 6,490 u/s (ce n'est pas une vitesse allumée) |
| bout en bout | **20,57 u en 2,22 s = 9,281 u/s moyen**, contre une marche à 5,357 (× 1,73) |
| arrêt doigt levé | 11,52 u/s → immobile en **363 frames (6,05 s)** |
| braquage | 2,477 rad en 2 s à 7,94 u/s ; pire lacet **74,4 °/s** |
| mur | **0 frame hors du set conduisible**, 10,84 u glissés en 6 s contre le bord |
| montée | autorité 18,857 u/s² contre une poussée de pente de 2,228 (**11,8 % utilisés**) ; pente la plus raide du sol **0,5280 = tan 27,834°** |
| placeholder garé, dans le cadre | **+132 primitives**, soit **exactement** son compte de triangles |
| conduit (poursuite) | **43 891** primitives contre **44 858** pour la LUGE, même station, même run |

⚠️ **LE KART N'EST PAS DANS CETTE TABLE, ET C'EN EST UN RÉSULTAT.** Le
brief demande une comparaison avec le karting « dans une zone
équivalente » ; le kart est confiné à son circuit (zone 3), dont le cadre
contient une piste, une grille, quatre karts et un décor de circuit que le
plateau n'a pas. Une lecture prise là et une prise ici diffèreraient par la
**SCÈNE** et non par le véhicule — le défaut de métrique que `CLAUDE.md`
documente. **La luge est le véhicule conduit de zone équivalente**, et
c'est elle le comparateur.

⚠️ **Les millisecondes sont un chiffre de SANDBOX** (llvmpipe, rasteriseur
logiciel) et la sonde l'imprime elle-même : 63,2 ms pour le quad, 65,5 pour
la luge. Seules les primitives transfèrent.

### Le geste — la question posée par le brief, tranchée dans les deux sens

```
  [OK ] POSITIVE: on foot, a held drag turns the camera        -- 0.80000 rad
  [OK ] NEGATIVE: the SAME drag, while driving, moves the orbit
        by nothing at all                                      -- 0.000000000 rad
  [OK ] and it reached the vehicle's writer instead            -- steer 0.659
```

Le POSITIF tourne **en premier** : une assertion d'absence passe
gratuitement contre un mécanisme jamais câblé.

## 8. Défauts d'INSTRUMENT trouvés, chacun avec l'allure d'un résultat

Le premier run a rendu **7 rouges**. Aucun n'était dans le véhicule.

1. ⚠️ **Le banc conduisait la monture DANS LE MUR puis mesurait sa
   croisière dessus.** Départ à (−18 ; 18), 300 frames plein gaz, 47 u
   parcourus — et le bord du lobe skate est à 47 u. Lectures obtenues :
   « croisière **0,906 u/s** », « il s'arrête en 101 frames », « les pattes
   pédalent à l'arrêt », « un braquage tenu tourne de 0,066 rad » et un
   **lacet à 3,8 °/s**. Les six sont vraies et répondent à une autre
   question : `VehicleDrive` met le gain de braquage proportionnel à
   `v_fwd`, et un mur est précisément ce qui mange `v_fwd`
   (`CLAUDE.md` : *un mur supprime la direction*). **Parade** : la fenêtre
   de mesure est désormais **dimensionnée sur le sol** (`_room_ahead()`
   ray-marche `drivable()` et cape la course à 55 % de la place
   disponible), et la phase **gate qu'elle est restée sur du sol libre** —
   0 frame hors surface, 27,0 u de reste à la fin.
2. ⚠️ **Une assertion prise avant la fin d'une convergence mesure la
   convergence.** `exit_drive()` **tween** le fondu et ne lâche
   `_drive_target` qu'à la fin, donc pendant `DRIVE_BLEND_S` après le
   bouton `is_driving()` est encore vrai et `_orbit_licensed` répond encore
   faux. Deux assertions de PHASE G rouges sur du code parfaitement sain.
   La sortie **attend la caméra**, pas un compte de frames (CH73).
3. ⚠️ **Une affirmation fausse écrite dans une sonde.** Le premier jet de
   PHASE H notait « le hub est plat, ce gate est gratuit » — il ne l'est
   pas : la crête ouest enregistre un domaine `HubSurface` et le balayage y
   lit **0,5280**, c'est-à-dire `tan(27,834°)`, le nombre même que cite le
   docblock de `SledBody.GRADE_FOR_FULL_CAP`. La phase **asserte
   désormais que le relief existe**, sinon le gate serait gratuit sans le
   dire.

## 9. Passes rouges — quatre, et l'une d'elles est la trouvaille

| # | neutralisation | prédit | obtenu |
|---|---|---|---|
| 1 | `GAIT_RADS_PER_U = 0` | **2** | **2** — « and moving, it advances » (0,000 rad) et la lecture du NŒUD (0,0000 rad) |
| 2 | `_wall()` rend `wanted` sans condition | **1** | **1** — « it never leaves the drivable set », **292 frames dehors** |
| 3a | le shunt `HubTapInput` SEUL | **0** | **0** |
| 3b | le shunt **+** `is_driving()` **+** `is_afoot()` | **1** | **1** — l'orbite bouge de **0,800000000 rad**, le chiffre exact que le POSITIF lit à pied |

Fichiers restaurés **byte-identiques** (`cmp`) après chacune.

⚠️ **LA PASSE 3a EST LA TROUVAILLE, ET ELLE EST DU TYPE « LE MÉCANISME
CRÉDITÉ N'EST PAS CELUI QUI TRAVAILLE ».** La séparation des deux gestes
continus est défendue **TROIS fois**, et **chaque défense suffit à elle
seule** :

* le shunt de `HubTapInput` (retour anticipé pendant la conduite) ;
* `_orbit_licensed` → `hub_camera.is_driving()` ;
* `_orbit_licensed` → `hopper.is_afoot()`, faux sous `ON_CARRIER`.

Aucune neutralisation **individuelle** ne peut donc faire rougir le banc —
ce qui, pris seul, aurait pu se lire comme « le shunt n'est pas gaté »
(CH73). La lecture juste est publiée à la place : **le banc prouve que
l'assertion PEUT échouer (3b) et qu'AUCUN des trois n'est
individuellement nécessaire (3a)**. Un lot qui en retirerait un ne casserait
rien ; un lot qui en retirerait trois casserait tout, et la sonde le dirait.

## 10. Budget

* placeholder : **132 triangles**, **+132 primitives** garé dans le cadre —
  le compteur a soumis exactement le maillage, ce qui est ce qui **prouve
  le câblage** (un écart nul entre deux lectures ne le prouve pas, CH62 : une
  valeur périmée se répète parfaitement) ;
* **+0 au tapis** : le recensement `CozyScatter` est **identique au chiffre
  CH78** — le disque du quad n'a rejeté aucun candidat que la place ne
  rejetait déjà. ⚠️ **Blind check obligatoire avant de publier ce zéro** :
  à `QUAD_FOOTPRINT = 6.0` le recensement **BOUGE** (grass 1005 → 1000,
  bush 17 → 16, flower 109 → 108, instances 2689 → 2683), donc le fil est
  vivant et le zéro est une mesure ;
* conduit, il coûte **moins** que la luge au même poste (43 891 contre
  44 858) ; le plafond de 50 k est dépassé depuis CH29 et ce lot ne le
  déplace pas.

## 11. Ce qu'un banc n'a PAS signé (CH62)

* **la sensation de conduite** — 11,79 u/s, une rampe de 1,7 s et un
  roulement libre de 6 s à doigt levé sont des chiffres, pas un plaisir.
  ⚠️ Les 6 s d'arrêt sont le nombre le plus susceptible d'être faux au
  toucher : `COAST_LAMBDA = 0,90` est déjà le roulement le plus court de la
  carte (kart 0,30, luge 0,18), mais une bête à pattes s'arrête peut-être
  plus sec. **Un knob, et un appel device.**
* **la lisibilité du placeholder** — qu'un assemblage de boîtes turquoise
  se lise comme un raptor et pas comme une caisse.
* **l'interprétation du nom** : « quad raptor » est construit ici comme une
  **monture à quatre pattes**, sur la phrase du brief « pas de tentative de
  modéliser un vrai raptor ». Si l'intention était un **quad (ATV) nommé
  Raptor**, le correctif est `build_mesh()` + les quatre boîtes de patte et
  **rien d'autre** : aucune mécanique ne lit le maillage.
