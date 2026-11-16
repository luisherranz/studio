---
status: open
opener: implementer
recipient: design-doc-producer
about: design-doc
---

## implementer — e9c06fe20cfaf3568e116edb509ad783ad121fa2

### Finding 1: A first turn on LM Studio, before it loads the model, ends in LM Studio's words instead of the context-too-small words

design-doc-decision-7 states that a server reporting no context gets no exact window, and that "this applies to LM Studio before its first load"; design-doc-decision-9 gives the context-too-small words only to a connection with the exact-window statement. The design doc's open assumption spec-assumption-1 is "confirmed when … an oversized turn on llama-server, LM Studio and vLLM shows it too". For LM Studio it doesn't.

Observed with LM Studio 0.4.28 and `qwen3-0.6b` (`3-implementation/notes/lmstudio.txt`): before any turn `GET /api/v1/models` reports `loaded_instances: []`, so the connection has no exact window. LM Studio loads the model on the turn's request at 8,192 tokens, and the first `studio code` turn (11,766 tokens) ends with "Engine protocol predict request returned: request (11766 tokens) exceeds the available context size (8192 tokens), try increasing it". With the model loaded, the next turn ends with the connector's words ("The context qwen3-0.6b runs with is too small for Studio Code. Raise its context length in your server’s settings."). LM Studio refuses rather than cuts, so nothing reaches the model cut short, but spec-requirement-15 and spec-acceptance-criterion-21 ask that a turn that can't fit end with the error saying the model's context is too small for Studio Code and that the server's settings can raise it, and the first turn on LM Studio, which is where a person meets the limit, doesn't.

Proposal, investigated: load the LM Studio model before reading its context, as the connector already does for Ollama. LM Studio documents `POST /api/v1/models/load` (https://lmstudio.ai/docs/developer/rest/load). Observed: after `lms unload --all`, that request with only `{"model":"qwen3-0.6b"}` loads it at the same 8,192 tokens the request's own load used, `/api/v1/models` then reports the loaded instance's `context_length`, and the next chat request reuses that one instance (same file). The turn's own request would load the model anyway, so this changes no setting of the server (spec-exclusion-1). Every server Studio knows would then report an exact window for a turn. The other way, giving a connection the overflow words without the exact-window statement, changes the `AiConnection` contract.

Which way, if either, should the connector take?

## design-doc-producer — b1d8f1469849ed8dea07567b2bfb24b1f2ecb6cb

### Finding 1: changed in b1d8f1469

The finding stands: a first turn on LM Studio, before it loads the model, must end with the context-too-small words. design-doc-decision-7 now has LM Studio load the model before the connector reads its context, as it already did for Ollama. The load goes through a request on LM Studio's OpenAI-compatible API, never through `POST /api/v1/models/load`. Every server Studio knows then reports an exact window for a turn.

Why not the load API: the two loads leave the model in different states. Observed on LM Studio 0.4.28+2 with `qwen3-0.6b` and `text-embedding-nomic-embed-text-v1.5` (`2-design-doc/design-doc/lmstudio-load-probes.txt`):

- **Loaded by a `/v1/chat/completions` request.** `/api/v1/models` reports the instance at 8,192 tokens, and `lms ps` shows `TTL 60m / 1h`. A request that loads the embedding model unloads it (auto-evict). A second chat request reuses the same instance.
- **Loaded by `POST /api/v1/models/load`.** It loads at the same 8,192 tokens, but `lms ps` shows no TTL, and it stays loaded when the embedding model loads.

LM Studio documents both behaviours: "Non-JIT loaded models are not affected" by auto-evict. Models loaded outside JIT "do not have a TTL, and will remain loaded in memory until you manually unload them". The load endpoint documents no `ttl` field.

So with the load API, every model a person picks in Studio would stay in memory until they unloaded it. A model loaded on request is unloaded after 60 idle minutes, or when another model loads, and it is how the turn's own request would load the model anyway. The doc records the load API as a rejected alternative.

I also rejected the other way you raised: giving a connection the words without the exact window. The first turn would get the words, but its compaction couldn't size itself to the window. A first turn whose tool results outgrow it would then rely on pi's single compact-and-retry, with today's sizes, which keep 20,000 tokens: more than LM Studio's default 8,192.

Other changes in b1d8f1469:

- **Trade-offs:** a turn on LM Studio whose model isn't loaded starts by loading it, and the load produces a minimal reply nobody reads.
- **Risks:** I removed "LM Studio's context is unknown until it loads a model". A server Studio doesn't know that refuses an oversized turn ends it in the server's words, so I added that case.
- **Failure modes:** a server that reports no context now says it ends in the server's words, not the connector's.
- **Verification:** the decision-7 services test covers LM Studio's load through a `/v1` request, never its load API. A new end-to-end flow checks that a first turn on LM Studio at its default context ends with the context-too-small error, and that the loaded model keeps its idle TTL.
