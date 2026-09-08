# CH53 — Le skatepark du lobe nord : modules procéduraux, cinquième véhicule, et son financement

**8 septembre 2026.** Le lot qui exécute le plan de CH51 sous le budget de
CH52, avec les six décisions que Mathieu a tranchées entre les deux :
garde-fou **G3**, mécanique **option B**, modules **posés sur l'herbe**,
assets **procéduraux** (pas de Meshy), style **béton**, densité **rampes +
rail**.

---

## 0. LA BASE, ET LA GARDE DE CONCURRENCE

La branche de ce lot avait été ouverte sur **`main` (`2876f27`)**, qui ne
porte ni CH50, ni CH51, ni CH52 — c'est-à-dire un hub dont le lobe nord
vaut encore R = 12. Repositionnée sur `origin/staging` (`e5ae4b0`) avant
la première ligne de code, exactement comme CH51 avait dû le faire.
**Tout lot de cette suite part de `staging`.**

Garde de concurrence, faite **au début** et **par arbre** :

| ref | verdict |
|---|---|
| `origin/claude/lot-zone0-nord-skatepark-ezbguf` | ancêtre de `staging` → **déjà mergée** (CH50) |
| `origin/claude/skatepark-trick-minijeu-xyuy9a` | ancêtre de `staging` → **déjà mergée** (CH51) |
| `origin/claude/budget-mesure-z35-z63-hfmh7f` | ancêtre de `staging` → **déjà mergée** (CH52) |

Aucune session concurrente vivante sur ce sujet.

**Deux arbres importés séparément, comptés des deux côtés avant toute
comparaison : 154 `.scn` dans chacun, zéro `Cannot open file`.** Sans ce
compte, une baseline tronquée se lit comme une régression (CLAUDE.md).

---

## 1. CE QUI EST LIVRÉ

| pièce | fichier | ce qu'elle fait |
|---|---|---|
| la géométrie | `scripts/hub/SkateparkMesh.gd` | cinq modules + la planche, construits en GDScript |
| le park | `scripts/hub/HubSkatepark.gd` | la table `MODULES`, le placement, le score, la chaîne |
| le HUD | `scripts/hub/SkateHud.gd` | lit le park, ne décide rien |
| le béton | `CozyPalette.concrete_material()` | le seul matériau non organique du hub |
| le véhicule | `HubTransport.VEHICLE_SKATE` | cinquième véhicule famille B, **porte de tap existante** |
| le grand livre | `WorldSave.award_from_activity()` | la seule conversion points → ressources, et G3 |
| le financement | `CozyScatter.NORTH_COVER_KEEP` | garde par cellule sur le tapis nord |

**Deux sondes permanentes**, séparées par driver et non par sujet :
`SkateparkProbe` (pixels, points d'écran, compteurs → `xvfb` + `opengl3`)
et `SkateTraverseProbe` (transformes et entiers → **headless**). Une sonde
jetable, `NorthCarpetCensus`, a servi à la table croisée et **a été
supprimée avant le commit**.

---

## 2. LE BUDGET — ce que le park coûte et ce que le tapis rend

### 2.1 Le park

| module | triangles |
|---|---|
| funbox | 20 |
| rail | 36 |
| quarterpipe haut (2,10 u) | 50 |
| quarterpipe bas (1,45 u) | 50 |
| bol | 312 |
| **total** | **468** |

Contre le plafond **6 000** de CH52 : **7,8 % du budget accordé**. Ce n'est
pas de la modestie, c'est le régime que CH52 impose — chaque triangle
dépensé ici doit être **racheté** dans la même frame, donc un park cher est
un tapis d'herbe plus rasé.

Le bol pèse les deux tiers du park à lui seul (24 azimuts × 5 anneaux). Les
quatre autres sont des primitives : un profil balayé, deux boîtes, un plan
incliné.

### 2.2 Le tapis nord, mesuré des deux côtés

Recensement lu sur les **transformes** des 20 batches `grass`, pas sur leurs
noms :

| | `origin/staging` | CH53 | delta |
|---|---|---|---|
| instances d'herbe, hub entier | 1 181 | 945 | −236 |
| instances **au nord de z = 35** | **406** | **179** | **−227** |
| triangles de ces instances | **6 819** | **2 973** | **−3 846** |

> **Le park coûte 468 triangles ; la garde en rend 3 846. Le financement
> est de 8:1.**

⚠️ **Le « 7 239 » de CH52 n'est PAS ce nombre et n'a jamais pu l'être.**
Cette figure est celle de sa PHASE D, qui vidait à 50 % **tous** les
batches d'herbe du hub par `visible_instance_count` — le tapis du spawn
compris, à 60 u au sud. La garde de ce lot ne touche que les cellules
nord. La prémisse du brief (« éclaircir l'herbe des cellules nord à 50 %
récupère 7 239 ») est **tombée à la mesure**, et le lot n'en avait pas
besoin : il finance un park de 468, pas de 6 000.

### 2.3 La frame, aux deux bouts

Recensement pris **au même protocole sur les deux arbres**, monde gelé, et
**retourné contre lui-même d'abord** : deux runs du même arbre sortent
**byte-identiques** sur les cinq stations et sur les 20 lignes de batch.
C'est ce qui donne le droit de lire un delta entre deux arbres (CH37 —
un gate qui ne se reproduit pas sur un seul arbre ne peut rien dire de
deux).

| station | `staging` gpu | CH53 gpu | **net** | calls |
|---|---|---|---|---|
| (0 ; 0) spawn | 70 946 | 70 923 | **−23** | 303 → 301 |
| (0 ; 42) entrée | 96 059 | 92 615 | **−3 444** | 375 → 376 |
| (−10 ; 51) **pire cadre CH52** | 101 510 | 97 890 | **−3 620** | 364 → 368 |
| (0 ; 51) | 96 942 | 93 094 | **−3 848** | 389 → 391 |
| (0 ; 63) rim | **96 467** | 93 253 | **−3 214** | 405 → 412 |

**La ligne de contrôle est la première colonne du dernier rang** :
`staging` rend **96 467** à z = 63, le chiffre exact publié par CH52. Le
banc restitue un chiffre déjà au dossier avant d'en publier un neuf.

> **La consigne du brief était « viser un chiffre ÉGAL ou INFÉRIEUR ». Le
> lot rend le corridor nord plus léger de 3 200 à 3 850 primitives à
> chacune de ses stations, et laisse le spawn à −23.**

Le coût du park lui-même, mesuré en le CACHANT à chaque station, monde
gelé : **+56** en (0 ; 42), **+50** en (−10 ; 51), **+468** en (0 ; 51) et
(0 ; 63). Les deux premiers sont du culling de frustum, pas une remise :
depuis (−10 ; 51) le moteur ne soumet qu'un module.

⚠️ **Le plancher de bruit de ces stations est 0, et c'est un résultat, pas
un oubli.** Le monde est GELÉ pendant la lecture A/B, donc l'ours ne
marche plus, les papillons ne volent plus, et six lectures consécutives
rendent le même entier. C'est la condition sous laquelle un delta de +50
est une mesure et non une dérive — mais elle rend l'assertion
« delta > plancher » facile, et le dire fait partie du résultat.

### 2.4 Les draw calls

**+5 pour les cinq modules**, exactement ce que CH51 prévoyait, plus la
planche. Total au rim : **412 contre 405**, soit **+1,7 %**.

⚠️ **La planche est un sixième nœud dessiné que CH52 n'avait pas budgété**
— son §8.5 excluait le cinquième véhicule pour une autre raison (la caméra
de poursuite), qui ne s'applique pas ici : cette planche est un modificateur
de saut, pas un véhicule piloté, et la caméra reste **FIGÉE**.

---

## 3. LE PLACEMENT — et la première version était fausse

C'est la partie du lot qui a coûté un aller-retour, et CH51 avait annoncé
qu'elle le coûterait : *« la lisibilité est une question d'image ; seul un
rendu y répond »*.

**Premier layout**, celui qu'on dessine sur une feuille : cinq modules
étalés sur x ∈ [−7,5 ; +8,5], centre (0 ; 50), la planche garée au sud sur
le chemin d'arrivée. Rendu, `unproject_position` depuis l'entrée :

```
m0:(-755, 1226)  m1:(639, 1691)  m2:(1835, 1534)  m3:behind  m4:(13292, 11210)
```

sur un canvas de **1080** de large. **Un module dans le cadre sur cinq**, et
**trois qui ne peignaient aucun pixel** — la sonde les a lus à zéro.

### 3.1 L'arithmétique qui décide, et elle est entièrement dans CLAUDE.md

`HubWorld.tscn` pose `keep_aspect = 0` (**KEEP_WIDTH**) et `fov = 45` : les
45° sont l'angle **HORIZONTAL**, demi-angle 22,5°. `HubCamera.OFFSET` vaut
`(0 ; 7,6 ; 8,9)`, la caméra ne yaw jamais et ne montre que des z
inférieurs au sien. Un module en `z` est donc dans le cadre depuis un
joueur en `z_p` **ssi** :

```
|x| ≤ tan(22,5°) · (z_p + 8,9 − z)      et      z < z_p + 8,9
```

Au z du joueur lui-même cela vaut **±3,69 u** — pas « environ 3 u » d'une
règle de pouce — et tout ce qui est à plus de **8,9 u au NORD** est
derrière l'objectif, purement et simplement.

### 3.2 Ce que ça impose

Le park est donc **étroit** (x ∈ [−4,2 ; +5,0]) et **long**
(z ∈ [45,5 ; 55,5]).

| module | position | h | tap |
|---|---|---|---|
| funbox | (0,0 ; 45,5) | 0,85 | 2,4 |
| rail | (4,2 ; 48,5) | 0,62 | 2,4 |
| quarterpipe | (−4,2 ; 50,5) | 2,10 | 2,6 |
| quarterpipe | (5,0 ; 54,0) | 1,45 | 2,4 |
| bol | (−0,5 ; 55,5) | 1,35 | 3,0 |

Modules dans le cadre, **mesurés par `unproject` sur la caméra livrée** :

| station | dans le cadre |
|---|---|
| (3 ; 60) — le point de montage | **5 / 5** |
| (0 ; 58) | **5 / 5** |
| (0 ; 52) — milieu du park | 4 / 5 |
| (0 ; 42) — l'arrivée depuis le plateau | **1 / 5** |

### 3.3 ⚠️ ET LA PLANCHE EST GARÉE AU NORD À CAUSE DE ÇA

C'est la décision non évidente du lot, et elle ne coûte rien.

La place naturelle d'une planche est le **sud**, sur le chemin d'arrivée.
Rendue, c'est la mauvaise : un rider qui monte au sud roule **en
s'éloignant** de l'objectif, dans un park entièrement derrière lui. Monté
au **nord**, il roule vers le sud avec **les cinq modules devant lui dans
le cadre**. Mêmes modules, même caméra, lecture opposée.

`SKATE_PARK` = **(3,0 ; 0 ; 60,0)**, et le `x = 3` est lui aussi une
trouvaille de sonde : garée sur l'axe en (0 ; 60) la planche était à
**4,53 u** du centre du bol contre 5,6 requis — c'est-à-dire **posée sur
le rebord du bol**. La phase G l'a signalé comme un chevauchement
d'emprise.

⚠️ **L'arrivée depuis le plateau reste à 1 module sur 5, et c'est
ACCEPTÉ, pas raté.** CH51 §4.3 a posé ce compromis à Mathieu
explicitement et il l'a pris (*« je ne le rediscute pas »*). Ce que ce
layout achète, c'est que **la direction de conduite** se lise ; l'approche
ne peut pas, sous une caméra qui ne tourne pas. Le chiffre est **publié**
par la sonde et **exclu du gate** — un gate sur une station que la caméra
ne peut pas servir serait un gate qu'aucun layout ne passe.

Le marqueur minimap `PLACE` est ce qui rend le park trouvable depuis le
plateau. Il est posé sur un **nœud enfant placé au centre du park**, jamais
sur `self` : `HubSkatepark` est précisément le genre de contrôleur qui ne
bouge jamais de l'origine du monde, et CH46 a épinglé sept marqueurs PNJ
sur (0, 0, 0) pour cette raison exacte.

---

## 4. LA MÉCANIQUE — option B, et ce qu'elle ne peut pas faire

### 4.1 Le véhicule, sans une seule ligne de routage neuve

`HubTransport.VEHICLE_SKATE = 4`. La planche entre par la **porte de tap
existante** : `tapped_vehicle` → `vehicle_at()` → `_try_mount_ball()` →
`KeepyHopper.mount_vehicle(board, SKATE_LIFT)`. Le patron du Sautillon,
nommé comme tel par Mathieu : véhicule **bondissant**, donc chaque hop
passe à `VEHICLE_HOP_DISTANCE` 2,7 u et `VEHICLE_HOP_HEIGHT` 1,15 u.

Ni glissant (le char à voile), ni piloté (le char, le voilier, la luge
depuis CH30) — et le second point est un vrai garde-fou budgétaire : un
véhicule piloté amène la **caméra de poursuite**, dont CH52 §8.5 dit
explicitement que son budget « ne vaut pas » pour elle. Un `ChaseAudit` du
lobe nord serait un lot à lui seul.

La planche suit le patron **BATEAU** sans code neuf : `vehicle_at()` ne
répond que pour un véhicule qu'il ne monte pas déjà, donc un tap sur la
planche montée retombe sur le chemin sol et **devient** la sortie.

### 4.2 ⚠️ LE SCORE EST UN PROXY, ET LE FICHIER LE DIT

CH51 §3.2 argumentait le contraire et avait raison sur le mécanisme :
*« un test "l'atterrissage est dans le disque du module" ne distingue pas
"il a fait un air sur la rampe" de "il est retombé à côté d'elle" »* —
c'est la doctrine CH43 dans sa forme générale.

**Mathieu a tranché contre**, explicitement : pas de physique, pas de
collider, le proxy d'atterrissage, et la vraie chose nommée comme une
dette différée. Donc le proxy est ce qui part, et la conséquence est
**écrite dans l'en-tête de `HubSkatepark`** plutôt que maquillée : ce
fichier **ne sait pas distinguer un trick d'un atterrissage**, et chaque
nom de trick (`air`, `grind`, `carve`, `ollie`) est une **étiquette de
module**, pas la classification de quoi que ce soit.

Un proxy n'a que deux défenses, et les deux sont câblées :

1. **Rien ne score à pied.** `note_landing` refuse hors planche. Sans ça,
   traverser le park à pied farme — et la passe rouge l'a démontré en
   grandeur nature (§6).
2. **Le même module deux fois ne chaîne pas.** C'est le plus petit
   substitut honnête à « il a fait autre chose ».

### 4.3 La chaîne

Atterrissages successifs, sur des modules **différents**, à moins de
`CHAIN_WINDOW_S` = **3,4 s** — dérivé et non choisi : un hop de véhicule
dure 0,34 s pour 2,7 u, l'écart le plus large du layout fait 10,1 u, soit
quatre hops soit 1,36 s de vol, plus le doigt. Multiplicateur
`1 + 0,5 · n`, plafonné à n = 5 parce que le garde-fou en aval est un
**stock** et qu'un multiplicateur non borné viderait la session en une
ligne.

L'horloge est **la simulation, pas le mur** : sous `--fixed-fps 60` un
banc simule bien plus vite que les secondes réelles, et une fenêtre de
chaîne lue sur `Time.get_ticks_msec()` serait une règle différente en
sonde et sur téléphone.

---

## 5. G3 — LE GARDE-FOU, ET LE MÉCANISME QUE MATHIEU A DEMANDÉ DE RÉUTILISER

La consigne était « **réutilisant** le mécanisme `tree_stock()` /
`TREE_RECHARGE_S` déjà écrit et sondé ». Réutiliser veut dire **appeler**,
pas recopier : une seconde implémentation de recharge paresseuse serait
une seconde chose à rater sur une horloge qui recule, sur le crédit
partiel d'une période entamée, et sur une entrée jamais touchée qui doit
se lire pleine.

L'arithmétique des arbres a donc été **sortie** dans `_stock(id, capacity,
recharge)` / `_take(...)`. `tree_stock` et `tree_take` l'appellent avec
`TREE_CAPACITY` / `TREE_RECHARGE_S` et lisent exactement ce qu'ils lisaient
(le compteur `shakes` est resté chez `tree_take` : un trick n'est pas une
secousse).

**Aucun bump de schéma.** Le stock du park est une entrée du **même**
dictionnaire `trees` sous un id réservé (`"skatepark"`), que `_sanitise`
type déjà et que `_defaults` fournit déjà. Le clamp y vaut `TREE_CAPACITY`,
et **c'est ce qui borne la capacité du park à 3** : au-dessus, un rechargement
du fichier tronquerait silencieusement — un park qui vaut 12 avant un
reload et 3 après, sans rien pour le dire.

| réglage | valeur | pourquoi |
|---|---|---|
| `SKATE_CAPACITY` | 3 | le clamp de `_sanitise`, pas un choix |
| `SKATE_RECHARGE_S` | 180 s | un robinet **plus petit** que celui du monde (59 arbres, 295 noisettes d'ouverture, ~59/min de régime) |
| `POINTS_PER_NUT` | 150 | une rampe vaut 60, le bol 80 : une noisette tous les deux ou trois tricks |
| `AWARD_KIND` | `hazelnut` | pas de nouvelle monnaie — il y a **un seul puits** dans ce jeu |

**La variante retenue par Mathieu** : le trick score toujours, le combo
monte toujours, le HUD l'affiche toujours ; seule la **conversion**
s'arrête. Un park qui refuserait de scorer se lirait comme cassé.
`award_from_activity` rend **ce qu'il a réellement crédité** précisément
pour que le HUD puisse le dire sans re-dériver la règle.

⚠️ **La banque de points est vidée même quand le stock n'a pas payé.**
Sinon un park vide garderait une banque pleine et lâcherait tout d'un coup
à la première unité repoussée : le garde-fou plafonnerait le total d'une
session mais aucune fenêtre plus courte, ce qui est exactement le burst
qu'il existe pour empêcher.

`ACTIVITY_STOCK` est une **table dès la première entrée** : un second jeu
de trick est une ligne, jamais un second cooldown.

---

## 6. ROUGE AVANT VERT — cinq neutralisations, et deux ont trouvé quelque chose

Chaque mécanisme neuf a été neutralisé isolément, la sonde devait sortir
**ROUGE sur les assertions attendues et pas d'autres**, puis le fichier a
été restauré et vérifié **byte-identique** (`cmp`).

| neutralisation | rouges attendus | obtenus | verdict |
|---|---|---|---|
| l'enroulement (`_tri`, convention inversée) | 5 | **4** puis **9** | **a trouvé un défaut de sonde** — §6.1 |
| le refus « rien ne score à pied » | 2 | **3** puis **2** | **a trouvé un défaut de `reset()`** — §6.2 |
| le stock G3 | 3 | 3 | L7, L8, L9 |
| la remise à zéro de chaîne sur le même module | 1 | 1 | R12 |
| le rect du HUD (coordonnée canvas au lieu d'offset) | 1 | 1 | H2, panneau lu **870 → 1290 sur 1080** |

### 6.1 ⚠️ UN TEST DE SILHOUETTE NE VOIT PAS UN SOLIDE CONVEXE FERMÉ RETOURNÉ

La passe rouge de l'enroulement a rendu **quatre** rouges là où **cinq**
étaient attendus. Le survivant était le **rail**, à **0,9977** de ses
pixels conservés.

Ce n'est pas un défaut du rail, c'est de l'arithmétique : **un solide
convexe fermé rendu à l'envers couvre EXACTEMENT la même silhouette.** On
voit l'intérieur de sa paroi lointaine au lieu de l'extérieur de sa paroi
proche, et un aplat non éclairé ne distingue pas les deux. Un **comptage
de pixels est un test de silhouette**, et une silhouette ne change pas
sous inversion. Les quatre autres modules sont **ouverts** (dessous
absent), donc leur silhouette, elle, s'effondre.

C'est la règle « le nombre d'échecs attendus fait partie de l'assertion »
qui a transformé ça en trouvaille au lieu d'un haussement d'épaules. Et la
réponse n'est pas de baisser le premier test, c'est d'en **ajouter un qui
discrimine** :

> **QUELLE SURFACE EST DEVANT.** Un shader encode la profondeur en espace
> vue. Rendu `cull_back`, un corps bien enroulé montre sa surface
> **PROCHE** ; `cull_front` montre la **LOINTAINE**. Retourné, les deux
> échangent. La moyenne encodée sous `cull_back` doit donc être **plus
> petite** que sous `cull_front` — un **SIGNE**, sans seuil à régler, et
> qui marche sur un corps fermé là où la silhouette ne peut pas.

Mesuré sur la géométrie correcte : 0,3737 < 0,4017 (funbox), 0,3540 <
0,3568 (rail), 0,2837 < 0,3090, 0,2749 < 0,2892, 0,2435 < 0,2465.
Re-neutralisé : **les cinq** modules sortent `** INVERTED **`, rail
compris, pour **9 rouges** (4 de silhouette + 5 de profondeur).

⚠️ **Et le rappel qui rend ça non-optionnel : le shader décor de ce dépôt
est `cull_disabled`.** Un park construit à l'envers serait **PARFAIT
aujourd'hui** et disparaîtrait le jour où un lot lui donne un matériau qui
cull — c'est le piège CH39 dans sa forme exacte.

### 6.2 La passe rouge a trouvé un défaut hors du park

Neutraliser le refus « rien ne score à pied » a rendu **3** rouges au lieu
de 2, et le troisième était **L6**, dans une phase qui tourne **avant**.
Explication : la phase X marche à travers le park à pied ; sans le refus,
**ces pas scoraient**, remplissant la banque de points, et l'assertion
« sous le seuil, rien n'est crédité » de la phase suivante basculait.

Le rouge inattendu était donc une démonstration plus forte que celle
visée — une marche ordinaire farmait le park — **et** un vrai défaut :
`WorldSave.reset()` ne vidait pas `_activity_bank`. Des points banqués
sont de l'état qu'une remise à zéro doit effacer, même si aucun champ ne
les tient. Corrigé ; la passe rouge rend maintenant exactement 2.

### 6.3 Ce qui n'a PAS de passe rouge, et pourquoi c'est dit

**La garde d'herbe nord n'est gatée par aucune assertion**, et ne peut pas
l'être sur un seul arbre : elle retire les instances **à la génération**,
donc aucune sonde ne peut les remettre. Sa preuve est la **table croisée**
du §2.3, prise au même protocole des deux côtés et reproductible à
l'octet sur un même arbre. La seule chose qu'un arbre unique peut
asserter, et que la phase D asserte, c'est qu'il **existe** un tapis nord
à amincir (179 instances) — sans quoi tout l'argument de financement
serait vide.

---

## 7. LA TRAVERSÉE — marchée, pas déduite

CH51 §4.1 avait **lu** que la traversée était inchangée par construction :
`KeepyHopper._is_clear(point, blocked)` ne reçoit un `blocked` qu'à **un
seul endroit** du dépôt (le point de berge du bateau), et les `_holes` de
`HubRegion` n'agissent que sur une **destination**. Une lecture n'est pas
une mesure ; ce lot ajoute cinq objets d'apparence solide en travers du
lobe, donc les chiffres ont été **re-marchés sur le vrai `KeepyHopper`**.

| trajet | hops | secondes | publié | verdict |
|---|---|---|---|---|
| diagonale du carré (**contrôle**) | 66 | **18,700** | 66 / 18,700 | identique |
| pire CH38 (35 ; −35) → (−63 ; 18) | 74 | **20,967** | 20,967 | identique |
| pire CH50 (−63 ; −12) → (22,43 ; 51,74) | 71 | **20,117** | 20,117 | identique |
| **à travers le park** (0 ; 40) → (0 ; 61) | 14 | 3,967 | — | droit (prédiction 3,920) |

**Les trois publiés sont inchangés à la milliseconde**, et la traversée
neuve que ce lot invente est une chaîne **droite**, pas un contournement.
La diagonale de contrôle est aussi ce qui donne au banc le droit de
publier le chiffre neuf.

⚠️ Cette conclusion expire le jour où quoi que ce soit ajoute de
l'évitement d'obstacle au hopper.

---

## 8. TABLE CROISÉE DES SONDES EXISTANTES

Rejouées **sur les deux arbres, séquentiellement** (CH37 : une sonde à
séquence temporelle se rejoue à charge comparable, ou son verdict n'est pas
comparable), après avoir compté 154 `.scn` de chaque côté.

| sonde | driver | `origin/staging` | CH53 | verdict |
|---|---|---|---|---|
| `SeesawProbe` | headless | **2 échecs** (draw nodes 157 ≠ 144 attendus) | **2 échecs, mêmes lignes, mêmes nombres** | **préexistant sur `staging`** — pas ce lot |
| `ZiplineStructureProbe` | headless | **8 échecs** | **8 échecs, lignes identiques au diff** | **préexistant sur `staging`** — pas ce lot |
| `MountainProbe` | xvfb + opengl3 | ALL GREEN, 0 rouge | ALL GREEN, 0 rouge | parité |
| `MinimapProbe` | xvfb + opengl3 | ALL GREEN, 0 rouge | **1 rouge → corrigé → 190 checks, 0 rouge** | §8.1 |
| `NorthBudgetProbe` (CH52) | xvfb + opengl3 | ALL GREEN, 0 rouge | ALL GREEN, 0 rouge | parité, et §8.2 |
| `ProbeTimeoutAudit` | headless | PASSED, **86** scènes | PASSED, **88** scènes | +2 = les deux sondes permanentes de ce lot ; la jetable est supprimée |

Les rouges de `SeesawProbe` et `ZiplineStructureProbe` ont été comparés
**ligne à ligne** (`diff` des lignes `FAIL`) : **identiques des deux
côtés**. Ce sont des rouges que `staging` porte déjà ; ce lot ne les crée
pas et ne les répare pas.

### 8.1 La seule vraie régression, et c'était un inventaire littéral

`MinimapProbe` est sorti **rouge sur la branche et vert sur la
référence** — la forme exacte qu'une régression prend. L'assertion :

```
_check(members_total == 37, "all 37 markers are still on the map ...")
```

CH53 ajoute **deux** marqueurs : la planche (`VEHICLE`) et le site du park
(`PLACE`). Le diff des inventaires le dit sans ambiguïté — `vehicle 12 →
13`, `place 15 → 16`, tout le reste identique, et les deux nouveaux glyphes
passent **toutes** les autres assertions de la sonde (ton propre,
isolation, séparation).

Ce n'est donc pas un défaut du lot : c'est un **littéral d'inventaire**, la
famille que CLAUDE.md décrit comme « fausse au premier nom oublié ». Il n'y
a rien dont le dériver — l'inventaire EST la liste de ce que le hub
construit — donc le nombre est passé à 39 **avec son historique écrit à
côté**, et il reste une **ÉGALITÉ** : un `>=` laisserait une suppression se
cacher derrière l'ajout suivant.

### 8.2 `NorthBudgetProbe` confirme le financement par un SECOND instrument

La sonde de CH52, **non modifiée**, rejouée sur les deux arbres. Ses dix
stations, sur son propre protocole :

| station | `staging` | CH53 | delta |
|---|---|---|---|
| (0 ; 0) spawn | 70 946 | 70 923 | **−23** |
| (−5 ; 35) pire frame CH22 | 94 601 | 91 219 | **−3 382** |
| (0 ; 35) | 87 477 | 84 447 | −3 030 |
| (0 ; 39) | 86 999 | 83 987 | −3 012 |
| (0 ; 43) | 95 917 | 93 082 | −2 835 |
| (0 ; 47) | 95 337 | 92 971 | −2 366 |
| (0 ; 51) | 97 114 | 93 736 | −3 378 |
| (0 ; 55) | 96 336 | 93 214 | −3 122 |
| (0 ; 59) | 96 102 | 92 784 | −3 318 |
| (0 ; 63) rim | **96 467** | **93 253** | **−3 214** |

Deux choses valent d'être dites :

* **elle restitue les chiffres de CH52 à l'unité** sur la colonne
  `staging` (70 946, 94 601, 96 467 — les valeurs publiées) ;
* et son **93 253 à z = 63 est exactement** celui du recensement du §2.3,
  pris par un autre script, à un autre protocole. **Deux instruments
  indépendants tombent sur le même entier.** C'est ce qui donne au
  financement de ce lot le statut de mesure et pas d'estimation.

---

## 9. LE STYLE — béton, et ce que ça veut dire dans un hub non éclairé

Les gris sont **cuits dans les sommets** (`ARRAY_COLOR`), et la teinte du
matériau reste blanche : un `tint` multiplie, il ne peut pas recolorer
(CLAUDE.md). Quatre valeurs — béton, dalle, coping, dessous sombre.

`CozyPalette.concrete_material()` part du **même shader décor** (donc du
même programme, du même brouillard, de la même météo) et déplace quatre
paramètres :

| paramètre | décor | béton | pourquoi |
|---|---|---|---|
| `rim_strength` | 0,22 | **0,0** | le rim est ce qui fait lire un buisson comme un corps rond ; sur une arête coulée c'est un reflet mouillé, et c'est l'indice le plus « organique » du shader |
| `band_softness` | 0,28 | **0,9** | la bande toon dure est le second indice ; à 0,9 une transition courbe lit comme un dégradé |
| `lit` / `shade` | 1,06 / 0,80 | **1,0 / 0,88** | une surface mate a peu d'écart entre sa face éclairée et sa face à l'ombre |
| `shade_tint` | (0,86 ; 0,92 ; 1,0) | **(0,97 ; 0,97 ; 0,98)** | une ombre froide sur du gris est précisément la note à retirer |

⚠️ **Le brouillard est GARDÉ, et ce n'est pas un oubli** : tout l'indice de
distance de ce hub est ce haze exponentiel. Un module qui ne s'effacerait
pas avec la distance serait le seul objet du plateau à ne pas le faire, et
lirait comme un décalque.

⚠️ **Et `_concrete` est dans l'énumération de `apply_weather`.** Cette
fonction est une **liste** des matériaux que la météo atteint — la forme
exacte que CLAUDE.md décrit comme « fausse au premier nom oublié ». Un
matériau absent ne lève rien : il cesse simplement de prendre la teinte
de l'orage et ne collecte jamais de neige.

⚠️ **Le bol est POSÉ sur l'herbe, il n'est pas CREUSÉ dedans.** Un vrai
bol est un trou, et un trou dans ce hub est une feature **multi-altitude** :
CH18 a coûté treize sections pour ça. Une vasque posée sur la pelouse n'en
demande aucune — le sol reste `y = 0` sous elle, la résolution du tap est
intacte, la région n'apprend aucune forme neuve. Ce que ça coûte est
l'honnêteté sur la lecture : c'est un bol **portable**, celui qu'un parc
pose sur une pelouse, pas une piscine coulée.

---

## 10. ZONES D'INCERTITUDE — dites, pas maquillées

1. **Aucun pixel de ce lot n'a été vu sur un GPU réel.** llvmpipe sous
   xvfb n'est pas WebGL2 sous Safari iOS. Ce qui traverse est la
   **géométrie** et le **cadrage** ; le rendu du béton, lui, reste à
   confronter sur device.
2. **Le plancher de bruit des stations est 0 parce que le monde est
   gelé.** L'assertion « le delta dépasse le plancher » est donc facile.
   Ce qui la sauve est que le gel rend le compteur **déterministe** (six
   lectures, même entier).
3. **Le pire cadre du lobe n'est toujours pas prouvé** (CH52 §9.2) :
   (−10 ; 51) est le pire d'un maillage à pas de 5 u. Les mesures de ce
   lot héritent de cette borne.
4. **Le proxy d'atterrissage reste un proxy** (§4.2). La physique réelle
   est une dette nommée, différée par décision explicite.
5. **La garde d'herbe n'a pas de passe rouge** (§6.3) — sa preuve est
   croisée, pas neutralisable.
6. **Rien ici ne mesure le coût par fragment.** Le béton est un shader de
   plus dans la frame ; le banc compte des primitives, pas des pixels
   ombrés.
7. **La capacité du stock est bornée par le sanitiseur à 3**, ce qui est
   petit. La monter est une conversation de schéma, pas un réglage.

---

## 11. NEXT STEPS

| # | quoi | pourquoi |
|---|---|---|
| 1 | **Lecture device de Mathieu** — station (−10 ; 51), overlay ouvert, `FPS min` et `TRI gpu` notés | le seul point qui lèverait la censure du modèle device de CH52 §8.1, et le seuil de 50 FPS de ce lot |
| 2 | La **physique réelle** du trick (dette CH51 §3.2, différée par décision) | tant qu'elle n'existe pas, le score est un proxy et le fichier doit continuer à le dire |
| 3 | Un `ChaseAudit` du lobe nord **si** un véhicule piloté y arrive un jour | CH52 §8.5 : ce budget ne vaut pas pour une caméra de poursuite |
| 4 | Raffiner le pire cadre du lobe (pas de 2 u) | CH52 §9.2, toujours ouvert, et ce lot s'appuie dessus |
| 5 | Le **son** du park (rien n'a été touché côté audio) | un skatepark muet est ce qui part aujourd'hui |
