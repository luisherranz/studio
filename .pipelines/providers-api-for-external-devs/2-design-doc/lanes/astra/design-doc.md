# Design Doc: A folder-local provider contract

## Overview

A provider contribution consists of its own folder and one descriptor registration. The package derives its public provider, config, site and model types and its capability lists from that registration. Services remain a separate, browser-safe entry, discovered at build time from the registered folders. A checked, folder-local authoring contract connects each descriptor to the services it promises.

Studio continues to own accounts' persistence, local-site connections and the execution of local site operations. Its consumers become capability-driven rather than maintaining exhaustive lists of today's providers. Compatibility exceptions remain exceptions for the existing stored data and the Studio sign-in, not extension points every contributor must implement.

## Architecture

| Component | Responsibility after the change |
| --- | --- |
| Each provider folder | Browser-safe descriptor, config schema and account presentation; account services and the capabilities it offers; provider-local tests. |
| Package authoring types and helpers | Describe a provider independently of the registered-provider union; check the relationship between its descriptor and services. |
| Surface registry and model utilities | One ordered registration source; derived identities, capability membership and model lookup; synchronous metadata access with no service dependency. |
| Services entry | Resolve a registered provider's checked service export from build-time folder discovery; preserve synchronous service lookup for hosts. |
| Provider lint rules and repository tooling | Recognize any provider folder, enforce the authoring and import boundaries, and include its services without another allowlist or registration. |
| `@studio/common` storage and account operations | Generic config and remote-site persistence, with existing legacy adapters; account renewal and shared connection operations. |
| `apps/static` | Equivalent account lifecycle over its existing browser storage; in-page account, chat and image execution. |
| UI connectors, CLI and agent hosts | Consume capability-derived data and resolve services; retain their existing transport and local-operation responsibilities. |
| Agent stream adapter | Run exactly the four supported model APIs, independent of the provider supplying the connection. |

The renderer-facing entry stays separate from the service entry. Neither imports Node APIs or another workspace package. The CLI remains the one implementation of machine-local publishing; the Desktop and local-server wrappers do not gain provider-specific publishing code.

## Decisions

design-doc-decision-1: One descriptor registration, with separate build-time service discovery

**Serves:** spec-requirement-1, spec-requirement-2, spec-requirement-3, spec-requirement-7, spec-requirement-9.

**Decision:** Use one ordered descriptor registry as the authority for registered identities and capability membership. Provider authors register their folder's descriptor there and nowhere else. Derive provider-id, config, remote-site and model-id types from those descriptors; remove the manually maintained parallel unions and capability lists. Authoring types take local identity, config, site and model parameters rather than importing those derived unions back into the declarations they describe.

The services entry discovers conventional service exports in provider folders at build time, using the existing Vite toolchain. Only registered providers are exposed by its lookup. The folder name is its provider id, and the descriptor and service exports belong to that same identity. Registration does not import services, including through a loader. Surface consumers keep synchronous descriptor lookup, and service consumers keep synchronous service lookup.

The existing providers retain their current relative precedence, with WordPress.com first. New registrations follow them. Capability-specific lists preserve registry order. Global model lookup keeps first-provider precedence, including label, vision support and paid-credit metadata; it does not replace an existing listing when a later provider offers the same id.

**Alternatives:** Combining descriptor and services in one imported definition would remove discovery but violate the surface-only dependency boundary. Keeping two registrations preserves today's silent omission. Generating both registries from a new manifest could satisfy the contract, but adds generated artifacts and generation lifecycle to builds, tests and direct typechecks where Vite already supplies build-time discovery. Runtime plugin discovery is outside the intended use.

**Trade-offs:** Discovery makes the source package depend on its supported build/test toolchain rather than plain Node module loading. A folder convention and its lint enforcement replace a handwritten service map. This preserves the existing synchronous host API and keeps service code out of the renderer graph.

**Claims:** observed: `packages/providers/registry.ts:18-48`, `packages/providers/services.ts:9-24` and `packages/providers/models.ts:9-15` maintain separate lists; `packages/providers/models.ts:31-41` implements first-match lookup. observed: `packages/agent/shared/skills.ts:14-18` already uses Vite build-time discovery in code shared by Node and browser agents; `apps/cli/vite.config.base.ts`, `apps/studio/electron.vite.config.ts` and `vitest.config.ts` bind the relevant toolchains. assumed: design-doc-assumption-1, confirmed by contributor diagnostics and built-entry proofs below.

design-doc-decision-2: Check capabilities against their implementations in the provider's folder

**Serves:** spec-requirement-1, spec-requirement-2, spec-requirement-3, spec-requirement-5, spec-requirement-6.

**Decision:** The public authoring API has two related contracts: a descriptor that preserves its literal identity and declared capabilities, and services checked against that exact descriptor. Config arguments and returned configs use the descriptor's schema type; remote sites share the provider's declared site type. A mandatory checked service declaration in each registered folder is part of the authoring contract, not an optional convention.

Account connection is required. Form methods need their input schema and connection implementation; device and loopback methods additionally require account-start support. Chat metadata requires a model-connection service. Image generation is an independently declared capability requiring image-generation services, with optional account-dependent availability. Remote-site presentation requires listing and pushing services, and declarations of site creation or pull require their corresponding services. Capability omissions produce diagnostics naming the missing member in the provider folder or registration.

Chat, images and hosting can be combined independently, but a provider must offer at least one. In particular, an image-only provider is connectable and eligible for image fallback without being a chat choice or needing a fictitious default model. Model declarations and defaults are local to the provider; account model restrictions refer to that provider's models.

The ordinary authoring contract excludes `redirect`: it remains the WordPress.com Studio sign-in contract. Existing `requiresPaidAiCredits` and `paidDefaultModel` metadata remain tied to WordPress.com's quota, not a new provider's billing; ordinary providers leave them unset. The common publishing contract retains the current push arguments for compatibility; other providers do not act on WordPress.com's selective-sync and launch options or the `planRequired` listing option. WordPress.com's checkout and pull/exporter integration remain explicitly scoped extensions, not newly supported third-party hosting capabilities.

The model connection accepts only `openai-completions`, `openai-responses`, `anthropic-messages` and `google-generative-ai`. It retains the current endpoint, credential, header, limits, upstream-alias and error-rewrite responsibilities. Provider code owns its network protocol and errors, not persistence, prompts or process exit.

**Alternatives:** Making every service optional leaves the current descriptor/service mismatch undiagnosed. Requiring all providers to implement every capability creates meaningless stubs. Flattening config, site and model types to unqualified strings and unknown values would reduce inference work but move contributor mistakes into hosts. Redesigning the WordPress.com sync protocol would expand scope without helping the required publishing contribution.

**Trade-offs:** Stronger local types and a mandatory declaration constrain the provider folder's public exports. They eliminate the need for casts or manually extended shared type maps in a normal contribution. Existing WordPress.com-specific types remain in the API, clearly scoped rather than falsely generalized.

**Claims:** observed: `packages/providers/types.ts:150-180,288-321` allows descriptor capabilities and service capabilities to vary independently; its lines 67-85, 182-192 and 237-285 expose the connect, model and sync contracts. observed: `packages/providers/spacefast/sites.ts:55-74` ignores sync options and accepts static content; `packages/providers/wpcom/descriptor.ts:68-100` uses Studio sign-in, paid defaults and the existing sync capabilities. assumed: design-doc-assumption-1, confirmed by local authoring diagnostics and consumer typechecks.

design-doc-decision-3: Generic storage defaults with explicit compatibility exceptions

**Serves:** spec-requirement-1, spec-requirement-2, spec-requirement-8, spec-requirement-9.

**Decision:** `@studio/common` supplies the ordinary storage policy for every registered provider without a provider-specific adapter: schema-validated config under `providerConfigs.<id>` and local-site links under the existing generic remote-site storage. Provider-specific site fields survive round trips alongside Studio's link and synchronization metadata. Local-site deletion removes its connections across registered sites providers. Providers supply schemas and account behavior, not persistence functions.

Keep the WordPress.com and Anthropic compatibility adapters instead of migrating their data. WordPress.com remains in `authToken` and `connectedWpcomSites`, with its environment-token override and Studio sign-in semantics. Anthropic's API key remains in `anthropicApiKey`; its subscription configuration remains in `providerConfigs`, with existing mutual exclusion and the legacy CLI-config fallback. Preserve remembered sign-ins, host identity, timestamps and defaults. Identity serialization defaults to the registered id; Anthropic alone keeps its existing legacy alias on reads and writes, including session entries.

The browser backend retains its existing storage format and validates every registered provider's config using the same descriptor contract. Account connection, disconnection, renewal and rejected-credential handling apply to any registered provider. Hosts supply fresh configuration for model, image and remote-site services; renewed configuration becomes the persisted account state, and definitive credential rejection becomes disconnected state. Config expiration means the account configuration is unusable, not merely that its renewable access token needs replacement.

Node config writes retain the shared-config lock; renewal retains its separate per-provider lock against concurrent token use. Local-site metadata writes retain their owning storage lock. The browser backend owns its own storage lifecycle rather than importing Node persistence.

**Alternatives:** A storage adapter for each provider preserves today's contribution burden. Migrating all accounts into one new format is conceptually uniform but breaks old builds reading new writes. Moving storage into providers violates the browser-safe, storage-free package boundary.

**Trade-offs:** Two account compatibility exceptions and the WordPress.com site adapter remain deliberately permanent. The generic default removes future entries from exhaustive store maps without erasing compatibility behavior.

**Claims:** observed: `packages/common/lib/provider-config.ts:39-61,73-169,223-269` implements legacy reads, exhaustive stores, schema validation, rejection handling and separately locked renewal; `packages/common/lib/remote-sites.ts:69-169` stores arbitrary site fields but selects stores and deletion cleanup from an exhaustive map. observed: `apps/static/src/agent/index.ts:219-259,283-320,412-523` owns the page's persistence but its chat path does not renew or invalidate rejected provider configs; `packages/providers/openai/account.ts:155-175` distinguishes renewable token expiry, rejected renewal and transient failure. assumed: design-doc-assumption-2, confirmed by bidirectional persistence and account-lifecycle proofs.

design-doc-decision-4: Consumers select capabilities, not a list of provider names

**Serves:** spec-requirement-1, spec-requirement-2, spec-requirement-8, spec-requirement-9.

**Decision:** Registry-derived views distinguish connectable accounts, chat providers, image providers and hosting providers. Each consumer selects the view it actually needs:

- Settings displays AI accounts offering chat or images, and hosting accounts offering sites; a mixed provider has one account across both sections.
- Default chat selection, chat fallback, session resolution, model pickers and CLI `/provider` and `/model` accept chat providers only. Model pickers honor the connected account's model restriction.
- `/connect`, `/disconnect` and account settings accept all relevant registered accounts, with their declared methods and account summaries.
- Machine-local image resolution accepts connected image providers independently of chat capability. The current chat's capable account wins; otherwise registry precedence chooses the first connected account able to generate images. The page retains its existing WordPress.com fallback policy while supporting the selected chat provider's image capability.
- Default hosting selection, publish-panel data, remote-site parsing and agent hosting operations accept every registered sites provider. Local publishing still runs the CLI's existing archive/static-export operation, with the provider responsible for the remote side.

Desktop and `studio ui` expose forms, device and loopback methods through the existing shared account operations. Studio on the web exposes supported forms and its separate Studio sign-in, not device or loopback flows. No provider gains UI components, custom IPC endpoints or a second publishing implementation. The existing WordPress.com and Spacefast presentation exceptions stay, while new providers use the generic descriptor presentation and logo fallback.

Tests and test-state factories outside provider folders must no longer require edits whenever the registered set grows. Their contracts distinguish an intentionally selected account or model from exhaustive account-state construction.

**Alternatives:** Keeping one list for both chat selection and image fallback leaves image-only services unusable or selectable as broken chat providers. Per-surface registries repeat the omission risk. Removing all WordPress.com and Spacefast exceptions is not required and would unnecessarily change established flows. Broadening the page's image fallback is not chosen: spec-requirement-2 explicitly names the machine-local surfaces for general fallback, while requiring the page to run its chat provider's image service.

**Trade-offs:** Several consumers need a one-time capability distinction. Existing transport contracts and UI primitives can remain; only provider membership and generic state construction broaden. No new account-store mirror is introduced in a host process.

**Claims:** observed: spec-requirement-2 cites the registry consumers and surface-specific connect and image policies; `packages/providers/models.ts:21-53` currently assumes AI selection has a default chat model; `apps/cli/ai/auth.ts:118-145` combines chat-provider and image-provider discovery. observed: `apps/ui/src/data/settings-sections.ts:300-333` derives settings entries from AI/site lists, and `apps/cli/ai/host.ts:58-75` derives agent remote sites from sites providers. observed: `docs/design-docs/cli-host-communication.md:13-17` assigns local operations and writes to the CLI; `apps/ui/README.md:9-24,135-141` defines connector and verification boundaries. assumed: design-doc-assumption-3, confirmed by surface-wiring and host-resolution proofs.

design-doc-decision-5: The agent never substitutes an API dialect

**Serves:** spec-requirement-2, spec-requirement-6, spec-requirement-9.

**Decision:** The shared agent stream boundary explicitly supports each of the four connection APIs. Unsupported runtime API values produce an error naming the unsupported API and cause no model request. The browser adapter retains the existing API-specific transport behavior. Providers using a supported API need no agent registration or bundle exclusion change.

Request-model aliases, connection credentials and headers, stream error rewriting and existing request cleanups retain their current meaning. The provider remains responsible for returning a usable connection; the runtime remains responsible for streaming it over the declared dialect.

**Alternatives:** Relying only on narrowed TypeScript types would leave the existing pi-facing runtime boundary's broader model input able to reach the fallback dialect. Keeping the OpenAI Responses fallback is incorrect for an unsupported API. Automatically adopting every pi API adds unsupported SDKs and exceeds the four-API scope.

**Trade-offs:** A small runtime rejection complements local type diagnostics. The runtime does not infer an alternative protocol or add provider-specific dispatch.

**Claims:** observed: `packages/agent/shared/models.ts:17-29` defaults all unmatched APIs to OpenAI Responses; `packages/agent/browser/models.ts:17-25` handles Google's fetch restriction. assumed: design-doc-assumption-4, confirmed at the shared-stream and browser-stream boundaries.

design-doc-decision-6: Folder-wide enforcement and an author-facing contract

**Serves:** spec-requirement-1, spec-requirement-3, spec-requirement-4, spec-requirement-5, spec-requirement-7.

**Decision:** Extend the existing provider boundary enforcement to any provider folder rather than enumerating current names. Surface files may import only permitted surface files; provider implementation files remain free of Node and workspace imports. The rule recognizes the provider's surface exports and their supporting surface files without relaxing the boundary to arbitrary files in the folder.

Provider authoring lint also verifies the registered folder's required descriptor/service exports and mandatory checked service declaration. Missing registration, missing service counterpart or an unchecked service declaration must fail locally, rather than yield a provider that passes the contribution checks but disappears at runtime. Typecheck owns capability-member diagnostics; lint owns registration, folder and import-boundary diagnostics.

Repository tooling recognizes discovered service entries generically, including knip and the test runner. It must not require contributor-added ignore lists or suppress unused code wholesale. The package documentation and field-level contract reference become the author-facing specification for this API, satisfying the coverage in spec-requirement-4 and spec-requirement-5. The existing architecture documentation is kept consistent with the implemented boundaries.

**Alternatives:** Documentation alone cannot prevent a valid-looking but unregistered provider. Generating names into the current lint allowlist still requires synchronization. Allowing every import within a provider folder admits services into the surface entry. A scaffolding generator does not replace a sufficient contract and is not required by the intended contribution.

**Trade-offs:** A focused provider authoring rule becomes maintained infrastructure. It enforces only the public folder/declaration contract; ordinary implementation organization remains the author's choice. Documentation explains the API rather than requiring contributors to inspect another package's storage or agent implementation.

**Claims:** observed: `eslint.config.mjs:410-455` already prohibits Node/workspace dependencies but enumerates provider folders for the surface boundary; `packages/providers/README.md:57-72` describes the current multi-file contribution and provider-local tests. observed: `npm test -- packages/providers` passes all 117 current provider tests; raw output is in `.pipelines/providers-api-for-external-devs/2-design-doc/lanes/astra/design-doc/providers-tests.txt`. assumed: design-doc-assumption-1 and design-doc-assumption-5, confirmed by authoring checks and documentation inspection.

## Interfaces

The authoring and consumer interfaces have different roles:

- **Authoring descriptor:** preserves a literal provider id, schema-derived config type, provider-local model ids and remote-site type. Its account and capability declarations determine what its service export must provide.
- **Authoring services:** use the same config/site/model relationship as the descriptor. Declared account methods and capabilities determine required members, not separate global type declarations.
- **Registry consumer view:** `getProvider`, capability enumeration, model utilities and identity normalization expose only registered providers. Existing known-id consumers retain precise config and site types. Generic consumers admit any registered member of their capability view.
- **Service consumer view:** `getProviderServices` exposes services for the same registered identity. No service-loading function or implementation module crosses the surface entry.
- **Stored data:** provider ids, model ids and connect-method ids are persistent identities and must not change. Existing config keys, aliases, session identities, browser settings and site-link representations remain readable and writable by older builds. New providers use generic storage; writes preserve other accounts' entries.
- **Operation boundary:** providers receive Studio-prepared config and push content; Studio receives config, account descriptions, model connections, images, remote-site results and operation status. Credentials stay out of account summaries, logs and renderer-facing connection-state data.

No IPC or HTTP API needs a separate operation for a new provider. Any necessary widening of existing provider-id payloads follows the registered type and the receiver's capability view.

## Dependencies

No new external library or service is required. The design uses TypeScript, Zod, the existing ESLint plugin, Vite/Vitest and the four existing pi API adapters. Build-time discovery is a new dependency of the providers service entry on the already-used Vite tooling. `@studio/providers` still imports no workspace package; `@studio/common` still cannot import its services.

## Failure modes and observability

- An incomplete or unregistered provider fails typecheck or lint at its own declaration or registration, naming the missing capability member or folder contract.
- Invalid account input uses the existing connection-error channel. An unusable credential uses the existing not-connected channel; renewal rejection removes the usable connection, while transient failures retain existing recovery semantics. Account descriptions never expose credentials.
- An unsupported model API fails at the stream boundary, names the API, and sends no request through another adapter.
- Remote publishing retains the existing progress, cancellation and remote-site error contracts, including WordPress.com's partial launch result. Local operation failures continue through CLI results and activity events.
- No new telemetry system is needed. Existing diagnostics, connection state and operation errors expose the failures relevant to contributors and users.

## Verification

Each entry names an outcome and its cheapest observable boundary, not a prescribed test procedure.

| Proof | Decisions and acceptance criteria | What it proves |
| --- | --- | --- |
| Repository contribution gate: typecheck, changed-file lint, knip and test suites | design-doc-decision-1, design-doc-decision-2, design-doc-decision-6; spec-acceptance-criterion-1, spec-acceptance-criterion-2 | A documented chat or publishing contribution changes only its folder and one registration, with no remaining shared union, store, lint or test-list edits. |
| Type-system and lint diagnostics at the provider-authoring boundary | design-doc-decision-1, design-doc-decision-2, design-doc-decision-6; spec-acceptance-criterion-9, spec-acceptance-criterion-10 | Registration, service counterpart and capability completeness are enforced locally, with named missing parts, rather than accepted and silently omitted. |
| New import-boundary test at the ESLint plugin boundary | design-doc-decision-6; spec-acceptance-criterion-15 | The same surface, Node and workspace restrictions apply to newly named provider folders; valid surface dependencies remain permitted. |
| Built package-entry integration in Node-host and browser builds | design-doc-decision-1; spec-acceptance-criterion-1, spec-acceptance-criterion-2, spec-acceptance-criterion-10 | Service discovery exposes the registered set in actual bundles, while the surface entry has no service dependency. |
| End-to-end account/chat flow through each of Desktop, `studio ui` and Studio on the web | design-doc-decision-3, design-doc-decision-4; spec-acceptance-criterion-3 | Real connectors expose descriptor presentation, connection, chat/model selection, streamed replies and persisted connection state. UI presentation remains usable in light and dark themes. |
| End-to-end `studio code` account/model flow | design-doc-decision-3, design-doc-decision-4; spec-acceptance-criterion-4 | The CLI's account and model commands expose registered providers and preserve connection state across process lifetimes. |
| End-to-end publish flow through Desktop, `studio ui` and CLI | design-doc-decision-3, design-doc-decision-4; spec-acceptance-criterion-5 | Hosting selection and site presentation reach the same CLI publishing operation and provider service, rather than a surface-specific implementation. |
| New behavior test at the shared settings/connector boundary | design-doc-decision-2, design-doc-decision-4; spec-acceptance-criterion-6, spec-acceptance-criterion-7 | Capability combinations share one account; supported connect methods and account summaries render correctly, with web method restrictions. |
| New account-lifecycle contract tests at common storage and browser account boundaries | design-doc-decision-3; spec-acceptance-criterion-7, spec-acceptance-criterion-8 | Device/loopback completion, schema-valid persistence, renewal and rejection retain their contracts for arbitrary registered identities. |
| New model-selection test at the package model-utility boundary | design-doc-decision-2, design-doc-decision-4; spec-acceptance-criterion-8 | The model list supplied to UI and CLI pickers respects the provider's declaration and the connected account's restrictions. |
| New host-resolution tests at Node and page agent boundaries | design-doc-decision-2, design-doc-decision-4; spec-acceptance-criterion-8, spec-acceptance-criterion-17 | Image capability, including image-only accounts, reaches the correct host service; chat choices exclude non-chat accounts; account-dependent image availability and each host's fallback policy hold. |
| New stream-adapter tests at shared and browser boundaries | design-doc-decision-5; spec-acceptance-criterion-13, spec-acceptance-criterion-14 | Each supported API selects its own transport, browser transport constraints hold, and unsupported APIs are named and rejected before any model request. |
| Persistence compatibility tests at common storage, session and browser-storage boundaries | design-doc-decision-3; spec-acceptance-criterion-16 | Old and new representations round-trip without changing connected accounts, summaries, selected providers, model pins or remote links; new writes retain old-build-readable fields and aliases. Connection deletion covers every registered sites provider. |
| New registry/model-resolution regression test, complementing `packages/providers/tests/providers.test.ts` | design-doc-decision-1, design-doc-decision-2, design-doc-decision-4; spec-acceptance-criterion-17 | Existing provider precedence and metadata for shared model ids remain stable as the registry grows. |
| Existing account tests: `packages/providers/{wpcom,anthropic,openai,github-copilot}/tests/account.test.ts` and `{gemini,spacefast}/tests/provider.test.ts` | design-doc-decision-2, design-doc-decision-3; spec-acceptance-criterion-17 | The six providers retain their existing account service behavior under the new declarations. |
| Existing service tests: `packages/providers/anthropic/tests/ai.test.ts`, `wpcom/ai/tests/{index,images}.test.ts`, `gemini/tests/images.test.ts`, `spacefast/tests/provider.test.ts` and `wpcom/sites/tests/index.test.ts` | design-doc-decision-2, design-doc-decision-5; spec-acceptance-criterion-17 | Existing model, image and publishing/pull service contracts remain valid after the authoring-contract changes. |
| Existing `apps/cli/commands/tests/push.test.ts` and affected end-to-end agent evals | design-doc-decision-4; spec-acceptance-criterion-5, spec-acceptance-criterion-17 | Agent-visible connected-site listing and publishing remain usable and use the shared CLI operation; provider-derived tool behavior does not regress. |
| Inspection of package authoring documentation against exported contracts | design-doc-decision-2, design-doc-decision-6; spec-acceptance-criterion-11, spec-acceptance-criterion-12 | Documentation is sufficient for the bounded contribution and specifies every public value's meaning, obligation and consumer, including the provider-specific exceptions. |

## Risks

- Build-time discovery must be understood by all relevant bundlers and knip; a TypeScript-only success cannot establish that a service reaches a shipped host. Until design-doc-assumption-1 is confirmed, a missing transformed entry could fail only when the account is used.
- Stronger types do not verify a provider's remote API, credential policy or browser CORS behavior. Provider-local service verification remains necessary; introducing a proxy for browser-incompatible providers is outside this change.
- Compatibility adapters are intentionally not retired. Removing one later could disconnect accounts or lose stored choices in mixed-version use; design-doc-assumption-2 requires behavioral compatibility, not merely type compatibility.
- The design makes no claim to support direct unbundled consumption or providers loaded at runtime. Broadening that support later would require revisiting the service-discovery boundary.

## Open assumptions

design-doc-assumption-1: The descriptor-derived types, mandatory local service declaration and build-time discovery can jointly satisfy the contribution contract across supported builds and tooling — assumed: authoring diagnostics, built-entry integration and the repository contribution gate will confirm this.

design-doc-assumption-2: Replacing exhaustive storage maps with generic defaults can preserve every existing persistence and account-lifecycle behavior — assumed: common, session and browser-storage compatibility proofs will confirm this.

design-doc-assumption-3: Capability-specific consumer views can cover the required surfaces without provider-specific host additions, including image-only accounts — assumed: connector flows, CLI flows and host-resolution proofs will confirm this.

design-doc-assumption-4: Narrowed connection APIs and explicit runtime rejection preserve all existing stream behavior while preventing protocol substitution — assumed: shared/browser stream proofs and existing provider coverage will confirm this.

design-doc-assumption-5: The final public API can be completely described at the package boundary without requiring Studio-internal knowledge — assumed: documentation/contract inspection and the documented contribution gate will confirm this.
