# Gorilla / Fieldnotes

Archive technique francophone à accès restreint. Identité visuelle sombre et sobre, emblème gorille original, pages de ressources Linux, Pentest, OPSEC, GEOINT et OSINT.

> Important : cette archive contient encore le jeu initial de ressources sélectionnées. Elle ne correspond PAS encore à une copie exacte des cinq pages de référence. Consulte `REFERENCE-PARITY.md` et utilise `DEVIN-SWE2-HIGH-PROMPT.md` pour terminer l'audit de parité. La page de référence Pentest demande une connexion; ne contourne pas cette barrière et n'invente pas son contenu.

## Architecture

- `index.html` — index de l'archive, protégé côté edge
- `pages/*.html` — cinq répertoires informatifs, protégés côté edge
- `login.html` — formulaire public de clé d'accès
- `assets/` — style, interactions, et emblème gorille
- `netlify/edge-functions/access-gate.js` — protection et session signée côté serveur Edge
- `tests/access-gate.test.mjs` — tests d'authentification Node natifs
- `netlify.toml` — configuration de publication et de l'Edge Function

## Authentification par clé d'accès

Le système actuel utilise une **clé partagée**. Ce n'est pas un système de comptes individuels et il ne permet pas d'identifier séparément les utilisateurs. La clé n'est jamais livrée au navigateur ni enregistrée dans `localStorage`. La fonction Edge valide la clé côté serveur, puis crée un cookie signé limité dans le temps. Le cookie est `HttpOnly`, `SameSite=Strict` et, en production HTTPS, utilise le préfixe `__Host-` avec `Secure` et `Path=/`.

La fonction échoue en mode fermé : sans secrets valides, les pages restent bloquées. Les ressources HTML sont protégées au niveau Edge; ce n'est pas une simple vérification JavaScript exécutée dans le navigateur. Les sessions sont stateless : la déconnexion efface le cookie du navigateur, mais une copie volée d'un cookie signé resterait valide jusqu'à son expiration. En cas d'incident, fais tourner `SESSION_SECRET` et redéploie pour invalider toutes les sessions en cours.

### Configurer Netlify

1. Déploie le projet via un dépôt Git connecté à Netlify ou via la Netlify CLI. Le simple glisser-déposer de fichiers statiques ne permet pas de considérer la fonction Edge comme configurée et testée.
2. Génère une clé d'accès imprévisible et conserve-la hors du dépôt. Exemple sur macOS/Linux/WSL/Git Bash :

   ```sh
   umask 077
   openssl rand -hex 32 > /chemin/prive/access-key.txt
   ```

   Garde ce fichier privé : son contenu est la clé que les visiteurs autorisés saisiront. Ne le place pas dans le dossier du site ni dans Git.
3. Calcule son SHA-256 sans retour de ligne (remplace le chemin par le fichier local où tu as conservé la clé) :

   ```sh
   printf '%s' "$(cat /chemin/prive/access-key.txt)" | openssl dgst -sha256
   ```

   Dans le résultat, copie uniquement les 64 caractères hexadécimaux après `=`.
4. Dans Netlify, ouvre **Project configuration → Environment variables** et ajoute :
   - `ACCESS_KEY_SHA256` — le hash SHA-256 de la clé d'accès
   - `SESSION_SECRET` — un secret indépendant généré avec `openssl rand -hex 32`
5. Assure-toi que les variables sont disponibles aux Edge Functions/Functions, puis lance un nouveau déploiement. Les variables ne doivent **pas** être ajoutées à `netlify.toml`, aux fichiers du dépôt, au JavaScript client ou aux journaux.
6. Teste le comportement avec une mauvaise clé, une bonne clé, l'accès direct aux URL de pages, la déconnexion, et un déploiement où les variables sont absentes. Ce dernier cas doit rester verrouillé.
7. Configure si possible une règle de limitation de débit/WAF sur `POST /__auth/login` dans les réglages de sécurité Netlify. La clé partagée devrait toujours être aléatoire et longue. La limitation côté fournisseur est importante : le code Edge sans stockage distribué ne peut pas garantir à lui seul un verrouillage global des tentatives par IP.

Ne réutilise pas une vraie clé dans les tests; `tests/access-gate.test.mjs` utilise des valeurs fictives.

## Développement et tests

Prérequis : Node.js récent et Netlify CLI pour tester le comportement Edge localement. Pour tester uniquement la syntaxe et l'authentification simulée :

```sh
npm test
```

Pour tester l'intégration Edge avec Netlify CLI après son installation :

```sh
npx netlify-cli dev
```

N'utilise pas un simple serveur statique Python pour valider la sécurité : il ne lancera pas l'Edge Function, donc il ne testera pas la barrière d'accès.

## Build et déploiement

Le build `npm run build` copie seulement les fichiers destinés à être servis dans `dist/`; il ne publie pas les notes de développement, les tests ou le code source de la fonction Edge comme pages statiques. Netlify utilise `netlify.toml` à la racine pour lancer ce build et charger la fonction depuis `netlify/edge-functions/`.

Cette version n'est plus une simple publication statique : la barrière doit s'exécuter à l'Edge. Connecte le dépôt Git dans Netlify ou utilise la Netlify CLI. Un simple glisser-déposer statique n'est pas suffisant pour prétendre que l'authentification Edge fonctionne. Après avoir changé les variables d'environnement, redéploie le site.

## État de parité du contenu

Le nombre et les catégories de ressources n'ont pas encore été synchronisés exactement avec les pages de référence. Voir `REFERENCE-PARITY.md`; aucune copie exacte ne doit être revendiquée avant le diff automatisé de l'inventaire source.
