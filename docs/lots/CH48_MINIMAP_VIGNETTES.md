# CH48 — Des miniatures réelles sur la minimap (8 septembre 2026)

> Base : `origin/staging` au commit `dfb3d83` (merge CH47), arbre
> `6eaa693cb71b9ae168b5fb01f91273184f1f74e3`. Branche
> `claude/minimap-real-thumbnails-w8ya0m`, partie de l'arbre de `staging`
> et **pas** de celui de `main`.
>
> **Vérification de concurrence faite AU DÉBUT** (`git fetch --all --prune`,
> comparaison par **hash d'arbre** et non par nom) : aucune ref distante ne
> ressemble à celle-ci, `origin/claude/minimap-readability-ch47-3rugvg` est
> l'ancêtre direct de `staging`, `origin/main` porte un commit CI de plus et
> n'est pas touché. Aucune session concurrente.

---

## LE MOTIF

CH47 est sorti **125 assertions vertes** — trois rangs de saillance, une
matrice de séparation à six paires, la fusion des grappes, la correction du
ciblage PNJ. Mathieu, sur device, verbatim :

> « je la trouve pas lisible »

Deux lots verts d'affilée sur une carte que personne ne peut lire. Sa
demande : **des répliques miniatures des vrais personnages et véhicules** à
la place des formes géométriques.

---

## LES DEUX CHIFFRES QU'IL A DÉLÉGUÉS À LA MESURE

### A — LA TAILLE, ET LA MÉTHODE DEMANDÉE QUI N'A PAS PU RÉPONDRE

Le brief demandait la taille par **couverture**, la méthode CH46/CH47 :
cuire chaque vignette sur une échelle de tailles et trouver où deux du même
rang cessent de se séparer. Fait (`MinimapThumbBake` PHASE 3, 22 sujets,
onze tailles, matrice complète imprimée à 24, 32 et 40 px). Le résultat :

```
size 16 px : pire paire 0.0000 (Yacht/SailBoat)   pire même-rang 0.0000
size 32 px : pire paire 0.0000 (Yacht/SailBoat)   pire même-rang 0.0000
size 64 px : pire paire 0.0000 (Yacht/SailBoat)   pire même-rang 0.0000

les cinq quadrupèdes bruns, pire paire :
   16 px  Boar/Fawn 0.551      40 px  Boar/Fawn 0.499      64 px  Boar/Fawn 0.483
```

⚠️ **LA SÉPARATION EMPIRE QUAND L'ICÔNE GRANDIT.** À 16 px une plus grande
part de la boîte est du bord, où deux sujets diffèrent ; à 64 px les
intérieurs (bruns des deux côtés) s'accordent. **Un critère qui s'améliore
quand l'image rétrécit ne peut pas nommer une taille minimale.** CH47
l'avait dit en mots (« la distinction reste mesurée en COUVERTURE, pas en
perception ») ; voici le nombre.

Ce qui **dégrade** monotoniquement, c'est ce qui survit au sous-échantillonnage
(PHASE 3b : descendre à S, remonter, comparer au rendu de référence). Son
rendement par pixel de cellule :

```
16->20  0.0118/px    24->28  0.0072    32->36  0.0056    44->48  0.0039
20->24  0.0098       28->32  0.0061    36->40  0.0047    48->56  0.0032
```

**32 est le dernier barreau qui rende encore au moins la moitié de ce que
rendait le premier pixel (0,0059).** Aller à 64 px achèterait 0,085 de
fidélité et coûterait une carte 60 % plus large. **`ICON_PX = 32`.**

### A2 — LA CARTE, DÉRIVÉE DU SEUIL DE CH46 LUI-MÊME

Le seuil n'est pas inventé : c'est le chiffre que CH46 a publié pour la
carte livrée — « 37 marqueurs couvrent 16 % d'un plan de 155 x 280 ». Le
balayage (PHASE 3f : vraies positions au spawn, clustering meneur livré
rejoué à chaque candidat) demande le plus petit plan qui repasse dessous
avec des vignettes de 32 px :

| plan | glyphes | encre | plan | glyphes | encre |
|---|---|---|---|---|---|
| 155 x 280 | 27 | **28,2 %** | 189 x 340 | 28 | 19,1 % |
| 166 x 300 | 27 | 24,5 % | 200 x 360 | 28 | 17,0 % |
| 177 x 320 | 27 | 21,6 % | **211 x 380** | **28** | **15,3 %** |

**380 est le premier barreau à 16 % ou moins, et le lot livre le premier
barreau** — Mathieu a dit « un peu plus grande seulement ». C'est **1,36×
CH47 linéairement**, 19,5 % de la largeur du canvas là où CH47 faisait 14,4 %.

### B — LA DÉSATURATION, ET POURQUOI CE N'EST PAS LE LEVIER DE CONTRASTE

⚠️ **DÉSATURER À CLARTÉ CONSTANTE EST NEUTRE EN CONTRASTE**, et c'est de
l'arithmétique, pas une opinion : le WCAG note la LUMINANCE relative, et
tirer `GRASS_A` jusqu'à son propre gris la déplace de **L 0,4717 à 0,4491**.

⚠️ **ET LA PRÉMISSE DE PALETTE DU BRIEF NE TIENT PAS POUR CE HUB.** Le brief
annonce « palette marécage, sol L=0,1035, deux bandes utilisables ». C'est
la palette de *Chased*. La minimap peint les bandes `CozyPalette` VOIE A,
mesurées :

```
GRASS 0,4717   AUTUMN 0,3139   MOOR 0,3339   LAWN 0,5290
SAND  0,7000   SEABED 0,1996   SHALLOW 0,5370   TRACK 0,9320
```

Toutes CLAIRES. Il n'existe **aucune bande claire disponible** : pour huit
des dix tons, atteindre 3,0:1 par le haut exigerait L > 1.

**La demande de Mathieu (« les aplats sont vifs et dominent ») porte sur la
CHROMA**, et la chroma est exactement ce qu'un lavage vers le blanc retire :
`lerp(c, blanc, w)` laisse à une bande **(1 − w)** de sa propre chroma.

* **Plancher** — la bande la plus criarde est AUTUMN à chroma **0,5200**, les
  22 vignettes font **0,3442** de moyenne : `w ≥ 1 − 0,3442/0,5200 =` **0,3382**.
* **Plafond** — la paire la plus serrée que le plan sépare PAR LE TON est
  MOOR/SHALLOW à 0,2315, et la limite de résolution est le saignement de
  8 % de l'alpha 0,92 du plan : `w ≤ 1 − 0,08/0,2315 =` **0,6545**.

Fenêtre **[0,3382 ; 0,6545]**, non vide ; le lot livre son **PLANCHER** :
**`WASH = 0.34`**.

⚠️ **GRASS/LAWN (0,0640 d'écart) ÉTAIT DÉJÀ SOUS CE SAIGNEMENT AVANT CE
LOT**, à w = 0. Ces deux bandes n'ont jamais été distinguées par le ton ;
c'est la haie que `_bake_zone_edges` trace à `CIRCUIT_EDGE_Z` qui les
sépare, et elle le fait toujours. La sonde exclut cette paire **par son nom**
et asserte qu'elle reste la plus serrée, pour qu'une SECONDE paire tombant
sous le saignement ne puisse pas se cacher derrière elle.

---

## ⚠️ LA RÉPONSE À « EST-CE QUE LES COULEURS RÉELLES PASSENT » EST NON, ET LE BALAYAGE LE PROUVE

Le brief demandait de le dire AVANT de livrer, chiffres à l'appui. Balayé de
w = 0,0 à w = 1,0 (PHASE 3d), **la pire vignette ne dépasse jamais 2,6 % de
son encre franchissant 3,0:1 contre toutes les bandes à la fois** — à
n'importe quelle désaturation, bandes lavées jusqu'au blanc pur comprises.

```
w=0.0  pire sujet   0.0% (le bateau)      w=0.6  pire sujet   0.0% (la luge)
w=0.3  pire sujet   0.0% (la luge)        w=0.9  pire sujet   1.9% (Keepy)
w=0.5  pire sujet   0.0% (la luge)        w=1.0  pire sujet   2.6% (Keepy)
```

**Ce n'est pas le lavage qui échoue.** Un RATIO de contraste est un ton
contre un ton ; un blaireau a une fourrure blanche et un masque noir, et
quelle que soit la luminance d'une bande, l'un des deux en est proche.
**3,0:1 est un contrat qu'un aplat d'icône peut signer et qu'une
PHOTOGRAPHIE ne peut pas.**

### Ce que le lot livre à la place, et il est mesuré

Le plancher est porté par un **PLATEAU SOMBRE**, qui est un seul ton et peut
le signer. Mesuré : `PLATE_TONE (0.07, 0.08, 0.09)`, **L = 0,0070**, pire
ratio contre les huit tons de bande peints **4,38:1** (contre le fond marin,
le plus sombre). La vignette n'a alors à franchir que **LE PLATEAU**, un ton
fixe connu : entre **47,2 %** (le sanglier) et **100 %** (la luge, les trois
oiseaux) de son encre le fait.

⚠️ **ET LE LISÉRÉ DE RANG A FAILLI COÛTER LE CONTRAT.** La première coupe
donnait au plateau UN liséré, dans le ton du rang. La sonde — reconstruite
après que sa propre passe rouge R8 l'ait démasquée (voir plus bas) — a marché
le périmètre et lu **43 échantillons sur 68 sous 3,0:1, pire 1,16:1**. La
cause est arithmétique : les tons de rang 1 sont CLAIRS par la construction
de CH47 (joueur L 0,8392, véhicule 0,6476) et les bandes le sont aussi. **La
règle de CH46 avait raison la première fois — ce qui survit à n'importe quel
fond est le NOIR** — et CH48 la garde en mettant la couleur du rang **juste
à l'intérieur** d'une keyline noire de 1,6 px plutôt qu'à sa place.

Mesuré après correction, sur le rendu :

```
13 plateaux marchés : 488 échantillons contre du sol peint
   (300 tombés sur un voisin, 0 sur le lavis hors-monde)
   pire 3,56:1, 0 sous 3,0:1
et sur l'atlas, toutes variantes comprises :
   le bord le plus sombre que chaque cellule peut présenter : pire L 0,0039
```

---

## LA PRODUCTION DES VIGNETTES — CE QUE LE BAKE A TROUVÉ

`scripts/dev/MinimapThumbBake.gd` construit `HubWorld.tscn` et **photographie
les entités que la carte marque déjà**, en place, à travers leurs propres
matériaux et à leurs propres échelles. Il n'instancie aucun modèle, ne recopie
aucune transformée et ne nomme aucun chemin : il énumère les groupes de
`MinimapMarkers`. C'est la parade directe au piège « un fixture qui diverge
du réel sur un axe ne protège pas de cet axe ».

**Angle unique, tranché une fois** : celui de `HubCamera.OFFSET (0 ; 7,6 ; 8,9)`,
élévation 40,5°, exprimé **dans le lacet propre du sujet** — la vue que le
joueur a déjà de cette entité quand elle lui fait face. **Distance : 11,7034 u**,
la longueur de cet OFFSET, assertée contre elle et non retapée ; `CLAUDE.md`
enregistre déjà que cette caméra ne s'approche jamais, donc c'est la SEULE
distance d'où un joueur voit quoi que ce soit.

### ⚠️ UNE SEULE ASSERTION A DÉBUSQUÉ TROIS CAUSES DISTINCTES

L'outil ouvrait sur « le même sujet vu de 5 u et de 9 u est une seule
image », censé prouver que le haze était coupé. **ROUGE sur 17 des 22.**

1. **Le monde n'était pas figé.** Les animaux marchent, les karts roulent,
   les montgolfières oscillent : deux prises à quatre frames d'écart sont
   deux poses. `get_tree().paused`.
2. **`visibility_range_end` EST UN CULL DE DISTANCE**, et `HubCritter` en
   pose un sur chaque maillage d'animal (`CLAUDE.md` : culling CPU pur en
   Compatibility). Un sujet photographié au-delà de son propre cull n'est pas
   une image sombre, c'est **aucune image**. Neutralisé pour la prise,
   restauré après : **à lui seul, 16 rouges sont tombés à 6.**
3. **`haze` (`length(view_pos)`) ET `rim` (un vecteur de vue reconstruit
   depuis `VIEW`, qui reste positionnel même sous une caméra orthographique)
   sont deux vrais termes de distance du rendu LIVRÉ.** On ne peut pas les
   retirer et continuer d'appeler le résultat « le vrai modèle ».

Le contrat a donc changé, et pour quelque chose de plus vrai : **la prise est
faite à la distance propre de la caméra du jeu**. Le haze est le seul terme
délibérément coupé, et c'est un choix énoncé : à 11,7 u il mêle 9,8 % de ciel
pâle à chaque sujet, et le plan sur lequel ces icônes se posent est déjà une
palette claire. **Une carte est un schéma, pas une fenêtre.** `wind_amount`
part avec lui, pour une autre raison : il est piloté par le TIME du shader,
que la pause de la SceneTree n'arrête pas — une voile laissée en mouvement
faisait différer deux prises d'un canal entier (**pic 1,000 mesuré**).

Trois preuves remplacent l'assertion d'origine : déterminisme à une distance
(22/22 byte-identiques), une prise haze-ON contre haze-OFF qui doit DIFFÉRER,
et une prise à deux distances qui doit AUSSI différer — cette dernière étant
le blind check qui dit que la comparaison voit quelque chose.

### ⚠️ ET `get_aabb()` A CADRÉ DEUX SUJETS SUR RIEN DU TOUT

La première version cadrait sur l'union des `VisualInstance3D.get_aabb()` et
est tombée droit dans le piège que `CLAUDE.md` nomme : un rig Mixamo porte une
`Armature` à l'échelle 0,01, donc l'AABB du maillage de l'ours relue à travers
elle mesurait **0,01 × 0,02 × 0,01 u** pour un corps de 1,6 u. Les deux
acteurs rigués sont sortis à **couverture 1,0000** (la caméra cadrait une
boîte À L'INTÉRIEUR de l'ours) et **0,0000**. Aucune de ces deux erreurs n'est
visible dans le code ; les deux sont évidentes sur l'image.

**Le cadre est donc TROUVÉ EN RENDANT** : une prise dans une boîte
délibérément généreuse, la boîte englobante de l'encre **mesurée sur les
pixels rendus**, la caméra recadrée dessus, répété deux fois. C'est le dessiné
qui fixe le cadre — la règle que ce dépôt applique déjà aux silhouettes,
appliquée au cadrage.

### ⚠️ ET LA SONDE S'EST COLLISIONNÉE ELLE-MÊME, ET LA COLLISION SE LISAIT COMME UNE MESURE

CH46 note déjà que cinq des 37 marqueurs n'ont **aucun nom** (`@Node3D@228`).
Le repli de l'outil était « parent/classe » — et **l'ours et le blaireau sont
tous deux des `Node3D` anonymes sous `World`**. Les deux ont reçu l'étiquette
`World/Node3D`, la seconde prise a écrasé la première dans le dictionnaire, et
la matrice de séparation a alors rapporté la paire à **0,0000** : deux
maillages différents (5846 et 5623 triangles, l'inventaire le dit une ligne
plus haut) déclarés identiques parce qu'ils étaient la même image stockée.
**Un défaut de sonde qui ressemble exactement à une trouvaille.** Le repli est
désormais le **fichier de scène** dont le nœud a été instancié, et l'unicité
des 22 étiquettes est assertée.

### L'INVENTAIRE, SUR L'ARBRE CONSTRUIT

Les 22 entités ont toutes un modèle exploitable — aucune n'est restée abstraite
faute de visuel. Les 15 lieux gardent la forme abstraite de CH47, par décision.

| ce que la mesure a trouvé | chiffre |
|---|---|
| oiseaux d'arbre | **2 triangles** chacun, une paire d'ailes plates ; trois COULEURS (bleu, ambre, rose) |
| char à voile et voilier | **le MÊME jeu de maillages** (`yacht_hull_0` + `yacht_sail_0`) |
| kart du joueur | 648 tri, sans pilote ; les trois IA 5374 à 6358 tri, chacune son animal |
| ours / blaireau | 5846 / 5623 tri, rigs Mixamo |

### ⚠️ DEUX ENTITÉS SONT LA MÊME IMAGE, ET RIEN DANS CE LOT NE LE RÉPARE

**Le char à voile et le voilier sont bâtis des deux MÊMES `.glb`.** Leurs
portraits sont identiques à **0,0000** à toutes les tailles de l'échelle, de
16 px à 64 px. Ce n'est pas maquillé : la sonde **asserte que ce fait reste
VRAI**, pour que le jour où l'un des deux reçoit son propre modèle,
l'assertion le dise. Sur la carte ils restent deux glyphes distincts, à deux
endroits distincts — ce qui est toute l'information que la géométrie porte.

**Les cinq quadrupèdes bruns, en revanche, se séparent nettement** — Meshy
leur a donné des tenues distinctes (veste bleue du sanglier, manteau vert et
monocle du chat, écharpe du faon, bonnet vert du castor) : pire paire
**0,483 à 64 px, 0,551 à 16 px**. La crainte du brief ne s'est pas réalisée,
et c'est mesuré plutôt que supposé.

---

## L'IDENTITÉ, ET POURQUOI C'EST UNE LISTE ET PAS UNE TABLE DE NOMS

Une image est **par ENTITÉ**, pas par type. `MinimapMarkers.mark()` prend donc
un troisième argument — **une ligne, au site qui construit l'entité**, à côté
de l'appel qui y est déjà. `THUMBS` publie l'ORDRE, et c'est le seul endroit
où cet ordre existe : le bakeur y écrit les cellules, `HubMinimap` les y lit.
L'ours et le blaireau dérivent le leur du `model_scene` qu'on leur a donné ;
les karts d'un `grid_index` écrit **avant** `add_child` (leur `_ready()` court
dedans) ; les oiseaux et les montgolfières de l'indice déjà en portée. Aucun
`.name` n'est lu nulle part.

**Une entité sans entrée n'est pas une erreur** : elle garde la forme
abstraite. C'est ainsi que les quinze lieux restent des lieux.

---

## LE COIN, ET CE QU'IL FALLAIT VÉRIFIER

Décision 4 de Mathieu : bas DROITE, parce que le bas GAUCHE est là où son
pouce se pose. CH44 axe 4 dit que le tiers bas est libre des deux côtés ; la
seule chose qui vit à droite est la jauge d'accélérateur de `KartHud`, et son
propre commentaire la dit « bottom-anchored » alors que le code la dessine
**centrée verticalement** (`y = vp.y * 0.5 - GAUGE_H * 0.5`). Sur un canvas
1920 elle occupe y 830..1090 ; le widget commence à **y 1390**. Les deux rects
sont **mesurés et assertés disjoints**, parce que « son commentaire dit
centrée » n'est pas une mesure.

`MOUSE_FILTER_IGNORE` re-prouvé APRÈS le déplacement, avec de vrais
`InputEventScreenTouch` poussés au centre du nouveau rect, et sa paire aveugle
(`STOP`, qui doit avaler) :

```
IGNORE (livré)   2 événements, canal tapped_ground
STOP   (blind)   0 événement,  0 canal
IGNORE (rendu)   2 événements, 1 canal
```

---

## LA FUSION : CH47 FUSIONNAIT À DEUX PORTÉES, CH48 À UNE — ET C'EST UNE DÉCISION

`merge_px` valait **deux fois** la portée dessinée (« leurs encres se
touchent »). À 8 px d'encre cela fait 16 px ; à un plateau de 32 px cela fait
**29 px, soit 19 UNITÉS MONDE** sur ce plan. Mesuré sur le monde livré à
2 × portée, les véhicules pliaient **{HopBall, Balloon_0, le bateau du
ruisseau} en UN seul glyphe** — trois véhicules différents, trois portraits
différents, une seule image montrée.

CH47 pouvait se le permettre : ses glyphes ne portaient aucune identité
au-delà de leur type. **CH48 existe précisément pour qu'ils en portent une**,
donc une fusion qui cache deux portraits sur trois détruit ce que le lot
livre. **UNE portée** est le seuil honnête, et c'est le même critère que le
dimensionnement de la carte : deux glyphes ne se plient que quand le second
**ENTERRERAIT** le premier. Mesuré après le changement : `{Yacht, SailBoat}`
et `{HopBall, Balloon_0, bateau}` cessent de se plier ; les quatre karts sur
la grille et les trois oiseaux à l'origine du monde se plient toujours.

```
37 marqueurs -> 31 glyphes   (CH47 : 37 -> 30)
```

---

## ⚠️ LE PLACEMENT SOUS-PIXEL, ET CH47 AVAIT DÉJÀ PAYÉ LA MOITIÉ

CH47 note : à rayon 2,3 « le cœur pleinement opaque du point fait neuf pixels
AVANT le placement sous-pixel du widget », et la sonde en a lu quatre. CH48 l'a
retrouvé par l'autre bout : **l'anneau de rang de 2 px culminait à 0,835 de son
ton au lieu de 1,000** sur les glyphes dont la position de grappe était
fractionnaire, et `MinimapProbe` a lu **ZÉRO** pixel du ton sur quatre d'entre
eux alors que l'anneau était parfaitement visible sur la capture.

**Un origine en pixel entier** remet chaque détail de 1 à 2 px — cet anneau ET
la keyline noire qui signe le contrat de contraste — à pleine intensité. Le
coût est au plus un demi-pixel de position, soit **0,32 unité monde** sur ce
plan.

---

## ⚠️ ET L'ANNEAU DE RANG A DÛ SORTIR DE LA CELLULE

Première conception : cuire la couleur du rang dans chaque portrait. Cela
oblige à lire les groupes **AU MOMENT DU BAKE** — et le bake tourne à la
première frame, alors que le blaireau, la luge, le bateau du ruisseau et le
voilier rejoignent tous leur groupe après elle. **Les quatre sont sortis avec
le liséré NOIR de repli**, et `MinimapProbe` PHASE 4 l'a lu exactement :
« lights only 0 px of its tone », quatre glyphes, sur une carte par ailleurs
juste. Un repaint-sur-changement a été essayé d'abord : c'est le genre de
correctif qu'il faut re-gagner chaque fois que l'ordre de construction bouge.

L'anneau est désormais **TROIS cellules à lui** — ordinaire, joueur, clampée —
cuites en BLANC et dessinées par-dessus le portrait avec le ton du type en
`modulate`. Le type est alors résolu là où il est toujours juste : **au moment
du dessin**, depuis le groupe d'où sort le glyphe. Cela coûte un quad de plus
par glyphe, **de la MÊME texture**, donc la carte reste à un seul draw call.

---

## KEEPY PARMI LES TRENTE-SEPT — LE BESOIN PREMIER

Verbatim : « le marqueur de Keepy doit rester identifiable au premier coup
d'œil ». CH47 lui donnait le plus grand disque ; CH48 le lui avait retiré en
donnant à chaque portrait la même cellule de 32 px. Un anneau plus épais seul
ne suffit pas, et **la mesure l'a dit** : 184 pixels d'anneau contre 176 pour
un véhicule, **4,5 % d'écart**, ce que personne ne trouve « au premier coup
d'œil ».

Son glyphe est donc **DESSINÉ à 1,28×** — la cellule reste 32 px pour tout le
monde (un atlas, une planche, un bake), c'est une échelle au draw call. Tout ce
qui est en aval le lit à travers `node_reach()`, donc la borne de clustering,
l'inset de clamp et chaque assertion de sonde bougent avec, sans avoir à le
savoir. Mesuré :

```
Keepy est dessiné à une portée de 18,56 px ; le plus grand des 36 autres est 15,50
son anneau encre 184 px ; l'anneau le plus large des autres types en encre 176
```

---

## LA SONDE, ET LES PASSES ROUGES

`MinimapProbe` — **188 assertions, ALL GREEN, 0 rouge**, sous
`xvfb-run --rendering-driver opengl3 --resolution 1080x1920 --fixed-fps 60`.

### ⚠️ LE CRITÈRE DE CH47 NE VOIT PAS LES MARQUEURS DE CH48

CH47 séparait ses quatre types par **|couverture(A) − couverture(B)|** et
obtenait 0,0960 au pire contre un plancher de 0,0000, parce que ses quatre
glyphes étaient quatre TAILLES. Chaque portrait de CH48 est le même plateau :
ce nombre vaut ~0,02 pour chaque paire **par construction**, et reporté tel
quel il déclare cassée une carte correcte. Pire, il lirait **0,0000 pour deux
portraits IDENTIQUES** et appellerait ça une réussite. **Une aire scalaire ne
distingue pas deux images, seulement deux empreintes.**

La matrice est donc devenue une **couverture de DÉSACCORD** : quelle part de
la boîte les cartes d'encre des deux glyphes ne partagent pas, chacune lue
contre sa propre ligne de base. Le chiffre CH47 reste imprimé à côté.

```
--- MATRICE, 6 paires (désaccord | delta d'aire CH47) ---
    player   vs vehicle   0.8301  |  0.0487
    player   vs npc       0.5721  |  0.0230     <-- CH47 aurait échoué ici
    player   vs place     0.8494  |  0.8044
    vehicle  vs npc       0.7769  |  0.0257     <-- et ici
    vehicle  vs place     0.8200  |  0.7557
    npc      vs place     0.8320  |  0.7815
paire la plus faible player/npc à 0.5721, plancher 0.0000
```

### Les passes rouges

| passe | neutralisation | rouges | ce qu'ils ont dit |
|---|---|---|---|
| **G** | aucune (livré) | **0** | 188 checks |
| **R6** | les portraits coupés (tout retombe sur les formes) | **21** | cellules, anneau clampé, empreinte, taille de Keepy |
| **R7** | `WASH` poussé à 0,90 | **5** | les bandes cessent d'être séparables |
| **R8** | `PLATE_TONE` et `PLATE_RIM` éclaircis en gris moyen | **2** | l'anneau d'atlas ET le périmètre |
| **R9** | `merge_px` remis à 2 × portée (CH47) | **5** | le seuil, et la paire témoin qui doit rester deux glyphes |
| **R10** | `PLAYER_SCALE` remis à 1,0 | **3** | Keepy cesse d'être le plus gros |

Tous les fichiers restaurés et vérifiés **byte-identiques** par `cmp`.

### ⚠️ R8 A DÉMASQUÉ UN FAUX VERT DANS CETTE SONDE MÊME

La première version de la phase de contraste lisait **le pixel le plus sombre
n'importe où dans le glyphe** et le notait contre chaque bande. R8 a éclairci
le plateau — le défaut exact que la phase existe pour attraper — et **la phase
est sortie ALL GREEN** : un portrait a ses propres pixels sombres (un œil, un
contour), donc « le plus sombre de la boîte » reste sombre quelle que soit la
clarté du plateau. **L'assertion était vraie et ne portait sur rien.**

Ce que le contrat dit réellement, c'est que le glyphe présente une FRONTIÈRE
sombre tout autour, contre la bande sur laquelle il se trouve. C'est donc le
périmètre qui est marché, et le pixel juste dedans contre le pixel juste
dehors — **le sol qu'il touche vraiment**, pas un ton de bande lu dans une
table.

### ⚠️ ET DEUX AUTRES DÉFAUTS DE SONDE, TROUVÉS PAR LEURS PROPRES CHIFFRES

* **La pause dans la mauvaise phase.** Le gel du monde (nécessaire : le
  plancher de bruit de la PHASE 9, à 0,0000 pour CH47 en bas à gauche, est
  revenu à **0,3499** en bas à droite — pas une autre carte, une autre
  parcelle d'herbe qui bouge) a été inséré par un remplacement textuel qui a
  attrapé **DEUX** blocs de lifting identiques. L'arbre est resté en pause de
  la PHASE 6 à la fin de la PHASE 9 : les taps de la PHASE 8 sont morts (un
  `HubTapInput` en pause n'a pas d'`_unhandled_input`) et la PHASE 6 a lu une
  frame dessinée AVANT son propre lifting. **Six rouges, pas un seul au sujet
  de la carte.** Et le gel a une seconde moitié : **le widget en est exempté**,
  sans quoi `HubMinimap._process` ne rappelle jamais `queue_redraw()` et chaque
  frame « un type remis » revient IDENTIQUE à la ligne de base — pic 0,000
  pour chaque glyphe de chaque type, une carte lue comme vide.
* **Un blind check qui ne pouvait pas discriminer.** La vérification du
  correctif PNJ de CH47 déplaçait le CONTRÔLEUR en attendant que le glyphe ne
  bouge pas — mais l'animal est un ENFANT du contrôleur, donc bouger le parent
  bouge l'enfant et le glyphe a bougé de 33,88 px comme il devait. Ce test
  n'aurait jamais pu séparer les deux câblages. Le vrai : remettre le marqueur
  là où CH46 l'avait — **sur le contrôleur** — et bouger l'ANIMAL seul. Une
  carte qui lit le contrôleur ne peut pas le voir. Mesuré : **33,88 px avec le
  bon câblage, 0,00 px avec celui de CH46.**

### Ce qui est gaté au PIXEL, jamais sur un compteur

* les 22 cellules de la planche livrée encrent leur cellule sans la remplir, et
  chaque paire (sauf char/voilier) est sa propre image ;
* l'alpha reste une matte franche (pire frange **0,1172**), donc l'import n'est
  pas devenu destructif ;
* **le glyphe à l'écran EST la cellule cuite** : pour chacun des **14** lus, la
  comparaison avec sa propre cellule bat celle avec la cellule d'un autre — et
  les pixels qu'un voisin recouvre sont EXCLUS plutôt que le glyphe entier
  (les exclure entièrement ne laissait que **3** portraits lisibles sur 16 :
  au spawn, cette carte est assez dense pour que la plupart des plateaux se
  touchent).

---

## LE COÛT — TOUJOURS UN SEUL DRAW CALL

Banc CH38/CH40, protocole de CH44 axe 5, CH46 axe C et CH47.

```
référence (minimap cachée) #1   total_prims 71 531   total_calls 315
référence (minimap cachée) #2   total_prims 71 531   total_calls 315
PLANCHER DE BRUIT                0 prim / 0 calls
avec la minimap CH48            total_prims 71 579   total_calls 316
DELTA                           +48 prim / +1 call     (anneaux compris : +80 prim / +1 call)
CH47 publié                     +62 prim / +1 call
CH46 publié                     +76 prim / +1 call
```

**Un draw call, fond compris.** L'atlas runtime fait **256 × 700** pour
**78 cellules** ; la planche versionnée pèse **25 698 octets** sur disque et
est packée une fois.

⚠️ **La référence n'est pas celle de CH47** (71 609 / 311) : ce n'est pas le
même arbre et pas la même carte cachée. C'est le **RAPPORT** qui traverse,
pas la valeur absolue — et rien ici ne dit quoi que ce soit du device
(llvmpipe contre WebGL2 sous Safari), ni du temps CPU du corps de `_draw`.

---

## CE QUE CE LOT N'A PAS ÉTABLI

1. **Aucun chiffre device, aucune validation device.** Palier 1 seulement.
   C'est exactement ce que CH46 puis CH47 ont appris à leurs dépens : deux
   lots verts, deux fois illisible sur device.
2. **Le char à voile et le voilier restent la même image.** Documenté, gaté
   comme un fait, non réparé — cela demanderait un modèle.
3. **La lisibilité sous pluie et sous neige reste NON ÉVALUÉE.** Le plan est
   cuit une fois, sur la palette de base. Troisième lot de suite à le dire.
4. **Un glyphe qui déborde sur le lavis hors-monde n'a pas de bord là.**
   `OUT_TONE` rend à L 0,005 et une keyline noire aussi. Compté et rapporté
   par la sonde (0 échantillon concerné au spawn), pas caché.
5. **Les quatre cellules que le monde livré ne produit jamais** (joueur
   fusionné, joueur clampé, lieu clampé, PNJ clampé) restent non gatées au
   pixel à l'écran ; elles le sont désormais sur l'ATLAS, ce qui est un progrès
   sur CH47 mais pas la même chose.
6. **Le coût CPU du `_draw` a encore augmenté** (un quad d'anneau de plus par
   glyphe) et n'est toujours pas mesuré en millisecondes.
