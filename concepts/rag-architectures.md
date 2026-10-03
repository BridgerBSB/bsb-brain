---
type: concept
domain: ai-engineering
created: 2026-07-03
tags:
  - concept
  - rag
  - agents
  - ai-engineering
source: https://x.com/akshay_pachaar/status/2072767459908796782
---
# RAG Architectures — Standard vs Graph vs Agentic

**Source:** [@akshay_pachaar, Jul 2 2026](https://x.com/akshay_pachaar/status/2072767459908796782)
(fetched via fxtwitter; embedded explainer video not reviewed).

## Companion post — "You're doing RAG wrong" (IdeaBlocks), read in full Jul 3
**Source:** https://x.com/akshay_pachaar/status/2052743644411765230 · Tool = **Blockify**
by Iternal Technologies (open-source + commercial preprocessing layer between document
parsing and vectorization).

- **IdeaBlocks** = question-answer packets with typed governance fields, replacing raw
  text chunks. Core insight: *"The chunk fails because it's structurally agnostic. The
  fix is to make the unit of knowledge structurally explicit."*
- **Numbers:** corpus −40× (2,042 blocks → 1,200 after dedup) · 3× fewer tokens/query ·
  vector relevance 2.3× (cosine distance 0.3624 → 0.1585) · +13.55% accuracy after dedup.
- **7-stage pipeline:** scoping (index hierarchy) → ingestion (docs → draft IdeaBlocks
  via fine-tuned LLMs) → context-aware Q-A chunking → semantic dedup (80–85% similarity
  clustering) → auto-tagging (clearance/version/privacy) → human SME validation →
  export to vector DB (Pinecone/Milvus/Azure AI Search).

### Full-text extras (Zac pasted the complete article, Jul 3)
- **Why chunks fail — the triad:** no idea boundary (splitter cuts on token count →
  half a table, conclusion without argument) · no version state (a dozen near-identical
  copies across SharePoint/Confluence/Git → top-K returns current+deprecated mixed →
  "confidently wrong" blends) · no access metadata (governance ends up bolted onto the
  orchestrator, disconnected from content).
- **Why dedup HELPS retrieval:** 15 near-duplicates = 15 competing vectors in the same
  embedding region; probability mass spreads and the canonical copy's match score drops.
  *"Your vector index isn't a hard drive you want to fill. It's a retrieval surface,
  and redundancy degrades it."*
- **Application-layer wins:** question-shaped index makes matching structural (stop
  tuning similarity thresholds) · governance lives IN the data (different roles get
  different datasets from the same index) · updates propagate from ONE record instead of
  hunting every duplicated passage.
- **The principle:** "the chunk is a parsing convenience that became a retrieval
  assumption" — rerankers/hybrid search/threshold tuning are all downstream patches;
  fix the unit. RAG stacks are growing a **distillation layer** between parsing and
  vectorization "the way web stacks grew a CDN layer." Buildable yourself with
  clustering + LLM summarization + schema enforcement; Blockify is open-source.

## The three architectures (solutions for DIFFERENT query patterns, not tiers)

| Architecture | How it retrieves | Right for | Fails at |
|---|---|---|---|
| **Standard RAG** | embed query → nearest chunks → stuff context | simple single-fact lookups | multi-hop questions ("what did X say about Y's effect on Z") |
| **Graph RAG** | knowledge graph of entities+relationships; walk edges | relationship/multi-hop queries | build/maintenance cost of the graph |
| **Agentic RAG** | LLM agent dynamically picks tools/sources per query | heterogeneous corpora, mixed query types | latency + cost; needs good tool descriptions |

Author's core point: pick by **query pattern**, don't ladder-climb.

## Takeaways for us (the BSB Brain / council system)

- Our vault-retrieval today is effectively **Agentic RAG already**: agents grep/read
  specific notes (retrieval-first per [[council-knowledge-base]]) rather than embedding
  chunks — the "agent picks its source" pattern. Named validation for the design.
- Our `[[wikilinks]]` graph IS a lightweight knowledge graph — Graph-RAG-style multi-hop
  ("which rule spawned which incident") works by link-walking, no infra needed.
- **IdeaBlocks maps to what we already do instinctively**: one-fact memory files +
  one-line index entries ARE Q-A-shaped blocks, not raw chunks. The 40×/2.3× numbers
  justify keeping notes atomic instead of dumping transcripts.
- If we ever embed the vault (e.g. Astro World search, coordinator-notes RAG), start
  Standard on atomic notes, NOT chunked long docs.

Related: [[council-knowledge-base]] · [[loop-engineering]] · [[claude-code-obsidian]] ·
[[fable5-use-cases]]
