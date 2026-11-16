# Design Doc: A providers API that external developers add a provider through

## Overview

Today a provider is two independent objects, `Provider` (what surfaces show) and `ProviderServices` (what it does). They are registered in hand-kept unions and maps inside the package (`ProviderId`, `AiProviderId`, `ProviderConfigs`, `ProviderSites`, `AiModelId`, `registry.ts`, `services.ts`) and outside it (`provider-config.ts`, `remote-sites.ts`, the lint folder list, three tests). Nothing ties the two objects together, so mismatches compile. WordPress.com's own parts (the Studio sign-in, paid credits, sync options, pull) are open to every provider, and each provider repeats the same checks and values.

The design makes a provider one checked composition of a **definition** and **operations typed from it**, kept in separate modules of the provider's folder so that what surfaces read never imports the operations. The **registry** of definitions is the only list of providers: every id list and per-provider type derives from it, and its first slot is the Studio sign-in, the only one whose contract has WordPress.com's parts. The **services entry** keeps giving Studio's apps the interface they call today (`getProviderServices( id )`). It wraps each provider's operations with what Studio does for every provider: parsing form values, rejecting a missing config, refusing an unlisted model, completing the model connection, translating listed model ids, and handing WordPress.com's options only to WordPress.com. Models a server lists become a second kind of AI capability, reached through every app. The per-provider knowledge left outside the package (config and connection storage, the lint folder list, tests, model checks, the agent's API fallback, Settings' method filter and form, Studio on the web's accounts and publishing) becomes generic once, in this change, so that later providers change only the package.

## Architecture

New or reshaped inside `@studio/providers`:

- **Contract** (`types.ts`): the provider-facing definition and operations types per capability, documented in place (design-doc-decision-2, design-doc-decision-12); the Studio sign-in's extension of them (design-doc-decision-3); Studio's interface types (`ProviderServices`, `AiConnection`, `AccountDetails`, `ProviderSitesInfo`, …), which keep the shapes Studio's callers use. It names no provider.
- **Registry** (`registry.ts`, surface entry): the ordered list of definitions, the Studio sign-in first; the id lists, the id types, `ProviderConfigs`, `ProviderSites`, `AiModelId`, the stored-id mapping, `getProvider` and `getProviderSites` (design-doc-decision-1).
- **Services entry** (`services.ts`): the operations registered by provider id, and the layer that turns them into Studio's interface (design-doc-decision-4).
- **Models** (`models.ts`): model lookups over fixed and listed models, and a predicate saying whether a provider serves a model id (design-doc-decision-5).
- **Connection** (`connection.ts`): form fields with whether each is required (design-doc-decision-7), and whether a method can complete in a page (design-doc-decision-6).
- **Provider folders** (seven): migrated to the contract, with ids, method ids, config schemas and model ids unchanged (design-doc-decision-13).
- **README**: the guide for adding a provider (design-doc-decision-13).

Modified outside the package, once:

- `eslint.config.mjs`: the surface boundary covers every provider folder without naming it (design-doc-decision-10).
- `packages/common`: `provider-config.ts` and `lib/remote-sites.ts` store any provider without a per-provider entry (design-doc-decision-9). `ai-settings.ts` gains the model listing that a listing provider's pickers read (design-doc-decision-5).
- `packages/agent`: `shared/models.ts` runs only the four APIs (design-doc-decision-8), and `protocol/sessions/model.ts` uses the serves predicate (design-doc-decision-5).
- `apps/cli`: `commands/ai/index.ts`, `ai/slash-commands.ts` (`/model`) and `ai/eval-harnesses/studio.ts` (design-doc-decision-5).
- `apps/studio` (`ipc-handlers.ts`, preload) and `apps/local` (`index.ts`): the serves predicate and the model listing (design-doc-decision-5).
- `apps/ui`:
  - the Connector type, its `ipc`, `local` and `static` connectors, and the in-memory test connector (design-doc-decision-5);
  - the model picker and the composer's image check (design-doc-decision-5);
  - `ai-panel.tsx`, `providers-panel.tsx` and `settings-sections.ts` (design-doc-decision-6, design-doc-decision-7).
- `apps/static`: the accounts of every provider the web offers, publishing to any archive provider, and the model listing (design-doc-decision-11, design-doc-decision-5).
- The three tests that list every provider (design-doc-decision-14).
- `docs/design-docs/providers.md` (design-doc-decision-13).

Untouched but relevant:

- The WordPress.com rows and sync statuses, and Spacefast's connect dialog in Settings (spec-exclusion-6).
- These already read the registry's lists and a provider's presentation:
  - the push command;
  - the CLI host's connected sites;
  - the agent's remote-site tools;
  - `studio push`'s remote-site parsing.
- These already tell the user how to connect a provider:
  - the apps' composer notice;
  - the publish panel's connect view;
  - `studio code`'s `/connect` hint;
  - the push command's connect prompt.
- Credential renewal under its lock, and forgetting a rejected config (`readFreshProviderConfig`, `forgetRejectedConfig` in `packages/common/lib/provider-config.ts`). These keep their behavior for every provider.

Data flow:

```
provider folder
  definition ──► registry (surface entry) ──► apps/ui, @studio/common, CLI, agent
  operations ──► services entry ─ Studio's layer ─► getProviderServices( id )
                                                    ├► @studio/common (connect, refresh, storage, sites, model listing)
                                                    ├► CLI (AI connection, images, push)
                                                    └► apps/static (connect, AI, images, archive publishing, model listing)
AI connection ─► agent (Node or page) ─► stream for one of the four APIs, or an error
```

## Decisions

design-doc-decision-1: One ordered registry of definitions is the only list of providers

**Serves:** spec-requirement-1, spec-requirement-11, spec-requirement-12, spec-acceptance-criterion-1, spec-acceptance-criterion-2, spec-acceptance-criterion-3, spec-acceptance-criterion-17, spec-acceptance-criterion-18
**Decision:** The surface entry's registry holds one ordered list of provider definitions. Everything Studio enumerates or types by provider derives from it:
- the lists of every provider, of AI providers and of providers with remote sites;
- their order, which is the AI fallback order and the publish panel's order;
- the types `ProviderId`, `AiProviderId`, `SitesProviderId`, `ProviderConfigs`, `ProviderSites` and `AiModelId`.

The contract module names no provider. The services entry registers each provider's operations under its id, and checks them against the registry (design-doc-decision-2). Adding a provider is its folder, one registry entry and one services entry.

The exported names Studio reads today keep their meaning, so a new provider reaches every surface that enumerates them:
- Settings' sections and rows, and the default provider selects;
- `/connect`, `/provider` and `/disconnect`;
- the model picker and image generation's fallback;
- the publish providers, `studio push`'s remote-site names and the default hosting provider's stored values.

The registry keeps today's order, with new providers after the existing ones. So WordPress.com stays first, and a model id that several providers list keeps its first listing. A new provider's id is stored as itself. The legacy stored id (`anthropic-api-key`) stays a registry mapping that lists only the providers whose stored id differs from their id.
**Alternatives:**
- Keep the hand-kept unions and maps, and list them in the README. Every recent addition edited them inside and outside the package (Meta changed `types.ts`, `models.ts`, `registry.ts`, `services.ts` and six files outside the package), so the steps stay error-prone and spec-requirement-1 stays unmet.
- Discover provider folders with a bundler glob. Types can't follow a glob, so `ProviderId` and `AiModelId` would widen to `string` and lose design-doc-decision-2's checks. tsc, vitest and the four bundlers would also all need the same glob.
- Load providers at run time. That is spec-exclusion-2.
**Trade-offs:** The id types are computed from definitions, so an error in one definition can surface in consumers' types too. The registry's order carries meaning, which its documentation states.
**Claims:**
- observed: read `packages/providers/registry.ts:18-57`, `types.ts:14-43`, `models.ts:10-17` and `services.ts:10-20`; `git show --stat eb3225c1f` (`.pipelines/providers-api-for-external-devs-v3/1-spec/spec/provider-additions-stat.txt`).
- observed: the surfaces a provider must reach enumerate providers through the exported lists. Read:
  - `apps/ui/src/data/settings-sections.ts:53-56,300-332`;
  - `apps/ui/src/data/queries/use-remote-sites.ts:26-31`;
  - `apps/cli/ai/slash-commands.ts:268,310,466`;
  - `apps/cli/ai/auth.ts:42,136`;
  - `apps/cli/ai/host.ts:63`;
  - `packages/common/lib/ai-settings.ts:54`;
  - `packages/common/lib/user-settings/user-preferences.ts:106`;
  - `packages/providers/registry.ts:96-105`.

  The per-provider maps outside the package are design-doc-decision-9's and design-doc-decision-14's.
- assumed: design-doc-assumption-4.

design-doc-decision-2: A definition declares each capability whole, and the operations are typed from it

**Serves:** spec-requirement-2, spec-requirement-3, spec-requirement-10, spec-requirement-4, spec-acceptance-criterion-4, spec-acceptance-criterion-5, spec-acceptance-criterion-6, spec-acceptance-criterion-15, spec-acceptance-criterion-16
**Decision:** A provider's folder has two halves in separate modules:
- the definition, which imports only surface files and states what the provider offers;
- the operations, defined against the definition and typed from it.

The contract's types make the definition the source of truth for each capability:
- **Account.** The operations always connect. They must start a sign-in on the provider's site exactly when one of the declared methods is a loopback or device sign-in. The account description's method is one of the declared method ids, and the models it narrows to are among the provider's own model ids.
- **AI.** A definition with an AI part requires a model connection in the operations, and a definition without one admits none.
  - A fixed list has at least one model, and its default model is one of its ids. The model connection receives only the provider's own model ids.
  - A definition whose models a server lists requires the listing operation instead (design-doc-decision-5).
  - Image generation is optional. The check of whether a config can generate images exists only alongside it.
- **Sites.** A definition with a sites part requires listing, creating and pushing, and one without admits none.
  - The definition states the shape of its remote site, which every site operation and the site presentation use.
  - The push receives the kind of content the definition says it publishes, a WordPress archive or a static export, and no other. It receives no options and reports only the general phases (design-doc-decision-3).
  - The site presentation's issue, details and refresh from the account's sites are optional. When one is absent, Studio's default applies: no issue, no details and no links, and a connection that shows the account's current values for its site and keeps its stored ones when the site is gone, as Spacefast does today.
- **Identity.** Operations carry no id of their own. The services entry registers them under the id of the definition they were typed from. The typecheck rejects operations registered under another id, a registered provider without operations, and operations for a provider the registry doesn't list.

The repository's typecheck reports each mismatch at the provider's definition, its operations or its registration entry, naming the property, with no casts in the provider's code. Account-narrowed models and config-dependent image generation stay open to any provider, typed to its own models (spec-requirement-3).
**Alternatives:**
- One object per provider holding the surface and lazily imported operations, the literal "one whole". The surface entry would gain dynamic edges to every provider's operations. Their code (pi's catalogs, `wpcom`, `tus-js-client`) would go into every surface bundle and break the lint boundary that design-doc-decision-10 relies on.
- Generate the two halves from one source. This adds a build step that typed binding makes unnecessary.
- Keep the two independent types and compare them in a test at run time. The report would name a provider in a test failure rather than point at its code, and operations could still name an id.
- Make creating a site optional, required only when the provider says Studio creates its sites, with the publish panel hiding its new-site entry otherwise. No source shows a hosting provider that can't create a site (Spacefast creates one, and WordPress.com checks out), and it adds a panel state that no provider exercises.
- Keep the site presentation's issue, details and refresh required. Spacefast writes `issue: () => null` and the generic refresh, which is what any new publisher without its own would copy.
**Trade-offs:** Types inferred from a definition are harder to read than plain interfaces, and their errors can be long. The README's examples and the in-place documentation carry the explanation. Every hosting provider other than WordPress.com must create sites.
**Claims:**
- observed: the contract accepts today the mismatches of spec-requirement-2: probe cases 3–5 compile (`.pipelines/providers-api-for-external-devs-v3/1-spec/spec/contract-probe-tsc.txt`). A device method without `start` fails only when used: read `apps/local/src/index.ts:833`.
- observed: surfaces read the presentation without operations: read `apps/ui/src/features/sync/publish-panel/index.tsx:71,113,167`, `connected-view.tsx:121,166,185` and `packages/agent/shared/tools/pull-site.ts:30`.
- observed: Spacefast's presentation is today's default. Read `packages/providers/spacefast/descriptor.ts:41-52`: no issue, team details only, and a refresh that merges the account's current values.
- observed: today's `newSite` is either a checkout (WordPress.com) or created from Studio. Read `packages/providers/types.ts:132-134`.
- observed: TypeScript 6.0.3 (`node -e "console.log(require('typescript/package.json').version)"`).
- assumed: design-doc-assumption-1.

design-doc-decision-3: WordPress.com's parts belong to the registry's Studio sign-in slot only

**Serves:** spec-requirement-7, spec-requirement-12, spec-acceptance-criterion-12, spec-acceptance-criterion-18
**Decision:** The registry's first entry is the Studio sign-in. Its definition and operations extend the general ones with WordPress.com's parts, and every other entry takes the general contract, which has none of them. WordPress.com's parts are:
- the `redirect` connect method;
- models gated on paid AI credits, and a default model for accounts with them;
- selective sync and the push options: the file selection, and launching after a push;
- the plan option when listing sites;
- pulling: a remote backup, the Reprint exporter and its key, and the latest backup and its files;
- the backups that a selective pull browses;
- a new site made by checkout;
- the push phases for a remote backup and a launch, and a push that ends with a launch error.

The contract documents each one as the Studio sign-in's. The services entry hands the push and list options only to the Studio sign-in's operations.

Studio's interface keeps reading these parts uniformly. For any other provider:
- the site presentation says it doesn't pull, has no selective sync and creates new sites from Studio;
- its models carry no paid-credit lock, and its default doesn't change with credits.

The registry's type keeps WordPress.com first. No other provider can declare a `redirect` method, so the places that treat one as the Studio sign-in stay right for every provider unchanged:
- `studio code`'s `/connect` runs the WordPress.com login for it;
- `/disconnect` signs out of Studio;
- the reconnect hint skips it;
- Settings and the publish panel leave it out.
**Alternatives:**
- Keep the parts open to every provider, documented as WordPress.com's, with what Studio does for any provider that uses them. For `redirect`, that is running the WordPress.com login and signing out of Studio, which spec-acceptance-criterion-12 forbids for any other provider. For the push options, it keeps handing them to Spacefast, which spec-requirement-7 forbids. Generalizing pull, checkout and credits for other providers needs consumers no source shows.
- Branch on WordPress.com's id at each consumer. This spreads the knowledge across the push command, the apps and the agent tools, and the contract still accepts the parts.
**Trade-offs:** There are two definition types. WordPress.com's folder can't serve as a model for those parts. A copy of it registered in a general slot fails the typecheck at each part it can't keep, which is the report spec-requirement-2 wants. A future hosting provider that pulls needs its own contract extension.
**Claims:**
- observed: `redirect` means the Studio sign-in for any provider. Read `apps/cli/lib/providers.ts:144-145`, `apps/cli/ai/slash-commands.ts:324-327`, `apps/cli/commands/ai/index.ts:449`, `apps/ui/src/features/settings/settings-view/ai-panel.tsx:28-33` and `apps/ui/src/features/sync/publish-panel/index.tsx:467`.
- observed: any provider's paid-credit model is locked on WordPress.com's credits. Read `apps/ui/src/features/composer/use-model-access.ts:38-42` and `apps/cli/ai/slash-commands.ts:404-417`.
- observed: every provider's push receives WordPress.com's options. Read `apps/cli/commands/push.ts:300-304` and `packages/providers/spacefast/sites.ts:55`.
- observed: pulling, the plan option and `connectedIds` go only to WordPress.com. Read:
  - `apps/cli/lib/pull/pull-source.ts:106`;
  - `apps/cli/lib/sync-api.ts:72,117`;
  - `apps/ui/src/data/core/connectors/static/index.ts:87-89,364-371`;
  - `packages/common/sites/remote-sites.ts:34`;
  - `apps/static/src/wpcom-services.ts:262`.

  Also `.pipelines/providers-api-for-external-devs-v3/2-design-doc/design-doc/contract-readers.md` ("Values read only for WordPress.com").
- assumed: design-doc-assumption-1.

design-doc-decision-4: The services entry does for every provider what is the same for every provider

**Serves:** spec-requirement-4, spec-requirement-7, spec-requirement-8, spec-requirement-12, spec-acceptance-criterion-7, spec-acceptance-criterion-8, spec-acceptance-criterion-9, spec-acceptance-criterion-18
**Decision:** `getProviderServices( id )` returns Studio's interface to the provider, with the call shapes Studio's code uses today. Before or after calling the provider's operations, it does the following:
- **Forms.** Connecting with a form method parses the values with that method's schema. A rejection becomes a `ConnectError` with the schema's first message, and the provider isn't called. The provider receives the values as the schema parsed them, under the method's id. A method id the provider doesn't declare is refused.
- **Config.** Chat, image and site operations called without a config reject with `NotConnectedError`, so the provider's operations always receive a config.
  - The error's message is the sentence the provider's account may give on how to connect it. Without one, the message says the provider, by its label, isn't connected.
  - The seven providers give the sentence their operations say today, so their messages are unchanged.
  - Surfaces add how to connect, as they do today: `studio code` appends `/connect <id>`, the push command checks first and offers to connect in a terminal, and the apps fall back to a connected provider and show their composer notice or the publish panel's connect view.
  - A provider still throws `NotConnectedError` itself when its service rejects a config it was given, which Studio already forgets.
- **Models.** Asking a fixed-list provider for a model it doesn't list is refused before the provider is called.
- **Connection.** The model connection Studio receives is complete:
  - the cost is always zero;
  - the context window and output limit are the values spec-requirement-4 names, unless the provider states its own;
  - the model's image input comes from its listed image support, unless the provider states it;
  - Studio's model id is on the model, and the provider's name for the model is sent in requests when it differs;
  - pi's provider name is taken from the model, defaulting to the provider's id.
- **Options.** The push's and the list's WordPress.com options reach only the Studio sign-in's operations (design-doc-decision-3).
**Alternatives:**
- Studio's own wording for every provider's not-connected message, dropping the providers' sentences. The seven providers' chat errors would change ("Connect Anthropic with an API key or a Claude subscription." would become one that only names the provider), which spec-requirement-12 keeps.
- Keep pi's provider name as a value of its own, documented apart from the provider's id. Every provider sets it equal to its model's `provider`, so it is a second statement of one value.
- Let the provider state a cost. Nothing in Studio reads a model's cost, and it always runs at zero.
- Put these steps in each consumer (`@studio/common`'s connect, the CLI's AI connection, Studio on the web's agent). Three hosts would repeat them, a new host would miss them, and the form check must hold in four apps.
- A base class that providers extend. It mixes the data surfaces read with the operations, which the surface/services split forbids, and leaves the checks overridable.
**Trade-offs:** A provider has one more optional value, its connect sentence. A provider that offers both AI and sites says one sentence for both. Providers that spread pi's catalog entry into their connection no longer restate the shared values, so a catalog's own context window and output limit never reach the runtime unless a provider states them on purpose.
**Claims:**
- observed: the checks and values each provider repeats: `.pipelines/providers-api-for-external-devs-v3/1-spec/spec/repeated-code.txt`.
- observed: the providers' not-connected sentences, and where they reach the user. `studio code` shows a chat's with `/connect <id>` appended. Image generation skips a provider without a config. Push checks the config itself first. The apps list sites only for a connected provider. See `.pipelines/providers-api-for-external-devs-v3/2-design-doc/design-doc/not-connected-messages.txt`, and read `apps/ui/src/data/queries/use-remote-sites.ts:80,107` and `apps/cli/ai/host.ts:67`.
- observed: every model the providers list has image input in pi's catalog, and a context window and output limit above the shared ones: `.pipelines/providers-api-for-external-devs-v3/2-design-doc/design-doc/pi-catalog-models.txt`. WordPress.com derives image input from `supportsImages`: read `packages/providers/wpcom/ai/index.ts:87`.
- observed: each provider's pi provider name equals its model's `provider`, and the runtime registers the connection under it. Read `packages/providers/anthropic/ai.ts:24`, `wpcom/ai/index.ts:77,85`, `gemini/ai.ts:20`, `meta/ai.ts:21`, `openai/ai.ts:37` and `github-copilot/ai.ts:43`, with the catalog providers in `pi-catalog-models.txt`, and `packages/agent/node/runtime/index.ts:318`.
- observed: nothing outside the package reads a model's cost: `git grep -nE "usage\.cost|\.cost\b|cost\.total" -- apps packages ':(exclude)packages/providers'` finds nothing outside tests.
- observed: the apps fall back to a connected provider and offer to connect. Read `packages/agent/protocol/sessions/model.ts:101-112` and `apps/ui/src/features/composer/use-composer-notice.ts:77-86`.
- assumed: design-doc-assumption-2.

design-doc-decision-5: Models a server lists are a kind of AI capability, reached through every app

**Serves:** spec-requirement-5, spec-requirement-1, spec-requirement-13, spec-acceptance-criterion-10
**Decision:** A provider's AI part is either a fixed list of models or the models its account's server lists.
- **Listing.** A listing provider supplies an operation that lists what the server offers now: each model's name on the server, and optionally a label and whether it reads images. Its account description names the model that new chats start on.
- **Ids.** Studio's id for a listed model is the provider's id, a slash and the server's name. So any model id names its provider without reaching a server, and sessions record it like any model id.
- **Lookups.** The package's lookups accept these ids. Finding a model returns its provider and labels it with the server's name. A predicate says whether a provider serves a model id: for a listing provider, any id with its prefix. The default model of a listing provider is its connected account's.
- **Consumers of the predicate.** It replaces the five places that test `ai.models` today: the Desktop and `studio ui` routes that pin a session's provider, `studio code`'s model check, the eval harness and session model resolution. A conversation keeps its listed model when it is reopened, whether or not the server lists it then.
- **Services entry.** It gives the provider's model operation the server's name, and turns the listing into Studio's model descriptions.
- **Reaching the listing.** Every app reaches the listing through one new Connector method, implemented by the `ipc`, `local` and `static` connectors and the in-memory test connector. One `@studio/common` function backs it, and the Desktop IPC handler and the `studio ui` route wrap that function. It reads the fresh config and lists. It forgets a config only when the provider rejects it, and keeps the config when the server can't be reached.
- **Pickers.** The chat model picker lists a listing provider's models through the Connector method each time it opens, and `studio code`'s `/model` through the common function.
- **Images.** The composer takes a listed model's image support from the listing.
- **Storage.** Nothing new is stored.
**Alternatives:**
- The Local LLM branch's approach, which also stores the model chosen last for each provider in `shared.json`. That is a persisted field older builds don't read, for a behavior the spec doesn't ask for: a conversation keeping its model is already in its session.
- Take the default from the server's listing instead of the account description. New chats would need a request to the server before they start, and the Local LLM provider's account already names one.
- A free `string` model id throughout. It loses design-doc-decision-2's per-provider model checks and lets any string through Studio's validation.
- Listing in the definition. The surface must make no request (spec-requirement-10).
- Leave image support out of the listing. The composer would let a chat on a text-only server model send an image, which the server then rejects. The Local LLM provider read the server's answer for that check.
**Trade-offs:** The id prefix ties a listed model to its provider for good, as provider ids already are. Places that show a model without listing it, such as a reopened chat's header and `studio code`'s status line, label a listed model with the server's name.
**Claims:**
- observed: what the Local LLM provider added to the contract and outside it: `.pipelines/providers-api-for-external-devs-v3/1-spec/spec/local-llm-provider.diff.txt` (the account's `model`, `ListedAiModel` with `supportsImages`, and `listModels`); `git diff 9ff418200 rp/local-llm-connector -- apps/local/src/index.ts packages/common/lib/ai-settings.ts apps/ui/src/data/core/types.ts`.
- observed: the Local LLM provider's composer refused images for a listed model the server says doesn't read them: `.pipelines/providers-api-for-external-devs-v3/2-design-doc/design-doc/local-llm-listed-images.txt`. Today's composer reads image support from the definition: read `apps/ui/src/features/composer/composer.tsx:389`.
- observed: the checks a listed id must pass. Read `apps/studio/src/ipc-handlers.ts:365,381`, `apps/local/src/index.ts:2213,2231`, `apps/cli/commands/ai/index.ts:78-80`, `apps/cli/ai/eval-harnesses/studio.ts:144,158` and `packages/agent/protocol/sessions/model.ts:41-49,63-73`.
- observed: the picker and `/model` read models synchronously from the definition today. Read `apps/ui/src/features/composer/model-picker.tsx:89-92` and `apps/cli/ai/slash-commands.ts:395-402`.
- observed: forgetting a rejected config and keeping it otherwise is today's rule for every operation. Read `packages/common/lib/provider-config.ts:218-240`.
- assumed: design-doc-assumption-4.

design-doc-decision-6: A connect method can say it completes only on the user's computer

**Serves:** spec-requirement-6, spec-requirement-12, spec-acceptance-criterion-11
**Decision:** A connect method may say that it completes only in a process on the user's computer. A package function says whether a method can complete in a page. It can't when the method is a device or loopback sign-in, or says so. Three places in Settings use that function:
- the method filter;
- the provider lists the filter feeds;
- the settings search's native-only flag.

The Desktop app, `studio ui` and `studio code` offer every method, as today.
**Alternatives:**
- Keep deciding by kind in the UI. That can't express a form that only the host can check, such as a server address on the user's network.
- List such providers in the UI. That names providers in a surface.
**Trade-offs:** Studio on the web's backend doesn't refuse such a method itself. It relies on Settings not offering it, as it does for device and loopback sign-ins today.
**Claims:**
- observed: read `apps/ui/src/features/settings/settings-view/ai-panel.tsx:28-33`, `apps/ui/src/features/settings/settings-view/providers-panel.tsx:187-193` and `apps/ui/src/data/settings-sections.ts:309-311`.
- observed: the Local LLM provider needed this for its server address form: `.pipelines/providers-api-for-external-devs-v3/1-spec/spec/local-llm-provider.diff.txt` (`hostOnly`).

design-doc-decision-7: A form field the schema accepts empty is optional in every app

**Serves:** spec-requirement-4, spec-acceptance-criterion-7
**Decision:** `getConnectFields` reports for each field whether it is required. A field is required exactly when its schema rejects an empty value. Settings enable saving once every required field has a value, and send the values to the services entry, which parses them and returns the schema's message on a rejection (design-doc-decision-4). `studio code` already checks each field against its schema.
**Alternatives:** Mark optional fields in the field metadata. That is a second statement of what the schema already says, and it can contradict it.
**Trade-offs:** none beyond the field's new property.
**Claims:**
- observed: Settings require every field. Read `apps/ui/src/features/settings/settings-view/ai-panel.tsx:61,187,228`.
- observed: `studio code` validates with the schema. Read `apps/cli/lib/providers.ts:48-52`.

design-doc-decision-8: The contract names the four model APIs, and the agent runs only those

**Serves:** spec-requirement-9, spec-acceptance-criterion-14
**Decision:** The contract exports the APIs Studio's agent runs (`openai-completions`, `openai-responses`, `anthropic-messages`, `google-generative-ai`) as a closed type. The model connection's API is typed to it, so a connection built from a typed catalog entry on another API fails the typecheck. The agent's connection stream, shared by the Node and page runtimes, maps each of those APIs to its stream function, exhaustively over that type. It answers any other API with an error that names the API and says Studio doesn't run it, before any request. It never sends a request over another API.
**Alternatives:**
- Check only in the services entry. The agent would still send an unknown API as `openai-responses` for a connection built elsewhere, such as in tests or the eval harness.
- Rely on the type alone. A connection built from a catalog read as `Model< Api >`, as GitHub Copilot's lookup is, passes it.
**Trade-offs:** Adding an API to the contract later fails the agent's typecheck until the agent maps it, which is the intended coupling.
**Claims:**
- observed: the agent sends any other API as `openai-responses`. Read `packages/agent/shared/models.ts:17-29`.
- observed: catalogs name other APIs: `.pipelines/providers-api-for-external-devs-v3/1-spec/spec/pi-catalog-apis.txt`.
- observed: Copilot reads its catalog untyped. Read `packages/providers/github-copilot/ai.ts:36-38`.

design-doc-decision-9: Studio stores any provider's config and remote-site connections without a per-provider entry

**Serves:** spec-requirement-1, spec-requirement-13, spec-acceptance-criterion-19
**Decision:** `@studio/common`'s config store keeps the configs where they are today:
- WordPress.com's config in the Studio sign-in (`authToken`);
- Anthropic's API key in `anthropicApiKey`, with its subscription token in `providerConfigs.anthropic`;
- every other registered provider's config in `providerConfigs.<id>`, without that provider being listed.

The remote-site store keeps WordPress.com's connections in `connectedWpcomSites` and every other provider's in `remoteSites`, under its id. `providerConfigs` and `remoteSites` stay open records in `shared.json`, so a build keeps the entries of providers it doesn't know. Writes keep taking `shared.json`'s lock, as they do today. The seven providers' ids, method ids, model ids and config schemas don't change, and nothing new is persisted, so builds from before and after the change read each other's files. Providers never receive a storage API.
**Alternatives:**
- Let a provider declare where its config is stored. No provider after the first two needs a place of its own, and providers own no storage.
- Move the legacy fields to one uniform layout. Older Desktop and CLI builds that share the file would stop reading them.
**Trade-offs:** The two legacy mappings stay, permanently.
**Claims:**
- observed: read `packages/common/lib/provider-config.ts:64-145` and `packages/common/lib/remote-sites.ts:69-133`.
- observed: `providerConfigs` and `remoteSites` are open records in a loose schema. Read `packages/common/lib/shared-config.ts:41-93`.
- assumed: design-doc-assumption-5.

design-doc-decision-10: The lint boundaries cover every provider folder without a list

**Serves:** spec-requirement-10, spec-requirement-1, spec-acceptance-criterion-15
**Decision:** The lint configuration covers every provider folder's surface files without naming the folders, as it already covers `apps/ui`'s folders. So the rule that the surface entry's files import only each other covers a new folder's definition and config with no edit, and reports a crossing at the import. The rules against Node APIs and other workspace packages already cover every file of the package.
**Alternatives:** Keep the list and add it to the README's steps. That is a step outside the package, against spec-requirement-1.
**Trade-offs:** none.
**Claims:**
- observed: read `eslint.config.mjs:33-45,410-466`, and its folder discovery for `apps/ui` at `eslint.config.mjs:61-74`; `git show eb3225c1f -- eslint.config.mjs`.

design-doc-decision-11: Studio on the web offers every provider whose methods and publishing it supports

**Serves:** spec-requirement-1, spec-requirement-12, spec-requirement-13, spec-acceptance-criterion-1, spec-acceptance-criterion-18, spec-acceptance-criterion-19
**Decision:** Studio on the web's backend reads the account of every provider the web offers, not only AI providers, from the configs it keeps today. It publishes to any provider whose push takes a WordPress archive, through the hosting path it has today:
- it lists the account's sites and creates one;
- it keeps the connection with the web's other remote-site data, under the provider's id and with the site's id as the provider gave it;
- it builds the archive in the page, as it does for WordPress.com, and hands it to the provider's push through its services;
- it reports the push's progress and cancellation as it does WordPress.com's.

The static connector's site methods route WordPress.com to its existing sync, and other archive providers to this path. WordPress.com's stored web connections keep their format. Static-export providers stay out, as `usePublishProviders` already filters them, and pulling, checkout, previews and quota stay WordPress.com's.
**Alternatives:**
- Read "the kinds of publishing the web offers" as WordPress.com's sync only, and hide every other hosting provider on the web. The spec contrasts the WordPress archive with the static export that the web leaves out (spec-requirement-12). WordPress.com's push already shows that the archive the web builds is what a provider's push takes.
- Leave the web as it is. A new archive provider would reach Settings and the publish panel on the web, where its account is missing from the settings and every site method throws `UnsupportedError`. `AGENTS.md` says no reachable control on the web may throw it.
- A second archive pipeline beside WordPress.com's. It would repeat the archive building and activity reporting.
**Trade-offs:** Studio on the web gains a remote-site path that no registered provider uses until an archive provider other than WordPress.com is added (see Risks).
**Claims:**
- observed: the web reads only AI providers' accounts. Read `apps/static/src/agent/index.ts:261-280`.
- observed: its site methods are WordPress.com's only, and convert site ids to numbers. Read `apps/ui/src/data/core/connectors/static/index.ts:87-92,346-371`.
- observed: the web builds the archive and hands it to the provider's push. Read `apps/static/src/wpcom-services.ts:383-450`.
- observed: publish providers on the web. Read `apps/ui/src/data/queries/use-remote-sites.ts:26-31`.
- assumed: design-doc-assumption-3.

design-doc-decision-12: Every value of the contract is explained where it is declared, and Studio reads every value it asks for

**Serves:** spec-requirement-8, spec-requirement-11, spec-acceptance-criterion-13
**Decision:** Every field and operation of the provider-facing contract carries documentation in place. It says what the value means, whether a new provider must supply it or act on it, and what Studio does with it. This covers:
- identity and presentation;
- the account's config, methods, description and connect sentence;
- renewal and expiry;
- each capability's operations, with their inputs and results;
- the model connection's fields;
- the errors.

The contract stops asking for values Studio doesn't read:
- the provider-level learn-more URL (Studio reads only the sites intro's);
- the model connection's cost and its separate pi provider name (design-doc-decision-4);
- a connect failure's reason outside the Studio sign-in, whose sign-in analytics is its only reader.

User-facing `ConnectError` messages and the remote error codes that analytics records stay.
**Alternatives:**
- Remove the connect failure's reason from every provider, the Studio sign-in included. WordPress.com's sign-in analytics reads it.
- Start reading the values instead, such as recording every provider's connect failure reason in analytics. No source shows anyone needing them.
**Trade-offs:** Providers that set a reason today (OpenAI, GitHub Copilot and Spacefast) stop setting it. Studio's own loopback sign-in reports a declined sign-in by its message alone.
**Claims:**
- observed: Studio reads only the sites intro's learn-more URL. `git grep -n learnMoreUrl -- apps packages ':(exclude)packages/providers'` finds readers only at `apps/ui/src/features/sync/publish-panel/index.tsx:485`, `connected-view.tsx:191` and `connect-account.tsx:29`.
- observed: `ConnectError.reason` is read only for the WordPress.com sign-in's analytics. Read `packages/common/lib/auth-tracks.ts:120-127`, called from `apps/studio/src/lib/deeplink/handlers/auth.ts:45`, `apps/cli/lib/wpcom-auth.ts:50` and `apps/local/src/index.ts:692`, each after connecting WordPress.com, whose `account.ts:17,49` sets the reason.
- observed: the readers of each contract value: `.pipelines/providers-api-for-external-devs-v3/2-design-doc/design-doc/contract-readers.md`.

design-doc-decision-13: The README guides a developer through the whole API, and every provider follows it

**Serves:** spec-requirement-11, spec-requirement-12, spec-acceptance-criterion-17, spec-acceptance-criterion-18
**Decision:** The package README is the guide for adding a provider. It covers:
- every step, all inside the package: the folder with its definition, config and operations, the registry entry, and the services entry;
- each capability's parts, and which are the provider's and which Studio does (design-doc-decision-4);
- each kind of connect method and the apps that offer it (design-doc-decision-6);
- the errors a provider throws, and what Studio does with each;
- the values Studio stores, which never change: the provider id, method ids, model ids, the config's fields and a listed model's id;
- that the code runs in Node and in the page;
- the four model APIs;
- how to test a provider: its tests beside its code, the package tests that cover every registered provider, and running it in the apps.

`docs/design-docs/providers.md` points to the README for the steps, and states the layout and principles of the new contract. All seven providers move to the contract and drop the checks and values that Studio now handles. They keep their ids, methods, configs, models, connect sentences and behavior, and their own error messages from their services.
**Alternatives:** A generator that writes a new provider's files. No source shows one, and spec-requirement-11 makes the documentation enough.
**Trade-offs:** The README grows from a sketch into a guide that has to change with the contract. Public TypeScript signatures change; they are no compatibility promise (intent-context-1).
**Claims:**
- observed: read `packages/providers/README.md:57-59` and `docs/design-docs/providers.md:55-71`.

design-doc-decision-14: Tests outside the package don't list every provider

**Serves:** spec-requirement-1
**Decision:** The three test fixtures that list every provider's account build them from the registry's ids, as the apps' in-memory connector already does, and assert on the providers each test is about.
**Alternatives:** Make the settings' accounts partial. That weakens a type every surface reads, to spare three tests.
**Trade-offs:** none.
**Claims:**
- observed: `git show eb3225c1f -- apps/studio packages/agent packages/common` (Meta added itself to `settings-tracks.test.ts`, `protocol/sessions/tests/model.test.ts` and `lib/tests/ai-settings.test.ts`); read `apps/ui/src/test/in-memory-connector.ts:92-106`.

## Interfaces

**The provider contract** (what a developer writes; documented in place, design-doc-decision-12):

| Part | Who supplies it | What Studio does |
| --- | --- | --- |
| id | provider; stable, stored | registers it; stores configs, sessions and connections under it |
| label, description, logo, icon | provider (label required) | shows them in Settings, pickers and `studio code` |
| config schema | provider; its fields stay readable by later builds | validates the stored config; never looks inside it |
| connect methods: id, label, instructions, kind (`form` with its schema, `loopback`, `device`), completes only on the user's computer | provider; ids stable; at least one | renders forms and prompts; offers each method in the apps that can run it |
| connect sentence: how to connect the provider | provider, optional | shows it when an operation needs the provider and it isn't connected; otherwise says the provider isn't connected |
| start a sign-in, given the address a loopback sign-in returns to, a stable id for this computer, and what it remembered | provider, exactly when a method is loopback or device | listens for a loopback redirect; shows the address and code |
| connect | provider; receives a form's parsed values, or what `start` handed off plus the redirect's parameters, with a declared method id | parses form values first; stores the config; picks a default chat provider |
| account description: method, summary, note, links, narrowed models, a listing provider's default model | provider | shows the account; narrows the pickers; starts new chats on the default |
| expiry, renewal, cleanup, what to remember | provider, when its credential needs them | treats an expired config as disconnected; renews before use under a lock; cleans up before removing; keeps what to remember after a rejection |
| AI, fixed list: models (id, label, image support), default model | provider; ids stable | offers them in pickers and `/model`; asks only for listed ids |
| AI, listed by a server: listing operation (server name, label, image support); default model in the account description | provider | names them `<provider id>/<name>`; lists them when pickers open; gates images on the listing |
| model connection: API (one of four), base URL, key, headers, reasoning, compat, thinking levels, own limits, image input, the name the service knows the model by, error rewrite | provider, given a config, one of its models and the conversation's id | completes cost, limits, image input, ids and pi's provider name; runs the chat |
| image generation, and whether a config can generate images | provider, optional | uses the chat's provider, then the first connected one that can |
| sites: site shape, content kind, largest push, intro, push warning; issue, details and refresh from the account's sites, each optional | provider (shape, content kind, intro required) | renders the publish panel; builds the content the provider takes |
| sites: list, create, push | provider, all three | lists, creates and connects sites; pushes with progress; stores connections |
| errors: `ConnectError`, `NotConnectedError` for a rejected credential, `RemoteSiteError` with a cause code | provider | shows the message; forgets a rejected config; records the code in analytics |

The Studio sign-in's contract adds WordPress.com's parts (design-doc-decision-3).

**Studio's interface** (what Studio's code calls; shapes kept except as listed):

- **Surface entry:**
  - the id lists and id types;
  - `getProvider`, `getProviderSites` and `getConnectMethod`;
  - `getConnectFields`, where each field now says whether it is required;
  - a function saying whether a method can complete in a page;
  - `findAiModel` (accepts listed ids), `getAiModels`, and `getDefaultAiModel` (takes the connected account for a listing provider);
  - a predicate saying whether a provider serves a model id;
  - `normalizeProviderId`, `toStoredProviderId`, `formatRemoteSite` and `parseRemoteSite`;
  - the errors, and the type of the four model APIs.
- **Services entry:** `getProviderServices( id )`, with `id`:
  - `account.start`, `connect`, `refresh` and `disconnect`;
  - `ai.model( config | undefined, AiModelId, { sessionId } )`, resolving to a complete `AiConnection`;
  - for a listing provider, a listing of its models as Studio's model descriptions (id, label, image support), given `config | undefined`;
  - `ai.generateImages` and `ai.canGenerateImages`;
  - `sites.list( config | undefined, options )`, `create` and `push( config, site, content, options, onStatus, signal )`, plus `pull` for the Studio sign-in.
- **`@studio/common`:** one function that lists a provider's models with its fresh config, forgetting a config only when the provider rejects it.
- **Connector** (`apps/ui/src/data/core/types.ts`): one method listing a provider's models. `ipc` implements it with a new IPC handler that the preload exposes, `local` with a new `studio ui` route, and `static` in the page. The in-memory test connector implements it too.
- **Agent:** the connection stream runs the four APIs, and rejects any other with an error naming it.

## Dependencies

No new libraries. The contract keeps depending on zod (schemas), pi-ai's model types and catalogs, and `@wordpress/i18n`. Its inferred types need nothing beyond the repository's TypeScript 6.0.3. `@studio/providers` still imports no workspace package, `@studio/common` still imports only its surface entry, and `apps/ui` still imports only the surface entry and `@studio/providers/wpcom`. Storage, locking and renewal stay in `@studio/common` and the hosts.

## Failure modes and observability

- **A provider contradicts its definition.** Examples: a default model it doesn't list; operations missing for a declared capability; a WordPress.com part on another provider; an undeclared method in its description; operations registered under another id; a push on the other content kind; a connection on another API typed from a catalog. The typecheck fails at the provider's code, naming the property.
- **A user submits form values the schema rejects.** The services entry raises `ConnectError` with the schema's message, which Settings show under the form and `studio code` shows at the prompt. The provider isn't called, and nothing is stored.
- **An operation runs without a config.** `NotConnectedError` carries the provider's connect sentence, or says the provider by its label isn't connected. `studio code` appends `/connect <id>`. The push command offers to connect in a terminal, or fails with `auth_required`. The apps fall back to a connected provider and show their notice.
- **A provider's service rejects its config.** The provider throws `NotConnectedError`, and Studio forgets the config, so every surface shows the provider as disconnected.
- **A connection names an API Studio doesn't run** (built untyped). The chat fails with an error naming the API, and no request is sent.
- **A listing provider's server doesn't answer.** The listing rejects with the provider's error, and the config is kept. The picker shows no models for that provider, and `/model` reports the error. A reopened conversation keeps its model. A chat on a model the server no longer has fails with the server's error, worded by the provider's error rewrite when it has one.
- **A push to an archive provider other than WordPress.com fails on the web.** The provider's `RemoteSiteError` message reaches the publish panel, as WordPress.com's push failures do.
- No credential, form value or config is newly logged.

## Verification

- type system: a contract type test in the package's typecheck — design-doc-decision-2, design-doc-decision-3, design-doc-decision-8, spec-acceptance-criterion-5, spec-acceptance-criterion-12. The contract rejects:
  - each mismatch spec-requirement-2 lists;
  - a hosting provider without creating;
  - a loopback or device method without starting a sign-in;
  - each WordPress.com part declared outside the Studio sign-in;
  - a connection typed on an API Studio doesn't run.

  It accepts a provider of each kind the acceptance criteria name, with no casts.
- new test at `getProviderServices` — design-doc-decision-3, design-doc-decision-4, spec-acceptance-criterion-7, spec-acceptance-criterion-8, spec-acceptance-criterion-9. It proves that:
  - form values reach the provider as the schema parsed them, under a declared method;
  - a value the schema rejects fails with its message, without the provider being called;
  - operations without a config fail with the provider's sentence, or its label when it gives none;
  - an unlisted model is refused;
  - a connection gets Studio's cost, limits, image input and pi provider name, unless the provider states its own limits or image input;
  - WordPress.com's push and list options reach only the Studio sign-in.
- new test at `getProviderServices` for the seven providers — design-doc-decision-4, design-doc-decision-13, spec-acceptance-criterion-18. For every model each provider lists, the connection Studio receives keeps today's API, base URL, key, headers, ids, reasoning, compat, image input, limits, cost and pi provider name. Each provider's not-connected message stays today's.
- new test at the package's registry, over every registered provider — design-doc-decision-1, spec-acceptance-criterion-16. Every provider's label, logo, description, methods, form fields, models and sites intro are read without a request. Ids are unique, and the Studio sign-in is first.
- existing test `packages/providers/tests/providers.test.ts` — design-doc-decision-1, spec-acceptance-criterion-18 — ids, stored ids, fixed-list model lookups and defaults stay as before.
- new test at the package's model lookups and `packages/agent/protocol/sessions/model.ts` — design-doc-decision-5. A listed id names its provider, and only that provider serves it. Session model resolution keeps it whether or not the server lists it. A listing provider's default is its account's.
- new test at `@studio/common`'s model listing — design-doc-decision-5. It lists with the fresh config, forgets a config the provider rejects, and keeps one when the server can't be reached.
- new test at `getConnectFields` — design-doc-decision-7 — a field whose schema accepts an empty value is not required.
- new tests at `apps/ui`'s Settings provider row and composer, over the in-memory connector — design-doc-decision-5, design-doc-decision-6, design-doc-decision-7, spec-acceptance-criterion-7, spec-acceptance-criterion-10, spec-acceptance-criterion-11. They prove that:
  - an optional field leaves saving enabled, and the schema's message shows;
  - a method that completes only on the user's computer is offered only where the connector can run it;
  - the picker offers a listing provider's models from the connector;
  - the composer refuses images for a listed model that the listing says doesn't read them.
- new test at `studio code`'s `/model` (`apps/cli/ai/tests/slash-commands.test.ts`) — design-doc-decision-5, spec-acceptance-criterion-10 — it offers the models a listing provider's server lists.
- new test at the agent's connection stream — design-doc-decision-8, spec-acceptance-criterion-14 — each of the four APIs streams over its own API, and another API fails naming it, with no request sent.
- new test at `@studio/common`'s config and remote-site stores — design-doc-decision-9, spec-acceptance-criterion-19. A provider the stores don't name keeps its config in `providerConfigs` and its connections in `remoteSites`. A write keeps the entries of providers the build doesn't know.
- existing tests `packages/common/lib/tests/ai-settings.test.ts`, `provider-connect.test.ts` and `remote-sites.test.ts` — design-doc-decision-9, spec-acceptance-criterion-19 — WordPress.com's, Anthropic's and the later providers' configs and connections stay where builds of every version read them.
- new test at Studio on the web's backend and static connector — design-doc-decision-11, spec-acceptance-criterion-18, spec-acceptance-criterion-19. It proves that:
  - a hosting-only provider's account is read;
  - an archive provider's sites are listed, created, connected and pushed to with progress and cancellation, keeping the provider's site ids;
  - WordPress.com's web sync and its stored connections are unchanged;
  - static-export providers stay out.
- existing test `apps/cli/ai/tests/auth.test.ts` — design-doc-decision-2, design-doc-decision-4, spec-acceptance-criterion-6. Image generation skips a config that can't generate images and takes the next connected provider. Chats on a provider that isn't connected say how to connect it.
- existing tests that the seven providers still connect, chat, pick models, generate images and publish as before — design-doc-decision-13, spec-acceptance-criterion-18:
  - each provider's tests: `packages/providers/*/tests/`, `packages/providers/wpcom/ai/tests/` and `packages/providers/wpcom/sites/tests/`;
  - `apps/cli/commands/tests/push.test.ts`;
  - `packages/agent/protocol/sessions/tests/model.test.ts`;
  - in `apps/ui/src/features/`: `settings/settings-dialog/app-settings-dialog.test.tsx`, `settings-search.test.tsx`, `spacefast-connect.test.tsx`, `composer/chat-model-picker.test.tsx`, `composer.test.tsx`, `sync/publish-tab.test.tsx` and `sync/publish-panel/publish-popover.test.tsx`.
- end-to-end flow — design-doc-decision-1, design-doc-decision-5, design-doc-decision-10, design-doc-decision-13, design-doc-decision-14, spec-acceptance-criterion-1, spec-acceptance-criterion-2, spec-acceptance-criterion-3, spec-acceptance-criterion-10, spec-acceptance-criterion-17. The providers that spec-acceptance-criterion-1, spec-acceptance-criterion-3 and spec-acceptance-criterion-10 describe are added following only the README. They change no file outside the package, and they pass typecheck, lint on the changed files, knip and the tests. They work in the apps and `studio code` as those criteria describe.
- end-to-end flow — design-doc-decision-2, design-doc-decision-4, spec-acceptance-criterion-4 — the provider that spec-acceptance-criterion-4 describes, connected once in the Desktop app, behaves as that criterion describes.
- end-to-end flow — design-doc-decision-6, design-doc-decision-7, spec-acceptance-criterion-6, spec-acceptance-criterion-7, spec-acceptance-criterion-8, spec-acceptance-criterion-11 — the providers those criteria describe behave as described in each app and in `studio code`.
- end-to-end flow — design-doc-decision-10, spec-acceptance-criterion-15 — with nothing outside the package changed, lint fails at each use of a Node API, another workspace package, or the operations from the definition in a provider's code. A provider within the boundaries passes.
- end-to-end flow — design-doc-decision-9, design-doc-decision-11, spec-acceptance-criterion-18, spec-acceptance-criterion-19. The seven providers behave as before in Settings, the chat, the publish panel and `studio code`. `shared.json`, session files and the web's settings written by a build from before the change, and by one from after it, read the same in both.
- inspection of the README and the contract's documentation — design-doc-decision-12, design-doc-decision-13, spec-acceptance-criterion-13, spec-acceptance-criterion-17. Every item spec-requirement-11 lists, and every value of the contract, is explained in agreement with the types. Every value the contract asks of a provider has a reader in Studio.
- inspection of the changed Settings form, provider lists and model picker in light and dark — design-doc-decision-5, design-doc-decision-6, design-doc-decision-7 — they stay legible and usable in both color schemes.

## Risks

- No registered provider does any of the following:
  - lists its models from a server;
  - has a method that completes only on the user's computer;
  - has an optional form field;
  - publishes an archive other than WordPress.com.

  Studio's code for these (the apps' listing and picker, the composer's listed-image check, Settings' filter and form, and the web's archive publishing) is covered by tests and end-to-end flows only. A later change can break it unnoticed until a provider uses it (design-doc-assumption-3, design-doc-assumption-4).
- A listed model's id carries the name the user's server gives it. Studio records the chat's model id in analytics, as it does for every model, so a server's names reach analytics as the server gives them.
- A server can stop serving a model after a conversation picked it. The conversation keeps the model, and its next chat fails with the server's error rather than switching models.
- A provider that offers both AI and sites says one connect sentence for both. A sentence written for one capability reads oddly for the other.
- An older build doesn't know a provider that a newer build added. It keeps that provider's stored config and connections, but doesn't offer the provider (design-doc-assumption-5).
- Errors from inferred contract types can be long, and a developer may need the README's examples to read them (design-doc-assumption-1).
- Checking the seven providers end to end needs an account for each. Where the implementer has none, behavior rests on each provider's existing tests and the connection test of Verification (design-doc-assumption-2).

## Open assumptions

design-doc-assumption-1: TypeScript's inference reports each mismatch of spec-requirement-2's list, and each WordPress.com part on another provider, at the provider's code with the property named, and without casts in provider code — assumed: the contract type test compiles with every expected error used, its messages name the property, and the seven migrated providers need no casts.

design-doc-assumption-2: Studio's layer gives each of the seven providers the same model connection and not-connected message as its own code does today. The connection covers API, base URL, key, headers, model id and request id, reasoning, compat, image input, limits, cost, pi provider name and error rewrite — assumed: the Verification test of the seven providers at `getProviderServices`, and their chats in the apps.

design-doc-assumption-3: Studio on the web can hand the archive it builds to the push of a provider other than WordPress.com, and keep that provider's connections, as it does for WordPress.com — assumed: the Verification test at Studio on the web's backend and static connector.

design-doc-assumption-4: The registry-driven lists, the serves predicate and the model listing reach every consumer, so a provider added with only package changes appears and works in every surface its capabilities reach — assumed: the end-to-end flow that adds the providers of spec-acceptance-criterion-1, spec-acceptance-criterion-3 and spec-acceptance-criterion-10.

design-doc-assumption-5: Generic storage keeps the read and write contract with builds from before the change, in both directions — assumed: the stores' tests and the end-to-end flow with `shared.json`, session files and the web's settings written by builds from before and after the change.
