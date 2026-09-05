"""Vault paths. Everything is relative to the vault root so tests can point
at a temp vault by passing `root`."""
from pathlib import Path

PIPELINE_DIR = Path(__file__).resolve().parents[1]
DEFAULT_VAULT = PIPELINE_DIR.parent


class VaultPaths:
    def __init__(self, root: Path | None = None):
        self.root = Path(root) if root else DEFAULT_VAULT
        self.pipeline = self.root / "_pipeline"
        self.state = self.pipeline / "state.json"
        self.sources_yml = self.pipeline / "sources.yml"
        self.taxonomy = self.pipeline / "taxonomy.md"
        self.prompts = self.pipeline / "prompts"
        self.examples = self.pipeline / "examples"
        self.log = self.pipeline / "log.md"
        self.failed = self.pipeline / "failed.md"
        self.review = self.root / "_review"
        self.sources = self.root / "sources"
        self.raw = self.sources / "_raw"
        self.assets = self.sources / "_assets"
        self.cues = self.root / "cues"
        self.concepts = self.root / "concepts"

    def raw_file(self, source: str, item_id: str) -> Path:
        return self.raw / source / f"{item_id}.md"

    def rel(self, p: Path) -> str:
        """Vault-relative POSIX path, the form used inside notes."""
        return Path(p).resolve().relative_to(self.root.resolve()).as_posix()
