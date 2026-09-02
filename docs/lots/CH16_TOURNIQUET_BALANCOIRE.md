# Tourniquet, balançoire et lobe nord

> Extrait de `CLAUDE.md` par le LOT H (2 septembre 2026), **verbatim** : aucune ligne réécrite, résumée ni supprimée.
> 4 section(s), 1237 lignes d'origine.
> Doctrine permanente : voir `CLAUDE.md`. Index des chantiers : `docs/lots/INDEX.md`.

## LE TOURNIQUET : LE PLATEAU GAGNE UN PROP QUI REPOND, ET TROIS PREMISSES DU BRIEF TOMBENT A LA MESURE (28 aout 2026)

Branche `claude/tourniquet-hub-prop-qj4778`, partie de `main` (`12a1d6b`,
et `origin/staging` portait alors le MEME arbre `ea21c6b7`). Regle n°1
verifiee AU DEBUT : `git fetch --all --prune`, tri des refs distantes par
date et comparaison des **ARBRES** et pas des noms -- toutes les branches
plus recentes sont deja ancetres de `main`, **aucune session concurrente**.

Un manege de cour de recreation sur la pelouse nord. Un tap ordinaire y
amene Keepy ; **l'atterrissage fait tourner le prop**. Rien ne change chez
Keepy : aucun nouvel etat de `KeepyHopper`, aucune elevation sur le
plateau, et le plateau du manege **n'est pas praticable**.

### ⚠️ PREMISSE FAUSSE N°1 : L'ECHELLE FAIT DEJA CE QUE LE BRIEF LUI OPPOSE

Le brief posait deux comportements a distinguer -- l'echelle declencherait
`CLIMBING` **immediatement** au tap, le tourniquet devrait au contraire
reagir **A L'ARRIVEE** d'un hop normal. **Mesure : l'echelle fait DEJA la
seconde chose.** `_on_tapped_ladder` arme `_climbing` puis appelle
`hop_to(point)` -- un hop parfaitement ordinaire -- et c'est
`_on_hop_landed` qui appelle `_try_climb` a l'arrivee. Le seul chemin
immediat est `if not _keepy.is_hopping()`, c'est-a-dire « il etait deja
debout au pied ».

La vraie difference est ailleurs, et elle est plus simple : l'echelle
consomme un **signal de tap dedie** (`tapped_ladder` EMIS A LA PLACE de
`tapped_ground`, un tap un signal), qui arme une intention. Le tourniquet
n'a besoin d'aucun signal special : il repond a **n'importe quel
atterrissage** pres de lui, depuis n'importe quel tap ordinaire.
`HubTapInput.gd` est donc **byte-intouche**.

### ⚠️ PREMISSE FAUSSE N°2 : AUCUN PROP NE BLOQUE L'APPROCHE, AUJOURD'HUI

Le brief demandait de confirmer « comment un prop bloque l'approche
(landmark, pontoon) pour que le tourniquet suive le meme modele et que
Keepy s'arrete devant plutot que de le traverser ». **Mesure : rien ne
bloque quoi que ce soit.** `FOOTPRINT_RADIUS` existe, mais
`ground_footprints()` n'a **qu'un seul appelant de jeu** --
`leave_ride()`, la recherche de point de debarquement -- plus deux sondes.
La chaine de hop ordinaire ne consulte RIEN : `_begin_hop` avance sur une
corde droite. Keepy traverse aujourd'hui les arbres, les landmarks et les
pontons.

Suivre « le meme modele » signifie donc exactement ceci : le tourniquet
declare son empreinte au sol (`&"turnstile": TURNSTILE_BASE_RADIUS`, la
dalle de pierre) et Keepy passe au travers comme devant tout le reste.
**Rien de nouveau n'est ajoute pour l'arreter** -- ce serait une regle de
DEPLACEMENT neuve, dans une fonction qui ne consulte rien, et elle rendrait
ce prop le seul du plateau a stopper Keepy.

### ⚠️ PREMISSE FAUSSE N°3 : LES BARRES NE PEUVENT PAS ETRE UN BATCH PARTAGE

Le brief demandait les barres « BATCHEES en MultiMesh, meme principe que
les barreaux d'echelle ». **Le principe est bon, le batch partage est
impossible**, et c'est structurel : `_instance()`/`_flush_batches()`
produisent un `MultiMeshInstance3D` **enfant de HubBuilder**, avec des
transforms **MONDE cuits une fois**. Des barres deposees la resteraient
immobiles pendant que le pivot auquel elles appartiennent tourne,
pointant ou le manege etait avant.

Livre : un `MultiMeshInstance3D` **propre au prop**, parente **sous le
pivot**, ses instances en espace LOCAL. Toujours **un noeud de dessin pour
les quatre barres**, ce qui est toute la raison d'etre d'un batch ici --
simplement pas un batch partage.

### L'ARCHITECTURE EST GENERIQUE DES LE PREMIER COMMIT

C'est la lecon que le plongeoir a fait payer : sa GEOMETRIE etait generique
depuis le debut et c'est la **TABLE** en aval qui etait un singleton, si
bien qu'une seconde planche etait dessinable et non grimpable -- defaire ca
a coute son propre lot.

`HubBuilder.spinning_props()` est donc **une LISTE des le premier commit**,
avec une entree dedans, et sa forme n'a rien de tourniquet :
`{"position", "radius", "spinner"}`. Un second prop reactif est une entree
de plus, pas un second mecanisme. `HubWorld` en copie une fois une version
avec un champ `"tween"` -- **un seul tableau et pas deux tableaux
paralleles index-alignes**, qui sont exactement la facon dont le tween du
prop 3 finit par tuer le prop 4.

Le rayon de declenchement est publie **par entree** et non tenu comme un
nombre unique par l'appelant : `LADDER_TAP_RADIUS` est le meme pour toutes
les planches parce qu'un pouce fait la meme taille partout, alors qu'un
manege plus grand voudrait une portee plus grande.

### Le prop, et ce qui ne tourne pas

```
Turnstile          <- place par _build (position / rotation_y / scale)
  Footing          <- STATIQUE. Ce contre quoi la rotation se lit.
  Spinner          <- le pivot, le SEUL noeud jamais tourne
    Deck
    Post
    Bars           <- MultiMeshInstance3D, TURNSTILE_BARS instances
```

**La dalle est deliberement HORS du pivot** : une rotation n'est lisible
que contre quelque chose qui reste en place, et un manege dont l'assise
tournerait avec lui se lirait comme le prop entier qui glisse. Gate par
sonde, y compris « la dalle est plus large que le plateau ».

`transform_format = MultiMesh.TRANSFORM_3D` est pose **en premiere ligne** :
`TRANSFORM_2D` est le DEFAUT en Godot 4.3, et un batch laisse dessus jette
toutes les transforms qu'on lui ecrit et dessine tout a l'origine -- le
piege que `_flush_batches()` avait deja du apprendre. `custom_aabb` est
ecrit et non hérité : une AABB fausse fait disparaitre le batch entier
quand la camera tourne, sans erreur.

### Le declencheur : `hop_landed`, AU-DESSUS de tous les retours anticipes

Il n'y a **aucun troisieme mecanisme parallele** a inventer : `_on_hop_landed`
est deja le point d'entree commun « Keepy a atterri ici », et tout le monde
y passe -- teinte d'eau, cue d'impact, embarquement, grimpe, portails. Le
tourniquet s'y branche juste sous le cue d'impact, **avant** chaque branche
qui `return`, pour la raison exacte que la teinte est ecrite en haut de
cette fonction : une reaction placee apres cesserait de tirer sur les
atterrissages qui FONT quelque chose, en silence et seulement parfois.

⚠️ **Un plongeon est gate DEHORS, explicitement et pas par le placement.**
Un plongeon n'est pas une marche. Le latch `_dive_pending` est lu dans une
copie (`was_dive`) avant d'etre consomme, et le tourniquet ne repond que si
elle est fausse. Le test de distance refuserait de toute facon un
atterrissage de plongeon aujourd'hui -- les planches sont au-dessus de
l'eau et le manege sur la terre ferme -- mais **c'est un fait sur le
LAYOUT, qui est de la DONNEE**, et une donnee se modifie sans qu'on relise
ce fichier.

**Debounce par IGNORER, jamais par redemarrer.** Un joueur qui retape le
meme endroit pendant que le haut coasse ne doit pas le voir repartir a
pleine vitesse. `_spin_near` enroule l'angle dans `[0, 360)` avant de
tweener -- le haut garde le cap ou il s'est arrete, ce que fait un vrai
manege, pendant que le nombre reste borne au lieu de grimper de 540 degres
par shove pour le reste de la session.

### ⚠️ DEUX DEFAUTS TROUVES AU RENDU, PAS A LA RELECTURE

La premiere passe utilisait `BOAT_HULL_COLOR` pour le cadre -- ce que le
plongeoir emprunte -- contre un plateau en `PONTOON_COLOR`. **Les deux
bruns sont assez proches pour que le poteau central DISPARAISSE et que les
barres se lisent comme des traits dessines sur la planche** : le prop
cessait d'etre un manege et devenait une assiette. Le cadre prend donc le
**liston pale du bateau** (`BOAT_RIM_COLOR`), deja sur la planche, et le
rayon des barres passe de 0,045 a **0,06** -- a 0,045, depuis la camera a
-34 degres de cet ecran, elles se lisaient comme des brindilles POSEES sur
le plateau plutot que comme des rails au-dessus.

**Aucune couleur neuve n'est installee** : plateau = planche de ponton,
cadre = liston du bateau, dalle = rocher du scatter.

### ⚠️ DEUX DEFAUTS TROUVES DANS MA PROPRE SONDE, publies plutot que lisses

1. **PHASE D assertait d'abord « l'angle ne bouge pas » a travers un
   re-atterrissage, et a echoue de 12,4 degres SUR DU CODE CORRECT.** Une
   rotation qui coasse AVANCE pendant les deux frames que coute un
   atterrissage : je mesurais le tween en train de faire son travail. Elle
   gate desormais ce qu'un tween empile ou redemarre ferait vraiment -- un
   saut EN ARRIERE (un redemarrage ré-enroule dans `[0, 360)`) ou un
   depassement de la cible en vol -- plus le fait que **deux atterrissages
   pendant une rotation voyagent exactement d'un seul shove**.
2. **Elle relisait l'origine du shove APRES l'atterrissage**, alors que le
   tween tournait deja : 214,11 mesure contre une vraie origine de 180,0.

### ⚠️ UN TROU DE COMPTAGE FERME : `HubPerfBaseline` sous-comptait d'un noeud

Deux sondes se contredisaient -- `TurnstileProbe` et `WaterTintProbe`
disaient **124**, `HubPerfBaseline` **123**. Cause :
`_count_mesh_instances()` ne comptait que `MeshInstance3D`. C'etait complet
tant que chaque batch du plateau etait un enfant DIRECT de HubBuilder
(l'appelant les traite dans sa propre branche) -- **le batch NICHE du
tourniquet lui etait invisible**. Corrige, et **aucun chiffre historique ne
bouge** : la colonne AVANT ci-dessous est mesuree avec le compteur CORRIGE
et rend toujours 120 / 126, parce qu'avant ce prop il n'existait aucun
batch niche sur le plateau.

### Placement : balaye, pas choisi a l'oeil

Balayage exhaustif au pas 0,5 puis affine a 0,25, avec exclusion de **l'eau
des cinq corps** (`HubWater`) plus une marge de 1,50 sur tout le pourtour du
disque -- un manege de cour de recreation ne se pose pas dans un lac, et
`HubRegion.contains()` dit « marchable » dans l'eau depuis que la
soustraction du grand lac a ete retiree.

**Retenu : (-4,00 ; 17,25)**, degagement **1,994 u** au prop le plus proche
(un arbre, index 111 du layout), 17,71 u du spawn. Mesure avec un rayon de
placement conservateur de 1,60 ; contre l'empreinte reellement declaree
(1,35) le degagement est de 2,244.

⚠️ **LE CONE AVANT DU SPAWN EST PLEIN, mesure** : dans les +-18 degres de
l'axe camera il n'existe que **12 candidats secs**, tous coinces dans la
rangee de portails, avec un degagement de **0,02 a 0,52 u** contre 1,99
disponible ailleurs. Le lobe spawn du grand lac plus les trois portails
l'occupent entierement. Le tourniquet est donc **derriere le spawn** et ne
se voit pas depuis l'ecran d'arrivee -- comme la moitie des props du
plateau, la camera ne lacetant jamais. **Signale, pas corrige** : cramer un
prop a 0,5 u d'une dalle de portail pour le rendre visible au spawn aurait
coute plus qu'il ne rapporte.

### La planche

`docs/color-sheets/turnstile_proportions_sheet.png` -- **4 lignes x 3
colonnes** : deck 1,15 / 4 barres (LIVRE), deck 1,15 / 3 barres, deck 1,45 /
4 barres, deck 1,45 / 3 barres ; colonnes = lacet du prop 0 / 22,5 / 45
degres, Keepy plante a cote pour l'echelle. **Rien n'est valide, Mathieu
tranche** -- et changer d'avis coute une constante.

⚠️ **La planche est rendue par un mock parametrique, et il est CONTROLE
avant qu'une tuile soit crue** : les transforms de son MultiMesh et le
rayon de son deck sont compares un a un a ceux du tourniquet REELLEMENT
construit dans la scene livree. `CONTROL: sheet mock reproduces the shipped
turnstile exactly = true`. Piege deja consigne et re-rencontre quand meme :
`HubCamera` se lerp sur Keepy chaque frame, donc sans couper son `_process`
une tuile sur quatre est cadree en plein glissement.

### `TurnstileProbe` : 32 checks, 0 echec, GATEE

Gatee et pas rapportee parce que **tout mode de panne de cette feature est
SILENCIEUX** : registre vide, pivot null, MultiMesh reste en TRANSFORM_2D,
declencheur accroche sous un retour anticipe, debounce qui laisse deux
tweens se disputer un angle. Aucun ne leve, aucun ne casse un build, et
tous ressemblent a « le tourniquet n'a jamais ete branche ».

**PHASE C achete le droit d'asserter un refus par un BLIND CHECK d'abord** :
« rien n'a tourne » passe gratuitement contre un declencheur jamais cable,
donc il faut prouver qu'une rotation PEUT arriver avant de mesurer qu'elle
n'arrive pas. Meme ordre que `WaterImpactProbe`, pour la meme raison.

PHASE A registre et contrat de noeuds (dont « la dalle est HORS du
pivot »), PHASE B le batch et ses pieges, PHASE C declenchement et refus,
PHASE D debounce, PHASE E le plongeon ne pousse rien / le latch est bien
consomme / **Keepy reste a y = 0 et dans aucun etat de planche ou de ride**,
PHASE F budget et separation d'avec les echelles (**22,255 u contre un
rayon de tap de 2,50**).

### Budget

| | AVANT | APRES |
|---|---|---|
| draw nodes hors portails | **120** | **124** |
| draw nodes, total | 126 | **130** |
| marge sous le plafond de 260 | 140 | **136** |

**+4, itemises** : une dalle, un plateau, un poteau, et **UN**
`MultiMeshInstance3D` pour les quatre barres. Detail perf, les deux cotes
mesures dans une seule session sur machine au repos :
`docs/HUB_PERF_BASELINE.md`. **Aucun cout n'est detectable** -- les plages
se chevauchent sur les trois metriques, ce qui soutient « rien de
mesurable » et pas « c'est plus rapide ».

### Validation

Editeur + templates Godot 4.3-stable installes dans ce sandbox (releases
GitHub officielles, **tailles verifiees contre le `Content-Length`** :
50 276 070 et 1 073 228 327 octets, aucune troncature silencieuse). Import
headless **exit 0, 24 `.scn`** (import complet verifie, pas suppose). Boot
de `HubWorld.tscn` **exit 0, 0 erreur, 0 `push_warning`** -- la
confirmation A L'EXECUTION que les 208 entrees sont coherentes. Export Web
release **exit 0**.

`index.wasm` **35 376 909** octets / md5
**`af4a8fc2925d992348eb30deeeb54360`**, `index.js` md5
**`4e08904b1b7107858246af44b602067b`** -- identiques au fingerprint deja
consigne pour tout lot qui ne touche pas le code moteur. `index.pck`
**5 892 576 puis 5 892 544** sur deux exports du MEME arbre, 32 octets
d'ecart : enieme illustration de l'instabilite deja consignee, **marqueur
et jamais preuve d'identite**. **Piege payload tenu** : sur **228** lignes
`Storing File`, **0** pour `scripts/dev`, `assets_source`, `docs`, `web/`,
`build` ou `firebase.json` -- et **0** occurrence de `TurnstileProbe` ou de
la planche dans le pack.

**Sondes, toutes exit 0** : `TurnstileProbe` (32), `DivingBoardProbe`
(**113**, `HubTapInput` etant partage), `WaterImpactProbe` (**23** --
le chiffre du brief, pas le 24 d'une note anterieure), `WaterTintProbe`
(48), `LakeZoneProbe`, `StreamRideProbe` (37), `AssetContractAudit` (12/12
visuels, **0/10 colliders deplaces**), `DeathModelAudit`,
`ChargerShapeProbe`, `ProbeTimeoutAudit` -- **53 -> 54 sondes scenes**,
**MESURE des deux cotes** (mes deux fichiers deplaces puis remis) et non
deduit du fait qu'un seul `.tscn` a ete ajoute. Les BLIND CHECKS existants
restent armes et verts.

### Reste ouvert -- jugement device, seul juge

1. **Est-ce que 1,5 tour en 2,2 s se lit comme une poussee qui coasse**, ou
   comme un prop qui glitche ? C'est tout l'objet du lot et aucune sonde ne
   le dit.
2. **Les proportions** : la planche compare deux tailles de plateau et deux
   comptes de barres, rien n'y est valide.
3. **Le tourniquet n'est pas visible depuis le spawn** (cone avant plein,
   mesure). A trancher : l'accepter comme un prop qu'on decouvre en
   marchant, ou rouvrir le placement.
4. **Keepy traverse le prop** comme il traverse tout le reste du decor
   (premisse n°2). Reel, mesure, et hors perimetre d'un lot de decor.
5. **Rien ici n'est un rendu device** : llvmpipe sous xvfb via le backend
   opengl3 BUREAU, contre WebGL2 sous Safari.

### Deploiement staging du tourniquet (palier 1, automatique)

`staging` **`d51fee4`** (merge `--no-ff`, arbre **byte-identique** a la
branche feature : meme hash d'arbre `1626b712` des deux cotes ET
`git diff` vide, verifie AVANT le push). CI run **#282**
(id 33148550179) -- `Import project resources` 06:37:57 -> 06:40:14,
**`Export Web build` 06:40:14 -> 06:40:19**, `Verify export output`
succes, `Deploy to Vercel [STAGING -- staging]` succes,
`[PRODUCTION -- main]` correctement **skipped**. **`main` NON touche**
(`origin/main` toujours `12a1d6b`, verifie apres le push).

**Verifie SUR LE SERVICE, pas dans le log CI, sur DEUX marqueurs
independants et aux DEUX bouts** :

| marqueur | avant (run #280) | apres (ce lot, run #282) |
|---|---|---|
| `CACHE_VERSION` | `1787892373` = **04:46:13** | **`1787899219` = 06:40:19** |
| `index.pck` servi | **5 888 448** | **5 892 592** |
| `index.wasm` servi | 35 376 909 | 35 376 909 *(inchange, attendu)* |

L'epoch d'apres tombe **exactement sur la fermeture de l'etape `Export Web
build`** du run #282, et **les deux lectures d'apres portent
`x-vercel-cache: MISS` avec `age: 0`**. Le trou du lot precedent est ferme :
les DEUX marqueurs sont relus aux deux bouts, pas un seul.

⚠️ **Limite dite plutot que sous-entendue** : les valeurs AVANT ont ete
prises **avant le merge** mais sur des reponses `HIT` avec un `age` non nul
(6595 et 6602 s). Elles sont valables comme **VALEURS** -- elles precedent
le push, donc ce sont bien celles de l'ancien build -- mais **ce ne sont
PAS des mesures de fraicheur**, et un parametre de requete different ne les
a pas bustees. Seules les lectures MISS/age 0 d'apres le sont.

⚠️ **`index.pck` prend un TROISIEME chiffre pour le meme contenu** : 5 892 576
et 5 892 544 sur deux exports locaux du meme arbre, 5 892 592 servi.
Marqueur « un nouveau build est en ligne », **jamais preuve d'identite** --
c'est `index.wasm` qui la porte, et il est identique partout.

⚠️ **L'API Actions n'etait PAS perimee sur ce run**, et c'est note dans ce
sens-la : les appels successifs montraient de vraies progressions d'etapes
avec de vrais horodatages, et l'import a reellement pris **2 min 17 s**.
Le piege existe ; il ne s'est pas produit ici, et le verifier coute un
regard a l'horloge.

## KEEPY MONTE SUR LE TOURNIQUET : un etat qui l'ecrit sur le pivot, et le "second tween parallele" evite PAR CONSTRUCTION (28 aout 2026)

Branche `claude/keepy-turnstile-riding-c10wvi`, partie de `staging`
(**`2bf755c`** -- le `d51fee4` annonce par le brief plus un commit DOC SEULE,
verifie ancetre plutot que suppose). Regle n°1 verifiee AU DEBUT : tri des refs
par date et comparaison des **ARBRES** -- `claude/tourniquet-hub-prop-qj4778`
porte **exactement l'arbre de `origin/staging`**, donc deja mergee, **aucune
session concurrente**. `origin/main` = `12a1d6b`, **INTOUCHE**.

**CONTRAINTES DURES TENUES, verifiees par `git diff` et pas affirmees** :
`HubRegion.gd`, `HubTapInput.gd`, `HubCamera.gd` et
`resources/hub/hub_layout.tres` **ne sont PAS dans le diff**.
`PLATEAU_HALF_EXTENT` reste **35.0**, `HOP_DISTANCE` **1.5**, `HOP_DURATION`
**0.28**, `HubCamera.OFFSET`/`FOLLOW_LAMBDA` inchanges. **Le tourniquet n'est
pas replace** : toujours (-4, 17.25), yaw 22.

### Le defaut, et ce qu'il n'etait PAS

Keepy TRAVERSAIT le tourniquet -- le plateau le coupait a mi-corps, les barres
lui passaient au travers. **Ce n'est pas un defaut du tourniquet** : aucun prop
de ce depot ne bloque une approche, c'est le regime de tout le decor. Il monte
dessus, donc, plutot que de se voir refuser le passage.

### Q1-Q2 -- le squelette repris, et le hook

`board()` -> `_state = RIDING` + `_place_on_route()` ; `_process` avance
l'abscisse et re-place ; `leave_ride()` repasse en HOPPING avec
`EJECT_HOP_HEIGHT` et `_hop_from_y/_hop_to_y`. C'est cette forme qui est
reprise. Le hook est bien `_on_hop_landed`, la ou `_spin_near` vit deja et
au-dessus de tous les `return` -- le montage partage donc **le meme
atterrissage et la meme reponse de proximite** que la poussee, si bien que le
prop sur lequel il est pose ne peut pas etre un autre que celui qui tourne.

### Q3 -- geometrie MESUREE sur l'arbre construit

Pivot (-4, 0, 17.25), scale 1, yaw 22. **Dessus du deck 0.31** (le
`CylinderMesh` est centre sur son origine : 0.26 + 0.10/2), rayon deck 1.15,
footing 0..0.06 rayon 1.35, post rayon 0.10 jusqu'a 0.98, **4 barres, pointes
a 1.0200, y 0.62**, trigger 2.40. Keepy : pieds a y=0, **hauteur 1.35006,
largeur 1.3198, profondeur 2.0371**.

⚠️ **PIEGE RE-RENCONTRE, deja consigne pour LAKE-MOVE : `--headless` ne peut
PAS relire les transforms d'un MultiMesh.** Le premier passage a rapporte
`bar0 origin=(0,0,0)` et `max|dx|=0.07` -- des zeros du driver DUMMY, pas la
geometrie. Sous `xvfb` les quatre barres sortent a 0/90/180/270 deg,
pointes 1.0200.

### Q4 -- le pivot porte bien les deux, et l'orbite est CALCULEE, pas parentee

Mesure : une rotation de +90 deg deplace bar0 de (-3.5271, 0.62, 17.0590) a
(-4.1910, 0.62, 16.7771) -- deck ET barres suivent.

**Keepy n'est PAS reparente**, et c'est un choix argumente : (a) le precedent
de ce fichier est d'ECRIRE le corps chaque frame (`_place_on_route`) plutot
que de le parenter a la coque, alors que la coque bouge ; (b) le `scale`
uniforme du layout est sur la racine `Turnstile`, donc un Keepy reparente
serait silencieusement redimensionne par une edition de DONNEES ; (c) `_yaw`
se composerait sous un parent tournant. Il est place par
`pivot.to_global(offset_local)` : **le meme transform que le deck et les
barres**, donc synchrone par construction et non par reglage.

### ⚠️ LE RAYON N'EST PAS CHOISI, IL EST DERIVE -- une fenetre de 3 cm

Face a l'exterieur (choix de Mathieu), la profondeur 2.0371 se couche le long
du rayon, donc la queue arrive a `r - 1.0187`. Le post central fait 0.10 et
monte jusqu'a 0.98 -- en plein dans la hauteur du corps -- donc la queue ne le
manque que si `r >= 1.1187`. Le bord du deck est a 1.15. **Toute la fenetre
legale est [1.119, 1.150]**, moins de quatre centimetres, et le bord en est
l'extremite naturelle. `TURNSTILE_RIDE_RADIUS = TURNSTILE_DECK_RADIUS`.

⚠️ **SON MUSEAU DEBORDE, mesure et non cache** : a ce rayon le modele atteint
2.17 du pivot contre un deck de 1.15 et un footing de 1.35. Keepy fait 2.04 de
long et le deck 2.30 de large : **un corps tourne vers l'exterieur ne peut
etre contenu par ce deck a AUCUN rayon**, c'est une propriete des deux tailles
et pas de ce nombre. Le tourner TANGENTIELLEMENT le ferait tenir (sa largeur
n'est que 1.32) -- c'est le seul levier si le device juge le debord mauvais.

### ⚠️ LE DEFAUT REEL DU LOT : un rider qui echantillonne un tween est une frame derriere

Premiere version : `_place_on_turnstile()` appele depuis `_process`. Rayon et
hauteur exacts a 1e-6, **mais la position angulaire derivait de 0.240317 u**.

⚠️ **Ma premiere metrique etait FAUSSE et annoncait 179.6 deg sur du code
correct** : une rotation +Y fait DECROITRE le relevement `atan2(z, x)`, donc
je comparais `dk` a `+dp` quand il fallait `-dp`. Remplacee par une mesure
sans convention -- l'offset **de-rotate par le pivot lui-meme**, qui est une
constante si le rider tourne avec lui.

Cause isolee par mesure : re-placer DANS la frame donne **3.93e-6 u**, donc le
siege est exact a l'instant du placement et les 0.240 sont l'ecart entre ce
moment et l'echantillon. L'arithmetique le confirme : cubic EASE_OUT, 540 deg
en 2.2 s, pic a 3x540/2.2 = **736 deg/s**, soit **12.3 deg par frame a 60 Hz**
contre **12.0 mesures**.

⚠️ **`process_priority` N'Y CHANGE RIEN -- 0.240317 au dernier chiffre pres,
les steps de Tween tombent apres le `_process` de tout noeud.** Il est
**RETIRE plutot que garde**, selon le precedent du clamp adaptatif du lot JUMP :
un fix qui ne corrige rien ne reste pas.

**Correctif : la poussee devient un `tween_method` qui ecrit l'angle PUIS le
rider, dans le meme appel.** Angles identiques (meme depart, meme arrivee,
meme trans, meme ease, meme duree), donc la poussee est celle validee sur
device au degre pres ; ce que la methode achete est qu'il n'existe plus de
frame entre les deux. **Derive sur 515.8 deg de poussee : 0.240317 u ->
0.000004 u.** C'est la regle que `_place_on_route()` suit deja pour que la
coque ne derive pas de son passager, atteinte par l'autre bout.

### ⚠️ LA BOUCLE INFINIE, ET LE LATCH QUI EST PROUVE PORTEUR

Un demontage se termine par un atterrissage ordinaire, et un atterrissage
ordinaire pres du prop est exactement ce qui le monte. La sortie est donc
mesuree **au-dela du rayon de DECLENCHEMENT** (2.40 + 0.85 = 3.25 mesures) et
non du seul footing -- sinon elle re-pousserait le prop en partant. Un latch
`_dismount_pending` double la garde, parce que "la sortie tombe assez loin"
est un fait de GEOMETRIE ET DE LAYOUT, et les layouts s'editent sans relire ce
fichier.

**Prouve porteur, pas decoratif** : latch neutralise + sortie ramenee dans le
rayon, Keepy finit a **y = 0.310 -- la hauteur du deck**, c'est-a-dire remonte.

### La sonde : 32 -> 50 checks, chacun verifie ROUGE d'abord

⚠️ **PHASE E est REECRITE, pas supprimee.** Elle affirmait que "rien chez
Keepy ne change jamais" -- la chose meme que ce lot change. Re-visee sur la
moitie qui tient encore et qui merite de l'etre : l'atterrissage d'un PLONGEON
le laisse au sol et ne le monte pas. Mesure **la, juste apres le plongeon**,
et non en fin de phase ou l'atterrissage ordinaire est desormais cense le
ramasser -- l'y mesurer serait asserter que la feature ne marche pas. Une
assertion positive ("un atterrissage ordinaire le monte BIEN") est ajoutee en
face : un test plongeon-contre-marche qui refuserait les deux passerait
gratuitement.

**Trois cassures deliberees, chacune attrapee** : rider non ecrit -> la
synchronie tombe ROUGE ; sortie dans le rayon -> "il atterrit HORS du rayon"
tombe ROUGE ; latch neutralise -> "le demontage ne l'a pas remonte" tombe
ROUGE. PHASE G porte son propre **BLIND CHECK** : tourner le pivot sans le lui
dire doit deplacer le siege (mesure 0.646 u), et un seul `follow_turnstile()`
le remet exactement (**< 0.001 u**) -- sans quoi le chiffre de derive passerait
gratuitement contre un rider qui n'aurait jamais bouge.

⚠️ **UNE ASSERTION A MOI EST PARTIE ROUGE SUR DU CODE CORRECT.** "il est assis
dans un ECART" testait `demi-ecart - off`, c'est-a-dire la distance au CENTRE
de l'ecart, correctement NULLE pour un rider assis en plein milieu. Le print le
disait : **"45.00 deg de la barre la plus proche, un demi-ecart vaut 45.00"**,
ce a quoi ressemble un siege parfait. Corrigee en deux assertions -- il est au
centre de l'ecart, et son propre demi-angle (**29.85 deg** a ce rayon) reste
sous les 45.

### Validation

Editeur + templates Godot 4.3-stable installes (releases GitHub officielles).
⚠️ **Le `.tpz` est arrive TRONQUE au premier essai -- 925 499 392 contre
1 073 228 327, sans erreur curl.** Piege deja consigne ; retelecharge en ENTIER
(jamais `curl -C -`), taille reverifiee contre le `Content-Length`.

Import headless **exit 0, 24 `.scn`** (import complet verifie, pas suppose).
Boot de `HubWorld.tscn` **0 erreur**. Export Web release **exit 0, 0 erreur**.
`index.wasm` **35 376 909** / md5 **`af4a8fc2925d992348eb30deeeb54360`**,
`index.js` md5 **`4e08904b1b7107858246af44b602067b`** -- identiques au
fingerprint deja consigne pour tout lot qui ne touche pas le code moteur.
`index.pck` 5 897 376, **marqueur et jamais preuve d'identite**. Piege payload
tenu : sur **228** lignes `Storing File`, **0** pour `scripts/dev`,
`assets_source`, `docs`, `web`, `build` ou `firebase.json`.

⚠️ **`--script` ne charge PAS les autoloads** (`Identifier not found: SafeArea`)
-- piege deja consigne, la verification syntaxique passe par un boot de scene.

**Sondes, toutes exit 0** : `TurnstileProbe` **50** (32 en baseline),
`DivingBoardProbe` **113**, `WaterTintProbe` **48**, `StreamRideProbe` **37**,
`WaterImpactProbe` **23**, `LakeZoneProbe`, `ProbeTimeoutAudit`,
`AssetContractAudit` (**12/12 visuels, 0/10 colliders deplaces**),
`DeathModelAudit`, `ChargerShapeProbe`.

**`_apply_hop` re-echantillonne** (le fichier est touche) : **0.000000000000 u
de divergence pire sur 1001 points**, sur le hop plein, le dernier hop court
ET l'eject.

**Draw nodes REMESURES des deux cotes dans cette session** -- `origin/staging`
en worktree separe, import verifie complet (24 `.scn`) : **124 hors portails /
130 au total AVANT ET APRES**, et **54 scenes de sonde des deux cotes**. Aucune
geometrie ajoutee, comme il se doit : un etat n'est pas un mesh.

### Reste ouvert -- jugement device, seul juge

1. **Est-ce qu'un Keepy pose au bord, museau au-dessus du vide, se lit comme un
   PASSAGER** plutot que comme un prop tombe ? Le debord de 1.02 au-dela du
   bord est mesure et structurel (§ Q4) ; sa lecture ne l'est pas. C'est le
   risque principal du lot, et le seul levier est de le tourner
   tangentiellement.
2. **Les barres passent a hauteur de genou** (0.62 local contre un corps de
   1.35 debout sur 0.31), donc elles le traversent toujours -- il est assis
   ENTRE deux d'entre elles, pas au-dessus. Mesure, assume, jamais juge a
   l'oeil.
3. **La duree du tour est celle de la poussee** (2.2 s) : personne n'a encore
   vu si etre embarque aussi longtemps sans pouvoir rien faire est agreable ou
   long -- un tap pendant le tour est DELIBEREMENT sans effet.
4. **Aucun son, aucune particule, aucun asset** : hors perimetre.

### Deploiement staging du tourniquet ridable (palier 1, automatique)

`staging` **`5f7ee7b`** (merge `--no-ff`, arbre **byte-identique** a la branche
feature : meme hash d'arbre `ccb31a4` des deux cotes ET `git diff` vide,
verifie AVANT le push). CI run **#284** (id 33153748835) **verte** --
`Import project resources` 08:03:04 -> 08:05:42, **`Export Web build`
08:05:42 -> 08:05:47**, `Deploy to Vercel [STAGING -- staging]` **succes**
(08:06:04 -> 08:06:15), `[PRODUCTION -- main]` correctement **skipped**.
**`main` NON touche** (`origin/main` toujours `12a1d6b`, verifie apres le
push) : ce lot corrige un defaut CONSTATE SUR DEVICE, donc la validation
doit se faire sur device avant tout palier 2.

**Verifie SUR LE SERVICE, sur DEUX marqueurs independants, et les QUATRE
lectures sont `x-vercel-cache: MISS` avec `age: 0`** -- les valeurs "avant"
ayant ete relevees AVANT le merge, la bascule est prouvee dans les deux sens
et pas deduite du log :

| marqueur | avant (run #283) | apres (ce lot, run #284) |
|---|---|---|
| `CACHE_VERSION` | `1787899481` = **06:44:41** | **`1787904346` = 08:05:46** |
| `index.pck` servi | **5 892 560** | **5 897 408** |
| `index.wasm` servi | 35 376 909 | **35 376 909** *(inchange, attendu)* |

L'epoch d'apres tombe **a l'interieur de la fenetre `Export Web build`**
(08:05:42 -> 08:05:47) : l'alias sert bien ce build.

⚠️ **`index.pck` prend une valeur de plus pour le meme contenu** : 5 897 376 a
l'export local propre contre 5 897 408 servi, **32 octets d'ecart**. Enieme
illustration de l'instabilite deja consignee -- le `.pck` est un marqueur
"nouveau build", **jamais** une preuve d'identite. `index.wasm` (**35 376 909**,
md5 `af4a8fc2925d992348eb30deeeb54360`) est identique des deux cotes et c'est
lui la preuve d'identite.

⚠️ **L'API GitHub Actions N'ETAIT PAS perimee sur ce run, et c'est note dans ce
sens-la** : les appels successifs ont rendu de vraies progressions d'etapes
avec de vrais horodatages, et l'import a reellement pris **2 min 38 s**. Le
piege existe ; il ne s'est pas produit ici, et le verifier coute un regard a
l'horloge.

## DEUX CORRECTIFS INDEPENDANTS : LES ILOTS NE SONT PLUS DE L'EAU, LE TOURNIQUET TOURNE SANS LIMITE (28 aout 2026)

⚠️ **DEROGATION DE BRANCHE, ASSUMEE ET SIGNALEE.** Le brief nommait deux
branches distinctes a titre d'exemple (`claude/fix-water-islands`,
`claude/turnstile-infinite-spin`). La contrainte d'environnement de cette
session imposait explicitement une seule branche pre-designee
(`claude/keepy-water-islands-turnstile-uyrwbo`) et interdisait tout push
ailleurs sans permission explicite. **Les deux lots sont donc livres comme
DEUX COMMITS ATOMIQUES distincts sur cette branche unique**, chacun
independamment verifiable et revertable, puis merges ensemble sur `staging`
en UN SEUL merge commit -- exactement le compromis que la contrainte
laissait ouvert (deux lots independants, deux commits independants, un seul
vehicule de merge). Rien n'a ete fusionne au niveau du CODE : les deux
diffs ne partagent aucune ligne.

### LOT A -- LES ILOTS DU GRAND LAC ETAIENT TOUJOURS DE L'EAU, ET UN SEUL SYSTEME EN ETAIT LA CAUSE

Retour de Mathieu, capture a l'appui : les petits ilots du grand lac (dont
celui pres du plongeoir/tourniquet) sont toujours traites comme de l'eau,
alors que Keepy s'y tient et y marche normalement.

**Recon en quatre points, faite AVANT tout patch, comme le brief l'exigeait
-- et elle isole UN SEUL coupable, pas plusieurs.**

1. `grep` sur toute drapeau/flag d'eau du depot : deux systemes distincts
   repondent chacun a une question differente sur la meme geometrie --
   `HubRegion.contains()` ("Keepy peut-il se TENIR ici ?", walkability) et
   `HubWater.body_at()` ("Keepy est-il MOUILLE ici ?", tint/splash visuels).
2. `HubRegion.gd` lu en entier : depuis le lot du 27 aout ("rename
   colliding LAKE_WATER_RADIUS, remove great-lake water guard"), il
   **N'EXCLUT PLUS AUCUNE EAU** -- Mathieu a decide que toute l'eau du
   plateau est marchable. Ce fichier est donc **structurellement
   innocent** : il n'a jamais pu produire le defaut rapporte, et n'a pas
   ete touche.
3. Les drapeaux `offshore` de `hub_layout.tres` : verifies **absents**
   (0 occurrence), retires par le lot "drop the 11 stale offshore flags"
   du meme jour. Ecarte aussi.
4. **`HubWater.body_at()` reste seul en lice, et c'est bien lui** : c'est
   le seul appelant que `HubWorld._on_hop_landed()` consulte pour
   `_set_keepy_wet(in_water)` **et** pour declencher l'effet d'impact
   (splash) -- les deux effets visuels signales partagent la meme
   variable `in_water`, donc un seul systeme suffit a expliquer les deux
   symptomes a la fois.

**Cause exacte, lue dans le code, pas devinee** : `body_at()` etait un pur
test de disque (`distance_to(centre) < radius`) sur quatre corps (mare,
petit lac, les deux lobes du grand lac) plus un test de ruban pour le
ruisseau -- **aucune notion d'ilot**. Le grand lac porte trois entrees
`&"islet"` dans `hub_layout.tres` (rayons 3.20 / 3.40 / 3.00, a 6.80-9.98 u
du centre du lac contre son propre rayon de 16.0 u) : chacune est un
banc de galets plat sur lequel le joueur marche, **bien a l'interieur** du
disque d'eau du lac qui le porte. Un simple test de disque ne peut pas les
voir -- `body_at()` repondait `"great_lake_0"` sur le CENTRE d'un ilot
exactement comme sur de l'eau libre a cote.

**Fix -- une soustraction, pas une redefinition** :
`HubBuilder.gd` gagne `_islets: Array[Dictionary]` (rempli dans `_build()`
sur chaque entree `&"islet"`, rayon **tel que reellement dessine**, meme
discipline que `pond_centre()`/`small_lake_centre()` -- ne jamais relire le
layout une seconde fois ailleurs) et un accesseur `islets()`.
`HubWater.gd` gagne son propre `_islets` (lu depuis `builder.islets()` dans
`_init`), **teste EN PREMIER, avant tout disque et avant le ruisseau** :
etre sur un ilot exclut l'eau sans conditions, il ne rivalise pas avec elle
pour la reponse.

```gdscript
func body_at(point: Vector3) -> StringName:
	var flat := Vector3(point.x, 0.0, point.z)
	for islet in _islets:
		if flat.distance_to(islet["centre"] as Vector3) < float(islet["radius"]):
			return &""
	for disc in _discs:
		if flat.distance_to(disc["centre"] as Vector3) < float(disc["radius"]):
			return disc["name"] as StringName
	if _route != null and _route.distance_to(flat) < _stream_half_width:
		return &"stream"
	return &""
```

**Validation, rouge avant vert** : `WaterTintProbe` gagne **PHASE A2**
(5 checks) -- le centre de chacun des 3 ilots lit "sec", et un point a
0.2 u au-dela du bord propre de chaque ilot redevient de l'eau. Prouvee
rouge d'abord en desactivant temporairement (sans toucher aux accesseurs,
pour ne pas faire echouer le parsing du script) la seule boucle
d'exclusion : **exactement 3 FAIL**, un par ilot -- reproduit le defaut
rapporte au chiffre pres avant d'etre corrige. Aucune geometrie neuve :
`_EXPECTED_DRAW_NODES_EXCL_PORTALS` reste **124**, inchange.

### LOT B -- LE TOURNIQUET NE FAISAIT QU'UN SEUL TOUR, MEME EN RETAPANT DESSUS

Comportement actuel : le tourniquet fait exactement un tour (1.5 tour,
ease-out, ~2.2 s) puis ejecte Keepy automatiquement. Comportement voulu :
un tap sur le tourniquet PENDANT qu'il tourne (etat `ON_TURNSTILE`)
relance un tour complet au lieu d'ejecter, indefiniment tant que Mathieu
retape ; l'ejection automatique reste le repli si aucun tap ne suit.

**Recon stricte, lecture seule, sur les trois fichiers partages AVANT tout
patch** (le plongeoir et la barque partagent le meme motif `RIDE_SEAT_Y`,
donc toute modification de ces fichiers est a haut risque de regression) :

1. **`KeepyHopper.gd` lu en entier (~1057 lignes)** : `hop_to()` est deja
   **inerte** pendant `ON_TURNSTILE` (`if _state != State.IDLE and
   _state != State.HOPPING: return`) -- **aucun changement necessaire ici**.
   La sortie du tour est pilotee de l'EXTERIEUR (par le callback de fin de
   tween de `HubWorld.gd`), pas par ce fichier.
2. **`HubTapInput.gd` lu en entier (198 lignes)** : emet
   `tapped_ground`/`tapped_boat`/`tapped_ladder`
   **INCONDITIONNELLEMENT**, sans aucune notion de l'etat de ride de
   Keepy -- toute la logique de suspension vit dans `HubWorld.gd`, pas
   ici. **Repond directement a la question 3 du brief : aucun changement
   necessaire dans ce fichier non plus.**
3. **`HubWorld.gd`** : localise l'endroit exact ou un tap pendant
   `ON_TURNSTILE` etait avale sans effet (`_on_tapped_ground()`, branche
   tourniquet, `return` inconditionnel) et le callback qui termine le
   tour (`_on_turnstile_spin_finished` -> `leave_turnstile()`).

**Fix, dans `HubWorld.gd` uniquement** -- le tween-construction de
`_spin_near()` est extrait dans un helper partage
`_build_turnstile_spin(entry)` (memes parametres exacts :
`TURNSTILE_SPIN_TURNS`, `TRANS_CUBIC`/`EASE_OUT`, `TURNSTILE_SPIN_S`).
Nouvelle fonction `_reshove_turnstile(point)` : verifie que le tap tombe
dans le rayon de declenchement du tourniquet MONTE, **tue l'ancien tween**
(`Tween.kill()` -- verifie qu'il n'emet PAS `finished`, donc aucune
ejection parasite), construit un tween frais via le helper partage, et
reconnecte `_on_turnstile_spin_finished` en `CONNECT_ONE_SHOT`. La branche
tourniquet de `_on_tapped_ground()` appelle desormais `_reshove_turnstile`
avant son `return`.

⚠️ **Le debounce existant de `_spin_near()` (ignorer une poussee si un
tween tourne deja, pour qu'une simple marche a proximite ne relance pas un
prop qui coasse) est DELIBEREMENT PAS reutilise ici** : pendant un ride, un
tween tourne EN PERMANENCE -- le reutiliser aurait avale chaque retap en
silence, exactement l'inverse de la feature demandee. D'ou une fonction
dediee plutot qu'un partage naif.

**Validation, rouge avant vert** : `TurnstileProbe` gagne **PHASE H**
(8 checks) -- un retap en plein tour demarre un tween **REELLEMENT
NOUVEAU** (pas le meme objet) et tue l'ancien ; il maintient Keepy a bord
au-dela de la duree d'un seul tour ; sans retap suivant, le tour prolonge
se termine quand meme tout seul et atterrit dans la region marchable ;
trois retaps consecutifs le maintiennent a bord a chaque fois ; lacher
prise ensuite le laisse descendre normalement. Prouvee rouge en
court-circuitant temporairement `_reshove_turnstile` en no-op :
**exactement 4 FAIL**, reproduisant le defaut rapporte (Keepy perd l'etat
"a bord" apres le seul tour) avant d'etre corrige. La PHASE G existante
("un tap a 12 u, hors du rayon de declenchement, pendant le ride est
ignore, pas marche") reste **inchangee et toujours valide** -- ce tap
depasse aussi le rayon du nouveau `_reshove_turnstile`.

**Non-regression plongeoir/barque, explicitement verifiee et pas
supposee** : aucune ligne de `KeepyHopper.gd` ni de `HubTapInput.gd` n'est
touchee par ce lot ; `DivingBoardProbe` (**113/113**) reste
byte-identique a `origin/main`.

### VALIDATION COMMUNE AUX DEUX LOTS

Editeur + templates Godot 4.3-stable dans ce sandbox (releases GitHub
officielles). Import headless **exit 0**, boot **exit 0**, export Web
release **exit 0, 0 erreur GDScript**. `index.wasm`/`index.js` **identiques
au fingerprint permanent** de tout lot qui ne touche pas le code moteur --
coherent, aucun de ces deux fixes ne touche `project.godot` ni aucune
ressource hors `scripts/hub/` et `scripts/dev/`.

**Quatre sondes partagees, diffees contre `origin/main` en worktree
separe : BYTE-IDENTIQUES sur les deux flux** -- `ProbeTimeoutAudit`,
`AssetContractAudit` (12/12 visuels, 0/10 colliders deplaces),
`DeathModelAudit`, `ChargerShapeProbe`. **`LakeZoneProbe` (25 checks,
0 echec) rejouee sur les deux arbres, `--fixed-fps 60`, graine 20260806 :
BYTE-IDENTIQUE** entre baseline et branche -- confirmation independante
que ni `HubRegion.in_lake_water()` ni les timings de traversee ne bougent,
alors qu'aucun des deux lots ne touche `HubRegion.gd`.

**Piege payload verifie sur le log `savepack`** : 0 ligne `Storing File`
pour `res://scripts/dev`, `assets_source`, `docs`, `web` ou `build`.

### DEPLOIEMENT STAGING (palier 1, automatique)

`staging` (**b37de5c**, merge `--no-ff` des deux commits atomiques
`e90e922`/`23949df` sur `341d0dc`). CI run **#287**
(id 33160805893) **verte** : import 09:47:59 -> 09:50:52 (2 min 53 s),
export Web 09:50:52 -> 09:50:57, `Deploy to Vercel [STAGING -- staging]`
succes, `[PRODUCTION -- main]` correctement **skipped**. **`main` NON
touche** (`origin/main` reste `fe0f4d7`) : palier 2, gate Mathieu apres
validation device des deux correctifs.

**Verifie SUR LE SERVICE, pas seulement dans le log CI, aux DEUX bouts** :

| marqueur | avant (run #285, `341d0dc`) | apres (ce lot, run #287) |
|---|---|---|
| `CACHE_VERSION` | `1787904701` = **08:11:41 UTC** | **`1787910657` = 09:50:57 UTC** |
| `index.pck` servi | -- | **5 898 432** |
| `index.wasm` servi | -- | **35 376 909** |

L'epoch d'apres tombe **exactement sur la fermeture de l'etape `Export Web
build`** du run #287 (09:50:52 -> 09:50:57), et la lecture porte
**`x-vercel-cache: MISS`, `age: 0`**, `last-modified` colle a l'instant de
la requete. La lecture d'avant portait `x-vercel-cache: HIT`, `age: 4317` --
valable comme VALEUR (elle precede le push) mais **pas une mesure de
fraicheur**, comme toujours dans ce fichier.

**`index.wasm` est la preuve d'identite** : md5 servi identique a l'export
local (**`af4a8fc2925d992348eb30deeeb54360`**), et `index.js` md5
**`4e08904b1b7107858246af44b602067b`** -- le fingerprint permanent de tout
lot qui ne touche pas le code moteur, confirme ici pour un lot qui ne
touche que `scripts/hub/*.gd`. **`index.pck` n'est PAS offert comme
preuve** : l'export local propre donne 5 898 464 octets contre 5 898 432
servis, 32 octets d'ecart -- l'instabilite deja consignee (variance de la
passe de compression VRAM sur les textures des autres assets), jamais une
preuve a elle seule.

### Reste ouvert -- jugement device, seul juge

1. **LOT A** : est-ce que marcher sur un ilot se lit desormais comme de la
   terre ferme (pas de teinte, pas d'eclaboussure a l'atterrissage) sur
   les trois ilots du grand lac, a l'echelle reelle d'un telephone.
2. **LOT B** : est-ce que retaper le tourniquet en plein tour se ressent
   comme "je le relance" plutot que comme un bug d'un tour qui ne
   s'arrete jamais -- et si le rythme de spins consecutifs reste
   confortable au pouce.
3. Aucun des deux lots ne touche a l'art, aux couleurs, ni au gameplay de
   Chased/Quizz/Battle -- hors perimetre, inchange.

### Merge en production (28 aout 2026, autorisation explicite de Mathieu)

`staging` (`0a7fe05`) -> `main`, commit de merge **`785390f`**, `--no-ff`,
apres validation device confirmee sur les deux lots ("ilots ne
declenchent plus la teinte/impact", "tourniquet tourne indefiniment sur
re-tap, ejection normale au lacher prise").

**Verifie AVANT le merge** : `git fetch --all --prune`, `origin/main`
(`fe0f4d7`) et `origin/staging` (`0a7fe05`) exactement les SHA annonces,
aucune divergence. `main..staging` porte les quatre commits attendus
(`e90e922` fix ilots, `23949df` re-shove tourniquet, `b37de5c` merge,
`0a7fe05` doc), rien de plus. `git rev-parse HEAD^{tree}` et
`git rev-parse origin/staging^{tree}` **identiques** (`01f329047...`)
avant le push -- ce qui part en prod est litteralement l'arbre valide,
pas une recomposition. Merge `--no-ff` sans conflit.

CI **run #289** (id `33164821995`) **verte** (10:49:36 -> 10:52:56 UTC) --
`Import project resources` 10:50:10 -> 10:52:27, `Export Web build`
10:52:27 -> 10:52:32, `Deploy to Vercel [PRODUCTION -- main]` **succes**
10:52:48 -> 10:52:56, `[STAGING -- staging]` correctement **skipped**
(push sur `main`).

**Verifie SUR LE SERVICE, pas seulement dans le log CI** :

| marqueur | valeur servie |
|---|---|
| `CACHE_VERSION` | `1787914351` = **10:52:31 UTC** -- tombe exactement dans la fenetre `Export Web build` (10:52:27 -> 10:52:32) |
| `x-vercel-cache` / `age` | `MISS` / `0` sur `index.html` ET `index.service.worker.js` |
| `index.wasm` servi | **35 376 909** octets |
| `index.pck` servi | 5 898 448 octets (marqueur "nouveau build", jamais preuve d'identite) |

`index.wasm` **35 376 909 octets** -- identique au fingerprint permanent
deja consigne pour tout lot qui ne touche pas le code moteur, coherent :
ce merge n'ajoute aucun commit de code au-dela de ce qui etait deja
valide sur staging, aucune sonde n'a ete rejouee ici (pas de code
nouveau depuis la derniere verification sur l'arbre fusionne).

**Le hub plateau 3D avec ses lacs, ilots et tourniquet est desormais EN
PRODUCTION** sur `keepy-ten.vercel.app`, avec les deux correctifs (fix
teinte/eclaboussure des ilots, re-shove illimite du tourniquet)
integres.

**Reste ouvert : aucun sur ce merge.** Les deux points laisses ouverts
par le lot de staging (lisibilite des ilots, ressenti du re-shove) sont
**clos** par la validation device confirmee ci-dessus.

## LE LOBE NORD ET LA BALANCOIRE : le carre grandit par FORME pour la premiere fois, et trois premisses tombent a la mesure (28 aout 2026)

Branche `claude/hub-north-lobe-seesaw-pa8u21`, partie de `main` (`b00fa1d`,
verifie par ARBRE et pas par nom : `origin/main` est la ref la plus recente du
depot, `origin/staging` est strictement en retard des deux commits du merge de
prod, **aucune session concurrente**).

**CONTRAINTES DURES TENUES, verifiees par `git diff --stat`** :
`PLATEAU_HALF_EXTENT` reste **35.0**, `HOP_DISTANCE` **1.5**, `HOP_DURATION`
**0.28**, `HubCamera` **n'est pas dans le diff du tout**. Aucun asset Meshy.

Decisions de Mathieu, prises sur la recon precedente et **non re-arbitrees
ici** : lobe CONTIGU unionne dans `HubRegion` (option A), azimut **NORD (+Z)**,
rayon **12**, **balancoire seule**.

### MONO-ALTITUDE : verifie, et il n'y a rien a refactorer

Le brief demandait un STOP si un point du lobe ou de la balancoire exigeait une
hauteur de SOL non nulle. **Mesure : non, et sur les deux axes.**

* **Le sol reste a y = 0 partout.** Les 215 entrees de `hub_layout.tres`
  portent `y = 0.0` **sans exception** (parcourues, pas supposees), le lobe
  ajoute du sol a y = 0, `HubTapInput` raycaste toujours contre
  `Plane(UP, 0.0)` et `HubRegion._flat()` jette toujours le Y. Aucun de ces
  trois fichiers ne change de modele.
* **Keepy monte, mais par ETAT et jamais par TAP.** Sa hauteur ne varie que
  pendant `ON_SEESAW`, exactement comme `ON_TURNSTILE` le fait deja a 0,31 et
  `ON_BOARD` a 1,80. Le precedent est ecrit noir sur blanc dans la section
  plongeoir : **« LE DECK N'EST PAS PRATICABLE, PAR CONSTRUCTION ET PAR
  CHOIX »** -- il n'existe structurellement aucun tap qui signifie « un point
  sur la planche ». La balancoire suit la meme regle.

Donc pas de STOP, pas de refactor improvise, et le mono-altitude est preserve
par construction et non par chance.

### ⚠️ PREMISSE FAUSSE N°1 : les appelants ne sont pas TROIS, ils sont QUATRE

Le brief annoncait « 3 sites appelants : `HubTapInput._handle_point`,
`HubWorld` x2 ». Mesure par `grep` sur tout le depot -- il y en a **quatre**,
repartis sur **trois fichiers** :

| site | appel |
|---|---|
| `HubTapInput._handle_point:168` | `clamp_to()` -- un tap devient une destination |
| `HubWorld._ride_exit_point:506` | `clamp_to()` -- le repli d'un demontage |
| `HubWorld._ride_exit_point:515` | `contains()` -- chaque candidat de l'anneau |
| `HubBuilder._build:966` | `contains()` -- ce prop est-il atteignable |

**Aucun des quatre ne restate la geometrie**, et c'est toute la proposition de
valeur de l'option A. Confirme **par mesure et pas par lecture** : PHASE CLAMP
de la sonde exerce les quatre chemins sur le lobe -- 361/361 taps a l'interieur
laisses en place, 361/361 au-dela ramenes sur du sol reellement contenu, et les
7 props du sol neuf tous walkable. **Zero ligne modifiee dans ces trois
fichiers pour le lobe.**

### ⚠️ PREMISSE FAUSSE N°2 : une assertion de `LakeZoneProbe` devient FAUSSE PAR CONCEPTION

`LakeZoneProbe` gate `beyond == 0` -- « la berge n'ajoute rien au-dela du
carre » -- et l'implemente par un balayage generique sur `contains()`. **Le
lobe ajoute du sol au-dela du carre : c'est ce pour quoi il est ecrit.**
L'INTENTION de l'assertion (le shore pad est inerte) reste vraie et vaut d'etre
gatee ; son IMPLEMENTATION a expire.

Corrigee plutot que supprimee ou contournee : le balayage compte desormais les
points au-dela du carre **que le lobe n'explique pas**. Et l'exclusion est
payee sur la ligne suivante -- **un lobe lui-meme devenu inerte ferait passer
ca gratuitement**, donc le balayage doit AUSSI voir le sol du lobe
(`lobe_points > 0`). Un chiffre ne se croit pas sans l'autre.

Sa ligne `worst reachable |axis|` passe de **35,00 a 47,00** (demi-extension +
rayon du lobe) contre un sol de demi-taille 300 : **rapporte, pas masque**, et
son gate (`reach < half`) tient avec un facteur 6,4.

### ⚠️ PREMISSE FAUSSE N°3 : le `_EXPECTED_DRAW_NODES_EXCL_PORTALS` de DEUX autres sondes

`TurnstileProbe` et `WaterTintProbe` portent la meme constante a 124. Le prop
en ajoute 3. **Montees a 127 et ITEMISEES** (fulcrum + planche + UN batch de
poignees) plutot que poussees : une constante de budget qui derive en silence
est un budget que personne ne surveille.

### Le lobe

`( carre(+-35) OU shore pad OU lobe nord )`. Disque de **rayon 12 centre sur le
MILIEU DE L'ARETE +Z**, `(0, 35)`, unionne. Le centre est **DERIVE** de
`PLATEAU_HALF_EXTENT` et non ecrit en litteral : le lobe est defini « sur
l'arete nord », donc si le carre bouge un jour le lobe doit bouger avec.

**Disque ENTIER et pas demi-disque** : la moitie interieure est deja carree,
donc les deux ecritures decrivent la meme region -- et un disque est la forme
que `clamp_to()` sait deja traiter. Un lobe dont le centre serait au-dela de
l'arete laisserait au contraire une encoche a la jonction.

| | mesure |
|---|---|
| sol neuf, **mesure sur le `contains()` livre** | **224,89 u2** (analytique 226,195) |
| part du carre de 4 900 u2 | **+4,590 %** |
| portee maximale de la region | \|z\| = **47,00** contre un sol de 300 |
| props deplaces | **ZERO** |

**+Z parce que la moitie exterieure est VIDE, mesure et pas suppose** : le
plus grand \|z\| du layout est **33,895**, donc rien ne se tient au-dela de
l'arete nord et le lobe ne coute a aucun prop une relocalisation -- contrairement
au grand lac, qui en avait coute 32.

⚠️ **LE LOBE EST DERRIERE LE SPAWN, et c'est structurel** : `HubCamera` ne
lacete jamais, donc le joueur ne voit QUE ce qui est a un z inferieur au sien.
En marchant vers +Z il a la balancoire dans le dos ; il la decouvre en la
depassant, et les **8,5 u** de sol laissees au nord d'elle sont exactement ce
qui lui permet de se placer pour la voir. Mathieu a choisi cet azimut en
connaissance de cause, aux memes conditions que le tourniquet avant elle.

⚠️ **POURQUOI UNE FORME ET PAS UN PLUS GRAND CARRE, re-mesure ici plutot que
cite** : la recon du lot D place la derniere demi-extension carree sous le
budget de 22 s a 40 (21,533 s ; 41 donne 22,100 s). Un lobe boulonne sur une
ARETE n'ajoute rien a une diagonale entre COINS -- **PHASE CROSSING marche le
pire couple sur le vrai hopper** :

| trajet | hops | frames | secondes |
|---|---|---|---|
| diagonale du carre *(publie 66 / 18,700)* | **66** | **1122** | **18,700** |
| coin oppose -> pointe du lobe | 60 | 1020 | **17,000** |

La diagonale **se reproduit au frame pres** -- un banc incapable de restituer
un chiffre deja au dossier n'a pas qualite a en publier un neuf -- et le pire
trajet que le lobe cree est **PLUS COURT**. La diagonale reste la pire marche
du jeu.

### La balancoire

`&"seesaw"`, une entree, a **(0,00 ; 38,50)** -- dans le sol NEUF, 3,5 u
au-dela de l'arete, avec **8,5 u** de recul au nord (le seul cote depuis lequel
une camera qui ne lacete jamais peut la cadrer) et **8,15 u** de degagement au
prop le plus proche. Trois noeuds de dessin, aucun asset :

```
Seesaw            <- place par _build (position / rotation_y / scale)
  Fulcrum         <- STATIQUE. Ce contre quoi la bascule se lit.
  Pivot           <- le SEUL noeud jamais incline
    Plank
    Grips         <- MultiMeshInstance3D, 2 instances
```

**Le fulcrum est HORS du pivot**, exactement comme le footing du tourniquet est
hors de son spinner : une rotation n'est lisible que contre quelque chose qui
reste en place. **La planche court le long de X** et non de Z -- `HubCamera`
regarde -Z a pitch fixe, donc une planche selon X est de travers a l'ecran et
sa bascule se lit en VERTICAL ECRAN ; selon Z elle basculerait vers et loin de
la camera, la seule direction qu'un cadrage fixe rend comme presque aucun
mouvement.

⚠️ **UNE INEGALITE, PAS UN LOOK : la hauteur du fulcrum est ce qui garde la
planche hors du sol.** Le coin bas d'une planche inclinee est a
`fulcrum - (L/2)·sin(tilt) - (e/2)·cos(tilt)` = `0,62 - 1,80·sin(15) -
0,07·cos(15)` = **0,0865** -- positif de 8,6 cm, et **gate** plutot
qu'argumente, pour qu'un lot futur qui rallonge la planche ou creuse la bascule
soit prevenu au lieu de l'enfoncer.

**Interaction : declenchement par `hop_landed` dans le rayon**, le patron du
tourniquet. Le brief laissait l'arbitrage ouvert entre « bascule automatique au
poids » et « tap pour actionner » et demandait, en cas d'ambiguite, le plus
proche du patron etabli. **Les deux lectures convergent ici** : un
atterrissage EST le poids, et c'est aussi exactement ce que le tourniquet fait.
Le tap reste utile pendant la course -- il **re-pompe** la bascule, jamais il
ne devient une destination.

⚠️ **La bascule est un ROCK AMORTI, et le retour a plat est ARITHMETIQUE**
plutot qu'un reglage : `cos(TAU·2,5·t)·(1-t)`, dont le facteur `(1-t)` est nul
a `t = 1` quoi que fasse le cosinus -- la planche ne peut pas etre laissee
penchee. Le tween est **LINEAIRE** exprès : le cosinus EST l'amortissement, un
`EASE_OUT` par-dessus adoucirait une courbe deja adoucie.

⚠️ **Defaut d'ordonnancement trouve en ecrivant le code, pas apres.** Le cote
qui descend etait d'abord ecrit dans `_mount_seesaw`, c'est-a-dire APRES que
`_rock_near` ait deja lance le tween -- donc la premiere frame de la bascule
aurait penche du mauvais cote chaque fois que le moteur aurait step le tween en
premier. Deplace dans `_rock_near`, decide **une fois, depuis le point
d'atterrissage**, avant que le tween puisse exister. Effet de bord voulu : la
planche repond desormais aussi a un atterrissage qui ne monte pas, ce qui est
ce que fait une balancoire.

**Keepy est ECRIT sur le pivot, jamais reparente**, et sa position sort de la
MEME multiplication que la planche -- donc sa hauteur suit la bascule par
construction. C'est la regle mesuree du tourniquet (`_apply_spin` : un rider
qui echantillonnait le pivot sur son propre callback etait **une frame
entiere** en retard, 12,0 deg au pic, et `process_priority` n'y changeait
rien). Verifie ici a **0,000000 u** d'ecart sur 40 frames.

### La sonde : `SeesawProbe`, 48 checks, 0 echec, GATEE

Gatee et pas rapportee parce que **tout mode de panne des deux moities est
SILENCIEUX** : un terme d'union qui ne tire jamais, un `clamp_to` qui repond
un point hors region, un registre vide, un `MultiMesh` laisse au
`TRANSFORM_2D` par defaut (qui jette toute transform et dessine le batch a
l'origine), un declencheur accroche sous un `return` anticipe, un demontage
qui retombe dans le rayon et remonte pour toujours. Aucun ne leve, aucun ne
casse un build.

**ROUGE AVANT VERT, trois cassures deliberees, chacune produisant le FAIL
attendu** puis revertee :

| cassure | resultat |
|---|---|
| terme du lobe retire de `contains()` | **13 FAIL** (pointe, azimuts, aire, clamp, 7 props inatteignables) |
| `_apply_tilt` n'ecrit plus le rider | **1 FAIL** -- *puis 1 autre apres correction, voir ci-dessous* |
| `_repump_seesaw` en no-op | **2 FAIL** (tween pas frais, ancien pas tue) |

⚠️ **DEUX DEFAUTS DANS MA PROPRE SONDE, trouves par cette passe et publies
plutot que lisses :**

1. **L'assertion de suivi etait VIDE.** Elle comparait Keepy a
   `pivot.to_global(pivot.to_local(SA POSITION))` -- l'identite, donc zero
   quel que soit son retard. Elle est restee VERTE avec l'ecriture du rider
   retiree ; **seul le BLIND CHECK l'a attrapee**, ce qui est toute sa raison
   d'etre. Re-visee sur le SIEGE FIXE, elle mesure desormais **0,347 u** de
   derive quand on retire l'ecriture.
2. **L'assertion de re-pompe etait VIDE aussi** (`absf(x - before) >= 0.0`,
   trivialement vraie). Remplacee par l'identite du TWEEN : l'ancien tue, un
   objet different en place.

⚠️ **ET UN TROISIEME, celui-la sur l'ETAT GLOBAL : la diagonale traverse un
PORTAIL.** `PHASE CROSSING` marche `(-35,-35) -> (35,35)`, qui passe a 0,8 u du
portail `chased` -- un atterrissage l'ouvre, et `_on_tapped_ground` retourne
alors a sa toute premiere garde. Les phases suivantes sont parties rouges sur
un build sain, en rapportant un tap qui ne fait rien : **c'est exactement ce a
quoi ressemble un tap sous un dialogue ouvert**. Ferme explicitement en fin de
phase, et **asserte ferme**, plutot que contourne par un detour -- marcher le
VRAI pire couple est tout l'objet de la phase.

⚠️ **`PHASE CROSSING` doit tourner AVANT que quoi que ce soit ne touche
Keepy**, et le premier jet ne le faisait pas : les phases de ride le laissent
sur une planche, `hop_to()` est refuse dans cet etat, et la diagonale est
sortie a **1 hop / 83,333 s** -- la signature exacte d'un `hop_to` refuse. Le
`settle` attend desormais l'inactivite COMPLETE et non le seul `is_hopping()`.

### Decor du lobe : 6 entrees, et la doctrine degressive tient

Un premier jet en posait **16**, soit **7,07 props/100 u2** -- au-dessus des
bandes deja livrees (r0-10 = 12,10 ; r10-20 = 4,99 ; r20-27 = 3,39 ;
r27-35 = **2,95**) et donc **cassant la doctrine degressive** sur la bande la
plus exterieure du plateau. Recalcule : **6 entrees = 2,65/100 u2**, strictement
sous 2,95. Leger, discret, et conforme -- ce que « rester leger » voulait dire.

2 rochers, 1 buisson, 3 fleurs, en grappes, ecart minimal **1,188 u**, toutes
dans le sol NEUF (z > 35,4) et a **5,185 u** au moins du centre de la
balancoire (keep-out 3,60). **Batchees en MultiMesh comme tout le scatter, donc
zero noeud de dessin.**

### Cout

| | AVANT | APRES |
|---|---|---|
| noeuds de dessin hors portails | **124 / 124 / 124** | **127 / 127 / 127** |
| noeuds de dessin, total | 130 | **133** |
| construction | 49,61-57,78 ms | 50,48-59,49 ms |
| FPS simule, moyen | 14,9-15,8 | 14,4-15,0 |
| marge sous le plafond de 260 | 136 | **133** |
| entrees de layout | 208 | **215** |

Les deux cotes mesures dans UNE session sur machine au repos, trois runs
chacun. **Toutes les plages se chevauchent** : la revendication est
« aucun cout n'est detectable », jamais « c'est plus rapide ». Ligne
complete : `docs/HUB_PERF_BASELINE.md`.

**+3, itemises** : le fulcrum, la planche, et **UN** `MultiMeshInstance3D` pour
les deux poignees. Le decor du lobe coute **zero** noeud.

⚠️ **Le compteur de la sonde compte AUSSI les `MultiMeshInstance3D`, et pas
seulement les `MeshInstance3D`** : les poignees sont un batch **NICHE** sous le
pivot, et un compteur qui ne cherchait que des noeuds de mesh simples le
raterait -- exactement le sous-comptage que `HubPerfBaseline` s'est fait
trouver au lot tourniquet.

### Reste ouvert -- jugement device, seul juge

1. **Est-ce qu'une planche qui bascule de 15 deg deux fois et demie sur 2,4 s
   se lit comme une balancoire qui repond a un poids**, ou comme un prop qui
   glitche ? C'est tout l'objet du lot et aucune sonde ne le dit.
2. **Est-ce qu'un lobe derriere le spawn se lit comme un endroit ou aller ?**
   Il est structurellement invisible tant qu'on ne l'a pas depasse (la camera
   ne lacete jamais). Mesure, assume, jamais juge a l'oeil.
3. **Keepy traverse la planche** comme il traverse tout le decor du plateau --
   rien ici ne bloque une approche, et la balancoire n'allait pas devenir le
   premier prop a le faire.
4. **Aucun son, aucune particule, aucun second riders** : hors perimetre.
5. **Rien ici n'est un rendu device** : llvmpipe sous xvfb via le backend
   `opengl3` de BUREAU, contre WebGL2 sous Safari.

### Deploiement staging du lobe nord + balancoire (palier 1, automatique)

`staging` **`07f094f`** (merge `--no-ff`, arbre **byte-identique** a la branche
feature : meme hash d'arbre `d37a5b35` des deux cotes ET `git diff` vide,
verifie AVANT le push). CI run **#291** (id 33172072883) **verte** --
`Import project resources` 12:41:20 -> 12:43:16, **`Export Web build`
12:43:16 -> 12:43:20**, `Deploy to Vercel [STAGING -- staging]` **succes**,
`[PRODUCTION -- main]` correctement **skipped**. **`main` NON touche**
(`origin/main` toujours `b00fa1d`, verifie apres le push) : palier 2, gate
Mathieu apres validation device.

**Verifie SUR LE SERVICE, pas dans le log CI, sur DEUX marqueurs independants
et aux DEUX bouts -- les QUATRE lectures en `x-vercel-cache: MISS` / `age: 0`**,
les valeurs "avant" ayant ete relevees AVANT le merge :

| marqueur | avant | apres (ce lot, run #291) |
|---|---|---|
| `CACHE_VERSION` | `1787910913` | **`1787920999` = 12:43:19 UTC** |
| `index.pck` servi | **5 898 448** | **5 906 080** |
| `index.wasm` servi | 35 376 909 | **35 376 909** *(inchange, attendu)* |

L'epoch d'apres tombe **a l'interieur de la fenetre `Export Web build`**
(12:43:16 -> 12:43:20) : l'alias sert bien ce build.

⚠️ **`index.pck` prend une valeur de plus pour le meme contenu** : 5 906 064 a
l'export local propre contre 5 906 080 servi, **16 octets d'ecart**. Enieme
illustration de l'instabilite deja consignee -- marqueur "nouveau build",
**jamais** preuve d'identite. `index.wasm` (**35 376 909**, md5
`af4a8fc2925d992348eb30deeeb54360`, `index.js` md5
`4e08904b1b7107858246af44b602067b`) est identique des deux cotes et c'est lui
la preuve d'identite, coherent avec un lot qui ne touche que
`scripts/hub/*.gd`, `scripts/dev/*` et un `.tres`.

### Merge en production (28 aout 2026, autorisation explicite de Mathieu)

`staging` (`8d79d95`) -> `main`, commit de merge **`b10b216`**, `--no-ff`,
apres validation device confirmee ("bascule lue comme naturelle, lobe/
balancoire acceptes tels quels, traversee du decor jugee coherente avec le
reste du plateau").

⚠️ **`origin/main` avait DIVERGE de la ref attendue au moment de demarrer ce
lot, et ce n'etait ni une session concurrente ni du travail perdu.** Verifie
AVANT tout merge, jamais suppose : `merge-base(origin/main, origin/staging)
= b00fa1d` exactement, donc `b00fa1d` est bien le point de depart reel et
commun. `origin/main` avait avance de 2 commits au-dela -- **`8e8b9bd`
"ennemis"** (10 `.glb` bruts sous `assets_source/openworld/`, **0 insertion
/ 0 suppression de texte**, poussee par Mathieu depuis VS Code/GitHub le
28 aout 15:27 CEST) et **`d7a0b81`**, le merge automatique GitHub qui
reconcilie ce commit avec `b00fa1d` sans rien y ajouter. **Zero
chevauchement de fichiers** avec ce que `staging` avait change (diff croise
vide). C'est exactement l'exception permanente deja actee dans ce fichier :
Mathieu depose des `.glb` Meshy bruts directement sur `main` depuis
l'interface web/VS Code, bornee a `assets_source/`, sans jamais toucher de
code, de scene ni de configuration -- meme motif que `51aa01d`+`3f04b89`
deja consigne. **Signale plutot que suppose : divergence detectee, session
arretee pour rapport, confirmee benigne par Mathieu, puis merge relance.**

**Verifie AVANT le merge, tree par tree** : `origin/main` = `d7a0b81` et
`origin/staging` = `8d79d95` (SHA du brief confirmes, re-fetch fait en tete
de session ET juste avant de relancer -- aucun troisieme etat n'est apparu
entre les deux checks). Local `main` mis a jour en `--ff-only` vers
`origin/main` (aucune divergence locale) avant le merge. **Le merge lui-meme
est purement additif sur les deux flancs** : `git diff HEAD origin/staging`
= exactement les 10 `.glb` "ennemis" (0 ligne de texte) ; `git diff HEAD
origin/main` = exactement les 12 fichiers du lot hub (`CLAUDE.md`,
`docs/HUB_PERF_BASELINE.md`, `resources/hub/hub_layout.tres`,
`scripts/dev/LakeZoneProbe.gd`, `scripts/dev/SeesawProbe.{gd,tscn}`
(nouveaux), `scripts/dev/TurnstileProbe.gd`, `scripts/dev/WaterTintProbe.gd`,
`scripts/hub/HubBuilder.gd`, `scripts/hub/HubRegion.gd`,
`scripts/hub/HubWorld.gd`, `scripts/hub/KeepyHopper.gd`). Aucun conflit,
merge `ort` automatique.

CI **run #294** (id `33176960418`) **verte** (13:46:41 -> 13:51:48 UTC) --
`Checkout` 13:46:46 -> 13:47:30 (44 s, malgre les ~150 Mo de `.glb` "ennemis"
ajoutes a l'historique), `Import project resources` 13:47:58 -> 13:51:13,
`Export Web build` **13:51:13 -> 13:51:18**, `Deploy to Vercel
[PRODUCTION -- main]` **succes** 13:51:36 -> 13:51:44, `[STAGING --
staging]` correctement **skipped** (push sur `main`).

**Verifie SUR LE SERVICE, pas seulement dans le log CI, sur DEUX marqueurs
independants et aux DEUX bouts** -- les DEUX lectures en `x-vercel-cache:
MISS` / `age: 0`, la valeur "avant" relevee AVANT le merge :

| marqueur | avant (run #293, `d7a0b81`) | apres (ce lot, run #294) |
|---|---|---|
| `CACHE_VERSION` | `1787924004` = **13:33:24 UTC** | **`1787925077` = 13:51:17 UTC** |
| `index.pck` servi | -- (non relu) | **5 909 024** |
| `index.wasm` servi | -- (non relu) | **35 376 909** |

L'epoch d'apres tombe **exactement dans la fenetre `Export Web build`**
(13:51:13 -> 13:51:18) : l'alias sert bien ce build. `index.wasm`
**35 376 909 octets** -- identique au fingerprint permanent deja consigne
pour tout lot qui ne touche pas le code moteur, coherent : ce merge n'ajoute
que des `.gd`/`.tres`/`.md` du lot hub, plus des `.glb` bruts non installes
(exclus du build par `exclude_filter`, jamais referencs par une scene).
`index.pck` **5 909 024** -- marqueur "nouveau build servi", **jamais**
preuve d'identite, l'instabilite entre exports etant deja documentee.

**Aucune sonde re-derouleee dans cette session** : le tree pousse sur `main`
est byte-identique a celui deja valide sur `staging` par la session
precedente (`AssetContractAudit`, `DeathModelAudit`, `ChargerShapeProbe`,
`ProbeTimeoutAudit`, `LakeZoneProbe`, `SeesawProbe` tous verts au lot
staging) -- meme principe deja applique aux merges tourniquet et diving
board precedents.

**Le lobe nord et la balancoire (seesaw) sont desormais EN PRODUCTION** sur
`keepy-ten.vercel.app`.

