---
status: approved
opener: reviewer-opus
recipient: implementer
about: implementation
---

## reviewer-opus — b2bb0d37d2e6c21f0a59f26cff4390f6f24ddaf4

The Local LLM connector does what the issue asks: a person adds any OpenAI-compatible model server to Studio with its address and an optional key. Over two earlier rounds I tested it against real Ollama, llama-server and LM Studio, in `studio ui` and in the terminal. This round I compared the head with the one I approved and found two changes. I checked both live. I'd merge it as it stands, with one non-blocking nit below.

### What changed since my approval

1. **Interrupted compaction (`packages/agent/node/runtime/index.ts`).** A turn the user stops while pi compacts after an overflow now ends as interrupted, instead of with "The context … is too small".
   - The new runtime test covers it.
   - Live, I used a fake llama-server style server that reports a 40,000-token context, refuses the turn as too large, then stalls the summary request. I pressed Stop during "Compacting" in `studio ui`.
   - The session recorded `studio.turn_closed` as `{ status: "interrupted" }` with no error, and the transcript showed no "too small" message.
   - The server saw the summary request closed (a broken pipe on its late reply), so the stop reaches the server.
   - The aborted `compaction_end` is passed through unchanged. That's safe: the terminal ignores everything but `agent_end` once interrupted, and the app doesn't read `compaction_end`.
2. **Composer keeps text typed while it checks for images (`apps/ui/src/features/composer/composer.tsx`).** The composer now keeps text typed while it waits to learn whether a local model reads images, and clears only the attachments it sent.
   - Live, with the fake server's model list slowed to 4 seconds, sending an image in an existing chat worked: the message and image went out, and the image left the composer.

### Nit (non-blocking): text typed during that wait

The new test replaces the whole text. In real use, two other cases come up:

- **Typing appends.** The caret sits at the end, so typing " and more" during the wait in an existing chat left "Second question and more" in the box after "Second question" was sent. Pressing Enter again resends the first part.
  - Consider keeping only what was typed after the sent text, for example when `current.startsWith( value )`, or making the textarea read-only for that short wait.
- **A new chat drops it.** The app moves to the new session, whose composer is empty, and the site's new-chat draft was empty too. So the text typed during the wait is lost there, as it was before this change.

The wait only happens when the message has images and the chat is on a local model, and it lasts as long as one listing request to that local server. So this is a nit, and this round's change is no worse than the version I approved, which wiped the typed text in both cases.

### Rules

- **lint**: `npx eslint` (without `--fix`) on the 55 JS/TS files changed since `924a826` reports no errors.
- **typecheck**: `npm run typecheck` passes.
- **tests**: all pass, 125 files and 1,315 tests, covering:
  - `packages/providers`
  - `packages/agent/node/runtime/tests`, `packages/agent/protocol/sessions/tests`, `packages/agent/shared/runtime-guards/tests`
  - `packages/common/lib/tests/ai-settings.test.ts`, `packages/common/lib/tests/shared-config.test.ts`
  - `apps/cli/commands/ai/tests/index.test.ts`, `apps/cli/ai/tests/slash-commands.test.ts`, `apps/cli/ai/tests/auth.test.ts`, `apps/cli/lib/tests`
  - `apps/local/src/tests`
  - `apps/studio/src/tests/ai-session-model.test.ts`, `apps/studio/src/modules/user-settings/lib/tests`
  - `apps/ui/src/features/chats/session-view/index.test.tsx`, `apps/ui/src/features/composer`, `apps/ui/src/features/settings`, `apps/ui/src/features/sites/add-site-dialog`
  - `apps/ui/src/data/settings-sections.test.ts`, `apps/ui/src/data/core/connectors`
- **knip**: `npm run knip` reports nothing.
- **light-and-dark**: checked in `studio ui` (this worktree, port 8099).
  - Light: sending an image while the model list is slow, in a new chat and in an existing one, and the composer afterwards.
  - Dark: a turn the server refuses as too large ending with the connector's "too small" message, and a turn stopped while it compacts, which shows no error.
  - Earlier rounds covered the connect form, the connected row, the picker with its server error, and the composer's image refusal, in both schemes. None of those changed since.
- **agent-evals**: not applicable.
  - The change doesn't touch the system prompt, tool definitions, descriptions or result shapes, or skills.
  - The runtime changes act only on connections that set `exactContextWindow`, which only Local LLM does. With no overflow message, `createOverflowEnding` passes every event through, and `flush` returns nothing.
- **agents-md**:
  - The three front ends hold: `ipc` and `local` list models, and the web hides the connector through `hostOnly`.
  - Config writes take their locks, and nothing is translated at module level.
  - Providers import no workspace package, and the docs are updated.
  - Analytics never name a local model or the server's address.
  - Comments explain why.
- **scope**: in scope. Both changes this round stay inside the composer's image check and the runtime's overflow ending. The AI panel's row summary for every provider is a design-doc decision; it should be named in the PR description.
