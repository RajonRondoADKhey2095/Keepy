# CH78 — Le ballon sauteur part du plateau de spawn

> Chantier court, un seul fait changé : `HubTransport.BALL_PARK`.
> Aucune mécanique touchée — le ballon reste le même modificateur de saut,
> monté par le même canal, re-garé par la même règle hors-champ.

| | |
|---|---|
| **date** | 12 septembre 2026 |
| **branche** | `claude/bouncing-ball-quad-raptor-d3mag6` |
| **base** | `origin/staging` (= `20cf6b8`, CH77 mergé) |
| **fichiers de jeu** | `scripts/hub/HubTransport.gd` (une constante + son bloc) |
| **palier** | 1 — `staging` |

## 1. La demande

Mathieu : le ballon sauteur doit être **« repositionné plus loin dans la
zone 0 — pas de refonte de la mécanique, juste ses coordonnées »**.

## 2. Recon — ce que le dépôt publie déjà

`BALL_PARK` est **la seule orthographe** de cette position, et c'est ce qui
rend le lot court. Grep exhaustif :

| lecteur | comment il lit |
|---|---|
| `HubTransport._build_ball` | `_ball.position = BALL_PARK` |
| `HubTransport.update` (règle hors-champ) | `BALL_PARK` deux fois |
| `HubTransport.footprints()` | un disque `BALL_FOOTPRINT` au park |
| `CozyScatter._blocked` / `_autumn_blocked` / `_moor_blocked` | via `footprints()` |
| `CoveProbe` (3 sites), `SailBoatProbe` (1) | **la constante**, jamais un littéral |
| `CozyCapture`, `V4SiteProbe` | `ball_position()` / `footprints()`, dynamiques |

⚠️ **Aucun littéral de coordonnée nulle part** — deux mentions dans
`docs/` (`CARTE_BLANCHE_JOURNAL.md`, `CH44_RECON.md`) sont des **relevés
historiques** et restent tels quels : ce sont des enregistrements de ce qui
était vrai à leur date, pas des lectures du jeu.

## 3. Le balayage, et la contrainte qui décide

`HubParkRecon` (jetable, supprimée avant le commit), grille 0,5 u sur
`HubRegion.walkable_bounds()`, **365 disques publiés** rassemblés une fois.

Cinq contraintes → **13 935 candidats**, et la table N+1 nomme les leviers :

| on retire | candidats restants |
|---|---|
| la région | 68 466 |
| la zone 0 | 44 780 |
| le sec (lac / mer) | 17 766 |
| le dégagement des disques | 25 179 |
| **la dalle / le circuit** | **13 935** |

⚠️ **La cinquième ne retranche RIEN**, et c'est dit plutôt que transporté :
la zone 0 exclut déjà le circuit, et la dalle est déjà un disque de
`HubSkatepark.footprints()`. Une contrainte qui ne coûte rien voyage de
brief en brief comme si elle coûtait quelque chose (doctrine CH68).

Deux termes décident ensuite, et **c'est le SECOND qui borne** :

* le **cône de cadre du spawn** (`|x| ≤ 0,414·(8,9 − z)`) — la propriété
  pour laquelle le park expédié avait été choisi, gardée plutôt que
  abandonnée en silence ;
* le **disque du ballon TENANT DANS la région** sur 16 azimuts, avec la
  même marge (CH21 : un prop dont le CENTRE est sur le bord met des
  morceaux de lui-même au-delà, sans que rien ne le signale).

| cône | tient-dans-la-région | candidats | le plus loin | dégagement |
|---|---|---|---|---|
| 0,0 | non | 269 | **(18, −35)** à 39,357 u | 6,629 |
| 0,0 | **oui** | 178 | **(−8, −33)** à 33,956 u | 0,560 |
| 1,0 | non | 267 | (17, −35) à 38,910 u | 6,872 |
| 1,0 | **oui** | 178 | **(−8, −33)** à 33,956 u | 0,560 |

**Le cône n'est pas ce qui borne** : la réponse est la même à 0 et à 1,0 u
de marge de cône, donc ce park ne naît pas sur sa propre limite (CH69).
Ce qui borne est le tenant-dans-la-région : sans lui la réponse est
(18, −35), **exactement sur le bord sud du plateau**.

La marge utilisée des deux côtés est **`KeepyHopper.ARRIVE_EPSILON`
(0,45 u)** — la distance à laquelle une marche se termine, c'est-à-dire le
plus petit déplacement que ce jeu promet d'atteindre.

**Réponse livrée : `BALL_PARK = Vector3(-8.0, 0.0, -33.0)`**, soit
**4,428 u → 33,956 u** (× 7,7).

## 4. Deux mesures qui vont contre l'attente

⚠️ **LE PARK EXPÉDIÉ ÉCHOUERAIT LUI-MÊME AU TEST DE DÉGAGEMENT**, de
**0,363 u**, contre un prop de rayon 0,26 à (1,07 ; 3,24). Dit à voix
haute : un jeu de contraintes qui condamne ce qui tourne déjà ne prouve
rien en refusant (CH68). Le nouveau park est choisi pour être **meilleur**
sur cet axe, pas simplement légal sous une règle que l'ancien violait.

⚠️ **CE QUE LE DÉPLACEMENT COÛTE, ET CE N'EST PAS RIEN.** Le ballon n'est
plus la première chose derrière Keepy, et à 34 u le brouillard
(0,016 exponentiel) en a mangé **≈ 42 %**. Être dans le cône de cadre est
une **CONTENANCE**, pas une lisibilité. Ce qui le rend trouvable est son
marqueur de minimap (`MinimapMarkers.VEHICLE`, `&"hopball"`, CH46) — sans
ce marqueur ce déplacement demanderait une autre réponse.

## 5. Ce que le déplacement fait au tapis — mesuré, pas supposé

`BALL_PARK` est testé dans `CozyScatter._blocked()`, c'est-à-dire **AVANT**
les tirages d'échelle et de lacet. Déplacer le disque change donc quels
candidats sont rejetés, et un candidat rejeté saute ses deux tirages : le
flux RNG se décale et **le tapis est rebattu à l'échelle du hub** (CH53).
C'est irréductible pour un test placé là, et c'est mesuré plutôt que passé
sous silence :

| famille | `origin/staging` | CH78 | Δ |
|---|---|---|---|
| batches | 338 | 337 | **−1** |
| instances | 2 686 | 2 689 | **+3** |
| grass | 1 001 | 1 005 | +4 |
| flower | 108 | 109 | +1 |
| bush | 16 | 17 | +1 |
| leaf | 112 | 111 | −1 |
| pebble | 61 | 59 | −2 |

Rien n'est faux : ce n'est simplement plus le même tapis. Le lot **ne
déplace pas** le test après les tirages (le remède CH71) parce que cela
changerait où **TOUS** les disques de `HubTransport` sont testés, ce que le
brief exclut explicitement (« juste ses coordonnées »).

## 6. Gate

Le brief dit qu'aucune sonde nouvelle n'est nécessaire, et c'est juste :
aucune **mécanique** n'a changé. Ce qui a besoin d'un gate est la paire de
faits que CH78 et CH79 ont choisis **l'un contre l'autre**, et un gate sur
une paire doit voir les deux parks — donc les quatre assertions CH78
vivent dans `QuadProbe` PHASE P, avec un **littéral 4,428** (le chiffre que
ce lot prétend avoir changé ne se relit pas dans la constante qui a
changé : ce serait une tautologie) :

```
  [OK ] CH78: the ball's park moved FAR from the spawn plaza   -- 33.956 u, was 4.428
  [OK ] CH78: and it is still in zone 0, inside the region     -- zone 0
  [OK ] CH78: its own disc fits inside the region              -- 0/16 outside
  [OK ] CH78: and it is still inside the spawn frame cone      -- |x| 8.00 vs half-width 17.35
```

## 7. Non-régression

`SailBoatProbe` **42 checks / 0 rouge** sur l'arbre déplacé — elle asserte
notamment « le park du ballon nomme toujours le ballon », c'est-à-dire
exactement le canal de tap que ce lot déplace. Table croisée complète au
§ VALIDATION du rapport de session.

## 8. Ce qui reste au jugement de Mathieu

* **Est-ce assez loin ?** 34 u est un choix de règle (« le plus loin qui
  garde le cadre du spawn ET tient dans la région »), pas un optimum
  absolu : sans le cône, la réponse est (0, 71), à 71 u, au bord nord du
  lobe skate.
* **La lisibilité à 34 u sous 42 % de brume** — un banc ne signe pas ça.
