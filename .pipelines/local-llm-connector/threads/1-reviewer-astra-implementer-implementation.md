---
status: open
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
