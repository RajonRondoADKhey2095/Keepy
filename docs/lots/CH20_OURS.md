# Ours — lots A à F, du rig animé au siège de balançoire

> Extrait de `CLAUDE.md` par le LOT H (2 septembre 2026), **verbatim** : aucune ligne réécrite, résumée ni supprimée.
> 5 section(s) extraites, 1084 lignes d'origine, **plus 2 sections écrites par le LOT H** (LOT A et LOT F, trous signalés au LOT G).
> Doctrine permanente : voir `CLAUDE.md`. Index des chantiers : `docs/lots/INDEX.md`.

## LOT A -- L'OURS EST IDENTIFIE PAR RENDU, PAS PAR SES METADONNEES : les deux candidats sont RIGOUREUSEMENT indiscernables sur le papier (1er septembre 2026)

Branche `claude/bear-asset-visual-id-jwx53w`, commit `c9362a9`.
**Identification seule** : aucune integration gameplay, aucun fichier de hub
ni de navigation touche, aucun rendu commite. Trois fichiers au diff, tous
sous `assets_source/openworld/` -- deux suppressions et un renommage.

⚠️ **SECTION ECRITE RETROACTIVEMENT PAR LE LOT H (2 septembre 2026)** : ce lot
existait en code sur `staging` sans avoir jamais eu sa section ici, trou
signale par l'etat des lieux du lot G. Le contenu ci-dessous est reconstitue
depuis le message de commit et le diff reel, pas depuis un souvenir.

### ⚠️ LES METADONNEES NE POUVAIENT PAS TRANCHER -- mesure, pas impression

Deux `.glb` candidats sous `assets_source/openworld/` partageaient **le meme
rig Mixamo (24 joints)**, **les memes noms d'animation** (`Walking`,
`Running`), **la meme chaine de noeuds**, **le meme skin**, **le meme
`extensionsUsed`** et **la meme hauteur de 1,7 unite**. Ils ne differaient
que par le maillage et la texture -- c'est-a-dire par exactement ce qu'aucun
parseur glTF ne resume dans un champ.

**Toute methode d'identification par lecture de JSON etait donc structurellement
condamnee ici**, et c'est le vrai enseignement du lot : ce depot a deja paye
trois fois pour un asset nomme d'apres son fichier plutot que d'apres son
contenu (le rondin JUMP contre le tronc DODGE, le castor qui etait un rat, le
« conifere » qui etait un arbre mort). Cette fois le nom **ET** les metadonnees
etaient muets ensemble.

### Ce qui a tranche : des rendus offscreen, cinq angles, deux poses

Bind pose et `Walking` frame 0, cinq angles chacun, `gl_compatibility` sous
`xvfb` -- jamais `--headless` seul, qui force le driver DUMMY et ne rend aucun
pixel. Le verdict est visuel et sans ambiguite :

| | `Meshy_AI_Ourson.glb` -- **RETENU** | `Meshy_AI_Meshy_Merged_Animations.glb` -- **SUPPRIME** |
|---|---|---|
| sujet | **ourson brun** | **BLAIREAU**, pas un ours du tout |
| tete | ronde, petites oreilles arrondies hautes et ecartees | museau blanc, **deux bandes noires du nez aux oreilles** |
| corps | chemise a carreaux, ceinture a outils | corps gris, pattes sombres, gilet rapiece |
| accessoire | casquette jaune a badge tete-d'ours | -- |
| bbox glTF | demi-largeur X **0,5476**, Z **0,5007** | plus mince |
| geometrie | **5 846 triangles / 7 671 sommets** | -- |

Renomme en **`assets_source/openworld/perso/keepy_bear_walker.glb`** --
nomme d'apres ce qu'il EST, jamais d'apres son identifiant Meshy.

⚠️ **LES DEUX COPIES DU BLAIREAU ETAIENT BYTE-IDENTIQUES** (md5
`dbc6fbcb116a793012c7fe92e0ad2082`), une sous `animated/` et une sous
`perso/`, 14 485 536 octets chacune. Verifie plutot que suppose depuis leur
seul nom de fichier commun -- **les deux sont supprimees**, soit **27,6 Mo**
de source morte retires du depot.

### ⚠️ PREREQUIS QUI A COUTE UN MERGE AU LOT SUIVANT

Le lot B nommait `keepy_bear_walker.glb` dans son propre brief, mais cet asset
**n'existait que sur cette branche**, ni sur `main` ni sur `staging` -- verifie
par ancetralite (`merge-base --is-ancestor` = NON) et pas par lecture de
`git log`. D'ou le merge prealable `9257814` de la branche A dans celle du lot
B, avec verification que le blob y est **identique** a `Meshy_AI_Ourson.glb`
de `main` (`e4c501e9`).

**Regle a retenir** : un lot qui nomme un asset dans son brief doit verifier
par ARBRE que cet asset existe sur sa propre base, jamais supposer qu'un lot
d'identification precedent a ete merge.

### Reste ouvert a la cloture de ce lot

Aucune integration. L'asset est nomme et pose sous `assets_source/`, donc
**hors du pack** (`exclude_filter`), et rien ne le reference -- c'est le lot B
qui le fera entrer dans une scene.

## LOT B — SPIKE ISOLE : L'OURS ANIME MARCHE EN gl_compatibility, ET LE PIEGE `get_aabb()` EST CONFIRME PUIS CONTOURNE (1er septembre 2026)

Branche `claude/keepy-bear-animation-spike-g5js0d`, partie de `main`
(`d8f6fb0`). **Scene de test ISOLEE** : `HubBuilder.gd`, `HubWorld.gd`,
`KeepyHopper.gd` et `resources/hub/hub_layout.tres` sont **byte-intouches**,
verifie par `git status` -- le seul fichier existant modifie hors doc est
`LoginScreen`, pour la seule raison qu'il fallait un chemin d'acces device
(voir plus bas).

### ⚠️ PREREQUIS : L'ASSET DU BRIEF N'EXISTAIT PAS SUR `main`

`keepy_bear_walker.glb` n'existe que sur `origin/claude/bear-asset-visual-id-jwx53w`
(lot A), **non mergee** -- verifie par ancetralite (`merge-base --is-ancestor`
= NON) et pas par lecture de `git log`. Le blob y est **identique**
(`e4c501e9...`) a `Meshy_AI_Ourson.glb` de `main` : c'est un pur renommage.
Lot A merge en prerequis (`--no-ff`) plutot que de batir contre l'ancien nom,
qui aurait casse le jour ou lot A atterrit.

### ⚠️ DEUXIEME PREMISSE FAUSSE : IL N'EXISTE AUCUN COLLIDER DE REFERENCE

Le brief demandait de chercher « la hauteur de reference ou le rayon de
collision de Keepy » dans `KeepyHopper.gd`/`HubBuilder.gd`. **Le walker du
hub n'a AUCUN collider** -- `grep CollisionShape3D scripts/hub` ne rend que
l'`Area3D` de `HubPortal`. Deux candidats reels a la place :

| candidat | valeur | verdict |
|---|---|---|
| `Hitboxes.KEEPY_HEIGHT` | 1.6 | **ECARTE** -- son propre en-tete la designe comme « the reference every hazard's fairness contract is written against », c'est-a-dire un contrat de **Chased**, pas du hub |
| hauteur **DESSINEE** du hub | **1.3501** | **RETENU** -- `CabinInterior.gd` la derive deja (`1.257416 * KEEPY_SCALE 1.07368`), c'est la taille a laquelle Keepy apparait reellement a l'ecran |

### ⚠️ LE PIEGE `get_aabb()` EST REPRODUIT DEPUIS ZERO, PUIS LA VRAIE MESURE EST ETABLIE

Parse glTF direct (JSON + BIN, aucune dependance) : accessor POSITION,
`min.y = 1.002e-07`, `max.y = 1.700000` -> etendue brute **1.700000** ; le
noeud `Armature` porte `scale [0.01, 0.01, 0.01]` -> **0.017000**. C'est
**exactement** le chiffre annonce par le lot A, reproduit de premiers
principes plutot que repris sur parole.

**La mesure honnete** vient de `Skeleton3D.get_bone_global_pose()` sur les
24 os, en pose de repos : **etendue 1.671335** (le « ~1.67 » du brief).

⚠️ **ET J'AI FAIT LE BUG DEUX FOIS AVANT DE LE COMPRENDRE, PUBLIE PLUTOT QUE
LISSE.** Ma constante initiale venait du parcours TRS Python (**1.705818**,
plus haut os `head_end`). Premier boot : `rest span is 1.851959, constant
says 1.705818`. **Mauvais diagnostic** ("l'engine utilise les
`inverseBindMatrices`, Python le TRS des noeuds") et j'ai recale la
constante. Second run : `1.705802` contre `1.851959`. **L'etendue bougeait
AVEC l'echelle** -- `1.851959 / 1.108066 = 1.671335` et
`1.705802 / 1.020617 = 1.671335`, le meme nombre des deux cotes.

**Cause reelle : `skel.global_transform` porte DEJA le `BEAR_SCALE` du Rig,
donc mesurer a travers lui puis multiplier par `BEAR_SCALE` applique
l'echelle DEUX FOIS.** Corrige en mesurant dans l'espace propre du rig
(`rig_from_world = _rig.global_transform.affine_inverse()`). **Le controle
Python (1.705818, 2,1 % plus grand) est conserve en commentaire** : les deux
chiffres sont justes, ils repondent a deux questions differentes (TRS de
noeud glTF contre `inverseBindMatrices`).

⚠️ **C'est l'assertion de la sonde elle-meme qui a attrape mon bug** :
`BEAR_SCALE` est **re-mesure contre le rig vivant a chaque run** et
`push_error` en cas de derive. Elle a paye des le premier boot.

### L'ECHELLE, CALCUL MONTRE

```
KEEPY_DRAWN_HEIGHT  = 1.3501      (hauteur dessinee du hub)
HEIGHT_FACTOR       = 1.4         (milieu de la bande 1.3-1.5 du brief)
BEAR_TARGET_HEIGHT  = 1.3501 x 1.4      = 1.89014
BEAR_REST_SPAN      = 1.671335          (mesure os, pose de repos)
BEAR_SCALE          = 1.89014 / 1.671335 = 1.130876
verification        = 1.671335 x 1.130876 = 1.8901  OK
```

### MATERIAU EN `gl_compatibility` : CORRECT, VERIFIE AU PIXEL

`extensionsUsed = ['KHR_materials_specular']`, **`extensionsRequired`
ABSENT** -- l'extension est optionnelle, donc un fallback est legal et non
une casse. **Rendu reel** sous `xvfb-run --rendering-driver opengl3`
(llvmpipe LLVM 20.1.2), jamais `--headless` seul (qui force le driver DUMMY
et ne rend rien) :

| capture | mean_luma | max_luma |
|---|---|---|
| scene eclairee | **0.4664** | **1.0000** |
| lumiere coupee + ambiante a 0 | 0.2684 | 0.9961 |

Le PNG montre le personnage **entierement texture** -- casque jaune au logo
ours, fourrure brune, chemise a carreaux rouge/vert, gilet brun, short
kaki, ceinture. **Ni noir, ni casse.**

⚠️ **CONSTAT POUR LE LOT C, ET IL N'EST PAS COSMETIQUE : cet asset est
ECLAIRE, et le hub n'a AUCUNE `DirectionalLight3D`.** Toutes les surfaces du
plateau sont unshaded, precisement pour que « la couleur ecrite soit la
couleur vue ». Un personnage lit pose dans le hub tel quel n'aura aucune
source -- il faudra soit lui ajouter une lumiere, soit forcer son materiau
en unshaded, et les deux ont un cout a peser. La scene du spike porte donc
un `Sun` a 1.3 et une ambiante a 0.9 **qui n'existent nulle part dans le
hub**.

### LA SCENE, ET LE CHEMIN D'ACCES DEVICE

`scenes/test/BearAnimSpike.tscn` + `scripts/test/BearAnimSpike.gd` : plan de
sol 80x80 a l'albedo du hub, `WorldEnvironment` au `SWAMP_SKY`, camera fixe
a **-34 deg** (l'angle du hub, `HubCamera`), et une **capsule ambre
translucide de hauteur 1.3501 posee a cote** -- la reference Keepy, pour que
l'echelle se juge a l'oeil et pas seulement au chiffre.

⚠️ **`Transform3D(...)` dans un `.tscn` serialise la base en LIGNES, pas en
colonnes.** J'ai « corrige » la camera en supposant l'inverse : elle a pointe
le ciel (`mean_luma=0.0971`, cadre uniforme et vide). A connaitre avant de
retoucher une camera a la main dans un fichier de scene.

**Le bouton d'entree est sur `LoginScreen`, DELIBEREMENT** : c'est la
`run/main_scene`, donc **avant le gate d'auth** -- un device atteint le rig
sans aller-retour de connexion. Le menu de secours du hub aurait exige un
handler dans `HubWorld.gd`, que ce lot ne peut pas toucher. **JETABLE** :
il sort avec la scene de spike, et son commentaire le dit sur place.

### Validation

`rm -rf build .godot` avant tout. Import headless **exit 0, 0 erreur**,
**36 `.scn` pour 36 `.glb` sources** (import complet verifie, pas suppose).
Export Web release **exit 0**, **0 `SCRIPT ERROR`, 0 `Parse Error`**.

`index.wasm` **35 376 909** octets / md5
**`af4a8fc2925d992348eb30deeeb54360`**, `index.js` md5
**`4e08904b1b7107858246af44b602067b`** -- identiques au fingerprint permanent
de tout lot qui ne touche pas le code moteur. **Piege payload tenu** : sur
**280** lignes `Storing File`, **0** pour `scripts/dev`, `assets_source`,
`docs`, `web/`, `build` ou `firebase.json` -- et les trois ressources du
spike (`.glb.import`, les deux `.png.import`, `BearAnimSpike.gdc/.remap`)
**sont** packees, comme elles le doivent.

⚠️ **`index.pck` passe de ~34,35 Mo a 43 293 392 octets (+~8,9 Mo)** : le
`.glb` de 10,4 Mo et ses deux textures. **C'est le cout d'un SPIKE**, et il
sort avec lui si le rig n'est pas retenu -- a peser au lot C, avec les memes
leviers deja mesures ailleurs dans ce fichier (les maps mortes sur un
materiau unlit).

**Sondes de non-regression, toutes exit 0** : `ProbeTimeoutAudit`
(**59 sondes scenes + 1 `--script`**, retour exact a la baseline apres
suppression de la sonde de capture jetable), `AssetContractAudit` (**12/12
visuels, 0/10 colliders deplaces**), `DeathModelAudit`, `ChargerShapeProbe`.

### Reste ouvert -- jugement device, seul juge

1. **Est-ce que "Walking" boucle proprement sur un vrai telephone**, en
   WebGL2 sous Safari ? En sandbox la boucle est forcee
   (`Animation.LOOP_LINEAR`), 1,03 s, sans glitch visible -- mais llvmpipe
   sous `xvfb` via le backend `opengl3` de BUREAU n'est pas WebGL2.
2. **Est-ce que le materiau `KHR_materials_specular` tient sur device** ?
   C'est la seule question que le rendu sandbox ne peut pas fermer, et c'est
   tout l'objet de ce spike.
3. **Est-ce que 1,4x Keepy est la bonne taille** a l'oeil, la capsule ambre
   servant de repere ?
4. **La lumiere manquante du hub** (constat ci-dessus) -- a trancher au
   lot C, pas ici.

### Deploiement staging du spike lot B (palier 1, automatique)

`staging` **`aaf14c6`** (merge `--no-ff` de `29b267e`, arbre **byte-identique**
a la branche feature -- `git diff HEAD <branche> --stat` vide, verifie AVANT le
push). CI run **#358** (id 33550844219) **verte** -- `Import project resources`
19:41:00 -> 19:44:34, **`Export Web build` 19:44:34 -> 19:44:40**, `Verify
export output` succes, `Deploy to Vercel [STAGING -- staging]` **succes**
19:45:00 -> 19:45:12, `[PRODUCTION -- main]` correctement **skipped**.
**`main` NON touche** (`origin/main` toujours `215e6d4`).

**Verifie SUR LE SERVICE, pas dans le log CI, sur DEUX marqueurs
independants, les deux lectures en `x-vercel-cache: MISS` / `age: 0`** :

| marqueur | valeur servie |
|---|---|
| `CACHE_VERSION` | **`1788291880` = 19:44:40 UTC** -- tombe exactement sur la fermeture de l'etape `Export Web build` |
| `index.wasm` servi | **35 376 909** -- identique a l'export local, le fingerprint permanent |
| `index.pck` servi | 43 293 408 (export local 43 293 392, **16 octets d'ecart** -- l'instabilite deja consignee ; marqueur, jamais preuve d'identite) |

⚠️ **Limite dite plutot que sous-entendue** : la valeur "avant" du
`CACHE_VERSION` (`1788268182`) a ete lue sur un `HIT` a `age: 23252` -- valable
comme VALEUR (elle precede le push), **pas** une mesure de fraicheur. La
bascule est etablie par la concordance de l'epoch servi avec la fenetre
d'export de CE run, plus deux lectures fraiches -- pas par une paire
avant/apres toutes deux en MISS.

⚠️ **`curl` vers `*.vercel.app` est refuse par le proxy de ce sandbox** (piege
deja consigne) : les deux lectures passent par le canal MCP Vercel. Une boucle
d'attente `curl` avait ete lancee puis **arretee immediatement** pour cette
raison -- une garde qui compare une chaine VIDE a l'ancienne valeur la trouve
"differente" et annonce un deploiement qui n'a pas eu lieu.

**Chemin d'acces device** : `keepy-staging.vercel.app` -> bouton **"Spike ours
(dev)"** sur l'ecran de connexion (AVANT le gate d'auth, donc aucun
aller-retour de connexion) -> `res://scenes/test/BearAnimSpike.tscn`. Bouton
**JETABLE**, il sort avec la scene de spike.

## LE BOUTON DU SPIKE OURS ETAIT SUR UN ECRAN QUE MATHIEU NE TRAVERSE JAMAIS (1er septembre 2026)

Branche `claude/keepy-bear-spike-access-bwykwb`, partie de `staging`
(`5cf98c8`). Correctif d'un defaut d'ACCES, pas de rendu : le lot spike
lot B avait pose son bouton d'entree sur `LoginScreen.tscn`/`.gd`, en
supposant que cet ecran est toujours traverse. **Faux** -- la session de
Mathieu persiste, donc il arrive directement dans le hub et l'ecran de
connexion n'est jamais affiche. Le bouton etait litteralement
inatteignable dans son flux reel.

### ⚠️ RECON : IL N'EXISTE AUCUN MENU DEBUG POUR LA CABANE -- elle est du gameplay ORDINAIRE

C'etait l'etape bloquante du brief (« trouver comment Mathieu atteint
`CabinInterior.tscn` en test »), et la reponse ferme la question plutot
que de la contourner :

* **La cabane n'a PAS de porte de debug.** `CabinInterior.tscn` est
  atteinte par le jeu normal -- `HubRouter.ROUTES[&"cabin"]`, en tapant le
  marqueur du pas de porte sur le plateau. `HubRouter` est la table de
  routage de PRODUCTION et l'unique appelant de `change_scene_to_file`
  pour les quatre destinations (`chased`, `quizz`, `battle`, `cabin`).
  Il n'y a donc rien a « repliquer » de ce cote-la : le chemin cabane est
  du gameplay, pas un acces de test.
* **Le SEUL mecanisme etabli de ce depot pour atteindre une SCENE DE TEST
  ISOLEE depuis un telephone est le MENU DE SECOURS DU HUB** -- le bouton
  « Menu » en haut a droite de `HubWorld.tscn`, qui ouvre
  `FallbackMenu/Panel/VBoxContainer`. C'est exactement par la que le banc
  multi-niveaux a fait sa propre passe device : bouton « Test nav (dev) »,
  commit **`b7e641b`**, retire par **`1504982`** (« cleanup: close the two
  debug doors before production »).

**Ce precedent est replique A L'IDENTIQUE, pas adapte** : meme conteneur
parent, meme metrique de bouton (320x84, font 24) et memes `StyleBoxFlat`
que le `NavTestButton` retire, meme appel direct
`get_tree().change_scene_to_file(...)` **contournant deliberement
`HubRouter.ROUTES`** (cette table est le routage de production, un banc
jetable n'y entre pas), et meme discipline de commentaire jetable nommant
chaque piece a retirer ensemble. **Aucun systeme d'acces parallele n'est
invente.**

### Ce qui change, et le perimetre tenu

`git diff --stat origin/staging` : **exactement 6 fichiers**.

| fichier | changement |
|---|---|
| `scenes/HubWorld.tscn` | +11 -- `SpikeButton` insere juste avant `CloseButton` |
| `scripts/hub/HubWorld.gd` | +23 -- un `@onready`, une connexion, `_on_fallback_spike()` |
| `scenes/LoginScreen.tscn` | **-11 -- rendu byte-identique a `origin/main`** |
| `scripts/ui/LoginScreen.gd` | **-17 -- rendu byte-identique a `origin/main`** |
| `scripts/test/BearAnimSpike.gd` | +7/-1 -- le retour pointe sur le hub |
| `scenes/test/BearAnimSpike.tscn` | +-2 -- libelle `« < Retour hub »` |

⚠️ **La contrainte « ne pas toucher au hub au-dela du point d'acces
lui-meme » est VERIFIEE, pas affirmee** : `git diff origin/staging` rend
**0 ligne** pour `HubBuilder.gd`, `HubTapInput.gd`, `HubRegion.gd`,
`HubCamera.gd`, `KeepyHopper.gd`, `HubRouter.gd` et
`resources/hub/hub_layout.tres`. Les seules lignes de `HubWorld.gd`
touchees sont les trois du bouton.

**Les deux fichiers `LoginScreen` sont RESTAURES, pas retouches** :
`git checkout origin/main --` sur les deux, puis `git diff origin/main`
verifie a **0 ligne**. Le code spike y etait jetable des le depart ; il
part parce qu'il est inutilisable, pas remplace en silence.

⚠️ **La sortie du spike suit l'entree** : `BearAnimSpike._on_back()`
renvoyait sur l'ecran de connexion, ce qui rendait le trajet a sens unique
une fois l'entree deplacee. Il renvoie desormais sur `HubWorld.tscn` --
meme forme que le « Retour hub » du banc nav.

### LE CHEMIN D'ACCES REEL, depuis l'ecran que Mathieu voit au chargement

```
keepy-staging.vercel.app  ->  le jeu ouvre sur LE HUB (session persistante)
   -> taper « Menu » (bouton en haut a DROITE)
   -> taper « Spike ours (dev) »   -> res://scenes/test/BearAnimSpike.tscn
   -> retour par « < Retour hub »
```

### Validation

Editeur + templates Godot 4.3-stable installes dans ce sandbox (releases
GitHub officielles, **tailles verifiees contre le `Content-Length`** :
50 276 070 et 1 073 228 327 octets, aucune troncature). `rm -rf build
.godot` avant tout. Import headless **exit 0, 0 erreur, 36 `.scn` pour 36
sources `.glb`** (import complet verifie, pas suppose). Boot headless de
`HubWorld.tscn`, `LoginScreen.tscn` et `BearAnimSpike.tscn` : **exit 0,
aucune erreur SCRIPT/Parse**. Export Web release **exit 0, 0 erreur**.

`index.wasm` **35 376 909** octets / md5
**`af4a8fc2925d992348eb30deeeb54360`**, `index.js` md5
**`4e08904b1b7107858246af44b602067b`** -- identiques au fingerprint
permanent de tout lot qui ne touche pas le code moteur. `index.pck`
43 293 472, **marqueur et jamais preuve d'identite**. **Piege payload
tenu** : sur **280** lignes `Storing File`, **0** pour `scripts/dev`,
`assets_source`, `docs`, `web/`, `build` ou `firebase.json` -- et **6**
pour les ressources propres au spike, qui doivent bien y etre.

**Sondes, toutes exit 0** : `ProbeTimeoutAudit` (**59 sondes scenes + 1
`--script`**, chiffre inchange -- ce lot n'ajoute aucune sonde),
`AssetContractAudit` (**12/12 visuels, 0/10 colliders deplaces**),
`DeathModelAudit`, `ChargerShapeProbe`, plus -- sous `xvfb-run
--rendering-driver opengl3`, jamais `--headless` seul -- `CabinProbe`,
`TurnstileProbe`, `SeesawProbe` et `WaterTintProbe`, chacune **0
failure(s)**.

### Reste ouvert

1. **Jugement device, seul juge** : le spike ours existe pour etre regarde
   sur un vrai telephone (WebGL2/Safari), et ce lot ne fait que le rendre
   ATTEIGNABLE -- il ne dit rien du rig lui-meme.
2. **Tout ce lot est JETABLE et STAGING-ONLY** : le `SpikeButton`, son
   `@onready`, sa connexion, `_on_fallback_spike()` et
   `scenes/test/BearAnimSpike.tscn` sortent **ensemble**, dans le meme lot,
   avant que quoi que ce soit d'ici n'atteigne `main`.

### Deploiement staging (palier 1, automatique)

`staging` **`6734404`** (merge `--no-ff`, arbre **byte-identique** a la
branche feature : meme hash d'arbre `5b4374aa` des deux cotes ET
`git diff --stat` a 0 ligne, verifie AVANT le push). CI run **#360**
(id 33555961739) **verte** -- `Import project resources` 20:33:45 ->
20:37:22 (3 min 37), **`Export Web build` 20:37:22 -> 20:37:28**,
`Verify export output` succes, `Deploy to Vercel [STAGING -- staging]`
**succes** 20:37:49 -> 20:38:03, `[PRODUCTION -- main]` correctement
**skipped**. **`main` NON touche** (`origin/main` toujours `215e6d4`).

**Verifie SUR LE SERVICE, pas dans le log CI, sur DEUX marqueurs
independants** :

| marqueur | avant | apres (ce lot, run #360) |
|---|---|---|
| `CACHE_VERSION` | **`1788292533` = 19:55:33 UTC** | **`1788295047` = 20:37:27 UTC** |
| `index.wasm` servi | -- | **35 376 909** *(fingerprint permanent)* |
| `index.pck` servi | -- | 43 293 456 |

L'epoch d'apres tombe **a l'interieur de la fenetre `Export Web build`**
(20:37:22 -> 20:37:28), et **les lectures d'avant ET d'apres portent
`x-vercel-cache: MISS` avec `age: 0`** -- la valeur d'avant ayant ete
relevee AVANT le merge, la bascule est prouvee dans les deux sens et pas
deduite du log. C'est la forme la plus forte que ce fichier documente.

⚠️ **`index.pck` : 43 293 472 a l'export local propre contre 43 293 456
servi, 16 octets d'ecart** -- enieme illustration de l'instabilite deja
consignee, **marqueur « nouveau build » et jamais preuve d'identite**.
`index.wasm` est identique des deux cotes et c'est lui qui la porte.

⚠️ **L'API GitHub Actions a de nouveau servi un etat perime**, note dans
ce sens-la : `get_workflow_run` est reste fige sur `updated_at
20:33:02` / `in_progress` alors que le job avancait reellement --
`list_workflow_jobs` avec `filter: "all"` rendait, lui, chaque etape avec
son vrai horodatage. Le piege est celui deja consigne ; la lecture au
niveau des JOBS est celle qui dit vrai.

## LOT C -- L'OURS MARCHE VERS LA BALANCOIRE : un marcheur GENERIQUE, et l'ETAPE 0 se referme sur une egalite qui n'est PAS une garantie (1er septembre 2026)

Branche `claude/keepy-walker-seesaw-t6a12z`, partie de `main` (`215e6d4`) et
`staging` (`40aa427`) -- le rig ours et son point d'acces de test y sont deja,
valides sur device au lot B. **`KeepyHopper.gd` n'est PAS touche** : ce lot ne
fait que LIRE ses deux signaux existants (`seesaw_mounted`,
`seesaw_dismounted`), verifie par `git diff --stat` et pas affirme.

### ⚠️ ETAPE 0 -- LE MATERIAU SANS LUMIERE : issue (a), MAIS L'EGALITE EST UN ACCIDENT D'ASSET

Le hub n'a **AUCUN noeud `Light3D`** -- compte, pas suppose -- et son
`Environment` porte `ambient_light_source 2 (COLOR)`, couleur
`(0.42, 0.5, 0.35)`, energie `0.750`. La scene de spike du lot B, elle, portait
un `Sun` a 1.3 et une ambiante a 0.9 **qui n'existent nulle part dans le hub** :
la validation device du lot B ne disait donc rien du rendu reel.

**Mesure au pixel, jamais a l'oeil** (rendus offscreen `xvfb-run
--rendering-driver opengl3`, 1080x1920 = 2 073 600 px, diffes contre
`bear_lit.png`) :

| variante | pixels differents |
|---|---|
| **unshaded force** | **0** |
| ambiante forcee ROUGE a 3.0 | **0** |
| `AMBIENT_SOURCE_DISABLED` | **0** |
| **BLIND CHECK : override magenta** | **23 372** *(pire delta 238, bbox 439,973 - 591,1191)* |

Le blind check est ce qui donne un sens aux trois zeros : il prouve que le
chemin d'override atteint bien la surface dessinee, sans quoi « 0 pixel
different » passerait gratuitement contre un override qui n'ecrit nulle part.

**Le mecanisme, lu sur le materiau importe** : `StandardMaterial3D`,
`shading_mode = 1` (LIT), `metallic = 1` **sans texture metallic**, `roughness
= 1`, `emission_enabled = true`, `emission = (0,0,0)` en operateur ADD avec une
`emission_texture`. Un `metallic = 1` annule le terme diffus -- la seule chose
qu'une ambiante COULEUR sache alimenter ; zero lumiere et aucune radiance map
annulent le speculaire. **Ce qui dessine reellement est l'EMISSION**, qui est
independante de la lumiere. Et sa map est **byte-identique a la map d'albedo**
(md5 `8f1c95fbd6200aec2827ddb4be7977d2`, deux ressources distinctes, 2048x2048
toutes les deux).

⚠️ **DONC : issue (a), le personnage reste parfaitement lisible sans lumiere,
et AUCUNE escalade n'etait due. Mais l'unshaded est force QUAND MEME, et c'est
la decision qui compte.** Cette egalite repose entierement sur une map
d'emission survivant a chaque futur re-export : retirez-la, et une surface
totalement metallique sous zero lumiere dessine **NOIR, en silence**. Sur
l'albedo, elle ne le peut pas. Forcer coute zero pixel aujourd'hui et ferme un
mode de panne muet demain.

### ETAPE 1 -- `HubActorWalker.gd`, generique des la premiere ligne

Rien dedans ne nomme un ours, une balancoire ni le hub : le modele, son
echelle, son clip, sa vitesse et **chaque destination** arrivent en donnee.
Etats `IDLE / WALKING / ARRIVED`.

⚠️ **LA TRAVERSEE EST A VITESSE CONSTANTE, PAS LE LERP EXPONENTIEL DE
`HubCamera`, et ce n'est pas une preference.** Un lerp a une vitesse
proportionnelle a la distance restante : le meme cycle de marche serait joue a
**~9 u/s** au depart d'un trajet de 6 unites et a **~0 u/s** a l'arrivee. Un
personnage dont les jambes cyclent a cadence fixe pendant que sa vitesse au sol
varie d'un ordre de grandeur, c'est la definition du patinage. La forme
exponentielle est **conservee pour le CAP** (`turn_lambda = 6.0`, memes unites
que `FOLLOW_LAMBDA`), ou elle est juste : un virage n'a aucune cadence a
contredire.

⚠️ **`walk_speed = 0.7556` EST DERIVE DU CLIP LUI-MEME, pas choisi -- et pas
derive de la longueur de foulee non plus.** La seule vitesse a laquelle un pied
ne patine pas est celle a laquelle le pied POSE recule dans le repere du rig.
Chaque os a donc ete echantillonne sur le clip livre (longueur **1.033333 s**,
24 os, `loop_mode` **NONE** a l'origine), les frames de pied bas retenues, et
`dz/dt` ajuste sur cette fenetre d'appui, rig deja a son echelle 1.130876 :

| os | fenetre | vitesse |
|---|---|---|
| LeftToeBase | 18/64 | 0.7501 u/s |
| LeftFoot | 15/64 | 0.7332 u/s |
| RightFoot | 20/64 | 0.7835 u/s |
| RightToeBase | **7/64** | 1.1586 u/s -- **ECARTE** |

L'aberrant est ecarte **sur son nombre d'echantillons, pas sur sa valeur** :
sept frames est une fenetre que le seuil a tronquee, donc sa pente porte le
deroule de l'orteil et non la vitesse au sol. Les trois qui s'accordent
moyennent **0.7556**. Une estimation par foulee entiere aurait donne **0.81 a
1.05** selon qu'on lit la cheville ou l'orteil -- cet ecart est exactement
pourquoi l'ajustement d'appui a ete fait a la place.

⚠️ **DEUX PIEGES DE RESSOURCE PARTAGEE, FERMES CHACUN PAR UNE DUPLICATION, ET
CHACUN PROUVE ROUGE-AVANT-VERT :**

1. **Le materiau** -- l'importeur glTF lie **UN** materiau partage sur le mesh,
   donc ecrire dedans teinte toutes les instances de ce `.glb` du projet.
   `_force_unshaded()` duplique avant d'ecrire (precedent
   `FighterView._ensure_material()`).
2. **L'ANIMATION** -- et celui-la est moins connu : `instantiate()` copie des
   NOEUDS, pas les `Animation` qu'ils pointent. Ecrire `loop_mode` sur le clip
   que le player rend ecrit sur la ressource **PARTAGEE**, donc un second
   acteur tire du meme `.glb` -- ou la scene de spike du lot B -- en heriterait
   en silence. L'acteur recoit donc sa **propre `AnimationLibrary`**, et le
   clip du `.glb` n'est jamais ecrit.

Le gel est un `pause()` **et jamais une ecriture de `loop_mode`** : une pause
est par-PLAYER, un `loop_mode` est par-RESSOURCE. La derniere frame d'un cycle
de marche EST sa premiere, donc `seek(0)` tient la meme pose que `seek(length)`
et 0 est le seul qui ne peut pas boucler.

**Le cap est lu sur la geometrie du rig, pas suppose** : la face est en model
**+Z**, verifie au rendu a travers la camera du hub (qui regarde -Z, donc voit
la face +Z d'un noeud) -- visage, casque et ceinture tous a l'ecran a rotation
zero. Meme convention que le modele de Keepy.

### ETAPE 2 -- LE BRANCHEMENT, ET UN PIEGE D'ORDRE DE SIGNAL

`HubWorld.gd` est **le seul fichier existant du hub touche**, et **purement
additif** : `git diff --stat origin/staging` = **120 insertions, 0
suppression**.

⚠️ **`seesaw_mounted` EST EMIS AVANT QUE `_seesaw_ride` NE SOIT ASSIGNE.**
`_mount_seesaw()` appelle `mount_seesaw()`, qui emet le signal
**synchroniquement**, et n'assigne `_seesaw_ride` qu'ENSUITE -- donc un
handler qui lirait `_seesaw_ride` lirait le dictionnaire vide. Resolu par
`_seesaw_under()`, qui rejoue **le meme test de rayon que `_rock_near`**
(factorise, pour que l'ours et la bascule ne puissent jamais etre en desaccord
sur quelle planche un atterrissage appartient).

⚠️ **ET C'EST LA RACINE, PAS LE PIVOT, QUI SERT DE REPERE** : la rotation en z
du pivot est ce que la bascule ANIME, donc transformer a travers lui donnerait
un point qui monte et descend avec la planche. Le cote est lu sur
`root.to_local(keepy)` et l'ours vise `root.to_global(Vector3(-side * 2.6, 0,
0))` -- l'extremite opposee, jamais celle ou Keepy est assis.

**Point de repos `Vector3(0, 0, 35.5)`, choisi par balayage du layout et pas a
l'oeil** : sur l'axe local Z de la balancoire (donc les deux bouts de planche
sont la meme marche), **5.95 u** du prop le plus proche, et DERRIERE la
balancoire depuis la camera.

**Cout de dessin : UN `MeshInstance3D`.** ⚠️ **L'ours est parente sous `World/`
a cote de Keepy et NON sous `World/Props`, parce qu'il BOUGE -- et le budget de
noeuds partage par `SeesawProbe`/`TurnstileProbe`/`WaterTintProbe`
(`_EXPECTED_DRAW_NODES_EXCL_PORTALS`) compte sur `World/Props` SEUL, donc il ne
peut structurellement pas le voir.** Verifie : les trois sondes lisent
**132/132**, inchange. Le cout est donc publie ici plutot que gate la-bas.

### ⚠️ ETAPE 2 -- LE CHOIX DE SENSATION EST PARQUE, ET LES DEUX OPTIONS NE SONT PAS SYMETRIQUES

`BEAR_RETURNS_HOME` est une constante a une ligne, `false` a la livraison.
**Ce n'est pas une preference, c'est une mesure** :

| | duree |
|---|---|
| la bascule (`SEESAW_ROCK_S`) | **2.4 s** |
| la marche de l'ours, mesuree bout en bout | **5.28 s** |

`seesaw_dismounted` part donc **pendant que l'ours est encore en route**. Sous
l'option B (« il rentre »), il ferait demi-tour a mi-approche et **n'arriverait
jamais** -- choisir B, c'est donc choisir implicitement « un ours plus rapide
ou un point de repos plus proche ». Les deux options ne sont pas deux gouts,
c'est un gout contre un reglage a refaire. **Decision de Mathieu, non prise
ici.**

### ETAPE 3 -- NON-REGRESSION, DIFFEE ET PAS AFFIRMEE

`git diff --stat origin/staging` sur `HubBuilder.gd`, `KeepyHopper.gd`,
`HubRouter.gd` et `resources/hub/hub_layout.tres` : **VIDE** sur les quatre.

Sondes diffees contre un worktree `origin/staging` **dont l'import a ete
verifie complet des deux cotes (36 `.scn` chacun)** -- le piege du faux-rouge
par import tronque a d'ailleurs frappe au premier essai (10 `.scn` malgre un
exit 0), et a ete referme avant toute comparaison :

| sonde | verdict |
|---|---|
| `AssetContractAudit`, `DeathModelAudit`, `ChargerShapeProbe`, `SeesawProbe` | **BYTE-IDENTIQUES sur les DEUX flux** |
| `ProbeTimeoutAudit` | diff = **exactement deux lignes** (`ActorWalkerProbe.tscn` armee, et **59 -> 60** sondes scenes) |

### `ActorWalkerProbe` -- GATEE, 0 echec, et TROIS defauts trouves dans MES PROPRES assertions

Gatee et pas rapportee parce que **tout mode de panne est SILENCIEUX**, et que
**deux d'entre eux FUIENT HORS de l'acteur** (le materiau partage, l'Animation
partagee) -- les deux sont donc assertes **des DEUX cotes** : ce que l'acteur
dessine, ET que la ressource du `.glb` est restee intacte.

⚠️ **PHASE C N'IMPRIMAIT RIEN AU PREMIER RUN -- UN FAUX VERT COMPLET.**
`_phase_c` contient un `await`, ce qui en fait une **coroutine** : l'appeler nue
la fait tourner **CONCURREMMENT**, et l'arbre quitte avant que ses assertions
n'impriment quoi que ce soit. **0 echec rapporte, une phase entiere absente.**
C'est le piege coroutine deja consigne dans ce fichier, re-paye ici a une
couche de plus. Corrige en `await _phase_c(walker)`.

⚠️ **L'ASSERTION DE CAP PASSAIT GRATUITEMENT.** `TARGET` valait `(0, 0, 2)` --
droit sur +Z, donc le cap voulu est **zero**, et un acteur qui ne tourne
**jamais** satisfaisait le test. Corrige en deplacant la cible **hors axe**
(`(1.5, 0, 1.5)`, cap voulu 0.785 rad) et en remplacant la disjonction par un
`absf(yaw - wanted) < 0.01` strict, **plus un BLIND CHECK** que le cap voulu
n'est pas le cap de depart.

⚠️ **UNE ASSERTION FAIBLE TROUVEE PAR LE TEST ROUGE lui-meme** : avec
`_force_unshaded` neutralise, `drawn` valait `null` et « l'override est un
duplicat » passait parce que `null != own`. Corrige en `drawn != null and drawn
!= own`.

Quatre phases : **A** un seul mesh, un player trouve, la surface DESSINE
unshaded (lue sur `get_surface_override_material`, **jamais** sur la constante
ecrite) + blind check que le materiau PROPRE du mesh est reste LIT ; **B** la
marche, l'arrivee (`arrived` exactement une fois, `< 1.0e-4` de la marque), le
cap strict, plus deux blind checks (le clip avance vraiment, l'acteur a vraiment
voyage) ; **C** la pose ne bouge pas sur 12 frames, l'acteur joue SON duplicat,
ce duplicat boucle, et **le clip du `.glb` est reste `LOOP_NONE`** ; **D** une
marche de longueur nulle arrive immediatement et ne laisse pas l'acteur coince
en WALKING.

`walk_speed` est **rapporte et deliberement pas gate** : re-deriver
l'ajustement d'appui avec une logique de seuil legerement differente ferait
echouer du code correct.

### Verification bout-en-bout DANS LE HUB LIVRE

Sonde jetable (supprimee avant commit), `xvfb`/`opengl3`, sur
`scenes/HubWorld.tscn` reelle :

```
bear rest (0, 0, 35.5)  state IDLE  draws 1 MeshInstance3D
seesaw (0, 0, 38.5) ride_x=1.38     mounted: true
keepy local x = +1.855  ->  bear walked to local x = -2.600
final (-2.6, 0, 38.5)   distance bear<->keepy = 6.05 u
walk took 5.28 s        state ARRIVED
```

Deux captures gardees : `docs/hub-shots/lotc_bear_{walking,arrived}.png`
(`docs/` est dans l'`exclude_filter`, elles ne coutent rien au pack).

### Reste ouvert -- jugement device, seul juge

1. **Est-ce que la marche se lit comme une marche** a vitesse reelle sur un
   telephone -- le patinage est ferme par construction (vitesse constante,
   cadence issue de la phase d'appui), mais 0.7556 u/s n'a jamais ete juge a
   l'oeil.
2. **Est-ce que l'ours unshaded se lit comme au lot B**, ou la scene portait un
   Sun et une ambiante que le hub n'a pas ? Les zeros de l'etape 0 sont mesures
   sous llvmpipe/`opengl3` de BUREAU, **pas** sous WebGL2/Safari.
3. **`BEAR_RETURNS_HOME`** -- la decision parquee ci-dessus.
4. **La pose figee** : il gele sur la premiere frame de `Walking`, faute de
   clip « assis »/« regarde ». C'est une pose de marche arretee, pas une pose
   de spectateur.

### Deploiement staging du lot C (palier 1, automatique)

`staging` **`eab31e5`** (merge `--no-ff` de `c07045b`, arbre **byte-identique**
a la branche feature : meme hash d'arbre `76567e7b` des deux cotes, verifie
AVANT le push). CI run **#362** (id 33573396917, head_sha `eab31e58...`)
**verte** -- `Import project resources` 00:00:03 -> 00:03:23 (3 min 20),
**`Export Web build` 00:03:23 -> 00:03:29**, `Verify export output` succes,
`Deploy to Vercel [STAGING -- staging]` **succes** 00:03:48 -> 00:04:00,
`[PRODUCTION -- main]` correctement **skipped**. **`main` NON touche**
(`origin/main` toujours `215e6d4`, verifie apres le push).

**Verifie SUR LE SERVICE, pas dans le log CI, sur DEUX marqueurs
independants** :

| marqueur | avant | apres (ce lot, run #362) |
|---|---|---|
| `CACHE_VERSION` | **`1788295565` = 1er sept 20:46:05 UTC** | **`1788307409` = 2 sept 00:03:29 UTC** |
| `index.wasm` servi | -- | **35 376 909** *(fingerprint permanent)* |
| `index.pck` servi | -- | 43 298 864 |

L'epoch d'apres tombe **exactement sur la seconde de fermeture de l'etape
`Export Web build`** (00:03:23 -> 00:03:29), et **les lectures d'avant ET
d'apres portent `x-vercel-cache: MISS` avec `age: 0`** -- la valeur d'avant
ayant ete relevee AVANT le push, la bascule est prouvee dans les deux sens et
pas deduite du log. C'est la forme la plus forte que ce fichier documente.

⚠️ **Limite dite plutot que sous-entendue** : `fileSizes` (`index.wasm` /
`index.pck`) n'a ete lu qu'APRES le merge, donc il vaut comme marqueur d'ETAT
COURANT et **pas** comme preuve de transition -- c'est le `CACHE_VERSION` qui
la porte. `index.wasm` servi est en revanche **identique au bit pres a
l'export local** (md5 `af4a8fc2925d992348eb30deeeb54360`), et c'est lui la
preuve d'identite.

⚠️ **`index.pck` : 43 298 816 a l'export local propre contre 43 298 864
servi, 48 octets d'ecart** -- enieme illustration de l'instabilite deja
consignee, **marqueur « nouveau build » et jamais preuve d'identite**.

⚠️ **`curl` vers `*.vercel.app` reste refuse par le proxy de ce sandbox**
(`connect_rejected`, politique d'organisation -- re-teste et pas suppose) :
les deux lectures passent par le canal MCP Vercel. Une boucle d'attente
`curl` avait ete ecrite puis abandonnee pour cette raison, avant qu'elle ne
puisse comparer une chaine VIDE a l'ancienne valeur et annoncer un
deploiement qui n'a pas eu lieu.

⚠️ **L'API Actions n'etait PAS perimee sur ce run, et c'est note dans ce
sens-la** : deux polls successifs ont rendu une reponse byte-identique, ce
qui en a exactement la forme -- mais l'horloge disait ~3 minutes ecoulees
depuis un import demarre a 00:00:03, et cet import a reellement dure
**3 min 20 s** (plus lourd depuis l'ajout du `.glb` ours de ~10 Mo et de ses
deux textures ~5 Mo). Verifier l'HEURE avant d'accuser l'API reste la parade,
dans les deux sens.

**Chemin d'acces device** : `keepy-staging.vercel.app` -> le hub -> taper la
balancoire (lobe nord, `(0, 0, 38.5)`) -> Keepy monte dessus -> **l'ours
quitte son point de repos `(0, 0, 35.5)`, marche ~5,3 s vers le bout de
planche OPPOSE a Keepy, arrive et se fige**.

## L'OURS MONTE SUR LA BALANÇOIRE : un second rider, et un conflit de timing qui rendait le premier lot invisible (2 septembre 2026)

Branche `claude/bear-seesaw-lot-d-b0qm3o`, repartie de `origin/staging`
(`900d827`). Regle n°1 verifiee par ARBRE et pas par nom :
`origin/claude/keepy-walker-seesaw-t6a12z` est deja ancetre de
`origin/staging` (`merge-base --is-ancestor`), **aucune session
concurrente**. **Diff VIDE verifie** sur `KeepyHopper.gd`, `HubBuilder.gd`,
`HubRouter.gd` et `hub_layout.tres` -- le diff complet ne touche que
`HubActorWalker.gd`, `HubWorld.gd` et `ActorWalkerProbe.gd`.

### ⚠️ ETAPE 0 -- L'OURS N'AVAIT JAMAIS ETE VU SUR LA PLANCHE, ET LE CHIFFRE LE DIT

Lot C livrait un ours qui marche vers la balancoire quand Keepy s'y
assoit. Mesure : destination `(±2,6 ; 0 ; 38,5)` depuis un repos
`(0 ; 0 ; 35,5)` = **3,970 u**, soit **5,254 s** a `walk_speed` 0,7556 u/s
-- contre un `SEESAW_ROCK_S` de **2,4 s**. Le `seesaw_dismounted` partait
donc **2,85 s AVANT l'arrivee** : l'ours n'a jamais atteint la planche une
seule fois.

**Les quatre options du brief, mesurees plutot que jugees :**

| option | verdict |
|---|---|
| (a) rapprocher le point de repos SEUL | **impossible** -- meme au pivot, un siege est a `SEESAW_RIDE_X` 1,38, donc la marche plancher est ~1,83 s |
| (b) accelerer SEUL | k ~ **3,0** depuis 35,5 -- une lecture comique |
| (c) declencher sur un signal d'approche | **aucun signal n'existe** (verifie, pas invente) : le seul point plus tot serait la destination d'un tap, dont le preavis est nul quand le joueur tape depuis le bord de la balancoire |
| (d) allonger `SEESAW_ROCK_S` | **DERNIER RECOURS, non utilise** -- c'est la duree de ride de Keepy, deja validee device |

**Retenu : (a) + (b) combines, `SEESAW_ROCK_S` intouche.**
`BEAR_REST` 35,5 -> **37,0** (re-scan layout : encore **5,374 u** du prop
le plus proche, le rocher a `(-5,18 ; 0 ; 38,43)`), `BEAR_WALK_RATE`
**2,0**, et la destination passe de « 0,8 au-dela de la pointe » a **a cote
du bout de planche** (`BEAR_APPROACH_Z` 0,8 sur le Z local, cote depuis
lequel l'ours arrive, derive du signe de son propre z local pour qu'une
balancoire tournee marche aussi).

**Resultat : approche 1,547 u -> 1,024 s -> l'ours est A BORD pendant
1,376 s des 2,4 s de rock, soit 57,3 %.** Mesure in-engine par la sonde :
**1,00 s de temps de jeu**.

⚠️ **A COTE DE LA PLANCHE ET PAS DESSOUS** : a `SEESAW_TILT_DEG` 15 le bout
balaie ±0,357 u en vertical, donc un acteur qui marcherait sur la ligne de
la planche la traverserait.

⚠️ **`walk_rate` EST UN SEUL BOUTON ET PAS DEUX**, et c'est structurel :
`walk_speed` est la vitesse a laquelle le pied PLANTE recule dans le
repere du rig a playback 1,0 -- la seule vitesse ou un pied ne patine pas
-- et la relation est exactement lineaire en playback. `HubActorWalker`
ecrit donc `_player.speed_scale = walk_rate` et expose
`ground_speed() = walk_speed * walk_rate`. Exposer les deux separement,
c'est comme ca qu'un appelant demande une marche plus rapide et obtient un
moonwalk. `BEAR_WATCH_X` devient inutilise et est **retire** (grep : aucun
lecteur hors `HubWorld.gd`).

### ETAPE 1 -- LE SECOND RIDER EST ECRIT DANS `_apply_tilt` ET NULLE PART AILLEURS

```gdscript
pivot.rotation_degrees.z = -side * SEESAW_TILT_DEG * cos(...) * damp
if riding:
    _keepy.follow_seesaw()
if _bear != null and _bear_pivot == pivot:
    _bear_follow_seesaw()
```

**La discipline est mesuree et pas stylistique** : un rider qui lit son
prop sur son propre callback a ete mesure **une frame entiere en retard**
sur le tourniquet (12,0 deg au pic), et `process_priority` n'y changeait
rien parce que les steps de Tween tombent apres le `_process` de tout
noeud.

⚠️ **`KeepyHopper.gd` N'EST PAS REFACTORE.** La logique de suivi est
DUPLIQUEE cote `HubWorld` plutot que d'extraire une interface commune --
le rider de Keepy est valide device, et le facteur commun se paierait sur
lui. Diff vide verifie.

⚠️ **LE GATE EST `_bear_pivot == pivot` ET PAS `_seesaw_ride`** : un
re-pump remplace le tween en cours de ride, donc un gate sur l'entree de
ride perdrait l'ours a chaque re-tap.

Siege : `Vector3(-side * ride_x, seat_y, 0)` en repere pivot -- **le bout
oppose a celui de Keepy**, derive de sa propre place et non d'un cote
fixe. Orientation : vers l'interieur (`-seat.x` a travers la base du
pivot), donc **vers Keepy**, et derivee du SIEGE plutot que de sa position
pour rester juste la frame ou il part.

⚠️ **IL SNAPPE SUR LA PLANCHE, decision et pas raccourci** : le rig ne
livre qu'un cycle de marche, il n'existe aucune animation de montee. Le
snap fait 0,8 u lateral et ~0,69 u vertical, pris en une frame a l'instant
ou la marche finit. `_bear_follow_seesaw()` est appele **immediatement** a
l'arrivee plutot qu'a la prochaine step de tween : une frame d'ours debout
a cote de la planche a hauteur de siege est exactement le pop que ca evite.

⚠️ **L'ARRIVEE RE-VERIFIE LE RIDE** plutot que de faire confiance au
mount : l'approche dure ~1 s, et un re-pump ou un dismount precoce peut
tomber dedans. Monter une planche vide et deja posee laisserait l'ours sur
du decor, sans tilt a suivre et sans dismount a venir.

### ETAPE 2 -- DISMOUNT SYNCHRONE

Sur `seesaw_dismounted` (le meme signal, pas un second timer qui pourrait
deriver) : l'intention d'approche est effacee, l'ours est repose au sol au
point d'approche -- **calcule a travers le ROOT et jamais le pivot**, qui
reste incline a l'angle ou le rock s'est arrete -- et `_bear_pivot` est
libere, donc `_apply_tilt` cesse de l'ecrire. `BEAR_RETURNS_HOME` reste
`false` ; son argumentaire d'origine (« l'approche depasse le rock »)
**disparait avec ce lot** et sa doc est reecrite en consequence : c'est
desormais un choix de game-feel et rien d'autre.

**Re-pump verifie et pas suppose** : `Tween.kill()` n'emet pas `finished`,
donc aucun dismount parasite ; le gate sur `_bear_pivot` fait que le
nouveau tween continue de porter l'ours. Garde defensive ajoutee dans
`_on_seesaw_mounted` : un ours encore assis est repose au sol avant de
repartir -- inatteignable tant qu'un dismount precede tout mount, gardee
parce que l'echec est silencieux (une approche marchee EN L'AIR a hauteur
de siege).

### ETAPE 3 -- `ActorWalkerProbe` ETENDUE, PAS DOUBLEE

PHASE E ajoutee (aucune sonde nouvelle), pilotee sur **`HubWorld.tscn`
livre** et jamais un fixture -- toute la revendication porte sur OU
l'ecriture a lieu, et un stand-in avec sa propre boucle de tilt repondrait
a une autre question. **17 assertions**, dont deux BLIND CHECKS (l'ours a
reellement voyage ; la planche a reellement bouge pendant
l'echantillonnage -- 13,03 deg de swing).

⚠️ **LA PREUVE QUE L'ECRITURE EST DANS `_apply_tilt` ET NULLE PART
AILLEURS** est une observable et pas une relecture :
`HubActorWalker.arrive()` appelle `set_process(false)`, donc **assis,
l'ours n'a AUCUN callback a lui** -- la sonde gate
`not bear.is_processing()`. La seule chose qui peut le deplacer est
l'appel de tilt.

Le suivi est mesure **contre le SIEGE FIXE** et jamais contre un
aller-retour de sa propre position (qui est l'identite, donc zero quel que
soit le retard -- `SeesawProbe` documente avoir paye exactement ca) :
**0,0000000 u au pire sur 20 frames**, orientation **0,0000 rad** au pire.

⚠️ **PIEGE DE SONDE RENCONTRE ET CONSIGNE : le budget etait en TEMPS MUR.**
Tout ce qui est teste ici avance sur `delta`, et sous `--fixed-fps 60` ce
delta vaut 1/60 quel que soit le temps que met le rasteriseur logiciel --
donc une horloge murale mesure le sandbox et pas la marche. Le premier
jet a rapporte **2,41 s pour un trajet qui en avait simule 0,77** et
echouait sur du code correct. Budget en FRAMES depuis. Second piege du
meme run : `seesaw_dismounted` part a la FIN de l'arc de sortie de Keepy,
donc un controle fait a l'instant ou `is_on_seesaw()` bascule lit un ours
encore assis.

**ROUGE AVANT VERT, deux neutralisations distinctes, fichier restaure
byte-identique (`cmp`) apres chacune :**

| neutralisation | rouge obtenu |
|---|---|
| l'appel `_bear_follow_seesaw()` dans `_apply_tilt` | **2 FAIL** -- 0,3346 u de derive sur le siege, 0,3457 apres re-pump |
| `_on_bear_arrived()` (le mount) | **4 FAIL** -- jamais sur la planche, 1,183 u de derive, 2,3875 rad d'orientation |

### VALIDATION

Editeur + templates Godot 4.3-stable installes dans ce sandbox (tailles
verifiees contre le `Content-Length` : 50 276 070 et 1 073 228 327 octets,
aucune troncature). `rm -rf build .godot`, import headless **exit 0,
36 `.scn`**, export Web release **exit 0, 0 erreur GDScript**.

`index.wasm` **35 376 909** octets / md5
**`af4a8fc2925d992348eb30deeeb54360`**, `index.js` md5
**`4e08904b1b7107858246af44b602067b`** -- identiques au fingerprint
permanent de tout lot qui ne touche pas le code moteur.

⚠️ **PIEGE PAYLOAD RE-RENCONTRE, ET IL EST AUTO-INFLIGE PAR L'EXPORTEUR :
un export propre vers `build/web` se contamine LUI-MEME.** Horodatage a
l'appui -- les six `.import` de `build/web/index.*.png` sont crees a
00:50:29, c'est-a-dire **pendant** l'export (import termine a 00:47:50),
donc l'exporteur ecrit ses icones dans `res://` et son propre savepack les
ramasse : **7 lignes `Storing File: res://build`**. `build/` n'etant pas
dans l'`exclude_filter`, un `rm -rf build` prealable ne suffit pas. Mesure
propre obtenue en exportant **hors de `res://`** (`/tmp/webout`) :
**282 lignes `Storing File`, 0 pour `scripts/dev`, `assets_source`,
`docs`, `web/`, `build` ET `firebase.json`**. Ce n'est pas une regression
de ce lot ; c'est le chemin d'export lui-meme.

**Sondes, toutes exit 0 / 0 FAIL** : `ActorWalkerProbe` (PHASE E
comprise), `SeesawProbe`, `ProbeTimeoutAudit` (**60 scenes de sonde**,
chiffre inchange -- ce lot n'ajoute aucune sonde), `AssetContractAudit`,
`DeathModelAudit`, `ChargerShapeProbe`.

⚠️ **INCIDENT D'OUTILLAGE, consigne plutot que tu** : un `rm -rf .godot`
a ete lance pendant que des sondes tournaient encore, puis un import a ete
demarre en parallele d'elles -- exactement le hasard « deux processus
Godot sur le meme `.godot/imported` » que ce fichier documente. Tue par
`pkill -f '[G]odot_v4.3'` (forme crochetee, sinon le motif se matche
lui-meme), arbre nettoye, et toute la sequence rejouee **serialisee**.
Aucun chiffre publie ici ne vient de la passe contaminee.

### RESTE OUVERT -- jugement device, seul juge

1. **Est-ce que l'ours se lit comme un second passager** a l'echelle
   reelle d'un telephone, ou comme un modele pose sur une planche ? Le
   snap de montee (0,8 u lateral, 0,69 u vertical, en une frame) est le
   risque principal du lot -- il n'existe aucune animation de montee dans
   le rig, et aucune sonde ne peut trancher ca.
2. **57,3 % du rock passe a bord** : mesure, mais personne n'a encore vu
   si c'est « il monte, on le voit basculer, il descend » ou « il apparait
   et disparait ».
3. Rien ici n'est un rendu device : llvmpipe sous `xvfb` via le backend
   `opengl3` de BUREAU, contre WebGL2 sous Safari.

### Deploiement staging du lot D (palier 1) -- dette de verification, comblee le 2 septembre 2026

Ce paragraphe manquait au rapport du lot D : il avait ete laisse en dette
plutot qu'invente apres coup. Les chiffres ci-dessous sont releves
maintenant, sur le run reel et sur le service, pas reconstruits de memoire.

CI **run #364** (id `33577556065`, job `100084741695`), branche `staging`,
head_sha `aecfd555a076fdc0dde584546e8e076175a5e916`, **conclusion
`success`** -- cree 00:59:22 UTC, job termine 01:04:00 UTC :
`Import project resources` 01:00:09 -> 01:03:20 (3 min 11 s), **`Export Web
build` 01:03:20 -> 01:03:25**, `Verify export output` 01:03:25,
`Deploy to Vercel [STAGING -- staging]` **succes** 01:03:46 -> 01:03:58,
`[PRODUCTION -- main]` correctement **skipped** (push sur `staging`).

**Verifie SUR LE SERVICE, sur DEUX marqueurs independants** :

| marqueur | valeur servie |
|---|---|
| `CACHE_VERSION` | **`1788311005|4243534` = 01:03:25 UTC** -- tombe exactement sur la fermeture de l'etape `Export Web build` |
| `index.wasm` servi | **35 376 909** octets -- le fingerprint permanent de tout lot qui ne touche pas le code moteur |
| `index.pck` servi | 43 300 688 (marqueur « nouveau build », jamais preuve d'identite) |

⚠️ **Limite dite plutot que maquillee** : le `CACHE_VERSION` a ete lu sur
une reponse **`x-vercel-cache: HIT` avec `age: 17362`** -- ce n'est donc
**PAS** une mesure de fraicheur, seulement une lecture de VALEUR. Elle est
corroboree par son `last-modified` (01:04:15 GMT, coherent avec le
deploiement) et par la lecture d'`index.html`, elle **`MISS` / `age: 0`**,
qui rend `fileSizes {"index.pck":43300688,"index.wasm":35376909}`. La
bascule n'est donc pas prouvee dans les deux sens par une paire de
lectures fraiches, comme le fait la forme la plus forte de ce fichier ;
elle est etablie par la concordance epoch/fenetre d'export plus une
seconde lecture fraiche du meme build.

## LOT E -- LA BALANCOIRE DEVIENT UN SIEGE : le rock cesse de decider quand on descend (2 septembre 2026)

Branche `claude/lot-e-seesaw-persistent-a8dqbh`, partie de `origin/staging`
(`aecfd55`, le lot D merge). Regle n1 verifiee AU DEBUT et par ARBRE :
`origin/main` strict ancetre d'`origin/staging`, **aucune session
concurrente**.

Avant ce lot, un tour de balancoire etait quelque chose que le decor te
FAISAIT toutes les 2,4 s : la fin du tween te rendait au sol, que tu
l'aies demande ou non. Desormais **le siege survit au rock** -- Keepy et
l'ours restent assis, planche a plat, jusqu'a ce qu'un tap AILLEURS les
fasse descendre ; un tap sur la balancoire relance un rock sans que
personne ne remonte.

### ETAPE 0 -- LES QUATRE POINTS DE RECON, LUS DANS LE CODE ET PAS SUPPOSES

| # | question | reponse etablie par lecture |
|---|---|---|
| **a** | qui decide la sortie ? | `HubWorld._mount_seesaw()` connectait `_on_seesaw_rock_finished` en `CONNECT_ONE_SHOT` sur le `finished` du rock -- **c'est le TWEEN qui te descendait**, pas toi |
| **b** | un tap ailleurs pendant `ON_SEESAW` ? | **JETE**. `HubWorld._on_tapped_ground()` : la branche seesaw appelait `_repump_seesaw(point)` et `return`ait, sans aucun chemin de sortie -- ni file, ni destination retenue |
| **c** | `_repump_seesaw` marche-t-il au REPOS ? | **OUI**, et c'est tout le coeur de l'exigence 2 : il n'exige qu'un ride vivant, un pivot valide et un point dans le rayon ; son `old.is_valid()` tolerait deja un tween **termine**. Il ne lui manquait que `_seesaw_ride` qui persiste |
| **d** | reference du « patron bateau » | `BoatMooring.is_available()` / `set_busy()`, consulte par `HubTapInput`, plus le `if _keepy.is_riding(): leave_ride(point, footprints)` d'`_on_tapped_ground` -- **le gate se RETIRE**, donc le tap tombe a travers et DEVIENT l'eject, en gardant sa destination |

⚠️ **PAS D'ESCALADE, ET C'EST VERIFIE PLUTOT QUE PARIE.** La consigne
imposait un STOP si le changement debordait sur la FSM de
`KeepyHopper.gd`. Apres `leave_seesaw(landing)` l'etat est `HOPPING` (ou
`IDLE` sur le chemin degenere), et `hop_to(point)` est **accepte dans les
deux** -- le tap qui fait descendre peut donc porter sa destination sans
qu'un seul octet de `KeepyHopper.gd` bouge. **Diff de ce fichier : VIDE**,
comme les trois autres exiges.

### CE QUI CHANGE, ET LES TROIS PIEGES FERMES AU PASSAGE

**`_on_seesaw_rock_finished` est SUPPRIMEE**, pas neutralisee -- zero
reference restante. `_mount_seesaw` finit desormais sur un commentaire qui
dit pourquoi rien n'est accroche au `finished` : « une balancoire posee,
c'est une planche a plat avec deux passagers dessus ; la seule chose qui
termine un tour est un tap ailleurs ».

**`_leave_seesaw_towards(point)` (nouvelle)** porte la sortie facon
bateau. Elle **TUE** le rock plutot que de le laisser se poser :
`Tween.kill()` n'emet aucun `finished`, donc personne ne l'observe -- et
un tween qui continuerait d'ecrire un tilt par `_apply_tilt` apres le
depart des deux passagers ferait basculer un decor sur lequel plus
personne n'est assis.

**`_repump_seesaw` enregistre son nouveau tween** (`_seesaw_ride["tween"]
= tween`) : sans ca, la sortie tuerait un tween perime et laisserait le
vrai en vol.

**`_on_seesaw_dismounted` gagne un `_seesaw_ride = {}` defensif** en
premiere ligne -- le ride ne doit pas survivre a un demontage, quel que
soit le chemin qui l'a provoque.

**`BEAR_RETURNS_HOME` passe a `true`**, et le risque nomme par la consigne
-- un re-tap pendant que l'ours rentre -- est **verifie plutot que
suppose** : `HubActorWalker.walk_to` remplace simplement sa cible et reste
`WALKING`, sans rien emettre pour la marche qu'il abandonne, et son
handler `arrived` sort tot sur un `_bear_pending` vide. Il n'existe donc
aucun etat ou un ours a mi-chemin puisse produire un montage fantome.

### ROUGE AVANT VERT : QUATRE NEUTRALISATIONS CIBLEES, CHACUNE REVERTEE BYTE-IDENTIQUE

| ce qui est neutralise | rouge obtenu |
|---|---|
| le siege ne survit pas au rock (timer qui le depose LOIN) | **ActorWalkerProbe 3 FAIL / SeesawProbe 3 FAIL** |
| `_repump_seesaw` -> no-op | **ActorWalkerProbe 8 FAIL / SeesawProbe 2 FAIL** |
| `_leave_seesaw_towards` -> no-op | **ActorWalkerProbe 4 FAIL / SeesawProbe 8 FAIL** |
| `BEAR_RETURNS_HOME = false` | **ActorWalkerProbe 1 FAIL** (« bear walked back to its post (2.682 u) »), **SeesawProbe exit 0** -- correctement insensible |

`cp` + `cmp` apres chaque passe : `HubWorld.gd` restaure **byte-identique**
(md5 `28edba072ed3259fe5f6cd9c7dfac131`) les quatre fois.

⚠️ **TROIS TENTATIVES DE ROUGE ONT ECHOUE AVANT LA BONNE, ET LA CAUSE VAUT
D'ETRE CONSIGNEE.** Deposer Keepy **a sa propre position** pour simuler
« le siege ne survit pas » le fait atterrir au pied du prop -> `hop_landed`
-> `_rock_near` le trouve dans le rayon -> **il REMONTE**, et
l'echantillon deux rocks plus tard le retrouve assis : le rouge visait
donc a cote (« planche laissee a plat », pas « toujours sur la planche »).
Il a fallu le deposer **loin** (`entry["position"] + Vector3(0,0,-20)`)
pour que la neutralisation exerce reellement l'assertion visee. **Une
neutralisation qui produit un rouge n'est pas forcement une neutralisation
qui produit LE rouge qu'on croit.**

### ⚠️ UNE ASSERTION DE `SeesawProbe` A EXPIRE, ET ELLE EST REECRITE PLUTOT QUE TUE

PHASE GATE echouait sur « a landing well outside the radius does not mount
him ». Cause : son BLIND CHECK laisse desormais Keepy **assis** (c'est le
lot), et son helper `_land_at()` teleporte puis emet `hop_landed` -- il ne
peut pas faire descendre quelqu'un de `ON_SEESAW`, et `hop_to` est refuse
dans cet etat. La phase emprunte donc la **sortie livree** (un tap hors du
prop, attendu jusqu'a l'inactivite) et **asserte qu'il en est reellement
descendu** -- sans quoi le refus teste juste apres passerait gratuitement
contre un Keepy reste a bord tout du long.

### VALIDATION

**Perimetre du diff, exact** : `scripts/hub/HubWorld.gd`,
`scripts/dev/ActorWalkerProbe.gd`, `scripts/dev/SeesawProbe.gd`.
**Diff VIDE sur `HubBuilder.gd`, `HubRouter.gd`, `hub_layout.tres` ET
`KeepyHopper.gd`**, verifie par `git diff --stat` sur ces quatre chemins.

`ActorWalkerProbe` gagne **PHASE F** (trois blocs : le siege survit au
rock, le re-tap relance sans remonter, la sortie sur tap ailleurs avec le
retour de l'ours), chainee depuis PHASE E via un contexte partage --
`_phase_e()` rend `{"hub","keepy","bear","entry","pivot","seat","rock_s"}`
et `_ready` fait `await _phase_f(ctx)` (un `await`, pas un appel nu : une
phase qui contient un `await` est une coroutine, piege deja paye deux fois
dans ce depot).

**Six sondes, toutes exit 0 / 0 FAIL** : `ActorWalkerProbe` (PHASE F
comprise), `SeesawProbe` (**59 OK**), `ProbeTimeoutAudit` (**60 scenes de
sonde + 1 `--script`**, chiffre inchange -- ce lot n'ajoute aucune sonde),
`AssetContractAudit` (**10 colliders, pas un deplace**), `DeathModelAudit`,
`ChargerShapeProbe`.

Import headless **exit 0, 36 `.scn`**. Export Web release **exit 0, 0
erreur SCRIPT/Parse**, fait **hors de `res://`** (`/tmp/webout`) pour eviter
l'auto-contamination deja documentee : **282 lignes `Storing File`, 0**
pour `scripts/dev`, `assets_source`, `docs`, `web/`, `build` et
`firebase.json`. `index.wasm` **35 376 909** / md5
**`af4a8fc2925d992348eb30deeeb54360`**, `index.js` md5
**`4e08904b1b7107858246af44b602067b`** -- le fingerprint permanent de tout
lot qui ne touche pas le code moteur, coherent avec un diff de trois
fichiers GDScript. `index.pck` 43 300 768, **marqueur et jamais preuve
d'identite**.

### RESTE OUVERT -- jugement device, seul juge

1. **Est-ce que rester assis se lit comme un choix** plutot que comme une
   balancoire qui a oublie de te reposer ? La planche revient a plat et
   personne ne bouge tant qu'on ne tape pas ailleurs -- aucune sonde ne
   dit si ce repos se lit comme volontaire.
2. **Le re-tap relance-t-il proprement** au pouce, sans a-coup de
   remontee visible ?
3. **L'ours qui rentre a pied vers (0,0,37)** apres une sortie : mesure et
   gate, jamais vu en mouvement sur un telephone.
4. Rien ici n'est un rendu device : llvmpipe sous `xvfb` via le backend
   `opengl3` de BUREAU, contre WebGL2 sous Safari.

### Deploiement staging du lot E (palier 1, automatique)

`staging` **`cdba3d7`** (merge `--no-ff` de `05a1457`, arbre **byte-identique**
a la branche feature : meme hash d'arbre `3a4ba265` des deux cotes ET
`git diff --stat` vide, verifie AVANT le push). CI run **#365**
(id `33596862403`, job `100141957694`, head_sha
`cdba3d79915212d37627949cf11dc4094b205640`) **verte** -- `Import project
resources` 05:59:16 -> 06:02:51 (3 min 35 s), **`Export Web build`
06:02:51 -> 06:02:57**, `Verify export output` succes, `Upload web build
artifact` succes, `Deploy to Vercel [STAGING -- staging]` **succes**
06:03:15 -> 06:03:27, `[PRODUCTION -- main]` correctement **skipped**.
Run complete 06:03:30. **`main` NON touche** (`origin/main` toujours
`215e6d4`, verifie apres le push).

**Verifie SUR LE SERVICE, pas dans le log CI, sur DEUX marqueurs
independants, et les DEUX lectures d'apres portent `x-vercel-cache: MISS`
avec `age: 0`** :

| marqueur | avant (run #364) | apres (ce lot, run #365) |
|---|---|---|
| `CACHE_VERSION` | `1788311005` = **01:03:25 UTC** | **`1788328976` = 06:02:56 UTC** |
| `index.pck` servi | 43 300 688 | **43 300 768** |
| `index.wasm` servi | 35 376 909 | **35 376 909** *(inchange, attendu)* |

L'epoch d'apres tombe **a l'interieur de la fenetre `Export Web build`**
(06:02:51 -> 06:02:57), `last-modified` colle a l'instant de la requete --
l'alias sert bien ce build.

⚠️ **Limite dite plutot que sous-entendue** : la valeur AVANT du
`CACHE_VERSION` n'a pas ete relue fraiche dans cette session -- elle est
reprise du paragraphe run #364 juste au-dessus, ou elle avait ete lue sur un
`x-vercel-cache: HIT` a `age 17362`, donc une lecture de VALEUR et pas une
mesure de fraicheur. Ce qui EST prouve directement est que la valeur servie
maintenant tombe exactement dans la fenetre d'export de CE run et est
fraiche des deux cotes.

⚠️ **`index.pck` servi (43 300 768) est identique a l'export local propre de
cette session -- et ce n'est DELIBEREMENT PAS offert comme preuve
d'identite** : sa taille n'est pas stable d'un export a l'autre du meme
commit, et une coincidence n'y change rien. **`index.wasm` reste la preuve
d'identite** (35 376 909, md5 `af4a8fc2925d992348eb30deeeb54360`), au
fingerprint permanent de tout lot qui ne touche pas le code moteur --
coherent avec un diff limite a trois fichiers GDScript.

⚠️ **L'API GitHub Actions n'etait PAS perimee sur ce run**, note dans ce
sens-la : les appels successifs ont rendu de vraies progressions d'etapes
avec de vrais horodatages, et l'import a reellement pris **3 min 35 s**. Le
piege existe ; il ne s'est pas produit ici, et le verifier coute un regard a
l'horloge -- ce qui a d'ailleurs servi une fois de plus dans l'autre sens,
un `sleep` lance en arriere-plan puis relu immediatement ne montrant que
quelques secondes ecoulees la ou une lecture naive aurait conclu a un job
fige.

**Chemin d'acces device** : `https://keepy-staging.vercel.app` (Safari
iPhone, navigation privee -- **jamais la PWA installee**, dont le service
worker peut servir un ancien `CACHE_VERSION`).

## LOT F -- L'OURS AU REPOS TOURNAIT LE DOS A LA BALANCOIRE : `face()` ne tournait que pendant `WALKING`, et `ARRIVED` heritait du dernier pas (2 septembre 2026)

Branche `claude/bear-rest-orientation-*`, commit `eea794e`. **DEUX fichiers**,
45 lignes ajoutees, zero supprimee : `scripts/hub/HubWorld.gd` (+28) et
`scripts/dev/ActorWalkerProbe.gd` (+17). **`KeepyHopper.gd`, `HubBuilder.gd`,
`HubRouter.gd` et `resources/hub/hub_layout.tres` sont BYTE-INTOUCHES**,
verifie par `git show --stat` et pas affirme.

⚠️ **SECTION ECRITE RETROACTIVEMENT PAR LE LOT H (2 septembre 2026)**, meme
trou signale au lot G que pour le lot A. Reconstituee depuis le message de
commit et le diff reel.

### LA CAUSE, LUE DANS LE CODE LIVRE ET PAS DEDUITE DU RAPPORT DEVICE

Retour device : l'ours au repos tourne le dos a la balancoire -- et donc a la
camera, qui ne lacete jamais.

`HubActorWalker.face()` n'etait appele **que pendant `WALKING`** ; l'etat
`ARRIVED` **heritait de l'orientation que le dernier pas de marche avait
laissee**. Sur le chemin du retour a la maison, ce cap est **A L'OPPOSE** de
la balancoire des lors que la marche s'est faite en -Z -- ce qui est
precisement le cas, `BEAR_REST` etant pose derriere elle. Exactement le
symptome rapporte.

⚠️ **Les deux chemins d'arrivee n'etaient PAS symetriques, et c'est ce qui a
rendu le defaut invisible a moitie** : l'approche de la balancoire est
**reecrite dans la meme frame** par `_bear_follow_seesaw()`, donc elle
paraissait juste ; le retour a la maison (`BEAR_RETURNS_HOME`, le seul autre
appelant de `walk_to` sur cet acteur) n'a **rien** qui le reoriente ensuite.
Une garde posee sur un seul des deux cotes d'une paire est une garde qui
manque exactement la ou personne ne regarde -- **la meme famille de defaut que
la porte de la cabane** (`_exit_pending` garde cote lit et pas cote sol) et
que la marche de longueur nulle avant elle.

### LE CORRECTIF : un cap FIXE, derive du fulcrum PUBLIE, pose sur les DEUX arrivees

`HubWorld` derive **une seule fois** `_bear_rest_facing` dans `_setup_bear()`,
depuis le fulcrum que la balancoire publie elle-meme
(`_seesaws[0]["position"] - BEAR_REST`), avec un garde de degenerescence sur
la longueur XZ (`> 1.0e-8`) -- une soustraction de deux points confondus
donnerait un vecteur nul et une rotation indefinie. **Aucun nombre n'est
recopie** : c'est la meme discipline que tout ce fichier applique deja aux
positions publiees (`pond_centre()`, `stream_spine()`, `magpie_local_pose()`).

Puis **un seul `.face()` sur CHACUNE des deux arrivees** : le spawn au
chargement du hub, et la fin de la marche de retour dans `_on_bear_arrived()`
sur la branche `_bear_pending.is_empty()`. **`WALKING` et `ON_SEESAW` sont
intouches** -- ce lot ne change que ce qui se passe une fois immobile.

### ⚠️ MESURE, PAS SUPPOSE : le premier appel ne corrige RIEN, et il est garde quand meme

Rouge-avant-vert applique **aux deux sites separement**, chacun neutralise
puis restaure :

| site neutralise | resultat |
|---|---|
| **spawn** | **AUCUNE regression** -- la rotation identite tombe deja juste |
| **retour a la maison** | **le bug rapporte, reproduit exactement** : yaw **-2,601 rad** contre **0,000** voulu |

La raison pour laquelle le spawn passe deja : `HubActorWalker._ready()` lit
`_yaw` sur `rotation.y`, qui vaut **0 par defaut** sur un noeud fraichement
construit -- et 0 EST le bon cap ici, **parce que `BEAR_REST` est pose
derriere la balancoire sur son propre Z local**, si bien que « faire face a la
balancoire » et « faire face a la camera » sont la meme direction.

⚠️ **C'est une COINCIDENCE DU DEFAUT, pas un fait que ce fichier asserte
ailleurs.** Laisser cette justesse implicite serait la laisser dependre d'une
valeur par defaut du moteur et d'un placement de layout qu'une entree de
`hub_layout.tres` peut deplacer sans que personne relise ce code. **Les deux
sites sont donc gardes** ; le second est celui qui porte reellement le
correctif, et le commentaire du premier dit explicitement pourquoi il est la
alors qu'il ne change rien aujourd'hui.

### La sonde gate les DEUX chemins, pas seulement celui qui etait casse

`ActorWalkerProbe` gagne deux assertions gatees, chacune **verifiee ROUGE
avant vert** contre le code neutralise ci-dessus :

* **PHASE E -- cap au spawn** : le spawn le pose directement, sans marche,
  donc `_arrive()` n'a jamais tourne et **rien d'autre que le snap explicite
  de `_setup_bear()` n'a pu l'orienter**. Cap attendu recalcule sur place
  depuis le fulcrum reel (`atan2(dx, dz)`), tolerance 0,01 rad.
* **PHASE F -- cap apres le retour a la maison** : meme derivation, apres la
  marche complete depuis la balancoire.

Les deux comparent via `angle_difference()` plutot que par soustraction brute
-- un ecart de cap ne se mesure pas modulo rien.

### Reste ouvert -- jugement device, seul juge

Est-ce que l'ours au repos se lit desormais comme **tourne vers la
balancoire** a l'echelle reelle d'un telephone ? Le yaw est mesure et gate ;
la lecture ne l'est pas. Et rien ici n'est un rendu device : llvmpipe sous
`xvfb` via le backend `opengl3` de BUREAU, contre WebGL2 sous Safari.

## LOT J -- VERIFICATION DU LOT F : le code EXISTE, il est CORRECT, et l'assertion qui le gate est REELLEMENT PORTEUSE (2 septembre 2026)

Branche `claude/lot-j-bear-rest-orientation-70xep5`, partie de `staging`
(`cb557d4`). **AUCUN fichier de jeu, aucun fichier de sonde touche** : le seul
diff de ce lot est cette section. `git status` verifie vide avant et apres les
manipulations decrites plus bas.

⚠️ **LE LOT J EXISTE PARCE QUE LE LOT F N'AVAIT JAMAIS ETE VERIFIE.** Sa
section a ete ecrite **retroactivement** par le lot H, depuis un message de
commit et un diff -- pas depuis une execution. Deux sessions paralleles ont
ensuite tente de le refaire, chacune supposant qu'il restait a coder. Ce lot ne
suppose rien : il relit le code livre, puis **rejoue le rouge-avant-vert
lui-meme** plutot que de croire une table qu'aucune session vivante n'avait
produite.

### ETAPE 1 -- LE CODE EXISTE, ET IL EST OU LA DOC LE DIT

⚠️ **Le brief demandait de chercher dans `HubActorWalker.gd`. Ce n'est PAS la
qu'il vit** -- et c'est un point utile, parce qu'un futur lecteur qui grepera
le marcheur ne trouvera rien et pourra en conclure a tort que le correctif
n'existe pas. `HubActorWalker.gd` est **byte-intouche** par le lot F ; il porte
seulement le MECANISME du defaut :

* `enum State { IDLE, WALKING, ARRIVED }` (l.34) ;
* le seul site qui ecrit le cap pendant la marche est garde par
  `if dist > arrive_epsilon` dans `_process` (l.221-234) ;
* `_arrive()` (l.245-249) fait `_state = ARRIVED`, `set_process(false)`,
  `_freeze()`, `arrived.emit()` -- **et ne touche jamais au yaw**. L'etat
  `ARRIVED` herite donc litteralement du dernier pas, exactement comme la doc
  du lot F le decrit.

Le correctif, lui, vit dans `scripts/hub/HubWorld.gd`, aux **trois** sites que
la doc annonce, tous presents dans `staging` :

| ligne | contenu |
|---|---|
| **230** | `var _bear_rest_facing: Vector3 = Vector3(0.0, 0.0, 1.0)` |
| **1339-1342** | derivation depuis le fulcrum publie + garde de degenerescence `> 1.0e-8`, puis `_bear.face(_bear_rest_facing)` -- le spawn |
| **1416** | `_bear.face(_bear_rest_facing)` sur la branche `_bear_pending.is_empty()` de `_on_bear_arrived()` -- le retour a la maison |

Commit confirme : `eea794e`, *"fix(hub): the resting bear faces the seesaw, not
away from it"*, **2 fichiers, 45 insertions, 0 suppression**
(`HubWorld.gd` +28, `ActorWalkerProbe.gd` +17) -- le stat exact que la doc
annonce. Il est **ancetre de `staging` depuis trois commits**, les deux
au-dessus (`LOT H`, `LOT I`) etant doc seule.

### ETAPE 2 -- LE ROUGE-AVANT-VERT REJOUE, ET LES DEUX AFFIRMATIONS DE LA DOC TIENNENT

Editeur + templates Godot 4.3-stable installes dans ce sandbox (releases GitHub
officielles, **tailles verifiees contre le `Content-Length`** : 50 276 070 et
1 073 228 327 octets, aucune troncature). Import headless **exit 0, 36 `.scn`,
0 erreur**. `ActorWalkerProbe` sous `xvfb-run --rendering-driver opengl3
--fixed-fps 60` -- jamais `--headless` seul, qui forcerait le driver DUMMY.

**Baseline : 0 echec, exit 0.** Les deux assertions du lot F sont vertes :

```
OK  : on spawn it already faces the seesaw (yaw 0.000 rad, wanted 0.000).
OK  : and settles back facing the seesaw, not away from it (yaw 0.000 rad, wanted 0.000).
```

Puis **chaque site neutralise separement**, `HubWorld.gd` restaure
**byte-identique** (`cmp` silencieux) apres chacun :

| site neutralise | resultat mesure ici |
|---|---|
| **retour a la maison** (l.1416) | **exit 1, 1 FAIL** -- `yaw -2.601 rad, wanted 0.000` |
| **spawn** (l.1342) | **exit 0, 0 FAIL** -- aucune regression |

⚠️ **Le `-2,601 rad` est reproduit INDEPENDAMMENT, au millieme pres, du chiffre
que la doc du lot F annoncait sans l'avoir execute.** C'est ~-149 degres :
l'ours dos a la balancoire, donc dos a une camera qui ne lacete jamais --
exactement le symptome device rapporte. L'assertion de PHASE F est donc
**reellement porteuse**, et le correctif est bien ce qui la fait passer.

⚠️ **Et la seconde affirmation de la doc tient aussi : le snap au SPAWN ne
corrige rien aujourd'hui.** Neutralise, la sonde reste verte. Sa justesse est
une **coincidence de deux faits independants** -- `HubActorWalker._ready()` lit
`_yaw` sur `rotation.y`, nul par defaut, et le layout pose la balancoire a
`(0, 0, 38.5)` pour un `BEAR_REST` a `(0, 0, 37)`, soit `to_fulcrum = (0, 0,
1.5)` et `atan2(0, 1.5) = 0`. **Deplacer l'une des deux entrees en X rendrait
ce site porteur**, et c'est pourquoi il est garde. L'assertion PHASE E, elle,
passe **gratuitement** dans la geometrie actuelle : elle documente une
propriete, elle ne protege rien tant que la balancoire reste plein axe.

### ETAPE 3 -- SANS OBJET : RIEN N'A ETE IMPLEMENTE

L'etape 3 du brief (implementer le correctif minimal) **ne s'est pas
declenchee**. Le diff vide exige sur `KeepyHopper.gd`, `HubBuilder.gd`,
`HubRouter.gd` et `hub_layout.tres` est donc tenu **par construction** : ce lot
ne touche aucun de ces quatre fichiers, ni aucun autre fichier de code.

### VALIDATION

Import headless **exit 0** (36 `.scn`). Export Web release **exit 0, 0 erreur
GDScript ni de parse**. `index.wasm` **35 376 909** octets / md5
**`af4a8fc2925d992348eb30deeeb54360`**, `index.js` md5
**`4e08904b1b7107858246af44b602067b`** -- identiques au fingerprint permanent
deja consigne pour tout lot qui ne touche pas le code moteur, ce qu'un lot
doc-seule est trivialement. **Piege payload tenu** : sur **282** lignes
`Storing File`, **0** pour `scripts/dev`, `assets_source`, `docs`, `web/` ou
`build`.

Sondes : `ActorWalkerProbe` (**0 echec**, les deux assertions du lot F
comprises), `ProbeTimeoutAudit` (**60 sondes scenes + 1 `--script`**, toutes
armees), `AssetContractAudit` (**12/12 visuels, 0/10 colliders deplaces**) --
toutes **exit 0**.

### ⚠️ AUCUN PUSH DE CODE N'ETAIT NECESSAIRE -- le deploiement en place est deja le bon

Verifie **sur le service** plutot que deduit du log CI, en **un seul appel**,
les deux marqueurs de fraicheur dans la meme reponse :

| | valeur |
|---|---|
| `CACHE_VERSION` servi | `1788349460` = **2 sept. 11:44:20 UTC** |
| tip `origin/staging` (`cb557d4`) | **11:39:26 UTC** |
| `x-vercel-cache` | **MISS** |
| `age` | **0** |

Le build servi est date de ~5 minutes apres le commit de tip -- c'est celui du
run declenche par ce push. Le correctif du lot F etant ancetre de ce tip depuis
trois commits (dont deux doc-seule), **le lien de staging expose deja le code a
tester**, et l'etape 2 du brief retient donc explicitement sa branche « sinon
utiliser le deploiement deja en place ».

### LE CHEMIN D'ACCES DEVICE, ET LES DEUX CHOSES A REGARDER

L'ours n'est pas derriere un menu de debug : il est du **gameplay ordinaire du
hub**, pose a `BEAR_REST (0, 0, 37)`, juste derriere la balancoire
`(0, 0, 38.5)`.

```
keepy-staging.vercel.app  ->  le jeu ouvre sur LE HUB
  1. AU CHARGEMENT       -> l'ours est deja au repos derriere la balancoire
                            (site 1 : le spawn)
  2. taper la balancoire -> Keepy s'assied, l'ours marche jusqu'a l'autre
                            bout de la planche et s'y assied
  3. taper AILLEURS      -> Keepy descend, l'ours descend et RENTRE a son
                            poste  (site 2 : LE chemin qui portait le bug)
```

**Ce qu'il faut juger, et c'est le point 3 qui compte** : a la fin de la marche
de retour, **l'ours doit se retourner vers la balancoire** -- donc vers la
camera, puisque les deux directions coincident dans cette geometrie. S'il finit
de dos, le correctif ne tient pas sur device. Le point 1 est un controle
gratuit : il etait deja juste avant le lot F.

`BEAR_RETURNS_HOME` vaut **`true`** dans le code livre -- verifie, pas suppose :
sans quoi l'etape 3 n'existerait pas et il n'y aurait rien a juger.

### Reste ouvert -- jugement device, seul juge

1. **Est-ce que l'ours au repos se lit comme tourne vers la balancoire** a
   l'echelle reelle d'un telephone ? Le yaw est mesure, gate, et son gate est
   desormais **prouve porteur par execution** et plus seulement par un rapport
   ecrit apres coup -- mais un cap juste n'est pas une lecture juste.
2. **La pose figee reste celle du lot C** : il gele sur la premiere frame de
   `Walking`, faute de clip « assis »/« regarde ». Une pose de marche arretee
   tournee vers la balancoire reste une pose de marche arretee.
3. Rien ici n'est un rendu device : llvmpipe sous `xvfb` via le backend
   `opengl3` de BUREAU, contre WebGL2 sous Safari.

## LOT K -- LE BLAIREAU EST RESTAURE : LA JUSTIFICATION "BYTE-IDENTIQUE" DU LOT A N'A JAMAIS ETE CE QU'ELLE NOMMAIT, ET LA MESURE LE CONFIRME (3 septembre 2026)

Branche `claude/badger-restore-716m11`, partie de `main` (`6198492`).
Mathieu a demande de restaurer l'asset blaireau supprime par le LOT A
(commit `c9362a9`) apres avoir tranche en faveur de sa reintegration
malgre son cout de payload -- mais d'abord de VERIFIER que la
justification de suppression tenait, plutot que de la croire sur la foi
du nom de la doctrine invoquee dans le brief.

⚠️ **LE BRIEF CITAIT UNE JUSTIFICATION QUE LE LOT A N'A JAMAIS ECRITE.**
Relu avant toute manipulation : le LOT A (section ci-dessus, ligne ~53)
ne dit a aucun moment que le blaireau etait byte-identique a l'ours. Il
dit exactement l'inverse -- un rendu offscreen a cinq angles a etabli que
c'etait un **animal visuellement distinct** (museau blanc a bandes
noires, corps gris, gilet rapiece, contre l'ourson brun a casquette) --
et la seule byte-identite mesuree la etait **entre les deux copies du
blaireau lui-meme** (`animated/` et `perso/`, md5
`dbc6fbcb116a793012c7fe92e0ad2082`, 14 485 536 octets chacune). Le
blaireau a ete supprime parce qu'il n'etait **pas le sujet cherche**
(l'identification portait sur l'ours), jamais parce qu'il dupliquait
l'ours. La formulation "byte-identique a l'ours" du brief est donc une
lecture erronee de la doc, corrigee ici avant qu'elle ne se propage.

### Verification independante, refaite ici plutot que crue sur la doc

Blob recupere depuis `c9362a9^` (avant suppression), les deux copies
`assets_source/openworld/{animated,perso}/Meshy_AI_Meshy_Merged_Animations.glb`
-- sha256 des deux copies **identique**
(`303988a22596d3328302d47c031262c38908a5c610d0068403b496563afb17bf`),
confirmant le md5 deja publie par le LOT A. Compare ensuite au fichier
ours actuellement dans le depot
(`assets/models/keepy_bear_walker.glb`, 10 408 936 octets, sha256
`86e315653df7d144ea77ccddba5691b2b7f8bf004e0c0a8b0e5948b252c0ae58`) :
**tailles differentes (14 485 536 contre 10 408 936 octets) et sha256
differents** -- `cmp` confirme un octet de divergence des la position 9.
**Ce sont deux fichiers distincts.** Aucune erreur d'export Meshy n'a
jamais fait du blaireau une copie de l'ours ; c'est un vrai modele
distinct qui existait dans l'historique et qui a ete efface par exces de
zele du LOT A plutot que par une decouverte de doublon.

### Confirmation visuelle, refaite -- pas simplement recopiee du LOT A

Godot 4.3-stable telecharge (50 276 070 octets, taille verifiee contre
`Content-Length` avant extraction -- le piege de telechargement tronque
documente plus haut dans `CLAUDE.md`), projet importe en entier
(`--headless --path . --import`, execute deux fois : la premiere passe
n'avait pas encore vu le fichier restaure, depose apres le debut du
scan), puis rendu offscreen a quatre azimuts (0/90/180/270, dedie a ce
lot, camera fixe a 2,2 u, lumiere directionnelle -- l'asset source brut
ne porte pas encore l'extension `KHR_materials_unlit`, contrairement aux
`.glb` livres sous `assets/models/`) sous `xvfb-run --rendering-driver
opengl3`, jamais `--headless` seul. Verdict sans ambiguite aux angles
inspectes : museau blanc, deux bandes noires du nez aux oreilles, corps
gris, gilet rapiece a boutons -- exactement la description du LOT A,
**un blaireau et rien d'autre**. Script de rendu jetable, supprime avant
ce commit conformement a la doctrine (sonde jetable = supprimee avant le
commit) ; seules les captures PNG ont ete inspectees puis jetees.

### Restauration -- une seule copie, pas les deux

Restaure sous `assets_source/openworld/animated/keepy_badger_walker.glb`
(convention de nommage alignee sur `keepy_bear_walker.glb`, meme
dossier). **Une seule des deux copies byte-identiques** est restauree --
restaurer les deux recreerait exactement le doublon de 14,5 Mo que le
LOT A avait deja identifie et a bon droit signale comme source morte.

### Impact `.pck` -- mesure, pas suppose : ZERO, parce qu'il n'y a aucune integration

`export_presets.cfg` exclut `assets_source/*` du pack (ligne 39,
`exclude_filter`), et aucun fichier `.gd`/`.tscn`/`.tres` du depot ne
reference `keepy_badger_walker` -- verifie par grep sur l'arbre entier
avant ce commit. **Le blaireau restaure est donc hors du pack livre**,
exactement comme le LOT A l'avait laisse pour `keepy_bear_walker.glb`
avant son integration par le LOT B. Le seul cout reel aujourd'hui est la
taille du DEPOT source : **+14 485 536 octets (~13,8 MiB)** sur
`assets_source/`. Le cout `.pck` ne s'appliquera que le jour ou un lot
d'integration future (sur le modele du LOT B pour l'ours) referencera cet
asset depuis une scene -- a mesurer alors, pas maintenant. Le trade-off
tranche par Mathieu (blaireau restaure malgre le cout payload) reste
donc, pour l'instant, un cout purement source-side et non un cout de
telechargement joueur.

### Reste ouvert

Aucune integration gameplay -- comme pour l'ours au LOT A, c'est un lot
d'identification et de restauration seul. Un futur lot d'integration
devra, comme les lots suivants pour l'ours, verifier par ARBRE que cet
asset existe bien sur sa propre base avant de le nommer dans un brief.
