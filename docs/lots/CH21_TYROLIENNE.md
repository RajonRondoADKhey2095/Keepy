# Tyrolienne — recon geometrie, candidats animaux, suppression du blaireau

> Chantier ouvert par cette session (3 septembre 2026). Recon pure : aucun
> fichier de jeu modifie, aucun commit hors docs et sonde jetable
> `scripts/dev/ZiplineReconProbe.*`. Doctrine permanente : voir
> `CLAUDE.md`. Index des chantiers : `docs/lots/INDEX.md`.

## RECON — suppression du blaireau, inventaire des animaux riggés, geometrie de la tyrolienne bidirectionnelle (3 septembre 2026)

Branche `claude/tyrolienne-recon-igte4f`, partie d'`origin/main`. Godot 4.3
n'etait pas installe dans ce sandbox au demarrage de la session : le binaire
editeur officiel (`Godot_v4.3-stable_linux.x86_64.zip`, **50 276 070** octets
telecharges — la meme taille que `CLAUDE.md` publie deja pour ce fichier,
confirmee independamment) a ete recupere depuis les releases GitHub
officielles et utilise pour toute mesure ci-dessous. Import complet fait
en amont de toute sonde (`godot4 --headless --path . --import`, 5 min 27 s,
**374** `.scn` importes, aucune erreur) — la parade documentee contre un
import tronque qui produirait un faux rouge silencieux.

### PARTIE 1 — le commit `c9362a9` est un nettoyage d'identification, deja documente

`c9362a96b3b904e94e2de1c816ac0454bbeb4e1e`, *"assets: identify the bear rig
by offscreen render, drop the badger"*, branche
`claude/bear-asset-visual-id-jwx53w`. **Deja ecrit dans `CH20_OURS.md`,
LOT A** (section reconstituee retroactivement par le LOT H depuis ce meme
commit — voir la note en tete de `CH20_OURS.md`). Le message de commit est
integralement auto-suffisant : deux `.glb` (`Meshy_AI_Ourson.glb` et
`Meshy_AI_Meshy_Merged_Animations.glb`, present en double byte-identique
sous `animated/` et `perso/`, md5 `dbc6fbcb116a793012c7fe92e0ad2082`)
partageaient le meme rig Mixamo (24 joints) et les memes noms de clips
(`Walking`, `Running`) — la metadata ne pouvait pas les distinguer. Le
choix a ete tranche par rendu offscreen (pose de bind + frame 0 de Walking,
cinq angles, `gl_compatibility` sous xvfb) : `Meshy_AI_Ourson.glb` est
l'ours retenu (renomme `keepy_bear_walker.glb`), l'autre est un blaireau
(museau blanc, deux bandes noires, gilet rapiece) — **supprime**, les deux
copies.

**Verdict** : ce n'est PAS un effet collateral d'un lot plus large. C'est un
lot d'identification pur, seul sur sa branche, avec zero fichier de
gameplay touche (`git show --stat` : 3 fichiers, tous sous
`assets_source/openworld/`, tous des blobs binaires ou un renommage pur).
Aucune ligne de `CLAUDE.md` ni d'aucun `docs/lots/CHxx_*.md` autre que
`CH20_OURS.md` lui-meme ne mentionne ce commit — il n'y avait rien d'autre
a trouver, et rien n'est invente ici pour combler ce vide.

### PARTIE 2 — inventaire complet des `.glb` d'animaux : quatre riggés au total, un seul disponible et non identifie

Recherche exhaustive (`find -iname "*.glb"`, 32 fichiers) puis inspection
directe du chunk JSON glTF de chacun (lecture binaire, pas de dependance a
Godot pour cette partie) pour `skins`/`animations`. **Seuls quatre `.glb`
du depot portent un skin** — tout le reste (dragonfly, boar, toad, log,
trunk, rat, hibou, pie, hedgehog, beaver, tous les decors) est un mesh
statique, 0 skin, 0 animation, verifie sur **20 fichiers** distincts.

| animal | fichier(s) | integre ou ? | marche fonctionnelle |
|---|---|---|---|
| Ours (bear) | `assets/models/keepy_bear_walker.glb` (source `assets_source/openworld/animated/keepy_bear_walker.glb`) | **HubWorld** — NPC pres de la balancoire (CH20), marche vers Keepy puis rentre | **OUI** — clips nommes `Running`, `Walking` separement |
| Ecureuil Keepy (hero) | `assets/models/keepy_squirrel_hero.glb` | **HubWorld** (Keepy), **CabinInterior**, **Battle** (`resources/battle/keepy.tres`) | NON — 0 skin, 1 noeud/1 mesh (CabinInterior.gd le dit explicitement : "NO SKELETON, SO NO CLIP"), deplacement par hop procedural |
| Hibou poursuivant | `assets/models/keepy_hibou_pursuer.glb` (source `assets_source/pursuer/owl_pursuer_decimated.glb`) | **Pursuer.tscn** (Chased), **Battle** (`dummy.tres`) | NON — 0 skin, vol par transform procedural (CH17) |
| Hibou decor | `assets/models/keepy_owl_decor.glb` (source `Meshy_AI_Ember_Eyed_Owlet...glb`) | **HubWorld**, statique | NON — 0 skin |
| Pie (magpie) | `assets/models/keepy_magpie_prop.glb` (source `Meshy_AI_Pie.glb`) | **CabinInterior** (hotspot du lit) | NON — 0 skin |
| Rat | `assets/models/keepy_enemy_rat.glb` | **Obstacle.tscn** (Chased) | NON — 0 skin |
| Libellule | `assets/models/keepy_air_enemy_dragonfly.glb` | **Obstacle.tscn** | NON — 0 skin |
| Sanglier (boar) | `assets/models/keepy_charger_boar.glb` | **Obstacle.tscn** | NON — 0 skin |
| Crapaud (toad) | `assets/models/keepy_stomper_toad.glb` | **Obstacle.tscn** | NON — 0 skin |
| Herisson (Hedgehog Adventurer) | `assets_source/openworld/perso/Meshy_AI_Hedgehog_Adventurer...glb` | **DISPONIBLE, NON INTEGRE** | NON — 0 skin, mesh statique pur |
| Castor (Low Poly Beaver) | `assets_source/ennemis/Meshy_AI_Low_Poly_Beaver...glb` | **DISPONIBLE, NON INTEGRE** | NON — 0 skin |
| **3 rigs Mixamo non identifies** | `assets_source/openworld/animated/Meshy_AI_model_Animation_Walking_withSkin.glb` (+ `(1)`, `(2)`) | **DISPONIBLES, NON INTEGRES** | **PARTIELLE / A CONFIRMER** — voir ci-dessous |

**Les trois rigs non identifies**, mesures directement (29 noeuds, 1 skin
chacun, tous DIFFERENTS de l'ours qui a 26 noeuds) :

| fichier | taille | animation |
|---|---|---|
| `...withSkin.glb` | 4 863 280 o | UNE piste : `Armature\|Unreal Take\|baselayer` |
| `...withSkin (1).glb` | 4 025 712 o | idem, meme nom de piste |
| `...withSkin (2).glb` | 3 870 064 o | idem |

**md5 tous distincts** (`0ec9237...`, `721a5be...`, `f3f45d9...`) — ce sont
TROIS rigs differents, pas des doublons. Contrairement a l'ours (`Running`
et `Walking` en pistes separees, nommees), ces trois portent une piste
UNIQUE au nom generique Unreal/Mixamo (`baselayer`) qui peut contenir une
marche, un idle, ou un blend — **le nom seul ne le dit pas**, et aucune
texture/materiau/nom d'image dans le glTF (`texture_0`, `Material_1`
generiques) n'identifie l'espece. Une tentative de rendu offscreen dans
cette session a echoue (framing camera errone contre un rig dont
`MeshInstance3D.get_aabb()` traverse une Armature Mixamo a l'echelle
0.01 — exactement le piege documente par `CLAUDE.md` pour l'ours,
retrouve ici de premiere main) et n'a pas ete debogue plus loin dans le
budget de cette recon.

**Conclusion Partie 2** : le seul candidat "pret a l'emploi" pour la
tyrolienne serait un QUATRIEME animal a inventer/importer (rien de
disponible n'a a la fois un skin ET une identite visuelle confirmee ET
n'est pas deja affecte a un role — l'ours a deja son role au tourniquet).
Les trois rigs `withSkin` sont les seuls candidats plausibles pour une
marche animee, mais **aucun des trois n'est identifie visuellement** :
une session ulterieure doit reprendre le rendu offscreen (bind pose +
frame de la piste `baselayer`, camera a distance fixe ~2,2 u plutot que
cadree sur l'AABB brute) avant qu'aucun des trois ne puisse etre retenu.

### PARTIE 3 — geometrie de la tyrolienne A<->B

**Sonde** : `scripts/dev/ZiplineReconProbe.gd`/`.tscn`. Meme technique de
raycast que `HubTapInput._handle_point()` (camera reelle du hub ->
`Plane(Vector3.UP, 0.0)`), depuis le spawn camera standard
(`Keepy` a l'origine, camera a `HubCamera.OFFSET`), cadre **1080x1920**.
Deux phases : MEASURE (pur calcul, `--headless` sur) et CAPTURE (deux
rendus offscreen, xvfb + `opengl3` — jamais `--headless` seul pour un
pixel, la regle du projet).

⚠️ **Aucun fichier `CH21_TYROLIENNE.md` n'existait avant cette session**, et
aucun seuil de pente "13 degres" ni bande "14-22 u" n'est documente nulle
part dans ce depot (`grep` sur `CLAUDE.md` et tous les `docs/lots/*.md` :
zero occurrence). Le brief le presupposait etabli ; ce n'est pas le cas, et
rien n'est invente ici pour le faire correspondre — cette section MESURE
la geometrie et PROPOSE un seuil, elle n'en verifie aucun prealable.

#### Points A et B, mesures

| | fraction ecran | monde (X, Y, Z) |
|---|---|---|
| A (haut, cercle du haut) | (0,52 ; 0,24) | (0,5209 ; 0,0000 ; -23,8963) |
| B (bas, cercle du bas) | (0,38 ; 0,72) | (-0,9127 ; 0,0000 ; 2,9521) |

- **Altitude** : les deux points tombent EXACTEMENT sur `y = 0` — le sol du
  hub est un `PlaneMesh` sans relief, le meme plan que chaque hop/tap du
  projet resout deja contre. **Aucun ecart d'altitude a signaler** : ce
  n'est pas une approximation, c'est la geometrie reelle. Toute hauteur de
  tour aux deux extremites est donc un CHOIX DE DESIGN (esthetique/lisible
  a distance), pas une contrainte de terrain — des tours symetriques de
  meme hauteur sont le defaut naturel, pas un compromis.
- **Distance A<->B** : **26,8866 u** (horizontale = totale, puisque Y=0
  des deux cotes).
- **Pente proposee** (aucun seuil prealable n'existant, balayage a
  plusieurs deltas de hauteur de plateforme plutot qu'un chiffre suppose) :

  | delta hauteur plateforme | pente du cable |
  |---|---|
  | 0,0 u | 0,00° |
  | 1,0 u | 2,13° |
  | 2,0 u | 4,25° |
  | 3,0 u | 6,37° |

  Propose a Mathieu : des plateformes de meme hauteur (0,0 u de delta,
  0,00°) sont la lecture la plus simple compte tenu du sol plat mesure —
  toute pente choisie au-dela est un effet stylistique voulu, pas une
  necessite.

#### Clairance decor — 424 AABB, mesurees deux fois (headless ET xvfb/opengl3)

**424 AABB au total**, comptees par un collecteur generique ecrit pour
cette sonde (aucun accesseur nomme "totem"/"pilier" n'existe dans ce
depot — `grep` negatif sur `scripts/hub/*.gd` — donc rien n'a ete
suppose, tout a ete parcouru en direct sur le `Props`/`HubBuilder` reellement
construit). **424 est un chiffre re-mesure independamment ici**, pas
recopie du brief.

⚠️ **PIEGE HEADLESS RETROUVE EN DIRECT, PAS SUPPOSE** : le premier passage
`--headless` de cette sonde a donne des chiffres DIFFERENTS du passage
xvfb+`opengl3` (341 vs 360 objets au-dessus de 0,3 u de hauteur, 166 vs 168
au-dessus de 1,0 u) — la lecture des transforms de `MultiMesh` (arbres,
roches, fleurs sont tous batches) sous driver DUMMY est exactement le
piege documente par `CLAUDE.md` ("relire une instance rend l'identite").
**Seul le passage xvfb+opengl3 fait foi pour la clairance decor**
ci-dessous ; le passage headless reste fiable pour le raycast cameraet la distance au pond (aucun `MultiMesh` implique).

Un premier passage de la sonde a aussi inclus par erreur le `Ground`
(un `PlaneMesh` de 600x600, distance 0 partout par construction) dans le
calcul de clairance — corrige en restreignant la collecte au sous-arbre
`Props` plutot qu'au `World` entier. Exactement le piege « blind check » :
l'assertion « distance > seuil » est passee FAUSSE partout au premier
essai, ce qui a prouve qu'elle savait echouer avant d'etre creee sur le
bon perimetre.

| filtre | objets retenus | point A : plus proche | point B : plus proche |
|---|---|---|---|
| tout objet (`size.y > 0,3`, exclut seulement les nappes de sol plates — ilots/berge/eau) | 341 | `Rock[43]` a **2,8395 u** | `FlowerStem[1]` a **1,1238 u** |
| objets "solides" (`size.y > 1,0`, exclut aussi les anneaux de portail plats) | 166 | poteau de **DivingBoard** a **3,2802 u** | mesh du **hibou decor** (`keepy_owl_decor`) a **1,7677 u** |
| corridor A->B, echantillonne tous les ~1 u | — | pire clairance **0,0000 u** a 59 % du trajet (un anneau de portail, 0,3 u de haut) sur le filtre 0,3 ; **0,8270 u** a 56 % (une couronne d'arbre) sur le filtre 1,0 | |

**Rayon de structure propose (PAS un chiffre shippe ailleurs dans ce
depot)** : 3,5 u — une fois et demi le rayon de tap du bateau (2,5 u),
puisqu'un escalier est un plus gros pied qu'une coque. **Point A comme
point B tombent tous deux SOUS ce rayon propose** contre l'objet solide le
plus proche (3,2802 u et 1,7677 u) : **point de decision pour Mathieu, pas
masque**. Le point B en particulier est net : le hibou decor est a moins de
2 u, largement a l'interieur de tout pied d'escalier plausible — soit
l'ancrage B est deplace de 1 a 2 u, soit le hibou est deplace, soit le
rayon de structure est reduit en-dessous de 1,77 u (ce qui reduirait aussi
la marge de securite du tap).

⚠️ **Le "corridor bloque a 0,0000 u" (anneau de portail, 59 % du trajet)
n'est PAS un vrai blocage** : c'est une clairance au NIVEAU DU SOL, et un
cable de tyrolienne passe AU-DESSUS du terrain — seules les deux
extremites (les pieds des tours) ont vraiment besoin de clairance au sol.
Le signal reste utile pour la LISIBILITE (une structure au sol alignee
pile sur un anneau de portail serait un choix etrange), mais ce n'est pas
une collision physique a corriger.

#### Rendus offscreen (xvfb + `opengl3`, jamais `--headless` seul)

Deux PNG sauvegardes localement (non commits, hors du budget de taille du
depot) :

* `zipline_recon_standard_view.png` — la camera standard du hub, spawn
  reel, marqueur ROUGE sur A et BLEU sur B. **Confirme visuellement** : A
  tombe exactement a la fourche entre le petit etang (portail Chased,
  gauche) et le grand lac (portail Battle, droite) — PAS directement "a la
  base" d'un pilier, mais avec UNE seule fleche/spire grise haute et fine
  visible au loin sur l'ilot du grand lac, a droite. B tombe dans l'herbe
  degagee, entre le hibou decor (gauche) et Keepy (droite) — correspond
  bien a la description du brief ("sous et legerement a gauche" de Keepy).
* `zipline_recon_corridor_overview.png` — camera repositionnee en
  survol oblique, visant le milieu du segment A-B. Montre une PAIRE de
  hautes dalles verticales grises (variante "slabs" du landmark, DEUX
  barres cote a cote) en haut du cadre — c'est ce type de landmark, pas la
  spire fine vue dans le premier rendu, qui correspond le mieux a
  "plusieurs hauts piliers d'ecorce grise (totems)" au pluriel decrit par
  Mathieu. Sa position exacte relative a A n'a pas ete isolee par un
  accesseur nomme (aucun n'existe) ; le rendu la place clairement au-dela
  de A, pas dessous — a verifier device avant de fixer le pied de la tour A
  sur cette base.

⚠️ **Le "petit etang" verifie par `pond_centre()`/`POND_WATER_RADIUS` (CH12)
n'est PAS le grand lac visible a droite sur le rendu** — ce sont deux corps
d'eau distincts (CH12 documente cinq corps au total). Le segment A-B a ete
verifie contre le petit etang uniquement (clairance **18,8656 u**, large
marge) ; **le grand lac n'a pas ete verifie par cette sonde** faute d'un
accesseur equivalent explicitement demande dans le brief pour ce corps —
suivi a faire avant integration, le rendu standard montrant A tres proche
de sa rive.

#### Architecture proposee des deux portes de tap symetriques (texte seulement, aucun code de jeu)

Patron **BATEAU**, jamais ECHELLE (banni par `CLAUDE.md` pour toute
nouvelle interaction) : la cible se retire activement pendant le trajet, et
CHAQUE extremite garde un canal de sortie.

* **Un seul rig partage**, sur le modele de `BoatMooring` : un noeud
  `ZiplineRig` (nom provisoire) porte l'etat "un trajet est en cours" (un
  seul booleen partage, puisqu'un seul trajet peut exister a la fois sur un
  cable unique) et les deux poses d'ancrage A/B publiees une fois (jamais
  recopiees, la doctrine "un fait est publie une fois").
* **`is_available_at(end)`** — vrai ssi aucun trajet n'est en cours,
  independamment du sens : pendant un trajet A->B, `is_available_at(A)` ET
  `is_available_at(B)` sont TOUS LES DEUX faux — aucune des deux
  extremites ne peut re-declencher, symetrique par construction.
* **`accepts_tap(point, end)`** — comme `BoatMooring.accepts_boarding_tap`,
  teste la distance du point resolu par `HubTapInput` a l'ancrage
  concerne, sous un rayon de tap genereux (mesure sur le pied de structure
  reel une fois dessine, pas suppose a 2,5 u par analogie avec le bateau).
* **`HubTapInput`** interroge le rig AVANT de retomber sur le sol, une
  fois pour chaque extremite (meme ordre de priorite que
  `BoatMooring`/portails aujourd'hui) : un tap pres de A lance A->B, un tap
  pres de B lance B->A, un tap ailleurs retombe au chemin sol normal.
* **Intention qui SURVIT a l'atterrissage de passage** (la lecon de la
  porte de cabane, `CLAUDE.md`) : si Keepy doit marcher plusieurs hops pour
  atteindre l'ancrage avant de pouvoir embarquer, l'intention "je veux
  prendre la tyrolienne vers X" reste armee jusqu'a l'arrivee, exactement
  comme `_boarding` survit dans `HubWorld._try_board()`.
* **Sortie garantie dans les deux sens** : contrairement a une echelle, il
  n'existe PAS d'etat ou le joueur est "dans" la structure sans qu'aucun
  tap ne reponde — le sol autour des deux pieds de tour reste un
  destination normale a tout moment hors trajet, et pendant le trajet la
  seule interaction est la sortie de fin de course (comme le bateau,
  "riding la tyrolienne n'est pas etre bloque dedans").
* **Chaque extremite est un point d'interaction propre** avec son propre
  escalier menant a sa propre petite plateforme de depart, mais les DEUX
  plateformes partagent le meme `ZiplineRig` en arriere-plan — pas de
  hierarchie "depart"/"arrivee" fixe dans le code, seulement "extremite A"
  et "extremite B" nommees par position, jamais par role.

### Sonde jetable

`scripts/dev/ZiplineReconProbe.gd` / `.tscn` — mesure et rendu uniquement,
ne gate rien, aucune assertion. Ne modifie aucune scene shippee (charge
`HubWorld.tscn` en instance separee, jamais la scene principale). A
supprimer quand ce chantier passera en implementation (regle "sonde
jetable = supprimee avant le commit" qui livre du gameplay reel) ;
conservee pour l'instant car cette session est pure recon.

## SUIVI — lisibilite du corridor, arbitrage des deux conflits, grand lac et totems (3 septembre 2026)

Session separee, meme discipline (recon pure, aucun fichier de jeu
modifie). Godot 4.3 non installe au demarrage : meme binaire officiel
recupere depuis les releases GitHub (`Godot_v4.3-stable_linux.x86_64.zip`,
**50 276 070** octets, taille verifiee identique). Import complet fait en
amont (`godot4 --headless --path . --import`, 5 min 17 s, 0 erreur ; 36
`.glb` importes en `.scn`, tous les assets necessaires a cette recon
verifies presents avant toute mesure).

⚠️ **Le brief de cette session presupposait une bande lisible "14-22 u" et
un seuil de pente "13 degres" comme doctrine deja etablie par CH21.** Ce
n'est pas le cas : la section PARTIE 3 ci-dessus le dit noir sur blanc
("aucun seuil de pente '13 degres' ni bande '14-22 u' n'est documente nulle
part dans ce depot"). Re-grepe ici, meme resultat, zero occurrence. Rien
n'est invente pour faire correspondre le brief a une doctrine qui n'existe
pas — cette section mesure le corridor A<->B tel qu'il est, avec le
brouillard reellement en vigueur (statique, toujours actif dans le hub :
`HubWorld.tscn` porte `fog_enabled=true fog_density=0.016`, aucun noeud
`SwampAtmosphere` dans cette scene — confirme absent par recherche — donc
rien a "activer", c'est deja la valeur servie a chaque frame).

Sonde `scripts/dev/CorridorFollowupProbe.gd`/`.tscn`, meme decoupage
MEASURE (headless)/CAPTURE (xvfb+`opengl3`) que la sonde precedente.

### POINT 1 — le defaut d'occlusion ne se reproduit A AUCUNE des pentes testees, y compris la pente NULLE

Un "fil" (cylindre jaune vif, contraste maximal contre la palette sombre,
pour qu'aucune lecture ci-dessous ne soit un artefact de couleur) est
trace entre les deux ancrages, une tour A a une base fixe de 2,0 u et une
tour B a la meme base + un delta variable (le meme "delta hauteur
plateforme" que la table de PARTIE 3), depuis la camera standard du hub
(meme pose que le rendu "standard view" de CH21 : Keepy et camera au
spawn).

**Verdict par inspection visuelle directe des rendus** (voir plus bas
pourquoi la metrique de contraste automatisee n'est PAS fiable telle
qu'ecrite) :

| delta plateforme | pente | lecture visuelle du fil contre le brouillard |
|---|---|---|
| 0,0 u | 0,00° | **PARFAITEMENT LISIBLE** — jaune vif, aucune confusion avec le fond |
| 3,0 u | 6,37° (candidate max) | **PARFAITEMENT LISIBLE** |
| 6,0 u | 12,58° | **PARFAITEMENT LISIBLE** |
| 10,0 u | 20,40° | tour B sort du cadre superieur (voir plus bas) |
| 16,0 u / 24,0 u | — | tour B passe DERRIERE la camera (`is_position_behind` vrai) — non mesurable dans cette pose camera |

**Le defaut ne se reproduit dans AUCUNE configuration testable avec la
camera standard du hub**, y compris a pente nulle — le cas que la
premisse du brief attendait le plus mauvais. Trois rendus (delta=0,0 ;
3,0 ; 6,0) montres a Mathieu confirment un fil jaune parfaitement net sur
toute sa longueur, sans aucune zone ou il se confond avec le degrade de
fond.

⚠️ **La metrique de contraste automatisee ecrite pour cette sonde
(WCAG-style, meme convention que le seuil 3,0:1 documente dans
`CLAUDE.md`) a echoue son propre blind check et n'est PAS fiable pour du
fil fin en diagonale** : a delta=0,0 elle rapporte 1,01:1 ("perdu dans le
brouillard") alors que le rendu montre un fil parfaitement net — le point
de fond echantillonne (40 px au-dessus du milieu ecran) tombe LUI AUSSI
sur le fil (fin et proche de la verticale a l'ecran), donc la mesure se
compare a elle-meme. A delta=10,0 la meme metrique rapporte a nouveau
1,00:1, mais cette fois parce que le point B se projette tres au-dessus du
cadre (y=-2720 px) et que le milieu ecran calcule par simple moyenne
lineaire des deux points projetes ne tombe plus sur le trace reel du fil
(projection perspective non lineaire) — echantillonnage du fond des deux
cotes, pas du tout un signal de brouillard. **Cette metrique ne doit pas
etre reutilisee sans etre re-ecrite pour echantillonner perpendiculairement
a la direction ecran du fil** ; les verdicts ci-dessus viennent de
l'inspection directe des trois PNG, pas de ce nombre.

**Consequence pratique** : rien dans la geometrie du brouillard de ce
projet (purement exponentiel par DISTANCE, `fog_height_enabled` absent des
deux scenes verifiees) ne justifie une bande de distance "lisible" ou un
seuil de pente — la distance A<->B (26,89 u, fixe, independante de la
hauteur des tours) est ce que le brouillard voit ; la hauteur des tours ne
change que l'angle d'affichage a l'ecran, pas l'attenuation. A la lumiere
de ce mecanisme et des trois rendus obtenus, **aucune pente minimale n'est
necessaire pour la lisibilite** — 0,00° (le defaut naturel du sol plat deja
identifie en PARTIE 3) est deja lisible. Une pente reste un choix
stylistique libre, pas une necessite technique.

### POINT 2 — les deux conflits de clairance, chiffres a l'appui (recalcules en direct contre l'arbre AABB reellement construit)

#### Conflit 1 — point A vs poteau du DivingBoard (baseline 3,2802 u, deficit 0,22 u seulement)

| option | detail | resultat |
|---|---|---|
| **A — deplacer l'ancrage A** de 1,0 u dans la direction opposee au poteau (XZ = -0,726 ; 0,688) | | clairance -> **4,2802 u** (clear), nouvelle distance A<->B = **26,1699 u** (delta -0,7167 u sur 26,89 u, negligeable) ; pas de nouvel obstacle rencontre |
| idem, 1,5 u | | clairance -> 4,7802 u, distance -> 25,8186 u (delta -1,0680 u) |
| idem, 2,0 u | | clairance -> 5,2802 u, distance -> 25,4723 u (delta -1,4143 u) ; obstacle le plus proche devient une couronne d'arbre a 5,2449 u (toujours large marge) |
| **B — reduire le rayon de structure** | de 3,5 u a **3,2802 u** (deficit reel de seulement 0,22 u) | zero deplacement d'ancrage ; rayon quasiment inchange, deja tres proche du seuil propose |
| C — deplacer le DivingBoard | non chiffre ici (le plongeoir est un prop integre avec sa propre chaine CH15, deplacer son poteau a plus d'implications que deplacer un point d'ancrage pas encore construit) | **non recommande sans une raison forte** — l'option A ou B suffit a un cout bien moindre |

**Ce conflit est mineur** : le deficit est de 0,22 u seulement, et un nudge
de 1,0 u (moins de 3% de la distance totale) le resout confortablement.

#### Conflit 2 — point B vs hibou decor (baseline 1,7677 u, deficit 1,73 u — la moitie du rayon propose)

| option | detail | resultat |
|---|---|---|
| **A — deplacer l'ancrage B**, +1,0 u (direction XZ = 0,620 ; 0,785) | | clairance -> 2,7677 u, **toujours SOUS 3,5 u** ; distance A<->B -> 27,6451 u (delta +0,7586 u) |
| idem, +1,5 u | | clairance au hibou -> 3,2677 u, **toujours sous le seuil** — ET un NOUVEL obstacle (couronne d'arbre) apparait a 3,1793 u, lui aussi sous le seuil : ce palier ne resout rien |
| idem, **+2,0 u** | | clairance au hibou -> 3,7677 u (clear, marge fine +0,27 u) ; nouvel obstacle le plus proche = Rock[3] a 3,5717 u (clear, marge fine +0,07 u) — **les deux clairances passent tout juste**, marge etroite |
| idem, +3,0 u | | clairance au hibou -> 4,7677 u ; obstacle le plus proche = Rock[3] a 4,3568 u — marge confortable des deux cotes |
| **B — reduire le rayon de structure** | de 3,5 u a **1,7677 u** | reduction de moitie, tres agressif pour un pied d'escalier — reduit aussi la marge de tap, deja signale par CH21 comme peu souhaitable |
| **C — deplacer le hibou decor** | prop purement decoratif (0 skin, aucun accesseur nomme, aucun autre systeme ne le lit — confirme par la table PARTIE 2 de ce fichier) ; un deplacement de layout de quelques u est un edit isole, sans couplage ailleurs | **option la moins couteuse en risque** si Mathieu prefere ne pas toucher a la geometrie de la tyrolienne elle-meme |

**Ce conflit est plus serieux** : un nudge minimal ne suffit pas
(1,0-1,5 u restent sous le seuil, voire rencontrent un second obstacle a
1,5 u) ; il faut au moins +2,0 u pour clairer, avec une marge fine des deux
cotes a ce palier — +3,0 u est plus confortable. L'option C (deplacer le
hibou, prop non couple) reste la plus simple si le rayon de structure et
la position de B sont a preserver tels quels.

### POINT 3 — grand lac et landmarks du grand lac

#### 3.1 — distance du point A au grand lac (accessseur `HubRegion.lakes()`, jamais recopie)

Le grand lac est en realite DEUX lobes publies par `HubRegion.lakes()` :

| lobe | centre | rayon | distance(A, centre) | clairance a la rive |
|---|---|---|---|---|
| lobe principal (`GREATLAKE_WATER_RADIUS`) | (15.5, -19) | 16,0000 | 15,7590 | **-0,2410 u — POINT A EST DANS LE CERCLE D'EAU** |
| lobe cote spawn (`SPAWN_LAKE_WATER_RADIUS`) | (-12, -19.5) | 10,0000 | 13,2703 | 3,2703 u (marge large) |

⚠️ **Resultat inattendu et confirme par rendu** (voir 3.2) : le point A,
tel que Mathieu l'a annote sur sa capture (fraction ecran 0,52 ; 0,24,
raycast identique a chaque tap du jeu), tombe **A L'INTERIEUR** du cercle
d'eau du lobe principal du grand lac, de 0,24 u. Ce n'est pas la petite
mare deja verifiee par `pond_centre()`/`POND_WATER_RADIUS` en PARTIE 3
(clairance 18,8656 u, large marge, toujours valable) — c'est un second
corps d'eau, non verifie par la sonde precedente faute d'accesseur demande
a l'epoque. **Le pied de la tour A, tel que mesure aujourd'hui, ne peut
pas etre pose sans deplacement** : soit l'ancrage A est nudge vers la terre
ferme (la fourche entre les deux lobes, visible sur le rendu 3.2, est a
quelques u de la, cote securise cote petit lac deja mesure a 18,87 u de
marge), soit la geometrie de la rive est revue localement.

#### 3.2 — capture depuis la position de jeu reelle

Keepy place EXACTEMENT au point A (pas au spawn), camera a l'offset
HubCamera reel depuis cette position (`Vector3(A.x,0,A.z) + HubCamera.OFFSET`,
rotation figee de la scene — la meme pose que le joueur aurait reellement
en marchant jusque-la). Le rendu confirme visuellement le chiffre 3.1 :
**Keepy se tient a la pointe exacte de la fourche entre les deux plans
d'eau turquoise, qui l'entourent des deux cotes** — ni "a la base d'un
pilier" ni clairement sur la berge, un a-pic vers l'eau immediatement
visible des deux flancs.

#### 3.3 — identification des landmarks, PAR LE CODE (`variant` de layout), pas par un rendu synthetique

`resources/hub/hub_layout.tres` declare 3 variantes de landmark
(`_make_landmark()` dans `HubBuilder.gd`) : **0=spire** (aiguille fine,
seule), **1=cairn** (masse empilee, seule), **2=slabs** (DEUX barres
verticales inegales — le seul variant qui correspond litteralement a
"plusieurs hauts piliers... (totems)" au pluriel). Quatre landmarks du
grand lac tombent a moins de 25 u du point A :

| variant | position | distance a A |
|---|---|---|
| 0 (spire) | (2.668, -33.895) | **10,2267 u** |
| 1 (cairn) | (6.836, -20.528) | **7,1572 u — LE PLUS PROCHE** |
| 0 (spire) | (17.372, -12.464) | 20,3631 u |
| 2 (slabs, "totems") | (19.884, -25.496) | 19,4291 u |

**Le landmark le plus proche du point A n'est PAS la paire de dalles
("totems")** — c'est le CAIRN (variant 1, masse grise empilee unique),
a 7,16 u. Confirme par rendu rapproche : une masse grise anguleuse et
etagee, coherente avec la description du code ("blocky stacked mass...
grey rather than green"), pas deux barres separees. La spire fine visible
au loin sur les rendus 3.2/standard-view (celle que CH21 avait deja
repere a l'oeil) est le variant 0 a 10,23 u — une AIGUILLE UNIQUE, pas des
"totems" non plus. La vraie paire de dalles (variant 2) existe bien sur ce
lac, mais a 19,43 u de A — sensiblement plus loin que le cairn, et
comparable a la distance de la seconde spire (20,36 u).

**Verdict** : la capture d'origine de Mathieu montrant "plusieurs hauts
piliers d'ecorce grise (totems)" ne correspond ni a l'objet le plus proche
du point A (le cairn, silhouette non-plurielle), ni a l'objet visible en
arriere-plan sur le rendu standard (la spire, silhouette non plurielle
non plus) — le seul landmark qui correspond litteralement a une paire de
piliers est a 19,43 u de A, pas immediatement a cote. **A verifier
directement avec Mathieu quel landmark sa capture montrait reellement**
avant de fixer le pied de la tour A dessus ou a proximite.

### Sonde jetable (suivi)

`scripts/dev/CorridorFollowupProbe.gd`/`.tscn` — memes garanties que
`ZiplineReconProbe` (mesure/rendu seulement, aucune assertion, scene
HubWorld instanciee separement). Rendus PNG sauvegardes localement
(`user://corridor_*.png`, non commits, hors budget de taille du depot).
