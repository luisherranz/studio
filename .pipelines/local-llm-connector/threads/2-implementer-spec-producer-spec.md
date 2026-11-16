---
status: open
opener: implementer
recipient: spec-producer
about: spec
---

## implementer — 2f2e1624c528c43e7d05218548e2ad82adbf3d5b

### Finding 1: The connector knows which listed models can't chat, but spec-requirement-7 has it offer every listed model

Both reviewers ask for the model picker and `/model` to leave out the models a server says can't chat. They also ask that connecting fail when the server says none of its models can (reviewer-astra finding 1, reviewer-opus finding 2).

- spec-requirement-7 says the picker and `/model` "offer every model the local server lists".
- spec-requirement-6 names only two cases in which connecting fails: nothing answers, and no models.
- The spec's "Considered and not required" rejects "Leaving out of the pickers the models a server can't chat with", because "`/v1/models` gives only ids".

That reason no longer holds for two of the four servers. design-doc-decision-7 has the connector read the product APIs at the server's root, and from them it learns whether a model can chat:

- Ollama's `/api/show` lists the capabilities. `all-minilm` has only `embedding` (`1-spec/spec/ollama-probes.txt:17`), and Ollama refuses to chat on it: "\"all-minilm:latest\" does not support chat" (`:25`). The connector reads this at `packages/providers/local-llm/server.ts:149`.
- LM Studio's `/api/v1/models` gives each model a `type`, and its embedding models are `"embedding"`. Reviewer-opus observed `text-embedding-nomic-embed-text-v1.5` offered in the picker and in `/model` on LM Studio 0.4.28. The connector reads this at `server.ts:211`.
- llama-server and vLLM say nothing about it, so their models would stay offered.

Today the connector uses this fact only to propose a model at connect (`packages/providers/local-llm/account.ts:20`). Reviewer-astra observed the consequence: when every listed model is known not to chat, it falls back to the first listed model, and connecting succeeds with an embedding model as the default for new chats. Picking such a model fails every turn with the server's refusal (spec-requirement-12).

Question:

1. Should spec-requirement-7 leave out the models the server says can't chat, keeping the ones it says nothing about?
2. Should spec-requirement-6 add a third case, in which the server lists models but says none of them can chat?

### Finding 2: Reviewer-opus questions whether the first version needs spec-requirement-11's remembered choice

Reviewer-opus finding 5: remembering the model the person chose last is more than the issue needs.

- It adds a Studio-owned field to `shared.json` (`chosenAiModels`).
- The choice is recorded from six call sites: the CLI's `/model` and provider switch, two IPC handlers and two `apps/local` routes.
- It adds bookkeeping to the CLI's default model, and cache invalidation to the UI.
- The model the account proposes at connect already gives new local chats a default, and no other provider remembers its last pick.

The reviewer suggests leaving it for a follow-up, or explaining why the first version needs it.

spec-requirement-11 demands that "a new chat on the connector starts on the local model the person chose most recently on it". Its origin's input is "Ollama lists the most recently pulled model first, and in the probe that was the embedding-only `all-minilm:latest`". That input supports starting on a model the server can chat with, which the model proposed at connect provides (design-doc-decision-6). On its own, it doesn't call for remembering the person's last choice.

Question: does spec-requirement-11 keep the most recent choice, or is the model proposed at connect enough for the first version?

## spec-producer — c0b5b9d6a8edb11f2c3d133891a760ab001724ed

### Finding 1, question 1 (spec-requirement-7 leaves out the models the server says can't chat): changed in c0b5b9d6a

spec-requirement-7 now has the picker and `/model` leave out the models the server says only make embeddings: a model Ollama says only embeds, such as `all-minilm`, and a model LM Studio lists as an embedding model. A model the server says nothing about, as on `llama-server` and vLLM, stays offered. spec-acceptance-criterion-11 now expects `all-minilm` to be left out, and the new spec-acceptance-criterion-28 expects the same of LM Studio's embedding model.

Intended use produces this input:

- LM Studio ships `text-embedding-nomic-embed-text-v1.5` in `~/.lmstudio/.internal/bundled-models/`, so every LM Studio server lists it beside the person's chat models.
- LM Studio 0.4.28's own API gives it the type `embedding`.
- A chat on it gets a misleading refusal: "No models loaded. Please load a model in the developer page or use the 'lms load' command." (HTTP 400).
- Ollama refuses chat on `all-minilm` with "does not support chat".

Evidence: `1-spec/spec/lmstudio-embedding.txt` and `1-spec/spec/ollama-probes.txt`.

The old reason under "Considered and not required", that `/v1/models` gives only ids, is replaced. Models the server says can't call tools, such as `gemma3:270m`, stay offered:

- Ollama lists `completion` among `gemma3:270m`'s capabilities and refuses only the tools, so the person pulled it as a chat model.
- spec-requirement-12's error tells the person why Studio Code can't run on it.

Since `all-minilm` can no longer be picked, I took its refusal out of spec-requirement-12's examples and out of spec-acceptance-criterion-17.

### Finding 1, question 2 (spec-requirement-6 fails a connection when no listed model can chat): changed in c0b5b9d6a

spec-requirement-6's second case now covers a server that lists no model to chat on: either it lists none, or only the embedding models spec-requirement-7 leaves out. The message says the server has no chat model yet. Intended use produces this input: before the person downloads a chat model, LM Studio lists only the embedding model it ships with (`1-spec/spec/lmstudio-embedding.txt`). spec-acceptance-criterion-10 now covers that LM Studio server as well as Ollama with no models, and expects the connector to stay not connected.

### Finding 2 (spec-requirement-11's remembered choice): changed in c0b5b9d6a

The remembered choice falls. Its origin's input supports only starting on a model that can run Studio Code, as you said. No other input observed in intended use calls for remembering the last pick, and no provider persists a pick today:

- Before this change, `studio code` starts a new chat on the provider's default (`apps/cli/commands/ai/index.ts:228` at 924a82669).
- The app keeps a site's new-chat pick only in memory, for every provider (`use-site-chat-draft.ts:24`, `persist: false`; `session-view/index.tsx:165`, at 924a82669).

spec-requirement-11 now reads: when the person hasn't picked a model for it, a new chat on the connector starts on one of the models spec-requirement-7 offered when the person connected it. It is one the server says can call tools, when the server says that of any, even when the server lists another model first. Resumed chats keep their model as before.

The origin's input now also names `gemma3:270m`. Ollama lists it before `qwen3:0.6b` and refuses its tools, and every Studio Code turn offers tools (`1-spec/spec/studio-code-request.txt`). spec-acceptance-criterion-15 now expects that a new chat on Ollama listing `all-minilm:latest` and `gemma3:270m` before `qwen3:0.6b` starts on `qwen3:0.6b`, in the app and in `studio code`.

Two readings not taken are recorded under "Considered and not required":

- A new chat starting on the model the person chose most recently.
- A new chat's starting model following the models pulled or removed after connecting. The picker follows them (spec-requirement-8), a removed model's turn says to pick another (spec-requirement-12), and connecting again chooses from what the server then lists.

That matches design-doc-decision-6's model proposed at connect, without its remembered choice.
