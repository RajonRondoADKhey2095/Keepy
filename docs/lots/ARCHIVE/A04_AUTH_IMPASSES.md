# ARCHIVE — Google Sign-In, les deux impasses abandonnées

> Extrait de `CLAUDE.md` par le LOT H (2 septembre 2026), **verbatim** : aucune ligne réécrite, résumée ni supprimée.
> 2 section(s), 282 lignes d'origine.
> Doctrine permanente : voir `CLAUDE.md`. Index des chantiers : `docs/lots/INDEX.md`.

## GOOGLE SIGN-IN : `signInWithRedirect` → `signInWithPopup` — le redirect ne revenait JAMAIS sur Safari iOS (17 août 2026)

Branche `claude/google-signin-popup-migration-hdslwn`, partie de `staging`
(`e844824`). **Première section auth de ce fichier** : le lot qui a posé la
porte Google Sign-In (`aa66ab0`, le matin même) n'a documenté son
raisonnement que dans son message de commit — ce paragraphe régularise, il
ne remplace rien.

⚠️ **Ce n'est PAS un réglage, c'est un changement de FLOW** : le redirect
ne pouvait structurellement pas fonctionner sur ce déploiement, et aucune
valeur de paramètre ne l'aurait sauvé.

### Le défaut, confirmé sur device (screenshots à l'appui, ne pas re-questionner)

Chaîne observée sur `keepy-staging.vercel.app`, Safari iOS, wifi actif :
bouton tapé → page blanche bloquée sur `keepy-8df91.firebaseapp.com`,
chargement infini → retour sur l'app → « Connexion en cours... » → au bout
de **12 s** (`BRIDGE_TIMEOUT_S` d'`Auth.gd`) → « Le module de connexion ne
répond pas ». Le round-trip ne se termine jamais.

**Cause : storage partitioning ITP.** Le flow redirect gare son état en
attente sur l'**authDomain** (`keepy-8df91.firebaseapp.com`), qui n'est PAS
l'origine de l'app (`*.vercel.app`). Safari donne à cette origine une
partition de stockage différente quand elle est chargée en tierce partie :
l'état écrit à l'aller n'est pas celui relu au retour. Deux origines
distinctes qui ne partagent pas l'état de redirection en attente — le
`getRedirectResult()` du retour ne trouve donc rien, pour toujours.

**Pourquoi le popup n'a pas ce problème** : il n'a AUCUN état cross-origin
à faire survivre à une navigation. Le popup reposte son résultat vers
**cette** fenêtre, dans **la même** session JS, et la promesse se résout sur
place. C'est aussi pourquoi tout le mécanisme `sessionStorage` de détection
de redirect perdu (`PENDING_KEY` / `readPending()` / `writePending()`) est
**retiré et pas neutralisé** : il n'avait plus rien à détecter.

### `Cross-Origin-Opener-Policy: same-origin` → `same-origin-allow-popups`

`vercel.json`, règle site-wide `/(.*)`. **Indispensable** : sous
`same-origin`, le navigateur coupe le lien `window.opener` entre le popup et
la fenêtre principale, donc le `postMessage` par lequel le SDK Firebase
rend son résultat n'arrive jamais — le popup s'ouvrirait et ne servirait à
rien. `Cross-Origin-Embedder-Policy: require-corp` et la règle `.wasm` sont
**intouchés**.

⚠️ **La formulation courante « `same-origin-allow-popups` coexiste avec
`crossOriginIsolated` » est FAUSSE, et c'est vérifié plutôt qu'accepté :**
l'isolation cross-origin exige COOP **`same-origin`** + COEP
`require-corp`. Passer à `same-origin-allow-popups` fait donc tomber
`crossOriginIsolated` à `false`, et avec lui `SharedArrayBuffer`.

**C'est sans conséquence ICI, et c'est mesuré sur le build réel, pas
supposé** : l'export web de ce projet est un build **nothreads** —
`GODOT_THREADS_ENABLED = false` et `"ensureCrossOriginIsolationHeaders":
false` lus dans l'`index.html` généré par l'export de ce lot (cohérent avec
les templates `web_nothreads_{debug,release}.zip` déjà documentés plus
haut). Aucun `SharedArrayBuffer` n'est demandé, donc l'isolation
cross-origin ne servait rien à ce jeu. **Corollaire pour plus tard : le
jour où quelqu'un active le support threads dans le preset Web, ce COOP
devient bloquant** — les deux réglages sont incompatibles et il faudra
trancher entre threads et popup OAuth.

### Codes d'erreur : trois nouveaux, les anciens CONSERVÉS

Le contrat de robustesse existant est étendu, jamais cassé : aucun chemin ne
crashe, chaque chemin finit en signal, chaque code a un message français
associé dans `LoginScreen._message_for()`.

| code | origine | traitement écran |
|---|---|---|
| `popup-blocked` | `auth/popup-blocked` | « Ton navigateur bloque les popups… » |
| `popup-cancelled` | `auth/popup-closed-by-user`, `auth/cancelled-popup-request` | **neutre** : « Connecte-toi pour jouer. », sans détail |
| `popup-start-failed` | tout autre code | « La connexion Google a échoué. » |

⚠️ **`popup-cancelled` voyage par `auth_error` alors que ce n'est PAS une
erreur, et ce n'est pas un compromis paresseux — c'est obligatoire :**
`_on_sign_in_pressed()` **désactive** le bouton, et `auth_error` est le seul
canal qui le réactive. Publier « silencieusement » (l'autre option offerte)
laisserait un bouton mort sous un « Connexion à Google... » figé, pour un
joueur qui a simplement fermé le popup. La distinction failure/neutre est
donc portée par `LoginScreen.NEUTRAL_CODES`, qui rend le message
d'invitation **sans le détail entre parenthèses** — `auth/popup-closed-by-
user` sous une ligne disant que tout va bien se lit comme une contradiction.

⚠️ **Le `publish({error: '', detail: ''})` avant chaque tentative est
PORTEUR, pas de la coquetterie** : `Auth._apply_snapshot()` ne ré-émet
`auth_error` que si le code **change**. Sans ce reset, deux popups annulés
d'affilée produiraient deux fois le même code, le second serait avalé, et le
bouton resterait désactivé pour de bon.

**Les codes `redirect-lost` / `redirect-failed` / `redirect-start-failed`
sont GARDÉS dans le `match`** bien qu'aucun chemin du shell actuel ne puisse
plus les émettre. Un joueur dont le navigateur ou le service worker sert
encore un build en cache de l'ancienne coquille est exactement celui qui a
le plus besoin d'un message lisible ; les retirer lui servirait le fallback
générique « Connexion impossible. ». Trois lignes, contre la leçon déjà
payée au lot gzip du classement.

### Régression de flash évitée — un effet de bord du `getRedirectResult()` supprimé

`await getRedirectResult(auth)` attendait aussi, **par effet de bord**,
l'initialisation du SDK : `auth.currentUser` était donc déjà peuplé quand
`ready` basculait. Le retirer sans rien mettre à la place aurait publié
`signed_out` + `ready` à un joueur dont la session persistée était encore en
cours de restauration — donc **un flash de l'écran de login** à chaque
retour, exactement ce que les commentaires du shell interdisent. Remplacé
par une promesse résolue au **premier** `onAuthStateChanged` (que le SDK tire
toujours une fois, connecté ou non), attendue avant de basculer `ready`. Si
ce callback n'arrive jamais, rien ne rapporte et le `BRIDGE_TIMEOUT_S` de 12 s
d'`Auth.gd` le remonte — c'est précisément le rôle de ce garde-fou.

`onAuthStateChanged` **reste la source de vérité unique** pour `uid`/`idToken` :
la résolution du popup ne publie rien en cas de succès, pour ne pas créer un
second écrivain sur le même fait.

### ⚠️ RISQUE CONNU, NON CORRIGÉ ICI — Safari et l'activation utilisateur

**Ce point ne peut être tranché que par le test device qui suit.** Safari
est le navigateur le plus strict sur l'ouverture d'un popup : historiquement
il exigeait un `window.open` **dans la même pile d'appel** que le geste
utilisateur réel.

**La chaîne de ce jeu n'est PAS synchrone dans ce sens, et c'est vérifié sur
le build exporté, pas supposé** : les listeners DOM de Godot sont
`touchend`/`mouseup`, `project.godot` ne pose aucun
`input_devices/buffering/agile_event_flushing` (donc défaut = événements
bufferisés, vidés une fois par frame), et la boucle moteur tourne sous
`requestAnimationFrame`. Le signal `pressed` du bouton — donc
`Auth.sign_in()`, donc `JavaScriptBridge.eval()`, donc le `window.open` du
SDK — s'exécute dans une **tâche rAF distincte** du handler DOM d'origine.

Le popup dépend donc de la **transient user activation** (fenêtre temporelle
de ~5 s après un geste, honorée par Chrome/Firefox) et non d'une même pile
d'appel. **Ce qui est incertain est le comportement réel de Safari iOS dans
cette fenêtre** — pas la mécanique côté Godot, qui est établie ci-dessus.

**Aucun contournement n'a été tenté**, délibérément : intercaler un
`window.open('about:blank')` posé plus tôt puis re-ciblé, ou déplacer le
déclenchement dans un listener DOM en amont du moteur, sont deux
changements structurels qu'il serait absurde d'engager avant de savoir si le
défaut existe. Si Safari refuse, il le dira **proprement** : c'est
exactement le chemin `auth/popup-blocked` → `popup-blocked` → message
français explicite, et non un nouveau blocage silencieux de 12 s.

### Validation

Import headless **exit 0**, export Web release **exit 0**, boot de
`LoginScreen.tscn` (`--quit-after 3`) **exit 0** — aucune erreur de parse.
`index.wasm` **35 376 909 octets**, identique au fingerprint consigné pour
tout lot ne touchant pas le code moteur. `index.html` généré vérifié :
`signInWithPopup` présent **en code** (les seules occurrences restantes de
`signInWithRedirect` et `getRedirectResult` sont dans des commentaires),
**0** occurrence de `PENDING_KEY` / `readPending` / `writePending` /
`redirect-lost` / `redirect-start-failed`, et `viewport-fit=cover` +
`#101d0b` toujours en place (le fix safe-area du même jour n'est pas abîmé).

**Sondes : 6 rejouées, TOUTES byte-identiques sur les deux flux** contre
`origin/staging` en worktree séparé, même graine 20260806, `--fixed-fps 60` —
`ProbeTimeoutAudit` (**33 sondes armées**), `AssetContractAudit` (12/12
visuels, **0/10 colliders déplacés**), `DeathModelAudit`,
`ChargerShapeProbe`, `ComboAudit`, `ShrinkAudit`. C'est le résultat attendu
et il est **mesuré, pas argumenté** : `Auth.gd` est un autoload, donc il
tourne dans CHAQUE sonde — mais ce lot n'y change que des commentaires, et
`LoginScreen.gd` n'est chargé par aucune sonde (elles lancent leur propre
`.tscn` et ne passent jamais par `run/main_scene`). L'identité au bit près
le dit plus fort qu'un simple verdict identique.

### Reste ouvert — jugement device, seul juge

Le test sur iPhone Safari (onglet normal **et** PWA installée) doit répondre
à trois questions, dans cet ordre : (a) le popup s'ouvre-t-il **du tout**
— c'est l'incertitude d'activation utilisateur ci-dessus ; (b) si oui, la
connexion aboutit-elle et le jeu se lance-t-il ; (c) fermer le popup à la
main laisse-t-il bien un bouton réactivé et le message d'invitation, sans
message d'échec rouge. Aucune sonde de ce dépôt ne rend de pixels iOS réels
— c'est structurellement hors de portée d'un test headless Godot.

## GOOGLE SIGN-IN : INSTRUMENTATION DE DIAGNOSTIC — aucun fix, objectif
## localiser le prochain `bridge-timeout` sans devtools (17 août 2026)

Branche `claude/google-signin-timeout-debug-5vg5pq`, redémarrée sur
`origin/staging` (`7582b70`) — la branche n'avait aucun commit propre,
elle pointait encore sur un vieux commit `main` antérieur au gate
Google Sign-In (aucun `Auth.gd` sur cet arbre). **Diagnostic pur, comme
demandé : aucune ligne de logique d'auth n'est changée.** Le flow
timeout (bridge-timeout à 12 s) de façon non reproductible, sur Safari
iOS et Chrome Android, sans accès devtools pour Mathieu (iPhone-only) —
objectif de ce lot : rendre chaque étape du chargement visible à l'écran,
pour que le prochain timeout dise EXACTEMENT où ça a coincé.

**Six checkpoints ajoutés dans `web/html_shell.html`**, chacun publié via
le canal existant (`publish()` → `window.keepyAuthNotify` →
`Auth._on_js_auth_event`), jamais un nouveau canal :
`sdk-import-started` → `sdk-import-done` → `app-initialized` →
`auth-obtained` → `listener-registered` → `first-auth-state-received`
(ce dernier au tout premier `onAuthStateChanged`, même `user=null` —
gardé par une fermeture `firstAuthStateSeen`, pas par un champ sur
`window.keepyAuth`, pour ne pas alourdir chaque snapshot JSON d'un
booléen qu'Auth.gd n'a pas besoin de lire). Chaque checkpoint publie
`{ stage, stageAt }` (`Date.now()`) ; `window.keepyAuth.bootAt` est posé
UNE fois, à la toute première ligne du fichier (avant même la
déclaration de l'objet), pour qu'`Auth.gd` calcule un écart en secondes
sans posséder sa propre horloge. Chaque checkpoint passe aussi par
`console.log('[keepyAuth] stage=... elapsedMs=...')`, pour le jour où
Mathieu peut brancher un Mac — mais c'est le canal secondaire : le canal
écran (ci-dessous) est celui qui compte pour son setup réel.

**`scripts/autoload/Auth.gd`** : nouveau signal diagnostic-only
`auth_debug_stage_changed(stage, elapsed_s)`, émis depuis
`_apply_snapshot()` à chaque nouveau `stage` reçu (comparaison sur
`stage` + `stageAt`, pas seulement `stage`, pour ne pas rater un second
passage sur le même checkpoint) ; deux nouveaux getters
`get_debug_stage()` / `get_debug_stage_elapsed_s()`. **Aucune branche
existante n'est touchée** — `_debug_stage`/`_debug_stage_at`/
`_debug_boot_at` sont des variables neuves, lues nulle part ailleurs
dans ce fichier, donc rien dans le comportement de `sign_in()`, du
timeout 12 s ou de `_apply_snapshot()` pour `status`/`error`/`uid` n'a
changé de chemin.

**`scenes/LoginScreen.tscn` / `scripts/ui/LoginScreen.gd`** : un nouveau
`Label` discret (`DebugStageLabel`, taille 16, `modulate` alpha 0.55)
sous `OfflineButton`, dernier enfant du même `VBoxContainer` que
`StatusLabel`/`SignInButton` — aucun nœud existant déplacé ni retouché.
Affiche `"etape: <stage> (<elapsed>s)"`, mis à jour par
`_on_auth_debug_stage_changed()` sur le nouveau signal, avec le même
patron défensif que `_refresh_from_auth()` (`_refresh_debug_stage_label()`
lit l'état déjà connu au cas où un checkpoint serait arrivé avant que
cette scène ne connecte le signal). Si le bridge se bloque à nouveau,
ce label reste figé sur le dernier stage atteint — exactement le
symptôme que Mathieu doit pouvoir lire et rapporter.

### Bug réel repéré en lisant le code, PAS corrigé — pour discussion

Consigne de session explicite : ne pas patcher à l'aveugle une deuxième
fois. `LoginScreen.gd._refresh_from_auth()` affiche
`"Connexion en cours..."` tant que `Auth.is_ready()` est faux, mais rien
n'y montre le champ `status` intermédiaire que le shell publie AVANT
`ready` (`'redirecting'` au clic sur connexion, ou le `status` restauré
au retour d'un redirect). Un joueur dont le retour de Google prend
plusieurs secondes voit un texte figé identique du premier instant au
`bridge-timeout` (ou au succès), avec le nouveau `DebugStageLabel` comme
seule source de mouvement à l'écran. Cette instrumentation le couvre déjà
partiellement (les 6 checkpoints tournent bien avant le retour de
Google), mais le `status` lui-même n'est pas un des 6 checkpoints
demandés — signalé, pas traité ici.

### Validation

Éditeur + templates Godot 4.3-stable installés dans ce sandbox pour ce
lot (releases GitHub officielles, réseau disponible). Les deux blocs
`<script>` de `web/html_shell.html` extraits et vérifiés avec
`node --check` (syntaxe seule, aucun DOM/Firebase réel en headless) :
**les deux OK**. Import headless **exit 0**, export Web release **exit
0** — `index.wasm` **35 376 909 octets**, identique au fingerprint déjà
consigné pour tout lot qui ne touche pas le code moteur (cohérent : deux
fichiers `.gd`, un `.tscn`, un `.html` d'export shell, aucun changement
à `project.godot` ni aux autoloads enregistrés). Vérifié dans
`build/web/index.html` exporté : les six identifiants de checkpoint et
`bootAt` sont bien présents dans le bundle livré, pas seulement dans la
source.

`res://scenes/LoginScreen.tscn` bootée seule en headless
(`--quit-after 2`) : **exit 0**, aucune erreur de parse ni de nœud
manquant (branche hors-web, celle que tout probe emprunte). `Auth.gd`
tourne dans chaque sonde en tant qu'autoload, mais sa `_ready()` sort
avant toute ligne utile dès que `OS.has_feature("web")` est faux
(systématique sous `--headless`) — les nouvelles variables/signal ne
sont donc jamais exercés par un probe, par construction, pas par chance.
`ProbeTimeoutAudit` (**33 sondes, toutes armées**, chiffre inchangé),
`AssetContractAudit` (**12/12 visuels, 0/10 colliders déplacés**),
`DeathModelAudit` (CHARGER seul fatal, capture au 2ᵉ contact pour les 5
autres types — inchangé) — **toutes exit 0**.

### Reste ouvert

Aucune sonde de ce dépôt ne peut déclencher un `bridge-timeout` réel ni
lire un écran iPhone — cette instrumentation attend le prochain timeout
en conditions réelles pour prouver qu'elle localise effectivement le
point de blocage. Le bug `status` intermédiaire non affiché (ci-dessus)
reste ouvert, pour discussion avec Mathieu avant tout patch. Merge sur
`staging` : palier 1, automatique (build/export/sondes verts) ; `main`
reste gaté par Mathieu, sans changement à cette règle.

