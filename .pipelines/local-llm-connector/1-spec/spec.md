# Spec: Generic connector for local LLM providers

## Overview

Studio Code chats only through the providers built into Studio: WordPress.com, OpenAI, Anthropic, Google Gemini and GitHub Copilot, each serving a fixed list of models. A person who runs models themselves, with Ollama, LM Studio, llama.cpp's `llama-server`, vLLM or another server of that kind, can't chat on them in Studio.

The change adds one generic connector for those servers in the Desktop app, `studio ui` and `studio code`. The person gives Studio the server's address, and a key only when the server asks for one. Studio then offers the models that server chats on and follows them as they change. Studio Code chats on the one the person picks, with no WordPress.com sign-in or AI credits needed. The connector works the same whichever product runs the server. It tells the person what is wrong when the server is stopped, refuses a model, or runs the model with too little context for Studio Code. Studio doesn't run the server or fetch its models.

In this spec, a **local server** is a server the person runs that answers `GET <address>/v1/models` with the models it serves and `POST <address>/v1/chat/completions` with a chat reply. Ollama, LM Studio, `llama-server` and vLLM all document these two requests. A **local model** is a model a local server lists. **The connector** is what the person adds a local server through.

## Requirements

spec-requirement-1: In the Desktop app and in `studio ui`, the AI providers group in Settings → Providers offers the connector. The person connects it by giving their local server's address, and a key only when the server requires one. Once it is connected, the group shows it as connected, with the server's address, and the Default AI provider setting offers it. Connecting it again with another address or key replaces the previous one, and from then on chats on the connector go to the new server. Disconnecting it removes it: the group shows it as not connected, and neither the Default AI provider setting nor the model picker offers it.

origin: from-intent Goal ("People can add any local LLM provider to Studio through a generic connector.")

observed: in a running `studio ui`, the AI providers group lists WordPress.com, OpenAI, Anthropic, Google Gemini and GitHub Copilot, and no control takes a server's address (`spec/providers.txt`). The group renders only the built-in providers (`AiProviders` in `apps/ui/src/features/settings/settings-view/ai-panel.tsx`). The Default AI provider setting offers the connected AI providers (`ProviderDefaults` in `apps/ui/src/features/settings/settings-view/providers-panel.tsx`).

spec-requirement-2: In `studio code`, `/connect` offers the connector and asks for the server's address and an optional key, and `/disconnect` removes it. Once it is connected, `/provider` offers it as the chat provider.

origin: from-intent Goal

observed: `/connect` offers `PROVIDER_IDS` and `/provider` offers `AI_PROVIDER_IDS`, and both list only the built-in providers (`apps/cli/ai/slash-commands.ts:268`, `:466`).

spec-requirement-3: The connector works with any local server, whichever product runs it, and with any model the server chats on, whether or not Studio knows that model. Studio asks only for the address and the optional key, never which product runs the server.

origin: from-intent Goal ("any local LLM provider", "a generic connector")

observed: Ollama, LM Studio, `llama-server` and vLLM each document `/v1/models` and `/v1/chat/completions` at their address (`spec/server-docs.md`), and Ollama 0.40.0 answers both (`spec/ollama-probes.txt`). Today the pickers offer only the models Studio lists for each built-in provider (`getAiModels` in `packages/providers/models.ts`).

spec-requirement-4: The address connects in each form the servers print or document. It may end at the server's root (`http://localhost:11434`, `http://localhost:8000`), or carry the `/v1` path with or without a trailing slash (`http://localhost:1234/v1`, `http://localhost:11434/v1/`). It may also have no scheme (`127.0.0.1:11434`), which Studio reads as `http://`.

origin: derived Goal; input: Ollama prints its address without a scheme, both in its log (`Listening on 127.0.0.1:11555`, `spec/ollama-probes.txt`) and as its default host (`127.0.0.1:11434`, `spec/local-service.txt`), and documents `http://localhost:11434/v1/`. LM Studio documents `http://localhost:1234/v1`, and vLLM documents both `http://localhost:8000` and `http://localhost:8000/v1` (`spec/server-docs.md`).

observed: Ollama answers `GET /` with "Ollama is running" and `GET /models` with 404, so its models are found only under `/v1` (`spec/ollama-probes.txt`).

spec-requirement-5: A local server that takes no key connects with the key left empty, in Settings and in `/connect`. A server that requires a key connects when the person gives it, and its chats run with it. When the key is missing or wrong, connecting fails with a message saying the server refused the key. Studio never shows the whole key back, at most its first and last characters, as it does for the built-in providers' keys.

origin: derived Goal; input: Ollama's local API takes no key. LM Studio with authentication on, `llama-server` started with `--api-key`, and vLLM started with `--api-key` each require a Bearer key (`spec/server-docs.md`).

observed: the Settings connect form enables Save only once every field has a value (`filled` in `apps/ui/src/features/settings/settings-view/ai-panel.tsx:61`).

observed: Ollama lists its models with no key (`spec/local-service.txt`) and accepts a request whatever key it carries (`spec/ollama-probes.txt`).

observed: the providers design states that surfaces show of a connected account a summary "such as a key's first and last characters, never the credential itself" (`docs/design-docs/providers.md:87`).

spec-requirement-6: Connecting fails, and the connector stays not connected, in two cases. When nothing at the address lists models, because no server is listening there or the address points somewhere other than a local server, the message names the address and says no local server answered there. When the server lists no model to chat on, because it lists none or only the embedding models spec-requirement-7 leaves out, the message says the server has no chat model yet.

origin: derived Goal; input: LM Studio's server runs only after the person starts it (`lms server start`, `spec/server-docs.md`). Ollama as installed, before any model is pulled, lists `"data":null` (`spec/local-service.txt`, `spec/ollama-probes.txt`). LM Studio ships with the embedding model `text-embedding-nomic-embed-text-v1.5`, so before the person downloads a chat model its server lists only that one (`spec/lmstudio-embedding.txt`).

observed: a connection to `127.0.0.1:11556`, where nothing listens, is refused (`spec/ollama-probes.txt`).

spec-requirement-7: Once the connector is connected, the model picker in the app's composer and `/model` in `studio code` offer the models the local server lists, as models of the connector, each under the name the server gives it, such as `qwen3:0.6b`. They leave out the models the server says only make embeddings, which no chat runs on: a model Ollama says only embeds, such as `all-minilm`, and a model LM Studio lists as an embedding model, such as the `text-embedding-nomic-embed-text-v1.5` it ships with. A model the server says nothing about, as on `llama-server` and vLLM, is offered. Picking one in a chat runs that chat's next turns on it.

origin: derived Goal; input: the models a local server lists at `/v1/models`. Ollama 0.40.0 lists `all-minilm:latest`, `gemma3:270m` and `qwen3:0.6b` (`spec/ollama-probes.txt`). LM Studio 0.4.28 lists its chat model and the embedding model it ships with (`spec/lmstudio-embedding.txt`).

observed: before this change, the pickers offer each provider's fixed model list: `getAiModels` (`packages/providers/models.ts`), `ModelPicker` (`apps/ui/src/features/composer/model-picker.tsx`) and `/model` (`apps/cli/ai/slash-commands.ts:392`), at 924a82669.

observed: neither server's `/v1/models` entries say what kind of model each is. Ollama's own API reports `all-minilm`'s only capability as `embedding`, and Ollama refuses to chat on it with "\"all-minilm:latest\" does not support chat" (`spec/ollama-probes.txt`). LM Studio's own API lists `text-embedding-nomic-embed-text-v1.5` with the type `embedding`, and LM Studio refuses to chat on it with "No models loaded. Please load a model in the developer page or use the 'lms load' command." (`spec/lmstudio-embedding.txt`).

spec-requirement-8: The offered models follow the server, without connecting again. A model the person adds to the server after connecting is offered the next time they open the model picker or run `/model` while the server runs. A model they remove is no longer offered from then on.

origin: derived Goal; input: a model pulled into a running Ollama server is listed at `/v1/models` right away (`spec/ollama-probes.txt`).

observed: the pickers build their lists without reaching the provider's service: "the pickers never reach the service to build their list" (`docs/design-docs/providers.md:95`).

spec-requirement-9: A Studio Code chat on a local model runs the way it does on the built-in providers. The reply streams into the chat. When the model can call tools, such as Ollama's `qwen3:0.6b`, the agent uses Studio Code's tools on the person's sites and continues from their results in the same turn.

origin: derived Goal; input: Studio's AI providers exist to power Studio Code's chats; the AI providers group says "Build and edit sites through chat" (`spec/providers.txt`).

observed: Ollama's `qwen3:0.6b` answers a chat request that offers a tool with a call to that tool (`spec/ollama-probes.txt`).

assumed: a Studio Code turn on a local model that can call tools adds a page to a local site (spec-assumption-4).

spec-requirement-10: When the connector is the chat provider and no other provider is connected, chats on it run in the app and in `studio code` without signing in to WordPress.com and without AI credits.

origin: derived Goal; input: a person whose only AI provider is their local server. Settings offers each AI provider on its own, and the Default AI provider setting offers whichever are connected (`spec/providers.txt`, `ProviderDefaults` in `apps/ui/src/features/settings/settings-view/providers-panel.tsx`).

observed: with no provider connected, a `studio code` turn ends with "Log in to WordPress.com to use its models. Use /connect wpcom to connect it." (`spec/unconfigured-chat.txt`).

spec-requirement-11: When the person hasn't picked a model for it, a new chat on the connector starts on one of the models spec-requirement-7 offered when the person connected it. It is one the server says can call tools, when the server says that of any, even when the server lists another model first. A chat that ran on a local model keeps running on that model while the server still lists it, when the person reopens it from the app's chat list or with `studio code sessions resume`.

origin: derived Goal; input: Ollama lists the most recently pulled model first. In the probe it listed the embedding-only `all-minilm:latest` and `gemma3:270m`, which can't call tools, before `qwen3:0.6b`, which can (`spec/ollama-probes.txt`). Ollama refuses tools on `gemma3:270m` (`spec/ollama-probes.txt`), and every Studio Code turn offers the model its tools (`spec/studio-code-request.txt`). Chats are reopened from the app's chat list and with `studio code sessions resume`.

observed: before this change, a new chat starts on its provider's fixed default model, and on resume a recorded model that isn't in the provider's fixed list is replaced by that default. See `resolveSessionModelForProvider` (`packages/agent/protocol/sessions/model.ts:63`) and `servesModel` (`apps/cli/commands/ai/index.ts:78`, `:224`), at 924a82669.

spec-requirement-12: Sometimes the local server refuses a turn because of its model. Ollama answers "does not support tools" for `gemma3:270m`, and "model '…' not found" for a model it no longer has. The turn then ends with an error in the chat that names the model, gives the server's reason in words rather than as a raw response body, and says to pick another model. No other provider answers the turn in its place.

origin: derived Goal; input: Ollama 0.40.0 answers those two refusals with 400 and 404 (`spec/ollama-probes.txt`).

observed: a turn the model server refuses ends with the raw response as its error, `400: {"message":"…","type":"invalid_request_error"}` (`spec/studio-code-request.txt`).

spec-requirement-13: When the local server doesn't answer during a chat, the turn ends with an error that names the server's address, says the local server isn't answering, and says to start it. No other provider answers the turn in its place.

origin: derived Goal; input: LM Studio's server runs only after the person starts it (`spec/server-docs.md`), and a connection to an address where no server listens is refused (`spec/ollama-probes.txt`).

observed: a turn whose model server doesn't answer ends with "Connection error." after 3 automatic retries (`spec/studio-code-request.txt`).

spec-requirement-14: A chat on a local model that can't read images, such as Ollama's `qwen3:0.6b`, behaves as chats on the built-in models that can't. A screenshot the agent takes with `take_screenshot`, or an image an earlier turn holds, doesn't stop that turn or the turns after it. An image the person attaches in the composer is held back with the message asking them to choose a model that supports images. A local model that can read images receives the screenshots and the images the person attaches.

origin: derived Goal; input: Ollama 0.40.0 answers 400 "Multimodal data provided, but model does not support multimodal requests." when `qwen3:0.6b` is sent an image (`spec/ollama-probes.txt`). Screenshot tool results are images (`packages/providers/types.ts:52`), and the app's composer takes image attachments (`apps/ui/src/features/composer/composer.tsx:388`).

observed: for a built-in model that can't read images, such as WordPress.com's `fast` (`packages/providers/wpcom/descriptor.ts:16`), the composer holds attached images back with "Choose a model that supports images before sending these attachments" (`apps/ui/src/features/composer/composer.tsx:388`).

assumed: whether a local model reads images can be learned on every local server (spec-assumption-2).

spec-requirement-15: A conversation on a local model never reaches the model cut short without the person knowing. As it grows past the context the server runs the model with, it keeps getting replies, as conversations on the built-in providers do past theirs. When a single turn can't fit in that context, the turn ends with an error saying the model's context is too small for Studio Code and that the server's settings can raise it.

origin: derived Goal; input: Ollama defaults to a 4k context on machines with less than 24 GiB of VRAM (`spec/server-docs.md`, `spec/local-service.txt`), and one Studio Code turn is 11,299 tokens (`spec/studio-code-request.txt`).

observed: Ollama running with a 4096-token context cuts Studio Code's first turn from 11,299 to 2,050 tokens and answers 200 with no error (`spec/studio-code-request.txt`). `llama-server` and LM Studio fail such a request with an error instead (`spec/server-docs.md`).

observed: on the built-in providers, Studio Code compacts a conversation as it nears the context window the provider states for the model (`STUDIO_COMPACTION_SETTINGS` in `packages/agent/node/runtime/index.ts:52`, `contextWindow` in `packages/providers/anthropic/ai.ts`).

assumed: the context a local server runs a model with, or the fact that a turn didn't fit in it, can be learned on every local server (spec-assumption-1).

spec-requirement-16: A chat on a local model can be sent while the computer has no internet connection, in the app and in `studio code`.

origin: derived Goal; input: the composer's offline state, which the app shows whenever the computer is offline (`useOffline` in `apps/ui/src/features/composer/use-composer-notice.ts`).

observed: while offline, the composer blocks sending on every provider with "You are offline. Reconnect to send a message." (`apps/ui/src/features/composer/use-composer-notice.ts:63`).

assumed: a Studio Code turn on a local model needs nothing from the internet (spec-assumption-3).

spec-requirement-17: A local server connected in one of the Desktop app, `studio ui` and `studio code` is connected in the other two, with the same address and models. Choosing the connector as the chat provider in one chooses it in all three.

origin: derived Goal; input: people use the Desktop app, `studio ui` and `studio code` on the same computer, and they share the chat provider ("Studio saves it in `shared.json`, and every surface shares it", `docs/design-docs/providers.md:105`).

observed: the Desktop app, `studio ui` and `studio code` read provider configs and the selected chat provider from `shared.json` (`packages/common/lib/provider-config.ts`, `packages/common/lib/ai-settings.ts`).

spec-requirement-18: The analytics events Studio records for chats on a local model carry neither the model's name nor the server's address.

origin: derived Goal; input: local model names the person chooses. To raise a model's context for clients of the `/v1` API, Ollama documents writing a Modelfile, which creates a new model under a name the person picks (`spec/server-docs.md`).

observed: every chat turn's `studio_code_message_sent` and `studio_code_turn_completed` events carry the model id (`apps/cli/commands/ai/index.ts:639`). The analytics design states that these events never carry prompts, replies, raw error text or site names, and reports a tool name the model wrote as `unknown` (`docs/design-docs/analytics-tracks.md:289`, `:566`).

spec-requirement-19: A Studio build from before this change that shares settings with one that has the connector keeps running chats. When the connector is the chosen chat provider, the older build runs chats on another connected provider, WordPress.com first. The connector is still connected when the newer build runs again.

origin: derived Goal; input: "Desktop and CLI builds of different versions read the same `shared.json` and session files" (`docs/design-docs/providers.md:24`).

observed: today's builds keep provider configs they don't know (`providerConfigs: z.record( z.string(), z.unknown() )`, `packages/common/lib/shared-config.ts:57`). For a chat provider id they don't know, they run chats on the first connected provider, WordPress.com first (`readSelectedAiProvider` in `packages/common/lib/ai-settings.ts`, `resolveInitialAiProvider` in `apps/cli/ai/auth.ts`).

spec-requirement-20: Studio on the web doesn't offer the connector: its AI providers group and its model picker don't show it.

origin: derived Goal; input: Studio on the web runs at `app.wordpress.studio` (`docs/release-process.md:48`), and Ollama 0.40.0 as installed refuses requests from that origin with 403 (`spec/web-origins.txt`). LM Studio and vLLM refuse cross-origin requests by default, and Chrome 142 asks the person before a public site reaches localhost (`spec/server-docs.md`).

observed: Studio on the web already leaves out the connect methods it can't run: `loopbackSignIn: false` (`apps/ui/src/data/core/connectors/static/index.ts:154`) and `getProviderConnectMethods` (`apps/ui/src/features/settings/settings-view/ai-panel.tsx`).

## Acceptance criteria

spec-acceptance-criterion-1: Given Ollama running at `http://localhost:11434` with a chat model, when the person connects the connector with that address from Settings → Providers in the Desktop app and in `studio ui`, then the AI providers group shows the connector as connected with that address, and the Default AI provider setting offers it.

spec-acceptance-criterion-2: Given the connector connected to one local server, when the person connects it again with the address of another, then Settings shows the new address, the model picker offers only the new server's models, and the next turn of a chat on the connector is answered by the new server.

spec-acceptance-criterion-3: Given the connector connected, when the person disconnects it in Settings or with `/disconnect` in `studio code`, then Settings and `/connect` show it as not connected, and neither the model picker nor `/model` offers local models.

spec-acceptance-criterion-4: Given Ollama running, when the person runs `/connect` in `studio code`, picks the connector and enters the address, then `/model` offers the server's models and `/provider` offers the connector.

spec-acceptance-criterion-5: Given a local server run by Ollama, by LM Studio, by `llama-server` or by vLLM, when the person connects the connector with its address, then it connects without asking which product runs the server, and the model picker offers that server's models.

spec-acceptance-criterion-6: Given Ollama listening on `127.0.0.1:11434`, when the person connects with `http://localhost:11434`, `http://localhost:11434/v1`, `http://localhost:11434/v1/` or `127.0.0.1:11434`, then each connects, and the model picker offers the same models.

spec-acceptance-criterion-7: Given Ollama, which takes no key, when the person connects with the key left empty, in Settings and in `/connect`, then the connector connects.

spec-acceptance-criterion-8: Given `llama-server` started with `--api-key`, when the person connects with that key, then the connector connects and a chat on its model gets a reply. When the person connects with no key or a wrong one, then connecting fails with a message saying the server refused the key. In both cases Settings never shows the whole key.

spec-acceptance-criterion-9: Given an address where nothing listens, when the person connects with it in Settings or in `/connect`, then connecting fails with a message that names the address and says no local server answered there, and the connector stays not connected.

spec-acceptance-criterion-10: Given an Ollama server with no models, or an LM Studio server whose only model is the `text-embedding-nomic-embed-text-v1.5` it ships with, when the person connects with its address, then connecting fails with a message saying the server has no chat model yet, and the connector stays not connected.

spec-acceptance-criterion-11: Given the connector connected to Ollama serving `qwen3:0.6b`, `gemma3:270m` and `all-minilm`, when the person opens the composer's model picker and runs `/model`, then both offer `qwen3:0.6b` and `gemma3:270m` by those names, as models of the connector, and neither offers `all-minilm`.

spec-acceptance-criterion-12: Given the connector connected to a running Ollama, when the person adds a model with `ollama pull` and opens the model picker again, then the new model is offered. After `ollama rm`, it isn't.

spec-acceptance-criterion-13: Given a chat on a local model that can call tools, when the person asks Studio Code to add a page to one of their local sites, then the reply streams into the chat and the page exists in the site.

spec-acceptance-criterion-14: Given the connector connected and chosen as the chat provider, with no other provider connected, when the person sends a message in the app and in `studio code`, then the local model's reply appears in the chat, with no request to sign in to WordPress.com or to add AI credits.

spec-acceptance-criterion-15: Given Ollama listing `all-minilm:latest` and `gemma3:270m` before `qwen3:0.6b`, when the person connects the connector and starts a new chat on it without picking a model, in the app and in `studio code`, then the chat starts on `qwen3:0.6b`.

spec-acceptance-criterion-16: Given a chat that ran on a local model the server still lists, when the person reopens it from the app's chat list or with `studio code sessions resume` and sends a message, then the turn runs on that model.

spec-acceptance-criterion-17: Given a chat on Ollama's `gemma3:270m`, or on a model removed from the server, when the person sends a message, then the chat shows an error that names the model, gives the server's reason in words and says to pick another model, with no raw response body and no reply from another provider.

spec-acceptance-criterion-18: Given a chat on a local model whose server has stopped, when the person sends a message, then the chat shows an error that names the server's address, says the local server isn't answering, and says to start it, with no reply from another provider.

spec-acceptance-criterion-19: Given a chat on Ollama's `qwen3:0.6b`, which can't read images, when the agent takes a screenshot, then that turn and the turns after it complete. When the person attaches an image in the composer, then the composer holds it back with the message asking them to choose a model that supports images.

spec-acceptance-criterion-20: Given a chat on a local model that reads images, when the person attaches an image and asks about it, then the reply describes the image.

spec-acceptance-criterion-21: Given Ollama running its model with a 4096-token context, when the person sends the first message of a chat on it, then the chat shows an error saying the model's context is too small for Studio Code and that the server's settings can raise it, and no reply.

spec-acceptance-criterion-22: Given a local model whose context fits Studio Code's turns, when a chat on it grows past that context, then the chat keeps getting replies, and the server never cuts a request short (Ollama's log shows no "truncating input prompt").

spec-acceptance-criterion-23: Given a computer with no internet connection and a chat on a local model, when the person sends a message in the app or in `studio code`, then the turn runs and gets a reply.

spec-acceptance-criterion-24: Given the connector connected in the Desktop app, when the person opens `studio ui` or `studio code`, then the connector is connected there with the same address and models. When the person chooses it as the chat provider in one of the three, then new chats in the other two use it.

spec-acceptance-criterion-25: Given chats on a local model, when Studio records the analytics events for their turns, then no event carries the model's name or the server's address.

spec-acceptance-criterion-26: Given settings in which the connector is connected and chosen as the chat provider, when a Studio build from before this change runs a chat, then the chat runs on another connected provider. When the newer build runs again, then the connector is still connected.

spec-acceptance-criterion-27: Given Studio on the web, when the person opens Settings → Providers and the composer's model picker, then neither offers the connector.

spec-acceptance-criterion-28: Given the connector connected to LM Studio serving a chat model and the `text-embedding-nomic-embed-text-v1.5` it ships with, when the person opens the composer's model picker and runs `/model`, then both offer the chat model and neither offers the embedding model.

## Exclusions

spec-exclusion-1: Studio doesn't install, start or stop a local server, download models into it, or change its settings, such as the context it runs a model with.

spec-exclusion-2: The connector doesn't generate images. Image generation keeps coming from a connected provider that offers it.

spec-exclusion-3: While the computer is offline, the operations that reach an online service, such as publishing to WordPress.com or sharing a preview, keep failing as they do today, whichever model the chat runs on.

## Considered and not required

- Several local servers connected at once, such as Ollama and LM Studio side by side — one connection the person can point at any server meets the Goal, and a provider keeps one connection at a time today (observed: `docs/design-docs/providers.md:79`).
- Reading of the Goal in which the person types the model's name when connecting — every server examined lists the models it serves at `/v1/models` (observed: `spec/ollama-probes.txt`; documented: `spec/server-docs.md`), so Studio offers those, and a name the server doesn't serve gets the refusal of spec-requirement-12.
- Reading of the Goal that offers the connector in Studio on the web for servers that accept its origin — Ollama as installed refuses that origin, and LM Studio and vLLM refuse it by default (observed: `spec/web-origins.txt`; documented: `spec/server-docs.md`). Only `llama-server` accepts any origin by default (read in its source: `spec/web-origins.txt`), so the control would fail on most servers as installed.
- Leaving out of the pickers the models a server says can't call tools, such as Ollama's `gemma3:270m` — such a model is a chat model: Ollama lists its `completion` capability and refuses only the tools (observed: `spec/ollama-probes.txt`). Offering it lets the turn's error (spec-requirement-12) tell the person why Studio Code can't run on it, where leaving it out would hide it with no reason. Only an embedding model is no chat model, and LM Studio ships one the person never chose (observed: `spec/lmstudio-embedding.txt`).
- Reading of spec-requirement-11 in which a new chat starts on the local model the person chose most recently — no provider carries a pick into the next `studio code` run, which starts a new chat on the provider's default (observed: `apps/cli/commands/ai/index.ts:228` at 924a82669). The app keeps a site's new-chat pick only in memory, for every provider (observed: `apps/ui/src/data/queries/use-site-chat-draft.ts:24` and `apps/ui/src/features/chats/session-view/index.tsx:165` at 924a82669). The input that calls for choosing where a new chat starts is a server listing first a model Studio Code can't run on, and the model chosen from what the server lists at connect meets it.
- Reading of spec-requirement-11 in which a new chat's starting model follows the models pulled or removed after connecting — the picker follows them (spec-requirement-8). A turn on a removed model ends saying to pick another (spec-requirement-12), and connecting again chooses from what the server then lists (spec-requirement-1).
- Completing a turn that carries an image the person attached, on a local model that can't read images — the composer holds such attachments back for the built-in models that can't read images (observed: `apps/ui/src/features/composer/composer.tsx:388`), and the connector follows it.
- Finding local servers on the computer or the network without the person giving an address — every Studio provider connects from Settings or `/connect` (observed: `spec/providers.txt`, `apps/cli/ai/slash-commands.ts:268`).
- A provider the person writes or loads for their own server — the Goal asks for one generic connector, and providers are compiled into Studio (observed: `docs/design-docs/providers.md:149`).
- The address of a hosted service that answers the same two requests, such as OpenRouter — the intent asks for local LLM providers.
- A server that answers only another API, such as Ollama's own `/api/chat` or Anthropic's Messages API — every server examined documents `/v1/models` and `/v1/chat/completions` (`spec/server-docs.md`).
- A local server serving hosting, previews or sync — the connector is an AI provider, and hosting providers are a separate group in Settings (observed: `spec/providers.txt`).
- Chats through `studio mcp` — the agent apps that use Studio through MCP chat on their own models (observed: only `studio code` and its eval harness open a chat model connection, `resolveAiConnection` in `apps/cli/commands/ai/index.ts:591` and `apps/cli/ai/eval-harnesses/studio.ts:164`).

## Open assumptions

spec-assumption-1: On every local server, Studio can learn the context the server runs a model with, or the fact that a turn didn't fit in it. This is what spec-requirement-15 rests on. — assumed: confirmed once the design names how Studio learns it for Ollama, LM Studio, `llama-server` and vLLM, and a turn on Ollama with a 4096-token context shows the error.

spec-assumption-2: On every local server, Studio can learn whether a local model reads images (spec-requirement-14). — assumed: confirmed when a turn holding a screenshot completes on Ollama's `qwen3:0.6b`, and a model Ollama lists with the `vision` capability describes an attached image.

spec-assumption-3: A Studio Code turn on a local model needs nothing from the internet (spec-requirement-16). — assumed: confirmed when a turn on a local model completes with the computer's network off.

spec-assumption-4: Studio Code's tools work through a local model that can call tools (spec-requirement-9). — assumed: confirmed when a turn on such a model adds a page to a local site.
