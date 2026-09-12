# CH75 — La Comète : le troisième manège du parc, et le premier sous la caméra de poursuite

*11 → 12 septembre 2026, session carte blanche nocturne (Fable 5.1, sans
supervision). Branche `claude/3rd-coaster-funfair-gc48t2`, base
`origin/staging` `21c1d42` (merge CH74), arbre `2a05017…`, vérifié par
ARBRE au `fetch` du début : `origin/main` n'est en avance que de deux
fichiers de doc (CH74), aucune branche distante ne porte un nom voisin,
aucune session concurrente.*

Brief : un « 3e roller coaster » dans le parc, « nettement plus effrayant et
plus rapide que les 2 coasters existants », rail fixe, aucun contrôle
joueur, caméra de poursuite comme le karting, pattern bateau pour la porte
de tap, patron échelle interdit. Le lot a été conçu, tranché, sondé et
poussé sur `staging` sans un seul test device. **Tout ce qui suit est
mesuré ; ce qu'aucune sonde ne peut signer est nommé en section 9.**

⚠️ **Une prémisse du brief corrigée en tête** : le parc CH71/CH72 ne
contient pas deux coasters mais **un coaster** (crête 5,03 u, 9,19 u/s) et
**une tour de chute** (14,0 u, −14,21 u/s). La Comète est donc le
troisième MANÈGE et le second COASTER ; la comparaison chiffrée est faite
contre les deux.

---

## Section 1 — RECON (bloquante, tout mesuré)

### 1.1 — Ce que CH71/CH72 ont laissé (lu dans leurs fichiers, pas supposé)

| manège | forme | hauteur | vitesse max | caméra | triangles |
|---|---|---|---|---|---|
| coaster CH71 (`HubFunfair.TRACK_POINTS`, 17 points, 51,165 u) | ovale N-S, treuil à 17,7°, pente max 37,6° (43,1° relue sur la courbe cuite) | crête 5,027 | **9,189 u/s** (mesuré au vrai canal) | FIGÉE | 4 068 (parc entier) |
| tour CH72 | montée 7 s, chute libre, frein 3,04 g | nacelle 14,0 | **−14,21 u/s** | figée + LIFT borné, POV au tap | +384 |

Patrons réutilisables lus : la boucle est une spline cardinale fermée
(`Curve3D`, tension 0,5, bake 0,1) ; le chariot est paramétré par l'abscisse
curviligne et sa vitesse est une COURBE par phase (DEPART/LIFT/COAST/BRAKE,
énergie exacte sur la table des hauteurs) ; la pose du rider vient de
`ride_frame` (+Z sur la tangente, base droitière — CH72) ; la porte de tap
se RETIRE pendant le trajet (bateau) ; l'intention est armée APRÈS `hop_to`.

### 1.2 — Le site : la pointe nord-est de la zone 0 (`Ch75SiteRecon`, xvfb, jetable, supprimé)

Instrument d'abord : 296 couleurs, **2 583 / 2 583** transforms de
`MultiMesh` non-identité. Puis la boîte x [8 ; 37] × z [34 ; 62] :

* **région** : le lobe skate (r 36 depuis (0 ; 35)) ; la pointe est
  limitée à x ≤ 35 en z 38-42, ≤ 33 à z 48, ≤ 30 à z 56, ≤ 24 à z 62 ;
* **sol plat** : hauteur min 0,000, max 0,000 sur toute la boîte ;
* **layout** : un seul prop à moins de 12 u du futur tracé — la balançoire
  (18 ; 44) r 1,8 ; la tour P2 de la tyrolienne (25,2 ; 35) r 1,78 (lobe de
  structure r 3), son câble finissant à z 34,5 ; la dalle du skatepark
  s'arrête à x 10 ; le marcheur de l'ours à (18 ; 42,5) ;
* **semis** : herbe, fleurs, feuilles, 4 buissons, 3 rochers ; **un seul
  arbre du mur** dans la boîte, à (35,18 ; 55,11), HORS région ;
* **le coaster CH71** : sa pointe nord est à z 37,5, ses empreintes
  publiées montent à z 36,91.

### 1.3 — Le prix d'une caméra en hauteur, mesuré AVANT de dessiner

C'est la question qui décidait du concept : une pose de poursuite à 16 u
voit-elle tout le plateau ? Poses posées à la main (far 120, fov 60), deux
lectures chacune après un aller-retour (règle CH62, une lecture répétée ne
détecte pas une valeur périmée) :

| pose | gpu | calls |
|---|---|---|
| crête 16 u regardant le SUD | **69 897** | 242 |
| crête 16 u regardant le nord | 15 919 | 30 |
| crête 16 u regardant l'ouest | 53 884 | 115 |
| vallée 4 u regardant le sud | 51 948 | 215 |
| pose kart au sol, spawn, vers le sud | 70 380 | 237 |
| **pose FIXE du hub au spawn (témoin)** | **70 782** | 303 |

**La hauteur ne coûte rien sur ce plateau** : depuis 16 u vers le sud, le
compteur lit 1 % de MOINS que la pose fixe du spawn. Le plafond de 50 k
est dépassé depuis CH29 (+41 % au spawn avant ce lot) et la Comète n'y
change rien au spawn (delta +0, mesuré en G).

---

## Section 2 — LA DÉCISION : LA DESCENTE VERTICALE, ET POURQUOI PAS AUTRE CHOSE

Trois profils étaient sur la table (drops, inversions, vitesse + virages
serrés). **Tranché : drop dominant + vitesse**, sur trois mesures.

**(a) Le chiffre.** L'énergie sur un rail donne `v² = v_treuil² + 2 g Δh −
2 μ Δs`. Une crête à **14,0 u** (la hauteur de la tour CH72, celle que
Mathieu a validée à l'image) dans une vallée à 0,9 u donne **15,92 u/s**
en forme fermée — **×1,75 le coaster CH71** (9,10 u/s par la même
arithmétique, 9,19 mesuré), **×1,13 la chute de la tour** (14,14 u/s), ×1,6
la croisière du skate (10,0). Pente de descente authored à 65-75° (72,2°
mesuré sur la courbe cuite) contre 43,1° pour le coaster CH71. Treuil à
~60° sur sa partie haute contre 17,7°.

**(b) La lisibilité unlit.** Rien n'est éclairé dans ce hub : une forme se
lit par SILHOUETTE seule. Un treillis de 14 u contre la brume est
exactement la tour CH72 (15,5 u, visible sur device) ; une descente se lit
parce que le rail TOMBE dans la silhouette. Une INVERSION ne se lirait
pas et ne se DESSINERAIT pas : `KeepyHopper.follow_carrier` ne recopie que
le **LACET** du porteur (cinq manèges dépendent de ce contrat), donc un
chariot en looping dessinerait Keepy debout la tête en haut dans le loop.
Corriger ça, c'est toucher un composant partagé validé device — pas cette
nuit, et pas sans Mathieu. Pas de looping.

**(c) Le budget.** Section 1.3 : la pose de poursuite en hauteur coûte le
prix de la pose fixe. La Comète elle-même est des boîtes et des tubes à six
pans (section 4).

---

## Section 3 — LE TRACÉ (`HubFunfair.COMET_POINTS`, 22 points, y = dessus de rail)

```
 0  (23.0, 0.55, 41.5)  gare (s = 0), cap NORD
 1  (23.0, 0.62, 43.2)  pied du treuil
 2  (23.0, 1.30, 45.2)  jambe douce (voir 3.2)
 3  (23.0, 2.60, 47.6)
 4  (23.0, 4.30, 50.0)  le genou : le treuil passe a ~60 deg
 5  (23.0, 8.50, 52.6)
 6  (23.0, 13.0, 55.2)  haut du treuil, le virage commence
 7  (23.81, 13.4, 57.14)
 8  (25.75, 13.7, 57.95) apex du virage haut
 9  (27.6, 13.8, 57.3)
10  (28.3, 13.9, 56.0)  fin du virage, cap SUD, A PLAT
11  (28.3, 14.0, 54.7)  CRETE -- la descente commence, deja plein sud
12  (28.3, 12.3, 53.5)
13  (28.3, 7.00, 51.6)
14  (28.3, 2.20, 49.5)
15  (28.3, 0.90, 47.6)  vallee (COMET_VALLEY_INDEX)
16  (28.3, 4.40, 45.0)  camelback
17  (28.3, 2.40, 43.2)
18  (28.3, 1.00, 41.5)  seconde vallee, le virage bas commence
19  (27.52, 0.70, 39.63)
20  (25.65, 0.60, 38.85) apex sud
21  (23.78, 0.60, 39.63) -> retour au 0
```

Mesuré sur la courbe cuite (`CometProbe`) : longueur **63,163 u**, pied du
treuil s 1,721, **crête s 28,800 / y 14,164**, pente max **72,2°**, rail
le plus bas 0,515 u, **43 poteaux**, 0 / 514 échantillons de rail
EXTÉRIEUR hors région, 0 / 43 poteaux hors région.

### 3.1 — Les demi-cercles à points réguliers, et le coup de fouet qu'ils évitent

Deux réécritures du tracé avant la bonne, toutes deux sur mesure :

* **un point de contrôle inégalement espacé fait un S** : la poignée
  d'une spline cardinale vaut `(P[k+1] − P[k−1]) × 0,25`, donc une corde
  courte après une longue reçoit une poignée plus longue qu'elle. Réplique
  Python du bake : **0,48 u de rayon** à l'entrée de la gare avec un point
  d'aide mal placé, 2,8 u une fois les virages authorés comme des
  demi-cercles à ~2 u de pas ;
* **le virage haut terminé SUR la crête a fait lire 502°/s de lacet au
  chariot** (`CometProbe` E24, run 2) : le cap se lit sur la tangente, et
  au moment où elle bascule sa composante plate est minuscule — 36° de cap
  en quelques frames. Le virage finit désormais à PLAT un point AVANT la
  crête (point 10), et les points 10-18 partagent **x = 28,3 exactement**
  (le lacet de la descente vaut 180,00°, gaté à 0,5° par A9). Mesuré
  après : **159,1°/s** au pire, à l'entrée du virage bas.

### 3.2 — Le treuil à deux pentes, et c'est la caméra FIXE qui l'a décidé

Premier tracé : treuil rectiligne à 45°. La caméra du hub se tient 8,9 u
au NORD du rider à 7,6 u de haut ; à la gare (z 41,5) elle est donc à
z 50,4 — **sur le treuil**, dont le rail y culminait à 8,2 u. Pendant la
marche d'embarquement, l'objectif était DANS les poteaux du treuil
(`CometProbe` E11, 4 frames au départ du run 5, à (22,6 ; 7,6 ; 49,9)).
Le treuil monte donc doucement sur 7 u (rail à **4,74 u** sous l'objectif à
z 50,4) puis à **61,8°** jusqu'à la crête. Le chariot y va toujours à
2,2 u/s : ~13 s de montée, dont 4 s de virage haut à plat au-dessus du
vide — c'est la suspense, et c'est un ressenti (section 9).

---

## Section 4 — CE QUI EST CONSTRUIT

`CoasterRail` (nouveau, statique, pur) porte l'arithmétique que les deux
coasters partagent : bake de la boucle fermée, repère de balayage
(miroir, det −1, jamais une pose), repère de conduite (+Z sur la tangente,
droitier), crête et pente max mesurées sur la courbe cuite. `HubFunfair`
lui **délègue** ses cinq fonctions de courbe — un déplacement pur, prouvé
par `FunfairProbe` PHASE A qui relit 51,165 u / s 17,350 / y 5,027 sur
les deux arbres (section 8).

La Comète vit DANS `HubFunfair` comme `RIDE_COMET = 2` : même corps
statique (D5), mêmes `footprints()` (semis rejeté après tirages, CH71
section 6), même `accepts_tap` (retrait pendant le trajet), même
`arm / on_landing / cancel_intent / ride_finished`, même `stand_point`.
**Zéro ligne de `HubWorld`, `HubTapInput`, `CozyScatter` ou
`SkatePhysicsProbe` touchée** — ils lisaient déjà le producteur.

| pièce | construction | triangles |
|---|---|---|
| rails | deux tubes hexagonaux r 0,06 à l'écartement 0,70, échantillon 0,5 u | ~3 000 |
| traverses | tous les 0,9 u | ~850 |
| poteaux | tous les 1,5 u où le rail dépasse 0,35 u, section 0,22, **solides** | 43 × 12 |
| croisillons | une diagonale entre poteaux voisins de plus de 3 u, en alternance | ~300 |
| gare | deck CH71, deux poteaux solides, toit | ~60 |
| chariot | boîte, appuie-tête, quatre roues | 72 |
| **total** | `comet_triangle_total()` | **4 788** (le parc passe de 4 452 à 9 240) |

Couleurs (sommets, unlit) : structure **encre violette** (0,30 ; 0,16 ;
0,48) — sombre, parce qu'à 14 u elle se découpe sur la brume ; rails
**jaune** (0,98 ; 0,86 ; 0,30), L ~0,65 contre le sol rendu à 0,08 ;
chariot **carmin**. Choix de goût, à juger device.

`FunfairProbe` D3 lit désormais `HubFunfair.FIXED_SOLIDS` (2 + 6 + 2) au
lieu de taper 8 : les poteaux de la Comète comptent par les mêmes disques
`POST_FOOTPRINT` que ceux de CH71, une seule liste de stations
(`comet_post_stations`, lue par le bâtisseur ET par `footprints()`).

---

## Section 5 — LA CONDUITE : la loi CH71, sans frein joueur, avec un run-out en deux temps

| phase | loi |
|---|---|
| DEPART | v → 2,2 à 1,5 u/s² jusqu'au pied du treuil |
| LIFT | 2,2 u/s jusqu'à la crête (**le virage haut est sur la chaîne**) |
| COAST | E += −g·Δh − 0,35·Δs, v = √(2E), plancher 1,2 ; **aucun terme de doigt** |
| TRIM | 4 u : v descend linéairement de l'entrée (**13,3 u/s**) à `COMET_TURN_SPEED` **5,0** (~1,9 g) |
| BRAKE | 9 u : `5,0 · √(1 − u)`, arrêt exact à s = L, remise à s = 0 |

Le trim existe pour une mesure : à 13 u/s dans un demi-cercle de 2,65 u
le lacet du chariot vaut ~280°/s et la caméra le suivrait en coup de fouet.
`CometProbe` A12 marche la loi de freinage elle-même le long du virage
cuit : **158°/s au pire** (s 55,9), contre ~400 sans trim — le seuil de
200 est ENTRE les deux (CH65).

Le trajet est BORNÉ (rail, plancher, run-out) : c'est la licence CLAUDE.md
qui autorise à jeter un tap pendant le trajet ; la porte se retire
(`accepts_tap` → −1), le tap retombe sur le sol et `ON_CARRIER` le refuse.
**Pas de POV sur la Comète** : `accepts_rider_tap` refuse pendant son
trajet — un POV ouvert sur un drive en cours ferait deux écrivains sur
une caméra.

---

## Section 6 — LA CAMÉRA : le drive du karting, monté SUR le rail

`HubCamera.ChaseTuning.coaster(cart)` : les lags du kart (3,6 / 7,0), le
cap de lacet du skate porté à **150°/s**, pas de zone morte, fov **64**
(le plus large des quatre — un nombre de ressenti), `airborne = true`,
`up = 6,2`, `look_target = le chariot`. Les trois véhicules et la planche
gardent leur chemin byte-identique (`is_plain()` exclut `airborne`).

⚠️ **Trois poses ont été mesurées avant la bonne**, et chacune avait l'air
juste à la relecture :

| pose | `CometProbe` E11 |
|---|---|
| 7,6 u derrière sur le cap plat, 4,4 u au-dessus du CHARIOT | 37 frames dans un solide, 27 dans un rail (le rail du camelback, frôlé à 0,2 u) |
| idem, 6,2 u au-dessus | **24 dans les poteaux de la descente**, 8 sur son rail |
| 7,6 u derrière le long de la tangente 3D lissée | 16 / 15 — la pointe balaie le rail concave derrière le chariot dans la vallée |
| **une MONTURE trainée sur la courbe** (`comet_ride_frame(s − DRIVE_BACK)`), caméra 6,2 u au-dessus, regard sur le chariot | **0 / 0** sur 1 196 frames |

Le mécanisme est écrit dans `CLAUDE.md` (doctrine nouvelle) : les poteaux
se tiennent sur la ligne XZ du rail et derrière un chariot en descente à
72° ce rail monte de 23 u en 7,6 u ; un chariot sur rail n'a pas
d'« arrière » qui ne soit pas le rail. Il reste le retard de position qui
coupe l'intérieur de la vallée (~0,9 u sur 6,2 de marge) et **61 frames
sur 1 147 où un rail traverse la ligne de visée** (le croisement de la
structure derrière une descente) — publié, pas gaté, à juger à l'image.

---

## Section 7 — `CometProbe` (permanente, xvfb + opengl3, jamais headless)

Huit phases, ~70 assertions, chaque trajet lancé depuis un POINT D'ÉCRAN
par `HubTapInput._handle_point`, `board()` jamais appelé par la sonde.
Météo épinglée au soleil (CH72). Le coaster CH71 est ridé D'ABORD dans le
même run, pour que « ×1,5 » soit une comparaison de même banc.

### 7.1 — Le trajet mesuré (run final)

| grandeur | mesure |
|---|---|
| frames à bord | **1 196** (19,9 s) : DEPART 1, LIFT 89, COAST ~803, TRIM ~947, BRAKE ~973 |
| v max | **16,088 u/s** ; crête franchie à 2,194 (treuil 2,2) |
| vallée | **15,976** contre 15,918 en forme fermée (0,4 %) — la loi d'énergie est CÂBLÉE |
| coaster CH71, même banc | 9,189 → **×1,75** |
| entrée du trim / pire vitesse dans le virage bas | 13,309 / 4,979 (≤ 5,0) |
| y max du rider | 14,504 (rail 14,164 + siège 0,34) |
| poursuite | 1 196 / 1 196 frames en drive, blend fait sur 1 147, **couronne dans le cadre 1 147 / 1 147** |
| caméra dans un solide / un rail | **0 / 0** |
| lacet caméra / chariot | voir 7.2 / 159,1°/s au pire (s 56,05) |
| face à la marche | pire 0,03° ; portage 0,00000 u |
| primitives sous la poursuite | max **85 321**, moyenne **36 558** (spawn fixe : 70 510) |
| fin | terminé UNE fois, debout sur le stand à 0,000 u, drive relâché, fov 45 / far 4000 rendus |
| portes | gare retirée pendant le trajet, tap sol jeté par l'état, tap sur le rider sans POV, gare répond après |

### 7.2 — Ce que la première passe verte a trouvé (quatre instruments faux, un vrai défaut)

* **D1 lisait 0 / 28** : le rayon partait 5 cm SOUS le rail, c'est-à-dire
  DANS le poteau, et un rayon qui naît dans une forme ne rapporte rien
  (défaut Godot par défaut). Parti d'au-dessus du rail : 27 / 27.
* **Les taux de lacet étaient imprimés en rad/s sous une étiquette deg/s**
  (« 1,8 deg/s ») — le vingt-et-unième faux-signal du dépôt, attrapé
  parce que 1,8°/s pour une caméra qui fait deux demi-tours n'est pas
  crédible. Corrigé, E24 est sorti ROUGE à 502°/s — le vrai défaut de
  tracé de 3.1.
* **Le compteur de croisements de visée comptait 1 098 / 1 098** : le
  chariot est à 6 cm de son propre rail. Le tronçon du chariot est exclu.
* **A12 gatait la vitesse de virage CONSTANTE** alors que la loi la fait
  décroître : réécrit pour marcher la loi.
* **Un taux de lacet lu PAR ITÉRATION et non par frame écoulée** : les
  tests de tap en pleine descente font deux `await` dans une itération de
  la boucle, donc l'échantillon suivant couvre trois frames ; lu comme une
  seule, un virage de caméra à 66°/s (trace : 1,1° par frame) s'est
  imprimé **208°/s** et E23 est sorti rouge sur une caméra sous son cap.
  Divisé par les frames écoulées (`Engine.get_process_frames()`).
* Et E11 a nommé le défaut de caméra de la section 6, trois fois.

### 7.3 — Rouge avant vert : 8 rouges pour 7 prédits, et l'extra a une cause unique

Trois neutralisations appliquées ENSEMBLE sur `HubFunfair.gd`, rouges
prédits AVANT le run :

| neutralisation | prédits | obtenus |
|---|---|---|
| `GRAVITY` retiré de la loi d'énergie de la Comète | E5, E6, E7, E13 | E5 « 4.99 u/s », E6 « valley 1.20 vs 15.92 », E7 « x0.54 », E13 « entered at 1.21 » |
| `_sync_comet_camera(true)` jamais demandé | E9, E10 | E9 « 0 / 2120 frames », E10 « 0 out of 0 » |
| `accepts_tap` sans la condition de phase | E12 | E12 |
| — | — | **E11 « camera inside a solid 424, rail 69 »** |

L'extra n'est pas un défaut de sonde : **sans la poursuite, la caméra FIXE
suit le point SOL du rider le long de la boucle**, 8,9 u au nord et 7,6 u
de haut, et traverse les poteaux du treuil et de la descente pendant 424
frames. C'est la preuve, par la passe rouge, que la poursuite montée sur
le rail est ce qui tient la caméra hors de la structure — et que la
question « est-il visible » (E10) et la question « la caméra est-elle
dans un poteau » (E11) tombent ensemble quand la caméra ne suit pas le
corps. Sans gravité, le trajet dure 35,3 s au plancher de 1,2 u/s et
finit quand même (E16 vert : BORNÉ, même à vide). Fichier restauré,
**byte-identique au commit** (`git diff --quiet`), `.bak` supprimé.

---

## Section 8 — TABLE CROISÉE SUR DEUX ARBRES

Référence : worktree `origin/staging` (`21c1d42`) importé à part, **154
`.scn` des deux côtés** (compté avant de comparer). Chaque sonde rejouée
**en séquence, un process à la fois**, sous le driver que son en-tête
exige.

| sonde | driver | référence | branche | verdict |
|---|---|---|---|---|
| **FunfairProbe** (CH71 + CH72, 116 assertions) | xvfb | **116 / 0** | **116 / 0** | parité exacte, `diff` des libellés VIDE — la délégation à `CoasterRail` relit 51,165 u / s 17,350 / y 5,027, D3 lit `FIXED_SOLIDS` |
| ProbeTimeoutAudit | headless | 100 scènes bornées | **101** | + `CometProbe`, la recon jetable supprimée |
| SkatePhysicsProbe | headless | 161 / 0 | voir 8.1 | — |
| **CometProbe** (neuve) | xvfb | — | **73 / 0** | passe rouge 8 pour 7 prédits (7.3) |

### 8.1 — SkatePhysicsProbe : un banc de temps CPU dont le plancher a dépassé son signal

PHASE I mesure le coût d'un tick physique avec et sans les corps du hub
(le corps du parc compris, qui porte désormais 45 boîtes de plus). Premier
run de branche : **idle 0,1719 ms/tick, plancher 0,1204** → rouge sur le
budget de 0,10 ; run de référence : idle 0,0234, plancher 0,0433, vert.
Rejoué seul sur la branche : **idle −0,1273 (négatif) contre un plancher
de 0,1271**, et cette fois c'est le BLIND CHECK qui rougit (le banc ne
voit plus la planche ridée au-dessus de son propre bruit). Un coût mesuré
négatif n'est pas un coût (CLAUDE.md : « un coût mesuré négatif est un
contrôle faux ») et **un plancher au-dessus du budget est une absence de
verdict** (CH56) — le tick complet oscillait entre 1,04 et 1,50 ms d'une
lecture à l'autre sur ce sandbox, contre 1,08-1,14 sur la référence.
La paire rejouée dos à dos sur machine vide (charge 1,0) : référence
**idle −0,0375 / plancher 0,1666, ALL GREEN** ; branche **idle −0,0298 /
plancher 0,0303, ALL GREEN**. Les deux lisent un coût idle NÉGATIF de
quelques centièmes, c'est-à-dire ZÉRO au bruit près, des deux côtés :
**45 boîtes statiques de plus dans le même corps ne coûtent rien que ce
banc sache voir**, et la parité est rétablie. Le premier rouge était le
sandbox, pas la Comète — et il a fallu trois runs pour le dire, parce
qu'un banc de temps CPU ne se lit pas sur un seul.

---

## Section 9 — CE QUE CE LOT NE PEUT PAS SIGNER (l'appel device de Mathieu)

Une sonde ne juge pas un game feel (CH62). Rien ici ne dit :

* si la descente **fait peur** — 16 u/s sont mesurés, le frisson ne l'est pas ;
* si 13 s de treuil à 2,2 u/s, dont 4 s de virage haut à plat, sont une
  attente délicieuse ou une attente ;
* si la caméra montée sur le rail, 6,2 u au-dessus, regardant le chariot
  presque à la verticale sur la descente, est le bon point de vue — ou
  s'il faut la reculer, la baisser, élargir ou resserrer le fov (64) ;
* si le trim de 1,9 g sur le flanc du camelback se lit comme un frein ou
  comme un décrochage ;
* si le violet se lit contre la brume et le jaune contre l'herbe ;
* si les 61 frames de rail dans la ligne de visée dérangent ;
* si le tap sur soi, qui ouvre le POV sur les deux autres manèges et rien
  sur celui-ci, manque.

### Protocole device (PWA, sans paramètre)

1. Marcher vers **x ≈ 20, z ≈ 42** (nord-est du plateau, au nord du
   coaster CH71, à côté de la balançoire). Le deck en bois et le chariot
   carmin sont à l'est, sous un treillis violet de 14 u.
2. Tap sur le chariot ou le deck : Keepy marche, embarque, **la caméra
   passe en poursuite** (0,9 s de fondu). Montée douce puis raide vers le
   nord, virage à plat au sommet vers l'est, **descente plein sud**,
   camelback, freinage sec, demi-tour au sol, gare. ~20 s.
3. Tap n'importe où pendant le trajet : **rien** (ni saut, ni POV, ni
   menu). La caméra revient en pose fixe à l'arrivée, Keepy debout sur le
   deck.
4. À regarder : la lisibilité du treillis contre le ciel depuis le sol,
   la sensation de la descente, le retour de caméra, et si un rail
   traverse l'image au départ de la descente.
