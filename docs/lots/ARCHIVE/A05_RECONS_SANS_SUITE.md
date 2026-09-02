# ARCHIVE — recons sans suite et lots arrêtés

> Extrait de `CLAUDE.md` par le LOT H (2 septembre 2026), **verbatim** : aucune ligne réécrite, résumée ni supprimée.
> 8 section(s), 1762 lignes d'origine.
> Doctrine permanente : voir `CLAUDE.md`. Index des chantiers : `docs/lots/INDEX.md`.

## LOT D (plateau 25 -> 35) : ARRETE EN RECON — le seuil de traversee du brief est FRANCHI, aucun changement applique (25 aout 2026)

Branche `claude/keepy-plateau-radius-35-3sq42r`. **Ce lot ne modifie AUCUN
fichier de jeu** : ni `HubTapInput.PLATEAU_HALF_EXTENT`, ni
`resources/hub/hub_layout.tres`, ni `HubBuilder.gd`, ni la camera, ni le
hopper. Le brief posait un seuil d'arbitrage explicite sur R1 et ce seuil
est franchi — **il n'y avait donc rien a coder, seulement a mesurer et a
rapporter.** La decision appartient a Mathieu, elle n'est pas technique.

⚠️ **Ecart de ref au demarrage, signale plutot que passe sous silence.** Le
brief annonce `origin/main = ffcc552` — exact — et demande une branche
partie de `main`. Mais `docs/HUB_PERF_BASELINE.md` et
`scripts/dev/HubPerfBaseline.{gd,tscn}`, que la tache 5 exige de rejouer,
**n'existent QUE sur `staging`** (5 commits d'avance, le lot baseline perf
du matin meme). Branche partie de `origin/staging` (`a17d6ed`) en
consequence : partir de `main` aurait rendu la tache 5 litteralement
impossible. Regle n°1 verifiee AU DEBUT — `origin/staging` est la ref la
plus recente du depot (09:58:46), aucune session concurrente.

### R1 — TRAVERSEE : le seuil de 22 s est FRANCHI (23,10 s), c'est le STOP

Methode du lot C reprise a l'identique : hopper LIVRE, chaine de bonds
reelle, `--fixed-fps 60`, comptage de frames entre `hop_to()` et
`became_idle`. **Les deux trajets de reference au rayon 25 ont ete rejoues
dans le meme run** pour valider le banc avant de lui faire confiance sur
les nouveaux — ils reproduisent les chiffres publies **au bond et au
centieme pres**.

| trajet | distance | bonds | temps |
|---|---|---|---|
| **[ref 25] centre -> bord (25,0)** | 25,00 u | **17** | **5,95 s** *(publie lot C : 17 / 5,95)* |
| **[ref 25] coin a coin (-25,-25)->(25,25)** | 70,71 u | **47** | **16,45 s** *(publie lot C : 47 / 16,45)* |
| centre -> bord (35,0) | 35,00 u | 24 | **8,40 s** |
| centre -> bord (0,-35) | 35,00 u | 24 | 8,40 s |
| centre -> coin diagonal (35,35) | 49,50 u | 33 | **11,55 s** |
| **coin a coin (-35,-35)->(35,35)** | 98,99 u | **66** | **23,10 s** |

**Delta contre le lot C, pas seulement les valeurs brutes** : centre->bord
**5,95 -> 8,40 s (+2,45 s, +41,2 %)** ; coin a coin **16,45 -> 23,10 s
(+6,65 s, +40,4 %)**. L'echelle est lineaire en distance, comme elle doit
l'etre — un bond coute `HOP_DURATION` quelle que soit la taille du plateau.

⚠️ **`23,10 s > 22 s` — le STOP du brief se declenche.** Le brief le posait
comme un arbitrage de Mathieu et pas une decision technique : **aucun
levier n'a donc ete applique**, et `HOP_DISTANCE`/`HOP_DURATION` sont
byte-intouches.

**Les leviers, chiffres sur le trajet qui declenche le STOP (98,99 u), pour
que l'arbitrage se fasse sur des nombres et pas sur une intuition :**

| levier | coin a coin | centre -> bord (35 u) |
|---|---|---|
| **aucun (etat actuel)** | **66 bonds — 23,10 s** | 24 bonds — 8,40 s |
| `HOP_DISTANCE` 1,5 -> 1,75 | 57 bonds — 19,95 s | — |
| `HOP_DISTANCE` 1,5 -> **2,0** | 50 bonds — **17,50 s** | 18 bonds — 6,30 s |
| `HOP_DISTANCE` 1,5 -> **2,5** | 40 bonds — **14,00 s** | 14 bonds — 4,90 s |
| `HOP_DURATION` 0,35 -> 0,32 | 66 bonds — 21,12 s | — |
| `HOP_DURATION` 0,35 -> **0,28** | 66 bonds — **18,48 s** | 24 bonds — 6,72 s |

Les deux familles de levier ramenent sous 22 s des le premier cran, mais
**elles ne coutent pas la meme chose** : `HOP_DISTANCE` allonge la foulee
(Keepy couvre plus de sol par bond, la cadence visuelle ne bouge pas),
`HOP_DURATION` accelere le bond lui-meme — donc touche directement le
squash/stretch et le poids que le lot du hub decrit comme « toute la
difference entre un personnage qui a du poids et un curseur ». Aucun des
deux n'a ete essaye sur device.

⚠️ **LE VRAI COUT N'EST TOUJOURS PAS LA DUREE, C'EST L'ASYMETRIE DE VISEE
— et elle empire.** Mesuree sur la camera livree, aux deux ratios :

* **Vers l'AVANT : UN SEUL TAP, a n'importe quel rayon.** Un tap juste sous
  la ligne d'horizon vise **4 311 u** (1080x1920) / **5 967 u**
  (1170x2532) — donc le clamp de `PLATEAU_HALF_EXTENT` le ramene au bord,
  quel que soit ce bord. Ce n'est pas une limite et ca ne le deviendra pas.
* **DE COTE : la portee d'un tap ne depend PAS du plateau.** Le fov
  HORIZONTAL est fixe a 45 deg (`keep_aspect = KEEP_WIDTH`), donc la
  demi-largeur du frustum a la profondeur de Keepy vaut **~5,15 u
  identique aux deux ratios** (lot C publie 4,82 — meme phenomene, l'ecart
  vient de la bande en z sur laquelle on echantillonne, +-1 tap selon ou
  on la trace). Traverser lateralement coute donc **~5-6 taps a 25 et
  ~7 taps a 35**.

C'est la degradation reelle d'un elargissement : pas le nombre de bonds,
qui reste un seul tap vers l'avant, mais le nombre de TAPS qu'un joueur qui
longe un bord doit donner.

### R2 — FOG ET HORIZON AU RAYON 35 : aucun bord de sol, mais le landmark PERD en lisibilite

Banc camera-figee du lot C repris tel quel (`_process` de `HubCamera`
coupe, `SubViewportContainer.stretch` desactive — sans les deux la camera
lerpe pendant la mesure et l'aspect mesure n'est pas celui demande).

| viewport | haut du cadre | sol le plus lointain atteint (Keepy au pire coin) |
|---|---|---|
| 1080x1920 | `dir.y = +0,0413` (**+2,37 deg**) -> **CIEL** | `\|axe\|` **41,2** |
| 1170x2532 | `dir.y = +0,1370` (**+7,87 deg**) -> **CIEL** | `\|axe\|` **42,0** |

Les `+2,37` et `+7,87` **reproduisent au centieme** ceux deja consignes aux
lots B et C — le banc mesure bien la meme chose. Le pire rayon atteint
**42,0** contre les **+-300** du `PlaneMesh` 600x600 : **facteur 7 de
marge**, le bord du sol reste hors de portee. Et la jonction sol/ciel reste
invisible par construction (`fog_light_color == background_color`).
**Le sol n'est donc pas la contrainte.**

Fog exponentiel, `hub_fog_density = 0,016`, `occlusion = 1 - exp(-d*0,016)`
— formule relue sur l'`Environment` reel, pas sur la doc :

| distance camera | 10 u | 20 u | 30 u | 40 u | 43,3 u | 60 u | 75 u | 100 u |
|---|---|---|---|---|---|---|---|---|
| occlusion | 14,8 % | 27,4 % | 38,1 % | 47,3 % | **50 %** | 61,7 % | ~69,9 % | 79,8 % |

⚠️ **Ce que ca fait a un landmark pose a ~30,5, et c'est la mauvaise
nouvelle de R2** — un landmark n'est pas vu depuis le centre du plateau, il
est vu de partout :

| rayon du landmark | vu depuis le CENTRE | vu depuis le bord OPPOSE |
|---|---|---|
| 12,6 (anneau interieur, lot B) | 22,80 u — **30,6 %** | 57,01 u — 59,8 % |
| 21,4 (anneau median, lot C) | 31,24 u — **39,3 %** | 65,74 u — 65,1 % |
| **30,5 (ce lot, non pose)** | 40,13 u — **47,4 %** | **74,79 u — 69,8 %** |

Le brief posait « si le fog efface au-dela de ~25 unites » comme condition
de blocage. **Il n'efface pas** — a 47,4 % le landmark garde encore ~53 %
de sa propre couleur depuis le centre. Mais c'est **la premiere fois qu'un
landmark de ce projet passerait sous la barre des 60 % de couleur propre**
la ou les lots B et C tenaient 69 % et 61 %, et **vu du bord oppose il
tombe a 30 % de couleur propre**. Ce n'est pas un STOP, c'est une
degradation reelle a mettre dans la balance de l'arbitrage R1 : les 4
landmarks que ce lot devait poser seraient les moins lisibles des douze.

### R3 — COUT : 17 noeuds, et ce n'est pas la contrainte

`landmark` **n'est PAS batche** — verifie dans `HubBuilder.gd`, dont
l'en-tete le dit explicitement (« batching them would trade 31 nodes for
~12 and lose the per-variant readability of the tree »). Cout par
silhouette, compte sur les constructeurs livres : **spire = 4 meshes,
cairn = 5, slabs = 3**.

Compte reel sur la scene livree, pas deduit du layout :

| | actuel | + 4 landmarks |
|---|---|---|
| `MeshInstance3D` (HubBuilder, hors portails) | 47 | 64 |
| `MultiMeshInstance3D` | 8 | 8 |
| **noeuds de dessin hors portails** | **55** | **72** |
| noeuds de dessin, total (+ 3 portails) | 61 | 78 |
| marge sous le plafond de 260 | 205 | **188** |

Les 4 variantes forcees par la regle « pas deux identiques adjacentes »
seraient cairn/slabs/cairn/spire aux azimuts intercales **23,5 / 112,75 /
202,4 / 292,4** (les 8 existants sont a 0 / 47 / 92,5 / 133 / 177,3 /
227,5 / 271,8 / 313, en spire-slabs-cairn-spire-slabs-spire-cairn-slabs) —
soit **5+3+5+4 = 17 noeuds**. **Le budget n'est a aucun moment la
contrainte de ce lot**, et le refactor MultiMesh du matin est ce qui le
garantit.

### Piege de sonde rencontre, a connaitre — il coute 20 minutes en silence

⚠️ **Un lambda GDScript capture une variable LOCALE PAR VALEUR.** La
premiere version du banc R1 faisait
`hopper.became_idle.connect(func(): done = true)` avec `done` local a la
boucle : le lambda ecrit sa propre COPIE, la boucle d'attente ne voit
jamais le changement, et chaque trajet tourne jusqu'a son plafond de
frames. **Aucune erreur, aucun warning** — juste une sonde qui a l'air
lente au lieu d'avoir l'air cassee, et qui l'etait sous un rendu logiciel
ou 20 000 frames sont plausibles. Parade : un membre de classe et une
methode nommee, jamais un lambda, pour tout drapeau qu'une boucle attend.

⚠️ **Second piege, meme run** : `SubViewportContainer.stretch = true` fait
FORCER par le conteneur la taille du `SubViewport` a la sienne, donc un
`vp.size` explicite est **ignore en silence** (un simple `WARNING`) et
l'aspect reellement mesure est celui de la fenetre, pas celui demande. La
premiere passe a rendu des chiffres **identiques pour les deux ratios**,
ce qui ressemblait a un resultat et n'en etait pas. Couper `stretch` avant
toute mesure d'aspect — ce que le banc du lot C faisait deja, et que la
partie R1 du mien avait omis.

### Ce que ce lot laisse au depot

**Aucun changement de jeu.** Les deux sondes de mesure etaient jetables et
sont supprimees avant commit — `ProbeTimeoutAudit` revient a **38 sondes
scenes**, le chiffre exact de `origin/staging`. `docs/HUB_PERF_BASELINE.md`
n'a **pas** recu de ligne de comparaison : son tableau compare des ETATS du
plateau, et ce lot n'en produit aucun nouveau. Import headless **exit 0**
(24 `.scn`).

**Reste ouvert — c'est l'arbitrage de Mathieu, pas une question
technique** : accepter 23,10 s de diagonale complete au rayon 35 ; ou
tirer un levier (`HOP_DISTANCE` 2,0 -> 17,50 s / 2,5 -> 14,00 s ;
`HOP_DURATION` 0,28 -> 18,48 s), sachant qu'aucun n'a ete juge sur device
et que `HOP_DURATION` touche directement le poids du bond ; ou s'arreter a
un rayon intermediaire. A cela s'ajoutent les **~7 taps lateraux** contre
5-6 aujourd'hui, et le fait que **les 4 landmarks de la nouvelle couronne
seraient les moins lisibles des douze** (47,4 % de fog depuis le centre,
69,8 % depuis le bord oppose).

### Deploiement staging du lot D (palier 1, automatique — DOC SEULE)

`staging` **`17b49d8`** (merge `--no-ff`, arbre **byte-identique** a la
branche feature : meme hash d'arbre `494e0487` des deux cotes, verifie AVANT
le push). **Le contenu de JEU est rigoureusement inchange** — le diff ne
porte que sur `CLAUDE.md`, qui n'est pas une ressource Godot et n'entre donc
pas dans le pack. CI run **#221** (id `32840536211`) **verte** (11:05:48 ->
11:14:06 UTC), `[STAGING -- staging]` succes, `[PRODUCTION -- main]`
correctement **skipped**. **`main` NON touche** (`origin/main` toujours
`ffcc552`).

**Verifie SUR LE SERVICE, pas dans le log CI, et DANS LES DEUX SENS** :

| | `CACHE_VERSION` | = UTC |
|---|---|---|
| avant (run #220) | `1787652096` | **10:01:36** |
| **apres (ce lot, run #221)** | **`1787656419`** | **11:13:39** |

L'epoch d'apres tombe **a l'interieur de la fenetre du run #221**, avec
`x-vercel-cache: MISS` et `age: 0`. La valeur d'avant a ete **relue a
11:10:45 pendant que le job tournait** — toujours l'ancienne — donc la
bascule est prouvee dans les deux sens et pas deduite du log.

⚠️ **Piege de lecture rencontre a cette relecture** : la reponse de 11:10:45
portait `x-vercel-cache: HIT` et `age: 308`, c'est-a-dire une copie CDN
figee a 11:05:37. **Un `HIT` avec un `age` non nul n'est pas une mesure de
fraicheur** — il ne dit rien de l'etat du service a l'instant de la lecture.
Seule la lecture `MISS`/`age: 0` compte, au besoin en cassant le cache par
un parametre de requete.

⚠️ L'egress direct vers `*.vercel.app` reste refuse par le proxy de ce
sandbox (`http_code 000`, re-teste et pas suppose) : le canal MCP Vercel est
le seul disponible ici, comme deja consigne.

## HUB, LOT G — RECON PURE : la geometrie du stream mesuree contre la chaine de hops (25 aout 2026)

Branche `claude/stream-geometry-measure-3dnlsr`, partie de `main` (`ab62ba6`,
la ref la plus a jour du depot : `main..staging` est VIDE et les deux portent
le MEME arbre `2ee5143` — `staging` n'a que le commit de merge en moins.
Aucune session concurrente). **AUCUN fichier de jeu touche** : `git diff
--stat` ne rapporte que `scripts/dev/StreamGeometryProbe.{gd,tscn}` (nouveaux)
et ce document. Ni `scripts/hub/*`, ni `resources/hub/hub_layout.tres`, ni une
scene, ni un `.glb`. **Aucun changement de gameplay, aucune decision prise** —
ce lot produit les chiffres qui permettront a Mathieu de trancher si un
ruisseau ridable peut etre un RACCOURCI ou seulement un mode de deplacement
passif.

### R1 — OUI, les 12 points sont lisibles SANS reconstruire le mesh

Reponse explicite a la question du brief. L'entree `&"stream"` de
`hub_layout.tres` porte ses points en clair, dans un
**`PackedVector3Array`** (la forme retenue au lot precedent apres un test
d'aller-retour de serialisation), plus un champ `width` :

```
"points": PackedVector3Array(17.58, 0, 6.67, ... , -18.54, 0, -0.73),
"type": &"stream",
"width": 1.2
```

Un simple `load("res://resources/hub/hub_layout.tres") as HubLayout` puis
`layout.props` les rend tels quels : `HubLayout` est une `Resource` a
`@export var props: Array[Dictionary]`, **aucun `SurfaceTool`, aucun
`ArrayMesh`, aucune scene n'a besoin d'exister** pour les lire.

### ⚠️ MAIS LA POLYLINE DES POINTS DE CONTROLE N'EST PAS LE CHEMIN D'UN RIDER

C'est la nuance qui change la reponse a la question 4, et elle n'etait pas
dans le brief. `HubBuilder` ne dessine PAS les 12 points : il les passe par
`_centripetal()` (Catmull-Rom centripete, alpha 0,5) a
`STREAM_SAMPLES_PER_SPAN = 8`, ce qui produit **89 echantillons**, et c'est
CE spine qui est ribbonne. Une spline **bombe a l'exterieur** des cordes
d'une polyline passant par les memes points, donc son arc est le PLUS LONG
des deux — et c'est celui qu'un rider parcourrait reellement.

Les deux sont donc mesures et publies. **La vitesse minimale de ride est
calculee sur le SPINE** : la calculer sur la polyline annoncerait une
vitesse que la geometrie reelle ne peut pas tenir.

| | polyline (12 points de controle) | **spine (89 echantillons, ce qui est construit)** |
|---|---|---|
| **L_arc** | **41,1150 u** | **41,2837 u** |
| **L_corde** | **36,8702 u** | 36,8702 u |
| **ratio** | **1,115127** | **1,119703** |
| **rayon de courbure min** | **3,5022 u** (index 6) | **1,4058 u** (index 48) |

**Demi-largeur du ruban a la construction : 0,6000 u** (`width` 1,2 lu dans
l'entree, `half = width * 0,5` dans `_make_stream`). Le rayon de courbure
minimum du spine vaut donc **2,34x la demi-largeur** — un ruban dont le
rayon de courbure descend sous sa propre demi-largeur SE REPLIE, et c'est
pourquoi ce chiffre est imprime a cote d'elle plutot que seul.

**Extremites monde** : HEAD **(17,5800 ; 0,0000 ; 6,6700)**, TAIL
**(-18,5400 ; 0,0000 ; -0,7300)**.

⚠️ **Le 1,4058 reproduit le « 1,403 » deja consigne au lot stream**, mesure a
l'epoque sur le mesh construit et non sur une transcription — premier
recoupement independant de ce chiffre.

### La transcription du spline est CONFRONTEE au mesh livre, pas crue

Recopier `_centripetal()` dans une sonde, c'est fabriquer un fixture libre de
diverger du code qu'il imite — le piege exact que ce depot a deja paye une
fois (`SubstituteModel.tscn`). PHASE B **reconstruit `scenes/HubWorld.tscn`
pour de vrai**, retrouve le `MeshInstance3D` du stream **par sa COULEUR de
materiau et jamais par un index de noeud** (le fichier de layout decide
combien de props le precedent), et relit les sommets de l'`ArrayMesh` livre :

| | valeur |
|---|---|
| mesh construit | **528 sommets, 176 triangles, 88 quads** |
| echantillons du spine, transcription | 89 |
| echantillons reconstruits depuis le mesh | 89 |
| **ecart pire transcription vs mesh** | **0,000000477 u** *(precision float32 du buffer)* |
| arc du ruban relu SUR LE MESH | **41,2837 u** — identique a la transcription |

**Contre-verification independante** : les memes chiffres ont ete recalcules
en Python depuis le texte brut du `.tres`, hors moteur — L_arc 41,1150 /
41,2837, corde 36,8702, rayons 3,5022 / 1,4058, 25 hops, toutes les vitesses.
**Identiques au dernier chiffre imprime.**

### R3 — la chaine de hops equivalente, et la QUANTIFICATION qui la rallonge

Constantes **lues dans `KeepyHopper.gd`**, jamais recopiees du brief :
`HOP_DISTANCE = 1,5000`, `HOP_DURATION = 0,2800`, `ARRIVE_EPSILON = 0,4500`.
Le nombre de hops est obtenu **en rejouant la regle de `_advance()`**
(pas par une formule fermee qui pourrait cesser d'etre d'accord avec elle
apres une edition du hopper).

| | valeur |
|---|---|
| distance euclidienne extremite a extremite | **36,8702 u** |
| **hops dans la chaine** | **25** |
| frames par hop a 60 fps | **17** (0,2833 s) |
| **temps NOMINAL** (25 x 0,28) | **7,0000 s** |
| **temps QUANTIFIE** (ce que voit un chronometre) | **7,0833 s** |

⚠️ Un hop est UN Tween sur `HOP_DURATION`, et un Tween se termine sur une
FRONTIERE DE FRAME : 0,28 s vaut 16,8 frames a 60 fps, donc le tween finit a
la frame **17** et un hop occupe reellement 0,2833 s. **Toute chaine coute
donc ~1,19 % de plus que la multiplication nominale** — la meme quantification
deja consignee au lot E, ici sur un trajet de 25 hops. Le 25e hop est par
ailleurs **partiel** (0,87 u restant, pas 1,5) et coute quand meme un
`HOP_DURATION` plein.

### R4 — LA VITESSE DE RIDE MINIMALE : > 5,83 u/s

| comparaison | seuil |
|---|---|
| **spine vs temps QUANTIFIE** *(la reponse)* | **> 5,8283 u/s** |
| spine vs temps NOMINAL | > 5,8977 u/s |
| polyline vs temps QUANTIFIE *(sous-estime — voir plus haut)* | > 5,8045 u/s |
| pour l'echelle : vitesse au sol de la chaine de hops | **5,2941 u/s** |

⚠️ **CE QUE CE CHIFFRE DIT, ET IL EST INCONFORTABLE : un ride qui se
contenterait de la vitesse de deplacement actuelle serait PLUS LENT que
marcher.** Il faut **au moins 1,101x la vitesse au sol de Keepy** juste pour
faire match nul, et cela **uniquement parce que le ruisseau meandre** — il
fait 41,28 u pour relier deux points distants de 36,87 u (**+12 %** de detour,
ratio 1,1197). Un raccourci reel — disons 25 % plus rapide que la chaine de
hops — demanderait **> 7,77 u/s**, soit **1,47x** la vitesse au sol.

**Ni cette decision ni aucune autre n'est prise ici.** Ce que la mesure
autorise a dire, et rien de plus : la vitesse de ride n'est pas un parametre
libre a choisir a l'oreille — sous 5,83 u/s le ruisseau ne peut etre qu'un
mode de deplacement PASSIF (agreable, panoramique, jamais optimal), et au
dela il devient un raccourci. **Il n'existe pas de reglage qui donne les
deux.**

### R5 — ce qui se tient pres des extremites (candidats a bloquer un embarquement)

Rayon de recherche 3,0 u autour de chaque extremite. **Trois props, tous
degages du ruban** :

| extremite | prop | position | distance | echelle |
|---|---|---|---|---|
| **HEAD** (17,58 ; 6,67) | `stump` | (17,61 ; 4,72) | **1,9502 u** | 0,84 |
| **HEAD** | `stump` | (16,99 ; 9,21) | **2,6076 u** | 0,90 |
| **TAIL** (-18,54 ; -0,73) | `rock` | (-18,68 ; 1,70) | **2,4340 u** | 1,18 |

⚠️ **Les deux plans d'eau n'apparaissent PAS dans cette liste, et c'est une
propriete du seuil, pas une absence** : le centre de la mare est a
**3,2043 u** du HEAD et celui du lac a **7,9949 u** du TAIL — c'est-a-dire
exactement leurs rayons d'eau (3,20 et 8,00), les extremites du stream etant
posees **sur la rive EAU** de chacun. Un embarquement se ferait donc au bord
de l'eau, pas au milieu d'un prop.

Les deux souches du HEAD sont deux des **quatre souches de rive de la mare**
deja consignees (0,37 a 0,54 au-dela de la berge) ; le rocher du TAIL est l'un
des **rochers de rive du lac**. Aucun n'est un ajout de ce lot, aucun n'est
deplace par lui.

### Validation

Editeur + templates Godot 4.3-stable installes dans ce sandbox (releases
GitHub officielles, **tailles verifiees contre le `Content-Length`** —
50 276 070 et 1 073 228 327 octets, aucune troncature silencieuse). Import
headless **exit 0**, **24 `.scn`** (import complet verifie, pas suppose — le
piege du faux-rouge par import tronque est controle), **0 erreur**. Export Web
release **exit 0**, **0 ligne d'erreur** dans le log.

`index.wasm` **35 376 909 octets** / md5
**`af4a8fc2925d992348eb30deeeb54360`**, `index.js` md5
**`4e08904b1b7107858246af44b602067b`** — identiques au fingerprint deja
consigne pour tout lot qui ne touche pas le code moteur, ce qui est exactement
ce qu'un lot dev-only doit rendre. `index.pck` **5 838 080** (export unique et
propre, `build/` supprime avant — a lire avec la mise en garde permanente sur
son instabilite, jamais offert comme preuve).

**`exclude_filter` couvre bien le nouveau fichier, VERIFIE sur le pack et pas
sur le filtre** : `scripts/dev/*` est un glob, et le log `savepack` porte
**0** ligne `Storing File` pour `res://scripts/dev` (comme pour
`assets_source`, `docs`, `web`, `build` et `firebase.json`) sur 219 lignes ;
la chaine `StreamGeometryProbe` est **absente du `.pck`**.

Sondes : `ProbeTimeoutAudit` **exit 0, 39 sondes scenes** (38 + celle-ci,
toutes armees — la nouvelle arme `arm()` en PREMIERE instruction de `_ready()`
**et** un `deadline()`, parce qu'elle a les deux formes : PHASE B attend des
frames, les autres phases bloquent dans un seul appel ou un watchdog arme
serait MUET). `AssetContractAudit` (**12/12 visuels, 0 collider deplace**),
`DeathModelAudit`, `ChargerShapeProbe` — **toutes exit 0**.
**Non-applicabilite du reste VERIFIEE** : ce lot n'ajoute aucun noeud, aucun
mesh, aucun materiau et ne touche aucune constante de jeu.

### Reste ouvert — c'est une decision de Mathieu, pas une question technique

1. **La vitesse de ride** : sous **5,83 u/s** le ruisseau est un mode de
   deplacement passif, au-dessus c'est un raccourci. Le detour de +12 % du
   meandre est une propriete de la trace livree, pas un reglage.
2. **Si un raccourci est voulu, la trace elle-meme est un levier** — la
   redresser baisserait le seuil, mais elle a ete routee pour degager les
   props ET pour tenir un rayon de courbure de 1,4058 u ; la retoucher
   rouvrirait les deux contraintes du lot precedent.
3. **Rien n'a ete mesure sur l'EMBARQUEMENT** : ni comment on monte sur le
   ruban, ni ce que devient le `KeepyHopper` pendant un ride, ni si une
   sortie en cours de trajet est possible. Hors perimetre de cette recon.
4. **Aucun jugement device n'est possible sur ce lot** — il n'ajoute rien de
   visible.
### ⚠️ QUATRIEME INCIDENT DE SESSIONS CONCURRENTES — le lot G a ete brieffe DEUX fois (25 aout 2026)

**La regle n°1 de ce fichier a ete enfreinte une quatrieme fois** (precedents
des 6 et 11 aout, puis 21 aout). Deux sessions ont recu le meme brief de recon
lot G, avec deux noms de branche quasi identiques :
`claude/stream-geometry-measure-3dnlsr` (l'incumbent) et
`claude/stream-geometry-measure-fasmdp` (celle-ci).

**Resolu au moindre cout des quatre, et pour la raison que l'incident du
11 aout avait nommee** : le `git fetch --all --prune` a ete fait **AVANT
d'ecrire une ligne**. La collision est apparue immediatement — `origin/staging`
portait deja `1d06c18` (la sonde) et son merge `97ab1db`, pousses ~2 minutes
plus tot. **Cette session n'a donc produit AUCUN doublon a abandonner** : zero
ligne de sonde ecrite, contre ~3 h de travail duplique au 11 aout. Elle s'est
convertie en **verification independante**, comme la session du 21 aout.

⚠️ **Rien dans l'outillage n'a signale la collision, une quatrieme fois.** Le
seul indice etait la presence de `origin/claude/stream-geometry-measure-3dnlsr`
dans `git branch -r` — un nom a **un suffixe pres** du mien, ce qui rend la
lecture par nom encore plus fragile qu'aux incidents precedents. **Ce qui a
tranche en une commande est le tri des refs distantes par date de commit**
(`git for-each-ref --sort=-committerdate`), qui a mis la branche incumbente et
`origin/staging` en tete a 20:42 et 20:43.

#### Verification independante : les chiffres du lot G se reproduisent TOUS

Re-derivation **en Python pur, hors moteur**, depuis le texte brut de
`resources/hub/hub_layout.tres` — donc sans la sonde livree, sans Godot (ni
editeur ni templates dans ce sandbox), et sans reutiliser une seule de ses
lignes : parseur `PackedVector3Array` par regex, transcription independante de
`_centripetal()` relue dans `HubBuilder.gd`, rejeu de la regle de
`_advance()` relue dans `KeepyHopper.gd`.

| grandeur | lot G (publie) | **cette verification** |
|---|---|---|
| points lus sans mesh (R1) | 12, `width` 1,2 | **12, `width` 1,2** ✅ |
| polyline `L_arc` / `L_corde` / ratio | 41,1150 / 36,8702 / 1,115127 | **identiques** ✅ |
| polyline rayon min | 3,5022 @6 | **identique** ✅ |
| spine : echantillons | 89 | **89** ✅ |
| spine `L_arc` / ratio | 41,2837 / 1,119703 | **identiques** ✅ |
| spine rayon min | 1,4058 @48 (2,34x la demi-largeur 0,6) | **identiques** ✅ |
| HEAD / TAIL | (17,58 ; 0 ; 6,67) / (-18,54 ; 0 ; -0,73) | **identiques** ✅ |
| hops / frames / nominal / quantifie | 25 / 17 / 7,0000 s / 7,0833 s | **identiques** ✅ |
| **vitesse de ride minimale (R4)** | **> 5,8283 u/s** | **> 5,8283 u/s** ✅ |
| vitesse au sol de la chaine de hops | 5,2941 u/s (ratio 1,101x) | **identiques** ✅ |
| props a moins de 3 u (R5) | 2 souches HEAD + 1 rocher TAIL | **identiques au centieme** ✅ |

**Aucun ecart, sur aucune ligne.** Le `1,4058` recoupe une troisieme fois le
`1,403` du lot stream, cette fois par un chemin qui ne passe ni par le mesh
construit ni par la sonde qui le relit.

⚠️ **Ce que cette verification NE couvre PAS, dit plutot que sous-entendu** :
elle ne rejoue pas la PHASE B de la sonde (la confrontation de la
transcription aux sommets de l'`ArrayMesh` livre, ecart 4,77e-7) — **aucun
Godot n'est installe dans ce sandbox** et le telecharger pour un lot doc-only
ne se justifiait pas. C'est la seule assertion du lot G qui reste sur la seule
parole de l'incumbent ici. **Elle a en revanche ete validee par la CI** : le
run **#235** (id 32896953382) sur `staging` `97ab1db` est **`conclusion:
success`**, donc l'import + l'export Web de ces deux fichiers de sonde passent
exit 0 sur le commit exact.

**`exclude_filter` couvre bien le nouveau fichier** — `export_presets.cfg`
porte `scripts/dev/*` dans son `exclude_filter` (relu, pas suppose), et
`StreamGeometryProbe.{gd,tscn}` est sous ce glob.

**Ce lot ne touche aucun fichier de jeu et n'ajoute aucune sonde** : son diff
est ce document seul. `scripts/dev/StreamGeometryProbe.*` reste l'artefact
unique du lot G, celui de l'incumbent.

## HUB, LOT WATER-HUE-1 : LA PLANCHE DES CANDIDATS -- rien n'est installe, et deux premisses du brief tombent a la mesure (26 aout 2026)

Branche `claude/water-hue-candidates-aqeckt`, partie de `staging` (**`4c7da9a`**,
un commit de doc au-dessus du `73d45d2` annonce par le brief -- ecart benin,
verifie ancetre plutot que suppose). Regle n°1 verifiee AU DEBUT : tri des refs
distantes par date, `origin/staging` en tete, **aucune branche ne porte ce
brief**, et la comparaison porte sur les ARBRES et pas sur les noms.

**AUCUNE COULEUR D'EAU N'EST MODIFIEE.** `git diff --stat` contre
`origin/staging` ne rapporte que `scripts/dev/WaterHueSheet.{gd,tscn}`
(nouveaux), `docs/color-sheets/water_hue_*.png` (nouveaux) et ce document.
`scripts/hub/HubBuilder.gd`, `resources/hub/hub_layout.tres`,
`resources/world/swamp_palette.tres`, `KeepyHopper.gd`, `HubCamera.gd` et
`HubRegion.gd` **ne sont pas dans le diff du tout**. Les candidats vivent dans
le script de planche, exactement pour que juger l'un coute un rendu et pas un
commit.

### RECON -- ou vivent REELLEMENT les quatre couleurs

Les quatre sont des constantes de `scripts/hub/HubBuilder.gd`, et **le layout
n'en porte aucune** (`grep -c -i color resources/hub/hub_layout.tres` -> **0**).
Rien n'est migre vers `SwampPalette` : son propre en-tete range les couleurs de
decor du hub comme locales, et ce lot ne touche pas a ca.

| ligne | constante | valeur | hex | hsv | Lrel albedo |
|---|---|---|---|---|---|
| 137 | `POND_WATER_COLOR` | `Color(0.16, 0.30, 0.36, 0.55)` | **#294C5C** | (198.0, 0.556, 0.360) | **0.0647** |
| 156 | `LAKE_WATER_COLOR` | `Color(0.30, 0.46, 0.82, 0.55)` | **#4C75D1** | (221.5, 0.634, 0.820) | **0.1896** |
| 236 | `GREATLAKE_WATER_COLOR` | `Color(0.32, 0.23, 0.60, 0.55)` | **#523B99** | (254.6, 0.617, 0.600) | **0.0717** |
| 277 | `STREAM_WATER_COLOR` | `Color(0.42, 0.78, 0.86, 0.55)` | **#6BC7DB** | (190.9, 0.512, 0.860) | **0.4906** |

### ⚠️ PREMISSE 1 QUI TOMBE : le sol du HUB n'est pas celui de Chased, donc le plancher n'est pas 0.549

Le brief pose « le sol est a Lrel = 0.15 », d'ou la bande claire a **L >= 0.549**.
Ce 0.150 est le sol de **Chased** (`SwampPalette.ground_albedo`, multiplie par
son ambiante). Le hub a le sien, ecrit dans `HubWorld.tscn` et **unshaded** :
`Color(0.2, 0.4, 0.15)`. **Mesure sur le rendu, pas calculee : #2C5A20,
Lrel 0.0799** (le fog l'assombrit encore par rapport a son albedo).

**Le plancher 3.0:1 contre le sol du hub est donc `L rendu >= 0.3397`,
pas 0.549.** Le 0.549 reste juste comme cible sur l'**ALBEDO**, et c'est comme
ca qu'il est applique ici : **les 12 couleurs candidates le franchissent
toutes**.

### ⚠️ PREMISSE 2 QUI TOMBE, ET C'EST LE RESULTAT CENTRAL DU LOT : a alpha 0.55, AUCUNE eau ne peut atteindre 3.0:1 -- ni maintenant, ni dans aucun des trois candidats

L'eau est la **seule surface alpha-melangee** du plateau (0.55), et elle se
melange sur sa propre **berge opaque** (`POND_BANK_COLOR`, Lrel **0.0359**), pas
sur le sol -- la berge est un disque plein plus large que l'eau. Le ruisseau,
lui, n'a pas de berge et se melange sur le sol. Puis le fog exponentiel
(`hub_fog_density` 0.016 vers un vert quasi noir) passe par-dessus.

Meilleur chiffre mesure, toutes familles confondues : **2.61:1** (le ruisseau
de la famille B). **Le grand lac plafonne a 2.02:1.** Aucune teinte, aucune
saturation ne franchit 3.0:1 -- **c'est l'alpha qui plafonne, pas la couleur.**

Ce n'est pas un modele : la planche capture chaque vue **deux fois**, une a
l'alpha livre et une en opaque. Le fog et le melange alpha sont tous deux des
melanges lineaires, donc la luminance rendue est **AFFINE en alpha** et deux
points mesures donnent le resultat exact a n'importe quel alpha. D'ou la
colonne « a -> 3.0:1 » de la planche :

| famille | mare | ruisseau | petit lac | grand lac |
|---|---|---|---|---|
| ACTUEL | >1.00 | 1.00 | >1.00 | >1.00 |
| A | 0.91 | 0.67 | 0.94 | 0.97 |
| **B** | **0.74** | **0.62** | 0.93 | **0.72** |
| C | 0.81 | 0.68 | 0.97 | 1.00 |

**Non fait, et deliberement : l'alpha n'est pas une couleur.** Le chiffre est
publie parce qu'il transforme « impossible » en « voici le levier », pas parce
que ce lot le tire. Second levier possible, non tire non plus : eclaircir
`POND_BANK_COLOR`, qui est le fond sur lequel trois des quatre eaux se melangent.

### ⚠️ PREMISSE 3 QUI TOMBE : un BLEU SATURE est interdit par la bande claire

Consequence de la formule de luminance (le canal bleu pese 0.0722). Saturation
maximale a V = 1.00 qui tient encore `Lalb >= 0.549` :

| teinte | 158 | 170 | 182 | **188** | **194** | 200 | 212 | **224** | 236 |
|---|---|---|---|---|---|---|---|---|---|
| S max | 1.00 | 1.00 | 1.00 | **1.00** | **0.74** | 0.57 | 0.41 | **0.32** | 0.27 |

**Au-dela de ~190 deg, tenir la bande claire OBLIGE a desaturer.** Une famille
a « saturation homogene et teinte etalee » est donc **impossible** telle quelle
si elle doit atteindre le bleu : la famille C est livree avec la saturation **au
plafond de chaque teinte** plutot qu'avec une valeur unique, et c'est dit
plutot que maquille.

### ⚠️ SEULES TROIS PAIRES SONT CO-VISIBLES -- mesure, pas suppose

Le cadre du hub fait ~13 a 18 unites de large a la profondeur du sujet
(fov horizontal 45 deg, fixe). Les distances entre plans d'eau :

| paire | co-visible ? |
|---|---|
| **petit lac / grand lac** | **OUI -- ils SE TOUCHENT** (0.347 u entre les eaux) |
| **mare / ruisseau** | **OUI** -- la tete du ruisseau est sur la rive de la mare |
| **petit lac / ruisseau** | **OUI** -- la queue du ruisseau est sur la rive du lac |
| mare / petit lac | non (47.5 u) |
| mare / grand lac | non (~75 u) |
| ruisseau / grand lac | non |

La matrice complete est publiee sur chaque planche, mais **seules ces trois
lignes decident** ; les autres sont de l'information.

### Les trois familles candidates

**A -- ANCRE STRICTE.** Le grand lac EST `#40E0D0` ; les trois autres derivent,
l'ecart est mene par la TEINTE.
`mare #2FD8EB` / `ruisseau #61FFC5` / `petit lac #7AD3FF` / `grand lac #40E0D0`.

**B -- TEINTE RESSERREE, SATURATION ECARTEE.** Toutes les teintes dans 170-180
deg d'albedo ; l'ecart est porte par la SATURATION seule, et elle alterne le
long de la chaine mare -> ruisseau -> petit lac -> grand lac (0.92 / 0.28 /
0.714 / 0.20), donc **chaque paire adjacente alterne**. L'ancre `#40E0D0` y est
le petit lac.
`mare #14FFD8` / `ruisseau #B8FFFF` / `petit lac #40E0D0` / `grand lac #CCFFFD`.

**C -- TEINTE ETALEE, SATURATION AU PLAFOND.** 146 / 172 / 196 / 220 deg, avec
la saturation la plus haute que la bande claire autorise a chaque teinte (voir
la premisse 3). L'ancre y est le ruisseau.
`mare #24F27E` / `ruisseau #26FFE2` / `petit lac #57D2FF` / `grand lac #ABC7FF`.

**Paires critiques, MESUREES sur le rendu** (pas sur l'albedo) :

| famille | petit lac / grand lac | mare / ruisseau | petit lac / ruisseau |
|---|---|---|---|
| ACTUEL | 1.39:1 -- 37.2 deg -- dS 0.083 | 2.71:1 -- 11.2 deg -- dS 0.163 | 2.05:1 -- 53.0 deg -- dS 0.022 |
| A | **1.04:1** -- 26.5 deg -- dS 0.188 | 1.50:1 -- 34.3 deg -- dS 0.058 | 1.54:1 -- 48.3 deg -- dS 0.178 |
| **B** | **1.29:1** -- 8.4 deg -- **dS 0.421** | 1.34:1 -- 13.5 deg -- **dS 0.448** | 1.66:1 -- 14.7 deg -- dS 0.257 |
| C | **1.02:1** -- 23.5 deg -- dS 0.291 | 1.35:1 -- 19.5 deg -- dS 0.047 | 1.56:1 -- 30.1 deg -- dS 0.232 |

⚠️ **Le defaut du grand lac ACTUEL est nomme par un seul chiffre : il rend a
Lrel 0.0342 contre un sol a 0.0799 -- il est PLUS SOMBRE que le sol qui
l'entoure.** C'est litteralement le « trou » du retour terrain, et les trois
candidats le placent au-dessus du sol (0.1246 a 0.2120).

### La planche

`docs/color-sheets/water_hue_{current,A,B,C}.png` -- une planche par famille,
trois vues chacune : la jonction des deux lacs (le cas dur), la mare + la tete
du ruisseau, le petit lac + la queue du ruisseau. Plus
`docs/color-sheets/water_hue_comparatif.png`, les quatre jonctions cote a cote
-- **le seul cadre ou la paire critique est visible d'un coup**, donc la seule
image sur laquelle le choix se fait vraiment.

Rendu offscreen sous `xvfb-run --rendering-driver opengl3` avec la **VRAIE
camera du hub** : meme base, meme `fov 45`, meme `keep_aspect KEEP_WIDTH`, seule
la POSITION change -- ce que la camera fait deja en jeu quand Keepy se deplace.
540x960 = exactement la moitie du viewport livre, donc le RATIO et le cadrage
sont ceux du jeu. Recadre a 620 px pour la planche : le tiers bas de chaque
cadre est du sol nu au pied du joueur.

### ⚠️ LA MESURE EST MASQUEE, PAS ECHANTILLONNEE DANS UNE BOITE -- et la moyenne prime sur le dominant

Deux ruptures assumees avec la methode de toutes les recolorations de hazards
de ce depot, et les deux sont des consequences de ce qu'est l'eau :

1. **Masque et non fenetre.** Une passe d'identification par corps et par vue
   rend la cible en blanc opaque, fog coupe, les trois autres en noir ; un pixel
   appartient a ce corps **ssi il revient exactement 255,255,255**. Une fenetre
   fixe est inutilisable ici : l'eau est alpha-melangee sur sa berge (une
   fenetre qui deborde lit la berge) et le ruisseau est un ruban de 1.2 u vu de
   biais (aucune boite n'est jamais 100 % objet).
2. **Moyenne lineaire et non dominant d'histogramme.** Un hazard plat unlit
   remplit sa fenetre d'UNE valeur, donc son dominant EST sa couleur. Ces
   surfaces-la s'etendent sur assez de profondeur pour que le fog les degrade en
   continu : **le dominant du grand lac porte 4 a 9 % de ses 34 653 pixels** et
   n'est que la marche la plus frequente d'un degrade. La planche publie les
   deux, plus la part et le nombre de valeurs distinctes -- c'est ce qui dit
   que l'ecart est un degrade et pas du bruit.

### Validation

Editeur + templates Godot 4.3-stable installes dans ce sandbox (releases GitHub
officielles, **tailles verifiees contre le `Content-Length`** -- 50 276 070 et
1 073 228 327 octets, aucune troncature silencieuse). Import headless
**exit 0**, **24 `.scn`**. Export Web release **exit 0**, **0 erreur GDScript**.
`index.wasm` **35 376 909** octets / md5
**`af4a8fc2925d992348eb30deeeb54360`**, `index.js` md5
**`4e08904b1b7107858246af44b602067b`** -- identiques au fingerprint deja
consigne pour tout lot qui ne touche pas le code moteur, ce qui est exactement
ce qu'un lot doc + sonde doit rendre.

**Piege payload verifie sur le pack et pas sur le filtre** : sur **225** lignes
`Storing File`, **0** pour `res://docs`, `res://scripts/dev`,
`res://assets_source`, `res://web` ou `firebase.json`, et la chaine
`WaterHueSheet` est **absente du `.pck`**. `docs/*` etait deja dans
l'`exclude_filter` (ferme le 13 aout apres qu'une planche de recon y ait coute
414 862 octets) -- ce lot le confirme pour le nouveau chemin plutot que de le
supposer.

Sondes : `AssetContractAudit` (**12/12 visuels, 0/10 colliders deplaces**),
`DeathModelAudit`, `ChargerShapeProbe`, `ProbeTimeoutAudit` -- **toutes
exit 0**. Ce dernier passe de **42 a 43 sondes scenes**, **mesure des deux
cotes** (les deux fichiers retires puis remis) et non deduit : c'est la planche
elle-meme, gardee pour que le lot soit reproductible, au meme titre que
`EnemyEarthtoneAxisSheet` et `ChargerEarthtoneAxisSheet` avant elle.

⚠️ **`SwampIdentityAudit` : 4/4 etats OK, `SWAMP_IDENTITY_VERIFIED=yes`,
exit 0 -- et ce verdict ne prouve RIEN sur ce lot.** Le brief prevoyait qu'elle
signale une derive ; elle ne le peut pas, parce que **ce lot n'installe aucune
couleur** et que l'arbre livre est inchange sur ce point. Elle est par ailleurs
**non deterministe** (la derive de teinte du sol de Chased, `_tint_rng`, est un
flux `DecorRng` insensible a `--seed`), donc son chiffre n'aurait de toute
facon bloque aucune decision. Publie pour information, comme le brief le
demande, plutot que tu.

### Reste ouvert -- c'est la decision de Mathieu, pas une question technique

1. **Le choix de la famille**, sur la planche. Ce que les chiffres disent et ne
   disent pas : B donne la plus grande separation de la paire qui touche
   (dS 0.421 mesuree, et le grand lac le plus lisible de tous a 2.02:1 contre
   le sol) ; A tient l'ancre `#40E0D0` telle quelle mais son grand lac ne
   separe presque plus du petit en luminance (1.04:1, tout est porte par 26.5
   deg de teinte) ; C etale la teinte mais son grand lac est le plus pale des
   trois et retombe a 1.02:1 contre le petit lac. **Aucune sonde ne dit
   laquelle est belle.**
2. **Le plafond d'alpha.** Si Mathieu veut reellement des eaux dans la bande
   claire au sens du CONTRASTE RENDU et pas seulement de l'albedo, il faudra
   toucher `transparency`/alpha (0.62 a 0.74 suffisent en famille B) ou la
   couleur de berge. **Hors perimetre de ce lot**, chiffre plutot que tranche.
3. **Jugement device** : la planche est un rendu llvmpipe sous xvfb, pas un
   ecran de telephone. Est-ce qu'un grand lac pale se lit comme de l'eau et pas
   comme de la brume ou de la glace, et est-ce que la separation par saturation
   de la famille B survit a un petit ecran -- aucune mesure ici n'y repond.
4. Hors perimetre et inchange : les 6 props qui se tiennent dans l'eau du petit
   lac, le bateau du lac (lot LAKE-2), et la sensation d'eau (mouvement de
   surface, reflets).

### Deploiement staging de la planche eau (palier 1, automatique)

`staging` **`693432a`** (merge `--no-ff`, arbre **byte-identique** a la branche
feature : meme hash d'arbre `6d8aae48` des deux cotes, verifie AVANT le push).
CI run **#244** (id 32947596733) **verte** (08:24:31 -> 08:27:54 UTC) --
`Deploy to Vercel [STAGING -- staging]` succes, `[PRODUCTION -- main]`
correctement **skipped**. **`main` NON touche** (`origin/main` toujours
`ae13b99`, verifie apres le push) : ce lot n'a de toute facon rien a livrer en
prod, il n'installe aucune couleur.

**Verifie SUR LE SERVICE, pas dans le log CI, sur DEUX marqueurs
independants :**

| marqueur | avant | apres |
|---|---|---|
| `CACHE_VERSION` | `1787728666` = **07:17:46** (run #243) | **`1787732847` = 08:27:27** *(dans l'etape `Export Web build`, 08:27:23 -> 08:27:28)* |
| `index.pck` servi | **5 862 240** | **5 862 480** |
| `index.wasm` servi | 35 376 909 | 35 376 909 *(inchange, attendu)* |

Le `CACHE_VERSION` est lu **aux deux bouts en `x-vercel-cache: MISS` avec
`age: 0`**, et la valeur d'avant a ete prise **avant le merge** : la bascule
est donc prouvee dans les deux sens et pas deduite du log.

⚠️ **Honnetete sur le second marqueur** : la valeur `index.pck` d'AVANT vient
d'une reponse **`HIT` avec `age: 3899`** (copie de bord datee de 07:19:48).
Elle precede le merge, donc elle est valable comme VALEUR, mais **elle n'est
pas une mesure de fraicheur** et n'est pas comptee comme telle. La lecture
d'APRES, elle, est MISS/age 0.

⚠️ **Le piege HIT/age s'est reproduit DEUX fois et a ete refuse les deux
fois** (age 3899 puis age 191) -- et la seconde fois c'est ma PROPRE lecture
de 08:24:15 qui avait rempli le cache de bord, exactement comme au lot
rideable. Un parametre de requete different ne le contourne pas toujours ; il
faut en changer reellement la valeur.

⚠️ **L'export LOCAL de cette session donne `index.pck` 5 862 512 et le service
en sert 5 862 480 pour le MEME contenu** -- 32 octets d'ecart, une nouvelle
illustration de l'instabilite deja consignee. **Le `.pck` reste un marqueur de
« un nouveau build a ete servi », jamais une preuve d'identite avec l'export
local** ; c'est `index.wasm` qui porte l'identite, et il est identique partout.

Le commit d'hygiene `.gitignore` (les sidecars `.import` que l'editeur fait
pousser a cote des planches sous `docs/`) est **pousse APRES la fin du run
#244**, deliberement : `web-build.yml` porte `cancel-in-progress: true` et
pousser coup sur coup annule le premier run -- piege deja paye au lot de
densification du hub.

## LAKE-MOVE : RECON PURE -- ou le grand lac peut aller, et ce que ca coute (26 aout 2026)

Branche `claude/lake-move-recon-6irqhq`, partie de `staging` (`7f5e6e6`).
**AUCUN fichier de jeu touche** : `git diff --stat origin/staging` ne rapporte
que `scripts/dev/LakeMove{Recon,Capture}Probe.{gd,tscn}` (nouveaux) et ce
document. Ni `HubBuilder.gd`, ni `hub_layout.tres`, ni `HubRegion.gd`, ni
`KeepyHopper.gd`, ni `HubTapInput.gd`, ni `HubCamera.gd`. **Aucune decision
prise** -- ce lot produit les chiffres, l'arbitrage appartient a Mathieu.

### ⚠️ Q1 -- KEEPY MARCHE SUR L'EAU, ET C'EST MESURE

**Verdict : il n'existe AUCUN evitement d'obstacle dans tout le depot.**
`grep -rniE "navigation|navmesh|astar|pathfind|avoid|detour|waypoint"` sur
`*.gd`/`*.tscn`/`*.tres` : **zero occurrence** liee a un chemin. `HubRegion` n'a
que **deux** consommateurs -- `HubTapInput._handle_point` (clampe la
DESTINATION) et `HubBuilder._build` (teste si un prop est atteignable). **Le
hopper ne l'interroge jamais** : `_begin_hop` avance sur une corde droite
(`delta.normalized() * step`) et ne consulte rien en route.

Mesure sur le hopper LIVRE, `--fixed-fps 60`, chaque atterrissage teste contre
l'eau reelle. **Le banc restitue d'abord la diagonale publiee -- 66 hops /
18,700 s, au bond et au millieme pres** : un banc incapable de reproduire un
chiffre deja au dossier n'a pas qualite a en publier un nouveau.

| trajet | hops | atterrissages SUR l'eau |
|---|---|---|
| (-35,-5) -> (-15,-5), traverse le PETIT LAC | 14 | **10 sur le lac** |
| (14,7) -> (28,8), traverse la MARE | 10 | **4 sur la mare, 1 sur le ruisseau** |
| (-2,4) -> (-2,16), traverse le RUISSEAU | 8 | **1 sur le ruisseau** |
| (-35,-20) -> (-12,10), longue corde | 25 | **11 sur le lac** |

**Keepy bondit par-dessus la mare, les deux lacs et le ruisseau, aujourd'hui,
en production.** La regle « une eau est un trou dans la region » ne dit ou un
tap peut ENVOYER Keepy, jamais ou il peut PASSER.

⚠️ **Consequence qui rend tout le lot EXACT plutot qu'extrapole** : puisque
aucun lac ne peut courber une corde, la chaine de bonds d'un trajet est
IDENTIQUE avec et sans lac candidat. Tester les atterrissages reels contre un
disque candidat **mesure** ce candidat, il ne le modelise pas.

### Q2 -- L'EXCLUSION INTERIEURE EXISTE DEJA, ET ELLE FONCTIONNE

**Reponse : OUI, sans un mot de code a changer.** `HubRegion.contains()` ouvre
deja sur `if in_lake_water(flat): return false` -- le grand lac EST un trou, et
la doc du fichier le nomme « the one subtraction in it ». `clamp_to()` genere
des candidats dont `_out_of_water(flat)`, qui pousse radialement hors du
disque : ce candidat est correct pour un trou INTERIEUR exactement comme pour
un trou de bord, parce qu'il ne suppose rien sur la position du disque.

Ce qui manquerait pour un lac au milieu du carre n'est donc PAS `clamp_to` --
c'est le hopper (Q1). Un tap sur le lac serait bien ramene a la rive ; un
trajet qui PASSE au-dessus continuerait de passer au-dessus.

### Q3 -- LA CARTE, ET DEUX PRECISIONS SUR L'ANNONCE

203 entrees de layout : 3 portails, **15** landmarks, 172 props de scatter,
plus mare / petit lac / grand lac / ruisseau / barque / 3 ilots / 5 pontons.

⚠️ **« 12 landmarks » du brief est juste pour le PLATEAU** : 12 sont sur le
plateau (anneaux a d~12,7, ~21, ~30,5), et les **3 autres sont poses sur les
ilots du grand lac** -- leurs positions sont identiques a celles des ilots
(`(-50,48;-3,06)`, `(-63,65;-13,14)`, `(-47,34;-19,35)`), donc ils
demenageraient AVEC le lac.

Portails : `chased` (-5,40;-4,60), `quizz` (0;-7,20), `battle` (5,40;-4,60),
tous a d~7,1. Mare (20,70;7,40) r 3,20. Petit lac (-25,10;-5,30) r 8,00. Grand
lac (-52,82;-11,23) r 20, az 282, d 54. Ruisseau : 12 points de trace, de
(17,58;6,67) a (-18,54;-0,73), largeur 1,20.

**Densite par secteur de 30 deg** (scatter, par anneau radial) -- les plus
charges sont az 300-330 (26) et 240-270 (22), les plus libres az 330-360 (8)
et 60-90 (10).

⚠️ **Le plus grand disque libre, et c'est ce qui decide Q4** : en evitant les
portails ET les landmarks, le maximum atteignable est **R = 11,33** (az
180-210). **Aucun disque de rayon 20 ne tient nulle part sur le plateau sans
recouvrir un landmark.** En n'evitant que les portails, le maximum monte a
**20,15** (az 120-150 et 210-240).

### ⚠️ Q4 -- P2 TEL QUE SPECIFIE EST GEOMETRIQUEMENT INFAISABLE

Deux prémisses du brief ne survivent pas a la mesure.

**1. La contrainte P2 est PAR AXE, pas radiale.** Le brief donne « centre a
15 u MAXIMUM du centre du plateau (15 + 20 = 35) ». Un disque r=20 tient dans
le carre ssi `|cx| + 20 <= 35` ET `|cz| + 20 <= 35`, donc `|cx| <= 15` et
`|cz| <= 15` : le centre peut etre a **21,21 u** du centre (au coin de la
boite 15x15). La contrainte reelle est plus large que l'annonce.

**2. Et pourtant AUCUN centre n'est viable.** Balayage exhaustif de la boite au
pas 0,5, avec la seule exigence de ne pas engloutir mare, ruisseau et portails :

| rayon, entierement dans le carre | verdict |
|---|---|
| **20** | **AUCUN CENTRE N'EXISTE** |
| **18** | **AUCUN CENTRE N'EXISTE** |
| 16 | faisable, meilleur centre (15,50;-19,00), degagement min **7,71 u** |
| 14 | faisable, (7,50;-21,00), 14,12 u |
| 12 | faisable, (8,50;-23,00), 17,56 u |

Le meilleur centre r=20 que le brief demande, (15;15), **recouvre la mare de
13,70 u et le ruisseau de 13,79 u** : il engloutit la mare, la majeure partie du
ruisseau, et donc le ride en barque. **Le rayon maximum d'un lac entierement
dans le plateau est 16.**

### Q4 -- LE TABLEAU DES CANDIDATS

Trajets marches une fois sur le hopper livre ; les atterrissages sont ensuite
testes contre chaque disque (exact, cf. Q1). Jeu de 10 trajets, 340 bonds.

| candidat | dedans | aire perdue | portails | landmarks | scatter | bonds sur l'eau | pire trajet |
|---|---|---|---|---|---|---|---|
| **ACTUEL** az282 d54 r20 | non | 26,7 u2 (0,55 %) | 0 | 0 | 0 | **0 / 340** | 0 |
| **P1** (35;-35) r20, a cheval | non | **314,2 u2 (6,41 %)** | 0 | **0** | **1** buisson | 28 / 340 | 14 |
| P1' (-35;35) r20 | non | 314,2 u2 (6,41 %) | 0 | 0 | 2 rochers | 27 / 340 | 14 |
| **P2** (15;15) r20 | oui | **1 256,8 u2 (25,65 %)** | 0 | **4** | **51** | **90 / 340** | **27** |
| **P2f** (15,5;-19) **r16** | **oui** | 804,5 u2 (16,42 %) | 0 | 3 | 25 | -- | -- |
| P3a (-27;27) r8 | oui | 201,1 u2 (4,10 %) | 0 | **0** | **0** | 20 / 340 | 10 |
| **P3b** (24,5;-25) **r10** | oui | 314,3 u2 (6,41 %) | 0 | **0** | **2** buissons | 26 / 340 | 13 |
| P3c (22;19) r12 | oui | 452,4 u2 (9,23 %) | 0 | 1 | 6 | 32 / 340 | 16 |

⚠️ **LE PIRE CAS DE TRAVERSEE NE BOUGE POUR AUCUN CANDIDAT : 18,700 s.**
Mesure, pas deduit -- la diagonale du carre coute 66 hops / 1 122 frames avec
ou sans lac, **parce qu'un lac ne peut pas courber une corde**. Le cout d'un
lac interieur n'est pas du TEMPS, c'est que Keepy marche sur l'eau : P2 met
**27 bonds sur 66 au-dessus du lac** sur cette meme diagonale.

**Separation d'avec le petit lac** (la contrainte d'origine du chantier : ils
se touchent a 0,347 u) : **tous les candidats les separent**, de +13,50 u
(P1') a +39,04 u (P1). Aucun ne recree le contact.

### Q5 -- LE LAC N'EST PAS VISIBLE, ET LA CAMERA NE PEUT PAS SE TOURNER

⚠️ **Fait qui decide la question : `HubCamera` a une rotation FIXE, elle ne
lace JAMAIS** (par conception -- un `look_at` re-vise chaque frame ferait
tanguer l'horizon au rythme des bonds). Elle regarde toujours -Z, fov 45
KEEP_WIDTH, pitch -34. Un corps est dans le cadre **ssi son gisement est a
+-22,5 deg de -Z**. « Orienter la camera vers le lac » est donc impossible :
la seule facon de voir une chose est de se placer de facon qu'elle soit deja
devant soi.

Captures offscreen reelles, 1080x1920, `xvfb` + `opengl3` (jamais
`--headless` seul, driver DUMMY sans valeur), disques candidats construits
DANS la sonde et jamais dans le layout :

| candidat | gisement depuis le centre | fraction du disque dans le cadre | positions du plateau avec vue reelle |
|---|---|---|---|
| **ACTUEL** | **-69,1 deg** | **0 %** | **4,4 %** |
| P1 (35;-35) r20 | +38,6 deg | 12 % *(sliver)* | 35,7 % |
| P2 (15;15) r20 | -- | **camera DANS l'eau** | 31,0 % |
| **P2f (15,5;-19) r16** | **+29,1 deg** | **39 %** | **50,4 %** |
| P3b (24,5;-25) r10 | +35,9 deg | 2 % *(sliver)* | 39,7 % |
| P3a (-27;27) r8 | -123,8 deg | 0 % | 6,8 % |

**La capture depuis le centre sur l'arbre LIVRE ne montre AUCUNE eau** -- de
l'herbe, des arbres, les trois portails, des fleurs. La plainte de Mathieu est
exacte et desormais prouvee a l'image.

⚠️ **Le booleen « dans le cadre » ment.** P3b est techniquement visible depuis
le centre (bord a 22,1 deg contre un cadre a 22,5) : c'est un **sliver de
0,4 deg** a 41,8 u sous la brume, et le rendu ne montre rien. **Le seul
candidat clairement visible depuis le centre est P2f**, et sa capture le
confirme : une grande etendue pale derriere le portail Battle.

### Q6 -- LA CHAINE D'ADJACENCE EST DE TROIS MAILLONS, PAS D'UNE

⚠️ **Troisieme prémisse corrigee.** Le brief dit que la famille B a ete imposee
« UNIQUEMENT par la paire qui se touche » (singulier). **Mesure : il y a TROIS
paires en contact, en chaine.**

```
mare --(-0,596 u)-- ruisseau --(-0,605 u)-- petit lac --(+0,347 u)-- GRAND LAC
```

Le ruisseau part de la rive de la mare et arrive sur celle du petit lac -- par
construction, c'est ce qui en fait un connecteur. **Deplacer le grand lac ne
casse qu'UN maillon sur trois** ; la chaine mare-ruisseau-petit lac subsiste et
continue d'exiger une echelle de saturation a trois crans.

La famille livree separe par la **SATURATION seule** -- la teinte est quasi
constante (170,0 a 180,0 deg, 10 deg d'ecart) :

| corps | hex | H | **S** | V | alpha |
|---|---|---|---|---|---|
| mare | `#14FFD8` | 170,0 | **0,922** | 1,000 | 0,78 |
| **petit lac** | **`#40E0D0`** | 174,0 | **0,714** | 0,878 | 0,96 |
| ruisseau | `#B8FFFF` | 180,0 | **0,278** | 1,000 | 0,65 |
| **grand lac** | `#CCFFFD` | 177,7 | **0,200** | 1,000 | 0,85 |

⚠️ **`#40E0D0` -- la couleur que Mathieu a validee a l'ecran -- EST DEJA,
exactement, l'albedo du petit lac.** Et les deux corps dont il se plaint
(« ruisseau blanchatre », grand lac « glacier ») sont **precisement les deux
plus bas de l'echelle de saturation**, 0,278 et 0,200. Le defaut n'est pas une
teinte mal choisie : c'est l'echelle de saturation qui, pour separer quatre
corps enchaines, a du pousser les deux derniers vers le blanc.

**Reponse mesuree a la question posee : une famille turquoise homogene ne
devient PAS possible par un simple deplacement.** La co-visibilite n'est
eliminee par aucun candidat -- grand lac + petit lac restent co-visibles depuis
4,4 % a 11,0 % des positions, grand lac + ruisseau depuis 7,9 % a 26,6 %.

**Ce qu'un deplacement achete reellement, et c'est net** : le grand lac cesse
d'etre ADJACENT a quoi que ce soit (ecarts mesures : P1 +21,5 / +39,0 / +24,6 ;
P3b +19,4 / +35,4 / +21,8 ; P2f +7,7 / +18,9 / +9,2 sur mare / petit lac /
ruisseau). **Il sort de l'echelle et peut reprendre `#40E0D0`** -- deux corps
turquoise a 20 u l'un de l'autre dans un cadre n'ont aucun bord commun a faire
lire, contrairement a deux corps qui se touchent. Le ruisseau, lui, **reste
coince entre la mare et le petit lac** et garde son probleme : c'est un lot
distinct, et aucun placement du grand lac ne le resout.

### DOCTRINE PERMANENTE : LE RENDU N'EST PAS AFFINE EN ALPHA

Consignee ici parce que c'est le lot WATER-HUE-2 qui l'a payee, et qu'elle vaut
pour tout reglage d'eau a venir. Le modele du lot WATER-HUE-1 avait ete cale
sur **DEUX points** (l'alpha livre et l'opaque) puis extrapole ; il a
**sous-estime les QUATRE plans d'eau**, qui sont sortis a **2,48-2,94:1** aux
alphas predits, tous **sous le plancher de 3,0**.

**Deux points definissent une droite, ils ne prouvent pas la linearite.** Tout
reglage d'alpha doit passer par un **BALAYAGE direct** -- mesurer la valeur a
chaque cran candidat -- **jamais par une forme fermee**.

### Ce que ce lot laisse au depot

Deux sondes de mesure sous `scripts/dev/` (couvert par `exclude_filter` :
**0** ligne `Storing File` pour `res://scripts/dev` sur 225, et **0**
occurrence de `LakeMoveRecon` dans le `.pck`). `ProbeTimeoutAudit` passe de
**43 a 45 sondes scenes**, toutes armees.

⚠️ **`LakeMoveReconProbe` tourne EN HEADLESS, pas sous `xvfb`** -- elle ne lit
aucun pixel (positions et transforms seulement), et sous llvmpipe elle n'avait
pas depasse la phase de controle. Meme famille que la lecon deja consignee pour
`PursuerFramingAudit`. `LakeMoveCaptureProbe`, elle, DOIT tourner sous `xvfb` :
elle lit des pixels, et `--headless` forcerait le driver DUMMY.

⚠️ **Defaut trouve dans ma propre sonde et corrige** : quand la camera est
DANS le disque, `asin(r/d)` n'a pas de sens et le demi-angle vaut 90 deg, pas
0. La premiere version imprimait « off screen » pour un plan qui n'est QUE de
l'eau -- exactement le genre d'etiquette qui survit au run qui l'a produite.

### Reste ouvert -- c'est l'arbitrage de Mathieu, pas une question technique

1. **P2 tel que specifie n'existe pas** (r=20 entierement dedans : aucun centre).
   Le choix reel est entre **P2f r=16** (le seul clairement visible du centre,
   50,4 % de couverture -- mais 16,42 % du plateau perdu, 3 landmarks et 25
   props recouverts), **P3b r=10** (6,41 % perdu, 0 landmark, 2 buissons, 39,7 %
   de couverture mais un sliver depuis le centre), et **P1 a cheval r=20**
   (6,41 % perdu, 0 landmark, 1 buisson, 35,7 %).
2. **Aucun de ces choix ne change une seconde de traversee**, et tous mettent
   des bonds sur l'eau (20 a 90 sur 340). **Marcher sur l'eau est le vrai cout,
   et il n'a pas de correctif dans ce lot** : il faudrait un evitement dans
   `KeepyHopper`, qui n'existe nulle part et serait son propre chantier.
3. **Le ruisseau restera delave** quoi qu'il advienne du grand lac (chaine a
   trois maillons ci-dessus).

### Deploiement staging de la recon lake-move (palier 1, automatique)

`staging` **`8c243b8`** (merge `--no-ff`, arbre **byte-identique** a la branche
feature : meme hash d'arbre des deux cotes ET `git diff` vide, verifie AVANT le
push). CI run **#247** (id 32974312057) **verte** (13:27:30 -> 13:30:25 UTC) --
`Deploy to Vercel [STAGING -- staging]` succes, `[PRODUCTION -- main]`
correctement **skipped**. **`main` NON touche** (`origin/main` toujours
`ae13b99`, verifie apres le push). **Le contenu de JEU est rigoureusement
inchange** : le diff ne porte que sur `CLAUDE.md` et quatre fichiers de sonde
sous `scripts/dev/`, aucun n'etant une ressource Godot packee.

| marqueur | avant | apres |
|---|---|---|
| `CACHE_VERSION` | `1787735262` = **09:07:42** (run #246) | **`1787750998` = 13:29:58** *(dans la fenetre du run #247)* |
| `index.pck` servi | *(non lu avant le merge -- voir ci-dessous)* | **5 862 880** |
| `index.wasm` servi | -- | **35 376 909** *(inchange, attendu)* |

⚠️ **Honnetete sur la couverture** : la bascule n'est prouvee DANS LES DEUX
SENS que sur le `CACHE_VERSION` ; sa valeur d'avant a ete relevee avant le
merge. Le `.pck` servi n'a ete lu qu'APRES, donc il vaut comme second marqueur
independant de l'etat courant, pas comme preuve de transition. Les deux
lectures d'apres sont `x-vercel-cache: MISS` avec `age: 0`.

⚠️ **Le piege HIT/age s'est reproduit DEUX fois et a ete refuse les deux
fois** (age 15479 puis 15649, la meme copie de bord vieillissant entre mes
deux lectures). Un parametre de requete different ne l'a pas bustee ; seul un
changement reel de valeur y est parvenu.

⚠️ **L'API GitHub Actions a de nouveau servi une reponse PERIMEE, et cette
fois c'est net** : un appel `list_workflow_jobs` **posterieur a 13:30:25** --
donc apres la fin reelle du run -- rendait encore « Import project resources /
in_progress » fige a 13:28:01, **byte-identique** a l'appel precedent. C'est le
`CACHE_VERSION` servi qui a tranche, comme aux runs #201, #202, #226, #229 et
#242. **Nuance a garder de RIDE-1** : avant de crier a l'API perimee, verifier
qu'une etape ne soit pas simplement lente ; ici la borne temporelle du run
lui-meme (`updated_at` 13:30:25) l'a exclu.

⚠️ **L'export LOCAL de cette session donne `index.pck` 5 862 944 et le service
en sert 5 862 880** pour le meme contenu -- 64 octets d'ecart, enieme
illustration de l'instabilite deja consignee. `index.wasm` est identique
partout (**35 376 909**, md5 `af4a8fc2925d992348eb30deeeb54360`) : c'est lui
la preuve d'identite, jamais le `.pck`.

## RECON SPAWN-LAKE : un second grand lac devant le spawn — GEOMETRIQUEMENT POSSIBLE, mais PAS a r=16 sans fusionner avec le premier (26 aout 2026)

Branche `claude/spawn-lake-recon-phbzq6`, partie de `staging` (`8772f86`).
**Mesure seule, aucune geometrie posee, aucune couleur changee** :
`git diff --stat` contre `origin/staging` ne rapporte que
`scripts/dev/SpawnLakeReconProbe.{gd,tscn}` et
`scripts/dev/SpawnLakeCaptureProbe.{gd,tscn}` (nouveaux) plus ce document.
Ni `HubBuilder.gd`, ni `hub_layout.tres`, ni `HubRegion.gd`, ni
`KeepyHopper.gd`, ni `HubTapInput.gd`, ni `HubCamera.gd`. Regle n°1
verifiee AU DEBUT : `git fetch --all --prune` + tri des refs par date +
comparaison d'ARBRES (pas de noms) — `origin/staging` est la ref la plus
recente du depot, aucune branche ne porte ce brief.

Demande de Mathieu : AJOUTER un second lac (pas deplacer celui de
LAKE-MOVE-1), rayon 16, devant le spawn, visible des l'entree. Methode :
sweep geometrique offline en Python (meme doctrine que LAKE-MOVE RECON —
"chosen by the python sweep... re-measured on the shipped hopper"), puis
verification sur le VRAI moteur (`SpawnLakeReconProbe`, headless,
`--fixed-fps 60`, KeepyHopper reel) et une VRAIE capture camera
(`SpawnLakeCaptureProbe`, `xvfb` + `opengl3`, jamais `--headless` seul).

### Q1 — SPAWN, MESURE sur la scene live

`scenes/HubWorld.tscn` : le noeud `Keepy` ne porte AUCUN transform
(`Vector3.ZERO` par defaut de `Node3D`) — confirme en lisant
`Keepy.global_position` au boot sur la scene REELLEMENT instanciee :
**`(0, 0, 0)`**. `Camera3D` a un `transform` fige dans la scene
(`scripts/hub/HubCamera.gd:22`, `OFFSET = Vector3(0.0, 7.6, 8.9)`,
`_wanted()` = position au sol de Keepy + `OFFSET`) : au spawn, camera a
**`(0, 7.6, 8.9)`**, lu en direct sur le noeud instancie plutot que
recalcule a la main.

**Direction "devant"** — la camera ne pivote jamais (`HubCamera.gd`,
rotation fixe, pas de `look_at`) : `forward = -basis.z = (0, -0.55919,
-0.82904)`, soit **34,000 deg** de pitch vers le bas (`asin(0.55919)`,
reproduit exactement le -34 deg documente dans `HubCamera.gd`) et une
composante horizontale **pure -Z**. **"Devant Keepy a l'ecran" au spawn =
l'axe -Z**, sans ambiguite : la composante horizontale du forward est
`(≈0, -0.829)`, aucun decalage en X.

Point au sol au centre de l'ecran, au spawn : **`(0, 0, -2.368)`** (calcul
`camera + t*forward` avec `t` tel que `y=0`).

Distances, mesurees sur la scene reelle :

| | distance |
|---|---|
| spawn -> centre du plateau | **0,000** (le spawn EST le centre) |
| spawn -> portail `chased` (-5,40;-4,60) | **7,094** |
| spawn -> portail `quizz` (0;-7,20) | **7,200** |
| spawn -> portail `battle` (5,40;-4,60) | **7,094** |

**Formule de bearing validee AVANT d'etre utilisee, pas supposee** :
`bearing = atan2(dx, -dz)` avec `(dx,dz) = cible - camera` reproduit au
dixieme de degre pres les deux seuls chiffres deja publies dans ce depot
sur cet axe — l'ancien grand lac `(-52,82;-11,23)` donne **-69,1 deg**
(publie par LAKE-MOVE RECON) et le grand lac actuel `(15,5;-19,0)` donne
**+29,1 deg** (publie par LAKE-MOVE-1). Les deux assertions passent dans
`SpawnLakeReconProbe`.

### Q2 — CARTE COMPLETE et PLACE RESTANTE, sur l'arbre LIVRE (post LAKE-MOVE-1)

203 entrees de layout, relues via le script livre lui-meme (positions,
rayons) : 3 portails, 15 landmarks (**12 sur le plateau, 3 sur les ilots
du grand lac** — confirme `offshore` sur la scene reelle), 172 props de
decor, 3 ilots, 5 pontons, et les 4 plans d'eau :

| corps | centre | rayon eau | rayon berge |
|---|---|---|---|
| mare (`pond`) | (20,70;7,40) | 3,20 | 3,62 |
| petit lac (`lake`) | (-25,10;-5,30) | 8,00 | 9,05 |
| **grand lac (`greatlake`)** | **(15,50;-19,00)** | **16,00** | **17,30** |
| ruisseau (`stream`) | 12 points, (17,58;6,67) -> (-18,54;-0,73) | largeur 1,20 | — |

**Surface d'eau TOTALE actuelle : 1 086,82 u2 = 22,180 % des 4 900 u2**
(mare 32,17 + petit lac 201,06 + grand lac 804,25 + ruisseau ~49,34 en
approximation par corde — sous-estime legerement l'aire reelle du ruban
spline, meme sens d'erreur que `_on_stream()` de `LakeMoveReconProbe.gd`).

**Plus grand disque libre restant**, balaye au pas 0,5 sur tout le carre
puis affine a 0,02 :

| contrainte | rayon max | centre |
|---|---|---|
| (a) evite portails + eaux existantes seulement | **15,415** | **(-19,58;19,58)** |
| (b) evite AUSSI les 12 landmarks du plateau | **11,391** | **(-6,44;23,60)** |

⚠️ **Les deux meilleurs emplacements sont DERRIERE le spawn (z positif),
pas devant** — z=+19,58 et z=+23,60 sont du cote OPPOSE a la direction
"devant" (Q1 : devant = -Z). Ca dit deja, avant meme le sweep dirige de
Q3, que la place libre du plateau n'est pas du cote ou Mathieu veut son
second lac.

### Q3 — FAISABILITE DU r=16 DEVANT LE SPAWN — GEOMETRIQUEMENT infaisable comme second lac SEPARE, MESURE

**Lecture stricte du brief d'abord, honnetement** : la condition de
declenchement du sweep degressif ("Si AUCUN centre r=16 ne degage les
portails") est **FAUSSE au sens le plus etroit** — le sweep exhaustif au
pas 0,5 sur tout le demi-plan devant (z<0) trouve **66 centres r=16 qui
degagent les 3 portails**. Mais **AUCUN de ces 66 ne degage AUSSI les eaux
deja en place** : verifie explicitement, **0/66** degagent a la fois les
portails ET les banques de la mare, du petit lac, du grand lac et du
ruisseau. C'est la vraie reponse a la question posee ("AJOUTER un lac, pas
fusionner avec l'existant") — publiee franchement plutot que masquee
derriere la lecture litterale qui aurait dit "oui, ca passe".

**Le plus proche du spawn parmi les 66** — `(16,50;-18,00)` — est
quasiment **superpose au grand lac existant** : distance eau-a-eau
**+0,016** (quasi zero), banques **-1,284** (elles se CHEVAUCHENT). Le
second candidat symetrique, `(-16,50;-18,00)`, mange lourdement le petit
lac (`d_eau = -8,662`). **La zone "devant le spawn" est deja largement
occupee par le grand lac lui-meme** — a r=16, il n'y a tout simplement pas
la place d'en poser un second a cote sans toucher le premier.

**Sur l'axe strict x=0 (droit devant, aucun decalage lateral) : AUCUN
centre r=16 ne degage meme les portails** — verifie par balayage complet
de la plage legale (`z` de -19 a -16) : les 7 positions testees echouent
toutes sur le portail `quizz` (0;-7,2), qui se trouve litteralement sur le
chemin direct. Un lac r=16 droit devant, sans decalage, est **impossible**
avant meme de considerer les autres eaux.

**Sweep degressif refait sous le CRITERE HONNETE** (portails ET toutes les
eaux existantes, banque a banque, "devant" = z<0), comme le veut l'esprit
de "ajouter" un second lac :

| rayon | centres 100% propres trouves | le plus proche du spawn |
|---|---|---|
| 16 | **0** | — |
| 14 | **0** | — |
| 12 | **0** | — |
| **10** | **142** | **(-12,00;-19,50)**, d(spawn)=22,94 |
| 8 | 527 | (-9,50;-13,50), d(spawn)=16,68 |

**r=10 est donc "le plus grand qui tient devant le spawn"** au sens
demande par le brief (portails + eaux existantes toutes degagees). Detail
complet du centre retenu, `(-12,00;-19,50)` r=10, mesure sur le layout
livre :

- portails : **aucun chevauchement**
- mare : distance eau **29,143** / berge **28,723**
- petit lac : distance eau **1,320** / berge **0,270**
- grand lac : distance eau **1,505** / **berge 0,205** (tres proche —
  voir l'avertissement Q6 plus bas)
- ruisseau : distance **9,277**
- landmarks recouverts : **2** (`(-15,94;-14,87)` a 6,08 ; `(-11,557;
  -27,901)` a 8,41 — ces deux sont a l'INTERIEUR du disque)
- props recouverts : **27** (arbres, buissons, rochers, fleurs, souches —
  liste complete dans le probe)
- surface marchable perdue : **314,16 u2 = 6,411 %** des 4 900
- surface d'eau TOTALE apres ajout : **1 400,98 u2 = 28,591 %**

⚠️ **Le second candidat retenu pour contraste — `(16,50;-18,00)` r=16, le
plus proche du spawn parmi les 66 "portails seuls"** — est aussi teste
(voir Q4/Q5) precisement PARCE QU'il illustre le risque de fusion : ses
banques chevauchent celles du grand lac de 1,284 u.

### Q4 — MARCHER SUR L'EAU, MESURE sur le VRAI KeepyHopper (`--headless --fixed-fps 60`)

`SpawnLakeReconProbe` reproduit d'ABORD, au bond et a la seconde pres, la
diagonale (66 hops / 1 122 frames / 18,700 s) et l'anti-diagonale de
LAKE-MOVE-1 (66 hops, 21 atterrissages sur le grand lac) avant de publier
quoi que ce soit de neuf — **0 echec** sur les deux controles.

Les 10 trajets de LAKE-MOVE + les 3 allers spawn -> portail, tous marches
UNE fois (la chaine de bonds ne depend d'aucun candidat — un lac ne peut
pas courber une corde) :

| trajet | hops | secondes |
|---|---|---|
| spawn -> portail chased/quizz/battle (les 3) | **5** chacun | **1,417 s** chacun |
| diagonale du carre | 66 | 18,700 |
| anti-diagonale | 66 | 18,700 |

**Atterrissages sur chaque candidat, sur l'ensemble des 13 trajets (350
atterrissages au total)** :

| candidat | atterrissages sur l'eau | trajets touches | spawn->portail touches |
|---|---|---|---|
| **retenu, r=10 @ (-12,-19,5)** | **11 / 350 (3,1 %)** | seulement la diagonale du carre (11/66) | **0 / 15** |
| r=16 "portails seuls" @ (16,5;-18) | **42 / 350 (12,0 %)** | anti-diagonale (21/66) + centre->coin SE (21/33) | **0 / 15** |

**Aucun des deux candidats ne touche jamais les 3 allers-retours
spawn->portail** — les portails sont trop pres du spawn (7,1-7,2 u) pour
que ces trajets courts croisent un candidat pose plus loin. Le candidat
r=16 "portails seuls" touche **3,8x plus** de bonds que le candidat r=10
retenu, coherent avec son chevauchement mesure du grand lac existant :
ses 21 atterrissages sur l'anti-diagonale sont EXACTEMENT les 21 deja
comptes sur le grand lac lui-meme en Q4-controle — c'est la meme eau.

### Q5 — VISIBILITE A L'ENTREE, capture REELLE (`xvfb` + `opengl3`, jamais `--headless` seul)

`SpawnLakeCaptureProbe` : Keepy pose exactement au spawn, camera reelle,
viewport 1080x1920. Fraction visible mesuree par
`Camera3D.is_position_in_frustum()` (le test EXACT du moteur, pas une
trigonometrie remaniee a la main) sur une grille de ~1250 points couvrant
chaque disque.

| | bearing | distance | fraction du disque dans le cadre |
|---|---|---|---|
| **grand lac existant** (arbre LIVRE, avant tout ajout) | +29,1 deg | 31,92 | **34,5 %** |
| **candidat retenu r=10 @ (-12,-19,5)** | -22,9 deg | 30,83 | **47,0 %** |

**VERDICT Q5 : OUI, le candidat retenu occupe le cadre des l'entree dans
le hub, et une PLUS GRANDE fraction de son disque est visible que celle du
grand lac deja en place** (47,0 % contre 34,5 %). Deux captures
enregistrees (`before_shipped_from_spawn.png`, l'arbre livre depuis le
spawn ; `after_candidate_from_spawn.png`, le candidat dessine ad-hoc par
le probe, jamais ecrit dans le layout) confirment a l'image : le grand lac
existant reste visible en haut a droite (comme documente par LAKE-MOVE-1),
et le candidat apparait a gauche, **les DEUX plans d'eau visibles dans le
MEME cadre au tout premier instant**.

⚠️ **La capture montre des arbres/rochers/une souche visuellement DANS le
candidat** — attendu et sans consequence pour cette recon : le disque est
dessine tel quel par le probe, sans deplacer aucun des 27 props qu'il
recouvre (Q3), exactement comme LAKE-MOVE RECON l'avait fait pour ses
propres candidats. Une installation reelle relocaliserait ces props,
comme LAKE-MOVE-1 l'a fait pour le grand lac.

### Q6 — COULEUR UNIFORME (`#40E0D0` partout) — question DOCUMENTEE, PAS TRANCHEE

Adjacences eau-a-eau, relues sur les constantes reellement construites par
`HubBuilder`/`HubRegion` (pas recopiees) :

| paire | distance (bord a bord) | touchent ? |
|---|---|---|
| mare <-> ruisseau | **-0,596** | **OUI** (chaine intacte, identique a LAKE-MOVE-1) |
| ruisseau <-> petit lac | **-0,605** | **OUI** (chaine intacte, identique a LAKE-MOVE-1) |
| petit lac <-> grand lac | +18,849 | non |
| mare <-> grand lac | +7,707 | non |
| grand lac <-> ruisseau | +9,154 | non |

**La chaine a trois maillons (mare-ruisseau-petit lac) est RE-VERIFIEE
intacte**, au millieme pres des chiffres publies par LAKE-MOVE-1 —
`SpawnLakeReconProbe` l'asserte explicitement (2 checks, 0 echec). Le
grand lac reste isole de tout, comme documente.

**Co-visibilite (calculee sur la formule de bearing validee en Q1, sur les
positions marchables reelles de `HubRegion`, pas une simple mesure de
distance)** : contrairement au sweep pre-LAKE-MOVE de WATER-HUE-1 (qui ne
trouvait que 3 paires co-visibles), **TOUTES les paires sont desormais
co-visibles depuis AU MOINS une position** — consequence directe du grand
lac deplace a l'INTERIEUR du carre :

| paire | co-visible | % des positions marchables scannees |
|---|---|---|
| mare <-> petit lac | oui (sliver rare) | 0,1 % |
| mare <-> grand lac | oui | 19,3 % |
| petit lac <-> grand lac | oui | 14,8 % |
| grand lac <-> ruisseau (point milieu) | oui | 12,5 % |
| mare <-> ruisseau | oui (TOUCHENT) | trivial |
| petit lac <-> ruisseau | oui (TOUCHENT) | trivial |

**Ce qu'une couleur unique produirait** : si les 3 corps qui se touchent
(mare + ruisseau + petit lac) portent la meme teinte, ils se liraient
comme UNE masse continue de **282,57 u2** (somme des disques, le ruisseau
compte en approximation de corde). Le grand lac resterait visuellement
separe de cette masse (aucun contact), MAIS —

⚠️ **LE CANDIDAT Q3 RETENU (r=10 @ -12,-19,5) CHANGE CE CALCUL, et c'est
un couplage que Q3 seul n'aurait pas revele** : sa **banque** n'est qu'a
**0,205** de celle du grand lac existant (Q3, ligne "greatlake bank" =
0,205) — quasiment collees. **Si Mathieu installe ce candidat ET une
couleur uniforme, le second lac fusionnerait visuellement avec le
premier** (masse combinee ≈ 804,25 + 314,16 ≈ 1 118 u2, quasi continue),
ce qui est exactement l'inverse de "un SECOND lac distinct" que la demande
visait. **Non tranche ici, publie pour que Mathieu le pese** : soit
reculer legerement le candidat r=10 (au prix de moins bien degager le
spawn), soit accepter la fusion visuelle des deux grands lacs, soit ne pas
appliquer la couleur uniforme a cette paire precise.

**NE RIEN INSTALLE** — ni geometrie ni couleur, conforme a la consigne.

### Validation

Editeur + templates Godot 4.3-stable installes dans ce sandbox (releases
GitHub officielles, tailles verifiees contre le `Content-Length` — 50 276 070
et 1 073 228 327 octets, aucune troncature). Import headless **exit 0**,
**24 `.scn`** (import complet verifie, pas suppose). Export Web release
**exit 0, 0 erreur GDScript** — export unique et propre (`build/` et
`.godot/` supprimes avant, la lecon deja consignee sur l'auto-contamination
d'un second export sans nettoyage).

`index.wasm` **35 376 909 octets**, md5 **`af4a8fc2925d992348eb30deeeb54360`**
et `index.js` md5 **`4e08904b1b7107858246af44b602067b`** — identiques au
fingerprint deja consigne pour tout lot qui ne touche pas le code moteur,
coherent : ce lot n'ajoute que deux sondes dev-only. `index.pck` 5 863 040
octets (dans la plage deja documentee comme instable d'un export a l'autre,
jamais offert comme preuve). **Piege payload tenu, verifie sur le pack et
pas sur le filtre** : sur **225** lignes `Storing File`, **0** pour
`res://scripts/dev`, `res://assets_source`, `res://docs`, `res://web/` ou
`firebase.json`, et **0** occurrence de `SpawnLake` dans tout le pack.

Sondes : `ProbeTimeoutAudit` (**47 sondes scenes** — 45 + les deux
nouvelles, toutes armees, `SpawnLakeReconProbe` et `SpawnLakeCaptureProbe`
listees explicitement avec `ProbeWatchdog.arm()`), `AssetContractAudit`
(**12/12 visuels, 0/10 colliders deplaces**), `DeathModelAudit`,
`ChargerShapeProbe` — **toutes exit 0**, et **BYTE-IDENTIQUES sur les DEUX
flux (stdout ET stderr)** contre `origin/staging` en worktree separe, meme
graine 20260806, `--fixed-fps 60` : ce lot ne touche a rien que ces quatre
sondes lisent, et l'identite au bit pres le dit plus fort qu'un simple
verdict identique.

⚠️ **`SpawnLakeReconProbe` tourne EN HEADLESS, pas sous `xvfb`** — elle ne
lit aucun pixel (positions et transforms seulement), meme lecon deja
consignee pour `LakeMoveReconProbe` et `PursuerFramingAudit`.
`SpawnLakeCaptureProbe`, elle, tourne SOUS `xvfb` + `opengl3` : elle lit
des pixels via `is_position_in_frustum()` et des captures PNG, et
`--headless` forcerait le driver DUMMY (surface vide, faux vert deja
documente pour cette famille de piege).

### Reste ouvert — c'est l'arbitrage de Mathieu, pas une question technique

1. **r=16 devant le spawn n'existe pas comme second lac SEPARE.** Les
   options chiffrees : accepter la fusion visuelle avec le grand lac
   existant (candidat "portails seuls" a (16,5;-18), qui n'est alors plus
   vraiment un SECOND lac) ; ou reduire le rayon a **10** (le plus grand
   qui degage tout, a (-12,-19,5), 6,41 % de plateau perdu, 2 landmarks et
   27 props a relocaliser) ; ou a **8** si Mathieu veut plus de marge
   (4,10 % perdu, 1 landmark, 20 props).
2. **Le candidat r=10 est deja visible a 47,0 % depuis le spawn**,
   legerement mieux que le grand lac existant (34,5 %) — confirme a
   l'image, pas seulement au chiffre.
3. **La banque du candidat r=10 n'est qu'a 0,205 du grand lac existant** —
   couplage direct avec Q6 : une couleur uniforme fusionnerait
   visuellement les deux grands lacs. A peser AVANT de trancher Q6.
4. **Marcher sur l'eau reste sans correctif** (deja documente par LAKE-MOVE
   RECON) : le candidat retenu ajoute 11 atterrissages sur 350 a la chaine
   de trajets deja mesuree, sur la seule diagonale du carre.
5. **Aucun test device** : les captures sont un rendu llvmpipe sous xvfb,
   pas un ecran de telephone.

## WATER-WALK RECON : ce qu'un ARRET A LA BERGE couterait -- MESURE, aucun code de jeu touche (26 aout 2026)

Branche `claude/keepy-water-collision-recon-6w1a0a`, partie de `staging`
(`2ba12e0` ; `main` = `ae13b99`, les deux exactement comme le brief
l'annoncait). **Recon bloquante : ce lot ne modifie AUCUN fichier de jeu.**
`git diff --stat` ne rapporte que `docs/WATER_WALK_RECON.md` (nouveau) et ce
document. Sonde de mesure JETABLE, supprimee avant le commit --
`ProbeTimeoutAudit` revient a **48 sondes scenes**, le chiffre de
`origin/staging`. **Rapport chiffre complet : `docs/WATER_WALK_RECON.md`.**

**Q1 -- la chaine est calculee HOP PAR HOP, jamais en une fois.** `hop_to()`
(L240) ne fait que poser `_target` ; `_advance()` (L418) relit la position
COURANTE a chaque atterrissage ; `_begin_hop()` (L432) calcule UN saut
(`_hop_to = here + delta.normalized() * min(HOP_DISTANCE, |delta|)`, L434-436)
et `_on_hop_finished()` (L488) rappelle `_advance()` (L504). **Le point
d'insertion d'une troncature est donc entre L436 et L450**, ou un test dans
`_advance` avant L430 -- les deux voient un seul atterrissage candidat a la
fois.

### ⚠️ PREMISSE DU BRIEF PUBLIEE EN ECHEC : `HubRegion` ne connait que 2 des 5 eaux

Le test unique existe bien et est bien centralise -- `HubRegion.contains()`
(L250) sur `in_lake_water()` (L215) sur `_lake_holding()` (L243), une boucle
sur `HubRegion.lakes()`. **Mais cette table ne porte que les DEUX lobes du
grand lac.** Mesure sur la region livree : pond, petit lac et ruisseau
rendent tous `contains() == true` -- ils sont WALKABLE par conception
(l'en-tete de `HubRegion.gd` le dit et explique pourquoi : le bateau embarque
depuis la tete du ruisseau, posee sur la rive du pond). **Une garde couvrant
les 5 corps NE PEUT PAS s'ecrire contre le `HubRegion` d'aujourd'hui** : les
rayons du pond et du petit lac vivent dans `HubBuilder`, et le ruisseau est
un ruban autour d'un spine que seul `HubBuilder` possede.

**Float32 au rim : le brief a raison, et c'est mesure.** 360 azimuts par
disque, chaque disque teste contre LUI-MEME : a exactement `radius`,
**141/360** (pond), **171/360** (petit lac), **115/360** (grand lac A),
**54/360** (lobe B) lisent comme EAU sous le `<` strict ; a `radius + 0.001`,
**0/360 sur les quatre**. Pire glissement 1,907e-06. Echantillonner a
`radius + 0.001`, comme `_out_of_lake()` le fait deja.

### ⚠️ Q3 -- L'EJECTION N'EST PAS LE PROBLEME. C'EST L'EMBARQUEMENT.

Le brief prevenait qu'une garde naive "casse les deux". **Moitie faux,
moitie vrai, et la moitie fausse est celle qu'on aurait protegee.**

* **Le saut d'ejection est INERTE a une garde dans `_begin_hop`** :
  `leave_ride()` construit son tween EN LIGNE (L337-343) et n'appelle jamais
  `_begin_hop` ni `_advance` avant de sauter. Tout `RIDING` est hors
  d'atteinte de la meme facon (`_advance` sort L421, `hop_to` refuse L246,
  `_place_on_route` L363 ecrit le corps directement).
* **Mais la chaine APRES l'ejection ne l'est pas** -- mesure sur une vraie
  ride : atterrissage 1 apres la ride `(-17.548, -1.646)` **SEC**,
  atterrissage 2 `(-19.047, -1.705)` **DANS LE PETIT LAC**. Le
  desembarquement automatique vise `ahead` (L358) le long de la tangente
  au-dela du bout -- et a la queue cette direction pointe dans le lac.
* **L'EMBARQUEMENT est la vraie casse.** La coque est amarree SUR l'eau
  (`_mooring_pose` la pose au bout du ruban) : tete `(17.580, 6.670)` = DANS
  LE RUISSEAU (et 0,0043 u hors du pond) ; queue `(-18.540, -0.730)` = DANS
  LE PETIT LAC (7,995 pour un rayon 8). `_try_board` exige
  `d(coque) <= BOARD_TAP_RADIUS = 2,500`. Marches d'embarquement reelles
  tronquees au dernier atterrissage sec, 6 azimuts par bout, depart a 9 u :
  **5 sur 10 approches NE PEUVENT PLUS EMBARQUER** (2/6 embarquent a la
  tete, 3/4 a la queue), avec des ecarts de 3,000 a 7,500 u.

### Q4 -- le ruisseau : instruit, PAS tranche

**(a)** Le ruban est **CONSTANT a 1,200 u** par construction (offset
`+-0,600` a la perpendiculaire sur les 89 samples) : il n'a ni plus large ni
plus etroit. Ce qui varie est la **portee mouillee vue par une corde
droite** : **1,199 u** (perpendiculaire) a **8,013 u** (rasante), 36 azimuts.
**(b)** `HOP_DISTANCE = 1,500` (lu dans le code), `HOP_HEIGHT 0,600`,
`ARRIVE_EPSILON 0,450`. **(c)** 40 traversees paralleles : **39 sur 40**
posent au moins un atterrissage DANS le ruban, 40 atterrissages mouilles au
total (**~1 arret par traversee**), et **1 sur 40** seulement l'enjambe d'un
saut -- malgre 1,5 > 1,2.

| option | runs mouilles sur les 13 trajets | trajets arretes au moins une fois |
|---|---|---|
| garde uniforme sur les 5 corps | **12** | **10 sur 13** |
| ruisseau exempte | **7** | **7 sur 13** |

**Non choisi ici** -- c'est la decision de Mathieu.

### Q5 -- la detection de portail survit a la troncature

Pas de portail fantome (`_begin_hop` est deterministe en `here`/`_target`,
donc une chaine tronquee est le PREFIXE exact de la chaine entiere : la
troncature retire des atterrissages, elle n'en invente aucun). Aucun disque
de portail ne recouvre d'eau -- eau la plus proche d'un centre de portail
**1,589 u** (battle vs grand lac A) contre un rayon de declenchement lu sur
le `CylinderShape3D` du portail -- donc une garde ne peut jamais supprimer
une entree legitime. Les trois portails sont secs, les cordes
spawn -> portail ont **0,000 u** de portee mouillee, et les trois trajets
spawn -> portail font 5 sauts avec **0 atterrissage mouille**. Aucun portail
n'est detecte pendant une ride (`HubWorld._on_hop_landed` refuse L240).
**MAIS** : depuis 20 u, **12/16, 12/15 et 13/18** des departs secs traversent
de l'eau en approche -- environ trois quarts des approches droites
demanderaient un second tap.

### Q6 -- le cout, et le piege qui le fixe

**MESURE** sur les 10 trajets LAKE-MOVE/SPAWN + les 3 spawn -> portail :
**350 sauts, 93 atterrissages mouilles (26,6 %), 12 runs mouilles**, les 3
trajets vers les portails **inchanges (0 mouille)** -- le 350 et les 3
trajets secs reproduisent les chiffres cites par le brief, ce qui valide le
banc avant qu'on lui fasse confiance.

⚠️ **LE PIEGE, MESURE : un retap IDENTIQUE depuis la berge n'achete RIEN.**
Place au dernier atterrissage sec et redonne la MEME destination :
**0 saut sec sur 4 cas sur 4**. La corde depuis la berge rentre dans l'eau
des son premier saut, donc le joueur DOIT viser hors de la corde.

**EXTRAPOLE, et marque comme tel** : un run mouille coute donc **au moins
DEUX taps** supplementaires (un a cote de l'eau, un pour repartir), soit
**>= 24 taps en plus sur les 10 trajets concernes, >= 2,4 par trajet
concerne**. Le vrai chiffre depend de la facon dont un joueur contourne, et
aucune sonde de ce depot ne peut le mesurer. Ce qui EST mesure : le plancher
n'est pas d'un tap par run, et le premier tap achete tres peu du trajet --
**2 sauts sur 47** (W -> E, 4 %), **1 sur 14** (petit lac court, 7 %),
**12 sur 66** (diagonale, 18 %). Le temps mur ne bouge pas (18,700 s reste
la pire traversee) mais cesse d'etre un seul geste.

### Validation

Editeur Godot 4.3-stable installe dans ce sandbox (release GitHub
officielle, **taille verifiee contre le `Content-Length`** -- 50 276 070
octets, aucune troncature). Import headless **exit 0**, **24 `.scn`**
(import complet verifie, pas suppose). La sonde jetable sort **exit 0,
stderr vide**. Sondes rejouees apres suppression de la sonde :
`ProbeTimeoutAudit` (**48 sondes scenes**, retour exact a la baseline),
`AssetContractAudit` (**12/12 visuels, 0/10 colliders deplaces**),
`DeathModelAudit`, `ChargerShapeProbe`, `LakeZoneProbe` (**0 failure**) --
**toutes exit 0**. Recoupement independant : `LakeZoneProbe` imprime
`33 landings, 21 on great-lake water` pour `(0,0,0) -> (35,0,-35)`, exactement
la ligne `centre -> SE corner 33 sauts / 21 mouilles` de la sonde de ce lot.
Aucun export Web joue : ce lot ne touche aucune ressource Godot.

### Reste ouvert -- ce sont des decisions, pas des questions techniques

1. **Ou vit le test d'eau** : `HubRegion` couvre 2 corps sur 5, l'etendre lui
   fait lire des rayons qui vivent dans `HubBuilder`.
2. **Comment l'embarquement survit** : 5 approches sur 10 perdent le bateau.
   Une exemption "ce trajet est un trajet d'embarquement" est la forme
   evidente, mais `_begin_hop` ignore pourquoi il marche -- cette intention
   vit dans `HubWorld._boarding`.
3. **Le ruisseau, uniforme ou exempte** (les deux couts sont tabules).
4. **La cible du desembarquement automatique** vise dans le petit lac a la
   queue : quelle que soit la garde, ce point demande aussi un clamp.

## RECON ACCES + RENDU DES CINQ EAUX -- la premisse "immersion lisible OU
## disparition brutale" ne survit PAS a la mesure : c'est une troisieme
## chose, pire que les deux (26 aout 2026)

Branche `claude/keepy-water-recon-3w83et`, posee sur
`claude/keepy-water-collision-recon-6w1a0a` (`7b04132`,
`docs/WATER_WALK_RECON.md`, pas encore mergee sur `staging` au demarrage).
**RECON PURE, aucun fichier de jeu touche.** Decision de Mathieu deja prise
et **non re-arbitree ici** : Keepy doit pouvoir entrer dans les cinq corps
d'eau (mare, petit lac, ruisseau, 2 lobes du grand lac) ; la garde des 2
lobes sera retiree dans le lot suivant ; le chantier "arret a la berge" de
`docs/WATER_WALK_RECON.md` est abandonne. Le bateau est hors perimetre.
Detail chiffre complet des six questions : `docs/WATER_ACCESS_RENDER_RECON.md`.

**Ce qui compte le plus** : `WaterImmersionCaptureProbe` (rendu reel, xvfb +
opengl3, jamais `--headless` qui donne un viewport DUMMY 1920x1920 au lieu
du vrai 1080x1920 -- piege reconfirme independamment de celui deja consigne
ailleurs) a mesure, pixel par pixel et par capture ecran, Keepy enfonce a
0/30/60% dans le ruisseau (a=0.90) ET dans le lobe spawn du grand lac
(a=0.95) : **les SIX cas donnent le meme resultat, BOTH == KEEPY-ONLY au
dernier chiffre pres, WATER-ONLY totalement different.** L'eau ne dessine
JAMAIS par-dessus la silhouette de Keepy, quel que soit l'enfoncement
synthetique ou l'alpha. Ce n'est ni « immersion lisible » ni « disparition
brutale » -- c'est un TROISIEME resultat, plus mauvais que les deux : le
corps reste TOUJOURS pleinement opaque et visible, sans aucun signe visuel
d'etre dans l'eau. Mecanisme mesure et pas suppose : un maillage opaque
plein devant un plan transparent plat gagne le test de profondeur partout
ou sa silhouette dessine, quelle que soit sa position Y -- ce n'est pas un
bug de tri gl_compatibility a corriger, c'est le comportement correct et
attendu de cette geometrie. **Consequence directe pour le lot suivant :
deplacer le Y de Keepy seul ne produira JAMAIS un effet de submersion
visible, sur aucun renderer.** Un effet lisible demandera un mecanisme qui
NE COMPTE PAS sur l'occlusion de l'eau -- degrade de couleur vers la teinte
de l'eau, cue de squash/echelle, decals de vaguelettes a la ligne d'eau,
et/ou un shader a plan de coupe sur le materiau de Keepy (aujourd'hui plat
unshaded, aucun de ces mecanismes n'existe).

**Les cinq autres reponses, en bref** (chiffres complets dans le doc dedie) :
Q1 -- `KeepyHopper.gd` ecrit `y` de facon **purement procedurale**, jamais
via terrain/collision (grep confirme) : parabole `4t(1-t)*HOP_HEIGHT` en
vol, `0.0` exact au repos, `RIDE_SEAT_Y=0.14` constant en bateau (hors
perimetre). Q2 -- les cinq surfaces d'eau sont a des Y differents,
**0.0270 (grand lac A) a 0.0950 (ruisseau)**, tous a moins de 10cm du repos
de Keepy (`y=0`) -- alphas confirmes : mare/petit lac/lobes 0.95, ruisseau
0.90. Q4 -- `HubRegion.contains()` ne connait que 2 corps sur 5 (les lobes
du grand lac) ; etendre a cinq demande DEUX formes de travail differentes
(2 lignes de disque triviales pour mare/petit lac, un vrai test
point-vers-polyligne pour le ruisseau, pas une case de plus dans la meme
table) -- et une **collision de nom trouvee au passage** :
`HubBuilder.LAKE_WATER_RADIUS` (8.0, le PETIT lac) contre
`HubRegion.LAKE_WATER_RADIUS` (16.0, le GRAND lac), meme identifiant, deux
fichiers, deux corps differents -- a renommer avant toute table partagee.
Q5 -- hauteur du modele **MESUREE a 1.3501u** (`visual_aabb()` sur le
vrai .glb installe) ; a 30%/60% d'enfoncement (si un futur lot decoupe
reellement la geometrie), il resterait 70%/40% de la hauteur visible, sur
les cinq corps sans distinction reelle (leur ecart de Y est negligeable
face a 1.35u). Q6 -- le ruisseau **n'a aucune berge** (il alpha-blend
directement sur le sol), donc rien ne peut masquer un corps qui s'y tient ;
la camera suit toujours Keepy au meme cadrage relatif, confirme a la fois
par calcul (une fois le piege du viewport DUMMY headless evite) et par
capture reelle (le ruisseau, Keepy dedans, se lit sans ambiguite dans le
meme cadre que la mare, le grand lac et les trois portails).

**Reste ouvert, decision du lot suivant, pas de celui-ci** : le choix du
mecanisme de rendu de submersion (Q3) ; le renommage de collision (Q4) ;
le test point-vers-polyligne du ruisseau et sa marge float32 propre (Q4) ;
et l'occlusion possible par des houppiers d'arbres au-dessus du ruisseau,
mesuree ailleurs mais pas re-verifiee ici (Q6).

## LIGNE DE FLOTTAISON : RECON PURE -- il faut un SHADER, et la metrique de contraste du brief tombe a la mesure (27 aout 2026)

Branche `claude/water-tint-height-recon-avzd47`, partie de `staging`
(`2c1563f`, qui porte la teinte uniforme 75 %). `origin/main` = `a007e78`,
conforme. Refs triees par date et comparees par ARBRE : toutes les branches
plus recentes que `main` sont deja ancetres de `origin/staging`, **aucune
session concurrente**. **AUCUN fichier de jeu touche** : `git diff --stat`
ne rapporte que `docs/WATERLINE_RECON.md`, dix captures sous
`docs/color-sheets/` et ce document. Detail chiffre complet :
**`docs/WATERLINE_RECON.md`**.

Retour device : la teinte uniforme a 75 % rend Keepy entierement turquoise
et ne se lit pas comme « il a pied ». Decision de Mathieu, **non
re-arbitree ici** : ce sont des PATAUGEOIRES, le CORPS est mouille et la
TETE reste seche, avec une **ligne de flottaison a Y CONSTANT dans le
monde**. Nage et bateau hors perimetre.

**Keepy est bien UN SEUL MESH, l'ambiguite est fermee** : le `.glb` porte
1 mesh / 1 primitive / 1 materiau (3121 verts). Les « 2 instances » de la
recon precedente sont `Body` (le `ModelSlot`, `mesh = null` une fois le
modele installe) plus `Mesh1_0`, le seul qui dessine. Il n'y a donc aucune
decoupe tete/corps exploitable par ecriture de propriete -- le shader est
la seule route, et ce serait le premier du hub.

### ⚠️ QUATRE PREMISSES TOMBENT A LA MESURE, dont trois sont les miennes

1. **La metrique du brief tourne A L'ENVERS, et c'est la correction la plus
   lourde.** Le brief demande « le contraste de la TETE contre l'eau » et de
   chiffrer le gain contre les 1,64-1,81:1 de la teinte uniforme. Mesure :
   une tete SECHE marque **1,13-1,23:1**, soit **MOINS BIEN** que les
   **1,89:1** de la teinte livree. Le WCAG est un rapport de LUMINANCE,
   l'eau rend clair (0,457) et le creme naturel de Keepy aussi (0,409),
   alors que la teinte 75 % est sombre (0,193). Ce qui fait lire une tete
   seche comme « pas de l'eau », c'est la TEINTE : **155 deg** d'ecart
   contre **41 deg** pour le corps teinte. Les deux axes sont publies
   partout ; aucun des deux seul n'est la reponse.
2. **MIENNE : « le materiau livre cull les faces arriere ». FAUX** --
   `cull_mode = 2` (DISABLED), `transparency = 0`, UNSHADED, texture
   1024x1024. Mon `cull_disabled` etait le bon choix, mon assertion la
   mauvaise.
3. **MIENNE : « le premier rendu de l'echelle est moucheté, donc ca
   z-fight ». FAUX** -- mesure a **0,96 flip/colonne sur les QUATRE
   combinaisons** de `render_mode` : la frontiere est propre partout. Ce
   que je lisais comme du moucheté etait la fourrure sur une pose de
   profil.
4. **MIENNE : « 6 des 34 checks de `WaterTintProbe` vont casser ». FAUX,
   c'est 5** -- mesure en patchant temporairement `HubWorld` puis en
   revertant (34 OK / 0 echec avant, **29 OK / 5 echecs apres**). Le 6e
   PASSE **pour la mauvaise raison** : c'est une assertion NEGATIVE, le
   lecteur rend MAGENTA sur un cast rate, et MAGENTA n'est effectivement
   « pas la couleur de base ». Un check qui ne peut pas echouer dans le
   sens ou il pointe.

S'y ajoutent trois defauts de MES sondes, chacun ayant produit un chiffre
faux et confiant : une erreur de parse (15 min a ne rien mesurer -- le
piege que ce fichier documente deja), un diff CROISE ENTRE POSES qui
mesurait le deplacement de la silhouette et rapportait un Keepy qui monte
comme **de plus en plus mouille** (0,189 -> 0,948, l'exact inverse), et
`--fixed-fps 60` oublie (un hop de 0,28 s termine en **trois** frames
llvmpipe).

### Ce qui est MESURE et acquis

* **`gl_compatibility` fournit tout** : `varying` + `MODEL_MATRIX` en
  `vertex()`, `INV_VIEW_MATRIX` en `fragment()` (equivalent, mesure
  identique), `uniform sampler2D : source_color`, `step()`, `mix()`. Une
  variante volontairement cassee sort l'erreur exacte -- le detecteur peut
  echouer rouge.
* **L'ESPACE EST LE PIEGE, et l'ecart n'est pas subtil** : model
  `VERTEX.y` va de -0,6291 a +0,6283, monde de 0 a 1,3500 (slot a 0,9,
  offset -0,2246, echelle 1,07368). `water_y = 0,55` mouille **40,7 %** de
  lui en monde et **93,8 %** en modele. Mesure : le shader monde le seche
  completement des que ses pieds passent la ligne (0,187 -> 0,000) ; le
  shader modele le laisse trempe a **toutes** les altitudes (0,906 ->
  0,914) et sa ligne **remonte l'ecran avec lui** (943 -> 855) alors que la
  vraie est a 1060.
* **Un vrai hop traverse une ligne qui ne bouge pas** : 11 634 px teintes
  au sol contre **592 a l'apex** (y 0,599), soit 95 % d'effondrement.
* **Le residu de 18 px n'est pas une derive** : la camera est inclinee de
  -34 deg, donc le plan y=0,55 s'etale sur **147 px** avec la profondeur
  (rows 992 a 1139 sur les +-1,02 de Keepy) ; la ligne mesuree, 1042, est
  dedans.
* **Le shader REMPLACE l'ecriture d'albedo, il ne remplace PAS
  `HubWater`** : au spawn `contains()` est faux, les pieds sont a y=0 et
  une ligne a 0,55 les couvrirait -- un test de hauteur sans gate de
  membership mouille Keepy sur l'herbe.
* **L'uniform se tween exactement comme la propriete** (`shader_parameter/
  tint_fraction` : 0,4986 a mi-course, 0,7500 en fin), donc
  `KEEPY_WATER_TINT_FRACTION` et `KEEPY_TINT_FADE_S` sont conserves.
* **Cout : nul et mesure** -- **98 / 104 draw nodes AVANT ET APRES** sur
  trois runs de chaque cote, 9 batches MultiMesh, FPS 25,1-25,3 contre
  25,4-27,1 (les plages se chevauchent : « rien de detectable », pas « plus
  rapide »).

### La planche, et ce qu'elle montre

`docs/color-sheets/waterline_ladder_sheet.png` -- dix tuiles, **toutes dans
la MEME pose** (la premiere version avait la tuile « livree » dans une
autre orientation parce qu'un hop l'avait tourne ; re-shootee plutot
qu'expliquee). ⚠️ **Les trois barreaux bas sont quasi inoperants** (fraction
mouillee 0,021 / 0,059 / 0,110) : Keepy est modelise ASSIS, ses pattes sont
petites et auto-occultees, donc **la plage utile commence a 0,62**. La bande
« corps mouille, tete seche » est **0,78 a 0,92**, marquee sur la planche.
**Le barreau n'est PAS choisi ici.**

⚠️ **Propriete que personne n'avait demandee et que la planche rend
evidente** : la couleur de teinte EST la couleur de l'eau, donc la partie
immergee ne se lit pas « Keepy mouille » mais **DISPARAIT** dans l'eau. A
0,62-0,78 c'est exactement l'effet voulu ; a 0,92 le corps sous la machoire
a largement fusionne avec le fond et on est plus proche d'une tete
flottante. Teinter vers une couleur PROCHE de l'eau plutot qu'EGALE a elle
adoucirait ca -- non tranche, non demande.

### Reste ouvert -- jugement device, et une limite de validation a dire franchement

⚠️ **Tout ce qui precede est rendu par llvmpipe sous xvfb via le backend
`opengl3` de bureau ; le jeu tourne en WebGL2 dans Safari iOS.** Deux
compilateurs GLSL differents derriere la meme source `gl_compatibility`.
Les deux points sur lesquels ce design s'appuie sont justement les plus
exposes : la **precision d'interpolation d'un `varying`** (WebGL2 mobile
donne couramment `mediump` la ou le bureau donne `highp`) et la
**disponibilite de `MODEL_MATRIX` en `vertex()`**. Un Y monde autour de
0,55 en `mediump` devrait passer ; **rien ici ne le prouve**.

Restent aussi : le choix du barreau ; le fait qu'avec une ligne fixe **tout
hop en pataugeant est un cycle mouille -> sec -> mouille en 0,28 s**
(physiquement juste, potentiellement lu comme un clignotement) ; la
reecriture des 5 checks de `WaterTintProbe` (plus le 6e, a qui il faut
donner quelque chose de POSITIF a asserter) ; et le fait que **les cinq
surfaces d'eau ne sont pas a la meme hauteur** (0,0270 a 0,0950, soit
**5,04 %** de la taille de Keepy) alors qu'une seule constante est prevue.
Une seule masse d'eau a ete echelonnee (le lobe spawn du grand lac).


