# CH71 — Le parc d'attractions : montagnes russes et tour de chute

> Chantier ouvert le 11 septembre 2026. Objectif large confié à Fable 5.1
> avec garde-fous, sur le modèle CH66. Emplacement fourni par Mathieu :
> **ancré autour de x ≈ 35,2, z ≈ 27,7** (zone 0), coordonnées lues sur
> l'overlay debug en jeu. Deux attractions jouables de bout en bout :
> une **montagne russe** (chariot sur rail, boucle fermée, embarquement
> et débarquement, frein au doigt tenu) et une **tour de chute** (montée
> lente, arrêt en haut, chute libre, freinage magnétique, débarquement).
> Base : `origin/staging` = `origin/main` = `60d7cb3` (même arbre
> `d50f189a…`, vérifié au `fetch` du début, les deux paliers alignés
> après CH70).

## Section 1 — RECON (bloquante, tout mesuré, rien estimé)

### 1.1 — Les branches

`git fetch --all --prune` au début : `origin/main` et `origin/staging`
portent le **même commit** (`60d7cb3`, merge CH70) et donc le même arbre.
Aucune branche distante dont le nom évoque CH71, parc, coaster ou tour ;
la seule voisine par le nom (`hubregion-north-tower-lobe-voom9v`) est le
lobe de la tour P2 de CH21, mergé depuis longtemps.

### 1.2 — Le site, mesuré en jeu (`Ch71SiteRecon`, xvfb + opengl3, jetable, supprimé avant le commit)

Instrument d'abord : 296 couleurs sur la frame, **2 626 / 2 626**
transforms de `MultiMesh` relues non-identité (le faux-vert CH50 nommé et
écarté).

| fait | mesure |
|---|---|
| `HubRegion.contains(35.2, 27.7)` | **vrai**, `zone_of` = **0** |
| par rapport au carré (`PLATEAU_HALF_EXTENT` 35) | **0,20 u HORS** du carré en x |
| ce qui l'admet | le **lobe skate** (r 36 depuis (0, 35)) : distance 35,949, à **0,051 u** du rebord |
| bord est de la région sur z = 27,7 | x = **35,26** |
| bord est aux autres z | 35,01 (z 15-25), 35,66 (z 30), 36,01 (z 35), 34,59 (z 45) |
| lobe de structure le plus proche | P2 tyrolienne (25,2 ; 35) r 3, à 12,38 u |
| liseré peint du lobe (`kerb`) | peint pour z ≥ 35 seulement — **absent** au site |
| `CozyScatter.COVER_MAX` / `WALL_NEAR_Z` / `WALL_CLEARANCE` | (37, 71) / 76 / 2 |

Le point de Mathieu est donc **le rebord est du plateau**, admis par le
lobe skate à cinq centimètres près.

### 1.3 — Recensement dans un rayon de 16 u (bornes exactes)

**Layout (`hub_layout.tres`) — aucune entrée à moins de 12 u du site :**

| type | position | scale | distance |
|---|---|---|---|
| tree | (23,750 ; 23,880) | 0,650 | 12,07 |
| stump | (22,810 ; 21,350) | 0,922 | 13,92 |
| landmark (spire, aabb y 0,03 → 8,32) | (30,491 ; 12,871) | 0,880 | 15,56 |
| rock | (24,691 ; 15,852) | 1,172 | 15,84 |
| zipline P1 → P2 | (27,7 ; 9,2) → (25,2 ; 35,0), câble à y 2 | câble à x 25,2-27,7 |

**Nœuds construits par `HubBuilder` dans le rayon** : les deux pièces du
landmark spire (30,49 ; 12,87), la tour P2 (deck à (25,2 ; 0,85 ; 35),
head beam à y 2), le `Cable` (aabb x [25,22 ; 27,68], z [9,74 ; 34,46],
y ≈ 2), le feu de camp (anneau de pierres à (19,9 ; 25,4), 15,47 u).

**Scatter (instances `MultiMesh`, origines dans le rayon)** :

| batch | n | aabb x | aabb z | plus proche |
|---|---|---|---|---|
| grass (4 cellules) | 112 | [19,45 ; 35,98] | [14,65 ; 43,37] | 0,49 u |
| flower (4) | 18 | [20,88 ; 34,33] | [16,65 ; 40,35] | 4,54 u |
| leaf / pebble / mushroom | 15 / 5 / 3 | — | — | 2,49 u |
| bush | 3 | [19,22 ; 35,07] | [26,06 ; 41,83] | 8,45 u |
| rock | 1 | (29,95 ; 35,40) s 0,61 | — | 9,32 u |
| **wall_near tree_1_round** | 9 | **[36,60 ; 44,70]** | [11,52 ; 41,57] | **4,00 u** à (38,33 ; 30,19) |
| **wall_near tree_3_tall** | 4 | **[35,68 ; 44,40]** | [17,57 ; 35,24] | 5,01 u à (37,31 ; 23,16) |
| wall_far tree_6_far | 7 | [41,51 ; 51,76] | [20,12 ; 35,38] | 9,11 u |

Bornes de tout ce qui est HAUT (mur d'arbres inclus) : x [19,22 ; 51,76],
z [11,41 ; 41,83]. **Le mur d'arbres commence à x = 36,6** : le site est
littéralement la lisière.

⚠️ **Deux écarts de nomenclature dans le brief, signalés sans être
tranchés.** (a) Le brief parle d'un secteur « au sud-ouest du spawn » :
en convention du dépôt (+z = nord, +x = est, caméra 8,9 u au nord),
(35,2 ; 27,7) est au **nord-est**. (b) « La structure en bois visible sur
site » : la seule structure en bois à moins de 15 u est la **tour P2 de
la tyrolienne** (25,2 ; 35), à 12,4 u ; la **cabane** (échelle 7) est à
(−17,43 ; 28,18) — même z, x opposé. L'overlay imprime `POS x %.1f z %.1f`
signé ; le lot a pris les coordonnées telles quelles, comme demandé, et
tout est mesuré autour de (35,2 ; 27,7). Si Mathieu voulait le côté
cabane, c'est un déplacement de constantes (`HubFunfair.TRACK_POINTS`,
`TOWER_AT`, les deux `*_STAND`) et un rejeu de `FunfairProbe`.

### 1.4 — Budget triangles AVANT (référence, même sonde)

`gpu` = primitives opaques du viewport 3D ; `TOTAL` = tous viewports
(la ligne « TOTAL tri » de l'overlay) ; `lod0 / scene` = rejeu de
l'overlay.

| station | gpu | calls | lod0 cadre | scene | TOTAL |
|---|---|---|---|---|---|
| spawn (0, 0) | 70 634 | 302 | 265 257 | 360 849 | 71 572 |
| CH22 pire (−5, 35) | 84 886 | 362 | 298 403 | 360 849 | 85 824 |
| approche (30 ; 27,7) | 66 098 | 290 | 270 714 | 360 849 | 67 036 |
| **SITE (35,2 ; 27,7)** | **61 383** | 271 | 261 683 | **360 849** | **62 321** |
| site sud (35,2 ; 20) | 57 556 | 264 | 256 022 | 360 849 | 58 494 |

Les « ~64 k TOTAL / ~360 k scene » lus par Mathieu sur device sont
reproduits (62 321 / 360 849 au site ; l'écart de 2 k sur TOTAL est la
météo et le HUD du moment). **Le plafond de 50 k est dépassé depuis CH29
et il l'est ici de 23 % avant que ce lot pose un triangle** — dit en tête
de rapport, pas enterré.

### 1.5 — Les patrons lus avant de concevoir

`HubSkatepark.gd` (coordinateur sous `World`, `footprints()` statiques
lus par `CozyScatter`, hook d'atterrissage, `cancel_intent()`),
`HubKarting.gd` (`accepts_tap` / `arm` / `on_landing` / `cancel_intent`,
le patron d'intention), `HubTransport.gd` (la montgolfière : trajet
BORNÉ, retrait des docks pendant le vol, `mount_carrier` /
`follow_carrier` / `leave_carrier`), `BoatMooring.is_available()` (le
patron bateau), `HubTapInput._handle_point` (tout prop interrogé sur
`aim`, jamais sur la destination clampée).

## Section 2 — LA DÉCISION D'EMPLACEMENT : TOUT À L'INTÉRIEUR, AUCUN LOBE

Deux dessins ont été chiffrés avant la première ligne de géométrie.

**(A) Un lobe à cheval sur le bord est**, centré sur l'ancre. Le coût se
lit en une colonne : la pire paire du hub devient le coin de montagne
(−63, −12) contre le point du lobe le plus loin de lui, soit
`|C − M| + r`. Pour C = (35,2 ; 27,7), |C − M| = 105,7 u, et au ratio
publié 0,1889 s/u : r = 5 → 20,91 s, r = 8 → 21,48 s, r = 9 → 21,67 s,
**r = 10,2 → 21,817 s (la pire paire CH67, donc le titre change)**,
r = 11,2 → 22,0 s (le budget). Un lobe utile (r ≥ 8) tenait, mais
**re-semait le mur d'arbres** — 13 troncs de `wall_near` dans
x [36,6 ; 44,7] disparaissent dès que la région avance de 2 u sur eux —
et la doctrine « une structure posée sur un bord déborde » aurait mis
la tour ou la gare sur la couture.

**(B) Tout à l'intérieur de la région existante**, dans la bande
x ∈ [28,5 ; 35] entre le câble de tyrolienne (x ≤ 27,7) et le bord du
carré. Une boucle de 5 u de large tient (rails à x 29,5 et 34,5, bord
extérieur du rail est à **34,966 < 35**), la tour tient au sud de la
boucle à l'intérieur du carré, et **rien ne bouge** : ni `HubRegion`, ni
la pire traversée (21,817 s, CH67), ni le mur, ni un seul asset. Le
brief interdisait de supprimer un arbre sans validation ; (B) n'en
touche aucun. **C'est (B) qui est livré**, ancré à 0,7 u de l'ancre (la
vallée de la descente passe à (34,5 ; 27,5)).

## Section 3 — LE DESSIN, ET C'EST LA CAMÉRA QUI L'A DESSINÉ

`HubCamera` ne monte jamais et ne tourne jamais (`OFFSET (0 ; 7,6 ; 8,9)`,
tangage fixe) : elle montre les z **inférieurs** au sien, ±3,69 u de large
au z du joueur, et coupe la colonne au-dessus de lui à
`FRAME_TOP_AT_APLOMB` = 7,968 u. Trois conséquences, toutes gatées :

1. **Les hauteurs.** La couronne de Keepy est ~1,7 u au-dessus de son
   siège ; avec la marge de 0,4 u des sièges d'arbre (`SEAT_MAX_Y`), un
   siège ne dépasse pas **5,868 u**. Rail de crête à 5,0 (siège 5,367),
   nacelle au sommet à 5,1 (siège 5,22), casquette de tour à 6,85 <
   7,968 (un passager voit la tour entière). `FunfairProbe` A6-A8, et
   E4/F10 déprojettent la couronne **à chaque frame** des deux trajets.
2. **Le sens de la boucle.** La gare est sur la jambe OUEST et le chariot
   part vers le **NORD** : la montée au treuil se fait à l'aveugle
   (l'anticipation n'a pas besoin de voir), puis le virage nord au
   sommet **révèle toute la jambe est qui descend vers le sud** — la
   grande descente, la bosse, le virage sud, et la tour au-delà — dans
   le cadre pendant toute la descente. Le miroir exact du skatepark
   « ridé vers le sud ».
3. **La tour au sud.** Visible depuis la gare (9,5 u devant, 4,5 u de
   côté : dans le cône de 22,5°) et depuis toute la descente. Une tour au
   nord de la boucle aurait été derrière l'objectif depuis chaque point
   du parc.

### 3.1 — La boucle (`HubFunfair.TRACK_POINTS`, hauteur = dessus de rail)

```
 0  (29.5, 0.55, 20.0)  gare -- le chariot y repose, s = 0
 1  (29.5, 0.55, 23.0)  pied du treuil
 2  (29.5, 1.60, 26.0)
 3  (29.5, 3.20, 29.5)
 4  (29.5, 4.60, 33.0)
 5  (30.0, 5.00, 35.6)  crete, debut du virage nord
 6  (32.0, 4.90, 37.0)  pointe nord
 7  (34.0, 4.70, 35.6)
 8  (34.5, 4.30, 33.5)  debut de la descente
 9  (34.5, 1.60, 30.0)
10  (34.5, 0.55, 27.5)  vallee (0,7 u de l'ancre)
11  (34.5, 2.40, 23.5)  bosse
12  (34.5, 0.55, 19.5)
13  (34.0, 0.55, 16.9)  virage sud
14  (32.0, 0.55, 15.8)  pointe sud
15  (30.0, 0.55, 16.9)
16  (29.5, 0.55, 18.0)  zone de freinage -> retour au 0
```

Spline cardinale (tension 0,5, Catmull-Rom) fermée, `bake_interval` 0,1.
**Mesuré sur la courbe cuite** : longueur **51,165 u**, pied du treuil à
s = 3,012, **crête à s = 17,350 (y 5,027)**, rails dans x [29,034 ; 34,966]
et z [15,390 ; 37,409]. Rails : deux tubes hexagonaux r 0,06 à
l'écartement 0,70 ; traverses tous les 0,9 u ; poteaux tous les 1,8 u
partout où le rail dépasse 0,35 u (29 poteaux). Gare : deck de 1,4 × 3,2
à 3 mm au-dessus de la pelouse (sous l'ombre-blob à 0,014, la raison
de `SkateparkMesh.SLAB_LIFT`), deux poteaux et un toit plat.

### 3.2 — La tour (`TOWER_AT` (33,0 ; 8,5))

Socle 2,6 × 0,3 × 2,6, mât central 0,22, quatre jambes à ±1,0 sur 6,6 u,
trois niveaux de croisillons (2,2 / 4,2 / 6,2), casquette à 6,6-6,85.
Nacelle : plancher 1,5 × 0,15 × 1,5 à **0,45** au repos (son dessous à
0,375, au-dessus du socle à 0,30 — F9 gate qu'elle ne le traverse jamais),
quatre montants et une main courante à 0,9. Voisins mesurés : buisson du
layout (29,87 ; 7,14) r 0,63 à **0,89 u** d'écart, spire (30,49 ; 12,87)
r 1,461 à 1,68 u, P1 plus loin. ⚠️ Première pose à x = 33,3 : le socle
tenait (34,6 < 35) mais l'**empreinte publiée** (r 1,9) dépassait le bord
du carré de 0,2 u — `FunfairProbe` B7 est sorti ROUGE, la tour a reculé
de 0,3 u. Un débord de 20 cm sur une réserve, invisible à l'œil, est
exactement ce que la doctrine « une structure posée sur un bord déborde »
existe pour attraper.

## Section 4 — LES MÉCANIQUES

### 4.1 — Le chariot : une COURBE de vitesse, pas une vitesse

CH54 l'a écrit pour la planche et ça vaut pour un rail : « une vitesse
n'est pas une conduite, un profil l'est ». Le chariot est paramétré par
l'abscisse curviligne `s` sur la courbe cuite, et sa vitesse est écrite
par PHASE (`HubFunfair.CoasterPhase`) :

| phase | de s | à s | loi |
|---|---|---|---|
| DEPART | 0 | pied du treuil (3,012) | v monte à `LIFT_SPEED` 2,2 u/s à `LIFT_ACCEL` 1,5 |
| LIFT | 3,012 | crête (17,350) | v = 2,2 constant (le treuil) |
| COAST | crête | L − 3 | **énergie** : E += −g·Δh − 0,35·Δs − (3,0·Δs si le doigt est tenu) ; v = √(2E), plancher 1,2 u/s |
| BRAKE | L − 3 | L (51,165) | v = v_entrée · √(1 − u), arrêt exact à s = L, remise à s = 0 |

`GRAVITY` = **9,8**, la physique, et pas `SkateBoardBody.GRAVITY` (26,0) :
celle-là est un contrat de capsule sur quarterpipe. Ici la conservation
d'énergie est ce qui fait que la vitesse de la descente **LIT** la hauteur
de la colline : Δh = 4,45 u → v_vallée ≈ 9,2 u/s, la bosse de 1,85 u la
ramène à 7 et la rend. L'intégration prend Δh **sur la table** (h(s₁) −
h(s₀)), donc l'énergie est exacte quel que soit le pas de temps.

**Le frein au doigt tenu** (`brake_held()` : bouton souris gauche, que
le toucher émule — CLAUDE.md `emulate_mouse_from_touch`) retire
`BRAKE_DECEL` 3,0 d'énergie par unité parcourue pendant COAST. Le
plancher `SPEED_FLOOR` 1,2 u/s garantit qu'un frein tenu sur la bosse
n'y laisse jamais le chariot : **le trajet reste BORNÉ**, c'est la
licence (CLAUDE.md, patron bateau) qui autorise à jeter un tap pendant
le trajet. C'est « pilotable » sur UN axe — la vitesse — et pas la
direction, que le rail possède ; donc la caméra reste **FIGÉE**, au
critère CH30 (« le joueur choisit la direction frame par frame » — non).

Pose du chariot : `Transform3D(Basis.looking_at(tangente, UP), point)` ;
le tangage suit le rail, `follow_carrier` ne lit que le lacet du
porteur et le siège `CART_SEAT (0 ; 0,34 ; 0)` par `to_global`.

### 4.2 — La tour : cinq phases, un frein DÉRIVÉ

RISE (0,9 u/s, de 0,45 à 5,10) → HOLD (1,6 s d'attente au sommet) → FALL
(chute libre à g = 9,8 jusqu'à `GONDOLA_BRAKE_Y` 1,6) → BRAKE (décélération
constante calculée **sur la vitesse réellement atteinte** au passage de
la ligne de frein, pour s'arrêter exactement à 0,45) → SETTLE (0,6 s) →
IDLE. `tower_brake_decel()` publie la forme fermée : chute de 3,5 u,
freinage sur 1,15 u, **29,83 u/s² = 3,04 g** (A9 le gate entre 1 et 5 g).

### 4.3 — La porte de tap et l'intention

`HubTapInput` demande `HubFunfair.accepts_tap(aim)` sur `aim` (jamais sur
la destination clampée), après les châteaux et avant les arbres : 2,0 u
autour du point de repos du chariot, 2,2 u autour du centre de la tour.
**Une attraction en cours se RETIRE** (répond −1) : le tap retombe sur
`tapped_ground` et y est refusé par `ON_CARRIER` — jamais avalé par la
chose qu'on chevauche. Le signal `tapped_funfair(point, ride)` arrive à
`HubWorld._on_tapped_funfair` qui suit le kart : gardes d'état, remise à
zéro de toutes les intentions, `_hop_via_corridor(stand_point)`, **puis**
`arm(ride)` (l'ordre des châteaux : une marche de longueur nulle émet
`became_idle` synchroniquement dans `hop_to()` et efface tout), puis un
`on_landing` immédiat. `_on_hop_landed` appelle `_funfair.on_landing`
après le kart ; `_on_keepy_idle` et les deux autres sites de remise à
zéro appellent `_funfair.cancel_intent()`.

Fin de trajet : `ride_finished(ride, landing)` → `leave_carrier(landing)`
sur le point de stand que le parc possède (le deck, ou l'aire nord de la
tour) — pas de recherche d'anneau, il n'y a aucun prop à éviter là.

## Section 5 — CE QUI EST SOLIDE (D5)

Un seul `StaticBody3D` (`FunfairCollider`, couche `LAYER_PARK`, masque 0)
et **37 `BoxShape3D`** : 29 poteaux de rail, 2 poteaux de gare, socle,
mât et 4 jambes de tour. Convexe par construction, aucun trimesh. Les
rails ne sont PAS solides (la planche passe dessous), le deck non plus
(3 mm). D4 lance un rayon sur l'axe de la tour et touche le mât à
y 6,600 ; D5 (aveugle) en lance un sur le deck et ne touche rien.

## Section 6 — LE TAPIS : UN FOOTPRINT QUI NE REBAT PAS LE JEU

Première version : `HubFunfair.footprints()` ajouté dans
`CozyScatter._blocked()` comme les quatre familles avant lui. Mesuré au
`CozyScatter:` du boot (référence → branche) : grass **1 022 → 985**,
bush **22 → 7**, flower 114 → 112, instances 2 626 → 2 573. Quinze
buissons de moins **dans tout le hub** pour un parc qui n'en couvre
peut-être deux : ce n'est pas un amincissement, c'est le tapis REBATTU
(CH53 : un candidat rejeté AVANT ses tirages saute son échelle et son
lacet, et tout le flux d'après est déplacé).

Seconde version, livrée : le test du parc est fait dans `_sprinkle`
**APRÈS** les deux tirages (`s`, `yaw`) — un candidat rejeté a consommé
exactement ce qu'un candidat placé consomme, le flux est intact.
Mesuré : grass 1 022 → **990**, bush **22 → 22**, flower 114 → 110,
instances 2 626 → 2 584, 307 batches des deux côtés. Ce qui manque est ce
qui se tenait DANS les disques du parc, et rien d'autre. C'est le
raisonnement de `_keep_hash` (« une garde locale ne touche pas le
flux ») appliqué à une empreinte — et ça réfute le « irréductible » de
CH53 : il l'était pour un test fait dans `_blocked()`, pas pour un
test fait après les tirages. `FunfairProbe` B9/B10 gate l'absence sous
les disques avec son témoin (62 instances dans l'anneau juste dehors).

## Section 7 — `FunfairProbe` (xvfb + opengl3, permanent) : 78 assertions, 0 rouge

Huit phases, I → H, chacune avec ce qu'elle ne peut PAS signer dit en
tête de fichier (CH62 : un banc ne juge pas un game feel).

| phase | ce qu'elle gate | mesure |
|---|---|---|
| I | instrument : 296 couleurs, 2 584 / 2 584 transforms non-identité, rect du conteneur réel, `KEEPY_CLEARANCE` lu (0,660) | — |
| A | les deux orthographes de la courbe (nœud / statique) à 0,001 u ; crête après le pied ; pic 5,027 ; rails dans x [29,034 ; 34,966] < 35 ; sièges sous 5,868 ; casquette 6,85 < 7,968 ; frein tour 3,04 g | — |
| B | tour vs empreintes layout ≥ 0,66 (**0,885**, le buisson (29,87 ; 7,14)) ; rails bas vs layout (1,338) ; rail vs câble (**3,367 u**) ; 17/17 points sur sol marchable, les deux stands aussi, zone 0 ; rien ne déborde du carré ; aucun stand dans un solide ; **blind** : 62 instances dans l'anneau hors disques, **0 dedans** | — |
| C | juge CH39 : `cull_back` vs `cull_disabled`, même compte de pixels magenta, sur les QUATRE maillages | rail 20 857 / 20 860 · chariot 1 244 / 1 244 · tour 13 690 / 13 690 · nacelle 1 481 / 1 481 |
| D | un corps, couche park, masque 0 ; 37 `BoxShape3D`, 0 autre ; rayon sur l'axe de la tour → le mât à y 6,600 ; **blind** : rayon sur le deck → rien | — |
| E | le chariot PAR LE CANAL DU DOIGT (`_handle_point` sur le point écran du repos), deux fois | ci-dessous |
| F | la tour par le même canal | ci-dessous |
| G | budget : delta scène = `triangle_total()` exact ; le parc coûte quelque chose depuis ses stations | ci-dessous |
| H | pixels : cacher / relire contre le plancher (deux lectures, arbre gelé) | drop view 24 899 px (plancher 347) · tour 46 681 (182) · gare 40 440 (470) |

### 7.1 — Le chariot, deux courses

| course | frames à bord | v max | v crête | v vallée | y max Keepy | couronne hors cadre | portage (écart siège) |
|---|---|---|---|---|---|---|---|
| libre (frein forcé OFF) | **899** (15,0 s) | **9,189** | 2,195 | **8,920** | 5,367 | 0 | 0,00000 |
| freinée (frein forcé ON) | **1 870** (31,2 s) | 5,910 | 2,144 | **5,792** | 5,367 | 0 | 0,00000 |

Gates : le trajet finit UNE fois et il est debout sur le deck (0,000 u
du point de stand) ; la crête est franchie à la vitesse du treuil ; les
quatre phases DEPART → LIFT → COAST → BRAKE dans l'ordre ; **la gare
s'est retirée pendant le trajet** et répond de nouveau après ; **un tap
sur le sol nu en pleine descente a été jeté par l'état** (toujours à
bord, pas en saut, toujours en COAST) ; la course freinée finit quand
même (BORNÉE), sa vallée est 3,1 u/s plus lente, elle dure deux fois plus
longtemps, le plancher 1,2 tient. Le contrôle négatif d'abord : un tap
sur le sol nu n'arme rien.

⚠️ **Deux défauts d'instrument trouvés par la première passe, tous deux
avec l'allure d'un résultat.** (1) « il est porté par le chariot » a lu
**0,0838 u** au pire — la frame qui termine le trajet est aussi celle qui
lance son saut de descente, et une lecture prise là mesure le saut, pas
le portage (idem 0,168 u sur la nacelle). Lu seulement tant qu'il est
`is_on_carrier()` : 0,00000 des deux côtés. (2) L'insertion de
`_setup_funfair` dans `HubWorld` avait avalé la queue de
`_setup_skatepark` (le `board_trick.connect`), qui se retrouvait
exécutée à chaque FIN DE TRAJET : « Signal already connected » dans le
log, sans aucun rouge. Relu dans le diff (`git diff` ne devait montrer
AUCUNE ligne retirée), remis en place, l'erreur a disparu au rerun.

### 7.2 — La tour

506 frames à bord (8,4 s) : montée à **0,900 u/s** exactement, sommet
**5,100**, **96 frames** d'attente (1,6 s), chute à **−8,33 u/s** à la
ligne de frein (chute libre prédite −8,28), plancher jamais sous 0,450,
couronne toujours dans le cadre, portage 0,00000, débarquement sur le
stand nord, porte retirée pendant le trajet et tap jeté.

### 7.3 — Budget APRÈS, et le delta du lot

`gpu` = primitives opaques du viewport 3D, parc visible → caché,
plancher entre deux lectures = 0 (arbre gelé) :

| station | gpu avec | gpu sans | Δ gpu | Δ calls | scene |
|---|---|---|---|---|---|
| spawn (0, 0) | 70 592 | 70 592 | **+0** | +0 | 364 217 → 360 149 |
| CH22 pire (−5, 35) | 84 844 | 84 844 | **+0** | +0 | idem |
| gare (27, 26) | 70 699 | 66 631 | **+4 068** | +4 | idem |
| drop view (32, 40) | 67 828 | 63 760 | **+4 068** | +4 | idem |
| tour (33 ; 18) | 64 626 | 60 558 | **+4 068** | +4 | idem |

**Delta du lot : +4 068 triangles de scène (+1,13 %), +4 068 primitives
et +4 draw calls là où le parc est dans le cadre, ZÉRO ailleurs** (aucun
LOD, aucun `visibility_range` : le parc est un objet de 4 maillages qui
est soit dans le frustum soit pas). Le plafond de 50 k du dépôt était
déjà à 62 321 au site avant ce lot (+23 %) ; il est à **~66 400 aux
stations du parc** (+33 %). Point de décision pour Mathieu, pas un blocage
silencieux : le parc pèse 6 % d'une frame qui en était déjà à 123 %.

## Section 8 — CE QUI N'EST PAS COUPLÉ, ET CE QUI POURRAIT L'ÊTRE

Cherché parce que CH69 l'a payé (`park_span` → `skate_coast_u` →
`configure`) : **aucune constante dérivée d'un autre module ne lit le
parc**. `HubFunfair.footprints()` n'est lu que par `CozyScatter._sprinkle`
(après tirages) et par `FunfairProbe` ; `TRACK_POINTS` par personne
d'autre ; la région, `HubTransport`, `HubSkatepark`, `HubTrees` sont
intacts. Les seules choses qui ont bougé hors du parc :

* `CozyScatter._sprinkle` : le test post-tirages (section 6) ;
* `HubTapInput` : un `NodePath`, un signal, un test sur `aim` ;
* `HubWorld` : un `@onready`, un `_setup_`, deux handlers, un hook
  d'atterrissage, trois `cancel_intent()` — **zéro ligne retirée** ;
* `HubWorld.tscn` : un nœud `Funfair`, un chemin sur `TapInput`.

Un couplage POSSIBLE, nommé sans être corrigé : la planche (skate lobe,
r 36) peut rouler jusqu'au parc (le site est dans le lobe). Les solides
D5 l'arrêtent sur les poteaux, la gare et la tour ; elle passe SOUS les
rails et sur le deck de 3 mm. Non mesuré avec la planche dans ce lot
(hors brief) — à valider device, et `SkatePhysicsProbe` ne le sait pas.

## Section 9 — PROTOCOLE DE TEST DEVICE (PWA installée, sans URL ni paramètre)

1. Ouvrir la PWA, arriver au hub (spawn). Ouvrir l'overlay dev si le
   build le montre (`DevTools.enabled()`, aucun query param) et lire
   `POS` pour se guider.
2. Marcher vers l'**est puis le nord** jusqu'à lire **x ≈ 33, z ≈ 20** :
   le deck en bois et le chariot crème sont à droite du repère
   **(35,2 ; 27,7)**, sous les rails ; la tour rouge est au sud
   (x ≈ 33, z ≈ 8,5), visible depuis la gare.
3. **Montagnes russes** : un tap sur le chariot ou le deck → Keepy
   marche au deck et embarque. Vérifier : montée lente vers le nord
   (~6 s), le virage au sommet, puis la descente vers le sud avec la
   bosse et la tour dans le cadre, l'arrêt en gare et le pas sur le
   deck. Total ~15 s.
4. **Le frein** : pendant la descente, **tenir le doigt** n'importe où :
   le chariot ralentit (jusqu'à 1,2 u/s), relâcher le relance ; il
   revient TOUJOURS en gare. Tap bref pendant le trajet : rien ne doit
   se passer (ni saut, ni menu).
5. **Tour de chute** : tap sur la tour → marche jusqu'à son aire nord,
   embarquement, montée lente (~5 s), pause 1,6 s, chute, freinage sec,
   pas sur l'aire. Vérifier que la tête reste dans l'image au sommet.
6. À regarder pour la lisibilité (ce que la sonde ne peut pas signer) :
   la tour rouge contre le mur d'arbres et le ciel, les rails gris sur
   l'herbe, le chariot crème ; et la sensation de la descente (9,2 u/s
   contre 10 de croisière skate).
7. Cas de bord : taper la tour PENDANT un trajet de chariot (rien),
   taper le sol depuis le deck (marche normale), skate jusqu'au parc
   (les poteaux arrêtent la planche).

## Section 10 — ROUGE AVANT VERT : 5 rouges sur 5 prédits

Trois neutralisations appliquées ENSEMBLE sur `HubFunfair.gd`, chacune
avec ses rouges prédits avant le run :

| neutralisation | rouges prédits | rouges obtenus |
|---|---|---|
| `BRAKE_DECEL` 3,0 → 0,0 | E13 (vallée freinée = libre), E14 (durée égale) | E13 « 8.92 braked vs 8.92 free », E14 « 899 vs 899 frames » |
| `accepts_tap` sans la condition de phase (les portes ne se retirent jamais) | E8, F12 | E8, F12 |
| `blocks()` → `false` | B10 | B10 « none inside them (16) » |

**5 / 5, et pas un de plus** : E9 (le tap est jeté par l'ÉTAT, pas par
la porte) reste vert sous la seconde neutralisation, ce qui est exactement
la distinction que le patron bateau fait entre « la porte se retire » et
« la chose ne mange pas le tap » — deux assertions, deux mécanismes, la
passe rouge le prouve. Fichier restauré, `cmp` byte-identique, `.bak`
supprimé.

## Section 11 — TABLE CROISÉE SUR DEUX ARBRES

Référence : worktree `origin/staging` (`60d7cb3`) importé à part
(**154 `.scn` des deux côtés**, compté avant de comparer). Chaque sonde
rejouée sur les deux arbres **en séquence, un process à la fois**, sous
le driver que son en-tête exige.

| sonde | driver | référence | branche | verdict |
|---|---|---|---|---|
| ProbeTimeoutAudit | headless | 98 scènes bornées | **99** | + `FunfairProbe`, la recon jetable supprimée |
| SeesawProbe | headless | 61 / 2 | 61 / 2 | les MÊMES deux rouges pré-existants ; diagonale 1 122 frames / 18,700 s des deux côtés |
| SkateTraverseProbe | headless | 37 / 0 | 37 / 0 | identique |
| SkatePhysicsProbe | headless | 161 / 0 | **46 / 1 → arrêt** puis **161 / 0** | voir ci-dessous |
| SkateDriveProbe | xvfb | 29 / 0 | 29 / 0 | identique (le canal de tap) |
| ZiplineStructureProbe | xvfb | 100 / 3 | 100 / 3 | les mêmes trois rouges pré-existants |
| SkateparkProbe | xvfb | 57 / 0 | 57 / 0 | identique (recensement nord compris) |
| MinimapProbe | xvfb | 189 / 1 | **188 / 2 → 189 / 1** | voir ci-dessous |
| CabinProbe | xvfb | 253 / 15 puis **255 / 12** | 253 / 15 puis 254 / 14 | ne se reproduit pas sur UN arbre, voir ci-dessous |
| **FunfairProbe** (neuve) | xvfb | — | **78 / 0** | passe rouge 5 / 5 prédits |

**Deux recensements littéraux ont rougi, et c'est le lot qui les répare
en les faisant LIRE le producteur** (CLAUDE.md : « le producteur publie ce
qu'il a construit ; le lecteur ne le reconnaît jamais ») :

* `SkatePhysicsProbe` gatait `rids.size() == 6` (cinq modules + la
  planche) et, sur un septième corps, s'ARRÊTAIT en imprimant « nothing
  physical was built » — ce qui n'était pas ce qui s'était passé. Le gate
  compare maintenant l'ensemble des corps VIVANTS du serveur à l'ensemble
  PUBLIÉ (les corps du park, la planche, le corps du parc s'il existe),
  **dans les deux sens** : 7 vivants, 0 non publié, 0 manquant. Sa PHASE X
  (« 9 objets, 139 formes ») lit de même le corps et les 37 formes du
  parc : 10 objets, 176 formes. Rejouée : **161 / 0**, la parité.
* `MinimapProbe` porte un roster littéral « écrit avec son historique »
  (37 → 39 au CH53) ; il passe à **40** (+ la tour, un PLACE) avec sa ligne
  CH71. Rejouée : 189 / 1, le même rouge pré-existant que la référence
  (le cadre 137 × 263 contre 271).
* `CabinProbe` : **15 puis 12 rouges sur la référence SEULE**, deux runs
  à charge comparable, lignes différentes — tous dans la phase du baiser
  (CH19 : pourcentages de contact au visage lus au pixel sur une pose
  animée). Un gate qui ne se reproduit pas sur un arbre ne peut rien
  dire de deux (CH37). Les 253-255 assertions hors baiser sont vertes
  des deux côtés, y compris tout le routage de tap de la porte à z = 28.

## Section 12 — CE QUI RESTE, ET CE QUI EST UN POINT DE DÉCISION

* **Budget** : 62 321 → ~66 400 primitives aux stations du parc, +0
  ailleurs ; le plafond de 50 k était déjà dépassé de 23 % avant ce lot.
  Décision Mathieu, pas blocage.
* **L'orientation « sud-ouest » et la « structure en bois »** du brief ne
  correspondent pas à (35,2 ; 27,7) — section 1.3. Si le site voulu était
  côté cabane, c'est un déplacement de constantes et un rejeu de la sonde.
* **Une caméra qui monte** rendrait des collines de 8-10 u possibles ; la
  doctrine dit que c'est un autre lot. Le parc est dimensionné pour la
  caméra livrée (siège ≤ 5,868).
* **Pas de son, pas de HUD, pas de score** : hors brief, à décider après
  le device (le HUD du skate et `WorldSave.award_from_activity` sont les
  patrons à suivre).
* **La planche jusqu'au parc** (section 8) : à valider device.
