# Design Doc: Providers live behind Studio's hosts, one value each

## Overview

Today a provider is written twice. Its descriptor is the half that `apps/ui` imports and bundles. Its services are the half that hosts run. A lint zone that names every provider folder keeps the two halves apart, and hand-written maps and closed unions join them back together. `@studio/common`, the agent protocol and tests outside the package then list the providers again. The split exists because the renderer imports providers. The lists exist because every consumer types itself over the set of providers. A provider registered by the README's steps typechecks and appears nowhere. A descriptor that lists models with no model connection fails only when a chat starts.

After the change, a provider is one value in one module of its folder, and each part of it carries the code that serves it:
- a connect method carries its `connect`;
- a sign-in on the provider's site also carries its `start`;
- the AI part carries its model connection;
- the sites part carries its `list` and `push`.

Only Studio's hosts hold providers: the Desktop main process, the `studio ui` server, the CLI, and Studio on the web's backend in the page. The package finds the provider modules at build time and puts them in Studio's order. Each host builds a provider catalog: plain data, in the app's locale, holding only what that host offers. It serves the catalog to `apps/ui` through the connector, and presents every remote site it hands over. `apps/ui`, `@studio/common` and the agent protocol hold no provider: they read the catalog, or receive the providers from their caller. Typecheck reports a missing part in the developer's own literal. The package's tests and knip report a provider module the build can't find. Studio stores any provider by default, and the agent runs exactly the four model APIs the contract names.

Previous candidates each keep a descriptor that `apps/ui` imports, beside services that hosts run:
- lane v1: a hand-written ordered registration of descriptors, with services found by Vite's glob import;
- lane diverge-1: both halves found by Vite's glob import, the folder's name as the id, and provider ids as strings;
- lane diverge-2: a generated, committed index of both halves, which keeps the literal id unions.

This design removes the descriptor. Providers never reach `apps/ui`, which renders what its host serves. A provider is therefore one value, and its completeness follows from its shape instead of being checked across two halves.

## Architecture

New or reshaped inside `@studio/providers`:

- **A provider's folder** (`packages/providers/<folder>/`) holds:
  - its provider module, which exports the provider value under the name the contract fixes;
  - its config schema;
  - its own modules and its `tests/`.

  No file in it imports another workspace package or a Node API, and a provider never reads or writes storage.
- **The contract** (`types.ts`, with the provider helper) holds:
  - one provider type in which each part carries its code;
  - the catalog's types;
  - the union of model APIs Studio runs;
  - the reference documentation of every value.
- **The root entry** (`@studio/providers`) holds the contract, the catalog's types, the errors, and the helpers that need no provider:
  - the stored-id mapping, with Anthropic's legacy id;
  - remote-site names, over the sites providers the caller passes;
  - the default provider's id.

  It reaches no provider folder.
- **The WordPress.com entry** (`@studio/providers/wpcom`) is unchanged: the Studio sign-in URL and WordPress.com sync's site schemas, from WordPress.com files that never reach its provider value.
- **The hosts' entry** (`@studio/providers/services`) holds:
  - the registry: every provider module found at build time, in Studio's order, with `getProvider`, the id lists by capability, and model lookup;
  - the catalog builder;
  - the remote-site presenter;
  - `createTusUpload`.
- **The package's tests** cover the discovered folders, unique ids, the order of the existing six, and the catalog for each host's abilities.

Changed once outside the package, so that a later provider needs no change there:

- `apps/ui` renders every provider surface from the catalog and from the remote sites its connector presents:
  - Settings (`features/settings/`);
  - the composer's model pickers and model access (`features/composer/`);
  - the command palette (`data/settings-sections.ts`);
  - the publish tab and panel (`features/sync/`);
  - the provider logos (`features/account/provider-logo/`).
- The `Connector` (`apps/ui/src/data/core/types.ts`) gains the catalog and the push warning. Its remote-site results carry their presentation, and `capabilities.loopbackSignIn` goes. The ipc, local and static connectors implement these, and the in-memory connector, which the behavior tests and the playground render over, serves the catalog the package builds.
- The hosts serve the catalog and presented remote sites as thin wrappers over the hosts' entry:
  - the Desktop main process (`apps/studio/src/**/ipc-handlers.ts` and the preload);
  - the `studio ui` server (`apps/local/src/index.ts`);
  - Studio on the web's backend (`apps/static`).
- `@studio/common`'s provider config, account, connect, remote-site and default-hosting-provider functions take the providers from their caller, and store any provider by default.
- `@studio/agent`:
  - the protocol's session-model helpers take the catalog;
  - `shared/models.ts` runs the four model APIs;
  - the shared tools read providers through the hosts' entry.
- `eslint.config.mjs`:
  - the root entry's zone names only the package's shared files;
  - the in-memory connector is exempt from the services restriction, as the static connector is.
- The tests outside the package that enumerate every provider's account.
- `packages/providers/README.md` and `docs/design-docs/providers.md`.

Untouched but relevant, apart from where they import providers from:

- the CLI's `studio code` commands (`apps/cli/ai/slash-commands.ts`, `apps/cli/lib/providers.ts`), `studio push` (`apps/cli/commands/push.ts`), and the resolution of the AI connection and the image generator (`apps/cli/ai/auth.ts`, `apps/cli/ai/host.ts`), which are host code that reads the registry;
- `AiSettings`, the account state hosts already compute and serve, whose shape doesn't change;
- the `shared.json` schema (`packages/common/lib/shared-config.ts`).

Data flow:

- At build time, the hosts' entry collects every provider module. The `apps/ui` builds contain no provider, except through the static connector, which runs Studio on the web's backend in the page, and through the in-memory connector of its tests and playground.
- `apps/ui` asks its connector for the catalog in the app's locale. The host builds it from the registry and from what the host offers.
- Settings, the pickers and the palette render the catalog together with `AiSettings`.
- To connect, `apps/ui` sends the provider's id, the method's id and the user's values. The host hands them to `@studio/common` with that provider, which runs the method's `connect` and stores the config.
- The publish panel lists presented remote sites, and asks the host for a push warning before a push. The push runs through `studio push` in the Desktop app and `studio ui`, and through WordPress.com's own sync on the web.
- For a chat, the host resolves the provider's model connection, and the agent's stream runs it over its API or rejects it.
- The CLI reads the registry directly.

## Decisions

design-doc-decision-1: Studio's apps show providers from a catalog their host serves

**Serves:** spec-requirement-1, spec-requirement-2, spec-requirement-3, spec-requirement-7, spec-requirement-9, spec-acceptance-criterion-3, spec-acceptance-criterion-5, spec-acceptance-criterion-6, spec-acceptance-criterion-10, spec-acceptance-criterion-15, spec-acceptance-criterion-17
**Decision:**
- Each host that runs `apps/ui` builds a provider catalog from the package and serves it through the connector:
  - the Desktop main process;
  - the `studio ui` server;
  - Studio on the web's backend.
- The catalog is plain data. It lists every provider in Studio's order (design-doc-decision-3). Each entry holds:
  - its id, label, description, learn-more URL, icon and logo;
  - the connect methods this host offers (design-doc-decision-4), each with its id, label, kind and instructions, and, for a form, its fields: name, title, description, placeholder, and whether the field is secret;
  - when the provider offers AI: its models, each with its id, label, image support and paid-credit lock, and its default and paid default models;
  - when this host publishes to it: how its remote sites behave and are introduced. That is its largest push, whether Studio pulls, whether a sync can be selective, what a push sends, how a new site is made, and its intro.
- `apps/ui` renders every provider surface from the catalog: Settings' rows and default selects, the model pickers and model access, the palette's provider entries, the publish tab and panel, and the logos. A model's label, image support and paid-credit lock come from the first provider in the catalog that lists the model's id.
- No module that `apps/ui`, `@studio/common` or the agent protocol imports reaches a provider value. Provider values are reachable only through the hosts' entry, which the hosts, the agent's Node and browser code, the static connector and the in-memory connector import. The lint restriction that keeps `apps/ui`, `@studio/common` and the agent protocol off every subpath but `/wpcom` stays as it is (design-doc-decision-9).
- What surfaces read of a provider is its catalog entry, which is data and can't carry code. The boundary between what surfaces read and a provider's services therefore holds for every provider, whatever the provider's module imports.
- The CLI is a host, and reads providers from the registry.

**Alternatives:**
- A descriptor that `apps/ui` imports, written apart from the provider's services (lanes v1, diverge-1 and diverge-2). Not taken. Every provider then has two halves, which the developer writes and keeps in step, and which helpers with conditional types and a test that restates the parts check against each other. A lint zone and two entries keep the halves apart, and each half needs its own discovery. All of that exists only because the renderer imports providers.
- `apps/ui` importing whole providers. Rejected: surfaces would bundle the services and their SDKs, against spec-requirement-7's third boundary.
- One provider value whose services load lazily, through `import()`. Rejected:
  - what surfaces read would still reference the services, against spec-requirement-7;
  - `apps/ui` would bundle the services as chunks;
  - `getProviderServices` would become asynchronous, including for its module-level callers.
- One provider value that a build transform strips of its services for `apps/ui`. Rejected: every app's build would depend on a custom transform, and a provider whose data reads a services value would fail only when built.
- A catalog generated at build time and bundled into `apps/ui` as data. Not taken: provider text is translated at run time, in the app's locale, and the presentation of a remote site is code that reads the site.
- Reading spec-requirement-7's third boundary as requiring every provider to keep a data half apart from its services. Not taken: the requirement is that what surfaces read uses no services code, and here surfaces read only the catalog's data.

**Trade-offs:**
- A one-time change across `apps/ui`, its connectors, the Desktop IPC handlers, the `studio ui` server, Studio on the web's backend and the agent protocol. That covers 78 provider reads in `apps/ui` alone.
- `apps/ui` waits for the catalog before rendering a provider surface (design-doc-assumption-4).
- The catalog crosses IPC and HTTP, and `apps/ui` looks a model up in data instead of through an import.

**Claims:**
- observed: `apps/ui` imports provider values at run time in its settings, composer, sync and palette code, on 78 lines (`.pipelines/providers-api-for-external-devs-v2/2-design-doc/lanes/radical/design-doc/observations.txt` §1). The agent protocol, which `apps/ui` imports, reads provider values at run time (same file, §2).
- observed: lint keeps `apps/ui`, `@studio/common` and the agent protocol off every `@studio/providers` subpath but `/wpcom`, and lets the static connector import them (same file, §3 and §15).
- observed: hosts already compute what Settings show of an account, provider text included, and serve it as `AiSettings` (same file, §4).
- observed: Settings never run a connect field's validator, and only the CLI's prompts do. A form's fields therefore reach `apps/ui` as data (same file, §5).
- observed: the palette builds its provider entries from descriptors in `apps/ui` (same file, §9).
- assumed: the catalog arrives before a provider surface renders, without a visible change at start; see design-doc-assumption-4.

design-doc-decision-2: A provider is one value, and each part of it carries its own code

**Serves:** spec-requirement-3, spec-requirement-5, spec-requirement-1, spec-requirement-2, spec-acceptance-criterion-7, spec-acceptance-criterion-8, spec-acceptance-criterion-9, spec-acceptance-criterion-12
**Decision:** The contract is one provider type, which a provider declares through one helper. The helper infers the provider's id, config type, site type and model ids.

Each part that a surface shows, or that a capability needs, carries the code that serves it:
- **Connect methods.** Each one carries its own `connect`:
  - a form method carries its input schema, and a `connect` that takes the form's values;
  - a device or loopback sign-in carries a `start`, which takes the connect context and returns where the user goes, and a `connect`, which takes what `start` handed off, together with a loopback redirect's parameters.
- **The account.** It carries its config schema and `describe`. `expiresAt`, `remember`, `refresh` and `disconnect` stay optional.
- **AI**, when offered, carries:
  - its models, its default model and its paid default model, which accept only the provider's own model ids;
  - the model connection;
  - optionally, image generation, and whether a config can generate images.
- **Sites**, when offered, carry:
  - the presentation of a remote site;
  - `list` and `push`;
  - how a new site is made: either Studio creates it, which carries `create`, or WordPress.com's checkout;
  - optionally, the pull steps, whose presence means Studio pulls from the provider.

`AccountDetails.models` accepts only the provider's own model ids. A connect method, a capability or a way of making sites can't be declared without its code. Typecheck therefore reports a missing piece as a missing property at the developer's literal, naming it. No second helper links services to a descriptor, and no test restates which parts each capability needs. The six existing providers move to this form, and their services' code stays in their own modules.

**Alternatives:**
- A descriptor and services, linked by a services helper whose conditional types require the parts the descriptor declares (lanes v1, diverge-1 and diverge-2). Not taken: under design-doc-decision-1 nothing keeps a provider's halves apart. With each part beside its code, completeness is the shape of the value itself.
- One `account.connect( method, input )` per provider that dispatches on the method's id, as today. Not taken:
  - a device or loopback method would need `start` through a conditional rule over the methods' kinds;
  - a method the dispatch misses fails only at run time.
- A `pull` flag and a `create` new-site kind beside optional functions, as today. Rejected: they let a provider declare pull or create without the code, the same gap as models without a model connection.
- Image generation as a capability of its own. Not taken: no provider or source shows a service that offers images without chat models.

**Trade-offs:**
- A provider module imports its services' code. Only hosts import it.
- Two methods that share logic call a shared function of their folder, where today one `connect` branches.
- The six providers' connect code moves from one dispatcher per provider into their methods.

**Claims:**
- observed: what surfaces read (`Provider.ai`, `Provider.sites`) and the matching services (`ProviderServices.ai`, `ProviderServices.sites`) are optional independently of each other, and `pull` and `newSite` are flags beside optional functions (read `packages/providers/types.ts:119-131,150-179,237-320`).
- observed: a provider's `connect` dispatches on the method's id, and its `start` ignores the method (`.pipelines/providers-api-for-external-devs-v2/2-design-doc/lanes/radical/design-doc/observations.txt` §11).
- observed: the device and loopback providers (OpenAI, GitHub Copilot, Spacefast) implement `start`, and the form and redirect providers don't (`.pipelines/providers-api-for-external-devs/2-design-doc/design-doc/observations.txt`).
- observed: `defaultModel` and `AccountDetails.models` are typed as the global `AiModelId`, and GitHub Copilot casts its plan's models to it (read `packages/providers/types.ts:97,175` and `packages/providers/github-copilot/descriptor.ts:26-31`).
- assumed: typecheck reports each missing piece at the property of the developer's literal, naming it; see design-doc-assumption-1.

design-doc-decision-3: The package finds its provider modules at build time, in Studio's order, and its checks report one it can't find

**Serves:** spec-requirement-1, spec-requirement-2, spec-requirement-3, spec-requirement-9, spec-acceptance-criterion-1, spec-acceptance-criterion-2, spec-acceptance-criterion-6, spec-acceptance-criterion-10, spec-acceptance-criterion-17
**Decision:**
- A provider folder is a top-level folder of the package that holds the provider module the contract names. The hosts' entry collects every such module with Vite's build-time glob import, as `@studio/agent` collects its skills. No list in the package names a provider.
- Studio's order puts the six existing providers first, in today's order: WordPress.com, Anthropic, OpenAI, Google Gemini, GitHub Copilot, Spacefast. Every other provider follows, ordered by id. The registry's lists, model lookup and the catalog all follow this order:
  - `PROVIDER_IDS` lists every provider;
  - `AI_PROVIDER_IDS` lists those with AI, and `SITES_PROVIDER_IDS` those with sites;
  - `findAiModel` returns the first provider that lists a model's id.
- `getProvider( id )` stays synchronous. It throws an error that names any id no provider has.
- The package's tests, which `npm test` runs, fail with a report that names the folder in these cases:
  - a top-level folder without the provider module, naming the module it expects;
  - a provider module that exports no provider under the contract's name;
  - two providers with the same id;
  - lists whose head isn't the six existing providers in today's order.
- knip reports the files of a folder whose provider module the glob misses as unused, at those files.
- Removed: the descriptor and services maps, the hand-written id lists and unions, and `types.ts`'s imports from each folder.

A provider that passes these checks, and design-doc-decision-2's typecheck, is in every host's registry. Through the catalog it is in every surface its capabilities reach.

**Alternatives:**
- One hand-written, ordered registration (lane v1). Not taken: every provider would be one more edit to a shared file. With only hosts reading providers, the registration's one gain is literal id types, which design-doc-decision-7 doesn't use.
- A generated, committed index (lane diverge-2). Not taken: it adds a command to remember and a generated file that conflicts between branches, and its gain is the same literal types.
- Order by folder name. Rejected: OpenAI would follow GitHub Copilot, which moves rows in Settings and resolves the model ids GitHub Copilot shares to GitHub Copilot (spec-requirement-9).
- An order rank that each provider declares. Rejected: every new provider would have to pick a rank, and two equal ranks still need a rule.

**Trade-offs:**
- The hosts' entry depends on Vite's transform. A program that loads it without Vite fails when it imports it.
- The order names the six existing providers in a list that is never edited for a new one.
- A provider's id stays in its value, so renaming its folder changes nothing stored. Changing the id itself does.

**Claims:**
- observed: `@studio/agent` collects its skills with Vite's glob import, in code the CLI and Studio on the web run (`.pipelines/providers-api-for-external-devs-v2/2-design-doc/lanes/radical/design-doc/observations.txt` §14).
- observed: Vite 8.3.5 adds its glob-import plugin to every build. electron-vite builds the Desktop main process as a Vite build that bundles `@studio/providers` from source, the CLI bundles the `@studio/*` packages, and the test projects alias the package to its source (`.pipelines/providers-api-for-external-devs-v2/2-design-doc/lanes/diverge-1/design-doc/vite-glob-in-every-build.txt`; no code has changed since it was recorded: `git diff --stat 7ddc6ddac HEAD -- . ':!.pipelines'` is empty).
- observed: knip enables its Vite plugin for `packages/providers`, and treats the targets of a non-raw `import.meta.glob` as entries (`.pipelines/providers-api-for-external-devs/2-design-doc/design-doc/knip-vite-glob.txt`). It reports a file of a provider folder that nothing imports as unused (`.pipelines/providers-api-for-external-devs-v2/2-design-doc/lanes/diverge-2/design-doc/knip-and-indexer-probe.txt`).
- observed: today's orders. `AI_PROVIDER_IDS` is wpcom, anthropic, openai, gemini and github-copilot. `PROVIDER_IDS` adds spacefast, and `SITES_PROVIDER_IDS` is wpcom and spacefast. `findAiModel` returns the first provider that lists an id (read `packages/providers/registry.ts:17-35` and `models.ts:31-41`).
- assumed: the Desktop main build bundles every provider module through the glob; see design-doc-assumption-2.

design-doc-decision-4: Each host's catalog holds what that host offers

**Serves:** spec-requirement-2, spec-requirement-9, spec-acceptance-criterion-3, spec-acceptance-criterion-5, spec-acceptance-criterion-7, spec-acceptance-criterion-17
**Decision:** The catalog builder takes what the host offers: the kinds of connect method it runs, and the sites providers it publishes to.
- The Desktop app and `studio ui` run form, device and loopback methods, and publish to every sites provider through `studio push`.
- Studio on the web runs form methods, and publishes only to WordPress.com, through WordPress.com's own sync.
- No catalog lists the Studio sign-in as a connect method. `apps/ui` shows it as WordPress.com's row, by name (spec-exclusion-6).

Every provider stays in the catalog, so a model resolves to the same provider in every app. Settings hide a provider left with no method that the host offers, as they do today. A provider's sites appear in the catalog only where the host publishes to it. `apps/ui` stops filtering providers by connector capabilities, and `capabilities.loopbackSignIn` is removed. The CLI connects through every kind, the Studio sign-in included, as today.

**Alternatives:**
- `apps/ui` filtering by the connector's capabilities, by `nativeSites` for publishing (lanes v1, diverge-1 and diverge-2) and by `loopbackSignIn` for methods. Not taken: the host would serve a catalog, and `apps/ui` would then hold a second statement of what the host can do with it.
- Studio on the web publishing to new archive providers in the page. Not taken: spec-requirement-2's bullet for the web names account, model and image services, and spec-acceptance-criterion-5 names the Desktop app and `studio ui`.

**Trade-offs:** An archive provider whose API accepts calls from a page, which the web could in principle publish to, stays out of the web's catalog.
**Claims:**
- observed: `loopbackSignIn` is used only to filter connect methods, in Settings (`.pipelines/providers-api-for-external-devs-v2/2-design-doc/lanes/radical/design-doc/observations.txt` §6).
- observed: Studio on the web's remote-site methods throw for any provider but WordPress.com (same file, §10).
- observed: the palette leaves out, off native hosts, the providers that connect only by device or loopback sign-in, or that publish static exports (same file, §9).
- observed: the Desktop app and `studio ui` publish by running `studio push` (read `packages/common/sites/sync.ts:56-79`).

design-doc-decision-5: Hosts present the remote sites they hand to `apps/ui`

**Serves:** spec-requirement-2, spec-requirement-7, spec-requirement-9, spec-acceptance-criterion-5, spec-acceptance-criterion-6, spec-acceptance-criterion-17
**Decision:** Every remote site a connector returns carries what the publish panel shows of it, from the provider's presentation. That covers the account's sites, a local site's connections, and a site just created. It carries:
- its details and links;
- why it can't be pushed to, and why it can't be pulled from, now, or nothing;
- whether it has backups to browse.

A local site's connections come back in two forms: as stored, or refreshed against the account's current sites through the provider's own rule for merging them. The publish panel shows the stored ones until the refreshed ones arrive, as it does today with the account's sites. Before a push, the host says what the user should know about pushing that local site to that remote site. `apps/ui` renders all of this without knowing which provider gave it, and keeps naming WordPress.com's sync statuses where it names them today (spec-exclusion-6).

**Alternatives:**
- The publish panel running each site's presentation functions. Not taken: under design-doc-decision-1 no provider code reaches `apps/ui`.
- Presentation as declarative data in the catalog, such as tables from site states to messages. Rejected: WordPress.com's issues and environment labels read several of a site's fields and the direction, which a table can't state without becoming code.

**Trade-offs:**
- What the panel computed per site now crosses the connector.
- A push makes one more connector call, for its warning.
- A presentation function that throws fails the host's listing, where today it fails the panel's render.

**Claims:** observed: the publish panel runs the descriptor's `describe`, `issue`, `pushWarning`, `hasBackups` and `withDetails` in the page (`.pipelines/providers-api-for-external-devs-v2/2-design-doc/lanes/radical/design-doc/observations.txt` §7), and WordPress.com's issues and environment label read several fields and the direction (read `packages/providers/wpcom/sites/site.ts:100-137`).

design-doc-decision-6: Provider text is built in the app's locale

**Serves:** spec-requirement-9, spec-requirement-2, spec-acceptance-criterion-17
**Decision:** The connector asks for the catalog, and for presented remote sites, in the app's current locale, and every host builds provider text in that locale. When the locale changes, `apps/ui` refetches the catalog and the presented sites. Account summaries in `AiSettings` keep today's behavior.
**Alternatives:**
- Building in the host's own locale. Rejected for the `studio ui` server, which loads its locale once, at start. After the user switched language, Settings, the pickers and the publish panel would show provider text in the old language until a restart. Today that text follows the switch at once, because `apps/ui` evaluates it (spec-requirement-9).
- Serving source strings that `apps/ui` translates. Rejected: text built with `sprintf` or chosen by a function, such as a site's issue, can't be translated after it is built.

**Trade-offs:** The `studio ui` server builds text for a locale other than its own while it answers the request.
**Claims:**
- observed: the Desktop main process swaps its locale data when the user switches language (read `AGENTS.md`, "i18n - Never translate at module level", and `.pipelines/providers-api-for-external-devs-v2/2-design-doc/lanes/radical/design-doc/observations.txt` §8). The CLI, the `studio ui` server included, loads its locale once at start and never reloads it (same file, §8).
- observed: every supported locale's data is bundled, and loaded by name (same file, §13).
- assumed: the `studio ui` server builds provider text in a requested locale; see design-doc-assumption-3.

design-doc-decision-7: Studio's shared code receives providers from its caller, and provider ids are data

**Serves:** spec-requirement-1, spec-requirement-8, spec-acceptance-criterion-1, spec-acceptance-criterion-2, spec-acceptance-criterion-10, spec-acceptance-criterion-16
**Decision:**
- Outside the package, `ProviderId` and `AiModelId` are strings. `AiProviderId`, `SitesProviderId`, `ProviderConfigs` and `ProviderSites` are removed. Which providers exist, and what each offers, is the registry in hosts and the catalog in `apps/ui` and the agent protocol.
- `@studio/common`'s functions over providers take them from their caller, as `connectProvider` already takes the provider it connects. That covers config storage and renewal, account state, connect and disconnect, remote-site connections, and checking a default hosting provider. `@studio/common` keeps importing only the root entry and `/wpcom`.
- The agent protocol's session-model helpers take the catalog: the recorded model, the pinned provider and the effective provider. Hosts pass theirs, and `apps/ui` passes the catalog it loaded.
- Code that names WordPress.com uses WordPress.com's own config and site types by name. Code that handles any provider handles the base types.
- Hosts keep checking the ids they receive and read from storage against the lists, as they do today.

**Alternatives:**
- Letting `@studio/common`'s host-only modules import the hosts' entry. Not taken: `apps/ui` imports `@studio/common`'s modules, and only the lint rule that covers all of `@studio/common` keeps provider values out of `apps/ui`.
- Literal id unions (lanes v1 and diverge-2). Not taken: they need a registration or an index (design-doc-decision-3), and they tie types outside the package to the set of providers. That set is what made other packages fail typecheck when a provider was added.

**Trade-offs:**
- The signatures of `@studio/common`'s provider functions and of the protocol's session-model helpers change, and so do their callers.
- A misspelled literal id compiles, and fails when it runs.

**Claims:**
- observed: `connectProvider` takes the provider's services from its caller (`.pipelines/providers-api-for-external-devs-v2/2-design-doc/lanes/radical/design-doc/observations.txt` §12).
- observed: the rule that keeps `@studio/common` off every `@studio/providers` subpath but `/wpcom` covers all its files but its tests (same file, §15).
- observed: constructs outside the package typed over every provider id made the sample provider fail typecheck in `@studio/common` and in tests of other packages (`.pipelines/providers-api-for-external-devs/1-spec/spec/probe/2-registered-repo-typecheck.txt`).
- observed: hosts check the ids they receive against the runtime lists (`.pipelines/providers-api-for-external-devs-v2/2-design-doc/lanes/diverge-1/design-doc/provider-typed-consumers.txt`; the code is unchanged since).

design-doc-decision-8: Studio stores any provider's config and remote-site connections in the shared sections by default

**Serves:** spec-requirement-1, spec-requirement-2, spec-requirement-8, spec-acceptance-criterion-2, spec-acceptance-criterion-3, spec-acceptance-criterion-4, spec-acceptance-criterion-6, spec-acceptance-criterion-8, spec-acceptance-criterion-16
**Decision:** The config store keeps any provider in its `providerConfigs.<id>` section. Two providers override that, and their storage doesn't change:
- WordPress.com stays in `authToken`, the Studio sign-in;
- Anthropic keeps an API key in `anthropicApiKey`, with today's fallback to `cli.json`, and its subscription token in `providerConfigs.anthropic`.

The remote-site connection store keeps any sites provider in `remoteSites` entries tagged with its id. Each entry holds the site as the provider returned it, with Studio's sync times. Only WordPress.com overrides that, with `connectedWpcomSites`. Forgetting a local site's connections covers every sites provider.

The stored-id mapping keeps one exception, Anthropic's `anthropic-api-key`. Every other provider is stored under its id. The following already work for any id and don't change:
- renewal, and forgetting a config the provider rejects;
- `rememberedSignIns` and `signInHostId`;
- the default hosting provider;
- Studio on the web's per-id configs.

The overrides are Studio's storage, not part of the provider contract. Every write still goes through `shared.json`'s lock, and renewal through its per-provider lock. The exhaustive per-provider store maps are removed.
**Alternatives:**
- A storage field the provider declares. Rejected: it puts storage into the provider contract, against "Providers own no storage" (`docs/design-docs/providers.md`, principle 5), and only two providers would ever use it.
- Migrating every account into one new format. Rejected: builds from before the change would no longer read what new builds write (spec-requirement-8).

**Trade-offs:** A new provider never gets a storage field of its own, only its section, as OpenAI, Google Gemini, GitHub Copilot and Spacefast have today.
**Claims:**
- observed: OpenAI, Google Gemini, GitHub Copilot and Spacefast use the per-id section the default would (read `packages/common/lib/provider-config.ts:64-144`), and Spacefast's connections use the generic store, which keeps the site as given (read `packages/common/lib/remote-sites.ts:69-133`).
- observed: every stored id equals the provider's id except Anthropic's (read `packages/providers/registry.ts:62-84`).
- observed: in `shared.json`, `providerConfigs`, `rememberedSignIns` and `remoteSites` are keyed by plain strings, and `aiProvider` is a plain string (read `packages/common/lib/shared-config.ts:54-84`). An unknown `defaultHostingProvider` reads back as no preference (read `packages/common/lib/user-settings/user-preferences.ts:191-195`).

design-doc-decision-9: Lint keeps provider code out of surfaces at the package's entries, and never names a provider folder

**Serves:** spec-requirement-7, spec-requirement-1, spec-acceptance-criterion-15
**Decision:**
- The rules against Node APIs and other workspace packages keep covering every file of `@studio/providers` except its tests. Each report lands at the import, in the provider's own file.
- The zone that today lists the files the surface entry is made of names only the package's shared files and WordPress.com's sign-in files. It never names a provider folder: a file of the root entry or of `/wpcom` that imports anything else is reported at the import.
- The restriction that keeps `apps/ui`, `@studio/common` and the agent protocol off every subpath but `/wpcom` stays. Only `apps/ui`'s static connector and its in-memory connector are exempt.

A new provider adds no file to what surfaces import, so nothing it writes can carry its services into a surface. Its Node and workspace imports are reported in its folder.
**Alternatives:**
- A zone that matches provider folders by pattern, with each folder's descriptor and config as exceptions (lanes v1, diverge-1 and diverge-2). Not taken: there is no descriptor to except.
- A test that checks each provider file's imports. Not taken: ESLint's existing rules already report each crossing at the import.

**Trade-offs:** The playground and the behavior tests bundle the providers through the in-memory connector, which is test and development code.
**Claims:**
- observed: the zone lists the six folders by name, and the restriction keeps `apps/ui`, `@studio/common` and the protocol off every subpath but `/wpcom` (`.pipelines/providers-api-for-external-devs-v2/2-design-doc/lanes/radical/design-doc/observations.txt` §3).
- observed: the rules against Node APIs and workspace packages match `packages/providers/**/*.ts` and ignore only `tests/` (read `eslint.config.mjs:410-431`).
- observed: the in-memory connector imports `@studio/providers`, and the playground renders over it (`.pipelines/providers-api-for-external-devs-v2/2-design-doc/lanes/radical/design-doc/observations.txt` §16).

design-doc-decision-10: The contract names the four model APIs, and the agent runs exactly those

**Serves:** spec-requirement-6, spec-acceptance-criterion-3, spec-acceptance-criterion-4, spec-acceptance-criterion-13, spec-acceptance-criterion-14
**Decision:** The contract defines the model APIs Studio runs as a union: `openai-completions`, `openai-responses`, `anthropic-messages` and `google-generative-ai`. A provider's model connection is typed to that union, so a connection that names any other API fails typecheck in its folder, naming the API.

In `@studio/agent/shared/models.ts`, the connection stream has one stream for each API in the union. The agent fails typecheck if the union gains an API without a stream. A connection that names an API outside the union, such as one cast past the types, ends the turn with an error that names the API, and no request is sent. The Node runtime and the browser agent both stream through this code. GitHub Copilot narrows the models it reads from pi's catalog to the union, in its own folder.
**Alternatives:**
- Keeping the `openai-responses` fallback, with only the narrowed type. Rejected: spec-requirement-6 forbids sending a request over a different API.
- A runtime check only. Rejected: nothing would report the API until a user chats.

**Trade-offs:** Adding a fifth API is Studio's decision. It changes the union and the agent together (spec-exclusion-3).
**Claims:**
- observed: `openai-completions`, `anthropic-messages` and `google-generative-ai` get their own stream, and any other API goes to `openai-responses` (read `packages/agent/shared/models.ts:17-29`).
- observed: every existing connection names one of the four APIs (`.pipelines/providers-api-for-external-devs/2-design-doc/design-doc/model-apis.txt`).
- observed: GitHub Copilot's connection takes its model from pi's catalog, typed `Model< Api >` (read `packages/providers/github-copilot/ai.ts:36-56`).
- assumed: an error the stream raises before any request reaches the user as the chat's error, in both runtimes; see design-doc-assumption-5.

design-doc-decision-11: Tests outside the package hold for any set of providers

**Serves:** spec-requirement-1, spec-acceptance-criterion-1, spec-acceptance-criterion-2, spec-acceptance-criterion-17
**Decision:** Some tests outside `@studio/providers` build or compare an `AiSettings`: `packages/common/lib/tests/ai-settings.test.ts`, `packages/agent/protocol/sessions/tests/model.test.ts` and `apps/studio/src/modules/user-settings/lib/tests/settings-tracks.test.ts`. They build its accounts from the registry, and assert only on the providers they exercise. `apps/ui`'s behavior tests render over the catalog the package builds. A new provider then adds an account that those tests treat as not connected, and a catalog entry the UI tests render, and changes none of them.
**Alternatives:** Making `AiSettings.accounts` partial, with a missing account meaning not connected. Rejected: every consumer that reads `accounts[ id ].connected` would change, for a fix that belongs in the tests.
**Trade-offs:** A later test outside the package that compares every provider's account fails when a provider is added. See Risks.
**Claims:**
- observed: with a sample provider listed, four tests failed in `ai-settings.test.ts` and `model.test.ts` on their full accounts, and the `apps/ui` settings and model-picker tests passed unchanged (`.pipelines/providers-api-for-external-devs/1-spec/spec/probe/3-listed-tests.txt`).
- observed: the typecheck failures in `model.test.ts` and `settings-tracks.test.ts` came from literals typed over every provider id (`.pipelines/providers-api-for-external-devs/1-spec/spec/probe/2-registered-repo-typecheck.txt`). With string ids, such a literal holds for any set of providers.

design-doc-decision-12: The contract documents every value, and only WordPress.com may declare the Studio sign-in

**Serves:** spec-requirement-5, spec-requirement-3, spec-acceptance-criterion-12
**Decision:** Every field, method, parameter and result of the contract carries documentation that states:
- what the value means;
- whether a new provider supplies it or acts on it;
- what Studio does with it.

That covers the provider type, the helper, the catalog's types and `errors.ts`. The provider's `id` says that Studio stores it, so it never changes. `AiConnection.piProvider` says how pi uses the name.

The contract offers a new provider form, device and loopback methods. The Studio sign-in method is accepted only in a provider whose id is WordPress.com's, and typecheck reports it anywhere else, at the method, naming the kind.

The other parts that work for one provider only stay available. Their documentation says they belong to WordPress.com, and what a new provider does with them:
- `requiresPaidAiCredits` and the paid default model follow the WordPress.com account's paid credits, and a new provider leaves them out;
- `push`'s options use the selection format WordPress.com sync defined. A provider without selective sync receives the whole site, and one with it receives what the user picked;
- `list`'s `planRequired` option, which a new provider ignores;
- the pull steps, which are remote backups and a Reprint exporter, and which a new provider leaves out;
- making a new site through WordPress.com's checkout;
- whether a site has backups to browse.

**Alternatives:**
- Documenting the Studio sign-in as WordPress.com's and leaving it available. Rejected: a new provider that declared it would pass every check. The apps would then leave it out of the catalog's methods, and `studio code`'s `/connect` would run the WordPress.com login, so the provider would be left out of a surface, against spec-requirement-3.
- Removing every WordPress.com-only part from the contract a new provider sees, and typing WordPress.com through a wider contract. Rejected:
  - these are WordPress.com behaviors Studio keeps (spec-exclusion-6);
  - it would add a second provider type for one provider;
  - spec-requirement-5 accepts documenting them.

**Trade-offs:** A new provider can still set the documented WordPress.com-only values, against their documentation.
**Claims:**
- observed: the CLI connects any `redirect` method by running the WordPress.com login, and disconnects it by signing out of Studio. Settings drop `redirect` methods and hide a provider left with none (spec, `apps/cli/lib/providers.ts:144-145`, `apps/cli/ai/slash-commands.ts:323-327`, `apps/ui/src/features/settings/settings-view/ai-panel.tsx:28-33` and `providers-panel.tsx:187-192`).
- observed: only WordPress.com declares a `redirect` method (`.pipelines/providers-api-for-external-devs/2-design-doc/design-doc/observations.txt`).
- observed: the push options, `planRequired` and the pull steps are typed in `packages/providers/types.ts:237-286`, with the options taken from `wpcom/sites/site.ts` (read).
- assumed: the rejection is reported at the method, naming the kind; see design-doc-assumption-1.

design-doc-decision-13: The package README is the complete guide to adding a provider

**Serves:** spec-requirement-4, spec-acceptance-criterion-1, spec-acceptance-criterion-2, spec-acceptance-criterion-11
**Decision:** The section of `packages/providers/README.md` on adding a provider covers:
- every change a developer makes: one folder in the package, with its provider module, and nothing else;
- for each capability and connect method, the parts a provider fills in, as design-doc-decision-2 shapes them;
- the connect methods a new provider can use (`form`, `device`, `loopback`), and the apps that offer each: Studio on the web offers forms only;
- the four model APIs;
- which declared values Studio stores, and that they never change: the provider's id, its model ids and its connect methods' ids;
- that a provider's code runs in Node and in the page, and that Studio's apps show it from the catalog its host builds, so a provider never writes UI code or splits itself for the UI;
- how to test a provider: its own `tests/`, the package's tests that check every folder and the catalog, and `npm test -- packages/providers`.

`docs/design-docs/providers.md` states the same architecture:
- providers behind the hosts, one value each;
- the catalog and presented sites;
- the order, and ids as data;
- default storage;
- the four APIs.

Its principle that surfaces read descriptors becomes that surfaces render what their host serves. The README points to the contract's reference documentation (design-doc-decision-12) instead of repeating it.
**Alternatives:** A generator that creates a provider's files. Not taken: the spec's "Considered and not required" leaves it out, and documentation alone meets spec-requirement-4.
**Trade-offs:** The README and the contract can drift. The README states the rules, and the contract documents the values.
**Claims:** observed: today's steps name edits to `types.ts`, `registry.ts`, `services.ts`, `provider-config.ts` and `remote-sites.ts`, and leave out the id lists, `AiModelId`, the lint folder list and the agent (read `packages/providers/README.md:57-59`, and `.pipelines/providers-api-for-external-devs/1-spec/spec/probe/README.md`).

## Interfaces

**A provider (`packages/providers/<folder>/`)**
- The provider module exports one value under the name the contract fixes, declared through the provider helper. The value holds:
  - its id, which Studio stores, and its label, description, learn-more URL, icon and logo;
  - `account`:
    - its config schema;
    - its connect methods, the first being the default. Each has a stable id, a label, optional Markdown instructions, a kind, and its code:
      - `form`: its input schema, and `connect( values )`, which returns the config or throws `ConnectError`;
      - `device` and `loopback`: `start( context )`, which returns a `PendingConnect`, and `connect( handoff )`, which returns the config. A loopback handoff includes the redirect's parameters;
      - the Studio sign-in: WordPress.com only;
    - `describe( config )`, whose `models` lists only the provider's own model ids;
    - optionally, `expiresAt`, `remember`, `refresh` and `disconnect`, with today's meaning;
  - optionally, `ai`:
    - its models, each with a stable id, label, image support and paid-credit lock;
    - its default model and paid default model, from its own model ids;
    - `model( config, modelId, options )`, which returns an `AiConnection` whose `model.api` is one of the four APIs;
    - optionally, `generateImages` and `canGenerateImages`;
  - optionally, `sites`:
    - its largest push, whether a sync can be selective, and what a push sends;
    - its intro;
    - the presentation of a site: `describe`, `issue`, `pushWarning`, `hasBackups` and the merge of connections with the account's sites;
    - `list` and `push`;
    - how a new site is made: by Studio, with `create( config, { name } )`, or through WordPress.com's checkout;
    - optionally, the pull steps.
- Imports: the folder's own modules, the package's shared modules, and its npm dependencies. Never a Node API or another workspace package.

**The root entry (`@studio/providers`)**
- The contract's types, the catalog's types, `ConnectError`, `NotConnectedError` and `RemoteSiteError`.
- `DEFAULT_PROVIDER_ID` (`wpcom`).
- `normalizeProviderId( value, ids )` and `toStoredProviderId( id )`, whose one exception is Anthropic's `anthropic-api-key`.
- `formatRemoteSite( provider, id )` and `parseRemoteSite( value, sitesProviderIds )`.
- Types: `ProviderId` and `AiModelId` are `string`. Removed: `AiProviderId`, `SitesProviderId`, `ProviderConfigs` and `ProviderSites`. WordPress.com's config and `SyncSite` keep their names.

**The hosts' entry (`@studio/providers/services`)**
- `getProvider( id )` returns the provider synchronously. It throws, naming the id, for an id no provider has. It replaces the root entry's `getProvider` and `getProviderServices`.
- `PROVIDER_IDS`, `AI_PROVIDER_IDS` and `SITES_PROVIDER_IDS`, in Studio's order.
- `findAiModel( id )`, `getAiModels( provider, account? )` and `getDefaultAiModel( provider, options? )`, with today's behavior over that order.
- The catalog builder takes what the host offers (the kinds of connect method it runs and the sites providers it publishes to) and a locale, and returns the catalog.
- The presenter takes a provider, sites and a locale, and returns them presented. It merges a local site's connections with the account's sites, and returns the warning for pushing a local site to a remote site.
- `getConnectMethod` and `getConnectFields`, for the CLI's prompts.
- `createTusUpload` stays.

**The catalog (plain data, at the connector)**
- The providers in Studio's order. Each holds:
  - `id`, `label`, and optionally `description`, `learnMoreUrl`, `icon` and `logo`;
  - `methods`: the connect methods this host offers, each with `id`, `label`, `kind`, optional `instructions`, and, for a form, its fields, each with `name`, `title`, optional `description` and `placeholder`, and `secret`;
  - optionally, `ai`: `models`, each with `id`, `label`, `supportsImages` and `requiresPaidAiCredits`, then `defaultModel` and optionally `paidDefaultModel`;
  - optionally, where this host publishes to it, `sites`: optionally `maxPushSize`, then `pull`, `selective`, `content`, `newSite` (`create` or `checkout`), and `intro` with `title`, `description` and `learnMoreUrl`.
- All text is in the requested locale.

**A presented remote site**: the provider's site, together with its details (title and value), its links (title and URL), its issue for a push and for a pull (text or none), and whether it has backups.

**The `Connector` (`apps/ui/src/data/core/types.ts`)**
- New: the catalog, for a locale.
- New: the warning for pushing a local site to a remote site, for a locale.
- Changed: `getRemoteSites`, `listAccountSites` and `createRemoteSite` return presented sites, for a locale. `getRemoteSites` returns a local site's connections either as stored or refreshed against the account's sites.
- Removed: `capabilities.loopbackSignIn`.
- The ipc connector reaches new Desktop IPC handlers, the local connector new `studio ui` routes, and the static connector Studio on the web's backend. Each is a thin wrapper over the hosts' entry.

**`@studio/common`**: `readProviderConfig`, `writeProviderConfig`, `readFreshProviderConfig`, `forgetRejectedConfig`, `readSignInContext`, `readAiSettings`, `describeAccount`, `connectProvider`, `disconnectProvider`, `setAiProvider`, `startProviderConnect`, `getRemoteSites`, `rememberRemoteSite`, `forgetRemoteSite`, `forgetRemoteSites` and the reading of the default hosting provider take the providers, or the provider, from their caller. They store under `providerConfigs.<id>` and in `remoteSites`, except for design-doc-decision-8's overrides.

**The agent protocol (`packages/agent/protocol/sessions/model.ts`)**: `readRecordedSessionModel`, `resolveSessionModel`, `resolveSessionModelForProvider`, `resolveSessionProvider` and `getEffectiveSessionProvider` take the catalog, and keep today's results for the six providers.

**The agent's stream (`@studio/agent/shared/models.ts`)**: `createConnectionStream( ai )` streams a connection whose API is one of the four. For any other API, it ends the turn with an error that names the API, and sends no request.

**Contracts narrowed by the change**
- `apps/ui`, `@studio/common` and the agent protocol no longer import provider values. They read the catalog, or receive providers from their caller.
- A provider is one value. Each connect method carries its own `connect`, and each sign-in its `start`. AI carries its model connection, and sites carry `list` and `push`. Making sites carries `create`, and pulling carries the pull steps. The six providers move to that.
- A provider's default models and `AccountDetails.models` accept only its own model ids. WordPress.com and GitHub Copilot already conform at run time.
- The Studio sign-in method is accepted only in WordPress.com's provider, which is the only one that declares it today.
- `AiConnection.model.api` is limited to the four APIs. Among providers, GitHub Copilot narrows its catalog models, and the two agent runtimes already handle only these.
- `getProvider` throws for an id no provider has, where today it returns `undefined` past its types. Hosts pass ids from the lists, or ids they normalized against them.
- Publishing on Studio on the web is limited to WordPress.com, the same set as today for the six providers.
- `capabilities.loopbackSignIn` is removed. Its only use was filtering connect methods, which the host's catalog now does.

**Left without a purpose, and removed**
- The descriptor and services modules of each provider, and `Provider` and `ProviderServices` as two halves.
- The surface zone's per-folder exceptions.
- `getProviderSites`, the `PROVIDERS` and `SERVICES` maps, `STORED_PROVIDER_IDS`'s identity entries, and the hand-written id lists and unions.
- `@studio/common`'s exhaustive per-provider store maps.

**Contracts widened by the change, and what each consumer newly admits**
- `ProviderId` and `AiModelId` admit any string at compile time:
  - `@studio/common`'s functions admit any id their caller's providers hold;
  - the Desktop and `studio ui` handlers keep normalizing the ids they receive against the lists;
  - Tracks' `sync_type` admits any sites provider's id.
- The set of providers is every provider module in the package:
  - `shared.json` admits a new id as a `providerConfigs`, `rememberedSignIns` and `remoteSites[].provider` key or value, and in `aiProvider`;
  - session entries record it;
  - the user preferences admit it as `defaultHostingProvider`, checked against the sites providers when read;
  - `studio push --remote-site` admits it as a prefix;
  - the catalog lists it, so Settings, the pickers, the palette and the publish panel render it;
  - older builds read such an id as unknown: `normalizeProviderId` returns `undefined`, and they fall back to the saved selection or WordPress.com, as for any unknown id today.
- Session entries record any listed model id. Readers keep a recorded model only when a provider in the catalog lists it. An older build drops a recorded model it doesn't know, and falls back to the provider's default.

## Dependencies

- Vite's `import.meta.glob` and its `vite/client` types, for the hosts' entry. Neither is new: `vite` is a root dev dependency, and `@studio/agent/shared/skills.ts` uses both in code the CLI and Studio on the web bundle and Vitest runs.
- knip's Vite plugin, already enabled for `packages/providers`, which follows the glob.
- `@wordpress/i18n`'s locale data for every supported locale, which hosts already bundle (`getLocaleData` in `packages/common/lib/locale.ts`).
- `eslint-plugin-import-x`'s `no-restricted-paths` (4.17.1, already installed).
- `@earendil-works/pi-ai`'s `Model` type (1.5.0, already a dependency), narrowed to the four APIs.
- No new npm dependency. The bundle scripts don't change: the SDKs of the four APIs already ship, and the Mistral and AWS SDKs stay stripped. The Desktop renderer and the `studio ui` page stop bundling provider descriptors.

## Failure modes and observability

- **The catalog doesn't load** (an IPC error, the `studio ui` server unreachable, or Studio on the web's backend failing): `apps/ui` shows the provider surfaces in the error state of a failed query, and lists no provider until a retry succeeds. The host's error reaches the query, as any connector error does today.
- **A folder without the provider module, or a module that exports none under the contract's name:** knip reports the folder's files as unused, and `npm test` fails, naming the folder and the module it expects. At run time the provider is in no list.
- **A missing part** (a connect method's `connect`, a sign-in's `start`, AI's model connection, sites' `list` or `push`, `create` for sites Studio makes): a typecheck error at the property of the developer's literal, naming it.
- **A default model that isn't the provider's own, or the Studio sign-in outside WordPress.com:** a typecheck error in the provider's value.
- **A connection that names an API Studio doesn't run:** a typecheck error in the folder, naming the API. If the API is cast past the types, the chat's turn ends with an error that names it, and nothing is sent.
- **A Node API or another workspace package imported in a provider folder, or a root-entry file that imports a provider folder:** an ESLint error at the import.
- **Two providers with one id, or one of the six existing providers renamed, removed or reordered:** `npm test` fails, naming the folders.
- **An id no provider has, passed to `getProvider`:** an error that names the id, at the first call.
- **A provider's presentation throws for a site:** the host's listing fails with that error, and the publish panel shows it, as it shows any failed listing.
- **A locale without bundled data:** provider text is built in English, as the hosts' own text is.
- **A program that loads the hosts' entry without Vite:** it fails when it imports the entry, because `import.meta.glob` is not a function. No program does so today.
- **A stored config that no longer parses, or has expired:** read as not connected (unchanged).
- **A config the provider rejects:** forgotten in the Desktop app, `studio ui` and the CLI, keeping what the provider's `remember` returns (unchanged).

## Verification

- new test at the package's types (checked by `npm run typecheck`) — design-doc-decision-2, design-doc-decision-12, spec-acceptance-criterion-7, spec-acceptance-criterion-9, spec-acceptance-criterion-12 — typecheck rejects, at the property and naming it:
  - a form method without `connect`;
  - a device or loopback sign-in without `start`;
  - AI without its model connection;
  - sites without `list` or `push`;
  - sites that Studio makes without `create`;
  - a default model, paid default model or account model list outside the provider's own models;
  - the Studio sign-in in a provider other than WordPress.com.
- new test at the package's types (checked by `npm run typecheck`) — design-doc-decision-10, spec-acceptance-criterion-14 — a connection whose API is outside the four fails typecheck, naming the API.
- new test at the hosts' entry (`packages/providers/tests`) — design-doc-decision-3, spec-acceptance-criterion-10, spec-acceptance-criterion-17 — it checks that:
  - every top-level folder holds a provider module that exports a provider;
  - ids are unique;
  - the six existing providers lead every list in today's order, and the lists equal today's for them;
  - every model id GitHub Copilot shares resolves through `findAiModel` to the existing provider that lists it;
  - `getProvider` throws, naming an id no provider has.
- new test at the catalog builder (`packages/providers/tests`) — design-doc-decision-1, design-doc-decision-4, spec-acceptance-criterion-10, spec-acceptance-criterion-15 — it checks that:
  - every provider is in the catalog, in Studio's order;
  - each provider's methods are the ones whose kinds the host runs, and its sites appear only where the host publishes to it;
  - the Studio sign-in is never a catalog method;
  - every provider's entry is plain data, holding no function.
- new test at the presenter (`packages/providers/tests`) — design-doc-decision-5, spec-acceptance-criterion-17 — WordPress.com's and Spacefast's presented sites, refreshed connections and push warnings equal what their presentation gives today.
- new test at the `studio ui` server's catalog route — design-doc-decision-6 — the catalog comes back in the requested locale, whatever locale the server started in.
- existing test `packages/providers/tests/providers.test.ts` › "reads the id builds before `anthropic` stored, and keeps writing it" — design-doc-decision-8, spec-acceptance-criterion-16 — the stored-id exception, and every other id stored as itself.
- existing tests in `packages/common/lib/tests/ai-settings.test.ts` — design-doc-decision-7, design-doc-decision-8, spec-acceptance-criterion-16 — configs stay where builds of every version read them, with the providers passed in:
  - "stores an accepted key where every build reads it, and makes it the default without another";
  - "keeps a subscription token in its own section, and clears the other method on write";
  - "replaces a ChatGPT sign-in with an OpenAI API key";
  - "keeps the WordPress.com config in the Studio sign-in, and revokes it on disconnect";
  - "reads legacy values from cli.json and migrates them on write";
  - "selects only a connected provider, storing the id older builds read";
  - "treats an unknown stored provider as the default".
- existing tests in `packages/common/lib/tests/ai-settings.test.ts` › "disconnects a provider whose config expired or that the provider rejects" and "stores a renewed config, and forgets one the provider no longer accepts but its client" — design-doc-decision-8, spec-acceptance-criterion-8 — renewal and rejection run through the default store a new provider uses.
- existing tests in `packages/common/lib/tests/remote-sites.test.ts` › "keeps the Spaces a site publishes to, and forgets them with the site" and "records each sync and keeps the times of the others" — design-doc-decision-8, spec-acceptance-criterion-16 — connections stay in `connectedWpcomSites` for WordPress.com and in `remoteSites` for the others, and are forgotten with the local site.
- existing test `packages/agent/protocol/sessions/tests/model.test.ts` › "runs on the selected provider, or the first connected one, WordPress.com first" — design-doc-decision-7, design-doc-decision-11, spec-acceptance-criterion-17 — the protocol's helpers keep fallback with WordPress.com first, over the catalog.
- new test at `@studio/agent/shared/models` (`createConnectionStream`) — design-doc-decision-10, spec-acceptance-criterion-14 — a connection that names an API outside the four ends with an error that names the API, and no request goes out.
- existing tests `packages/agent/browser/tests/gemini-stream.test.ts` › "streams a Gemini reply through Google’s SDK with the connected key" and `packages/agent/node/runtime/tests/pi-runtime.test.ts` › "streams with the connection’s upstream model and error rewrite" — design-doc-decision-10, spec-acceptance-criterion-13 — connections over the supported APIs still stream in both runtimes.
- existing test `apps/ui/src/features/composer/chat-model-picker.test.tsx` › "offers only the models the connected account can run" — design-doc-decision-1, spec-acceptance-criterion-8 — the picker narrows to the account's models from the catalog and the account.
- existing test suites of `packages/common`, `packages/agent`, `apps/cli`, `apps/studio` and `apps/ui` (`npm test`), with the three test files of design-doc-decision-11 building accounts from the registry, and `apps/ui`'s tests rendering over the catalog — design-doc-decision-1, design-doc-decision-5, design-doc-decision-11, spec-acceptance-criterion-17 — the six providers behave as before in Settings, the pickers, the palette, the publish tab and panel, connecting, selection, fallback, images and publishing.
- end-to-end flow — design-doc-decision-2, design-doc-decision-3, design-doc-decision-9, design-doc-decision-11, design-doc-decision-13, spec-acceptance-criterion-1, spec-acceptance-criterion-2, spec-acceptance-criterion-11 — following only the README, a chat provider (an API key form, one of the four APIs) and a sites provider (a device sign-in) are each added as one folder. No other file changes, inside or outside the package, and `npm run typecheck`, ESLint on the changed files, `npm run knip` and `npm test` pass.
- end-to-end flow — design-doc-decision-2, design-doc-decision-3, spec-acceptance-criterion-9 — a provider part-way through being written fails the checks in each case of design-doc-decision-2 and design-doc-decision-3, each report naming the provider's file and the missing part.
- end-to-end flow — design-doc-decision-9, spec-acceptance-criterion-15 — with nothing outside the package changed, ESLint on a new provider's files reports a Node API import and another workspace package's import, each at the import, and nothing for a provider within the boundaries.
- end-to-end flow in `studio ui`, Studio on the web and the Desktop app — design-doc-decision-1, design-doc-decision-3, design-doc-decision-4, design-doc-decision-8, design-doc-decision-10, spec-acceptance-criterion-3, spec-acceptance-criterion-13 — the new chat provider meets each point of spec-acceptance-criterion-3 in each app, and its replies stream over its API.
- end-to-end flow in `studio code` — design-doc-decision-3, design-doc-decision-8, spec-acceptance-criterion-4 — the new chat provider meets each point of spec-acceptance-criterion-4.
- end-to-end flow in the settings and publish panel of `studio ui` and the Desktop app, and `studio push --remote-site <id>` — design-doc-decision-1, design-doc-decision-4, design-doc-decision-5, design-doc-decision-8, spec-acceptance-criterion-5, spec-acceptance-criterion-6 — the new sites provider, and a provider that offers both capabilities and is connected once, appear and publish as the criteria say.
- end-to-end flow in Studio on the web — design-doc-decision-4 — with a new archive-publishing provider in the package, the publish tab, Settings' hosting providers and the palette offer only WordPress.com, as before, and a device-only provider is not offered.
- end-to-end flow — design-doc-decision-2, spec-acceptance-criterion-7, spec-acceptance-criterion-8 — providers that declare each connect method, and each account and model feature the criteria list, behave as declared in Settings, the chat model picker, `/model` and a chat.
- end-to-end flow in `studio ui` — design-doc-decision-6 — after a language switch, Settings, the pickers and the publish panel show provider text in the new language without restarting the server.
- end-to-end flow — design-doc-decision-7, design-doc-decision-8, spec-acceptance-criterion-16 — builds from before and after the change each read what the other stored, and show the same accounts, defaults, connections and pins, as spec-acceptance-criterion-16 states.
- inspection — design-doc-decision-12, spec-acceptance-criterion-12 — every value of the contract states its meaning, whether a new provider supplies it or acts on it, and what Studio does with it, and each WordPress.com-only part says so.
- inspection — design-doc-decision-13, spec-acceptance-criterion-11 — the README covers each point the criterion lists, in agreement with the contract.

## Risks

- **The one-time change is wide.** The publish panel's per-site presentation moves behind the connector, including WordPress.com's sync statuses, which the most flows depend on. A presentation that differs from today's shows wrong issues or details for existing sites. The publish panel's existing tests and the presenter's test guard it.
- **Provider surfaces wait for the catalog at start.** If it arrives late, Settings, the pickers and the publish tab show a loading state that today's synchronous import never shows (design-doc-assumption-4).
- **A program that loads the hosts' entry without Vite**, such as a script run with `tsx` that imports it, fails when it imports it. Every program that reaches it today builds or tests through Vite (design-doc-assumption-2).
- **A misspelled literal provider or model id in Studio's code** compiles, and throws or finds nothing at run time (design-doc-decision-7). Studio's code passes literal ids only for WordPress.com, for Spacefast in its settings row, and in tests.
- **A later test outside the package that compares every provider's account** fails when a provider is added (design-doc-decision-11).
- **Account summaries in `studio ui`** stay in the server's startup locale after a language switch, as they do today. This design builds the catalog and the presentation in the app's locale, but leaves `AiSettings` as it is (design-doc-decision-6).
- **A provider that offers both chat models and remote sites** gets two palette entries with the same settings target, and its hosting entry lands on its AI provider row. It is the same provider and connection, so spec-acceptance-criterion-6 still holds.
- **On Studio on the web, a form-connected provider whose credential expires** is not renewed in the page, which reads stored configs without a refresh, as today. It shows as disconnected once the credential expires. Only OpenAI's ChatGPT sign-in and GitHub Copilot renew a credential today, and the web offers neither (`.pipelines/providers-api-for-external-devs/2-design-doc/design-doc/observations.txt`).
- **A form-connected provider whose API rejects calls from a page** is still offered on Studio on the web, and fails there when connecting or chatting. No source shows such a provider (spec, "Considered and not required").
- **A service that offers image generation without chat models** can't be added as a provider without declaring models (design-doc-decision-2). No provider or source shows one.

## Open assumptions

design-doc-assumption-1: Typecheck reports each missing piece of design-doc-decision-2 as a missing property at the property of the developer's literal, naming it, through the provider helper's inference of the provider's id and model ids. It reports a foreign default model, and the Studio sign-in outside WordPress.com, in the provider's value — assumed: the type tests of design-doc-decision-2 and design-doc-decision-12, and the flow with a provider part-way through being written, show those errors at those places.

design-doc-assumption-2: The Desktop main build bundles every provider module through the hosts' entry's glob, as the CLI and Studio on the web builds do — assumed: connecting the new chat provider from the Desktop app's Settings, and chatting on it, works.

design-doc-assumption-3: The `studio ui` server builds the catalog and the presented sites in a requested locale other than the one it started in, without changing the text of other requests it answers at the same time — assumed: the catalog route's test and the language-switch flow in `studio ui` show provider text in the new language.

design-doc-assumption-4: Each app loads the catalog before it renders a provider surface, without a loading state the user sees at start: over IPC in the Desktop app, over HTTP in `studio ui`, and in the page on the web — assumed: the end-to-end flows in the three apps show Settings, the pickers and the publish tab as promptly as before.

design-doc-assumption-5: An error the connection stream raises before any request reaches the user as the chat's error, in both the Node runtime and the browser agent — assumed: the new `createConnectionStream` test, and chats in `studio code` and on Studio on the web on a connection that names another API, show the error naming the API.
