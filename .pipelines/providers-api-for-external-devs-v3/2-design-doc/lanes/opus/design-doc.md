# Design Doc: A providers API that external developers add a provider through

## Overview

Today a provider is two independent objects (`Provider`, what surfaces show, and `ProviderServices`, what it does), registered in hand-kept unions and maps inside the package (`ProviderId`, `AiProviderId`, `ProviderConfigs`, `ProviderSites`, `AiModelId`, `registry.ts`, `services.ts`) and outside it (`provider-config.ts`, `remote-sites.ts`, the lint folder list, three tests). Nothing ties the two objects together, so mismatches compile; WordPress.com's own parts (the Studio sign-in, paid credits, sync options, pull) are open to every provider; and each provider repeats the same checks and values.

The design turns the package into two faces with one layer between them. A developer writes a **provider definition** (the surface half: identity, account, AI, sites) and **operations typed from that definition**, in separate modules of the provider's folder, and adds one entry to the registry and one to the services entry. The **registry** is the only list of providers: every id list and every per-provider type derives from it, and its first slot is the Studio sign-in, the only one whose contract has WordPress.com's parts. The **services entry** gives Studio's apps the same interface they call today (`getProviderServices( id )`), wrapping each provider's operations with what Studio does for every provider: parsing form values, rejecting a missing config, refusing an unlisted model, completing the model connection, translating listed model ids, and handing WordPress.com's options only to WordPress.com. The remaining per-provider knowledge outside the package (config and connection storage, the lint folder list, tests, model checks, the agent's API fallback, Settings' method filter and form, Studio on the web's accounts and publishing) becomes generic once, in this change, so that later providers change only the package.

## Architecture

New or reshaped inside `@studio/providers`:

- **Contract** (`types.ts`): the provider-facing definition and operations types per capability, documented in place (design-doc-decision-2, design-doc-decision-12); the Studio sign-in's extension of them (design-doc-decision-3); Studio's interface types (`ProviderServices`, `AiConnection`, `AccountDetails`, `ProviderSitesInfo`, …), which keep the shapes Studio's callers use. It names no provider.
- **Registry** (`registry.ts`, surface entry): the ordered list of definitions, the Studio sign-in first; the id lists, ids' types, `ProviderConfigs`, `ProviderSites`, `AiModelId`, the stored-id mapping, `getProvider`, `getProviderSites` (design-doc-decision-1).
- **Services entry** (`services.ts`): the operations registered by provider id, and the layer that turns them into Studio's interface (design-doc-decision-4).
- **Models** (`models.ts`): model lookups over fixed and listed models, and a new predicate saying whether a provider serves a model id (design-doc-decision-5).
- **Connection** (`connection.ts`): form fields with whether each is required (design-doc-decision-7), and whether a method can complete in a page (design-doc-decision-6).
- **Provider folders** (seven): migrated to the contract; ids, method ids, config schemas and model ids unchanged (design-doc-decision-13).
- **README**: the guide for adding a provider (design-doc-decision-13).

Modified outside the package, once:

- `eslint.config.mjs`: provider folders found on disk (design-doc-decision-10).
- `packages/common`: `provider-config.ts` and `lib/remote-sites.ts` store any provider without a per-provider entry (design-doc-decision-9); `ai-settings.ts` gains the model listing a listing provider's pickers read (design-doc-decision-5).
- `packages/agent`: `shared/models.ts` runs only the four APIs (design-doc-decision-8); `protocol/sessions/model.ts` uses the serves predicate (design-doc-decision-5).
- `apps/cli`: `commands/ai/index.ts`, `ai/slash-commands.ts` (`/model`), `ai/eval-harnesses/studio.ts` (design-doc-decision-5).
- `apps/studio` (`ipc-handlers.ts`, preload) and `apps/local` (`index.ts`): the serves predicate, and the model listing (design-doc-decision-5).
- `apps/ui`: the Connector type, its `ipc`, `local` and `static` connectors and the in-memory test connector (design-doc-decision-5); the model picker (design-doc-decision-5); `ai-panel.tsx` and `settings-sections.ts` (design-doc-decision-6, design-doc-decision-7).
- `apps/static`: accounts of every provider the web offers, archive publishing to any archive provider, and the model listing (design-doc-decision-11, design-doc-decision-5).
- Three tests that list every provider (design-doc-decision-14).
- `docs/design-docs/providers.md` (design-doc-decision-13).

Untouched but relevant: the WordPress.com rows and sync statuses, and Spacefast's connect dialog in Settings (spec-exclusion-6); the push command, the CLI host's connected sites, the agent's remote-site tools and `studio push`'s remote-site parsing, which already read the registry's lists and a provider's presentation; the apps' composer notice and publish panel connect view, which already tell the user how to connect a provider.

Data flow:

```
provider folder
  definition ──► registry (surface entry) ──► apps/ui, @studio/common, CLI, agent
  operations ──► services entry ─ Studio's layer ─► getProviderServices( id )
                                                    ├► @studio/common (connect, refresh, storage, sites, model listing)
                                                    ├► CLI (AI connection, images, push)
                                                    └► apps/static (connect, AI, images, archive publishing)
AI connection ─► agent (Node or page) ─► stream for one of the four APIs, or an error
```

## Decisions

design-doc-decision-1: One ordered registry of definitions is the only list of providers

**Serves:** spec-requirement-1, spec-requirement-11, spec-requirement-12, spec-acceptance-criterion-1, spec-acceptance-criterion-2, spec-acceptance-criterion-3, spec-acceptance-criterion-17, spec-acceptance-criterion-18
**Decision:** The surface entry's registry holds one ordered list of provider definitions. Everything Studio enumerates or types by provider derives from it: the lists of every provider, of AI providers and of providers with remote sites, their order (the AI fallback order and the publish panel's order), and the types `ProviderId`, `AiProviderId`, `SitesProviderId`, `ProviderConfigs`, `ProviderSites` and `AiModelId`. The contract module names no provider. The services entry registers each provider's operations under its id (design-doc-decision-2). Adding a provider is its folder, one registry entry and one services entry. The exported names Studio reads today keep their meaning, so a new provider reaches every surface that enumerates them: Settings' sections and rows, the default provider selects, `/connect`, `/provider`, `/disconnect`, the model picker, image generation's fallback, the publish providers, `studio push`'s remote-site names and the default hosting provider's stored values. The registry keeps today's order, so WordPress.com stays first and a model id several providers list keeps its first listing. The legacy stored id (`anthropic-api-key`) stays a registry mapping that lists only the providers whose stored id differs from their id.
**Alternatives:** Keep the hand-kept unions and maps and list them in the README: every recent addition edited them inside and outside the package (Meta changed `types.ts`, `models.ts`, `registry.ts`, `services.ts` and six files outside the package), so the steps stay error-prone and spec-requirement-1 stays unmet. Discover provider folders with a bundler glob: types can't follow a glob, so `ProviderId` and `AiModelId` would widen to `string` and lose design-doc-decision-2's checks, and tsc, vitest and the four bundlers would all need the same glob.
**Trade-offs:** Id types are computed from definitions, so an error in one definition can surface in consumers' types too. The registry's order carries meaning, which its documentation states.
**Claims:**
- observed: read `packages/providers/registry.ts:18-57`, `types.ts:14-43`, `models.ts:10-17`, `services.ts:10-20`; `git show --stat eb3225c1f` (`.pipelines/providers-api-for-external-devs-v3/1-spec/spec/provider-additions-stat.txt`).
- observed: the surfaces a provider must reach enumerate providers through the exported lists (the per-provider maps outside the package are design-doc-decision-9's and design-doc-decision-14's): read `apps/ui/src/data/settings-sections.ts:53-56,300-332`, `apps/ui/src/data/queries/use-remote-sites.ts:26-31`, `apps/cli/ai/slash-commands.ts:268,310,466`, `apps/cli/ai/auth.ts:42,136`, `apps/cli/ai/host.ts:63`, `packages/common/lib/ai-settings.ts:54`, `packages/common/lib/user-settings/user-preferences.ts:106`, `packages/providers/registry.ts:96-105`.
- assumed: a provider added with only its folder and the two entries reaches those surfaces — confirmed by the end-to-end flow of Verification.

design-doc-decision-2: A definition declares each capability, and the operations are typed from it

**Serves:** spec-requirement-2, spec-requirement-3, spec-requirement-10, spec-acceptance-criterion-4, spec-acceptance-criterion-5, spec-acceptance-criterion-6, spec-acceptance-criterion-15, spec-acceptance-criterion-16
**Decision:** A provider's folder has two halves in separate modules: the definition, which imports only surface files and states what the provider offers, and the operations, defined against the definition and typed from it. The contract's types make the definition the source of truth for each capability:
- **Account.** The operations always connect. Starting a sign-in on the provider's site is required exactly when a method is a loopback or device sign-in. The account description's method is one of the declared method ids, and the models it narrows to are among the provider's own model ids.
- **AI.** A definition with an AI part requires a model connection in the operations; a definition without one admits none. A fixed list has at least one model, and its default model is one of its ids. The model connection receives only the provider's own model ids. Image generation is optional, and the check of whether a config can generate images exists only alongside it. A definition whose models a server lists requires the listing operation instead (design-doc-decision-5).
- **Sites.** A definition with a sites part requires listing, creating and pushing; one without admits none. The definition states the shape of its remote site, which every site operation and the site presentation use. The push receives the kind of content the definition says it publishes, a WordPress archive or a static export, and no other. The site presentation's issue, details and refresh from the account's sites are optional, with Studio's default when absent (no issue, no details, a connection showing the account's current values for its site and keeping its stored ones when the site is gone, as Spacefast does today).
- **Identity.** Operations carry no id of their own. The services entry registers them under the id of the definition they were typed from, and the typecheck rejects operations registered under another id, a registered provider without operations, and operations for a provider the registry doesn't list.
The repository's typecheck reports each mismatch at the provider's definition, its operations or its registration entry, naming the property. Account-narrowed models and config-dependent image generation stay open to any provider, typed to its own models (spec-requirement-3).
**Alternatives:** One object per provider holding the surface and lazily imported operations, the literal "one whole": the surface entry would gain dynamic edges to every provider's operations, putting their code (pi's catalogs, `wpcom`, `tus-js-client`) into every surface bundle and breaking the lint boundary design-doc-decision-10 relies on. Keep the two independent types and compare them in a test at run time: the report names a provider in a test failure rather than pointing at its code, and operations could still name an id. Make creating a site optional, with the publish panel hiding its new-site entry: no source shows a hosting provider that can't create a site (Spacefast creates one, WordPress.com checks out), and it adds a panel state no provider exercises.
**Trade-offs:** Types inferred from a definition are harder to read than plain interfaces, and errors from them can be long; the README's examples and the in-place documentation carry the explanation. Every hosting provider other than WordPress.com must create sites.
**Claims:**
- observed: the contract accepts today the mismatches of spec-requirement-2: probe cases 3–5 compile (`.pipelines/providers-api-for-external-devs-v3/1-spec/spec/contract-probe-tsc.txt`).
- observed: surfaces read the presentation without operations: `apps/ui/src/features/sync/publish-panel/index.tsx:71,113,167`, `connected-view.tsx:121,166,185`, `packages/agent/shared/tools/pull-site.ts:30`; Spacefast's presentation defaults: read `packages/providers/spacefast/descriptor.ts:41-52`.
- observed: TypeScript 6.0.3 (`node -e "console.log(require('typescript/package.json').version)"`).
- assumed: design-doc-assumption-1.

design-doc-decision-3: WordPress.com's parts belong to the registry's Studio sign-in slot

**Serves:** spec-requirement-7, spec-requirement-12, spec-acceptance-criterion-12, spec-acceptance-criterion-18
**Decision:** The registry's first entry is the Studio sign-in, typed with a definition and operations that extend the general ones with WordPress.com's parts; every other entry takes the general contract, which has none of them. WordPress.com's parts are: the `redirect` connect method; models gated on paid AI credits, and a default model for accounts with them; selective sync and the push options (the file selection and launching after a push); the plan option when listing sites; pulling (a remote backup, the Reprint exporter and its key, the latest backup and its files) and the backups a selective pull browses; a new site made by checkout; the push phases for a remote backup and a launch, and a push that ends with a launch error. The contract documents each as the Studio sign-in's. Studio's interface keeps reading them uniformly: for any other provider the site presentation says it doesn't pull, has no selective sync and creates new sites from Studio, its models carry no paid-credit lock, its default doesn't change with credits, and the services entry hands the push and list options only to the Studio sign-in's operations. The registry's type keeps WordPress.com first. Because no other provider can declare a `redirect` method, the places that treat it as the Studio sign-in stay right for every provider unchanged: `studio code`'s `/connect` runs the WordPress.com login for it, `/disconnect` signs out of Studio, the reconnect hint skips it, and Settings and the publish panel leave it out.
**Alternatives:** Keep the parts open to every provider, documented as WordPress.com's with what Studio does for any provider that uses them: for `redirect` that is running the WordPress.com login and signing out of Studio, which spec-acceptance-criterion-12 forbids for any other provider, and for the push options it keeps handing them to Spacefast, which spec-requirement-7 forbids. Branch on WordPress.com's id at each consumer: spreads the knowledge across the push command, the apps and the agent tools, and the contract still accepts the parts.
**Trade-offs:** Two definition types. WordPress.com's folder can't serve as a model for those parts; a copy of it registered in a general slot fails the typecheck at each part it can't keep, which is the report spec-requirement-2 wants.
**Claims:**
- observed: `redirect` means the Studio sign-in for any provider: read `apps/cli/lib/providers.ts:144-145`, `apps/cli/ai/slash-commands.ts:324-327`, `apps/cli/commands/ai/index.ts:449`, `apps/ui/src/features/settings/settings-view/ai-panel.tsx:31`, `apps/ui/src/features/sync/publish-panel/index.tsx:467`.
- observed: any provider's paid-credit model is locked on WordPress.com's credits: read `apps/ui/src/features/composer/use-model-access.ts:38-42`, `apps/cli/ai/slash-commands.ts:404-417`.
- observed: every provider's push receives WordPress.com's options: read `apps/cli/commands/push.ts:300-304`, `packages/providers/spacefast/sites.ts:55`.
- observed: pulling, the plan option and `connectedIds` go only to WordPress.com: read `apps/cli/lib/pull/pull-source.ts:106`, `apps/cli/lib/sync-api.ts:72,117`, `apps/ui/src/data/core/connectors/static/index.ts:87-89,364-371`, `packages/common/sites/remote-sites.ts:34`, `apps/static/src/wpcom-services.ts:262`.
- assumed: design-doc-assumption-1.

design-doc-decision-4: The services entry does for every provider what is the same for every provider

**Serves:** spec-requirement-4, spec-requirement-7, spec-requirement-8, spec-acceptance-criterion-7, spec-acceptance-criterion-8, spec-acceptance-criterion-9
**Decision:** `getProviderServices( id )` returns Studio's interface to the provider, with the call shapes Studio's code uses today, and does the following before or after calling the provider's operations:
- **Forms.** Connecting with a form method parses the values with that method's schema. A rejection becomes a `ConnectError` with the schema's first message, and the provider isn't called. The provider receives the values as the schema parsed them, under the method's id. A method id the provider doesn't declare is refused.
- **Config.** Chat, image and site operations called without a config reject with `NotConnectedError`, whose message says the provider, by its label, isn't connected. The provider's operations always receive a config. Surfaces add how to connect, as they do today: `studio code` appends `/connect <id>`, the CLI's push offers to connect in a terminal, and the apps fall back to a connected provider and show their composer notice or the publish panel's connect view. A provider still throws `NotConnectedError` itself when its service rejects a config it was given, which Studio already forgets.
- **Models.** Asking a fixed-list provider for a model it doesn't list is refused before the provider is called.
- **Connection.** The model connection Studio receives is complete: zero cost always; the context window and output limit every existing provider states today (spec-requirement-4), unless the provider states its own; the model's image input from its listed image support, unless the provider states it; Studio's model id on the model, with the provider's name for the model sent in requests when it differs; pi's provider name taken from the model, defaulting to the provider's id.
- **Options.** The push's and list's WordPress.com options reach only the Studio sign-in's operations (design-doc-decision-3).
**Alternatives:** Put these in each consumer (`@studio/common`'s connect, the CLI's AI connection, Studio on the web's agent): three hosts would repeat them, a new host would miss them, and the form check must hold in four apps. A base class providers extend: mixes the data surfaces read with operations, which the surface/services split forbids, and leaves the checks overridable.
**Trade-offs:** The not-connected wording becomes Studio's for every provider: the seven providers' own sentences ("Connect Anthropic with an API key or a Claude subscription.") give way to one that names the provider, as `studio code`'s startup notice already says ("<provider> isn't connected. Use /connect <id> to connect it."). Providers that spread pi's catalog entry into their connection no longer restate the shared values, so a catalog's own context window and output limit never reach the runtime unless a provider states them on purpose.
**Claims:**
- observed: the checks and values each provider repeats: `.pipelines/providers-api-for-external-devs-v3/1-spec/spec/repeated-code.txt`.
- observed: every model the providers list has image input in pi's catalog, and a context window and output limit above the shared ones: `.pipelines/providers-api-for-external-devs-v3/2-design-doc/lanes/opus/design-doc/pi-catalog-models.txt`.
- observed: each provider's pi provider name equals its model's `provider`, and the runtime registers the connection under it: read `packages/providers/anthropic/ai.ts:24,31`, `wpcom/ai/index.ts:77,85`, `gemini/ai.ts:20-23`, `meta/ai.ts:21`, `openai/ai.ts:37`, `github-copilot/ai.ts:43` with the catalog providers in `pi-catalog-models.txt`; `packages/agent/node/runtime/index.ts:318`.
- observed: `studio code` already words a not-connected provider by its label: read `apps/cli/commands/ai/index.ts:530-538`; the apps fall back and offer to connect: read `packages/agent/protocol/sessions/model.ts:101-112`, `apps/ui/src/features/composer/use-composer-notice.ts:77-86`.
- assumed: design-doc-assumption-2.

design-doc-decision-5: Models a server lists are a kind of AI capability, reached through every app

**Serves:** spec-requirement-5, spec-requirement-1, spec-requirement-13, spec-acceptance-criterion-10
**Decision:** A provider's AI part is either a fixed list of models or the models its account's server lists. A listing provider supplies an operation that lists what the server offers now (each model's name on the server, and optionally a label and whether it reads images), and its account description names the model new chats start on. Studio's id for a listed model is the provider's id, a slash and the server's name, so any model id names its provider without reaching a server, and sessions record it like any model id. The package's lookups accept these ids: finding a model returns its provider and labels it with the server's name; a new predicate says whether a provider serves a model id (for a listing provider, any id with its prefix); the default model of a listing provider is its connected account's. The predicate replaces the five places that test `ai.models` today: the Desktop and `studio ui` routes that pin a session's provider, `studio code`'s model check, the eval harness and session model resolution. The services entry gives the provider's model operation the server's name and turns the listing into Studio's ids. Every app reaches the listing through one new Connector method, implemented by the `ipc`, `local` and `static` connectors and the in-memory test connector, and backed by one `@studio/common` function that the Desktop IPC handler and the `studio ui` route wrap: it reads the fresh config, forgets one the provider rejects, and lists. The chat model picker lists a listing provider's models through it each time it opens, and `studio code`'s `/model` through the common function. Nothing new is stored.
**Alternatives:** The Local LLM branch's approach, which also stores the model chosen last per provider in `shared.json`: a persisted field older builds don't read, for a behavior the spec doesn't ask (a conversation keeping its model is already in its session). A free `string` model id throughout: loses design-doc-decision-2's per-provider model checks and lets any string through Studio's validation. Listing in the definition: the surface must make no request (spec-requirement-10).
**Trade-offs:** The id prefix ties a listed model to its provider for good, which provider ids already are. Places that show a model without listing (a reopened chat's header, `studio code`'s status line) label a listed model with the server's name.
**Claims:**
- observed: what the Local LLM provider added to the contract and outside it: `.pipelines/providers-api-for-external-devs-v3/1-spec/spec/local-llm-provider.diff.txt`; `git diff 9ff418200 rp/local-llm-connector -- apps/local/src/index.ts packages/common/lib/ai-settings.ts apps/ui/src/data/core/types.ts`.
- observed: the checks a listed id must pass: read `apps/studio/src/ipc-handlers.ts:365,381`, `apps/local/src/index.ts:2213,2231`, `apps/cli/commands/ai/index.ts:78-80`, `apps/cli/ai/eval-harnesses/studio.ts:144,158`, `packages/agent/protocol/sessions/model.ts:41-49,63-73`.
- observed: the picker and `/model` read models synchronously from the definition today: read `apps/ui/src/features/composer/model-picker.tsx:89-92`, `apps/cli/ai/slash-commands.ts:395-402`.
- assumed: the end-to-end flow against a local model server (Verification).

design-doc-decision-6: A connect method can say it completes only on the user's computer

**Serves:** spec-requirement-6, spec-requirement-12, spec-acceptance-criterion-11
**Decision:** A connect method may say it completes only in a process on the user's computer. A package function says whether a method can complete in a page: it can't when it is a device or loopback sign-in, or says so. Settings' method filter, the provider lists it builds from it, and the settings search's native-only flag all use that function; the Desktop app and `studio ui` offer every method as today.
**Alternatives:** Keep deciding by kind in the UI: can't express a form only the host can check, such as a server address on the user's network. List such providers in the UI: names providers in a surface.
**Trade-offs:** Studio on the web's backend doesn't refuse such a method itself; it relies on Settings not offering it, as it does for device and loopback sign-ins today.
**Claims:**
- observed: read `apps/ui/src/features/settings/settings-view/ai-panel.tsx:28-33`, `apps/ui/src/features/settings/settings-view/providers-panel.tsx:187-193`, `apps/ui/src/data/settings-sections.ts:309-311`.

design-doc-decision-7: A form field the schema accepts empty is optional in every app

**Serves:** spec-requirement-4, spec-acceptance-criterion-7
**Decision:** `getConnectFields` reports for each field whether it is required, which it is exactly when its schema rejects an empty value. Settings enable saving once every required field has a value and send the values to the services entry, which parses them (design-doc-decision-4); `studio code` already checks each field against its schema.
**Alternatives:** Mark optional fields in the field metadata: a second statement of what the schema already says, which can contradict it.
**Trade-offs:** none beyond the field's new property.
**Claims:**
- observed: Settings require every field: read `apps/ui/src/features/settings/settings-view/ai-panel.tsx:61,187,228`; `studio code` validates with the schema: read `apps/cli/lib/providers.ts:48-52`.

design-doc-decision-8: The contract names the four model APIs, and the agent runs only those

**Serves:** spec-requirement-9, spec-acceptance-criterion-14
**Decision:** The contract exports the APIs Studio's agent runs (`openai-completions`, `openai-responses`, `anthropic-messages`, `google-generative-ai`) as a closed type, and the model connection's API is typed to it, so a connection built from a typed catalog entry on another API fails the typecheck. The agent's connection stream maps each of those APIs to its stream function, exhaustively over that type, and answers any other API with an error that names it and says Studio doesn't run it, before any request; it never sends a request over another API.
**Alternatives:** Check only in the services entry: the agent still sends an unknown API as `openai-responses` for a connection built elsewhere (tests, the eval harness). Rely on the type alone: a connection built from a catalog read as `Model< Api >`, as GitHub Copilot's lookup is, passes it.
**Trade-offs:** Adding an API to the contract later fails the agent's typecheck until it maps one, which is the coupling intended.
**Claims:**
- observed: the agent sends any other API as `openai-responses`: read `packages/agent/shared/models.ts:21-29`; catalogs name other APIs: `.pipelines/providers-api-for-external-devs-v3/1-spec/spec/pi-catalog-apis.txt`; Copilot reads its catalog untyped: read `packages/providers/github-copilot/ai.ts:36-38`.

design-doc-decision-9: Studio stores any provider's config and remote-site connections without a per-provider entry

**Serves:** spec-requirement-1, spec-requirement-13, spec-acceptance-criterion-19
**Decision:** `@studio/common`'s config store keeps WordPress.com's config in the Studio sign-in (`authToken`), and Anthropic's API key in `anthropicApiKey` with its subscription token in `providerConfigs.anthropic`, as today; every other registered provider's config goes to `providerConfigs.<id>` without being listed. The remote-site store keeps WordPress.com's connections in `connectedWpcomSites` and every other provider's in `remoteSites` under its id. Writes keep taking `shared.json`'s lock, as they do today. The seven providers' ids, method ids, model ids and config schemas don't change, and nothing new is persisted, so builds before and after the change read each other's files.
**Alternatives:** Let a provider declare where its config is stored: no provider after the first two needs a place of its own, and the providers own no storage.
**Trade-offs:** none; the two legacy mappings stay where they are.
**Claims:**
- observed: read `packages/common/lib/provider-config.ts:64-145`, `packages/common/lib/remote-sites.ts:69-133`; `providerConfigs` and `remoteSites` are open records: read `packages/common/lib/shared-config.ts:57-72`.

design-doc-decision-10: The lint boundaries cover every provider folder without a list

**Serves:** spec-requirement-10, spec-requirement-1, spec-acceptance-criterion-15
**Decision:** The lint configuration finds the provider folders in `packages/providers` on disk, as it already finds `apps/ui`'s folders, so the rule that the surface entry's files import only each other covers a new folder's definition and config with no edit. The rules against Node APIs and other workspace packages already cover every file of the package.
**Alternatives:** Keep the list and add it to the README's steps: a step outside the package, against spec-requirement-1.
**Trade-offs:** none.
**Claims:**
- observed: read `eslint.config.mjs:33-45,410-466`, and its folder discovery for `apps/ui` at `eslint.config.mjs:61-74`; `git show eb3225c1f -- eslint.config.mjs`.

design-doc-decision-11: Studio on the web offers every provider whose methods and publishing it supports

**Serves:** spec-requirement-1, spec-requirement-12
**Decision:** Studio on the web's backend reads the account of every provider the web offers, not only AI providers, and publishes to any provider whose push takes a WordPress archive: it lists the account's sites, creates one, keeps the connection with the web's other remote-site data, builds the archive in the page as it does for WordPress.com, hands it to the provider's push through its services and reports the push's progress as WordPress.com's does. The static connector's site methods route WordPress.com to its existing sync and other archive providers to this path. Static-export providers stay out, as `usePublishProviders` already filters them, and pulling stays WordPress.com's.
**Alternatives:** Read "the kinds of publishing the web offers" as WordPress.com's sync only, and hide every other hosting provider on the web: the spec contrasts the WordPress archive with the static export the web leaves out (spec-requirement-12), and WordPress.com's push already shows the archive the web builds is what a provider's push takes. Leave the web as it is: a new archive provider would reach Settings and the publish panel on the web, where its account is missing from the settings and every site method throws `UnsupportedError`, against the rule in `AGENTS.md` that no reachable control on the web may throw it.
**Trade-offs:** Studio on the web gains a remote-site path no registered provider uses until an archive provider other than WordPress.com is added (see Risks).
**Claims:**
- observed: the web reads only AI providers' accounts: read `apps/static/src/agent/index.ts:261-280`; its site methods are WordPress.com's only: read `apps/ui/src/data/core/connectors/static/index.ts:87-89,347-371`; the web builds the archive and hands it to the provider's push: read `apps/static/src/wpcom-services.ts:383-450`; publish providers on the web: read `apps/ui/src/data/queries/use-remote-sites.ts:26-31`.
- assumed: design-doc-assumption-3.

design-doc-decision-12: Every value of the contract is explained where it is declared, and Studio reads every value it asks for

**Serves:** spec-requirement-8, spec-requirement-11, spec-acceptance-criterion-13
**Decision:** Every field and operation of the provider-facing contract carries documentation in place that says what it means, whether a new provider must supply it or act on it, and what Studio does with it; this covers identity and presentation, the account's config, methods and description, renewal and expiry, each capability's operations, their inputs and results, the model connection's fields, and the errors. The contract stops asking for values Studio doesn't read: the provider-level learn-more URL (Studio reads only the sites intro's); the model connection's cost (Studio always runs at zero cost) and its separate pi provider name (the model's provider, design-doc-decision-4); and a connect failure's reason outside the Studio sign-in, whose sign-in analytics is its only reader.
**Alternatives:** Start reading the values instead, such as recording every provider's connect failure reason in analytics: no source shows anyone needing them.
**Trade-offs:** Providers that set a reason today (OpenAI, GitHub Copilot, Spacefast, and Studio's own loopback sign-in) stop setting it.
**Claims:**
- observed: Studio reads only the sites intro's learn-more URL: `git grep -n learnMoreUrl -- apps packages ':(exclude)packages/providers'` finds readers only at `apps/ui/src/features/sync/publish-panel/index.tsx:485`, `connected-view.tsx:191`, `connect-account.tsx:29`.
- observed: `ConnectError.reason` is read only for the WordPress.com sign-in's analytics: read `packages/common/lib/auth-tracks.ts:120-127`, called from `apps/studio/src/lib/deeplink/handlers/auth.ts:45`, `apps/cli/lib/wpcom-auth.ts:50`, `apps/local/src/index.ts:692`. This corrects the spec's evidence for spec-requirement-8, which found no reader.
- observed: readers of each contract value: `.pipelines/providers-api-for-external-devs-v3/2-design-doc/lanes/opus/design-doc/contract-readers.md`.

design-doc-decision-13: The README guides a developer through the whole API, and every provider follows it

**Serves:** spec-requirement-11, spec-requirement-12, spec-acceptance-criterion-17, spec-acceptance-criterion-18
**Decision:** The package README is the guide for adding a provider. It covers: every step, all inside the package (the folder with its definition, config and operations; the registry entry; the services entry); each capability's parts, and which are the provider's and which Studio does (design-doc-decision-4); each kind of connect method and the apps that offer it (design-doc-decision-6); the errors a provider throws and what Studio does with each; the values Studio stores, which never change (the provider id, method ids, model ids, the config's fields, a listed model's id); that the code runs in Node and in the page; the four model APIs; and how to test a provider (its tests beside its code, the package tests that cover every registered provider, and running it in the apps). `docs/design-docs/providers.md` points to the README for the steps and states the layout and principles of the new contract. All seven providers move to the contract and drop the checks and values Studio now does, keeping their ids, methods, configs, models, behavior and their own error messages from their services.
**Alternatives:** A generator that writes a new provider's files: no source shows one, and spec-requirement-11 makes the documentation enough.
**Trade-offs:** The README grows from a sketch into a guide that has to change with the contract.
**Claims:**
- observed: read `packages/providers/README.md:57-59`, `docs/design-docs/providers.md:55-71`.

design-doc-decision-14: Tests outside the package don't list every provider

**Serves:** spec-requirement-1
**Decision:** The three test fixtures that list every provider's account build them from the registry's ids, as the apps' in-memory connector already does, and assert on the providers each test is about.
**Alternatives:** Make the settings' accounts partial: weakens a type every surface reads, to spare three tests.
**Trade-offs:** none.
**Claims:**
- observed: `git show eb3225c1f -- apps/studio packages/agent packages/common` (Meta added itself to `settings-tracks.test.ts`, `protocol/sessions/tests/model.test.ts`, `lib/tests/ai-settings.test.ts`); read `apps/ui/src/test/in-memory-connector.ts:92-106`.

## Interfaces

**The provider contract** (what a developer writes; documented in place, design-doc-decision-12):

| Part | Who supplies it | What Studio does |
| --- | --- | --- |
| id | provider; stable, stored | registers, stores configs, sessions and connections under it |
| label, description, logo, icon | provider (label required) | shows them in Settings, pickers, `studio code` |
| config schema | provider; its fields stay readable by later builds | validates the stored config; never looks inside it |
| connect methods: id, label, instructions, kind (`form` with its schema, `loopback`, `device`), completes only on the user's computer | provider; ids stable; at least one | renders forms and prompts; offers each method in the apps that can run it |
| start a sign-in, given the address a loopback sign-in returns to, a stable id for this computer, and what it remembered | provider, when a method is loopback or device | listens for a loopback redirect; shows the address and code |
| connect | provider; receives a form's parsed values, or what `start` handed off plus the redirect's parameters, with a declared method id | parses form values first; stores the config; picks a default chat provider |
| account description: method, summary, note, links, narrowed models, a listing provider's default model | provider | shows the account; narrows the pickers; starts new chats on the default |
| expiry, renewal, cleanup, what to remember | provider, when its credential needs them | treats an expired config as disconnected; renews before use under a lock; cleans up before removing; keeps what to remember after a rejection |
| AI, fixed list: models (id, label, image support), default model | provider; ids stable | offers them in pickers and `/model`; asks only for listed ids |
| AI, listed by a server: listing operation; default model in the account description | provider | names them `<provider id>/<name>`; lists them when pickers open |
| model connection: API (one of four), base URL, key, headers, reasoning, compat, thinking levels, own limits, image input, the name the service knows the model by, error rewrite | provider, given a config, one of its models and the conversation's id | completes cost, limits, image input, ids and pi's provider name; runs the chat |
| image generation, and whether a config can generate images | provider, optional | uses the chat's provider, then the first connected one that can |
| sites: site shape, content kind, largest push, intro, issue, details, refresh from account sites, push warning | provider (shape, content kind, intro required) | renders the publish panel; builds the content the provider takes |
| sites: list, create, push | provider, all three | lists, creates and connects sites; pushes with progress; stores connections |
| errors: `ConnectError`, `NotConnectedError` for a rejected credential, `RemoteSiteError` with a cause code | provider | shows the message; forgets a rejected config; records the code in analytics |

The Studio sign-in's contract adds WordPress.com's parts (design-doc-decision-3).

**Studio's interface** (what Studio's code calls; shapes kept except as listed):

- Surface entry: the id lists and id types, `getProvider`, `getProviderSites`, `getConnectMethod`, `getConnectFields` (each field now says whether it is required), a function saying whether a method can complete in a page, `findAiModel` (accepts listed ids), `getAiModels`, `getDefaultAiModel` (takes the connected account for a listing provider), a predicate saying whether a provider serves a model id, `normalizeProviderId`, `toStoredProviderId`, `formatRemoteSite`, `parseRemoteSite`, the errors, the four model APIs' type.
- Services entry: `getProviderServices( id )` with `id`; `account.start`, `connect`, `refresh`, `disconnect`; `ai.model( config | undefined, AiModelId, { sessionId } )` resolving to a complete `AiConnection`; for a listing provider, a listing of its models as Studio's model descriptions, given `config | undefined`; `ai.generateImages`, `ai.canGenerateImages`; `sites.list( config | undefined, options )`, `create`, `push( config, site, content, options, onStatus, signal )`, and `pull` for the Studio sign-in.
- `@studio/common`: one function that lists a provider's models with its fresh config, forgetting a config the provider rejects.
- Connector (`apps/ui/src/data/core/types.ts`): one method listing a provider's models, implemented by `ipc` (a new IPC handler, exposed by the preload), `local` (a new `studio ui` route) and `static` (in the page), and by the in-memory test connector.
- Agent: the connection stream runs the four APIs and rejects any other with an error naming it.

## Dependencies

No new libraries. The contract keeps depending on zod (schemas), pi-ai's model types and catalogs, and `@wordpress/i18n`. Its inferred types need nothing beyond the repository's TypeScript 6.0.3. `@studio/providers` still imports no workspace package; `@studio/common` still imports only its surface entry; `apps/ui` still imports only the surface entry and `@studio/providers/wpcom`.

## Failure modes and observability

- **A provider contradicts its definition** (a default model it doesn't list, operations missing for a declared capability, a WordPress.com part on another provider, an undeclared method in its description, operations registered under another id, a push on the other content kind, a connection on another API typed from a catalog): the typecheck fails at the provider's code, naming the property.
- **A user submits form values the schema rejects**: the services entry raises `ConnectError` with the schema's message, which Settings show under the form and `studio code` shows at the prompt; the provider isn't called and nothing is stored.
- **An operation runs without a config**: `NotConnectedError` names the provider as not connected; `studio code` appends `/connect <id>`; the push command offers to connect in a terminal or fails with `auth_required`; the apps fall back to a connected provider and show their notice.
- **A provider's service rejects its config**: the provider throws `NotConnectedError`; Studio forgets the config (`forgetRejectedConfig`), so every surface shows it disconnected.
- **A connection names an API Studio doesn't run** (built untyped): the chat fails with an error naming the API, and no request is sent.
- **A listing provider's server doesn't answer**: the listing rejects; the picker shows no models for that provider and `/model` reports the error; a chat on a model the server no longer has fails with the server's error, worded by the provider's error rewrite when it has one.
- **A push to a non-WordPress.com archive provider fails on the web**: the provider's `RemoteSiteError` message reaches the publish panel as WordPress.com's push failures do.

## Verification

- type system: a contract type test in the package's typecheck — design-doc-decision-2, design-doc-decision-3, design-doc-decision-8, spec-acceptance-criterion-5, spec-acceptance-criterion-12 — the contract rejects each mismatch spec-requirement-2 lists, each WordPress.com part declared by another provider and a connection typed on an API Studio doesn't run, and accepts a provider of each kind the acceptance criteria name.
- new test at `getProviderServices` — design-doc-decision-4, design-doc-decision-3, spec-acceptance-criterion-7, spec-acceptance-criterion-8, spec-acceptance-criterion-9 — form values reach the provider as the schema parsed them, and a value the schema rejects fails with its message without the provider being called; operations without a config fail naming the provider; an unlisted model is refused; a connection gets Studio's cost, limits and image input unless the provider states its own limits; WordPress.com's push and list options reach only the Studio sign-in.
- new test at `getProviderServices` for the seven providers — design-doc-decision-4, design-doc-decision-13, spec-acceptance-criterion-18 — for every model each lists, the connection Studio receives keeps today's API, base URL, key, headers, ids, reasoning, compat, image input, limits, cost and pi provider name.
- new test at the package's registry, over every registered provider — design-doc-decision-1, design-doc-decision-10, spec-acceptance-criterion-16 — every provider's label, logo, description, methods, form fields, models and sites intro are read without a request; ids are unique; the Studio sign-in is first.
- new test at the package's model lookups — design-doc-decision-5 — a listed id names its provider, only that provider serves it, session model resolution keeps it, and a listing provider's default is its account's.
- existing test `packages/providers/tests/providers.test.ts` — design-doc-decision-1, spec-acceptance-criterion-18 — ids, stored ids, fixed-list model lookups and defaults stay as before.
- new test at `getConnectFields` — design-doc-decision-7 — a field whose schema accepts an empty value is not required.
- new test at the agent's connection stream — design-doc-decision-8, spec-acceptance-criterion-14 — each of the four APIs streams over its own API, and another API fails naming it with no request sent.
- new test at `@studio/common`'s config and remote-site stores — design-doc-decision-9, spec-acceptance-criterion-19 — a provider the stores don't name keeps its config in `providerConfigs` and its connections in `remoteSites`.
- existing tests `packages/common/lib/tests/ai-settings.test.ts`, `packages/common/lib/tests/provider-connect.test.ts`, `packages/common/lib/tests/remote-sites.test.ts` — design-doc-decision-9, spec-acceptance-criterion-19 — WordPress.com's, Anthropic's and the later providers' configs and connections stay where builds of every version read them.
- new test at `@studio/common`'s model listing — design-doc-decision-5 — it lists with the fresh config and forgets a config the provider rejects.
- existing tests of each provider (`packages/providers/*/tests/`, `packages/providers/wpcom/ai/tests/`, `packages/providers/wpcom/sites/tests/`), `apps/cli/ai/tests/auth.test.ts`, `apps/cli/commands/tests/push.test.ts`, `packages/agent/protocol/sessions/tests/model.test.ts`, `apps/ui/src/features/settings/settings-dialog/app-settings-dialog.test.tsx`, `settings-search.test.tsx`, `spacefast-connect.test.tsx`, `apps/ui/src/features/composer/chat-model-picker.test.tsx`, `composer.test.tsx`, `apps/ui/src/features/sync/publish-tab.test.tsx`, `apps/ui/src/features/sync/publish-panel/publish-popover.test.tsx` — design-doc-decision-13, spec-acceptance-criterion-18 — the seven providers connect, chat, pick models, generate images and publish as before.
- end-to-end flow — design-doc-decision-1, design-doc-decision-5, design-doc-decision-10, design-doc-decision-13, spec-acceptance-criterion-1, spec-acceptance-criterion-2, spec-acceptance-criterion-3, spec-acceptance-criterion-10, spec-acceptance-criterion-17 — providers of the kinds spec-acceptance-criterion-1, spec-acceptance-criterion-3 and spec-acceptance-criterion-10 describe, added following only the README, change no file outside the package, pass typecheck, lint on the changed files, knip and the tests, and work in the apps and `studio code` as those criteria describe.
- end-to-end flow — design-doc-decision-2, design-doc-decision-4, spec-acceptance-criterion-4 — a provider with chat, images and sites, a renewing credential and a loopback sign-in among several methods, connected once in the Desktop app, is listed in both groups, chats, generates an image, shows its sites and renews its credential before use.
- end-to-end flow — design-doc-decision-6, design-doc-decision-7, spec-acceptance-criterion-6, spec-acceptance-criterion-7, spec-acceptance-criterion-8, spec-acceptance-criterion-11 — narrowed models and a no-image method, an optional form field, a provider that isn't connected, and a method that completes only on the user's computer behave in each app and in `studio code` as those criteria describe.
- end-to-end flow — design-doc-decision-10, spec-acceptance-criterion-15 — a provider's code using a Node API, another workspace package, or its operations from its definition fails lint at each use with nothing outside the package changed, and one within the boundaries passes.
- end-to-end flow — design-doc-decision-11 — a provider publishing a WordPress archive and connecting with a form connects in Studio on the web's Settings, and its sites are listed, created and pushed to from the web's publish panel.
- end-to-end flow — spec-acceptance-criterion-18, spec-acceptance-criterion-19 — the seven providers behave as before in Settings, the chat, the publish panel and `studio code`, and `shared.json`, session files and the web's settings written by a build from before the change and by one from after it read the same in both.
- inspection of the README and the contract's documentation — design-doc-decision-12, design-doc-decision-13, spec-acceptance-criterion-13, spec-acceptance-criterion-17 — every item spec-requirement-11 lists and every value of the contract is explained, in agreement with the types.

## Risks

- No registered provider lists its models from a server, has a method that completes only on the user's computer, has an optional form field, or publishes an archive other than WordPress.com. Studio's code for them (the apps' listing and picker, Settings' filter and form, the web's archive publishing) is covered by package tests and end-to-end flows only, so a later change can break it unnoticed until a provider uses it.
- A listed model's id carries the name the user's server gives it, and Studio records the chat's model id in analytics as it does for every model; a server's names reach analytics as typed there.
- The composer gates images on a model's image support from `findAiModel`, which for a listed model is unknown; a chat on a text-only server model can send an image and fail with the server's error (design-doc-decision-5).
- Errors from inferred contract types can be long; a developer may need the README's examples to read them (design-doc-assumption-1).
- Checking the seven providers end to end needs an account for each; where the implementer has none, behavior rests on each provider's existing tests (design-doc-assumption-2).

## Open assumptions

design-doc-assumption-1: TypeScript's inference reports each mismatch of spec-requirement-2's list, and each WordPress.com part on another provider, at the provider's code with the property named — assumed: the contract type test compiles with every expected error used, and its messages name the property.

design-doc-assumption-2: Studio's layer gives each of the seven providers the same model connection as its own code does today (API, base URL, key, headers, model id and request id, reasoning, compat, image input, limits, cost, error rewrite) — assumed: the Verification test of the seven providers' connections at `getProviderServices`, and their chats in the apps.

design-doc-assumption-3: Studio on the web can hand the archive it builds to a non-WordPress.com provider's push, and keep that provider's connections, as it does for WordPress.com — assumed: the web end-to-end flow with a scratch archive provider.
