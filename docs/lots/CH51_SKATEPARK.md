# CH51 — Skatepark du lobe nord : RECON + CONCEPTION

**Lot A, 8 septembre 2026.** Aucun asset importé, aucun module placé,
aucune mécanique implémentée, aucun fichier de gameplay modifié. Ce
fichier est le livrable : un plan, un arbitrage chiffré à remonter, et
la liste de ce qui reste à mesurer avant qu'une seule ligne de gameplay
soit écrite.

---

## 0. LA BASE — et une prémisse de brief qui est tombée à la lecture

Le brief situe le lot « après le lot CH50 » (disque centre (0, 35),
R = 28, sol marchable jusqu'à z = 63). **CH50 est réel et vérifié**
(`HubRegion.SKATE_LOBE_RADIUS = 28.0`, `skate_lobe_centre()`,
`SkateGroundProbe`) — mais il vit sur `origin/staging`, **pas sur
`main`**, et la branche de ce lot avait été ouverte sur `main`
(`2876f27`), c'est-à-dire sur un hub dont le lobe nord vaut encore
**R = 12** et s'arrête à z = 47.

Corrigé avant toute lecture de géométrie : `git merge --ff-only
origin/staging` (fast-forward propre, `HEAD` était ancêtre). **Tout lot
de suite part de `staging`, jamais de `main`.**

**Garde de concurrence, faite AU DÉBUT et par ARBRE.** Deux branches
distantes portent un nom voisin du sujet :

| ref | verdict |
|---|---|
| `origin/claude/lot-zone0-nord-skatepark-ezbguf` | `merge-base --is-ancestor` → **déjà mergée** dans `staging` (c'est CH50) |
| `origin/claude/overlay-dev-staging-default-o97z0y` | même **arbre** que `staging` (`77fccf8…`) → **déjà mergée** |

Aucune session concurrente vivante sur ce sujet.

---

## 1. L'EXISTANT — lu, pas supposé

### 1.1 Les compteurs noisettes/glands

**Un seul écrivain, un seul point d'entrée.**

* `scripts/autoload/WorldSave.gd:125` — `add_resource(kind, amount)` est
  la **seule** fonction qui bouge un compteur. Elle écrit
  `_data["resources"][kind]`, incrémente `stats.picked`, marque le
  fichier sale (flush débouncé 0,4 s) et émet
  `resources_changed(kind, total, delta)`.
* **Deux appelants dans tout le jeu**, hors sondes :
  * `scripts/hub/HubNuts.gd:473` — `+1`, dans le callback de fin du tween
    de ramassage (la noisette vole vers la poitrine, PUIS le compteur) ;
  * `scripts/hub/HubBeaver.gd:203` — `−PRICE[kind]`, le troc du castor.
* `WorldSave.KINDS` = `acorn, hazelnut, ladybug, golden, truffle, flower`.
* `scripts/hub/WorldHud.gd` lit `WorldSave` **et rien d'autre**, se
  réveille sur `resources_changed`, s'estompe à `GHOST_ALPHA` après 4 s.
  Les rares n'apparaissent qu'une fois détenus (`APPEARS_WHEN_HELD`).

**Aucun gate.** `add_resource` n'a ni plafond, ni cooldown, ni notion de
source. Un lot qui l'appelle en boucle inflate le compteur sans qu'aucun
garde-fou existant s'y oppose.

**Les stats persistantes passent par `WorldSave.note(key)`**, refusée si
la clé n'est pas dans `STAT_KEYS` (`kart_laps`, `castles_built`,
`cove_visits`…). Ajouter une clé y est **additif, sans bump de schéma** —
`_sanitise` défausse ce qu'il ne connaît pas, `_defaults()` fournit le 0.

### 1.2 Les mini-jeux et interactions déjà présents

**Trois patrons distincts coexistent, et ils ne sont pas
interchangeables :**

| patron | exemplaire | ce qu'il est |
|---|---|---|
| **PORTAIL → changement de scène** | `HubPortal` + `HubRouter` (`chased`, `quizz`, `battle`, `cabin`) | une `Area3D` qui n'utilise **jamais** `body_entered` (un saut passe à travers en l'air) : elle répond à « cet **atterrissage** était-il dedans ? », question posée par `HubWorld` sur `hop_landed`, puis `HubConfirmDialog`, puis `HubRouter.route()` |
| **MODULE DE ZONE, dans le hub** | `HubKarting`, `HubCove`, `HubTransport`, `HubCritters` | un `Node3D` sous `World`, construit dans `_ready()`, câblé par `HubWorld.setup(...)`, publiant `footprints()` pour `CozyScatter`, **un** canal de tap, **un** hook d'atterrissage, **un** `cancel_intent()` |
| **RIDE BORNÉ** | plongeoir, tourniquet, balançoire, hibou, tyrolienne, arbre | un état de `KeepyHopper` (`enum State`, 12 valeurs), corps écrit le long d'une géométrie en espace LOCAL et relu par `to_global()` |

**Un mini-jeu à score qui reste dans le hub existe déjà : le karting.**
`HubKarting` (V7/V8) tient `racers: Array[Dictionary]` — **liste dès le
premier commit** —, une machine `enum Race { IDLE, COUNTDOWN, RUNNING,
FINISHED }`, un HUD (`KartHud`) qui ne fait que lire, et il persiste par
`WorldSave.kart_offer_lap()` / `kart_record_result()` + les stats
`kart_races` / `kart_wins`. **Il n'attribue aucune ressource** : son
score est un temps et un rang, jamais une noisette. Le skatepark serait
**le premier mini-jeu à écrire dans les compteurs partagés** — c'est
exactement de là que vient l'arbitrage §2.

**Le routage du tap est centralisé et strictement ordonné.**
`HubTapInput._handle_point` (546 l.) résout le rayon caméra contre
`HubSurface`, produit **deux** faits séparés :

* `aim` — où le doigt pointait, **non clampé** ; c'est lui que **chaque**
  prop est interrogé sur ;
* `destination` — `HubRegion.clamp_to(point)`, la seule chose clampée.

⚠️ **Cette séparation est un correctif payé** : lire un test de prop sur
le point clampé fait du clamp un **entonnoir** (15,26 % du sol visible
voulait dire « entre dans la cabane », 89,2 % de ces pixels visant du sol
inexistant jusqu'à 49,8 u hors carte). Tout nouveau canal se pose sur
`aim`.

Chaque prop émet **un** signal **au lieu de** `tapped_ground` — jamais
les deux. Et deux patrons de retrait, dont un **banni** :

* **patron BATEAU** — la cible se retire (`accepts_*_tap` → faux) pendant
  l'interaction, donc un tap retombe sur le chemin sol et **devient** la
  sortie ;
* **patron ÉCHELLE** — la cible émet toujours, l'appelant jette le
  signal : **BANNI** pour toute nouvelle interaction, sauf trajet borné
  par un tween finissant toujours à un point connu.

**L'intention** est le troisième morceau : `HubWorld._try_*()` (fly,
enter_cabin, climb, board, balloon, mount_ball, castle, climb_tree,
zip_badger, zip_solo) est **armée APRÈS `hop_to()`** puis tentée
immédiatement, ET recâblée sur l'atterrissage — parce qu'une marche de
longueur nulle **n'émet pas** `hop_landed` (elle émet `became_idle`,
**synchroniquement dans `hop_to()`**, et ce signal EFFACE les intentions).

### 1.3 Le saut et la collision dans le hub — le point décisif

**Il n'y a NI moteur physique, NI collider, NI détection de contact, NI
saut piloté dans le hub.** Mesuré à la lecture, sur trois fichiers :

* `HubNuts.gd` en-tête : *« NO PHYSICS ENGINE. The plateau has no bodies
  and no colliders (taps resolve against a maths plane) »* — chaque
  noisette est un intégrateur de dix lignes à elle seule.
* `HubTapInput` : *« Maths, not a physics raycast: the ground is a
  decorative PlaneMesh with no collider »*.
* `HubKarting` : les collisions entre karts sont des **disques au sol**,
  « never a `PhysicsBody3D`, the hub has no physics and wants none ».

Ce qui existe en fait de saut :

| brique | valeur | fichier |
|---|---|---|
| le hop ordinaire | `HOP_DISTANCE` 1,5 u, `HOP_HEIGHT` 0,6 u, **17 frames** mesurées (0,2833 s) → **5,294 u/s** | `KeepyHopper.gd:61-99` |
| l'enveloppe de poids | `SQUASH_TAKEOFF (1.18, 0.76, 1.18)`, `STRETCH_APEX`, `SQUASH_LAND`, `PITCH_DEG` 14° | `:262-268` |
| **le seul « modificateur de saut » existant** | le Sautillon : `VEHICLE_HOP_DISTANCE` **2,7**, `VEHICLE_HOP_HEIGHT` **1,15**, `VEHICLE_HOP_DURATION` 0,34 | `:1626-1628` |
| les arcs spéciaux | `EJECT_HOP_HEIGHT` 1,05 · `DIVE_HOP_HEIGHT` 1,55 · `TREE_TOP_HOP_HEIGHT` 0,45 · `CLIMB_MOUNT_HOP_HEIGHT` 0,40 | dispersés |
| « contact avec une surface » | **n'existe pas.** Le seul test de contact du hub est `HubPortal.landed_within(point)` : une distance 2D à un centre, sur un **atterrissage** | `HubPortal.gd` |

**Et rien ne bloque un trajet.** `KeepyHopper._is_clear(point, blocked)`
existe, mais `blocked` n'est passé **qu'une fois dans tout le dépôt** —
`HubWorld.gd:1750`, `_builder.ground_footprints()`, pour choisir le point
de berge de `leave_ride()` (le bateau). Un hop ordinaire va **tout
droit** et traverse ce qu'il veut. Les `HubRegion._holes` (tronc de
l'arbre-mère, moulin, phare) n'agissent que sur `contains()` /
`clamp_to()`, c'est-à-dire sur une **destination**, jamais sur la
trajectoire.

**Conséquence directe, et c'est la réponse au point 4 du brief : aucun
agencement de modules solides ne peut allonger un trajet du hub.**

### 1.4 Le sol du lobe, tel que CH50 l'a laissé

* `SKATE_LOBE_RADIUS` 28,0 sur `skate_lobe_centre()` = (0, 0, 35) —
  **le même point** que `north_lobe_centre()`, `NORTH_LOBE_RADIUS` (12)
  devenant inerte comme `SHORE_PAD_RADIUS` l'est depuis LAKE-MOVE.
* Couture sur le bord nord du carré : **56,0 u** (x ∈ [−28, 28]).
* Tapis : **505 pièces** semées sur le demi-disque, dont 398 sur du sol
  que l'ancienne région refusait ; **0 pièce hors région** sur toute la
  carte ; mur de forêt à `WALL_NEAR_Z` = 68, **0 arbre dans la région**,
  le plus proche à 2,161 u.
* **Le sol est PLAT** : aucun domaine `HubSurface` n'est enregistré dans
  le lobe. `y ≡ 0` partout.

---

## 2. ARBITRAGE À REMONTER — le farm, chiffré

> ⚠️ **Tous les chiffres de cette section sont de l'ARITHMÉTIQUE sur des
> constantes publiées, pas une marche au vrai hopper.** La doctrine du
> dépôt exige qu'un chiffre de traversée soit *marché*. Une passe
> `SkateFarmProbe` qui rejoue le cycle de récolte sur `KeepyHopper` est
> le premier next-step (§6), et elle prime sur tout ce qui suit.

### 2.1 Ce que rapporte l'exploration normale

Constantes lues : `WorldSave.TREE_CAPACITY` = 3, `TREE_RECHARGE_S` = 120,
`HubWorld.NUTS_PER_SHAKE` = 2, `HubTrees.kinds_for_shake` (qui rend
`min(2, stock)` noisettes) — et `tree_take()` ne retire **qu'une** unité
de stock par secousse.

Donc, arbre plein :

| secousse | stock avant | noisettes rendues |
|---|---|---|
| 1 | 3 | 2 |
| 2 | 2 | 2 |
| 3 | 1 | **1** |
| | | **5 par arbre plein** |

Arbres grimpables : **59** (5 perchoirs `HubTrees.TREES` + 54 arbres de
décor adoptés — CH44 §217, CH46 §117).

* **Stock d'ouverture, sauvegarde fraîche** : 59 × 5 = **295 noisettes**.
* **Régime permanent** : 1 unité de stock / 120 s / arbre → ~**1
  noisette/min/arbre**, soit un plafond théorique de **59/min** qui
  suppose d'être partout à la fois.

Coût en temps d'un arbre, additionné sur les constantes de
`KeepyHopper` : montée `TREE_MOUNT_HOP_S` 0,26 + `TREE_CLIMB_S` 1,6 +
`TREE_TOP_HOP_S` 0,34 = **2,20 s** ; trois secousses `TREE_SHAKE_S` 0,9 =
**2,70 s** ; descente + `TREE_DESCEND_S` 1,3 + démontage ≈ **1,90 s** ;
balayage des 5 noisettes tombées dans ~1,7 u (`PICK_RADIUS` 0,85) ≈
**0,85 s**. Soit **6,80 s en l'arbre** et ~**7,7 s** avec le ramassage.
Marche vers l'arbre suivant à 5,294 u/s : 1,1 s sur un bosquet dense,
3,8 s sur une jambe de 20 u.

| régime | débit |
|---|---|
| burst sur bosquet dense (5 noisettes / ~8,8 s) | **≈ 34 /min** |
| burst réaliste sur un circuit du plateau | **20 – 28 /min** |
| après épuisement (~9 min de jeu) | **quelques /min**, plafonné par la recharge |

**Le fait décisif n'est pas le débit, c'est le STOCK** : le monde a 295
noisettes à donner, puis il rationne.

### 2.2 Ce que rapporterait le skatepark sans garde-fou

Un trick borné a la longueur naturelle des rides déjà livrés (plongeon
`DIVE_DURATION` 0,62 s ; montée d'arbre 0,60 s de hops ; tyrolienne ~4 s) :
comptons **1,2 à 2,0 s**, plus la marche entre deux modules distants de
4 à 8 u (0,8 à 1,5 s).

| hypothèse | cycle | à **1 noisette/trick** | à **3 (combo)** |
|---|---|---|---|
| modules à 4 u, trick 1,2 s | 2,0 s | **30 /min** | **90 /min** |
| modules à 8 u, trick 1,5 s | 3,0 s | **20 /min** | **60 /min** |

| horizon | exploration | skatepark @1 | skatepark @3 |
|---|---|---|---|
| 10 min | ~330 | ~200 – 300 | ~600 – 900 |
| 30 min | ~500 | ~600 – 900 | ~1 800 – 2 700 |
| 2 h | ~1 500 | ~2 400 – 3 600 | ~7 200 – 10 800 |

**À 1 noisette par trick, le skatepark ÉGALE déjà le meilleur débit
d'exploration — et il ne s'arrête jamais, depuis une parcelle de 10 u.**
L'exploration est bornée par un stock et par la marche (la pire traversée
publiée du hub est 20,967 s coin à coin) ; le skatepark tel que spécifié
n'est borné par rien. **C'est la seule chose qui, dans ce monde, n'aurait
pas de stock** : un arbre a `TREE_CAPACITY`, un château a 3 stades, le
castor prend un de chaque, une course a 3 tours.

### 2.3 ⚠️ Ce qui relativise la sévérité — et qui change l'axe de la décision

**Il n'existe aujourd'hui qu'UN SEUL puits dans tout le jeu** :
`HubBeaver.PRICE = {truffle: 1, hazelnut: 1, flower: 1}`. Trois objets,
une fois. **Rien d'autre ne dépense une noisette.**

Donc un compteur gonflé ne casse **aucun** équilibre économique — il n'y
a pas d'économie. Ce qu'il casse, c'est **ce que le nombre VEUT DIRE** :
aujourd'hui le compteur est un relevé d'exploration (« j'ai fait le tour
du monde »), demain il serait un relevé de temps passé sur une rampe.

**L'arbitrage n'est donc pas « équilibrer une économie », c'est « décider
ce que le compteur raconte ».** C'est une question de design, et c'est
pour ça qu'elle est remontée plutôt que tranchée.

### 2.4 Trois garde-fous possibles

**G1 — Cooldown par module.** Un module qui vient de payer devient froid
pendant N s ; le joueur doit changer de module.
*Pour* : ne refuse jamais un score (le trick marche, il ne paie pas),
pousse à utiliser tout le park, trivial à sonder.
*Contre* : le plafond devient `nb_modules / N`, donc **la taille du park
devient le curseur de l'économie** — un lot qui ajoute une rampe augmente
le farm en silence. Un round-robin optimal reste du farm, juste plus
chorégraphié.

**G2 — Rendement décroissant sur répétition.** La valeur d'un trick
décroît avec la fraîcheur du même trick/module, et remonte avec le temps.
*Pour* : c'est le seul qui récompense la **variété**, c'est-à-dire ce qui
fait qu'un jeu de trick lit comme un jeu de trick ; il ne bloque jamais.
*Contre* : **le moins lisible des trois.** Le hub n'a aucune convention
de texte ; un joueur qui voit son score fondre sans explication se sent
volé. Et « pourquoi ce chiffre a baissé » est indémontrable à l'écran.

**G3 — Plafond, et de préférence un STOCK sur horloge murale.** Le park
donne au plus N noisettes, puis se recharge d'une unité toutes les
`X` secondes — **exactement le mécanisme de `tree_stock()` /
`TREE_RECHARGE_S`, déjà écrit, déjà sondé, déjà compris**, y compris la
recharge pendant que la page est fermée sans aucun timer.
*Pour* : le seul des trois qui borne le **TOTAL** et pas le débit, donc
le seul qui survive à un joueur AFK ou à une macro ; il met le skatepark
sur le même régime que tout le reste du monde ; la mécanique est du code
existant.
*Contre* : rend le park **inerte** en fin de session (les tricks
marchent, ils ne paient plus), ce qui contredit littéralement « score
continu » — à moins que le score de combo reste affiché et que seule la
conversion en noisettes s'arrête, ce qui est la variante que je
recommanderais si G3 est retenu.

*(Observation factuelle et non un vote : G3 est le seul des trois dont le
mécanisme existe déjà, testé, dans `WorldSave`. G1 et G2 sont du code
neuf à sonder de zéro.)*

**→ Décision attendue de Mathieu.** Les trois se combinent (G1+G3 est
cohérent) ; aucun n'est présupposé dans l'architecture §3, qui isole
volontairement la conversion score → noisettes derrière **une seule
fonction** pour que le choix soit un paramètre et non une refonte.

---

## 3. ARCHITECTURE PROPOSÉE

### 3.1 Où vit l'état

**`HubSkatepark` — un `Node3D` sous `World`, PAS un autoload.**

La forme est exactement celle de `HubKarting` / `HubCove` /
`HubTransport` : construit dans `_ready()`, références remises par
`HubWorld.setup(...)`, `footprints()` lu par `CozyScatter`, un canal de
tap, un hook d'atterrissage, un `cancel_intent()`.

**Pourquoi pas un autoload — et le dépôt a déjà écrit l'argument.**
`HubRouter.gd` en-tête : *« Deliberately a plain node inside
HubWorld.tscn and NOT an autoload […] a routing table that grows a second
caller stops being a hub detail and starts being a framework. »* Ici la
raison est plus dure encore : un autoload de score serait joignable
depuis `Battle`, `Chased` et `Quizz`, c'est-à-dire depuis les trois
écrans dont `WorldSave` refuse explicitement de connaître les affaires
(*« never anything that belongs to the leaderboard, to Firestore or to an
account »*).

**« Et dans 6 mois », si un deuxième jeu de trick arrive** (pump track,
half-pipe dans la Crique) : ce qui se partage n'est **pas** la géométrie,
c'est le **grand livre** — la conversion score → ressources et le
garde-fou §2.4. Ce livre a déjà un propriétaire légitime : `WorldSave`,
seul écrivain des compteurs. Le deuxième jeu ajoute **un appel**, pas un
second cooldown. Concrètement :

```
WorldSave.award_from_activity(source: StringName, points: int) -> int
    # le SEUL endroit où un garde-fou vit ; rend ce qui a réellement
    # été crédité (0 quand le garde-fou a mordu), pour que l'appelant
    # sache quoi montrer sans re-dériver la règle.
WorldSave.STAT_KEYS += ["skate_tricks", "skate_best_combo"]
    # additif, AUCUN bump de schéma -- le patron de kart_races/cove_visits.
```

Le module ne calcule jamais de noisettes. Il émet des **points** ; le
livre décide ce que ça vaut.

### 3.2 Détection du trick

**Table `MODULES: Array[Dictionary]` — liste dès la première entrée** (le
plongeoir a coûté un lot entier pour l'avoir oublié) :

```
{"kind": &"quarterpipe"|&"bowl"|&"rail"|&"funbox",
 "at": Vector3, "yaw": float, "glb": String,
 "tap_radius": float, "footprint": float,
 "tricks": Array[StringName], "points": Array[int]}
```

Granularité : **par module ET par type de trick**, publiée dans la table,
jamais devinée par l'appelant. Signal :

```
signal trick_scored(module: int, trick: StringName, points: int, chain: int)
```

⚠️ **Le trick est classé par ce qui a été JOUÉ, jamais par un proxy.**
CH43 : un test de signe ne voit pas quelle branche a tourné. Un test
« l'atterrissage est dans le disque du module » est précisément ce
proxy — il ne distingue pas « il a fait un air sur la rampe » de « il est
retombé à côté d'elle ». Le module **écrit** l'arc (§3.3), donc il
**sait** quel trick a tourné : c'est cette connaissance-là qui score.

### 3.3 Le trick lui-même — Option principale (A) : un RIDE BORNÉ

Une phase de plus dans la famille des rides de `KeepyHopper`, corps écrit
le long de la géométrie du module en espace **LOCAL** et relu par
`to_global()`.

**C'est un ride, pas une altitude.** Doctrine du dépôt : tant que ce
qu'on veut est « le personnage monte et redescend », le sol reste un seul
plan et rien d'autre n'est touché — `ON_TREE` fait 8 phases et ~330 l.
La migration multi-altitude (CH18) a coûté treize sections ; on ne la
paie que si le joueur doit **se déplacer librement** en hauteur, ce qui
n'est pas le cas ici.

Chaîne, calquée sur le bateau et l'arbre :
1. tap sur le module → `HubTapInput.tapped_skate(destination, index)`,
   testé sur **`aim`** (jamais sur la destination clampée) ;
2. `HubWorld._try_trick()` armé **APRÈS `hop_to()`** puis tenté
   immédiatement, et recâblé sur `hop_landed` ;
3. `mount_*` refuse depuis tout état autre que « debout immobile » — une
   seule réponse, chez `KeepyHopper`, jamais un second drapeau ;
4. **patron BATEAU** : `accepts_tap()` faux pendant le trick, donc un tap
   retombe sur le chemin sol et devient la sortie. Le trick est **borné
   par un tween finissant toujours à un point connu** — c'est la seule
   condition sous laquelle jeter un tap est légitime ;
5. fin → `trick_scored` → `WorldSave.award_from_activity(&"skate", pts)`.

**Le nœud porteur d'un module adopté depuis un `MultiMesh` est un
`Node3D` VIDE qui reprend rotation et translation, JAMAIS l'échelle** —
toute constante de chorégraphie est en unités personnage et traverse
`to_global()`.

*Pour* : c'est ce que « mini-jeu de trick » décrit littéralement ; le
trick a une chorégraphie ; la classification est arithmétique et non un
proxy ; la caméra reste **FIGÉE** (trajet écrit donc cadrable — la table
de la doctrine caméra range explicitement un ride à trajet fixe côté
figé).
*Contre* : c'est du code neuf dans `KeepyHopper` (un mode partagé — donc
la table des rides existants devra être rejouée sur **deux arbres** avant
la fermeture du lot), et une session faite de rides successifs est moins
« libre » qu'un roulement continu.

### 3.4 Alternative (B) : la planche comme cinquième véhicule famille B

`VEHICLE_SKATE`, après le Sautillon, le char à voile, le voilier et la
luge. Tap la planche → marche → `mount_vehicle(vehicle, lift,
glide_step, glide_s)` **qui existe déjà** ; à partir de là chaque hop
ordinaire est plus long et plus haut (le Sautillon fait exactement ça :
2,7 u / 1,15 u). Un trick est alors un **test d'atterrissage** sur le
disque d'un module, plus une vrille écrite dans `_apply_hop`.

*Pour* : **c'est ce que « session LIBRE, score continu, pas de début ni
de fin » décrit littéralement.** Zéro nouvel état dans `KeepyHopper`.
Machinerie déjà livrée et validée device. Caméra figée (le véhicule n'est
pas piloté en continu — c'est du tap-to-move, donc la table caméra le
range côté figé, comme le Sautillon).
*Contre* : le trick n'a **pas** de chorégraphie, et le score repose sur
le **proxy** que §3.2 refuse. « Il a atterri dans le disque » n'est pas
« il a fait un trick sur la rampe ».

⚠️ **Ces deux options répondent à deux moitiés différentes de la spec, et
c'est une vraie ambiguïté à trancher, pas une préférence technique** :
A sert « mini-jeu de trick », B sert « session libre, score continu ».
Elles ne sont pas exclusives (B porte la session, A porte les figures
signature sur le bol et le rail), mais faire les deux est un lot
nettement plus gros.

### 3.5 Découpage logique / présentation

* **`SkateHud`** — un `Control` qui lit le combo publié par
  `HubSkatepark` et **rien d'autre**, exactement comme `WorldHud` lit
  `WorldSave` et `KartHud` lit `HubKarting`. Zéro logique métier.
* Son rect est gaté **contre la bande de 1080 px centrée sur le milieu du
  canvas**, jamais contre le canvas headless nu (le panneau chrono du
  kart a été livré coupé sur device pour ne pas l'avoir fait), et
  `mouse_filter` est posé **explicitement** (le défaut de `Control` est
  `STOP` et il avale les taps).
* **Minimap** : `MinimapMarkers.mark(<le nœud réellement au site>,
  MinimapMarkers.PLACE)` au site de construction. **Jamais `self` dans un
  fichier où `self` est un contrôleur** — CH46 a épinglé sept marqueurs
  PNJ sur (0, 0, 0) pour cette raison exacte.
* Tout fait géométrique (centre d'un module, rayon, hauteur d'un lip) est
  **publié par un accesseur** et lu par tous les autres, jamais retapé.

---

## 4. IMPACT SUR LES BUDGETS

### 4.1 Traversée — **inchangée, par construction**

Ce n'est pas une estimation, c'est une lecture (§1.3) : `blocked` n'est
passé qu'à `leave_ride()` pour le point de berge du bateau, et les
`_holes` n'agissent que sur une **destination**. Un hop va tout droit.

**Donc aucun agencement de modules ne peut allonger un trajet.**

| paire | u | s | plafond |
|---|---|---|---|
| pire du hub — CH38 (35, −35) → (−63, 18) | 111,414 | **20,967** | 22,0 |
| pire créée par CH50 (−63, −12) → (22,43 ; 51,74) | 106,590 | **20,117** | 22,0 |
| contrôle — diagonale publiée | 98,995 | **18,700** | — |

Les trois sont intouchées. ⚠️ **Cette conclusion expire le jour où quoi
que ce soit ajoute de l'évitement d'obstacle au hopper**, et un lot qui
le ferait doit rouvrir cette ligne.

### 4.2 Triangles et draw calls — la vraie contrainte, et un chiffre à
ne PAS recopier

**Le plafond est un budget de FRAME : 50 000 primitives**
(`docs/MESHY_SPEC.md` §7, `TrackPropsAudit.TRIANGLE_TARGET`).

⚠️ **Le « 48 012, il reste 1 988 de marge » de CH22 est PÉRIMÉ et ne doit
pas être cité.** Deux mesures postérieures :

* `CozyScatter.gd:713-716` : *« 44 043 primitives with the bare relief
  (CH39, station A) »* et *« The hub already exceeds that target
  elsewhere (**55 722 measured at spawn, CH38**) »*.
* CH38 a de plus gaté un delta de crête de **+1 744** pire cas.

**Le hub est donc déjà ~11 % AU-DESSUS de la cible au spawn**, et le
skatepark n'a aucune marge à dépenser sans mesure fraîche.

⚠️ **Et la position de la pire frame de CH22 est exactement le pas de
porte du skatepark** : Keepy en **(−5,0 ; 35,0)**, caméra en
(−5,0 ; 7,6 ; 43,9), « le bord nord du plateau, regardant vers le sud à
travers tout le hub » — les cinq pires stations étant toutes entre
z = 25 et z = 35. CH50 vient de porter le sol marchable à z = 63 : le
joueur peut désormais se tenir **28 u plus au nord que la pire station
jamais mesurée**.

Une atténuation attendue, **à vérifier et non à supposer** :
`visibility_range_end` vaut 82 u (95 u pour les familles d'automne) et
fonctionne en Compatibility tant que `fade_mode = DISABLED`. Depuis
z = 63, le bord sud du plateau (z = −35) est à 98 u — **déjà coupé**.
La station nord pourrait donc être moins chère que la station z = 35, pas
plus. **Ça se mesure, ça ne se déduit pas.**

**Draw calls.** La règle du dépôt est le batch `MultiMeshInstance3D` par
paire **(mesh, couleur)**, jamais par type sémantique ; restent
individuels : ce dont il n'y a qu'UN, ce qui porte un **signal**, ce dont
le batch serait niché sous un pivot mobile. Un module interactif **n'a
pas besoin** d'être un nœud dessiné de plus : `HubTrees` a rendu 54
arbres grimpables **sans un seul nœud dessiné supplémentaire**, en
adoptant les instances de leurs `MultiMesh`.

⚠️ **On n'« ajoute » jamais une instance à un batch partagé de
l'extérieur** : porter `instance_count` de 48 à 49 rend **0 transform sur
48** survivantes. Un park qui veut de la géométrie répétée porte **son
propre `MultiMesh`**, en réutilisant mesh et matériau publiés.

Estimation, à confirmer par mesure :

| poste | prévu |
|---|---|
| batches (draw calls) | **+4 à +5** — un par paire (mesh, couleur) : quarterpipe A, quarterpipe B, bol, rail, funbox |
| triangles par module | **≤ 900** (référence `MESHY_SPEC` §7.1 : hazard 1 200, tuile de piste 800) |
| **budget park proposé, gaté DÈS LE PREMIER COMMIT** | **6 000 primitives**, la même forme et le même nombre que `CozyScatter.RIDGE_TRIANGLE_BUDGET` |

⚠️ Le budget est dans le fichier **du commit qui crée la passe** : CH35-B
Q7 — *« a ceiling added afterwards defends nothing »*.

⚠️ Et il se lit sur la ligne **`gpu`** du compteur moteur (l'opaque, au
LOD choisi), avec le replay LOD0 en borne haute et le compte de scène en
information seulement — jamais un seul des trois. Un 0 se **publie**
comme un 0 (rien ne garantit que WebGL2 remplisse ces compteurs).

⚠️ **Et un delta de primitives prouve qu'un objet est SOUMIS, jamais
qu'il est VISIBLE** (CH39 : 1 680 triangles soumis, zéro dessiné). Toute
sonde d'un objet destiné à être VU doit lire au moins un **PIXEL**, par
une passe d'identification masquée. Un skatepark est un objet visuel : il
tombe pile dans cette règle.

⚠️ **Et le delta se lit là où l'instrument est immobile** : le hub dérive
de quelques centaines de primitives entre deux frames intouchées
(papillons, pluie, critters, et **l'ours qui marche**). Gate par station
contre le tremblement **de cette station**, stations bruyantes imprimées
et laissées hors du gate.

### 4.3 Cadrage — un risque visuel nommé, à trancher par RENDU

`HubCamera.OFFSET` = (0 ; 7,6 ; 8,9), rotation **fixe**, ne yaw jamais,
ne s'approche jamais. Elle se tient donc **8,9 u au nord du joueur** :
tout ce qui est planté entre 0 et ~10 u au nord d'une position de jeu se
retrouve **entre l'objectif et le corps** et remplit le cadre. Mesuré
trois fois sur la Crique (palmiers, parasol : couronne ou toile plein
cadre), d'où `CozyScatter.COVE_CAMERA_BAND`.

Un skatepark est fait d'objets **hauts et pleins** que le joueur va
délibérément contourner : il **remplira** le cadre depuis le sud de
chaque module. C'est inhérent, et Mathieu a explicitement accepté le
compromis hors-champ — **je ne le rediscute pas**.

Ce qui reste ouvert et qui est un curseur **différent** : la **HAUTEUR**
des modules. Et elle ne se tranche pas par argument — *« un mot de
convention ne vaut rien sans une capture »*, *« une question de
lisibilité est une question de place dans le cadre, et seul un rendu y
répond »*. Un balayage `unproject_position` + rendus offscreen (station ×
azimut × météo) sur trois hauteurs candidates est le livrable qui tranche.

---

## 5. ASSETS À PRODUIRE — lot Meshy séparé

**Cinq objets autonomes distincts** (six si l'option B est retenue) :

| # | nom proposé | sujet |
|---|---|---|
| 1 | `quarterpipe_0` | quarter-pipe, profil haut/étroit |
| 2 | `quarterpipe_1` | second profil, plus large et plus bas — pour que le park ne soit pas une forme répétée |
| 3 | `bowl_0` | le bol |
| 4 | `rail_0` | rail droit avec ses deux pieds |
| 5 | `funbox_0` | funbox / plan plat + kicker — le module qui rend une chaîne possible |
| (6) | `skateboard_0` | la planche, **seulement si option B** |

**Contraintes, chacune adossée à une mesure déjà payée par le dépôt :**

1. **Objets AUTONOMES uniquement.** Une rampe seule, jamais « un
   skatepark ». Pas de sol dans le maillage, pas de composition de scène.
2. **Prompts descriptifs**, écrits au lot Meshy — **pas dans ce lot-ci**.
3. **Bake-once : la couleur est cuite dans le `.glb`, une fois.** Depuis
   la suppression du grade plein écran, **rien ne post-traite la frame**
   et l'asset est unlit : la couleur que porte un `.glb` est
   littéralement celle qui s'affiche, pour toujours. Un `tint`
   **multiplie** — il éclaircit ou assombrit **dans la teinte du
   sommet**, il ne peut pas recolorer. **Le gris béton se cuit à la
   source**, il ne s'obtient pas par teinte.
4. **`KHR_materials_unlit` est posé À LA MAIN à l'import** — aucune
   source Meshy ne le déclare.
5. **Retirer `normal_texture` et `metallic_texture` du `.glb`.**
   L'importeur glTF ne les lie **jamais** sur un matériau unlit (elles
   lisent `null` dès l'import) ; les retirer est prouvé au pixel et a
   économisé jusqu'à **10,7 Mo** sur un seul asset.
6. **Tessellation explicite, budget par unité** (≤ 900 tri/module, §4.2),
   jamais contre une ligne famille. Et **ne pas décimer** un `.glb` déjà
   livré et réutilisé : une ressource n'est packée qu'une fois, une copie
   décimée est un fichier **de plus**. Le décimateur ne transporte pas
   les UV, à aucun budget.
7. **Enroulement HORAIRE vu de la face qu'on veut voir** — Godot tient
   les faces horaires pour faces avant, et le contrôle qui tranche est
   `cull_back` contre `cull_disabled` sur le même cadre, **jamais** la
   relecture d'une assertion de normale (CH39 : 1 680 triangles verts sur
   une convention inversée).
8. **Les sources brutes vont dans `assets_source/`**, qui est dans
   `exclude_filter` — un original Meshy pèse 12 à 27 Mo et coûterait ça
   en charge morte à chaque joueur mobile.
9. **Le placeholder doit suivre le `.glb`**, sans quoi on reconstruit le
   piège « fixture qui diverge du réel » dans le dépôt qui le documente.

---

## 6. ZONES D'INCERTITUDE — décisions qui manquent, posées plutôt que supposées

1. **Le garde-fou anti-farm** (§2.4) — G1 / G2 / G3, ou une combinaison.
   **C'est la décision bloquante** : l'architecture l'isole derrière une
   fonction, mais la valeur qu'elle rend est un choix de design.
2. **Option A (ride borné) ou B (véhicule)** — §3.3 / §3.4. Les deux
   moitiés de la spec (« mini-jeu de trick » vs « session libre, score
   continu ») pointent chacune vers une option différente.
3. **Le sol sous les modules.** Béton peint (nouvelle bande
   `CozyPalette`, fichier partagé, plus l'arithmétique de lavage de
   CH48) ou modules posés sur le tapis d'herbe que CH50 vient de semer
   (zéro changement de palette, et ça lit comme « un skatepark dans un
   parc »). ⚠️ Une bande de couleur ne doit **jamais** traverser un
   versant : sans ombrage, cette ligne serait le seul trait du flanc.
4. **La hauteur des modules** — §4.3, à trancher par **rendu**, pas par
   argument.
5. **L'affichage du score.** Le hub n'a aucune convention de texte : le
   compteur `WorldHud` est tout le retour d'information existant. Un HUD
   de combo est un objet neuf à valider device.
6. **La borne des chiffres du §2** : arithmétique, pas marche. Une
   `SkateFarmProbe` doit les reproduire avant qu'ils gouvernent quoi que
   ce soit — et le banc qui les publie doit d'abord **reproduire** un
   chiffre déjà au dossier (la diagonale à 66 hops / 18,700 s) pour avoir
   qualité à en publier un neuf.

---

## 7. NEXT STEPS, dans l'ordre où ils se paient

| # | lot | ce qu'il rend | pourquoi avant le suivant |
|---|---|---|---|
| 1 | **Mesure** — pire frame rejouée sur l'arbre courant, stations nord z ∈ [35, 63] × 2 hauteurs caméra × 4 météos, ligne `gpu` + replay LOD0 + scène, plancher de bruit par station | le vrai chiffre de départ | CH22 (48 012 / 1 988) est périmé ; CH38 lit 55 722 au spawn. **Aucun module ne se place sur un budget inconnu.** |
| 2 | **Décision Mathieu** — §6 points 1 à 3 | le garde-fou et l'option | l'architecture les isole, mais ils décident la forme du lot mécanique |
| 3 | **Meshy** — les 5 (ou 6) objets autonomes, contraintes §5 | les `.glb` | le placement a besoin de silhouettes réelles, pas de primitives |
| 4 | **Placement** — layout du park dans le demi-disque, balayage `unproject_position` + rendus offscreen sur 3 hauteurs, `footprints()` pour `CozyScatter` | le park visible, inerte | §4.3 : la lisibilité est une question d'image ; seul un rendu y répond |
| 5 | **Mécanique** — `HubSkatepark`, le canal de tap, la phase de trick, `award_from_activity` | le mini-jeu | et il touche `KeepyHopper`, **un mode partagé** : la table des rides existants se rejoue sur **DEUX arbres** (branche + référence `origin/staging` importée à part, `.scn` comptés des deux côtés) avant fermeture |

**Et pour tout ce qui suit** : la première sonde du chantier doit
reproduire un chiffre déjà au dossier avant d'en publier un neuf ; toute
assertion neuve passe **ROUGE avant VERT** avec le nombre d'échecs
attendus fait partie de l'assertion ; toute assertion d'égalité ou
d'absence porte son **blind check** ; toute sonde qui lit un pixel ou un
point d'écran tourne **sous `xvfb-run --rendering-driver opengl3`**,
jamais `--headless` seul — et celles qui ne lisent que des transforms,
l'inverse.
