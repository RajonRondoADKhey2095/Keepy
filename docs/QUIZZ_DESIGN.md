# Keepy Quizz -- Visual Design System

Established 18 August 2026, branch `claude/keepy-quizz-visual-identity-9codta`.
Applies to Keepy Quizz screens only. Keepy Chased, the Hub, and LoginScreen
keep their existing wood/forest identity (dark brown panels, gold borders,
`SWAMP_SKY` green background) unchanged -- this system exists precisely to
give Quizz a distinct look, not to replace theirs.

## Why this exists

`QuizzHomeScreen.tscn` (18 Aug 2026, first real Quizz screen) shipped with
ad-hoc StyleBoxFlat resources copied from the Chased/Hub palette -- dark
brown panels, gold borders, white text on near-black. That is the Keepy
Chased identity leaking into a sub-game that has no reason to share it. This
lot replaces those local styleboxes with a dedicated Theme resource and
establishes the tokens below as the one place any future Quizz screen should
pull from.

**Rule for every future Quizz session: reuse `resources/themes/quizz_theme.tres`.
Do not create a second Quizz theme, and do not hand-roll StyleBoxFlat/font
overrides that duplicate what the theme already defines.** If a screen needs
a look the theme does not cover, extend the theme (add a type variation or a
style) rather than working around it locally -- that is exactly how
`QuizzHomeScreen.tscn`'s per-row cards and info panel are covered today.

## Palette

| token | hex | usage |
|---|---|---|
| Orange principal | `#FF8A5B` | primary buttons, action, shadow tint |
| **Corail Keepr** | **`#E8907F`** | **accent non-actionnable : rule de carte, soulignement de titre** |
| Peche pastel | `#FFDCC4` | field borders, info/warning panels, muted fills |
| Fond creme | `#FFF8F1` | screen background |
| Blanc | `#FFFFFF` | cards, input fields |
| Texte | `#4A3728` | all text, on every surface below |

### Contrast, measured (WCAG relative-luminance formula, not eyeballed)

| pair | ratio | verdict |
|---|---|---|
| Texte on Fond creme | 10.68:1 | pass (AA/AAA) |
| Texte on Blanc | 11.24:1 | pass (AA/AAA) |
| Texte on Peche pastel | 8.72:1 | pass (AA/AAA) |
| **Texte on Orange principal** | **4.84:1** | **pass (AA normal text)** |
| Blanc on Orange principal | 2.32:1 | **fails AA (needs 4.5:1)** |
| Texte on Corail Keepr | 4.67:1 | pass (AA normal text) |
| Blanc on Corail Keepr | 2.41:1 | **fails AA** -- meme verdict que sur l'orange |
| Corail on Blanc (accent non-texte) | 2.41:1 | voir la note corail plus bas |
| Corail on Fond creme (accent non-texte) | 2.29:1 | voir la note corail plus bas |
| **Corail vs Orange principal** | **1.04:1** | **luminances quasi identiques -- voir la note corail** |
| **Texte on Orange (chip selectionne)** | **4.84:1** | pass (AA) -- meme paire que le bouton |
| **Anneau texte `#4A3728` vs Fond creme** | **10.68:1** | pass 1.4.11 -- c'est LUI l'indicateur d'etat du chip |
| **Anneau texte `#4A3728` vs Orange (remplissage du chip)** | **4.84:1** | pass 1.4.11 |
| Orange vs Blanc, *comme seul* indicateur d'etat | 2.32:1 | **echoue 1.4.11** -- voir la section chips |

**Deviation from the original brief, measured and therefore taken:** the
brief's default instruction was white text on the orange button. Measured,
that pair is 2.32:1 -- well under WCAG AA for normal text (4.5:1) and even
under the large-text floor (3:1). Dark text (`#4A3728`) on the same orange
measures 4.84:1, comfortably over the AA floor. `quizz_theme.tres` therefore
sets **dark text on every Button state**, including the orange `normal`/
`hover`/`focus` styles -- not white. This follows the project's own standing
rule (see `CLAUDE.md`, repeatedly: "mesure, pas suppose") of measuring
before committing a color decision rather than taking an assumption at face
value when it disagrees with a real number. If a future palette pass darkens
the orange enough to clear 4.5:1 for white text, white becomes viable again
-- but that has to be measured at that point, not assumed now.

## Typography

- **Fredoka** (headings) -- variable font, OFL-licensed, from the
  `google/fonts` repository (`ofl/fredoka/Fredoka[wdth,wght].ttf`).
- **Quicksand** (body text) -- variable font, OFL-licensed, from the same
  source (`ofl/quicksand/Quicksand[wght].ttf`).

Both ship as a single variable `.ttf` under `assets/fonts/quizz/`
(`Fredoka-Variable.ttf`, `Quicksand-Variable.ttf`), each paired with its own
`OFL-*.txt` license file alongside it. Rather than exporting separate static
Regular/SemiBold/Bold files, `quizz_theme.tres` defines `FontVariation`
sub-resources that pin the `wght` axis on the one variable font file:

| variation | base font | weight | used for |
|---|---|---|---|
| `FontVariation_quicksand_regular` | Quicksand | 400 | body text, default `Label`/`LineEdit`/`PanelContainer` content |
| `FontVariation_quicksand_semibold` | Quicksand | 600 | reserved for future emphasis text (not yet consumed by a node) |
| `FontVariation_fredoka_semibold` | Fredoka | 600 | button labels, quiz-row card titles (`CardTitleLabel`) |
| `FontVariation_fredoka_bold` | Fredoka | 700 | screen title (`TitleLabel`) |

One `.ttf` per family is both licensing-simpler (one `OFL.txt` per family
covers every weight pulled from it) and avoids importing four to six separate
static font files for what a single variable font already contains.

## Shape language

- **Cards and panels**: 26px corner radius (`StyleBoxFlat_panel`,
  `StyleBoxFlat_info_panel`), white or peach background, no border -- a
  soft, low-opacity orange-tinted shadow (`shadow_color` alpha 0.14,
  `shadow_size` 14, `shadow_offset` `(0, 4)`) stands in for the
  border-heavy look Chased/Hub use.
- **Buttons**: pill-shaped, **32px** corner radius against the 64px button
  height this screen actually uses (`corner_radius = height / 2`, per the
  brief) -- orange fill, dark text, a tighter shadow on `normal` that grows
  slightly on `hover` to read as lift. ⚠️ **Corrige le 19 aout 2026** : ce
  paragraphe annoncait `height / 2` mais 28 etait livre. 32 le rend vrai --
  voir la section reskin en fin de fichier.
- **Text fields**: pill-shaped (28px radius), white fill, 2px peach border
  at rest, 2px orange border on focus -- no heavy border weight anywhere in
  the system, matching the "soft shadows over skeuomorphic borders" rule.
  ⚠️ **Depuis le 19 aout 2026 ceci decrit le style de BASE `LineEdit`
  seulement** (encore porte par `IndexUrlEdit`). Le champ de creation utilise
  la variation `SearchField`, sans fond ni bordure au repos parce qu'il vit
  DANS une barre -- voir la section reskin.
- **Quiz-row cards** (variation `QuizRowPanel`): the same white-card-plus-
  shadow recipe as `StyleBoxFlat_panel`, at a tighter 22px radius -- a list
  row is a smaller card in this system, not a different shape. ⚠️ **Depuis le
  19 aout 2026 c'est une variation du THEME, plus un `StyleBoxFlat` construit
  a la main dans `_build_row_style()`** (cette fonction n'existe plus).
- **Accent corail** (variation `AccentBar`) : une pill corail de 6px, la
  meme pour la rule verticale d'une carte et pour le soulignement horizontal
  du titre. Jamais actionnable -- voir la section reskin pour la mesure qui
  l'impose.

## Where it's applied today

`scenes/QuizzHomeScreen.tscn` is the only Quizz screen that exists as of
this lot. Its root `Control` carries `theme = quizz_theme.tres`; every
`Button`/`Label`/`LineEdit`/`PanelContainer` node either takes the theme's
base style directly or opts into one of the **eight** type variations
(`TitleLabel`, `CardTitleLabel`, `MutedLabel`, `InfoPanel`, plus
`SearchPanel`, `SearchField`, `QuizRowPanel`, `AccentBar` added by the
19 August 2026 reskin) defined in the theme resource. The screen's `Background` `ColorRect` is set to the cream
token directly (a `ColorRect` fill isn't themeable). No hand-authored
StyleBoxFlat remains in the `.tscn` file **nor in GDScript** -- the last one
(`_build_row_style()`, for dynamically-created quiz rows) became the
`QuizRowPanel` variation on 19 August 2026, so the "extend the theme" rule at
the top of this file now holds with no exception anywhere in the Quizz scope.

## Validation

Godot 4.3-stable editor installed in-sandbox for this lot (GitHub release,
same version the CI uses). `--headless --import`: exit 0, no errors.
Headless boot of `QuizzHomeScreen.tscn` (`--quit-after 2`): exit 0, no parse
or missing-node errors. A real offscreen render (`xvfb-run --rendering-driver
opengl3`, `Viewport.get_texture().get_image()`) was captured and inspected:
Fredoka title, Quicksand body/placeholder text, orange pill button with dark
readable text, cream background, white card with soft shadow -- no residual
Chased/Hub coloring anywhere on screen.

**Probes: verified non-applicable, not skipped.** `grep -rl "QuizzHomeScreen"
scripts/dev/` returns nothing -- no probe loads this scene, so none can be
affected by it. Rejouees quand meme, toutes exit 0 : `ProbeTimeoutAudit`
(33 sondes armees, chiffre inchange), `AssetContractAudit` (12/12 visuels,
0/10 colliders deplaces), `DeathModelAudit` (CHARGER seul fatal, capture au
2e contact pour les 5 autres types). Aucune ressource de gameplay (scene,
script, collider, .glb) n'est touchee par ce lot -- seuls
`resources/themes/quizz_theme.tres`, `assets/fonts/quizz/*`,
`scenes/QuizzHomeScreen.tscn` et `scripts/ui/QuizzHomeScreen.gd` changent.

---

## Reskin "dashboard" du 19 aout 2026

Branche `claude/quizz-home-screen-reskin-0ea4ab`, partie de `staging`.
**Reskin du contenu EXISTANT de `QuizzHomeScreen.tscn`, pas un nouvel
ecran.** La maquette de reference (fournie par Mathieu en description, elle
n'existe pas comme fichier dans ce depot) montre aussi des categories, un
avatar, un compteur de points et une nav du bas : **rien de tout cela n'est
ajoute** -- ces quatre elements sont structurellement absents du modele de
donnees (`docs/QUIZZ_SPEC.md`), donc les livrer serait inventer un produit,
pas reskin celui-ci. Ce qui est repris de la maquette est son LANGAGE :
cartes elevees, ombres douces, barre de recherche, hierarchie lisible.

`Chased`, `Hub`, `LoginScreen`, `TitleScreen` : **aucun fichier touche**. Le
fix safe-area/letterbox (`SafeArea.gd`) : **intouche**. `Quizz.gd` : **intouche**.

### Le corail est un accent, jamais une action -- et c'est une MESURE qui l'impose

`#E8907F` entre dans le systeme comme **quatrieme couleur**, et son role est
borne par deux chiffres mesures, pas par un gout :

1. **Corail vs Orange principal = 1,04:1.** Les deux couleurs ont une
   luminance quasi identique ; elles ne different que par la teinte et la
   saturation. **Consequence directe : le corail ne peut pas porter une
   action.** Un bouton corail pose sur le meme ecran qu'un bouton orange ne
   se lirait pas comme "un autre bouton", il se lirait comme le meme bouton
   mal teinte -- et pour un daltonien deutan, comme le meme bouton tout
   court. C'est exactement pourquoi **le bouton retour reste ORANGE** : le
   brief autorisait a le passer en corail, la mesure dit que ca n'achete
   aucune distinction et coute la coherence. Juge aussi au rendu offscreen
   avant d'etre tranche, comme le brief le demandait.
2. **Corail vs Blanc = 2,41:1**, sous le plancher 3,0:1 de WCAG SC 1.4.11
   pour un composant d'interface. **C'est assume, et c'est correct ici** :
   1.4.11 gate les elements qui IDENTIFIENT un controle ou son etat. La rule
   corail d'une carte et le soulignement du titre ne portent aucune
   information -- retires, l'ecran reste integralement utilisable et rien
   n'est ambigu. Point de comparaison utile plutot qu'une affirmation :
   **l'orange du bouton principal deja livre mesure 2,32:1 contre le blanc**,
   donc le corail est *legerement plus present* que la couleur la plus
   visible du systeme actuel. Il n'est pas timide, il est non-signalant.
3. **Texte `#4A3728` sur corail = 4,67:1**, AA texte normal. Le corail est
   donc utilisable comme fond de bouton **le jour ou il n'y a pas d'orange a
   cote** -- ce n'est pas le cas de cet ecran. Note pour un futur ecran
   Quizz : ce chiffre existe deja, ne pas le re-mesurer.

### Ce qui change, ecran par ecran

- **Barre de creation -> barre de recherche.** Le defaut du rendu precedent
  etait un blanc sur blanc : une carte blanche contenant un champ blanc
  borde de peche, donc deux surfaces pour un seul geste. La carte devient la
  BARRE (`SearchPanel` : pill radius 42, padding 10, ombre plus marquee --
  `shadow_size` 18 / alpha 0,16, c'est l'interaction principale de l'ecran)
  et le champ devient invisible dedans (`SearchField` : `draw_center = false`,
  aucune bordure au repos). Le bouton "Creer" est desormais **encastre a
  l'interieur** de la barre plutot que pose a cote. Un seul objet, un seul
  geste.
- **Focus du champ : le delta est PLUS FORT qu'avant, pas plus faible.**
  Le repos passe de "bordure peche 2px" a "aucune bordure" ; le focus reste
  la bordure orange 2px deja livree. Le changement percu passe donc de
  `1,29:1 -> 2,32:1` (peche->orange, deux bordures qui se ressemblent) a
  `rien -> 2,32:1`. **Verifie au rendu, pas deduit** : capture dediee de
  l'etat focus, l'anneau orange est sans ambiguite sur le champ nu.
- **Rangee de quiz : rule corail a gauche + respiration.** Marges verticales
  internes 14 -> 20, radius 20 -> 22, ombre 10/0,12 -> 12/0,13, separation
  entre rangees 12 -> 14, separation titre/date 4 -> 6.
  ⚠️ **La rule est une BARRE et pas le bloc de couleur plein que la maquette
  met a cet endroit** : ce depot n'a aucun jeu d'icones pour des rangees de
  quiz, et un bloc plein se lirait comme un emplacement qui attend un asset
  jamais livre. Une rule se lit comme finie. Aucun asset n'est genere dans ce
  lot. Elle est calee sur la HAUTEUR DU TEXTE (`SIZE_FILL`), pas sur celle de
  la carte -- mesure au rendu : **66 px physiques de haut pour 6 de large**,
  soit ~60 % de la hauteur de carte, alignee au bloc titre/date.
- **Titre : soulignement corail** (`HeaderUnderline`, 112x6, `AccentBar`).
  `HeaderLabel` gagne un `VBoxContainer` parent (`HeaderCol`) pour que la
  rule puisse se poser dessous ; **aucune propriete du label lui-meme ne
  change**, et `BackButton` reste au meme chemin de noeud (les `@onready` de
  `QuizzHomeScreen.gd` ne bougent pas).
- **Rayon des boutons 28 -> 32.** Ce document affirmait deja
  `corner_radius = height / 2` pour les boutons de 64 px de cet ecran, mais
  28 etait livre -- l'affirmation etait fausse. 32 la rend vraie : le
  `BackButton` 64x64 devient un vrai **cercle** (idiome de la maquette), le
  bouton "Creer" une pill pleine. Godot clampe le rayon a la moitie du plus
  petit cote, donc le `CopyUrlButton` (56 de haut) reste une pill a son
  propre 28 au lieu de se deformer.

### `_build_row_style()` n'existe plus -- la regle de ce document est appliquee

La carte de rangee etait le seul `StyleBoxFlat` encore ecrit a la main, dans
`QuizzHomeScreen.gd`. Ce document la documentait comme une exception
acceptee. Elle devient **`QuizRowPanel`**, une variation de type du theme,
et la rule devient **`AccentBar`** -- donc `_build_row()` ne construit plus
aucun style, il pose deux `theme_type_variation`. **Il ne reste plus un seul
`StyleBoxFlat` hand-roll dans tout le perimetre Quizz**, ce que la regle en
tete de ce fichier demandait sans que l'ecran l'ait encore atteint.

`AccentBar` sert **a la fois** la rule verticale des cartes et le
soulignement horizontal du titre : une seule variation, un seul token
corail, plutot que deux styles jumeaux qui pourraient deriver.

⚠️ **Ce qui change dans `QuizzHomeScreen.gd` est strictement de la
PRESENTATION** : `_build_row()` (structure des noeuds d'une rangee) et la
suppression de `_build_row_style()`/`_row_style`. **Aucun chemin CRUD,
signal, busy-state ou erreur n'est touche** -- `_on_create_pressed`,
`_on_quiz_created`, `_on_quizzes_fetched`, `_set_busy`, `_show_error`,
`_extract_index_url`, `_format_timestamp` sont byte-identiques.

### Validation

Editeur + templates Godot 4.3-stable installes dans ce sandbox (releases
GitHub officielles, memes que la CI). Import headless **exit 0**, export Web
release **exit 0**.

**Rendu offscreen REEL au ratio device** (`xvfb-run --rendering-driver
opengl3`, **1170x2532**, pas 9:16 -- la lecon deja consignee dans
`CLAUDE.md`). Sonde de capture jetable, **jamais commitee, supprimee avant le
commit** : `ProbeTimeoutAudit` revient a **33 sondes**, sa baseline exacte.
Le viewport mesure **1080x2337** pour une image de **1170x2532**, ce qui
confirme au passage que `SafeArea.fill_screen()` (`CONTENT_SCALE_ASPECT_
EXPAND`) fait bien son travail : la largeur de design 1080 est tenue, c'est
la hauteur qui s'etend. Deux passes capturees : etat nominal (3 rangees
injectees) **et** etat focus + busy -- ce dernier parce que `_ready()`
appelle `_refresh_list()`, donc **l'etat desactive est le tout premier que
voit n'importe quel joueur**, jamais un cas limite.

⚠️ **Signale, non corrige, et PRE-EXISTANT** : le bouton "Creer" desactive
est peche sur panneau blanc, soit **1,29:1** -- tres doux. Ce n'est pas une
regression de ce lot (l'ancien panneau etait blanc lui aussi, meme paire),
et son libelle sombre reste lisible ; verifie au rendu de l'etat busy. A
traiter dans un lot qui aurait le droit de bouger la couleur `disabled`.

**Sondes : 4 rejouees, les QUATRE byte-identiques sur les DEUX flux**
(stdout ET stderr) contre `origin/staging`, graine 20260806, `--fixed-fps 60`
-- `ProbeTimeoutAudit` (33 sondes armees), `AssetContractAudit` (12/12
visuels, 0/10 colliders deplaces), `DeathModelAudit`, `ChargerShapeProbe`.
Non-applicabilite **verifiee et pas supposee** : `grep -rl "Quizz\|quizz_theme"
scripts/dev/` ne rend rien, aucune sonde ne charge cet ecran ni ce theme.
Blast radius du theme verifie de la meme facon : `quizz_theme.tres` n'est
reference que par `scenes/QuizzHomeScreen.tscn` (l'autre occurrence, dans
`SafeArea.gd`, est un commentaire), donc le rayon 28->32 ne peut atteindre
aucun autre ecran.

**Fingerprint compare a l'existant, meme session et meme toolchain** (la
seule comparaison valable, cf. la mise en garde permanente sur l'instabilite
du `.pck`) : baseline exportee depuis l'arbre `origin/staging` propre, puis
l'arbre de ce lot.

| | baseline `staging` | ce lot |
|---|---|---|
| `index.wasm` | 35 376 909 | **35 376 909** (md5 `af4a8fc2...`, **identique**) |
| `index.js` | md5 `4e08904b...` | **identique** |
| `index.pck` | 5 669 744 | 5 671 184 (**+1 440 o**) |

`index.wasm` et `index.js` **md5-identiques** : aucun code moteur touche,
et c'est EUX la preuve d'identite, jamais le `.pck`. Les +1 440 octets sont
coherents avec 5 `StyleBoxFlat` et 4 variations de type ajoutes au theme.
Piege payload tenu : **0** ligne `Storing File: res://assets_source`.

### Reste ouvert -- jugement device, seul juge

Aucune sonde ne dit que c'est BEAU. Ce qui doit etre regarde sur telephone :
(a) la barre de recherche se lit-elle bien comme UN objet et le bouton
"Creer" comme encastre dedans, et non comme un bouton qui deborde ; (b) la
rule corail se lit-elle comme un accent volontaire ou comme un residu
graphique a cette taille ; (c) le bouton retour circulaire orange ne
concurrence-t-il pas visuellement le "Creer" orange sur le meme ecran --
c'est la seule chose que la mesure `1,04:1` ne tranche PAS, puisqu'elle
compare corail et orange, pas orange et orange. Et la redondance de fond
deja notee ailleurs reste entiere : cet ecran n'a toujours ni categories, ni
points, ni avatar, ni nav du bas -- **volontairement**, ils sont hors du
modele de donnees.


## Categories, chips et CTA -- lot du 19 aout 2026

Branche `claude/keepy-categories-filtering-0mnv5s`, partie de `staging`.
**Trois patterns visuels nouveaux** (`CtaButton`, `Chip`, `ChipSelected`)
plus une variation de titre (`SectionLabel`), tous ajoutes au theme
existant -- **aucun `StyleBoxFlat` ecrit a la main**, ni dans le `.tscn`
ni en GDScript, donc la regle en tete de ce document tient toujours sans
exception. Le theme passe de **8 a 12 variations de type**.

`Chased`, `Hub`, `LoginScreen`, `TitleScreen` : **aucun fichier touche**.

### L'etat SELECTIONNE d'un chip est porte par un ANNEAU SOMBRE, pas par le remplissage orange

C'est le seul vrai arbitrage visuel du lot, et il est tranche par une
mesure, pas par un gout. Un chip selectionne doit etre distinguable d'un
chip au repos, et WCAG SC 1.4.11 demande **3,0:1** a l'information qui
identifie l'etat d'un composant.

La solution evidente -- remplir le chip selectionne en orange et laisser
les autres en blanc -- **echoue** : orange `#FF8A5B` contre blanc mesure
**2,32:1**, et contre le fond creme **2,21:1**. Aucune des deux ne
franchit 3,0. C'est le meme plafond que la note corail deja consignee
plus haut : dans cette palette, orange et corail sont des couleurs
**claires**, elles ne peuvent pas porter un ecart de luminance.

Le chip selectionne porte donc **en plus** une bordure de 2px en
`#4A3728` -- la couleur de texte du systeme, deja presente partout. C'est
elle l'indicateur d'etat, et elle passe des deux cotes a la fois :

| frontiere | ratio mesure | seuil 1.4.11 |
|---|---|---|
| anneau `#4A3728` vs fond creme (a l'exterieur) | **10,68:1** | pass |
| anneau `#4A3728` vs remplissage orange (a l'interieur) | **4,84:1** | pass |
| *(pour comparaison)* remplissage orange vs chip blanc | 2,32:1 | **echoue** |

⚠️ **Mesure faite sur les PIXELS REELLEMENT RENDUS, pas sur les constantes
du theme** : le rendu offscreen 1170x2532 a ete echantillonne le long de
la ligne du chip selectionne, et l'anneau y rend exactement `(74, 55, 40)`
-- `#4A3728` au bit pres, aucune derive d'anti-aliasing sur la partie
droite du trait. Les ratios ci-dessus sont calcules sur cette valeur lue,
pas sur celle ecrite dans le `.tres`.

Le repos garde la bordure peche 2px du langage de champ deja etabli
(peche vs creme = **1,22:1**, tres doux) -- c'est volontaire : ce qui doit
sauter aux yeux est **quel** chip est actif, pas le fait qu'il existe
cinq chips.

⚠️ **Ecart assume avec la regle « soft shadows over skeuomorphic
borders »** : un anneau sombre est le seul trait franc du systeme Quizz.
Il est a la meme epaisseur (2px) que l'anneau de focus orange des champs
deja livre, il ne concerne qu'un composant de 56px de haut, et il est
**impose par une mesure** -- exactement le motif que ce document invoque
deja pour avoir choisi du texte sombre sur bouton orange contre l'avis du
brief d'origine.

### Le CTA sort de la barre de recherche -- et ca REVIENT sur une decision du 19 aout au matin

Le reskin « dashboard » du meme jour avait **encastre** le bouton « Creer »
a l'interieur de la barre, argument a l'appui : « un seul objet, un seul
geste ». Ce lot l'en **ressort** et en fait une pill orange pleine largeur
sous la barre (`CtaButton` : radius 38 pour 76px de haut, donc
`height / 2` exactement, ombre 18 / alpha 0,30, Fredoka bold 30).

**Les deux decisions ne se contredisent pas, la demande a change** : le
bouton encastre s'appelait « Creer » et faisait 150px de large. Il devient
« **Creer ton quizz** », un libelle qui ne rentre pas dans une barre de
1008px sans ecraser le champ de titre -- et surtout un libelle qu'on
n'ecrit pas sur un bouton de soumission de formulaire. Le brief de ce lot
demande explicitement qu'il cesse de se lire comme tel. Un CTA pleine
largeur est ce que ca veut dire.

⚠️ Ce que ca **ne** change pas : c'est le **meme noeud**, le meme signal,
le meme `_on_create_pressed()`. Aucune logique de creation n'est dupliquee
-- seuls sa place dans l'arbre (`Margin/VBox/CreateButton` au lieu de
`Margin/VBox/CreatePanel/CreateRow/CreateButton`) et sa variation de theme
changent. Le champ de titre + le bouton restent le mecanisme reel de
creation, comme le brief l'exige.

Un `CreateHintLabel` (variation `MutedLabel`) sous le CTA dit ou le
prochain quizz sera range (« Nouveau quizz range dans : Histoire »).
Sans lui, le lien entre le chip selectionne et `create_quiz()` serait
invisible : il faudrait creer un quizz pour le decouvrir.

### Le reste, sans surprise

- **Barre « nouvelle categorie »** : `SearchPanel` + `SearchField`
  **identiques** a la barre de titre de quizz -- meme variation, meme
  radius, meme ombre. Le brief demandait « style identique au champ titre
  de quizz », et le respecter litteralement evite d'inventer un cinquieme
  objet. Son bouton « Ajouter » reste le bouton orange de BASE (140x60) :
  la hierarchie entre lui et le CTA se fait par la **taille** et le
  **libelle**, jamais par la couleur -- le corail ne peut pas porter une
  action (1,04:1 contre l'orange, deja mesure et deja consigne).
- **`SectionLabel`** : Fredoka semibold 26, entre le `TitleLabel` de
  l'ecran (bold 32) et le `CardTitleLabel` d'une rangee (semibold 26 mais
  dans une carte blanche). Porte le « Mes quizz » au-dessus de la liste.
- **Rangee de chips** : `ScrollContainer` horizontal, `horizontal_scroll_
  mode = 3` (SHOW_NEVER). ⚠️ **Corrige au rendu, pas prevu** : le premier
  jet etait en SHOW_ALWAYS et posait une barre de defilement grise pleine
  largeur sous les chips -- le seul element gris de tout l'ecran. Le drag
  tactile fonctionne toujours sans elle.
- **Aucun asset genere.** Pas d'icone par categorie : coherent avec la
  regle deja etablie pour la rule corail des rangees (ce depot n'a aucun
  jeu d'icones, et un emplacement vide se lit comme un asset qui n'arrive
  jamais).

### Validation

Editeur + templates Godot 4.3-stable installes dans ce sandbox (releases
GitHub officielles, memes que la CI). Import headless **exit 0**, export
Web release **exit 0**, boot headless de `QuizzHomeScreen.tscn`
(`--quit-after 3`) **exit 0** -- son unique sortie est le
`push_warning("categories unavailable (network-disabled)")` attendu, la
degradation propre du court-circuit headless de `Quizz.gd`.

**Rendu offscreen REEL au ratio device** (`xvfb-run --rendering-driver
opengl3`, **1170x2532**), sonde de capture jetable **jamais commitee,
supprimee avant le commit**. Quatre etats captures, pas un :
- **nominal** (3 categories, 5 quizz dont un sans categorie et un a
  `categoryId` PENDANT) -- le chip « Sans categorie (2) » compte bien les
  deux, ce qui prouve au rendu la resolution decrite au
  `QUIZZ_SPEC.md` 11.2 ;
- **filtre sur une categorie** -- liste reduite a 1, chip selectionne
  lisible, hint passe a « range dans : Histoire » ;
- **filtre « Sans categorie »** ;
- **busy**, parce que `_ready()` lance un chargement : c'est le **tout
  premier** etat que voit n'importe quel joueur, jamais un cas limite.

⚠️ **Signale, non corrige, PRE-EXISTANT et deja consigne au lot
precedent** : les boutons desactives sont peche sur blanc (**1,29:1**).
Le CTA desactive herite du meme defaut, en plus grand. Ce n'est pas une
regression de ce lot ; il appartient a un lot qui aurait le droit de
bouger la couleur `disabled`.

### Reste ouvert -- jugement device, seul juge

Aucune sonde ne dit que c'est BEAU. Ce qui doit etre regarde sur
telephone : (a) le CTA pleine largeur ecrase-t-il la barre de titre
juste au-dessus, ou la hierarchie se lit-elle bien dans l'autre sens ;
(b) l'anneau sombre du chip actif se lit-il comme « selectionne » ou
comme « en erreur » a taille reelle -- la mesure dit qu'il est VISIBLE,
elle ne dit pas ce qu'il SIGNIFIE pour un oeil ; (c) **la redondance
« Mes questionnaires » (titre d'ecran) / « Mes quizz » (titre de
section)** -- deux noms pour la meme chose a 200px d'ecart, releve ici
plutot que tranche : le brief demandait explicitement les deux, et
choisir lequel supprimer est une decision produit, pas technique.

## Matiere : le reflet "shiny", les proportions de bloc, et pourquoi StyleBoxFlat ne suffit pas (19 aout 2026)

Branche `claude/quizz-home-cta-redesign-6f3a3g`, partie de `staging`.
Retour device sur le CTA livre le matin meme : **ce n'est pas la palette
qui etait rejetee, c'est la FORME**. Mesure sur capture : le bouton
« Creer ton quizz » faisait **~90px de haut sur ~1000px de large**
(ratio ~1:11) et touchait les deux bords de l'ecran -- il se lisait comme
une **barre**, pas comme un bloc. Les deux lots precedents avaient livre
« coins larges + ombre douce » : insuffisant, parce que la PROPORTION et
la MATIERE manquaient, et aucune des deux ne s'obtient en elargissant un
rayon de coin.

### La regle de proportion, pour tout futur bloc d'action Quizz

| propriete | valeur | pourquoi |
|---|---|---|
| largeur | **60-70 % de la largeur disponible**, bloc CENTRE | un bloc qui touche les deux bords se lit comme une barre de systeme, quelle que soit sa hauteur |
| ratio largeur/hauteur | **entre 1:2 et 1:4** | 1:11 est une barre ; la carte de reference du brief est proche de 1:2 |
| deux niveaux de texte | libelle Fredoka bold + sous-titre Quicksand semibold | c'est le second niveau qui fait qu'un bloc est un bloc et pas un bouton grandi |
| rayon de coin | ~1/4 a 1/5 de la hauteur (**44px pour 200px**) | `height / 2` est une PILL ; un bloc garde un coin lisible comme un coin |

Livre : **672 x 200 unites de design**, soit **728 x 217 px** rendus a
1170x2532, **ratio 1:3,36**, marges laterales **221px des deux cotes**
(centre au pixel), **62,2 %** de la largeur d'ecran. Le libelle est
« Creer ton quizz » / « Cree tes propres questionnaires ».

⚠️ **Le CTA n'est plus un `Button` a `text`** : ses deux niveaux vivent
dans des `Label` enfants (`CtaTitleLabel` / `CtaSubLabel`), parce qu'un
`Button` n'a qu'une typographie. Consequence non evidente et **corrigee
plutot que decouverte sur device** : `font_disabled_color` ne les atteint
plus, donc un CTA occupe serait reste plein contraste sur son fond peche
desactive et se serait lu comme encore pressable. `_set_busy()` attenue
donc explicitement `CtaText.modulate` -- purement presentationnel, a cote
du `disabled` qu'il posait deja.

### Le reflet : GradientTexture2D superpose, et pourquoi il n'y a pas d'alternative

**`StyleBoxFlat` ne sait PAS faire de degrade** : `bg_color` est un aplat,
il n'existe aucune propriete de rampe. La matiere passe donc
obligatoirement par une **seconde couche** superposee au remplissage :
un `TextureRect` portant une **`GradientTexture2D`**, ressource **generee
par le moteur** -- aucun fichier image produit, aucun asset externe, la
contrainte « pas de nouvel asset » de ce chantier reste tenue.

Deux ressources partagees, dans `resources/gradients/` :

| ressource | couleur | sens | consommateurs |
|---|---|---|---|
| `quizz_shine_cta.tres` | blanc, alpha **0,58 -> 0** | depuis le **milieu du bord HAUT** | le CTA |
| `quizz_shine_card.tres` | peche `#FFDCC4`, alpha **0,62 -> 0** | depuis le **milieu du bord BAS** | cartes de la liste, les deux barres |

⚠️ **Le sens s'inverse sur les surfaces blanches, et c'est une contrainte,
pas un gout : du blanc semi-transparent sur du blanc est invisible par
construction.** C'est donc la peche pastel -- token deja au catalogue,
**aucune couleur nouvelle** -- qui monte par le bas. La lecture a l'oeil
reste la meme des deux cotes (« clair en haut, chaud en bas ») et reste
mesurable au pixel.

### ⚠️ VERIFIE SOUS `gl_compatibility`, PAS SUPPOSE -- et les deux premieres tentatives de masquage ont ECHOUE

Ce depot a un precedent de fonctionnalite de rendu silencieusement inerte
dans ce renderer, donc rien n'a ete pris pour acquis. Sonde de recon
jetable, `xvfb-run --rendering-driver opengl3` :

1. **`GradientTexture2D` rend correctement sous `gl_compatibility`** --
   delta vertical mesure 0,42 sur un bloc orange temoin. Aucun blocage.
2. **Le masquage des coins, lui, a demande trois essais**, et le brief
   avait raison de le nommer « a verifier au rendu, pas a supposer » :

| tentative | resultat mesure |
|---|---|
| degrade LINEAIRE plein cadre, sans masque | **ECHEC** : l'alpha est maximal exactement la ou vivent les coins arrondis -> **« oreilles » carrees claires** visibles hors du bloc (et, sur les cartes, un epaulement peche carre sous chaque coin bas) |
| `clip_children = CLIP_CHILDREN_AND_DRAW` | **masque correctement** (coin releve a `rgb(255,247,240)`, la creme exacte) **mais decoupe l'ombre du bloc au rectangle englobant** -> halo rectangulaire pale autour du CTA. Inutilisable tel quel |
| **degrade RADIAL centre sur le milieu du bord** | **RETENU** : l'alpha retombe a ~4 % avant d'atteindre le moindre coin. **La forme du reflet resout le masquage au lieu de le demander a un masque** |

**Regle pour tout futur reflet Quizz : `fill = 1` (RADIAL),
`fill_from` sur le milieu du bord d'ou vient la lumiere, `fill_to` a
0,55.** Pas de `clip_children`, pas de shader, pas de masque genere.
Un rayon de 0,55 laisse au coin le plus proche une distance normalisee de
0,5, soit ~91 % du rayon, donc un alpha residuel de l'ordre de 4 % --
invisible sur creme, et surtout **independant du rayon de coin choisi**,
ce qui rend la recette reutilisable sans re-mesurer a chaque bloc.

⚠️ **Une contrainte de structure va avec, et elle a coute un rendu pour
etre trouvee : un `PanelContainer` insete TOUS ses enfants de son
`content_margin`, y compris le reflet.** Le degrade s'arretait donc a
16-26px du bord avec une ligne franche. Le padding est desormais porte par
un `MarginContainer` a l'interieur du panneau (`CreatePad`, `CategoryPad`,
et le `pad` construit par `_build_row()`), et les `StyleBoxFlat`
`row_panel` / `search_panel` n'ont plus **aucun** `content_margin`. Tout
futur panneau Quizz qui veut une matiere doit suivre ce patron.

### Ombres renforcees, padding elargi

| stylebox | avant | apres |
|---|---|---|
| CTA (`cta_*`) | rayon 38, ombre 18 / alpha 0,30 / offset (0,6), padding 28/14 | **rayon 44, ombre 28 / alpha 0,42 / offset (0,12), padding 34/26** |
| carte de rangee (`row_panel`) | rayon 22, ombre 12 / alpha 0,13 / offset (0,4), padding 20-22 | **rayon 26, ombre 20 / alpha 0,20 / offset (0,7), padding 24-28 (via MarginContainer)** |
| barres (`search_panel`) | ombre 18 / alpha 0,16 / offset (0,5), padding 10 | **ombre 26 / alpha 0,24 / offset (0,8), padding 16 (via MarginContainer)** |

### Contraste RE-MESURE sur les pixels rendus, au point le PLUS CLAIR

Le reflet eclaircit le fond, donc le contraste texte/fond **change dans sa
zone** -- il a ete mesure la, pas seulement au centre :

| surface | fond rendu | texte `#4A3728` |
|---|---|---|
| CTA, point le plus clair du reflet | `rgb(255,204,183)` | **7,80:1** |
| CTA, bas du bloc (orange nu) | `rgb(255,138,91)` | **4,84:1** -- la valeur deja documentee, inchangee |
| carte / barre, haut (blanc nu) | `rgb(255,255,255)` | **11,24:1** |
| carte / barre, bas (peche montante) | `rgb(255,237,224)` | **9,88:1** |

**Le reflet ne peut qu'AMELIORER le contraste sur le CTA** (il eclaircit
un fond deja clair sous un texte sombre) et le degrade au pire de 11,24 a
9,88 sur les surfaces blanches -- tres au-dessus du plancher AA de 4,5:1
dans les quatre cas. Aucun plancher n'a ete deplace.

⚠️ **Signale, non corrige, PRE-EXISTANT** : le fond `disabled` reste peche
sur blanc (1,29:1 pour la bordure). Ce lot ne bouge pas la couleur
`disabled`, il se contente d'attenuer le TEXTE du CTA avec elle.

## Remise a la cible de l'accueil + parcours de creation complet (20 aout 2026)

Branche `claude/quizz-creation-editor-o5t3en`, partie de `staging`.
Les lots precedents avaient procede par ajouts successifs sans jamais
specifier l'ecran cible : l'accueil portait SEPT familles d'elements la ou
la cible en veut DEUX (le CTA et la liste). Ce lot remet l'accueil a la
cible et construit le parcours complet de creation (ecran de creation,
editeur de questions).

### REGLE PERMANENTE : l'accueil ne porte que le CTA et la liste

`QuizzHomeScreen.tscn` contient exactement QUATRE familles d'elements
visibles : le titre d'ecran ("Mes Quizz" + soulignement corail), le bouton
retour, le bloc CTA "Creer ton quizz" (forme et matiere du lot du 19 aout
CONSERVEES telles quelles -- bloc centre 672x200, reflet radial, ombre
marquee : cette forme est validee device), et la liste des quizz. TOUT
ajout d'element a cet ecran est une deviation de la cible et doit etre
argumente contre cette regle, pas empile dessus. Le `StatusLabel` (texte
vide au repos), l'`IndexHelpPanel` (visible uniquement sur le 400
FAILED_PRECONDITION documente du tout premier lancement) et l'`EmptyLabel`
(visible uniquement quand la liste est vide) ne sont pas des elements de
plus : ils sont invisibles a l'etat nominal.

Ce qui a ETE RETIRE de l'accueil par ce lot -- ne pas le "restaurer" :
le champ "Titre du questionnaire" et son bouton "Creer", le hint de
rangement, le champ "Nouvelle categorie" et son bouton "Ajouter", le label
"Categories indisponibles", le titre "Mes questionnaires", le label de
section "Mes quizz", et les chips de filtre. La creation et les categories
vivent desormais sur `QuizzCreateScreen` ; le filtrage par categorie n'a
plus d'ecran (a re-poser le jour ou la liste devient longue, comme une
decision produit, pas comme un retour de l'ancien accueil).

Le mot "questionnaire" a disparu de toute l'UI Quizz : le terme est
"quizz" partout. (La caption du Hub -- "Cree et gere tes questionnaires"
-- est HORS de ce perimetre : le Hub est contractuellement intouchable par
ce lot, l'occurrence est signalee au rapport plutot que corrigee en
douce.)

### Les trois ecrans du parcours

| ecran | scene | contenu |
|---|---|---|
| accueil | `QuizzHomeScreen.tscn` | titre, retour, CTA, liste ; tap sur une carte -> editeur |
| creation | `QuizzCreateScreen.tscn` | champ titre (obligatoire), categorie optionnelle (chips + creation sur place), "Creer le quizz" ; a la validation -> editeur du quizz frais |
| editeur | `QuizzQuestionsScreen.tscn` | titre du quizz en tete, liste des questions, formulaire d'ajout a TROIS panneaux de format (QCM / Vrai ou faux / Reponse libre) |

L'annulation de la creation est le bouton retour : rien n'est persiste
avant "Creer le quizz", donc quitter EST annuler -- pas de bouton
"Annuler" a garder en phase avec le retour.

### `QuizRowButton` -- une carte de liste devient pressable (13e variation)

Une rangee de quizz ouvre l'editeur, donc elle devient un `Button`. La
variation `QuizRowButton` reutilise le stylebox `row_panel` EXISTANT pour
`normal`/`hover`/`focus`/`disabled` et un nouveau `StyleBoxFlat_row_
pressed` (remplissage peche `#FFDCC4`, token deja au catalogue -- aucune
couleur nouvelle) pour le retour visuel du tap. Consequence structurelle
consignee dans `_build_row()` : un Button ne se dimensionne pas sur ses
enfants comme un PanelContainer, donc la rangee porte une hauteur minimale
explicite (128) et son contenu s'ancre au rect complet -- le meme patron
que le CTA. Les rangees de QUESTIONS de l'editeur, elles, restent des
`PanelContainer` : rien ne s'ouvre en les tapant dans ce lot, et un
control pressable qui ne fait rien est exactement le "controle mort" que
l'assertion du Hub existait pour interdire.

### Contraste, RE-MESURE sur les pixels rendus (1170x2532, opengl3)

| paire (nouvelle surface de ce lot) | ratio mesure | verdict |
|---|---|---|
| texte sur orange ("Ajouter la question", "Creer le quizz", CTA) | 4,84:1 | AA |
| texte sur blanc (cartes, champs du formulaire) | 11,24:1 | AA/AAA |
| texte sur creme (titres de section) | 10,68:1 | AA/AAA |
| anneau du chip selectionne (formats, reponses, categories) | 4,84:1 vs orange / 10,68:1 vs creme | 1.4.11 |
| hint "Categories indisponibles..." (ecran creation, degrade) | **8,63:1** | AA/AAA |

Le hint de degradation avait d'abord ete pose en `MutedLabel` (3,27:1
mesure au rendu) : il porte une vraie information (pourquoi les chips
manquent), donc il est passe en Label plein contraste AVANT livraison
plutot que consigne comme dette. ⚠️ **Pre-existant, signale, non touche** :
la variation `MutedLabel` elle-meme (dates des cartes, badges "Question N
-- format") mesure 3,50:1 sur blanc -- le meme token alpha 0,62 que les
lots precedents livrent deja ; le bouger est une decision de palette qui
depasse ce lot.
