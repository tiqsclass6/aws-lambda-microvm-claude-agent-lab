from pathlib import Path

root = Path(__file__).resolve().parents[1]
(root / "build").mkdir(parents=True, exist_ok=True)
(root / "build" / "launcher-package").mkdir(parents=True, exist_ok=True)
