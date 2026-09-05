# Pipeline assets Meshy — les six hazards et leurs recolorisations

> Extrait de `CLAUDE.md` par le LOT H (2 septembre 2026), **verbatim** : aucune ligne réécrite, résumée ni supprimée.
> 14 section(s), 2126 lignes d'origine.
> Doctrine permanente : voir `CLAUDE.md`. Index des chantiers : `docs/lots/INDEX.md`.

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

