# Google Sign-In — proxy /__/auth/*, COOP/COEP, rafraîchissement du token

> Extrait de `CLAUDE.md` par le LOT H (2 septembre 2026), **verbatim** : aucune ligne réécrite, résumée ni supprimée.
> 3 section(s), 672 lignes d'origine.
> Doctrine permanente : voir `CLAUDE.md`. Index des chantiers : `docs/lots/INDEX.md`.

## GOOGLE SIGN-IN : LE POPUP A ÉCHOUÉ AUSSI — proxy `/__/auth/*` pour unifier l'origine, retour au redirect (17 août 2026)

Branche `claude/firebase-auth-cross-origin-fix-oiffyd`, partie de `staging`
(`ffabe64`). Le popup du lot précédent a été testé sur device et a échoué
**pour une raison différente du redirect, mais avec la MÊME cause racine**.
Ce lot ne retente pas un troisième mode d'auth : il corrige l'origine.

### Les deux échecs mesurés sur device (ne pas re-tester, ne pas re-questionner)

- **`signInWithRedirect`** (lot du matin) : page blanche bloquée sur
  `keepy-8df91.firebaseapp.com`, jamais de retour, timeout 12 s côté
  `Auth.gd`. Cause déjà documentée ci-dessus : l'état de redirection en
  attente est gardé sur l'authDomain, une origine tierce pour Safari ITP,
  qui lui donne une partition de stockage différente de celle de l'app.
- **`signInWithPopup`** (lot suivant, ce jour) : le popup s'ouvre — l'incertitude
  d'activation utilisateur documentée plus haut n'était **pas** le problème
  — la mire Google s'affiche, l'authentification se fait. Mais sur iOS le
  popup s'ouvre comme un **nouvel onglet** ; le joueur revient manuellement
  à l'app, et le `postMessage` par lequel le SDK doit livrer son résultat
  **n'atteint jamais l'opener**. Bouton grisé indéfiniment, aucune session
  écrite.

**Cause commune aux deux, et c'est ce que ce lot corrige** : `authDomain`
(`keepy-8df91.firebaseapp.com`) est une origine différente de celle de l'app
(`*.vercel.app`). Que le SDK gare son état dans une navigation cross-origin
(redirect) ou dans une fenêtre cross-origin qui doit reposter vers l'opener
(popup), Safari coupe la même relation à chaque fois. Aucun réglage de
paramètre ne l'aurait résolu sur l'un ou l'autre flow — il fallait supprimer
le cross-origin lui-même.

### 1. Proxy `/__/auth/*` — `vercel.json`

Approche vérifiée dans la documentation officielle avant implémentation
(Google Cloud Identity Platform, « Showing a custom domain during sign
in » / « How to customize auth handler » ; recoupé par l'issue
firebase-js-sdk #7824 et plusieurs implémentations de référence nginx/Vercel)
plutôt que prise sur parole : la manière documentée de servir le handler
Firebase Auth depuis l'origine de l'app est un reverse proxy transparent sur
`/__/auth/*`, `authDomain` étant ensuite pointé sur le domaine propre de
l'app. Firebase lui-même sert cette arborescence en statique sous
l'authDomain par défaut ; la proxifier ne change rien à son contenu, elle
change seulement quelle origine le NAVIGATEUR croit avoir jamais quittée.

```json
"rewrites": [
  { "source": "/__/auth/:path*", "destination": "https://keepy-8df91.firebaseapp.com/__/auth/:path*" }
]
```

**Conflit réel identifié et corrigé, pas ignoré** : la règle `headers`
site-wide (`"source": "/(.*)"`) posait déjà `Cross-Origin-Embedder-Policy:
require-corp` sur TOUTE réponse, `/__/auth/*` compris — les règles
`headers` de Vercel matchent sur le chemin de la requête ORIGINALE,
indépendamment des `rewrites`. Appliquer COEP `require-corp` à une page
`/__/auth/handler` que Firebase sert (potentiellement chargée de
sous-ressources gstatic non maîtrisées par ce dépôt) risque de la casser en
silence si l'une de ces sous-ressources n'annonce pas
`Cross-Origin-Resource-Policy`. Corrigé en excluant `/__/auth/*` de cette
règle par lookahead négatif groupé (syntaxe confirmée dans la doc Vercel
elle-même, `error-list` : un lookahead négatif nu est rejeté, il doit être
enveloppé dans un groupe) :

```json
"source": "/((?!__/auth/).*)"
```

`Cross-Origin-Opener-Policy` **revient à `same-origin`** (elle était passée
à `same-origin-allow-popups` pour le popup, désormais retiré — voir §4) :
plus aucun `window.open` n'est émis par ce dépôt, donc plus aucune raison de
sacrifier `crossOriginIsolated`. La règle `.wasm` (`Content-Type`) est
**intouchée**, et continue de s'appliquer normalement puisque aucun `.wasm`
ne vit sous `/__/auth/`.

**Conflit avec le service worker PWA : vérifié, pas de conflit.** Déjà établi
dans ce fichier (section CLASSEMENT PWA, 14-15 août) sur les octets
RÉELLEMENT servis par `keepy-staging.vercel.app` : le handler `fetch` du
service worker généré par Godot n'appelle `event.respondWith()` que pour une
navigation ou un fichier de `CACHED_FILES`/`CACHABLE_FILES` (index.html/js/
wasm/pck…) — `isCachable` ne peut structurellement jamais être vrai pour une
requête vers `/__/auth/*`, donc c'est un passthrough complet, identique à
l'absence de service worker. Ce lot ne réinstrumente pas cette vérification
(déjà faite et documentée), il en confirme la portée : `/__/auth/*` n'est
dans aucune des deux listes.

### 2. `authDomain` dynamique — `web/html_shell.html`

`resolveAuthDomain()` (nouvelle) : si `window.location.hostname` est
`keepy-ten.vercel.app` ou `keepy-staging.vercel.app` (les deux seuls
domaines où le proxy ci-dessus est réellement déployé), `authDomain` devient
**ce hostname lui-même** — le navigateur ne quitte alors plus jamais son
origine pendant la connexion, hormis la navigation top-level inévitable vers
`accounts.google.com`, qui n'est pas soumise à COEP (COEP ne gouverne que
les sous-ressources d'un document, pas une navigation top-level d'onglet/
fenêtre).

**Fallback explicite pour tout hostname inconnu** (déploiements preview
Vercel à URL aléatoire par commit) : `authDomain` reste
`keepy-8df91.firebaseapp.com`, l'ancien comportement cross-origin — **pas
pour que ça marche** (voir §3), mais pour ne jamais faire croire à un proxy
qui n'a pas été déployé pour cet hôte. Un diagnostic est publié dans
`window.keepyAuth` (`authDomainFallback: true`,
`authDomainFallbackDetail: '...'`) dès la résolution, avant tout tentative
de connexion — visible via `keepyAuthSnapshot()` sans attendre un échec.
**Décision assumée** : ce diagnostic est publié comme un champ d'état, pas
comme un `error` — publier un `error` à ce stade déclencherait
`auth_error` sur `Auth.gd` avant même que le joueur ait tapé le bouton, sur
un hostname où la connexion n'a en réalité pas encore été tentée et pourrait
en théorie réussir hors Safari. `Auth._apply_snapshot()` ignore les clés
qu'elle ne connaît pas — inerte côté GDScript, aucun changement de contrat
nécessaire côté `Auth.gd` pour ce lot.

### 3. Conséquence sur les domaines Authorized — ce qui se passe sur une preview URL

**Chaque domaine qui sert l'app doit être dans Authorized domains Firebase**
— indépendamment du proxy : c'est une vérification Firebase séparée, faite
sur l'origine de la requête, qui rejette avec `auth/unauthorized-domain`
n'importe quel domaine absent de la liste, quel que soit `authDomain`.
`keepy-ten.vercel.app` et `keepy-staging.vercel.app` y sont déjà.

**Sur une URL de preview Vercel (`keepy-git-*.vercel.app`, un hostname
aléatoire par commit) : le sign-in échouera, et c'est structurel, pas un
bug de ce lot.** Deux raisons qui s'additionnent : (a) `resolveAuthDomain()`
retombe sur l'ancien `authDomain` cross-origin, donc le défaut ITP/popup
d'origine se reproduit tel quel sur Safari ; (b) même si l'origine était
unifiée, une URL de preview ne peut de toute façon **jamais** être ajoutée
aux Authorized domains — son hostname change à chaque commit, la liste
Firebase n'accepte que des hostnames fixes. Le joueur y verra un
`popup-start-failed`/`redirect-start-failed` avec `auth/unauthorized-domain`
dans le détail (le catch existant le capture déjà, aucun code nouveau requis
pour ça). **À savoir avant de tester une preview URL et de croire à une
régression : c'est l'état attendu, pas une casse.**

### 4. Popup ou redirect une fois l'origine unifiée : REDIRECT retenu, popup retiré

**Choix tranché en faveur du redirect**, comme suggéré. Justification propre
à ce dépôt, pas seulement la recommandation générale mobile :

L'échec du popup documenté en §… ci-dessus n'était **pas** de la même nature
que celui du redirect — il ne s'agissait pas de storage partitioning à
l'aller-retour mais du comportement propre de Safari iOS qui transforme un
popup en nouvel onglet, combiné à un retour manuel du joueur qui semble
casser la référence `window.opener`/le canal `postMessage`. **Unifier
l'origine ferme le problème du redirect avec certitude** (l'état en attente
n'a plus de frontière de partition tierce à traverser), mais ne ferme le
problème du popup qu'**avec incertitude** — rien ne garantit que la
gestion d'onglet de Safari et la survie de `window.opener` à travers un
changement d'app en arrière-plan se comportent différemment une fois
popup et opener same-origin. Le redirect, lui, n'a structurellement **aucun**
onglet à gérer et **aucun** `postMessage` à perdre : c'est une navigation
de page pleine, le geste mobile le plus élémentaire et le mieux éprouvé — y
compris par Safari iOS lui-même sur d'innombrables flows « Continuer avec
Google » ailleurs sur le web.

**Restauré dans `web/html_shell.html`** (retiré au lot popup, remis à
l'identique fonctionnel, `authDomain` dynamique en plus) :
`getRedirectResult(auth)` appelé au chargement, `PENDING_KEY`
(`keepy.auth.redirect.pending`) + `readPending()`/`writePending()` en
`sessionStorage` pour détecter un redirect qui revient sans rien (partait
avec `wasPending=true`, revient sans `cred` ni `auth.currentUser` →
`redirect-lost`), `keepySignInWithGoogle()` appelle `signInWithRedirect`
au lieu de `signInWithPopup`. **Rien du flow popup ne reste en JS actif** :
`signInWithPopup` n'apparaît plus une seule fois dans le fichier, vérifié
sur le `index.html` généré par l'export.

Le remplacement de la promesse `firstState`/`resolveFirstState`
(introduite au lot popup pour flipper `ready` seulement après le premier
`onAuthStateChanged`, en remplacement de la garantie que
`getRedirectResult()` donnait déjà par effet de bord) **par le
`getRedirectResult()` original** n'est pas une régression : c'est
précisément la garantie que ce mécanisme de remplacement existait pour
recréer, désormais inutile puisque sa cause est restaurée. Garder les deux
aurait été une redondance, pas une robustesse en plus.

`scripts/autoload/Auth.gd` et `scripts/ui/LoginScreen.gd` : **aucun
changement de comportement**, seulement des commentaires mis à jour
(le bloc d'en-tête d'`Auth.gd`, la docstring de `sign_in()`, la liste des
codes possibles sur `auth_error`, le commentaire au-dessus de
`_message_for()`). **Les codes `popup-*` sont CONSERVÉS** dans
`LoginScreen._message_for()`, au même titre que `redirect-*` l'était resté
au lot popup : un navigateur ou service worker servant encore un shell en
cache du lot popup est exactement celui qui a besoin d'un message lisible.
`NEUTRAL_CODES` (`popup-cancelled`) est inchangé pour la même raison — le
redirect n'a pas d'équivalent « annulé proprement » à ajouter : un joueur
qui fait demi-tour pendant un redirect ne déclenche aucun événement côté
app tant qu'il ne revient pas dessus, exactement comme dans l'implémentation
d'origine avant le lot popup.

### 5. Cache-Control sur `index.html`

`vercel.json`, deux nouvelles règles `headers` (`"/"` et `"/index.html"`,
les deux nécessaires puisque le site est servi à la racine et qu'un lecteur
peut viser l'un ou l'autre) : `Cache-Control: no-cache, must-revalidate`.
**`.wasm`/`.pck` non touchés** — leurs noms de fichier ne changent pas d'un
build à l'autre (`index.wasm`/`index.pck`, pas de hash de contenu dans le
nom), donc les laisser cachables reste correct ; c'est `index.html` qui
référence leur taille exacte via `GODOT_CONFIG` et doit toujours être la
version fraîche. **Motif mesuré, pas préventif** : la porte d'auth
(lot du 17 août) est restée invisible **deux fois** sur `staging` tant qu'un
cache-bust manuel (`?v=2`) n'était pas forcé à la main — deux sessions de
test device faussées par un `index.html` mis en cache par le navigateur/CDN
avant même que la question de l'auth ne se pose.

### Validation

Éditeur + templates Godot 4.3-stable installés dans ce sandbox pour ce lot
(releases GitHub officielles). Import headless **exit 0**, export Web
release **exit 0** (`xvfb-run`), boot de `res://scenes/LoginScreen.tscn`
(`--quit-after 2`) **exit 0**, aucune erreur de parse sur les deux `.gd`
modifiés. `index.wasm` **35 376 909 octets**, identique au fingerprint
consigné pour tout lot ne touchant pas le code moteur — cohérent, ce lot ne
touche que des commentaires GDScript et des fichiers hors ressources Godot
(`vercel.json`, `web/html_shell.html`). `vercel.json` validé comme JSON
strict avant commit. `index.html` généré vérifié : **0** occurrence de
`signInWithPopup`, `getRedirectResult`/`resolveAuthDomain`/
`KNOWN_AUTH_HOSTS`/`signInWithRedirect` bien présents en code.

**4 sondes rejouées sur cette branche, toutes exit 0** : `ProbeTimeoutAudit`
(**33 sondes armées**, chiffre inchangé), `AssetContractAudit` (12/12
visuels, **0/10 colliders déplacés**), `DeathModelAudit` (CHARGER seul
fatal, les 5 autres types 1 demi-unité, capture au 2ᵉ contact — inchangé),
`ChargerShapeProbe`. **Structurellement, ce lot ne peut pas déplacer un flux
RNG seedé** : `Auth.gd` tourne dans chaque sonde en tant qu'autoload, mais
son `_ready()` sort avant toute ligne utile dès que `OS.has_feature("web")`
est faux (systématique sous `--headless`) — rien de ce lot n'est dans le
chemin que les sondes exécutent, et le diff des trois fichiers `.gd`/`.tscn`
touchés par ce lot au global est nul (`LoginScreen.gd`/`Auth.gd` uniquement,
tous deux hors du chemin de chargement `run/main_scene` des sondes).
`ComboAudit`/`ShrinkAudit` n'ont pas pu être rejouées jusqu'au bout dans ce
sandbox avant l'envoi de ce rapport (CPU partagée avec l'export/les autres
sondes, chacune de l'ordre de plusieurs minutes) — attendu byte-identique
par le même argument structurel, pas mesuré ici ; à vérifier si un doute
subsiste.

### Reste ouvert — jugement device, seul juge

Le test sur iPhone Safari (onglet normal **et** PWA installée si possible)
doit confirmer, dans cet ordre : (a) le tap sur « Se connecter » redirige
bien vers un `/__/auth/...` sous `keepy-staging.vercel.app` — c'est la
preuve visuelle la plus directe que le proxy est actif (l'URL affichée par
Safari ne doit **jamais** montrer `firebaseapp.com`) ; (b) le retour après
consentement Google atterrit bien sur l'app avec une session écrite, sans
passer par le timeout de 12 s ; (c) qu'un rechargement à froid de
`keepy-staging.vercel.app` (pas juste un retour d'onglet) serve bien la
version fraîche du gate — c'est ce que le fix Cache-Control du §5 doit
garantir, et c'était justement invisible sans cache-bust manuel lors des
deux tests précédents. Aucune sonde de ce dépôt ne rend de pixels iOS réels
ni ne peut suivre une redirection cross-origin réelle vers
`accounts.google.com` — c'est structurellement hors de portée d'un test
headless Godot.

## GOOGLE SIGN-IN RÉPARÉ : le proxy `/__/auth/*` était CORRECT, c'est COOP/COEP qui bloquait l'iframe d'auth (17 août 2026)

Branche `claude/firebase-auth-iframe-proxy-17h5vm`, partie de `staging`
(`6bb80a2`). **L'instrumentation du lot précédent (`4480691`) a payé dès son
premier test device** : elle a localisé le blocage à une seule transition, et
c'est cette mesure — pas une hypothèse — qui a orienté tout ce lot.

**Mesure device (iPhone Safari, Wi-Fi, staging)** : dernier checkpoint atteint
`listener-registered (0,5 s)`, checkpoint **jamais** atteint
`first-auth-state-received`, puis `bridge-timeout` à 12 s. Le SDK Firebase
charge et s'initialise en 0,5 s — **réseau, DNS, Wi-Fi et gstatic sont donc
éliminés par la mesure**, pas par argument. `onAuthStateChanged` est bien
enregistré mais son premier callback n'est jamais émis, même avec `user=null`.

### ⚠️ LE PROXY N'EST PAS CASSÉ — mesuré sur les réponses SERVIES, pas lu dans la config

L'hypothèse de départ (le proxy `/__/auth/*` ne restituerait pas ce que le SDK
attend) est **INFIRMÉE**. Les trois routes ont été récupérées telles que
`keepy-staging.vercel.app` les sert réellement (via
`mcp__Vercel__web_fetch_vercel_url` — l'egress direct de ce sandbox est bloqué
en 403 CONNECT sur `*.vercel.app`, `*.firebaseapp.com` ET `gstatic.com`, donc
aucune comparaison directe avec l'origine Firebase n'était possible) :

| route | statut | Content-Type | COOP/COEP servis |
|---|---|---|---|
| `/__/auth/iframe` | **200** | `text/html; charset=utf-8` | **aucun** |
| `/__/auth/iframe.js` | **200** (296 Ko, 94 Ko gzip) | `text/javascript; charset=utf-8` | **aucun** |
| `/__/auth/handler` | **200** | `text/html; charset=utf-8` | **aucun** |
| `/index.html` (le PARENT) | 200 | `text/html` | **COEP `require-corp` + COOP `same-origin`** |

Les corps sont ceux de Firebase (`fireauth.iframe.AuthRelay.initialize()`,
`vary: x-fh-requested-host` — la requête atteint bien Firebase Hosting), et les
chemins **relatifs** (`iframe.js`, `handler.js`) se résolvent correctement sous
`/__/auth/` à travers le rewrite. **Le lookahead négatif de `vercel.json`
fonctionne exactement comme prévu** : COOP/COEP sont bien absents des routes
d'auth — vérifié sur la réponse servie, ce que la tâche demandait explicitement.

### La cause : l'exclusion est EXACTEMENT À L'ENVERS

Sous `Cross-Origin-Embedder-Policy: require-corp`, **un document imbriqué doit
LUI-MÊME déclarer un COEP compatible ou le navigateur refuse de l'intégrer** —
et, contrairement à CORP, **être same-origin n'exempte de rien**. Retirer COEP
de `/__/auth/*` est donc précisément ce qui faisait refuser au parent
l'intégration de l'iframe que Firebase ouvre au démarrage. Firebase attend cette
iframe avant de résoudre l'état d'auth : d'où un premier `onAuthStateChanged`
jamais émis. **C'est tout le bug**, et il correspond exactement à la mesure.

**REPRODUIT EN CHROMIUM** (Playwright local — le seul navigateur atteignable
depuis ce sandbox), avec les **en-têtes exacts** mesurés ci-dessus et les
**octets exacts** du corps de `/__/auth/iframe`, sur une iframe **same-origin**
qui doit charger puis `postMessage` vers son parent — le mécanisme même de
l'AuthRelay :

| variante | relay reçu par le parent | verdict |
|---|---|---|
| **A — staging tel que déployé** (parent COEP, iframe sans COEP) | **NONE** | **BLOQUÉE** |
| B — ajouter COEP sur `/__/auth/*` | `RELAY-INITIALIZED` | passe |
| **C — CE FIX : plus de COOP/COEP du tout** | `RELAY-INITIALIZED` | passe |

⚠️ **`iframe.onload` SE DÉCLENCHE QUAND MÊME dans le cas bloqué** (mesuré) —
aucune exception, aucune erreur console, rien qui ait l'air cassé. C'est
exactement pourquoi la panne était totalement silencieuse, et pourquoi
`onload` est inutilisable comme signal de santé.

### Arbitrage explicite : (a2) supprimer COOP/COEP, PAS (a1) les ajouter à `/__/auth/*`

Les deux options débloquent l'embed (variantes B et C ci-dessus, mesurées).

**(a1) — ajouter COEP sur `/__/auth/*` : ÉCARTÉE.** Elle place l'iframe de
Firebase sous `require-corp`, or cette iframe tire **`apis.google.com`**
(mesuré : 3 références dans le `iframe.js` réellement proxifié), un script
classique cross-origin qui exigerait alors un en-tête CORP que **nous ne
contrôlons pas et que ce sandbox ne peut pas tester** (egress Google bloqué).
C'est échanger un bug mesuré contre un bug non mesurable — et un aller-retour
device de plus si Google ne l'envoie pas.

**(a2) — supprimer COOP/COEP : RETENUE.** Sans COEP sur le parent, **le contrôle
sur document imbriqué ne s'exécute plus du tout** : l'iframe d'auth s'intègre
quels que soient les en-têtes de Firebase, et les sous-ressources de Firebase ne
sont plus contraintes. On supprime la CLASSE de panne, pas une instance.

⚠️ **La prémisse qui avait introduit ces en-têtes est FAUSSE pour ce build.**
Commit `55df42c` : « SharedArrayBuffer (required by the Godot 4 web runtime)
needs cross-origin isolation ». Or l'export est la variante **nothreads** —
`index.html` **servi en production** porte `GODOT_THREADS_ENABLED = false` et
`ensureCrossOriginIsolationHeaders: false`, `export_presets.cfg` n'a aucun
`variant/thread_support`, et **le dépôt ne contient aucune occurrence de
`SharedArrayBuffer` ni de `crossOriginIsolated`**. Rien ici n'a jamais eu
besoin d'isolation cross-origin. Quatrième fois dans ce dépôt qu'une prémisse
annoncée ne survit pas à la mesure.

**Ne PAS réintroduire COOP/COEP** : ça re-casse le sign-in, silencieusement.
`vercel.json` étant du JSON strict (aucun commentaire possible), tout
l'argumentaire vit dans le commentaire de bloc de `web/html_shell.html`.

**(b) — revenir à `authDomain = keepy-8df91.firebaseapp.com` : ÉCARTÉE**, et pas
seulement par préférence : ce chemin est **déjà mesuré en échec sur Safari iOS**
(ITP, deux tests device le 17 août). Il n'aurait été acceptable qu'accompagné
d'une alternative au cross-origin — domaine custom Firebase Hosting ou
sous-domaine dédié — qui exige DNS, certificat et console Firebase, donc du
travail manuel de Mathieu hors de portée d'une session. Inutile de payer ça
quand (a2) est un fix mesuré et contenu.

### Instrumentation CONSERVÉE et ÉTENDUE (tâches 4 et 5)

Les six checkpoints existants sont **intacts** — ils viennent de prouver leur
valeur, les retirer maintenant serait absurde. S'y ajoute un **watchdog de
stall + sonde d'embed** qui nomme ce point précis à l'écran la prochaine fois :

```
first-auth-state-stalled -> auth-iframe-embed-ok
                          | auth-iframe-embed-blocked
                          | auth-iframe-probe-skipped-cross-origin
                          | auth-iframe-probe-failed
```

⚠️ **Elle ne tourne QUE si le boot a déjà stallé** (6 s), jamais sur le chemin
sain : la sonde intègre une seconde copie de l'iframe relay, ce qui coûte un
fetch de 296 Ko et une frame vivante — un diagnostic qui taxe le cas qui marche
est un diagnostic qu'on finit par retirer. Plafond 3 s, verdict à ~9 s, donc
**à l'intérieur** des 12 s de `BRIDGE_TIMEOUT_S` d'`Auth.gd` au lieu de courir
contre.

⚠️ **La méthode de détection est MESURÉE, pas supposée** : `onload` se
déclenchant dans les deux cas, la sonde lit `contentWindow.location.href` —
`SecurityError` quand COEP a bloqué, URL de la frame quand elle a chargé (le
proxy la rend same-origin). **La fonction réellement livrée a été extraite
verbatim de `html_shell.html` et exercée en Chromium** : verdict `BLOCKED` sur
la config telle que déployée, `OK` sur celle de ce fix, et **0 frame résiduelle**
dans les deux cas (elle se nettoie).

⚠️ Sur un host inconnu (previews), `authDomain` reste cross-origin, donc la
lecture ci-dessus lèverait `SecurityError` **pour une raison parfaitement
légitime**. La sonde refuse alors de répondre
(`auth-iframe-probe-skipped-cross-origin`) plutôt que de rapporter un faux
blocage — une sonde qui ment là où personne ne peut la contredire est
exactement le piège « fixture qui diverge du réel » que ce dépôt documente.

Strictement additive : elle n'appelle que `publishStage()`, donc elle ne peut
toucher ni `status`, ni `error`, ni `ready`, ni le comportement du jeu. **Aucun
changement côté Godot** — `Auth.gd` et `LoginScreen.gd` sont intouchés, les
nouveaux checkpoints passent par le canal `stage` existant.

### Validation

Import headless **exit 0**, export Web release **exit 0**. `index.wasm`
**35 376 909 octets** — identique au fingerprint consigné pour tout lot qui ne
touche pas le code moteur (cohérent : ce lot ne change que du HTML/JS de
coquille et un fichier de config de déploiement).

Sondes rejouées, **toutes exit 0** : `ProbeTimeoutAudit` (**33 sondes, toutes
armées**), `AssetContractAudit` (**12/12 visuels, 0/10 colliders déplacés**),
`DeathModelAudit`, `ChargerShapeProbe`. **Non-applicabilité vérifiée plutôt que
supposée** : aucune sonde de `scripts/dev/` ne rend de HTML ni n'évalue de JS de
coquille, et `Auth.gd` sort de sa `_ready()` avant toute ligne utile dès que
`OS.has_feature("web")` est faux — systématique sous `--headless`.

### Reste ouvert — jugement device, c'est le seul juge

Aucune sonde de ce dépôt ne rend de pixels iOS ni ne peut exécuter le vrai SDK
Firebase : la reproduction Chromium prouve le **mécanisme** et le **fix**, pas
que Safari se comporte à l'identique (Safari est plus strict, pas moins, sur
COEP comme sur ITP). Ce qui reste à confirmer sur device : que le sign-in
Google aboutit enfin sur `keepy-staging.vercel.app`, en onglet Safari **et** en
PWA installée. Si un `bridge-timeout` survient encore, l'écran doit désormais
afficher `first-auth-state-stalled` suivi d'un verdict d'embed — et un
`auth-iframe-embed-ok` serait l'information la plus intéressante possible : il
dirait que l'iframe s'intègre et que le blocage est ailleurs.

## RAFRAÎCHISSEMENT DU TOKEN FIREBASE : défaut CLOS — `onIdTokenChanged` remplace `onAuthStateChanged` (18 août 2026)

Branche `claude/firebase-token-refresh-ipkaym`, partie de `main`
(`afed994`). **Ferme le défaut connu ouvert depuis le lot de durcissement
des rules du 18 août** (« ⚠️ DÉFAUT TROUVÉ EN LISANT LE CODE, NON CORRIGÉ
ICI — le token n'est JAMAIS rafraîchi »), listé « reste ouvert » dans les
trois lots suivants sans être traité. **Prérequis à `Quizz.gd`**, qui y
sera bien plus exposé que `Leaderboard.gd` : Chased n'écrit qu'une fois par
run de 40-90 s, Quizz écrira de façon répétée et étalée dans le temps.

**Trois fichiers : `web/html_shell.html`, `scripts/autoload/Auth.gd`, ce
document.** `scripts/autoload/Leaderboard.gd` est **byte-intouché**
(`git diff` vide) — c'était la contrainte du lot, et elle tient sans effort
pour une raison structurelle expliquée plus bas. Aucune scène, aucun
collider, aucune constante de gameplay, aucun `.glb`, aucune config
d'export.

### Le mécanisme du défaut, et pourquoi il était silencieux

Un token d'ID Firebase **expire au bout d'une heure**. Le SDK le renouvelle
tout seul bien avant, mais le shell n'écoutait que **`onAuthStateChanged`**,
qui ne tire **que** sur connexion et déconnexion — **jamais** sur un
renouvellement. Le `idToken` publié dans `window.keepyAuth` restait donc la
chaîne capturée une fois à la connexion, pour toute la session.

⚠️ **Ce que l'ancienne formulation du défaut disait d'`Auth.gd` était
imprécis, et c'est vérifié dans le code plutôt que repris tel quel.** Le
`set_process(false)` posé après `ready` **ne coupait PAS la réception** :
il ne coupait que le **poll de secours**. Le callback push
(`window.keepyAuthNotify`, installé dans `_ready()` et jamais retiré)
restait vivant, et `_apply_snapshot()` écrase bien `_id_token` à chaque
snapshot reçu. **Le défaut était donc à 100 % côté shell** — rien n'était
jamais republié, donc il n'y avait rien à pousser. Corriger le seul
`onAuthStateChanged` suffit à fermer le défaut ; le volet `Auth.gd`
ci-dessous ferme un trou distinct.

Silencieux parce que le chemin d'échec est **le même que celui d'être hors
ligne** : `Leaderboard.gd` prend un `push_warning`, émet
`submit_finished(false)`, et l'écran affiche « Score non synchronisé (hors
ligne ?) ». Un joueur dont la session dure plus d'une heure voyait donc un
message de réseau pour une cause d'authentification.

### Le fix — `onIdTokenChanged` est un SUPERSET, pas une alternative

Les deux listeners ne sont pas deux options à arbitrer :
`onIdTokenChanged` tire **exactement là où `onAuthStateChanged` tire**
(une fois au démarrage avec l'utilisateur restauré ou `null`, puis à chaque
connexion/déconnexion) **PLUS** à chaque renouvellement de token.
**Remplacé, pas ajouté à côté** : enregistrer les deux publierait le même
payload deux fois à chaque connexion et déconnexion, soit un second écrivain
pour un fait qui a déjà un propriétaire — le contraire de la discipline que
tout ce fichier applique par ailleurs.

⚠️ **Piège fermé explicitement dans le commentaire, parce qu'il est
séduisant : `getIdToken(true)` À L'INTÉRIEUR de ce listener est une boucle
infinie.** Un refresh forcé produit un nouveau token, ce qui refait tirer ce
même listener, ce qui reforce un refresh — contre les serveurs de Google. Le
`getIdToken()` **non forcé** déjà en place est le bon appel : sur un
callback de renouvellement, le token que le SDK vient de mettre en cache
**EST** le nouveau.

**Les noms de checkpoints de diagnostic sont volontairement INCHANGÉS**
(`first-auth-state-received` en particulier, toujours posé par
`firstAuthStateSeen` sur le premier appel du nouveau listener). Ils sont
cités dans `Auth.gd`, dans le label écran de `LoginScreen.gd` et dans ce
document comme l'état sain de fin de boot ; les renommer les aurait
invalidés partout sans le dire. Le watchdog de stall (qui teste
`firstAuthStateSeen`) et la sonde d'embed d'iframe sont donc **intacts et
toujours fonctionnels**.

### AJOUT au-delà du périmètre littéral : le backstop `visibilitychange`

Dit plutôt que glissé : ce lot ajoute une chose que la liste de tâches ne
demandait pas nommément, parce qu'elle relève du même défaut.

Le renouvellement proactif du SDK est **un timer**, et un timer dans un
onglet en arrière-plan — **une PWA installée que le joueur a quittée est le
cas ORDINAIRE sur mobile, pas le cas exotique** — est throttlé ou suspendu
par le navigateur. Il peut donc tirer en retard, laissant une fenêtre où le
token publié est déjà expiré au retour du joueur.

Un handler `visibilitychange` appelle `user.getIdToken()` **sans
`forceRefresh`** quand la page redevient visible. C'est exactement le bon
appel : la méthode rend le token en cache **tel quel** s'il n'expire pas
dans les cinq minutes, et ne renouvelle que sinon. Donc **no-op sur chaque
changement d'onglet ordinaire, vrai renouvellement seulement quand il
serait sinon trop tard**. Il **ne publie rien lui-même** — un
renouvellement fait tirer `onIdTokenChanged`, qui reste l'unique écrivain
d'`idToken`. Enveloppé dans un `try/catch` : perdre ce backstop coûte de la
fraîcheur après un long arrière-plan, jamais la connexion.

### `Auth.gd` — le poll de secours ne s'arrête plus, il RALENTIT ×60

`POLL_INTERVAL_READY_S := 30.0` (nouveau) remplace le `set_process(false)`
sur le chemin sain. **L'argument d'origine reste vrai et n'est pas
contredit** : un `JavaScriptBridge.eval` à 2 Hz n'a rien à faire dans le
budget de frame d'un runner à 60 fps. Il ne dit rien de **1/30 Hz**, qui est
ce qui est posé ici — **600× moins cher** que le poll de démarrage.

Ce qui a changé, c'est ce que ce backstop protège. Avant, il n'y avait rien
à rattraper après `ready` : l'état était capturé une fois et fini, et le
seul événement manquable aurait été une déconnexion que rien dans ce jeu ne
déclenche. Maintenant que le shell republie à chaque renouvellement, **un
push perdu après `ready` coûte un bearer périmé de façon permanente** — soit
exactement le défaut que ce lot ferme. Et un push perdu est **silencieux par
conception** : le `publish()` du shell avale un listener qui lève
(« un Godot cassé ne doit jamais casser l'auth »). Un backstop qui s'arrête
avant que la chose qu'il couvre ne commence à arriver n'est pas un backstop.

⚠️ **Le chemin `bridge-timeout` garde EXACTEMENT son comportement d'avant
(`set_process(false)`), et c'est délibéré.** Le confier au backstop lent
aurait fait relire le snapshot du bloc `<script>` pré-module — celui qui
porte `error: 'not-ready'` — dont le code aurait **écrasé `bridge-timeout` à
l'écran** et perdu le seul diagnostic que ce chemin existe pour produire.
Deux états « ready » distincts (annoncé par le pont / conclu par timeout),
deux traitements.

`get_id_token()` gagne un contrat explicite dans sa doc : **c'est le token
COURANT, pas celui capturé à la connexion**, et un appelant doit le lire au
moment où il en a besoin plutôt que de mettre le résultat en cache.

### Tâche 3 — `Leaderboard.gd` : rien à changer, et c'est structurel

**Vérifié dans le code, pas supposé** : `_request_headers()` est appelé
**en ligne dans l'appel `request()` lui-même**, aux deux points d'entrée
(`submit_score` ligne 221, `fetch_top_scores` ligne 255), jamais une fois
dans `_ready()`. Il relit donc `Auth.get_id_token()` à chaque requête et
récupère le token frais **sans une ligne de changement**. Le
court-circuit headless (`if not network_enabled` en toute première
instruction des deux points d'entrée) est également intact : une sonde ne
touche jamais `Auth`.

### Tâche 4 — sondes headless : intactes, et c'est structurel aussi

`Auth.gd` tourne en autoload dans **chaque** sonde, mais son `_ready()`
prend la branche `if not OS.has_feature("web")` — systématiquement vraie
sous `--headless` — qui appelle `set_process(false)` et `return` avant
toute ligne utile. `_process()` n'est donc **jamais** exécuté sous sonde, et
le nouveau `POLL_INTERVAL_READY_S` **jamais atteint**.
`web/html_shell.html` n'est ni une ressource Godot ni chargé par quoi que
ce soit en headless. **Aucune sonde ne peut voir ce lot**, par construction
et pas par chance. Rejouées quand même, résultats plus bas.

### Validation

Éditeur + templates Godot 4.3-stable installés dans ce sandbox (releases
GitHub officielles, mêmes que la CI).

⚠️ **Piège d'outillage rencontré, à connaître** : le premier téléchargement
de `Godot_v4.3-stable_export_templates.tpz` s'est terminé **sans erreur
curl** à **318 289 257 octets** contre les **1 073 228 327** annoncés par le
`Content-Length` — une troncature silencieuse, qui se manifeste plus loin
par un `End-of-central-directory signature not found` d'`unzip` ressemblant
à une archive corrompue en amont. **Toujours vérifier la taille contre le
`Content-Length` avant de conclure que la release est cassée**, et reprendre
avec `curl -C -`.

Les deux blocs `<script>` du shell extraits et vérifiés avec `node --check`
(syntaxe seule, aucun DOM ni SDK réel en headless) : **les deux OK**.

Import headless **exit 0**, export Web release **exit 0**. `index.wasm`
**35 376 909 octets**, md5 **`af4a8fc2925d992348eb30deeeb54360`** — identique
au fingerprint déjà consigné pour tout lot qui ne touche pas le code moteur ;
`index.js` md5 **`4e08904b1b7107858246af44b602067b`**, également identique.
`index.pck` 5 451 104 octets (export unique et propre, `build/` et `.godot/`
supprimés d'abord — à lire avec la mise en garde permanente sur son
instabilité, jamais offert comme preuve). `index.manifest.json` inchangé.
**Piège payload tenu** : **0** ligne `Storing File` pour `res://assets_source`,
`res://docs`, `res://web` ou `firebase.json`.

**Vérifié dans le bundle EXPORTÉ, pas seulement dans la source** :
`authMod.onAuthStateChanged` **0 occurrence** (les 5 mentions restantes de
`onAuthStateChanged` sont toutes des commentaires, dont deux volontairement
laissées au passé — elles racontent le bug COEP du 17 août, où le listener
S'APPELAIT bien ainsi) ; `onIdTokenChanged` 5, `visibilitychange` 1,
`first-auth-state-received` 3. `viewport-fit=cover` et `#101d0b` toujours en
place — le fix safe-area du 17 août n'est pas abîmé.

**QUATRE sondes rejouées et diffées contre `origin/main` en worktree séparé :
les QUATRE sont BYTE-IDENTIQUES sur les DEUX flux (stdout ET stderr), exit 0
des deux côtés** — `ProbeTimeoutAudit` (**33 sondes armées**),
`AssetContractAudit` (**12/12 visuels, 0/10 colliders déplacés**),
`DeathModelAudit`, `ChargerShapeProbe`. C'est le bar attendu, et l'identité au
bit près le dit plus fort qu'un simple verdict identique.

⚠️ **Second piège d'outillage, celui-ci capable de fabriquer un FAUX ROUGE — à
connaître avant d'accuser son propre lot.** Le premier run de comparaison a
donné 3 sondes sur 4 « DIFFERS », dont `AssetContractAudit` annonçant
`[-- ]` là où le lot lit `[glb]` : de quoi croire à une régression d'assets.
Ce n'en était pas une — l'import du worktree de baseline avait été coupé avant
la fin (**5 puis 21 `.scn` importés sur 24**), donc les `.glb` manquaient et la
baseline mesurait des placeholders. Le `stderr` le disait (`Cannot open file
'res://.godot/imported/*.glb-*.scn'`) et le `stdout` seul ne le disait pas.
**Compter les `.scn` de `.godot/imported/` des deux côtés avant de comparer
quoi que ce soit** : un import Godot complet de ce projet prend plusieurs
minutes dans ce sandbox et ne signale pas lui-même qu'il a été interrompu.

### Déployé sur `staging` (palier 1, automatique)

`staging` `e1f97fc`, CI run **#150** (id `32150981048`) **verte en
5 min 11 s** — `Deploy to Vercel [STAGING -- staging]` **succès**,
`[PRODUCTION -- main]` correctement **skipped**. `main` **non touché**
(palier 2, gaté par Mathieu après validation device).

**Fingerprint vérifié sur le site LIVE** (`keepy-staging.vercel.app`, via
`mcp__Vercel__web_fetch_vercel_url` — l'egress direct de ce sandbox reste
bloqué en 403 CONNECT sur ce domaine, re-testé et pas supposé) : HTTP 200,
`x-vercel-cache: MISS`, `age: 0`, `last-modified` collé à l'instant de la
requête (l'index est servi en `no-cache, must-revalidate`) — trois signaux
indépendants qui disent que ce n'est pas une réponse de cache.
`GODOT_CONFIG.fileSizes` = `index.pck 5 451 120` / **`index.wasm
35 376 909`**, ce dernier identique au bit près à l'export local.

⚠️ **Le fix est vérifié DANS LES OCTETS SERVIS, pas seulement dans le
commit** : le shell livré porte bien `authMod.onIdTokenChanged(auth, ...)`
et le handler `visibilitychange`. **Un AVANT/APRÈS réel a été capturé au
passage**, parce que la même URL avait été lue trop tôt : à 14:55 elle
servait encore `authMod.onAuthStateChanged` (build précédent), à 14:58 elle
sert `onIdTokenChanged`.

⚠️ **Discriminateur bon marché trouvé et à réutiliser** : `index.pck` n'est
pas stable d'un export à l'autre et `index.wasm` ne bouge jamais sur un lot
sans code moteur — **aucun des deux ne dit quel build est aliasé**. Le
`CACHE_VERSION` d'`index.service.worker.js` (~5 Ko) est un **epoch de
l'instant d'export** : `1787056834` = 12:40:34 UTC (run #147, l'ancien) puis
`1787064920` = 14:55:20 UTC (run #150, celui-ci). Un fichier minuscule qui
date le build servi, là où l'index complet coûte ~30 Ko à relire.

⚠️ **L'API GitHub Actions a de nouveau servi des réponses PÉRIMÉES**, comme
la section dédiée le documente : trois polls successifs ont rendu une
réponse **byte-identique** figée sur `updated_at: 14:52:21`, `filter:
"latest"` compris, pendant que le job avançait réellement. Ce qui a tranché
n'est pas un poll de plus mais le **second signal indépendant** — le
`CACHE_VERSION` servi par le site. Ne jamais conclure d'un seul appel.

### Reste ouvert — jugement device, seul juge

Aucune sonde de ce dépôt ne rend de pixels iOS, n'exécute le SDK Firebase,
ni ne peut faire passer une heure à une session réelle. Ce qui reste à
confirmer, et ce qui ne peut l'être que sur device :

1. **Le cas nominal ne régresse pas** : connexion Google sur
   `keepy-staging.vercel.app`, arrivée au hub, une run de Chased, et le
   score qui se synchronise comme avant. C'est le risque principal du lot —
   le listener remplacé est celui dont dépend tout le boot.
2. **Le cas que le lot corrige** : une session laissée ouverte **plus
   d'une heure** (idéalement en PWA installée, mise en arrière-plan puis
   reprise), puis une soumission de score qui aboutit toujours. Avant ce
   lot elle échouait en « Score non synchronisé ».
3. Le backstop `visibilitychange` n'a **aucune preuve mesurée** ici : il
   repose sur le contrat documenté de `getIdToken()` (« rend le cache sauf
   à moins de cinq minutes de l'expiration »), pas sur une observation.

