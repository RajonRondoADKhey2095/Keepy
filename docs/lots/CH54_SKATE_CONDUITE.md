# CH54 — Le skate devient conduisible : diagnostic par la mesure, puis un profil d'allure sur le patron glide

**8 septembre 2026.** Le lot qui répond au retour device de Mathieu sur le
skatepark CH53 : *« Keepy est sur le skate mais il ne le conduit pas »*.
Deux hypothèses étaient posées, à trancher **par la mesure avant d'écrire
une ligne** : H1 (il ne bouge pas — un défaut de câblage), H2 (il bouge,
mais rien ne se lit comme une conduite — un manque de game feel).

---

## 0. LA BASE, ET LA GARDE DE CONCURRENCE

La branche `claude/skateboard-drivability-north-lgmqk8` avait été ouverte
sur **`main` (`2876f27`)**, comme celles de CH51 et CH53 avant elle.
Repositionnée sur `origin/staging` (`6b2d65a`, merge CH53) avant la
première ligne de code. **Tout lot de cette suite part de `staging`.**

Garde de concurrence, faite au début et par ARBRE : une seule branche
distante récente (`origin/claude/skateboard-drivability-north-lgmqk8`),
ancêtre de `staging` (`merge-base --is-ancestor` vrai) — donc aucun
travail concurrent, seulement la branche vide de ce lot. Aucune session
concurrente vivante.

Outillage : Godot 4.3-stable et les templates d'export installés dans le
sandbox (le `.tpz` vérifié à **1 073 228 327** octets contre le
`Content-Length`, CLAUDE.md ayant payé quatre téléchargements tronqués).
Deux arbres importés séparément : **762 `.scn` de chaque côté, zéro
`Cannot open file`**, comptés avant toute comparaison.

---

## 1. LE DIAGNOSTIC — H2, PAR TRACÉ, PAS PAR LECTURE

`SkateDriveProbe` (nouvelle, permanente, **xvfb + `opengl3` +
`--fixed-fps 60`**, jamais `--headless` : chaque tap y passe par
`HubTapInput._handle_point`, c'est-à-dire un point ÉCRAN déprojeté sur la
caméra livrée, et en headless le rect du conteneur vaut 0×0 donc tout
« il a bougé » passerait gratuitement en ne s'exécutant jamais).

PHASE I : le conteneur a un rect réel (1080×1920), la planche en (3 ; 60)
se projette DANS le conteneur, un tap sur l'herbe du lobe est
`tapped_ground`. PHASE D, sur la planche CH53 telle que livrée :

| geste | ce qui s'est passé |
|---|---|
| tap sur la planche garée | `tapped_vehicle` → marche de 55 frames → `is_on_vehicle()` vrai, `vehicle_node()` = la planche, debout à (3,00 ; 0,15 ; 60,00) — **le câblage est juste** |
| tap 12 u au sud, sur la planche | **16,002 u parcourus** (de z = 60 à 44), **7,941 u/s dès la frame 1**, 6 atterrissages de 2,7 u, **arcs de 1,300 u** (1,15 + 0,15 de deck), arrêt sec 7,4 → 0 |
| le même tap à pied | 12,000 u, 5,357 u/s dès la frame 1, 8 hops, arcs 0,599 u |

**Verdict : H2.** Il bouge — et il bouge exactement comme le Sautillon,
avec une planche dessinée sous les pieds. Pas de vitesse propre (× 1,48 la
marche, le multiplicateur de la balle), pas de mise en vitesse (7,9 u/s à
la première frame), pas d'arrêt (7,4 → 0 en une frame), et un REBOND de
1,3 u à chaque pas, qui est la signature de la balle. Mathieu décrivait
précisément ce que la sonde a lu.

Ce que la lecture seule n'aurait pas tranché : rien dans le code n'était
FAUX. `_try_mount_ball` monte bien la planche, `mount_vehicle` la porte
bien, chaque tap la déplace. H1 était plausible sur au moins un point que
CLAUDE.md documente (un `Control` plein écran qui avale les taps — le
`SkateHud` est bien en `IGNORE`, vérifié) et il fallait un tracé pour
l'écarter.

---

## 2. CE QUI EST CONSTRUIT — LE PATRON GLIDE DE CH29, ÉTENDU

Le brief demandait de regarder comment les véhicules existants se
déplacent avant d'inventer. `KeepyHopper` portait déjà **deux** modes de
véhicule : le BONDISSANT (la balle, la planche CH53) et le **GLISSANT** de
CH29 (`mount_vehicle(v, lift, glide_step, glide_s)` — hops plats,
enchaînés en roulement continu, ni squash ni tangage). Le char à voile
l'a utilisé jusqu'à CH30, qui l'a fait piloter ; depuis, **aucun véhicule
n'y passait** (`is_gliding()` n'était lu que par deux sondes en
négatif). La planche en est le nouvel utilisateur, et le mode gagne ce qui
lui manquait pour être une conduite : **un profil d'allure**.

### 2.1 Le profil

Un facteur d'allure sur la croisière autorée (`glide_step / glide_s`) :

* **au repos, `GLIDE_PACE_FLOOR` = 0,35** — pas 0 : un tap répond tout de
  suite, la première frame BOUGE, seulement au tiers de la croisière ;
* **montée** de (1 − 0,35) sur `accel_u` unités de roulement ;
* **descente** vers le plancher sur les `brake_u` dernières unités avant
  la cible — la cible reste atteinte exactement, aucun dépassement, la
  région clampe toujours la destination ;
* **relance** : un re-tap derrière (cosinus négatif entre deux segments)
  remet l'allure au plancher — il faut repousser ; un virage plus serré
  que 60° la divise par deux ; droit devant, elle est conservée.

Chaque segment est un tween de `glide_step` (1,6 u) dont la vitesse
RAMPE LINÉAIREMENT de l'allure à laquelle le précédent a fini vers celle
que celui-ci gagne ; `_apply_hop` reconvertit la fraction de TEMPS du
tween en fraction de DISTANCE (`_glide_progress`, quadratique, identité
quand les deux allures sont égales). Sans cette rampe le profil est un
ESCALIER — mesuré par la passe rouge 2, §4.

**Rien d'autre ne bouge** : ni physique, ni collider, ni contact, ni
caméra de poursuite. Un segment reste un tween d'un point sol à un autre,
`hop_landed` à chaque fin, la marche à pied intacte. Un véhicule qui
passe des zéros (`accel_u = brake_u = 0`) glisse à l'allure constante de
CH29, y compris sans pénalité de virage et sans plancher au repos
(`_glide_rest_pace()`).

### 2.2 Les nombres, publiés par `HubTransport` à côté du parc

| constante | valeur | pourquoi |
|---|---|---|
| `SKATE_CRUISE` | **10,0 u/s** | × 1,87 la marche (5,36 mesuré), × 1,26 le rebond ; le char CH29 glissait à 10,7 et se lisait rapide sur device |
| `SKATE_GLIDE_STEP` | 1,6 u | un re-tap répond en ≤ 0,16 s à la croisière ; les rampes ont trois marches ; une traversée du parc atterrit 6 fois et non 12 (chaque atterrissage déroule toute la chaîne de `HubWorld._on_hop_landed`) |
| `SKATE_ACCEL_U` / `SKATE_BRAKE_U` | 3,2 u chacune | deux segments ; depuis l'arrêt les 3,2 premières unités prennent 0,50 s, ce que prennent deux hops de marche |

⚠️ **La croisière a d'abord été 9,0, et la mesure l'a fait monter.** Sur
les 16 u de la planche garée au point de tap, le tracé donnait
**2,233 s** contre **2,100 s** pour le rebond CH53 : les rampes coûtaient
plus que la croisière n'apportait, et une conduite plus lente de bout en
bout que la chose qu'elle remplace n'est pas une conduite. À 10,0 :
**1,967 s**.

### 2.3 ⚠️ Un tween qui finit au milieu d'une frame laisse UNE frame courte par segment

Trouvé sur le tracé, pas par raisonnement. Le profil à 10 u/s lisait
`10.0 10.0 10.0 10.0 6.0 10.0 10.0` : un segment de 1,6 u à 10 u/s dure
0,16 s soit 9,6 frames, le tween se termine à la 10ᵉ en SNAPPANT à sa
fin, et cette frame ne parcourt que 0,6 frame de distance. À pied la même
chose existe (le `4.3` du tracé de marche, et le « chaque trajet coûte
~1,2 % de plus que l'arithmétique » que `HOP_DURATION` documente) et le
rebond la cache sous son arc. **Un roulement plat n'a rien pour la
cacher.**

Mesuré sur un tween jetable : `Tween.get_total_elapsed_time()` **inclut**
le delta entier de la dernière frame (0,16667 lu pour 0,16 de durée), et
`custom_step(over)` sur le tween suivant, appelé dans la MÊME frame,
l'absorbe (t = 0,0417 immédiatement, puis 0,1458 à la frame suivante —
continu). C'est ce que fait `_begin_hop` en glisse seulement : le
dépassement est lu dans `_on_hop_finished`, dépensé par le segment
suivant, jeté par tout le reste. **À pied cette frame fait partie des
chiffres de traversée publiés et reste** — la diagonale 66 hops /
18,700 s est un compte de frames, pas de hops.

Après : pire saut de fenêtre de 3 frames **0,28 u/s** (1,80 avant), et
**0 frame courte sur 62 frames de plateau** (PHASE P7).

### 2.4 Le proxy de score sous un roulement

Un roulement atterrit tous les 1,6 u. Sans règle neuve, une traversée du
disque du bol (r = 3,0) aurait scoré **quatre « carves »** en passant, et
chaque segment d'herbe entre deux modules aurait cassé la chaîne — la
chaîne devenait impossible à construire. `HubSkatepark.note_landing`
ignore donc, en glisse, tout atterrissage qui n'est pas le DERNIER du
roulement (`KeepyHopper.roll_remaining() > ARRIVE_EPSILON`) : ni score ni
cassure, ce n'est pas un atterrissage, c'est le milieu d'un roulement.
Seul le point où il S'ARRÊTE compte : *il a roulé jusqu'au module et s'y
est arrêté*. La sémantique CH53 (« il est retombé sur le module, sur la
planche ») est conservée, et le proxy reste un proxy — l'en-tête de
`HubSkatepark` le dit toujours.

`CHAIN_WINDOW_S` = 3,4 re-dérivé pour le roulement et **conservé** : les
10,1 u entre les deux modules les plus écartés prennent ~1,5 s de repos à
repos, plus le doigt.

---

## 3. LA SONDE — `SkateDriveProbe`, permanente

| phase | ce qu'elle gate |
|---|---|
| **I** | rect réel, planche dans le conteneur, canal de tap (`tapped_ground` sur l'herbe) |
| **D** | le diagnostic (§1), rejoué à chaque run : tap planche → `tapped_vehicle` → montée par le canal ; tap 12 u au sud → tracé ; même tap à pied → témoin |
| **P** | le profil, sur le tracé de D : P1 pic = croisière publiée ; P2 les 3 premières frames entre 10 % et 50 % de croisière ; P3 95 % de croisière atteints après la frame 12 et avant la 48 ; P4 les 3 dernières frames mobiles entre 10 % et 50 % ; P5 hauteur max = deck (0,150) — il roule, il ne rebondit pas ; P6 pire saut entre fenêtres de 3 frames < 25 % de croisière ; P7 zéro frame courte sur le plateau (≥ 20 frames) |
| **T** | T0/T1 témoin : un re-tap droit devant conserve l'allure 1,000 ; T2 un re-tap derrière ramène le segment suivant à **0,675** (= 0,35 + 0,65 × 1,6/3,2, prédit puis lu) |
| **S** | S1a **blind check** : le roulement (3 ; 60) → (0,5 ; 50,5) a atterri **2 fois DANS le disque du bol** en passant ; S1b aucun score ; S1c chaîne intacte ; S2 un arrêt sur le bol score exactement une fois ; S3 l'arrêt suivant sur le rail CHAÎNE (1) malgré les segments d'herbe, S3b zéro `chain_broken` ; S4 la funbox fait 2 |

Résultats du run final : **ALL GREEN**, 16 u en 1,967 s, premières
3 frames à 3,76 u/s, dernières 3 à 3,74, croisière atteinte à la frame
29, pire saut 0,28, 62 frames de plateau sans frame courte.

Le tracé complet (vitesse toutes les 6 frames) :
`3.6 4.6 5.7 6.7 8.4 10.0 10.0 10.0 10.0 10.0 10.0 10.0 10.0 10.0 10.0 9.2 7.5 6.2 5.1 4.1 0.0`.

---

## 4. ROUGE AVANT VERT — quatre neutralisations, quatre comptes prédits

| passe | neutralisation | rouges prédits | rouges lus |
|---|---|---|---|
| 1 | `SKATE_ACCEL_U` = `SKATE_BRAKE_U` = 0 (plus de rampes) | P2 P3 P4 T2 | **P2 P3 P4 T2** — 4/4 (premières frames à 10,00 u/s, croisière à la frame 1, relance à 1,000) |
| 2 | `_glide_progress` rendue identité (plus de rampe dans le segment) | P6 | **P2 P4** seulement — P6 VERT : la fenêtre de 3 frames diluait un escalier de 3,3 u/s en 1,1 par décalage, sous le plafond de 2,5 |
| 3 | report de dépassement retiré (`custom_step` neutralisé) | P7 | **AUCUN** — P7 définissait le plateau par une fenêtre qui CONTENAIT la frame testée : un `6.0` entre des `10.0` tirait sa propre fenêtre sous la barre et n'était jamais testé |
| 2b | idem 2, gates P6/P7 réécrits PAR FRAME | P2 P4 P6 | **P2 P4 P6** — 3/3 (saut 2,41 u/s à la frame 100) |
| 3b | idem 3, gates réécrits | P6 P7 | **P6 P7** — 2/2 (saut 5,40 u/s, **7 frames courtes** sur 49, pire 4,60 u/s) |
| 4 | garde « seul le dernier atterrissage compte » retirée | S1b S2 S3 S3b S4 | **S1b S2 S3 S3b S4** — 5/5 (2 scores en passant, 3 « carves » pour un arrêt, chaîne cassée par l'herbe) |

**Deux gates ont été trouvés aveugles par leur propre passe rouge**, et
c'est la seule raison d'exister de la passe : P6 et P7 étaient verts sur
le code correct ET sur le code neutralisé. Réécrits frame à frame — le
saut entre deux frames consécutives plafonné à un dixième de la croisière
(les rampes livrées montent de ~0,3 u/s par frame), et le plateau défini
par les deux VOISINES de la frame testée, jamais par une fenêtre qui la
contient. Le vert final : pire saut **0,28 u/s**, **0 frame courte sur
60**.

Chaque fichier restauré depuis sa copie et vérifié **byte-identique**
(`cmp`).

---

## 5. TRAVERSÉES ET SONDES EXISTANTES — deux arbres

`SkateTraverseProbe` (headless, transforms seulement, comme son en-tête
l'exige) sur les deux arbres :

| trajet | `origin/staging` (6b2d65a) | branche CH54 | publié |
|---|---|---|---|
| diagonale du carré | 66 hops / 1 122 frames / **18,700 s** | 66 / 1 122 / **18,700 s** | 66 / 18,700 |
| pire CH38 (35 ; −35) → (−63 ; 18) | 74 / 1 258 / **20,967 s** | 74 / 1 258 / **20,967 s** | 20,967 |
| pire CH50 (−63 ; −12) → (22,43 ; 51,74) | 71 / 1 207 / **20,117 s** | 71 / 1 207 / **20,117 s** | 20,117 |
| à travers le parc (0 ; 40) → (0 ; 61) | 14 / 238 / 3,967 s | 14 / 238 / 3,967 s | 3,967 |

ALL GREEN des deux côtés, 0 rouge, le plafond de 22,0 s tenu avec la
même marge qu'avant.

La marche à pied n'a pas bougé d'une frame — ce qui est attendu par
construction (le profil ne vit que derrière `is_gliding()`, et la seule
ligne partagée, la remise à zéro dans la branche d'arrivée de
`_advance()`, écrit une variable que la marche ne lit pas) et qui est
**mesuré** plutôt que déduit, parce que CLAUDE.md a payé une extraction
« pure » qui divergeait au 30ᵉ frame pour une question de type.

`SkateparkProbe` (xvfb + `opengl3`, le rendu du parc, son budget par
station, le cadrage, le HUD) rejouée sur la branche : **ALL GREEN, 52
vérifications, 0 rouge** — le lot ne touche ni un nœud, ni un mesh, ni
un pixel du parc, et la sonde le confirme plutôt que de le supposer.
`SkateDriveProbe` n'existe pas sur `origin/staging` et n'a donc pas de
colonne de référence : son PHASE D EST la mesure de référence (§1).

---

## 6. BUILD

Export Web local (`godot4 --headless --export-release "Web"`, templates
4.3.stable vérifiés) : **exit 0, zéro `Parse Error`, zéro `SCRIPT
ERROR`**, zéro `Storing File: res://build` (auto-contamination écartée par
`rm -rf build` préalable). `index.wasm` **35 376 909 octets / md5
`af4a8fc2925d992348eb30deeeb54360`** et `index.js` md5
`4e08904b1b7107858246af44b602067b` — l'identité que CLAUDE.md publie
pour tout lot qui ne touche pas le moteur. `index.pck` 34 661 200 octets
(marqueur « nouveau build », jamais une preuve, CLAUDE.md). La CI de
`staging` est le second signal, lu après le push.

---

## 7. ZONES D'INCERTITUDE — dites, pas maquillées

1. **Aucune frame de ce lot n'a été vue sur un GPU réel ni sur un
   téléphone.** Le profil est prouvé en transforms à 60 fps fixes ; le
   corridor nord tourne à 34-49 FPS sur device (relevé CH52/CH53) et ce
   que le report de dépassement (§2.3) vaut à 40 fps irréguliers n'est
   pas mesuré ici.
2. **Le feel est un arbitrage, pas une mesure.** 10,0 u/s, 0,35 de
   plancher, 3,2 u de rampes : dérivés (§2.2), mais le seul juge est le
   pouce de Mathieu. Les quatre nombres sont des constantes de
   `HubTransport`, un réglage est une ligne.
3. **Pas d'inclinaison du corps.** Une inclinaison avant liée à l'allure
   était envisagée et écartée : `_on_hop_finished` remet le tangage à sa
   base à chaque fin de segment, et un lean réécrit à la frame suivante
   aurait clignoté 6° tous les 10 frames. Le faire proprement touche le
   chemin partagé ; ce n'est pas ce lot.
4. **Le proxy reste un proxy** (CH53 §4.2), et il l'est un peu plus
   franchement : il ne score plus que là où le rider S'ARRÊTE. Un joueur
   qui roule à travers tout le parc sans s'arrêter ne marque rien — c'est
   voulu, et c'est dit.
5. **Le budget perf n'a pas bougé et n'a pas été re-mesuré** : zéro
   primitive, zéro draw call, zéro nœud ajouté (le lot ne touche que des
   scripts de mouvement et de score). Une sonde de budget aurait mesuré
   un delta de zéro sur un banc dont le plancher de bruit vaut plus.
6. **La caméra reste figée** — décision CH53 reconduite (un véhicule
   PILOTÉ amène la poursuite, dont CH52 §8.5 dit que le budget nord ne
   vaut pas pour elle). Si Mathieu veut piloter au pouce, c'est un
   `ChaseAudit` du lobe, pas une constante.

---

## 8. NEXT STEPS

| # | quoi | pourquoi |
|---|---|---|
| 1 | **Lecture device de Mathieu** : monter la planche en (3 ; 60), taper le bol, puis le rail, puis la funbox ; sentir le départ, la croisière, le freinage, la relance après un tap derrière | le seul juge du feel ; §7.2 |
| 2 | Régler `SKATE_CRUISE` / `GLIDE_PACE_FLOOR` / les rampes sur ce retour | quatre constantes, une ligne chacune ; la sonde gate le profil, pas ses valeurs |
| 3 | Un « pop » sur le dernier segment quand la cible est un module (un petit arc onto la rampe) | un cue visible au moment du score, cheap sur le chemin d'arc existant ; écarté ici pour tenir le périmètre |
| 4 | Le z-fighting du fond du bol | identifié, **non touché** par ce lot sur consigne explicite |
| 5 | Le son du roulement | un skate muet est ce qui part |
