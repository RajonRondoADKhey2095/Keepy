# CH24 — Feu de camp interactif : le blaireau vient s'asseoir

> Stub créé en RECON PURE (4 septembre 2026), avant tout lot d'implémentation.
> Numéro de lot attribué par ordre (CH23 est le dernier chantier existant).
> Aucune ligne de code de jeu écrite par cette session ; le contenu ci-dessous
> est la recon complète, à reprendre telle quelle par le premier lot
> d'implémentation.

## Contexte

CH23 a clos le feu de camp lui-même (bûcher + flamme, lot 3-5) et son cercle
de pierres SOBRE (lot 6-7), mergés `staging` (`dede1d4`), site définitif
`(19.9, 25.4)`. Le feu n'a aucune interaction : ni tap, ni entrée dans
`ground_footprints()` (dette déjà signalée par CH23 lot 7).

Le blaireau (CH21_TYROLIENNE) est un `HubActorWalker` générique, rigué,
actuellement dédié à la tyrolienne (attente à une tour, traversée suspendue).

## Sujet de ce chantier

Faire marcher le blaireau depuis sa position d'attente actuelle jusqu'à un
point proche du feu, où il reste debout en idle. Pas de tap sur le feu prévu
dans le brief initial de recon — seulement une interaction de tap sur le feu
à évaluer côté faisabilité (voir RECON 1 ci-dessous). Pas de prop chaise, pas
de nouvel asset.

## RECON 1 — Pattern de tap sur un prop purement décoratif

Voir `CLAUDE.md` → aucune doctrine nouvelle extraite ; le détail complet vit
dans le rapport de recon livré en session (4 septembre 2026, branche
`claude/feu-camp-recon-sjvm0m`), résumé :

- Aucun pattern de tap "décoratif pur" n'existe dans le hub aujourd'hui.
  `HubTapInput.gd` déclare 6 canaux (`tapped_boat`, `tapped_zipline_badger`,
  `tapped_zipline_solo`, `tapped_owl`, `tapped_cabin`, `tapped_ladder`), tous
  fonctionnels (transition d'état ou trajet). La pie/magpie (CH19) n'est pas
  un prop tapable du plateau 3D : elle est dessinée à l'intérieur de la
  coupe de la cabane, sans tap propre.
- Le feu lui-même documente explicitement (`HubCampfire.gd:37`) : "no tap,
  no Area3D, no ignition state, no persistence" — décision de Mathieu,
  inchangée.
- Un nouveau canal (`tapped_campfire`, sur le patron OWL/CABIN) est
  transposable techniquement, mais reste une décision de scope à trancher
  avec Mathieu — non tranchée ici.

## RECON 2 — Script du blaireau

- `HubActorWalker.gd` est déjà générique et interruptible : `walk_to(point)`
  accepte n'importe quelle destination à tout moment (state IDLE/WALKING/
  ARRIVED), signal `arrived`. Aucun changement structurel requis pour un
  "marche vers point arbitraire puis idle" — c'est littéralement ce que la
  méthode fait déjà.
- Le point d'accroche : `HubWorld.gd` construit et pilote `_badger` par
  callbacks dédiés à la tyrolienne (`_on_tapped_zipline_badger`,
  `_try_zip_badger`, `_badger_take_seat`, `_badger_follow_zipline`). Un
  nouvel appel `_badger.walk_to(<point près du feu>)` depuis un nouveau
  déclencheur (tap sur le feu si retenu, ou tout autre événement) s'ajoute
  à côté de ces callbacks sans les toucher.
- Idle : le rig ne porte que deux clips, `Running` et `Walking` (mesuré
  CH21 RECON 3, ligne 254 : "les mêmes deux, mêmes durées, mêmes 72
  canaux"). Pas de clip "idle" dédié. L'arrêt du blaireau utilise déjà
  `_freeze()` (frame 0 de `Walking`, en boucle arrêtée) — c'est le
  mécanisme qui sert déjà de pose d'attente à la tour.

## RECON 3 — Géométrie / clearance au point d'arrivée

⚠️ Calcul À LA MAIN à partir des constantes du code (`HubBuilder.gd`,
`HubWorld.gd`), **non re-mesuré en moteur** (aucun binaire `godot4`
disponible dans ce sandbox, comme CH23 lot 7 l'a déjà signalé). À reprouver
par sonde avant tout merge.

- Position actuelle du blaireau (`_badger_rest(0)`, tour proche de la
  tyrolienne) : `stair_foot + side * BADGER_SIDE_OFFSET(1.10)` ≈
  **(28.96, 0, 7.62)** — dérivé de `near = (27.7, 0, 9.2)`,
  `far = (25.2, 0, 35.0)`, `ZIPLINE_DECK_HALF=0.65`, `ZIPLINE_STEP_DEPTH=
  0.26 × ZIPLINE_STEP_COUNT=4`.
- Distance jusqu'au site du feu (19.9, 25.4) : **≈ 19.95 u**.
- Bornes déjà mesurées par CH23 (lot 6/7, `docs/lots/CH23_FEU_VFX.md`) :
  bord extérieur de l'anneau de pierres **1.529 u** au pire ; dégagement
  publié au site (enveloppe convexe du voisinage) **3.521 u**.
- Point d'arrivée PROPOSÉ (non tranché) : sur le rayon site → position
  actuelle du blaireau, à 2.19 u du centre (1.529 + `KEEPY_CLEARANCE`
  0.66) : **≈ (20.90, 0, 23.44)**. Par construction ce point est hors de
  l'anneau et du bûcher, et le segment blaireau→point est un
  sous-segment du rayon blaireau→site, donc n'entre dans le disque de
  dégagement du feu qu'à son extrémité.
- Trajet : le hub n'a pas de navmesh — `HubActorWalker` marche en ligne
  droite (`move_toward` sur XZ), sans évitement d'obstacle, et le feu ne
  déclare toujours aucune emprise à `ground_footprints()` (dette CH23 lot
  7, non traitée). Rien n'empêcherait donc mécaniquement le blaireau de
  traverser un autre prop sur le trajet ; **non vérifié** au-delà du
  segment final près du feu (pas de rendu ni de sonde exécutés cette
  session).

## Découpage proposé pour le lot d'implémentation (à discuter, pas décidé)

1. Décision Mathieu : tap sur le feu retenu ou non (sinon, quel
   déclencheur fait marcher le blaireau — un événement existant ?).
2. Si tap retenu : nouveau canal `tapped_campfire` sur le patron OWL/CABIN
   dans `HubTapInput.gd` + wiring dans `HubWorld.gd`.
3. Un point d'arrivée MESURÉ par sonde (reprendre le calcul ci-dessus,
   confirmer clearance et absence de croisement du trajet).
4. `_badger.walk_to(point)` câblé sur le déclencheur retenu ; retour au
   poste tyrolienne à traiter (comportement au retour à trancher avec
   Mathieu — non couvert par cette recon).
5. Rouge-avant-vert sur toute nouvelle assertion, blind check si une
   sonde teste une absence/égalité.

## Statut de la recon

Recon uniquement au moment de ce stub. Aucun code de jeu modifié par cette
session. Le lot d'implémentation qui suit reprend ce découpage tel quel.

---

# LOT 1 — Implémentation (4 septembre 2026)

> Reprend le découpage ci-dessus point par point, sur décisions actées par
> Mathieu (canal `tapped_campfire`, aller-retour, patron bateau — jamais
> patron échelle —, pas de chaise). **Le brief de ce lot citait un commit
> `0a152f9` pour ce stub qui ne correspond à aucun commit de ce dépôt** ;
> le stub réel vit dans l'historique `staging` sous `23000f1` — traité
> comme le même document malgré le hash divergent (contenu identique
> constaté après fetch), plutôt que re-fait de zéro en aveugle.

## Ce qui a été livré

Un sixième couple (canal, gate) sur `HubTapInput` : un tap sur le feu envoie
le blaireau s'y asseoir (pose `Walking` frame 0, mécanisme déjà existant de
`_freeze()` -- aucun nouvel asset, aucune nouvelle pose) ; un second tap le
ramène à sa position de repos tyrolienne. Pendant tout le détour (marche
aller, assis au feu, marche retour), le canal `tapped_zipline_badger` est
retiré -- patron bateau, jamais patron échelle -- via une nouvelle méthode
`ZiplineDoor.set_badger_at()` qui réutilise le gate `_at_end < 0` déjà câblé
pour un trajet de câble en cours, plutôt que d'ajouter un second drapeau.
`tapped_zipline_solo` n'est PAS touché : il ne lit que `_riding`, jamais
`_at_end`, donc Keepy peut toujours traverser seul pendant que le blaireau
est au feu -- vérifié en lisant `ZiplineDoor.gd`, pas supposé (RECON 1
notait déjà les 6 canaux existants ; celui-ci en fait 7).

## Le point d'arrivée -- la recon avait raison sur le chiffre, pas sur sa sûreté

RECON 3 proposait **(20,90 ; 23,44)**, sur le rayon site → position du
blaireau, à 2,19 u du centre (1,529 + `KEEPY_CLEARANCE` 0,66) -- et notait
elle-même : "Rien n'empêcherait donc mécaniquement le blaireau de traverser
un autre prop sur le trajet ; **non vérifié** au-delà du segment final près
du feu." Ce lot a fait cette vérification, et elle a trouvé un défaut réel.

Aucun binaire `godot4`/`godot` n'est présent dans ce sandbox non plus
(`which`, `find /` : rien) -- même constat que RECON 3 et que CH23 lot 7 --
donc pas de rendu `xvfb` + `opengl3` possible ici. Le contrôle est resté
analytique (segments contre le cercle de l'anneau), avec les mêmes
quantités publiées que la recon :

* `HubCampfire.SITE` = (19,9 ; 25,4), bord extérieur pire cas de l'anneau
  **1,529 u** (`HubCampfire.gd`, commentaire de `STONE_RING_RADIUS`).
* `HubWorld.KEEPY_CLEARANCE` = 0,66.
* Position du blaireau aux DEUX bouts de la tyrolienne (RECON 3 n'en donnait
  qu'un) : bout 0 (28,958 ; 7,624) -- confirme RECON 3 à la précision près
  -- et bout 1, non calculé par la recon : **(23,942 ; 36,576)**.

**Rejeu du point proposé par RECON 3** sur le segment complet (pas
seulement l'extrémité) : le trajet ALLER depuis le bout 0 est effectivement
propre (c'est un sous-segment du rayon site→bout 0, exactement comme la
recon l'argumente). Mais le trajet RETOUR depuis le bout 1 -- que RECON 3
n'avait pas la donnée pour tester -- passe, en son point le plus proche, à
**1,409 u** du site : **à l'intérieur** du bord extérieur mesuré de
l'anneau de pierres (1,529 u). Un vrai risque de croisement avec le
foyer/bûcher si le blaireau revient du bout éloigné de la tyrolienne, que
rien dans RECON 3 n'avait pu voir faute de calculer ce second bout.

**Correction retenue** : le point ne se pose plus sur le relèvement vers un
bout précis, mais sur l'axe LATÉRAL (`side`) de la tour proche -- le même
`Vector3(forward.z, 0, -forward.x)` que `_badger_rest()` lit déjà pour
placer le blaireau à côté de son escalier, pas un vecteur inventé pour
l'occasion. Balayage numérique (script Python hors moteur, 3600 pas
d'azimut à rayon fixe 2,189 u, faute de binaire Godot pour un vrai rendu) :
cet axe tombe au milieu d'une bande d'environ 28° où les DEUX approches
(bout 0 et bout 1) dégagent l'anneau de la marge complète publiée -- 2,189 u
des deux côtés, à la millimétrie. Le relèvement direct vers l'un ou l'autre
bout est au contraire le PIRE choix : c'est exactement l'angle où l'AUTRE
bout coupe le plus court. Point retenu : **(22,079 ; 25,611)**, au lieu du
(20,90 ; 23,44) proposé par RECON 3.

## Ce qui reste non vérifié faute de binaire Godot

* **Le rendu offscreen demandé par le brief n'a pas pu être fait** -- aucun
  `godot4` dans ce sandbox, comme RECON 3 et CH23 lot 7 l'avaient déjà
  signalé. La géométrie ci-dessus reste un contrôle analytique, pas un
  contrôle visuel.
* **Les props décoratifs batchés (rocher/arbre/buisson/souche/fleur)
  n'ont AUCUNE entrée dans `HubBuilder.FOOTPRINT_RADIUS`** -- ce moteur ne
  les traite comme obstacle de marche pour AUCUN acteur existant, blaireau
  compris (vérifié en lisant `ground_footprints()` et `HubActorWalker`, qui
  ne fait aucun évitement -- RECON 3 le notait déjà en général, ce lot l'a
  vérifié précisément sur le trajet retenu). Vérifiés à la main contre
  `hub_layout.tres` : le plus proche du trajet retenu est une souche à
  **0,84 u** de la jambe bout-0 → feu. Ce n'est pas un blocage de jeu (rien
  dans ce moteur ne bloque sur ces props), mais le CROISEMENT VISUEL
  (silhouette) n'a pas pu être confirmé par rendu -- item NEXT STEPS pour
  la CI/device.
* L'emprise du feu dans `ground_footprints()` reste la dette CH23 non
  traitée que RECON 1 et RECON 3 signalaient déjà -- hors scope explicite
  de ce lot, non touchée.

## Sonde / assertion rouge-avant-vert

Aucune sonde `.gd` n'a été ajoutée à `scripts/dev/` : sans binaire Godot
dans ce sandbox, une sonde ajoutée ici n'aurait pu être ni passée au rouge
ni au vert -- donc rien qui `push_error`/`assert` n'a été committé sans
preuve de sa propre capacité à échouer, conformément à la règle et au point
5 du découpage de RECON 3. Le contrôle géométrique du point d'arrivée
(segments contre le cercle de l'anneau) a été fait en Python, hors moteur,
et est reproductible mais **n'est pas un substitut à une sonde Godot
gatée** -- laissé en NEXT STEPS.

## Statut

Implémentation livrée (code + doc). Build et sondes **non vérifiés dans ce
sandbox** faute de binaire Godot -- palier `staging` poussé pour que la CI
fasse cette vérification, conformément à la consigne du brief de laisser ce
point en NEXT STEPS plutôt que de le supposer propre.

## RECON 4 -- vitesse du trajet, rotation retour, mécanisme de proximité (recon pure, aucun code touché)

### Sujet A -- vitesse

Distance retenue du lot 1 (`_campfire_point` = (22,079 ; 25,611), PAS le
(20,90 ; 23,44) de RECON 3) : **19,258 u** depuis `_badger_rest(0)`
(28,958 ; 7,624) -- position de repos par défaut du blaireau au boot, avant
toute traversée de câble -- et **11,122 u** depuis `_badger_rest(1)`
(23,942 ; 36,576) si le blaireau a déjà traversé. Les deux distances sont
identiques à l'aller et au retour (même segment, sens opposé).

`walk_speed` (0,7556 u/s, `HubActorWalker.gd`) est un `@export` de la
classe de base, PARTAGÉ entre `_bear` et `_badger` -- aucune instance ne le
redéfinit, seul `walk_rate` est par-instance (`_bear.walk_rate =
BEAR_WALK_RATE` 2.0 ; `_badger.walk_rate` n'est écrit NULLE PART, reste au
défaut 1.0). Ne jamais toucher `walk_speed` : ça changerait aussi la marche
de l'ours au tourniquet.

`walk_rate` multiplie DÉJÀ vitesse ET `speed_scale` de l'`AnimationPlayer`
ensemble (un seul knob, structurel -- commentaire `HubActorWalker.gd:64-79`) :
accélérer ne glisse pas, quelle que soit la valeur. Le risque n'est donc pas
le moonwalk mais un pas visuellement trop rapide pour lire comme une marche.

Temps actuel (rate 1.0) : **25,49 s** (bout 0) / **14,72 s** (bout 1) --
confirme le ressenti "trop long". Vitesse requise pour <=4s : 4,8145 u/s
(bout 0, **facteur x6,37**) ou 2,7805 u/s (bout 1, **facteur x3,68**).

**4s non atteignable proprement.** Le seul précédent chiffré du dépôt
(`BEAR_WALK_RATE` = 2,0, déjà expédié/validé) donne, à titre de comparaison
raisonnable :

| rate | bout 0 (19,258 u) | bout 1 (11,122 u) |
|---|---|---|
| 1.0 (actuel) | 25,49 s | 14,72 s |
| 2.0 (= BEAR_WALK_RATE) | 12,75 s | 7,36 s |
| 3.0 (50% au-delà du seul précédent) | 8,49 s | 4,91 s |

Même x3 (déjà au-delà de ce que ce dépôt a validé une fois) ne descend pas
sous 4s dans le pire cas (bout 0). Proposition : une constante DÉDIÉE
`CAMPFIRE_WALK_RATE` sur `_badger.walk_rate` SEULEMENT (jamais sur la classe
ni sur `_bear`), posée une fois à la construction du blaireau -- `walk_to()`
n'est jamais appelé sur `_badger` ailleurs que pour ce détour, donc pas de
bascule à gérer entre deux usages. Valeur autour de x2,0-x2,5, temps ~13-8s
(bout 0) / ~7-6s (bout 1) : réduction réelle, sans sortir du seul rate déjà
validé sur device pour ce projet.

Alternative "point d'arrivée plus proche" écartée par le calcul : à rate
1,5 il faudrait un point à <=4,53 u du repos -- soit quasiment au pied de la
tour, très loin du site (~19-20 u) -- ce qui viderait le détour de son sens
et rouvrirait la géométrie de dégagement anneau/segment validée au lot 1
sans nouveau balayage. Non proposée pour implémentation sans accord exprès.

### Sujet B -- rotation au retour

`HubActorWalker._process()` recalcule le cap à CHAQUE frame par
`atan2(to_target.x, to_target.z)` puis `lerp_angle` (turn_lambda 6.0) --
IDENTIQUE aller/retour, aucune inversion de signe. Le bug n'est pas dans
cette formule mais dans son AMORÇAGE : à l'arrivée au feu, rien n'appelle
`_badger.face()` -- l'orientation reste figée sur le cap de l'aller (converge
vite car trajet rectiligne, donc quasi constant tout du long).

Mesuré : cap figé à l'arrivée au feu = **-20,93°**. Cap requis pour le
retour vers le MÊME bout (cas le plus courant, blaireau n'ayant pas roulé
depuis) = **159,07°** -- écart exactement **180,0°**, le pire cas possible
pour un `lerp_angle` de vitesse finie. Pendant que le corps avance déjà en
ligne droite à pleine vitesse (`move_toward`, indépendant du yaw), le
modèle met ~0,5-1s à finir sa rotation : le dos est tourné vers la maison
pendant cette fenêtre, visible dès les premières frames du retour -- pile ce
que le screenshot montre. Retour vers l'AUTRE bout (si le blaireau a roulé
entre-temps) ne demande que **30,6°**, imperceptible -- ce qui explique
pourquoi le défaut ne se voit QUE dans le cas courant. Cause identifiée,
rien corrigé.

### Sujet C -- mécanisme de proximité (correctif de lecture)

Le mécanisme cité (bisous pie) N'EST PAS un bouton CTA d'UI. Grep exhaustif
`Button` sur `scripts/cabin/` et `scripts/hub/` : zéro résultat lié aux
hotspots (les seuls `Button` du dépôt sont `HubWorld._fallback_button` --
menu de secours -- et `HubConfirmDialog` -- popup avant Chased/Quizz/Battle
-- deux mécanismes SANS RAPPORT).

Ce qui existe réellement : `CabinMarker.gd`, un `Node3D` (pad + anneau +
`Label3D`, PAS un `Control`), copié VERBATIM du `HubPortal.tscn` du
plateau lui-même -- la classe déclare déjà un `enum Surface {CABIN_FLOOR,
HUB_GRASS}` et sert TANT la cabine QUE le plateau (les 3 portails Quizz/
Battle/Chased l'utilisent en HUB_GRASS). La proximité (`HubWorld._pulse_if_near`
/ `CabinInterior._pulse_if_near`, seuils `NEAR_FACTOR`/`NEAR_RELEASE`
partagés avec `HubPortal`) ne fait QUE piloter un pulse visuel (anneau qui
respire) sur un point déjà tapable en permanence -- le déclencheur reste un
TAP DIRECT sur ce point 3D, par le même canal que toute autre hotspot du hub
(`HubTapInput`), jamais un widget 2D qui apparaît/disparaît.

Transposition au feu : quasi mécanique. `HubWorld` a DÉJÀ ce pattern pour
ses 3 portails (ligne ~2652-2665) -- il suffit d'instancier un `HubPortal`
(ou un `CabinMarker` en `HUB_GRASS`) au site du feu et de le câbler dans
`_setup_campfire()` sur le même `_pulse_if_near`, exactement comme
`_tap.campfire_points`/`campfire_radius` le sont déjà. **Zéro `Control`,
zéro HUD, zéro `Button` en jeu** -- tout ce travail est du `Node3D` dans
`HubWorld.gd`. La clause du brief sur un lot HUD à faire par Opus 4.8 NE
S'APPLIQUE PAS ici : rien de cette transposition ne touche la mise en page
écran. Reste à trancher (mais sans HUD) : garder ou retirer le tap direct
sur le prop 3D lui-même une fois le marqueur posé à côté (le brief le juge
"peu lisible") -- probablement à retirer, pour ne laisser que le marqueur
comme unique entrée.

### Next steps proposés (lot d'implémentation)

1. Vitesse : `CAMPFIRE_WALK_RATE` dédiée sur `_badger.walk_rate` (~x2,0-x2,5),
   jamais sur `walk_speed` ni sur `_bear`.
2. Rotation : `_badger.face(...)` vers l'axe de retour explicite à l'entrée
   de `to_rest` (dans `_on_tapped_campfire`, avant `walk_to()`), pour que le
   yaw de départ soit correct avant que le corps ne bouge -- pas seulement
   laisser `lerp_angle` rattraper.
3. Proximité : instancier un marqueur (`HubPortal` ou `CabinMarker`
   `HUB_GRASS`) au site du feu, câblé sur `_pulse_if_near` comme les 3
   portails existants ; retirer ou garder le tap direct sur le prop selon
   arbitrage device. Aucune part HUD/Control -- reste Sonnet, pas Opus.
4. Les trois sont indépendants et peuvent être livrés dans le même lot ou
   séparément.

Aucune sonde, aucun rendu offscreen (toujours pas de binaire Godot dans ce
sandbox) -- recon purement analytique (lecture de code + calcul Python hors
moteur), comme RECON 3 et le lot 1.

---

# LOT 2 -- Vitesse, rotation au retour, marqueur de proximité (4 septembre 2026)

> Reprend les 3 next steps de RECON 4 point par point, sur décisions actées
> par Mathieu (`CAMPFIRE_WALK_RATE = 2.5`, tap existant conservé comme seul
> déclencheur, marqueur en pulse visuel seul). Base réelle de ce lot :
> `origin/staging` ne portait pas encore RECON 4 (`da4603f` vit sur la
> branche `claude/ch24-feu-interactif-recon-icucmq`, pas mergée) -- la
> branche d'implémentation attribuée à cette tâche était en réalité un clone
> de `main` sans même le LOT 1 (`tapped_campfire` absent au grep). Repartie
> depuis `da4603f` après vérification par ARBRE (`merge-base --is-ancestor`),
> plutôt que codée en aveugle sur la prémisse du brief.

## 1. Vitesse

`CAMPFIRE_WALK_RATE = 2.5` ajoutée en `const` dédiée à côté de
`BEAR_WALK_RATE`, et écrite sur `_badger.walk_rate` UNIQUEMENT (jamais
`walk_speed`, jamais `_bear`), dans `_setup_zipline()`, **avant**
`_world.add_child(_badger)` -- même règle que `_bear.walk_rate =
BEAR_WALK_RATE` juste au-dessus dans le fichier, et pour la même raison
structurelle : `HubActorWalker._ready()` lit `walk_rate` dans
`AnimationPlayer.speed_scale` UNE SEULE FOIS ; l'écrire après coup
accélérerait les pieds (`ground_speed()` relit `walk_rate` à chaque frame)
sans accélérer le clip -- glissement de pied, exactement ce que le knob
partagé existe pour empêcher.

Vérifié avant d'écrire, pas supposé : `walk_to()` n'est appelé sur `_badger`
nulle part ailleurs que dans le détour du feu (grep sur `scripts/hub/*.gd`,
deux occurrences, toutes deux dans `_on_tapped_campfire`). Il n'y a donc
**aucune valeur à restaurer au retour** -- la clause conditionnelle du brief
("si `walk_rate` est réutilisé ailleurs") ne s'applique pas : c'est la seule
vitesse de marche que le blaireau ait jamais eue, posée une fois à sa
construction plutôt que basculée à l'aller et au retour. `_bear` non touché.

## 2. Rotation au retour

Dans `_on_tapped_campfire()`, branche `&"at_fire"` : le point `home` est
maintenant calculé d'abord, puis `_badger.face(home - _badger.global_position)`
est appelé explicitement AVANT `_badger.walk_to(home)`. Le cap visé est la
direction RÉELLE (mesurée sur la position courante du blaireau), pas un
relèvement deviné -- exact pour les deux bouts, donc le cas "retour vers
l'autre bout" (30,6° mesuré par RECON 4, déjà imperceptible) reçoit le même
traitement instantané et n'est pas dégradé : `face()` pose exactement le cap
que `_process()` aurait calculé de toute façon pour un trajet en ligne
droite, l'appel ne fait qu'éliminer le retard de `lerp_angle` sur le cas à
180°.

## 3. Marqueur de proximité

Confirmation du composant : **`CabinMarker`**, pas `HubPortal`. `HubPortal`
est une scène `Area3D` autonome (signal + collision propre), utilisée par
les 3 vrais portails du hub et par rien d'autre côté tap -- l'instancier ici
aurait ajouté un SECOND mécanisme de déclenchement en parallèle du canal
`tapped_campfire`/`_tap.campfire_points` déjà câblé (LOT 1), sur le même
patron array-based que les portes de cabane. `CabinMarker` est le `Node3D`
purement visuel (pad + anneau + `Label3D` optionnel, aucun signal, aucune
collision) déjà utilisé en `Surface.HUB_GRASS` pour le marqueur de porte de
cabane -- exactement le composant que RECON 4 désignait.

Instancié dans `_setup_campfire()`, juste après le câblage du canal de tap :
position = `_campfire_point` (le point de tap RÉEL, pas `HubCampfire.SITE`
-- même règle que la porte de cabane : le marqueur est dessiné AU point qu'il
marque, jamais à une position ou une taille inventées à côté), rayon =
`CAMPFIRE_TAP_RADIUS` (1,8), `Surface.HUB_GRASS` (encre ambre des 3
portails), texte vide (pas de `Label3D` créé -- "pulse visuel seul", rien de
plus).

Pulsé par une fonction DÉDIÉE, `_pulse_campfire_marker()`, appelée depuis
`_process()` à côté de `_pulse_cabin_markers()` -- **pas fusionnée** avec
elle ni ajoutée à `_cabin_markers` : `_pulse_cabin_markers()` lit
`CABIN_TAP_RADIUS` (1,30) en dur pour CHAQUE entrée de son tableau, un rayon
différent de `CAMPFIRE_TAP_RADIUS` (1,8) -- les y mélanger aurait fait
respirer le marqueur du feu à la mauvaise distance. Même hystérésis, mêmes
seuils `HubPortal.NEAR_FACTOR`/`NEAR_RELEASE`, juste réécrite au rayon du
feu plutôt que partagée à tort.

Le tap direct sur le prop 3D (canal `tapped_campfire`, LOT 1) est **conservé
tel quel** -- décision de Mathieu, actée dans le brief ("le tap reste le
déclencheur réel") : ce lot n'y touche pas, le marqueur n'ajoute qu'un pulse.

**Zéro `Control`, zéro `Button`, zéro HUD** -- confirmé en relisant le code
ajouté : `CabinMarker` est un `Node3D` (`MeshInstance3D`/`Label3D` enfants),
la clause Opus/HUD du brief ne s'applique pas.

## Validation statique

Toujours aucun binaire `godot4`/`godot` dans ce sandbox (`which` : rien,
comme RECON 3, CH23 lot 7 et LOT 1). `gdtoolkit` installé via `pip` pour ce
lot (absent du sandbox jusqu'ici) :

* `gdlint` : 102 problèmes après édition contre 100 avant (baseline) --
  différence de 2, toutes deux de la même catégorie `class-definitions-order`
  déjà omniprésente dans ce fichier avant tout changement de ce lot (100
  occurrences pré-existantes, convention du fichier que ce lot ne corrige
  pas -- hors scope). Aucune AUTRE catégorie de problème (retours multiples,
  ligne trop longue, fichier trop long, espace de fin) n'a bougé en nombre
  NI en contenu par rapport à la baseline -- vérifié par diff des deux
  sorties filtrées hors `class-definitions-order`, lignes strictement
  identiques une fois l'offset d'insertion pris en compte.
* `gdformat --diff` : le fichier entier diverge déjà du style par défaut de
  `gdformat` avant ce lot (un saut de ligne entre fonctions au lieu de deux,
  entre autres -- convention du projet, pas appliquée par ce lot). Le diff
  autour des trois zones éditées ne montre que cette même divergence
  cosmétique pré-existante, aucun problème de fond.
* Pas de sonde `.gd` ajoutée à `scripts/dev/` : sans binaire Godot, une
  sonde ajoutée ici n'aurait pu être ni passée au rouge ni au vert -- même
  raison que RECON 3, RECON 4 et le LOT 1. Reste en NEXT STEPS pour CI/device
  (rouge-avant-vert sur les trois comportements neufs : vitesse mesurable
  par chrono, absence de dos tourné au retour vers le bout 0, pulse du
  marqueur qui s'allume/s'éteint aux deux seuils).

## Statut

Implémentation livrée (code + doc), scope strictement limité aux 3 items de
RECON 4 : aucune constante partagée touchée hors `_badger.walk_rate`,
`_bear` intact, aucun `Control`/HUD, aucun changement à
`ground_footprints()` ni au déclenchement (tap conservé). Palier `staging`
poussé pour que la CI fasse la vérification build/sondes non faisable dans
ce sandbox.

# LOT 3 -- Rotation retour : le fix du LOT 2 était bon, le défaut n'en était pas un ; marqueur remis sur le foyer (4 septembre 2026)

⚠️ **Premier lot de ce chantier mesuré avec un VRAI binaire Godot dans le
sandbox.** Les lots précédents ont travaillé par lecture de code sur la foi
d'un « pas de Godot ici » jamais retesté. L'éditeur 4.3 se télécharge et
s'exécute : `Godot_v4.3-stable_linux.x86_64.zip`, **50 276 070 octets**
(exactement le `Content-Length` que CLAUDE.md publie -- vérifié avant
extraction, piège de la troncature silencieuse), import complet du projet en
~5 min, **38 `.scn`**, zéro `Cannot open file`. C'est ce qui a permis de
répondre au brief par une trace frame par frame au lieu d'une troisième
relecture du même diff.

## Sujet A -- rotation au retour : LE FIX DU LOT 2 EST CORRECT, ET LE DÉFAUT N'EN EST PAS UN

### Ce que le brief demandait de vérifier, et ce que la mesure a répondu

Le brief posait comme hypothèse première un recalcul par-frame qui
écraserait le `face()` du LOT 2. **L'hypothèse est vraie sur le mécanisme et
fausse sur la conséquence**, et c'est exactement le genre d'écart qu'une
relecture ne tranche pas.

`HubActorWalker._process()` **recalcule bien** le cap à chaque frame
(lignes 231-234 : `wanted = atan2(to_target.x, to_target.z)` →
`lerp_angle(_yaw, wanted, weight)` → `rotation.y = _yaw`). Mais ce recalcul
converge vers **le cap du déplacement**, c'est-à-dire vers la valeur même
que `face()` vient de poser : `_yaw == wanted` dès la première frame, donc
`lerp_angle` ne bouge pas. Un `face()` en amont **n'est pas écrasé** ici,
il est *confirmé*.

### La trace demandée, cas retour bout 0 (le pire cas, 180°)

`CampfireFacingProbe`, headless (transforms seulement -- surtout pas xvfb),
`--fixed-fps 60` **avant** le `--` :

```
BEFORE le tap :  rotation.y  -20.93   _yaw  -20.93  | cap requis +159.07  (err -180.00)
  [BLIND CHECK] l'écart AVANT vaut bien 180.00° -- sans lui, « il regarde
                la maison après » passerait gratuitement
AFTER le tap, MÊME frame, aucun _process encore exécuté :
                 rotation.y +159.07   _yaw +159.07  | err +0.00
frame  rotation.y     wanted     err
    1    +159.07    +159.07    +0.00
    2    +159.07    +159.07    +0.00
   ...        ...        ...      ...
   60    +159.07    +159.07    +0.00
PIRE écart de cap sur tout le retour tracé : 0.00° (frame 45)
```

**Qui fixe `rotation.y`, à quelle frame, avec quelle valeur** -- la réponse
noir sur blanc que le brief exigeait :

| instant | fonction | valeur écrite |
|---|---|---|
| frame N, dans le handler du tap | `HubActorWalker.face()` (appelé par `_on_tapped_campfire`, branche `at_fire`) | `_yaw` **et** `rotation.y` ← **+159,07°** |
| frame N+1 et suivantes | `HubActorWalker._process()` | `lerp_angle(159,07 ; 159,07 ; w)` = **+159,07°**, inchangé |

Aucune autre fonction n'écrit l'orientation du blaireau pendant ce trajet
(`grep` exhaustif sur `_badger` : `ZiplineDoor` ne fait que LIRE,
`_badger_follow_zipline` et `_zip_arrive` sont gardés derrière `_zip_trip`
non vide, et `_on_tapped_campfire` sort tôt dans ce cas).

### Alors pourquoi le device voit-il encore un dos ? PARCE QUE C'EST LA GÉOMÉTRIE

**PHASE D.** La caméra du hub ne tourne jamais (`HubCamera.OFFSET`
constante), sa direction de vue à plat est donc une propriété fixe du
plateau : mesurée **(−0,000 ; −1,000)**, soit plein −Z.

| trajet | cap | `dot` avec l'axe de vue | ce que le joueur voit |
|---|---|---|---|
| aller (tour → feu) | −20,93° | **−0,934** (159,1° d'écart) | il vient VERS la caméra → **face** |
| retour (feu → tour) | +159,07° | **+0,934** (20,9° d'écart) | il s'éloigne → **dos** |

Le retour part du feu (22,079 ; 25,611) vers la tour (28,958 ; 7,624) :
**19,23 u dont −17,99 en Z**. Il s'éloigne de la caméra à 20,9° de son axe
de vue. **Un personnage qui marche à l'opposé de la caméra montre son dos ;
c'est correct, et aucun réglage de rotation ne peut le changer.** Le vrai
défaut que RECON 4 avait identifié -- la fenêtre de 0,5 à 1 s où le corps
avançait pendant que le modèle finissait un demi-tour -- **a bien été fermé
par le LOT 2** : elle vaut 0,00° aujourd'hui.

⚠️ **AUCUN CODE DE ROTATION N'A DONC ÉTÉ TOUCHÉ PAR CE LOT**, et c'est le
résultat, pas un renoncement. Le brief interdisait de repatcher en aveugle
après un deuxième échec ; la mesure dit qu'il n'y a rien à patcher. Si le
souhait est de VOIR le blaireau de face au retour, c'est une décision de
mise en scène (faire demi-tour à l'arrivée, ou un trajet retour qui ne
s'aligne pas sur l'axe caméra), pas un correctif de `face()`.

### PHASE E -- le double dispatch tactile, écarté par mesure et non par raisonnement

`emulate_mouse_from_touch` est laissé à son défaut `true` (vérifié dans
`project.godot`), donc **un doigt réel produit DEUX événements** là où ce
sandbox n'en appelait qu'un -- le seul écart connu entre la sonde et le
device. Rejoué en tapant deux fois dans la même frame sur les deux jambes :
un seul trajet démarre à chaque fois (la machine à états retombe dans `_:`),
et le cap reste **+0,00°** d'erreur, stable sur 30 frames. Hypothèse fermée.

## Sujet B -- le marqueur était sur le point d'arrivée du blaireau, et le tap aussi

**Coordonnée fautive confirmée, et elle n'est pas celle du brief.** Le brief
annonçait `(20.90, 0, 23.44)` d'après RECON 4 ; la mesure donne
**(22,079 ; 25,611)** -- le site du feu a bougé au CH23 lot 7 et le chiffre
du brief est périmé. Le mécanisme, lui, est bien celui qu'il décrivait :

```
_campfire_point = site + side * (CAMPFIRE_STONE_RING_OUTER 1,529 + KEEPY_CLEARANCE 0,66)
```

soit **2,189 u du foyer** (19,900 ; 25,400) -- et le `CabinMarker` était
instancié sur `_campfire_point`. D'où l'anneau ambre décalé du foyer et
chevauchant le bord du cercle de pierres, exactement comme le screenshot.

⚠️ **PRÉMISSE DE BRIEF TOMBÉE, ET ELLE CHANGE LE CORRECTIF.** Le brief
demandait de ne changer que l'instanciation du marqueur, « la même référence
que le tap 3D `tapped_campfire` lui-même ». **Il n'existe pas de tap 3D sur
le prop** : `HubTapInput` (l. 404-408) ne teste qu'un **disque plat** autour
de `campfire_points`, et ce tableau ne contenait que `_campfire_point`.
Conséquence mesurée : avec `CAMPFIRE_TAP_RADIUS = 1,8` et un foyer à
2,189 u du centre du disque, **taper sur le feu ne déclenchait rien** -- il
fallait taper la pelouse à côté. Déplacer le seul marqueur aurait donc
produit pire : un anneau visible dont le centre n'est pas tappable.

Correctif appliqué, les deux points restant logiquement distincts :

* `_campfire_marker.position = site` -- l'anneau est dessiné **sur le
  foyer**, la chose que le joueur est invité à toucher ;
* `campfire_points = [site, _campfire_point]` -- le foyer est **ajouté** et
  non substitué, parce que le disque autour du point d'arrivée est aussi
  celui qui couvre le blaireau une fois assis : le retirer supprimerait
  « taper le blaireau pour le renvoyer ». `HubTapInput` boucle déjà sur ce
  tableau, `Array` dès son premier commit ;
* `_campfire_point` garde son unique rôle -- **où le blaireau se tient** --
  et n'est plus relu par quoi que ce soit de visuel ;
* **`CAMPFIRE_TAP_RADIUS` (1,8) et `CAMPFIRE_WALK_RATE` (2,5) intacts**,
  conformément au hors-scope.

**ROUGE AVANT VERT, acquis sans neutralisation** : PHASE C a été mesurée
**FAIL à 2,189 u du foyer** sur l'arbre d'origine, avant tout patch, puis
**OK à 0,000 u** après. L'assertion a échoué sur le code réel avant de
réussir sur le code corrigé.

## Sonde livrée

`scripts/dev/CampfireFacingProbe.{gd,tscn}` -- **conservée**, pas jetable :
elle gate deux contrats permanents que rien d'autre ne défend (« le blaireau
ne marche jamais de travers en rentrant », « l'anneau est dessiné sur le
feu ») et porte le blind check qui empêche le premier de passer gratuitement.
`ProbeTimeoutAudit` la voit et **PASSE** (65 scènes de sonde, `arm()` +
`deadline()`).
