# Index des lots Keepy

> Créé par le **LOT H** (2 septembre 2026), qui a découpé `CLAUDE.md`
> (26 321 lignes de contenu, 133 sections H2) en un fichier de doctrine et
> vingt-cinq fichiers de chantier. **C'est un déplacement, pas une purge** :
> chaque section vit ici *verbatim*, dans son ordre chronologique d'origine.
> Rien n'a été résumé, condensé, réécrit ni supprimé.
>
> La **doctrine permanente** — pièges d'outillage, pièges Godot, doctrine de
> conception, règles d'art, paliers de déploiement — vit dans
> [`CLAUDE.md`](../../CLAUDE.md) et **nulle part ailleurs**.

## Comment lire ce tableau

* **Sections** : nombre de sections H2 d'origine dans le fichier (le
  découpage était *fence-aware* — les `##` à l'intérieur d'un bloc de code
  GDScript sont des commentaires de documentation, pas des titres).
* **Dernier déploiement consigné** : la dernière cérémonie de déploiement
  *écrite dans ce fichier* — `main`, `staging`, ou `—` quand le chantier
  n'en contient aucune. ⚠️ **`—` ne veut PAS dire « pas en production »** :
  les premiers chantiers précèdent l'établissement de la vérification
  sur le service, et un chantier peut avoir été emporté en prod par le
  merge d'un autre.

## Chantiers

| # | Chantier | Fichier | Sections | Lignes | Période | Dernier déploiement consigné |
|---|---|---|---|---|---|---|
| CH01 | Pipeline assets Meshy — les six hazards et leurs recolorisations | [CH01_MESHY.md](CH01_MESHY.md) | 14 | 2132 | 11 → 13 août 2026 | `main` |
| CH02 | Palette marécage — direction artistique permanente et `SwampPalette` | [CH02_PALETTE.md](CH02_PALETTE.md) | 3 | 541 | 11 → 23 août 2026 | `main` |
| CH03 | Sondes — budget temps, watchdog, `ProbeTimeoutAudit` | [CH03_SONDES.md](CH03_SONDES.md) | 1 | 109 | 9 août 2026 | — |
| CH04 | Keepy Chased — décor procédural, modèle de mort, poursuivant, audio | [CH04_CHASED.md](CH04_CHASED.md) | 5 | 411 | 9 → 10 août 2026 | — |
| CH05 | Déploiement — paliers staging/main, CI, API périmées | [CH05_DEPLOIEMENT.md](CH05_DEPLOIEMENT.md) | 3 | 149 | 8 → 17 août 2026 | — |
| CH06 | Écrans 2D — titre, logo, icône PWA, safe-area, letterbox | [CH06_UI_ECRANS.md](CH06_UI_ECRANS.md) | 7 | 950 | 14 → 19 août 2026 | `main` |
| CH07 | Google Sign-In — proxy `/__/auth/*`, COOP/COEP, rafraîchissement du token | [CH07_AUTH.md](CH07_AUTH.md) | 3 | 678 | 17 → 18 août 2026 | — |
| CH08 | Firestore — rules versionnées, durcissement auth, plan Firebase | [CH08_FIRESTORE.md](CH08_FIRESTORE.md) | 6 | 1153 | 18 → 22 août 2026 | `main` |
| CH09 | Keepy Quizz — autoload CRUD et premier écran | [CH09_QUIZZ.md](CH09_QUIZZ.md) | 2 | 440 | 18 août 2026 | — |
| CH10 | Keepy Battle — lots 1 à 12 | [CH10_BATTLE.md](CH10_BATTLE.md) | 13 | 3185 | 20 → 22 août 2026 | `staging` |
| CH11 | Hub — du menu 2D au plateau 3D, décor, extensions, MultiMesh | [CH11_HUB_PLATEAU.md](CH11_HUB_PLATEAU.md) | 10 | 2149 | 18 → 25 août 2026 | `staging` |
| CH12 | Eau — géométrie des cinq corps, lake, stream, spawn-lake | [CH12_EAU_GEOMETRIE.md](CH12_EAU_GEOMETRIE.md) | 5 | 1431 | 25 → 26 août 2026 | `staging` |
| CH13 | Eau — rendu : teinte de Keepy, ligne de flottaison, impact | [CH13_EAU_RENDU.md](CH13_EAU_RENDU.md) | 4 | 1014 | 27 août 2026 | `staging` |
| CH14 | Bateau — le ruisseau devient ridable | [CH14_BATEAU.md](CH14_BATEAU.md) | 2 | 500 | 26 août 2026 | `main` |
| CH15 | Plongeoir — la chaîne complète et sa généralisation | [CH15_PLONGEOIR.md](CH15_PLONGEOIR.md) | 2 | 270 | 27 août 2026 | — |
| CH16 | Tourniquet, balançoire et lobe nord | [CH16_TOURNIQUET_BALANCOIRE.md](CH16_TOURNIQUET_BALANCOIRE.md) | 4 | 1243 | 28 août 2026 | `main` |
| CH17 | Hibou — prop statique et vol en boucle | [CH17_HIBOU.md](CH17_HIBOU.md) | 3 | 949 | 28 août 2026 | `main` |
| CH18 | Cabane et navigation multi-niveaux | [CH18_CABANE_NAV.md](CH18_CABANE_NAV.md) | 13 | 3026 | 28 → 31 août 2026 | `main` |
| CH19 | Pie, baiser et hotspot du lit | [CH19_PIE.md](CH19_PIE.md) | 11 | 2244 | 31 août → 1 sept 2026 | `main` |
| CH20 | Ours — lots A à F, du rig animé au siège de balançoire | [CH20_OURS.md](CH20_OURS.md) | 7 | 1256 | 1 → 2 sept 2026 | `staging` |
| CH21 | Tyrolienne — recon, palier 1 (structure/câble), palier 2 (blaireau/porte/nacelle), retouche échelle blaireau + diagnostic point nord, station debout dégagée de l'escalier, tier 3 (trajet solo sur la structure + retour automatique du blaireau au sud) | [CH21_TYROLIENNE.md](CH21_TYROLIENNE.md) | 17 | 2338 | 3 → 4 sept 2026 | `staging` |
| CH22 | Audit visuel du hub 3D — recon pure, lecture seule : inventaire mesuré des 154 nœuds de dessin, budget 61 161 triangles, ancrage, densité XZ, palette (20 albédos sur 25 en bande morte), liste A (7 corrections sans asset) et liste B (5 fiches Meshy), arbitrage des deux décimateurs ; puis lot batch appliquant A1/A2/A3/A6 (61 161 → 60 201 triangles, `Rock` 1,43:1 → 3,14:1) et mesurant la **pire frame** laissée ouverte par la recon — 48 012 primitives, sous le plafond de frame de 50 000 | [CH22_HUB_VISUEL.md](CH22_HUB_VISUEL.md) | 2 | 1147 | 4 sept 2026 | `staging` |
| CH23 | Feu de camp — **recon VFX**, aucune implémentation finale : viabilité de `GPUParticles3D` sous `gl_compatibility` prouvée (2 078 px contre 0 sur frame vide et 980 pour le contrôle CPU), glow mesuré disponible (1 809 px de halo à albédo 1,0, 5 043 à 4,0) mais coûtant une passe plein écran que le hub n'a pas, émission sur unlit re-mesurée **inerte** (0,5451 des deux côtés), dégagement de 3,521 u autour de (19,9 ; 25,4) par enveloppe convexe des huit coins transformés de 452 pièces, coût flamme seule **+56 / +56 / +2** primitives et **+0 à la pire frame par frustum culling** — trois candidats étiquetés livrés sur `staging` pour arbitrage device | [CH23_FEU_VFX.md](CH23_FEU_VFX.md) | 1 | 305 | 4 sept 2026 | `staging` |

**Total chantiers : 128 sections, 24 752 lignes.**

⚠️ **CH20 contient DEUX sections écrites rétroactivement par le LOT H**
(LOT A — identification de l'ours par rendu ; LOT F — orientation de l'ours
au repos). Ces deux lots existaient en code sur `staging` mais n'avaient
jamais reçu de section. Elles sont reconstituées **depuis le message de
commit et le diff réel**, pas depuis un souvenir, et chacune le déclare en
tête pour qu'un futur lecteur sache d'où elle vient.

## Archive

Chantiers **clos, sans objet ou historiques**. Déplacés intégralement,
**jamais condensés** : une approche abandonnée garde sa mesure, parce que
c'est la mesure qui explique pourquoi elle a été abandonnée — et c'est ce
qui évite de la refaire.

| Fichier | Sections | Lignes | Période | Contenu |
|---|---|---|---|---|
| [ARCHIVE/A01_MODE_SOMBRE_ET_F10.md](ARCHIVE/A01_MODE_SOMBRE_ET_F10.md) | 2 | 286 | 9 → 11 août 2026 | le mode sombre par inversion plein écran, **supprimé** par la refonte marécage ; et les deux décisions de teinte F10 qu'elle a rendues **sans objet** |
| [ARCHIVE/A02_CLASSEMENT_PWA_CLOS.md](ARCHIVE/A02_CLASSEMENT_PWA_CLOS.md) | 2 | 235 | 15 → 16 août 2026 | l'enquête `accept_gzip` sur le classement en PWA — **close**, validée device des deux côtés, diagnostic retiré |
| [ARCHIVE/A03_INCIDENTS_INFRA_RESOLUS.md](ARCHIVE/A03_INCIDENTS_INFRA_RESOLUS.md) | 2 | 174 | 8 août 2026 | `vercel alias set` « Not able to load user » (scope de token), et le blocage GitHub Actions transitoire |
| [ARCHIVE/A04_AUTH_IMPASSES.md](ARCHIVE/A04_AUTH_IMPASSES.md) | 2 | 288 | 17 août 2026 | `signInWithRedirect` puis `signInWithPopup` — les **deux impasses** Safari iOS, avec leurs mesures, avant le proxy `/__/auth/*` |
| [ARCHIVE/A05_RECONS_SANS_SUITE.md](ARCHIVE/A05_RECONS_SANS_SUITE.md) | 8 | 1768 | 25 → 27 août 2026 | recons pures n'ayant produit **aucun code**, et lots **arrêtés en recon** sur un seuil franchi (lot D plateau 35, water-walk, spawn-lake, waterline, lake-move) |

**Total archive : 16 sections, 2 751 lignes.**

## Comptabilité de non-perte (LOT H)

| | lignes |
|---|---|
| `CLAUDE.md` d'origine (hors titre + ligne vide) | **26 321** |
| dont section de doctrine conservée dans `CLAUDE.md` | 56 |
| dont réparties dans les 20 fichiers de chantier | 23 544 |
| dont réparties dans les 5 fichiers d'archive | 2 721 |
| **somme** | **26 321** ✅ |

Vérifié **byte à byte** : les 133 sections ont été réassemblées dans leur
ordre d'origine depuis les fichiers générés et comparées au fichier source —
identiques, ordre compris. Aucune section n'apparaît deux fois, aucune ne
manque.

Le total actuel des fichiers de `docs/lots/` (**26 581** lignes) dépasse les
26 321 d'origine de **260 lignes**, et le compte tombe juste à la ligne près :

| | lignes |
|---|---|
| contenu verbatim déplacé dans `docs/lots/` | +26 265 |
| 25 en-têtes de six lignes (un par fichier) | +150 |
| section LOT A écrite par le LOT H | +71 |
| section LOT F écrite par le LOT H | +94 |
| ligne vide de jointure au splice de `CH20_OURS.md` | +1 |
| **total** | **26 581** ✅ |

Les 56 lignes restantes des 26 321 d'origine sont la section de doctrine,
**conservée dans `CLAUDE.md`** et donc absente de `docs/lots/` :
26 265 + 56 = 26 321.
