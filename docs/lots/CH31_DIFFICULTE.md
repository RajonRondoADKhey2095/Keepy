# CH31 — La course cesse d'être gagnée d'avance : référentiel réparé, plafond levé, accélérateur trouvable

> Lot cadré du 6 septembre 2026, seule session sur le dépôt, branche
> `claude/keepy-difficulty-rebalance-merrvy` repartie du HEAD réel de
> `origin/staging` (`e02b155`, CH30). `main` intouché. **Aucun personnage
> créé.** Aucun asset supprimé ni renommé.
>
> ⚠️ **La branche pointait sur l'arbre de `origin/main`** au démarrage
> (`0290e1d`), pas sur celui de `origin/staging` (`cee2c41`) — exactement
> ce que le brief annonçait. Constaté par comparaison d'ARBRES, jamais de
> noms, avant la première ligne de code.
>
> Retour de Mathieu : la conduite et la caméra du char à voile sont bonnes,
> mais la course est beaucoup trop facile — les trois adversaires sont
> doublés dès le premier virage, et il prend un tour d'avance sur trois
> tours. Il ajoute qu'il n'arrive pas à accélérer et ne sait pas si la
> commande existe.

## PRIORITÉ 0 — le référentiel était faux, et c'est le lot entier

Deux faits ne pouvaient pas être vrais ensemble : CH30 publiait un
**plancher de circuit de 21,633 s** présenté comme le tour le plus rapide
que ce véhicule puisse tourner ici, et Mathieu prenait un tour d'avance sur
une course de trois tours contre des adversaires à 23,4–25,7 s.

`RaceReconProbe` (sonde jetable, supprimée avant le commit) a pris les trois
hypothèses du brief **dans l'ordre, sans en privilégier aucune**.

### (c) — le banc ne joue pas la même chose : RÉFUTÉE

Phase 0, lue sur la scène réellement chargée :

```
scene            res://scenes/HubWorld.tscn
TRACK_ID         circuit_1            length 230,711 u sur 200 échantillons
HALF_WIDTH       5,00 u (+0,60 marge)     laps 3
steering preset  7/10 (steer_rate 1,550)  difficulty x1.5
racers           4, player index 0    chat / castor / sanglier
```

Même scène, même circuit, même plateau, mêmes profils. Rien à trouver de
ce côté. **Un fait est tout de même tombé au passage** : les décalages de
grille valent 5,00 / 5,60 / 6,20 / 6,80 u derrière la ligne pour les slots
0 à 3, et le joueur est l'entrée 0 — **il partait en POLE POSITION**, 1,8 u
devant le dernier adversaire, à chaque course.

### (b) — les IA n'atteignent pas en course ce qu'elles atteignent au banc : RÉFUTÉE

Phase D, chaque adversaire couru SEUL puis dans le peloton, même graine :

| adversaire | peloton (laisse) | peloton (sans laisse) | seul | coût du peloton |
|---|---|---|---|---|
| Le Chat | 23,350 | 23,317 | 23,200 | **+0,117 s** |
| Le Castor | 25,667 | 25,733 | 25,750 | −0,017 s |
| Le Sanglier | 25,700 | 25,833 | 26,400 | −0,567 s |

Le peloton coûte au plus 0,117 s de meilleur tour, et la laisse au plus
0,13 s. **Le rubber-band est inerte, mesuré une seconde fois** (CH30 le
disait déjà ; il n'est toujours pas un levier, et ce lot ne le vend pas
comme tel).

Au passage, le banc a **reproduit sa propre table CH30** au frame près —
chat 23,350, castor 25,667, sanglier 25,700 contre 25,733 publié — ce qui
lui donnait le droit de publier un chiffre neuf (CLAUDE.md : reproduire
d'abord un chiffre déjà au dossier).

### (a) — le pilote de référence du banc est lent : **CONFIRMÉE**, et c'était un problème d'ÉTALON

Le chiffre qui tranche tient en une ligne du même tableau :

```
pilote de référence (human_ref), meilleur tour dans le peloton : 24,400 s
```

**L'étalon censé mesurer la course tournait plus lentement que le chat
qu'il mesurait.** `human_ref` et `limit_ref` sont deux profils de
`KartAiDriver` : le MÊME contrôleur que les adversaires, avec le MÊME
profil de vitesse. Un banc dont l'étalon est membre du peloton ne peut pas
voir que le peloton est lent — et c'est exactement pourquoi toutes les
tables de CH30 étaient vertes pendant que la course se gagnait d'un tour.

### Le plafond : le profil de vitesse était construit sur la SPINE

Phase A, échantillon par échantillon, ce qui borne chaque pilote :

| profil | n_top | n_pneus | n_braquage | v_min | tour théorique |
|---|---|---|---|---|---|
| chat | 64 | 129 | 7 | **4,17** | 20,318 s |
| castor | 44 | 154 | 2 | **4,17** | 22,226 s |
| sanglier | 28 | 171 | 1 | **4,17** | 23,396 s |
| human_ref | 41 | 157 | 2 | **4,17** | 21,339 s |
| limit_ref | 98 | 0 | 102 | **4,17** | 17,637 s |

**Tout le plateau est épinglé au même 4,17 u/s à l'oméga**, y compris le
profil dont les pneus ne lâchent jamais (`a_lat` 40). La cause : le profil
de vitesse était bâti sur la courbure de la **SPINE** (rayon 3,396 u)
pendant que le pilote roulait sur une ligne décalée jusqu'à 3,9 u — sur un
ruban de 10 u, ce n'est pas une petite approximation.

### Le plancher re-dérivé, et il est PILOTÉ

La première tentative a été une ligne de courbure minimale relaxée dans le
couloir. **Elle a été jetée, et la raison mérite d'être écrite** : minimiser
`Σ|Δ²P|²` pondère un virage par `ds⁴`, et `ds` est le PLUS PETIT exactement
là où le virage est le plus serré. 12 000 balayages ont déplacé le rayon
minimal de 3,396 à 3,371 u — **dans le mauvais sens**. Un objectif qui ne
regarde pas le virage n'est pas un instrument.

Ce qui l'a remplacée est la question elle-même : **piloter** le circuit avec
le profil multiplié par `f`, et chercher le plus grand `f` qui tient encore
le ruban.

```
f      meilleur tour   hors-piste   |lat| max   verdict
1,00   19,533          0,00 %       3,600       sur le ruban
1,10   18,917          0,00 %       3,930       sur le ruban
1,20   18,583          0,00 %       4,738       sur le ruban
1,30   19,450          8,06 %       6,397       DEHORS
...
PLANCHER PILOTÉ : 18,583 s (à f = 1,20).  Plein gaz sur cette longueur : 12,111 s.
CH30 publiait ce plancher à 21,633 s.
```

## PRIORITÉ 0 (suite) — l'étalon réparé

`HumanRefDriver` (`scripts/dev`) remplace le profil `human_ref`. Il n'est
délibérément **pas** un meilleur `KartAiDriver` : il est un modèle de
pouce, faux dans les deux sens.

* **PIRE** — il voit ~1,15 s de piste devant lui, pas le tour entier ; il
  décide **9 fois par seconde**, pas soixante ; sa visée porte un bruit
  gaussien (σ 0,55 u) et son braquage aussi (σ 0,085) ; et ses commandes
  arrivent en retard.
* **MIEUX** — il n'obéit à aucun profil de vitesse par échantillon. Il
  emmène de la vitesse en virage et laisse le kart glisser, parce que ce
  kart pardonne.

⚠️ **La latence est tirée une fois PAR RUN**, `N(0,135 ; 0,035)` s bornée à
[0,060 ; 0,280] : la latence d'un joueur est une propriété de ses mains et
de son téléphone, et la re-tirer chaque frame la moyennerait — c'est
précisément comme ça qu'un banc cesse de voir la latence.

**n = 320 runs par population**, publié en distribution :

| population | p10 | p50 | p90 | moyenne | σ | pointe | hors-piste |
|---|---|---|---|---|---|---|---|
| propre, **utilise le boost** | 19,033 | **20,350** | 21,950 | 20,440 | 1,220 | 17,40 | 20,93 % |
| propre, **n'accélère JAMAIS** (Mathieu avant ce lot) | 20,900 | **21,633** | 22,417 | 21,670 | 0,611 | 13,94 | 5,02 % |
| ordinaire, utilise le boost | 19,050 | 20,417 | 22,133 | 20,558 | 1,271 | 17,40 | 21,09 % |
| **(témoin) latence à ZÉRO** | 18,667 | **18,967** | 19,133 | 18,906 | 0,334 | 17,11 | 16,68 % |

Latence moyenne réellement tirée : **0,1332 s**. Le témoin est le **blind
check B** : couper la ligne à retard change la médiane de **1,38 s**, donc
la latence est bien câblée. Sans ce contrôle, tout chiffre produit par cet
étalon passerait gratuitement contre un modèle dont le retard n'aurait
jamais été branché.

⚠️ **Ce que l'étalon réparé dit du « tour d'avance ».** Avec ce modèle, le
déficit du dernier adversaire à l'arrivée valait **0,39 tour** sur l'ancien
plateau, pas un tour entier. Un tour littéral demanderait un tour humain
sous 17 s, c'est-à-dire **sous le plancher piloté du circuit**. La
formulation de Mathieu décrit donc « je gagne largement, contre les deux
derniers surtout » plutôt qu'un tour au sens strict — et le lot vise la
sensation, pas la lettre : D4 gate le déficit à 0,80 tour.

## PRIORITÉ 1a — le plafond, puis l'agressivité, chiffrés séparément

### Le profil est bâti sur la ligne réellement suivie

`KartAiDriver._build_line()` calcule le **plan** — le décalage latéral que
la personnalité vise, échantillon par échantillon — puis construit le
profil sur la **courbure et la longueur d'arc de CE polyligne**. La passe
arrière intègre la bonne longueur : une ligne intérieure est plus courte,
et une distance de freinage mesurée sur la mauvaise longueur freine au
mauvais endroit.

Le plan doit être **atteignable** : `LANE_RATE` vaut 2,6 u/s, donc un plan
qui sauterait d'une ligne à l'autre entre deux échantillons promettrait un
rayon que le pilote ne tiendra jamais. Le lissage a été **mesuré, pas
choisi** (meilleur tour adverse) :

| passes de lissage | meilleur tour adverse |
|---|---|
| 0 | **31,150 s** — le plan zigzague, le pilote ralentit pour son propre slalom |
| **12** | **22,767 s** |
| 40 | 23,250 s — le décalage de virage est étalé dans l'approche |

⚠️ **Et ce correctif n'est PAS le levier de difficulté.** La passe rouge
qui le neutralise (le plan écrasé sur la spine) laisse les presets ordonnés
et séparés, avec des tours ~0,7 s plus lents. C'est une **correction de
justesse** qui vaut ~0,7 s au tour, pas ce qui rend la course difficile.
Le dire est le résultat.

⚠️ **`corner_bias` a dû être re-réglé, et c'est une conséquence directe.**
Sous l'ancien profil bâti sur la spine, un balancement de ligne était
**gratuit** : le profil ne le voyait pas. Il ne l'est plus. Le sanglier à
1,1 lisait **plus lent que le chat sur le quart le plus droit du tour**
(15,516 contre 16,139) — l'inverse de sa personnalité. 1,1 → 0,70 et
−0,9 → −0,75 ; les signes et l'ordre ne bougent pas, le balancement n'est
simplement plus un slalom. `a_lat` du sanglier 4,6 → 5,2 pour la même
raison (la passe arrière propage désormais son manque d'adhérence plus
loin, et il se retrouvait à 3,4 s du chat au lieu des 2,1 s de CH30).

### La table, reconstruite et non décalée

⚠️ **`top` porte la plus grosse échelle, et ce n'est pas un goût.** `top`
est un **plafond dur** appliqué après tout le reste
(`min(top, min(v_pneus, v_braquage) · pace)`) : une personnalité à `top`
bas ne peut être accélérée par **aucune** quantité de `pace`. Mesuré, et
c'est ce qui a tué la première table CH31 : le `top` de base du chat vaut
0,35, donc passer `pace` de 1,20 à 1,38 a déplacé son tour de **−0,05 s**.
L'échelle lève donc le PLAFOND d'abord et la vitesse en virage ensuite,
dans l'ordre que l'arithmétique impose.

| preset | `pace` | `top` | `headroom` | `bias` | `a_lat` | `a_brake` | `wobble` | `fault` | laisse |
|---|---|---|---|---|---|---|---|---|---|
| **x1** | 1,05 | 1,00 | 1,00 | 1,00 | 1,00 | 1,00 | 1,00 | 1,00 | 0,93 / 1,05 |
| **x1.5** (DÉFAUT) | 1,30 | 1,60 | 0,96 | 1,05 | 1,12 | 1,12 | 0,72 | 0,55 | 0,97 / 1,08 |
| **x2.5** | 1,45 | 2,10 | 0,95 | 1,10 | 1,22 | 1,25 | 0,55 | 0,35 | 1,00 / 1,11 |

**Vitesse et agressivité sont deux colonnes différentes** : `pace` et `top`
sont l'allure ; `headroom` (l'autorité de braquage gardée en réserve),
`bias` (la corde plus serrée), `a_brake` (le freinage plus tardif) et
`wobble` / `fault` (moins de fautes) sont l'agressivité.

### Temps au tour mesurés, meilleur de deux graines par preset

⚠️ **DEUX GRAINES, parce qu'une course est un instrument bruité.** La
première calibration a lu x1 comme **plus rapide** que x1.5 sur une course
unique où le chat avait eu un tour propre d'un côté et une faute de
l'autre. Un contrat d'ordonnancement ne se décide pas sur un coup de dé.

| | x1 | x1.5 (défaut) | x2.5 |
|---|---|---|---|
| Le Chat | **21,917** — 23,133 / 21,933 / 21,917 | **20,000** — 22,033 / 20,467 / 20,000 | **19,467** — 20,833 / 20,683 / 19,467 |
| Le Castor | **24,867** — 25,117 / 25,167 / 24,867 | **21,833** — 22,467 / 21,833 / 21,917 | **20,100** — 20,667 / 20,133 / 20,100 |
| Le Sanglier | **24,900** — 24,950 / 26,100 / 24,900 | **21,500** — 22,333 / 21,500 / 22,183 | **20,717** — 20,800 / 20,717 / 20,867 |
| pointes réelles | 15,43 / 15,84 / 17,09 | 16,28 / 16,58 / 17,31 | 16,67 / 17,53 / 17,25 |
| arrivée de l'étalon | 68,800 (**2ᵉ**) | 65,317 (**4ᵉ**) | 63,650 (**4ᵉ**) |
| écart entre presets | — | **1,917 s/tour** | **0,533 s/tour** |

Contre CH30 (23,350 / 25,667 / 25,733 au défaut), le défaut gagne **3,3 à
4,2 s au tour** selon l'adversaire, soit une dizaine de secondes sur trois
tours. **L'étalon finit 4ᵉ au preset par défaut** : la victoire se mérite.

### Le départ ne sera plus gratuit

`HubKarting.grid_slot()` inverse le plateau : le joueur, entrée 0, est
placé sur le **dernier** slot au lieu de la pole. La géométrie de grille
reste un fait de `KartTrack` ; l'ordre d'installation est un fait de la
course, et il est **publié par un accesseur** — `KartProbe` supposait
l'identité et le lit désormais.

## PRIORITÉ 1b — l'accélérateur : il EXISTAIT

**Réponse de recon, telle quelle : oui, une commande de gaz existait avant
ce lot.** C'est le boost V7b — pousser le doigt-ancre vers le HAUT de
l'écran, avec une ligne d'aide dans le HUD et un fantôme. Trois défauts
l'ont rendue introuvable, et les trois sont des défauts, pas des goûts :

1. **L'affordance n'apparaissait qu'une fois le doigt déjà posé** — le
   fantôme est dessiné depuis `_ghost_active`. Un joueur qui n'a pas encore
   touché l'écran ne voyait rien.
2. **Lever le doigt la tuait.** Le schéma dit lui-même au joueur que lever
   le doigt redresse les roues — c'est ce qu'on fait en ligne droite, et la
   ligne droite est exactement l'endroit où le boost vaut quelque chose. Le
   geste naturel annulait la mécanique.
3. **La poussée coûtait cher** : 150 px de course en plus d'un drag de
   direction, avec 24 px de zone morte.

Livré : une **jauge permanente** sur le côté droit, dessinée pendant toute
la conduite — vide c'est une invitation, pleine c'est un retour, et elle
n'a besoin d'aucune phrase ; une **flèche** en tête de la piste de poussée
qui s'efface à mesure que la poussée arrive ; le relâchement qui **décroît
sur 0,45 s** au lieu de disparaître ; et la course ramenée à 105 px avec
14 px de zone morte. La jauge se remplit à la **VITESSE**, pas au boost :
une barre qui ne bougerait qu'avec le pouce dirait « tu pousses », et ce
qu'un pilote veut lire est « tu vas plus vite ». Le trait marque où finit
la croisière et où commence la poussée.

⚠️ **Ces valeurs sont des propriétés d'INSTANCE, et c'est porteur.** Le
char à voile est piloté par un SECOND `KartTouchInput`. Les constantes de
classe restent les valeurs V7b livrées, `HubKarting` configure la sienne,
`HubTransport` ne configure rien — donc l'instance du char est identique à
ce qu'elle était. `YachtTraceProbe` le prouve par trace comparative plutôt
que par relecture de diff, avec un **blind check** : la même gestuelle
rejouée avec les valeurs du kart DOIT donner une trace différente.

## PRIORITÉ 1c — la vitesse générale, et sa borne

`KartBody.MAX_SPEED` 13,0 → **15,0** ; `BOOST_MAX_SPEED` 16,5 → **19,05**
(le même rapport 1,27). Balayé avec l'étalon, n = 40 par point :

| croisière / boost | discipliné p50 (hors-piste) | qui pousse p50 (hors-piste) |
|---|---|---|
| 13,0 / 16,51 | 22,750 s (0,00 %) | 20,033 s (9,20 %) |
| 14,5 / 18,41 | 22,317 s (5,02 %) | 20,533 s (20,21 %) |
| **15,0 / 19,05** | **21,700 s (5,05 %)** | 20,620 s (21,63 %) |
| 16,0 / 20,32 | 20,467 s (6,86 %) | **20,917 s (25,88 %)** |

⚠️ **LA BORNE EST À 16 u/s, ET ELLE SE LIT COMME UN CROISEMENT.** À 16,0 le
pilote qui POUSSE tourne **plus lentement** que le discipliné (20,917 contre
20,467) en passant un quart du tour hors du ruban : au-delà, la vitesse
supplémentaire n'est plus convertie en temps au tour, elle est dépensée à
partir large. 15,0 est la dernière valeur où pousser paie encore et où la
bande disciplinée reste serrée (σ 0,529 s).

⚠️ **Et monter le PLAFOND DE BOOST seul n'est pas un levier de vitesse.** À
croisière 13,0, passer le plafond de 16,51 à 18,20 a déplacé la médiane de
**+0,10 s — dans le mauvais sens** — en doublant la part hors-piste
(9,20 % → 18,79 %). Le kart ne sait déjà pas utiliser 16,5 partout.

`KartTrack.TRACK_ID` passe de `circuit_1` à **`circuit_1b`** : le meilleur
tour persistant est indexé par cette chaîne, donc un record posé à 13 u/s
ne reste pas à côté de ceux posés à 15. **Rien n'est invalidé** — l'ancienne
clé reste dans la sauvegarde, intacte.

## Le relevé de fin de course

Derrière `?keepydev=1`, chaque ligne porte maintenant, par concurrent : le
profil, les trois temps au tour, la **moyenne**, la **pointe réellement
atteinte**, le **temps passé en contact** avec un autre kart, et l'écart au
vainqueur. `HubKarting` accumule ces compteurs pendant la course
(`top_speed`, `contact_s`, `off_s`, remis à zéro à chaque mise en grille) et
`results()` les publie. Un retour de Mathieu peut être un tableau.

## Ce que la sonde gate — 22 checks, et deux d'entre eux ont été réécrits

`RaceBalanceProbe` : blind A (le bouton change la course), **blind B (la
latence est câblée)**, blind C (le plancher est bien sous chaque tour
adverse), D1 (au défaut, le meilleur adversaire tourne à moins de 1,20 s de
la médiane de l'étalon — mesuré à **−0,117 s**), D2 (ordonnés et séparés
d'au moins 0,45 s), D3 (les personnalités survivent), D4 (aucun adversaire à
plus de 0,80 tour au drapeau), D5, D6.

⚠️ **D1 est mesuré contre la population qui UTILISE l'accélérateur**, pas
contre celle qui ne l'utilise jamais. La seconde décrit Mathieu **avant** ce
lot ; calibrer dessus construirait une course qui se ramollit le jour où il
trouve la pédale.

### Passes rouges — et l'une d'elles a trouvé un garde qui passait gratuitement

| ce qui a été neutralisé | attendu | obtenu |
|---|---|---|
| le plan écrasé sur la spine (le plafond) | des tours plus lents | 22,633 / 20,800 / 19,817, **tous les gates verts** — donc ce correctif vaut ~0,7 s et n'est pas le levier |
| toutes les échelles de difficulté à 1,0 + joueur en pole | blind A et D2 rouges | **4 rouges, exactement ceux-là** |
| `pace` à 0,55 sur les trois presets | D4 rouge | **D4 rouge à 1,156 tour** — le symptôme « un tour d'avance » reproduit et gaté |

⚠️ **D5 EST PASSÉ VERT AVEC LE CORRECTIF NEUTRALISÉ, et il a fallu le
réécrire.** Sa première forme vérifiait que l'étalon n'est pas EN TÊTE six
secondes après l'extinction des feux. Elle est restée verte avec le joueur
remis en pole, pour une raison évidente après coup : les IA sont parfaites
au feu vert et ce modèle ne l'est pas, donc il est quatrième depuis
n'importe quel slot. Le check ne savait pas distinguer les deux grilles —
la définition d'une assertion qui ne prouve rien. Ce qui est asserté
maintenant est le fait structurel que le lot a changé : le joueur est
installé sur le **dernier** slot. Le rang à six secondes reste **publié,
non gaté**, avec la raison écrite à côté. *(À la passe rouge n° 3, ce rang
publié valait **1 sur 4** — « il double les trois dans le premier virage »,
reproduit.)*

⚠️ **D6 est né d'un échec de blind C.** La première version de x2.5
(`pace` 1,55) faisait tourner au chat un **18,467 s**, sous le plancher
piloté — en passant **131 frames hors du ruban**. Un adversaire qui achète
son temps sur l'herbe n'est pas plus fort, il est cassé, et un temps au tour
seul ne le voit pas. x2.5 a été ramené à `pace` 1,45 / `headroom` 0,95 /
`top` 2,10, et D6 gate désormais la part hors-piste de chaque adversaire à
1,5 % de sa course (mesurée à **0,00 %** aux trois presets).

## Mesures, dans l'ordre

| | |
|---|---|
| hypothèse retenue | **(a)**, l'étalon était membre du peloton |
| étalon CH30 (`human_ref`) contre le chat qu'il mesurait | **24,400 s contre 23,350 s** |
| borne dure trouvée à l'oméga, tout profil confondu | **4,17 u/s** (profil bâti sur la spine) |
| plancher CH30 → plancher piloté re-dérivé | 21,633 s → **18,583 s** (à f = 1,20) |
| plein gaz sur 230,711 u | 12,111 s |
| étalon réparé, n = 320 — sans boost / avec boost | p50 **21,633 s** / **20,350 s** |
| effet de la latence sur la médiane (blind B) | **1,383 s** |
| meilleur tour adverse x1 / x1.5 / x2.5 | **21,917 / 20,000 / 19,467 s** |
| gain du défaut contre CH30, par adversaire | **3,3 à 4,2 s au tour** |
| écart au tour entre presets | **1,917 s** puis **0,533 s** |
| déficit du dernier adversaire au drapeau (défaut) | **0,075 tour** (gate 0,80) |
| coût du peloton / de la laisse | **≤ 0,117 s** / **≤ 0,13 s** |
| croisière et plafond de boost | 13,0 → **15,0** ; 16,5 → **19,05** |
| borne de lisibilité mesurée | **16 u/s** (le pilote qui pousse devient plus lent) |
| position de départ du joueur | pole → **dernier slot** |
| commande de gaz avant ce lot | **elle existait** (boost V7b), introuvable |
