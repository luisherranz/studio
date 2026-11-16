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
