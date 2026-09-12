# CH77 — Le terrain des zones 1 et 2 devient navigable hors-chemin

> 12 septembre 2026. Périmètre STRICT zones 1 (le Vallon d'automne) et
> 2 (la Lande aux Moulins). La montagne (CH39) n'est pas touchée.

## 1. La recon, bloquante, et ce qu'elle a tué

Le brief demandait de classer chaque blocage dans une catégorie et de
donner ses coordonnées. **Quatre des cinq catégories sont sorties vides**,
mesurées sur l'arbre livré (`ac30ae7`) sous `xvfb` + `opengl3`, contrôle
d'instrument vert (rect 540×960 réel, 4 008/4 908 transforms de `MultiMesh`
non-identité — les 900 en identité sont le batch `Precipitation`, la pluie,
à l'identité tant que la météo ne la pilote pas).

| catégorie | verdict mesuré |
|---|---|
| (a) collision / mur invisible | **ZÉRO**. Les 10 `CollisionObject3D` du monde construit sont tous en zone 0 (3 `Area3D` de portail, `Skateboard`, `Funbox`, `Rail`, 2 `Quarterpipe`, `Bowl`, `Funfair`). |
| (b) absence de sol sous le visuel | **ZÉRO**. Aucun domaine `HubSurface` n'est enregistré en jeu (seules les sondes appellent `register_domain`), donc le sol est plat à y = 0 partout, sur **un** `PlaneMesh` de 600 × 600. |
| (c) footprint trop large | **ZÉRO effet**. `HubBuilder.ground_footprints()` rend **0 entrée sur 206** en zones 1/2, et `KeepyHopper._advance()` ne lit **aucun** footprint — seul `leave_ride()` le fait. |
| (d) clamp / borne de zone | **LA CAUSE, ET LA SEULE.** |
| (e) pas de blocage | **VRAI À L'INTÉRIEUR** des rectangles. |

### Le mécanisme, en une phrase

`assets/shaders/cozy_ground.gdshader` bande les teintes d'automne et de
lande sur **`world_pos.z` SEUL** — il n'y a aucun terme en `x` dans l'une
ni dans l'autre — et le sol est un plan unique de 600 × 600. Le sol
**peint** court donc jusqu'à l'horizon pendant que le sol **marchable**
s'arrête à un rectangle.

Balayé au demi-mètre sur x ∈ [−60, 60] :

| bande peinte | marchable | REFUSÉ |
|---|---|---|
| zone 1, z[−78,−42] | 2 403,0 u² | **1 995,2 u² (45,4 %)** |
| zone 2, z[−126,−86] | 3 721,8 u² | **1 158,5 u² (23,7 %)** |
| goulot 0↔1, z[−42,−35] | 136,8 u² | **767,0 u² (84,9 %)** — franchissable sur **10 u de 120 peints** |
| goulot 1↔2, z[−86,−78] | 165,2 u² | **859,0 u² (83,9 %)** — franchissable sur **12 u de 120 peints** |

### La teinte violette de la capture device — tranchée, mesurée

Le point (27,4 ; −89,4) que Mathieu a photographié :
`contains` **true**, zone 2, `in_hole` false, `in_sea` false,
`HubWater.body_at` **vide**, hauteur 0,00000, hors de tout
`LAVENDER_FIELDS`. Le pixel (moyenne 7×7, soleil épinglé) vaut
**(0,7826 ; 0,7749 ; 0,5954)** :

| candidat | distance |
|---|---|
| `CozyPalette.MOOR_C` | **0,0405** |
| `CozyPalette.MOOR_A` | 0,2830 |
| `HubWater.hue` (turquoise) | 0,4488 |
| `CozyPalette.SEA_BED` | 0,5995 |

**C'est une teinte de SOL** — la bande bruyère, le point étant 7,4 u
au-delà de `MOOR_EDGE_Z`. Ni eau fonctionnelle, ni flaque, et **elle ne
bloque pas** : ce point était déjà marchable avant ce lot. Rien à corriger
là ; la question posée par le brief est fermée par la mesure et non par une
supposition.

## 2. L'arbitrage, et les trois bords épinglés

La cause étant la catégorie (d), le lot s'est **arrêté** et a demandé
arbitrage comme le brief l'impose. Réponse de Mathieu : **élargir la
région ET le semis, 10 u par côté**.

Six côtés le prennent. **Trois sont ÉPINGLÉS**, parce que +10 y
annexerait la bande d'une zone voisine et que le périmètre de ce lot est
« zones 1 et 2 » :

| bord | épinglé à | ce que +10 aurait annexé |
|---|---|---|
| `AUTUMN_MAX.y` | −42 | le carré zone 0 (\|z\| ≤ 35) |
| `MOOR_MIN.y` | −126 | `CIRCUIT_MAX.y` (−134), zone 3 |
| `MOOR_MAX.x` | 38 | `COVE_CORRIDOR` (x[38,44]) et `COVE_MIN.x` (44), zone 4 |

Le goulot 0↔1 est compensé **sans toucher un nombre que le carré possède** :
`CORRIDOR_*` est une constante de **zone 1** (`in_autumn()` la possède), et
l'élargir de 10 u par côté porte la traversée de **10 u à 30 u**.

Livré :

```
AUTUMN_MIN   (-33,-78) -> (-43,-88)      AUTUMN_MAX   ( 33,-42) -> ( 43,-42)
CORRIDOR_MIN (-33,-42) -> (-43,-42)      CORRIDOR_MAX (-23,-33) -> (-13,-33)
MOOR_MIN     (-38,-126)-> (-48,-126)     MOOR_MAX     ( 38,-86) -> ( 38,-76)
```

zone 1 : 66 × 36 → **86 × 46** (2 376 → 3 956 u²)
zone 2 : 76 × 40 → **86 × 50** (3 040 → 4 300 u²)

⚠️ **Le goulot 1↔2 disparaît EXPRÈS** : `AUTUMN` atteint z = −88 et `MOOR`
z = −76, donc les deux rectangles **se recouvrent** sur z[−88,−76] à
travers x[−43,38]. `MOOR_CORRIDOR` devient **inerte** — entièrement
contenu par `AUTUMN` — et il est gardé pour la raison exacte pour laquelle
le dépôt garde le shore pad et le lobe r=12 : un terme mesuré de l'union
qui ne coûte rien tant qu'il est contenu, et dont la suppression
déplacerait le flux RNG de tout ce qui suit (CH53).

## 3. LE VRAI BLOCAGE N'ÉTAIT PAS QUE DANS LA RÉGION

Trouvaille du lot, et elle vaut la doctrine qu'elle a produite dans
`CLAUDE.md`. La région a cessé de refuser la traversée zone 1 ↔ zone 2 —
et **le routeur a continué**. `HubWorld._hop_via_corridor` forçait
`MOOR_GATE` dès que l'index de zone changeait, quelle que soit la forme.

Mesuré par le **vrai canal du doigt**, marche (−30,−74) → (−30,−92),
18 u droit devant :

| | approche la plus proche de `MOOR_GATE` | excursion latérale | frames |
|---|---|---|---|
| routeur inchangé | **0,000 u** | **42,000 u** | 985 |
| routeur relâché | 42,000 u | **0,000 u** | **204** |

**42 u de côté pour un point à 18 u devant**, et rien ne le signalait : la
marche arrivait bel et bien, à 0,002 u de la cible, donc toute assertion de
point d'arrivée passait.

Le correctif est une **condition de suffisance**, jamais une exception
nommée : `_line_is_walkable(here, target)` échantillonne le segment au pas
`KeepyHopper.HOP_DISTANCE` (1,5 u, soit moins du tiers du plus petit trou
de la région) et exige `contains()` partout. La porte est donc prise
**exactement comme avant** partout où la ligne n'est pas libre — les
goulots 0↔1, 2↔3 et 2↔4 gardent la leur sans qu'on ait eu à les nommer.
C'est une **relaxation** : elle ne peut casser aucun trajet.

## 4. Le semis

`_autumn_sprinkle` dérivait déjà ses comptes de l'aire — ils suivent tout
seuls. Le moor non : `for i in 40` (olives, cap 7) et `for i in 60`
(rochers) étaient écrits contre le rectangle de 76 × 40, et un compte fixe
sur une boîte 41 % plus grande n'est pas le même semis dilué, c'est une
autre densité. Trois densités neuves, **calibrées sur les nombres livrés** :
à l'ancienne aire elles rendent `int(40,128) = 40`, `int(7,296) = 7` et
`int(60,19) = 60`, soit les comptes expédiés à l'entier près, aucune sur
un fil de rasoir. Idem pour les carrés de citrouilles
(`PUMPKIN_PER_U2`, `int(5,049) = 5` à l'ancienne aire), dont la boîte de
tirage était deux littéraux contre l'ancien rectangle.

Comptes mesurés, référence → branche :

```
autumn_tree  22 ->  48    fern    123 -> 222    leafpile 46 -> 79
palerock     32 ->  50    olive     7 ->  10    pumpkin  32 -> 24
hedge2       35 ->   0    hedge    27 ->  21    hedge3   44 -> 41
wall_far    182 -> 150    wall_near 277 -> 270  instances 2566 -> 2686
```

⚠️ **`hedge2` tombe à ZÉRO, et c'est la conséquence assumée** de la
dissolution du goulot : cette passe plante là où `contains()` est FAUX. Le
shader tourne toujours la litière de feuilles en bruyère à `MOOR_EDGE_Z`
sur 3 u de fondu, donc la transition est toujours **dessinée** — elle l'est
maintenant sur du sol marchable au lieu de derrière une haie.

⚠️ **Et le tapis de ZONE 0 bouge**, ce qui est le témoin hors-sujet que
CH53 exige de regarder : `COVER` couvre z ∈ [−37, 71] et le couloir de
zone 1 élargi mord dedans à x[−43,−13], donc `_sprinkle` accepte des
candidats qu'il rejetait (grass +25, bush −6, rock +2, pebble +1,
mushroom +1, leaf +5). Rebattage, pas régression — et il est nommé ici
plutôt que découvert plus tard.

## 5. Le budget — il DESCEND

Mesuré par la même sonde, mêmes stations, même ordre, météo épinglée au
soleil, sur les deux arbres :

| station | référence | branche | Δ |
|---|---|---|---|
| spawn (0, 0) | 70 790 | 71 193 | **+403** |
| lobe skate (0, 30) | 78 286 | 73 895 | **−4 391** |
| bouche du couloir (−25, −30) | 49 382 | 49 794 | **+412** |
| zone 1 (0, −60) | 84 968 | 83 545 | **−1 423** |
| zone 2 (0, −105) | 59 262 | 57 406 | **−1 856** |

Le décor semé ajoute pourtant **+10 955 triangles** en zone (zone 1
26 131 → 28 584, zone 2 28 568 → 37 070). Ce qui l'emporte est que le mur
forestier est planté là où `contains()` est FAUX : il a été **poussé vers
l'extérieur** (`wall_far` 182 → 150) et `visibility_range_end` en culle
davantage. **Aucune aggravation du budget device** n'est donc à signaler
aux stations mesurées ; les deux hausses sont de l'ordre du tremblement que
`CLAUDE.md` documente pour ce hub.

⚠️ **Un compteur de frame se publie comme un ordre de grandeur** (CH62) :
ces chiffres sont un A/B honnête (même sonde, mêmes stations, même ordre),
pas des valeurs à l'unité.

## 6. `ZoneNavProbe` — permanente, et ses deux passes rouges

`xvfb` + `opengl3`, **jamais headless** (CH50 : une lecture headless rend
2 743/2 743 transforms en identité et laisse une assertion d'absence passer
en vert). **40 assertions, 0 rouge.**

Tout entre par `HubTapInput._handle_point` depuis une **vraie coordonnée
écran** (CH58 : une sonde qui conduit un prop par son API mesure la
fonction, pas l'interaction). Le POSITIF tourne **avant** les refus, sinon
« ça refuse » passe gratuitement contre un canal jamais câblé.

Deux neutralisations, chacune **prédite avant d'être lancée**, fichiers
restaurés **byte-identiques** (`cmp`) :

| passe | prédit | obtenu |
|---|---|---|
| routage seul neutralisé | 2 | **2**, et les deux bonnes (approche de la porte, excursion latérale) |
| région seule neutralisée | 10 | **10**, et les dix prédites (6 en PHASE W, 2 en PHASE N, 2 en PHASE R) |

La seconde dit aussi **à qui revient le mérite** (CH65) : avec la région
neutralisée mais le routeur relâché, PHASE N reste rouge — donc les deux
correctifs sont **nécessaires tous les deux** et aucun ne porte le crédit
de l'autre.

### Deux défauts d'INSTRUMENT attrapés, chacun avec l'allure d'un résultat

1. ⚠️ **La caméra lerpe.** Six frames après un téléport elle est encore à
   61 % de la station précédente, donc chaque `unproject` passait par une
   caméra qui n'était pas là où la sonde la croyait, le tap tombait hors du
   rect de `_handle_point` et était **jeté** — « 0 stage accepté, il n'a
   pas bougé », c'est-à-dire exactement la signature d'un sol refusé. Trois
   lignes de PHASE W ont rapporté du sol neuf comme inatteignable. La sonde
   **gate désormais l'arrivée de la caméra**, pas un compte de frames.
2. ⚠️ **Une cible purement latérale n'est pas tapable.** Le cadre fait
   ±3,69 u à la hauteur de Keepy et la caméra ne tourne pas : on n'atteint
   un sol de côté qu'en visant **en avant-et-en-travers**, en plusieurs
   taps. Les trajets de PHASE W sont réécrits comme un joueur les fait, et
   `_walk_toward` bissecte le point le plus loin qui soit encore tapable.

Un troisième échantillon était faux : le test « le bord est de la lande
refuse » tapait (42 ; −100), qui est **dans `COVE_CORRIDOR`** — il aurait
testé le couloir de la Crique en l'appelant l'épingle de la lande.

## 7. Ce qui reste ouvert, et n'a pas été corrigé

⚠️ **`MinimapProbe:227` est ROUGE, et il l'était AVANT ce lot.** Il gate un
littéral `137 × 263` ; l'arbre rend `137 × 271`. Le 263 est
`−200 .. +63`, c'est-à-dire `PLATEAU_HALF_EXTENT + 28` — **l'ancien rayon
du lobe skate**. CH67 l'a porté à 36 (span 271) sans relire ce littéral.
C'est le motif CH70 exactement : une seconde orthographe d'une valeur
dérivée, rouge depuis un lot que personne n'a rejoué sur cette sonde. Hors
périmètre (zone 0), **signalé et non corrigé** ; le correctif est de dériver
la borne de `walkable_bounds()` au lieu de la retaper.

`SeesawProbe` sort **2 échecs**, en parité exacte sur les deux arbres —
les deux pré-existants que `CLAUDE.md` documente depuis CH69.
