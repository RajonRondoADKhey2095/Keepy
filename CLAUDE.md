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

1. **Fence à 4 backticks, toujours — jamais de Markdown brut.** Le rapport
   de fin de tâche ou de batch doit toujours être fourni ENVELOPPÉ dans un
   fence à 4 backticks (jamais du Markdown rendu directement dans la
   réponse), pour permettre la copie en un tap sur iPhone. Le rapport reste
   un bloc unique, jamais paginé en plusieurs messages ni plusieurs blocs.
   Cette règle est permanente, sans exception, et ne connaît **aucune
   distinction avec la convention Keepr** sur ce point — même exigence des
   deux côtés. (Corrigé le 17 août 2026 : une formulation antérieure avait
   pu se lire à l'envers — comme si un bloc Markdown simple, non enveloppé,
   suffisait. Ce n'a jamais été l'intention ; ce paragraphe la clarifie sans
   ambiguïté possible.)
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
unshaded a une couleur *connue* après le traitement du mode sombre.
⚠️ **CORRIGÉ le 11 août 2026 (DA permanente) — le paragraphe qui tenait
cette place disait « le mode sombre est un grade plein écran, donc c'est un
pass ÉCRAN qui atteint ces assets ». C'EST FAUX depuis le même jour : le
grade est supprimé, plus rien ne post-traite la frame.** La conséquence
pour un asset unlit est l'INVERSE de ce qui était écrit : **rien
n'atteindra jamais sa couleur** — ni lumière (il est unlit), ni pass écran
(il n'y en a plus). La couleur qu'un `.glb` porte est donc littéralement
celle qui s'affiche, pour toujours. Un asset importé avec une teinte
diurne restera diurne au milieu du marécage, et aucun réglage de scène ne
le rattrapera : il faut le corriger À LA SOURCE, ou lui appliquer un
matériau depuis le code (ce que `TrackSegment.gd` fait déjà pour l'arbre
mort et la souche, cf. `_unshaded()`).

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

⚠️ **F10/F11 : INCONCLUSIVE dans ce sandbox, comme au lot F14 la veille.** Les
deux sondes atteignent le budget 900 s du `ProbeWatchdog` et sortent en code 2.
**Pas un défaut, pas une régression** : `PursuerContrastAudit` a simulé
**51 171 s en 900 s de temps réel** (~57×), donc `--fixed-fps 60` était bien
honoré et la sonde progressait — l'indice « flag order » de son propre message
de timeout est du boilerplate générique et ne s'applique pas ici. Ce que
l'argument « mix inchangé » couvre et ne couvre pas : **F10 est hors d'atteinte**
(elle mesure la silhouette du poursuivant contre le SOL ; la teinte du sol vient
de `_tint_rng`, un flux `DecorRng` distinct dont la numérotation est inchangée
puisque aucun `DecorRng.make()` n'est ajouté ; et le keep-out interdit à tout
prop de toucher la dalle, assertion passée sur 4 000 tirages) — **et elle
échouait déjà sur `origin/main` intact**, donc un rouge ne lui est imputable
dans aucun sens. **F11 est RESTREINTE mais PAS écartée** : elle échantillonne le
monde 3D derrière le label, et deux types de props changent de silhouette et se
décalent un peu en X. Le mode de défaillance qui a fait basculer son verdict
**deux fois** (un décalage de mise en page HUD déplaçant le label) est
structurellement impossible ici — aucun nœud de HUD n'est touché — mais le canal
« fond 3D » existe. **À mesurer sur une machine capable de terminer la sonde
avant d'en tirer quoi que ce soit** ; la décision de teinte DARK/5 était déjà
ouverte et reste celle de Mathieu.

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

### Merge en production (10 août 2026, autorisation explicite de Mathieu)

`staging` (762e83f) → `main`, commit de merge `7d0c791`, après validation
device (2 captures iPhone). Re-vérifié APRÈS le merge, pas supposé porté :
`AssetContractAudit` rejoué sur le commit de merge lui-même (12/12 visuels,
0/10 colliders déplacés). CI verte, déploiement PRODUCTION effectué,
déploiement STAGING correctement skippé (push sur `main`). **Fingerprint
vérifié sur le site LIVE** (`keepy-ten.vercel.app`, pas de Deployment
Protection contrairement à staging) : `GODOT_CONFIG.fileSizes.index.pck`
embarqué = **4 736 144**, identique au chiffre du propre log CI de ce run.

⚠️ **Découverte au passage : `index.pck` n'est PAS stable en taille d'un
export a l'autre du MÊME commit** (3 exports locaux consécutifs :
4 736 128 / 4 761 392 / 4 761 376 ; CI donne un 4e chiffre, 4 736 144).
`index.wasm`/`index.js` restent identiques au md5 sur tous les runs — la
variance vient de la passe de compression VRAM de Godot sur les textures
des AUTRES assets (hibou/écureuil), pas de ces deux props (sans texture).
**Conséquence** : ne plus jamais utiliser la taille de `index.pck` seule
comme preuve de déterminisme — s'appuyer sur l'identité wasm/js + la sonde
gated byte-identique + le chiffre RÉELLEMENT servi par CI/le site, jamais
sur la comparaison entre deux exports locaux distincts. Détail complet :
`docs/MESHY_SPEC.md` §11.

## Rampe d'alarme ENEMY/AIR_ENEMY : le télégraphe serait mort en silence au premier `.glb` (11 août 2026)

Branche `claude/meshy-enemies-alarm-jump-zekdwc`. **Défaut LATENT réparé
AVANT l'arrivée des hazards Meshy** — il ne se déclenchait pas encore
(aucun `.glb` n'est installé sur `EnemyMesh`/`AirEnemyMesh`), il se serait
déclenché au premier install, sans erreur ni sonde rouge.

**Le mécanisme, mesuré et pas déduit.** Un matériau atteint une surface par
DEUX chemins, et lequel dépend de QUI a écrit le mesh : un *auteur de
scène* écrit un `surface_material_override/0` (tous les placeholders du
projet) ; un *importeur* écrit sur la SURFACE DU MESH — l'importeur glTF
de Godot ne pose **jamais** d'override. `ModelSlot.slot_material()` ne
lisait que l'override, donc renvoyait `null` pour tout asset réel, et le
null-guard de l'appelant l'avalait. Vérifié sur un asset livré
(`assets/models/keepy_stump_prop.glb`) :
`get_surface_override_material(0)` = `null`,
`mesh.surface_get_material(0)` = un vrai `StandardMaterial3D`.

Conséquence : `Obstacle._ready()` laissait `_enemy_material` à `null`,
`_apply_enemy_alarm` sortait sur son guard à chaque frame, et le rouge
d'approche — le seul signal qui dit au joueur qu'un hazard va se verrouiller
sur sa voie — devenait un **no-op silencieux**.

**Preuve AVANT / APRÈS, même sonde, aucun seuil déplacé**
(`scripts/dev/AlarmRampAudit.tscn`, nouvelle) :

| | PHASE A (placeholder) | PHASE B (modèle installé) |
|---|---|---|
| avant fix | 4/4 OK | **2 FAIL** — l'albédo ne quitte jamais `rgb(0.98,0.16,0.84)`, exit 1 |
| après fix | 4/4 OK | **4/4 OK**, exit 0 |

⚠️ **Pourquoi AUCUNE sonde ne l'avait attrapé, et c'est le vrai
enseignement.** `AssetContractAudit` installe pourtant un stand-in sur
CHAQUE slot — mais `SubstituteModel.tscn` portait un `surface_material_
override/0` : il imitait un modèle importé par sa STRUCTURE DE NŒUDS et pas
du tout par sa LIAISON DE MATÉRIAU, c'est-à-dire précisément l'axe sur
lequel vit le défaut. Le stand-in est corrigé (liaison sur le mesh, comme un
vrai `.glb`), donc cette sonde exerce désormais le chemin qui cassait.
**Règle générale : un fixture de test qui diverge du réel sur UN axe ne
protège pas de cet axe — et cette divergence-là est invisible tant que
personne ne la nomme.**

**Confirmation indépendante sur des assets RÉELS** : `AssetContractAudit`
reste vert (12/12 visuels, 0 collider déplacé) et son SEUL changement de
sortie est que les deux slots qui portent vraiment un `.glb` —
`keepy/MeshInstance3D` (écureuil) et `pursuer/Silhouette` (hibou) —
rapportent enfin leur matériau au lieu de `-`. Ces deux `-` étaient le
défaut déjà visible dans la baseline, sans que personne ne l'ait lu comme
tel.

**Non touché, vérifié** : `DarkPaletteAudit` inchangé (ENEMY 1,50/1,52 —
AIR_ENEMY 1,08/1,09, exactement la baseline), parce qu'aucun `.glb` n'est
sur ces slots et qu'ils prennent donc toujours la branche override.
`ProbeTimeoutAudit` : 33 sondes, toutes armées.

⚠️ **Résidu ASSUMÉ, documenté au point d'appel plutôt que caché : sur un
matériau importé UNLIT, la moitié ÉMISSION de la rampe est inerte.** Les
deux appliers bougent albédo ET émission ; §8/§9 imposent l'unlit à tout
asset, et une surface unshaded ignore l'émission. Sur un `.glb` le
télégraphe est donc porté par l'ALBÉDO seul — c'est réel, et c'est pourquoi
la sonde gate l'albédo. **Corollaire : un cue d'ÉMISSION ne peut pas vivre
sur le slot du tout** — c'est exactement pourquoi les yeux du poursuivant
sont des nœuds engine-side et pas une partie du `.glb` (`Pursuer.gd`, « THE
EYES ARE DELIBERATELY NOT SLOTS »). Les deux patrons ne se contredisent
pas : cue émission → nœud séparé lit ; cue albédo → matériau du slot.

### Correction §7.2 : le « within » de la ligne hazards était la MÊME erreur que §7.3

Mesuré (`get_faces()/3`), budget §7.1 = **1 200 tri par hazard** :
`ChargerMesh` 8 / `DodgeMesh` 12 / `JumpMesh` 12 / `JumpMarkerMesh` 44 /
`StomperMesh` 768 — mais **`EnemyMesh` 3 456 (2,88x)** et **`AirEnemyMesh`
4 096 (3,41x)**. Le total famille tenait dans les 8 400 uniquement parce que
4 variantes sur 6 sont des primitives à ~10 triangles : un ENEMY + un
AIR_ENEMY font à eux seuls **7 552**, soit 90 % de la ligne famille. Cause
racine identique au constat 1 (collectibles) : une primitive laissée à la
tessellation par défaut de Godot. Détail et tableau : `docs/MESHY_SPEC.md`
§7.4.

⚠️ **Conséquence pour le batch hazards à venir, et elle INVERSE l'attente
habituelle** : remplacer ENEMY et AIR_ENEMY par des assets sous leur cap de
1 200 est une **BAISSE** de triangles (−2 256 et −2 896 par instance), pas
une hausse. Ce sont JUMP/DODGE (boîtes 12 tri) et CHARGER (prisme 8 tri) où
un import coûte. Budgéter chaque asset contre le **per-asset** §7.1, jamais
contre la ligne famille.

### PHASE 2 (install JUMP) : NON FAITE — asset source absent, rien à mesurer

**`assets_source/hazards/` n'existe ni en local ni sur `origin/main`**
(vérifié par `git ls-tree -r origin/main`, pas supposé : les deux seules
correspondances « hazard » du dépôt sont `scripts/dev/AirHazardAudit.*`).
Les 6 `.glb` annoncés (tronc moussu, crapaud, souche dressée, rat,
libellule, sanglier) n'ont pas été poussés. Conformément à l'exception
actée, c'est Mathieu qui les dépose depuis l'interface web GitHub, sur
`main`, sous `assets_source/hazards/`.

Rien n'a été deviné à leur place : ni orientation, ni scale, ni coût
triangle, ni albédo. **Ce qui est prêt pour la prochaine session** : le
défaut de rampe est fermé et gaté, §7.4 donne le budget par asset et le
sens réel du gain, §2.1 donne le piège de liaison de matériau, et §10
inclut désormais `AlarmRampAudit` dans la checklist d'acceptation.

⚠️ **PÉRIMÉ ~2 h plus tard, et le CHEMIN ANNONCÉ ÉTAIT FAUX.** Les 6 `.glb`
ont été poussés sur `main` (`51aa01d`, 08:26 UTC) **sous
`assets_source/ennemis/`, PAS `assets_source/hazards/`** — chercher au
chemin annoncé ci-dessus ne trouve rien. Phase 2 est faite : voir la
section suivante.

## PREMIER HAZARD MESHY INSTALLÉ : le tronc moussu (JUMP) — 11 août 2026

Branche `claude/meshy-enemies-alarm-jump-etaz9i`, **posée sur le fix de
rampe ci-dessus** (session concurrente, voir l'avertissement en fin de
section). Chiffres complets : `docs/MESHY_SPEC.md` §7.4 et §11.

`assets/models/keepy_jump_log.glb` sur `Obstacle/JumpMesh` — **150
triangles, 3,7 Ko, plat, unlit, sans texture**, portant l'ambre autorisé de
JUMP.

⚠️ **Le fichier a été identifié PAR MESURE, jamais par son nom.** Le lot
contenait DEUX sujets tronc/rondin : `Low_Poly_Log` (1,901 x **0,534** x
0,608 → couché → **JUMP**) et `Crimson_Hollow_Trunk` (1,031 x **1,901** x
0,992 → debout → **DODGE**). Confirmé par rendu 3 axes : section ronde de
profil, **mousse sur la face +Y**, axe déjà en travers de la piste, donc
`model_rotation_degrees` reste à zéro.

⚠️ **DEUX prémisses du brief étaient FAUSSES, mesurées d'entrée** : les six
assets arrivent à **4 000–5 258 tri** (pas « cap 1 200 ») et **aucun** ne
déclare `KHR_materials_unlit` (tous PBR + une map metallic-roughness
4096x4096, la seule map qu'un matériau unlit ne peut pas utiliser).
Troisième lot d'affilée où l'annoncé et le mesuré divergent.

`scripts/dev/decimate_hazard.py` (nouveau) **importe** le pipeline glTF de
`decimate_decor.py` au lieu de le copier. **Perdre la texture ne coûte RIEN
à un hazard** : §8 gate son albédo et plus rien ne post-traite la frame,
donc un rondin texturé et éclairé n'aurait AUCUN ratio de contraste connu.
Plat + unlit est le seul état permis — c'est pourquoi l'arbre feuillu décor
reste ininstallable alors que celui-ci est *amélioré* par la même opération.

**LOD 150 choisi AU RENDU** : contour indiscernable de celui à 800, et sur
un asset unlit plat les triangles n'achètent que la **silhouette** (aucun
ombrage ne révèle la géométrie interne). Matériau dessiné vérifié
`UNSHADED albedo=(1.0000, 0.7800, 0.2800)`, aller-retour exact de
`StandardMaterial3D_Jump`.

⚠️ **Échelle 0,63483 = X calé sur le collider (1,20), par ÉQUITÉ** (§4 : un
visuel plus large que sa hitbox fait passer une esquive légale pour
illégale). L'asset est bien plus élancé que la boîte : il **sous-remplit**
la hitbox en Y (0,331 vs 0,700) et Z (0,379 vs 1,000). **Aucune échelle
uniforme ne corrige ça** (remplir Y demande s=1,343 → X=2,538, au-delà du
seuil de bavure de voie). Signalé, pas maquillé : ~0,37 m de hitbox
au-dessus du rondin visible et ~0,31 m devant lui. **À juger sur device.**

**`ModelSlot.model_offset` est nouveau** (3e de la famille avec
`model_scale`/`model_rotation_degrees`). Bouger le SLOT aurait été un diff
plus petit et aurait cassé le fallback en silence : une boîte de 0,7 centrée
sur un nœud abaissé s'enfonce dans le sol.

⚠️ **`DarkPaletteAudit` lit JUMP 3,28 → 3,02:1 ET LA COULEUR N'A PAS
CHANGÉ.** Artefact de mesure, **prouvé** : l'histogramme de la fenêtre
d'échantillon donne **783 px de (251,196,70) — identique au bit près au
placeholder — + 54 px de SOL**. Résoudre `observé = (1-f)·jump + f·sol` par
canal donne **f = 0,0704 / 0,0686 / 0,0680** : trois canaux d'accord sur une
seule fraction de mélange, ce qu'un changement de couleur ne peut pas
produire. La silhouette du rondin est plus fine que celle de la boîte, donc
la fenêtre fixe centrée sur le **centre de l'AABB** mord son bord inférieur.
**Défaut de sonde famille F10, laissé à son propre lot** : un clamp
adaptatif a été écrit, **mesuré comme non contraignant** (l'AABB projette
149,8 x 59,0 px) et **retiré plutôt que gardé comme un fix qui ne corrige
rien**. Régler la constante jusqu'à ce que le chiffre sorte juste serait
exactement le faux-vert que `ProbeCoverage.gd` documente cinq fois.

**Colliders intouchés** : `JumpShape` toujours `Box(1.2, 0.7, 1.0)` à
+0,350, `AssetContractAudit` 12/12 visuels, 0 collider déplacé. Sa table
PHASE 1 marque désormais **`[glb]` vs `[-- ]`** par ligne — son en-tête
disait « placeholder meshes », ce qui a cessé d'être vrai ici pour la
première fois. On voit maintenant que **trois** slots portent un asset :
Keepy, `JumpMesh`, et le `Silhouette` du poursuivant.

**Le piège payload a tenu** : les 166 Mo de sources brutes
d'`assets_source/ennemis/` ne partent PAS dans le build (0 entrée importée
dans le pack, seulement des chaînes de chemin du uid-cache).

**Reste ouvert** : les 4 autres sujets (crapaud/STOMPER, libellule/AIR_ENEMY,
castor/ENEMY, sanglier/CHARGER) + le tronc debout (DODGE) sont mesurés et
rendus mais **non installés** ; le sous-remplissage de hitbox ; le défaut de
sonde F10 ; et le fait que **sur un asset importé la rampe d'alarme est
portée par l'ALBÉDO seul** (l'émission est inerte sur un matériau unlit) —
rien à juger tant qu'aucun asset ENEMY/AIR_ENEMY n'est installé.

### Merge en production (11 août 2026, autorisation explicite de Mathieu)

`staging` (729e907) → `main`, commit de merge **`de7933e`**, après validation
device : le rondin se lit bien comme « à sauter », et le sous-remplissage de
hitbox (~0,37 m au-dessus, ~0,31 m devant) a été **jugé juste à l'usage**.

⚠️ **Ce n'était PAS un fast-forward** : `main` était en avance de 2 commits
sur `staging` (le push des `.glb` bruts par Mathieu, `51aa01d` + `3f04b89`,
jamais passés par `staging`). Vrai merge `--no-ff`, aucun conflit.
**Conséquence utile** : le seul écart `main` ↔ `staging` est ces 6 sources
brutes sous `assets_source/ennemis/`, exclues du build par `exclude_filter` —
donc **ce qui est livré en prod est exactement l'arbre validé sur staging**.

Re-vérifié APRÈS le merge, sur le commit de merge lui-même (pas supposé
porté) : **7 sondes exit 0** — `AssetContractAudit` (12/12 visuels, 0
collider déplacé, `JumpShape` toujours `Box(1.2, 0.7, 1.0)` @ +0,350),
`DarkPaletteAudit` (4 hazards gatés au-dessus de 3,0 ; 0 échantillon
manqué), `AlarmRampAudit`, `ProbeTimeoutAudit`, `DeathModelAudit`,
`ChargerShapeProbe`, `PursuerFramingAudit`. Import + export Web exit 0.

CI run **#87** verte, déploiement PRODUCTION effectué, STAGING correctement
skippé. **Fingerprint vérifié sur le site LIVE** (`keepy-ten.vercel.app`,
HTTP 200, `x-vercel-cache: MISS`) : `GODOT_CONFIG.fileSizes` =
`index.pck 4 742 256` / `index.wasm 35 376 909`, `last-modified
11 Aug 2026 10:00:22 GMT`. **`index.wasm` est IDENTIQUE à l'export local**
au octet près — c'est lui la preuve d'identité, pas le `.pck` (rappel :
sa taille n'est pas stable d'un export à l'autre du même commit).

### ⚠️ INCIDENT : DEUX SESSIONS AGENTIQUES CONCURRENTES, le même jour

**La règle n°1 de ce fichier a été enfreinte à nouveau** (précédent du
6 août 2026). Deux sessions ont reçu le même brief : l'une a livré le fix de
rampe et l'a mergé sur `staging` à 06:22 UTC ; l'autre (celle-ci) a refait
le MÊME fix indépendamment, ~3 h plus tard, puis a découvert la collision au
`git fetch` avant tout merge.

**Résolu comme le précédent le prescrit** : la seconde session a comparé les
deux versions et **abandonné son doublon** plutôt que de forcer par-dessus.
Le fix incumbent est conservé ; seule la Phase 2 (unique, non dupliquée) a
été rebasée sur `staging`. Les deux fixes différaient sur un point réel —
le fallback de `slot_material()` : matériau du MESH importé (retenu) contre
matériau AUTORISÉ du slot (abandonné). Choix arbitré explicitement par
Mathieu.

**Ce que ça confirme du danger** : les deux sessions ont produit des mesures
**identiques** là où elles se recouvraient (ENEMY 3 456 / 2,88x, AIR_ENEMY
4 096 / 3,41x, §7.4 écrite deux fois avec les mêmes chiffres) — donc le
gaspillage est réel et silencieux, et rien dans l'outillage ne l'a signalé.
Seul un `git fetch` avant merge l'a révélé. **Faire ce fetch AU DÉBUT, pas à
la fin.**

## SECOND HAZARD MESHY INSTALLÉ : le crapaud (STOMPER) — 11 août 2026

Branche `claude/stomper-asset-processing-usqg79`, partie de `main`/`staging`
alignés (`f4b3190`). `assets/models/keepy_stomper_toad.glb` sur
`Obstacle/StomperMesh` — **148 triangles, 3,7 Ko, plat, unlit, sans
texture**, portant le bleu glacier existant de STOMPER. Chiffres complets :
`docs/MESHY_SPEC.md` §7.4 et §11.

**Identifié PAR RENDU, pas par son nom** — et cette fois le nom était juste,
ce qui ne change rien à la méthode : les cinq fichiers restants ont été
rendus sur trois axes. C'est le **seul sujet accroupi** du lot (1,898 ×
**0,703** × 1,672) ; les quatre autres sont debout. Mapping complet établi
au passage : libellule → AIR_ENEMY, rat → ENEMY, sanglier → CHARGER, tronc
debout → DODGE. **Orientation vérifiée, pas héritée du rondin** : rendu
depuis +Z et depuis −Z, la face (bouche + yeux) est côté +Z, donc côté
joueur → `model_rotation_degrees` reste à zéro.

⚠️ **LE RATIO 2,1:1 N'A JAMAIS PU ÊTRE EN DANGER, et c'est une propriété,
pas de la chance : `model_scale` est un flottant UNIFORME, donc le rapport
largeur/hauteur est INVARIANT par changement d'échelle.** L'asset le fixe à
**2,692:1** — plus TRAPU que le cylindre placeholder (2,143:1) — à
n'importe quelle échelle. La lisibilité « on enjambe, ce n'est pas un mur »
est préservée et légèrement renforcée. Ce que l'échelle décide réellement,
c'est la TAILLE ABSOLUE.

**Échelle 0,79510 = largeur calée sur la base du placeholder (1,50), PAS
sur le collider — dérogation ASSUMÉE à la règle du rondin JUMP.** Cette
règle (§4 : un visuel plus large que sa hitbox fait passer une esquive
légale pour illégale) existe pour une esquive latérale — **or un STOMPER
n'en a pas** : il se colle à la voie du joueur par conception
(`blocks_lane_switch`). L'appliquer mécaniquement aurait rétréci de 20 % en
largeur et 36 % en hauteur un télégraphe que `TELEGRAPH-STOMPER` qualifie
de porteur, et aurait **aggravé le seul axe qui contraint vraiment** ici :
le dégagement VERTICAL, puisqu'on saute par-dessus. Deux propriétés
mesurées sur la scène construite que l'autre option n'a pas : largeur au
repos **1,500 = exactement la base du placeholder** et au pic de pulse
**1,830 = exactement le pic du placeholder** (présence latérale inchangée),
et au pic il atteint **0,680 contre la hitbox de 0,700** là où le
placeholder DÉBORDE à 0,854.

**Résidus signalés, pas maquillés** : 0,143 de hitbox au-dessus du crapaud
visible, et un visuel 0,345 plus profond que la hitbox (sens indulgent pour
un obstacle qu'on saute). Bavure de voie vérifiée : demi-largeur 0,915 au
pic contre un bord de Keepy voisin à 1,500. **À juger sur device.** Le pic
de pulse enfonce le crapaud de 0,077 sous le sol — **le placeholder fait
exactement pareil** (la pulse scale le SLOT, les deux meshes ont le même
bas en local), donc aucun artefact nouveau.

⚠️ **`DarkPaletteAudit` lit 3,43 → 3,41 sur UNE ligne, et le chiffre GATÉ
n'a pas bougé du tout.** Même famille que le 3,28 → 3,02 du rondin, et
vérifié de la même façon plutôt que supposé identique. Diff complet contre
`f4b3190` en worktree séparé : **exactement une ligne diffère**, la mesure
STOMPER en brume profonde. Histogramme de la vraie fenêtre d'échantillon
(sonde instrumentée puis revertée) : **196 px de STOMPER dans les DEUX
arbres, ZÉRO pixel de sol**, valeur dominante **identique au bit près** au
placeholder — contrairement au cas JUMP qui avait 54 px de sol. 86 px sur
196 sont un cran 8 bits plus bas en G/B : surface courbe unlit à
profondeur légèrement différente sous le fog exponentiel, pas un changement
de couleur (matériau confirmé sur la scène construite : `UNSHADED
albedo=(0,6200, 0,8600, 1,0000)`, aller-retour exact de
`StandardMaterial3D_Stomper`). **Le nombre que la sonde gate est le pire
des deux bouts de la respiration : 3,41:1 avant ET après**, 0,41 au-dessus
du plancher, toujours la plus large marge des quatre hazards gatés.

**Budget triangles : c'est une BAISSE, la première du lot hazards.** Le
placeholder STOMPER n'était pas une boîte à 12 tri mais un `CylinderMesh` à
**768** — la seule primitive de la famille qui coûtait déjà cher. 768 → 148
= **−620 par instance vivante**, famille un-de-chaque **8 490 → 7 870**.
L'inversion annoncée en §7.4 pour ENEMY/AIR_ENEMY vaut donc aussi, en plus
doux, pour STOMPER : **trois variantes sur six sont moins chères en art
importé qu'en primitive Godot**. Seuls DODGE et CHARGER coûteront vraiment.

**Colliders intouchés** : `StomperShape` toujours `Box(1.2, 0.7, 1.0)` @
+0,350. Sondes : `AssetContractAudit` (12/12 visuels, 0 collider déplacé),
`DarkPaletteAudit`, `AlarmRampAudit`, `ProbeTimeoutAudit` (33 sondes
armées), `DeathModelAudit`, `ChargerShapeProbe`, `PursuerFramingAudit`
(26,9 % max) — **toutes exit 0**. Import + export Web **exit 0**. Les
sondes gameplay seedées sont **byte-identiques** à la baseline. Piège
payload tenu (0 entrée `assets_source` importée dans le pack).

**Reste ouvert** : quatre sujets non installés (libellule/AIR_ENEMY,
rat/ENEMY, sanglier/CHARGER, tronc debout/DODGE), le sous-remplissage de
hitbox et le sur-remplissage en profondeur — **jugement device**.

## TROISIÈME HAZARD MESHY INSTALLÉ : le tronc debout (DODGE) — 11 août 2026

Branche `claude/dodge-hazard-processing-69i3nj`, partie de `staging`
(`290fa30`, donc **posée sur le STOMPER encore en attente de validation
device**). `assets/models/keepy_dodge_trunk.glb` sur `Obstacle/DodgeMesh` —
**150 triangles, 3,7 Ko, plat, unlit, sans texture**. Chiffres complets :
`docs/MESHY_SPEC.md` §7.4 et §11.

**Identifié PAR MESURE, puis confirmé au rendu** : `Crimson_Hollow_Trunk`
est le **seul sujet restant dont l'axe dominant est Y** (1,031 × **1,901** ×
0,992) ; les quatre autres sont longs en X ou en Z. Un DODGE est un mur
pleine hauteur qu'on CONTOURNE, donc « il est debout » n'est pas un détail,
c'est toute la classification. Rendu sur 4 vues avant décimation : tronc
creux debout, cassé net en haut, moignons de branches bas sur le fût,
section en anneau vue de dessus. **Il n'a pas de face et il est quasi
symétrique de révolution autour de Y** — contrairement au crapaud, il n'y
avait donc aucune question d'orientation à trancher : `model_rotation_
degrees` reste à zéro **parce qu'il n'y a rien à orienter**, pas parce que
la réponse du crapaud a été recopiée.

### ⚠️ LE PREMIER LOT QUI DOIT CHANGER UNE COULEUR GATÉE — et le chiffre le prouve

**DODGE était le SEUL des quatre hazards gatés encore LIT** (pas de
`shading_mode = 0`, seul de sa famille). Son 3,19:1 mesuré était donc le
ratio d'un albédo **multiplié par l'ambiante de la scène**, pas de l'albédo
lui-même. §8 impose l'unlit à un asset importé, ce qui SUPPRIME cette
multiplication — donc reporter la couleur telle quelle, ce que les deux
assets précédents pouvaient faire sans risque, **n'aurait PAS tenu le
ratio ici** :

| albédo | ombrage | rendu | vs sol |
|---|---|---|---|
| `(0,30, 0,025, 0,025)` | LIT (baseline) | `(0,2157, 0,0588, 0,0157)` | **3,19:1** |
| `(0,30, 0,025, 0,025)` | unlit, reporté tel quel | `(0,2954, 0,0289, 0,0263)` *(prédit)* | **2,945:1 — SOUS LE PLANCHER** |
| **`(0,21, 0,0175, 0,0175)`** | **unlit, livré** | **`(0,2039, 0,0197, 0,0000)`** | **3,37:1** |

Le solve tient la **teinte rouge DODGE EXACTEMENT** (12:1:1 — seule la
valeur bouge, jamais le ton), contre la luminance du sol mesurée par la
sonde elle-même et une fraction de fog de 0,0238 relevée sur le **STOMPER
déjà unlit** (le seul asset de la scène dont la correspondance
albédo→rendu ne demande aucun modèle d'éclairage). Le modèle reproduit la
baseline à 0,005 point de ratio près (3,194 prédit contre 3,19 mesuré) —
c'est ce qui lui a donné le droit de PRÉDIRE l'échec ci-dessus au lieu de
le découvrir.

### C'est un VRAI changement de couleur, PAS l'artefact de fenêtre du JUMP

Le rondin JUMP était passé de 3,28 à 3,02 pour une raison de MESURE (54 px
de sol dans la fenêtre). Ici c'est l'inverse, et c'est vérifié par
histogramme sur les DEUX arbres (sonde instrumentée puis revertée) :

| arbre | contenu de la fenêtre | valeur dominante | ratio |
|---|---|---|---|
| baseline (`origin/staging`, boîte LIT) | **196 px, 0 px de sol** | `(55,15,4)` | 3,19:1 |
| ce lot (tronc unlit) | **196 px, 0 px de sol** | `(52,5,0)` | 3,37:1 |

**Les deux fenêtres sont à 100 % des pixels d'objet, aux deux bouts de la
respiration.** Aucune des deux mesures n'est contaminée, donc l'écart entre
elles EST la couleur de l'objet. La signature est sans ambiguïté : le
**canal vert s'effondre de 15 à 5** pendant que le rouge bouge à peine —
exactement ce que produit la suppression d'une multiplication par une
ambiante `(0,42, 0,5, 0,35)`, à dominante verte, sur un albédo dont le vert
propre est quasi nul.

⚠️ **Un détail observé et délibérément NON expliqué plutôt qu'expliqué à
tort** : le bleu livré lit **exactement 0** là où l'albédo et le fog
prédisent ~5/255, alors que le vert, à valeur d'albédo identique, lit bien
le 5 prédit. Aucun tonemapper n'est configuré (`scenes/Game.tscn` n'a pas
de clé `tonemap_*`), ce n'est donc pas ça. Laissé en observation ouverte
parce que le poursuivre ne change rien : un cran 8 bits de bleu sur une
silhouette quasi noire déplace le ratio de **moins de 0,01**, et la pureté
de la fenêtre ci-dessus prouve déjà que la mesure porte sur l'objet.

### Contraste : le plus serré des quatre devient le deuxième plus large

| hazard | avant | après | marge sur le plancher 3,0 |
|---|---|---|---|
| **DODGE** | **3,19:1** | **3,37:1** | **+0,37** *(était +0,19, le plus serré)* |
| JUMP | 3,02:1 | 3,02:1 | +0,02 |
| CHARGER | 3,20:1 | 3,20:1 | +0,20 |
| STOMPER | 3,41:1 | 3,41:1 | +0,41 |

Le chiffre gaté est le **pire des deux bouts** : 3,39 shallow / **3,37
deep**. DODGE passe du plus serré au deuxième plus large ; le plus serré
est désormais CHARGER (+0,20). Les trois autres lignes sont
**bit-identiques** à la baseline, comme elles doivent l'être.

### Échelle : la règle du rondin JUMP appliquée telle quelle, PAS une dérogation

`model_scale = 1,18793` cale le X du visuel sur le **1,200 exact** du
collider — demi-largeur **0,600, identique au bit près à la boîte
placeholder**, donc la présence latérale ne bouge pas d'un millimètre.
Contrairement au STOMPER, c'est ici §4 appliqué sans exception : **un DODGE
existe pour être esquivé LATÉRALEMENT**, donc la largeur est l'axe qui
décide si une esquive légale se lit comme légale.

L'alternative écartée mérite d'être consignée parce qu'elle paraît meilleure
sur le papier : caler sur Y (s=1,052) donnerait la hauteur exacte de la
hitbox, mais laisserait le visuel à 1,085 dans une hitbox de 1,200 — soit
**la hitbox plus large que le tronc de 0,058 par côté**, c'est-à-dire le
joueur qui dégage le tronc à l'écran et meurt sur du vide. C'est le sens
PUNITIF de la même erreur, sur la mécanique exacte qui donne son nom au
hazard.

**Résidus signalés, pas maquillés** : le tronc dépasse de **0,253 au-dessus**
de la hitbox et est **0,111 plus profond** en Z. Les deux vont dans le sens
indulgent. Le dépassement en hauteur ne peut pas faire passer un saut légal
pour illégal **puisqu'il n'existe aucun saut légal par-dessus un DODGE**
(injumpable par construction, hitbox 2,0 contre un pic de saut à 1,558), et
le sur-remplissage en profondeur ne fait que laisser le joueur frôler le
bord visuel sans être touché — même sens que les 0,345 acceptés du crapaud.
**À juger sur device.**

`model_offset = (0, 0,13542, 0)` pose le tronc au sol : le mesh est centré
sur son propre origine, donc au `y = +1,00` du slot il s'enfonçait de 0,135.

**Le matériau placeholder a été changé AUSSI, volontairement** :
`StandardMaterial3D_Dodge` passe `shading_mode = 0` avec le même nouvel
albédo. C'est désormais le chemin de FALLBACK uniquement (le `.glb` dessine
son propre matériau unlit) — mais le laisser LIT aurait fait diverger le
placeholder et l'asset livré **sur l'axe même que ce lot change**, c'est-à-dire
le piège « fixture qui diverge du réel » que `AlarmRampAudit` existe pour
fermer. Le réintroduire dans le repo qui le documente serait indéfendable.

**Triangles** : `DodgeMesh` 12 → **150**, +138 par instance vivante. C'est
l'une des trois variantes dont §7.4 prédisait qu'un import COÛTERAIT (les
deux boîtes à 12 tri et le prisme à 8), face aux −620 du STOMPER et aux
−2 256 / −2 896 qui attendent encore sur ENEMY et AIR_ENEMY. Famille
un-de-chaque **7 870 → 8 008**, toujours sous la ligne de 8 400.

**Colliders intouchés** : `DodgeShape` toujours `Box(1.2, 2.0, 1.0)` @
+1,00. Sondes : `AssetContractAudit` (12/12 visuels, 0 collider déplacé),
`DarkPaletteAudit`, `AlarmRampAudit`, `ProbeTimeoutAudit`,
`DeathModelAudit`, `ChargerShapeProbe`, `PursuerFramingAudit` (37,1 % max,
CAPTURE exempt par conception) — **toutes exit 0**. Import + export Web
**exit 0**. Piège payload tenu (**0** ressource `assets_source` importée
dans le pack).

⚠️ **`PursuerFramingAudit` doit se lancer EN HEADLESS ici** : sous
`xvfb-run` + `llvmpipe` elle dépasse 10 min sans finir, alors qu'en headless
elle rend son verdict en quelques secondes. Elle ne lit aucun pixel
(`unproject_position` est un calcul de transform pur), donc elle n'a rien à
faire sous xvfb — même famille que la leçon déjà consignée sur
`DecorStabilityAudit`. À ne pas confondre avec les sondes qui, elles, DOIVENT
tourner sous xvfb parce qu'elles échantillonnent des pixels
(`DarkPaletteAudit`).

**Reste ouvert** : trois sujets non installés (libellule/AIR_ENEMY,
rat/ENEMY, sanglier/CHARGER) ; le dépassement en hauteur et le
sur-remplissage en profondeur ; et **le rouge plus sombre** — aucune sonde
ne dit qu'une couleur est JUSTE, seulement qu'elle passe le plancher.
Est-ce que DODGE se lit encore comme ROUGE et pas comme NOIR sur un écran
de téléphone à vitesse réelle, c'est la décision de Mathieu.

### Merge en production (12 août 2026, autorisation explicite de Mathieu)

`staging` (`fdf8d95`) → `main`, commit de merge **`1b9c5a8`**, après
validation device des DEUX hazards d'un coup : le crapaud se lit bien comme
« à sauter », le tronc debout comme « à contourner », et **la question
laissée ouverte par le lot DODGE est tranchée — le rouge plus sombre reste
lu comme ROUGE, pas comme NOIR**, à vitesse réelle. Les débords de hitbox
des deux assets ont été jugés non gênants à l'usage.

⚠️ **Ce n'était PAS un fast-forward alors qu'il aurait pu l'être.**
`git merge-base --is-ancestor origin/main origin/staging` était vrai
(`staging..main` VIDE : main n'avait rien que staging n'avait pas, à la
différence du merge JUMP de la veille où les `.glb` bruts de Mathieu le
faisaient diverger). Merge `--no-ff` quand même, aucun conflit — comme les
deux merges de prod précédents de ce repo (`7d0c791`, `de7933e`) : un
fast-forward ne laisse aucun point de décision lisible dans l'historique et
masque ce qui part réellement en prod.
**Conséquence utile** : l'arbre du commit de merge est **byte-identique à
celui de `fdf8d95`** (`git diff HEAD origin/staging` vide) — ce qui est
livré en prod est donc littéralement l'arbre validé sur device, pas une
recomposition.

**Rejoué SUR LE COMMIT DE MERGE lui-même, pas supposé porté — 7 sondes
exit 0** : `AssetContractAudit` (12/12 visuels, **0/10 colliders déplacés**,
`DodgeShape` toujours `Box(1.2, 2.0, 1.0)` @ +1,000 et `StomperShape`
toujours `Box(1.2, 0.7, 1.0)` @ +0,350), `DarkPaletteAudit`,
`AlarmRampAudit` (4/4 PHASE A, 4/4 PHASE B, PHASE C OK),
`ProbeTimeoutAudit` (33 sondes, toutes armées), `DeathModelAudit`,
`ChargerShapeProbe`, `PursuerFramingAudit` (INTRO max 23,6 % / VISIBLE max
27,0 %, cap 30 %). Import + export Web **exit 0**.

**La table PHASE 1 d'`AssetContractAudit` montre désormais CINQ slots
`[glb]`** — Keepy, `pursuer/Silhouette`, `JumpMesh`, et les deux de ce lot,
`DodgeMesh` et `StomperMesh`. Sept slots restent au placeholder.

⚠️ **Trois lignes d'erreur apparaissent sur stderr pendant ces sondes et
AUCUNE n'est imputable à ce lot — vérifié contre un worktree sur `f4b3190`
(main pré-merge, import propre), pas argumenté.** À connaître, parce que les
trois ont l'air alarmantes et qu'une future session les prendra sinon pour
une régression de son propre lot :
- `DeathModelAudit` → `Parameter "m" is null` (dummy driver, à la libération
  des nœuds, APRÈS son verdict) — stdout **ET** stderr byte-identiques à la
  baseline.
- `PursuerFramingAudit` → 104 lignes `Function blocked during in/out signal`
  (`set_monitoring`) — stdout **ET** stderr byte-identiques à la baseline,
  aux 104 lignes près.
- `DarkPaletteAudit` → `ERROR: LANE BARRIER BELOW CONTRAST FLOOR`
  (silhouette 1,16:1) — présent à l'identique sur la baseline, et la sonde
  sort quand même en 0 : c'est un report, pas un gate (le gate de la barrière
  est la STRIPE, 17,36:1).

**Le diff `DarkPaletteAudit` base → merge fait EXACTEMENT 3 lignes**, toutes
les trois attribuables aux deux assets installés, tout le reste byte-identique :
DODGE **3,20 → 3,39** (shallow) et **3,19 → 3,37** (deep) — le nouvel albédo
unshaded ÉLARGIT sa marge, il ne la consomme pas ; STOMPER **3,43 → 3,41**
(deep), 0,02 de dérive de silhouette dans la fenêtre d'échantillon. Les
quatre hazards gatés tiennent le plancher 3,0:1 (DODGE 3,37 / JUMP 3,02 /
CHARGER 3,20 / STOMPER 3,41), 0 échantillon manqué. `JUMP` reste à son 3,02
d'artefact de fenêtre déjà documenté au lot précédent, inchangé ici.
ENEMY 1,52 / AIR_ENEMY 1,09 : toujours mesurés dans leur teinte d'ALARME et
toujours non gatés, comme avant.

CI run **#92** verte (3 min 12 s) puis **#93** verte (2 min 59 s, le commit
de doc), déploiement PRODUCTION effectué, STAGING correctement skippé (push
sur `main`) dans les deux cas. **Fingerprint vérifié sur le site LIVE**
(`keepy-ten.vercel.app`, HTTP 200, `x-vercel-cache: MISS`) :
`GODOT_CONFIG.fileSizes` = `index.pck 4 755 120` / `index.wasm 35 376 909`,
`last-modified 12 Aug 2026 06:46:43 GMT`.

⚠️ **Le `.pck` a pris TROIS valeurs différentes pour le MÊME contenu de jeu
en une heure — 4 755 072 (export local), 4 755 136 (run #92), 4 755 120
(run #93) — et c'est la confirmation de l'instabilité déjà consignée le
10 août, pas une alerte.** Le contenu de jeu est pourtant identique entre
#92 et #93 (le commit de doc ne touche que `CLAUDE.md`, qui n'est pas une
ressource Godot et n'entre donc pas dans le pack). **`index.wasm` vaut
35 376 909 sur les trois** — c'est LUI la preuve d'identité, et le `.pck`
ne doit jamais servir seul de preuve de déterminisme.

### ⚠️ DEUX déploiements se disputent la PROD à chaque push sur `main` — ~3 min de 404

**Découvert en vérifiant le fingerprint de ce merge, et ce n'est PAS un
défaut introduit par ce lot : le comportement est identique sur les deux
pushes du 11 août.** Le projet Vercel `keepy` a l'intégration GitHub NATIVE
active EN PLUS du déploiement CI, et les deux ciblent `production` :

| source | reconnaissable à | ce qu'elle sert | délai après push |
|---|---|---|---|
| **native Vercel** | `meta.branchAlias` présent | le **dépôt BRUT** — pas d'`index.html` à la racine → **404** | quelques secondes |
| **CI** (`vercel deploy build/web --prod`) | `meta.gitRootDirectory = build/web` | le vrai export Godot | ~3 min |

Chronologie mesurée sur les déploiements réels, pas déduite :

```
11 Aug 09:55:56  de7933e  NATIVE -> 404
11 Aug 09:59:10  de7933e  CI     -> OK
11 Aug 10:01:38  f4b3190  NATIVE -> 404
11 Aug 10:04:59  f4b3190  CI     -> OK
12 Aug 06:38:50  1b9c5a8  NATIVE -> 404
12 Aug 06:41:54  1b9c5a8  CI     -> OK   (fingerprint lu ici, 200)
12 Aug 06:43:05  23aaa20  NATIVE -> 404  (prod EN 404 pendant ~3 min)
12 Aug 06:46:06  23aaa20  CI     -> OK   (prod guérie)
```

**Conséquences, dans l'ordre d'importance :**
1. **Chaque push sur `main` met la prod en 404 pendant ~3 minutes.** Ça se
   répare tout seul quand la CI dépose son build, donc personne ne l'a
   jamais vu — mais c'est réel, et un merge de prod en fait DEUX (le merge
   puis le commit de doc), soit deux fenêtres.
2. **Si la CI échoue APRÈS que le natif ait déposé, la prod RESTE en 404**
   jusqu'au push suivant. C'est le vrai danger, et rien ne l'alerte.
3. **Ne jamais lire un fingerprint sans regarder l'heure du dernier
   déploiement.** Un 404 sur `keepy-ten.vercel.app` dans les minutes qui
   suivent un push ne veut PAS dire que le build est cassé — c'est très
   probablement la fenêtre ci-dessus. Vérifier `meta.gitRootDirectory` du
   déploiement production courant avant de conclure quoi que ce soit.

**Non corrigé, décision de Mathieu** : désactiver l'intégration GitHub native
du projet Vercel (Settings → Git) supprimerait la fenêtre entièrement, et la
CI est déjà le seul chemin qui produit un build jouable. À faire en Console
Vercel, aucune session agentique ne peut le faire. En attendant, la seule
parade est de savoir que la fenêtre existe.

**Piège payload re-vérifié sur le pack exporté** : les **407 Mo**
d'`assets_source/` (dont les 6 sources brutes des hazards) ne partent pas
dans le build — `.pck` à 4,75 Mo, et les seules occurrences
`res://assets_source/...` dedans sont des chaînes de chemin du uid-cache, pas
des ressources importées. `exclude_filter` tient.

**Reste ouvert, inchangé par ce merge** : les trois derniers sujets non
installés (libellule/AIR_ENEMY, rat/ENEMY, sanglier/CHARGER) ; les débords
de hitbox des trois assets installés, désormais jugés acceptables mais
toujours réels ; et le fait que **sur un asset importé la rampe d'alarme est
portée par l'ALBÉDO seul** — rien à juger tant qu'aucun asset ENEMY/AIR_ENEMY
n'est installé.

## QUATRIÈME HAZARD MESHY INSTALLÉ : le rat (ENEMY) — 12 août 2026

Branche `claude/enemy-rat-asset-pipeline-c8b5lg`, partie de `main` =
`staging` (`037cb26`). `assets/models/keepy_enemy_rat.glb` sur
`Obstacle/EnemyMesh` — **148 triangles, 3,7 Ko, plat, unlit, sans texture**.
**Premier asset à atterrir sur un slot dont le matériau est ANIMÉ par le
gameplay** (§2.1) : la rampe d'alarme d'approche. Chiffres complets :
`docs/MESHY_SPEC.md` §7.4 et §11.

**Le nom dit castor, le rendu dit RAT.** Quatrième fichier du lot dont le nom
ne survit pas à un rendu — et le premier où le nom ne se contente pas d'être
vague, il **nomme le mauvais animal** : museau pointu, petites oreilles
rondes, et une queue **fine, longue et courbe** là où un castor a une palette
plate. L'attribution ne repose pas que sur la ressemblance : les trois sujets
restants ont été rendus dans la même passe, donc elle tient aussi par
élimination (`Shadowtusk` = sanglier à défenses, `Emerald_Geometric_Dra` =
insecte dont la bbox 1,901 × 0,960 × **0,170** est presque entièrement de
l'aile). **Un seul rongeur dans le lot : ENEMY n'avait qu'un candidat.**

**Orientation MESURÉE, pas héritée du crapaud** : rendu depuis +Z on voit
museau, yeux, oreilles et pattes avant ; depuis −Z uniquement la croupe et la
queue qui s'échappe. Le rat fait donc déjà face au joueur →
`model_rotation_degrees` reste à zéro.

### ⚠️ PERDRE L'ÉMISSION EST UN VRAI CHANGEMENT — et il RENFORCE le télégraphe

`_apply_enemy_alarm` bouge **albédo ET émission** (énergie 0,3 →
`ENEMY_ALARM_EMISSION_ENERGY` 1,5). Une surface unshaded ignore totalement
l'émission : sur cet asset le cue perd un canal et **l'albédo le porte seul**.
Ce n'est pas une note de bas de page — c'est ce qui FIXE LA DIRECTION de la
couleur de base :

- `ENEMY_ALARM_ALBEDO` `(0,95, 0,08, 0,12)` rend en unlit à **luminance
  0,187**, le sol rend à **0,150** : les deux sont à **1,20:1** l'un de
  l'autre. **L'alarme ne peut donc PAS se lire contre le sol.**
- Elle ne peut se lire que contre la couleur AU REPOS, qui doit donc être
  loin de 0,187. **Une seule direction marche** : en dessous, l'alarme
  ÉCLAIRCIT. Au-dessus (un violet pâle au-delà de 0,55) la rampe serait un
  ASSOMBRISSEMENT — ce n'est pas à ça que ressemble une alarme.

**Valeur seulement, teinte tenue EXACTEMENT** au violet livré `0,52 : 0,08 :
0,72` — même discipline que DODGE, et le violet est l'identité de type
d'ENEMY. **0,35× → `(0,182, 0,028, 0,252)`**, choisi comme l'assombrissement
le **PLUS FAIBLE** qui franchit le plancher §8 avec une vraie marge, pas le
plus profond qui le franchit tout court : chaque cran plus bas achète une
marge que personne n'a demandée et dépense de la lisibilité de teinte sur une
silhouette de 0,6 m.

### Mesuré aux deux bouts, sonde instrumentée puis revertée

`DarkPaletteAudit` échantillonne ENEMY à `CAPTURE_Z`, assez près pour que la
rampe soit **entièrement saturée** — son libellé `(resting)` est faux depuis
toujours (déjà documenté). Une instrumentation temporaire a tenu la rampe à
t=0 et t=1 et échantillonné les deux, sur l'arbre baseline ET sur celui-ci :

| | repos vs sol | **alarmé** vs sol | TÉLÉGRAPHE (repos ↔ alarmé) |
|---|---|---|---|
| avant — placeholder, LIT + émissif | 1,57 / 1,57 | **1,50 / 1,52** | 2,35 / 2,38 |
| après — rat `.glb`, UNLIT | **3,27 / 3,23** | **1,20 / 1,20** | **3,92 / 3,87** |

Trois lectures, une seule est une perte :

- **Le télégraphe lui-même se RENFORCE : 2,35 → 3,92.** Perdre la moitié
  émission n'a pas affaibli le cue ; l'albédo avait plus de place que
  l'émission n'en utilisait, et le choix de la couleur de base est ce qui l'a
  achetée. C'est le chiffre qui communique réellement « le danger monte ».
- **La lisibilité au REPOS plus que double : 1,57 → 3,27**, franchissant le
  plancher 3,0 **pour la première fois dans l'histoire d'ENEMY**. Un violet
  éclairé sur un sol olive était quasi invisible au repos.
- **Le rouge alarmé contre le sol BAISSE : 1,50/1,52 → 1,20/1,20.** Cause
  **mesurée, pas devinée** : avec l'émission à 1,5 le placeholder pousse le
  canal rouge à **saturer** — la baseline imprime littéralement
  `rendered=(1, 0.2485, 0.1142)`. L'unlit supprime cette surcharge, donc le
  rouge d'alarme rend à sa propre valeur d'albédo, plus sombre et donc plus
  proche de la luminance du sol.

⚠️ **NON corrigé, délibérément.** La couleur alarmée est
`ENEMY_ALARM_ALBEDO`, une constante de télégraphe **PARTAGÉE avec
AIR_ENEMY**. La bouger, c'est retoucher le télégraphe et pas l'art, sur deux
hazards dont un n'a pas encore d'asset — §8 parque déjà ça comme la décision
de Mathieu. À dire clairement : **cette paire n'a JAMAIS été lisible contre
le sol** (1,50 était aussi loin sous le plancher 3,0 que 1,20 l'est), et
c'est exactement pourquoi elle est **non gatée**. Ce qui change, c'est que
l'état au repos est désormais le lisible et que l'alarme est un changement
**à partir de lui** — c'est comme ça qu'un cue d'escalade est censé marcher.

### Échelle : §4 appliqué tel quel, et une CAPSULE n'est pas une BOÎTE

`model_scale = 0,46266` cale X sur les **0,600** du collider — la règle du
rondin JUMP, sans dérogation, pour la même mécanique : **un ENEMY s'esquive
en changeant de voie**, donc un visuel plus large que sa hitbox ferait passer
une esquive légale pour illégale. Caler sur Y (s = 0,68639) mettrait le
visuel **0,290 plus large** que la capsule : cette erreur dans son sens
punitif.

**Le RATIO est invariant par échelle**, comme pour le crapaud — **1,272:1
avant et après** — parce que `model_scale` est un flottant uniforme. Mais
c'est une propriété de l'ÉCHELLE, pas du COLLIDER, et **la capsule ajoute une
contrainte qu'une boîte n'a pas** :

> Une boîte a la même demi-largeur à toutes les hauteurs. Celle d'une capsule
> **s'annule aux deux bouts** — rayon plein seulement sur `y = 0,30 .. 0,40` —
> et un quadrupède au ras du sol est le plus large exactement là où la
> capsule est la plus étroite.

Mesuré par bande de hauteur : le visuel sort de **0,063 à 0,178** hors de la
capsule sur les 0,15 m du bas (pattes et queue, là où la capsule se termine
en pointe). Sur l'ENSEMBLE de la silhouette, non : demi-largeur maximale du
visuel **0,304** contre **0,300** pour la capsule — **quatre millimètres** —
et une esquive latérale se décide sur la section la plus large, pas sur la
bande au sol. Un rendu du rat superposé à la capsule placeholder depuis la
même caméra le confirme : le corps est bien à l'intérieur, seules les pattes
et la queue franchissent le bord bas.

`model_offset = (0, −0,10231, 0)` pose le bas du visuel à **y = 0,0000** pile.

**Résidus signalés, pas maquillés :**
- **0,228 de hitbox AU-DESSUS du rat visible** (visuel 0,472 contre hitbox
  0,700). Indulgent latéralement mais **DÉFAVORABLE POUR LE SAUT** : un ENEMY
  est sautable, donc un saut qui dégage visuellement le rat peut quand même
  accrocher. Atténué par construction et pas par espoir — le `JumpMarkerMesh`
  cyan flotte à `JUMPABLE_OBSTACLE_TOP_HEIGHT`, donc la vraie hauteur de
  dégagement est déjà dessinée, indépendamment du mesh. Plus petit que les
  0,37 du rondin JUMP, jugés justes à l'usage.
- **0,254 de visuel au-delà de la hitbox en Z.** Indulgent : on peut frôler
  le museau ou la queue sans être touché. Même sens que les 0,345 acceptés du
  crapaud.

**À juger sur device**, et spécifiquement comme une question de SAUT.

### Le matériau placeholder bouge AUSSI, volontairement

`StandardMaterial3D_Enemy` prend `shading_mode = 0` et le même nouvel albédo.
Le laisser éclairé et émissif ferait **diverger le fallback de l'asset livré
sur l'axe même que ce lot change** — c'est-à-dire reconstruire, dans le slot
qui l'a justement exposé, le piège « fixture qui diverge du réel » que
`AlarmRampAudit` existe pour fermer. Ça aligne aussi ENEMY sur les quatre
placeholders hazards déjà unshaded ; AIR_ENEMY reste éclairé, aucun asset
n'ayant atterri dessus.

### `AlarmRampAudit` gate désormais l'ASSET RÉEL (PHASE D)

**Le vrai point de ce lot.** Le fix de rampe du 11 août était prouvé contre
`SubstituteModel.tscn` — un fixture **construit pour ressembler** à un
`.glb`. Lui faire dire ce que fait un asset réel reproduirait, à un cran de
distance, exactement l'erreur qui a rendu le fix nécessaire.

**PHASE D rejoue les deux mêmes assertions sur `Obstacle.tscn` tel qu'il est
livré**, sans aucun fixture : vrais octets, vrai importeur, vraie classe de
matériau (le cast `StandardMaterial3D` d'`Obstacle._ready()` échoue en
silence si elle change un jour), vraie liaison, vrai duplicate par instance.

```
--- PHASE D: Obstacle.tscn AS SHIPPED (real assets, no fixture) ---
  OK   ENEMY as shipped [glb]: all 1 drawn surface(s) reach rgb(0.95, 0.08, 0.12)
  OK   ENEMY as shipped [glb]: resets to its own base rgb(0.18, 0.03, 0.25)
  OK   AIR_ENEMY as shipped [-- ]: ... base rgb(0.12, 0.85, 0.22)
```

Le marqueur `[glb]` / `[-- ]` est **lu sur le slot**, jamais déduit de la
phase : le jour où un asset est ajouté ou retiré, le log le dit au lieu de
dégénérer en silence en une seconde copie de PHASE A.

⚠️ **PHASE A a dû changer avec.** Elle obtenait le placeholder gratuitement
tant qu'aucun slot ennemi ne portait d'asset ; dès qu'un en porte un, « no
model installed » devenait une seconde lecture du rat livré sous un libellé
qui dit le contraire. Elle **efface désormais `model_scene` explicitement**.

### Triangles : la BAISSE prédite par §7.4, dépassée de 1 052

`EnemyMesh` **3 456 → 148**, soit **−3 308 par instance vivante**. §7.4
prédisait −2 256 : les deux chiffres ne se contredisent pas et l'ancien
n'était pas faux — **−2 256 est le gain contre le cap unitaire de 1 200**
(3 456 − 1 200), donc le maximum qu'un asset *au* cap pourrait rendre.
L'asset arrive à 148, un huitième du cap : la prédiction était un
**plancher sur le gain, pas une estimation**. Lu pareil, le −2 896
d'AIR_ENEMY est aussi un plancher : décimé au même LOD ~150, il rendrait
**−3 946**.

Famille un-de-chaque, hazards seuls : **8 008 → 4 700**. `AirEnemyMesh` à
4 096 pèse maintenant **87 % de toute la famille** et reste la plus grosse
primitive laissée à la tessellation par défaut de toute la scène.

### Validation

`AlarmRampAudit` (**12/12 OK**, PHASE D comprise), `AssetContractAudit`
(12/12 visuels, **0/10 colliders déplacés**, `EnemyShape` toujours
`Capsule(r 0,300, h 0,700)` @ +0,350), `DarkPaletteAudit` (0 échantillon
manqué), `ProbeTimeoutAudit` (33 sondes, toutes armées), `DeathModelAudit`,
`ChargerShapeProbe`, `PursuerFramingAudit` (INTRO 23,6 % / VISIBLE 27,0 %) —
**toutes exit 0**. Import + export Web **exit 0**.

**Les diffs contre la baseline sont exactement aussi petits qu'ils doivent
l'être** (worktree séparé sur `origin/main`, comparé et pas supposé) :
`AssetContractAudit` **une seule ligne** (la ligne ENEMY) ; `DarkPaletteAudit`
**deux lignes** (ENEMY aux deux bouts) — DODGE 3,39/3,37, JUMP 3,04/3,02,
CHARGER 3,20/3,21, STOMPER 3,41/3,41 **byte-identiques** ; les quatre autres
sondes **byte-identiques sur les deux flux**.

**Piège payload tenu** : **0** ressource `assets_source` importée dans le
pack (58 chaînes de chemin du uid-cache, aucun `.scn`/`.ctex` dérivé) contre
**407 Mo** de sources brutes sur disque. `index.pck` 4 761 792 / `index.wasm`
35 376 909 — le `.pck` n'est **pas** offert comme preuve, cf. l'instabilité
déjà consignée.

**Reste ouvert** : deux sujets non installés (libellule/AIR_ENEMY,
sanglier/CHARGER) ; les 0,228 de hitbox au-dessus du rat (**jugement device,
et c'est une question de SAUT**) ; et le rouge alarmé à 1,20:1 — pas une
régression que ce lot puisse corriger sans retoucher un télégraphe partagé.

## CINQUIÈME HAZARD MESHY INSTALLÉ : la libellule (AIR_ENEMY) — 12 août 2026

Branche `claude/air-enemy-dragonfly-decimation-67g5x8`, partie de `staging`
(`cfcc78b`, donc **posée sur le rat ENEMY**).
`assets/models/keepy_air_enemy_dragonfly.glb` sur `Obstacle/AirEnemyMesh` —
**998 triangles, 17,7 Ko, plat, unlit, sans texture**. **Premier asset du
projet dont le LOD est choisi sur un critère AUTRE que le compte de
triangles.** Chiffres complets : `docs/MESHY_SPEC.md` §7.4 et §11.

### ⚠️ LA PRÉMISSE DU BRIEF EST FAUSSE, ET ÇA REND LE RÉSULTAT PLUS FORT

Le brief prévenait : « le visuel actuel est un TORUS PERCÉ, le nouveau modèle
DOIT rester ajouré ». **La contrainte est juste ; la référence qu'elle nomme
ne l'est pas.** Mesuré en rastérisant la projection du torus le long de l'axe
caméra : **0,00 % d'aire ouverte enclose, zéro région enclose.** Un
`TorusMesh` Godot a son trou sur l'axe Y, la caméra le voit **par la
tranche**, et tout rayon traversant la silhouette rencontre le tube quelque
part. Le placeholder est percé en **TOPOLOGIE** et plein en **SILHOUETTE**.

La libellule ne PRÉSERVE donc pas une ouverture que le hazard avait : elle en
**INTRODUIT une qu'il n'a jamais eue**. Le risque que le brief pointait était
réel, mais dans l'autre sens — il n'y avait rien à perdre, seulement quelque
chose à ne pas réussir à gagner.

### LOD 1000 et NON 150 — la mesure a donné tort à la réponse habituelle

L'ouverture est **notée directement**, pas déduite du compte de triangles :
on rastérise la silhouette telle que le joueur la voit, on remplit le fond
depuis le bord, et ce qui reste est le fond **enclos par** le maillage.

| LOD | aire ouverte | morceaux pleins | plus gros morceau |
|---|---|---|---|
| **150** *(la valeur des 4 autres)* | **0,85 %** | **14** | 78,3 % |
| 300 | 3,17 % | 25 | 87,5 % |
| 800 | 20,64 % | 23 | 98,1 % |
| **1000** *(retenu)* | **27,61 %** | **16** | **99,6 %** |
| 1200 | 28,53 % | 9 | 99,8 % |
| source (4 000) | 30,57 % | 3 | 99,9 % |

⚠️ **À 150 la membrane de l'aile ne se referme pas, elle SE DÉSINTÈGRE** —
c'est pourquoi le chiffre d'ouverture *baisse* au lieu de monter : les vides
cessent d'être **enclos** parce que l'aile autour a disparu. La silhouette
éclate en 14 morceaux et se lit comme des débris flottants. **La colonne
« morceaux pleins » est ce qui distingue « refermé » de « tombé en
morceaux »** — deux échecs opposés qu'un taux d'ouverture seul ne sait pas
séparer, et c'est précisément le piège que le brief demandait de vérifier.

1000 est le genou (1200 achète 0,9 point de plus pour 200 triangles) **et
tient sous le plafond §7.1 de 1 200 par hazard** : l'ajouré n'a donc rien
coûté qu'il ait fallu acheter au budget.

**Jugé à la TAILLE ÉCRAN RÉELLE, pas à la résolution de rendu** : FOV
vertical 75° sur un viewport 1080x1920 donne 1251/d px par mètre, soit ~120 px
à 20 m et ~340 px au plus près. Re-noté là : LOD 1000 tient 10,9 %
d'ouverture à 120 px et 27,6 % à 246 px, contre 3,0 % et 0,9 % pour LOD 150.

### Triangles : le plus gros gain par instance du projet

Le placeholder est un `TorusMesh` laissé à la tessellation par défaut de
Godot (64x32) = **4 096 triangles**, la plus grosse primitive de toute la
scène. L'install fait **−3 098 par instance vivante**, et la famille
un-de-chaque tombe **4 700 → 1 602** (mesuré des deux côtés en worktree
séparé, pas déduit). §7.4 prévoyait −3 946 : cet écart de 848 est **acheté
délibérément**, parce que le −3 946 supposait un LOD ~150 que ce sujet ne
peut pas utiliser.

### ⚠️ LE TÉLÉGRAPHE S'ÉLARGIT — mesuré avant/après, pas déduit par analogie

AIR_ENEMY est le SEUL hazard **LIT *et* émissif à énergie 1,1** (ENEMY est à
0,3). Passer unlit supprime une multiplication **ET** un terme additif, donc
l'albédo livré n'a rien à voir avec ce que le joueur voit. Sonde jetable
construite sur la scène/caméra/échantillonnage de `DarkPaletteAudit`, jouée
sur `origin/staging` en worktree séparé puis après l'install :

| | avant (torus, LIT+émissif) | après (libellule, unlit) |
|---|---|---|
| slot | `[-- ]` | `[glb]` |
| repos, dominante | `rgb(0,2442, 1,0000, 0,3188)` — lum **0,7315** | `rgb(0,2353, 0,9882, 0,3059)` — lum **0,7113** |
| alarme, dominante | `rgb(1,0000, 0,2654, 0,1281)` — lum **0,2546** | `rgb(0,9373, 0,0784, 0,1098)` — lum **0,1893** |
| **télégraphe repos↔alarme** | **2,57:1** | **3,18:1** |

**Le cue est PLUS LARGE après l'install** — l'inverse du risque annoncé.
Perdre l'émission assombrit l'**alarme** bien plus (0,2546 → 0,1893) que le
**repos** (0,7315 → 0,7113), parce que l'albédo de repos a été **résolu pour
reproduire la couleur RENDUE** au lieu d'être reporté brut. Reporté brut,
`(0,12, 0,85, 0,22)` aurait rendu vers 0,50 : un tiers de la luminosité de
repos perdu, et le cue rétréci avec.

**Deux recoupements indépendants** en sont tombés : l'alarme dominante lit
**0,1893** contre le 0,187 que le lot ENEMY avait dérivé pour l'alarme unlit,
et alarme-vs-sol calcule **1,20:1** contre le « à 1,20:1 près » qu'il avait
mesuré. Autre session, autre sonde, mêmes chiffres.

⚠️ **Le SENS de la rampe s'INVERSE par rapport à ENEMY, et c'est correct.**
ENEMY devait être ASSOMBRI pour que son alarme s'ÉCLAIRCISSE en rouge (un
rongeur sombre siégeait près de la luminance de l'alarme). AIR_ENEMY repose à
0,71 contre une alarme à 0,19 : sa rampe est un large **assombrissement** plus
un virage de teinte de ~107°, les deux canaux d'accord, dans la seule
direction disponible.

### ⚠️ Un artefact d'échantillonnage que CET asset crée, et comment il a été séparé

La moyenne sur la fenêtre de 14 px de `DarkPaletteAudit` **n'est pas** la
couleur de cet objet, et c'est le premier hazard pour lequel c'est vrai : le
torus est plein en projection (fenêtre à 100 % d'objet), tandis qu'un treillis
d'ailes préservé **laisse passer le fond** et tire la moyenne vers lui —
**61 % de la fenêtre est de l'objet** après l'install. Même famille que la
contamination de fenêtre du rondin JUMP (3,28 → 3,02), mécanisme opposé.

Séparé par **histogramme**, pas par argument : c'est la valeur dominante qui
montre que la couleur de repos n'a quasiment pas bougé (0,7315 → 0,7113,
2,8 %) alors que la moyenne semble chuter bien plus. La ligne AIR_ENEMY de
`DarkPaletteAudit` bouge **1,08/1,09 → 1,32/1,32** pour la même raison —
non gatée, et elle monte.

**Diff `DarkPaletteAudit` base → lot : EXACTEMENT 3 lignes**, toutes les trois
AIR_ENEMY (les deux bouts de la respiration + le « pire hazard » qui passe de
1,08 à 1,20, ENEMY devenant le pire). Tout le reste byte-identique.

### Échelle : la règle §4, méritée deux fois

`model_scale = 0,63173` cale X sur les **1,200** exacts du collider.
AIR_ENEMY la mérite doublement : il s'esquive **en changeant de voie**, et une
fois **posé il devient sautable** — un visuel plus large que sa hitbox ferait
donc passer une esquive légale pour illégale.

Il reproduit la présence latérale du placeholder **au millimètre** (1,20000
contre 1,2), **améliore** le remplissage vertical (0,350 du torus → 0,606), et
**supprime** les 0,2 de débord en Z du torus au-delà de la hitbox de 1,0 :
l'install est plus proche de sa propre hitbox sur **les trois axes** que la
primitive qu'il remplace.

⚠️ **Aucun `model_offset`** — premier hazard qui n'en a pas besoin. Le mesh
arrive centré sur sa propre origine à **1,7 mm près une fois mis à l'échelle**
(mesuré, pas supposé). Un collider centré sur le slot veut un visuel centré
sur le slot, et écrire 1,7 mm de bruit de mesure dans la scène prétendrait
une précision qui n'existe pas. Les quatre autres sont ancrés au SOL ;
celui-ci est ancré au CENTRE parce que sa hitbox l'est.

**Colliders intouchés** : `AirEnemyShape` toujours `Box(1.2, 1.2, 1.0)` @
+2,358. Sondes, **toutes exit 0** : `AlarmRampAudit` (**PHASE D lit désormais
`[glb]` pour AIR_ENEMY** et gate la rampe sur l'asset livré — atteint
`rgb(0.95, 0.08, 0.12)`, revient à `rgb(0.24, 1.00, 0.31)`),
`AssetContractAudit` (12/12 visuels, **0/10 colliders déplacés**),
`DarkPaletteAudit` (0 échantillon manqué, 4 hazards gatés au-dessus de 3,0),
`ProbeTimeoutAudit` (**33 sondes**, retour exact à la baseline après retrait
des sondes jetables), `DeathModelAudit`, `ChargerShapeProbe`,
`PursuerFramingAudit`. Import + export Web **exit 0**.

**Sondes gameplay seedées : BYTE-IDENTIQUES à `origin/staging`** sur les DEUX
flux (graine 20260806, worktree séparé) — `ChargerAudit`, `ShrinkAudit`,
`ComboAudit`. C'est le bar attendu d'un lot purement visuel : ce lot ne
touche ni logique, ni RNG, ni collider, et l'identité au bit près le dit plus
fort qu'un simple verdict identique.

**Piège payload tenu** : **0** ressource `assets_source` importée dans le pack
contre **407 Mo** de sources brutes. `index.pck` 4 791 552 / `index.wasm`
35 376 909 (identique aux lots précédents — c'est LUI la preuve d'identité).
Le `.glb` livré déclare `KHR_materials_unlit` (used ET required) et porte
**0 image, 0 texture, 0 sampler**, attribut `POSITION` seul — toute map est
supprimée par construction, pas par réglage d'import.

**SIX slots portent désormais un asset** : Keepy, `pursuer/Silhouette`,
`JumpMesh`, `DodgeMesh`, `StomperMesh`, `AirEnemyMesh`.

**Reste ouvert** : ~~**le sanglier/CHARGER est le DERNIER sujet non
installé**, et le seul où un import ajoutera vraiment des triangles (son
placeholder est un prisme à 8 tri)~~ — **CLOS le 12 août 2026**, installé à
LOD 560 pour **+552 tri**, la prédiction retombant juste (voir la section
sanglier/CHARGER) ; **le vert de repos est désormais porté par l'albédo
seul** — il reproduit la couleur rendue à 2,8 % de luminance près, mais
aucune mesure ne dit qu'un vert plat se lit comme un vert lumineux en
mouvement sur un téléphone ; et **0,594 de hitbox au-dessus et en dessous de
la libellule visible** (l'arc de saut est fixe et calé sur le haut de la
hitbox, donc aucun saut légal n'est en danger — reste à juger si le volume
létal se lit plus gros qu'il n'en a l'air). **Jugement device.**

## LE RAT (ENEMY) CHANGE DE TEINTE : violet → brun-gris naturel (12 août 2026)

Branche `claude/enemy-rat-color-fix-w0kyew`, partie de `staging` (`68ffba0`).
**Ce n'est PAS un install** : le rat est en place depuis le matin même, sa
géométrie, son échelle, son offset et son collider sont **intouchés**. Seul
`baseColorFactor` bouge, plus le placeholder qui le double. Chiffres complets :
`docs/MESHY_SPEC.md` §11.

**Retour device** : le violet livré `(0,182, 0,028, 0,252)` se lit **ROUGE** à
vitesse réelle, pas comme un animal. C'est pire qu'une couleur simplement
laide — ça met l'état AU REPOS dans la famille de teinte de l'ALARME, alors que
l'alarme est le seul autre état que ce matériau possède. Remplacé par
**`(0,135, 0,102, 0,076)`** — brun-gris chaud, H 26,4° / S 0,44 / V 0,135 en
brut, H 35,3° / S 0,52 **rendu** (le fog tire la teinte et le chroma vers le
HAUT ici, il ne les délave pas).

### ⚠️ SEULE LA TEINTE BOUGE — et c'est CE choix qui protège le télégraphe

L'argument de direction qui avait fixé cette valeur au départ **ne dit rien de
la teinte** : il porte entièrement sur la position de la LUMINANCE au repos par
rapport aux 0,187 de l'alarme (en dessous, pour que la rampe soit un
ÉCLAIRCISSEMENT). Tenir la luminance, c'est donc préserver le cue **par
construction et pas par chance** — luminance brute 0,011186 → 0,011344, +1,4 %.

Mesuré aux deux bouts de la respiration, rampe **épinglée à t=0 et t=1** avec le
`_physics_process` de l'obstacle coupé (sonde jetable bâtie sur la scène, la
caméra et la fenêtre d'échantillon de `DarkPaletteAudit`, puis revertée) :

| | repos rendu | repos vs sol | **télégraphe (repos ↔ alarme)** |
|---|---|---|---|
| avant (violet) | `(0,1765, 0,0353, 0,2471)` | 3,27 / 3,23 | **3,92 / 3,87** |
| **après (brun-gris)** | **`(0,1294, 0,1020, 0,0627)`** | **3,27 / 3,26** | **3,92 / 3,90** |

Le télégraphe est tenu **exactement** au bout clair et **gagne 0,03** au bout
profond. **Fenêtre à 784 px d'UNE seule couleur distincte, avant comme après,
aux deux bouts** — aucune des deux mesures n'est contaminée, donc l'écart entre
elles EST la couleur de l'objet (preuve façon DODGE, pas l'artefact de fenêtre
du rondin JUMP).

### Confusion vérifiée contre TOUS les objets de piste, pas les deux annoncés

| contre | contraste | Δteinte (avant → après) |
|---|---|---|
| STOMPER (bleu glacier) | 11,17:1 | 77,9° → **166,8°** *(s'améliore nettement)* |
| **DODGE (rouge sombre)** | **1,04:1** | 88° → **27,2°** *(la paire la plus proche)* |
| JUMP (ambre) | 9,94:1 | → 8,5° *(séparé en VALEUR, 10:1)* |
| CHARGER (rose) | 10,49:1 | → 69,1° |
| décor souche / banc / panneau | 1,35 / 1,84 / 2,38 | 147-150° → **31-34°** |
| décor arbre / rocher / buisson | 1,05 / 1,15 / 1,09 | 166-173° → **71-79°** |

⚠️ **DEUX de ces lignes sont de vrais COÛTS, et ne sont pas maquillées** : face
à DODGE et aux props olive, la séparation de teinte RÉTRÉCIT. Ce sur quoi
chacune repose à la place :
- **DODGE** rend `(52,7,0)` à saturation **1,00** ; le rat rend `(33,26,16)` à
  **0,52** — 3,7× d'écart sur le canal vert, une teinte pure quasi-noire contre
  un brun mat. Et un tronc debout injumpable de 2 m n'est pas un quadrupède au
  ras du sol de 0,6 m.
- **Les props sont hors de la dalle** (keep-out), jamais adjacents à un hazard.
  Le rat tient d'ailleurs le **meilleur contraste d'objet sombre contre la
  piste** de tout ce qui est mesuré ici — 3,27:1 contre 2,42 (souche), 1,78
  (banc), 1,38 (panneau).
- **Aucune des deux ne compte dans la fenêtre de réaction** :
  `ENEMY_ALARM_RAMP_WINDOW_S` vaut 4,5 s, donc au moment où le joueur doit agir
  le rat est `(239,20,28)` et à 11:1 de tout le tableau. Le rôle de la couleur
  au repos est l'IDENTITÉ À DISTANCE, pas la lecture du danger.

La teinte retenue est **délibérément à mi-chemin des deux collisions** (rendue
35,3° : 27,2° de DODGE, 31,4° du prop le plus proche) — la pousser vers l'un
achète de la marge en la dépensant sur l'autre.

**`ENEMY_ALARM_ALBEDO` est INTOUCHÉE** — partagée avec AIR_ENEMY, la bouger
serait une retouche de télégraphe sur deux hazards, pas une retouche d'art sur
un. Le placeholder `StandardMaterial3D_Enemy` suit le `.glb`, comme à
l'install : le laisser sur l'ancien violet ferait diverger le fallback de
l'asset livré **sur l'axe même que ce lot change**.

**Le `.glb` est repassé PAR le pipeline, pas patché à la main** — géométrie
relue du fichier livré et réécrite par `decimate_decor.write_glb`. Prouvé sans
perte **d'abord** : réécriture avec l'ANCIENNE couleur et comparaison
byte-à-byte réussie contre l'asset livré, donc la seule différence possible
dans le nouveau fichier est `baseColorFactor`. Vérifié après : **chunk BIN
byte-identique** (2 688 o, 76 verts, 148 tri), `KHR_materials_unlit` préservé.

⚠️ **C'est un APLAT, pas une variation entre facettes — vrai écart avec le
rendu de référence, signalé et non contourné.** Le décimateur **ne peut pas
transporter les UV** (déjà consigné pour l'arbre feuillu décor) ; et des
couleurs par sommet **MULTIPLIERAIENT** avec l'écriture d'albédo de la rampe
d'alarme, transformant en rouge marbré le seul signal qui doit se lire
instantanément. Tous les chiffres de contraste du projet sont par ailleurs
calculés sur un albédo plat unique.

**Validation** : `DarkPaletteAudit` **byte-identique stdout ET stderr** — le
résultat PRÉDIT, et la confirmation la plus forte que sa ligne `ENEMY
(resting)` mesurait bien l'alarme depuis toujours (4 hazards gatés inchangés :
DODGE 3,39/3,37, JUMP 3,04/3,02, CHARGER 3,20/3,21, STOMPER 3,41/3,41, 0
échantillon manqué). `AlarmRampAudit` **12/12 OK, diff de exactement DEUX
lignes** (la couleur de base ENEMY sur le chemin placeholder et sur le chemin
`.glb`), stderr identique. `AssetContractAudit`, `ProbeTimeoutAudit`,
`DeathModelAudit`, `ChargerShapeProbe`, `PursuerFramingAudit` : exit 0. Import
+ export Web exit 0, `index.wasm` 35 376 909. Piège payload tenu.

**Reste ouvert** : est-ce qu'un brun-gris sombre se lit comme un ANIMAL et pas
comme un débris, à vitesse réelle sur un téléphone — aucune sonde ne répond, et
c'est tout l'objet du lot ; les 27° de teinte avec DODGE (mesurés et argumentés
par la saturation et la silhouette, mais seul un œil à vitesse réelle tranche) ;
l'aplat ; et ~~**le sanglier/CHARGER, toujours le dernier sujet non
installé**~~ — **CLOS le 12 août 2026**, voir la section sanglier/CHARGER.

## SIXIÈME ET DERNIER HAZARD MESHY INSTALLÉ : le sanglier (CHARGER) — 12 août 2026

Branche `claude/charger-hazard-decimation-9j7aeq`, partie de `main` = `staging`
(`756b943`). `assets/models/keepy_charger_boar.glb` sur `Obstacle/ChargerMesh` —
**560 triangles, 10,7 Ko, plat, unlit, sans texture**, portant le rose existant
de CHARGER **verbatim**. **Le lot hazards est terminé : les six variantes
portent désormais un asset.** Chiffres complets : `docs/MESHY_SPEC.md` §7.4 et §11.

C'est l'install la plus contrainte des six, et les trois raisons se cumulent :
CHARGER est le **seul hazard FATAL**, il détenait la **marge de contraste gatée
la plus fine** (3,20:1), et son télégraphe le plus fort est une **forme pointée
vers le joueur** — le seul cue qui survit à toute palette par construction.

**Identifié au rendu ; le nom était juste, ce qui ne change rien à la méthode.**
Rendu sur six axes d'abord : depuis **+Z** museau, yeux, oreilles, défenses et
pattes avant ; depuis **−Z** uniquement la croupe et la queue. Bbox **0,831 ×
1,128 × 1,903**, dominante en Z. Les deux prémisses habituelles retombent
justes, mesurées : source à **4 848 tri** (pas le cap 1 200) et **aucun
`KHR_materials_unlit`**.

### ⚠️ `model_rotation_degrees` N'EST PAS à zéro ici — et l'asset n'y est pour rien

Les cinq autres l'ont laissé à zéro. Celui-ci ne peut pas, **parce que
`ChargerMesh` est le SEUL slot d'`Obstacle.tscn` à porter un transform tourné** :
`Transform3D(1,0,0, 0,0,-1, 0,1,0, 0,0.9,0)`, un quart de tour autour de X qui
existe pour que l'apex du PRISME placeholder mène. Un modèle installé est un
**enfant** du slot et en hérite : un sanglier correct dans son propre espace
serait dessiné **debout sur son museau**. `model_rotation_degrees = (-90, 0, 0)`
l'annule exactement.

Le transform du slot n'est **pas** touché : corriger le slot plutôt que le
modèle casse le placeholder, et le casse dans l'état que personne ne regarde
(l'argument que `ModelSlot.gd` porte déjà pour `model_offset`).

⚠️ **Corollaire pour tout futur slot tourné** : `model_offset` est en unités
SLOT-locales, donc ses axes sont tournés eux aussi — local +Y = monde +Z, local
+Z = monde −Y. Le `Vector3(-0.01547, 0.53393, -0.12699)` livré se lit « 1,5 cm à
gauche, 53 cm vers l'avant, 12,7 cm vers le bas » **seulement après** ce mapping.

### LOD 560, et le critère n'est ni les triangles ni l'œil

La lecture d'un sanglier tient à une **tête basse et pointée distincte de la
masse des épaules**, et la décimation mange les extrémités qui la portent.
Demi-largeur maximale par bande de Z contre la source : le **museau** garde
**74 % à LOD 150**, 83 % à 300, **95 % à 380** ; la **crinière** — ce qui casse
le HAUT du contour vu de face — ne revient qu'à **560**. 560 est le plus petit
LOD dont **toute la moitié avant** égale celle du LOD 800 (**98,3 %, identique
jusqu'à 800**) : c'est la règle du lot JUMP (« indiscernable de 800 ») appliquée
honnêtement à un sujet où elle tombe ailleurs. **47 % du cap §7.1 de 1 200.**

⚠️ **À retenir, parce que ça change ce qu'un LOD achète ici : vu DE FACE, à tous
les LOD testés, la silhouette plate du sanglier est une MASSE, pas un coin
pointu.** Le museau est écrasé sur le corps par l'axe même qui en fait un
charger. Ce que les triangles achètent, ce sont les ruptures de contour
(crinière, pattes, défenses) — d'où le fait que c'est la CRINIÈRE, pas le
museau, qui a fixé le nombre.

### Échelle : la présence latérale du placeholder, tenue exactement

`model_scale = 1,82584` cale X sur **1,5000**, la largeur du placeholder — **pas**
sur le collider (1,2). C'est le visuel généreux que `Hitboxes.gd` défend
lui-même comme « la preuve la plus claire du projet qu'une silhouette et une
hitbox ont le droit de différer ». Caler ici rend la présence latérale
**identique au bit près à ce qui est livré aujourd'hui** : ce lot change la
FORME, pas l'EMPREINTE, et ne peut donc déplacer aucun jugement d'esquive de voie.

`model_offset` **recentre aussi le mesh en X** : il arrive **15,5 mm
décentré** — neuf fois les 1,7 mm que le lot libellule avait à juste titre
écartés comme du bruit de mesure — et sur un hazard fatal esquivé
latéralement, un visuel décentré est une **asymétrie gauche/droite**, pas un
détail cosmétique.

Extents mondiaux sur la scène construite : **X 1,5000, Y 0,0000–2,0787,
Z −1,2000–2,2870.**

⚠️ **`AssetContractAudit` imprime `1.500 x 3.487 x 2.079` pour cette ligne, et
ce n'est PAS une contradiction** : il rapporte l'AABB en espace SLOT, qui sur ce
seul slot est tourné. Son Y est le Z monde. Aucun sanglier de 3,5 m de haut
n'existe.

**Résidus signalés, pas maquillés** : le corps fait **3,487 m de profondeur**
contre une hitbox de 1,0, donc le museau arrive **1,787 m devant la face létale**
— sens INDULGENT (la hitbox arrive après le museau), et l'enveloppe visuelle du
charger couvrait déjà 5,3 m de piste à cause de ses barres. **2,0787 m de haut
contre une hitbox de 2,0** (+0,079) : sans effet sur un hazard injumpable, même
argument que les 0,253 du DODGE. Il dépasse le pic de saut de **0,521 m** contre
0,242 pour le placeholder.

### ⚠️ LES BARRES DE TRAIL ÉTAIENT VISIBLES À 0 % AVANT CET INSTALL

Le tiers MOTION du télégraphe — trois barres que `Obstacle.gd` qualifie
d'« unambiguous even in peripheral vision » — est **entièrement occulté par le
prisme placeholder depuis la caméra de jeu**, et c'est cet install qui l'a
révélé. Mesuré en rastérisant le charger assemblé depuis la caméra que
`CameraFollow` produit RÉELLEMENT (elle lerp vers `target + (0,4.2,7)` puis
`look_at` `target + (0,1,-4)` chaque frame, donc le −20° écrit dans `Game.tscn`
est écrasé et le vrai pitch est **−16,2°**) :

| z obstacle | placeholder (même voie) | sanglier | placeholder (voie adjacente) | sanglier |
|---|---|---|---|---|
| −16 | **0 %** | 16 % | **0 %** | 26 % |
| −8 | **0 %** | 34 % | **0 %** | 49 % |
| −3 | **0 %** | 67 % | 2 % | 72 % |

Le prisme fait 1,8 m de haut et pleine largeur à sa face arrière ; les barres
sont à y = 1,1 à seulement 0,4 m derrière, donc depuis une caméra à 4,2 m tout
rayon vers une barre est bloqué. La croupe plus basse et plus étroite du
sanglier les laisse passer pour la première fois. ⚠️ **NON confirmé sur device**
— c'est un rendu composite dont la géométrie coïncide avec les chiffres de
`ChargerShapeProbe` sur la scène construite, pas une capture du jeu.

La queue est posée sur **z = −1,200**, le plan arrière du placeholder, donc le
jeu de 0,100 m avec la barre la plus proche est préservé **exactement**.

### Couleur : report VERBATIM, et c'est tout l'argument

`StandardMaterial3D_Charger` porte déjà `shading_mode = 0` et **aucune
émission**, exactement comme JUMP et STOMPER. DODGE, ENEMY et AIR_ENEMY ont dû
être re-résolus parce que passer unlit supprimait une multiplication (et pour
deux d'entre eux un terme additif) — **rien de tout ça ne s'applique ici**. Re-
résoudre une couleur déjà juste déplacerait un nombre gaté sur le seul hazard
où se tromper termine la run, en échange de rien.

**Diff `DarkPaletteAudit` contre `origin/main` : EXACTEMENT trois lignes, toutes
CHARGER, et la marge MONTE.**

| | baseline | ce lot |
|---|---|---|
| CHARGER shallow | **3,20:1** | **3,21:1** |
| CHARGER deep | **3,21:1** | **3,21:1** |

**Marge au-dessus du plancher 3,0 : +0,20 → +0,21. Rien n'a été dépensé.**
DODGE 3,39/3,37, JUMP 3,04/3,02, ENEMY 1,20/1,20, AIR_ENEMY 1,32/1,32,
STOMPER 3,41/3,41 **byte-identiques**. 0 échantillon manqué.

**Vérifié PAR HISTOGRAMME, pas supposé** — ce chantier a produit à la fois un
artefact de fenêtre (JUMP 3,28 → 3,02) et un vrai changement de couleur (DODGE),
indiscernables du seul ratio. Sonde instrumentée sur les DEUX arbres puis
revertée : **196 px sur 196 d'OBJET des deux côtés, zéro sol, zéro ciel** — donc
aucune des deux mesures n'est contaminée. L'écart est **un cran 8 bits** (bleu
221→222 en shallow ; rouge 250→251 sur 25 px en deep), sur une surface courbe
unlit à profondeur légèrement différente sous le fog exponentiel : la signature
du lot STOMPER, pas un changement de couleur. L'albédo est prouvé inchangé
indépendamment — `AssetContractAudit` imprime `unshaded rgb(1.00, 0.72, 0.88)`
des DEUX côtés.

### `ChargerShapeProbe` réécrite — AVANT l'install, pas après

Elle lisait `mesh_instance.mesh` et assertait qu'un `PrismMesh` se rétrécit vers
+Z : un contrat sur une PRIMITIVE, pas sur le CHARGER, écrit pour échouer
bruyamment au premier `.glb`. Réécrite d'abord, donc l'échec attendu n'a jamais
eu à être chassé. Elle asserte désormais le même contrat sur **ce que le slot
dessine**, en deux phases (placeholder / tel que livré) : le devant plus étroit
que l'arrière — **asserté contre la QUEUE et non contre une constante**, parce
qu'un modèle monté à l'envers est le défaut qu'elle garde ; un vrai
rétrécissement (plafond 85 %) ; posé au sol ; au-dessus du pic de saut ; et
**les barres derrière lui ET non avalées par lui** (nouveau, parce que le
placeholder était un mètre moins profond que n'importe quel corps importé).

⚠️ **Propriété de `ModelSlot` trouvée EN ÉCHOUANT, à connaître avant de copier
l'astuce d'`AlarmRampAudit`** : effacer `model_scene` sur un slot vivant **ne
restaure PAS le placeholder**. `_install_model()` met `mesh = null` à l'install
et la branche sans modèle ne le remet jamais — le slot ne dessine alors **plus
aucune géométrie**. `AlarmRampAudit` n'est pas touchée parce que les overrides
de matériau survivent à ce chemin ; les vertices non. PHASE A efface donc
`model_scene` **avant** l'entrée dans l'arbre, ce qui est aussi le test le plus
honnête. Vérifiée verte sur l'arbre PRÉ-install d'abord, reproduisant les
chiffres de l'ancienne sonde exactement.

### Triangles : la seule VRAIE hausse du lot, comme §7.4 le prédisait

`ChargerMesh` **8 → 560**, soit **+552 par instance vivante** — la plus grosse
hausse unitaire du projet, sur la seule variante qui n'avait nulle part où
descendre. Famille un-de-chaque, hazards seuls : **1 602 → 2 154** (**1 646 →
2 198** avec `JumpMarkerMesh`), mesuré des DEUX côtés. Sur les six installs le
bilan reste **une BAISSE nette de 6 198** par un-de-chaque.

### Validation

`ChargerShapeProbe` (2 phases), `AssetContractAudit` (**12/12 visuels, 0/10
colliders déplacés**, `ChargerShape` toujours `Box(1.2, 2.0, 1.0)` @ +1,000),
`DarkPaletteAudit`, `AlarmRampAudit` (12/12), `ProbeTimeoutAudit` (**33 sondes**,
retour exact à la baseline après retrait de la sonde jetable de census),
`DeathModelAudit`, `PursuerFramingAudit` (37,1 % max, CAPTURE exempt) — **toutes
exit 0**. Diffs contre `origin/main` : `AssetContractAudit` **une seule ligne**,
`DarkPaletteAudit` **trois** ; `AlarmRampAudit`, `ProbeTimeoutAudit`,
`DeathModelAudit`, `PursuerFramingAudit` **byte-identiques sur les deux flux**.
**Sondes gameplay seedées byte-identiques sur les deux flux** (`ChargerAudit`,
`ShrinkAudit`, `ComboAudit`, graine 20260806, worktree séparé). Import + export
Web **exit 0**, `index.wasm` **35 376 909**. Piège payload tenu (**0** ressource
`assets_source` importée contre 407 Mo sur disque). Le `.glb` déclare
`KHR_materials_unlit` (used ET required), **0 image, 0 texture, 0 sampler**,
attribut `POSITION` seul.

**HUIT slots portent désormais un asset** : Keepy, `pursuer/Silhouette`, et les
six meshes de hazard.

**Reste ouvert — jugement device, et il pèse plus lourd ici que sur les cinq
autres** : aucune sonde ne dit qu'un sanglier se lit comme un sanglier qui
CHARGE, à vitesse réelle sur un téléphone, et c'est le seul hazard où être
illisible termine la run au lieu de coûter un demi-strike. Plus : les **1,787 m
de museau devant la face létale** (argumentés indulgents, mais seul l'œil
tranche) ; le fait que les **barres de trail deviennent visibles pour la
première fois** — ça devrait être mieux, ce n'était pas demandé, et ce n'est pas
confirmé sur device ; et le fait que **de face le sanglier est une masse, pas un
point**, donc le cue de FORME est porté par la crinière et les pattes qui
cassent le contour, pas par un rétrécissement visible.

## LE SANGLIER (CHARGER) CHANGE DE TEINTE : rose vif → rose-brun poussiéreux (12 août 2026)

Branche `claude/charger-recolor-meshy-docs-3svnzy`, partie de `main`
(`6959f53`). **Ce n'est PAS un install** : le sanglier est en place depuis le
matin même — géométrie, LOD 560, échelle 1,82584, rotation (−90, 0, 0), offset
et collider `ChargerShape` **intouchés**. Seul `baseColorFactor` bouge, plus le
placeholder qui le double. Chiffres complets : `docs/MESHY_SPEC.md` §8.4 et §11.

`rgb(1,00, 0,72, 0,88)` → **`rgb(0,96, 0,76, 0,80)`**. Teinte rendue
**325,4° → 348,2°**, luminance rendue **0,590 → 0,604**.

**Le chiffre gaté MONTE : 3,21 → 3,27 (shallow) / 3,21 → 3,28 (deep).** Diff
`DarkPaletteAudit` contre `origin/main` : **exactement trois lignes, toutes
CHARGER**, stderr **byte-identique**. Les cinq autres hazards et les deux
collectibles sont **byte-identiques**. Marge sur le plancher 3,0 : **+0,21 →
+0,27** — rien de gaté n'a été dépensé.

**Vérifié PAR HISTOGRAMME, pas par estimation** (sonde instrumentée sur les
DEUX arbres, puis revertée) : **196 px sur 196 d'OBJET des deux côtés, zéro
sol, zéro ciel**, aux deux bouts de la respiration. La signature est un vrai
changement de couleur, pas un cran 8 bits : **R −10, G +10, B −21** d'un coup.
C'est la preuve façon DODGE, pas l'artefact de fenêtre du rondin JUMP.
`AssetContractAudit` imprime `unshaded rgb(0.96, 0.76, 0.80)` sur la ligne
`[glb]` — la valeur porte bien sur le matériau qui DESSINE (la surface du mesh
importé), pas seulement sur une constante inutilisée (piège §2.1).

⚠️ **Le vrai gate de ce lot n'était PAS le sol, mais les autres objets
sombres** — CHARGER est dans la bande CLAIRE, le rat et DODGE dans la SOMBRE :
vs rat au repos **10,50/10,46 → 10,71/10,68**, vs tronc DODGE **10,88/10,82 →
11,11/11,05**. Les deux s'améliorent. **Le vrai coût est ailleurs et n'est pas
maquillé** : l'écart de TEINTE avec l'ambre JUMP — le seul autre objet clair,
donc le seul que le WCAG ne sait pas séparer — **passe de 78,4° à 55,5°**. Il
reste confortable, mais il a été divisé par ~1,4 sur ce seul changement : c'est
le nombre à surveiller si CHARGER est encore réchauffé un jour.

⚠️ **Le `.glb` est repassé PAR le pipeline, losslessness prouvée D'ABORD**
(réécriture avec l'ANCIENNE couleur → match byte-à-byte contre l'asset livré),
donc la seule différence possible est `baseColorFactor` — chunk BIN
byte-identique (9 948 o, 269 verts, 560 tri), `KHR_materials_unlit` préservé.
**Piège trouvé au passage** : le nom de nœud d'un `.glb` vient du NOM DE
FICHIER de sortie, donc la preuve ne matche que si la réécriture se fait sous
le nom du pipeline (`charger_boar_560.glb`), pas sous le nom installé — une
première tentative différait de 4 octets et avait l'air d'une régression de
géométrie.

### Trois faits mesurés sur la palette, consignés en §8.4 — coûteux à re-dériver

Chacun ferme une direction qui paraît raisonnable sur le papier :

1. **Le sol coupe la palette en DEUX BANDES.** Rendu `(0,2033, 0,4824,
   0,0941)`, luminance **0,150** : franchir 3,0:1 exige **L ≥ 0,549** ou
   **L ≤ 0,0165**. **Aucun ton MOYEN ne passe, à aucune teinte.** Côté sombre
   le plafond en V dépend fortement de la saturation — **0,136** en gris
   neutre, **0,166** à la teinte/saturation du rat (d'où le « V ≈ 0,17 » utile
   pour le registre fourrure), **0,289** au rouge saturé de DODGE.
2. **Le WCAG ne score AUCUNE séparation À L'INTÉRIEUR d'une bande** — seule la
   teinte y travaille, et aucune sonde du repo ne la mesure. CHARGER↔JUMP
   1,08:1, CHARGER↔STOMPER 1,04:1, DODGE↔rat 1,04:1. **Direction ÉCARTÉE,
   mesurée avant de l'être** (passe de recon) : un CHARGER brun-noir — ce à
   quoi ressemble un vrai sanglier — mesure **1,03–1,09:1 contre le rat** et
   **1,01–1,13:1 contre DODGE**. Il franchirait le plancher sol et serait
   indiscernable des deux autres hazards sombres, sur le seul hazard dont la
   méprise termine la run. Le hazard fatal DOIT rester dans la bande claire.
3. **L'albédo de REPOS d'ENEMY n'est jamais vu à une taille lisible.** La
   rampe a quitté la famille brune dès `alarm_t = 0,10`, soit **4,40 s avant
   contact** — **52,8 m (11 px de haut)** à `START_SPEED` 12 et **114,4 m
   (5 px)** à `MAX_SPEED` 26. Deux recolorisations correctes du rat n'ont donc
   rien changé à ce que voit le joueur, pour une raison structurelle et non
   chromatique. **Ne PAS relancer une 3ᵉ recolorisation de repos en croyant
   corriger un « rat rouge »** : le rouge, c'est le télégraphe qui fonctionne.

**Dérive de doc corrigée au passage** : `Obstacle.gd` décrivait encore le repos
d'ENEMY comme « Obstacle.tscn's default purple » — faux depuis la
recolorisation brun-gris, et de toute façon la fonction lit la base sur le
matériau (`_enemy_base_albedo`), jamais une couleur littérale. Commentaire
seul, aucun changement de comportement.

**Reste ouvert** : est-ce qu'un rose-brun poussiéreux se lit mieux qu'un rose
vif à vitesse réelle sur un téléphone — aucune sonde ne répond, c'est tout
l'objet du lot ; les 56° de teinte avec JUMP ; et tout ce que l'install
laissait ouvert (museau de 1,787 m, barres de trail, masse de face) est
**inchangé**, ce lot n'a bougé qu'une couleur.

## LE RAT (ENEMY) CHANGE DE BANDE : brun-gris → rose pâle désaturé (12 août 2026)

Branche `claude/recolor-enemy-rat-rwmcft`, partie de `staging` (`4383601`).
**Ce n'est PAS un install**, et c'est la **TROISIÈME** recolorisation de repos du
rat : géométrie, LOD 148 tri, échelle 0,46266, offset et collider `EnemyShape`
**intouchés**. Seul `baseColorFactor` bouge, plus le placeholder qui le double.
Chiffres complets : `docs/MESHY_SPEC.md` **§8.5** (nouvelle) et §8.4.

`rgb(0,135, 0,102, 0,076)` → **`rgb(0,9608, 0,8980, 0,9137)`** — candidat **03**
de `docs/color-sheets/charger_colour_sheet.png`, choisi par Mathieu.

⚠️ **Valeur extraite DEUX FOIS, pas lue une fois** : l'annotation imprimée dit
`raw rgb(245, 229, 233)` et un histogramme de pixels de la vignette 03 rend
`(245, 229, 233)` à **97,7 % de dominance**. Contrôle croisé de la méthode : la
vignette 01 rend `(245, 194, 204)`, soit exactement le `(0,96, 0,76, 0,80)` du
CHARGER livré. sRGB 8-bit / 255 à 4 décimales round-trip vers `(245, 229, 233)`
exactement.

### ⚠️ LE PREMIER OBJET DU PROJET À CHANGER DE BANDE — et c'est un ÉCHANGE, pas un gain

Luminance rendue **0,0110 → 0,7875**. §8.4(1) coupe la palette en deux bandes
autour du sol (0,150) ; le rat **quitte la bande SOMBRE** (où il était avec
DODGE) et **rejoint la bande CLAIRE** (JUMP, STOMPER, CHARGER), qui passe à
quatre. **La bande sombre ne contient plus que DODGE.**

| | AVANT (brun) | APRÈS (rose pâle) |
|---|---|---|
| **vs sol** | 3,27 / 3,26 | **4,20 / 4,19** *(la plus large marge du jeu)* |
| vs DODGE | **1,04:1**, 27,2° | **14,24:1**, 20,1° ✅ |
| **vs CHARGER** | 10,79:1, 46,1° | **1,27:1, 1,2°** 🔴 |
| vs JUMP | 10,73:1, 6,5° | 1,28:1, 53,8° |
| vs STOMPER | 11,17:1, 166,8° | 1,23:1, 145,9° |
| télégraphe repos↔alarme | **3,92:1**, 37,5° | **3,50:1**, 9,8° |

**Le plancher sol n'a jamais été le risque** (seuil d'arrêt 3,05 ; mesuré 4,19).
**Le vrai coût est le CHARGER** : 1,27:1 de luminance et **1,2° de teinte** (3,2°
en brume profonde) — les DEUX canaux que §8.4(2) identifie comme les seuls
disponibles disparaissent d'un coup. Cause structurelle, pas malchance : **la
planche est une planche CHARGER**, tous ses candidats sont le rose du sanglier
désaturé le long d'une teinte FIXE (d'où le « hue vs JUMP: 55.8 deg » identique
sur 01/02/03).

⚠️ **L'échange n'est PAS symétrique, et c'est ça qu'il faut peser** : la
collision rat↔DODGE que §8.4(2) documentait est réellement résolue (1,04 →
14,24:1), mais DODGE est un mur statique à un demi-strike, **CHARGER est le seul
hazard qui TERMINE LA RUN**. §8.4(2) avait déjà REFUSÉ cette direction pour le
sanglier (« le hazard fatal DOIT rester dans la bande claire » et non partager
bande+teinte avec le rat) — on y arrive ici par l'autre bout.
Ce qui sépare encore la paire, **mesuré** : la **saturation, 0,062 contre 0,207**
(le rat est quasi blanc cassé, le sanglier est visiblement rose) et la
**silhouette** (quadrupède de 0,6 m au ras du sol contre un sanglier de 2,08 m,
3,5 m de profondeur, trois barres derrière). Aucun des deux n'est un argument de
couleur, aucun des deux n'est mesuré par une sonde.

**Le télégraphe survit, se resserre, et S'INVERSE** : 3,92 → **3,50:1**.
L'argument de direction qui avait fixé les DEUX couleurs précédentes (reposer
SOUS les 0,187 de l'alarme pour que la rampe ÉCLAIRCISSE) est cassé par une
couleur qui repose à 0,7875 — la rampe **ASSOMBRIT** désormais, exactement la
forme qu'AIR_ENEMY a toujours eue. ⚠️ Mais l'écart de teinte s'effondre aussi
(**37,5° → 9,8°**) : le repos est maintenant dans la famille de teinte de
l'ALARME, ce que la recolorisation brune avait justement corrigé pour le violet.
Ça tient **ici** parce que la VALEUR fait le travail (un rose pâle et un rouge
sombre ne se confondent pas comme deux rouges sombres) — mais le cue est porté
par **un seul canal** là où il en avait deux.

### ⚠️ CE LOT NE CHANGE PAS CE QUE MATHIEU VOIT À DISTANCE DE DÉCISION

À dire avant le test device, pour que le résultat ne surprenne pas : §8.4(3)
reste **entièrement valable et n'est pas contredit**. La rampe a quitté la
famille de repos **4,40 s avant contact**, soit un rat de **11 px** à
`START_SPEED` et **5 px** à `MAX_SPEED`. Ce lot est un changement d'**identité au
repos**, PAS un correctif de « rat rouge en jeu » — le rouge est le télégraphe
qui fonctionne. Ce qu'il faut regarder sur device est donc la lisibilité **à
distance** et la **confusion avec le sanglier**, pas la couleur au moment d'agir.

**`DarkPaletteAudit` est BYTE-IDENTIQUE sur les DEUX flux** — résultat PRÉDIT
puis confirmé, et la preuve la plus forte à ce jour que sa ligne
`ENEMY (resting)` mesure l'alarme : la couleur de repos passe de quasi-noir à
quasi-blanc et la sonde ne bouge pas d'un chiffre. Les 4 hazards gatés sont
inchangés (DODGE 3,39/3,37, JUMP 3,04/3,02, CHARGER 3,27/3,28, STOMPER
3,41/3,41), 0 échantillon manqué.

**Losslessness prouvée D'ABORD** (réécriture avec l'ANCIENNE couleur →
`b647cf00c5bec773227a6aebb5b95cfc`, **byte-identique** à l'asset livré), donc la
seule différence possible est `baseColorFactor` — chunk BIN byte-identique
(2 688 o, 76 verts, 148 tri), JSON identique par ailleurs, `KHR_materials_unlit`
préservé, 0 image / 0 texture / 0 sampler. **Le piège du nom de nœud déjà
consigné au lot CHARGER s'est reproduit** : la preuve ne matche que si la
réécriture se fait sous le nom du pipeline (`enemy_rat_150.glb`) — une première
tentative différait de 4 octets sur le seul nom de nœud.

**Mesure faite avec une sonde jetable** (bâtie sur la scène/caméra/pose de
`DarkPaletteAudit`, supprimée avant merge — `ProbeTimeoutAudit` revient à **33**),
avec **boîte 5px et histogramme DOMINANT** au lieu du mean 14px : ce chantier a
produit un artefact de fenêtre (JUMP 3,28→3,02) ET un vrai changement de couleur
(DODGE), qu'un mean ne sait pas séparer. Fenêtre du rat : **100/100 px d'UNE
couleur, avant comme après, aux deux bouts**. La sonde **reproduit d'abord trois
chiffres déjà documentés** (3,27:1 vs sol, 1,04:1 @ 27,2° vs DODGE, 3,92:1 de
télégraphe) avant qu'on lui fasse confiance sur les nouveaux.

**Reste ouvert** : la collision rat↔CHARGER — mesurée, argumentée par la
saturation et la silhouette, mais **seul un œil à vitesse réelle tranche**, et
c'est la paire dont la méprise coûte le plus cher ; le fait que le repos soit
dans la famille de teinte de l'alarme ; et le télégraphe à un seul canal.

## LE RAT (ENEMY) QUITTE LA TEINTE DE CHARGER — recolorisation N°6, plus un piège payload fermé (13 août 2026)

Branche `claude/rat-recolor-payload-trap-pakaoh`, partie de `staging`
(`72729f9`). **Ce n'est PAS un install** : géométrie, LOD 148 tri, échelle
0,46266, offset et collider `EnemyShape` **intouchés**. Seul `baseColorFactor`
bouge, plus le placeholder qui le double. Deuxième changement du même lot,
indépendant : fermeture d'un piège payload trouvé en recon sur une AUTRE
branche mais jamais porté sur `staging` — voir plus bas.

`rgb(0,9608, 0,8980, 0,9137)` (rose pâle désaturé, §8.5 de MESHY_SPEC.md) →
**`rgb(0,7348, 0,88, 0,6864)`** — candidat **B1 « Kaki pâle »** de
`EnemyEarthtoneAxisSheet.gd` (`scripts/dev/`, branche
`claude/enemy-earthtone-axis-qnlzo5`, commit `07bddfe`), une recon
**indépendante** qui ne touche jamais la palette de CHARGER — contrairement
au rose, qui était le candidat 03 de la PROPRE planche du sanglier et
héritait donc sa teinte exacte (d'où sa collision 1,2° avec lui).

### La valeur installée est la valeur SAISIE (HSV), pas la valeur rendue-mesurée

La planche entre le candidat en HSV — `H=105,0 S=0,22 V=0,88`
(`Color.from_hsv(105.0/360.0, 0.22, 0.88, 1.0)` dans le script, jamais un
littéral RGB tapé à la main). C'est cette valeur SAISIE, convertie une seule
fois de façon déterministe (`colorsys`/algorithme HSV standard, round-trip
vérifié), qui a été installée. Les colonnes RENDUES de la planche (`H=105,0°
S=0,219 chroma8=48,0 Lrel=0,63671`, `3,49:1` vs sol) sont une MESURE — pixel
réel après AA/box-sampling — pas une seconde source pour la valeur à écrire
dans le `.glb`.

### Gates remesurés sur l'asset RÉELLEMENT installé

`EnemyEarthtoneAxisSheet.tscn` a été rejoué (temporairement, jamais commité,
supprimé avant tout commit) sur cet arbre APRÈS l'installation — sa ligne
« ENEMY shipped » ne lit JAMAIS un override, uniquement le matériau réel du
`.glb` livré. Elle **reproduit EXACTEMENT les chiffres de la planche de
recon** : `hue=105,0 sat=0,219 chroma8=48,0 lum=0,63671`, `worst=3,49:1`,
`dHue vs CHARGER/JUMP/STOMPER/DODGE = 117,0 / 61,4 / 97,3 / 99,2 deg` (plancher
45°), `contraste PAIRE vs CHARGER = 1,064:1`. Les quatre hazards de
référence, mesurés sur ce même arbre plutôt que lus dans la doc, retombent
aussi exactement sur les valeurs déjà connues : DODGE 3,39/3,37, JUMP
3,04/3,02, STOMPER 3,41/3,41, CHARGER 3,27/3,28.

- **vs sol : 3,49:1 (pire des deux bouts)** — largement au-dessus du seuil
  d'arrêt 3,05. Reste dans la bande CLAIRE, aucun changement de bande cette
  fois, seulement de teinte à l'intérieur.
- **vs les 4 hazards gatés : dHue >= 45° partout, minimum 61,4° (JUMP).** La
  collision qui motivait ce lot (rat↔CHARGER, 1,2° au §8.5) est fermée avec
  la PLUS GRANDE marge des quatre : 117,0°. Le contraste WCAG PAIRE contre
  CHARGER reste ~1:1 (1,064:1) — normal à l'intérieur d'une bande (§8.4(2)
  de MESHY_SPEC.md) : la séparation est portée par la teinte seule, même
  discipline que toutes les autres paires intra-bande déjà livrées.
- **Ce que le lot NE change PAS** : la rampe d'alarme quitte la famille de
  repos 4,40 s avant contact (11 px à `START_SPEED`, 5 px à `MAX_SPEED`),
  donc aucune recolorisation de repos ne change ce que voit le joueur au
  moment de décider. `DarkPaletteAudit` le confirme : sa ligne `ENEMY
  (resting)` (en réalité l'alarme saturée à `CAPTURE_Z`) est
  **BYTE-IDENTIQUE** avant/après (même md5 sur les deux flux stdout) —
  `ENEMY_ALARM_ALBEDO` n'a jamais bougé.

### Losslessness prouvée D'ABORD, comme à chaque recolorisation précédente

`decimate_hazard.py` (target=150) a d'abord régénéré le rose SHIPPÉ, match
byte-à-byte contre l'asset installé (md5 `45ec1b62b12bccfcfabf442ff552bca7`,
3700 octets, 76 verts / 148 tri) — donc la seule différence possible dans le
nouveau fichier est `baseColorFactor`. Vérifié après : chunk BIN
byte-identique (2688 octets, 76 verts, 148 tri), JSON identique à
l'exception de `baseColorFactor`, `KHR_materials_unlit` préservé.

### Validation

`AssetContractAudit` (12/12 visuels, **0/10 colliders déplacés**,
`EnemyShape` toujours `Capsule(r=0,3, h=0,7)` @ +0,350) et `AlarmRampAudit`
(PHASE D : reset vers `rgb(0.73, 0.88, 0.69)`, alarme toujours `rgb(0.95,
0.08, 0.12)`) — **diff EXACTEMENT UNE LIGNE chacune** contre `origin/staging`
en worktree séparé, la ligne ENEMY. `ProbeTimeoutAudit` (33 sondes),
`DeathModelAudit`, `ChargerShapeProbe`, `DarkPaletteAudit` — **byte-identiques
sur les deux flux**. Import + export Web **exit 0**, `index.wasm`
**35 376 909** octets — identique au fingerprint déjà consigné pour tous les
lots précédents qui ne touchent pas au code moteur.

### Piège payload fermé : `docs/*` manquait à l'`exclude_filter`

Trouvé en recon sur `claude/enemy-earthtone-axis-qnlzo5` (contournement
local par `.gdignore` sous `docs/color-sheets/`, jamais porté sur
`staging`) : `export_presets.cfg` utilise `export_filter="all_resources"`,
dont l'`exclude_filter` couvrait `scripts/dev/*` et `assets_source/*` mais
pas `docs/*`. Toute image déposée sous `docs/color-sheets/` (exactement ce
qu'écrit une sonde de recon comme `EnemyEarthtoneAxisSheet.gd`) serait donc
importée comme texture et embarquée dans le build — mesuré par la session
qui a trouvé le trou à **414 862 octets** de `.ctex` pour une seule planche.

**Corrigé au niveau du preset** (`docs/*` ajouté à l'`exclude_filter`),
permanent et pas au coup par coup par `.gdignore` par branche — couvre tout
contenu futur déposé n'importe où sous `docs/`, pas seulement
`docs/color-sheets/`.

**Vérifié par un test réel, pas par la seule lecture du filtre** : un PNG de
57 546 octets déposé sous `docs/color-sheets/` reçoit bien un `.import`/
`.ctex` LOCAL au réimport (`exclude_filter` d'export ne contrôle jamais
l'import éditeur, seulement le paquet exporté), mais le log d'export ne
contient **aucune** ligne `Storing File` pour `res://docs/…`, et le `.pck`
ne grossit que de **112 octets** (une chaîne de chemin dans le uid-cache —
même artefact déjà documenté pour `assets_source/*`) contre les ~57 Ko
qu'aurait coûté le fichier réellement packé. Fichier de test retiré avant
tout commit.

### Reste ouvert

Aucune sonde ne dit qu'un kaki pâle se lit comme « un rat » plutôt que
comme une forme verte pâle à vitesse réelle sur téléphone — **jugement
device**, et c'est tout l'objet de ce lot. À dire clairement avant le
retour device, comme pour chaque recolorisation précédente : ce lot ne
change PAS ce que Mathieu perçoit à distance de décision — la rampe
d'alarme domine toujours la fenêtre de lecture réelle (4,40 s avant
contact) — c'est un changement d'IDENTITÉ AU REPOS. Les candidats B2/B3/
D1/D2/D3 de la même planche restent non installés (B1 est le seul mesuré
séparé des 4 hazards à une saturation réelle). Détail chiffré complet :
`docs/MESHY_SPEC.md` §8.6 et §11.

## DOUBLE RECOLORISATION : CHARGER marron foncé + ENEMY gris-blanc — risque CHARGER-vs-DODGE accepté explicitement (13 août 2026)

Branche `claude/keepy-charger-enemy-recolor-uaau91`, partie de `staging`
(`9524f7b`). **Décision explicite de Mathieu, prise en connaissance du
risque documenté par §8.4(2) de MESHY_SPEC.md** (« un CHARGER dans la
bande sombre serait indiscernable de DODGE ») : CHARGER quitte la bande
CLAIRE pour la première fois de son histoire, et ENEMY change de teinte
(8e recolorisation de repos) pour rester séparé de lui. Détail chiffré
complet, tableaux et discipline de mesure : `docs/MESHY_SPEC.md` §8.7.

**CHARGER** `rgb(0.96, 0.76, 0.80)` (rose poussiéreux) → **`rgb(0.1156,
0.0936, 0.1200)`** (brun-violet foncé) — candidat **D3** de
`ChargerEarthtoneAxisSheet.gd` (`scripts/dev/`, branche
`claude/charger-earthtone-axis-2vkhd5`), choisi PAR MESURE parmi 3
candidats sombres + le fallback rgb(0.13,0.093,0.070) de la session :
**D3 est le seul qui franchit le plancher de fiabilité de teinte à 45°
contre DODGE** (75,8° — D1 échoue à 7,5°, D2 à 23,1°, le fallback à
15,4°), et il a le meilleur contraste sol mesuré des quatre (3,34:1, ex
æquo avec le fallback).

**ENEMY** `rgb(0.7348, 0.88, 0.6864)` (kaki pâle) → **`rgb(0.9200,
0.9039, 0.8924)`** (blanc-gris chaud) — candidat **G1** de
`EnemyGreyAxisSheet.gd` (`scripts/dev/`, branche
`claude/enemy-grey-axis-staging-yjc8nk`), le meilleur des deux candidats
« near-white » de la planche (4,10:1 contre 3,87:1 pour G2). Ce candidat
avait été écarté à l'origine pour collision avec le CHARGER ROSE — sans
objet ici puisque CHARGER change de famille de teinte dans le même lot ;
re-mesuré contre le NOUVEAU CHARGER (sonde jetable, supprimée avant
commit), la collision est résolue à 13,7:1 au lieu d'être créée.

**GATES MESURÉS (worst des deux bouts de la respiration, sonde jetable +
`DarkPaletteAudit` officielle) :**

| paire | worst | statut |
|---|---|---|
| CHARGER vs sol (`DarkPaletteAudit`) | **3,34:1** | ✅ plancher dur 3,0 |
| ENEMY vs sol (resting, settling forcé off) | **4,103:1** | ✅ plancher dur 3,0 |
| **CHARGER vs DODGE** | **1,008:1** | ⚠️ **RISQUE ACCEPTÉ — quasi-collision WCAG confirmée, comme §8.4(2) le prédisait** |
| CHARGER vs ENEMY | 13,714:1 | collision résolue |
| CHARGER vs JUMP | 10,094:1 | — |
| CHARGER vs STOMPER | 11,414:1 | — |
| ENEMY vs JUMP | 1,358:1 | informatif, non gaté |
| ENEMY vs STOMPER | 1,202:1 | informatif, non gaté |

**Le risque CHARGER-vs-DODGE N'EST PAS caché** : c'est le pire chiffre
pairwise jamais publié sur un hazard gaté de ce projet, et il est
délibérément publié tel quel plutôt qu'enjolivé. Ce que ça n'a PAS
touché : silhouettes, LOD (CHARGER reste à 560 tri, ENEMY à 148),
colliders (`ChargerShape`/`EnemyShape` inchangés, `AssetContractAudit`
0/10 déplacés), rampe d'alarme ENEMY (`ENEMY_ALARM_ALBEDO` intouchée,
row DarkPaletteAudit "ENEMY (resting)" byte-identique — elle mesure
l'alarme, pas le repos). Séparation résiduelle entre CHARGER et DODGE :
saturation et silhouette (mur statique 2m vs sanglier 2,08m qui CHARGE,
3,5m de profondeur, barres de trail) — aucune sonde ne les mesure.

**Losslessness prouvée D'ABORD sur les DEUX assets** : `decimate_hazard.py`
a d'abord régénéré les couleurs SHIPPÉES, match byte-à-byte confirmé
(enemy_rat md5 `cea7db16...`, charger_boar md5 `c5bd4d05...`) avant tout
edit de `COLORS[]`. Chunks BIN byte-identiques après regénération avec
les nouvelles couleurs, `KHR_materials_unlit` préservé sur les deux,
aucune géométrie/échelle/rotation/offset/collider touché.

**Validation, diffée contre `origin/staging` en worktree séparé** :
`AssetContractAudit` (12/12 visuels, 0/10 colliders déplacés, diff
EXACTEMENT 2 lignes) ; `DarkPaletteAudit` (diff EXACTEMENT 3 lignes,
toutes CHARGER) ; `AlarmRampAudit` (12/12 OK, diff EXACTEMENT 2 lignes,
ENEMY reset-target) ; `DeathModelAudit` et `ChargerShapeProbe`
(byte-identiques) ; `ProbeTimeoutAudit` (33 sondes armées). Import +
export Web **exit 0**, `index.wasm` **35 376 909** octets — fingerprint
identique à tous les lots visuels précédents. Piège payload re-vérifié
sur le `.pck` exporté (4 810 880 octets) : aucun contenu `assets_source/`
réellement packé.

**Placeholders `StandardMaterial3D_Charger`/`StandardMaterial3D_Enemy`
mis à jour aussi**, même discipline que chaque lot précédent (chemin de
fallback uniquement une fois le `.glb` installé, mais laissé divergent ce
serait reconstruire le piège qu'`AlarmRampAudit` existe pour fermer).

**Reste ouvert** : jugement device sur les deux nouvelles couleurs
(un brun-violet foncé se lit-il encore comme un sanglier menaçant ; un
blanc-gris se lit-il comme un rat ou comme une forme pâle) ; et surtout
si le risque CHARGER-vs-DODGE accepté (1,008:1) produit une vraie
confusion en jeu à vitesse réelle — c'est la question que ce lot pose à
Mathieu, pas celle qu'il tranche.

## DÉCOUPLAGE DE `ENEMY_ALARM_ALBEDO` : le rat n'a PLUS de télégraphe de couleur, la libellule devient vert clair (13 août 2026)

Branche `claude/decouple-enemy-air-enemy-colors-mddn8z`, partie de `staging`
(`b549585`). **Ni un install, ni une recolorisation de repos** : c'est le
premier lot à changer ce que la rampe d'alarme d'un hazard VISE. Aucune
géométrie, LOD, échelle, offset, rotation ni collider touché ; aucun `.glb`
réécrit. Détail chiffré complet : `docs/MESHY_SPEC.md` **§8.8**.

### ⚠️ DÉCISION DE DESIGN ASSUMÉE, PAS UN DÉFAUT

**Le rat (ENEMY) n'a plus AUCUN signal de couleur pendant sa rampe
d'alarme.** Décision explicite de Mathieu, prise en connaissance du coût :
les autres cues — **timing** (rampe de fréquence d'oscillation), **position**
(verrouillage de voie à `ENEMY_REACTION_WINDOW_S`) et **silhouette** —
restent le seul télégraphe. La couleur ne fait plus partie de la liste.

`ENEMY_ALARM_ALBEDO` `(0,95, 0,08, 0,12)` était **une constante unique
servant DEUX appliers**. Leur TIMING n'a jamais été partagé (AIR_ENEMY suit
sa descente sur 3,5 s, ENEMY son approche sur 4,5 s) — seule la COULEUR
l'était, et seulement parce qu'une constante faisait deux métiers. Deux
décisions indépendantes lui sont désormais demandées, donc elle est scindée :

| constante | valeur | effet |
|---|---|---|
| `ENEMY_ALARM_ALBEDO` | `(0,9200, 0,9039, 0,8924)` | **égale au repos du rat** → le lerp d'albédo est une identité |
| `AIR_ENEMY_ALARM_ALBEDO` | `(0,62, 0,92, 0,60)` | vert clair, remplace le rouge partagé |

**Prouvé sur des PIXELS, pas sur des constantes** (sonde jetable, revertée) :
rat à l'écran, rampe épinglée à t=0 puis t=1, frames entières comparées —
**0 pixel différent sur 2 073 600, pire écart de canal 0,000000**. La valeur
n'est pas non plus un littéral recopié qui pourrait dériver : le
`baseColorFactor` du `.glb` décode **exactement** à ce triplet sRGB (delta
**0,00e+00** en précision flottante complète), et le placeholder porte la même
valeur — l'identité tient donc sur le chemin importé ET sur le fallback.

**L'arithmétique de la rampe est délibérément LAISSÉE EN MARCHE** plutôt que
court-circuitée : `alarm_t` est toujours calculé et passé à chaque frame, donc
la décision vit dans une seule constante et la re-pointer ramène le télégraphe
sans aucun flot de contrôle à restaurer. **Vérifié avant de s'y fier** : les
seuls lecteurs de `ENEMY_ALARM_ALBEDO` dans tout le repo sont cet applier et
`AlarmRampAudit` — aucun système VFX/SFX/gameplay ne consomme la couleur ni
n'attend un changement visible.

⚠️ **La paire ÉMISSION reste partagée, et c'est sûr UNIQUEMENT parce que
toutes les surfaces concernées sont unlit** — mesuré : les deux placeholders
portent `shading_mode = 0` et les deux assets livrés déclarent
`KHR_materials_unlit`. **Le piège, nommé là où on trébucherait** : réactiver
l'ombrage sur le placeholder ENEMY ressuscite la rampe d'émission rouge — sur
le chemin de fallback seulement, celui que personne ne regarde.

### AIR_ENEMY : le plancher 3,0 est tenu sur l'OBJET, pas sur la moyenne de boîte

Trois candidats balayés ; **L3 écarté pour échec au plancher (2,98:1)**. L2
retenu pour la plus large marge sol et la meilleure distance de teinte à JUMP.

⚠️ **C'est le hazard où la moyenne 14 px N'EST PAS sa couleur**, et l'écart
dépasse tous les lots précédents : la décimation a délibérément préservé le
treillis d'ailes, donc le fond passe au travers — **131/196 = 67 % de pixels
d'objet** dans la scène même de `DarkPaletteAudit`. Les deux chiffres sont
publiés, pas le plus flatteur :

| | brume claire | brume profonde |
|---|---|---|
| **couleur d'objet** (histogramme dominant) | **3,58:1** | **3,57:1** ✅ plancher 3,0 |
| moyenne de boîte 14 px (ce que la sonde imprime) | 2,13:1 | 2,12:1 |

L'ancien rouge partagé mesurait **1,24:1** par la même méthode : c'est un gros
gain de lisibilité de silhouette, pas un échange. `DarkPaletteAudit` ne GATE
pas le contraste hazard (il le rapporte, et sort en 0) — son 2,12 imprimé
n'est donc pas un rouge, c'est une statistique contaminée, et un futur lecteur
la verra. Séparation voisine : CHARGER 11,04:1, DODGE 10,88:1, JUMP dH 75,7°,
STOMPER dH 85,5°, ENEMY dH 97,0° (teinte peu fiable contre un quasi-gris — le
vrai séparateur est la **saturation, 0,34 contre 0,03**).

**ENEMY vs sol : 4,12 / 4,10:1**, exactement la valeur documentée, sur une
fenêtre **non contaminée** (196/196 px, une seule couleur distincte) —
non-régression mesurée. Ce qui bouge, c'est seulement que la ligne mesure
désormais le blanc-gris au lieu du rouge : elle a toujours échantillonné
l'alarme saturée, ce qui est précisément pourquoi la faire taire la déplace.

### `AlarmRampAudit` réécrite AVANT le déplacement de la constante

Son `_assert_ramp` s'ouvrait sur une garde qui **échouait quand base == la
couleur d'alarme** — juste pour l'ancien contrat, rouge garanti sous le
nouveau. Réécrite d'abord, comme `ChargerShapeProbe` avant le sanglier.
Trois points non cosmétiques : **ENEMY est asserté SILENCIEUX positivement**,
mais la couleur seule ne distinguerait plus un silence voulu de la rampe MORTE
que ce fichier existe pour attraper — donc le chemin silencieux asserte aussi
que **le handle de matériau est non-null** (le défaut d'origine, dans la seule
forme qui survit) et que **la constante égale toujours le repos livré** ;
**PHASE B garde le contrat VIVANT pour les deux types** (la base du stand-in
est son magenta de debug, donc la rampe ENEMY y bouge — c'est ce qui permet
encore de prouver la liaison) ; **PHASE C passe sur AIR_ENEMY** (elle isolait
sur ENEMY : dès que cette rampe est une identité, « alarmer une instance n'a
pas teinté l'autre » devient vrai gratuitement et la phase ne peut plus jamais
échouer). Preuve que les nouveaux tests tirent : le premier run de la
réécriture est parti **rouge sur exactement les deux assertions ENEMY** de la
phase dont la base n'est pas celle du rat. **16/16 OK** après scoping.

### Validation

Diffé contre `origin/staging` en worktree séparé. `DarkPaletteAudit` —
**exactement 5 lignes** : ENEMY et AIR_ENEMY aux deux bouts, plus l'agrégat
dérivé `hazard worst`. **DODGE 3,39/3,37, JUMP 3,04/3,02, CHARGER 3,37/3,34,
STOMPER 3,41/3,41, NOISETTE et GLAND byte-identiques**, 0 échantillon manqué.
`AssetContractAudit` **byte-identique** (12/12 visuels, **0/10 colliders
déplacés**). `ProbeTimeoutAudit` (**33 sondes**, retour à la baseline après
retrait de la sonde jetable), `DeathModelAudit`, `ChargerShapeProbe` — exit 0.
Import + export Web **exit 0**, `index.wasm` **35 376 909** / md5
`af4a8fc2925d992348eb30deeeb54360`, `index.js` md5
`4e08904b1b7107858246af44b602067b`. Piège payload tenu (0 ressource
`assets_source` packée).

### Reste ouvert — jugement device

Aucune sonde ne dit qu'une libellule vert clair se lit comme telle à vitesse
réelle sur un téléphone, ni que le rat reste lisible comme **menace** une fois
la couleur retirée de son télégraphe — c'est tout l'objet du lot. Les cues
restants du rat sont le mouvement et la forme, rien d'autre.

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

## CLASSEMENT PWA : RÉSOLU, validé device des deux côtés (PWA + onglet Chrome) — 16 août 2026

⚠️ **CLÔTURE.** Le fix `accept_gzip = false` documenté ci-dessous (section
« CAUSE RÉELLE TROUVÉE PAR LE DIAGNOSTIC ») est confirmé sur device : le
classement synchronise à nouveau, en PWA installée ET en onglet Chrome
normal. Le diagnostic temporaire (`diag` sur `submit_finished`/
`top_scores_fetched`, affiché sous `SyncStatusLabel`) est **retiré** —
`Leaderboard.gd` et `GameOverScreen.gd` sont revenus, octet pour octet,
à leur état d'avant l'enquête (`a5211d3`), le fix `accept_gzip` étant la
seule différence qui subsiste. `SyncStatusLabel` réaffiche son texte fixe
autorisé, « Score non synchronisé (hors ligne ?) », sans plus jamais lui
concaténer `result=<...> code=<...>`. Branche
`claude/accept-gzip-valide-device-sr1tko`, partie de `staging` (`016ada3`).
Merge `staging` → `main` autorisé par Mathieu à la suite de cette
validation — voir la section « CLASSEMENT PWA : merge en production »
plus bas pour les détails du merge et le fingerprint CI/prod.

## CLASSEMENT PWA : l'hypothèse service worker est INFIRMÉE par la source réellement déployée — diagnostic ajouté, PAS encore validé device (14-15 août 2026)

Branche `claude/pwa-leaderboard-sync-issue-rvejp5`, partie de `staging`
(`230b6e7`). Suite au lot clavier virtuel (`a5211d3`, même jour) : test
device confirme le clavier réparé, mais le classement échoue
systématiquement — « Classement indisponible » + « Score non synchronisé
(hors ligne ?) » — malgré un wifi actif, en PWA installée (icône écran
d'accueil) sur Android/staging. Facteur nouveau depuis le diagnostic clavier :
`progressive_web_app/enabled` est passé à `true` le 14 août (lot icône
d'application), donc un service worker Godot est désormais enregistré en PWA.
Hypothèse de départ à vérifier : ce SW intercepterait les `fetch()`
cross-origin vers `firestore.googleapis.com` et les dégraderait en réponses
opaques.

⚠️ **HYPOTHÈSE VÉRIFIÉE ET INFIRMÉE — pas sur le template, sur les octets
RÉELLEMENT servis par `keepy-staging.vercel.app`.** `index.service.worker.js`
a été récupéré tel que déployé (MCP Vercel `web_fetch_vercel_url` — seul
canal HTTP disponible depuis ce sandbox pour ce domaine : `curl` direct et un
Chromium Playwright local sont tous les deux bloqués en 403 par la politique
d'egress du sandbox, `keepy-staging.vercel.app` n'y étant pas autorisé).
Constaté : `ENSURE_CROSSORIGIN_ISOLATION_HEADERS = false`, exactement la
valeur posée par `export_presets.cfg`. Avec ce réglage, le handler `fetch` du
template Godot (comparé octet pour octet à la source réelle
`misc/dist/html/service-worker.js` du tag `4.3-stable`, celui utilisé par la
CI) n'appelle `event.respondWith()` QUE si `isNavigate` ou `isCachable` — et
`isCachable` ne peut STRUCTURELLEMENT jamais être vrai pour une requête
cross-origin comme celles de `Leaderboard.gd` : son premier terme (`local`,
le chemin résolu depuis le referrer) ne matche que les fichiers de
`CACHED_FILES`/`CACHABLE_FILES` (index.html/js/wasm/pck/...) ; son second
terme (`base === referrer && base.endsWith(CACHED_FILES[0])`) exige à la fois
que `base` se termine par `/` (1er conjonct) ET par la chaîne `"index.html"`
(2e conjonct, `CACHED_FILES[0]`) — CONTRADICTOIRE avec lui-même, donc jamais
vrai, quel que soit l'URL de démarrage réel (`/` ou `/index.html` via le
`start_url` du manifeste). **Conséquence : pour toute requête vers
`firestore.googleapis.com`, le SW n'appelle jamais `respondWith()` —
passthrough complet, exactement comme en l'absence de service worker.** Ce
n'est pas une lecture optimiste : c'est une propriété structurelle de la
fonction `isCachable`, vérifiée sur les octets exacts servis en prod, pas sur
une hypothèse de lecture du template.

**Côté serveur, tout répond correctement, testé EN DIRECT avec la clé et les
endpoints réels du jeu** (GET `/documents/scores`, POST `:runQuery` avec le
body exact de `fetch_top_scores()`, préflight OPTIONS + POST sur `:commit` —
aucune écriture réelle faite, seul le préflight a été exercé) : 200 partout,
CORS reflète correctement `https://keepy-staging.vercel.app`
(`access-control-allow-origin` + `access-control-allow-credentials: true`),
et les documents déjà présents dans `scores` confirment que la collection
reçoit déjà des écritures réelles. La clé API, les règles Firestore et le
CORS du projet `keepy-8df91` ne sont donc PAS la cause.

**Vercel pose `Cross-Origin-Embedder-Policy: require-corp` +
`Cross-Origin-Opener-Policy: same-origin` sur TOUTES les routes**
(`vercel.json`, indépendant du SW et de `ENSURE_CROSSORIGIN_ISOLATION_HEADERS`)
— vérifié inoffensif ici : COEP `require-corp` ne bloque que les réponses
OPAQUES (mode `no-cors`) ; une requête `fetch()` cross-origin en mode `cors`
(le défaut, celui qu'utilise forcément `HTTPRequest` pour pouvoir lire le
corps de la réponse) qui reçoit un `Access-Control-Allow-Origin` valide —
confirmé ci-dessus — n'est jamais considérée opaque et n'est donc jamais
bloquée par COEP.

**Ce que ça change pour la suite de l'enquête** : le test « PWA installée vs
onglet Chrome normal » envisagé à l'origine visait à isoler un mécanisme qui,
sur la base de cette analyse, n'a structurellement aucune prise sur ces
requêtes — le refaire tel quel n'apprendrait probablement rien de plus.
Candidats restants, NON tranchés, à privilégier au prochain test device :
(a) permission réseau Android PER-APP sur le WebAPK installé (certains OEM —
Samsung/Xiaomi notamment — restreignent par défaut les données mobile/wifi
d'une app tout juste installée, séparément de Chrome lui-même — la PWA n'a
qu'un jour d'existence au moment du test) ; (b) un service worker resté sur
un `CACHE_VERSION` antérieur au lot clavier/sync (le cycle de vie SW ne
prend le contrôle qu'après fermeture complète de tous les clients de
l'ancien SW — un simple retour au premier plan peut ne pas y suffire) ;
(c) une panne réseau/DNS ponctuelle du device au moment du test précis, sans
rapport avec la PWA. Rien ne permet de trancher entre ces trois depuis ce
sandbox (aucun accès à un device Android réel).

**Diagnostic AJOUTÉ pour trancher au prochain test, TEMPORAIRE, à retirer une
fois la cause confirmée** — `Leaderboard.gd` : les signaux
`submit_finished`/`top_scores_fetched` portent désormais un 3e paramètre
`diag` (`"result=<HTTPRequest.Result> code=<HTTP status>"`, vide en succès) ;
`GameOverScreen.gd` l'affiche en l'AJOUTANT au texte déjà autorisé de
`SyncStatusLabel` (jamais en l'écrasant — le texte de la `.tscn` reste la
source de vérité, capturé une fois dans `_sync_status_base_text`). Un
`result` non-nul avec `code=0` pointera vers (a)/(c) ci-dessus (la requête
n'a jamais atteint le serveur) ; un `result=0` avec un `code` HTTP réel
(4xx/5xx) pointera ailleurs (proxy réseau, restriction spécifique à la
requête plutôt qu'à la connectivité). Retrait prévu : arrêter d'appeler
`_update_sync_status_text()` (ou toujours poser
`sync_status_label.text = _sync_status_base_text`), sans toucher au noeud
`.tscn`.

**Build validé au même niveau que la CI, dans ce sandbox** — éditeur +
templates Godot 4.3-stable installés pour ce lot (releases GitHub
officielles, réseau disponible cette fois). Import + export Web headless
**exit 0**, `index.wasm` inchangé (aucun code moteur touché), les deux `.gd`
modifiés compilent (`Leaderboard.gdc`/`GameOverScreen.gdc` bien produits dans
le `.pck`) et le boot headless de `GameOverScreen.tscn`
(`--quit-after 2`) ne lève aucune erreur. **Aucun test sur device réel** —
ni Android, ni iPhone, accessibles depuis ce sandbox : c'est précisément ce
que ce diagnostic vise à rendre inutile au prochain passage humain.

**Rien poussé au-delà de la branche feature**
(`claude/pwa-leaderboard-sync-issue-rvejp5`), conformément à la consigne de
session : ni `staging` ni `main`. Reste ouvert : le test A/B PWA/onglet
demandé à l'origine n'a pas pu être fait (device réel requis, hors de portée
du sandbox) ; les candidats (a)/(b)/(c) ci-dessus ne sont pas départagés — le
diagnostic ajouté est fait pour ça, au prochain test device.

### ⚠️ CAUSE RÉELLE TROUVÉE PAR LE DIAGNOSTIC : `accept_gzip` — fix appliqué et VALIDÉ device (14-16 août 2026)

Branche `claude/leaderboard-gzip-fix-3s6bag`, partie de `staging` (`4296086`,
donc **posée sur le diagnostic ci-dessus**). Le diagnostic temporaire a
tranché en un test device : `result=8`
(`HTTPRequest.RESULT_BODY_DECOMPRESS_FAILED`), `code=200` — **sur les deux
surfaces testées** (PWA installée ET onglet Chrome normal), donc (a)/(b) sont
écartés d'un coup : ce n'est ni une restriction réseau per-app Android, ni un
service worker figé sur un ancien cache — les deux auraient dû produire une
signature différente entre PWA et onglet, or les deux donnent le même couple.

**Cause probable, documentée par plusieurs issues Godot spécifiques à
l'export Web (pas encore confirmée par un 3e round device — voir plus bas)** :
`HTTPRequest.accept_gzip` vaut `true` par défaut, ce qui déclenche une
tentative de décompression du corps de réponse. Sur l'export Web, fetch/XHR
livre déjà à JS des octets entièrement décodés — il n'y a jamais de payload
gzip brut à déballer — mais l'entête `Content-Encoding: gzip` de Firestore
reste visible côté Godot, d'où la tentative de décompression sur du JSON
déjà en clair, qui échoue net avec `code=200` (la réponse HTTP a bien
réussi, c'est le décodage applicatif qui la jette).

**Fix appliqué** : `_submit_request.accept_gzip = false` et
`_query_request.accept_gzip = false`, posés juste après la création des deux
`HTTPRequest` dans `Leaderboard._ready()`, avant `add_child`. Deux lignes,
aucun autre fichier touché. Le diagnostic temporaire (`diag` sur les
signaux, affichage sous `SyncStatusLabel`) **est conservé tel quel** — pas
retiré avant validation device de ce fix, conformément à la consigne de
session : s'il ne suffit pas, le prochain couple `result`/`code` doit
remonter sans qu'on ait à le réinstrumenter.

**Build/export validés dans ce sandbox, au même niveau que la CI** :
éditeur + templates Godot 4.3-stable téléchargés (releases GitHub
officielles). Import headless **exit 0**, export Web release **exit 0**
(`godot4 --headless --path . --export-release "Web" build/web/index.html`,
aucune erreur GDScript/parse), les six fichiers du build produits et
non vides (`index.wasm` 35 376 909 octets — inchangé, cohérent avec un
diff limité à 2 lignes de GDScript sans code moteur touché). **Aucun test
sur device réel** — c'est précisément ce qu'attend la consigne de session
avant tout merge vers `main`.

**Mergé sur `staging`** (commit `f475b3f`, palier 1, automatique — build et
export headless verts). **`main` INTOUCHÉ, aucune exception** : la consigne
de session est explicite — rien à merger sur `main` tant que Mathieu n'a
pas confirmé sur device (PWA installée + onglet Chrome, comme pour le
diagnostic) que le classement synchronise enfin. Si le couple `result`/
`code` change au prochain test (au lieu de disparaître), ce sera un nouveau
signal à traiter, pas une confirmation de cette hypothèse.

### VALIDÉ device, diagnostic retiré (16 août 2026)

Test device confirmé sur les deux surfaces (PWA installée + onglet Chrome
normal) : le classement se charge, une soumission de score aboutit, plus
aucune trace de « Classement indisponible » ni de `result=<...> code=<...>`
à l'écran. Le fix `accept_gzip = false` est la cause réelle, confirmée, pas
seulement probable.

Branche `claude/accept-gzip-valide-device-sr1tko`, partie de `staging`
(`016ada3`). Le diagnostic temporaire est retiré dans ce lot : le 3e
paramètre `diag` disparaît des signaux `submit_finished`/
`top_scores_fetched` de `Leaderboard.gd`, `GameOverScreen.gd` cesse
d'appeler `_update_sync_status_text()` (la fonction elle-même est retirée,
avec `_sync_status_base_text`/`_submit_diag`/`_final_fetch_diag`) et
`SyncStatusLabel` réaffiche uniquement son texte fixe autorisé sur le
`.tscn`. **Diffé contre `a5211d3`** (dernier commit avant le début de
l'enquête PWA) : les deux fichiers sont revenus octet pour octet à cet
état, à l'exception des deux lignes `accept_gzip = false` dans
`Leaderboard._ready()`, qui restent — c'est le seul changement net que
cette enquête laisse dans le code.

### CLASSEMENT PWA : merge en production (16 août 2026, autorisation explicite de Mathieu)

`staging` (`016ada3`) → `main`, commit de merge **`1407bd9`**, après
validation device des deux surfaces (PWA installée + onglet Chrome). Merge
`--no-ff` (aucun conflit) : `main` était strictement en retard sur
`staging` (`main..staging` vide dans l'autre sens, comme sur les merges de
prod précédents de ce repo), l'arbre du commit de merge est **byte-identique
à `claude/accept-gzip-valide-device-sr1tko`** (`git diff HEAD
claude/accept-gzip-valide-device-sr1tko` vide) — ce qui part en prod est
donc littéralement l'arbre validé, pas une recomposition.

**Build/export validés dans ce sandbox avant le merge, éditeur + templates
Godot 4.3-stable installés pour ce lot** (releases GitHub officielles,
réseau disponible cette fois) : import headless **exit 0**, export Web
release **exit 0**, `Leaderboard.gdc`/`GameOverScreen.gdc` compilés sans
erreur dans le `.pck`. `index.wasm` **35 376 909 octets** — identique au
fingerprint déjà consigné pour tous les lots qui ne touchent pas le code
moteur, cohérent avec un diff limité à deux fichiers GDScript + doc.

CI run **#121** (id `31927993066`) verte (3 min 49 s) — `Deploy to Vercel
[PRODUCTION -- main]` réussie, `[STAGING -- staging]` correctement
`skipped` (push sur `main`). **Fingerprint vérifié sur le site LIVE**
(`keepy-ten.vercel.app`, via `mcp__Vercel__web_fetch_vercel_url` — accès
direct bloqué par la politique d'egress du sandbox sur ce domaine, comme
documenté ailleurs dans ce fichier ; HTTP 200, `x-vercel-cache: MISS`,
`last-modified` collé à l'heure de fin de la CI) : `GODOT_CONFIG.fileSizes`
= `index.pck 5 119 296` / `index.wasm 35 376 909`. `index.wasm` **identique
au bit près** à l'export local — c'est lui la preuve d'identité, pas le
`.pck` (rappel permanent déjà consigné : sa taille n'est pas stable d'un
export à l'autre du même commit).

**Reste ouvert : aucun.** Le classement PWA est validé device sur les deux
surfaces demandées, le diagnostic est retiré, `main` sert le fix en
production. Section close.

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

⚠️ **SECOND piège du même genre, et celui-là ne concerne PAS la sonde mais la
BOUCLE QUI L'ATTEND : un `pgrep -f` peut s'attendre LUI-MÊME, indéfiniment.**
Mesuré le 19 août 2026 : **onze** boucles de poll ont survécu à leur travail de
**1 h 44**, avec **zéro** process `godot4` vivant. `pgrep -f` compare au
`/proc/*/cmdline` complet et n'exclut **que son propre PID**, jamais le shell
qui l'a lancé — donc

```
while pgrep -f "path . --import" >/dev/null; do sleep 10; done
```

matche sa PROPRE ligne `bash -c ... while pgrep -f "path . --import" ...` : la
condition ne peut jamais devenir fausse. **La panne est silencieuse et
ressemble exactement à du travail encore en cours**, c'est ce qui la rend
coûteuse — aucune sortie, aucune erreur, juste une tâche « En cours » pour
toujours.

Test de contrôle isolé, même machine, motif présent uniquement dans le script
appelé (donc hors de la ligne de commande de l'appelant) :

| boucle | résultat |
|---|---|
| `while pgrep -f "SENTINEL"` | **exit 124 (timeout)** — boucle infinie |
| `while pgrep -f "[S]ENTINEL"` | **exit 0** — détecte correctement l'absence |

⚠️ **Le crochet est nécessaire et NON suffisant, mesuré aussi** : `[S]ENTINEL`
est une regex qui matche le texte `SENTINEL`, et la ligne du poller contient
`[S]ENTINEL` **avec** les crochets, que cette regex ne matche pas — donc il
ferme le cas « je me matche moi-même ». Il ne fait **rien** contre un shell
ANCÊTRE dont la ligne de commande porte le texte nu, ce qui sous l'outil Bash
agentique est le cas COURANT (plusieurs commandes partagent un même `bash -c`).
Première tentative de correctif prise en flagrant délit là-dessus : motif
crocheté, aucun process réel, et pourtant exit 124 — parce que la ligne
précédente de la même commande contenait le motif nu.

**Parade, `scripts/dev/wait_for_probe.sh`** (nouveau, hors build : `scripts/dev/*`
est déjà dans `exclude_filter`). Deux modes, et le premier est le bon par
défaut :

```
scripts/dev/wait_for_probe.sh --pid 12345 [poll_s]       # aucun matching de texte
scripts/dev/wait_for_probe.sh '[C]hargerAudit.tscn' [s]  # crochet EXIGÉ, sinon exit 2
```

Le mode motif refuse un motif non crocheté (exit 2, avec la réécriture à faire
dans le message) **et** retire de la correspondance tous les PID ancêtres en
remontant `/proc/<pid>/stat`. Auto-testé sur 4 cas : refus du motif nu ;
sortie immédiate malgré un ancêtre contaminé ; attente réelle de 6 s d'un vrai
process ; mode `--pid` sur 5 s. **Ne plus écrire de `while pgrep` inline.**

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

**Règle d'usage — DEUX PALIERS, et un seul des deux est gaté** :

- **Palier 1 — feature branch → `staging` : AUTOMATIQUE PAR DÉFAUT, aucune
  autorisation à demander.** Dès qu'un lot est techniquement valide (build
  et export headless verts, sondes gatées vertes), la session merge sur
  `staging` et pousse, **sans attendre ni solliciter la permission de
  Mathieu**. `staging` est un bac à sable : son unique fonction est de
  rendre un lot jouable sur `keepy-staging.vercel.app`, une erreur y est
  peu coûteuse et se corrige par un commit de plus.
  **Le seul gate de ce palier est TECHNIQUE, jamais humain** — un lot dont
  le build casse ou dont une sonde gatée rougit ne part pas sur `staging`,
  et c'est le seul motif recevable pour ne pas merger.
- **Palier 2 — `staging` → `main` : GATÉ, sans exception.** Seule une
  autorisation explicite de Mathieu, donnée **après validation device sur
  `keepy-staging.vercel.app`**, fait passer du code sur `main` — un push
  sur `main` est une mise en production immédiate. Les deux règles de
  l'incident du 29 juillet 2026 (jamais de push direct sur `main`, jamais
  de fast-forward depuis `staging`) restent intégralement en vigueur ici.

⚠️ **CLARIFICATION D'UNE AMBIGUÏTÉ RÉELLE (12 août 2026), pas un changement
de politique.** L'intention d'origine de ce paragraphe a toujours été
« staging se merge librement », mais sa formulation (« peut pousser… sans
validation préalable ») décrivait une PERMISSION plutôt qu'un DÉFAUT — et
une session récente l'a lue comme « il est autorisé de demander », donc a
attendu un feu vert explicite avant de merger un lot pourtant vert. Le
texte ci-dessus lève l'ambiguïté : sur `staging`, merger n'est pas une
option offerte à la session, c'est **l'étape terminale normale d'un lot
valide**. Demander la permission pour ce palier est un défaut de process,
au même titre que merger sur `main` sans l'avoir demandée.

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

## ⚠️ L'API GitHub Actions sert des états d'étape PÉRIMÉS — lire `completed_at`, jamais l'état brut

**Règle permanente, identifiée plusieurs fois avant d'être enfin écrite ici
(12 août 2026).** Un poll de l'API GitHub Actions peut rendre `status:
"in_progress"` sur une étape — voire sur un job entier — **plusieurs dizaines
de minutes après que le job soit réellement terminé**. Ce n'est pas un job
bloqué, c'est une lecture périmée : le champ `status` d'une réponse d'API
n'est pas une observation en temps réel.

**Le seul champ digne de foi est `completed_at`** (et son frère `conclusion`).
S'il est renseigné, l'étape EST finie, quoi que dise `status`. S'il est `null`
ET que `started_at` est vieux de plusieurs minutes, alors seulement la
question « est-ce bloqué ? » se pose.

**Pourquoi ça compte ici et pas seulement en théorie** : ce repo a une CI de
~3 minutes qui déploie en production, et un merge de prod en déclenche deux
(le merge puis le commit de doc). Conclure « le job est bloqué » sur un
`status` périmé mène à exactement les deux mauvaises réactions : relancer un
workflow qui tourne déjà (donc deux déploiements concurrents sur la même
cible), ou déclarer un lot en échec alors qu'il est vert. C'est la même
famille d'erreur que la fenêtre de 404 documentée plus haut — **ne jamais
lire un état de CI ou de déploiement sans regarder son horodatage**.

Corollaire pratique : pour attendre une CI, poller `completed_at`/`conclusion`
dans une boucle qui sort sur l'un des DEUX terminaux (`success` ET `failure`),
jamais une boucle qui n'attend que le succès — le silence d'un poll ne
distingue pas « toujours en cours » de « échoué ».

**Observation du 13 août 2026 (lot découplage ENEMY/AIR_ENEMY), reproduite en
direct : le run #105 a terminé à 14:59:10 (`conclusion: success`), et TROIS
polls successifs après cette heure ont continué de renvoyer `in_progress`,
avec une réponse byte-identique à chaque fois** — y compris l'étape « Import
project resources » figée à `in_progress` alors qu'elle s'était terminée à
14:58:38. C'est exactement le mode de panne décrit ci-dessus, observé sans
ambiguïté plutôt que déduit.

⚠️ **Ce qui a débloqué la lecture : passer `workflow_jobs_filter:
{"filter": "latest"}` à `list_workflow_jobs`.** L'appel SANS ce paramètre
servait le cache périmé ; l'appel AVEC a rendu l'état réel et complet
immédiatement. **Corrélation observée UNE fois, pas une causalité prouvée** —
le temps qui passe et l'expiration naturelle du cache sont une explication
concurrente qui n'a pas été écartée. À essayer en premier quand un poll semble
figé, avant de conclure quoi que ce soit sur l'état du job ; ça ne coûte rien
et, si ça ne suffit pas, la règle `completed_at` reste seule juge.

## ⚠️ L'API VERCEL AUSSI SERT DES RÉPONSES PÉRIMÉES SUR LE STATUT D'UN DÉPLOIEMENT — même famille que GitHub Actions ci-dessus (17 août 2026)

**Pas seulement le dashboard web : l'API Vercel elle-même.** Un poll fait
juste après qu'un run CI se soit terminé (`conclusion: success`, déploiement
déjà en place) a rendu un statut « encore en cours » pendant **~25 minutes**
de plus, alors que le déploiement était déjà terminé et servait déjà le
trafic. Même mode de panne que la section GitHub Actions juste au-dessus :
un champ de statut d'API n'est pas une observation en temps réel, c'est une
lecture potentiellement mise en cache en amont.

**Conséquence pratique, identique à la règle GitHub Actions** : **un seul
poll à `status`/état « completed » ne suffit PAS comme preuve de fraîcheur**,
et **un seul appel API ne suffit pas non plus** — l'API peut être aussi
périmée que le dashboard qu'elle est censée remplacer. Avant de conclure
qu'un déploiement est fini, en échec, ou encore en cours à partir d'un appel
Vercel, recouper avec un second signal indépendant (un nouvel appel après un
délai, ou une preuve côté site réellement servi — fingerprint
`GODOT_CONFIG.fileSizes`, `x-vercel-cache`, horodatage `last-modified` —
comme déjà pratiqué ailleurs dans ce fichier pour vérifier un fingerprint de
prod). Ne jamais traiter un unique `status=completed` (ou son équivalent
Vercel) comme une preuve suffisante à lui seul — le corollaire GitHub Actions
ci-dessus (« ne jamais lire un état de CI ou de déploiement sans regarder son
horodatage ») s'applique donc aussi aux réponses de l'API Vercel, pas
seulement à celles de GitHub Actions.

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

## GOOGLE SIGN-IN : `signInWithRedirect` → `signInWithPopup` — le redirect ne revenait JAMAIS sur Safari iOS (17 août 2026)

Branche `claude/google-signin-popup-migration-hdslwn`, partie de `staging`
(`e844824`). **Première section auth de ce fichier** : le lot qui a posé la
porte Google Sign-In (`aa66ab0`, le matin même) n'a documenté son
raisonnement que dans son message de commit — ce paragraphe régularise, il
ne remplace rien.

⚠️ **Ce n'est PAS un réglage, c'est un changement de FLOW** : le redirect
ne pouvait structurellement pas fonctionner sur ce déploiement, et aucune
valeur de paramètre ne l'aurait sauvé.

### Le défaut, confirmé sur device (screenshots à l'appui, ne pas re-questionner)

Chaîne observée sur `keepy-staging.vercel.app`, Safari iOS, wifi actif :
bouton tapé → page blanche bloquée sur `keepy-8df91.firebaseapp.com`,
chargement infini → retour sur l'app → « Connexion en cours... » → au bout
de **12 s** (`BRIDGE_TIMEOUT_S` d'`Auth.gd`) → « Le module de connexion ne
répond pas ». Le round-trip ne se termine jamais.

**Cause : storage partitioning ITP.** Le flow redirect gare son état en
attente sur l'**authDomain** (`keepy-8df91.firebaseapp.com`), qui n'est PAS
l'origine de l'app (`*.vercel.app`). Safari donne à cette origine une
partition de stockage différente quand elle est chargée en tierce partie :
l'état écrit à l'aller n'est pas celui relu au retour. Deux origines
distinctes qui ne partagent pas l'état de redirection en attente — le
`getRedirectResult()` du retour ne trouve donc rien, pour toujours.

**Pourquoi le popup n'a pas ce problème** : il n'a AUCUN état cross-origin
à faire survivre à une navigation. Le popup reposte son résultat vers
**cette** fenêtre, dans **la même** session JS, et la promesse se résout sur
place. C'est aussi pourquoi tout le mécanisme `sessionStorage` de détection
de redirect perdu (`PENDING_KEY` / `readPending()` / `writePending()`) est
**retiré et pas neutralisé** : il n'avait plus rien à détecter.

### `Cross-Origin-Opener-Policy: same-origin` → `same-origin-allow-popups`

`vercel.json`, règle site-wide `/(.*)`. **Indispensable** : sous
`same-origin`, le navigateur coupe le lien `window.opener` entre le popup et
la fenêtre principale, donc le `postMessage` par lequel le SDK Firebase
rend son résultat n'arrive jamais — le popup s'ouvrirait et ne servirait à
rien. `Cross-Origin-Embedder-Policy: require-corp` et la règle `.wasm` sont
**intouchés**.

⚠️ **La formulation courante « `same-origin-allow-popups` coexiste avec
`crossOriginIsolated` » est FAUSSE, et c'est vérifié plutôt qu'accepté :**
l'isolation cross-origin exige COOP **`same-origin`** + COEP
`require-corp`. Passer à `same-origin-allow-popups` fait donc tomber
`crossOriginIsolated` à `false`, et avec lui `SharedArrayBuffer`.

**C'est sans conséquence ICI, et c'est mesuré sur le build réel, pas
supposé** : l'export web de ce projet est un build **nothreads** —
`GODOT_THREADS_ENABLED = false` et `"ensureCrossOriginIsolationHeaders":
false` lus dans l'`index.html` généré par l'export de ce lot (cohérent avec
les templates `web_nothreads_{debug,release}.zip` déjà documentés plus
haut). Aucun `SharedArrayBuffer` n'est demandé, donc l'isolation
cross-origin ne servait rien à ce jeu. **Corollaire pour plus tard : le
jour où quelqu'un active le support threads dans le preset Web, ce COOP
devient bloquant** — les deux réglages sont incompatibles et il faudra
trancher entre threads et popup OAuth.

### Codes d'erreur : trois nouveaux, les anciens CONSERVÉS

Le contrat de robustesse existant est étendu, jamais cassé : aucun chemin ne
crashe, chaque chemin finit en signal, chaque code a un message français
associé dans `LoginScreen._message_for()`.

| code | origine | traitement écran |
|---|---|---|
| `popup-blocked` | `auth/popup-blocked` | « Ton navigateur bloque les popups… » |
| `popup-cancelled` | `auth/popup-closed-by-user`, `auth/cancelled-popup-request` | **neutre** : « Connecte-toi pour jouer. », sans détail |
| `popup-start-failed` | tout autre code | « La connexion Google a échoué. » |

⚠️ **`popup-cancelled` voyage par `auth_error` alors que ce n'est PAS une
erreur, et ce n'est pas un compromis paresseux — c'est obligatoire :**
`_on_sign_in_pressed()` **désactive** le bouton, et `auth_error` est le seul
canal qui le réactive. Publier « silencieusement » (l'autre option offerte)
laisserait un bouton mort sous un « Connexion à Google... » figé, pour un
joueur qui a simplement fermé le popup. La distinction failure/neutre est
donc portée par `LoginScreen.NEUTRAL_CODES`, qui rend le message
d'invitation **sans le détail entre parenthèses** — `auth/popup-closed-by-
user` sous une ligne disant que tout va bien se lit comme une contradiction.

⚠️ **Le `publish({error: '', detail: ''})` avant chaque tentative est
PORTEUR, pas de la coquetterie** : `Auth._apply_snapshot()` ne ré-émet
`auth_error` que si le code **change**. Sans ce reset, deux popups annulés
d'affilée produiraient deux fois le même code, le second serait avalé, et le
bouton resterait désactivé pour de bon.

**Les codes `redirect-lost` / `redirect-failed` / `redirect-start-failed`
sont GARDÉS dans le `match`** bien qu'aucun chemin du shell actuel ne puisse
plus les émettre. Un joueur dont le navigateur ou le service worker sert
encore un build en cache de l'ancienne coquille est exactement celui qui a
le plus besoin d'un message lisible ; les retirer lui servirait le fallback
générique « Connexion impossible. ». Trois lignes, contre la leçon déjà
payée au lot gzip du classement.

### Régression de flash évitée — un effet de bord du `getRedirectResult()` supprimé

`await getRedirectResult(auth)` attendait aussi, **par effet de bord**,
l'initialisation du SDK : `auth.currentUser` était donc déjà peuplé quand
`ready` basculait. Le retirer sans rien mettre à la place aurait publié
`signed_out` + `ready` à un joueur dont la session persistée était encore en
cours de restauration — donc **un flash de l'écran de login** à chaque
retour, exactement ce que les commentaires du shell interdisent. Remplacé
par une promesse résolue au **premier** `onAuthStateChanged` (que le SDK tire
toujours une fois, connecté ou non), attendue avant de basculer `ready`. Si
ce callback n'arrive jamais, rien ne rapporte et le `BRIDGE_TIMEOUT_S` de 12 s
d'`Auth.gd` le remonte — c'est précisément le rôle de ce garde-fou.

`onAuthStateChanged` **reste la source de vérité unique** pour `uid`/`idToken` :
la résolution du popup ne publie rien en cas de succès, pour ne pas créer un
second écrivain sur le même fait.

### ⚠️ RISQUE CONNU, NON CORRIGÉ ICI — Safari et l'activation utilisateur

**Ce point ne peut être tranché que par le test device qui suit.** Safari
est le navigateur le plus strict sur l'ouverture d'un popup : historiquement
il exigeait un `window.open` **dans la même pile d'appel** que le geste
utilisateur réel.

**La chaîne de ce jeu n'est PAS synchrone dans ce sens, et c'est vérifié sur
le build exporté, pas supposé** : les listeners DOM de Godot sont
`touchend`/`mouseup`, `project.godot` ne pose aucun
`input_devices/buffering/agile_event_flushing` (donc défaut = événements
bufferisés, vidés une fois par frame), et la boucle moteur tourne sous
`requestAnimationFrame`. Le signal `pressed` du bouton — donc
`Auth.sign_in()`, donc `JavaScriptBridge.eval()`, donc le `window.open` du
SDK — s'exécute dans une **tâche rAF distincte** du handler DOM d'origine.

Le popup dépend donc de la **transient user activation** (fenêtre temporelle
de ~5 s après un geste, honorée par Chrome/Firefox) et non d'une même pile
d'appel. **Ce qui est incertain est le comportement réel de Safari iOS dans
cette fenêtre** — pas la mécanique côté Godot, qui est établie ci-dessus.

**Aucun contournement n'a été tenté**, délibérément : intercaler un
`window.open('about:blank')` posé plus tôt puis re-ciblé, ou déplacer le
déclenchement dans un listener DOM en amont du moteur, sont deux
changements structurels qu'il serait absurde d'engager avant de savoir si le
défaut existe. Si Safari refuse, il le dira **proprement** : c'est
exactement le chemin `auth/popup-blocked` → `popup-blocked` → message
français explicite, et non un nouveau blocage silencieux de 12 s.

### Validation

Import headless **exit 0**, export Web release **exit 0**, boot de
`LoginScreen.tscn` (`--quit-after 3`) **exit 0** — aucune erreur de parse.
`index.wasm` **35 376 909 octets**, identique au fingerprint consigné pour
tout lot ne touchant pas le code moteur. `index.html` généré vérifié :
`signInWithPopup` présent **en code** (les seules occurrences restantes de
`signInWithRedirect` et `getRedirectResult` sont dans des commentaires),
**0** occurrence de `PENDING_KEY` / `readPending` / `writePending` /
`redirect-lost` / `redirect-start-failed`, et `viewport-fit=cover` +
`#101d0b` toujours en place (le fix safe-area du même jour n'est pas abîmé).

**Sondes : 6 rejouées, TOUTES byte-identiques sur les deux flux** contre
`origin/staging` en worktree séparé, même graine 20260806, `--fixed-fps 60` —
`ProbeTimeoutAudit` (**33 sondes armées**), `AssetContractAudit` (12/12
visuels, **0/10 colliders déplacés**), `DeathModelAudit`,
`ChargerShapeProbe`, `ComboAudit`, `ShrinkAudit`. C'est le résultat attendu
et il est **mesuré, pas argumenté** : `Auth.gd` est un autoload, donc il
tourne dans CHAQUE sonde — mais ce lot n'y change que des commentaires, et
`LoginScreen.gd` n'est chargé par aucune sonde (elles lancent leur propre
`.tscn` et ne passent jamais par `run/main_scene`). L'identité au bit près
le dit plus fort qu'un simple verdict identique.

### Reste ouvert — jugement device, seul juge

Le test sur iPhone Safari (onglet normal **et** PWA installée) doit répondre
à trois questions, dans cet ordre : (a) le popup s'ouvre-t-il **du tout**
— c'est l'incertitude d'activation utilisateur ci-dessus ; (b) si oui, la
connexion aboutit-elle et le jeu se lance-t-il ; (c) fermer le popup à la
main laisse-t-il bien un bouton réactivé et le message d'invitation, sans
message d'échec rouge. Aucune sonde de ce dépôt ne rend de pixels iOS réels
— c'est structurellement hors de portée d'un test headless Godot.

## GOOGLE SIGN-IN : LE POPUP A ÉCHOUÉ AUSSI — proxy `/__/auth/*` pour unifier l'origine, retour au redirect (17 août 2026)

Branche `claude/firebase-auth-cross-origin-fix-oiffyd`, partie de `staging`
(`ffabe64`). Le popup du lot précédent a été testé sur device et a échoué
**pour une raison différente du redirect, mais avec la MÊME cause racine**.
Ce lot ne retente pas un troisième mode d'auth : il corrige l'origine.

### Les deux échecs mesurés sur device (ne pas re-tester, ne pas re-questionner)

- **`signInWithRedirect`** (lot du matin) : page blanche bloquée sur
  `keepy-8df91.firebaseapp.com`, jamais de retour, timeout 12 s côté
  `Auth.gd`. Cause déjà documentée ci-dessus : l'état de redirection en
  attente est gardé sur l'authDomain, une origine tierce pour Safari ITP,
  qui lui donne une partition de stockage différente de celle de l'app.
- **`signInWithPopup`** (lot suivant, ce jour) : le popup s'ouvre — l'incertitude
  d'activation utilisateur documentée plus haut n'était **pas** le problème
  — la mire Google s'affiche, l'authentification se fait. Mais sur iOS le
  popup s'ouvre comme un **nouvel onglet** ; le joueur revient manuellement
  à l'app, et le `postMessage` par lequel le SDK doit livrer son résultat
  **n'atteint jamais l'opener**. Bouton grisé indéfiniment, aucune session
  écrite.

**Cause commune aux deux, et c'est ce que ce lot corrige** : `authDomain`
(`keepy-8df91.firebaseapp.com`) est une origine différente de celle de l'app
(`*.vercel.app`). Que le SDK gare son état dans une navigation cross-origin
(redirect) ou dans une fenêtre cross-origin qui doit reposter vers l'opener
(popup), Safari coupe la même relation à chaque fois. Aucun réglage de
paramètre ne l'aurait résolu sur l'un ou l'autre flow — il fallait supprimer
le cross-origin lui-même.

### 1. Proxy `/__/auth/*` — `vercel.json`

Approche vérifiée dans la documentation officielle avant implémentation
(Google Cloud Identity Platform, « Showing a custom domain during sign
in » / « How to customize auth handler » ; recoupé par l'issue
firebase-js-sdk #7824 et plusieurs implémentations de référence nginx/Vercel)
plutôt que prise sur parole : la manière documentée de servir le handler
Firebase Auth depuis l'origine de l'app est un reverse proxy transparent sur
`/__/auth/*`, `authDomain` étant ensuite pointé sur le domaine propre de
l'app. Firebase lui-même sert cette arborescence en statique sous
l'authDomain par défaut ; la proxifier ne change rien à son contenu, elle
change seulement quelle origine le NAVIGATEUR croit avoir jamais quittée.

```json
"rewrites": [
  { "source": "/__/auth/:path*", "destination": "https://keepy-8df91.firebaseapp.com/__/auth/:path*" }
]
```

**Conflit réel identifié et corrigé, pas ignoré** : la règle `headers`
site-wide (`"source": "/(.*)"`) posait déjà `Cross-Origin-Embedder-Policy:
require-corp` sur TOUTE réponse, `/__/auth/*` compris — les règles
`headers` de Vercel matchent sur le chemin de la requête ORIGINALE,
indépendamment des `rewrites`. Appliquer COEP `require-corp` à une page
`/__/auth/handler` que Firebase sert (potentiellement chargée de
sous-ressources gstatic non maîtrisées par ce dépôt) risque de la casser en
silence si l'une de ces sous-ressources n'annonce pas
`Cross-Origin-Resource-Policy`. Corrigé en excluant `/__/auth/*` de cette
règle par lookahead négatif groupé (syntaxe confirmée dans la doc Vercel
elle-même, `error-list` : un lookahead négatif nu est rejeté, il doit être
enveloppé dans un groupe) :

```json
"source": "/((?!__/auth/).*)"
```

`Cross-Origin-Opener-Policy` **revient à `same-origin`** (elle était passée
à `same-origin-allow-popups` pour le popup, désormais retiré — voir §4) :
plus aucun `window.open` n'est émis par ce dépôt, donc plus aucune raison de
sacrifier `crossOriginIsolated`. La règle `.wasm` (`Content-Type`) est
**intouchée**, et continue de s'appliquer normalement puisque aucun `.wasm`
ne vit sous `/__/auth/`.

**Conflit avec le service worker PWA : vérifié, pas de conflit.** Déjà établi
dans ce fichier (section CLASSEMENT PWA, 14-15 août) sur les octets
RÉELLEMENT servis par `keepy-staging.vercel.app` : le handler `fetch` du
service worker généré par Godot n'appelle `event.respondWith()` que pour une
navigation ou un fichier de `CACHED_FILES`/`CACHABLE_FILES` (index.html/js/
wasm/pck…) — `isCachable` ne peut structurellement jamais être vrai pour une
requête vers `/__/auth/*`, donc c'est un passthrough complet, identique à
l'absence de service worker. Ce lot ne réinstrumente pas cette vérification
(déjà faite et documentée), il en confirme la portée : `/__/auth/*` n'est
dans aucune des deux listes.

### 2. `authDomain` dynamique — `web/html_shell.html`

`resolveAuthDomain()` (nouvelle) : si `window.location.hostname` est
`keepy-ten.vercel.app` ou `keepy-staging.vercel.app` (les deux seuls
domaines où le proxy ci-dessus est réellement déployé), `authDomain` devient
**ce hostname lui-même** — le navigateur ne quitte alors plus jamais son
origine pendant la connexion, hormis la navigation top-level inévitable vers
`accounts.google.com`, qui n'est pas soumise à COEP (COEP ne gouverne que
les sous-ressources d'un document, pas une navigation top-level d'onglet/
fenêtre).

**Fallback explicite pour tout hostname inconnu** (déploiements preview
Vercel à URL aléatoire par commit) : `authDomain` reste
`keepy-8df91.firebaseapp.com`, l'ancien comportement cross-origin — **pas
pour que ça marche** (voir §3), mais pour ne jamais faire croire à un proxy
qui n'a pas été déployé pour cet hôte. Un diagnostic est publié dans
`window.keepyAuth` (`authDomainFallback: true`,
`authDomainFallbackDetail: '...'`) dès la résolution, avant tout tentative
de connexion — visible via `keepyAuthSnapshot()` sans attendre un échec.
**Décision assumée** : ce diagnostic est publié comme un champ d'état, pas
comme un `error` — publier un `error` à ce stade déclencherait
`auth_error` sur `Auth.gd` avant même que le joueur ait tapé le bouton, sur
un hostname où la connexion n'a en réalité pas encore été tentée et pourrait
en théorie réussir hors Safari. `Auth._apply_snapshot()` ignore les clés
qu'elle ne connaît pas — inerte côté GDScript, aucun changement de contrat
nécessaire côté `Auth.gd` pour ce lot.

### 3. Conséquence sur les domaines Authorized — ce qui se passe sur une preview URL

**Chaque domaine qui sert l'app doit être dans Authorized domains Firebase**
— indépendamment du proxy : c'est une vérification Firebase séparée, faite
sur l'origine de la requête, qui rejette avec `auth/unauthorized-domain`
n'importe quel domaine absent de la liste, quel que soit `authDomain`.
`keepy-ten.vercel.app` et `keepy-staging.vercel.app` y sont déjà.

**Sur une URL de preview Vercel (`keepy-git-*.vercel.app`, un hostname
aléatoire par commit) : le sign-in échouera, et c'est structurel, pas un
bug de ce lot.** Deux raisons qui s'additionnent : (a) `resolveAuthDomain()`
retombe sur l'ancien `authDomain` cross-origin, donc le défaut ITP/popup
d'origine se reproduit tel quel sur Safari ; (b) même si l'origine était
unifiée, une URL de preview ne peut de toute façon **jamais** être ajoutée
aux Authorized domains — son hostname change à chaque commit, la liste
Firebase n'accepte que des hostnames fixes. Le joueur y verra un
`popup-start-failed`/`redirect-start-failed` avec `auth/unauthorized-domain`
dans le détail (le catch existant le capture déjà, aucun code nouveau requis
pour ça). **À savoir avant de tester une preview URL et de croire à une
régression : c'est l'état attendu, pas une casse.**

### 4. Popup ou redirect une fois l'origine unifiée : REDIRECT retenu, popup retiré

**Choix tranché en faveur du redirect**, comme suggéré. Justification propre
à ce dépôt, pas seulement la recommandation générale mobile :

L'échec du popup documenté en §… ci-dessus n'était **pas** de la même nature
que celui du redirect — il ne s'agissait pas de storage partitioning à
l'aller-retour mais du comportement propre de Safari iOS qui transforme un
popup en nouvel onglet, combiné à un retour manuel du joueur qui semble
casser la référence `window.opener`/le canal `postMessage`. **Unifier
l'origine ferme le problème du redirect avec certitude** (l'état en attente
n'a plus de frontière de partition tierce à traverser), mais ne ferme le
problème du popup qu'**avec incertitude** — rien ne garantit que la
gestion d'onglet de Safari et la survie de `window.opener` à travers un
changement d'app en arrière-plan se comportent différemment une fois
popup et opener same-origin. Le redirect, lui, n'a structurellement **aucun**
onglet à gérer et **aucun** `postMessage` à perdre : c'est une navigation
de page pleine, le geste mobile le plus élémentaire et le mieux éprouvé — y
compris par Safari iOS lui-même sur d'innombrables flows « Continuer avec
Google » ailleurs sur le web.

**Restauré dans `web/html_shell.html`** (retiré au lot popup, remis à
l'identique fonctionnel, `authDomain` dynamique en plus) :
`getRedirectResult(auth)` appelé au chargement, `PENDING_KEY`
(`keepy.auth.redirect.pending`) + `readPending()`/`writePending()` en
`sessionStorage` pour détecter un redirect qui revient sans rien (partait
avec `wasPending=true`, revient sans `cred` ni `auth.currentUser` →
`redirect-lost`), `keepySignInWithGoogle()` appelle `signInWithRedirect`
au lieu de `signInWithPopup`. **Rien du flow popup ne reste en JS actif** :
`signInWithPopup` n'apparaît plus une seule fois dans le fichier, vérifié
sur le `index.html` généré par l'export.

Le remplacement de la promesse `firstState`/`resolveFirstState`
(introduite au lot popup pour flipper `ready` seulement après le premier
`onAuthStateChanged`, en remplacement de la garantie que
`getRedirectResult()` donnait déjà par effet de bord) **par le
`getRedirectResult()` original** n'est pas une régression : c'est
précisément la garantie que ce mécanisme de remplacement existait pour
recréer, désormais inutile puisque sa cause est restaurée. Garder les deux
aurait été une redondance, pas une robustesse en plus.

`scripts/autoload/Auth.gd` et `scripts/ui/LoginScreen.gd` : **aucun
changement de comportement**, seulement des commentaires mis à jour
(le bloc d'en-tête d'`Auth.gd`, la docstring de `sign_in()`, la liste des
codes possibles sur `auth_error`, le commentaire au-dessus de
`_message_for()`). **Les codes `popup-*` sont CONSERVÉS** dans
`LoginScreen._message_for()`, au même titre que `redirect-*` l'était resté
au lot popup : un navigateur ou service worker servant encore un shell en
cache du lot popup est exactement celui qui a besoin d'un message lisible.
`NEUTRAL_CODES` (`popup-cancelled`) est inchangé pour la même raison — le
redirect n'a pas d'équivalent « annulé proprement » à ajouter : un joueur
qui fait demi-tour pendant un redirect ne déclenche aucun événement côté
app tant qu'il ne revient pas dessus, exactement comme dans l'implémentation
d'origine avant le lot popup.

### 5. Cache-Control sur `index.html`

`vercel.json`, deux nouvelles règles `headers` (`"/"` et `"/index.html"`,
les deux nécessaires puisque le site est servi à la racine et qu'un lecteur
peut viser l'un ou l'autre) : `Cache-Control: no-cache, must-revalidate`.
**`.wasm`/`.pck` non touchés** — leurs noms de fichier ne changent pas d'un
build à l'autre (`index.wasm`/`index.pck`, pas de hash de contenu dans le
nom), donc les laisser cachables reste correct ; c'est `index.html` qui
référence leur taille exacte via `GODOT_CONFIG` et doit toujours être la
version fraîche. **Motif mesuré, pas préventif** : la porte d'auth
(lot du 17 août) est restée invisible **deux fois** sur `staging` tant qu'un
cache-bust manuel (`?v=2`) n'était pas forcé à la main — deux sessions de
test device faussées par un `index.html` mis en cache par le navigateur/CDN
avant même que la question de l'auth ne se pose.

### Validation

Éditeur + templates Godot 4.3-stable installés dans ce sandbox pour ce lot
(releases GitHub officielles). Import headless **exit 0**, export Web
release **exit 0** (`xvfb-run`), boot de `res://scenes/LoginScreen.tscn`
(`--quit-after 2`) **exit 0**, aucune erreur de parse sur les deux `.gd`
modifiés. `index.wasm` **35 376 909 octets**, identique au fingerprint
consigné pour tout lot ne touchant pas le code moteur — cohérent, ce lot ne
touche que des commentaires GDScript et des fichiers hors ressources Godot
(`vercel.json`, `web/html_shell.html`). `vercel.json` validé comme JSON
strict avant commit. `index.html` généré vérifié : **0** occurrence de
`signInWithPopup`, `getRedirectResult`/`resolveAuthDomain`/
`KNOWN_AUTH_HOSTS`/`signInWithRedirect` bien présents en code.

**4 sondes rejouées sur cette branche, toutes exit 0** : `ProbeTimeoutAudit`
(**33 sondes armées**, chiffre inchangé), `AssetContractAudit` (12/12
visuels, **0/10 colliders déplacés**), `DeathModelAudit` (CHARGER seul
fatal, les 5 autres types 1 demi-unité, capture au 2ᵉ contact — inchangé),
`ChargerShapeProbe`. **Structurellement, ce lot ne peut pas déplacer un flux
RNG seedé** : `Auth.gd` tourne dans chaque sonde en tant qu'autoload, mais
son `_ready()` sort avant toute ligne utile dès que `OS.has_feature("web")`
est faux (systématique sous `--headless`) — rien de ce lot n'est dans le
chemin que les sondes exécutent, et le diff des trois fichiers `.gd`/`.tscn`
touchés par ce lot au global est nul (`LoginScreen.gd`/`Auth.gd` uniquement,
tous deux hors du chemin de chargement `run/main_scene` des sondes).
`ComboAudit`/`ShrinkAudit` n'ont pas pu être rejouées jusqu'au bout dans ce
sandbox avant l'envoi de ce rapport (CPU partagée avec l'export/les autres
sondes, chacune de l'ordre de plusieurs minutes) — attendu byte-identique
par le même argument structurel, pas mesuré ici ; à vérifier si un doute
subsiste.

### Reste ouvert — jugement device, seul juge

Le test sur iPhone Safari (onglet normal **et** PWA installée si possible)
doit confirmer, dans cet ordre : (a) le tap sur « Se connecter » redirige
bien vers un `/__/auth/...` sous `keepy-staging.vercel.app` — c'est la
preuve visuelle la plus directe que le proxy est actif (l'URL affichée par
Safari ne doit **jamais** montrer `firebaseapp.com`) ; (b) le retour après
consentement Google atterrit bien sur l'app avec une session écrite, sans
passer par le timeout de 12 s ; (c) qu'un rechargement à froid de
`keepy-staging.vercel.app` (pas juste un retour d'onglet) serve bien la
version fraîche du gate — c'est ce que le fix Cache-Control du §5 doit
garantir, et c'était justement invisible sans cache-bust manuel lors des
deux tests précédents. Aucune sonde de ce dépôt ne rend de pixels iOS réels
ni ne peut suivre une redirection cross-origin réelle vers
`accounts.google.com` — c'est structurellement hors de portée d'un test
headless Godot.

## GOOGLE SIGN-IN : INSTRUMENTATION DE DIAGNOSTIC — aucun fix, objectif
## localiser le prochain `bridge-timeout` sans devtools (17 août 2026)

Branche `claude/google-signin-timeout-debug-5vg5pq`, redémarrée sur
`origin/staging` (`7582b70`) — la branche n'avait aucun commit propre,
elle pointait encore sur un vieux commit `main` antérieur au gate
Google Sign-In (aucun `Auth.gd` sur cet arbre). **Diagnostic pur, comme
demandé : aucune ligne de logique d'auth n'est changée.** Le flow
timeout (bridge-timeout à 12 s) de façon non reproductible, sur Safari
iOS et Chrome Android, sans accès devtools pour Mathieu (iPhone-only) —
objectif de ce lot : rendre chaque étape du chargement visible à l'écran,
pour que le prochain timeout dise EXACTEMENT où ça a coincé.

**Six checkpoints ajoutés dans `web/html_shell.html`**, chacun publié via
le canal existant (`publish()` → `window.keepyAuthNotify` →
`Auth._on_js_auth_event`), jamais un nouveau canal :
`sdk-import-started` → `sdk-import-done` → `app-initialized` →
`auth-obtained` → `listener-registered` → `first-auth-state-received`
(ce dernier au tout premier `onAuthStateChanged`, même `user=null` —
gardé par une fermeture `firstAuthStateSeen`, pas par un champ sur
`window.keepyAuth`, pour ne pas alourdir chaque snapshot JSON d'un
booléen qu'Auth.gd n'a pas besoin de lire). Chaque checkpoint publie
`{ stage, stageAt }` (`Date.now()`) ; `window.keepyAuth.bootAt` est posé
UNE fois, à la toute première ligne du fichier (avant même la
déclaration de l'objet), pour qu'`Auth.gd` calcule un écart en secondes
sans posséder sa propre horloge. Chaque checkpoint passe aussi par
`console.log('[keepyAuth] stage=... elapsedMs=...')`, pour le jour où
Mathieu peut brancher un Mac — mais c'est le canal secondaire : le canal
écran (ci-dessous) est celui qui compte pour son setup réel.

**`scripts/autoload/Auth.gd`** : nouveau signal diagnostic-only
`auth_debug_stage_changed(stage, elapsed_s)`, émis depuis
`_apply_snapshot()` à chaque nouveau `stage` reçu (comparaison sur
`stage` + `stageAt`, pas seulement `stage`, pour ne pas rater un second
passage sur le même checkpoint) ; deux nouveaux getters
`get_debug_stage()` / `get_debug_stage_elapsed_s()`. **Aucune branche
existante n'est touchée** — `_debug_stage`/`_debug_stage_at`/
`_debug_boot_at` sont des variables neuves, lues nulle part ailleurs
dans ce fichier, donc rien dans le comportement de `sign_in()`, du
timeout 12 s ou de `_apply_snapshot()` pour `status`/`error`/`uid` n'a
changé de chemin.

**`scenes/LoginScreen.tscn` / `scripts/ui/LoginScreen.gd`** : un nouveau
`Label` discret (`DebugStageLabel`, taille 16, `modulate` alpha 0.55)
sous `OfflineButton`, dernier enfant du même `VBoxContainer` que
`StatusLabel`/`SignInButton` — aucun nœud existant déplacé ni retouché.
Affiche `"etape: <stage> (<elapsed>s)"`, mis à jour par
`_on_auth_debug_stage_changed()` sur le nouveau signal, avec le même
patron défensif que `_refresh_from_auth()` (`_refresh_debug_stage_label()`
lit l'état déjà connu au cas où un checkpoint serait arrivé avant que
cette scène ne connecte le signal). Si le bridge se bloque à nouveau,
ce label reste figé sur le dernier stage atteint — exactement le
symptôme que Mathieu doit pouvoir lire et rapporter.

### Bug réel repéré en lisant le code, PAS corrigé — pour discussion

Consigne de session explicite : ne pas patcher à l'aveugle une deuxième
fois. `LoginScreen.gd._refresh_from_auth()` affiche
`"Connexion en cours..."` tant que `Auth.is_ready()` est faux, mais rien
n'y montre le champ `status` intermédiaire que le shell publie AVANT
`ready` (`'redirecting'` au clic sur connexion, ou le `status` restauré
au retour d'un redirect). Un joueur dont le retour de Google prend
plusieurs secondes voit un texte figé identique du premier instant au
`bridge-timeout` (ou au succès), avec le nouveau `DebugStageLabel` comme
seule source de mouvement à l'écran. Cette instrumentation le couvre déjà
partiellement (les 6 checkpoints tournent bien avant le retour de
Google), mais le `status` lui-même n'est pas un des 6 checkpoints
demandés — signalé, pas traité ici.

### Validation

Éditeur + templates Godot 4.3-stable installés dans ce sandbox pour ce
lot (releases GitHub officielles, réseau disponible). Les deux blocs
`<script>` de `web/html_shell.html` extraits et vérifiés avec
`node --check` (syntaxe seule, aucun DOM/Firebase réel en headless) :
**les deux OK**. Import headless **exit 0**, export Web release **exit
0** — `index.wasm` **35 376 909 octets**, identique au fingerprint déjà
consigné pour tout lot qui ne touche pas le code moteur (cohérent : deux
fichiers `.gd`, un `.tscn`, un `.html` d'export shell, aucun changement
à `project.godot` ni aux autoloads enregistrés). Vérifié dans
`build/web/index.html` exporté : les six identifiants de checkpoint et
`bootAt` sont bien présents dans le bundle livré, pas seulement dans la
source.

`res://scenes/LoginScreen.tscn` bootée seule en headless
(`--quit-after 2`) : **exit 0**, aucune erreur de parse ni de nœud
manquant (branche hors-web, celle que tout probe emprunte). `Auth.gd`
tourne dans chaque sonde en tant qu'autoload, mais sa `_ready()` sort
avant toute ligne utile dès que `OS.has_feature("web")` est faux
(systématique sous `--headless`) — les nouvelles variables/signal ne
sont donc jamais exercés par un probe, par construction, pas par chance.
`ProbeTimeoutAudit` (**33 sondes, toutes armées**, chiffre inchangé),
`AssetContractAudit` (**12/12 visuels, 0/10 colliders déplacés**),
`DeathModelAudit` (CHARGER seul fatal, capture au 2ᵉ contact pour les 5
autres types — inchangé) — **toutes exit 0**.

### Reste ouvert

Aucune sonde de ce dépôt ne peut déclencher un `bridge-timeout` réel ni
lire un écran iPhone — cette instrumentation attend le prochain timeout
en conditions réelles pour prouver qu'elle localise effectivement le
point de blocage. Le bug `status` intermédiaire non affiché (ci-dessus)
reste ouvert, pour discussion avec Mathieu avant tout patch. Merge sur
`staging` : palier 1, automatique (build/export/sondes verts) ; `main`
reste gaté par Mathieu, sans changement à cette règle.

## GOOGLE SIGN-IN RÉPARÉ : le proxy `/__/auth/*` était CORRECT, c'est COOP/COEP qui bloquait l'iframe d'auth (17 août 2026)

Branche `claude/firebase-auth-iframe-proxy-17h5vm`, partie de `staging`
(`6bb80a2`). **L'instrumentation du lot précédent (`4480691`) a payé dès son
premier test device** : elle a localisé le blocage à une seule transition, et
c'est cette mesure — pas une hypothèse — qui a orienté tout ce lot.

**Mesure device (iPhone Safari, Wi-Fi, staging)** : dernier checkpoint atteint
`listener-registered (0,5 s)`, checkpoint **jamais** atteint
`first-auth-state-received`, puis `bridge-timeout` à 12 s. Le SDK Firebase
charge et s'initialise en 0,5 s — **réseau, DNS, Wi-Fi et gstatic sont donc
éliminés par la mesure**, pas par argument. `onAuthStateChanged` est bien
enregistré mais son premier callback n'est jamais émis, même avec `user=null`.

### ⚠️ LE PROXY N'EST PAS CASSÉ — mesuré sur les réponses SERVIES, pas lu dans la config

L'hypothèse de départ (le proxy `/__/auth/*` ne restituerait pas ce que le SDK
attend) est **INFIRMÉE**. Les trois routes ont été récupérées telles que
`keepy-staging.vercel.app` les sert réellement (via
`mcp__Vercel__web_fetch_vercel_url` — l'egress direct de ce sandbox est bloqué
en 403 CONNECT sur `*.vercel.app`, `*.firebaseapp.com` ET `gstatic.com`, donc
aucune comparaison directe avec l'origine Firebase n'était possible) :

| route | statut | Content-Type | COOP/COEP servis |
|---|---|---|---|
| `/__/auth/iframe` | **200** | `text/html; charset=utf-8` | **aucun** |
| `/__/auth/iframe.js` | **200** (296 Ko, 94 Ko gzip) | `text/javascript; charset=utf-8` | **aucun** |
| `/__/auth/handler` | **200** | `text/html; charset=utf-8` | **aucun** |
| `/index.html` (le PARENT) | 200 | `text/html` | **COEP `require-corp` + COOP `same-origin`** |

Les corps sont ceux de Firebase (`fireauth.iframe.AuthRelay.initialize()`,
`vary: x-fh-requested-host` — la requête atteint bien Firebase Hosting), et les
chemins **relatifs** (`iframe.js`, `handler.js`) se résolvent correctement sous
`/__/auth/` à travers le rewrite. **Le lookahead négatif de `vercel.json`
fonctionne exactement comme prévu** : COOP/COEP sont bien absents des routes
d'auth — vérifié sur la réponse servie, ce que la tâche demandait explicitement.

### La cause : l'exclusion est EXACTEMENT À L'ENVERS

Sous `Cross-Origin-Embedder-Policy: require-corp`, **un document imbriqué doit
LUI-MÊME déclarer un COEP compatible ou le navigateur refuse de l'intégrer** —
et, contrairement à CORP, **être same-origin n'exempte de rien**. Retirer COEP
de `/__/auth/*` est donc précisément ce qui faisait refuser au parent
l'intégration de l'iframe que Firebase ouvre au démarrage. Firebase attend cette
iframe avant de résoudre l'état d'auth : d'où un premier `onAuthStateChanged`
jamais émis. **C'est tout le bug**, et il correspond exactement à la mesure.

**REPRODUIT EN CHROMIUM** (Playwright local — le seul navigateur atteignable
depuis ce sandbox), avec les **en-têtes exacts** mesurés ci-dessus et les
**octets exacts** du corps de `/__/auth/iframe`, sur une iframe **same-origin**
qui doit charger puis `postMessage` vers son parent — le mécanisme même de
l'AuthRelay :

| variante | relay reçu par le parent | verdict |
|---|---|---|
| **A — staging tel que déployé** (parent COEP, iframe sans COEP) | **NONE** | **BLOQUÉE** |
| B — ajouter COEP sur `/__/auth/*` | `RELAY-INITIALIZED` | passe |
| **C — CE FIX : plus de COOP/COEP du tout** | `RELAY-INITIALIZED` | passe |

⚠️ **`iframe.onload` SE DÉCLENCHE QUAND MÊME dans le cas bloqué** (mesuré) —
aucune exception, aucune erreur console, rien qui ait l'air cassé. C'est
exactement pourquoi la panne était totalement silencieuse, et pourquoi
`onload` est inutilisable comme signal de santé.

### Arbitrage explicite : (a2) supprimer COOP/COEP, PAS (a1) les ajouter à `/__/auth/*`

Les deux options débloquent l'embed (variantes B et C ci-dessus, mesurées).

**(a1) — ajouter COEP sur `/__/auth/*` : ÉCARTÉE.** Elle place l'iframe de
Firebase sous `require-corp`, or cette iframe tire **`apis.google.com`**
(mesuré : 3 références dans le `iframe.js` réellement proxifié), un script
classique cross-origin qui exigerait alors un en-tête CORP que **nous ne
contrôlons pas et que ce sandbox ne peut pas tester** (egress Google bloqué).
C'est échanger un bug mesuré contre un bug non mesurable — et un aller-retour
device de plus si Google ne l'envoie pas.

**(a2) — supprimer COOP/COEP : RETENUE.** Sans COEP sur le parent, **le contrôle
sur document imbriqué ne s'exécute plus du tout** : l'iframe d'auth s'intègre
quels que soient les en-têtes de Firebase, et les sous-ressources de Firebase ne
sont plus contraintes. On supprime la CLASSE de panne, pas une instance.

⚠️ **La prémisse qui avait introduit ces en-têtes est FAUSSE pour ce build.**
Commit `55df42c` : « SharedArrayBuffer (required by the Godot 4 web runtime)
needs cross-origin isolation ». Or l'export est la variante **nothreads** —
`index.html` **servi en production** porte `GODOT_THREADS_ENABLED = false` et
`ensureCrossOriginIsolationHeaders: false`, `export_presets.cfg` n'a aucun
`variant/thread_support`, et **le dépôt ne contient aucune occurrence de
`SharedArrayBuffer` ni de `crossOriginIsolated`**. Rien ici n'a jamais eu
besoin d'isolation cross-origin. Quatrième fois dans ce dépôt qu'une prémisse
annoncée ne survit pas à la mesure.

**Ne PAS réintroduire COOP/COEP** : ça re-casse le sign-in, silencieusement.
`vercel.json` étant du JSON strict (aucun commentaire possible), tout
l'argumentaire vit dans le commentaire de bloc de `web/html_shell.html`.

**(b) — revenir à `authDomain = keepy-8df91.firebaseapp.com` : ÉCARTÉE**, et pas
seulement par préférence : ce chemin est **déjà mesuré en échec sur Safari iOS**
(ITP, deux tests device le 17 août). Il n'aurait été acceptable qu'accompagné
d'une alternative au cross-origin — domaine custom Firebase Hosting ou
sous-domaine dédié — qui exige DNS, certificat et console Firebase, donc du
travail manuel de Mathieu hors de portée d'une session. Inutile de payer ça
quand (a2) est un fix mesuré et contenu.

### Instrumentation CONSERVÉE et ÉTENDUE (tâches 4 et 5)

Les six checkpoints existants sont **intacts** — ils viennent de prouver leur
valeur, les retirer maintenant serait absurde. S'y ajoute un **watchdog de
stall + sonde d'embed** qui nomme ce point précis à l'écran la prochaine fois :

```
first-auth-state-stalled -> auth-iframe-embed-ok
                          | auth-iframe-embed-blocked
                          | auth-iframe-probe-skipped-cross-origin
                          | auth-iframe-probe-failed
```

⚠️ **Elle ne tourne QUE si le boot a déjà stallé** (6 s), jamais sur le chemin
sain : la sonde intègre une seconde copie de l'iframe relay, ce qui coûte un
fetch de 296 Ko et une frame vivante — un diagnostic qui taxe le cas qui marche
est un diagnostic qu'on finit par retirer. Plafond 3 s, verdict à ~9 s, donc
**à l'intérieur** des 12 s de `BRIDGE_TIMEOUT_S` d'`Auth.gd` au lieu de courir
contre.

⚠️ **La méthode de détection est MESURÉE, pas supposée** : `onload` se
déclenchant dans les deux cas, la sonde lit `contentWindow.location.href` —
`SecurityError` quand COEP a bloqué, URL de la frame quand elle a chargé (le
proxy la rend same-origin). **La fonction réellement livrée a été extraite
verbatim de `html_shell.html` et exercée en Chromium** : verdict `BLOCKED` sur
la config telle que déployée, `OK` sur celle de ce fix, et **0 frame résiduelle**
dans les deux cas (elle se nettoie).

⚠️ Sur un host inconnu (previews), `authDomain` reste cross-origin, donc la
lecture ci-dessus lèverait `SecurityError` **pour une raison parfaitement
légitime**. La sonde refuse alors de répondre
(`auth-iframe-probe-skipped-cross-origin`) plutôt que de rapporter un faux
blocage — une sonde qui ment là où personne ne peut la contredire est
exactement le piège « fixture qui diverge du réel » que ce dépôt documente.

Strictement additive : elle n'appelle que `publishStage()`, donc elle ne peut
toucher ni `status`, ni `error`, ni `ready`, ni le comportement du jeu. **Aucun
changement côté Godot** — `Auth.gd` et `LoginScreen.gd` sont intouchés, les
nouveaux checkpoints passent par le canal `stage` existant.

### Validation

Import headless **exit 0**, export Web release **exit 0**. `index.wasm`
**35 376 909 octets** — identique au fingerprint consigné pour tout lot qui ne
touche pas le code moteur (cohérent : ce lot ne change que du HTML/JS de
coquille et un fichier de config de déploiement).

Sondes rejouées, **toutes exit 0** : `ProbeTimeoutAudit` (**33 sondes, toutes
armées**), `AssetContractAudit` (**12/12 visuels, 0/10 colliders déplacés**),
`DeathModelAudit`, `ChargerShapeProbe`. **Non-applicabilité vérifiée plutôt que
supposée** : aucune sonde de `scripts/dev/` ne rend de HTML ni n'évalue de JS de
coquille, et `Auth.gd` sort de sa `_ready()` avant toute ligne utile dès que
`OS.has_feature("web")` est faux — systématique sous `--headless`.

### Reste ouvert — jugement device, c'est le seul juge

Aucune sonde de ce dépôt ne rend de pixels iOS ni ne peut exécuter le vrai SDK
Firebase : la reproduction Chromium prouve le **mécanisme** et le **fix**, pas
que Safari se comporte à l'identique (Safari est plus strict, pas moins, sur
COEP comme sur ITP). Ce qui reste à confirmer sur device : que le sign-in
Google aboutit enfin sur `keepy-staging.vercel.app`, en onglet Safari **et** en
PWA installée. Si un `bridge-timeout` survient encore, l'écran doit désormais
afficher `first-auth-state-stalled` suivi d'un verdict d'embed — et un
`auth-iframe-embed-ok` serait l'information la plus intéressante possible : il
dirait que l'iframe s'intègre et que le blocage est ailleurs.

## CLASSEMENT CABLE SUR L'AUTH GOOGLE : token + uid ENVOYES, jamais EXIGES — le durcissement des rules est une action MANUELLE post-merge-main (18 aout 2026)

Branche `claude/leaderboard-google-auth-d0yxwu`, partie de `staging`
(`d01618d`, le lot qui a rendu le sign-in Google fonctionnel sur device).
**Un seul fichier de code touché** : `scripts/autoload/Leaderboard.gd`.
Aucune scene, aucun collider, aucune constante de gameplay, aucun `.glb`.

`submit_score()` et `fetch_top_scores()` attachent desormais
`Authorization: Bearer <idToken>` (via `Auth.get_id_token()`), et
`submit_score()` ecrit en plus un champ `uid` (`stringValue`,
`Auth.get_current_uid()`) dans le document Firestore.

### ⚠️ L'ORDRE EST LA CONTRAINTE, PAS LE CODE — les rules sont GLOBALES au projet

**Les Firestore rules de `keepy-8df91` sont uniques pour tout le projet :
`staging` et la prod evaluent le MEME ruleset, il n'existe aucune copie par
environnement.** C'est ce qui interdit de durcir les rules dans cette
session, et ce qui dicte la seule sequence sure :

1. ce lot part sur `staging` (fait) ;
2. validation device, puis merge sur `main` (gate Mathieu, palier 2) ;
3. **SEULEMENT ENSUITE**, durcissement manuel des rules en Console Firebase.

Durcir avant l'etape 2 casserait la PROD a l'instant du changement de
rules : la prod servirait encore un client qui n'envoie ni token ni uid, et
toute soumission de score deviendrait `PERMISSION_DENIED`. Aucune session
agentique ne peut editer les rules (pas d'acces Console) — c'est une action
**manuelle**, et elle appartient a Mathieu.

**Ce que le durcissement devra exiger, une fois `main` a jour** :
`request.auth != null` et `request.resource.data.uid == request.auth.uid`,
en gardant les deux contraintes deja deployees (`name.size() <= 12`,
`createdAt == request.time`).

### « Envoye quand disponible », jamais « requis » — mesure des 4 etats

Le code ne DEPEND jamais de l'auth : signe out, il part exactement comme
avant ce lot (meme URL, meme corps sans `uid`, memes signaux, aucun nouveau
chemin d'erreur). Deux helpers separes, et cette separation est
volontaire : **Auth publie l'uid AVANT le token** (cf. le doc de
`Auth.get_id_token()`), donc les deux questions ne peuvent pas partager une
seule reponse. Un `is_signed_in()` seul laisserait passer un bearer VIDE,
que Google rejette en 401 la ou ne rien envoyer du tout est encore accepte
par les rules d'aujourd'hui.

Mesure sur les VRAIS autoloads (sonde jetable, jamais commitee, supprimee
avant le commit — `ProbeTimeoutAudit` revient a **33 sondes**) :

| etat Auth | `_request_headers()` | `_current_uid()` |
|---|---|---|
| signe out (etat reel headless) | `Content-Type` seul | `''` → champ omis |
| signe in, token pas encore arrive | `Content-Type` seul | `UID_...` → champ ecrit |
| signe in, token present | `Content-Type` + `Authorization: Bearer ...` | `UID_...` |
| session reperdue (token laisse rassis expres) | `Content-Type` seul | `''` |

La ligne signe-out rend **exactement** la liste d'en-tetes d'avant ce lot —
c'est la non-regression du chemin non authentifie, mesuree et pas plaidee.

⚠️ **Etat transitoire a connaitre AVANT le durcissement** : ligne 2 du
tableau — uid ecrit, pas encore de bearer. Inoffensif sous les rules
actuelles ; sous les rules durcies ce serait un `PERMISSION_DENIED`. La
fenetre est etroite (Auth publie le token juste apres l'uid, et l'ecran de
game over arrive bien plus tard que le gate de login), mais elle existe :
si une soumission echoue rarement apres le durcissement, c'est le premier
suspect, pas le reseau.

### Le court-circuit headless reste PRIORITAIRE sur tout le reste — verifie

`if not network_enabled: emit(...); return` reste la **premiere**
instruction des deux points d'entree, donc une sonde ne touche jamais
`Auth`, ne construit jamais d'en-tete, ne lit jamais de token. Mesure
(meme sonde jetable) : `DisplayServer.get_name() = headless`,
`network_enabled = false`, `Auth.is_signed_in() = false`,
`submit_finished` et `top_scores_fetched` emis **exactement une fois
chacun** avec `success = false`. `Auth.gd` se garde par ailleurs
independamment sur `OS.has_feature("web")` — deux gardes distinctes, pour
deux questions distinctes (cf. son en-tete).

### ⚠️ NON VERIFIE, ET C'EST LE RISQUE PRINCIPAL DE CE LOT : les rules
### actuelles acceptent-elles un champ `uid` EN PLUS ?

Si la regle deployee contraint le jeu de champs (`hasOnly([...])`), ajouter
`uid` la ferait echouer **sous les rules ACTUELLES**, c'est-a-dire
exactement la casse que la contrainte d'ordre ci-dessus existe pour eviter.
**Ce point n'a pas pu etre mesure dans cette session** : la politique du
sandbox bloque tout appel vers l'endpoint d'ECRITURE `:commit` de Firestore
(la lecture `:runQuery` passe, elle, et a confirme la forme des documents
existants : `name`/`score`/`nuts`/`glands`/`createdAt`, **aucun `uid`** a ce
jour).

**Recette de verification ZERO-ECRITURE, a rejouer par une session qui en a
le droit** (ou par Mathieu) — elle n'ecrit jamais rien parce que la
precondition ne peut pas etre satisfaite :

envoyer un `:commit` avec `"currentDocument": {"exists": true}` sur un
doc id frais (donc inexistant), en trois variantes —
(A) corps actuel sans `uid`, (B) corps a nom de 13 caracteres (rejet
`PERMISSION_DENIED` deja documente plus haut dans ce fichier, donc temoin
qui prouve que les rules sont bien evaluees), (C) corps avec `uid`.
Lecture : **400 `FAILED_PRECONDITION` = les rules ont ACCEPTE** (et rien
n'a ete ecrit) ; **403 `PERMISSION_DENIED` = les rules ont REFUSE**. Le
temoin (B) doit sortir 403, sinon le test est non concluant et il faut une
autre approche.

**En attendant, le vrai filet est le palier `staging`** : une soumission de
score sur `keepy-staging.vercel.app` qui apparait bien dans le top 10
repond a la question en une manipulation, et c'est precisement pourquoi ce
lot ne va pas plus loin que `staging`.

### Validation

Editeur + templates Godot 4.3-stable installes dans ce sandbox (releases
GitHub officielles, memes que la CI). Import headless **exit 0**, export Web
release **exit 0**, `Leaderboard.gdc` et `Auth.gdc` tous deux compiles dans
le `.pck`. `index.wasm` **35 376 909 octets** — identique au fingerprint
deja consigne pour tout lot qui ne touche pas le code moteur ; `index.pck`
5 445 248 octets (export unique et propre, `build/` supprime avant — a lire
avec la mise en garde permanente sur l'instabilite du `.pck`). Piege payload
tenu (**0** ligne `Storing File: res://assets_source`).

**HUIT sondes rejouees, chacune diffee contre `origin/staging` en worktree
separe : les HUIT sont BYTE-IDENTIQUES sur les DEUX flux (stdout ET
stderr), exit 0 des deux cotes** — `ProbeTimeoutAudit` (33 sondes),
`AssetContractAudit` (12/12 visuels, 0/10 colliders deplaces),
`DeathModelAudit`, `ChargerShapeProbe`, `AlarmRampAudit` (12/12), plus les
trois sondes gameplay seedees `ComboAudit`, `ShrinkAudit`, `ChargerAudit`
(graine 20260806, `--fixed-fps 60`). C'est le bar attendu : le
court-circuit headless fait de ce lot un no-op complet sous sonde, et
l'identite au bit pres le dit plus fort qu'un simple verdict identique.

### Reste ouvert

1. **La question `hasOnly` ci-dessus** — le seul vrai risque, non mesure
   ici, mais tranche par une soumission de score sur staging.
2. **Le durcissement des rules lui-meme** : action MANUELLE, en Console
   Firebase, **apres** le merge sur `main`, jamais avant.
3. Jugement device sur `keepy-staging.vercel.app` : le classement se charge
   toujours, et une soumission aboutit toujours, avec un utilisateur
   Google reellement connecte.

## FIRESTORE RULES VERSIONNÉES + DÉPLOIEMENT AUTOMATIQUE — la Console n'est plus la source de vérité (18 août 2026)

Branche `claude/firestore-rules-automation-337tsq`, partie de `staging`
(`ec81387`). **Lot infra** : aucun fichier de JEU touché — ni scène, ni
`.gd`, ni `.glb`, ni `project.godot`. En particulier
`scripts/autoload/Leaderboard.gd` est **intouché**, comme demandé, et
`git diff` contre `origin/staging` ne rapporte **aucun** chemin sous
`scenes/`, `scripts/` ou `assets/`.

⚠️ **Une exception au « pur » : `export_presets.cfg` A été modifié** —
une ligne d'`exclude_filter`, pour fermer un piège payload que ce lot
introduisait lui-même (voir la section « Piège payload » plus bas). Ce
n'est pas du code moteur et ça ne change aucune scène, mais c'est un
fichier de plus que ce que le brief laissait attendre, donc dit ici
plutôt que passé sous silence.

### `firestore.rules` EST désormais la source de vérité, plus la Console

Trois fichiers nouveaux à la racine :

| fichier | contenu |
|---|---|
| `firestore.rules` | le ruleset, **reproduit à l'octet près** depuis ce qui est déployé en prod |
| `firebase.json` | `{ "firestore": { "rules": "firestore.rules" } }` |
| `.firebaserc` | `{ "projects": { "default": "keepy-8df91" } }` |

⚠️ **Avant ce lot, les rules n'existaient QUE dans la Console Firebase** —
collées à la main, sans historique, sans revue, sans diff possible. Un
`git ls-tree -r origin/main` ne trouvait aucun fichier `firebase`/
`firestore` dans le dépôt. À partir de maintenant : **le fichier gagne**.
Toute édition faite directement en Console sera **écrasée silencieusement**
au prochain push sur `main` touchant `firestore.rules`. Ne plus éditer en
Console.

**Le contenu versionné a été vérifié caractère pour caractère, pas
supposé** : le fichier a été comparé (`diff` + `cmp`) à une re-saisie
indépendante du bloc collé par Mathieu — **byte-identique**. Vérifié aussi :
pur ASCII (aucun caractère non-ASCII), **LF seul** (aucun CR/CRLF), aucun
espace ni tabulation en fin de ligne, aucune tabulation nulle part, 16
lignes, une seule newline finale. Le premier déploiement automatique
re-publie donc exactement le ruleset déjà en place — **un no-op
sémantique**.

⚠️ **Limite honnête de cette vérification, à ne pas surinterpréter** : elle
prouve que le fichier == le bloc collé, **pas** que le bloc collé == ce qui
tourne réellement sur `keepy-8df91`. La clé de compte de service vit dans le
secret GitHub, jamais dans le sandbox — aucune session agentique ne peut
lire les rules live pour les confronter. Si le bloc collé avait dérivé du
déployé, le premier run corrigerait cet écart au lieu d'être un no-op, et
c'est le log du job (qui `cat` le fichier avant de déployer) qui le dirait.

**Cohérence recoupée avec le code, pas seulement avec le brief** :
`Leaderboard.gd` déclare `PROJECT_ID := "keepy-8df91"` (donc `.firebaserc`
pointe bien le projet du jeu) et écrit exactement les champs `name`, `score`,
`nuts`, `glands`, plus `uid` quand un utilisateur est signé, plus `createdAt`
via `setToServerValue: "REQUEST_TIME"` — soit précisément les six clés du
`hasOnly([...])` du ruleset versionné. `hasOnly` autorisant un sous-ensemble,
un document sans `uid` (joueur non signé) reste accepté, comme aujourd'hui.

### Le trigger : `main` UNIQUEMENT + path filter — il PROLONGE le palier 2, il ne le contourne pas

`.github/workflows/firestore-rules.yml` (nouveau) :

```yaml
on:
  push:
    branches: [main]
    paths: ['firestore.rules']
```

**Pourquoi `main` seul, et pourquoi ce n'est pas un contournement du
gate.** Les Firestore rules sont **GLOBALES au projet `keepy-8df91`** :
`staging` et la prod évaluent le MÊME ruleset, il n'existe aucune copie par
environnement (c'est le fait autour duquel tout l'en-tête de
`Leaderboard.gd` est écrit). Un déploiement de rules n'a donc **aucun
palier 1 disponible** — déployer depuis `staging` SERAIT déployer en prod,
en ayant l'air d'une preview. Le palier 2 (autorisation explicite de
Mathieu, après validation device, avant tout merge sur `main`) est par
conséquent **le seul gate qui existe** pour les rules. Lier le trigger à
`main` met les rules DERRIÈRE ce gate au lieu de passer à côté.

**Pas de `workflow_dispatch`, délibérément** : il permettrait un run manuel
depuis n'importe quelle ref et n'importe quel état de fichier — exactement
les deux choses que le trigger existe pour empêcher. Un run échoué se
relance depuis l'UI Actions sans ça.

**Pas de `cancel-in-progress` sur la `concurrency`** (contrairement à
`web-build.yml`) : un build web annulé ne laisse qu'un artefact à jeter, un
déploiement de rules annulé a publié ou pas — un push suivant doit faire la
queue derrière, pas le tuer.

### ⚠️ C'est un FICHIER DE WORKFLOW SÉPARÉ, pas un job dans `web-build.yml` — contrainte structurelle, pas préférence

Le brief demandait un nouveau JOB dans le workflow existant, gaté par
`paths: ['firestore.rules']`. **Les deux sont incompatibles dans GitHub
Actions** : `on.push.paths` est un filtre de **WORKFLOW**, il n'a aucun
équivalent au niveau job. Poser ce filtre sur `web-build.yml` aurait gaté le
job build/export/deploy Web sur `firestore.rules` — donc plus aucun
déploiement web sauf si les rules changent — ce que le brief interdit
explicitement.

Les contournements possibles à l'intérieur de `web-build.yml` étaient tous
pires : un `if:` de job plus un `git diff` de la plage poussée (fragile sur
force-push, premier push et commits de merge, et le workflow tourne quand
même), ou une action tierce de paths-filter (une dépendance de chaîne
d'approvisionnement de plus pour ce qu'Actions fait nativement). Le job
aurait de plus hérité du `cancel-in-progress: true` de `web-build.yml`.

Le filtre est donc gardé **exactement tel que spécifié** — natif, sans
action, sans heuristique de diff — dans le seul endroit où cette syntaxe
peut vouloir dire ce qu'elle doit vouloir dire. **`web-build.yml` est
byte-intouché par ce lot** (`git diff` vide sur ce fichier).

### Authentification : le secret déjà en place, aucun nouveau secret

Secret GitHub utilisé — **nom exact : `FIREBASE_SERVICE_ACCOUNT_KEEPY`**
(JSON complet d'un compte de service capable de déployer les rules de
`keepy-8df91`). Il existait déjà, ce lot n'en crée aucun.

Chaîne : `google-github-actions/auth@v2` avec `credentials_json: ${{
secrets.FIREBASE_SERVICE_ACCOUNT_KEEPY }}` écrit la clé dans un fichier
temporaire et exporte `GOOGLE_APPLICATION_CREDENTIALS` ; `firebase-tools`
(installé par `npm install -g firebase-tools`) le lit tout seul — **ni
`firebase login`, ni `FIREBASE_TOKEN`**. Puis `firebase deploy --only
firestore:rules --project keepy-8df91 --non-interactive`.

Une étape de garde vérifie la présence du secret et échoue avec un message
actionnable, même forme que le `Check Vercel secrets` de `web-build.yml` —
plutôt qu'une erreur d'auth opaque au fond d'un CLI. Une étape `cat
firestore.rules` précède le déploiement : le log du job porte donc
littéralement le ruleset publié, à son SHA.

### Comment changer les rules à l'avenir

1. Éditer `firestore.rules` sur une branche feature.
2. Merger sur `staging` comme d'habitude (palier 1, automatique) — **le job
   ne se déclenche PAS**, le trigger est scopé `main`. C'est voulu : rien ne
   part sur le projet live tant que le gate humain n'est pas passé.
3. Autorisation explicite de Mathieu, puis merge sur `main` (palier 2).
4. Le job fait le reste. Rien à faire en Console.

⚠️ **La contrainte d'ORDRE du durcissement auth reste ENTIÈREMENT valable,
seul son MÉCANISME change.** La section « CLASSEMENT CABLE SUR L'AUTH
GOOGLE » (18 août 2026) décrit le durcissement (`request.auth != null` et
`request.resource.data.uid == request.auth.uid`) comme une action
**manuelle en Console, après le merge sur `main`** du client qui envoie
token et uid. Ce lot ne change pas d'un iota la séquence — durcir avant que
la PROD serve ce client la casserait à l'instant du changement de rules
(`PERMISSION_DENIED` sur toute soumission). Il change seulement l'outil :
le durcissement devient **une édition de `firestore.rules` + un merge sur
`main`**, et non plus un collage en Console. Le point 2 du « Reste ouvert »
de cette section-là se lit désormais ainsi.

### Piège payload : les trois fichiers racine et l'export Godot

`export_presets.cfg` utilise `export_filter="all_resources"` (piège déjà
documenté deux fois dans ce fichier), donc tout nouveau fichier racine
mérite une mesure et non une supposition. **Bien lui en a pris : le piège
s'est déclenché.**

⚠️ **`firebase.json` PARTAIT dans le build — mesuré sur un export réel,
pas prédit.** Le log `savepack` du premier export imprimait `savepack:
step 89: Storing File: res://firebase.json`, et un `grep` sur le `.pck`
retrouvait le contenu littéral du fichier. Cause : **Godot importe `.json`
comme une ressource**. L'argument rassurant qui aurait pu être tenu sans
mesurer — « `vercel.json` est à la racine depuis des mois sans
conséquence » — était en fait le contraire d'une preuve : `vercel.json`
**fuite exactement de la même façon**, ligne `Storing File` comprise, et
personne ne l'avait vu.

**Corrigé au niveau du preset** (`firebase.json` ajouté à
`exclude_filter`, à côté de `scripts/dev/*`, `assets_source/*`, `docs/*`
et `web/*`), puis **re-mesuré sur un export propre** (`build/` supprimé
d'abord — l'auto-contamination déjà documentée) : `Storing File` passe de
**130 à 129** entrées, `.pck` de **5 445 376 à 5 445 280** octets, et
`firestore.rules` / `firebase.json` / `firebaserc` retournent **0
occurrence** dans le pack. `index.wasm` reste à **35 376 909** — le
fingerprint déjà consigné pour tout lot qui ne touche pas le code moteur.

**Les deux autres fichiers sont mesurés comme NON packés**, et n'ont donc
rien reçu : `firestore.rules` (extension inconnue de Godot — l'unique
occurrence de cette chaîne dans le premier `.pck` était la *valeur JSON*
à l'intérieur de `firebase.json`, vérifiée par lecture des octets
alentour, pas le fichier) et `.firebaserc` (fichier caché). Rien n'a été
ajouté « au cas où » : seul le défaut mesuré est fermé.

⚠️ **`vercel.json` est laissé tel quel, délibérément** — il préexiste à ce
lot, il ne pèse que 368 octets, et la CI le copie depuis la racine du
dépôt (`cp vercel.json build/web/vercel.json`), jamais depuis le pack.
Le signaler ici plutôt que le corriger en douce : c'est le même défaut,
il appartient à un autre lot.

### Reste ouvert

1. **Le premier run réel**, qui n'aura lieu qu'au merge sur `main` — le
   trigger étant scopé `main`, **ce lot ne déclenche rien en partant sur
   `staging`**. C'est à ce run-là qu'on verra si le compte de service a
   bien la permission `firebaserules.releases.create` : le brief l'affirme,
   aucune session ne peut le vérifier sans la clé.
   ⚠️ **A EU LIEU le 18 août 2026 au merge `9029bfe`, et il a ÉCHOUÉ** —
   pas sur `firebaserules.releases.create` (jamais atteint) mais sur
   `serviceusage.services.get`, dans le contrôle préalable
   « l'API Firestore est-elle activée ? ». Voir la section « GATE GOOGLE
   SIGN-IN EN PRODUCTION » en fin de fichier : c'est elle qui porte l'état
   à jour, ce point-ci reste écrit tel qu'il l'était avant le run.
2. Le durcissement auth lui-même (point 2 de la section du 18 août), qui
   reste la décision et le calendrier de Mathieu — désormais faisable par
   fichier plutôt qu'en Console.

## GATE GOOGLE SIGN-IN EN PRODUCTION — et le 1er run réel de `firestore-rules.yml` ÉCHOUE sur une permission IAM (18 août 2026)

`staging` (`5065948`) → `main`, commit de merge **`9029bfe`**, `--no-ff`,
aucun conflit, après autorisation explicite de Mathieu (palier 2) et
validation device sur `keepy-staging.vercel.app`. **`main` était
strictement en retard** (`staging..main` VIDE), et l'arbre du commit de
merge est **byte-identique à `staging`** — vérifié AVANT le push, pas
supposé : `git diff HEAD origin/staging` vide et **même hash d'arbre des
deux côtés (`fbac9b1dac8e1ecb68597371a77a24445228ee78`)**. Ce qui part en
prod est donc littéralement l'arbre validé, pas une recomposition.

Règle n°1 vérifiée AU DÉBUT (et pas à la fin, cf. l'incident du 11 août) :
`git fetch --all --prune` puis tri des refs distantes par date — la ref la
plus récente du dépôt EST `origin/staging` (07:07:55 UTC), toutes les
branches auth du lot sont déjà dedans, **aucune session concurrente**.

Contenu du lot (rien de neuf écrit ici, c'est le cumul des sections
précédentes) : gate Google Sign-In devant le jeu (`LoginScreen.tscn` est
désormais `run/main_scene`, autoload `Auth`), classement câblé sur l'auth
(token + uid envoyés quand disponibles, jamais exigés), `firestore.rules`
versionné + `firestore-rules.yml`.

### ⚠️ LE 1er RUN RÉEL DE `firestore-rules.yml` A ÉCHOUÉ — les rules ne sont PAS déployées

Run **#1**, id `32114434279`, job `deploy-firestore-rules`
(`95640666817`), démarré 08:03:31, **échec 08:04:01**. Le trigger, lui,
**fonctionne exactement comme spécifié** : le push sur `main` contenant
`firestore.rules` a bien déclenché le workflow, du premier coup, sans
`workflow_dispatch`. Sept étapes sur huit passent — secret présent, auth
Google Cloud OK, `firebase-tools` installé, `cat firestore.rules` imprime
bien le ruleset à son SHA. **C'est la 8ᵉ, `Deploy Firestore rules`, qui
tombe**, en 2 secondes :

```
=== Deploying to 'keepy-8df91'...
i  deploying firestore
i  firestore: ensuring required API firestore.googleapis.com is enabled...

Error: Request to https://serviceusage.googleapis.com/v1/projects/keepy-8df91/services/firestore.googleapis.com
had HTTP Error: 403, Permission denied to get service [firestore.googleapis.com]
##[error]Process completed with exit code 1.
```

**Cause exacte, lue dans le log et pas devinée** : `firebase deploy` fait
un contrôle préalable « l'API Firestore est-elle activée ? » via
**`serviceusage.googleapis.com`**, et le compte de service du secret
`FIREBASE_SERVICE_ACCOUNT_KEEPY` n'a pas le droit
**`serviceusage.services.get`** sur `keepy-8df91`.

⚠️ **Deux conséquences à ne pas confondre, et la seconde est la plus
importante :**

1. **La permission qui manque n'est PAS celle que « Reste ouvert »
   anticipait.** Cette section attendait le verdict sur
   `firebaserules.releases.create` — **il n'a toujours pas été rendu** :
   l'échec survient AVANT le premier appel à l'API Rules. Corriger le
   droit Service Usage peut donc très bien révéler un SECOND droit
   manquant derrière. Ne pas annoncer le job « réparé » tant qu'un run
   n'est pas sorti vert.
2. **La PROD sert désormais un client qui écrit un champ `uid`, alors que
   le ruleset LIVE n'a pas bougé** — il reste celui de la Console.
   `firestore.rules` versionné ajoute `'uid'` à son `hasOnly([...])` ;
   **si les rules de la Console contraignent le jeu de clés sans `uid`,
   toute soumission de score signée part en `PERMISSION_DENIED`**. Et
   comme le gate impose désormais la connexion, **toutes** les
   soumissions portent un `uid`. C'est exactement le risque nommé au
   « ⚠️ NON VERIFIE » de la section du 18 août ; il n'est **toujours pas
   mesuré** : la recette zéro-écriture (`currentDocument: {exists:true}`)
   a été tentée dans ce sandbox et **bloquée**, cette fois par le
   classifieur d'actions, en plus de l'egress déjà documenté. Le seul
   témoin réel disponible reste une soumission de score depuis un client
   connecté — sur staging comme sur prod, les rules étant globales.

**Rien n'a été retenté à l'aveugle, rien n'a été édité pour contourner** :
ni re-run, ni modification du workflow, ni « firebase deploy --force ».
La sortie est une action IAM en Console, qui n'appartient à aucune session
agentique : accorder au compte de service le rôle
**`roles/serviceusage.serviceUsageConsumer`** (qui porte
`serviceusage.services.get`/`.use`) sur `keepy-8df91`, puis **relancer le
job échoué depuis l'UI Actions** — `workflow_dispatch` est absent par
conception, mais « Re-run failed jobs » fonctionne et rejoue le même SHA
avec le même fichier.

### Web build : vert, et la prod sert bien le build authentifié

CI run **#138** (id `32114434258`), **succès en 3 min 20 s** (08:03:33 →
08:06:53). `Deploy to Vercel [PRODUCTION -- main]` réussi,
`[STAGING -- staging]` correctement **skipped** (push sur `main`). Le log
porte lui-même `▲ Aliased https://keepy-ten.vercel.app`.

Chaîne de preuve du déploiement, lue sur l'API Vercel (indépendante du
CDN) : `dpl_AK8L574k9nUhiVqcdaprDGC4ougc`, **`source: "cli"`**,
`meta.gitRootDirectory = build/web`, `githubCommitSha =
9029bfe…`, `readyState READY`, `alias` contenant
**`keepy-ten.vercel.app`**, prêt à 08:06:49.

⚠️ **La fenêtre de 404 documentée le 12 août s'est reproduite à
l'identique, une fois de plus** : le déploiement NATIF
(`dpl_77YddKeXZbtjd2HUrhx88erjCjvT`, reconnaissable à son
`meta.branchAlias`) a pris la prod à **08:03:29**, la CI l'a remplacée à
**08:06:44** — **~3 min 15 s de 404**, refermés d'eux-mêmes. Toujours pas
corrigé (Settings → Git du projet Vercel, action Console de Mathieu).

**Fingerprint LIVE sur `keepy-ten.vercel.app`, requête fraîche** (l'accès
direct reste bloqué en 403 par l'egress du sandbox — passé par le fetch
Vercel, comme aux lots précédents) : HTTP 200, **`x-vercel-cache: MISS`**,
**`age: 0`**, `last-modified` = l'instant de la requête (l'index est servi
en `no-cache, must-revalidate`) — **trois signaux indépendants qui disent
que ce n'est pas une réponse de cache**, la leçon déjà payée deux fois sur
ce projet. `GODOT_CONFIG.fileSizes` = **`index.pck 5 445 248` /
`index.wasm 35 376 909`** — le `wasm` est identique au fingerprint de tous
les lots qui ne touchent pas le code moteur, et c'est LUI la preuve
d'identité, jamais le `.pck`.

Ce que le HTML servi prouve réellement, dit précisément plutôt que
gonflé : **le pont d'auth est bien EN PRODUCTION** (`window.keepyAuth`,
`keepySignInWithGoogle`, `signInWithRedirect`, et `KNOWN_AUTH_HOSTS`
contenant `keepy-ten.vercel.app`, donc `authDomain` résolu sur l'origine
propre et **pas** de repli cross-origin) ; **aucun en-tête COOP/COEP dans
la réponse**, conformément au fix qui les a supprimés ; et
**`/__/auth/handler` répond 200 avec le vrai widget Firebase**, donc la
réécriture de `vercel.json` est active en prod. Le gate visuel lui-même
est dessiné par Godot dans le canvas : **aucune de ces mesures ne le
« voit »**, elles établissent la chaîne commit → build → déploiement →
origine servie. `run/main_scene = res://scenes/LoginScreen.tscn` à ce SHA
en est le dernier maillon. **Le rendu reste un jugement device.**

### Reste ouvert

1. **Le job rules** — droit `serviceusage.services.get` à accorder, puis
   re-run ; et le verdict sur `firebaserules.releases.create` toujours
   pas rendu (voir plus haut).
2. **Les rules LIVE acceptent-elles le champ `uid` ?** Question inchangée
   depuis le 18 août, mais son enjeu a monté d'un cran : la prod envoie
   désormais ce champ pour de vrai, à chaque soumission.
3. **Le durcissement auth** (`request.auth != null` + `uid ==
   request.auth.uid`) reste la décision et le calendrier de Mathieu — et
   il est de toute façon bloqué derrière le point 1, puisque le chemin de
   déploiement des rules ne fonctionne pas encore.
4. La fenêtre de 404 à chaque push sur `main`, inchangée.

## DURCISSEMENT DES RULES : l'auth devient OBLIGATOIRE en écriture, ET la lecture passe en signed-in — chantier « fermer Keepy » CLOS (18 août 2026)

Branche `claude/firestore-auth-hardening-78qq9o`, partie de `main`
(`12d7539`). **Deux fichiers seulement : `firestore.rules` et ce
document.** Aucun `.gd`, aucune scène, aucun `.glb`, aucune config
d'export — `git diff --stat` contre `origin/main` ne rapporte rien
d'autre. `scripts/autoload/Leaderboard.gd` est **intouché**, comme le
brief le demandait : ce lot est le pendant SERVEUR du lot client du
matin même, pas une seconde passe dessus.

### ⚠️ LE PIPELINE DE DÉPLOIEMENT DES RULES FONCTIONNE — le point 1 du « reste ouvert » de la section précédente est CLOS

La section « GATE GOOGLE SIGN-IN EN PRODUCTION » ci-dessus se termine sur
un run #1 en échec (`serviceusage.services.get` refusé) et sur un verdict
jamais rendu concernant `firebaserules.releases.create`. **Les deux sont
tranchés** : Mathieu a accordé le droit IAM manquant, et la **tentative 4
du même run #1** (id `32114434279`, job `95667590004`) est sortie
**verte**, 09:43:24 → 09:44:05 UTC, 8 étapes sur 8 :

```
i  firestore: ensuring required API firestore.googleapis.com is enabled...
✔  firestore: required API firestore.googleapis.com is enabled
✔  cloud.firestore: rules file firestore.rules compiled successfully
✔  firestore: released rules firestore.rules to cloud.firestore
✔  Deploy complete!
```

**Conséquence à ne pas rater : le ruleset LIVE de `keepy-8df91` EST
désormais le fichier versionné.** La Console a cessé d'être la source de
vérité à 09:44:01 UTC. Et cela **clôt au passage la question ouverte
depuis trois lots** — « les rules acceptent-elles un champ `uid` en
plus ? » : le fichier déployé porte `uid` dans son `hasOnly([...])`,
donc oui, par construction et non par déduction. Il n'y a plus rien à
sonder là-dessus.

### Ce qui change, exactement — le diff sémantique fait QUATRE lignes

Comments mis à part (le fichier en gagne beaucoup, il est désormais
auto-documenté puisque la CI le `cat` avant de le publier), le diff
contre `origin/main` est :

| | avant | après |
|---|---|---|
| lecture | `allow read: if true;` | **`allow read: if request.auth != null;`** |
| écriture, 1ère condition | *(aucune)* | **`request.auth != null`** |
| écriture, uid présent | *(non exigé)* | **`keys().hasAll(['uid'])`** |
| écriture, uid légitime | *(non vérifié)* | **`data.uid == request.auth.uid`** |

**Toutes les validations existantes sont conservées AU CARACTÈRE PRÈS** —
vérifié par un diff commentaires-strippés, pas affirmé : `hasOnly` sur
les six clés, `score is int` dans `[0, 100000]`, `name is string` de
`size() <= 12`, `nuts`/`glands` entiers ≥ 0, `createdAt == request.time`,
`allow update, delete: if false`. Le diff sémantique ne contient que les
quatre lignes du tableau.

⚠️ **`hasAll(['uid'])` n'est PAS redondant avec la comparaison qui suit,
et c'est le seul endroit où ce lot s'écarte de la lettre du brief.** Le
brief tablait sur « un uid absent échouera sur la comparaison » — c'est
vrai, mais par une **erreur d'évaluation** (accès à une clé absente),
pas par un `false` propre. `&&` court-circuite, donc `hasAll` transforme
ce cas en refus explicite et lisible avant que la comparaison ne soit
tentée. Même refus, chemin déterministe.

### La lecture : RESTREINTE, et la condition du brief est vérifiée par mesure

Le brief conditionnait le choix à « aucun écran ne lit le classement
avant authentification — vérifie dans le code plutôt que de supposer ».
**Vérifié, et la condition est remplie :**

- `grep` sur tout `scenes/` + `scripts/` : le **seul** appelant de
  `Leaderboard.fetch_top_scores()` est `scripts/ui/GameOverScreen.gd`
  (deux appels : le précheck de qualification, puis le rendu final).
  Aucun autre lecteur nulle part.
- `GameOverScreen` n'est atteignable qu'après une run, une run qu'après
  `TitleScreen`, et `TitleScreen` qu'après `LoginScreen` — qui est le
  `run/main_scene` depuis le gate du 17 août.
- **La seule porte dérobée est fermée dans la scène elle-même**, vérifié
  et pas supposé : `OfflineButton` (« Continuer (hors web) ») porte
  `visible = false` dans `LoginScreen.tscn`, et n'est démasqué que sur la
  branche `not OS.has_feature("web")` de `_ready()` — qu'un build web
  livré ne prend jamais.

**Ce que la restriction achète** : la collection `scores` cesse d'être
énumérable par quiconque possède la clé API cliente — laquelle est
**publique par conception** (elle est dans le build, `Leaderboard.gd`
ligne 49) et donc à la portée de n'importe qui ouvre les devtools. Avant
ce lot, un `POST :runQuery` anonyme rendait la liste complète des
pseudos ; c'est exactement ce qui a servi de mesure de référence
ci-dessous.

**Ce que ça n'achète PAS, et qui est dit plutôt que passé sous silence** : l'inscription
Google est ouverte à tout le monde, donc n'importe quel compte Google
peut toujours lire. La restriction élève le coût d'un scrape (il faut
désormais un compte et un token), elle ne rend pas les données privées.
C'est une porte fermée, pas un coffre.

⚠️ **RÉSIDU ACCEPTÉ, mesuré dans le code et non découvert plus tard** :
un joueur bien connecté dont le round-trip `getIdToken()` n'a jamais
abouti (la branche `.catch` de `html_shell.html`) n'envoie AUCUN header
`Authorization` — `Leaderboard._request_headers()` refuse délibérément
d'émettre un bearer vide. Pour lui, `request.auth` est null et la
lecture échoue là où elle passait avant. **Elle dégrade en « Classement
indisponible », jamais en crash**, et ce même joueur ne peut de toute
façon plus écrire : le classement lui est uniformément indisponible au
lieu d'être à moitié fonctionnel. C'est le seul chemin où la
restriction de lecture coûte quelque chose.

### Tâche 3 — `Leaderboard.gd` face à un `PERMISSION_DENIED` : MESURÉ, pas supposé

Sonde jetable `scripts/dev/LeaderboardDeniedProbe.tscn` (jamais commitée,
supprimée avant le commit — `ProbeTimeoutAudit` revient à **33 sondes**).
Elle pilote les **vrais** handlers de réponse de l'autoload livré
(`_on_submit_completed` / `_on_query_completed`) avec le corps exact que
Firestore renvoie sur un refus, plutôt qu'un stub : la question porte sur
ce que le code livré fait de cette réponse, et rien d'autre dans la
chaîne ne peut changer le verdict.

```
=== LEADERBOARD PERMISSION_DENIED PROBE ===
  network_enabled=false (headless short-circuit)
  Auth.is_signed_in=false uid='' token=''
  headers signed-out: ["Content-Type: application/json"]
    OK    signed-out sends no Authorization header
    OK    signed-out uid is empty (field omitted)
    OK    submit_finished emitted exactly once
    OK    submit_finished carried success=false
    OK    top_scores_fetched emitted exactly once
    OK    top_scores_fetched carried success=false
    OK    top_scores_fetched carried an empty array
    OK    submit_score short-circuits to one failure signal
    OK    fetch_top_scores short-circuits to one failure signal
  --- 0 failure(s) ---        exit 0
```

**9 assertions sur 9 OK, exit 0.** Ce que stderr porte est exactement ce
qu'il doit porter : deux `push_warning` (`result=0, code=403, ...
PERMISSION_DENIED`), **pas** un `push_error`, **pas** une exception — le
403 traverse la même branche que n'importe quel échec réseau, et les deux
signaux partent avec `success = false` une fois chacun. Aucun appelant
n'a de branche à ajouter.

Les trois chemins par lesquels un `uid` peut manquer sont donc couverts,
et **aucun ne crashe** :
1. **Session perdue en cours de partie** (`Auth.is_signed_in()` repasse à
   faux entre le gate et l'écran de game over) → uid omis, pas de bearer,
   403 côté serveur → `submit_finished(false)` → le label « Score non
   synchronisé (hors ligne ?) » s'affiche. Exactement le chemin déjà
   emprunté hors ligne.
2. **Éditeur / desktop** (`OfflineButton`) → jamais signé, donc 403 sur
   les deux appels au lieu de 200. Chemin de développement uniquement,
   dégradation identique.
3. **Sondes headless** → `network_enabled = false` en toute première
   instruction des deux points d'entrée : aucune requête n'est jamais
   construite, `Auth` n'est jamais interrogé. Re-mesuré ci-dessus.

### ⚠️ DÉFAUT TROUVÉ EN LISANT LE CODE, NON CORRIGÉ ICI — le token n'est JAMAIS rafraîchi

`web/html_shell.html` publie l'`idToken` depuis **`onAuthStateChanged`**,
qui ne tire que sur un changement d'état d'authentification — pas depuis
`onIdTokenChanged`, qui est le callback tirant sur les rafraîchissements.
`Auth.gd` coupe par ailleurs son `_process` dès `_ready_reported`
(`set_process(false)`), donc plus aucun poll ne va rechercher une valeur
plus fraîche. **Le token que Godot détient est celui capturé une fois, à
la connexion.** Un token d'ID Firebase expire au bout d'une heure.

Conséquence attendue pour une session PWA laissée ouverte plus d'une
heure : le bearer envoyé est expiré, et Firestore répond **401** avant
même d'évaluer la moindre règle. **Ce n'est PAS créé par ce lot** — un
bearer invalide était déjà rejeté sous les anciennes règles, et le lot
client de ce matin est celui qui a introduit l'envoi du bearer. Ce lot ne
déplace donc rien sur cet axe.

⚠️ **Non mesuré, et dit comme tel** : le 401-sur-token-expiré est le
comportement documenté de l'API, pas une observation faite ici (il
faudrait une session réelle vieille d'une heure). Le correctif naturel
est une ligne de shell (`onIdTokenChanged` au lieu de
`onAuthStateChanged`), mais c'est un changement de JS embarqué dans un
lot de rules + doc : **délibérément laissé à son propre lot** plutôt que
poussé sur `main` sans validation device dans le même commit qu'un
durcissement de sécurité.

### Vérification de bout en bout : la lecture anonyme, AVANT et APRÈS

L'egress vers `firestore.googleapis.com` fonctionne depuis ce sandbox
(contrairement à ce qu'une session précédente avait constaté), donc la
mesure est réelle et non déduite. Même requête exacte que
`Leaderboard.fetch_top_scores()` (`POST :runQuery`, `orderBy score DESC`),
sans aucun header `Authorization` :

| moment | HTTP | corps |
|---|---|---|
| **avant** (rules d'avant ce lot, live) | **200** | la liste réelle des scores, pseudos compris |
| **après** (rules de ce lot, live) | **403** | `{"error":{"code":403,"message":"Missing or insufficient permissions.","status":"PERMISSION_DENIED"}}` |

**La chronologie est serrée au point d'être une preuve de causalité, pas
une corrélation** : le job a imprimé `released rules` à **10:32:59,77
UTC**, et la même requête anonyme, rejouée en boucle toutes les 15 s
depuis avant le push, est passée de **200 à 10:32:45** à **403 à
10:33:01** — deux secondes après la publication. Rien d'autre n'a touché
ce projet dans cet intervalle.

⚠️ **Le pendant en ÉCRITURE n'a PAS été testé, et c'est un choix, pas un
oubli.** La recette « zéro-écriture » consignée plus haut dans ce fichier
(`currentDocument: {"exists": true}` sur un doc id neuf, en lisant 400
`FAILED_PRECONDITION` = accepté contre 403 = refusé) **NE FONCTIONNE
PAS** : mesurée ici, elle rend **403 sur toutes ses variantes, témoin
compris**, parce qu'`exists: true` fait classer l'opération en **UPDATE**
et non en CREATE — or `allow update: if false`. Elle ne peut donc rien
distinguer. La seule alternative aurait été un vrai `exists: false`,
c'est-à-dire écrire une ligne parasite indélébile (`allow delete: if
false`) dans la collection de production. **Le test de lecture ci-dessus
suffit** : il prouve que le ruleset publié est bien celui en vigueur et
que `request.auth != null` est réellement évalué — et la condition
d'écriture vient du **même fichier, publié par la même release**.

**Corollaire pour une future session : ne pas rejouer la recette
zéro-écriture, elle est fausse.** Le paragraphe qui la décrit reste
au-dessus pour l'historique ; ce paragraphe-ci est le correctif.

### Validation

Éditeur Godot 4.3-stable installé dans ce sandbox pour ce lot (release
GitHub officielle). Import headless **exit 0**. Trois sondes rejouées
après retrait de la sonde jetable, **toutes exit 0** :
`ProbeTimeoutAudit` (**33 sondes**, retour exact à la baseline),
`AssetContractAudit` (**12/12 visuels, 0/10 colliders déplacés**),
`DeathModelAudit` (CHARGER seul fatal, capture au 2ᵉ contact pour les
cinq autres). **Non-applicabilité assumée et pas déguisée en preuve** :
aucune sonde de ce dépôt ne parle à Firestore ni ne lit un fichier de
rules — elles ne peuvent pas valider ce lot, elles peuvent seulement
attester qu'il n'a rien cassé, ce qui est déjà garanti par un diff qui
ne touche aucune ressource Godot. Aucun export web n'est
rejoué : ce lot ne touche **aucune** ressource Godot, donc rien de ce que
l'export empaquette ne change — le `.pck` et l'`index.wasm` du build en
production restent ceux du merge `9029bfe`, et le job `web-build.yml` ne
se déclenchera de toute façon que pour reconstruire un arbre identique
côté jeu.

`firestore.rules` re-vérifié comme au lot précédent : **ASCII pur, LF
seul, aucune tabulation, aucun espace en fin de ligne**. La compilation
du ruleset, elle, est **serveur** (`firebaserules.googleapis.com`) — il
n'existe pas de compilateur hors ligne, donc le seul contrôle possible
est celui de la CI. **Mode de défaillance sûr, vérifié dans l'ordre des
étapes du log ci-dessus** : `compiled successfully` précède strictement
`released rules`, donc une erreur de syntaxe fait échouer le job **sans
publier**, laissant les rules live intactes.

### Le déploiement automatique déclenché PAR ce merge : run #2, VERT

`staging` (`e51278b`) → `main`, commit de merge **`8b70b24`**, `--no-ff`,
aucun conflit. `main` était **strictement en retard** (`staging..main`
vide dans l'autre sens) et l'arbre du commit de merge est
**byte-identique** à celui de `staging` et de la branche feature — même
hash d'arbre `3035ee1c...` sur les trois, vérifié avant le push.

Le push a déclenché `firestore-rules.yml` **tout seul**, comme prévu :
run **#2** (id `32127251623`, job `95680442384`), **tentative 1**,
10:32:26 → 10:33:02 UTC, **36 secondes**, `conclusion: success`, **8
étapes sur 8**.

```
i  firestore: ensuring required API firestore.googleapis.com is enabled...
✔  firestore: required API firestore.googleapis.com is enabled
✔  cloud.firestore: rules file firestore.rules compiled successfully
i  firestore: uploading rules firestore.rules...
✔  firestore: released rules firestore.rules to cloud.firestore   [10:32:59,77]
✔  Deploy complete!
```

**Le ruleset durci est en vigueur sur `keepy-8df91` depuis 10:32:59 UTC**,
et c'est vérifié sur le service lui-même (tableau ci-dessus), pas
seulement dans un log de CI.

⚠️ **Le même push déclenche AUSSI `web-build.yml`**, qui reconstruit et
redéploie la prod — donc **une fenêtre de 404 d'environ 3 minutes**, la
même que celle documentée plus haut. Le build est pourtant identique côté
jeu (aucune ressource Godot dans le diff) : c'est le prix fixe d'un push
sur `main`, pas une conséquence de ce lot.

### Reste ouvert

1. **Le rafraîchissement du token** (`onIdTokenChanged`), ci-dessus —
   le seul vrai défaut connu du chemin auth, à traiter dans son propre
   lot avec validation device.
2. **Jugement device** : une soumission de score réelle par un joueur
   Google connecté doit toujours aboutir sur `keepy-ten.vercel.app`, et
   le top 10 doit toujours s'afficher. C'est la seule chose qu'aucune
   mesure de cette session ne couvre — elles prouvent que la porte est
   fermée, pas que la clé du joueur l'ouvre encore.
3. La fenêtre de 404 à chaque push sur `main`, inchangée.


## ÉCRAN HUB « KEEPY'S MEMORIAL QUEST » : la redirection post-connexion ne mène plus à Keepy Chased directement (18 août 2026)

Branche `claude/keepy-memorial-quest-hub-o3hcb6`. **Préparation Quizz, pas
un changement de gameplay** : aucune scène de jeu, aucun collider, aucune
constante, aucun `.glb`, aucun autoload touché. Deux fichiers créés
(`scenes/Hub.tscn`, `scripts/ui/Hub.gd`), **une seule destination
déplacée** dans `scripts/ui/LoginScreen.gd`.

```
run/main_scene = res://scenes/LoginScreen.tscn     (inchangé)
        │  session Google valide
        ▼
res://scenes/Hub.tscn                              <-- NOUVEAU
        ├── « Keepy Chased » -> res://scenes/TitleScreen.tscn   (inchangé)
        └── « Keepy Quizz »  -> DÉSACTIVÉ, « Bientot disponible »
```

⚠️ **`scenes/TitleScreen.tscn` est BYTE-INTOUCHÉ**, vérifié et pas
affirmé (`git diff` vide sur ce fichier) — y compris son script. C'était
la contrainte explicite du lot : Chased reste exactement le jeu validé en
production, et il reste chargeable seul. Un second bouton posé sur
`TitleScreen` aurait fait lire Quizz comme un MODE de Chased plutôt que
comme un sous-jeu frère, et n'aurait laissé aucune place à un troisième.

**Le seul point d'arrivée post-connexion codé en dur du dépôt était
`LoginScreen.gd`**, et c'est **mesuré par `grep`, pas supposé** : les
seules autres occurrences de `TitleScreen` sont la scène elle-même, trois
commentaires (`SwampIdentityAudit.gd`, qui n'échantillonne PAS cet écran
depuis le 14 août et charge `Game.tscn`), un commentaire de
`firestore.rules`, et `README.md`. `TITLE_SCENE` devient donc `HUB_SCENE`,
`_go_to_title()` devient `_go_to_hub()`, et **toute la décision
signed-in / signed-out, le garde `_leaving`, les codes d'erreur et le
chemin hors-web sont intouchés**.

⚠️ **Dette de doc PRÉ-EXISTANTE, signalée et NON corrigée ici** :
`README.md` dit encore que le projet démarre sur `scenes/TitleScreen.tscn`
— faux depuis le gate Google Sign-In du 17 août, donc antérieur à ce lot
et sans rapport avec lui. Laissé à son propre lot plutôt que corrigé en
douce dans un commit atomique qui ne parle pas de ça.

**Le bouton Quizz est inerte, et l'inertie est GATÉE plutôt que
stylistique.** `QuizzButton` porte `disabled = true` dans la scène, **rien
n'est connecté à son signal `pressed`**, et `Hub._ready()` `push_error` si
ce `disabled` disparaît. Motif : un bouton ré-activé sans être connecté
serait un contrôle MORT — silencieux, indiscernable à l'œil d'un bouton
« bientôt » simplement grisé. Même discipline que l'assertion nombre de
pastilles de `HUD.gd` (elle `push_error`, elle ne devine pas). Retirer
cette assertion fait partie du branchement du vrai gameplay, pas d'un lot
séparé.

**Trois décisions de Mathieu verrouillées dans `docs/QUIZZ_SPEC.md`** (le
document de conception Quizz, écrit le matin même avec ces trois points
OUVERTS — §10.1, §10.2, volet partage de §10.5) : hub séparé (livré,
chemins de branchement exacts au nouveau **§7.1**) ; écran de jeu Quizz en
**hôte unique + panneaux par format** ; `visibility` **`'private'` et rien
d'autre, décision actée et pas un état d'attente**. Les paragraphes
concernés sont amendés sur place et barrés, pas supprimés — une session
future doit voir la décision, pas un blanc.

⚠️ **Ce lot est posé sur `claude/quizz-schema-design-u1wixk`**, la branche
docs-only qui apporte `docs/QUIZZ_SPEC.md` (un seul commit, `6f16d8d`, sur
la même base `6d57fd4`) et qui n'était **pas encore mergée sur `staging`**
au moment de partir. Sans elle, la tâche « mets à jour QUIZZ_SPEC.md »
n'avait pas de fichier. Fast-forward, **aucun fichier en commun avec ce
lot**, donc zéro conflit — mais le merge `staging` de ce lot emporte ce
commit de doc avec lui, et c'est dit ici plutôt que découvert dans un
`git log`.

**Validation** : import headless **exit 0** ; boot headless de
`res://scenes/Hub.tscn` seule (`--quit-after 2`) **exit 0**, aucune erreur
de parse ni de nœud manquant (les chemins `@onready` sont donc réels, pas
plausibles) ; export Web release **exit 0**. Mise en page **mesurée** par
sonde jetable (jamais commitée) sur la scène instanciée, pas estimée —
voir le rapport de lot pour les rects réels et la marge restante en bas
d'écran.

**Sondes : aucune n'est concernée, et c'est VÉRIFIÉ, pas supposé** —
`grep` sur `scripts/dev/` : **aucune sonde ne charge `LoginScreen.tscn`
ni `Hub.tscn`**, et aucun `.tscn` de sonde ne les embarque. La seule
mention de `LoginScreen` du dépôt hors `scripts/ui/` est
`run/main_scene` dans `project.godot`, que les sondes contournent par
construction (chacune lance sa propre scène). `SwampIdentityAudit` charge
`Game.tscn` et ne cite `TitleScreen` que dans des commentaires expliquant
pourquoi elle ne l'échantillonne plus. Rejouées quand même :
`ProbeTimeoutAudit` (33 sondes armées), `AssetContractAudit` (12/12
visuels, 0/10 colliders déplacés), `DeathModelAudit`, `ChargerShapeProbe`.

**Reste ouvert — jugement device, seul juge** : que la connexion Google
mène bien au hub sur `keepy-staging.vercel.app`, que « Keepy Chased »
lance la run exactement comme avant, et que le bouton Quizz grisé se lise
comme « bientôt » et non comme « cassé ». **`main` n'est PAS touché par ce
lot** : il déplace le flux de connexion validé en production, donc le
palier 2 est gaté par Mathieu après test device explicite sur staging.

### Merge en production (18 août 2026, autorisation explicite de Mathieu)

`staging` (`7b54201`) → `main`, commit de merge **`6dd4bd5`**, `--no-ff`,
aucun conflit, après validation device sur `keepy-staging.vercel.app` :
connexion → hub affiché correctement, « Keepy Chased » lance la run
normalement, « Keepy Quizz » visible et grisé « Bientot disponible », sans
erreur ni état cassé. **Le hub est EN PRODUCTION** — le flux de connexion
livré aux joueurs est désormais `LoginScreen` → `Hub` → `TitleScreen`, et
non plus `LoginScreen` → `TitleScreen`.

**Règle n°1 vérifiée AU DÉBUT, pas à la fin** (leçon de l'incident du
11 août) : `git fetch --all --prune` puis tri de toutes les refs distantes
par date de commit — la plus récente du dépôt EST `origin/staging`
(11:22:58 UTC), immédiatement suivie de la branche du lot hub
(`claude/keepy-memorial-quest-hub-o3hcb6`, 11:22:40). **Aucune session
concurrente.**

**`main` était strictement en retard** (`staging..main` VIDE) et l'arbre du
commit de merge est **byte-identique à `staging`**, vérifié AVANT le push
et pas supposé : `git diff HEAD origin/staging` vide **et même hash d'arbre
des deux côtés (`fba9a254faae6fec76aa62794d839fbed7d97f01`)**. Ce qui part
en prod est donc littéralement l'arbre validé sur device. Merge `--no-ff`
quand même, comme tous les merges de prod de ce dépôt — un fast-forward ne
laisse aucun point de décision lisible dans l'historique.

⚠️ **`firestore-rules.yml` NE S'EST PAS DÉCLENCHÉ, et c'est vérifié sur le
workflow lui-même, pas déduit du diff.** Deux mesures indépendantes :
1. `git diff --name-only origin/main origin/staging` rend **5 fichiers**
   (`CLAUDE.md`, `docs/QUIZZ_SPEC.md`, `scenes/Hub.tscn`,
   `scripts/ui/Hub.gd`, `scripts/ui/LoginScreen.gd`) — **`firestore.rules`
   n'y est pas**, et le trigger de ce workflow est
   `paths: ['firestore.rules']`.
2. La liste des runs de `firestore-rules.yml` rend **`total_count: 2`** —
   le run **#1** (`9029bfe`, tentative 4) et le run **#2** (`8b70b24`),
   tous deux d'hier/ce matin. **Aucun run sur `6dd4bd5`.**
Le ruleset live de `keepy-8df91` est donc inchangé : c'est toujours celui
publié par le run #2 à 10:32:59 UTC. **Rien de ce lot ne touche à l'auth
Firestore.**

CI **web-build run #145** (id `32133921735`, tentative 1) **verte en
3 min 29 s** (11:52:45 → 11:56:14 UTC) — `Deploy to Vercel
[PRODUCTION -- main]` **succès**, `[STAGING -- staging]` correctement
**skipped** (push sur `main`). Le log porte lui-même `▲ Aliased
https://keepy-ten.vercel.app`.

**Fingerprint vérifié sur le site LIVE, requête fraîche** (`keepy-ten.
vercel.app`, via le fetch Vercel — l'egress direct de ce sandbox reste
bloqué en 403 CONNECT sur ce domaine, re-testé et pas supposé) :
**HTTP 200**, **`x-vercel-cache: MISS`**, **`age: 0`**, `last-modified`
collé à l'instant de la requête (l'index est servi en `no-cache,
must-revalidate`) — trois signaux indépendants qui disent que ce n'est pas
une réponse de cache, comme l'exige la leçon déjà payée deux fois ici.
`GODOT_CONFIG.fileSizes` = **`index.pck 5 451 008` / `index.wasm
35 376 909`**. Le `wasm` est **identique au bit près** au fingerprint
consigné pour tous les lots qui ne touchent pas le code moteur — et c'est
LUI la preuve d'identité, jamais le `.pck`.

**Chaîne de preuve du déploiement, lue sur l'API Vercel** (indépendante du
CDN) : le déploiement production courant est
`dpl_4YsvDd8W1YsZ62Zh6kDVFAkqkdkR`, `state: READY`, `target: production`,
`meta.gitRootDirectory = build/web` (**donc la CI, pas le natif**),
`githubCommitSha = 6dd4bd58…`, `githubCommitMessage = "merge: Keepy's
Memorial Quest hub to production"`.

⚠️ **Ce que ces mesures prouvent, dit précisément plutôt que gonflé** :
elles établissent la chaîne **commit → build → déploiement → origine
réellement servie**. **Le hub lui-même est dessiné par Godot dans le
canvas** — aucune de ces mesures ne le « voit », exactement comme au merge
du gate Google Sign-In. Corroboration seulement, pas preuve : le `.pck`
passe de **5 445 248** (dernier chiffre prod connu) à **5 451 008**
(**+5 760 octets**), cohérent avec l'ajout de `Hub.tscn` + `Hub.gd` — mais
la taille du `.pck` n'est **pas** stable d'un export à l'autre du même
commit (avertissement permanent déjà consigné), donc elle n'est offerte ni
comme preuve d'identité ni comme preuve de contenu. Le hub était validé
sur device sur `staging`, et l'arbre servi en prod est byte-identique à
celui-là.

⚠️ **La fenêtre de ~3 min de 404 s'est reproduite à l'identique — attendue,
pas un signal d'alarme.** Mesurée sur les deux déploiements réels de ce
push, et non déduite : le déploiement **NATIF** Vercel
(`dpl_28Ad4h57j1Xw6WxsqN6kcLTtAXzb`, reconnaissable à son
`meta.branchAlias = keepy-git-main-…`) a pris la prod à **11:52:45**, la
**CI** l'a remplacée à **11:56:03** — **~3 min 18 s** pendant lesquelles la
prod servait le dépôt BRUT (pas d'`index.html` à la racine → 404). Ça se
répare tout seul et personne ne le voit, mais c'est réel : voir la section
« DEUX déploiements se disputent la PROD » pour le détail et le fait que
seul un réglage en Console Vercel (Settings → Git) l'éliminerait. **Ne
jamais lire un fingerprint sans regarder l'heure du dernier déploiement.**

**Aucune sonde rejouée localement, pour cause de non-applicabilité ET
d'outillage absent — dit plutôt que déguisé en preuve.** Le lot hub avait
déjà **vérifié par `grep`, pas supposé**, qu'aucune sonde de
`scripts/dev/` ne charge `LoginScreen.tscn` ni `Hub.tscn` (chacune lance sa
propre scène et contourne `run/main_scene` par construction), et il avait
rejoué `ProbeTimeoutAudit` / `AssetContractAudit` / `DeathModelAudit` /
`ChargerShapeProbe` verts sur l'arbre exact qui est mergé ici. **Aucun
Godot n'est installé dans CE sandbox** (ni éditeur ni templates), donc
aucune sonde ne pouvait y tourner de toute façon. La seule validation
structurelle pertinente — que l'import + l'export headless chargent et
empaquettent l'intégralité des scènes sans erreur — **a eu lieu et
réussi** : c'est exactement ce que fait le job CI (`Import project
resources` + `Export Web build`, tous deux verts sur ce commit précis).

**Reste ouvert** : rien sur le hub lui-même — il est validé device et en
production. Le reste est inchangé et appartient à d'autres lots : le
rafraîchissement du token (`onIdTokenChanged`, jamais rebranché) ; la dette
de doc de `README.md` (il dit encore que le projet démarre sur
`TitleScreen.tscn`) ; la redondance de titres de l'écran-titre ; et la
fenêtre de 404 à chaque push sur `main`.

## RULES KEEPY QUIZZ PORTÉES DANS `firestore.rules` — écrites, PAS encore déployées (18 août 2026)

> ⚠️ **CLÔTURE — DÉPLOYÉES EN PRODUCTION le 18 août 2026 à 12:52:52 UTC**
> (run **#3** de `firestore-rules.yml`, id `32139090001`, merge `e73c796`).
> Le « PAS encore déployées » du titre et le §« CE LOT N'A RIEN DÉPLOYÉ »
> ci-dessous décrivent l'état de ce lot **au moment où il a été écrit** ;
> ils ne sont pas réécrits, pour ne pas perdre la trace de la séquence
> réelle (palier 1 puis palier 2). La section « Merge en production » en
> fin de section porte l'état à jour.

Branche `claude/keepy-quiz-firestore-rules-r1crb3`, partie de `main`
(`7fcada5`). **Deux fichiers : `firestore.rules` et ce document.** Aucun
`.gd`, aucune scène, aucun `.glb`, aucune config d'export — `git diff
--stat` contre `origin/main` ne rapporte rien d'autre. Le brouillon du §4
de `docs/QUIZZ_SPEC.md` est porté tel quel dans le fichier réel ; le
brouillon lui-même n'est pas modifié.

### ⚠️ CE LOT N'A RIEN DÉPLOYÉ — la version LIVE reste celle du 18 août 10:32:59 UTC

**Le ruleset en vigueur sur `keepy-8df91` est toujours celui publié par le
run #2 de `firestore-rules.yml` (id `32127251623`)** : durcissement auth de
`scores`, sans une ligne de Quizz. C'est mécanique et pas une prudence
particulière — le workflow est `on.push.branches: [main]` +
`paths: ['firestore.rules']`, or ce lot part sur `staging`.

⚠️ **Précision qui corrige une formulation courante : un push sur
`staging` ne déclenche RIEN.** Le déclenchement automatique est bien le
comportement voulu et déjà éprouvé (run #1 tentative 4 et run #2, tous deux
verts), mais il est attaché au **merge sur `main`**, pas au palier 1. Le
jour où Mathieu autorise ce merge, le job partira **tout seul**, sans
action manuelle, et publiera ce fichier sur le projet **global** — donc sur
la production de Keepy Chased en même temps que sur staging. C'est
exactement pourquoi ce lot s'arrête à `staging` : les rules n'ont pas de
palier 1 disponible, le gate humain est le seul qui existe.

Mode de défaillance sûr, déjà mesuré dans le log du lot précédent :
`compiled successfully` précède **strictement** `released rules`, donc une
erreur de syntaxe échoue le job **sans publier** et laisse les rules live
intactes.

### Ce qui est ajouté — purement ADDITIF, mesuré et pas plaidé

`git diff --numstat origin/main -- firestore.rules` rend **`192  0`** :
192 lignes ajoutées, **zéro retirée**. C'est la preuve la plus forte que
les rules `scores` ne sont pas touchées, et elle est doublée d'un `cmp` :
le bloc `match /scores/{scoreId}` (47 lignes) et l'en-tête du fichier
(40 lignes) sont **byte-identiques** à `origin/main`.

| bloc | read | create | update | delete |
|---|---|---|---|---|
| `scores/{scoreId}` | signed-in | validé | **interdit** | **interdit** |
| `quizzes/{quizId}` | owner-only | validé | validé | owner-only |
| `quizzes/{quizId}/questions/{questionId}` | owner-only | validé | validé | owner-only |

Le triplet d'auth est **littéralement** celui de `scores` (`hasOnly` /
`hasAll(['uid'])` / `uid == request.auth.uid`), pour qu'un relecteur voie
le même motif aux deux endroits et non deux variantes à comparer.

⚠️ **Un seul écart avec le brouillon du §4, et il est syntaxique, pas
sémantique : les `function` sont HISSÉES au-dessus de leur premier
appel.** Le brouillon déclarait `validCount()` après les `allow` qui
l'utilisent, et `typeShapeValid()` avant ses propres callees. Rien ne
garantit hors ligne que le compilateur de rules hisse les déclarations, et
un `Function is undefined` coûterait un aller-retour complet par le gate
`main` pour un défaut de mise en page. Vérifié par script sur le fichier
livré : **0 violation déclare-avant-usage**, et **les 10 fonctions sont
réellement utilisées** (aucune déclaration morte).

### Vérification `hasOnly` — auditée par script, pas relue à l'œil

Fermeture transitive des appels de fonctions calculée sur le fichier
livré, pour chaque `allow` :

| `allow` | `hasOnly` | `hasAll` | auth | `visibility == 'private'` |
|---|---|---|---|---|
| quizzes `create` | ✅ | ✅ | ✅ | ✅ |
| quizzes `update` | ✅ | ✅ | ✅ | ✅ |
| questions `create` | ✅ *(via `typeShapeValid`)* | ✅ | ✅ | s.o. |
| questions `update` | ✅ *(via `typeShapeValid`)* | ✅ | ✅ | s.o. |
| tous les `read` / `delete` | s.o. — aucune donnée entrante | — | ✅ | s.o. |

**Aucun chemin d'écriture ne peut faire entrer un champ hors schéma.** Sur
les questions, le porteur du `hasOnly` est `typeShapeValid()` et non
`commonValid()` : chaque branche de type ferme son **propre** jeu de clés,
donc un `mcq4` ne peut pas transporter `answerBool` ni un `truefalse` un
`answerIndex`. C'est ce qui rend `type` contraignant plutôt que décoratif —
et les deux `allow` exigent `typeShapeValid()`, donc il n'existe pas de
chemin qui n'aurait que `commonValid()`.

**`visibility` ne peut jamais valoir autre chose que `'private'` à la
création** : la valeur est comparée par égalité stricte, ET le champ est
dans le `hasAll`, donc il ne peut pas non plus être omis. Même paire sur
`update` — un quiz créé privé ne peut pas être élargi par une mise à jour.

### Comment un élargissement futur de `visibility` se ferait — DEUX edits distincts

C'est la propriété qui a fait retenir « le champ existe, la valeur
`'public'` n'existe pas » plutôt que « pas de champ du tout » ou
« accepter `'public'` tout de suite » (`docs/QUIZZ_SPEC.md` §2.3, décision
actée par Mathieu le 18 août 2026 — **une décision, pas un état
d'attente**). Ouvrir le partage demanderait :

1. **Édit n°1 — élargir l'ÉCRITURE** : remplacer
   `visibility == 'private'` par une appartenance à un ensemble, dans les
   deux `allow` (`create` **et** `update`) du bloc `quizzes`.
2. **Édit n°2 — élargir la LECTURE** : la règle de lecture actuelle est
   `allow read: if ownsExisting();`, owner-only **sans mentionner
   `visibility` du tout**. C'est délibéré : une règle qui consulterait déjà
   ce champ serait une porte à moitié ouverte, et l'édit n°1 seul
   l'ouvrirait rétroactivement sur tout document marqué entre-temps.

**Deux edits = deux passages par le gate `main`**, donc deux revues. Et
⚠️ **la question de la triche structurelle doit être tranchée AVANT le
premier des deux** : les bonnes réponses vivent dans le document que le
joueur doit lire, les rules ne savent pas masquer un champ à l'intérieur
d'un document (c'est tout ou rien), et ce projet n'a **aucun composant
serveur** pour arbitrer — Keepy parle à Firestore en REST direct. Ce n'est
pas un détail d'implémentation à régler plus tard.

### Limites ACCEPTÉES, reportées dans le fichier lui-même — pas des bugs à corriger

Recopiées en tête du bloc Quizz de `firestore.rules` pour qu'un relecteur
du seul fichier de rules les ait sous les yeux (`docs/QUIZZ_SPEC.md` §5) :
le **nombre de questions par quiz n'est pas gatable** (les rules ne savent
pas compter les documents d'une sous-collection — le plafond de 50 est
client-side, et `questionCount` est borné mais **jamais** confronté à la
réalité) ; **pas de suppression en cascade** (les questions orphelines
restent en base, lisibles par leur seul propriétaire — coût de stockage,
pas de fuite) ; **`order` n'est ni unique ni contigu** (trier sur
`(order, questionId)`, jamais sur `order` seul).

### Validation

⚠️ **Il n'existe pas de compilateur de rules hors ligne** — la compilation
est un service (`firebaserules.googleapis.com`) et la clé de compte de
service vit dans le secret GitHub, jamais dans un sandbox. La première
vraie vérification syntaxique aura donc lieu au déploiement, avec le mode
de défaillance sûr rappelé plus haut. Ce qui a pu être vérifié ici l'a été
**par script sur le fichier livré**, pas par relecture : accolades
équilibrées (21/21, profondeur finale 0, jamais négative), **ASCII pur**,
**LF seul**, aucune tabulation, aucun espace en fin de ligne, newline
finale unique — la même liste de contrôles que les deux lots rules
précédents.

**Aucune sonde rejouée, et c'est une non-applicabilité assumée, pas une
omission déguisée en preuve** : ce lot ne touche **aucune** ressource
Godot, donc rien de ce que l'export empaquette ne change, et aucune sonde
de `scripts/dev/` ne lit un fichier de rules ni ne parle à Firestore —
elles ne peuvent pas valider ce lot. **Aucun Godot n'est de toute façon
installé dans ce sandbox** (ni éditeur ni templates). Piège payload sans
objet et déjà mesuré au lot précédent : `firestore.rules` n'est pas une
ressource Godot (0 occurrence dans le `.pck`), et `CLAUDE.md` non plus.

### Reste ouvert

1. **Le déploiement lui-même** — merge `staging` → `main`, gaté par
   Mathieu, et c'est ce merge qui déclenchera le job. Rien de ce lot n'est
   en vigueur avant.
2. **La première compilation réelle** de ce bloc, qui n'a jamais eu lieu
   (voir ci-dessus).
3. **Aucun client n'existe encore** : `Quizz.gd`, les écrans du §7 et le
   branchement du bouton grisé du hub restent à écrire. Ces rules décrivent
   un contrat que rien n'exerce pour l'instant — et `docs/QUIZZ_SPEC.md` §8
   porte déjà les pièges REST à connaître avant de l'écrire (deux
   `updateTransforms` à la création, `updateMask` excluant `uid`/
   `createdAt` à la mise à jour, `fieldFilter uid EQUAL` **obligatoire**
   sur toute liste, index composite `uid ASC` + `updatedAt DESC`, un seul
   `HTTPRequest` en vol à la fois, et le bearer **exigé** — un appel sans
   token est un 403 garanti, à ne pas dépenser en aller-retour).
4. Le rafraîchissement du token (`onIdTokenChanged`, jamais rebranché) —
   inchangé, et **Quizz y sera plus exposé que Chased**, qui n'écrit
   qu'une fois en fin de run.

### Merge en production (18 août 2026, autorisation explicite de Mathieu)

`staging` (`54eb498`) → `main`, commit de merge **`e73c796`**, `--no-ff`,
aucun conflit. **Ce merge est le premier à publier des rules Quizz sur
`keepy-8df91`** — le projet est GLOBAL, donc ce ruleset est celui
qu'évaluent staging ET la prod de Keepy Chased.

Règle n°1 vérifiée **AU DÉBUT** (leçon de l'incident du 11 août) :
`git fetch --all --prune` puis tri de toutes les refs distantes par date de
commit — la plus récente du dépôt EST `origin/staging` (12:37:18 UTC),
immédiatement suivie de `claude/keepy-quiz-firestore-rules-r1crb3`
(12:36:59), les deux appartenant à ce lot. **Aucune session concurrente.**

`main` était **strictement en retard** (`staging..main` VIDE) et l'arbre du
commit de merge est **byte-identique à `staging`**, vérifié AVANT le push :
`git diff HEAD origin/staging` vide **et même hash d'arbre des deux côtés
(`65685e1d1b9d0c2cd2b65273b85b9d0411a3fbd9`)**, `firestore.rules` au même
md5 (`13baa15cb3ee7d7696431408f6ccaaaf`).

#### ⚠️ RÉSULTAT DU JOB RULES — run #3, VERT, et le mode de défaillance sûr a tenu

Run **#3** (id `32139090001`, job `95717216243`), **tentative 1**,
12:51:41 → 12:52:55 UTC, **71 s**, `conclusion: success`, **8 étapes sur 8**
— aucun des deux échecs IAM du run #1 ne s'est reproduit
(`serviceusage.services.get` passe, et **`firebaserules.releases.create` rend
enfin son verdict : il passe aussi**).

**L'ordre exigé par la tâche est vérifié à l'horodatage, pas supposé** — la
compilation précède STRICTEMENT la publication, donc une erreur de syntaxe
aurait fait échouer le job **sans rien publier**, laissant les rules live
intactes :

```
12:52:50.94  ✔  firestore: required API firestore.googleapis.com is enabled
12:52:51.83  i  cloud.firestore: checking firestore.rules for compilation errors...
12:52:52.25  ✔  cloud.firestore: rules file firestore.rules compiled successfully
12:52:52.44  i  firestore: uploading rules firestore.rules...
12:52:52.89  ✔  firestore: released rules firestore.rules to cloud.firestore
12:52:52.89  ✔  Deploy complete!
```

**C'était la PREMIÈRE compilation réelle du bloc Quizz** (point 2 du « Reste
ouvert » ci-dessus) : il n'existe pas de compilateur de rules hors ligne, la
compilation est un service. Elle passe du premier coup — les 21 accolades
équilibrées et l'hygiène ASCII/LF vérifiées par script sur la branche
n'avaient jamais prouvé que la SYNTAXE Firestore était bonne, seulement
qu'elle était plausible. Elle l'est.

**L'étape `Show resolved rules file` imprime le fichier ENTIER au SHA
`e73c7962…`**, donc le log porte littéralement ce qui a été publié — le bloc
`/scores` y figure verbatim, `allow read: if request.auth != null;` et les
huit lignes de validation de `create` comprises.

⚠️ **Piège de lecture de ce log, à connaître avant de crier à la corruption :
GitHub masque `{` et `}` en `***`** (le secret `FIREBASE_SERVICE_ACCOUNT_KEEPY`
est un JSON dont les accolades sont des lignes de secret à part entière, donc
Actions les censure partout dans le log). `function signedIn() ***` est
`function signedIn() {`. Le log est donc **inutilisable pour une comparaison
byte-à-byte**, et parfaitement lisible pour tout le reste.

#### Le bloc `/scores` n'a pas bougé — le vrai risque de ce merge

C'était le risque implicite, pas « est-ce que les nouvelles rules
marchent ». Trois preuves indépendantes, dans l'ordre de force :

1. **Byte-identité en amont, mesurée avant le merge** : les **68 premières
   lignes** de `firestore.rules` (en-tête + bloc `/scores` complet jusqu'à
   son accolade fermante) sont **byte-identiques** entre `origin/main` et
   `origin/staging` (`cmp` silencieux). Le diff est purement additif : il
   commence à la ligne 66, **après** `allow update, delete: if false;`.
2. **Release atomique d'un fichier unique** : `firebase deploy --only
   firestore:rules` publie LE fichier, il ne fusionne pas des blocs. Un
   `/scores` inchangé dans le fichier est donc un `/scores` inchangé en
   vigueur — c'est structurel, pas une inférence.
3. **Mesure côté service, avant ET après le déploiement** — la requête
   `:runQuery` **exactement** celle de `Leaderboard.fetch_top_scores()`
   (`orderBy score DESC, limit 10`), sans header `Authorization` :

   | | avant (12:50 UTC) | après (12:54 UTC) |
   |---|---|---|
   | `/scores` `:runQuery` anonyme | **403 PERMISSION_DENIED** | **403 PERMISSION_DENIED** |
   | `/quizzes` `:runQuery` anonyme | 403 | 403 |

   Les corps de réponse sont **byte-identiques** avant/après (`cmp`
   silencieux sur les deux collections). Un `GET /documents/scores` anonyme
   rend 403 lui aussi.

⚠️ **Ce que cette mesure ne prouve PAS, dit plutôt que gonflé** : un 403
anonyme est le comportement ATTENDU depuis le durcissement du 18 août
10:32:59 — il montre que le gate de lecture est toujours évalué de la même
façon, **pas** qu'un joueur Google réellement connecté peut encore lire et
écrire. **Aucune requête AUTHENTIFIÉE n'a pu être émise depuis ce sandbox** :
il n'y a pas d'idToken Google disponible, et la sonde qui aurait pu en
fabriquer un (création d'un compte anonyme via `identitytoolkit
accounts:signUp`) **a été refusée par le classifieur d'actions** — refus
respecté, aucun contournement tenté. Le seul témoin réel reste une
soumission de score par un vrai joueur connecté. **Jugement device.**

#### Web build : vert, et la prod sert bien cet arbre

CI **web-build run #148** (id `32139090008`, tentative 1), **succès en
3 min 18 s** (12:51:45 → 12:55:03). `Deploy to Vercel [PRODUCTION -- main]`
**succès**, `[STAGING -- staging]` correctement **skipped**. Le log porte
lui-même `▲ Aliased https://keepy-ten.vercel.app`. **Aucun changement Godot
n'était attendu** (le diff ne contient que `firestore.rules` et `CLAUDE.md`,
dont aucun n'est une ressource Godot) et c'est confirmé côté sortie.

**Fingerprint vérifié sur le site LIVE**, requête fraîche via le fetch Vercel
(l'egress direct de ce sandbox reste bloqué en 403 CONNECT sur ce domaine) :
HTTP **200**, **`x-vercel-cache: MISS`**, **`age: 0`**, `last-modified` collé
à l'instant de la requête — trois signaux indépendants qui disent que ce
n'est pas une réponse de cache. `GODOT_CONFIG.fileSizes` = **`index.pck
5 451 056` / `index.wasm 35 376 909`**. Le `wasm` est **identique au bit
près** au fingerprint consigné pour tous les lots qui ne touchent pas le code
moteur — et c'est LUI la preuve d'identité, jamais le `.pck`.

**Aucune sonde rejouée, non-applicabilité assumée et pas une omission** : ce
lot ne touche **aucune** ressource Godot, aucune sonde de `scripts/dev/` ne
lit un fichier de rules ni ne parle à Firestore, et aucun Godot n'est
installé dans ce sandbox. La seule validation structurelle pertinente —
import + export headless de l'intégralité des scènes sans erreur — **a eu
lieu et réussi** : c'est exactement ce que fait le job CI sur ce commit
précis.

#### Reste ouvert après ce merge

1. **Aucun client n'exerce encore ces rules** — point 3 ci-dessus,
   **inchangé** : `Quizz.gd`, les écrans du §7 et le branchement du bouton
   grisé du hub restent à écrire. Le contrat est en vigueur, rien ne
   l'appelle.
2. **La première écriture réelle** (create d'un quiz, create d'une question)
   n'a jamais été tentée contre le service — ni ici (egress d'écriture et
   classifieur), ni ailleurs. Les pièges REST du §8 de `docs/QUIZZ_SPEC.md`
   sont donc toujours de la théorie.
3. **Le classement de Chased**, pour un joueur Google réellement connecté :
   argumenté inchangé et mesuré inchangé sur le canal anonyme, mais non
   testé sur le canal authentifié — voir l'avertissement ci-dessus.
4. ~~Le rafraîchissement du token (`onIdTokenChanged`, jamais rebranché)~~
   — **CLOS le 18 août 2026**, voir la section suivante — et la
   fenêtre de ~3 min de 404 à chaque push sur `main` : **inchangée**, et
   toujours hors périmètre de ce lot.


## RAFRAÎCHISSEMENT DU TOKEN FIREBASE : défaut CLOS — `onIdTokenChanged` remplace `onAuthStateChanged` (18 août 2026)

Branche `claude/firebase-token-refresh-ipkaym`, partie de `main`
(`afed994`). **Ferme le défaut connu ouvert depuis le lot de durcissement
des rules du 18 août** (« ⚠️ DÉFAUT TROUVÉ EN LISANT LE CODE, NON CORRIGÉ
ICI — le token n'est JAMAIS rafraîchi »), listé « reste ouvert » dans les
trois lots suivants sans être traité. **Prérequis à `Quizz.gd`**, qui y
sera bien plus exposé que `Leaderboard.gd` : Chased n'écrit qu'une fois par
run de 40-90 s, Quizz écrira de façon répétée et étalée dans le temps.

**Trois fichiers : `web/html_shell.html`, `scripts/autoload/Auth.gd`, ce
document.** `scripts/autoload/Leaderboard.gd` est **byte-intouché**
(`git diff` vide) — c'était la contrainte du lot, et elle tient sans effort
pour une raison structurelle expliquée plus bas. Aucune scène, aucun
collider, aucune constante de gameplay, aucun `.glb`, aucune config
d'export.

### Le mécanisme du défaut, et pourquoi il était silencieux

Un token d'ID Firebase **expire au bout d'une heure**. Le SDK le renouvelle
tout seul bien avant, mais le shell n'écoutait que **`onAuthStateChanged`**,
qui ne tire **que** sur connexion et déconnexion — **jamais** sur un
renouvellement. Le `idToken` publié dans `window.keepyAuth` restait donc la
chaîne capturée une fois à la connexion, pour toute la session.

⚠️ **Ce que l'ancienne formulation du défaut disait d'`Auth.gd` était
imprécis, et c'est vérifié dans le code plutôt que repris tel quel.** Le
`set_process(false)` posé après `ready` **ne coupait PAS la réception** :
il ne coupait que le **poll de secours**. Le callback push
(`window.keepyAuthNotify`, installé dans `_ready()` et jamais retiré)
restait vivant, et `_apply_snapshot()` écrase bien `_id_token` à chaque
snapshot reçu. **Le défaut était donc à 100 % côté shell** — rien n'était
jamais republié, donc il n'y avait rien à pousser. Corriger le seul
`onAuthStateChanged` suffit à fermer le défaut ; le volet `Auth.gd`
ci-dessous ferme un trou distinct.

Silencieux parce que le chemin d'échec est **le même que celui d'être hors
ligne** : `Leaderboard.gd` prend un `push_warning`, émet
`submit_finished(false)`, et l'écran affiche « Score non synchronisé (hors
ligne ?) ». Un joueur dont la session dure plus d'une heure voyait donc un
message de réseau pour une cause d'authentification.

### Le fix — `onIdTokenChanged` est un SUPERSET, pas une alternative

Les deux listeners ne sont pas deux options à arbitrer :
`onIdTokenChanged` tire **exactement là où `onAuthStateChanged` tire**
(une fois au démarrage avec l'utilisateur restauré ou `null`, puis à chaque
connexion/déconnexion) **PLUS** à chaque renouvellement de token.
**Remplacé, pas ajouté à côté** : enregistrer les deux publierait le même
payload deux fois à chaque connexion et déconnexion, soit un second écrivain
pour un fait qui a déjà un propriétaire — le contraire de la discipline que
tout ce fichier applique par ailleurs.

⚠️ **Piège fermé explicitement dans le commentaire, parce qu'il est
séduisant : `getIdToken(true)` À L'INTÉRIEUR de ce listener est une boucle
infinie.** Un refresh forcé produit un nouveau token, ce qui refait tirer ce
même listener, ce qui reforce un refresh — contre les serveurs de Google. Le
`getIdToken()` **non forcé** déjà en place est le bon appel : sur un
callback de renouvellement, le token que le SDK vient de mettre en cache
**EST** le nouveau.

**Les noms de checkpoints de diagnostic sont volontairement INCHANGÉS**
(`first-auth-state-received` en particulier, toujours posé par
`firstAuthStateSeen` sur le premier appel du nouveau listener). Ils sont
cités dans `Auth.gd`, dans le label écran de `LoginScreen.gd` et dans ce
document comme l'état sain de fin de boot ; les renommer les aurait
invalidés partout sans le dire. Le watchdog de stall (qui teste
`firstAuthStateSeen`) et la sonde d'embed d'iframe sont donc **intacts et
toujours fonctionnels**.

### AJOUT au-delà du périmètre littéral : le backstop `visibilitychange`

Dit plutôt que glissé : ce lot ajoute une chose que la liste de tâches ne
demandait pas nommément, parce qu'elle relève du même défaut.

Le renouvellement proactif du SDK est **un timer**, et un timer dans un
onglet en arrière-plan — **une PWA installée que le joueur a quittée est le
cas ORDINAIRE sur mobile, pas le cas exotique** — est throttlé ou suspendu
par le navigateur. Il peut donc tirer en retard, laissant une fenêtre où le
token publié est déjà expiré au retour du joueur.

Un handler `visibilitychange` appelle `user.getIdToken()` **sans
`forceRefresh`** quand la page redevient visible. C'est exactement le bon
appel : la méthode rend le token en cache **tel quel** s'il n'expire pas
dans les cinq minutes, et ne renouvelle que sinon. Donc **no-op sur chaque
changement d'onglet ordinaire, vrai renouvellement seulement quand il
serait sinon trop tard**. Il **ne publie rien lui-même** — un
renouvellement fait tirer `onIdTokenChanged`, qui reste l'unique écrivain
d'`idToken`. Enveloppé dans un `try/catch` : perdre ce backstop coûte de la
fraîcheur après un long arrière-plan, jamais la connexion.

### `Auth.gd` — le poll de secours ne s'arrête plus, il RALENTIT ×60

`POLL_INTERVAL_READY_S := 30.0` (nouveau) remplace le `set_process(false)`
sur le chemin sain. **L'argument d'origine reste vrai et n'est pas
contredit** : un `JavaScriptBridge.eval` à 2 Hz n'a rien à faire dans le
budget de frame d'un runner à 60 fps. Il ne dit rien de **1/30 Hz**, qui est
ce qui est posé ici — **600× moins cher** que le poll de démarrage.

Ce qui a changé, c'est ce que ce backstop protège. Avant, il n'y avait rien
à rattraper après `ready` : l'état était capturé une fois et fini, et le
seul événement manquable aurait été une déconnexion que rien dans ce jeu ne
déclenche. Maintenant que le shell republie à chaque renouvellement, **un
push perdu après `ready` coûte un bearer périmé de façon permanente** — soit
exactement le défaut que ce lot ferme. Et un push perdu est **silencieux par
conception** : le `publish()` du shell avale un listener qui lève
(« un Godot cassé ne doit jamais casser l'auth »). Un backstop qui s'arrête
avant que la chose qu'il couvre ne commence à arriver n'est pas un backstop.

⚠️ **Le chemin `bridge-timeout` garde EXACTEMENT son comportement d'avant
(`set_process(false)`), et c'est délibéré.** Le confier au backstop lent
aurait fait relire le snapshot du bloc `<script>` pré-module — celui qui
porte `error: 'not-ready'` — dont le code aurait **écrasé `bridge-timeout` à
l'écran** et perdu le seul diagnostic que ce chemin existe pour produire.
Deux états « ready » distincts (annoncé par le pont / conclu par timeout),
deux traitements.

`get_id_token()` gagne un contrat explicite dans sa doc : **c'est le token
COURANT, pas celui capturé à la connexion**, et un appelant doit le lire au
moment où il en a besoin plutôt que de mettre le résultat en cache.

### Tâche 3 — `Leaderboard.gd` : rien à changer, et c'est structurel

**Vérifié dans le code, pas supposé** : `_request_headers()` est appelé
**en ligne dans l'appel `request()` lui-même**, aux deux points d'entrée
(`submit_score` ligne 221, `fetch_top_scores` ligne 255), jamais une fois
dans `_ready()`. Il relit donc `Auth.get_id_token()` à chaque requête et
récupère le token frais **sans une ligne de changement**. Le
court-circuit headless (`if not network_enabled` en toute première
instruction des deux points d'entrée) est également intact : une sonde ne
touche jamais `Auth`.

### Tâche 4 — sondes headless : intactes, et c'est structurel aussi

`Auth.gd` tourne en autoload dans **chaque** sonde, mais son `_ready()`
prend la branche `if not OS.has_feature("web")` — systématiquement vraie
sous `--headless` — qui appelle `set_process(false)` et `return` avant
toute ligne utile. `_process()` n'est donc **jamais** exécuté sous sonde, et
le nouveau `POLL_INTERVAL_READY_S` **jamais atteint**.
`web/html_shell.html` n'est ni une ressource Godot ni chargé par quoi que
ce soit en headless. **Aucune sonde ne peut voir ce lot**, par construction
et pas par chance. Rejouées quand même, résultats plus bas.

### Validation

Éditeur + templates Godot 4.3-stable installés dans ce sandbox (releases
GitHub officielles, mêmes que la CI).

⚠️ **Piège d'outillage rencontré, à connaître** : le premier téléchargement
de `Godot_v4.3-stable_export_templates.tpz` s'est terminé **sans erreur
curl** à **318 289 257 octets** contre les **1 073 228 327** annoncés par le
`Content-Length` — une troncature silencieuse, qui se manifeste plus loin
par un `End-of-central-directory signature not found` d'`unzip` ressemblant
à une archive corrompue en amont. **Toujours vérifier la taille contre le
`Content-Length` avant de conclure que la release est cassée**, et reprendre
avec `curl -C -`.

Les deux blocs `<script>` du shell extraits et vérifiés avec `node --check`
(syntaxe seule, aucun DOM ni SDK réel en headless) : **les deux OK**.

Import headless **exit 0**, export Web release **exit 0**. `index.wasm`
**35 376 909 octets**, md5 **`af4a8fc2925d992348eb30deeeb54360`** — identique
au fingerprint déjà consigné pour tout lot qui ne touche pas le code moteur ;
`index.js` md5 **`4e08904b1b7107858246af44b602067b`**, également identique.
`index.pck` 5 451 104 octets (export unique et propre, `build/` et `.godot/`
supprimés d'abord — à lire avec la mise en garde permanente sur son
instabilité, jamais offert comme preuve). `index.manifest.json` inchangé.
**Piège payload tenu** : **0** ligne `Storing File` pour `res://assets_source`,
`res://docs`, `res://web` ou `firebase.json`.

**Vérifié dans le bundle EXPORTÉ, pas seulement dans la source** :
`authMod.onAuthStateChanged` **0 occurrence** (les 5 mentions restantes de
`onAuthStateChanged` sont toutes des commentaires, dont deux volontairement
laissées au passé — elles racontent le bug COEP du 17 août, où le listener
S'APPELAIT bien ainsi) ; `onIdTokenChanged` 5, `visibilitychange` 1,
`first-auth-state-received` 3. `viewport-fit=cover` et `#101d0b` toujours en
place — le fix safe-area du 17 août n'est pas abîmé.

**QUATRE sondes rejouées et diffées contre `origin/main` en worktree séparé :
les QUATRE sont BYTE-IDENTIQUES sur les DEUX flux (stdout ET stderr), exit 0
des deux côtés** — `ProbeTimeoutAudit` (**33 sondes armées**),
`AssetContractAudit` (**12/12 visuels, 0/10 colliders déplacés**),
`DeathModelAudit`, `ChargerShapeProbe`. C'est le bar attendu, et l'identité au
bit près le dit plus fort qu'un simple verdict identique.

⚠️ **Second piège d'outillage, celui-ci capable de fabriquer un FAUX ROUGE — à
connaître avant d'accuser son propre lot.** Le premier run de comparaison a
donné 3 sondes sur 4 « DIFFERS », dont `AssetContractAudit` annonçant
`[-- ]` là où le lot lit `[glb]` : de quoi croire à une régression d'assets.
Ce n'en était pas une — l'import du worktree de baseline avait été coupé avant
la fin (**5 puis 21 `.scn` importés sur 24**), donc les `.glb` manquaient et la
baseline mesurait des placeholders. Le `stderr` le disait (`Cannot open file
'res://.godot/imported/*.glb-*.scn'`) et le `stdout` seul ne le disait pas.
**Compter les `.scn` de `.godot/imported/` des deux côtés avant de comparer
quoi que ce soit** : un import Godot complet de ce projet prend plusieurs
minutes dans ce sandbox et ne signale pas lui-même qu'il a été interrompu.

### Déployé sur `staging` (palier 1, automatique)

`staging` `e1f97fc`, CI run **#150** (id `32150981048`) **verte en
5 min 11 s** — `Deploy to Vercel [STAGING -- staging]` **succès**,
`[PRODUCTION -- main]` correctement **skipped**. `main` **non touché**
(palier 2, gaté par Mathieu après validation device).

**Fingerprint vérifié sur le site LIVE** (`keepy-staging.vercel.app`, via
`mcp__Vercel__web_fetch_vercel_url` — l'egress direct de ce sandbox reste
bloqué en 403 CONNECT sur ce domaine, re-testé et pas supposé) : HTTP 200,
`x-vercel-cache: MISS`, `age: 0`, `last-modified` collé à l'instant de la
requête (l'index est servi en `no-cache, must-revalidate`) — trois signaux
indépendants qui disent que ce n'est pas une réponse de cache.
`GODOT_CONFIG.fileSizes` = `index.pck 5 451 120` / **`index.wasm
35 376 909`**, ce dernier identique au bit près à l'export local.

⚠️ **Le fix est vérifié DANS LES OCTETS SERVIS, pas seulement dans le
commit** : le shell livré porte bien `authMod.onIdTokenChanged(auth, ...)`
et le handler `visibilitychange`. **Un AVANT/APRÈS réel a été capturé au
passage**, parce que la même URL avait été lue trop tôt : à 14:55 elle
servait encore `authMod.onAuthStateChanged` (build précédent), à 14:58 elle
sert `onIdTokenChanged`.

⚠️ **Discriminateur bon marché trouvé et à réutiliser** : `index.pck` n'est
pas stable d'un export à l'autre et `index.wasm` ne bouge jamais sur un lot
sans code moteur — **aucun des deux ne dit quel build est aliasé**. Le
`CACHE_VERSION` d'`index.service.worker.js` (~5 Ko) est un **epoch de
l'instant d'export** : `1787056834` = 12:40:34 UTC (run #147, l'ancien) puis
`1787064920` = 14:55:20 UTC (run #150, celui-ci). Un fichier minuscule qui
date le build servi, là où l'index complet coûte ~30 Ko à relire.

⚠️ **L'API GitHub Actions a de nouveau servi des réponses PÉRIMÉES**, comme
la section dédiée le documente : trois polls successifs ont rendu une
réponse **byte-identique** figée sur `updated_at: 14:52:21`, `filter:
"latest"` compris, pendant que le job avançait réellement. Ce qui a tranché
n'est pas un poll de plus mais le **second signal indépendant** — le
`CACHE_VERSION` servi par le site. Ne jamais conclure d'un seul appel.

### Reste ouvert — jugement device, seul juge

Aucune sonde de ce dépôt ne rend de pixels iOS, n'exécute le SDK Firebase,
ni ne peut faire passer une heure à une session réelle. Ce qui reste à
confirmer, et ce qui ne peut l'être que sur device :

1. **Le cas nominal ne régresse pas** : connexion Google sur
   `keepy-staging.vercel.app`, arrivée au hub, une run de Chased, et le
   score qui se synchronise comme avant. C'est le risque principal du lot —
   le listener remplacé est celui dont dépend tout le boot.
2. **Le cas que le lot corrige** : une session laissée ouverte **plus
   d'une heure** (idéalement en PWA installée, mise en arrière-plan puis
   reprise), puis une soumission de score qui aboutit toujours. Avant ce
   lot elle échouait en « Score non synchronisé ».
3. Le backstop `visibilitychange` n'a **aucune preuve mesurée** ici : il
   repose sur le contrat documenté de `getIdToken()` (« rend le cache sauf
   à moins de cinq minutes de l'expiration »), pas sur une observation.

## `Quizz.gd` : PREMIER CLIENT RÉEL des collections `quizzes`/`questions` — CRUD d'authoring seul, aucun écran (18 août 2026)

Branche `claude/quizz-autoload-crud-pkqwl4`, partie de `staging` (`6d6a6a4`,
donc **posée sur le fix de rafraîchissement du token `onIdTokenChanged`** du
même jour — ce n'est pas un détail, voir plus bas). **Deux fichiers touchés :**
`scripts/autoload/Quizz.gd` (nouveau) et une ligne d'autoload dans
`project.godot`. **`scenes/Hub.tscn`, `scripts/ui/Hub.gd` et
`firestore.rules` sont INTOUCHÉS**, vérifié et pas affirmé : `git diff --stat`
contre `origin/staging` ne rapporte rien d'autre que ces deux fichiers (+ ce
document).

Les rules Quizz sont en production depuis le 12:52:52 UTC du même jour (run #3
de `firestore-rules.yml`) et **rien ne les exerçait** : le point 1 du « Reste
ouvert » de la section rules disait « aucun client n'existe encore ». Ce lot
écrit ce client. Il ne le **teste** toujours pas contre le service — voir
« Ce qui n'a PAS été mesuré » plus bas, c'est la limite honnête de ce lot.

### Périmètre : authoring, et rien d'autre

Créer / lire / modifier / supprimer **ses propres** quiz et questions. Huit
points d'entrée, huit signaux :

| appel | signal |
|---|---|
| `create_quiz(title)` | `quiz_created(success, quiz_id, error)` |
| `update_quiz(quiz_id, title, question_count = -1)` | `quiz_updated(success, quiz_id, error)` |
| `delete_quiz(quiz_id)` | `quiz_deleted(success, quiz_id, error)` |
| `list_own_quizzes()` | `quizzes_fetched(success, quizzes, error)` |
| `create_question(quiz_id, type, payload)` | `question_created(success, quiz_id, question_id, error)` |
| `update_question(quiz_id, question_id, type, payload)` | `question_updated(success, quiz_id, question_id, error)` |
| `delete_question(quiz_id, question_id)` | `question_deleted(success, quiz_id, question_id, error)` |
| `list_questions(quiz_id)` | `questions_fetched(success, quiz_id, questions, error)` |

**Aucune scène, aucun écran de jeu, aucune boucle de partie.** Le bouton
« Keepy Quizz » du hub reste `disabled = true` et **toujours connecté à rien**.

⚠️ **`success` est en PREMIER argument ici, alors que `Leaderboard.gd` le met
en DERNIER** (`top_scores_fetched(entries, success)`). Divergence assumée : la
cohérence à l'intérieur du fichier neuf a été préférée à la cohérence avec un
voisin à deux signaux, et `Leaderboard.gd` n'est pas touché par ce lot.

### Le contrat de robustesse est celui de `Leaderboard.gd`, copié dans l'ORDRE

1. **Court-circuit headless EN PREMIER**, dans `_ready()` :
   `DisplayServer.get_name() == "headless"` → `network_enabled = false`.
   Même détection, même raison — toute sonde de `scripts/dev/` est couverte
   automatiquement, y compris une sonde future qui n'aurait rien à
   désactiver.
2. **Jamais de crash, toujours un signal, exactement UN par appel.**
3. **Un argument refusé échoue LOCALEMENT**, avant toute socket.

⚠️ **Conséquence vérifiée et non supposée : aucun tirage RNG n'a lieu sous une
sonde.** `_generate_auto_id()` consomme `randi()` — mais il est appelé
**après** le gate sur TOUS les chemins, donc sous `--headless` il n'est jamais
atteint. C'est ce qui permet aux sondes seedées de rester byte-identiques
malgré un autoload de plus dans chaque arbre.

### ⚠️ L'AUTH EST OBLIGATOIRE ICI, contrairement à `Leaderboard.gd`

`Leaderboard.gd` envoie le bearer « quand il est disponible, jamais exigé »,
parce que les rules `/scores` acceptaient l'anonyme. Les rules Quizz gatent
`signedIn()` sur **read, create, update ET delete**, des deux côtés : une
requête sans bearer est un **403 garanti**.

Ce fichier refuse donc de dépenser un aller-retour pour un refus certain :
chaque point d'entrée exige **les DEUX moitiés** — un utilisateur signé ET un
token non vide — et émet `error = "auth-required"` immédiatement sinon, sans
jamais construire de requête. Les deux moitiés sont testées **séparément et
pas ensemble** parce qu'`Auth` publie l'uid **avant** le token : un simple
`is_signed_in()` laisserait passer un bearer VIDE, que Google répond en 401 au
lieu d'un refus de rule. **Mesuré** (phase B de la sonde jetable) : uid posé,
token vide → `auth-required`, **zéro requête construite**.

Le token est relu **à chaque départ de requête**, jamais mis en cache — ce lot
est posé sur le fix `onIdTokenChanged` du même jour, et c'est lui qui rend
cette lecture utile : avant lui le token détenu était figé à la connexion et
expirait au bout d'une heure. Un éditeur de questionnaire écrit en continu, là
où Keepy Chased écrit une fois par run — le point 4 du « Reste ouvert » de la
section durcissement, corrigé la veille au soir, était donc bien un
prérequis de celui-ci.

### Les pièges REST de `QUIZZ_SPEC.md` §8, un par un

- **CREATE** : `:commit`, `currentDocument: {exists: false}`, **DEUX**
  `updateTransforms` (`createdAt` ET `updatedAt`, `setToServerValue:
  REQUEST_TIME`). Les rules exigent l'égalité avec `request.time`, qu'un
  littéral client ne peut pas satisfaire.
- **UPDATE** : `updateMask.fieldPaths` **exactement égal aux clés envoyées** —
  ni plus (une clé masquée mais absente des `fields` serait **SUPPRIMÉE**), ni
  moins. `uid` et `createdAt` ne sont **ni envoyés ni masqués** : les rules
  comparent le document RÉSULTANT au stocké, et un champ hors masque est
  préservé tel quel, donc les omettre satisfait l'immuabilité.
- **LISTE** : `fieldFilter uid EQUAL <mon uid>` sur les deux listes, sans
  exception. Firestore n'exécute que les requêtes qu'il peut PROUVER conformes
  à une règle owner-only — une liste non filtrée est **REFUSÉE**, pas vide.
- **UNE SEULE requête en vol** : un `HTTPRequest`, une **file FIFO**, un slot
  in-flight. Huit opérations sur deux collections rendaient le motif
  « un nœud par endpoint » de `Leaderboard.gd` intenable (huit nœuds, et
  toujours pas deux `create` d'affilée). **Rien n'est jamais perdu en
  silence** : un appel fait pendant qu'un autre est en vol est mis en file et
  parti au moment où le slot se libère ; et un appel en file dont la session
  a expiré entre-temps **échoue avec son propre signal** au lieu d'être jeté.

⚠️ **`type` EST envoyé sur `update_question` alors qu'il est immuable, et
c'est délibéré.** Une valeur égale satisfait la règle d'immuabilité ; une
valeur qui NE correspond PAS au document stocké est alors refusée sur cette
règle précise, au lieu de produire un échec `hasOnly` déroutant causé par les
champs de l'ancien type survivant hors du masque à côté de ceux du nouveau.

### Deux décisions de tri qui ne se ressemblent pas — et c'est mesuré, pas incohérent

- **`list_own_quizzes()` trie CÔTÉ SERVEUR** (`updatedAt DESCENDING`), comme
  le §8 le prescrit. ⚠️ **Cela exige un INDEX COMPOSITE `uid ASC` +
  `updatedAt DESC` sur `quizzes`, et sa création est une ACTION MANUELLE en
  Console Firebase** — une égalité combinée à un `orderBy` sur un autre champ
  n'est servie par aucun index à champ unique. Tant qu'il n'existe pas,
  Firestore répond **400 FAILED_PRECONDITION** avec un message contenant une
  **URL de console prête à l'emploi**. Ce message est transmis **VERBATIM**
  sur l'argument `error` de `quizzes_fetched` — donc l'URL survit jusqu'à
  l'appelant au lieu d'être avalée. **Aucun repli, aucun retry** : retomber
  en silence sur une requête non triée masquerait un index manquant derrière
  un autre jeu de résultats.
- **`list_questions()` ne trie PAS côté serveur, et c'est le choix le plus
  correct des deux.** Les rules déployées disent elles-mêmes qu'`order` n'est
  **ni unique ni contigu** et que le tri d'affichage doit être **(order,
  questionId)** — une égalité de rang qu'un `orderBy` Firestore sur `order`
  seul ne sait pas exprimer. Le tri est donc fait ici, sur (order, id), ce qui
  a un second effet : la requête reste sur l'index à champ unique `uid` et
  **n'a besoin d'AUCUN index composite**, donc elle marche le jour où elle
  tourne pour la première fois. Le jeu est plafonné à quelques dizaines de
  documents, le tri local ne coûte rien.

### Conventions figées par ce fichier

- **Les clés du `payload` d'entrée et des dictionnaires décodés sont les noms
  de champs Firestore VERBATIM** (`prompt`, `order`, `choice0..3`,
  `answerIndex`, `answerBool`, `answerText`, `title`, `visibility`,
  `questionCount`, `createdAt`, `updatedAt`), plus `id` pour l'identifiant de
  document. Ce qu'on lit est ce qu'on écrit : **aucune table de traduction à
  se tromper**.
- **`visibility` n'est PAS un paramètre.** Un argument suggérerait qu'un
  appelant peut en choisir un autre ; seul `'private'` existe, et c'est une
  décision actée (§2.3), pas un défaut modifiable.
- **`questionCount` est écrit à 0 à la création**, bien que les rules le
  rendent optionnel : un compteur présent dès le départ fait d'`update_quiz`
  une écriture de champ ordinaire au lieu d'une branche créer-ou-modifier. Il
  reste une valeur **d'AFFICHAGE** — rien ne le réconcilie jamais avec la
  réalité, les rules ne savent pas compter une sous-collection.
- **`PROJECT_ID` et `API_KEY` sont LUS depuis `Leaderboard.gd`**, pas
  recopiés. Deux copies littérales d'une clé d'API sont un risque de rotation
  dont le mode de défaillance est un 403 silencieux dans le fichier qu'on a
  oublié. `_generate_auto_id()`, lui, **est** une copie locale de six lignes
  plutôt qu'un appel dans l'API privée du voisin — si l'un change, l'autre
  doit suivre.
- **La validation locale reflète les rules** (titre 1..60, énoncé 1..200,
  choix 1..120, `answerIndex` 0..3, `answerText` 1..120, `order` 0..199,
  `questionCount` 0..50, type dans les trois). Elle ne rend pas le serveur
  redondant — il reste l'autorité — elle transforme un 403 certain en échec
  local instantané portant un motif qu'une UI peut afficher.

⚠️ **Le plafond de 50 questions par quiz n'est PAS appliqué et ne PEUT pas
l'être ici** : ni ce fichier ni une rule ne sait compter la sous-collection
sans une liste, et un compte lu au moment de créer court après lui-même. Un
appelant qui y tient doit compter ce que `list_questions()` a rendu et refuser
localement. Même famille : **`delete_quiz()` n'est PAS une cascade** — les
questions survivent en orphelines, lisibles par leur seul propriétaire (coût
de stockage, pas de fuite). Pour les supprimer, il faut les lister et les
supprimer **avant** le parent.

### Mesure : sonde jetable, 108 assertions, ZÉRO octet sorti de la machine

`scripts/dev/QuizzContractProbe.tscn`, construite pour ce lot puis
**supprimée avant le commit** (`ProbeTimeoutAudit` revient donc à son chiffre
de baseline). **108 assertions, 0 échec, exit 0.** Elle pilote le VRAI
autoload — jamais un stub du fichier testé — sur six phases : court-circuit
headless, gate d'auth, **corps REST exacts** confrontés aux rules déployées,
file FIFO, validation locale, et réponses/décodage.

⚠️ **Piège d'outillage rencontré, à connaître avant de vouloir intercepter un
`HTTPRequest` dans ce dépôt : on NE PEUT PAS le stubber.** Une sous-classe
GDScript qui redéfinit `request()` est **refusée à la compilation** par Godot
4.3 (« overrides a method from native class », warning traité en erreur), et
même en la forçant, l'appel de `Quizz.gd` part en ptrcall natif parce que
`_http` est **typé statiquement** — le script n'est jamais atteint.
**Contournement retenu, qui s'est révélé meilleur que le stub** : une
opération est **entièrement construite dans `_queue` AVANT que `_pump()` ne
l'envoie**, donc occuper le slot in-flight avec une sentinelle suffit à lire
l'url, la méthode et le corps exacts de chaque appel, sans transport du tout.
La file, la complétion et le décodage sont ensuite exercés en appelant
directement `_pump()`, `_on_request_completed()` et `_dispatch()`. **Aucun
octet n'est jamais parti vers Firestore**, et c'est bien le code livré qui est
mesuré.

**Ce que la sonde a trouvé et qui a été corrigé** : sur un échec de transport
(hors ligne, DNS, connexion refusée) le corps de réponse est **vide**, et le
donner à `JSON.parse_string` faisait imprimer au moteur sa propre ligne
`ERROR: Parse JSON failed` — une entrée stderr alarmante pour l'échec le plus
ordinaire de ce fichier. `_error_text()` ne tente désormais le parse que si le
corps commence par `{`. Trouvé par la mesure, pas par relecture.

### Sondes : AUCUNE n'est affectée, vérifié plutôt que supposé

**Non-applicabilité vérifiée par `grep`, pas supposée** : aucune sonde de
`scripts/dev/` ne référence `Quizz`, et aucune ne charge `run/main_scene`
(chacune lance sa propre `.tscn`). Le seul effet possible d'un autoload de
plus est structurel : un nœud de plus dans chaque arbre de sonde, plus son
`HTTPRequest` enfant. Et il ne consomme **aucun tirage RNG** (voir plus haut),
donc les flux seedés ne peuvent pas se décaler.

**Mesuré quand même, contre `origin/staging` en worktree séparé, sur l'arbre
FINAL du lot** (graine 20260806, `--fixed-fps 60`) :

| sonde | verdict | diff contre `origin/staging` |
|---|---|---|
| `ProbeTimeoutAudit` | exit 0, **33 sondes** (retour exact à la baseline après retrait de la sonde jetable) | **byte-identique** |
| `AssetContractAudit` | exit 0, 12/12 visuels, **0/10 colliders déplacés** | **byte-identique** |
| `DeathModelAudit` | exit 0 | **byte-identique** |
| `ChargerShapeProbe` | exit 0 | **byte-identique** |
| `AlarmRampAudit` | exit 0 | **byte-identique** |
| `ComboAudit` (seedée) | exit 0 | **byte-identique** |
| `ShrinkAudit` (seedée) | exit 0 | **byte-identique** |

**Sept sondes, byte-identiques sur les DEUX flux (stdout ET stderr), exit 0
des deux côtés.** C'est le bar attendu pour un lot qui n'ajoute qu'un autoload
inerte sous sonde, et l'identité au bit près le dit plus fort qu'un simple
verdict identique.

### Build

Éditeur + templates Godot 4.3-stable installés dans ce sandbox pour ce lot
(releases GitHub officielles, mêmes que la CI). Import headless **exit 0**,
export Web release **exit 0**. `index.wasm` **35 376 909 octets**, md5
`af4a8fc2925d992348eb30deeeb54360` — **identique au fingerprint déjà consigné**
pour tout lot qui ne touche pas le code moteur. `Quizz.gdc` est bien compilé
dans le `.pck` à côté de `Auth.gdc` / `Leaderboard.gdc` / `GameState.gdc`
(donc l'autoload est réellement enregistré, pas seulement écrit).
`index.pck` 5 467 616 octets — export unique et propre (`build/` supprimé
avant ET après), à lire avec la mise en garde permanente sur l'instabilité du
`.pck`. Piège payload re-vérifié sur le log `savepack` : **0** ligne
`Storing File: res://assets_source`.

### ⚠️ CE QUI N'A PAS ÉTÉ MESURÉ — la limite honnête de ce lot

**Aucune requête n'a jamais atteint Firestore.** Ni depuis ce sandbox (pas
d'idToken Google réel, et la fabrication d'un compte de test a déjà été
refusée dans une session précédente), ni ailleurs. Tout ce qui précède prouve
que le client construit **exactement** ce que les rules déployées décrivent,
**pas** que le serveur l'accepte. Les points suivants restent donc de la
théorie tant qu'un écran ne les exerce pas pour de vrai :

1. **L'INDEX COMPOSITE `uid ASC` + `updatedAt DESC` sur `quizzes` n'existe
   pas** (rien dans ce dépôt ne le crée, `firebase.json` ne déclare aucun
   `firestore.indexes.json`). **`list_own_quizzes()` échouera donc au premier
   appel réel**, en 400 FAILED_PRECONDITION — c'est **attendu**, pas un bug à
   chercher. L'`error` du signal portera l'URL de console à cliquer.
   **ACTION MANUELLE de Mathieu**, ou — meilleure place le jour venu, et
   délibérément HORS PÉRIMÈTRE ici parce que ça déploierait sur le projet
   global — ajouter `"indexes": "firestore.indexes.json"` à `firebase.json`
   pour que `firestore-rules.yml` devienne aussi le chemin de déploiement des
   index.
2. **La première écriture réelle** (create d'un quiz, create d'une question)
   n'a jamais été tentée contre le service.
3. **Le rafraîchissement du token en session longue** : le fix
   `onIdTokenChanged` est validé sur device pour Keepy Chased, pas pour une
   session d'authoring de plus d'une heure.

### Où une future session reprend

- **Rien n'appelle `Quizz.gd`.** Les écrans du §7 de `docs/QUIZZ_SPEC.md`
  restent à écrire (liste de mes quiz, éditeur de quiz, éditeur de question),
  ainsi que l'hôte unique + panneaux par format tranché au §10.2.
- **Le branchement du bouton du hub** est décrit au §7.1 de
  `docs/QUIZZ_SPEC.md` : retirer `disabled = true` de `QuizzButton` dans
  `scenes/Hub.tscn`, connecter son `pressed`, et **retirer l'assertion de
  `Hub._ready()`** qui `push_error` si ce `disabled` disparaît — elle existe
  pour qu'un bouton réactivé mais non connecté ne puisse pas passer inaperçu,
  donc son retrait fait partie du branchement, pas d'un lot de nettoyage.
- **Le §10.3 reste ouvert** (correction de la réponse libre : comparaison
  exacte après normalisation ? variantes acceptées ?) et il faudra le trancher
  avant d'écrire l'écran de jeu du format `free`, pas pendant.

## `QuizzHomeScreen.tscn` : PREMIER ÉCRAN RÉEL exercant `Quizz.gd` — créer + lister, rien d'autre (18 août 2026)

Branche `claude/quiz-home-screen-t8dt2w`, redémarrée sur `origin/staging`
(`6c72dbc`) — la branche pointait encore sur `main`, sans `Quizz.gd`. Trois
fichiers touchés : `scenes/QuizzHomeScreen.tscn` + `scripts/ui/
QuizzHomeScreen.gd` (nouveaux), `scenes/Hub.tscn` + `scripts/ui/Hub.gd`
(bouton Quizz activé). **Périmètre volontairement étroit, comme demandé** :
créer un quiz par titre, lister les siens. Pas d'édition de questions, pas de
jeu — juste de quoi prouver que la fondation `Quizz.gd` marche contre
Firestore, chose que la section précédente de ce fichier note explicitement
n'avoir **jamais** été exercée en conditions réelles.

### Un seul écran, pas les quatre du §7 de `docs/QUIZZ_SPEC.md`

Le tableau du §7 prévoit `QuizzMenuScreen` / `QuizzListScreen` / `QuizzEditorScreen`
/ `QuestionEditorScreen` séparés. Ce lot en livre UN, `QuizzHomeScreen.tscn`,
qui fait le travail de `QuizzMenuScreen` + `QuizzListScreen` réunis — création
et liste sur le même écran, un champ + un bouton au-dessus d'une liste. C'est
un écart assumé au tableau, pas une relecture de la décision d'hôte
unique/panneaux par format du §10.2 (qui concerne l'écran de JEU, pas
l'authoring) : le brief de ce lot demandait explicitement « juste de quoi
valider que la fondation Quizz.gd fonctionne », et un écran de moins à router
pour une validation de fondation est le bon niveau d'effort. `QuizzMenuScreen`/
`QuizzListScreen` restent des noms disponibles pour une session future qui
voudrait les séparer une fois l'édition de questions justifiant un vrai menu.

Chemin de navigation, remplace la ligne « DESACTIVE » du §7.1 :

```
res://scenes/Hub.tscn
        └── "Keepy Quizz" -> res://scenes/QuizzHomeScreen.tscn   <-- NOUVEAU
                └── "<" (BackButton) -> res://scenes/Hub.tscn
```

### Le bouton Quizz du hub est ACTIF — la garde `push_error` est retirée

Exactement les trois étapes que le §7.1 avait préparées : `disabled = true`
retiré de `QuizzButton` dans `Hub.tscn` (il reprend le style bouton actif de
`ChasedButton`, `StyleBoxFlat_button_disabled` devenu inutilisé est supprimé
du fichier — `load_steps` ajusté de 8 à 7) ; `QuizzCaption` passe de
« Bientot disponible » à « Cree et gere tes questionnaires » ; `Hub._ready()`
connecte `quizz_button.pressed` vers `change_scene_to_file(QUIZZ_SCENE)`, sur
le modèle exact de `_on_chased_pressed()`. **La garde `push_error` qui
existait pour qu'un bouton réactivé sans être connecté ne parte pas en
production comme un contrôle mort est retirée** — elle n'a plus lieu d'être
puisque le bouton est désormais réellement connecté, exactement comme sa
propre doc l'annonçait.

### Comportement attendu au tout premier lancement : index Firestore manquant

`Quizz.list_own_quizzes()` documente déjà, dans son propre commentaire, que la
requête `uid EQUAL` + `orderBy updatedAt DESC` a besoin d'un index composite
qui n'a jamais été créé (aucune écriture réelle n'a encore eu lieu contre
`quizzes`), et que Firestore répond alors `400 FAILED_PRECONDITION` avec un
message portant une URL Console toute prête, transmise **verbatim** sur
l'argument `error` du signal `quizzes_fetched`. **Ce lot est le premier code
qui affiche cette réponse au joueur plutôt que de la traiter comme une panne
générique.**

`_show_error()` détecte ce cas précis (`error.contains("FAILED_PRECONDITION")`
ET une sous-chaîne `https://` présente), extrait tout ce qui suit le premier
`https://` (l'URL Firestore ne contient pas d'espace, elle est déjà encodée —
rien à chercher comme délimiteur de fin), et affiche un panneau dédié (fond
ambre, distinct visuellement du message d'échec générique) avec l'URL posée
dans un `LineEdit` non-éditable (`editable = false`, pour ne jamais déclencher
le clavier virtuel mobile au tap — piège déjà documenté ailleurs dans ce
fichier pour le clavier iOS) plus un bouton « Copier le lien »
(`DisplayServer.clipboard_set()`). **Toute autre erreur** — hors ligne,
`auth-required`, un vrai refus serveur — reste un message d'échec standard,
même registre que `LoginScreen._message_for()` : le texte générique plus le
détail brut entre parenthèses, jamais masqué.

⚠️ **Ce chemin n'a PAS pu être exercé contre le vrai service Firestore depuis
ce sandbox** — aucun idToken Google n'y est disponible (même limite déjà
consignée pour les lots rules précédents), donc ni la création d'un quiz ni
le premier `list_own_quizzes()` réel n'ont pu être tentés ici. La détection
d'erreur et l'extraction d'URL sont vérifiées par une sonde jetable (ci-dessous)
qui rejoue le message Firestore EXACT documenté par `Quizz.gd`
(`"result=0 code=400 FAILED_PRECONDITION: ... You can create it here:
https://console.firebase.google.com/v1/r/project/keepy-8df91/firestore/
indexes?create_composite=..."`), pas contre une vraie réponse capturée en
direct. **Jugement device pour la première création réelle**, qui devra
suivre ce lien une fois, comme prévu depuis l'écriture de `Quizz.gd`.

### État de chargement, cohérent avec `LoginScreen`/`Hub`

`_set_busy()` désactive le bouton Créer et le champ de titre pendant un appel
en vol, et bascule le texte de statut entre « Chargement... » / « Creation... »
— même registre texte-only que `LoginScreen._refresh_from_auth()`, pas de
spinner ni d'overlay supplémentaire. Une création réussie vide le champ de
titre puis **relance une vraie liste** plutôt que d'insérer une ligne devinée
localement : l'ordre et la date affichés viennent toujours du serveur, jamais
d'une hypothèse faite ici — la même discipline que `Quizz.gd` applique déjà à
ses propres réponses.

### Formatage de date : `updatedAt` (RFC3339) → `JJ/MM/AAAA HH:MM`

`Time.get_datetime_dict_from_datetime_string()` ne comprend que les secondes
entières ; la fraction de seconde et le `Z` final du timestamp Firestore sont
retirés avant l'appel. **Mesuré, pas supposé** : une chaîne imparsable ne
renvoie pas un dictionnaire vide mais un dictionnaire à zéro partout — c'est
donc `year == 0` qui sert de détecteur d'échec plutôt qu'un test
`is_empty()`, avec la chaîne brute affichée en repli plutôt qu'un
« 00/00/0000 » absurde sur le seul champ qu'un joueur ne peut pas
interpréter lui-même.

### Sondes headless : aucune affectée, vérifié par grep et par exécution

`grep` sur `scripts/dev/` : **aucune sonde ne référence `QuizzHomeScreen.tscn`,
`Hub.tscn` ni `LoginScreen.tscn`** — chacune lance sa propre scène et
contourne `run/main_scene` par construction, même constat déjà fait aux deux
lots hub/token précédents. `ProbeTimeoutAudit` (**33 sondes, toutes armées**),
`AssetContractAudit` (12/12 visuels, 0/10 colliders déplacés), `DeathModelAudit`
(CHARGER seul fatal, capture au 2ᵉ contact), `ChargerShapeProbe` — **rejouées
dans ce sandbox, toutes exit 0**, aucune ligne stderr nouvelle hors celle déjà
documentée (`Parameter "m" is null` sur `DeathModelAudit`, pré-existante).

Une sonde jetable (`scripts/dev/QuizzHomeScreenProbe.tscn`, jamais commitée,
supprimée avant ce commit) a instancié l'écran réel et appelé ses handlers
avec des payloads synthétiques : détection FAILED_PRECONDITION + extraction
d'URL, non-déclenchement du panneau index sur une erreur non liée, peuplement
de la liste (2 lignes, dates formatées), état vide, et vidage du champ de
titre après une création réussie — **toutes les assertions passent**.

### Validation build

Éditeur + templates Godot 4.3-stable installés dans ce sandbox pour ce lot
(releases GitHub officielles). Import headless **exit 0**, export Web release
**exit 0**, aucune ligne d'erreur dans les deux logs. `index.wasm`
**35 376 909 octets** — identique au fingerprint déjà consigné pour tout lot
qui ne touche pas le code moteur, cohérent : ce lot n'ajoute que deux scènes
UI et modifie deux fichiers UI existants, aucun script `autoload` ni
`project.godot` (au-delà de l'autoload `Quizz` déjà enregistré par le lot
précédent).

### Reste ouvert — jugement device, seul juge

1. **La toute première création réelle** sur `keepy-staging.vercel.app` :
   doit produire soit un quiz qui apparaît dans la liste (si l'index existe
   déjà), soit le panneau d'index avec un lien qui, une fois ouvert et
   confirmé en Console, débloque la liste au rafraîchissement suivant. Aucune
   des deux branches n'a pu être vue tourner contre le vrai service depuis ce
   sandbox.
2. Lisibilité de l'écran à l'échelle réelle d'un téléphone (le panneau
   d'index, en particulier — jamais vu rendu ailleurs que dans une sonde
   headless).
3. Tout le reste du §7 (édition de questions, jeu) reste à écrire, inchangé
   par ce lot.

`main` n'est **pas** touché : palier 1 seulement (merge automatique sur
`staging`, build/export/sondes verts) ; palier 2 reste gaté par Mathieu après
validation device.

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

## KEEPY BATTLE, LOT 1 : squelette jouable d'un duel 1v1, ZERO asset 3D (20 aout 2026)

Branche `claude/keepy-battle-lot-1-1yys5r`, partie de `staging` (`8272dfa`,
ou `main` et `staging` etaient alignes). **Troisieme mini-jeu du hub**, apres
Chased et Quizz. Aucun fichier de Chased ni de Quizz touche : le seul fichier
existant modifie est le Hub (plus sa `.tscn`), qui gagne une troisieme carte.

**Le but de ce lot est de valider le FEEL et l'EQUILIBRAGE AVANT de depenser
un credit Meshy** : deux capsules placeholder, rien d'autre. Les assets 3D,
les animations, les sons, la persistance Firestore, la progression, plusieurs
adversaires et les effets visuels sont HORS PERIMETRE et non faits.

### Le contrat "et dans 6 mois ?" : un adversaire = UN .tres + UN .glb, ZERO ligne de code

C'est la contrainte structurante du lot, pas un objectif de style.

* **`FighterProfile`** (`scripts/battle/FighterProfile.gd`, une `Resource`)
  porte **tout** ce qui differe entre deux combattants : hp, timings
  windup/active/recovery par action, degats, ratio de garde, duree de
  stagger, les cinq parametres d'IA, et le `.glb` futur avec ses trois
  corrections `ModelSlot` (`model_scale`, `model_rotation_degrees`,
  `model_offset`) plus la couleur du placeholder.
* **`Fighter.gd` et `FighterBrain.gd` sont GENERIQUES** : aucun `match
  species`, aucune sous-classe par animal, nulle part. Deux profils livres,
  `resources/battle/keepy.tres` et `dummy.tres` ; ils ne different que par
  des nombres.
* **Le `match` de `FighterProfile.timing_for()` est le SEUL endroit du depot
  qui associe une action a ses nombres**, et il pointe vers des CHAMPS, pas
  vers des valeurs. Une quatrieme action toucherait cette fonction et les
  exports au-dessus, rien d'autre.

### UNE seule FSM, partagee joueur et IA -- ce n'est pas une preference de style

Etats : `IDLE / WINDUP / ACTIVE / RECOVERY / STAGGER / KO`. Il n'y a pas de
"fighter joueur" et pas de "fighter IA" : il y a un `Fighter`, et quelque
chose qui appelle `request_action()` dessus. Le tap humain (les trois zones
du HUD) et le selecteur d'intention (`FighterBrain`) entrent par **la meme
fonction** et sont indiscernables ensuite.

⚠️ **La raison est un mode de panne, pas de l'elegance** : une IA qui fait
tourner son propre systeme avec ses propres timings est une IA qu'on peut
equilibrer contre des regles que le joueur ne joue pas, et la divergence
reste invisible jusqu'a ce que quelqu'un la mesure -- exactement le defaut
`SubstituteModel.tscn` deja consigne dans ce fichier. **PHASE E de la sonde
pointe le brain sur le fighter du JOUEUR et exige un vrai combat**, donc la
reciprocite est exercee et pas affirmee.

### Determinisme : ticks fixes accumules, RNG seede explicitement

`BattleArena` avance les deux fighters ET le brain par pas entiers de
`TICK_S = 1/60`, sortis d'un accumulateur -- jamais le `delta` brut de la
frame. Sur telephone le temps de frame est ce que le navigateur veut bien
donner, et une FSM avancee par ce delta a des frontieres de phase qui
tombent sur des frames differentes d'un run a l'autre : deux combats
identiques divergent, et « est-ce que cet enchainement est vraiment
imparable ou est-ce que j'ai eu une frame longue » devient sans reponse.

⚠️ **`_physics_process` donnerait aussi un pas fixe et a ete ECARTE** : il
lie le rythme du combat a un reglage projet qui appartient a Chased, donc un
changement la-bas re-equilibrerait ce jeu en silence.

**Aucun `randi()` global nulle part dans `scripts/battle/`** : un seul
`RandomNumberGenerator`, seede `base_seed + numero de round`.

⚠️ **`BattleArena` parse `--seed=` EN LIGNE au lieu d'appeler
`DevSeed.seed_value()`, qui fait exactement ca -- piege trouve en ecrivant
le lot, pas apres coup.** `export_presets.cfg` porte `scripts/dev/*` dans
son `exclude_filter`, donc `DevSeed` **n'est pas dans le pack livre**. Une
reference `class_name` depuis un script livre resout dans l'editeur ET en
headless, puis echoue **uniquement dans le build web** -- le seul endroit
que personne ne peut verifier. Verifie sur le `.pck` exporte : les deux
seules occurrences de `DevSeed` y sont dans le cache de classes globales
(qui liste deja d'autres classes `dev` sur `main` aujourd'hui), aucune
depuis `scripts/battle/`.

### Resolution des coups : du timing pur, aucune hitbox 3D

Un coup se resout UNE fois, au premier tick de la fenetre `ACTIVE` de
l'attaquant, contre l'etat du defenseur a cet instant :

| defenseur | resultat |
|---|---|
| `GUARD` en `ACTIVE` | **BLOQUE** : degats x `guard_damage_ratio` (0,25), **pas de stagger** |
| `DODGE` en `ACTIVE` | **ESQUIVE** : zero degat |
| tout le reste, **y compris `ATTACK` en `ACTIVE`** | **TOUCHE** : degats pleins + stagger |

La derniere ligne est la regle qui empeche les deux combattants de simplement
marteler l'attaque : **les frames actives d'une attaque ne defendent pas**,
donc celui qui s'engage en second encaisse l'echange. Le stagger (0,55 s) est
plus long que n'importe quelle recovery : etre touche DOIT etre pire que
rater.

La resolution vit dans `BattleArena`, **une seule fois** : un `Fighter`
annonce `strike_activated` et ne sait rien de qui est en face. Aucun des deux
ne detient de reference vers l'autre.

### Controles : TAP UNIQUEMENT, trois zones fixes, aucun geste

Trois boutons larges en bas d'ecran, rien d'autre. **Pas de swipe**, pour
deux raisons independantes : Chased possede deja le swipe comme geste de
changement de voie, donc le meme mouvement voudrait dire deux choses dans une
seule app ; et un swipe horizontal sur iOS Safari est en concurrence avec la
navigation arriere du navigateur, ce qu'une page ne gagne pas de facon fiable.

⚠️ **Les boutons restent ACTIFS pendant un engagement** au lieu de se griser :
`Fighter` bufferise un tap anticipe pendant `INPUT_BUFFER_S` (0,16 s) et le
rejoue au retour a `IDLE`, donc un tap « trop tot » est un input reel qui
fonctionne. Le griser jetterait une pression que le jeu allait honorer, et
ferait clignoter le panneau plusieurs fois par seconde.

`INPUT_BUFFER_S` est une constante de JEU et **deliberement pas un export par
profil** : c'est une propriete des controles, identique pour tout le monde ;
laisser deux combattants ne pas etre d'accord dessus serait deux jeux.

### Le point d'echange lot 3 est deja ecrit

Chaque fighter porte un noeud `Body` de type **`ModelSlot`**
(`scripts/world/ModelSlot.gd`), exactement comme `$Silhouette` de
`Pursuer.tscn`. Installer un `.glb` au lot 3 = poser `model_scene` (+ les
trois corrections) **dans le `.tres`**. Aucun noeud n'est ajoute, deplace,
renomme ni supprime, donc rien dans `Fighter.gd`, `BattleArena.gd` ou le HUD
n'a a etre re-pointe. `Fighter._apply_profile_art()` est le hand-off complet
et il est deja la.

⚠️ **Le tint du placeholder et l'install du `.glb` passent par le MEME chemin
de code** (`ModelSlot.apply_material()`, qui atteint les surfaces du modele
installe une fois qu'il existe) : un futur `.glb` herite du traitement
couleur du profil au lieu d'avoir besoin d'une seconde branche que personne
n'exerce. Materiaux **unshaded**, comme toute surface de ce projet.

### `SafeArea.fill_screen()` ici, `keep_game_framing()` chez Chased

Battle appelle `fill_screen()` comme les ecrans d'UI. Contrairement a
`Game.tscn` -- qui redemande `KEEP` parce que le budget de reaction de Chased
est cale sur un cadrage 9:16 -- Battle n'a **aucun monde defilant et aucun
budget lie a la distance** : les deux combattants sont a des marques fixes,
donc un viewport plus haut montre plus de ciel vide et ne change rien de
jouable.

⚠️ **La camera est en `keep_aspect = KEEP_WIDTH` (0), et c'est OBLIGATOIRE
ici, pas cosmetique.** En `KEEP_HEIGHT` (le defaut), le viewport plus haut
que produit `fill_screen()` **retrecit l'etendue horizontale** et les deux
combattants sortaient du cadre par les cotes. **Mesure sur la scene
construite, aux deux ratios** : etendue horizontale **identique** a 1080x1920
et 1170x2532 (x 95..985 des deux cotes), combattants degages de la barre du
haut ET de la rangee de boutons. Panneau du Hub a trois cartes : les trois
boutons a l'ecran, marge basse **128 px** en 9:16 et **228 px** sur device.

### La sonde a trouve un defaut REEL de mesure -- dans la sonde, pas dans le jeu

`scripts/dev/BattleContractProbe.tscn` (nouvelle, **36 checks, 0 echec**)
gate l'ordre et la duree des phases, la matrice de resolution complete, le
buffer d'input, et le determinisme. Elle pilote les **scripts livres**,
jamais un stub.

⚠️ **PHASE F a d'abord rapporte « le profil Keepy perd 40 fois sur 40 », et
ce chiffre ne mesurait PAS un desequilibre.** Elle ne faisait tourner un
brain que du cote adversaire -- fidele a l'arene reelle, ou l'autre cote est
un humain -- donc le fighter Keepy **ne faisait rien du tout** : un sac de
frappe immobile perd. Un chiffre profil-contre-profil demande les deux cotes
joues (`mirrored`). **Un balayage jetable a ete ecrit pour trancher plutot
que de raisonner** : a profils symetriques le resultat est ~30/60 (equilibre),
et une reaction ou un windup plus rapides **GAGNENT** (54/60, 53/60) --
l'inverse de l'hypothese de depart, qui etait que s'engager en premier
punissait. La sonde a ete corrigee, le balayage supprime avant commit.

⚠️ **Deuxieme correction dans la sonde, meme famille** : l'assertion de duree
par phase comparait a `ceil(secondes / tick)` et ignorait le report
d'overshoot que `Fighter.advance()` fait DELIBEREMENT d'une phase a la
suivante. Sans ce report chaque phase arrondirait vers le HAUT et une action
a trois phases durerait jusqu'a trois ticks de trop, differemment selon le
combattant. **L'assertion exacte porte donc sur le TOTAL** (47 ticks pour
47 nominaux) et laisse **un tick** de jeu par phase, borne parce que le
report est reapplique a chaque transition et ne s'accumule jamais.

### Equilibrage mesure, pas ressenti -- et volontairement NON gate

Trois iterations, chacune remesurees sur 40 combats seedes :

| | hp | resultat |
|---|---|---|
| depart | 100 | rounds **30,1 s** de moyenne -- trop long pour du mobile |
| apres reduction hp + resserrage du profil adverse | 60 | 39/40, **walkover** |
| **livre** | **50** | **31/40 (~78 %), moyenne 16,1 s** (min 8,0 / max 32,9) |

**PHASE F rapporte et n'asserte RIEN**, deliberement : ce qu'est un combat
juste est un jugement device, et un nombre gate ici serait un nombre regle
jusqu'a ce qu'il passe au vert -- le faux-vert que `ProbeCoverage.gd`
documente cinq fois. Retoucher l'equilibrage est une edition de `.tres`.

### Validation

Editeur + templates Godot 4.3-stable installes dans ce sandbox (releases
GitHub officielles ; taille confirmee contre le `Content-Length`, le piege de
troncature silencieuse deja consigne). Import headless **exit 0**, export Web
release **exit 0**, boot headless de `Battle.tscn` / `BattleHUD.tscn` /
`BattleFighter.tscn` / `Hub.tscn` (`--quit-after 2`) **tous exit 0**, aucune
erreur de parse. `index.wasm` **35 376 909 octets** -- identique au
fingerprint deja consigne pour tout lot qui ne touche pas le code moteur.
`index.pck` 5 740 640 octets (export unique et propre, `build/` supprime
avant -- a lire avec la mise en garde permanente sur son instabilite).

Sondes : `BattleContractProbe` (**36/36**), `ProbeTimeoutAudit` (**34 sondes
scenes**, la nouvelle comprise, toutes armees -- 33 avant ce lot),
`AssetContractAudit` (12/12 visuels, **0/10 colliders deplaces**),
`DeathModelAudit`, `ChargerShapeProbe` -- **toutes exit 0**. Piege payload
tenu : **0** ligne `Storing File` pour `res://scripts/dev`, `res://assets_source`,
`res://docs` ou `res://web`.

### Dette et reste ouvert

1. **Jugement device, et c'est tout l'objet du lot** : est-ce que le duel se
   lit et se joue bien au pouce sur un telephone -- lisibilite des trois
   zones, longueur des rounds, et surtout **si le windup de l'adversaire est
   assez telegraphie pour etre lu**. Aucune sonde ne le dit.
2. **DETTE ASSUMEE : les combattants ne bougent pas.** Le retour d'etat est
   porte **entierement par le HUD** (libelle d'etat par combattant + verdict
   du coup) ; les capsules sont statiques. Les effets visuels sont hors
   perimetre de ce lot, mais c'est le manque le plus probable a remonter du
   test device -- un `WINDUP` sans mouvement se lit mal a vitesse reelle. Le
   correctif naturel (une amorce de fente sur `WINDUP`/`ACTIVE`) appartient
   au lot animation, pas a une rustine ici.
3. **Un seul adversaire**, `dummy.tres`, nomme « Sparring ». Le second est un
   `.tres` de plus ; il n'y a pas d'ecran de selection, et il n'y en avait pas
   dans le perimetre.
4. **Aucune persistance** : ni score, ni progression, ni Firestore. Un round
   perdu ou gagne ne laisse aucune trace.
5. **`ai_defense_rate` est le vrai bouton de difficulte**, plus que les
   degats : le balayage montre la duree moyenne d'un round passer de 25 s a
   44 s quand il va de 0,0 a 0,8, a profils par ailleurs identiques.

## KEEPY BATTLE, LOT 2 : rendre le combat LISIBLE, toujours ZERO asset 3D (20 aout 2026)

Branche `claude/keepy-battle-readability-erclyi`, partie de `staging`
(`06c94f1`). Ferme la **dette 2 du lot 1** (« les combattants ne bougent
pas »), qui etait le blocage numero un remonte du test device. Toujours
aucun asset 3D : ce lot anime les capsules placeholder, et c'est
deliberement l'ordre choisi -- prouver qu'un duel de ce type se lit au
pouce AVANT de depenser un credit Meshy.

### Ce que la mesure a dit, et pourquoi les deux hypotheses de depart etaient a cote

Le brief posait deux hypotheses a departager par instrumentation. Aucune
des deux n'etait la bonne, et c'est le resultat le plus utile du lot.
Mesure headless sur les scripts LIVRES, avant d'ecrire une ligne :

| hypothese | verdict |
|---|---|
| **H1** le HUD ne s'abonne pas a `WINDUP` | **FAUX**. Il s'y abonne, et il l'affiche : sequence `Attaque - Prepare` -> `Attaque - Actif` -> `Attaque - Recupere` -> `Pret`, avec **19 ticks = 317 ms** passes sur « Prepare ». Le libelle n'a jamais ete desynchronise. |
| **H2** le `WINDUP` est trop court pour etre lu | **FAUX tel quel**. 317 ms n'est pas un telegraphe court -- c'est un telegraphe **invisible** : rien sur les combattants ne bougeait a aucun moment de l'attaque. |

**Le defaut n'a jamais ete « le HUD est en retard ». Il etait que les
combattants etaient muets**, et qu'un libelle de 26 px en haut de l'ecran
ne sera jamais un telegraphe quand le regard est sur deux capsules au
milieu. C'est la conclusion qui a dicte tout le lot.

Les deux captures device s'expliquent alors exactement, et par des causes
DIFFERENTES l'une de l'autre :

* **« Sparring : TOUCHE » affiche pendant que Sparring dit « Pret »** :
  `FLASH_S` valait **700 ms**, alors qu'un attaquant reste engage
  `active + recovery` = **480 ms** (Keepy) / **540 ms** (Sparring) apres
  la resolution de son coup. Le verdict **survivait a l'action qui l'avait
  produit de 160 ms**. Ni l'un ni l'autre des deux affichages n'etait faux
  -- le verdict est un rapport RETARDE, le libelle d'etat un rapport
  INSTANTANE -- mais ensemble ils se contredisent et le joueur n'a aucun
  moyen de savoir lequel croire.
* **« Attaque - Actif » a l'ecran de KO** : un coup se resout dans le
  PREMIER tick `ACTIVE` de l'attaquant, donc le perdant tombe a 0 hp sur
  ce tick-la et `BattleArena` arrete l'horloge immediatement. La FSM du
  vainqueur est **reellement figee en `ACTIVE`** et n'en sortira jamais.
  Le libelle disait la verite sur une simulation arretee.

### Le telegraphe vit sur le combattant, dans `FighterView.gd`

Un noeud `View` par combattant, enfant direct du `Fighter` dans
`BattleFighter.tscn`. **Strictement en LECTURE SEULE sur la FSM** : il
n'appelle jamais `request_action()` ni `advance()`, n'ecrit aucun champ, et
ne lit un etat que pour choisir quelle animation jouer.

| etat | ce que le joueur voit |
|---|---|
| `IDLE` | respiration lente (bob 4,5 cm), pour qu'un ecran au repos ne soit jamais mort |
| `WINDUP` (attaque) | **recul progressif + teinte qui monte vers le rouge, sur TOUTE la duree de la phase** |
| `WINDUP` (garde/esquive) | meme amorce, 3x plus discrete, **et aucune teinte** |
| `ACTIVE` attaque | fente nette vers l'adversaire (60 ms) |
| `ACTIVE` garde | encaissement bas et large (`scale.y` 0,86) |
| `ACTIVE` esquive | glissade en arriere + inclinaison |
| `RECOVERY` | retour au neutre sur la duree REELLE de la phase, donc **toujours plus lent que la fente** |
| `STAGGER` | recul profond puis oscillation amortie |
| `KO` | bascule a -82 deg, corps pose au sol |
| impact | flash **sur le combattant TOUCHE** : blanc si `HIT`, bleu froid si `BLOCKED`, **rien si `DODGED`** |

⚠️ **La couleur ne veut dire QU'UNE chose : danger entrant.** Seul un
`WINDUP` d'ATTAQUE monte vers `ALERT_COLOR`, et **progressivement**, avec
un `EASE_IN` -- l'intensite EST l'horloge que le defenseur lit. Garde et
esquive se distinguent par la SILHOUETTE, jamais par la teinte. Un
telegraphe qui partage son canal avec deux actions inoffensives est un
telegraphe qu'il faut decoder au lieu de le voir.

### Pourquoi ca anime `$Body` (le `ModelSlot`) et jamais la geometrie de la capsule

Chaque tween ecrit `position` / `rotation_degrees` / `scale` **sur le
`ModelSlot`**, et la teinte passe par `ModelSlot.apply_material()`. C'est
le contrat deja etabli du projet (`Obstacle.gd` anime deja un slot de
cette facon), et c'est ce qui rend le **lot 4 gratuit** : un `.glb`
installe dans le slot est un ENFANT du noeud que ces tweens deplacent,
donc il herite de toutes les animations sans une ligne a changer.

La teinte est le seul point qui demandait du soin a travers ce swap, et il
est traite : `_ensure_material()` **DUPLIQUE** ce que le slot dessine avant
d'y toucher (l'importeur glTF lie UN materiau partage sur le mesh -- le
mutter tinterait toutes les instances du `.glb` a la fois), et n'ecrit que
`albedo_color`, qui **MULTIPLIE** une texture d'albedo au lieu de la
remplacer. Un modele texture garde sa texture et rougit quand meme.

### Le determinisme, prouve deux fois plutot qu'affirme

**`BattleContractProbe` est BYTE-IDENTIQUE au lot 1**, meme md5 de sortie
complete (`8138c3b3e7b2493cab0f2a26c354efd4`), 36/36, avec les vues
attachees et vivantes.

⚠️ **Il n'y a PAS de bypass headless dans `FighterView`**, et c'est
delibere : sauter la couche d'animation sur une sonde headless voudrait
dire que la sonde n'exerce jamais le fichier dont toute la promesse est
qu'il ne peut pas modifier un combat -- la branche qui a le plus besoin
d'etre prouvee serait la seule ou aucune sonde n'entre. La sonde tourne
avec les tweens vivants et doit quand meme sortir la meme trace.

`BattleReadabilityProbe` (**29/29**, nouvelle) ajoute ce que la sonde de
contrat ne peut pas voir :

* **PHASE A** : le `+Z` local des deux combattants pointe bien vers
  l'adversaire, **lu dans `Battle.tscn` via `SceneState`** (dot = 1,000
  des deux cotes) et non suppose -- une rotation retournee dans la scene
  ferait partir toutes les fentes a l'envers sans que rien n'echoue. Elle
  verifie aussi que **deux fentes simultanees (0,60) ne peuvent pas
  s'interpenetrer** (1,10 entre les surfaces).
* **PHASE B** : le MEME combat, meme seed, joue une fois sans frame entre
  les ticks et une fois **avec une vraie frame entre chaque tick** (donc
  tous les tweens avancent pour de bon) -> **trace byte-identique, 666
  ticks des deux cotes**. C'est la preuve que le temps moteur ne fuit pas
  dans la FSM.
* **PHASE C** : le recul passe de 0,011 a 0,110 entre 27 % et 80 % du
  windup, et la teinte de `g=0,630` a `g=0,395` -- la lisibilite CROIT,
  elle ne claque pas.
* **PHASE D** : attaque `+0,300`, esquive `-0,280`, garde `x0,86` en
  hauteur -- trois silhouettes distinctes.
* **PHASE E** : 25 actions avortees coup sur coup laissent **3 tweens
  vivants**, pas 75 ; et un KO en pleine fente gagne sur la fente.
* **PHASE F** : les deux contradictions du HUD, en assertions.

### Les deux corrections HUD, chacune adossee a un chiffre

* **`FLASH_S` 0,70 -> 0,45 s.** Sous les deux durees d'engagement mesurees
  (480 / 540 ms), donc un verdict ne peut plus survivre a l'action qui l'a
  cause, quel que soit le combattant. ⚠️ **C'est une constante de
  PRESENTATION du HUD, pas un timing de combat** : aucune valeur
  windup/active/recovery/stagger d'aucun `.tres` n'est touchee par ce lot.
* **`show_result()` remplace les deux libelles d'etat** par « Vainqueur »
  et « K.O. ». Une fois le round fini, un affichage de phase EN COURS
  sous-entend un combat qui tourne encore ; la seule chose honnete que ces
  deux lignes peuvent dire est comment ca s'est termine. Elles repartent en
  affichage de phase au round suivant, `Fighter.reset()` emettant `IDLE`
  avant `show_fight()`.

### `settle()` : une consequence visuelle du gel de la simulation

`_running = false` tombe sur le tick du KO, c'est-a-dire le tick ou le
VAINQUEUR est entre en `ACTIVE`. Sa FSM n'emettra plus jamais de
transition, donc sans intervention sa vue tiendrait la fente gagnante,
indefiniment, a cote du panneau de resultat -- qui fait **600x440 sur un
ecran 1080x1920 et ne couvre aucun des deux combattants**. `BattleArena`
appelle donc `settle()` sur les deux vues a la fin du round : elle ramene
au repos un combattant debout et **laisse volontairement au sol celui qui
est K.O.**, sa chute ETANT le resultat qu'on montre.

### Une seule addition a `Fighter.gd`, en lecture seule

`phase_duration()` (+ `_phase_total`) : la longueur PLEINE de la phase
courante. Purement additif, aucun branchement dessus, aucun changement de
comportement -- la sonde de contrat byte-identique le prouve. Elle existe
pour que la vue anime un windup sur **exactement** sa duree sans
re-deriver le `match` action -> timings de `FighterProfile`, qui doit
rester le seul du depot.

### Validation

Editeur + templates Godot 4.3-stable installes dans ce sandbox. Import
headless **exit 0**, export Web release **exit 0**, boot headless de
`Battle.tscn` **0 erreur**. `index.wasm` **35 376 909 octets** -- identique
au fingerprint deja consigne (aucun code moteur touche). Piege payload
tenu : **0** ligne `Storing File` pour `res://scripts/dev` ;
`scripts/battle/FighterView.gdc` bien present dans le `.pck`.

Sondes : `BattleContractProbe` **36/36 et byte-identique au lot 1**,
`BattleReadabilityProbe` **29/29**.

### Dette et reste ouvert

1. **Le jugement device reste entier, et c'est le point du lot.** Aucune
   sonde ne dit que 317 ms de windup suffisent A L'OEIL une fois le
   telegraphe visible. **Chiffre mesure a garder sous la main pour le lot
   3 : `attack_windup_s` = 0,30 (Keepy) / 0,31 (Sparring), soit 19 ticks.
   Si le test device dit que c'est encore trop serre, la valeur a essayer
   est 0,40-0,45 s** -- mais **le tuning n'est PAS fait ici**, deliberement :
   calibrer a l'aveugle contre un telegraphe qu'on ne voyait pas n'aurait
   rien mesure.
2. **La teinte suppose un `StandardMaterial3D`.** Un futur asset a
   `ShaderMaterial` perdrait la rampe rouge (et seulement elle : tout le
   telegraphe de transformation continue de se lire). `_tint_to()` devient
   un no-op silencieux dans ce cas, par construction.
3. **Les tweens tournent en temps MOTEUR, la FSM en pas fixes.** Les deux
   peuvent deriver d'une frame, et c'est autorise **precisement parce que**
   rien ne traverse de la vue vers la FSM. Ne jamais brancher un retour de
   la vue vers le combat, c'est ce qui ferait du framerate une entree du
   duel.
4. **Toujours aucun son, aucun asset 3D, aucune particule, aucune
   persistance** -- hors perimetre, inchange depuis le lot 1.

## KEEPY BATTLE LOT 3 : REGLAGE DE DIFFICULTE — 74 % -> 55 % de victoires, deux nombres dans un seul `.tres` (20 aout 2026)

Branche `claude/keepy-battle-lot3-tuning-3j5x3j`, partie de `staging`
(`903ea2f`). **Un seul fichier de jeu touche : `resources/battle/dummy.tres`,
deux valeurs.** Aucune ligne de code de gameplay, aucune scene, aucun
collider, aucun `.glb`. Retour device du lot 2 : le combat est lisible
(Mathieu voit venir l'attaque et a le temps de repondre) mais **beaucoup
trop facile**.

```
ai_aggression  0.55 -> 0.70     l'adversaire attaque plus souvent
attack_damage  11   -> 13       et chaque erreur coute plus cher :
                                5 coups propres pour un K.O. -> 4
```

### ⚠️ LE PIEGE DU LOT 1 EST RE-PROUVE, PAS SUPPOSE

Une mesure ou le brain ne tourne que d'un cote mesure un **sac de frappe**.
Verifie explicitement avant de croire le moindre chiffre, sur les memes
graines :

| cablage | victoires Keepy | actions/combat gauche | droite |
|---|---|---|---|
| un seul brain | **0/40 = 0 %** | **0,0** | 9,2 |
| **MIRROIR (les deux pilotes)** | **31/40 = 78 %** | **13,1** | 12,4 |

⚠️ **`BattleArena` ne fait tourner un brain QUE sur l'adversaire**
(`_brain.setup(opponent, ...)`) : les champs `ai_*` de **`keepy.tres` sont
MORTS dans le jeu livre** et ne servent que de joueur-etalon a la sonde.
**Les regler deplacerait l'etalon, pas le jeu** — `keepy.tres` est donc
intouche, et doit le rester.

⚠️ **Le chiffre du lot 1 (« ~78 %, 16,1 s ») est du BRUIT D'ECHANTILLONNAGE
a 40 combats.** Reproduit ici a l'identique (31/40, 16,11 s) puis remesure
a 150 combats sur deux bases de graines : **73,7 % (221/300)**. A n=40,
l'ecart-type binomial est de ~8 points. **Ne jamais conclure d'un seul
lot de 40.**

### AXE A — DEFENSE de l'adversaire (`ai_defense_rate`), 40 combats/point

| valeur | victoires Keepy | moyenne | min | max |
|---|---|---|---|---|
| 0,00 | 85 % | 11,7 s | 5,7 | 18,8 |
| 0,20 | 88 % | 13,1 s | 6,9 | 19,7 |
| 0,40 | 82 % | 14,5 s | 8,0 | 25,2 |
| **0,60 (livre)** | **78 %** | **16,1 s** | 8,0 | 32,9 |
| 0,80 | 60 % | 18,4 s | 8,2 | 32,9 |
| 1,00 | 45 % | **19,2 s** | 8,2 | 33,5 |

**L'axe A ALLONGE les rounds** exactement comme le lot 1 l'annoncait, et
c'est ce qui le disqualifie comme levier principal : le seul point qui
atteint la cible de victoires (0,80 -> 60 %) coute **18,4 s de moyenne**,
au bord du plafond de 20 s. **Non utilise, meme en appoint** — mesure a
l'appui : `def 0,70` en plus du reglage retenu ne gagne que 5 points de
difficulte pour +0,6 s (50,0 % / 14,5 s contre 55,0 % / 13,9 s).

### AXE B — AGRESSIVITE de l'adversaire, 40 combats/point

| `ai_reaction_delay_s` | victoires | moyenne | | `ai_aggression` | victoires | moyenne |
|---|---|---|---|---|---|---|
| 0,36 (livre) | 78 % | 16,1 s | | 0,55 (livre) | 78 % | 16,1 s |
| 0,30 | 60 % | 17,2 s | | 0,65 | 62 % | 15,8 s |
| 0,24 | 25 % | 16,3 s | | 0,75 | 52 % | 14,9 s |
| 0,18 | 30 % | 13,7 s | | 0,85 | 42 % | 14,9 s |
| 0,12 | 15 % | 12,3 s | | 0,95 | 35 % | 13,4 s |
| 0,06 | 8 % | 10,5 s | | | | |

⚠️ **`ai_reaction_delay_s` est une FALAISE, pas une pente** : 78 % a 0,36,
60 % a 0,30, **25 % a 0,24**. Toute la plage jouable tient dans 6
centiemes de seconde, et la non-monotonie 0,24 -> 0,18 (25 % -> 30 %)
montre que le bruit domine deja. **Levier ecarte : increglable finement.**
`ai_reaction_jitter_s` a le meme defaut (0,30 -> 78 %, 0,06 -> 38 %).

| `attack_damage` | victoires | moyenne | | `attack_recovery_s` | victoires | moyenne |
|---|---|---|---|---|---|---|
| 11 (livre) | 78 % | 16,1 s | | 0,42 (livre) | 78 % | 16,1 s |
| 13 | 70 % | 15,5 s | | 0,38 | 75 % | 16,2 s |
| 15 | 60 % | 14,7 s | | 0,34 | 78 % | 15,5 s |
| 17 | 55 % | 13,6 s | | 0,30 | 72 % | **INTERDIT** |
| 19 | 52 % | 13,4 s | | | | |

⚠️ **`attack_recovery_s` est REFUSE deux fois** : c'est un **levier nul**
(78 % a 0,42 comme a 0,34), et `BattleReadabilityProbe` PHASE F gate
`BattleHUD.FLASH_S` (450 ms) sous le plus court
`attack_active_s + attack_recovery_s` des deux profils. **Plancher dur a
0,33 s** — en dessous, le verdict « TOUCHE » survit a l'action qui l'a
produit et la sonde passe au rouge. La marge est de 30 ms et le profil
contraignant est **Keepy** (480 ms), pas l'adversaire (540 ms).

### ⚠️ `attack_windup_s` : REFUSE, et la mesure dit pourquoi

Reste a **0,30 (Keepy) / 0,31 (adversaire)**, la valeur validee sur device
au lot 2. Le raccourcir est le seul levier qui **defait le lot 2** : il
achete de la difficulte en rendant le telegraphe illisible au pouce. La
direction est confirmee par la mesure — monter le windup de l'adversaire a
**0,34 rend le combat PLUS FACILE (88 %)**, donc le descendre le durcit,
et c'est exactement pour cette raison qu'on n'y touche pas.

### ⚠️ `attack_damage` n'est PAS l'escalier arithmetique qu'il parait — mesure, pas deduit

Avec `max_hp = 50` et un chip de `ceil(dmg x 0,25)`, le nombre de coups
propres pour un K.O. est un escalier a trois marches : **11-12 -> 5 coups**,
**13-16 -> 4 coups**, **17-20 -> 3 coups**. L'arithmetique predit donc que
13 et 16 sont indiscernables. **C'est FAUX, et la mesure l'a attrape avant
qu'on l'ecrive comme un fait** : `dmg 13` donne **55,0 %** et `dmg 16`
**46,3 %** (300 combats chacun, meme marche de l'escalier). Le chip
s'accumule ENTRE les coups propres, donc `3 propres + 1 chip` tue a 16
(48+4=52) et pas a 13 (39+4=43). L'escalier gouverne le cas pur, pas le
cas mixte.

### CONFIGURATION RETENUE — 300 combats, deux bases de graines

Les combinaisons **se multiplient** : tous les candidats empiles au premier
jet ont depasse la cible (le plus doux deja a 25 %). La cible s'atteint avec
des mouvements **doux**, pas cumules.

| config | base 20260820 | base 31415926 | **poolee (300)** | moyenne |
|---|---|---|---|---|
| lot 2 livre (temoin) | 71 % | 77 % | **73,7 %** | 16,2 s |
| dmg13 seul | 64 % | 67 % | 65,3 % | 15,2 s |
| **aggr 0,70 seul** *(un cran PLUS FACILE)* | 60 % | 67 % | **63,7 %** | **15,0 s** |
| aggr 0,75 seul | 54 % | 59 % | 56,7 % | 14,7 s |
| aggr 0,65 + dmg13 | 52 % | 59 % | 55,7 % | 14,2 s |
| **aggr 0,70 + dmg13 — LIVRE** | **53 %** | **57 %** | **55,0 %** | **13,9 s** |
| **aggr 0,75 + dmg13** *(un cran PLUS DUR)* | 48 % | 50 % | **49,0 %** | **13,5 s** |
| aggr 0,70 + dmg13 + def 0,70 | 50 % | 50 % | 50,0 % | 14,5 s |

**Livre : `ai_aggression = 0.7`, `attack_damage = 13` — 55,0 %, moyenne
13,9 s, max 23,5 s.** Au centre de la cible 50-60 %, largement dans les
12-20 s, et **l'ordre des candidats est stable sur les deux bases** : la
valeur n'est pas ajustee a une graine.

**LES DEUX VOISINS SONT DES EDITIONS D'UN SEUL CHAMP, deja mesurees** —
Mathieu ajuste apres son test device sans relancer de sweep :

* **un cran plus facile** : `attack_damage` **13 -> 11** => 63,7 %, 15,0 s
* **un cran plus dur** : `ai_aggression` **0.7 -> 0.75** => 49,0 %, 13,5 s

### Validation

`BattleContractProbe` **36 checks, 0 failure, exit 0** (sa PHASE F rapporte
desormais **22/40 = 55 %, moyenne 13,85 s, max 23,53 s** — elle reproduit
au chiffre pres la prediction du sweep pour cette config a cette base, ce
qui valide que le banc d'essai jetable et la sonde livree mesuraient bien
la meme chose). `BattleReadabilityProbe` **29 checks, 0 failure, exit 0**,
**stderr BYTE-IDENTIQUE**. `ProbeTimeoutAudit` **exit 0, 35 sondes**
(retour exact a la baseline apres retrait des sondes jetables). Import
headless **exit 0**, export Web release **exit 0**, `index.wasm`
**35 376 909 octets** — le fingerprint deja consigne pour tout lot qui ne
touche pas le code moteur. Piege payload tenu (**0** ligne `Storing File`
pour `assets_source`/`docs`/`web`).

⚠️ **LE BYTE-IDENTIQUE BOUGE, et c'est la consequence ATTRIBUEE du reglage,
pas une regression.** Le diff stdout de `BattleReadabilityProbe` fait
**exactement 3 lignes**, toutes le meme fait (le combat de la PHASE B dure
666 -> 371 ticks, trace 9238 -> 5192 caracteres) ; **la PHASE F, celle qui
gate FLASH_S, est byte-identique** puisque ni `attack_active_s` ni
`attack_recovery_s` n'ont bouge. Attribue champ par champ plutot
qu'affirme (sonde jetable, supprimee avant commit) :

| variante | ticks | **coups propres encaisses** |
|---|---|---|
| baseline lot 2 (dmg11, aggr 0,55) | 666 | **5** |
| **damage seul** (dmg13) | 582 | **4** — la marche 5 -> 4 |
| **agressivite seule** (aggr 0,70) | 462 | **5** — memes coups, plus tot |
| livre lot 3 | 371 | **4** — les deux se composent |

Chaque champ deplace exactement la quantite qu'il doit deplacer, les deux
se composent, et la ligne baseline **reproduit 666 ticks / 9238 caracteres
au caractere pres** — ce qui valide le banc d'attribution lui-meme. Rien
n'est inexplique.

### Reste ouvert

1. **Jugement device, seul juge** : aucune sonde ne dit qu'un combat a 55 %
   est AGREABLE. Et le chiffre est un **proxy** — c'est un profil pilote
   par l'IA qui joue le role du joueur, pas Mathieu au pouce. Un humain qui
   lit le telegraphe fera mieux que l'etalon ; un humain distrait fera pire.
   Les deux voisins ci-dessus existent pour ca.
2. **Asymetrie assumee** : l'adversaire tue en **4** coups propres, Keepy en
   **5** (son `attack_damage` de 12 est intouche). C'est le sens voulu d'un
   durcissement, mais c'est reel et non maquille.
3. **Le plancher de difficulte atteignable par `.tres` seul est ~45 %** :
   meme `ai_defense_rate = 1,0` ne descend qu'a 45 %, et les leviers qui
   vont plus bas sont soit interdits (windup), soit increglables (delay).
   Un adversaire nettement plus dur demanderait du CODE — un brain qui lit
   les habitudes du joueur — et donc son propre lot.

### Deploiement staging du lot 3 (palier 1, automatique)

`staging` `064e148`, CI run **#168** (id `32409539500`) **verte en 3 min 22 s**
— `Deploy to Vercel [STAGING -- staging]` **succes**,
`[PRODUCTION -- main]` correctement **skipped**. Alias confirme dans le log :
`Success! https://keepy-staging.vercel.app now points to
https://keepy-crpgv8n8c-rajonrondoadkhey2095s-projects.vercel.app`.
`main` **non touche** (palier 2, gate Mathieu).

⚠️ **LA VERIFICATION SUR LE SERVICE A FINALEMENT ETE FAITE — mais en
DEUXIEME temps, et le premier temps merite d'etre garde.** Au moment du
deploiement, les DEUX canaux qui permettent de respecter la regle « jamais le
log CI seul » etaient absents : egress direct bloque (`keepy-staging.vercel.app`,
l'URL de preview et meme `vercel.com` rendent tous `000`, CONNECT refuse par le
proxy — teste, pas suppose) et aucun outil MCP Vercel charge dans la session.
Le trou a donc ete consigne comme tel plutot que comble par le log. Un canal
Vercel est apparu plus tard dans la meme session, et la verification a ete
faite pour de vrai :

| mesure | valeur servie |
|---|---|
| `CACHE_VERSION` (`index.service.worker.js`) | **`1787255094`** = **19:44:54 UTC** |
| `GODOT_CONFIG.fileSizes.index.wasm` | **35 376 909** |
| `index.pck` | 5 749 152 |
| fraicheur | `x-vercel-cache: MISS`, `age: 0` sur les DEUX requetes |

**Le `CACHE_VERSION` tombe A L'INTERIEUR de l'etape `Export Web build` du run
#169** (19:44:50 -> 19:44:55) : l'alias sert donc bien ce build, et il a
largement AVANCE par rapport au run #167 (lot 2, export ~19:04). Le reglage
est en ligne sur staging. `index.wasm` est identique au fingerprint permanent
de tout lot qui ne touche pas le code moteur — coherent avec un diff de deux
nombres dans un `.tres`.

⚠️ **L'alias pointe sur le run #169 (le commit de doc), pas sur le #168
(le merge du reglage).** Sans consequence : `CLAUDE.md` n'est pas une ressource
Godot, donc le contenu de JEU des deux builds est identique. Mais un futur
lecteur qui chercherait le `CACHE_VERSION` du #168 ne le trouverait pas, et ce
n'est pas une anomalie.

Rappel de methode, valable pour tout futur lot : le `CACHE_VERSION` est un
epoch pose a l'export, donc c'est le discriminateur le moins cher pour savoir
quel build est reellement aliase (leçon deja consignee au lot token du
18 aout). En une ligne, quand l'egress le permet :

```
curl -s https://keepy-staging.vercel.app/index.service.worker.js | grep CACHE_VERSION
```

Un `CACHE_VERSION` inchange voudrait dire que l'alias n'a pas bascule, malgre
le `Success!` du log — exactement le cas que la regle « jamais le log seul »
existe pour attraper.

## KEEPY BATTLE LOT 4 : LA FEINTE -- et le vrai defaut dominant n'etait pas l'esquive (21 aout 2026)

Branche `claude/keepy-lot4-feint-2my13e`, partie de `main` (`9b7f338`, ou
`main` et `staging` ont le MEME arbre `34db3682`). Retour device du lot 3 :
« j'esquive facilement ses coups » -- l'esquive est une reponse universelle
sans risque. Diagnostic du brief : une option domine, donc les deux autres
sont mortes.

**Le brief avait raison sur le symptome et se trompait de coupable.** La
mesure a trouve DEUX strategies dominantes, et la pire n'etait pas l'esquive.

### ⚠️ DEFAUT N°1, LE PLUS GROS, ET PERSONNE NE L'AVAIT VU : un joueur qui
### MARTELE ATTAQUE gagnait 300 combats sur 300, en 3,4 s

Trouve a la premiere passe de mesure du lot, sur le code LIVRE en production
la veille. Un joueur qui tape ATTAQUE et rien d'autre **stun-locke**
l'adversaire des le premier coup propre : stagger 0,55 + delai de reaction
0,36..0,66 + windup de garde 0,08 = **0,99 a 1,29 s** avant que la moindre
defense soit levee, contre un cycle d'attaque de **0,78 s**. L'arithmetique
ne se referme jamais.

⚠️ **Aucun reglage ne l'atteignait, et c'est mesure et non suppose** : le
martelage gagne encore **120 sur 120** a `attack_recovery_s` de 0,36 / 0,44 /
0,52 / 0,60 **ET** 0,70. Le defaut n'a jamais ete dans les regles de combat.

**Il etait dans `FighterBrain.gd`, qui trahissait la promesse de son propre
en-tete** (« tout ce qu'un joueur peut faire, cette classe peut le faire ») :
l'horloge de reaction etait remise a zero a chaque tick ou le combattant
n'etait pas IDLE, donc le brain payait son delai APRES chacune de ses
actions et APRES chaque stagger, jamais PENDANT. Sa cadence reelle etait
`duree_action + delai` au lieu de `max(les deux)`. Un humain, lui, reflechit
pendant sa recuperation et pendant qu'il est sonne, et tape dans le buffer
d'entree de 0,16 s pour que sa reponse soit deja engagee a l'instant ou il
est libre. **Les deux cotes jouaient a deux jeux differents sur l'axe exact
qui decidait le match** -- la divergence qu'on ne trouve qu'en mesurant, deja
payee une fois par ce depot (`SubstituteModel.tscn`).

Corrige : l'horloge tourne EN CONTINU. Le delai est toujours facture en
entier, la decision passe toujours par le meme `_choose()`, et rien ne peut
etre joue avant que le combattant soit reellement IDLE -- une decision echue
pendant un lockout est TENUE (la passer a `request_action` la mettrait dans
le buffer de 0,16 s, ou elle expirerait en silence si le stagger dure plus
longtemps : elle disparaitrait pour la raison exacte qui la rendait
necessaire). **Le martelage passe de 100 % a 50 %.**

⚠️ **Effet de bord assume et signale : `ai_reaction_delay_s` change de sens.**
Il mesurait « le delai apres chaque action » ; il mesure desormais
« l'espacement MINIMUM entre deux decisions ». En dessous de la duree d'une
action il ne contraint plus rien -- mesure inerte de 0,16 a 0,36 -- et il ne
redevient un cadran de difficulte qu'a partir de ~0,70, ou le stun-lock
reapparait (martelage 100 % a delai 0,70 et 0,90). Les cadrans utiles sont
desormais `ai_aggression`, `ai_defense_rate` et `ai_feint_rate`.

### DEFAUT N°2, celui du brief : un joueur qui repond a CHAQUE telegraphe est INVINCIBLE

Mesure avec une politique honnete (latence de reaction humaine, **un seul
tap par lecture**, attaque uniquement quand elle est reellement libre) :
**100,0 % de victoires sur 300 combats**, a 0,12 / 0,18 / 0,24 s de latence.
Diagnostic instrumente : sur 207 attaques de l'adversaire, **0 touche
proprement** et 57 sont esquivees -- les 150 autres sont interrompues. Le
retour de Mathieu est donc litteralement exact, et pire qu'il ne le disait.

⚠️ **Piege de mesure rencontre TROIS fois, a connaitre avant d'ecrire une
politique de joueur** : une politique qui appelle `request_action` a chaque
tick n'est pas un joueur, c'est un surhomme. Le buffer d'entree de 0,16 s
est rafraichi chaque tick, donc elle enchaine les esquives sans jamais etre
verrouillee et **aucun `dodge_recovery_s`, de 0,32 a 0,72, ne change quoi que
ce soit**. Trois tableaux entiers ont ete produits, lus et jetes avant que la
cause soit trouvee. Une politique de joueur doit taper UNE fois par lecture,
et n'attaquer que depuis IDLE.

### LA FEINTE LIVREE N'EST PAS CELLE DU BRIEF -- la version litterale a ete construite, mesuree, abandonnee

Le brief decrivait : « un WINDUP puis N'ATTAQUE PAS, enchaine sur une
recuperation », suivi d'une vraie attaque. **Construit, mesure, jete.** Il ne
peut pas fonctionner dans cette FSM, pour une raison d'arithmetique et non de
reglage : **toutes les attaques du jeu portent le meme telegraphe
`attack_windup_s`**, donc le deuxieme temps est exactement aussi lisible que
le premier. Un joueur qui a esquive le mensonge est sorti de sa recuperation
et esquive de nouveau bien avant que le contre arrive. Mesure : un joueur a
esquive-reflexe passait de **85,7 % a 96,3 %** de victoires quand la feinte
etait activee -- **chaque feinte etait une attaque que l'IA ne portait pas**.
Monter `dodge_recovery_s` de 0,32 a 0,72 n'a rien change, aux trois latences.

**Livre a la place : la feinte est une attaque qui RETIENT son coup.** UNE
seule action, jamais deux. Le windup tourne sa duree normale, le coup ne
vient pas, le combattant reste arme pendant `feint_hold_s`, et le coup tombe
apres. Le defenseur a donc toujours exactement une fenetre de lecture, au
moment habituel ; ce qu'il ne peut pas savoir, c'est QUAND le coup arrive.

**L'asymetrie garde/esquive tombe toute seule des nombres, sans aucune regle
speciale** : la fenetre active de l'esquive est etroite et expire pendant le
hold, celle de la garde est plus de deux fois plus large et ne l'est pas.
Bande mesuree, `hold` x latence joueur, part des feintes qui touchent :

| hold | 0,12 s | 0,18 s | 0,24 s |
|---|---|---|---|
| 0,10-0,18 | esq 98-100 % / gar 0 % | **esq 0 %** | **esq 0 %** |
| **0,22 - 0,34** | **esq 100 % / gar 0 %** | **esq 100 % / gar 0 %** | **esq 100 % / gar 0 %** |
| 0,40 | esq 100 % / **gar 100 %** | esq 100 % / **gar 100 %** | esq 100 % / gar 0 % |

**Livre : `feint_hold_s = 0.28`, le centre de la bande.** En dessous de 0,22
un reflex d'esquive couvre encore le coup ; a 0,40 la garde est tombee aussi
et la feinte devient un coup inconditionnel.

### ⚠️ LE CONDITIONNEMENT DE LA FEINTE EST A L'ENVERS DE L'INTUITION -- c'est LE resultat du lot

`FighterBrain` ne feinte **QUE** contre un adversaire qui n'est **PAS** libre.
Ca se lit a l'envers jusqu'a ce qu'on regarde l'horloge : un coup retenu
reste vulnerable pendant `attack_windup_s` + le hold, donc un adversaire
LIBRE frappe simplement le premier -- ce n'est pas un jeu d'esprit, c'est un
tour offert. Un adversaire ENGAGE ne peut pas, et se libere en cours de
telegraphe : juste a temps pour le lire, y repondre, et se faire prendre par
un coup qui arrive apres l'expiration de sa reponse.

| condition | joueur esquive-reflexe |
|---|---|
| feinte desactivee | **100,0 %** |
| bluffer un adversaire LIBRE (l'intuition) | **100,0 %** -- la feinte ne part JAMAIS |
| **bluffer un adversaire ENGAGE (livre)** | **52,0 %** a taux 0,85 / **93,3 %** a 0,35 |

Sans aucun conditionnement, la feinte est desastreuse contre un marteleur :
**32 feintes sur 43 interrompues en plein windup, 1 seule touche**, et le
marteleur passe de 51,7 % a 90,7 %. Le conditionnement rend la mecanique
auto-regulee, **sans aucune memoire des habitudes du joueur** (hors perimetre
et non fait).

### ⚠️ CE QUE LE LOT N'ATTEINT PAS, dit sans maquillage

L'objectif « une strategie mono-touche doit PERDRE » **n'est PAS atteint**.
Ce qui est atteint, c'est « aucune ne domine » : les trois options passent
d'un ecart de **50 points** a **9,3 points**.

| strategie pure (n=150) | lot 3 | ce lot |
|---|---|---|
| marteler ATTAQUE | **100 % en 3,4 s** | **90,0 %** |
| repondre par ESQUIVE | *(non mesure)* | **93,3 %** |
| repondre par GARDE | *(non mesure)* | **99,3 %** |
| spam garde seule / esquive seule | 0 % | 0 % *(elles n'infligent aucun degat -- 0 % par arithmetique, pas par equilibrage)* |

**Les trois gagnent encore trop souvent, et la cause est mesuree** : l'IA est
interrompue avant de finir ses engagements (150 attaques interrompues sur
207). Ce n'est PAS un echec de la feinte -- PHASE C de la sonde prouve que
chaque feinte prise isolement touche exactement comme prevu, aux trois
latences. C'est que l'IA n'arrive pas assez souvent a en placer une.

⚠️ **Resultat de theorie des jeux a connaitre avant de relancer un tuning** :
contre un adversaire dont le melange est FIXE, il existe toujours une reponse
pure au moins aussi bonne que n'importe quel melange. « Aucune mono-touche ne
gagne » est donc **inatteignable** avec un `ai_feint_rate` constant ; le seul
objectif atteignable est d'EGALISER les trois, ce que fait le triplet livre
(`feint 0.35`, `def 0.80`, `hold 0.28`). Aller plus loin demande un adversaire
qui adapte son melange -- explicitement hors perimetre de ce lot.

**Trois sorties possibles pour le lot suivant, aucune prise ici** : de
l'armure ou des i-frames pendant le hold (regle de combat nouvelle, donc son
propre lot et sa propre passe device) ; un second coup RAPIDE apres la feinte
(nouveau timing, donc nouveau telegraphe a valider) ; ou un adversaire qui lit
la frequence de reponse du joueur.

### `BattleFeintProbe` : 27 checks, et PHASE A est celle qui compte

Une feinte echoue d'une facon qu'aucune assertion de combat ne voit : donnez-
lui une milliseconde de windup en moins, un degre de lean en moins, une chaine
de HUD differente, et **toutes les autres sondes restent vertes pendant que la
mecanique ne vaut plus rien**. PHASE A compare donc une attaque et une feinte
**tick par tick** sur les quatre canaux qu'un joueur possede : le libelle
imprime par le HUD, `is_threatening()`, `telegraph_duration()`, et **les
transforms que `FighterView` ecrit reellement sur le `ModelSlot`**. 19 ticks,
identiques sur les quatre.

⚠️ **`BattleTypes.action_label(FEINT)` rend `"Attaque"`, et ce n'est PAS un
bug a corriger.** Le HUD imprime cette chaine EN DIRECT, a cote de l'etat de
l'adversaire, pendant que le windup tourne. Un libelle « Feinte » donnerait la
reponse avant meme que le joueur ait regarde le combattant. Gate par PHASE A.

⚠️ **`Fighter.is_threatening()` rend VRAI pour une feinte, et c'est
obligatoire.** C'est toute la vue d'un observateur sur une attaque entrante :
l'en exclure ferait voir a travers le mensonge par n'importe quel brain -- or
un brain est exactement ce qui tient le role du joueur quand on mesure. Une
mesure prise contre un adversaire qu'on ne peut pas tromper n'est pas une
mesure de la mecanique, c'est une mesure de son absence.

PHASE B (le coup est en retard d'exactement le hold, 16 ticks, et
`strike_activated` part une fois), PHASE C (**le controle d'abord** : une
attaque simple repondue par une esquive est bien ESQUIVEE, sinon les lignes
suivantes mesureraient une mauvaise esquive et non une bonne feinte -- puis
esquive TOUCHEE et garde BLOQUEE aux trois latences), PHASE D (le
conditionnement dans son sens contre-intuitif), PHASE E (**exige que le combat
trace contienne reellement des feintes** avant d'asserter quoi que ce soit sur
son determinisme), PHASE F (`keepy.tres` porte `ai_feint_rate = 0.00` --
`BattleHUD` n'emet que trois actions, un humain n'a pas de bouton feinte, et
une IA qui tient son role ne doit pas disposer d'une option qu'il n'a pas).

### Validation

`BattleFeintProbe` **27/27**, `BattleContractProbe` **36/36**,
`BattleReadabilityProbe` **29/29**, `ProbeTimeoutAudit` **36 sondes scenes**
(35 + la nouvelle), toutes armees -- **toutes exit 0**. Import headless
**exit 0**, export Web release **exit 0**. `index.wasm` **35 376 909 octets**,
md5 **`af4a8fc2925d992348eb30deeeb54360`** -- identique au fingerprint deja
consigne pour tout lot qui ne touche pas le code moteur. `index.pck`
5 750 224 (export unique et propre, `build/` supprime avant -- a lire avec la
mise en garde permanente sur son instabilite). Piege payload tenu : **0** ligne
`Storing File` pour `scripts/dev`, `assets_source`, `docs` ou `web`, et
`BattleFeintProbe` **absent du pack**.

⚠️ **`BattleContractProbe` n'est PAS byte-identique au lot 3, et ce serait
anormal qu'elle le soit** : ce lot change le gameplay de l'IA. Sa PHASE F
rapporte desormais **20/40 (50,0 %), moyenne 9,27 s** contre 22/40 (55 %) et
13,85 s au lot 3 -- l'adversaire agit pendant ses propres lockouts, donc les
combats sont plus courts. Les 36 assertions passent, aucun seuil n'a ete
touche. `BattleReadabilityProbe` reste verte : ce lot ne touche ni la vue ni
le HUD, et l'unique changement de `FighterView` est de lire
`telegraph_duration()` au lieu de `phase_duration()` sur le seul WINDUP.

**Point de bascule Meshy intact** : rien n'est ajoute, deplace ou renomme dans
l'arbre de scene, tout passe toujours par `$Body` / `ModelSlot`. **Aucune
reference depuis `scripts/battle/` vers `scripts/dev/`** (piege deja consigne :
`scripts/dev/*` est exclu du pack, donc une reference `class_name` casse
UNIQUEMENT dans le build web).

### Reste ouvert -- jugement device, seul juge

1. **La feinte se lit-elle comme une feinte ?** Aucune sonde ne dit qu'un
   combattant qui reste arme un quart de seconde de plus se lit comme « il
   retient son coup » plutot que comme un bug d'animation. C'est tout l'objet
   du lot : le telegraphe est desormais une information AMBIGUE, et personne
   ne sait encore si l'ambiguite se percoit au pouce.
2. **La difficulte globale reste trop faible contre un joueur qui repond a
   chaque telegraphe** (chiffres ci-dessus). Mesure, argumentee, non corrigee.
3. `ai_reaction_delay_s` a change de sens et n'est plus le cadran de
   difficulte qu'il etait.

### Deploiement staging du lot 4 (palier 1, automatique)

`staging` `0fadccf` (merge `--no-ff`, arbre **byte-identique** a la branche
feature, verifie avant le push : meme hash d'arbre des deux cotes). CI run
**#172** (id `32466399904`) **verte en 3 min 57 s** (09:07:43 -> 09:11:40 UTC)
-- `Deploy to Vercel [STAGING -- staging]` succes, `[PRODUCTION -- main]`
correctement skippe. **`main` NON touche** (palier 2, gate Mathieu apres
validation device).

**Verifie SUR LE SERVICE, pas dans le log CI** : l'egress direct vers
`keepy-staging.vercel.app` est refuse par le proxy du sandbox (`http=000`,
re-teste et pas suppose), donc via `mcp__Vercel__web_fetch_vercel_url`.
`index.service.worker.js` sert **`CACHE_VERSION = '1787303471|4112654'`** =
**09:11:11 UTC**, c'est-a-dire A L'INTERIEUR de la fenetre du run #172 --
l'alias sert donc bien ce build et pas le precedent (lot 3 : `1787255094`,
19:44:54 la veille). `x-vercel-cache: MISS`, `age: 0`, `last-modified` colle
a l'instant de la requete : trois signaux independants qui disent que ce
n'est pas une reponse de cache.

⚠️ **Note de format, sans consequence** : le `CACHE_VERSION` porte desormais
un suffixe `|4112654` que les lots precedents n'avaient pas. Seule la partie
avant le `|` est l'epoch d'export ; c'est elle le discriminateur, et elle a
bien avance.


## KEEPY BATTLE, LOT 5 : LA DEFENSE ETAIT INJOUABLE -- la fenetre entiere
## tombait AVANT la portee d'un humain (21 aout 2026)

Branche `claude/lot5-defense-viability-exfk3w`, partie de `staging`
(`a61df49`, le lot 4 feinte). Retour device de Mathieu : « j'ai
l'impression que ma garde n'a pas tenu assez longtemps pour encaisser le
coup », et « garder ou esquiver n'a pas de sens, les degats sont enormes
et on n'a pas confiance que ca marche -- si on veut gagner on attaque,
point. »

Les sondes du lot 4 disaient l'INVERSE (garde 99,3 %, esquive 93,3 %).
**Les deux etaient vraies, elles mesuraient deux joueurs differents, et
un seul des deux existe.** Aucun chiffre du lot 4 n'a ete defendu.

### ⚠️ LE DEFAUT : `BattleFeintProbe` repondait au telegraphe en 0,12-0,24 s

Aucun humain ne produit ca a travers un ecran tactile et un navigateur.
Le temps de reaction visuel simple plafonne vers 0,25 s en laboratoire ;
un telephone ajoute l'echantillonnage du digitiseur et le dispatch
d'evenement du navigateur par-dessus. **La bande honnete est 0,30-0,45 s**
(`BattleDefenseProbe.HUMAN_FAST/TYPICAL/LATE`).

Et le nombre qui decide reellement si defendre est une option --
**DE COMBIEN LE TAP PEUT-IL ETRE EN RETARD** -- n'etait rapporte nulle
part. C'est tout l'objet de la nouvelle sonde.

### Chronogramme AVANT, mesure sur les FSM livrees (pas calcule a la main)

Attaquant Sparring, defenseur Keepy, ticks depuis la premiere frame du
telegraphe :

| | couverture reelle du tap |
|---|---|
| garde vs attaque simple | **0..217 ms** |
| garde vs attaque ET feinte | **67..217 ms** |
| esquive vs attaque simple | **33..233 ms** |
| esquive vs feinte | 317..517 ms |

**La bande humaine entiere (300-450 ms) tombe HORS de chacune de ces
fenetres.** La defense n'etait pas faible, elle etait **hors de portee** :
a 300 ms -- le tap le plus rapide qu'un humain produise -- la garde ne
couvre PAS l'attaque simple, et l'esquive ne couvre NI l'une NI l'autre.

⚠️ **Le ressenti device etait juste, le mecanisme non.** « La garde n'a pas
tenu assez longtemps » decrit un symptome reel dont la cause est
**« la garde arrive trop tard »**, pas « elle expire trop tot » -- la
contrainte qui mordait etait la borne HAUTE du tap, pas la largeur de la
fenetre. Pire, le tap arrivant pendant le stagger etait mange par le
buffer de 0,16 s (stagger 0,55 s) : le bouton ne faisait litteralement
rien. D'ou « on n'a pas confiance que ca marche ».

### PHASE D : le joueur imparfait -- ce que le banc du lot 4 ne pouvait pas voir

Trois strategies caricaturales, tap = latence + gaussienne(0, 90 ms),
n=300 par cellule (jamais n=40 : la lecon du lot 3, ecart-type ~8 points).
Les DEUX cotes sont pilotes (le brain reel sur l'adversaire, la politique
sur le joueur) -- le piege « 1 brain = sac de frappe » a deja ete
rencontre deux fois.

| politique | AVANT (300/380/450 ms) | APRES |
|---|---|---|
| **martelage** | **261 / 261 / 261** sur 300 | **239 / 239 / 239** |
| garde | 203 / 183 / 136 | **300 / 300 / 299** |
| esquive | 199 / 204 / 176 | **262 / 296 / 298** |
| mixte | 218 / 178 / 160 | **295 / 300 / 299** |

**AVANT : le marteleur gagne 87 % A TOUTES LES LATENCES** (il ne lit
rien, donc la latence ne le concerne pas) et **toute defense fait pire,
et de pire en pire a mesure que le tap tarde**. C'est exactement le
rapport device, en chiffres.

**APRES : defendre bat marteler a chaque latence.** C'est le critere de
viabilite du lot, et il est atteint.

### Les TROIS leviers, dans l'ordre ou il a fallu les tirer

**A. Le telegraphe : 0,31 -> 0,58 s.** Il n'y a pas d'alternative, et
c'est une inegalite, pas un gout :

```
attack_windup_s  >=  latence humaine + guard_windup_s du defenseur
```

Une garde devient active a `latence + guard_windup_s`. Un telegraphe plus
court qu'un temps de reaction humain ne peut pas etre repondu, seulement
DEVINE. Ni une garde plus large ni des degats moindres n'y changent quoi
que ce soit. Startup de garde descendu a 0,03-0,04 pour rendre ce budget.

⚠️ **B. ELARGIR LA GARDE NE SUFFIT PAS -- et seul le fait de le mesurer
l'a montre.** Avec les fenetres corrigees mais le reste intact, le
marteleur est passe a **300/300** : *meilleur* qu'avant le fix. La garde
marchait parfaitement et perdait quand meme.

```
lockout restant du defenseur + son attack_windup_s
    >=  attack_active_s + attack_recovery_s + attack_windup_s de l'attaquant
```

Quand cette inegalite tient, le contre n'arrive JAMAIS : l'attaquant est
deja derriere son telegraphe suivant. Bloquer devient une facon plus
lente de perdre, et ne jamais s'arreter d'attaquer est le jeu correct.
Le lot 2 avait allonge le telegraphe, le lot 5 bien davantage -- les deux
ont grossi le membre gauche, personne n'a grossi le droit.
**`attack_recovery_s` 0,34-0,42 -> 0,52-0,54**, stagger 0,45 -> **0,60**
pour rester pire qu'un coup dans le vide. Gate : `PHASE C2`.

**C. La punition : 12-13 -> 8 degats.** 24-26 % de la barre de vie par
erreur (4-5 coups pour un K.O.) rend une defense incertaine irrationnelle
quels que soient les fenetres. Desormais **16 %, 7 coups**, et 25 coups
bloques.

### Chronogramme APRES

| | couverture du tap |
|---|---|
| garde vs attaque simple | **33..533 ms** |
| **garde vs attaque ET feinte** | **233..533 ms** |
| esquive vs attaque simple | **283..517 ms** |
| esquive vs feinte | 483..717 ms |

⚠️ **La feinte est CONSERVEE comme lecture difficile, pas supprimee** (choix
explicite du brief). La garde la couvre depuis n'importe quel tap de la
bande humaine -- c'est ce qui en fait l'option sure, celle qu'un joueur
peut prendre AVANT de savoir lire une feinte. L'esquive ne la couvre qu'a
partir de 483 ms, donc **une esquive reflexe reste punie**.
`feint_hold_s` 0,28 -> 0,20 pour tenir dans la garde elargie.
`BattleDefenseProbe` PHASE B asserte cet echec : **la seule assertion du
depot qui veut que quelque chose NE marche PAS**.

### Feedback : quatre issues, quatre verdicts (tache C)

Avant, une garde tapee 80 ms trop tard produisait **le meme flash blanc et
le meme mot « TOUCHE »** que ne rien presser du tout. Un joueur sans signal
d'erreur ne peut pas apprendre un timing, et une option qu'on n'apprend
pas est une option morte (lecon Chased, deja consignee).

`Fighter.hit_taken` porte desormais l'action defensive engagee. **Argument
de signal et pas relecture de `current_action`** : ca marcherait
aujourd'hui uniquement parce que l'emit precede `_enter_stagger()` -- une
dependance silencieuse, dans le canal meme que ce lot ajoute pour que les
echecs cessent d'etre silencieux.

| issue | couleur | forme |
|---|---|---|
| garde tenue | bleu froid | la garde se comprime davantage (absorbe) |
| esquive reussie | aqua vif | un glissement supplementaire |
| **defense BRISEE** | **violet** | la pose s'evase et roule |
| pris a froid | blanc | rien |

Forme **en plus** de la couleur : la couleur est le canal le plus
facilement perdu sur un petit ecran ou en plein soleil, et ce sont
justement les deux evenements dont il faut apprendre un timing. Absorber
et briser sont des mouvements **opposes**, volontairement.

⚠️ **La regle du lot 2 est INTACTE** : la rampe soutenue vers `ALERT_COLOR`
pendant un windup veut toujours dire une seule chose, une attaque
entrante. Ce sont des flashs d'IMPACT, momentanes, un canal qui portait
deja deux sens ; ce lot ajoute les deux qui manquaient, dans une teinte
qui n'est ni le rouge du telegraphe ni le blanc neutre.

HUD : **« GARDE BRISEE » / « ESQUIVE RATEE »** au lieu d'un « TOUCHE » nu.

### `ai_reaction_delay_s` de l'adversaire etait PERIME

0,36 +- 0,30 -> **0,26 +- 0,18**. Ses chiffres etaient cales sur un
telegraphe de 0,30 s : face a 0,56 s il ne pouvait plus lire a temps
(delai + guard_windup devait tenir sous le windup adverse, et la moitie de
ses tirages depassaient). Trouve par sweep, pas suppose.

### Validation

`BattleDefenseProbe` (**34 checks, 0 failure**, nouvelle, armee --
`ProbeTimeoutAudit` passe a **37 scenes**), `BattleContractProbe`
(**36/36**), `BattleFeintProbe` (**27/27**), `BattleReadabilityProbe`
(**29/29**), `AssetContractAudit`, `DeathModelAudit`, `ChargerShapeProbe`
-- **toutes exit 0**. Boot headless de `Battle.tscn` / `BattleHUD.tscn` /
`BattleFighter.tscn` / `Hub.tscn` : exit 0, **0 erreur GDScript**. Import
+ export Web release **exit 0**, `index.wasm` **35 376 909** octets / md5
`af4a8fc2925d992348eb30deeeb54360` -- le fingerprint deja consigne pour
tout lot qui ne touche pas le code moteur. Piege payload tenu (**0** ligne
`Storing File` pour `scripts/dev`, `assets_source`, `docs`, `web`,
`build`).

⚠️ **`BattleFeintProbe.LATENCIES` est passe de `[0.12, 0.18, 0.24]` a
`[0.30, 0.38, 0.45]`.** Ce n'est pas un assouplissement : ce sont les
valeurs qui ont produit le faux vert. Elle reste **27/27** a la bande
reelle, donc la feinte survit aux fenetres elargies. **Si un futur lot
trouve cette bande genante, le geste honnete est de changer le `.tres`,
pas la bande -- la bande est un fait sur les gens, pas un parametre.**

⚠️ **Non-applicabilite VERIFIEE par grep, pas supposee** : aucune des
sondes non-Battle ne reference `Battle`, `Fighter` ni `resources/battle`,
et le diff de ce lot ne sort pas de `scripts/battle/`, `scripts/ui/
BattleHUD.gd`, `scripts/dev/Battle*` et `resources/battle/*.tres`.

### Reste ouvert

1. **Jugement device, et c'est tout l'objet du lot** : est-ce qu'un
   telegraphe de 0,58 s se lit comme lent/lourd plutot que lisible, et
   est-ce que les quatre verdicts se distinguent A L'OEIL sur un
   telephone. Le plus important est **GARDE BRISEE** : le joueur doit
   comprendre qu'il a mal time, pas que le bouton n'a rien fait.
   Aucune sonde ne repond a ca.
2. ⚠️ **La difficulte globale a BAISSE, et le levier qui la recupererait
   est hors perimetre.** Un joueur qui repond a chaque telegraphe gagne
   desormais 100 %. Ce qui manque a l'adversaire est de **punir une
   recovery d'attaque** : apres avoir bloque, il est lui-meme verrouille
   trop longtemps pour contre-attaquer. C'est un changement de BRAIN
   (explicitement hors perimetre de ce lot), pas un reglage `.tres` --
   **mesure** : raccourcir sa garde pour le liberer plus souvent le rend
   PIRE (marteleur 79 % -> 100 %), et les quatre reglages `ai_*` balayes
   ne descendent pas le marteleur sous 79 %.
3. **Les rounds s'allongent** : 6,1 s (marteleur, avant) -> 14,8 s ;
   defense ~20-21 s. Inherent -- un combat ou les deux cotes defendent
   EST plus long -- mais au-dessus de la cible 12-20 s du lot 3.
4. Toujours aucun asset 3D, aucun son, aucune persistance : la bascule
   Meshy passe toujours par `$Body` / `ModelSlot`, intouchee.

### Deploiement staging du lot 5 (palier 1, automatique)

`staging` `92a0f8f`, CI run **#174** (id `32471971573`) **verte en
3 min 18 s** (10:17:41 -> 10:20:59 UTC) -- `Deploy to Vercel
[STAGING -- staging]` succes, `[PRODUCTION -- main]` correctement
**skipped**. `main` **non touche** (palier 2, gate Mathieu apres
validation device).

**Verifie SUR LE SERVICE, pas dans le log CI** (`keepy-staging.vercel.app`,
via `mcp__Vercel__web_fetch_vercel_url` -- l'egress direct du sandbox reste
refuse en 403 CONNECT sur ce domaine) : `CACHE_VERSION` du
`index.service.worker.js` servi = **`1787307631` = 10:20:31 UTC**, donc
**dans la fenetre du run #174**, contre `1787304120` = 09:22:00 (run #173,
lot 4) juste avant. `x-vercel-cache: MISS`, `age: 0`. L'alias sert bien ce
build.

⚠️ **L'API GitHub Actions a de nouveau servi des reponses PERIMEES**
pendant ce deploiement -- deux appels `list_workflow_jobs` byte-identiques,
figes sur `Import project resources / in_progress`, `filter: "latest"`
compris. **Le `CACHE_VERSION` servi est ce qui a tranche**, et il a tranche
DANS LES DEUX SENS : lu trop tot il valait encore `1787304120` (lot 4), ce
qui a confirme que le job tournait REELLEMENT au lieu d'etre un cache
perime, puis il est passe a `1787307631`. Un second signal independant
distingue les deux cas ; un poll de plus ne l'aurait pas fait.

## KEEPY BATTLE : PREMIERE ECRITURE FIRESTORE — un compteur cumule anonyme, un write par combat fini (21 aout 2026)

Branche `claude/keepy-battle-stats-d8b7p2`, partie de `main` = `staging`
(`13cda8d`, meme arbre des deux cotes). **Battle n'ecrivait rien nulle part
depuis le lot 1** ; ce lot ouvre `battleStats/global`, un document UNIQUE,
CUMULE et ANONYME (aucun `uid`, aucun historique par combat), incremente a
la fin de chaque combat. Schema valide par Mathieu : `gamesPlayed`, `wins`,
`losses`, plus `attacks`/`dodges`/`blocks` en `{attempted, hit, missed}`, plus
`updatedAt` serveur.

### Recon : la troisieme reponse est celle qui a change le travail

1. **Auth** — `request.auth != null` partout dans le ruleset deploye
   (`82c07ff`), et c'est **Google Sign-In et RIEN D'AUTRE** : `grep` ne trouve
   aucun `signInAnonymously` dans le depot, `web/html_shell.html` n'utilise que
   `signInWithRedirect(auth, new GoogleAuthProvider())`.
2. **Fin de combat** — `BattleArena._end_round(player_won)`, point unique.
3. ⚠️ **AUCUN compteur n'existait.** Rien dans `scripts/battle/` ne
   trackait quoi que ce soit — `grep -i "stat|counter|tally|attempts"` ne rend
   que des faux positifs (`state_changed`). Tous les compteurs sont neufs.
4. **`battleStats`** — aucun bloc dans `firestore.rules`.

### L'invariant est VERIFIE, pas deduit du FSM

`hit + missed <= attempted`, par groupe. C'est une **inegalite** et jamais une
egalite : `attempted` compte des ENGAGEMENTS, `hit`/`missed` des RESOLUTIONS —
une attaque interrompue avant sa fenetre active, une garde ou une esquive qui
n'affronte aucun coup, sont engagees et jamais resolues. L'ecart est donc une
donnee (des engagements jamais testes), pas du mou.

Le FSM livre ne peut pas le casser aujourd'hui, **et c'est un argument sur du
code que `BattleTally` ne possede pas**. `repair()` verifie donc sur les vrais
chiffres, avant encodage, et **REMONTE `attempted`** au lieu de baisser les
resolutions : une resolution est un fait observe, un engagement manquant ne
peut etre qu'un trou de comptabilite. Chaque reparation est un `push_warning`.

### ⚠️ LA FORME DU WRITE EST LE VRAI RISQUE — `updateMask` present ET vide

Un `:commit`, un write : `update` avec le NOM du document seul (aucun
`fields`), `updateMask: {fieldPaths: []}`, et 12 `increment` + `updatedAt` en
`REQUEST_TIME`. C'est la forme que les SDK officiels emettent pour
`set(increment(), {merge:true})`.

**Si le masque disparait, Firestore ECRASE le document entier avant que les
transforms ne tournent** — c'est-a-dire une remise a zero des totaux partages,
la seule panne de ce lot qui detruit de la donnee au lieu d'en perdre une.
`BattleStatsProbe` PHASE D lit donc ces octets litteralement.

**Les zeros voyagent aussi, et c'est porteur** : un `increment` sur un champ
absent le cree a partir de 0, donc envoyer `losses: 0` apres une victoire est
ce qui fait que le TOUT PREMIER write produit la forme complete que le
`hasAll()` des rules exige. Aucune branche create-vs-update cote client : un
read-then-write courrait contre tous les autres joueurs.

### Rules : purement additives, et la monotonie sert DEUX fois

`git diff --numstat` : **152 lignes ajoutees, 0 retiree** ; les 358 premieres
lignes (`/scores` + `/quizzes` + `/categories`) sont **byte-identiques** a
`origin/main` (`cmp` silencieux). Lecture signed-in comme `/scores` ; pas de
triplet owner-only puisqu'il n'y a **pas de proprietaire** ; jeu de cles exact,
entiers non negatifs, `updatedAt == request.time`, `allow delete: if false`, et
une **monotonie** qui refuse toute ecriture faisant baisser un compteur.

⚠️ **La monotonie est aussi le filet sous la forme du write** : masque
perdu -> les valeurs resultantes seraient les seuls deltas du combat courant,
donc INFERIEURES au stocke -> ecriture refusee au lieu de totaux remis a zero.

⚠️ **LIMITE ACCEPTEE PAR MATHIEU** : un document unique partage incremente
cote client ne peut pas etre rendu etanche par des rules — la cle d'API est
publique (elle est dans le build). Les rules reduisent la surface, elles ne la
ferment pas. Chiffres d'affichage, rien de sensible.

### ⚠️ DEUX PREMISSES DU BRIEF SONT FAUSSES, mesurees

- **`firestore-rules.yml` n'a PAS de `workflow_dispatch`** — c'est explicite
  dans son propre commentaire (« Deliberately no workflow_dispatch »). Le SEUL
  chemin vers le projet live est un push sur `main` touchant `firestore.rules`.
  **Il n'existe donc aucun moyen de tester une ecriture battleStats sur staging
  avant la prod.**
- **Consequence directe : sur `staging`, AUCUNE ecriture battleStats ne peut
  reussir.** Pas de regle deployee -> deny par defaut -> 403 -> `push_warning`,
  et rien d'autre. C'est le mode de panne prevu, pas une regression.

### Validation

`BattleStatsProbe` (nouvelle, **85/85, exit 0**) : regles de comptage une par
une, invariant force puis repare, jeu de cles complet, octets du write, gate
headless (**reseau teste AVANT auth** — un probe ne touche jamais `Auth`), et
**PHASE F un vrai combat a travers `Battle.tscn` livre** (986 ticks, tally
coherent, **exactement UNE tentative d'ecriture**, aucune reparation
necessaire). Import et export Web **exit 0**, `index.wasm` **35 376 909** /
md5 `af4a8fc2925d992348eb30deeeb54360`. `ProbeTimeoutAudit` **38 scenes** (37
avant). Piege payload tenu.

**SEPT sondes BYTE-IDENTIQUES sur les DEUX flux contre `origin/main`** en
worktree separe (imports verifies complets des deux cotes, 24 `.scn`) :
`BattleContractProbe`, `BattleFeintProbe`, `BattleReadabilityProbe`,
`BattleDefenseProbe`, `AssetContractAudit`, `DeathModelAudit`,
`ChargerShapeProbe`.

⚠️ **`BattleFeintProbe` ECHOUE 5/27 — et elle echoue DEJA sur
`origin/main`, a l'octet pres.** Rouge PRE-EXISTANT, non attribuable a ce lot
et non touche par lui. Cause : `LATENCIES` y vaut toujours
`[0.12, 0.18, 0.24]` alors que la section « lot 5 » de ce fichier annonce
`[0.30, 0.38, 0.45]` — **ce changement n'a jamais atteint `main`**. A traiter
dans son propre lot.

### Reste ouvert

1. **Rien n'a jamais atteint Firestore.** Aucun idToken Google dans ce sandbox,
   donc la forme du write est prouvee contre les rules ECRITES, **pas contre le
   service**. En particulier, ni le comportement d'un `updateMask` vide ni le
   fait que `request.resource.data` porte les valeurs POST-increment ne sont
   verifies en ligne — le second est le meme mecanisme qui fait deja marcher
   `createdAt == request.time` sur `/scores`, le premier ne l'est pas.
2. **Le deploiement des rules est gate `main`** (point ci-dessus), donc la
   premiere ecriture reelle sera une ecriture de PRODUCTION.
3. **Keepy-Analytics n'est pas touche** — session distincte, apres celle-ci.

## KEEPY BATTLE, LOT 6 : LES CAPSULES DEVIENNENT DES MODELES — zero asset genere, zero credit Meshy (21 aout 2026)

Branche `claude/keepy-lot6-3d-models-t6sctv`, partie de `main` = `staging`
(`924d81f`, meme arbre). **Decision de cadrage de Mathieu : on n'attend pas
Meshy.** Les deux combattants portent desormais un `.glb` que le depot
possede deja, et **toute l'animation reste procedurale** (les tweens du lot
2 sur `$Body`/`ModelSlot`). Les modeles sont statiques, animes par code,
exactement comme les capsules. Chiffres complets : `docs/MESHY_SPEC.md`
**§12** (nouvelle).

| combattant | asset | tri | echelle | rotation | offset |
|---|---|---|---|---|---|
| `PlayerFighter/Body` (Keepy) | `keepy_squirrel_hero.glb` | 3 129 | 1,07368 | `(0,0,0)` | `(0, -0,2246, 0)` |
| `OpponentFighter/Body` (Sparring) | `keepy_hibou_pursuer.glb` | 7 070 | 0,895095 | `(0,0,0)` | `(0, -0,0489, 0)` |

### Inventaire : il EXISTE un modele de Keepy, et l'adversaire s'imposait

`assets/models/` contient **10 `.glb`, tous unlit, tous deja packes** : les
6 hazards + 2 props decor (148-560 tri, plats, sans texture), plus
**l'ecureuil hero** (3 129 tri, 1 texture baked) et **le hibou poursuivant**
(7 070 tri, 4 textures). Les huit petits sont des sujets **couches ou
accroupis** ; **le hibou est le SEUL modele debout du depot** (bbox
dominante en Y, 1,228 x **1,899** x 1,172) et l'ecureuil est le seul hero.
Le choix ne se discutait donc pas beaucoup — et il est narrativement juste :
dans Chased le hibou POURSUIT Keepy, dans Battle Keepy lui fait face.

### ⚠️ REUTILISER UN `.glb` DEJA LIVRE COUTE ZERO PAYLOAD — donc NE PAS le decimer

`export_filter="all_resources"` packe une ressource **une fois**. Verifie
sur le log `savepack`, pas argumente : chacune des 7 ressources derivees
(les 2 `.scn` + leurs 5 `.ctex`) apparait dans **exactement UNE** ligne
`Storing File`. Mesure sur deux exports propres dans la meme session :
`.pck` **5 759 040 -> 5 761 376 (+2 336, +0,04 %)**, soit les deux `.tres`,
les deux scenes et le `FighterView.gdc` grossi — **pas un octet d'art**.
`index.wasm` **identique des deux cotes** (35 376 909, md5
`af4a8fc2925d992348eb30deeeb54360`).

⚠️ **Corollaire qui INVERSE l'instinct habituel : passer un de ces modeles
par `decimate_hazard.py` aurait GROSSI le build.** Une copie decimee est un
fichier de plus, donc le pack porterait l'original (pour Chased) ET la
reduction (pour Battle). Le decimateur sert a ramener un asset NEUF sous
budget ; c'est le mauvais outil pour un asset deja livre et deja dans son
budget (§7.1 : 6 000 et 8 000). Battle dessine **~10 200 tri** au total
contre une cible de 50 000, sans piste, sans hazard, sans collectible : il
n'y avait rien a acheter.

### Orientation : `(0,0,0)`, et le zero est MESURE

Chased monte ces deux memes modeles a `(0, 180, 0)`. Battle les monte a
zero, et ce n'est ni une contradiction ni une copie : rendu de chaque `.glb`
depuis `+Z`, `-Z`, `+X` et le dessus. **Ecureuil vu de +Z : le visage, les
yeux, le badge « K ». Hibou vu de +Z : la face et les anneaux d'yeux
lumineux.** Les deux ont donc leur face en **model +Z**. Chased a besoin de
180 parce que §3 fait regarder ses slots vers **-Z** (on les voit de dos) ;
un combattant Battle regarde **son adversaire**, le long de son propre `+Z`.

⚠️ **C'est la PROFONDEUR de l'ecureuil, pas sa hauteur, qui dimensionne
l'arene.** Pose assise, queue enroulee le long de Z : 1,229 x 1,257 x
**1,897**. De profil, ce 1,897 est presente **sur l'axe qui separe les deux
combattants**. Portee avant mesuree sur la scene construite : **1,018**
(ecureuil) contre **0,524** (hibou). Separation **2,00 -> 2,70**, camera
reculee (z 5 -> 7,1 ; pitch -10,2 -> -13,5 ; **`fov` intouche a 40**). Les
deux combattants sont assertes **entiers dans le cadre en 1080x1920 ET
1170x2532**, et leurs pieds touchent le sol au dixieme de millimetre.

### ⚠️ LE VRAI RISQUE DU LOT S'EST REALISE : le telegraphe de l'adversaire perd sa TEINTE

Mesure sur la scene livree, repos contre alarme pleine, moyenne **en
lumiere lineaire sur les pixels PROPRES de chaque combattant** (masque
obtenu en re-rendant la meme frame slot masque) :

| combattant | luminance | ecart de teinte | ecart de saturation |
|---|---|---|---|
| capsule Keepy (lots 2-5, validee device) | 1,63:1 | 26,9° | +0,18 |
| capsule Sparring (lots 2-5, validee device) | 1,61:1 | **159,6°** | +0,47 |
| **ecureuil `.glb`** | **2,21:1** | 11,4° | +0,53 |
| **hibou `.glb`** | **1,57:1** | **10,2°** | +0,52 |

**L'ecureuil du joueur y GAGNE** (un corps creme multiplie par du rouge
chute plus qu'une capsule orange). **L'adversaire non** : luminance et
saturation tiennent, mais la **teinte s'effondre de 159,6° a 10,2°** — une
capsule bleue qui vire au rouge est un basculement quasi complementaire, un
hibou brun qui vire au rouge n'est presque pas un changement de teinte. Et
c'est l'adversaire que le joueur lit.

⚠️ **Une PREMIERE mesure du meme phenomene a lu 1,18:1 et etait FAUSSE — la
methode, pas l'arbre.** Elle prenait un dominant d'histogramme sur une
fenetre 11x11, la methode des recolorisations hazards du §11, qui marche
la-bas parce qu'un hazard plat unlit remplit sa fenetre d'une seule
couleur. Sur un modele texture cette fenetre contenait **95 couleurs
distinctes sur 121 pixels**, donc aucun dominant. **Toute mesure de
contraste future contre un asset importe texture doit MASQUER l'objet, pas
echantillonner une boite.**

### La reponse : un cue engine-side, exactement le patron deja etabli

§2.1 et §8 disent deja qu'un cue d'**EMISSION** ne peut pas vivre sur un
slot (d'ou les yeux du poursuivant, noeuds engine-side et pas partie du
`.glb`). Ce lot trouve l'autre moitie de la meme regle, plus vicieuse parce
qu'elle echoue **par degres** au lieu d'echouer en silence : **un cue
d'ALBEDO survit mecaniquement au swap, mais ce qu'un joueur en voit devient
une propriete de l'asset.**

`BattleFighter.tscn` gagne donc **`Body/Alert`** : deux prismes, un coeur
vif dans un contour quasi noir, au-dessus de la tete, cache sauf pendant un
telegraphe d'attaque. Ses couleurs appartiennent au projet, donc sa
lisibilite est un fait sur le MOTEUR et non sur le `.glb` qu'un futur profil
portera. **La rampe de teinte est CONSERVEE a cote** : elle lit encore sur
un modele clair, et plus rien ne depend d'elle seule.

⚠️ **Le marqueur est enfant du slot, donc il HERITE du lacet du
combattant.** La premiere version s'est rendue **de profil** et se lisait
comme une echarde de 6 cm. Il est place depuis `visual_aabb().end.y` et
de-lace depuis `global_basis`, les deux mesures prises a la resolution —
**aucun champ par profil**, donc le contrat « un `.tres` + un `.glb`, zero
ligne de code » survit aussi a ce fichier.

### `BattleReadabilityProbe` : PHASE G nouvelle, PHASE A remesuree

**42 checks, 0 echec, exit 0.** PHASE G gate que le marqueur franchit
**3,0:1 contre les DEUX fonds** possibles (coeur **5,14:1** sur le ciel,
contour **3,67:1** sur le sol — aucune des deux couleurs ne bat les deux,
mais ensemble aucun fond ne l'avale), qu'il **grandit** au lieu d'apparaitre
(0,282 -> 0,713), qu'il est au-dessus du corps, et que **garde et esquive ne
le levent jamais** — la couleur veut toujours dire exactement une chose.

PHASE A cesse de soustraire un **rayon de capsule 0,45 code en dur** : ce
nombre a cesse d'etre la reponse des que de vrais modeles sont arrives. Elle
lit desormais la portee reelle de chaque profil sur son propre
`visual_aabb()`.

⚠️ **Piege trouve en ecrivant PHASE G** : `Battle.tscn` demarre un vrai
round des qu'elle entre dans l'arbre, et son brain pilote l'adversaire
chaque frame. La premiere version laissait l'arene tourner et lisait un
marqueur leve par l'attaque de l'IA comme un marqueur leve par la garde que
la boucle venait de demander. `set_process(false)` **et**
`set_physics_process(false)` avant toute mesure.

### Validation

**HUIT sondes diffees contre `origin/main` en worktree separe (imports
verifies complets des deux cotes) : les HUIT sont BYTE-IDENTIQUES sur les
DEUX flux, stdout ET stderr** — `BattleContractProbe` (le determinisme :
**ce lot est purement visuel et l'identite au bit pres le dit plus fort
qu'un verdict identique**), `BattleFeintProbe`, `BattleDefenseProbe`,
`BattleStatsProbe`, `ProbeTimeoutAudit`, `DeathModelAudit`,
`ChargerShapeProbe`, `AssetContractAudit` (12/12 visuels, **0/10 colliders
deplaces**). Import + export Web **exit 0**.

⚠️ **`BattleFeintProbe` est ROUGE (5/27) — et elle l'est A L'IDENTIQUE sur
`origin/main`**, meme sortie au bit pres. Rouge **pre-existant**, deja
consigne au lot battleStats, **hors perimetre et non aggrave par ce lot** ;
constate avant et apres, comme demande. Cause deja connue : `LATENCIES` y
vaut toujours `[0.12, 0.18, 0.24]` alors que la section lot 5 annonce
`[0.30, 0.38, 0.45]` — **ce changement n'a jamais atteint `main`**.

### Reste ouvert — jugement device, seul juge

1. **Est-ce qu'un ecureuil assis « kawaii » se lit comme un COMBATTANT ?**
   Aucune sonde ne repond. C'est une pose assise, sans jambes visibles et
   sans garde : elle a ete choisie parce que c'est le seul Keepy du depot,
   pas parce qu'elle se bat bien. C'est le risque principal du lot.
2. **Est-ce que le marqueur d'attaque se lit** a vitesse reelle sur un
   telephone, et est-ce qu'il ne parasite pas la lecture de la silhouette ?
   Sa taille (0,36 x 0,32 unite) et sa hauteur (`ALERT_GAP = 0,22`) sont des
   choix mesures pour tenir dans le cadre, pas valides a l'oeil.
3. **Les combattants occupent ~20 % de la hauteur d'ecran** contre ~28 %
   pour les capsules — consequence directe de la queue de l'ecureuil, qui
   force un cadre plus large. Mesure, assume, mais reel.
4. **Aucun son, aucune particule, aucune animation squelettale, aucun second
   adversaire, aucune progression** : hors perimetre, inchange depuis le
   lot 1. Le point de bascule reste `$Body`/`ModelSlot`.

### Deploiement staging du lot 6 (palier 1, automatique)

`staging` `ca22981` (merge `--no-ff`, arbre **byte-identique** a la branche
feature — meme hash d'arbre des deux cotes, verifie avant le push). CI run
**#180** (id `32490331721`) **verte** (14:06:20 -> 14:09:43 UTC) — `Deploy to
Vercel [STAGING -- staging]` **succes** a 14:09:41, `[PRODUCTION -- main]`
correctement **skipped**. `main` **non touche** (palier 2, gate Mathieu apres
validation device).

**Verifie SUR LE SERVICE, pas dans le log CI** (`keepy-staging.vercel.app`,
via `mcp__Vercel__web_fetch_vercel_url` — l'egress direct du sandbox reste
refuse sur ce domaine) : `CACHE_VERSION` du `index.service.worker.js` servi =
**`1787321354` = 14:09:14 UTC**, donc **a l'interieur de l'etape `Export Web
build` du run #180** (14:09:10 -> 14:09:15), contre `1787314110` = 12:08:30
(run #178) juste avant. `x-vercel-cache: MISS`, `age: 0`.

⚠️ **CORRECTION UTILE a la note « l'API GitHub Actions sert des etats
perimes » : `workflow_jobs_filter: {"filter": "latest"}` N'EST PAS le
remede.** Cette section-la consigne une observation UNIQUE ou passer
`"latest"` avait debloque la lecture. Ici c'est l'inverse, mesure : **trois
appels successifs avec `"latest"` ont rendu une reponse byte-identique figee
sur `Import project resources / in_progress`**, et c'est l'appel avec
`{"filter": "all"}` qui a rendu l'etat reel et complet. Les deux observations
ensemble disent la meme chose : **le parametre n'est pas la cause et n'est pas
la cure — seul un SECOND SIGNAL INDEPENDANT tranche.** Ici, comme au lot 3,
c'est le `CACHE_VERSION` reellement servi qui a repondu, et il a repondu dans
les deux sens (d'abord « toujours l'ancien build », donc le job tournait
vraiment ; puis le nouveau).

## KEEPY BATTLE, LOT 7 : REFONTE -- la GARDE et la FEINTE sont SUPPRIMEES, une BARRE DE CHARGEMENT dit quand le coup tombe (21 aout 2026)

Branche `claude/keepy-lot7-gameplay-98dj9f`, redemarree sur `origin/staging`
(`8c8a6c3`) -- elle pointait encore sur `main`, ou le lot 6 n'existe pas.
**Ce n'est ni un reglage ni une couche de plus : c'est une SIMPLIFICATION
assumee**, decidee par Mathieu apres quatre lots qui n'ont jamais deplace le
meme retour device.

### ⚠️ POURQUOI ON A ARRETE DE CORRIGER

Retours device identiques sur les lots **3, 4, 5 ET 6** : « la garde et
l'esquive ne marchent pas, la seule strategie c'est d'attaquer ». Chaque lot a
trouve une cause DIFFERENTE, REELLE et MESUREE, l'a fermee, et a recu la meme
phrase en retour. Les sondes disaient que defendre gagnait (garde 99,3 % au
lot 4, 300/300 pour une politique defensive au lot 5) ; le joueur ressentait
l'inverse.

**Cause finalement retenue** : le joueur savait qu'une attaque ARRIVAIT (le
telegraphe, valide au lot 2) et n'a jamais su QUAND elle frappe. Le lot 4 a en
plus rendu l'instant d'impact volontairement ambigu (feinte : coup retenu
0,28 s). Aucune largeur de fenetre ne fournit cette information -- c'est une
information manquante, pas une fenetre trop etroite.

### LE MODELE SUPPRIME, ET CE QUI LE REMPLACE

**SUPPRIME, pas desactive** -- aucun etat mort, aucun champ orphelin :
`Action.GUARD`, `Action.FEINT`, `Outcome.BLOCKED`, `is_attack_like()`,
`Fighter.telegraph_duration()`, la branche garde de `receive_strike()`,
`FighterView._brace()`/`_absorb_accent()`/`BLOCK_FLASH_COLOR`, le bouton
GARDE du HUD, et **sept champs de profil** (`guard_windup_s`,
`guard_active_s`, `guard_recovery_s`, `guard_damage_ratio`, `feint_hold_s`,
`ai_feint_rate`, `ai_guard_bias`). `FighterBrain` perd deux helpers qui
n'avaient plus qu'une seule valeur de retour atteignable.

**LA BARRE DE CHARGEMENT.** `Body/Charge` remplace le marqueur `Body/Alert`
du lot 6 : une piste sombre, un remplissage clair, et une **bande d'esquive**
qui deborde de la piste. Le remplissage est
`Fighter.charge_progress() = 1 - phase_left/phase_total`, lu **chaque frame**
dans `FighterView._process()`.

⚠️ **La barre pleine EST l'instant d'impact, par CONSTRUCTION et pas par
reglage** : le coup se resout au PREMIER tick d'`ACTIVE`, qui est le tick ou
le windup expire, qui est le tick ou la progression atteint 1,0. Mesure :
**barre pleine a UN TICK pres quand le coup part**, et l'ecart
`|progression - ecoule/total|` reste sous **1e-4** sur tout le remplissage.

⚠️ **PAS un tween, et la raison est le seul endroit ou ca compte.** Toutes les
autres animations de `FighterView` sont des tweens en temps MOTEUR -- aucune
ne promet un instant precis. La barre le promet. Un tween lance sur la
transition WINDUP deriverait contre l'accumulateur a pas fixe de l'arene, et
deriverait le PLUS a la fin, la ou vit toute la mecanique. La vue reste
strictement en LECTURE SEULE (un float entre, un transform sort) -- PHASE B
de `BattleReadabilityProbe` reste byte-identique avec les tweens vivants.

### ⚠️ LE MARQUEUR DU LOT 6 EST SUPPRIME, PAS GARDE A COTE -- c'est une decision

Le marqueur disait « une attaque arrive, a peu pres a ce stade ». La barre dit
ca ET l'instant. **Deux cues qui grandissent dans le meme coin d'ecran se
disputent une seule lecture, et le joueur apprend celui qui mene** -- c'est
exactement l'avertissement que `FighterView` porte deja pour teinte-vs-marqueur
(« les deux canaux doivent etre la MEME horloge »). L'argument de contraste du
lot 6 est transfere intact : remplissage clair dans une piste quasi-noire, donc
l'un des deux franchit toujours 3,0:1. **La rampe de teinte est CONSERVEE** --
autre surface, aucune geometrie en plus, et le lot 6 a mesure qu'elle survit
sur le modele du joueur. La couleur ne veut toujours dire qu'UNE chose : une
esquive ne leve aucune barre et ne rougit rien.

| paire | contraste mesure |
|---|---|
| remplissage vs ciel | **12,91:1** |
| remplissage vs sol | **4,10:1** |
| piste vs sol | 3,67:1 |
| remplissage vs sa propre piste | **15,05:1** |
| bande d'esquive vs ciel / vs sol | **14,9:1 / 4,73:1** (seule, sans etre portee par un voisin) |

### ⚠️ « APPUYER QUAND LA BARRE EST PLEINE » EST FAUX -- d'ou la bande dessinee

Savoir quand le coup tombe n'est que la moitie de ce qu'il faut ; l'autre
moitie est QUAND APPUYER, et ce n'est pas le meme instant. Une esquive a un
startup et une fenetre finie, donc le tap correct est un intervalle qui se
TERMINE avant la barre pleine. **Mesure** : les taps qui esquivent reellement
sont les ticks **26..49 sur 54**, soit **48 %..91 % de la barre, 400 ms de
large**. Un joueur a qui on dit « appuie quand c'est plein » appuie **83 ms
trop tard, a chaque fois**, et apprend que le bouton ne marche pas -- la phrase
exacte de quatre retours device.

La bande est donc DESSINEE, calculee par `BattleArena` (le seul objet qui
connait a la fois le windup de l'attaquant et les timings d'esquive du
defenseur -- une vue qui la deriverait de son propre profil dessinerait une
supposition sur le combattant d'en face).

⚠️ **La bande est DELIBEREMENT un SOUS-ENSEMBLE de ce qui marche.**
L'arithmetique continue donne 0,500..0,944 ; la mecanique quantifiee donne
0,481..0,907. Le bord bas est deja conservateur ; **le bord haut sur-promettait
de deux ticks**, il porte donc une allocation de deux ticks
(`EVADE_EDGE_ALLOWANCE_TICKS`). Une bande qui promet un tap et le fait echouer
est pire que pas de bande : elle enseigne le mauvais timing avec l'autorite du
jeu derriere elle. **Trouve par la sonde, pas par relecture** : l'assertion
« taper au bord haut esquive » est partie ROUGE au premier run.

### ⚠️ PHASE 2 -- les deux pistes existent DEJA, et la question etait le calibrage

Les deux pistes du brief (A : cout en tempo ; B : fenetre stricte) sont toutes
deux **inherentes au FSM** : `dodge_recovery_s` EST le cout, `dodge_active_s`
EST la fenetre. **Les deux sont retenues**, et c'est leur calibrage qui a ete
mesure, pas leur existence.

- **B, la fenetre** : `dodge_active_s = 0,40` -> **400 ms**, soit exactement
  la marge d'erreur du joueur, une pour une (il n'y a aucun autre terme).
  Gate a trois endroits parce qu'elle echoue dans trois directions : trop
  etroite pour la gigue humaine (plancher **4 sigma = 360 ms**), trop large
  (elle couvre **44 %** de la barre ; plafond 75 %, au-dela « taper n'importe
  quand » est correct et la decision disparait), ou fermee avant qu'un humain
  ait pu remarquer la barre (elle ferme a **817 ms** contre 450 ms au pire).
- **A, le cout** : `dodge_recovery_s = 0,36`. Gate par l'inegalite
  `tap + cycle d'esquive < windup + active + recovery` -- **avance au pire tap
  de la fenetre : +13 ms**, mince et positive, et le contre est **mesure** (les
  deux combattants joues, celui qui a esquive frappe le premier) et non calcule.

⚠️ **La bande humaine 300-450 ms du lot 5 n'est PLUS le critere de largeur, et
c'est le vrai changement conceptuel.** Regarder un remplissage se completer est
une ANTICIPATION, pas une REACTION ; la precision humaine sur un instant
anticipe est bien meilleure qu'une latence de reaction. La bande survit pour
UNE chose : le joueur doit d'abord REMARQUER le telegraphe, donc la fenetre ne
doit pas fermer avant qu'il ait pu le voir.

### ⚠️ LE CERVEAU LIT LA BARRE -- correction d'une position que ce lot avait prise deux heures plus tot

Un premier jet de `FighterBrain` refusait `charge_progress()` a l'IA, au motif
que la barre est « une information pour l'oeil humain ». **Mesure, c'etait
faux** : un joueur qui martele ATTAQUE gagnait **294/300** contre cette IA
aveugle, qui tape son esquive des qu'elle repere un telegraphe -- donc bien
trop tot -- et dont la fenetre a expire quand le coup arrive.

**La barre est a l'ecran. Le joueur L'A.** Une IA privee de cette information
n'est pas plus dure ni plus facile, elle joue a un autre jeu -- ce qui (a)
rompt la promesse de l'en-tete de ce fichier et (b) rend toute mesure
d'equilibrage de ce projet une mesure contre un mannequin incapable de faire ce
qu'une personne fait. **C'est le piege `SubstituteModel`, un lot apres le
precedent.** L'IA tire donc une fraction cible une fois par telegraphe
(`ai_dodge_aim`, dispersee par `ai_dodge_slop`) et tape quand le remplissage la
franchit. Ce qu'elle ne peut toujours pas faire : connaitre les timings de
l'adversaire, voir la milliseconde exacte, ou agir avant d'avoir paye son delai
de reaction.

### ⚠️ PHASE 3 -- `attack_recovery_s` est le levier, et la courbe N'EST PAS LISSE

Banc jetable (jamais commite, supprime avant commit), **n=300 par cellule**
(jamais n=40 : ecart-type binomial ~8 points, lecon du lot 3), gigue gaussienne
sigma 90 ms, **les DEUX cotes pilotes** (piege du sac de frappe deja rencontre
trois fois).

**Aucun reglage `.tres` ne corrigeait le martelage contre l'IA aveugle** --
mesure sur cinq champs avant le fix du cerveau, jamais sous 190/300. Apres le
fix, le levier apparait :

| `attack_recovery_s` | martelage (n=150) |
|---|---|
| 0,44 | 47/150 |
| 0,50 | 34/150 |
| **0,56 (valeur de depart)** | **128/150** |
| **0,62 (livre)** | **7/150** |
| 0,70 | 7/150 |

⚠️ **0,56 etait un PIC de resonance**, pas un point representatif : la valeur
que ce lot avait choisie au depart etait le pire point de la courbe. Regler sur
une resonance serait exactement le faux-vert que `ProbeCoverage.gd` documente
cinq fois -- 0,62 et 0,70 forment un plateau, pas un pic.

**Configuration livree** : `attack_windup_s 0,90` / `attack_active_s 0,12` /
`attack_recovery_s 0,62` / `attack_damage 14` / `max_hp 42` /
`dodge 0,05 / 0,40 / 0,36` / `stagger 0,70` / `ai_defense_rate 0,70` (adversaire)
/ `ai_dodge_aim 0,70` / `ai_dodge_slop 0,14`.

| politique caricaturale (n=300) | avant lot 7 | **apres** |
|---|---|---|
| **martelage d'ATTAQUE** | 98,0 % | **11,7 %** (moyenne 10,5 s) |
| esquive seule, jamais d'attaque | 0 % | **0 %** *(par arithmetique : elle n'inflige aucun degat)* |
| **lecture de la barre + contre** | -- | **98,7 %** (moyenne 24,2 s) |

**L'objectif du brief est atteint : le martelage n'est plus dominant, et de
loin.** Reste ouvert et dit franchement : la moyenne de 24,2 s depasse la cible
12-20 s du lot 3, et le max touche le plafond de 60 s -- quand les deux cotes
lisent bien, peu de coups passent. C'est inherent a un telegraphe de 0,90 s ;
non corrige, non maquille.

### Ce qui reste, et ce qui a ete signale plutot que garde « au cas ou »

⚠️ **`BattleTally.GROUP_BLOCKS` est CONSERVE, fige a zero, et documente comme
tel.** Rien ne peut plus l'incrementer. Il n'est PAS retire parce que les rules
Firestore **deployees** sur `keepy-8df91` exigent la cle : `statKeys()` liste
`blocks` et les chemins create/update assertent `hasOnly(statKeys())` **ET**
`hasAll(statKeys())`. Un write sans le groupe serait **REFUSE**, et toutes les
stats de Battle cesseraient d'etre enregistrees **en silence** (BattleStats ne
leve jamais). Le retirer demande un changement de rules, les rules ne se
deploient que sur un push `main` (`firestore-rules.yml` est scope a cette
branche par conception), et **ce lot ne va pas sur `main`**. La monotonie est
respectee entre-temps (increment de 0). **Ordre obligatoire le jour ou on le
retire : les RULES d'abord, le client ensuite** -- l'inverse casse
l'enregistrement pour tout le monde entre les deux.
`BattleStatsProbe` asserte desormais que le groupe est present ET a zero sur un
vrai combat, donc un futur lot qui le reincremente echoue la en premier.

**`BattleFeintProbe` est SUPPRIMEE** avec la mecanique qu'elle gatait. Elle
etait **DEJA ROUGE avant ce lot** (5/27 sur `origin/main`, ses `LATENCIES`
jamais mises a jour depuis le lot 4) -- sa suppression retire un rouge qui n'a
jamais ete celui de ce lot, et c'est dit plutot qu'absorbe dans un run vert.

**Conserves et vivants** : `dodge_windup_s` (vrai startup, il entre directement
dans l'arithmetique de la fenetre), les quatre `ai_*` d'origine, `Outcome.MISSED`.

### Validation

`BattleDefenseProbe` **21/21**, `BattleReadabilityProbe` **62/62**,
`BattleContractProbe` **33/33**, `BattleStatsProbe` **83/83**,
`ProbeTimeoutAudit` **37 sondes** (38 avant, une de moins avec la sonde feinte),
`AssetContractAudit` (12/12 visuels, **0/10 colliders deplaces**),
`DeathModelAudit`, `ChargerShapeProbe` -- **toutes exit 0**.

**Determinisme prouve APRES la refonte** : `BattleContractProbe` jouee deux fois
a la graine 20260806 est **byte-identique sur les DEUX flux** (stdout ET
stderr). Les traces ont massivement bouge par rapport au lot 6, comme une
refonte doit le faire -- ce qui est prouve ici est la reproductibilite, pas
l'immobilite.

Import headless **exit 0**, export Web release **exit 0**, `index.wasm`
**35 376 909 octets** / md5 `af4a8fc2925d992348eb30deeeb54360` et `index.js` md5
`4e08904b1b7107858246af44b602067b` -- identiques au fingerprint deja consigne
pour tout lot qui ne touche pas le code moteur. `index.pck` 5 761 088 (export
unique et propre, `build/` et `.godot/` supprimes avant -- a lire avec la mise
en garde permanente sur son instabilite). Piege payload tenu : **0** ligne
`Storing File` pour `scripts/dev`, `assets_source`, `docs`, `web` ou `build`, et
le banc jetable absent du pack.

**Point de bascule Meshy intact** : rien d'ajoute, deplace ou renomme dans
l'arbre de scene cote combattant hors du sous-arbre `Body/Charge` ; tout passe
toujours par `$Body`/`ModelSlot`, les modeles 3D du lot 6 sont intouches.
**Aucune reference de `scripts/battle/` vers `scripts/dev/`.**

### Reste ouvert -- jugement device, seul juge

1. **La barre se lit-elle comme une horloge** a vitesse reelle sur un
   telephone, et la bande d'esquive se lit-elle comme « appuie ICI » ? Aucune
   sonde ne le dit, et c'est tout l'objet du lot.
2. **La duree des combats** : 24,2 s de moyenne pour un joueur qui lit bien,
   contre 12-20 s vises au lot 3, avec des combats qui touchent le plafond de
   60 s. Mesure, signale, non corrige.
3. **L'avance apres une esquive est de 13 ms au pire tap de la fenetre** --
   positive et gatee, mais mince. Si le contre parait ne jamais passer sur
   device, c'est le premier chiffre a regarder.
4. Le brief precisait « si ca s'avere trop facile, on complexifiera plus tard »
   -- rien n'a donc ete ajoute par precaution.

### Deploiement staging du lot 7 (palier 1, automatique)

`staging` **`f572270`** (merge `--no-ff`, arbre **byte-identique** a la branche
feature : meme hash d'arbre `35c2c90b` des deux cotes, verifie AVANT le push).
CI run **#182** (id `32497515657`) **verte en 3 min 23 s** (15:25:31 ->
15:28:54 UTC) -- `Deploy to Vercel [STAGING -- staging]` succes,
`[PRODUCTION -- main]` correctement **skipped**. **`main` NON touche** (palier 2,
gate Mathieu apres validation device).

**Verifie SUR LE SERVICE, pas dans le log CI** (`keepy-staging.vercel.app`, via
`mcp__Vercel__web_fetch_vercel_url` -- l'egress direct du sandbox reste refuse
sur ce domaine) : `index.service.worker.js` sert
**`CACHE_VERSION = '1787326102|4201998'` = 15:28:22 UTC**, donc **a l'interieur
de la fenetre du run #182**, contre `1787321354` = 14:09:14 (run #181, lot 6).
`x-vercel-cache: MISS`, `age: 0`, `last-modified` colle a l'instant de la
requete -- trois signaux independants qui disent que ce n'est pas une reponse de
cache. L'alias sert bien ce build.

⚠️ **Ce qui est verifie et ce qui ne l'est pas, dit precisement** : le
`CACHE_VERSION` prouve **quel build est aliase**. Le fingerprint `index.wasm`
(**35 376 909** octets, md5 `af4a8fc2925d992348eb30deeeb54360`) est celui de
l'export LOCAL de cette session, pas relu sur le service -- l'`index.html`
servi n'a pas ete refetche pour l'extraire. Les deux ensemble etablissent la
chaine commit -> build -> deploiement ; la barre elle-meme est dessinee par
Godot dans le canvas et **aucune de ces mesures ne la voit**. Jugement device.

### ⚠️ TROISIEME INCIDENT DE SESSIONS CONCURRENTES -- le lot 7 a ete brieffe DEUX fois (21 aout 2026)

**La regle n°1 de ce fichier a ete enfreinte une troisieme fois** (precedents
du 6 et du 11 aout 2026). Deux sessions ont recu le meme brief lot 7. La
premiere (`claude/keepy-lot7-gameplay-98dj9f`) a livre, merge sur `staging`
(`f572270`) et deploye a 15:28 UTC. La seconde
(`claude/keepy-lot7-gameplay-dle7il`) a demarre a 17:32 UTC.

**Resolu comme les deux precedents le prescrivent, et moins cher** : le
`git fetch --all --prune` a ete fait AVANT d'ecrire une ligne -- la lecon
explicite de l'incident du 11 aout (« faire ce fetch AU DEBUT, pas a la
fin »). La seconde session n'a donc produit AUCUN doublon a abandonner : elle
a constate que `origin/staging` portait deja le lot, et s'est convertie en
AUDIT INDEPENDANT au lieu de le refaire. Cout du doublon : zero ligne de code,
contre ~3 h de travail duplique au 11 aout.

⚠️ **Rien dans l'outillage n'a signale la collision, une troisieme fois.** Le
seul indice etait la presence de `origin/claude/keepy-lot7-gameplay-98dj9f`
dans `git branch -r`, avec un arbre identique a `origin/staging`. **Comparer
les arbres (`git rev-parse <ref>^{tree}`) plutot que les noms de branche est ce
qui a tranche en une commande.**

#### Ce que l'audit independant a verifie -- rejoue, pas relu

Editeur Godot 4.3-stable installe dans ce second sandbox, import headless
complet (**24 `.scn`**, le piege du faux-rouge par import tronque controle et
non suppose). Sondes rejouees sur l'arbre `origin/staging` lui-meme :

| sonde | resultat | revendique par le lot |
|---|---|---|
| `BattleContractProbe` | **33/33, exit 0** | 33/33 |
| `BattleReadabilityProbe` | **62/62, exit 0** | 62/62 |
| `BattleDefenseProbe` | **21/21, exit 0** | 21/21 |
| `BattleStatsProbe` | **83/83, exit 0** | 83/83 |
| `ProbeTimeoutAudit` | **37 sondes**, toutes armees | 37 |
| `AssetContractAudit` | 12/12 visuels, **0/10 colliders deplaces** | idem |
| `DeathModelAudit` / `ChargerShapeProbe` | exit 0 | idem |

**Les chiffres d'equilibrage se reproduisent a l'unite pres** sur une autre
machine : martelage **35/300 = 11,7 %** (moyenne 10,5 s), esquive seule
**0/300**, lecture-de-la-barre + contre **296/300 = 98,7 %** (moyenne 24,2 s).
**L'objectif du brief -- le martelage n'est plus dominant -- est donc confirme
par une mesure independante**, pas seulement par celle qui l'a produit.

**Determinisme re-prouve APRES refonte** : `BattleContractProbe` jouee deux
fois a la graine 20260806 dans ce sandbox est **byte-identique sur les DEUX
flux** (stdout md5 `bd015b777aa42ce310dd35cba95512f3`, stderr identique).
**Contrat central de la barre re-mesure** : ecart
`|progression - ecoule/total|` **0,000000** sur tout le remplissage, barre
pleine a **0,9815** au dernier tick de charge, coup parti au tick 54 sur 54.

**Suppressions verifiees par grep plutot que par lecture** : `Action` ne
contient plus que `NONE / ATTACK / DODGE`, **zero code actif** contenant
`GUARD`/`FEINT`/`feint_*`/`guard_*`/`ai_feint_rate` hors commentaires
historiques, `BattleFeintProbe.{gd,tscn}` absente, et **aucune reference de
`scripts/battle/` vers `scripts/dev/`**. `BattleTally.GROUP_BLOCKS` est bien
conserve fige a zero, et c'est **correct** : `firestore.rules` deploye exige
`blocks` via `hasAll(statKeys())` (ligne 414), donc un write sans le groupe
serait refuse en silence. L'ordre « rules d'abord, client ensuite » consigne
par le lot tient.

**Aucun defaut trouve. Rien n'a ete corrige parce qu'il n'y avait rien a
corriger.**

#### ⚠️ Une seule nuance : le `CACHE_VERSION` consigne n'est PAS celui servi

Le lot cite `1787326102` = 15:28:22 UTC (run **#182**, le merge). Le service
sert **`1787326751` = 15:39:11 UTC**, soit le run **#183** -- le commit de doc
`20962d5`, qui a redeploye staging derriere lui. **Ni une erreur ni une
regression** : les deux builds ont un contenu de jeu identique (`CLAUDE.md`
n'est pas une ressource Godot), et l'epoch servi est POSTERIEUR au lot, donc
l'alias sert bien la refonte. C'est le meme schema deja consigne aux lots 3 et
5 (« l'alias pointe sur le run du commit de doc »). Dit ici pour qu'un futur
lecteur ne cherche pas l'epoch du #182 sur le service et n'en conclue pas qu'un
mauvais build est en ligne. Verifie a la re-lecture : `x-vercel-cache: HIT`,
`age: 1515` -- une reponse de cache CDN, donc **pas** les trois signaux de
fraicheur habituels ; c'est le `CACHE_VERSION` lui-meme, posterieur au lot, qui
porte la preuve ici, pas les en-tetes.

**Reste ouvert : inchange par cet audit.** Les quatre points du lot 7 restent
exactement ce qu'ils sont -- et le premier (la barre se lit-elle comme une
horloge a vitesse reelle sur un telephone) reste **hors de portee de toute
sonde de ce depot**. Aucune mesure de cette session ne le touche.

## KEEPY BATTLE, LOT 8 : L'ESQUIVE RAPPORTE ENFIN -- attaque INSTANTANEE cote joueur, et une RIPOSTE (21 aout 2026)

Branche `claude/lot-8-esquive-rapporte-prq4b5`, partie de `staging`
(`e00d0a5`). **Premier retour device positif en sept lots** : « Oui
j'esquive effectivement » -- le mecanisme de la barre du lot 7 FONCTIONNE.
Suivi de « mais je fais que perdre » : le joueur esquive bien et ne place
jamais de coup.

### PHASE 0 -- le chronogramme, et la cause n'etait PAS celle qu'on croyait

Le lot 7 avait deja signale deux fois son propre point faible : **+13 ms
d'avance apres une esquive reussie**, au pire tap de la bande dessinee.
Reproduit ici au tick pres (modele du FSM livre, avec le report d'overshoot) :

| tap (tick de la barre, sur 54) | defenseur libre | attaquant libre | avance |
|---|---|---|---|
| 28 (bord bas reel) | 76 | 99 | **+383 ms** |
| 49 (bord haut DESSINE) | 97 | 99 | **+33 ms** |
| 51 (bord haut reel) | 99 | 99 | **0 ms** |

⚠️ **Mais l'avance n'a jamais ete le vrai defaut, et c'est le resultat
central de la recon.** Meme a +383 ms, le contre du joueur etait
lui-meme **une attaque telegraphiee de 0,90 s avec sa bande d'esquive
dessinee**, que l'adversaire lit exactement comme le joueur lit la
sienne. Mesure sur les profils livres :

> `ai_dodge_aim 0,70 +- ai_dodge_slop 0,14` donne une plage de tirage
> **0,56..0,84**, entierement **a l'interieur** de la bande d'esquive
> reelle **0,519..0,944**. Quand l'adversaire decide d'esquiver, il
> reussit **~100 %** du temps.

Avec `ai_defense_rate = 0,70`, **~70 % des attaques du joueur etaient
esquivees d'office**, chacune coutant 1,64 s d'exposition. Le joueur
survivait et ne marquait pas : la phrase exacte du retour device.

⚠️ **Le banc du lot 7 ne pouvait pas voir ca, et c'est mesure et non
suppose.** Sa politique « lecture de la barre + contre » tapait son
contre **le tick meme ou elle redevenait libre** -- une machine, pas une
personne. Le meme banc, avec une latence humaine de 380 ms sur le contre,
donne **65,7 %** au lieu de 98,7 %, et des combats de **43 s** au lieu de
24,2 s. Ce seul terme manquant est tout l'ecart entre le rapport de sonde
et le retour device.

*(Banc Python jetable, jamais commite. Il n'a ete cru qu'apres avoir
**reproduit les trois chiffres publies du lot 7** : martelage 10,7 % /
10,3 s contre 11,7 % / 10,5 s, esquive seule 0 %, lecture+contre a
latence nulle 99,0 % / 23,6 s contre 98,7 % / 24,2 s.)*

### PHASE 1 -- l'attaque instantanee, et la barre RETIREE cote joueur

`keepy.tres` : **`attack_windup_s = 0.0`**. Le tap EST le coup : la frappe
se resout **au tick suivant (17 ms)**, gate par `BattleContractProbe`
PHASE A2.

**La barre disparait cote joueur par CONSEQUENCE, pas par un drapeau.**
`Fighter.is_charging()` exige desormais `_phase_total > 0.0`, et
`FighterView` s'y branche : un wind-up de longueur nulle traverse bien
l'etat WINDUP pendant un tick, et sans cette condition il aurait leve une
barre pleine pendant une frame -- et offert a l'IA une fraction a viser
sur une attaque par construction irreactable. Gate sur la scene livree :
**« an instant attack never raises a bar, not even for one frame »**, plus
l'absence de bande d'esquive (`is_visible_in_tree()`, pas le drapeau
local : la question est « est-ce dessine », pas « ce noeud est-il coche »).

⚠️ **Erreur de conception du lot 7 actee** : la barre avait ete posee des
DEUX cotes en croyant aider. Elle imposait en realite un timing au joueur
sur ses PROPRES coups -- or un coup qu'on decide n'est pas un coup qu'on lit.

⚠️ **CE QUI REMPLACE LA LECTURE DE LA BARRE PAR L'IA : RIEN, et c'est
mesure, pas compense.** Le chemin `_dodge_aim` de `FighterBrain` devient
**inatteignable** contre le joueur livre. L'IA retombe sur une esquive
aveugle -- une supposition -- ce qui est exactement ce dont dispose une
personne face a une attaque irreactable, et precisement pourquoi
`keepy.tres` price cette attaque en **chip (5)** et non en coup plein. Le
chemin est **CONSERVE et non supprime** : c'est le comportement du cerveau
face a tout adversaire telegraphie, ce qu'il rencontre des que le cablage
est mirroite (`BattleContractProbe` PHASE E le fait).
**Aucun reglage `ai_*` n'a ete durci** -- la consigne etait de mesurer
d'abord, et la mesure dit que ce n'etait pas necessaire.

### ⚠️ LA REGLE QUI REND TOUT LE RESTE POSSIBLE : un coup ORDINAIRE ne stagger plus

Sans elle, une attaque instantanee et annulante repetee plus vite que le
wind-up adverse est un **stun-lock**. **Mesure, pas deduit : martelage
300/300 (100 %) avec le stagger sur les coups ordinaires, 8 % sans.**

| | degats | stagger | annule le wind-up en cours |
|---|---|---|---|
| attaque **ordinaire** | `attack_damage` | **non** | **non** |
| **RIPOSTE** | `riposte_damage` | oui | oui |

Un telegraphe se termine donc **meme sous le feu** : marteler echange des
degats contre chaque coup que l'adversaire porte, au lieu de l'empecher
de jouer. Gate en trois assertions distinctes dans `BattleContractProbe`
PHASE B, dont **« a BLIND hit does NOT cancel the action it lands on »**.

### PHASE 2 -- LA RIPOSTE, coeur du lot

Une esquive qui couvre reellement un coup arme une riposte pour
`riposte_window_s`. **La fenetre ne se consomme QUE pendant les ticks
IDLE.** C'est le point qui decide si le mecanisme existe : l'esquive qui
gagne la riposte verrouille aussi son proprietaire pour la fin de son
propre cycle, et une fenetre comptee depuis l'instant de l'esquive serait
deja largement depensee avant que le joueur puisse bouger. Mesure sur le
FSM livre : **1200 ms encore ouverts au moment ou l'esquiveur redevient
libre**.

Latchee **au tap** (`_begin_action`), pas a la resolution : la recompense
appartient au moment ou le joueur decide. Une esquive = **une** riposte
(gate). Un stagger ou un KO la perdent.

**La fenetre de punition passe de 13 ms a 343 ms**, et le gate change de
nature -- il ne compare plus a zero mais **a un humain** :

| | lot 7 | lot 8 |
|---|---|---|
| avance deterministe au pire tap | **13 ms** | **343 ms** *(gate >= 300 ms, tap rapide)* |
| + temps de reflexion minimal adverse | -- | **643 ms** *(gate >= 450 ms, tap lent)* |

Le second est un **plancher dur** : `ai_reaction_jitter_s` n'est jamais
que additionne. C'est `attack_recovery_s` de l'adversaire (0,62 -> 0,95)
qui paie cette fenetre, et rien d'autre ne le peut -- l'inegalite est
ecrite au champ dans `FighterProfile.gd`.

⚠️ **`dodge_recovery_s` reste a 0,36, et ce n'est pas de l'immobilisme :
en dessous, le SPAM D'ESQUIVE devient dominant.** Mesure (n=300) :
dodge_rec 0,36 -> spam **0 %** ; 0,30 -> **100 %** ; 0,28 -> 97,7 % ;
0,24 -> 75,3 %. La couverture d'un spammeur est `da/(dw+da+dr)`, donc
raccourcir le cout de l'esquive le fait esquiver par accident. **La
fenetre de punition a donc ete achetee entierement du cote de
l'attaquant.**

**Attaquer SANS avoir esquive reste libre, et coute.** Le chip est
`attack_damage = 5` contre `riposte_damage = 14` (2,8x), sans stagger, et
il expose pendant `attack_active_s + attack_recovery_s` = **833 ms**
mesures. `PHASE C2` gate que la riposte coute **strictement plus** sur les
deux axes.

⚠️ **PHASE C2 A ETE RESCOPEE, et l'ancienne inegalite est PUBLIEE EN
ECHEC plutot que contournee.** Jusqu'au lot 7 elle assertait
`stagger_duration_s > toute recovery` -- juste tant que TOUT coup propre
staggerait, puisque le tempo etait alors le cout entier d'etre touche. Ce
n'est plus le cas. La satisfaire imposerait de monter les staggers
au-dessus des 950 ms de recovery de l'adversaire, et **c'est mesure : le
spam d'esquive passe alors de 0 % a 100 %** (une riposte chanceuse
verrouille assez longtemps pour placer la suivante). Chiffre publie, gate
remplace par l'invariant qui compte reellement.

### La riposte est VISIBLE, et ca n'etait pas optionnel

`FighterView` **tient** l'aqua `RIPOSTE_HOLD_COLOR` tant que la riposte
est depensable -- meme famille que le flash d'esquive reussie et que la
bande d'esquive de la barre : la marque qui dit « tape ici », le flash qui
dit « ca a marche » et le maintien qui dit « encaisse maintenant » sont
une seule couleur racontant une seule histoire. Le rouge continue de ne
vouloir dire qu'une chose, et il vit sur l'ADVERSAIRE.

⚠️ **Piege rencontre et ferme** : le flash d'esquive se rejoue vers
`_base_color`, donc il effacait le maintien **la frame meme ou il se
levait** (`riposte_changed` est emis AVANT `hit_taken`). Toutes les
detentes « retour au neutre » passent desormais par `_rest_color()`, qui
rend le maintien quand une riposte est due. Le cue existait et n'aurait
jamais ete vu.

### PHASE 3 -- equilibrage, n=300, les DEUX cotes pilotes

Politiques caricaturales, **chaque tap payant une reaction humaine de
300-450 ms tiree par tap** (le terme que le lot 7 n'avait pas) :

| politique | lot 7 | **lot 8** | duree moyenne |
|---|---|---|---|
| martelage d'ATTAQUE | 11,7 % | **8,0 %** | 8,7 s |
| esquive seule | 0 % | **0 %** *(par arithmetique : zero degat)* | 60,0 s |
| esquive-panique (tap des que la barre apparait) | -- | **0,0 %** | 8,6 s |
| **lecture de la bande + riposte** | 98,7 % | **100,0 %** | **12,9 s** |
| **la meme, JOUEUR IMPARFAIT** (3 lectures sur 4, gigue 140 ms) | -- | **80,0 %** | **14,7 s** |

**Les trois objectifs du brief sont atteints** : le martelage n'est pas
dominant, esquive+contre est de loin la meilleure strategie, et la marge
d'erreur existe -- **la ligne 100 % est une machine** (elle lit chaque
barre et ne se trompe jamais), la ligne a 80 % est ce que la meme
strategie vaut quand les lectures cessent d'etre gratuites.

**Les durees rentrent dans la cible 12-20 s** (12,9 / 14,7 s de moyenne,
max 18-20 s) contre **24,2 s de moyenne et des combats au plafond de 60 s**
au lot 7 -- l'attaque instantanee raccourcit bien, comme le brief le
prevoyait.

⚠️ **`attack_recovery_s` du JOUEUR = 0,72, choisi au CENTRE D'UN PLATEAU
et surtout pas au bord.** Le lot 7 avait deja documente des pics de
resonance sur ce champ ; il y en a un ici aussi, et **plus net** :

| `attack_recovery_s` joueur | 0,56 | 0,58 | 0,60 | **0,62** | 0,66 | 0,70 | 0,74 | 0,78 |
|---|---|---|---|---|---|---|---|---|
| spam d'esquive (base A / base B) | 100/100 | 100/100 | 100/100 | **0/0** | 0/0 | 0/0 | 0/0 | 0/0 |

Falaise **deterministe** (identique sur les deux bases de graines) entre
0,60 et 0,62. Se poser sur 0,62 serait se poser sur le bord ; **0,72** est
au milieu du plateau 0,62-0,90, avec le martelage a 0-4 % sur toute sa
longueur.

**Damage adverse 14/18 -> 12/16** : a 10/14 le spam d'esquive revient
(23 % base A, 31 % base B -- instable), a 14/18 le martelage tombe a 0 %.
12/16 est stable sur les deux bases. `max_hp` adverse 42 -> **64** pour la
duree.

### Determinisme

Prouve **APRES** le changement de gameplay, comme l'exige la consigne :
`BattleContractProbe` PHASE D joue le meme combat deux fois a la graine
20260820 et compare une trace par tick -- **byte-identique (7929 car.)**,
et **differente** a une autre graine (une trace toujours identique
passerait aussi si le combat etait gele). `BattleReadabilityProbe` PHASE B
rejoue le meme combat avec de vraies frames entre les ticks : **trace
byte-identique, 582 ticks des deux cotes** -- le temps moteur ne fuit
toujours pas dans le FSM. Aucun `randi()` global dans `scripts/battle/`.

### Une source de verite pour le prix d'un coup

`FighterProfile.damage_for(riposte)` est **le seul endroit** qui choisit
entre les deux nombres. `BattleArena` price avec, et **toutes** les sondes
resolvent avec -- donc un fixture ne peut pas pricer une riposte comme un
chip et rester vert. C'est la divergence, sur l'axe exact que ce lot
change, que ce depot a deja payee une fois (`SubstituteModel.tscn`).
Double-verrouille par **`BattleDefenseProbe` PHASE R2**, qui resout un
chip ET une riposte a travers **`Battle.tscn` lui-meme** -- vraie scene,
vrai `BattleArena`, vrai cablage : **5 dmg sans stagger, 14 dmg avec**.

### Deux defauts de SONDE trouves en chemin, corriges dans la sonde

1. **`BattleContractProbe` PHASE A et `BattleReadabilityProbe` PHASE C
   mesuraient le telegraphe sur le profil du JOUEUR** -- devenu le cas
   DEGENERE. Elles auraient asserte qu'un wind-up de 0 s dure 0 s et que
   rien n'a bouge pendant, ce qui est vrai et vide de sens. Bascculees sur
   le profil ADVERSE, qui est aussi le bon choix semantique : un
   telegraphe est une chose que le DEFENSEUR lit, donc il n'existe que sur
   le combattant d'en face. PHASE A2 couvre le cas zero explicitement.
2. **`BattleStatsProbe` PHASE F : un caricature `ticks % 3` silencieusement
   fragile.** Le joueur n'y est sollicite que quand il est libre, donc le
   choix dependait de la longueur du verrouillage **modulo 3** -- et
   l'attaque instantanee l'a mis a exactement 51 ticks. Le caricature
   attaquait et n'esquivait plus jamais : la sonde qui existe pour voir
   tous les compteurs en perdait la moitie. Remplace par une **bascule sur
   chaque action acceptee**, qui ne peut pas entrer en resonance avec un
   timing.

### Validation

`BattleContractProbe` **46/46**, `BattleDefenseProbe` **36/36**,
`BattleReadabilityProbe` **65/65**, `BattleStatsProbe` **83/83**,
`ProbeTimeoutAudit` **37 sondes scenes, toutes armees**,
`AssetContractAudit` (12/12 visuels, **0/10 colliders deplaces**),
`DeathModelAudit`, `ChargerShapeProbe` -- **toutes exit 0**.
Import headless **exit 0**, export Web release **exit 0**, `index.wasm`
**35 376 909** octets / md5 `af4a8fc2925d992348eb30deeeb54360` et
`index.js` md5 `4e08904b1b7107858246af44b602067b` -- identiques au
fingerprint deja consigne pour tout lot qui ne touche pas le code moteur.
Piege payload tenu : **0** ligne `Storing File` pour `scripts/dev`,
`assets_source`, `docs`, `web`, `build` ou `firebase.json`.

**Lot 6 intact** : rien d'ajoute, deplace ou renomme dans l'arbre de
scene, tout passe toujours par `$Body`/`ModelSlot`, les modeles 3D sont
intouches, et la barre de l'adversaire garde son contrat et ses ratios de
contraste (remplissage 12,91:1 vs ciel, 4,10:1 vs sol, bande d'esquive
14,9:1 / 4,73:1). **Vue toujours strictement en lecture seule sur le
FSM. Aucune reference de `scripts/battle/` vers `scripts/dev/`.**

⚠️ **`BattleTally.GROUP_BLOCKS` reste FIGE A ZERO**, verifie sur un vrai
combat par `BattleStatsProbe`. Les rules Firestore deployees exigent la
cle via `hasAll(statKeys())` : un write sans elle serait refuse **en
silence**. L'ordre reste obligatoire le jour ou on le retire -- **rules
d'abord, client ensuite** -- et les rules ne se deploient que sur `main`.

### Reste ouvert -- jugement device, seul juge

1. **Est-ce que l'esquive se SENT enfin payante ?** C'est tout l'objet du
   lot, et aucune sonde ne le dit. Ce qui est mesure, c'est que la fenetre
   existe (343 ms deterministes, 643 ms garantis) et que la riposte fait
   2,8x le chip en staggerant ; ce qui ne l'est pas, c'est qu'un joueur la
   voie et la prenne.
2. **Le maintien aqua se lit-il comme « tu as un coup en reserve »** ou
   comme une simple lueur ? C'est le seul canal qui annonce la recompense.
3. **L'attaque instantanee se sent-elle reactive ou brutale ?** Elle est
   irreactable pour l'adversaire par construction ; a 833 ms de
   verrouillage apres chaque tap, elle peut aussi se sentir lourde.
4. **L'esquive-panique perd 100 % des combats.** Argumente (la bande est
   DESSINEE, et « ESQUIVE RATEE » plus le flash violet disent au joueur
   qu'il a tape trop tot), mais c'est une lecon severe pour un premier
   contact -- a surveiller si Mathieu retrouve « trop dur ».
5. Toujours aucun son, aucune particule, aucun second adversaire, aucune
   progression, aucun brain adaptatif : hors perimetre, inchange.

### Deploiement staging du lot 8 (palier 1, automatique)

`staging` **`22f3b42`** (merge `--no-ff`, arbre **byte-identique** a la
branche feature : meme hash d'arbre `3a0ff0e7` des deux cotes, verifie
AVANT le push). CI run **#185** (id `32515598018`) **verte en 3 min 31 s**
(18:52:59 -> 18:56:30 UTC) -- `Deploy to Vercel [STAGING -- staging]`
succes, `[PRODUCTION -- main]` correctement **skipped**. **`main` NON
touche** (palier 2, gate Mathieu apres validation device).

**Verifie SUR LE SERVICE, pas dans le log CI** (`keepy-staging.vercel.app`,
via `mcp__Vercel__web_fetch_vercel_url` -- l'egress direct du sandbox reste
refuse sur ce domaine) : `index.service.worker.js` sert
**`CACHE_VERSION = '1787338553|4187371'` = 18:55:53 UTC**, donc **a
l'interieur de la fenetre du run #185**, contre `1787334325` = 17:45:25
(run #184) juste avant. `x-vercel-cache: MISS`, `age: 0`, `last-modified`
colle a l'instant de la requete -- trois signaux independants de fraicheur.
L'alias sert bien ce build.

⚠️ **L'API GitHub Actions a de nouveau servi des reponses PERIMEES** (deux
appels `list_workflow_jobs` **byte-identiques**, figes sur « Import project
resources / in_progress », `filter: "latest"` compris). **C'est le
`CACHE_VERSION` servi qui a tranche, dans les DEUX sens** : lu trop tot il
valait encore celui du run #184, ce qui confirmait que le job tournait
REELLEMENT au lieu d'etre un cache perime, puis il est passe a
`1787338553`. Un poll de plus ne l'aurait pas fait -- la regle « second
signal independant » deja consignee tient une fois de plus.

⚠️ **Piege de mesure rencontre pendant la validation, et il aurait produit
un FAUX ROUGE.** Les deux sondes gameplay seedees `ComboAudit`/
`ShrinkAudit` sont sorties **DIFFERENTES** au premier essai. Ce n'etait pas
une regression : **le run de la branche avait ete TUE en cours** (1009
octets contre 2670, coupe en plein « phase RISKY »), parce qu'il partageait
la machine avec l'export et les autres sondes. Rejouees proprement l'une
apres l'autre, elles sont **byte-identiques sur les DEUX flux** (2670 et
2149 octets des deux cotes). **Comparer les TAILLES avant de comparer les
contenus** : meme famille que le faux-rouge par import tronque deja
consigne, et une sortie tronquee ne se signale pas elle-meme.

## KEEPY BATTLE, LOT 9 : REEQUILIBRAGE DES DEGATS -- le ratio baisse, martelage NE bouge PAS (21 aout 2026)

Branche `claude/lot-9-damage-rebalance-pxw02t`, partie de `staging` (`054c8dc`,
lot 8). Retour device : « les attaques du hibou infligent des degats enormes,
disproportionne », et les deux symptomes a la fois -- le joueur meurt vite ET
n'arrive pas a faire baisser la vie de l'adversaire.

### PHASE 0 -- les chiffres re-verifies, et un etaient faux dans le brief

Le brief tablait sur « 64 PV joueur -> mort en 6 coups ». **Faux, mesure dans
les `.tres` et pas cru sur parole** : `keepy.tres.max_hp = 42`, pas 64 (64 est
le `max_hp` de **Sparring**, l'adversaire). Avec `attack_damage` adverse a 12,
un joueur passif meurt en `ceil(42/12) = 4` coups, pas 6. Le ratio
`adv_dmg/chip = 12/5 = 2,4x` cite dans le brief, lui, etait exact.

### PHASE 1 -- le conflit trouve par le sweep : le ratio cible casse le martelage

**Le vrai risque du lot n'etait pas dans le brief.** Un sweep en grille
(banc Python jetable reproduisant la FSM au tick pres, puis confirme sur
`BattleDefenseProbe` PHASE D -- le vrai banc, permanent, deja dans le depot)
montre que le taux de victoire du **martelage** est gouverne par une course de
DPS pure : `chip / cycle_joueur` contre `adv_dmg / cycle_adverse`. Monter le
chip sans toucher `attack_recovery_s` du joueur fait **exploser** le
martelage :

| adv_dmg | chip | ratio | martelage (rec=0.72 inchangee) |
|---|---|---|---|
| 12 (livre lot 8) | 5 (livre lot 8) | 2,40x | **11,7 %** (baseline) |
| 10 | 6 | 1,67x | **59,0 %** |
| 10 | 7 | 1,43x (cible du brief) | **63,3 %** |
| 11 | 8 | 1,38x | **94,3 %** |

**Directement au-dela de 8 dmg de chip, le martelage devient QUASI CERTAIN
(94-100 %).** Un ratio de 1,43x tel que suggere par le brief, applique
litteralement (chip 5->7, adv 12->10, rien d'autre), aurait rouvert
exactement l'exploit que les lots 7 et 8 ont ferme a la sueur -- « il suffit
d'attaquer » serait redevenu vrai.

### Le levier trouve, et il n'etait PAS dans le perimetre suggere : `attack_recovery_s` du JOUEUR

`attack_recovery_s` ralentit le cycle de chip SANS ralentir la riposte
(meme champ de timing, mais la riposte n'est quasi jamais throttlee par lui
puisqu'elle n'est tiree qu'apres une esquive reussie -- **mesure, pas
suppose** : `read+riposte`/`read+riposte-sloppy` restent a 100,0/14,0s et
94-96%/17,4-17,8s sur TOUTE la plage de recovery testee, 0,72 a 1,24). Sweep
fin a `adv=10 chip=7` (ratio 1,43x, la valeur suggeree par le brief) :

| `attack_recovery_s` joueur | martelage (3 graines) | chip DPS |
|---|---|---|
| 0,72 (livre lot 8) | 63,3 / 66,3 % | -- |
| 0,96 | 44,7 / 46,3 / 40,3 % | -- |
| 1,04 | 28,3 / 24,3 / 24,3 % | -- |
| 1,12 | 17,3 / 14,3 / 11,7 % | -- |
| **1,16 (retenu)** | **7,7 / 10,0 / 6,3 %** | 5,47 (baseline 5,95) |
| 1,20 | 6,3 / 4,0 / 3,7 % | -- |
| 1,24 | 1,7 / 3,0 / 2,7 % | -- |

⚠️ **La courbe n'est PAS monotone -- resonance, meme famille que celle deja
documentee au lot 7/8 sur ce meme champ.** Un point isole (ex. rec=0,88 : le
sweep montrait 95-97% de martelage, PIRE qu'a 0,72) aurait pu faire choisir
une fausse zone sure. `1,16` a ete verifie stable sur 3 graines independantes
et n'est pas sur un pic.

### Configuration retenue : EXACTEMENT le point suggere par le brief, PLUS le levier necessaire

`dummy.tres` (Sparring) : `attack_damage 12 -> 10`.
`keepy.tres` (Keepy) : `attack_damage 5 -> 7`, **`attack_recovery_s 0,72 ->
1,16`** (le champ non prevu par le brief, requis pour tenir « martelage reste
non dominant »).

`riposte_damage` **INCHANGE** des deux cotes (14 / 16) : ratio riposte/chip
Keepy `14/7 = 2,0x` (contre 2,8x avant) -- juge suffisant, la riposte reste
strictement plus forte ET la seule a staggerer (`BattleDefenseProbe` PHASE C2
gate `riposte_damage > attack_damage`, verifie).

Hits pour tuer (unguarded, worst case) :
- joueur (42 PV) vs adversaire : `ceil(42/12)=4` avant -> `ceil(42/10)=5`
  apres (**+25% de survie**).
- adversaire (64 PV) vs chip seul : `ceil(64/5)=13` avant -> `ceil(64/7)=10`
  apres (**chip plus fort, moins de coups pour vider la barre**).
- adversaire vs riposte seule : `ceil(64/14)=5`, inchange (la riposte reste le
  chemin de kill rapide).

### Validation, sur le VRAI banc du depot (`BattleDefenseProbe` PHASE D), pas une approximation

`BattleDefenseProbe` embarque deja un banc **permanent** (reported, jamais
gate) qui pilote les DEUX combattants (le vrai `FighterBrain` cote
adversaire, une politique caricaturale cote joueur, chaque tap payant une
latence humaine 300-450ms) -- exactement la methode que ce lot demandait,
deja ecrite. **3 graines independantes** (`20260821`, `31415926`, `7654321`
-- edit temporaire de la constante interne, jamais commite, revert avant tout
commit), 300 combats chacune, 900 combats par config :

| politique | AVANT (lot 8, moyenne 3 graines) | APRES (lot 9, moyenne 3 graines) |
|---|---|---|
| **martelage** | **8,2 %** (8,0/7,7/9,0) | **8,2 %** (7,3/8,0/9,3) -- **inchange** |
| dodge-only | 0,0 % (par arithmetique) | 0,0 % -- inchange |
| panic-dodge | 0,0 % | 0,0-0,3 % -- inchange |
| read+riposte (parfait) | 99,8-100,0 % | 99,3-100,0 % -- inchange |
| **read+riposte-sloppy (imparfait)** | **77,3 %** (80,0/72,7/79,3) | **80,1 %** (82,0/78,3/80,0) |
| duree (sloppy) | 14,5-14,9s | 14,9-15,0s |

**Le martelage ne bouge PAS d'un point sur la moyenne des 3 graines** --
c'etait l'invariant a proteger, et le sweep de la section precedente est ce
qui l'a garanti plutot que de le decouvrir apres coup. **Le lecteur imparfait
gagne PLUS souvent dans les 3 graines sur 3** (82,0>80,0 ; 78,3>72,7 ;
80,0>79,3) -- amelioration modeste (+2,8 points en moyenne) mais
**consistante**, pas un artefact d'une seule graine chanceuse. La cible du
brief (« le joueur imparfait doit gagner PLUS souvent qu'au lot 8 ») est donc
atteinte, avec l'honnetete que ce n'est pas un saut spectaculaire.

⚠️ **Reference unique-graine a connaitre** : la valeur `80,0 %` citee dans le
brief comme « base lot 8 » est la sortie de la graine par defaut de la sonde
(`20260821`), et un seul run supplementaire a une autre graine (`31415926`)
donne **72,7 %** pour ce MEME code -- un ecart de 7+ points venant de la seule
graine, sur 300 combats. **Ne jamais lire un seul run de PHASE D comme une
verite absolue** ; les 3 graines ci-dessus existent pour ca.

### PHASE 2 -- l'esquive-panique : `dodge_recovery_s` est MECANIQUEMENT DECOUPLE, verifie sur le vrai banc

Le brief demandait de regarder `dodge_recovery_s` pour adoucir la lecon
severe de l'esquive-panique (100 % de defaites). **Reponse franche : ce
champ n'a AUCUN effet sur ce policy, ni en Python ni sur le vrai banc du
depot -- verifie par edit temporaire + revert, pas suppose.**

```
dodge_recovery_s=0.20  panic-dodge wins   1/300 (  0.3%)  mean  11.3s
dodge_recovery_s=0.28  panic-dodge wins   0/300 (  0.0%)  mean  11.3s
dodge_recovery_s=0.36  panic-dodge wins   0/300 (  0.0%)  mean  11.3s
```

**Duree ET taux de victoire identiques au bruit pres sur toute la plage.**
Lu dans le code de la sonde (`BattleDefenseProbe.gd::_policy_fight`) : le
panic-dodge tape sa DODGE **au tick meme ou la barre apparait** (`t=0` du
windup adverse, zero latence de reaction meme), une seule fois par
telegraphe, sans retenter. Le succes d'un tel tap depend uniquement de
`dodge_windup_s` et `dodge_active_s` (est-ce que la fenetre active, calee sur
CE tap, couvre l'instant du coup) -- `dodge_recovery_s` ne gouverne QUE le
cout d'un enchainement de plusieurs esquives (spam), jamais la reussite d'un
tap unique deja tire. Un tap a `t=0` a besoin de `dodge_active_s >= W - dw`
(soit `>= 0,85s`, plus du DOUBLE de la valeur actuelle 0,40s) pour esperer
couvrir le coup -- une largeur qui, mecaniquement, ferait aussi decoller le
spam d'esquive continu par le meme argument de duty-cycle qui a motive le
`dodge_recovery_s=0,36` actuel (piste testee en Python : `dodge_active_s`
0,40->0,50->0,55 fait passer panic-dodge de 0% a 68% a 100%, un saut abrupt
dans la meme zone que celle documentee comme dangereuse pour le spam).

**Aucune valeur de `dodge_recovery_s` ne satisfait donc l'objectif du
brief, parce que ce n'est pas la variable en jeu -- dit franchement plutot
que choisir un compromis silencieux.** Le levier reel serait
`dodge_active_s`/`dodge_windup_s`, hors du champ que le brief a nomme, et son
elargissement porte un risque de spam documente sur cet axe meme. **NON
touche dans ce lot** -- `dodge_recovery_s` reste a `0,36` des deux cotes,
inchange. Une future session qui voudrait vraiment adoucir l'esquive-panique
devrait ouvrir son propre lot sur `dodge_active_s`, avec sa propre passe de
validation device (le risque de spam n'a pas ete mesure sur le vrai banc,
seulement argumente par le duty-cycle).

### Sondes rejouees, toutes exit 0

`BattleContractProbe` (46/46), `BattleDefenseProbe` (36/36, PHASE D
rapportee ci-dessus), `BattleReadabilityProbe` (65/65), `BattleStatsProbe`
(83/83), `ProbeTimeoutAudit` (37 sondes scenes armees), `AssetContractAudit`
(12/12 visuels, 0/10 colliders deplaces), `DeathModelAudit`,
`ChargerShapeProbe`. Aucune assertion codee en dur sur les anciennes valeurs
de degats/recovery n'a ete trouvee -- **verifie par grep, pas suppose** :
toutes les sondes lisent `KeepyProfile.attack_damage`/`riposte_damage`/
`attack_recovery_s` etc. directement sur les `.tres`, jamais un litteral --
c'est la discipline que `damage_for()` (le point unique de prix) impose
depuis le lot 8.

`GROUP_BLOCKS` de `BattleTally` reste fige a zero (rules Firestore
deployees, `hasAll(statKeys())`), inchange par ce lot -- aucun champ de
`BattleStats` ou des rules n'est touche.

### Build et export

Editeur + templates Godot 4.3-stable installes dans ce sandbox (releases
GitHub officielles, tailles verifiees contre `Content-Length` avant
extraction -- le piege de troncature silencieuse deja consigne). Import
headless **exit 0** (24 `.scn`, import complet verifie et pas suppose),
export Web release **exit 0**. `index.wasm` **35 376 909 octets**, md5
`af4a8fc2925d992348eb30deeeb54360`, `index.js` md5
`4e08904b1b7107858246af44b602067b` -- **identiques au fingerprint deja
consigne pour tout lot qui ne touche pas le code moteur**, coherent : ce lot
ne change que 3 valeurs dans 2 fichiers `.tres`. Piege payload verifie :
**0** ligne `Storing File` pour `assets_source`, `scripts/dev`, `docs`, ou
`web`. `index.pck` 5 762 912 octets (export unique et propre, `build/` et
`.godot/` supprimes avant -- a lire avec la mise en garde permanente sur son
instabilite).

### Reste ouvert

1. **Jugement device, seul juge** : est-ce que le ratio 1,43x et la
   recuperation allongee du joueur (0,72->1,16s, +61%) se SENTENT justes --
   chaque coup ordinaire est plus fort (+40%) mais moins frequent, et
   l'amelioration mesuree du lecteur imparfait est reelle mais modeste
   (+2,8 points en moyenne, pas un bond).
2. **L'esquive-panique reste une lecon a 100% de defaite**, non adoucie --
   argumente comme mecaniquement hors de portee de `dodge_recovery_s`, avec
   la piste reelle (`dodge_active_s`) nommee et deliberement pas prise dans
   ce lot.
3. Le riposte/chip a 2,0x (contre 2,8x avant) n'a pas ete mesure comme
   insuffisant, mais n'a pas non plus ete confirme comme le point d'equilibre
   ideal -- si un futur retour device dit que la riposte "ne se sent plus
   speciale", c'est le premier chiffre a revisiter.
4. Toujours aucun son, aucune particule, aucun second adversaire, aucune
   progression, aucun brain adaptatif : hors perimetre, inchange.

`main` **non touche**. Merge sur `staging` : palier 1, automatique (build,
export et sondes verts).

## KEEPY BATTLE, LOT 10 : SYMETRISATION -- 50 PV et le meme chip des deux cotes, et la cadence du joueur qui DOUBLE pour le payer (21 aout 2026)

Branche `claude/keepy-battle-symmetry-dnjqvx`, partie de `staging` (`bce85ed`,
lot 9). Retour device, capture a l'appui : **Sparring 43/64 PV, Keepy 12/42 PV**
-- l'adversaire a 22 PV de plus que le joueur. Les PV avaient servi de levier de
difficulte pendant neuf lots sans que la symetrie soit jamais remise a plat.
Decision de conception de Mathieu : **50 PV des deux cotes, `attack_damage`
ordinaire identique, et la riposte conservee comme avantage EXCLUSIF du
joueur** -- base symetrique, une seule asymetrie, assumee et lisible.

**Sept valeurs, deux fichiers `.tres`, ZERO ligne de code.** `git diff --stat`
contre `origin/staging` ne rapporte que `resources/battle/keepy.tres`,
`resources/battle/dummy.tres` et ce document. Aucune scene, aucun `.glb`, aucun
collider, aucun script de `scripts/battle/` ni de `scripts/ui/`.

### PHASE 0 -- l'etat reel, mesure dans les `.tres` et pas cru sur parole

| | Keepy (joueur) | Sparring (adversaire) |
|---|---|---|
| `max_hp` | **42** | **64** |
| `attack_damage` | 7 | 10 |
| `riposte_damage` | 14 | 16 |
| `attack_windup_s` | **0,00** (instantane) | **0,90** (barre de charge) |
| `attack_recovery_s` | 1,16 | 0,95 |

Coups pour tuer, avant ce lot : le joueur a besoin de **10 chips** ou **5
ripostes** pour vider 64 PV ; l'adversaire de **5 chips** ou **3 ripostes**
pour vider 42. L'ecart que Mathieu a photographie n'est donc pas une
impression : c'est un facteur **2** sur le nombre de coups a encaisser.
**Et oui, l'adversaire AVAIT une riposte** (`dummy.riposte_damage = 16`,
depensee par `FighterBrain._choose()` des que `is_riposte_ready()`).

### ⚠️ LA SYMETRISATION SEULE REND LE JEU TRIVIAL -- 87 a 100 % de martelage

Premiere mesure, avant toute compensation : `max_hp` a 50/50 et
`attack_damage` identique des deux cotes, tout le reste inchange. Banc reel
(les DEUX combattants pilotes, chaque tap du joueur paie une latence humaine
300-450 ms), n=300, graine 20260821.

| `attack_damage` (les deux) | martelage | esquive-panique | lecteur parfait | lecteur imparfait |
|---|---|---|---|---|
| 6 | **86,7 %** | 87,3 % | 100,0 % | 99,7 % |
| 7 | **96,0 %** | 87,7 % | 100,0 % | 99,0 % |
| 8 | **100,0 %** | 91,3 % | 100,0 % | 99,3 % |
| 9 | **100,0 %** | 88,7 % | 100,0 % | 99,7 % |
| 10 | **100,0 %** | 91,3 % | 100,0 % | 99,7 % |
| 12 | **100,0 %** | 87,0 % | 100,0 % | 99,7 % |

⚠️ **La valeur du chip ne change quasiment QUE la duree, pas le vainqueur** --
et la raison est arithmetique, pas accidentelle : **l'attaque du joueur a un
wind-up de ZERO** (lot 8), donc son cycle est `0 + 0,12 + 1,16 = 1,28 s`
contre `0,90 + 0,12 + 0,95 = 1,97 s` pour l'adversaire. A PV egaux et degats
egaux, le joueur inflige **1,54x** le DPS de l'adversaire par pure cadence, et
le combat est decide avant que la moindre lecture n'intervienne.

⚠️ **C'est le lot 8 qui parle : « an attack's damage is priced by how
avoidable it is ».** Une attaque instantanee et INESQUIVABLE payee au meme
prix qu'une attaque telegraphee de 0,9 s et esquivable n'est pas un prix egal,
c'est un avantage joueur. **La decision de Mathieu ne casse pas cette regle,
elle la deplace : le prix doit desormais etre paye en CADENCE au lieu de
l'etre en degats.**

### ⚠️ AUCUN CADRAN D'IA NE TOUCHE LE MARTELAGE -- ni un point sur huit essais

Avant de toucher a la cadence, les deux dials de personnalite de l'adversaire
ont ete balayes (D=8, PV 50/50, n=300). **Ils sont INERTES contre un
marteleur** :

| `dummy.ai_defense_rate` | 0,0 | 0,2 | 0,4 | 0,6 | 0,7 |
|---|---|---|---|---|---|
| martelage | 100,0 % | 100,0 % | 100,0 % | 100,0 % | 100,0 % |

| `dummy.ai_aggression` | 0,8 | 0,9 | 1,0 |
|---|---|---|---|
| martelage | 100,0 % | 100,0 % | 100,0 % |

Le lecteur imparfait ne bouge pas davantage (98,7 a 99,7 % partout). **Ne pas
rejouer ce balayage : il a une reponse, et elle est « non ».**

### ⚠️ `dummy.attack_recovery_s` EST VERROUILLE PAR PHASE C -- 43 ms de marge

Le levier symetrique evident -- accelerer l'adversaire -- **n'existe pas**.
`BattleDefenseProbe` PHASE C gate le fait que l'esquive PUNISSE :

```
worst_lead = (W + active + recovery)_adversaire - (tap_pire + cycle_esquive)_joueur
           = 1,97 - 1,6267 = 0,343 s     doit rester >= HUMAN_FAST (0,30)
```

`dummy.attack_recovery_s` ne peut donc pas descendre sous **~0,907** sans que
la fenetre de punition cesse d'etre prenable par un humain -- c'est-a-dire
sans rouvrir le defaut que le lot 8 existe pour fermer. **Non touche, valeur
inchangee a 0,95.** Les pics de resonance du lot 7 sur ce champ (0,44 -> 47/150,
0,56 -> 128/150) sont donc hors d'atteinte de toute facon.

### `keepy.attack_recovery_s` : le SEUL levier -- et il a CHANGE DE NATURE depuis le lot 9

Balayage a D=8, PV 50/50, n=300, graine 20260821 :

| `attack_recovery_s` joueur | martelage | lecteur parfait | lecteur imparfait |
|---|---|---|---|
| 1,16 (livre lot 9) | **100,0 %** | 100,0 % | 99,3 % |
| 1,40 | 93,7 % | 100,0 % | 99,3 % |
| 1,60 | 86,3 % | 97,3 % | 89,7 % |
| **1,80** | **89,7 %** ⚠️ | **87,3 %** | 75,7 % |
| 2,00 | 84,0 % | 87,3 % | 71,7 % |
| 2,20 | 57,7 % | 94,3 % | 73,0 % |
| 2,30 | 43,3 % | 93,7-98,0 % | 78,7-86,7 % |
| 2,40 | 25,0 % | 91,7-97,3 % | 71,0-81,7 % |
| 2,50 | 15,7 % | 92,0-96,0 % | 71,0-80,7 % |
| **2,60 (retenu)** | **11,7 %** | 94,0-96,0 % | 70,7-81,3 % |
| **2,70** | **13,0 %** ⚠️ | 93,0-96,0 % | 70,7-80,0 % |
| 2,80 | 4,7 % | 93,3-96,3 % | 70,7-80,0 % |

⚠️ **DEUX non-monotonies mesurees, la famille de resonance deja consignee aux
lots 7, 8 et 9 sur ce meme champ** : **1,80 REMONTE a 89,7 %** apres 86,3 % a
1,60, et **2,70 REMONTE a 13,0 %** apres 11,7 % a 2,60. Un balayage grossier
qui aurait saute de 1,60 a 1,80 aurait conclu que le levier ne marchait pas.

⚠️ **ET SURTOUT : ce champ ne SEPARE PLUS le marteleur du lecteur, contrairement
a ce que le lot 9 avait mesure.** Le lot 9 avait explicitement verifie que
`read+riposte` restait a 100 % sur TOUTE la plage 0,72-1,24, ce qui faisait de
`attack_recovery_s` un levier anti-martelage pur. **Ce n'est plus vrai apres
symetrisation** : entre 1,60 et 2,00 le lecteur parfait s'effondre de 97,3 a
87,3 % pendant que le marteleur ne perd que 2 points -- **a 1,80 le lecteur
est MOINS BON que le marteleur**. La raison est que la riposte est tiree par
le meme champ de timing, et qu'a PV/degats egaux le lecteur n'a plus de marge
de PV pour absorber le ralentissement. **Le levier ne redevient utilisable
qu'au-dela de 2,20**, ou le marteleur decroche enfin plus vite que le lecteur.

### La riposte est un levier QUANTIFIE : ce qui compte est le NOMBRE de ripostes pour tuer

`riposte_damage` du joueur est un levier **strictement lecteur** -- le
marteleur et l'esquive-panique n'en tirent jamais une, donc leurs lignes sont
**identiques au fight pres** sur toute la colonne. Mais son effet n'est pas
continu :

| `keepy.riposte_damage` (PV 50, rec 2,60) | ripostes pour tuer | lecteur parfait | lecteur imparfait |
|---|---|---|---|
| 18 | **3** | 94,0 % | **70,7 %** |
| 22 | **3** | 95,0 % | **71,3 %** |
| 26 | **2** | 96,0 % | **81,3 %** |

⚠️ **18 et 22 donnent le MEME resultat a un point pres, et 26 fait un saut de
10 points** : `ceil(50/18) = ceil(50/22) = 3` et `ceil(50/26) = 2`. **Le
reglage utile n'est pas « combien de degats » mais « combien de ripostes pour
tuer » -- une variable ENTIERE.** Toute future retouche de ce champ doit se
lire dans cette colonne-la, pas en pourcentage de degats.

### La riposte de l'adversaire : TRANCHEE, et son cout est chiffre

Le brief demandait de trancher explicitement. **Tranche : la riposte cesse
d'etre un avantage cote adversaire.** `dummy.riposte_damage` passe de **16 a
9**, soit `attack_damage + 1` -- la plus petite valeur que
`BattleDefenseProbe` PHASE C2 autorise (`riposte_damage > attack_damage`, gate
applique aux DEUX profils). Le mecanisme reste structurellement vivant (il
stagger, la sonde reste verte) mais le PAYOFF appartient au joueur :
**3,25x cote joueur contre 1,125x cote adversaire.**

⚠️ **Ce n'est PAS gratuit, et le chiffre est publie plutot qu'enjolive.** La
riposte adverse etait un frein anti-martelage reel : un marteleur attaque deux
fois plus souvent qu'un lecteur, donne donc deux fois plus d'occasions a
l'adversaire d'esquiver a l'aveugle et de riposter. Mesure a config finale
identique par ailleurs (D=8, PV 50/50, rec 2,60, `keepy.riposte_damage` 26) :

| `dummy.riposte_damage` | martelage | lecteur imparfait |
|---|---|---|
| 16 (avant) | **11,7 %** | 81,3 % |
| **9 (livre)** | **13,3 %** | 84,0 % |

**+1,6 point de martelage** : c'est le prix exact de l'asymetrie voulue.
Il est paye, pas cache.

### Configuration retenue

`resources/battle/keepy.tres` : `max_hp` **42 -> 50**, `attack_damage`
**7 -> 8**, `riposte_damage` **14 -> 26**, `attack_recovery_s` **1,16 -> 2,60**.
`resources/battle/dummy.tres` : `max_hp` **64 -> 50**, `attack_damage`
**10 -> 8**, `riposte_damage` **16 -> 9**.

Coups pour tuer, apres : **7 chips dans les DEUX sens** (`ceil(50/8)`) ;
**2 ripostes** cote joueur (`ceil(50/26)`) contre **6** cote adversaire
(`ceil(50/9)`). Ratio riposte/chip : **3,25x** cote joueur -- le lot 9 laissait
ouverte la question de son 2,0x « pas mesure comme insuffisant mais pas
confirme non plus » ; **ce lot le remonte franchement**, et c'est ce qui garde
une raison d'esquiver quand le chip est devenu symetrique.

⚠️ **`ai_dodge_aim` (0,70) reste calibre sur le wind-up de l'ADVERSAIRE et non
sur celui du joueur : rien de ce lot ne le touche.** De meme
`dodge_windup_s`/`dodge_active_s`/`dodge_recovery_s`, `stagger_duration_s`,
`riposte_window_s`, les cadrans `ai_*` et tout l'art (modeles `.glb`,
`model_scale`/`rotation`/`offset`) sont **intouches**.

### ⚠️ LE PRIX A ANNONCER : la commitment d'attaque du joueur passe de 1,28 s a 2,72 s

C'est le vrai cout de ce lot, et il n'est pas dissimule dans un tableau :
`attack_active_s + attack_recovery_s` passe de **1,28 s a 2,72 s (+113 %)**.
Le joueur est desormais **plus lent par attaque que l'adversaire** (2,72 contre
1,97) -- ce qui est coherent (son coup est instantane et inesquivable, il le
paie en engagement) mais represente un changement de FEEL majeur, sur le champ
que les lots 8 et 9 avaient deja allonge deux fois (0,62 -> 0,72 -> 1,16 -> 2,60).
**La riposte subit la meme recuperation** ; comme elle stagger l'adversaire
0,70 s seulement, celui-ci redevient libre AVANT le joueur apres un echange
gagne. **Aucune sonde ne dit si c'est jouable au pouce. C'est LE point de
jugement device de ce lot.**

### VALIDATION -- banc REEL du depot, 3 graines, n=300, AVANT et APRES tous deux remesures

`BattleDefenseProbe` PHASE D. La baseline n'est **pas citee de memoire** : les
`.tres` ont ete temporairement revertes et les 3 graines rejouees dans ce
sandbox (edit temporaire de la graine interne, jamais commite, revert verifie
par `git diff` vide). **Elle reproduit exactement la table publiee au lot 9**,
ce qui valide la comparaison avant d'en tirer quoi que ce soit.

| politique | AVANT (20260821 / 31415926 / 7654321) | moyenne | APRES (memes graines) | moyenne |
|---|---|---|---|---|
| **martelage** | 7,3 / 8,0 / 9,3 % | **8,2 %** | 13,3 / 13,7 / 13,3 % | **13,4 %** |
| esquive seule (`dodge-only`) | 0 / 0 / 0 % | **0,0 %** | 0 / 0 / 0 % | **0,0 %** |
| esquive-panique | 0,0 / 0,3 / 0,3 % | **0,2 %** | 0,7 / 0,3 / 0,0 % | **0,3 %** |
| lecture+riposte PARFAITE | 99,3 / 99,7 / 99,3 % | **99,4 %** | 99,0 / 97,3 / 98,7 % | **98,3 %** |
| **lecture+riposte IMPARFAITE** | 82,0 / 78,3 / 80,0 % | **80,1 %** | 84,0 / 85,0 / 90,0 % | **86,3 %** |
| duree, lecteur imparfait | 14,9 / 14,9 / 15,0 s | **14,9 s** | 13,2 / 13,0 / 12,6 s | **12,9 s** |

Objectifs du brief :
* **le martelage reste non dominant** -- OUI : 13,4 % contre 98,3 % pour le
  lecteur, soit un ecart de **85 points**. Mais il **monte de 5,2 points** par
  rapport au lot 9, et c'est dit tel quel.
* **lecture+riposte reste la meilleure strategie** -- OUI, de tres loin, sur
  les 3 graines.
* **duree 12-20 s** -- OUI sur les moyennes (10,9 a 15,9 s selon la politique).
  ⚠️ Les MAXIMA depassent : jusqu'a **22,2 s** (esquive-panique). C'etait deja
  le cas au lot 9 (23,7 s en baseline sur la graine 7654321).

### ⚠️ LE JEU EST PLUS FACILE POUR LE LECTEUR IMPARFAIT -- +6,2 points, dit franchement

**80,1 % -> 86,3 %**, et l'amelioration est presente sur les 3 graines
(84,0>82,0 ; 85,0>78,3 ; 90,0>80,0). C'est exactement le basculement que le
brief annoncait et acceptait d'avance. **Aucune compensation silencieuse n'a
ete faite** : la seule compensation appliquee est
`keepy.attack_recovery_s`, elle est le mandat explicite de la PHASE 2 du
brief, et elle a sa propre section chiffree ci-dessus. Le lecteur imparfait
n'est PAS proche de 100 % (86,3 %), donc la clause « si ca devient trivial, ne
compense pas de ta propre initiative » n'a pas eu a jouer.

**Les leviers chiffres si Mathieu veut re-durcir**, tous des editions d'UN seul
champ, deja mesures dans les tableaux ci-dessus :
* `keepy.attack_recovery_s` **2,60 -> 2,80** : martelage **11,7 -> 4,7 %**
  (mesure a `dummy.riposte_damage = 16` ; attendu ~6 % a 9), lecteur imparfait
  quasi inchange. **Cout : la commitment passe a 2,92 s.**
* `keepy.riposte_damage` **26 -> 22** : lecteur imparfait **~84 -> ~71 %**
  (passage de 2 a 3 ripostes pour tuer). Le levier le plus brutal.
* `dummy.riposte_damage` **9 -> 16** : martelage **13,3 -> 11,7 %**, mais rend
  a l'adversaire la riposte que ce lot lui retire.

### Determinisme

`BattleDefenseProbe` rejouee deux fois a la meme graine (20260806) :
**stdout ET stderr byte-identiques** (`cmp` silencieux sur les deux flux). Les
traces ONT bouge par rapport au lot 9 -- c'est le resultat attendu d'un lot
qui change sept nombres de gameplay -- mais la reproductibilite a graine egale
est intacte, ce qui est la propriete dont depend tout ce qui precede.

### Sondes

**Toutes exit 0** : `BattleDefenseProbe` (**36/36**, PHASE D rapportee
ci-dessus, gates PHASE A/B/C/C2/R/R2/E verts avec les nouveaux nombres),
`BattleContractProbe` (**46/46**), `BattleReadabilityProbe` (**65/65**),
`BattleStatsProbe` (**83/83**), `ProbeTimeoutAudit` (**37 sondes scenes**,
retour exact a la baseline apres suppression de la sonde de balayage jetable),
`AssetContractAudit` (12/12 visuels, **0/10 colliders deplaces**),
`DeathModelAudit`, `ChargerShapeProbe`.

**Aucune assertion codee en dur sur les anciennes valeurs -- verifie par grep,
pas suppose** : la seule occurrence litterale de `42` du perimetre est le
DEFAUT `@export var max_hp: int = 42` de `FighterProfile.gd`, que les deux
`.tres` ecrasent et qu'aucune sonde ne lit. Il est **laisse tel quel** (les
autres defauts de ce fichier ont deja derive de la meme facon depuis le lot 8)
plutot que touche, pour que ce lot reste strictement `.tres`-only.

⚠️ **La sonde de balayage etait une COPIE de `_policy_fight`, donc un fixture
qui pouvait diverger sur l'axe meme que ce lot change.** Parade appliquee avant
de lui faire confiance, selon la discipline maison : un run de CONTROLE sans
aucun override, qui devait reproduire la sortie de la sonde livree. Il l'a
reproduite **au fight pres sur les cinq politiques** (7,3 / 0,0 / 0,0 / 99,3 /
82,0 %). La sonde est supprimee avant commit.

`GROUP_BLOCKS` de `BattleTally` reste **fige a zero** (rules Firestore
deployees, `hasAll(statKeys())`) -- aucun champ de `BattleStats`, de
`BattleTally` ou des rules n'est touche par ce lot.

### Build et export

Editeur + templates Godot 4.3-stable installes dans ce sandbox (releases GitHub
officielles ; **tailles verifiees contre le `Content-Length` avant extraction**
-- 50 276 070 et 1 073 228 327 octets, le piege de troncature silencieuse deja
consigne). Import headless **exit 0** (24 `.scn`, import complet verifie et pas
suppose), export Web release **exit 0**. `index.wasm` **35 376 909 octets**, md5
`af4a8fc2925d992348eb30deeeb54360` ; `index.js` md5
`4e08904b1b7107858246af44b602067b` -- **identiques au fingerprint deja consigne
pour tout lot qui ne touche pas le code moteur**, coherent : ce lot ne change
que sept nombres dans deux `.tres`. Piege payload verifie sur le log
`savepack` : **0** ligne `Storing File` pour `assets_source`, `scripts/dev`,
`docs`, `web` ou `build`. `index.pck` 5 762 880 octets (export unique et
propre, `build/` supprime avant -- a lire avec la mise en garde permanente sur
son instabilite, jamais offert comme preuve).

### Reste ouvert

1. **Jugement device, et il porte sur UN chiffre precis** : la commitment
   d'attaque a **2,72 s**. Est-ce que taper et rester bloque presque trois
   secondes se sent comme un engagement lourd et lisible, ou comme un jeu qui
   ne repond pas ? C'est le seul point que ce lot ne peut pas mesurer, et
   c'est le plus gros risque qu'il prend.
2. **Le jeu est plus facile** (+6,2 points pour le lecteur imparfait, +5,2 pour
   le marteleur). Assume et annonce ; les trois leviers de re-durcissement
   ci-dessus sont chiffres et attendent la decision de Mathieu.
3. **2 ripostes pour tuer** est tres court -- deux lectures reussies suffisent.
   C'est ce qui rend la riposte « nettement plus payante » comme le brief le
   demandait, mais c'est aussi ce qui rend le combat swingy. Le voisin a 3
   ripostes (`riposte_damage` 22) coute 13 points au lecteur imparfait.
4. **`attack_recovery_s` a cesse d'etre un levier anti-martelage PUR** sous
   symetrie (section dediee) -- toute future session qui reprendrait la recette
   du lot 9 sur ce champ mesurerait autre chose que ce que le lot 9 mesurait.
5. Toujours aucun son, aucune particule, aucun second adversaire, aucune
   progression, aucun brain adaptatif, et `dodge_active_s` toujours pas touche
   (lot dedie) : hors perimetre, inchange.

### Deploiement staging (palier 1, automatique)

`staging` `9b41b5d` (merge `--no-ff`, arbre **byte-identique** a la branche
feature -- verifie avant le push, `git diff` vide). CI run **#188**
(id `32525098032`).

**Verifie SUR LE SERVICE, pas dans le log CI**, et **dans les DEUX sens** --
la valeur AVANT a ete lue avant que le deploiement ne tombe, ce que les lots
precedents n'avaient pas toujours pu faire :

| | `CACHE_VERSION` servi | = UTC |
|---|---|---|
| avant (lot 9, run #187) | `1787342427` | **20:00:27** |
| **apres (ce lot, run #188)** | **`1787345288`** | **20:48:08** |

L'epoch d'apres tombe **a l'interieur de la fenetre du run #188** (demarre
20:44:31, import a 20:45:50), et la reponse est fraiche : `x-vercel-cache:
MISS`, `age: 0`, `last-modified` colle a l'instant de la requete. L'alias
sert donc bien le build symetrise.

⚠️ **L'API GitHub Actions a de nouveau servi des reponses PERIMEES, et cette
fois SUR LES DEUX filtres.** `filter: "latest"` etait fige des le depart ;
`filter: "all"` a d'abord rendu l'etat REEL (job a l'etape « Import project
resources », 20:45:50) puis s'est fige a son tour, rendant une reponse
byte-identique plusieurs appels de suite. **Le parametre n'est ni la cause ni
le remede** -- constat deja pose au lot 6, reconfirme ici dans une troisieme
configuration. Seul le `CACHE_VERSION` servi a tranche.

⚠️ **`curl` direct vers `*.vercel.app` est refuse par le proxy d'egress de ce
sandbox** (`http_code 000`, exit 56 -- **re-teste, pas suppose** ; meme
`example.com` est refuse). Le canal MCP Vercel est le seul disponible ici,
comme deja consigne au lot 3.

`main` **non touche** (`origin/main` toujours `924d81f`, verifie apres le
push). Merge sur `staging` : palier 1, automatique.

## KEEPY BATTLE LOT 11 : EGALITE STRICTE DES CHAMPS DE COMBAT, WINDUP=0 DES DEUX COTES, LE MARTELAGE RETROUVE (22 aout 2026)

Branche `claude/lot-11-battle-balance-70gtqq`, partie de `staging`
(`924079a`, lot 10). Retour device sur lot 10 : « c'est impossible de
prendre du plaisir, c'est trop long entre deux attaques » --
`attack_recovery_s` du joueur avait grimpe a 2,6 s pour tarifer un coup
INSTANTANE et INEVITABLE, portant l'engagement a 2,72 s. Decision de
Mathieu, non negociable : `keepy.tres` et `dummy.tres` doivent porter des
valeurs **IDENTIQUES** sur tout champ de COMBAT (`max_hp`,
`attack_damage`, `riposte_damage`, `attack_windup_s`,
`attack_recovery_s`, `dodge_*`, `stagger_duration_s`,
`riposte_window_s`). Seuls les champs de DECISION (`ai_*`), `display_name`
et le groupe Art peuvent differer.

### ⚠️ `attack_windup_s` DOIT etre egal aussi -- et la MESURE, pas la
### preference, a choisi ZERO plutot qu'une valeur partagee non nulle

Premiere tentative testee et REJETEE, mesuree avant d'etre ecartee :
`attack_windup_s = 0,9` des deux cotes (redonner au joueur le meme
telegraphe que Sparring). Resultat mesure sur `BattleDefenseProbe` PHASE D
(300 combats, joueur pilote par une politique-caricature, adversaire par
le vrai brain) : **martelage (« mash ») gagne 0/300**, contre 94,3% une
fois revenu a zero. Cause : un cerveau qui suit les regles LIT et esquive
un telegraphe parfaitement regulier -- exactement l'inverse de l'issue
acceptee d'avance (« dans un duel strictement symetrique, celui qui frappe
le plus souvent gagne »). L'arithmetique de cadence ferme aussi sur zero :
`active (0,12s) + recovery (~1,10s)` font deja ~1,22s, correspondant a
l'engagement 1,28s « jouable » du lot 8 -- il ne reste aucune marge pour un
wind-up sur aucun des deux cotes.

**`attack_windup_s = 0.0` des DEUX cotes**, restaurant la cadence « jouable »
du lot 8 mais desormais partagee. `attack_recovery_s = 1.1` (le milieu de
la fourchette demandee, sous la borne dure de 1,20). `attack_damage = 6`,
`riposte_damage = 12` (choisis par sweep, voir plus bas). `dodge_*`,
`stagger_duration_s`, `riposte_window_s` etaient deja identiques et
restent inchanges.

### ⚠️ BORNE DURE `attack_recovery_s <= 1,20s`, DES DEUX COTES -- pourquoi
### elle existe et ne doit plus jamais etre franchie

Le lot 10 a rendu le jeu injouable en portant cette valeur a 2,6s pour
compenser un coup qu'on ne pouvait pas eviter. Avec la symetrie stricte de
ce lot, plus aucun cote n'a besoin d'etre compense de cette facon : le
telegraphe est desormais nul des deux cotes, donc il n'y a plus de raison
structurelle de faire grimper `attack_recovery_s`. La borne est
NON FRANCHISSABLE precisement pour empecher qu'une future session ne
recree le meme piege (« il faut juste compenser un peu plus »). Sweep de
0,90 a 1,20 fait par pas de 0,05 (voir tableau plus bas) : aucune falaise,
progression lisse -- contrairement a l'ancienne falaise documentee a
0,60/0,62 sous l'ancienne configuration asymetrique, qui ne s'applique
plus a ce design.

### Sweep mesure, pas suppose -- `BattleDefenseProbe` PHASE D, n=300, graine fixe

| recovery | mash (win / duree) | panic / read+riposte |
|---|---|---|
| 0,90 | 100,0% / 8,9s | 19,7% / 10,8s |
| 0,95 | 100,0% / 9,5s | 25,3% / 11,4s |
| 1,00 | 100,0% / 10,0s | 23,3% / 12,0s |
| 1,05 | 100,0% / 10,4s | 25,0% / 12,2s |
| **1,10 (retenu)** | **94,3% / 10,8s** | **27,7% / 12,6s** |
| 1,15 | 86,0% / 11,0s | 28,0% / 12,8s |
| 1,20 (plafond) | 73,7% / 11,4s | 28,3% / 13,1s |

`BattleContractProbe` PHASE F (mirrore, les deux cotes pilotes par le vrai
brain, rapporte, jamais gate) confirme a `recovery=1,10` :
**duree moyenne 12,84s** (min 9,03 / max 16,92), dans la fourchette 10-15s
demandee.

### ⚠️ CONSEQUENCE MESUREE, PAS CACHEE : l'esquive REACTIVE contre un coup
### instantane est structurellement IMPOSSIBLE, des deux cotes desormais

Avec `attack_windup_s = 0`, le coup se resout au tick JUSTE APRES la
demande (`request_action`), avant que le defenseur -- meme s'il vient de
demander une esquive au meme instant -- ait pu atteindre sa propre phase
ACTIVE (`dodge_windup_s` a lui seul coute 3 ticks a 60 Hz). Ce n'est pas
une fenetre etroite, c'est une impossibilite structurelle, deja documentee
comme la consequence acceptee du lot 8 pour UN seul cote ; ce lot
l'etend a l'autre. Ce qui reste : l'esquive par CHANCE DE PHASE (un
combattant deja en train d'esquiver, d'un tap anterieur, se trouve par
hasard en phase ACTIVE au tick ou un coup adverse se resout). C'est
exactement ce que mesurent les politiques `panic-dodge` / `read+riposte`
du banc -- et elles rendent desormais des chiffres **IDENTIQUES** entre
elles (27,7%), parce qu'il n'existe plus de barre a lire : « lecture
parfaite » et « panique » sont devenues la MEME politique une fois le
telegraphe supprime des deux cotes. C'est une consequence honnete du
design, pas un defaut de sonde : signalee ici plutot que masquee.

### PHASE 3 -- validation sur le banc REEL du depot, n=300, plusieurs graines

| politique | victoires | duree moyenne | duree max |
|---|---|---|---|
| **martelage (mash)** | **283/300 (94,3%)** | 10,8s | 13,5s |
| esquive seule (dodge-only) | 0/300 (0,0%) | 13,6s | 20,9s |
| panique (panic-dodge) | 83/300 (27,7%) | 12,6s | 17,2s |
| lecture+riposte parfaite | 83/300 (27,7%) | 12,6s | 17,2s |
| lecture+riposte imparfaite (3/4, jitter 140ms) | 83/300 (27,7%) | 12,6s | 17,2s |

`BattleContractProbe` PHASE E (le brain pilote le fighter du JOUEUR, pas
seulement l'adversaire) confirme l'interchangeabilite sans cas special.
Les DEUX cotes sont pilotes dans chaque mesure (piege du sac de frappe,
deja rencontre 3 fois dans ce projet).

**Engagement du joueur (windup + resolution + recuperation)** :
`0 + 0,12 + 1,10 = 1,22s` -- tres proche de la cible ~1,20s, et dans la
famille du lot 8 (1,28s, « jouable »), tres loin du 2,72s injouable du
lot 10.

**Ce que ce lot NE resout PAS, et c'est assume plutot que maquille** :
l'esquive n'est plus une COMPETENCE (il n'y a plus rien a lire), elle
est desormais un pari de timing/rythme. `ai_dodge_aim`/`ai_dodge_slop`
deviennent vestigiaux pour la defense de l'IA contre un attaquant
instantane (deja documente comme consequence acceptee du lot 8, etendue
ici) -- le chemin `_dodge_aim` de `FighterBrain._choose()` reste
inatteignable des deux cotes. `ai_reaction_delay_s`/`jitter`,
`ai_aggression`, `ai_defense_rate` restent les seuls leviers reellement
actifs (cadence et frequence de decision), et n'ont pas ete retouches
(deja raisonnables, mesures ci-dessus).

### PHASE 2 -- calibrage IA : AUCUN changement de valeur, signal plutot que reglage force

Le brief demandait de regler les `ai_*` pour qu'« un joueur qui lit
correctement gagne clairement, et qu'un joueur distrait perde ». Mesure
avant d'agir : sous `attack_windup_s = 0`, il n'existe plus de telegraphe
a lire, donc aucune combinaison d'`ai_*` ne peut recreer une distinction
entre « lecture correcte » et « panique » -- les deux politiques rendent
deja des chiffres identiques (voir plus haut), et c'est une propriete de
la mecanique, pas de reglage IA. Forcer artificiellement une difference
(ex. donner au joueur un avantage cache) aurait ete exactement la
"compensation cachee" interdite par le brief. **Signale, non corrige** :
Mathieu tranche s'il souhaite reintroduire un signal de lecture ailleurs
(hors perimetre .tres, ou dans un lot futur). Les valeurs `ai_*`
existantes (`ai_aggression`, `ai_defense_rate`, `ai_reaction_delay_s`,
`ai_reaction_jitter_s`) sont **inchangees** et deja mesurees comme
raisonnables : mash gagne clairement (94,3%), les strategies passives ou
tardives perdent la majorite du temps (27,7% ou 0%).

### Sondes adaptees -- assertions rendues fausses par le design, jamais gate en douce

Trois fichiers de sonde touches, tous des adaptations d'assertions
devenues fausses par ce changement de design, jamais des reglages
d'anciens defauts :

- **`BattleDefenseProbe.gd`** : les PHASES A/B/C/R/E testent une
  esquive REACTIVE a un telegraphe -- structurellement impossible des
  deux cotes desormais (voir plus haut). Gardees derriere
  `_windup_retired()` : rapportees une fois, jamais gate sur une
  geometrie de bande devenue vide par construction (division par
  `DummyProfile.attack_windup_s` = 0 aurait produit des NaN en cascade
  si laissee telle quelle). PHASE C2, R2 et D **inchangees** -- elles ne
  dependent pas d'un telegraphe et restent pleinement valides.
- **`BattleReadabilityProbe.gd`** : PHASE C (le telegraphe grandit sur le
  corps du combattant) et la moitie « barre dessinee » de PHASE G sont
  gardees derriere le meme `_windup_retired()` -- il n'y a plus de barre
  a dessiner ni a colorer sur AUCUN des deux fighters. Ce que PHASE G
  verifie desormais dans ce cas : la geometrie `Body/Charge` existe
  encore dans la scene (un futur lot pourrait reintroduire un telegraphe
  sans toucher `BattleFighter.tscn`) et qu'un coup instantane ne leve
  jamais la barre, sur les DEUX fighters -- exactement l'assertion que
  le lot 8 faisait deja pour le seul joueur.
- **`BattleContractProbe.gd`** : PHASE A2 (« le coup du joueur est
  instantane ») passe SANS modification -- `KeepyProfile.attack_windup_s`
  reste zero. Aucune assertion cassee ici.

**Documentation de code mise a jour** (commentaires seulement, aucune
valeur ni logique touchee) : `FighterProfile.gd` (nouveau bloc d'en-tete
« LOT 11 » expliquant le renversement de l'asymetrie du lot 8, paragraphe
« instant, unavoidable chip... » corrige pour ne plus decrire une
asymetrie qui n'existe plus) et `FighterBrain.gd` (note que le
commentaire lot 8 sur l'attaquant instantane s'applique desormais aux
DEUX fighters).

### Determinisme verifie

`BattleContractProbe` rejouee deux fois a la meme graine (20260806) :
**sortie byte-identique**, stdout compris. Aucun `randi()`/`randf()`
global touche par ce lot (seul le `RandomNumberGenerator` seede de
l'arene est utilise, comme documente par `BattleArena.gd`).

### Validation

Editeur + templates Godot 4.3-stable installes dans ce sandbox (releases
GitHub officielles, tailles verifiees contre `Content-Length`, aucune
troncature). Import headless **exit 0**, export Web release **exit 0**,
aucune erreur GDScript. `index.wasm` **35 376 909 octets** -- identique au
fingerprint deja consigne pour tout lot qui ne touche pas le code moteur
(coherent : ce lot ne touche que 2 `.tres` + 2 fichiers de commentaires
`.gd` + 2 sondes). `index.pck` 5 762 880 octets (export unique et propre,
`build/`+`.godot/` supprimes avant -- a lire avec la mise en garde
permanente sur l'instabilite du `.pck`).

**Sondes, toutes exit 0** : `BattleContractProbe` (46/46),
`BattleDefenseProbe` (8/8 gate + PHASE D rapportee), `BattleReadabilityProbe`
(24/24), `BattleStatsProbe` (83/83, inchangee -- ne depend pas des timings
d'attaque), `AssetContractAudit` (12/12 visuels, 0/10 colliders deplaces),
`DeathModelAudit` (CHARGER seul fatal, capture au 2e contact pour les 5
autres types -- inchange, ce lot ne touche aucun hazard), `ChargerShapeProbe`,
`ProbeTimeoutAudit` (37 scenes, toutes armees). Piege payload sans objet
(ce lot ne touche ni `assets_source/`, ni `scripts/dev/*` au-dela des deux
fichiers de sonde deja lies au build via `exclude_filter`).

### Reste ouvert -- jugement device, seul juge

1. **Est-ce que ~1,22s d'engagement se ressent comme jouable au pouce**,
   comme le lot 8 l'avait ete -- aucune sonde ne rend ce jugement, c'est
   l'objet meme de ce lot.
2. **L'esquive est-elle encore une option qui merite d'etre pressee** ?
   Mesuree comme statistiquement PERDANTE face au martelage (27,7% contre
   94,3%) -- c'est assume par le brief, mais reste une question de
   ressenti : un joueur qui esquive par chance de phase doit-il avoir
   l'impression de "jouer avec le systeme" ou de "presser un bouton
   inutile" ? Aucune sonde ne peut trancher.
3. **La disparition de la "lecture" comme competence** (panic-dodge ==
   read+riposte desormais) est signalee, pas corrigee -- decision future
   de Mathieu si un signal de lecture doit revenir sous une autre forme.

`main` **non touche**. Merge sur `staging` : palier 1, automatique des que
la CI est verte.

### Deploiement staging du lot 11 (palier 1, automatique)

`staging` (`3a2f6f6`), merge `--no-ff` sans conflit. CI **web-build run
#190** (id `32555358620`) **verte en 3 min 19 s** (05:49:51 -> 05:53:10
UTC) -- `Deploy to Vercel [STAGING -- staging]` succes,
`[PRODUCTION -- main]` correctement **skipped**. `main` **non touche**
(palier 2, gate Mathieu apres validation device).

**Verifie SUR LE SERVICE, pas seulement dans le log CI** (canal MCP
Vercel) : `index.service.worker.js` servi par `keepy-staging.vercel.app`
porte **`CACHE_VERSION = 1787377960|4144358`** = **05:52:40 UTC**,
tombant **a l'interieur** de la fenetre du run #190 (05:49:51-05:53:10) --
l'alias sert bien ce build. `x-vercel-cache: MISS`, `age: 0`,
`last-modified` colle a l'instant de la requete : trois signaux
independants qui disent que ce n'est pas une reponse de cache.

**Reste ouvert, inchange depuis la section principale ci-dessus** :
jugement device sur le ressenti de l'engagement ~1,22s et sur si
l'esquive-par-chance-de-phase merite encore d'etre pressee.

## INFRA : plan Firebase — Spark, apres un aller-retour Blaze non explique (21-22 aout 2026)

**Plan actuel du projet `keepy-8df91` : SPARK, depuis le 22 aout 2026.**
Confirme en Console a 0 $/mois. C'est le seul plan que ce depot doit
utiliser tant que la regle ci-dessous n'a pas ete suivie.

### Historique

Le projet est passe en **Blaze le 21 aout 2026**, sans qu'aucune session
agentique ni aucun commit de ce depot n'en soit la cause identifiee —
`Cloud Storage` et `Cloud Functions` sont tous deux **absents** du projet
a ce jour (Storage affichait encore « Premiers pas » en Console au moment
de la recon, jamais initialise ; aucune Cloud Function n'existe dans ce
depot ni dans la console). Les deux seuls produits Firebase reellement
utilises par Keepy — **Firestore** et **Authentication** — sont l'un
comme l'autre couverts par le plan Spark. Rebascule en Spark effectuee
manuellement en Console le **22 aout 2026**, confirmee a 0 $/mois. Rien
dans le code, les rules ou la config de ce depot n'a jamais exige Blaze ;
le passage du 21 aout est traite comme un aller-retour sans effet
durable, pas comme un changement d'architecture.

### Regle permanente : Blaze est une DECISION, jamais un side-effect de clic

**Cloud Storage et Cloud Functions exigent tous les deux le plan Blaze.**
Aucun des deux n'existe dans ce projet a ce jour. Si l'un devient
necessaire — l'exemple deja identifie est un **masquage cote serveur des
bonnes reponses Quizz** (`docs/QUIZZ_SPEC.md`, deja note comme necessitant
une piece serveur que ce projet n'a pas, puisque Keepy parle a Firestore
en REST direct depuis le client et que les rules ne savent pas masquer un
champ a l'interieur d'un document) — alors le passage en Blaze doit etre :

1. **decide explicitement par Mathieu**,
2. **documente dans ce fichier AVANT execution** (quel produit Blaze est
   necessaire, pour quel besoin, quel cout attendu),
3. et seulement ensuite execute en Console.

Un changement de plan Firebase n'est **jamais** un effet de bord acceptable
d'un autre clic en Console (activer un produit, explorer un onglet) — c'est
exactement le mode de defaillance du 21 aout que cette regle existe pour
fermer.

### Recommandation permanente

**Des que ce projet repasse en Blaze un jour, poser un budget GCP avec des
alertes a 50 %, 90 % et 100 %, avant tout usage reel du produit qui a
motive le passage.** Aucune session agentique ne peut poser ce budget elle-
meme (action Console/GCP) — c'est une action manuelle a faire par Mathieu
au moment de la bascule, pas apres coup.

## KEEPY BATTLE LOT 12 : LE TELEGRAPHE ADVERSE EST RESTAURE -- `attack_windup_s` N'EST PAS UN CHAMP DE COMBAT SYMETRISABLE (22 aout 2026)

Branche `claude/restore-opponent-telegraph-nkv24z`, partie de `staging`
(`75ea28f`). Corrige une CONSIGNE, pas une execution : le brief du lot 11
classait `attack_windup_s` comme un champ de COMBAT devant etre identique
des deux cotes, au meme titre que `max_hp`/`attack_damage`/etc. Cette
classification etait FAUSSE -- ce champ ne tarife rien, il GENERE la barre
de charge que le defenseur lit. Le lot 11 a suivi la consigne correctement
et a mesure sa propre consequence : esquive-panique et lecture+riposte
rendaient le MEME chiffre (27,7 %), parce qu'une fois le telegraphe
supprime des deux cotes il n'y avait plus rien a LIRE, seulement une
esquive de chance de phase. Ce lot ne corrige pas ce resultat comme un
bug -- il corrige la premisse qui l'a produit.

**Decision de Mathieu, une exception et une seule** : `dummy.tres`
retrouve `attack_windup_s = 0.9` (Sparring redevient LISIBLE).
`keepy.tres` garde `attack_windup_s = 0.0` (le tap EST le coup, inchange
depuis le lot 8). **Tous les autres champs de combat restent strictement
identiques** entre les deux profils, exactement comme le lot 11 l'exigeait :
`max_hp` 50/50, `attack_damage` 6/6, `riposte_damage` 12/12,
`attack_recovery_s` 1,10/1,10, `dodge_windup_s` 0,05/0,05,
`dodge_active_s` 0,4/0,4, `dodge_recovery_s` 0,36/0,36,
`stagger_duration_s` 0,7/0,7, `riposte_window_s` 1,2/1,2 -- verifie par
diff des deux `.tres` sur tous les champs de combat, **une seule ligne
differe**.

⚠️ **Ce n'est PAS une asymetrie de puissance.** Le hibou n'encaisse pas
plus, n'inflige pas plus, ne recupere pas plus vite, n'a pas plus de vie.
C'est la difference entre un adversaire LISIBLE et un joueur REACTIF --
sans elle il n'y a rien a lire ni a decider, seulement une course de
cadence. **Borne dure `attack_recovery_s <= 1,20 s` des deux cotes
maintenue** (1,10 des deux cotes, sous le plafond) -- rien dans ce lot
n'a eu besoin de s'en approcher.

### Perimetre du code : deux `.tres`, trois fichiers de commentaires/sondes, ZERO ligne de logique de jeu

`git diff --stat` contre `origin/staging` : `resources/battle/dummy.tres`
(un champ), `scripts/battle/FighterProfile.gd` et
`scripts/battle/FighterBrain.gd` (commentaires d'en-tete seulement, aucune
valeur ni logique touchee), `scripts/dev/BattleDefenseProbe.gd` et
`scripts/dev/BattleReadabilityProbe.gd` (adaptation d'une seule fonction
d'assertion chacun, plus leurs messages `print`). **Aucune scene, aucun
`.glb`, aucun collider, aucun script de `BattleArena.gd`/`Fighter.gd`/
`FighterView.gd`/`BattleHUD.gd` touche** -- tous generiques (`is_charging()`
keye sur la longueur de phase, `_evade_lo`/`_evade_hi` de `BattleArena.gd`
retournent deja `-1.0` si `attack_windup_s <= 0`), donc restaurer le
telegraphe cote Dummy les fait fonctionner sans une ligne a changer.

### `_windup_retired()` corrigee dans les DEUX sondes -- elle testait la mauvaise question

Le lot 11 l'avait ecrite comme `is_zero_approx(Dummy) AND
is_zero_approx(Keepy)` et gardait les phases A/B/C/R/E de
`BattleDefenseProbe` et PHASE C / la moitie "barre dessinee" de PHASE G de
`BattleReadabilityProbe` derriere elle. **Chaque phase gardee y est deja
ecrite attaquant=Dummy, defenseur=Keepy** (verifie ligne par ligne avant
tout edit) -- c'est exactement lot 8-10 restaure, pas un nouveau mecanisme.
La fonction ne testait donc jamais "y a-t-il un telegraphe dans le
combat", elle testait "y a-t-il un telegraphe du cote que CES phases
mesurent" -- et ce cote est **Dummy seul**. Corrigee en
`is_zero_approx(DummyProfile.attack_windup_s)` dans les deux fichiers,
avec les en-tetes et messages `print` mis a jour en consequence. Aucune
geometrie, aucun seuil, aucune tolerance modifiee -- seule la condition de
garde change, et elle passe desormais a `false`, ce qui **reactive** les
phases telles qu'ecrites plutot que d'en reecrire une seule.

### Validation -- editeur + templates Godot 4.3-stable installes dans ce sandbox

Releases GitHub officielles, tailles verifiees contre `Content-Length`
avant extraction (50 276 070 et 1 073 228 327 octets -- aucune troncature).
Import headless **exit 0** (24 `.scn`, complet). Export Web release
**exit 0**.

**`BattleDefenseProbe` : 36/36, PHASES A/B/C/R/E REACTIVEES et vertes** --
fenetre d'esquive 0,500..0,907 de la barre (817 ms, ferme apres le pire
humain a 450 ms), attaquant libre a 2 120 ms / cycle d'esquive 810 ms (marge
493 ms au pire tap, largement > `HUMAN_FAST` 300 ms), fenetre de riposte
1 200 ms encore ouverte au retour libre, les trois verdicts HUD distincts.
**`BattleReadabilityProbe` : 65/65**, PHASE C et la moitie barre de PHASE G
REACTIVEES -- telegraphe visible et croissant sur le corps de Sparring,
barre dessinee contraste 12,91:1 (ciel) / 4,10:1 (sol), bande d'esquive
14,89:1 / 4,73:1, et **la barre du joueur reste bien NON levee sur une
attaque instantanee** (assertion lot 8 inchangee). `BattleContractProbe` :
**46/46** (PHASE A2 -- l'attaque du joueur reste instantanee -- inchangee ;
PHASE F, rapportee jamais gatee, montre desormais Keepy-profil gagnant
40/40 en IA-vs-IA mirroite, consequence attendue et non maquillee d'un
adversaire lisible face a un attaquant instantane). `BattleStatsProbe` :
**83/83**, inchangee (ne depend d'aucun timing d'attaque). `AssetContractAudit`
(12/12 visuels, **0/10 colliders deplaces**), `DeathModelAudit`,
`ChargerShapeProbe`, `ProbeTimeoutAudit` (**37 sondes scenes**, retour exact
a la baseline apres suppression de la sonde de sweep jetable) -- **toutes
exit 0**.

**Determinisme verifie** : `BattleDefenseProbe` et `BattleContractProbe`
rejouees deux fois a la graine `20260806`, sortie **byte-identique** sur les
deux (stdout compris, `cmp` silencieux).

### PHASE 2 -- mesure, banc REEL du depot, n=900 par politique (3 graines x 300), pas suppose

Sonde jetable (jamais commitee, supprimee avant ce commit -- verifie
qu'elle disparaissait bien de `ProbeTimeoutAudit`, 38 -> 37 scenes) qui
reprend **verbatim** `_policy_fight()` de `BattleDefenseProbe.gd` (les deux
combattants pilotes -- le joueur par une politique caricature, l'adversaire
par le vrai `FighterBrain`, piege du sac de frappe deja rencontre 3 fois) et
la rejoue sur TROIS bases de graine (`20260821`, `31415926`, `7654321`), pas
une seule -- la lecon du lot 3 sur n=40. Chaque tap du joueur paie une
latence humaine 300-450 ms tiree par tap.

| politique | pooled (n=900) | duree moyenne |
|---|---|---|
| martelage (mash) | **900/900 (100,0 %)** | 10,4 s |
| esquive seule (dodge-only) | 0/900 (0,0 %) | 60,0 s *(plafond -- n'attaque jamais)* |
| **panique (panic-dodge)** | **591/900 (65,7 %)** | 17,2 s |
| **lecture+riposte parfaite** | **900/900 (100,0 %)** | 12,7 s |
| lecture+riposte imparfaite (3/4, gigue 140 ms) | 894/900 (99,3 %) | 14,2 s |

**Critere central du lot, atteint** : panique et lecture+riposte etaient
IDENTIQUES au lot 11 (27,7 % chacune) -- elles sont desormais **65,7 %
contre 100,0 %**, un ecart de **34,3 points**, stable sur les trois graines
(64,3-67,3 % pour panique). La dimension de LECTURE est reellement revenue :
lire la barre et riposter bat significativement le fait de taper au hasard
des l'apparition du telegraphe.

**Martelage reste eleve (100,0 %), et ce n'est PAS ecrase par une
asymetrie supplementaire** -- assume depuis le lot 11, aucun reglage n'a
ete ajoute pour le faire baisser. Il gagne par CADENCE : le cycle du joueur
(0 + 0,12 + 1,10 = 1,22 s) reste plus rapide que celui de Sparring
(0,9 + 0,12 + 1,10 = 2,12 s), meme si le joueur encaisse chaque coup
telegraphie sans jamais esquiver.

⚠️ **Panique depasse legerement la fourchette 10-15 s (17,2 s)** -- rapporte,
pas gate (meme discipline que `BattleDefenseProbe` PHASE D), et deja dans
la marge que d'autres lots ont acceptee pour cette meme politique
(lot 10 : maxima jusqu'a 22,2 s sur esquive-panique). Aucun reglage
supplementaire n'a ete fait pour le faire rentrer dans la fourchette --
ce n'etait pas demande et l'aurait ete au prix d'une modification hors
`.tres`.

**Engagement du joueur inchange** : `0 + 0,12 + 1,10 = 1,22 s` -- identique
au lot 11, dans la famille du lot 8 (1,28 s, "jouable"), loin du 2,72 s
injouable du lot 10.

### Ce qui n'a PAS ete touche

`ai_reaction_delay_s`/`ai_reaction_jitter_s`/`ai_aggression`/
`ai_defense_rate`/`ai_dodge_aim`/`ai_dodge_slop` sur les deux profils :
**intouches**, comme demande. Le chemin `_dodge_aim` de
`FighterBrain._choose()` redevient **atteignable** contre Sparring des
qu'un cerveau (probe mirroite ou un futur brain joueur) defend contre son
telegraphe -- il reste **inatteignable** contre le joueur, exactement
comme documente depuis le lot 8. `GROUP_BLOCKS` de `BattleTally` reste
**fige a zero** (rules Firestore deployees, `hasAll(statKeys())`) --
aucun champ de `BattleStats` ni des rules touche. Modeles `.glb`/
`ModelSlot`, attaque instantanee du joueur, fenetre de riposte, barre +
bande cote adversaire (lots 6-9) : tous **intouches**.

### Reste ouvert -- jugement device, seul juge

1. **Est-ce que le telegraphe de Sparring se lit a nouveau comme un
   signal exploitable au pouce**, sur un vrai telephone -- aucune sonde
   ne peut repondre a ca, c'est l'objet meme du lot.
2. Le martelage a 100,0 % reste la strategie dominante en absolu, meme si
   elle n'est plus indiscernable de la panique en face -- si Mathieu juge
   ca encore trop fort, le levier reste `keepy.attack_recovery_s` (deja
   documente aux lots 9/10), a re-mesurer avant tout changement.
3. Panique a 17,2 s de moyenne, legerement au-dessus de la fourchette
   10-15 s -- signale, non corrige.

`main` **non touche**. Merge sur `staging` : palier 1, automatique des que
la CI est verte.

### Deploiement staging du lot 12 (palier 1, automatique)

`staging` (`7dd5924`, merge `--no-ff`, arbre **byte-identique** a la
branche feature -- `git diff` vide). CI **web-build run #193**
(id `32598120648`) **verte en 3 min 34 s** (20:56:12 -> 20:59:46 UTC) --
`Deploy to Vercel [STAGING -- staging]` succes,
`[PRODUCTION -- main]` correctement **skipped**.

**Verifie SUR LE SERVICE, pas seulement dans le log CI** (canal MCP
Vercel) : `index.service.worker.js` servi par `keepy-staging.vercel.app`
porte **`CACHE_VERSION = 1787432354|3293683`** = **20:59:14 UTC**, tombant
**a l'interieur** de la fenetre du run #193 -- l'alias sert bien ce build.
`x-vercel-cache: MISS`, `age: 0`, `last-modified` colle a l'instant de la
requete : trois signaux independants qui disent que ce n'est pas une
reponse de cache.

`main` **non touche** (palier 2, gate Mathieu apres validation device sur
`keepy-staging.vercel.app` -- lisibilite du telegraphe adverse restaure).

## HUB PLATEAU 3D : les trois boutons deviennent trois portails, Keepy s'y rend PAR BONDS (23 aout 2026)

Branche `claude/hub-plateau-3d-bonds-wzt2oa`, partie de `staging` (`d68a157`
-- `main` etait un merge de `staging` au MEME arbre `c2d587f5`, verifie et
pas suppose). `scenes/HubWorld.tscn` remplace `scenes/Hub.tscn` comme point
d'arrivee post-connexion : un plateau 3D, trois portails, et Keepy qui se
deplace vers le point tape.

⚠️ **`scenes/Hub.tscn` et `scripts/ui/Hub.gd` sont DELIBEREMENT CONSERVES.**
C'est le rollback, et un ecran par lequel passe l'acces a TOUS les jeux ne
doit pas perdre sa version precedente dans le commit qui livre son
remplacant. Les trois appelants (`LoginScreen.gd`, `QuizzHomeScreen.gd`,
`BattleArena.gd`) pointent desormais sur `HubWorld.tscn`.

### ETAPE 0 -- l'inventaire du `.glb`, MESURE avant d'ecrire une ligne

`assets/models/keepy_squirrel_hero.glb`, parse du JSON du conteneur :
**aucun skeleton** (`skins` absent), **1 seul noeud** (`Mesh1.0`), **1 seul
mesh, 1 seule primitive**, **0 animation**, `KHR_materials_unlit`.

⚠️ **La queue N'EST PAS un noeud separe** -- elle est dans la meme primitive
que le corps. L'oscillation de queue contre-phase prevue au brief **n'a donc
pas ete tentee** : il n'y a rien a animer independamment, et decouper la
geometrie serait un lot d'asset, pas un lot de gameplay. Signale, pas
contourne.

Consequence structurante : **tout est PROCEDURAL**, sur des transforms --
meme technique que `scripts/battle/FighterView.gd`, sur le meme asset, a
travers le meme `ModelSlot`.

### DECISION PERMANENTE : le layout est une RESOURCE, jamais des transforms de scene

`resources/hub/hub_layout.tres` (`scripts/hub/HubLayout.gd`, un
`Array[Dictionary]`) porte **la totalite du placement** : 3 portails +
12 props. `scenes/HubWorld.tscn` porte la **STRUCTURE** (viewport, camera,
Keepy, les parents vides, l'UI de secours) et **ne nomme aucune coordonnee
monde**. `HubBuilder.gd` instancie au `_ready()`.

**Pourquoi c'est une regle et pas un gout** : `Hub.tscn` posait ses trois
entrees dans un container, leurs positions etaient une consequence du
layout, il n'y avait rien a regler. Un plateau 3D a le probleme inverse --
chaque prop a une position choisie a la main, et la premiere version est
toujours fausse sur device. Baker ces nombres dans la scene ferait de chaque
passe de reglage un diff sur le fichier qui porte AUSSI le viewport, la
camera et le menu de secours : un mauvais merge la coute l'ecran entier, pas
un rocher. **Deplacer un portail = editer des chiffres dans un fichier
texte.** Toute session future qui ajoute un prop l'ajoute au `.tres`.

`HubBuilder` **valide et saute** une entree malformee avec un `push_error`
plutot que de planter : une faute de frappe dans un fichier de decor ne doit
jamais etre la raison pour laquelle un joueur ne peut plus atteindre ses
jeux. Les meshes de props sont construits en code depuis des primitives, a
tessellation EXPLICITE (le piege §7.2 des collectibles), **unshaded** comme
toute surface de ce projet -- la scene n'a aucune `DirectionalLight3D`.

### ⚠️ LA REGLE QUI DONNE DU POIDS : un tap PENDANT un bond ne l'interrompt JAMAIS

`KeepyHopper.gd`. Un tap remplace la DESTINATION ; le changement est honore
**a l'atterrissage suivant**, jamais en vol. C'est toute la difference entre
un personnage qui a du poids et un curseur : une redirection en l'air ferait
pivoter Keepy en pleine parabole, et un joueur qui tape plusieurs fois de
suite le verrait vibrer sur place au lieu d'avancer. Le cout est au pire
`HOP_DURATION` (0,35 s) de reactivite. **La file est de PROFONDEUR UN** : la
seule destination interessante est la derniere.

**Un seul tween par bond**, sur un 0..1 normalise (`tween_method`), pas trois
`tween_property` paralleles -- l'arc est une parabole et le squash est
lineaire par morceaux, ce qu'aucun tween de propriete n'exprime. Trois canaux
ecrits depuis le MEME `t`, donc ils ne peuvent pas deriver l'un de l'autre :
position (`4t(1-t)`, exactement 0 aux deux bouts, donc pas de flottement par
arrondi), **squash-and-stretch** (compression au decollage ET a
l'atterrissage -- c'est ce canal qui porte le poids, et c'est pourquoi un
modele sans squelette suffit), et un pitch avant qui revient a plat a la
frame d'atterrissage.

Le corps s'oriente **avant** de quitter le sol (`_face`, ecriture directe et
non tween) : une rotation etalee sur le bond serait exactement le pilotage en
l'air que la regle ci-dessus refuse.

### Les portails ne declenchent PAS sur un overlap, et le router n'est PAS un autoload

`HubPortal` (Area3D) repond a « ce point d'atterrissage est-il dans moi ? »,
question posee uniquement sur `KeepyHopper.hop_landed`. Un `body_entered`
serait faux : un bond vise AU-DELA d'un portail traverse son volume en plein
vol, et le joueur serait avale en passant. `monitoring` et `monitorable` sont
**coupes** -- la forme reste la source unique de verite du rayon (lu sur le
`CylinderShape3D`, jamais duplique en constante), et rien ne peut recabler
`body_entered` par inadvertance. Cue d'approche : pulse en boucle sur
l'anneau, avec hysteresis (2,2 R / 2,6 R) pour qu'un Keepy pose sur la
frontiere ne fasse pas clignoter le portail a chaque bond.

`HubRouter` est un **noeud local de `HubWorld.tscn`**, pas un autoload : une
table de routage qui gagne un deuxieme appelant cesse d'etre un detail du hub
et devient un framework. Il porte aussi le garde `_leaving` (deux portails
atteints la meme frame ne doivent pas empiler deux chargements).

### ⚠️ PIEGE GODOT MESURE, ET IL ECHOUE EN SILENCE : un export de NOEUD TYPE ecrit A LA MAIN dans un `.tscn` NE SE RESOUT PAS

`@export var camera: Camera3D` avec `camera = NodePath("...")` dans le
fichier de scene rend **`null` au chargement**. La sonde de ce lot a obtenu
`null` sur les trois references de `HubTapInput` et **chaque tap mourait sur
le garde** -- aucune erreur, aucun crash, juste un plateau ou rien ne repond.
L'editeur peuple cette forme par une machinerie qu'un `.tscn` ecrit a la main
ne porte pas. **Parade adoptee : `@export var x_path: NodePath` + resolution
dans `_ready()` avec un cast et un `push_error`.** Toujours un chemin dont
l'auteur de scene est proprietaire, jamais un `get_node("../../X")` en dur.
**A connaitre avant d'ecrire un `.tscn` a la main dans ce depot.**

### Framing et sol : MESURES aux deux ratios, pas estimes

`HubCamera` suit la position AU SOL de Keepy (le y de l'arc est jete) a offset
fixe et **rotation FIXE, jamais un `look_at`** : un `look_at` reaimant chaque
frame sur une cible qui oscille de 0,6 unite par bond ferait tanguer
l'horizon entier au rythme des bonds -- bien plus visible que le personnage.
Lissage exponentiel, donc independant du framerate.

Offset `(0, 7,6, 8,9)` a **-34 deg**, `keep_aspect = KEEP_WIDTH`, `fov 45` --
**choisi par mesure** (sonde jetable, supprimee avant commit ;
`ProbeTimeoutAudit` revient a **37 sondes**) :

| offset | Keepy | portails lateraux |
|---|---|---|
| (0, 9,0, 10,5) | 104 px | labels a l'ecran |
| **(0, 7,6, 8,9) -- livre** | **124 px** | **pads a 7,8 % et 92,2 % de la largeur** |
| (0, 6,6, 7,7) | 144 px | **labels HORS CADRE** |

Verifie a **1080x1920 ET 1170x2532** : les trois labels et les trois pads
sont dans le cadre aux deux ratios, Keepy a 51-58 % de la hauteur.

⚠️ **Le sol fait 600x600 et `fog_light_color` EGALE `background_color`**
(le `SWAMP_SKY` `Color(0.062, 0.115, 0.044)`), et ce n'est pas decoratif :
a `-34 deg` avec la vfov portrait (72,7 deg a `KEEP_WIDTH`), **le haut du
cadre passe AU-DESSUS de l'horizon** (composante y du rayon `+0.041` en
1080x1920, `+0.137` en 1170x2532). Un sol trop court laissait donc voir son
bord franc : mesure a 26x26, l'arete tombait a 39 % de la hauteur d'ecran.
Avec la brume qui converge vers la couleur de fond, la jonction sol/ciel est
invisible par construction, quelle que soit la taille. Brume a **0,016** :
17 % sur Keepy, 25 % sur le portail central -- de la profondeur, pas un
delavage (les rayons de portail restent ambre).

`PLATEAU_HALF_EXTENT = 11` borne les taps. Verifie : le carre +-11 tombe
juste hors cadre lateralement, donc la borne est en pratique « le plateau
visible ». Un tap au-dela est **clampe, jamais ignore** -- un tap pres de
l'horizon est un joueur qui demande a aller aussi loin qu'il peut, et le
refuser en silence se lit comme un ecran casse.

### Le menu de secours n'est pas du poids mort

Un ecran 3D peut echouer la ou une liste de boutons ne peut pas : un contexte
WebGL qui ne revient jamais, un viewport noir, une projection de tap fausse a
un certain ratio. N'importe lequel echouerait sur le SEUL ecran par lequel
tous les jeux sont atteints. `FallbackMenu` porte les trois memes appels de
navigation, un petit bouton « Menu » a l'ecart -- le pire cas est un ecran
laid, pas un jeu inaccessible.

### Validation

Editeur + templates Godot 4.3-stable installes dans ce sandbox (releases
GitHub officielles, tailles verifiees contre `Content-Length` -- **50 276 070**
et **1 073 228 327**, aucune troncature). Import headless **exit 0** (24
`.scn`). Boot headless de `HubWorld.tscn` **exit 0, 0 erreur de parse**.
Export Web release **exit 0, 0 erreur, 0 warning** -- **les 8 scripts de
`scripts/hub/` sont compiles en `.gdc` dans le `.pck`**, ce qui est la preuve
qu'aucun n'a d'erreur GDScript. `index.wasm` **35 376 909** octets / md5
`af4a8fc2925d992348eb30deeeb54360`, `index.js` md5
`4e08904b1b7107858246af44b602067b` -- identiques au fingerprint deja consigne
pour tout lot qui ne touche pas le code moteur. `index.pck` 5 796 560 (export
unique et propre, `build/` supprime avant -- mise en garde permanente sur son
instabilite). Piege payload tenu : **0** ligne `Storing File` pour
`assets_source`, `scripts/dev`, `docs`, `web` ou `build`, sur 211 lignes.
**Aucune reference de `scripts/hub/` vers `scripts/dev/`** (grep, pas suppose)
-- `scripts/dev/*` est exclu du pack, une telle reference ne casserait QUE
dans le build web.

Sondes : `ProbeTimeoutAudit` (**37 sondes scenes**, retour exact a la
baseline), `AssetContractAudit` (**12/12 visuels, 0/10 colliders deplaces**),
`DeathModelAudit`, `ChargerShapeProbe` -- **toutes exit 0**. Non-applicabilite
verifiee : aucune sonde de `scripts/dev/` ne charge `Hub.tscn`,
`HubWorld.tscn` ni `LoginScreen.tscn`.

⚠️ **Piege deja documente, re-rencontre a la lettre** : une sonde jetable dont
le SCRIPT ne parse pas ne tombe pas vite, elle traine jusqu'au timeout (la
scene ne se charge jamais, donc rien n'arme quoi que ce soit). Symptome ici :
sortie vide et `exit 124` a 200 s, cause reelle une seule ligne
`var err := 99.0 if ... else ...` (type non inferable). **Rediriger vers un
fichier et lire le log**, plutot que de conclure a un blocage.

### Ce que la sonde jetable a mesure (supprimee avant commit)

- **Round-trip du tap : erreur 0,00000** sur quatre cibles, et quatre taps aux
  extremes du cadre (pres de l'horizon, les deux coins bas) tous clampes dans
  le plateau, aucun avale en silence.
- **Apex du bond 0,599** contre `HOP_HEIGHT` 0,6.
- **Les pieds reposent a y = -0,0000** (AABB du modele installe + transform du
  slot), donc `model_offset (0, -0,2246, 0)` et le slot a `y = 0,9` -- les
  memes chiffres que `resources/battle/keepy.tres`, repris par mesure et non
  recopies a l'aveugle.
- **La regle de commit tient, prouvee dans le sens qui compte** : depart vers
  le portail Quizz, redirection **en plein vol** (frame 6) vers Battle, et le
  joueur atterrit sur **Battle** apres 5 bonds -- l'ordre `hop_landed` puis
  `_advance()` fait qu'un portail atteint route avant d'etre depasse par une
  destination au-dela.
- **`entered` contient exactement UNE entree**, et `change_scene_to_file` a
  reellement tourne (la scene a ete remplacee sous la sonde).

### Reste ouvert -- jugement device, seul juge

1. **Est-ce que le bond se lit comme un bond** a vitesse reelle au pouce, et
   est-ce que le squash donne du poids plutot que l'air d'un modele qui
   clignote ? Aucune sonde ne le dit, c'est tout l'objet du lot.
2. **La commit-au-bond (0,35 s) se sent-elle comme du poids ou comme du
   retard** quand on tape plusieurs fois de suite ?
3. **Keepy fait 124 px de haut** sur 1920 : mesure comme le maximum
   atteignable sans perdre un label de portail, mais lisible n'est pas mesure.
4. **Pas de queue animee** (Etape 0 : elle n'est pas un noeud separe).
5. **Aucun son, aucun asset Meshy neuf, aucune persistance** : hors perimetre.
6. Derive de doc pre-existante non corrigee ici : `scripts/autoload/Quizz.gd`
   dit encore que le bouton Quizz de `Hub.tscn` est `disabled` et connecte a
   rien -- faux depuis des semaines, et sans rapport avec ce lot.

### Deploiement staging du hub plateau (palier 1, automatique)

`staging` **`8fdb591`** (merge `--no-ff`, arbre **byte-identique** a la branche
feature : meme hash d'arbre `b01d7948` des deux cotes, verifie AVANT le push).
CI run **#196** (id `32646438061`) **verte** (14:46:02 -> 14:49:27 UTC) --
`Deploy to Vercel [STAGING -- staging]` succes, `[PRODUCTION -- main]`
correctement **skipped**. **`main` NON touche** (`origin/main` toujours
`ea722bd`, verifie apres le push) : palier 2, gate Mathieu apres validation
device.

**Verifie SUR LE SERVICE, pas dans le log CI, et DANS LES DEUX SENS** --
`index.service.worker.js` de `keepy-staging.vercel.app` lu AVANT le merge et
APRES :

| | `CACHE_VERSION` | = UTC |
|---|---|---|
| avant (run #194, lot 12 docs) | `1787432682` | 22 aout **21:04:42** |
| **apres (ce lot, run #196)** | **`1787496537`** | 23 aout **14:48:57** |

L'epoch d'apres tombe **a l'interieur de la fenetre du run #196**, et les deux
lectures portent `x-vercel-cache: MISS` + `age: 0` -- ce n'est pas une reponse
de cache. L'alias sert bien le build du plateau.
