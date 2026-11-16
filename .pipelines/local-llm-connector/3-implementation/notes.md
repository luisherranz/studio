---
status: done
---

# Implementation notes

## Done

- The `local-llm` provider in `@studio/providers`: descriptor, config, account (address forms, optional key, the three connect failures, the proposed model), the server client (`/v1/models`, then Ollama's `/api/show`, `/api/ps` and `/api/generate`, or LM Studio's `/api/v1/models`), the model connection (plain Chat Completions, `requestModelId`, `rewriteError`, `exactContextWindow`) and the listing; ids `local-llm/<server name>`, `servesAiModel`, the remembered-model default, `ConnectField.required`, `ConnectMethod.hostOnly`, `AccountDetails.model`; `@studio/common` storage, `listProviderModels`, `recordAiModelChoice`; the CLI, the Desktop IPC handler, the `apps/local` route, the `ipc`/`local` connectors, the picker's listing and the new-chat default (9c8c6f143).
- Settings: optional fields, the account's summary on its row, host-only methods left out on the web (2dc9083ee); the key field's `default( '' )` so Settings connects with it untouched (256ee7346).
- Runtime: the exact-window guard (049ac1edf) and compaction sized to the room the system prompt and tools leave (77b88fd43).
- Composer: image gate from the listing, offline sending on the connector (c2f0f1bd0).
- Tests at Settings, the picker, the composer, new chats, the IPC handler and the `apps/local` route (bcfe55a4e).
- `studio code` re-resolves a chat that hasn't settled on a model after `/connect` to another server (7d9186ae8).
- Docs: `docs/design-docs/providers.md`, `docs/design-docs/analytics-tracks.md`, `packages/providers/README.md`, the user docs' AI providers section (8bc4dbea9).
- LM Studio loads a model that isn't loaded through a minimal `/v1/chat/completions` request before the connector reads its context, never its load API (9f4ae7ac2), as design-doc-decision-7 now has it: a first turn too large for LM Studio's default context ends in the connector's words, and the model keeps LM Studio's 60-minute idle TTL (`lmstudio.txt`).
- End to end, with evidence in `notes/`: Ollama in `studio code` (`studio-code-ollama.txt`, `studio-code-long-chat.txt`, `studio-code-tools-offline-older-build.txt`), `studio ui` in light and dark and Studio on the web (`studio-ui.txt` and its screenshots), llama-server with a key (`llama-server.txt`), LM Studio (`lmstudio.txt`), vLLM (`vllm.txt`), a `take_screenshot` turn on a text-only model and the turn after it (`screenshot-text-only.txt`).

## Remaining

- Not observed here: a Studio Code turn on vLLM getting its reply. vLLM connected, listed its model with `max_model_len`, and accepted the turn's request (200), but its CPU backend on this Mac took 815 s to prefill a 9k-token prompt, past Node fetch's 300 s body timeout (`vllm.txt`). vLLM is meant to run on a GPU.
- Agent evals: not run. The change doesn't touch the system prompt, a tool's definition, description or result shape, or a skill; the runtime changes act only on connections that state an exact window, which no built-in provider does.
- Failures that aren't this change's: with the CLI built, `npm test -- packages/providers packages/common packages/agent apps/cli apps/local apps/ui apps/studio` also runs the CLI's `*.e2e.test.ts` files, which start real sites in parallel and collided on port 8881 (`EADDRINUSE`). Run one file at a time, `start-stop`, `create`, `localization`, `import` and `site-management` pass; `create-blueprint` (2–3 cases) and `site-navigation` ("adds new themes") fail because the sites' PHP gets `cURL error 35: Recv failure: Connection reset by peer` from downloads.wordpress.org on this network, in code the change doesn't touch. Every other test file passes; typecheck, knip and lint report nothing.

## Decisions

- The connector's label is `Local LLM`; its one method is the `server` form (`address`, optional `apiKey`), marked `hostOnly`.
- A model's Studio id is `local-llm/<server name>`; `findAiModel` labels it with the server's name. `toUserServerModelId` lives in `models.ts`; the descriptor builds the id inline, because a descriptor importing `models.ts` makes an import cycle that leaves `getProvider( 'local-llm' )` undefined when the services entry loads first.
- Studio remembers the chosen model in `shared.json`'s `chosenAiModels`, keyed by stored provider id; `AiSettings.chosenModels` carries it. Only providers whose models a server lists are recorded, and a write takes the lock only when the value changes.
- Choices are recorded by the hosts' session model and provider-pin handlers, `/model`, and `switchProvider` in `studio code`; the UI re-reads AI settings after such a pick (`refreshChosenModel`).
- The analytics `model` for the connector is the fixed `user-server-model`.
- An unknown context gets a 128,000-token window and no exact-window statement.
- pi needs a key to send a request; a server without one gets the placeholder `none`, which servers without auth ignore.
- `getDefaultAiModel` for the connector with neither a chosen nor an account model returns WordPress.com's default, which the connector doesn't serve; `studio code` re-resolves the model after `/connect`.
- The exact-window guard refuses a request when pi's own output clamp would leave fewer than `MIN_ANSWER_TOKENS` for the reply; the refusal is a `context_length_exceeded` error pi compacts and retries on. Compaction for an exact window: `reserveTokens = min( 16384, share / 2 + 5120 )`, `keepRecentTokens = min( 20000, share / 4 )`, where `share` is the window less the system prompt and tools (by pi's estimate) and 5,120 tokens for the reply.
- The overflow words replace the last assistant message's `errorMessage` in the final `agent_end`, and the overflow `compaction_end`'s error is dropped, so a surface shows the connection's words once.
- The connector's commits group its cross-package wiring in one commit: the derived requirements' code shares files (the connector's `ai.ts`, the CLI command), and splitting hunks after the fact was not worth the risk.

## Failed approaches

- A quarter of the window for both compaction sizes: on windows near Studio Code's base request (~15k tokens by pi's estimate) the kept tail left no room after compacting, so sizes now come from what the system prompt and tools leave.
- vLLM 0.11 with transformers 5 fails to start (`Qwen2Tokenizer has no attribute all_special_tokens_extended`); transformers 4.57 works.

## Assumptions

- spec-assumption-1: observed for Ollama (`/api/ps` after a load; a 4096-token context shows the words and sends nothing, `studio-code-ollama.txt`), llama-server (`meta.n_ctx`, `llama-server.txt`), vLLM (`max_model_len`, `vllm.txt`) and LM Studio, including a first turn before its model is loaded once the connector has it loaded on request (`lmstudio.txt`).
- spec-assumption-2: observed: `qwen3:0.6b` gets attachments held back, completes a turn after earlier images (`studio-ui.txt`), and completes a `take_screenshot` turn and the turn after it (`screenshot-text-only.txt`); `qwen3-vl:2b` (Ollama `vision`) answers "red" for a red image. vLLM reports nothing, so its models count as text-only.
- spec-assumption-3: observed with all outbound traffic but localhost denied by `sandbox-exec`: a turn on a local model completed (`studio-code-tools-offline-older-build.txt`). The machine's network itself wasn't turned off.
- spec-assumption-4: observed: `qwen3-vl:2b` called `wp_cli` and the "About us" page exists (`studio-code-tools-offline-older-build.txt`); `qwen3:0.6b` called a tool, the wrong one.
- design-doc-assumption-1: observed on Ollama `qwen3:0.6b` at 32,768: five long turns, one compaction at 21,643 tokens, replies throughout, no "truncating input prompt" (`studio-code-long-chat.txt`).
- design-doc-assumption-2: observed for Ollama, llama-server and LM Studio (replies; tool calls on Ollama); vLLM accepted the request (200) but its CPU backend was too slow to finish a turn here.
