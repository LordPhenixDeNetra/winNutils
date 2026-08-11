# ViderCorbeille

Un utilitaire simple pour vider la corbeille Windows, en script Python ou en exécutable autonome.

## Contenu du projet

- **`vider_corbeille.py`** : Script Python source
- **`dist/ViderCorbeille.exe`** : Exécutable Windows autonome (ne nécessite pas Python)

## Prérequis

- **Pour utiliser l'exécutable** : Windows 10/11 uniquement (aucune dépendance)
- **Pour utiliser/modifier le script** : Python 3.10+

## Utilisation rapide

### Option 1 : Exécutable (recommandé pour une utilisation simple)

Double-cliquez sur `dist/ViderCorbeille.exe` ou lancez-le en ligne de commande :

```cmd
dist\ViderCorbeille.exe
```

### Option 2 : Script Python

```cmd
python vider_corbeille.py
```

## Fonctionnalités

- Confirmation interactive avant vidage
- Affichage de la barre de progression Windows standard
- Lecture du son système de vidage de la corbeille
- Codes de retour explicites (0 = succès, 1 = échec)

## Utilisation en tant que module

```python
from vider_corbeille import vider_corbeille

# Vider sans confirmation ni interface
succes = vider_corbeille(confirmer=False, afficher_progression=False, son=False)

if succes:
    print("Corbeille vidée")
```

### Paramètres de `vider_corbeille()`

| Paramètre             | Type | Valeur par défaut | Description                                          |
|-----------------------|------|-------------------|----------------------------------------------------|
| `confirmer`           | bool | `False`           | Afficher une boîte de dialogue de confirmation Windows  |
| `afficher_progression`| bool | `True`            | Afficher la barre de progression Windows          |
| `son`                 | bool | `True`            | Jouer le son système du vidage de la corbeille    |

**Valeur de retour : `True` en cas de succès, `False` sinon.

## Recompiler l'exécutable

Si vous modifiez le script et souhaitez régénérer l'exécutable :

```cmd
pip install pyinstaller
python -m PyInstaller --onefile --clean --name ViderCorbeille vider_corbeille.py
```

L'exécutable se trouvera dans le dossier `dist/`.

## Fonctionnement interne

Le script utilise l'API Windows native `SHEmptyRecycleBinW` via `ctypes` (aucune dépendance externe). Les drapeaux utilisés :

| Constante               | Valeur | Effet                                            |
|---------------------------|--------|--------------------------------------------------|
| `SHERB_NOCONFIRMATION`   | 0x0001 | Supprime la boîte de confirmation Windows              |
| `SHERB_NOPROGRESSUI`    | 0x0002 | Supprime la barre de progression               |
| `SHERB_NOSOUND`          | 0x0004 | Supprime le son du vidage                     |

## Licence

Projet libre d'usage personnel.
