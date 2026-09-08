# CH33 — Le voilier, pilotable sur la mer existante (6 septembre 2026)

Brief : un voilier pilotable sur la mer que CH29 a déjà construite, sans
agrandir cette mer (`HubRegion.SEA_RADIUS` / `SEA_CENTRE` interdits
d'écriture, l'agrandissement étant un lot séparé après validation iPhone).
Pas de pêche, pas de `WorldSave`.

## Ce qui a été construit

`SailBoat.gd`, calqué sur `SandYacht.gd` (CH30) : même patron de véhicule
piloté — `VehicleDrive.step()` non touché, le même `KartTouchInput`, le
même `HubCamera.enter_drive()` — avec deux différences délibérées : la
surface est la mer et non le sable, et le bord n'est pas un mur dur.

Coque et voile réutilisent `yacht_hull_0.glb` / `yacht_sail_0.glb` (aucun
asset généré, aucun supprimé). `SEAT_Y` republié UNE fois
(`SandYacht.SEAT_Y`, patron `RIDE_SEAT_Y`) ; aucun patron ÉCHELLE (le seul
canal de tap est `HubTransport.vehicle_at()`/`mount_sailboat()`, qui
retire le voilier du tap pendant qu'il est piloté — la withdrawal du
bateau).

`HubTransport.gd` gagne un troisième véhicule coordonné,
`VEHICLE_SAILBOAT` : `mount_sailboat()`/`exit_sailboat()` recopient le
patron exact `mount_yacht()`/`exit_yacht()`, avec exclusion mutuelle
explicite entre les trois véhicules partagés (`touch`, la caméra, le HUD).
`HubTapInput.gd` gagne une troisième garde
(`transport.is_driving_sailboat()`), même forme que les deux existantes.

**Aucune persistance** : ni lecture ni écriture `WorldSave` pour ce
véhicule. `SAILBOAT_MOORING` (65, 0, -110) est une constante nommée dans
`HubTransport.gd`, à l'intérieur du disque `sea` (distance au centre
45,04 u contre un rayon 48 u) et dans la bande où `HubRegion` traite déjà
l'eau comme praticable (`COVE_MAX.x = 74`), donc atteignable à pied depuis
n'importe quel point de la plage sans règle nouvelle. Le voilier y
réapparaît à CHAQUE démarrage, quel que soit l'endroit où il a été laissé
la session précédente — prouvé par sonde (`SailBoatProbe`, PHASE EXIT).

## L'échouage progressif, et pourquoi ce n'est pas SandYacht avec s/sable/mer/

Le bord du char à voile est un mur dur : `HubRegion.contains()` répond
oui/non, et `SandYacht._wall()` glisse dessus ou rebondit. Le brief de ce
lot interdit explicitement cette forme pour le voilier — pas de mur, un
échouage progressif et réversible.

`SailBoat.ground_factor_at(p)` lit `HubRegion.shore_distance(p)` (déjà
publié par CH29, ni `SEA_CENTRE` ni `SEA_RADIUS` n'est retapé ici) et
rend 0 en eau libre (`GROUND_FREE_MARGIN = 4.0` u sous la ligne d'eau) à
1 bien échoué (`GROUND_AGROUND_MARGIN = 1.5` u sur le sable), linéaire
entre les deux. Ce facteur pilote une TRAÎNÉE exponentielle sur la
vélocité, appliquée APRÈS que `VehicleDrive.step()` a déjà déplacé la
coque pour cette frame — jamais un clamp de position, jamais une remise à
zéro dure.

C'est ce choix (traînée, pas clamp) qui rend l'échouage réversible par
construction : même à facteur 1, la traînée ne fait que réduire la
vélocité que la frame porte déjà, elle n'écrase jamais la cible que la
manette écrit. La branche marche arrière de `VehicleDrive.step()`
(`move_toward(v_fwd, -reverse_speed, ...)`) continue de pousser vers
l'arrière à chaque frame physique quel que soit le degré d'échouage, et
la traînée qu'elle combat est EXACTEMENT celle qui s'annule dès que la
coque repasse au-dessus de l'eau (`shore_distance` est signé et continu).

**Mesuré, pas supposé** : une marche arrière tenue depuis l'échouage
ramène le bateau en eau libre en 295 frames (~4,9 s), sur le run vert
final (`SailBoatProbe`, PHASE GROUND).

### Rouge-avant-vert

Deux passes, chacune restaurée `cmp` byte-identique après coup :

1. **Le mécanisme neutralisé** (la ligne d'application de la traînée
   commentée) : sur le run complet, UNE SEULE assertion tombe — « its
   speed near the shore is far under the open-water pace (progressive
   friction) » (6,45 u/s près du bord contre 5,23 u/s en eau libre, donc
   PLUS rapide, pas moins). Les 41 autres assertions restent vertes, y
   compris — et c'est le point notable — la réversibilité, qui passe
   trivialement sans aucune friction du tout : cette assertion-là ne
   prouve donc PAS que le mécanisme existe, seulement qu'il ne bloque
   rien quand il n'existe pas.
2. **`GROUND_DRAG_LAMBDA` porté à 500** (traînée pathologiquement forte,
   le mécanisme réel mais dénaturé) : le bateau échoue à un facteur de
   seulement 0,283 après 900 frames (il n'atteint jamais le plafond) et
   la marche arrière ne le sort JAMAIS de l'eau en 900 frames — les
   TROIS assertions du contrat d'échouage tombent, dont la réversibilité
   elle-même. C'est cette passe qui prouve que l'assertion de
   réversibilité SAIT échouer sur un échouage réel mais trop fort, donc
   que son vert sur la valeur livrée (`3.0`) veut dire quelque chose.

Fichier restauré et vérifié `cmp`/`md5sum` byte-identique entre les deux
passes.

## Deux bugs trouvés en écrivant la sonde, pas dans le jeu

`SailBoatProbe.gd` a d'abord rapporté 6 échecs qui n'étaient pas des
défauts du véhicule :

* **le frein doit être réaffirmé CHAQUE frame physique.**
  `KartTouchInput._physics_process` remet `input.brake` à l'état du
  clavier (faux, en headless) dès qu'aucun second doigt n'est suivi ; un
  `touch.input.brake = true` posé une fois hors boucle est donc défait
  avant que le véhicule ne le lise. `CoveProbe`'s propre test de frein du
  char à voile le fait déjà correctement (dans la boucle) — corrigé pour
  suivre le même patron.
* **un point de test hors de la mer.** Le test « il roule avant que le
  frein soit essayé » plaçait le bateau à (20, -110), à 88 u du centre de
  la mer (rayon 48) — donc sur la terre ferme, loin de la Crique.
  Déplacé à (90, -110), à 18 u du centre.

Les deux corrections sont dans `SailBoatProbe.gd` uniquement ; aucune
ligne de `SailBoat.gd` ou `HubTransport.gd` n'a changé pour ça.

## Sondes rejouées

* **`SailBoatProbe`** (neuve) : 42 checks, 0 échec, run final. Couvre le
  mouillage fixe, le montage/pilotage, la dérive marine (accélération/
  décélération/virage), l'échouage progressif ET sa réversibilité,
  la sortie, et l'absence de persistance.
* **`WaterTintProbe`** : rejouée sous `xvfb-run -a godot4
  --rendering-driver opengl3 --fixed-fps 60` (jamais `--headless` seul —
  PHASE G échantillonne des pixels et bloque 300 s sous le driver dummy,
  rencontré une fois avant de corriger l'invocation). 9 échecs, TOUS
  reproduits À L'IDENTIQUE (mêmes comptes de pixels au pixel près, même
  157/144 nœuds de dessin) sur `origin/staging` non modifié, rejoué dans
  un `git worktree` séparé après un premier import tronqué (108/154
  `.scn`, corrigé) — donc aucune régression de ce lot. Pré-existant,
  environnement (rendu logiciel llvmpipe) et CH26 (le compte 157/144),
  déjà documentés.
* **`CoveProbe`** : rejouée en entier sous les mêmes flags. **0 échec** sur
  toutes les phases qui ont pu s'exécuter (region, geometry, save, walk,
  castle, weather, yacht, balloon jusqu'au tap du dock corail), puis
  INCONCLUSIVE — le budget de 840 s épuisé avec l'horloge de jeu gelée à
  `state=TITLE`, exactement le symptôme que CH32 a déjà diagnostiqué et
  documenté (`docs/PROBE_AUDIT.md`) : ce sandbox n'a pas de GPU matériel,
  la phase « times » ne termine jamais dans cet environnement. Aucune
  assertion n'a échoué.
* `ChargerAudit` et `AirEnemyLandingLaneAudit` : **non lancées**, sur
  interdiction explicite du brief (pas de timeout global).
* `LakeZoneProbe` / `V6CrittersProbe` : **non rouvertes**, INCONCLUSIVE
  structurel déjà diagnostiqué par CH32 dans ce même sandbox.

## Dette signalée, non corrigée (hors scope de ce lot)

`CoveProbe` compare le disque de la mer aux constantes
`HubRegion.SEA_CENTRE`/`SEA_RADIUS` elles-mêmes plutôt qu'à une mesure
indépendante — un étalon qui partage le contrôleur de ce qu'il mesure
(doctrine CLAUDE.md) suivrait donc n'importe quelle valeur de ces deux
constantes sans rien prouver. Non touché ici : le brief l'interdit
explicitement.

## Outillage de session

Aucun binaire Godot n'était installé dans ce sandbox. Éditeur 4.3-stable
(50 276 070 octets, identique à la référence CI) et templates d'export
Web (1 073 228 327 octets, `Content-Length` complet cette fois) ont été
téléchargés et mis en place à l'identique du workflow `web-build.yml`.
`xvfb`/Mesa llvmpipe étaient déjà présents.
