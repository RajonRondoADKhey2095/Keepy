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
