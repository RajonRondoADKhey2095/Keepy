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
| Orange principal | `#FF8A5B` | primary buttons, accents, shadow tint |
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
- **Buttons**: pill-shaped, 28px corner radius against the 64px button
  height this screen actually uses (`corner_radius = height / 2`, per the
  brief) -- orange fill, dark text, a tighter shadow on `normal` that grows
  slightly on `hover` to read as lift.
- **Text fields**: pill-shaped (28px radius), white fill, 2px peach border
  at rest, 2px orange border on focus -- no heavy border weight anywhere in
  the system, matching the "soft shadows over skeuomorphic borders" rule.
- **Quiz-row cards** (`QuizzHomeScreen._build_row_style()`, built at runtime
  since rows are dynamic): the same white-card-plus-shadow recipe as
  `StyleBoxFlat_panel`, at a tighter 20px radius/margin -- a list row is a
  smaller card in this system, not a different shape.

## Where it's applied today

`scenes/QuizzHomeScreen.tscn` is the only Quizz screen that exists as of
this lot. Its root `Control` carries `theme = quizz_theme.tres`; every
`Button`/`Label`/`LineEdit`/`PanelContainer` node either takes the theme's
base style directly or opts into one of the four type variations
(`TitleLabel`, `CardTitleLabel`, `MutedLabel`, `InfoPanel`) defined in the
theme resource. The screen's `Background` `ColorRect` is set to the cream
token directly (a `ColorRect` fill isn't themeable). No hand-authored
StyleBoxFlat remains in the `.tscn` file itself; the one StyleBoxFlat built
in GDScript (`_build_row_style()`, for dynamically-created quiz rows) uses
the same tokens and is documented above rather than treated as an exception.

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
