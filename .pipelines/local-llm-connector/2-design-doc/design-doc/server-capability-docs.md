# What LM Studio, llama-server and vLLM report about a model's context and images (read 2026-11-16)

Each line gives the fact, where it was read, and a short verbatim quote. Nothing here was run: none of the three servers is installed on this machine. Ollama was probed instead (`ollama-context-probes.txt`).

## llama.cpp `llama-server` (master)

- Running context: `GET /props` → `default_generation_settings.n_ctx`, and `GET /v1/models` → `data[0].meta.n_ctx` (slot context) next to `n_ctx_train` (trained maximum). Source: https://github.com/ggml-org/llama.cpp/blob/master/tools/server/server-context.cpp — `{"n_ctx", meta.slot_n_ctx}`. The README's `/v1/models` example predates `n_ctx` and shows only `n_ctx_train`.
- Images: `GET /v1/models` → `data[].architecture.input_modalities`. README (checked here: `tools/server/README.md`, "GET `/v1/models`"): "`input_modalities` lists what the model can read. It always has `text`, plus each media type that the model supports." `GET /props` → `modalities.vision` (server-context.cpp: `{"vision", meta.has_inp_image}`).
- `/v1/models` "can be `null` (for example, while the model is still loading)" for `meta` (README).
- A request longer than the context: HTTP 400, type `exceed_context_size_error`, message `request (%d tokens) exceeds the available context size (%d tokens), try increasing it` (server-common.cpp, server-context.cpp).
- Missing or wrong key with `--api-key`: HTTP 401 `{"error":{"message":"Invalid API Key","type":"authentication_error","code":401}}`; only `/health`, `/v1/health` and UI assets are public, so `/v1/models` and `/props` need the key (server-http.cpp). 403 is CORS: "Cross-origin request not allowed (see --cors-origins)".

## vLLM (main)

- Running context: `GET /v1/models` → `data[].max_model_len`. Checked here in `vllm/entrypoints/serve/engine/protocol.py`: `class ModelCard` has `max_model_len: int | None = None`. CLI docs (https://docs.vllm.ai/en/latest/cli/serve/): "Model context length (prompt and output). If unspecified, will be automatically derived from the model config." The model is fixed at startup, with no load step.
- Images: not reported. `ModelCard` has only `id, object, created, owned_by, root, parent, max_model_len, permission` (checked here).
- A request longer than the context: HTTP 400 `BadRequestError`, message starting `This model's maximum context length is ` (vllm/renderers/params.py).
- Missing or wrong key: HTTP 401 `{"error": "Unauthorized"}` (vllm/entrypoints/serve/middleware/authenticate.py); "this only authenticates endpoints under the `/v1`, `/v2`, `/inference`, and `/cohere` path prefixes" (cli/serve docs).

## LM Studio (closed source; docs only)

- Running context: `GET /api/v1/models` → `models[].loaded_instances[].config.context_length` — https://lmstudio.ai/docs/developer/rest/list: "The maximum context length for the model in number of tokens." `loaded_instances` is empty while the model isn't loaded (docs example `"loaded_instances": []`). The v0 API documents only `max_context_length` and `state`.
- Images: `GET /api/v1/models` → `capabilities.vision` — same page: "Whether the model supports vision/image inputs." v0: `"type": "vlm"` (https://lmstudio.ai/docs/developer/rest/endpoints).
- What `/v1/models` lists: "Returns the models visible to the server." (https://lmstudio.ai/docs/developer/openai-compat/models); with Just-In-Time loading on by default, "the list may include all downloaded models" (spec `server-docs.md`).
- A request longer than the context: not documented. Community reports show HTTP 400 on `/v1/chat/completions` with "…greater than the context length" / "the model is loaded with context length of only 4096 tokens, which is not enough" (https://github.com/lmstudio-ai/lmstudio-bug-tracker/issues/237). pi's overflow patterns already match "greater than the context length" (`node_modules/@earendil-works/pi-ai/dist/utils/overflow.js`).
- Missing or wrong key: status not documented; community reports show HTTP 401 ("Malformed LM Studio API token provided").

## Not confirmed

- LM Studio's loaded context before the model loads (JIT loads it on the first request).
- Whether a vLLM model reads images, by any endpoint.
- LM Studio's overflow status and body, and its key-refusal status, from its own docs.
