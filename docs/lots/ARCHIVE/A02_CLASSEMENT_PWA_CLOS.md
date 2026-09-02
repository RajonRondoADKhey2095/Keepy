# ARCHIVE — classement PWA, chantier clos

> Extrait de `CLAUDE.md` par le LOT H (2 septembre 2026), **verbatim** : aucune ligne réécrite, résumée ni supprimée.
> 2 section(s), 229 lignes d'origine.
> Doctrine permanente : voir `CLAUDE.md`. Index des chantiers : `docs/lots/INDEX.md`.

## CLASSEMENT PWA : RÉSOLU, validé device des deux côtés (PWA + onglet Chrome) — 16 août 2026

⚠️ **CLÔTURE.** Le fix `accept_gzip = false` documenté ci-dessous (section
« CAUSE RÉELLE TROUVÉE PAR LE DIAGNOSTIC ») est confirmé sur device : le
classement synchronise à nouveau, en PWA installée ET en onglet Chrome
normal. Le diagnostic temporaire (`diag` sur `submit_finished`/
`top_scores_fetched`, affiché sous `SyncStatusLabel`) est **retiré** —
`Leaderboard.gd` et `GameOverScreen.gd` sont revenus, octet pour octet,
à leur état d'avant l'enquête (`a5211d3`), le fix `accept_gzip` étant la
seule différence qui subsiste. `SyncStatusLabel` réaffiche son texte fixe
autorisé, « Score non synchronisé (hors ligne ?) », sans plus jamais lui
concaténer `result=<...> code=<...>`. Branche
`claude/accept-gzip-valide-device-sr1tko`, partie de `staging` (`016ada3`).
Merge `staging` → `main` autorisé par Mathieu à la suite de cette
validation — voir la section « CLASSEMENT PWA : merge en production »
plus bas pour les détails du merge et le fingerprint CI/prod.

## CLASSEMENT PWA : l'hypothèse service worker est INFIRMÉE par la source réellement déployée — diagnostic ajouté, PAS encore validé device (14-15 août 2026)

Branche `claude/pwa-leaderboard-sync-issue-rvejp5`, partie de `staging`
(`230b6e7`). Suite au lot clavier virtuel (`a5211d3`, même jour) : test
device confirme le clavier réparé, mais le classement échoue
systématiquement — « Classement indisponible » + « Score non synchronisé
(hors ligne ?) » — malgré un wifi actif, en PWA installée (icône écran
d'accueil) sur Android/staging. Facteur nouveau depuis le diagnostic clavier :
`progressive_web_app/enabled` est passé à `true` le 14 août (lot icône
d'application), donc un service worker Godot est désormais enregistré en PWA.
Hypothèse de départ à vérifier : ce SW intercepterait les `fetch()`
cross-origin vers `firestore.googleapis.com` et les dégraderait en réponses
opaques.

⚠️ **HYPOTHÈSE VÉRIFIÉE ET INFIRMÉE — pas sur le template, sur les octets
RÉELLEMENT servis par `keepy-staging.vercel.app`.** `index.service.worker.js`
a été récupéré tel que déployé (MCP Vercel `web_fetch_vercel_url` — seul
canal HTTP disponible depuis ce sandbox pour ce domaine : `curl` direct et un
Chromium Playwright local sont tous les deux bloqués en 403 par la politique
d'egress du sandbox, `keepy-staging.vercel.app` n'y étant pas autorisé).
Constaté : `ENSURE_CROSSORIGIN_ISOLATION_HEADERS = false`, exactement la
valeur posée par `export_presets.cfg`. Avec ce réglage, le handler `fetch` du
template Godot (comparé octet pour octet à la source réelle
`misc/dist/html/service-worker.js` du tag `4.3-stable`, celui utilisé par la
CI) n'appelle `event.respondWith()` QUE si `isNavigate` ou `isCachable` — et
`isCachable` ne peut STRUCTURELLEMENT jamais être vrai pour une requête
cross-origin comme celles de `Leaderboard.gd` : son premier terme (`local`,
le chemin résolu depuis le referrer) ne matche que les fichiers de
`CACHED_FILES`/`CACHABLE_FILES` (index.html/js/wasm/pck/...) ; son second
terme (`base === referrer && base.endsWith(CACHED_FILES[0])`) exige à la fois
que `base` se termine par `/` (1er conjonct) ET par la chaîne `"index.html"`
(2e conjonct, `CACHED_FILES[0]`) — CONTRADICTOIRE avec lui-même, donc jamais
vrai, quel que soit l'URL de démarrage réel (`/` ou `/index.html` via le
`start_url` du manifeste). **Conséquence : pour toute requête vers
`firestore.googleapis.com`, le SW n'appelle jamais `respondWith()` —
passthrough complet, exactement comme en l'absence de service worker.** Ce
n'est pas une lecture optimiste : c'est une propriété structurelle de la
fonction `isCachable`, vérifiée sur les octets exacts servis en prod, pas sur
une hypothèse de lecture du template.

**Côté serveur, tout répond correctement, testé EN DIRECT avec la clé et les
endpoints réels du jeu** (GET `/documents/scores`, POST `:runQuery` avec le
body exact de `fetch_top_scores()`, préflight OPTIONS + POST sur `:commit` —
aucune écriture réelle faite, seul le préflight a été exercé) : 200 partout,
CORS reflète correctement `https://keepy-staging.vercel.app`
(`access-control-allow-origin` + `access-control-allow-credentials: true`),
et les documents déjà présents dans `scores` confirment que la collection
reçoit déjà des écritures réelles. La clé API, les règles Firestore et le
CORS du projet `keepy-8df91` ne sont donc PAS la cause.

**Vercel pose `Cross-Origin-Embedder-Policy: require-corp` +
`Cross-Origin-Opener-Policy: same-origin` sur TOUTES les routes**
(`vercel.json`, indépendant du SW et de `ENSURE_CROSSORIGIN_ISOLATION_HEADERS`)
— vérifié inoffensif ici : COEP `require-corp` ne bloque que les réponses
OPAQUES (mode `no-cors`) ; une requête `fetch()` cross-origin en mode `cors`
(le défaut, celui qu'utilise forcément `HTTPRequest` pour pouvoir lire le
corps de la réponse) qui reçoit un `Access-Control-Allow-Origin` valide —
confirmé ci-dessus — n'est jamais considérée opaque et n'est donc jamais
bloquée par COEP.

**Ce que ça change pour la suite de l'enquête** : le test « PWA installée vs
onglet Chrome normal » envisagé à l'origine visait à isoler un mécanisme qui,
sur la base de cette analyse, n'a structurellement aucune prise sur ces
requêtes — le refaire tel quel n'apprendrait probablement rien de plus.
Candidats restants, NON tranchés, à privilégier au prochain test device :
(a) permission réseau Android PER-APP sur le WebAPK installé (certains OEM —
Samsung/Xiaomi notamment — restreignent par défaut les données mobile/wifi
d'une app tout juste installée, séparément de Chrome lui-même — la PWA n'a
qu'un jour d'existence au moment du test) ; (b) un service worker resté sur
un `CACHE_VERSION` antérieur au lot clavier/sync (le cycle de vie SW ne
prend le contrôle qu'après fermeture complète de tous les clients de
l'ancien SW — un simple retour au premier plan peut ne pas y suffire) ;
(c) une panne réseau/DNS ponctuelle du device au moment du test précis, sans
rapport avec la PWA. Rien ne permet de trancher entre ces trois depuis ce
sandbox (aucun accès à un device Android réel).

**Diagnostic AJOUTÉ pour trancher au prochain test, TEMPORAIRE, à retirer une
fois la cause confirmée** — `Leaderboard.gd` : les signaux
`submit_finished`/`top_scores_fetched` portent désormais un 3e paramètre
`diag` (`"result=<HTTPRequest.Result> code=<HTTP status>"`, vide en succès) ;
`GameOverScreen.gd` l'affiche en l'AJOUTANT au texte déjà autorisé de
`SyncStatusLabel` (jamais en l'écrasant — le texte de la `.tscn` reste la
source de vérité, capturé une fois dans `_sync_status_base_text`). Un
`result` non-nul avec `code=0` pointera vers (a)/(c) ci-dessus (la requête
n'a jamais atteint le serveur) ; un `result=0` avec un `code` HTTP réel
(4xx/5xx) pointera ailleurs (proxy réseau, restriction spécifique à la
requête plutôt qu'à la connectivité). Retrait prévu : arrêter d'appeler
`_update_sync_status_text()` (ou toujours poser
`sync_status_label.text = _sync_status_base_text`), sans toucher au noeud
`.tscn`.

**Build validé au même niveau que la CI, dans ce sandbox** — éditeur +
templates Godot 4.3-stable installés pour ce lot (releases GitHub
officielles, réseau disponible cette fois). Import + export Web headless
**exit 0**, `index.wasm` inchangé (aucun code moteur touché), les deux `.gd`
modifiés compilent (`Leaderboard.gdc`/`GameOverScreen.gdc` bien produits dans
le `.pck`) et le boot headless de `GameOverScreen.tscn`
(`--quit-after 2`) ne lève aucune erreur. **Aucun test sur device réel** —
ni Android, ni iPhone, accessibles depuis ce sandbox : c'est précisément ce
que ce diagnostic vise à rendre inutile au prochain passage humain.

**Rien poussé au-delà de la branche feature**
(`claude/pwa-leaderboard-sync-issue-rvejp5`), conformément à la consigne de
session : ni `staging` ni `main`. Reste ouvert : le test A/B PWA/onglet
demandé à l'origine n'a pas pu être fait (device réel requis, hors de portée
du sandbox) ; les candidats (a)/(b)/(c) ci-dessus ne sont pas départagés — le
diagnostic ajouté est fait pour ça, au prochain test device.

### ⚠️ CAUSE RÉELLE TROUVÉE PAR LE DIAGNOSTIC : `accept_gzip` — fix appliqué et VALIDÉ device (14-16 août 2026)

Branche `claude/leaderboard-gzip-fix-3s6bag`, partie de `staging` (`4296086`,
donc **posée sur le diagnostic ci-dessus**). Le diagnostic temporaire a
tranché en un test device : `result=8`
(`HTTPRequest.RESULT_BODY_DECOMPRESS_FAILED`), `code=200` — **sur les deux
surfaces testées** (PWA installée ET onglet Chrome normal), donc (a)/(b) sont
écartés d'un coup : ce n'est ni une restriction réseau per-app Android, ni un
service worker figé sur un ancien cache — les deux auraient dû produire une
signature différente entre PWA et onglet, or les deux donnent le même couple.

**Cause probable, documentée par plusieurs issues Godot spécifiques à
l'export Web (pas encore confirmée par un 3e round device — voir plus bas)** :
`HTTPRequest.accept_gzip` vaut `true` par défaut, ce qui déclenche une
tentative de décompression du corps de réponse. Sur l'export Web, fetch/XHR
livre déjà à JS des octets entièrement décodés — il n'y a jamais de payload
gzip brut à déballer — mais l'entête `Content-Encoding: gzip` de Firestore
reste visible côté Godot, d'où la tentative de décompression sur du JSON
déjà en clair, qui échoue net avec `code=200` (la réponse HTTP a bien
réussi, c'est le décodage applicatif qui la jette).

**Fix appliqué** : `_submit_request.accept_gzip = false` et
`_query_request.accept_gzip = false`, posés juste après la création des deux
`HTTPRequest` dans `Leaderboard._ready()`, avant `add_child`. Deux lignes,
aucun autre fichier touché. Le diagnostic temporaire (`diag` sur les
signaux, affichage sous `SyncStatusLabel`) **est conservé tel quel** — pas
retiré avant validation device de ce fix, conformément à la consigne de
session : s'il ne suffit pas, le prochain couple `result`/`code` doit
remonter sans qu'on ait à le réinstrumenter.

**Build/export validés dans ce sandbox, au même niveau que la CI** :
éditeur + templates Godot 4.3-stable téléchargés (releases GitHub
officielles). Import headless **exit 0**, export Web release **exit 0**
(`godot4 --headless --path . --export-release "Web" build/web/index.html`,
aucune erreur GDScript/parse), les six fichiers du build produits et
non vides (`index.wasm` 35 376 909 octets — inchangé, cohérent avec un
diff limité à 2 lignes de GDScript sans code moteur touché). **Aucun test
sur device réel** — c'est précisément ce qu'attend la consigne de session
avant tout merge vers `main`.

**Mergé sur `staging`** (commit `f475b3f`, palier 1, automatique — build et
export headless verts). **`main` INTOUCHÉ, aucune exception** : la consigne
de session est explicite — rien à merger sur `main` tant que Mathieu n'a
pas confirmé sur device (PWA installée + onglet Chrome, comme pour le
diagnostic) que le classement synchronise enfin. Si le couple `result`/
`code` change au prochain test (au lieu de disparaître), ce sera un nouveau
signal à traiter, pas une confirmation de cette hypothèse.

### VALIDÉ device, diagnostic retiré (16 août 2026)

Test device confirmé sur les deux surfaces (PWA installée + onglet Chrome
normal) : le classement se charge, une soumission de score aboutit, plus
aucune trace de « Classement indisponible » ni de `result=<...> code=<...>`
à l'écran. Le fix `accept_gzip = false` est la cause réelle, confirmée, pas
seulement probable.

Branche `claude/accept-gzip-valide-device-sr1tko`, partie de `staging`
(`016ada3`). Le diagnostic temporaire est retiré dans ce lot : le 3e
paramètre `diag` disparaît des signaux `submit_finished`/
`top_scores_fetched` de `Leaderboard.gd`, `GameOverScreen.gd` cesse
d'appeler `_update_sync_status_text()` (la fonction elle-même est retirée,
avec `_sync_status_base_text`/`_submit_diag`/`_final_fetch_diag`) et
`SyncStatusLabel` réaffiche uniquement son texte fixe autorisé sur le
`.tscn`. **Diffé contre `a5211d3`** (dernier commit avant le début de
l'enquête PWA) : les deux fichiers sont revenus octet pour octet à cet
état, à l'exception des deux lignes `accept_gzip = false` dans
`Leaderboard._ready()`, qui restent — c'est le seul changement net que
cette enquête laisse dans le code.

### CLASSEMENT PWA : merge en production (16 août 2026, autorisation explicite de Mathieu)

`staging` (`016ada3`) → `main`, commit de merge **`1407bd9`**, après
validation device des deux surfaces (PWA installée + onglet Chrome). Merge
`--no-ff` (aucun conflit) : `main` était strictement en retard sur
`staging` (`main..staging` vide dans l'autre sens, comme sur les merges de
prod précédents de ce repo), l'arbre du commit de merge est **byte-identique
à `claude/accept-gzip-valide-device-sr1tko`** (`git diff HEAD
claude/accept-gzip-valide-device-sr1tko` vide) — ce qui part en prod est
donc littéralement l'arbre validé, pas une recomposition.

**Build/export validés dans ce sandbox avant le merge, éditeur + templates
Godot 4.3-stable installés pour ce lot** (releases GitHub officielles,
réseau disponible cette fois) : import headless **exit 0**, export Web
release **exit 0**, `Leaderboard.gdc`/`GameOverScreen.gdc` compilés sans
erreur dans le `.pck`. `index.wasm` **35 376 909 octets** — identique au
fingerprint déjà consigné pour tous les lots qui ne touchent pas le code
moteur, cohérent avec un diff limité à deux fichiers GDScript + doc.

CI run **#121** (id `31927993066`) verte (3 min 49 s) — `Deploy to Vercel
[PRODUCTION -- main]` réussie, `[STAGING -- staging]` correctement
`skipped` (push sur `main`). **Fingerprint vérifié sur le site LIVE**
(`keepy-ten.vercel.app`, via `mcp__Vercel__web_fetch_vercel_url` — accès
direct bloqué par la politique d'egress du sandbox sur ce domaine, comme
documenté ailleurs dans ce fichier ; HTTP 200, `x-vercel-cache: MISS`,
`last-modified` collé à l'heure de fin de la CI) : `GODOT_CONFIG.fileSizes`
= `index.pck 5 119 296` / `index.wasm 35 376 909`. `index.wasm` **identique
au bit près** à l'export local — c'est lui la preuve d'identité, pas le
`.pck` (rappel permanent déjà consigné : sa taille n'est pas stable d'un
export à l'autre du même commit).

**Reste ouvert : aucun.** Le classement PWA est validé device sur les deux
surfaces demandées, le diagnostic est retiré, `main` sert le fix en
production. Section close.

