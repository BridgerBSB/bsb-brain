import sys
from pathlib import Path

# Make `kb` importable when pytest is run from _pipeline/ or from the vault root.
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
