# CH76 — La Comète reçoit la vue POV, et le patron CH72 devient réutilisable sous une poursuite

*12 septembre 2026. Branche `claude/la-comete-pov-view-7bkx3a`, base
`origin/staging` `3b6ea62` (CH75 doc, un commit après le merge `ab33026`).
Vérifié par ARBRE au `fetch` du début : l'arbre d'`origin/staging` et
celui d'`origin/claude/3rd-coaster-funfair-gc48t2` sont le MÊME
(`7bea701c…`) — la branche CH75 est donc déjà mergée malgré un
`merge-base --is-ancestor` négatif (deux commits de doc divergents, un seul
arbre), et aucune branche distante ne porte un nom voisin du mien. Aucune
session concurrente.*

Brief : La Comète est validée device par Mathieu ce matin ; il manque la
vue POV que les autres manèges du parc ont déjà. **Lot CAMÉRA
uniquement** — ni tracé, ni physique, ni budget triangle touchés.

---

## Section 1 — RECON (bloquante) — et le blocage annoncé était réel

### 1.1 — Le patron POV existant, lu dans le code et pas supposé

Il vient de **CH72** et il est entièrement générique :

| morceau | où |
|---|---|
| la pose | `HubCamera.enter_pov(head, pitch_deg)` / `exit_pov()` / `is_pov()` / `_apply_pov()` |
| le déclenchement | `HubTapInput._handle_point` → `tapped_funfair_rider` → `HubWorld._on_tapped_funfair_rider()` |
| la porte | `HubFunfair.accepts_rider_tap(origin, direction)` — distance perpendiculaire du RAYON au corps ; une fois le POV ouvert, **un tap n'importe où** |
| le tangage | `HubFunfair.pov_pitch_deg(ride)` |
| le retour | `ride_finished` → `HubWorld._on_funfair_ride_finished` → `exit_pov()` |
| le nœud de tête | `KeepyHopper.head_anchor()`, pendu au nœud de LACET |

Rien là-dedans ne connaît un manège en particulier. `running_ride()`
répond déjà `RIDE_COMET`, `head_anchor()` suit le chariot gratuitement via
`follow_carrier()`, et `_handle_point` n'est shunté par aucun des quatre
véhicules pilotés pendant un trajet du parc. **Le canal arrive donc
intact jusqu'à la Comète.**

### 1.2 — `CoasterRail.gd` n'a besoin d'AUCUNE extension, et c'est mesuré dans sa propre doctrine

La question du brief (§3) avait une réponse déjà écrite. `CoasterRail.ride_frame()`
pose le chariot **+Z sur la marche, base droitière (X = Y × Z)**, donc
`global_rotation_degrees.y` se décompose en le cap réel du rail ;
`follow_carrier()` recopie ce lacet verbatim dans `_yaw` ; `head_anchor()`
pend de `_yaw`. La position et le cap de la tête **frame par frame** sont
donc déjà publiés, par construction, depuis CH72 § CHANGE 1.

**Zéro ligne de `CoasterRail.gd` dans ce lot.** Le POV est une affaire de
caméra, pas de rail.

### 1.3 — ⚠️ LE BLOCAGE RÉEL : LE POV N'ÉTAIT PAS « NON CÂBLÉ » SUR LA COMÈTE, IL ÉTAIT **ARITHMÉTIQUEMENT MORT**

CH75 écrit, dans `accepts_rider_tap` :

> *« no POV on the Comet. Its camera is the CHASE, and a POV opened over a
> running drive would be two writers on one camera. »*

La raison invoquée est un **conflit**. La mesure dit autre chose, et c'est
l'inverse : `_apply_pov()` n'est appelé **que dans la branche hub** de
`HubCamera._process` (`_drive_target == null`). La branche drive sort par
`return` sans jamais l'appeler. Sur la Comète, `enter_pov()` aurait donc
posé une tête, tweené un blend jusqu'à 1,0, et **personne n'aurait lu ni
l'une ni l'autre**.

Il n'y avait pas deux écrivains. Il y en avait **zéro**.

C'est la forme de panne la plus trompeuse qui soit : `is_pov()` rend
`true`, `pov_blend()` rend 1,000, aucune erreur n'est poussée, et l'image
ne bouge pas d'un pixel. Ouvrir la porte sans toucher à la caméra aurait
livré exactement ce symptôme.

### 1.4 — ⚠️ ET UNE SECONDE TRAPPE, INERTE TANT QUE LA PORTE EST FERMÉE

```gdscript
static func pov_pitch_deg(ride: int) -> float:
	return 0.0 if ride == RIDE_COASTER else TOWER_POV_PITCH_DEG
```

Une table à **deux branches** pour **trois manèges**. `RIDE_COMET` tombe
dans le `else` et reçoit **16,7°** — le tangage que Ch72Recon R4 a mesuré
pour une **nacelle regardant le hub depuis 14 u**, sur un manège qui ne
regarde rien vers le bas.

Ce n'est pas un défaut expédié : `accepts_rider_tap` refusant la Comète,
cette ligne était **morte**. C'est mon propre lot qui l'aurait armée.
Corrigée dans le même commit, en une branche par manège, pour qu'un
quatrième manège ait à répondre pour lui-même au lieu d'hériter du
tangage de la tour.

---

## Section 2 — CE QUI EST LIVRÉ

### 2.1 — `HubCamera` : le POV se fond sur la pose que la frame VIENT d'écrire

`_apply_pov()` est scindé en deux, sans une virgule d'arithmétique
changée :

* `_pov_idle()` — l'orthographe unique de « aucun POV ne tourne et aucun
  ne s'éteint », parce que deux branches la demandent maintenant ;
* `_blend_pov(base, base_fov)` — le corps CH72, dont la pose de départ est
  désormais **PASSÉE** au lieu d'être supposée ;
* `_apply_pov()` — l'entrée de la branche hub, qui appelle `_blend_pov`
  avec exactement ce que CH72 construisait. **La branche hub est donc
  inchangée dans son effet, ligne pour ligne.**

Et la branche drive gagne **une ligne**, après avoir écrit sa pose et son
fov :

```gdscript
_blend_pov(global_transform, fov)
```

⚠️ **Une BASE, pas une seconde pose.** Il y a toujours **un** écrivain
(`_process`) et **un** blend. Ce qui change est que la pose dont le POV
s'éloigne est celle de la branche courante : depuis le hub la pose fixe,
depuis la poursuite la pose de poursuite. Un tap sur la Comète passe donc
de « au-dessus du chariot » directement « dans les yeux », sans détour par
un cadre au niveau du sol dont le rider est à 14 u. **« Deux écrivains sur
une caméra » est ce que cette forme rend impossible, pas ce qu'elle
risque.**

⚠️ **Et `base` est RECALCULÉE, jamais relue sur la pose vivante** — la
raison que le commentaire de `fov` donne depuis CH72, et qui vaut aussi
fort pour le transform. Les deux sites d'appel la satisfont : la branche
hub lerpe `global_position` vers `_wanted()` avant d'appeler, et la branche
drive passe le `global_transform` qu'elle vient d'assigner depuis
`_hub_position`, `_drive_position` et `_drive_yaw` — dont **aucun** n'est
écrit par `_blend_pov`. Une base relue aurait flué vers le POV à
n'importe quel blend. **Gaté** (PHASE P12b : l'œil s'ÉLOIGNE de la tête
quand le blend tombe).

### 2.2 — ⚠️ UN DÉFAUT QUE CE LOT A INTRODUIT, ET QUE LA SONDE A ATTRAPÉ

`_on_pov_exited()` rendait le fov par `fov = _hub_fov`, **sans
condition** — juste, et documenté comme tel, tant que le POV ne se
superposait qu'à la pose fixe. Sur une poursuite c'est faux : la branche
drive **possède** le fov tant qu'un chase tourne et le réécrit chaque
frame, donc ce `fov = _hub_fov` peint le **45 du hub par-dessus le 64 de
la Comète**.

Mesuré, pas raisonné : `CometProbe` P12 a lu **exactement 19,00000** de
dérive sur la frame où le fondu se termine, et 19,0 est
`COASTER_FOV − hub_fov` au chiffre près. Laissé en place, c'était un
**pop de fov visible** à chaque fois qu'un joueur sort du POV en cours de
trajet.

Le garde porte sur le **DRIVE**, pas sur le blend : tant que
`_drive_target` est posé, la branche drive fait converger le fov vers
`_hub_fov` toute seule et `_on_drive_exited` fait la même restitution
exacte depuis la même valeur capturée. Le fov est donc rendu exactement
dans les deux cas ; ce qui change est **QUI le rend**.

### 2.3 — `HubFunfair` : la porte s'ouvre, et le tangage devient explicite

* `accepts_rider_tap` ne refuse plus la Comète. La moitié de la note CH75
  qui reste vraie est celle qui rend la porte SÛRE : sous la poursuite
  aucun pixel fixe ne veut dire « lui », donc la **sortie** est un tap
  n'importe où — ce que la ligne `_pov_on()` accordait déjà, précédent
  CH64 de la planche, inchangé. L'**entrée** est un tap sur le RAYON qui
  passe par son corps, et sous CETTE poursuite c'est un geste fiable et
  non un coup de chance : la pose vise le chariot à chaque frame
  (`ChaseTuning.coaster`'s `look_target`), donc le rider est près du
  milieu de l'image pendant tout le trajet.
* `pov_pitch_deg` : une branche par manège. La Comète prend **0,0°** — la
  réponse du coaster CH71, pour la raison du coaster CH71 : le rail
  fournit tout le mouvement, et un tangage qui le combattrait est le terme
  qui rend malade. Mesuré sur le chariot ridé, pas supposé.

**Ce que ce lot NE touche pas** : `CoasterRail.gd`, le tracé, la physique,
le budget, `HubWorld`, `HubTapInput`, `CozyScatter`, `DevTools`.

---

## Section 3 — LE POV EST LEVEL, ET CE QUE ÇA DONNE EST MESURÉ

Un banc ne signe pas un confort (CH62). Ce qu'il peut dire de la vue de
niveau, il le dit, par phase, sur le trajet complet :

| phase | frames | part du bas de l'image qui résout au SOL | rails en vue dans 8 u |
|---|---|---|---|
| 2 — LIFT (chaîne) | 685 | **100 %** | jusqu'à 9 |
| 3 — COAST (crête, descente, camelback) | 135 | **100 %** | jusqu'à 10 |
| 4 — TRIM | 28 | **100 %** | jusqu'à 1 |
| 5 — BRAKE (virage bas, gare) | 209 | **100 %** | jusqu'à 7 |

⚠️ **Le rayon CENTRAL aurait été un instrument dégénéré**, et c'est
pourquoi la mesure descend dans l'image. À tangage 0, `_pov_wanted` vise
**exactement** le niveau, donc le rayon central est parallèle au plan et
`HubSurface.intersect_ray` rend `null` à **toutes** les frames — par
arithmétique, pas par mesure. Cinq rayons à 55 → 95 % de la hauteur du
cadre posent la question qui a une réponse : *combien de ce qu'il voit
est du monde*. Réponse : **100 %, partout**, à fov 58 sur 540×960 (le
bas du cadre regarde 44,6° vers le bas).

**Aucune structure ne traverse l'œil.** L'œil n'est **jamais** dans un
solide du parc (0 frame sur 1 057) et le rail le plus proche passe à
**0,917 u** — sur le treuil, à `s 16,30`, et c'est une **autre** section
de la boucle (`(22,92 ; 11,37 ; 54,10)`), pas celle qu'il ride : l'œil
roule à 1,89 u au-dessus de son propre rail, donc tout ce qui est sous
1,89 est du décor voisin. Plancher gaté : 0,60 u, contre un plan proche de
0,050. **Marge 0,317 u** — dite, pas cachée.

⚠️ **Le roulis est nul UNE FOIS LES DEUX FONDUS FINIS, et c'est une passe
rouge qui l'a précisé.** Sur 1 057 frames tenues, pire roulis
**0,0000°**. Mais la passe rouge 1 (POV débranché sous la poursuite) a
rendu **7 rouges pour 6 prédits**, et l'extra est **P7 à 0,2738°** : la
pose de poursuite elle-même porte un tiers de degré de roulis **pendant
son propre fondu d'entrée**, parce que `hub_xform.interpolate_with(
drive_xform, _blend)` slerpe entre deux bases de lacets ET de tangages
différents. Le POV hérite donc de ce que sa base porte pendant un fondu :
au plus les 0,27° que la poursuite avait **déjà avant ce lot**, et
exactement zéro dès que la poursuite est établie. Transitoire, sous le
degré, préexistant — publié plutôt que gommé.

---

## Section 4 — CE QUE ÇA COÛTE : MÊME RUN, MÊME BANC, MÊME TRAJET

La question du brief se répond par une comparaison de **deux trajets
entiers**, pas par un échantillon. `CometProbe` PHASE E ride la Comète
sous la poursuite et publie ses primitives et son temps de frame ; PHASE P
la ride **une seconde fois dans le même run**, POV tenu de la gare au
run-out, et publie les deux mêmes grandeurs.

| | poursuite (PHASE E) | POV (PHASE P) |
|---|---|---|
| frames mesurées | 1 147 | 1 057 |
| primitives max | 85 321 | **85 344** (+0,03 %) |
| primitives moyennes | 36 558 | **35 329** (−3,4 %) |
| temps de frame moyen | 34,72 / 36,70 ms | **31,71 / 32,47 ms** |
| temps de frame pire | 66,62 / 80,10 ms | **66,00 / 67,38 ms** |

⚠️ **Les millisecondes sont un chiffre de SANDBOX et la sonde le dit
elle-même dans sa sortie.** llvmpipe est un rastériseur logiciel ; ce
n'est pas le temps de frame du téléphone et aucune lecture ne le rend. Ce
qui est utilisable est le **RAPPORT**, pris sur le même banc, sur le même
trajet, dans le même run : deux runs indépendants donnent le POV **8,7 %
puis 11,5 % moins cher en moyenne** et à égalité sur le pire.

**Conclusion mesurée : le POV ne coûte rien de plus que la poursuite, et
un peu moins.** C'est attendu — la poursuite se tient 6,2 u au-dessus du
rail et voit plus de parc que des yeux au niveau du rail — mais c'était à
mesurer, pas à supposer. Les 31 FPS / 51-52 k triangles GPU du screenshot
device de Mathieu sont une mesure de SON appareil sous la poursuite ; ce
lot ne peut pas la reproduire, il peut seulement établir que le POV n'est
pas plus lourd que ce qu'elle décrit.

⚠️ **Et la ligne de visée est une question DIFFÉRENTE en POV.** CH75
publiait 61 frames sur 1 147 où un rail traverse la ligne caméra→chariot.
En POV il n'y a pas de « ligne vers le sujet » : le sujet est l'œil. La
question qui a un sens est *est-ce qu'une structure passe À TRAVERS
l'œil* — réponse 0 frame dans un solide, 0,917 u de rail le plus proche —
et *combien de rail est dans l'image*, publié par phase ci-dessus. Un
rail dans l'image n'est pas un défaut en POV : c'est le manège.

---

## Section 5 — `CometProbe` PHASE P (permanente, xvfb + opengl3, jamais headless)

**24 assertions neuves** (P0 → P24, P12 dédoublée), toutes par
`HubTapInput._handle_point` depuis un point d'écran réel. `enter_pov` et
`exit_pov` ne sont appelés **nulle part** dans la sonde — dix-huitième
faux-signal du dépôt, évité par construction.

⚠️ **C'est un SECOND trajet, délibérément.** Un seul trajet ne peut pas
être les deux caméras sur toute sa longueur, et la question posée est une
comparaison de deux trajets entiers.

⚠️ **Et le test des portes va dans le TREUIL, pas dans la descente, et
c'est mesuré.** Sortir puis rentrer coûte `2 × POV_BLEND_S` = 54 frames.
La descente (COAST) fait **135 frames** sur cette boucle : y dépenser 40 %
de la seule section pour laquelle le manège existe aurait fait décrire un
fondu au lieu d'une vue. Le treuil fait **685 frames** et chacune est la
même image.

Ce que PHASE P signe : que la porte répond (P3), qu'**un** geste livré
**deux fois** ouvre le POV **une** fois et l'y laisse (P4), que la
poursuite est **toujours le drive dessous** (P5 — la forme du lot en une
lecture), que la caméra est **SUR** le nœud de tête à 0,0000 u alors qu'un
chase tourne (P6/P16 — ce que la surimpression CH72 ne pouvait pas
faire), qu'elle ne roule pas et ne tangue pas (P7/P17/P18), que la sortie
est un tap sur le **HAUT de l'écran** où un œil de niveau ne vise aucun sol
(P10 — le gate patron-ÉCHELLE, et sur ce manège ce n'est pas une
formalité : la moitié haute de l'image vise l'horizon ou au-dessus), que
le fondu obéit aux blends publiés (P12), que le trajet **continue** à
travers la bascule (P11/P14), ce que l'œil traverse (P19/P20), et que le
POV ne survit **jamais** au trajet (P22/P23).

Ce qu'elle NE signe pas : que le point de vue soit **confortable**, que la
sensation de vitesse soit là, que 58 de fov soit le bon nombre, que
regarder droit devant pendant une chute à 72° se lise comme une chute.
Appel device de Mathieu, et c'est écrit en tête du fichier de sonde.

### 5.1 — ⚠️ E20 A ÉTÉ RÉ-VISÉE, PAS RELÂCHÉE NI FAITE TAIRE

CH75 gatait `E20 a tap on the rider mid-drop opens no POV under the
chase`. Ce lot ouvre exactement cette porte : l'arbre livré **ne peut pas**
satisfaire les deux. La propriété qui survit dessous est celle-ci — *le
canal répond pour LUI et pour personne d'autre* — et c'est ce que E20
gate désormais, en lisant le prédicat **et** son négatif (le même rayon
vers le sol nu doit rendre `false`).

⚠️ **Et la bascule n'est plus DISPATCHÉE dans PHASE E.** Un POV ouvert en
pleine descente aurait mis toutes les lectures de poursuite situées plus
bas dans cette phase — le compteur de primitives, la couronne de E10, les
dégagements de E11, le lacet de E23 — **sous la mauvaise caméra**, et
PHASE E aurait cessé de décrire la poursuite. La porte se lit dans E, la
bascule se fait dans P.

### 5.2 — ⚠️ UN SEUIL REMPLACÉ PAR UN ENCADREMENT, PARCE QUE LE PLANCHER DU BANC LE DEMANDAIT

La première rédaction de P12 comparait `fov` à l'attente construite sur
les blends **lus après la frame**, et est sortie ROUGE à **0,34887** sur
un arbre correct. `fov` est écrit dans `_process` et le tween avance
ailleurs dans la même frame : la valeur vivante porte légitimement le
blend de la frame **précédente**. Une frame d'un fondu sinusoïdal de
0,45 s à travers 58 → 64, c'est environ un tiers de degré — exactement ce
qui a été mesuré. **Un artefact d'instrument, pas un défaut.**

`CLAUDE.md` est explicite : on mesure le plancher, on n'élargit pas un
seuil jusqu'à ce que le bruit tienne dessous. **Encadrée entre les deux
attentes consécutives**, la dérive ne peut plus produire de lecture du
tout (mesuré : **0,00000**) et il n'y a **aucun nombre à régler** — le
défaut pour lequel P12 existe lit **13 degrés HORS** de l'encadrement
(le 45 du hub contre une attente qui ne quitte jamais 58..64), contre un
epsilon de 0,01. La passe rouge 2 le confirme : **19,00000**.

### 5.3 — ⚠️ QUATRE VERTS GRATUITS, TROUVÉS EN ÉCRIVANT LA PASSE ROUGE AVANT DE LA LANCER

P16, P17, P18 et P20 lisent des grandeurs qui n'existent **que si le POV
s'est ouvert**, et chacune a un initialiseur qui satisfait son propre
seuil : `head_worst` et `roll_worst` partent de `0.0`, `eye_rail_worst`
part de `INF`. Sans POV tenu ce ne sont pas de petites lectures, ce sont
**aucune lecture** — et les quatre auraient imprimé VERT. (`CLAUDE.md`
CH69 : *« toute grandeur qui n'a de sens qu'APRÈS un événement se publie
avec le booléen "l'événement a eu lieu", et le gate exige les DEUX »*.)

Trouvé en **prédisant** la troisième passe rouge, avant de la lancer.
Corrigé par un `measured := held > 600` porté par les cinq (P19 compris).
La passe rouge 3 l'a ensuite confirmé au chiffre : les cinq impriment
`0 frames`, `worst 0.0000`, `nearest inf` — et rougissent.

---

## Section 6 — TROIS PASSES ROUGES

| # | neutralisation | prédits | obtenus |
|---|---|---|---|
| 1 | `_blend_pov(global_transform, fov)` retiré de la branche drive (le cœur du lot) | 6 — P6, P8, P9, P12, P16, P18 | **7** — les six, **plus P7** |
| 2 | le garde de `_on_pov_exited` retiré (le `fov = _hub_fov` inconditionnel revient) | 1 — P12 | **1** — P12 à **19,00000** |
| 3 | l'exclusion CH75 de la Comète remise dans `accepts_rider_tap` | 14 — E20, P3, P4, P6, P7, P8, P9, P13, P14, P16, P17, P18, P19, P20 | **14**, exactement |

Le fichier a été restauré après chaque passe et vérifié **byte-identique**
par `cmp` (`HubCamera.gd` deux fois, `HubFunfair.gd` une fois).

⚠️ **L'extra de la passe 1 est une trouvaille, pas un haussement
d'épaules** — le nombre d'échecs attendus fait partie de l'assertion. P7
(roulis < 0,01°) rougit à **0,2738°** parce que la pose de poursuite, à
`_blend` 0,987, porte ce roulis-là : un slerp entre la base du hub
(tangage 34°) et la base du chase n'est pas sans roulis en chemin. C'est
la propriété décrite en §3 : le roulis exactement nul du POV est un fait
sur la pose ÉTABLIE, et le POV hérite du fondu de sa base pendant un
fondu. Préexistant à ce lot, sous le degré, transitoire — et maintenant
écrit.

---

## Section 7 — TABLE CROISÉE SUR DEUX ARBRES

`HubCamera` est un mode PARTAGÉ (kart, char à voile, voilier, planche,
tour, coaster CH71, orbite CH73) : `CLAUDE.md` impose de rejouer la table
des sondes existantes sur les DEUX arbres, jamais sur la branche seule.

Arbre de référence : `origin/staging` `3b6ea62` dans un worktree séparé,
importé à part. **154 `.scn` des deux côtés** — le compte que CH70, CH72
et CH73 publient, donc aucun import tronqué d'aucun côté.

| sonde | driver | branche | `origin/staging` `3b6ea62` | verdict |
|---|---|---|---|---|
| `FunfairProbe` (le patron POV de référence : tour + coaster CH71) | xvfb | **116 OK / 0 rouge** | **116 OK / 0 rouge** | parité, tout vert |
| `OrbitCameraProbe` (CH73) | xvfb | **56 ok / 0 rouge** | **56 ok / 0 rouge** | parité, tout vert |
| `CabinProbe` (le canari de régression caméra) | xvfb | **8 échecs** | **8 échecs** | **lignes IDENTIQUES** (`diff` vide), préexistants |
| `KartProbe` (la branche drive) | headless | **150 checks, 1 échec** | **150 checks, 1 échec** | ligne identique (`chrono panel centred -- 977.0`), préexistante |
| `CometProbe` | xvfb | **99 OK / 0 rouge** (24 assertions neuves) | **73 OK / 0 rouge** (sans PHASE P) | tout vert des deux côtés |
| `ProbeTimeoutAudit` | headless | **101 scènes** | **101 scènes** | inchangé — aucune sonde neuve, PHASE P vit dans `CometProbe` |
| `.scn` importés | — | **154** | **154** | aucun import tronqué d'aucun côté |

⚠️ Les 8 rouges de `CabinProbe` et le rouge de `KartProbe` sont
**préexistants et prouvés tels par la parité**, pas par un jugement : les
lignes sont byte-identiques des deux côtés. (CH73 avait déjà mesuré que
`CabinProbe` ne se reproduit pas sur un seul arbre ; ici les deux runs
sortent le même jeu.)

---

## Section 8 — LE DÉPLOIEMENT, LU SUR LE SERVICE

CI `web-build.yml` run **530**, `conclusion: success`, `completed_at`
**02:04:03Z**. Étape `Export Web build` : **02:03:24 → 02:03:32Z**, soit
l'epoch **1789178604 → 1789178612**. Alias posé à 02:04:01 sur
`keepy-emm886mp2-…`.

**`CACHE_VERSION` servi = `1789178611`** — **à l'intérieur de la fenêtre
de l'étape d'export**, lu sur `https://keepy-staging.vercel.app` avec
**`x-vercel-cache: MISS` et `age: 0`**, la seule lecture qui compte. Le
build servi par l'alias de staging EST celui de ce merge.

`index.wasm` n'a pas été relu : ce lot ne touche aucun code moteur, donc
la constante d'identité publiée (35 376 909 octets) est **attendue**
inchangée — attendue, pas mesurée, et c'est dit plutôt que affirmé.


Le rayon d'action réel des lignes changées est petit et se lit dans le
code : la ligne ajoutée à la branche drive sort sur `_pov_idle()` à sa
première instruction, et `_pov_head` ne peut être posé que par
`enter_pov`, appelé du seul `_on_tapped_funfair_rider`. Sur tout arbre où
personne n'ouvre un POV, **la totalité de ce lot est arithmétiquement
inerte.** La table croisée est là pour le prouver plutôt que pour
l'affirmer.

---

## Section 9 — CE QUE CE LOT NE PEUT PAS SIGNER (l'appel device)

Une sonde ne juge pas un game feel (CH62). Rien ici ne dit :

* si la vue de niveau, sur une descente à **72,2°**, se lit comme une
  chute ou comme un ascenseur — le tangage est le SEUL levier que la
  doctrine CH72 laisse (un nombre par manège) et il vaut 0,0 ;
* si **fov 58** est le bon nombre à l'intérieur d'une tête qui va à
  16 u/s (la poursuite est à 64, le hub à 45) ;
* si les **685 frames de treuil** en POV, à 2,2 u/s, sont une attente
  délicieuse ou une attente ;
* si le rail à **0,917 u** de son visage sur le treuil est un frisson ou
  une gêne ;
* si le fondu de **0,45 s** entre la poursuite et les yeux est une
  transition ou un saut ;
* si la sensation de vitesse est meilleure ou pire qu'en poursuite ;
* si le POV donne la nausée. Le roulis est **prouvé nul** sur la pose
  établie, ce qui est la moitié mesurable de cette question ; l'autre
  moitié est un estomac.

Ce que les mesures couvrent, et qui n'a donc plus à être jugé à l'œil :
le coût (§4), le clipping et ce que l'œil traverse (§3), le câblage, les
deux portes, et le fait que le POV ne survit pas au trajet.
