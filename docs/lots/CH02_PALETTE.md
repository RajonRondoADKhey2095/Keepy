# Palette marécage — direction artistique permanente et SwampPalette

> Extrait de `CLAUDE.md` par le LOT H (2 septembre 2026), **verbatim** : aucune ligne réécrite, résumée ni supprimée.
> 3 section(s), 535 lignes d'origine.
> Doctrine permanente : voir `CLAUDE.md`. Index des chantiers : `docs/lots/INDEX.md`.

## DIRECTION ARTISTIQUE PERMANENTE : le marécage n'est plus une phase (11 août 2026)

Branche `claude/swamp-permanent-art-direction-vw2pev`, partie de `staging`
(`0e633fa`). **Changement de direction artistique global, validé
explicitement par Mathieu.** Le lot précédent avait fabriqué une ambiance
marécage nocturne et la faisait apparaître au bout de 18 s par-dessus une
scène diurne. Ce lot supprime la scène diurne : **le marécage EST le jeu,
dès la première frame de la première run.**

**Le ciel bleu (`0.55, 0.75, 0.95`) et la piste pastel (`0.55, 0.42, 0.32`)
n'existent plus dans aucun état du jeu**, écran-titre compris — c'est
mesuré et *gaté*, pas affirmé (voir `SwampIdentityAudit` plus bas).

### Le grade plein écran est SUPPRIMÉ — deux raisons mesurées, pas une préférence

`assets/shaders/swamp_grade.gdshader` et le `ColorRect` qui le portait sont
supprimés. `scripts/world/DarkModeEffect.gd` devient
`scripts/world/SwampAtmosphere.gd`, un simple `Node` qui n'écrit plus que
trois propriétés d'`Environment`. Rien ne post-traite la frame désormais :
**la couleur écrite EST la couleur vue**, littéralement, sans shader entre
les deux.

1. **Il détruisait la teinte par construction.** Mesuré sur l'arbre de
   départ (`DarkPaletteAudit`, baseline conservée) : les six hazards que le
   joueur doit distinguer d'un coup d'œil rendaient tous le MÊME olive, à
   la valeur près — DODGE `(0.19,0.25,0.16)`, STOMPER `(0.17,0.22,0.15)`,
   CHARGER `(0.24,0.30,0.19)`, ENEMY `(0.26,0.33,0.21)`, JUMP
   `(0.28,0.34,0.22)`, AIR_ENEMY `(0.31,0.37,0.24)`. Une barrière rouge, un
   charger rose vif et un stomper bleu étaient la même couleur. C'est
   inhérent à une rampe indexée sur la luminance (l'en-tête du shader le
   disait), et c'est ce qui plafonnait la pire paire hazard-vs-sol à
   **1,46:1** avec un meilleur cas balayé de 1,70:1.
2. **Il coûtait une passe plein écran tant qu'il était allumé.** Le shader
   échantillonnait `hint_screen_texture`, ce qui force sur le renderer
   Compatibility une copie du framebuffer entier plus une passe fragment
   plein écran. Le rendre permanent, c'était payer ça à chaque frame de
   chaque run, sur mobile web, pour un rendu que des constantes atteignent
   gratuitement.

### Le cycle survit, mais comme RESPIRATION — plus jamais comme identité

Le brief laissait le choix entre neutraliser le cycle et le garder en
variation subtile. **Gardé**, parce que c'était le moins cher : le
supprimer imposait d'arracher la machine à états de `GameState` et de
réécrire toutes les sondes qui mesurent ses deux bouts, alors que changer
ce qu'il PILOTE est un diff plus petit.

Le vocabulaire suit le sens (précédent maison : `InvertCapture` →
`SwampGradeCapture`, renommée parce qu'un nom qui ment est un piège) :
`dark_intensity` → **`mist_intensity`**, `DarkPhase{DARK,LIGHT}` →
**`MistPhase{DEEP,SHALLOW}`**, `DARK_*` → `MIST_*`, `_update_dark_cycle` →
`_update_mist_cycle`. ~100 occurrences, 12 fichiers, vérifié par `grep`
résiduel vide + sondes rejouées.

⚠️ **La respiration ne touche QUE le fond**, et c'est ce qui la rend
acceptable là où un grade permanent ne l'était pas : elle bouge
`background_color`, `fog_light_color` et `fog_density`. `fog_sky_affect`
vaut 0.0 et la zone de jeu est à quelques mètres de la caméra, où le
brouillard à ces densités n'apporte presque rien. **Aucun contraste
gameplay ne peut donc bouger avec elle** — et c'est vérifié, pas supposé :
`DarkPaletteAudit` mesure désormais les DEUX bouts et les deux colonnes
sont identiques à ±0,02.

### Contrastes : 4 hazards sur 6 passent 3,0:1, contre 0 sur 6 avant

⚠️ **Arithmétique à connaître avant de retoucher une couleur.** Le sol rend
à **luminance relative 0,153**. Contre lui, franchir 3,0:1 exige d'être
soit **≥ 0,559** (nettement brillant), soit **≤ 0,018** (quasi noir).
**Tout ce qui atterrit entre les deux est sous le plancher, quelle que soit
sa teinte** — la teinte survit maintenant, mais elle ne compte pour RIEN
dans le ratio WCAG. C'est la règle qui remplace « mets le contraste dans
l'asset » (qui était la règle de l'inversion).

| objet | avant ce lot | après | ce qui a changé |
|---|---|---|---|
| DODGE | 1,72 | **3,28** | rouge moyen → silhouette quasi noire |
| JUMP | 1,39 | **3,23** | brun → ambre vif, passé **unshaded** |
| STOMPER | 1,14 | **3,36** | bleu profond → bleu glacier pâle |
| CHARGER | 1,45 | **3,15** | magenta → rose vif pâle |
| ENEMY | 1,47 | 1,47 | inchangé — voir ci-dessous |
| AIR_ENEMY | 1,14 | 1,14 | inchangé — voir ci-dessous |
| NOISETTE | 2,35 | 2,35 | rapporté, jamais gaté |
| GLAND | 4,47 | 4,47 | rapporté, jamais gaté |

⚠️ **La colonne « après » ci-dessus est celle du lot ART DIRECTION
(albédos hazards + suppression du grade), PAS la valeur actuelle.** La
saturation pass du même jour (section « AJUSTEMENT SATURATION » plus bas)
a aussi changé l'albédo du SOL, ce qui déplace ces quatre ratios une
seconde fois sans toucher aux albédos hazards eux-mêmes : DODGE 3,28→3,19,
JUMP 3,23→3,28, STOMPER 3,36→3,41, CHARGER 3,15→3,20 — tous restent au-dessus
de 3,0:1, avec plus de marge sur CHARGER qu'avant. Chiffres et HSV complets
dans cette section.

⚠️ **`ENEMY` et `AIR_ENEMY` sont mesurés dans leur teinte d'ALARME, pas au
repos, et les libellés `(resting)` de la sonde sont FAUX là-dessus.** À la
distance de capture la rampe d'alarme (`Obstacle.ENEMY_ALARM_ALBEDO`,
`0.95,0.08,0.12`) a entièrement repris la main sur le matériau : ces deux
lignes mesurent le télégraphe rouge, pas l'albédo de base, et changer la
couleur de base ne les bouge quasiment pas. Ce rouge est pauvre en
luminance contre un sol olive. **Les remonter, c'est retoucher le
TÉLÉGRAPHE, pas l'art — décision gameplay, elle appartient à Mathieu.** Le
mauvais libellé est pré-existant ; signalé plutôt que corrigé en douce,
parce que les chiffres en dessous sont réels.

⚠️ **Le CHARGER est le cas où teinte et luminance se contredisent.** Son
magenta `(1.00,0.15,0.62)` mesurait 1,45:1 — pas un raté de réglage mais
une propriété du magenta, qui n'a pas de canal vert et ne peut donc pas
être lumineux. C'est le SEUL hazard fatal. L'argument qui a tranché est
l'accessibilité : pour un deutéranope, magenta contre olive est exactement
la paire confusable, et il ne reste que la luminance.

### Ce que ce lot FERME au passage

**`PursuerContrastAudit` PASSE** — silhouette **4,13:1** (shallow) et
**4,06:1** (deep) contre un plancher de 2,5:1. Cette sonde échouait sur
`origin/main` intact (6/6 palettes sombres sous le plancher, pire 1,86:1),
puis était INCONCLUSIVE en sandbox. **La décision de teinte ouverte depuis
le 9 août — « pursuer vs sol en DARK/2 à 2,37:1, il faut bouger l'albédo du
sol ou `DARK_TINT_AMOUNT` » — est SANS OBJET** : les deux variables qu'elle
nommait n'existent plus sous cette forme, et le chiffre est passé de 2,37 à
4,06 sans qu'on touche à l'albédo du poursuivant.

⚠️ **MàJ 11 août 2026, saturation pass (même jour) : 4,05:1 / 3,99:1 —
toujours PASS, marge confortable contre le plancher 2,5:1.** Voir la
section « AJUSTEMENT SATURATION » plus bas.

### `SwampIdentityAudit` — nouvelle sonde GATÉE, remplace `SwampGradeCapture`

`SwampGradeCapture` mesurait quatre propriétés du grade ; le grade
n'existant plus, ses quatre questions expirent d'un coup — exactement comme
son propre en-tête racontait `InvertCapture` expirant un cran plus tôt.
Remplacée, pas rafistolée.

Elle asserte le critère d'acceptation réel du brief : **aucun état du jeu ne
rend une frame bleue ou pastel**. Cinq états échantillonnés, trois
assertions chacun (vert dominant / saturé / sombre) :

| état | rgb moyen | luma | sat |
|---|---|---|---|
| WORLD AT TITLE | `0.245, 0.281, 0.117` | 0,261 | 0,58 |
| **TITLE SCREEN** | `0.084, 0.110, 0.078` | 0,102 | 0,30 |
| RUN OPENING (mist 0,00) | `0.245, 0.281, 0.117` | 0,261 | 0,58 |
| RUN DEEP MIST (mist 1,00) | `0.231, 0.262, 0.105` | 0,244 | 0,60 |
| GAME OVER | `0.245, 0.281, 0.117` | 0,261 | 0,58 |

`SWAMP_IDENTITY_VERIFIED=yes`.

⚠️ **MàJ 11 août 2026, saturation pass (même jour) : ces cinq lignes sont
DÉPASSÉES.** Retour device le jour même : « lit comme du noir légèrement
teinté, pas comme du vert ». Nouvelles valeurs et diagnostic (saturation,
pas luminosité) dans la section « AJUSTEMENT SATURATION » plus bas — la
ligne TITLE SCREEN, la plus basse en saturation ici (0,30), est celle qui
bouge le plus (0,58 après).

**L'écran-titre est chargé pour de vrai**
(`TitleScreen.tscn` est une scène séparée que `Game.tscn` ne contient pas) :
c'est l'endroit le plus probable pour que le look diurne survive sans être
vu — première chose que voit le joueur, dernière que regarde une sonde 3D.

### Deux pièges de sonde rencontrés — à connaître

⚠️ **`--headless` FORCE le driver de rendu DUMMY et écrase
`--rendering-driver opengl3`, en silence.** `get_image()` rend alors une
surface vide : tous les échantillons lisent `(0,0,0)`, tous les ratios
calculent 1,00:1, **et la sonde SORT EN 0**. Faux vert complet, rencontré
pour de vrai sur la première mesure de ce lot. Même famille que le piège
d'ordre des flags déjà documenté, sur un autre flag. Toute sonde qui lit
des pixels se lance **sans `--headless`**, sous `xvfb-run`.

⚠️ **Une sonde dont le SCRIPT ne PARSE pas ne tombe pas vite : elle traîne
jusqu'au timeout.** Une erreur de parse GDScript empêche la scène de se
charger, donc `ProbeWatchdog.arm()` n'est **jamais atteint** — il n'y a pas
de watchdog du tout, et le process tourne à vide (15 min observées ici).
`ProbeTimeoutAudit` garantit qu'une sonde ARME un timeout, pas qu'elle
COMPILE. Parade adoptée : un `--headless --quit-after 2` sur la scène de la
sonde avant tout run long, qui fait apparaître `Parse Error` en quelques
secondes.

### `DarkPaletteAudit` : la scène de calibration est LUE, plus copiée

La sonde tenait des copies à la main des couleurs des scènes livrées
(`GROUND_ALBEDO`, `SKY_COLOR`, plus l'ambiante et la lumière reconstruites
en dur), avec un commentaire affirmant que copier « depuis la sous-ressource
exacte » protégeait de la dérive. **C'est l'inverse, et ce lot l'a pris sur
le fait** : après le changement de palette, la sonde a rendu sa propre scène
diurne et rapporté un sol pastel et un ciel BLEU, à pleine confiance, run
vert et code de sortie 0, contre un build où ni l'un ni l'autre n'existait.
Elle lit désormais l'`Environment`, la `DirectionalLight3D` et le matériau
du sol dans les `.tscn` livrés via `PackedScene.get_state()` (même astuce
que `TrackSegment._shared_model`). Plus aucune copie.

### Ce qui n'a PAS bougé

Géométries, colliders, spawn logic, gameplay, timings du cycle
(`MIST_FIRST_TRIGGER_S` 18 s, `MIST_CYCLE_PERIOD_S` 10 s,
`MIST_FADE_DURATION_S` 0,8 s), `_PROP_KIND_WEIGHTS`, les flux `DecorRng`,
l'albédo du poursuivant, les textures des billboards (re-teintées par
`modulate`, pas ré-exportées).

### RESTE À VALIDER SUR DEVICE — le seul juge

Aucune sonde ne dit que c'est BEAU. Ce qui doit être regardé sur téléphone :
est-ce que ça se lit comme un marécage, est-ce que la piste guide l'œil
sans éclairer la scène, et surtout **est-ce que les 4 hazards re-coloriés
restent lisibles à vitesse réelle** — `JUMP` en ambre vif et `GLAND` en
jaune sont désormais deux objets brillants et chauds, distingués par la
FORME (boîte basse large vs sphère qui flotte et tourne) et non plus par la
couleur. C'est le risque de ce lot, et il n'est pas mesurable ici.

## AJUSTEMENT SATURATION PALETTE MARÉCAGE (11 août 2026, retour device)

Branche `claude/keepy-swamp-palette-saturation-ajuzus`, partie de `staging`
(`1a6bce9`, la même base que la « DIRECTION ARTISTIQUE PERMANENTE »
ci-dessus). **Retour device le jour même du lot précédent** : « le rendu lit
comme du NOIR légèrement teinté, pas comme du vert — un peu trop sombre en
plus ». Ce lot NE touche à aucune géométrie, collider, RNG de gameplay ou
timing — uniquement des couleurs, sur les surfaces que Mathieu a listées :
ciel, brume, sol/piste, curbs, tint des trois couches de décor.

### Diagnostic vérifié AVANT tout changement de code, pas supposé

Hypothèse du retour device : ce n'est pas un problème de LUMINOSITÉ mais de
SATURATION — à luma 0,10-0,26 avec une saturation faible, l'œil lit du gris
avant de lire une teinte. Mesuré en HSV sur les valeurs livrées par le lot
précédent :

| surface | H (raw) | S (raw) | V (raw) |
|---|---|---|---|
| `SWAMP_SKY` | 111° | 0,35 | 0,08 |
| `SWAMP_HAZE` | 92° | 0,31 | 0,22 |
| Sol/piste (albédo) | **66°** | 0,46 | 0,44 |
| Curbs | 66° | 0,30 | 0,74 |

Le sol était le pire cas : H=66° place sa teinte pile entre jaune (60°) et
vert (120°), avec R=0,42 quasi égal à G=0,44 (ratio R/G=0,95) — c'est un
olive jaunâtre, pas un vert, exactement le diagnostic du retour device. Le
ciel et la brume avaient déjà une teinte verte correcte (92-111°) mais une
saturation et une valeur trop basses pour porter cette teinte à l'écran —
`SWAMP_SKY` à V=0,08 est la ligne la plus sombre et la moins saturée de
toute la palette, et c'est très probablement ce que l'écran-titre et les
18 premières secondes de chaque run montrent en premier.

### Ajustement — saturation d'abord, teinte vers le vert franc, luminosité en dernier

Tenu dans cet ordre, comme demandé : la saturation est montée nettement
partout, la teinte a été recentrée sur ~105° (la même famille que les
autres verts déjà en place dans le jeu — arbre mort, rocher, buisson,
collines), et la luminosité n'a bougé que là où l'espace le permettait
(voir la contrainte hazards ci-dessous, qui a directement limité de
combien le sol pouvait remonter en valeur).

| constante | avant (raw) | après (raw) | H | S | V |
|---|---|---|---|---|---|
| `GameState.SWAMP_SKY` | `0.055,0.078,0.051` | `0.062,0.115,0.044` | 105° | 0,62 | 0,12 |
| `GameState.SWAMP_HAZE` | `0.180,0.216,0.149` | `0.151,0.260,0.114` | 105° | 0,56 | 0,26 |
| `GameState.SWAMP_SKY_DEEP` | `0.031,0.047,0.031` | `0.035,0.068,0.024` | 105° | 0,64 | 0,07 |
| `GameState.SWAMP_HAZE_DEEP` | `0.122,0.153,0.102` | `0.107,0.190,0.080` | 105° | 0,58 | 0,19 |
| Sol/piste (`TrackSegment.tscn`) | `0.42,0.44,0.24` | `0.24,0.46,0.17` | 105,5° | 0,63 | 0,46 |
| Curbs (`_CURB_COLOR`) | `0.72,0.74,0.52` | `0.475,0.760,0.380` | 105° | 0,50 | 0,76 |
| Décor mountain (`Decor.gd`) | `0.30,0.36,0.28` | `0.274,0.370,0.244` | 106° | 0,34 | 0,37 |
| Décor hill_far | `0.26,0.33,0.24` | `0.233,0.340,0.204` | 107° | 0,40 | 0,34 |
| Décor hill_near | `0.20,0.27,0.19` | `0.177,0.280,0.151` | 108° | 0,46 | 0,28 |

`scenes/Game.tscn` (le `WorldEnvironment` qui rend RÉELLEMENT, dupliqué à
dessein — voir `SwampAtmosphere.gd`) et `scenes/TitleScreen.tscn` /
`scenes/GameOverScreen.tscn` (deux `ColorRect` autonomes, jamais raccordés
à `GameState`) ont été mis à jour dans le même lot, avec les mêmes valeurs
que `SWAMP_SKY`/`SWAMP_SKY_DEEP` pour rester dans la même famille de
couleur plutôt que d'inventer une quatrième teinte. Les albédos des 6
hazards, du poursuivant, des collectibles et des props de bord de piste
(arbre mort, rocher, buisson, souche, banc, panneau) sont **intouchés** —
hors du périmètre demandé.

⚠️ **Le rendu final diverge sensiblement du calcul HSV brut, et c'est
mesuré, pas négligé.** L'`ambient_light_color` de la scène (`0.42,0.5,
0.35`) multiplie l'albédo par canal : sur l'ancien sol peu saturé l'écart
raw→rendu était faible (~1 %), mais sur un albédo plus saturé l'écart
devient net. Sol RENDU (ce que `DarkPaletteAudit` échantillonne
réellement) : H=76,7°/S=0,68/luminance 0,153 (avant) → H=103,1°/S=0,81/
luminance 0,150 (après) — la saturation rendue dépasse même la saturation
brute. **Un premier essai à `Color(0.25, 0.47, 0.18)` a été corrigé après
mesure** : il rendait à luminance 0,158, trop proche du plafond CHARGER
(voir plus bas), et faisait tomber son contraste à 3,08:1. La valeur
retenue (`0.24, 0.46, 0.17`) a été trouvée par deux itérations de
mesure réelle (sonde rejouée à chaque fois), pas par un calcul sur
papier — voir le commentaire dédié dans `TrackSegment.gd` pour le détail
des trois points de mesure.

### Contraintes non négociables — toutes vérifiées par sonde réelle, pas par calcul

**`DarkPaletteAudit`** (pire des deux bouts de la respiration) :

| hazard | avant ce lot | après | plancher |
|---|---|---|---|
| DODGE | 3,28:1 | **3,19:1** | 3,0:1 ✅ |
| JUMP | 3,23:1 | **3,28:1** | 3,0:1 ✅ |
| STOMPER | 3,36:1 | **3,41:1** | 3,0:1 ✅ |
| CHARGER | 3,15:1 | **3,20:1** | 3,0:1 ✅ |

Les quatre restent au-dessus du plancher, avec une marge sur CHARGER
(l'ancien pire cas, 0,15 de marge) désormais MEILLEURE qu'avant (0,20).
ENEMY/AIR_ENEMY (mesurés dans leur teinte d'alarme, pas au repos — voir la
section « DIRECTION ARTISTIQUE PERMANENTE » plus haut) bougent un peu
(1,47→1,50, 1,14→1,08) mais restent non gatés, comme avant.

**`PursuerContrastAudit`** : silhouette 4,13:1/4,06:1 → **4,05:1/3,99:1**,
gauge 5,60:1/5,64:1 → 5,90:1/5,95:1. Planchers 2,5:1 et 3,0:1 tous les deux
larges. PASS.

**`SwampIdentityAudit`** (mesure de dominance verte — devait MONTER, pas
descendre) :

| état | sat avant | sat après | luma avant | luma après |
|---|---|---|---|---|
| WORLD AT TITLE | 0,58 | **0,72** | 0,257 | 0,277 |
| TITLE SCREEN | 0,30 | **0,58** | 0,102 | 0,106 |
| RUN OPENING | 0,58 | **0,72** | 0,258 | 0,277 |
| RUN DEEP MIST | 0,60 | **0,73** | 0,240 | 0,254 |
| GAME OVER | 0,58 | **0,72** | 0,258 | 0,277 |

Dominance verte (rapport G/R, hors mesure de la sonde mais calculé sur ses
propres échantillons) : ~1,25 avant → ~1,84 après sur les quatre états
monde, et 1,32 → 1,69 sur TITLE SCREEN. `SWAMP_IDENTITY_VERIFIED=yes` sur
les deux mesures. Luma
monte legèrement partout (le « un peu trop sombre » du retour device),
sans jamais approcher le plafond 0,42 (marge restante ~0,14-0,17). C'est la
ligne TITLE SCREEN — la pire avant ce lot, celle citée en premier par le
retour device puisque c'est le tout premier écran — qui progresse le plus
(quasiment doublée).

**`AssetContractAudit`** : 12/12 visuels swappés, 0/10 colliders déplacés
— inchangé, attendu (aucune géométrie touchée). **`ProbeTimeoutAudit`** :
32 sondes, toutes armées. Les deux PASS.

### Build et export — les deux exit 0

Éditeur + templates Godot 4.3-stable installés dans ce sandbox pour ce lot
(téléchargés depuis les releases GitHub officielles, comme le fait la CI).
`godot4 --headless --path . --import` : exit 0, aucune erreur GDScript ni
de scène. `godot4 --headless --path . --export-release "Web"
build/web/index.html` : exit 0, `index.html`/`index.wasm`/`index.pck`
tous non vides (35,4 Mo / 4,73 Mo). `build/` n'est pas versionné
(`.gitignore`).

### Ce qui reste ouvert — décision Mathieu, pas mesurable ici

Comme pour le lot précédent, **aucune sonde ne dit que c'est beau**, seulement
que c'est vert, saturé, sombre et que les planchers de contraste tiennent.
Ce qui reste à juger sur téléphone : est-ce que le marécage se lit
maintenant comme VERT au premier coup d'œil (l'objectif explicite du
retour device) tout en restant sombre et oppressant, et si un 3e tour de
calibrage est nécessaire, les tableaux HSV ci-dessus donnent un point de
départ chiffré plutôt qu'un réglage à l'aveugle.

## SWAMPPALETTE : la palette marecage a UNE seule source (23 aout 2026)

Branche `claude/swamp-palette-extraction-ioofz3`, partie de `staging`
(`b119a43`, le lot hub plateau). **C'est une EXTRACTION, pas une refonte
visuelle** : aucune couleur, aucune densite, aucune energie ne change.
Chased est en production ; ce lot doit etre invisible a l'oeil.

`scripts/world/SwampPalette.gd` (`class_name SwampPalette`, `extends
Resource`) + `resources/world/swamp_palette.tres`. Motif : **deux ecrans
dessinent desormais ce marecage** -- Chased (`scenes/Game.tscn`) et le hub
plateau (`scenes/HubWorld.tscn`, lot du 23 aout) -- et le second a ete
ecrit a partir d'une COPIE des memes nombres. Le `.tres` est la seule
forme qu'une scene et un script peuvent viser tous les deux.

**Consommateurs branches** (chacun son commit, chaque valeur verifiee
identique au litteral qu'elle remplace) :

| fichier | ce qu'il lit |
|---|---|
| `scripts/autoload/GameState.gd` | `SWAMP_SKY` / `_HAZE` / `_SKY_DEEP` / `_HAZE_DEEP` / `SWAMP_FOG_DENSITY` / `_DEEP` |
| `scripts/track/TrackSegment.gd` | `_CURB_COLOR` + les 6 couleurs de props |
| `scripts/world/Decor.gd` | les 3 tints de billboards (`_LAYERS`) |
| `scripts/hub/HubWorld.gd` | `background_color`, `ambient_light_*`, `fog_light_color`, `fog_density` |

⚠️ **`const` -> `static var` sur les valeurs DERIVEES, et c'est
obligatoire, pas un gout** : un initialiseur `const` ne peut pas lire la
propriete d'une instance de `Resource`. `_PALETTE` lui-meme reste `const`
(un `preload` est repliable). **Aucun nom d'API ne change** et rien
n'ecrit ces valeurs -- `Decor._LAYERS` garde sa forme, ses cles et son
ordre, donc `DecorParallaxProbe`/`DecorStabilityAudit` le parcourent
exactement comme avant. **Chaque consommateur `preload` le `.tres`
directement plutot que de passer par l'autoload `GameState`** : un
autoload est un noeud d'execution, il n'est pas lisible a la
constant-folding, et `GameState.gd` n'a de toute facon pas de
`class_name`.

### ⚠️ TROIS FAMILLES DE COULEURS NE SONT DELIBEREMENT PAS DEPLACEES

Signale plutot que tranche seul -- ce sont des dependances de sonde et de
contrat d'asset, pas des oublis :

1. **`scenes/Game.tscn` et `scenes/TrackSegment.tscn`.**
   `scripts/dev/DarkPaletteAudit.gd` lit ces scenes via
   `PackedScene.get_state()` (`_scene_environment`,
   `_scene_directional_light`, `_scene_ground_material`) et **mesure les
   valeurs qu'il y trouve** : c'est comme ca que la baseline livree est
   assertee sans faire tourner le jeu. Remplacer ces litteraux par une
   assignation d'execution laisserait la sonde mesurer le stub restant.
   La palette **DECLARE** donc `ambient_light_color`,
   `ambient_light_energy`, `sun_light_color` et `ground_albedo` -- elle
   reste une description complete -- mais **la scene reste ce qui rend**.
   **Contrat manuel tant qu'aucune sonde ne l'asserte.**
2. **`scenes/Obstacle.tscn` (les 6 albedos de hazards).** C'est le chemin
   de FALLBACK uniquement : les six hazards portent un `.glb` dont le
   `baseColorFactor` est ce qui dessine, et les sections hazards de ce
   fichier exigent que le placeholder MIROITE l'asset. **Un `.glb` ne peut
   pas lire un `.tres`** -- ne deplacer que la moitie placeholder
   FABRIQUERAIT la divergence qu'`AlarmRampAudit` existe pour fermer.
3. **`scripts/hub/HubBuilder.gd`** (`TRUNK`/`CROWN`/`ROCK`/`BUSH`) :
   numeriquement distinctes des props de Chased, lues par rien d'autre --
   locales au hub, pas de l'identite partagee.

### Les deux seuils de luminance : ils n'etaient DANS AUCUN script

Recon : `0.549` et `0.0165` n'existaient que dans `docs/MESHY_SPEC.md`
(sections 8.4 / 1057-1064), **jamais dans du code**. Aucune sonde ne les
asserte -- `DarkPaletteAudit` gate le ratio MESURE contre
`CONTRAST_FLOOR = 3.0` sur des pixels rendus, ce qui est le test le plus
fort. Ils sont desormais `@export contrast_light_threshold` /
`contrast_dark_threshold` : le raccourci d'AUTHORING qui dit qu'une
couleur echouera **avant** de la rendre. Rappel de leur origine : le sol
rend a `L = 0.150`, donc franchir 3,0:1 exige `L >= 0.549` ou
`L <= 0.0165` -- **rien au milieu ne passe, a aucune teinte**, et le
plafond sombre est dependant de la teinte en V (0,136 gris neutre, 0,166
a la teinte du rat, 0,289 au rouge DODGE sature) : resoudre en luminance,
jamais en HSV.

### Le fog du hub N'EST PAS celui de Chased, et c'est voulu

Chased fogge vers `haze_shallow` a `0.0035` ; le hub fogge vers
`sky_shallow` a `0.016` (~4,6x). Un plateau lu depuis une camera fixe veut
l'horizon ferme bien plus tot qu'une piste qu'on descend. Ces deux valeurs
sont nommees `hub_fog_light_color` / `hub_fog_density` **dans la palette**
plutot que laissees en litteraux, pour que la deviation soit visible a
cote de ce dont elle devie.

**Reste ouvert** : la synchronisation `.tscn` <-> `.tres` du point 1
ci-dessus est manuelle ; une sonde qui l'asserterait est le prochain pas
naturel, mais elle toucherait `scripts/dev/` et a ete laissee hors
perimetre. Et **jugement device** : Chased doit etre visuellement
IDENTIQUE avant/apres en navigation privee -- toute difference constatee
est une regression a signaler, pas a expliquer apres coup.

### Validation : NEUF sondes BYTE-IDENTIQUES, dont la sonde a PIXELS

Editeur + templates Godot 4.3-stable installes dans ce sandbox (releases
GitHub officielles, tailles verifiees contre `Content-Length` :
50 276 070 et 1 073 228 327 octets, aucune troncature). Import headless
**exit 0** (**24 `.scn`**, import complet verifie et pas suppose), export
Web release **exit 0**, **0 erreur GDScript**. `index.wasm`
**35 376 909 octets** -- le fingerprint deja consigne pour tout lot qui ne
touche pas le code moteur.

Diffees contre `origin/staging` en worktree separe, graine 20260806 :
`DarkPaletteAudit`, `AssetContractAudit`, `ProbeTimeoutAudit` (**37 sondes
scenes**), `DeathModelAudit`, `ChargerShapeProbe`, `DecorStabilityAudit`,
`ComboAudit`, `ShrinkAudit`, `ChargerAudit` -- **BYTE-IDENTIQUES sur les
DEUX flux (stdout ET stderr), exit 0 des deux cotes**.

⚠️ **`DarkPaletteAudit` byte-identique est LA preuve du lot**, et pas une
ligne de plus dans une liste : c'est la seule sonde qui echantillonne de
vrais PIXELS. Elle rend exactement les chiffres deja consignes -- DODGE
3,39/3,37, JUMP 3,04/3,02, CHARGER 3,37/3,34, STOMPER 3,41/3,41, ENEMY
4,12/4,10, AIR_ENEMY 2,13/2,12, 0 echantillon manque. Une couleur
deplacee de travers aurait bouge une de ces lignes.
`SwampIdentityAudit` : **4/4 etats OK, `SWAMP_IDENTITY_VERIFIED=yes`**.
Les 24 valeurs de la palette ont aussi ete relues a l'execution et
comparees une a une aux litteraux remplaces (**0 mismatch**, sonde jetable
supprimee avant commit).

⚠️ **DEUX sondes divergent, les DEUX sont NON SEEDEES, et c'est verifie
plutot qu'argumente** :
- `DecorParallaxProbe` -- **deux runs sur LA MEME branche divergent
  autant que branche-vs-base** (bornes de bande `[-700,-540]` /
  `[-520,-360]` / `[-340,-210]` identiques partout, seul le maximum
  observe bouge de moins d'un millimetre). PASS des deux cotes.
- `TrackPropsAudit` -- deja documente comme inerte au `--seed`. 4 runs de
  chaque cote : branche **1164 / 1220 / 1608 / 1648**, base **746 / 1166 /
  1690 / 1772**. **La base depasse le plafond de 1 500 sur 2 runs sur 4,
  exactement comme la branche** : les deux plages se chevauchent, l'echec
  est PRE-EXISTANT et non imputable a ce lot. Aucun seuil n'a ete bouge.

**Piege payload tenu** : **0** ligne `Storing File` pour `assets_source`,
`scripts/dev`, `docs` ou `web`. La palette EST packee (`swamp_palette.res`
+ son `.remap`), comme il faut puisque le jeu la lit.

### Deploiement staging (palier 1, automatique)

`staging` **`90694eb`** (merge `--no-ff`, arbre **byte-identique** a la
branche feature -- meme hash d'arbre des deux cotes, verifie AVANT le
push). CI run **#198** (id `32651298012`) **verte en 3 min 31 s**
(16:19:15 -> 16:22:46 UTC), `[STAGING -- staging]` succes,
`[PRODUCTION -- main]` correctement **skipped**. **`main` NON touche**
(palier 2, gate Mathieu apres validation device).

**Verifie SUR LE SERVICE, pas dans le log CI, et DANS LES DEUX SENS** --
le `CACHE_VERSION` a ete lu AVANT le deploiement puis apres :
**`1787496944` (14:55:44, run #197) -> `1787502139` (16:22:19)**, le
second **a l'interieur de la fenetre du run #198**. `x-vercel-cache:
MISS`, `age: 0` sur les DEUX lectures. L'alias sert bien ce build.

### HUB PLATEAU 3D : LIVREE EN PRODUCTION (23 aout 2026)

`staging` (`0815327`, incluant le fix overlap bouton Hub sur
`TitleScreen`) -> `main`, commit de merge **`20b9d93`**, `--no-ff`,
autorisation explicite de Mathieu apres validation device complete du
hub plateau 3D (bonds, 3 portails, popup de confirmation, retour depuis
Chased/Quizz/Battle, fix overlap).

**Verifie AVANT le merge** : `git fetch --all --prune`, `origin/staging`
= ref la plus recente du depot, aucune session concurrente. `main`
n'avait qu'un seul commit hors ancetres de `staging` -- le merge
`ea722bd` (battle lots 9-12) lui-meme, deja integre en contenu via
`staging` -- donc `--no-ff` sans conflit, arbre du merge **byte-identique
a `origin/staging`** (`git diff HEAD origin/staging` vide, meme hash
d'arbre `323cd8a0`).

**CI run #205** (id `32666854142`) **verte** (21:13:30 -> 21:16:31 UTC),
`conclusion: success`. **Verifie SUR LE SERVICE, pas seulement dans le
log CI** : `index.service.worker.js` de `keepy-ten.vercel.app` sert
`CACHE_VERSION = 1787519765` = **21:16:05 UTC**, a l'interieur de la
fenetre du run. `x-vercel-cache: MISS`, `age: 0` sur `index.html` ET
`index.service.worker.js` -- pas une reponse de cache. `index.wasm`
**35 376 909 octets**, identique au fingerprint deja consigne pour tout
lot qui ne touche pas le code moteur ; `index.pck` 5 807 728 octets.

**Le hub plateau 3D est donc EN PRODUCTION sur `keepy-ten.vercel.app`**,
pas seulement sur staging. Aucune sonde de ce depot ne rend de pixels
iOS reels -- la confirmation finale reste un jugement device, a refaire
sur prod meme si deja fait sur staging (environnement different).

