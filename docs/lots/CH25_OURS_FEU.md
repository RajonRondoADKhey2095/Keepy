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

## LOT 1 — implémentation

Branche `claude/bear-campfire-sync-js1zzj`, repartie de `origin/main`
(`da5035f`, le dernier merge palier 2 -- CH24 interactif). Reprend le
découpage de la recon point par point ; rien n'a été pris pour acquis sans
être rejoué.

### Reprouvé indépendamment (RECON 4/5, avant tout code)

Script Python hors moteur (aucun binaire `godot4`/`godot` dans ce sandbox,
même constat que la recon et que CH24 -- `which`/`find /` : rien), écrit
sans lire le script de la recon, seulement ses constantes publiées et la
géométrie déjà dans le dépôt (`hub_layout.tres`, `HubBuilder._build_zipline_
tower`, `HubCampfire.SITE`).

- **Relèvement direct `BEAR_REST → SITE` (149,76°) : RECONFIRMÉ MAUVAIS.**
  Segment complet contre TOUT le fichier de props (213 entrées, aucune
  restriction à une boîte -- plus large que la recon, qui bornait à
  x∈[-4,26] z∈[20,40]) : pire dégagement décor 0,2125 u contre l'arbre
  échelle 0,719 à (6,643 ; 32,682), sous `KEEPY_CLEARANCE` (0,66).
  ⚠️ **Le chiffre diffère de celui de la recon (0,385 u) sans se
  contredire** : 0,2125 + le rayon PROPRE de cet arbre à cette échelle
  (`FOOTPRINT_RADIUS[&"tree"]` 0,24 × 0,719 = 0,1726) = 0,3851 -- la recon
  a mesuré la distance au CENTRE du prop, ce lot mesure la distance à sa
  SURFACE (centre moins son propre rayon). Les deux méthodes condamnent le
  même candidat pour la même raison ; celle de ce lot est la plus
  conservatrice des deux.
- ⚠️ **Correction d'une affirmation reprise sans vérification par la
  recon** (et par le commentaire déjà présent dans `_setup_campfire()`
  pour le blaireau) : « les props décoratifs batchés n'ont AUCUNE entrée
  dans `HubBuilder.FOOTPRINT_RADIUS` ». Faux, vérifié par lecture directe
  du dict (`&"tree": 0.24, &"rock": 0.44, &"bush": 0.71, &"flower": 0.22,
  &"stump": 0.44`) : ces entrées EXISTENT. Ce qui est vrai, et qui est tout
  ce que la conclusion utilisée nécessitait, c'est que `HubActorWalker`
  (grep exhaustif) n'appelle jamais `ground_footprints()` -- seul
  `KeepyHopper` (atterrissage de saut) le fait. Un acteur qui MARCHE en
  continu ne consulte donc aucun de ces rayons, quels qu'ils soient ; c'est
  la raison structurelle, pas une case vide dans un dictionnaire qui, en
  fait, ne l'est pas. Sans conséquence sur le candidat retenu (même rayon
  utilisé comme proxy des deux côtés), mais un chiffre à ne plus recopier.
- **Balayage 3600 pas, indépendant, rejoué sur les 213 props (pas une
  boîte) : bande valide 45,7°-116,4°** (la recon, restreinte à sa propre
  boîte de 13 props, trouvait 45,7°-130,2° -- même borne basse, borne haute
  différente parce qu'un prop hors de sa boîte referme le haut de la bande
  dans ce script-ci ; les deux bandes contiennent largement le candidat
  retenu, donc la conclusion ne dépend pas de laquelle est exacte).
  **Meilleur point par marge, indépendamment retrouvé identique à celui de
  la recon** : azimut 65,20°, **(20,818 ; 27,387)**. Marge décor (surface)
  0,9628 u (même arbre, même réconciliation de méthode que ci-dessus :
  0,9628 + 0,1726 = 1,1354 ≈ 1,135 u publié par la recon), séparation
  (corde) avec le point du blaireau 2,1779 u. **Deux sweeps indépendants,
  deux méthodes de mesure de marge légèrement différentes, un seul et même
  point gagnant** -- c'est ce qui rend ce point committable plutôt que
  coïncident. `BEAR_CAMPFIRE_AZIMUTH_DEG = 65.2` et `_bear_campfire_point`
  livrés dans `HubWorld.gd`.
- **`BEAR_CAMPFIRE_WALK_RATE` calculé, pas choisi** : distance aller du
  blaireau (`_badger_rest(0)` → `_campfire_point`) 19,2577 u à
  `CAMPFIRE_WALK_RATE` 2,5 → 10,1947 s de trajet. Distance aller de l'ours
  (`BEAR_REST` → `_bear_campfire_point`) 22,9304 u ; le taux qui couvre
  cette distance dans le même temps est 2,9768 -- sous le plafond 3,0 déjà
  vérifié pour ce même mécanisme (le taux du blaireau lui-même, dont 3,0
  était le plafond testé et refusé pour être trop rapide). Écart résiduel
  mesuré en le rejouant : 0,0001 s -- gaté par un `assert()` dans
  `_setup_campfire()` (seuil 1,0 s), pas seulement documenté.

### Le piège de glissement de pieds -- trouvé, pas contourné

`HubActorWalker._ready()` ne lit `walk_rate` qu'UNE fois pour fixer
`AnimationPlayer.speed_scale` ; `ground_speed()` le relit à CHAQUE frame
pour la position. Tant qu'un acteur n'a jamais qu'un seul taux pour toute
sa vie (blaireau: `CAMPFIRE_WALK_RATE` seul ; ours jusqu'ici:
`BEAR_WALK_RATE` seul), cette asymétrie ne se voit jamais. L'ours de ce
lot est le PREMIER acteur à avoir deux taux légitimes (le sien pour la
balançoire, un dédié pour le feu) : écrire `BEAR_CAMPFIRE_WALK_RATE` sur
`_bear.walk_rate` avant son `walk_to()` du feu, SANS toucher le script
générique, aurait déplacé le CORPS au nouveau taux en laissant le CLIP
jouer à l'ancien -- exactement le glissement de pieds que le commentaire
de `CAMPFIRE_WALK_RATE` (CH24) décrit déjà en théorie sans que rien, avant
ce lot, ne l'ait jamais déclenché en pratique.

Corrigé À LA RACINE plutôt que contourné dans `HubWorld.gd` : `HubActor
Walker.walk_to()` réapplique désormais `speed_scale` depuis `walk_rate`
à CHAQUE appel (une ligne), pas seulement dans `_ready()`. No-op pour
tout appelant à taux unique déjà shippé (blaireau, et l'approche
balançoire de l'ours elle-même) -- vérifié par lecture, aucun des deux ne
change jamais `walk_rate` après l'avoir posé une fois, donc cette
réapplication réécrit chaque fois la MÊME valeur. C'est la correction
générique demandée par le brief plutôt qu'un contournement local : un
troisième acteur à taux multiples futur en bénéficie sans rien écrire.

### Découpage livré

1. **Gate balançoire, DANS LES DEUX SENS** -- `_on_seesaw_mounted()` refuse
   (patron bateau, retrait actif écrit à la main, aucune porte façon
   `ZiplineDoor`) tant que `_bear_campfire_leg != &""`, exactement comme
   demandé. **Trouvé en écrivant ce gate, pas anticipé par la recon** : le
   sens INVERSE n'était pas fermé -- rien n'empêchait un tap sur le feu de
   détourner un ours DÉJÀ assis sur la planche, et `_apply_tilt()` continue
   d'appeler `_bear_follow_seesaw()` à chaque tic de bascule tant que
   `_bear_pivot` reste non-null, ce qui aurait combattu l'écriture de
   position du `walk_to()` du feu sur le MÊME nœud -- un tic replaçant
   l'ours sur son siège, l'autre essayant de l'en faire sortir. Fermé par
   `_evict_bear_from_seesaw()`, factorisée hors de `_on_seesaw_dismounted()`
   (même nettoyage, sans le walk-to-home qui ne convient qu'au vrai
   débarquement de Keepy) et appelée en tête du départ de l'ours dans
   `_on_tapped_campfire`.
2. **État de l'ours** -- `_bear_campfire_leg` (mêmes quatre valeurs que le
   blaireau), `_bear_campfire_point` (calculé une fois dans
   `_setup_campfire()`, gaté par l'assert de synchronisation ci-dessus).
3. **Synchronisation par état partagé** -- `_campfire_guests`
   (`&""`/`&"transit"`/`&"out"`), lu par `_on_tapped_campfire` et LUI SEUL ;
   `_badger_campfire_leg`/`_bear_campfire_leg` restent chacun la propriété
   de leur propre gestionnaire d'arrivée (`_on_badger_arrived`/
   `_on_bear_campfire_arrived`, ce dernier appelé en tête de
   `_on_bear_arrived`), qui ne font qu'annoncer leur propre progression à
   `_maybe_advance_campfire_guests()`. **Décision explicite sur le cas
   vitesses asynchrones** : un retap n'est accepté que lorsque les DEUX
   invités sont effectivement `at_fire` (`_campfire_guests` ne passe à
   `&"out"` qu'à ce moment-là, jamais au premier des deux) ; un tap reçu
   pendant que l'un des deux marche encore (`&"transit"`) ne fait rien de
   nouveau -- même forme que le no-op déjà existant du blaireau seul sur un
   tap en cours de trajet. L'alternative (accepter dès le premier arrivé,
   ou interrompre le trajet en cours) a été écartée : la première
   réintroduit exactement le risque de désaccord entre deux drapeaux
   indépendants que cet état partagé existe pour fermer ; la seconde est le
   patron ÉCHELLE, banni.
   **Factorisation vs duplication, tranchée** : dupliqué plutôt que
   factorisé. Les deux acteurs partagent l'ÉTAT partagé (`_campfire_guests`)
   et le patron (mêmes quatre valeurs de jambe, même séquence face-puis-
   walk_to au retour), mais leurs corps de code restent deux blocs
   distincts dans `_on_tapped_campfire` et deux fonctions distinctes pour
   l'arrivée (`_on_badger_arrived` / `_on_bear_campfire_arrived`) plutôt
   qu'une fonction paramétrée par acteur : les deux acteurs divergent sur
   des détails non triviaux à chaque étape (le blaireau retire un CANAL DE
   TAP, l'ours n'en a pas et se contente d'un garde interne ; le blaireau
   revient vers l'une de DEUX tours selon `_badger_campfire_return_end`,
   l'ours revient toujours vers `BEAR_REST` seul ; le blaireau ne touche
   jamais `walk_rate`, l'ours en change deux fois par trajet). Une fonction
   générique aurait dû prendre en paramètre au moins six valeurs
   différentes (canal à retirer ou non, destination retour à un ou deux
   choix, taux à écrire ou non...) pour un gain de lignes marginal --
   exactement le genre de paramétrage qui rend une fonction plus dure à
   lire que les deux blocs qu'elle remplace. Dupliqué, donc, sur le PATRON
   -- jamais sur l'ÉTAT, qui reste la seule chose que ce lot devait unifier.
4. **`turn_to()` au retour** -- `_bear.face(BEAR_REST - _bear.global_
   position)` avant le `walk_to()` retour (empêche la marche arrière
   perçue le temps que l'ease rattrape, même défaut que LOT 3/4 CH24 sur
   le blaireau) et `_bear.turn_to(_bear_rest_facing)` après l'arrivée
   (corrige l'écart de face mesuré par la recon, -59,76° à -65,21° selon
   le candidat -- non re-rendu ici, `HubActorWalker.turn_to()` est déjà
   générique et gaté par CH24 LOT 4, aucun nouveau code de lissage écrit).
   Le départ (`to_fire`) n'a PAS reçu de `face()` explicite avant son
   `walk_to()`, sur le même précédent que l'aller du blaireau (jamais
   pré-orienté non plus) -- signalé, non confirmé par rendu, à vérifier
   sur device en priorité si le départ lit comme une marche arrière.
5. **Vérification géométrique** -- voir la section "Reprouvé
   indépendamment" ci-dessus. Aucun binaire Godot dans ce sandbox (même
   constat que la recon) : calcul analytique seul, aucune sonde rouge-
   avant-vert exécutée dans le moteur. Le "rouge avant vert" a néanmoins
   été appliqué à l'outil de mesure lui-même : le script de ce lot a
   d'abord été vérifié capable de FAIRE ÉCHOUER le candidat par relèvement
   direct (0,2125 u < 0,66, rouge) avant d'être cru sur le candidat retenu
   (0,9628 u > 0,66, vert) -- l'équivalent, hors moteur, du blind check que
   ce dépôt exige de toute assertion d'absence/égalité.

### Fichiers touchés

- `scripts/hub/HubWorld.gd` -- constantes `BEAR_CAMPFIRE_WALK_RATE`,
  `BEAR_CAMPFIRE_AZIMUTH_DEG` ; champs `_bear_campfire_point`,
  `_bear_campfire_leg`, `_campfire_guests` ; `_setup_campfire()` étendu
  (point/disc de l'ours, assert de synchronisation) ; `_on_seesaw_mounted()`
  gaté ; `_on_tapped_campfire()` réécrit sur l'état partagé ;
  `_on_badger_arrived()` inchangé sur le fond, annonce sa progression au
  nouvel arbitre ; `_on_bear_arrived()` délègue en tête à la nouvelle
  `_on_bear_campfire_arrived()` ; nouvelle `_maybe_advance_campfire_guests()` ;
  nouvelle `_evict_bear_from_seesaw()`, factorisée hors de
  `_on_seesaw_dismounted()` (comportement inchangé pour ce dernier) et
  réutilisée par `_on_tapped_campfire()` pour le cas trouvé ci-dessus.
- `scripts/hub/HubActorWalker.gd` -- `walk_to()` réapplique `speed_scale`
  depuis `walk_rate` à chaque appel (correctif générique, voir section
  dédiée ci-dessus).
- `docs/lots/CH25_OURS_FEU.md` (ce fichier), `docs/lots/INDEX.md`,
  `CLAUDE.md` -- lignes d'index mises à jour en additif.

### Hors scope, non touché

Blaireau (CH24) : logique interne inchangée, seul son point d'ancrage dans
`_on_tapped_campfire`/`_on_badger_arrived` a été adapté pour annoncer sa
progression à l'état partagé -- strict nécessaire au câblage commun,
comme demandé. Dette CH23 (emprise du feu), `INDEX.md` CH24 périmé :
toujours hors scope.

### NEXT STEPS

- **Test device obligatoire avant tout merge `main`**, comme pour CH24 :
  aucun rendu n'a validé (a) que le départ de l'ours sans `face()`
  explicite ne lit pas comme une marche de travers, (b) que la marge
  décor de 0,9628 u au point retenu est réellement suffisante à l'écran
  (silhouette, pas seulement dégagement de marche -- ce moteur ne bloque
  aucun des deux), (c) que le taux 2,9768 ne produit aucun glissement de
  pieds résiduel visible malgré le correctif générique (le correctif
  ferme l'écart de PRINCIPE ; seul un rendu confirme qu'aucun autre
  chemin ne l'a réintroduit).
- Si un binaire Godot devient disponible dans une session future : sonde
  headless reprenant RECON 4/5 en moteur (segment complet, pas
  l'extrémité seule), rouge-avant-vert sur l'assert de synchronisation et
  sur le gate balançoire (neutraliser `_bear_campfire_leg != &""`,
  vérifier que la sonde le voit, restaurer byte-identique).
