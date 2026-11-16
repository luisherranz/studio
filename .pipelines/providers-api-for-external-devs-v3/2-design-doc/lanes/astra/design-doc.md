# Design Doc: Complete provider capabilities behind a presentation-only boundary

## Overview

Make a provider a checked composition of its account and complete capabilities, rather than two independently valid objects. Keep presentation physically separate from operations: the public descriptor declares the capability contract, and a provider-local implementation binding completes exactly that contract. Registration accepts only completed providers. Identity, config, method ids, models and site types belong to that definition, not to parallel hand-maintained unions.

Studio supplies the common execution boundary: form parsing, connected-config requirements, fixed-model membership and model-connection defaults. Hosts retain storage and runtime-specific sign-in responsibilities. Model discovery becomes a general capability consumed through the same host boundaries in every surface. This is a one-time migration of the package and its consumers; subsequent providers require only package changes. No additional production provider ships.

## Architecture

- **`@studio/providers` presentation entry:** provider descriptors, schemas, capability contracts, ordered discovery and pure lookup/validation helpers. Available without credentials, operation imports or service requests.
- **Provider folders:** presentation declarations and implementations bound to those declarations. Each folder owns its account protocol, upstream requests, model-specific choices and remote-site behavior.
- **`@studio/providers/services`:** completed provider registry and common execution adapter. It checks the shared preconditions and returns normalized model connections. It owns no storage or UI.
- **`@studio/common`:** existing config, account-state and remote-connection persistence; locked credential renewal; generic host-side operations taking supplied provider services. It still does not import implementations.
- **Desktop main, `apps/local`, CLI and `apps/static`:** runtime adapters supplying configs and exposing account, model-catalog and site operations. Desktop/local site work continues through CLI commands; static archive publishing remains in the page.
- **`apps/ui`:** descriptor-rendered Settings and publishing, with connected model choices obtained through its connector/query boundary. All three connectors implement the widened catalog contract.
- **`@studio/agent`:** provider-independent execution of normalized connections, and session selection able to preserve discovered models. Shared stream dispatch remains the single authority for the four supported APIs.

## Decisions

design-doc-decision-1: Complete capabilities through typed binding, without importing operations into presentation

**Serves:** spec-requirement-1, spec-requirement-2, spec-requirement-7, spec-requirement-10, spec-requirement-11; spec-acceptance-criterion-5.

**Decision:** Retain the presentation/operations split as an import boundary, but remove independently authorable, loosely related `Provider` and `ProviderServices` contracts. A provider-local binding accepts its literal descriptor and exactly the implementations its capabilities require. The result is the complete provider. The presentation registry exposes descriptors; the services registry accepts the corresponding completed providers and checks identity correspondence.

The descriptor owns the provider id, config schema, declared method ids and capability data. The binding derives operation config, method, model and site types from it. Operations cannot declare a second provider id. A fixed-model capability requires a nonempty catalog, a default belonging to it and a model connection. A discovered-model capability requires discovery and model connection. Image generation exists only within chat. A sites capability requires listing and matching-content push; advertised Studio creation requires creation. Absent capabilities accept no implementations. WordPress.com's pull presentation requires its complete pull implementation. Account descriptions may name only declared methods.

**Alternatives:** Keeping two broadly optional interfaces plus runtime checks is the smallest edit, but leaves copy-and-edit mistakes valid until use. An eager all-in-one module makes capability composition simpler but exposes operations through the presentation import graph. A generated split from one source introduces a build/generation system where typed binding can preserve the existing boundary.

**Trade-offs:** Contributors still maintain two physical parts and register both; neither part is a separately valid operational provider. Type diagnostics and inference must remain understandable at provider declarations rather than requiring contributor casts.

**Claims:** observed: `packages/providers/types.ts:153-183,291-324` independently allow capabilities and duplicate identity; `packages/providers/services.ts:10-25` does not correlate capability completeness. observed: `packages/providers/README.md:18-21` and `docs/design-docs/providers.md:55-71` establish the import boundary. assumed: the declaration/type proofs below will establish provider-local diagnostics and complete pairing.

design-doc-decision-2: Derive discovery from registered descriptors and make consumers open to additions

**Serves:** spec-requirement-1, spec-requirement-10, spec-requirement-12; spec-acceptance-criterion-1, spec-acceptance-criterion-2, spec-acceptance-criterion-3, spec-acceptance-criterion-4, spec-acceptance-criterion-15, spec-acceptance-criterion-16.

**Decision:** The ordered presentation registry is authoritative for provider ids, capability subsets, config/site associations and fixed-model ids. Preserve the existing order, with WordPress.com first and future additions after the existing providers. Services registration is checked against it, not another independently maintained membership list. New provider ids store as themselves unless covered by an existing legacy mapping.

Generic consumers enumerate registrations rather than exhaustively naming today's providers: Settings sections, account maps, default selectors, CLI commands, remote identifiers, agent hosting tools and persistence schemas all accept registrations. Repository tests outside the package must not encode a closed roster where the tested behavior is generic.

Lint classifies presentation versus implementation by module role/import boundary, not provider folder names. Its restrictions cover future provider folders and transitive presentation dependencies, with diagnostics at the crossing import. Node and workspace imports remain prohibited throughout provider production code. Package exports and registration references remain visible to knip.

**Alternatives:** Retaining all id lists but documenting them could meet the package-only edit boundary, but preserves contradictory memberships and unnecessary contributor work. Runtime plugin discovery adds loading/security/lifecycle concerns expressly outside scope. Removing presentation import restrictions would allow package-only additions at the expense of the required boundary.

**Trade-offs:** This change touches generic consumers and repository enforcement once. It does not remove deliberate WordPress.com/Spacefast product UI or provider-specific regression coverage.

**Claims:** observed: `packages/providers/registry.ts:18-51,68-87` and `models.ts:10-17` repeat memberships. observed: `eslint.config.mjs:410-457` applies package-wide Node/workspace restrictions but enumerates provider folders for presentation imports. assumed: package-only contribution verification will demonstrate that checks, UI and command consumers no longer need additions outside the package.

design-doc-decision-3: Centralize input parsing and connected-operation preconditions

**Serves:** spec-requirement-2, spec-requirement-4, spec-requirement-6, spec-requirement-8, spec-requirement-12; spec-acceptance-criterion-7, spec-acceptance-criterion-8, spec-acceptance-criterion-11.

**Decision:** A form's schema is authoritative for the complete submitted value, including normalization and acceptance of empty strings. The shared services boundary resolves a declared method and supplies the provider its schema-parsed form output. Provider code handles upstream validation, not repeated form parsing. Every surface displays schema messages and permits schema-valid empty fields; no surface substitutes an all-fields-filled rule.

The public host-facing services adapter may receive an absent config; provider-authored chat, image and site operations cannot. Shared preconditions reject missing/unusable configurations with provider identity and connection guidance before calling them. Hosts provide the surface-appropriate route to connection. Existing provider-specific connection/error wording is retained through presentation/error contracts where it is user-visible.

Connect methods declare whether they are usable in the page. The web admits page-capable forms, never device or loopback flows; host-only forms remain available in Desktop, `studio ui` and CLI. WordPress.com redirect belongs only to the reserved Studio sign-in contract. Hosts still own callback reception and pending connection lifetime.

**Alternatives:** UI-only validation leaves other callers unvalidated and cannot guarantee parsed inputs. Repeating schema/config checks inside each provider fails the authoring goal. Letting method kind alone determine availability cannot express the observed local-server form.

**Trade-offs:** UI validation can improve feedback, but it cannot replace the authoritative execution boundary. This changes the contributor contract while preserving existing connect protocols and persisted method ids.

**Claims:** observed: `packages/providers/connection.ts:16-41` exposes field validation but not whole-form parsed execution; `apps/ui/src/features/settings/settings-view/ai-panel.tsx:61,77-79,185-188,228` gates submission by nonempty fields. observed: `apps/cli/ai/auth.ts:84-115` already adds CLI guidance. observed: the Local LLM host-only form is recorded in `.pipelines/providers-api-for-external-devs-v3/1-spec/spec/local-llm-provider.diff.txt`. assumed: shared-execution and surface integration proofs will establish that all callers receive the same validation behavior.

design-doc-decision-4: Offer fixed and discovered model catalogs through one consumer contract

**Serves:** spec-requirement-1, spec-requirement-2, spec-requirement-3, spec-requirement-4, spec-requirement-5, spec-requirement-12, spec-requirement-13; spec-acceptance-criterion-6, spec-acceptance-criterion-8, spec-acceptance-criterion-10.

**Decision:** Chat has two catalog modes. Fixed catalogs retain their presentation-only model list, compile-time default membership and optional account narrowing. Discovered catalogs expose a config-requiring listing operation, not a fake build-time list or placeholder model from another provider. Host-facing catalog resolution returns serializable model choices and an available default, or no available default when the account offers no models. Pickers and `/model` obtain a current discovered catalog when offering choices; service requests are not part of descriptor or connect-form rendering.

Discovered models use a stable provider-qualified Studio id, with the provider's own model name preserved for requests. The qualification is defined once by the package for every discovered provider. Existing fixed model ids remain unchanged. Model resolution keeps the existing first-listing metadata semantics for shared fixed ids; discovered ids do not collide with those listings.

Session readers, setters, drafts, CLI selection, model labels, image-input availability and turn creation admit discovered model ids belonging to a registered discovered provider. Reopening a conversation preserves its recorded provider/model independently of discovery availability. A temporarily unavailable server must not silently turn a saved model into a different model. Fixed catalogs retain their current selection/fallback behavior. The operation adapter enforces fixed-list membership before invoking provider code.

**Alternatives:** Refreshing models only on connect is simpler but cannot reflect a user's changing server catalog. Making all model reads asynchronous would unnecessarily make fixed catalogs service-dependent. Unqualified arbitrary model strings leave existing model-only session records and global model metadata lookup without an unambiguous provider association.

**Trade-offs:** All model consumers need a one-time widening from a closed fixed-id union. Discovered ids are a new stored contract and must remain stable. Catalog unavailability is distinct from a disconnected account; it is not a reason to discard credentials or a conversation's model.

**Claims:** observed: `packages/providers/models.ts:23-43` provides fixed-list filtering and first-listing lookup; `packages/agent/protocol/sessions/model.ts:24-72` currently discards ids absent from that lookup. observed: `apps/ui/src/features/composer/model-picker.tsx` and `composer.tsx` consume model labels and image support through it. observed: the Local LLM branch evidence in `.pipelines/providers-api-for-external-devs-v3/1-spec/spec/local-llm-provider.diff.txt` demonstrates live catalogs and qualified ids in intended use. assumed: catalog/session and connected-surface proofs will confirm identity preservation and current choices.

design-doc-decision-5: Normalize model connections and dispatch only supported APIs

**Serves:** spec-requirement-3, spec-requirement-4, spec-requirement-8, spec-requirement-9, spec-requirement-12; spec-acceptance-criterion-4, spec-acceptance-criterion-6, spec-acceptance-criterion-9, spec-acceptance-criterion-14.

**Decision:** Provider model connections describe the supported API, endpoint/model identity, credentials, optional headers, upstream alias and error rewrite. Model cost and limits are optional author inputs. The common services adapter supplies the established defaults when absent, producing a complete `AiConnection` for both agent runtimes. Explicit provider limits remain authoritative. Runtime registration names are documented separately from Studio provider identity; they are not another declaration of the provider's id.

The connection API and shared stream dispatcher admit only `openai-completions`, `openai-responses`, `anthropic-messages` and `google-generative-ai`. A connection naming another API fails explicitly before any stream request; it never falls through to another protocol. Existing shared stream cleanups and browser transport handling remain.

Image capability couples generation with its optional config-dependent availability predicate. Host resolution uses that capability, preferring the chat provider and then existing ordered connected providers. A configuration excluded by its predicate is never handed a generation request.

**Alternatives:** Keeping pi's unrestricted API type and relying on provider knowledge preserves a silent wrong-protocol path. Duplicating defaults/guards in Node and browser runtimes creates two contracts. Delegating image availability to generator failure would send requests for configurations known not to support images.

**Trade-offs:** Providers using pi catalogs may need to narrow supported catalog APIs. Migrating existing connections must distinguish deliberately stated catalog limits from the repeated Studio defaults; omitting values must not accidentally substitute pi's unrelated catalog limits.

**Claims:** observed: `packages/agent/shared/models.ts:17-49` defaults unknown APIs to OpenAI Responses; `packages/agent/browser/models.ts:17-25` shares that dispatcher. observed: `packages/providers/openai/ai.ts:25-51` and `gemini/ai.ts:8-31` repeat membership/config/default handling. observed: `apps/cli/ai/auth.ts:118-145` defines the image fallback order. assumed: normalized-connection and shared-stream proofs will confirm unchanged defaults and exact protocol routing.

design-doc-decision-6: Separate general publishing from WordPress.com sync

**Serves:** spec-requirement-1, spec-requirement-2, spec-requirement-7, spec-requirement-8, spec-requirement-12; spec-acceptance-criterion-3, spec-acceptance-criterion-4, spec-acceptance-criterion-5, spec-acceptance-criterion-12.

**Decision:** General remote-site capabilities describe their own site type, presentation, listing, content kind, push and optional Studio creation. A static publisher receives exported files; an archive publisher receives the existing browser/Node-compatible archive representation. Each push receives only its capability's options. General progress describes only general publishing; WordPress.com backup/launch phases and launch-error results do not appear in unrelated provider callbacks.

Keep WordPress.com's selective-sync options, plan-filtered listing, backup/Reprint pull, checkout creation, backup browsing and launch semantics in an explicitly WordPress.com-only extension. Its descriptor and services are checked together, but new provider ids cannot opt into it. Studio sign-in redirect and paid-credit/default-model gating use the same reserved identity rule. Document this extension for contributors copying WordPress.com; do not present it as a general hosting API.

The generic publish panel, CLI push and agent remote-site operations consume general capabilities. Existing WordPress.com sync consumers retain the richer extension. Local content preparation and site operations remain CLI-owned; the web supports archive-capable hosting only.

**Alternatives:** Generalizing the entire WordPress.com protocol and its app behavior for other providers would require supporting new pull/checkout/credit consumers not evidenced by intended use. Keeping optional WordPress.com fields on every provider preserves misleading contracts and irrelevant options. A separate parallel publishing subsystem would duplicate existing CLI ownership.

**Trade-offs:** This intentionally narrows apparent generality. A future non-WordPress.com pull provider requires a separately justified contract extension, not imitation of Reprint or checkout. Spacefast remains a general publisher rather than a special service architecture.

**Claims:** observed: `packages/providers/types.ts:121-149,240-288` mixes general publishing with WordPress.com sync, including importing its options at line 10. observed: `docs/design-docs/providers.md:127-135` assigns local work to Studio and remote work to the provider. assumed: publishing boundary and existing sync regression proofs will confirm that narrowing does not remove current behavior.

design-doc-decision-7: Preserve storage and lifecycle ownership while opening generic records

**Serves:** spec-requirement-1, spec-requirement-4, spec-requirement-12, spec-requirement-13; spec-acceptance-criterion-1, spec-acceptance-criterion-4, spec-acceptance-criterion-18, spec-acceptance-criterion-19.

**Decision:** Storage remains host-owned. Generic config records use registered descriptor schemas; new providers need no host-specific config property or storage branch. Preserve the existing adapters for WordPress.com's `authToken`, Anthropic's legacy API-key field and subscription config, and generic `providerConfigs`. Preserve remembered registrations, host ids, the `anthropic-api-key` stored selection mapping, default hosting provider, `connectedWpcomSites`, `remoteSites` and static settings formats.

Renewal remains a host operation under the storage's existing locking contract, with refreshed credentials persisted before use. Expired/rejected configs are disconnected according to existing lifecycle semantics, retaining only provider-declared noncredential remembered data. Static account storage follows the same schema/lifecycle semantics through its own persistence adapter. Providers never receive a storage API.

All seven providers migrate to the checked authoring contract. Their existing model ids, config schemas, sign-in methods, account presentation, provider order, errors and remote behavior are compatibility obligations, not opportunities to redesign them.

**Alternatives:** Moving persistence into providers would make additions self-contained but violates browser/storage separation. Migrating legacy fields to a uniform new layout breaks older desktop/CLI builds sharing the files. Per-provider branches in generic records preserve the integration burden this change is meant to remove.

**Trade-offs:** Legacy storage exceptions remain explicit and permanent. Generic schema generation must preserve values belonging to newer builds rather than rewriting the shared file as only the current registry's recognized keys.

**Claims:** observed: `packages/common/lib/provider-config.ts:69-166` and `packages/common/lib/remote-sites.ts:69-150` implement generic storage behind exhaustive dispatch maps and legacy adapters; `packages/providers/registry.ts:65-87` preserves Anthropic's stored alias. observed: `docs/design-docs/providers.md:23-24,85-87` assigns storage/locking and cross-version compatibility to hosts. assumed: bidirectional persistence and lifecycle proofs will establish migrated compatibility.

design-doc-decision-8: Make the contributor contract the supported API, with no inert fields

**Serves:** spec-requirement-8, spec-requirement-11, spec-requirement-12; spec-acceptance-criterion-13, spec-acceptance-criterion-17, spec-acceptance-criterion-18.

**Decision:** Exported contributor contracts document each field and callback's meaning, requiredness and Studio consumer behavior, including stored identities, parsed form values, connection expiry/renewal, model registration/limits, image results and publishing data/status/error contracts. The package README is sufficient to add fixed chat, publishing or discovered chat providers using only package edits. It describes boundaries, supported APIs, surface availability, error handling and verification; all seven providers follow that API.

Remove the unused connection-failure reason category rather than invent a new consumer. Retain user-facing `ConnectError` messages, disconnected-account semantics and remote error codes used by analytics. Keep translated presentation evaluated at use time. Update architectural documentation where it contradicts the resulting boundaries; no undocumented second authoring path remains.

**Alternatives:** Documentation-only improvement cannot prevent the observed mismatches or remove repeated code. Keeping unused reason fields for possible future UX asks contributors for values Studio ignores. A generator is unnecessary when the contract and documented package-local registration are sufficient.

**Trade-offs:** Public TypeScript signatures change; they are not externally published compatibility promises. User data and behavior remain compatible. Contract documentation must be maintained with the consuming behavior.

**Claims:** observed: `packages/providers/errors.ts:9-21` exposes failure reasons; the spec's `.pipelines/providers-api-for-external-devs-v3/1-spec/spec/repeated-code.txt` records no readers. observed: `packages/providers/README.md:57-59` currently requires outside-package storage edits. observed: `npm test -- packages/providers` passed 18 files and 124 tests; the sanitized output is `.pipelines/providers-api-for-external-devs-v3/2-design-doc/lanes/astra/design-doc/provider-tests.txt`. This is baseline evidence, not proof of the migration. assumed: documentation/consumer inspection and package-only contribution verification will establish completeness.

design-doc-decision-9: Broaden the existing static backend to registered accounts and archive publishers

**Serves:** spec-requirement-1, spec-requirement-4, spec-requirement-6, spec-requirement-12, spec-requirement-13; spec-acceptance-criterion-1, spec-acceptance-criterion-7, spec-acceptance-criterion-8, spec-acceptance-criterion-11, spec-acceptance-criterion-18, spec-acceptance-criterion-19.

**Decision:** Studio on the web's backend exposes provider account state for hosting-only providers as well as AI providers, and owns config access usable by both domains. The existing browser config format remains unchanged. The static connector's generic site methods admit every registered archive publisher with a page-usable account: listing, creating when offered, connecting/disconnecting remote sites, and publishing with progress/cancellation. Provider/site identity remains associated throughout browser storage and activity reporting; non-WordPress.com site ids are not converted to WordPress.com numeric ids.

Reshape the existing static hosting boundary to own general archive preparation, connection persistence and provider dispatch; retain WordPress.com's checkout, preview, quota and sync responsibilities as its reserved behavior. There is no second archive publishing pipeline alongside the current one. Existing WordPress.com browser connections keep their stored format; other providers receive provider-keyed associations. Static-export controls stay hidden because the page cannot build that content.

**Alternatives:** Leaving the static backend unchanged would make a new archive provider appear eligible while returning empty sites or throwing on publish. A second generic archive implementation beside WordPress.com's repeats preparation/activity responsibilities. Routing web publishing through the CLI requires a local server the static app does not have.

**Trade-offs:** A one-time static host migration is necessary even though no additional archive provider ships. Shared behavior is constrained by the existing page runtime and provider CORS support; it does not promise browser execution of device, loopback or static-export flows.

**Claims:** observed: `apps/ui/src/data/core/connectors/static/index.ts:346-371` returns empty non-WordPress.com lists, rejects creation and routes push through `wpcomOnly`. observed: `apps/static/src/wpcom-services.ts:383-449` already builds and uploads the page's archive. observed: `apps/static/src/agent/index.ts:227-280` stores configs by provider id but returns account state only for AI providers. observed: `apps/static/README.md:3-5,63-66` establishes page-only operation and browser persistence. assumed: static connector/persistence and connected-web proofs will establish the broader hosting contract.

## Interfaces

- **Presentation to implementation:** one provider identity and descriptor-specific config, method ids, model mode and site type; the completed service shape must match every advertised capability. Pure presentation remains importable without services.
- **Form caller to services:** provider id, declared method id and raw string form fields. Provider callback input is the schema output; schema rejection returns its message and does not call the callback. Non-form protocols retain their handoff/context contracts.
- **Host to operations:** a current config or a disconnected state. Only the shared boundary accepts the latter; provider operations receive their own config. Credential updates return to host-owned persistence.
- **Host to model consumers:** provider-associated, credential-free, serializable catalog choices with stable ids, labels and image-input support, plus an available default. Catalog loading/failure is separate from account connection. Fixed catalogs preserve account narrowing and global first-listing metadata precedence.
- **Provider to agent:** a normalized connection using one of the four supported APIs. Credentials remain outside descriptor data and model-choice transport.
- **Host to publishing:** provider-associated site data and content matching the selected capability. Only WordPress.com sync consumers can supply WordPress.com options or consume its specialized pull/checkout/launch results.
- **Persistence to sessions:** existing fixed model/provider records retain their meanings. Discovered ids extend accepted values without rewriting fixed ids or requiring a model to appear in a build-time list to preserve a conversation.

## Dependencies

No new external dependency is required. Retain Zod for config/form contracts, pi for the four stream implementations, the existing translation system and provider HTTP clients. Provider code remains browser-safe and workspace-independent. The common execution adapter belongs in the existing providers package; there is no new plugin runtime, storage service or parallel agent integration.

## Failure modes and observability

- Contradictory capability declarations fail repository checks at the contributor's declaration/binding, naming the missing or incompatible part.
- Invalid forms display schema messages; failed upstream authentication preserves the provider's user-facing connection error. No new failure taxonomy is required.
- Disconnected operations surface the provider name and a usable connection instruction. Credential refresh rejection follows existing disconnection semantics.
- Discovery failure is a catalog error, not a successful empty catalog, sign-out or model substitution. A server with no available models exposes no runnable default. Existing pinned identity remains visible.
- Unsupported stream APIs fail explicitly without a request through another protocol.
- Publishing retains current progress and remote error reporting. WordPress.com's launch-error distinction remains visible to its existing consumers; it is absent from generic publisher contracts.
- No additional credential, form-value or config logging is introduced.

## Verification

Each entry names an observable proof boundary, not a prescribed implementation or procedure.

- **Type system at provider declaration and registration** — design-doc-decision-1, design-doc-decision-6; spec-acceptance-criterion-5, spec-acceptance-criterion-12 — proves complete capabilities, own identity/config/site/method types, fixed defaults, content agreement and WordPress.com-only extensions.
- **New test at presentation import and repository lint boundaries** — design-doc-decision-2; spec-acceptance-criterion-15, spec-acceptance-criterion-16 — proves future folders inherit restrictions, crossing imports are diagnosed, and presentation/forms are available without operations or requests.
- **New test at common provider execution boundary** — design-doc-decision-3, design-doc-decision-4; spec-acceptance-criterion-7, spec-acceptance-criterion-8 — proves parsed form delivery, schema rejection before callbacks, required configs and fixed-model membership.
- **New test at host model-catalog and session-resolution boundaries** — design-doc-decision-4; spec-acceptance-criterion-6, spec-acceptance-criterion-10 — proves live discovered choices, account narrowing, provider-qualified identity and pinned-model preservation independently of catalog availability.
- **New test at normalized connection/shared stream boundary** — design-doc-decision-5; spec-acceptance-criterion-9, spec-acceptance-criterion-14 — proves defaults/overrides, correct dispatch for supported APIs and explicit rejection without wrong-protocol requests.
- **New test at host image-provider resolution boundary** — design-doc-decision-5; spec-acceptance-criterion-4, spec-acceptance-criterion-6 — proves config-dependent exclusion and ordered connected fallback without invoking an excluded generator.
- **New test at host credential lifecycle and persistence boundaries** — design-doc-decision-7; spec-acceptance-criterion-4, spec-acceptance-criterion-19 — proves renewal before use, expiration/disconnection, durable configs and bidirectional legacy-format compatibility, including static storage and session pins.
- **New test at static hosting connector boundary** — design-doc-decision-6, design-doc-decision-9; spec-acceptance-criterion-18, spec-acceptance-criterion-19 — proves general archive publishing reaches the registered provider, browser account/site identity and persistence work for hosting-only providers, and reserved WordPress.com behavior and unsupported-mode exclusions remain intact.
- **New integration proof at package contribution/repository checks boundary** — design-doc-decision-1, design-doc-decision-2, design-doc-decision-8; spec-acceptance-criterion-1, spec-acceptance-criterion-3, spec-acceptance-criterion-10, spec-acceptance-criterion-17 — proves the documented fixed-chat, publishing and discovered-chat additions need no edits outside the package and pass typecheck, changed-file lint, knip and tests.
- **New behavior tests at UI connector and CLI command boundaries** — design-doc-decision-2, design-doc-decision-3, design-doc-decision-4, design-doc-decision-9; spec-acceptance-criterion-1, spec-acceptance-criterion-2, spec-acceptance-criterion-3, spec-acceptance-criterion-6, spec-acceptance-criterion-7, spec-acceptance-criterion-8, spec-acceptance-criterion-11 — proves descriptor rendering, capability-based selectors, schema-message presentation, current model choices, actionable disconnected errors and method exclusions. UI tests use the repository's real providers/fake connector boundary.
- **End-to-end connected-provider flows across Desktop, `studio ui`, static and `studio code` where supported** — design-doc-decision-2, design-doc-decision-5, design-doc-decision-6, design-doc-decision-7, design-doc-decision-9; spec-acceptance-criterion-1, spec-acceptance-criterion-2, spec-acceptance-criterion-3, spec-acceptance-criterion-4, spec-acceptance-criterion-10, spec-acceptance-criterion-14 — proves transport/runtime integration of connection, streamed chats, image delivery, publication and persisted selection rather than repeating lower-level contract assertions.
- **Inspection of changed UI in light and dark** — design-doc-decision-3, design-doc-decision-4; spec-acceptance-criterion-1, spec-acceptance-criterion-7, spec-acceptance-criterion-10 — proves the changed form/catalog states remain legible and usable in both supported schemes.
- **Existing provider regressions in `packages/providers/**/tests`, plus host sync/selection regressions** — design-doc-decision-4 through design-doc-decision-8; spec-acceptance-criterion-18 — proves retained seven-provider protocols, errors, defaults, first-listing semantics and WordPress.com sync behavior.
- **Inspection of exported contracts, their consumers and contributor documentation** — design-doc-decision-6, design-doc-decision-8; spec-acceptance-criterion-12, spec-acceptance-criterion-13, spec-acceptance-criterion-17 — proves all values are explained and consumed, all seven implementations use the documented API, and reserved semantics are unavailable to unrelated providers.

## Risks

- Type inference can make a coherent contract unpleasant to author if errors arise in shared machinery instead of the declaration. The type-boundary proof must settle design-doc-assumption-1 before calling the API usable.
- A live server can remove a model after it has been selected. Preserving the pin does not guarantee the upstream can run it; the chat reports the service error rather than silently changing identity. No server inventory snapshot is persisted.
- End-to-end authentication, renewal and publishing rely on external services; the baseline unit suite does not establish migrated service behavior. design-doc-assumption-3 remains open until the connected-surface proofs.
- The one-time migration reaches many model and config consumers. A remaining closed roster or fixed-only validator can silently omit a future provider; package-only contribution and consumer proofs address design-doc-assumption-2.
- Older builds cannot gain capabilities or recognize newly added providers they never shipped. Bidirectional compatibility here preserves existing providers and data, not new feature support in old binaries.

## Open assumptions

design-doc-assumption-1: Descriptor-bound capability inference can deliver precise contributor-local diagnostics without unsafe contributor casts — assumed: declaration/registration type proofs and inspection of all seven migrated providers will confirm it.

design-doc-assumption-2: Registry-driven records and the widened model-catalog contract cover all intended consumers without future outside-package edits — assumed: package-only contribution verification and connected-surface flows will confirm it.

design-doc-assumption-3: Migrated provider adapters preserve live account, model, publishing and credential-renewal behavior — assumed: connected-surface flows and lifecycle/sync regressions will confirm it; the recorded baseline tests only establish current behavior.

design-doc-assumption-4: Generic persistence retains the legacy read/write contract in both directions — assumed: persistence boundary proofs against existing formats and static/session consumers will confirm it.
