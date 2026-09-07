# CH35 — Socle multi-altitude : dossier de conception, complément B, rendu de terrain test et plan du lot 1 SURFACE (7 septembre 2026)

Dépôt documentaire **fidèle** (lot doc CH36, commit additionnel, 7 septembre
2026). Les trois dossiers ci-dessous ont été produits par trois sessions de
lecture/calcul distinctes le 7 septembre 2026 et livrés **en chat** : aucun
n'existait dans aucune ref du dépôt avant ce fichier (CH35-B et CH36 le
signalent tous deux). Ils sont déposés **tels quels**, dans l'ordre de leur
production — CONCEPTION, puis B, puis C — sans réécriture, résumé,
correction de style ni mise à jour de chiffre : ce sont des sources de
vérité historiques, et certains de leurs chiffres ont depuis été tranchés
par CH36 (plafond de cadre 7,968 u, `SEAT_MAX_Y` dérivé, six arbres
re-admis). Le titre de section de chaque dossier est son propre titre
d'origine. Trois dossiers déposés sur trois.

---

# CH35-CONCEPTION — SOCLE MULTI-ALTITUDE (dossier d'architecture, 7 sept 2026)

Base lue : working tree = origin/main 08229cc (branche claude/keepy-multi-altitude-socle-u80pe4,
même arbre). origin/staging fa8c807 lu en plus pour CH32/CH33 (SailBoat.gd, HubTapInput.gd,
HubTransport.gd, HubWorld.gd diffèrent ; KeepyHopper / HubRegion / HubCamera / VehicleDrive /
scripts/nav/* sont IDENTIQUES sur les deux arbres — git diff --name-only). Aucune branche
distante « altitude/montagne » (mountain-parallax-* = décor Chased, sans rapport). Aucun code,
commit, push. Godot absent du sandbox : tout chiffre ci-dessous est LU dans le dépôt ou calculé
(géométrie caméra en python), jamais mesuré par sonde ici.

## 0. RÉSUMÉ EXÉCUTIF
1. Le hub est mono-altitude par UNE constante de contrat répétée partout : Plane(UP, 0) au tap,
   y jeté dans la région, y remis à 0 par la chaîne de hops, OFFSET caméra absolu. ~300 sites.
2. VehicleDrive.step():141 n'est PAS un verrou : SandYacht et SailBoat post-traitent déjà sa
   sortie (mur, échouage). Une couche « surface » côté client suffit, sans toucher au fichier.
3. Le noyau scripts/nav est bon sur ses IDÉES (aim/destination, retrait, arc bidirectionnel,
   caméra qui suit le SOL et non le corps) et faux sur son ABSTRACTION (un niveau = un plan plat
   carré). Dehors, l'unité n'est pas le niveau, c'est la SURFACE h(x,z).
4. Frontière : hub mono-altitude + montagne = zone 5 avec h ≡ 0 partout ailleurs (option A).
   Prouvable par rejeu byte-identique. La migration totale (option B) est un chantier CH18-taille
   à faire APRÈS, jamais avant.
5. Caméra figée : la doctrine tient si « figée » = attitude figée + OFFSET depuis le point SOL
   (x, h, z), jamais depuis y = 0 ni depuis l'arc. Montée = sortie par le haut dès y ≈ 5,3 u.
6. ~25 sondes assertent « y ≈ 0 = au sol » ou posent la caméra à (x,0,z)+OFFSET : toutes
   restent vertes sous un relief que le code aurait aplati. Liste en Q6.
7. Budget : personne n'a jamais mesuré le hub sur device. Lot 0 = mesure, puis décision.
8. Sauvegarde : positions en [x, z] ; pas de bump tant que l'invariant « une surface par (x,z) »
   tient, et il doit être gaté.

## Q1 — INVENTAIRE DU COUPLAGE À y = 0
DUR = littéral 0.0 écrit / constante absolue. MOU = test 2D (XZ) ou clamp rectangulaire, vrai
tant qu'il n'existe qu'une surface par (x,z), faux dès un surplomb.

| fichier:ligne | ce qui est supposé | type | effet en pente |
|---|---|---|---|
| HubTapInput.gd:356 (staging :360) | Plane(Vector3.UP, 0.0), SEUL plan de résolution des taps | DUR | tout tap sur un sol à h≠0 vise le mauvais point (parallaxe sous 34° de pitch : à h=3, ~4,5 u d'écart) |
| HubCamera.gd:193-194 | _wanted = (x, 0, z) + OFFSET(0; 7,6; 8,9) | DUR | Keepy sort par le haut du cadre dès y ≈ 5,3 u (voir Q5) |
| HubCamera.gd:138, :186 | pose de poursuite : (x, 0, z) − heading·7,6 + (0; 4,4; 0) ; look à y=0,4 | DUR | caméra de poursuite sous le sol en montée, au-dessus en descente |
| KeepyHopper.gd:513 | hop_to() écrase y : Vector3(point.x, 0.0, point.z) | DUR | tout tap devient une destination à y=0 |
| KeepyHopper.gd:1459-1460, :1550-1551 | _begin_hop / _on_hop_finished remettent _hop_from_y/_hop_to_y à 0 | DUR | la chaîne de hops ramène le corps au plan 0 au premier pas, même posé en hauteur |
| KeepyHopper.gd:737,859,971,1139,1349,1688,1982,2052 | tous les dismounts visent _hop_to_y = 0.0 | DUR | idem, 8 sites |
| KeepyHopper.gd:695,812,928,1048,1079,1658 | garde « prop disparu » : y = 0 | DUR | le corps est reposé sous/au-dessus du relief |
| KeepyHopper.gd:1385 | RIDE_SEAT_Y absolu (0,14) sur le bateau | DUR | un ruisseau en pente est hors socle, mais la constante est absolue |
| KeepyHopper.gd:1503-1512 | _apply_hop : base = lerp(_hop_from_y, _hop_to_y) — arc DÉJÀ généralisé | — | ⚠ LA brique réutilisable : un hop en pente = ses deux y d'extrémité lus sur la surface |
| VehicleDrive.gd:95,106-107,141 | fwd/rgt plats ; position.y = 0.0 | DUR | voir Q2 |
| KartBody.gd:195 ; SandYacht.gd:177,184,199 ; SailBoat.gd(staging):179,185,209 | place()/flat_position() à y=0 avant step() | DUR | les 3 véhicules vivent à y=0 par construction |
| KartTrack.gd:37-43, :61 | spine à y=0, Y_RIBBON = 0,032 absolu | DUR | ruban et kart plats ; hors socle |
| HubRegion.gd:700 _flat, :534 _clamp_rect, :653 clamp carré | y jeté en première ligne de contains/clamp_to/zone_of/in_hole | MOU (par contrat) | reste JUSTE en pente sans surplomb ; ne peut jamais dire « à quelle hauteur » |
| HubRegion.gd:466-522 | toutes les zones = Vector2/Vector3(…,0,…) rectangles | MOU | idem ; la montagne = un rectangle + couloir de plus (une ligne par table) |
| HubWater.gd:155,174,199 ; docblock « every water surface sits within 10 cm of rest height » | membership XZ seule | MOU | un lac de montagne ne peut pas coexister au-dessus d'un lac de vallée au même XZ |
| HubNuts.gd:20, :264-275, :341, :140 | gravité vers un plan y=0 ; repos à y=0 ; reload à y=0 | DUR | une noisette lâchée en pente traverse le sol jusqu'à 0 |
| HubWorld.gd:765 | spawn de retour : Vector3(where.x, 0.0, where.z) | DUR | |
| HubWorld.gd:3274-3287 | gates de zone à y=0 ; BRANCH_OF/BRANCH_GATE (tables) | DUR/MOU | inoffensif si le couloir montagne est plat (h=0 à la porte) |
| HubWorld.gd:3152-3160 | commentaire de CONTRAT : « the y = 0 ground plane is the only plane taps resolve against » ; interceptions par état lisent le point à y=0 | DUR | tout hotspot qui lit « quel côté » sur ce point reste juste en XZ |
| HubWorld.gd:1533,1652 ; :2176 ; :2963 | ours reposé à y=0 ; travel.y = 0 | DUR | acteurs secondaires aplatis |
| HubActorWalker.gd:206, :325 ; HubCritter.gd:138,196,201 | cible à y=0 mais écrit global_position.y COURANT | MOU | marchent à altitude constante = celle de leur départ (pas à 0) |
| HubTransport.gd:40-57, :471, :512-518, :563 | docks à y=0 ; DECK_TOP + CRUISE_HEIGHT absolus ; vol = lerp plat | DUR | une ligne plateau→montagne vole sous le relief |
| HubBuilder.gd:1524 ground_footprints ; :2272 « ground is a PlaneMesh at exactly y = 0 » (slabs eau à 0,005/0,02) ; :1641 reachable = HubRegion.contains | DUR | empreintes plates (MOU) ; z-fight des slabs calé sur 0 (DUR) |
| HubWorld.tscn:43-44, :128 | Ground = PlaneMesh 600×600 (2 triangles) | DUR | LE sol ; un relief = un second mesh ou un remplacement local |
| CozyScatter.gd:183,236,260,275,336,370,389,417… ; :457-461 | tout semis à y=0 ; COVE_CAMERA_BAND à z constant | DUR | semis enfoui/flottant en pente ; la « bande caméra » devient une fonction de h |
| HubPortal.gd:65-68, :96 | « a landing is always at y = 0 » ; distance XZ | MOU | |
| HubCritters.gd:66 | HIDE_RUN_PER_HEIGHT 1,19 = tan(50°) sur SOL PLAT | DUR | modèle d'occultation faux sur pente |
| HubTrees.gd:96-98, :448 | SEAT_MAX_Y 4,85 dérivé d'une caméra à y=0 ; seat_w = seat_y·scale sans terme terrain | DUR | un arbre grimpable à h=3 : tête hors cadre, gate vert |
| HubKarting.gd:291,313,320,387 ; BoatMooring.gd:100 ; ZiplineDoor.gd:182 ; KartTrack.progress_at:170 | disques de tap XZ | MOU | vrais sans surplomb |
| HubCamera.gd:69 DRIVE_FAR 120 ; ChaseAudit.gd:58 READABLE_U 73 | portée de la poursuite | — | dimensionne le budget Q7 |
| scripts/cabin/CabinInterior.gd (seul client de scripts/nav) | niveaux à plane_y constant | — | déjà multi-niveau, par PLANS |
Recensement : le motif large `Vector3(·, 0.0, ·)` (directions comprises) sort à 307 occurrences
sous scripts/hub (KeepyHopper 50, HubWorld 35, CozyScatter 32, HubBuilder 22, HubTransport 20,
HubCove 19, KartTrack 16, HubTrees 13) ; l'idiome strict (x,0,z) comptait 59 au recensement du
design doc (docs/MULTILEVEL_NAV_DESIGN.md §1.6, avant CH26-CH33). Les deux chiffres ne sont pas
comparables ; ce qui compte est la liste des ÉCRITURES de y ci-dessus (≈ 30 sites), pas les lectures.

## Q2 — LE « VERROU » VehicleDrive (sans modifier le fichier)
Faits : step() prend position/velocity en Vector3, fabrique fwd/rgt plats (:95, :106-107), écrit
position.y = 0.0 (:141), clôture par un Rect2 XZ (:143-162), RETOURNE un dictionnaire (:163) — le
nœud est écrit par l'appelant (docblock :31-41). Les trois clients post-traitent DÉJÀ cette
sortie : SandYacht._wall (:238-254, mur région axe par axe + rebond), SailBoat (staging) traînée
d'échouage « appliquée à la vélocité APRÈS step(), jamais un clamp de position » (INDEX CH33).
Le patron « surface fournie par l'appelant » n'est donc pas une proposition, c'est l'existant.

| stratégie | mécanisme | kart / char / voilier | limites |
|---|---|---|---|
| A. post-traitement client | step() sur position plate → y = h(x,z) ; châssis incliné sur normal(x,z) ; pente = force injectée dans `velocity` AVANT step (g·sinθ le long de la plus grande pente, projetée XZ) | h ≡ 0, normal ≡ UP, force ≡ 0 → arithmétique byte-identique, gate = KartTraceProbe rejouée sur les deux arbres | off_lambda (:127-128, 1,6/s) rappelle vers max_speed toute vitesse au-delà : une descente ne dépasse pas le cap → à régler PAR INSTANCE (max_speed est une var :44, SailBoat le fait :132). Vitesse XZ conservée → v le long de la pente = v/cosθ (+10 % à 25°), acceptable pour un socle |
| B. composite « SurfaceDrive » (nom à fixer) | un RefCounted qui possède un VehicleDrive + un accesseur de surface et fait A une fois pour tous | mêmes nombres que A ; ZÉRO changement si seul le véhicule nouveau l'adopte ; migrer le kart dessus = un changement sur une conduite validée (trace obligatoire) | +1 fichier ; risque de « deux chemins » si un client fait A à la main et un autre B |
| C. fork VehicleDrive3D | copie avec y | — | REJETÉ : CH30 a extrait précisément pour n'avoir qu'une arithmétique ; le piège float32 (:64-85) prouve qu'une copie n'est jamais « la même » |
| D. le traîneau n'est pas un véhicule VehicleDrive | ride à trajet écrit (tween sur spline) | aucun impact | hors lot (c'est l'activité) ; noté comme borne : si la descente finit en trajet fixe, Q2 n'a pas d'objet et la caméra reste figée (critère CH30) |

Recommandation : B, écrit comme la formalisation de A, adopté par le véhicule NOUVEAU seulement ;
kart, char, voilier ne sont PAS migrés dans le socle (zéro changement sur trois conduites
validées device). La clôture montagne se fait comme SandYacht : WORLD_FENCE géant (SandYacht:115)
+ mur région, jamais via le Rect2 de step().
Ce qui me ferait changer d'avis : (i) si la descente exige une accélération gravitaire au-delà
du cap avec un rappel off_lambda qui se sent → la SEULE raison légitime d'ouvrir VehicleDrive.gd,
au lot descente, par un paramètre nouveau à défaut 1,6 prouvé byte-identique par trace ; (ii) si
la descente est un trajet fixe → D, pas de VehicleDrive du tout ; (iii) si les couloirs de
montagne ne s'expriment pas en région + mur axe par axe (une pente courbe étroite) → le mur de
SandYacht devient un mur le long d'une spline, toujours hors du fichier.

## Q3 — NOYAU scripts/nav : ce qui tient dehors, ce qui ne tient pas
Réutilisable tel quel (idées et code) : LevelController aim/destination + un tap = un signal
(:142-207) ; LevelTransition retrait actif (:56-74) ; LevelWalker arc bidirectionnel
(_hop_from_y/_hop_to_y, crossing :193-230, « every hub caller hard-codes _hop_to_y = 0 » :34-41) ;
LevelCamera « suit plane_y, jamais le y du corps » (:14-27, :167-171) — c'est exactement la règle
Q5, à h continu près.
Écrit pour un espace clos, ne tient pas dehors : LevelDefinition = UN plan plat carré (plane_y :76,
half_extent :79, contains :153, clamp_to :176, « as simple inside as the hub » :6-13) — une pente
n'est pas une pile de plans ; LevelController.current() = index discret (:93, :107, ground_y :132)
— dehors la question n'est pas « quel niveau » mais « quelle hauteur ici » ; plane().intersects_ray
(:130, controller :161) → il faut un ray-march sur une fonction de hauteur (déterministe, sans
collider, même doctrine « zéro PhysicsDirectSpaceState » LevelCamera:49-58) ; occultation par AABB
de nœuds d'un groupe (:100, :262) — un terrain est UN AABB, le fader = fader la montagne ;
TARGET_EYE_Y lié à la capsule de test (:112). Le design doc exclut explicitement : >2 niveaux
exercés, rendu de niveaux empilés, persistance, migration du hub (docs/MULTILEVEL_NAV_DESIGN.md
:300-316). Et le noyau n'est branché QUE dans CabinInterior.gd : le hub marche toujours sur
KeepyHopper (deux implémentations de hop, LevelWalker:6-17).
Verdict : à l'échelle, on ne généralise pas « niveau », on généralise « sol » : une Surface
{height_at, normal_at, contains, clamp_to} dont un niveau plat est le cas h = const. Les plans
empilés (cabane) gardent la transition par arc ; le relief continu marche par hops dont les deux
extrémités lisent h — KeepyHopper:1503-1512 sait déjà le dessiner.

## Q4 — FRONTIÈRE HUB / MONTAGNE
Option A (principale) — hub mono-altitude, montagne = zone 5 raccordée. Une ligne dans BRANCH_OF/
BRANCH_GATE (HubWorld:3286-3287) + un rectangle et un couloir PLAT dans HubRegion (h = 0 à la
porte). UN accesseur de surface (fichier nouveau, nom à fixer) qui vaut 0.0 partout hors du
rectangle montagne, lu par les ≈ 30 sites d'écriture de y de Q1 (tap, extrémités de hop, caméra,
walkers, noisettes, spawn, dismounts). Compromis : + comportement du hub byte-identique par
construction (h ≡ 0 → no-op), PROUVABLE (table des rides rejouée sur les deux arbres) ; + une
seule passe de plomberie ; − aucun relief possible dans les zones actuelles sans rouvrir ; − tout
système futur doit lire l'accesseur (règle « un fait publié une fois »).
Option B (alternative) — tout le monde en multi-altitude : migrer le hub sur scripts/nav (le
« lot 4/4 » différé depuis CH18, docs/lots/CH18_CABANE_NAV.md:2303, :2376) avec des surfaces
partout. Compromis : + une seule navigation, dette « deux hops » fermée ; − remplace KeepyHopper
(2 213 lignes, 12 états :382) contre lequel 8+ rides sont écrits → un chantier de la taille de
CH18 (13 sections) AVANT la première pente ; − aucune preuve byte-identique possible.
Critère actionnable pour Mathieu : « un relief doit-il un jour exister DANS une zone actuelle
(colline sur la Lande, plateau vallonné) ? » Non → A et on s'arrête là. Oui → A quand même pour la
montagne, puis B en lot séparé, jamais l'inverse. Gate de sortie qui tranche sans discussion : si,
après A, la table des rides + KartTraceProbe rejouées sur les deux arbres ne sont pas 100 %
identiques, A a fuité et est devenu B sans le dire.

## Q5 — CAMÉRA
Mesuré (python sur HubWorld.tscn:183 basis → pitch 34,0° ; fov 45 KEEP_WIDTH sur 1080×1920 →
demi-angle vertical 36,4°) : rayon haut à 2,4° AU-DESSUS de l'horizon, croisant l'aplomb de Keepy à
y = 7,97 u ; rayon bas touchant y=0 à 6,2 u au sud de Keepy. ⚠ La valeur publiée 6,96 u
(HubTrees.gd:96, CLAUDE.md) utilise 40,5° = l'angle caméra→Keepy, pas le pitch du .tscn : 1 u
d'écart, inconnu à trancher par unproject_position (calcul pur, headless OK). Dans les deux cas :
montée à pied → Keepy sort PAR LE HAUT dès y ≈ 5,3 u (tête 1,7 u) ; descente → il glisse vers le
bas du cadre et y reste jusqu'à y ≈ −15 : l'asymétrie est totale. Terrain devant lui (nord) : reste
dans l'image jusqu'à h ≈ 8 u à 5-20 u ; terrain ENTRE la caméra et lui (bande 0-8,9 u au sud) :
occulte, sans erreur (CLAUDE.md « rien de haut dans cette bande » — en pente, le sol lui-même y est).
La doctrine tient-elle ? Pas telle quelle : « figée » signifiait implicitement « OFFSET depuis
(x, 0, z) ». Amendement, règle exacte : « Caméra FIGÉE = attitude figée (aucun look_at, aucun yaw,
_hub_basis inchangée) et position = point SOL de Keepy + OFFSET, où le point sol est (x, h(x,z), z)
lu sur la surface — jamais le y du corps (l'arc), jamais 0. » C'est LevelCamera:14-27 avec h continu
au lieu de plane_y ; FOLLOW_LAMBDA (:173-175) lisse déjà, donc une montée est une glissade, pas
une coupe. Même amendement pour la poursuite (HubCamera:138, :186 : DRIVE_UP et le look ajoutés à
h, pas à 0). Le critère CH30 (pilotage continu → poursuite) ne change pas ; seule sa définition de
« sol » change. Deux contraintes de LAYOUT en découlent, gatable par sonde : (1) pour tout point
marchable P, le segment [P + (0; 1,7; 0) → P + OFFSET] reste au-dessus du terrain (la bande sud ne
cache jamais la tête) ; (2) le relief monte vers −z ou ±x, jamais vers +z (vers la caméra).

## Q6 — SONDES QUI DEVIENDRAIENT VERTES SANS RIEN PROUVER
Aucune ne passe au rouge d'elle-même ; c'est le piège. Mode de faux vert dominant : si le socle
laisse UN site de re-zéro (KeepyHopper:1550-1551 suffit), le corps atterrit à y = 0 sous le relief
et la sonde lit « au sol ».
1. Assertions « y ≈ 0 = au sol » : DivingBoardProbe:147,368,386 ; OwlFlightProbe:148,311 ;
   SeesawProbe:431 ; TurnstileProbe:377,554 ; V4ClimbProbe:267 ; ZiplineRideProbe:142 ;
   CoveProbe:715,747 ; ActorWalkerProbe:291 ; CabinProbe:938 (« the spawn carries no height »).
2. Caméra posée à la main à (x,0,z)+OFFSET puis unproject/pixels : LakeZoneProbe:417-418 ;
   CabinProbe:743,845,895,963 ; LakeMoveCaptureProbe:128,156 ; LakeZoneReconProbe:179,226 ;
   ChaseAudit STATIONS :45-52 (toutes à y=0) ; HubPerfBaseline / CozyCapture (ligne gpu lue depuis
   une caméra qui n'est pas celle du jeu, voire dans le sol).
3. Filtres géométriques plats : ChaseAudit:166,205 ne gate l'enroulement QUE des AABB « plates en
   Y » (< 0,35) → un ruban de piste EN PENTE n'est jamais gaté, le piège ruban CCW de CLAUDE.md
   redevient invisible ; HubTrees:448 (SEAT_MAX_Y sans terrain) → gate de grimpe vert avec la tête
   hors cadre ; HubCritters:66 → V6CrittersProbe (déjà INCONCLUSIVE, CH32) mesure une occultation
   fausse.
4. Membership XZ seule : HubWater.body_at:199 + WaterTintProbe — 9 échecs préexistants reproduits
   à l'identique sur staging (CH32 :32-35, CH33 :118-126 : 8 comparaisons pixel + draw nodes
   157/144 depuis CH26) → ZÉRO témoin aujourd'hui ; HubRegion.contains/zone_of via CoveProbe:115-132,
   KartProbe:95-108, LakeZoneProbe:162-163 : vraies par contrat, ne prouvent RIEN sur l'altitude,
   fausses dès un surplomb.
5. Headless : is_position_in_frustum toujours faux (CLAUDE.md) — SpawnLakeCaptureProbe:140,
   BoatMooring:173, HubTransport:616 ; aggravé si une ligne de montgolfière dessert la montagne.
6. Rouges qui masquent : SeesawProbe FAIL 157 ≠ 144 (CH32) — pas un faux vert, mais un rouge
   permanent ne peut plus signaler une régression.
Règle pour le socle : chaque assertion « y ≈ 0 » gagne une jumelle « y == h(x,z) » précédée d'un
blind check « h(x,z) ≠ 0 au point testé » — sinon la jumelle est la même assertion écrite plus long.

## Q7 — BUDGET TRIANGLES, réponse honnête
État : spawn 73 861 gpu (journal :1216), pire frame poursuite 100 520 (:1457), départ karting déjà
123 515 (HubCamera.gd:64-66), plafond 50 000 justifié pour Chased (MESHY_SPEC §7:247) et « jamais
re-justifié pour le hub » (CH22:1097), mesuré sous llvmpipe, JAMAIS sur device. Le sol actuel coûte
2 triangles (PlaneMesh 600×600). Un heightfield : 60×60 u à 1 u = 7 200 tri ; à 2 u = 1 800 ;
100×100 u à 1 u = 20 000. Le terrain n'est pas le coût : le semis l'est (la Lande lit 44-52 k, CH29).
Ordre de grandeur d'une montagne jouable (~80×80 u, maille 1 u, semis conifères/rochers au tiers
de la Lande) : +10 à 20 k terrain, +20 à 35 k semis = 30 à 55 k pour la zone SEULE, caméra figée.
Sous poursuite (far 120 u, fog 93 % à 120 u) : ~60-80 k si la montagne est isolée par le fog
(≥ 73 u = READABLE_U de toute zone dense), 120-150 k si elle jouxte la Lande. Autrement dit, la
montagne DOUBLE une frame déjà au double du plafond.
Franchement : (a) je ne peux pas dire si 100 k est un problème sur l'iPhone, et personne ne le
peut, parce que la mesure n'existe pas ; (b) un lot d'assainissement lancé sans elle peut couper
30 k pour rien ou être insuffisant. Donc le socle doit être précédé d'un LOT 0 DE MESURE DEVICE
(HubPerfOverlay existe, gaté DevTools) — et, conditionnellement à son résultat, d'un lot
d'assainissement chiffré sur la mesure (visibility_range_end par famille, cellules, far de
poursuite ramené à 73 u). Dans tous les cas la montagne naît avec un plafond gpu PAR ZONE gaté à
8 azimuts × 2 caméras dès son premier commit, jamais après.

## Q8 — SAUVEGARDE
WorldSave.gd : SCHEMA_VERSION 2 (:61). Positions stockées : yacht [x, z] (:196, relu à y=0 :192),
noisettes [x, z, kind] (:308-320, reposées à y=0 HubNuts:140), châteaux par index, arbres par id,
placed[] réservé et vide (:298). Aucune position de Keepy, aucun niveau (design doc :309).
Ambiguïté : NULLE tant que l'invariant « une seule surface par (x,z) hors cabane » tient — y se
dérive de h(x,z), le stocker serait une seconde orthographe (règle « un fait publié une fois »).
Le socle n'écrit rien de neuf → PAS de bump. Le jour d'un pont ou d'un surplomb : bump 3 additif
sur le patron _migrate (:414-428, défaut = surface 0) + un champ surface/niveau par position,
sanitisé comme la crique (:489-500), sans invalider une sauvegarde v1/v2. À faire dès le socle :
l'invariant sous forme d'assertion de sonde (blind : h ≠ 0 au point, puis y == h au repos d'une
noisette et du véhicule garé).

## DÉCOUPAGE EN LOTS (ordre = dépendance ; socle et descente séparés)
| lot | objectif | modèle | risque principal | critère de sortie prouvable |
|---|---|---|---|---|
| 0 MESURE DEVICE | fps + gpu au spawn, Lande est, pire frame poursuite, via HubPerfOverlay sur keepy-staging ; décider le plafond RÉEL | Sonnet, effort faible | lire un HIT de cache ou un ancien build comme mesure (CLAUDE.md : MISS + age 0, wasm md5) | 3 lignes chiffrées au journal + décision écrite « assainissement : oui/non, cible N k » ; en sandbox, CozyCapture rejouée aux mêmes stations pour la ligne gpu |
| 0b ASSAINISSEMENT (si lot 0 le dit) | pire frame poursuite ≤ plafond décidé | Opus | couper ce qui se voit (fog à 0,022 : 82-95 u sont les seuls ranges gratuits) | ChaseAudit sweep + CozyCapture : gpu ≤ cible aux 5 stations × 8 azimuts, pixels byte-identiques hors range cuts |
| 1 SURFACE | publier height_at/normal_at (h ≡ 0 partout, rectangle montagne encore vide) ; brancher les ≈ 30 sites d'écriture de y : ray-march du tap, extrémités de hop, caméra (Q5), walkers, noisettes, spawn, dismounts ; clamp/région inchangés | Opus, effort élevé | une fuite dans le hub (un site oublié, ou un site branché qui change un arrondi) | table des rides + KartTraceProbe rejouées sur les DEUX arbres, 100 % identiques ; SurfaceProbe neuve : avec un h de test non nul (blind : h ≠ 0 mesuré) tap→sol, hop→sol, caméra→sol+OFFSET, noisette au repos à h ; rouge-avant-vert en neutralisant h |
| 2 ZONE MONTAGNE | zone 5 (BRANCH_OF + rectangle + couloir plat), heightfield réel, semis, contraintes de layout Q5 (ligne de vue caméra→tête, pente vers −z/±x), plafond gpu par zone | Opus | cadre et occultation (bande sud), puis payload (.glb neufs) | MountainProbe : contains/clamp/zone_of/gates ; ligne de vue sur grille × 8 azimuts jamais sous le terrain ; gpu ≤ plafond aux stations × 2 caméras ; sondes Q6 groupe 1-2 doublées de leur jumelle y == h ; captures device à plusieurs azimuts |
| 3 VÉHICULE SUR SURFACE | composite Q2-B prouvé sur UN véhicule de test dans la montagne ; kart/char/voilier NON migrés | Sonnet ou Opus | dérive de la conduite validée si un client existant est touché | traces byte-identiques des 3 véhicules existants ; sonde pente : y == h chaque frame physique, châssis sur normal, descente plus rapide que montée (blind), mur région axe par axe |
| 4 ACTIVITÉ DESCENTE | luge/traîneau, règles, circuit | — | hors dossier | après validation device des lots 1-3, lot distinct |

## ZONES D'INCERTITUDE (inconnu > plausible)
- Plafond de cadre : 6,96 u (formule HubTrees:96 à 40,5°) contre 7,97 u (pitch 34° du .tscn).
  Inconnu, à mesurer par unproject_position. Change la marge de montée d'1 u.
- Aucune sonde n'a tourné dans cette session (toolchain Godot absent) : tous les chiffres sont
  lus, la seule mesure faite ici est la géométrie caméra en python.
- HubWorld.gd (4 628 lignes) lu par grep ciblé : d'autres écritures de y peuvent exister (météo,
  papillons, pluie — CozyWeather.gd n'a rendu aucune écriture de y, hauteur d'émission inconnue).
- SailBoat.gd et HubTransport.gd (staging) lus par grep, pas ligne à ligne.
- cozy_ground.gdshader lit world_pos (:92) et une peinture par rectangles (CozyPalette:61) :
  comportement sur un mesh non plan inconnu (haze, bandes de couleur).
- Eau en altitude (lac de montagne) : HubWater est XZ seule, hors socle, à trancher au lot 2.
- Le coût device réel : inconnu, c'est l'objet du lot 0.
- Le compte « 59 idiomes » du design doc est antérieur à CH26-CH33 ; mon 307 est un regex large
  (directions comprises). Le chiffre utile est la liste des écritures, pas l'un ni l'autre.
- CI/Vercel non consultées (rien à builder, rien à déployer).

## RAPPORT
BRANCH : claude/keepy-multi-altitude-socle-u80pe4 (existe localement, = origin/main 08229cc).
COMMITS : aucun. FILES : aucun fichier créé ni modifié. BUILD : aucun. DEPLOY : aucun.
VALIDATION CHECKLIST : fetch de collision fait au début (aucune branche altitude) ; base comparée
main/staging par arbre ; toutes les citations relues sur le fichier (main) ou sur origin/staging
quand indiqué ; aucune sonde exécutée (toolchain absent) — assumé et dit.
NEXT STEPS : (1) Mathieu tranche Q4 (critère « relief dans une zone actuelle ? ») et lit la
recommandation Q2 ; (2) lot 0 mesure device — c'est sur ordinateur/iPhone, pas en session ;
(3) lot 1 SURFACE seulement après le verdict du lot 0.
DOCS STATUS : ce dossier n'est PAS versionné (brief : aucun fichier). Le lot 1 devra le déposer
en docs/lots/CH35_MULTI_ALTITUDE.md et ajouter la ligne d'index ; CLAUDE.md ne reçoit qu'une
doctrine nouvelle si elle survit au lot 1 (candidate : la règle Q5 « point sol = (x, h, z) »).

---

# CH35-B — COMPLÉMENT AU DOSSIER CH35-CONCEPTION (7 sept 2026, session lecture/calcul)

Base lue : origin/main 08229cc (= HEAD de la branche, arbre byte-identique) ; SailBoat.gd, HubTransport.gd,
CH32/CH33 lus sur origin/staging fa8c807 (main en retard de 3 lots : CH32 sondes, CH33 voilier, CI
sparse-checkout — aucun .glb brut en avance, git diff --stat vérifié). ⚠️ Le dossier CH35-CONCEPTION n'existe
dans AUCUNE ref du dépôt (grep toutes branches ; docs/lots/ s'arrête à CH33) : livré en chat. Ce complément
renvoie à ses sections par leur NOM tel que le brief les cite. Un lot doc doit le déposer sous
docs/lots/CH35_*.md, sinon ce complément renverra à un fantôme (doctrine « chiffre sans source »).

Une seule exécution : sonde JETABLE FrameCeilingProbe (écrite puis SUPPRIMÉE, git status vide), import complet
préalable (154 .scn = le compte que CH33 publie comme complet), commande :
xvfb-run -a -s "-screen 0 1200x2000x24" Godot_v4.3 --rendering-driver opengl3 --path . res://scripts/dev/FrameCeilingProbe.tscn
(exit 0, 15 s, llvmpipe ; parse-check --headless --quit-after 2 avant). Aucun autre run.

## TÂCHE 1 — PLAFOND DE CADRE : 7,968 u. HubTrees.gd:96 EST FAUX.

Mesuré sur la VRAIE caméra de scenes/HubWorld.tscn:183-186 instanciée (HubWorld complet), viewport forcé
1080×1920 (container.stretch=false, piège documenté), 12 frames de settle, Keepy au spawn (0,0,0) :
- pitch réel 34,000° (basis du .tscn : forward (0, −0,55919, −0,82904)) ; demi-angles lus dans la matrice
  de projection : horizontal 22,500°, vertical 36,367° (KEEP_WIDTH, aspect 0,5625).
- rayon haut = 34,00 − 36,37 = +2,367° AU-DESSUS de l'horizontale (normal (0 ; 0,0413 ; −0,999)).
- Méthode 1 (bissection sur unproject_position(...).y < 0 à l'aplomb) : 7,9679 u.
- Méthode 2 (project_position du pixel (540, 0) à deux profondeurs, intersection z = z_Keepy) : 7,9679 u.
  is_position_in_frustum : vrai à 7,50, faux à 7,97. Concordance au 1e-4.
- Formule HubTrees.gd:96 recalculée avec les angles mesurés : 6,957 u ; formule au pitch réel : 7,968 u.

Laquelle est fausse et pourquoi : HubTrees.gd:96 écrit 7.6 − 8.9·tan(40.5° − 36.4°). Le 40,5° est
atan(7,6/8,9), le pitch qu'aurait une caméra qui REGARDE le point-sol de Keepy. Or HubCamera est à ROTATION
FIXE (HubCamera.gd:5-9 « Fixed ROTATION, not look_at ») et le .tscn porte −34°. La formule suppose un
look_at qui n'existe pas ; le signe s'inverse (le rayon haut monte au lieu de descendre) : 1,01 u d'écart.
HubTransport.gd:160-162 (staging) « top ray at +2.4 deg over 8.9 u from a 7.6 u camera », mesuré sur
capture, avait la bonne valeur ; CLAUDE.md (« y = 6,96 u ») recopie la fausse. Aucune sonde ne gate ce
chiffre : il a survécu deux lots.

Altitude de sortie de la tête (1,7 u, mesure v4 non re-vérifiée ici) : base du corps à y = 6,268 u à
l'aplomb. Le plafond varie avec la profondeur (rayon incliné) : dz −6 u (sud) 8,216 · dz −3 8,092 · aplomb
7,968 · dz +3 (nord) 7,844 · dz +6 7,720. Bas du cadre à l'aplomb : −17,35 u (dz −6 : −34,2) — une DESCENTE
n'est jamais plafonnée par la caméra.

Conséquence sur SEAT_MAX_Y (4,85) : dérivé de 6,96 − 1,7 − 0,4 de marge. Au vrai plafond, la tête d'un
siège à 4,85 est à 1,418 u sous le bord (pas 0,4). La même marge de 0,4 donnerait SEAT_MAX_Y = 5,87. Les
« huit arbres exclus pour cette seule raison » (CLAUDE.md, CH26) le sont sur un chiffre faux ; combien
redeviennent admissibles à 5,87 = inconnu (HubTrees:449 n'est gaté par aucune sonde qui publie la liste).
Aucun changement fait : lot cadré (constante + re-gate + RENDU des sièges, doctrine « jamais relecture »).

Pour le multi-altitude : la caméra jette le y de Keepy (HubCamera.gd:193 Vector3(target.x, 0.0, target.z)).
Tant que l'amendement caméra du dossier n'est pas codé, un Keepy qui MONTE à pied sort la tête du cadre à
h = 6,27 u (pas 5,26). Si l'amendement fait suivre le y réel, le plafond ne contraint plus la marche,
seulement les rides à siège fixe. À publier : FRAME_TOP_AT_APLOMB = 7,968 u, gaté par une sonde qui relit
unproject_position (10 lignes : viewport forcé, bissection sur .y < 0) — jamais par une formule.

## TÂCHE 2 — INVENTAIRE COMPLÉMENTAIRE DES ÉCRITURES DE y

Méthode : HubWorld.gd lu EN ENTIER (code seul, 1 668 lignes hors commentaires) ; CozyWeather, SailBoat,
HubTransport (staging), HubWater, HubRegion, LevelDefinition en entier ; grep exhaustif scripts/hub/**
(.y =, position =, global_position =, transform =, Vector3(x, 0.0, z)) puis contexte de chaque site.
DUR = littéral 0 ou constante MONDE ; MOU = y d'un porteur/repère local, ou conservé ; « inerte-A » =
reste juste sous l'option A parce que l'objet reste à h = 0.

| fichier:ligne | supposé | DUR/MOU | effet en pente |
|---|---|---|---|
| CozyWeather.gd (120 l.) | aucune écriture de y — CONFIRMÉ | — | l'émission est ailleurs ↓ |
| CozyScatter.gd:1281 _precip_node.position=(p.x,0,p.z) + cozy_precip.gdshader:30-33 (boîte 0..9 u au-dessus du nœud) | pluie/neige de y=9 à y=0 MONDE, ±7 u autour de Keepy | DUR | à h=20 la pluie tombe 11-20 u SOUS le sol : ciel sec sur la montagne. Suiveur global |
| CozyScatter.gd:1283-1286 ombre à SHADOW_Y+0.005, lift=clamp(p.y,0,1.5) | y = hauteur en l'air | DUR | ombre enterrée, rétrécie 25 % en permanence dès h ≥ 1,5 |
| CozyScatter.gd:183,236,260,264,275,336,359,370 (2 246 instances, p=(x,0,z), transforms cuites MONDE) | semis à 0 | DUR | tout semis sur un domaine échantillonne la surface AU SEMIS |
| HubWorld.gd:765 retour cabane (where.x,0,where.z) | porte à 0 | DUR | spawn sous/sur une porte en pente |
| HubWorld.gd:978-981 vol hibou y=OWL_LOOP_APEX·sin(πt) | apex ABSOLU, perchoir à 0 | DUR | hibou sur domaine vole à y monde 0..3,6 |
| HubWorld.gd:1533,1652 ours (x,0,z) ; 2131/3032 blaireau (_badger_rest:2166) ; 2346 site feu (SITE Vector2) | acteurs remis à 0 | DUR | inerte-A |
| HubWorld.gd:1559,1615,2874,2958,2850,1007 to_global / ancres builder | y du porteur | MOU | juste par construction |
| HubWorld.gd:1743-1744,3336 _ride_exit_point / clamp_to → y=0, consommés par hop_to | destination plate | DUR-inerte | hop_to (KeepyHopper:500) aplatit de toute façon : c'est LÀ qu'on rebase |
| HubWorld.gd:3673 bateau ← ride_moved (RIDE_SEAT_Y) | ruisseau à 0,095 | DUR | inerte-A |
| HubWorld.gd:4362/4623 KEEPY_WATERLINE_Y=0.45 (monde, 5 corps) ; 4417/4590 SPLASH_RING_Y=0.12 | surface d'eau ~0 | DUR | tâche 5 : eau en altitude = ligne de flottaison invisible |
| KeepyHopper.gd:500 _target=(point.x,0,point.z) | ENTRÉE de toute marche | DUR | point d'insertion de l'accesseur (tâche 6) |
| KeepyHopper.gd:1459-1460,1550-1551,1192-1193,1981-1982,2051-2052,2135-2136 _hop_from_y/_to_y=0 | ligne de base plate | DUR | 6 sites (le dossier en citait 3) ; 1512/1548 restent la brique généralisée (MOU) |
| KeepyHopper.gd:695,812,928,1048,1079,1658,2211 (x,0,z) sorties de ride ; 736-737,858-859,970-971,1138-1139,1348-1349,1687-1688,2174-2175 _hop_to_y=0 | 7+7 démontages atterrissent à 0 | DUR | tout ride posé sur un domaine ressort SOUS le sol |
| KeepyHopper.gd:1385 RIDE_SEAT_Y ; 1304-1305 deck_height ; 1712,1729,1737 véhicule (x,0,z) | hauteurs monde | DUR | inerte-A sauf balle/char sur un domaine |
| HubActorWalker.gd:329,333 ; HubCritter.gd:196,201 (t.x, global_position.y, t.z) | y CONSERVÉ, jamais ré-échantillonné | MOU-figé | un acteur qui entre sur une pente flotte/s'enterre |
| HubCat.gd:273,277 pop y=0 ; HubBoar:130, HubBeaver:98/107, HubFawn:112/133 (REST/GRAZE y=0) | sites à 0 | DUR | inerte-A |
| HubNuts.gd:261-275 repos y∈{0,ACORN_LIE_Y} ; 341 if pos.y<=0.0 ; 439 feuilles 0.02 ; 369 bob | SOL = y 0 pour la gravité | DUR | une noix d'un arbre de montagne traverse le terrain jusqu'à y=0. Suiveur global |
| HubTrees.gd:292 spec["at"] (TREES y=0) ; 466 porteurs adoptés ; 449 SEAT_MIN/MAX_Y en unités MONDE | arbres à 0, siège gaté en absolu | DUR | un arbre sur domaine à h=3 est REFUSÉ (seat_w > 4,85) : gate à rendre relatif au pied |
| HubTransport.gd (staging):259,270,280 docks/panneaux/fanions ; 292/756 BALL_PARK ; 313 char (WorldSave XZ seul, :188-196 y=0 reconstruit) ; 326 voilier ; 609/703 ballon DECK_TOP ; 656 vol DECK_TOP+lift (docks à 0) | ABSOLU | DUR | une ligne de ballon vers un sommet (le transport évident de l'option A) doit interpoler dock.y |
| SailBoat.gd (staging):179-185 flat_position/place ; 209-221 moved = sortie de step() (VehicleDrive:141 position.y=0.0) ; 109 SEAT local | mer à 0 | DUR / MOU | inerte-A ; le post-traitement (drag) existe mais NE rebase PAS y aujourd'hui |
| KartBody.gd:195 place ; 218 global_position=out["position"] (y=0, AUCUN post-traitement) ; SandYacht.gd:185,203 _wall plat | y de step() écrit tel quel | DUR | ⚠️ nuance au « faux verrou » : le kart est le SEUL client qui écrit la sortie brute ; les deux autres passent par une fonction où un rebase est possible. Inerte-A |
| HubRegion.gd:534 _clamp_rect, 646-697 clamp_to, 699 _flat | toute destination à y=0 | DUR | rappel Q1 ; inerte SI le hopper ré-échantillonne |
| HubTapInput.gd:356 Plane(UP,0) ; HubCamera.gd:193 _wanted jette y | rappel Q1 | DUR | chiffré tâche 1 (6,27 u) |
| HubBuilder.gd:1648 node.position=where (layout y=0) ; 2286-2303 slabs ; 1505 ground_footprints y=0 ; 2898 échelles | props de layout à 0 | DUR | inerte-A ; un prop SUR un domaine doit lire la surface |
| HubCove.gd:168,176-181,238,244-254,263,277,285,292,300,427,453 ; HubCampfire.gd:245 ; BoatMooring.gd:125,136 ; HubKarting.gd:320 ; ZiplineDoor.gd:174 | tout à 0 / local | DUR inertes-A / MOU | aucun ne quitte h=0 sous l'option A |
| WorldSave.gd:188-196 cove_yacht persiste [x,z] | y jamais persisté | — | BON : y se DÉRIVE de XZ, rien à migrer dans le schéma 2 |

Sites qui contrediraient l'option A : AUCUN ne l'interdit. Mais quatre SUIVEURS GLOBAUX cassent sur la
montagne même si le hub n'est pas touché : (1) HubCamera:193 ; (2) CozyScatter:1281-1286 pluie + ombre ;
(3) HubNuts:341/439 plancher de gravité ; (4) HubActorWalker/HubCritter y figé. Plus deux constantes MONDE
(SEAT_MAX_Y, KEEPY_WATERLINE_Y) à rendre relatives le jour où arbres/eau montent. Le lot 1 doit porter
(1)+(2) au minimum ; (3)(4) attendent qu'un acteur ou un arbre monte.

## TÂCHE 3 — SHADER DE SOL SUR MESH NON PLAN (calcul, pas rendu)

cozy_ground.gdshader:92 world_pos MONDE, fragment sur p = world_pos.xz (:99). Déterministe sans rendu :
- Étirement : toute texture (patch 26 u, détail 5,5, mottle 1,7, cellules 2,6) est projetée VERTICALEMENT
  → facteur 1/cos(pente) le long de la ligne de plus grande pente : 15° ×1,04, 30° ×1,15, 45° ×1,41,
  60° ×2,0, falaise → ∞ (stries verticales d'une seule colonne de texels). Bandes (autumn/moor/circuit
  _edge_z, field_0..2, cove_rect, disque mer) en xz aussi → une frontière de bande GRIMPE le relief comme une
  courbe de niveau verticale ; continue (smoothstep), aucune discontinuité, mais un versant coupé par
  moor_edge_z serait bicolore en travers de la pente. Sur un domaine séparé, aucune bande ne le traverse si
  son AABB est hors des rectangles — à ASSERTER à l'enregistrement.
- Haze (:175-177) : length(view_pos) = distance caméra→fragment vraie. Cohérente quelle que soit h : un
  versant plus proche est moins hazé, correct par construction. Ce qui change : le haut du cadre montre
  aujourd'hui du sol lointain hazé vers SKY (CozyPalette:14-18) ; une montagne à 30 u devant l'occupe à
  48 % de haze (1−exp(−30·0,022)) et lit comme un relief flou, pas comme un ciel. haze_start 8 / 0,022
  sont réglés pour un sol plat : non prévisible, rendu requis.
- Z-fight des slabs (_make_water_body bank 0,005..0,055, water 0,02..0,08 ; table HubBuilder:352-369) :
  supposent le sol EXACTEMENT à 0. Sous l'option A les 5 corps restent en zone plate → rien ne change SI
  ET SEULEMENT SI la partie plate reste un PlaneMesh à y = 0,0 exact (pas un height-field « ≈0 »). Contrat
  lot 1 : sol des zones existantes bit-identique, relief = mesh SÉPARÉ (un quad 600×600 subdivisé à 1 u =
  720 k triangles). Un disque d'eau sur un domaine = bassine plate creusée dans le height-field, jamais
  un slab sur une pente.
- Tranché sans rendu = OUI pour la géométrie, NON pour la lisibilité (le ×1,15 à 30° sous le mottle ? la
  montagne hazée lit-elle comme relief ?). Rendu minimal, NON lancé : gaussienne test 40×40 u sommet 12 u
  au sud du spawn ; 3 stations (pied à 10 u, mi-pente, sommet) × 3 pentes (15°, 30°, 45°) + 1 falaise 80° ×
  3 orientations du versant (face caméra, flanc est, dos — la caméra ne yaw pas) = 36 captures offscreen,
  SUN puis RAIN (wet assombrit/sature : le stretch se voit mieux). xvfb + opengl3, jamais headless.

## TÂCHE 4 — MESURE DEVICE (lot 0) : PROTOCOLE

Ce que l'overlay AFFICHE RÉELLEMENT (HubPerfOverlay.gd:187-193 _format, 4 lignes) : FPS n (min m) [min
glissant 3 s, :44/:73-76] · TRI gpu / lod0 cadre / scene [:88-90 render_info, :116 replay frustum, total
scène] · DRAW calls / obj / cadre n/N / inst · METEO. Gate : HubWorld.gd:4229 DevTools.enabled()
(?keepydev=1, DevTools.gd:39-41,68-81) ; bouton « Perf (dev) » du menu Fallback (:4231-4259) ; rangée
météo forcée (:3723-3730 SUN/RAIN/STORM/SNOW/AUTO) au même gate.
MANQUE (prérequis de code, non inventés) : (a) POSITION/ZONE de Keepy — l'overlay n'a aucune référence à
Keepy (@export :33-37) ; les stations sont donc nommées par REPÈRES VISUELS ; (b) engine_prims sous
WebGL2 : le fichier (:13-15) ne suppose pas que le backend le remplit, un 0 sera affiché 0 ; (c) pas de ms
(FPS entier suffit à 60 Hz) ; (d) aucun marqueur de build à l'écran. Prérequis lot 0 recommandé (≈15
lignes, PAS fait) : ligne POS x z zone + BUILD CACHE_VERSION dans _format, Keepy via un NodePath (jamais un
export typé, piège documenté).

Avant de tendre le téléphone (côté session) : relire index.service.worker.js via le canal MCP Vercel
(egress direct refusé) : x-vercel-cache: MISS + age: 0 + CACHE_VERSION dans la fenêtre Export Web build,
ET index.wasm 35 376 909 / md5 af4a8fc2. Un HIT n'est pas une mesure. Contrôle Mathieu : ouvrir
https://keepy-staging.vercel.app/index.service.worker.js dans Safari (texte brut), lire CACHE_VERSION,
égal à celui publié par la session. Fermer l'onglet du jeu, le rouvrir (le SW peut servir l'ancien build
un chargement de plus).

Protocole (https://keepy-staging.vercel.app/?keepydev=1, iPhone ≥ 50 % batterie, pas en charge, luminosité
fixe ; relevé = CAPTURE D'ÉCRAN, une par ligne) :
0. Menu Fallback → « Perf (dev) : ON » → météo SUN. 10 s immobile.
1. S1 spawn (Keepy tel que chargé, caméra figée) : 20 s ; captures à 10 s et 20 s. RÉFÉRENCE.
2. S1-storm : STORM, 15 s, capture (900 quads + overlay alpha plein écran : pire fillrate connu). SUN.
3. S2 porte du Vallon : entrée du couloir ouest vers le vallon d'automne (−28 ; −38,5), dans le couloir
   face au sud ; 10 s ; capture.
4. S3 Arbre-Mère : au pied du grand arbre du vallon (0 ; −62), 10 s ; capture (semis le plus dense).
5. S4 porte de la Lande : couloir (12 ; −82) face aux champs de lavande, 10 s ; capture.
6. S5 kart, ligne de départ, CAMÉRA DE POURSUITE : monter, rester ARRÊTÉ sur la grille 10 s ; capture
   (123 515 primitives mesurées en sandbox : pire frame connue). Un tour complet ; capture à la fin.
7. S6 Crique : au char à voile (48 ; −112), monter, arrêté face à la mer 10 s ; capture ; S6-storm :
   STORM 15 s ; capture ; SUN.
8. S7 en altitude : grimper climbtree_0 (6 ; 0) près du spawn, assis 10 s ; capture — la seule vue
   « caméra sous le corps », référence du cadre montagne.
9. S8 ballon Corail (dock sud (−13 ; −33) → Crique) : capture en vol (4 zones traversées, croisière 4 u).
10. S1 retour : spawn, SUN, 20 s, capture — écart avec l'étape 1 = dérive THERMIQUE.
≈ 8 min. Ordre = du figé à la poursuite, SUN avant STORM, référence répétée en fin.

Grille de décision (FPS plafonné 60 par Safari ; si l'overlay lit > 60, plafond 120 et seuils ×2) :
| lecture | verdict |
|---|---|
| toutes stations SUN moy ≥ 50 ET min ≥ 40 ; STORM min ≥ 35 ; S1 retour ≥ 0,85 × S1 | PAS de lot 0b. Budget montagne = le gpu (ou lod0 si gpu = 0) de la PIRE station tenue ≥ 50 : la montagne ne le dépasse pas à sa pire station, gaté par sonde |
| une station SUN moy < 45 ou min < 30 | lot 0b sur CETTE station ; cible moy ≥ 50 / min ≥ 40 au même protocole ; leviers : visibility_range_end (−20 k prims mesurés), DRIVE_FAR 120, comptes de batches ; jamais un asset |
| seulement STORM < 35 | 0b limité à PRECIP_COUNT 900 et alpha de WeatherOverlay |
| S5 seul < 45 | 0b caméra de poursuite ; la montagne (cadre figé) n'attend pas 0b |
| S1 retour < 0,85 × S1 | thermique : refaire sur iPhone froid ; si reproduit, 0b sur la charge moyenne |
| TRI gpu = 0 partout | WebGL2 ne remplit pas render_info : lod0 cadre devient LA ligne gatée, à écrire dans PROBE_AUDIT |
Seuils : 50/40 = un hop de 0,28 s reste 14 frames à 50 ; 30 = FOLLOW_LAMBDA 5,0 lisse visiblement par
paliers. Aucun chiffre device au dépôt (grep iPhone ∧ fps : seule la promesse CH26 l.142) : a priori à
corriger sur la première série.

## TÂCHE 5 — EAU EN ALTITUDE (conception)

HubWater = tableau XZ (_discs, y aplati :174,199), islet-test, ruban ; body_at ignore y par contrat
(:179-181). Sous l'option A :
- Lac de montagne : OUI, sans toucher le contrat des 5 disques. Le tableau anticipe une ligne de plus
  (:159 « a third lobe would report as one without an edit », :193). Un 6e disque &"mountain_lake",
  centre/rayon publiés par le bâtisseur du domaine, disjoint en XZ de tout corps à h=0 (domaines disjoints,
  tâche 6) → membership inchangée. Ce qui DOIT changer (3 constantes MONDE, tâche 2) : KEEPY_WATERLINE_Y
  0,45 et SPLASH_RING_Y 0,12 deviennent surface_y + offset posés à l'entrée dans l'eau (HubWorld:4458
  _set_keepy_wet connaît le corps via body_at) ; les slabs se posent à lac_y + … sur un fond de bassine PLAT
  creusé dans le height-field (Keepy patauge au niveau du fond : fond = surface du domaine à lac_y − 0,08,
  plat dans le disque). cozy_water (world_pos.xz + haze par distance) n'a rien à apprendre. Le sol reste
  herbe sous le lac (sea-bed peint par sea_centre seul) : alpha 0,82 sur vert = l'étang d'aujourd'hui.
- Torrent (ruban en pente) : NON sans toucher le bateau. STREAM_SURFACE_Y 0,095 constante, _place_on_route
  écrit RIDE_SEAT_Y (KeepyHopper:1385), HubStreamRoute.distance_to plat, bateau lit ride_moved
  (HubWorld:3673). Exige une spine 3D interpolée en y, un siège relatif, et un RENDU (eau alpha en pente
  jamais vue ; doctrine transparents Safari). La montagne naît avec au plus un lac immobile ; le torrent
  est un lot ultérieur.
- Gate : WaterTintProbe N'EST PAS VERTE (9 échecs pré-existants, 157/144 nœuds partagés avec SeesawProbe
  depuis CH26 ; CH32 : compte 4→5 ; CH33 : rejouée deux arbres, 9/9 identiques). Un 6e disque REFAIT le
  coup de CH32 (compte à 6) et se prouve par COMPARAISON deux arbres (9 → 9), jamais par la couleur d'un run.

## TÂCHE 6 — ACCESSEUR DE SURFACE MULTI-DOMAINES

Forme retenue (noms PROPOSÉS, aucun n'existe dans le dépôt) : un HubSurface statique, une REQUÊTE sans
règle (patron HubWater : refuse aucun tap, ne clampe rien, ne bouge rien).
- HubSurface.height_at(flat: Vector3) -> float — y de la surface marchable en (x, z) ; 0,0 hors domaine,
  par contrat. HubSurface.domain_at(flat) -> int (−1 = socle). normal_at seulement si le lot 1 incline le
  corps (pas requis : le hop est un arc sur une ligne de base, KeepyHopper:1504-1512).
- static var _domains: Array[Dictionary] — TABLE DÈS LA PREMIÈRE ENTRÉE (doctrine plongeoir) :
  {"name", "aabb": Rect2 (xz), "grid": PackedFloat32Array, "pitch", "origin": Vector2}.
- Coût à un seul domaine : N rejets AABB (N = 1) puis UN échantillon ; zéro domaine = une comparaison. Pas
  de structure spatiale tant que N < ~10.
- L'échantillon lit LE MESH DESSINÉ, pas une formule : le domaine possède une grille ; le mesh est construit
  DEPUIS cette grille avec une diagonale de triangulation FIXE ; height_at fait le barycentrique sur la MÊME
  triangulation → les pieds sont exactement sur le triangle vu (doctrine « l'AABB n'est pas la forme »,
  « fixture qui diverge du réel »). Une fonction analytique ne sert qu'à REMPLIR la grille. Grille float32
  (le mesh l'est), pas 64 (piège rotation.y float32 du CH30 : deux précisions = deux surfaces).
- Budget : 60×60 u à 1 u = 7 200 triangles LOD0 (vs 52 k gpu au spawn) ; 0,5 u = 28 800, hors budget tant
  que la tâche 4 n'a pas parlé. Pas de grille = constante du domaine, pas une globale.
- Composition avec HubRegion : HubRegion reste 2D (« peut-il se TENIR ici »), HubSurface répond « à quelle
  hauteur ». Un domaine n'est PAS une zone : la montagne (option A) est une zone (zone 5, BRANCH_OF +
  BRANCH_GATE, arbre CH29) ET un domaine ; une colline sur la Lande (Q4) est un domaine DANS la zone 2.
  contains()/clamp_to() ne changent pas ; le rebase se fait UNE fois dans KeepyHopper.hop_to/_begin_hop
  (les 6 _hop_*_y = 0 de la tâche 2 → height_at(from)/height_at(to)), puis dans les suiveurs globaux. C'est
  littéralement « la seule brique réutilisable » de docs/MULTILEVEL_NAV_DESIGN.md §1.3.
- Frontière domaine/domaine : INTERDITE PAR CONTRAT (AABB disjoints, assertés à l'enregistrement). Pas de
  blend à écrire.
- Frontière domaine / h=0 : RACCORD CONTINU C0, hauteur EXACTEMENT 0 sur tout le périmètre de l'AABB, gaté
  par sonde (périmètre à 0,5 u, |h| < 1e-4, ROUGE AVANT VERT en décalant la grille de 0,01). Une MARCHE est
  interdite au lot 1 : le hop de 0,45 u ne distingue pas une marche d'une pente, et une falaise sans état
  est un joueur enterré. Le jour où une marche est voulue, c'est une TRANSITION DE NIVEAU — le métier de
  scripts/nav (LevelTransition), pas de l'accesseur.
- Pente max : constante du domaine, à mesurer au lot 1 sur l'arc (HOP_DISTANCE × pente = gain par hop) et
  sur le cadre (6,27 u de montée avant l'amendement caméra ; « 13° et plus pour qu'une pente LISE »).
- Dette « deux implémentations de hop » (KeepyHopper vs scripts/nav/LevelWalker ; LevelDefinition.gd = un
  PLAN par niveau, plane_y constant, flat() = Vector3(x, plane_y, z)) : NON bloquante pour l'option A (la
  montagne est du hub ; scripts/nav n'est utilisé que par CabinInterior — grep). NON bloquante pour la
  migration générale tant que le raccord reste C0. Elle DEVIENT bloquante au premier lot qui veut une MARCHE
  (falaise, terrasse) : là plane_y et height_at doivent être la même chose. Nommer ce lot
  « marche/falaise », le placer APRÈS la migration générale, y unifier avant la première marche.

## ZONES D'INCERTITUDE — MISE À JOUR

Fermé : plafond de cadre (7,968 u, deux méthodes, cause nommée) ; sortie de tête 6,268 u ; SEAT_MAX_Y
conservatif de ~1 u ; inventaire y de HubWorld entier, CozyWeather (aucune), CozyScatter (pluie y 0..9
monde, ombre), SailBoat, HubTransport staging, HubTrees, HubNuts, acteurs, kart ; lac de montagne possible /
torrent non ; forme de l'accesseur ; frontières (disjoint / C0 exact) ; statut de la dette hop.
Ouvert (préférer « inconnu ») : (1) tête 1,7 u = « v4's measurement », non re-mesurée sur les vertices
skinnés (os ≠ silhouette, ~0,16 possible) ; (2) FPS device : INCONNU, aucun chiffre au dépôt ; (3)
engine_prims sous WebGL2 : inconnu jusqu'à la première capture ; (4) lisibilité de l'étirement 1/cos et du
haze sur relief : exige le rendu de la tâche 3, non lancé ; (5) combien des 8 arbres exclus repassent à
5,87 : inconnu ; (6) contenu exact de l'amendement caméra du dossier (non versionné) ; (7) le dossier
CH35-CONCEPTION n'est pas dans le dépôt ; (8) LakeZoneProbe / V6CrittersProbe INCONCLUSIVE structurel, non
rouverts ; ChargerAudit / AirEnemyLandingLaneAudit non lancés.

BRANCH : claude/ch35-b-multi-altitude-6945aq (= origin/main 08229cc, arbre identique) — rien poussé.
COMMITS : aucun.
FILES : aucun fichier de jeu modifié ; sonde jetable FrameCeilingProbe.gd/.tscn écrite puis supprimée ;
git status --porcelain vide ; seul .godot/ (gitignoré) créé par l'import.
BUILD : aucun export. Import Godot 4.3 complet (154 .scn) + une sonde xvfb/opengl3 (exit 0, 15 s).
DEPLOY : aucun, aucune vérification Vercel.
VALIDATION CHECKLIST : [x] fetch collision au début (aucune branche jumelle, main = base) [x] plafond
mesuré sur la caméra réelle, 2 méthodes concordantes [x] HubWorld.gd lu en entier (code) [x] staging lu
pour SailBoat/HubTransport [x] sonde supprimée, arbre propre [ ] rendu tâche 3 (décrit, non lancé)
[ ] lot 1 SURFACE : NON ouvert.
NEXT STEPS : (1) déposer le dossier CH35-CONCEPTION + ce complément sous docs/lots/CH35_MULTI_ALTITUDE.md
(lot doc, sans code) ; (2) lot 0 : +2 lignes overlay (POS/zone, CACHE_VERSION) puis la série device par
Mathieu, grille ci-dessus ; (3) lot cadré « plafond » : FRAME_TOP 7,968 gaté par sonde, SEAT_MAX_Y 5,87 +
rendu des sièges ré-admis ; (4) lot 1 SURFACE seulement après le verdict device.
DOCS STATUS : rien écrit dans le dépôt (interdiction du brief) ; ce bloc est le livrable, doublé du fichier
.md joint.

---

# CH35-C — RENDU DE TERRAIN TEST + PLAN D'EXÉCUTION LOT 1 SURFACE (7 sept 2026)

Base : HEAD = origin/main 08229cc, arbre 8f4dc2e byte-identique (fetch de collision au début : aucune
branche altitude/terrain, dernières refs = vercel-purge / ci-sparse-checkout). Godot 4.3 éditeur téléchargé
(50 276 070 o = Content-Length), import complet 154 .scn, 0 erreur. Sonde JETABLE TerrainReadProbe.gd/.tscn
(scripts/dev) écrite, parse-checkée --headless --quit-after 2, lancée 8× sous
xvfb-run -a -s "-screen 0 1200x2000x24" godot4 --rendering-driver opengl3, puis SUPPRIMÉE. Aucun fichier de
jeu touché. Toutes les lignes citées relues sur main ce jour.

## TÂCHE A — RENDU DE TERRAIN TEST : 50 captures offscreen 1080×1920 (llvmpipe)

Protocole exécuté, avec UNE adaptation forcée par le calcul : « 40×40 u, sommet 12 u » et « 15° » sont
incompatibles (une gaussienne qui revient à 0 sur 40 u impose σ = 6,5 ; sa pente max A/(σ√e) vaut 48,5° à
12 u). Donc 4 buttes de même empreinte 40×40 (raccord C0 exact au bord, h(20) = 0) et sommets 2,85 / 6,13 /
10,62 / 12,0 u = pente max 15° / 30° / 45° / 48,5°, + 1 mesa 12 u à face 80° (run 2,1 u), dos 35°, flancs
latéraux 66°, en 3 orientations (face caméra, flanc est, dos). Centre (0, −30) = « sud du spawn » du brief :
les deux lacs sont enterrés sous la butte et la haie du vallon (z ≈ −39) traverse son flanc nord (bases
d'arbres enfouies) — bruit assumé et identifié sur les planches, pas une mesure. Stations : pied à 10 u du
bord (= le spawn, butte à 30 u), mi-pente (r = σ, pente nominale sous Keepy), sommet ; mesa : pied 10 u,
pied 3 u, dessus, + axe sud pour le flanc 66°. SUN puis RAIN (force(RAIN) + 20 s simulées, wet = 1,00).
Caméra : amendement Q5 appliqué à la main (target = null, position = (x, h, z) + OFFSET, basis intacte).
Mesh : ArrayMesh 0,5 u (12 800 tri ; mesa 0,25 u, 51 200), MÊME ShaderMaterial que le sol
(CozyPalette.ground_material()), enroulement horaire vu de dessus (normale main-droite −y, vérifiée = face
avant Godot). Blind check : à la station mi-pente le pixel centre lit (0.54,0.76,0.41) contre
(0.86,0.78,0.56) sans butte — la butte dessine ; viewport lu 1080×1920 (stretch = false forcé).

RÉPONSES, captures à l'appui (planche buttes / planche falaises jointes) :
1. Étirement 1/cos : INVISIBLE à 15°, 30° et 45° (g15/g30/g45 mid + summit, SUN et RAIN). Cause : aucune
   texture du sol n'a d'orientation (patch 26 u, détail 5,5, mottle 1,7, cellules 2,6 sont des bruits
   isotropes) — un ×1,41 sur un bruit isotrope ne se lit pas. VISIBLE vers 60-66° (flanc latéral de la
   mesa vu de l'axe sud : stries au bord gauche du cadre) ; GÊNANT à 80° (cliff_face foot3/foot10 : la
   moitié haute du cadre est un rideau vert strié verticalement, RAIN identique en plus sombre). Le wet ne
   change rien à la lisibilité du stretch, il assombrit.
2. Le VRAI défaut n'est pas 1/cos, c'est l'absence de shading : le sol est unshaded, donc un flanc n'a
   AUCUN indice de pente. Une pente uniforme de 35° face caméra (cliff_back mid_gentle) est indiscernable
   d'un sol plat, sauf que l'horizon devient une règle droite en haut du cadre = « mur vert ». Le relief
   ne se lit que par (a) la silhouette de crête contre des arbres ou le ciel, (b) l'occlusion des props,
   (c) l'horizon qui monte. Un plateau sommital a des arêtes dures (cliff_east top : rectangle vert « en
   papier » posé sur le vallon) ; une falaise vue d'en haut est une ligne horizontale nette sans face
   (cliff_back top) ; une face 80° ENTRE caméra et Keepy remplit le bas du cadre (cliff_face top).
3. Haze (haze_start 8, densité 0,022) à 30 u : la butte lit comme un RELIEF, pas comme du ciel — dôme vert
   pâli, pixel (540,300) = (0.55,0.74,0.55) sur g45 contre (0.53,0.52,0.56) arbres/ciel sans butte ; RAIN :
   plus gris (0.44,0.58,0.47) mais toujours un dôme devant les arbres. Réserve : ça tient parce que la
   crête se découpe sur un fond ; sans crête visible (versant plein cadre) le haze ne sauve rien.
4. Cadre (mesuré sur capture, cohérent avec CH35-B 7,968 u + 2,367°) : à 30 u devant Keepy le plafond vaut
   ≈ 9,2 u — le sommet 10,62 affleure le bord, le sommet 12 est COUPÉ (g12 foot10). Un sommet de 12 u
   entre dans le cadre à ≈ 97 u, où le haze est à 88 % : avec la caméra figée, un sommet de montagne n'est
   JAMAIS à l'image ; la masse lisible depuis un pied est ≤ 9 u de dénivelé à 30 u. À la station
   mi-pente 45° (Keepy à 6,4 u), le dôme occupe ≈ 60 % du cadre ; à 30°, la crête est à 55 % du cadre et
   le sol lointain reste visible au-dessus.
5. Bandes CozyPalette : la frontière autumn (z −39 ± 4,5 de wobble) grimpe le flanc nord en courbe de
   niveau ; vu du sommet (g45/g12 summit) le brun commence sur la crête, continu, acceptable. Mais sans
   shading cette ligne de couleur serait le SEUL trait d'un versant : un versant bicolore horizontal lit
   comme deux terrasses. Confirme CH35-B : aucune bande ne doit traverser un domaine (assert à
   l'enregistrement, voir HubSurface.register_domain ci-dessous).
6. PENTE MAXIMALE RECOMMANDÉE pour le domaine montagne : 30° pour tout sol MARCHABLE (colline lisible par
   sa silhouette, textures intactes, sol lointain encore dans le cadre depuis la mi-pente : g30 mid /
   summit / foot10) ; 45° toléré sur des flancs NON marchables et courts (< 8 u de dénivelé : g45 mid est
   déjà un dôme plein cadre) ; > 55° INTERDIT avec cozy_ground (stries) — une falaise exige un autre
   matériau (roche, triplanaire) ou un habillage de props, hors socle. Deux contraintes de layout en plus :
   chaque station marchable doit voir une crête contre un fond (sinon mur vert), et le dénivelé présenté
   depuis un pied ≤ 9 u à 30 u.
llvmpipe prouve la GÉOMÉTRIE et le CADRAGE, pas le shading WebGL2 de Safari iOS (mipmaps/aniso sur les
stries, précision du haze, tri des transparents pour la pluie) : les planches restent à confronter sur
device, en SUN et en RAIN, aux mêmes stations.

## TÂCHE B — PLAN D'EXÉCUTION DU LOT 1 SURFACE (aucun code écrit ici)

### Signature HubSurface (fichier NOUVEAU scripts/hub/HubSurface.gd, nom proposé, n'existe pas)
- static var _domains: Array[Dictionary] = [] — TABLE dès la première entrée : {"name": StringName,
  "aabb": Rect2 (x, z), "origin": Vector2, "pitch": float, "cols": int, "rows": int,
  "grid": PackedFloat32Array}. Lot 1 : ZÉRO domaine enregistré en jeu ; seules les sondes en enregistrent.
- static func height_at(flat: Vector3) -> float : 0.0 hors de toute AABB (comparaison stricte, pas de
  blend) ; dedans, barycentrique sur la triangulation FIXE (diagonale a-b-c / b-d-c, la même que le mesh
  que le lot 2 construira DEPUIS la grille).
- static func domain_at(flat: Vector3) -> int : −1 = socle.
- static func ground(flat: Vector3) -> Vector3 : Vector3(flat.x, height_at(flat), flat.z) — l'orthographe
  UNIQUE du point sol (règle « un fait publié une fois ») ; c'est ground() que les sites ci-dessous
  appellent, jamais height_at + Vector3 à la main.
- static func intersect_ray(origin: Vector3, dir: Vector3) -> Variant : si _domains vide → EXACTEMENT
  Plane(Vector3.UP, 0.0).intersects_ray(origin, dir) (byte-identique par construction) ; sinon marche du
  rayon par pas de 0,25 u jusqu'à y_ray ≤ height_at, bissection 6 itérations, borne 200 u, null au-delà.
  Pure (calcul), donc testable en headless.
- static func register_domain(spec: Dictionary) -> int : refuse (push_error, −1) une AABB qui intersecte
  une AABB existante, une grille dont un point du périmètre échantillonné à 0,5 u a |h| ≥ 1e-4 (CONTRAT
  C0 : hauteur EXACTEMENT 0 sur tout le périmètre, pas de marche), une grille float64 (PackedFloat32Array
  exigé), et une AABB qui coupe une bande CozyPalette (autumn/moor/circuit _edge_z ± wobble, field_0..2,
  cove_rect) — lue dans CozyPalette, pas recopiée.
- static func domains() / clear_domains() (sondes).
- normal_at : PAS au lot 1 (le hop est un arc sur une ligne de base, KeepyHopper:1503-1512).

### Sites à brancher — fichier:ligne | écrit aujourd'hui | doit écrire | vague | preuve de non-fuite
VAGUE 0 — le socle seul (aucun client). HubSurface.gd + SurfaceProbe phases A/B. Sortie : sonde verte,
`git diff --stat` = 2 fichiers neufs + ProbeTimeoutAudit +1, rien d'autre.
VAGUE 1 — l'entrée unique de la marche (KeepyHopper.gd) :
| :513 hop_to | _target = (point.x, 0, point.z) | _target = HubSurface.ground(point) | 1 | table des rides 2 arbres + SurfaceProbe C |
| :1442 _advance here | (x,0,z) | INCHANGÉ (delta XZ : lecture, pas écriture) | — | grep-gate |
| :1459-1460 _begin_hop | _hop_from_y = 0 ; _hop_to_y = 0 | = height_at(here) ; = height_at(_hop_to), écrits APRÈS le calcul de _hop_to (:1464) | 1 | SurfaceProbe C (base mi-hop = lerp) |
| :1550-1551 _on_hop_finished | remise à 0 après le snap | = height_at(_hop_to) les deux (le corps idle reste à h) ; :1548 _place_vehicle(Vector3(x,0,z), …) → ground(_hop_to) | 1 | idem |
| :1192-1193 leave_ride | 0 ; 0 | height_at(here) ; height_at(landing) | 1 | StreamRideProbe 2 arbres |
| :1024, :1305, :1968, :2030, :2120 | handle.y / deck / grip / seat | INCHANGÉS (hauteurs de prop, pas du sol) | — | — |
| :1981-1982, :2051-2052, :2135-2136 (phases arbre) | 0 ; 0 | height_at(foot de l'arbre) les deux — valeurs mortes pendant la phase, mais la règle est uniforme : AUCUN littéral 0.0 de ligne de base ne survit | 1 | V4ClimbProbe 2 arbres |
| :2174-2175 drop de l'arbre | grip.y ; 0 | grip.y ; height_at(foot) | 1 | V4ClimbProbe |
| :1349 dive | anchor.y ; 0 | anchor.y ; height_at(flat_landing) (eau à h=0 sous A, byte-identique) | 1 | DivingBoardProbe |
Sortie vague 1 : table des rides rejouée sur les DEUX arbres (référence importée à part : DivingBoard,
OwlFlight, Seesaw, Turnstile, V4Climb, ZiplineRide, Cove, ActorWalker, Cabin, Kart, StreamRide, Yacht)
avec comptes de rouges IDENTIQUES (SeesawProbe 157≠144 et WaterTintProbe 9 rouges pré-existants sont des
ROUGES ATTENDUS des deux côtés, jamais présentés verts) ; grep-gate : dans KeepyHopper.gd les seules
occurrences restantes de `Vector3(global_position.x, 0.0, global_position.z)` sont des lectures de delta
(715, 837, 949, 1009, 1114, 1173, 1442, 1669, 1965) — script shell dans le rapport du lot.
VAGUE 2 — suiveur global n°1, la caméra (HubCamera.gd) :
| :193 _wanted | (x, 0, z) + OFFSET | HubSurface.ground(target.global_position) + OFFSET | 2 | CozyCapture 5 stations md5-identiques 2 arbres ; SurfaceProbe D |
| :138 _drive_wanted | (x, 0, z) − heading·DRIVE_BACK + DRIVE_UP | ground(at) − heading·DRIVE_BACK + (0, DRIVE_UP, 0) | 2 | KartTraceProbe + ChaseAudit 2 arbres |
| :186 look | (x, 0, z) + … + DRIVE_LOOK_UP | ground(kart) + … | 2 | idem |
VAGUE 3 — le tap (HubTapInput.gd) :
| :356-357 | Plane(UP, 0).intersects_ray | HubSurface.intersect_ray(origin, direction) ; `aim` (:386) reste (hit.x, 0, hit.z) — tous les tests de prop sont XZ ; destination = HubRegion.clamp_to(hit) (plate, hop_to rebase) | 3 | CabinProbe (taps par pixel) 2 arbres ; SurfaceProbe B |
VAGUE 4 — retours au sol hors chaîne de hops (tous injouables en jeu ou inertes sous A) :
| KeepyHopper :695, :812, :928, :1048, :1079, :1658, :2211 | global_position = (x, 0, z) | = HubSurface.ground(global_position) | 4 | grep-gate + table des rides |
| KeepyHopper :1711, :1721 mount/dismount_vehicle | ground = (x,0,z) ; _place_vehicle(ground, 0.0) | ground = HubSurface.ground(…) ; _place_vehicle(ground, ground.y) | 4 | CoveProbe (char), KartProbe |
| HubWorld.gd :765 retour cabane | (where.x, 0, where.z) | HubSurface.ground(where) | 4 | CabinProbe |
| HubWorld.gd :1533, :1652 ours ; :2131, :3032 blaireau | (x, 0, z) | ground(…) | 4 | ActorWalkerProbe, CampfireFacingProbe |
| HubWorld.gd :1743-1744 _ride_exit_point ; :3336 clamp_to | plats | INCHANGÉS (consommés par hop_to qui rebase) | — | — |
VAGUE 5 — suiveur global n°2, pluie + ombre (CozyScatter.gd) :
| :1281 | _precip_node.position = (p.x, 0, p.z) | = HubSurface.ground(p) | 5 | CozyCapture RAIN md5-identique ; SurfaceProbe E |
| :1283 | lift = clamp(p.y, 0, 1.5) | clamp(p.y − height_at(p), 0, 1.5) | 5 | idem |
| :1286 | (p.x, SHADOW_Y + 0.005, p.z + 0.18) | (p.x, height_at(p) + SHADOW_Y + 0.005, p.z + 0.18) | 5 | idem |
VAGUE 6 — peut attendre (CH35-B : (3)(4) attendent qu'un acteur ou un arbre monte) ; si la fenêtre le
permet, faire les NOISETTES seulement, gatées par V4SaveProbe + SurfaceProbe F :
| HubNuts.gd :341 | if pos.y <= 0.0: pos.y = 0.0 | h = height_at(pos) ; if pos.y <= h: pos.y = h | 6 | V4SaveProbe 2 arbres |
| :264-275 repos, :140 reload, :369 bob, :439 feuilles (0.02) | y absolus | h + la même constante | 6 | idem |
| HubActorWalker.gd :329, :333 ; HubCritter.gd :196, :201 | (x, global_position.y, z) | (x, height_at(next), z) — ⚠️ HubCritter porte `_lift` (:134) : vérifier qu'aucun porteur n'écrit y avant de brancher | LOT 2 | V6CrittersProbe est INCONCLUSIVE structurel → pas de gate possible : c'est pourquoi ça ne rentre PAS au lot 1 |
Obligatoires au lot 1 : vagues 0-5 (dont suiveurs (1) caméra et (2) pluie/ombre). Attendent : noisettes
(6, optionnelle), acteurs/critters (lot 2 avec leur propre sonde), SEAT_MAX_Y de HubTrees:96-97/449 et
KEEPY_WATERLINE_Y (lot 2, avec le rendu des sièges — et HubTrees:96 porte déjà le 6,96 faux de CH35-B),
HubTransport.gd :471/:518 (dock y pour une ligne vers un sommet : lot 2).
KartBody.gd:218 — nuance : `global_position = out["position"]` écrit la sortie brute de
VehicleDrive.step() (:141 position.y = 0.0) ; SandYacht.gd:203 passe par _wall(), SailBoat (staging)
par sa traînée. Implication : le kart est le SEUL véhicule sans point d'accroche pour un rebase ; sur le
circuit plat c'est inerte (0.0 == 0.0), donc AUCUNE ligne au lot 1, ni au lot 2. Au lot 3 seulement, et
seulement si le composite Q2-B est adopté uniformément : une ligne `global_position =
HubSurface.ground(out["position"])` à :218, prouvée par KartTraceProbe byte-identique (h ≡ 0). Sinon
jamais : VehicleDrive.gd ne s'ouvre pas.

### Sondes à écrire (SurfaceProbe.gd/.tscn, PERMANENTE, headless — transforms seuls ; ProbeTimeoutAudit +1)
Blind check en tête de CHAQUE phase : height_at(point testé) ≠ 0 (lu, imprimé) — sans lui, « y == h »
est « y == 0 » écrit plus long.
- A. Domaine de test 20×20 u, gaussienne 3 u, enregistré par register_domain ; asserts : height_at(centre)
  = 3,000 ; périmètre à 0,5 u : |h| < 1e-4 (80 points) ; hors AABB : 0.0 exact ; barycentrique = valeur
  du sommet aux nœuds de grille. ROUGE AVANT VERT : grille décalée de +0,01 → register refuse (1 rouge
  attendu, pas d'autre) ; AABB chevauchante → refus (1 rouge).
- B. intersect_ray : rayon de la vraie pose caméra (basis du .tscn, pitch 34°) vers un point du flanc :
  hit.y == height_at(hit) ± 1e-3 ET |hit.xz − plan0.xz| > 1 u (blind : le plan 0 répond AILLEURS, sinon
  la marche ne prouve rien) ; _domains vide → hit byte-identique au Plane (comparaison de 20 rayons).
- C. Chaîne de hops : Keepy au pied (h ≠ 0 mesuré à la cible), hop_to(sommet) ; à chaque hop_landed
  y == height_at(xz) ± 1e-4 ; à mi-hop (t = 0,5 lu via un tween sondé) y − arc = lerp(h_from, h_to) ;
  au repos idle y == h. ROUGE : remettre :1550-1551 à 0.0 (édition locale, cmp après restauration) →
  corps à 0 sous le relief : 2 rouges attendus (atterrissage + repos).
- D. Caméra : Keepy posé à (x, h, z) avec h = 3, 120 frames → camera.global_position == ground + OFFSET
  ± 1e-3 ; blind : h ≠ 0 ; ROUGE : :193 à 0.0 → y caméra = 7,6 (1 rouge).
- E. Pluie/ombre : après 60 frames precip.position.y == h ; ombre.y == h + 0,025 ; lift avec Keepy à h+1
  → rayon réduit de 25 % (positif d'abord), puis Keepy à h → rayon plein. ROUGE : :1283 sans −h → rayon
  réduit au repos (1 rouge).
- F (si vague 6) : noisette lâchée à (x, h+2, z) → repos à y == h + ACORN_LIE_Y ; reload → idem.
- G. Négatif final : clear_domains() → toutes les grandeurs ci-dessus reviennent à 0 (prouve que c'est h
  qui les pilote).
Gates de non-fuite hors SurfaceProbe : table des rides 2 arbres (12 sondes, comptes identiques) ;
KartTraceProbe + YachtTraceProbe traces identiques ; CozyCapture 5 stations × SUN/RAIN md5-identiques ;
ChaseAudit identique ; grep-gate KeepyHopper ; ProbeTimeoutAudit = baseline + 1. Ne pas rouvrir
LakeZoneProbe / V6CrittersProbe ; WaterTintProbe reste à 9 rouges des deux côtés.

## RAPPORT
BRANCH : claude/keepy-ch35-terrain-test-plan-3nhjhd (locale, = origin/main 08229cc, arbre 8f4dc2e).
Rien poussé.
COMMITS : aucun.
FILES : aucun fichier de jeu modifié. TerrainReadProbe.gd/.tscn (+ .uid) écrits puis SUPPRIMÉS ;
`git status --porcelain` = 0 ligne, arbre HEAD == origin/main^{tree}. Seuls .godot/ et les sous-produits
d'import gitignorés existent. Captures et planches dans le scratchpad de session (hors dépôt) ; 2
planches-contact envoyées (buttes 20 vignettes, falaises 12).
BUILD : aucun export. Import Godot 4.3 complet (154 .scn), 8 runs xvfb/opengl3 (18-28 s chacun, exit 0).
DEPLOY : aucun, aucune vérification Vercel.
VALIDATION CHECKLIST : [x] fetch collision au début [x] Godot taille = Content-Length [x] import complet
154 .scn, 0 erreur [x] parse-check headless avant xvfb [x] viewport 1080×1920 asserté non dégénéré
[x] blind check pixel (butte dessine) [x] enroulement vérifié [x] 50 captures SUN+RAIN, 3 stations × 4
buttes + mesa × 3 orientations [x] sonde jetable supprimée, porcelain vide, arbre = main [x] toutes les
lignes de la tâche B relues sur main [ ] shading WebGL2 Safari : NON prouvé (llvmpipe) [ ] lot 1 : NON
ouvert.
NEXT STEPS : (1) Mathieu regarde les deux planches sur device (SUN/RAIN) et tranche la pente max
(recommandation : 30° marchable, 45° flancs courts, > 55° interdit) ; (2) lot 0 mesure device (CH35-B
tâche 4) reste préalable au lot 1 ; (3) lot 1 SURFACE = vagues 0→5 ci-dessus, dans l'ordre, chaque vague
fermée par son critère de sortie avant la suivante ; noisettes en 6 si la fenêtre le permet ; (4) lot doc :
déposer CH35-CONCEPTION, CH35-B et ce CH35-C sous docs/lots/CH35_MULTI_ALTITUDE.md + ligne d'INDEX
(aucun des trois n'est dans le dépôt : un lot 1 qui les cite citerait un fantôme).
DOCS STATUS : rien écrit dans le dépôt (interdiction du brief). Doctrines candidates pour CLAUDE.md si
elles survivent au lot 1 : « un sol unlit n'a pas de pente — le relief se lit par silhouette, jamais par
le flanc » ; « point sol = (x, h, z) » ; « un sommet n'est jamais dans le cadre figé : ≤ 9 u de dénivelé
à 30 u ».
