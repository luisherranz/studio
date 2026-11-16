# Design Doc: Generic connector for local LLM providers

## Overview

Studio Code chats only through providers whose models are lists compiled into Studio. The change adds one more AI provider to `@studio/providers`: the local LLM connector, `local-llm`. Its account is the address of a server the person runs, plus a key when the server asks for one, and its models are the ones that server lists at `/v1/models`, less those it says only make embeddings. Because it is a provider, the registry carries it into Settings, `/connect`, `/disconnect`, `/provider`, the Default AI provider setting, `shared.json` and the chat fallback rules, without those surfaces knowing it. What's new is what no built-in provider needs. Models are read from the server rather than compiled in, and Studio doesn't know their ids in advance. Whether a model reads images, and the context the server runs it with, come from the server. The server may cut a request silently. The provider works offline, and Studio on the web can't reach it.

The connector's services talk to the server over the OpenAI-compatible API that Ollama, LM Studio, llama-server and vLLM all document. They read a product's own API at the server's root only for what `/v1` doesn't say: whether a model only makes embeddings, can call tools or reads images, and its running context. The descriptor states one new fact that surfaces read: the provider's models are the ones a server the person runs lists. From it, surfaces derive the live model listing, sending while offline, and keeping model names out of analytics. A local model's Studio id carries the connector's id and the server's name for the model. So every place that turns a model id into a provider and a label keeps working without reaching the server. The runtime gains a contract for connections whose context window is exact: compaction fits inside the window, a request never exceeds it, and a turn that can't fit ends in the connection's own words.

## Architecture

New:

- `packages/providers/local-llm/`: the connector's descriptor (label, description, one connect form, the statement that a server the person runs lists its models), its config schema, and its services: `account.connect`, a model listing, and the model connection. It is registered in `registry.ts` and `services.ts`.

Modified:

- `packages/providers` root: the provider ids (`ProviderId`, `AiProviderId`, `AI_PROVIDER_IDS`, stored ids), `AiModelId`, `findAiModel`, default-model resolution, one served-model check, `Provider.ai`, `AccountDetails`, `ConnectMethod`, `ConnectField`, `AiConnection`, and the services' `ai` group.
- `packages/common`: `provider-config.ts` (the connector's store in `providerConfigs`) and `ai-settings.ts` (the model listing operation).
- `packages/agent`: `shared/models.ts` (the connection stream refuses a request the exact window can't hold), `node/runtime/index.ts` (compaction sized to the window, and the wording of a turn that ends on an overflow), and `protocol/sessions/model.ts` (the served check and the default for a new chat).
- `apps/cli`: `commands/ai/index.ts` (the served check, the default model, and the Tracks `model` value), `ai/slash-commands.ts` (`/model` lists the server's models; `/provider` starts on the connector's default), and `lib/providers.ts` (optional fields in the terminal form).
- `apps/studio`: an IPC handler and preload entry for the model listing, and the session model and provider-pin handlers, which accept connector ids.
- `apps/local`: a route for the model listing, and the same session model and provider-pin changes.
- `apps/ui`: the `ipc` and `local` connectors (the listing method; `static` has none), the Settings provider row, the settings search, the composer's model picker, the composer's image and offline gates, and the new-chat default model.
- Docs: `docs/design-docs/providers.md`, `docs/design-docs/analytics-tracks.md` and `packages/providers/README.md` describe the contracts this changes.

Untouched but relevant:

- pi's `openai-completions` stream. It turns image blocks into placeholders for a model whose `input` lacks images, and it clamps output to the window. It also retries transient errors, recognises context-overflow errors, and compacts and retries once.
- `withErrorRewrite`, which applies a connection's `rewriteError` before pi decides whether to retry.
- `take_screenshot` and `inspect_design`, which follow the connection's `model.input`.
- The run manager, which forks `studio code sessions resume <id> --json` for every chat in the apps, so the CLI decides each turn's provider and model.
- `connectProvider`, `disconnectProvider`, `setAiProvider`, `getEffectiveSessionProvider`, `resolveInitialAiProvider` and `resolveImageGenerator`: they are generic over `AI_PROVIDER_IDS` and take the connector in as they stand.

Contracts this widens, and what each consumer newly admits:

- **`AiModelId` admits connector ids (decision 5).**
  - Every caller of `findAiModel` gets the connector and the server's name: the labels in the picker, the CLI's status line and the family-switch dialog, and the eval harness's provider lookup.
  - `isModelLocked` reads no paid-credit requirement, so a local model is never locked.
  - `getModelDescription` has no description for a local model, so the picker shows only the provider.
  - The composer's image gate would read "reads images" for a local model, so decision 10 changes it.
  - The session validators and `readRecordedSessionModel` keep a local model's id.
- **`Provider.ai` may have no model list and no default (decisions 4 and 6).** `getAiModels` returns none for it. `getDefaultAiModel` and `resolveSessionModelForProvider` take the account. The served checks become the one shared check. The picker and `/model` read the listing.
- **`AccountDetails.summary` may be an address (decision 3).** The secret field's placeholder, which showed it, stops showing it.
- **`ConnectField` may be optional (decision 2).** Settings' Save rule and the terminal prompt accept it empty.
- **`ConnectMethod` may be host-only (decision 13).** The web's method filter and the settings search's native-only mark leave it out.
- **`AiConnection` may state an exact window (decision 9).** Only the runtime reads the statement. Connections without it behave as today.

The offline gate of `useComposerNotice` narrows to providers whose models need the internet (decision 11). No component or responsibility is left without a purpose.

Data flow:

1. **Connecting.** The Settings form or `/connect` calls `connectProvider` in `@studio/common`, through the IPC handler, the `apps/local` route, or the CLI directly. That calls the connector's `account.connect`, which lists the server's models, proposes the one new chats start on, and returns the config. Studio stores the config in `shared.json` under `providerConfigs`.
2. **Listing.** The model picker, through the connector method and then the IPC handler or `apps/local` route, or `/model` directly, calls the listing operation in `@studio/common`. It reads the stored config and calls the connector's listing. That reads `/v1/models`, plus per-model facts from the server, leaves out the models the server says only make embeddings, and returns plain data per model.
3. **A turn.** The app forks the CLI. The CLI resolves the provider (the session's pin, else the shared selection) and the model (the session's record, else the model the account proposed at connect). It then calls the connector's `ai.model( config, id )`, which learns the model's image support and running context (having Ollama or LM Studio load the model first, as a request would). That returns an `AiConnection`: plain Chat Completions to the server's `/v1` base, with an exact window and the connector's error wording. The runtime registers it with pi, and pi streams the turn from the server.

## Decisions

design-doc-decision-1: The connector is one AI provider, `local-llm`, in `@studio/providers`

**Serves:** spec-requirement-1, spec-requirement-2, spec-requirement-3, spec-requirement-10, spec-requirement-17, spec-acceptance-criterion-1, spec-acceptance-criterion-3, spec-acceptance-criterion-4, spec-acceptance-criterion-14, spec-acceptance-criterion-24

**Decision:** The connector is a provider registered like the others. It joins `ProviderId`, `AiProviderId`, `ProviderConfigs`, the registry and the services. It comes last in `AI_PROVIDER_IDS`, which is the fallback order, so WordPress.com stays first. It is stored under its own id, with no legacy mapping. That id, `local-llm`, is persisted: in `shared.json`'s `aiProvider` and `providerConfigs`, in session pins, and in the Tracks `provider` property. It is also what `/connect local-llm` takes. Its config lives in `providerConfigs` through `provider-config.ts`, as OpenAI's does. It has one connect method (decision 2), no image generation and no remote sites. Its label and description name no product.

Everything the registry drives then includes it:

- Settings' AI providers group and the Default AI provider setting.
- `/connect`, `/disconnect`, `/provider`, and the first-run "Choose how to connect".
- Becoming the default on connect when the current default isn't connected, and the fallback on disconnect.
- The effective provider of a chat.
- Image generation from another connected provider.

**Alternatives:**
- A base-URL field on OpenAI's API-key form. OpenAI's models are a fixed list and its key is required. Local servers couldn't be connected alongside OpenAI. The form would still need decisions 4 to 9.
- One provider per product (Ollama, LM Studio and so on). The spec allows asking only for the address and key, never the product, and the four products share one API.
- Providers the person defines while Studio runs. Both providers.md and the spec's "Considered and not required" put these out of scope.

**Trade-offs:** The registry assumes each provider has a model list, a default model, and model ids known at build time. One provider now breaks all three assumptions, and decisions 4, 5, 6 and 9 widen those contracts. The person types the id in `/connect local-llm`.

**Claims:**

- observed: a registered provider "shows up in the settings and in `studio code`'s `/connect` on its own" (read in `packages/providers/README.md`, "Adding a provider").
- observed: `connectProvider` makes a newly connected AI provider the selected one when the current selection has no config (`packages/common/lib/ai-settings.ts`).
- observed: `resolveImageGenerator` asks every AI provider in turn and skips those without image generation (`apps/cli/ai/auth.ts`).

design-doc-decision-2: The connect form takes an address and an optional key, and connecting checks the server by listing its models

**Serves:** spec-requirement-1, spec-requirement-2, spec-requirement-4, spec-requirement-5, spec-requirement-6, spec-acceptance-criterion-2, spec-acceptance-criterion-6, spec-acceptance-criterion-7, spec-acceptance-criterion-8, spec-acceptance-criterion-9, spec-acceptance-criterion-10

**Decision:**

- The connector's one method is a form with two string fields: the server's address, which is required and not secret, and a key, which is optional and secret.
- `ConnectField` gains whether the field is required, read from its schema: a field whose schema accepts an empty value is optional. Settings enables Save once every required field has a value. The terminal form accepts an empty answer for an optional field.
- `account.connect` reads the address as follows. An address without a scheme is `http://`. If its path ends at `/v1`, with or without a trailing slash, the address is the API base; otherwise the API base is the address with `/v1` added.
- It then lists the models at the API base as the listing does (decision 4). It sends the key as a Bearer token only when one is given. If the listing offers a model, it returns the config: the API base, the key when given, and the model it proposes for new chats (decision 6). Otherwise it throws `ConnectError`:
  - When nothing answers, or the answer isn't a model list, the message names the address and says no local server answered there.
  - On 401 or 403, the message says the server refused the key. This covers a missing key and a wrong one.
  - When the server lists no model, or only models it says only make embeddings, the message says the server has no chat model yet.
- Connecting again replaces the config. Every turn reads the config, so the next turn goes to the new server.
- `describe( config )` gives the server's address as the summary: the API base without `/v1`. It never gives the key.
- Like every provider's form, the form starts empty each time it opens, connected or not.

**Alternatives:**
- Ask only for the address, and support only servers without a key. LM Studio, llama-server and vLLM can each require a Bearer key.
- Try the address at both its root and `/v1`, and keep whichever lists models. Every server examined lists models under `/v1`, so the single rule covers each form the servers print or document with one request.
- Accept the address without contacting the server, as Anthropic accepts a key it can't verify. spec-requirement-6 asks connecting to fail when nothing lists models.
- Start the form with the current address when the connector is connected, through `AccountDetails` giving the current values of the connected method's fields that aren't secret. That would be a new contract serving one field of one provider. Changing the address means typing the new one anyway. Changing only the key means typing the address the row already shows above the form (decision 3), and the key itself always has to be typed again.

**Trade-offs:**

- A server that guards chat but not its model list accepts a wrong key at connect. The first turn then fails with the key-refused message (decision 8).
- Connecting needs the server to be running.
- Connecting again to change only the key means typing the address again.

**Claims:**

- observed: Ollama answers `GET /models` with 404, so it lists models only under `/v1`. It lists `"data":null` before any model is pulled, and accepts a request whatever key it carries (spec `ollama-probes.txt`).
- observed in source, not run: llama-server answers a missing or wrong key with 401 and guards `/v1/models`. vLLM answers 401 `{"error": "Unauthorized"}`. LM Studio documents no status; community reports show 401 (`design-doc/server-capability-docs.md`).
- observed: Settings enables Save only once every field has a value (`apps/ui/src/features/settings/settings-view/ai-panel.tsx:61`). The terminal form checks each field against its schema, and connects when the last field is entered (`apps/cli/lib/providers.ts`). Both at 924a82669.
- observed: LM Studio ships the embedding model `text-embedding-nomic-embed-text-v1.5`, so before the person downloads a chat model its server lists only that one (spec `lmstudio-embedding.txt`).

design-doc-decision-3: A connected provider's row in Settings shows its summary, and secret fields never show it

**Serves:** spec-requirement-1, spec-requirement-5, spec-acceptance-criterion-1, spec-acceptance-criterion-8

**Decision:** For every provider, while its account is connected, its row in Settings shows the summary that the provider's `describe` gives, in place of the provider's description. For the connector, that is the server's address. A secret field's placeholder no longer shows the account summary, because the connector's summary is an address, not its key. The placeholder shows the field's example instead.

**Alternatives:**
- Show the summary only on the connector's row. Surfaces must not branch on a provider id (providers.md, principle 2), and providers.md already says Settings shows each provider's summary.
- Keep the summary in the secret field's placeholder, and add the address elsewhere. The connector's key field would then show the server's address.
- Add a preview per form field to `AccountDetails`. That is a new contract for a single placeholder.

**Trade-offs:** This changes every connected provider's row, not only the connector's. The Anthropic, OpenAI (API key) and Gemini rows show the key's first and last characters on the row, in place of the provider's description, and their empty key field shows the key's example. The row stays above the form while it is open, so the preview stays in view. The ChatGPT and Copilot rows gain the account's email or login.

**Claims:**

- observed: `ProviderRow` showed `account.summary` only as a secret field's placeholder, and its row description was the descriptor's (`ai-panel.tsx:213`, at 924a82669).
- observed: providers.md says the settings list every provider with "a summary the provider gives" (`docs/design-docs/providers.md:87`).

design-doc-decision-4: Models are read from the server whenever a picker opens, and nothing stores the list

**Serves:** spec-requirement-7, spec-requirement-8, spec-requirement-17, spec-acceptance-criterion-2, spec-acceptance-criterion-3, spec-acceptance-criterion-4, spec-acceptance-criterion-5, spec-acceptance-criterion-11, spec-acceptance-criterion-12, spec-acceptance-criterion-24, spec-acceptance-criterion-28

**Decision:**

- The descriptor's `ai` states that the provider's models are the ones a server the person runs lists. Decisions 11 and 12 read the same fact. Such a provider has no fixed model list and no fixed default, and `getAiModels` returns none for it.
- The connector's services gain an `ai` operation that lists the models the server offers now, as plain data per model: its Studio id (decision 5), the server's name for it, and whether it reads images (decision 7). It offers every model the server lists at `/v1/models`, in the server's order, except those the server says only make embeddings (decision 7). A model the server says nothing about is offered. When the server doesn't answer, the operation fails in the not-answering words of decision 8.
- `@studio/common` gains the operation surfaces call. It takes the provider's services and reads the stored config, as `connectProvider` does. The Desktop main process exposes it through an IPC handler and `apps/local` through a route, both thin wrappers around it.
- The `Connector` gains an optional method for it, implemented by `ipc` and `local` and absent from `static`; decision 13 keeps the web from needing it. `/model` in `studio code` calls the common operation directly.
- For each connected provider whose models a server lists, the composer's model picker shows that method's result, read again each time the picker opens. `/model` reads the list each time it runs.
- When the listing fails, the picker offers none of the connector's models, and the chat keeps its current model.

**Alternatives:**
- Store the list in the config at connect, and renew it in `refresh`, as GitHub Copilot does with its plan's models. The list would go stale between renewals, `refresh` runs only when a host uses the config, and every renewal would write `shared.json`. AGENTS.md prefers reading cheap derived data on demand to persisting a mirror of it.
- Have the renderer fetch the server's list itself. The Desktop renderer is sandboxed, and LM Studio and vLLM refuse cross-origin requests by default.
- Poll the server in the background. The spec asks for the list to be fresh when the picker opens, which polling doesn't guarantee and reading on open does.
- Offer every model the server lists, and let a turn's refusal tell the person. LM Studio ships an embedding model that every LM Studio server lists, and its refusal of a chat on it reads "No models loaded…".
- Also leave out the models the server says can't call tools. The spec keeps them offered, so the turn's error says why Studio Code can't run on them (spec-requirement-12).

**Trade-offs:** Opening the picker makes a request to the server, plus Ollama's per-model capability reads, so a slow server delays the connector's models in the picker. providers.md's "the pickers never reach the service to build their list" no longer holds for providers whose models a server lists.

**Claims:**

- observed: Ollama lists a model pulled while it runs right away (spec `ollama-probes.txt`).
- observed: the picker builds its list synchronously from `getAiModels` (`apps/ui/src/features/composer/model-picker.tsx`), and so does `/model` (`apps/cli/ai/slash-commands.ts:399`), at 924a82669.
- observed: LM Studio 0.4.28's `/v1/models` lists its bundled `text-embedding-nomic-embed-text-v1.5` beside the chat model, and answers a chat on it with HTTP 400 "No models loaded. Please load a model in the developer page or use the 'lms load' command." (spec `lmstudio-embedding.txt`).
- observed: `connectProvider` takes a provider's services as a parameter, so `@studio/common` never imports them (`packages/common/lib/ai-settings.ts`).

design-doc-decision-5: A local model's Studio id is the connector's id followed by the server's name for it

**Serves:** spec-requirement-7, spec-requirement-11, spec-requirement-19, spec-acceptance-criterion-11, spec-acceptance-criterion-16

**Decision:**

- Besides the built-in ids, `AiModelId` admits ids made of the connector's id, a fixed separator, and the server's name for the model, verbatim. Model ids remain what sessions record.
- `findAiModel` resolves such an id to the connector, and to a model labelled with the server's name, without reaching the server. It says nothing about whether the model reads images.
- One shared check answers whether a provider serves an id: membership in its list for a built-in provider, and the connector's prefix for the connector. It replaces the separate list checks in the CLI's resume and provider switch, in `resolveSessionModelForProvider`, and in the Desktop and `apps/local` validators for a session's provider pin.
- The connection sends the server's name on the wire (`requestModelId`), so pi and the session history keep the Studio id.

**Alternatives:**
- Use the server's name as the id. Every lookup that needs only an id today would need the provider, or a request to the server: `findAiModel` in the session-model validators, `readRecordedSessionModel`, and the labels in the CLI's status line and the family-switch dialog. A server could also list a name equal to a built-in id, which breaks "the same id means the same model".
- Use an opaque id, such as a hash or an index. The label and the name sent on the wire would then need a stored mapping.

**Trade-offs:** The id's format is persisted forever. A Studio id differs from the server's name for the model, so a surface that prints ids, such as `/model`'s option descriptions, shows the label instead.

**Claims:**

- observed: the session-model validators reject an id `findAiModel` doesn't know (`apps/studio/src/ipc-handlers.ts:365`, `apps/local/src/index.ts:2213`).
- observed: the provider-pin validators and the resume checks test the descriptor's list (`apps/studio/src/ipc-handlers.ts:381`, `apps/local/src/index.ts:2231`, `packages/agent/protocol/sessions/model.ts:70`, `servesModel` in `apps/cli/commands/ai/index.ts:78`).
- observed: `requestModelId` already renames the model on the wire for WordPress.com and GitHub Copilot (`packages/agent/shared/models.ts`).

design-doc-decision-6: New chats on the connector start on the model proposed at connect, and recorded chats keep theirs

**Serves:** spec-requirement-11, spec-requirement-17, spec-acceptance-criterion-2, spec-acceptance-criterion-15, spec-acceptance-criterion-16, spec-acceptance-criterion-24

**Decision:**

- For a provider whose models a server lists, `AccountDetails` gives the model a new chat on the account starts on when the person hasn't picked one.
- The connector's config records that model at connect. It is the first model the listing offers (decision 4) that the server says can call tools. When the server says that of none, it is the first model the listing offers. It changes only when the person connects again.
- `getDefaultAiModel` and `resolveSessionModelForProvider` take the account to resolve a new chat's model on such a provider. The CLI's start, the `/provider` switch and the app's new-chat composer use them.
- A model the person picks for a chat, in the composer or with `/model`, runs that chat, as on every provider.
- A chat that recorded a local model keeps it on resume, whatever the server lists, while the connector serves the id (decision 5). If the server no longer has the model, the turn ends with the refusal of decision 8.

**Alternatives:**
- Start new chats on the person's most recent pick, kept by Studio in `shared.json`. spec-requirement-11 asks for the model chosen at connect, and no provider carries a pick into the next chat.
- Choose the model each time a new chat starts, from what the server lists then. Every new-chat composer and every `studio code` start would wait on the server, and the spec doesn't ask the starting model to follow the models pulled after connecting.
- Propose no model at connect, and start on the first model the server lists. Ollama lists its most recent pull first. In the spec's probe that was an embedding-only model, followed by one that can't call tools.

**Trade-offs:**

- If the proposed model is removed from the server, a new chat's first turn gets the "pick another model" error, until the person picks another model or connects again.
- On llama-server and vLLM, which don't say whether a model can call tools, the proposal is the first model the server lists.
- Checking the server's list on resume was considered and dropped, because the refusal already tells the person.

**Claims:**

- observed: before this change, a new chat started on `getDefaultAiModel`, which throws for a provider with no AI models (`packages/providers/models.ts:51`, at 924a82669).
- observed: the app pins a new chat's provider and model through `setSessionProvider` (`apps/ui/src/features/chats/session-view/use-send-site-draft.ts`).
- observed: Ollama 0.40.0 lists `all-minilm:latest`, `gemma3:270m` and `qwen3:0.6b` in that order. Its own API reports `all-minilm` as `embedding` only, `gemma3:270m` as `completion`, and `qwen3:0.6b` as `completion`, `tools` and `thinking`. It refuses tools on `gemma3:270m` (spec `ollama-probes.txt`).
- observed in docs, not run: LM Studio reports `capabilities.trained_for_tool_use` per model (`design-doc/server-capability-docs.md`).

design-doc-decision-7: The connector learns each model's kind, image support and running context from what the server reports, never from the person

**Serves:** spec-requirement-3, spec-requirement-6, spec-requirement-7, spec-requirement-11, spec-requirement-14, spec-requirement-15, spec-acceptance-criterion-5, spec-acceptance-criterion-10, spec-acceptance-criterion-11, spec-acceptance-criterion-15, spec-acceptance-criterion-19, spec-acceptance-criterion-20, spec-acceptance-criterion-21, spec-acceptance-criterion-28

**Decision:**

- For each model, the connector's services read what the server reports. They read the model's `/v1/models` entry first, then the product APIs the server answers at its root, without asking which product runs it. The sources for the four servers are under Claims.
- A model only makes embeddings when the server says it can do nothing else: Ollama's capabilities list only `embedding`, or LM Studio's type is `embedding`. The listing leaves such models out (decision 4).
- A model can call tools only when the server says so, through Ollama's capabilities or LM Studio's tool-use capability. The proposal at connect reads this (decision 6).
- The model reads images only when the server says so.
- The context the server runs the model with is needed only for a turn. Ollama and LM Studio report it only once the model is loaded. When it isn't loaded, the connector has the server load it before the turn, the way the turn's own request would:
  - Ollama, through a request that names only the model.
  - LM Studio, through a request on its OpenAI-compatible API, never through its load API. The model is then loaded on request, and keeps the idle TTL and auto-evict LM Studio gives such models.
- The listing (decision 4) carries image support. The model connection carries image support and the context: `model.input` includes images only when the server says the model reads them, and the connection's window is exact when the context is known (decision 9).
- When a server reports no context, its connection has no exact window, and the server's own refusal ends a turn that is too large. This applies to servers Studio doesn't know.

**Alternatives:**
- Load LM Studio's model through its load API. A model loaded that way gets no idle TTL and isn't auto-evicted. Every model a person picks in Studio would stay in memory until they unload it, where a model loaded on request is unloaded after 60 idle minutes, or when another model loads on request.
- Leave LM Studio's model to the turn's own request, and give every connection the context-too-small words, exact window or not. The first turn would get the words. But its compaction couldn't size itself to the window: a first turn that outgrows it would rely on pi's one compact-and-retry with today's sizes, which keep the last 20,000 tokens, more than LM Studio's default 8,192-token context.
- Use only what `/v1` says. Ollama's `/v1/models` says nothing about context or images, and Ollama cuts a request that is too large silently, so spec-acceptance-criterion-21 couldn't hold.
- Ask the person for the context and for whether the model reads images. spec-requirement-3 allows asking only for the address and the key.
- Detect a cut request after the reply, from the prompt tokens the server reports. By then the reply has already streamed into the chat.
- Set the context per request through Ollama's own chat API. spec-exclusion-1 rules out changing the context, and Ollama would need a transport of its own.
- Assume every model reads images, and retry without them when the server refuses. The composer has to hold attachments back before sending (spec-acceptance-criterion-19).

**Trade-offs:**

- The generic connector carries knowledge of two products' own APIs (Ollama's and LM Studio's), and of fields two servers add to `/v1/models`. A server product Studio doesn't know gets the safe defaults until it is added.
- vLLM never says whether a model reads images, so its vision models get no images.
- llama-server and vLLM never say what kind a model is, so an embedding model they list is offered, and a chat on it gets the server's refusal (decision 8).
- A turn on Ollama or LM Studio whose model isn't loaded starts by loading it. On LM Studio, that load produces a minimal reply nobody reads.

**Claims:**

- observed: Ollama 0.40.0's `/v1/models` entry has only `id`, `object`, `created` and `owned_by`. `/api/show` reports the model's capabilities, and its trained context (40960) rather than its running one. `/api/ps` reports the running context (4096) once the model is loaded. A `POST /api/generate` naming only the model loads it, answering `"done_reason":"load"` in 0.54 s (`design-doc/ollama-context-probes.txt`).
- observed: Ollama's OpenAI-compatible endpoint cuts a request that is too large even with `"truncate": false`. It streams 20 chunks of the reply before the last chunk's usage reveals `prompt_tokens: 2050` of 24,408 (`design-doc/ollama-context-probes.txt`).
- observed in source and docs, not run (`design-doc/server-capability-docs.md`):
  - llama-server: `architecture.input_modalities` and `meta.n_ctx` in `/v1/models`.
  - vLLM: `max_model_len` in `/v1/models`, and no field about images.
  - LM Studio: `capabilities.vision`, `capabilities.trained_for_tool_use`, and a loaded instance's `context_length`, in `/api/v1/models`.
- observed: LM Studio 0.4.28's `/api/v1/models` gives `qwen3-0.6b` the type `llm` and `text-embedding-nomic-embed-text-v1.5` the type `embedding`. Ollama 0.40.0's `/api/show` lists `all-minilm`'s only capability as `embedding`, and Ollama refuses to chat on it with "does not support chat" (spec `lmstudio-embedding.txt`, `ollama-probes.txt`).
- observed: LM Studio 0.4.28 reports no loaded instance, and so no running context, before a request loads the model (`design-doc/lmstudio-load-probes.txt`):
  - Loaded by a chat request on `/v1`, the model's instance reports its context (8,192), `lms ps` shows a 60-minute idle TTL, and a request that loads another model unloads it. A later chat request reuses the same instance.
  - Loaded through `POST /api/v1/models/load`, it has no TTL, and stays loaded when another model loads.
- observed: pi turns image blocks into placeholders for a model whose `input` lacks images (`node_modules/@earendil-works/pi-ai/dist/api/transform-messages.js`), and Studio's vision-dependent tools follow `model.input` (`packages/agent/node/runtime/index.ts:220`).

design-doc-decision-8: The connection speaks plain Chat Completions, and turn errors say what happened in the connector's words

**Serves:** spec-requirement-9, spec-requirement-10, spec-requirement-12, spec-requirement-13, spec-acceptance-criterion-8, spec-acceptance-criterion-13, spec-acceptance-criterion-14, spec-acceptance-criterion-17, spec-acceptance-criterion-18

**Decision:**

- The connector's `ai.model( config, id )` returns an `AiConnection` to the server's `/v1` base, over the `openai-completions` API, with the key or none. It sends the plain Chat Completions shape that the WordPress.com `fast` tier sends: no OpenAI-only fields, streamed with usage.
- Its `rewriteError` words these failures, before pi decides whether to retry:
  - When the server doesn't answer (connection refused, reset or timed out), the message names the address, says the local server isn't answering, and says to start it.
  - On 401 or 403, the message says the server refused the key, and to connect again with the right one.
  - On any other 4xx refusal that isn't a context overflow, the message names the model, gives the server's reason in words drawn from its error body, and says to pick another model.
- It leaves context-overflow refusals, 429 and 5xx untouched, so pi compacts or retries them. A llama-server that is still loading answers 503.
- No other provider answers in the connector's place. The connector stays connected while its server is down. The CLI falls back only from a WordPress.com that isn't connected, and the app's effective provider falls back only from a provider that isn't connected, so neither moves the chat.

**Alternatives:**
- Keep pi's default request shape, which it infers from the base URL as OpenAI's. That adds OpenAI-only fields that local servers may reject, and Studio already spells out the plain shape for `fast`.
- Word the errors in the surfaces instead. The provider owns how its failures read (providers.md, "Connection"), and both surfaces already show the rewritten text.
- Retry a server that doesn't answer. A stopped local server stays stopped. The rewritten text is not one pi retries, so the turn ends at once.

**Trade-offs:** A 4xx caused by the request rather than the model also reads as "pick another model", though it shows the server's reason. A local server that restarts mid-turn ends the turn instead of being retried.

**Claims:**

- observed: the body Studio Code sends to the `fast` tier (`model`, `messages`, `stream`, `stream_options`, `max_tokens`, `tools`) gets HTTP 200 from Ollama 0.40.0 (spec `studio-code-request.txt`).
- observed: Ollama's `qwen3:0.6b` answers an offered tool with a call to it. Ollama answers 400 for a model that doesn't support tools or chat, and 404 for one it doesn't have (spec `ollama-probes.txt`).
- observed: `withErrorRewrite` runs before pi's retry decision (`packages/agent/shared/runtime-guards/error-rewrite.ts`). pi retries `connection error`, `fetch failed`, 429 and 5xx (`node_modules/@earendil-works/pi-ai/dist/utils/retry.js`).
- observed: `resolveUnavailableAiProvider` falls back only from WordPress.com (`apps/cli/ai/auth.ts`), and `getEffectiveSessionProvider` only from a provider that isn't connected (`packages/agent/protocol/sessions/model.ts`).
- assumed: LM Studio, llama-server and vLLM accept the same request shape (design-doc-assumption-2).

design-doc-decision-9: A request never exceeds the context the server runs the model with

**Serves:** spec-requirement-15, spec-acceptance-criterion-21, spec-acceptance-criterion-22

**Decision:** `AiConnection` gains an optional statement: its `model.contextWindow` is exactly the context the server runs the model with, and a turn that can't fit ends with the words the statement gives. The connector gives the statement whenever decision 7 learned the context. Its words say the model's context is too small for Studio Code, and that the server's settings can raise it.

For a connection with this statement, the runtime:

- Sizes compaction to fit the window, so a conversation compacts before a request outgrows it. Today's fixed sizes stay for windows they fit.
- Never sends a request that its token estimate says the window can't hold. It fails that request as a context overflow, which pi recovers from by compacting and retrying once.
- Ends a turn that still fails on a context overflow, whether its own or the server's refusal, with the connection's words, replacing pi's or the server's text.

Connections without the statement, which includes every built-in provider's, behave as today.

**Alternatives:**
- Rely on pi's overflow handling alone. It catches servers that refuse, but Ollama answers a cut request with HTTP 200 and a reply.
- Check only a chat's first turn. A conversation that grows past the limit is cut all the same (spec-acceptance-criterion-22).
- Word the overflow in `rewriteError`. pi would no longer recognise it as an overflow, so it wouldn't compact and retry a conversation that had only grown. The words are also translated, so they can't be matched.
- Size compaction to the window for every provider. That changes the built-in providers' compaction.

**Trade-offs:** The guard trusts a token estimate, and one that under-counts lets a cut request through on Ollama (Risks). A model with a small window compacts often. A window smaller than Studio Code's base request refuses every turn, and the spec asks for the person to be told exactly that.

**Claims:**

- observed: Studio's compaction reserves, and keeps, fixed token counts sized for 200,000-token windows (`STUDIO_COMPACTION_SETTINGS`, `packages/agent/node/runtime/index.ts:52`).
- observed: pi clamps a request's output to the window using its estimate (`node_modules/@earendil-works/pi-ai/dist/api/simple-options.js`). It recognises overflow errors, including llama.cpp's and LM Studio's (`.../pi-ai/dist/utils/overflow.js`). It compacts and retries once, then reports "Context overflow recovery failed…" (`node_modules/@earendil-works/pi-coding-agent/dist/core/agent-session.js`).
- observed: Studio Code's first turn is 11,299 tokens on `qwen3:0.6b` for a 54,017-character body (spec `studio-code-request.txt`). pi's estimate counts 3.5 characters per token (`.../pi-ai/dist/utils/estimate.js`), so it over-counts that request.
- assumed: compaction sized to a window larger than Studio Code's base request keeps a long chat getting replies with nothing cut (design-doc-assumption-1).

design-doc-decision-10: Images on a local model follow what the server says

**Serves:** spec-requirement-14, spec-acceptance-criterion-19, spec-acceptance-criterion-20

**Decision:** For a provider whose models a server lists, the composer learns whether the chat's model reads images from the listing (decision 4), not from `findAiModel`. Until the listing says the model reads images, the composer holds attached images back with today's message asking for a model that supports images. The connection's `model.input` follows the same fact (decision 7). So a text-only local model gets screenshots and earlier images as pi's placeholders, and a local model that reads images gets them as images.

**Alternatives:**
- Use `findAiModel`'s `supportsImages`, which defaults to true. A text-only local model would be sent the attachments, and the server would refuse the turn: Ollama answers 400 "Multimodal data provided, but model does not support multimodal requests."
- Let the turn fail and tell the person. The spec asks the composer to hold the attachments back, as it does for built-in models that can't read images.

**Trade-offs:** A model that reads images, on a server that doesn't say so (vLLM), can't take attachments.

**Claims:**

- observed: the composer holds images back when `findAiModel( model )?.model.supportsImages === false` (`apps/ui/src/features/composer/composer.tsx:388`).
- observed: `AiModel.supportsImages` defaults to true (`packages/providers/types.ts`).

design-doc-decision-11: Chats on the connector send while offline

**Serves:** spec-requirement-16, spec-acceptance-criterion-23

**Decision:** The composer's two offline notices — the computer being offline, and the AI-credit check failing because it is — apply only to chats on providers whose models need the internet. A provider whose models a server the person runs lists doesn't need it. Nothing in `studio code` blocks sending while offline. Operations that need the internet keep failing as they do today (spec-exclusion-3).

**Alternatives:**
- Add a separate descriptor flag for offline use. The fact decision 4 reads already decides it: the models are on a server the person runs.
- Check whether the server answers instead of reading the offline state. The turn's own error (decision 8) already covers a server that doesn't answer.

**Trade-offs:** A connector pointed at a server on another computer still sends while offline. If the network to that computer is down, the turn ends with the not-answering error.

**Claims:**

- observed: `useComposerNotice` blocks every provider while offline, and when the AI-credit check fails offline (`apps/ui/src/features/composer/use-composer-notice.ts:62`, `:65`).
- assumed: a turn on a local model needs nothing from the internet (spec-assumption-3).

design-doc-decision-12: Analytics carry neither a local model's name nor the server's address

**Serves:** spec-requirement-18, spec-acceptance-criterion-25

**Decision:** For a chat on a provider whose models a server the person runs lists, `studio_code_message_sent` and `studio_code_turn_completed` carry a fixed `model` value that names no model. `provider` and `model_family` carry the connector's id. No event gains the address. The connector's error texts name the address and the model, and they stay out of events, as all raw error text does today. The analytics design doc records the fixed value.

**Alternatives:**
- Send a hash of the model's name. Short names can be recovered from their hash by guessing, and the spec allows no name.
- Leave out the `model` property for the connector. Keeping it present for every provider keeps the registered properties uniform, and reporting already splits by `provider`.

**Trade-offs:** Reporting can't tell local models apart.

**Claims:**

- observed: both events carry `model: currentModel` (`apps/cli/commands/ai/index.ts:639`).
- observed: the analytics design states that these events never carry raw error text (`docs/design-docs/analytics-tracks.md:289`).

design-doc-decision-13: Studio on the web leaves the connector out

**Serves:** spec-requirement-20, spec-acceptance-criterion-27

**Decision:** `ConnectMethod` gains a mark saying that only a host process can run the method, because a page can't reach what the method checks. The connector's form carries that mark. Studio on the web leaves out methods with the mark, along with loopback and device sign-ins, through the capability that already leaves those out. Its AI providers group and its settings search therefore hide the connector. The connector is never connected there, so the web's model picker never offers it.

**Alternatives:**
- Add a new method kind for a server's address. Every consumer that renders a form would need to learn the new kind.
- Add a capability that names the providers a host offers. Surfaces must not name providers.
- Offer the connector on the web for servers that accept the page's origin. The spec rejects this: most servers refuse that origin as installed.

**Trade-offs:** The capability's name, `loopbackSignIn`, understates what it now covers; whether to rename it is the implementer's call.

**Claims:**

- observed: the web hides a provider whose connect methods are all left out (`apps/ui/src/features/settings/settings-view/providers-panel.tsx:189`).
- observed: settings search marks a provider as native-only when every method is a device or loopback sign-in (`apps/ui/src/data/settings-sections.ts`).
- observed: Studio on the web sets `loopbackSignIn: false` (spec, `apps/ui/src/data/core/connectors/static/index.ts:154`).

design-doc-decision-14: Older builds stay compatible because the change only adds ids and fields

**Serves:** spec-requirement-19, spec-acceptance-criterion-26

**Decision:** Every value this change persists is new: the `local-llm` id, its `providerConfigs` entry, and local model ids in sessions. No existing field changes meaning. An older build reads them as unknown values. It runs chats on another connected provider, WordPress.com first, and keeps the connector's config. For a chat that recorded a local model, it uses its own default model.

**Alternatives:** Map the stored id, as Anthropic's id maps to the stored `anthropic-api-key`. That mapping exists so that an older build keeps choosing the same provider, and an older build can't run this one.

**Trade-offs:** When an older build runs a chat from the app, it reads the connector's id as no choice at all, so it saves WordPress.com as the chat provider. The connector stays connected.

**Claims:**

- observed: unknown provider configs are kept (`packages/common/lib/shared-config.ts:57`), and writing one provider's config leaves the others untouched (`providerConfigStore` in `packages/common/lib/provider-config.ts`).
- observed: an unknown `aiProvider` reads as no choice (`readSelectedAiProvider`), and JSON mode then switches to WordPress.com and saves it (`apps/cli/commands/ai/index.ts:474`, `:480`).
- observed: a pinned provider that a build doesn't know is ignored (`resolveSessionProvider`), and a recorded model it doesn't know is dropped (`readRecordedSessionModel`).

## Interfaces

`@studio/providers`, the part surfaces read:

- `ProviderId` and `AiProviderId` include `'local-llm'`. `AI_PROVIDER_IDS` ends with it, and its stored id is the same.
- `AiModelId` is a built-in model id, or the connector's id, the separator, and a name a server gives a model.
- `Provider.ai` is either today's list of models with a default, or the statement that the provider's models are the ones a server the person runs lists, with no list and no default.
- `AccountDetails` has an optional model: for a provider whose models a server lists, the one a new chat on the account starts on when the person hasn't picked one.
- `ConnectMethod` has an optional mark that only a host can run it.
- `ConnectField` says whether the field is required.
- `findAiModel( id )` resolves a connector id to the connector and to a model labelled with the server's name.
- One check takes a provider and an id, and answers whether the provider serves the id.
- `getDefaultAiModel` also takes the account, whose model is the default for a provider whose models a server lists.

`@studio/providers/services`:

- The `ai` group has an optional operation that takes the config and resolves to the models the server offers now: those it lists, less those it says only make embeddings. It returns plain data per model: the Studio id, the server's name for it, and whether it reads images.
- `AiConnection` has the optional statement that its window is exact, with the words a turn that can't fit ends with (decision 9).
- The connector's `account.connect( method, input )` takes the form's address and its optional key. It resolves to the config, or throws `ConnectError` with one of the three messages of decision 2.

The connector's config, in `shared.json` under `providerConfigs['local-llm']`, is validated by its schema: its method's id, the API base, an optional key, and the model it proposes for new chats. Like every stored field, it is persisted forever.

`@studio/common`:

- The listing operation takes the provider's services, and resolves to the listed models or throws the not-answering message.

The app's data layer:

- `Connector` gains an optional method that takes a provider and resolves to its listed models. The `ipc` and `local` connectors implement it; `static` doesn't.
- The Desktop main process adds an IPC handler, and `apps/local` a route, each wrapping the common operation.
- The hosts' handlers for a session's model and provider pin accept connector ids.

Sessions: `model_change` and `studio.session_context` entries may record a connector id, and a pin may name `local-llm`.

Analytics: for a chat on the connector, the chat events carry `provider: local-llm`, `model_family: local-llm`, and the fixed `model` value.

## Dependencies

- No new package. The connector uses pi-ai 1.5.0's `openai-completions` stream, which Studio already depends on, and `fetch`, so it runs wherever the providers' services run.
- External, at the person's server: `GET /v1/models` and `POST /v1/chat/completions` on every server. Beyond `/v1`, at the server's root: Ollama's `/api/show`, `/api/generate` (to load a model) and `/api/ps`, and LM Studio's `/api/v1/models`, whose models load on a `/v1` request. These are new external dependencies on product APIs. The connector depends on their documented fields only, and a server that doesn't answer them gets the defaults of decision 7.

## Failure modes and observability

- **Nothing answers at the address when connecting.** Connecting fails with the message naming the address; Settings shows it under the form and `/connect` asks again. Studio stores nothing.
- **The server refuses the key.** At connect, the key-refused message. In a turn, the same wording asks the person to connect again; the connector stays connected.
- **The server lists no chat model.** It lists none, or only models it says only make embeddings, as LM Studio does before the person downloads a chat model. Connecting fails with the no-chat-model message.
- **The server stops after connecting.** The picker offers none of its models. A turn ends at once with the not-answering message naming the address, which is recorded in the session's closed turn and shown in both surfaces. pi doesn't retry it, and no other provider answers.
- **The server refuses the model.** The turn ends with the model's name, the server's reason in words, and the advice to pick another model. This covers a model without tools, a model the server no longer has (including a proposed model that was removed), and an embedding model on a server that doesn't say what kind its models are.
- **A llama-server still loading answers 503.** pi retries it with backoff, as it does today.
- **A turn too large for the window.** On a server whose context is known, the request isn't sent: pi compacts and retries once, then the turn ends with the context-too-small words. If the server refuses it anyway, its overflow refusal gets the same handling and the same words.
- **A server reports no context.** This happens on a server Studio doesn't know, or for a model the server couldn't load, whose turn it then refuses (decision 8). The connection has no exact window. pi compacts and retries once on the server's overflow refusal, and the turn then ends in the server's words. A server that cuts silently and reports no context isn't covered (Risks).
- **A server reports no image support.** The model counts as text-only. Its screenshots reach it as placeholders, and the composer holds attachments back.
- **An older build shares the settings.** It runs chats on another connected provider, and keeps the connector's config.

Nothing new is logged. The errors above are the person's signal, and they reach the session's closed-turn record as other turn errors do. Tracks classifies them through the existing `error_kind`, without their text.

## Verification

- new test at the connector's services boundary (`packages/providers/local-llm/tests`) — design-doc-decision-2, spec-acceptance-criterion-6, spec-acceptance-criterion-7, spec-acceptance-criterion-9, spec-acceptance-criterion-10 — connecting accepts each address form spec-requirement-4 lists, and a missing key on a server that takes none. It fails with the address-naming, key-refused and no-chat-model messages, the last also for a server listing only models it says only make embeddings. The account's summary is the address, never the key.
- new test at the connector's services boundary — design-doc-decision-6, spec-acceptance-criterion-15 — connecting proposes the first offered model the server says can call tools, even when the server lists others first, and the first offered model when the server says that of none.
- new test at the connector's services boundary — design-doc-decision-7, design-doc-decision-4, spec-acceptance-criterion-11, spec-acceptance-criterion-28 — the listing leaves out the models Ollama or LM Studio says only make embeddings, and offers those a server says nothing about. The listing and the connection take image support and the running context from each of the four servers' reported fields, and have Ollama or LM Studio load a model that isn't loaded before reading its context, LM Studio through a `/v1` request and never its load API. A server that reports nothing yields a text-only model and no exact window.
- new test at the connector's services boundary — design-doc-decision-8 — the connection's error wording for a server that doesn't answer, a refused key and a refused model. It leaves overflow refusals, 429 and 5xx untouched, and sends the server's name on the wire.
- new test at the `@studio/providers` root (`packages/providers/tests/providers.test.ts`) — design-doc-decision-1, design-doc-decision-5 — `findAiModel` and the served check resolve connector ids to the connector and the server's name, built-in ids resolve as today, and the connector comes last in `AI_PROVIDER_IDS`.
- new test at `getConnectFields` — design-doc-decision-2 — each field reports whether it is required, from its schema.
- new test at `@studio/common`'s AI settings — design-doc-decision-4 — the listing operation reads the stored config and returns the connector's listing.
- new test at `getDefaultAiModel` and `resolveSessionModelForProvider` — design-doc-decision-6 — for a provider whose models a server lists, a new chat's model is the account's, and a recorded connector id is kept.
- new test at the runtime boundary (`packages/agent/node/runtime/tests`) — design-doc-decision-9 — with an exact-window connection, a request the window can't hold is never sent and the turn ends with the connection's words. A conversation that outgrows the window compacts and keeps getting replies. A connection without the statement behaves as today.
- new test at the IPC handler and at the `apps/local` route — design-doc-decision-4, design-doc-decision-5 — the listing reaches the connector's services, and a session's model and provider pin accept connector ids.
- new `apps/ui` behavior tests over the in-memory fake connector — design-doc-decision-2, design-doc-decision-3 — the connector's form saves with the key empty, a connected row shows its summary, and the key field never shows it.
- new `apps/ui` behavior test — design-doc-decision-4, design-doc-decision-6 — the model picker offers the connector's listed models by the server's names, asks again when reopened, and a new chat starts on the account's proposed model.
- new `apps/ui` behavior test — design-doc-decision-10 — the composer holds attachments back for a local model the listing doesn't report as reading images, and sends them for one it does.
- new `apps/ui` behavior test — design-doc-decision-11 — offline, the composer sends on the connector and still blocks on WordPress.com.
- new `apps/ui` behavior test — design-doc-decision-13 — without the host capability, Settings, settings search and the picker leave the connector out.
- existing test file `apps/cli/commands/ai/tests/index.test.ts`, with new cases — design-doc-decision-12, design-doc-decision-5, design-doc-decision-6 — the chat events for the connector carry the fixed `model` value and no address. A resumed chat keeps its recorded local model, and a new chat on the connector starts on the account's proposed model.
- type system — design-doc-decision-1 — every map keyed by `ProviderId` or `AiProviderId`, and `ProviderConfigs`, include the connector.
- end-to-end flow, in the Desktop app and in `studio ui`, with Ollama — spec-acceptance-criterion-1, spec-acceptance-criterion-2, spec-acceptance-criterion-3, spec-acceptance-criterion-7, spec-acceptance-criterion-9, spec-acceptance-criterion-11, spec-acceptance-criterion-12, spec-acceptance-criterion-14, spec-acceptance-criterion-15, spec-acceptance-criterion-16, spec-acceptance-criterion-17, spec-acceptance-criterion-18, spec-acceptance-criterion-19, spec-acceptance-criterion-20, spec-acceptance-criterion-24 — connecting, choosing, chatting, and every error, as a person meets them.
- end-to-end flow, in `studio code`, with Ollama — spec-acceptance-criterion-3, spec-acceptance-criterion-4, spec-acceptance-criterion-7, spec-acceptance-criterion-9, spec-acceptance-criterion-11, spec-acceptance-criterion-13, spec-acceptance-criterion-14, spec-acceptance-criterion-15, spec-acceptance-criterion-16 — `/connect`, `/model`, `/provider`, `/disconnect`, and a tool-using turn that adds a page.
- end-to-end flow, with Ollama running its model at a 4096-token context and then at a context that fits — spec-acceptance-criterion-21, spec-acceptance-criterion-22 — the first turn ends with the context-too-small error, and a long chat keeps getting replies while Ollama's log shows no truncation.
- end-to-end flow, with LM Studio at its default context and its model not loaded — design-doc-decision-7, spec-acceptance-criterion-21 — the first turn ends with the context-too-small error, and the model LM Studio loaded keeps its idle TTL.
- end-to-end flow, with LM Studio and the embedding model it ships with — spec-acceptance-criterion-10, spec-acceptance-criterion-28 — with a chat model beside it, the picker and `/model` offer only the chat model; with the embedding model alone, connecting fails with the no-chat-model message.
- end-to-end flow, with llama-server started with a key, and with LM Studio and vLLM — spec-acceptance-criterion-5, spec-acceptance-criterion-8 — each connects from its address alone, offers its models, and gets a reply. A missing or wrong key fails with the key-refused message.
- end-to-end flow, with the computer's network off — spec-acceptance-criterion-23 — a turn on a local model runs and replies, in the app and in `studio code`.
- end-to-end flow, with a build from before the change sharing the settings — design-doc-decision-14, spec-acceptance-criterion-26 — the older build chats on another provider, and the newer build still shows the connector connected.
- end-to-end flow, in Studio on the web — spec-acceptance-criterion-27 — neither Settings nor the picker offers the connector.
- inspection — spec-acceptance-criterion-25, design-doc-decision-12 — the analytics design doc and the events' properties name no local model and no address.

## Risks

- **A server Studio doesn't know may cut requests silently and report no context.** Its cut requests would reach the model without the person knowing (spec-requirement-15). Of the four servers examined, only Ollama cuts silently, and Studio reads Ollama's context. A server Studio doesn't know that refuses an oversized turn ends it in the server's words, not the context-too-small words.
- **The token estimate may under-count.** For text that tokenizes densely, Ollama could still cut a request the guard let through, and the reply would rest on a cut prompt. This depends on design-doc-assumption-1.
- **vLLM never says whether a model reads images.** Its vision models get no images, and the composer holds attachments back for them (spec-assumption-2).
- **A server may guard chat but not its model list.** Then a wrong key passes at connect and the first turn fails with the key-refused message. The spec's evidence leaves this open for LM Studio.
- **The proposed model may be removed from the server.** The first turn of a new chat then gets the "pick another model" error, until the person picks another model or connects again.
- **llama-server and vLLM don't say what kind a model is.** An embedding model they list is offered, and a chat on it gets the server's refusal.
- **Connecting to another server can strand existing chats.** A chat recorded on a model the new server doesn't have gets the refusal on each turn until the person picks another model.
- **An older build that runs a chat saves WordPress.com as the chat provider.** The person has to choose the connector again in the newer build.
- **A small local model may not drive Studio Code's tools.** This depends on spec-assumption-4.
- **While the server is down, the picker offers none of its models.** The turn's not-answering error is what tells the person.

## Open assumptions

spec-assumption-1: On every local server, Studio can learn the context the server runs a model with, or the fact that a turn didn't fit in it. This is what spec-requirement-15 rests on. Ollama reports it in `/api/ps` once the model is loaded (`design-doc/ollama-context-probes.txt`), and LM Studio in `/api/v1/models` once a request loads it (`design-doc/lmstudio-load-probes.txt`). llama-server and vLLM document it, and llama-server, vLLM and LM Studio refuse a turn that doesn't fit (`design-doc/server-capability-docs.md`). — assumed: confirmed when a first turn on Ollama with a 4096-token context shows the context-too-small error, and an oversized turn on llama-server, LM Studio and vLLM shows it too.

spec-assumption-2: On every local server, Studio can learn whether a local model reads images (spec-requirement-14). vLLM reports nothing in its source, so its models count as text-only (Risks). — assumed: confirmed when a turn holding a screenshot completes on Ollama's `qwen3:0.6b`, and a model Ollama lists with the `vision` capability describes an attached image.

spec-assumption-3: A Studio Code turn on a local model needs nothing from the internet (spec-requirement-16). — assumed: confirmed when a turn on a local model completes with the computer's network off.

spec-assumption-4: Studio Code's tools work through a local model that can call tools (spec-requirement-9). — assumed: confirmed when a turn on such a model adds a page to a local site.

design-doc-assumption-1: The runtime's token estimate doesn't under-count Studio Code's requests on the four servers' tokenizers. Sized compaction and the guard then keep every request inside an exact window, and Ollama never cuts one. — assumed: confirmed when a long chat on an Ollama model, at a context that fits Studio Code, keeps getting replies and Ollama's log shows no "truncating input prompt".

design-doc-assumption-2: LM Studio, llama-server and vLLM accept the plain Chat Completions request Studio Code sends, including its tools and its streamed usage. — assumed: confirmed by a turn that calls a tool on each of them.
