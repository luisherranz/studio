---
status: open
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
