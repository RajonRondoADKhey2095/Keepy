# Écrans 2D — titre, logo, icône PWA, safe-area, letterbox

> Extrait de `CLAUDE.md` par le LOT H (2 septembre 2026), **verbatim** : aucune ligne réécrite, résumée ni supprimée.
> 7 section(s), 944 lignes d'origine.
> Doctrine permanente : voir `CLAUDE.md`. Index des chantiers : `docs/lots/INDEX.md`.

## ÉCRAN-TITRE : COUVERTURE GRAPHIQUE DÉDIÉE — hors périmètre `SwampIdentityAudit` (14 août 2026)

Branche `claude/title-cover-image-aj30y0`, partie de `main` (`ae8a3d5`).
`scenes/TitleScreen.tscn` porte désormais une illustration plein écran
(`assets/textures/ui/title_cover.png`, 720×1280, ratio 9:16 — exactement
celui du viewport 1080×1920, aucun rognage) au lieu de son simple
`ColorRect` uni `SWAMP_SKY`. Le `ColorRect` reste en dessous comme fond
de secours pendant le chargement de la texture, il n'est pas retiré.

**Import en compression LOSSY (WebP q=0.7), pas lossless** — seule texture
du projet dans ce cas, écart mesuré et pas supposé : `.ctex` **117 462
octets** en lossy contre **976 862** en lossless (mode par défaut de
l'import Godot), pour une source de 2 143 989 octets. Le rendu composite
(texture décodée + capture réelle de l'écran-titre sous `xvfb-run`
`--rendering-driver opengl3`) ne montre aucun artefact visible à l'écran —
c'est une illustration peinte plein cadre, pas une texture UI à arêtes
nettes où la perte WebP se verrait. Toutes les autres textures du projet
(billboards décor, bakes de matériaux `.glb`) restent en lossless : aucune
n'est un fond photographique de cette taille, donc aucune n'avait ce
compromis à faire. `.pck` : 4 810 928 → 4 930 608 octets (+119 680,
**+2,49 %**) — mesuré avant/après dans la même session/toolchain, seule
comparaison valable (voir la mise en garde permanente sur l'instabilité du
`.pck` entre deux exports, section PWA/Meshy plus haut).

**⚠️ EXCEPTION VOULUE ET EXPLICITE, ACTÉE CE JOUR — `SwampIdentityAudit`
ne sample PLUS `scenes/TitleScreen.tscn`.** Cette sonde gate « aucun état
du jeu ne doit rendre une frame bleue ou pastel » (voir la section
« DIRECTION ARTISTIQUE PERMANENTE » plus bas) ; elle échantillonnait un
état `TITLE SCREEN` en plus des quatre états du monde 3D. Une couverture
graphique dédiée n'a, par construction, aucune raison d'être dominée par
le vert du marécage — lui appliquer les mêmes planchers de saturation/
luminance/dominance verte gaterait la mauvaise chose. L'assertion
`TITLE SCREEN` est retirée du fichier ; les quatre autres (`WORLD AT
TITLE`, `RUN OPENING`, `RUN DEEP MIST`, `GAME OVER`) sont inchangées et
continuent de couvrir le monde 3D rendu **derrière** l'écran-titre à
`GameState.State.TITLE` — c'est ce périmètre-là, pas l'overlay
`TitleScreen.tscn` lui-même, que le reste du jeu doit rester marécage.
Rejoué après le retrait : **4/4 états `OK`, `SWAMP_IDENTITY_VERIFIED=yes`,
exit 0.**

**Ne pas réinstaller cette assertion en pensant réparer un oubli** — une
future session qui verrait `SwampIdentityAudit.gd` ne couvrir que 4 états
sur un total historique de 5 ne doit pas y voir une régression : c'est le
retrait délibéré documenté ici, pas un test manquant.

**Restructuration de scène nécessaire pour la lisibilité, script mis à
jour en conséquence.** Titre/sous-titre/bouton (`TitleLabel`,
`SubtitleLabel`, `PlayButton`) sont désormais regroupés dans un nouveau
`PanelContainer` (`CenterContainer/TitlePanel`), doté d'un `StyleBoxFlat`
semi-opaque (scrim brun, coins arrondis) — sans ce fond, le texte blanc
par défaut se serait retrouvé directement sur la scène la plus chargée de
l'illustration (le `VBoxContainer`, centré par le `CenterContainer`, tombe
exactement sur la confrontation hibou/écureuil au milieu de l'image, pas
sur le bandeau-titre peint en haut — vérifié par rendu, pas supposé).
`PlayButton` reçoit en plus ses propres `StyleBoxFlat` `normal`/`hover`/
`pressed`/`focus` (brun/ambre, cohérent avec le badge en bois peint dans
l'image elle-même), demandés explicitement pour garantir sa lisibilité
indépendamment du scrim. Conséquence mécanique : le chemin du nœud dans
`TitleScreen.gd` passe de `$CenterContainer/VBoxContainer/PlayButton` à
`$CenterContainer/TitlePanel/VBoxContainer/PlayButton` — aucun texte, aucune
police, aucune position relative des labels n'est touchée, seule la
hiérarchie qui les enveloppe change.

**Redondance signalée, non tranchée — décision produit, pas technique.**
L'image source porte elle-même un bandeau-titre peint (« KEEPY CHASED / A
Keepy Memorial Quest Mini-Game ») en haut de cadre, distinct dans l'espace
du `TitleLabel`/`SubtitleLabel` du moteur (« Keepy » / « Cours, saute,
ramasse des noisettes ») qui, lui, est centré verticalement par le
`CenterContainer` — **aucune collision de pixels entre les deux**, mais
une redondance de contenu (deux titres, deux registres de texte, à deux
endroits de l'écran). Non tranché ici : ni le bandeau peint ni le texte
moteur n'ont été retirés ou repositionnés — à arbitrer par Mathieu au vu
du rendu capturé.

Validation : import + export headless **exit 0**, `index.wasm` **35 376
909** octets (inchangé, aucun code moteur touché). Sondes rejouées après
coup, aucune ne touchant la scène modifiée : `ProbeTimeoutAudit`
(**33 sondes armées**), `AssetContractAudit` (**12/12 visuels, 0/10
colliders déplacés**) — toutes exit 0.

### Merge en production (14 août 2026, autorisation explicite de Mathieu)

`staging` (`3b8e7d2`) → `main`, commit de merge **`9e4b09a`**, après
validation device : positionnement du panneau confirmé, bouton « Jouer »
testé et fonctionnel, hors zone home indicator. Couvre les deux commits du
lot — couverture graphique + repositionnement du panneau off the owl.

Merge `--no-ff` (aucun conflit) : `main` était strictement en retard sur
`staging` (`main..staging` vide dans l'autre sens), l'arbre du commit de
merge est byte-identique à `origin/staging` (`git diff HEAD origin/staging`
vide) — ce qui part en prod est donc littéralement l'arbre validé sur
device, pas une recomposition.

CI run **#112** verte (3 min 32 s), déploiement PRODUCTION effectué,
STAGING correctement skippé (push sur `main`). **Fingerprint vérifié sur
le site LIVE** (`keepy-ten.vercel.app`, HTTP 200, `x-vercel-cache: MISS`) :
`GODOT_CONFIG.fileSizes` = `index.pck 4 930 656` / `index.wasm
35 376 909` — les deux identiques au chiffre du propre log CI de ce run
(`ls -la build/web/`), et le log CI porte lui-même `▲ Aliased
https://keepy-ten.vercel.app` sur ce déploiement précis.

**Rejoué SUR LE COMMIT DE MERGE lui-même, pas supposé porté** (éditeur
Godot 4.3-stable installé dans ce sandbox pour ce lot, import headless
exit 0) — **3 sondes exit 0** : `SwampIdentityAudit` (4/4 états OK,
`SWAMP_IDENTITY_VERIFIED=yes` — chiffres identiques à ceux déjà mesurés
sur la branche feature), `AssetContractAudit` (12/12 visuels, 0/10
colliders déplacés), `ProbeTimeoutAudit` (33 sondes armées).

## ICÔNE D'APPLICATION + PWA MINIMALE : écran d'accueil iOS/Android (14 août 2026)

Branche `claude/keepy-pwa-icon-hosebg`, partie de `staging` (`3b8e7d2`).
**Décision explicite de Mathieu : activer la PWA (option b), version
MINIMALE — le seul but est une icône/nom corrects à l'installation, pas
une stratégie offline élaborée.** `progressive_web_app/offline_page` reste
vide et aucun service worker applicatif custom n'est ajouté par-dessus
celui que Godot génère lui-même : ce projet n'a structurellement AUCUN
service worker applicatif à ce jour (voir la section PWA du CLAUDE.md
Keepr, même constat de fond), et ce lot ne change pas cet état — il active
simplement le générateur PWA natif de l'exporteur HTML5 de Godot
(`godot.service.worker.js`/`godot.offline.html`, présents dans le template
d'export officiel, jamais custom).

**Source** : `assets/textures/ui/1786650683166.jpg`, branche d'upload
`https/github.com/RajonRondoADKhey2095/Keepy/upload/main/assets/textures/ui`
(commit `c302396`), **confirmée par Mathieu**. 3100×2992 px, JPEG,
3 829 262 octets — c'est la MÊME illustration déjà installée en prod comme
`assets/textures/ui/title_cover.png` (voir la section « ÉCRAN-TITRE »
juste au-dessus, 14 août 2026), donc l'icône réutilise l'identité visuelle
déjà validée sur device pour la couverture de l'écran-titre, pas un nouvel
artwork.

**Crop retenu, MESURÉ avant d'être choisi, pas un centre géométrique
aveugle** — box `(54, 0, 3046, 2992)`, carré 2992×2992. Ratio source
1,036 (3100×2992) : la dimension qui contraint est la hauteur (2992),
donc AUCUN rognage vertical n'a lieu, seuls 108 px sont à retirer en
largeur (54 de chaque côté pour un crop centré). Avant de centrer, les
deux bords ont été inspectés à pleine résolution pour vérifier qu'aucun
sujet n'y est coupé : l'oreille de l'écureuil (bord gauche) démarre à
~127 px du bord, la pointe de l'aile du hibou (bord droit) s'arrête à
~48 px du bord — les deux largement au-delà de la zone de 54 px retirée,
donc un crop CENTRÉ est à la fois le choix le plus simple et celui qui ne
mord sur aucun des deux sujets. Aucune autre position n'a été jugée
meilleure : le sujet (écureuil + hibou) occupe déjà quasiment toute la
largeur de l'image bord à bord, donc la marge de 108 px ne permettait de
toute façon aucun repositionnement significatif.

**Tailles dérivées** (Lanczos depuis le carré source, PNG RGB standard —
PAS de `pngquant`/palette sur le master avant redimensionnement, pour ne
pas cumuler deux passes lossy avec le WebP d'import ci-dessous ; même
convention que `title_cover.png`, jamais quantifié à la source) :
- **`icon.png`** (racine du projet, 512×512) — sert à LA FOIS
  `config/icon` (icône projet/éditeur ET source du favicon HTML5, via
  `html/export_icon=true`, déjà activé) ET
  `progressive_web_app/icon_512x512` — un seul fichier, une seule
  ressource importée, pour ne pas payer deux fois le même contenu.
- **`assets/textures/ui/pwa_icon_180.png`** (180×180) — apple-touch-icon /
  PWA 180×180, c'est ce qu'iOS lit pour « Sur l'écran d'accueil ».
- **`assets/textures/ui/pwa_icon_144.png`** (144×144) — PWA 144×144.

**`config/icon` accepte bien un PNG en Godot 4.3, vérifié sur le vrai code
du moteur et pas supposé** — `EditorExportPlatformWeb` (extrait via
`godot4 --doctool`, classe `EditorExportPlatformWeb` dans
`platform/web/doc_classes/`) type le champ comme `CompressedTexture2D`
générique, sans contrainte de format ; `icon.svg` (l'ancien placeholder)
fonctionnait déjà de la même façon. L'ancien `icon.svg` + son
`.import` sont **supprimés** (pas de dette : entièrement superseded, zéro
référence restante, cohérent avec la convention du projet de ne jamais
garder de fichier mort — voir la règle Keepr sur les « vieux docs sticker
pollués »).

**⚠️ PIÈGE PAYLOAD DÉCOUVERT ET MESURÉ, PAS SUPPOSÉ — `config/icon`
EMBARQUE SON FICHIER SOURCE BRUT EN PLUS DE SON `.ctex` IMPORTÉ, et
c'est SPÉCIFIQUE à `config/icon`, pas un comportement général
d'`export_filter="all_resources"`.** Confirmé en grep-ant le log
`savepack` d'un export réel : `res://icon.png` (le PNG brut) apparaît
comme une ligne `Storing File` DISTINCTE, en plus de
`res://.godot/imported/icon.png-....ctex` — alors qu'un contrôle croisé
sur `title_cover.png` et sur les deux `pwa_icon_*.png` montre que SEUL
leur `.ctex` (et le petit `.import` texte qui l'accompagne) est packé,
jamais leur PNG source. Cause probable : la génération du favicon HTML5 à
l'export lit l'image du projet icon directement depuis son fichier
source (pas via le pipeline `CompressedTexture2D` normal), donc
l'exporteur embarque le fichier brut pour pouvoir le redécoder. **Levier
de poids identifié en conséquence : compresser le FICHIER SOURCE
`icon.png` lui-même compte ici, contrairement aux autres textures du
projet où seul le `.ctex` importé pèse.** `icon.png` est donc passé par
`pngquant --quality=70-95` (417 417 → **132 919 octets**, −68 %,
vérifié SANS artefact visible à l'œil sur un rendu upscalé 3× du 144×144
dérivé) avant d'être commité — les deux `pwa_icon_*.png` n'ont PAS reçu
ce traitement (inutile, leur PNG source n'est jamais dupliqué dans le
`.pck`).

**Import Godot en compression LOSSY (WebP q=0.7), même convention que
`title_cover.png`** — `compress/mode=1` posé à la main dans les trois
`.import` générés (le défaut Godot est `mode=0`, Lossless). Mesuré
après réimport :

| fichier | PNG source (repo) | `.ctex` importé (WebP q0.7) |
|---|---|---|
| `icon.png` | 132 919 o (pngquant) | 37 356 o |
| `pwa_icon_180.png` | 69 160 o | 9 918 o |
| `pwa_icon_144.png` | 46 386 o | 7 020 o |

**Configuration** (`export_presets.cfg`, preset Web) :
`progressive_web_app/enabled=true` ; `display=1` (Standalone — déjà posé
avant activation, valeur retrouvée en extrayant la chaîne d'enum
`Fullscreen,Standalone,Minimal UI,Browser` du binaire `godot4` via
`strings`, aucune doc XML ne liste les valeurs d'un enum d'export
plugin) ; `orientation` passe de `0` (Any) à `2` (Portrait, chaîne
`Any,Landscape,Portrait`), cohérent avec le viewport 1080×1920 de
`project.godot` ; `background_color=Color(0.062, 0.115, 0.044, 1)` —
reprend `GameState.SWAMP_SKY` telle quelle (même teinte que l'écran-titre
et l'écran game-over depuis le lot « DIRECTION ARTISTIQUE PERMANENTE »),
pour que le splash PWA ne jure pas avec l'identité marécage permanente du
jeu.

**Validation, export headless réel — pas une lecture de config.**
Éditeur + templates Godot 4.3-stable installés dans ce sandbox pour ce
lot (mêmes releases GitHub que la CI). Import + export Web : **exit 0**,
aucune erreur GDScript/parse. `index.manifest.json` généré et vérifié
octet pour octet :
```
{"background_color":"#101d0b","display":"standalone","icons":[
{"sizes":"144x144","src":"index.144x144.png","type":"image/png"},
{"sizes":"180x180","src":"index.180x180.png","type":"image/png"},
{"sizes":"512x512","src":"index.512x512.png","type":"image/png"}],
"name":"Keepy","orientation":"portrait","start_url":"./index.html"}
```
`#101d0b` = arrondi hex exact de `Color(0.062, 0.115, 0.044)` (confirmé
par calcul, pas approximatif). `index.html` porte les trois balises
attendues :
```
<link id="-gd-engine-icon" rel="icon" type="image/png" href="index.icon.png" />
<link rel="apple-touch-icon" href="index.apple-touch-icon.png"/>
<link rel="manifest" href="index.manifest.json">
```
`index.apple-touch-icon.png` (180×180) et `index.icon.png` (512×512)
inspectés visuellement après export : identiques au rendu attendu, aucun
artefact de compression visible malgré le double passage lossy
(pngquant sur la source + WebP à l'import, puis re-décodage/ré-encodage
PNG par l'exporteur lui-même pour le favicon).

**⚠️ Piège de mesure rencontré et corrigé pendant cette session, à
connaître pour toute future mesure de `.pck` locale (hors CI) : ne
JAMAIS relancer `--import` sans avoir d'abord supprimé `build/`.**
`export_filter="all_resources"` scanne tout `res://`, `build/` compris —
un second export sans nettoyage préalable fait réimporter les PNG
fraîchement écrits par le PREMIER export (`build/web/index.icon.png` etc.)
comme de NOUVELLES ressources du projet, qui se retrouvent alors
elles-mêmes packées dans le `.pck` suivant (contamination auto-entretenue,
observée : +564 Ko sur un second export non nettoyé). `.gitignore` exclut
déjà `/build/` du dépôt donc ce risque n'existe QUE localement en dehors
d'un checkout propre (la CI part toujours d'un checkout frais, jamais
exposée) — mais toute session qui exporte plusieurs fois de suite en local
doit faire `rm -rf build/` (et idéalement `.godot/` pour repartir d'un
cache d'import propre) entre deux exports avant de comparer des tailles de
`.pck`.

**`.pck` : 4 930 656 → 5 118 976 octets (+188 320, +3,82 %)** — mesuré sur
un export unique, propre (`.godot/` et `build/` supprimés puis reconstruits
en une seule passe), comme l'exige la mise en garde permanente sur
l'instabilité du `.pck` entre deux exports (section PWA/Meshy). `index.wasm`
**inchangé** (35 376 909 octets, identique à toutes les mesures précédentes
de ce fichier) — confirme qu'aucun code moteur n'a été touché, uniquement
des assets + de la config d'export. Le delta se décompose intégralement :
~133 Ko (copie brute dupliquée de `icon.png`, voir le piège payload
ci-dessus) + ~54 Ko (les trois `.ctex` WebP-lossy combinés) ≈ 187 Ko,
cohérent avec les 188 320 octets mesurés à quelques centaines d'octets
près (bruit de compression normal sur les autres textures du projet, déjà
documenté).

**Déployé sur `staging`** (palier 1, automatique — voir la règle de
déploiement) : `keepy-staging.vercel.app`.

**RESTE OUVERT — jugement device, rien de mesurable ici** : le rendu
final sur un VRAI écran d'accueil iOS (Safari → Partager → Sur l'écran
d'accueil) et Android (Chrome → Ajouter à l'écran d'accueil), en
particulier (a) que l'icône installée affiche bien l'illustration
écureuil/hibou et pas un reste de cache d'un ancien favicon/PWA (aucune
PWA n'existait avant ce lot, donc aucun cache à purger côté navigateur,
mais à vérifier quand même) ; (b) que le mode Standalone (sans barre
d'adresse) et l'orientation Portrait se comportent comme attendu au
lancement depuis l'icône installée. Aucune sonde de ce projet ne couvre
le rendu PWA/HTML — c'est structurellement hors de portée d'un test
headless Godot.

### Merge en production (14 août 2026, autorisation explicite de Mathieu)

`staging` (`0ded3b6`) → `main`, commit de merge **`e13d916`**, après
validation device iOS confirmée : icône installée correcte (illustration
écureuil/hibou), nom « Keepy », lancement en mode standalone (sans barre
d'adresse) vérifié après suppression de l'ancien raccourci d'écran
d'accueil (piège de cache iOS déjà documenté ailleurs dans ce fichier).

**PAS un fast-forward, et un conflit RÉEL sur `CLAUDE.md`** — contrairement
aux merges de prod précédents de ce lot (rondin JUMP excepté) : entre le
point de départ de la branche icône (`3b8e7d2`) et ce merge, `main` avait
déjà reçu EN PARALLÈLE le merge de l'écran-titre + panneau (`9e4b09a` +
`0edda7a`), sur la MÊME section de doc. Résolu par **concaténation simple**
(les deux sections documentent des changements disjoints — écran-titre
d'un côté, icône PWA de l'autre — aucune ligne de contenu réellement en
conflit, seulement leur point d'insertion commun) ; **tous les fichiers
hors `CLAUDE.md` sont restés sans conflit et byte-identiques à
`origin/staging`** (`git diff HEAD origin/staging -- . ':!CLAUDE.md'`
vide, vérifié avant le commit du merge).

**CI run `#115` (id `31806771806`) verte (3 min 34 s)** — étape
`Deploy to Vercel [PRODUCTION -- main]` réussie, `[STAGING -- staging]`
correctement `skipped` (push sur `main`). Sortie de build vérifiée dans le
log CI (`Verify export output`) :

```
index.pck               5118864
index.wasm              35376909
index.manifest.json         325
index.apple-touch-icon.png  69347
index.icon.png          355419
```

**Fingerprint LIVE re-vérifié sur `keepy-ten.vercel.app`** (fetch direct
post-déploiement, `x-vercel-cache: MISS` sur les trois requêtes — donc pas
une réponse de cache stale) :
- `index.html` → `GODOT_CONFIG.fileSizes` = `{"index.pck":5118864,
  "index.wasm":35376909}`, **identique au bit près** au log CI. Les trois
  balises attendues présentes : `<link id="-gd-engine-icon" ...
  href="index.icon.png">`, `<link rel="apple-touch-icon"
  href="index.apple-touch-icon.png">`, `<link rel="manifest"
  href="index.manifest.json">`.
- `index.manifest.json` → `content-length: 325`, contenu **identique au
  bit près** à celui validé sur staging (`background_color:"#101d0b"`,
  `display:"standalone"`, 3 icônes 144/180/512, `name:"Keepy"`,
  `orientation:"portrait"`).
- `index.apple-touch-icon.png` → HTTP 200, `content-length: 69347`,
  identique au chiffre du log CI.

**Aucune sonde gameplay rejouée pour cause de non-applicabilité, pas
d'omission** : `git diff` sur le périmètre exact de ce merge
(`0edda7a..e13d916`) montre **zéro fichier touché sous `scripts/` ou
`scenes/`** — le lot ne modifie que `icon.png`/`pwa_icon_{144,180}.png`
(+ leurs `.import`), `icon.svg` (supprimé), `export_presets.cfg` et 1 ligne
de `project.godot` (`config/icon`). Aucune sonde de `scripts/dev/` ne peut
détecter une régression sur un fichier qu'elle ne mesure pas. La seule
validation structurelle pertinente — que l'import + l'export headless
chargent et empaquettent l'intégralité des scènes/ressources sans erreur —
**a déjà eu lieu et réussi** : c'est exactement ce que fait le job CI
(`Import project resources` + `Export Web build`, tous deux `exit 0` sur
ce commit précis). **Toolchain Godot indisponible dans CE sandbox pour
rejouer quoi que ce soit localement** — ni éditeur ni templates installés,
et le téléchargement échoue en timeout sur
`release-assets.githubusercontent.com` (même famille de blocage réseau
déjà documentée pour `productionresultssa*.blob.core.windows.net`) : la
validation locale par sonde headless, faite pour d'autres lots dans
d'autres sessions, n'était structurellement pas possible ici — la
validation CI + fingerprint live ci-dessus en tient lieu.

**Note de cohérence, pas une contradiction** : la section « ICÔNE
D'APPLICATION + PWA MINIMALE » ci-dessus dit encore « **Déployé sur
`staging`** ». Volontairement non réécrite après ce merge — c'était l'état
au moment où ce lot a été écrit, et le réécrire ferait perdre la trace de
la séquence réelle (palier 1 avant palier 2). Ce paragraphe-ci est la
mise à jour d'état ; les deux se lisent ensemble.

## BANDE BLANCHE SOUS LE BOUTON « JOUER » (iOS Safari / PWA, safe-area) — coquille HTML custom ajoutée (17 août 2026)

Branche `claude/keepy-safe-area-fix-obp7bm`, partie de `staging` (`016ada3`).
Fix CSS/HTML scopé sur la coquille d'export web, aucune scène ni logique de
jeu touchée — `TitleScreen.tscn` et son `TextureRect` sont intouchés, comme
demandé.

**Recon d'abord, pas de patch à l'aveugle.** `export_presets.cfg` n'a jamais
référencé de `html_shell` custom (`html/custom_html_shell=""`,
`html/head_include=""`) : l'export utilisait le template PAR DÉFAUT de
Godot, invisible dans ce repo — impossible à corriger sans en fournir un.
Le template `misc/dist/html/full-size.html` du tag `4.3-stable` (même
version que la CI, `GODOT_VERSION="4.3-stable"`) a été récupéré depuis la
source officielle et lu octet pour octet avant toute modification : meta
viewport SANS `viewport-fit=cover`, `body { background-color: black }`.

**Cause du défaut, pas seulement le symptôme.** Sans `viewport-fit=cover`,
Safari iOS ne fait jamais s'étendre le viewport de layout jusque sous
l'encoche/l'indicateur d'accueil — cette bande reste HORS du DOM de la
page, donc la couleur de fond du `body` (même correcte) ne peut jamais
l'atteindre : c'est le blanc par défaut du navigateur qui s'y affiche,
quel que soit le réglage CSS. C'est un défaut de VIEWPORT, pas de couleur
— corriger seulement la couleur sans `viewport-fit=cover` n'aurait rien
changé.

**Fix, `web/html_shell.html` (nouveau)** : copie du template par défaut de
Godot 4.3, avec deux changements seulement —
- `<meta name="viewport" ...>` gagne `viewport-fit=cover`, pour que le
  layout s'étende réellement sous la safe-area ;
- le fond (`body`, `html`/`body` en 100%×100%, `#status`) passe de
  `black`/`#242424` à **`#101d0b`** — la même teinte `SWAMP_SKY` déjà
  utilisée par `progressive_web_app/background_color` dans ce même fichier
  (`Color(0.062, 0.115, 0.044, 1)`, arrondi déjà vérifié ailleurs dans ce
  document). Toute zone hors safe-area se peint donc dans l'identité
  marécage plutôt qu'en noir générique, et sans divergence avec le
  splash PWA.

Rien d'autre n'a bougé (structure `#status`/`#status-splash`/script de
boot, taille/police, logique de `Engine.startGame`) — un diff minimal
contre la source officielle, vérifié ligne à ligne avant commit.

`export_presets.cfg` : `html/custom_html_shell="res://web/html_shell.html"`,
et `web/*` ajouté à `exclude_filter` par précaution — **vérifié plutôt que
supposé nécessaire** : le log `savepack` d'un export réel ne contient
**aucune** ligne `Storing File` pour `res://web/…`, donc Godot ne
considère jamais un `.html` comme une ressource « all_resources » à
packer (contrairement au piège déjà documenté pour `config/icon`, qui
embarque son PNG source pour une raison différente — la génération du
favicon). L'exclusion est donc une ceinture-et-bretelles délibérée, pas
une correction d'un défaut mesuré.

**Validation, éditeur + templates Godot 4.3-stable installés dans ce
sandbox** (releases GitHub officielles, mêmes que la CI) : import headless
**exit 0**, export Web release sous `xvfb-run` **exit 0**, aucune
erreur/warning dans le log. `index.html` généré vérifié octet pour octet :
`viewport-fit=cover` présent, `#101d0b` sur les trois règles de fond
attendues (`html,body`, `body`, `#status`). `index.manifest.json`
inchangé (`background_color:"#101d0b"`, déjà cohérent). `index.wasm`
**35 376 909 octets** — identique au fingerprint déjà consigné pour tout
lot qui ne touche pas le code moteur, cohérent avec un diff limité à un
fichier HTML + config d'export. `index.pck` **5 119 312 octets**, dans la
plage déjà documentée pour ce commit de base (l'avertissement permanent
sur l'instabilité du `.pck` entre deux exports s'applique, ne pas s'en
servir seul comme preuve).

**Reste ouvert — jugement device, rien de mesurable ici** : Mathieu doit
confirmer sur iPhone Safari (onglet normal ET PWA installée) que la bande
blanche a disparu sous le bouton « Jouer » — c'est le seul juge, aucune
sonde de ce repo ne rend de pixels iOS réels. Merge sur `staging`
automatique dès que la CI est verte (palier 1) ; `main` reste gaté par
Mathieu après validation device (palier 2).

## ÉCRAN-TITRE : LE MOT « KEEPY » DEVIENT UN LOGO IMAGE (17 août 2026)

Branche `claude/keepy-title-logo-texture-yk6tqd`, partie de `main`
(`aa108fc`, après le merge de la PR #3 « Add files via upload » qui a
déposé `assets_source/ui/keepy_title_logo.png`, 704×395, exception du
push web direct déjà actée dans ce fichier). `TitleLabel` (un `Label`
texte, police 96) est remplacé par `TitleLogo` (`TextureRect`), même
emplacement dans `CenterContainer/TitlePanel/VBoxContainer`, entre le
scrim et le sous-titre/bouton « Jouer » — les deux **intouchés**, comme
le `CoverImage` et le scrim.

**Le fichier a été mesuré avant d'être installé, pas supposé sain** :
RGBA, déjà découpé sur fond transparent (`getbbox()` = `(6,20,696,375)`
sur un canevas 704×395 — marge négligeable, pas de recadrage fait), rendu
composite vérifié visuellement : un panneau en bois peint « Keepy » avec
lianes, cohérent avec le badge en bois déjà peint dans `title_cover.png`
et avec le style `PlayButton` (bordure ambre/brun) posé au lot écran-titre
du 14 août.

**Installé sous `assets/textures/ui/keepy_title_logo.png`, import
LOSSLESS (`compress/mode=0`)** — pas le mode lossy de `title_cover.png`,
qui était une exception motivée par une texture plein écran de 2,1 Mo ;
celle-ci (418 124 octets source, `.ctex` 312 840 octets) suit la
convention par défaut du projet, comme les billboards de `Decor.gd` et
les icônes PWA.

**Dimensionnement** : `custom_minimum_size = Vector2(280, 120)`,
`expand_mode = 1` (IGNORE_SIZE, pour que la taille native 704×395 ne
force pas la mise en page), `stretch_mode = 5` (KEEP_ASPECT_CENTERED).
Le ratio source (1,782:1) est plus large que la boîte (2,33:1), donc la
hauteur est l'axe contraignant : logo affiché à 214×120, occupant un
volume comparable à l'ancien `Label` (police 96, ~1-2 lignes). Choisi
pour rester dans l'enveloppe déjà occupée par le texte, pas par un calcul
de collision avec `PlayButton` (360 px de large, jamais serré par le
logo).

**Filtre de texture** : aucun override posé sur le nœud — le projet n'a
aucune entrée `rendering/textures/canvas_textures/default_texture_filter`
dans `project.godot`, donc le défaut moteur (linéaire) s'applique, comme
pour tous les autres `TextureRect` de la scène. Pas de pixelisation
attendue sur un artwork peint, non pixel-art.

**Validation, éditeur + templates Godot 4.3-stable installés dans ce
sandbox** (releases GitHub officielles) : import headless **exit 0**,
export Web release **exit 0**, aucune erreur ni sur `TitleScreen.tscn`
seul (`--quit-after 2`) ni sur l'export complet. **Rendu réel capturé**
sous `xvfb-run --rendering-driver opengl3` (sonde jetable
`TitleLogoCapture.tscn`, supprimée avant commit) : le logo s'affiche
net, centré, non déformé, au-dessus du sous-titre et du bouton « Jouer »
— confirmé à l'œil, pas seulement calculé. Piège payload re-vérifié :
`res://assets_source` n'apparaît dans aucune ligne `Storing File` du log
`savepack`. `index.wasm` **35 376 909 octets**, inchangé (aucun code
moteur touché) ; `index.pck` **5 432 848 → 5 432 816 octets** selon
l'export (local vs CI), écart cohérent avec l'instabilité de taille déjà
documentée pour ce fichier, jamais utilisé seul comme preuve.

⚠️ **Merge sur `staging` fait avec un commit d'un autre lot déjà dessus**
(`78b2c0c`, la coquille HTML `viewport-fit=cover` du jour même, section
juste au-dessus) — merge `--no-ff` sans conflit (aucun fichier en commun),
re-validé (import + export + boot) sur l'arbre fusionné avant push, pas
seulement sur la branche feature seule.

⚠️ **Nettoyage de routine bloqué, signalé plutôt que silencieux** :
`RajonRondoADKhey2095-patch-3` (la branche mergée par la PR #3) n'a pas pu
être supprimée — `git push origin --delete` échoue systématiquement en
HTTP 403 depuis ce sandbox (retenté deux fois), alors que le push normal
sur cette même session fonctionne sans problème. Cause probable : la
suppression de ref est bloquée par la politique du proxy git de ce
sandbox, indépendamment des droits GitHub réels. Aucun outil MCP GitHub
disponible ne couvre la suppression de branche. À faire manuellement par
Mathieu (ou une session avec un accès différent) si le nettoyage est
souhaité — la branche mergée ne gêne rien fonctionnellement, elle reste
juste affichée dans la liste des branches.

**Merge staging fait, `main` non touché** — palier 2 gaté par Mathieu
après validation device (le logo se lit-il bien à distance et à
l'échelle réelle du panneau, sur `keepy-staging.vercel.app`).

**Reste ouvert** : jugement device (lisibilité du logo à la taille
réelle, cohérence avec le sous-titre et le bouton juste en dessous) ; et
la redondance déjà notée au lot du 14 août (bandeau peint « KEEPY CHASED »
en haut de `title_cover.png` vs ce nouveau logo « Keepy » en bas) reste
non tranchée — elle passe maintenant de « deux registres de texte » à
« deux logos image du même mot », ce qui ne change pas la question posée
à Mathieu mais vaut la peine d'être noté au prochain retour device.

## LOGO DU TITRE AGRANDI : retour device « trop petit/timide » — 356x200, PAS le 420-460 initialement visé (17 août 2026)

Branche `claude/keepy-logo-resize-o55ll9`, redémarrée sur `staging`
(`bdb1539`) — la branche n'avait aucun commit propre, elle pointait
encore sur `main` (le lot logo vit sur `staging`, pas encore sur `main`).
Retour device sur le lot ci-dessus : `TitleLogo` (`custom_minimum_size
= Vector2(280, 120)`) se lit trop petit/timide face au bandeau peint
« KEEPY CHASED » de l'image de couverture. Seul `scenes/TitleScreen.tscn`
touché — une ligne, aucun script, aucun autre nœud.

### ⚠️ La fourchette suggérée (420x236 à 460x258) DÉBORDE de l'écran — mesuré, pas supposé

Éditeur + templates Godot 4.3-stable installés dans ce sandbox pour ce
lot (releases GitHub officielles). Sonde jetable (jamais committée,
supprimée avant tout commit) instanciant `TitleScreen.tscn` en headless,
forçant `custom_minimum_size` de `TitleLogo` à chaque candidat, et lisant
les rects `global` réels après 30 frames de stabilisation.

**Cause du désaccord avec l'estimation du brief : la police par défaut du
projet (aucun thème custom, `project.godot` n'a aucune clé `theme/font`)
rend `SubtitleLabel` avec `font.get_height(32) = 96px`** (ascent 64 +
descent 32) — pas les ~44px qu'un texte à interligne standard aurait
laissé supposer. `PlayButton` rend aussi 138px de haut (padding de thème
par défaut autour de son `font_size=44`) contre son `custom_minimum_size`
de 110. Aucun des deux n'est nouveau ni causé par ce lot — c'est l'état
déjà shippé, juste jamais mesuré avant.

**Formule mesurée** (régime où le panneau dépasse la hauteur nominale du
`CenterContainer`, ce qui est déjà le cas au-delà de `logo_h ≈ 144` —
`CenterContainer` clampe alors sa propre taille sur celle du contenu,
son bord HAUT restant épinglé à `0.68 * 1920 = 1305.6px`) :

```
panel_bottom(y) = 1305.6 + 370 + logo_h
```

où 370 = marges du panel (56) + logo(gap 40) + SubtitleLabel réel (96) +
gap(40) + PlayButton réel (138). Vérifié à quatre tailles (356x200,
364x204, 420x236, 460x258, 500x281, 440x247) — la formule reproduit
chaque bord mesuré à 0,0px près. Résultat pour la fourchette du brief :

| taille visée | marge restante avant le bas de l'écran (1920px) |
|---|---|
| 420x236 (bas de fourchette) | **+8,4px** — quasiment collé au bord |
| 440x247 | **−2,6px** — déjà hors écran |
| 460x258 (haut de fourchette) | **−13,6px** — déjà hors écran |

`window/stretch/aspect="keep"` (`project.godot`) empêche un rognage dur
(letterbox, pas de crop) — mais rien ne garantit que la zone au-delà de
1920px reste visible sous la coquille `viewport-fit=cover` déjà posée
pour iOS (safe-area, section PWA plus haut) : dépasser, même sans
crash, revient à parier sur une marge dont ce lot n'a aucune preuve.

### Taille retenue : 356x200 (ratio 704:395 exact, marge 44,4px)

Recherchée par la même sonde à l'envers : `logo_h` maximal pour une marge
cible ~40-50px. **356x200** donne une marge mesurée de **44,4px** —
confortablement au-dessus des ~34px habituellement réservés à la home
indicator iOS, tout en restant un agrandissement réel : le rendu
effectif de l'ancienne boîte (280x120, ratio 2,33:1, ne matchait PAS le
ratio source 1,78:1) était contraint par la HAUTEUR sous
`KEEP_ASPECT_CENTERED` — 214x120 réellement affiché, pas 280x120. Le
logo visible passe donc de **214x120 à 356x200**, soit **+66,4% en
largeur ET en hauteur** (la boîte matche maintenant exactement le ratio
source, donc plus aucun espace perdu par lettrboxing interne).

**Option 1 retenue (taille fixe), pas Option 2** — mesuré comme sans
objet plutôt qu'écarté par défaut : `SubtitleLabel` (554px de large,
mesuré via `Font.get_string_size()`, pas de wrap) est déjà plus large
que n'importe quel logo dans la fourchette envisagée, donc c'est LUI
qui fixe la largeur du panel (626px), pas le logo — `size_flags_
horizontal = SIZE_EXPAND_FILL` sur `TitleLogo` n'aurait rien élargi de
plus. Le projet n'a par ailleurs qu'une seule résolution de design fixe
(`window/stretch/mode="canvas_items"`, viewport 1080x1920) : l'argument
« plus robuste si le scrim doit s'adapter à d'autres largeurs » du brief
ne s'applique à aucun cas réel de ce projet aujourd'hui.

**Build/export validés dans ce sandbox** : import headless **exit 0**,
export Web release **exit 0**, `index.wasm` **35 376 909 octets** —
identique au fingerprint déjà consigné pour tout lot qui ne touche pas
le code moteur (cohérent : une seule valeur `Vector2` a changé).
`SwampIdentityAudit` (4/4 états OK, `SWAMP_IDENTITY_VERIFIED=yes`,
lancée SANS `--headless` sous `xvfb-run` — la combiner avec `--headless`
force le driver DUMMY et lit des pixels null, piège déjà consigné plus
haut, reproduit puis évité ici), `AssetContractAudit` (12/12 visuels,
0/10 colliders déplacés), `ProbeTimeoutAudit` (33 sondes armées) —
**toutes exit 0**. Aucune sonde de `scripts/dev/` ne couvre
`TitleScreen.tscn` en dehors des trois lignes de doc de
`SwampIdentityAudit` expliquant pourquoi elle ne l'échantillonne plus
(section ÉCRAN-TITRE, 14 août) — non-applicabilité vérifiée, pas
supposée.

**Mergé sur `staging`** (palier 1, automatique), `main` non touché
(palier 2 gaté par Mathieu après validation device).

**Reste ouvert — jugement device, rien de mesurable de plus ici** : la
taille 356x200 est un compromis mesuré (marge écran vs impact visuel),
pas une certitude esthétique — si Mathieu le trouve encore trop petit
sur son téléphone, la marge restante (44,4px) donne ~44px de budget
supplémentaire avant de retoucher la marge de sécurité elle-même
(actuellement fixée par convention, pas par une contrainte matérielle
mesurée dans ce sandbox).

## BANDES NOIRES SUR TOUS LES ÉCRANS : c'était le LETTERBOX GODOT, pas la safe-area HTML (18 août 2026)

Branche `claude/godot-letterbox-ui-screens-oq6rzf`, redémarrée sur
`origin/staging` (`3312a3c`) — elle pointait encore sur `main`, sans commit
propre. **Six fichiers, tous du code, aucune scène, aucun collider, aucune
constante de gameplay, aucun `.glb`, `project.godot` INTOUCHÉ.**

⚠️ **Ce n'était PAS le fix safe-area du 17 août, qui fonctionne** — vérifié
device : la bande de status bar est bien crème sur Quizz et `#101d0b` sur
Hub. C'était le **letterboxing de Godot**, dessiné **À L'INTÉRIEUR du
canvas**, que ni CSS ni JS ne peut atteindre.

**Mesuré sur capture device 1170x2532** : 141px de couleur de page (correct),
puis **155px de NOIR**, 2080px de contenu, **156px de NOIR**. Et
`1170 * 1920/1080 = 2080` exactement. `project.godot` déclare un viewport
1080x1920 avec `window/stretch/aspect="keep"` sur un écran ~19.5:9.
**Reproduit ici avec les chiffres du moteur** : `visible_rect` reste
1080x1920 et le transform final prend un `origin.y` de **226** — soit
`(2532 − 2080) / 2`. Sur device le canvas est plus court que la fenêtre des
141px de safe-area, d'où 155/156 là-bas et 226 dans une fenêtre nue : même
mécanisme, deux hauteurs de canvas.

### Bascule au RUNTIME, `project.godot` jamais touché — et c'est la contrainte, pas un détail

Passer `window/stretch/aspect` à `"expand"` globalement corrigerait les
écrans UI **et rééquilibrerait Chased en silence** : le viewport passerait de
1920 à **2337** de haut sur ce même device (mesuré, pas estimé — le brief
tablait sur ~2207), soit **~417px de monde visible en plus devant Keepy**,
donc des obstacles qui entrent dans le cadre plus tôt, donc le budget de
réaction autour duquel le jeu est calibré (`OBSTACLE_REACTION_BUDGET_S`) qui
bouge sans qu'une ligne de gameplay ne change.

Donc : les écrans UI demandent **EXPAND**, le jeu redemande **KEEP**.
`project.godot` garde `"keep"` par défaut, ce qui veut dire que **chaque
sonde de `scripts/dev/` et chaque scène que personne n'a touchée héritent du
cadrage auquel Chased est réglé** — la valeur sûre est celle qu'on obtient en
ne faisant rien.

**Ça vit dans `SafeArea.gd`** plutôt que dans un second autoload : même
responsabilité (« à quoi ressemblent les bords de l'écran sur ce device »), et
un écran qui a besoin de l'un a presque toujours besoin de l'autre. Deux
fonctions, `fill_screen()` (UI) et `keep_game_framing()` (jeu).

⚠️ **Aucune garde `OS.has_feature("web")` sur ces deux-là**, contrairement aux
fonctions de couleur juste au-dessus : `content_scale_aspect` est une
propriété du moteur, pas un appel `JavaScriptBridge`. La garde web existe
parce que `JavaScriptBridge` n'existe pas hors web ; ici il n'y a rien à
garder, et garder ferait diverger l'éditeur et les rendus offscreen du build
livré — la seule divergence qui cacherait ce défaut à tout test capable de
l'attraper.

**`Game._ready()` redemande KEEP DÉFENSIVEMENT**, pas parce que l'écran
précédent aurait oublié : une sonde qui boote `Game.tscn` directement, ou un
futur point d'entrée qui saute le hub, doit obtenir le cadrage réglé aussi.

### Le mécanisme a été VÉRIFIÉ AU RUNTIME avant qu'on s'y fie

Godot 4.3, gl_compatibility, X11 1170x2532 : `content_scale_aspect` prend
effet **à la frame suivante sans recréer la fenêtre**, et le remettre
reproduit `visible_rect`, `origin` **et** `scale` **exactement**. C'est cet
aller-retour qui fait de `keep_game_framing()` une vraie restauration et pas
un espoir.

| | `visible_rect` | `final_transform.origin` |
|---|---|---|
| KEEP (défaut projet) | 1080x1920 | **(0, 226)** — le letterbox |
| EXPAND | **1080x2337** | (0, 0) |
| retour KEEP | 1080x1920 | (0, 226) |

### Non-régression Chased : PROUVÉE, pas plaidée

Sonde jetable (jamais commitée, supprimée avant le commit) bootant
`Game.tscn`, caméra épinglée à une pose fixe pour que le lerp ne fasse pas
varier la mesure, lisant le viewport réel, la **matrice de projection complète
de la caméra** et **9 points du monde unprojetés** (centres de voie à la
distance de réaction, plan du sol, hauteur de tête de Keepy). Jouée à
**1170x2532** sur cette branche ET sur `origin/staging` en worktree séparé :

**22 lignes, BYTE-IDENTIQUES.** `content_scale_aspect = 1` (KEEP),
`visible_rect` 1080x1920, `origin (0, 226)`, `proj[0..3]` identiques,
9 unprojections identiques au dernier chiffre. Le jeu est donc **toujours
letterboxé**, exactement comme avant — c'est le résultat voulu.

### Côté UI : preuve POSITIVE, pas seulement « le jeu n'a pas bougé »

Seconde sonde jetable, sous `xvfb` (pas `--headless` — piège déjà documenté :
il force le driver DUMMY et lit des pixels nuls). Elle remet **KEEP avant
chaque écran**, sinon un écran qui oublierait de demander aurait l'air correct
en héritant de l'EXPAND du précédent.

| écran | aspect atteint | `visible_rect` | letterbox | contrôles dans le viewport | lignes noires haut/bas |
|---|---|---|---|---|---|
| LoginScreen | **4 = EXPAND** | 1080x2337 | **(0,0)** | 2/2 | **0 / 0** |
| Hub | **4 = EXPAND** | 1080x2337 | **(0,0)** | 2/2 | **0 / 0** |
| TitleScreen | **4 = EXPAND** | 1080x2337 | **(0,0)** | 1/1 | **0 / 0** |
| QuizzHomeScreen | **4 = EXPAND** | 1080x2337 | **(0,0)** | 5/5 | **0 / 0** |

**0 échec, exit 0.** Les pixels extrêmes portent du contenu réel, pas du noir
— vert marécage en haut sur les trois écrans monde, crème
`(1, 0.9725, 0.9451)` en haut ET en bas sur Quizz, exactement sa couleur de
thème. Rendus offscreen 1170x2532 confirmés **à l'œil** en plus du compte de
lignes noires.

⚠️ **Aucun étirement de fond** : les `CoverImage` sont en
`stretch_mode = 6` (KEEP_ASPECT_COVERED), donc un viewport plus haut **rogne**
latéralement au lieu de déformer — vérifié au rendu, les deux sujets
(écureuil/hibou) restent entiers.

### Sondes : 7 byte-identiques, et la 8ᵉ n'est pas déterministe

Diffées contre `origin/staging` en worktree séparé (import vérifié complet
des deux côtés : **24 `.scn`** chacun, le piège du faux rouge par import
tronqué est contrôlé, pas supposé), graine 20260806, `--fixed-fps 60` :
`ProbeTimeoutAudit` (**33 sondes**), `AssetContractAudit` (**12/12 visuels,
0/10 colliders déplacés**), `DeathModelAudit`, `ChargerShapeProbe`,
`AlarmRampAudit`, `ComboAudit`, `ShrinkAudit` — **BYTE-IDENTIQUES sur les
DEUX flux, exit 0 des deux côtés**.

⚠️ **`SwampIdentityAudit` DIFFÈRE, et ce n'est PAS une régression — la sonde
n'est pas déterministe.** Vérifié plutôt que supposé : **deux runs
consécutifs sur le MÊME arbre divergent autant que base vs branche**, et
`grep` confirme qu'elle **n'appelle ni `DevSeed.apply()` ni
`DecorRng.force_seed()`** — `--seed=20260806` y est **inerte**. Ce qu'elle
échantillonne est la dérive de teinte du sol (`_tint_rng := DecorRng.make()`,
`TrackSegment.gd`), non seedée et déjà documentée comme telle. Canal rouge de
`WORLD AT TITLE` sur 3 runs de chaque côté :

| | run 1 | run 2 | run 3 |
|---|---|---|---|
| baseline | 0,1526 | 0,1663 | 0,1771 |
| branche | 0,1690 | 0,1503 | 0,1809 |

**Les deux plages se chevauchent et chaque valeur d'un côté tombe à
l'intérieur de celle de l'autre.** Le critère réel pour une sonde non seedée
est son VERDICT : **6/6 runs `SWAMP_IDENTITY_VERIFIED=yes`, 4/4 états OK des
deux côtés.** Même famille de défaut que `TrackPropsAudit`, déjà consignée
plus haut ; **aucun seuil n'a été bougé.**

### Build

Éditeur + templates Godot 4.3-stable installés dans ce sandbox (releases
GitHub officielles). Import headless **exit 0** ; boot headless des cinq
scènes concernées (`LoginScreen`, `Hub`, `TitleScreen`, `QuizzHomeScreen`,
`Game`, `--quit-after 2`) **exit 0, 0 erreur GDScript** ; export Web release
**exit 0, 0 erreur**. `index.wasm` **35 376 909 octets**, md5
**`af4a8fc2925d992348eb30deeeb54360`** — **identique sur les DEUX arbres**,
donc c'est bien lui la preuve d'identité. `.pck` baseline **5 667 712** →
branche **5 668 192** (**+480 octets**, cohérent avec six éditions GDScript ;
offert en corroboration seulement, l'instabilité permanente du `.pck`
s'applique). Piège payload tenu : **0** ligne `Storing File` pour
`res://assets_source`, `res://docs`, `res://web`, `firebase.json` **ni
`res://build`**.

⚠️ **Piège d'outillage rencontré** : `godot4 --export-release` **ne crée pas**
le dossier de destination et échoue en `Target folder does not exist` — un
`rm -rf build` avant export (celui que la doc impose pour éviter
l'auto-contamination) doit donc être suivi d'un `mkdir -p build/web`.

### Reste ouvert — jugement device, seul juge

1. **La disparition réelle des bandes** sur iPhone Safari (onglet **et** PWA
   installée) sur les quatre écrans : aucune sonde de ce dépôt ne rend de
   pixels iOS, les rendus ci-dessus sont du llvmpipe sous xvfb.
2. ~~**Le rognage latéral des couvertures** en 19.5:9 : mesuré comme non
   déformant et les sujets entiers, mais le cadrage exact est un jugement.~~
   ⚠️ **CORRIGÉ ET CLOS le 19 août 2026 — « les sujets entiers » était FAUX** :
   ce rognage coupait la pancarte peinte « PLAYER: KEEPY / STATUS: CHASED »,
   dont le premier pixel passait de x=29 à **x=0** sur device (IMG_1888 vs
   IMG_1894). Voir la section « LA PANCARTE PEINTE ÉTAIT ROGNÉE PAR LE FIX
   LETTERBOX » en fin de fichier. Ce point est le seul des trois à avoir été
   mesuré faux plutôt que simplement laissé au jugement.
3. **Les panneaux descendent proportionnellement** dans un viewport plus haut
   (les `CenterContainer` ont un `anchor_top` fractionnel) — mesuré comme
   entièrement dans le viewport, marge en bas plus grande qu'avant, mais la
   composition à l'échelle réelle d'un téléphone reste à valider.

## LA PANCARTE PEINTE ETAIT ROGNEE PAR LE FIX LETTERBOX -- le crop de la couverture s'ancre desormais sur le CONTENU (19 aout 2026)

Branche `claude/pancarte-clipping-expand-x07ws4`, partie de `staging`
(`37e00fc`, donc **posee sur le lot letterbox du 18 aout**). Suite directe de
ce lot : `SafeArea.fill_screen()` a bien tue les bandes noires, et a rogne au
passage la pancarte « PLAYER: KEEPY / STATUS: CHASED » peinte dans le fond
foret. Un fichier nouveau (`scripts/ui/CoverArt.gd`), trois scenes recablees,
un commentaire de `SafeArea.gd` remis a jour. **Aucune scene de jeu, aucun
collider, aucune constante de gameplay, aucun `.glb`, aucun `.png` touche.**

### La cause, mesuree et pas deduite

L'art (`assets/textures/ui/title_cover.png`) fait **720x1280, soit 9:16
exactement**, et porte DEUX elements d'UI **peints** en haut : la pancarte a
gauche et le bandeau « KEEPY CHASED » au centre. Ce sont des pixels de fond,
pas des `Control` : rien dans l'arbre de scene ne les garde a l'ecran.

Tant que le canvas etait 9:16 lui aussi, `STRETCH_KEEP_ASPECT_COVERED` n'avait
**rien** a rogner. EXPAND fait passer le canvas a **1080x2337** sur un
1170x2532, donc COVERED se met a mettre l'art a l'echelle par la HAUTEUR et
rogne **117 px de canvas de CHAQUE cote**. La pancarte commence a **17 px du
bord gauche de la source** (31 px de canvas une fois mise a l'echelle) : elle
perd sa marge, et davantage.

⚠️ **Le defaut est dans `TextureRect`, pas dans un reglage oublie :
`STRETCH_KEEP_ASPECT_COVERED` CENTRE toujours sa region source** (Godot 4.3
calcule `region.position` comme la moitie du debordement) et **n'expose aucune
propriete d'alignement**. Aucune valeur de `stretch_mode` ne corrige donc ca.
Elargir le rect avec un offset statique ne marche pas non plus : le
debordement necessaire depend de la HAUTEUR du canvas, donc toute constante
qui cadre bien sur un 19.5:9 **rogne le haut de la pancarte sur un 16:9**.

### Ce que la sonde de mesure vaut : elle reproduit les DEUX chiffres device

Sonde jetable (jamais commitee, supprimee avant le commit -- `ProbeTimeoutAudit`
revient a **33 sondes**) : rendu offscreen sous `xvfb-run --rendering-driver
opengl3`, **sans `--headless`** (il force le driver DUMMY et tout lit noir,
faux-vert deja consigne), fenetre **1170x2532**, le vrai ratio device. Scan
identique au diagnostic device : premier pixel « chaud » (`luminance>70` et
`r>g+15`, bois/creme contre feuillage) depuis `x=0`, ligne par ligne.

| canvas | sonde ici | photo device |
|---|---|---|
| KEEP (avant fix letterbox) | **28** | **29** (IMG_1888) |
| EXPAND (apres fix letterbox) | **0** | **0** (IMG_1894) |

Un pixel d'ecart sur le premier, zero sur le second : le banc d'essai mesure
bien la meme chose que la photo, et c'est ce qui lui donne le droit de servir
de verdict sur les autres ecrans.

### Perimetre : TROIS ecrans, pas un -- verifie par rendu, pas par lecture

`grep` sur `title_cover` : exactement `Hub.tscn`, `TitleScreen.tscn`,
`LoginScreen.tscn`, chacun avec le meme noeud `CoverImage` (full-rect,
`expand_mode=1`, `stretch_mode=6`). Les trois ont ete **rendus** plutot que
deduits : **les trois mesurent 0** avant fix, **34** apres. `QuizzHomeScreen`
(fond `ColorRect` creme) et `GameOverScreen` (`ColorRect` translucide sur le
jeu) n'ont aucune couverture peinte -- hors sujet, confirme par le meme grep.

### La regle retenue, et pourquoi PAS l'option « sortir la pancarte du fond »

`scripts/ui/CoverArt.gd` : mise a l'echelle pour couvrir **exactement comme
avant**, puis la fenetre source est placee pour que la portee **PROTEGEE** --
tout ce qui est dessine plutot que decor -- soit centree dedans, clampee pour
que l'art ne cesse jamais de couvrir le canvas. Zone protegee mesuree dans les
pixels de l'art : **pancarte x 17..222**, **bandeau + feuilles x 237..519** --
donc le contenu concu est les **72 % gauche** de l'art, le reste est du
feuillage.

⚠️ **Le VERTICAL est laisse EXACTEMENT comme COVERED l'avait (centre).** Sur
tout canvas portrait l'echelle est pilotee par la hauteur, donc il n'y a
aucun rognage vertical et le choix est sans objet ; le changer deplacerait
quelque chose que ce lot n'a pas mesure.

⚠️ **L'option 2 du brief (recreer la pancarte en `Control` separe) a ete
ECARTEE SUR UNE MESURE, pas par preference** : la pancarte PEINTE reste dans
le fond, et une fois le fond rogne elle glisse de **117 px de canvas a gauche**
d'un overlay epingle a marge fixe -- il resterait une bande visible de bord de
pancarte peinte a cote de la propre. La retirer de l'art voudrait dire
**repeindre le feuillage derriere**, sur une illustration peinte.

### Ce que la mesure donne apres fix

| ecran | avant (EXPAND) | apres (EXPAND) | KEEP 9:16 |
|---|---|---|---|
| `Hub.tscn` | **0** | **34** | 28, inchange |
| `TitleScreen.tscn` | **0** | **34** | -- |
| `LoginScreen.tscn` | **0** | **34** | -- |

**Le rendu 9:16 est BYTE-IDENTIQUE avant/apres** (md5 `4cfc5d78...` des deux
cotes, capture complete 1170x2080) : la regle degenere en « aucun rognage » la
ou il n'y avait deja rien a rogner, ce n'est pas un argument, c'est le meme
fichier PNG. Cote droit : le bandeau garde **188 px** de marge apres fix.

**Balayage de robustesse, 4 ratios rendus** (1080x1920, 1170x2532, 1080x2640,
1600x900) : pancarte visible partout (**26 / 34 / 22 / 195**) et **aucune
colonne de fond `ColorRect` non couverte** a gauche ni a droite -- le clamp
tient, y compris sur un 9:22 plus extreme que n'importe quel telephone et sur
une fenetre desktop plus large que haute.

### L'assertion est prouvee ROUGE avant d'etre verte

`CoverArt._ready()` **asserte** `stretch_mode`/`expand_mode` au lieu de les
forcer en silence : la scene reste la source de verite sur la facon dont ce
noeud dessine, et une scene qui contredit son script est le piege « fixture
qui diverge du reel » qu'`AlarmRampAudit` existe pour fermer. Verifie en
remettant `stretch_mode = 6` dans `Hub.tscn` : `ERROR: CoverArt: stretch_mode
must be STRETCH_SCALE`, puis reverte.

### Validation

Import headless **exit 0**. Boot headless des trois scenes modifiees
(`--quit-after 2`) **exit 0**, aucun `push_error` de `CoverArt`.
`ProbeTimeoutAudit` (**33 sondes armees**, retour exact a la baseline apres
retrait de la sonde jetable), `AssetContractAudit` (**12/12 visuels, 0/10
colliders deplaces**), `DeathModelAudit`, `ChargerShapeProbe`,
`PursuerFramingAudit` (**37,1 % max**, la valeur deja consignee -- c'est la
reconfirmation « Chased non touche » demandee), plus les sondes gameplay
seedees `ComboAudit`/`ShrinkAudit`/`ChargerAudit` (graine 20260806) --
**toutes byte-identiques a `origin/staging`** sur les DEUX flux, en worktree
separe. C'est le bar attendu : aucune sonde ne charge un ecran d'UI, et le
seul fichier de ce lot qu'un probe touche (`SafeArea.gd`) ne recoit qu'un
commentaire.

### Dette de doc fermee au passage

`SafeArea.fill_screen()` documentait encore « their cover art is
KEEP_ASPECT_COVERED, so a taller viewport re-lays-out and re-crops rather than
stretching anything » -- vrai la veille, faux depuis ce lot, et surtout
**cette phrase decrivait comme inoffensif exactement le mecanisme qui cassait**.
Remplacee par le constat mesure, avec la consigne pour la suite : **tout NOUVEL
ecran qui appelle `fill_screen()` ET peint quelque chose pres d'un bord de son
fond a besoin du meme script** -- le canvas 9:16 qui rendait le crop centre
inoffensif n'existe plus.

### Reste ouvert -- jugement device, seul juge

Aucune sonde ne dit que la marge de **34 px** se lit bien a l'oeil sur un vrai
iPhone : le chiffre est mesure, l'equilibre visuel ne l'est pas. A confirmer
sur `keepy-staging.vercel.app`, sur les TROIS ecrans (login, hub, titre), en
onglet Safari **et** en PWA installee. Non touche par ce lot et toujours
ouvert : la redondance entre le bandeau peint « KEEPY CHASED » et le logo
`TitleLogo` du moteur, deja signalee au lot ecran-titre du 14 aout -- elle
devient plus visible maintenant que les deux tiennent l'ecran en entier.

