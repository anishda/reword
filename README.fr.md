# reword

[🇬🇧 English](README.md) · 🇫🇷 Français

Outil en ligne de commande qui réécrit du texte avec le **modèle Apple Intelligence local** (FoundationModels). Rien ne quitte votre Mac. Il lit stdin et écrit le résultat sur stdout, donc il s'intègre à n'importe quel outil de raccourcis : un raccourci clavier Hammerspoon sur le Mac, ou un Raccourci iPhone via SSH.

## Prérequis

- macOS 26 ou plus récent, sur un Mac avec Apple Intelligence activé et son modèle téléchargé
- Toolchain Swift 6.2 (Xcode 26)
- Optionnel : [Hammerspoon](https://www.hammerspoon.org) pour les raccourcis globaux

## Installation

```bash
git clone https://github.com/anishda/reword.git
cd reword
make install        # build release, copié dans ~/.local/bin/reword
reword --check      # {"available": true} quand le modèle est prêt
```

Vérifiez que `~/.local/bin` est dans votre `PATH`. Utilisez `PREFIX=/usr/local make install` pour installer ailleurs. `make test` lance les tests unitaires.

## Utilisation

```bash
echo "je sui content de te voir" | reword fix
# -> Je suis content de te voir
pbpaste | reword formal | pbcopy
```

| Mode | Effet |
|---|---|
| `fix` | Orthographe, grammaire, ponctuation. Changements minimaux, même ton. |
| `rephrase` | Formulation différente et plus claire. Même sens, même ton, même longueur. |
| `shorten` | Environ 40 % plus court (entrée limitée à 4000 caractères). |
| `formal` | Registre professionnel et poli (utilise le « vous » en français). |
| `translate` | Français vers anglais, tout le reste vers le français. |
| `translate-en` / `translate-fr` | Force la langue cible. |

Options : `--timeout N` (secondes, 20 par défaut), `--strict`, `--debug` (durées sur stderr). `reword --list-modes` affiche les modes disponibles.

Les textes longs sont découpés en morceaux puis réassemblés. La sortie est vérifiée (ratio de longueur) et nettoyée des préambules, guillemets et blocs de code ; une sortie inutilisable fait échouer la commande au lieu de remplacer votre texte.

Codes de sortie : `0` ok, `2` usage, `3` entrée vide, `10` modèle indisponible, `11` langue non prise en charge, `12` bloqué par les garde-fous d'Apple, `13` texte trop long pour le mode, `14` délai dépassé, `15` erreur de génération, `16` sortie inutilisable.

### Prompts personnalisés

```bash
mkdir -p ~/.config/reword
reword --dump-modes > ~/.config/reword/modes.json
```

Modifiez le fichier pour changer les prompts, la température ou les ratios de longueur. Les entrées de même nom remplacent les modes intégrés ; les nouveaux noms ajoutent des modes.

## Raccourcis Hammerspoon

```bash
cp hammerspoon/reword.lua ~/.hammerspoon/
echo 'require("reword")' >> ~/.hammerspoon/init.lua
```

Rechargez la configuration Hammerspoon, sélectionnez du texte dans n'importe quelle app, puis appuyez sur :

| Raccourci | Action |
|---|---|
| ⌃⌥F | fix |
| ⌃⌥R | rephrase |
| ⌃⌥S | shorten |
| ⌃⌥T | formal |
| ⌃⌥E | translate |
| ⌃⌥Z | annuler le dernier remplacement |
| ⌃⌥Espace | choisir un mode dans une liste |

Le script copie la sélection, lance `reword`, colle le résultat et restaure votre presse-papiers. Modifiez `BINDINGS`, `hyper` et `TIMEOUT` en haut du fichier pour personnaliser. Hammerspoon a besoin de l'autorisation Accessibilité. Lancez `hs.settings.set("reword.debug", true)` dans la console Hammerspoon pour journaliser dans `/tmp/reword-hs.log` (le journal contient votre texte).

## Raccourci iPhone (SSH via Tailscale)

Le modèle tourne sur votre Mac : un iPhone peut donc l'utiliser en exécutant `reword` via SSH. Avec [Tailscale](https://tailscale.com) sur les deux appareils, le Mac est joignable par son nom MagicDNS depuis n'importe où.

1. Sur le Mac, activez *Réglages Système → Général → Partage → Session à distance*. Générez une clé SSH dédiée sur l'iPhone (dans l'action SSH de Raccourcis ou une app SSH) et ajoutez sa clé publique à `~/.ssh/authorized_keys`.
2. Sur l'iPhone, créez un Raccourci :
   - *Obtenir le contenu du presse-papiers* (ou *Recevoir du texte depuis la feuille de partage*)
   - *Exécuter le script via SSH* : hôte `<votre-mac>.<votre-tailnet>.ts.net`, utilisateur `<votre-nom-d-utilisateur-mac>`, la clé de l'étape 1, script `~/.local/bin/reword fix` (ou un autre mode), entrée *Entrée du raccourci*
   - *Copier dans le presse-papiers* (ou *Afficher le résultat*)
3. Ajoutez le Raccourci à la feuille de partage ou au bouton Action.

Utilisez le chemin complet de `reword`, car un shell SSH non interactif peut ne pas avoir `~/.local/bin` dans son `PATH`. Gardez le Mac éveillé et joignable sur le tailnet. Astuce : restreignez la clé dans `authorized_keys` avec `no-pty,no-port-forwarding,no-agent-forwarding` et, si un seul mode vous suffit, une `command="/Users/<vous>/.local/bin/reword fix"` forcée.

Cette configuration SSH n'est pas couverte par les tests : vérifiez que `reword --check` réussit depuis une session SSH sur votre Mac avant de vous y fier.

## Notes

- Tout s'exécute en local : pas d'accès réseau, pas de télémétrie.
- La prise en charge des langues dépend de celles du modèle local d'Apple (`reword` sort avec le code `11` sinon).
- Les prompts intégrés sont en anglais ; les notifications du script Hammerspoon sont en français.

## Licence

[MIT](LICENSE)
