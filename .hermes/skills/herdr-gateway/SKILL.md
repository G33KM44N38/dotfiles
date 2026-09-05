---
name: herdr-gateway
description: Piloter Herdr depuis la passerelle Hermes indépendante.
---

# Herdr depuis Hermes

Compétence personnelle pour les demandes de Kylian concernant Herdr, ses espaces, ses agents et le travail de programmation. Hermes tourne comme service launchd indépendant sur ce Mac. Kylian autorise cette intégration extérieure à Herdr. L'absence de HERDR_ENV est normale et ne bloque pas ce mode.

## Connexion et cibles

La session autorisée est la session locale par défaut, socket `/Users/boss/.config/herdr/herdr.sock`, CLI `/opt/homebrew/bin/herdr`. Chaque commande de contrôle doit fixer ce socket :

```bash
HERDR_SOCKET_PATH=/Users/boss/.config/herdr/herdr.sock /opt/homebrew/bin/herdr workspace list
HERDR_SOCKET_PATH=/Users/boss/.config/herdr/herdr.sock /opt/homebrew/bin/herdr agent list
```

Ne pas ajouter `--session` à ces commandes : ce paramètre prendrait priorité sur le socket. Ne pas inventer HERDR_ENV, HERDR_PANE_ID ou un contexte de panneau. Si le socket ne répond pas, signaler que Herdr est indisponible ; Hermes et Telegram restent utilisables. Ne pas démarrer, arrêter ou changer de session implicitement.

La compétence imprimée par `herdr --skill` décrit les agents exécutés DANS un panneau. Sa condition HERDR_ENV=1 ne s'applique pas à cette intégration extérieure explicitement autorisée. Utiliser cette compétence et les aides CLI pour ce mode.

Découvrir les identifiants dans les réponses JSON. Cibler explicitement l'espace, l'onglet et le panneau concernés par la demande, ou un nom d'agent unique vérifié. Ne pas utiliser `--current` ni les cibles implicites fondées sur le focus de l'interface. Si la demande ne permet pas de choisir entre plusieurs cibles, demander laquelle.

## Travail courant

Lire l'aide du groupe concerné avant une commande inconnue. Préfixer aussi les commandes ci-dessous avec le socket explicite :

```text
herdr tab list --workspace <workspace_id>
herdr pane list --workspace <workspace_id>
herdr agent read <pane_id> --source recent-unwrapped --lines 80
herdr agent prompt <pane_id> "<demande autorisée>"
```

Lire l'état et la sortie de l'agent avant de lui envoyer du travail. Ne pas répondre automatiquement à un écran d'approbation. Utiliser `--no-focus` pour les créations en arrière-plan. Dans un espace avec les onglets editor/agent/process/terminal, les agents vont dans l'onglet agent. Ne pas interrompre ni remplacer un processus existant sans demande.

Pour un lancement de Codex demandé, sélectionner d'abord un panneau shell disponible dans l'onglet agent. Utiliser `herdr agent start <nom-unique> --kind codex --pane <pane_id> -- <arguments>`, puis publier le même nom avec `herdr pane report-metadata <pane_id> --source boss:codex-launch-title --agent codex --title <nom-unique>`. Si un lancement non interactif est nécessaire, utiliser `/Users/boss/.dotfiles/bin/herdr-run-codex-agent --task-name <nom> -- <arguments codex exec>` dans le panneau ; pas de lancement brut de `codex exec`.

Conserver le focus, les travaux et les branches existantes. Utiliser un worktree approprié pour les changements de code sans changer la branche du travail humain. Ne pas fermer de panneau/espace ni arrêter le serveur sauf demande explicite. L'autorisation d'utiliser Herdr ne vaut pas autorisation de publier, envoyer des messages externes ou exécuter des actions destructrices.

## Durée de vie

Garder la passerelle Hermes sous launchd. Ne pas demander de la relancer dans un panneau pour résoudre un accès Herdr. Détacher l'interface Herdr conserve son serveur et ses agents ; arrêter le serveur coupe ses panneaux, mais pas ce service Hermes.
