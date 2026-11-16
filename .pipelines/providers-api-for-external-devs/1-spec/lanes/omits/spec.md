# Spec: A clear provider authoring API

## Overview

External contributors can add a provider to `@studio/providers` through a documented, well-defined authoring contract. A contributed provider can describe its account and the existing capabilities it offers, and consumers can discover and use it through the package API.

The scope is contributing providers to Studio, not installing providers into an existing Studio distribution or opening a public package release.

## Requirements

spec-requirement-1: A contributor can add a provider with its own identifier and account configuration shape through the documented package API. After the documented integration, normal provider discovery, account connection and service requests return that provider's information and results.

origin: derived 0-intent/intent.md#goal provider additions described in packages/providers/README.md:57-59 and provider-owned identities and configuration shapes in packages/providers/types.ts:13-38

observed: `packages/providers/README.md:57-59` describes adding a provider to the repository and making it available to consumers. The current public types accept only the existing provider and model identifiers; the compiler observation is recorded in [spec/type-probe.txt](spec/type-probe.txt). Current discovery and account-operation outputs are recorded in [spec/runtime-probe.txt](spec/runtime-probe.txt).

assumed: Authoring and using an additional provider through the revised contract will confirm this outcome.

spec-requirement-2: Contributed providers can offer AI models and optional image generation, remote sites using their own site details, or both. Their models can have their own identifiers. AI remains usable without remote sites, and publication remains usable without AI or pull; discovery exposes the capabilities the provider actually offers.

origin: derived 0-intent/intent.md#goal the AI-only Anthropic, publish-only Spacefast and combined WordPress.com providers consumed through the current registry and services, and optional image generation consumed by apps/static/src/agent/index.ts:448-457

observed: [spec/runtime-probe.txt](spec/runtime-probe.txt) records these capability combinations. `packages/providers/spacefast/descriptor.ts:15-53` supplies Spacefast's site details and declares publication without pull. `packages/providers/models.ts:21-53` exposes model lists and defaults to consumers. `packages/providers/types.ts:305-319` defines the optional image-generation service consumed by the page agent.

assumed: Using the contributed provider's advertised capabilities through package consumers will confirm the same supported combinations.

spec-requirement-3: The package's authoring reference tells a contributor what information and operations are required, which capabilities are optional, what inputs and results the operations accept, and the complete integration steps needed for the provider to be discovered and used. It explains which identifiers and account values are saved for later use. The reference agrees with the accepted API and identifies its Node and page consumers and existing runtime restrictions, including redirect sign-in being specific to WordPress.com.

origin: derived 0-intent/intent.md#goal the provider authoring reference in packages/providers/README.md:18-59 and existing runtime-specific connection consumers in apps/ui/src/features/settings/settings-view/ai-panel.tsx:28-32 and apps/cli/lib/providers.ts:116-150

observed: `packages/providers/README.md:18-59` is the current account, operation and contribution reference. Its addition instructions do not identify the additional model declarations observed in `packages/providers/models.ts:1-15`. `apps/ui/src/features/settings/settings-view/ai-panel.tsx:28-32` limits the connection methods available in the page, while `apps/cli/lib/providers.ts:116-150` handles the terminal's connection methods.

assumed: A contributor following the revised reference can complete the documented integration without inferring missing contract information from another provider's implementation.

spec-requirement-4: Saved provider choices, model identifiers and account configurations that Studio can currently read remain usable with the same meaning under the same account and model availability. The saved `anthropic-api-key` identifier continues to identify Anthropic, and the WordPress.com account continues to be Studio sign-in.

origin: derived 0-intent/intent.md#goal saved provider selections and account configurations read by packages/common/lib/ai-settings.ts:33-60 and packages/common/lib/provider-config.ts:69-156, and recorded conversation choices read by packages/agent/protocol/sessions/model.ts:16-92

observed: The persisted-identifier and sign-in contracts are documented in `packages/providers/README.md:53-55` and `docs/design-docs/providers.md:40-52,120-124`. [spec/runtime-probe.txt](spec/runtime-probe.txt) records the Anthropic identifier mapping. Current stored-account and selection behavior was exercised in [spec/consumer-tests.txt](spec/consumer-tests.txt), and recorded-model handling in [spec/session-model-tests.txt](spec/session-model-tests.txt); the observations' limits are recorded in [spec/observations.md](spec/observations.md).

assumed: Reading and using those saved values after the API change will confirm that the authoring improvement alone does not require reconnecting accounts or changing provider/model choices.

spec-requirement-5: After a contributed provider accepts an account connection, later Studio operations can use that account after saved state is reloaded, without requiring a new connection solely because it is a contributed provider.

origin: derived 0-intent/intent.md#goal accepted account configurations saved by packages/common/lib/ai-settings.ts:75-96 and read for later operations by packages/common/lib/provider-config.ts:146-165,249-265

observed: The current saved-account lifecycle is exercised in [spec/consumer-tests.txt](spec/consumer-tests.txt). The page consumer also saves accepted configurations and reads them back in `apps/static/src/agent/index.ts:219-258,283-298`.

assumed: Using a contributed provider's accepted configuration in a later operation after reloading Studio's saved state will confirm this outcome.

spec-requirement-6: The authoring API supports Node consumers and Studio on the web. For account and service flows that already support calls from the page, a contributed provider remains discoverable and usable in the page without requiring a running Desktop app or Studio server.

origin: derived 0-intent/intent.md#goal provider account and model operations consumed in the page by apps/static/src/agent/index.ts:219-298,448-481, alongside the Node consumers documented in packages/providers/README.md:18-29

observed: `apps/static/src/agent/index.ts:219-298,448-481` reads provider descriptions and invokes provider account, model and image services directly in the page. `docs/design-docs/providers.md:58-68` and `packages/providers/README.md:61-68` document this supported runtime boundary. This is source observation, not a live browser or upstream-service run.

assumed: Discovering, connecting and using a contributed provider in a page-supported flow, without a Desktop app or Studio server, will confirm this outcome.

## Acceptance criteria

spec-acceptance-criterion-1: Given a contributor adding a provider with a form, device or loopback account flow supported in its intended runtime, when they consult the package's authoring reference and exported API, then the required information, optional capabilities, operation inputs and results, saved values, runtime restrictions and complete integration steps are identifiable there and agree with the API.

spec-acceptance-criterion-2: Given a contributed provider added according to the authoring contract with its own identifier and configuration shape, when consumers discover it, connect it or request its declared service operations with accepted inputs, then the package returns that provider's declared information, accepted account configuration and corresponding service results.

spec-acceptance-criterion-3: Given a contributed AI-only provider and an account configuration it accepts, when a consumer requests its model list, default model or a connection to an advertised model, then the package returns the provider's declared models and default and its connection for the requested model, without requiring remote-site functionality.

spec-acceptance-criterion-4: Given a contributed provider that publishes remote sites but offers neither AI nor pull, when a consumer discovers its capabilities, lists its sites or requests publication, then the consumer receives that provider's site details and publication result, without AI or pull being advertised as available.

spec-acceptance-criterion-5: Given a contributed provider offering both AI and remote sites, when consumers request either capability, then both are discoverable and usable under that provider's identifier and accepted account configuration.

spec-acceptance-criterion-6: Given saved provider/model choices and account configurations that Studio can read before this change, when Studio reads and uses them afterwards with unchanged account and model availability, then they identify the same provider, model and connected account without reconnection solely because of this change; `anthropic-api-key` identifies Anthropic and WordPress.com remains Studio sign-in.

spec-acceptance-criterion-7: Given a contributed provider with a successfully connected account whose saved configuration remains valid, when a later Studio operation reloads the account and requests a service, then the provider receives the accepted account configuration and the operation can proceed without reconnecting.

spec-acceptance-criterion-8: Given a contributed provider whose account flow and service endpoints support calls from the page, when Studio on the web discovers, connects or uses that provider, then its declared information and supported service results are available without a Desktop app or Studio server.

## Exclusions

spec-exclusion-1: This change does not enable users to install providers into an existing Studio distribution through plugins or user configuration.

spec-exclusion-2: This change does not make `@studio/providers` available as a publicly installable package for independent third-party applications.

spec-exclusion-3: This change does not add connection methods, provider capabilities or service-specific UI flows that Studio does not already support, or make device and loopback sign-in available in Studio on the web.

spec-exclusion-4: This change does not add a new production provider or change which provider account is Studio sign-in.

## Considered and not required

- A provider supplied by a runtime plugin or user configuration — no current contribution flow produces one; observed: `docs/design-docs/providers.md:147-150` explicitly excludes runtime-added providers, and `packages/providers/README.md:57-59` describes repository contributions.
- Installing a published package into an independent third-party application — the Goal names adding to `@studio/providers`, and intent-context-1 concerns opening contributions; observed: `packages/providers/package.json:1-10` marks the package private and the documented addition flow is in-repository.
- A provider offering an account but neither AI nor remote sites — the types admit this, but no listed provider has this combination and settings enumerate AI and site providers; observed: [spec/runtime-probe.txt](spec/runtime-probe.txt) and `apps/ui/src/data/settings-sections.ts:300-333`.
- A contributed preview capability, custom provider UI, or new sign-in protocol — the Goal asks for a clearer API for adding providers, not completion of planned features; observed: `docs/design-docs/providers.md:20,136-138` marks custom UI and provider previews planned, and `packages/providers/types.ts:67-85,149-180,289-321` defines the current account methods and capabilities.
- Device or loopback sign-in performed inside Studio on the web — the existing page consumer excludes those methods rather than attempting them; observed: `apps/ui/src/features/settings/settings-view/ai-panel.tsx:28-32` and `docs/design-docs/providers.md:112-114`.
- Adding a particular new production service — the Goal asks for an authoring API and names no service to add; the documented contribution flow in `packages/providers/README.md:57-59` supports additions without identifying a required new service.
- A turn combining model connections from multiple providers — no documented turn consumer asks for it; observed: `docs/design-docs/providers.md:97-101` describes a connection to the selected provider's model per turn and `:147-150` explicitly excludes mixing providers within one turn.
- Restoring a model identifier that Studio no longer offers — the API improvement preserves currently readable choices rather than restoring retired offerings; observed: `packages/agent/protocol/sessions/model.ts:36-72` applies the current default when a recorded model is no longer offered.
- Compatibility with unspecified future revisions of an external provider — no released external contribution or version pairing is identified by the intent or the in-repository contribution reference; the required account reload and existing saved-value behavior do not establish a new third-party release policy.
- Reading “easily” as a prescribed helper, file layout, registration count or elapsed-time target — the Goal and documented contribution flow support a complete, usable authoring contract, not one mandated implementation or numerical authoring budget.
