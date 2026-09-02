# Cabane et navigation multi-niveaux

> Extrait de `CLAUDE.md` par le LOT H (2 septembre 2026), **verbatim** : aucune ligne réécrite, résumée ni supprimée.
> 13 section(s), 3020 lignes d'origine.
> Doctrine permanente : voir `CLAUDE.md`. Index des chantiers : `docs/lots/INDEX.md`.

## LA CABANE : premier prop ou Keepy DISPARAIT, et le gate copie le BATEAU et non l'echelle (28 aout 2026)

Branche `claude/keepy-cabin-install-u5gk87`, partie de `staging`
(`06f5b39`). Regle n°1 verifiee AU DEBUT : `git fetch --all --prune`, tri
des refs par date et comparaison des **ARBRES** -- les deux branches plus
recentes que `main` (`keepy-debug-coords`, `keepy-cabin-debug-markers`)
sont deja ancetres de `origin/staging`, **aucune session concurrente**.

⚠️ **DEROGATION DE BRANCHE, SIGNALEE** : le brief nommait
`claude/keepy-cabin-install` ; la contrainte d'environnement de cette
session imposait `claude/keepy-cabin-install-u5gk87` et interdisait tout
push ailleurs. Meme arbitrage que les lots precedents ou les deux se sont
contredits -- le nom designe l'emporte, et l'ecart est dit plutot que tu.

`assets/models/keepy_cabin_decor.glb` sur une entree `&"cabin"` a
**(-17,43 ; 28,18)**, echelle 1,0, `rotation_y` 0. Un tap sur le pas de la
porte l'y amene et le fait entrer ; **il disparait sur place**, et
n'importe quel tap ensuite le fait ressortir a l'endroit exact ou il a
disparu. Aucune derogation mono-altitude : il ne quitte jamais y = 0.

### La chirurgie du `.glb` : losslessness prouvee AVANT, strip prouve APRES

Meme methode que le hibou, executee cette fois plutot qu'heritee, et dans
l'ordre que le brief impose :

| passe | resultat |
|---|---|
| **reecriture verbatim** | chunk BIN **byte-identique** (md5 `7222e5fa6f3498d10888839b9c2da185`), JSON semantiquement identique, et fichier de sortie a **exactement 23 198 240 octets**, la taille de la source |
| **+ `KHR_materials_unlit`** | BIN **encore byte-identique** ; `used`, jamais `required`, comme le hibou et le poursuivant |
| **- metallicRoughness** | prefixe BIN conserve **byte-identique** -- son bufferView etait le DERNIER, donc une pure troncature |

⚠️ **Le retrait n'est pas argumente, il est MESURE sur des pixels** : le
materiau unlit a ete rendu a **quatre azimuts** sous `xvfb`
(`--rendering-driver opengl3`) avec et sans la map, et **les quatre paires
de PNG sont BYTE-IDENTIQUES**. Le mecanisme derriere ce zero est
l'importeur glTF de Godot lui-meme, verifie a part : sur un materiau
UNLIT il ne lie **jamais** `metallic_texture` ni `roughness_texture` --
les deux lisent `null` des l'import, donc la map 4096x4096 ne pouvait
atteindre aucun pixel.

**23 198 320 -> 13 756 932 octets, soit 9 441 388 economises (40,7 %)**,
et aucun sidecar metallicRoughness n'est plus genere a l'import.

### ⚠️ ET LA MEME MESURE TROUVE 8,6 Mo DE PLUS, NON RETIRES -- decision de Mathieu

Le brief scopait le strip a la seule map metallicRoughness. En verifiant le
materiau reellement DESSINE, la meme lecture donne
**`normal_tex null = true`, `normal_enabled = false`** : la normal map ne
peut pas davantage atteindre un pixel sur une surface unshaded.

Son `.ctex` pese **8 619 000 octets** -- **le plus gros contributeur
unique du lot**, plus lourd que la baseColor (6 455 000). La retirer
economiserait plus de la moitie du cout de la cabane, avec exactement la
meme structure de preuve.

**NON FAIT, deliberement** : c'est hors du perimetre demande, et
`keepy_owl_decor.glb` **embarque la sienne** dans les memes conditions --
le precedent dit de la garder. Le chiffre est publie pour que Mathieu
tranche, comme le lot hibou avait publie le sien.

### ⚠️ LE `.pck` PLUS QUE DOUBLE, et c'est le vrai cout de ce lot

Mesure des DEUX cotes **dans la meme session**, exports uniques et propres
(`build/` et `.godot/` supprimes avant), la seule comparaison que ce
fichier autorise :

| | `index.pck` | `index.wasm` |
|---|---|---|
| baseline (`origin/staging`, worktree separe) | **14 798 736** | 35 376 909 |
| ce lot | **30 228 432** | 35 376 909 |
| delta | **+15 429 696 (+104,3 %)** | **0** |

Le delta se decompose **a 3 947 octets pres** : `.scn` 351 749 + baseColor
`.ctex` 6 455 000 + normal `.ctex` 8 619 000 = 15 425 749, le reste etant
les quelques ecritures GDScript et l'entree de layout. `index.wasm`
identique au bit pres (md5 `af4a8fc2925d992348eb30deeeb54360`), `index.js`
md5 `4e08904b1b7107858246af44b602067b` -- le fingerprint permanent de tout
lot qui ne touche pas le code moteur.

⚠️ **Piege payload rencontre et evite** : un premier export a rendu **7**
lignes `Storing File: res://build` -- l'auto-contamination deja consignee
(un second export sans `rm -rf build` reimporte les PNG que le PREMIER
avait ecrits). Refait proprement : **0** pour `assets_source`,
`scripts/dev`, `docs`, `web`, `build` et `firebase.json` sur 253 lignes.

### `rotation_y = 0` est MESURE, pas laisse par defaut

Le modele a ete rendu sur quatre axes avant qu'une ligne soit ecrite :
**depuis +Z le tronc est evide et meuble** -- un lit, des etageres, une
enseigne suspendue, des marches au pied -- **et depuis -Z c'est un tronc
ferme sans ouverture**. `HubCamera` ne lacete jamais et regarde toujours
-Z, donc un prop n'est jamais vu que de son cote +Z : zero est la seule
rotation qui montre l'interieur meuble plutot que de l'ecorce.

La cabane etant a z = +28,18, elle se decouvre **en redescendant du lobe
nord** -- la meme propriete « structurellement derriere le spawn » deja
consignee pour le lobe et la balancoire, et la trajectoire contre laquelle
le placement a ete arbitre.

`CABIN_MODEL_OFFSET` est lu sur l'accesseur POSITION du `.glb` livre
(min.y = **-0,800420**) et non suppose d'un modele centre -- l'origine d'un
`.glb` est la ou son auteur l'a laissee, la lecon du rondin JUMP.
`CABIN_FOOTPRINT_RADIUS` est le rayon circonscrit **mesure** (1,228043)
arrondi **vers le haut** a 1,25 : arrondir vers le bas l'empreinte d'un
volume plein est la direction qui fait passer un rocher a travers un mur.

Le pas de la porte est **derive dans `_build`** depuis la meme position et
la meme rotation qui ont place le prop, puis publie sur le registre --
jamais ecrit dans le layout comme une seconde coordonnee : deux nombres
pour une porte, c'est comme ca qu'une porte finit derriere une cabane que
quelqu'un a tournee. Le registre est une **LISTE des le premier commit**,
la lecon du plongeoir payee d'avance.

### ⚠️ LE GATE EST CELUI DU BATEAU, ET CE N'EST PAS UNE HABITUDE ICI

`cabin_available` est la retraite de la mooring sous forme de drapeau : le
pas de la porte **cesse d'accepter les taps pour toute la visite**, donc le
tap suivant retombe sur `tapped_ground` et **DEVIENT la sortie** --
exactement comme un tap pendant une navigation devient l'eject.

Copier l'ECHELLE aurait ete le bug : elle emet `tapped_ladder` quoi que
fasse Keepy et `HubWorld` le jette, ce qui est inoffensif pour une planche
dont le seul autre sens est un plongeon deja traite par etat, et qui
laisserait ici un joueur **A L'INTERIEUR d'un prop qui avale chacun de ses
taps, sans aucune sortie**.

**Ce n'est pas un argument, c'est mesure** : neutraliser la retraite fait
partir la sonde en rouge sur **3 assertions**, dont *« un tap ON THE
DOORSTEP a termine la visite »* qui echoue avec Keepy **toujours dedans
240 frames plus tard**.

**N'IMPORTE QUEL tap le fait ressortir, et c'est deliberement plus permissif
que le tourniquet ou la balancoire** : ceux-la peuvent exiger un tap sur
eux-memes parce que le joueur les voit ; **la cabane ne le peut pas**, il
est invisible dedans et n'a rien a viser. Le point reste **jete** et jamais
mis en file : il peut dire que le joueur voulait quelque chose, il ne doit
jamais devenir un endroit ou marcher depuis l'interieur d'un arbre.

### `IN_CABIN` est le plus petit etat de ride de l'ecran

Rien ne le porte : **aucun `follow_*()`**, rien qui ecrive son transform
par frame, et **aucun `_ride_exit_point`** -- la sortie est l'entree, et
cet endroit est du sol sur lequel il avait deja atterri. Ce que l'etat
achete n'est pas du mouvement mais de la **propriete** : `hop_to()` refuse
deja depuis tout etat autre qu'immobile, aucun atterrissage n'est emis, et
les quatre gardes « aucun atterrissage » de `_on_hop_landed` deviennent
cinq.

⚠️ **Aucun latch `_dismount_pending`, et pour une fois c'est structurel
plutot qu'une exception** : sortir n'emet **AUCUN atterrissage**, donc il
n'y a rien a re-declencher -- contrairement a chaque dismount qui
redescend en hop ordinaire. L'animation est une esquive : il se tourne
vers la porte, se ramasse a 25 % de son echelle en 0,30 s, puis le corps
est **cache** (`_body.visible`, pas le hopper -- la camera suit le hopper,
et une camera qui perdrait sa cible le temps d'une disparition sauterait
ailleurs puis reviendrait).

### `CabinProbe` : 42 checks, 0 echec, GATEE et verifiee ROUGE d'abord

Gatee parce que **tout mode de panne est SILENCIEUX** : scene non
assignee avalee par un `push_error`, modele flottant ou enfonce, porte
derivee du cote ferme du tronc, signal de tap qui continue de tirer. Aucun
ne leve ; tous ressemblent a « la cabane n'a jamais ete installee ».

| cassure deliberee | resultat |
|---|---|
| hook d'entree neutralise | **1 FAIL** -- il marche jusque-la et rien ne se passe |
| retraite neutralisee (patron echelle) | **3 FAIL** -- dont Keepy toujours dedans a 240 frames |

⚠️ **DEFAUT TROUVE DANS MA PROPRE SONDE, publie plutot que lisse.** La
premiere PHASE D appelait `_on_tapped_ground` **directement**, et elle est
donc restee VERTE sous le patron echelle qu'elle existe pour ecarter --
elle ne testait que le drapeau, jamais le ROUTAGE, qui est precisement ce
que la retraite decide. Reecrite pour piloter le **`HubTapInput._handle_point`
LIVRE** via un point d'ecran projete (donc `xvfb`, jamais `--headless`),
elle attrape les trois echecs ci-dessus. PHASE D porte aussi un **BLIND
CHECK** (« il est de nouveau visible » passe gratuitement contre un corps
jamais cache) et PHASE E le fait rentrer **une seconde fois**, ce qui
prouve que la premiere visite n'a laisse ni retraite non restauree ni tween
non nettoye.

### L'overlay de debug est supprime DANS CE LOT

`scripts/hub/debug/KeepyCoordsOverlay.gd`, sa constante
`KEEPY_COORDS_DEBUG_ENABLED` et son site d'appel : partis. Son propre
en-tete l'exigeait -- il existait pour lire la coordonnee que ce lot
installe, et **rien qui le porte ne doit atteindre `main`**.

### Validation

Editeur + templates Godot 4.3-stable installes dans ce sandbox (releases
GitHub officielles, **tailles verifiees contre le `Content-Length`** :
50 276 070 et 1 073 228 327 octets, aucune troncature). Import headless
**exit 0** ; boot de `HubWorld.tscn` **exit 0, 0 erreur, 0 `push_warning`**
-- la confirmation A L'EXECUTION que les 217 entrees restent coherentes ;
export Web release **exit 0, 0 erreur**.

**Sondes, toutes exit 0** : `CabinProbe` (**42/42**), `ProbeTimeoutAudit`
(**58 sondes scenes**, 57 en baseline, le +1 etant `CabinProbe`),
`AssetContractAudit` (**12/12 visuels, 0/10 colliders deplaces**),
`DeathModelAudit`, `ChargerShapeProbe`, `OwlProbe`, `OwlFlightProbe`,
`DivingBoardProbe`, `WaterImpactProbe`, `WaterTintProbe`, `SeesawProbe`,
`LakeZoneProbe` et `StreamRideProbe` (**37/37**, sous `xvfb` et au budget
complet du watchdog -- ce dernier est d'ailleurs VERT ici, alors que ce
fichier le consigne ailleurs comme portant deux echecs pre-existants).

⚠️ **`TurnstileProbe` sort en 1, sur son echec UNIQUE et PRE-EXISTANT**
(`entry 0's custom_aabb encloses every bar`), deja consigne comme tel dans
ce fichier et non aggrave par ce lot.

⚠️ **Piege `--fixed-fps` re-rencontre, et il a produit un faux rouge.**
`SeesawProbe` lancee sans le flag rapporte la diagonale a **45,033 s** et
part en rouge sur deux assertions. Avec `--fixed-fps 60` elle rend
**18,700 s** -- la valeur deja publiee -- et **0 echec**. Le budget de
draw nodes partage passe de **128 a 129**, itemise dans les trois en-tetes
qui le portent (`SeesawProbe`, `TurnstileProbe`, `WaterTintProbe`) plutot
que pousse : une constante de budget qui derive en silence est un budget
que personne ne surveille.

**Rendu reel capture** (1080x1920, `xvfb` + `opengl3`) : la cabane est
posee au sol au bon endroit, face ouverte vers la camera, l'interieur
meuble lisible.

### Reste ouvert -- jugement device, seul juge

1. ⚠️ **L'ECHELLE EST LA VRAIE QUESTION.** A 1,0 la cabane fait **1,59 de
   haut contre un Keepy de 1,35** : sur le rendu il se lit presque aussi
   grand que la maison, et son ouverture est plus petite que lui. L'echelle
   etait **fixee par la recon avec un verdict GO et n'a PAS ete
   re-arbitree** -- mais elle est mesuree, et c'est le premier chiffre a
   regarder sur device.
2. **La normal map, 8 619 000 octets prouves morts** (section dediee) --
   plus de la moitie du cout du lot, non retiree parce que hors perimetre
   et contre le precedent du hibou.
3. **Le `.pck` double** (14,8 -> 30,2 Mo) sur un jeu web mobile. Mesure,
   decompose, non corrige.
4. **L'anim d'entree est un placeholder assume** : il se ramasse et
   disparait. Le gag « sieste » que le brief evoque reste a affiner sur
   rendu reel, et c'etait le perimetre.
5. **La cabane n'est pas visible depuis le spawn** (z = +28,18, camera qui
   ne lacete jamais) -- comme la moitie des props du plateau.

### Deploiement staging de la cabane (palier 1, automatique)

`staging` **`4ca3778`** (merge `--no-ff` `c2077fb`, arbre **byte-identique** a
la branche feature, verifie AVANT le push ; le commit de doc au-dessus n'ajoute
aucune ressource Godot). CI run **#308** (id 33218098447) **verte** --
`Import project resources` 22:48:16 -> 22:51:32, **`Export Web build`
22:51:32 -> 22:51:36**, `Deploy to Vercel [STAGING -- staging]` **succes**
22:51:57 -> 22:52:10, `[PRODUCTION -- main]` correctement **skipped**.
**`main` NON touche** (`origin/main` toujours `9031e5e`, verifie apres le
push) : palier 2, gate Mathieu apres validation device.

**Verifie SUR LE SERVICE, pas dans le log CI, sur DEUX marqueurs
independants** :

| marqueur | avant | apres (ce lot, run #308) |
|---|---|---|
| `CACHE_VERSION` | `1787953320` = **21:42:00 UTC** (run #306) | **`1787957495` = 22:51:35 UTC** |
| `index.pck` servi | -- | **30 228 432** |
| `index.wasm` servi | -- | **35 376 909** |

L'epoch d'apres tombe **a l'interieur de la fenetre `Export Web build`**
(22:51:32 -> 22:51:36), et les DEUX lectures d'apres portent
**`x-vercel-cache: MISS` avec `age: 0`**, `last-modified` colle a l'instant de
la requete. `index.wasm` servi est **identique au bit pres a l'export local**
(md5 `af4a8fc2925d992348eb30deeeb54360`) -- c'est lui la preuve d'identite.

⚠️ **Limites dites plutot que sous-entendues, deux fois.** (1) La valeur AVANT
n'existe que pour le `CACHE_VERSION`, et elle a ete lue sur un `HIT` a
`age 4079` : valable comme VALEUR (elle precede le push, c'est bien l'ancien
build), **pas une mesure de fraicheur**. (2) `index.pck`/`index.wasm` n'ont ete
lus qu'APRES, donc ils valent comme second marqueur d'ETAT COURANT, pas comme
preuve de transition.

⚠️ **Le piege HIT/age s'est reproduit et a ete REFUSE** : une lecture
cache-bustee par parametre de requete (`?probe=...`) est revenue `HIT` avec
`age 4079` -- **le parametre ne buste pas ce cache de bord**, comportement deja
consigne. Seule la lecture MISS/age 0 d'apres compte.

⚠️ **Pour une fois `index.pck` servi et export local sont EGAUX** (30 228 432
des deux cotes) -- ca reste un marqueur « nouveau build servi » et **jamais**
une preuve d'identite : l'instabilite de compression VRAM entre deux exports du
meme commit est documentee, et une coincidence ne la contredit pas.

⚠️ **Le run #307 (le merge du code) est `cancelled`, et ce n'est PAS un
echec** : le push du commit de doc a declenche #308, qui a tue #307 via
`cancel-in-progress: true`. #308 construit le MEME arbre plus `CLAUDE.md`, qui
n'est pas une ressource Godot -- le contenu de jeu deploye est bien celui du
lot. Piege deja consigne, reproduit ici.

## LA CABANE GRANDIT : echelle 3,5, la porte devient plus grande que Keepy -- AUCUN rocher n'etait en collision, MESURE et pas suppose (29 aout 2026)

Branche `claude/keepy-cabin-scale-up`, partie de `staging` (`e5b1160`).
Regle n°1 verifiee AU DEBUT : `git fetch --all --prune`, tri des refs
distantes par date -- `origin/staging` est la ref la plus recente du depot,
`origin/main` (`9031e5e`) strictement en retard, **aucune session
concurrente**. Position de la cabane **INCHANGEE**
`(-17,43 ; 0 ; 28,18)` -- seule l'echelle bouge.

Retour du lot precedent, qui avait fixe l'echelle a 1,0 avec un verdict GO
mais l'avait publiee comme « la vraie question » : a 1,0 la cabane faisait
1,59 de haut contre un Keepy de 1,35, et son ouverture etait **plus petite
que lui**. Ce lot repond a cette question, sans re-arbitrer le placement.

### ⚠️ RECON : ZERO ROCHER, ZERO ARBRE EN COLLISION -- la formule du brief donne un ensemble vide

Le brief anticipait une suppression de rochers genants. **La mesure dit le
contraire.** Layout parse (217 entrees a l'epoque), tous les voisins a
moins de 15 u du centre releves avec leur type, leur position et leur
propre `scale`, puis testes contre la formule exacte du brief --
`distance_centre - footprint_voisin < rayon_cabine`, avec
**rayon_cabine = 1,228043 (circonscrit MESURE, pas le 1,25 arrondi) x
3,5 = 4,298 u** :

| pire cas | type | position | distance | footprint | marge |
|---|---|---|---|---|---|
| **idx 135** | rock | (-19,65 ; 22,47) | 6,126 | 0,437 | **+1,391 (clear)** |
| idx 114 | tree | (-11,92 ; 23,68) | 7,114 | 0,257 | +2,559 (clear) |
| idx 111 | tree | (-18,02 ; 20,96) | 7,244 | 0,212 | +2,733 (clear) |

Balayage refait a 20 u de rayon (pas seulement 15) pour couvrir toute
collision geometriquement possible (rayon cabine + plus grand footprint de
la famille, landmark 1,66) : **aucun nouveau cas**. Meme en substituant la
constante arrondie `CABIN_FOOTPRINT_RADIUS = 1,25` (donc rayon 4,375 au
lieu de 4,298), le pire cas (idx 135) garde une marge de **+1,314 u** --
toujours clair. **Aucune entree n'est retiree du layout.** Le doorstep
(voir plus bas, desormais a z = 33,255) a aussi ete verifie sans voisin a
moins de 5 u. **Aucun conflit d'arbre a signaler non plus** -- rien a
arbitrer.

### `CABIN_DOOR_REACH` ne scalait PAS -- bug latent ferme avant qu'il morde

`CABIN_FOOTPRINT_RADIUS` etait deja correctement mis a l'echelle par
`ground_footprints()` (`FOOTPRINT_RADIUS[type] * uniform`), verifie par
lecture et non suppose. Mais le pas de la porte, lui, etait calcule avec
`CABIN_DOOR_REACH` **litteral**, jamais multiplie par `uniform` :
`var reach := Vector3(0.0, 0.0, CABIN_DOOR_REACH)`. A l'echelle 1,0
c'etait invisible (juste assez au-dela du footprint de 1,25). A 3,5 ca
aurait plante la porte a `z = 28,18 + 1,45 = 29,63`, **soit 3,68 u a
l'interieur du volume desormais circonscrit a 4,3 u** -- un pas de porte
DANS le tronc.

**Corrige a la source** : `reach := Vector3(0.0, 0.0, CABIN_DOOR_REACH *
uniform)`, dans `_build()`, la meme regle que `ground_footprints()` deja
appliquee au footprint. Porte livree : **(-17,43 ; 0 ; 33,255)**
(28,18 + 1,45×3,5 = 33,255), verifiee sur la scene construite par
`CabinProbe` PHASE B au dixieme de millimetre pres, et confirmee ne
recouvrir aucun voisin dans un rayon de 5 u.

### `CabinProbe.gd` : deux hypotheses de taille codees en dur, corrigees plutot que contournees

Deux assertions PHASE B supposaient l'echelle 1,0 explicitement et
auraient echoue sur du code par ailleurs correct :

- **La taille AABB attendue** (`1,8929 x 1,5901`) est devenue
  `1,8929 * _EXPECTED_SCALE` / `1,5901 * _EXPECTED_SCALE` -- une seule
  source (`_EXPECTED_SCALE = 3,5`), jamais un second litteral pour « la
  taille a 3,5 ».
- **Le controle de footprint** (`CABIN_FOOTPRINT_RADIUS >= half`)
  comparait une constante non-scalee au demi-empan d'un mesh CONSTRUIT
  (donc deja mis a l'echelle). Corrige en lisant `root.scale.x` --
  AS-BUILT, la meme discipline que le reste de ce fichier applique deja a
  `pond_centre()`/`islets()` -- plutot que de dupliquer l'entree du
  layout dans la sonde.

`_EXPECTED_POSITION` reste inchangee, `_EXPECTED_DOOR` mise a jour a
`(-17,43 ; 0 ; 33,255)`.

### Rendu offscreen -- la porte est desormais NETTEMENT plus grande que Keepy

Capture jetable (`xvfb-run --rendering-driver opengl3`, supprimee avant
commit), Keepy pose au pas de la porte puis recule de 3 u sur le meme
axe : **l'ouverture voutee de la cabane est plusieurs fois la hauteur de
Keepy**, le mobilier interieur (lit, etageres, table, enseigne suspendue)
reste lisible, et le hibou du lot precedent est visible au fond a droite
-- confirmation visuelle directe que l'inversion « maison plus petite que
son ouverture apparente » du lot precedent est fermee.

### Validation

Editeur + templates Godot 4.3-stable installes dans ce sandbox (releases
GitHub officielles, tailles verifiees contre le `Content-Length` --
50 276 070 et 1 073 228 327 octets, aucune troncature). Import headless
**exit 0** ; boot de `HubWorld.tscn` **exit 0, 0 erreur, 0
`push_warning`** -- la confirmation A L'EXECUTION qu'aucune entree n'est
devenue inatteignable ni en collision ; export Web release **exit 0, 0
erreur**. `index.wasm` **35 376 909 / md5
af4a8fc2925d992348eb30deeeb54360**, `index.js` md5
**4e08904b1b7107858246af44b602067b** -- identiques au fingerprint
permanent de tout lot qui ne touche pas le code moteur, coherent : ce
lot ne change qu'un flottant de layout et deux fichiers GDScript.
`index.pck` **30 228 512** (marqueur, jamais preuve d'identite -- l'ecart
de quelques dizaines d'octets avec le lot precedent est l'instabilite deja
documentee). Piege payload tenu : **0** ligne `Storing File` pour
`scripts/dev`, `assets_source`, `docs`, `web`, `build` ou `firebase.json`
sur 240 lignes.

**Sondes, toutes exit 0** : `CabinProbe` (**42/42**, reproductible au
chiffre pres avec le brief), `AssetContractAudit` (12/12 visuels, 0/10
colliders deplaces), `DeathModelAudit`, `ChargerShapeProbe`, `OwlProbe`,
`OwlFlightProbe`, `DivingBoardProbe`, `WaterImpactProbe`, `WaterTintProbe`,
`SeesawProbe`, `LakeZoneProbe`, `StreamRideProbe` (**37/37**),
`TurnstileProbe` (**0 echec** -- l'echec pre-existant deja consigne pour
cette sonde ne s'est pas reproduit ici). **PHASE UNTOUCHED** de
`CabinProbe` confirme les 3 portails, les 3 planches, l'unique hibou,
tourniquet, balancoire et bateau intacts, et le voisin de tap le plus
proche (la balancoire, 18,20 u) largement hors du rayon de la porte.
`ProbeTimeoutAudit` **exit 0, 58 sondes scenes** -- identique a la
baseline, confirmant qu'aucune sonde jetable n'a fuite dans le commit.
Compte de draw nodes hors portails **inchange sur toutes les sondes qui le
mesurent (129)** : ce lot ne touche a aucune geometrie, seulement a un
facteur d'echelle sur un noeud existant.

### Reste ouvert -- jugement device, seul juge

1. **Est-ce que 3,5 est le bon cran**, ou trop grand maintenant a l'inverse
   -- la mesure dit seulement que la porte franchit desormais la taille de
   Keepy, pas qu'elle est BIEN calibree a l'oeil sur un telephone.
2. Le `.pck` reste a 30,2 Mo (inchange par ce lot -- la geometrie/texture
   de la cabane n'a pas bouge, seul un scalaire de placement). La normal
   map 8,6 Mo signalee comme morte au lot precedent reste non retiree,
   hors perimetre ici aussi.
3. La cabane reste structurellement derriere le spawn (camera qui ne
   lacete jamais) -- inchange.

### Deploiement staging de la cabane agrandie (palier 1, automatique)

`staging` **`c24eb11`** (merge `--no-ff` de `d92c755`, arbre
**byte-identique** a la branche feature, verifie AVANT le push --
`git rev-parse HEAD^{tree}` egal des deux cotes, `8deece46...`). Regle
n°1 revrifiee juste avant le push : `origin/staging` (`e5b1160`) et
`origin/main` (`9031e5e`) inchanges depuis le debut du lot, **aucune
session concurrente**.

CI run **#310** (id 33237025998) **verte** -- `Import project resources`
05:49:35 -> 05:53:38, `Export Web build` **05:53:38 -> 05:53:44**,
`Deploy to Vercel [STAGING -- staging]` **succes** 05:54:01 -> 05:54:13,
`[PRODUCTION -- main]` correctement **skipped**. **`main` NON touche**
(`origin/main` toujours `9031e5e`, verifie apres le push) : palier 2,
gate Mathieu apres validation device.

**Verifie SUR LE SERVICE, pas dans le log CI, sur DEUX marqueurs
independants** :

| marqueur | avant | apres (ce lot, run #310) |
|---|---|---|
| `CACHE_VERSION` | `1787957927` = **22:58:47 UTC (28 aout)** | **`1787982823` = 05:53:43 UTC** |
| `index.pck` servi | -- | **30 228 592** |
| `index.wasm` servi | -- | **35 376 909** |

L'epoch d'apres tombe **exactement dans la fenetre `Export Web build`**
(05:53:38 -> 05:53:44), et les deux lectures d'apres portent
**`x-vercel-cache: MISS` avec `age: 0`**, `last-modified` colle a
l'instant de la requete. `index.wasm` servi est **identique au bit pres
a l'export local** (md5 `af4a8fc2925d992348eb30deeeb54360`) -- c'est lui
la preuve d'identite. `index.pck` **30 228 592** servi contre
**30 228 512** en export local propre -- 80 octets d'ecart, l'instabilite
de compression VRAM deja documentee, jamais offerte comme preuve seule.

⚠️ **Limite dite plutot que sous-entendue** : la valeur AVANT n'existe
que pour le `CACHE_VERSION`, et elle a ete lue avant le push mais sur une
reponse deja `MISS/age 0` -- fraiche au moment de la lecture, et
suffisamment anterieure au push (plusieurs heures) pour ne laisser aucune
ambiguite sur la transition. `index.pck`/`index.wasm` n'ont ete lus
qu'APRES, donc ils valent comme marqueur d'ETAT COURANT, pas comme
preuve de transition a eux seuls -- c'est le `CACHE_VERSION` qui porte
cette preuve.

## LA CABANE : LE DECLENCHEMENT INTEMPESTIF, ET L'ECHELLE 7,0 (29 aout 2026)

Branche `claude/keepy-cabin-trigger-fix-scaleup-rqj344`, partie de `staging`
(`e53571e`). Regle n°1 verifiee AU DEBUT : `git fetch --all --prune`, tri des
refs par date et comparaison des **ARBRES** -- `claude/keepy-cabin-scale-up`
est deja ancetre de `origin/staging`, **aucune session concurrente**.
`origin/main` = `9031e5e`, **INTOUCHE**.

**DEUX lots dans une branche, DEUX commits atomiques**, le fix avant
l'agrandissement -- parce que le fix devait tenir a N'IMPORTE QUELLE echelle
pour que le second lot soit sur, et c'est exactement ce qu'il fallait
prouver avant de doubler la taille du prop.

### ⚠️ PARTIE A -- LES DEUX HYPOTHESES DU BRIEF SONT FAUSSES, ET LES DEUX SONT REFUTEES PAR MESURE

Retour device : Keepy « disparait / se fait aspirer par le bas » en
s'approchant simplement de la cabane, sans tap volontaire dessus. Le brief
proposait deux causes ; aucune ne survit a la lecture du code.

**H1 -- « un rayon de declenchement devenu trop large en scalant 1:1 avec la
taille visuelle ». FAUX.** `CABIN_TAP_RADIUS` est un `const` de
`HubWorld.gd` valant **2,2**, et il n'est multiplie par rien, nulle part --
`grep` sur ses quatre sites d'usage. Il n'a jamais scale avec le modele.

**H2 -- « un declenchement par PROXIMITE pure, sans tap ». FAUX, et mesure
plutot que deduit.** `_try_enter_cabin` n'est atteignable que derriere
`if _entering`, et `_entering` n'est arme que par `_on_tapped_cabin`. Sonde :
Keepy pose **exactement sur le seuil**, `_entering = false`, un `hop_landed`
emis a la main -> `in cabin before=false after=false`. **Un tap est requis.**

### LA CAUSE REELLE : c'est le SEUIL DE PORTE qui a derive, pas le rayon

`CABIN_DOOR_REACH` etait mesure contre `CABIN_FOOTPRINT_RADIUS` (1,25), qui
est le rayon **CIRCONSCRIT** -- le COIN -- alors que le seuil est place le
long de la **FACE**. L'ecart entre les deux vaut **0,469 par unite
d'echelle** : 0,47 u a l'echelle 1, invisible ; **1,64 u a 3,5**.

| | echelle 1,0 | echelle 3,5 |
|---|---|---|
| face avant (AABB construite) | z 28,961 | z **30,913** |
| seuil de porte | z 29,630 | z **33,255** |
| **ecart seuil / mur** | **0,669** | **2,342** |
| **disque de declenchement SUR le batiment** | **18,2 %** | **0,0 %** |
| disque sur la PELOUSE | 12,44 u2 | **15,21 u2 (100 %)** |

⚠️ **C'est ce 18,2 % -> 0,0 % qui EST le rapport device, en un chiffre.** A
l'echelle 1 le disque **HABILLAIT le prop** : « taper la cabane » et « taper
le seuil » etaient le meme geste. A 3,5 il s'en etait **detache** -- une
bande de **4,4 u de pelouse invisible flottant 2,34 u DEVANT le mur**,
mesuree a **473-617 px de large sur un ecran de 1080** (soit jusqu'a 57 % de
la largeur). Le joueur qui tape cette pelouse pour aller regarder la cabane
depense en « entrer » le tap qu'il voulait en « marcher ».

⚠️ **Il n'a donc pas ete ASPIRE, il a ete REPONDU.** Un tap, un signal --
et le signal n'etait pas celui qu'il visait. Le fondu de `enter_cabin`
(`CABIN_DUCK_SCALE` 0,25 puis `visible = false`) est ce qui donne
l'impression d'aspiration ; le defaut est en amont, dans le routage.

**Piste ecartee, mesuree aussi** : un tap vise sur le CORPS VISIBLE de la
cabane (le joueur tape le batiment pour aller le voir) -- le rayon traverse
le mesh (aucun collider) et atterrit sur le plan du sol. **0 % de ces pixels
tombent dans le disque**, aux quatre distances testees. Ce n'etait pas ca.

### LE FIX : le seuil se scinde en DEUX, et une seule moitie scale

```
door = position + rotate( CABIN_DOOR_FACE_DEPTH * scale  +  CABIN_DOOR_STANDOFF )
                          ^--- suit le mur                  ^--- NE SCALE PAS
```

* **`CABIN_DOOR_FACE_DEPTH = 0,78078`** -- la demi-profondeur +Z du modele,
  **mesuree sur l'AABB construite** (2,73274 / 3,5), donc elle suit le mur
  ou qu'il aille.
* **`CABIN_DOOR_STANDOFF = 0,70`** -- le recul d'un VISITEUR, **FIXE, parce
  que KEEPY NE SCALE PAS.** Il fait 1,32 de large quelle que soit la taille
  de la cabane, donc la place dont il a besoin devant une porte est une
  constante et jamais une fraction du batiment.

⚠️ **La paire reproduit le seuil livre a l'echelle 1 a 3 cm pres (1,4808
contre 1,45)** -- le nouveau formalisme est un quasi no-op a l'echelle pour
laquelle l'ancien avait ete calibre, et ne corrige que la derive. C'est le
signe le plus fort que c'est la bonne formulation. **L'ecart au mur devient
un 0,700 plat A TOUTES LES ECHELLES**, et c'est cette invariance que la
sonde gate.

**`CABIN_TAP_RADIUS` 2,2 -> 1,30**, re-documente comme **indexe sur la
PORTE et non sur le BATIMENT**. L'ancien 2,2 etait argumente par « le prop
est plus gros que le hibou » -- un argument sur le VOLUME, la seule grandeur
qu'un seuil ne doit pas suivre : une porte fait la meme taille sur une
cabane et sur une cathedrale, parce que ce qui doit y passer est Keepy.
**1,30 est LU sur le comportement qui MARCHAIT** et non choisi : avec le
seuil desormais tenu a 0,70 du mur, il remet **17,5 %** du disque sur le
batiment -- les 18,2 % de la cabane livree a l'echelle 1. Et il est
**scale-INVARIANT par construction** : les memes 17,5 % a 3,5 et a 7,0.

⚠️ **NOUVEAU : `CABIN_ARRIVE_RADIUS` = tap + `ARRIVE_EPSILON`.** Defaut
LATENT ferme au passage : `_advance()` s'arrete quand le reste est sous
`ARRIVE_EPSILON` (0,45), donc une marche visant un point a R du seuil peut
legalement finir a **R + 0,45**. Tester l'arrivee au R du tap -- ce qu'un
rayon unique partage faisait -- laisse un joueur qui a tape le bord du seuil
y marcher entierement et s'entendre dire qu'il n'y est pas encore, intention
toujours armee. Inoffensif a elargir : ce test n'est consulte qu'une fois
`_entering` deja arme **par un tap delibere**.

### `CabinProbe` PHASE T -- verifiee ROUGE AVANT VERT sur l'arbre livre

Worktree separe sur `origin/staging`, seule la sonde portee : **5 echecs**,
et ils redisent le rapport device mot pour mot --

```
FAIL  the doorstep stands 2.342 u off the front wall (want 0.70, any scale)
FAIL  a walking tap two paces BACK from the door (2.00 u out) stays a walking tap ([&"cabin"])
FAIL  a walking tap one pace to the SIDE of it (2.00 u out) stays a walking tap ([&"cabin"])
FAIL  a walking tap one pace to the OTHER side (2.00 u out) stays a walking tap ([&"cabin"])
FAIL  a walking tap one pace to the side left him OUTDOORS (4 frames)
```

Apres fix : **0 echec**, et la sonde entiere **48 checks / 0 failure**.

Trois disciplines dans cette phase, chacune payee :

1. **Les points sont derives du BATIMENT, jamais du rayon.** Les dimensionner
   sur `CABIN_TAP_RADIUS` ferait passer la phase pour n'importe quel rayon --
   ce serait asserter qu'un cercle est un cercle.
2. **Elle ouvre sur le POSITIF.** « Rien ne s'est declenche » est satisfait
   gratuitement par un seuil jamais cable, donc elle prouve d'abord qu'il
   PEUT tirer -- la discipline de blind check que PHASE D porte deja.
3. ⚠️ **La moitie « signal » tourne avec le handler de `HubWorld`
   DECONNECTE.** Ce qui est teste est QUEL SIGNAL un tap devient ; laisser le
   handler vivant fait entrer Keepy des le blind check et chaque assertion
   suivante mesure les restes de la precedente. **Une premiere version a fait
   exactement ca et a rapporte trois echecs qu'elle s'etait causes.**

### ⚠️ PARTIE B -- LA CIBLE DU BRIEF EST AMBIGUE, ET LES DEUX LECTURES DONNENT UN TRAVAIL DIFFERENT

Mesure sur le monde CONSTRUIT (batches `MultiMesh` parcourus instance par
instance -- lire les seuls `MeshInstance3D` aurait rate **tous** les arbres) :

| | hauteur monde |
|---|---|
| **plus grand arbre BATCHE** (`TreeCrown`, 44 instances) | **3,9330** |
| **plus grande chose EN FORME D'ARBRE** (landmark spire, variante 0 a 1,12) | **9,4640** |
| cabane a l'echelle 3,5 | 5,5653 |

⚠️ **La cabane a 3,5 depassait DEJA le plus grand arbre litteral de 41,5 %.**
La lecture litterale de « plus grand arbre de la foret » voulait donc dire
« ne rien faire » -- ce qu'un lot d'agrandissement ne peut pas demander. La
**spire** est le conifere du plateau (fut brun, trois cones a couronne VERTE,
`LANDMARK_SPIRE_CROWN`), c'est-a-dire la plus haute silhouette d'arbre du
jeu, et la cabane n'en faisait que **59 %**. C'est cette lecture qui est
retenue, et le brief l'anticipait : il prevoit des collisions d'ARBRES a
signaler, ce que la lecture litterale ne pouvait pas produire.

**Deux derivations independantes s'accordent sur 9,4640** : la mesure sur
l'arbre construit, et le calcul depuis les constantes de
`_make_landmark_spire()` (cone haut a 7,55 + 1,8/2 = 8,45, x 1,12).

**Echelle retenue : 7,0** -- toit a **11,1306**, soit **+17,6 %** au-dessus
de la spire (milieu de la bande 15-20 % demandee) et **x2,83** le plus grand
arbre batche. C'est aussi exactement le double de 3,5.

### Quatre rochers retires, trois conflits SIGNALES et non resolus

Balayage `distance_centre - footprint_voisin < rayon_cabine` sur **tous** les
voisins a portee, footprint 8,75 :

| retire (politique tranchee) | position | recouvrement |
|---|---|---|
| rocher | (-19,650 ; 22,470) | **3,061** |
| rocher | (-20,430 ; 21,410) | **1,701** |
| rocher | (-11,390 ; 22,260) | **0,585** |
| rocher | (-16,460 ; 18,920) | **0,034** |

| ⚠️ SIGNALE, NON TOUCHE | position | recouvrement |
|---|---|---|
| **arbre** | (-11,920 ; 23,680) | **1,893** |
| **arbre** | (-18,020 ; 20,960) | **1,718** |
| **souche** | (-19,140 ; 19,240) | **0,109** |

⚠️ **Aucune echelle atteignant la cible ne degage les arbres** : il faudrait
un footprint sous 6,86, soit l'echelle 5,5 et **+0,8 %** seulement. La souche
n'est pas un rocher, donc elle attend avec eux -- une ligne de layout si
Mathieu veut qu'elle parte. Voisin degage le plus proche : un landmark a
**0,253**.

**`ground_footprints()` multiplie deja `CABIN_FOOTPRINT_RADIUS` par le
`scale` de l'entree** -- le footprint a suivi tout seul a 8,75, rien a
re-deriver, rien de re-casse (verifie dans le code, pas suppose).

### ⚠️ CONSEQUENCE MESUREE ET NON RESOLUE : le seuil est a 0,65 u du bord du plateau

A l'echelle 7,0 le seuil tombe a **z = 34,3455** contre une arete nord a
**z = 35,0**. Il reste donc **0,65 u de sol praticable derriere la porte** --
« deux pas en arriere de la porte » n'existe pas comme terrain.

C'est ce qu'une assertion de PHASE T a trouve en echouant sur du code
CORRECT : `_handle_point` clampe a la region **AVANT** de choisir un signal,
donc ce point hors-carte revient a 0,65 u du seuil, et 0,65 u d'une porte
**EST** a la porte -- la reponse est juste. La phase filtre desormais ses
points par `HubRegion.contains()`, imprime celui qu'elle saute et pourquoi,
et **refuse d'etre vide a moins de deux points reels**. Le chiffre est
**rapporte a chaque run** plutot qu'enterre ici.

⚠️ **Ce serrage n'est PAS propre a l'echelle** : il vient de la POSITION
(z = 28,18 pour une arete a 35). A 3,5 il restait deja 1,745 u. Aucune
echelle >= 6 -- le minimum pour depasser la spire -- n'en laisse plus de
1,44. **Deplacer la cabane est un changement de placement que ce lot n'avait
pas mandat de faire**, donc c'est signale, pas resolu.

### Validation

Editeur + templates Godot 4.3-stable installes dans ce sandbox (releases
GitHub officielles, **tailles verifiees contre le `Content-Length`** :
**50 276 070** et **1 073 228 327** octets, aucune troncature silencieuse).
Import headless **exit 0**, **36 `.scn`** (import complet verifie, pas
suppose). Export Web release **exit 0**, **0 erreur GDScript** -- les cinq
lignes que `grep -i error` rend sont du bruit ALSA/pilote audio factice.

`index.wasm` **35 376 909** octets / md5
**`af4a8fc2925d992348eb30deeeb54360`**, `index.js` md5
**`4e08904b1b7107858246af44b602067b`** -- identiques au fingerprint deja
consigne pour tout lot qui ne touche pas le code moteur. **Piege payload
tenu** : sur **240** lignes `Storing File`, **0** pour `assets_source`,
`scripts/dev`, `docs`, `web`, `build` ou `firebase.json`.

**Sondes, TOUTES exit 0** : `CabinProbe` (**48 checks, 0 failure**, PHASE T
comprise), `LakeZoneProbe`, `DivingBoardProbe`, `OwlFlightProbe`,
`WaterImpactProbe`, `StreamRideProbe` (37), `SeesawProbe`, `TurnstileProbe`,
`WaterTintProbe`, `AssetContractAudit` (**12/12 visuels, 0 collider
deplace**), `DeathModelAudit`, `ChargerShapeProbe`, `ProbeTimeoutAudit`
(**58 sondes scenes + 1 `--script`**). **Le jeu de sondes est IDENTIQUE a
`origin/staging`** (`diff` des noms de `.tscn`, 59 des deux cotes) -- les
trois sondes de recon de ce lot etaient jetables et sont supprimees.

**Budget de noeuds de dessin INCHANGE a 129** (hors portails), confirme par
les trois sondes qui le portent : retirer quatre rochers ne coute aucun
noeud, ils sont des instances dans un `MultiMesh` et non des noeuds.

⚠️ **Le piege d'ordre des flags s'est reproduit et a ete refuse** :
`SeesawProbe` lancee SANS `--fixed-fps 60` rapporte « the diagonal
reproduces at 4.983 s » et echoue. Relancee AVEC, elle rend **66 hops /
1122 frames / 18,700 s** -- le chiffre publie, au frame pres -- et sort a
0 echec. Ce n'etait pas une regression, c'etait l'invocation.

⚠️ **Piege deja consigne, re-rencontre deux fois** : une sonde dont le
SCRIPT ne parse pas ne tombe pas vite, elle traine jusqu'au timeout (la
scene ne se charge jamais, donc `arm()` n'est jamais atteint). Le boot
`--quit-after 3` la fait apparaitre en secondes, et c'est ce qui a servi
les deux fois.

### Rendus

`docs/hub-shots/cabin_scale7_{front,standoff}.png` -- la taille, meme azimut
que les plaques cabane precedentes, Keepy pose au seuil pour l'echelle.
`docs/hub-shots/cabin_tap_{before,after}.png` -- un tap de marche **un pas a
cote de la porte**, pilote par le vrai routage : il marche, reste dehors,
reste a taille pleine.

⚠️ **La premiere version de la plaque « tap » a photographie un tap qui ne
faisait rien**, parce que le point vise tombait **hors du frustum** (fov
horizontal 45°, camera sans lacet) : `_to_screen` le projetait hors du rect
du conteneur et `_handle_point` le jetait. La plaque asserte desormais
`rect.has_point()` avant de declencher -- un tap invisible se photographie
exactement comme un tap ignore.

### Reste ouvert -- jugement device, seul juge

1. **La cible.** Si « plus grand arbre de la foret » voulait dire le type
   `tree` littéral (3,9330) et non la spire, la cabane le depassait deja a
   3,5 et ce lot est trop grand d'un facteur 2. **Une constante dans
   `hub_layout.tres` le corrige** ; la mesure des deux est ci-dessus.
2. **Deux arbres et une souche traversent la cabane** (recouvrements 1,893 /
   1,718 / 0,109). Signale, non resolu, et aucune echelle atteignant la
   cible ne les degage.
3. **0,65 u de sol devant la porte.** Le joueur a tres peu de place pour se
   tenir devant la cabane et la regarder ; c'est la position, pas l'echelle,
   et la corriger est un changement de placement.
4. **Le `.pck` est a 30,2 Mo**, dont ~14 Mo de textures de cabane
   (`normal.png` seule fait 8,6 Mo de `.ctex`). **Anterieur a ce lot** -- le
   lot d'installation les a apportees -- mais c'est le double du 14,8 Mo
   d'avant la cabane, et sur un jeu web mobile ca merite d'etre su.
5. **Rien ici n'est un rendu device** : llvmpipe sous xvfb via le backend
   `opengl3` de BUREAU, contre WebGL2 sous Safari.

## LA CABANE, TROISIEME CAUSE : le CLAMP est un ENTONNOIR -- l'assertion qui l'avait trouvee avait ete FAITE TAIRE (29 aout 2026)

Branche `claude/keepy-cabin-trigger-diag-gllj3v`, partie de `staging`
(`24de82f`). Retour device apres le lot precedent : « c'est different
maintenant, mais toujours pas net ». Le symptome a change sans disparaitre,
donc une troisieme cause restait. **DEUX fichiers de jeu touches**, et
`CABIN_TAP_RADIUS`, `CABIN_DOOR_FACE_DEPTH`, `CABIN_DOOR_STANDOFF` et
`CABIN_ARRIVE_RADIUS` **ne sont dans le diff d'aucun des deux** : elles
avaient ete derivees, pas devinees, et rien ici ne prouve qu'une seule soit
encore fautive.

### ⚠️ LES DEUX HYPOTHESES DU BRIEF SONT REFUTEES PAR MESURE

Aucun fix n'a ete propose avant que le symptome soit reproduit dans une
sonde. Les deux pistes que le brief nommait ont ete exercees sur le code
livre et **ne produisent aucune entree** :

| piste | mesure |
|---|---|
| un tap fait PENDANT un hop en cours | 2 taps enchaines, le second a `hopping=true` -> `in_cabin=false`, **0 entree** |
| une chaine de hops TRAVERSANT le disque | approche la plus proche **0,501 u** (rayon d'arrivee 1,75) -> `in_cabin=false`, **0 entree** |

La raison est structurelle et vaut d'etre dite : `_try_enter_cabin` n'est
appele que derriere le latch `_entering`, et `_entering` n'est arme que par
un tap deliberement resolu en `tapped_cabin`. Un atterrissage qui traverse
le seuil sans cette intention ne peut rien declencher, quelle que soit sa
proximite. **Le defaut n'a jamais ete du cote de l'ATTERRISSAGE ; il est du
cote de CE QU'UN TAP VEUT DIRE.**

### LA CAUSE : une seule variable repond a DEUX questions

`_handle_point` resout un tap en deux temps qui partageaient une variable :

```
clamp_to()   repond  « ou peut-il se TENIR »
un test prop repond  « qu'est-ce que le joueur a VOULU DIRE »
```

Lire la seconde sur la premiere fait du clamp un **ENTONNOIR** : tout tap
sur du sol qui n'existe pas est tire vers le sol le plus proche qui existe,
et si un prop se trouve pres de ce bord, **tout le demi-plan derriere lui
se met a signifier ce prop**.

Le seuil de la cabane est a **0,655 u** a l'interieur de l'arete nord
(`z = 34,345` contre `z = 35,0`), donc une bande de **2,246 u** de cette
arete tombe **dans** le disque du seuil. Mesure sur la scene livree, sonde
jetable pilotant le vrai `_handle_point` en fenetre reelle 1080x1920 :

| visee (depuis le seuil) | sur la carte | clampe a | signal AVANT |
|---|---|---|---|
| 0,5 u derriere la porte | oui | 0,500 u | `cabin` |
| **1,5 u derriere** | **non** | **0,655 u** | **`cabin`** |
| **3,0 u derriere** | **non** | **0,655 u** | **`cabin`** |
| **5,0 u derriere** | **non** | **0,655 u** | **`cabin`** |

Et le balayage d'ecran, qui est le chiffre qui dit l'ampleur -- **debout au
seuil, 15,26 % de tout le sol visible voulait dire « entre », et 89,2 % de
ces pixels visaient du sol qui n'existe pas** ; le tap le plus lointain a
etre avale visait **49,8 u hors carte**.

### ⚠️ LA CABANE EST LE SEUL PROP EXPOSE, ET C'EST MESURE

C'est ce qui a decide le perimetre du fix plutot qu'une preference. Pour
chaque point de declenchement du plateau, distance au sol hors-carte le
plus proche, et nombre de points hors-carte qui s'y deversent :

| prop | position | sol hors-carte le plus proche | entonnoir |
|---|---|---|---|
| bateau | (-18,54 ; -0,73) | 16,50 u | **aucun** |
| perchoir hibou | (-2,70 ; 0,80) | infini | **aucun** |
| pied d'echelle x3 | (0,49 ; -28,20), (-21,15 ; 3,06), (-15,57 ; -8,57) | 6,85 / 13,90 / 19,45 u | **aucun** |
| **seuil cabane** | **(-17,43 ; 34,35)** | **0,70 u** | **3 004 points, jusqu'a 49,8 u** |

### LE FIX : le sens vient de la VISEE, la destination reste clampee

`_handle_point` calcule desormais `aim` -- le point brut sur le plan du sol
-- et **tous les tests de prop l'interrogent lui** ; seule la destination
emise reste `clamp_to(point)`. Une ligne par prop.

**Ecrit une fois pour les quatre plutot qu'en cas special cabane**, et la
mesure ci-dessus est ce qui rend ca gratuit : les cinq autres points de
declenchement sont de 6,85 u a infiniment loin de tout sol hors-carte et
aucun tap ne s'y deverse, donc leur comportement ne peut pas changer. Le
regle est ecrite une fois parce que l'entonnoir est une propriete du fait
d'etre **PRES D'UN BORD**, pas du fait d'etre une cabane -- le prochain prop
pose pres d'une arete la redecouvrirait.

**AVANT / APRES, meme sonde, memes postes, sujet verifie immobile :**

| debout | AVANT | APRES | pixels SUR la carte | pixels HORS carte |
|---|---|---|---|---|
| au seuil | 3 015 (15,26 %) | **443 (2,24 %)** | **327 -> 327** | 2 688 -> **116** |
| 2 u avant | 2 687 (13,60 %) | **700 (3,54 %)** | **522 -> 522** | 2 165 -> **178** |
| 4 u avant | 2 140 (10,83 %) | **1 226 (6,20 %)** | **902 -> 902** | 1 238 -> **324** |
| 8 u avant | 0 | 0 | 0 | 0 |

⚠️ **Le compte SUR LA CARTE est identique a chaque poste** (327 / 522 /
902), et c'est ca la preuve que le fix ne touche pas au seuil legitime : il
ne retire que l'entonnoir. Le residu hors-carte (116 / 178 / 324) est la
lamelle du disque du seuil qui depasse `z = 35` **tout en restant a moins
de 1,30 u de la porte** -- correctement encore le seuil. Un tap vise 1,0 u
derriere la porte entre donc toujours, et c'est juste : 1,0 u d'une
embrasure, on y est.

### ⚠️ L'ASSERTION QUI AVAIT TROUVE CETTE CAUSE AVAIT ETE FAITE TAIRE

C'est le vrai enseignement du lot, et il ne porte pas sur la geometrie.
`CabinProbe` PHASE T avait **echoue sur ce cas exact** au lot precedent. La
section « CONSEQUENCE MESUREE ET NON RESOLUE » de ce fichier le raconte
elle-meme -- « ce qu'une assertion de PHASE T a trouve en echouant sur du
code CORRECT » -- et conclut que « 0,65 u d'une porte **EST** a la porte,
la reponse est juste ». La phase a alors ete modifiee pour **filtrer** ses
points par `HubRegion.contains()` et **sauter** celui-la.

L'assertion avait raison ; le raisonnement qui l'a fait taire avait tort.
Le point n'est pas a 0,655 u de la porte parce que le joueur a vise la :
il y est parce qu'un demi-plan hors-carte NON BORNE a ete replie sur une
bande de 2,246 u. Le filtre est retire, le commentaire qui l'excusait est
remplace par la mesure, et **les trois candidats de PHASE T sont desormais
assertes au lieu d'etre sautes**.

**Regle generale, au prix d'un lot** : une sonde qui echoue sur du code
qu'on croit correct est une question, pas une nuisance. La faire taire par
un filtre supprime le seul temoin du defaut -- et ici le filtre a survecu
un lot entier avant que le device le redise.

### `CabinProbe` PHASE F -- ROUGE AVANT VERT, et non vide par construction

Nouvelle phase dediee a l'entonnoir. **Verifiee ROUGE sur l'arbre pre-fix :
5 echecs** (les 3 refus de PHASE F, celui de PHASE T re-active, et
l'assertion bout-en-bout), puis **0 echec** apres le fix.

⚠️ **L'ENTONNOIR EST ASSERTE COMME EXISTANT AVANT QU'ON DEMANDE A QUOI QUE
CE SOIT DE LUI RESISTER.** Chaque refus passerait gratuitement sur un
layout ou le clamp laisserait simplement ces points loin de la porte -- la
phase mesurerait alors la geometrie et pas le fix. Elle prouve donc d'abord
que ces visees sont hors carte **ET** que le clamp les traine encore sur le
seuil (0,655 u pour un rayon de 1,30), et seulement ensuite exige qu'elles
signifient une marche. Plus un **BLIND CHECK** : un tap SUR le seuil veut
toujours dire la cabane, sans quoi les refus ne diraient rien.

Bout-en-bout : viser 3 u au-dela de la cabane le laisse **dehors**, debout
a 0,655 u de la porte -- c'est-a-dire que « s'approcher pour regarder »
fonctionne enfin.

### ⚠️ DEUX DEFAUTS DANS MA PROPRE SONDE DE DIAGNOSTIC, publies plutot que lisses

Les deux rapportaient « aucun defaut » en ne mesurant rien, et les deux ont
ete trouves parce que les chiffres ne se recoupaient pas :

1. **`_settle` appelait `keepy.leave_cabin()` DIRECTEMENT**, ce qui ne
   restaure jamais le retrait du tap tenu par `HubWorld` -- apres la
   premiere entree, plus aucun tap ne pouvait signifier la cabane et le
   balayage lisait **0 pixel**. Un zero qui ressemblait a un fix.
2. **Le balayage ne coupait que `tapped_ground` et `tapped_cabin`.** Des
   pixels pres de l'horizon atteignaient encore une **ECHELLE** a travers
   `HubWorld`, qui emmenait Keepy jusqu'a elle : les postes 2 a 4 etaient
   mesures depuis le pied d'echelle `(-21,15 ; 3,06)`, dans les DEUX
   arbres. Une sonde qui deplace son propre sujet ne mesure rien. Le
   balayage coupe desormais **les quatre** signaux et **verifie que le
   sujet n'a pas bouge**, sinon il l'imprime au lieu de publier un chiffre.

Meme famille que la troncature de run deja consignee : la parade est de
**comparer les TAILLES avant les contenus**, et de faire porter a chaque
mesure la preuve qu'elle a reellement eu lieu.

### Reste ouvert -- jugement device, seul juge

1. **Est-ce que l'entree ne se declenche plus QUE sur un tap volontaire sur
   la porte ?** C'est tout l'objet du lot, et aucune sonde ne le dit : ce
   qui est mesure ici est llvmpipe sous xvfb via le backend `opengl3` de
   BUREAU, pas WebGL2 sous Safari.
2. **Le residu assume** : un tap vise jusqu'a 1,30 u de la porte entre
   toujours, hors carte compris (116 pixels au seuil). C'est le seuil, et
   le retrecir serait retoucher `CABIN_TAP_RADIUS`, que rien ne prouve
   fautif.
3. **Le seuil est toujours a 0,655 u du bord du plateau.** Le fix supprime
   l'entonnoir, il ne deplace pas la cabane -- le serrage vient de la
   POSITION (z = 28,18 pour une arete a 35) et reste signale, pas resolu.

### Deploiement staging de la troisieme cause (palier 1, automatique)

`staging` **`54b1b30`** (merge `--no-ff`, arbre **byte-identique** a la
branche feature : meme hash d'arbre `fc5a2602` des deux cotes ET `git diff`
vide, verifie AVANT le push). CI run **#313** (id 33244050576) **verte** --
`Import project resources` 08:50:09 -> 08:53:14, **`Export Web build`
08:53:14 -> 08:53:19**, `Deploy to Vercel [STAGING -- staging]` **succes**,
`[PRODUCTION -- main]` correctement **skipped**. **`main` NON touche**
(`origin/main` toujours `9031e5e`, verifie apres le push).

**Verifie SUR LE SERVICE, pas dans le log CI** :

| marqueur | avant | apres |
|---|---|---|
| `CACHE_VERSION` | `1787988691` = **07:31:31 UTC** | **`1787993598` = 08:53:18 UTC** |
| `index.wasm` servi | -- | **35 376 909** *(identique a l'export local, md5 `af4a8fc2925d992348eb30deeeb54360`)* |
| `index.pck` servi | -- | 30 228 288 *(marqueur, jamais preuve)* |

L'epoch d'apres tombe **a l'interieur de la fenetre `Export Web build`**
(08:53:14 -> 08:53:19), et les deux lectures d'apres portent
**`x-vercel-cache: MISS` avec `age: 0`**.

⚠️ **Deux limites dites plutot que sous-entendues** : la valeur AVANT du
`CACHE_VERSION` a ete relevee **avant le push** mais sur une reponse `HIT`
avec `age: 4374` -- valable comme **VALEUR** (elle precede le merge),
**pas** comme mesure de fraicheur ; et `index.wasm`/`index.pck` n'ont ete
lus qu'APRES, donc ils valent comme marqueur d'etat courant et non comme
preuve de transition. L'`index.pck` local vaut 30 228 272 contre
30 228 288 servi -- 16 octets, l'instabilite deja consignee.

**Sondes partagees, diffees contre `origin/staging` en worktree separe**
(import verifie complet des deux cotes, **36 `.scn`** chacun) :

| sonde | verdict |
|---|---|
| `AssetContractAudit`, `DeathModelAudit`, `ChargerShapeProbe`, `ProbeTimeoutAudit`, `WaterTintProbe` | **BYTE-IDENTIQUES sur les deux flux** |
| `SeesawProbe`, `LakeZoneProbe` (`--fixed-fps 60`) | **BYTE-IDENTIQUES sur les deux flux**, 0 echec |
| `StreamRideProbe` | 37 checks / 0 echec des deux cotes ; **une seule ligne differe, et elle differe AUSSI entre deux runs du MEME arbre** (une projection ecran a 4 decimales, 0,008 px) |
| `OwlFlightProbe`, `DivingBoardProbe`, `TurnstileProbe` | memes verdicts, memes tailles ; les seules lignes qui bougent sont des comptes de frames et des echantillons de tween (41 vs 44 frames, apex 2,565 vs 2,566) |
| `CabinProbe` | 8 phases, **0 echec** ; diff limite au passage saute -> asserte de PHASE T et aux lignes neuves de PHASE F |

⚠️ **`SeesawProbe` est sorti ROUGE au premier essai sur LES DEUX arbres, et
c'etait MON invocation** : j'avais omis `--fixed-fps 60` sur les runs xvfb,
donc son banc de traversee tournait a la vitesse du mur sous llvmpipe et sa
diagonale sortait a 8,150 s au lieu de 18,700 s. Avec le flag : **0 echec,
byte-identique**. C'est le piege d'ordre des flags deja consigne dans ce
fichier, rencontre sur un autre flag.

⚠️ **Piege d'outillage rencontre, et il a produit un faux diff** : un
premier script de sondes lance en `nohup ... &` a **survecu a son shell** et
a tourne EN PARALLELE de sa propre relance, les deux ecrivant dans les memes
fichiers `/tmp`. Le rapport annoncait alors 17 lignes de diff et une taille
de 5 109 contre 5 794 octets -- de la corruption mutuelle, pas une mesure.
**Comparer les TAILLES avant les contenus** est ce qui l'a attrape, comme
pour la troncature de run deja consignee.

Build : import headless **exit 0**, **36 `.scn`** (import complet verifie),
export Web release **exit 0**, **0 erreur GDScript ou de parse**. Piege
payload tenu : sur **240** lignes `Storing File`, **0** pour `scripts/dev`,
`assets_source`, `docs`, `web`, `build` ou `firebase.json`.

## SYSTEME DE NAVIGATION MULTI-NIVEAUX : le noyau, prouve dans une scene isolee (29 aout 2026)

Branche `claude/keepy-multilevel-nav-core-dimooi`, partie de `staging`
(`2b0fa66`). Regle n°1 verifiee AU DEBUT : `git fetch --all --prune`, tri
des refs par date et comparaison des **ARBRES** -- toutes les branches plus
recentes que `main` sont deja ancetres de `origin/staging`, **aucune session
concurrente**. La branche existait sans commit propre et pointait encore sur
`main` (precedent deja consigne) : reposee sur `staging`.

⚠️ **AUCUN FICHIER DU HUB N'EST TOUCHE.** `git status` sur ce lot ne rend
que des fichiers NEUFS -- `HubWorld.gd`, `HubBuilder.gd`, `HubTapInput.gd`,
`HubRegion.gd`, `KeepyHopper.gd`, `HubCamera.gd` et `hub_layout.tres` ne
sont dans le diff a aucun titre. **Destination assumee : ce systeme
remplacera a terme la navigation du hub -- mais cette migration est un lot
ULTERIEUR, hors de la sequence des quatre lots en cours.** Conception
complete : `docs/MULTILEVEL_NAV_DESIGN.md`.

### RECON -- toutes les hypotheses mono-altitude, MESUREES

**Le raycast de tap est UN plan ecrit en dur.** `HubTapInput:219` porte
`Plane(Vector3.UP, 0.0)`, et c'est **le seul `Plane(...)` de tout
`scripts/` hors `scripts/dev/`** (grep sur le depot). Il n'existe aucun
chemin par lequel un tap se resolve contre autre chose que y = 0.

**La region est litteralement 2D.** `HubRegion._flat()` est appele en
PREMIERE ligne de `contains()`, `clamp_to()`, `in_lake_water()`,
`lake_index_at()` et `_lake_holding()` : elle ne peut pas repondre
differemment a deux points qui ne different que par leur hauteur.
`PLATEAU_HALF_EXTENT` (35.0) est un scalaire unique -- aucune notion de
bornes par zone.

**Le corps ecrit Y proceduralement, jamais lu d'un terrain** -- trois sites
seulement, tous calcules : `_apply_hop` (`base + height`),
`_on_hop_finished` (`_hop_to_y`), `_place_on_route` (`RIDE_SEAT_Y`).

⚠️ **`_hop_from_y`/`_hop_to_y` SONT DEJA la generalisation multi-altitude
de l'arc**, livree par le lot plongeoir et prouvee exacte a extremites
egales (`DivingBoardProbe` PHASE A, divergence **0,000000000000 u** sur
1001 points). **C'est la seule brique existante directement reutilisable --
et elle est verrouillee a zero par TOUS ses appelants** : `_begin_hop`
re-zerote les deux a chaque hop ordinaire, `_on_hop_finished` les remet a
zero apres chaque atterrissage, et **tout dismount vise `_hop_to_y = 0.0`
en dur** (plongeon, eject bateau, tourniquet, balancoire, hibou). Le
mecanisme pour circuler a une altitude non nulle existe et n'a jamais ete
atteignable.

**⚠️ LA CAMERA N'A AUCUN OFFSET VERTICAL CONFIGURABLE** -- reponse
explicite a la question de recon. `HubCamera._wanted()` jette le Y de la
cible (`Vector3(x, 0.0, z) + OFFSET`) et `OFFSET.y = 7.6` est une constante
absolue mesuree depuis y = 0. Le "banking" du hibou evoque au brief est le
lacet de l'OISEAU : `grep camera` sur `HubWorld.gd` ne rend que des
commentaires, aucun code. Porter Keepy a y = +5 aujourd'hui le ferait
sortir par le haut du cadre sans que la camera bouge d'un pixel.

Recensement de l'idiome `Vector3(x, 0.0, z)` : **59 occurrences dans
`scripts/hub`** (KeepyHopper 24, HubBuilder 10, HubWorld 8, BoatMooring 6,
HubStreamRoute 5, HubWater 3, et 1 chacun pour HubCamera / HubRegion /
HubTapInput).

### ⚠️ LES TROIS DEROGATIONS SONT ETUDIEES ET ECARTEES -- ce sont deux problemes differents

Question de recon 3, repondue franchement. Tourniquet, balancoire et hibou
partagent un squelette identique (`mount` / `follow` appele **par
l'ecrivain du porteur dans le meme appel** / `leave` avec `_hop_from_y =
seat_y` lu sur le corps). Ils ne conviennent pas :

| | derogation | niveau |
|---|---|---|
| duree | **TRANSITOIRE**, bornee par un tween | **PERSISTANTE** |
| qui ecrit le corps | le PORTEUR, chaque frame | **personne** |
| taps pendant | interceptes, jamais une destination | **doivent devenir des destinations** |
| sortie | vers y = 0, en dur | vers l'altitude d'un AUTRE niveau |

**Un niveau ou Keepy ne peut pas marcher n'est pas un niveau, c'est un
siege.** Seul leur ARC est repris.

### CONCEPTION -- un niveau est aussi simple INTERNEMENT que le hub

`LevelDefinition` : un plan plat, `plane_y` absolu, `half_extent` **par
niveau**, plus `contains()` / `clamp_to()` / `flat()` / `plane()`.

⚠️ **`flat()` REMPLACE Y, il ne le JETTE PAS** -- la seule difference de
fond avec `HubRegion._flat()`, et ce qui permet a deux niveaux de repondre
differemment sur le meme XZ. `plane()` rend `Plane(UP, plane_y)`, pas le
`Plane(UP, 0)` qui fait du hub un rez-de-chaussee.

`LevelController` : le niveau courant decide **A LA FOIS** le raycast ET le
clamp -- resoudre contre le plan du niveau A puis clamper avec les bornes du
niveau B produit une destination dans la region et a la mauvaise hauteur,
sans erreur, un corps qui marche a travers le sol.

⚠️ **LE PATRON AIM/DESTINATION DU LOT 1 EST REPRIS DES LA PREMIERE LIGNE**,
pas ajoute apres. Tout test de lien lit `aim` (non clampe) ; seule
`destination` est un endroit ou marcher. **Le multi-niveaux AGGRAVE
l'entonnoir plutot que de le laisser inchange** : chaque niveau a son propre
bord, donc chaque lien pose pres d'un bord est un entonnoir de plus.

`LevelTransition` : le gate est **le RETRAIT ACTIF du bateau**, et le patron
ECHELLE est **INTERDIT** -- il a deja coute deux bugs distincts a ce depot.
Un lien se declare indisponible pour toute la duree d'une traversee, donc
un tap tombe **A TRAVERS** vers le chemin sol au lieu d'etre avale. Un
joueur en pleine traversee garde toujours un moyen de dire quelque chose.

**Camera : option INTERPOLEE retenue**, parce qu'elle ne coute rien -- le
suivi est deja un lerp exponentiel, lui donner une cible plus haute suffit.
⚠️ Elle suit **`plane_y`, jamais le Y du corps** : l'argument d'origine de
`HubCamera` (un arc qui oscille de 0,6 u par hop ferait tanguer l'horizon)
reste entierement valable -- un niveau est stable, un arc ne l'est pas.

### HORS PERIMETRE, nomme et non construit

Rendu de plusieurs niveaux empiles (occlusion, tri de transparence, culling
entre etages) ; plus de deux niveaux -- les structures sont des **LISTES des
le premier commit** (lecon du plongeoir payee d'avance) mais **seul le cas a
deux est EXERCE** ; persistance de position entre sessions ; la migration du
hub ; toute geometrie reelle (`.glb` cabane, echelle) qui est le lot 3 ;
collision et evitement d'obstacle, que le hub n'a pas non plus.

### `LevelNavProbe` : 56 checks, 0 echec, ROUGE AVANT VERT sur QUATRE cassures

Gatee et pas rapportee parce que **tout mode de panne de ce systeme est
SILENCIEUX** : un retrait qui ne s'engage jamais, un plan qui n'est pas
celui contre lequel les taps se resolvent, une visee lue sur une
destination clampee. Aucun ne leve, aucun ne casse un build.

⚠️ **Elle pilote `scenes/dev/LevelNavTest.tscn`, JAMAIS un fixture a elle**
-- le piege `SubstituteModel.tscn`. Et elle **DOIT tourner sous `xvfb`** :
PHASE AIM projette des points monde vers l'ecran et les repasse par le vrai
`dispatch()` ; sous le driver DUMMY le rect du conteneur est 0x0 et chaque
check passerait **en ne s'executant jamais**. Le rect est donc **asserte
non degenere** (mesure 1080x1920).

| cassure | rouge obtenu |
|---|---|
| patron ECHELLE (`is_available()` -> `true`) | **2 FAIL** |
| retrait jamais engage (`set_busy` no-op) | **2 FAIL** |
| **LES DEUX** gardes de re-declenchement retirees | **3 FAIL** |
| liens lus sur la DESTINATION (regression du lot 1) | **1 FAIL** -- « un vrai tap vise a 22 u hors carte est dispatche en `transition` » |

**DEUX DEFAUTS DE MA PROPRE SONDE, publies plutot que lisses**, tous deux
ayant fait echouer du code CORRECT :

1. **`contains()` est XZ-SEUL PAR CONTRAT.** J'assertais qu'un tap lointain
   sur le niveau haut ne serait pas contenu par le niveau bas -- or le carre
   haut est entierement dans l'empreinte XZ du bas, qui a raison de le
   contenir ("sur quel niveau est-il" est la question du CONTROLEUR).
   Re-visee sur la BORNE contre laquelle le clamp s'est arrete.
2. **« aucune visee hors carte ne peut signifier traverser » est FAUX.** Une
   visee a 1 u au-dela du bord est a 1 u d'un pied de rayon 1,6 : c'est un
   joueur qui tape A LA PORTE depuis juste dehors. Ce que la regle du lot 1
   achete n'est pas un ensemble VIDE mais un ensemble **borne par le
   RAYON**. Mesure : la visee hors carte la plus profonde qui signifie
   encore "traverser" est **-10,50**, la borne du rayon (-10,60) a un pas
   pres, et **0 des 690 visees balayees de 11 u a 88 u** au-dela.

⚠️ **UN DEFAUT REEL TROUVE PAR LA PASSE ROUGE-AVANT-VERT** :
`LevelTransition.accepts_tap()` lisait `_available` **en direct** alors que
`is_available()` est l'accesseur. Avec l'accesseur sabote, elle continuait
de refuser -- donc **une seule** des deux assertions de gate passait au
rouge. Un champ, deux lecteurs, l'un contournant l'accesseur. Corrige avant
commit ; le meme sabotage rend desormais **les deux** rouges.

### VALIDATION

Editeur + templates Godot 4.3-stable installes dans ce sandbox (releases
GitHub officielles, **tailles verifiees contre le `Content-Length`** :
**50 276 070** et **1 073 228 327** octets, aucune troncature). ⚠️ **Le
premier import a rendu 21 `.scn` au lieu de 36** -- le piege du faux-rouge
par import tronque, rencontre et controle plutot que suppose ; relance,
**36 `.scn`, 0 erreur**.

Boot de `scenes/dev/LevelNavTest.tscn` **exit 0** (le seul stderr est
`Parameter "m" is null`, l'erreur benigne du driver dummy deja consignee).
Export Web release **exit 0, 0 erreur** -- et **les 6 scripts de
`scripts/nav/` sont compiles en `.gdc` dans le pack**, ce qui est la preuve
qu'aucun n'a d'erreur GDScript.

`index.wasm` **35 376 909** octets / md5
**`af4a8fc2925d992348eb30deeeb54360`**, `index.js` md5
**`4e08904b1b7107858246af44b602067b`** -- identiques au fingerprint deja
consigne pour tout lot qui ne touche pas le code moteur.

⚠️ **Le `.pck` a DOUBLE depuis le dernier chiffre consigne (14,8 -> 30,2 Mo),
et ce n'est PAS ce lot** -- mesure des DEUX cotes dans la meme session,
`origin/staging` en worktree separe : **30 228 320** en baseline contre
**30 251 360** ici, soit **+23 040 octets**, exactement ce que coutent 6
petits `.gdc` et un `.tscn`. Le doublement precede ce lot (la cabane).

**Piege payload tenu, verifie sur le pack et pas sur le filtre** : sur
**254** lignes `Storing File`, **0** pour `scripts/dev`, `assets_source`,
`docs`, `web/`, `build` ou `firebase.json` -- et `scripts/nav/*` +
`scenes/dev/LevelNavTest.tscn` **sont** packes, comme ils le doivent.

**Sondes partagees, diffees contre `origin/staging` en worktree separe**
(imports verifies complets des deux cotes) : `AssetContractAudit` (12/12
visuels, **0/10 colliders deplaces**), `DeathModelAudit`,
`ChargerShapeProbe` -- **BYTE-IDENTIQUES sur les DEUX flux**.
`ProbeTimeoutAudit` differe d'**exactement deux lignes** : la nouvelle sonde
et son total, **58 -> 59 sondes scenes**, mesure des deux cotes et non
deduit du fait qu'un seul `.tscn` a ete ajoute.

**Aucune reference de code de `scripts/nav/` ou `scenes/dev/` vers
`scripts/dev/`** -- verifie commentaires strippes, parce que `scripts/dev/*`
est dans l'`exclude_filter` et qu'une telle reference resoudrait en editeur
et en headless puis echouerait **uniquement dans le build web**.

### Reste ouvert -- jugement device, seul juge

1. **Est-ce qu'un franchissement de 0,62 s se lit comme une montee** plutot
   que comme un saut vers un etage qui apparait ? Aucune sonde ne le dit.
2. **Le point explicitement demande au prochain test device** : verifier
   qu'aucun tap pres du bord ne declenche une transition non voulue -- meme
   classe de bug que le lot 1, sur ce nouveau systeme. La geometrie du banc
   est choisie pour ca (le pied du lien est **SUR** le bord du niveau bas),
   et la sonde la gate, mais un pouce a vitesse reelle est un autre juge.
3. **La camera traine pendant une montee** (lerp exponentiel, `FOLLOW_LAMBDA`
   5,0). Mesure comme le choix le moins couteux, jamais juge a l'oeil.
4. **L'etage haut est une dalle dont on voit le dessous.** Le rendu de deux
   niveaux empiles est nomme hors perimetre, pas resolu.

### Deploiement staging du noyau multi-niveaux (palier 1, automatique)

`staging` **`73a9d0a`** (merge `--no-ff`, arbre **byte-identique** a la
branche feature : meme hash d'arbre `2399d661` des deux cotes ET
`git diff` vide, verifie AVANT le push). CI run **#315**
(id 33246016102) **verte** -- `Import project resources` 09:40:29 ->
09:43:49, **`Export Web build` 09:43:49 -> 09:43:55**, `Deploy to Vercel
[STAGING -- staging]` **succes**, `[PRODUCTION -- main]` correctement
**skipped**. **`main` NON touche** (`origin/main` toujours `9031e5e`,
verifie apres le push).

**Verifie SUR LE SERVICE, pas dans le log CI** :

| | `CACHE_VERSION` | = UTC |
|---|---|---|
| avant (run #314) | `1787994186` | **09:03:06** |
| **apres (ce lot, run #315)** | **`1787996634`** | **09:43:54** |

L'epoch d'apres tombe **a l'interieur de la fenetre `Export Web build`**
(09:43:49 -> 09:43:55), et **les DEUX lectures portent `x-vercel-cache:
MISS` avec `age: 0`**, celle d'avant ayant ete relevee **avant le push**.
La bascule est donc prouvee dans les deux sens et pas deduite du log.

`GODOT_CONFIG.fileSizes` lu au meme moment (MISS/age 0 aussi) :
**`index.wasm` 35 376 909** -- identique a l'export local et au
fingerprint permanent -- et `index.pck` 30 251 408.

⚠️ **Une limite dite plutot que sous-entendue** : les deux tailles n'ont
ete lues qu'APRES le merge, donc elles valent comme marqueur d'etat
courant et **pas** comme preuve de transition ; c'est le `CACHE_VERSION`,
lu aux deux bouts en MISS/age 0, qui porte la bascule. Le `.pck` servi
(30 251 408) est 48 octets au-dessus de l'export local propre
(30 251 360) -- l'instabilite deja consignee, **marqueur et jamais preuve
d'identite**.

⚠️ **L'API GitHub Actions n'etait PAS perimee sur ce run**, et c'est note
dans ce sens-la : un seul appel a rendu les 18 etapes avec de vrais
horodatages, et l'import a reellement pris **3 min 20 s**. Le piege
existe ; il ne s'est pas produit ici, et le verifier coute un regard a
l'horloge.

### ACCES DEVICE TEMPORAIRE : bouton "Test nav (dev)" dans le menu de
### secours du hub (29 aout 2026)

Branche `claude/keepy-navtest-access-u63mxv`, partie de `staging`
(`cdad00e`). **Lot jetable, pas une feature** : il n'existe que pour
permettre a Mathieu de valider le noyau de navigation multi-niveaux
(lot 2/4, section ci-dessus) sur un vrai telephone avant le lot 3/4.

`scenes/HubWorld.tscn` gagne `NavTestButton` dans `FallbackMenu/Panel/
VBoxContainer` (memes `StyleBoxFlat` que `ChasedButton`/`QuizzButton`/
`BattleButton`, aucune ressource dupliquee), et `HubWorld.gd` un
`_on_fallback_navtest()` qui appelle `get_tree().change_scene_to_file(
"res://scenes/dev/LevelNavTest.tscn")` **directement, sans passer par
`HubRouter.ROUTES`** -- cette table est la routing de production, et ce
chemin est un banc jetable qui n'est pas cense lui survivre.
`scenes/dev/LevelNavTest.tscn` gagne symetriquement un bouton
"Retour hub" (`HubButton`) qui appelle `change_scene_to_file(
"res://scenes/HubWorld.tscn")` -- sans lui la validation device etait un
aller sans retour.

⚠️ **GATING STRUCTUREL, PAS RUNTIME** : ce projet n'a aucun flag
prod/staging a l'execution (deja note pour les outils de debug
precedents). Le bouton reste donc accessible tant que ce lot vit sur
`staging` -- il est retire **avant tout merge vers `main`**, dans le
meme lot que le retrait de `scenes/dev/LevelNavTest.tscn` lui-meme ou
juste avant, selon ce qui reste utile a ce moment-la.

**PHASE UNTOUCHED** : `HubBuilder.gd`, `HubTapInput.gd`, `HubRegion.gd`,
`KeepyHopper.gd`, `HubCamera.gd` et `resources/hub/hub_layout.tres` ne
sont dans le diff a aucun titre -- verifie par `git diff --stat`, pas
suppose. Seuls `HubWorld.tscn`/`HubWorld.gd` (un bouton, un handler) et
`LevelNavTest.tscn`/`LevelNavTestWorld.gd` (un bouton, un handler) sont
touches.

`LevelNavProbe` pilote la scene shippee et ne connait aucun nom de
noeud UI ni aucune assertion de comptage d'enfants -- un bouton de plus
sous `Control` ne peut donc pas la faire regresser, et elle reste verte
sur l'arbre modifie.

**Reste ouvert -- jugement device, seul juge** : Mathieu doit acceder a
la scene de test via ce bouton sur `keepy-staging.vercel.app`, se
deplacer sur chaque niveau, franchir la transition dans les deux sens,
et verifier qu'aucun tap pres du bord ne declenche une transition non
voulue. `main` **non touche**.
l'horloge.

## LA CAMERA DE NIVEAU FAIT DISPARAITRE CE QUI CACHE KEEPY -- et le risque alpha deja paye sur l'eau reste entier (29 aout 2026)

Branche `claude/keepy-nav-camera-occlusion-cz7m5q`, partie de `staging`
(`4c204c8`). Regle n°1 verifiee AU DEBUT, par ARBRE et pas par nom : la
branche la plus recente du depot porte **exactement l'arbre de
`origin/staging`** (donc deja mergee) et `staging..main` est VIDE --
**aucune session concurrente**. `main` = `9031e5e`, **INTOUCHE**.

Retour device du noyau nav (lot 2) : le mecanisme de transition marche,
mais la camera se fait masquer Keepy des qu'un plan intermediaire passe
entre les deux, ce qui rend l'endroit injouable. **TROIS fichiers touches**,
verifie par `git diff --stat` : `scripts/nav/LevelCamera.gd`,
`scripts/nav/LevelNavTestWorld.gd`, `scripts/dev/LevelNavProbe.gd`. Le diff
hub est **VIDE** (`scripts/hub/`, `scenes/HubWorld.tscn`, `resources/hub/`,
`scripts/world/`, `scripts/battle/`, `scripts/autoload/` : rien).

### Le defaut est MESURE sur les constantes livrees, pas deduit du rapport

Segment lentille -> masse du corps, teste contre l'AABB de chaque prop, aux
constantes que `LevelNavTestWorld` et `LevelCamera` publient deja :

| Keepy sur le niveau BAS (sol 0) | z 0 | -4 | -6 | **-7** | **-8** | **-9** |
|---|---|---|---|---|---|---|
| la dalle du haut le cache ? | non | non | non | **OUI** | **OUI** | **OUI** |

Le rayon entre dans la dalle a **52 % du trajet**, et le balayage lateral
donne **OCCLUDE de x -4 a +4** -- c'est-a-dire toute la largeur de la
dalle. Ce n'est pas un cas de bord : c'est **l'approche entiere du seul
lien du monde**, donc le joueur se perd de vue exactement la ou il doit
viser. Le **poteau** s'y ajoute au pied du lien (z -9, entree a 98 % du
trajet). Sur le niveau HAUT, **rien n'occulte jamais** : la dalle du haut
est sa propre dalle et son dessus est a ses pieds.

⚠️ **`HubCamera` n'a pas ce probleme et n'a besoin de rien** -- le plateau
est mono-altitude par construction, donc rien n'est jamais AU-DESSUS du
marcheur. Elle n'est **pas modifiee** (reconfirme en la relisant, pas
suppose perime).

### ⚠️ AUCUN RAYCAST N'EXISTE DANS CE DEPOT -- d'ou un test AABB

`grep` sur tout le depot : **ZERO** `intersect_ray`, `RayCast3D`,
`PhysicsDirectSpaceState`, `PhysicsRayQuery`. Le noyau nav ecrit des
transforms ; le plateau dont il reprend l'idiome n'a pas de collider non
plus. `intersect_ray` ne rapporte que des `CollisionObject3D`, donc le
faire marcher exigerait de poser des `StaticBody3D` sur la geometrie de
niveau : **le premier collider de navigation du projet**, un changement
plus gros que le fondu qu'il sert, une nouvelle classe de panne, et un tick
physique qu'une sonde devrait ensuite pomper.

Un test **segment-vs-AABB** (methode des slabs, borne au segment) est exact
pour une boite, deterministe, et gatable sans serveur physique. L'AABB est
celle du noeud transformee en monde : pour un occluder tourne elle enclot
plus que le mesh, donc **le fondu s'engage un peu TOT plutot qu'un peu
tard** -- le sens sur pour un mecanisme dont le travail est de ne pas
cacher le joueur.

### Ce que le fondu fait, et les trois choses qu'il fait par discipline

Groupe **`level_occluder`** : la geometrie de niveau s'inscrit, le fondu ne
prend jamais "ce qui passe". Test throttle a **12,5 Hz**, fondu lerpe
**chaque frame** -- ca throttle la requete et pas la fluidite.

1. **Le materiau est DUPLIQUE avant toute ecriture.** L'importeur glTF de
   Godot lie UN materiau partage sur le mesh, donc ecrire dedans fait
   fondre toutes les copies de cette geometrie dans le projet. Precedent
   direct : `FighterView._ensure_material()`.
2. **`transparency` passe a ALPHA seulement PENDANT le fondu, et revient a
   DISABLED des que l'alpha revient a 1.** Un alpha < 1 avec transparency
   DISABLED est **silencieusement IGNORE** (le lac a deja paye celle-la),
   et un materiau laisse dans la passe transparente y perd son ecriture de
   profondeur en permanence. Les deux sont ecrits ensemble, jamais separes.
3. **`cull_mode` n'est JAMAIS touche.** Le defaut de la ligne de flottaison
   avait besoin de `cull_disabled` sur un corps ferme pour apparaitre ; le
   defaut de `StandardMaterial3D` est BACK, et rien ici ne le change.
   Asserte, pour que rien plus tard ne le fasse sans le dire.

⚠️ **LA GEOMETRIE MARQUEE EST CHOISIE PAR MESURE** : la dalle du HAUT et le
POTEAU (les deux mesures occultantes ci-dessus). La dalle du BAS n'est
**pas** marquee -- c'est le sol que la camera regarde d'en haut, rien de
pose dessus n'est jamais derriere elle, et la marquer dirait quelque chose
de faux sur ce que le groupe signifie.

### ⚠️ CE LOT NE PEUT PAS ETRE VALIDE SUR LA FOI DU BUILD -- c'est la meme classe de risque que l'eau

La transparence pres des plans d'eau est deja passee **VERTE dans ce
sandbox** (llvmpipe/opengl3 sous xvfb) et **CASSEE sur device** (Safari
iOS, WebGL2, a certains azimuts seulement) : le shader de flottaison
ecrivait ALPHA, ce qui deplace un materiau dans la passe transparente et
lui coute son ecriture de profondeur. **C'est exactement la meme classe
ici.** Les trois mesures ci-dessus reduisent la surface exposee ; aucune ne
prouve le telephone.

⚠️ **Et ce lot ne peut PAS non plus eliminer le risque par construction** :
la scene de test n'a **aucun plan d'eau**, donc le voisinage precis qui a
casse -- une surface alpha a cote d'une autre surface alpha -- **n'est pas
exerce ici du tout**. C'est dit plutot que sous-entendu.

### Rouge avant vert, DEUX FOIS, et une assertion a moi qui ne valait rien

**Casse n°1** -- l'ecriture de l'ensemble bloquant neutralisee : **5 FAIL,
exit 1**, dont le BLIND CHECK. ⚠️ **Et trois assertions sont passees VERTES
dans ce run rouge** ("le sol n'est jamais bloquant", "il redevient opaque",
"il ressort de la passe transparente") -- gratuitement, contre un mecanisme
qui n'avait jamais ete cable. **C'est litteralement pourquoi le blind check
n'est pas optionnel.**

**Casse n°2** -- la duplication du materiau retiree, tout le reste intact :
**2 FAIL**, et le materiau PARTAGE sort a **alpha 0,250** -- le defaut
"fondre toutes les copies de cette geometrie" attrape en flagrant delit.

⚠️ **UNE ASSERTION QUE J'AVAIS ECRITE ETAIT SANS VALEUR, et le premier run
vert l'a montree.** Elle comparait l'id du materiau avant/apres pour prouver
la duplication -- or au moment ou la phase lit son "avant", la camera a deja
eu des frames pour dupliquer, donc elle comparait le duplicat a lui-meme.
Pire : elle serait restee verte contre une camera qui aurait ecrit droit
dans la ressource partagee, puisqu'aucun id ne le remarque. Remplacee par
le test qui porte sur la propriete reelle -- **deux noeuds recoivent UN
materiau, un seul est marque, et l'assertion est que l'AUTRE n'a pas
bouge** -- qui ne peut pas passer par accident, et que la casse n°2
confirme.

### Validation

`LevelNavProbe` : **56 checks (baseline) -> 77, 0 echec, exit 0**, avec
**DEUX blind checks** armes et verts. Editeur + templates Godot 4.3-stable
installes (releases GitHub officielles, **tailles verifiees contre le
`Content-Length`** : 50 276 070 et 1 073 228 327 octets, aucune troncature
silencieuse). Import headless **exit 0, 36 `.scn`**, verifie complet des
DEUX cotes. Export Web release **exit 0, 0 ligne d'erreur** ;
`index.wasm` **35 376 909** / md5 `af4a8fc2925d992348eb30deeeb54360`,
`index.js` md5 `4e08904b1b7107858246af44b602067b` -- le fingerprint
permanent de tout lot qui ne touche pas le code moteur. `index.pck`
30 255 424, **marqueur et jamais preuve d'identite**. Piege payload tenu :
sur **254** lignes `Storing File`, **0** pour `scripts/dev`,
`assets_source`, `docs`, `web/`, `build` ou `firebase.json` ; les six
scripts de `scripts/nav/` sont packes, `LevelNavProbe` **absent du pack**.

**Quatre sondes partagees, diffees contre `origin/staging` en worktree
separe (36 `.scn` des deux cotes, TAILLES comparees avant les contenus) :
BYTE-IDENTIQUES sur les DEUX flux** -- `ProbeTimeoutAudit` (**59 sondes
scenes**, inchange : ce lot ajoute une phase a une sonde existante, pas une
sonde), `AssetContractAudit` (**12/12 visuels, 0/10 colliders deplaces**),
`DeathModelAudit`, `ChargerShapeProbe`.

**Rendu de controle, et rien de plus que ca** (sonde jetable, supprimee
avant commit -- `ProbeTimeoutAudit` revient a 59) : trois captures
1080x1920 sous `xvfb`/`opengl3`. Degage, la dalle est opaque et le marcheur
visible ; dans la bande mesuree, la dalle est visiblement translucide et le
marcheur se lit au travers ; au pied du lien, dalle ET poteau fondus, corps
parfaitement lisible. **Ca attrape une erreur grossiere, ca ne dit rien du
telephone.**

### Reste ouvert -- le device est seul juge, et il l'est plus que d'habitude ici

1. **Est-ce que le fondu se lit proprement sous tous les angles**, sans
   scintillement ni zone restee opaque ? C'est tout l'objet du lot, et la
   classe de risque a deja casse une fois exactement la.
2. **Le voisinage alpha-contre-alpha n'est pas exerce** par cette scene
   (aucun plan d'eau) -- donc meme un device vert ici ne dira rien du jour
   ou un occluder cotoiera une surface transparente.
3. **La dalle fondue lit sombre plutot que brune** dans le sandbox, parce
   que le ciel derriere est quasi noir. Appreciation, pas defaut.
4. **`OCCLUDED_ALPHA = 0.25`, `FADE_LAMBDA = 9.0`, `TEST_INTERVAL_S = 0.08`**
   sont des points de depart pour un appel device, pas des optimums
   mesures -- chacun est une edition de constante.

### Deploiement staging du fondu d'occlusion (palier 1, automatique)

`staging` **`026bcc4`** (merge `--no-ff`, arbre **byte-identique** a la
branche feature : meme hash d'arbre `388abd07` des deux cotes ET
`git diff` vide, verifie AVANT le push). CI run **#318**
(id 33249349142) **verte** -- `Import project resources`
11:07:25 -> 11:10:43, **`Export Web build` 11:10:43 -> 11:10:49**,
`Deploy to Vercel [STAGING -- staging]` **succes** 11:11:03 -> 11:11:13,
`[PRODUCTION -- main]` correctement **skipped**. **`main` NON touche**
(`origin/main` toujours `9031e5e`, verifie apres le push).

**Verifie SUR LE SERVICE, pas dans le log CI, sur DEUX marqueurs
independants et aux DEUX bouts** :

| marqueur | avant | apres (ce lot, run #318) |
|---|---|---|
| `CACHE_VERSION` | `1787999014` = **10:23:34 UTC** | **`1788001848` = 11:10:48 UTC** |
| `index.pck` servi | **30 252 288** | **30 255 392** |
| `index.wasm` servi | 35 376 909 | **35 376 909** *(inchange, attendu)* |

L'epoch d'apres tombe **a l'interieur de la fenetre `Export Web build`**
(11:10:43 -> 11:10:49), et **les deux lectures d'apres portent
`x-vercel-cache: MISS` avec `age: 0`**.

⚠️ **Limite dite plutot que sous-entendue** : les deux valeurs AVANT ont
ete relevees **avant le merge** mais sur des reponses `HIT` avec un `age`
non nul (2510 et 2524 s). Elles sont valables comme **VALEURS** -- elles
precedent le push, donc ce sont bien celles de l'ancien build -- mais **ce
ne sont PAS des mesures de fraicheur**.

⚠️ **`index.pck` prend une valeur de plus pour le meme contenu** :
30 255 424 a l'export local propre contre 30 255 392 servi, **32 octets
d'ecart**. Enieme illustration de l'instabilite deja consignee -- marqueur
« nouveau build », **jamais** preuve d'identite. `index.wasm`
(**35 376 909**, md5 `af4a8fc2925d992348eb30deeeb54360`) est identique des
deux cotes et c'est lui la preuve d'identite.

⚠️ **L'API Actions n'etait PAS perimee sur ce run**, et c'est note dans ce
sens-la : les appels successifs ont rendu de vraies progressions d'etapes
avec de vrais horodatages, et l'import a reellement pris **3 min 18 s**.
Le piege existe ; il ne s'est pas produit ici, et le verifier coute un
regard a l'horloge.

⚠️ **PIEGE `pgrep` RE-RENCONTRE, celui que ce fichier documente deja** :
une boucle d'attente `until pgrep -f "[p]ath . --import"` ne s'est jamais
terminee, parce que la ligne de commande du shell ANCETRE contenait le
motif nu (le heredoc du script qui lancait l'import). Le crochet ferme
« je me matche moi-meme », il ne fait rien contre un ancetre. Contourne en
attendant le **PID reel** (`until [ ! -d /proc/<pid> ]`), ce que
`scripts/dev/wait_for_probe.sh --pid` fait deja proprement.

**RAPPEL, et il vaut plus ici que sur n'importe quel lot recent : CE LOT
NE PEUT PAS ETRE CONSIDERE VALIDE SUR LA SEULE FOI DU BUILD HEADLESS.**
Le fondu est de la transparence, et la transparence de ce projet est
DEJA passee verte dans ce sandbox et cassee sur device une fois. Le
device est seul juge.

## LA CABANE : L'INTERIEUR JOUABLE -- une scene a part entiere, et le vieux « il disparait sur place » est SUPPRIME (29 aout 2026)

Branche `claude/keepy-cabin-interior-alsew8`, partie de `staging` (**`8bad644`**,
exactement la ref annoncee ; `origin/main` = **`9031e5e`**, **INTOUCHE**). Regle
n°1 verifiee AU DEBUT : `git fetch --all --prune`, tri des refs distantes par
date et comparaison des ARBRES -- `origin/staging` est la ref la plus recente du
depot et la branche du lot occlusion (`2ecf722`) en est deja un ancetre,
**aucune session concurrente**.

Le lot 2 avait pose le noyau multi-niveaux dans une scene de banc d'essai. Ce
lot lui donne son premier vrai client : la cabane du plateau s'ouvre desormais
sur un **interieur jouable a deux etages**, et le mecanisme precedent -- Keepy
qui se recroqueville et disparait SUR PLACE -- est **retire**, pas desactive.

### ⚠️ TROIS PREMISSES DU BRIEF TOMBENT A LA MESURE, et elles changent tout le lot

1. **« l'interieur est une texture peinte, pas de la geometrie creuse » --
   FAUX.** Une carte de profondeur le long de -Z montre la bande centrale de la
   face avant a **z ~ -0,20** en unites modele contre une coque a **+0,18** :
   un vrai renfoncement d'environ **0,4** de profondeur.
2. **« aucune mesure de sommets ne peut dire ou est le vrai sol » -- FAUX.**
   Des raycasts vers le BAS a l'interieur de la cavite trouvent un plancher
   plat a **y = -0,5305** (echantillons -0,532 / -0,529 / -0,528 / -0,530 /
   -0,529, ecart-type **0,0175** sur **117** cellules), une dalle de mezzanine
   a **-0,115** et un plafond a **+0,106**. Monde = `(y_modele + 0,800420) x
   echelle`.
3. **« la navigation devra peut-etre etre contrainte a un axe parce que la
   profondeur peinte est fausse » -- FAUX POUR LE REZ-DE-CHAUSSEE.** Son
   empreinte mesuree a l'echelle 11 fait ~3,5 de large sur ~5,5 de profond :
   de la profondeur REELLE, donc **XZ libre**. C'est la MEZZANINE qui est
   contrainte, et seulement par la mesure (deck ~3,6 x 2,0) -- ce qui tombe
   tout seul de son `half_extent`, sans second mode de navigation.

⚠️ **UNE CONTRAINTE REELLE SUBSISTE, elle** : la cavite n'ouvre que sur **+Z**.
Rendue sur quatre axes, elle est creuse et meublee depuis +Z et un tronc ferme
depuis -Z. C'est ce qui borne la camera, pas l'illusion.

### RECON DU ROUTAGE : aucun chemin de retour ne savait revenir a une PORTE

Les trois portails passent par `HubRouter` (`ROUTES`, un seul appelant de
`change_scene_to_file`, deliberement pas un autoload). Et **tout retour vers le
hub est aujourd'hui un `change_scene_to_file` nu** -- Chased, Quizz, Battle,
l'ecran de login et le banc nav font exactement ca. Or **le noeud `Keepy` de
`HubWorld.tscn` ne porte AUCUN transform** : les cinq reviennent donc a
l'origine du monde, c'est-a-dire au milieu du plateau.

C'est juste pour un sous-jeu. C'est **faux pour une porte**.

D'ou `scripts/hub/HubSpawn.gd` (nouveau) : un `static var` sur une classe
simple -- la plus petite chose qui survive a un changement de scene, les
scripts restant charges quand l'arbre ne l'est pas. **Pas un autoload**, pour
l'argument que `HubRouter` tient deja sur lui-meme (« une table de routage qui
gagne un second appelant cesse d'etre un detail du hub et devient un
framework ») : un autoload est joignable de partout, et la seule chose que
ceci ne doit pas devenir est un teleport generique.

⚠️ **IL EST CONSOMME, PAS LU.** `take()` efface en rendant. Un spawn laisse en
place s'appliquerait aussi au PROCHAIN chargement du hub : sortir de la cabane,
s'eloigner, aller dans Chased, revenir -- et se retrouver a la porte de la
cabane sans savoir pourquoi.

**Et c'est le HUB qui l'ecrit, pas l'interieur.** La coordonnee de la porte est
un fait que cet ecran possede deja (`HubBuilder` la derive de la position, de
l'echelle et de la rotation de la cabane), donc il l'enregistre a l'ALLER et la
scene d'interieur n'apprend jamais rien du plateau -- pas de `HubBuilder`, pas
de `HubRegion`, pas de ressource de layout. Une seconde copie de cette
arithmetique la-dedans est exactement comme une porte finit du mauvais cote
d'un batiment que quelqu'un a tourne dans le layout.

### DECISION CAMERA : FIXE, et `LevelCamera` DELIBEREMENT PAS UTILISEE

C'est la decision que le brief demandait de documenter plutot que de prendre en
silence, et elle est tranchee par une mesure et non par un gout.

L'AABB monde de la cabane a l'echelle 11 est **x [-10,43 ; 10,40], y [0 ;
17,49], z [-8,42 ; 8,59]**, et **le marcheur se tient DEDANS aux deux etages**.
Or un segment qui SE TERMINE dans une boite coupe toujours cette boite : le
test de dalle de `LevelCamera._segment_hits` rapporterait « bloquant » a chaque
frame depuis n'importe quelle position, et toute la cabane -- **un seul mesh**
-- resterait a `alpha 0,25` pendant toute la visite.

Donc : **camera fixe**, `LevelCamera` ni utilisee ni modifiee, et **rien ne
rejoint le groupe `level_occluder`**. C'est une reponse directe a la case de la
checklist, pas une omission -- et `CabinProbe` PHASE I la gate
(`get_nodes_in_group("level_occluder").is_empty()`).

Pose retenue : **`(0,3 ; 9,5 ; 12,5)` a -22 deg**, `KEEP_WIDTH`, `fov 45`,
choisie parmi quatre candidates rendues. Les deux etages sont assertes devant
elle.

### DECISION NAVIGATION : XZ LIBRE aux deux etages, PROPOSEE ET JUSTIFIEE

Le brief demandait de **proposer** si la navigation devait etre contrainte a un
axe (couloir) plutot que libre. **Proposition : non, XZ libre**, et la raison
est la premisse 3 ci-dessus -- la profondeur du rez-de-chaussee est reelle
(~5,5 unites monde), pas peinte. Contraindre a un axe serait retirer de
l'espace que la geometrie possede vraiment.

La mezzanine EST plus etroite, et c'est son `half_extent` (1,10 contre 1,70)
qui le dit : elle se parcourt naturellement comme une galerie qu'on longe,
**sans second mode de navigation**, sans code special et sans branche.

### CALIBRATION : ZERO iteration corrective sur la hauteur de sol

Parce que la premisse 2 est tombee : le sol n'a pas ete cherche au rendu, il a
ete **MESURE** (117 cellules, sd 0,0175), puis le rendu a servi a **CONFIRMER**.

| passe | ce qui a ete rendu | resultat |
|---|---|---|
| 1 | echelle 7 / 11 / 14 / 18, Keepy sur le sol mesure | **11 retenue** : 7 montre l'arbre entier (on regarde une cabane, on n'est pas dedans), 14 rogne la mezzanine, 18 perd la mezzanine ET la fenetre ronde |
| 2 | quatre poses de camera a l'echelle 11 | **(0,3 ; 9,5 ; 12,5) a -22 deg** |
| 3 | Keepy au centre ET aux quatre coins de chaque etage | plante sur le tapis dessine et sur le plancher de la mezzanine **du premier coup, a chaque echelle** |

**Aucune iteration corrective n'a ete necessaire sur `FLOOR_MODEL_Y` ni sur
`LOFT_MODEL_Y`.** Ce qui a demande trois passes, c'est le CADRAGE (echelle et
camera), pas l'altitude.

⚠️ **UNE LIMITE HONNETE, mesuree et publiee plutot que tue.** Lu comme une
COLLISION, un balayage exhaustif de toutes les hauteurs a la recherche du plus
grand carre strictement plat (tolerance +-0,18) ne trouve que y ~ 1,75
(half_extent 1,00), y ~ 2,00 (0,80) et deux touches de canopee a y ~ 10,50 /
11,00 ; le plus grand carre strictement plat de la mezzanine fait **0,5 x 0,5**
contre un Keepy de **1,32 de large sur 2,04 de profond**. Lu comme un DECOR --
ce que le brief demande explicitement : plans invisibles, `.glb` en toile de
fond -- la mezzanine est un plancher DESSINE, et un plan invisible a sa hauteur
dominante y pose Keepy, les etageres dessinees etant traversees exactement
comme les arbres du plateau le sont deja.

### CE QUI EST RETIRE, ET IL EST RETIRE ENTIEREMENT

`grep` le confirme : **zero reference** a `State.IN_CABIN`, `enter_cabin`,
`leave_cabin`, `is_in_cabin`, `cabin_entered`, `cabin_exited` ou
`cabin_available` dans du code vivant.

* `KeepyHopper` : l'etat, les deux signaux, `CABIN_ENTER_S` / `CABIN_EXIT_S` /
  `CABIN_DUCK_SCALE`, `_cabin_spot`, `_cabin_tween` et les quatre fonctions.
* `HubWorld` : `_leave_cabin()` et **les deux gardes `is_in_cabin()`** (celle
  du chemin sol, qui etait toute la sortie, et celle de l'atterrissage).
* `HubTapInput` : `cabin_available`. **La retraite du bateau n'a plus d'objet**
  -- l'ecran entier cesse d'exister pendant la visite, donc il n'y a plus de
  « pendant » ou un tap pourrait vouloir dire autre chose, et un drapeau qui ne
  peut jamais etre faux est un drapeau que personne ne lit.
* `CabinProbe` : les phases C, D et E. **Une assertion dont le sujet n'existe
  plus n'est pas un test plus faible, c'est un test de rien** -- et en laisser
  une derriere est comme une sonde continue d'imprimer OK sur une feature que
  personne ne livre plus.

⚠️ **CE QUI LES REMPLACE ASSERTE LA MEME PROMESSE PAR L'AUTRE MECANISME** :
PHASE G prouve que la surface a disparu (`has_method`, la liste de signaux, la
liste de proprietes), PHASE R que le tap route, PHASE S que la sortie revient
sur le pas de la porte. Supprimer sans ajouter aurait laisse la SUPPRESSION
elle-meme non testee : un etat a moitie retire compile, se livre, et ne fait
rien de visible jusqu'a ce qu'un tap le trouve.

### ⚠️ AUCUN DIALOGUE DE CONFIRMATION, et ce n'est pas un oubli

Les trois portails passent par `HubConfirmDialog`. La cabane non, parce que la
maniere d'y ARRIVER est differente : **un portail s'entre en ATTERRISSANT
dessus**, ce qu'un saut vise au-dela fait par accident ; **la cabane s'entre en
TAPANT SON PAS DE PORTE**, sur une cible retrecie a **1,30** pour exactement
cette raison. La question a deja ete posee par le geste.

⚠️ **Mais la consequence d'un declenchement intempestif est desormais PIRE, pas
meilleure** : il coutait un accroupissement dont un tap sortait, il coute
maintenant un CHANGEMENT DE SCENE. Les phases T et F -- les trois causes de
declenchement intempestif deja documentees -- sont donc **conservees en
entier**, inchangees dans ce qu'elles assertent.

### QUATRE PIEGES MESURES DANS LA SONDE ELLE-MEME, publies plutot que lisses

Aucun n'est un defaut du jeu, et chacun a produit un rouge ou un vert
trompeur avant d'etre compris :

1. **La sonde EST `current_scene`, donc la route la TUE.**
   `change_scene_to_file` libere ce que `current_scene` designe -- le premier
   test d'entree honnete a supprime la sonde en pleine phase, et toutes les
   assertions suivantes ont lu un arbre nul (`Parameter "data.tree" is null`,
   PHASE R et PHASE S perdues toutes les deux). Le hub est donc **declare
   `current_scene`** : ce n'est pas une fiction, c'est la scene sous test, et
   la remplacer est precisement le travail du routeur.
2. **`set_current_scene` REFUSE un noeud qui n'est pas enfant direct de
   `root`**, en poussant une erreur moteur et en laissant `current_scene`
   intacte -- donc silencieusement, du point de vue de la sonde.
3. **`root` est occupe a monter ses enfants pendant le `_ready()` de la
   scene principale** : `add_child` dessus echoue net, et la sonde a alors
   mesure un plateau VIDE -- zero cabane, zero portail, zero bateau, comme si
   le lot avait supprime le hub. Une frame d'attente le ferme.
4. **`change_scene_to_packed` met `current_scene` a NULL immediatement** et
   n'installe la nouvelle scene qu'a la FIN de la frame d'idle. Il existe donc
   une fenetre ou l'arbre n'a aucune scene courante, et une attente sur
   `current_scene != hub` seule lit `null` et rapporte l'interieur manquant.

Un cinquieme, sur le CADRAGE : PHASE T aimait a la porte **depuis le spawn**,
or la porte est a **z = +34** et la camera regarde vers -Z -- elle est donc
DERRIERE elle. `unproject_position` rend un point hors du conteneur,
`_handle_point` le jette, et les quatre assertions lisent une liste de signaux
vide, **y compris leur propre blind check**. Elle place et SNAPPE desormais la
camera, exactement comme PHASE F le faisait deja.

### ROUGE-AVANT-VERT, trois neutralisations distinctes

Chacune appliquee puis revertee, fichier restaure verifie **byte-identique**
(`cmp`) :

| ce qui est neutralise | resultat |
|---|---|
| `_router.route(&"cabin")` | **2 FAIL** -- « the hub scene was left (240 frames) » et « the interior is the current scene (HubWorld) » |
| `HubSpawn.request(door)` | **1 FAIL** -- « he walked to the door and the entry fired (900 frames) » |
| `_consume_return_spawn()` | **3 FAIL** -- il revient a `(0, 0, 0)`, le spawn n'est pas consomme, et la camera cadre l'origine |

### VALIDATION

Import headless **exit 0** (36 `.scn`). Boot headless de `CabinInterior.tscn`
et de `HubWorld.tscn` : **exit 0, 0 erreur**. Export Web release **exit 0**,
**0 ligne d'erreur ou de parse** sur 260 lignes `Storing File`.

`index.wasm` **35 376 909** octets / md5
**`af4a8fc2925d992348eb30deeeb54360`**, `index.js` md5
**`4e08904b1b7107858246af44b602067b`** -- identiques au fingerprint deja
consigne pour tout lot qui ne touche pas le code moteur. **Piege payload
tenu** : **0** ligne `Storing File` pour `scripts/dev`, `assets_source`,
`docs`, `web/` ou `build`.

⚠️ **`index.pck` fait 30 264 416 octets, et ce n'est PAS une regression de ce
lot** : la cabane pese ses textures depuis son propre lot d'installation.
Marqueur « nouveau build », **jamais preuve d'identite** -- c'est `index.wasm`
qui la porte.

**Sondes : `CabinProbe` 0 echec (exit 0), `LevelNavProbe` 77 checks / 0 echec
(exit 0)**, plus la couverture PHASE UNTOUCHED des trois portails et de leurs
routes, des trois plongeoirs, du hibou, du tourniquet, de la balancoire et du
bateau.

### RESTE OUVERT -- jugement device, seul juge

1. ⚠️ **LA CALIBRATION VISUELLE DE L'INTERIEUR NE PEUT ETRE VALIDEE
   DEFINITIVEMENT QUE SUR DEVICE**, meme reserve qu'au lot occlusion : le rendu
   headless confirme la MECANIQUE (les plans sont a la hauteur mesuree, le
   marcheur s'y tient, la camera les voit tous les deux), il ne confirme pas le
   RESSENTI. Tout ce qui precede est rendu par llvmpipe sous xvfb via le
   backend `opengl3` de BUREAU, contre WebGL2 sous Safari.
2. **Est-ce que Keepy se lit comme POSE sur le tapis dessine et sur la
   mezzanine dessinee**, a la taille reelle d'un telephone ?
3. **L'echelle 11 est un compromis mesure** (les deux etages lisibles), pas un
   optimum : c'est la seule constante a bouger si le cadrage est rejuge.
4. **La mezzanine est un plancher DESSINE, pas une collision** (limite
   ci-dessus) -- les etageres se traversent, comme les arbres du plateau.
5. **Aucun son, aucune particule, aucun asset neuf** : hors perimetre.

### Deploiement staging de l'interieur de la cabane (palier 1, automatique)

`staging` **`28bf6a5`** (merge `--no-ff`, arbre **byte-identique** a la branche
feature : meme hash d'arbre `4bb3865a` des deux cotes ET `git diff` vide,
verifie AVANT le push). CI run **#320** (id 33253871453) **verte** --
`Import project resources` 13:00:19 -> 13:03:37, **`Export Web build`
13:03:37 -> 13:03:43**, `Verify export output` succes, `Deploy to Vercel
[STAGING -- staging]` **succes** 13:03:58 -> 13:04:12, `[PRODUCTION -- main]`
correctement **skipped**. **`main` NON touche** (`origin/main` toujours
`9031e5e`, verifie apres le push) : palier 2, gate Mathieu apres validation
device.

**Verifie SUR LE SERVICE, pas dans le log CI, sur DEUX marqueurs independants
et aux DEUX bouts -- les QUATRE lectures en `x-vercel-cache: MISS` /
`age: 0`**, les valeurs "avant" ayant ete relevees AVANT le merge :

| marqueur | avant | apres (ce lot, run #320) |
|---|---|---|
| `CACHE_VERSION` | `1788002366` = **11:19:26 UTC** | **`1788008622` = 13:03:42 UTC** |
| `index.pck` servi | **30 255 392** | **30 264 448** |
| `index.wasm` servi | 35 376 909 | **35 376 909** *(inchange, attendu)* |

L'epoch d'apres tombe **a l'interieur de la fenetre `Export Web build`**
(13:03:37 -> 13:03:43) : l'alias sert bien ce build. C'est la forme la plus
forte que ce fichier documente -- deux marqueurs, quatre lectures fraiches,
la bascule prouvee dans les deux sens et pas deduite du log.

⚠️ **`index.pck` prend une valeur de plus pour le meme contenu** : 30 264 416
a l'export local propre contre 30 264 448 servi, **32 octets d'ecart**.
Enieme illustration de l'instabilite deja consignee -- marqueur « nouveau
build », **jamais** preuve d'identite. `index.wasm` (**35 376 909**, md5
`af4a8fc2925d992348eb30deeeb54360`) est identique des deux cotes et c'est lui
la preuve d'identite, coherent avec un lot qui ne touche que du GDScript et
deux scenes.

⚠️ **L'API GitHub Actions N'ETAIT PAS perimee sur ce run, et c'est note dans
ce sens-la** : deux appels successifs ont rendu une reponse byte-identique
figee sur « Import project resources », ce qui en a exactement la forme --
mais l'horloge disait 13:02:46 pour un import demarre a 13:00:19, et cet
import a reellement dure **3 min 18 s**. « L'etape est simplement lente »
doit etre ecarte avant d'accuser l'API, dans les deux sens.

⚠️ **RAPPEL, et il vaut plus ici que sur la plupart des lots : LA
CALIBRATION VISUELLE DE L'INTERIEUR NE PEUT ETRE VALIDEE DEFINITIVEMENT QUE
SUR DEVICE**, meme reserve qu'au lot occlusion. Le rendu headless confirme la
MECANIQUE (les plans sont a la hauteur mesuree, le marcheur s'y tient, la
camera cadre les deux etages, le tap route, la sortie revient sur le pas de
la porte) ; il ne confirme pas le RESSENTI -- tout ce qui precede est rendu
par llvmpipe sous xvfb via le backend `opengl3` de BUREAU, contre WebGL2 sous
Safari.

## LE PLANCHER DE LA CABANE : Keepy etait enfonce de 68 % de sa taille, et la cause etait UNE MOITIE d'un chiffre copie (29 aout 2026)

Branche `claude/keepy-cabin-floor-and-taps-89xt2k`, partie de `staging`
(`d613034` — un commit DOC SEULE au-dessus du `28bf6a5` annonce par le brief,
verifie ancetre plutot que suppose ; `main` = `9031e5e`, **INTOUCHE**). Regle
n°1 verifiee AU DEBUT par comparaison d'ARBRES et pas de noms : la branche du
lot precedent porte exactement l'arbre de `origin/staging`, donc deja mergee,
**aucune session concurrente**.

### SECTION A — LA CAUSE, ET LES DEUX HYPOTHESES DU BRIEF QUI TOMBENT

Retour device : Keepy visible **uniquement a partir des yeux**. Le brief
proposait trois pistes ; la mesure en garde une, et pas sous la forme annoncee.

* **H2 (formule de conversion) — REFUTEE.** `CABIN_MODEL_OFFSET_Y = 0.800420`
  **EST** le `min.y` du `.glb` (mesure sur l'accessor POSITION : min
  `-0.800420`, max `+0.789680`). Et la question « le transform reel du noeud
  `.glb` dans `CabinInterior.tscn` » n'a pas d'objet : **la scene ne contient
  aucun noeud `.glb`**, `Props` est vide et le decor est instancie en code.
  Les deux modeles portent par ailleurs **un seul noeud a transform
  identite** — aucun transform cache a decouvrir.
* **H3 (face touchee) — REFUTEE.** Rayons verticaux dans la piece, toutes les
  intersections listees avec la normale : le sol trouve a `y ≈ -0.528..-0.533`
  porte **`n_y = +0.99`**, c'est-a-dire la face SUPERIEURE. Le raycast d'origine
  visait juste.
* **H1 (pivot) — CONFIRMEE, mais PAS « centre vs pieds ».** Ce pivot-la
  couterait une demi-hauteur (0.675) ; le defaut mesure vaut **0.916568**.

⚠️ **LA CAUSE : UN CHIFFRE COPIE PAR MOITIE.** Le hub enonce le lift de Keepy
en **DEUX nombres qui ne veulent rien dire separement** — le slot `Body` est a
`y = 0.9` dans `HubWorld.tscn`, et `ModelSlot` y place ensuite le modele a
`model_offset = -0.2246`, total **0.6754**. `CabinInterior._place_walker()`
avait copie **le SECOND terme seul** et l'avait **multiplie par l'echelle** —
or `ModelSlot` ne le multiplie pas (`_model_root.position = model_offset`,
directement). Le 0.9 saute, et un terme que le hub ne scale jamais est scale :

| | y du modele au-dessus des pieds |
|---|---|
| hub (correct) | `0.9 + (-0.2246)` = **+0.6754** |
| cabane (livre) | `-0.2246 * 1.07368` = **-0.2411** |
| **ecart** | **0.916549 analytique / 0.916568 mesure** |

Contre une hauteur dessinee de **1.3501**, cela fait **67,9 % de lui sous le
plancher** — seul le haut du crane depasse, ce qui est exactement le rapport
device. **Les DEUX etages souffraient du meme decalage**, confirme par la sonde
en rouge : `-0.916568` sur `cabin_floor` **et** sur `cabin_loft`. Une seule
formule, donc une seule cause.

**Corrige A LA RACINE en DERIVANT le lift du maillage** plutot qu'en ajoutant
une correction par-dessus une formule fausse : le contrat de `LevelWalker` est
que son origine EST les pieds, donc le corps est leve d'exactement la
profondeur a laquelle le modele pend sous sa propre origine
(`-KEEPY_MODEL_MIN_Y * KEEPY_SCALE`). **Recoupe trois fois** : le hub (pieds a
`-0.000020`), `scenes/dev/LevelNavTest.tscn` (capsule hauteur 1.3 a `y = 0.65`,
donc bas sur l'origine, meme contrat), et cette constante qui **reproduit le
0.6754 du hub a 2.0e-5**. Verifie sur la scene construite : **pieds − plan =
+0.000000** aux deux etages, et il fait toujours **1.3501** de haut.

⚠️ **PIEGE A CONNAITRE, ET C'EST L'INVERSE DE CELUI QU'ON ATTEND : ici le
RAYCAST avait raison et c'est la COPIE qui mentait.** Le lot precedent avait
mesure les deux planchers par rayons et les avait eus JUSTES du premier coup ;
ce qui a coule, c'est un chiffre repris d'un autre fichier. **Un nombre copie
d'ailleurs merite plus de defiance qu'un nombre mesure ici** — surtout quand il
est UNE MOITIE d'une somme, parce qu'une moitie de somme se lit comme un
nombre complet et ne se signale jamais.

### SECTION B — LES ZONES TAPABLES, ET LE PATRON DU HUB REUTILISE A MOITIE

Le patron existant EST reconnu : `HubPortal.tscn` = pad sombre + anneau vif +
`Label3D` billboard + pulse d'anneau en ECHELLE a l'approche (1.14 sur 0.55 s,
hysteresis 2.2/2.6). **Forme et comportement repris tels quels** — c'est ce
qu'un joueur vient d'apprendre sur le plateau.

⚠️ **MAIS SES COULEURS NON, ET C'EST MESURE.** Le sol de la cabane a ete
echantillonne **sur un rendu reel de cette scene**, 121 points a travers la
camera livree : **`rgb(0.7138, 0.4829, 0.3730)`**, un bois clair et chaud,
contre l'herbe du hub a `rgb(0.2, 0.4, 0.15)`. Les deux encres ne marchent pas
sur les deux fonds :

| couleur | vs SOL CABANE | vs HERBE HUB |
|---|---|---|
| anneau ambre du portail | **2.03:1** | 3.96:1 |
| pad vert sombre du portail | 3.00:1 | 1.54:1 |

L'ambre du hub est une marque a 3.96:1 dehors et **2.03:1 dedans — sous le
plancher 3.0:1 de ce projet**. La reutiliser telle quelle aurait livre un
marqueur quasi invisible sur du bois, c'est-a-dire exactement la plainte que ce
lot doit fermer. **La doctrine des deux bandes du plateau ne s'applique pas
ici** : le sol cabane rend a `L = 0.2498`, donc franchir 3.0:1 exige
`L >= 0.8493` (quasi blanc) ou `L <= 0.0499` (quasi noir) — verifie, pas
suppose.

Livre : **anneau creme `rgb(1.00, 0.96, 0.88)` a 3.23:1**, qui porte seul le
contraste.

⚠️ **ET LE PAD SOMBRE A ETE PRIS SUR UN RENDU QUE LE RATIO AVAIT DEJA
VALIDE.** La premiere version copiait l'arrangement du hub : pad quasi noir
`rgb(0.10,0.07,0.05)`, **5.29:1**, confortable. Le ratio etait bon et la
LECTURE fausse — sur du bois clair un disque quasi noir ne se lit pas comme un
tapis d'atterrissage mais comme **un TROU perce dans le plancher**. Sur l'herbe
sombre du hub le meme disque se lit comme une ombre, ce qui est pourquoi le
patron marche dehors et pas dedans. **Aucun chiffre de contraste ne pouvait
attraper ca** : c'est du contraste ELEVE, et le defaut porte sur QUELLE CHOSE
l'oeil decide qu'il regarde. Il a fallu regarder le rendu. Remplace par le
creme de l'anneau **a alpha 0.28** — une flaque de lumiere posee sur les
planches. Son **1.45:1 est publie plutot que cache** : le pad ne franchit pas
3.0:1 et n'a pas a le faire, il remplit la forme pour que le marqueur se lise
comme un LIEU et pas comme un contour.

⚠️ `transparency = TRANSPARENCY_ALPHA` est **pose explicitement** : le canal
alpha d'`albedo_color` est ignore tant qu'il reste a `DISABLED`, et le pad
rendrait creme opaque **sans aucune erreur pour le dire** — le meme piege
autour duquel les disques d'eau de ce projet sont deja construits.

**Retour au tap** : `CabinMarker.flash()`, un pop d'echelle + de luminosite sur
**un seul tween** normalise 0..1 (`4t(1-t)`, exactement 0 aux deux bouts, donc
l'anneau ne peut pas rester coince clair sur un arrondi). C'est la moitie que
le hub n'a pas : son pulse dit « ceci est vivant », il ne dit rien du tap qui
vient d'avoir lieu, et dehors la marche elle-meme fait la reponse. Ici un tap
sur la porte peut ne declencher aucun hop.

⚠️ **LE MARQUEUR DE L'ECHELLE SE DEPLACE AVEC L'ETAGE**, et c'est l'option
honnete : le lien a une entree sur CHAQUE niveau et seule celle du niveau
courant repond a un tap (`accepts_tap` mesure contre `entry_for(current)`).
Dessiner les deux bouts poserait un anneau inerte sur la mezzanine pendant
qu'on est en bas — **un marqueur qui ment sur sa propre tapabilite**.

### SECTION C — SORTIR PAR LA PORTE

Taper la porte fait **marcher** Keepy jusqu'a elle puis sortir a l'arrivee —
la forme de l'echelle du hub, et non celle du bouton. Mesure plutot que
supposee maison : l'echelle du hub ne declenche pas non plus au moment du tap,
`_on_tapped_ladder` arme une intention et appelle `hop_to()`, et c'est
l'atterrissage qui grimpe.

**Gate patron BATEAU, jamais patron echelle** : la porte **se retire**
(`is_available()` faux) des que la sortie commence, donc un second tap
**tombe a travers** vers le chemin sol au lieu d'etre avale. Ce n'est pas de
la coquetterie : `change_scene_to_file()` est differe en fin de frame, donc
sans ca deux taps dans la meme frame demandent deux fois.

**L'intention de sortie SURVIT a un atterrissage de passage** — la lecon du lot
hibou, assertee et pas supposee : une version qui la lachait au premier
atterrissage laissait Keepy debout a cote de la chose sans l'avoir utilisee, et
sa sonde etait verte jusqu'a ce qu'une marche passe a deux hops. Un tap
ordinaire ailleurs l'annule.

⚠️ **LE BOUTON « < Sortir » EST CONSERVE, DELIBEREMENT.** Son retrait est
**conditionne** a la validation device de la sortie par tap. Tant que ce test
n'a pas eu lieu, il est le chemin de sortie qui ne peut enfermer personne — et
il partage desormais `_leave_to_hub()` avec la porte, donc « ce que sortir veut
dire » est un seul fait.

### ⚠️ TROUVE ET **NON CORRIGE** : l'echelle dessinee n'est pas ou le lien la met

Rendu de debug avec des marqueurs aux positions configurees : le carre du sol
tombe bien sur le tapis, mais **le haut du lien `LADDER_TOP` atterrit sur le
LIT**, pas au sommet de l'echelle dessinee, qui arrive a la mezzanine **a
droite de l'ourson, hors du carre de la mezzanine**.

**Non recalibre ici, et c'est un choix.** Re-deriver une position 3D a l'oeil
depuis une seule vue est precisement la methode peu fiable qui produit ce genre
d'erreur — le faire mal serait pire que le signaler. Le marqueur est donc pose
**la ou un tap fonctionne reellement**, parce que son travail est de dire ou
taper, pas de decorer le dessin ; et le desaccord devient VISIBLE sur device,
ce qui est le chemin le plus court vers une calibration propre (multi-vues ou
par maillage) dans son propre lot.

**Le lit** est en revanche bien dans le carre de la mezzanine (confirme au
rendu : les points du carre tombent sur le matelas). Son cercle est a **0.70**
et non 0.85 parce que le haut de l'echelle occupe deja ce petit carre : les
deux sont a **1.920** l'un de l'autre contre des rayons qui somment a **1.800**
— **asserte par la sonde** plutot que laisse a un commentaire.

### VALIDATION

Editeur + templates Godot 4.3-stable installes dans ce sandbox (releases GitHub
officielles, **tailles verifiees contre le `Content-Length`** : 50 276 070 et
1 073 228 327 octets, aucune troncature). Import headless **exit 0, 36 `.scn`,
0 erreur de parse**. Boot de `CabinInterior.tscn` **0 erreur**. Export Web
release **exit 0, 0 erreur**, `index.wasm` **35 376 909** / md5
`af4a8fc2925d992348eb30deeeb54360`, `index.js` md5
`4e08904b1b7107858246af44b602067b` — le fingerprint permanent de tout lot qui
ne touche pas le code moteur. **Piege payload tenu** : sur 264 lignes
`Storing File`, **0** pour `scripts/dev`, `assets_source`, `docs`, `web`,
`build` ou `firebase.json`.

**`CabinProbe` : 125 OK, 0 echec** (PHASE J et PHASE K neuves), et **les deux
verifiees ROUGE AVANT VERT** :

| sabotage | resultat |
|---|---|
| lift d'origine restaure | **2 FAIL**, `-0.916568` au sol ET a la mezzanine ; la hauteur reste verte |
| signal de porte lache (patron echelle) | **2 FAIL** sur l'intention ; les deux refus restent verts |

Le second rouge justifie l'ordre de la phase : « un tap ailleurs ne sort pas »
passe gratuitement contre une porte jamais cablee, donc la porte est montree
TIRANT avant que ses refus veuillent dire quoi que ce soit.

**PHASE UNTOUCHED, diffee contre `origin/staging` en worktree separe** (import
verifie complet des deux cotes, 36 `.scn`) : `LevelNavProbe`,
`ProbeTimeoutAudit` (**59 sondes scenes**, chiffre inchange),
`AssetContractAudit`, `DeathModelAudit`, `ChargerShapeProbe` —
**BYTE-IDENTIQUES sur les DEUX flux, stdout ET stderr**. Le hub complet de
`CabinProbe` (portails, plongeoirs, hibou, tourniquet, balancoire, bateau,
routes) est vert.

⚠️ **DEUX ROUGES PRE-EXISTANTS, verifies sur `origin/staging` et NON imputables
a ce lot** : `LevelNavProbe` **2 echecs** (fade d'occlusion, `alpha 0.997`) —
sortie **byte-identique** des deux cotes ; et `SeesawProbe` **2 echecs**, deja
signale comme tel par le brief. Ni l'un ni l'autre n'est traite ici.

⚠️ **PIEGES D'OUTILLAGE RENCONTRES, tous deja documentes ailleurs dans ce
fichier et re-payes ici :**
* **Editer un `.gd` pendant qu'un `--import` tourne** produit une cascade de
  `Could not find type` sur une classe qui existe : l'import avait scanne le
  consommateur avant que le `class_name` soit sur le disque. Un import propre
  ensuite : 0 erreur. **Ne pas editer pendant un import.**
* **Un `class_name` neuf n'est pas visible avant un re-import** — le boot
  echoue sur `Could not find type` alors que le fichier est correct.
* **`pkill -f 'Godot_v4.3'` TUE SON PROPRE SHELL** : le motif matche la ligne
  de commande qui le contient. Toute la suite de la commande n'a jamais tourne,
  silencieusement. Forme crochetee obligatoire (`'[G]odot_v4.3'`), exactement
  le piege `pgrep -f` deja consigne.
* **`SubViewportContainer.stretch = true` ignore un `vp.size` explicite** — une
  tentative de rendre a demi-resolution a rendu a 1080x1920 quand meme (sans
  consequence ici : le cadrage est donc bien celui livre).
* **Un lambda GDScript capture une locale PAR VALEUR**, et `.z` sur un
  `Vector2` fait tourner une sonde a vide sans verdict.

### RESTE OUVERT — jugement device, seul juge

1. **Keepy est-il pose correctement aux deux etages** a l'echelle reelle ? Le
   chiffre est `+0.000000` ; l'oeil n'a pas encore tranche.
2. **Les zones tapables sont-elles identifiables sans explication** ? Le
   contraste est mesure, la lecture ne l'est pas — et le pad a deja prouve que
   les deux ne sont pas la meme question.
3. **La sortie par la porte se sent-elle naturelle**, et le bouton
   « < Sortir » peut-il alors disparaitre ? **Son retrait est un lot ulterieur,
   explicitement conditionne a ce test.**
4. **Le desaccord echelle-dessinee / lien** ci-dessus, a calibrer dans son
   propre lot.
5. Rien ici n'est un rendu device : llvmpipe sous `xvfb` via le backend
   `opengl3` de BUREAU, contre WebGL2 sous Safari.

## LA PORTE DE LA CABANE SE VOIT ENFIN DU DEHORS, ET KEEPY SE COUCHE SUR LE LIT (29 aout 2026)

Branche `claude/keepy-entrance-marker-bed-pose-stbbbp`, partie de `staging`
(`597326d`). Regle n°1 verifiee AU DEBUT : `git fetch --all --prune`, tri des
refs par date et comparaison des **ARBRES** -- la seule branche plus recente que
`main`, `claude/keepy-cabin-floor-and-taps-89xt2k`, porte **exactement l'arbre
de `origin/staging`** (donc deja mergee), **aucune session concurrente**.

Deux sujets independants, deux commits distincts.

### A -- LE MARQUEUR D'ENTREE : le lot precedent avait marque l'INTERIEUR et rien DEHORS

Retour device : depuis le plateau, rien n'indique ou taper pour entrer. Le lot
precedent a pose des marques sur l'echelle, le lit et la porte **a l'interieur**
de la cabane, en reutilisant le disque+anneau+pulse des portails du hub -- et
n'a jamais applique ce motif a l'ENTREE. La seule porte du jeu qui mene a une
nouvelle scene etait la seule sans anneau autour.

**`CabinMarker` est REUTILISE, pas reinvente** : le composant gagne un
`enum Surface { CABIN_FLOOR, HUB_GRASS }` et rien d'autre. Le hub instancie le
meme fichier, avec l'encre et les hauteurs de l'exterieur.

⚠️ **LE MARQUEUR EST CONSTRUIT DES DEUX MEMES FAITS QUE LE TEST DE TAP** -- le
point de porte publie par `HubBuilder` et `CABIN_TAP_RADIUS` -- et jamais d'une
seconde position ou d'une seconde taille. Le cercle qu'on vise et le cercle que
`HubTapInput` mesure sont donc **un seul nombre** : un marqueur ne peut pas etre
dessine A COTE du declencheur, ni plus petit que lui, parce qu'il n'y a rien a
cote de quoi le dessiner. Gate : « il se tient SUR le pas de porte publie
(0,0000 u d'ecart) » et « l'anneau est exactement le rayon de tap (1,300 vs
1,300) ».

**Permanent + pulse quand on approche**, ce qui est le comportement DES
PORTAILS et non un nouveau. C'etait une decision a prendre plutot qu'un defaut :
une marque qui n'apparait qu'une fois qu'on est proche ne peut pas dire ou
aller, et les trois portails du plateau sont deja permanents. Le brief demandait
la coherence avec ce qui est livre, et ce qui est livre est permanent-plus-pulse
(`HubPortal.NEAR_FACTOR` 2,2 / `NEAR_RELEASE` 2,6, relus et non recopies).

⚠️ **UNE AFFIRMATION QUE J'AVAIS ECRITE ETAIT FAUSSE, ET LA MESURE L'A TUEE.**
J'avais commente que le creme de l'interieur « echouerait » sur l'herbe du
plateau, extrapole de la table d'albedos de l'en-tete. **Mesure sur des pixels
REELLEMENT RENDUS a ce pas de porte** :

| | Lrel rendu | vs le sol |
|---|---|---|
| sol du plateau au pas de porte `rgb(0,3258 0,3762 0,1917)` | **0,1042** | -- |
| anneau AMBRE livre `(0,95 0,74 0,30)` | 0,4366 | **3,16:1** |
| anneau CREME de l'interieur | 0,7169 | **4,76:1** |
| pad vert fonce livre `(0,13 0,28 0,12)` | -- | 1,48:1 |

**Le creme aurait mieux score.** L'ambre est donc choisi sur **l'IDENTITE** et
explicitement PAS sur le contraste : c'est le quatrieme endroit du plateau ou un
tap vous emmene ailleurs, et les trois autres ressemblent a ca. Les deux
commentaires qui disaient le contraire sont reecrits. A noter au passage : le
3,96:1 de l'en-tete est un chiffre d'ALBEDO, alors que le fog a `z = +34` ne
livre que **3,16:1** a l'ecran -- 0,16 de marge au-dessus du plancher 3,0.

⚠️ **Les HAUTEURS changent avec la surface, et c'est porteur** : dedans le pad
flotte a 0,20 et l'anneau a 0,23 (le plancher peint de la cabane n'est pas
plat) ; dehors ils tombent a **0,03 / 0,09**, l'herbe etant un `PlaneMesh` a
`y = 0` exactement. Gate : « il repose sur la pelouse, pas a un cinquieme de
metre au-dessus ». Le libelle passe de 32 px / `pixel_size` 0,0032 a **64 px /
0,006** -- la camera du hub est bien plus loin que celle de la cabane.

⚠️ **`font_size` etait implicite et ne l'est plus** : le libelle roulait sur le
defaut moteur de 32. Mesure, pas suppose (`Label3D.new()` en 4.3 : font_size 32,
pixel_size 0,005, outline 12). Un defaut moteur qui bouge d'une version a
l'autre aurait redimensionne toutes les marques du jeu en silence.

**`CABIN_DOOR_LABEL = "Cabane"` vit dans `HubWorld`, a cote du rayon**, et n'est
PAS lu dans le layout comme les trois portails lisent le leur : l'entree de
layout d'une cabane ne porte aucune cle `label`, et en ajouter une imposerait un
schema a toute cabane future pour un panneau qui dirait le meme mot a chaque
fois.

### B -- LA POSE COUCHEE : le lit EST le plancher, et c'est ce que la mesure a trouve en premier

⚠️ **LE PREMIER RESULTAT EST QUE LA MEZZANINE *EST* LE LIT.** Le dessus dessine
de la mezzanine et l'edredon turquoise peint dessus sont **la meme surface** --
un ray-cast vers le bas sur le carre marchable du loft trouve un seul plateau a
**7,52-7,59** et aucun matelas separe a l'interieur. Donc « couche-le sur le
lit » et « couche-le sur le plancher de la mezzanine » etaient la MEME
instruction sur presque tout ce carre, et **la mise en garde du brief ne pouvait
pas etre satisfaite en trouvant une surface plus haute : il n'y en a pas** (la
literie surelevee a 7,66-7,79 est centree a x ≈ -1,9, juste hors du carre
marchable x ∈ [-1,80 ; 0,40]).

Ce qu'il y A : **sous le marqueur, la literie dessinee CREUSE**. Echantillonnee
sous le centre du marqueur sur un disque de rayon 0,25 -- a peu pres la largeur
que son corps presente au lit -- la surface dessinee court de 6,91 a 7,60,
**mediane 7,3686**, soit **0,1710 SOUS le plan de marche**. Ce creux est
l'intervalle entre la barriere de lit et l'edredon derriere elle.

⚠️ **ET LE RENDU A CHOISI LE MEME NOMBRE, INDEPENDAMMENT.** Six profondeurs
candidates rendues a travers la camera livree (0,00 / 0,12 / 0,18 / 0,25 sous le
plan, a trois lacets) : **0,18 lit le mieux** -- 0,25 met la barriere en travers
de son menton, 0,00 le laisse assis sur le cadre. La mesure dit **0,1710**. Deux
routes, un centimetre d'ecart. Livre en unites MODELE
(`BED_MODEL_Y = -0.13055`, multiplie par `CABIN_SCALE` via `_world_y()`), comme
les deux planchers -- un litteral monde ici serait une seconde copie muette de
l'echelle.

⚠️ **IL EST ROULE SUR LE FLANC, PAS BASCULE SUR LE DOS, ET C'EST LE MESH QUI
L'IMPOSE.** Keepy est modelise ASSIS, queue enroulee derriere lui : mesure sur
le `.glb` livre, sa profondeur museau-queue est **2,0371** contre une hauteur de
**1,3501** et une largeur de **1,3198**. Le basculer de 90 deg autour de X met
sa PROFONDEUR a la verticale -- un axe de deux metres se dresse hors d'un lit
dont la literie dessinee fait un cinquieme de ca. **Rendu plutot qu'argumente :
le resultat est une queue qui sort de l'edredon avec le corps enterre dessous,
et rien qui se lise comme un ecureuil.** Le rouler autour de son propre axe
avant (`rotation.z = +90`) met sa LARGEUR a la verticale -- 1,32, moitie sous
l'origine -- et laisse le grand axe couche le long du lit.

**Corollaire mesure et facile a rater** : la portance pendant qu'il est couche
est `KEEPY_MODEL_MIN_X = -0,616405`, **pas** le `MIN_Y` debout de -0,629070 --
le roulis met son axe X a la verticale. Utiliser celui du debout enterrerait son
flanc de la difference.

**`REST_YAW_DEGREES = 20`** : l'axe long du lit court le long du X monde avec
l'oreiller en -X (lu sur un rendu avec des marqueurs monde poses dessus, pas
devine du layout). Un roulis de +90 pose deja sa tete vers -X sans tourner le
walker ; ce lacet est un trois-quarts vers la camera, pour que le visage ET la
queue se lisent au lieu d'un profil plat. Rendu a 0 / 5 / 20 / 35 ; **20** est
ou il cesse de ressembler a un decalque.

⚠️ **AUCUNE ANIMATION, ET AUCUNE N'EST POSSIBLE** : le `.glb` porte un noeud, un
mesh, **zero skin et zero animation** -- le meme constat que le lot hibou a
publie pour la meme famille d'assets. Toute pose de ce projet est un transform
sur le corps entier, et celle-ci en est une de plus.

**Le gate est le motif du BATEAU, jamais celui de l'echelle** : le lit
`set_busy(true)` pendant la sieste, **et l'echelle aussi** -- c'est la seule
autre chose tapable du loft, et rien ne doit changer d'etage en pleine sieste.
Tout tap tombe donc A TRAVERS vers `_on_tapped_ground`, ou il devient « leve-toi ».
Sortie = second tap, comme l'ancienne entree de cabane, sans minuterie.

⚠️ **Le chemin du lit appelle `_try_rest()` IMMEDIATEMENT apres `hop_to()`**,
parce que `LevelWalker._advance()` termine une marche de longueur nulle par
`became_idle` et **jamais** par `hop_landed`. Sans ca, taper le lit en se tenant
deja dessus ne ferait rien.

### ⚠️ DEFAUT PRE-EXISTANT TROUVE ET DELIBEREMENT NON CORRIGE

**Taper la PORTE en se tenant deja dessus ne fait rien**, par ce meme mecanisme :
`_exit_pending` est arme, la marche de longueur nulle n'emet que `became_idle`,
et l'intention reste armee pour toujours. Atteignable des le demarrage de la
scene, puisque `DOOR_SPOT == ENTRY_SPOT`. **Signale, pas elargi dans ce lot** --
le corriger touche le chemin de sortie de scene et merite sa propre passe.

### VALIDATION

**`CabinProbe` : 0 echec, exit 0** -- et les deux nouvelles phases verifiees
**ROUGE AVANT VERT**, chaque neutralisation revertee et le fichier re-compare :

| neutralisation | resultat |
|---|---|
| `_build_cabin_markers()` -> `return` | **PHASE M, 1 FAIL** (« one mark per cabin (0 marks, 1 cabins) ») |
| `_try_rest()` -> `return false` | **PHASE P, 7 FAIL** (ne se couche pas, l'intention n'est pas depensee, roulis 0,0 deg, sommet le plus bas a 7,5396 au lieu de 7,3686, ni le lit ni l'echelle ne se retirent, et taper le lit en se tenant dessus ne fait rien) |

⚠️ **UN BUDGET PARTAGE A DERIVE, ET C'EST MOI** : `_EXPECTED_DRAW_NODES_EXCL_PORTALS`
passe de **129 a 131** dans `SeesawProbe`, `TurnstileProbe` et `WaterTintProbe`.
**+2 et pas +3, itemise plutot que pousse** : un `CabinMarker` construit un pad,
un anneau et un `Label3D`, et un `Label3D` n'est ni un `MeshInstance3D` ni un
`MultiMesh` -- le compteur, par sa propre definition (`_count_draw`), n'a jamais
vu le panneau. Trouve parce que `SeesawProbe` a rapporte **3** echecs contre 2
sur la baseline ; apres correction il revient a ses **2** echecs pre-existants.

**Sondes partagees, diffees contre `origin/staging` en worktree separe** (import
verifie complet des deux cotes) :

| sonde | verdict |
|---|---|
| `LevelNavProbe` | **BYTE-IDENTIQUE** sur les DEUX flux -- 77 checks, **2 echecs PRE-EXISTANTS** (fade d'occlusion), donc pas les miens |
| `AssetContractAudit` | **BYTE-IDENTIQUE** -- 12/12 visuels, **0/10 colliders deplaces** |
| `DeathModelAudit`, `ChargerShapeProbe` | **BYTE-IDENTIQUES** sur les deux flux |
| `TurnstileProbe` | exit 1 des DEUX cotes, **meme echec unique pre-existant** (`entry 0's custom_aabb encloses every bar`) |
| `SeesawProbe` | exit 1 des deux cotes, **memes 2 echecs pre-existants** (banc diagonal a 45 s sous llvmpipe) |
| `WaterTintProbe` | **0 echec** (sous `xvfb`, jamais `--headless`) |
| `ProbeTimeoutAudit` | **59 scenes de sonde + 1 `--script`**, identique a la baseline -- retour exact apres suppression des sondes jetables |

**PHASE UNTOUCHED de `CabinProbe`** re-confirme les 3 portails et leurs routes,
les 3 plongeoirs, le hibou, le tourniquet, la balancoire et le bateau ; et que la
cible tapable la plus proche du pas de porte est la balancoire a **17,92 u**,
degagee du rayon de 1,3.

Import headless **exit 0, 36 `.scn`**. Export Web release **exit 0, 0 erreur
GDScript**. `index.wasm` **35 376 909** octets / md5
**`af4a8fc2925d992348eb30deeeb54360`**, `index.js` md5
**`4e08904b1b7107858246af44b602067b`** -- identiques au fingerprint permanent de
tout lot qui ne touche pas le code moteur. `index.pck` 30 276 096, **marqueur et
jamais preuve d'identite**. Piege payload tenu : sur **264** lignes
`Storing File`, **0** pour `scripts/dev`, `assets_source`, `docs`, `web`,
`build` ou `firebase.json`.

**RENDU DE VERIFICATION FOURNI**, a travers la camera FIXE de la scene interieure
livree, Keepy amene sur le lit par le VRAI chemin de code (`_on_tapped_hotspot`)
et non pose a la main : `docs/hub-shots/cabin_rest_pose.png` (couche) et
`cabin_rest_stand.png` (debout, meme point, meme camera, pour comparaison). La
sonde de capture a imprime `resting=true walker_y=7,36857 roll=90 yaw=20` --
c'est-a-dire exactement ce que `CabinProbe` asserte. **Verdict : il se lit comme
couche sur le lit** -- sur le flanc, enfonce dans la literie, tete du cote de
l'oreiller, la barriere du lit passant devant lui ; ni flottant, ni en travers
d'un mur.

⚠️ **Limite honnete du rendu** : son VISAGE est tourne de 90 degres avec le reste
de lui -- les yeux se retrouvent l'un au-dessus de l'autre. C'est litteralement
ce que « couche sur le flanc » veut dire pour un mesh unique sans squelette, et
ca se lit comme un ecureuil endormi -- mais une pose « tete sur l'oreiller,
visage vers la piece » demanderait un squelette que ce `.glb` n'a pas.

⚠️ **Piege de sonde re-rencontre, et il a coute deux runs** : ma premiere sonde
de capture appelait `LevelWalker.place_on()`, qui **n'existe pas**. Le
`SCRIPT ERROR` etait avale par un `| head -20` en bout de pipe (le trap deja
consigne : `head` ne peut pas flusher), donc le process a simplement tourne
jusqu'a son `timeout` de 600 s et **ressemblait a un rendu lent** au lieu d'une
erreur. Placer le walker se fait par `controller.set_current(1)` puis
`walker.global_position = level.flat(...)`, comme `CabinProbe` le fait deja.

### Reste ouvert -- jugement device, seul juge

1. **Le marqueur se voit-il et se lit-il depuis le hub** a l'echelle reelle d'un
   telephone -- 3,16:1 est mesure, la lisibilite ne l'est pas.
2. **Taper « Lit » donne-t-il une pose couchee credible**, et le second tap le
   releve-t-il ? Le visage tourne de 90 deg est la limite publiee ci-dessus.
3. **Le defaut pre-existant de la porte** (taper dessus en s'y tenant ne fait
   rien) -- signale, non corrige.
4. Si valide : retirer le bouton « < Sortir » (conditionne depuis le lot
   precedent, toujours pas fait), puis le lot 4/4 (migration du hub).
5. Rien ici n'est un rendu device : llvmpipe sous `xvfb` via le backend
   `opengl3` de BUREAU, contre WebGL2 sous Safari.

### Deploiement staging du marqueur d'entree + de la pose couchee (palier 1, automatique)

`staging` **`ac5937c`** (merge `--no-ff`, arbre **byte-identique** a la branche
feature : meme hash d'arbre `eb558d1` des deux cotes ET `git diff` vide, verifie
AVANT le push). CI run **#323** (id 33276322504) **verte** -- `Import project
resources` 21:32:57 -> 21:36:16, **`Export Web build` 21:36:16 -> 21:36:21**,
`Deploy to Vercel [STAGING -- staging]` **succes** 21:36:37 -> 21:36:50,
`[PRODUCTION -- main]` correctement **skipped**. **`main` NON touche**
(`origin/main` toujours `9031e5e`, verifie apres le push).

**Verifie SUR LE SERVICE, sur DEUX marqueurs independants et aux DEUX bouts** :

| marqueur | avant (run #322) | apres (ce lot, run #323) |
|---|---|---|
| `CACHE_VERSION` | `1788015452` = **14:57:32** | **`1788039380` = 21:36:20** |
| `index.pck` servi | **30 272 864** | **30 276 096** |
| `index.wasm` servi | 35 376 909 | **35 376 909** *(inchange, attendu)* |

L'epoch d'apres tombe **a l'interieur de la fenetre `Export Web build`**, et les
**deux lectures d'apres portent `x-vercel-cache: MISS` avec `age: 0`**.

⚠️ **Limite dite plutot que sous-entendue** : les deux valeurs AVANT ont ete
relevees **avant le merge** mais sur des reponses `HIT` avec un `age` non nul
(23 604 et 23 728 s). Elles sont valables comme **VALEURS** -- elles precedent
le push -- mais **ce ne sont PAS des mesures de fraicheur**.

⚠️ **Pour une fois `index.pck` servi EST identique a l'export local**
(30 276 096 des deux cotes). Ca ne change rien a la doctrine : c'est un
marqueur « nouveau build », **jamais** une preuve d'identite -- l'identite est
portee par `index.wasm` (md5 `af4a8fc2925d992348eb30deeeb54360`).

⚠️ **PIEGE D'ATTENTE RENCONTRE, ET IL A COUTE UNE FAUSSE ALERTE DE 40 MINUTES.**
Deux erreurs se sont composees. D'abord une boucle
`until [ -n "$(curl ... | grep -v ANCIENNE_VALEUR)" ]` sur
`keepy-staging.vercel.app` : **l'egress direct vers `*.vercel.app` est refuse
dans ce sandbox** (`http_code 000`, exit 56, re-teste et pas suppose), donc la
lecture rendait une chaine VIDE, qui est bien « differente de l'ancienne
valeur » -- la boucle serait sortie immediatement en annoncant un deploiement.
**Une garde d'attente qui ne verifie pas qu'elle a REELLEMENT lu quelque chose
confond « ca a change » et « je n'ai rien recu ».** Tuee avant de conclure quoi
que ce soit. Ensuite, `sleep` en avant-plan etant bloque, les attentes ont ete
lancees en arriere-plan puis **relues immediatement** : chaque `cat` du fichier
de sortie revenait vide en une seconde, si bien que ce qui ressemblait a
40 minutes d'import fige n'etait en realite que **2 minutes**. **Comparer
l'horloge du sandbox (`date -u`) a l'en-tete `date` de la reponse HTTP est ce
qui l'a tranche en une commande**, et c'est le meme reflexe que la regle
« ne jamais lire un etat de CI sans regarder son horodatage », applique a soi.
L'API Actions n'etait PAS perimee : l'import a reellement pris 3 min 19 s.

## MERGE EN PRODUCTION : LA CABANE — et les deux portes de debug fermees avant (29 aout 2026)

Branche `claude/keepy-production-merge-cleanup-3iuobt`, partie de `staging`
(`16e3579`). `staging` (`cc0d105`) -> `main`, commit de merge **`e3cffd5`**,
`--no-ff`, apres feu vert explicite de Mathieu suivant la validation device
complete de la chaine cabane (marqueur d'entree, pose sur le lit, sortie par
tap). **`main` avant : `9031e5e`.**

Regle n°1 verifiee AU DEBUT et par ARBRE, jamais par confiance dans un
numero annonce : `origin/main` = `9031e5e` et `origin/staging` = `16e3579`
exactement les SHA du brief, `merge-base(main, staging) = main` — **`staging`
est un strict sur-ensemble**, `staging..main` VIDE, aucune session
concurrente, aucun commit `.glb` brut a signaler cette fois. Arbre du merge
**byte-identique a `origin/staging`** (meme hash `9043a2c8`, `git diff` vide),
verifie AVANT le push : ce qui part en prod est litteralement l'arbre valide.

**Perimetre du merge : 40 fichiers**, la chaine cabane complete (install du
`.glb`, les trois causes d'entree parasite, echelle 11.0, interieur jouable,
occlusion camera, marqueur d'entree, pose couchee) plus le noyau de
navigation `scripts/nav/` — **garde, reutilise par la cabane, et sans
migration du hub**, decision actee et non rouverte ici.

### Ce que ce lot RETIRE, et ce qu'il garde deliberement

Les deux boutons de debug etaient ecrits pour ressortir, et **chacun le
disait dans son propre commentaire** — ce lot est celui-la.

* **`"Test nav (dev)"`** — aux trois sites exacts que son commentaire
  nommait : le noeud de `HubWorld.tscn`, le `@onready`, la connexion de
  signal et `_on_fallback_navtest()`. ⚠️ **`scripts/nav/` et
  `scenes/dev/LevelNavTest.tscn` sont CONSERVES** : la cabane est batie sur
  ce noyau, et le banc qui l'exerce vaut d'etre garde. Seule la **porte
  joueur** est fermee.
* **`"< Sortir"`** — le noeud, son `StyleBoxFlat` devenu orphelin
  (`load_steps` 6 -> 5), le `@onready`, la connexion et
  `_on_exit_pressed()`. **`_leave_to_hub()` reste** : la porte en est le
  seul appelant restant, et « ce que partir veut dire » garde un seul foyer.

⚠️ **La note architecturale accrochee a `_on_exit_pressed()` est DEPLACEE sur
`_leave_to_hub()`, pas supprimee avec le wrapper** — elle documente pourquoi
rien du pas de porte n'est calcule dans cette scene, c'est-a-dire
l'independance totale de ce fichier vis-a-vis du plateau. Ce fait survit au
bouton. `LevelNavTestWorld` disait dans son propre en-tete que le bouton du
hub y menait : **il n'y mene plus, donc il ne le dit plus.**

### ⚠️ TROIS PREMISSES DU BRIEF TOMBENT A LA MESURE

1. **« CabinProbe / LevelNavProbe dependent de ces deux boutons » — FAUX.**
   `grep` sur les deux sondes : **zero** occurrence de `ExitButton`,
   `_exit_button`, `_on_exit_pressed`, `NavTestButton`, `navtest` ou
   `"Test nav"`. Aucune assertion a retirer — la tache 3 de
   l'implementation etait **un no-op**, et c'est dit plutot que presente
   comme un travail fait.
2. **« Les scripts/scenes de test resteront hors du `.pck` s'ils ne sont
   plus references » — FAUX, et MESURE plutot que suppose.**
   `export_filter="all_resources"` packe **toute** ressource, referencee ou
   non, et `scenes/dev/*` n'est PAS dans l'`exclude_filter` (qui ne couvre
   que `scripts/dev/*`, `assets_source/*`, `docs/*`, `web/*`,
   `firebase.json`). Le log `savepack` porte **4 lignes `Storing File`** pour
   le banc : `LevelNavTestWorld.gdc`, `LevelNavTest.scn`, et leurs deux
   `.remap`. **Le retrait du bouton ne le depacke pas.** C'est exactement le
   piege payload deja consigne cinq fois dans ce fichier.
   ⚠️ **Cout mesure : ~6,7 Ko de `.scn` plus son `.gdc`, sur un `.pck` de
   30 274 320 octets — de l'ordre de 0,04 %.** **NON corrige, et c'est un
   choix** : toucher `export_presets.cfg` sur le merge le plus sensible du
   projet est un changement de configuration de build que rien n'a valide
   sur device, pour recuperer un dix-millieme du poids. Le banc est **inerte
   et injoignable** (aucun chemin de code livre ne l'ouvre) — c'est la
   propriete qui compte pour la production, et elle est acquise. A trancher
   dans son propre lot si le poids devient un sujet.
3. **« Echecs pre-existants a reconfirmer (LevelNavProbe occlusion, Seesaw,
   Turnstile) » — IL N'Y EN A AUCUN.** Les trois sont **vertes, 0 echec**,
   sur la branche ET sur `origin/staging` en worktree separe.
   `StreamRideProbe`, documentee rouge a un lot anterieur, est elle aussi
   **37 checks / 0 echec**. Il n'y avait donc rien a reconfirmer ni a
   epargner : **tout est vert des deux cotes.**

### ⚠️ LE DEFAUT DE PORTE PRE-EXISTANT : confirme, NON aggrave, NON corrige

Confirme dans le code plutot que suppose. `&"door"` appelle
`_walker.hop_to(destination)` **puis** arme `_exit_pending` ; une marche de
longueur nulle se termine par `became_idle` et **jamais** `hop_landed` (le
commentaire du lit le dit, et c'est pourquoi le lit — lui — porte un
`_try_rest()` immediat). **Taper la porte en s'y tenant deja n'a donc aucun
effet et laisse l'intention armee.**

⚠️ **Mais ce n'est PAS un soft-lock, et le retrait du bouton n'en cree pas
un** — verifie sur le chemin de recuperation et pas seulement plaide :
taper le sol ailleurs passe par la branche `_:`, qui **efface
`_exit_pending`** ; revenir et taper la porte a distance produit un vrai
atterrissage, donc une sortie. Le cout reel du defaut est **un tap perdu**
quand on est deja sur le pas de porte, pas un enfermement. **Hors perimetre,
non corrige ici** — c'est son propre lot, comme le brief le demande.

### Ce qui est PROUVE de l'absence des deux boutons, et ce qui ne l'est PAS

⚠️ **Le canal `.gdc` du `.pck` n'est PAS greppable, et un BLIND CHECK l'a
prouve avant que le zero soit compte.** `_on_fallback_navtest` et
`_on_exit_pressed` rendent **0** occurrence dans le `.pck` — mais
`_on_fallback_battle`, `_leave_to_hub`, `_try_rest` et `_on_hop_landed`, qui
**survivent tous**, rendent **0** eux aussi. **Ces zeros-la ne veulent donc
rien dire** et ne sont pas offerts comme preuve : une assertion d'absence
passe gratuitement quand le canal ne voit rien. C'est la discipline de blind
check deja etablie par `SeesawProbe`/`TurnstileProbe`, appliquee a ma propre
mesure.

Ce qui EST une preuve, sur un canal **demontre greppable** (`"Keepy Battle"`,
un libelle de `.tscn` qui survit, rend **2**) :

| chaine | dans le `.pck` |
|---|---|
| `"Test nav (dev)"` | **0** |
| `"NavTestButton"` | **0** |
| `"< Sortir"` | **0** |
| `"ExitButton"` | **0** |
| *(temoin)* `"Keepy Battle"` | **2** |

Et la preuve **fonctionnelle**, la seule qui compte vraiment : les deux
scenes touchees **bootent en headless sans une seule erreur de noeud**. Un
`@onready` laisse pendant sur un noeud supprime rendrait `null` puis
echouerait sur `.pressed.connect()` — un bouton qui n'existe pas dans la
scene ne peut de toute facon pas etre presse.

### Validation

Editeur + templates Godot 4.3-stable installes dans ce sandbox (releases
GitHub officielles, **tailles verifiees contre le `Content-Length`** :
**50 276 070** et **1 073 228 327** octets, aucune troncature silencieuse).
Import headless **exit 0, 36 `.scn`, 0 erreur** (import complet verifie des
deux cotes, pas suppose). Export Web release **exit 0, 0 erreur GDScript**.

`index.wasm` **35 376 909** octets / md5
**`af4a8fc2925d992348eb30deeeb54360`** et `index.js` md5
**`4e08904b1b7107858246af44b602067b`** — **identiques au fingerprint
permanent** de tout lot qui ne touche pas le code moteur, ce qu'un retrait de
deux boutons est. **Piege payload tenu** : sur **264** lignes `Storing File`,
**0** pour `scripts/dev`, `assets_source`, `docs`, `web/` ou `firebase.json`.

**Sondes, diffees contre `origin/staging` en worktree separe** (imports
verifies complets des deux cotes, 36 `.scn`), graine 20260806,
`--fixed-fps 60` :

| sonde | verdict |
|---|---|
| **`CabinProbe`** | **0 echec — BYTE-IDENTIQUE sur les DEUX flux** |
| **`LevelNavProbe`** | **77 checks, 0 echec — BYTE-IDENTIQUE** |
| `AssetContractAudit` | 12/12 visuels, **0/10 colliders deplaces**, identique |
| `DeathModelAudit` | identique |
| `ChargerShapeProbe` | **BYTE-IDENTIQUE sur les deux flux** |
| `ProbeTimeoutAudit` | **BYTE-IDENTIQUE**, **59 sondes scenes des DEUX cotes** |

⚠️ **`--fixed-fps 60` N'EST PAS OPTIONNEL ICI, et l'oublier fabrique un faux
diff.** Le premier passage de `LevelNavProbe` sans ce flag sortait
**different** des deux cotes — 20 vs 18 frames de marche, 71 vs 64 pour la
traversee, un pic d'arc a 0,599 contre 0,600. Aucune assertion ne bougeait :
c'etaient des **comptes de frames en temps mur**. Avec le flag, byte-identique.

⚠️ **Second faux diff, sur `AssetContractAudit` et `DeathModelAudit`** : leur
stdout differait, uniquement par des lignes `WARNING: ... invalid UID` **du
cote BASELINE seul** — un artefact du cache d'UID d'un worktree fraichement
importe, sans rapport avec ce lot. **Aucune ligne d'assertion ne differe** :
identiques une fois ces warnings filtres. Meme famille que le faux-rouge par
import tronque deja consigne, sur un autre canal.

**PHASE UNTOUCHED, tout le plateau, toutes exit 0 et 0 echec** :
`OwlFlightProbe` (hibou statique + vol), `DivingBoardProbe` (3 plongeoirs),
`TurnstileProbe` (tourniquet), `SeesawProbe` (balancoire), `StreamRideProbe`
(bateau, 37 checks), `LakeZoneProbe` (les corps d'eau), `WaterImpactProbe`,
`WaterTintProbe` — plus les 3 portails, verifies par les sondes qui les
couvrent.

### Reste ouvert

1. **Validation device en PRODUCTION** sur `keepy-ten.vercel.app` (Safari
   iPhone, navigation privee) : la cabane fonctionne, et **aucun bouton de
   debug n'est visible** — ni dans le menu de secours du hub, ni dans la
   cabane.
2. **Le defaut de porte** (un tap perdu quand on est deja sur le pas de
   porte) — confirme, recuperable, non aggrave, **son propre lot**.
3. **Le banc de nav packe pour ~0,04 %** — inerte et injoignable, a trancher
   dans son propre lot si le poids devient un sujet.

### Deploiement PRODUCTION verifie SUR LE SERVICE (29 aout 2026)

CI **run #326** (id 33279493147) **verte**, 22:48:55 -> 22:53:33 UTC —
`Import project resources` 22:49:39 -> 22:53:01, **`Export Web build`
22:53:01 -> 22:53:06**, **`Deploy to Vercel [PRODUCTION -- main]` succes**
22:53:22 -> 22:53:31, **`[STAGING -- staging]` correctement skipped** (push
sur `main`).

**Verifie sur `keepy-ten.vercel.app` — la PRODUCTION, pas
`keepy-staging.vercel.app`** — sur DEUX marqueurs independants, et les
lectures utiles sont **toutes `x-vercel-cache: MISS` avec `age: 0`** :

| marqueur | avant | apres |
|---|---|---|
| `CACHE_VERSION` | `1787948577` | **`1788043986` = 22:53:06 UTC** |
| `index.wasm` servi | — | **35 376 909** *(fingerprint permanent, inchange)* |
| `index.pck` servi | — | 30 274 320 |

L'epoch d'apres tombe **exactement sur la seconde de fermeture de l'etape
`Export Web build`**, et la valeur d'avant a ete relevee **avant le push**,
en MISS/age 0 elle aussi : **la bascule est prouvee dans les deux sens** et
pas deduite du log CI.

⚠️ **Le `index.pck` servi (30 274 320) est byte-identique a l'export local
de cette session — et ce n'est DELIBEREMENT PAS offert comme preuve
d'identite.** La doctrine du depot tient : le `.pck` est un marqueur
« nouveau build servi », jamais une preuve, parce que sa taille n'est pas
stable d'un export a l'autre du meme commit. Ici les deux coincident, ce
qui est agreable et sans valeur probante. **`index.wasm` reste la preuve
d'identite**, et il est au fingerprint permanent.

⚠️ **Un piege de MESURE de ma part, publie plutot que tu** : les premiers
`sleep` d'attente ont ete lances **en arriere-plan**, donc ils ne
bloquaient rien — deux lectures d'API separees de quelques secondes sont
revenues **byte-identiques** et avaient exactement la forme du piege
« API Actions perimee » deja consigne. **Ce n'en etait pas un** : il
suffisait de regarder l'horloge (2 minutes ecoulees depuis le push, import
en cours pour de vrai, qui a dure **3 min 22 s**). La regle vaut donc dans
les deux sens, et cette fois c'est moi qui ai failli l'appliquer a
l'envers. Le **404 lu au meme moment** sur la prod n'etait pas davantage
une panne : c'est la fenetre de ~3 min du deploiement NATIF Vercel, deja
documentee, refermee par le depot de la CI.

## L'ASSERTION DE FONDU D'OCCLUSION ETAIT FLAKY : elle budgetait des FRAMES pour un mecanisme qui converge en TEMPS (29 aout 2026)

Branche `claude/keepy-nav-camera-occlusion-cz7m5q`, ramenee sur `staging`
(`ebdd1dc`, alors identique a `main`). **UN SEUL fichier touche, et c'est une
sonde** : `scripts/dev/LevelNavProbe.gd`. `git diff --name-only` ne rend rien
sous `scripts/hub/`, `scripts/nav/`, `scripts/world/`, `scenes/`, `resources/`,
`project.godot` ni `export_presets.cfg` -- **aucune ligne de jeu ne bouge, et
`scripts/dev/*` est dans l'`exclude_filter`, donc le build livre est
rigoureusement identique.**

### ⚠️ D'ABORD, LA RECONCILIATION : RIEN N'AVAIT ETE PERDU

Le redemarrage de conteneur du lot occlusion avait laisse une lecture faussee
-- le log de `origin/staging` ne montrait plus mes commits en tete, et j'en
avais conclu a une divergence. **Verifie plutot que suppose** :
`git merge-base --is-ancestor` rend **YES** pour `2ecf722`, `026bcc4` et
`8bad644` contre `origin/staging` **ET** contre `origin/main`. Ils etaient
simplement 20 commits plus bas, sous le lot cabane qui a suivi. **Le fondu
d'occlusion est donc EN PRODUCTION**, emporte par le merge de prod de la
cabane, et la cabane s'appuie dessus (`LevelHotspot`/la geometrie cabane
rejoignent `level_occluder`).

**Regle a retenir : ne jamais conclure a une divergence sur les 3 premieres
lignes d'un `git log`.** La question est une question d'ANCETRALITE, et
`git merge-base --is-ancestor` y repond en une commande.

### LE DEFAUT : les deux assertions de relachement dependaient de la VITESSE DE LA MACHINE

Deux sessions successives ont rapporte `LevelNavProbe` differemment sur du
**code identique au bit pres** (`git diff 2ecf722 origin/staging` sur
`LevelCamera.gd` et `LevelNavProbe.gd` : **vide**) :

| session | verdict |
|---|---|
| lot occlusion (la mienne) | **77 checks, 0 echec** |
| lot cabane (intermediaire) | **77 checks, 2 echecs**, `alpha 0.997`, « byte-identique des deux cotes » |
| lot merge de prod | **77 checks, 0 echec**, « il n'y en a aucun » |

⚠️ **La session intermediaire a range ces deux echecs comme « pre-existants,
donc pas les miens ». Ils n'etaient ni pre-existants ni du bruit : ils etaient
MON assertion, et elle est FLAKY.** `LevelCamera` converge par
`exp(-FADE_LAMBDA * delta)`, donc la distance parcourue par un fondu depend du
**TEMPS ECOULE** et jamais du nombre de frames -- pendant que la sonde
budgetait `_pump(90)`, c'est-a-dire des FRAMES. Le relachement ne se pose
exactement sur 1.0 qu'au-dela de **~0,68 s** ; en dessous il s'arrete a 0,99x,
et la seconde assertion tombe avec (la transparence ne repasse a DISABLED qu'A
1.0 -- d'ou une paire d'echecs, jamais un seul).

**MESURE, pas deduit** : 45 frames ont coute **914 ms** sur une machine chargee
et **493 ms** sur une machine calme, dans la meme session. Une boite ~3x plus
rapide fait donc 90 frames en ~0,6 s -- et 0,6 s, c'est **alpha 0.997**, le
chiffre exact rapporte.

**REPRODUIT AVANT D'ETRE CORRIGE** : pump ramene a 25 frames (493 ms ici) ->
**`77 checks, 2 failure(s)`, `alpha 0.991`, exit 1** -- la meme paire, la meme
forme.

### LE FIX : attendre la CONDITION sur un budget mur, pas un compte de frames

`_pump(frames)` est **remplacee** par `_settle_alpha(node, wanted)`, qui boucle
jusqu'a ce que l'alpha atteigne reellement sa valeur cible, avec
`FADE_SETTLE_BUDGET_MS = 4000` (~6x ce dont le mecanisme a besoin). Les trois
attentes de fondu passent dessus -- les deux fondus ENTRANTS aussi, qui etaient
fragiles de la meme facon (`_pump(60)` contre un seuil `< 0.5` : ~0,12 s
requis, ce que 60 frames rapides ne garantissent pas non plus).

⚠️ **Elle prend le NOEUD et pas le materiau** : au premier fondu l'override
n'existe pas encore, c'est `LevelCamera` qui le cree -- une aide a qui on
passerait un materiau d'avance recevrait `null`.

⚠️ **LE PLAFOND EST UN VRAI ECHEC, PAS UNE FORMALITE, ET C'EST PROUVE** :
ecriture du materiau de `_advance_fades` neutralisee -> **`77 checks, 3
failure(s)`, exit 1, en 17 s** (les trois budgets plus le reste), sans
blocage. `LevelCamera.gd` restaure byte-identique apres coup (`git diff` vide).

**Apres fix : trois runs, `77 checks, 0 failure(s)` chacun, et les alphas
atterrissent desormais sur des valeurs EXACTES** -- 0.250 aux deux fondus
entrants, 1.000 au relachement, la ou ils flottaient a 0.99x.

⚠️ **AU PASSAGE, UNE AFFIRMATION DU LOT PRECEDENT EST CORRIGEE :
`LevelNavProbe` N'EST PAS byte-stable, et ne l'a jamais ete.** Trois runs
consecutifs sur le MEME arbre donnent trois stdout differents -- les comptes de
frames des tweens de marche et de traversee (`36/34/35 frames`,
`127/126/128`, ...) bougent avec la charge machine, exactement comme
`SwampIdentityAudit` et `TrackPropsAudit` deja consignees. **Le « BYTE-IDENTIQUE
sur les DEUX flux » d'un lot precedent etait une COINCIDENCE** (meme machine,
deux runs dos a dos), pas une propriete. Ces lignes-la sont **rapportees et
jamais assertees**, donc elles ne peuvent pas produire de faux rouge -- mais le
critere pour cette sonde est le VERDICT, pas les octets. **stderr, lui, EST
byte-identique sur les trois runs.**

### Validation

Import headless **exit 0, 36 `.scn`, 0 erreur** (import complet verifie, pas
suppose). Export Web release **exit 0, 0 erreur GDScript ou de parse**.
`index.wasm` **35 376 909** / md5 **`af4a8fc2925d992348eb30deeeb54360`**,
`index.js` md5 **`4e08904b1b7107858246af44b602067b`** -- le fingerprint
permanent, comme il se doit pour un lot qui ne touche aucun fichier de jeu.
`index.pck` 30 274 288, marqueur et **jamais** preuve d'identite. Piege payload
tenu : sur **264** lignes `Storing File`, **0** pour `scripts/dev`,
`assets_source`, `docs`, `web/`, `build` ou `firebase.json`.

Sondes, **toutes exit 0** : `LevelNavProbe` (**77/0**, trois fois),
`ProbeTimeoutAudit` (**59 sondes scenes + 1 `--script`**, inchange -- ce lot
n'ajoute ni ne retire de sonde), `AssetContractAudit` (**12/12 visuels, 0/10
colliders deplaces**), `DeathModelAudit`, `ChargerShapeProbe`.

⚠️ **Non-applicabilite du reste ASSUMEE et dite plutot que deguisee en
preuve** : aucun diff baseline n'est joue pour les sondes partagees, parce que
le diff de ce lot est **un unique fichier de `scripts/dev/`** qu'aucune d'elles
ne reference -- la seule qui le LIT est `ProbeTimeoutAudit`, verte au meme
compte.

### Reste ouvert

1. ⚠️ **Le jugement device du fondu d'occlusion lui-meme reste ENTIER et
   n'est PAS touche par ce lot** : le risque alpha deja paye sur l'eau (vert en
   sandbox, casse sur Safari iOS/WebGL2 a certains azimuts) n'a toujours ete
   ecarte par aucun test device. Ce lot fiabilise une SONDE ; il ne dit rien du
   telephone.
2. **`SeesawProbe` « 2 echecs pre-existants (banc diagonal a 45 s sous
   llvmpipe) »** rapportes par la meme session intermediaire sont **la meme
   famille** -- c'est le piege d'ordre des flags deja consigne (`--fixed-fps
   60` omis), pas un defaut. Signale, **non corrige ici**.

### Deploiement staging du fix de flakiness (palier 1, automatique)

`staging` **`ea77e7f`** (merge `--no-ff`, arbre **byte-identique** a la branche
feature : meme hash d'arbre `f3d15cf` des deux cotes ET `git diff` vide, verifie
AVANT le push). CI run **#330** (id 33282001964) **verte** -- `Import project
resources` 23:53:35 -> 23:56:22, **`Export Web build` 23:56:22 -> 23:56:27**,
`Deploy to Vercel [STAGING -- staging]` **succes** 23:56:41 -> 23:56:51,
`[PRODUCTION -- main]` correctement **skipped**. **`main` NON touche**
(`origin/main` toujours `ebdd1dc`, verifie apres le push).

**Verifie SUR LE SERVICE, pas dans le log CI, et AUX DEUX BOUTS EN MISS/age 0
-- la forme la plus forte que ce fichier documente** :

| | `CACHE_VERSION` | = UTC | lecture |
|---|---|---|---|
| avant (run #329) | `1788044568` | **23:02:48** | **MISS, age 0** |
| **apres (ce lot, run #330)** | **`1788047786`** | **23:56:26** | **MISS, age 0** |

L'epoch d'apres tombe **a l'interieur de la fenetre `Export Web build`**
(23:56:22 -> 23:56:27). Pour une fois **aucune des deux lectures n'est un
`HIT`** : la valeur d'avant a ete relevee juste apres le push, avant que la CI
n'ait exporte, sur une reponse fraiche.

`GODOT_CONFIG.fileSizes` lu au meme moment (MISS/age 0 lui aussi) :
**`index.wasm` 35 376 909** -- identique a l'export local et au fingerprint
permanent -- et `index.pck` 30 274 304 contre **30 274 288** en export local
propre, **16 octets d'ecart**, l'instabilite deja consignee.

⚠️ **Limite dite plutot que sous-entendue** : `fileSizes` n'a ete lu qu'APRES,
donc il vaut comme marqueur d'ETAT COURANT et **pas** comme preuve de
transition ; c'est le `CACHE_VERSION`, lu aux deux bouts en MISS/age 0, qui
porte la bascule.

⚠️ **Le contenu de JEU deploye est rigoureusement IDENTIQUE a celui d'avant** :
le seul fichier de code de ce lot est sous `scripts/dev/`, exclu du pack.
`index.wasm` inchange le confirme. Ce deploiement n'existe que parce qu'un push
sur `staging` en declenche un ; il n'y a rien de neuf a regarder sur device
**pour ce lot-ci**.

⚠️ **L'API GitHub Actions n'etait PAS perimee sur ce run**, et c'est note dans
ce sens-la : les appels successifs ont rendu de vraies progressions d'etapes
avec de vrais horodatages, et l'import a reellement pris **2 min 47 s**. Le
piege existe ; il ne s'est pas produit ici, et le verifier coute un regard a
l'horloge.

## LA PORTE DE LA CABANE JETAIT LE PREMIER TAP DE CHAQUE VISITE (31 aout 2026)

Branche `claude/keepy-session-handoff-8cl1o6`, partie de `staging`
(`849e7da`). Regle n°1 verifiee AU DEBUT et par ARBRE, jamais par nom :
`origin/main` = `ebdd1dc`, `origin/staging` = `849e7da` (3 commits devant,
`CLAUDE.md` + `LevelNavProbe.gd` uniquement), `staging..main` VIDE, et la
seule branche plus recente que `main` est deja ancetre de `staging`
(`merge-base --is-ancestor`) -- **aucune session concurrente**.

⚠️ **DEROGATION DE BRANCHE, SIGNALEE** : le nom impose par l'environnement
(`keepy-session-handoff`) ne decrit pas ce lot. Meme arbitrage que les lots
precedents ou la contrainte d'environnement et le sujet se contredisent --
le nom designe l'emporte, et l'ecart est dit plutot que tu.

**DEUX fichiers, verifies par `git diff --stat`** :
`scripts/cabin/CabinInterior.gd` et `scripts/dev/CabinProbe.gd`. Ni
`scripts/hub/`, ni `scripts/nav/`, ni une scene, ni un `.tres`, ni un
`.glb`.

### LA CAUSE, LUE DANS LE CODE LIVRE ET PAS DEDUITE DU RAPPORT

`LevelWalker._advance()` termine une marche plus courte qu'`ARRIVE_EPSILON`
(0,45) par **`became_idle.emit()`** (ligne 276) et **jamais** par
`hop_landed.emit()` (ligne 349, reserve au chemin d'un vrai hop). La
branche `&"door"` de `_on_tapped_hotspot` appelait `hop_to()` puis armait
`_exit_pending` -- et **seul `_on_hop_landed` pouvait le depenser**. Le tap
n'atteignait donc rien, et laissait une intention armee derriere lui.

⚠️ **L'ASYMETRIE ETAIT EXPLICITE DANS LE FICHIER LUI-MEME.** La branche
`&"bed"`, dix lignes plus bas, porte un `_try_rest()` immediat avec un
commentaire ⚠️ qui **enonce exactement ce mecanisme**. La porte n'a jamais
eu sa moitie. C'est la forme la plus couteuse de defaut de ce depot : pas
un mecanisme inconnu, un mecanisme **deja compris, ecrit, et applique a un
seul des deux cotes d'une paire**.

**Trois precisions que la mesure ajoute au rapport de passation :**

| | |
|---|---|
| **portee reelle** | pas « exactement sur le pas de porte » mais **tout le disque de rayon `ARRIVE_EPSILON` = 0,45**. `DOOR_TAP_RADIUS` vaut 0,85, donc il existe une couronne ou le tap est accepte et la marche nulle. |
| **atteignable au demarrage** | `DOOR_SPOT := ENTRY_SPOT` -- distance **0,000** a l'apparition, mesuree par la sonde. Le tout premier tap possible d'une visite. Pas un cas de bord : l'etat par defaut de la piece. |
| **pas un soft-lock** | verifie sur le chemin de recuperation, pas plaide : `_on_tapped_ground`, la branche `&"bed"` et `_on_tapped_transition` remettent tous `_exit_pending = false`. Cout reel = **un tap perdu**. |

### ⚠️ UN SECOND DEFAUT SOUPCONNE, MESURE, ET INEXISTANT

`_on_hop_landed` comparait a `DOOR_SPOT` **en XZ sans jamais demander sur
quel NIVEAU** l'atterrissage avait eu lieu -- donc un atterrissage sur la
mezzanine dans le rayon de la porte aurait termine la visite depuis
l'etage, c'est-a-dire un changement de scene que personne n'a demande.

**Il ne le peut pas** : le point du loft le plus proche
(`LOFT_CENTRE (-0,70 ; -1,32)` +- 1,10) est a **1,583** de
`DOOR_SPOT (0,60 ; 1,35)`, contre un `DOOR_REACH` de 0,9.

⚠️ **Mais c'est un fait sur DEUX RECTANGLES, pas sur le code** : deplacer
le loft ou elargir la portee le casserait **en silence**. Il est donc
desormais **gate** dans `CabinProbe` PHASE K, derive des constantes livrees
plutot que recopie -- la sonde imprime `1.583 vs 0.900`, le chiffre calcule
a la main puis confirme par le code.

### LE CORRECTIF : la forme du LIT, pas une nouvelle doctrine

La sortie inline de `_on_hop_landed` est extraite en **`_try_exit() -> bool`**,
copie exacte de la forme de `_try_rest()` : elle demande au **WALKER** ou il
est plutot que de croire un argument, precisement parce qu'elle a **deux
appelants** -- l'atterrissage, et le tap lui-meme quand la marche est nulle,
qui n'a aucun atterrissage a lui tendre. `_on_hop_landed` delegue, et sa
signature passe a `_position` (le parametre n'est plus lu).

⚠️ **AUCUNE GARDE SUR `_resting`, et l'omission est deliberee** : se coucher
se passe sur le LOFT, et l'invariant ci-dessus interdit a un point du loft
d'atteindre la porte. Une garde qui ne peut jamais tirer est une garde que
personne ne lit -- la geometrie est assertee a la place.

⚠️ **CONSEQUENCE NOMMEE DANS LE CODE PLUTOT QUE DECOUVERTE PLUS TARD : il
part desormais SANS MARCHER partout dans `DOOR_REACH`, pas seulement a
l'arret.** Entre 0,45 et 0,9 la marche est reelle mais il est deja assez
pres pour etre arrive, donc l'appel immediat depense l'intention. **Ce
n'est pas un effet de bord du correctif** : c'est ce que le lit livre fait
depuis toujours -- meme `BED_REACH` de 0,9, meme appel immediat -- et faire
diverger les deux serait la plus etrange des deux reponses.

### ROUGE AVANT VERT, sur la scene que le VRAI ROUTEUR charge

`CabinProbe` gagne **PHASE Z**, et elle tourne **en tout dernier, apres
PHASE R** : partir est un changement de scene, donc rien ne peut la suivre.

⚠️ **Elle est pilotee sur `tree.current_scene` -- l'interieur que PHASE R
vient de faire charger par le vrai routeur -- et NON sur une instance
fraiche.** C'est la scene qu'un joueur a sous les yeux une frame apres avoir
tape le pas de porte dehors, avec le walker la ou la scene le pose : ce qui
est mesure est donc le vrai premier tap et pas une reconstitution.

**Son CONTROLE est ce qui donne un sens a l'assertion** : sans lui, un
walker place loin ferait mesurer une marche ordinaire, qui n'a jamais ete
cassee. La sonde imprime **`he starts within a zero-length walk of the door
(0.000 <= 0.450)`** avant d'avoir le droit de conclure.

| | resultat |
|---|---|
| **avant le correctif** | **exit 1, 3 FAIL** -- « tapping the door while ALREADY on it leaves at once », « leaves no exit intent standing », « the door withdrew ». Les trois lignes de controle deja VERTES. |
| **apres** | **0 failure(s), exit 0** |

### VALIDATION

Editeur + templates Godot 4.3-stable installes dans ce sandbox (releases
GitHub officielles, **tailles verifiees contre le `Content-Length`** :
**50 276 070** et **1 073 228 327** octets, aucune troncature silencieuse).
Import headless **exit 0, 36 `.scn`** -- **des DEUX cotes**, verifie et pas
suppose. Export Web release **exit 0**, **0 erreur GDScript** (l'unique
ligne `ERROR` du log est `audio_driver_alsa.cpp:90`, le bruit ALSA sous
xvfb deja consigne).

`index.wasm` **35 376 909** octets / md5
**`af4a8fc2925d992348eb30deeeb54360`** et `index.js` md5
**`4e08904b1b7107858246af44b602067b`** -- identiques au fingerprint
permanent de tout lot qui ne touche pas le code moteur, ce que deux fichiers
GDScript sont. `index.pck` 30 274 480, **marqueur et jamais preuve
d'identite**. **Piege payload tenu** : sur **264** lignes `Storing File`,
**0** pour `scripts/dev`, `assets_source`, `docs`, `web/`, `build` ou
`firebase.json`.

**HUIT sondes diffees contre `origin/staging` en worktree separe** (imports
verifies complets des deux cotes, **TAILLES comparees avant les contenus** --
la lecon de la troncature de run) :

| sonde | verdict |
|---|---|
| `ProbeTimeoutAudit` | **BYTE-IDENTIQUE (2 flux)** -- **59 sondes scenes des deux cotes** : ce lot ajoute une PHASE, pas une sonde |
| `AssetContractAudit` | **BYTE-IDENTIQUE (2 flux)** |
| `DeathModelAudit` | **BYTE-IDENTIQUE (2 flux)** |
| `ChargerShapeProbe` | **BYTE-IDENTIQUE (2 flux)** |
| `LevelNavProbe` | **BYTE-IDENTIQUE (2 flux)**, 0 FAIL |
| `SeesawProbe` | **BYTE-IDENTIQUE (2 flux)**, 0 FAIL |
| `TurnstileProbe` | **BYTE-IDENTIQUE (2 flux)**, 0 FAIL |
| `WaterTintProbe` | **BYTE-IDENTIQUE (2 flux)**, 0 FAIL |
| **`CabinProbe`** | **diff = EXACTEMENT les 9 lignes ajoutees**, stderr **byte-identique** |

⚠️ **Le diff de `CabinProbe` est la mesure qui compte le plus** : aucune
assertion existante ne bouge d'un caractere -- ni le « pass-through landing
KEEPS the intent », ni les refus de PHASE T et PHASE F, ni le retrait facon
bateau. Le correctif ne deplace aucun comportement deja teste.

Cinq sondes de plus, jouees sur la branche, **toutes exit 0 / 0 FAIL** :
`StreamRideProbe`, `LakeZoneProbe`, `WaterImpactProbe`, `OwlFlightProbe`,
`DivingBoardProbe`.

⚠️ **CORRECTION A LA PASSATION, MESUREE** : elle annonce `SeesawProbe` et
`TurnstileProbe` comme portant des « echecs pre-existants ». **Elles sont
VERTES des deux cotes** (0 FAIL, exit 0). Le piege d'ordre des flags --
`--fixed-fps 60`, sans lequel le banc de traversee tourne a la vitesse du
mur sous llvmpipe -- etait bien la cause historique, et il est passe ici.

### Reste ouvert

1. **Jugement device, seul juge** : taper « Sortir » en se tenant sur le pas
   de porte ressort-il immediatement, et le comportement dans la bande
   0,45-0,9 (partir sans marcher) se sent-il juste ? Rien ici n'est un rendu
   device -- llvmpipe sous `xvfb` via le backend `opengl3` de BUREAU, contre
   WebGL2 sous Safari.
2. **Le banc de nav toujours packe** (~0,04 % du `.pck`), inerte et
   injoignable -- inchange, son propre lot.
3. Les autres chantiers de la passation sont inchanges.

### Deploiement staging du correctif de porte (palier 1, automatique)

`staging` **`830ed3a`** (merge `--no-ff`, arbre **byte-identique** a la
branche feature : meme hash d'arbre `24084df9` des deux cotes ET `git diff`
vide, verifie AVANT le push). CI run **#332** (id 33368511038) **verte** --
`Import project resources` 07:29:11 -> 07:32:30 (3 min 19 s), **`Export Web
build` 07:32:30 -> 07:32:36**, `Verify export output` succes, `Deploy to
Vercel [STAGING -- staging]` **succes** 07:32:54 -> 07:33:06,
`[PRODUCTION -- main]` correctement **skipped**. **`main` NON touche**
(`origin/main` toujours `ebdd1dc`, verifie apres le push).

**Verifie SUR LE SERVICE, pas dans le log CI, sur DEUX marqueurs
independants** :

| marqueur | avant | apres (ce lot, run #332) |
|---|---|---|
| `CACHE_VERSION` | **`1788048180` = 30 aout 00:03:00 UTC** | **`1788161555` = 07:32:35 UTC** |
| `index.pck` servi | -- | 30 274 480 |
| `index.wasm` servi | -- | **35 376 909** |

L'epoch d'apres tombe **a l'interieur de la fenetre `Export Web build`**
(07:32:30 -> 07:32:36) : l'alias sert bien ce build.

⚠️ **Pour une fois LES DEUX BOUTS du `CACHE_VERSION` sont lus en
`x-vercel-cache: MISS` avec `age: 0`**, la valeur d'avant ayant ete relevee
**avant le push** -- c'est la forme la plus forte que ce fichier documente,
et non le cas habituel ou le « avant » sort d'un `HIT` a age non nul.

⚠️ **Limite dite plutot que sous-entendue** : `index.pck`/`index.wasm` n'ont
ete lus qu'APRES, donc ils valent comme marqueur d'etat courant et **pas**
comme preuve de transition -- c'est le `CACHE_VERSION` qui la porte.

⚠️ **`index.pck` servi (30 274 480) est identique a l'export local, et ce
n'est DELIBEREMENT PAS offert comme preuve d'identite** : la doctrine tient,
sa taille n'est pas stable d'un export a l'autre du meme commit et la
coincidence n'y change rien. **`index.wasm` reste la preuve d'identite**, au
fingerprint permanent des deux cotes.

⚠️ **L'API Actions n'etait PAS perimee sur ce run**, note dans ce sens-la :
un seul appel a rendu les 18 etapes avec de vrais horodatages, et l'import a
reellement pris **3 min 19 s**. Le piege existe ; il ne s'est pas produit
ici, et le verifier coute un regard a l'horloge -- ce qui a d'ailleurs servi
une fois de plus dans l'autre sens, un `sleep` en arriere-plan relu
immediatement ne montrant que **37 secondes** ecoulees.

## MERGE EN PRODUCTION : LE CORRECTIF DE LA PORTE CABANE (31 aout 2026)

`staging` (`6b45744`) -> `main`, commit de merge **`d6e17ff`**, `--no-ff`,
apres feu vert explicite de Mathieu suivant validation device : sortie
immediate depuis le pas de porte OK, bande 0,45-0,9 sans marche visible OK,
coherent avec la pose sur le lit deja en production.

**Verifie AVANT tout push** : `git fetch --all --prune`, `origin/staging`
(`6b45744`) et `origin/main` (`ebdd1dc`) exactement les SHA annonces par le
brief -- aucune derive de staging depuis le dernier commit valide sur
device, aucune session concurrente. Merge `--no-ff` sans conflit ; **diff
de l'arbre resultant contre l'arbre de `staging` au commit `6b45744` :
VIDE** (`git diff HEAD origin/staging` vide, meme hash d'arbre
`3c66c975...` des deux cotes) -- ce qui part en prod est litteralement
l'arbre valide, pas une recomposition.

**Build local, editeur + templates Godot 4.3-stable installes dans ce
sandbox** (releases GitHub officielles, tailles verifiees contre le
`Content-Length` avant extraction -- 50 276 070 et 1 073 228 327 octets,
aucune troncature). Import headless **exit 0, 36 `.scn`** (import complet,
pas suppose). **Piege d'auto-contamination rencontre et corrige** : un
premier export sans `rm -rf build/` a fait re-importer les PNG produits par
lui-meme comme ressources de projet (7 lignes `Storing File: res://build/*`
dans le log) -- refait proprement (`rm -rf build .godot` avant l'import),
et le second export est **propre : 0 ligne `Storing File` pour
`scripts/dev`, `assets_source`, `docs`, `web`, `build` ou `firebase.json`**.
`index.wasm` **35 376 909** octets / md5 **`af4a8fc2925d992348eb30deeeb54360`**,
`index.js` md5 **`4e08904b1b7107858246af44b602067b`** -- identiques au
fingerprint permanent de tout lot qui ne touche pas le code moteur.

CI **run #334** (id `33371986746`) **verte** (08:14:42 -> 08:19:19 UTC) --
`Import project resources` 08:15:18 -> 08:18:37, `Export Web build`
**08:18:37 -> 08:18:43**, `Deploy to Vercel [PRODUCTION -- main]` **succes**
08:18:59 -> 08:19:17, `Deploy to Vercel [STAGING -- staging]` correctement
**skipped** (push sur `main`, comme attendu pour ce lot -- pas de skip cote
production ici).

**Verifie SUR LE SERVICE, uniquement sur `keepy-ten.vercel.app` (jamais
`keepy-staging.vercel.app`)**, sur DEUX marqueurs independants, tous deux
`x-vercel-cache: MISS` / `age: 0` :

| marqueur | valeur servie |
|---|---|
| `CACHE_VERSION` | `1788164322` = **08:18:42 UTC** -- tombe exactement dans la fenetre `Export Web build` (08:18:37 -> 08:18:43) |
| `index.wasm` servi | **35 376 909** octets, md5 identique a l'export local -- preuve d'identite |
| `index.pck` servi | 30 274 480 octets -- marqueur "nouveau build", jamais offert comme preuve seule |

⚠️ **Aucune lecture "avant" live n'a ete prise sur la production avant le
merge** (le push a precede toute lecture HTTP de ce lot) -- signale plutot
que masque. La transition est corroboree par comparaison a la fenetre
`Export Web build` du dernier deploiement production connu (run #328/#329,
`ebdd1dc` : 29 aout 23:02:32 -> 23:02:37 UTC), soit un ecart de **~46 h**
avec le `CACHE_VERSION` desormais servi -- non ambigu, mais c'est une
corroboration historique et pas la forme la plus forte (deux lectures
fraiches aux deux bouts) que ce fichier documente ailleurs.

**Le correctif de la porte de la cabane (sortie immediate depuis le pas de
porte, bande de flottaison 0,45-0,9 sans marche visible) est desormais EN
PRODUCTION** sur `keepy-ten.vercel.app`.

**Reste ouvert : aucun sur ce merge.** `main` pointe sur `d6e17ff`.

### Prochaine etape

Lot pie/bisou (prompt deja scope et livre separement) -- recon obligatoire
avant toute implementation, comme prevu dans son propre brief.

