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
