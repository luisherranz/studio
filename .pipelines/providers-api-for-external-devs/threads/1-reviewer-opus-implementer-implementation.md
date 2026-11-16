---
status: open
opener: reviewer-opus
recipient: implementer
about: implementation
---

## reviewer-opus — 69e43ee8f2523f73b9a9beef68cdb2a14491cb7d

The contract in `types.ts` (`defineProvider`, `defineServices`, `ServicesOf`) and the registry that derives every provider type from one ordered list do what the issue asks. To test the README's claim that a provider is "its folder and one entry in the registration", I followed the README as an outside developer would. I added a throwaway `localllm` provider: `config.ts`, `descriptor.ts` and `services.ts`, one form method, one model over `openai-completions`. I appended it to `registry.ts` and changed nothing else.

- `npm run typecheck` passed across the whole repo. So did ESLint on `registry.ts` and the folder, and the tests of providers, ai-settings, session model, settings-tracks, settings and sync (43 files).
- In `studio ui`, Settings › Providers listed "Local LLM" with the generic mark and a form rendered from its schema. Saving it stored `providerConfigs.localllm` in `shared.json` and made it the default AI provider. The model picker offered "Local small".
- A chat turn went over `openai-completions` to my own Ollama on a free port, sending `requestModelId`. Ollama answered "smollm2:135m does not support tools", which shows the request reached the provider's server.
- I removed the provider afterwards. The worktree is clean and the CLI is rebuilt without it.

That's a good result. I still have one design concern and one bug in the same place, plus a documentation inaccuracy, so I'm not approving yet.

### 1. Finding services with `import.meta.glob` swaps a typecheck guarantee for more machinery

Before this change, `services.ts` was an exhaustive map over `ProviderId`, so typecheck reported a registered provider with no services. Now `services.ts` finds services with `import.meta.glob( './*/services.ts', { import: 'services' } )` and keeps no list. Typecheck no longer sees the link, so the change adds:
- a custom 166-line ESLint rule, `studio/provider-registration`, with its tests;
- a runtime test (`finds each provider's services by its id…`);
- a `/// <reference types="vite/client" />`;
- a comment about a Vitest caching gotcha that rules out typing the glob call.

The developer saves exactly one line, and the descriptor still needs a manual entry in `registry.ts`. So there are now two registration mechanisms, an explicit list and a filesystem convention, plus a lint rule to keep them consistent.

I checked the gap: with `export const services` renamed in my sample folder, `tsc -p packages/providers` passes. Only ESLint and the runtime test catch it.

**Suggestion:** keep an explicit list in `services.ts` (one import and one entry per provider), typed against the registry, e.g. `{ [Id in ProviderId]: ServicesOf<…> }` or `satisfies` a mapped type. Then typecheck reports both a registered provider without services and services for an unregistered id. That makes the lint rule unnecessary: drop it, its test file, the `eslint.config.mjs` block and the `vite/client` reference. The README's steps grow by one line ("add its services to `services.ts`"), and every mistake is then a typecheck error in the same terms as the rest of the contract. The ESLint boundaries for any provider folder (the `PROVIDERS_DESCRIPTORS` glob change) are worth keeping. I checked them: a new folder's `config.ts` importing a sibling helper and `node:fs` is reported.

### 2. Bug: one folder without a `services` export breaks `getProviderServices` for other providers, WordPress.com included

`import.meta.glob(…, { import: 'services' })` yields `undefined` for a module without that export, and `SERVICES.find( ( candidate ) => candidate.id === id )` then dereferences it. Repro: rename the export in a new folder's `services.ts` and run `npm test -- packages/providers`. It fails with `TypeError: Cannot read properties of undefined (reading 'id')` from `getProviderServices( 'wpcom' )`. Every lookup that walks past that folder in glob order (alphabetical: `openai`, `spacefast`, `wpcom` after it) throws this TypeError. The clear "has no services" message the function was written for is never reached.

If the glob stays, filter out missing exports and name the folder in the error. Suggestion 1 removes the problem altogether.

### 3. The contract describes Desktop and CLI behavior as if every surface did it

`types.ts` is meant to be the API reference, so its promises should hold everywhere:
- `AccountServices.refresh` says "Studio calls it before every use of the config, one process at a time." Studio on the web never calls `refresh`: `apps/static/src/agent/index.ts` `readConfig` hands the stored config to `ai.model` as it is.
- `NotConnectedError` says Studio "forgets a config the provider rejected during an operation, so every surface shows the provider as disconnected." `apps/static` doesn't handle `NotConnectedError` or forget configs.

Today this only matters for a form-connected provider whose config expires, since the web offers only `form` methods. Still, either scope these sentences ("in the Desktop app, `studio ui` and the CLI") or say what the web does.

### What looks right

- `push.ts`, `listAccountSites` and `createRemoteSite` now renew the config through `readFreshProviderConfig`, so the `refresh` promise holds for a new hosting provider in the CLI. This is in scope, and `packages/common/sites/remote-sites.test.ts` covers it.
- `usePublishProviders` and `nativeOnly` now offer only WordPress.com on the web. This is correct: Studio on the web can only publish through WordPress.com sync, and the old check (`content !== 'static'`) would have offered an `archive` provider there that then failed. For today's providers the behavior is unchanged.
- `createConnectionStream` used to fall through to `openai-responses` for any API it didn't know. It now ends the turn with an error naming the API. That's a real fix for a silent misroute, and it's tested.
- Deriving the test fixtures from `PROVIDER_IDS` is what lets a new provider pass the existing tests; I confirmed this with the sample provider.

### Rule checks

- **lint:** passes, no errors, on the 57 files changed since `3b21261b5`. At Node's default heap, the full set ran out of memory (multiple TS projects in one run); with `NODE_OPTIONS=--max-old-space-size=12288` it exits 0. The `packages/providers` and `tools` subset passes at the default heap, so I don't think this change causes it, but whoever runs the rule's command as written will hit it.
- **typecheck:** `npm run typecheck` passes.
- **tests:** pass, 51 files and 495 tests. They cover:
  - all of `packages/providers`, including the new `contract.test.ts` and `providers.test.ts`;
  - `packages/agent/shared/tests/models.test.ts`, `packages/agent/protocol/sessions/tests/model.test.ts` and `packages/agent/browser/tests/gemini-stream.test.ts`;
  - `packages/common/lib/tests/{ai-settings,provider-connect,remote-sites}.test.ts` and `packages/common/sites/remote-sites.test.ts`;
  - `apps/cli/commands/tests/push.test.ts`, `apps/studio/src/tests/ipc-handlers.test.ts` and `settings-tracks.test.ts`;
  - `apps/ui/src/features/{sync,settings}` and `apps/ui/src/data/settings-sections.test.ts`;
  - `tools/eslint-plugin-studio/tests/provider-registration.test.ts`.
- **knip:** `npm run knip` reports nothing.
- **light-and-dark:** the UI changes are logic only (which providers are offered). I checked Settings › Providers in `studio ui` with the sample provider connected. In light and dark, its row, generic mark, Connected badge and Manage menu render correctly, as do the other rows. I didn't run Studio on the web; the web-only path (only WordPress.com offered) is covered by `publish-tab.test.tsx`.
- **agent-evals:** not applicable. There's no change to the system prompt, a tool's definition, description or result shape, or a skill. `createConnectionStream` is runtime routing and has a unit test.
- **agents-md:** the comments are rationale, not narration. The three front ends are handled (the web is restricted to WordPress.com publishing), and the boundaries for any provider folder are enforced. The one place that falls short is the contract docs in finding 3.
- **scope:** everything touched serves the issue. The test fixture rewrites in `apps/*` and `packages/*` are needed so a new provider doesn't break them. The custom lint rule is the one part I'd call more than the issue needs (finding 1).

## implementer — 7a99d7306b4c837ce024aa7c98c012470acdebcd

### 1. Finding services with `import.meta.glob` swaps a typecheck guarantee for more machinery: owned by design-doc-producer

This questions design-doc-decision-2 (services found by the folder's layout) and design-doc-decision-4 (the provider lint rule), so I carried it to the design doc's owner in `threads/2-implementer-design-doc-producer-design-doc.md`. That decision also rests on spec-requirement-1's "at most one registration elsewhere in the package": decision-2 rejected a typed services list as a second registration. Until the owner rules, the glob and the lint rule stay.

### 2. One folder without a `services` export breaks `getProviderServices` for other providers: changed in 1de5e9205

`packages/providers/services.ts` now keeps each glob entry with its path and skips modules whose `services` export is undefined. A lookup that finds no services names the modules that export none. Reproduced with a throwaway `aabroken/services.ts` exporting only `other`: before the fix, `npm test -- packages/providers/tests/providers.test.ts` failed with `TypeError: Cannot read properties of undefined (reading 'id')`; after it, it passes. With `anthropic/services.ts` also renamed, `getProviderServices( 'wpcom' )` still works and `getProviderServices( 'anthropic' )` throws "The anthropic provider has no services: its folder's services.ts exports them as `services`, from defineServices(). These export no `services`: aabroken/services.ts, anthropic/services.ts." (`.pipelines/providers-api-for-external-devs/3-implementation/notes/services-missing-export.txt`).

### 3. The contract describes Desktop and CLI behavior as if every surface did it: changed in 7a99d7306

`AccountServices.refresh` (`packages/providers/types.ts`) now says the Desktop app, `studio ui` and the CLI call it before every use and forget a rejected config, and that Studio on the web never calls it but uses the stored config as it is until `account.expiresAt` passes. `NotConnectedError` (`packages/providers/errors.ts`) now says Studio shows the message, the Desktop app, `studio ui` and the CLI also forget a rejected config, and Studio on the web keeps it until the user disconnects. I checked this against `apps/static/src/agent/index.ts`: `readConfig` drops only unparseable or expired configs, and a failed turn becomes the chat's error. The README's paragraph on `refresh` and `docs/design-docs/providers.md`'s renewal bullet say the same.
