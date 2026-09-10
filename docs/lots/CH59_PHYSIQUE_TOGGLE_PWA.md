# CH59 — l'interrupteur physique doit être atteignable depuis la PWA staging

## Section 1 — le bouton, pas un lot 2

**Le problème mesuré, pas supposé** : CH57 a livré `DevTools.physics_enabled()`
derrière `?keepyphys=1`, un jeton d'URL. Mathieu travaille depuis une PWA
**installée** sur son téléphone : pas de barre d'adresse, donc ce jeton était
**structurellement inatteignable** pour lui. La physique CH57/CH58 n'avait
jamais pu être jugée sur le device réel.

**Précédent suivi** : l'overlay dev avait le même défaut avec `?keepydev=1`,
fermé par la règle 4 de `DevTools.enabled()` (défaut ON sur l'hôte
`keepy-staging.vercel.app`, lu par hostname). `keepyphys` est un second jeton
**sous** `enabled()` — donc pas éligible au même mécanisme de hostname sans
casser l'A/B (une PWA sur staging démarrerait alors physique ON par défaut,
justement ce que le brief interdit). La solution retenue est différente et
plus proche du problème réel : un **bouton dans le panneau dev existant**,
à côté de `Perf (dev)` et `Sauvegarde (dev)`, même style, même gate
`DevTools.enabled()`.

**`_setup_physics_button()`** (HubWorld.gd) pose visibilité et libellé par
défaut (`"Physique (dev) : ON"` / `"OFF"` selon `DevTools.physics_enabled()`,
donc OFF au chargement sur staging comme partout — l'A/B reste un geste
délibéré). **`_on_physics_toggled()`** flippe `DevTools.set_physics_override()`
puis appelle `get_tree().change_scene_to_file("res://scenes/HubWorld.tscn")`,
la convention de re-entrée dans le hub déjà utilisée par tous les retours de
sous-jeu (Battle, Quizz, Chased, la cabine).

## Section 2 — pourquoi un rechargement de SCÈNE, jamais de flag vivant

Le collider du funbox et le corps physique de la planche sont construits
**une seule fois**, à la construction du nœud, dans `HubSkatepark._maybe_collide`
et `HubTransport._build_board` — un `StaticBody3D`/`CharacterBody3D` contre
un simple `MeshInstance3D` est un choix pris **à la construction**, pas une
propriété réassignable sur un nœud vivant. Le brief l'interdit explicitement
("pas de lot 2, pas de nouveau collider") : ce lot est le chemin d'activation
et rien d'autre.

`change_scene_to_file` reconstruit donc tout le hub avec la réponse
fraîchement inversée — exactement ce qu'un A/B physique demande. **Ce n'est
PAS un rechargement navigateur** : aucune navigation, aucun aller-retour
réseau, aucune barre d'adresse impliquée, donc ça marche depuis une PWA
installée. **Ce que ça coûte, dit plutôt que caché** : Keepy revient au spawn
authored du plateau (comme tout autre retour dans le hub), il ne reste pas là
où il se tenait. `DevTools._physics_cache` est un `static var` de classe et
survit au changement de scène (les classes de script restent chargées à
travers `change_scene_to_file`), donc le bouton n'a besoin d'aucune
persistance côté navigateur (pas de `localStorage`) pour tenir jusqu'au
prochain vrai rechargement de page, où `physics_enabled()` retombe sur ses
règles normales (URL, puis défaut OFF).

## Section 3 — rouge avant vert

Sonde jetable `_tmp_PhysButtonCheck` (headless, off-web) : instancie
`HubWorld.tscn`, lit `PhysicsButton` (résolution du nœud, visibilité,
libellé par défaut), inverse l'override et rappelle `_setup_physics_button()`
pour vérifier le libellé refresh — sans passer par le `change_scene_to_file`
(déjà couvert par le patron du dépôt ailleurs).

Vert d'abord : **6 ok, 0 bad**. Neutralisation (ternaire de libellé inversé
dans `_setup_physics_button`) : **4 ok, 2 bad**, exactement les deux
assertions de libellé — ni plus ni moins. Restauré, revert confirmé par
`git diff --stat` (que des insertions), sonde supprimée avant commit.

## Section 4 — table croisée sur les sondes physique

Godot 4.3 absent du sandbox : binaire téléchargé, taille vérifiée contre le
`Content-Length` (50 276 070 octets, conforme à `CLAUDE.md`) avant
extraction. Import complet relancé après nettoyage (`154` `.scn`, comme la
baseline CH58). Worktree `origin/staging` (`1815383`) importé séparément
avec le même cache `.godot` copié, pour une comparaison à coût nul.

| sonde | driver | branche | baseline (`origin/staging`) |
|---|---|---|---|
| `SkatePhysicsProbe` | headless, `--fixed-fps 60` | ALL GREEN — 0 red | ALL GREEN — 0 red |
| `SkateDismountProbe` | `xvfb-run --rendering-driver opengl3` | ALL GREEN — 0 red | ALL GREEN — 0 red |
| `SkateDriveProbe` | `xvfb-run --rendering-driver opengl3` | ALL GREEN — 0 red | ALL GREEN — 0 red |

Les trois sorties sont **byte-identiques** entre les deux arbres (modulo le
bruit documenté du driver dummy à la sortie) : ce lot ne touche aucune ligne
du chemin physique lui-même, seulement son activation.

## Section 5 — CI et déploiement, lus sur le job et sur le service

Run `34347002383` (`web-build.yml`, push sur `staging`, commit `7293f92`,
merge `--no-ff` de `a614c45`) : `status: completed`, `conclusion: success`,
lu via `get_workflow_run` (`completed_at`/`conclusion`, pas le badge).

Vérifié **sur le service**, pas sur le seul log CI : `CACHE_VERSION` de
`index.service.worker.js` lu à `1788954249|5237857` → epoch **11:44:09 UTC**,
à l'intérieur de la fenêtre du run (`11:42:49`–`11:44:37 UTC`) ; lecture
`x-vercel-cache: MISS`, `age: 0` — fraîche, pas un bord figé.
`GODOT_CONFIG.fileSizes.index.wasm = 35376909` (lu dans `index.html` servi,
MISS/age 0) — identique au chiffre publié par `CLAUDE.md` pour tout lot qui
ne touche pas le moteur, ce qui est le cas ici (GDScript + une scène 2D
seulement). `index.wasm` intégral non re-téléchargé pour un md5 (35 Mo, hors
de la capacité du canal de fetch MCP disponible ici) — la taille exacte plus
`CACHE_VERSION` dans la fenêtre du run est le degré de preuve obtenu.
