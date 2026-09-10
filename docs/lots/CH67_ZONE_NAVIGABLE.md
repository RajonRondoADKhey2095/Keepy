# CH67 — La zone navigable du hub s'élargit, la limite devient lisible, et les obstacles quittent les lignes de course

*10 septembre 2026. Branche `claude/hub-zone-bowl-physics-icsoys`, basée sur
`origin/staging` `831db2e` (CH66, arbre `7c407ae`). Garde de concurrence par
ARBRE : aucune branche distante plus récente que `staging` ;
`claude/diagnostic-bol-fps-ai8hv1` (9 sept) n'est ancêtre ni de `main` ni de
`staging` et ne porte que des scripts de diagnostic remplacés.*

> Trois chantiers au brief. Les DEUX PREMIERS sont livrés et verts. Le
> TROISIÈME — le bol enfin physique — a été construit, prouvé, puis
> **retiré sur une mesure**, et la section 4 dit laquelle. Le brief
> l'autorisait explicitement (« si après mesure le bol ne peut pas être
> fait proprement, le laisser sans collider et l'expliquer avec les
> chiffres »).

## Section 1 — CHANTIER 1 : la zone, et le chiffre qui la cape

### 1.1 — Ce que la plainte était, mesuré

Mathieu, device, sur la planche : « il faut étendre la zone et pousser le
skatepark le plus loin possible — je suis bloqué parce que la zone
s'arrête. » Mesuré sur l'arbre livré, avant que rien ne bouge :

| ce qui a été mesuré | valeur |
|---|---|
| course libre au NORD depuis le centre du park, sur l'axe | **13,10 u** |
| la même aux coins de la dalle (x ± 10) | **11,20 u** |
| course libre au SUD | 85,10 u |
| **place de parking de la planche (3 ; 60) → bord du lobe** | **2,84 u** |
| run-up du modèle (`SKATE_ACCEL_U`) | 3,20 u |

Le dernier couple est la plainte entière : **la planche est garée à 2,84 u
d'un mur et son run-up en demande 3,20**. Un joueur qui monte et tient son
pouce vers le nord est arrêté par `SkateBoardBody._fence` — qui REFUSE le
pas ET EFFACE LA CIBLE — avant même d'avoir fini d'accélérer. Et le côté
court est celui dont le park se sert : le grand quarterpipe (yaw 0) se
monte en roulant vers le NORD par construction, et jette sa retombée au
nord de nouveau.

### 1.2 — CE QU'IL Y A AU-DELÀ, vérifié AVANT de repousser quoi que ce soit

Le brief le demandait explicitement, et la réponse est que rien ne manque :

* le sol DESSINÉ est un `PlaneMesh` **600 × 600** centré à l'origine, soit
  x et z de −300 à +300 — il n'y a aucun vide, aucun bord de monde, rien à
  construire ;
* `HubSurface` ne porte qu'**un seul domaine** (la crête ouest, AABB
  x [−63, −35] / z [−12, 18]) : sur tout l'axe nord la hauteur lue vaut
  **0,000** à z = 55, 60, 63, 66, 70, 80 et 100 ;
* le tapis (`CozyScatter.COVER_MAX.y`) et le mur d'arbres
  (`CozyScatter.WALL_NEAR_Z`) sont tous deux DÉRIVÉS du rayon du lobe
  (+0 et +5), donc ils suivent l'élargissement sans édition.

Il n'y avait donc rien à cacher derrière la limite : elle était fixée par
le BUDGET DE TRAVERSÉE, pas par le terrain.

### 1.3 — LE RAYON, BALAYÉ ET MARCHÉ

`HubRegion.SKATE_LOBE_RADIUS` **28 → 36**. Chaque ligne est une traversée
MARCHÉE sur le vrai hopper à `--fixed-fps 60`, et chaque run reproduit
d'abord la diagonale publiée (66 hops / 18,700 s) — un banc incapable de
restituer un chiffre du dossier n'a pas qualité à en publier un neuf. La
paire est chaque coin du hub contre le point du disque **le plus éloigné
DE CE COIN**, jamais la pointe +Z :

| r | portée | pire paire | marchée | verdict |
|---|---|---|---|---|
| 28 | z 63 | (−63,−12) → (22,44 ; 51,74) 106,600 u | 20,117 s | livré |
| 32 | z 67 | 110,600 u | 20,967 s | égalité EXACTE avec CH38 |
| 34 | z 69 | 112,600 u | 21,250 s | |
| **36** | **z 71** | (−63,−12) → (28,85 ; 56,53) 114,600 u | **21,817 s** | **retenu** |
| 38 | z 73 | 116,600 u | **22,100 s** | AU-DESSUS de 22, refusé |

**22,100 s est exactement le chiffre que la recon du lot D avait refusé
pour un demi-côté de 41** — le contrôle de sanité du banc, pas une
coïncidence. Le plafond est donc entre 36 et 38, et 36 est le dernier
rayon rond en dessous, avec **0,183 s — un hop — de marge**.

⚠️ **CE QUE ÇA COÛTE, ET CE N'EST PAS RIEN.** La pire traversée du hub
n'est plus celle de CH38 : ce disque lui PREND le titre (21,817 s contre
20,967 s), là où CH50 était délibérément resté deuxième. C'est un vrai
changement du pire cas du hub ; il est énoncé plutôt qu'enterré, et
`SkateTraverseProbe` PHASE X le marche à chaque run contre le budget.

**Après** : la course nord passe de 13,10 à **21,00 u** sur l'axe (19,58 u
au pire coin de la dalle), et la place de parking a **10,87 u** devant elle
au lieu de 2,84.

### 1.4 — LA LIMITE DEVIENT LISIBLE, et c'était la vraie plainte

Une région plus large s'arrête quand même quelque part, et `_fence` l'a
toujours arrêtée en refusant le pas — un mur invisible. Le hub a partout
ailleurs un mur d'arbres, mais il se tient `WALL_CLEARANCE` (2 u) au-delà
du bord et c'est un semis aléatoire : sur le seul bord qu'un véhicule
rencontre à la croisière, rien sous les yeux du rider ne dit « c'est ici
que ça s'arrête ».

**Un liseré est PEINT dans `cozy_ground.gdshader`**, pas construit : un
anneau à r 35,5 fait 113 u d'arc, ce qui serait des centaines de triangles
et un draw call sur la frame que ce lot charge déjà. Peint, c'est **zéro
primitive et zéro draw call** — l'argument qui a mis les rangs de lavande
et les bandes de tonte dans ce même fichier. Il n'est peint que sur la
moitié du disque qui EST le bord de la région (z ≥ le z du centre).

⚠️ **LA TEINTE A ÉTÉ CHOISIE EN LUMINANCE, ET LE PREMIER CHOIX A ÉTÉ
REFUSÉ PAR L'ARITHMÉTIQUE.** Un liseré de béton PÂLE paraissait évident.
Mesuré contre les trois verts du sol (L 0,4717 / 0,3509 / 0,5628) :

| candidat | L | ratios contre les trois verts |
|---|---|---|
| béton pâle (0,86 ; 0,84 ; 0,78) | 0,6742 | 1,39 / 1,81 / **1,18** |
| presque blanc (0,93 ; 0,92 ; 0,86) | 0,8235 | 1,67 / 2,18 / **1,43** |
| **terre battue (0,36 ; 0,31 ; 0,26)** | 0,0826 | **3,93 / 3,02 / 4,62** |

Un liseré pâle lit **1,18:1 contre `GRASS_C`** : il DISPARAÎT sur chaque
tache claire du tapis — la « bande morte » que ce dépôt paie depuis la
palette. Le sombre franchit 3:1 contre les trois.

Et **ce n'est pas cet argument qui gate** : `SkateEdgeProbe` PHASE K lit
des PIXELS, parce qu'un ton est une affirmation sur une couleur et que
seul un compte de pixels est une affirmation sur la frame.

## Section 2 — CHANTIER 2 : la balançoire et l'ourson quittent les lignes

Retour device : « la balançoire et l'ourson bloquent le passage pour faire
des tricks ». Mesuré plutôt que cru. Le **couloir de course** du park est
sa dalle (x [−10, 10], z [41, 59]) élargie du run-up qu'un rider demande —
10 u au nord et au sud (le protocole device de CH66 demande ~8 u avant le
grand quarterpipe, qui se monte vers le NORD, et la grande rampe rejette
sa retombée au nord), et 2 u de côté (les modules tiennent dans
x [−7,7 ; 8,0] : un rider dérive, il ne traverse pas le lobe). Soit
**x [−12, 12], z [31, 69]** — et la balançoire était à (0 ; 38,5), sur son
axe central, avec l'ours 1,5 u devant elle.

**L'AUDIT COMPLET DU COULOIR** (le brief le demandait pour tout ce qui
empiète, déplacé ou non) : **15 empreintes publiées** y tiennent, dont
**6 sont le park lui-même** (funbox, rail, les deux quarterpipes, le bol,
la dalle) et une la planche garée. Restent **la balançoire** et
**sept props de décor** — (−7,20 ; 31,18) r 1,66 ; (6,64 ; 32,68) r 0,17 ;
(−5,18 ; 38,43) r 0,38 ; (−6,77 ; 39,83) r 0,59 ; (−3,13 ; 42,87) r 0,23 ;
(−4,01 ; 44,33) r 0,18 ; (−2,28 ; 44,39) r 0,19 ; (6,76 ; 40,36) r 0,49.
**Ils ne sont PAS déplacés par ce lot** (aucun n'a de collider — D2 : le
décor n'est solide nulle part — et Mathieu n'a nommé que les deux), mais
trois d'entre eux sont à moins d'un mètre de la ligne d'approche du grand
quarterpipe (x ≈ −4,2) et c'est signalé en NEXT STEPS.

### Le site, scanné contre QUATRE contraintes à la fois

⚠️ **ET LE PREMIER SITE, CHOISI SUR LE DÉGAGEMENT SEUL, NE MARCHAIT PAS.**
(15 ; 36) était le meilleur des candidats sur ce critère (6,840 u) — et le
balayage du trajet de l'ours vers le feu en est revenu avec **AUCUN AZIMUT
VALIDE** : chaque segment vers le foyer croisait un prop. Ce point n'est
pas seulement là où l'ours SE TIENT, c'est là où sa marche COMMENCE. Le
scan a donc été refait sur les quatre contraintes ensemble : hors couloir,
dégagé de chaque empreinte publiée, dans la région pour la balançoire ET
pour l'ours, et un azimut de feu encore atteignable. **133 sites passent ;
101 gardent une marge de trajet au moins égale à la marge livrée
(0,9628 u)**, et **(18 ; 44)** est le plus proche d'entre eux avec de la
place des deux côtés :

| site | dans le couloir | dégagement | marge du trajet ours |
|---|---|---|---|
| (0 ; 38,5) — aujourd'hui | OUI, c'est L'obstruction | — | 0,9628 u |
| (−16 ; 38,5) | non | 1,669 u (la cabane réserve 8,8) | — |
| (−15 ; 34) | non | **−2,443 u** (dans la cabane) | — |
| (15 ; 36) | non | 6,840 u | **aucun azimut** |
| **(18 ; 44)** | **non** | **6,744 u** | **1,870 u** |

`BEAR_REST` suit à **(18 ; 42,5)**, le même 1,5 u derrière le pivot, et le
littéral est GATÉ contre la balançoire telle que construite (régime des
centres de lacs). Les deux constantes de l'ours qui sont des FONCTIONS de
ce point ont été re-dérivées, pas re-réglées :

* **`BEAR_CAMPFIRE_WALK_RATE` 2,9768 → 1,9957.** La jambe aller de l'ours
  passe de 22,9304 u à 15,3734 u (il part maintenant à l'est du feu et non
  plein nord), donc le taux qui la couvre dans les 10,1947 s du blaireau
  baisse avec elle. Dérive mesurée : **0,000000 s**. L'assertion vivante de
  `_setup_campfire()` la gate à chaque boot.
* **`BEAR_CAMPFIRE_AZIMUTH_DEG` reste 65,2°** — et c'est VÉRIFIÉ, pas
  supposé. Le balayage re-lancé depuis le nouveau point donne une bande
  valide de 45,7 à 227° (elle était 45,7-116,4), un optimum à 127,5°
  (4,4741 u), et l'azimut LIVRÉ y lit **3,2600 u**, plus de trois fois les
  0,9628 u auxquels il avait été choisi. 127,5° achèterait 1,2 u sur une
  contrainte déjà tenue au triple, contre une constante et une direction
  d'arrivée rendue : gardé.

⚠️ **UN PIÈGE DE BANC, ET IL RESSEMBLE EXACTEMENT À UN SITE IMPOSSIBLE.**
Le premier balayage depuis le site final est lui aussi revenu « aucun
azimut valide ». La cause : l'ours se repose à 1,5 u d'une balançoire dont
le rayon d'empreinte publié est 1,80, donc un test de segment qui traite
la balançoire en obstacle échoue à son PREMIER échantillon quel que soit
l'azimut. **Le prop d'où une marche PART n'est pas un obstacle pour
elle.** CH25 ne l'avait jamais rencontré parce que son balayage ne listait
que le décor.

## Section 3 — ROUGE AVANT VERT

Chaque mécanisme neutralisé, la sonde relancée, le fichier restauré et
vérifié **byte-identique par `cmp`** :

| # | neutralisé | sonde | attendu | obtenu |
|---|---|---|---|---|
| R1 | `SKATE_LOBE_RADIUS` 36 → 28 | SkateEdgeProbe | la place de parking et la course nord | **2** : E1 (2,84 u contre un run-up de 3,20) et E2 (pire course 11,15 u) |
| R2 | le liseré éteint (`kerb_radius` 0) | SkateEdgeProbe | le liseré ne dessine plus | **3** : K1, K2 (**1 625 pixels d'encre contre un plancher de 1 666** — exactement le bruit), K3 |
| R3 | le bol remis à sa position CH53, câblé | SkatePhysicsProbe | le chevauchement | **5**, dont le gate central : « unwired IFF overlap » à **774 échantillons partagés** |

R2 est le chiffre qui compte : le liseré encre **33 013** pixels
échantillonnés au bord contre un plancher de **1 666**, et **1 625** quand
on l'éteint. Le seuil sépare d'un facteur vingt.

## Section 4 — CHANTIER 3 : le bol a été fait, prouvé, puis RETIRÉ

Le bol a été entièrement construit dans ce lot et **il marchait**. Il est
retiré sur une mesure, et voici laquelle.

**Ce qui a été établi, et qui reste vrai** :

1. **Le chevauchement se supprime en déplaçant le bol**, et le chiffre est
   une SÉPARATION et non un compte d'échantillons à zéro (une absence
   passe gratuitement) :

   | position | échantillons dans les deux solides | approche la plus proche |
   |---|---|---|
   | (−0,50 ; 55,50) — livrée | **1 044** avec le 2,10, 158 avec le 1,45 | **0,16 u** |
   | (−0,50 ; 57,00) | 0 | 0,46 u |
   | (−3,00 ; 57,00) | 0 | 1,38 u |
   | (−3,00 ; 58,00) | 0 | **2,34 u** |

   La position livrée est le blind check de ce balayage : la mesure qui lit
   0 au nouveau site lit 1 044 à l'ancien.

2. **L'entrée au sol a été construite et prouvée.** Trois secteurs
   d'azimut de l'anneau ouverts face au park (0,94 u d'arc par secteur au
   lip, contre une planche de 0,92 u de long — un secteur unique est une
   fente qu'on ne peut pas viser ; trois donnent 2,83 u). Écrite de sorte à
   **n'introduire AUCUNE position de sommet nouvelle**, pour que le gate
   d'union de CH66 reste exactement le même test. `SkatePhysicsProbe` est
   sorti **ALL GREEN** avec le bol câblé, et une PHASE Z neuve, conduite
   par le VRAI canal d'input, a mesuré :

   * entrée EN ROULANT : franchissement du bord à **y = 0,000**, jusqu'à
     0,673 u de l'axe (le fond plat commence à 2,25) ;
   * le blind check qui en fait un résultat : **la même approche à un
     secteur PLEIN est arrêtée** (4,029 u contre 2,250) ;
   * sortie en roulant, r 5,034, sans passer par-dessus le lip.

**CE QUI L'A FAIT RETIRER.** La table croisée a trouvé `SkateAirProbe`
rouge sur la branche et VERTE sur `origin/staging` :

```
branche : quarterpipe 2.10, retombée (-4.20, 0.00, 57.20)  pops 2
staging : quarterpipe 2.10, retombée (-4.20, 0.00, 57.58)  pops 1
```

La retombée du grand quarterpipe **atterrit DANS le bol déplacé** — 1,44 u
de son axe, à l'intérieur même du fond plat — et la planche pope une
seconde fois sur son rebord. CH66 avait écrit que cette retombée tombait
« sur le REBORD, pas dans la cuvette » ; un décalage de (−2,5 ; +2,5) l'y
met. Le double pop est précisément ce que `POP_MIN_HELD_TICKS` avait été
introduit pour tuer.

Une position qui satisfasse EN MÊME TEMPS le chevauchement nul, les 5,6 u
d'emprise de la place de parking (3 ; 60) et un dégagement de la retombée
en (−4,2 ; 57,4) n'a pas été trouvée dans ce lot : le parking et la
retombée encadrent la zone libre par les deux côtés. **La disposition du
bol est donc rendue intacte** — ni position, ni géométrie, ni collider —
et le chantier reste ouvert avec ses chiffres.

⚠️ **ET IL Y A UN COUPLAGE NON ÉLUCIDÉ, SIGNALÉ PLUTÔT QU'ENTERRÉ.**
Déplacer le bol — sa POSITION seule, `pieces_for` remis à vide — déplace
les vitesses d'arrivée de `SkateInertiaProbe` PHASE E de **+0,13 u/s sur
les quatre échelons** (2,98/5,09/7,02/8,97 → 3,12/5,20/7,18/9,09), de
façon parfaitement reproductible des deux côtés. Isolé par élimination :
ni la région, ni le layout, ni `HubWorld`, ni la palette, ni le shader, ni
`SkateparkMesh`, ni le câblage du bol. Le mécanisme n'est PAS établi.

## Section 5 — LA TABLE CROISÉE, DEUX ARBRES

Référence : `origin/staging` `831db2e` (arbre `7c407ae`), copie importée à
part dans `/home/user/keepy-base`, **154 `.scn` = 154 `.scn`** comptés des
deux côtés avant toute comparaison.

| sonde | driver | branche | référence | écart |
|---|---|---|---|---|
| `SkatePhysicsProbe` | headless | **ALL GREEN** | ALL GREEN | identique |
| `SkateTraverseProbe` | headless | **ALL GREEN** | ALL GREEN | la paire du lobe est désormais DÉRIVÉE et vaut 21,817 s |
| `SkateAirProbe` | headless | **ALL GREEN** | ALL GREEN | identique |
| `SkateInertiaProbe` | headless | **ALL GREEN** | ALL GREEN | identique |
| `SkateTrickProbe` | headless | **ALL GREEN** | — | identique à CH66 |
| `SkateDriveProbe` | xvfb | **ALL GREEN** | — | |
| `SeesawProbe` | headless | **61 OK / 2 FAIL** | **61 OK / 2 FAIL** | **PARITÉ EXACTE**, voir ci-dessous |
| `ActorWalkerProbe` | headless | **PASSED** | — | |
| `ProbeTimeoutAudit` | headless | **98 scènes** | 97 scènes | +1 : `SkateEdgeProbe` |
| `SkateEdgeProbe` (neuve) | xvfb | **ALL GREEN** | — | trois passes rouges, section 3 |

⚠️ **DEUX ROUGES PRÉ-EXISTANTS SUR `origin/staging`, TROUVÉS PAR LA
TABLE.** `SeesawProbe` rend **2 échecs sur LES DEUX ARBRES**, aux mêmes
lignes : « the WEST edge did not move » et « draw nodes excluding portals
= 157, expected 144 ». Ils ne sont ni causés ni corrigés par ce lot (le
second est un compte de nœuds que le hub a dépassé depuis CH16). Le reste
de la sonde suit le changement correctement : 61 OK des deux côtés, et les
seules lignes qui diffèrent sont exactement celles que le lot déplace —
rayon 36, portée z 71,05, balançoire à (18 ; 44) — y compris le gate « les
termes publiés reconstruisent `contains()` sur 721 échantillons », qui
reste vert.

⚠️ **ET UN RUN INVALIDE, RAPPORTÉ PARCE QU'IL A FAILLI COMPTER.**
`SkateDriveProbe` lancée en `--headless` est sortie **12 rouges** ; c'est
une sonde `xvfb` et ses phases de conduite lisent l'écran. Relancée sous
`xvfb --rendering-driver opengl3` : **ALL GREEN**. Un verdict lu sous le
mauvais driver n'est pas un verdict.

## Section 6 — LES PROXYS DE PERF (mesure seule, aucune correction)

Le brief met la perf HORS SCOPE et demande des proxys avant/après. Six
stations, monde gelé, chaque station lue en la QUITTANT et en y revenant
(CH62 : une caméra gelée ne réévalue pas ce qu'elle voit tant qu'elle ne
BOUGE pas), chaque lecture faite deux fois.

| station | prims AVANT | prims APRÈS | Δ | calls avant → après |
|---|---|---|---|---|
| spawn (0 ; 0) | 72 013 | 72 700 | **+687** | 311 → 312 |
| (0 ; 42) | 91 920 | 86 774 | **−5 146** | 377 → 374 |
| (0 ; 51) | 92 067 | 89 257 | **−2 810** | 393 → 391 |
| (3 ; 60) parking | 94 578 | 91 106 | **−3 472** | 420 → 421 |
| (0 ; 63) | 91 976 | 89 060 | **−2 916** | 407 → 410 |
| (−10 ; 51) | 97 640 | 93 419 | **−4 221** | 368 → 368 |

Comptes de scène (déterministes, ce sont eux qui comparent proprement) :
instances de `MultiMesh` 4 671 → **4 969** (+298), triangles de scène
352 574 → **367 794** (+15 220).

**La scène est plus lourde et la frame du park est plus LÉGÈRE**, ce qui
n'est pas une contradiction : la balançoire et l'ours ont quitté le cadre
du park, et le compteur compte ce qui est SOUMIS. Le +687 du spawn est le
tapis REBATTU — `_sprinkle` tire `aire × densité` candidats dans le flux
RNG partagé, donc un rectangle `COVER` plus large redistribue chaque
tirage suivant (CLAUDE.md, CH53) ; c'est le plancher de bruit de toute
comparaison de tapis dans ce lot, et il vaut ±750 primitives.

**Le rayon seul coûtait plus que le lot entier** : mesuré à r 36 sans les
chantiers 2 et 3, la station (0 ; 51) lisait 95 405 primitives, contre
89 257 pour l'arbre livré. Ce sont les props déplacés qui rendent la
différence.

## Section 7 — CE QUE CE LOT NE SIGNE PAS

* **Le FPS device.** Ce sandbox est llvmpipe sous xvfb, pas WebGL2 sous
  Safari iOS. Les chiffres ci-dessus sont des PROXYS et rien d'autre. La
  chute de 55 à 30 FPS relevée sur la build CH66 n'est ni expliquée ni
  traitée ici ; voir NEXT STEPS.
* **La lisibilité réelle de la nouvelle limite.** La sonde signe que le
  liseré ENCRE des pixels au bord (33 013 contre un plancher de 1 666), et
  que 96,5 % de son encre tombe dans son propre anneau. Elle ne signe pas
  qu'un joueur le LIT comme « ça s'arrête ici » — cela n'appartient qu'à
  Mathieu.
* **Que 21 u de course nord suffisent.** C'est le maximum que le budget de
  22 s autorise ; si c'est encore court, le prochain levier n'est pas le
  rayon (38 sort à 22,100 s) mais le budget lui-même, ou une forme.
* **Le bol.** Il n'est pas physique et la planche le traverse toujours,
  exactement comme sur CH66.

## Section 8 — Protocole device

1. Ouvrir `keepy-staging.vercel.app`, monter au skatepark, taper la
   planche garée au nord du park (3 ; 60). Le rider monte, la caméra passe
   en poursuite.
2. **Sentir la zone élargie** : doigt tenu, partir plein NORD depuis la
   place de parking. Avant, le mur arrivait en 2,8 u — avant même la fin
   de l'accélération. Maintenant il y a **10,9 u** devant la planche
   depuis ce point, et **21 u** depuis le centre du park.
3. **Voir la limite** : continuer vers le nord jusqu'à l'arrêt. Une bande
   sombre de terre battue est peinte au sol **juste avant** le bord, sur
   tout l'arc. À reporter : la voit-on venir, et se lit-elle comme « fin
   du terrain » plutôt que comme une trace au hasard ?
4. **Les tricks n'ont pas changé** : refaire le protocole CH66 (petit
   quarterpipe, doigt tenu 1 s, puis un petit cercle au pouce dès le
   décollage). Rien du toucher, du pop ni de la caméra n'a été touché.
5. **La balançoire et l'ourson** : redescendre au sud du park et faire le
   demi-tour d'élan vers le grand quarterpipe. Ils ne sont plus sur ce
   passage — ils sont maintenant à l'EST, vers (18 ; 44). Vérifier qu'ils
   ne gênent plus la course, ET qu'ils sont toujours trouvables et
   utilisables : taper la balançoire, monter dessus, l'ours doit venir
   s'asseoir à l'autre bout comme avant.
6. **Le feu de camp** : taper le feu et vérifier que l'ours et le blaireau
   arrivent toujours à peu près en même temps (leur synchronisation a été
   recalculée pour le nouveau point de départ de l'ours ; dérive calculée
   0,000000 s, mais c'est l'œil qui juge).
7. À reporter : (a) la zone est-elle assez grande maintenant ? (b) le
   liseré se lit-il ? (c) le FPS au park (overlay Perf), pour le comparer
   aux 30 relevés sur CH66 ; (d) la balançoire est-elle encore facile à
   trouver depuis le plateau ?
