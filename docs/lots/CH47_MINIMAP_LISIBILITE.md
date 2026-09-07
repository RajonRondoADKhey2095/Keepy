# CH47 — La lisibilité de la minimap (7 septembre 2026)

> Base : `origin/staging` au commit `edc60d0` (merge CH46), arbre
> `ea005aed3f2e859c47b0b1fd4857bc898a333c34`. Branche
> `claude/minimap-readability-ch47-3rugvg`, partie de l'arbre de `staging`
> et **pas** de celui de `main`.
>
> **Vérification de concurrence faite AU DÉBUT** (`git fetch --all --prune`,
> comparaison par **hash d'arbre** et non par nom) : aucune ref `ch47`
> distante, `origin/claude/ch46-minimap-permanente-br1e1b` **est ancêtre de
> `staging`** (`merge-base --is-ancestor`), et `origin/main` ne l'est pas
> (il porte un commit CI de plus). Aucune session concurrente.

---

## LE MOTIF, ET CE QU'IL DIT VRAIMENT

Mathieu, sur device, après CH46, verbatim :

> « je ne comprends rien a cette map, il y a plein de points, on n'arrive pas
> a distinguer les amis de Keepy des vehicules. On arrive juste a distinguer
> les differentes zones, mais les petits points ne servent a rien. »

CH46 est sorti **69 assertions vertes** sur cette carte. Les 69 étaient
vraies. **Aucune ne demandait si les quatre TYPES se ressemblent** — et le
lot a livré trois types sur quatre avec **exactement la même icône** :

| type | CH46 | forme | rayon |
|---|---|---|---|
| player | `ICON_PLAYER` | disque | 4,2 |
| vehicle | `ICON_DOT` | disque | **3,9** |
| npc | `ICON_DOT` | disque | **3,9** |
| place | `ICON_DIAMOND` | losange | 4,2 |

`vehicle` et `npc` étaient **la même cellule d'atlas**, au pixel près. Seule
la teinte les séparait — et la teinte est précisément le canal que
`CLAUDE.md` documente comme inutilisable pour une séparation à quatre :
le WCAG ne score **aucune** séparation à l'intérieur d'une bande de
luminance, et **aucune sonde de ce dépôt ne mesure la teinte**. Le rapport
device de Mathieu n'est pas une opinion sur une carte correcte ; c'est la
mesure de la seule chose que CH46 n'avait pas gatée.

---

## ⚠️ CE QUE LA RECON A TROUVÉ AVANT TOUTE DÉCISION : SEPT PNJ SUR UN PIXEL

`MinimapDensityRecon` (sonde jetable, supprimée avant le commit) a projeté
les 37 marqueurs dans les pixels du widget, sous `xvfb + opengl3`,
1080 × 1920, météo sun, rect asserté non dégénéré. Résultat au spawn :

```
37 marqueurs sur un plan de 155 x 280 px      0,8821 u/px
plus proche voisin, tous types : min 0,00  médiane 5,02  moyenne 8,49 px
plus proche voisin, même type  : min 0,00  médiane 16,10 moyenne 14,03 px
```

Et le détail qui a changé le lot :

```
npc  Bird0   at (71.3, 53.3)      npc  Cat     at (71.3, 53.3)
npc  Bird1   at (71.3, 53.3)      npc  Fawn    at (71.3, 53.3)
npc  Bird2   at (71.3, 53.3)      npc  Beaver  at (71.3, 53.3)
npc  Boar    at (71.3, 53.3)      player Keepy at (71.3, 53.3)
```

**SEPT des NEUF marqueurs PNJ étaient empilés sur un seul pixel — l'origine
du monde — sous le marqueur de Keepy lui-même.** Les quatre karts tenaient
dans **2,80 px**, les trois portails dans **6,78 px**, phare et terrier dans
**9,63 px**.

### Le blind check qui a transformé une observation en défaut

Une seconde lecture à **900 frames simulées** (15 s à 60 fps) est revenue
**byte-identique** à celle du spawn. « Rien n'a bougé » est exactement
l'assertion que `CLAUDE.md` dit de ne jamais croire : elle passe
gratuitement contre un monde qui n'a jamais tourné. Un témoin a donc été
ajouté et relu aux deux bouts :

```
WITNESS frames  24  ticks   9 560 ms     WITNESS frames 924  ticks 158 637 ms
   Bird0 .. Beaver   world (0, 0, 0)        Bird0 .. Beaver   world (0, 0, 0)
```

Le monde **a** tourné — 900 frames, 149 s de plus au compteur — et les sept
sont restés là. Ce n'était pas un artefact de sonde.

### La cause, et elle est d'une ligne

`HubBoar`, `HubCat`, `HubFawn`, `HubBeaver` sont des **contrôleurs vides**
qui ne quittent jamais l'origine ; l'animal est leur enfant `HubCritter`,
publié par `critter()`. CH46 avait écrit `MinimapMarkers.mark(self, NPC)`
dans les quatre. Le marqueur était donc **sur le contrôleur**, pas sur la
bête. Les trois oiseaux, eux, sont bien à l'origine : ils sont
`visible = false` tant que Keepy n'est pas dans la couronne.

**« on n'arrive pas à distinguer les amis de Keepy » avait une seconde
lecture, littérale : les amis n'étaient jamais là où la carte les mettait.**

Corrigé en déplaçant la ligne sur `_critter`, à son propre site de
construction (doctrine CH46 : un marqueur s'ajoute d'une ligne là où
l'entité est bâtie, jamais par un chemin). Re-mesuré :

```
npc  Critter at ( 61.7, 116.2)   sanglier      npc  Critter at ( 61.7, 157.6)  faon
npc  Critter at ( 66.4, 114.8)   chat          npc  Critter at ( 93.9, 155.5)  castor
```

⚠️ **Cette correction ne retire AUCUN marqueur** — décision 1 de Mathieu
respectée à la lettre : les 37 restent, et la sonde l'asserte (`37`).

⚠️ **Et elle n'est pas gatable au pixel.** Quel nœud porte un marqueur n'est
pas une propriété DESSINÉE : au pixel, un marqueur à l'origine ressemble à
un marqueur. L'assertion ajoutée est donc **structurelle et le dit** — pour
chacun des quatre contrôleurs, `critter()` est dans le groupe et le
contrôleur ne l'est pas.

---

## LEVIER A — TROIS RANGS DE SAILLANCE

Chaque type a désormais **sa forme ET sa taille**. La teinte suit le rang en
**luminance** et n'est qu'un second indice.

| rang | type | forme | rayon de remplissage | portée dessinée **mesurée** | teinte | luminance |
|---|---|---|---|---|---|---|
| 1 | player | disque | 7,0 | **8,25 px** | (1,00 ; 0,86 ; 0,16) | **0,8392** |
| 1 | vehicle | losange | 7,6 | **8,00 px** | (1,00 ; 0,58 ; 0,28) | **0,6476** |
| 2 | npc | triangle | 3,0 (inrayon) | **8,06 px** | (0,30 ; 0,52 ; 0,90) | **0,5007** |
| 3 | place | petit disque | 2,7 | **4,00 px** | (0,46 ; 0,31 ; 0,62) | **0,3643** |

La cellule d'atlas passe de 14 à **25 px** — c'est la CELLULE, pas l'encre :
un lieu en encre 8 px, un véhicule clampé 19. Contour noir de **1,4 px**
partout, `modulate` multipliant (doctrine CH46 : un contour noir survit à
n'importe quelle teinte), donc chaque marqueur garde son arête sombre contre
l'herbe, le sable, la bruyère, la pelouse ou la mer.

⚠️ **La teinte du joueur n'est PAS rouverte** : CH46 l'avait mesurée contre
la ligne pâle du circuit et en avait tiré ce jaune chaud. Les trois autres
ont bougé pour **entrer dans l'ordre des rangs** — le bleu PNJ de CH46 était
à 0,577 de luminance, **plus clair** que son orange véhicule à 0,535 :
l'animal criait plus fort que le kart.

⚠️ **Le rayon rang 3 est 2,7 et pas 2,3, et c'est la sonde qui l'a dit.** À
2,3 le cœur pleinement opaque du point fait neuf pixels avant le placement
sous-pixel du widget, et `MinimapProbe` a lu **QUATRE** pixels de la teinte
là où elle en veut six. Quatre pixels device de teinte, c'est plus petit que
lisible : l'assertion avait raison sur l'art, pas tort sur elle-même. Elle
n'a pas été faite taire (doctrine `CLAUDE.md`).

---

## LEVIER B — LA FUSION DES GRAPPES

Deux marqueurs du **même type** plus proches que `merge_px(type)` sont
dessinés comme **UN** glyphe : même forme, **une taille au-dessus**, avec le
**centre percé** (le trou noir dit « plusieurs » sans un chiffre que
personne ne lirait à 25 px).

⚠️ **`merge_px` est MESURÉ, jamais écrit.** C'est **deux fois la portée
dessinée de l'icône**, relue sur l'atlas cuit (`_measure_reach` dans
`_paint_icon`) — c'est-à-dire exactement « ces deux icônes se touchent ».
Un littéral ici dériverait le jour où un rayon change, et rien ne le dirait.

| type | portée | `merge_px` | en unités monde |
|---|---|---|---|
| player | 8,25 px | **0,00 px** | — |
| vehicle | 8,00 px | **16,00 px** | 14,11 u |
| npc | 8,06 px | **16,12 px** | 14,22 u |
| place | 4,00 px | **8,00 px** | 7,06 u |

**KEEPY NE FUSIONNE JAMAIS**, et c'est écrit comme un seuil nul et non
comme un `if` au site d'appel : un seul endroit à lire, un seul à gater.

**Regroupement par MENEUR, pas par liaison simple**, et la différence porte :
une liaison simple enchaîne, donc trois marqueurs à 15 px l'un de l'autre
s'effondreraient en un glyphe posé à 30 px d'un membre qu'il prétend
représenter. Ici chaque membre est à moins d'un `merge_px` du **meneur**, le
glyphe est dessiné **SUR le meneur** — la position d'un membre réel, jamais
un barycentre qui peut ne rien recouvrir — et la borne est donc exacte et
assertable. Ordre stable (ouest→est, puis nord→sud, puis id d'instance) pour
que le meneur ne dépende pas de l'ordre d'énumération du groupe.

**Clampé et en-cadre ne fusionnent jamais ensemble** : ils disent deux
choses différentes, dont l'une est « je ne suis pas sur cette carte ».

Résultat mesuré au spawn — **37 marqueurs, 30 glyphes** :

```
player    1 marqueur  ->  1 glyphe
vehicle  12 marqueurs ->  9 glyphes   {Kart_0, Kart_1, Kart_2, Kart_3}
npc       9 marqueurs ->  6 glyphes   {sanglier, chat} {Bird0, Bird1, Bird2}
place    15 marqueurs -> 14 glyphes   {HubPortal, Area3D}
```

⚠️ **Le troisième portail ne fusionne PAS, et c'est la borne du meneur qui
le veut** : il est à 12,2 px du meneur pour un seuil de 8,0. La carte
affiche donc un glyphe fusionné et un point simple à côté — ce qui est la
vérité géométrique, pas un défaut. Une liaison simple l'aurait avalé au prix
de la borne.

---

## LE CRITÈRE DE SUCCÈS — LA MATRICE, ET COMMENT ELLE EST MESURÉE

L'assertion que CH46 n'a jamais écrite. Elle est bâtie comme l'a finalement
été le test de clamp de CH46 : **par COUVERTURE, pas par TON**. Ce qui
sépare deux icônes n'est pas leur couleur, c'est **quelle part de la boîte
elles encrent**.

**Chaque type est lu contre SA PROPRE ligne de base.** Les quatre groupes
sont retirés de la carte, une frame est lue (le plan nu), **un** type est
remis, une frame est lue : un pixel est de l'ENCRE quand les deux diffèrent.
C'est ce qui rend le nombre indépendant du ton **et** de la bande peinte
en dessous — un test de ton absolu aurait mesuré le sol autant que le
marqueur. Boîte de 25 × 25, seuil absolu 0,06 par canal.

### Le plancher de bruit, mesuré AVANT toute comparaison

Le plan est dessiné à alpha 0,92 : 8 % d'une scène 3D **en mouvement**
traverse. Deux frames de base, même écart de frames, mêmes boîtes :

```
plancher de bruit : 28 boîtes vides, pire couverture   0,0000
```

### LA MATRICE DES SIX PAIRES

```
       player   vs vehicle   0,1024
       player   vs npc       0,2016
       player   vs place     0,2976
       vehicle  vs npc       0,0992
       vehicle  vs place     0,1952
       npc      vs place     0,0960
       pire paire  npc/place  0,0960   plancher 0,0000   -> 960x le plancher
```

Couvertures absolues, et l'ordre des rangs se lit dedans :

| glyphe | couverture | pic de delta |
|---|---|---|
| player simple | **0,4128** | 0,718 |
| vehicle simple | **0,3104** | 0,714 |
| npc simple | **0,2112** | 0,710 |
| place simple | **0,1152** | 0,710 |
| vehicle **fusionné** (4 karts) | 0,4800 | 0,816 |
| npc **fusionné** (2 bêtes) | 0,3616 | 0,808 |
| place **fusionné** (2 lieux) | 0,2288 | 0,765 |
| vehicle **clampé** | 0,5136 | 0,549 |

Fusionné contre simple : **+0,1696** (vehicle), **+0,1504** (npc),
**+0,1136** (place). Clampé contre simple : **+0,2032** (vehicle).

### ⚠️ Les variantes que le monde livré NE PEUT PAS produire

Dites à voix haute plutôt que sautées en silence, et gatées autrement :

* **player fusionné** — impossible **par règle** : `merge_px(player)` vaut
  zéro, et c'est cette égalité qui est assertée.
* **player clampé** — impossible : la région clampe Keepy avant que la carte
  ne le voie.
* **place clampé** — impossible : la sonde compte les lieux hors cadre et
  exige **0**.
* **npc clampé** — aucun animal ne sort de la région au spawn.

Leurs cellules d'atlas sont cuites par la même règle uniforme que les
autres et **ne sont pas gatées au pixel**. C'est une limite de ce lot, pas
un vert.

### ⚠️ Deux entités DÉPLACÉES par la sonde pour que la mesure existe

* Le **voilier** est poussé hors cadre — mais à **z −20** et non au z −110
  de la PHASE 5 : pinglé à −110 le glyphe clampé tombe à **18,2 px** du
  marqueur du yacht, donc **dans** la boîte lue, et la couverture aurait été
  celle des deux. Au nord, le plus proche glyphe véhicule est à 72 px, et
  l'isolement est **asserté**, pas supposé.
* Un **ponton** est garé à côté de la cabane, parce que la seule grappe de
  lieux du monde livré a son glyphe à 12,2 px du troisième portail. Sans ça
  la cellule « lieu fusionné » serait la seule de l'atlas que rien ne lit.
  Les deux sont remis en place, et la remise en place est assertée.

---

## LE COÛT — UN SEUL DRAW CALL, ET MOINS CHER QU'AVANT

Banc CH38/CH40, protocole de CH44 axe 5 et CH46 axe C : `xvfb + opengl3`,
1080 × 1920, `SubViewportContainer.stretch = false`, viewport forcé, météo
sun, Keepy au spawn.

```
reference (no minimap) #1   total_prims 71 609   total_calls 311
reference (no minimap) #2   total_prims 71 609   total_calls 311
PLANCHER DE BRUIT           0 prim / 0 calls
avec la minimap CH47        total_prims 71 671   total_calls 312
DELTA                       +62 prim / +1 calls
CH46 publié                 +76 prim / +1 call
```

⚠️ **La référence est reproduite AU CHIFFRE PRÈS** (71 609 / 311, le nombre
publié par CH46) — c'est ce qui donne à ce banc le droit de publier un
chiffre neuf, et pas la couleur d'une sonde.

**Un draw call, fond compris, et 14 primitives de MOINS que CH46.** La
raison n'est pas une optimisation : la fusion dessine **31 quads** (30
glyphes + le fond) là où CH46 en dessinait 38, et l'atlas reste **une seule
texture** — douze cellules de 25 px, 300 × 305, même matériau, même type de
commande, donc le renderer canvas coalesce toujours l'ensemble.

⚠️ **Ce que ce banc NE dit PAS**, repris sans être adouci : rien du device
(llvmpipe contre WebGL2 sous Safari), rien du temps CPU du corps de `_draw`
— qui a **augmenté**, puisque le regroupement par meneur est quadratique en
nombre de membres d'un groupe (12 véhicules, donc 66 distances par frame) —
rien de la mémoire. C'est le **rapport** qui devrait traverser.

---

## LA SONDE, ET LES PASSES ROUGES

`MinimapProbe` — **11 phases, 125 assertions, ALL GREEN, 0 rouge**, sous
`xvfb-run --rendering-driver opengl3 --resolution 1080x1920 --fixed-fps 60`.

Ce que CH47 a dû réparer dans la sonde héritée, et les deux fois où c'est
sa propre garde qui l'a attrapé :

* **PHASE 4 lisait `members()`, la carte dessine `clusters()`.** Une sonde
  qui cherche six marqueurs de kart là où le widget en dessine un en
  déclarerait cinq manquants.
* **⚠️ LE RAYON D'OCCLUSION ÉTAIT LA CELLULE, PAS L'ENCRE.** CH46 utilisait
  `ICON_PX` parce que sa cellule ÉTAIT son encre. Reporté sur une cellule de
  25 px, « à moins d'une cellule d'un glyphe dessiné après » a exclu **les
  quatorze** glyphes de lieux, et la phase est sortie **0/0** — le vert le
  plus vide qui soit. C'est le garde `tried > 0` de CH46 lui-même qui l'a
  attrapé, celui que son propre commentaire justifiait deux lignes plus haut.
* **PHASE 5 demandait `project()` sans inset.** L'inset n'est plus une
  demi-cellule mais la portée du glyphe : la question posée avec le défaut 0
  lit le bord non-inseté et répond `155,0 sur 155`.
* **Le point central ne peut plus être la sonde de teinte** : un glyphe
  fusionné est **percé** en son centre. La phase compte les pixels de la
  teinte **dans la portée** du glyphe.

| passe | neutralisation | rouges attendus | obtenus |
|---|---|---|---|
| **G** | aucune (livré) | 0 | **0** (125 checks) |
| **R1** | l'icône npc redevient celle du véhicule (le défaut CH46) | 2 | **2** |
| **R2** | la fusion coupée (`merge_px` toujours nul) | 6 | **6** |
| **R3** | `HubBoar` remarque `self` (le contrôleur) | 2 | **2** |
| **R4** | les teintes npc et véhicule échangées | 1 | **1** |
| **R5** | l'inset de clamp ignoré dans `project()` | 2 | **2** |

Tous les fichiers touchés ont été restaurés et vérifiés **byte-identiques**
par `cmp`.

### ⚠️ MOUSE_FILTER_IGNORE — RE-PROUVÉ, PAS SUPPOSÉ

La PHASE 8 de CH46 est intacte et rejouée : nœud sentinelle en dernier
enfant du hub, 14 canaux de tap armés, vrais `InputEventScreenTouch` poussés
au centre du widget.

```
IGNORE (livré)   2 événements, canal tapped_ground
STOP   (blind)   0 événement,  0 canal
IGNORE (rendu)   2 événements, 1 canal
```

---

## CE QUE CE LOT N'A PAS ÉTABLI

1. **Aucun chiffre device, aucune validation device.** Palier 1 seulement.
   La ligne `TOTAL` de `HubPerfOverlay` reste la lecture à faire sur iPhone.
2. **La lisibilité sous pluie et sous neige reste NON ÉVALUÉE**, exactement
   comme CH46 l'avait signalée. Le plan est cuit une fois, sur la palette de
   base.
3. **Les trois oiseaux restent des marqueurs fantômes.** Ils sont
   `visible = false` tant que Keepy n'est pas dans la couronne, et pourtant
   dessinés — à l'origine du monde, sous Keepy. La fusion les réduit à **un**
   glyphe, mais un marqueur pour quelque chose d'invisible reste un
   marqueur pour rien. **Les retirer serait retirer un marqueur, ce que la
   décision 1 interdit** : c'est une question pour Mathieu, pas une décision
   de session.
4. **Le coût CPU du `_draw` a augmenté et n'est pas mesuré** (regroupement
   quadratique par groupe, 66 distances par frame pour les véhicules).
5. **Quatre cellules d'atlas ne sont jamais dessinées dans le monde livré**
   (player fusionné, player clampé, place clampé, npc clampé) et ne sont
   donc pas gatées au pixel.
6. **La distinction reste mesurée en COUVERTURE, pas en perception.** Une
   couverture séparée à 0,0960 contre un plancher de 0,0000 dit que les deux
   glyphes ne sont pas la même chose ; elle ne dit pas qu'un œil les sépare
   à bout de bras sur un iPhone. **Seul le device tranche ça**, et c'est
   exactement ce que CH46 a appris à ses dépens.
