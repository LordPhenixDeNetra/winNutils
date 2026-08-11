import ctypes
import ctypes.wintypes
import sys

SHERB_NOCONFIRMATION = 0x00000001
SHERB_NOPROGRESSUI = 0x00000002
SHERB_NOSOUND = 0x00000004


def vider_corbeille(confirmer=False, afficher_progression=True, son=True):
    """
    Vide la corbeille Windows.

    Paramètres:
        confirmer (bool): Afficher une boîte de confirmation avant de vider.
            Défaut: False (pas de confirmation).
        afficher_progression (bool): Afficher la barre de progression.
            Défaut: True.
        son (bool): Jouer le son de la corbeille vidée.
            Défaut: True.

    Retourne:
        bool: True si l'opération a réussi, False sinon.
    """
    flags = 0
    if not confirmer:
        flags |= SHERB_NOCONFIRMATION
    if not afficher_progression:
        flags |= SHERB_NOPROGRESSUI
    if not son:
        flags |= SHERB_NOSOUND

    try:
        resultat = ctypes.windll.shell32.SHEmptyRecycleBinW(
            ctypes.wintypes.HWND(0),
            None,
            ctypes.wintypes.DWORD(flags),
        )
        if resultat == 0:
            return True
        else:
            print(f"Erreur Windows (code {resultat}): impossible de vider la corbeille.", file=sys.stderr)
            return False
    except OSError as e:
        print(f"Erreur système: {e}", file=sys.stderr)
        return False
    except Exception as e:
        print(f"Erreur inattendue: {e}", file=sys.stderr)
        return False


def main():
    """Point d'entrée principal du script."""
    print("=== Vidage de la corbeille Windows ===")
    print()

    reponse = input("Voulez-vous vraiment vider la corbeille ? (o/N) : ").strip().lower()
    if reponse not in ("o", "oui"):
        print("Opération annulée.")
        return 0

    print("Vidage de la corbeille en cours...")
    succes = vider_corbeille(
        confirmer=False,
        afficher_progression=True,
        son=True,
    )

    if succes:
        print("Corbeille vidée avec succès.")
        return 0
    else:
        print("Échec du vidage de la corbeille.", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
