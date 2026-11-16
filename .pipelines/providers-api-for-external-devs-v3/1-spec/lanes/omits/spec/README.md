# Provider API observations

Observed against source commit `9770853292a5fd2a5aa43c2f9c600e4f81b32836`.
All commands ran from the assigned worktree. Absolute worktree paths in test
output are redacted as `<worktree>`.

## Commands and retained output

- `npm test -- packages/providers` — [provider-tests.log](provider-tests.log):
  18 files and 124 tests passed.
- `npm -w @studio/providers run typecheck` —
  [provider-typecheck.log](provider-typecheck.log): passed.
- `npm test -- packages/common/lib/tests/ai-settings.test.ts packages/common/lib/tests/provider-connect.test.ts apps/cli/ai/tests/auth.test.ts`
  — [consumer-tests.log](consumer-tests.log): 3 files and 31 tests passed.
- `node --input-type=module < .pipelines/providers-api-for-external-devs-v3/1-spec/lanes/omits/spec/observe-api.txt`
  — [api-observation.log](api-observation.log), produced by
  the probe transcript [observe-api.txt](observe-api.txt): public descriptions, methods, models,
  available operations, secret-field metadata, stored-id mapping, and operations
  without credentials. The fetch guard counted zero provider calls.

## Scope of the evidence

The probe reads and invokes existing APIs. It adds no provider and proposes no
replacement API. Its synthetic connection values are not real credentials.
Tests are evidence of current behavior, not prescribed acceptance fixtures.
The tests use their existing isolated or mocked services and storage.

No live account sign-in, paid AI request, remote push/pull, Desktop session, or
browser end-to-end flow was performed. Browser use and current host restrictions
were inspected in the source cited by the spec; a passing Node probe does not
establish browser execution.
