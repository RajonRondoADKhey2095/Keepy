# CH43 — Marche arrière : un seul geste, même axe qu'avancer

> Base `origin/staging` au commit `128d627` (fin CH42). **Ce lot corrige un
> choix UX de CH42 suite à un retour direct de Mathieu sur device.** La
> physique de CH42 n'est pas touchée : seul le chemin d'entrée change.

## CH43-0 — Le retour, et ce qu'il coûte exactement

CH42 avait livré la marche arrière sur un **deuxième doigt**. Mathieu l'a
essayée sur iPhone et l'a refusée : un second doigt est une chose à
**apprendre**, et rien d'autre dans ce jeu n'en demande un. Sa décision — un
seul axe, celui sur lequel le pouce est déjà : **haut = avancer, bas =
reculer** — n'est pas rediscutée ici.

Ce que ça coûte est étroit, et c'est le résultat principal du lot : **le
geste vit dans un seul fichier**. `KartTouchInput.gd` est le seul écrivain
tactile du dépôt, et il n'en existe que **deux instances** — celle de
`HubKarting` (le kart) et celle de `HubTransport` (le char, le voilier et la
luge). Les quatre véhicules reçoivent donc le nouveau geste **sans une ligne
de leur côté**, et `VehicleDrive.gd` n'a eu besoin d'aucun changement de
comportement.

## CH43-1 — Deux champs, pas un axe signé : le choix, et sa raison

Le brief laissait le choix entre fusionner `throttle`/`reverse` en une valeur
signée unique et garder deux signaux pilotés par un seul geste. **Deux
signaux**, et ce n'est pas un choix d'élégance mais de rayon d'explosion :

| `throttle` est écrit par | ce qu'un signe dessus atteindrait |
|---|---|
| `KartTouchInput` (croisière automatique tenue à 1,0) | le geste — le seul concerné |
| `KartAiDriver` | les trois adversaires du karting |
| `KartLineInput` | le suiveur de ligne |
| chaque `set_all` de sonde | KartProbe, RaceBalanceProbe, les traces |

Le geste est une propriété d'un **pouce** ; `throttle` est un contrat entre
trois écrivains et un corps. Fusionner aurait mis un retour UX à l'intérieur
d'un composant partagé — la forme exacte du défaut que la section « un fait
est publié une fois » de `CLAUDE.md` existe pour arrêter.

L'offset vertical du doigt par rapport à son ancre est donc devenu **signé** :
au-dessus il achète `boost` sur le span et la dead zone de V7b/CH31, en
dessous il achète `input.reverse` sur le **miroir** de ce span. Les deux
moitiés sont **exclusives** — un `boost` resté en place pendant un glissement
vers le bas laisserait `VehicleDrive` relever le plafond de vitesse
(`cap *= lerpf(1, boost_speed_ratio, boost)`) d'un véhicule que le joueur
essaie d'arrêter.

**Symétrie mesurée**, aux quatre quarts du span et pas seulement aux bouts
(deux courbes peuvent coïncider à leurs extrémités et diverger partout entre) :

| travail du pouce | `boost` | `reverse` |
|---|---|---|
| ±55,5 px | 0,250000 | 0,250000 |
| ±87,0 px | 0,500000 | 0,500000 |
| ±118,5 px | 0,750000 | 0,750000 |
| ±150,0 px | 1,000000 | 1,000000 |

Écart pire cas **0,000000000**.

**Relâchement asymétrique, et c'est délibéré.** Lever le doigt laisse le
`boost` se dissiper sur `boost_release_s` (CH31 : lever le pouce dans une
ligne droite est le geste naturel, et il tuait l'accélération) mais coupe le
rapport **net**. Aucune de ces raisons ne survit sous l'ancre : un rapport qui
continuerait à faire reculer 0,45 s après le départ du pouce est un véhicule
qui recule dans ce que le joueur vient de lever le pouce pour éviter.

**Ce qui disparaît** : `_reverse_index`, le second doigt qui l'armait, et le
**bouton droit de la souris** qui en tenait lieu hors-web. Un testeur bureau
qui l'utiliserait testerait un schéma que le téléphone n'a plus — pire que pas
de raccourci du tout ; le bouton gauche pilote l'axe entier à la place.

## CH43-2 — Le garde-fou était déjà là. Il a maintenant un nom, et une mesure

`VehicleDrive` **n'a reçu aucun changement de comportement**. Le garde-fou que
Mathieu demande — un glissement vers le bas sur un véhicule lancé **freine** et
ne bascule pas en marche arrière — est le `if v_fwd > 0.3` que CH42 avait écrit
dans ses deux branches d'entrée en marche arrière. CH43 lui a donné un nom,
`REVERSE_ENGAGE_SPEED`, parce que le brief demandait un seuil « défini et
nommé ». **La valeur est celle de CH42, au chiffre près.**

Le seuil reste **à la vitesse** et non en dead zone sur l'entrée : un écrivain
d'input ne peut pas voir à quelle vitesse va un véhicule, et trois véhicules
obéissent déjà à cette ligne sans savoir qu'elle existe.

### Le seuil, MESURÉ sur le véhicule — jamais relu dans la constante

`ReverseProbe` PHASE THRESHOLD lance chaque véhicule à **trente vitesses
différentes**, tient le rapport, et classe **chaque frame** par l'arithmétique
que la branche a réellement produite — frein, rapport, ou ni l'un ni l'autre.
La dernière frame classée « rapport » et la première classée « frein »
**encadrent** le point de bascule, et un lancement différent fait tomber les
échantillons à un décalage différent, ce qui resserre l'encadrement.

| véhicule | frames frein | frames rapport | non classées | encadrement |
|---|---|---|---|---|
| kart | 649 | 248 | 0 | (0,295599 ; 0,303540] |
| char | 540 | 262 | 0 | (0,298670 ; 0,304409] |
| voilier | 589 | 376 | 0 | (0,295031 ; 0,305069] |
| luge | 642 | 146 | 0 | (0,298196 ; 0,308061] |
| **les quatre** | | | | **(0,298670 ; 0,303540], large de 0,004870** |

La constante n'est ouverte **qu'à la fin**, pour demander si l'encadrement la
contient. La passe rouge prouve que ça compte : avec la branche gatée à **0,9**
et la constante lisant toujours 0,3, **l'encadrement mesuré s'est déplacé à
0,9** et cinq assertions sont passées au rouge.

## CH43-3 — Le garde-fou, prouvé : la fenêtre est TROUVÉE, pas choisie

« Pas de vitesse arrière dans les N premières frames » passe **gratuitement**
sur tout véhicule trop lent pour avoir atteint la bande — et la métrique
d'échappement de CH42 s'était trompée dans exactement cette forme. PHASE
BRAKING parcourt donc la trace jusqu'à la frame où la vitesse **entre** dans la
bande, quelle que soit cette frame, et n'asserte que sur les frames d'avant.

| véhicule | croisière | bande atteinte à | frames de freinage | plus basse vitesse avant | fond du run |
|---|---|---|---|---|---|
| kart | +12,260 u/s | frame 48 (0,800 s) | 48 | +0,260 | −3,240 |
| char | +7,118 u/s | frame 46 (0,767 s) | 46 | +0,218 | −2,182 |
| voilier | +5,231 u/s | frame 54 (0,900 s) | 54 | +0,281 | −2,385 |
| luge | +8,154 u/s | frame 40 (0,667 s) | 40 | +0,154 | −2,013 |

Zéro frame négative avant la bande, zéro frame qui n'a pas tourné la branche
**frein**, zéro frame où la vitesse remonte — et le run finit quand même en
marche arrière, sans quoi la phase serait verte sur un rapport qui ne marche
pas du tout.

### ⚠️ LE TEST DE SIGNE SEUL N'AURAIT RIEN VU

Mesuré sur la passe rouge qui **supprime entièrement le garde-fou** : le
véhicule n'atteint **toujours pas** une vitesse négative avant de traverser la
bande — il décélère simplement à la rampe (6,0) au lieu du frein (15,0).
`negatives_before` est resté **VERT sur du code cassé**. Ce qui l'a attrapé est
la classification par arithmétique, sur les quatre véhicules à la fois. Voir la
doctrine ajoutée à `CLAUDE.md`.

## CH43-4 — Depuis l'arrêt : la physique de CH42, au chiffre près

PHASE ARREST lit la rampe comme un **delta par frame réel** et la vitesse
terminale sur le run stabilisé, jamais comme la constante qu'elle devrait
égaler :

| véhicule | rampe mesurée | `REVERSE_ACCEL` publiée | terminale mesurée | `REVERSE_SPEED` publiée |
|---|---|---|---|---|
| kart | 6,0000 u/s² | 6,0000 | −3,5000 u/s | 3,5000 |
| char | 6,0000 u/s² | 6,0000 | −2,4000 u/s | 2,4000 |
| voilier | 4,0000 u/s² | 4,0000 | −2,6000 u/s | 2,6000 |
| luge | 13,0000 u/s² | 13,0000 | −2,2000 u/s | 2,2000 |

Et la toute première frame depuis l'arrêt tourne la branche **rapport** sur les
quatre : depuis l'arrêt il n'y a rien à freiner.

### ⚠️ La luge est conduite À PLAT dans les trois phases physiques — et le premier run dit pourquoi

`SurfaceDrive` ajoute `slope_accel * slope_gain * delta` à la vélocité monde
**APRÈS** que `VehicleDrive` l'ait écrite (CH41). À `SLED_PARK` — le milieu de
la crête ouest, **0,7777 u/s²** de pente — PHASE ARREST a donc lu une rampe de
**14,4159** contre les 13,0000 publiées et une terminale de **−2,3689** contre
−2,2000.

Aucun de ces deux nombres n'est un défaut : c'est la colline qui fait ce que
CH41 l'a construite pour faire. Mais c'est la **mauvaise question** pour une
phase qui porte sur la branche que les quatre véhicules partagent — une phase
qui répondrait « la rampe de la luge vaut 14,4159 » mesurerait deux choses et
n'en rapporterait qu'une.

La station plate est **gatée contre la station en pente**, et les deux doivent
**DIFFÉRER** (0,000000 contre 0,777682 u/s²) : une surface future qui
aplatirait la carte échouerait ici plutôt que de transformer silencieusement
PHASE SLOPE en tautologie. La luge sur sa colline reste PHASE SLOPE, de CH42,
rejouée sans modification et verte.

## CH43-5 — Le deuxième doigt, prouvé absent

`grep` trouve le code qui **est** là ; ce qu'on asserte est l'**absence d'un
comportement**. PHASE GESTURE pilote donc un vrai `KartTouchInput` avec de
vrais `InputEvent` :

* le champ `_reverse_index` n'existe plus (assertion sur la propriété, pas sur
  le texte du fichier) ;
* un **second doigt** posé et glissé écrit `reverse` **0,0000**, et ne touche
  ni `boost` ni `steer` ;
* le doigt d'ancre continue de piloter l'axe **pendant que ce second doigt est
  sur la vitre** — un second doigt qui casserait le premier serait son propre
  défaut ;
* le **bouton droit** de la souris écrit `reverse` 0,0000 ;
* et le bouton gauche glissé vers le bas écrit **1,0000**, donc la suppression
  a pris le raccourci et pas la capacité du bureau à tester le schéma.

### ⚠️ UN FAUX-VERT DE LA SONDE ELLE-MÊME, TROUVÉ PAR LA PASSE ROUGE

La dernière assertion souris lisait un `reverse` que la vérification du bouton
droit, juste au-dessus, avait laissé à **1,0** — elle **relisait l'assertion
précédente**, et elle est passée VERTE contre l'écrivain de CH42 restauré
verbatim. Fermée en pressant le bouton et en gatant le champ à zéro **avant**
le glissement qui doit l'écrire. Trouvée par la passe rouge, pas par relecture.

## CH43-6 — Ce que CH42 avait prouvé, rejoué

| sonde | verdict | contre la base |
|---|---|---|
| `KartTraceProbe` (189 lignes, 3 tours) | exit 0 | **IDENTIQUE** |
| `YachtTraceProbe` (55 lignes) | exit 0 | **IDENTIQUE** |
| `SailBoatProbe` | exit 0, 0 red | **IDENTIQUE** |
| `SledProbe` (xvfb + opengl3) | **ALL GREEN, 0 red** | **IDENTIQUE** |
| `SledProbe` (headless) | 3 red | **IDENTIQUE** — les trois rouges pixel du driver dummy, présents sur la base aussi |
| `ReverseProbe` phases CH42 (1 à 7) | ALL GREEN | **IDENTIQUE, ligne pour ligne** |

**Aucune trace ne diverge.** Là où CH42 avait dû expliquer 2 lignes de
différence sur le voilier, CH43 n'a rien à expliquer : le champ `reverse`
existait déjà, la branche qui le lit n'a pas bougé, et `YachtTraceProbe`
n'imprime pas ce champ — son second doigt au frame 230 n'écrivait rien
d'autre.

Les trois rouges headless de `SledProbe` sont le faux-rouge du driver dummy que
`CLAUDE.md` documente (« the sled paints 0 pixels », « the engine counter is
filled at all ») : mesurés sur la base **avant** toute modification, ils sont
identiques après. Sous `xvfb --rendering-driver opengl3`, la sonde est verte
des deux côtés.

## CH43-7 — La dette CH31 que CH42 avait rouverte, refermée

La ligne INDEX de CH42 se terminait par : « ⚠️ **DETTE** : le second doigt
écrit désormais `reverse` et **rien ne l'annonce** — le défaut CH31 de
l'accélérateur qui se rejoue ». CH43 la referme, parce que le geste qu'elle
concernait n'existe plus et que celui qui le remplace est annoncé :

* le rail de poussée passe désormais **À TRAVERS** l'ancre au lieu de s'y
  arrêter, avec une pointe de flèche à **chaque** bout qui s'efface quand sa
  propre moitié arrive ;
* le marqueur prend la couleur de la moitié où il est — chaud pour l'allure,
  froid pour le rapport (les deux sont exclusives à l'écrivain, donc il en lit
  une, jamais un mélange) ;
* la ligne d'aide nomme les deux directions.

`set_drive_readout` a pris un quatrième argument avec **0 par défaut**, donc un
appelant antérieur à l'axe dessine exactement le ghost qu'il dessinait.

## CH43-8 — Passes rouge-avant-vert

| neutralisation | rouges attendus | obtenus | autres |
|---|---|---|---|
| A — la branche gate à **0,9**, la constante lit toujours 0,3 | l'encadrement des 4 + le global + les 4 « branche frein » | **9** | aucun |
| B — **le garde-fou supprimé** : le rapport s'engage à toute vitesse | les 4 « les deux branches », les 4 encadrements, les 2 globaux, les 4 « branche frein » | **14** | aucun |
| C — `KartTouchInput` de CH42 **restauré verbatim depuis git** | les 8 assertions de geste | **8** | aucun — et c'est C qui a trouvé le faux-vert de la sonde |

Les trois fichiers restaurés et vérifiés **byte-identiques** (`cmp`).

## CH43-9 — Build

`--export-release "Web"` : **0 SCRIPT ERROR**. `index.wasm` **35 376 909**
octets, md5 `af4a8fc2925d992348eb30deeeb54360` ; `index.js` md5
`4e08904b1b7107858246af44b602067b` — les constantes d'identité que
`CLAUDE.md` publie pour un lot qui ne touche pas le code moteur. **Zéro** ligne
`Storing File: res://build/`.

---

# CH81 — Le kart perd la marche arrière, et lui seul

> Base `origin/staging` au commit `54c964a` (fin CH80), arbre
> `221122a53b98`. Garde de concurrence par **ARBRE** avant la première
> lecture : `origin/main` est en avance d'un seul commit de doc sur
> `staging` (`CLAUDE.md` + `docs/lots/INDEX.md`, la promotion CH78+79+80),
> `origin/staging` est ancêtre de la base ; la branche distante la plus
> récente est `quad-raptor-mesh-rebuild` (12 sept 09:33), déjà mergée dans
> `staging` — **aucune session concurrente**.
>
> Retour de Mathieu : sur le circuit, Keepy ne doit plus pouvoir reculer.
> **Aucun autre véhicule n'est concerné.** Ce lot ne rediscute pas le geste
> unique de CH43 et ne touche ni la physique de virage, ni l'accélération
> avant, ni le tracé.

## CH81-0 — La recon, et la situation réelle du code : (b), pas (a)

Le brief demandait de trancher entre « entièrement local au kart » et
« partiellement partagé » **avant** de choisir l'approche. La réponse est
**(b), et à trois niveaux** :

| niveau | ce qui est partagé |
|---|---|
| l'**écrivain** `KartTouchInput` | **DEUX instances** : celle de `HubKarting` (le kart) et **`"YachtTouch"` de `HubTransport`, qui écrit pour le char à voile, le voilier, la luge ET le quad** — un seul nœud pour quatre véhicules |
| le **champ** `KartInput.reverse` | écrit par cet écrivain, et par personne d'autre ; `KartAiDriver` appelle `set_all` à quatre arguments, donc `reverse` retombe sur son défaut 0 |
| le **consommateur** `VehicleDrive` | une branche `elif input.reverse > 0.0`, une instance par véhicule avec ses propres `reverse_speed` / `reverse_accel` (CH42 : « les quatre véhicules nomment leur propre rampe ») |

**Un branchement en dur « si c'est un kart » au milieu de `VehicleDrive`
était donc exclu, et le fichier partagé dit déjà quoi faire à sa place** :
`KartTouchInput` porte depuis CH31 des **valeurs d'instance** (`boost_span`,
`boost_dead_zone`, `boost_release_s`) et son en-tête dit pourquoi — « THESE
ARE INSTANCE VALUES, NOT CONSTANTS, AND THAT IS LOAD-BEARING ». Le lot ajoute
une quatrième valeur d'instance dans exactement le même moule.

⚠️ **L'autre voie a été écartée sur son mécanisme, pas par préférence.**
Mettre `KartBody.REVERSE_SPEED` à 0 aurait transformé le rapport en
**MAINTIEN-À-ZÉRO** et aurait atteint `input.brake` — la branche que
`KartAiDriver` presse avant chaque virage, et qui recule elle aussi sous
`REVERSE_ENGAGE_SPEED`. C'est-à-dire un nouvel état bloquant sur les trois
adversaires, ce que le brief interdit explicitement.

## CH81-1 — Ce qui est livré : une valeur d'instance, une ligne de câblage

```
KartTouchInput.allows_reverse : bool = true     # défaut = CH43 intact
HubKarting._ready()           : touch.allows_reverse = false
```

Le défaut **TRUE** est la moitié qui compte : l'instance de `HubTransport`
n'est pas configurée, donc les quatre véhicules gardent l'axe entier **sans
une ligne de leur côté**, et toute sonde qui construit une instance nue
(`YachtTraceProbe`, `CoveProbe`, `ReverseProbe` PHASE GESTURE) est
byte-identique à CH43.

Le garde est lu à **trois endroits, chacun un canal distinct et aucun
redondant** (la passe rouge le prouve, § CH81-4) :

1. `_apply_axis` — le pouce ;
2. le sondage clavier de `_physics_process` — DOWN / S / SPACE, ce qu'un
   probe et l'éditeur pilotent hors-web ; une divergence avec le pouce
   serait invisible depuis le device et verte sur le banc ;
3. `KartHud.set_reverse_available()` — la ligne d'aide et le ghost.

⚠️ **Le HUD est lui aussi partagé** (`HubTransport.setup()` reçoit « the
kart's HUD in its vehicle mode »), et sa ligne d'aide annonçait
« ↓ tirer pour reculer » **dans les deux modes**. Elle a désormais deux
orthographes et le coordinateur en choisit une **en lisant l'écrivain qu'il
possède** — jamais en la redisant. Le ghost suit : la piste verticale
**s'arrête à l'ancre** au lieu de la traverser (c'est l'argument de CH43
retourné : une piste qui nomme une moitié que le pouce ne peut pas
atteindre dessine un schéma que ce véhicule n'a pas) et la flèche du bas
n'est pas dessinée.

⚠️ **`_reverse_available` n'est PAS `_vehicle_mode`, et ne doit pas être lu
sur lui.** Le kart est le seul mode qui ne soit pas « vehicle mode », donc
aujourd'hui les deux drapeaux seraient d'accord — c'est exactement la forme
que la section « un état partagé n'est pas une permission partagée » de
`CLAUDE.md` décrit, et le prochain véhicule à perdre son rapport hériterait
de la mauvaise réponse.

## CH81-2 — Ce que le geste refusé fait : RIEN, et c'est mesuré

Le brief demandait, en cas de doute, de signaler les options plutôt que
d'en choisir une. Il n'y a pas de doute : le défaut du brief est déjà ce
que le code produit sans qu'on ajoute rien.

Un pouce sous l'ancre achète `boost = 0` — ce que `_fraction(0)` achète à
l'ancre de toute façon — et `throttle` reste à l'accélérateur automatique
**1,0**. Mesuré à travers le vrai canal (`ReverseProbe` PHASE LOCKOUT) : un
drag diagonal bas-et-à-droite maintenu donne `steer +1,0000`,
`reverse 0,0000`, `throttle 1,0000`. **Aucun frein, aucune roue libre,
aucun nouvel état.**

## CH81-3 — LE COÛT, MESURÉ AVANT DE RETIRER QUOI QUE CE SOIT

Le point 5 du brief demandait de signaler si la marche arrière servait de
filet de rattrapage. **Elle servait, et le chiffre est brutal.**

CH42 avait diagnostiqué le blocage sur la **LUGE**, contre les murs de
`HubRegion` qui refusent le pas. Le kart n'a pas ce mur : sa seule frontière
dure est `KartTrack.fence()` (x [−48,5 ; 48,5], z [−198,5 ; −135,5]), un
`Rect2` dont `VehicleDrive` **clampe** la position et **réfléchit** la
composante entrante à `FENCE_BOUNCE = 0,35`. Personne n'avait jamais mesuré
celui-là — `ReverseProbe` PHASE PIN / PHASE ESCAPE ne pilotent que la luge.
Le circuit ne porte par ailleurs **aucun collider** : hors piste n'est pas
un mur, c'est un plafond de vitesse (5,5 u/s) et moins de grip, et deux
karts sont séparés positionnellement chaque frame par `HubKarting._collide`.

Sonde **jetable** `KartPinRecon` (supprimée avant commit, `ProbeTimeoutAudit`
revenu à 103), scorée sur la **PREMIÈRE frame** à 4 u du départ — la leçon
CH42 : un braquage tenu dessine un cercle et un cercle finit où il commence.

| état du kart contre sa barrière | sans rapport | avec |
|---|---|---|
| **nez au mur à l'arrêt**, 26 stations (4 bords échantillonnés + 4 coins) × 2 braquages | **52 sur 52 n'atteignent jamais 4 u en 10 s** — excursion maximale **1,431 u** sur un bord, **0,424 u** dans un coin | 84–87 frames |
| **contact PILOTÉ**, lu à la frame du choc, 6 incidences × 2 braquages | 2 sur 12 | — |
| **contact piloté puis LAISSÉ SE STABILISER** (300 frames plein gaz) | **3 sur 12**, dont le cas **plein-axe dans LES DEUX SENS** (0,352 u en 10 s) | 84–197 frames |
| témoin : le même plein braquage **en terrain libre** | 55 frames (0,92 s), 9,55 u | — |

**Les trois lignes ne disent pas la même chose, et c'est le résultat.** La
réflexion de la barrière rend souvent un contact **piloté** échappable — ce
que le mur du hub ne fait jamais ; à 30° d'incidence et au-delà les deux
braquages libèrent le kart en 55 à 326 frames. Mais elle ne peut rien pour
un véhicule **ARRÊTÉ** contre elle : à 0° d'incidence la vitesse stabilisée
vaut **−0,0271 u/s**, le `|v_fwd|` moyen sur la fenêtre de blocage
**0,0128 u/s** contre un `STEER_FULL_SPEED` de 4,5, soit **0,28 % de plein
braquage** — et **l'accélérateur du kart étant AUTOMATIQUE, il n'existe
aucun geste pour cesser de pousser dans le mur**.

**La seule sortie restante est le bouton « ⤓ Descendre » du HUD**, qui est
toujours présent et rend le corps à pied — donc ce n'est pas un blocage de
l'application, c'est un **blocage de la course**. Signalé et **non corrigé** :
un plancher de braquage à vitesse nulle serait de la physique de virage, que
le brief gèle. **Décision à Mathieu** (§ NEXT STEPS du rapport).

⚠️ **Deux défauts d'INSTRUMENT dans cette recon, chacun avec l'allure d'un
résultat.** (1) La première PHASE ARRIVAL a rapporté « escaped: yes »
**12 fois sur 12** : elle roulait 120 frames vers un mur à 30 u avec un
plafond hors-piste de 5,5 u/s, soit **9 u** de trajet — chaque « arrivée »
tournait en terrain libre, 21 u avant la barrière. Le chiffre qui le disait
était imprimé à côté (`|v_fwd|` 3,9 à 12,3 u/s, c'est-à-dire un kart qui
roule librement) et personne ne l'a lu. C'est la règle CH69 « une grandeur
qui n'a de sens qu'APRÈS un événement passe gratuitement quand il n'a pas eu
lieu » : le contact est devenu un **événement ASSERTÉ** (la course continue
jusqu'à ce que le clamp écrive la coordonnée) et une station qui n'atteint
jamais le mur est imprimée `NOT REACHED` et comptée dans aucune colonne.
(2) La deuxième version mesurait la frame du choc et rendait 2/12, un coût
qu'on aurait appelé négligeable ; c'est la troisième lecture — l'arrêt — qui
donne le vrai chiffre.

## CH81-4 — Passes rouge-avant-vert : quatre, aucun garde redondant

| neutralisation | rouges prédits | obtenus | autres |
|---|---|---|---|
| **A** — `touch.allows_reverse = false` retiré de `HubKarting` (le câblage vivant) | 1 (le nœud vivant) | **1** | aucun |
| **B** — le garde de `_apply_axis` (le pouce) | 4 | **3** | ⚠️ **un rouge MANQUANT — et c'était un défaut de la sonde**, voir ci-dessous |
| **B′** — le même, après correction de la sonde | 4 | **5** | l'extra est la moitié `reverse` de l'assertion d'accélérateur, écrite en conjonction — prévisible, sous-comptée |
| **C** — le garde du sondage clavier | 3 | **3** | aucun |
| **D** — la bascule de la ligne d'aide du HUD | 2 | **2** | aucun |

**Aucune des quatre neutralisations ne recouvre une autre** : les trois
gardes gardent trois canaux distincts (pouce, clavier, écran) et le
quatrième est le câblage. C'est l'information que la règle CH79 demande de
publier **avant** qu'un lot futur en retire un.

⚠️ **LA PASSE B A TROUVÉ UN DÉFAUT DANS MA PROPRE SONDE, et c'est la
trouvaille du lot.** L'assertion « un drag diagonal bas-et-à-droite steer
encore et n'écrit pas de rapport » écrivait `-LOCKOUT_DRAG_PX` en y. Or
**vers le bas de l'écran est +y** : `_slide(t, dy)` prend la convention dy
(positif = haut) et la négationne lui-même, et les deux se sont mélangées.
L'assertion pilotait donc la moitié **ACCÉLÉRATEUR** en prétendant piloter
la moitié rapport — un **vert gratuit**, verte sur l'arbre livré comme sur
l'arbre neutralisé, avec un libellé qui mentait. Corrigée, elle rougit.

⚠️ **Et la même correction a fermé un second vert gratuit, du type que CH43
documente lui-même.** L'assertion `throttle == 1.0` relisait un 1,0 que
`_lockout_run` avait laissé **cent frames plus tôt** — « une assertion sur
une valeur tenue peut relire l'assertion précédente », commis dans la phase
même qui cite la règle. Elle porte désormais une **remise à zéro GATÉE**
(l'écrivain est vidé et le zéro est **asserté** avant le geste qui doit
l'écrire), puis appelle `_physics_process` explicitement.

## CH81-5 — La sonde : PHASE LOCKOUT, 22 assertions, tout par le canal du doigt

`ReverseProbe` passe de **129 à 151 assertions, 0 rouge**, et **aucune
assertion préexistante ne change de verdict** — les onze phases de
CH42/CH43 sont rejouées vertes sur l'arbre qui retire le rapport avant que
le rapport ne soit examiné, ce qui est l'ordre dans lequel `_run()` les
appelle.

Ce que PHASE LOCKOUT gate, et par quel canal :

* **l'A/B, même kart, même pose de grille, même geste, UN booléen d'écart.**
  « Aucune vitesse négative » est une assertion d'ABSENCE et passe
  gratuitement contre un banc incapable d'en produire une, donc le geste
  identique est joué dans le kart identique à travers deux écrivains :
  l'écrivain **PARTAGÉ** (la configuration des quatre véhicules) le mène à
  **−3,5000 u/s et −6,008 u en arrière**, celui du kart à **+0,0000 u/s au
  plus bas et +15,679 u en AVANT** à 12,2598 u/s. La paire est la mesure ;
  aucune des deux moitiés seule n'en est une. Et elle coupe dans les deux
  sens d'un seul run : le kart doit avancer, ce qui dit que le rapport est
  parti et pas l'axe.
* **la moitié haute et la moitié latérale survivent** sur l'écrivain du
  kart (boost 1,0000, steer +1,0000).
* **le clavier** : DOWN / S / SPACE écrivent 1,0000 sur l'écrivain partagé
  et 0,0000 sur celui du kart. `Input.flush_buffered_events()` est ce qui
  rend la lecture synchrone — `parse_input_event` ne fait que mettre en
  file, et lire l'état sans flusher aurait rendu un zéro qui ressemble à un
  refus.
* **les nœuds VIVANTS**, que l'A/B ne peut pas voir : tout le reste est
  mesuré sur des écrivains que la phase construit, ce qui prouve le
  mécanisme et non que le JEU l'a câblé (CH46 : sept marqueurs épinglés sur
  l'origine du monde étaient un mécanisme correct enregistré sur le mauvais
  nœud). `_karting.touch` (`"Touch"`) porte **false**, `_transport.touch`
  (`"YachtTouch"`) porte **true**, et ce sont **deux nœuds distincts**.
* **le HUD ne nomme pas une commande que l'écrivain refuse** : la ligne
  passe de « ↑ pousser pour foncer      ↓ tirer pour reculer » à
  « ↑ pousser pour foncer », avec un blind check dans l'autre sens.

⚠️ **PHASE GEAR garde sa ligne « kart », et son en-tête dit maintenant ce
qu'elle est.** Cette phase tend un `KartInput` **directement** au corps :
depuis ce lot elle ne dit plus rien des **commandes** du kart, elle dit que
la branche partagée de `VehicleDrive` marche toujours — ce qui est un chemin
vivant (trois véhicules au pouce, et `input.brake` à l'arrêt pour chaque
`KartAiDriver` de la grille). Elle est gardée pour exactement cette
régression. La lire comme « le kart a une marche arrière » serait le défaut
de fait périmé que `CLAUDE.md` existe pour empêcher.

## CH81-6 — Table croisée sur deux arbres

154 `.scn` importés des **deux** côtés (le chiffre CH80).

| sonde | driver | branche | `origin/staging` | verdict |
|---|---|---|---|---|
| `ReverseProbe` | headless | **151 ok / 0** | 129 ok / 0 | +22 assertions, aucune préexistante retournée |
| `KartTraceProbe` | headless | md5 `b6e1fa9c5e68` | md5 `b6e1fa9c5e68` | **byte-identique** — la conduite du kart est la même |
| `YachtTraceProbe` | headless | md5 `ceedfc85431c` | md5 `ceedfc85431c` | **byte-identique** — et sa trace EXERCE le rapport (0 → 1,0 à la frame 380) |
| `QuadProbe` | xvfb + opengl3 | 75 ok / 0 | (voir rapport) | le chiffre CH80 |
| `SledProbe` | xvfb + opengl3 | 72 ok / 1 | (voir rapport) | le rouge est le compteur de primitives |
| `SailBoatProbe` | headless | 42 ok / 0 | 42 ok / 0 | PASS |
| `CoveProbe` | headless | 178 / **2 FAIL** | 178 / **2 FAIL** | **parité exacte, mêmes deux lignes** — préexistant |
| `KartProbe` | headless | 150 / 0 PASS | 150 / **1 FAIL** | **un rouge PRÉEXISTANT sur `staging`**, et ce lot le rend vert par accident — § CH81-7 |
| `ProbeTimeoutAudit` | headless | **103 scènes, PASSED** | **103 scènes, PASSED** | parité exacte — la sonde jetable est bien supprimée |

## CH81-7 — ⚠️ UN ROUGE PRÉEXISTANT SUR `staging`, QUE CE LOT REND VERT PAR ACCIDENT

`KartProbe` sort **150 / 1 FAIL sur `origin/staging`** et **150 / 0 PASS sur
la branche**. Une divergence dans ce sens-là — la référence rouge, la
branche verte — se lit comme une bonne nouvelle, et c'est exactement pour ça
qu'elle a été retournée contre elle-même avant d'être crue : **deux runs de
chaque arbre, seuls, rien d'autre en charge**, et les quatre chiffres sont
identiques au dixième. Ce n'est donc pas de la charge machine.

L'assertion est `chrono panel centred (|centre − width/2| < 2 px)` :

| | base | branche |
|---|---|---|
| `_panel` | position (770, 150), **taille (414, 464)** | position (770, 150), **taille (380, 464)** |
| centre lu | **977,0** | **960,0** (= 1920 / 2, exactement centré) |

Le mécanisme, mesuré et non déduit : `_panel` est un `PanelContainer` ancré
`PRESET_CENTER_TOP`, posé à `−PANEL_WIDTH * 0.5` avec
`custom_minimum_size.x = PANEL_WIDTH = 380`. **Il n'est donc centré que si
son contenu ne dépasse pas 380 px** ; au-delà il grandit vers la DROITE
depuis sa position, et se décentre de `(largeur − 380) / 2`. Or l'enfant le
plus large de ce panneau est la **ligne d'aide de l'axe**, et la version
longue de CH43 (« ↑ pousser pour foncer      ↓ tirer pour reculer ») la
porte à **414**, soit **17 px** de décentrage. La version courte du kart
retombe à 380 et le panneau est centré.

Trois conséquences, et il faut les trois :

1. **C'est un défaut de CH43, pas de ce lot.** Le texte long est arrivé avec
   le geste unique et a décentré le panneau ; `KartProbe` est rouge sur
   `staging` depuis, et la table croisée de CH43 ne l'incluait pas.
2. **Ce lot ne le CORRIGE pas, il l'ESQUIVE sur un seul mode.** En mode
   véhicule (char à voile, voilier, luge, quad) la ligne reste longue, donc
   le panneau fait toujours 414 et reste décentré de 17 px. `KartProbe` ne
   teste que le mode kart, donc son vert ne dit rien de ce cas-là.
3. **Il n'est pas corrigé ici, et c'est un choix de périmètre.** Le HUD est
   partagé par cinq véhicules et validé device ; élargir `PANEL_WIDTH` ou
   changer l'ancrage déplacerait le panneau des quatre autres, ce que le
   brief gèle. Un vert obtenu par accident est rapporté comme un accident —
   ce qui est la seule chose qui empêche le prochain lot de croire que le
   centrage est réglé.
