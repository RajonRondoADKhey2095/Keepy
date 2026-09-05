# CH27 — Karting lot 1 : circuit, conduite libre, chrono

> Version **cadrée** de la section « V7 — KARTING LOT 1 » du journal carte
> blanche ([`docs/CARTE_BLANCHE_JOURNAL.md`](../CARTE_BLANCHE_JOURNAL.md),
> conservé tel quel, verbatim, aucune ligne retirée). Ce fichier n'est pas
> une copie : il reprend l'essentiel utile à une session future qui
> toucherait au karting, sans repasser par le récit heure par heure.

## Ce qui est livré

Une quatrième zone du hub, « le Circuit », accessible à pied depuis la fin
de la route de la Lande. Keepy peut y monter dans un kart, le conduire
librement au pouce sur un tracé fermé de 230,7 u à six virages de caractère
différent, et en descendre par un bouton explicite. Un chrono au tour tient
le meilleur temps, persistant (`user://`, schéma additif — aucun bump).

Deux checkpoints promus sur `staging` (`e77ba90` puis `846fb44`), un
correctif de régression (`CabinProbe`, voir plus bas), puis promotion vers
`main` par ce lot de fusion (`e64bc8f`), accord explicite de Mathieu après
validation device.

## Le schéma de contrôle tactile — choisi avant de coder

**Accélérateur automatique + direction par glissement horizontal du pouce,
ancrée là où le doigt se pose.**

1. le doigt se pose → ce point devient l'**ancre** (aucune zone à viser) ;
2. glissement gauche/droite → `steer = clamp((x − ancre.x) / 130 px, −1, 1)`,
   zone morte 10 px — proportionnel, donc un braquage léger existe ;
3. le doigt se lève → roues droites, le kart continue seul ;
4. **un second doigt posé = frein** (puis marche arrière si arrêté) ;
5. **sortir du kart = un bouton HUD explicite**, jamais un geste.

Écarté et pourquoi : l'inclinaison (permission iOS par geste, comportement
incertain en PWA) ; les zones gauche/droite (binaire, oscillation en ligne
droite) ; le joystick virtuel à position fixe (impose de viser un cercle
en regardant la piste) ; la direction au tap (c'est le tap-to-move que
Mathieu a refusé). `touch-action: none` déjà posé dans le shell HTML : pas
de conflit avec le scroll Safari.

**Une seule source d'entrées, abstraite dès la première ligne** :
`KartInput` (steer/throttle/brake) est un objet **lu** par le kart ;
`KartTouchInput` le **remplit** depuis l'écran. Un pilote IA remplira le
même objet — c'est le contrat qui rend le lot 2 possible sans réécriture.

## Architecture

| pièce | rôle | générique pour N karts ? |
|---|---|---|
| `KartInput` | steer/throttle/brake, source indifférente | oui |
| `KartBody` | physique arcade (vitesse, grip latéral, rayon de braquage, châssis qui roule/tangue, roues) ; ignore qui le pilote | oui |
| `KartTrack` | tracé : spine fermée (`ideal_line()`), `progress_at(p)`, `on_track(p)`, ligne de départ, clôture souple | oui |
| `KartLap` | tours + 3 checkpoints ordonnés d'UN coureur, chrono au tour | oui, une instance par coureur |
| `HubKarting` | module (comme `HubTransport`/`HubCritters`) : construit la zone, possède `racers: Array` **dès le premier commit** (une entrée = le joueur), branche tap → marche → `mount_carrier` → conduite, caméra, HUD, `WorldSave` | la liste existe déjà |
| `HubCamera` | mode conduite : poursuite tweenée dans les deux sens, **byte-identique hors conduite** | — |
| `KartHud` | chrono, meilleur, dernier tour, bouton « Descendre », fantôme de l'ancre | — |

Le kart est un **porteur** (`mount_carrier`/`follow_carrier`, patron déjà
utilisé par la montgolfière et le sanglier) : Keepy est `ON_CARRIER` pendant
toute la conduite, ce qui ferme d'office tous les autres taps du hub par
état. Sortie par bouton → `leave_carrier` sur un point clampé à la région
(la zone circuit fait partie de la région, même altitude que tout le
reste — **pas** une migration multi-altitude, un simple ride).

**Zone** : quatrième zone au sud de la Lande (z −134 à −196, x ±46), chaîne
de portes 0—1—2—3, portique de départ visible depuis la Lande à ~40 u de
la fin de la route.

**Piste** (`KartTrack`) : Catmull-Rom fermée sur 20 waypoints (230,7 u,
rayon mini 3,40 u à l'oméga, mesurés en Python avant le code), ruban 7 u,
liserés crème, bordures rouge/blanc où la courbure dépasse 1/16, damier de
départ, chevrons tous les 24 u.

**Physique** (`KartBody`) : vitesse vers une cible (13 u/s piste, 5,5
herbe) par constante de temps ; direction = taux de lacet × gain(vitesse)
avec relâchement à haute vitesse (0,72 au max) ; grip latéral (6,5/s piste,
2,4/s herbe) qui éteint la composante latérale du vecteur vitesse monde
introduite par le virage — c'est la glisse, et elle scrub (0,55). Frein
15 u/s², marche arrière 3,5. Clôture souple : réflexion 0,35. Châssis :
roulis (≤9°), tangage (≤5°), roues qui tournent et se braquent, bob +
secousse au mur. `SEAT (0 ; 0,42 ; −0,18)` publié.

## Validation — sonde et rides existants

`KartProbe` (headless, `--fixed-fps 60`, `ProbeWatchdog` en première
instruction, sauvegarde jetable) : **99 checks, 0 échec**, cinq phases,
trois passes rouge-avant-vert (VACANTE puis réécrite pour `KartLap` sans
checkpoints, 3 rouges exacts pour la caméra non restaurée, 1 rouge exact
pour un grip infini). Pilote de test `KartLineInput` (pure pursuit, hors
export) : 2 tours en 21,75 s / 21,48 s.

`index.pck` 34 374 864 (staging avant lot : 34 323 216, +51 Ko),
`index.wasm` 35 376 909 / `af4a8fc2…` (moteur inchangé), 0 `SCRIPT ERROR`
à l'export, `scripts/dev/*` exclu du pack.

Rides existants rejoués sur l'arbre du lot (`dcaca73`, 132 `.scn` importés) :
`V4SaveProbe`, `V4ClimbProbe`, `CampfireFacingProbe`, `OwlFlightProbe`,
`V6CrittersProbe`, `StreamRideProbe` **PASS** ; `SeesawProbe`/`TurnstileProbe`
FAIL identiques à `V6`/`main` (pré-existant, pas une régression du lot).

**Régression réelle trouvée et corrigée** : `CabinProbe` phases T/F
(5 taps de seuil jetés) — `HubCamera` en mode conduite lissait une
variable-ombre `_hub_position` et la recopiait dans `global_position` au
lieu de lisser `global_position` directement ; toute écriture externe de
`global_position` (une sonde qui gare la caméra à la main, ici) divergeait
du suivi. Corrigé : `global_position` reste lissé directement hors
conduite, le lissage séparé n'existe qu'en conduite. `CabinProbe` revient
à 1 rouge, identique à la référence `5fa8f29` importée à part.
**`KartProbe` seul ne pouvait pas voir cette régression** — elle ne gare
jamais la caméra à la main. Voir doctrine ajoutée à `CLAUDE.md`.

## Ce qui n'est pas fait, dit clairement

Aucun son ; aucun effet de glisse visible (poussière) ; pas de GLB Blender
(primitives Godot à tessellation explicite partout, `bpy` installé et
délibérément pas utilisé — la conduite l'a emporté sur le décor cette
nuit-là) ; pas de compte à rebours ni de mode « course » (contre-la-montre
seul, sur consigne) ; **les constantes de conduite et `STEER_SPAN`
(150 px logiques, ≈1 cm sur iPhone) n'ont pas rencontré de pouce réel
avant la validation device de ce lot**. Aucune nouvelle constante réglée
sur device n'a été communiquée à ce lot de fusion — si Mathieu en
communique après avoir roulé en prod, elles sont à consigner ici en
suivant, additif.

## Ce que le lot 2 (adversaires IA) attend de cette base

Déjà prêt, sans réécriture :

| besoin | où | état |
|---|---|---|
| second kart | `HubKarting.add_racer(name, colour, player=false)` | prêt (même fonction que le joueur, `player=false` laisse l'input sans écrivain) |
| IA de conduite | `KartLineInput` (pure pursuit sur `ideal_line()`) tourne déjà en 21,5 s, dans `scripts/dev`, hors export | prêt à déplacer sous `scripts/hub/kart/` |
| trajectoire idéale | `KartTrack.ideal_line()`, `point_at(s)`, `tangent_at(s)`, `progress_at(p, hint)` | prêt ; une corde de course sera une seconde liste publiée, pas une modification de la spine |
| tours/checkpoints par coureur | `KartLap` par entrée de `racers` | prêt |
| classement | tri par `(lap_count, s)` | à écrire (~10 lignes, pas fait sur consigne) |
| physique partagée | `KartBody.drive()` ignore qui pilote | prêt |
| caméra | suit `racers[_player]` | rien à faire |

À ajouter pour le lot 2 : un état de course (`IDLE`/`COUNTDOWN`/`RUNNING`/
`FINISHED`, ~150 lignes + HUD) ; des collisions entre karts (disques 2D +
séparation, jamais un `PhysicsBody3D` — doctrine `HubTapInput`, ~80 lignes
O(N²) sur N≤6) ; une IA qui dépasse le suiveur pur (décalage latéral cible,
profil de vitesse précalculé depuis `_curvature(i)`, une personnalité par
animal — 3 constantes chacune) ; un rubber-band cozy (facteur 0,92–1,06 sur
`v_max` selon l'écart au joueur) ; `kart.results` additif dans `WorldSave`
pour les résultats de course.

**Avis franc porté au journal, non réécrit ici** : ce qui manque le plus
n'est pas les adversaires — c'est la sensation à l'écran (son, poussière de
glisse, et surtout la validation du geste sur un vrai pouce, faite avec ce
lot de fusion).

**Contrat pour le lot 2** : `KartBody`, `KartTrack`, `KartLap`, `KartInput`,
le mode caméra et la bascule marche↔conduite ne bougent pas. Si le lot 2
doit toucher l'un de ces cinq fichiers pour autre chose qu'une constante,
c'est que ce lot-ci a raté quelque chose — à consigner ici si ça arrive.

## LOT 2 (V8, 5 sept 2026) — ce que le contrat a réellement coûté

Le lot 2 a touché deux des cinq fichiers du contrat au-delà d'une constante, et c'est consigné ici comme demandé :

* **`KartBody`** : `bump(strength)`, 12 lignes — expose le canal `_bump` que la clôture souple utilisait déjà, pour qu'une collision kart-kart (résolue par le coordinateur) produise la même secousse qu'un contact de mur. Rien d'autre.
* **`KartTrack`** : `sample_count()`, `sample_s(i)`, `curvature(i)`, `signed_curvature(i)`, `side_at(s)` — des accesseurs qui publient ce que les bordures lisaient en privé (`_curvature`), pour que le profil de vitesse de `KartAiDriver` ne re-dérive pas la géométrie.

`KartInput`, `KartLap`, le mode caméra et la bascule marche↔conduite sont intouchés. `KartLineInput` (`scripts/dev/`) est devenu `scripts/hub/kart/KartAiDriver.gd` (profils `cat`/`beaver`/`boar`/`probe`) ; le récit du lot est dans le journal, section « V8 — KARTING LOT 2 ».
