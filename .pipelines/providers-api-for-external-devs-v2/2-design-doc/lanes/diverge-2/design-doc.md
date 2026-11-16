# Design Doc: Add a provider as a folder that the package indexes into static, typed code

## Overview

Today a provider exists in Studio only once it is written into lists that people maintain by hand. Inside `@studio/providers` these are the id unions (`ProviderId`, `AiProviderId`), the model-id union (`AiModelId`), the type maps (`ProviderConfigs`, `ProviderSites`), and the id lists and maps (`AI_PROVIDER_IDS`, `SITES_PROVIDER_IDS`, `PROVIDER_IDS`, `PROVIDERS`, `STORED_PROVIDER_IDS`, `SERVICES`). Outside the package they are Studio's per-provider config and connection stores in `@studio/common`, the folder list of the lint boundary, and tests that list every provider's account. A provider left out of `AI_PROVIDER_IDS` passes every check and appears in no surface. The contract mixes in parts only WordPress.com uses without saying so, and the agent sends any model API it doesn't recognize as `openai-responses`.

After the change, the package keeps an index of its provider folders: one module for each of its two entries, with static imports in a recorded order. A script in the package, the indexer, writes the index from the folders. A developer adds a provider by adding its folder and running the indexer, with no hand edit to a shared file. Every provider list, id union and type map derives from the index. A new provider's literal id, config, site and model ids therefore reach the types Studio already uses, without bundler discovery and without changing the type of any consumer. Typecheck checks a provider against itself. Its services are checked against its own descriptor in its folder, and again at its entry in the index when they skip the helper. knip and the package's tests report a folder the index misses, and the tests name the command that fixes it. The changes outside the package are each made once: storage defaults, a lint boundary by pattern, the four model APIs in the agent, publishing on Studio on the web, and tests outside the package. The contract and the README document the whole API.

Previous candidates:
- Lane v1: one hand-written ordered registration of descriptors, from which the lists and literal types derive, with services discovered by Vite's glob import. This design has no hand-written registration and no glob: a generated static index covers both halves, so typecheck sees every provider's services.
- Lane diverge-1: both halves discovered by Vite's glob import, the folder's name as the id, and provider ids and per-provider types as strings, with WordPress.com typed by name. This design keeps the closed literal types and every consumer's types. Ids stay declared in the descriptor, and the index is ordinary code.

## Architecture

New or reshaped inside `@studio/providers`:

- **A provider's folder** (`packages/providers/<folder>/`) holds:
  - its config schema (`config.ts`);
  - its descriptor module, which exports the descriptor under the name the contract fixes for every folder;
  - its services module, which exports the services under the name the contract fixes for every folder;
  - its own modules and its `tests/`.

  The descriptor and config import only each other and the package's shared surface files. No file of the folder imports another workspace package or a Node API, and a provider never reads or writes storage.
- **The index** is two generated modules, committed with the package's code. Only the indexer writes them.
  - The surface index imports every indexed folder's descriptor, in the index's order.
  - The services index imports, in the same order, every indexed folder's descriptor paired with its services.
- **The indexer** is a script of the package, run through the package's own scripts. It writes the index from the provider folders, and runs only at development time, in Node.
- **The registry** (`registry.ts`, in the surface entry) derives everything from the surface index:
  - the runtime lists `PROVIDER_IDS`, `AI_PROVIDER_IDS` and `SITES_PROVIDER_IDS`, in index order;
  - the types `ProviderId`, `AiProviderId`, `SitesProviderId`, `ProviderConfigs`, `ProviderSites` and `ProviderSite`;
  - `getProvider`, `getProviderSites`, `normalizeProviderId`, `toStoredProviderId`, `formatRemoteSite` and `parseRemoteSite`. The stored-id mapping keeps Anthropic's legacy id as its only exception.
- **The services entry** (`services.ts`) provides `getProviderServices` from the services index.
- **The contract** (`types.ts`) holds:
  - the descriptor and services helpers, which check a provider against itself;
  - the consumer types surfaces and hosts read;
  - the union of model APIs Studio runs;
  - the reference documentation of every value.
- **Models** (`models.ts`) provides `AiModelId`, derived from the index, and `findAiModel`, `getAiModels` and `getDefaultAiModel` over index order.
- **The package's own tests** (`packages/providers/tests/`) check that the index is current, that ids are unique, and that the six existing providers keep today's order.

Changed once outside the package, so that a later provider needs no change there:

- `eslint.config.mjs`:
  - the surface boundary of `@studio/providers` matches any provider folder by pattern;
  - the surface index is one of the package's surface files;
  - the rule against Node APIs exempts the indexer.
- `@studio/common/lib/provider-config.ts` and `@studio/common/lib/remote-sites.ts` store any provider by default. Each keeps an override only where builds of every version read a legacy field.
- `@studio/agent/shared/models.ts`: a stream for each of the four model APIs, and a failed turn for a connection that names any other API.
- `apps/ui` (`data/queries/use-remote-sites.ts`, `data/settings-sections.ts`): a host without native sites offers only WordPress.com for publishing.
- The tests outside the package that list every provider's account: `packages/common/lib/tests/ai-settings.test.ts`, `packages/agent/protocol/sessions/tests/model.test.ts` and `apps/studio/src/modules/user-settings/lib/tests/settings-tracks.test.ts`.
- `packages/providers/README.md` and `docs/design-docs/providers.md`.

Untouched but relevant, because they already build everything from the registry's lists and the descriptors, with the types they use today:

- the settings' provider rows and defaults (`apps/ui/src/features/settings/settings-view/`), with the generic row and the fallback to the descriptor's logo;
- the model picker and model access (`apps/ui/src/features/composer/`);
- `studio code`'s `/connect`, `/disconnect`, `/provider` and `/model` (`apps/cli/ai/slash-commands.ts`, `apps/cli/lib/providers.ts`);
- the resolution of the AI connection and the image generator (`apps/cli/ai/auth.ts`, `apps/cli/ai/host.ts`);
- `studio push` (`apps/cli/commands/push.ts`);
- the Desktop and `studio ui` handlers, which normalize the ids they receive against the lists (`apps/studio/src/**/ipc-handlers.ts`, `apps/local/src/index.ts`);
- Studio on the web's per-id configs and settings (`apps/static/src/agent/index.ts`);
- the `shared.json` schema (`packages/common/lib/shared-config.ts`).

Data flow:

- At development time, the indexer turns the provider folders into the index. The developer commits the index with the folder.
- At build time, every bundler and type checker follows the index's static imports. `apps/ui` reaches only the surface index, so it bundles descriptors only. The hosts reach both.
- Surfaces read the runtime lists and the descriptors: lists, labels, connect forms, models and how sites are presented.
- A host asks the services entry for a provider's services by id. It hands them the config Studio reads from its store, and stores any config they return under the provider's id.
- The CLI, the Desktop main process and `studio ui` publish to any sites provider through `studio push`. Studio on the web publishes only to WordPress.com.
- A turn's model connection passes through the agent's stream, which either runs it over its API or rejects it.

## Decisions

design-doc-decision-1: The package indexes its provider folders into static, generated code, from which every list and type derives

**Serves:** spec-requirement-1, spec-requirement-2, spec-requirement-3, spec-requirement-9, spec-acceptance-criterion-1, spec-acceptance-criterion-2, spec-acceptance-criterion-5, spec-acceptance-criterion-6, spec-acceptance-criterion-10, spec-acceptance-criterion-17
**Decision:**
- A provider folder is a top-level folder of the package that holds a descriptor module or a services module. A complete one holds both, side by side.
- The index is two modules of static imports, committed with the package:
  - the surface index holds every indexed folder's descriptor;
  - the services index holds each of those descriptors paired with its folder's services.

  The surface entry reaches only the surface index, and the services entry only the services index.
- The indexer writes both modules from the folders. It is run from the package's own scripts.
  - It keeps the order of the folders already in the index, appends folders new to it in name order, and drops folders that are gone.
  - When a folder holds only one of its halves, the indexer stops and writes nothing. Its error names the folder and the module the folder lacks.
  - What it writes passes the repository's lint and formatting unchanged.
- The index starts with the six existing providers in today's order: WordPress.com, Anthropic, OpenAI, Google Gemini, GitHub Copilot, Spacefast.
- Everything derives from the index's descriptors, in its order:
  - `PROVIDER_IDS` lists every indexed provider;
  - `AI_PROVIDER_IDS` lists those whose descriptor declares `ai`, and `SITES_PROVIDER_IDS` those that declare `sites`;
  - `ProviderId`, `AiProviderId` and `SitesProviderId` are their literal ids;
  - `ProviderConfigs`, `ProviderSites` and `ProviderSite` map each id to its descriptor's config and site types;
  - `AiModelId` is every indexed model id.

  These exports keep their names, their values for the six providers, and their meaning, so no consumer's types change.
- A new provider goes after the six existing ones. So WordPress.com stays first wherever Studio picks the first connected or ready provider. Through `findAiModel`'s first match, a model id shared with an existing provider keeps resolving to the existing provider's listing. A provider that declares both capabilities is in both lists under one id, so one config serves both.
- `getProvider` and `getProviderServices` keep their signatures and stay synchronous.
- Removed: the hand-written unions, type maps, id lists, descriptor and services maps, and `types.ts`'s imports of each folder's config and site types.

**Alternatives:**
- One hand-written ordered registration of descriptors, with services found by Vite's glob import (lane v1). Not taken:
  - Typecheck cannot see which folders the glob finds. The services of a folder are therefore checked against its descriptor only by a package test that states the parts a second time (v1's design-doc-decision-4). A missing services module shows up as an error thrown at run time.
  - The services entry depends on the bundler's transform in every program that reaches it. That design carries open assumptions on the Desktop main build and on `vite/client` types in every program.
  - Running the indexer and appending an entry take the same effort, so effort decides nothing.
- Both halves discovered by Vite's glob import, the folder's name as the id, and ids as data (lane diverge-1). Not taken:
  - A glob gives typecheck no provider's types. `ProviderId`, `AiProviderId`, `SitesProviderId`, `ProviderConfigs` and `ProviderSites` would become strings and base types. The code outside the package typed with them would change: they appear on 94, 47, 93, 17 and 30 lines.
  - A misspelled literal id, or an AI-only provider passed where a sites provider is required, would no longer fail typecheck.
  - The parts of each folder's services would again need a runtime test that restates them.
  - Renaming a folder would change a stored id.
- Two hand-written registrations, one in each entry. Not taken: every provider would take two edits in two shared files. A forgotten services entry is reported at the shared list's declaration, as `SERVICES` is today (`services.ts(9,7)`), not at the developer's code.
- An index that a check rewrites, so the developer runs nothing. Rejected:
  - A check that rewrites source hides a stale index instead of reporting it, and leaves CI's checkout differing from the commit.
  - The root `npm run typecheck` runs `apps/*` before `packages/*`, so the apps would check against the old index.
- An index written by a Vitest file snapshot and its update flag. Not taken: the flag rewrites every snapshot of the run, and a failure shows a diff rather than the folder and the command.
- An order the indexer computes from a list of the six existing providers (lane diverge-1's rule). Not taken: the index already records the order, and the package tests pin the six.

**Trade-offs:**
- The repository commits no generated source today. The index and the indexer are a new pattern, and the indexer needs Node at development time.
- Adding a provider takes running the indexer. Forgetting it leaves the provider out of every surface, and design-doc-decision-3's checks report it.
- Two branches that each add a provider conflict in the index. Running the indexer again resolves the conflict.
- The derived types require each descriptor to keep its literal id and model ids (design-doc-decision-2), and provider code to reference none of the derived unions (design-doc-assumption-1).

**Claims:**
- observed: the lists, unions and maps a provider is written into today, and `types.ts` importing each folder's config and site types (read `packages/providers/registry.ts:17-84`, `services.ts:9-24`, `models.ts:9-15` and `types.ts:1-45`).
- observed: today's orders. `AI_PROVIDER_IDS` is wpcom, anthropic, openai, gemini and github-copilot. `PROVIDER_IDS` adds spacefast. `SITES_PROVIDER_IDS` is wpcom and spacefast. `findAiModel` returns the first provider that lists an id (read `registry.ts:18-35` and `models.ts:31-41`). The CLI falls back to the first connected provider in that order (spec, `apps/cli/ai/auth.ts:39-48`; the code is unchanged since).
- observed: the closed provider types appear on 94 (`ProviderId`), 47 (`AiProviderId`), 93 (`SitesProviderId`), 17 (`ProviderConfigs`), 30 (`ProviderSites`) and 72 (`AiModelId`) lines outside the package (`.pipelines/providers-api-for-external-devs-v2/2-design-doc/lanes/diverge-2/design-doc/closed-types-and-generated-code.txt`).
- observed: the repository commits no generated TypeScript (same file).
- observed: Node 24 runs a package-local TypeScript script from the package's own scripts, and knip treats such a script as an entry (`.pipelines/providers-api-for-external-devs-v2/2-design-doc/lanes/diverge-2/design-doc/knip-and-indexer-probe.txt`).
- observed: `npm run typecheck` runs the workspaces' scripts, then `scripts/` (read `package.json:59`). npm runs workspace scripts in the order `apps/*`, `tools/*`, `packages/*`, so `packages/providers` comes last (`.pipelines/providers-api-for-external-devs-v2/2-design-doc/lanes/diverge-2/design-doc/closed-types-and-generated-code.txt`).
- observed: a provider missing from today's exhaustive maps is reported at `registry.ts(39,7)`, `registry.ts(65,7)` and `services.ts(9,7)` (`.pipelines/providers-api-for-external-devs/1-spec/spec/probe/1-readme-steps-providers-typecheck.txt`).
- assumed: TypeScript derives the unions and maps from the index without a circular reference; see design-doc-assumption-1.

design-doc-decision-2: A provider is checked against itself, through helpers in its folder and its entry in the index

**Serves:** spec-requirement-3, spec-requirement-1, spec-acceptance-criterion-7, spec-acceptance-criterion-8, spec-acceptance-criterion-9
**Decision:**

The contract offers two authoring helpers.

The descriptor helper infers the following from the provider's own descriptor:
- its literal id;
- its config type, site type and model ids;
- the capabilities it declares;
- the kinds of its connect methods.

Within a descriptor, `ai.defaultModel`, `ai.paidDefaultModel` and `AccountDetails.models` accept only the provider's own model ids.

The services helper takes the folder's descriptor. It requires exactly the parts that descriptor declares:
- `account.connect`, always;
- `account.start`, when a connect method is a `device` or `loopback` sign-in;
- `ai.model`, when the descriptor declares `ai`;
- `sites.list` and `sites.push`, when it declares `sites`;
- `sites.create`, when `sites.newSite` is `create`;
- `sites.pull`, when `sites.pull` is true;
- no `ai` or `sites` part for a capability the descriptor doesn't declare.

`account.refresh`, `account.disconnect`, `ai.generateImages` and `ai.canGenerateImages` stay optional, and image generation stays part of `ai`. The services carry their descriptor's id. Typecheck therefore reports a missing part, or a part for an undeclared capability, in the provider's services module, naming the part.

The index applies the same checks to every folder. Its services index requires each folder's services to hold the parts its paired descriptor declares. Its surface index accepts only descriptors declared through the descriptor helper. Two kinds of folder are therefore reported at the folder's entry in the index, naming the folder's module:
- services written without the helper that lack a part, or hold one for an undeclared capability, with the part named;
- a descriptor declared without the helper, whose id may not be literal. Such an id would otherwise widen every derived union to `string` without any error.

The helpers' types reference no type derived from the index. The consumer types (`Provider`, `ProviderServices`, `AccountDetails` and the rest) keep their names and the meaning of their type parameters. The six existing providers move to the helpers.

**Alternatives:**
- `satisfies` or an annotation with the consumer types on plain objects. Rejected:
  - a provider that loses its literal id widens `ProviderId` to `string` with no error;
  - they cannot tie a default model to the provider's own models, or services to their descriptor.
- Today's descriptor and services capabilities, which are optional independently of each other. Rejected: they let a provider list models with no model connection, which is reported only as "offers no AI models" when a chat starts.
- A package test that checks each provider's services for the parts its descriptor needs (lanes v1 and diverge-1). Not taken: the static index lets typecheck check every folder's services, whether or not they use the helper. A test would state the parts a second time, and report away from the code.
- Image generation as a capability of its own. Not taken: no provider or source shows a service that offers images without chat models.

**Trade-offs:**
- Errors from the helpers' types can be longer than a plain missing-property error (design-doc-assumption-2).
- Services written without the helper are reported at the folder's entry in the index, a generated module, not in the folder's own services module. The report still names the folder's module and the part.

**Claims:**
- observed: the descriptor's and the services' capabilities are optional independently of each other (read `packages/providers/types.ts:173-179,289-320`). A missing model connection shows as "offers no AI models" when a chat starts (spec, `apps/cli/ai/auth.ts:89-91`).
- observed: the providers that connect with a device or loopback sign-in (OpenAI, GitHub Copilot, Spacefast) implement `account.start`, and the form and redirect providers don't (`.pipelines/providers-api-for-external-devs/2-design-doc/design-doc/observations.txt`).
- observed: `defaultModel`, `paidDefaultModel` and `AccountDetails.models` are typed as the global `AiModelId`, and GitHub Copilot casts its plan's models to it (read `types.ts:97,173-178` and `packages/providers/github-copilot/descriptor.ts:26-31`).
- observed: each descriptor and services object is annotated with the consumer types and states its id as a literal (read `packages/providers/*/descriptor.ts` and `*/services.ts`).
- assumed: each omitted or extra part, and a descriptor declared without the helper, is reported at the locations this decision names, naming the part; see design-doc-assumption-2.

design-doc-decision-3: The package's tests and knip report a provider folder that the index misses

**Serves:** spec-requirement-3, spec-requirement-9, spec-acceptance-criterion-9, spec-acceptance-criterion-10, spec-acceptance-criterion-17
**Decision:**

The package's own tests, which `npm test` runs, compare the committed index with what the indexer would write from the folders. They fail in these cases, and name each folder involved:
- a folder missing from the index, or listed in it but gone, with the command that rewrites the index;
- a folder that holds only one of its halves, with the module it lacks;
- two indexed providers with the same id;
- an index that doesn't start with the six existing providers in today's order.

knip reports the modules of a folder the index misses as unused files, at the folder's own files.

A provider that passes these checks and design-doc-decision-2's typecheck meets two conditions:
- it is in every list its declared capabilities reach;
- its services hold every part its descriptor declares.

Adding a provider never changes these tests.

**Alternatives:**
- The indexer's comparison run by the package's typecheck script. Not taken: every workspace's typecheck script is a plain `tsc` run, and the package's other checks of its registry are already in its tests.
- Relying on knip alone. Not taken: its report names the unused file, not the fix.
- No check of the six existing providers' order. Rejected: a hand edit of the index, or a fault in how the indexer keeps order, would reorder fallback and shared-model lookup without any report (spec-requirement-9).

**Trade-offs:** The tests' report appears in `npm test`'s output, not at a line of the developer's file. knip's report names that file.

**Claims:**
- observed: knip reports a file of a provider folder that nothing imports as an unused file (`.pipelines/providers-api-for-external-devs-v2/2-design-doc/lanes/diverge-2/design-doc/knip-and-indexer-probe.txt`).
- observed: `npm test` runs `vitest run` over the projects of `vitest.config.ts`, which include `packages/providers/vitest.config.ts` and its `**/*.test.ts` (read `package.json:62`, `vitest.config.ts:4-20` and `packages/providers/vitest.config.ts`).
- observed: the package's tests may use Node APIs, since the package's boundary rules ignore `packages/providers/**/tests/**` (read `eslint.config.mjs:413-414`).
- observed: every workspace's typecheck script is `tsc -p tsconfig.json --noEmit` (`.pipelines/providers-api-for-external-devs-v2/2-design-doc/lanes/diverge-2/design-doc/closed-types-and-generated-code.txt`).
- assumed: each failure names the folder, the module and what is missing; see design-doc-assumption-4.

design-doc-decision-4: Studio stores any provider's config and remote-site connections in the shared sections by default

**Serves:** spec-requirement-1, spec-requirement-2, spec-requirement-8, spec-acceptance-criterion-2, spec-acceptance-criterion-3, spec-acceptance-criterion-4, spec-acceptance-criterion-5, spec-acceptance-criterion-6, spec-acceptance-criterion-8, spec-acceptance-criterion-16
**Decision:**

The config store resolves any provider to its `providerConfigs.<id>` section. Two providers override that, and their storage doesn't change:
- WordPress.com stays in `authToken`, the Studio sign-in;
- Anthropic keeps an API key in `anthropicApiKey`, with today's fallback to `cli.json`, and its subscription token in `providerConfigs.anthropic`.

The remote-site connection store resolves any sites provider to `remoteSites` entries tagged with its id. Each entry keeps the site as the provider returned it, with Studio's sync times. Only WordPress.com overrides that, with `connectedWpcomSites`. Forgetting a local site's connections covers every provider in `SITES_PROVIDER_IDS`.

The stored-id mapping keeps one exception, Anthropic's `anthropic-api-key`. Every other provider is stored under its id, so `normalizeProviderId` and `toStoredProviderId` behave as today.

The following already work for any id, and don't change:
- renewal, and the forgetting of a config the provider rejects;
- `rememberedSignIns` and `signInHostId`;
- the default hosting provider;
- Studio on the web's per-id configs.

The overrides are Studio's storage, not part of the provider contract. Every write still goes through `shared.json`'s lock, and renewal through its per-provider lock, as today. The exhaustive per-provider store maps are removed.

**Alternatives:**
- A storage field the descriptor declares, such as a legacy field name. Rejected: it puts storage into the provider contract, against "Providers own no storage" (`docs/design-docs/providers.md`, principle 5), and only two providers would ever use it.
- Store maps typed over every provider id that fall back to the default. Rejected: with design-doc-decision-1's closed ids, typecheck in `@studio/common` would demand an entry for every new provider, as it does today.
- Migrating every account into one new format. Rejected: builds from before the change would no longer read what new builds write (spec-requirement-8).

**Trade-offs:** A new provider never gets a storage field of its own, only its section. OpenAI, Google Gemini, GitHub Copilot and Spacefast are stored this way today.
**Claims:**
- observed: the config store map is typed over every `ProviderId`. OpenAI, Google Gemini, GitHub Copilot and Spacefast use the per-id section the default would (read `packages/common/lib/provider-config.ts:64-144`).
- observed: a provider added to the package fails typecheck at that map (`.pipelines/providers-api-for-external-devs/1-spec/spec/probe/2-registered-repo-typecheck.txt`).
- observed: the connection store map is typed over every `SitesProviderId`. Spacefast's entry is the generic store, which keeps the site as given (read `packages/common/lib/remote-sites.ts:69-133`).
- observed: every stored id equals the provider's id except Anthropic's (read `packages/providers/registry.ts:62-84`).
- observed: in `shared.json`, `providerConfigs`, `rememberedSignIns` and `remoteSites` are keyed by plain strings, and `aiProvider` is a plain string. An unknown `defaultHostingProvider` reads back as no preference (`.pipelines/providers-api-for-external-devs-v2/2-design-doc/lanes/v1/design-doc.md`, design-doc-decision-5, from `packages/common/lib/shared-config.ts:54-84` and `user-preferences.ts:191-195`; the code is unchanged since).

design-doc-decision-5: The package's lint boundary matches provider folders by pattern, and exempts only the indexer from the rule against Node APIs

**Serves:** spec-requirement-7, spec-requirement-1, spec-acceptance-criterion-15
**Decision:** In `eslint.config.mjs`, the surface boundary of `@studio/providers` matches any provider folder by pattern, not by a list of names. Its restricted zone covers the package. Its exceptions are:
- the package's shared surface files, the surface index among them;
- any folder's `descriptor.ts` and `config.ts`;
- WordPress.com's `sites/site.ts`.

The part of a provider that surfaces read is therefore its descriptor and config. With nothing outside the package changed, ESLint:
- reports, at the import, a surface file of any folder that imports anything else;
- lets a folder's descriptor import its own config.

The rules against Node APIs and other workspace packages keep covering every file of the package. The one exception is the indexer, which reads the folders in Node at development time and which no entry imports. Each report lands in the provider's own file, which ESLint on the changed files covers.
**Alternatives:**
- Generating the folder list from the file system in `eslint.config.mjs`, as the config already does for `apps/ui`'s layers. Rejected: the rule takes glob exceptions directly, and a pattern doesn't depend on which folders exist when lint starts.
- Writing the indexer in plain JavaScript so the TypeScript-only rule doesn't reach it. Not taken: it would be the package's one untyped module, and it would escape the rule by its file extension rather than by an exemption the config states.
- A package test that checks each provider file's imports. Not taken: ESLint's existing rules already report each crossing at the import that crosses it.

**Trade-offs:** A provider's descriptor may import another provider's descriptor or config, as the six may today. A descriptor that imports a data module of its own folder other than its config is reported, so the README tells a developer to keep what surfaces read in those two files.
**Claims:**
- observed: the boundary's exceptions list the six folders by name (read `eslint.config.mjs:33-45,433-457`).
- observed: `import-x/no-restricted-paths` accepts glob exceptions when the zone's `from` is a glob, and matches them against the imported file's absolute path (eslint-plugin-import-x 4.17.1, `.pipelines/providers-api-for-external-devs/2-design-doc/design-doc/lint-restricted-paths.txt`).
- observed: the rules against Node APIs and workspace packages match `packages/providers/**/*.ts` and ignore only `tests/` (read `eslint.config.mjs:410-431`). A package script that imports `node:fs` is reported by them (`.pipelines/providers-api-for-external-devs-v2/2-design-doc/lanes/diverge-2/design-doc/knip-and-indexer-probe.txt`).
- observed: every descriptor imports only its own config, the package's shared surface files and npm packages. WordPress.com's also imports `wpcom/sites/site.ts` (read `packages/providers/*/descriptor.ts`).

design-doc-decision-6: The contract names the four model APIs, and the agent runs exactly those

**Serves:** spec-requirement-6, spec-acceptance-criterion-3, spec-acceptance-criterion-4, spec-acceptance-criterion-13, spec-acceptance-criterion-14
**Decision:** The contract defines the model APIs Studio runs as a union: `openai-completions`, `openai-responses`, `anthropic-messages` and `google-generative-ai`. `AiConnection.model` is typed to that union. A provider whose connection names any other API therefore fails typecheck in its folder, with the API named.

In `@studio/agent/shared/models.ts`, the connection stream has one stream for each API in the union, and the agent fails typecheck if the union gains an API without one. A connection that names an API outside the union, such as one cast past the types, ends the turn with an error that names the API, and no request is sent. The Node runtime and the browser agent both stream through this code. GitHub Copilot reads its models from pi's catalog under pi's wider `Api` type, so it narrows them to the union in its own folder.
**Alternatives:**
- Keeping the `openai-responses` fallback, with only the narrowed type. Rejected: spec-requirement-6 forbids sending a request over a different API.
- A runtime check only, with no narrowed type. Rejected: nothing reports the API until a user chats.
- A check in each host that resolves a connection (`apps/cli/ai/auth.ts`, `apps/static/src/agent/index.ts`, the eval harness). Rejected: every turn already passes through the one stream, which covers them all.

**Trade-offs:** Adding a fifth API is Studio's decision: it changes the union and the agent together (spec-exclusion-3).
**Claims:**
- observed: `openai-completions`, `anthropic-messages` and `google-generative-ai` get their own stream, and any other API goes to `openai-responses` (read `packages/agent/shared/models.ts:17-29`).
- observed: every existing connection names one of the four APIs (pi 1.5.0's catalogs and the WordPress.com tiers, `.pipelines/providers-api-for-external-devs/2-design-doc/design-doc/model-apis.txt`).
- observed: GitHub Copilot's connection takes its model from pi's catalog, typed `Model< Api >` (read `packages/providers/github-copilot/ai.ts:36-56`).
- observed: both runtimes stream through `createConnectionStream` (`.pipelines/providers-api-for-external-devs-v2/2-design-doc/lanes/diverge-1/design-doc.md`, design-doc-decision-7, from `packages/agent/node/runtime/index.ts:336-343` and `packages/agent/browser/models.ts:17-26`; the code is unchanged since).
- assumed: an error the stream raises before any request reaches the user as the chat's error in both runtimes; see design-doc-assumption-3.

design-doc-decision-7: A host without native sites offers only WordPress.com for publishing

**Serves:** spec-requirement-2, spec-requirement-9, spec-acceptance-criterion-5, spec-acceptance-criterion-17
**Decision:** The providers `apps/ui` offers for publishing depend on the host:
- where the connector has native sites (the Desktop app and `studio ui`), every provider in `SITES_PROVIDER_IDS`, which publish through `studio push`;
- elsewhere (Studio on the web), only WordPress.com, which publishes there through its own sync.

This rule drives the Settings hosting rows, the Default hosting provider select, the publish tab and the command palette's hosting entries. It replaces today's check for static exports, which it covers, since a static export needs native PHP. Studio on the web therefore offers the same publish providers as today. A new archive provider never appears there as a control its connector would reject.
**Alternatives:**
- A new connector capability that names the hosting providers a host publishes to. Rejected: it would carry the same information as `nativeSites` in all three connectors.
- Having Studio on the web publish to new archive providers in the page. Not taken: spec-requirement-2's bullet for the web names account, model and image services, and spec-acceptance-criterion-5 names the Desktop app and `studio ui`.

**Trade-offs:** An archive provider whose API accepts calls from a page, which the web could in principle publish to, stays hidden there.
**Claims:**
- observed: today the web offers any sites provider whose content isn't a static export (read `apps/ui/src/data/queries/use-remote-sites.ts:24-31`). Its connection state reads `accounts[ id ]` from the AI settings (read `use-remote-sites.ts:34-52`), which on the web hold AI providers' accounts only (read `apps/static/src/agent/index.ts:262-282`).
- observed: Studio on the web's remote-site methods throw `UnsupportedError` for any provider but WordPress.com (read `apps/ui/src/data/core/connectors/static/index.ts:87-92`).
- observed: off native hosts, the palette hides hosting entries only for providers that publish static exports (read `apps/ui/src/data/settings-sections.ts:321-333`).
- observed: the Desktop app and `studio ui` publish by running `studio push` (lane v1's design-doc-decision-8, from `packages/common/sites/sync.ts:56-79`; the code is unchanged since).

design-doc-decision-8: Tests outside the package hold for any set of providers

**Serves:** spec-requirement-1, spec-acceptance-criterion-1, spec-acceptance-criterion-2, spec-acceptance-criterion-17
**Decision:** The tests outside `@studio/providers` that build or compare an `AiSettings` do two things:
- they build its accounts from the registry's lists;
- they assert only on the providers they exercise.

These are `packages/common/lib/tests/ai-settings.test.ts`, `packages/agent/protocol/sessions/tests/model.test.ts` and `apps/studio/src/modules/user-settings/lib/tests/settings-tracks.test.ts`. An indexed provider then adds an account that those tests treat as not connected, and changes none of them. Tests that mock a few providers' services by id already don't list every provider.
**Alternatives:** Making `AiSettings.accounts` partial, so that a missing account means not connected. Rejected: every consumer that reads `accounts[ id ].connected` would change, for a fix that belongs in the tests.
**Trade-offs:** A later test outside the package that writes out every provider's account fails typecheck when a provider is added. See Risks.
**Claims:**
- observed: with a sample provider registered, typecheck failed at the account literals of `model.test.ts` and `settings-tracks.test.ts` (`.pipelines/providers-api-for-external-devs/1-spec/spec/probe/2-registered-repo-typecheck.txt`, and read `packages/agent/protocol/sessions/tests/model.test.ts:5-21`).
- observed: once the sample provider was listed, four tests failed in `ai-settings.test.ts` and `model.test.ts` on their full accounts (`.pipelines/providers-api-for-external-devs/1-spec/spec/probe/3-listed-tests.txt`).

design-doc-decision-9: The contract documents every value, and only WordPress.com may declare the Studio sign-in

**Serves:** spec-requirement-5, spec-requirement-3, spec-acceptance-criterion-12
**Decision:** Every field, method, parameter and result of the contract carries documentation that states:
- what the value means;
- whether a new provider supplies it or acts on it;
- what Studio does with it.

This covers `types.ts`, `errors.ts` and the helpers of design-doc-decision-2. `AiConnection.piProvider` says how pi uses the name. The descriptor's `id` says that Studio stores it, so it never changes.

The `redirect` connect method, the Studio sign-in, is unavailable to a new provider. The descriptor helper rejects a `redirect` method in any descriptor whose id isn't WordPress.com's, naming the kind, in that descriptor. The consumer-facing `ConnectMethod` keeps the kind, so surfaces read WordPress.com's sign-in as today.

The other parts that work for one provider only stay available. Their documentation says they belong to WordPress.com, and what a new provider does with them:
- `requiresPaidAiCredits` and `paidDefaultModel` follow the WordPress.com account's paid credits;
- `push`'s options use the selection format WordPress.com sync defined. A provider without selective sync receives the whole site, and one with it receives what the user picked;
- `list`'s `planRequired` option;
- the `pull` steps, which are remote backups and a Reprint exporter;
- `sites.newSite: 'checkout'`, which is WordPress.com's checkout;
- `hasBackups`.

**Alternatives:**
- Documenting `redirect` as WordPress.com's and leaving it available. Rejected: a new provider that declared one would pass every check. Settings would then drop the method and hide the provider when it has no other, and `studio code`'s `/connect` would run the WordPress.com login. The provider would be left out of a surface, against spec-requirement-3.
- A package test that rejects `redirect` outside WordPress.com's folder (lane diverge-1). Not taken: the helper sees the literal id, so typecheck reports in the descriptor itself.
- Removing every WordPress.com-only part from the contract a new provider sees, and typing WordPress.com through a wider internal contract. Rejected:
  - these are WordPress.com behaviors Studio keeps (spec-exclusion-6), and consumers read them through the shared types;
  - it would add a second descriptor type for one provider;
  - spec-requirement-5 accepts documenting them.

**Trade-offs:** A new provider can still set the documented WordPress.com-only values, against their documentation.
**Claims:**
- observed: the CLI connects any `redirect` method by running the WordPress.com login, and disconnects it by signing out of Studio (spec, `apps/cli/lib/providers.ts:144-145` and `apps/cli/ai/slash-commands.ts:323-327`).
- observed: Settings drop `redirect` methods, and hide a provider left with no other method (spec, `apps/ui/src/features/settings/settings-view/ai-panel.tsx:28-33` and `providers-panel.tsx:187-192`).
- observed: only WordPress.com declares a `redirect` method (read `packages/providers/*/descriptor.ts`).
- observed: `requiresPaidAiCredits` locks a model on WordPress.com's quota (spec, `apps/ui/src/features/composer/use-model-access.ts:31-43`).
- observed: the push options, `planRequired` and the pull steps are typed in `packages/providers/types.ts:237-286`, with the options from `wpcom/sites/site.ts` (read).
- assumed: the helper's rejection names the kind in the descriptor; see design-doc-assumption-2.

design-doc-decision-10: The package README is the complete guide to adding a provider

**Serves:** spec-requirement-4, spec-acceptance-criterion-1, spec-acceptance-criterion-2, spec-acceptance-criterion-11
**Decision:** The section of `packages/providers/README.md` on adding a provider covers:
- every change a developer makes, all of them inside the package: the provider's folder, then running the indexer and committing the index it writes;
- for each capability, the parts a provider fills in, as design-doc-decision-2 requires them;
- the connect methods a new provider can use (`form`, `device`, `loopback`), and the apps that offer each: Studio on the web offers forms only;
- the four model APIs;
- which declared values Studio stores, and that they never change: the provider id, model ids and connect-method ids;
- that a provider's code runs in Node and in the page, and that what surfaces read of it stays in its descriptor and config;
- how to test a provider: its own `tests/`, the package tests that check the index, and `npm test -- packages/providers`.

`docs/design-docs/providers.md` states the same architecture: the index and the indexer, the checks, default storage and the four APIs. The README points to the contract's reference documentation (design-doc-decision-9) instead of repeating it.
**Alternatives:** A generator that creates a new provider's files. Not taken: the spec's "Considered and not required" leaves it out, and documentation alone meets spec-requirement-4. The indexer writes only the index, never a provider's own files.
**Trade-offs:** The README and the contract can drift. The README states the rules, and the contract documents the values.
**Claims:** observed: today's steps name edits to `types.ts`, `registry.ts`, `services.ts`, `provider-config.ts` and `remote-sites.ts` (read `packages/providers/README.md:57-59`). They leave out `AiProviderId`, the id lists, `STORED_PROVIDER_IDS`, `AiModelId`, the lint folder list and the agent (`.pipelines/providers-api-for-external-devs/1-spec/spec/probe/README.md`).

## Interfaces

**A provider's folder (`packages/providers/<folder>/`)**
- A provider folder is a top-level folder of the package that holds a descriptor module or a services module. A complete one holds both.
- `config.ts`: the zod schema of what Studio stores for the provider.
- The descriptor module exports the provider's descriptor under the name the contract fixes for every folder, declared through the descriptor helper. The descriptor holds:
  - its literal id, which Studio stores, and its label, description, learn-more URL, icon and logo;
  - `account`: the config schema, connect methods of kind `form`, `device` or `loopback` with stable ids, `describe`, and optionally `expiresAt` and `remember`;
  - optionally, `ai`: models with stable ids, and the default model;
  - optionally, `sites`: presentation and behavior flags.
- The services module exports the provider's services under the name the contract fixes for every folder, declared through the services helper with the folder's descriptor. Their required parts follow design-doc-decision-2.
- Model connections are `AiConnection`s, with `model.api` one of `openai-completions`, `openai-responses`, `anthropic-messages` and `google-generative-ai`.
- Imports: the descriptor and config import only each other and the package's shared surface files. The services may also import the folder's other modules, the package's shared modules and its npm dependencies.

**The index and the indexer**
- The surface index lists every indexed folder's descriptor, in index order. The services index lists, in the same order, each descriptor paired with its folder's services. Both are committed, and only the indexer writes them.
- The indexer runs as a script of the package (`npm -w @studio/providers run <script>`):
  - it rewrites both index modules from the provider folders;
  - it keeps the existing order, appends new folders in name order, and drops folders that are gone;
  - it exits with an error, writing nothing, when a folder holds only one half, naming the folder and the module it lacks;
  - its output passes ESLint and the repository's formatting as written.

**The surface entry (`@studio/providers`)**
- Unchanged in name and meaning:
  - lists: `PROVIDER_IDS`, `AI_PROVIDER_IDS`, `SITES_PROVIDER_IDS`, in index order;
  - the default, `DEFAULT_PROVIDER_ID` (`wpcom`);
  - functions: `getProvider( id )`, `getProviderSites( id )`, `normalizeProviderId( value, ids? )`, `toStoredProviderId( id )`, `formatRemoteSite`, `parseRemoteSite`, `findAiModel( id )`, `getAiModels( provider, account? )` and `getDefaultAiModel( provider, options? )`;
  - types: `ProviderId`, `AiProviderId`, `SitesProviderId`, `ProviderConfigs`, `ProviderSites`, `ProviderSite` and `AiModelId`, now derived from the index, and the consumer types `Provider`, `ProviderServices`, `AccountDetails`, `ConnectMethod`, `AiConnection` and the rest.
- New: the descriptor and services helpers, and the union of model APIs Studio runs.

**The services entry (`@studio/providers/services`)**: `getProviderServices( id )` returns `ProviderServices< ProviderConfigs[ Id ], ProviderSite< Id > >` synchronously: the services of the indexed folder whose descriptor has that id. `createTusUpload` stays.

**The package's checks**
- `npm run typecheck` fails at the developer's folder in these cases, naming the part or the API:
  - a missing services part;
  - a part for an undeclared capability;
  - a default model that isn't the provider's own;
  - a `redirect` method outside WordPress.com;
  - a connection whose API is outside the four.

  It fails at the folder's entry in the index when the services or the descriptor skip the helpers.
- `npm test` fails in these cases, naming the folders involved:
  - an index that differs from the folders, with the command that rewrites it;
  - a folder with one half;
  - duplicate ids;
  - an index that doesn't start with the six existing providers in today's order.
- `npm run knip` reports the modules of a folder the index misses as unused files.

**Studio's storage (`@studio/common`)**
- `readProviderConfig`, `writeProviderConfig`, `readFreshProviderConfig`, `forgetRejectedConfig` and `readSignInContext` take any `ProviderId`. They store under `providerConfigs.<id>`, except WordPress.com (`authToken`) and Anthropic's API key (`anthropicApiKey`).
- `getRemoteSites`, `rememberRemoteSite` and `forgetRemoteSite` take any `SitesProviderId`. They store in `remoteSites`, except WordPress.com (`connectedWpcomSites`). `forgetRemoteSites( localSiteId )` covers every sites provider.

**The agent's stream (`@studio/agent/shared/models.ts`)**: `createConnectionStream( ai )` streams a connection whose API is one of the four. For any other API, it ends the turn with an error that names the API and sends no request.

**`apps/ui`**: `usePublishProviders()` returns every id in `SITES_PROVIDER_IDS` when `capabilities.nativeSites` is true, and only `'wpcom'` otherwise. Where sites aren't native, the palette hides every hosting entry except WordPress.com's.

**Contracts narrowed by the change**
- `AiConnection.model.api` is limited to the four APIs:
  - among providers, GitHub Copilot narrows its catalog models;
  - among consumers, the two agent runtimes already handle only these.
- A descriptor's `defaultModel`, `paidDefaultModel` and `AccountDetails.models` accept only the provider's own model ids. WordPress.com and GitHub Copilot already conform at run time.
- A provider folder exports its descriptor and services under the contract's names, through the helpers, with a literal id. Its services hold every part its descriptor needs, and none for a capability it doesn't declare. The six providers move to that.
- A `redirect` connect method is accepted only in WordPress.com's descriptor, which is the only one that declares one today.
- Publishing on Studio on the web is limited to WordPress.com, the same set as today for the six providers.

**Contracts widened by the change, and what each consumer newly admits**
- `ProviderId`, `AiProviderId` and `SitesProviderId` admit any indexed provider's id. Each consumer newly admits it as follows:
  - `shared.json` as a `providerConfigs`, `rememberedSignIns` and `remoteSites[].provider` key or value, and in `aiProvider`;
  - session entries record it;
  - the user preferences admit it as `defaultHostingProvider`;
  - Tracks admits it as a `sync_type` value;
  - `studio push --remote-site` admits it as a prefix;
  - Settings, the model picker and `studio code` render it through the generic provider row, the descriptor's logo and its connect methods;
  - older builds read such an id as unknown: `normalizeProviderId` returns undefined, and they fall back to the saved selection or WordPress.com, as for any unknown id today.
- `AiModelId` admits any indexed model id, which session entries record. An older build drops a recorded model it doesn't know, and falls back to the provider's default.

## Dependencies

- Node, at development time, runs the indexer as a TypeScript script. The repository requires Node 24 or later (`package.json` `devEngines`), and the probe ran it on 24.22.2. No build runs the indexer. The package's tests only compare the committed index with what it would write.
- knip already treats a script that the package's own scripts run as an entry, and follows the index's static imports.
- `eslint-plugin-import-x`'s `no-restricted-paths` with glob exceptions (4.17.1, already installed).
- `@earendil-works/pi-ai`'s `Model` type (1.5.0, already a dependency), narrowed to the four APIs.
- No new npm dependency, and no use of Vite's glob import. The bundle scripts don't change: the SDKs of the four APIs already ship, and the Mistral and AWS SDKs stay stripped.

## Failure modes and observability

- **A provider folder that isn't indexed:** knip reports its modules as unused files. `npm test` fails, naming the folder and the command that rewrites the index. At run time the provider is in no surface.
- **A folder that holds only one half:** the indexer stops, naming the folder and the module it lacks, and writes nothing. `npm test` reports the same. If an index is edited by hand to import a module that is missing, typecheck fails at that import.
- **Services missing a part their descriptor declares, or holding one it doesn't:** a typecheck error in the folder's services module, naming the part. When the services skip the helper, the error is at the folder's entry in the index.
- **A descriptor declared without the helper, or with an id that isn't literal:** a typecheck error at the folder's entry in the index.
- **A default model that isn't one of the provider's own, or a `redirect` method outside WordPress.com:** a typecheck error in its descriptor.
- **A connection that names an API Studio doesn't run:** a typecheck error in the folder, naming the API. If the API is cast past the types, the chat's turn ends with an error that names it, and nothing is sent.
- **A surface file that imports beyond the boundary, or code that imports a Node API or another workspace package:** an ESLint error at the import, in the offending file of the folder.
- **Two providers with the same id, or the six existing providers reordered or dropped from the head of the index:** `npm test` fails, naming the folders.
- **Two branches that each add a provider:** git reports a conflict in the index. Running the indexer resolves it. A hand resolution that drops a folder is reported as an index that misses it.
- **A stored config that no longer parses, or has expired:** read as not connected (unchanged).
- **A config the provider rejects:** forgotten in the Desktop app, `studio ui` and the CLI, keeping what the provider's `remember` returns (unchanged).

## Verification

- new test at the package's types (checked by `npm run typecheck`) — design-doc-decision-1 — the derived `ProviderId`, `AiProviderId`, `SitesProviderId`, `ProviderConfigs`, `ProviderSites` and `AiModelId` equal today's for the six providers. Each provider's config and site types reach consumers unchanged.
- new test at the package's types (checked by `npm run typecheck`) — design-doc-decision-2, design-doc-decision-9, spec-acceptance-criterion-7, spec-acceptance-criterion-9, spec-acceptance-criterion-12 — typecheck rejects the following, naming the part or the kind:
  - services that lack a part their descriptor's capabilities or connect methods require (the model connection, list and push, create, pull, start);
  - services that declare a capability their descriptor doesn't;
  - a default model, paid default model or account model list outside the provider's own models;
  - a `redirect` method in a descriptor other than WordPress.com's;
  - an index entry whose services or descriptor skip the helpers.
- new test at the package's types (checked by `npm run typecheck`) — design-doc-decision-6, spec-acceptance-criterion-14 — a connection whose API is outside the four fails typecheck, naming the API.
- new test at the package's registry boundary (`packages/providers/tests`) — design-doc-decision-1, design-doc-decision-3, spec-acceptance-criterion-10, spec-acceptance-criterion-17 — it checks that:
  - the committed index equals what the indexer writes from the folders;
  - the six existing providers lead it in today's order;
  - the derived lists equal today's for them;
  - ids are unique;
  - every model id GitHub Copilot shares resolves through `findAiModel` to the existing provider that lists it.
- end-to-end flow — design-doc-decision-1, design-doc-decision-2, design-doc-decision-3, spec-acceptance-criterion-9 — a provider part-way through being written fails the checks in each case of design-doc-decision-2 and design-doc-decision-3. Each report names the folder, the module, and the missing part or the command that rewrites the index.
- existing test `packages/providers/tests/providers.test.ts` › "reads the id builds before `anthropic` stored, and keeps writing it" — design-doc-decision-4, spec-acceptance-criterion-16 — the stored-id exception, and every other id stored as itself.
- existing tests in `packages/common/lib/tests/ai-settings.test.ts` — design-doc-decision-4, spec-acceptance-criterion-16 — configs stay where builds of every version read them:
  - "stores an accepted key where every build reads it, and makes it the default without another";
  - "keeps a subscription token in its own section, and clears the other method on write";
  - "replaces a ChatGPT sign-in with an OpenAI API key", for the default per-id section;
  - "keeps the WordPress.com config in the Studio sign-in, and revokes it on disconnect";
  - "reads legacy values from cli.json and migrates them on write";
  - "selects only a connected provider, storing the id older builds read";
  - "treats an unknown stored provider as the default".
- existing tests in `packages/common/lib/tests/ai-settings.test.ts` › "disconnects a provider whose config expired or that the provider rejects" and "stores a renewed config, and forgets one the provider no longer accepts but its client" — design-doc-decision-4, spec-acceptance-criterion-8 — renewal and rejection run through the default store a new provider uses.
- existing tests in `packages/common/lib/tests/remote-sites.test.ts` › "keeps the Spaces a site publishes to, and forgets them with the site" and "records each sync and keeps the times of the others" — design-doc-decision-4, spec-acceptance-criterion-16 — connections stay in `connectedWpcomSites` for WordPress.com and in `remoteSites` for the others, and are forgotten with the local site.
- new test at `@studio/agent/shared/models` (`createConnectionStream`) — design-doc-decision-6, spec-acceptance-criterion-14 — a connection that names an API outside the four ends with an error that names the API, and no request goes out.
- existing tests `packages/agent/browser/tests/gemini-stream.test.ts` › "streams a Gemini reply through Google’s SDK with the connected key" and `packages/agent/node/runtime/tests/pi-runtime.test.ts` › "streams with the connection’s upstream model and error rewrite" — design-doc-decision-6, spec-acceptance-criterion-13 — connections over the supported APIs still stream in both runtimes.
- existing test `apps/ui/src/features/composer/chat-model-picker.test.tsx` › "offers only the models the connected account can run" — design-doc-decision-2, spec-acceptance-criterion-8 — the picker narrows to the account's models from what the descriptor and the account declare.
- existing test `packages/agent/protocol/sessions/tests/model.test.ts` › "runs on the selected provider, or the first connected one, WordPress.com first" — design-doc-decision-1, design-doc-decision-8, spec-acceptance-criterion-17 — fallback keeps WordPress.com first, with accounts built from the registry's lists.
- existing test suites of `packages/common`, `packages/agent`, `apps/cli`, `apps/studio` and `apps/ui` (`npm test`), with the three test files of design-doc-decision-8 building accounts from the lists — design-doc-decision-8, spec-acceptance-criterion-17 — the six providers behave as before in connecting, selection, fallback, models, images and publishing.
- end-to-end flow — design-doc-decision-1, design-doc-decision-5, design-doc-decision-8, design-doc-decision-10, spec-acceptance-criterion-1, spec-acceptance-criterion-2, spec-acceptance-criterion-11 — two new providers are each added by following only the README, as one folder plus the index the indexer writes: a chat provider (API key form, one of the four APIs) and a sites provider (device sign-in). No other file changes, inside or outside the package. `npm run typecheck`, ESLint on the changed files, `npm run knip` and `npm test` pass.
- end-to-end flow — design-doc-decision-5, spec-acceptance-criterion-15 — with nothing outside the package changed, ESLint on a new provider's files reports each of the following at the import, and reports nothing for a provider within the boundaries:
  - a descriptor or config that imports its services;
  - a Node API import;
  - an import of another workspace package.
- end-to-end flow in `studio ui`, Studio on the web and the Desktop app — design-doc-decision-1, design-doc-decision-4, design-doc-decision-6, spec-acceptance-criterion-3, spec-acceptance-criterion-13 — the new chat provider meets each point of spec-acceptance-criterion-3 in each app, and its replies stream over its API.
- end-to-end flow in `studio code` — design-doc-decision-1, design-doc-decision-4, spec-acceptance-criterion-4 — the new chat provider meets each point of spec-acceptance-criterion-4.
- end-to-end flow in the settings and publish panel of `studio ui` and the Desktop app, and `studio push --remote-site <id>` — design-doc-decision-1, design-doc-decision-4, spec-acceptance-criterion-5, spec-acceptance-criterion-6 — the new sites provider, and a provider that offers both capabilities connected once, appear and publish as the criteria say.
- end-to-end flow in Studio on the web — design-doc-decision-7 — with a new archive-publishing provider in the package, the publish tab, Settings' hosting providers and the palette offer only WordPress.com, as before.
- end-to-end flow — design-doc-decision-2, spec-acceptance-criterion-7, spec-acceptance-criterion-8 — providers that declare each connect method, and each account and model feature the criteria list, behave as declared in Settings, the chat model picker, `/model` and a chat.
- end-to-end flow — design-doc-decision-4, spec-acceptance-criterion-16 — builds from before and after the change each read what the other stored. They show the same accounts, defaults, connections and pins, as spec-acceptance-criterion-16 states.
- inspection — design-doc-decision-9, spec-acceptance-criterion-12 — every value of the contract states its meaning, whether a new provider supplies it or acts on it, and what Studio does with it, and each WordPress.com-only part says so.
- inspection — design-doc-decision-10, spec-acceptance-criterion-11 — the README covers each point the criterion lists, in agreement with the contract.

## Risks

- **Code written later outside the package that is typed exhaustively over a closed provider id**, such as a literal `Record< ProviderId, … >`, fails typecheck when a provider is indexed, against spec-requirement-1. After design-doc-decision-4 and design-doc-decision-8, no such code remains. No check prevents someone from writing it again, and the typecheck failure points at the code that does.
- **A forgotten indexer run** leaves the provider out of every surface until `npm test` or knip reports it. Both are among the checks spec-requirement-1 names, and CI runs them.
- **A provider that offers both chat models and remote sites** gets two palette entries with the same settings target, and its hosting entry lands on its AI provider row. It is the same provider and connection, so spec-acceptance-criterion-6 still holds.
- **On Studio on the web, a form-connected provider whose credential expires** is not renewed in the page, which reads stored configs without a refresh, as today. It shows as disconnected once the credential expires. A config the provider rejects stays stored there, as it does today for the six providers. Only OpenAI's ChatGPT sign-in and GitHub Copilot renew a credential today, and the web offers neither (`.pipelines/providers-api-for-external-devs/2-design-doc/design-doc/observations.txt`).
- **A form-connected provider whose API rejects calls from a page** is still offered on Studio on the web, and fails there when connecting or chatting. No source shows such a provider (spec, "Considered and not required").
- **A service that offers image generation without chat models** can't be added as a provider without declaring models (design-doc-decision-2). No provider or source shows one.
- **Errors from the helpers' types and the index's checks** may be longer than a plain missing-property error (design-doc-assumption-2).

## Open assumptions

design-doc-assumption-1: TypeScript derives the id unions, type maps and `AiModelId` from the index's descriptors without a circular reference. This holds as long as provider code references only the contract and its own folder, and the helpers' types reference nothing derived from the index — assumed: `npm run typecheck` passes with the index as the only source of those types, and the type test of design-doc-decision-1 holds.

design-doc-assumption-2: Typecheck reports the cases of design-doc-decision-2 and design-doc-decision-9 at the locations those decisions name, naming the part or the kind:
- a missing or extra services part in the folder's services module;
- a `redirect` method or a foreign default model in the descriptor;
- services or a descriptor that skip the helpers at the folder's entry in the index.

Assumed: the type tests of design-doc-decision-2 and the end-to-end flow with a provider part-way through being written show those errors at those locations.

design-doc-assumption-3: An error the connection stream raises before any request reaches the user as the chat's error, in both the Node runtime and the browser agent — assumed: the new `createConnectionStream` test, and chats in `studio code` and in Studio on the web on a connection that names another API, show the error naming the API.

design-doc-assumption-4: The package's tests report each case of design-doc-decision-3 with a message that names the folder, the module and what is missing, or the command that rewrites the index — assumed: the end-to-end flow with a provider part-way through being written shows each report.
