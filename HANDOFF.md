# wslp — Handoff

Repo : https://github.com/fluxtendu/wslp
Local : C:\Users\janot\Claude\wslp\
Dernier commit : `379682a`

---

## État actuel

### Ce qui fonctionne (testé et validé)

- `wslp` en ligne de commande (PowerShell / CMD) :
  - Chemins Windows absolus (`C:\foo\bar`)
  - Chemins UNC WSL (`\\wsl.localhost\Ubuntu\...`)
  - Chemin home (`~`)
  - Chemins relatifs (`.`, `.\fichier`) — résolus en absolu
  - Chemin avec backslash final en CMD (`"C:\foo\"`)
  - Sans argument → message d'aide
- Menu contextuel Shift+clic droit (mode classic, HKCU) :
  - Sur les fichiers ✓
  - Sur les dossiers ✓
  - Sur les fonds de dossier ✓ (sauf cas particuliers — voir ci-dessous)

### Ce qui n'a pas encore été retesté après les derniers correctifs

- **Accents dans les noms de fichiers** via menu contextuel — le bug était dans `_wslp.vbs` (ADODB.Stream + BOM). Correctif appliqué (`379682a`) mais pas encore confirmé fonctionnel.
- **Uninstall cmdp** (`~/.local/share/cmdp`) — ne supprimait pas le répertoire. Correctif appliqué (`379682a`) mais pas encore confirmé.
- **Install cmdp** — fonctionnait à la dernière tentative (fichier copié), mais la ligne de source n'est plus injectée automatiquement (comportement voulu). À retester proprement.

### Limitations connues et acceptées

- `wslp g:\` sans guillemets depuis PowerShell → PowerShell mange le `\` final avant d'appeler le script. Comportement natif PS, non corrigeable côté wslp. Contournement : `wslp "g:\"`.
- Clic droit sur les disques durs dans le panneau gauche de l'Explorateur → pas supporté (Windows ne passe pas le chemin de façon standard dans ce contexte).
- Menu contextuel sur le fond d'un dossier → supprimé volontairement (entrée `Directory\Background`) car incohérent et buggé sur les racines de disques.
- `cmdp` non compatible avec fish shell (syntaxe bash/zsh uniquement).

---

## Ce qui reste à faire (tests)

### Phase 2 — Suite et fin

- [ ] **2.5** Retester menu contextuel sur fichier avec accent (`Carte d'identité.pdf`) → doit donner le bon chemin UTF-8
- [ ] **2.6** Retester uninstall : `& "C:\Users\janot\Claude\wslp\scripts\uninstall-registry.ps1"` → `~/.local/share/cmdp` doit disparaître
- [ ] **2.7** Réinstaller cmdp et vérifier le fichier est bien copié dans `~/.local/share/cmdp/cmdp.sh`

### Phase 3 — cmdp dans WSL

- [ ] **3.1** `cmdp /mnt/c/Users/janot` → `C:\Users\janot` + copié dans le presse-papiers
- [ ] **3.2** `cmdp /home/janot` → `\\wsl.localhost\Ubuntu\home\janot`
- [ ] **3.3** `cmdp` sans argument → message d'aide, exit 1
- [ ] **3.4** `cmdp /chemin/inexistant` → message d'erreur

### Phase 4 — Désinstallation complète

- [ ] Lancer `uninstall-registry.ps1`
- [ ] Vérifier menu contextuel disparu
- [ ] Vérifier `~/.local/share/cmdp/` supprimé

### Phase 5 — Cas limites restants

- [ ] `wslp "g:\"` (avec guillemets) → `/mnt/g/`
- [ ] `wslp "C:\Users\janot\OneDrive\Documents\Carte d'identité.pdf"` → accent correct

---

## Ce qui reste à faire (code / publication)

- [ ] **Scoop** : créer la release GitHub `v1.0.0` (tag), calculer le SHA256 du zip, mettre à jour `bucket/wslp.json` avec le vrai hash, supprimer le placeholder `TODO_SHA256_AFTER_RELEASE`
- [ ] **README** : corriger la typo `flxutendu` → `fluxtendu` dans l'exemple UNC (ligne 7)
- [ ] **winget** : prévu dans la roadmap, pas encore commencé

---

## Architecture du projet

```
src/
  wslp.cmd       → point d'entrée CLI (dans le PATH)
  _wslp.ps1      → implémentation PowerShell (interne, ne pas appeler directement)
  _wslp.vbs      → déclencheur silencieux pour le menu contextuel (interne)
scripts/
  install-registry.ps1   → installateur optionnel (menu contextuel + cmdp)
  uninstall-registry.ps1 → désinstallateur
  cmdp.sh                → fonction bash/zsh WSL (à sourcer dans .zshrc/.bashrc)
bucket/
  wslp.json      → manifest Scoop (hash à remplir avant release)
```

## Points techniques importants à retenir

- **Registre** : toutes les opérations passent par `Microsoft.Win32.Registry` (API .NET directe), jamais par le provider PowerShell, à cause de la clé nommée `*` (étoile littérale) qui serait interprétée comme wildcard.
- **Encodage VBS → PS** : le chemin est encodé en base64 UTF-16LE dans `_wslp.vbs` via ADODB.Stream (text mode utf-16le → binary read en skippant les 2 octets de BOM), puis décodé dans `_wslp.ps1` avec `[Text.Encoding]::Unicode.GetString()`.
- **Variables d'env vers WSL** : il faut lister la variable dans `$env:WSLENV` pour qu'elle soit transmise aux processus WSL.
- **wslpath via wsl.exe** : `wsl.exe wslpath -u $path` sans guillemets perd les backslashes. Toujours passer `"$path"` avec guillemets doubles. Sur certains setups wslpath échoue quand même — le fallback manuel (regex `^([A-Za-z]):(.*)` → `/mnt/x/...`) prend le relais.
- **Trailing backslash CMD** : `"C:\foo\"` en CMD → `%~1` donne `C:\foo"` (le `\` escape le `"`). Corrigé par `TrimEnd('"')` dans `_wslp.ps1`.
- **PowerShell + backslash final** : `wslp g:\` sans guillemets → PS interprète `\` comme escape. Comportement natif, non corrigeable.
