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

---

# CH80 — Le quad raptor est un ATV, pas un dinosaure

| | |
|---|---|
| **date** | 12 septembre 2026 |
| **branche** | `claude/quad-raptor-mesh-rebuild-2t60hy` |
| **base** | `origin/staging` (= `0bd0dc0`), après CH78 + CH79 — arbre `94903d7` vérifié des deux côtés |
| **fichiers touchés** | `scripts/hub/QuadRaptorBody.gd` (maillage, teintes, `SEAT_Y`, l'odomètre), `scripts/hub/HubTransport.gd` (**un commentaire**) |
| **fichiers neufs** | aucun |
| **palier** | 1 — `staging` |

## 12. La prémisse de CH79 était fausse, et CH79 l'avait écrit lui-même

Le § 11 ci-dessus se termine sur l'ambiguïté : « quad raptor » avait été
lu comme une **monture à quatre pattes**, et CH79 signale que si
l'intention était un **quad (ATV) nommé Raptor**, le correctif est
`build_mesh()` + les quatre boîtes de patte **et rien d'autre**.

C'était la bonne lecture et c'est le bon périmètre. CH80 l'applique.

**Ce que ce lot a mesuré avant d'écrire une ligne**, parce qu'une
affirmation de périmètre recopiée d'un lot précédent est un chiffre
recopié (CH70) : la surface publique de `QuadRaptorBody` lue par le reste
du dépôt est **exactement** `HULL_PIECES`, `LEG_PIECES`, `PIECE_TRIS`,
`MAX_SPEED_FLAT`, `SEAT`, `SEAT_Y`, `STEER_RATIO`, `WALK_PACE`,
`build_mesh`, `leg_mesh`, `climb_authority`, `drivable`, `place`,
`reverse_authority`, `slope_force`, plus dix méthodes d'instance. Aucun
collider n'est dérivé du maillage (il n'y a pas de collider : `_wall()`
est un prédicat), aucune hauteur d'assise n'est lue sur une patte
(`SEAT_Y` est authored), la caméra vise le **nœud** et pas une pièce.
**La revendication de CH79 tient.**

La preuve par la mesure, et non par la relecture : `QuadProbe` PHASE D
rend **les mêmes chiffres au dix-millième sur les deux arbres** — croisière
11,5185 contre 11,7857 authored, 20,57 u en 2,22 s, 95 % de la croisière
à la frame 103, arrêt en 363 frames, 2,477 rad de cap en 2 s, pire lacet
74,4 °/s. Un maillage reconstruit de 132 à 1 104 triangles n'a **pas
déplacé un seul chiffre de conduite**.

## 13. Ce qui a été construit, et pourquoi chaque trait est là

Référence : Yamaha Raptor 700, lue à **1 u = 1 m** (Keepy fait
`KeepyHopper.CROWN_HEIGHT` = 1,7 u).

| trait du brief | ce qui le porte | mesuré |
|---|---|---|
| **1. voie large / trapu** | essieux à \|x\| 0,62 (avant) et 0,68 (arrière) | **1,820 large × 2,065 long = 0,881**, contre le kart à 1,480 / 2,150 = **0,688** |
| **2. guidon moto** | colonne inclinée à 10°, tube transversal 6 pans, deux poignées caoutchouc | barre à **y 1,21**, soit **+0,39 u au-dessus de `SEAT_Y`** — la même élévation au-dessus du pilote que le volant de `KartBody` (0,79 − 0,42 = 0,37) |
| **3. roues, arrière plus grosses** | 12 côtés chacune, comme les pneus de `KartBody` à la même distance caméra | avant r 0,33 / l 0,26, arrière r 0,40 / l 0,38 ; **les deux tailles sont visibles EN MOUVEMENT** (angles lus sur les nœuds après 18,277 u : −1,163 avant, **+1,711** arrière) |
| **4. garde au sol** | plaque de protection à y 0,26 | **0,260 = 65 % du rayon de la roue arrière** (un quad sport réel : ~37 %) |
| **5. châssis qui rétrécit** | réservoir tronconique + museau tronconique + plaque avant inclinée à 58° | **0,50 u de large au pilote → 0,22 u au bout du museau** |
| **6. selle haute et étroite** | deux pièces, plate à `SEAT_Y` là où il se tient, qui plonge vers le réservoir | \|x\| ≤ 0,17, de z −0,54 à z 0,44, sommet **0,82** |
| **7. garde-boue** | trois plaques par roue, posées sur un arc autour de l'essieu | s'arrêtent **0,01 u en deçà** de la face externe du pneu : la roue n'est jamais carénée |
| **8. détails** | repose-pieds + nerf bars, bloc moteur, échappement + silencieux cylindrique, pare-chocs tubulaire avant, barre de maintien arrière, deux phares, quatre enjoliveurs | 68 pièces de hull en tout |

**Coût** : **1 104 triangles** (816 de hull + 288 de roues) contre **132**
pour le placeholder, soit **+972**. Le kart, l'autre véhicule détaillé de
ce dépôt, en dépense ~700 pour une pièce également unique. Mesuré aux deux
endroits que le brief demande :

| station | sans le quad | avec | delta |
|---|---|---|---|
| **frame de SPAWN** (le quad est garé dans le cône) | 71 380 | 72 484 | **+1 104** |
| poste ouvert de `QuadProbe` PHASE B | 64 951 | 66 055 | **+1 104** |
| **en conduite**, caméra de poursuite | — | **44 863** | contre **45 830** pour la LUGE au même poste, même run |

Les deux deltas sont **EXACTEMENT** le compte publié, ce qui est
l'assertion de câblage de PHASE B (CH62 : une valeur périmée se répète
parfaitement, un delta qui vaut le maillage au triangle près ne le peut
pas). Nœuds de dessin : **1 hull + 24 secteurs de roue**, du même ordre
que les ~24 `MeshInstance3D` du kart.

## 14. La discipline de construction — et pourquoi elle n'a coûté aucune assertion

`QuadProbe` PHASE X découpe le maillage livré en séries de `PIECE_TRIS`
triangles et score chacune contre **son propre centre** : un test qui
n'est valide que sur une pièce **CONVEXE**, et le fichier de la sonde le
dit (`SledProbe` a déjà rendu « 46 triangles sur 60 mal enroulés » sur un
maillage correct pour avoir oublié cette condition).

Un quad veut des **cylindres**. La tentation était d'affaiblir le test.
Ce n'était pas nécessaire : **`SledBody._hexa` est huit coins et six
quads**, donc aussi, coins cisaillés, un tronc, une plaque inclinée —
et un **COIN DE CYLINDRE** (centre, trois points de jante, extrudé :
huit sommets, six faces, **douze triangles**, convexe sous 180°). Deux
segments de jante par coin, donc *n* coins font un cylindre à *2n* côtés.

Résultat : **68 pièces de hull + 24 coins de roue, toutes convexes,
toutes à 12 triangles**, roues à 12 côtés comprises. Les six assertions
de maillage sont restées vertes **sans qu'une ligne de sonde bouge**, et
le blind check interne (le même test appliqué au maillage retourné) rend
**816/816** sur la géométrie neuve.

⚠️ **Et les indices d'enroulement ne sont PAS pris sur le centroïde.**
`_solid()` passe à `SledBody._quad` les **axes propres authored** de la
pièce portés par sa transformation de placement. Si le bâtisseur dérivait
sa direction sortante du centroïde, il utiliserait exactement le critère
du test, et PHASE X resterait verte sur n'importe quoi — la tautologie
CH62. Les hints sont vérifiés positifs pour tout secteur de moins de 90°
de demi-span ; le test garde un témoin indépendant.

## 15. Les teintes — la réponse évidente a été MESURÉE et refusée

CH79 avait choisi le turquoise « pour qu'une monture verte ne soit pas une
silhouette sans arête sur la seule surface où elle se tient ». Scoré en
luminance relative WCAG contre les **neuf bandes de sol** que ce véhicule
peut fouler :

| ton | pire ratio | contre |
|---|---|---|
| **turquoise CH79** `(0,24 ; 0,58 ; 0,62)` | **1,23:1** | `AUTUMN_A` |
| corail du kart | 1,10:1 | `AUTUMN_A` |
| rouge de la luge | 1,46:1 | `AUTUMN_A` |

Il ne perd pas du contraste : il **DISPARAÎT**. Et ce n'est pas un
problème de turquoise — la pire bande est à **L 0,313**, donc franchir
3,0:1 quelque part sur cette carte exige **L ≤ 0,071**, et aucun ton de
carrosserie n'est aussi sombre. C'est « la palette est coupée en deux
bandes par le sol » de `CLAUDE.md`, rencontrée sur les verts du hub.

**Le plancher est donc porté comme CH48 le porte pour un marqueur de
minimap qui contient une PHOTOGRAPHIE : par une pièce d'UN SEUL TON qui,
elle, le franchit.** Les pneus (**5,87:1** contre la pire bande) et le
cadre (**3,91:1**) ceinturent toute la moitié basse de la machine — roues,
plaque de protection, bras oscillants, guidon, pare-chocs. L'arête de la
silhouette est la leur, à toutes les stations.

La carrosserie est alors libre, et choisie pour trois choses qu'elle peut
réellement tenir : **distinctivité de flotte** (le kart est corail, la
luge crème et rouge ; le bleu n'est possédé par aucun véhicule),
**distance de teinte** (218° contre l'herbe à 90-120°, et bleu-contre-vert
est exactement la séparation que le WCAG ne score pas), et c'est la
couleur de la machine de référence.

| rôle | ton | pire contre le sol | séparation interne |
|---|---|---|---|
| carrosserie | `(0,16 ; 0,36 ; 0,72)` | 2,20:1 | — |
| garde-boue | `(0,28 ; 0,54 ; 0,86)` | 1,72:1 | 1,90:1 / carrosserie |
| selle | `(0,46 ; 0,39 ; 0,35)` | 3,75:1 | 2,31:1 / carrosserie |
| cadre, guidon | `(0,22 ; 0,23 ; 0,25)` | **3,91:1** | — |
| pneus, poignées | `(0,12 ; 0,11 ; 0,11)` | **5,87:1** | 2,67:1 / carrosserie |
| enjoliveurs, phares | `(0,80 ; 0,82 ; 0,84)` | 1,31:1 | 7,93:1 / pneus |

⚠️ **Aucun de ces chiffres ne dit que ça se lit.** Ce sont des
arithmétiques sur des albédos authored ; le shader décor est unlit, donc
ces albédos SONT ce qui s'affiche, mais « est-ce que ça se lit comme un
quad sur l'herbe » est un appel device et le rapport le nomme comme tel.

## 16. La pose du rider est HORS PÉRIMÈTRE, et le brief demandait qu'on le dise

Le brief demande Keepy **assis à califourchon**, mains vers le guidon.
**Il n'existe aucune pose assise dans ce dépôt.**
`KeepyHopper.mount_carrier()` écrit le rider **DEBOUT** au point d'assise
(`_body.scale = _base_scale`, `_body.rotation_degrees.x = _base_pitch`),
et le kart, la luge, le char à voile et le voilier montent tous ainsi. La
poser autrement est un changement de `KeepyHopper` partagé par **six**
véhicules — une mécanique, donc hors de ce lot.

Ce qui EST dans ce lot, c'est la géométrie autour de l'endroit où il se
tient : la selle est étroite et longue, le réservoir s'évase de part et
d'autre de ses pieds, les repose-pieds sont là où ses pieds pendraient, et
la barre est à +0,39 u au-dessus de la selle — la relation exacte que
`KartBody` donne à son volant au-dessus de son siège. **Il se lit comme
étant dessus parce que la machine est construite autour de là où il se
tient.**

## 17. Ce que la passe rouge a signé

Aucune assertion neuve n'a été écrite (le brief interdit de toucher la
sonde), donc la passe rouge porte sur la capacité du **contrat de
maillage existant** à rougir sur la géométrie neuve. **Une pièce de hull
retirée**, trois rouges prédits, **trois obtenus et pas d'autres** :

| assertion | lu |
|---|---|
| `the hull is HULL_PIECES boxes of PIECE_TRIS` | 804 contre 816 |
| `triangle_count() publishes what the meshes actually carry` | 816 + 288 publiés contre 804 réels |
| PHASE B `the delta is EXACTLY the triangle count` | **+1 092 contre 1 104 publiés** |

La troisième est la plus utile : elle prouve que le compteur de la frame
est câblé à ce que la scène dessine réellement, et donc que les 24 nœuds
de roue sont tous soumis. Fichier restauré et vérifié **byte-identique**
(`cmp`, md5 `b0927e29730b9b4f12cd78605208a397`).

## 18. Deux défauts d'INSTRUMENT, chacun avec l'allure d'un résultat

**(a) La station de rendu était DANS un arbre.** La sonde de rendu
jetable a d'abord utilisé le poste « plateau ouvert » de `QuadProbe`
(−18 ; 18) — parfait pour CONDUIRE, inutilisable pour REGARDER :
`HubCamera.OFFSET` met l'objectif 8,9 u au nord et 7,6 u au-dessus du
point suivi, et ce point-là tombe dans une couronne de pommier. Huit
azimuts de feuilles, nœud visible, sujet au centre du cadre,
`unproject_position` juste, **et pas un pixel du sujet**. Re-rendu depuis
le park du quad — dégagé par construction, et l'endroit où un joueur le
rencontre — les huit azimuts sont propres. ⚠️ **Et la sonde n'assertait
pas qu'elle avait vu son sujet** : c'est ce qui aurait transformé six
minutes de diagnostic en une ligne rouge.

**(b) Un seuil de sonde écrit dans les unités de la variable publiée.**
`_gait` devait devenir l'angle de la roue avant
(`1 / FRONT_WHEEL_RADIUS` = 3,03 rad/u, la dérivation évidente et celle
que `KartBody` écrit). PHASE D asserte « à l'arrêt, ça ne pédale pas »
avec un seuil de **0,05** sur `gait_phase()`, et le fluage résiduel
mesuré vaut **0,0199 u** en 30 frames : à 3,03 rad/u cela fait **0,060** —
**rouge sur un mécanisme parfaitement correct**, uniquement parce que le
seuil avait été écrit pour le 1,25 rad/u du placeholder. `_gait` est donc
resté un **ODOMÈTRE en unités**, ce qui est de toute façon la meilleure
décomposition : c'est la primitive dont les DEUX tailles de roue dérivent
(`ROLL_PER_U`), au lieu d'en privilégier une. Mesuré après changement :
**0,0199 contre 0,05**, et 18,277 u contre le seuil de 1,0. C'est la règle
CH47 (« un seuil écrit en cellules cesse de séparer le jour où la cellule
grandit ») rencontrée côté **publieur** et non côté conteneur.

## 19. La dette de nommage, dite et non payée

`leg_mesh()`, `LEG_PIECES` et `leg_pitch()` sont les noms que CH79 a
donnés aux quatre pièces mobiles. **Ce sont maintenant des roues.**
Les renommer casserait la compilation de `QuadProbe`, et le brief de CH80
interdit de toucher la sonde — pour une bonne raison : un rouge là-bas
était la preuve que le lot cherchait (une mécanique qui lirait le
maillage), et la sonde doit rester celle de CH79 pour que la comparaison
veuille dire quelque chose. Le renommage des trois **avec** la sonde est
un commit d'un lot qui a le droit de l'éditer. Idem pour le libellé
`%.3f rad` que PHASE D imprime à côté d'une distance.

## 20. Ce que ce lot n'a PAS touché

Ni la conduite (`PACE_RATIO`, `ACCEL_LAMBDA`, `COAST_LAMBDA`,
`BRAKE_DECEL`, `SLOPE_GAIN`, `GRIP_ON`, `STEER_*`), ni `_wall()`, ni
`drivable()`, ni la porte (`mount_quad` / `exit_quad` / `HubTransport`
au-delà d'un commentaire), ni la caméra, ni le HUD, ni la minimap, ni
`HubTapInput`, ni `KeepyHopper`, ni `SledBody` (dont `_quad` est
**appelé**, jamais copié), ni `QuadProbe`.

⚠️ **Les constantes de tenue de route ont été laissées telles quelles
DÉLIBÉRÉMENT.** `SLOPE_GAIN` 0,55 et `GRIP_ON` 6,5 sont argumentées dans
leurs propres commentaires par « des pattes, donc ça tient » ; sur un quad
les mêmes nombres se lisent comme de la suspension à grand débattement et
des pneus crantés, et la conduite CH79 a été validée sur device. Les
rouvrir est un lot de FEEL avec une passe device, pas un lot de maillage —
CH70 est le précédent de ce qui arrive quand on rouvre une constante de
goût sans mesurer qui s'est appuyé dessus depuis.
