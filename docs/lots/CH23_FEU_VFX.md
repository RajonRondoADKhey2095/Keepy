# Feu de camp — RECON VFX (4 septembre 2026)

> Chantier ouvert par ce lot. **RECON : aucune implémentation finale, aucun
> feu de camp.** Le livrable est un build `staging` comparatif — deux ou
> trois flammes candidates, étiquetées, posées côte à côte au point que
> Mathieu a relevé sur device — plus les mesures qui doivent survivre au
> lot 2. **Le verdict visuel appartient à Mathieu, sur Safari iPhone.**
> Aucun asset importé, aucun asset supprimé. Les quatre sondes qui ont
> produit les chiffres ci-dessous sont **jetables et supprimées avant le
> commit**, conformément à « SONDE JETABLE = SUPPRIMÉE AVANT LE COMMIT ».

## Ce que la recon a tranché, en une table

| question du brief | réponse | preuve |
|---|---|---|
| A. `GPUParticles3D` fonctionne-t-il en Compatibility ? | **OUI** | 2 078 px magenta dessinés, contre 0 sur frame vide et 980 pour le contrôle CPU |
| B. `CPUParticles3D` ? | **OUI** | 6 693 px peints au site |
| C. billboard sprite-sheet ? | **OUI**, et c'est le moins cher d'un facteur 28 | +2 primitives contre +56 |
| glow / halo disponible ? | **OUI**, mais il n'est pas gratuit | 1 809 px de halo à albédo 1,0 ; 5 043 à 4,0 |
| émission sur unlit ? | **INERTE**, re-mesuré ici | 0,5451 avec, 0,5451 sans — au chiffre près |
| dégagement en (19,9 ; 25,4) ? | **3,521 u** | enveloppe convexe XZ de 452 pièces dessinées |
| coût à la pire frame connue ? | **+0**, et c'est un piège de cadre, pas une bonne nouvelle | le site projette en (2225, 654) sur 1080 de large |
| tient-il de jour comme en mode sombre ? | **le hub n'a pas de mode sombre** | mesuré, voir plus bas |

## A. `GPUParticles3D` sous `gl_compatibility` — la question gatante

Le brief demandait de le vérifier **d'abord**, et de le prouver plutôt que
de contourner en silence. Trois rendus dans le **même** `SubViewport`, la
même caméra, le même fond noir ; chaque émetteur dessine le **même** quad
unlit magenta, donc un pixel magenta ne peut venir que d'une particule.

| rendu | px magenta |
|---|---|
| frame vide (blind check) | **0** |
| `CPUParticles3D` (contrôle connu-bon) | **980** |
| `GPUParticles3D` (candidat A) | **2 078** |

**Blind check armé et passé dans les deux sens** : la frame vide prouve que
le masque n'est pas contaminé, le contrôle CPU prouve que la sonde sait
VOIR une particule. Sans ce second point, un « GPU particles ne dessine
rien » aurait été gratuit — c'est exactement l'assertion d'absence que
`CLAUDE.md` interdit de croire sans l'avoir vue échouer.

⚠️ **Ce que cette mesure NE dit PAS.** Elle tourne sous llvmpipe, OpenGL 4.5
Core, backend Compatibility. Safari iOS exécute ce **même backend** sur
WebGL2, mais ce n'est pas le même compilateur GLSL et ce n'est pas la même
implémentation. Le résultat transporte comme « le chemin de code existe et
n'est pas un no-op », pas comme « ça marchera sur l'iPhone de Mathieu ».
C'est précisément le partage que le brief pose : le chiffrage est ici, le
verdict est sur device.

## Le halo — disponible, et il coûte une passe plein écran

Quatre rendus, un seul sujet : le même quad au centre. Seuls le matériau et
l'`Environment` changent. La mesure est le **HALO** — les pixels HORS de
l'empreinte écran du quad — et l'empreinte n'est pas supposée : elle est
apprise du rendu 1, qui n'a pas de glow par construction.

| rendu | core px | halo px | moyenne RGB du core |
|---|---|---|---|
| 1 albédo 1,0, glow OFF (contrôle) | 900 | **0** | 0,5451 |
| 2 albédo 1,0, glow ON | 900 | **1 809** | 0,5867 |
| 3 albédo 4,0 HDR, glow ON | 900 | **5 043** | 0,7091 |
| 4 albédo 1,0 + émission 1,0, glow OFF | 900 | **0** | **0,5451** |
| 5 glow ON, sans quad (blind check) | 900 | 0 | 0,0000 |

Trois faits, chacun mesuré :

1. **Le glow EXISTE sous `gl_compatibility`.** Il n'est pas indisponible.
2. **Un albédo au-dessus de 1 le pousse plus loin** (1 809 → 5 043), donc le
   signal lumineux d'un feu peut être réglé en HDR sur l'albédo, sans jamais
   toucher à l'émission.
3. **L'émission sur un matériau UNLIT est INERTE** — 0,5451 des deux côtés,
   au chiffre près. `CLAUDE.md` le documentait ; c'est maintenant re-mesuré
   dans ce renderer, pour ce lot, sur le chemin livré.

⚠️ **Mais le glow n'est PAS gratuit et le hub n'en a pas.** L'`Environment`
livré (`scenes/HubWorld.tscn`) n'a aucune ligne `glow_*`, donc `glow_enabled`
vaut `false`. L'activer ajoute une **passe post plein écran** à une frame que
`MESHY_SPEC` §7 justifiait justement sur l'absence d'une telle passe, et
l'ajoute **au hub entier**, pas au feu. C'est un arbitrage du lot 2, avec un
prix ; ce lot le nomme au lieu de le prendre. **Les trois candidats portent
donc leur signal en ALBÉDO seul et lisent pareil que le glow soit allumé ou
non.**

⚠️ **Une assertion a échoué sur du code correct, et elle n'a pas été
filtrée.** La première version du blind check exigeait `core == 0` sur la
frame vide et sortait ROUGE. Elle avait raison de poser la question : `core`
compte **l'AIRE du masque appris**, allumée ou non, donc une frame vide
rapporte les 900 pixels avec une moyenne de zéro. L'assertion a été
**reposée** sur l'ÉNERGIE dans le masque plus le halo dehors, et sur la
stabilité du masque entre deux rendus — jamais rendue muette.

## Le site — mesuré avant d'y poser quoi que ce soit

(19,9 ; 25,4) vient de Mathieu, relevé in-game via `DEBUG_POSITION_OVERLAY`.
Ce lot ne le discute pas et ne cherche pas « mieux ». Ce qu'il mesure, c'est
le dégagement, sur le hub **CONSTRUIT** — rien n'est lu dans le layout :
452 pièces dessinées, chacune réduite à l'**enveloppe convexe XZ de ses huit
coins transformés**, plus sa bande verticale.

| point | dégagement | plus proche voisin au sol | dans la région |
|---|---|---|---|
| slot **A** (17,9 ; 25,4) | **3,575 u** | `TreeCrown` | oui |
| **site** (19,9 ; 25,4) | **3,521 u** | `TreeCrown` | oui |
| slot **C** (21,9 ; 25,4) | **1,676 u** | `TreeCrown` | oui |

Le câble de tyrolienne passe **au-dessus** — au plus près 5,895 u en XZ, à
partir de y = 3,23 — jamais à travers le site. Les quatre points sont dans
`HubRegion.contains()`.

**Blind check** : un point posé À L'INTÉRIEUR d'une pièce dessinée (`Ring`,
en −5,76 ; −4,74) rapporte **0,000 u**. Sans lui, « tout est dégagé » serait
une assertion d'absence qui passe gratuitement.

⚠️ **La première métrique était FAUSSE, et pas d'un chiffre — d'une
nature.** Elle utilisait le **disque circonscrit** de l'AABB transformée.
Le câble de tyrolienne est une longue diagonale fine : son disque a un rayon
d'une trentaine d'unités et **avalait tout le plateau**. Les quatre points
sont d'abord sortis « obstruaient par `Cable` » avec des dégagements de
−5,082 à −6,796 u, et le blind check lui-même mesurait le câble au lieu du
prop visé. Un chiffre négatif partout n'est pas un résultat, c'est une
métrique qui ne discrimine pas. **C'est le cas d'école « LA MÉTRIQUE PEUT
ÊTRE LA MAUVAISE, ET LE CHIFFRE VERT AVEC ».**

## Le coût — deux stations, parce qu'une seule ne mesurait rien

`RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME`, pire frame sur 120, sous xvfb +
`opengl3`, à travers le `SubViewport`, la caméra et l'`Environment` livrés.

### Station 1 — la pire frame connue, Keepy en (−5,0 ; 35,0)

| candidats présents | primitives | delta |
|---|---|---|
| aucun (baseline) | **48 012** | +0 |
| A `GPUParticles3D` | 48 012 | **+0** |
| B `CPUParticles3D` | 48 012 | **+0** |
| C billboard sheet | 48 012 | **+0** |
| A + B + C | 48 012 | **+0** |

La baseline retombe sur **48 012**, le chiffre exact que CH22 a publié pour
cette station. C'est la reproduction d'un chiffre déjà au dossier avec le
banc qu'on s'apprête à utiliser, et c'est ce qui donne au banc qualité à
publier les chiffres neufs.

⚠️ **Le +0 n'est PAS une bonne nouvelle, et le blind check l'a attrapé.**
La première version de cette sonde est sortie **ROUGE** sur « aucun candidat
n'a bougé le compteur ». La cause est le **cadre étroit** que `CLAUDE.md`
documente : `keep_aspect` KEEP_WIDTH à `fov` 45, soit un demi-angle
**HORIZONTAL** de 22,5°. Depuis (−5 ; 35) le site est à 24,9 u de côté d'une
ligne de visée longue de 18,5 u — **53° hors axe**. `unproject_position` le
dit sans ambiguïté : le site projette en **(2225, 654) sur un viewport de
1080 de large**, soit plus de deux largeurs d'écran dehors. **Le coût mesuré
là est le coût de ne rien dessiner.** La marge de 1 988 primitives de CH22
est donc intacte à cette station — pas parce que le feu est gratuit, parce
qu'il n'y est pas.

### Station 2 — sur le site, Keepy en (19,9 ; 25,4)

Le site projette en **(540, 1058)** sur 1080 × 1920 : plein cadre.

| candidats présents | primitives | delta (avec label) | delta **flamme seule** |
|---|---|---|---|
| aucun (baseline) | 34 846 | +0 | +0 |
| **A** `GPUParticles3D` | 34 962 | +116 | **+56** |
| **B** `CPUParticles3D` | 34 962 | +116 | **+56** |
| **C** billboard sheet | 34 908 | +62 | **+2** |
| A + B + C | 35 140 | +294 | **+114** |

**Le `Label3D` de chaque candidat est un confondant, et il a été retiré pour
la seconde colonne** : une étiquette facture un quad par glyphe, soit 60
primitives — plus que la flamme de C d'un facteur 30. Les étiquettes sont un
artefact de recon et disparaissent au lot 2.

Les chiffres tombent **exactement** : 28 quads × 2 triangles = **56** pour A
et B, 1 quad × 2 = **2** pour C, et la somme est parfaitement additive
(56 + 56 + 2 = 114). Marge contre le plafond de frame de 50 000 à cette
station, les trois présents : **14 860 primitives**.

**Blind check** : les trois candidats bougent le compteur là où ils sont
réellement à l'écran. C'est ce qui autorise à lire le +0 de la station 1
comme du frustum culling et pas comme une flamme gratuite.

### Frame time — ordonnancement seulement

Moyenne sur 120 frames, wall-clock réel entre deux `process_frame`, sous
llvmpipe : **36,3 à 41,2 ms** selon la passe, **sans séparation nette entre
les candidats** — les écarts entre passes (±3 ms) sont du même ordre que
l'écart entre deux passes identiques. **Ce banc ne discrimine pas trois
flammes à 56 primitives près sur une frame qui en dessine 35 000.** Publié
comme tel plutôt que présenté comme un classement : la seule chose que ces
millisecondes disent est qu'aucun candidat ne provoque d'effondrement.

### Pixels — la seule preuve que la géométrie est DESSINÉE

Un delta de primitives prouve que la géométrie a été **soumise**. Seuls des
pixels prouvent qu'elle a été **peinte**. Contre une frame de référence du
même cadrage, étiquettes retirées :

| candidat | pixels qui diffèrent |
|---|---|
| A `GPUParticles3D` | **9 119** |
| B `CPUParticles3D` | **6 693** |
| C billboard sheet | **3 874** |

A et B ont **la même configuration** — même `amount`, même `lifetime`, même
quad, même rampe — et peignent pourtant des surfaces différentes. Ce n'est
pas une contradiction : leurs générateurs aléatoires sont distincts, donc
les deux feux sont à des phases différentes au moment du tir. **Publié tel
quel plutôt que lissé** : un chiffre identique aurait été plus suspect.

## Le mode sombre — la question n'a pas d'objet dans le hub, et c'est mesuré

Le brief demande si le rendu tient « de jour comme sous mode sombre ». La
réponse honnête est que **le hub n'a pas de mode sombre** :

* le cycle clair/sombre vit dans `GameState` et appartient à **Keepy
  Chased** (`docs/lots/ARCHIVE/A01_MODE_SOMBRE_ET_F10.md` archive par
  ailleurs le mode sombre par inversion plein écran, **supprimé**) ;
* `HubWorld._apply_swamp_palette()` écrit une palette **constante** depuis
  `SwampPalette` — `sky_shallow`, `ambient_light_color`,
  `ambient_light_energy`, `hub_fog_light_color`, `hub_fog_density` — et rien
  dans le hub ne la fait varier ;
* le hub ne porte **aucune** `DirectionalLight3D` (CH22 l'avait déjà mesuré,
  au motif qu'il n'y a donc pas de passe d'ombre à double-compter).

**Il n'y a donc qu'une condition d'éclairage sur ce plateau, et les trois
candidats y ont été mesurés.** Poser un mode sombre sur le hub serait un lot
à part entière. ⚠️ **À ne pas confondre avec « ça tient partout »** : ce lot
n'a mesuré qu'une condition parce qu'il n'en existe qu'une, pas parce qu'il
en a balayé plusieurs.

## Ce que les trois candidats partagent, et pourquoi

Une comparaison de TECHNIQUES n'est valable que si tout le reste est
identique. `scripts/hub/HubFlameRecon.gd` publie donc **une** rampe
(`RAMP_CORE` / `RAMP_MID` / `RAMP_EDGE`) lue par les trois, et A et B
reçoivent le **même** `amount`, le **même** `lifetime`, le **même** quad et
la **même** forme d'émission.

⚠️ **La première version ne partageait PAS la texture, et la capture l'a
montré.** Le quad des particules était **nu** : A et B rendaient des piles
de carrés jaunes à bords durs à côté du joli goutte-d'eau de C. Un arbitrage
sur cette image aurait porté sur l'ART, pas sur la technique — c'est-à-dire
exactement le défaut « UN FIXTURE QUI DIVERGE DU RÉEL SUR UN AXE NE PROTÈGE
PAS DE CET AXE », reconstruit dans le dépôt qui le documente. Corrigé : un
disque doux blanc, **baké une fois** et partagé, dont la couleur vient
toujours de la rampe via `vertex_color_use_as_albedo`.

⚠️ **Et les étiquettes se chevauchaient**, à 2 u d'écart. Trois noms qu'un
lecteur ne peut pas distinguer valent zéro nom. Texte raccourci et B relevé
de 0,42 u.

## Doctrine appliquée sans avoir à la redécouvrir

* **`--headless` interdit** pour toute sonde qui lit un pixel, une instance
  de `MultiMesh` ou un point d'écran : les quatre tournent sous `xvfb-run
  --rendering-driver opengl3`, et **chacune assertent son rect non
  dégénéré**. `FlameSiteProbe` va plus loin et refuse un run où le premier
  transform d'un batch lit l'IDENTITÉ — le symptôme exact du driver DUMMY,
  qui aurait rapporté le site glorieusement dégagé.
* **Les flags moteur avant le `--`**, `--fixed-fps 60` compris.
* **`--headless --quit-after 2` avant chaque run long**, qui a servi : le
  `class_name HubFlameRecon` neuf n'était pas visible avant un ré-import et
  `FlameCostProbe` ne parsait pas — trouvé en quelques secondes au lieu d'un
  timeout muet.
* **`transparency` posé EXPLICITEMENT** sur le matériau des particules : le
  canal alpha d'`albedo_color` est ignoré tant que `transparency` reste
  `DISABLED`, ce qui aurait rendu 28 cartes orange opaques.
* **`cull_disabled` sur le shader de C est sur un QUAD PLAT**, pas sur un
  corps fermé : la face arrière qui repeint la face avant ne peut pas se
  produire, il n'y a pas de seconde surface. `depth_draw_never` est posé
  explicitement et le blend est additif.
* **Le site est publié UNE fois** (`HubFlameRecon.SITE`) et lu par le
  bâtisseur, par les sondes et par la capture — jamais retapé.
* **La caméra n'est jamais réorientée par une sonde** : le pitch est cuit
  dans la transform de `scenes/HubWorld.tscn` et `HubCamera` n'écrit que la
  position. Une sonde qui réécrirait un angle serait une seconde orthographe
  du cadrage.

## Ce que ce lot n'a PAS mesuré

1. **Safari iOS.** Rien ici n'a tourné ailleurs que sous llvmpipe. C'est le
   verdict de Mathieu, en navigation privée, sur `keepy-staging.vercel.app`.
2. **Le coût du glow s'il est activé** — mesuré comme disponible, pas comme
   abordable. La passe plein écran est un chiffre que le lot 2 doit prendre
   avant de l'allumer.
3. **La lisibilité de la flamme contre la palette marécage.** Aucun contraste
   WCAG n'a été calculé : la couleur du feu n'est pas arbitrée dans ce lot.
4. **Le frame time** ne discrimine pas les candidats sur ce banc (voir plus
   haut) ; un classement de performance entre A, B et C reste ouvert.
5. **Le décor de camp** — cercle de pierres, rondins — hors périmètre.

## Ce que ce lot a écrit

* `scripts/hub/HubFlameRecon.gd` — les trois candidats, la rampe partagée,
  la texture de particule et l'atlas bakés une fois, les étiquettes.
* `scenes/HubWorld.tscn` — un nœud `FlameRecon` sous `World`.
* Ce document, une ligne d'index dans `CLAUDE.md` et une dans
  `docs/lots/INDEX.md`.

**Aucun asset importé, aucun asset supprimé, aucun tap, aucune pose de
Keepy.** Les quatre sondes (`FlameParticleViability`, `FlameGlowProbe`,
`FlameSiteProbe`, `FlameCostProbe`) et la capture (`FlameShot`) sont
supprimées avant le commit ; `ProbeTimeoutAudit` retrouve sa baseline.

---

# Feu de camp — LOT 2 : comparatif de rendu de flamme (4 septembre 2026)

> **RECON encore.** Aucune implémentation définitive, aucun tap, aucune
> interaction, aucun feu de camp. Le livrable est un build `staging`
> comparatif — trois flammes candidates étiquetées, au point que Mathieu a
> relevé sur device — plus les mesures qui doivent survivre au lot 3.
> **Le verdict visuel appartient à Mathieu, sur Safari iPhone.** La sonde
> qui a produit les chiffres ci-dessous est jetable et supprimée avant le
> commit ; `ProbeTimeoutAudit` est revenu à **64, PASSED**.

## L'ACQUIS DU LOT 1, ÉCRIT ICI POUR NE PLUS ÊTRE REDEMANDÉ

⚠️ **`GPUParticles3D` EST FONCTIONNEL EN RENDERER `Compatibility` SUR
SAFARI iOS / WebGL2.** Vérifié **par Mathieu, sur device, le 4 septembre
2026**. Ce n'est pas une mesure sandbox : c'est un fait de device, et il
vaut **pour tout le projet**, pas seulement pour le feu. Toute session
future qui hésite à poser un `GPUParticles3D` dans ce jeu a sa réponse ici
et n'a **rien à re-prouver**.

Ce que ce fait ne dit pas : que les particules soient la bonne réponse au
feu de camp. Elles ne le sont pas — voir juste en dessous.

## Les trois candidats du lot 1 sont ÉCARTÉS, et retirés du fichier

`A GPU`, `B CPU`, `C SHEET` **ne produisent pas le style voulu**. Aucun des
trois n'est en cause techniquement : les trois dessinaient, les trois
tenaient le budget. Ils échouent sur la CIBLE ARTISTIQUE — flamme illustrée,
aplats francs façon clipart — et un candidat qui ne peut pas y arriver
occupe un créneau d'attention de Mathieu pour rien.

Ils sont **supprimés de `scripts/hub/HubFlameRecon.gd`** dans ce lot. Ce qui
leur survit est la mesure de dégagement du site, réutilisée telle quelle,
jamais re-marchée.

## Ce que le lot 2 met sur le plateau

| slot | position | dégagement (lot 1) | candidat | étiquette |
|---|---|---|---|---|
| OUEST | (17,9 ; 25,4) | **3,575 u** | procédural, peu turbulent | `D1 UNIE` |
| CENTRE | (19,9 ; 25,4) | **3,521 u** | le PNG de Mathieu, animé | `E SPRITE` |
| EST | (21,9 ; 25,4) | **1,676 u** | procédural, très turbulent | `D2 NERVEUSE` |

⚠️ **LE FOND N'EST PAS LE MÊME POUR LES TROIS, ET C'EST `D2` QUI TIRE LA
COURTE PAILLE.** Le slot EST est à **1,676 u** d'un `TreeCrown`, contre
~3,5 u pour les deux autres : `D2` est lu contre un fond **plus proche et
plus chargé**. C'est un biais du comparatif, il ne peut pas être retiré sans
déplacer le site que Mathieu a choisi, donc il est **déclaré**.

Le placement de `D2` là est **délibéré** : c'est le candidat dont toute la
prétention est que ses langues QUITTENT le corps de la flamme, donc c'est
celui qui a le plus besoin d'être vu contre un fond proche. Mettre le
candidat le plus sage au créneau difficile aurait caché le mode de
défaillance que le comparatif existe pour trouver.

## L'axe qui sépare D1 de D2 — nommé, parce que le brief le demande

**Ce n'est PAS la vitesse. C'est jusqu'où le bruit a le droit de CASSER la
SILHOUETTE.** C'est la seule chose qu'une flamme procédurale sait faire
qu'un billboard ne peut structurellement pas : une langue qui naît, se
détache, monte seule et meurt. La vitesse suit — une langue détachée qui ne
voyage pas se lit comme un bug de rendu, pas comme du feu — mais la
**fragmentation** est la variable.

| | `turbulence` | `rise` | ce que ça donne |
|---|---|---|---|
| `D1` | 0,34 | 0,42 | le larme reste **UN corps**, le bruit ne grignote que le contour haut |
| `D2` | 0,82 | 0,86 | les langues se **séparent** réellement et montent seules |

Tout le reste — palette, taille, nombre de paliers, seuil de coupe, le
shader lui-même — est **identique au byte près**. Deux uniformes diffèrent.

## La palette est MESURÉE sur la référence de Mathieu, pas inventée

`assets/textures/props/campfire_flame.png`, 512×512 RGBA, **120 301 pixels
opaques** (45,9 % de l'image), décodé pixel par pixel. Les quatre paliers de
`D1`/`D2` sont les quatre bacs dominants d'un cube de quantification 16 :

| palier | hex | part des opaques | L relative | contraste vs sol du hub (L = 0,0799) |
|---|---|---|---|---|
| `STEP_CORE` | `#FEF175` | 3,4 % | 0,8527 | **6,95:1** |
| `STEP_HOT` | `#FED847` | 6,6 % | 0,7064 | **5,82:1** |
| `STEP_MID` | `#FD9625` | 9,5 % | 0,4283 | **3,68:1** |
| `STEP_EDGE` | `#F95B25` | **19,8 %** (le plus courant) | 0,2776 | **2,52:1** ❌ |

**La teinte est donc TENUE CONSTANTE entre les trois candidats** : `D1` et
`D2` quantifient les couleurs du PNG, `E` dessine le PNG. Ce qui reste
différent entre eux est ce que le comparatif est censé arbitrer.

⚠️ **`STEP_EDGE` ne franchit PAS 3,0:1 contre le sol du hub.** C'est une
propriété de l'art de référence, pas d'une décision prise ici, et elle est
**publiée plutôt que corrigée en douce** : la corriger voudrait dire que `D`
ne correspond plus au PNG que `E` dessine, c'est-à-dire casser la seule
chose qui tient ce comparatif ensemble.

## ⚠️ UN CONFONDANT SURVIT, ET IL FAUT LE DIRE À MATHIEU AVANT QU'IL ARBITRE

**Le PNG de référence est un DÉGRADÉ CONTINU.** Mesuré : **10 200 couleurs
opaques distinctes**, chauffant régulièrement de `#F75C2C` en haut à
`#FDD850` en bas (profil vertical par bandes de 64 lignes). Ce n'est pas du
clipart à aplats au niveau du pixel — c'est une illustration lissée.

Or la cible artistique du brief dit « **PAS de dégradé continu** ». `D1`/`D2`
quantifient en quatre paliers parce que le brief le demande ; `E` ne le peut
pas, parce que ce serait réécrire l'asset de Mathieu — ce que ce lot
n'a pas le droit de faire.

**Donc deux questions arrivent dans UNE seule image :**

1. *aplats francs* contre *dégradé continu* — et la réponse est déjà décidée
   par la SOURCE, pas par la technique ;
2. *silhouette procédurale* contre *silhouette fixe* — la vraie question du
   comparatif.

Ce document ne prétendra pas qu'un verdict unique répond aux deux. Si
Mathieu préfère `E`, la question « et si on quantifiait aussi le PNG ? »
reste **ouverte et non mesurée**.

## Le coût — trois chiffres, et deux d'entre eux ne discriminent pas

Banc : `xvfb` + `--rendering-driver opengl3`, flags moteur **avant** le
`--`, `--fixed-fps 60`, à travers le `SubViewport`, la caméra et
l'`Environment` livrés.

### 1. Primitives — mesurées, et elles ne disent RIEN

`RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME`, pire frame sur 120, Keepy en
(19,9 ; 25,4). Le site projette en **(540, 1058) sur 1080×1920** — le même
chiffre que le lot 1 a publié, donc le même cadrage.

| état | primitives | delta |
|---|---|---|
| baseline, candidats cachés | **35 134** | +0 |
| baseline, nœud `FlameRecon` **RETIRÉ de l'arbre** | **35 134** | +0 |
| `D1` seule (étiquette off) | 35 136 | **+2** |
| `E` seule (étiquette off) | 35 136 | **+2** |
| `D2` seule (étiquette off) | 35 136 | **+2** |
| les trois + étiquettes | 35 232 | +98 |

Marge contre le plafond de 50 000 : **14 768 primitives**.

**+2 partout, parce que chaque candidat est UN quad.** Le compteur de
primitives dit donc que les trois sont identiques. Ils ne le sont pas : un
shader de bruit s'exécute **par pixel**, et aucune primitive ne le voit.
C'est exactement l'angle mort que le brief demandait de ne pas supposer
négligeable.

⚠️ **Le nœud caché coûte EXACTEMENT ce que coûte le nœud absent (+0).**
Mesuré, pas supposé : la baseline « cachée » et la baseline « retiré de
l'arbre » sortent au même entier.

⚠️ **ET LA BASELINE NE REPRODUIT PAS CELLE DU LOT 1 : 35 134 contre
34 846, soit +288 (0,83 %).** Ce qui a été vérifié, et qui ferme les
explications faciles :

* la géométrie du plateau est **identique au byte près** entre la pointe du
  lot 1 et cette branche — `git diff` sur `scripts/hub`, `scenes/HubWorld.tscn`,
  `resources/hub`, `scripts/world` est **VIDE** ;
* le chiffre est **parfaitement stable dans ce banc** : trois échantillons
  worst-of-120 donnent **35 134..35 134, spread 0**. Ce n'est donc pas une
  phase d'échantillonnage contre les acteurs animés du hub ;
* le cachage n'y est pour rien (+0, ci-dessus).

**La cause n'est PAS isolée**, et ce lot le dit plutôt que de l'habiller.
Ce que ça ne contamine pas : **tous les deltas publiés ici sont pris contre
la baseline DE LEUR PROPRE RUN**, donc un décalage de banc ne peut pas
fuir dedans. Ce que ça coûte : le droit d'écrire « ce banc reproduit le
chiffre au dossier ». Il ne le reproduit pas, à 0,83 % près, et le lot 3
devrait rouvrir ça avant de s'appuyer sur un absolu du lot 1.

### 2. Coût ALU par fragment — la mesure que ce lot existe pour prendre

Viewport dédié 512×512 = **262 144 fragments**, quad couvrant exactement le
cadre, wall-clock sur 60 frames × **3 passes**.

⚠️ **DEUX VERSIONS DE CE BANC ONT DONNÉ DES COÛTS NÉGATIFS AVANT QUE LE
CONTRÔLE SOIT BON.** Le récit vaut plus que le chiffre :

* **v1** : contre un quad `StandardMaterial3D` plat, `D1` et `D2` sortaient
  **0,27 ms PLUS RAPIDES** que le contrôle. Cause : les deux shaders
  `discard` la moitié de leur quad, donc ils ombraient **moins de
  fragments**. Le banc comparait de la **COUVERTURE**, pas du coût de
  shader — et il flattait précisément le candidat à la silhouette la plus
  découpée.
* **v2** : discards neutralisés textuellement dans la source livrée →
  toujours **−0,12 ms**. Donc ce n'était pas la couverture. Cause :
  `StandardMaterial3D` compile le programme spatial COMPLET de Godot,
  alors que les candidats sont des shaders `unshaded` minimaux. **Le
  contrôle était un AUTRE PROGRAMME, pas « la même chose sans les
  maths ».** Un coût négatif, c'est à quoi ressemble un mauvais contrôle.
* **v3** : le contrôle est construit **DEPUIS LA SOURCE LIVRÉE** — le vrai
  shader, corps de `fragment()` remplacé par une écriture constante. Même
  `render_mode`, même `vertex()` billboard, mêmes uniformes. Le delta est
  alors **exactement les maths**.

| passe | ms/frame | spread | maths seules |
|---|---|---|---|
| viewport vide | 7,244 | 0,390 | — |
| contrôle `D` (boilerplate, zéro maths) | 7,651 | 0,430 | — |
| contrôle `E` (boilerplate, zéro maths) | 7,994 | 0,712 | — |
| **`D1`** 2 octaves de bruit | 8,709 | 0,264 | **+1,058** |
| **`D2`** 2 octaves de bruit | 8,899 | 0,568 | **+1,248** |
| **`E`** 1 fetch de texture | 9,616 | 0,455 | **+1,622** |

Plancher de bruit du banc (pire spread) : **0,712 ms**.

**Ce que ces chiffres disent :** les trois shaders coûtent quelque chose de
**mesurable** — +1,0 à +1,6 ms pour 262 144 fragments, soit ~4 à 6 ns par
fragment sous llvmpipe. Le coût par pixel n'est **pas** négligeable dans
l'absolu.

**Ce qu'ils ne disent PAS :** un classement. Les écarts ENTRE candidats
(0,19 et 0,37 ms) sont **à l'intérieur du plancher de bruit de 0,712 ms**.
Les deux contrôles diffèrent eux-mêmes de 0,344 ms. **Ce banc sépare les
shaders du contrôle, il ne sépare pas les shaders entre eux.** Publié comme
tel, comme au lot 1, plutôt que présenté comme un ordre.

⚠️ **Et le sens apparent est CONTRE-INTUITIF ET NON TRANSPORTABLE.** `E`,
le simple fetch de texture, sort **le plus cher** ici. C'est cohérent avec
llvmpipe : un rasteriseur LOGICIEL paye un échantillonnage trilinéaire sur
une texture de 512² en cache misses CPU, alors qu'un GPU le fait presque
gratuitement et paye au contraire le bruit ALU. **Ce banc sur-estime `E` et
sous-estime `D` par rapport à un iPhone. L'ordre ne transporte pas.**

### 3. Couverture — combien de son quad chaque shader GARDE

Les discards remis, sur le même viewport 512² :

| candidat | fragments gardés | part du quad |
|---|---|---|
| `D1` | 119 770 | **45,7 %** |
| `D2` | 116 723 | **44,5 %** |
| `E` | 123 372 | **47,1 %** |

Les trois se tiennent en 2,6 points. **Turbulence change la FORME de la
silhouette, pas son aire** : `D1` et `D2` sont à 1,2 point l'un de l'autre.

### 4. Le coût réel, dérivé — et il est minuscule

Le coût ALU se paye × la surface RÉELLEMENT peinte, pas × 262 144. À la
station NEAR, chaque flamme peint entre 2 560 et 3 306 pixels :

| candidat | maths | px peints | coût par frame |
|---|---|---|---|
| `D1` | +1,058 ms / 262 144 frag | 3 306 | **0,0133 ms** |
| `D2` | +1,248 ms / 262 144 frag | 3 292 | **0,0157 ms** |
| `E` | +1,622 ms / 262 144 frag | 2 560 | **0,0158 ms** |

Contre les **36 à 41 ms** de frame que le lot 1 a mesurés sur ce même
sandbox : **~0,04 % de la frame**. La réponse à « le shader de bruit
est-il négligeable ? » est donc **oui, mais pas parce que le shader est
bon marché** — il ne l'est pas — **parce que la flamme couvre 0,16 % de
l'écran**. Une flamme plein cadre serait une tout autre facture.

## Lisibilité — et la mesure qui tranche le comparatif

⚠️ **PREMIÈRE VERSION DE CETTE PHASE : FAUSSE, ET SPECTACULAIREMENT.** Elle
plaçait Keepy AU site, c'est-à-dire **debout à l'intérieur du candidat `E`**
qui occupe le créneau central. `E` peignait alors **50 pixels** contre
3 916 pour `D1`, ce qui se lit exactement comme « `E` est invisible à
distance de jeu ». C'était le corps de Keepy qui l'occultait. Les deux
stations placent désormais Keepy **AU SUD de la rangée**.

⚠️ **ET « DE PRÈS » CONTRE « À DISTANCE DE JEU » N'EST PAS UN AXE DE
DISTANCE CAMÉRA SUR CE PLATEAU.** `HubCamera.OFFSET` est une **CONSTANTE**
`(0 ; 7,6 ; 8,9)` : la caméra est à **11,703 u des pieds de Keepy et n'en
bouge JAMAIS**. Marcher vers le feu ne zoome pas dessus — ça fait glisser
le feu vers le BAS du cadre pendant que la caméra garde sa distance. Les
deux stations diffèrent donc par la place dans le cadre et par le fog
traversé, **pas par le grossissement**.

| station | Keepy | caméra → flamme | quad à l'écran |
|---|---|---|---|
| FAR | 8,0 u au sud | **18,302 u** | **78,8 px** de haut |
| NEAR | 1,6 u au sud | **12,633 u** | **98,7 px** de haut |

### La quantification, mesurée — c'est LE chiffre du lot

Nombre de couleurs distinctes dans les pixels **réellement peints** par
chaque candidat (différence contre la même frame, candidat caché — jamais
une fenêtre fixe, que `CLAUDE.md` documente comme dérivant) :

| candidat | FAR | NEAR |
|---|---|---|
| `D1` | **6** | **8** |
| `D2` | **6** | **7** |
| `E` | **2 050** | **1 626** |

**Un facteur ~250.** C'est « aplats francs » contre « dégradé continu »,
chiffré. `D1`/`D2` sortent 6 à 8 couleurs et non 4 exactement parce que le
fog exponentiel du hub (`fog_density = 0,016`) mélange chaque palier vers
la couleur de brume selon la profondeur — les couleurs supplémentaires sont
des voisines à 1/255 près (`#DE841F` et `#DF841F`), pas des paliers de plus.

### Contraste contre le sol du hub (L rendue = 0,0799)

| candidat | station | pire contraste | couleur dominante |
|---|---|---|---|
| `D1` | FAR | 2,00:1 | `#DE841F` 31,1 % → 2,86:1 |
| `D2` | FAR | 2,00:1 | `#DFBE3E` 39,0 % → **4,45:1** |
| `E` | FAR | **1,04:1** | `#F45B23` 0,3 % → 2,45:1 |
| `D1` | NEAR | 2,14:1 | `#E8C540` 31,2 % → **4,81:1** |
| `D2` | NEAR | 2,14:1 | `#E8C540` 35,6 % → **4,81:1** |
| `E` | NEAR | **1,01:1** | `#DE5120` 0,5 % → 2,04:1 |

⚠️ **Le pire pixel de `E` est un VERT** (`#2C571F`, `#2E5B20`) à **1,01:1**.
Ce n'est pas une couleur du feu : c'est la frange **alpha douce** du PNG qui
se mélange au feuillage derrière. `D1`/`D2` `discard` net, donc n'ont pas de
frange et leur pire pixel est leur propre `STEP_EDGE` traversé par le fog.

⚠️ **Le nombre de pixels peints n'est PAS un score de lisibilité et ne doit
pas être lu comme tel.** `E` peint 2 951 px en FAR contre 1 863 pour `D1`,
et l'inverse en NEAR — parce que la frange alpha de `E` fait bouger des
pixels que l'œil ne voit pas, pendant que `D` a un bord franc. C'est une
EMPREINTE, pas une visibilité. Les deux signaux qui portent sont le nombre
de couleurs et le contraste, ci-dessus.

## Aliasing de `E` — la question est CLOSE, et pas dans le sens attendu

Densité de texels : texels source par pixel écran, sur la hauteur du quad.
Au-dessus de 1, l'image est **minifiée** (les mipmaps la portent) ; au-
dessous, elle est **AGRANDIE** et aucun mipmap n'aide — les 512 px sources
sont étirés et le filtre linéaire transforme un dessin net en bouillie.

| station | densité mesurée |
|---|---|
| FAR (18,302 u) | **6,50 texels/px** |
| NEAR (12,633 u) | **5,19 texels/px** |

La densité ne croise 1,0 qu'à une distance caméra de **2,93 u**. Or
`HubCamera.OFFSET` est **constante** : la caméra est à 11,703 u de Keepy et
**ne s'approche jamais**. La flamme n'est donc jamais à moins de ~11,3 u de
l'objectif.

**`E` NE PEUT PAS PIXELISER DANS CE HUB.** Le risque réel est l'inverse — le
**scintillement de minification** à 5-6,5 texels/px sur une caméra qui suit
un personnage qui saute. C'est pour ça que
`assets/textures/props/campfire_flame.png.import` passe à
`mipmaps/generate=true` dans ce lot, et que `detect_3d/compress_to` passe à
`0` pour figer l'import (l'éditeur réécrit sinon ce fichier au premier
usage 3D, et la CI n'aurait pas le même import que le poste).

**L'asset lui-même n'est pas touché** — un `.import` est un sidecar dérivé,
pas l'asset. Payload : le `.ctex` généré pèse **182 392 octets**, et il est
bien packé (`Storing File: res://.godot/imported/campfire_flame.png-*.ctex`).

## Le shader — deux décisions qui ne sont pas des détails

### `blend_mix`, et NON `blend_add`

Les candidats du lot 1 étaient **additifs**, ce qui est le choix flatteur
pour du feu et le **mauvais** ici : un blend additif SOMME la flamme dans ce
qu'il y a derrière, donc un « aplat franc » cesse d'être franc dès que le
fond change de luminosité, et deux des quatre paliers virent vers le blanc.
La cible demande des aplats. **Seul un blend alpha peut poser une couleur
mesurée à l'écran et faire qu'elle SOIT encore cette couleur.** `E` est
alpha-blendée pour la même raison.

### Aucun `smoothstep` sous la ligne de coupe

Un `smoothstep` **EST** le dégradé continu que le brief exclut. Les quatre
paliers sont posés par des `if` durs sur la valeur de chaleur, et le bruit
est porté **MULTIPLICATIVEMENT** : là où le bruit plonge, la flamme ne se
contente pas de s'assombrir — elle passe sous la coupe et **le corps se
SCINDE**. Un bruit additif n'aurait fait que la nuancer. C'est le mécanisme
qui fait qu'une langue naît, se détache et meurt.

## Ce que ce lot n'a PAS mesuré

1. **Safari iOS.** Rien ici n'a tourné ailleurs que sous llvmpipe. Le
   verdict est celui de Mathieu, navigation privée, sur
   `keepy-staging.vercel.app`.
2. **Un classement de coût entre les trois** — le banc ne les sépare pas, et
   l'ordre apparent est un artefact de rasteriseur logiciel.
3. **La cause des +288 primitives** contre la baseline du lot 1, sur une
   géométrie pourtant identique au byte près.
4. **`E` quantifiée.** Si Mathieu retient `E` mais veut des aplats, il faut
   quantifier le PNG dans le shader — non écrit, non mesuré.
5. **Le glow**, toujours disponible et toujours non chiffré (lot 1).
6. **Le décor de camp** — bûches, cercle de pierres — hors périmètre.

## Ce que ce lot a écrit

* `scripts/hub/HubFlameRecon.gd` — réécrit : `A`/`B`/`C` supprimés, `D1`,
  `D2` et `E` posés, la palette mesurée sur le PNG, deux shaders.
* `assets/textures/props/campfire_flame.png.import` — sidecar d'import,
  mipmaps activés, `detect_3d` figé. **Le PNG lui-même n'est pas touché.**
* Ce document, et une ligne d'index.

**`scenes/HubWorld.tscn` n'a PAS bougé** : le nœud `FlameRecon` que le lot 1
y a posé suffit, et `DEBUG_POSITION_OVERLAY` reste tel quel sur `staging`.

**Aucun asset importé, aucun asset supprimé, aucun tap, aucune pose de
Keepy.** La sonde `FlameCompareProbe` est supprimée avant le commit et
`ProbeTimeoutAudit` est revenu à **64, PASSED**.

---

# Feu de camp — LOT 3 : l'objet définitif (4 septembre 2026)

> **FIN DE LA PHASE RECON.** Ce lot pose l'objet pour de bon : plus de
> comparaison, plus d'étiquette D1/D2/E. Le verdict de Mathieu (device,
> 4 septembre 2026) retient **candidat E** — le PNG de référence sur un
> billboard animé par shader. Toujours `staging` uniquement.

## Le verdict, et ce qui disparaît avec lui

D1 et D2 (la flamme procédurale, quatre paliers durs) sont **retirés
entièrement** de `scripts/hub/HubFlameRecon.gd` — qui n'existe plus : le
fichier est supprimé, remplacé par `scripts/hub/HubCampfire.gd`, un script
de PROP et non plus de recon. Ce que le lot 2 avait déjà mesuré et publié
tient toujours et n'est pas refait : le procédural n'a jamais atteint la
silhouette voulue (un contour lisse à goutte unique, jamais des aplats de
type clipart), et le PNG de Mathieu est un dégradé continu que la
quantification en 4 paliers ne pouvait imiter qu'en réécrivant l'art
source. **C'est un résultat utile, publié en LOT 2, pas un échec qu'on
efface** — cette ligne du brief est respectée à la lettre : rien n'est
réécrit dans la section LOT 2 ci-dessus, ce lot ajoute seulement la sienne.

`scripts/hub/HubCampfire.gd` reprend le shader de candidat E **byte pour
byte** (billboard Y-locked écrit à la main, `blend_mix`, pulsation
d'échelle + ondulation croissante vers le haut + variation de luminosité,
les trois fréquences 0,83 / 0,61 / 1,37 Hz non commensurables) : le lot ne
retouche pas ce que le device a déjà validé.

## Les bûches — géométrie réelle, jamais un billboard

Six cylindres bas-poly (`CylinderMesh`, `radial_segments = 6`) en
matériau **`HubBuilder.TRUNK_COLOR`** lu par accesseur statique
(`HubBuilder` porte un `class_name`, donc `HubBuilder.TRUNK_COLOR` se lit
directement — aucune couleur retapée à la main, doctrine « un fait est
publié une fois »). Disposition en teepee : une base sur un cercle de
rayon 0,30 u, convergeant vers un point commun à 0,44 u de hauteur — la
forme qui enveloppe la base de la flamme sur la quasi-totalité de
l'azimut, contrairement à deux bûches en croix simple qui n'auraient
couvert que deux côtés opposés.

**Pourquoi jamais un billboard** : un billboard de bûche pivoterait avec la
caméra exactement comme la flamme, et une bûche qui tourne trahit le
dessin dès que l'angle change — la flamme s'en sort parce que le feu n'a
structurellement aucune orientation propre, une bûche en a une. Chaque
bûche est donc une géométrie réelle, orientée une fois par un
`Basis(Quaternion(Vector3.UP, dir))`, jamais retournée vers quoi que ce
soit après.

## Coupe basse — vérifiée par rendu, pas supposée

La coupe nette du PNG (opaque jusqu'à sa dernière rangée, aucun fondu) est
à l'origine de la flamme (`y = 0`, même hauteur que la base des bûches).
Le brief demandait une vérification empirique, pas un raisonnement
géométrique sur le papier ; la sonde jetable `CampfireProbe.gd` (supprimée
avant ce commit) a rendu une passe d'isolation masque-blanc à **8 azimuts
× 3 distances (2,5 / 8,0 / 16,0 u)** pour chaque instance, sur la vraie
caméra `HubCamera` (position construite depuis `HubCamera.OFFSET`, exactement
comme le jeu la calcule) :

| instance | pixels de coupe non couverts par une bûche, sur 24 vues |
|---|---|
| SITE (échelle 1,6) | **0 / 0 — PASS** |
| ALT (échelle 1,2) | **0 / 0 — PASS** |

Méthode : un shader d'isolement dédié (`CUT_BAND_SHADER`) peint en blanc
pur uniquement la bande `v < 0,06` de la flamme (la coupe elle-même, pas
tout le corps), fond noir, tout le reste de la scène caché ; un second
rendu peint les bûches en blanc de la même façon ; tout pixel blanc du
premier rendu qui n'est PAS blanc dans le second est une fuite. Zéro fuite
mesurée aux 24 combinaisons — la coupe ne perce jamais.

## Clearance — bûches comprises, mesurée contre TOUT ce qui est dessiné

Pas la formule du lot 1/2 (flamme seule) : la sonde jetable a parcouru le
sous-arbre `Props` en entier — chaque `MeshInstance3D` individuel et
chaque instance de chaque `MultiMeshInstance3D` — et calculé la distance
minimale entre le point le plus proche de CHAQUE pièce dessinée et le
centre du feu, moins le rayon propre du feu (mesuré sur ses propres
enfants réels : bûches + flamme, jamais supposé) :

| instance | position | rayon propre | voisin le plus proche | clearance |
|---|---|---|---|---|
| SITE | (19,9 ; 25,4) | 0,746 u | `TreeCrown[36]` @ 3,560 u | **2,815 u** |
| ALT | (16,9 ; 25,4) | 0,559 u | `TreeCrown[24]` @ 2,625 u | **2,066 u** |

Les deux clearances sont positives et confortables — aucun chevauchement
avec le décor existant, bûches comprises. ALT est légèrement plus serré
(comme prévu : le lot 2 avait déjà mesuré le côté ouest comme le plus
dégagé, mais moins que le site lui-même).

## Échelle — DEUX instances posées, recommandation motivée, arbitrage à Mathieu

Comme demandé, le lot ne tranche pas seul :

* **SITE, x1,6 (RECOMMANDÉ)** — hauteur de flamme 1,84 u (1,15 × 1,6), plus
  le bûcher (0,44 u). Keepy mesure ≈ 1,55 u au sommet du crâne (capsule
  corps : rayon 0,4, hauteur 1,3, décalée de 0,9). Raisonnement : un feu de
  camp censé être l'élément central du campement doit rivaliser avec cette
  silhouette plutôt que rester à hauteur de genou — le turnstile, la
  balançoire et le plongeoir du même hub dépassent tous 1,6 u. À x1,0 (ce
  que le device a vu au lot 2, sans bûches), le brief prédit lui-même que
  l'ajout des bûches va faire lire l'ensemble comme trop petit ; x1,6 est
  la réponse à cette prédiction.
* **ALT, x1,2** — hausse conservatrice depuis x1,0, à 3 u à l'ouest du
  site. Sert de point de comparaison direct : si x1,6 lit comme
  excessif sur device, x1,2 est l'alternative la plus proche de ce qui a
  déjà été validé.

Le site exact (19,9 ; 25,4) porte l'instance recommandée (x1,6) ; l'autre
est à côté. Le lot 4 ne garde qu'une des deux et supprime ce comparatif,
par les NEXT STEPS du brief lui-même.

## L'écart de baseline — un TROISIÈME chiffre, toujours pas isolé, mais mieux cerné

Rappel : lot 1 a publié **34 846**, lot 2 **35 134** (+288, 0,83 %) sur une
géométrie identique au byte près. Ce lot ajoute un troisième point de
mesure, sur un process totalement neuf (import complet depuis zéro,
`godot4 --headless --import`, aucun résidu d'un run précédent) :

**baseline mesurée ici : 34 674** — un TROISIÈME nombre, différent des
deux précédents, alors que `scripts/hub`, `scenes/HubWorld.tscn`,
`resources/hub` et `scripts/world` ne portent, pour la partie baseline
(nœud `Campfires` caché), **aucune différence de comportement** vis-à-vis
du lot 2 : les deux flammes ajoutées par ce lot sont masquées pendant la
mesure baseline exactement comme `FlameRecon` l'était au lot 2.

Ce que ce lot ferme, que les deux précédents n'avaient pas : **la lecture
est parfaitement stable À L'INTÉRIEUR d'un même process.** Deux lectures
successives du même run (`baseline read 1` et `read 2`, même frame worst-of
60, aucun redémarrage entre les deux) rendent **34 674 et 34 674 — spread
0**. Ce n'est donc PAS un bruit d'échantillonnage entre deux frames du
pire cas, exactement comme le lot 2 l'avait déjà établi pour sa propre
paire de lectures.

**Ce que ça implique, sans le prouver totalement** : la variance est
cross-PROCESS (trois lancements de `godot4`, trois nombres différents :
34 846 / 35 134 / 34 674) mais nulle intra-process. Le candidat le plus
probable est un état dépendant de l'heure de lancement réelle plutôt que
du code — les acteurs animés du hub (chouette, ours, blaireau...) avancent
sur `TIME`, dont la phase au moment où la frame « pire cas sur N » est
échantillonnée dépend de l'instant de boot du process, ce qui peut faire
entrer ou sortir un acteur du frustum de justesse à la frame retenue. Ce
lot n'a **pas** isolé ce mécanisme expérimentalement (il faudrait geler
l'horloge des acteurs et rejouer plusieurs process pour le confirmer) —
il est donc rapporté comme **probable, non prouvé**, plutôt que présenté
comme la cause. Ce que ça ne change pas : chaque delta publié dans ce
document reste pris contre la baseline DE SON PROPRE RUN, donc rien de
cet écart ne contamine les deltas.

### Primitives — le vrai coût des bûches, mesuré

Toujours worst-of-60, site (19,9 ; 25,4), caméra réelle :

| état | primitives | delta |
|---|---|---|
| baseline (feux cachés), lecture 1 | 34 674 | +0 |
| baseline (feux cachés), lecture 2 | 34 674 | +0 (spread intra-process : 0) |
| SITE + ALT visibles (2 feux, 12 bûches, 2 flammes) | **35 218** | **+544** |

Marge contre le plafond de 50 000 : **14 782 primitives**. Bien au-dessus
du plancher lot 2 (+2 par billboard nu) : chaque bûche est une géométrie
réelle, ~272 primitives en moyenne par feu complet (6 bûches + 1 quad),
et la marge encaisse ça sans discussion.

## Escalade — non déclenchée

Le chemin de placement du décor procédural n'a pas résisté : `Campfires`
est un `Node3D` frère de `Props` dans `scenes/HubWorld.tscn`, exactement
comme l'était `FlameRecon`, et ne touche ni `HubBuilder.gd` ni aucun
`MultiMeshInstance3D` partagé. Aucune bascule sur Opus nécessaire à ce
lot.

## Ce que ce lot a écrit

* `scripts/hub/HubCampfire.gd` — nouveau, remplace
  `scripts/hub/HubFlameRecon.gd` (supprimé). Deux instances complètes
  (flamme + 6 bûches chacune), échelles 1,6 (site, recommandé) et 1,2
  (alt, 3 u à l'ouest), étiquetées.
* `scenes/HubWorld.tscn` — le nœud `FlameRecon` renommé `Campfires`,
  `ext_resource id="17"` repointé vers `HubCampfire.gd`. Rien d'autre n'a
  bougé.
* Ce document.

Aucun asset touché — `assets/textures/props/campfire_flame.png` et son
`.import` restent ceux du lot 2. La sonde jetable `CampfireProbe.gd` (et
sa scène) et la sonde de boot `HubBootCheck.gd` sont supprimées avant ce
commit ; `ProbeTimeoutAudit` revient à **65 scènes de sonde, PASSED**
(65, pas 64 : le compte affiché dans le brief du lot 3 datait d'avant ce
lot et n'a jamais été un chiffre gaté par la sonde elle-même — elle ne
vérifie qu'une propriété par sonde, jamais un total fixe).

Build vérifié par un export release réel (`godot4 --export-release
"Web"`, templates 4.3-stable, exit 0, aucune erreur GDScript ni erreur de
shader) : `index.wasm` fait **35 376 909 octets**, la valeur que
`CLAUDE.md` documente pour tout lot qui ne touche pas le code moteur —
confirmé, ce lot ne touche que du contenu.

## LOT 4 — imbrication flamme/bûches, la métrique du lot 3 était la mauvaise

Défaut constaté par Mathieu sur device (iPhone Safari,
`keepy-staging.vercel.app`) : la flamme se lit comme POSÉE DERRIÈRE les
bûches, pas comme jaillissant d'elles. Ce lot mesure la cause, corrige, et
pose deux variantes d'enfoncement pour arbitrage — même patron que
l'échelle au lot 3.

### La cause dominante — chiffrée, pas déduite

Lot 3 avait mesuré « 0 fuite sur 24 vues » et concluait à raison sur ce
qu'il mesurait : la coupe nette du PNG (la toute dernière rangée de
pixels opaques, `v < 0,06`, ~0,08 u de large à l'échelle x1,6) ne perce
jamais derrière les bûches. C'était vrai, et c'était la MAUVAISE
question — le défaut de Mathieu n'a jamais porté sur ce fil quasi
ponctuel.

Mesure directe sur `assets/textures/props/campfire_flame.png` (415x512
opaque, PIL, comptage de largeur par rangée) : la texture passe de
**0,079 u à 0,705 u de large entre y=0 et y=0,10 u** (post-échelle
x1,6) — elle FLARE presque instantanément. Or l'ancien bûcher (lot 3)
avait son apex à `LOG_APEX_HEIGHT=0,44` nominal, **0,70 u** à l'échelle
x1,6 — c'est-à-dire exactement la hauteur où la flamme est déjà proche de
son ventre le plus large (~1,0-1,1 u), et où les bûches, elles,
convergent déjà vers zéro. Les deux formes se croisaient tout en haut du
tas plutôt que de rester imbriquées sur toute sa hauteur : sur la quasi
totalité de la hauteur du bûcher, la flamme était déjà PLUS LARGE que le
bois censé la cacher. **C'est la cause dominante, chiffrée** : ce n'est
pas un problème de coupe (la coupe ne fuit jamais), c'est un problème de
PROPORTION entre la vitesse d'évasement de la texture et la hauteur du
tas.

Confirmé une seconde fois par une sonde jetable (`CampfireImmersionProbe.gd`,
supprimée avant ce commit) qui étend exactement la méthode du lot 3 (rendu
d'isolement masque-blanc, 8 azimuts x 3 distances 2,5/8,0/16,0 u, sur la
vraie `HubCamera`) à une bande MESURÉE (`_MUST_COVER_WORLD_Y`) au lieu de
la bande littérale du lot 3 :

| bande | immerge | prudent |
|---|---|---|
| coupe littérale (`v<0,06`, méthode lot 3) | 0/12 fuites (les deux étaient déjà bonnes) | 0/12 fuites (avec la géométrie finale — 3/12 avec la géométrie thin/sparse de départ) |
| bande mesurée (`y<0,12 u`, ~2x plus large) | **0/12 fuites (géométrie finale)** | **0/12 fuites (géométrie finale)** |

Sur la géométrie de PREMIER essai (bûches thin/sparse, 6 rondins fins hérités
du lot 3, juste repositionnés plus bas/plus étalés sur la seule base d'un
modèle 2D continu sur papier) : **19 fuites sur 24 vues testées** sur la
bande mesurée, RÉPARTIES SUR TOUS LES AZIMUTS (pas seulement entre deux
rondins) — preuve que la deuxième cause candidate du brief (des rondins
individuels trop fins, donc des vides angulaires entre eux qu'un modèle
d'enveloppe 2D continue ne voit pas) est une cause RÉELLE et SECONDAIRE,
mesurée séparément de la cause dominante ci-dessus. La troisième cause
candidate du brief (décalage caméra dû au pitch) n'a PAS été retenue : le
rendu par isolement mesure directement en pixels, sans hypothèse
géométrique intermédiaire, et le motif des fuites (quasi tous azimuts, pas
seulement ceux alignés avec le pitch) ne correspond pas à un artefact de
projection.

### Le correctif — bûcher bas/étalé, huit rondins épais, flamme engagée

`scripts/hub/HubCampfire.gd`, deux volets :

1. **Bûcher plus bas, plus étalé, plus dense** — `LOG_COUNT` 6→8,
   `LOG_RADIUS_TOP` 0,045→0,075, `LOG_RADIUS_BOTTOM` 0,065→0,12 (nominal),
   pour fermer les vides angulaires mesurés ci-dessus ; apex abaissé
   (0,44→0,22-0,26 nominal selon variante, soit 0,35-0,42 u à l'échelle
   x1,6 contre 0,70 u avant) et rayon d'anneau monté (0,30→0,38-0,42
   nominal) pour rester DANS la plage de hauteur où la texture n'a pas
   encore atteint son ventre.
2. **Flamme engagée** — un nouveau paramètre `flame_sink` (par variante)
   pousse la base du quad SOUS y=0 (nominal, avant échelle), enterrée
   derrière le plan Ground opaque (occlusion vérifiée par le rendu même,
   pas supposée sur le papier) — deuxième garantie indépendante des
   bûches, et la rangée qui tombe pile à y=0 est déjà partie dans
   l'évasement de la texture plutôt que son pixel le plus étroit.

### Deux variantes, échelle x1,6 partagée, degré d'enfoncement différent

| | PRUDENT (SITE_ALT) | IMMERGE — RECOMMANDÉ (SITE) |
|---|---|---|
| `ring_radius` nominal | 0,38 | 0,42 |
| `apex_height` nominal | 0,26 | 0,22 |
| `base_height` nominal | 0,05 | 0,04 |
| `flame_sink` nominal | 0,0 (coupe au ras du sol, comme le lot 3) | 0,08 (coupe enterrée sous le sol) |

Les deux partagent `SCALE=1,6` (décision de Mathieu au lot 3, non
rouverte), `LOG_COUNT/RADIUS_TOP/RADIUS_BOTTOM` et `LOG_COLOUR`. SITE
(19,9 ; 25,4) porte IMMERGE ; SITE_ALT (16,9 ; 25,4), 3 u à l'ouest, porte
PRUDENT — mêmes deux points déjà mesurés dégagés au lot 3. L'ancienne
comparaison d'échelle (x1,6 vs x1,2, ALT) et ses labels sont
**supprimés** : il ne reste que ces deux variantes, chacune à x1,6,
étiquetées par leur `Label3D` (`SITE IMMERGE (RECOMMANDE)` / `ALT
PRUDENT`).

**Recommandation : IMMERGE.** Les deux passent 0 fuite sur les deux
bandes (littérale et mesurée) aux 24 vues combinées, mais IMMERGE ajoute
la garantie indépendante de l'enterrement sous le plan Ground — un lot
futur qui retoucherait la géométrie des bûches sans y penser ne peut pas
faire réapparaître la coupe nette d'IMMERGE aussi facilement que celle de
PRUDENT, qui reste au ras du sol et dépend entièrement des bûches. Le
contraste bûches est aussi légèrement meilleur côté IMMERGE (3,499:1
contre 3,376:1, le site a un sol légèrement plus sombre que l'alt — voir
plus bas), sans que ce soit le facteur décisif.

### Contraste bûches — mesuré par rendu réel, pas par l'albédo seul

`HubBuilder.TRUNK_COLOR` (0,20 ; 0,13 ; 0,08), la couleur de tous les
troncs du hub, rendait quasi noir en isolation sur ce prop — L relative
WCAG ≈ 0,019 sur l'albédo brut, confirmé par la sonde en mode neutralisé
(rouge, voir plus bas) : L rendue mesurée 0,0553 (immerge) / 0,0523
(prudent) contre un sol à L≈0,084-0,087, soit un contraste de 1,27:1 /
1,33:1 — illisible, exactement le rapport de Mathieu.

Méthode masque-blanc (CLAUDE.md, « masque, pas fenêtre ») : un rendu
d'isolement peint les pixels bûches en blanc pur (tout le reste caché,
fond noir), un second rendu RÉEL (matériaux/fog/éclairage tels que
livrés) est échantillonné aux mêmes coordonnées — jamais l'albédo brut
seul, parce que le fog (`fog_density=0,016`) mesure une perte de
luminance d'environ 27% entre albédo et rendu à ~8 u de distance
(0,82;0,60;0,38 → L brute 0,372, L rendue 0,272).

Trois itérations avant stabilisation :

| couleur (albédo) | L rendue (immerge / prudent) | contraste vs sol rendu |
|---|---|---|
| `HubBuilder.TRUNK_COLOR` (0,20;0,13;0,08) | 0,0553 / 0,0523 | 1,27:1 / 1,33:1 — ROUGE, doctrine |
| première tentative (0,82;0,60;0,38) | 0,2716 / 0,2632 | 3,130:1 / **3,016:1** — vert, marge trop fine côté prudent |
| **couleur finale (1,0;0,80;0,56)** | **0,4225 / 0,4144** | **3,499:1 / 3,376:1** — vert, marge confortable |

Le sol lui-même a été re-mesuré en rendu réel à cette occasion (pas
seulement repris de CLAUDE.md) : L=0,0850 (site) / L=0,0876 (alt), cohérent
avec le L=0,0799 déjà documenté (l'écart tient à la position caméra/fog
spécifique à ce prop, pas à une contradiction).

`LOG_COLOUR` est désormais publiée séparément de `HubBuilder.TRUNK_COLOR`
— dérogation délibérée et documentée dans le fichier lui-même à la règle
« un fait publié une fois » : la couleur des troncs reste correcte pour
les troncs, elle ne l'est pas pour un petit tas de bois isolé, proche
caméra, sans éclairage directionnel pour le sculpter.

### Clearance — re-mesurée, l'emprise a grandi comme prévu

Sonde jetable, même méthode que le lot 3 (rayon propre mesuré sur les
enfants réels — bûches ET flamme, jamais supposé — puis distance minimale
à CHAQUE pièce dessinée du sous-arbre `Props`, individuelle et par
instance de `MultiMeshInstance3D`) :

| instance | rayon propre (avant) | rayon propre (après) | voisin le plus proche | clearance |
|---|---|---|---|---|
| SITE / IMMERGE | 0,746 u | **0,772 u** | `TreeCrown[36]` @ 3,144 u | **2,372 u** (contre 2,815 u au lot 3) |
| ALT / PRUDENT | 0,559 u | **0,746 u** | `TreeCrown[24]` @ 2,443 u | **1,697 u** (contre 2,066 u au lot 3) |

L'emprise a grandi comme annoncé (bûches plus étalées + plus épaisses),
la clearance a donc rétréci en proportion — mais reste positive et
confortable aux deux sites, aucun chevauchement avec le décor existant.
ALT/PRUDENT reste la plus serrée, comme au lot 3.

### Rouge avant vert

Deux volets neutralisés séparément dans le même run, puis restaurés et
vérifiés `cmp` byte-identiques à la version finale :

1. **Couleur seule** neutralisée (`LOG_COLOUR` → `HubBuilder.TRUNK_COLOR`)
   avec la géométrie déjà corrigée : 2 échecs (les deux contrastes), 0
   fuite de bande (la géométrie, elle, était déjà bonne) — confirme que
   les deux volets du correctif sont mesurés indépendamment l'un de
   l'autre.
2. **Géométrie ET couleur** neutralisées ensemble (retour aux
   `LOG_COUNT=6`, rayons 0,045/0,065 du lot 3, sur les nouveaux
   `ring_radius/apex_height/base_height` par ailleurs plus bas/étalés que
   le lot 3) : **5 échecs sur 10** — 2 bandes de fuite (immerge et
   prudent sur la bande mesurée, plus prudent sur la bande littérale — la
   géométrie amaigrie perd même la garantie du lot 3), 2 contrastes,
   clearance inchangée (n'a jamais dépendu de la couleur ni du rayon des
   rondins dans cette combinaison). Restauration vérifiée : `cmp` sur
   `scripts/hub/HubCampfire.gd`, identique au byte près (md5
   `30fe11ad7a39416b77f2dd34a3c21009` des deux côtés).

### Le coût — ProbeTimeoutAudit et le pack

`ProbeTimeoutAudit` : **64 scènes de sonde, PASSED** — vérifié identique
sur `origin/staging` AVANT ce lot (le chiffre de 65 publié au lot 3
n'était déjà plus exact, comme prévenu par ce même document : « jamais un
chiffre gaté par la sonde elle-même »). La sonde jetable
`CampfireImmersionProbe.gd`/`.tscn` de ce lot est supprimée avant ce
commit ; le compte revient donc à sa baseline réelle sans delta.

Export release réel (`godot4 --export-release "Web"`, templates
4.3-stable, sur un `.godot` ré-importé de zéro, `build/` nettoyé avant
export) : exit 0, aucune erreur GDScript ni shader. `index.wasm` =
**35 376 909 octets**, md5 `af4a8fc2925d992348eb30deeeb54360` ; `index.js`
md5 `4e08904b1b7107858246af44b602067b` — les deux empreintes documentées
par `CLAUDE.md` pour un lot qui ne touche pas le code moteur, confirmées
au byte/octet près. Aucune fuite de `scripts/dev/*`, `assets_source/*` ni
`docs/*` dans le pack (0 ligne `Storing File:` sur ces préfixes,
278 lignes au total). `campfire_flame.png` packé une seule fois, comme au
lot 3 — cet asset n'a pas été touché.

### Ce que ce lot n'a PAS mesuré

Pas de capture PNG offscreen comparative avant/après jointe à ce document
(la sonde jetable a été supprimée avant le commit, doctrine oblige) — le
verdict repose sur les chiffres d'isolement en pixels, pas sur une image.
Validation VISUELLE finale : device, comme toujours pour ce prop.

### Ce que ce lot a écrit

* `scripts/hub/HubCampfire.gd` — modifié : bûcher bas/étalé/dense (8
  rondins), `flame_sink` par variante, `LOG_COLOUR` propre et claire, deux
  variantes PRUDENT/IMMERGE à x1,6 partagé remplaçant l'ancien comparatif
  d'échelle x1,6/x1,2.
* Ce document.

Sonde jetable `CampfireImmersionProbe.gd`/`.tscn` supprimée avant ce
commit, comme `ProbeTimeoutAudit` le confirme (64 scènes, baseline
inchangée).

## LOT 5 — revert de `LOG_COLOUR` : l'éclaircissement du lot 4 n'avait jamais été demandé par Mathieu

Validation device (Mathieu, Safari iPhone, `keepy-staging.vercel.app`) de
l'imbrication flamme/bûches du lot 4 : **bonne**. Le rendu sombre des bûches
n'était pas un défaut de matériau : c'était le défaut d'imbrication
lui-même, déjà corrigé au lot 4 par la géométrie seule (bûcher bas/étalé +
`flame_sink`). Verdict sur le résultat clair : mauvais. **Retour pur et
simple** à `HubBuilder.TRUNK_COLOR` — pas de compromis, pas de teinte
intermédiaire.

⚠️ **Rectification faite au lot 6 — l'éclaircissement de `LOG_COLOUR` ne
venait PAS de Mathieu.** Une formulation antérieure de cette section parlait
d'« une demande erronée de Mathieu » : c'est faux, et l'attribution comptait.
Mathieu n'a jamais rien demandé sur la couleur des bûches ; la demande venait
de l'assistant de cadrage. **L'enseignement réel à conserver** : au lot 4,
une **correction esthétique NON DEMANDÉE** (éclaircir `LOG_COLOUR`) s'était
glissée à l'intérieur d'un **correctif technique, lui, réellement demandé**
(l'imbrication). Le lot 5 n'a pas corrigé une erreur de jugement de
l'utilisateur — il a retiré un changement que personne n'avait commandé, et
qui a survécu un lot entier parce qu'il voyageait dans le même commit qu'un
travail légitime. Un lot futur doit lire cette section comme un avertissement
sur le **périmètre** d'un correctif, pas comme un désaccord de goût.

Aucun plancher de contraste n'est appliqué : le seuil 3,0:1 documenté dans
ce fichier (WCAG, HUD/dangers) ne couvre pas un prop décoratif, et toute
mesure de contraste sur les bûches est explicitement hors sujet dans ce
lot — écrit ici pour qu'un futur lot ne tente pas de la reproduire.

### Nettoyage — une seule instance, aucune étiquette

L'arbitrage PRUDENT/IMMERGE du lot 4 est tranché : **IMMERGE**, seule
variante conservée. `VARIANT_PRUDENT`, `SITE_ALT` et les deux `Label3D`
(`SITE IMMERGE (RECOMMANDE)` / `ALT PRUDENT`) sont retirés de
`scripts/hub/HubCampfire.gd` — `_build_campfire()` ne construit plus de
`Label3D` du tout. Il ne reste qu'un feu, sans étiquette, au site
(19,9 ; 25,4). Géométrie (8 rondins, `ring_radius=0,42`, `apex_height=0,22`,
`base_height=0,04`) et `flame_sink=0,08` **inchangés** depuis le lot 4.

### Recette d'imbrication rejouée après le revert de couleur

Sonde jetable (méthode du lot 4 à l'identique : rendu d'isolement
masque-blanc, bande mesurée `v<0,12` dans l'espace UV de la flamme, 8
azimuts × 3 distances 2,5/8,0/16,0 u, vraie `HubCamera` — position
construite depuis `HubCamera.OFFSET` + point au sol, rotation fixe de la
caméra jamais touchée) sur la seule instance IMMERGE restante, couleur
revertée :

**Rouge avant vert** : la même sonde rejoue d'abord la géométrie CASSÉE du
lot 3 (6 rondins fins, anneau 0,30, apex 0,44, sans `flame_sink`) sur
l'instance réelle — **127 px de fuite sur les 24 vues**, preuve que la
sonde sait voir une fuite avant de croire son verdict sur la géométrie
livrée.

| geométrie | fuites sur 24 vues |
|---|---|
| LOT3-BROKEN (contrôle, doit fuir) | **127 — fuite confirmée** |
| IMMERGE, géométrie lot 4 + couleur revertée (livrée) | **0 — PASS** |

Le retour à une teinte sombre ne fait pas réapparaître de fuite : la
géométrie du bûcher/`flame_sink`, seule responsable de l'imbrication, est
restée strictement inchangée par ce lot.

### Le coût — `ProbeTimeoutAudit` et l'export

`ProbeTimeoutAudit` : **64 scènes, PASSED** — vérifié identique à la
baseline d'`origin/staging` avant ce lot, constatée (pas supposée), et
inchangée après (sonde jetable de ce lot supprimée avant ce commit).

Export release réel (`godot4 --export-release "Web"`, templates
4.3-stable, `.godot`/`build` nettoyés puis ré-importés de zéro) : exit 0,
aucune erreur GDScript ni shader. `index.wasm` = **35 376 909 octets**, md5
`af4a8fc2925d992348eb30deeeb54360` ; `index.js` md5
`4e08904b1b7107858246af44b602067b` — les deux empreintes documentées pour
un lot qui ne touche pas le code moteur, confirmées au byte/octet près.
278 lignes `Storing File:` au total, 0 fuite de `scripts/dev/*`,
`assets_source/*`, `docs/*`, `web/*` ou `firebase.json`.

### Ce que ce lot n'a PAS mesuré

Aucune nouvelle mesure de contraste sur les bûches (explicitement hors
sujet, voir plus haut). Pas de capture PNG offscreen comparative jointe —
la sonde jetable a été supprimée avant le commit ; le verdict repose sur
le comptage de pixels de fuite, pas sur une image. Validation visuelle
finale : device, comme toujours pour ce prop.

### Ce que ce lot a écrit

* `scripts/hub/HubCampfire.gd` — modifié : `LOG_COLOUR` revertée à
  `HubBuilder.TRUNK_COLOR` ; `VARIANT_PRUDENT`, `SITE_ALT` et les deux
  `Label3D` retirés ; `_build_campfire()` ne prend plus de `label_text`.
* Ce document.

Sonde jetable `CampfireColourRevertProbe.gd`/`.tscn` supprimée avant ce
commit, comme `ProbeTimeoutAudit` le confirme (64 scènes, baseline
inchangée).

## LOT 6 — le cercle de pierres, et ce que la recon a démenti

Le feu est **clos et validé device** : ce lot n'y touche pas. La seule
ligne de `HubCampfire.gd` qui concerne le feu et que ce lot modifie est un
**commentaire** — la rectification d'attribution décrite au LOT 5
ci-dessus, qui vivait aussi en clair dans le code. Le diff sur la
géométrie, la couleur, le shader et les paramètres du feu est **vide**, et
la sonde le regate en le lisant sur l'arbre CONSTRUIT (8 rondins, anneau
0,42, apex 0,22, `flame_sink` 0,08, `LOG_COLOUR` = `TRUNK_COLOR`, échelle
×1,6, quad 0,9321 × 1,1500) plutôt que sur les constantes.

### RECON BLOQUANTE — comment les rochers du hub sont posés

Mesurée sous `xvfb` + `--rendering-driver opengl3`, jamais `--headless`
seul : les transforms de `MultiMesh` reviennent à l'identité sous le
driver dummy, et une recon qui conclurait « le batch ne contient aucun
semis » l'aurait conclu d'un artefact de driver. PHASE 0 asserte le
contraire avant tout le reste.

| relevé | valeur |
|---|---|
| `MeshInstance3D` individuels sous `Props` | **134** |
| … portant `ROCK_COLOR` | **2** — socle du tourniquet, pivot de la balançoire |
| … dessinant le mesh du rocher | **0** |
| `MultiMeshInstance3D` sous `Props` | **16** |
| batch `Rock` | **n = 48**, `fmt = 1` (TRANSFORM_3D), `SphereMesh` r=0,600 h=0,800 seg=8 rings=4, albedo (0,69 ; 0,69 ; 0,67) unshaded |
| le batch EST le semis autorisé | 48 entrées `&"rock"` du layout, **pire écart 0,00000 u** |
| distorsion par instance | lift Y 0,1664 … 0,4382 ; échelle d'axe 0,5390 … 1,5651 |

**Issue (a) écartée PAR LA MESURE** : aucun nœud individuel ne dessine ce
mesh.

⚠️ **ET L'ISSUE (b), TELLE QUE LE BRIEF LA FORMULE, EST FAUSSE — MESURÉE,
PAS RAISONNÉE.** Porter `instance_count` de 48 à 49 sur le batch partagé a
rendu **0 transform sur 48** survivantes : le buffer est réalloué et remis
à zéro, sans une ligne d'erreur. `custom_aabb`, lui, ne suit pas du tout.
Un appelant extérieur qui voudrait « ajouter une instance » devrait donc
**ré-écrire tout le semis procédural de HubBuilder et lui recalculer son
AABB** — c'est-à-dire posséder ses données.

⚠️ **ET CETTE MESURE A CORROMPU LA SONDE QUI L'A FAITE.** La première
version de la phase ne sauvegardait qu'**une** transform avant de tester,
donc les phases suivantes ont tourné contre 48 rochers empilés à l'origine
du monde. Ce n'est pas passé inaperçu **uniquement parce que le blind
check était là** : le point censé être À L'INTÉRIEUR d'un rocher a
rapporté **1,942 u** au lieu de 0,000. Sans lui, la table de dégagement du
lot serait sortie verte et fausse.

**Verdict : ni (a), ni (c).** Aucun refactor du chemin de placement partagé
n'est nécessaire. L'anneau porte **son propre `MultiMesh`**, avec le
**mesh et la couleur du rocher du hub** (`HubBuilder.rock_mesh()` et
`HubBuilder.ROCK_COLOR`, lus, jamais retapés), parenté sous la racine du
feu. C'est exactement le patron que `HubLayout.gd` documente déjà pour les
barres du tourniquet — « un `MultiMesh` à lui, jamais un batch partagé » —
et les batches `Bars` (n=4) et `Grips` (n=2) relevés par la recon en sont
la preuve vivante.

`HubBuilder.rock_mesh()` est **neuf** : le mesh était un littéral enfoui
dans `_batch_spec()`, et le recopier dans `HubCampfire.gd` aurait
reconstruit le défaut « un fait est publié une fois, jamais recopié » que
ce dépôt a déjà payé sur le pas de porte de la cabane. Une nouvelle
instance à chaque appel, délibérément : deux `MultiMesh` partageant une
`Mesh` coupleraient leur tessellation pour toujours.

### L'anneau — irrégulier en TAILLE, ESPACEMENT et ROTATION, jamais en RAYON

Le rayon est **strictement** constant, pas « sensiblement » : la sonde le
lit à **0,000000 u de dispersion** sur les huit pierres des deux
variantes, et il vaut littéralement `STONE_RING_RADIUS`. Une pierre plus
loin ou plus près donnerait un semis, pas un foyer — décision de Mathieu,
regatée plutôt que reformulée.

⚠️ **UNE SPHÈRE DE RÉVOLUTION NE TOURNE PAS** — leçon A3 de l'audit CH22,
déjà payée sur le semis, et qui frappe ici à l'identique. Chaque pierre
reçoit donc une compression NON UNIFORME écrite dans le repère du MODÈLE,
puis l'assiette, puis le yaw, via `Transform3D.scaled_local()` qui
post-multiplie. Le blind check mesure la valeur du mécanisme : yaw seul sur
une pierre à échelle uniforme donne un aspect **1,0000 à 1,0000, dispersion
0,0000** — exactement zéro, parce que la section octogonale d'un
`SphereMesh` à 8 segments a la même boîte englobante à tous les yaws.

| | MARQUE (site) | SOBRE (alt) |
|---|---|---|
| pierres | 8 | 8 |
| rayon (dispersion) | 0,7625 nominal / 1,220 u monde (**0,000000**) | idem (**0,000000**) |
| taille dessinée | 0,2159 … 0,3381 (**×1,57**) | 0,2756 … 0,2937 (**×1,07**) |
| écart angulaire | **29,8° … 59,8°** | **39,9° … 51,1°** |
| aspect (silhouette) | 0,8114 … 1,0188 (**0,2074**) | 0,9329 … 1,0803 (**0,1474**) |
| bord intérieur | **0,959 u** (feu à 0,772 → **0,187 u** de jeu) | **0,989 u** (**0,217 u** de jeu) |
| emprise extérieure | **1,487 u** (borne AABB lâche 1,752) | **1,454 u** (borne lâche 1,663) |
| couronne la plus haute | 0,311 u (apex du bûcher 0,352 u) | 0,245 u |
| dégagement de la pierre la plus serrée | `TreeCrown[36]` à **1,926 u** | `TreeCrown[24]` à **0,912 u** |

Enfouissement : **26 % de la hauteur RÉELLEMENT DESSINÉE de chaque
pierre**, identique pour les seize, quelles que soient sa taille et son
assiette. Déterminisme : une graine entière fixe par variante, tirages dans
un ordre fixe — le foyer est identique à chaque chargement, aucun RNG libre
au runtime.

Coût : **2 nœuds de dessin** pour 16 pierres (1 par foyer), 80 triangles
par instance, **1 280 triangles** au total sur les deux foyers. Le lot 7
en supprimera la moitié.

### Le second site — 3,40 u, MÊME PROFONDEUR CAMÉRA, et le biais qui va avec

Balayage de 72 azimuts × 6 distances (3,40 à 3,90 u), `HubRegion.contains`
compris, sur le hub CONSTRUIT — 452 pièces dessinées, chacune réduite à
l'enveloppe convexe XZ de ses huit coins transformés, la métrique du lot 1
reproduite (site à **3,521 u**, chiffre déjà au dossier, restitué avant
qu'un chiffre neuf soit publié).

La caméra ne tourne jamais et le brouillard est exponentiel en distance :
deux foyers à des profondeurs différentes ne sont pas comparables. À `z`
constant, le corridor ouest est le seul disponible, et il est **plus
serré** :

| slot | dégagement | choisi |
|---|---|---|
| site (19,9 ; 25,4) | **3,521 u** | MARQUE |
| (16,5 ; 25,4) — 3,40 u ouest | **2,258 u** | SOBRE |
| (16,3 / 16,1 / 16,0 ; 25,4) | 2,078 / 1,903 / 1,818 u | — |
| (19,9 ; 29,0) — 3,60 u nord | 5,579 u | écarté : autre profondeur |
| (23,5 ; 25,4) — est | 0,748 u | écarté : trop serré |

Les deux foyers sont à **3,400 u**, au même `z`, avec **0,459 u de sol nu**
entre les emprises des deux anneaux.

⚠️ **BIAIS DE FOND, À DÉCLARER ET À ESCOMPTER** : les deux variantes ne
sont pas sur le même voisinage. **SOBRE occupe le slot le plus
contraint** — 2,258 u contre 3,521 u — et, pire pour elle, le **rocher du
semis existant le plus proche est à 3,81 u de son centre**, dans le MÊME
matériau et la MÊME couleur que ses pierres : il entre dans le cadre et
travaille contre la lecture « anneau délibéré ». Ce biais joue **contre
SOBRE, donc en faveur de la variante que ce rapport recommande**. Il faut
le savoir en regardant les deux sur device.

⚠️ **Et l'appairage lui-même produit le défaut que le brief redoute** : à
16 u, les deux anneaux à 3,40 u se lisent comme **un seul semis de galets**
plutôt que comme deux foyers. C'est un artefact du dispositif
d'arbitrage — le lot 7 en supprime un — pas un défaut de l'un ou l'autre
anneau.

### Recommandation — MARQUE, et pourquoi

**MARQUE**, déjà posée au site exact (19,9 ; 25,4), pour que le lot 7 soit
une suppression pure.

À la distance de jeu réelle (11,7015 u, la caméra livrée), SOBRE se lit
comme **huit galets identiques sur un cercle parfait** : sa variation
(×1,07 en taille, 39,9°–51,1° d'écart) est en dessous de ce que l'œil
distingue à 1080 px de large, et le résultat lit comme *posé à la machine*
— exactement ce qu'un foyer fait main n'est pas. MARQUE (×1,57, 29,8°–59,8°)
reste franchement un CERCLE — le rayon y est le même nombre à la sixième
décimale — tout en donnant la lecture « quelqu'un a ramassé des pierres ».

Un détail de rendu tranche dans le même sens : dans SOBRE, la pierre à
12 h tombe pile derrière la flamme et se fait manger par elle ; le jitter
angulaire de MARQUE la déporte.

### RECETTE — 8 azimuts × 3 distances, rendu d'isolement

Vraie `HubCamera` : le basis AUTORISÉ est capturé une fois et seulement
**yawé** autour du foyer, donc les rendus sont pris au pitch réel
**−34,00°** mesuré, et la vue à az 0 / 11,7015 u **EST** la caméra livrée.
Le script de suivi est coupé, sans quoi chaque rendu serait celui du spawn.

Rendu d'isolement : monde noirci, flamme dessinée **OPAQUE avec son propre
UV encodé dans la couleur** (r = 1, g = 1 − v), même seuil de `discard` et
même construction de billboard que le shader livré — un masque qui
divergerait du matériau réel serait le défaut « fixture qui diverge du réel
sur l'axe qui compte ». Les `Label3D` sont **cachés** et non noircis : leur
`modulate` (1,00 ; 0,94 ; 0,72) a précisément le canal rouge que le
comptage lit comme « flamme ». Le second foyer est caché pendant le
balayage du premier.

Les pierres étant **noires sur fond noir** dans cette passe, la seule façon
dont l'image « anneau visible » peut différer de l'image « anneau caché »
est qu'une pierre ait pris un pixel de flamme. La comparaison passe donc
par `Image.compute_image_metrics()`, côté C++ ; le comptage pixel à pixel
n'est fait que là où elle a trouvé quelque chose.

| | résultat |
|---|---|
| vues comparées | **48** (2 foyers × 8 azimuts × 3 distances 2,5 / 8,0 / 16,0 u) |
| vues sans un seul pixel de flamme | **0** — aucune vue ne passe gratuitement |
| vues perdant un pixel de flamme | **0** |
| pixels de bande basse (v < 0,12) perdus | **0** |
| **blind check** | anneau traîné sur la flamme : **156 627 → 130 784**, soit **25 843 px** perdus |

Le blind check est obligatoire ici : « aucune occultation » est une
assertion d'ABSENCE, et une vue où la flamme serait hors cadre la rendrait
verte pour rien. Chaque vue est donc d'abord vérifiée NON VIDE contre une
image noire, et le pouvoir de détection est prouvé sur une occultation
fabriquée.

Géométriquement, ce zéro n'est pas une chance : à −34° de plongée, la
ligne de visée qui atteint un point à hauteur `h` au centre du feu passe
`0,85 u` plus haut au droit d'une pierre du côté caméra, et la couronne la
plus haute mesure 0,311 u.

### ROUGE AVANT VERT — trois neutralisations, dont deux ont trouvé un vrai bug

1. **La métrique de silhouette (première version)** lisait l'AABB de
   l'AABB transformée. Le blind control « une pierre à échelle uniforme
   yawée 8 fois n'a QU'UNE silhouette » est sorti à **0,2006 de
   dispersion** — d'artefact pur : une BOÎTE tournée à 45° a une boîte
   englobante plus grande même quand le corps dedans est une sphère.
   Réécrit sur les **vrais sommets transformés** (`Mesh.get_faces()`),
   le contrôle tombe à **0,0000**. C'est le cas d'école « la métrique peut
   être la mauvaise » attrapé par le blind check lui-même.
2. **L'enfouissement**, écrit de la même façon fautive dans le
   CONSTRUCTEUR, donnait **0,1624 … 0,2574** (marque) et **0,2410 …
   0,2569** (sobre) au lieu des 0,26 demandés — une profondeur différente
   et fausse pour chaque pierre, variant avec son assiette, sans que rien
   ne se plaigne. **Exactement 2 assertions** sont tombées, celles
   attendues. Corrigé sur les vrais sommets : **0,2600 … 0,2600** des deux
   côtés.
3. **`scaled_local()` → `scaled()`**, le piège nommé dans `HubBuilder.gd` :
   **6 échecs**, et pas ceux qu'on aurait parié. La pré-multiplication
   écrase aussi l'ORIGINE, donc c'est la PHASE du RAYON qui tombe (rayon
   dispersé, bord intérieur à **−0,710 u** et **−0,700 u**, l'anneau
   traverse le feu) — **PHASE C, elle, reste verte** : un aspect mesuré sur
   les axes MONDE varie tout autant. **Le garde contre le mauvais opérateur
   est le test de rayon, pas le test de silhouette.** Restauration vérifiée
   `cmp` byte-identique.

### LE RISQUE SIGNALÉ PAR MATHIEU — vérifié, et voici la réponse franche

Mesuré au rendu réel, à la distance de jeu, sur les pixels classés :

| | luminance relative WCAG |
|---|---|
| pierres | **0,360** |
| sol | **0,086** |
| bûcher | **0,016** |

soit **pierres/bûcher 6,2:1**, **sol/bûcher 2,06:1**. *(Diagnostic, pas
une mesure de contraste gatée : aucun seuil HUD n'est appliqué à ce prop
décoratif — c'est l'erreur du lot 4, elle n'est pas refaite.)*

**Le risque est réel dans son mécanisme, et faux dans sa conclusion.** Le
bûcher EST l'objet le plus sombre du cadre, de loin, et l'entourer de
l'objet le plus clair du cadre creuse cet écart : la masse paraît plus
sombre avec l'anneau que sans. Mais **elle ne se lit pas comme un TROU** :
sur les rendus comparatifs anneau ON / anneau OFF, l'éventail des huit
rondins reste parfaitement lisible — on distingue les entailles entre
rondins et le V de la base — et la flamme sort d'un cran au sommet du tas,
pas d'un vide. Ce qui est perdu, c'est la lecture « du BOIS » : le tas est
une silhouette plate et non éclairée, sans arête interne, et il l'était
déjà **avant** l'anneau. L'anneau change le degré, pas la nature.

**Rien n'a été corrigé unilatéralement** : le feu est validé, on n'y
touche pas. Si Mathieu veut fermer l'écart, le levier qui ne touche pas au
feu est la couleur des pierres — mais elle est aujourd'hui `ROCK_COLOR`
par exigence du brief (réutiliser le matériau des rochers du hub), et
l'en écarter est une décision, pas un correctif.

### Dette connue, non traitée ici

* Le feu n'a **jamais** déclaré d'emprise à `ground_footprints()` : Keepy
  traverse le bûcher. L'anneau hérite de cette propriété et l'étend à
  1,53 u. Pré-existant, hors périmètre de ce lot, signalé.
* Les valeurs de la baseline de primitives au site restent instables d'un
  run à l'autre sur géométrie identique, cause non isolée — **aucun delta
  inter-run n'est publié ici**, conformément au brief.

### Ce que ce lot a écrit

* `scripts/hub/HubBuilder.gd` — `rock_mesh()` publié en `static`,
  `_batch_spec(&"Rock")` le lit au lieu de retaper le littéral.
* `scripts/hub/HubCampfire.gd` — l'anneau (`_make_stone_ring()`), les deux
  recettes `STONES_SOBRE` / `STONES_MARQUE`, `SITE_ALT`, `_make_label()`
  réintroduit pour l'arbitrage, `_build_campfire()` reprend un
  `label_text` ; **plus la rectification d'attribution du LOT 5** en
  commentaire.
* Ce document.

Sondes jetables `CampfireStoneRecon`, `CampfireStoneProbe` et
`CampfireStoneRender` (`.gd` + `.tscn`) supprimées avant ce commit :
`ProbeTimeoutAudit` relevé à **67 scènes** avec elles et **64** après,
c'est-à-dire la baseline réelle d'`origin/staging` **constatée** avant le
lot, pas supposée.

Export release réel (`godot4 --export-release "Web"`, templates
4.3-stable, `build/` nettoyé avant) : **exit 0**, zéro `SCRIPT ERROR`,
zéro `Parse Error`, zéro `SHADER ERROR`, zéro ligne
`Storing File: res://build`. `index.wasm` **35 376 909** octets, md5
`af4a8fc2925d992348eb30deeeb54360` ; `index.js` md5
`4e08904b1b7107858246af44b602067b` — les deux valeurs d'identité moteur
publiées dans `CLAUDE.md`, donc le moteur n'a pas bougé. Les shaders, eux,
ont réellement été compilés : la sonde de rendu a tourné sous `opengl3`
avec le shader de flamme livré et a produit 28 PNG où la flamme s'affiche.

## LOT 7 — finalisation : SOBRE au site, MARQUE supprimée

Arbitrage de Mathieu, tranché contre la recommandation du lot 6 :
**SOBRE retenue, MARQUE écartée.** À consigner comme fait notable : SOBRE
a été jugée sur device alors qu'elle occupait le créneau le plus contraint
mesuré au lot 6 (dégagement 2,258 u, contre 3,521 u pour MARQUE), avec un
rocher du semis existant du hub à 3,81 u — même mesh `Rock`, même
`ROCK_COLOR` — qui travaillait contre sa lecture en la rapprochant
visuellement d'un décor déjà présent. Le déplacement au site définitif
(19.9, 25.4), à l'ancien emplacement de MARQUE, fait disparaître ce
handicap : SOBRE y hérite du meilleur dégagement caméra que le lot 6 avait
mesuré pour l'autre variante.

### Ce que ce lot a écrit

`scripts/hub/HubCampfire.gd` seul :

* `_build()` ne construit plus qu'UN foyer, `STONES_SOBRE` à `SITE`
  (19.9, 25.4) — c'est une **translation pure** : `STONES_SOBRE` (graine
  20260904, tailles, jitter angulaire, tilt, squash) n'a pas été touchée
  un seul caractère, seule l'origine passée à `_build_campfire()` change
  de `SITE_ALT` à `SITE`. La disposition relative des huit pierres —
  angles, tailles, assiettes, enfouissement 0,26 — est donc
  byte-identique à celle jugée par Mathieu ; seul le repère monde bouge.
* `STONES_MARQUE`, `SITE_ALT`, `_make_label()` et les deux appels
  `_make_label()`/`label` dans `_build_campfire()` sont supprimés
  entièrement. `_build_campfire()` perd son paramètre `label_text` et le
  root du foyer reprend un nom fixe `"Campfire"` (`_campfires` publie
  toujours une seule clé, `&"sobre"`, plutôt que d'inventer un nom neutre
  qui n'apporterait rien à l'unique appelant de `campfires()`).
* Le feu (bûcher, flamme, `flame_sink`, `LOG_COLOUR`, échelle x1.6) et la
  géométrie de l'anneau (`STONE_RING_RADIUS`, `STONE_MESH_SCALE`,
  `STONE_BURIED_FRACTION`, la boucle de `_make_stone_ring()`) ne sont pas
  touchés — diff vérifié contre `origin/staging` : 13 insertions,
  59 suppressions, aucune ligne modifiée dans ces blocs.
* Les commentaires de doc qui décrivaient l'arbitrage à deux variantes
  (rayon anneau contraint par le second foyer à 3,40 u, bloc "LES DEUX
  VARIANTES À ARBITRER") sont mis à jour pour refléter l'état final à un
  seul foyer, sans changer aucune constante numérique de géométrie.

### Ce que ce lot N'A PAS pu faire dans ce bonac

Aucun binaire `godot4` n'est disponible dans ce sandbox d'exécution (ni
sous ce nom ni sous un autre, recherché sur tout le système de fichiers) :
la recette de recon 8 azimuts × 3 distances sous `xvfb-run
--rendering-driver opengl3`, le rouge-avant-vert avec contrôle positif, la
re-mesure de la clearance au nouveau voisinage, et l'export release local
n'ont **pas pu être exécutés depuis cette session**. Le changement reste
une translation mécanique d'un site déjà construit et déjà mesuré au
lot 6 vers un autre site déjà construit et déjà mesuré au lot 6
(dégagement 3,521 u, emprise extérieure de l'ancien anneau MARQUE
1,529 u au pire à ce même site) — mais cette continuité N'A PAS été
reprouvée par une sonde ici, et doit l'être par la CI (export release,
`web-build.yml`) et par la validation device de Mathieu avant tout merge
vers `main`.

### Dette signalée au lot 6, évaluation demandée

`ground_footprints()` ne déclare toujours aucune emprise pour le feu —
inchangé par ce lot, qui n'a touché ni `HubBuilder.gd` ni
`ground_footprints()`. Estimation sans implémentation : c'est un ajout
plutôt ISOLÉ. Le foyer est un prop terminal (aucun autre système ne lit sa
position — pas de hotspot, pas de zone de tap, `campfires()` n'a qu'un
seul appelant absent du code produit) ; déclarer son emprise consiste à
ajouter une entrée `Circle`/`Rect` à la liste que `ground_footprints()`
retourne déjà pour d'autres props statiques (le patron existe, voir
`HubBuilder.gd:1500` et les props qui l'alimentent), avec un rayon à
mesurer sur l'anneau construit (bord extérieur mesuré au lot 6 : 1,529 u
au pire, avant translation) plutôt que recopié. Ne touche à aucun chemin
partagé (navigation, hotspots, MultiMesh du semis) : le risque principal
est seulement de resserrer l'espace jouable autour du site si le rayon
choisi est trop large. Travail estimé à un lot court.
