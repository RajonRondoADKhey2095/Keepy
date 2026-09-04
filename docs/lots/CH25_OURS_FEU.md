# CH25 — Feu de camp : l'ours rejoint le blaireau

> Stub créé en RECON PURE (4 septembre 2026), avant tout lot d'implémentation.
> Numéro proposé par ordre (CH24 est le dernier chantier existant au moment de
> cette session). Aucune ligne de code de jeu écrite par cette session ; le
> contenu ci-dessous est la recon complète, à reprendre telle quelle par le
> premier lot d'implémentation. Branche `claude/bear-campfire-recon-8ezmi0`,
> repartie de `origin/main` (arbre identique, vérifié par `git rev-parse
> ^{tree}` avant toute lecture — pas de session concurrente détectée).

## Contexte

CH24 a livré le canal `tapped_campfire` et l'aller-retour du blaireau au feu
(patron bateau, retrait actif de `tapped_zipline_badger` via
`ZiplineDoor.set_badger_at()`). Objectif de ce chantier : faire venir l'ours
(CH20, balançoire) AU MÊME MOMENT, sur le MÊME tap, avec le même
aller-retour — en réutilisant au maximum le patron déjà prouvé.

## RECON 1 — Script/scène de l'ours

**L'ours EST déjà un `HubActorWalker`.** `HubWorld._setup_bear()` :
`_bear = HubActorWalker.new()`, avec `model_scene = BEAR_SCENE`, `model_scale
= BEAR_SCALE`, `walk_rate = BEAR_WALK_RATE`. C'est la MÊME classe que le
blaireau. `walk_to()` / `turn_to()` sont donc directement réutilisables,
sans migration ni duplication.

Position de repos : `const BEAR_REST: Vector3 = Vector3(0.0, 0.0, 37.0)`
(monde). ⚠️ **Aucun accesseur équivalent à `_badger_facing(index)` n'existe,
et c'est structurel, pas un oubli** : le blaireau a deux tours (d'où
l'`index`), l'ours a une seule balançoire et une seule position de repos —
`BEAR_REST` est une constante, et `_bear_rest_facing` (Vector3, calculée une
fois dans `_setup_bear()` à partir du fulcrum de la balançoire
`Vector3(0,0,38.5)`) en tient lieu. Un troisième acteur qui réutiliserait ce
patron devrait décider s'il ajoute un paramètre d'index ou reste sur une
paire constante+variable, cette recon ne tranche pas.

## RECON 2 — Animations disponibles

**Aucun écart.** Le rig de l'ours porte `Walking` ET `Running`, comme celui
du blaireau — déjà mesuré CH21 RECON 3 ("les mêmes deux, mêmes durées, mêmes
72 canaux") et confirmé ici par lecture de `HubActorWalker._ready()` (qui
`push_error` si `walk_anim` — par défaut `&"Walking"` — est absent du rig ;
aucun tel push_error n'existe pour l'ours dans le code actuel, et
`_bear.walk_to()` est déjà utilisé pour l'approche de la balançoire depuis
CH20). Le mécanisme `_freeze()` (frame 0 de `Walking`, boucle arrêtée) est
générique sur `HubActorWalker` et DÉJÀ utilisé par l'ours à chaque arrivée
(`_arrive()`). **Pas de transposition à faire, l'ours a déjà tout ce que le
blaireau a sur cet axe.**

## RECON 3 — Gate de la balançoire pendant le détour

**Le mécanisme à gater existe, mais n'a pas la même forme que celui du
blaireau — pas de canal de tap à retirer, il n'y en a pas.**

La balançoire n'a AUCUN canal `HubTapInput` dédié (grep exhaustif de
`HubTapInput.gd` : 7 signaux, aucun `tapped_seesaw`). Le montage est
**déclenché par l'atterrissage** : `HubWorld._on_seesaw_mounted()` répond au
signal `seesaw_mounted` (émis par `KeepyHopper.mount_seesaw()`), trouve le
plot sous Keepy (`_seesaw_under()`), et appelle **inconditionnellement**
`_bear.walk_to(...)` vers l'extrémité opposée de la planche — sans aucun
test de ce que l'ours est en train de faire ailleurs.

⚠️ **Défaut confirmé par lecture directe du code (lignes 1399-1432) : si
l'ours est en visite au feu (ou en chemin, dans un sens ou l'autre) au
moment où Keepy monte sur la balançoire, `_on_seesaw_mounted()` détourne
l'ours de son trajet campfire sans préavis** — `_bear_pending` serait
réécrit, l'ours abandonnerait sa marche vers/depuis le feu en plein
segment, et l'état de détour (qu'il faudra créer, symétrique de
`_badger_campfire_leg`) resterait bloqué sur une valeur jamais nettoyée
(aucun code actuel ne le fait, puisque l'ours n'a aujourd'hui aucune
notion de détour).

**Pas de gate générique réutilisable.** `ZiplineDoor.set_badger_at()`
retire un CANAL DE TAP (`accepts_boarding_tap()` répond faux), un mécanisme
qui n'a de sens que parce que le blaireau a un canal de tap à retirer. La
balançoire n'a pas ce canal — ce qu'il faut gater est un APPEL INTERNE
(`_on_seesaw_mounted()` → `_bear.walk_to()`), pas une réponse à un tap.
Revue des quatre autres patrons d'acteur/prop du fichier (`mooring`,
`owl_available`, `cabin` sans retrait, `ZiplineDoor`) : **chacun a sa
propre implémentation ad hoc**, aucune abstraction partagée
("actor away → disable my interaction") n'existe dans ce dépôt. Le lot
d'implémentation devra donc écrire son propre garde, probablement une
condition sur un futur `_bear_campfire_leg != &""` au sommet de
`_on_seesaw_mounted()` (et de tout autre point qui touche `_bear_pending`/
`_bear_pivot`), sur le modèle du blaireau mais sans code à réutiliser tel
quel.

## RECON 4 — Point d'arrivée de l'ours au feu

Calcul À LA MAIN à partir des constantes du code et de `hub_layout.tres`,
**non re-mesuré en moteur** (aucun binaire `godot4`/`godot` dans ce sandbox
— `which`, `find /` : rien, même constat que CH23 lot 7 et CH24). Contrôle
analytique en Python, hors moteur, reproductible mais pas un substitut à une
sonde Godot gatée.

Constantes utilisées : `HubCampfire.SITE` = (19,9 ; 25,4), bord extérieur
pire cas de l'anneau `CAMPFIRE_STONE_RING_OUTER` = 1,529 u,
`KEEPY_CLEARANCE` = 0,66, rayon d'arrivée `R` = 2,189 u (même construction
que le blaireau). `BEAR_REST` = (0 ; 37). Point d'arrivée du blaireau déjà
livré (CH24 LOT 1) : **(22,079 ; 25,611)**.

**Le relèvement direct `BEAR_REST → SITE` (bearing ≈ -30,24°, candidat à
(18,009 ; 26,502)) N'EST PAS PROPRE**, contrairement à l'hypothèse "la
recon n'a qu'à prendre le relèvement direct" : rejoué sur le SEGMENT
complet `BEAR_REST → candidat` (pas seulement l'extrémité — leçon CH24 LOT
1) contre les 13 props de `hub_layout.tres` situés dans le corridor
(bounding box x∈[-4,26], z∈[20,40]), un **arbre à (6,643 ; 32,682) ne
dégage le trajet que de 0,385 u** — sous `KEEPY_CLEARANCE` (0,66), un
croisement quasi certain. La distance à l'anneau de pierres elle-même reste
correcte par construction (le segment approche le site de façon monotone
sur ce relèvement, donc aucun risque d'anneau côté ligne droite), mais
l'arbre est un vrai défaut, du même genre que celui que CH24 LOT 1 avait
trouvé sur le retour du blaireau — juste sur un axe différent (décor plutôt
qu'anneau).

**Balayage numérique** (script Python hors moteur, 3600 pas d'azimut,
rayon fixe 2,189 u autour du site, faute de binaire Godot — même méthode que
CH24 LOT 1) : parmi les candidats qui (a) gardent le SEGMENT complet
`BEAR_REST → candidat` à ≥ 1,529 u du site en tout point, (b) gardent ≥ 0,66
u de marge sur les 13 props du corridor, et (c) restent à ≥ 1,5 u (corde) du
point d'arrivée déjà livré du blaireau (22,079 ; 25,611) — une bande valide
existe, **45,7° à 130,2°** (azimut site-centrique depuis +X). Le relèvement
direct (149,76°) est HORS de cette bande, ce qui confirme le défaut trouvé
ci-dessus.

**Candidat proposé, NON TRANCHÉ** : le meilleur point de la bande par marge
décor, **(20,818 ; 27,387)** — azimut 65,2°, marge décor 1,135 u, séparation
du point du blaireau 2,178 u (corde). À reprouver par sonde/rendu avant tout
merge ; les props décoratifs batchés (rocher/arbre/buisson/souche/fleur)
n'ont toujours aucune entrée dans `HubBuilder.FOOTPRINT_RADIUS` (même dette
que CH24), donc le croisement de SILHOUETTE (par opposition à un blocage de
marche, qui n'existe pas dans ce moteur pour ces props) n'a pas pu être
confirmé par rendu ici.

## RECON 5 — Géométrie caméra au retour (leçon CH24 LOT 3)

`HubCamera` ne tourne jamais et ne zoome jamais (`OFFSET` constant,
doctrine déjà établie) — la "géométrie caméra" en jeu ici est en réalité une
question de LISIBILITÉ DE LA FACE, la même classe de défaut que CH24 LOT
3/4 a corrigée pour le blaireau (`turn_to()` après arrivée, `face()` explicite
avant `walk_to()` au départ), **pas un problème de caméra au sens propre**.

Calcul (yaw au format `atan2(direction.x, direction.z)`, celui de
`HubActorWalker`) : face de repos canonique de l'ours,
`_bear_rest_facing` = direction `BEAR_REST → fulcrum(0,0,38.5)` = **0°**
(face au +Z, vers la balançoire).

Pour les deux candidats calculés en RECON 4 :

| candidat | yaw départ (aller) | yaw trajet retour (= face à l'arrivée, sans correction) | écart vs face de repos canonique |
|---|---|---|---|
| relèvement direct (18,009 ; 26,502) | 120,24° | -59,76° | **-59,76°** |
| meilleur candidat balayage (20,818 ; 27,387) | 114,79° | -65,21° | **-65,21°** |

**Un problème existe, mais ce n'est PAS automatiquement le même correctif
transposé tel quel.** Le blaireau avait DEUX cas : un retour au même tour
(écart ~180°, pire cas) et un retour à l'autre tour (30,6°, jugé "quasi
imperceptible" par la doctrine du dépôt — CH24 lui-même cite ce chiffre
comme seuil de référence). L'écart mesuré ici pour l'ours (~60-65°) est
**plus du double du cas "imperceptible" du blaireau**, donc probablement
visible sans correction — mais il n'atteint ni le pire cas à 180° ni n'a été
confirmé par rendu. Le lot d'implémentation devra vraisemblablement ajouter
un `_bear.turn_to(_bear_rest_facing)` après l'arrivée du trajet retour, sur
le PATRON du blaireau (`turn_to()` post-arrivée) — mais ce n'est pas prouvé
ici, seulement chiffré. Le départ (yaw ~115-120° depuis la face de repos à
0°) est un écart plus modeste que le pire cas blaireau (180°) qui avait
justifié le `face()` explicite avant `walk_to()` ; signalé comme item
secondaire, non tranché, à confirmer par rendu plutôt que supposé
nécessaire ou inutile.

## Découpage proposé pour le lot d'implémentation (à discuter, pas décidé)

1. Ajouter l'état de détour de l'ours, symétrique de `_badger_campfire_leg`
   (`_bear_campfire_leg: StringName`), et le point d'arrivée
   `_bear_campfire_point` (calculé comme en RECON 4, valeur à reprouver par
   sonde avant de figer le candidat (20,818 ; 27,387)).
2. Gater `_on_seesaw_mounted()` (et tout autre point touchant
   `_bear_pending`/`_bear_pivot`) sur `_bear_campfire_leg != &""` — écrit à
   la main, aucun `ZiplineDoor`-like réutilisable (RECON 3).
3. Câbler `_on_tapped_campfire` pour piloter les DEUX acteurs sur le même
   tap : la structure `match _badger_campfire_leg` existante peut se
   dupliquer pour l'ours, ou se refactorer en une fonction générique
   paramétrée par acteur — à trancher par le lot, pas cette recon.
4. `_bear.face(home - _bear.global_position)` avant `walk_to()` au retour
   (patron blaireau) et `_bear.turn_to(_bear_rest_facing)` après arrivée au
   repos (RECON 5) — à confirmer/mesurer plutôt qu'à copier aveuglément.
5. Sonde de reprise du calcul RECON 4 (segment complet, pas l'extrémité
   seule) une fois un binaire Godot disponible ; rouge-avant-vert sur toute
   assertion nouvelle, blind check si absence/égalité testée.
6. Décision Mathieu implicite déjà actée par le brief : même tap, même
   patron bateau (jamais patron échelle), aller-retour synchronisé — cette
   recon ne rouvre pas ces points.

## Statut de la recon

Recon uniquement. Aucun code de jeu modifié par cette session — seul ce
fichier et les deux tables d'index (`CLAUDE.md`, `docs/lots/INDEX.md`) sont
touchés. Le lot d'implémentation qui suit reprend ce découpage tel quel.
