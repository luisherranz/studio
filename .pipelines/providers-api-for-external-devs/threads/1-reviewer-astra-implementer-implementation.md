---
status: approved
opener: reviewer-astra
recipient: implementer
about: implementation
---

## reviewer-astra — 69e43ee8f2523f73b9a9beef68cdb2a14491cb7d

### Review: changes requested

The single registration, derived types and contributor guide make adding a provider substantially clearer. I would fix these two contract issues before merging.

#### 1. [P2] Require `start` when any connect method needs it

**`packages/providers/types.ts:633–637`**

The conditional distributes over `Method`. For a provider with both a form and a device/loopback method, the result includes `unknown`, which absorbs the required `start` member. Consequently `defineServices` accepts an account with only `connect`, even though choosing its interactive sign-in cannot work. An in-memory TypeScript probe confirmed that the mixed-method descriptor compiles without `start`; the current negative test covers only a single device method.

Test whether `Extract<Method, { kind: SignInKind }>` is nonempty instead, and add negative type tests for form + device and form + loopback. This is a normal supported combination, already used by OpenAI, not an invalid-input edge case.

#### 2. [P2] Do not handle a rejected refresh twice

**`packages/common/sites/remote-sites.ts:36–40, 54–56`**

Putting `readFreshProviderConfig` inside `forgetRejectedConfig` nests two rejection handlers. When a hosting provider's `refresh` throws `NotConnectedError`, the inner handler removes its config and saves `account.remember(config)`. The outer handler then catches the same error, finds no config, and calls `writeProviderConfig(id, undefined)` again. That call clears the newly saved `rememberedSignIns` entry. The next sign-in loses the registration it was supposed to reuse.

I reproduced this through `listAccountSites` with a synthetic hosting service reusing OpenAI's real refreshing account/config: after rejection, the expected `{ clientId: 'oaiapp_registration' }` was `undefined`. The temporary probe was removed. No current built-in hosting provider refreshes, but the new external-provider contract explicitly supports this lifecycle. Read the fresh config outside the outer rejection wrapper, or make rejection cleanup idempotent; cover both listing and creation with a refreshing account that remembers registration data.

### Required checks

- **lint:** Passed, without `--fix`, for every added/modified JS/TS file since `3b21261b531ccfdf20be79440ab217bb07b9f52c`. The default-heap run and a batched retry exhausted Node's 4 GB heap; the same full changed-file selection passed with `NODE_OPTIONS=--max-old-space-size=8192`. Only the multiple-projects advisory remained.
- **typecheck:** `npm run typecheck` passed.
- **tests:** 41 test files / 395 tests passed across the provider package, changed agent model/session tests, common config/connect/remote-site tests, CLI push, Electron IPC/settings tracking, UI publishing/settings/model pickers and ESLint plugin. This includes every changed test file. Separately, the temporary regression probe for finding 2 failed as described above.
- **knip:** `npm run knip` passed with no findings.
- **light-and-dark:** Built with `npm run cli:build:ui`. In isolated `studio ui`, checked the AI/hosting provider rows, labels, icons and connection controls in both schemes; WordPress.com and Spacefast remained available for hosting. In `dev:static`, checked the same settings in both schemes; hosting offered only WordPress.com, and unsupported device providers were absent. No changed visual defect found. Desktop was not launched; its IPC tests passed. No sites or credentials were created; both servers and the browser session were stopped, and isolated `site stop --all` confirmed no running sites.
- **agent-evals:** Not applicable: no system prompt, tool definition/description/result shape, or agent skill/instruction changed. The stream dispatch guard has a targeted unit test.
- **agents-md:** Reviewed against the provider README/design doc, UI README and CLI/host conventions. The descriptor/service boundary and shared storage/locking approach are retained. The expanded API documentation is appropriate to this issue; findings above concern guarantees that it advertises.
- **scope:** No unrelated refactor identified. Consumer/storage adjustments support registering providers without editing each consumer. No implementation changes made during review.

Review scope: branch compared with `76c54690ba3f802aee117ca1fd067db48688e313`.

## implementer — 7a99d7306b4c837ce024aa7c98c012470acdebcd

### 1. Require `start` when any connect method needs it: changed in 968f1e787

`ServicesOf` now tests whether `Extract< Method, { kind: 'loopback' | 'device' } >` is non-empty instead of distributing over `Method`, so a form next to a device or loopback method still requires `start` (`packages/providers/types.ts`). `packages/providers/tests/contract.test.ts` gains negative cases for form + device and form + loopback, and a positive one with `start`. Before the fix the new `@ts-expect-error` was reported as unused (TS2578), confirming the hole. After it, the error is "Property 'start' is missing … but required in type 'Required<Pick<AccountServices<…>, "start">>'", at the services argument (`.pipelines/providers-api-for-external-devs/3-implementation/notes/contract-type-errors.txt`). `npm run typecheck` passes, OpenAI's loopback + form account included.

### 2. Do not handle a rejected refresh twice: changed in d8cd354fa

`listAccountSites` and `createRemoteSite` (`packages/common/sites/remote-sites.ts`) now read `readFreshProviderConfig( provider )` before entering `forgetRejectedConfig`. A rejected renewal is then forgotten once, by `readFreshProviderConfig`, which keeps `account.remember`. `studio push` already read it outside its wrappers. `packages/common/sites/remote-sites.test.ts` adds a test with a refreshing account that remembers its registration (OpenAI's ChatGPT descriptor, `clientId`), for both listing and creating. Before the fix it failed with `expected undefined to deeply equal { clientId: 'oaiapp_registration' }`. After it, it passes, and the operation's own service is never called.

## reviewer-astra — 613076843be99f51993f91fa1462b68dd8780791

### Approved

Both findings are resolved:

- `ServicesOf` now requires `start` if any declared method is device or loopback. The mixed-method negative cases and positive case pass typecheck.
- Listing and creation obtain the refreshed config outside the rejection wrapper. The regression test confirms both operations preserve remembered registration data when refresh fails and never call their site service.

I also reviewed the remaining changes in `reviewer.diff`: missing service exports no longer cause an unrelated undefined-property exception during lookup, and the credential-lifecycle documentation now accurately distinguishes Studio on the web. No further blocking findings.

### Checks

- **lint:** Passed without `--fix` on the complete changed/untracked JS/TS selection since `3b21261b531ccfdf20be79440ab217bb07b9f52c`, using an 8 GB Node heap; only the multiple-projects advisory appeared.
- **typecheck:** `npm run typecheck` passed.
- **tests:** 41 files / 396 tests passed, including every changed test and the relevant provider, common storage/connect/sites, agent model, CLI push, Electron IPC/settings, UI publishing/settings/model-picker and lint-rule tests.
- **knip:** `npm run knip` passed with no findings.
- **light-and-dark:** No additional UI/CSS changes since the preceding review. Its light/dark checks of provider settings in `studio ui` and Studio on the web still apply; Desktop was not visually checked. No servers or sites started this round.
- **agent-evals:** Not applicable; no prompt, tool contract or agent instruction changed.
- **agents-md:** Rechecked the fixes against the provider contract, storage lifecycle and repository conventions; no remaining violation identified.
- **scope:** Fixes, regression tests, diagnostics and documentation stay within the provider-extension goal. No unrelated refactor identified.

Reviewed the author's answers and the supplied incremental diff, with the complete change based on `58b9121eedd70b420e58f664d6ffc4d24d15d73d`. I would merge this version.
