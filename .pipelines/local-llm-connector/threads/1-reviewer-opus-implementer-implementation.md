---
status: open
opener: reviewer-opus
recipient: implementer
about: implementation
---

## reviewer-opus — f3e4444f18a069add4bf1009438e74ceb581a3f5

The connector does what the issue asks. One "Local LLM" provider takes a server address and an optional key. It talks to any OpenAI-compatible server, and reads extra facts from Ollama, LM Studio, llama-server and vLLM where they report them. I tested it against real servers, and the core path works end to end. Three problems in the main flows need fixing before merge, so I'm requesting changes.

### How I tested it

I ran my own servers on free ports, all stopped afterwards:

- **Ollama 0.40.16**
  - A wrong address fails with "No local server answered at 127.0.0.1:11556…".
  - The right address connects and proposes `qwen3:0.6b`, the model that can call tools, over `gemma3:270m`.
  - The picker lists both models. A turn on `qwen3:0.6b` succeeds; Ollama reports a 32,768-token context.
  - `gemma3:270m` fails with "Your local server can't run gemma3:270m: … does not support tools. Pick another model."
  - A 4,096-token variant of qwen3 ends with "The context … is too small". The server log shows no chat request was sent, as intended.
  - Stopping the server gives "The local server at … isn't answering."
- **llama-server (b12359) with `--api-key`**
  - A wrong key gives "refused the API key"; the right key connects.
  - `/v1/models` reports `meta.n_ctx` and `architecture.input_modalities` where the code reads them.
  - A 16k context is refused. The real first-turn prompt is 11,751 tokens (measured on a 32k run), so that refusal is fair. 32k works.
- **LM Studio 0.4.28**
  - `/api/v1/models` has the shape the code expects.
  - Asking for the context loads the model through a one-token chat request, with an 8,192-token context and a 1-hour idle TTL. The guard then refuses the turn.
- **vLLM**: not tested live, because it isn't installed. Only the unit tests cover it.
- **Terminal (`studio code`)**
  - A `--json` turn starts on the model chosen last.
  - `/model` lists the server's models and records the pick.
  - The connect form is tested live in item 3 below.

### Must fix

1. **The model picker hides a server that doesn't answer.**
   - After a reload with the server stopped, the picker opens to an empty Models group, with only "Connect AI providers". Before a reload, it shows the stale cached list.
   - The route and the IPC handler already return the right words ("The local server at … isn't answering. Start it…"), but `useListedModels` drops the error. The user's models just vanish, with no reason given.
   - Show the error in the picker, for example as a disabled row.
2. **Embedding-only models are offered as chat models.**
   - LM Studio's `text-embedding-nomic-embed-text-v1.5` (`type: "embedding"`) appears in the picker and in `/model`. So would an Ollama model whose only capability is `embedding`.
   - Picking one fails every turn.
   - `readModelFacts` already knows `chat === false` for these, and `proposeModel` uses it. `listModels` should drop them, or at least sort them last and mark them.
3. **In the terminal, a mistyped address traps the user.**
   - `fillForm` (`apps/cli/lib/providers.ts`) checks the connection only when the last field, the API key, is entered.
   - With a wrong address, the API key prompt repeats "No local server answered at 127.0.0.1:11999…" forever. The address can't be corrected; only Ctrl+C gets out ("Canceled."). I reproduced this in a real terminal.
   - "A rejection asks again" worked for one-field forms. This is the first form with two fields. Either check the address when it is entered, or restart the whole form after a rejection.

### Should fix, or explain in the PR

4. **Scope: the AI panel changes for every provider.**
   - Every connected row now shows `account.summary` in place of the provider's description.
   - The key field no longer shows the key preview as its placeholder. That covers Anthropic, OpenAI, Gemini and Copilot, not only Local LLM.
   - I see why: the address would otherwise show up as the API key's placeholder. But it is a visible change for other providers. Either narrow it, or call it out in the PR so design can confirm it.
5. **More than the issue needs: remembering the model chosen last.**
   - It adds `chosenAiModels` in `shared.json`, `recordAiModelChoice` in six call sites (CLI `/model` and `switchProvider`, two IPC handlers, two `apps/local` routes), the CLI's `onDefaultModel` bookkeeping, and cache invalidation in the UI.
   - The model the account proposes when it connects already gives local chats a default, and no other provider remembers the last pick.
   - Consider leaving it for a follow-up, or say in the PR why the first version needs it.
   - Related: `AccountDetails.model` is documented as general ("in place of the provider's default"), but `getDefaultAiModel` only honours it for `userServer` providers.
6. **`getDefaultAiModel( 'local-llm' )` without an account returns `'fast'`,** WordPress.com's model, which local-llm doesn't serve. Callers guard against it today, but it is easy to trip on. Prefer throwing, as it does for a provider with no AI, or make the account required for `userServer` providers.

### Nits

7. **`/model` repeats the name as its description.** It shows `qwen3-4k:latest` with `qwen3-4k:l` under it, truncated. Drop the description, or show something useful such as whether the model reads images.
8. **The composer's image check can misfire.**
   - `readsImages` stays false until the listed-models query resolves, and that query only starts once there is an attachment.
   - So pressing Enter right after pasting an image, on a model that reads images, shows "Choose a model that supports images…".
   - With the server down, the same message hides the real cause.
9. **`--json` output shows an internal error text.** The intermediate `message_end` and `turn_end` events carry `context_length_exceeded: the request doesn't fit the context…`. Only `agent_end` gets the connector's words.
10. **`REPLY_TOKENS = 4096 + 1024`** (`packages/agent/node/runtime/index.ts`) copies pi's `CONTEXT_SAFETY_TOKENS` and `MIN_ANSWER_TOKENS`. `context-window.ts` already imports `MIN_ANSWER_TOKENS`, so use it here too, so the two don't drift.
11. **`withOverflowWords` clears every overflow `compaction_end` error on exact windows.** If the server stops while compacting, the turn ends with "context too small" instead of "isn't answering".
12. **Manage reopens with an empty address field.** The field shows the placeholder `http://localhost:11434`, not the current address, so reconnecting means retyping it. The address isn't a secret, so it could be filled in.
13. **One server at a time.** Someone running both Ollama and LM Studio has to reconnect to switch. That's fine for a first version, but the intent says "any local LLM provider", so say so in the PR or the docs.
14. **Test gaps:** nothing tests `/model` on a local server, or the optional field in `fillForm`.
15. **`docs/design-docs/providers.md`:** the new table row isn't padded like the others.

### Rules

- **lint**: passed. `npx eslint` (without `--fix`) on the 56 JS/TS files changed since `924a826` reports no errors.
- **typecheck**: `npm run typecheck` passes.
- **tests**: all pass, 81 files and 906 tests, covering:
  - `packages/providers`
  - `packages/agent/node/runtime/tests`, `packages/agent/protocol/sessions/tests`, `packages/agent/shared/runtime-guards/tests`
  - `packages/common/lib/tests/ai-settings.test.ts`, `packages/common/lib/tests/shared-config.test.ts`
  - `apps/cli/commands/ai/tests/index.test.ts`, `apps/cli/ai/tests/slash-commands.test.ts`, `apps/cli/ai/tests/auth.test.ts`
  - `apps/local/src/tests`
  - `apps/studio/src/tests/ai-session-model.test.ts`, `apps/studio/src/modules/user-settings/lib/tests`
  - `apps/ui/src/features/chats/session-view/index.test.tsx`, `apps/ui/src/features/composer`, `apps/ui/src/features/settings`, `apps/ui/src/features/sites/add-site-dialog`
  - `apps/ui/src/data/settings-sections.test.ts`, `apps/ui/src/data/core/connectors`
- **knip**: `npm run knip` reports nothing.
- **light-and-dark**: checked in `studio ui` (this worktree, port 8099).
  - Light: the Local LLM connect form, the wrong-address error, the connected row showing the address, the composer's picker listing the server's models, and the failed turns in the transcript.
  - Dark: the Manage form, the same transcript errors, and the picker with the server down.
  - Both read well; the provider's logo tile works on both backgrounds. The only issues are the behaviours in items 1 and 12.
- **agent-evals**: not applicable.
  - The change doesn't touch the system prompt, tool definitions, descriptions or result shapes, or skills.
  - The runtime changes (compaction sized to the window, and the check before sending) apply only to connections that set `exactContextWindow`, and only Local LLM sets it. Other providers keep `STUDIO_COMPACTION_SETTINGS` and the same stream.
  - No eval assertions need updating.
- **agents-md**:
  - Three front ends: `ipc` and `local` implement `listProviderModels`. On the web, `hostOnly` hides the connect method and the provider's row, and `listProviderModels` is optional.
  - `shared.json` writes take `lockSharedConfig`. Nothing is translated at module level. Providers import no workspace package. Docs are updated (`providers.md`, `analytics-tracks.md`, the user docs).
  - The chat events report `user-server-model`, never the model's name or the server's address.
  - The comments are dense but explain why, in line with the surrounding code.
- **scope**: mostly in scope. Items 4 and 5 go beyond what the issue needs.

## implementer — bb6dee377fcbd14a3ed6399e37c143704bcf8d48

### 1. The model picker hides a server that doesn't answer: changed in d06667ae6

In 8a6aa3574, `useListedModels` started reporting each provider's listing error, and stopped showing the models it read before once a later read fails. When the listing fails, the picker shows one row in place of the connector's models: its label is the provider's name, and its description is the server's error, for example "The local server at http://127.0.0.1:11555 isn't answering. Start it, then send your message again."

In d06667ae6 the row became enabled. The picker's rows scroll a long description into view only when enabled (`MarqueeLabel` skips `aria-disabled` rows), and disabled, the reason was cut off at the address. Choosing the row opens Settings → Providers.

Test: "says why a local server's models are missing once it stops answering" (`apps/ui/src/features/composer/chat-model-picker.test.tsx`). The picker lists the models once; the server stops; the picker is reopened without a reload. The test expects the reason row, no stale model, and provider settings opening when the row is chosen. It fails on the previous picker.

Observed in `studio ui` in light and dark, with Ollama stopped and the picker reopened without reloading: `3-implementation/notes/studio-ui.txt`, `studio-ui-picker-error-light.png` and `studio-ui-picker-error-dark.png`.

### 2. Embedding-only models are offered as chat models: owned by spec-producer

spec-requirement-7 has the picker and `/model` "offer every model the local server lists". The spec's "Considered and not required" rejects leaving out the models a server can't chat with, because "`/v1/models` gives only ids".

The connector now learns this from Ollama's `/api/show` and LM Studio's `/api/v1/models` (design-doc-decision-7). I carried your LM Studio observation, and reviewer-astra's case of a server whose every model is embedding-only, to the spec's owner in `threads/2-implementer-spec-producer-spec.md`.

### 3. In the terminal, a mistyped address traps the user: changed in b4b786335

From 07fa79554, a form of several fields is checked once every field is entered. When connecting fails, the CLI prints the rejection and asks for every field again, so the address can be corrected.

b4b786335 keeps the earlier behavior for a form of one field, such as an API key: the rejection still shows as that prompt's error. Asking every form again had made `apps/cli/ai/tests/auth.test.ts`'s rejected-key case, whose key is always rejected, loop until the heap ran out.

Test: `apps/cli/lib/tests/providers.test.ts` connects Local LLM through `connectInTerminal` with real config writes. A mistyped address is rejected, the right address with an empty optional key connects, the stored config has no key, and the key prompt says it's optional. It fails on the previous form.

Observed in a real terminal (`3-implementation/notes/connect-retry.txt`): "No local server answered at 127.0.0.1:11999…", the address asked again, then "Connected Local LLM."

### 4. Scope: the AI panel changes for every provider: owned by design-doc-producer

design-doc-decision-3 decides both changes for every provider: the row's summary, and the secret field's placeholder. It rejects showing the summary only on the connector's row, because surfaces must not branch on a provider id (providers.md, principle 2), and its trade-offs name the Anthropic, OpenAI, Gemini, ChatGPT and Copilot rows. I carried your finding to its owner in `threads/3-implementer-design-doc-producer-design-doc.md`.

### 5. More than the issue needs: remembering the model chosen last: owned by spec-producer

spec-requirement-11 requires that "a new chat on the connector starts on the local model the person chose most recently on it". I carried your finding, including what it costs in the code, to the spec's owner in `threads/2-implementer-spec-producer-spec.md`.

### 5, related. `AccountDetails.model` documented as general: changed in 2f2e1624c

The comment now says it's the model new chats on the account start on "for a provider whose models a server the user runs lists, which has no default of its own". That's how `getDefaultAiModel` reads it, and design-doc-decision-6 scopes it to such providers. Built-in providers' callers don't pass the account, so honoring the field for them would apply it on some paths and not others.

### 6. `getDefaultAiModel( 'local-llm' )` without an account returns `'fast'`: stands

A render path reaches it with no account:

- The session view resolves a new chat's default model during render, for the site draft's `provider` (`apps/ui/src/features/chats/session-view/index.tsx:152` and `:160`).
- A site draft keeps its `provider` (`apps/ui/src/data/queries/use-site-chat-draft.ts:8`), and nothing clears it when that provider is disconnected.
- Disconnecting also clears the remembered model.

So after picking a local model in a new chat and then disconnecting Local LLM in Settings, `getDefaultAiModel( 'local-llm' )` runs with no account and no remembered model. A throw there would throw during the chat view's render.

The fallback is never used as a local model. `resolveSessionModelForProvider` keeps a recorded model only when `servesAiModel` says the provider serves it. The hosts' session-model and provider-pin handlers reject a model the provider doesn't serve. `studio code` resolves the model again after `/connect`. The doc comment on `getDefaultAiModel` states the fallback.

### 7. `/model` repeats the name as its description: changed in 54b80a06f

A local model's option now has no description; its label is already the server's name for it.

Test: "offers the models a local server lists by their names, and remembers the pick" (`apps/cli/ai/tests/slash-commands.test.ts`). It fails on the previous `/model`. Observed in `studio code` (`3-implementation/notes/connect-retry.txt`): `/model` lists `qwen3-vl:2b (current)`, `all-minilm:latest`, `gemma3:270m` and `qwen3:0.6b`, with no line under them.

### 8. The composer's image check can misfire: changed in 5d842973b

At send, the composer reads whether a local model reads images from the listing as last read. When nothing has read it yet, it reads it then, and the send waits for it, holding `sending` so a second Enter can't send twice. When the server doesn't answer, the composer keeps the draft and shows the server's reason instead of "Choose a model that supports images…".

Tests (`apps/ui/src/features/composer/composer.test.tsx`):

- The two cases for a local model now press Enter before the server has said what the model reads.
- A new case covers a server that doesn't answer.

The image-model case and the new case fail on the previous composer.

Observed in `studio ui` (`3-implementation/notes/studio-ui.txt`):

- **Server stopped:** the composer shows "The local server at http://127.0.0.1:11555 isn't answering. Start it, then send your message again" (`studio-ui-composer-down-light.png` and `-dark.png`).
- **Server running:** `qwen3:0.6b` holds the image back, and `qwen3-vl:2b` sends it right after being picked.

### 9. `--json` output shows an internal error text: stands

The intermediate assistant message has to carry a text pi reads as an overflow, or pi wouldn't compact and retry. design-doc-decision-9 rejects wording the overflow in `rewriteError` for that reason.

No Studio surface shows that text:

- The terminal shows an assistant message's error only from a final `agent_end` (`apps/cli/ai/ui.ts:1964`).
- The app's transcript shows a turn's error from `studio.turn_closed` (`apps/ui/src/features/chats/session-view/conversation/transcript-items.ts:328`). That entry takes the error of the turn's last final `agent_end` (`apps/cli/commands/ai/index.ts:721`).

Since 3bb3dc951, the `agent_end` that carries the internal text is also marked not final, so a `--json` reader that follows `willRetry`, as Studio's own do, sees only the final words. On the built-in providers, the intermediate events carry the server's raw overflow text in the same way.

### 10. `REPLY_TOKENS = 4096 + 1024`: changed in 7c4f06bc6

It's now `4096 + MIN_ANSWER_TOKENS`, imported from pi as `context-window.ts` does. pi doesn't export its 4,096-token safety margin, and the comment says so.

### 11. `withOverflowWords` clears every overflow `compaction_end` error: changed in 3bb3dc951

A turn whose overflow compaction fails for a reason other than the overflow now ends with that failure. The mechanism is described in my answer to reviewer-astra's finding 2, in `threads/1-reviewer-astra-implementer-implementation.md`.

Your case, observed (`3-implementation/notes/summary-fails.txt`): the server stopped answering while compacting, and the turn ended with "Context overflow recovery failed: Turn prefix summarization failed: The local server at http://127.0.0.1:11556 isn't answering. Start it, then send your message again." It was the same in the terminal and in the session's `studio.turn_closed`.

### 12. Manage reopens with an empty address field: owned by design-doc-producer

The form gets nothing from the account except its summary. design-doc-decision-3 rejected a value per form field in `AccountDetails` as "a new contract for a single placeholder". I carried the finding to its owner in `threads/3-implementer-design-doc-producer-design-doc.md`.

### 13. One server at a time: changed in 1408b70ea

The spec's "Considered and not required" leaves several servers at once out of the first version. The user docs' Local LLM entry now says: "Studio connects to one server at a time: to switch, connect again with the other server's address." Connecting again to another server is observed in `3-implementation/notes/lmstudio.txt`.

### 14. Test gaps: changed in 54b80a06f

`/model` on a local server is tested in 54b80a06f (see 7). The optional field in `fillForm` is tested in 07fa79554 (see 3), which expects the key prompt to be marked optional and an empty key to connect.

### 15. `docs/design-docs/providers.md`: the new table row isn't padded: changed in b4f76c3f6

The row now fits the table's columns. Its Account cell reads "Server address, optional key".
