# Keepy — CLAUDE.md

## Une seule session agentique à la fois sur ce repo

**Ne jamais lancer deux sessions agentiques concurrentes sur ce repo — data
hazard. Incident déjà survenu le 6 août 2026.**

Ce qui s'est passé : deux sessions ont reçu la même demande (créer ce
fichier) et ont poussé sur `main` un `CLAUDE.md` quasi-identique à ~40
secondes d'intervalle (`4e02d46` à 14:16:43, puis un commit local au message
strictement identique à 14:17:23). Résolu sans casse — la seconde session a
constaté la collision au `push` rejeté, comparé les deux versions, et
abandonné son doublon au lieu de forcer par-dessus.

Pourquoi c'est un hasard et pas un simple désagrément : deux sessions ne
partagent aucun état, ni working tree ni connaissance de ce que l'autre a
déjà poussé. Elles se marchent dessus **à travers `origin`**. Les modes de
défaillance vont bien au-delà du doublon observé ici : un `push --force`
qui écrase le travail de l'autre, deux features qui divergent sur le même
fichier, ou une session qui valide (build, sondes) un arbre que l'autre a
déjà rendu obsolète — ce dernier cas étant le pire, parce qu'il produit un
rapport de validation vert sur du code qui n'est plus celui de `main`.

Règle : une session agentique à la fois. Si un doute existe sur une session
encore active, vérifier avant de coder (`git fetch` + comparer `origin/main`
à sa propre base, `git branch -r` pour des branches récentes non mergées).

Règle permanente, sans exception, pour tout rapport de fin de tâche ou de
batch produit dans ce repo :

1. **Fence à 4 backticks, toujours.** Le rapport de fin de tâche doit
   toujours être fourni dans un seul bloc de code Markdown enveloppé par un
   fence à 4 backticks, pour permettre la copie en un tap sur iPhone. Le
   rapport reste un bloc unique, jamais paginé en plusieurs messages ni
   plusieurs blocs. Cette règle est permanente, sans exception.
2. **Structure fixe**, dans cet ordre : BRANCH, COMMITS, FILES, BUILD,
   DEPLOY, VALIDATION CHECKLIST, NEXT STEPS, DOCS STATUS.
3. **UN SEUL bloc Markdown, toujours — la pagination est INTERDITE, sans
   exception.** Jamais plusieurs blocs séquentiels (jamais de
   `## Rapport (1/N)`, `(2/N)`, ...). Si le contenu naturel dépasse
   ~100 lignes, CONDENSER ou RÉSUMER pour rester dans un seul bloc — la
   contrainte "un seul bloc" prime sur l'exhaustivité du détail. Le rapport
   doit rester copiable en un seul tap sur iPhone.
4. **Vérification avant envoi.** Avant d'envoyer, relire la réponse : si le
   rapport n'est pas enveloppé dans un fence à 4 backticks, ajouter ce
   wrapper ; si elle dépasse ~100 lignes ou contient plusieurs blocs
   séquentiels, condenser jusqu'à tenir dans un seul bloc. Confirmer en une
   ligne à la fin qu'on a fait cette vérification.
5. **S'applique à chaque tâche sans exception**, y compris quand on
   redemande une reformulation d'un résultat déjà produit (pas de relance
   de recherche dans ce cas).

## État du pipeline assets Meshy

Le pipeline décrit dans `docs/MESHY_SPEC.md` n'est plus au stade de spec :
deux assets réels sont intégrés et validés selon la méthode qu'il documente
(§2, §9-11) :

- **Hibou (pursuer)** — `assets/models/keepy_hibou_pursuer.glb`, installé
  dans `Pursuer/Silhouette` (2026-08-08).
- **Keepy (hero squirrel)** — `assets/models/keepy_squirrel_hero.glb`,
  installé dans `Keepy/MeshInstance3D` (2026-08-09).
- **Arbre mort + souche (props de bord de piste)** —
  `assets/models/keepy_bare_tree_prop.glb` et `keepy_stump_prop.glb`
  (2026-08-10). Les deux premiers `.glb` **hors `ModelSlot`** : ce sont des
  pools d'instances recyclées dans `TrackSegment.gd`, pas des nœuds fixes.
  Décimés à 150 tri, plats, sans texture, unlit. Voir la section « Suite »
  du batch décor plus bas.

**Décor de fond : premiers assets 2D (billboards), pas des `.glb` (2026-08-10).**
`scripts/world/Decor.gd` rendait ses deux couches de collines en `CylinderMesh`
procédural (§8.1 les documentait comme « no asset yet »). Les trois assets
`assets_source/decor/{mountain,hill_near,hill_far}.png` (uploadés via GitHub
web, PNG fond blanc non transparent) ont été détourés/recadrés/recompressés en
Pillow (flood-fill depuis les bords, pas un seuil plat — le fond n'est pas
`(255,255,255)` pur, et un seuil plat aurait troué le point culminant enneigé
de la montagne, resté à l'intérieur de la même bande de bruit que le fond) et
installés dans `assets/textures/decor/`. Rendu en `Sprite3D` (billboard
`BILLBOARD_FIXED_Y`), pas en `ModelSlot` : ces couches n'ont pas de nœud fixe
adressé par du code gameplay, seulement un pool d'instances interchangeables,
et la source est un cutout plat, pas un maillage — §2/§9-11 restent écrits
pour l'installation d'un `.glb` sur un `ModelSlot`, ce premier asset 2D en
dévie délibérément (voir le commentaire de classe de `Decor.gd`).
Troisième couche ajoutée (mountain, la plus lointaine) — trois couches au
total désormais. Coût triangle mesuré EN BAISSE malgré l'ajout d'une couche :
165 tri/frame pour les deux cônes (`get_faces()` sur les mêmes paramètres
`CylinderMesh`) contre 26 tri/frame pour les trois couches Sprite3D (un
Sprite3D est toujours exactement un quad, 13 instances × 2 tri).
**Piège de diagnostic rencontré et à connaître pour un futur billboard** : le
fog existant de `WorldEnvironment` (`fog_density=0.0035`, inchangé) est assez
fort aux distances de ces couches pour dominer presque entièrement leur
couleur rendue — un échantillon de pixel en jeu a mesuré une couleur quasi
identique pour les trois couches malgré trois textures sources différentes,
ce qui, au premier regard sur une capture offscreen, ressemblait à des
collines manquantes/occultées. Ce n'en était pas — positions à l'écran et
échantillon de pixel confirmés avant de conclure : c'est le même traitement
atmosphérique déjà appliqué à toute géométrie opaque lointaine de la scène,
aux mêmes bandes Z que les anciens cônes. Non corrigé (couper le fog sur ces
seules couches les ferait lire comme des découpes plates au milieu d'une
scène qui s'estompe correctement) — juste mesuré et documenté, dans le
commentaire de classe de `Decor.gd` et ici.

**Deux défauts distincts d'instabilité visuelle sur ce billboard, corrigés
séparément le 10 août 2026 — ni l'un ni l'autre n'avait de trace ici avant
ce paragraphe.** Le retour terrain sur `staging` (« une masse verte instable
au lieu de trois couches distinctes ») avait en réalité deux causes
indépendantes, mesurées puis fermées l'une après l'autre :

- **Fusion au spawn (`acf060c`)** — `x_range` de `hill_far`/`hill_near`
  était resté celui des anciens cônes `CylinderMesh` (rayon indépendant de
  la hauteur), jamais re-vérifié après le passage aux cutouts Sprite3D dont
  `pixel_size` scale largeur ET hauteur ensemble. Une seule instance de
  `hill_near` à sa hauteur max pouvait rendre ~86 m de large contre un
  spawn de 52 m — plus large que sa propre bande. Élargi 34→62
  (`hill_far`) et 26→74 (`hill_near`), ramenant le ratio
  largeur-max/étalement à ~0,55-0,58, la même zone que la couche montagne
  avait déjà visée sur SA propre première passe.
- **Recyclage visible en plein champ (ce lot, `scripts/dev/DecorStabilityAudit.gd`)**
  — le fix ci-dessus n'a rien changé au fait que chaque instance se
  téléporte de `spawn_z_max` (bord proche, taille apparente maximale) vers
  `spawn_z_min` (bord loin, taille minimale) en une seule frame. Ce bord
  proche reste 200 à 550 unités devant la caméra sur les trois couches —
  largement à l'intérieur de son FOV horizontal (~107°) à ces distances,
  qui dépasse de loin le `x_range` de n'importe quelle couche. Le recyclage
  se produisait donc en PLEIN CHAMP, pas hors-écran : un pop continu, une
  fois par recyclage, sur les 13 instances à des phases décalées — un
  second défaut, non touché par le fix `x_range`, et c'est précisément ce
  que Mathieu continuait de voir après ce fix. **Mesuré, pas supposé** :
  sonde dédiée `DecorStabilityAudit.tscn`, PHASE A (900 frames organiques,
  15 s) + PHASE B (franchissement forcé par couche) — **5/5 recyclages
  observés visibles avant fix (alpha 1.0), 0/5 après**. Corrigé en
  fondant `Sprite3D.modulate.a` à 0 sur les derniers 12 % de la bande de
  chaque couche avant le bord de recyclage, et de 0 à 1 sur les premiers
  12 % après — le téléport a toujours lieu à la même frame, désormais à
  alpha déjà nul. `DecorParallaxProbe` (bornes de bande) et
  `AssetContractAudit` restent verts, aucun changement de `spawn_z_min`/
  `spawn_z_max`/`x_range`/`height_range`.
  ⚠️ **`DecorStabilityAudit` est une sonde BLOQUANTE** (`ProbeWatchdog.arm()`
  ET `deadline()`, comme `DecorParallaxProbe`) — elle pilote
  `Decor._physics_process`/`CameraFollow._process`/`GameState.advance_time`
  directement plutôt que d'attendre des frames réellement rendues
  (`await RenderingServer.frame_post_draw`), parce qu'une première version
  qui attendait des frames rendues n'avait toujours rien affiché après le
  budget de 900 s dans ce sandbox (rendu logiciel llvmpipe/Mesa sous xvfb,
  CPU à 100 % en continu — genuinement encore en cours, pas bloquée, puis
  tuée par le timeout) alors que cette sonde ne lit jamais un pixel
  (`unproject_position` est un calcul de transform pur). À charge pour tout
  futur probe décor de mesurer via transform plutôt que via capture d'image
  réelle si le budget temps compte.

Les deux matériaux sont **unlit** (`KHR_materials_unlit` posé à la main dans
le `.glb`, cf §9) — c'est la règle par défaut pour tout asset de ce projet,
pas une particularité du hibou : §8 explique pourquoi seule une surface
unshaded a une couleur *connue* après l'inversion du mode sombre.

**Piège payload, mesuré le 9 août 2026 — à connaître avant d'ajouter un
asset :** `export_presets.cfg` utilise `export_filter="all_resources"`, qui
embarque **toute** ressource du projet dans le build, qu'une scène la
référence ou non. Conséquence : les originaux Meshy bruts d'`assets_source/`
partaient dans le build web — **35,84 Mo de charge morte** téléchargée par
chaque joueur mobile, mesurée sur un arbre identique en ne changeant que le
filtre. Corrigé en ajoutant `assets_source/*` à `exclude_filter` (à côté de
`scripts/dev/*`, qui y était déjà pour la même raison). Le `.pck` est passé
de 43,35 Mo à 4,23 Mo. Corollaire pour le prochain asset : **désactiver un
map à l'import ne réduit rien** — un `.ctex` non référencé est packé quand
même ; pour économiser réellement, il faut retirer le map du `.glb`.

Voir `docs/MESHY_SPEC.md` §11 (Import log) pour les mesures, décisions et
résultats de validation de chaque asset. Le prochain asset à intégrer suit
la même méthode : recon triangle/texture avant import, recompression
Pillow si besoin, orientation vérifiée par rendu offscreen (jamais copiée
d'un asset précédent), scale calculé contre le budget §5/§7, checklist
d'acceptation §10 avant tout push.

### Exception actée : Mathieu commite les `.glb` bruts DIRECTEMENT sur `main`

Un `.glb` sorti de Meshy est un binaire de 12 à 27 Mo qui ne peut pas
transiter par une session agentique — le sandbox n'a aucun moyen de le
recevoir. Mathieu le pousse donc lui-même, depuis l'interface web GitHub,
sans branche ni PR. **C'est une exception explicite et permanente à la
règle « jamais de push direct sur `main` », et elle est bornée aux
binaires d'asset bruts sous `assets_source/`** : elle ne couvre aucun
fichier de code, de scène ou de configuration.

Elle est utilisée depuis le début du pipeline, mais n'avait jamais été
écrite ici — les trois commits qui ont amené le hibou et l'écureuil
(`9fe13b8`, `d007512`, `9a22dab`) sont déjà sur `main` sous cette forme,
et le batch décor du 10 août 2026 (`0502fb8`, message « decor », 6
fichiers) suit le même chemin. Ce paragraphe régularise l'usage plutôt
qu'il n'en crée un.

Ce que l'exception implique, et qui n'est pas négociable :

* **Un `.glb` sur `main` n'est PAS un asset validé.** Il est déposé, pas
  intégré. Rien ne le référence tant qu'une session ne l'a pas mesuré et
  installé — et `export_filter="all_resources"` fait que le seul fait de
  le déposer l'embarquerait dans le build si `assets_source/*` n'était
  pas dans `exclude_filter` (voir le piège payload ci-dessus).
* **Le contenu réel est à MESURER, jamais à lire dans le nom de
  fichier.** Le batch décor est arrivé décrit comme « 7 fichiers, 6
  sujets (arbre feuillu, conifère, rocher, souche, buisson, banc) » ;
  la mesure donne **6 fichiers, 5 payloads distincts, 4 sujets** — un
  doublon byte-identique, aucun rocher, aucun banc, et le « conifère »
  est en réalité un arbre mort sans feuilles (vérifié au rendu, §11).
  Le décompte annoncé et le décompte réel n'ont coïncidé sur aucun des
  trois axes.
* **Le travail d'intégration, lui, reste sur une branche**, avec la
  règle standard `staging` → validation device → `main`.

### Batch décor du 10 août 2026 : mesuré, NON installé — 2 sujets sur 4 sont viables

Aucun des `.glb` décor n'est installé, et ce n'est pas un travail laissé
à moitié : trois blocages indépendants ont été mesurés, chiffres complets
dans `docs/MESHY_SPEC.md` §11. **Ne pas relancer la mesure, elle a une
réponse.**

* **Triangles** — la frame est à **48 376 tri contre la cible de 50 000**,
  soit 1 624 de marge, dont **781 pour les props**. Le census par type
  (`TracksidePropCensus`, ajouté par ce batch) mesure **12,6 props à
  l'écran** en régime permanent. Remplacer les 3 types qui ont un sujet,
  au plancher du décimateur, met les props à **~3 945 tri (2,6× leur
  budget de 1 500)** et la frame à **~51 540, au-dessus de la cible**.
* **Payload** — les 5 `.glb` distincts importent **64,91 Mo de `.ctex`**
  contre un `.pck` livré de **4,23 Mo**. Le pire contributeur est une
  map metallic-roughness **4096×4096** par asset, soit précisément la map
  qui n'a aucun effet sur un matériau unlit.
* **Matériaux** — **aucun des 5 ne déclare `KHR_materials_unlit`**. Tous
  sont PBR (baseColor + metallicRoughness + normal). §8 impose l'unlit, et
  la table de contraste §8.2 des 6 types de props a été balayée contre des
  albédos plats mesurés.

Ce que la décimation sauve, jugé **sur rendu, pas sur prédiction**
(`scripts/dev/decimate_decor.py`, soudure puis décimation, sortie plate
unlit sans texture) : **l'arbre mort et la souche passent à ~150 tri en
restant lisibles** — le premier apporte même une silhouette que le jeu
n'a pas ; **le buisson est un match nul** ; **l'arbre feuillu devient un
blob informe, moins lisible que le cône de 25 tri qu'il remplacerait.**
Ce dernier échoue pour une raison structurelle : son caractère tient au
couple tronc/houppier et à la couleur des feuilles, or la soudure fusionne
le houppier et **la décimation ne peut pas transporter les UV** — donc
aucune texture ne survit, à aucun budget de triangles.

Installer les deux sujets viables tiendrait le budget (**props ~891 tri,
frame ~48 486**) mais engage trois choix qui appartiennent à Mathieu, et
qu'aucune mesure ne tranche : abandonner les textures comme direction
artistique du décor ; faire de l'arbre mort un remplaçant de `tree` ou un
7ᵉ type (ce qui change le mélange produit par `_PROP_KIND_WEIGHTS`, donc
le fond que les sondes de contraste F10/F11 mesurent) ; et accepter un
bord de piste mêlant souches `.glb` et rochers/bancs/panneaux procéduraux,
ces trois derniers n'ayant **aucun asset fourni**.

### Suite : les deux sujets viables sont INSTALLÉS (10 août 2026)

Branche `claude/meshy-bare-tree-stump-pnkuqm`. Les trois choix ci-dessus
ont été tranchés par Mathieu — textures abandonnées, `bare_tree` **remplace**
le type `tree` (pas de 7ᵉ type), mixage `.glb`/procédural assumé. L'arbre
feuillu et le buisson **ne sont toujours pas installés**, pour les raisons
mesurées plus haut. Chiffres complets : `docs/MESHY_SPEC.md` §8.3 et §11.

- **146 et 150 triangles**, 3,9 Ko et 3,7 Ko, `.pck` **+13 120 octets** au
  total — contre les 64,91 Mo de `.ctex` qu'auraient coûté les sources
  texturées. C'est le gain de la décision « pas de texture ».
- **`KHR_materials_unlit` est AJOUTÉ PAR NOUS**, pas hérité : aucune des
  5 sources Meshy ne le déclare (`extensionsUsed` absent partout). Ne pas
  lire un `.glb` d'`assets/models/` comme une preuve de ce que Meshy produit.
- **Pas un `ModelSlot`** (2ᵉ dérogation à §2, après les billboards de
  `Decor.gd`) : un slot adresse UN nœud fixe par son nom, un prop est un
  pool d'instances interchangeables. Le mesh est lu via le `SceneState` du
  `PackedScene` importé — **aucun nœud n'est jamais instancié ni libéré**,
  parce que libérer un `MeshInstance3D` en headless imprime `Parameter "m"
  is null` sur stderr, et ce repo compare les sorties de sondes octet par
  octet.
- **`_PROP_KIND_WEIGHTS` est intouché**, et `_place_model` consomme
  **exactement les 5 tirages** de `_prop_rng` que consommaient les deux
  placements remplacés, sur **tous** les chemins. Vérifié, pas argumenté :
  décor seedé, tous les rocher/banc/panneau/buisson visibles atterrissent à
  une position locale, une échelle et une rotation **identiques au bit près**
  face à `origin/main`.

⚠️ **Le budget propre aux props est DÉPASSÉ, et le seuil n'a PAS été bougé.**
`TrackPropsAudit` échoue sur **2 runs sur 6** (props 908–1 926 contre un
plafond de 1 500 ; baseline 459–868 sur 6 runs aussi). **La frame, elle, n'est pas affectée de façon
mesurable** : 46 825–58 143 contre 45 567–56 570 sur `origin/main` — les deux
plages se chevauchent, les deux dépassent déjà la cible de 50 000, et le bruit
run-à-run (±6 000, sonde non seedée) écrase les ~700–1 000 tri ajoutés. Le
1 500 est, de l'aveu de l'en-tête de la sonde, « ~3× le pic mesuré » de
l'époque tout-primitives et sert à **attraper une primitive laissée à la
tessellation par défaut** (~4 000 tri pour un rocher) — un détecteur de
défaut, pas un plafond de perf ; la sonde *rapporte* volontairement le total
de frame au lieu de l'asserter. **Trois sorties possibles, aucune prise ici,
c'est la décision de Mathieu** : re-décimer à ~100 tri (mais le LOD 150 est
celui qui a été jugé au rendu et approuvé) ; re-calibrer le budget props à
l'ère des meshes importés (~2 500 garde la logique du 3×) ; ou récupérer les
**16 896 tri des collectibles** (§7.2), de loin le plus gros gain, mais qui
touche la silhouette d'un objet de gameplay visible.

## Deux défauts de mesure corrigés (F10, 9 août 2026) — deux décisions de
## teinte EN ATTENTE de Mathieu, aucune action code en cours

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

**Aucune des deux ne demande de code ni de nouvelle sonde.** Ce sont des
choix de couleur/teinte réservés à Mathieu — voir `docs/PROBE_AUDIT.md`,
section « Still open after this batch », pour le détail chiffré complet.
Une fois la décision prise, il suffit de re-rouler la sonde concernée
(`PursuerContrastAudit` ou `StrikeFatalContrastAudit`) contre le nouveau
choix — rien d'autre n'a besoin de changer.

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

## Sondes : aucune ne peut tourner indéfiniment (mesuré, 9 août 2026)

Toute sonde de `scripts/dev/` est bornée par un budget **temps réel** de
900 s. Au dépassement elle imprime un verdict **INCONCLUSIVE** explicite et
sort en **code 2** — jamais 0 (faux vert), jamais 1 (un timeout n'est pas
une violation de contrat, c'est une absence de verdict).

Deux points d'entrée, parce qu'une sonde a deux formes possibles :

| forme | mécanisme | pourquoi |
|---|---|---|
| itère des frames | `ProbeWatchdog.arm(self, LABEL)` | `_process` tourne entre les frames |
| bloque dans un seul appel | `ProbeWatchdog.deadline(LABEL)` + `abort_if_exceeded()` dans la boucle | aucune frame n'existe, la boucle doit demander elle-même |

**`arm()` seul est MUET sur une sonde bloquante** — mesuré : budget 5 s,
toujours vivante à 25 s. C'était le cas de `DecorParallaxProbe` (2000
itérations dans `_ready()`) et de `PacingProbe` (`--script`, tout dans
`_init()`). Les deux sont corrigées.

`ProbeTimeoutAudit.tscn` **rend la garantie non optionnelle** : il échoue
si une sonde n'arme aucun timeout, ou l'arme après la première instruction
de `_ready()`. Vérifié rouge avant vert. À lancer après toute modification
de `scripts/dev/` — il coûte moins d'une seconde.

⚠️ **Piège d'invocation, à connaître avant de conclure qu'une sonde
plante.** Les flags moteur vont AVANT le `--`, les args applicatifs après :

```
godot4 --headless --fixed-fps 60 --path . res://scripts/dev/X.tscn -- --seed=20260806
```

`--fixed-fps` placé après le `--` est ignoré par le moteur, la simulation
tourne à ~1x le temps réel, et une sonde à 900 s simulés met ~15 minutes —
en-tête affiché puis plus rien. **Symptôme identique à un blocage, cause
totalement différente.** Le watchdog le dit maintenant lui-même : si
l'horloge de run avance encore, il imprime « NOT STUCK, JUST SLOW » et
rappelle l'ordre des flags.

⚠️ **Correction d'une passation périmée : F6 et F7 sont CLOS, mesurés.**
Une passation les décrivait comme ouverts/bloquants. C'est faux, et
`docs/PROBE_AUDIT.md` le documentait déjà comme résolu :

- **F7** — `ChargerAudit` (27 s) et `AirEnemyLandingLaneAudit` (106 s)
  terminent et passent. Les « ~50 minutes sans finir » se reproduisent
  uniquement par l'erreur d'ordre de flags ci-dessus.
- **F6** — `AirHazardAudit` est déterministe : 20 runs à la graine
  20260806, **20/20 exit 0, un seul stdout, un seul stderr** (flux
  capturés séparément).

Base de référence re-validée : les 10 sondes gatées sont **identiques au
bit près** entre `origin/main` et la branche timeout, sur les deux flux.
Il y a **SEPT** sondes-bot gatées, pas six.

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

## Déploiement staging (validation avant merge main)

**Depuis le 8 août 2026**, une branche permanente `staging` existe en plus
de `main`. Elle a son propre déploiement Vercel, sur son propre alias
stable :

- **`https://keepy-staging.vercel.app`** — build jouable de `staging`.
- `https://keepy-ten.vercel.app` reste la prod, alimentée uniquement par
  `main`, comportement inchangé.

**Pourquoi** : avant ce chantier, `main` était le seul déclencheur de build
web CI (`.github/workflows/web-build.yml`), donc aucune feature branch ne
pouvait être validée visuellement (device/navigateur) sans passer par
`main`. `staging` sert d'étape intermédiaire — merger une feature branch
dans `staging` la rend jouable sur `keepy-staging.vercel.app` sans toucher
à la prod.

**Mécanique** : `.github/workflows/web-build.yml` déclenche désormais sur
push vers `main` OU `staging`. Le job de build Godot (import + export
web) est strictement identique dans les deux cas — seule la dernière étape
diverge, en deux steps distincts et clairement labellisés dans les logs
Actions (`[PRODUCTION -- main]` / `[STAGING -- staging]`) pour qu'un échec
de l'un ne soit jamais confondu avec un échec de l'autre :
- `main` → `vercel deploy build/web --prod` (inchangé, alias prod déjà
  attaché au projet Vercel).
- `staging` → `vercel deploy build/web` (déploiement preview, URL
  jetable) puis `vercel alias set <url> keepy-staging.vercel.app` — pour
  que l'URL de staging reste stable d'un push à l'autre, exactement comme
  la prod ne change pas d'URL à chaque déploiement.

**Note recon (8 août 2026)** : le projet Vercel `keepy` a par ailleurs
l'intégration GitHub native active en parallèle (confirmé via l'API
Vercel — `source: "git"` sur les déploiements de branche) : elle crée
automatiquement une preview par branche poussée (alias du type
`keepy-git-<branche>-....vercel.app`). **Ces previews sont mortes** :
Vercel n'a aucune notion du build Godot (pas de `package.json`, aucune
commande de build détectée), donc elles servent le dépôt brut tel quel —
il n'y a pas d'`index.html` à la racine du repo (généré uniquement sous
`build/web/` par la CI), donc ces URLs renvoient systématiquement 404.
Ne pas confondre une de ces URLs `keepy-git-...` avec `keepy-staging.
vercel.app` : seule cette dernière est pilotée par la CI et sert un
build réellement jouable.

**Règle d'usage** :
- **Claude Code peut pousser directement sur `staging`** (créer la
  branche si besoin, merger des feature branches dedans, push), sans
  validation préalable de Mathieu — c'est l'environnement de test, une
  erreur y est peu coûteuse.
- **Claude Code ne merge/push JAMAIS sur `main` sans validation
  explicite de Mathieu.** Le flux normal reste : feature branch →
  `staging` (validation device sur `keepy-staging.vercel.app`) → une fois
  validé, PR/merge vers `main` sur demande explicite.

## Incident résolu : `vercel alias set` "Not able to load user (404)" (8 août 2026)

**Symptôme** : le step `Deploy to Vercel [STAGING]` échouait de façon
identique 5 fois d'affilée sur `vercel alias set ... -T "$VERCEL_ORG_ID"`
(et ses variantes `--scope <slug>` / `--scope <team_id>` testées avant),
toujours avec `Not able to load user (404)`, alors que `vercel deploy`
juste avant réussissait sans problème avec le même token.

**Cause réelle** : le `VERCEL_TOKEN` utilisé était scope **équipe**
(`keepy`). `vercel deploy` s'appuie sur `VERCEL_ORG_ID`/`VERCEL_PROJECT_ID`
pour résoudre le contexte projet sans jamais appeler `/user`, donc il
passait. `vercel alias set`, lui, résout systématiquement l'identité via
un appel `/user` avant d'agir — quel que soit le flag de scope fourni
(`--scope` slug, `--scope` team ID, `-T` team ID) — et ce token équipe
n'avait pas de compte utilisateur associé exploitable par cet appel,
d'où le 404 constant. Aucune combinaison de flags CLI ne pouvait
contourner ça : le problème était le *type* de token, pas sa syntaxe
d'invocation.

**Solution qui a fonctionné** : régénérer un `VERCEL_TOKEN` scope
**compte personnel** (`rajonrondoadkhey2095's projects`, pas team
`keepy`) et le mettre à jour dans le secret GitHub — code CI inchangé
(`-T "$VERCEL_ORG_ID"`). Confirmé sur le run #44 (workflow_dispatch,
commit `759a371`) : `vercel deploy` → preview OK, puis `vercel alias set`
→ `Success! https://keepy-staging.vercel.app now points to
https://keepy-lpisx5c3p-rajonrondoadkhey2095s-projects.vercel.app`.
Fetch direct de `keepy-staging.vercel.app` confirmé HTTP 200, contenu =
export web Godot réel (`<title>Keepy</title>`, canvas, `index.js`,
`GODOT_CONFIG` avec `index.pck`/`index.wasm`), pas une 404 Vercel.

**À retenir pour une session future** : si `vercel alias set` échoue à
nouveau avec `Not able to load user`, vérifier en priorité le **scope du
token** (personnel vs équipe) avant de retoucher les flags CLI — c'est
la variable qui a réellement résolu l'incident, pas `-T` vs `--scope`.
