# Sondes — budget temps, watchdog, ProbeTimeoutAudit

> Extrait de `CLAUDE.md` par le LOT H (2 septembre 2026), **verbatim** : aucune ligne réécrite, résumée ni supprimée.
> 1 section(s), 103 lignes d'origine.
> Doctrine permanente : voir `CLAUDE.md`. Index des chantiers : `docs/lots/INDEX.md`.

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

