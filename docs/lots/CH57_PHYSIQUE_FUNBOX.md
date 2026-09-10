# CH57 — LOT 1 : la première physique réelle du hub (funbox seule + planche `CharacterBody3D`)

**9 septembre 2026.** Premier lot d'IMPLÉMENTATION de la chaîne physique.
CH55 a conçu, CH56 a mesuré et conclu **AFFORDABLE** ; ce lot construit le
minimum que cette conclusion autorise — **un** module solide, **un** corps
mobile — et il le construit **derrière un interrupteur**, parce que c'est
l'interrupteur qui transforme le lot en **mesure de F**.

Livrables : `scripts/hub/SkateBoardBody.gd` (neuf),
`scripts/dev/SkatePhysicsProbe.gd` + `.tscn` (sonde **permanente**,
**43 assertions en headless, 45 sous xvfb** — les deux de plus sont les
compteurs moteur, qui n'ont de sens que sous un vrai driver), `SkateparkMesh.funbox_pieces()`, le collider de la funbox,
le second jeton de `DevTools`, et ce fichier.

---

## 0. LA BASE, ET LA GARDE DE CONCURRENCE

Branche ouverte sur `main` (`2876f27`) et **re-basée sur `origin/staging`**
(`f9f2ab7`) avant la première lecture : `merge-base --is-ancestor main
origin/staging` → vrai, et les ARBRES le confirment (`9a1d2a9` pour `main`,
`08cb3ce` pour `staging`). CH50 → CH56 vivent sur `staging` ; une session
menée sur `main` aurait lu un hub sans `HubSkatepark`, sans
`SkateparkMesh` et sans `PhysicsCostProbe`.

Garde faite **au début et par ARBRE**, jamais par nom :

| ref | verdict |
|---|---|
| `origin/claude/funbox-physique-ch57-lhtu63` (mon homonyme) | arbre `9a1d2a9` = celui de `main`, **aucun travail dessus** |
| `origin/claude/physics-cost-probe-v5q67p` | ancêtre de `staging` → **déjà mergée** (CH56) |
| `origin/claude/keepy-hub-physics-foundation-siqdqo` | ancêtre de `staging` → **déjà mergée** (CH55) |
| `…skateboard-drivability-north-lgmqk8`, `…budget-nord-v5a3id`, `…trick-minijeu-xyuy9a`, `…zone0-nord-ezbguf` | toutes ancêtres de `staging` (CH54, CH52, CH51, CH50) |

Aucune session concurrente vivante.

⚠️ **Et ce sandbox n'avait PAS de Godot.** Le binaire a été téléchargé
(`Godot_v4.3-stable_linux.x86_64.zip`), **taille vérifiée contre le
`Content-Length` avant extraction** — **50 276 070 octets**, exactement le
chiffre que `CLAUDE.md` publie pour l'éditeur, ce qui ferme le piège du
téléchargement tronqué à exit 0.

---

## 1. ⚠️ L'IMPORT A MENTI DEUX FOIS AVANT DE DIRE VRAI

`CLAUDE.md` documente qu'un import Godot tronqué produit un **faux rouge**
de sonde et qu'il faut **compter les `.scn` avant de comparer quoi que ce
soit**. Ce lot a payé la version aggravée : **deux passes d'import
consécutives sont sorties en exit 0 avec un log de DEUX LIGNES**, en
laissant **127 `.glb` sur 127 sans `.scn`** — c'est-à-dire tout le décor,
tous les personnages, tout ce qui n'est pas une texture. La troisième
passe, elle, a réellement travaillé (plusieurs minutes de CPU) et a fermé
la liste à **0 manquant / 154 `.scn`**.

Le premier boot de sonde sur l'arbre tronqué a rendu exactement ce que
`CLAUDE.md` annonce : `Parse Error: Could not preload resource file`,
`Cannot infer the type of "CABIN" constant` — une cascade qui **ressemble à
du code cassé** et qui n'est qu'un import incomplet.

**Contrôle appliqué des deux côtés avant la moindre comparaison** :
l'arbre de branche et l'arbre de référence (`origin/staging`, worktree
séparé) portent **762 fichiers dans `.godot/imported/` et 154 `.scn`**,
au fichier près.

---

## 2. CE QUE LE LOT CONSTRUIT, ET LE PÉRIMÈTRE QU'IL NE FRANCHIT PAS

| pièce | ce qu'elle fait | ce qu'elle ne fait pas |
|---|---|---|
| `DevTools.physics_enabled()` | second jeton `keepyphys` **sous** `enabled()`, caché à la première réponse | n'est pas un gate parallèle, et **n'ouvre rien pour un joueur** |
| `SkateparkMesh.funbox_pieces()` | 3 pièces convexes **écrites à la main** (une boîte, deux prismes) | ne touche à aucun autre module |
| `HubSkatepark._maybe_collide()` | un `StaticBody3D` **enfant du nœud dessiné** de la funbox | quatre modules restent sans collider |
| `SkateBoardBody` | `CharacterBody3D`, profil d'allure CH54 intégré, plancher `HubSurface`, clôture `HubRegion`, garde de calage | **ne lit pas `touch.input`** — ce n'est pas un véhicule piloté |
| `HubTransport.mount_board()` / `leave_board()` / `set_board_target()` | le contrat porteur, cinquième usage | pas de caméra de poursuite, pas de HUD |
| `HubTapInput` | **une** condition : en roulant, tout tap va à la planche | ne court-circuite pas `_unhandled_input` |
| `HubPerfOverlay` | une ligne `PHYS` d'affichage | **ne touche pas `snapshot()`**, donc pas `COZY_STATS` |

**Le bol, les deux quarterpipes et le rail n'ont AUCUN collider**, et c'est
la consigne de CH56 §12.4 tenue à la lettre : un bol décomposé en hulls
convexes est **géométriquement faux**, CH56 n'en a mesuré que le coût.

---

## 3. ⚠️ LA DÉCOUVERTE DU LOT : UN DESSOUS PLAT NE PEUT PAS MONTER UNE RAMPE

C'est la trouvaille qui vaut d'être remontée, et elle a été **mesurée, pas
raisonnée**. La première version donnait à la planche la forme évidente :
une `BoxShape3D` aux dimensions du deck, dessous **affleurant à y = 0**,
c'est-à-dire au niveau où `HubSurface` pose la planche.

Résultat de PHASE R, première exécution :

```
     with collider    path 3.72 u   max y 0.000   over-deck ticks 0   supported 0   arrived false
```

**3,72 u puis plus rien** — soit exactement la demi-longueur de la planche
(0,46) avant le pied de la rampe. Elle ne traversait pas et elle ne montait
pas : elle **s'arrêtait à côté**, le troisième des trois résultats possibles
et le seul qu'aucune assertion de hauteur seule n'aurait distingué du
second.

Le vidage de contacts par tick donne la cause en un nombre :

```
t20  pos (0.000, 0.0000, 48.2809)  floor=false wall=true
     n=(0, 0, 1) d=0.0009   n=(0, 0, 1) d=0.0001
```

La normale de contact est **`(0, 0, 1)`** — un **mur vertical** — contre une
rampe dont la vraie normale est `(0, 0.861164, 0.508327)`. La vraie normale
de pente n'est apparue **qu'une seule frame sur trente** (t28), noyée sous
deux contacts de mur sur la même frame.

**Le mécanisme** : la pièce de rampe s'effile en une **arête d'épaisseur
nulle à y = 0**, et le dessous de la boîte est une **face plate à y = 0**.
Les deux sont **COPLANAIRES**, donc la direction de translation minimale qui
les sépare est **horizontale**, et le moteur classe une pente de 30,6° en
mur de 90°. Ni le hull, ni l'enroulement, ni la couche, ni `floor_max_angle`
n'étaient en cause — **c'est la PLANÉITÉ du dessous** qui l'était.

**La cure** : une **capsule couchée** le long de la planche. Elle n'a aucune
face inférieure — elle touche le sol par une **ligne tangente** et une arête
par un **point** —, donc la direction de séparation contre la pointe de
rampe est celle qui va de l'axe de la capsule à l'arête, c'est-à-dire, au
premier contact, **droit vers le haut**. Mesuré, même station, même run :

```
t20  pos (0.000, 0.0000, 48.1975)  floor=true   n=(0, 0.861164, 0.508327)
t21  pos (0.000, 0.0467, 48.1080)  floor=true
t27  pos (0.000, 0.3942, 47.5193)  floor=true
t34  pos (0.000, 0.8811, 46.6945)  floor=true
t36  pos (0.000, 0.8509, 46.3612)  floor=true   n=(0, 1, 0)
end pos (0, 0, 40.42764)
```

La rampe est lue comme un **sol** dès le premier contact, la planche monte
de 0,047 à 0,881 en quatorze ticks, roule le tablier à **0,8509** (0,85
authored + la marge de sécurité du moteur) et repart de l'autre côté.

**Et la capsule ne coûte rien en justesse là où la justesse compte** : sa
ligne tangente est à **exactement y = 0** dans l'espace de la planche, donc
une planche posée sur le tablier a son **ORIGINE à la hauteur du tablier**,
sans facteur de correction à soustraire — ce qui est précisément ce qui
permet à PHASE R de gater le trajet contre le **0,85 authored du module**
plutôt que contre un epsilon réglé sur l'artefact.

> **Doctrine dégagée** : dans GodotPhysics3D, **deux faces coplanaires qui
> se rencontrent par la tranche donnent un contact dégénéré dont la normale
> est horizontale**. Un corps censé MONTER une géométrie posée sur le même
> plan que lui ne peut pas avoir de face inférieure plate à ce plan. C'est
> le pendant collision du piège CH39 (« l'assertion d'orientation ne se
> relit pas, elle se rend ») : ici l'assertion « la rampe fait 30,6° » est
> vraie, l'angle de `floor_max_angle` est bon, et le moteur voit quand même
> un mur — seul le **vidage de normales par tick** le dit.

---

## 4. QUI POSSÈDE LE SOL — D1 APPLIQUÉ, ET LA LIGNE QU'IL A FALLU INTERPRÉTER

D1 dit : *« `HubSurface` reste la SOURCE UNIQUE du sol. Pas de
`HeightMapShape3D`, pas de seconde orthographe. La physique bloque
LATÉRALEMENT seulement. »*

Pris à la lettre — la physique n'écrit jamais un Y — le lot **ne peut pas
atteindre son propre but**, qui est que la planche MONTE sur la funbox. La
ligne est donc lue de la seule façon qui garde ses deux moitiés vraies, et
c'est **la seule interprétation que ce lot s'est autorisée** :

* **LE TERRAIN est à `HubSurface`, entièrement.** Aucun `HeightMapShape3D`,
  aucun collider sous la pelouse, aucune seconde grille. `_hub_floor()`
  est tout le mécanisme : après chaque `move_and_slide`, un corps passé
  sous la surface est **remis dessus**. `HubSurface` n'est pas consulté PAR
  le moteur, il le **surclasse**.
* **CE QUI SE TIENT SUR LE TERRAIN est au collider.** Une funbox n'est pas
  du sol — c'est un prop POSÉ sur du sol, et ses 20 triangles sont la seule
  chose au monde qui ait le droit de mettre la planche au-dessus de
  `height_at`.

L'invariant, énoncé pour qu'une sonde le gate, et **PHASE R le gate à
CHAQUE tick et pas à la fin** :

> `global_position.y >= HubSurface.height_at(flat)`, toujours ; strictement
> supérieur **seulement** pendant qu'un module la tient.

Mesuré : **0 violation** sur les trois trajets de PHASE R/N, et la moitié
latérale de D1 mesurée séparément (PHASE L) — contre la face est verticale
du caisson la planche est **arrêtée à x = 2,661 pour une face à 2,200**
(2,200 + le rayon 0,13 de la capsule + la marge), **max y 0,000**, et la
garde de calage lâche la cible au lieu de meuler indéfiniment.

---

## 5. CE QUE LA SONDE PROUVE AVANT DE PUBLIER — 43 ASSERTIONS (45 SOUS XVFB), 0 ROUGE

`SkatePhysicsProbe`, **headless** (CH56 §8 : une sonde qui ne lit aucun
pixel et mesure du comportement ne va pas sous llvmpipe ; ses témoins sont
le serveur physique et des transforms, dont aucun n'a de rapport avec le
rendu).

### 5.1 PHASE S — l'interrupteur répond, DANS LES DEUX SENS

Blind check sur le gate lui-même, **positif d'abord** : « la physique est
éteinte pour un joueur » est une assertion d'ABSENCE et passe gratuitement
tant qu'on n'a pas montré que l'interrupteur sait dire OUI.

Et l'assertion qui protège les 90 autres sondes du dépôt :
`DevTools.enabled()` est **VRAI** en headless (elle est asserée vraie, sans
quoi le test suivant serait vide), et `physics_enabled()` y répond
**FAUX** — il ne suit que la ligne de commande. Un gate physique écrit sur
`enabled()` seul aurait allumé les colliders **à l'intérieur** de
`SkateDriveProbe`, `SkateparkProbe` et `SkateTraverseProbe`, et la table
croisée aurait comparé deux jeux différents en appelant l'écart une
régression.

### 5.2 PHASE G — les pièces contre le maillage DESSINÉ

Le gate est une **ÉGALITÉ d'ensembles de points**, pas une inclusion :
une inclusion serait satisfaite par une seule pièce, ou par aucune.

```
     piece point counts [8, 6, 6]   union distinct 12   drawn distinct 12
```

12 = 12, et les trois pièces sont 8 / 6 / 6 — une boîte et deux prismes
triangulaires. Le triangle de la funbox est restitué à **20**, le chiffre
que CH56 §3.1 publie.

**Blind check** : les mêmes pièces construites avec une rampe **0,10 u plus
longue** doivent NE PAS correspondre. Elles ne correspondent pas.

### 5.3 PHASE W — le témoin est le SERVEUR

CH56 §3.3 : compter des nœuds prouve qu'on a construit des nœuds. La
requête `intersect_shape` est lancée **depuis une physics frame** (hors
d'elle, le refus est une erreur **plus un résultat vide**, indiscernable du
blind check qui passe) : **4 objets de collision** dans tout le hub — la
funbox, la planche, et les deux que le monde porte déjà. Et **exactement
UN** module sur cinq porte un `StaticBody3D`, ce qui est le périmètre du
lot asserté au lieu d'être décrit.

### 5.4 PHASE R / N — le positif, puis VERT / ROUGE / VERT

| trajet | chemin | max y | ticks au-dessus du tablier (min y) | ticks tenus | arrivé |
|---|---|---|---|---|---|
| **avec collider** | 11,57 u | 0,883 | 9 (**0,851**) | 38 | oui |
| **collider neutralisé** | 11,61 u | 0,000 | 9 (**0,000**) | 0 | oui |
| **collider restauré** | 11,57 u | 0,883 | 9 (**0,851**) | 38 | oui |

La neutralisation est faite **à l'exécution** (la couche du `StaticBody3D`
est mise à 0, puis rendue), donc il n'y a **rien à restaurer à la main et
rien à `cmp` ensuite** — et elle court dans les deux sens, ce qu'un seul
rouge ne prouverait pas. Les deux runs neutralisé/restauré partagent leurs
deux instruments (le chemin parcouru, les 9 ticks dans l'empreinte), ce
qui interdit à « il est passé au travers » de vouloir dire « il n'est
jamais venu ».

⚠️ **Les DEUX axes sont gatés ensemble, et ni l'un ni l'autre ne suffit** :
une assertion de hauteur seule passerait pour une planche qui monte et
cale sur le tablier ; une assertion de distance seule passerait pour une
planche qui traverse. C'est la forme CH42 (« un run ne se note jamais sur
l'endroit où il finit »).

### 5.5 PHASE T — la traversée, avec le monde physique VIVANT

Garde-fou 4 du brief : *« par D2 le risque est structurellement nul, mais
CONFIRME-LE plutôt que de le supposer. »*

```
     diagonal: hops=66 frames=1123  18.717 s   (published 66 / 18.700 s)
```

**66 hops, à la frame près** du chiffre publié (1 123 contre 1 122 frames,
soit 0,017 s — un frame de comptage de boucle, sous le seuil d'une frame
que l'assertion pose). L'argument de la forme B — un tween écrit
`global_position` et ne consulte aucun collider — est donc **mesuré** et
plus seulement structurel.

### 5.6 ⚠️ PHASE B — FAUSSE DEUX FOIS AVANT D'ÊTRE VRAIE, ET LES DEUX FOIS C'ÉTAIT L'INSTRUMENT

CH56 fait reposer son verdict sur une phrase : *« un collider ne dessine
rien. C'est exactement la monnaie dont CH52 §8.3 mesure qu'il n'en reste
AUCUNE au bord nord. »* La sonde du park ne peut pas la vérifier (elle
tourne interrupteur bas), donc la comparaison se fait ici, en construisant
le hub **deux fois dans le même run**. Il a fallu trois versions.

**Version 1 — deux stations différentes.** Le hub ON était lu là où la
phase de traversée avait laissé Keepy (le coin opposé du plateau), le hub
OFF à son spawn. Verdict : **−6 957 primitives et −20 draw calls**. Ce qui
l'a démasqué est que le **recensement de SCÈNE ne bougeait pas d'un
triangle** sur la même paire : deux frusta différents, pas deux mondes
différents.

**Version 2 — même station, âges différents.** Corrigé pour parquer les
deux hubs au même endroit, la phase a rendu **+678 primitives et +3 draw
calls**, avec un tremblement de **0** sur chaque monde. Le hub ON avait
vécu trois trajets, une neutralisation et une diagonale ; le hub OFF venait
de naître. **C'est le faux-vert CH37 dans l'autre sens** : depuis CH25
l'ours MARCHE vers le feu, les critters bougent, la planche n'est plus
garée où elle l'était — deux lectures d'un même arbre à des âges
différents dérivent plus que deux arbres.

**Version 3 — les deux mondes construits FRAIS, au MÊME ÂGE
(`WORLD_AGE = 24` frames), à la MÊME station**, et la phase est déplacée
**avant le premier trajet** pour que le monde ON n'ait pas eu le temps de
vieillir. Le tremblement de **chaque** monde est publié à côté de son
chiffre (deux lectures consécutives, rien touché), et un compteur dont le
tremblement n'est pas nul est **imprimé et laissé hors du gate** avec la
raison écrite — CH41, jamais un plancher emprunté à une autre station.

```
     nodes_scene   ON      715 (repeat      715)   OFF      715 (repeat      715)   delta 0
     tris_scene    ON   346624 (repeat   346624)   OFF   346624 (repeat   346624)   delta 0
     engine_prims  ON    92342 (repeat    92342)   OFF    92342 (repeat    92342)   delta 0
     engine_calls  ON      394 (repeat      394)   OFF      394 (repeat      394)   delta 0
```

**Zéro sur les quatre, tremblement zéro sur les quatre**, sous
`xvfb + opengl3` où les deux compteurs moteur ont un sens. Le recensement
de scène est celui de `HubPerfOverlay.snapshot()` — **publié par le
producteur, jamais reconstruit par le lecteur** (CH40 : une liste
reconstruite a tort au premier nom oublié). Contrôle d'instrument : le
recensement doit avoir compté quelque chose.

> **Ce qu'il faut retenir au-delà de ce lot** : les deux fausses versions
> ont produit des deltas parfaitement crédibles — le bon signe, le bon
> ordre de grandeur, et un tremblement nul dans le second cas. Ce qui les a
> réfutées n'est pas leur invraisemblance, c'est **un second recensement
> qui ne bougeait pas** à côté du premier qui bougeait. Publier les deux
> est ce qui a permis de lire « l'instrument a changé de pièce » au lieu de
> « la physique coûte des primitives ».

---

## 6. LE COÛT MESURÉ, CONTRE CH56

`PhysicsCostProbe` rejouée **seule** sur l'arbre de ce lot (CH56 §13 next
step 3 : la sonde est permanente précisément pour ça).

`PhysicsCostProbe` rejouée **seule sur la machine** (aucune autre sonde en
parallèle — `CLAUDE.md` : *une sonde à séquence temporelle se rejoue à
charge comparable*), headless, `--fixed-fps 60`, sur l'arbre de ce lot :
**67 assertions, 0 rouge**, exactement le compte de CH56.

⚠️ **Et il faut dire ce que cette comparaison EST** : `PhysicsCostProbe`
mesure un **banc NU**, pas le hub — ce lot ne peut donc pas la faire
bouger, et ce qu'elle vérifie ici n'est pas le coût du lot mais **que
l'arbre du lot restitue la courbe de CH56**. Un banc qui ne la
restituerait plus n'aurait plus qualité à prédire quoi que ce soit.

| grandeur | CH56 (publié) | ce lot | verdict |
|---|---|---|---|
| boucle + 5 modules statiques, aucun corps mobile | 0,0086 | **0,0087** | reproduit |
| **le PREMIER corps mobile** | +0,2189 (runs : 0,2189 / 0,2300 / 0,2152) | **+0,2423** (tremblement de station **0,0177**) | dans la bande, à 0,012 du plus haut des trois runs de CH56 |
| chaque corps mobile de plus | 0,0344 | **0,03438** | reproduit à la 4ᵉ décimale |
| un module statique convexe | ≤ 0,00028 | **≤ 0,00028** | identique |
| une PIÈCE convexe | ≤ 0,000018 | **≤ 0,000018** | identique |
| un module statique trimesh | ≤ 0,00017 | **≤ 0,00022** | même ordre, toujours sous le plancher |
| montée de la courbe A sur 100 modules (convexe) | +0,0100 pour un plancher 0,0284 | **+0,0170 pour un plancher 0,0281** | **toujours SOUS le plancher** |
| `VehicleDrive.step()` marginal (l'incumbent) | 0,00456 / 0,00441 / 0,00455 | **0,00441** | reproduit |
| rapport physique / incumbent (marginal) | ×7,58 | **×7,80** | reproduit |
| bol : pièces convexes contre trimesh | −0,076 pour un plancher 0,4963 | **−0,1310 pour un plancher 0,4542** | **toujours SOUS le plancher, même signe** — D5 reste un arbitrage de sûreté et pas de coût |
| **la forme B telle que CH55 la spécifie** (5 colliders + 1 porteur) | 0,2278 | **0,2590** | c'est le nombre que ce lot livre |

**Ce que le lot ajoute réellement au tick, d'après cette table** : *un*
corps mobile et *un* collider statique de trois pièces — c'est-à-dire
**+0,2423 ms/tick sur cette machine et ≤ 0,00028 pour le collider**, soit
**1,37 % d'une frame à 60 FPS ici**, et ×F sur le téléphone.

⚠️ **Et la borne haute honnête reste celle de CH56 §12.5** : le « premier
corps » est cher **parce qu'il résout un contact**, et le contact mesuré
est une funbox. Une planche qui roulerait dans le bol coûterait davantage
(0,6098 ms/tick mesuré ici pour une capsule dans la cuvette). Le lot 3 hérite
de ce chiffre, pas de 0,259.

---

## 7. TABLE CROISÉE — LES TROIS SONDES EXISTANTES, SUR DEUX ARBRES

Arbre de branche contre worktree `origin/staging` importé séparément, les
deux avec **762 fichiers importés et 154 `.scn`** vérifiés d'abord.

| sonde | driver | branche | référence `origin/staging` | diff |
|---|---|---|---|---|
| `SkateTraverseProbe` | headless | **ALL GREEN — 0 rouge** | **ALL GREEN — 0 rouge** | **byte-identique** |
| `SkateDriveProbe` | xvfb + opengl3 | **ALL GREEN — 0 rouge** | **ALL GREEN — 0 rouge** | **byte-identique** |
| `SkateparkProbe` | xvfb + opengl3 | **ALL GREEN — 0 rouge** | **ALL GREEN — 0 rouge** | **byte-identique** |
| `ProbeTimeoutAudit` | headless | **91 scènes, PASSED** | 90 scènes | +1, `SkatePhysicsProbe` |
| `PhysicsCostProbe` | headless, **seule** | **67 assertions, 0 rouge** | (CH56, même compte) | courbe reproduite, §6 |
| `SkatePhysicsProbe` | headless **et** xvfb | **43 / 45 assertions, 0 rouge** | n'existe pas | neuve |

**Byte-identique** est la forme forte et elle est littérale : les sorties
complètes, filtrées des trois lignes de bruit que `CLAUDE.md` recense
comme bénignes (`Parameter "m" is null`, `Function blocked during in/out
signal`, ALSA sous xvfb), sont **identiques ligne pour ligne** entre les
deux arbres. C'est le résultat que l'inversion off-web de
`physics_enabled()` (§5.1) achète : sans elle, ces trois sondes auraient
tourné **avec les colliders allumés** et n'auraient plus mesuré le jeu de
CH54.

⚠️ **Et la sonde du lot elle-même sort identique sous les deux drivers**
sur tout ce qui est physique — 11,57 u de chemin, max y 0,883, 9 ticks
au-dessus du tablier, 38 ticks tenus, 66 hops / 1 123 frames — ce qui est
une propriété qu'il valait la peine de constater : le comportement mesuré
ici ne dépend pas du rasteriseur.

---

## 8. CE QUI EST DERRIÈRE L'INTERRUPTEUR, ET CE QUI NE L'EST PAS

**Interrupteur BAS (tout joueur, et les 90 sondes du dépôt)** — le
comportement CH54 **sans une différence** : la planche est le même
`MeshInstance3D` nommé `Skateboard`, montée par `mount_vehicle` avec les
mêmes six arguments, roulant par segments de tween, marquant le score par
le proxy d'atterrissage. `_maybe_collide` sort à sa première ligne. La
seule chose qui bouge est **une ligne de texte dans l'overlay dev**, qui
n'est visible que derrière `DevTools.enabled()`.

**Interrupteur HAUT** — la planche est un `CharacterBody3D`, Keepy est
`ON_CARRIER` dessus, la funbox est solide, et la caméra **ne bouge pas**.

⚠️ **ET UN ROULEMENT PHYSIQUE NE MARQUE AUCUN POINT.** Ce n'est ni un oubli
ni une régression du jeu livré (l'interrupteur est bas pour tout joueur) :
`ON_CARRIER` n'émet aucun `hop_landed`, donc `HubSkatepark.note_landing`
n'est **jamais appelée**. CH55 §3.3 l'EXIGE (*« le mode physique doit
n'émettre aucun `hop_landed` »*, sur les termes de `HubPortal`), et CH55
LOT 2 est le lot qui remplace le proxy par une classification arithmétique.
Ce lot mesure F ; il ne re-score rien.

---

## 9. ZONES D'INCERTITUDE — dites, pas maquillées

1. **F n'est toujours pas mesuré.** C'est tout l'objet de ce lot et il ne
   peut pas se conclure ici : la mesure est **une lecture device**, deux
   URLs, une station. Tant qu'elle n'est pas faite, la table de sensibilité
   de CH56 §10.3 reste une sensibilité.
2. **Rien n'a été rendu de ce lot.** Aucune capture, aucun pixel de la
   planche sur la funbox. Le trajet est prouvé par transforms et par le
   serveur physique ; **à quoi il RESSEMBLE est inconnu**, et
   `CLAUDE.md` est explicite que la pose d'un corps sur une géométrie est
   une question d'IMAGE qu'aucune transform ne tranche. La montée peut être
   juste au centimètre et lire comme un glissement.
3. **La capsule est plus grosse que la planche au-dessus d'elle** (rayon
   0,13 contre 0,075 de demi-épaisseur de deck). Sans conséquence tant que
   rien ne passe au-dessus d'une planche ; ça cesserait d'être vrai le jour
   où un module a un plafond.
4. **Le trajet n'est pas un chemin.** `set_board_target` envoie la planche
   **EN LIGNE DROITE** ; la clôture `HubRegion` et la garde de calage la
   protègent de sortir du monde ou de meuler, mais une cible derrière un
   module se solde par un arrêt contre ce module, pas par un contournement.
   C'est le même modèle que la marche (`_advance()` va tout droit) et ça se
   remarquera davantage ici, parce qu'ici quelque chose bloque vraiment.
5. **Le lot n'a exercé qu'UNE géométrie.** Le rail (36 tri), les deux
   quarterpipes (profil balayé **concave**) et le bol (312 tri, **faux en
   hulls**) ne sont pas décomposés et ne le seront pas sans le lot 3 ;
   rien ici ne dit ce qu'ils coûteront ni comment ils se comporteront.
6. **`max_physics_steps_per_frame` n'a toujours jamais été exercé.**
   `--fixed-fps` l'empêche par construction (CH56 §12.7). La
   contre-réaction positive que CH55 §4.2 décrit — une frame lente accumule,
   la suivante exécute deux pas — reste reconduite arithmétiquement et
   jamais observée. **Sur device elle le sera**, et c'est une raison de plus
   pour que la lecture de F se fasse au même endroit dans les deux modes.
7. **D3 et D6 ne sont pas tranchées et n'ont pas eu à l'être.** D3 (espace
   physique partagé) est rendue **sans objet pour ce lot** par le choix des
   couches 3 et 4, lues contre les couches que les scènes de Chased
   déclarent réellement sur le disque (**masque 3**, donc 1 et 2) plutôt que
   contre un chiffre dont quelqu'un se souvenait. D6 (caméra de poursuite)
   ne se pose pas : la planche n'est pas pilotée frame par frame.

---

## 10. NEXT STEPS

| # | quoi | pourquoi |
|---|---|---|
| 1 | **LA LECTURE DEVICE DE F** — même station, `?keepyphys=1` puis sans, `FPS min` relevé aux deux | c'est le seul but du lot, et le seul chiffre qui décide de toute la chaîne |
| 2 | Une **capture** de la planche sur la funbox | rien n'a été rendu ; `CLAUDE.md` dit qu'une pose est une question d'image |
| 3 | **LOT 2** — la phase aérienne et le score par arithmétique | la dette CH53 §4.2 / CH43, et ce lot vient de retirer le proxy sans le remplacer, sous l'interrupteur |
| 4 | La lecture device au park, overlay ouvert, en (−10 ; 51) | next step #1 de CH52, CH53, CH55 **et** CH56 — toujours pas faite |

---

## 11. DOCS STATUS

Ce fichier, plus une ligne dans `docs/lots/INDEX.md`. **Une seule doctrine
réellement nouvelle** remonte dans `CLAUDE.md` : le contact dégénéré entre
deux faces coplanaires (§3), parce qu'aucun exemplaire du fichier ne le
couvre — c'est un piège de MOTEUR, silencieux, dont le symptôme
(« il s'arrête à côté ») ne ressemble pas à sa cause (« son dessous est
plat ») et que seul un vidage de normales par tick nomme.

`ProbeTimeoutAudit` : **91 scènes de sonde** contre 90 avant ce lot —
`SkatePhysicsProbe` est la seule ajoutée, elle arme `ProbeWatchdog` en
première instruction, et l'audit reste **PASSED**. Une sonde jetable
(`_ScratchRampDiag`) a servi au diagnostic du §3 et a été **supprimée avant
le commit**.
