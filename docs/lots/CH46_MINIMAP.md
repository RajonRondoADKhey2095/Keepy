# CH46 — La minimap permanente (7 septembre 2026)

> Base : `origin/staging` au commit `404c283` (merge CH44), arbre
> `1236ecd42e931641ebc1a4f35d094f0653329aad`. Branche
> `claude/ch46-minimap-permanente-br1e1b`.
>
> **Vérification de concurrence faite AU DÉBUT** (`git fetch --all --prune`,
> comparaison par **hash d'arbre** et non par nom) : aucune autre ref
> `ch46`/`minimap` ; `origin/main` n'est en avance que d'un commit CI.
>
> **ÉTAPE 0 — la recon CH44 a été mergée dans `staging` avant tout code.**
> Le diff a été vérifié avant le merge : `docs/lots/CH44_RECON.md` ajouté et
> **une** ligne d'`INDEX.md`, rien d'autre. Après merge, les deux blobs sont
> **byte-identiques** à ceux de la branche de recon
> (`52e43af0…` et `a7053934…`, comparés par `git rev-parse`). Merge `--no-ff`,
> poussé sur `staging` sans demander l'autorisation (palier 1).

---

## Ce que le lot livre

Un `Control` permanent dans le **coin bas-gauche**, visible **à pied et dans
les quatre véhicules**, qui dessine un plan **nord fixe** du monde
**marchable** avec les zones peintes, le circuit de karting et 37 marqueurs
répartis en quatre types. Deux fichiers neufs de production
(`MinimapMarkers.gd`, `HubMinimap.gd`), un accesseur ajouté à `HubRegion`,
une ligne d'inscription à un groupe sur 21 sites de construction, un nœud
dans `HubWorld.tscn`, et une sonde permanente de 69 assertions.

Les cinq décisions de Mathieu sont appliquées telles quelles et ne sont
rouvertes nulle part : minimap permanente en coin, nord fixe, cadre =
monde **marchable seul**, frontières = celles **peintes**, `SubViewport`
éliminé.

---

## AXE A — Le cadre : `HubRegion.walkable_bounds()`

CH44 axe 2 avait établi qu'**aucune constante d'étendue globale n'existe** et
que l'étendue avait dû être **balayée** à 0,5 u pour être connue. Un widget
ne peut pas balayer 270 000 points à son `_ready()`. L'accesseur ajouté rend
la même réponse **en forme fermée**, à partir des **treize mêmes termes
d'union** que `contains()`, dans le même ordre :

```
walkable_bounds() = x [-63,0 ; 74,0]   z [-200,0 ; 47,0]   =  137 x 247 u
```

⚠️ **C'est une SECONDE ORTHOGRAPHE de `contains()`**, avec exactement le
risque que ce dépôt documente : un terme ajouté là et oublié ici donne une
boîte qui **rogne sa propre région**, en silence. La sonde le gate en
balayant `contains()` à 0,5 u et en exigeant que la boîte soit **SERRÉE des
quatre côtés** — serrée, pas seulement contenante, parce qu'une boîte
seulement contenante passe **gratuitement** quand un terme saute. Mesuré :

```
balayé     x[-63,0 ; 74,0]  z[-200,0 ; 47,0]
publié     x[-63,0 ; 74,0]  z[-200,0 ; 47,0]
```

**Passe rouge R1** (le rectangle montagne retiré de `walkable_bounds()`, et
de lui seul) : la boîte devient x[-50 ; 74] soit **124 x 247**, le balayage
descend toujours à **-54,0**, et **3 rouges attendus, 3 obtenus** — « tout
point admis est dans la boîte », « la boîte est SERRÉE », « le cadre est le
137 x 247 marchable ». Fichier restauré **byte-identique** (`cmp`).

Le cadre **tout-véhicule** (219 x 247, CH44) n'est pas retenu : décision 3.
Ce que ça coûte est traité à l'AXE D (clamping).

---

## AXE B — Les groupes, et l'inventaire VÉRIFIÉ

CH44 axe 3 : **zéro groupe Godot** dans le hub, et **la moitié des entités
n'a pas de nom stable** (l'ours est `@Node3D@228`, deux portails sur trois
sont `@Area3D@10/@11`). Une carte qui cite des chemins casse au premier prop
inséré avant eux, **sans erreur**.

`MinimapMarkers.gd` publie quatre noms de groupe — `minimap_player`,
`minimap_vehicle`, `minimap_npc`, `minimap_place` — plus `minimap_route`
pour ce qui se dessine en **ligne** et non en marqueur. **Le type EST le
groupe** : il n'existe aucune table de correspondance par nom, donc aucun
renommage ne peut transformer un sanglier en lieu.

### Ce qui est inscrit — 37 marqueurs, comptés sur l'arbre construit

| groupe | n | membres (nom réel, ou classe quand le nœud n'en a pas) |
|---|---|---|
| `minimap_player` | **1** | `Keepy` |
| `minimap_vehicle` | **12** | bateau du ruisseau (`Node3D`, sans nom), `Balloon_0..2`, `HopBall`, `Yacht`, `SailBoat`, `Sled`, `Kart_0..3` |
| `minimap_npc` | **9** | `Bird0..2`, `Boar`, `Cat`, `Fawn`, `Beaver`, **`Node3D` (ours)**, **`Node3D` (blaireau)** |
| `minimap_place` | **15** | `HubPortal`, **`Area3D` ×2 (portails)**, `Cabin`, `Dock_0_0..2_1` (6), `Lighthouse`, `Burrow`, `MotherTree`, `Windmill`, `Campfire` |

⚠️ **Cinq de ces trente-sept n'ont AUCUN nom** et sont exactement ceux que
CH44 avait signalés. La sonde le gate directement : elle exige que **les deux
`HubActorWalker` anonymes soient sur la carte**, et elle imprime la classe
quand le nom commence par `@`. Ours et blaireau ont reçu **une ligne
d'`add_to_group` dans `HubActorWalker._ready()`, rien d'autre** — pas
d'accesseur public, pas de renommage (hors scope, brief).

### Ce que j'ai AJOUTÉ à la liste CH44, et ce que je n'ai pas tranché

CH44 déclarait son inventaire **non garanti** (dump au spawn, météo sun,
sans interaction). Je l'ai revérifié sur le même arbre construit. Résultat :

* **La liste CH44 est exacte sur ce qu'elle nomme.** Aucune entité annoncée
  n'a manqué à l'appel.
* **Ajouté par rapport à ce que la liste appelait « mobile »** : les
  **six pontons de montgolfière** ont été classés en **lieu** et non ignorés
  — ce sont les seules raisons de marcher jusqu'aux coins du plateau.
* **Délibérément NON inscrits, et pourquoi** :
  * **la pie** (`Props/.../Magpie`) — elle vit **aux coordonnées de la
    cabane** ; un second marqueur au même pixel ne dit rien et masque le
    premier ;
  * **les trois pilotes IA** (`HubCritter` sous `Kart_1..3/Chassis/Rider`) —
    ils **sont** les karts, déjà marqueurs ;
  * **les 5 perchoirs et 54 arbres grimpables**, les 3 châteaux de sable,
    les 3 bouées, les 3 plongeoirs, le tourniquet, la balançoire, les deux
    tours de tyrolienne, la pancarte de jonction : **59+ marqueurs de plus
    sur un plan de 155 x 280 px** serait un plan illisible. Ce n'est pas une
    limite technique — l'AXE C montre que le coût ne dépend pas du nombre —
    c'est un arbitrage de lisibilité, et **il se défait d'une ligne** à
    chaque site.
* **Ce que je n'ai PAS pu trancher, et je le dis** : l'exhaustivité reste
  **non garantie pour les mêmes raisons que CH44**. Ce dump est pris **au
  spawn, météo sun, sans une seule interaction** : un nid tombé, un
  `DigMarker`, un `PileMarker`, une noix au sol n'existent pas encore ; le
  chat se déplace et **se cache**. La différence avec CH44 est qu'ici
  l'absence n'est plus une dette de conception : **tout nœud qui apparaît
  plus tard entre sur la carte par un `add_to_group()` à son site de
  naissance**, sans que ce fichier soit rouvert.

**Passe rouge R5** (l'inscription de `KartTrack` au groupe `minimap_route`
neutralisée) : **3 rouges attendus, 3 obtenus** — « exactement une route »,
« la route publie `ideal_line()` », « une route est dans le groupe ».
Restauré byte-identique.

---

## AXE C — Le coût : l'atlas contre `draw_circle`

Banc CH38/CH40, **même protocole que CH44 axe 5** : `xvfb-run --rendering-driver
opengl3`, `--resolution 1080x1920`, SubViewport forcé à 1080 x 1920 avec
`stretch = false` sur son conteneur et le rect **asserté** (il lit
`(1080, 1920)`), météo **sun**, Keepy au spawn. Les deux approches sont
mesurées **dans le même run**, sur la **même scène**, en ne changeant que le
type de commande de dessin : le fond est le **même quad de la même texture**
dans les deux cas, seuls les marqueurs diffèrent.

### Plancher de bruit, mesuré AVANT toute comparaison

Deux lectures de la même référence, minimap cachée :

```
reference (no minimap) #1    total_prims 71 609   total_calls 311
reference (no minimap) #2    total_prims 71 609   total_calls 311
PLANCHER DE BRUIT            0 prim / 0 calls
```

⚠️ **La référence n'est pas celle de CH44** (71 567 / 311) : cet arbre porte
CH45, qui a ajouté **une ligne `TOTAL tri … calls …` à `HubPerfOverlay`** —
soit des glyphes de plus dans le viewport racine. Les **42 primitives**
d'écart sont cette ligne, pas une dérive du hub. Le nombre de draw calls,
lui, est identique des deux côtés.

### Le résultat

| approche | Δ `engine_total_prims` | Δ `engine_total_calls` |
|---|---|---|
| **ATLAS** — 1 quad de fond + 37 marqueurs, `draw_texture_rect_region`, **une seule texture** | **+76** | **+1** |
| **CERCLES** — le même quad de fond + 37 `draw_circle` | **+2 370** | **+38** |

**+1 draw call pour toute la carte, fond compris.** 38 quads = 76 triangles,
et le renderer canvas les **coalesce en une seule commande** parce qu'ils
partagent texture, matériau et type de primitive. L'objectif du brief
(« quelques calls au total, fond compris, au lieu de 43 ») est donc atteint
**et dépassé** : il y en a **un**.

Et l'alternative se comporte exactement comme CH44 l'avait prédit :
**37 marqueurs → 38 draw calls**, c'est-à-dire **un draw call par marqueur**,
`draw_circle` émettant une commande POLYGONE qui ne se batche pas. Les
2 370 primitives sont les triangles d'éventail des 37 disques.

⚠️ **Ce que ce banc NE dit PAS**, et c'est repris de CH44 sans être adouci :
rien du device (llvmpipe contre WebGL2 sous Safari sont deux renderers),
**rien du temps CPU** du corps de `_draw` (les compteurs comptent des
primitives et des appels, pas des millisecondes), rien de la mémoire. Ce
qui devrait traverser, c'est le **rapport** entre les deux approches, pas
les valeurs absolues.

⚠️ **Et le coût est LISIBLE SUR DEVICE**, ce qui n'était pas vrai quand CH44
a écrit son axe 5 : `HubPerfOverlay` n'imprimait pas `engine_total_*`. CH45
a ajouté la ligne. Une minimap 2D n'entre **jamais** dans `TRI gpu` (qui lit
le RID du SubViewport 3D) ; c'est la ligne **`TOTAL`** qui la porte, et
Mathieu peut la lire.

### Le seul coût qui n'est pas dans ce tableau

Le plan est **cuit une fois**, au premier `_process`, en appelant
`HubRegion.contains()` **43 400 fois** (155 x 280 pixels). C'est une
saccade d'une frame au chargement du hub, pas un coût par frame, et ce banc
ne la mesure pas. Elle est bornée : la cuisson n'est **refaite qu'une seule
fois**, si le circuit apparaît après coup, et un compteur (`_route_retried`)
ferme le cas où un membre de groupe ne publierait rien de dessinable — sans
lui, un hub sans circuit (toute sonde qui construit un monde nu) paierait
ces 43 400 appels **à chaque frame, indéfiniment**.

---

## AXE D — Le plan lui-même

### Les bandes sont celles PEINTES, dans l'ordre du shader

`painted_tone()` rejoue `cozy_ground.gdshader` **sans son bruit** : herbe,
puis automne, puis lande, puis pelouse du circuit, puis le sable et la mer
de la Crique — **dans cet ordre**, qui est le fait ici (l'inverser mettrait
la bruyère par-dessus le circuit). Les seuils sont
`CozyPalette.AUTUMN_EDGE_Z / MOOR_EDGE_Z / CIRCUIT_EDGE_Z` et `COVE_RECT`,
**jamais** `HubRegion.*_MAX.y` : décision 4.

Chaque frontière est **lue au pixel** par la sonde, dans une colonne rendue,
puis reconvertie en z monde. Les trois colonnes ne sont pas choisies au
hasard : **une frontière peinte n'est visible que là où un couloir la
traverse**, parce que c'est la seule bande de région entre deux zones.

| frontière | colonne (couloir) | z trouvé au rendu | peint | logique | écart |
|---|---|---|---|---|---|
| automne | x = -28 | **-38,13** | -39,0 | -42,0 | 0,87 contre 3,87 |
| lande | x = 12 | **-81,35** | -82,0 | -86,0 | 0,65 contre 4,65 |
| circuit | x = -8 | **-131,63** | -132,0 | -134,0 | 0,37 contre 2,37 |

Résolution du plan : **0,882 u par pixel**.

### ⚠️ LE DIX-SEPTIÈME FAUX-VERT DE CE DÉPÔT, ET IL ÉTAIT DANS MA PROPRE SONDE

La passe rouge **R3** a réécrit `painted_tone()` pour mélanger ses bandes sur
les bords **logiques** de `HubRegion` — la substitution exacte que la
décision 4 interdit — et la PHASE 6 est ressortie **ALL GREEN, 0 rouge**.

La cause : le tableau ci-dessus lit le **TRAIT** sombre que la cuisson trace
au z peint (`_bake_zone_edges`), pas le **REMPLISSAGE** qu'il sépare. Le
trait, lui, n'avait pas bougé. Une frontière est **deux choses** — une ligne,
et le changement de couleur qu'elle sépare — et c'est la seconde que le
joueur lit d'un coup d'œil. Elle n'était **pas gatée du tout**.

Refermé par six assertions de plus, qui lisent la **rangée suivante** et la
**rangée précédente** du trait et exigent qu'elles tombent du bon côté (par
comparaison de DISTANCES entre les deux tons de bande candidats, ce qui
absorbe des deux côtés à la fois les 0,08 que la scène 3D peut apporter à
travers l'alpha 0,92 du plan). La rangée « avant » est le **blind** de la
rangée « après » : sans elle, « c'est la nouvelle bande » serait la réponse
partout.

Rejoué après correctif :

* **R3b** (bandes sur les bords logiques) : **3 rouges attendus, 3 obtenus** —
  les trois « une rangée APRÈS la haie peinte le plan remplit déjà avec la
  nouvelle bande ». Les assertions de trait restent vertes, ce qui est
  correct : le trait n'a pas été touché.
* **R7** (le TRAIT tracé aux bords logiques) : **6 rouges attendus, 6
  obtenus** — les trois « la frontière dessinée est le z PEINT » et les
  trois « et ce n'est PAS le logique ». Le remplissage reste vert, ce qui
  est également correct.

Les deux passes sont **complémentaires et ne se recouvrent pas** : c'est ce
qui prouve que les deux moitiés de la frontière sont désormais gatées
séparément. Fichiers restaurés byte-identiques (`cmp`) dans les deux cas.

### Le clamping GTA

Une entité hors cadre est **rabattue au bord** et **change de FORME** :
disque à l'intérieur, **carré** à l'extérieur. La couleur, elle, ne change
pas — un marqueur clampé continue de dire de quel type il est.

Mesuré, voilier poussé à `x = 150` (82 u au-delà du cadre, exactement le cas
que CH44 signalait) :

```
amarré à (65, 0, -110)     clamped = FAUX     <- le drapeau SAIT dire non
poussé à (150, 0, -110)    clamped = VRAI     x = 148,0 px sur 155
                           rendu dans le ton VEHICLE
                           remplissage des 4 coins diagonaux : 0,775
de retour dans le cadre    remplissage des mêmes 4 coins      : 0,284
                           séparation                          : 0,491
```

⚠️ **Le test de forme a d'abord été FAUX, et il a fallu la mesure pour le
voir.** La première version demandait « ce pixel est-il EXACTEMENT le ton »
aux quatre offsets (±3, ±3) et lisait **1 coin sur 4** sur un carré
parfaitement dessiné : à cet offset, l'antialiasing du carré met le texel le
plus proche à 3,5 en distance L∞, dans son remplissage de 3,7 mais couvert à
**70 %** seulement. Ce qui sépare les deux icônes n'est pas le ton, c'est la
**quantité de ton présente** — un disque de rayon 3,9 n'a **rien** à cet
offset (sa distance y vaut 4,95). Le test est passé à la **couverture**, et
il porte son propre blind (le marqueur en cadre doit lire **vide**).

**Passe rouge R4** (le drapeau `outside` forcé à faux) : **3 rouges
attendus, 3 obtenus**, dont la séparation qui tombe à **-0,008** — les deux
icônes deviennent la même. Restauré byte-identique.

### Les icônes : blanc sur noir, et c'est porteur

Les quatre icônes de l'atlas sont des **formes blanches à contour noir**,
teintées par l'argument `modulate` de `draw_texture_rect_region` — qui
**multiplie**. Un remplissage blanc devient la couleur du type ; un contour
noir **reste noir sous n'importe quelle couleur**. Chaque marqueur garde
donc une arête sombre franche contre l'herbe, le sable, la bruyère, la
pelouse ou la mer, **sans une seule décision de contraste par type**.

C'est l'avertissement permanent de `CLAUDE.md` — « le WCAG ne score AUCUNE
séparation À L'INTÉRIEUR d'une bande, et aucune sonde du dépôt ne mesure la
teinte » — traité **par construction** plutôt que par une table de tons.

⚠️ **Mais le ton du JOUEUR a quand même dû être mesuré et changé.** Un
marqueur joueur crème `(1,00 ; 0,99 ; 0,90)` rend à **0,03** de la ligne du
circuit `(0,97 ; 0,96 ; 0,87)` une fois l'alpha du plan appliqué : le joueur
posé sur le circuit aurait été un point pâle sur un trait pâle. **C'est le
balayage aveugle de la sonde qui l'a trouvé**, en lisant deux pixels de plan
comme « un joueur » pendant la passe rouge R1. Remplacé par un jaune chaud
`(1,00 ; 0,86 ; 0,16)`, à **0,71** en bleu de cette ligne et clair de chaque
ton de bande.

---

## AXE E — L'intégration

CH44 axe 4 avait établi qu'**aucun `CanvasLayer` n'existe**, que tout est
frère sous la racine `Control`, et qu'**un seul point d'insertion** couvre le
pied et le véhicule. Le nœud `Minimap` est donc un frère, inséré **après
`WeatherOverlay`** (pour ne pas être teinté par la couche météo) et
**avant `KartHud`**.

⚠️ **Avant `KartHud`, et c'est un choix, pas un hasard** : le fantôme du
doigt de `KartTouchInput` se dessine **là où le pouce s'est posé**,
n'importe où, minimap comprise. Placer la carte au-dessus l'aurait cachée
sous le plan à l'instant précis où le joueur en a besoin.

### Le rect, et l'encoche

```
rect  position (24, 1490)   taille (155, 280)     canvas 1080 x 1920
```

* **Ancres et offsets écrits à la main, jamais `set_anchors_preset()` +
  `position`.** Le piège est documenté et ce dépôt l'a déjà payé (V7,
  panneau chrono coupé sur device) : après un preset, `position` est un
  **offset depuis l'ancre**, donc une valeur y positive sur une ancre basse
  sort de l'écran. Quatre offsets contre deux ancres ne disent qu'une chose.
* Gaté **contre la bande de 1080 px** et non contre le canvas headless
  (24 → 179), comme `CLAUDE.md` l'exige.
* **L'encoche est à l'autre bout de l'écran.** `SafeArea` n'expose aucun
  inset et le hub tourne en `EXPAND` : la bande d'encoche (141 px device)
  est **dans** le canvas et rien ne dit où. La seule défense disponible est
  la distance à ce bord, et c'est le bas de l'écran qui est choisi — libre
  dans les deux modes selon CH44, et à 1490 px du haut ici. La marge basse
  de 150 px de canvas dégage l'indicateur d'accueil (~94 px de canvas à
  l'échelle `EXPAND` d'un iPhone).
* Le **ratio** du widget est asserté égal à celui du cadre monde : le plan
  n'est jamais étiré.

### Le tap n'est jamais avalé — PROUVÉ par événements réels

`mouse_filter = MOUSE_FILTER_IGNORE` est posé **deux fois** : dans
`HubWorld.tscn` (pour qu'un lecteur de la scène le voie) et dans `_ready()`
(pour qu'une minimap construite par code n'hérite jamais du défaut `STOP`).

La preuve n'est pas une relecture. La sonde ajoute un **nœud sentinelle** en
dernier enfant du hub — donc il voit exactement ce que voient les deux vrais
consommateurs, `HubTapInput._unhandled_input` et
`KartTouchInput._unhandled_input` : ce qui survit au picking GUI. Puis elle
pousse de vrais `InputEventScreenTouch` au centre du widget, **arme les 14
canaux de tap** de `HubTapInput`, et lit :

```
IGNORE (livré)   2 événements, canal tapped_ground
STOP   (blind)   0 événement,  0 canal
IGNORE (rendu)   2 événements, 1 canal
```

⚠️ **La paire IGNORE/STOP est obligatoire** : sans elle, « le tap est
arrivé » serait aussi vrai d'un build où la minimap n'a jamais été **devant**
le tap. La troisième lecture existe pour que la phase ne laisse pas le
widget dans l'état dont son propre blind avait besoin.

⚠️ **ET LE PREMIER JET DE CETTE PHASE MESURAIT LA MAUVAISE CHOSE.** Il
comptait `tapped_ground` seul, et lisait **2 événements passés / 0
destination** sur **neuf points différents** — de quoi conclure à une
interception qui n'existait pas. Deux causes distinctes, toutes deux
instructives :

1. **`HubTapInput` obéit à une règle un-tap-un-signal** : un prop sous le
   rayon prend l'événement **à la place** de `tapped_ground`. Le canal qu'un
   tap devient est l'affaire du monde, pas celle de la carte ; ce que la
   minimap ne doit pas faire, c'est empêcher le tap d'être un tap. La phase
   arme donc **tous** les canaux.
2. ⚠️ **LE PIÈGE DU LAMBDA GDSCRIPT, RE-RENCONTRÉ** — `CLAUDE.md` le
   documente et je suis tombé dedans quand même. Le compteur était
   `var counter := func(_at): ground += 1` : **un lambda capture une
   variable LOCALE PAR VALEUR**, il incrémentait sa propre copie, et la
   boucle n'a jamais rien vu bouger. Fermé en portant le compteur sur un
   **membre de classe** (`_fired`), qui est exactement la parade que
   `CLAUDE.md` prescrit.

**Passe rouge R2** (le widget passé à `MOUSE_FILTER_STOP`, dans le script
**et** dans la scène) : **3 rouges attendus, 3 obtenus** — le filtre lu à 0,
le tap qui n'atteint plus `_unhandled_input`, et le tap qui ne devient plus
rien. Fichiers restaurés byte-identiques.

---

## La sonde, les passes rouges, et la régression

`MinimapProbe` — **9 phases, 69 assertions, ALL GREEN, 0 rouge**, sous
`xvfb-run --rendering-driver opengl3 --resolution 1080x1920 --fixed-fps 60`.

⚠️ **Elle rend et relit des PIXELS partout où ce qu'elle garde est visuel**,
parce que la doctrine CH39/CH40 dit qu'un compteur compte le **SOUMIS** et
non le **DESSINÉ** : une minimap qui existe dans l'arbre, porte les bons
groupes, a le bon rect et **ne dessine rien du tout** passerait toute
assertion structurelle qu'on penserait à écrire. La PHASE 0 asserte d'abord
que la surface est réelle (viewport non dégénéré, une frame relue, et un
pixel central **ombré** et non le noir du driver dummy) — sans quoi tout ce
qui suit passerait **en ne s'exécutant jamais**.

| passe | neutralisation | rouges attendus | obtenus |
|---|---|---|---|
| **G** | aucune (livré) | 0 | **0** (69 checks) |
| **R1** | un terme d'union retiré de `walkable_bounds()` | 3 | **3** |
| **R2** | `mouse_filter` → `STOP` (script **et** scène) | 3 | **3** |
| **R3** | bandes peintes sur les bords **logiques** | 6 | **0** ⚠️ **le faux-vert ci-dessus** |
| **R3b** | la même, après le correctif de la sonde | 3 | **3** |
| **R4** | le drapeau `clamped` forcé à faux | 3 | **3** |
| **R5** | `KartTrack` retiré du groupe `minimap_route` | 3 | **3** |
| **R6** | plus aucun marqueur dessiné | 7 | **8** |
| **R7** | le TRAIT de frontière tracé aux bords logiques | 6 | **6** |

Tous les fichiers touchés par une passe rouge ont été restaurés et vérifiés
**byte-identiques** par `cmp`.

**R6 : 8 obtenus pour 7 prédits, et le huitième est légitime.** Le rouge en
trop est « de retour dans le cadre les mêmes quatre offsets sont VIDES
(0,475) » : sans aucun marqueur, le pixel lu est du fond de plan, dont le
canal atteint 0,475 — au-dessus du seuil de 0,30. Autrement dit, cette
assertion **n'est pas vide non plus**, ce qui est une bonne nouvelle et pas
un défaut de prédiction à maquiller.

### Régression : rejouée sur les DEUX ARBRES

`CLAUDE.md` : un lot qui touche un mode partagé (la minimap est **devant
chaque tap** des deux modes) rejoue la table existante sur la branche **et**
sur une référence importée à part. Worktree de `origin/staging` créé, arbre
vérifié par **hash** (`1236ecd4…` des deux côtés), import complet
(**154 `.scn`**, comme la branche).

| sonde | branche CH46 | référence `origin/staging` | verdict |
|---|---|---|---|
| `KartProbe` (headless) | 150 checks, **1 échec** | 150 checks, **1 échec** | **IDENTIQUE** |
| `ReverseProbe` (headless) | ALL GREEN 0 red | ALL GREEN 0 red | IDENTIQUE |
| `SailBoatProbe` (headless) | 42 checks, 0 échec | 42 checks, 0 échec | IDENTIQUE |
| `CoveProbe` (headless) | 178 checks, 0 échec | 178 checks, 0 échec | IDENTIQUE |
| `SledProbe` (xvfb + opengl3) | ALL GREEN 0 red | ALL GREEN 0 red | IDENTIQUE |

⚠️ **`KartProbe` échoue des DEUX côtés, sur la même assertion et la même
valeur** : `[FAIL] chrono panel centred (|centre - width/2| < 2 px) -- 977.0`.
Ce n'est **pas** une régression CH46 — c'est ce que la comparaison sur deux
arbres est faite pour trancher, et c'est exactement le cas que `CLAUDE.md`
décrit (« la couleur d'une sonde isolée ne dit rien ; c'est la COMPARAISON
qui tranche »). L'assertion mesure le panneau chrono contre la **moitié du
canvas de la fenêtre**, et la fenêtre headless de ce sandbox ne fait pas la
largeur que l'assertion suppose. **Signalé, non corrigé** : hors scope.

`ProbeTimeoutAudit` : **PASSED**, chaque sonde du dossier est bornée.
Le banc de coût était **jetable** et a été **supprimé avant le commit**,
comme la doctrine l'exige ; ses chiffres vivent dans l'AXE C.

---

## Ce que ce lot N'A PAS établi

1. **Aucun chiffre device.** Le banc est llvmpipe sous xvfb ; les rapports
   entre les deux approches devraient traverser, les valeurs absolues non.
   La ligne `TOTAL` de l'overlay est désormais la lecture à faire sur
   l'iPhone.
2. **Le coût CPU du `_draw`** n'est pas mesuré (37 positions recalculées par
   frame en GDScript), ni la saccade de cuisson au chargement.
3. **La lisibilité sous les quatre météos n'est pas évaluée.** Le plan est
   cuit **une fois**, sur la palette de base : il **ne reflète pas la neige**
   que le shader de sol pose par-dessus. La carte reste juste ; elle cesse
   simplement de ressembler au sol sous la neige.
4. **L'exhaustivité de l'inventaire** reste non garantie, pour les raisons
   dites à l'AXE B — mais elle n'est plus une dette de structure.
5. **Aucune vérification device.** Palier 1 uniquement : `staging`.
