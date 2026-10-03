---
type: project
domain: engineering
source: coordinator-app/utils/embeddings.py + utils/agent.py
created: 2026-07-09
feeds: coordinator-notes-app
---

# Coordinator Notes - RAG Pipeline

The AI Insights agent for [[coordinator-notes-app]]: synthesizes patterns across submitted visit notes. An instance of the ideas in [[rag-architectures]].

## Embedding (utils/embeddings.py)
- Model: LOCAL `sentence-transformers` `all-MiniLM-L6-v2`, normalized. Never OpenAI (cost + the open-source rule).
- Related fields are concatenated into richer chunks (CHUNK_GROUPS) rather than embedded per-field, for better retrieval. Each chunk carries `visit_id`, `affiliate_id`, `coordinator_id`, `chunk_type`.
- Stored in `visit_embeddings` (pgvector). **Only submitted visits embed; drafts never do.** Re-embedding a visit deletes its prior chunks first (dedup).
- 2026-07-09: added an `opp_org_observation` chunk group (org name + how-they-operate + opposing-staff standout) so cross-org questions retrieve.

## Retrieval + agent (utils/agent.py)
- `similarity_search` via the `match_visit_chunks` RPC, `match_count=12`, **`match_threshold=0.2`** (low on purpose to keep recall up on a small dataset).
- Query expansion: short affiliate aliases (DSL, FCL, AAA...) expanded before embedding since dense vectors underweight short tokens.
- Agent: Claude Haiku 4.5. System prompt loads the active coordinator roster, a compact index of every submitted visit, and the current staff roster from the DB on every call (roster/enumeration questions vector search structurally cannot answer). Prefix-cached (ephemeral) when the prefix crosses Haiku's 4096-token minimum.

## Gotcha
If RAG returns nothing: check the `0.2` threshold and confirm the Railway deploy is green before testing. Roster answers come from the system-prompt index, not the retrieved chunks.

## Links
[[coordinator-notes-app]] · [[coordinator-notes-questionnaire]] · [[rag-architectures]] · [[MOC-astros-engineering]]
