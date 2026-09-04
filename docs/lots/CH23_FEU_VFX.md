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
