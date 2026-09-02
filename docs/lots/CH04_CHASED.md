# Keepy Chased — décor procédural, modèle de mort, poursuivant, audio

> Extrait de `CLAUDE.md` par le LOT H (2 septembre 2026), **verbatim** : aucune ligne réécrite, résumée ni supprimée.
> 5 section(s), 405 lignes d'origine.
> Doctrine permanente : voir `CLAUDE.md`. Index des chantiers : `docs/lots/INDEX.md`.

## Décor procédural : déjà en prod (correction d'une passation périmée)

**Ce fichier ne mentionnait nulle part le décor, ce qui a laissé croire à une
session ultérieure que le lot décor restait à faire. Il était déjà mergé sur
`main` avant elle.** Vérifié sur `origin/main` (pas déduit d'un récit) : le
lot complet est en place et déployé —

- **Collines de fond** — `scripts/world/Decor.gd`, nœud `World/Decor` dans
  `Game.tscn`, deux couches parallaxe à pool fixe (`6270afc`, recyclage
  corrigé par `2ffc491`).
- **Bordures de voie + variation de teinte du sol** — `TrackSegment.gd`,
  `_build_lane_curbs()` et `_reroll_ground_tint()` (`83ef8e0`).

Les trois sont arrivés en prod par le merge `9dca8fb` (« merge: bring
procedural decor environment to prod »).

**Depuis le 9 août 2026, un quatrième élément s'y ajoute : les props de bord
de piste** (arbres et rochers low-poly), branche `claude/trackside-props`.
Même cycle de vie que les bordures — construits une fois dans `_ready()` de
`TrackSegment`, seulement montrés/cachés et repositionnés par `populate()`,
recyclés avec leur tuile. **Pas** une seconde couche à la `Decor.gd` : un
prop appartient à une TUILE, une colline n'appartient à rien.

**Second passage, 9 août 2026 (branche `claude/trackside-decor-props-n1rdzj`) :
quatre types de plus — banc, panneau, souche, buisson.** Même système, aucun
nouveau : construits une fois dans `_ready()`, montrés/cachés et repositionnés
par `populate()`, recyclés avec leur tuile. **Aucun nouveau flux `DecorRng`** —
`_prop_rng` est réutilisé, parce qu'en prendre un nouveau re-numéroterait tous
les flux créés après lui et déplacerait le fond que les sondes de contraste F10
mesurent. Le type tiré est désormais un **tirage pondéré sur six** (arbre 0,32 /
rocher 0,20 / buisson 0,18 / souche 0,14 / banc 0,09 / panneau 0,07) et non plus
un pile-ou-face arbre/rocher, donc une tuile est un mélange et non le même
catalogue dans le même ordre. Le panneau est **vierge par construction** : pas de
texture, pas de texte — une silhouette, rien à lire.

Coût mesuré (`get_faces()/3`, comme `TrackPropsAudit`) : arbre 25, rocher 48,
buisson **108**, souche 48, banc 44, panneau 22 triangles. Famille props au pire
frame : **871 tri sur 8 runs**, soit 58 % du plafond de 1 500 que la sonde
impose.

Règle qui vaut pour tout ajout de décor futur, et qui est la seule chose
réellement contraignante ici : **aucun prop ne doit empiéter sur la dalle de
6 m** (`Hitboxes.GROUND_SIZE.x`) — la contrainte porte sur le bord de la
SILHOUETTE, pas sur le centre du prop. Les deux types « fabriqués » (banc,
panneau) prennent un petit lacet (±0,21 rad) et leur demi-largeur est l'extension
tournée EXACTE, pas le cercle englobant ; le buisson ajoute le décalage de son
lobe le plus éloigné au rayon de ce lobe. `nearest_prop_edge_x()` parcourt
désormais une liste unique `_PROP_MESH_KEYS` au lieu d'un littéral, pour qu'un
type ajouté plus tard ne puisse pas être oublié du contrôle. Détail, table de
contraste mesurée et budget triangles : `docs/MESHY_SPEC.md` §8.2. Sonde dédiée :
`scripts/dev/TrackPropsAudit.tscn`.

⚠️ **`TrackPropsAudit` ne seede RIEN — `--seed=20260806` y est inerte**
(vérifié : ni `DevSeed.apply()` ni `DecorRng.force_seed()` dans la sonde). Son
total de frame est donc un échantillon d'un run NON seedé : le même binaire a
mesuré 44 943 puis 53 858 sur deux invocations consécutives, sans qu'aucune
ligne ne change. **Un run isolé de cette sonde n'est pas un chiffre de budget** —
c'est ce qui explique que le 57 402 noté plus haut et les chiffres ci-dessous ne
soient pas comparables un à un. Même famille de défaut que F10 côté sondes de
contraste ; noté et non corrigé ici, parce que seeder cette sonde changerait le
sens de tous les chiffres de frame déjà consignés et mérite son propre lot. Les
phases keep-out et collider ne sont PAS concernées (elles jugent sur 4 000
tirages, pas sur une frame échantillonnée).

⚠️ **Budget triangles §7 : le tableau d'origine n'était PAS une mesure.** La
re-mesure du 9 août 2026 (§7.2) montre la frame **au-dessus** de la cible de
50 000 — ~52 800 props désactivés, donc antérieurement au lot props et sans
rapport avec lui. Cause dominante : les collectibles (`Noisette.tscn` /
`Gland.tscn`) dessinent **4 224** triangles chacun (`SphereMesh` laissé à la
tessellation par défaut de Godot) là où §7 en budgétait 300. Correction
identifiée et chiffrée dans §7.2, **volontairement non faite** — elle touche
la silhouette d'un objet de gameplay **visible** et mérite sa propre revue
device. Ils restent le poste dominant : pire frame mesurée sur 11 runs après
le lot hibou ci-dessous, **57 402**, toujours 7 402 au-dessus de la cible.

**Re-mesure du 9 août 2026 (lot banc/panneau/souche/buisson), 8 runs de chaque
côté, pire frame gardée par run** — à lire avec l'avertissement « sonde non
seedée » ci-dessus, donc en PLAGES et jamais en chiffre unique : avant
44 943–**53 858**, après 41 423–**61 947**. La marge contre la cible de 50 000
est **négative, et l'était déjà avant ce lot** (53 858 sur l'arbre intact). Le
poste dominant reste les collectibles : 21 120–33 792 selon les runs, contre 300
budgétés au §7.1. Les props, eux, coûtent 377–871 tri, soit 1 à 1,7 % de la
frame — ils ne sont pas le problème et n'expliquent pas l'écart entre les deux
plages, qui est du bruit de collectibles/hazards.

⚠️ **« Le hibou pèse 15 518 triangles » est FAUX — corrigé le 9 août 2026
(§7.3). Ne pas repartir de ce chiffre.** Le `.glb` en pèse **7 070**, soit
930 SOUS son plafond de 8 000 ; il n'a jamais été hors budget et **n'a pas
été décimé**. Les 8 448 restants venaient de **deux sphères d'yeux
placeholder** (`SphereMesh` par défaut, 4 224 chacune) enfants de
`Silhouette` — 7 070 + 4 224 + 4 224 = 15 518, exactement le chiffre de §7.2,
qui comparait un total de *famille* à un budget d'*asset*. Décimer le hibou
ne pouvait pas atteindre la cible : même à zéro triangle la famille restait
à 8 448. Corrigé en passant `SphereMesh_Eye` à 16 x 8 : famille **15 518 ->
7 646**, soit **−7 872 triangles à chaque frame**. Les yeux sont sur la face
**-Z** (côté opposé à la caméra, cf. §6) et donc entièrement occultés : les
rendus offscreen avant/après aux trois poses de jeu sont **pixel-identiques**.
Les sept sondes gatées sont **byte-identiques**, 0 collider déplacé, `.pck`
+16 octets.

⚠️ **`PursuerContrastAudit` ÉCHOUE, et échouait déjà sur `origin/main`
intact** (6/6 palettes sombres sous le plancher 2,5:1, pire 1,86:1, contre
2,53:1 PASS enregistré au lot hibou du 8 août). Mesuré 3 fois avant / 3 fois
après le lot du 9 août : identique, donc **ni causé ni corrigé par lui**.
Régression pré-existante **ouverte**, suspect principal non confirmé : la
dérive de teinte du sol par segment (`_reroll_ground_tint`, §8.1), non
seedée, qui change précisément la surface contre laquelle la sonde mesure la
silhouette. C'est la lisibilité en mode sombre du poursuivant — à traiter.

## Modèle de mort : seul le CHARGER tue (rebalance demi-strike, 9 août 2026)

Branche `claude/half-strike-rebalance`. **Le plus gros changement de gameplay
depuis le split DODGE/JUMP d'origine** — à ne pas traiter comme un lot visuel.

**Avant** : 4 des 6 hazards tuaient au contact (CHARGER, STOMPER, ENEMY,
AIR_ENEMY), les 2 statiques coûtaient 1 strike sur 2.
**Maintenant** : **CHARGER seul** tue. Les 5 autres coûtent **0,5 strike**,
uniformément.

**Pourquoi** — mesuré, pas supposé : `StrikeAudit` montrait le profil
mid-skill mourant **32 fois sur hazard fatal contre 12 captures**. Le modèle
de mort que tout le bloc STRIKES de `GameState.gd` existe pour créer était
donc minoritaire dans son propre jeu : le poursuivant devait gagner une
course contre 4 morts instantanées avant d'avoir son tour. Le CHARGER garde
le statut fatal parce qu'il est le seul à avoir une vitesse propre
(`CHARGER_SPEED_FACTOR`) — il te chasse, il te rattrape, il a gagné la run.

**Unité interne : des DEMI-UNITÉS entières, pas un float.**
`strikes_used_half` / `STRIKE_CAPACITY_HALF` (= 4) / `CONTACT_COST_HALF`
(= 1). Un `float strikes_used` à 0.5 marcherait — jusqu'au jour où quelqu'un
ajoute un poids qui n'est pas une puissance de deux, et ça casserait en
silence dans le fichier que sa propre en-tête appelle « le contrat
d'équité ». Budget total INCHANGÉ (l'équivalent de 2 strikes pleins) : seule
la granularité bouge.

**Récupération : 1 demi-unité, jamais 1 strike plein**, par les deux chemins
(temps et combo). Décision explicite : sinon la récup rattraperait les dégâts
2 pour 1, et avec `COMBO_TO_CLEAR_STRIKE = 3` un joueur actif deviendrait
immortel côté strikes.

**HUD : 4 pastilles (pas 2 demi-remplies) + échelle d'alarme à 3 crans.**
`GameState` compte en demi-unités parce que c'est l'arithmétique sûre ; le
HUD, lui, parle en CONTACTS au joueur — 4 coups, 4 pastilles. L'ancien
`danger := used >= CAPACITY - 1` était binaire et correct à capacité 2 ; à
capacité 4 il ne s'allumerait qu'au 3e contact, laissant les deux premiers
sans marqueur persistant. D'où : clair (0-1) → **caution** (2, ambre, pulse
lent/faible) → **danger** (3, ambre, pulse rapide d'origine + kick) → fatal
(4, corail, le plus rapide). **L'escalade passe par le RYTHME**, une seule
bascule de teinte — ça préserve l'argument de `STRIKE_FATAL_COLOR` (le beat
fatal garde sa famille de teinte propre) et ça survit à DARK/4, que la
couleur seule ne passe pas.

⚠️ **Piège corrigé au passage, à ne pas réintroduire** : le kick d'entrée
était DESSINÉ dans la branche `danger`. À capacité 2 c'était équivalent (tout
contact non-fatal armait `danger` la même frame) ; à capacité 4 les contacts
1 et 2 sont sous le seuil, donc le kick aurait été armé, avancé, expiré —
et jamais dessiné. Il est maintenant appliqué HORS des branches de l'échelle.

**Sonde dédiée : `scripts/dev/DeathModelAudit.tscn`** (nouvelle). Elle
n'utilise **aucun bot et aucun RNG** — elle instancie Keepy et Obstacle
seuls, émet le vrai signal `body_entered`, et assère le CONTRAT :
classification sur `Type.values()` (un 7e type ne peut pas passer non
classé), CHARGER = 1 coup, et pour **chacun** des 5 autres : survie à 3
contacts, capture au 4e, en `PURSUER` et non `COLLISION`. Motif : un bot ne
rencontre un hazard que **par chance** — c'est exactement la famille de faux
verts que `ProbeCoverage.gd` documente. Byte-identique d'un run à l'autre.

**Ne PAS considérer les 6 sondes byte-identiques comme une preuve ici** :
c'est le bar des lots purement visuels. Le gameplay de 3 types change, donc
`StrikeAudit` DOIT bouger — voir `docs/PROBE_AUDIT.md` pour les nouveaux
chiffres et les seuils re-calibrés.

### Capacité RÉSISTANCE : 4 → 2 contacts (9 août 2026, F13) — NON validée device

Choix explicite de Mathieu, contre la piste #1 que `StrikeAudit` nomme dans
son propre source (elle proposait 4 → 3). **`STRIKE_CAPACITY_HALF = 2`** :
le CHARGER tue toujours en un coup, les 5 autres types coûtent toujours
1 demi-unité chacun — seule la capture passe du 4e au **2e** contact.
Chiffres complets : `docs/PROBE_AUDIT.md` §F13.

**Ce que ça corrige, et c'est un changement de NATURE :** à capacité 4 le
budget de résistance était **décoratif** — **0 capture sur 35** tombait sur
le contact de capacité, toutes étaient des drains de lead. À capacité 2 il
décide **30 captures sur 58**. La mécanique que tout le bloc STRIKES existe
pour créer tire enfin.

**Ce que ça ne corrige PAS, et le bar n'a pas été bougé :** l'écart de part
de captures passe de **8 → 15 points**, il en faut **20**. `StrikeAudit`
reste ROUGE, pour une raison désormais différente (« un joueur passif et un
joueur moyen meurent encore trop souvent de la même chose », plus « la
résistance ne tue jamais personne »). Baisser le seuil serait exactement le
faux-vert que `ProbeCoverage.gd` documente cinq fois.

**Deux effets à mesurer sur device avant tout merge :**
- **survie mid-skill quasi divisée par deux** (157,8s → 78,2s) — c'est un
  jeu nettement plus dur, pas un ajustement marginal ;
- **le profil RISKY devient rattrapable** (0 % → 41 % de ses morts) ; à
  capacité 4 il était structurellement immunisé contre le poursuivant.

⚠️ **HUD : l'échelle d'alarme à 3 crans DÉGÉNÈRE en binaire, et c'est
correct.** Les deux seuils sont DÉRIVÉS de la capacité (`CAPACITY - 1` et
`CAPACITY / 2`) : à 2 ils valent tous les deux 1, DANGER est testé en
premier, donc CAUTION devient **inatteignable** — par arithmétique, pas par
une édition. À deux contacts il n'existe pas d'état « à moitié entamé » qui
ne soit pas aussi « encore un et c'est fini ». Les constantes CAUTION sont
CONSERVÉES : remonter la capacité à 3+ ressuscite le cran avec son
calibrage. `HUD.tscn` perd Pip2/Pip3 (assertion `_ready()` capacité vs
nombre de pastilles — elle `push_error`, elle ne devine pas).

⚠️ **F11 SE REPRODUIT, EN SENS INVERSE — `StrikeFatalContrastAudit` passe de
PASS à FAIL sans qu'aucune couleur ne bouge.** `DARK/5` : 3,01:1 → **2,99:1**.
Retirer 2 pastilles rétrécit le `StrikeRow` de `2 × (34 + 12) = 92 px`, donc
le label centré se **décale de 46 px à droite** et échantillonne un autre
morceau du monde 3D. **2,99:1 EST le chiffre vrai** — celui que F10c avait
rendu reproductible et que F11 documente sur `staging` avant le merge
half-strike. Ce n'est donc pas une régression introduite ici : c'est le
défaut pré-existant qui redevient visible maintenant que la coïncidence de
mise en page à 4 pastilles qui le masquait a disparu. Le PASS à 3,00/3,01
était le faux vert. **Décision de teinte toujours ouverte, toujours celle de
Mathieu.** Deuxième fois que le nombre de pastilles déplace ce verdict :
traiter cette sonde comme sensible à la MISE EN PAGE du strike row, pas
seulement à la couleur.

**Sondes non byte-identiques mais VERTES** : `ShrinkAudit` et `ComboAudit`
bougent (bots morts à 2 contacts → plus de runs, plus courts, dans le même
budget de phase). Aucun critère ne bascule. Le lot half-strike laissait 6/7
sondes gatées byte-identiques ; celui-ci en laisse 4.

**Défaut de sonde révélé au passage** : `DeathModelAudit` posait sa phase 5
avec **deux `_contact()` en dur** — juste à capacité 4, mais à capacité 2 ces
deux contacts SONT la capture. La branche combo échouait correctement
(`register_risk_event` sort sur `state != PLAYING`) pendant que la branche
temps PASSAIT quand même (`_update_strikes` ne teste pas l'état). Corrigé
dans la SONDE (`STRIKE_CAPACITY_HALF - 1` contacts), pas dans le jeu : rien
en production n'appelle `advance_time()` hors PLAYING.

## « Le poursuivant ne recule jamais » — le moment de largage a enfin un cue (F14)

**Piste 1 de F12 LIVRÉE le 10 août 2026 ; les pistes 2 et 3 restent
intactes et restent la décision de Mathieu.** `GameState.pursuer_lost_sight`
avait zéro abonné — le signal était déclaré, émis, et personne ne s'y
connectait. Il en a un maintenant : `HUD.gd`. C'est tout le changement.

**Rien d'autre n'a bougé, et c'est délibéré** : `pursuer_became_visible`,
`PURSUER_RISK_REWARD_S`, `PURSUER_CLOSE_RATE`, la bande visuelle
`FAR_Z`/`CAUGHT_Z` et `STRIKE_CAPACITY_HALF` sont **hors périmètre**. La
poussée reste aussi longue qu'avant — PHASE CADENCE re-jouée **byte-identique**,
donc les 75,6 s de jeu propre qu'un profil mid-skill doit tenir pour chasser
le hibou sont exactement celles de F12. Ce lot ne raccourcit pas l'attente,
il transforme son aboutissement en événement.

Deux cues, au même instant :

- **Un son qui n'est PAS un cue de strike** — `assets/audio/pursuer_lost.wav`,
  troisième `.wav` du projet, joué par un troisième `AudioStreamPlayer` du
  HUD (même patron que les deux autres, aucun service audio nouveau). La
  séparation est de **CARACTÈRE**, pas de volume — la seule qui survive à un
  haut-parleur de téléphone. Les deux cues de strike sont des percussions à
  attaque dure qui décroissent (mesuré sur les fichiers commités : ~712 Hz
  sur 0,20 s ; ~275 → ~117 Hz sur 0,55 s). Celui-ci est une paire de notes
  sinus **MONTANTES** à attaque douce — A4 puis E5 une quinte au-dessus,
  0,62 s, léger scintillement d'octave, **aucun transitoire**. Même format
  (22050 Hz mono 16 bits), crête à 0,62 de la pleine échelle contre 0,72, et
  joué à −6 dB contre −4/−2. Un cue qui résout vers le haut depuis une
  attaque douce ne peut pas être pris pour un impact : le joueur ne doit
  jamais l'entendre et aller vérifier ses pastilles.
- **Un relâchement du télégraphe** — `PursuerLabel` et `GaugeFill` tombent à
  alpha 0,22 en 0,198 s puis remontent en douceur sur les 0,702 s restantes.
  Descente rapide, remontée lente : c'est cette asymétrie qui le fait lire
  comme un relâchement et non comme un clignotement. **Pas alpha zéro** — la
  jauge est une information PERMANENTE et doit rester lisible pendant le
  beat. Et volontairement **pas** la réaction d'arrivée jouée à l'envers :
  l'arrivée est un POP d'échelle sur le même label, donc les deux sont des
  propriétés différentes qui vont en sens opposés. Une nouvelle apparition
  pendant le beat l'ANNULE (le hibou est revenu ; un télégraphe encore en
  train de s'éteindre sous le pop d'arrivée dirait les deux choses à la fois).

⚠️ **F11 vérifié explicitement, et pas par un raisonnement.** Cette sonde a
déjà vu son verdict basculer **deux fois** sans qu'aucune couleur ne bouge,
juste parce qu'un changement de mise en page du strike row a déplacé le label
de quelques pixels. « Ce n'est que de l'audio et un fondu » n'est donc pas un
argument. Structurellement le lot ne PEUT pas déplacer un pixel de HUD : le
lecteur audio est un nœud **non-`Control`** à la racine du `CanvasLayer`
(aucune mise en page, aucun ordre de dessin), le beat visuel passe par
`modulate` (une multiplication de couleur, incapable de redimensionner ou
repositionner), et **aucun nœud n'a été ajouté à `PursuerRow`**. Et c'est
**mesuré** : une sonde jetable a imprimé les rects écran de toute la colonne
poursuivant sur les deux arbres — **byte-identiques**, `StrikeLabel` compris
(`pos=(430, 1722) size=(128, 66)`).

⚠️ **Mais `StrikeFatalContrastAudit` et `PursuerContrastAudit` n'ont PAS pu
tourner dans le sandbox de ce lot — ni avant ni après.** Les deux atteignent
le budget de 900 s du `ProbeWatchdog` et sortent en code 2. **Limite
d'environnement, pas défaut de sonde ni régression** : relancée SEULE sur une
machine oisive, `StrikeFatalContrastAudit` consomme **15 m 0,5 s réelles /
15 m 3,4 s CPU** — occupée à 100 % du début à la fin — contre les ~60 s que
`docs/PROBE_AUDIT.md` lui attribue ailleurs. Le sandbox n'a pas de GPU et rend
via `llvmpipe` sous `xvfb` ; ce sont les deux seules sondes ici qui capturent
des frames réelles en masse, et les deux seules à échouer ainsi. Les deux
arbres donnent le même INCONCLUSIVE, donc aucun basculement n'est masqué —
mais **le 2,99:1 de `DARK/5` n'est ici ni confirmé ni infirmé**, et la
décision de teinte reste ouverte et reste celle de Mathieu. Piège de lecture :
l'indice du watchdog (« the run clock has been FROZEN ») est un faux ami pour
ces deux sondes — elles gèlent l'horloge exprès (`_freeze_world` met
`current_speed = 0.0`), c'est leur état normal, pas la cause.

**Sondes : 11/11 byte-identiques sur les DEUX flux**, même code de sortie,
graine 20260806, `--fixed-fps 60` (7 sondes bot gatées + AssetContract +
ChargerShape + DeathModel + ProbeTimeout). `StrikeAudit` reproduit
exactement les chiffres capacité-2 de F13 — **safe 100 % / mid 85 % /
risky 41 %, écart 15 points contre 20 requis, toujours ROUGE**. C'est le
résultat recherché : un cue qui ne touche pas au modèle de mort ne doit pas
le déplacer, et l'identité au bit près le dit plus fort qu'un simple verdict
identique. **Aucun seuil n'a été bougé.**

**`PursuerPushbackAudit` gagne une PHASE CUE, et devient partiellement
gatante** — PHASE VISUAL et PHASE CADENCE continuent de décrire sans rien
asserter, PHASE CUE **gate**. Motif : le défaut qu'elle garde (le signal
reperd son abonné) est silencieux par nature — aucune erreur, rien qui ait
l'air cassé, le son cesse simplement d'exister. Elle pilote le vrai
`GameState` et le vrai `HUD.tscn`, jamais un stub, et vérifie sur **trois**
traversées : connecté **exactement une fois** (lu sur
`get_connections()`, pas `is_connected()` — celui-ci répond « au moins une »
alors que le défaut à attraper est « deux »), **une seule** émission par
traversée, tenue **10 s au-dessus du seuil** sans nouvelle émission (un test
par frame en rapporterait ~600), et annulation du beat à la ré-apparition.
17/17 OK. La ligne audio est **rapportée, jamais gatée** : en headless Godot
tourne le pilote audio factice, et gater dessus serait gater sur le banc
d'essai plutôt que sur le jeu.

Détail chiffré complet : `docs/PROBE_AUDIT.md` §F14.

## « Le poursuivant ne recule jamais » — le diagnostic d'origine (F12)

Retour playtest sur `staging`. **Mesuré, pas supposé** — sonde dédiée
`scripts/dev/PursuerPushbackAudit.tscn` (elle RAPPORTE, elle ne gate pas),
détail chiffré complet dans `docs/PROBE_AUDIT.md` §F12. Le rapport décrit
en réalité **deux défauts distincts**, et un seul « augmenter la
récompense » n'en corrigerait qu'un.

**Verdict : (b) — le recul existe mais n'est visible que comme une
disparition binaire — plus une forme atténuée de (a). PAS (c) :** le visuel
suit correctement `pursuer_lead_s`, chaque frame, sans bug.

- **Le recul EST rendu, mais ne porte quasi aucune information.** Sur la
  portion qu'un joueur traverse réellement en poussant (lead 4 → 8),
  l'occupation écran passe de 25,01 % à 23,88 % : **1,1 point de hauteur
  d'écran**, étalé sur les 40-75 s que la poussée prend. Presque toute la
  dynamique de la bande vit dans les deux dernières secondes de lead (8→10).
- **La fin est une coupe franche** : `19,93 % → 0 %` en UNE frame
  (`visible = false`), sans fondu — alors que l'intro, elle, a une sortie
  lissée. Et **`pursuer_lost_sight` n'a AUCUN abonné** : le signal est
  déclaré, émis, et personne ne s'y connecte. Le seul instant que la
  mécanique existe pour livrer n'a donc aucun cue — ni fondu, ni son, ni
  HUD.
- **La poussée fonctionne, mais trop lentement pour être perçue.** Après un
  seul contact (lead ramené à 4,0 s), sans autre contact : profil
  INTERMEDIATE (13,5 évts/min) → **75,6 s** de jeu propre avant que le hibou
  quitte l'écran ; RISKY (16,7) → 39,5 s ; profil sûr (1,6) → **jamais**, il
  se fait rattraper. Cause et effet séparés de plus d'une minute, avec rien
  entre les deux.

**Trois pistes proposées. La (1) est LIVRÉE (voir F14 ci-dessus) ; les (2)
et (3) restent la décision de Mathieu** (§F12 pour l'argumentaire) :
(1) ~~donner un cue à `pursuer_lost_sight`, qui tire déjà au bon instant et
n'écoute personne~~ **FAIT le 10 août 2026** — la moins chère et la seule qui
traite (b) ; (2) redistribuer la bande
visuelle (piège de géométrie à connaître : `CAUGHT_Z` est PLUS LOIN de la
caméra que `FAR_Z`, seul le ramp de scale fait grossir le hibou) ;
(3) raccourcir la constante de temps (`PURSUER_RISK_REWARD_S` ou
`STRIKE_PURSUER_LEAD_CAP_S`) — listée en dernier : elle raccourcit la
poussée sans la rendre plus lisible.

## Audio : ne coupe pas l'audio de fond (vérifié sur device, 9 août 2026)

Le projet a reçu son **premier audio** le 9 août 2026 (deux cues one-shot sur
les strikes, `assets/audio/strike_*.wav`, joués depuis `HUD.gd`). Avant ça il
n'y avait aucun `AudioStreamPlayer`, aucun bus, aucun autoload audio.

**Depuis le 10 août 2026 il y en a TROIS** : `pursuer_lost.wav` s'ajoute
(cue de largage du poursuivant, F14 ci-dessus). Toujours **aucun service
audio global** — trois nœuds `AudioStreamPlayer` posés sur le HUD, trois
fichiers dans `assets/audio/`, générés hors ligne et commités tels quels. La
raison pour laquelle deux cues ne justifiaient pas un autoload vaut encore à
trois ; si un quatrième arrive, c'est le moment de re-poser la question, pas
avant. **Règle acquise pour tout cue futur : la distinction se fait par le
CARACTÈRE** (forme d'attaque, sens de la hauteur), pas par le volume — c'est
la seule qui survive à un haut-parleur de téléphone, et c'est ce qui sépare
le cue de largage (attaque douce, notes montantes) des deux cues de coup
(attaque dure, décroissance). **Toute sonde qui joue un cue puis quitte doit
appeler un `_settle_audio_before_quit`** (attente en temps RÉEL, jamais en
frames) : sans ça elle s'ajoute à elle-même `ObjectDB instances leaked at
exit` après son propre verdict et casse la comparaison byte-identique —
constaté à nouveau sur `PursuerPushbackAudit` au premier run de sa PHASE CUE.

**Constat de test manuel, à ne pas re-vérifier :** l'export HTML5/WebGL Godot
de ce projet **n'interrompt pas et ne baisse pas (`duck`)** l'audio de fond
d'une autre app ou d'un autre onglet — musique, podcast. Testé à la main sur
**iOS Safari et Android**, en **prod (`keepy-ten.vercel.app`) et staging**.

**Conséquence pratique : pas besoin d'un toggle de coupure** (« couper le son
si de la musique joue ailleurs ») pour les futurs travaux SFX/audio. Le Web
Audio de la page cohabite avec l'audio de fond, c'est le comportement voulu.
Point acquis, aucune modification de code associée.

