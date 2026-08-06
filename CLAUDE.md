# Keepy — CLAUDE.md

## Restitution des rapports de session

Règle permanente, sans exception, pour tout rapport de fin de tâche ou de
batch produit dans ce repo :

1. **Markdown natif, jamais de wrapper 4-backticks.** Le rapport est écrit
   directement comme texte de la réponse — jamais entouré d'un bloc de code
   à 4 backticks (` ``` ` ou ` ```markdown `), et jamais produit via un tool
   call ou un script qui "print" le contenu.
2. **Structure fixe**, dans cet ordre : BRANCH, COMMITS, FILES, BUILD,
   DEPLOY, VALIDATION CHECKLIST, NEXT STEPS, DOCS STATUS.
3. **Pagination en blocs d'~100 lignes si dépassement.** Le contenu n'est
   JAMAIS compressé pour tenir dans un seul bloc. Si le rapport dépasse
   ~100 lignes, le découper en plusieurs blocs Markdown successifs
   (`## Rapport (1/N)`, `(2/N)`, ...), chacun autonome, coupés sur des
   frontières de section.
4. **Vérification avant envoi.** Avant d'envoyer, relire la réponse : si
   elle commence par ``` ``` `` `` ou ``` ```markdown ```, enlever ce
   wrapper et renvoyer en Markdown natif. Confirmer en une ligne à la fin
   qu'on a fait cette vérification.
5. **S'applique à chaque tâche sans exception**, y compris quand on
   redemande une reformulation d'un résultat déjà produit (pas de relance
   de recherche dans ce cas).
