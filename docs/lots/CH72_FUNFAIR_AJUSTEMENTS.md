# CH72 — Ajustements du parc d'attractions

*11 septembre 2026. Branche `claude/ch72-funfair-adjustments-a2i9f0`,
base `origin/staging` `043d6d9` (merge CH71).*

Trois demandes de Mathieu après le device test de CH71 : Kippy regarde
en arrière sur le chariot, la tour de chute est trop basse pour offrir
une vue, et il voudrait pouvoir passer en vue subjective pendant un
trajet. Les trois ont été traitées ; la recon en a **réfuté une prémisse
et en a déplacé une autre**, et c'est écrit ici avant le reste.

---

## Section 1 — RECON (bloquante, faite avant toute ligne de code)

`Ch72Recon.gd`, sonde jetable, lancée sous `xvfb + opengl3`, supprimée
avant le commit. Contrôle d'instrument en tête (R0) : rect du conteneur
540×960 réel, **5 217 couleurs distinctes** dans la frame, **2 583 /
2 583 transforms de `MultiMesh` non-identité** — donc pas le driver
dummy, et rien en dessous ne passe gratuitement.

### 1.1 — L'arbre de départ

`git fetch --all --prune`. `origin/staging` = `043d6d9`, arbre
`51522f0`. **L'arbre de la branche CH71 est byte-identique à celui de
staging** (`51522f0` des deux côtés) — CH71 est entièrement mergé, aucune
session concurrente, aucune divergence. Le HEAD local était en retard
d'un lot (CH70) et a été rebasé sur `origin/staging` **avant** de coder.

### 1.2 — L'orientation de Kippy : 180,00°, mesurés sur 900 frames

Mesure sur un **vrai trajet**, lancé depuis un **point d'écran** à
travers `HubTapInput._handle_point`, en lisant la colonne +Z du nœud
`Yaw` de Keepy (son modèle regarde +Z à lacet nul) contre la tangente du
rail à l'abscisse où le chariot se trouve réellement, **à chaque frame** :

| lecture | valeur |
|---|---|
| première frame | **180,00°** |
| minimum | 90,07° *(une seule frame — voir 4.2)* |
| moyenne | **179,90°** |
| maximum | **180,00°** |

Il montait la côte, prenait les deux virages et descendait la drop
**entièrement à l'envers**. La cause est arithmétique et tient en une
ligne : `_pose_cart` posait le chariot par `Basis.looking_at(t, UP)`,
qui met **−Z** sur la tangente ; `follow_carrier` recopie le lacet du
porteur verbatim et le modèle regarde **+Z** ; donc le rider regardait
`−t`, exactement.

Sur la tour, en revanche, il regarde le joueur à **0,14°** près — rien à
corriger là, et c'est désormais gaté.

### 1.3 — Les clairances et le budget AVANT, reproduits au chiffre près

| grandeur | CH71 publie | CH72 mesure |
|---|---|---|
| tour vs empreintes layout | 0,885 | **0,885** (buisson (29,87 ; 7,14)) |
| rails bas vs empreintes layout | 1,338 | **1,338** |
| rail le plus proche vs câble tyrolienne | 3,367 | **3,367** |
| `KEEPY_CLEARANCE` | 0,660 | **0,660** |
| triangles du parc | 4 068 | **4 068** |

Deux mesures que CH71 n'avait jamais faites et dont ce lot avait besoin :
**jambes de la tour vs la ligne du câble (à plat) = 4,310 u**, et
**instance de semis la plus proche de la tour = 2,290 u** à (32,08 ;
10,60).

Budget, arbre de départ, sonde identique : `gpu` 70 592 au spawn,
84 844 à la pire station CH22, **70 699 / 67 828 / 64 626** aux trois
stations du parc. Le plafond de 50 k du dépôt était donc dépassé de
**+41 % / +36 % / +29 %** *avant que ce lot pose un triangle*.

### 1.4 — Le plafond caméra, relu et non recalculé (règle CH36)

Bissection sur la colonne de l'aplomb de la tour, sur la caméra livrée :
le haut du cadre la coupe à **y = 7,9679**, contre les **7,968** que
`HubCamera.FRAME_TOP_AT_APLOMB` publie — accord à 1e-4. Le siège le plus
haut qu'une caméra FIXE peut montrer vaut donc **5,8679**, et la nacelle
CH71 culminait à 5,220 : il restait **0,648 u** de marge.

**Et la mesure qui a débloqué tout le lot** : on lève la caméra de `dy`
et le rider du même `dy`, et on relit où atterrit sa tête.

| caméra levée de | rider à y | tête à l'écran |
|---|---|---|
| +0,0 | 5,100 | (270, 121) |
| +3,0 | 8,100 | (270, 121) |
| +6,0 | 11,100 | (270, 121) |
| +10,0 | 15,100 | (270, 121) |
| +14,0 | 19,100 | (270, 121) |

**Le cadrage est INVARIANT** — identique à quatre chiffres sur toute la
plage. Le plafond cesse d'être un mur dès lors que la caméra monte avec
la nacelle. `CLAUDE.md` disait déjà que la réponse à « je veux plus haut
que ça » est « une caméra qui monte, c'est-à-dire un autre lot » : CH72
est ce lot.

### 1.5 — ⚠️ CE QUE LE RENDU A RÉFUTÉ

Le brief demandait de vérifier si des arbres ou du relief bouchent la vue
et, si oui, de proposer un déplacement du site. **Mesuré par rendu**,
caméra posée à la nacelle, trois caps, six hauteurs :

| y nacelle | ciel/brume dans la frame | l'œil touche le sol à | props layout dans le cadre (ouest) |
|---|---|---|---|
| 5,10 | 0,0 % | 24,0 u | 158 |
| 8,00 | 1,1 % | 34,0 u | 160 |
| 11,00 | 1,1 % | 44,5 u | 160 |
| 14,00 | 1,1 % | 55,0 u | 160 |
| 17,00 | 1,3 % | 65,5 u | 159 |
| 20,00 | 1,4 % | 76,0 u | 157 |

**(a) RIEN NE BOUCHE LA VUE, à aucune hauteur.** Pas un tronc, pas une
crête : la bande de ciel ne dépasse jamais 1,4 % de l'image. La prémisse
« il y a peut-être un mur » est fausse, **le site n'a pas été déplacé**,
et le lot n'a pas dépensé un commit là-dessus.

**(b) LA HAUTEUR N'ACHÈTE QUE DE LA PORTÉE.** Le compte de props dans le
cadre est **PLAT** (158 → 160 sur toute la plage) : ce qui décide de ce
qu'on voit est le **CAP**, pas l'altitude. Ce qui grandit vraiment, et
linéairement, c'est la distance que l'œil atteint : ≈ 3,5 u de portée par
unité de hauteur.

**Donc le plafond de la tour est la BRUME, pas la géométrie.** À
`CozyPalette.HAZE_DENSITY` (0,022), un objet garde 59 % de lui-même à
24 u, 38 % à 44,5, **30 % à 55**, 24 % à 65,5, 19 % à 76. Au-delà de
~55 u, le sol neuf qu'une tour plus haute achète est plus du ton du ciel
que du sol. **14,0 est le dernier échelon dont la portée tombe encore là
où un tiers de l'image survit.**

---

## Section 2 — CHANGEMENT 1 : l'orientation

Un publieur neuf, `HubFunfair.ride_frame(s)` : origine sur le rail,
**+Z sur la tangente**, base **droitière par construction** (`X = Y × Z`,
l'identité que la base de lacet de Godot satisfait), donc
`global_rotation_degrees.y` se décompose bien sur le cap du rail. Rien
n'est codé en dur sur cette boucle : on déplace un point de contrôle et
la pose suit.

### ⚠️ 2.1 — Un second défaut trouvé au passage : `track_frame` est MIROIR

`track_frame()`, qui pose les rails depuis CH71, construit
`right = t.cross(UP)` — c'est la **GAUCHE** de la marche, pas la droite —
et sa base a un **déterminant de −1**. Vérifié numériquement puis gaté
(K0/K1).

C'est **inoffensif pour les rails et l'a toujours été** : ils sont posés
symétriquement autour de l'axe (−gauge/2 et +gauge/2), donc échanger
gauche et droite ne fait que les renommer, et un tube à six pans balayé
autour d'un axe radial retourné est le même hexagone tourné. Mais **une
base miroir donnée à un `Node3D` n'est pas une rotation** et le lacet que
Godot en décompose ne veut rien dire. Les deux frames sont désormais des
choses distinctes, nommées, et **la distinction est gatée** plutôt que
laissée à un commentaire.

### 2.2 — Résultat

| | avant | après |
|---|---|---|
| première frame | 180,00° | **0,00°** |
| pire frame sur 899 | 180,00° | **0,03°** |
| frames au-delà de 90° | 899 / 899 | **0 / 899** |

---

## Section 3 — CHANGEMENT 2 : la tour

**Nacelle 5,10 → 14,00 u** (×2,75 la course), **structure 6,60 → 15,50**
(×2,35). Site **inchangé** (§1.5a).

### 3.1 — Trois constantes cessent d'être des littéraux

CH71 tapait une VITESSE de montée (0,9 u/s) et une HAUTEUR de freinage
(1,6). Les deux sont des orthographes d'une hauteur qui vient de changer :
laissées telles quelles, elles auraient expédié **une montée de 15,1 s**
et **un arrêt à 10,8 g**. Ce qu'un joueur ressent est une **durée** et une
**décélération** — donc c'est cela que le fichier publie, et les vitesses
suivent.

**Le ratio de freinage n'est pas inventé : c'est celui de CH71, relu.**
Avec `H = TOP − REST` et un freinage sur les `d` derniers mètres,
l'énergie donne `decel = GRAVITY · (H − d) / d`. Le 1,6 de CH71 sur une
chute de 4,65 u fait `d = 1,15`, donc `decel / GRAVITY = 3,0435` — le
« 3,04 g » que son propre en-tête cite. Inversé, `d = H / (1 + 3,0435)`,
qui **rend 1,59999 à la hauteur de CH71**. L'arrêt reste donc exactement
aussi ferme que celui validé device, à n'importe quelle hauteur.

Même discipline pour la treille : `tower_brace_levels()` **reproduit
exactement `[2.2, 4.2, 6.2]`** à 6,6 u, et rend 7 anneaux à 15,5.

| | CH71 | CH72 |
|---|---|---|
| chute totale | 4,65 u | **13,550 u** |
| début du freinage | 1,600 (tapé) | **3,801 (dérivé)** |
| décélération | 3,04 g | **3,0435 g** (mesuré 3,0435) |
| vitesse de chute atteinte | −8,28 u/s | **−14,21 u/s** |
| montée | 0,9 u/s / 5,17 s | **1,936 u/s / 7,0 s** |
| maintien en haut | 1,6 s | **2,4 s** |
| anneaux de treille | 3 | **7** |

Le maintien allongé est un **choix de ressenti déclaré**, lié à la raison
d'être du changement : un sommet qui montre enfin quelque chose mérite
qu'on y reste. Il est à Mathieu de le bouger, pas à un banc.

### 3.2 — Toutes les clairances revalidées à la nouvelle hauteur

L'emprise au sol ne bouge pas d'un millimètre — la tour grandit
verticalement — mais le brief demande de ne pas le supposer :

| gate | mesure | seuil |
|---|---|---|
| L5 tour vs empreintes layout | **0,885 u** | ≥ 0,660 |
| L6 jambes vs ligne du câble | **4,310 u** | ≥ 1,5 |
| L7 bord est de la tour (x 34,90) | dans la région | — |
| L8 semis le plus proche | **2,290 u** | ≥ 1,90 (empreinte réservée) |

Aucun arbre du mur n'a été touché, aucun prop supprimé, la région n'a pas
bougé, la pire traversée du hub est celle que CH67 a laissée.

### 3.3 — ⚠️ A7 et A8 sont RÉ-VISÉES, pas relâchées

CH71 demandait « le siège est-il sous le plafond FIXE » — il le devait,
la caméra ne montait pas. La tour CH72 est délibérément **8,13 u
au-dessus** de ce plafond : garder la question aurait laissé soit un
rouge permanent, soit un gate qu'on fait taire, et `CLAUDE.md` interdit le
second sans appel.

La propriété qui survit à la hauteur est demandée à la place : **le ride
ne se tient jamais plus haut que le lift qu'il demande** — `siège − lift
≤ plafond`, ligne **identique à celle de CH71 dès que le lift est nul**,
c'est-à-dire pour le chariot (A6, intacte) et pour tout autre ride du
hub. Et `A8b` est le blind check : la tour demande réellement un lift de
**13,550 u**, sinon A7 et A8 seraient les lignes de CH71 par accident.

---

## Section 4 — CHANGEMENT 3 : le double mode caméra

Par défaut, la caméra fixe, inchangée, sur les deux attractions. Un tap
sur Kippy **pendant un trajet** passe à ses yeux ; un tap n'importe où
revient. Le trajet continue.

### 4.1 — Le lift n'est pas D6, et le POV est une exception ÉCRITE

Le **lift** est un offset vertical borné ajouté à la **cible** du lerp de
la pose fixe — la forme exacte du ride mode CH62. Il ne lace pas, ne fait
pas de `look_at`, ne retarde aucun cap, ne touche pas `far`, et
`_hub_basis` n'est jamais écrit : l'horizon ne peut pas bouger. C'est un
**OFFSET, pas une variable d'ombre** (la discipline qu'un lot a déjà
cassée contre `CabinProbe`).

Le lerp le fait **traîner** derrière la nacelle : mesuré, **2,398 u au
pire** sur une chute à 14,2 u/s. Le rider glisse donc vers le bas du
cadre au départ de la chute et la caméra le rattrape — et sa tête ne
sort **jamais** (0 frame sur 713).

Le **POV** est une exception nouvelle à la doctrine caméra et elle est
écrite dans `CLAUDE.md`, pas laissée implicite. Le critère de la table
(« le joueur choisit la direction frame par frame ») reste **faux** ici :
ce qu'un tap achète est un point de VUE sur une trajectoire que le rider
ne pilote pas, et le défaut reste la pose fixe.

La pose est **la tête et rien d'autre** — `KeepyHopper.head_anchor()`,
accroché au nœud `Yaw` (jamais au slot du modèle, qui porte le tangage,
l'écrasement et l'échelle). Tout ce qu'un porteur fait atteint donc les
yeux gratuitement : un POV sur le chariot regarde où va le chariot sans
que la caméra sache qu'un chariot existe.

**Lacet seulement, reconstruit ici** : l'horizon est rebâti depuis le cap,
donc aucun futur écrivain sur ce nœud ne peut incliner l'image. Mesuré :
**roulis 0,0000°**. Le seul tangage est celui que le ride demande — nul
sur le chariot, **16,7° vers le bas** sur la tour, qui est l'angle
réellement mesuré en §1.5.

### 4.2 — ⚠️ Trois pièges fermés, dont deux auraient expédié le patron ÉCHELLE

**(a) Un doigt arrive DEUX fois.** `emulate_mouse_from_touch` vaut `true`
par défaut : un tap produit un relâchement tactile **et** un relâchement
souris synthétisé, dans la même frame. Une bascule lue deux fois est une
bascule qui ne bouge jamais. Un debounce de 3 frames le ferme, et la
sonde **envoie délibérément le geste deux fois** pour le gater (M3).

**(b) Le canal du rider est interrogé AU-DESSUS du retour horizon, et
cette position porte tout le poids.** Sous le POV la caméra est la tête
du rider, et un rayon passant par la bande haute de l'image vise l'horizon
ou au-dessus — là où `HubSurface.intersect_ray` rend `null` et où
`_handle_point` abandonne trois lignes plus loin. Chacun de ces taps aurait
été avalé, **et ce tap est la seule sortie du POV** : un joueur qui
regarde le ciel aurait été enfermé dans ses propres yeux, le menu toujours
réactif — le défaut expédié de CH58, à la virgule près. La sonde tape
**le haut de l'écran** exactement pour ça (M10) ; un tap sur la bande
basse serait passé dans les deux cas.

**(c) Le POV ne survit jamais au trajet.** Laissé ouvert, le joueur
arpenterait le plateau depuis l'intérieur de sa tête, et le canal de tap
— gaté sur `is_riding()` — ne pourrait plus l'éteindre.

### 4.3 — Le test « tap sur Kippy » se fait sur le RAYON, et c'est mesuré

`CLAUDE.md` CH58 dit qu'un tap sur un corps surélevé se teste contre son
point sol **DESSINÉ**. Cette règle a été écrite pour une planche à 0,85 u,
où l'écart est centimétrique. Sur cette tour elle s'effondre :

| station | point sol des pieds | point sol de la tête | étalement |
|---|---|---|---|
| sommet CH71 (sans lift) | z −28,4 | z −99,5 | **71,1 u** |
| sommet CH72 (avec lift) | z −26,8 | z −35,3 | **8,5 u** |

**Il n'existe aucun disque qui soit « lui ».** La distance perpendiculaire
de son corps au rayon du tap n'a aucun de ces termes : un corps de rayon
r est touché exactement quand le rayon passe à moins de r, à toute
hauteur, sous tout lift, sans parallaxe. C'est l'instrument que
`HubTrees.tree_hit` utilise déjà pour une couronne, dans la même fonction.

Et **sous le POV, c'est un tap N'IMPORTE OÙ** — le précédent CH64 de la
planche, mot pour mot : sous une caméra où aucun pixel ne veut dire
« lui », le geste est un tap partout.

---

## Section 5 — VALIDATION

`FunfairProbe` étendue de trois phases (K, L, M), **+37 assertions**.
Tous les trajets sont lancés par le **canal du joueur** (`_handle_point`
depuis un point d'écran) ; `enter_pov` n'est jamais appelé par la sonde.

### 5.1 — ⚠️ La météo est épinglée, et c'est une mesure qui l'a exigé

PHASE C, G et H lisent des pixels ou des primitives et prennent toutes un
plancher de bruit en relisant deux fois la même frame en pause. Or
**`paused` n'arrête pas le `TIME` d'un shader** (CH48) : la pluie, l'orage
et la neige traversent la pause. `CozyWeather.CYCLE` fait 70 s de soleil
puis 40 de pluie, 30 d'orage, 50 de soleil, 40 de neige — et les trois
phases neuves de CH72 allongent assez la sonde pour sortir du soleil
d'ouverture.

**Mesuré, même station, deux arbres : plancher 347 px sur la baseline,
24 752 px sur la branche — un facteur SOIXANTE-DIX**, sur un instrument
dont le métier est d'être plus silencieux que son sujet. Le parc peignait
*plus* de pixels qu'avant (64 511 contre 24 899) ; c'est la **règle** qui
avait molli. Météo épinglée au soleil pour toute la sonde, plancher
retombé à **556 / 152 / 456** — l'ordre de grandeur de la baseline.

### 5.2 — Passes rouges, chacune avec son compte PRÉDIT AVANT

| neutralisation | rouges prédits | rouges obtenus |
|---|---|---|
| CHANGEMENT 1 (`Basis.looking_at` de CH71 remis) | K5, K6 → **2** | **2** — K5 à 180,00°, K6 sur 899/899 |
| CHANGEMENT 2 (`camera_lift()` renvoie 0) | L10, F10 → **2** | **7** — les 5 extras ont **une cause unique**, voir 5.3 |
| CHANGEMENT 3 (debounce à 0), 1re passe | M3, M5, M6, M8, M9 → **5** | **4** — M3 est resté VERT, voir 5.4 |
| CHANGEMENT 3, après correction de M3 | **5** | **5** — M3 lit `blend 0.000` |

Fichiers restaurés et vérifiés **byte-identiques** par `cmp` après chaque
passe.

### ⚠️ 5.2bis — LA PASSE ROUGE 2 A RENDU 7 POUR 2, ET LES 5 EXTRAS ONT UNE SEULE CAUSE

`camera_lift()` neutralisé, **M3, M5, M6, M8 et M9 sont tombés avec L10 et
F10** — alors que le lift n'a rien à voir avec la bascule POV. La cause est
unique et elle vaut d'être écrite :

Sans lift, le rider au sommet est à **y = 14,12** quand le haut du cadre
coupe son aplomb à **7,968** : il est **6,152 u au-dessus du bord haut de
l'image**. `unproject_position` le projette donc **hors du conteneur**, et
`HubTapInput._handle_point` refuse le tap **sur son propre test de rect**,
avant d'interroger quoi que ce soit. Le POV ne peut pas s'ouvrir, et toute
la phase M s'effondre pour une raison qui n'est pas la sienne.

**Un lift n'est donc pas seulement un terme de CADRAGE : c'est un terme
d'ATTEIGNABILITÉ.** Un corps hors du cadre n'est pas seulement invisible,
il est **inadressable**. Un lot qui surélève un corps interactif doit se
demander non seulement « est-il visible » mais « est-il ADRESSABLE » — et
sans cette passe rouge, personne ne l'aurait formulé.

*(A7 et A8 sont restées vertes dans cette passe, et c'est correct : elles
portent sur des CONSTANTES d'auteur, pas sur le lift à l'exécution. C'est
le blind check L9 qui couvre l'exécution, et il a rougi.)*

### ⚠️ 5.4 — LA PASSE ROUGE A TROUVÉ UN GATE QUI NE SÉPARAIT RIEN

Passe 3, debounce à zéro : **4 rouges pour 5 prédits**, et le manquant
était **M3**, c'est-à-dire le gate écrit exprès pour le debounce.

`is_pov()` lit `_pov_head != null`, et `exit_pov()` ne remet ce champ à
`null` qu'à la **fin** du tween de fondu, 0,45 s plus tard. Une frame après
une double bascule, il est donc encore **vrai — en train de SORTIR**. M3
revenait vert sur un canal qui venait de s'allumer et de s'éteindre.

C'est `CLAUDE.md` CH65 mot pour mot : « un seuil qui ne sépare pas le
correctif de son absence rend une passe rouge verte ». Corrigé en attendant
le fondu et en lisant **le blend** : debounce en place, `blend 1.000` et
toujours dedans ; debounce retiré, `blend 0.000` et `_pov_head` nul. Passe
rejouée : **5 rouges pour 5 prédits**.

Le blind check L9 est lui-même passé de **0 à 473 frames** quand son
propre défaut a été corrigé (voir 5.5) : avec le lift épinglé à zéro, la
tête du rider quitte le cadre **473 frames sur 713**. C'est ce qui prouve
que c'est le lift, et non la chance, qui cadre le ride.

### 5.5 — ⚠️ Quatre défauts d'INSTRUMENT, chacun avec l'allure d'un résultat

1. **Un rouge K5 à 90,07° sur une frame en 900.** Diagnostic, pas
   silence : la frame qui termine le trajet démarre aussi le pas de
   descente, et `_face` y a déjà écrit le cap de la marche vers le quai.
   90,07° est exactement l'angle entre la tangente à la gare `(0,0,1)` et
   la marche sur le deck `(−1,0,0)`. **PHASE E portait déjà la garde,
   dans ses propres mots** ; PHASE K ne l'avait pas reprise.
2. **Un blind check devenu aveugle.** `_fly_tower(pin)` écrivait le lift
   à zéro **avant** la frame ; le parc le réécrivait **pendant**. Le
   contrôle est revenu à `0 sur 713` — c'est-à-dire vert, sur un
   mécanisme entièrement débranché.
3. **M10 visait un point du monde hors cadre.** Sous le POV, un point à
   45° de son épaule n'est pas à l'écran (demi-angle 29°) et
   `_handle_point` le refuse sur son propre test de rect, **avant** tout
   le reste. Ça se lisait exactement comme « la sortie ne marche pas ».
4. **Une assertion tautologique.** La première rédaction de M15 comparait
   `fov − fov`, donc zéro. `hub_fov()` est désormais publié et la
   comparaison porte sur la valeur capturée au `_ready`.

### 5.6 — Table croisée, deux arbres, **154 `.scn` des deux côtés**

| | `origin/staging` (043d6d9) | branche CH72 |
|---|---|---|
| `FunfairProbe` | **ALL GREEN — 0 rouge** | **ALL GREEN — 0 rouge** |

Parité exacte. Les deux runs ont tourné **seuls**, séquentiellement.

### 5.7 — Budget

Le seul chiffre comparable entre deux runs est le delta **intra-run**
(même météo, même frame, parc montré contre parc caché) :

| | baseline | branche | Δ du lot |
|---|---|---|---|
| triangles du parc | 4 068 | **4 452** | **+384** |
| Δ primitives aux stations du parc | +4 068 | **+4 452** | **+384** |
| Δ draw calls | +4 | **+4** | **0** |
| triangles de scène, parc caché | 360 149 | **360 149** | **0** — le reste du monde est byte-identique |

**+384 triangles, zéro draw call de plus**, et ce sont les 4 anneaux de
treille que la tour a gagnés. Le parc coûte **0** ailleurs qu'aux
stations où il est dans le cadre (spawn et pire station CH22 : Δ = 0).

`gpu` de la branche, météo épinglée : **72 075 / 69 014 / 65 442** aux
trois stations du parc. Le plafond de 50 k du dépôt, dépassé depuis CH29,
l'est de **+44 % / +38 % / +31 %**. **Ce n'est pas ce lot qui l'a fait
sauter** — il en pèse 0,5 % — mais le chiffre est dit en clair, comme
CH71 l'avait dit, et c'est un point de décision pour Mathieu.

### 5.8 — ⚠️ Ce que ce banc NE PEUT PAS signer

`CLAUDE.md` CH62 : une sonde ne juge pas un game feel. Elle **ne dit
rien** de : si le POV donne le mal des transports, si 58° de FOV est le
bon nombre, si 7 s de montée est long, si 2,4 s en haut suffit à
regarder, si la chute à 14,2 u/s fait peur ou fait mal. Tout cela est
l'appel device de Mathieu. Ce qu'elle signe est que la pose est bornée,
qu'elle ne roule pas, que la bascule est câblée au vrai canal du doigt,
que le trajet continue à travers, que rien ne tourne hors de
l'interrupteur, et ce que ça coûte.

---

## Section 6 — CE QUI N'A PAS ÉTÉ FAIT, ET POURQUOI

* **Le site n'a pas bougé.** La prémisse « des arbres bouchent peut-être
  la vue » est mesurée fausse (§1.5a) ; déplacer le parc aurait coûté un
  lot pour zéro pixel gagné.
* **La nacelle ne tourne pas sur elle-même au sommet.** §1.5b montre que
  ce qu'on voit d'en haut dépend du **cap**, pas de l'altitude, et une
  vraie tour de chute fait tourner sa nacelle pour ça. Ce serait le
  prolongement naturel de CHANGEMENT 2 — mais c'est une mécanique que le
  brief ne demande pas, et le dépôt n'élargit pas un lot tout seul.
  **Nommé ici comme lot suivant possible, pas fait.**
* **Le POV ne tangue pas avec la pente du rail.** Le nœud `Yaw` ne porte
  aucun tangage et la reconstruction n'en invente pas : un POV qui roule
  ou tangue est le terme qui rend un ride nauséeux, et CH64 a déjà payé
  ce prix une fois. Un tangage sur la drop est un bouton de ressenti, à
  arbitrer device.
* **Le frein du chariot s'applique aussi pendant le tap de bascule.**
  Un doigt posé est le frein (contrat CH71) ; un tap de bascule est un
  doigt posé, donc il freine deux ou trois ticks. Comportement existant,
  signalé, non corrigé — le corriger voudrait dire distinguer un tap d'un
  appui, ce qui change la conduite validée device.
