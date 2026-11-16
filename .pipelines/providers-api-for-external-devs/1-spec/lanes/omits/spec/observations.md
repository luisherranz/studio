# Provider authoring observations

## Revision and scope

The running package and compiler observations in [runtime-probe.txt](runtime-probe.txt), [type-probe.txt](type-probe.txt) and [provider-tests.txt](provider-tests.txt) used revision `924fe372f29bc036cc2cc74b4458a5127872cfe3`. The input revision is `814fb6bb1705a93b6adee96b06d2089a6e3ebc51`; the intervening commit changes only the intent, not the observed software.

Absolute local worktree paths in test output are replaced with `<worktree>`.

The latest intent concerns external contributors adding to the package through a clear API. It names no new provider, connection protocol, publication target or runtime loading mechanism.

## Running observations

- [runtime-probe.txt](runtime-probe.txt): loaded the existing package entry points with Vite's SSR loader, enumerated descriptors and services, read connection-form metadata, and invoked three account services with blank API-key input. All three rejected the input with `ConnectError: API key is required`. It also records existing model counts, independent capability combinations, persisted Anthropic identifier mapping and remote-site input interpretation. No successful external-service connection or paid operation was attempted.
- [type-probe.txt](type-probe.txt): TypeScript checked an in-memory consumer of the current public types. Existing provider/model names were accepted; an additional provider name and model name each produced TS2322. This observes the current closed sets, not whether any proposed replacement would work.
- [provider-tests.txt](provider-tests.txt): `npm test -- --project=providers` passed 16 files and 117 tests. This is evidence of current behavior, not a mandated test suite or a requirement to preserve every assertion.
- [consumer-tests.txt](consumer-tests.txt): the existing AI-settings and provider-connect tests passed two files and 16 tests. These execute the current shared account/selection code, including legacy selections and configurations, in temporary configuration directories with network responses substituted by the tests. They do not establish that live credentials work or that a new provider already integrates.
- [session-model-tests.txt](session-model-tests.txt): the current recorded-model behavior test passed one file and one test. `packages/agent/protocol/sessions/model.ts:16-92` reads saved conversation provider/model choices, retains models still offered and applies defaults for models no longer offered; preserving readable choices does not require restoring retired models.

## Intended inputs and authoring boundaries

- `packages/providers/README.md:57-59` documents contributions inside the repository, including provider registration and Studio-side storage integration. It does not describe runtime installation or a third-party package consumer.
- `packages/providers/types.ts:13-40`, `registry.ts:18-48`, `services.ts:9-23` and `models.ts:1-15` enumerate the current identities and their associated configurations, capabilities and models. The README's addition instructions do not enumerate the AI model declarations.
- `packages/providers/anthropic/descriptor.ts:50-102`, `spacefast/descriptor.ts:15-53` and the running enumeration establish AI-only, publish-only and combined capabilities as current inputs. Spacefast's site details include a slug and team in addition to the common site identity, name and URL.
- `packages/common/lib/provider-config.ts:69-156` reads provider-owned configuration through Studio's stores. `packages/common/lib/remote-sites.ts:115-150` similarly records site connections outside providers. These show current host integration responsibilities, not a requirement for a particular storage redesign.
- `apps/ui/src/features/settings/settings-view/ai-panel.tsx:28-32` filters unsupported page sign-ins; `apps/cli/lib/providers.ts:116-150` selects supported terminal connection flows. A clearer authoring contract need not make every method available in every runtime.
- `apps/static/src/agent/index.ts:219-298` reads provider descriptions, saves accepted account configurations and calls account services directly in the page. `apps/static/src/wpcom-services.ts:34-43` likewise uses WordPress.com site services from the page. These source observations establish page consumers of the existing API, not a live browser or vendor-connectivity result.
- `apps/static/src/agent/index.ts:448-481` requests the selected provider's model connection and uses its image-generation operation when present and supported by the account. Optional images are an existing service input, not a new capability requested by this change.
- `apps/ui/src/data/settings-sections.ts:300-333` enumerates AI and remote-site providers. Current descriptors have at least one of those capabilities; no current account-only settings consumer was established.
- `docs/design-docs/providers.md:40-52,120-124` and `packages/providers/README.md:53-55` describe Studio sign-in and existing persisted identities. The runtime identifier probe and shared consumer tests corroborate the observed compatibility cases.
- `docs/design-docs/providers.md:20,136-150` distinguishes planned custom UI and preview capability work from current features and explicitly excludes runtime-added providers and mixing providers in a turn.

## Limits

No solution code, proposed helper or replacement registration scheme was built. No real account, provider API, WordPress site, CLI daemon or Studio UI was changed or exercised. The observations establish the package's present interfaces and existing consumers, not the usability of a future API or connectivity to an unnamed service.
