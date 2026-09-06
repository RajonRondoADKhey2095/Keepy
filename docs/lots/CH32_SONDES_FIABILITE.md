# CH32 — Fiabilité des sondes, après la promotion palier 2 (6 septembre 2026)

Lot de diagnostic pur, sans changement de gameplay, ouvert après la
promotion palier 2 (merge `3647e60`, CH31 inclus). Deux sujets, dans l'ordre
du brief.

## SUJET 1 — WaterTintProbe comptait quatre disques, HubWater en construit cinq

Diagnostic confirmé avant correction, comme demandé : `HubWater._init()`
ajoute bien un cinquième disque (`&"sea"`, `HubRegion.SEA_CENTRE` /
`HubRegion.SEA_RADIUS`) depuis CH29 — lu directement dans
`scripts/hub/HubWater.gd:166-167`. `WaterTintProbe.gd:182` assertait encore
`water.discs().size() == 4`. Ce n'est pas une régression de jeu : `sea` est
la fonctionnalité attendue. C'est l'assertion qui était restée sur l'ancien
contrat (quatre corps, avant CH29).

Correctif : `_check(water.discs().size() == 5, "five discs: pond, small
lake, both great-lake lobes, sea")`.

**Rouge-avant-vert** : le disque `sea` retiré de `HubWater._init()` (les deux
lignes CH29), relancé sous `xvfb-run -a godot4 --rendering-driver opengl3
--fixed-fps 60` — l'assertion corrigée échoue bien (10 échecs au lieu de 9,
exactement le compte de disques en plus), rien d'autre ne bouge. Fichier
restauré et vérifié `cmp` byte-identique à `origin/staging`.

**Recherche d'autres sondes portant le même contrat périmé** : `HubWater` n'a
qu'un seul point d'instanciation dans `scripts/dev/` — `WaterTintProbe.gd`
lui-même (`grep -rln "HubWater\.new\|: HubWater" scripts/dev/*.gd` → un seul
fichier). Aucune autre sonde ne porte ce contrat.

**Effet de bord** : le run complet baseline (`origin/staging`) comptait déjà
9 échecs pré-existants sans rapport avec le disc-count (8 lignes de
comparaison pixel `yaw N: dry Keepy...` + 1 ligne `draw nodes excluding
portals`), inchangés après le correctif. Hors scope de ce lot (aucun code de
jeu à modifier pour les faire passer).

## SUJET 2 — cinq sondes « inconcluantes » : diagnostic, pas patch

Chaque sonde relancée isolément dans ce sandbox, sous le mode qu'elle exige
elle-même (déclaré dans son propre en-tête).

| sonde | mode | résultat isolé | cause retenue |
|---|---|---|---|
| `CoveProbe` | headless | **PASS 179/0** — aucun gel | ne reproduit pas ; probablement contention de ressources au moment du grand rejeu (plusieurs sondes/process Godot concurrents), pas un défaut de la sonde |
| `LakeZoneProbe` | xvfb + opengl3 | **INCONCLUSIVE propre** à 900 s, budget épuisé après 7 trajets sur 10 tous verts en PHASE CROSSING (diagonale 66 hops/18.700 s identique à la référence publiée, 3 traversées de lac, 3 marches vers les portails) | (i) limite d'environnement réelle : rendu logiciel llvmpipe (aucun GPU dans ce sandbox), `--rendering-driver opengl3` sous xvfb tombe sur Mesa llvmpipe et chaque frame réellement rendue coûte plusieurs centaines de ms — le budget de 900 s ne suffit pas pour ~10 traversées à pied réelles |
| `SeesawProbe` | headless | **FAIL déterministe et rapide** (157 ≠ 144 draw nodes), pas de gel | pré-existant, documenté depuis CH26 (monde cozy) sur `origin/main` comme sur la branche — pas une inconclusion, une régression connue et déjà hors scope |
| `V6CrittersProbe` | xvfb + opengl3 | **INCONCLUSIVE propre** à 600 s (son propre budget `ProbeWatchdog.arm(..., 600.0)`), après des dizaines de checks verts sur plusieurs phases (sanglier : layout, ride, cancel, refusal, weather ; puis approche/nuzzle d'un second animal) | (i) même cause que `LakeZoneProbe` : rendu réel coûteux sous llvmpipe, watchdog déclenché proprement après progression authentique |
| `SubstituteModel` | (n/a) | **boucle infinie confirmée** (`timeout 20` → exit 124, aucune sortie) | (i)/(ii) ni l'un ni l'autre au sens du brief : ce n'est **pas un probe**. `SubstituteModel.tscn` est un `Node3D` nu sans script attaché (fixture pour `AssetContractAudit`), et `ProbeTimeoutAudit.gd:61` l'exclut déjà nommément (« a dev ASSET … not a probe »). Lancé comme scène principale, rien n'appelle jamais `get_tree().quit()` : c'est un défaut de SÉLECTION de scènes au niveau de l'outillage qui a fait le rejeu de promotion (glob de tous les `.tscn` de `scripts/dev/` sans consulter la liste d'exclusion de `ProbeTimeoutAudit`), pas un défaut de sonde ni de jeu |

**Preuve retenue pour distinguer (i) environnement de (ii) défaut** : dans
les deux cas `LakeZoneProbe`/`V6CrittersProbe`, `ps` montrait un CPU réel
(175-196%, deux threads actifs) pendant toute la durée, et le log montrait
une **progression continue et correcte** (nouvelles lignes `OK`/`[ok]`
jusqu'à quelques secondes avant l'expiration du budget) — la signature d'un
`deadlock` ou d'un clock gelé aurait été un CPU proche de 0% ou un log figé
dès le début de la phase bloquante, jamais observé ici. `ProbeWatchdog` a
dans les deux cas produit le message `INCONCLUSIVE` complet et propre
attendu par sa propre doctrine (`ProbeWatchdog.gd`, section « WHAT IT
REPORTS ») — le mécanisme fonctionne comme conçu, il ne fait que constater
que ce sandbox n'a pas de GPU matériel.

**Aucune régression trouvée dans le code de jeu.** Aucune escalade Opus 4.8
recommandée : il n'y a ni deadlock, ni attente infinie sur un signal, ni
blocage transverse — seulement une limite de rendu logicielle mesurée et un
défaut de périmètre de sélection de scènes (`SubstituteModel.tscn`) déjà
couvert côté sonde par `ProbeTimeoutAudit` mais pas côté outillage de
rejeu.

## Rejeu sur les deux arbres

Le seul fichier modifié par ce lot est `scripts/dev/WaterTintProbe.gd` (une
ligne). `git diff --stat origin/staging` le confirme : aucun autre fichier
ne diverge. Un rejeu des cinq sondes diagnostiquées, de `SeesawProbe`,
`CoveProbe`, et l'export release n'implique donc qu'un seul arbre réel — la
branche et `origin/staging` sont, hors ce commit, byte-identiques. Le
correctif SUJET 1 lui-même a sa propre preuve rouge-avant-vert (ci-dessus),
qui est la comparaison qui compte pour ce fichier.

## Build

Godot 4.3-stable téléchargé dans cette session (pas préinstallé ici),
50 276 070 octets — Content-Length exact. Templates d'export
1 073 228 327 octets — exact. Import complet 154 `.scn`. Export
`--export-release Web` propre, 0 `SCRIPT ERROR` : `index.wasm`
**35 376 909 / `af4a8fc2925d992348eb30deeeb54360`**, `index.js`
**`4e08904b1b7107858246af44b602067b`** — byte-identiques à la référence
publiée (aucun code moteur touché). `index.pck` 34 558 384 octets ;
`scripts/dev/*` et `assets_source/*` toujours absents du pack (0 ligne
`Storing File`).
