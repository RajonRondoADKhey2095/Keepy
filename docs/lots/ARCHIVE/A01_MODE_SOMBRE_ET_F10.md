# ARCHIVE — mode sombre par inversion, et les deux décisions de teinte F10

> Extrait de `CLAUDE.md` par le LOT H (2 septembre 2026), **verbatim** : aucune ligne réécrite, résumée ni supprimée.
> 2 section(s), 280 lignes d'origine.
> Doctrine permanente : voir `CLAUDE.md`. Index des chantiers : `docs/lots/INDEX.md`.

## Mode sombre : REFONTE MARÉCAGE — l'inversion est supprimée (11 août 2026)

> ⚠️ **SECTION HISTORIQUE, DÉPASSÉE PAR LE LOT « DIRECTION ARTISTIQUE
> PERMANENTE » CI-DESSUS (même jour).** Elle décrit le marécage comme une
> PHASE rendue par un grade plein écran. Les deux ont disparu : il n'y a
> plus ni phase sombre ni shader de grade. Conservée pour les mesures et
> les pièges qu'elle porte, pas comme description du jeu actuel.

Branche `claude/dark-mode-swamp-refactor-8eoo0q`. **Refonte destructive
assumée, validée explicitement par Mathieu.** Remplace d'un bloc
l'inversion plein écran + les 6 teintes, ET les deux tentatives qui
essayaient de les contourner.

**SUPPRIMÉS** : `assets/shaders/screen_invert.gdshader`,
`scripts/world/NightSky.gd`, `scripts/world/DepthFog.gd`,
`GameState.DARK_VARIANTS`, `GameState.DARK_TINT_AMOUNT`,
`dark_variant_index`, `_reroll_dark_variant()`, `InvertCapture.gd`.
**INCHANGÉS** : `dark_intensity`, `dark_phase`, `DARK_CYCLE_PERIOD_S`,
`DARK_FADE_DURATION_S`, `_update_dark_cycle` — c'est le RENDU qui est
refait, pas le rythme.

**Pourquoi c'était structurel et pas un réglage.** Sous l'ancien pipeline
`mix(1.0 - src, tint, 0.55)`, **la couleur écrite n'était jamais la
couleur obtenue** : il fallait écrire la pré-image (`1 - cible`), puis une
teinte tirée au hasard parmi 6 déplaçait le résultat de 55 % de toute
façon. `NightSky.gd` calculait sa pré-image CORRECTEMENT, le documentait
dans son propre en-tête, et n'atteignait quand même pas sa cible — 55 %
du pixel final ne lui appartenaient pas. **2 teintes sur 6 (cold blue,
violet) ramenaient toute la frame en bleu** : c'est exactement le
symptôme device (« le ciel reste perçu comme bleu ») que deux lots
successifs n'ont pas pu corriger. Le chiffre `main` consigné plus bas
(pursuer vs sol plafonnant à **1,86:1**, 6/6 teintes sous le plancher) a
été reproduit indépendamment par le calcul albédo -> invert -> teinte
pendant cette recon : les deux tombent sur 1,86, ce qui valide le modèle
du pipeline autant que le chiffre.

**Ce qui remplace** : un **grade plein écran indexé sur la LUMINANCE**
(`assets/shaders/swamp_grade.gdshader`) — chaque pixel est placé sur une
rampe marécage à 4 arrêts par sa luminance. Les couleurs écrites SONT les
couleurs vues, aucune pré-image. Et la rampe est **monotone** : le plus
sombre reste le plus sombre, là où l'inversion RENVERSAIT l'ordre (c'est
elle qui mettait la silhouette quasi-noire du hibou à l'écran en quasi-
BLANC sur un sol devenu bleu clair, d'où le plancher jamais atteint).

⚠️ **LE POST-PROCESS PLEIN ÉCRAN N'EST PAS NÉGOCIABLE ICI, ne pas
« simplifier » en éclairage.** Les assets de ce projet sont délibérément
**unlit** (`KHR_materials_unlit` : hibou, écureuil, arbre mort, souche ;
les 3 couches de `Decor.gd` sont `shaded = false`). Une surface unlit
ignore totalement lumière et ambiante : baisser/teinter les lumières les
laisserait en plein jour sur un ciel noir. Seul un pass écran les atteint.

**UN SEUL fichier possède la nuit** — `DarkModeEffect.gd` pilote à la fois
le grade ET le ciel/brume (`background_color`/`fog_light_color`, écrits en
DIRECT, sans pré-image). Motif : les 3 fichiers disjoints précédents
pouvaient être chacun corrects pendant que le composite était faux, et
c'est précisément ce qui est arrivé. Le grade seul ne peut pas donner un
ciel quasi-noir (le ciel de jour est l'un des pixels les PLUS clairs, il
grade donc vers un olive moyen) ; l'environnement seul ne peut pas
assombrir les objets unlit. Il faut les deux, et un seul propriétaire.

**`fog_mode` REVENU en Exponentiel `fog_density = 0.0035`** (valeur de
`main`) : `DepthFog.gd` avait basculé la scène en Depth avec
`fog_depth_begin = 150`, ce qui ne touchait plus que les collines de
`Decor.gd` et supprimait au passage la brume que le commentaire de classe
de `Decor.gd` décrit toujours longuement — une régression silencieuse de
la phase CLAIRE. Le piège « écrire `fog_mode` remet `fog_density` à 1.0 »
ne peut plus se produire : la clé `fog_mode` n'existe plus dans le `.tscn`.

### Contrastes RE-MESURÉS — les deux dettes F10 sont FERMÉES

Baseline prise sur `origin/staging` intact, dans un worktree séparé, même
machine, même graine — jamais héritée de la doc.

| sonde | avant (staging) | après | plancher |
|---|---|---|---|
| Pursuer silhouette vs sol | **2,50:1** (marge nulle) | **4,36:1** | 2,5 ✅ |
| Label frappe fatale | **2,96:1 ÉCHEC** | **3,20:1** | 3,0 ✅ |
| Combo (pire effectif) | 4,58:1 | 15,82:1 | 3,0 ✅ |
| Pips strike (présence) | 4,65:1 | 4,49:1 | 3,0 ✅ |
| Pips strike (intact/usé) | 12,74:1 | 9,03:1 | 3,0 ✅ |
| Barrière (stripes) | 18,33:1 (clair) | 7,49:1 (sombre) | 3,0 ✅ |

Les deux lignes « pips » BAISSENT et restent largement au-dessus du
plancher : le fond derrière le HUD est désormais un olive sombre uniforme
au lieu de six teintes saturées, donc les extrêmes disparaissent dans les
deux sens. C'est le comportement attendu d'une identité unique, pas une
régression.

⚠️ **La baseline mesurée ne correspond PAS à ce que ce fichier
documentait.** CLAUDE.md donnait « pursuer 6/6 sous 2,5, pire 1,86 » et
« label 2,99 » — ce sont les chiffres de `main`. Sur `staging`, les
changements de fog de `DepthFog.gd` avaient déjà déplacé le sol : pursuer
2,50 (PASS de justesse), label 2,96 (ÉCHEC). **Toujours re-mesurer la
baseline sur la branche où l'on merge, jamais la lire ici.**

⚠️ **Le plancher silhouette 2,5 est CONSERVÉ alors que sa justification
est morte.** Il était un plafond DÉRIVÉ (3,0 était inatteignable sous
l'inversion, quel que soit l'albédo). Le grade lève ce plafond. Il n'est
délibérément PAS remonté à 3,0 dans le lot qui rend 3,0 atteignable :
resserrer un contrat en même temps que la réécriture qui le satisfait
rend toute régression future attribuable au resserrement. C'est une
décision séparée, et la marge pour la prendre est dans les chiffres
ci-dessus.

⚠️ **Hazards vs sol : 1,46:1, sous le 3,0 de référence — MAIS non gaté,
et jamais atteint.** Sous l'inversion ces paires étaient à **1,00-1,02:1**
et aucune couleur ne pouvait les bouger ; elles sont donc AMÉLIORÉES
(1,46-2,54 selon le type), pas dégradées. **Sweep fait, ne pas le
refaire** : déplacer `knee_mid` plafonne à **1,70:1** (voir le tableau
dans `GameState.gd`). La limite n'est pas positionnelle — ces hazards se
distinguent du sol surtout par la TEINTE, et un grade indexé luminance
jette la teinte par construction. La sortie est du côté des **albédos des
hazards**, pas de la rampe : ça touche la silhouette d'objets de gameplay
visibles et ça mérite son propre lot + revue device.

⚠️ **LES SONDES GATÉES NE PEUVENT PAS ÊTRE BYTE-IDENTIQUES, et c'est
inévitable.** `_reroll_dark_variant()` tirait dans le RNG **global**
(celui que `DevSeed.apply()` seede) : un `randi()` au reset de run, un ou
plusieurs à chaque phase sombre. Les supprimer DÉCALE le flux pour toutes
les sondes seedées. Préserver le flux aurait exigé de garder un tableau à
6 entrées et sa boucle de redraw uniquement pour que le nombre de tirages
JETÉS reste le même — garder tout le mécanisme mort pour protéger un
hash. **Le bon critère pour ce lot est « même VERDICT », pas « mêmes
octets ».**

### Build, export et ce qui reste ouvert

Import headless + **export Web release : exit 0**, aucune erreur GDScript.
`index.pck` = **4 741 280 octets** (à lire avec l'avertissement déjà
consigné plus haut : la taille du `.pck` n'est PAS stable d'un export à
l'autre du même commit, ne jamais s'en servir seule comme preuve de
déterminisme). Vérifié dans le pack : `swamp_grade` présent (3 occurrences),
`screen_invert` **absent** (0).

⚠️ **Les templates d'export n'étaient pas installés dans ce sandbox** —
`--export-release` échouait sur `web_nothreads_{debug,release}.zip`
manquants, ce qui ressemble à une erreur de projet et n'en est pas.
`godot4` lui-même n'y était pas non plus. Les deux s'installent depuis les
releases GitHub (éditeur ~50 Mo, templates ~1 Go) ; la CI fait déjà
exactement ça et les met en cache. À savoir avant de conclure qu'un export
est cassé.

**RESTE À VALIDER SUR DEVICE** (rien de tout ça n'est mesurable ici) :
l'ambiance elle-même — est-ce que ça se lit comme un marécage nocturne sur
un écran de téléphone, et est-ce que le ciel n'est plus perçu comme bleu.
C'est le seul juge du lot : toutes les sondes ci-dessus disent que la nuit
est verte, plus sombre, et que les contrastes gatés passent — aucune ne
dit que c'est BEAU.

### Sondes gatées : 11/12 VERTES, la 12e était déjà rouge (mesuré)

`AntiFrustrationAudit`, `ComboAudit`, `PursuerAudit`, `RushFrustrationAudit`,
`ShrinkAudit`, `PursuerFramingAudit`, `AssetContractAudit`,
`ChargerShapeProbe`, `DeathModelAudit`, `ProbeTimeoutAudit`,
`ChargerAudit` — **PASS**, graine 20260806, `--fixed-fps 60`.

`StrikeAudit` **ÉCHOUE, et échouait déjà** (dette connue : écart de part
de captures 15 points contre 20 requis). Son écart bouge à 12 sur ce lot,
ce qui est attendu — le flux RNG global est décalé (voir plus haut), donc
les bots tirent une AUTRE séquence de hazards. **Vérifié plutôt
qu'argumenté**, 3 graines de chaque côté, même machine, worktree séparé
pour la baseline :

| graine | `origin/staging` | marécage |
|---|---|---|
| 20260806 | **15** | 12 |
| 31415926 | 13 | **15** |
| 27182818 | **4** | 12 |

La plage baseline (**4-15**) est PLUS LARGE que celle du lot (**12-15**),
et la contient. Le 15 -> 12 de la graine documentée est donc du bruit
d'échantillonnage, pas une régression : sur la graine 27182818 la
baseline descend à 4. Les deux côtés échouent sur les 3 graines, toujours
pour la même raison (écart < 20). **Aucun seuil n'a été touché**, et la
baseline reproduit exactement le 15 documenté à la graine 20260806 — ce
qui valide la comparaison avant d'en tirer quoi que ce soit.

### Sondes réécrites (6) — pièges rencontrés, à connaître

`InvertCapture` → **`SwampGradeCapture`** (renommée, pas patchée : un
fichier nommé InvertCapture qui mesure un grade est le même piège une
couche plus loin). Elle assère 4 propriétés dont **« la nuit est
VERTE »** — c'est le contrôle qui aurait attrapé le défaut d'origine, que
seul un œil humain sur un téléphone avait vu. `InvertCapture` imprimait
déjà `INVERSION_VERIFIED=NO` sur du code sain depuis l'ajout du pass de
teinte : une sonde dont la prémisse avait expiré sans que personne ne la
relise.

Les 4 sondes de contraste + `DarkPaletteAudit` : la boucle 6 teintes
devient un seul cas DARK, et elles pilotent désormais le VRAI
`DarkModeEffect._apply()` au lieu d'écrire les uniformes à la main.
⚠️ **Nécessaire, pas cosmétique** : depuis que la nuit est aussi le
ciel/la brume, poker seulement le shader mesurerait un monde gradé
marécage sous un **ciel bleu de jour** — un état que le jeu ne peut pas
produire. `DarkPaletteAudit` construit sa propre scène, donc on lui pointe
explicitement son propre `WorldEnvironment` (`world_environment_path`).

`DarkPaletteAudit` perd son SWEEP (48 rendus pour calibrer une constante
qui n'existe plus) et donc sa « passe canonique » (plus de raccourci
sonde-only à confronter). Ce qui survit — hazard/collectible vs sol — est
la seule couverture des objets que le joueur esquive.

⚠️ **DEUX pièges de sonde rencontrés en écrivant `SwampGradeCapture`, tous
deux valables pour toute future sonde qui échantillonne des frames
entières :**
1. **Écrire `dark_intensity` UNE fois ne tient pas.** Tant que le run est
   PLAYING, `_update_dark_cycle` fait un `move_toward` CHAQUE frame vers
   la cible de la phase courante ; avec la phase laissée à INACTIVE, un
   `1.0` retombe pendant les frames de settle. La sonde échantillonnait
   une frame à mi-fondu en la rapportant comme la nuit pleine — ça
   ressemblait à un défaut de couleur du shader. Faire correspondre la
   PHASE à l'intensité (patron de `DarkPaletteAudit._hold_state`).
2. **Laisser le run avancer pollue la mesure.** Le monde défile, Keepy
   percute, et le **flash plein écran** de `HUD.gd` recouvre la frame :
   l'échantillon JOUR est revenu à `(0.84, 0.50, 0.41)` — orange vif — au
   lieu du ciel bleu pâle réel, et les verdicts jour/nuit se sont
   inversés. Même famille que F10c. Geler (`current_speed = 0`,
   `pursuer_enabled = false`).


## Deux défauts de mesure corrigés (F10, 9 août 2026) — les deux décisions
## de teinte sont désormais SANS OBJET (refonte marécage, 11 août 2026)

⚠️ **LES DEUX DÉCISIONS DE TEINTE DÉCRITES CI-DESSOUS SONT CLOSES, et pas
parce qu'on a tranché : la palette qu'elles concernaient N'EXISTE PLUS.**
`DARK_VARIANTS` et `DARK_TINT_AMOUNT` sont supprimés par la refonte
marécage (voir sa section plus haut). Les deux défauts qu'elles laissaient
ouverts sont re-mesurés et passent — pursuer **4,36:1** (plancher 2,5),
label fatal **3,20:1** (plancher 3,0). Aucun plancher n'a été déplacé pour
y arriver. **Ne pas rouvrir ces deux points ni les proposer à Mathieu.**
La section est conservée pour ce qu'elle documente encore et qui reste
vrai : DEUX DÉFAUTS DE MESURE, et comment ils se produisent.

`docs/PROBE_AUDIT.md` (F10a/F10b/F10c) documente deux sondes qui mesuraient
autre chose que ce qu'annonçait leur en-tête — `PursuerContrastAudit`
échantillonnait Keepy au lieu du sol, et `StrikeFatalContrastAudit` avait un
fond irreproductible d'une exécution à l'autre (décor non seedé, puis —
cause dominante — le flash plein écran des coups gelé à mi-décroissance).
**Les deux sondes ont été corrigées, re-validées (les 7 sondes bot gated +
AssetContractAudit + ChargerShapeProbe restent byte-identiques au seed
20260806), et poussées sur `claude/f10-measurement-defects-srfh8t`.**

**Ce que la correction a mis au jour — deux vrais défauts de lisibilité,
mesurés proprement, aucun plancher déplacé pour les faire passer :**

- **Pursuer vs sol en `DARK/2` : 2,37:1 contre le plancher 2,5:1.** La
  couleur du pursuer (déjà `0,02, 0,02, 0,03`, noir pur) n'a **aucune marge
  restante** — le sweep qui a servi à calibrer le plancher 2,5 place le
  plafond atteignable en vert à 2,05, en dessous du 2,37 mesuré. Fermer ça
  exige de bouger soit l'albédo du sol, soit `GameState.DARK_TINT_AMOUNT`
  (0,55) — les deux affectent le contraste dark-mode de TOUS les objets de
  gameplay, pas seulement le pursuer. Décrit dans `docs/MESHY_SPEC.md` §8
  (note dédiée, juste après le tableau de palette).
- **Label de frappe fatale en `DARK/5` : 2,99:1 contre le plancher 3,0:1.**
  0,01 sous le seuil, désormais stable d'une exécution à l'autre (avant la
  correction, le fond mesuré incluait un flash blanc plein écran figé à une
  opacité aléatoire — la sonde ne mesurait pas encore fiablement le HUD).

  ⚠️ **Depuis le merge half-strike (9 août 2026), cette sonde lit 3,00:1 et
  PASSE — ce n'est PAS une correction, c'est un faux vert (F11).** Aucune
  couleur n'a bougé : l'échelle de pips passe de 2 à 4, le `StrikeRow`
  (`HBoxContainer`) s'élargit, donc le label se DÉPLACE de quelques pixels
  et la sonde échantillonne un autre morceau du monde 3D derrière lui.
  Vérifié en re-jouant la sonde sur `staging` pré-merge sur la même machine :
  2,99:1, exactement le chiffre documenté. **La décision de teinte reste
  entièrement ouverte et reste celle de Mathieu** — un défaut qui passe à
  3,00:1 grâce à deux pixels de mise en page n'a aucune marge. Détail chiffré
  et tableau des fonds mesurés : `docs/PROBE_AUDIT.md`, F11.

~~**Aucune des deux ne demande de code ni de nouvelle sonde.**~~ **CLOS le
11 août 2026 par la refonte marécage** — les deux sondes ont été
re-roulées contre la nouvelle palette et passent avec marge (chiffres
dans la section refonte). Ce qui reste utile ici : F11 documente que
`StrikeFatalContrastAudit` a vu son verdict basculer **deux fois** sans
qu'aucune couleur ne bouge, juste parce que la mise en page du strike row
déplaçait le label de quelques pixels. **Cette sensibilité n'est PAS
corrigée par la refonte** — elle échantillonne toujours le monde 3D
derrière le label. Traiter cette sonde comme sensible à la MISE EN PAGE
autant qu'à la couleur reste valable.

