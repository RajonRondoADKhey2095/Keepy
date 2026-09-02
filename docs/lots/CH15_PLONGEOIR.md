# Plongeoir — la chaîne complète et sa généralisation

> Extrait de `CLAUDE.md` par le LOT H (2 septembre 2026), **verbatim** : aucune ligne réécrite, résumée ni supprimée.
> 2 section(s), 264 lignes d'origine.
> Doctrine permanente : voir `CLAUDE.md`. Index des chantiers : `docs/lots/INDEX.md`.

## LE PLONGEOIR : LA CHAINE COMPLETE, ET L'ARRONDI DU COMPTE DE BARREAUX (27 aout 2026)

Trois lots ont livre la chaine plongeoir sans qu'aucune section n'ait ete
ecrite ici. Celle-ci couvre les trois d'un coup, plus le lot de reglage du
compte de barreaux qui les clot.

**Le plongeoir** vit dans `resources/hub/hub_layout.tres` sous un type
`&"divingboard"` (une entree, sur le lobe du grand lac), et est construit
par `HubBuilder._make_divingboard()`. Une entree porte trois champs : la
`position` (le pied de l'echelle, sur terre), `deck_anchor` (ou l'on se
tient une fois monte, y compris son Y) et `dive_direction`. La longueur de
la planche, le nombre de poteaux, les rails et la hauteur du deck derivent
tous de ces deux points -- deplacer le plongeoir se fait en deplacant ses
extremites, le dessin suit. **Hauteur de deck = 1,8**, validee sur device
par Mathieu.

### Les trois etats CLIMBING / ON_BOARD / DIVING, et pourquoi RIDING est
### REUTILISE plutot que generalise

`KeepyHopper.State` gagne trois valeurs en plus d'IDLE/HOPPING/RIDING.
Aucune n'est un second systeme de mouvement : CLIMBING et DIVING
remplacent chacun, pour leur duree, la source qui ecrit le corps, et
rendent la main a la chaine ordinaire a leur sortie ; ON_BOARD n'ecrit
rien du tout pendant qu'on s'y tient. Les trois partagent la propriete
de RIDING : aucun n'emet `hop_landed`, donc la detection de portail est
silencieuse pendant toute leur duree -- un plongeoir pose a 9 u de la
rangee de portails emporterait sinon un plongeur dans un sous-jeu qu'il
ne faisait que survoler.

⚠️ **LE DECK N'EST PAS PRATICABLE, PAR CONSTRUCTION ET PAR CHOIX, pas par
oubli.** Le plateau est un modele MONO-ALTITUDE : `HubRegion.contains()`
jette le Y (`_flat()`), et `HubTapInput` raycaste contre un
`Plane(UP, 0.0)` **en dur**. Il n'existe donc structurellement pas de tap
qui signifie « un point sur le deck ». Laisser Keepy s'y deplacer
librement demanderait un second sol, sureleve, contre lequel resoudre les
taps -- un changement a l'echelle du plateau entier pour une seule
planche. Le plongeoir a donc exactement UNE place pour se tenir, et un
tap depuis cette place signifie PLONGER, jamais MARCHER. C'est aussi
pourquoi le tap est intercepte PAR ETAT, exactement comme pendant un
ride : le point au sol arrive toujours resolu a y=0, et il reste utile
(son cote par rapport a l'ancre choisit le plongeon eau/terre), mais il
ne doit jamais devenir une destination.

### La generalisation de `_apply_hop` a des extremites de hauteurs inegales

`_hop_from_y` / `_hop_to_y` valent **zero par defaut**, et tout bond que le
plateau a jamais fait les y laisse : le plateau etant mono-altitude, un
bond entre deux points de sa surface commence et finit au sol par
definition. Ils existent pour qu'UN SEUL bond puisse partir haut et
atterrir bas -- le plongeon depuis le plongeoir. Generaliser l'arc
existant plutot que d'en ajouter un second est deliberee : l'enveloppe de
squash, le pitch et le recoil d'atterrissage roulent tous sur le meme `t`
normalise que la hauteur, et une seconde implementation « bond haut »
aurait ete une copie de chacun d'eux, libre de deriver de celle que tout
le plateau utilise.

**La generalisation est EXACTE a `from == to`, pas seulement proche** :
a extremites egales `lerpf` rend cette valeur pour tout `t`, donc la
parabole s'ajoute a une constante et la trajectoire est celle qui etait
deja livree. **Prouve, pas argumente** : `DivingBoardProbe` PHASE A
echantillonne le `_apply_hop` livre contre la formule d'avant sur 1001
points, sur un bond plein, un dernier bond court et un bond d'ejection --
**divergence pire mesuree : 0,000000000000 u** sur les trois.

### La grimpe quantifiee : cadence MEDIAN validee, et le piege float32

La montee sur l'echelle avance par PALIERS (`climb_push_ratio` = fraction
d'un palier passee a pousser, `climb_sway_amplitude` = balancement
lateral au push, qui revient a zero avant la pause). Trois profils
existent sur la planche de cadence (`docs/color-sheets/`) -- SOBER /
MEDIAN / MARKED -- et **MEDIAN (0,55 / 0,05) est le profil valide sur
device par Mathieu le 27 aout 2026**, avec la cadence de saut du sommet
vers l'herbe qui fonctionne (une divergence ouverte depuis deux lots,
desormais fermee).

⚠️ **LE PIEGE FLOAT32, MESURE ET CORRIGE CE LOT.** Le compte de barreaux
etait `int(round(rung_run / DIVINGBOARD_RUNG_SPACING)) + 1`. A
`deck_anchor.y = 1,8`, cette expression tombe **EXACTEMENT** sur le
couteau de `round()` : en double precision le ratio vaut
`4,500000000000001` (au-dessus du seuil, arrondirait a 5 -> 6 barreaux),
mais `Vector3.y` est du **float32**, donc la valeur qui atteint le calcul
est en realite `1,7999999523162842`, dont le ratio vaut `4,499999841...`
(en-dessous du seuil, arrondit a 4 -> 5 barreaux). **Le compte de
barreaux ne dependait donc pas de la hauteur voulue, mais du sens
arbitraire dans lequel le float32 avait bruite cette hauteur.**

**Mesure AVANT tout changement, aux trois hauteurs (1,4 / 1,8 / 2,4),
en float64 et en float32** :

| hauteur | ratio float64 | ratio float32 (reellement utilise) | sur un couteau .5 ? |
|---|---|---|---|
| 1,4 | 3,166666666666667 | 3,166666587193807 | non (loin de tout .5) |
| **1,8** | **4,500000000000001** | **4,499999841054281** | **OUI** |
| **2,4** | **6,5** (exact) | **6,500000317891439** | **OUI, et la aussi** |

**Constat qui depasse le seul cas connu** : 1,8 ET 2,4 sont TOUTES LES
DEUX exactement sur un couteau de `round()` -- structurel, pas une
malchance isolee. Toute hauteur de deck de la forme `0,6 + 0,3*n` retombe
sur cette meme frontiere, parce que les barreaux eux-memes sont espaces
tous les 0,3.

**Correctif livre** : un arrondi EXPLICITE, a ties **casses vers le bas**,
avec un epsilon (`0,0001`) trois ordres de grandeur au-dessus du bruit
float32 mesure (~1,6e-7 a 3,2e-7) — `int(floor(ratio + 0,5 - EPS))`. Non
tie, il se comporte comme un arrondi normal ; sur un tie (reel ou
bruite), il choisit toujours la meme direction, independamment du sens
dans lequel le float32 a arrondi la hauteur d'entree. **Verifie donner
`rung_count = 5` a 1,8** -- la cadence livree et validee sur device y est
calee, pas seulement a la hauteur.

Les hauteurs de barreaux publiees restent **0,30 / 0,6375 / 0,975 /
1,3125 / 1,65** -- inchangees, parce que le premier et le dernier barreau
sont fixes par construction (`DIVINGBOARD_RUNG_LOWEST` et
`deck_height - 0,15`) quel que soit le compte ; seul l'espacement entre
eux en dependait.

### Keepy N'A AUCUN SQUELETTE -- contrainte qui reviendra

Le `.glb` de Keepy porte **1 seul noeud, 1 seul mesh, 0 skin, 0
animation** -- aucune queue separable, aucun os. Toute animation de ce
personnage, sur cet ecran comme sur celui de Battle, passe donc par le
transform du CORPS ENTIER (position, rotation, echelle) -- jamais par une
sous-partie. C'est deja ce que `FighterView.gd` (Battle) et
`KeepyHopper.gd` (le hub) font tous les deux, independamment, pour la
meme raison. A retenir pour tout futur mouvement de Keepy : il n'y a rien
a animer separement, seulement le corps comme un bloc.

### HORS PERIMETRE, non fait

- **Eclaboussures a l'impact** (lot 2 envisage) -- **AUCUNE particule
  n'existe nulle part dans ce depot**, verifie par grep. Techno non
  prouvee sur WebGL2 mobile ; hors de ce chantier.
- **Plongeoirs sur les 4 autres corps d'eau** (mare, petit lac, ruisseau,
  second lobe du grand lac) -- un seul plongeoir existe, sur le lobe du
  grand lac. Non etendu ici.

⚠️ **Derive de convention, constatee et NON corrigee retroactivement** :
plusieurs lots shader anterieurs (teinte eau, ligne de flottaison) ont
publie leurs mesures de cout/FPS directement dans ce fichier plutot que
dans `docs/HUB_PERF_BASELINE.md`, ou elles auraient du vivre selon la
convention posee par les lots hub anterieurs. Les lignes ne sont pas
reconstruites ni deplacees ici -- seul le constat est note, pour qu'une
future session ne cherche pas ces chiffres au seul endroit ou la
convention dit qu'ils devraient etre.

## LE PLONGEOIR SE GENERALISE : DEUX PLANCHES DE PLUS, UN PIEGE DE CONCURRENCE DANS SA PROPRE SONDE (27 aout 2026)

Branche `claude/diving-board-placement-lot-2-8misfh`, partie de `main`
(`a346912`, le plongeoir unique deja valide sur device). **La section
ci-dessus documentait la chaine complete mais s'arretait a une seule
planche, sur le lobe du grand lac** ; ce lot en ajoute deux, une par
grand corps d'eau restant (petit lac, lobe de spawn), et corrige au
passage un defaut de sonde qui aurait laisse le vert mentir.

### PREMISSE FAUSSE N°1 : la GEOMETRIE etait deja generique, PAS la PLOMBERIE autour

`_make_divingboard()` lisait deja `position`/`deck_anchor`/`dive_direction`
sur l'entree de layout sans rien coder en dur sur "la premiere planche" --
rien a generaliser la. Ce qui ne tenait qu'a UN etait la chaine autour,
et elle tenait a un a TROIS endroits distincts, chacun refuse plutot que
corrige a l'aveugle :

- **`HubBuilder`** : `_diving_board {}` singulier / `diving_board()` ->
  `_diving_boards []` / `diving_boards()`. **Pas** soumis a la regle "un
  seul" du pond/lake/boat -- ces singletons existent parce qu'un
  appelant en aval doit nommer LE pond ; rien ne nomme LE plongeoir, un
  climb part de l'echelle sur laquelle on a marche, donc une planche de
  plus est un lieu de plus a grimper, pas une ambiguite.
- **`HubTapInput`** : `ladder_foot` -> `ladder_feet`. Un point ne
  repondait que pour la premiere echelle ; un tap sur l'une des deux
  autres tombait a travers vers `tapped_ground` et marchait Keepy jusqu'a
  une planche qu'il ne pouvait ensuite pas grimper. Le rayon reste un
  nombre unique : c'est une propriete du GESTE, pas d'une planche.
- **`HubWorld`** : `_try_climb` choisit desormais le pied le PLUS PROCHE
  dans ce rayon, pas la premiere entree du layout. Le plus proche et pas
  le premier, parce que "premier" est un fait sur le fichier et le
  joueur se tient a un endroit.

**Avant ce lot, un deuxieme plongeoir aurait ete DESSINE et JAMAIS
GRIMPABLE** : la geometrie genereait la planche (elle ne lisait rien de
special au premier index), mais un `push_error` refusait explicitement
toute deuxieme entree tant que la plomberie n'avait pas suivi -- exactement
le defaut qu'une session pressee aurait pu livrer en silence si elle
avait vu la geometrie generique et suppose, a tort, que le reste
suivait automatiquement.

`KeepyHopper` est **intouche** : il possede une planche A LA FOIS, ce qui
reste vrai, et ses seules mentions de l'ancien accesseur etaient des
commentaires.

### Placement mesure, pas choisi a l'oeil -- meme critere que la premiere planche

Deux entrees, aucune nouvelle constante. Hauteur de deck **1,8** sur les
deux, comme la planche deja livree -- cette hauteur est validee sur
device et n'est pas rouverte ici.

Le candidat retenu par lac est celui qui maximise
`min(degagement aux props, degagement a l'autre eau)` **du cote par
lequel un joueur approche reellement**, et non le point le plus vide de
la carte -- maximiser le degagement seul pousserait les deux planches
dans un coin ou personne ne marche :

| corps d'eau | pied d'echelle | degagement |
|---|---|---|
| petit lac | (-21,1469 ; 3,0628), rive nord-est | 2,293 u au prop le plus proche, 3,9 u a toute autre eau |
| lobe de spawn | (-15,5728 ; -8,5691), rive nord, entre les deux lacs | 2,070 u au prop le plus proche, **2,07 u au petit lac** |
| grand lac (deja livre) | -- | **2,512 u**, RE-MESURE ici par la sonde plutot que repris de memoire |

### PREMISSE FAUSSE N°2 : le compte de barreaux ne se deduit PAS de "ils sont tous a 1,8"

Le nombre de barreaux est **mesure par planche**, pas suppose identique
parce que les trois partagent la meme hauteur de deck. Le ratio dont il
derive tombe **exactement** sur le couteau `.5` de `round()` a 1,8 (voir
la section precedente), et lequel des deux cotes un arrondi non protege
choisit dependait du bruit float32 -- pas de la hauteur voulue. "Ils sont
tous a 1,8, donc ils correspondent tous" est precisement l'hypothese que
le correctif de tie-break existe pour interdire. Les trois planches
retombent a **5 barreaux**, mesure et non suppose.

### PREMISSE FAUSSE N°3, TROUVEE DANS LA SONDE ELLE-MEME : un `await` fait d'une phase une COROUTINE, et l'appeler nue la fait tourner CONCURREMMENT

`DivingBoardProbe` mesurait la planche zero et l'appelait "la planche".
Chaque phase tourne desormais par instance :

- **PHASE B** resout de QUELLE eau chaque planche plonge en interrogeant
  les corps eux-memes -- `HubRegion` pour les lobes du grand lac,
  `HubBuilder` pour la mare et le petit lac -- au lieu d'etre epinglee a
  `lakes()[0]`, tout ce qu'une seule planche pouvait nommer. Ajoute un
  gate de compte de barreaux par planche et un controle qu'aucun pied
  d'echelle n'est a moins d'un rayon de tap d'un autre.
- **PHASE C** grimpe, se tient et plonge chaque planche, cibles TERRE et
  EAU toutes les deux.
- **PHASE D** essaie chaque centre de portail depuis chaque deck. Le
  BLIND CHECK reste arme et **sort de la boucle** : le laisser dedans
  laisserait le dialogue ouvert, ce qui empoisonnerait tous les
  controles "n'ouvre rien" suivants.

**113 checks, 0 echec.**

⚠️ **Trouve en ecrivant cette sonde, et ca merite d'etre nomme parce que
le vert avait l'air reel** : `_phase_c_one` contient des `await`, donc
c'est une coroutine, et l'appeler nue faisait tourner les trois planches
CONCURREMMENT sur un seul corps. Douze checks echouaient en imprimant les
coordonnees de la planche zero pendant les planches un et deux. **Corrige
en `await`ant l'appel** -- le meme piege que celui deja consigne pour les
sondes Battle et Hub ailleurs dans ce fichier, ici trouve une couche plus
loin, dans une sonde qui verifiait justement l'absence de concurrence
entre planches.

`WaterTintProbe` : constante de draw-nodes **106 -> 120**, itemisee comme
son propre commentaire l'exige : deux planches x sept noeuds de mesh
chacune. **Aucun nouveau MultiMesh** -- le lot de barreaux est cle par
mesh et couleur, donc trois echelles partagent UN noeud qui porte
desormais 15 instances au lieu de 5.

### Reste ouvert -- verifie sur l'arbre fusionne au lot suivant, pas ici

`resources/hub/hub_layout.tres` porte desormais trois entrees
`&"divingboard"`, `HubBuilder.gd`/`HubTapInput.gd`/`HubWorld.gd` portent
la generalisation ci-dessus, `DivingBoardProbe.gd` couvre les trois, et
`docs/HUB_PERF_BASELINE.md` recoit une ligne perf (106/112 avant ->
120/126 apres, FPS moyen inchange, FPS min bruite par la machine
partagee -- **jugement device**, comme toujours pour ce banc llvmpipe).

