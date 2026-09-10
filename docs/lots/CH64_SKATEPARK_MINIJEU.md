# CH64 — le skatepark devient un mini-jeu à part entière

*10 septembre 2026. Branche `claude/keepy-skatepark-minigame-dbwyly`, basée
sur `origin/staging` (`33b705c`, CH63 LOT 2 mergé). Garde de concurrence par
ARBRE : la branche `claude/skatepark-trick-minijeu-xyuy9a` au nom voisin est
la recon CH51, déjà ancêtre de `staging` ; aucun doublon.*

> Trois chantiers et un socle, dans l'ordre du brief : **0.a** les deux
> toggles dev disparaissent et la physique devient permanente ; **0.b** la
> caméra de poursuite de la planche est calmée ; **1** les tricks au cercle
> en l'air ; **2** la direction artistique béton du park. Ce que les sondes
> signent est l'ARITHMÉTIQUE de chacun ; le ressenti, le confort de caméra
> et le FPS device restent à Mathieu, et c'est écrit à chaque section.

## Section 0.a — les toggles n'existent plus, et la physique est le jeu

**« Physique (dev) »** (CH59) et **« Contrôle skate : TAP / DRAG »** (CH63)
existaient pour un A/B sur device. L'A/B a été fait : le doigt maintenu a
gagné, la physique est validée. Les deux boutons, leurs deux nœuds de
`HubWorld.tscn`, `DevTools.physics_enabled()` / `set_physics_override()` /
le jeton `keepyphys`, et le static `SkateTouchInput._drag_mode` sont
**supprimés** — pas mis à `true`, supprimés : un interrupteur qui ne dit
plus que oui est un interrupteur sur lequel un lot ultérieur trébuche.

Ce qui en découle, chacun mesuré :

* **La planche est un `CharacterBody3D` pour tout joueur**, montée par la
  porte CARRIER (`mount_board`), et **le chemin `mount_vehicle` glissant de
  CH54 est retiré** de `HubWorld._try_mount_ball`. `KeepyHopper` n'est pas
  touché (ses dix états et dix-huit sondes ne savent rien de la planche).
* **Le schéma TAP est retiré de bout en bout** : l'adaptateur de
  destination de `HubTransport` (`set_board_target`, `board_has_destination`,
  run-out, garde d'immobilisation, `BOARD_ARRIVE`, `BOARD_STALL_*`), la
  branche planche de `HubWorld._on_tapped_ground`, la route « planche →
  `tapped_ground` » de `HubTapInput._handle_point`. Le court-circuit de
  `HubTapInput._unhandled_input` se décide sur **`is_riding_board()` seul**.
  `_handle_point` et `_on_tapped_ground` sont intacts pour les dix autres
  états.
* **Les colliders du park sont inconditionnels** (`HubSkatepark._maybe_collide`
  sans garde). L'overlay perf perd son marqueur `PHYS ON/off`.

### Ce que coûte une physique permanente quand personne ne roule — MESURÉ

Le brief avertit : physMAX 26,80 ms sous la pluie sur device, lobe nord à
budget nul depuis CH52. `SkatePhysicsProbe` PHASE I (neuve) lit le tick
physique **au spawn, à pied, 46 u du park**, corps présents puis retirés de
l'espace (`PhysicsServer3D.body_set_space(…, RID())`, réversible, aucun nœud
libéré), contre le plancher de bruit du banc (deux lectures d'une même
configuration), puis le POSITIF : la planche montée et poussée doit coûter
quelque chose que l'instrument voit.

Résultat (headless, `--fixed-fps 60`, ce sandbox) : trois runs, le delta au
repos oscille de −0,05 à +0,06 ms/tick autour d'un plancher de 0,03 à
0,05 — **sous le bruit du banc**, pendant que la planche MONTÉE coûte
+0,18 à +0,21 (bloc en section 5). Verdict de conception : **pas
d'armement par zone** — le corps ne fait `move_and_slide` que monté, les
quatre corps statiques ne demandent rien au broadphase (CH56 : ≤ 0,0014
ms/tick), et le delta au repos est sous le plancher du banc. Le physMAX de
26,8 ms sous la pluie n'est **pas** un coût du park : les mêmes cinq corps
existent par temps clair à 1,00 ms. C'est un proxy ; le FPS device est à
Mathieu.

## Section 0.b — la caméra de poursuite, calmée

Retour device : « donne mal à la tête et au ventre », « trop dynamique »,
« plus lente, moins liée aux mouvements ». Cause nommée par CH63 §9 : le cap
de la planche est écrit **sans taux** depuis le pouce, et la caméra le
suivait au `DRIVE_HEADING_LAMBDA` du kart (3,6).

**`HubCamera.ChaseTuning`** : une tuning PAR VÉHICULE. `vehicle()` EST les
constantes du kart et prend le chemin `lerp_angle` byte-identique (gaté par
ChaseAudit CALM) ; `board()` porte quatre boutons et une règle :

| bouton | kart | planche | pourquoi |
|---|---|---|---|
| `heading_lambda` | 3,6 | **1,8** | constante de temps doublée (0,56 s) |
| `yaw_rate_max` | ∞ | **110 °/s** | juste AU-DESSUS du carve mesuré à ~106 °/s par CH63 : le régime établi n'est pas ralenti, c'est le TRANSITOIRE qui est borné |
| `deadzone` | 0 | **3°** | seuil DOUX (l'erreur est raccourcie, jamais gatée) : un pouce qui tremble ne fait pas tourner le cadre |
| `fov` | 60 | **56** | moins de décor en mouvement au bord de l'image |
| `keep_inside` | — | **2,5 u** | la pose reste DANS la région (voir ci-dessous) |

⚠️ **LE CAP SUR L'ORBITE NE BORNAIT PAS LE LACET.** Première version : cap
sur `_drive_heading` seul. `SkateInputProbe` PHASE T a mesuré **170 °/s** la
première seconde d'un doigt tenu plein travers. La pose est un `look_at`,
et un look_at lace avec la POSITION de la planche quoi que fasse l'orbite.
Le cap est donc appliqué **sur la pose finie**, image par image (le lacet du
transform est comparé au précédent et ramené au cap par rotation autour de
Y ; tangage et position intacts). PHASE T après : `170,7 / 103,0 / 110,0 /
108,8 / 109,3 / 110,0 °/s` — la première fenêtre contient le SNAP de 90° de
la planche elle-même (contrôle validé, non touché), le régime est au cap.

⚠️ **LA POSE SORTAIT DE LA RÉGION, DANS LES ARBRES DU BORD.** Capture : une
planche au bord nord du park face au sud met une caméra 7,6 u derrière,
c'est-à-dire HORS du lobe, dans les arbres-murs que `CozyScatter` plante
le long du bord — plein cadre de feuillage. Le circuit du kart ne frôle
jamais un mur ; le park est bordé par un sur trois côtés. `keep_inside` :
la pose est clampée à `HubRegion` et tirée de 2,5 u vers la planche —
**jamais plus près qu'un demi-unité derrière elle** (une pose SUR la
planche est un look_at dégénéré). Et comme une pose tirée près qui vise
5,5 u PLUS LOIN que la planche la perd sous le bord bas du cadre (mesuré :
**0 pixel** de planche au bord nord, deux fois), la visée converge vers la
planche avec la distance tenue (`ahead = 5,5 × clamp(held / 7,6, 0, 1)`).
Après : 9 px de planche au bord nord (0,5 u derrière, pose dans la
région), 42 px au bord est.

**`ChaseAudit` PHASE CALM** (neuve) : planche réelle, pilotée par le vrai
writer (`SkateBench`), tuning planche. 120 frames en ligne à la croisière,
240 en carve plein braquage, 120 de relâchement, puis trois bords du park
avec la planche peinte magenta et ses pixels EXIGÉS :

```
straight frames 120  in band 120  orbit rate max   0.0  camera yaw max   0.0  top 9.92
carve    frames 240  in band 240  orbit rate max 110.0  camera yaw max 110.0  mean 105.5
settle   frames 120  in band 120  error 70.2 -> 4.9 deg, 0 sign changes, 0 growths
```

Ce que l'audit ne signe pas : le confort. Si c'est encore trop vif, les
quatre nombres sont dans `HubCamera.gd` (`BOARD_*`), et un changement est
un commit — jamais un toggle.

## Section 1 — les tricks

Geste de Mathieu, à la lettre : doigt maintenu, **cercle EN L'AIR = trick**,
même cercle AU SOL = direction, deux sens = deux tricks, cercles enchaînés =
trick répété. Deux figures : **kickflip** (horaire sur l'écran) et
**heelflip** (antihoraire).

### (a) La frontière air/sol — `SkateBoardBody.in_air()`

`airborne()` (CH62) est `_supported and not _on_module` : juste pour un son
et une ombre, faux pour armer un geste — `is_on_floor()` décrit le pas
DÉJÀ fait, et une planche à l'arrêt sur le deck lit un tick de « pas sur le
sol ». Mesuré par `SkateTrickProbe` PHASE A : **`airborne()` dit oui sur 2
ticks de 60** sur une planche parfaitement immobile sur le deck de la
funbox. `in_air()` est cette lecture avec un **dwell** : `AIR_ARM_TICKS = 6`
ticks consécutifs sans appui, et retombe au PREMIER tick tenu. Mesuré :

* deck, 60 ticks : `in_air` jamais vrai (pic 2 ticks) ;
* pop à 1,0 u/s : 5 ticks en l'air, sous le dwell, **n'arme pas** ;
* pop à 4,0 u/s : 14 ticks, `took_off` 1, `landed` 1 ;
* lancement réel sur le grand quarterpipe : pic y 2,192 u, 26 ticks armés,
  deux décollages et deux atterrissages (un rebond sur la transition).

Les deux fronts sont des SIGNAUX (`took_off`, `landed`) branchés au writer
**sur le tick où ils se produisent**, dans `drive()` — pas au tick de
contrôle suivant, qui aurait laissé passer un tick de l'ancien offset comme
cap à l'atterrissage (mesuré : l'ancre relue inchangée au tick du contact).

### (b) La reconnaissance — le NOMBRE DE TOURS, pas la forme

Un cercle au pouce n'est ni rond, ni centré, ni fermé. Ce que toute boucle
a, c'est un **nombre de tours** : la somme des angles signés que la
direction de déplacement parcourt vaut ±360° quelle que soit la forme. Le
writer garde une polyligne (un point retenu tous les `TRICK_SEG_PX = 8`
px — un pouce qui tremble n'écrit aucun segment) et somme
`Vector2.angle_to` entre segments consécutifs. Trick à
**`TRICK_SWEEP_DEG = 300`**, puis **360 soustraits** (pas de remise à
zéro) : une seconde boucle enchaînée retire au même point de son propre
cercle. Argument du seuil : 270 est un crochet (un virage serré en montant
une rampe en trace un), 360 attend une fermeture que le pouce ne fait
pas ; 300 est dans la marge, côté joueur. **Le sens** : y écran vers le
bas, `angle_to` positif = horaire pour un spectateur — asserté sur un
cercle construit (neuf heures → haut → droite), jamais lu dans un commentaire.

`SkateTrickProbe` PHASE G : horaire → 1 kickflip ; antihoraire → 1
heelflip ; 3 boucles → 3 ; cercle bosselé ±4 px → 1 ; petit cercle bosselé
r 40 → 1 ; trait droit 300 px → 0 ; zigzag → 0 ; demi-cercle → 0 ;
**crochet 270° → 0 ; boucle 315° → 1** ; tremblement r 4 px sur trois tours
→ 0 ; **le même cercle au sol → 0 et un cap écrit**. Et l'inverse publié
`screen_offset_for` est l'exact inverse de `heading_world` (cos > 0,9999
sur huit caps).

### La coupure à l'atterrissage

En air ARMÉ, `HubTransport._advance_board` n'écrit **pas** le cap (la
face est gelée : un cercle ferait tourner la planche en vol). À
l'atterrissage, si le doigt a voyagé, **l'ancre est déplacée sous le doigt**
(`rebase()`) : offset nul, tout droit, pas de virage au contact. Un saut
trop court pour armer garde son ancre — un carve tenu par-dessus une bosse
n'est pas annulé. PHASE L : après une boucle et quart en l'air (doigt à
85 px de son ancre, à midi), face gelée à 1e-4 près, ancre sous le doigt au
contact, cap inchangé douze ticks plus tard, doigt toujours propulseur ;
NÉGATIF : un saut à 1,0 u/s (non armé) avec doigt de côté braque.

### La restitution — le deck TOURNE, le cavalier non

`SkateBoardBody.flip()` : `_flip_target ± TAU` par trick, `_flip_angle`
intégré à `FLIP_RATE = TAU / 0,33 s`, **×3 dès l'atterrissage** (un deck
laissé de travers lit comme cassé). Le roulis est écrit sur le
`SkateboardMesh` enfant, jamais sur le corps : le siège du cavalier ne
bouge pas (PHASE F : dérive 0,0000 u ; un tour exact −TAU au sol en 7
ticks ; deux heelflips en file en un air de 0,7 s = +2 TAU, deck droit à
la fin). HUD : `SkateHud.flash_trick()` imprime KICKFLIP / HEELFLIP.
Son : deux pops générés (22 050 Hz mono, 0,18 s, corps qui descend de 880
ou 1 240 Hz), `SkateAudio.play_trick()`. PHASE H : par la vraie route
writer → transport → HUD et haut-parleur, deux noms, deux streams, deux
comptes.

Scoring : hors scope, aucun point. Dette CH57 (ON_CARRIER n'émet pas
`hop_landed`) intacte.

## Section 2 — la DA béton

Réalisme façon True Skate, assumé contre le hub cartoon. Sans lumière et
sans post-traitement (CLAUDE.md), le réalisme est **cuit dans les
sommets** (bake-once) : `SkateparkMesh._shade()` assombrit vers
`CONCRETE_FOOT` selon un dial dérivé de la géométrie — pied de transition
(0,72 → 1,0 à la lèvre), bas des flancs, fond du bol, pied des rampes de
la funbox. Puis :

* **`skate_concrete.gdshader`** : le shader décor moins les bandes toon
  (diffus lisse : une transition lit comme une courbe), plus un GRAIN à
  deux prélèvements de LA texture de bruit que le sol et l'eau partagent
  déjà (projection par axe dominant de la normale), plus `wet` (la pluie
  fonce le béton comme la pelouse). Haze, tint météo, neige conservés.
  Enumération météo : `CozyPalette.apply_weather` le sert explicitement.
* **Coping acier** : tube hexagonal r 0,065 le long des lèvres des deux
  quarterpipes (bouchons aux extrémités) et anneau de 24 tubes sur la lèvre
  du bol ; **cornières acier** sur les deux arêtes du deck de la funbox.
* **Dalle** : plaque 20 × 18 u à 8 mm au-dessus de la pelouse (sous les
  14 mm de l'ombre, au-dessus de la précision du z-buffer), kerb sombre,
  ligne centrale et deux bandes de peinture jaune. Aucun collider (D1 :
  `HubSurface` reste le sol). Un disque d'emprise r 13,5 dans
  `HubSkatepark.footprints()` pour qu'aucune touffe ne perce le béton.

⚠️ **LE DÉCOR VA DANS UNE SECONDE SURFACE, ET LA RAISON EST D5.**
`SkatePhysicsProbe` PHASE G gate que l'union des pièces convexes EST
l'ensemble des sommets dessinés. Un tube ajouté à la surface 0 l'a
rougi — **correctement** : le dessiné divergeait du solide. Coping et
cornières sont donc la surface 1 du même `ArrayMesh` (même matériau) :
la surface 0 reste le béton solide, le gate est intact, et le prix est
un draw call de plus sur quatre modules.

Budget : 468 tri de modules avant ; après, béton + décor + dalle — voir
`SkateparkProbe` G1/G3/G4 dans la table (plafond CH52 : 6 000). Le pire
azimut de la station skatepark de `ChaseAudit` (85 289 prims avant) :
voir la table. **Le FPS device n'est pas signé ici** : llvmpipe prouve la
géométrie et le cadrage, pas Safari.

Vu sur capture (sept prises, caméra fixe et poursuite, soleil et pluie,
sous xvfb) : le grain, le kerb, la peinture, l'anneau du bol et les
dégradés lisent ; la dalle a été assombrie (0,68 → 0,60) pour que les
modules s'en détachent au ton.

## Section 3 — les sondes, retirées de l'adaptateur et remises sur le doigt

`set_board_target()` n'existe plus, et un `hold()` direct serait écrasé au
tick suivant par `_advance_board`. **`SkateBench`** (dev) tient un doigt
sur le vrai writer : une destination devient, à chaque tick, l'offset
écran qu'un pouce devrait tenir sous la caméra VIVANTE
(`SkateTouchInput.screen_offset_for`, l'inverse publié), livré en
`InputEventScreenDrag` relatif à l'ANCRE du writer (qui bouge à
l'atterrissage). Il ne freine pas (un doigt n'a pas de frein) : il lève
dans le rayon d'arrivée et la planche roule. Sa garde de progrès est une
propriété de banc, publiée (`stalled_out()`).

Retargets : `SkateInertiaProbe` (mur : « le doigt tenu à l'écart décolle
la planche du mur, 6,777 u en 60 ticks » — CH42), `SkatePhysicsProbe`
(PHASE S supprimée, PHASE B en un seul monde par retrait des
`CollisionObject3D`, PHASE I neuve), `SkateFeelProbe` (PHASE B un monde,
PHASE O supprimée, fov et montée : INERTES sous la poursuite),
`SkateInputProbe` (PHASE I à pied, A sans bascule, R sans destination, F
sur le signal `fenced` au tick, O supprimée, T recalibrée sur la tuning
planche), `SkateDismountProbe` réécrite sur le geste de sortie (X sautée
en headless, signée sous xvfb), `SkateDriveProbe` réécrite sur le CHEMIN
D'ACTIVATION (pixel sur la planche → marche → montage → writer armé →
poursuite → doigt tenu par le moteur → roue libre → tap de sortie → la
prochaine tape marche). `SkateTraverseProbe` inchangée (ses phases R
passent encore par `mount_vehicle`, un chemin que le jeu n'emprunte plus
pour la planche — signalé, scoring hors scope).

## Section 4 — rouge avant vert

Sept passes dans une copie isolée de l'arbre, chaque fichier restauré et
vérifié byte-identique (`cmp`) :

| # | neutralisation | rouges attendus | obtenus |
|---|---|---|---|
| 1 | `TRICK_SWEEP_DEG = 1e9` | tout ce qui tire | **13** (6 G + L + 6 H) |
| 2 | tracé au sol aussi | « le même cercle au sol ne tire pas » | **1**, celui-là |
| 3 | `rebase()` supprimé | l'ancre au contact, pas de virage | **2** |
| 4 | `AIR_ARM_TICKS = 1` | deck, pop court, pop long, « no took_off » | **4** |
| 5 | face non gelée en l'air | face gelée, cap au contact | **2** |
| 6 | cap de lacet retiré | (CALM) le relâchement sort de la bande, bord nord | **2** |
| 7 | `keep_inside` retiré | bord nord hors région, planche invisible | **2** |

## Section 5 — la table croisée, deux arbres

Import complet vérifié des deux côtés avant toute comparaison : **154 `.scn`
= 154 `.scn`**. Baseline = `origin/staging` (`33b705c`) importée à part
(`/home/user/keepy-base`), runs séparés, même machine.

| sonde | branche | baseline | écart |
|---|---|---|---|
| `SkateInputProbe` (xvfb) | **70 / 0** | 82 / 0 | −12 : PHASE O (schéma TAP) supprimée, PHASE I/A/R/F reciblées |
| `SkateInertiaProbe` | **86 / 0** | 86 / 0 | identique en nombre ; mur : « le doigt tenu à l'écart décolle la planche » remplace la garde d'immobilisation |
| `SkatePhysicsProbe` | **121 / 0** | 122 / 0 | PHASE S supprimée, PHASE I neuve (coût au repos), B en un monde, R sur `max_y`, J sur la solidité |
| `SkateDismountProbe` (xvfb) | **37 / 0** (33 en headless, X sautée) | 90 / 0 | réécrite sur le geste de sortie (+ PHASE F mid-air) |
| `SkateFeelProbe` (xvfb) | **121 / 0** | 136 / 0 | PHASE O supprimée, B en un monde, fov et montée INERTES sous la poursuite ; P : blob 171 px sur plancher 70 (marginal, planche levée d'1 u pour la capture) |
| `SkateDriveProbe` (xvfb) | **28 / 0** | 29 / 0 | réécrite : le chemin d'activation |
| `SkateparkProbe` (xvfb) | **57 / 0** | 55 / 0 | +2 : G3/G4 (dalle 16 tri, park + dalle 836 ≤ 6 000) |
| `SkateTraverseProbe` | **36 / 0** | 36 / 0 | identique (diagonale 66 hops / 18,700 s) |
| `PhysicsCostProbe` (xvfb) | NO VERDICT (18 ok) | NO VERDICT (18 ok) | **les deux arbres** : « this room cannot resolve the quantity » — le plancher de bruit de ce sandbox, pas le lot ; I1 lit désormais le béton seul (468) |
| `ChaseAudit` (xvfb) | **33 / 0 PASS** | 14 / 0 PASS | +19 : PHASE CALM ; station skatepark **moins chère** (voir ci-dessous) |
| `SkateTrickProbe` (neuve) | **54 / 0** | — | sept passes rouges, section 4 |
| `ProbeTimeoutAudit` | **96 scènes** | 95 scènes | +1 : `SkateTrickProbe` (`SkateBench.gd` classé NOT_PROBES) |

Station skatepark de `ChaseAudit`, primitives `gpu` par azimut (soleil) :

| azimut | 0 | 45 | 90 | 135 | 180 | 225 | 270 | 315 |
|---|---|---|---|---|---|---|---|---|
| baseline | 16 851 | 17 451 | 20 034 | 55 698 | 85 289 | 61 754 | 31 191 | 18 219 |
| branche | **15 280** | **16 158** | **19 027** | **54 812** | **84 792** | **60 849** | **30 342** | **16 914** |

**Moins cher partout** : la dalle publie un disque d'emprise r 13,5 dans
`footprints()`, et les touffes qu'il retire au semis pèsent plus que les
368 triangles de décor et de dalle ajoutés. Pire frame du hub inchangée
(storm/cove/270 : 102 466 contre 102 478). Draw calls : +1 (dalle) +4
(surface décor de quatre modules). **Ce sont des proxys** ; le FPS device
est à Mathieu (relevés CH63 : 55 soleil / 50 pluie à la station park).

`SkatePhysicsProbe` PHASE I (branche, seule sur la machine) :

```
run 1 (machine partagée) : delta au repos +0,019 ms/tick, plancher 0,054  -> sous le plancher
run 2 (seule)             : delta au repos +0,062 ms/tick, plancher 0,042  -> 3,7 % d'une frame de 20 ms à F = 10
run 3 (seule)             : delta au repos -0,051 ms/tick, plancher 0,032  -> sous le plancher
positif (planche montée, doigt tenu) : +0,179 à +0,211 ms/tick, 4 à 7 fois le plancher (CH56 : +0,219 pour le premier corps mobile)
gate : delta au repos <= 0,10 ms/tick (6 % d'une frame de 20 ms à F = 10) ET < un ride
```

## Section 6 — ce que ce lot ne signe pas

* **Le ressenti** du trick (le cercle est-il naturel au pouce), le
  **confort** de la caméra calmée, le **FPS device** (proxys : triangles,
  draw calls, primitives par station, tick physique headless).
* Le seuil de 300° et les quatre nombres de caméra sont des commits, pas
  des toggles — c'est l'objet de ce lot.
