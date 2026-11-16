# Spec: Generic connector for local LLM providers

## Overview

Studio Code chats only through the providers built into Studio: WordPress.com, Anthropic, OpenAI, Google Gemini and GitHub Copilot, each serving a fixed list of models. A person who runs models on their own computer, with Ollama, LM Studio, llama.cpp's `llama-server`, vLLM or another server of that kind, can't chat on them in Studio.

The change adds one generic connector for those servers. The person gives Studio the server's address, and a key only when the server asks for one. Studio then offers the models that server serves, and Studio Code chats on the one the person picks, in the Desktop app, in `studio ui` and in `studio code`. It works the same whichever product runs the server and follows the server's models as they change. It tells the person what is wrong when the server is stopped, refuses a model, or runs the model with too little context for Studio Code.

In this spec, a **local server** is a server the person runs that answers `GET <address>/v1/models` with the models it serves and `POST <address>/v1/chat/completions` with a chat reply. Ollama, LM Studio, `llama-server` and vLLM all document these two endpoints. A **local model** is a model a local server lists. **The connector** is what the person adds a local server through.

## Requirements

spec-requirement-1: In the Desktop app and in `studio ui`, the AI providers list in Settings offers the connector. The person connects it by giving their local server's address, and a key only when the server requires one. Once connected, the list shows it as connected, with the server's address. Connecting it again with another address or key replaces the previous one. Disconnecting it removes it.

origin: from-intent Goal ("People can add any local LLM provider to Studio through a generic connector.")

observed: the AI providers group lists only the built-in providers, by reading `SETTINGS_AI_PROVIDER_IDS` (`apps/ui/src/data/settings-sections.ts`) as rendered by `AiProviders` (`apps/ui/src/features/settings/settings-view/ai-panel.tsx`).

spec-requirement-2: In `studio code`, `/connect` offers the connector and asks for the server's address and an optional key. `/disconnect` removes the connector. Once the connector is connected, `/provider` offers it as the chat provider.

origin: from-intent Goal

observed: `/connect` offers `PROVIDER_IDS` and `/provider` offers `AI_PROVIDER_IDS`, both of which are only the built-in providers (`apps/cli/ai/slash-commands.ts:268`, `:466`).

spec-requirement-3: The connector works with any local server, whichever product runs it. Studio asks only for the address and the optional key, and never which product runs the server.

origin: from-intent Goal ("any local LLM provider", "a generic connector")

observed: Ollama, LM Studio, `llama-server` and vLLM each document `/v1/models` and `/v1/chat/completions` at their address (`spec/server-docs.md`). Ollama 0.40.0 answers both (`spec/ollama-probes.txt`).

spec-requirement-4: The address connects in each form the servers print or document. It may end at the server's root (`http://localhost:11434`, `http://localhost:8000`), carry the `/v1` path with or without a trailing slash (`http://localhost:1234/v1`, `http://localhost:11434/v1/`), or have no scheme (`127.0.0.1:11434`), which Studio reads as `http://`.

origin: derived Goal; input: Ollama prints its address without a scheme (`Listening on 127.0.0.1:11555`, `spec/ollama-probes.txt`) and documents `http://localhost:11434/v1/`; LM Studio documents `http://localhost:1234/v1`; vLLM documents both `http://localhost:8000` and `http://localhost:8000/v1` (`spec/server-docs.md`)

observed: Ollama answers `GET /` with "Ollama is running" and `GET /models` with 404, so its models are found only under `/v1` (`spec/ollama-probes.txt`).

spec-requirement-5: A local server that takes no key connects with the key left empty. A server that requires a key connects when the person gives it. When the key is missing or wrong, connecting fails with a message saying the server refused it. Studio never shows the key back.

origin: derived Goal; input: Ollama's local API takes no key. LM Studio with authentication on, `llama-server` started with `--api-key`, and vLLM started with `--api-key` each require a Bearer key (`spec/server-docs.md`).

observed: the Settings connect form enables Save only once every field has a value (`filled` in `apps/ui/src/features/settings/settings-view/ai-panel.tsx:61`).

observed: Ollama accepts a request whatever key it carries (`spec/ollama-probes.txt`).

spec-requirement-6: Connecting fails, and the connector stays not connected, in two cases. When nothing at the address lists models (no server is listening there, or the address points somewhere other than a local server), the message names the address and says no local server answered there. When the server lists no models, the message says the server has no models yet.

origin: derived Goal; input: LM Studio's server runs only after the person starts it (`lms server start`, `spec/server-docs.md`). An Ollama server with no models pulled lists `"data":null` (`spec/ollama-probes.txt`).

observed: a connection to `127.0.0.1:11556`, where nothing listens, is refused (`spec/ollama-probes.txt`).

spec-requirement-7: Once the connector is connected, the model picker in the app's composer and `/model` in `studio code` offer every model the local server lists, as models of the connector. Each one appears under the name the server gives it, such as `qwen3:0.6b`.

origin: derived Goal; input: the models a local server lists at `/v1/models`. Ollama 0.40.0 lists `all-minilm:latest`, `gemma3:270m` and `qwen3:0.6b` (`spec/ollama-probes.txt`).

observed: the pickers offer each provider's fixed model list: `getAiModels` (`packages/providers/models.ts`), `ModelPicker` (`apps/ui/src/features/composer/model-picker.tsx`) and `/model` (`apps/cli/ai/slash-commands.ts:392`).

spec-requirement-8: The offered models follow the server, without connecting again. A model the person adds to the server after connecting is offered the next time they open the model picker or run `/model` while the server runs. A model they remove is no longer offered from then on.

origin: derived Goal; input: a model pulled into a running Ollama server is listed at `/v1/models` right away (`spec/ollama-probes.txt`)

observed: the pickers build their lists without reaching the provider's service: "the pickers never reach the service to build their list" (`docs/design-docs/providers.md`, Models).

spec-requirement-9: A Studio Code chat on a local model runs the way it does on the built-in providers. The reply streams into the chat. When the model can call tools, such as Ollama's `qwen3:0.6b`, the agent uses Studio Code's tools on the person's sites.

origin: derived Goal; input: Studio's AI providers exist to power Studio Code's chats. The AI providers group says "Build and edit sites through chat" (`apps/ui/src/features/settings/settings-view/ai-panel.tsx`).

observed: Ollama's `qwen3:0.6b` answers a chat request that offers a tool with a call to that tool (`spec/ollama-probes.txt`).

assumed: a Studio Code turn on a local model that can call tools adds a page to a local site (spec-assumption-4).

spec-requirement-10: A new chat on the connector starts on the local model the person chose most recently on it. Until they have chosen one, it starts on a model the server lists. A chat that ran on a local model keeps running on that model while the server still lists it, when the person reopens it from the app's chat list or with `studio code sessions resume`.

origin: derived Goal; input: Ollama lists the most recently pulled model first, and in the probe that was the embedding-only `all-minilm:latest` (`spec/ollama-probes.txt`). Chats are reopened from the app's chat list and with `studio code sessions resume`.

observed: on resume, a recorded model that isn't in the provider's fixed list is replaced by the provider's default. See `servesModel` (`apps/cli/commands/ai/index.ts:78`, `:224`) and `resolveSessionModelForProvider` (`packages/agent/protocol/sessions/model.ts:63`).

spec-requirement-11: Sometimes the local server refuses a turn because of its model. Ollama answers "does not support tools" for `gemma3:270m`, "does not support chat" for the embedding-only `all-minilm`, and "model '…' not found" for a model it no longer has. The turn then ends with an error in the chat that names the model, gives the server's reason in words rather than as a raw response body, and says to pick another model.

origin: derived Goal; input: Ollama 0.40.0 answers those three refusals with 400, 400 and 404 (`spec/ollama-probes.txt`)

observed: a turn the model server refuses ends with the raw response as its error, `400: {"message":"…","type":"invalid_request_error"}` (`spec/studio-code-request.txt`).

spec-requirement-12: When the local server doesn't answer during a chat, the turn ends with an error that names the server's address, says the local server isn't answering, and says to start it.

origin: derived Goal; input: LM Studio's server runs only after the person starts it (`spec/server-docs.md`). A connection to an address where no server listens is refused (`spec/ollama-probes.txt`).

observed: a turn whose model server doesn't answer ends with "Connection error." after 3 automatic retries (`spec/studio-code-request.txt`).

spec-requirement-13: A chat on a local model that can't read images keeps working when the conversation holds an image, either a screenshot the agent took with `take_screenshot` or an image the person attached. A local model that can read images receives them.

origin: derived Goal; input: Ollama 0.40.0 answers 400 "Multimodal data provided, but model does not support multimodal requests." when `qwen3:0.6b` is sent an image (`spec/ollama-probes.txt`). Screenshot tool results are images (`packages/providers/types.ts:52`).

assumed: whether a local model reads images can be learned on every local server (spec-assumption-2).

spec-requirement-14: A conversation on a local model never reaches the model cut short without the person knowing. As it grows past the context the server runs the model with, it keeps getting replies, as conversations on the built-in providers do past theirs. When a single turn can't fit in that context, the turn ends with an error saying the model's context is too small for Studio Code and that the server's settings can raise it.

origin: derived Goal; input: Ollama documents a 4k default context on machines with less than 24 GiB of VRAM (`spec/server-docs.md`), and one Studio Code turn is 11,299 tokens (`spec/studio-code-request.txt`).

observed: Ollama running with a 4096-token context cuts Studio Code's first turn from 11,299 to 2,050 tokens and answers 200 with no error (`spec/studio-code-request.txt`). `llama-server` and LM Studio fail such a request with an error instead (`spec/server-docs.md`).

observed: on the built-in providers, Studio Code compacts a conversation as it nears the context window the provider states for the model (`STUDIO_COMPACTION_SETTINGS` in `packages/agent/node/runtime/index.ts:52`, `contextWindow` in `packages/providers/anthropic/ai.ts`).

assumed: the context a local server runs a model with, or the fact that a turn didn't fit in it, can be learned on every local server (spec-assumption-1).

spec-requirement-15: A chat on a local model can be sent while the computer has no internet connection, in the app and in `studio code`.

origin: derived Goal; input: the composer's offline state, which the app shows whenever the computer is offline (`useOffline` in `apps/ui/src/features/composer/use-composer-notice.ts`)

observed: while offline, the composer blocks sending on every provider with "You are offline. Reconnect to send a message." (`apps/ui/src/features/composer/use-composer-notice.ts:63`).

assumed: a Studio Code turn on a local model needs nothing from the internet (spec-assumption-3).

spec-requirement-16: A local server connected in one of the Desktop app, `studio ui` and `studio code` is connected in the other two, with the same address and models. Choosing the connector as the chat provider in one chooses it in all three.

origin: derived Goal; input: people use the Desktop app, `studio ui` and `studio code` on the same computer, which share the chat provider ("Studio saves it in `shared.json`, and every surface shares it", `docs/design-docs/providers.md`)

observed: the Desktop app, `studio ui` and `studio code` read provider configs and the selected chat provider from `shared.json` (`packages/common/lib/provider-config.ts`, `packages/common/lib/ai-settings.ts`).

spec-requirement-17: The analytics events Studio records for chats on a local model carry neither the model's name nor the server's address.

origin: derived Goal; input: local model names the person chooses. To raise a model's context for clients of the `/v1` API, Ollama documents writing a Modelfile, which creates a new model under a name the person picks (`spec/server-docs.md`).

observed: every chat turn's `studio_code_message_sent` and `studio_code_turn_completed` events carry the model id (`apps/cli/commands/ai/index.ts:639`). The analytics design states that these events never carry prompts, replies, raw error text or site names (`docs/design-docs/analytics-tracks.md:289`).

spec-requirement-18: A Studio build from before this change that shares settings with one that has the connector keeps running chats. When the connector is the chosen chat provider, the older build runs them on another connected provider, WordPress.com first. The connector is still connected when the newer build runs again.

origin: derived Goal; input: "Desktop and CLI builds of different versions read the same `shared.json` and session files" (`docs/design-docs/providers.md:24`)

observed: today's builds keep provider configs they don't know (`providerConfigs: z.record( z.string(), z.unknown() )`, `packages/common/lib/shared-config.ts:57`). For a chat provider id they don't know, they run chats on the first connected provider, WordPress.com first (`readSelectedAiProvider` in `packages/common/lib/ai-settings.ts`, `resolveInitialAiProvider` in `apps/cli/ai/auth.ts`).

spec-requirement-19: Studio on the web doesn't offer the connector: its AI providers list and its model picker don't show it.

origin: derived Goal; input: Studio on the web runs at `https://app.wordpress.studio`, and Ollama 0.40.0 refuses that origin with 403 (`spec/ollama-probes.txt`). LM Studio and vLLM refuse cross-origin requests by default, and Chrome 142 asks the person before a public site reaches localhost (`spec/server-docs.md`).

observed: Studio on the web already leaves out the connect methods it can't run: `loopbackSignIn: false` (`apps/ui/src/data/core/connectors/static/index.ts:154`) and `getProviderConnectMethods` (`apps/ui/src/features/settings/settings-view/ai-panel.tsx`).

## Acceptance criteria

spec-acceptance-criterion-1: Given Ollama running at `http://localhost:11434` with a chat model, when the person connects the connector with that address from Settings → AI providers in the Desktop app and in `studio ui`, then Settings shows the connector as connected with that address.

spec-acceptance-criterion-2: Given the connector connected to one local server, when the person connects it again with the address of another, then Settings shows the new address and the model picker offers only the new server's models.

spec-acceptance-criterion-3: Given the connector connected, when the person disconnects it in Settings or with `/disconnect` in `studio code`, then Settings and `/connect` show it as not connected, and neither the model picker nor `/model` offers local models.

spec-acceptance-criterion-4: Given Ollama running, when the person runs `/connect` in `studio code`, picks the connector and enters the address, then `/model` offers the server's models and `/provider` offers the connector.

spec-acceptance-criterion-5: Given a local server run by Ollama, by LM Studio, by `llama-server` or by vLLM, when the person connects the connector with its address, then it connects without asking which product runs the server, and the model picker offers that server's models.

spec-acceptance-criterion-6: Given Ollama listening on `127.0.0.1:11434`, when the person connects with `http://localhost:11434`, `http://localhost:11434/v1`, `http://localhost:11434/v1/` or `127.0.0.1:11434`, then each connects, and the model picker offers the same models.

spec-acceptance-criterion-7: Given Ollama, which takes no key, when the person connects with the key left empty, in Settings and in `/connect`, then the connector connects.

spec-acceptance-criterion-8: Given `llama-server` started with `--api-key`, when the person connects with that key, then the connector connects and a chat on its model gets a reply. When the person connects with no key or a wrong one, then connecting fails with a message saying the server refused the key. In both cases Settings never shows the key.

spec-acceptance-criterion-9: Given an address where nothing listens, when the person connects with it in Settings or in `/connect`, then connecting fails with a message that names the address and says no local server answered there, and the connector stays not connected.

spec-acceptance-criterion-10: Given an Ollama server with no models, when the person connects with its address, then connecting fails with a message saying the server has no models yet.

spec-acceptance-criterion-11: Given the connector connected to Ollama serving `qwen3:0.6b` and `gemma3:270m`, when the person opens the composer's model picker and runs `/model`, then both offer the two models by those names, as models of the connector.

spec-acceptance-criterion-12: Given the connector connected to a running Ollama, when the person adds a model with `ollama pull` and opens the model picker again, then the new model is offered. After `ollama rm`, it isn't.

spec-acceptance-criterion-13: Given a chat on a local model that can call tools, when the person asks Studio Code to add a page to one of their local sites, then the reply streams into the chat and the page exists in the site.

spec-acceptance-criterion-14: Given a person who picked a local model in a chat on the connector, when they start a new chat on the connector, then the composer shows that model.

spec-acceptance-criterion-15: Given a chat that ran on a local model the server still lists, when the person reopens it from the app's chat list or with `studio code sessions resume` and sends a message, then the turn runs on that model.

spec-acceptance-criterion-16: Given a chat on Ollama's `gemma3:270m`, on `all-minilm`, or on a model removed from the server, when the person sends a message, then the chat shows an error that names the model, gives the server's reason in words and says to pick another model, with no raw response body.

spec-acceptance-criterion-17: Given a chat on a local model whose server has stopped, when the person sends a message, then the chat shows an error that names the server's address, says the local server isn't answering, and says to start it.

spec-acceptance-criterion-18: Given a chat on Ollama's `qwen3:0.6b`, which can't read images, when the agent takes a screenshot or the person attaches an image, then that turn and the turns after it complete.

spec-acceptance-criterion-19: Given a chat on a local model that reads images, when the person attaches an image and asks about it, then the reply describes the image.

spec-acceptance-criterion-20: Given Ollama running its model with a 4096-token context, when the person sends the first message of a chat on it, then the chat shows an error saying the model's context is too small for Studio Code and that the server's settings can raise it, and no reply.

spec-acceptance-criterion-21: Given a local model whose context fits Studio Code's turns, when a chat on it grows past that context, then the chat keeps getting replies, and the server never cuts a request short (Ollama's log shows no "truncating input prompt").

spec-acceptance-criterion-22: Given a computer with no internet connection and a chat on a local model, when the person sends a message in the app or in `studio code`, then the turn runs and gets a reply.

spec-acceptance-criterion-23: Given the connector connected in the Desktop app, when the person opens `studio ui` or `studio code`, then the connector is connected there with the same address and models. When the person chooses it as the chat provider in one of the three, then new chats in the other two use it.

spec-acceptance-criterion-24: Given chats on a local model, when Studio records the analytics events for their turns, then no event carries the model's name or the server's address.

spec-acceptance-criterion-25: Given settings in which the connector is connected and chosen as the chat provider, when a Studio build from before this change runs a chat, then the chat runs on another connected provider. When the newer build runs again, then the connector is still connected.

spec-acceptance-criterion-26: Given Studio on the web, when the person opens Settings → AI providers and the composer's model picker, then neither offers the connector.

## Exclusions

spec-exclusion-1: Studio doesn't install, start or stop a local server, download models into it, or change its settings, such as the context it runs a model with.

spec-exclusion-2: The connector doesn't generate images. Image generation keeps coming from a connected provider that offers it.

## Considered and not required

- Reading of the Goal as several local servers connected at once, such as Ollama and LM Studio side by side — the Goal asks that any local LLM provider can be added, which one connection the person can point at any server meets, and no Studio doc or code shows a person running two.
- Reading of the Goal that offers the connector in Studio on the web for servers set to accept its origin — every default examined refuses that origin (observed: Ollama answers 403, `spec/ollama-probes.txt`; LM Studio and vLLM document cross-origin access off by default, `spec/server-docs.md`), so the control would fail on servers as installed.
- Reading that leaves out of the pickers the models a server can't chat with, or that can't call tools — `/v1/models` gives only ids (observed: Ollama's listing, `spec/ollama-probes.txt`), so the turn's error (spec-requirement-11) tells the person instead.
- The address of a hosted service that answers the same two requests, such as OpenRouter — the intent asks for local LLM providers.
- A server that answers only another API, such as Ollama's own `/api/chat` or Anthropic's Messages API — every server examined documents `/v1/models` and `/v1/chat/completions` (`spec/server-docs.md`).
- A model name typed by hand that the server doesn't list — every server examined lists the models it serves at `/v1/models` (`spec/server-docs.md`).
- Chats through `studio mcp` — the agent apps that use Studio through MCP chat on their own models (observed: only `studio code` and its eval harness open a chat model connection, `resolveAiConnection` in `apps/cli/commands/ai/index.ts` and `apps/cli/ai/eval-harnesses/studio.ts`).

## Open assumptions

spec-assumption-1: On every local server, Studio can learn the context the server runs a model with, or the fact that a turn didn't fit in it. This is what spec-requirement-14 rests on. — assumed: confirmed once the design names how Studio learns it for Ollama, LM Studio, `llama-server` and vLLM, and a turn on Ollama with a 4096-token context shows the error.

spec-assumption-2: On every local server, Studio can learn whether a local model reads images (spec-requirement-13). — assumed: confirmed when a turn holding a screenshot completes on Ollama's `qwen3:0.6b`, and a model Ollama lists with the `vision` capability describes an attached image.

spec-assumption-3: A Studio Code turn on a local model needs nothing from the internet (spec-requirement-15). — assumed: confirmed when a turn on a local model completes with the computer's network off.

spec-assumption-4: Studio Code's tools work through a local model that can call tools (spec-requirement-9). — assumed: confirmed when a turn on such a model adds a page to a local site.
