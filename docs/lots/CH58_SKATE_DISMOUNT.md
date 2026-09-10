# CH58 — le tap qui n'arrivait jamais : la planche physique avalait tout l'input

**9 septembre 2026.** Lot de **correction bloquante**, ouvert sur un verdict
terrain de Mathieu : sous `keepyphys=1`, à la station (3 ; 60), overlay
`PHYS ON bodies 1 pairs 0`, **le mount sur la planche marche et, une fois
monté, plus aucun tap n'est reçu par le gameplay**. Pas de déplacement, pas
de descente, rien. Le jeu tournait — FPS vivant, bouton Menu réactif — donc
ce n'était pas un gel moteur mais un **verrou d'input scopé au gameplay**.
Sortie seulement par rechargement complet de la page.

Aucune fonctionnalité dans ce lot. Aucun lot 2. Le défaut, sa cause, sa
preuve, son correctif, et la sonde permanente qui interdit son retour.

Livrables : `scripts/dev/SkateDismountProbe.gd` + `.tscn` (sonde
**permanente**, 8 phases, **51 assertions vertes**), deux corrections dans
`scripts/hub/HubWorld.gd`, ce fichier et sa ligne d'index.

---

## 0. LA BASE, ET LA GARDE DE CONCURRENCE

Branche `claude/skateboard-dismount-input-bug-e699x3` ouverte sur `main`
(`2876f27`) et **re-basée sur `origin/staging`** (`a4e517f`, arbre
`ce920c3e`) avant la première lecture — CH57 vit sur `staging`, et une
session menée sur `main` aurait lu un hub sans `SkateBoardBody` du tout.

Garde faite **au début et par ARBRE**, jamais par nom :

| ref | arbre | verdict |
|---|---|---|
| `origin/main` | `9a1d2a9` | identique à l'arbre où la branche a été ouverte |
| `origin/claude/skateboard-dismount-input-bug-e699x3` (mon homonyme) | `9a1d2a9` | **aucun travail dessus** — c'est l'arbre de `main` |
| `origin/staging` | `ce920c3e` | CH50 → CH57, la vraie base |

`merge-base --is-ancestor HEAD origin/staging` → vrai, `origin/staging`
ancêtre de `HEAD` → faux : un **retard**, pas une divergence. Trois refs
distantes en tout, aucune collision.

⚠️ **Ce sandbox n'avait pas de Godot** (comme au CH57) : binaire 4.3-stable
téléchargé et **taille vérifiée contre le `Content-Length` avant
extraction** — **50 276 070** octets, le chiffre que `CLAUDE.md` publie pour
l'éditeur. Import complet vérifié par ARTEFACT et non par notification :
**154 `.scn`**, 308 artefacts glb, zéro `Cannot open file` — et la
notification de tâche de fond « terminée » est arrivée **à 13 secondes**
d'un import qui en a pris **plus de 200**, exactement le corollaire que
`CLAUDE.md` documente.

---

## 1. LA CAUSE, ET ELLE N'EST VISIBLE DANS AUCUN DES DEUX FICHIERS LU SEUL

Trois faits, chacun correct isolément :

1. `HubTransport.mount_board()` appelle `KeepyHopper.mount_carrier()`, qui
   pose `_state = State.ON_CARRIER`. La planche est le **cinquième** usager
   du contrat porteur, et CH57 l'a écrit exprès ainsi.
2. `HubWorld._on_tapped_ground` **jette** un tap tant que
   `_keepy.is_on_carrier()`. C'est **juste pour la montgolfière** :
   `CLAUDE.md` n'accorde la licence de jeter un tap qu'à un trajet **BORNÉ**,
   « un tween qui se termine toujours à un point connu ».
3. La branche de la planche écrite par CH57 est **QUARANTE-SEPT LIGNES
   PLUS BAS** que ce `return`.

Donc, pendant tout un ride, la branche de CH57 est **du code mort**. Un
ride de planche — qui est **NON BORNÉ**, la planche reste immobile sous le
joueur jusqu'à ce qu'il en décide autrement — a hérité de la licence d'un
trajet borné.

C'est le **PATRON ÉCHELLE** de `CLAUDE.md` : un joueur enfermé dans un prop
qui avale chacun de ses taps, sans aucune sortie. Et il a été atteint **sans
que personne n'écrive le patron interdit** — par HÉRITAGE d'un `return` à
travers un ÉTAT partagé avec quelque chose qui, lui, a le droit de jeter.

**Le commentaire de CH57 dans `HubTapInput.gd` était exact et inutile :**
« every tap while riding means one of the board's two things (steer, or step
off), and none is ever swallowed ». Le routage était juste. C'est
l'écouteur qui jetait.

### 1.1 ⚠️ POURQUOI LES 43 ASSERTIONS DE CH57 ÉTAIENT TOUTES VERTES DESSUS

`SkatePhysicsProbe` conduit la planche en appelant `mount_board()` et
`set_board_target()` **DIRECTEMENT**. Elle ne passe **pas une seule fois**
par `_on_tapped_ground`. Tout le chemin de tap livré — le seul qu'un joueur
possède — est **hors de tout ce qu'elle mesure**.

C'est mot pour mot « **un fixture qui diverge du réel sur un axe ne protège
pas de cet axe** », et l'axe est le **ROUTAGE**. `SkateDismountProbe`
n'appelle donc **jamais** `set_board_target` : chaque tap y est délivré par
le **vrai signal** sur le **vrai nœud** `HubTapInput`, dans le **vrai**
écouteur `HubWorld`, et ce qui est asserté est ce que le **MONDE** en a
fait.

---

## 2. LA PREUVE DU DÉFAUT — 12 ROUGES SUR L'ARBRE VIERGE

`SkateDismountProbe`, headless, `--fixed-fps 60`, sur `origin/staging`
**sans une ligne de correctif** :

```
[OK ] INSTRUMENT: he starts on foot, not on the board
[OK ] a ground tap through the REAL signal starts a walk
[OK ] INSTRUMENT: the walk ended on plain ground, in no prop
[OK ] mount_board() took him aboard
[OK ] and the HOPPER is in ON_CARRIER
[RED] the tap reached the board: it now has a target
     rolled 0.000 u in 30 ticks
[RED] a tap on himself dismounted him
[RED] and the hopper is out of ON_CARRIER
     stepped off 0.000 u from where the board stands
[RED] and the WORLD acted on it -- the tap was not swallowed
     -> (9.10733, 0, 51.08163) ; riding=true has_target=false
=== FAILED -- 12 red ===
```

**Tous les INSTRUMENT sont verts** — il est réellement à bord, le mount a
réellement pris, la planche est bien un corps physique — et **tout ce qui
teste ce qu'un tap FAIT est rouge**. `0,000 u` parcourus, `0,000 u` de pas
de côté : rien n'a bougé.

La ligne qui tranche est celle de **PHASE X**, qui part d'une **vraie
coordonnée écran** et traverse le routeur réel : le tap sol est bien émis
(`-> (9.107, 0, 51.082)`) et le monde répond `riding=true has_target=false`.
**Le tap arrive et il est jeté.** C'est le verdict terrain de Mathieu,
reproduit en sandbox, de bout en bout.

Et le contraste borne le défaut exactement : **PHASE T** (traversée) et
**PHASE O** (interrupteur baissé) sortent **vertes dans la même passe**. Le
jeu livré n'est pas touché ; seul le ride physique est mort. C'est
précisément ce que Mathieu décrivait — le menu s'ouvrait, les FPS
bougeaient.

### 2.1 ⚠️ ET LA PREMIÈRE VERSION DE LA SONDE ÉTAIT FAUSSE — DEUX FOIS

La passe rouge a d'abord trouvé des défauts **dans la sonde**, ce qui est
ce à quoi sert une passe rouge :

* **`_tap_self()` rendait `not is_riding_board()`** — une assertion
  d'**ABSENCE**, qui passe gratuitement. Sur un run où le mount avait
  silencieusement échoué, « a tap on himself dismounted him » est sorti
  **VERT trois fois**, contre un cavalier qui n'était **jamais monté**.
  Réparé par une garde de précondition **gatée** (`INSTRUMENT: he IS aboard
  before the self-tap`), sur la règle `CLAUDE.md` d'un état TENU qui porte
  sa propre remise à zéro assertée.
* **Et la station était mauvaise.** La sonde faisait marcher Keepy vers
  `(0 ; 0 ; 40)` — et l'y posait **SUR LA BALANÇOIRE** : `_mount_seesaw`
  s'arme depuis **n'importe quel atterrissage** au-dessus d'une planche,
  sans aucune intention. Depuis `ON_SEESAW`, `mount_carrier` **refuse**,
  donc `mount_board()` rendait faux et tout l'aval se notait sur un
  cavalier absent. Stations déplacées à l'est du park (`(12 ; 52)` et
  `(12 ; 44)`, mesurées : `clamp_to` identité sur les deux), et **PHASE I
  re-vérifie à chaque run que la marche finit sur du sol nu**.

Les deux défauts avaient la même forme et c'est celle que ce dépôt paie le
plus souvent : **une négation qui passe pour un résultat.**

---

## 3. LE CORRECTIF 1 — LA LICENCE, PAS L'ÉTAT

Une ligne de logique dans `HubWorld._on_tapped_ground` :

```gdscript
if _keepy.is_on_carrier() and not _transport.is_riding_board():
    return
```

`ON_CARRIER` est un **état**, pas une **permission**. Cinq choses l'utilisent
désormais, et le droit de JETER un tap n'est pas une propriété de l'état :
`CLAUDE.md` ne l'accorde qu'à un trajet **borné**. Montgolfière, tyrolienne
et boucle de hibou le sont ; la planche physique **ne l'est pas** — elle a
une phase non bornée, exactement celle que couvre la règle de la balançoire,
où un corps tenu doit garder une sortie.

Le commentaire écrit au-dessus énonce le **test** plutôt que la liste : un
porteur futur dont le ride est non borné va dans l'exception, un dont le
ride est un tween borné va dans le `return`. Et un renvoi croisé est écrit
**à la branche de la planche**, pour que les deux moitiés — quarante-sept
lignes l'une de l'autre — se trouvent l'une l'autre.

---

## 4. LE CORRECTIF 2 — ET C'EST LA SONDE VERTE QUI L'A DÉNONCÉE

Après le correctif 1 : **ALL GREEN, 0 rouge**. Et la PHASE A(4) imprimait,
deux lignes au-dessus de son propre vert :

```
(4) on the deck: a finger on his drawn feet resolves 1.501 u
    from his flat position (radius 0.90)
[OK ] (4) up on the funbox deck -- he still gets off
```

**Le vert était faux.** La sonde tapait `_flat(global_position)` — la
position **plate** de Keepy — c'est-à-dire une question qu'**aucun doigt ne
peut poser**. C'est `CLAUDE.md`, « **la métrique peut être la mauvaise, et
le chiffre vert avec** », dans la forme exacte du hotspot du lit.

Rendue honnête (le tap part du point où le rayon caméra à travers son corps
rencontre `HubSurface`), la même sonde sort **1 rouge, et c'est le cas (4)**.

### 4.1 LE MÉCANISME, MESURÉ

`HubCamera` ne monte **jamais** — `OFFSET` est une constante et elle suit le
point **SOL** de Keepy — et tout tap se résout sur `HubSurface`. Un corps
qui se tient **au-dessus** du plan de sol est donc **DESSINÉ** là où le sol
sous lui n'est pas, et l'écart grandit avec la hauteur :

| station | où se résout un doigt visant ses pieds dessinés |
|---|---|
| sol plat | **0,133 u** — largement dans le rayon de 0,90 |
| deck de la funbox | **1,501 u** — **dehors**, de deux tiers en plus |

D'où : « taper sur soi pour descendre » marchait sur la pelouse et **ne
marchait pas sur le seul module que tout ce chantier existe pour grimper**.
Le joueur n'était pas bloqué — son tap devenait un braquage, la planche
finissait par redescendre — mais il ne pouvait pas descendre **là**, ce que
le brief exige explicitement.

**Correctif** : le test « c'est lui » lit le point **DESSINÉ**
(`_drawn_ground_point`), pas la position plate. C'est la règle AIM de
`CLAUDE.md` appliquée au cavalier au lieu d'un prop — un test de prop répond
« qu'est-ce que le joueur a VOULU dire », et ce qu'il veut dire en tapant un
corps dessiné, c'est ce corps. Seule la **destination** reste clampée.

⚠️ **SCOPÉ À LA PLANCHE PHYSIQUE EXPRÈS.** La branche du sautillon lit
toujours la position plate : elle est livrée, validée device, et le ballon ne
quitte jamais le sol — sa parallaxe est le cas 0,133. L'élargir serait
changer le jeu que **tous** les joueurs ont, ce que ce lot ne doit pas faire.
Repli sur l'ancien comportement quand il n'y a pas de caméra.

---

## 5. ROUGE AVANT VERT — DEUX PASSES QUI NE SE RECOUVRENT PAS

`CLAUDE.md` (CH46) : quand deux mécanismes distincts sont gatés, on le prouve
en neutralisant **chacun à son tour** et en exigeant que la passe rouge de
l'un laisse les assertions de l'autre **vertes**. Une seule passe qui rougit
tout ne distingue rien.

| neutralisation | rouges | lesquels |
|---|---|---|
| correctif 1 seul (`is_on_carrier()` nu restauré) | **12** | tout le routage — steer, dismount, PHASE X ; **pas** l'assertion du cas (4), qui échoue plus haut faute de ride |
| correctif 2 seul (`_drawn_ground_point` renvoyé au plat) | **1** | **exactement** `(4) up on the funbox deck -- he still gets off` |
| aucune | **0** | ALL GREEN, 44 assertions |

Les 12 rouges du premier tableau sont **le même compte et les mêmes lignes**
que la mesure sur l'arbre vierge — la neutralisation reproduit le défaut
livré, elle ne fabrique pas un autre défaut.

`HubWorld.gd` **restauré et vérifié byte-identique par `cmp`** après chacune
des deux passes.

---

## 6. CE QUE LA SONDE GATE, PHASE PAR PHASE

| phase | ce qu'elle tient |
|---|---|
| **I** — instrument | blind check **positif d'abord** : un tap sol démarre une marche, et la marche finit sur du sol nu (sans quoi tout mount en aval est refusé et tout l'aval passe gratuitement) |
| **S** — la prémisse | un ride de planche **EST** un ride `ON_CARRIER` — le fait dont dépend tout le diagnostic, gaté pour qu'il rougisse ici et pas sur un device |
| **R** — braquage | un tap loin de lui donne une cible **et fait rouler la planche** (3,465 u en 30 ticks) — pas seulement un drapeau posé sur un corps que personne ne fait avancer |
| **D** — descente | un tap sur lui, à l'arrêt, le pose (0,643 u de pas de côté), le sort d'`ON_CARRIER`, **et le tap suivant redevient une marche** |
| **A** — partout | les quatre cas du brief : sol dégagé, en roulement, **coincé contre la face est de la funbox**, et **debout sur son deck** ; parallaxe publiée à chaque station et le deck comparé au plat comme témoin |
| **X** — chaîne complète | depuis une **vraie coordonnée écran** à travers le vrai routeur ; asserte le rect non dégénéré, sinon **skip bruyant** |
| **T** — plafond | diagonale publiée re-marchée monde physique vivant : **66 hops / 1 123 frames / 18,717 s** contre 66 / 18,700 — à la frame près, sous les 22,0 s |
| **O** — non-régression | un **second monde** construit interrupteur baissé : la planche n'est pas un corps physique, le mount CH54 passe par `ON_VEHICLE` (une autre porte), et **la descente CH54 marche, inchangée** |

Compte par phase : **I 4, S 3, R 6, D 7, A 19, X 3, T 3, O 6 = 51**.

⚠️ **Le message du commit `1558bab` annonce 44** — chiffre écrit avant que
la correction « le tap part d'où un doigt le pose » n'ajoute ses
assertions, et laissé en place plutôt que réécrit : la CI de ce lot a
tourné sur ce SHA, et réécrire l'historique aurait détaché la preuve de
build de son commit. Le chiffre exact est **51**, ici et dans l'index.

Le cas (2) mérite d'être nommé : un tap sur soi **en roulement BRAQUE**, il
n'éjecte pas — c'est la règle de CH57 et elle est conservée. La garantie
n'est pas « un tap éjecte toujours » mais « un cavalier n'est jamais à plus
d'un tap de plus du sol », et c'est ce qui est gaté.

---

## 7. INCERTITUDES NOMMÉES

* ⚠️ **RIEN N'A ÉTÉ RENDU.** Comme au CH57, aucun pixel : la descente est
  prouvée par états, transforms et signaux. À quoi ressemble un pas de côté
  depuis le deck de la funbox est **inconnu** — c'est la première chose à
  regarder sur device.
* ⚠️ **La parallaxe du sautillon n'est pas mesurée.** Elle est du même
  mécanisme (0,133 u est la lecture au lift de la planche) et le ballon
  porte son propre `BALL_LIFT`. Rien dans ce lot ne le touche ni ne
  l'atteste ; si un jour un véhicule livré peut se tenir sur quelque chose,
  il rejoint `_drawn_ground_point`.
* ⚠️ **La dette de CH57 reste entière** : sous l'interrupteur le hopper est
  `ON_CARRIER`, qui n'émet pas de `hop_landed`, donc **un roulement physique
  ne marque toujours AUCUN point**. Ce lot ne re-score rien — c'est le LOT 2.
* ⚠️ **La sortie du cas « coincé » dépend du stall guard.** Le cas (3) est
  vert parce que `STALL_TICKS` (30) lâche la cible, ce qui rend `at_rest()`
  vrai et donc le self-tap lisible. Un réglage futur de ce garde déplace la
  fenêtre où une descente est possible contre un mur ; la sonde le verra.
* **F n'est toujours pas mesuré.** L'objet de CH57 reste ouvert : il fallait
  pouvoir rester sur la planche pour le lire.
