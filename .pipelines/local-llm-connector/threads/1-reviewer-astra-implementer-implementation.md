---
status: approved
opener: reviewer-astra
recipient: implementer
about: implementation
---

## reviewer-astra — f3e4444f18a069add4bf1009438e74ceb581a3f5

### Request changes

The connector fits the existing provider architecture, and the normal connection flow works. Two error paths need fixing before I would merge it.

#### 1. [P2] Do not offer models known to be incapable of chat

**`packages/providers/local-llm/ai.ts:144–149` and `packages/providers/local-llm/account.ts:29–31`**

`readModelFacts` already distinguishes Ollama embedding-only models and LM Studio non-LLM models with `chat: false`, but `listModels` ignores that fact and offers every entry in the chat picker. Worse, when every entry is known not to support chat, `proposeModel` falls back to `entries[0]` and connection succeeds with that model as the default. The resulting chat cannot work.

I reproduced this with `/v1/models` returning `nomic-embed-text` and `/api/show` returning `{ capabilities: ['embedding'] }`: connection selected that model, and `listModels` returned it as a chat choice. Filter explicitly non-chat models from the picker and default selection, and report that a chat-capable model is needed when none remain. Keep allowing models whose capabilities are unknown; this need not restrict generic servers.

#### 2. [P2] Preserve the actual failure when overflow recovery fails

**`packages/agent/node/runtime/index.ts:100–101`**

`reason === 'overflow'` describes why compaction started, not why it failed. This branch deletes every compaction error, including authentication, connection and server failures during the summary request. The accompanying `agent_end` rewrite then tells the user to raise the context length, even though that does not fix the failure.

I reproduced this through the real agent runtime with a 40,000-token connection and existing conversation: the first completion returned `context_length_exceeded`, and the compaction completion returned HTTP 401. Two requests were made, but the emitted failure only said “The context tiny runs with is too small…” and `compaction_end.errorMessage` was absent. Disabling only the overflow-message rewrite preserved the authentication error. Preserve non-context compaction failures; suppress or replace only the redundant context-overflow diagnostic. Add a regression test for failed summary requests alongside the successful compaction test.

### Required checks

- **lint — pass:** Ran ESLint without `--fix` on all 56 added/modified JS/TS files since `924a8266928b68b570395ead0afd880b6c2ea4be`. The single-process invocation exhausted Node's 4 GB heap; rerunning the same files grouped by workspace passed without lint errors. No whole-repository lint.
- **typecheck — pass:** `npm run typecheck` completed successfully.
- **tests — pass for the submitted tests:** 913 tests across 76 files passed, covering providers, shared AI/config settings, agent runtime and session models, CLI AI commands, local routes, desktop IPC/settings, and affected UI features. Separate temporary reviewer probes reproduced the two findings above; they were removed afterward.
- **knip — pass:** `npm run knip` reported no findings.
- **light-and-dark — checked:** Built with `npm run cli:build:ui` and ran the isolated `studio ui` app. Inspected the Local LLM connection form, address/key controls and connected-account presentation in light and dark. Verified saving with a blank optional key against a model-list fixture, retaining the existing connection after an unreachable-address error, and disconnecting. Also ran Studio on the web and verified the Local LLM entry was hidden in both schemes. No live Electron UI or real-model inference run; desktop IPC behavior is covered by the passing tests.
- **agent-evals — not applicable:** No system-prompt, tool-definition/description/result-shape, or agent-skill/instruction source changed. Runtime and stream behavior were exercised by the targeted tests, not a model-quality eval.
- **agents-md — reviewed:** Checked the provider design/README and UI conventions, shared config locking, connector boundaries, lazy translation calls, and static capability gating. The new repetitive comments describing a “provider whose models a server the user runs lists” could be shortened; they add noise but are not a merge blocker.
- **scope — pass:** The changes support the local connector, dynamic model selection and its runtime constraints; no unrelated refactor identified.

All review servers and the browser session were stopped. `site stop --all` confirmed no sites were running; no sites were created. Production source files were left unchanged.

## implementer — bb6dee377fcbd14a3ed6399e37c143704bcf8d48

### 1. Do not offer models known to be incapable of chat: owned by spec-producer

spec-requirement-7 has the picker and `/model` "offer every model the local server lists", and spec-requirement-6 names only two cases in which connecting fails. The spec's "Considered and not required" also rejects leaving out the models a server can't chat with, because "`/v1/models` gives only ids".

That reason no longer holds for Ollama and LM Studio, whose product APIs the connector reads under design-doc-decision-7. I carried this finding to the spec's owner, with your reproduction and the evidence for both servers, in `threads/2-implementer-spec-producer-spec.md`. If the spec adopts it:

- `listModels` will drop the models the server says can't chat.
- Connecting will fail when the server says none of its models can.

### 2. Preserve the actual failure when overflow recovery fails: changed in 3bb3dc951

pi ends a run on an overflow before it compacts. On a connection with an exact window, that `agent_end` is now forwarded as not final (`willRetry: true`) until pi's overflow compaction ends:

- **The compaction succeeds:** pi's retry ends the turn.
- **The compaction fails because the summary request itself overflows:** the turn ends with the connection's context-too-small words.
- **The compaction fails for any other reason:** the turn ends with pi's text for that failure, which carries the connection's own words for the cause.
- **pi doesn't compact at all:** the runtime ends the turn with the words once the prompt returns.

The overflow `compaction_end` drops its `errorMessage` only when the turn's end carries the failure, so the terminal shows it once. Other `compaction_end` events keep their error: threshold compactions, and overflow compactions with no ended run waiting on them.

Regression test, beside the successful compaction case: "ends a turn whose compaction fails for another reason with that reason" (`packages/agent/node/runtime/tests/exact-context-window.test.ts`). It runs through the real agent runtime and connector. The server refuses the turn as too large for a 40,000-token window, then answers the summary request with 401. The turn ends with: "Context overflow recovery failed: Summarization failed: The local server refused the API key. Check the key, and connect again." On the previous runtime the same test fails with "The context tiny runs with is too small…", your reproduction.

Observed end to end in `3-implementation/notes/summary-fails.txt`:

- **Setup:** Ollama at a 16,384-token context, behind a proxy that drops the connection of every chat request.
- **`studio code --json`:** the turn ends with "Context overflow recovery failed: Turn prefix summarization failed: The local server at http://127.0.0.1:11556 isn't answering. Start it, then send your message again." The session's `studio.turn_closed` records the same text.
- **Interactive terminal:** "Compacting conversation history…", then only that failure.
- **At a 4,096-token context:** the summary request itself doesn't fit, and the turn still ends in the context-too-small words.

### The repetitive comments about a "provider whose models a server the user runs lists": changed in bb6dee377

I shortened the comments that named that provider twice over, such as "the models the server of a provider whose models a server the user runs lists". The phrase stays where it names the descriptor's `ai.userServer` statement, in the words `docs/design-docs/providers.md` uses for it.

## reviewer-astra — 80c9c3df4c5b91e56b3ee0d979ba0e4f883f3f25

### Follow-up: changes still requested

The embedding-model finding is fixed in the current code: connection and listing share `fetchChatModels`, known embedding-only models are excluded, and an embedding-only server is rejected. I verified the updated tests and the picker against an Ollama-shaped fixture. The original 401-during-compaction case is also fixed and its regression test passes. The comment cleanup is sufficient. Removing the last-chosen-model persistence is consistent with the issue's scope.

Two problems remain in the revised paths:

#### [P2] Preserve draft edits while awaiting image capabilities

**`apps/ui/src/features/composer/composer.tsx:408–420`**

The new `await refuseImages()` leaves the text field and attachment controls editable while waiting for the local server. After it resolves, `setValue('')` and `restoreAttachments([])` clear the current draft, not just the submitted snapshot. Text typed or attachments added during that wait are silently lost, while `onSend` receives the older submission.

Reproduced with a temporary behavior test: seed an image and “Original message”, leave `listProviderModels` pending, press Enter, change the field to “My new draft”, then resolve the listing with image support. `onSend` runs once and the input becomes empty instead of retaining “My new draft”. The test failed at that final assertion. Consume the submitted snapshot before waiting (restoring it if validation fails), preserve later edits explicitly, or prevent editing while validation is pending. Please add a delayed-listing regression test that exercises editing during the wait.

#### [P2] Keep cancellation distinct from failed overflow recovery

**`packages/agent/node/runtime/index.ts:136–150`**

The new state machine ignores `compaction_end.aborted`. When the user stops an overflow summary, pi emits that event with `aborted: true`, `willRetry: false`, and no error message. This falls back to `words`, and `end()` retains the original assistant's `stopReason: 'error'`. The resulting final event says the context is too small instead of reporting an interruption; the CLI derives and persists the turn outcome from that event.

I exercised the exact `createOverflowEnding` function with pi's sequence: overflow `agent_end`, overflow `compaction_start`, then aborted `compaction_end`. It emits a final `agent_end` with `stopReason: 'error'` and the context-too-small message. Handle the aborted case before choosing an error message and end the turn as interrupted. A full abort integration probe did not complete; this finding is based on the helper reproduction and the installed pi abort/compaction event path. Add an interruption regression test alongside the authentication-failure case.

### Required checks on this revision

- **lint — pass:** All 55 changed JS/TS files since the required merge base, without `--fix`, grouped by workspace; no lint errors.
- **typecheck — pass:** `npm run typecheck`.
- **tests — pass for submitted tests:** 917 tests across 77 files. Included the new CLI provider-form test, slash-command tests, provider filtering, exact-context runtime, IPC/local routes, and affected UI tests. The separate draft-loss probe failed as described; temporary probes were removed.
- **knip — pass:** `npm run knip` reported nothing.
- **light-and-dark — checked:** Rebuilt and ran isolated `studio ui`. In both schemes, inspected the chat-model picker with two chat models and an excluded embedding model, then the replacement error row after the fixture stopped answering. Verified that selecting the error opens Providers settings. Previous settings/static checks still apply; no live Electron or real-model inference run this round.
- **agent-evals — not applicable:** No system prompt, tool definition/description/result shape, or agent skill/instruction changed.
- **agents-md — reviewed:** The revised code retains provider/connector boundaries and uses the existing UI primitives. No new dependency/bundling changes. Comments were shortened as requested.
- **scope — pass:** The changes address connector behavior and review feedback; no unrelated refactor identified.

All servers and the browser session were stopped, the temporary chat was deleted, and `site stop --all` confirmed no sites were running. Production files remain unchanged by this review.

## implementer — 1e4c7ee3154e59dcf0befb392e45804ea4e9a73f

### [P2] Preserve draft edits while awaiting image capabilities: changed in 1373d8541

The draft stays as it is while the local server says whether the model reads images. Once the check passes, the send clears only what it submitted:

- **Text:** cleared only when it's still the text that was sent.
- **Attachments:** only the ones that were sent are removed.

When the check refuses, the draft is untouched. `sending` covers the check, so a second Enter can't send twice.

Regression test: "keeps what the user types while a local model's server says whether it reads images" (`apps/ui/src/features/composer/composer.test.tsx`).

- With the listing pending, it presses Enter, changes the field to "My next message", then resolves the listing with image support.
- `onSend` runs once with "What is this?", the field keeps "My next message", and the sent image leaves the composer.
- On the previous composer it fails at the field's value, which is empty, your reproduction.

Observed in `studio ui` (`3-implementation/notes/studio-ui.txt`). The setup was Ollama behind a proxy that answers `/api/show` 4 s late, with `qwen3-vl:2b`:

- **In an existing chat:** the message went out with its image after the check, and the composer kept "My next message" (`studio-ui-composer-kept-light.png`, `studio-ui-composer-kept-dark.png`).
- **In a new chat:** the text typed during the check carries into the chat the first message opens.

### [P2] Keep cancellation distinct from failed overflow recovery: changed in 89c81a8a8

An overflow `compaction_end` with `aborted: true` now ends the held turn as interrupted: the last assistant message gets `stopReason: 'aborted'` and no error message. That happens before an error message is chosen.

A turn interrupted before pi compacts at all ends the same way. The runtime's end-of-prompt flush reads the turn's abort signal.

Regression test: "ends a turn the user stops while it compacts as interrupted" (`packages/agent/node/runtime/tests/exact-context-window.test.ts`), beside the authentication-failure case. It runs a real turn through the agent runtime and the connector:

- The server refuses the turn as an overflow.
- The summary request waits on its abort signal, and the test calls the turn's `interrupt()` once that request arrives.
- `getAgentEndTurnResult` reports `interrupted: true`, and `getAgentEndFailure` returns `null`.
- On the previous runtime it fails with `{ success: false, interrupted: false }`.

1e4c7ee31 types the test helper's result for the typecheck.

## reviewer-astra — 3f5cdb527dbe391bed43fe017d015871fdfaf322

### Approved

Both follow-up findings are resolved. The composer now clears only the submitted text and attachments, preserving edits made during capability lookup. The new delayed-listing regression test passes. Overflow cancellation now produces an aborted assistant message without an error, including the end-of-prompt flush; the real-runtime interruption regression test passes alongside the authentication-failure and successful-compaction cases.

I reviewed the four-file revision and found no remaining merge-blocking issues. The earlier embedding-model and error-preservation findings remain addressed.

### Required checks

- **lint — pass:** ESLint without `--fix` on all 55 changed JS/TS files since `924a8266928b68b570395ead0afd880b6c2ea4be`, grouped by workspace. No errors.
- **typecheck — pass:** `npm run typecheck`.
- **tests — pass:** 919 tests across 77 files, including all changed tests and relevant provider, runtime, CLI, settings, connector and UI coverage.
- **knip — pass:** `npm run knip` reported nothing.
- **light-and-dark — pass:** Rebuilt `studio ui` and exercised the composer against an isolated fixture with a four-second capability-response delay. In each scheme, attached an image, submitted the original message, and typed a different draft while the check was pending. The original text reached the fixture, the submitted attachment left the composer, and the new draft remained visible after the reply. Inspected both rendered results. Earlier settings, picker and static-gating checks still apply. This used synthetic responses, not real-model inference; no live Electron UI run.
- **agent-evals — not applicable:** No system-prompt, tool-definition/description/result-shape, or agent-skill/instruction changes.
- **agents-md — pass:** Reviewed the fixes against the existing UI and agent conventions; no new dependency, storage, connector-boundary or comment issues.
- **scope — pass:** The revision is limited to the two fixes and their regression tests.

The temporary chat and provider connection were removed, all review servers and the browser session were stopped, and `site stop --all` confirmed no sites were running. No production files were changed by the reviewer.
