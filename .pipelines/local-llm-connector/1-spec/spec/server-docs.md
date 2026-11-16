# What local LLM servers document (read 2026-11-16)

Each line: the fact, the page it was read on, and a verbatim quote.

## Ollama

- OpenAI-compatible base URL with `/v1`, key ignored. https://docs.ollama.com/api/openai-compatibility — `base_url='http://localhost:11434/v1/',` and `api_key='ollama',  # required but ignored`
- Binds to `127.0.0.1:11434` by default. https://docs.ollama.com/faq — "Ollama binds 127.0.0.1 port 11434 by default."
- Default context depends on VRAM. https://docs.ollama.com/context-length — "Ollama defaults to the following context lengths based on VRAM: < 24 GiB VRAM: 4k context; 24-48 GiB VRAM: 32k context; >= 48 GiB VRAM: 256k context", and "Tasks which require large context like web search, agents, and coding tools should be set to at least 64000 tokens."
- The OpenAI API can't set the context size. https://docs.ollama.com/api/openai-compatibility — "The OpenAI API does not have a way of setting the context size for a model"; a Modelfile with `PARAMETER num_ctx` (a new, named model) is the way.
- Browser origins. https://docs.ollama.com/faq — "Ollama allows cross-origin requests from `127.0.0.1` and `0.0.0.0` by default. Additional origins can be configured with `OLLAMA_ORIGINS`."
- No key on the local API. https://docs.ollama.com/api/authentication — "The local API at `http://localhost:11434` does not require authentication."

## LM Studio

- Base URL with `/v1`. https://lmstudio.ai/docs/developer/openai-compat — `base_url="http://localhost:1234/v1"`; "The following examples assume the server port is `1234`".
- The person starts the server. https://lmstudio.ai/docs/cli/serve/server-start — `lms server start`; "Port to run the server on. If not provided, uses the last used port".
- Optional key. https://lmstudio.ai/docs/developer/core/authentication — "By default, LM Studio does not require authentication for API requests. To enable authentication so that only requests with a valid API Token are accepted, toggle the switch in the Developers Page > Server Settings."; client sends `-H "Authorization: Bearer $LM_API_TOKEN"`.
- Browser origins. https://lmstudio.ai/docs/cli/serve/server-start — "--cors (optional) : flag. Enable CORS support for web application development. When not set, CORS is disabled".
- What `/v1/models` lists. https://lmstudio.ai/docs/developer/openai-compat/models — "Returns the models visible to the server. The list may include all downloaded models when Just-In-Time loading is enabled."; JIT is `[Default: enabled]` (https://lmstudio.ai/docs/developer/core/ttl-and-auto-evict).
- A prompt longer than the loaded context fails rather than being cut. https://github.com/lmstudio-ai/lmstudio-bug-tracker/issues/546 — "the API fails instead of truncating or returning an appropriate error message." (bug report; a maintainer confirms the error is intended)

## llama.cpp `llama-server`

- Endpoints. https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md — "### GET /v1/models: OpenAI-compatible Model Info API", "### POST /v1/chat/completions: OpenAI-compatible Chat Completions API".
- Optional key. Same README — `--api-key KEY` "API key to use for authentication ... (default: none)"; client example `-H "Authorization: Bearer no-key"`.
- A prompt longer than the context fails. https://github.com/ggml-org/llama.cpp/commit/cc0a04343e56f2decdf2a6df977ff9c9edc85ced — `"request (%d tokens) exceeds the available context size (%d tokens), try increasing it"`.

## vLLM

- Address. https://docs.vllm.ai/en/latest/getting_started/quickstart/ — "By default, it starts the server at `http://localhost:8000`."; `openai_api_base = "http://localhost:8000/v1"`.
- Optional key. https://docs.vllm.ai/en/latest/cli/serve/ — "If provided, the server will require one of these keys to be presented in the header."; https://docs.vllm.ai/en/latest/usage/security/ lists `/v1/models` and `/v1/chat/completions` among the endpoints that "require Bearer token authentication".
- Browser origins. https://docs.vllm.ai/en/latest/cli/serve/ — `--allowed-origins`: "Cross-origin browser access is disabled by default."

## Chrome

- A public site reaching localhost asks the person first, since Chrome 142. https://developer.chrome.com/release-notes/142 — "Chrome 142 restricts the ability to make requests to the user's local network, gated behind a permission prompt."; a local network request is "any request from a public website to a local IP address or loopback".

## Not confirmed

- LM Studio's default port as a documented default (its docs only use 1234 in examples), and the address its app shows.
- LM Studio's default context length when it loads a model.
- Whether LM Studio's token also guards its `/v1` endpoints (its authentication page names the REST API and SDKs).
