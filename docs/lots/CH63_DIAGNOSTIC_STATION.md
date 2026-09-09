# CH63 — DIAGNOSTIC : le contact sur « le bol », et la chute de FPS

**Lot de DIAGNOSTIC. Aucun correctif livré, et c'est le résultat.**
Branche `claude/diagnostic-bol-fps-ai8hv1`, depuis `origin/staging`
(69a230f, CH62). **Rien n'est mergé vers `staging`.**

Deux signaux à élucider, sur une même capture device, station
**(−1,9 ; 51,3)**, physique ON : `pairs 6` avec un ressenti de montée sur
« le bol », et FPS 39 (min 30) / physMAX 3,60 ms contre 55-56 FPS et
~1-2 ms auparavant.

## L'instrument, prouvé avant d'être cru — et il s'est attrapé lui-même

`SkateStationDiagProbe` interroge le **SERVEUR PHYSIQUE**
(`intersect_point` / `intersect_shape`), jamais un nom de nœud. PHASE I
exige, dans cet ordre : un point dans un module solide **VU**, un point
sur la pelouse **VIDE**, puis le retrait du layer qui doit **aveugler** le
premier, puis sa restauration qui doit le **rendre**.

⚠️ **Et c'est exactement ce qui a sauvé ce lot.** La première version
prenait l'espace physique sur `_hub as Node3D` — dont la racine n'est pas
un `Node3D`, donc le cast rendait `null` et **toutes** les requêtes
sortaient vides. Les deux assertions négatives (« la pelouse est vide »,
« le point s'aveugle ») sont sorties **VERTES** sur un instrument qui ne
voyait rien du tout ; seule la POSITIVE est sortie rouge. **Un contrôle
« ça s'aveugle » passe gratuitement contre un instrument déjà aveugle** —
les deux négatives portent désormais un garde qui refuse de scorer quand
la positive a échoué.

## Ce qui touche réellement la station (preuve serveur physique)

| lecture | résultat |
|---|---|
| colonne solide au-dessus de (−1,9 ; 51,3) | y = 0,05 → 0,15, portée par **`Skate_quarterpipe_2/QuarterpipeCollider`** |
| capsule de la planche posée à la station | **5 formes**, toutes du même corps |
| indices de modules touchés | **[2]** — et rien d'autre |
| distance au centre du **bol** [4] | **4,427 u**, aucune forme touchée |

`MODULES[2]` est le **quarterpipe de 7,0 × 2,1 × 2,1** à (−4,2 ; 50,5),
c'est-à-dire **la grande rampe courbe**. La station est à 2,435 u de son
centre, dans son emprise. **Ce que Mathieu appelle « le bol » est le grand
quarterpipe** ; le bol réel est 4,4 u plus au nord.

## VERDICT SUR LE BOL : aucun collider, et il n'en a jamais eu

Deux lectures indépendantes, plus un blind check.

**Structurelle** — `collider_indices()` rend **[0, 1, 2, 3]** (funbox 3
pièces, rail 3, les deux quarterpipes 12 chacun) ; `pieces_for(bowl)` rend
**vide** ; `collider_body_at(4)` rend **null**.

**Physique** — balayage dense du cylindre d'emprise du bol : **47
échantillons solides**, dont **41 appartenant au quarterpipe [2]** et **6
au quarterpipe [3]**. **Zéro** à un corps du bol.

⚠️ **Et ce 47 est précisément le piège que la première version aurait
publié.** Le rayon d'emprise du bol est 4,4 et la masse du grand
quarterpipe arrive à 2,9 u de son centre : **le cylindre d'emprise du bol
contient un morceau de son voisin**. Un compte de 47 lu seul dit « le bol
est solide ». Ce qui répond à la question est **à QUI appartient chaque
échantillon**, jamais combien il y en a.

**Historique** — `git log -L` sur `pieces_for` : deux commits seulement,
`7e43d93` (CH57) et `e2a4972` (CH60). Depuis CH60 la fonction rend vide
pour le bol et **personne ne l'a touchée**. CH61 et CH62 ne touchent pas
`HubSkatepark.gd` sur ce point. **Les rapports ont raison, et Mathieu
aussi : il sent bien un solide, ce n'est simplement pas celui qu'il
nomme.**

## `pairs 6` reproduit

| situation | pairs |
|---|---|
| planche montée, pelouse libre | **0** (blind check) |
| planche montée, à l'arrêt à la station | **1** |
| planche **roulant** en travers de la transition | **7** |

Le 6 du device tombe entre les deux : une planche en mouvement recoupe
plus d'AABB de coins que la même à l'arrêt. Le compteur est
`PHYSICS_3D_COLLISION_PAIRS`, un total MONDE — 6 paires, c'est la planche
contre 6 des 12 coins convexes du quarterpipe, et rien d'autre dans la
carte n'en produit.

## VERDICT SUR L'ÉLAN : la physique publiée, pas un défaut

Banc de coast pur — la planche est **lâchée** au pied à une vitesse
d'entrée connue, sans cible, et on lit le sommet atteint.

| entrée | rampe 2,10 | rampe 1,45 | v²/2g |
|---|---|---|---|
| 6,00 u/s | 0,448 | 0,467 | 0,692 |
| 8,00 | 0,841 | 0,903 | 1,231 |
| 8,97 | 1,063 | 1,113 | 1,547 |
| **10,00 (croisière)** | **1,368** | **1,382** | 1,923 |
| 12,00 | 1,944 | **1,990 → PASSE** | 2,769 |

**CH61 publiait 1,348 sur la rampe de 2,10. Ce banc rend 1,368 à la
croisière** — 1,5 % d'écart — et `SkatePhysicsProbe`, la sonde permanente
existante, réimprime **1,348** au chiffre près sur l'arbre courant
(PHASE R, `core 53 ticks (y 0.052 .. 1.348)`). Le banc restitue le chiffre
au dossier avant d'en publier un neuf.

**Donc : à la croisière, la planche atteint 1,37 u sur une rampe de 2,10 u
— 65 % de la hauteur. Elle ne peut pas la passer, et c'est mesuré, voulu
et documenté depuis CH61.** « Je monte, je ne passe pas à travers, je
n'ai pas assez d'élan » est une description exacte de ce que le jeu fait.

⚠️ **Et il y a un levier, qui est le PLACEMENT DU TAP.** Un tap posé
**au-delà** de la rampe garde `remaining` grand, donc le modèle POUSSE
pendant toute la montée : les deux rampes sont alors **passées** (sommets
2,188 et 1,957). Un tap posé **au pied** met la planche en course de
sortie et elle arrive en roue libre : elle cale. La même rampe répond
différemment selon où le doigt se pose, et rien à l'écran ne le dit.

## Le contact n'est pas un défaut de tenue

PHASE H classe chaque tick contre la **surface DESSINÉE** sous la planche
(lue sur `quarterpipe_profile`, la courbe dont le collider est bâti) :
**0 % des ticks passés SUR la rampe sont non tenus, pénétration maximale
0,0000 u**.

⚠️ **La première version de cette phase rapportait 53,7 % de ticks « non
tenus » et c'était un artefact de la phase, pas du jeu** : elle comptait
ensemble « posé sur la rampe sans être tenu » et « en vol au-dessus du
lip », qui est le comportement normal du module — le pire lift mesuré
valait 2,2092 u sur une rampe de 2,10. **CH43 exactement : un test sur une
grandeur observable ne voit pas quelle branche a tourné.**

**Observation, non corrigée** : à l'ARRÊT sur la rampe, `on_module()` est
faux et `airborne()` est donc vrai (`is_on_floor()` décrit le
`move_and_slide` déjà fait, et un corps à vitesse nulle n'est entré dans
rien). `SkateAudio` le lit, mais son cue d'atterrissage exige une chute de
1,60 u/s qu'une planche à l'arrêt n'a pas. Signalé, pas touché.

## VERDICT SUR LA CHUTE DE FPS : c'est la STATION, pas le lot

Sous `xvfb + opengl3`, compteurs moteur, deux lectures par station et une
lecture jetée d'abord :

| station | primitives | draw calls | tremor |
|---|---|---|---|
| **spawn (0 ; 0)** | **70 923** | 301 | **0** |
| entrée du park (0 ; 43) | 93 118 | 378 | 0 |
| **LA STATION (−1,9 ; 51,3)** | **93 780** | **393** | **0** |
| bord nord (0 ; 63) | 93 253 | 412 | 0 |

**70 923 au spawn : le chiffre de CH62 au primitive près, et le 70 946 de
CH52.** Le banc restitue.

**La station porte +22 857 primitives sur le spawn, soit +32,2 %.** À la
pente marginale que CH52 a mesurée sur device (**≥ 0,199 ms par 1 000
primitives**, une borne INFÉRIEURE), cela vaut **≥ 4,55 ms** — sur une
frame de spawn à 16,67 ms, ~21,2 ms, soit **~47 FPS**. CH52 avait mesuré
**46 FPS au bord nord sur device, avant que le skatepark existe**, et
avait écrit noir sur blanc que *« le budget net disponible pour cinq
modules de skatepark est de ZÉRO »*. Cinq modules y ont ensuite été bâtis.

⚠️ **Les 55-56 FPS n'ont jamais été un chiffre du lobe nord.** Ils ont été
lus là où l'overlay se lit d'habitude — le spawn et le plateau. Comparer
39 au bord nord avec 55 au spawn, c'est comparer deux stations, pas deux
versions.

### Ce que le lot CH62 coûte À CETTE STATION : rien de mesurable

Caméra de ride ouverte **en grand** (contrôle : fov **45,00 → 49,58**,
distance à Keepy **11,7034 → 13,7435 u**, rush 1,000 — les trois vérifiés,
sinon la phase mesurerait un objectif qui n'a pas bougé) :

| | delta |
|---|---|
| primitives totales moteur | **+5** |
| draw calls | **−3** |
| triangles au cadre (replay frustum) | **−17** |

⚠️ **Le +8 165 primitives de CH62 ne se transporte pas ici.** Un terme de
frustum est fonction de **où l'objectif pointe** : au lobe nord, élargir
le champ n'admet rien de neuf. Le chiffre de CH62 était juste **à sa
station** ; c'est une propriété du poste, pas du lot.

⚠️ **Et le même relevé en headless est FAUX** : il donnait +2 610
triangles / +14 nœuds, parce que le viewport du driver dummy est 0×0 et
que le test de frustum n'y veut rien dire (`CLAUDE.md` le documente déjà
pour `unproject_position`). Seul le relevé xvfb compte.

### Fuite : aucune

Huit cycles montée/ride/descente complets : **0 nœud** ajouté sous le hub
(1085 → 1085), **0** sur `OBJECT_COUNT` (3999 → 3999). Blind check vert
(le recensement voit un nœud ajouté puis retiré). À la source,
`SkateStreaks._build_lanes` et les deux `AudioStreamPlayer` sont
construits une fois depuis `_ready()`.

### Coût physique du contact : sous le plancher de ce banc

Trois runs, plancher de bruit publié à chaque fois :

| run | plancher | signal (station − pelouse) | verdict |
|---|---|---|---|
| 1 | 0,0473 | +0,0556 | +0,0083 au-dessus |
| 2 | 0,1022 | +0,1416 | +0,0394 au-dessus |
| 3 | 0,0820 | +0,0456 | **sous le plancher** |

**Ce banc ne sépare pas le contact de son propre tremblement, et c'est le
résultat** — au plus ~0,14 ms/tick ici. Le `physMAX 3,60 ms` du device
n'est pas expliqué par ce banc ; ce qu'on peut en dire est que le contact
avec un collider est un coût RÉEL que CH60 n'avait jamais mesuré (son banc
priçait des corps statiques que **rien ne touchait**, +0,00049 ms/tick
pour 27 pièces — la résolution de contact est une autre facture).

## CE QU'IL Y A À CORRIGER : rien

* le bol n'a pas de collider, sur les deux lectures et depuis CH60 ;
* ce qui est solide sous lui est le grand quarterpipe, solide **par
  conception** depuis CH60, avec ses 12 pièces exactes ;
* l'élan qui manque est la physique publiée par CH61, restituée à 1,5 % ;
* la tenue est bonne : 0 % de ticks non tenus, 0 pénétration ;
* aucune fuite ;
* le FPS est une lecture de STATION dans un lobe que CH52 avait déjà
  déclaré à budget nul.

`SkatePhysicsProbe`, la sonde permanente, sort **ALL GREEN — 0 red** sur
l'arbre courant : CH62 n'a rien régressé. Le diff le dit aussi —
`SkateBoardBody` ne gagne que **deux accesseurs en lecture seule**
(`lift()`, `airborne()`), et rien du modèle de conduite, des colliders ou
de la région ne bouge.

⚠️ **`SkateStationDiagProbe` est une sonde JETABLE** (`CLAUDE.md` : une
sonde de mesure ponctuelle n'entre pas dans le dépôt, `ProbeTimeoutAudit`
doit revenir exactement à son chiffre de baseline). Elle est commitée
**sur cette branche seulement**, qui n'est pas destinée au merge. **Si
quoi que ce soit d'ici part un jour vers `staging`, elle est supprimée
d'abord.**

## Doctrine que ce lot ajoute

Deux règles neuves sont remontées dans `CLAUDE.md` : un balayage borné par
une emprise mesure aussi ses voisins, et un relevé de frame se compare à
la MÊME station avant de se comparer à la même version.
