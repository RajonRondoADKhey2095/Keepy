# CH70 — La croisière du skate, rouverte et REFUSÉE PAR LA MESURE

> Chantier ouvert le 11 septembre 2026 sur **autorisation explicite de
> Mathieu**. C'est une réouverture volontaire d'une décision structurante
> verrouillée depuis quatre chantiers (CH61 → CH69), motivée par un retour
> device **répété à travers plusieurs sessions** — « ça va trop vite en
> croisière, tout le temps » — et non par une intuition ponctuelle.
>
> **Le lot a fait le changement, l'a mesuré, et ne l'expédie pas.** Ce qui
> est livré est la MESURE qui l'a refusé, plus la réparation d'un rouge
> pré-existant trouvé pendant le recon.

## Section 1 — LE RECON A TUÉ DEUX PRÉMISSES DU BRIEF AVANT LA PREMIÈRE LIGNE DE CODE

Le brief demandait trois valeurs :

```
croisiere  : 10.0000  -> 6.5000
push       : 17.2165  -> 11.1907
brake      : 10.3433  -> 6.7231
```

### 1.1 — `push` et `brake` ne sont pas des constantes de ce dépôt

Elles sont **RÉSOLUES** par `SkateBoardBody.configure(cruise, accel_u,
brake_u, coast_u)`, appelé une fois depuis `HubTransport.gd:486`. Le
fichier l'écrit en capitales :

> ⚠️ THE FOUR DISTANCES ARE THE AUTHORED THING AND THE ACCELERATIONS ARE
> DERIVED, never the other way round.

Les retaper aurait été la seconde orthographe que toute cette convention
existe pour refuser (`CLAUDE.md`, « un fait est publié une fois, jamais
recopié »).

### 1.2 — L'arithmétique du solveur : ×0,65 sur la croisière ne fait pas ×0,65 sur les accélérations

Posée une fois, elle se lit toute seule. Avec `s = COAST_QUADRATIC_SHARE`
et `span = ln(1/(1−s))` :

| grandeur | forme | dépend de la croisière ? |
|---|---|---|
| `drag_k` | `span / (2 · coast_u)` | **NON** |
| `roll_stop` | `(1−s)/s · drag_k · cruise²` | **cruise²** |
| `push` | `drag_k · cruise² · C(accel_u, coast_u)` | **cruise²** |
| `brake` | `drag_k · cruise² · C'(brake_u, coast_u)` | **cruise²** |

Donc une croisière à ×0,65 rend des accélérations à **×0,4225**. Ce n'est
pas une approximation : c'est exactement ce qui **CONSERVE** les distances
authored de CH54 (run-up 3,2 u, run-out 3,2 u) à la nouvelle vitesse.

Forcer ×0,65 sur le `push` aurait exigé de déplacer les distances :

| cible | distance impliquée | authored |
|---|---|---|
| `push` = 11,1907 | run-up **1,844 u** | 3,20 u |
| `brake` = 6,7231 | run-out **2,365 u** | 3,20 u |

Une planche qui atteint sa croisière en 1,84 u au lieu de 3,20 a un départ
**PLUS sec** qu'aujourd'hui — l'inverse exact de ce que le retour device
demande. **Décision de Mathieu, prise sur cette table avant tout code :
seule la croisière bouge.**

### 1.3 — ⚠️ LES CHIFFRES DE BASELINE DU BRIEF ÉTAIENT PÉRIMÉS, ET UNE SONDE ÉTAIT ROUGE DEPUIS CH69

`17,2165 / 10,3433` sont les valeurs d'un `coast_u` de **18,043 u**,
c'est-à-dire du `park_span()` **d'AVANT CH69**. CH69 a porté ce span à
23,201 u ; sur l'arbre livré `0ecc4a4` les valeurs réelles sont
**16,4253 / 11,0800**.

Trouvé **par arithmétique, avant de lancer quoi que ce soit**, puis
reproduit : `SkateFeelProbe` PHASE W portait ces deux littéraux et gatait
`|push − 17,2165| < 0,01`. Sur l'arbre livré :

```
     board: push 16.4253  brake 11.0800  (CH61 published 17.2165 / 10.3433)
  [RED] W INSTRUMENT: this is CH61's board, to the fourth decimal
```

**120 OK / 1 RED sur `origin/staging` intact.** La table croisée de CH69
n'incluait pas cette sonde — c'est ce qui l'a laissée passer. C'est le
couplage que CH69 a élucidé (`park_span() → skate_coast_u() →
configure()`) pris sur le fait : **un nombre recopié hors du solveur se
périme au premier déplacement de module, et rien ne prévient.**

## Section 2 — ⚠️ LA MESURE : LA CROISIÈRE NE PEUT PAS BAISSER DU TOUT

Changement appliqué (`SKATE_CRUISE 10.0 → 6.5`), suite rejouée. Le modèle
a fait exactement ce que la section 1.2 annonçait :

| grandeur | 10,0 | 6,5 | rapport |
|---|---|---|---|
| `push` | 16,4253 | **6,9397** | 0,4225 |
| `brake` | 11,0800 | **4,6813** | 0,4225 |
| `drag_k` | 0,02988 | 0,02988 | **1,000** |
| run-up mesuré | 3,471 u | 3,4xx u | inchangé |

Et la couche de tricks s'est éteinte :

| sonde | avant | après (6,5) |
|---|---|---|
| `SkateAirProbe` | 40 / **0** | 22 / **18** |
| `SkateTrickProbe` | 54 / **0** | 53 / **1** |
| `SkatePhysicsProbe` | 161 / **0** | 158 / **3** |
| `SkateFeelProbe` | 120 / 1 | 120 / 3 |

Le nombre qui explique les quatre lignes d'un coup :

```
[2] quarterpipe straight  peak y 0.999 (lip 2.10)  pops 0  WINDOW 0.000 s
[3] quarterpipe straight  peak y 0.903 (lip 1.45)  pops 0  WINDOW 0.000 s
```

**La planche n'atteint plus AUCUNE lèvre.** La montée d'une transition est
plafonnée par la croisière (`SkateBoardBody.drive()` n'ajoute rien au-delà
de `_cruise`), donc la croisière décide si une lèvre est atteinte. Sans
lèvre : pas de `POP_SPEED`, pas d'aire, pas de trick, pas de cue
d'atterrissage, et la sortie du bol (PHASE Y) ne pope plus.

### 2.1 — ⚠️ LE BALAYAGE, ET C'EST LE RÉSULTAT DU LOT

Huit valeurs, une ligne changée à chaque fois, `SkateAirProbe` headless
`--fixed-fps 60`. Le contrat CH66 est **0,762 s** de fenêtre (pouce de
référence r 40 px à 400 px/s = 0,562 s, plus 0,20 s de réaction) :

| croisière | pop 2,10 | pop 1,45 | fenêtre V[2] | fenêtre V[3] | rouges |
|---|---|---|---|---|---|
| 6,5 | 0 | 0 | 0,000 s | 0,000 s | 18 |
| 7,0 | 0 | 0 | 0,000 s | 0,000 s | 18 |
| 7,5 | 0 | 0 | 0,017 s | 0,000 s | 18 |
| 8,0 | 0 | 0 | 0,000 s | 0,000 s | 18 |
| 8,5 | 0 | 1 | 0,000 s | 0,650 s | 9 |
| 9,0 | 0 | 1 | 0,000 s | 0,783 s | 7 |
| 9,5 | 1 | 1 | 0,700 s | 0,867 s | **1** |
| **10,0** | 1 | 1 | **0,817 s** | 0,900 s | **0** |

**Le premier échelon qui tient le contrat est 10,0, et il le tient avec
0,055 s de marge (7 %).** À 9,5 le grand quarterpipe est déjà court.

Donc ce n'est pas « 35 % c'est trop » : **cette croisière ne peut pas
baisser du tout** sur le park tel qu'il est authored. C'est le pendant de
CH68 (« retirer la retombée laisse 56 avant, 56 après ») — un balayage qui
répond « aucune position » ne dit pas quel levier tirer, et ici le levier
n'est pas la croisière.

### 2.2 — Ce qui est vraiment le paramètre

Les lèvres (2,10 et 1,45 u, CH60) ont été dessinées contre une planche à
10,0 u/s. C'est la **PAIRE** (croisière, hauteur de lèvre) qui porte la
fenêtre, et la croisière en est aujourd'hui la moitié saturée. Ralentir la
planche demande donc l'une de ces trois choses, **aucune n'étant dans le
périmètre de ce lot** :

1. **ré-authorer les rampes** (CH60), en re-gatant CH66 et la retombée
   CH67/CH69 derrière ;
2. **vendre la vitesse autrement** — la couche CH62 (`SkateStreaks`,
   `fov`, `pitch_scale` du roulement, la caméra) est ce qu'un joueur LIT
   comme de la vitesse, et elle se règle sans toucher au budget d'énergie
   des rampes. ⚠️ **Proposition, non mesurée** : `CLAUDE.md` CH62 interdit
   qu'un banc vert sous-entende un ressenti, et rien ici ne dit que ça
   répondrait au retour device ;
3. **accepter que le skatepark tourne à 10,0** et que la plainte porte sur
   autre chose que la croisière du park (les traversées du hub, par
   exemple, qui passent par le même véhicule).

### 2.3 — Les rouges qui ne sont PAS la couche de tricks, rapportés séparément

| rouge | ce que c'est |
|---|---|
| `SkateAirProbe` W[2]/W[3] « reached the foot near cruise » | ⚠️ **une sonde calibrée sur l'ancienne vitesse** : `_check(speed_at_foot > 8.0)` porte un **littéral 8,0** là où il voulait dire « près de la croisière ». C'est une seconde orthographe de `SKATE_CRUISE`. **Signalé et NON corrigé** — le brief l'interdit, et le corriger en silence aurait maquillé un rouge. À reprendre en `HubTransport.SKATE_CRUISE * 0.9` **si** la croisière bouge un jour. |
| `SkateInertiaProbe` E[3] « phantom volume » (2,198 ≤ 1,450 + 0,60) | l'échelon **injecté à 10 u/s** — une vitesse que la planche ne peut plus atteindre — vole plus haut parce que `roll_stop` a chuté avec `cruise²`. Le gate était déjà **sur sa propre limite** (2,023 contre 2,050 avant, soit 0,027 de marge) : `CLAUDE.md` CH69, « un optimum se pose exactement sur la contrainte qui le borne ». |
| `SkatePhysicsProbe` PHASE I « idle park under budget » (0,1949 ≤ 0,10) | **artefact de charge machine, pas une conséquence** : la lecture idle est passée de −0,0008 à 0,1949 ms/tick pendant que la lecture *ridden* passait de 1,5528 à 1,3061 — deux runs qui n'ont pas partagé la même machine. Rien dans ce lot ne touche un collider. Rejoué sur l'arbre final : **vert**. `CLAUDE.md` CH37 : une sonde à séquence temporelle se rejoue à charge comparable, ou son verdict n'est pas comparable. |

## Section 3 — CE QUI EST LIVRÉ : `SkateFeelProbe` PHASE W REDEVIENT UN INSTRUMENT

Le rouge de la section 1.3 est réparé, et **pas en remettant les deux
littéraux à jour** — ce qui aurait reconstruit le piège pour le prochain
lot qui déplace un module.

Le gate voulait dire « ce banc regarde la planche que `HubTransport` a
CONFIGURÉE, pas une planche par défaut ». Ça se teste sans retaper un
chiffre : une planche de **RÉFÉRENCE** est configurée avec les entrées
**publiées** (`SKATE_CRUISE`, `SKATE_ACCEL_U`, `SKATE_BRAKE_U`,
`skate_coast_u()`) et l'égalité des quatre accélérations est exigée. Le
solveur reste écrit **une seule fois**, dans `configure()` : le
ré-implémenter dans la sonde en ferait une tautologie (`CLAUDE.md` CH62),
le recopier en ferait la seconde orthographe qu'on vient de payer.

⚠️ **Et il porte son propre blind check**, parce que « ces deux objets sont
égaux » passe **gratuitement** contre deux planches également non
configurées : une troisième planche (`DECOY_CRUISE = 3.0`) doit d'abord
sortir **différente**.

### 3.1 — Passe rouge

Référence nourrie du coast **pré-CH69** (18,043) au lieu du publié :

```
     solved from the published inputs (...): push 17.2166  brake 10.3433
  [OK ] W INSTRUMENT: the board is configured at all (16.4253 / 11.0800)
  [OK ] W INSTRUMENT (blind): a board configured at a DIFFERENT cruise reads different
  [RED] W INSTRUMENT: this is the board HubTransport configured, to the fourth decimal
```

**Exactement UN rouge, celui attendu** ; les deux autres assertions restent
vertes, ce qui prouve que la passe teste le bon axe. Et la référence
neutralisée imprime **17,2166 / 10,3433** — les chiffres exacts du brief,
c'est-à-dire le défaut reproduit à la demande. Fichier restauré et vérifié
**byte-identique** (`cmp`).

## Section 4 — TABLE CROISÉE, DEUX ARBRES

Référence : `origin/staging` `0ecc4a4` (arbre `ede0409`), **154 `.scn`**
comptés avant toute comparaison (le chiffre de CH69). Import `rc=0`, zéro
ligne d'erreur. Godot 4.3-stable, archive vérifiée contre son
`Content-Length` (50 276 070 octets, exact).

| sonde | driver | référence `0ecc4a4` | branche CH70 | écart |
|---|---|---|---|---|
| `SkateInertiaProbe` | headless | 103 / 0 | **103 / 0** | identique |
| `SkateTraverseProbe` | headless | 37 / 0 | **37 / 0** | identique |
| `SkateAirProbe` | headless | 40 / 0 | **40 / 0** | identique |
| `SkateTrickProbe` | headless | 54 / 0 | **54 / 0** | identique |
| `SkatePhysicsProbe` | headless | 161 / 0 | **161 / 0** | identique |
| `SkateDriveProbe` | xvfb | 29 / 0 | **29 / 0** | identique |
| `SkateFeelProbe` | xvfb | **120 OK / 1 RED** | **123 OK / 0 RED** | ⚠️ **le rouge CH69 réparé** ; 121 assertions → 123 (une remplacée par trois : « configuré du tout », le blind check, l'égalité) |

Aucun nombre de jeu ne bouge : la croisière est revenue à 10,0 et le seul
fichier de jeu touché ne l'est qu'en commentaires.

## Section 5 — CE QUE CE LOT NE PEUT PAS SIGNER

Qu'une croisière quelconque soit la bonne. `CLAUDE.md` CH62 est explicite :
un banc headless ne voit ni une sensation, ni un plaisir. Ce que le banc
signe ici est **arithmétique** — qu'à 6,5 la fenêtre vaut 0,000 s contre
0,762 exigées, et qu'aucune valeur sous 10,0 ne la tient. Le fait que 10,0
« aille trop vite » sur device reste **vrai et non traité** : ce lot dit
seulement que la réponse n'est pas dans cette constante.
