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
