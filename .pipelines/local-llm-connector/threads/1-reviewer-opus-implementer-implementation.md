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
