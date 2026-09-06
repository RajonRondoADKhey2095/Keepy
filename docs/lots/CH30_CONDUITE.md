# CH30 — Conduite unifiée : difficulté mesurée, char à voile piloté, caméra de poursuite

> Lot cadré du 6 septembre 2026, seule session sur le dépôt, branche
> `claude/keepy-difficulty-sailcar-trw87d` partie du HEAD de `origin/staging`
> (`06d9107`, CH29 la Crique). `main` intouché. **Aucun personnage créé.**
> Aucun asset supprimé ni renommé.
>
> Trois demandes de Mathieu après validation au pouce de V8 (« la course est
> bien ») : la difficulté doit monter (~×1,5), le char à voile doit se
> conduire comme le kart, et il passe en caméra de poursuite — deuxième
> exception caméra assumée.

## Table des matières

1. [P0 — la difficulté, mesurée avant d'être touchée](#p0)
2. [P0 bis — le char ne stationne plus sur le circuit](#p0bis)
3. [P1a — l'extraction du contrôleur, et sa preuve](#p1a)
4. [P1b — la caméra de poursuite et l'audit visuel](#p1b)
5. [Ce qui n'a pas été fait, et pourquoi](#reste)

---

<a name="p0"></a>
## 1. P0 — LA DIFFICULTÉ, MESURÉE AVANT D'ÊTRE TOUCHÉE

### L'instrument : `RaceBalanceProbe`

Interdiction de tuner à l'aveugle. La sonde fait courir la vraie course
(vrai circuit, vrais corps, vraies collisions, vrai rubber-band) et publie,
pour chaque concurrent : les trois temps au tour, le meilleur, le temps
total, l'écart à l'arrivée, la vitesse de pointe **réellement atteinte**, le
nombre de fautes, et la moyenne du `speed_scale` que le rubber-band lui a
écrit. Elle rejoue la même graine avec la laisse et sans elle.

**Le dénominateur.** « ×1,5 d'adversité » est un rapport, et un rapport a
besoin d'un dénominateur. Un bac à sable ne peut pas tenir le pouce de
Mathieu, donc le dénominateur ne peut pas être « le niveau de Mathieu ». La
sonde en mesure un qui ne dépend d'aucune supposition : **le tour le plus
rapide que ce véhicule peut physiquement tourner sur ce circuit**, avec un
pilote dont les pneus ne lâchent jamais (profil `limit_ref`, `a_lat` 40).

```
LE PLANCHER (limit_ref)                       21,633 s / tour
```

Le **déficit** d'un adversaire est son meilleur tour moins ce plancher, et
un preset ×N divise ce déficit par N. C'est mesurable, ça peut échouer, et
ça ne bouge pas quand le pilote humain progresse.

### Ce que la mesure a dit — trois prémisses tombées

#### 1. LE RUBBER-BAND EST INERTE. Ce n'est pas le levier.

| preset | adversaire | `speed_scale` moyen | arrivée avec laisse vs sans |
|---|---|---|---|
| x1 | Le Chat | 1,0000 | +0,083 s |
| x1 | Le Castor | 1,0073 | +0,083 s |
| x1 | Le Sanglier | 1,0094 | +0,100 s |
| x1.5 | Le Chat | 1,0000 | −0,016 s |
| x1.5 | Le Castor | 1,0019 | −0,100 s |
| x1.5 | Le Sanglier | 1,0043 | −0,117 s |

Sur une course de 75 s, la laisse déplace une arrivée de **0,1 s au plus**.
Le diagnostic du brief est confirmé par la mesure : le levier est la
vitesse de pointe et les profils, pas l'assistance. Ses deux bornes ont
quand même été déplacées sur le preset de difficulté, **dans un seul
sens** : la laisse sur un adversaire **en tête** est relâchée vers 1,0
(x1 : 0,93 → x2.5 : 1,00), pour qu'un adversaire devant ne puisse jamais
donner l'impression d'attendre.

#### 2. `a_lat` SATURE — c'est la limite de BRAQUAGE qui tient l'oméga

À l'oméga (rayon minimal 3,40 u), la vitesse tenable n'est pas
`sqrt(a_lat / k)` mais celle que le braquage permet :

```
v_steer = steer_rate / (k · headroom + steer_rate · e) = 4,17 u/s   (preset 7/10)
```

soit `a_lat ≈ 5,1` comme seuil au-delà duquel le virage le plus serré **ne
regarde plus `a_lat` du tout**. Le chat (`a_lat` 7,2) y est déjà saturé à
x1 ; le sanglier (4,6) ne l'est pas. Conséquence directe : la première
version de la table multipliait `a_lat` par 1,40 et **aplatissait les
personnalités** — chat et sanglier lisaient exactement 4,17 tous les deux à
l'oméga. C'est `top` (le boost tenu en ligne droite) qui porte l'essentiel
de chaque marche, et `a_lat` n'achète du temps que dans les virages moyens.

#### 3. L'ÉCHELLE EST COMPRESSIVE — le troisième preset s'appelle x2.5

Le plancher n'est qu'à 2,7 s à x1. Chaque marche suivante achète moins :
un preset x2 se serait posé à 0,45 s/tour du défaut, **à l'intérieur de la
dispersion d'un peloton qui fait encore des fautes**, et Mathieu ne l'aurait
pas senti au pouce. x2.5 est à ~0,7 s/tour du défaut, soit deux secondes sur
trois tours.

### Les trois presets, et les chiffres avant/après

Commutables **à chaud** depuis le HUD du kart derrière `DevTools.enabled()`
(`?keepydev=1`), sur le patron V7b exact des presets de direction 8/7/6, et
prenant effet **à la mise en grille suivante** — jamais au milieu d'un
virage.

| preset | `a_lat` | `top` | `a_brake` | `wobble` | `fault` | laisse min/max |
|---|---|---|---|---|---|---|
| **x1** | ×1,00 | ×1,00 | ×1,00 | ×1,00 | ×1,00 | 0,93 / 1,05 |
| **x1.5** (DÉFAUT) | ×1,12 | ×1,25 | ×1,08 | ×0,83 | ×0,75 | 0,97 / 1,08 |
| **x2.5** | ×1,22 | ×1,46 | ×1,15 | ×0,69 | ×0,54 | 1,00 / 1,11 |

Les **personnalités ne sont jamais remplacées, seulement mises à l'échelle** :
`KartAiDriver.PROFILES` garde le chat vif en virage et le sanglier rapide en
ligne droite, et `KartDifficulty.apply()` multiplie. Deux profils ne sont
**jamais** mis à l'échelle (`probe`, `human_ref`, `limit_ref`) : ce sont les
étalons, et un étalon qui bouge avec ce qu'il mesure ne mesure rien.

#### Temps au tour mesurés — course de 3 tours, graine 20260905, laisse active

| | x1 (= `staging`) | x1.5 (défaut) | x2.5 |
|---|---|---|---|
| Le Chat (chat) | **24,350** — 25,317 / 24,367 / 24,350 | **23,350** — 25,033 / 23,700 / 23,350 | **22,733** — 24,883 / 23,233 / 22,733 |
| Le Castor (castor) | **26,450** — 27,033 / 26,583 / 26,450 | **25,667** — 25,983 / 25,750 / 25,667 | **25,067** — 25,633 / 25,067 / 25,117 |
| Le Sanglier (sanglier) | **26,467** — 27,117 / 27,083 / 26,467 | **25,733** — 26,317 / 26,033 / 25,733 | **25,217** — 25,833 / 25,500 / 25,217 |
| déficit du meilleur au plancher | **2,700 s** | **1,700 s** | **1,083 s** |
| rapport au déficit x1 | 1,000 | **0,630** (cible 1/1,5 = 0,667) | 0,401 |
| vitesses de pointe réelles | 13,64 / 14,32 / 15,22 | 13,90 / 14,56 / 15,32 | 14,14 / 14,82 / 15,39 |
| fautes sur la course | 1 / 0 / 3 | 1 / 0 / 3 | 0 / 0 / 2 |

Le kart du joueur n'a **aucune constante modifiée** : ni vitesse, ni
accélération, ni adhérence, ni collisions. Toute l'adversité vient du côté
IA.

### Le relevé dev

Derrière `?keepydev=1`, le panneau de résultats gagne, sous le classement,
une ligne par concurrent : profil, les trois temps au tour, et l'écart au
vainqueur. `HubKarting` enregistre les temps par coureur (`laps_ms`), et
`results()` les publie avec le nom du profil. Un retour de Mathieu peut
maintenant être un tableau de chiffres.

### Ce que la sonde gate (6 contrats, 16 checks)

* **blind** : le bouton de difficulté change réellement la course (x1 et
  x2.5 séparés de plus d'une seconde) ;
* **blind** : le plancher est bien un plancher (aucun adversaire mesuré
  au-dessous) ;
* **D2** : les trois presets sont ordonnés et séparés d'au moins 0,35 s ;
* **D1** : le preset par défaut ramène le déficit dans [0,55 ; 0,80] de
  celui de x1 ;
* **D3** : à **chaque** preset, le chat reste plus rapide que le sanglier
  sur le quart le plus tortueux et l'inverse sur le quart le plus droit, et
  leurs biais de trajectoire gardent des signes opposés.

⚠️ **D3 ne se lit PAS à l'échantillon le plus serré**, où la première
version le lisait et se trompait : tout profil au-dessus de `a_lat ≈ 5,1`
y est épinglé sur la même limite de braquage, donc chat et sanglier y sont
égaux dès que la difficulté monte — un rouge sur des personnalités
parfaitement intactes partout ailleurs.

---

<a name="p0bis"></a>
## 2. P0 BIS — LE CHAR NE STATIONNE PLUS SUR LE CIRCUIT

Mathieu avait garé le char à voile sur la grille de départ ; rien ne l'en
empêchait.

**La garde est une propriété de OÙ IL PEUT ROULER**, écrite une fois :

```gdscript
static func drivable(point: Vector3) -> bool:
    return HubRegion.contains(point) and not HubRegion.in_circuit(point)
```

Un véhicule qui ne peut pas entrer sur le circuit ne peut pas être sur la
grille au moment des feux, donc **la garde n'a aucun crochet dans la
course** — pas de repositionnement au démarrage, pas d'état à tenir en
phase. C'est la solution la moins intrusive des deux proposées, et c'est
aussi la seule qui survit à un rechargement.

Une **sauvegarde écrite avant CH30** peut contenir un char garé sur la
grille (celle de Mathieu). `HubTransport._build_yacht()` teste `drivable`
et non `contains` : un char sauvegardé là revient à son parc.

Gaté par `CoveProbe` :

* les 24 points du ruban du circuit **et** la grille sont tous refusés
  (28/28), et le même test **accepte** la lande à côté (blind) ;
* conduit droit sur l'entrée du couloir pendant **21 s depuis trois caps
  différents**, le char n'y entre **jamais** (0 frame à l'intérieur), et le
  blind check confirme que la course a réellement atteint la bouche du
  couloir (approche 0,00 u) ;
* un char sauvegardé sur la grille revient au parc à la construction.

---

<a name="p1a"></a>
## 3. P1a — L'EXTRACTION DU CONTRÔLEUR, ET SA PREUVE

### Ce qui a été extrait

`VehicleDrive` : tout ce que `KartBody.drive()` faisait à une **position, un
cap et une vitesse monde**, et rien de ce qu'il faisait à un châssis. Une
instance par véhicule, avec ses propres constantes. Le kart garde son art,
son roulis, ses roues, son bump ; il lit le preset de direction vivant et
écrit son transform **une seule fois**.

Le char à voile consomme le même composant, avec ses propres nombres, et le
**même** `KartTouchInput` écrivant le **même** `KartInput`. Il n'existe
nulle part une seconde copie de la logique de conduite.

### La preuve — et le piège qui l'a d'abord fait échouer

`KartTraceProbe` conduit le kart du joueur avec le profil déterministe
`probe` pendant 5 400 frames et imprime position, cap, vitesse et écart
latéral toutes les 30 frames, plus les trois temps au tour. Rejouée sur
`origin/staging` et sur cette branche.

**Premier essai : NON identique.**

| | `origin/staging` | branche (v1) |
|---|---|---|
| tours | 26,550 / 26,200 / 26,217 | 26,533 / 26,217 / 26,200 |
| état final | x = 14,372494 | x = 14,314851 |
| premier écart | — | frame 30, dernier chiffre imprimé |
| écart à la frame 1200 | — | 0,070 u |

Rien n'était faux : c'était une **différence de TYPE**. `rotation.y` est une
composante de `Vector3`, donc un **float32** dans un build simple précision,
et `rotation.y -= x` tronquait à 32 bits **à chaque frame physique** depuis
toujours. Un `float` GDScript est un **float64** : l'extraction, en portant
le cap dans une variable locale, gardait silencieusement 29 bits que le kart
livré n'avait jamais eus. Sur un contrôleur de poursuite pure, qui reboucle
le braquage sur la trajectoire et la trajectoire sur le braquage, cela sépare
les deux builds en trente frames.

`VehicleDrive` écrit désormais le cap **à travers une cellule `Vector3`**,
qui tronque exactement là où le nœud le fait.

**Second essai :**

```
$ diff trace_base.tab trace_branch2.tab
TRACE IDENTICAL          (180 échantillons, 5400 frames)
LAPS: 26.550, 26.200, 26.217     BEST: 26.200
FINAL: x=14.372494 z=-188.915329 yaw=-1.099774 v=10.190460
```

**Byte-identique sur les 180 échantillons et sur les trois temps au tour.**
L'extraction est un déplacement pur. Aucune dette de duplication.

⚠️ **L'entrée piéton n'a pas été touchée.** `KeepyHopper`, `HubTapInput`
(hors la ligne qui refuse les taps pendant une conduite) et les presets de
direction 8/7/6 sont intacts ; `KartTuning.PRESETS` est byte-identique à
`origin/staging`.

### Le char comme véhicule conduit

| | CH29 (glisse) | CH30 (conduite) |
|---|---|---|
| entrée | un tap = une glisse plate | appui continu, direction au pouce |
| modèle | modificateur de hop dans `KeepyHopper` | `SandYacht` + `VehicleDrive` |
| passager | `mount_vehicle` (le véhicule suit le corps) | `mount_carrier` sur le **pont** (il gîte avec le bateau) |
| caméra | figée | poursuite (`HubCamera.enter_drive`) |
| allure | 3,2 u / 0,30 s = 10,67 u/s × vent | `BASE_SPEED` = **le même 10,67** × vent |

L'allure est celle de CH29 **au mètre près** : CH30 a changé comment le
véhicule est piloté, pas à quelle vitesse il traverse la carte. Mesuré sur
la ligne droite de la lande : **10,40 u/s** au soleil (autorisé 10,67),
**12,99 u/s** en orage — un rapport de **1,249** contre un facteur de vent
de **1,250**.

Ses nombres propres, et pourquoi ils diffèrent du kart : une voile monte en
vitesse lentement (`ACCEL_LAMBDA` 0,55 contre 0,85), glisse davantage sur le
sable (`GRIP` 3,2 contre 5,0), freine moins fort (9,0 contre 15,0 — 58
frames pour s'arrêter de 10,4 u/s, mesuré) et **gîte vers l'extérieur** du
virage là où le kart s'incline vers l'intérieur : c'est la lecture qui les
distingue d'un coup d'œil. Le **taux de braquage n'est pas un littéral** :
c'est le preset `KartTuning` vivant × 0,85, donc le bouton 8/7/6 déplace les
deux véhicules et aucun ne peut dériver de l'autre.

### ⚠️ LE MUR A BLOQUÉ LE VÉHICULE — trouvé dès la première passe de sonde

Le mur du char est **séparé par axe** : le mouvement complet s'il tombe sur
du sol conduisible, sinon la moitié x ou la moitié z seule. Sur une bordure
rectangulaire c'est parfait : le char la longe.

En roulant plein est à travers la lande, il a rencontré le **trou du
moulin** de face. La moitié x était refusée (c'est le chemin vers le trou) ;
la moitié z était « conduisible » — parce qu'avec un cap plein est, la
moitié z **ne bouge rien**, donc c'est le point que le char occupe déjà — et
elle a été acceptée en annulant `velocity.x`. À partir de là le char est
resté **à vitesse nulle contre l'obstacle pour toujours** : le modèle de
conduite ne donne aucune autorité de braquage à vitesse nulle (un véhicule à
l'arrêt ne pivote pas), et l'accélérateur automatique le repoussait dans le
mur à chaque frame. Un joueur aurait dû descendre et marcher.

Correctif : une demi-course n'est acceptée **que si c'est une course**, et
un refus qui ne laisse nulle part où aller **rebondit** (`WALL_BOUNCE`
0,45) au lieu de s'arrêter — assez pour garder la direction vivante le temps
de se détourner. Ça se lit comme un coup de nez dans un rocher, ce que c'est.

---

<a name="p1b"></a>
## 4. P1b — LA CAMÉRA DE POURSUITE ET L'AUDIT VISUEL

### La caméra

Aucun code caméra n'a été écrit. `HubCamera.enter_drive(node)` ne demandait
qu'un `global_position` et un `rotation.y` ; le char en a. Le mélange, la
distance, le retard de cap, le plan lointain à 120 u et le retour au repère
du hub sont ceux du kart, à la ligne près.

### L'instrument : `ChaseAudit`

160 frames rendues : **5 stations** (plateau, vallon, lande, circuit,
crique) × **8 azimuts** × **4 météos**, sous `xvfb-run --rendering-driver
opengl3` — jamais `--headless`, et la sonde **refuse de rendre un verdict**
si elle se retrouve sur le driver dummy (elle sort `INCONCLUSIVE`, code 2 ;
sous `--headless` le SubViewport ment en annonçant 1920×1920).

Plus trois audits statiques : l'enroulement de chaque surface construite en
code, la distance de cull de chaque `MeshInstance3D` contre la portée de la
caméra de poursuite, et la luminance de vertex de chaque arbre de décor.

### Les défauts trouvés

#### 1. LES PILOTES ADVERSES ÉTAIENT INVISIBLES — des karts sans tête

`HubCritter.CULL_DISTANCE` vaut 52 u, **mesuré contre la caméra FIXE** à
11,7 u. La caméra de poursuite est à 7,6 u en arrière, 60° de champ, plan
lointain 120 u, et elle regarde **le long de la piste** avec trois
adversaires dessus : leurs karts se dessinaient, leurs pilotes non.

Corrigé : le cull devient **par instance** (`HubCritter.cull_distance`,
défaut inchangé) et les trois pilotes du kart reçoivent le plan lointain de
la caméra de poursuite (`HubKarting.RIDER_CULL = HubCamera.DRIVE_FAR`,
120 u). Gaté : *« aucun pilote de kart n'est cullé dans la bande lisible de
la caméra de poursuite »*, 3 → **0**.

Les **critters qui marchent dans le hub gardent 52 u, délibérément** : les
monter aggraverait la frame du SPAWN, qui est déjà au-dessus de son plafond.
C'est une limite connue, mesurée et acceptée, pas un oubli.

#### 2. LE CYPRÈS EST NOIR

Tout est unlit et **rien ne post-traite la frame**, donc la couleur qu'un
`.glb` porte est littéralement celle qui arrive à l'écran. Luminance moyenne
des couleurs de vertex :

| asset | luminance | |
|---|---|---|
| `tree_4_conifer` | 0,3159 | |
| `olive_0` | 0,2787 | |
| `bush_0` | 0,2542 | |
| `palm_0` | 0,1868 | |
| **`cypress_0` / `cypress_1`** | **0,0692** | **4× plus sombre que tous** |

Le sol du hub rend à **L = 0,0799** : le cyprès est donc **plus sombre que
le sol sur lequel il pousse**, à 1,09:1 — indiscernable en luminance, et une
silhouette noire contre le ciel. La caméra fixe n'approchait jamais à moins
de 11,7 u et la brume le cachait ; la caméra de poursuite passe à deux
mètres.

Corrigé par un **gain uniforme ×4,4** sur le `tint` du shader de décor
(`CozyPalette.FAMILY_GAIN`) : 0,0692 × 4,4 = **0,305**, entre l'olivier et
le conifère, et le multiplicateur étant uniforme, `(0,025 ; 0,086 ; 0,037)`
devient `(0,110 ; 0,378 ; 0,163)` — **exactement la même teinte**, quatre
fois et demie plus claire. Confirmé au rendu : le pixel du tronc passe de
`(0, 10, 0)` à `(10, 64, 30)`, et rien d'autre dans la frame ne bouge.

⚠️ **Le `.glb` n'est pas touché.** C'est un asset de Mathieu : la correction
de valeur vit dans le rendu, révocable en une ligne, et l'asset est signalé
pour qu'il le ré-exporte s'il préfère.

#### 3. Deux étalons de la sonde étaient faux AVANT le monde

* **Le prédicat d'enroulement avait le signe à l'envers** et déclarait
  cassés les **huit** rubans du hub. Godot tient les faces **horaires** pour
  faces avant, donc la normale de face avant est **−n** et un ruban de sol
  doit lire **n.y < 0**. Les huit lisent −1,000 : tous corrects. Le ruban du
  ruisseau — celui pour lequel `CLAUDE.md` a écrit la règle — sert désormais
  d'**ancre** : s'il lit un jour « cassé », c'est le prédicat qui l'est.
* **La mesure de « frame vide » échantillonnait le ciel au pixel du haut au
  centre**, et à `circuit/180` ce pixel est le **mât crème du portique de
  départ** à un mètre : 58 % d'une frame parfaitement pleine rapportés comme
  ciel. Médiane de trois points sur la ligne du haut.

#### Ce qui a été regardé et jugé sain

Aucun ruban disparu, aucune face arrière manquante, aucun `pop-in` dans la
bande lisible hors le cas des pilotes, aucune frame noire, aucun azimut sur
un monde vide, et le décor tient sous les quatre météos aux cinq zones. Les
deux stations où une capture semblait cassée étaient des stations mal
choisies — la caméra **dans** le tronc de l'Arbre Mère (2 u de son trou de
2,7 u), et la caméra contre le mât du portique — pas des défauts du monde.
La première a été déplacée à 12 u à l'ouest.

### Budget triangles

Ligne `gpu` (celle que `CLAUDE.md` impose de gater), jamais `scene`.

| frame | avant | après |
|---|---|---|
| pire frame de poursuite, 160 rendues | 94 055 (`snow/hollow/180`) | 100 520 (`storm/cove/270`) |

Le plafond de 50 k était déjà dépassé au spawn sur `staging` (73 861) ; il
l'est davantage sous une caméra qui regarde l'horizon avec 60° de champ, ce
que `CLAUDE.md` documentait déjà pour le kart (123 515 à la ligne de départ
en V7). **Le lot n'aggrave pas la frame du SPAWN** — la seule chose qu'il a
ajoutée au monde est un cull de pilote plus long, sur trois modèles situés à
100 u du spawn, et un gain de teinte qui ne coûte pas un triangle.

---

<a name="reste"></a>
## 5. CE QUI N'A PAS ÉTÉ FAIT, ET POURQUOI

* **P2 — retour sensoriel de la conduite** (son moteur ou de glisse,
  poussière de roues, effet de vitesse) : sacrifié, comme le brief
  l'autorisait. La P1 a mangé la nuit — l'extraction a demandé une seconde
  passe complète après le piège float32, et l'audit visuel a produit deux
  correctifs de monde et deux correctifs d'étalon.
* **Le cull des critters qui marchent dans le hub (52 u)** : laissé tel
  quel, décision documentée ci-dessus (frame du spawn déjà au-dessus du
  plafond).
* **Le mât du portique de départ vu à un mètre** : laissé tel quel. C'est
  un cylindre crème uni qui remplit le cadre pendant une fraction de seconde
  quand un kart passe sous le portique. Signalé, pas corrigé.
* **Les couleurs de `cypress_0/1` dans le `.glb`** : signalées, pas
  réécrites. Le gain de rendu est la correction révocable ; la correction à
  la source appartient à Mathieu.
