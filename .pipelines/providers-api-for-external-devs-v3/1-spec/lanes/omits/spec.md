# Spec: A clear provider authoring API

## Overview

External contributors can add a compiled-in provider to `@studio/providers` through a clear public contract and complete addition instructions. The contract explains account behavior and the capabilities a provider offers, while keeping existing providers usable by Studio's consumers.

## Requirements

spec-requirement-1: A contributor can determine from the public authoring API and its documentation what to supply for a provider's identity, presentation, account configuration, connection lifecycle, and offered capabilities, including operation inputs and results. The documented addition process covers the integration needed for Studio to discover the provider and call its operations, and distinguishes the provider's responsibilities from the host's.

origin: derived Goal the contributor addition flow and host-owned configuration documented in `packages/providers/README.md:18-59`

observed: `packages/providers/README.md:18-59` describes the current authoring flow and host-owned configuration. Adding an AI provider also involves the capability membership in `packages/providers/types.ts:14-35` and the model catalog in `packages/providers/models.ts:1-17`, which the README's addition instructions do not identify. Current public descriptions and operations are observable through the probe recorded in [spec/api-observation.log](spec/api-observation.log).

spec-requirement-2: The contract makes required and optional operations clear for the offerings Studio already uses: chat without image generation or remote sites; remote publishing without chat or pull; and combined AI and remote-site offerings. An author does not have to provide operations for offerings the provider lacks. Account-dependent availability of models and image generation remains expressible and available to consuming hosts.

origin: derived intent-proposal-1 Anthropic's chat-only offering, Spacefast's publish-only offering, WordPress.com's combined offering, GitHub Copilot's account-restricted models, and OpenAI's connection-dependent image support in `packages/providers/anthropic/services.ts:6-10`, `packages/providers/spacefast/descriptor.ts:28-32`, `packages/providers/wpcom/services.ts:8-13`, `packages/providers/github-copilot/descriptor.ts:23-32`, and `packages/providers/openai/ai.ts:49-51`

observed: The public API inventory and connection-dependent image availability are recorded in [spec/api-observation.log](spec/api-observation.log). Hosts act on these distinctions in `apps/cli/ai/auth.ts:84-145` and `packages/common/sites/remote-sites.ts:39-68`.

spec-requirement-3: A contributor can supply the provider's own configuration, offered model identifiers, and, when applicable, remote-site data through the authoring contract. TypeScript authors and consumers receive the corresponding configuration and remote-site field types when implementing or using an operation; adding a provider does not require it to claim another provider's configuration or site fields.

origin: derived Goal the different account configurations and model catalogs already supplied by Anthropic and OpenAI, and WordPress.com's numeric-id sites versus Spacefast's string-id Spaces, in `packages/providers/anthropic/config.ts:3-9`, `packages/providers/openai/config.ts:3-20`, `packages/providers/models.ts:1-17`, `packages/providers/wpcom/sites/site.ts:18-36`, and `packages/providers/spacefast/descriptor.ts:5-15`

observed: The existing public contracts associate operations with configuration and site types (`packages/providers/types.ts:153-183,240-324`; `packages/providers/services.ts:10-25`). The current package type-checks, recorded in [spec/provider-typecheck.log](spec/provider-typecheck.log).

spec-requirement-4: Existing providers retain their supported account connections, model offerings, image availability, and remote-site operations in the CLI, Desktop app, `studio ui`, and Studio on the web wherever each is supported today. Existing valid saved accounts, provider/model selections, and local-to-remote site connections remain usable without reconnection or reselection solely because of this API change. Provider choices and connection-form information remain readable without credentials or contacting the provider.

origin: derived Goal the provider-driven settings and operation calls in `apps/ui/src/data/settings-sections.ts:300-332`, `apps/ui/src/features/settings/settings-view/ai-panel.tsx:28-80`, `apps/cli/ai/auth.ts:84-145`, and `apps/static/src/agent/index.ts:430-481`, together with stored account and site connections in `packages/common/lib/provider-config.ts:21-26,73-158` and `packages/common/lib/remote-sites.ts:115-150`

observed: The probe reads provider descriptions and forms with zero provider fetch calls and confirms the Anthropic stored-id mapping ([spec/api-observation.log](spec/api-observation.log)). Current provider and selected consumer behavior passes 124 provider tests and 31 consumer tests; commands, results, and observation limits are recorded in [spec/README.md](spec/README.md). Browser operation use and runtime restrictions are observed in `apps/static/src/agent/index.ts:448-481`, `apps/ui/src/features/settings/settings-view/ai-panel.tsx:28-32`, and `apps/ui/src/data/queries/use-remote-sites.ts:24-30`.

## Acceptance criteria

spec-acceptance-criterion-1: Given a newly contributed provider using Studio's supported account and capability flows and integrated according to the public addition instructions, when a host discovers and uses it through the provider API, then its presentation, connection methods, and offered operations are available as documented, with no undocumented integration obligation needed to make them usable. Covers spec-requirement-1.

spec-acceptance-criterion-2: Given an author implementing a provider with its own configuration and remote-site fields, when the public TypeScript contracts are used to implement and consume its operations, then those fields and their declared types are available at the relevant inputs and results, without supplying fields belonging only to another provider. Covers spec-requirement-3.

spec-acceptance-criterion-3: Given a provider offering chat but neither image generation nor remote sites, when it is authored and discovered, then its chat offering is usable without image or site implementations, and absent offerings are distinguishable by hosts. Covers spec-requirement-2.

spec-acceptance-criterion-4: Given a provider offering remote publishing but neither AI nor pull, when it is authored and discovered, then its publishing offering is usable without model, image, or pull implementations, and hosts can distinguish those absent offerings. Covers spec-requirement-2.

spec-acceptance-criterion-5: Given account-restricted models or a connection method that cannot generate images, when the host resolves that account's offerings, then it offers only the permitted models and does not select that account for unsupported image generation. Covers spec-requirement-2.

spec-acceptance-criterion-6: Given the existing registered providers and no credentials, when their choices and connection forms are read in Studio's supported runtimes, then their presentation and connection information are available without contacting provider services. Covers spec-requirement-4.

spec-acceptance-criterion-7: Given existing valid saved accounts, provider/model choices, and remote-site connections, when Studio reads and uses them after the API change, then they still identify the same accounts, offerings, and remote sites without requiring the user to reconnect or reselect them because of the change. Covers spec-requirement-4.

spec-acceptance-criterion-8: Given an existing provider and an operation supported by the current host, when the user connects, chats, generates images, or publishes or pulls a site as applicable, then the operation remains available with its existing user-visible behavior, including both AI and site operations for a provider offering both. Connection methods and publishing modes currently unavailable in Studio on the web remain unavailable rather than becoming reachable non-working options. Covers spec-requirement-2 and spec-requirement-4.

spec-acceptance-criterion-9: Given an AI provider with newly contributed model identifiers registered according to the addition instructions, when a host queries the model API, then the provider's offered identifiers are discoverable there. Covers spec-requirement-1 and spec-requirement-3.

## Exclusions

spec-exclusion-1: This change does not publish the package for external installation or let users install or configure additional providers at runtime.

spec-exclusion-2: Users do not gain an additional built-in provider, a new authentication flow, or a new end-user service capability, including provider-based preview creation.

## Considered and not required

- Providers loaded from plugins or user configuration — observed: the documented addition flow is compiled-in registration, and runtime providers are explicitly outside the existing design (`packages/providers/README.md:57-59`; `docs/design-docs/providers.md:148-151`).
- Compatibility for outside code using the exact current exported TypeScript signatures — not the reading taken: Goal and intent-proposal-1 ask to improve the API, and intent-context-1 says the package is not yet open to external contributors; existing Studio behavior and saved data, rather than those signatures, are preserved.
- A provider offering only image generation, or only an account with neither AI nor remote sites — no such provider or consumer use is shown by the current registered offerings; observed: [spec/api-observation.log](spec/api-observation.log) and `apps/cli/ai/auth.ts:118-145` show image providers discovered among chat providers.
- Runtime diagnostics for deliberately contradictory provider declarations or direct lookup of an unregistered provider identifier — no intended consumer supplies these inputs; observed: lookup accepts registered identifiers (`packages/providers/registry.ts:41-57`; `packages/providers/services.ts:10-25`). An unknown saved AI selection already has a separate fallback (`packages/common/lib/tests/ai-settings.test.ts:313-320`).
- Making device/loopback sign-in or static-site publishing work in the page — observed: the UI omits those options where the host cannot support them (`apps/ui/src/features/settings/settings-view/ai-panel.tsx:28-32`; `apps/ui/src/data/queries/use-remote-sites.ts:24-30`); Goal does not request expanded host capabilities.
- A new preview provider or a redesign of settings and publishing — no added provider or redesigned workflow is named by the intent; observed: previews still use the WordPress.com upload path (`packages/providers/services.ts:28-29`), while current settings already consume provider information (`apps/ui/src/data/settings-sections.ts:300-332`).
