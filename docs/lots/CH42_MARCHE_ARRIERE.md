# CH42 — Le blocage falaise, et la marche arrière des quatre véhicules

> Base `origin/staging` au commit `13613b5` (fin CH41). Deux sujets, dans
> l'ordre que le brief impose : **diagnostic d'abord**, correctif ensuite.

## CH42-0 — La question, et la réponse en une ligne

Mathieu reste coincé près d'un bord du domaine Mountain **même en tournant à
fond**. Le brief nommait quatre hypothèses. Mesurées, **aucune des quatre
telle qu'écrite** : le mur est correct, la géométrie n'est morte que dans les
coins, la pente ne peut pas s'y annuler contre le mur — et ce qui bloque est
**le gain de braquage**, qui n'était dans aucune des quatre.

## CH42-1 — ÉTAPE 1, LE DIAGNOSTIC : quatre hypothèses, quatre verdicts

`ReverseProbe` PHASE WALL et PHASE PIN, 28 points d'échantillonnage sur les
**trois vrais murs** de la crête (nord z = 18, sud z = −12, ouest x = −63 ;
le bord est x = −35 est partagé avec le carré du plateau et n'est pas un mur),
chacun joué **aux deux braquages à fond**, 600 frames (10 s).

| hypothèse du brief | verdict | preuve |
|---|---|---|
| le mur / prédicat de bornage ne repousse pas sur cette portion | **ÉCARTÉE** | 28/28 points intérieurs `drivable`, 28/28 points à 1 u au-delà refusés |
| coin géométrique qu'aucune rotation ne dégage | **CONFIRMÉE, mais pour les coins seulement, et pas pour la raison supposée** | 4 runs sur 56 ne s'éloignent **jamais** de 4 u en 10 s ; le pire atteint **1,04 u** au plus loin |
| luge : `SLOPE_GAIN` / `climb_authority()` s'annulant contre le mur | **ÉCARTÉE** | un bord de crête est **plat par contrat** — `HubSurface` refuse un domaine dont le périmètre n'est pas à 0 (raccord C0). Pire échantillon de bord : pente 0,0865, soit **2,19 u/s² contre 13,60** d'autorité de montée (**16 %**) |
| une combinaison | **c'en est une — mais d'un mur CORRECT et d'un INPUT MANQUANT** | ci-dessous |

### La cause, mesurée et nommée

`VehicleDrive` fait tourner le cap à `|v_fwd| / steer_full_speed` de la
vitesse de lacet pleine — **`v_fwd`, la composante AVANT, pas la vitesse**.
Or contre un mur, la composante avant est exactement ce que le mur mange :

> Pire épingle, **(−62 ; 17,7)** cap nord, braquage +1 : **600 frames sur le
> mur**, vitesse avant moyenne **0,0851 u/s**, soit un gain de braquage de
> **0,0284 — 2,8 % du braquage à fond**. Excursion maximale : **1,04 u**.
> Le même braquage à fond **en terrain libre** met **59 frames (0,98 s)** à
> parcourir 4 u.

Le coin est inéchappable **parce que le lacet y est nul**, pas parce qu'il est
étroit. Et rien ne le signale : ni erreur, ni sonde rouge avant celle-ci.

⚠️ **CONCLUSION D'ESCALADE : aucun correctif de mur n'est nécessaire.**
`HubRegion.gd`, `HubSurface.gd` et `SandYacht._wall` ne sont pas touchés par
ce lot. PHASE ESCAPE le prouve dans l'autre sens : la marche arrière **seule**
libère les 112 épingles, coin mort compris.

## CH42-2 — ⚠️ LA MÉTRIQUE ÉTAIT FAUSSE, ET ELLE A FABRIQUÉ QUATRE FAUSSES ÉPINGLES

Écrit ici parce que c'est une **doctrine neuve** et qu'elle a coûté deux
versions de la phase.

La première version mesurait « bloqué » par la **distance au départ après
600 frames**. Elle a rendu 4 épingles qui n'en sont pas. Tracé :
l'échantillon qui « a parcouru 0,570 u en 10 s » passe **4,7 s sur le mur**,
se dégage, parcourt une boucle de **36,7 u à 352,7° de braquage tenu**, et
**revient exactement d'où il part**.

**Un braquage tenu dessine un cercle, et un cercle finit où il commence.** Un
véhicule libre et un véhicule épinglé rendent alors le même chiffre.

Pire, la même erreur a contaminé la mesure de la CAUSE : moyennée sur tout le
run — c'est-à-dire majoritairement sur une boucle libre à 6 u/s — la vitesse
avant donnait un gain de braquage de **0,59 à 0,67**, un nombre qui dit que le
véhicule braque parfaitement bien, pris sur les secondes où il n'est pas
bloqué. Deux versions ont publié ce chiffre avant qu'il ne soit vu.

**Parade, et c'est la règle** : un run est noté sur la **PREMIÈRE FRAME où il
atteint un rayon d'échappement**, jamais sur l'endroit où il se trouve quand
le chronomètre s'arrête ; et toute moyenne qui décrit un état (« sur le mur »)
est prise **sur la fenêtre où cet état tient**, jamais sur le run entier.

## CH42-3 — ÉTAPE 2 : la marche arrière, un INPUT et non une vitesse négative

* `KartInput.reverse : float` (0..1, tenu), **à côté** de `throttle` et non
  dessus. `reset()` l'efface, `set_all()` le prend en 5ᵉ paramètre **par
  défaut 0** — donc `KartAiDriver`, `KartProbe` et les deux sondes de trace
  écrivent exactement ce qu'elles écrivaient.
* `VehicleDrive.step()` : **une branche `elif`**, sous `brake`, et le fichier
  est une **addition pure — zéro ligne retirée** (`git diff` : 40 lignes,
  toutes en `+`).
* La moitié « encore lancé vers l'avant » de la branche est **l'arithmétique
  du frein, énoncé pour énoncé**, sur le même seuil 0,3 : le freinage qu'un
  joueur ressent est le même float. La moitié neuve est la rampe :
  `move_toward(v_fwd, −reverse_speed × reverse, reverse_accel × delta)`.
* **Le braquage n'est pas touché, et il ne devait pas l'être.** La ligne
  `if v_fwd < -0.05: gain = -gain * 0.7` existait déjà et lit la **vélocité**,
  pas l'input : elle était juste pour le recul du frein, elle l'est pour
  celui-ci, sans seconde orthographe de la règle.

### Les constantes, par véhicule

| véhicule | `REVERSE_SPEED` | vs vitesse avant | `REVERSE_ACCEL` (u/s²) |
|---|---|---|---|
| kart | 3,50 | 15,00 (23 %) | **6,00** = `BRAKE_DECEL × 0,4` — le kart recule **exactement** comme avant |
| char à voile | 2,40 | 10,67 (22 %) | **6,00** (était 3,60) |
| voilier | 2,60 | 9,50 (27 %) | **4,00** (était 2,20) — le plus doux : une coque abat, elle n'enclenche pas |
| luge | 2,20 | 8,50 (26 %) | **13,00** — voir ci-dessous |

Les quatre `REVERSE_SPEED` **existaient déjà** et sont toutes bien sous la
vitesse avant : elles sont lues, pas retapées.

### ⚠️ La luge : `REVERSE_ACCEL` n'est pas un nombre de feeling

Reculer nez vers l'aval, **c'est monter**. La branche répond à la pente par
une rampe plate en u/s², donc l'inégalité est plus simple que celle de
`climb_authority()` : si la pente pousse plus fort que la rampe, l'engin ne
recule pas *lentement*, il **ne recule pas du tout**. Publiée en
`SledBody.reverse_authority()` et gatée :

> pente la plus raide du domaine **(−44 ; 7)**, |g| = 0,5280 (27,83°) :
> **10,5312 u/s² contre 13,0000 — 81 % utilisés.**

Mesuré des deux côtés, gaz tenu : nez à l'aval **−5,971 u** (il monte à
reculons), nez à l'amont **−6,500 u**. Vitesse la plus basse **−2,197 u/s** :
ce n'est pas le gel CH41 à 0,000. L'ordre force/`step()` de `SurfaceDrive`
est inchangé — la branche vit **dans** `step()`, donc la force reste injectée
après, exactement comme CH41 l'a corrigé.

## CH42-4 — Ce que la marche arrière achète, mesuré

`ReverseProbe` PHASE ESCAPE, 112 épingles (luge + char à voile, 28 bords ×
2 braquages × 2 véhicules) :

| | sans la marche arrière | avec |
|---|---|---|
| temps moyen pour s'éloigner de 4 u | **439,1 frames (7,3 s)** | **119,7 frames (2,0 s)** |
| pire cas | **600 frames — jamais** | **143 frames (2,38 s)** |
| le coin mort (−62 ; 17,7) | **1,04 u en 10 s** | **4 u en 118 frames (1,97 s)**, 9,72 u au plus loin |

`GEAR_FRAMES_CEILING = 180` est ce pire cas mesuré avec un cinquième de
marge : une passe de réglage qui rendrait la marche arrière plus lente échoue
ici plutôt que sur le pouce de Mathieu.

## CH42-5 — Le gain est atteignable AUJOURD'HUI, et c'est la dette du lot

Le **second doigt** (et le bouton droit de la souris, et bas / S / espace hors
web) écrit désormais `input.reverse` au lieu de `input.brake`. `brake` n'a
plus qu'un seul écrivain, `KartAiDriver`, qui l'utilise pour ce qu'il a
toujours voulu dire : freiner avant un virage, à des vitesses où la moitié
recul n'est jamais atteinte. **Un champ répondait à deux questions** — la
famille de défaut que `clamp_to` a coûtée à ce dépôt (CLAUDE.md, AIM contre
DESTINATION CLAMPÉE).

⚠️ **DETTE EXPLICITE, ET C'EST LE DÉFAUT CH31 QUI SE REJOUE.** Le geste
existe et **rien ne l'annonce** : ni HUD, ni jauge, ni ligne d'aide — comme
l'accélérateur de V7b, qui existait et que Mathieu n'a pas trouvé. Ce lot ne
touche pas au HUD (hors brief). **Si Mathieu était coincé faute de connaître
le second doigt, ce lot lui rend un geste tuné, pas un geste découvrable.**
La découvrabilité est à ouvrir comme son propre lot.

## CH42-6 — Rouge-avant-vert

Branche neutralisée (`elif input.reverse > 0.0:` → `elif false:`) :
**19 rouges attendus, 19 rouges obtenus, aucun autre.** PHASE WALL et
PHASE PIN restent **vertes** — elles ne dépendent pas de la marche arrière,
et une passe rouge qui les aurait fait tomber aurait voulu dire que le
diagnostic mesurait le correctif. Fichier restauré, `cmp` byte-identique.

Blind checks : `KartInput` neuf à 0 et `reset()` qui l'efface ; le char à
voile en terrain libre **+16,407 u** sans la marche arrière et **−6,740 u**
avec (le SIGNE, pas la distance) ; le témoin de PHASE PIN en terrain libre
(59 frames) sans lequel « 120 frames c'est long » n'aurait pas de plancher ;
et pour chaque véhicule le **déplacement** exigé en plus de la vitesse
négative — une vitesse sans déplacement est le faux-vert que ce dépôt a
trouvé quatorze fois.
