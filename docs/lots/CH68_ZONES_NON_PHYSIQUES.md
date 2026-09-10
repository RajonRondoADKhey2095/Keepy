# CH68 — Les deux zones « non physiques » n'en font qu'une, et l'angle qui devait la débloquer n'achète rien

*10 septembre 2026. Branche `claude/keepy-physics-zones-recon-7s5bak`, basée
sur `origin/staging` `d9e0026` (CH67, arbre `e31ef72`). Garde de concurrence
par ARBRE, faite AU DÉBUT : `origin/main` est ancêtre de `origin/staging`,
`claude/hub-zone-bowl-physics-icsoys` porte **exactement l'arbre de
`staging`** (donc CH67 est intégralement mergé, pas une branche vivante), et
aucune ref distante n'est plus récente. Base repartie de `staging`, pas de
`main` : le lot précédent n'est pas encore promu en palier 2.*

> **RECON PURE — AUCUN CODE DE JEU N'EST TOUCHÉ.** Le brief l'autorisait
> explicitement (« IMPLEMENTATION SEULEMENT si le recon montre une voie
> propre », « Si ni (a) ni (b) ne donne de solution propre, NE PAS
> CÂBLER »). Le recon a mesuré les deux angles ; le second est mort en
> arithmétique et le premier ne survit pas au béton du park. Les chiffres
> sont ici ; le seul livrable est ce fichier.
>
> Ce que ce lot ajoute à CH66/CH67 et qu'ils n'avaient pas : **les deux
> zones signalées sont le MÊME objet**, et **la retombée du grand
> quarterpipe n'est pas la contrainte qui bloque le bol**.

## Section 1 — ZONE 1 IDENTIFIÉE : c'est le bol, et le panneau gris n'y est pour rien

Mathieu, capture device : « Keepy près d'un rail avec un mur / panneau gris
à côté, POS x 4,2 z 49,8, zone 0, PHYS bodies 1 pairs 0 ». Le brief
interdisait le guess. Quatre instruments, dans cet ordre.

### 1.1 — Ce qui occupe le point, énuméré

Sonde jetable sous `xvfb --rendering-driver opengl3` — obligatoire, elle
relit des transforms de `MultiMesh` et CH50 a mesuré que le driver dummy
en rend **2 743 identités sur 2 743** en laissant une assertion d'absence
passer verte. **Contrôle d'instrument en tête** : 370
`MultiMeshInstance3D`, **4 969 instances, 4 069 non-identité**.

Tout `MeshInstance3D` à moins de 6 u de (4,20 ; 49,80), distance XZ à son
AABB monde :

| d | nœud | y | solide ? |
|---|---|---|---|
| **0,000** | `Ground` | 0,00 | — (D1, `HubSurface`) |
| **0,000** | `Skatepark/SkateparkSlab` | 0,00–0,01 | — (D1, 1 cm) |
| **0,000** | `Skatepark/Skate_rail_1` | 0,00–0,68 | **SOLID (RailCollider)** |
| 2,284 | `Skatepark/Skate_bowl_4` | 0,00–1,37 | **— AUCUN** |
| 2,718 | `Skatepark/Skate_quarterpipe_3` | 0,00–1,47 | **SOLID** |
| 2,814 | `Skatepark/Skate_funbox_0` | 0,00–0,86 | **SOLID** |
| 4,950 | `Skatepark/Skate_quarterpipe_2` | 0,00–2,12 | **SOLID** |

Et **une seule** instance de `MultiMesh` dans le même rayon : `Hills` #8,
le relief. **Aucun prop de décor.** Les huit empreintes que CH67 signale en
NEXT STEPS #4 vivent toutes entre z 31 et 45 — la question du brief
(« est-ce un des 8 props ? ») se ferme là, par énumération et non par
lecture de coordonnées.

### 1.2 — Le panneau gris est le DOS DU PETIT QUARTERPIPE, et il est solide

L'identification s'est faite par **passe masquée** (cible en blanc pur,
`disable_fog`, appartenance ssi la couleur revient exactement — CH39 : un
objet destiné à être VU se gate au PIXEL, jamais sur une fenêtre), rendue
1080 × 1920 depuis la station :

| nœud | pixels | part du cadre | rect écran |
|---|---|---|---|
| `SkateparkSlab` | 723 140 | 34,87 % | x[0,1079] y[712,1919] |
| `Skate_quarterpipe_3` | **266 985** | **12,88 %** | x[201,1079] y[1211,1540] |
| `Skate_bowl_4` | 182 973 | 8,82 % | x[0,331] y[1164,1919] |
| `Skate_funbox_0` | 78 750 | 3,80 % | x[0,386] y[766,980] |
| `Skate_rail_1` | 6 471 | 0,31 % | x[456,662] y[820,1195] |
| `Skate_quarterpipe_2` | **0** | 0,00 % | hors cadre |

Le **0** de `quarterpipe_2` est le blind check du banc et il est
arithmétiquement juste : à son z la demi-largeur du cadre vaut
`tan(22,5°) × 7,2 = 2,98 u` autour de x = 4,2, et le module occupe
x[−7,70 ; −0,70]. Un banc qui aurait lu 0 partout n'aurait rien vu ; celui-ci
lit 0 là où la géométrie l'exige et des centaines de milliers ailleurs.

La capture RGB le dit d'un coup d'œil : le rail est la barre diagonale, le
**mur gris à lisière claire qui barre le cadre est la face NORD du
quarterpipe 1,45** — yaw π, donc sa transition ouvre au SUD et c'est son dos
que cette caméra montre — et le bol est la cuvette à anneau blanc en bas à
gauche.

### 1.3 — Et ce mur EST physique. Le fantôme est ailleurs

Balayage de 72 azimuts à y = 0,30 (la hauteur qu'un bout de planche
rencontre), chaque rayon lancé DEUX FOIS : contre le serveur de physique
(masque `LAYER_PARK`) et contre les **triangles de la surface 0** de chaque
module (la surface SOLIDE ; le coping vit en surface 1, D5).

* **32 azimuts** rendent un contact physique, **37** rendent un contact
  dessiné ;
* sur **31 d'entre eux les deux distances sont ÉGALES au millimètre** —
  2,750 / 2,750 sur le dos du quarterpipe à 0°, 1,232 / 1,232 sur le rail à
  35°, 3,248 / 3,248 sur la funbox à 220° ;
* **6 azimuts sont FANTÔMES — 295°, 300°, 305°, 310°, 315°, 320° — et les
  six sont le bol.** À 300–320° il n'y a **aucun solide du tout** sur 14 u.

Depuis une seconde station, (0 ; 52) : **63 azimuts fantômes sur 72**.

**`PHYS bodies 1 pairs 0` n'était donc pas le symptôme.** C'est la lecture
NORMALE partout : le seul corps actif est la planche, le sol est `HubSurface`
(D1, aucun corps), et une paire n'apparaît qu'au contact d'un module. Le
chiffre est juste ; ce qu'il ne pouvait pas dire, c'est qu'à 2,28 u au
nord-ouest il n'y a rien à toucher.

### 1.4 — Par le CANAL DU JOUEUR, avec son blind check

CH58 : une sonde qui gate une interaction entre par le canal du joueur. La
planche a donc été montée et pilotée par de vrais `InputEvent` à travers
`SkateBench`, doigt tenu, **depuis la position exacte que Mathieu a
rapportée**, cap sur l'axe du bol.

| run | parcouru | approche de l'axe | contacts avec le bol | fin |
|---|---|---|---|---|
| **à travers le bol**, départ (4,20 ; 49,80) | **15,460 u** | **0,199 u** | **0** | (−5,63 ; 61,41), r 7,82 — ressortie de l'autre côté, jamais arrêtée |
| **blind check**, même geste sur le quarterpipe SOLIDE | 4,678 u | 1,937 u | 57 | **ARRÊTÉE au tick 100** |

Le rider traverse la jupe, le flanc, le fond plat et le flanc opposé sans un
seul contact — et le même banc, sur un module solide, s'arrête. « Ça passe à
travers » est une assertion d'ABSENCE, qui passe gratuitement contre un banc
qui n'a jamais rien conduit ; le second run est ce qui en fait un résultat.

### 1.5 — Verdict de la zone 1

**Zone 1 = le bol (module 4).** Ce n'est ni un module jamais audité, ni un
prop de décor, ni le rail. C'est **le même objet que la zone 2**, vu depuis
un autre endroit — et le seul béton non solide du park, ce que
`SkatePhysicsProbe` PHASE X gate déjà à chaque run (`pieces_for` vide **ssi**
chevauchement). Le brief demandait de rapporter la nature exacte avant de
coder : il n'y avait pas deux chantiers, il y en avait un.

⚠️ **Et la leçon de méthode est là** : un retour device nomme un
**SYMPTÔME**, pas un objet. Deux symptômes ne sont pas deux causes tant
qu'on ne les a pas mesurés, et ici le prix de la confusion aurait été un
collider écrit pour un mur qui en a déjà un.

## Section 2 — LE BOL : les deux angles, mesurés

### 2.1 — Le banc reproduit d'abord les chiffres du dossier

Un banc incapable de restituer un chiffre déjà au dossier n'a pas qualité à
en publier un neuf.

| grandeur | CH66 / CH67 | ce banc |
|---|---|---|
| rim du bol au coin est du quarterpipe 2,10 | 2,87 u (0,73 dedans) | **2,907 u (0,693 dedans)** |
| rim du bol au pied du quarterpipe 1,45 | 2,92 u (0,68 dedans) | **2,915 u (0,685 dedans)** |
| retombée du grand quarterpipe sur `staging` | (−4,20 ; 57,58) | **(−4,20 ; 0,00 ; 57,58)** |
| rapport des chevauchements 2,10 : 1,45 | 968:140 = 6,9 / 1 044:158 = 6,6 | 59:9 = **6,6** |

La retombée est **remesurée par `SkateAirProbe` sur cet arbre**, jamais
recopiée du dossier — CLAUDE.md : un nombre copié mérite plus de défiance
qu'un nombre mesuré ici. Elle tombe au chiffre près sur celle de CH67.

Deux retombées de plus, que CH67 ne publie pas et qui comptent pour un lot
futur : le petit quarterpipe jette au SUD, **(5,00 ; 46,66)**, et une course
20° hors axe sur le GRAND atterrit à **(0,77 ; 55,78)** — c'est-à-dire à
**1,30 u du centre du bol livré**, dans son fond plat. Aujourd'hui c'est de
la pelouse (D1) et il ne se passe rien ; le jour où le bol est solide, c'est
une seconde entrée à traiter.

⚠️ **PLANCHER DE RÉSOLUTION DU BANC, PUBLIÉ.** Le chevauchement est compté
sur un réseau de **0,20 u** moissonné DEPUIS LE SERVEUR DE PHYSIQUE (funbox
1 760 points, rail 18, quarterpipe 2,10 840, quarterpipe 1,45 390 — aucun
module solide n'en rend zéro, c'est le blind check du moissonnage). Un
réseau de 0,20 u **ne voit pas une pénétration de 0,19 u** : partout où ce
fichier publie un chevauchement nul ou une approche, le chiffre porte cette
barre. Les distances de la table ci-dessus, elles, sont exactes (géométrie
de coin, aucun échantillonnage).

### 2.2 — Les cinq contraintes, et le débord qui existe DÉJÀ

| # | contrainte | énoncé |
|---|---|---|
| K1 | OVERLAP | zéro échantillon partagé avec un module solide |
| K2 | PARKING | `\|C − (3,00 ; 60,00)\| ≥ 5,60` (empreinte 4,40 + `SKATE_FOOTPRINT` 1,20) |
| K3 | LANDING | `\|C − (−4,20 ; 57,58)\| ≥ 4,60` (rim 3,60 + 1,00 de marge) |
| K4 | REGION | les 36 points du rim dans `HubRegion.contains()` |
| K5 | SLAB | le rim ne déborde pas la dalle de plus que **le bol livré ne le fait déjà** |

⚠️ **K5 A DÛ ÊTRE MESURÉ AVANT D'ÊTRE ÉCRIT.** Une première version exigeait
le rim ENTIÈREMENT sur la dalle — et **le bol livré échoue à ce test** : il
déborde de **0,100 u** au nord (rim à z 59,10 pour une dalle qui s'arrête à
59,00). Un seuil qui condamne l'état expédié ne prouve pas moins que rien,
il prouve à l'envers. K5 vaut donc 0,100 u exactement, le débord d'aujourd'hui.

### 2.3 — ANGLE (a) : des positions existent, et aucune n'est sur le béton du park

Balayage de **12 057 candidats** (x ∈ [−14, 14], z ∈ [44, 70], pas 0,25).

**Les cinq contraintes ensemble : 56 positions.** Elles tiennent toutes dans
**x[−6,50 ; 6,50], z[44,50 ; 49,00]** — l'extrémité SUD de la dalle, sur la
ligne de la funbox et du rail, à l'entrée à pied que CH53 a mesurée comme le
pire cadrage du park.

| | valeur |
|---|---|
| la plus proche du centre livré | (5,50 ; 49,00), déplacée de **8,846 u**, approche **0,047 u** |
| la plus DÉGAGÉE des 56 | (−6,50 ; 45,00), déplacée de **12,093 u**, approche **0,801 u** |
| combien gardent ≥ 1,00 u de dégagement | **0 sur 56** |
| combien gardent ≥ 2,00 u | **0 sur 56** |

**CH67 disait « aucune position » ; c'est trop fort et ce lot le corrige :
il y en a 4 489 dès qu'on lâche la dalle.** CH67 était honnête dans sa
formulation (« n'a pas été trouvée DANS CE LOT ») et la mesure lui donne
raison sur le fond — mais la raison n'est pas celle qu'il nomme.

### 2.4 — ANGLE (b) : LA RETOMBÉE N'ACHÈTE RIEN, et ça se lit en une ligne

Le brief demandait de **mesurer avant d'essayer** d'ajuster la trajectoire
de retombée. La mesure est un tableau où chaque contrainte est retirée une
fois :

| on retire | positions restantes |
|---|---|
| K1 OVERLAP | **2 071** |
| K2 PARKING | 56 |
| **K3 LANDING** | **56** |
| K4 REGION | 56 |
| K5 SLAB | **4 489** |

**Retirer K3 entièrement ne change RIEN : 56 avant, 56 après.** Déplacer la
retombée du grand quarterpipe — par n'importe quel moyen, et donc à plus
forte raison sans toucher au modèle CH61/CH66 — **n'ouvre pas une seule
position**. L'angle (b) est mort, et il est mort **sans qu'une ligne de code
ait été touchée**, pour le prix d'une colonne dans un tableau.

Ce qui contraint réellement, ce sont **K1 et K5** : le chevauchement avec les
deux quarterpipes, et le fait que la dalle du park fait 20 × 18 et porte déjà
quatre modules. `slab + K1` rend exactement les mêmes 56 que les cinq
contraintes ensemble — K2, K3 et K4 ne retranchent rien du tout.

### 2.5 — Ce qu'il faudrait ACHETER, chiffré

Puisque la dalle est le mur, voici son prix. La dalle est **16 triangles**
(`SkateparkMesh.slab`) : l'agrandir ne coûte pratiquement rien au compteur.
Pour chaque budget de débord, le meilleur dégagement atteignable sous K1–K4 :

| débord toléré | positions | meilleur dégagement | où | déplacement |
|---|---|---|---|---|
| 0,10 u (aujourd'hui) | 56 | **0,801 u** | (−6,50 ; 45,00) | 12,09 u |
| 1,00 u | 122 | 1,551 u | (−7,25 ; 44,00) | 13,34 u |
| 2,00 u | 243 | 2,551 u | (−8,25 ; 44,00) | 13,87 u |
| 3,00 u | 435 | 3,397 u | (−9,25 ; 44,00) | 14,45 u |
| 4,00 u | 731 | 3,745 u | (−10,25 ; 59,25) | 10,45 u |
| 6,00 u | 1 852 | aucun solide en vue | (−12,25 ; 61,00) | 12,97 u |

Autrement dit : **un mètre de dégagement coûte un mètre de béton en plus et
13 u de déplacement**, et le bol quitte alors la ligne de course du park.

⚠️ **UN TROISIÈME ANGLE, MESURÉ ET NON PROPOSÉ** (le brief n'en demandait
que deux, il est ici parce qu'il est bon marché à écrire et cher à
redécouvrir). Le chevauchement ne vaut que **0,69 u de chaque côté**. Un bol
plus PETIT dégage **sans que rien ne bouge** : d'après les distances de coin
exactes de 2.1, le rayon qui dégage au centre livré est
**min(2,907 ; 2,915) = 2,907 u**, contre 3,600 aujourd'hui — soit un fond
plat qui passerait de 2,25 à 1,56 u de rayon (`bowl_profile` dérive le fond
du rayon, `flat = radius − depth`). Le banc à réseau de 0,20 u, lui, annonce
3,10 : **c'est son plancher de résolution qui parle, pas la géométrie**, et
c'est exactement pourquoi ce plancher est publié en 2.1. Cette piste ne
règle PAS la seconde objection de CH66 — une jupe verticale n'a toujours
aucune entrée au sol — donc elle appelle le roll-in que CH67 avait écrit
puis rendu.

### 2.6 — VERDICT : LE BOL N'EST PAS CÂBLÉ

Ni (a) ni (b) ne donne de voie propre, et le brief prescrit alors de ne pas
câbler :

* **(a)** des positions existent, mais aucune ne garde **un seul mètre** de
  dégagement sur le béton du park, et les 56 candidates sont toutes à
  l'entrée à pied, 9 à 12 u de leur place, sur la ligne de course de deux
  autres modules ;
* **(b)** **réfuté par la mesure** : la retombée n'est pas une contrainte
  active, la déplacer ouvre zéro position.

`HubSkatepark.pieces_for()` rend toujours vide pour le bol, `SkateparkMesh.bowl_pieces()`
reste la géométrie prouvée de CH66 qui attend son lot, et `SkatePhysicsProbe`
PHASE X continue de gater le périmètre sur la mesure. **Rien de tout cela
n'est modifié par ce lot.**

## Section 3 — LA TABLE DES SONDES

Aucun fichier de jeu n'étant touché, **une table croisée sur deux arbres
serait dégénérée** : les deux arbres seraient identiques hors `docs/`, qui
est dans l'`exclude_filter` du build et n'est pas une ressource Godot. Ce qui
est publié est donc la table de l'arbre livré, plus la preuve que le recon
n'a rien laissé derrière lui.

| sonde | driver | verdict |
|---|---|---|
| `SkatePhysicsProbe` | headless | **ALL GREEN — 0 red** |
| `SkateAirProbe` | headless | **ALL GREEN — 0 red** |
| `SkateInertiaProbe` | headless | **ALL GREEN — 0 red** |
| `SkateTrickProbe` | headless | **ALL GREEN — 0 red** |
| `SkateTraverseProbe` | headless | **ALL GREEN — 0 red** |
| `ProbeTimeoutAudit` | headless | **98 scènes — PASSED** |

⚠️ **LES 98 SONT LE CONTRÔLE DE PROPRETÉ DU LOT.** Pendant le recon,
l'audit lisait **100** : les quatre sondes jetables (énumération des nœuds,
balayage d'azimut, balayage de positions, ride fantôme) y comptaient. Elles
sont **supprimées**, et le retour à 98 — le chiffre exact de CH67 — est ce
qui le prouve. CLAUDE.md : une sonde de mesure ponctuelle n'entre pas dans
le dépôt.

Rien n'est rouge et rien ne pouvait l'être : ce lot ne change aucun `.gd`,
aucun `.tscn`, aucun shader et aucune constante.

## Section 4 — CE QUE CE LOT NE SIGNE PAS

* **Que le bol ne pourra jamais être câblé.** Il signe que les deux angles
  du brief ne suffisent pas, et il chiffre ce qu'un troisième coûterait.
* **Que 0,801 u de dégagement serait vraiment injouable.** C'est un
  jugement, pas une mesure — et le chiffre porte en plus la barre de
  ±0,20 u du réseau de moissonnage.
* **Le FPS device.** Hors sujet ici, toujours ouvert depuis CH67.
* **Que le petit quarterpipe se LIT comme un mur qu'on peut heurter.** Il
  est solide, c'est mesuré onze fois ; qu'un joueur comprenne en le voyant
  que c'en est un n'appartient qu'à Mathieu.

## Section 5 — PROTOCOLE DEVICE

Le build de `staging` ne change pas, donc il n'y a **rien à re-tester**. Ce
qui est demandé est une confirmation d'identification, en une manipulation :

1. Monter sur la planche, rouler jusqu'au rail (la barre en diagonale au
   milieu du park) et s'arrêter à côté, du côté ouest.
2. Le **mur gris à lisière claire droit devant** est le petit quarterpipe :
   rouler dedans, **il arrête la planche**. C'est le comportement attendu.
3. Se tourner **vers le nord-ouest**, vers la cuvette à anneau blanc :
   la planche la **traverse de part en part**, sans rien toucher. C'est la
   zone 1 ET la zone 2 — le même objet.
4. À reporter : (a) est-ce bien cette cuvette-là qui avait été vue les deux
   fois ? (b) y a-t-il un TROISIÈME endroit où quelque chose se traverse —
   auquel cas il faut sa position, parce que le balayage dit qu'il n'y en a
   pas dans le park.
