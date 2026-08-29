# Navigation multi-niveaux -- conception

> Document ECRIT AVANT LE CODE, lot 2/4. Il decrit un systeme GENERIQUE,
> prouve dans une scene de test isolee. **Aucun fichier du hub n'est
> touche par ce lot** ; la migration du hub vers ce systeme est un lot
> ULTERIEUR, hors de la sequence des quatre lots en cours.

---

## 1. RECON -- toutes les hypotheses mono-altitude, MESUREES

`grep` cible plus lecture integrale de `HubTapInput.gd`, `HubRegion.gd`,
`KeepyHopper.gd`, `HubCamera.gd` et du gate de tap de `HubWorld.gd`.
Chaque ligne ci-dessous est une hypothese que le nouveau systeme ne doit
PAS reproduire par inadvertance.

### 1.1 Le raycast de tap -- UN plan, ecrit en dur

`HubTapInput._handle_point:219`

```gdscript
var ground := Plane(Vector3.UP, 0.0)
var hit: Variant = ground.intersects_ray(origin, direction)
```

**C'est le seul `Plane(...)` de tout `scripts/` hors `scripts/dev/`**
(verifie par grep sur le depot). Le `0.0` est un litteral : il n'existe
aucun chemin par lequel un tap puisse se resoudre contre autre chose que
le sol a y = 0. Un `hit == null` (camera au-dessus de l'horizon) est un
`return` silencieux -- comportement a conserver, mais qui devra etre
re-evalue par niveau, un plan plus haut ayant un horizon different.

### 1.2 La region -- Y jete a l'entree de CHAQUE requete

`HubRegion._flat():430` est appele en premiere ligne de `contains()`,
`clamp_to()`, `in_lake_water()`, `lake_index_at()` et `_lake_holding()`.
La region est donc **litteralement 2D** : elle ne peut pas repondre
differemment a deux points qui ne different que par Y. `PLATEAU_HALF_EXTENT`
(35.0) est un scalaire unique pour tout le plateau -- il n'existe aucune
notion de bornes par zone.

### 1.3 Le corps -- Y ecrit proceduralement, jamais lu d'un terrain

`KeepyHopper` ecrit `global_position.y` a exactement trois endroits, tous
calcules et aucun echantillonne :

| site | ecriture |
|---|---|
| `_apply_hop:1414` | `base + height`, ou `base = lerpf(_hop_from_y, _hop_to_y, t)` |
| `_on_hop_finished:1441` | `Vector3(_hop_to.x, _hop_to_y, _hop_to.z)` |
| `_place_on_route:1300` | `Vector3(where.x, RIDE_SEAT_Y, where.z)` |

⚠️ **`_hop_from_y` / `_hop_to_y` SONT DEJA la generalisation multi-altitude
de l'arc**, livree par le lot plongeoir, et prouvee exacte a extremites
egales (`DivingBoardProbe` PHASE A, divergence 0,000000000000 u sur 1001
points). **C'est la seule brique existante directement reutilisable.**

**Mais elle est verrouillee a zero par ses appelants** :

| site | ligne |
|---|---|
| `_begin_hop:1369-1370` | `_hop_from_y = 0.0` / `_hop_to_y = 0.0` -- reset a CHAQUE hop ordinaire |
| `_on_hop_finished:1442-1443` | remis a `0.0` apres chaque atterrissage |
| `leave_ride:1108-1109` | `0.0` / `0.0` |
| `leave_turnstile:711-712`, `leave_seesaw`, `leave_owl:944-945` | `seat_y` / **`0.0`** |
| `dive:1263-1264` | `anchor.y` / **`0.0`** |

**Tout dismount vise `_hop_to_y = 0.0` en dur.** Il n'existe aucun chemin
par lequel la chaine de hops ordinaire circule a une altitude non nulle.

`hop_to():491` ecrase le Y du point demande (`Vector3(point.x, 0.0, point.z)`),
et `_advance():1356` relit la position courante en la mettant a plat -- donc
meme si le corps etait pose en hauteur, la chaine le ramenerait au plan zero
au premier pas.

### 1.4 Retour au sol des trois props a derogation

Les trois -- tourniquet, balancoire, hibou -- portent une garde identique
pour le cas ou le prop disparait sous le rider :

```gdscript
global_position = Vector3(global_position.x, 0.0, global_position.z)
```

(`KeepyHopper:671`, `:787`, `:902` -- les trois SEULES ecritures de position
a Y litteral zero du fichier.)

### 1.5 La camera -- aucune notion d'offset vertical configurable

`HubCamera._wanted():48-50`

```gdscript
var ground := Vector3(target.global_position.x, 0.0, target.global_position.z)
return ground + OFFSET
```

**Reponse explicite a la question de recon : NON, la camera n'a AUCUN
offset vertical configurable.** `OFFSET.y = 7.6` est une constante absolue
mesuree depuis y = 0, et le Y de la cible est **jete** avant l'addition --
deliberement (l'en-tete du fichier explique que suivre l'arc ferait tanguer
l'horizon au rythme des hops). Le "banking" du hibou evoque au brief est le
lacet/roulis de l'OISEAU, pas un reglage de camera : `grep camera` sur
`HubWorld.gd` ne rend que des commentaires, aucun code.

Consequence : porter Keepy a y = +5 aujourd'hui le ferait sortir par le haut
du cadre sans que la camera bouge d'un pixel.

### 1.6 Recensement

| fichier | occurrences de l'idiome `Vector3(x, 0.0, z)` |
|---|---|
| `KeepyHopper.gd` | 24 |
| `HubBuilder.gd` | 10 |
| `HubWorld.gd` | 8 |
| `BoatMooring.gd` | 6 |
| `HubStreamRoute.gd` | 5 |
| `HubWater.gd` | 3 |
| `HubCamera.gd`, `HubRegion.gd`, `HubTapInput.gd` | 1 chacun |
| **total `scripts/hub`** | **59** |

---

## 2. LES TROIS DEROGATIONS -- reutilisables ou pas ?

Question de recon 3, repondue franchement.

### 2.1 Ce qu'elles font reellement

Les trois suivent EXACTEMENT le meme squelette :

1. `mount_*()` : `_state = <etat dedie>`, memoriser le porteur + un offset
   local, `_has_target = false`.
2. `follow_*()` : appelee **par l'ecrivain du porteur, dans le meme appel**
   (jamais depuis `_process` -- un rider qui echantillonne son porteur est
   une frame en retard, mesure a 12,0 deg au pic de la poussee du
   tourniquet, et `process_priority` n'y change rien).
3. `leave_*(landing)` : `_hop_from_y = <hauteur du siege, LUE sur le corps>`,
   `_hop_to_y = 0.0`, un arc, puis `_on_hop_finished()`.

### 2.2 ⚠️ AUCUN DES TROIS NE CONVIENT COMME BRIQUE DE TRANSITION -- et il faut le dire clairement

Un etat de derogation et un etat de niveau sont **deux problemes
differents**, et confondre les deux serait la premiere erreur de ce
systeme :

| | derogation (tourniquet / balancoire / hibou) | niveau (ce lot) |
|---|---|---|
| duree | **TRANSITOIRE** -- bornee par un tween qui finit tout seul | **PERSISTANTE** -- dure jusqu'a la prochaine transition |
| qui ecrit le corps | le PORTEUR, chaque frame | **personne** : Keepy marche normalement |
| taps pendant | **interceptes par etat**, jamais une destination | **doivent devenir des destinations** -- c'est tout l'objet |
| sortie | vers y = 0, en dur, toujours | vers l'altitude d'un AUTRE niveau |
| bornes de deplacement | aucune -- il n'y a pas de deplacement libre | les siennes, par niveau |

Un niveau ou Keepy ne peut pas marcher n'est pas un niveau, c'est un
siege. **Les trois derogations sont donc etudiees et ECARTEES comme
patron d'etat.**

### 2.3 Ce qui EST reutilise, et c'est une seule chose

**`_hop_from_y` / `_hop_to_y` -- l'arc generalise.** C'est deja le
mecanisme "partir haut, atterrir bas", il est deja prouve exact a
extremites egales, et le rendre bidirectionnel (`from` bas, `to` haut) ne
demande aucune ligne nouvelle -- seulement des appelants qui cessent
d'ecrire `0.0`.

**Ce lot le reimplemente plutot que d'importer `KeepyHopper`**, parce que
la contrainte du brief est zero dependance au hub. La formule est
reproduite a l'identique (`base = lerpf(from_y, to_y, t)`,
`height = h * 4t(1-t)`), et la sonde le gate contre la formule d'origine.

---

## 3. CONCEPTION

### 3.1 `LevelDefinition` -- un niveau est un PLAN PLAT, aussi simple que le hub

```
plane_y        offset Y absolu du sol de ce niveau
half_extent    demi-cote du carre marchable (equivalent PLATEAU_HALF_EXTENT)
centre_xz      centre du carre dans le plan XZ
```

**Chaque niveau reste INTERNEMENT aussi simple que le hub d'aujourd'hui.**
C'est le point de conception central : la complexite ne va pas dans les
niveaux, elle va dans le PASSAGE de l'un a l'autre. Un niveau expose
exactement les deux operations que `HubRegion` expose deja, plus une
troisieme qui n'a de sens qu'ici :

| operation | equivalent hub |
|---|---|
| `contains(point)` | `HubRegion.contains()` |
| `clamp_to(point)` | `HubRegion.clamp_to()` |
| `flat(point)` | `HubRegion._flat()`, **mais projetant sur `plane_y` au lieu de 0** |
| `plane()` | **NOUVEAU** : le `Plane(UP, plane_y)` contre lequel un tap se resout |

⚠️ **`flat()` ne jette PLUS Y, il le REMPLACE** par `plane_y`. C'est la
seule difference de fond avec `HubRegion._flat()`, et c'est ce qui permet
a deux niveaux de repondre differemment a deux points qui ne different que
par leur hauteur.

`half_extent` est **par niveau** et non global : un interieur de cabane
est petit, un plateau est grand, et un scalaire unique redirait l'erreur
que `HubRegion` a deja payee quand la limite a cesse d'etre un nombre.

### 3.2 `LevelController` -- l'etat "niveau courant", et le patron AIM/destination

Un composant dedie plutot qu'un champ de plus sur le hopper : le hopper
sait DEPLACER un corps, il n'a pas a savoir sur quel monde. Il porte :

- l'index du niveau courant ;
- la resolution d'un tap : ecran -> rayon -> **plan DU NIVEAU COURANT** ;
- le couple **AIM / DESTINATION**, repris du lot 1 et adapte a N niveaux.

⚠️ **LE PATRON AIM/DESTINATION EST REPRIS DES LE DEPART, PAS AJOUTE APRES.**
Le lot 1 a mesure ce que coute de les confondre : `clamp_to()` repond "ou
peut-il se tenir", un test de prop repond "qu'a voulu dire le joueur", et
lire le second sur le premier fait du clamp un **entonnoir** -- sur le
layout livre, des taps vises jusqu'a 49,8 u hors de la carte atterrissaient
sur le pas de porte de la cabane et signifiaient "entre". Debout a la
porte, **15,26 %** de tout le sol visible disait "entre", dont **89,2 %**
visait du sol qui n'existe pas.

Le systeme expose donc deux valeurs par tap, jamais une :

```
aim          l'intention brute, sur le plan du niveau, NON clampee
destination  aim passe par clamp_to() du niveau
```

**Tout test de transition lit `aim`. Seule `destination` est un endroit ou
marcher.** C'est ce qui empeche un tap vise hors des bornes d'etre
reinterprete comme un ordre de transition -- et c'est explicitement gate
par la sonde.

⚠️ **Multi-niveaux AGGRAVE le risque d'entonnoir plutot que de le laisser
inchange** : chaque niveau a son propre bord, donc chaque transition posee
pres d'un bord est un entonnoir potentiel de plus. C'est pourquoi le
patron est repris des la premiere ligne au lieu d'etre re-decouvert.

### 3.3 `LevelTransition` -- gate sur le patron BATEAU, jamais sur le patron ECHELLE

Une transition relie deux niveaux adjacents et porte, de chaque cote, un
point d'accroche (le pied et le sommet d'une echelle, au lot 3).

**Le gate est le RETRAIT ACTIF de disponibilite du bateau :**

```
is_available()  ->  false pendant toute la duree d'une transition
```

⚠️ **Le patron ECHELLE est INTERDIT ici, et ce n'est pas une preference.**
Il a coute deux bugs distincts a ce depot : `HubTapInput` emet
`tapped_ladder` quoi que fasse Keepy et `HubWorld` le jette. C'est
inoffensif pour une planche (dont le seul autre sens serait un plongeon
deja traite par etat) et **faux ici** : un tap pendant une transition doit
pouvoir atteindre le chemin sol, sinon un joueur dont les taps sont
avales par le prop dans lequel il se trouve n'a **aucune sortie**.

Consequence directe : pendant une transition, un tap retombe sur le
chemin ordinaire au lieu de re-declencher la transition. Ce cas
("un tap pendant une transition ne doit PAS re-declencher") est un gate
explicite de la sonde, prouve rouge avant vert.

### 3.4 La camera -- proposee, une seule option retenue

`HubCamera` n'ayant aucune notion d'offset vertical (§1.5), un changement
de niveau la laisserait derriere. Deux options :

| | franche | **interpolee (retenue)** |
|---|---|---|
| mecanisme | `plane_y` du niveau ajoute d'un coup | le lerp exponentiel existant absorbe le changement |
| cout | un saut d'image a chaque transition | aucun code nouveau : le `FOLLOW_LAMBDA` fait deja le travail |
| risque | un cut lu comme un glitch | la camera traine pendant la montee |

**Retenue : interpolee**, parce qu'elle ne coute rien -- le suivi est deja
un lerp exponentiel independant du framerate, et lui donner une cible plus
haute suffit. La seule ligne qui change est celle qui jette Y :

```gdscript
# avant : ground.y toujours 0
var ground := Vector3(target.x, 0.0, target.z)
# apres : le PLAN DU NIVEAU, jamais le Y du corps (l'arc du hop
#         ferait toujours tanguer l'horizon -- l'argument d'origine tient)
var ground := Vector3(target.x, level.plane_y, target.z)
```

⚠️ **Suivre `plane_y` et non `global_position.y`** : l'argument original de
`HubCamera` -- un `look_at` re-vise chaque frame sur une cible qui oscille
de 0,6 u par hop ferait tanguer l'horizon -- reste entierement valable. Le
niveau est stable, l'arc ne l'est pas.

Le noyau expose donc `plane_y` du niveau courant ; **la camera de test
l'utilise, mais `HubCamera` n'est pas touche** (ce serait une modification
du hub, hors perimetre).

---

## 4. HORS PERIMETRE DE CE LOT -- nomme, pas construit

- **Rendu de plusieurs niveaux simultanement visibles / empiles.** Les deux
  niveaux de test sont dessines ensemble parce qu'ils sont des primitives
  triviales ; rien ici ne resout l'occlusion, le tri de transparence ni le
  culling d'un etage au-dessus d'un autre.
- **Plus de deux niveaux.** Les structures sont des LISTES des le premier
  commit (lecon du plongeoir : sa geometrie etait generique le jour de sa
  livraison, c'est la table en aval qui n'en tenait qu'un, et defaire ca a
  coute son propre lot) -- mais **seul le cas a deux est exerce**. Un
  troisieme niveau est une entree de plus, pas un mecanisme de plus.
- **Sauvegarde de la position par niveau entre sessions.** Aucune
  persistance : le systeme oublie tout au rechargement, exactement comme
  `HubWorld` aujourd'hui.
- **Migration du hub.** C'est la destination assumee, et elle appartient a
  un lot ULTERIEUR, hors de la sequence des quatre lots en cours.
- **Toute geometrie reelle** (`.glb` cabane, plateformes alignees,
  echelle) : c'est le lot 3.
- **Collision, physique, evitement d'obstacle.** Le hub n'en a aucun ; ce
  systeme n'en ajoute pas.

---

## 5. FICHIERS

| fichier | role | packe ? |
|---|---|---|
| `scripts/nav/LevelDefinition.gd` | un plan plat, ses bornes, son `clamp_to` | oui |
| `scripts/nav/LevelController.gd` | niveau courant, resolution de tap, AIM/destination | oui |
| `scripts/nav/LevelTransition.gd` | une liaison entre deux niveaux, gate bateau | oui |
| `scripts/nav/LevelWalker.gd` | le corps : chaine de hops, arc generalise | oui |
| `scripts/nav/LevelCamera.gd` | le suivi, cible `plane_y` du niveau courant | oui |
| `scripts/nav/LevelNavTestWorld.gd` | le banc : deux niveaux, un lien, primitives | oui |
| `scenes/dev/LevelNavTest.tscn` | la scene de test, structure seule | oui |
| `scripts/dev/LevelNavProbe.{gd,tscn}` | la sonde | **non** (`exclude_filter`) |

⚠️ **AUCUNE dependance de `scripts/nav/` vers `scripts/dev/`.**
`scripts/dev/*` est dans l'`exclude_filter` de l'export, donc une
reference `class_name` depuis un script packe resout dans l'editeur et en
headless puis **echoue uniquement dans le build web** -- le seul endroit
que personne ne peut verifier. Piege deja consigne pour `DevSeed`.

---

## 6. CE QUE LA SONDE A TROUVE -- deux defauts a moi, publies

Les deux sont des defauts de la SONDE, pas du systeme, et ils sont dits
parce qu'un vert obtenu en corrigeant une assertion merite d'etre
distingue d'un vert obtenu en corrigeant du code.

1. **`contains()` est XZ-SEUL PAR CONTRAT, et j'ai asserte le
   contraire.** J'ai ecrit "un tap lointain sur le niveau haut clampe
   dans les bornes hautes ET PAS dans les basses". Le carre haut est
   entierement a l'interieur de l'empreinte XZ du carre bas, donc le
   niveau bas contient bien ce XZ -- et il a raison de le contenir : "sur
   quel niveau est-il" est la question du CONTROLEUR, pas d'un niveau.
   Re-visee sur ce qui porte reellement le sens : la BORNE contre
   laquelle le clamp s'est arrete.
2. **"aucun tap hors carte ne peut signifier traverser" est FAUX, et
   l'asserter a fait echouer du code correct.** Une visee a 1 u au-dela
   du bord est a 1 u d'un pied de rayon 1,6 : c'est un joueur qui tape A
   LA PORTE depuis juste dehors, et le refuser serait un autre bug. Ce
   que la regle du lot 1 achete n'est pas un ensemble VIDE, c'est un
   ensemble **borne par le RAYON** au lieu d'etre non borne par le clamp.
   Mesure : la visee hors carte la plus profonde qui signifie encore
   "traverser" est a **-10,50**, soit la borne du rayon (-10,60) a un pas
   de balayage pres -- et **0 des 690 visees balayees de 11 u a 88 u**
   au-dela en signifient une.

## 7. UN DEFAUT REEL, TROUVE PAR LA PASSE ROUGE-AVANT-VERT

`LevelTransition.accepts_tap()` lisait le champ `_available` **en
direct** alors que `is_available()` est l'accesseur public. Avec
l'accesseur sabote pour modeler le patron ECHELLE, cette fonction
continuait de refuser -- donc **une seule** des deux assertions de gate
passait au rouge. Un champ, deux lecteurs, l'un contournant l'accesseur :
c'est exactement ainsi que les deux reponses commencent a differer.
Corrige avant commit ; le meme sabotage rend desormais **les deux**
rouges.
