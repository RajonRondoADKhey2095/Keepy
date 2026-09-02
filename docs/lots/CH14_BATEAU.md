# Bateau — le ruisseau devient ridable

> Extrait de `CLAUDE.md` par le LOT H (2 septembre 2026), **verbatim** : aucune ligne réécrite, résumée ni supprimée.
> 2 section(s), 494 lignes d'origine.
> Doctrine permanente : voir `CLAUDE.md`. Index des chantiers : `docs/lots/INDEX.md`.

## HUB : LE RUISSEAU DEVIENT RIDABLE — une coque de noix, un seul tap, et AUCUN portail depuis le bateau (26 aout 2026)

Branche `claude/ride-1-ridable-stream-8uswi8`. **Partie de `origin/staging`
(`b102e0c`) et non de `main`** : la recon du lot G
(`scripts/dev/StreamGeometryProbe.*`) que ce lot doit lire n'existe QUE sur
`staging`, donc partir de `main` (`ab62ba6`, verifie conforme au brief)
aurait rendu la tache 5 litteralement impossible. Regle n°1 verifiee AU
DEBUT : `origin/staging` est la ref la plus recente du depot (21:04:39) et
**aucune branche ne porte ce brief** — verifie en comparant les ARBRES
(`git rev-parse <ref>^{tree}`) et pas seulement les noms, la lecon du
quatrieme incident ou deux branches differaient d'un suffixe.

**AUCUNE des trois constantes protegees n'est touchee**, verifie par
`git diff` : `HubTapInput.PLATEAU_HALF_EXTENT` reste **35.0**,
`KeepyHopper.HOP_DISTANCE` **1.5**, `HOP_DURATION` **0.28**, et
`HubCamera.OFFSET`/`FOLLOW_LAMBDA`/`fov`/rotation sont intouches —
`HubCamera.gd` n'est pas dans le diff du tout.

### R1 -- les 12 points sont lisibles sans mesh, MAIS ce n'est pas eux qu'on ride

Deja etabli par la recon et **re-verifie ici plutot que recopie** : l'entree
`&"stream"` porte ses points en clair dans un `PackedVector3Array`, donc un
`load()` suffit. Mais `HubBuilder` ne dessine PAS ces 12 points — il les
passe par `_centripetal()` a 8 echantillons par span, ce qui donne **89
echantillons**, et la spline BOMBE hors des cordes de la polyligne.

**`HubStreamRoute` recoit donc le spine que `HubBuilder` a REELLEMENT
construit** (`stream_spine()`), il ne le re-derive jamais. Une seconde
transcription de la courbe serait un fixture libre de diverger de celle a
l'ecran — le piege `SubstituteModel.tscn` exactement, et celui contre
lequel `StreamGeometryProbe` se controle deja lui-meme.

### La longueur de coque est un CALCUL, pas un gout

Une coque rigide de longueur L et de largeur B, centree sur le spine et
tournee le long de la tangente, a son pire point a un **COIN EXTERIEUR** :
sur un cercle de rayon R il est a `sqrt((R + B/2)^2 + (L/2)^2)` du centre,
donc il quitte le spine de cela moins R. La coque tient tant que

```
sqrt((R + B/2)^2 + (L/2)^2) - R  <=  demi-largeur du ruban
```

Mesure sur le spine CONSTRUIT (jamais sur la polyligne, qui plie moins) :
R = **1.4058** au sample **48**, demi-largeur **0.6000**.

| coque | excursion de coin | marge |
|---|---|---|
| **0.78 x 0.86 (livre)** | **0.4710** | **0.1290** |
| 0.80 x 1.00 (le plafond du brief) | 0.5415 | 0.0585 |

Aucun des deux axes n'est pousse a sa limite : le plafond ne laisserait que
0.0585. **La forme de coin est CONSERVATRICE** pour une coque arrondie —
c'est le but, un bord qu'une future coque plus cubique satisferait encore.
Gate par `StreamRideProbe`, pas laisse en commentaire : re-tracer le
ruisseau deplace la marge.

⚠️ **La coque est SYMETRIQUE avant/arriere**, et pas par economie : le ride
est bidirectionnel (son sens vient du tap, jamais du layout), donc une
proue pointerait dans le mauvais sens une fois sur deux. Une forme sans
avant ne peut pas etre a l'envers.

### ⚠️ DEUX DEFAUTS DE RENDU TROUVES SUR CAPTURE, invisibles a la relecture

Aucun n'a produit d'erreur ; les deux ont ete vus sur un rendu offscreen
1080x1920 et corriges avec la mesure a l'appui.

1. **La coque etait DESSINEE DANS LE SOL.** A `BOAT_FLOAT_Y = 0.16` la
   quille tombait a **-0.08**, sous un plan de sol opaque a y = 0 : tout ce
   qui etait sous le liston etait clippe par le plancher et le bateau
   rendait comme un **ANNEAU CREUX** a travers lequel on voyait le lac. La
   geometrie etait juste depuis le debut, simplement dessinee dans le
   plancher.
2. **Puis l'eau passait a travers la coque.** A 0.30 la quille etait a 0.06,
   sous `STREAM_SURFACE_Y = 0.095` : le plan d'eau coupait l'interieur de
   la coque et un eclat de ruisseau se voyait au fond du bateau.

**Livre a 0.34** : quille a **0.10**, soit 5 mm au-dessus de la surface du
ruisseau et 2 cm au-dessus de celle du lac — rien ne traverse, et l'ecart
est bien trop petit pour se lire comme un survol. Les trois relations sont
desormais **gatees** (`keel > 0`, `keel >= STREAM_SURFACE_Y`,
`keel - STREAM_SURFACE_Y < 0.05`).

⚠️ **Troisieme tone ajoute pour la meme raison** : a un seul tone la coque
se lisait comme un TROU dans la berge, parce qu'a ce pitch la camera voit
surtout l'INTERIEUR de la paroi opposee — et elle s'amarre justement sur
l'anneau sombre du lac. Trois tones (coque sombre, interieur clair, liston
plus clair) transforment la meme silhouette en coquille ouverte, pour
**+1 noeud**.

### RIDE_SPEED 8.0 -- le plancher 5.8283 est MESURE, pas choisi

Le ruisseau MEANDRE : **41.2837 u** de spine contre **36.8702 u** de ligne
droite entre les memes extremites (ratio **1.1197**), la ou une chaine de
hops couvre cette droite en **25 hops de 17 frames**. Sous ce plancher, un
rider qui parcourt le chemin le plus long arrive APRES quelqu'un qui a
simplement saute — le bateau serait une facon plus lente de voyager qui a
juste l'air plus jolie.

| | temps |
|---|---|
| chaine de hops (25 hops, quantifie) | **7.0833 s** |
| ride a 8.0 u/s | **5.1605 s** |

`_ready()` **push_error** si `ride_speed` passe sous le plancher, et la
sonde le gate : c'est ce qui empeche un futur reglage de le faire par
accident. `ride_speed` est **exporte** (reglable depuis la scene) et le
plancher est un `const` (lisible par une sonde sans instancier).

### Un seul tap achete tout le voyage

`HubTapInput` demande a la mooring, **en unites MONDE et AVANT toute
resolution de destination**, si le doigt a atterri sur la coque. Rayon
**2.5 u** : la coque fait 0.78 de long et serait une cible que personne ne
peut toucher a cette distance de camera. **Exactement UN des deux signaux
part par tap** — emettre les deux et laisser l'ecouteur choisir rendrait
chaque tap ambigu en aval.

Pendant un ride cette question repond **false**, donc le meme tap retombe
sur le chemin sol — et c'est ca qui en fait un **eject**. Un tap, un
signal, dans les deux cas.

⚠️ **DEFAUT REEL TROUVE PAR LA SONDE, et il etait vert par CHANCE.**
`_try_board` effacait l'intention de monter a bord **au PREMIER
atterrissage**, qu'on soit arrive ou non : une marche de plus d'un hop
finissait donc avec Keepy debout a cote de la coque sans jamais y entrer.
La sonde le validait quand meme — jusqu'a ce qu'un tap de controle ajoute
AVANT le tap bateau repousse la marche d'un hop. **Le vert n'avait jamais
tenu qu'a ce que le premier atterrissage tombe dans le rayon.** L'intention
survit desormais a un atterrissage de passage, et n'est lachee que sur un
embarquement reussi, un autre tap, ou `became_idle`.

### ⚠️ AUCUN PORTAIL N'EST DECLENCHE DEPUIS LE BATEAU

C'est la pire chose que cette feature puisse faire, et le ruisseau arque
justement devant la rangee de portails (9.25 u du plus proche). Un ride
n'emet AUCUN `hop_landed`, donc la detection est muette gratuitement — et
« gratuitement » est exactement le genre de garantie qui cesse
silencieusement d'etre vraie, donc `_on_hop_landed` refuse en plus
explicitement tant que `is_riding()`.

**Prouve plutot que constate** : la sonde appelle `_on_hop_landed`
directement avec le **CENTRE d'un portail** pendant le ride (0 declenche),
tape sur un portail pendant le ride (0 declenche, et le ride se termine —
c'etait un eject), puis rejoue le meme appel une fois a terre : **1
declenche**. Le compteur bouge, donc les zeros sont des refus reels et pas
un compteur mort.

⚠️ **Et c'etait justement un compteur mort au premier run.** Le piege deja
consigne dans ce fichier — **un lambda GDScript capture une LOCALE PAR
VALEUR** — a repris la sonde en flagrant delit : les trois « 0 declenche »
passaient pour la mauvaise raison. Corrige en membre de classe.

### Sortie : un bond plus haut, sur une berge verifiee

`EJECT_HOP_HEIGHT = 1.05` contre `HOP_HEIGHT = 0.6` — quitter un bateau est
un evenement different de traverser le plateau, et l'arc est le seul canal
qui le dit sans un son ni un mesh de plus. Le point d'atterrissage est
verifie contre **166 empreintes au sol** tirees du layout ; s'il est
occupe, la recherche marche **LE LONG** de la berge (et pas plus loin sur
le cote : le cote est justement ou sont les props que la trace a ete routee
pour degager).

**Mesure sur 42 points d'eject** (21 abscisses x 2 cotes) : **0 atterrit
encore sur l'eau**, **0 tombe dans une empreinte**, pire degagement
**0.4785 u**. Arriver au bout du ruisseau debarque tout seul.

⚠️ **Les empreintes sont AU SOL, pas les silhouettes** : un tronc fait 0.24
quand son houppier fait 0.95 mais flotte a deux metres. Un tronc dans l'eau
est un bug, un houppier au-dessus est ce que fait un vrai arbre au bord
d'un ruisseau — la meme distinction que le routage du lot G.

### La mooring : la regle des 12 u NE SUFFIT PAS, et c'est mesure

La regle du brief est implementee telle quelle : quand Keepy est a plus de
**12 u de TOUTE extremite**, la coque se repositionne sans animation a
l'extremite la plus proche. **Elle ne garantit pas a elle seule que le
deplacement soit hors champ**, et ce n'est pas une supposition : la bascule
n'a lieu que sur la mediatrice des deux extremites, ou les DEUX sont a
~18 u de Keepy — 18 u de COTE est loin hors d'un fov horizontal de 45°,
mais 18 u DROIT DEVANT est dedans, la camera regardant vers -Z.

La regle de distance est donc **ET-ee avec un test de frustum** sur la
position actuelle de la coque ET sur celle visee.

⚠️ **Le garde est PORTEUR, mesure sur 90 frames consecutives avec la vraie
camera** : au point de bascule cote head, la coque amarree au loin est
**dans le frustum**, et le deplacement est **RETENU**. Sans le garde le
joueur aurait regarde un bateau se teleporter. Le report distingue les deux
raisons de ne pas bouger (retenu par le garde / deja au bon endroit) pour
qu'un futur lecteur ne les confonde pas.

Le cout de differer est seulement que la coque reste brievement au mauvais
bout — l'etat dans lequel elle etait deja — et la condition est re-testee
chaque frame.

### Cout : +3 noeuds de dessin

| | avant (lot stream) | ce lot |
|---|---|---|
| noeuds de dessin hors portails | **75** | **78** |
| noeuds de dessin, total | **81** | **84** |
| marge sous le plafond de 260 | 185 | **182** |
| construction | 46.2–49.7 ms | **38.3–40.9 ms** |

Les 3 noeuds sont la coque, la coquille interieure et le liston. **Non
batche** : il y en a UN, il n'y a rien a repeter, et il est deplace chaque
frame d'un ride. Ligne complete : `docs/HUB_PERF_BASELINE.md`.

### Validation

Editeur + templates Godot 4.3-stable installes dans ce sandbox (releases
GitHub officielles, **taille du `.tpz` verifiee contre le `Content-Length`**
— 1 073 228 327 octets, aucune troncature silencieuse). Import headless
**exit 0**, **24 `.scn`** (import complet verifie, pas suppose). Boot
headless de `HubWorld.tscn` **exit 0, 0 erreur, 0 `push_warning`** — la
confirmation A L'EXECUTION que les 169 entrees restent atteignables. Export
Web release **exit 0**.

`index.wasm` **35 376 909 octets** / md5
**`af4a8fc2925d992348eb30deeeb54360`**, `index.js` md5
**`4e08904b1b7107858246af44b602067b`** — identiques au fingerprint deja
consigne pour tout lot qui ne touche pas le code moteur. `index.pck`
**5 853 648** (export unique et propre — a lire avec la mise en garde
permanente sur son instabilite, jamais offert comme preuve). **Piege
payload tenu** : sur **223** lignes `Storing File`, **0** pour
`assets_source`, `scripts/dev`, `docs`, `web`, `build` ou `firebase.json`,
et `BoatMooring`/`HubStreamRoute` sont bien packes.

**`StreamRideProbe` (nouvelle) : 37 checks, 0 echec, exit 0.** Diffees
contre `origin/staging` en worktree separe (imports verifies complets des
deux cotes) : `AssetContractAudit` (12/12 visuels, **0/10 colliders
deplaces**), `DeathModelAudit`, `ChargerShapeProbe` — **BYTE-IDENTIQUES sur
les DEUX flux**. `ProbeTimeoutAudit` differe **d'exactement deux lignes** :
la ligne de la nouvelle sonde et son total (**39 -> 40 sondes scenes**,
toutes armees).

⚠️ **`StreamRideProbe` doit tourner sous `xvfb`, PAS `--headless`.** Sa
phase de tap projette la coque en point d'ecran et appelle `_handle_point`
dessus ; sous le driver DUMMY le rect du conteneur est 0x0 et la fonction
sort avant de projeter quoi que ce soit — un vert qui ne veut rien dire.
Meme famille que le piege deja paye sur cet ecran au lot `mouse_filter`.

### Deploiement staging (palier 1, automatique)

`staging` **`4ff3611`** (merge `--no-ff`, arbre **byte-identique** a la
branche feature : meme hash d'arbre `25ece069` des deux cotes, verifie AVANT
le push). CI run **#237** (id 32903307934) **verte** — `Deploy to Vercel
[STAGING -- staging]` succes a 21:58:04, `[PRODUCTION -- main]` correctement
**skipped**. **`main` NON touche** (`origin/main` toujours `ab62ba6`, verifie
apres le push) : palier 2, gate Mathieu apres validation device.

**Verifie SUR LE SERVICE, pas dans le log CI, sur DEUX marqueurs
independants et DANS LES DEUX SENS** :

| marqueur | avant | apres |
|---|---|---|
| `CACHE_VERSION` | `1787692117` = **21:08:37** | **`1787695057` = 21:57:37** *(dans l'etape `Export Web build` du run #237, 21:57:32 -> 21:57:38)* |
| `index.pck` servi | **5 838 064** | **5 853 728** |
| `index.wasm` servi | 35 376 909 | 35 376 909 *(inchange, attendu)* |

Les valeurs AVANT ont ete lues **avant le merge**, et les quatre lectures
utiles portent `x-vercel-cache: MISS` avec `age: 0` — la bascule est donc
prouvee dans les deux sens et pas deduite du log. Le `.pck` servi est 80
octets au-dessus de l'export local propre (5 853 648) : l'instabilite deja
documentee, pas un autre build.

⚠️ **Le piege HIT/age s'est reproduit TROIS fois et a ete refuse les trois
fois** (age 50, 80 puis 244). Detail utile : c'est ma PROPRE lecture de
21:52:14 qui avait rempli le cache de bord, et un parametre de requete
different n'a pas suffi a le contourner. **Un HIT avec un `age` non nul
n'est pas une mesure de fraicheur**, quel que soit le cache-bust.

⚠️ **NUANCE HONNETE sur le piege « API Actions perimee » : ici elle ne
l'etait PAS.** Un appel intermediaire montrait le job fige sur « Checkout /
21:52:38 », ce qui ressemble exactement au piege deja consigne — mais le
checkout de ce run a reellement dure **2 min 12 s** (21:52:38 -> 21:54:50),
et l'import **2 min 21 s**. La reponse etait juste. **Ne pas conclure a une
API perimee sans regarder si l'etape en cours peut simplement etre lente** ;
c'est le meme reflexe que la regle `completed_at`, dans l'autre sens.

### Reste ouvert — jugement device, seul juge

1. **La coque est BEAUCOUP plus petite que Keepy a l'ecran** (0.78 x 0.86
   contre un ecureuil qui remplit ~124 px de haut), donc pendant un ride
   elle est en grande partie cachee sous lui. **Ce n'est pas reglable** :
   la longueur est bornee par le rayon de courbure du ruisseau, pas par un
   gout. C'est le risque principal du lot — est-ce qu'on lit « Keepy dans
   une barque » ou « Keepy qui glisse sur l'eau » ?
2. **Est-ce que la coquille de noix se lit comme une barque** a la taille
   reelle sur un telephone ? Les trois tones et les hauteurs sont mesures ;
   la lecture ne l'est pas.
3. **Le rayon de tap de 2.5 u est genereux** — mesure comme necessaire
   (la coque est minuscule a l'ecran), mais il couvre aussi de l'eau et de
   la berge autour d'elle. Un joueur qui voulait marcher pres du bateau
   monte dedans.
4. **5.16 s de ride se sentent-ils comme un raccourci** ou comme une
   attente ? Le chiffre bat la chaine de hops de 1.9 s ; le ressenti n'est
   pas mesure.
5. **La mooring peut rester differee longtemps** si le joueur regarde en
   permanence le long du ruisseau. Argumente comme le bon compromis (la
   coque reste au mauvais bout, l'etat ou elle etait deja), jamais observe
   sur device.


## RIDE-1 EN PRODUCTION, ET RECON ZONE LAC AU-DELA DE 35 (26 aout 2026)

### Merge RIDE-1 -> main (autorisation explicite de Mathieu, validation
### device faite)

`staging` (`18282fa`) -> `main`, commit de merge **`ae13b99`**, `--no-ff`,
apres resolution d'une incoherence signalee dans le rapport RIDE-1 avant
tout merge.

⚠️ **L'incoherence des trois tailles de `index.pck` (5 853 648 en BUILD,
5 853 728 en DEPLOY) EST EXPLIQUEE, pas ignoree.** Verifie avant de merger,
pas suppose : `git diff` entre les commits feature de RIDE-1 ne touche QUE
`scripts/hub/*`, `resources/hub/hub_layout.tres`, `scenes/HubWorld.tscn` et
des fichiers dev/doc -- **ni `project.godot` ni `export_presets.cfg`**. C'est
exactement la classe de lot qui, partout ailleurs dans ce fichier, produit un
`index.wasm`/`index.js` identiques au bit pres mais un `index.pck` instable
d'un export a l'autre (variance de la passe de compression VRAM sur les
textures des AUTRES assets, deja documentee des le 10 aout). `index.wasm`
**35 376 909** / md5 **`af4a8fc2925d992348eb30deeeb54360`**, `index.js` md5
**`4e08904b1b7107858246af44b602067b`** -- **identiques dans le build RIDE-1
local ET sur le service apres deploiement**, ce qui est la preuve d'identite
qui compte. Un **quatrieme** export (celui de ce lot, verification GDScript
de l'Etape 1) donne un **quatrieme** chiffre de pck (5 853 776), avec le meme
wasm/js -- confirmation supplementaire que l'instabilite est bien celle deja
connue.

**CI run #239** verte (22:28:05 -> 22:31:26 UTC). **Verifie SUR LE SERVICE,
deux marqueurs independants, MISS/age 0 des deux cotes** :
`CACHE_VERSION` du `index.service.worker.js` servi = `1787697059` =
**22:30:59 UTC**, a l'interieur de la fenetre du run ; `index.pck` servi =
5 853 776 (un CINQUIEME chiffre, `index.html` `fileSizes`) ; `index.wasm`
servi = 35 376 909, inchange. `x-vercel-cache: MISS`, `age: 0` sur
`index.html` et `index.service.worker.js`.

### Etape 1 -- recon zone lac au-dela de 35, mesure pure, RIEN implemente

`scripts/hub/*.gd`, `resources/hub/hub_layout.tres` : **intouches**. Seul
ajout : `scripts/dev/LakeZoneReconProbe.{gd,tscn}`, mesure pure sur la scene
livree (KeepyHopper/HubCamera reels), aucune assertion, aucun gate.

**Q1 -- CLAMP** : `PLATEAU_HALF_EXTENT` est un SCALAIRE UNIQUE, deux sites de
lecture (`HubTapInput._handle_point`, clamp de la destination ;
`HubBuilder._build()`, avertissement de bornes -- qui lit deja **tous** les
points de controle d'un `stream`, pas seulement sa position). Camera et
generation de decor n'en dependent PAS (`grep` : zero occurrence hors ces
deux fichiers). Remplacer par une FORME (carre + peninsule) toucherait ces
memes deux sites, avec une geometrie de clamp plus riche qu'un simple
`clampf` par axe (test d'appartenance carre-ou-rectangle-peninsule, projection
sur le bord le plus proche en cas d'exterieur) -- de l'ordre de quelques
dizaines de lignes, pas une reecriture.

**Q2 -- SEUIL 22s** : reproduit sur le VRAI `KeepyHopper` (`--fixed-fps 60`,
`hop_to()` n'a aucune notion du clamp). Diagonale a 35 : **66 hops / 1122
frames / 18,700s** (reproduit le docblock a la frame pres). Carre : **H=40
tient (76 hops, 21,533s), H=41 depasse (78 hops, 22,100s)** -- dernier
half-extent carre sous 22s = **40**. Peninsule azimut 282° (direction du lac
du lot F), coin oppose (35,35) -> pointe, **AUCUNE des trois longueurs ne
depasse** : L=5 -> 16,150s, L=10 -> 17,283s, L=15 -> 18,133s (57/61/64 hops).
Une peninsule etroite coute bien moins cher qu'un carre elargi sur le pire
trajet.

**Q3 -- VISIBILITE DES LANDMARKS** : `fog_mode` n'est POSE NULLE PART dans
`HubWorld.tscn` -> defaut EXPONENTIEL (0), jamais Depth -- **le rappel sur le
bug moteur Depth-fog (#97875/#92019) ne s'applique donc pas a cette scene**,
verifie et pas suppose. Occlusion `1-exp(-d*0,016)` reproduit EXACTEMENT les
trois figures deja publiees (30,6% / 39,3% / 47,4% a r=12,6/21,4/30,5, azimut
0, "vu depuis le centre"). Extrapole a r=40 -> **54,7%** (45,3% de couleur
propre), r=45 -> **58,1%** (41,9%) -- degradation continue, jamais "efface".

⚠️ **Ma premiere formule de HAUTEUR A L'ECRAN (H*px_per_unit sur la distance
euclidienne) etait FAUSSE, et la mesure REELLE l'a prouve.** Elle predisait
spire=222,6px a r=40 (1080x1920) ; le VRAI `HubCamera.unproject_position()`
sur la scene livree donne **300,2px**. Cause : la camera est tiltee -34° et
la hauteur du landmark (8,45u) n'est pas petite devant la distance (22,8-
54,4u), donc le HAUT du landmark est reellement plus proche de la camera que
sa BASE -- l'approximation lineaire H/D casse. **Chiffres retenus =
UNIQUEMENT ceux mesures sur `HubCamera` reelle** (Keepy et camera repositionnes
exactement a l'origine avant mesure, `SubViewportContainer.stretch` desactive
le temps de la mesure) :

| r | 1080x1920 spire | 1170x2532 spire |
|---|---|---|
| 12,6 (existant) | 618px | 670px |
| 21,4 (existant) | 461px | 500px |
| 30,5 (existant) | 365px | 396px |
| **40,0** | **300px** | **325px** |
| **45,0** | **275px** | **297px** |

Degradation continue et lisible en pixels (aucun effondrement brutal), mais
**PAS de conclusion "lisible" ou "illisible" tiree ici** -- seule la mesure
est rapportee.

⚠️ **Capture offscreen REELLE produite** (`xvfb-run --rendering-driver
opengl3`, un vrai `_make_landmark_spire()` construit par `HubBuilder`, pas un
stand-in), a r=40 : la silhouette du spire reste distinctement identifiable a
l'oeil contre le ciel/fog, plus attenuee que le spire existant a r=12,6 dans
la meme image -- confirme visuellement la degradation mesuree.

⚠️ **CAVEAT NON RESOLU, signale plutot que cache** : un ECHANTILLON DE PIXEL
REEL (pas une formule) sur un spire jetable a r=40, **azimut 20°** (hors axe,
pas azimut 0) donne une occlusion de fog mesuree a **~35%**, contre 54,7%
predit par la formule azimut-0/distance-euclidienne extrapolee a ce meme
rayon. La formule azimut-0 reste la bonne convention pour "vu en approchant
le landmark" (c'est celle deja etablie par les lots B/C/D), mais elle
SURESTIME l'occlusion hors axe -- donc les 54,7%/58,1% ci-dessus sont un
MAJORANT prudent (pessimiste sur la lisibilite), pas une prediction exacte
pour toute position d'approche. Cause exacte non investiguee (disproportionne
pour cette recon) -- a re-ouvrir si un futur lot pose un landmark hors axe et
a besoin d'un chiffre precis plutot qu'une borne.

**Q4 -- SURFACE NAVIGABLE** : lac existant (`hub_layout.tres`, scale=1,0) =
eau r=8,0 -> **201,06 u² de surface**, traversee diametrale en bateau a
8,0u/s = **2,000s**. Largement assez de PLACE pour un trace libre dans
l'absolu -- mais **`HubStreamRoute` est structurellement 1D** (arc-length
sur UNE courbe fixe, `project()`/`point_at()` n'ont aucune notion de
position 2D libre) : la contrainte n'est pas la taille du lac, c'est que rien
dans l'architecture actuelle ne sait representer un mouvement 2D libre.

**Q5 -- REUTILISATION DU RAIL** : OUI, mecaniquement. `HubStreamRoute._init(spine:
Array)` accepte N'IMPORTE QUEL tableau de points -- rien ne le lie au
`&"stream"` du layout. `KeepyHopper.board(route, half_width, toward)` est
deja generique sur `HubStreamRoute`. **`_centripetal(points, per_span)` de
`HubBuilder` ne lit AUCUN etat d'instance** (verifie : aucune reference `self`
dans son corps) -- trivialement `static`. Ce qu'il faudrait changer : marquer
`_centripetal` `static` (ou l'exposer publiquement) pour qu'un futur input de
drag puisse construire une route a chaud SANS dupliquer l'algorithme -- la
duplication serait exactement le piege `SubstituteModel.tscn` deja paye une
fois sur cet ecran. Le mouvement resterait 1D le long de la courbe dessinee
(pas un pilotage libre continu), coherent avec Q4.

**Q6 -- PONTONS** : y=0 est suppose PARTOUT dans le hop ordinaire, verifie
dans le code, pas suppose -- `_hop_from`/`_hop_to`/`_target`/le landing final
de `_on_hop_finished()` sont TOUS explicitement aplatis a y=0
(`Vector3(x, 0.0, z)`), et `hop_to(point)` jette le y de `point` a l'entree.
Il n'existe AUCUN parametre de hauteur d'atterrissage dans l'API. Pour un
ponton affleurant a `STREAM_SURFACE_Y=0,095` : la confirmation demandee par
le brief ("aucune modification necessaire") est VRAIE seulement en pratique,
pas par construction -- 0,095u est assez petit (comparer a `HOP_HEIGHT=0,6`,
aux hauteurs de landmark 8+u) pour probablement lire comme negligeable, dans
la meme famille que `RIDE_SEAT_Y=0,14` deja qualifie "NEAR ENOUGH" par son
propre commentaire -- mais ce n'est PAS verifie par un rendu, et un ponton
sensiblement plus haut (un vrai quai souleve) casserait visiblement.

**Q7 -- GESTE DRAG SUR SAFARI iOS** : deja en place -- `touch-action: none`
sur `body` (herite par `#canvas`), `user-scalable=no` en meta viewport,
`overflow: hidden`. Precedent fort : `scripts/input/SwipeDetector.gd`, deploye
et valide sur iPhone, MAIS il ne lit que PRESSE+RELACHE (`InputEventScreenTouch`),
jamais `InputEventScreenDrag` en continu -- **verifie par grep : zero occurrence
de `InputEventScreenDrag` dans tout le depot**, donc un drag CONTINU (necessaire
pour dessiner un trace) n'a jamais ete exerce par ce projet. Manque, si un drag
long/lent devait etre ajoute : aucun `overscroll-behavior` (mitigation standard
du rubber-band iOS, absente de `html_shell.html`) ; aucun listener JS
`touchmove`/`preventDefault` custom -- toute la suppression tactile au-dela du
CSS depend du runtime web compile de Godot, non inspectable depuis ce depot ;
et le geste edge-swipe-back de Safari (UIScreenEdgePanGestureRecognizer,
systeme) n'est pas garanti supprime par `touch-action:none` seul pres du bord
gauche. **Rien modifie.**

### Validation

Editeur + templates Godot 4.3-stable installes dans ce sandbox (releases
GitHub officielles, tailles verifiees contre le `Content-Length` -- 50 276 070
et 1 073 228 327 octets). Import headless **exit 0**, **24 `.scn`**. Export
Web release **exit 0, 0 erreur GDScript**. `index.wasm` **35 376 909**
octets / md5 **`af4a8fc2925d992348eb30deeeb54360`**, `index.js` md5
**`4e08904b1b7107858246af44b602067b`** -- identiques au fingerprint deja
consigne pour tout lot qui ne touche pas le code moteur. **Piege payload
verifie sur le log `savepack`** : **0** ligne `Storing File` pour
`res://scripts/dev` sur 39 lignes au total -- `LakeZoneReconProbe.*` bien
exclu.

`ProbeTimeoutAudit` (**41 sondes scenes**, toutes armees -- la nouvelle
comprise), `AssetContractAudit` (12/12 visuels, 0/10 colliders deplaces),
`DeathModelAudit`, `ChargerShapeProbe` -- toutes exit 0.

### Reste ouvert -- decisions de Mathieu, pas des questions techniques

1. **Extension de zone** : forme (carre H<=40, ou peninsule L jusqu'a 15 sans
   cout de traversee mesurable) ; aucune n'est appliquee ici.
2. **Le caveat fog hors axe** (Q3) -- borne prudente publiee, pas un chiffre
   precis pour toute position.
3. **Le systeme de navigation libre** (Q4/Q5) reste a concevoir si voulu --
   ce lot montre que le RAIL (`HubStreamRoute`/`board()`) est reutilisable
   tel quel pour une route construite a chaud, mais qu'aucun mouvement 2D
   libre n'existe dans l'architecture actuelle.

`main` **touche uniquement par le merge RIDE-1** (Etape 0). Ce lot de recon
merge sur `staging` : palier 1, automatique.

