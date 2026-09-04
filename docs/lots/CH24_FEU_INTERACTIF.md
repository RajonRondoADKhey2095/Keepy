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

## Statut

Recon uniquement. Aucun code de jeu modifié. Ce fichier est le seul livrable
de cette session, avec le rapport de fin de tâche.
