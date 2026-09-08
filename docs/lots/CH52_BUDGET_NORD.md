# CH52 — Le budget réel du corridor nord, z = 35 → 63

**8 septembre 2026.** Lot de **mesure seule** : aucun asset, aucun module,
aucune mécanique, aucun fichier de gameplay touché. Le livrable est une
sonde permanente (`scripts/dev/NorthBudgetProbe.gd`), ce fichier, et un
budget chiffré pour le skatepark que CH51 a conçu sans pouvoir le
chiffrer.

---

## 0. LA BASE, ET LA GARDE DE CONCURRENCE

Branche ouverte sur `main` (`2876f27`), **re-basée sur `origin/staging`**
(`bde31e1`) avant la première ligne : CH50 et CH51 vivent sur `staging`,
et `main` porte encore un lobe nord à r = 12. `merge-base --is-ancestor`
confirme que `main` est ancêtre de `staging` — pas une divergence, un
retard.

Garde faite **au début et par ARBRE**, pas par nom :

| ref | verdict |
|---|---|
| `origin/claude/lot-zone0-nord-skatepark-ezbguf` | ancêtre de `staging` → **déjà mergée** (CH50) |
| `origin/claude/skatepark-trick-minijeu-xyuy9a` | `d22e51d`, ancêtre de `staging` → **déjà mergée** (CH51 lot A) |
| `origin/claude/budget-mesure-z35-z63-hfmh7f` | pointait sur `main`, **aucun travail dessus** |

Aucune session concurrente vivante.

---

## 1. LE CONTRÔLE D'INSTRUMENT — et il a refusé de publier deux fois

Le brief l'exigeait, à cause du faux-vert CH50 (une sonde `--headless`
lisant 2 743 transforms de `MultiMesh` en identité et sortant « 0
instance » en vert). `NorthBudgetProbe` PHASE I tourne **en premier** et
`_run()` **arrête la sonde** si elle échoue — aucun chiffre en dessous
n'est imprimé.

Elle a échoué deux fois, sur deux défauts distincts, tous deux **dans la
sonde** :

### 1.1 « Le plus gros batch » est le mauvais sujet

Premier jet : prendre le plus gros `MultiMeshInstance3D` du monde et
exiger que ses transforms ne soient pas l'identité. Résultat :

```
biggest batch 'Precipitation': 900 instances, 900 read back as IDENTITY
[RED] I3b transforms read back as REAL: 900 of 900 are identity
```

**Et la sonde avait raison de lire ça.** `Precipitation` est le plus gros
batch du hub (900 quads) et **toutes ses instances sont à l'origine du
nœud par conception** : `cozy_precip.gdshader` les place depuis
`INSTANCE_CUSTOM` et `TIME`. Une lecture tout-identité n'est **pas** la
signature d'un driver aveugle ; elle ne signifie rien tant qu'on ne sait
pas si ce batch était censé porter des transforms.

Corrigé en lisant le sujet dans la liste que **le producteur publie** —
`CozyScatter.batch_nodes()`, les 306 batches de décor au sol que `_flush`
a réellement bâtis — jamais dans une devinette, jamais dans une liste de
ce qui n'en est PAS un. Sujet retenu : `grass_grass_1_0_1`, 233
instances, **0 en identité**, origines étalées sur 27,95 u contre une
AABB de nœud de 28,53 u.

`Precipitation` est désormais **publié à côté, comme contre-exemple**,
pour que le prochain lecteur ne refasse pas l'erreur.

### 1.2 Un test de réponse à 2 triangles ne teste rien

Deuxième jet : prouver que le compteur RÉPOND en cachant `Ground`.

```
[OK ] I4a hiding Ground drops the counter: 70946 -> 70944 (delta 2)
```

Vert, et sans valeur : le sol du hub est un `PlaneMesh` de **deux
triangles**. Une réponse de 2 est indiscernable d'une dérive et aurait
laissé passer un compteur quasi mort. Sujet remplacé par **tout
`CozyScatter`** : 70 946 → 27 306, **delta 43 640**, seuil exigé 1 000.

### 1.3 Le contrôle tel qu'il tourne aujourd'hui

```
[OK ] I1a viewport rendered 1080x1920, asked 1080x1920
[OK ] I1b the frame carries 109 distinct colours on a 37px lattice (dummy driver renders 1)
[OK ] I2a engine_prims filled: 70946
[OK ] I2b engine_calls filled: 303
[OK ] I2c the overlay's frustum replay answers: lod0 257546, scene 351657
[OK ] I3z CozyScatter publishes 306 ground-decor batch names
[OK ] I3a 'grass_grass_1_0_1' transform_format is TRANSFORM_3D
[OK ] I3b transforms read back as REAL: 0 of 233 are identity (CH50 read 233 of 233)
[OK ] I3c and they are SPREAD (widest horizontal span 27.95 u)
[OK ] I4a hiding CozyScatter drops the counter hard: 70946 -> 27306 (delta 43640)
[OK ] I4b two stations do not read the same number: spawn 70946, z=63 96467
```

**Aucun `--headless`** : tout tourne sous `xvfb-run --rendering-driver
opengl3 --fixed-fps 60`.

---

## 2. LE PROTOCOLE — et le troisième défaut, qui était dans la mesure

Premier jet de PHASE G (« cacher un groupe, relire la même frame ») **non
pausé**. Il a rendu, à la station (0, 35) :

```
world/Ground     1 nodes  gpu  +1920
world/Mountain   1 nodes  gpu  +1918
world/Critters   5 nodes  gpu  +1918
scatter/rock     4 nodes  gpu  +1938
```

`Ground` est un plan de **deux triangles**. Ce ~1 918 n'est le coût de
rien : c'est le hub qui bouge sous une mesure qui prend six frames par
groupe. C'est exactement la doctrine CH37 (« un gate de capture ne gate
rien dans un monde qui contient un acteur en marche »), une couche plus
haut.

Trois corrections, et il fallait les trois :

1. **`get_tree().paused = true`** pendant PHASE V, G, L et D. Le `TIME`
   d'un shader continue (CH48) — sans importance ici : `TIME` déplace des
   pixels, pas des primitives.
2. **`_station_frozen()`** : pauser puis se déplacer ne suffit pas. Deux
   choses SUIVENT Keepy dans `_process` (la colonne de pluie et son ombre
   au sol, `CozyScatter._process`) ; une station prise arbre déjà pausé
   laisserait la boîte de pluie garée à la station précédente. L'arbre est
   donc relâché, la station prise, les frames de rattrapage laissées, et
   seulement ensuite gelé.
3. **Un GROUPE TÉMOIN VIDE**, même protocole, rien de caché, joué **trois
   fois et intercalé** dans chaque station. Son pire |delta| est le
   plancher de CE protocole — pas celui de PHASE S, mesuré sous un autre
   profil temporel. Sans lui, « le groupe coûte quelque chose » passe
   gratuitement (CH40).

Après correction, `world/Ground` relit **+2** partout, et le témoin
rapporte **|delta| = 0** aux quatre stations : le monde gelé est
réellement immobile.

⚠️ **Et PHASE S a corrigé son propre plancher.** Premier jet : 5 lectures
sur frames consécutives → **spread 0 aux dix stations**, ce qui ressemble
à un instrument parfait et n'en est pas un : ce qui bouge dans ce hub
bouge sur des SECONDES. Porté à 8 lectures espacées de 12 frames
(≈ 1,6 s simulée) — le spread reste **0**. C'est donc un vrai résultat, et
il est publié comme tel : **à station garée, le compteur de primitives de
ce hub est déterministe sur 1,6 s.**

### Reproductibilité — retournée contre elle-même (CH37)

Quatre runs complets du même arbre, mêmes arguments :

| phase | verdict |
|---|---|
| PHASE S (stations) | **byte-identique** runs 3, 4, 5, 7 |
| PHASE V (leash on/off) | **byte-identique** runs 3, 4, 5, 7 |
| PHASE G (139 lignes, monde gelé) | **byte-identique** runs 3, 4, 5, 7 |
| PHASE L + D (courbes de reprise) | **byte-identique** runs 4, 5, 7 |
| PHASE X (balayage x, **vivant**) | **divergeait** — corrigé §4.1 |
| PHASE T (temps mur) | diverge par construction — §7 |

---

## 3. LES RELEVÉS PAR STATION

Sous `xvfb + opengl3`, 1080×1920, spawn du hub, météo par défaut. `scene`
vaut **351 657** à toutes les stations (c'est le monde entier, cadre ou
pas). Plancher de bruit **0** partout (8 lectures espacées).

| station | `gpu` | `calls` | `lod0 cadre` | `inst` | dans la région |
|---|---|---|---|---|---|
| (0 ; 0) **spawn** | **70 946** | 303 | 257 546 | 3 806 | oui |
| (−5 ; 35) *pire frame CH22* | 94 601 | 362 | 292 012 | 4 606 | oui |
| (0 ; 35) | 87 477 | 364 | 291 944 | 4 591 | oui |
| (0 ; 39) | 86 999 | 364 | 292 318 | 4 605 | oui |
| (0 ; 43) | 95 917 | 375 | 309 004 | 4 727 | oui |
| (0 ; 47) | 95 337 | 378 | 310 116 | 4 746 | oui |
| (0 ; 51) | 97 114 | 392 | 313 221 | 4 862 | oui |
| (0 ; 55) | 96 336 | 394 | 313 589 | 4 869 | oui |
| (0 ; 59) | 96 102 | 399 | 316 045 | 4 912 | oui |
| (0 ; 63) | 96 467 | **405** | 318 475 | 4 929 | oui |

**La prémisse de CH51 est RÉFUTÉE.** CH51 écrivait : *« Depuis z = 63, le
bord sud du plateau est à 98 u — déjà coupé. La station nord pourrait donc
être moins chère que la station z = 35, pas plus. Ça se mesure, ça ne se
déduit pas. »* Mesuré : **z = 63 coûte 96 467 contre 87 477 à z = 35**,
soit **+9 000**, et **+36,0 % au-dessus du spawn**.

⚠️ **Marche entre z = 39 et z = 43 : +8 918 primitives d'un coup.** Le
leash s'applique par **NŒUD de batch**, et un batch de `CozyScatter`
couvre une cellule de `CELL = 28 u` : des cellules entières sortent du
cull d'un seul bloc. La courbe n'est pas continue et ne peut pas l'être.

---

## 4. L'AXE N'EST PAS LE PIRE CADRE — et la 1re version du balayage ne survivait pas à un re-run

Le balayage en z se fait à x = 0, l'axe du lobe. Mais PHASE S lit
**94 601 en (−5 ; 35) contre 87 477 en (0 ; 35)** : sept mille primitives
d'écart au même z, uniquement en x. Un budget calé sur un balayage qui
n'a jamais regardé ailleurs que l'axe est calé sur un cadre qui n'est pas
le pire — le même défaut que gater un plafond sur la mauvaise des trois
lignes de triangles.

### 4.1 Le quatrième défaut de méthode : un balayage qui mélange deux horloges

Les deux premières versions de PHASE X, **vivantes**, se sont contredites
l'une l'autre :

| run | pire cadre annoncé | lecture en (−10 ; 51) |
|---|---|---|
| 5 | **101 394** en (−10 ; 51) | 101 394 |
| 6 | **99 030** en (−5 ; 51) | **95 548** |

Rien du hub n'avait changé entre les deux. **L'ours avait marché** — 5 846
primitives qui entrent et sortent du frustum sur SON horloge, pas sur
celle de la station. Un balayage qui demande « quel x est le pire » doit
ne faire varier que x ; celui-ci faisait varier x **et le temps**, et son
classement ne survivait pas à une relecture.

Correction : les acteurs mobiles sont **trouvés par la MESURE** — chaque
`VisualInstance3D` dont la position a bougé de plus de 0,01 u sur 45
frames — et cachés pendant le balayage. Jamais par une liste de noms :
CH44 a déjà établi que la moitié des chemins de nœuds de ce hub n'existent
pas (l'ours est `@Node3D@228`, un nom dérivé du compteur d'instanciation).

**Dix nœuds trouvés** : `char1(Skeleton3D)` (l'ours), `Clouds`, trois
`output_unwrapped(Model)`, deux bouées de la Crique, les trois
montgolfières.

Leur coût n'est **pas jeté** : il est mesuré séparément (PHASE G lit
l'ours à **+5 846** depuis chaque station nord) et se rajoute.

### 4.2 Le balayage, acteurs mobiles retirés

| z | x = −25 | −20 | −15 | −10 | −5 | 0 | +5 | +10 | +15 | +20 | +25 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 35 | 71 296 | 77 987 | 82 021 | 76 419 | 82 425 | 74 891 | 74 933 | 71 752 | 74 071 | 69 044 | 67 313 |
| 43 | 73 958 | 79 059 | 83 569 | **87 955** | 83 377 | 84 149 | 76 217 | 82 557 | 78 967 | 68 972 | 67 744 |
| 51 | — | 82 268 | 84 318 | **90 220** | 87 460 | 85 484 | 77 906 | 84 943 | 80 437 | 78 456 | — |

**Pire cadre position-dépendant : 90 220 primitives en (−10 ; 51).** Pire
compte de draw calls : **402** en (+10 ; 51).

### 4.3 Le pire cadre complet, décomposé

Le terme mobile se mesure par différence, à la même station : PHASE S lit
**97 114** en (0 ; 51) avec le casting, PHASE X lit **85 484** sans →
**11 630 primitives de casting mobile** quand il est tout entier dans le
cadre.

> **Pire cadre du lobe ≈ 101 400 primitives en (−10 ; 51)** —
> **90 220 de position** + **≈ 11 200 de casting mobile**.
>
> Les deux décompositions se recoupent : run 5, casting inclus, avait lu
> **101 394** à cette même station. Écart entre les deux chemins :
> **≈ 450 primitives**.

C'est **+30 400 / +42,9 %** au-dessus du spawn, et **+6,8 %** au-dessus de
la pire frame historique de CH22.

## 5. CE QUI COÛTE — et pourquoi, géométriquement

PHASE G, monde gelé, témoin nul à 0. **La partition ferme exactement** :
la somme des deltas de groupe vaut 96 467 à z = 63 et 70 946 au spawn,
c'est-à-dire les totaux mesurés, résidu **zéro**. Un bucket oublié se
serait vu là.

| groupe | spawn | z = 63 | **excès nord** |
|---|---|---|---|
| `world/Props` (HubBuilder, 167 nœuds) | 14 753 | 26 367 | **+11 614** |
| `scatter/grass` (20 batches) | 7 221 | 14 409 | **+7 188** |
| `world/@Node3D@228` (**l'ours**) | 0 | 5 846 | **+5 846** |
| `scatter/wall_near` (mur forestier) | 9 892 | 12 222 | +2 330 |
| `world/Cove` | 230 | 2 432 | +2 202 |
| `world/Transport` | 2 568 | 4 118 | +1 550 |
| `world/Trees` | 3 852 | 4 834 | +982 |
| `scatter/flower` | 294 | 1 128 | +834 |
| `scatter/wall_far` | 72 | 648 | +576 |
| `scatter/other` (collines, nuages, chemins, papillons…) | 17 884 | 17 884 | **0** |
| `world/Keepy` | 3 129 | 3 129 | 0 |
| `world/Karting` | 2 772 | 2 592 | −180 |
| `scatter/autumn_tree` | 2 090 | 0 | −2 090 |
| `scatter/fern` | 3 885 | 0 | −3 885 |
| *(autres, chacun < 500)* | | | −1 546 |
| **total** | **70 946** | **96 467** | **+25 521** |

### La cause est la caméra, pas le semis

`HubCamera.OFFSET` est une **constante** `(0 ; 7,6 ; 8,9)` et la caméra
**ne tourne jamais** : elle se tient toujours 8,9 u au NORD de Keepy et
regarde vers −z.

* Au **spawn** (caméra en z = 8,9), toute la moitié nord du plateau est
  **derrière l'objectif** et entièrement cullée.
* Depuis **(0 ; 63)** (caméra en z = 71,9), **le plateau entier est devant
  elle** — les 70 u de z = 35 à z = −35, plus les 28 u du lobe.

`world/Props` n'a **aucun** `visibility_range_end` (seul `CozyScatter` en
pose), donc il entre en totalité. D'où les +11 614. Et l'ours, qui marche
vers le feu au milieu du plateau, passe de hors-champ à en-champ : +5 846
d'un bloc, pour un seul nœud.

⚠️ **Le corridor nord est le SEUL endroit du hub où la caméra
non-orientable a le plateau entier devant elle.** Ce n'est pas un défaut
du semis de CH50 : c'est une propriété du bord nord, et aucun lot avant
CH50 ne pouvait s'y tenir. Le semis n'en est que le deuxième terme
(+7 188 d'herbe).

⚠️ **Et le compteur compte ce qui est SOUMIS, pas ce qui est DESSINÉ**
(CH39) : ces chiffres prouvent que ces objets sont soumis au GPU, jamais
qu'ils sont visibles à l'écran. À 63 u derrière le brouillard
(`fog_density = 0,016`), une bonne partie de ce que le nord soumet est
déjà effacée pour le joueur — et payée quand même.

### La météo ne déplace PAS cette ligne — mesuré, pas supposé

CH51 demandait quatre météos. PHASE W force les quatre
(`CozyWeather.force`) et relit :

| station | sun | rain | storm | snow | spread |
|---|---|---|---|---|---|
| (0 ; 0) | 70 946 | 70 946 | 70 946 | 70 946 | **0** |
| (−10 ; 51) | 94 710 | 94 714 | 94 714 | 94 710 | **4** |
| (0 ; 63) | 96 467 | 96 471 | 96 471 | 96 467 | **4** |

**Quatre primitives sur 96 000.** La raison est structurelle et lisible
dans le code : `Precipitation` est **toujours visible** — rien ne pose son
`.visible` depuis la météo — et `cozy_precip.gdshader` en gate le LOOK
depuis les uniformes `rain` et `snow`. **Dans ce hub, la météo est un
paramètre de shader, pas un interrupteur de géométrie**, et ses 900 quads
(1 800 primitives) sont dans tous les chiffres de ce document.

⚠️ **Ce que cette phase ne dit pas** : les quatre critters écoutent
`weather_changed` et vont s'abriter, ce qui est un DÉPLACEMENT, et un
déplacement peut porter un corps dans ou hors du frustum. Trente frames
sont très loin de suffire à cette marche. La phase répond « la géométrie
soumise est indépendante de la météo », jamais « un critter ne peut pas
rentrer dans le cadre ».

⚠️ Elle ne dit rien non plus du **coût par fragment** : la pluie et le
brouillard coûtent des pixels, et ce banc ne mesure que des primitives.

---

## 6. `visibility_range_end` — vérifié, et il est déjà en train de tout tenir

CH51 avait explicitement marqué ce point non vérifié. Mesuré en
**retirant** le leash et en relisant la même frame (monde gelé) :

| station | avec leash | sans leash | ce que le leash épargne |
|---|---|---|---|
| (0 ; 0) spawn | 70 946 | 155 534 | **84 588** |
| (0 ; 35) | 87 337 | 179 642 | 92 305 |
| (0 ; 51) | 95 988 | 192 457 | 96 469 |
| (0 ; 63) | 96 467 | 193 951 | **97 484** |

Cohorte : **298 nœuds** leashés — 194 à 82 u, 64 à 95 u, 27 à 150 u
(décor du circuit), 5 à 125, 4 à 52, 3 à 120, 1 à 72.

**Réponse à la question du brief : oui, le leash agit depuis le nord, et
il agit MASSIVEMENT — il divise la frame par deux.** Mais il ne l'atténue
pas *davantage* qu'ailleurs : il épargne 97 484 à z = 63 contre 84 588 au
spawn, c'est-à-dire qu'il travaille plus fort au nord **et n'y suffit
pas**. L'hypothèse de CH51 (« la station nord pourrait être moins chère »)
échoue parce qu'elle raisonnait sur ce que le leash COUPE (le bord sud à
98 u) en oubliant ce qu'il LAISSE PASSER : les 82 u au nord de z = −10
contiennent le plateau entier, et `world/Props` n'est pas leashé du tout.

---

## 7. LE TEMPS MUR NE TRANCHE PAS — et c'est un résultat

PHASE T mesure le temps réel entre deux `process_frame` (méthode
`HubPerfBaseline` : le delta rapporté par `--fixed-fps` est une
constante, pas une mesure).

| run | spawn | (−5 ; 35) | (0 ; 35) | (0 ; 51) | (0 ; 63) | z=63 vs spawn |
|---|---|---|---|---|---|---|
| 2 | 106,64 ms | 117,60 | 119,60 | 119,22 | 121,69 | **+14,1 %** |
| 3 | 110,79 | 121,55 | 120,82 | 120,34 | 120,20 | **+8,5 %** |
| 4 | 117,84 | 120,16 | 117,73 | 121,94 | 123,71 | **+5,0 %** |
| 6 | 109,33 | 113,20 | 116,24 | 118,13 | 120,76 | **+10,5 %** |
| 7 | 105,70 | 114,81 | 116,13 | 116,32 | 119,99 | **+13,5 %** |

**Le sens est constant (le nord est plus lourd, cinq fois sur cinq),
l'amplitude ne l'est pas : 5,0 à 14,1 points, soit 9,1 points de
dispersion.** Le plancher de bruit de ce banc
dépasse le signal qu'il prétend mesurer, exactement comme le banc de coût
de shader de CH23 qui ne séparait pas trois candidats derrière un plancher
de 0,712 ms. **Ce banc ne sépare pas ces stations** ; publier l'un de ces
trois pourcentages comme *le* chiffre aurait inventé un classement.

Ce qui tranche est le compteur de primitives, qui est le comptage du
renderer sur ce qu'il a soumis — **byte-identique entre runs** (§2) et
identique sur un téléphone, parce que la soumission ne dépend pas du
rasteriseur.

---

## 8. LE BUDGET — ce qui est réellement disponible

### 8.1 L'ancrage device, et pourquoi il ne donne PAS de modèle linéaire

Deux lectures device de Mathieu : **46 FPS à z ≈ 62,2**, **60 FPS
ailleurs**.

⚠️ **Le 60 est CENSURÉ.** 60 Hz est la cadence de rafraîchissement : « 60
FPS » veut dire « ≤ 16,67 ms », pas « = 16,67 ms ». Le vrai coût au spawn
peut être 10 ms.

⚠️ **Et le 46 est un MÉLANGE, pas un temps de frame.**
`Engine.get_frames_per_second()` est une moyenne glissante ; sur un
affichage à vsync 60 Hz, une moyenne de 46 se produit quand **≈ 30 % des
frames doublent** (16,67 + 16,67 × 0,304 = 21,74 ms). Le coût unitaire réel
à z = 62,2 est donc **juste au-dessus des 16,67 ms**, pas 21,74.

**Conséquence, et c'est la seule chose que ces deux points déterminent
robustement : au bord nord, le device est DÉJÀ à la limite du budget de
frame, et au spawn il est dessous.** Il n'y a **aucune marge** à z ≈ 62 :
chaque primitive ajoutée pousse une frame de plus au-delà du vsync, et
chaque frame doublée est directement visible.

Une borne, si on veut un chiffre : en traitant la moyenne observée comme
un temps de frame (ce qu'elle n'est pas tout à fait), la pente marginale
locale vaut **au moins** (21,74 − 16,67) / 25 521 = **0,199 ms par 1 000
primitives**. C'est une **borne inférieure**, parce que le point de spawn
est censuré par le bas. À prendre comme un ordre de grandeur, jamais comme
un modèle.

### 8.2 Le seuil FPS proposé, et sa justification

**Proposition : 50 FPS (20,0 ms de moyenne observée) comme plancher à
toute station où le joueur peut se tenir dans le lobe.**

Justification, en trois points, aucun n'étant « on a toujours fait
comme ça » :

1. **Il est mesurable avec l'instrument existant.** `HubPerfOverlay`
   affiche déjà `FPS` et `min` sur device, et CH36 y a ajouté la ligne
   `BUILD`. Un plancher device se vérifie en une capture, sans nouvel
   outil.
2. **Il est au-dessus du statu quo et en dessous du plafond.** 46 est ce
   que le nord donne aujourd'hui ; 60 est la cadence de l'écran, donc un
   plancher à 60 rendrait tout module illégal par construction. 50 est
   la première valeur qui exige une amélioration réelle sans exiger
   l'impossible.
3. **Il correspond à un taux de frames doublées de 20 %** (16,67 × 1,20 =
   20,0), contre 30 % aujourd'hui. C'est une grandeur qui a un sens
   perceptif sur une caméra fixe, où le seul mouvement à l'image est le
   défilement du décor — et un défilement qui saute une frame sur trois
   est ce que Mathieu a signalé.

⚠️ **La cible historique de 50 000 triangles n'est pas utilisée ici.**
Elle est déclarée caduque par Mathieu et la mesure lui donne raison : le
hub lit 70 946 au spawn, où le device tient 60 FPS. Un plafond que le
spawn dépasse de 42 % en tenant la cadence ne défend rien.

### 8.3 Ce qui est disponible : **zéro, tant que rien n'est repris**

Au pire cadre mesuré du lobe — **≈ 101 400 primitives / 408 draw calls en
(−10 ; 51)** (§4.3) — et avec le device déjà à la limite à 96 467 :

> **Le budget net disponible pour cinq modules de skatepark est de
> ZÉRO primitive et ZÉRO draw call.** Toute géométrie de park doit être
> **financée** par une reprise d'au moins autant dans la même frame.

### 8.4 Le menu de reprise, mesuré

Deux leviers balayés à z = 51 et z = 63, monde gelé.

**Levier A — densité du tapis d'herbe** (`visible_instance_count` sur les
20 batches `grass`, 1 181 instances) :

| garde | z = 51 | z = 63 | draw calls |
|---|---|---|---|
| 100 % | 95 502 | 96 467 | 405 |
| 75 % | −3 780 | −3 654 | **405 (inchangé)** |
| 50 % | −7 473 | **−7 239** | **405 (inchangé)** |
| 25 % | −11 184 | −10 842 | **405 (inchangé)** |
| 0 % | −14 715 | −14 283 | 398 |

**Linéaire, et gratuit en draw calls jusqu'à 25 %.**

⚠️ **Contre-vérification par un SECOND mécanisme** : PHASE G a caché les
mêmes batches par `visible` et lit **14 409** à z = 63 ; PHASE D les vide
par `visible_instance_count` et lit **14 283**. Écart **126 primitives
(0,87 %)** — deux mécanismes indépendants d'accord. C'est ce qui donne le
droit de croire la courbe.

**Levier B — raccourcir le leash** (cohorte 82 u, 194 nœuds) :

| leash | z = 51 | z = 63 |
|---|---|---|
| 82 u (livré) | 0 | 0 |
| 72 u | 0 | −576 |
| 62 u | −602 | −592 |
| 52 u | −1 056 | **−7 123** |
| 45 u | −1 208 | −7 143 |
| 40 u | −7 587 | −7 143 |
| 35 u | −7 607 | −7 143 |
| 30 u | −7 607 | −7 939 |

**Escalier, pas courbe** — et pour la raison du §3 : le leash agit par
NŒUD, et un nœud de batch couvre une cellule de 28 u. Le levier plafonne à
**≈ 7 900** et exige de descendre à 30 u, où le brouillard n'a effacé que
38 % (`1 − exp(−30 × 0,016)`) contre 73 % à 82 u : **la coupe se verrait**.
Levier faible et cher visuellement.

### 8.5 Verdict sur les 6 000 de CH51 : **confirmé, mais comme un budget FINANCÉ**

CH51 proposait 6 000 primitives gatées dès le premier commit.

* **Le nombre tient.** 6 000 primitives + ~5 draw calls sur une frame de
  ≈ 101 400 / 408, c'est +5,9 % de géométrie et +1,2 % d'appels.
* **Mais il n'est pas gratuit.** Aux ~0,2 ms/1 000 primitives de la borne
  du §8.1, 6 000 coûtent **≥ 1,2 ms** sur une frame qui n'a plus rien.
* **Il est finançable, et par un seul levier.** Amincir l'herbe à **50 %
  de garde dans les cellules nord** reprend **7 239** à z = 63 pour
  **0 draw call** — soit **1 239 primitives de plus** que ce que le park
  dépense.

> **Budget conclu : 6 000 primitives et 5 draw calls pour les cinq
> modules, gaté dès le premier commit, ET conditionné à ce que le MÊME
> lot livre l'amincissement du tapis d'herbe des cellules nord (garde
> ≤ 50 %). Les deux moitiés dans le même commit, sinon le plafond ne
> défend rien.**

Marge nette après financement, au pire cadre : **101 400 − 7 239 + 6 000 =
100 161**, soit **1 239 primitives sous l'état actuel**. Le park n'améliore
pas la frame ; il ne l'aggrave pas.

⚠️ **Ce que ce budget NE couvre pas** : un cinquième véhicule piloté en
continu (option B de CH51) amènerait la **caméra de poursuite**, qui
montre le décor sous des azimuts que le cadre figé n'a jamais montrés —
et **tout ce que ce dépôt a calibré l'a été pour le cadre figé** (CH30).
Le budget ci-dessus est mesuré sous `HubCamera.OFFSET` et **ne vaut pas**
pour une poursuite. Un `ChaseAudit` sur le lobe nord serait un lot à lui
seul.

---

## 9. ZONES D'INCERTITUDE — dites, pas maquillées

**Fermées par la mesure pendant ce lot** (elles étaient dans la liste, elles
n'y sont plus) :

* ~~une seule météo~~ → PHASE W : **spread ≤ 4 primitives** sur les quatre
  météos à trois stations (§5). La météo de ce hub est un paramètre de
  shader, pas un interrupteur de géométrie.
* ~~le balayage x dérive~~ → §4.1 : la dérive venait d'**un seul terme**,
  l'ours, isolé en trouvant les nœuds mobiles **par la mesure** et retiré du
  balayage, son coût publié à part.

**Ouvertes, et il faut les lire avant d'utiliser un chiffre d'ici** :

1. **Deux hauteurs de caméra non balayées.** Toutes les mesures sont prises
   sous `HubCamera.OFFSET` livré. Aucune station n'a été relue à la caméra
   surélevée dont `MountainProbe` PHASE E se sert comme substitut de
   poursuite, et **rien ici ne vaut pour une caméra de poursuite** (§8.5).
2. **Le pire cadre du lobe n'est pas prouvé.** PHASE X balaie x par pas de
   5 u à trois z seulement. (−10 ; 51) est le pire **de ce maillage** ; un
   maillage plus fin en trouverait probablement un pire. Le +42,9 % est donc
   un **plancher** sur l'excès, pas sa valeur.
3. **Le terme mobile (≈ 11 200) dépend d'où en est le casting.** Il est
   publié comme « l'ours, les nuages, les montgolfières et les bouées à cet
   instant », jamais comme un coût permanent. Un joueur qui se tient en
   (−10 ; 51) le paie parfois et pas toujours.
4. **Le modèle device est une BORNE, pas un modèle** (§8.1). Deux lectures,
   dont une censurée par le vsync et une qui est une moyenne de mélange. Le
   seul énoncé device robuste est qualitatif : *au nord, plus de marge*.
5. **`lod0 cadre` et `scene` ne sont pas gatés ici.** Publiés (§3) parce que
   « le shader est cher », « le prop est cher » et « la scène est grosse »
   ne sont pas la même phrase — mais seul `gpu` porte le raisonnement.
6. **Rien de tout ceci ne mesure le temps CPU** d'un `_process`, la mémoire,
   ni le **coût par fragment**. Un module qui coûterait cher en shader plutôt
   qu'en triangles passerait ce budget sans être vu. Idem pour la pluie et le
   brouillard, qui coûtent des pixels que ce banc ne compte pas.
7. **Le compteur compte ce qui est SOUMIS, pas ce qui est DESSINÉ** (CH39).
   Une partie de ce que le nord soumet est déjà effacée par le brouillard
   pour le joueur — et payée quand même.
8. **Une seule graine, un seul état de sauvegarde.** Le hub est mesuré à son
   spawn, sur la graine par défaut.

---

## 10. NEXT STEPS

| # | quoi | pourquoi |
|---|---|---|
| 1 | Rejouer `NorthBudgetProbe` à la **caméra haute** (substitut de poursuite) | §9.1 : rien ici ne vaut pour une caméra qui n'est pas celle du hub |
| 2 | Raffiner PHASE X (pas de 2 u, tous les z de 35 à 63) et **publier le pire cadre du lobe** comme constante lue par le futur gate | §9.2 : un budget se cale sur le pire, et le pire n'est pas prouvé |
| 3 | **Lecture device de Mathieu à (−10 ; 51)**, overlay ouvert, ligne `TRI gpu` + `FPS min` notée | le seul point qui lèverait la censure du §8.1 — et c'est la station qui compte, pas z = 62,2 |
| 4 | Chiffrer l'amincissement du tapis nord comme un **paramètre de `CozyScatter`** (garde par cellule), pas comme un `visible_instance_count` de sonde | le levier du §8.4 doit exister dans le jeu pour financer le park |
| 5 | Le lot skatepark porte **les deux moitiés dans le même commit** : le plafond de 6 000 ET le financement | §8.5 — un plafond ajouté après ne défend rien (CH35-B Q7) |

---

## Fichiers

| fichier | statut |
|---|---|
| `scripts/dev/NorthBudgetProbe.gd` | **créé, permanent** — mesure, ne gate aucun budget ; seuls ses contrôles d'instrument peuvent rougir |
| `scripts/dev/NorthBudgetProbe.tscn` | créé |
| `docs/lots/CH52_BUDGET_NORD.md` | ce fichier |
| `docs/lots/INDEX.md` | une ligne ajoutée |

`ProbeTimeoutAudit` : **PASSED**, 86 scènes de sonde (85 + celle-ci), 1
sonde `--script`. Aucun fichier de gameplay touché.
