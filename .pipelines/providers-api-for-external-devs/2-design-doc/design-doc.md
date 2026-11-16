# Design Doc: Add a provider to @studio/providers from its own folder

## Overview

Today a provider exists in Studio only once it is written into hand-maintained lists. Inside `@studio/providers` these are the id unions (`ProviderId`, `AiProviderId`), the type maps (`ProviderConfigs`, `ProviderSites`), the model-id union (`AiModelId`), and the id lists and maps (`AI_PROVIDER_IDS`, `SITES_PROVIDER_IDS`, `PROVIDER_IDS`, `PROVIDERS`, `STORED_PROVIDER_IDS`, `SERVICES`). Outside the package they are Studio's per-provider config and connection stores in `@studio/common`, the folder list of the lint boundary, and tests that list every provider's account. Some of these lists still typecheck when a provider is missing from them, and a provider left out of them appears in no surface. The contract also mixes in parts that only WordPress.com uses, without saying so. Separately, the agent sends any model API it doesn't recognize as `openai-responses`.

After the change, a provider is its folder plus one entry appended to an ordered registration in `registry.ts`. Every provider list and id union derives from that registration, in its order. The services entry finds each folder's services by the folder's layout, so it needs no list of its own. A provider's contract is written in terms of its own id, config, site and model ids, and its services are checked against its own descriptor. Typecheck reports a missing part in the provider's folder. ESLint reports a folder that isn't registered, or that is registered without checked services. Studio stores any provider's config and remote-site connections in the shared sections by default, and only the first providers keep their legacy fields. The lint boundary matches provider folders by pattern. The agent runs exactly the four model APIs the contract names and rejects any other by name. Studio on the web offers only the hosting providers it can publish to. The contract documents every value. Only WordPress.com may declare the Studio sign-in's connect method. The package README is the complete guide to adding a provider.

## Architecture

New or reshaped inside `@studio/providers`:

- **A provider's folder** (`packages/providers/<folder>/`) holds:
  - its config schema (`config.ts`);
  - its descriptor (`descriptor.ts`), the browser-safe data surfaces read;
  - its services (`services.ts`), which hosts run;
  - its own modules and its `tests/`.

  The descriptor and config import only each other and the package's shared surface files. Neither half imports another workspace package or a Node API. A provider never reads or writes storage.
- **The registration** (`registry.ts`) is the one ordered list of every provider's descriptor: existing providers first in today's order, new ones appended. The id lists (`PROVIDER_IDS`, `AI_PROVIDER_IDS`, `SITES_PROVIDER_IDS`) come from it, and so do the types `ProviderId`, `AiProviderId`, `SitesProviderId`, `ProviderConfigs`, `ProviderSites` and `ProviderSite`. It also provides `getProvider` and `getProviderSites`, and keeps the stored-id exceptions, which hold Anthropic's legacy id only.
- **The contract** (`types.ts`) holds:
  - the descriptor and services shapes, expressed in a provider's own id, config, site and model ids;
  - the two authoring helpers: one declares a descriptor, and one declares services checked against that descriptor;
  - the union of model APIs Studio runs;
  - the reference documentation of every value.
- **Models** (`models.ts`): `AiModelId` derived from the registered descriptors' models, and `findAiModel`, `getAiModels` and `getDefaultAiModel` with today's behavior.
- **The services entry** (`services.ts`): `getProviderServices( id )`, built from every folder's `services.ts`, which it finds by the folder's layout.
- **The package's own tests** (`packages/providers/tests/`): registry-wide checks that hold for any set of providers.

Changed once outside the package, so that a later provider needs no change there:

- `tools/eslint-plugin-studio`: a rule that checks every provider folder against the registration, enabled for `@studio/providers` in `eslint.config.mjs`.
- `eslint.config.mjs`: the surface boundary of `@studio/providers` matches any provider folder by pattern.
- `@studio/common/lib/provider-config.ts` and `@studio/common/lib/remote-sites.ts`: a default store for any provider, with overrides only where builds of every version read a legacy field.
- `@studio/agent/shared/models.ts`: a stream for each of the four model APIs, and a failed turn for a connection that names any other API.
- `apps/ui` (`data/queries/use-remote-sites.ts`, `data/settings-sections.ts`): a host without native sites offers only WordPress.com for publishing.
- The tests outside the package that list every provider (`packages/common/lib/tests/ai-settings.test.ts`, `packages/agent/protocol/sessions/tests/model.test.ts`, `apps/studio/src/modules/user-settings/lib/tests/settings-tracks.test.ts`): their account maps follow the registry.
- `packages/providers/README.md` and `docs/design-docs/providers.md`.

Untouched but relevant, because they already build everything from the registry's lists and the descriptors:

- the settings' provider rows and defaults (`apps/ui/src/features/settings/settings-view/`), with the generic row and the descriptor-logo fallback;
- the model picker and model access (`apps/ui/src/features/composer/`);
- `studio code`'s `/connect`, `/disconnect`, `/provider` and `/model` (`apps/cli/ai/slash-commands.ts`, `apps/cli/lib/providers.ts`);
- the AI connection and image-generator resolution (`apps/cli/ai/auth.ts`);
- `studio push` (`apps/cli/commands/push.ts`) and the CLI host's remote sites (`apps/cli/ai/host.ts`);
- the Desktop and `studio ui` handlers (`apps/studio/src/**/ipc-handlers.ts`, `apps/local/src/index.ts`);
- Studio on the web's agent and settings (`apps/static/src/agent/index.ts`);
- the agent's remote-site tools;
- `@studio/common/lib/ai-settings.ts` and `@studio/common/lib/user-settings/user-preferences.ts`;
- the `shared.json` schema (`packages/common/lib/shared-config.ts`).

Data flow:

- The registration's descriptors feed every surface's lists, labels, connect forms, models and site presentation.
- A host asks the services entry for a provider's services. It hands them the config Studio reads from its store, and stores any config they return under the provider's id.
- The CLI, the Desktop main process and `studio ui` publish to any provider through `studio push`. Studio on the web publishes only to WordPress.com.
- A turn's model connection passes through the agent's stream, which runs it over its API or rejects it.

## Decisions

design-doc-decision-1: One ordered registration, from which every provider list and type derives

**Serves:** spec-requirement-1, spec-requirement-2, spec-requirement-3, spec-requirement-9, spec-acceptance-criterion-1, spec-acceptance-criterion-2, spec-acceptance-criterion-6, spec-acceptance-criterion-10, spec-acceptance-criterion-17
**Decision:** `registry.ts` holds one ordered list of provider descriptors. The six existing providers come first, in today's order: WordPress.com, Anthropic, OpenAI, Google Gemini, GitHub Copilot, Spacefast. New providers are appended. Everything else derives from the list by capability, in its order:
- `PROVIDER_IDS` is the full list;
- `AI_PROVIDER_IDS` is the providers whose descriptor declares `ai`;
- `SITES_PROVIDER_IDS` is the ones that declare `sites`;
- `ProviderId`, `AiProviderId` and `SitesProviderId` are their ids;
- `ProviderConfigs`, `ProviderSites` and `ProviderSite` map each id to its descriptor's config and site types;
- `AiModelId` is every registered model id.

The derived exports keep their names, their values for the six providers, and their meaning, so their consumers don't change. A provider that declares both capabilities is in both lists under one id, so one config serves both. Appending keeps WordPress.com first everywhere Studio picks the first connected or ready provider. Through `findAiModel`'s first match, a model id shared with an existing provider keeps resolving to the existing provider's listing. The package's own tests hold the six existing providers at the head of the list. The hand-written unions, type maps, id lists and descriptor map are removed.
**Alternatives:**
- Discovering descriptors by folder, with no registration. Rejected: discovery order is alphabetical, which would move WordPress.com from first to last and change the fallback order and shared-model lookup. Discovery also loses the literal ids the unions need.
- Keeping the hand-written lists and checking them with a test. Rejected: adding a provider would still take edits in several places, and spec-requirement-1 allows one.
**Trade-offs:** The derived types come from the descriptors' inferred types, so a descriptor must keep its literal id and model ids (design-doc-decision-3). Order is a convention backed by a package test, not by the type system.
**Claims:**
- observed: read `packages/providers/registry.ts:17-48`, `types.ts:13-45` and `models.ts:9-15`: the lists and maps a provider is written into today.
- observed: today's derived orders equal the registration order filtered by capability: `AI_PROVIDER_IDS` is wpcom, anthropic, openai, gemini, github-copilot, and `PROVIDER_IDS` adds spacefast (read `registry.ts:18-35`).
- observed: `findAiModel` returns the first provider that lists an id (read `models.ts:31-41`), and the CLI picks the first connected provider in `AI_PROVIDER_IDS` order (read `apps/cli/ai/auth.ts:39-48`).
- assumed: TypeScript derives the literal unions from the registration without a circular reference; see design-doc-assumption-5.

design-doc-decision-2: Each folder's services are found by the folder's layout

**Serves:** spec-requirement-1, spec-requirement-2, spec-requirement-3, spec-acceptance-criterion-1, spec-acceptance-criterion-2, spec-acceptance-criterion-3
**Decision:** The services entry (`@studio/providers/services`) collects the services that every provider folder's `services.ts` exports. Vite's glob import finds them at build time. `getProviderServices( id )` keeps its signature and stays synchronous. It returns the services whose `id` is `id`. For a registered provider without services, it throws an error that names the provider and the module it expects, and lists the folders whose `services.ts` exports none. A folder whose `services.ts` exports no services never affects another provider's lookup. The surface entry (`@studio/providers`) never reaches services code, so `apps/ui` bundles only descriptors, as today. The package's own tests check that every registered provider resolves through the services entry to services with its id, and that provider ids are unique. The hand-written services map is removed.
**Alternatives:**
- A second list in `services.ts`, one import and one entry per provider, typed as a map over `ProviderId`, with no provider lint rule. Typecheck would then report a registered provider without services, services exported under another name, and services under an unregistered id. Rejected: every provider would change two files outside its folder, `registry.ts` and `services.ts`, and spec-requirement-1 allows one registration and no other file. It would also leave a folder that neither list names, as a developer has it before the registration step, passing typecheck and lint. That provider would appear in no surface, against spec-requirement-3. Only knip would report its files, as unused, without naming the registration.
- A registration that imports both halves. Rejected: the surface entry would import services code. `apps/ui` would then bundle the services, or rely on tree-shaking to drop them, and the surface boundary in `eslint.config.mjs:433-457` would have to go.
- A lazy `import()` of each services module from the registration. Rejected: `getProviderServices` would become asynchronous for every caller, `apps/ui` would bundle the services as chunks, and the lint boundary reports dynamic imports too.
- Generating the services map, or both maps, from a manifest with a script. Rejected: it adds a build step and a generated file that changes with every provider, and Vite already offers build-time discovery.
**Trade-offs:** The services entry now relies on the bundler. Every consumer builds or tests it with Vite:
- the CLI and the `studio ui` server through `apps/cli/vite.config.*`;
- the Desktop main process through electron-vite;
- Studio on the web through Vite;
- tests through Vitest.

A consumer that loads the entry without Vite would find no services. A provider is listed explicitly in the registration, but its services are found by convention. A missing services module, or services exported under another name, is no longer a typecheck error, as it is with today's exhaustive map. design-doc-decision-4's lint rule reports both instead, and the repository maintains that rule.
**Claims:**
- observed: `@studio/agent` already discovers files this way, in code the CLI and Studio on the web run (read `packages/agent/shared/skills.ts:1-18`, with `/// <reference types="vite/client" />`).
- observed: knip enables its Vite plugin for `packages/providers`, and treats non-raw `import.meta.glob` targets as entries without analyzing their exports (`npx knip --workspace packages/providers --debug` and knip's source, in `.pipelines/providers-api-for-external-devs/2-design-doc/design-doc/knip-vite-glob.txt`).
- observed: every importer of `@studio/providers/services` is in `apps/cli`, `apps/local`, `apps/studio`, `apps/static` or tests (`git grep -n "providers/services"`).
- observed: before the change, `SERVICES` was typed over every `ProviderId`, so a registered provider without services failed typecheck (`git show 3b21261b5:packages/providers/services.ts`, lines 9-18).
- observed: with a folder's services exported under another name, `tsc -p packages/providers` passes and the provider lint rule reports it in that `services.ts` (`.pipelines/providers-api-for-external-devs/2-design-doc/design-doc/services-list-question.txt`, case 1).
- observed: knip reports a provider file that no module imports as an unused file, without naming the registration (`.pipelines/providers-api-for-external-devs/2-design-doc/design-doc/services-list-question.txt`, case 2).
- assumed: electron-vite's main build resolves the glob; see design-doc-assumption-1.
- assumed: every TypeScript program that reaches the services entry accepts `vite/client` types; see design-doc-assumption-3.

design-doc-decision-3: A provider's contract is written in its own ids, and its services are checked against its own descriptor

**Serves:** spec-requirement-1, spec-requirement-3, spec-acceptance-criterion-7, spec-acceptance-criterion-8, spec-acceptance-criterion-9
**Decision:** A provider declares its descriptor through a package helper. The helper infers the provider's literal id, its config type, site type and model ids, which capabilities it declares, and the kinds of its connect methods. Within a descriptor, `ai.defaultModel`, `ai.paidDefaultModel` and `AccountDetails.models` accept only the provider's own model ids.

A provider declares its services through a second helper. The helper takes the folder's own descriptor and requires exactly the parts that descriptor declares:
- `account.connect`, always;
- `account.start`, when a connect method is a `device` or `loopback` sign-in;
- `ai.model`, when the descriptor declares `ai`;
- `sites.list` and `sites.push`, when it declares `sites`;
- `sites.create`, when `sites.newSite` is `create`;
- `sites.pull`, when `sites.pull` is true;
- no `ai` or `sites` part for a capability the descriptor doesn't declare.

`account.refresh`, `account.disconnect`, `ai.generateImages` and `ai.canGenerateImages` stay optional. Image generation stays part of `ai`. The services carry the descriptor's id. Typecheck therefore reports, in the provider's `services.ts`, a missing part and a part for a capability the descriptor doesn't declare, naming the part.

The consumer-facing types (`Provider`, `ProviderServices`, `AccountDetails` and the rest) keep their names and the meaning of their existing type parameters. Provider code references only the contract and its own folder, never the derived unions of design-doc-decision-1. The six existing providers move to the two helpers.
**Alternatives:**
- `satisfies Provider<…>` annotations on plain objects. Rejected: a provider that forgets to keep its id literal widens `ProviderId` to `string`, with no error.
- Contract types alone, with no link from services to descriptor. Rejected: they cannot tell that a provider listing models lacks a model connection, which is today's gap.
- Today's `Provider.ai`/`Provider.sites` and `ProviderServices.ai`/`ProviderServices.sites`, optional independently of each other. Rejected: they let a provider list models with no model connection, which is reported only as "offers no AI models" when a chat starts.
- A services helper that takes the provider's registered id, so services in an unregistered folder fail typecheck. Not taken: provider code would reference the registry's derived types, and design-doc-decision-4 reports an unregistered folder whether or not it has services yet.
- Image generation as a capability of its own, so a service offering only images could be a provider without chat models. Not taken: no provider or source shows one. spec-requirement-2 has a provider generate images when it is the chat's provider, or as the first connected AI provider that offers images, and today image services are an optional part of `ai`.
**Trade-offs:** The contract's types become conditional on the descriptor, so a typecheck error can be longer than a plain missing-property error (design-doc-assumption-2). Services written without the helper escape this check; design-doc-decision-4's lint rule reports them.
**Claims:**
- observed: the descriptor's and the services' capabilities are optional independently of each other (read `packages/providers/types.ts:173-179` and `305-320`), and a missing model connection shows as "offers no AI models" at chat time (read `apps/cli/ai/auth.ts:84-91`).
- observed: the device and loopback providers (OpenAI, GitHub Copilot, Spacefast) implement `account.start`, and the form and redirect providers don't (read `packages/providers/{openai,github-copilot,spacefast}/account.ts`).
- observed: `defaultModel` and `AccountDetails.models` are typed as the global `AiModelId` (read `types.ts:97,175`).
- observed: image generation is an optional part of `ProviderServices.ai` (read `types.ts:305-319`).
- assumed: an omitted or extra part is reported naming it; see design-doc-assumption-2.

design-doc-decision-4: ESLint reports a provider folder that is unregistered, or registered without checked services

**Serves:** spec-requirement-3, spec-requirement-1, spec-acceptance-criterion-9, spec-acceptance-criterion-10
**Decision:** A new rule in `eslint-plugin-studio`, enabled once for `@studio/providers` in `eslint.config.mjs`, checks each provider folder against the registration. It reports:
- in a folder's descriptor, a provider folder the registration doesn't list;
- at a registration entry, a registered provider whose folder has no `services.ts`, naming the module it expects;
- in a folder's `services.ts`, services that it doesn't export through the services helper of design-doc-decision-3, under the name the services entry reads.

Together with the services helper's type check, this means a registered provider that passes typecheck and lint has services that the services entry finds and that hold every part its descriptor declares. Each report lands in a file that a contribution changes, so ESLint on the changed files shows it. Adding a provider never changes the rule or its configuration.
**Alternatives:**
- Leaving a missing services module to the package tests and to the first connect or chat. Rejected: spec-requirement-3 and spec-acceptance-criterion-9 ask typecheck or lint to report it. A registered provider without services lists its models with no model connection and would pass both.
- A typed services list that typecheck checks against the registration, in place of this rule. Rejected with design-doc-decision-2's second list: it is a second registration, and it leaves a folder that neither list names unreported by typecheck and lint.
- A type-only reference to each folder's services from the registration, so a missing module fails typecheck. Rejected: the surface boundary reports type-only imports, and a `typeof import()` type query escapes it only because the rule doesn't visit type queries. That works against spec-requirement-7's boundary, and every registration entry would have to name both halves.
**Trade-offs:** The rule is infrastructure the repository maintains. Its result for one file depends on other files, the folder layout and the registration. That works because nothing lints with a cache, and a contribution's changed files include the file each report lands in.
**Claims:**
- observed: `tools/eslint-plugin-studio/src/rules` holds the repository's custom rules, each with a test in `tools/eslint-plugin-studio/tests` (`ls`).
- observed: `eslint.config.mjs` already reads folders from disk to build `apps/ui`'s layer zones (read `eslint.config.mjs:60-110`).
- observed: no workspace lints with `--cache`, and `@studio/providers` lints with `eslint .` (`.pipelines/providers-api-for-external-devs/2-design-doc/design-doc/observations.txt`).
- observed: `import-x/no-restricted-paths` visits type-only import declarations but not `typeof import()` type queries (eslint-plugin-import-x 4.17.1 source, `.pipelines/providers-api-for-external-devs/2-design-doc/design-doc/lint-restricted-paths.txt`).
- assumed: each report appears at its location, naming the missing part; see design-doc-assumption-6.

design-doc-decision-5: Studio stores any provider's config and remote-site connections in the shared sections by default

**Serves:** spec-requirement-1, spec-requirement-2, spec-requirement-8, spec-acceptance-criterion-2, spec-acceptance-criterion-3, spec-acceptance-criterion-4, spec-acceptance-criterion-6, spec-acceptance-criterion-8, spec-acceptance-criterion-16
**Decision:** The config store resolves any provider to its `providerConfigs.<id>` section. Only two providers override that, and their storage doesn't change:
- WordPress.com stays in `authToken`, the Studio sign-in;
- Anthropic keeps an API key in `anthropicApiKey`, with today's fallback to `cli.json`, and its subscription token in `providerConfigs.anthropic`.

The remote-site connection store resolves any sites provider to `remoteSites` entries tagged with its id. These keep the provider's site as the provider returned it, with Studio's sync times. Only WordPress.com overrides that, with `connectedWpcomSites`. Forgetting a local site's connections covers every registered sites provider.

In the registry, the stored-id mapping keeps one exception, Anthropic's `anthropic-api-key`. Every other provider is stored under its id, so `normalizeProviderId` and `toStoredProviderId` behave as today. Renewal, the forgetting of a rejected config, `rememberedSignIns`, `signInHostId`, the default hosting provider and Studio on the web's per-id configs already work for any id and don't change. The exception tables are Studio's storage, not part of the provider contract. Every write still goes through `shared.json`'s lock, and renewal through its per-provider lock, as today. The exhaustive per-provider store maps are removed.
**Alternatives:**
- A per-provider storage field in the descriptor, such as a legacy field name. Rejected: it puts storage into the provider contract, against "providers own no storage" (`docs/design-docs/providers.md`, principle 5), and only two providers would ever use it.
- Exhaustive maps that fall back to the default for unlisted ids. Rejected: typecheck would keep demanding an entry for every new id, as it does today.
- Migrating every account into one new format. Rejected: builds from before the change would no longer read what new builds write (spec-requirement-8).
**Trade-offs:** A new provider can never get a storage field of its own, only its section. This matches how OpenAI, Google Gemini, GitHub Copilot and Spacefast are stored today.
**Claims:**
- observed: OpenAI, Google Gemini, GitHub Copilot and Spacefast use the same per-id section the default would (read `packages/common/lib/provider-config.ts:69-144`).
- observed: Spacefast's connection store is the generic `remoteSitesStore( 'spacefast' )`, which stores the site object as given (read `packages/common/lib/remote-sites.ts:69-165`).
- observed: every stored id equals the provider id except Anthropic's (read `packages/providers/registry.ts:62-84`).
- observed: in `shared.json`, `providerConfigs`, `rememberedSignIns` and `remoteSites` are keyed by plain strings, and `aiProvider` is a plain string, so older builds keep parsing a file that names a provider they don't know (read `packages/common/lib/shared-config.ts:54-84`).
- observed: an unknown `defaultHostingProvider` reads back as no preference (read `packages/common/lib/user-settings/user-preferences.ts:191-195`).

design-doc-decision-6: The package's lint boundary matches provider folders by pattern

**Serves:** spec-requirement-7, spec-requirement-1, spec-acceptance-criterion-15
**Decision:** In `eslint.config.mjs`, the surface boundary of `@studio/providers` matches any provider folder by pattern, not by a list of names. Its restricted zone covers the package. Its exceptions are the package's shared surface files, any folder's `descriptor.ts` and `config.ts`, and WordPress.com's `sites/site.ts`. As a result, ESLint:
- reports a surface file of any folder that imports anything else;
- lets a folder's descriptor import its own config with no configuration change.

The rules against Node APIs and other workspace packages already cover every file in the package, and they stay as they are.
**Alternatives:**
- Generating the folder list from the file system in `eslint.config.mjs`, as the config already does for `apps/ui`'s layers. Rejected: the rule takes glob exceptions directly, so a pattern is simpler and doesn't depend on which folders exist when lint starts.
- A custom rule for the boundary. Rejected: the existing rule covers it.
**Trade-offs:** A provider's descriptor may import another provider's descriptor or config, as the six may today.
**Claims:**
- observed: the exceptions list the six folders by name (read `eslint.config.mjs:33-45,433-457`).
- observed: `import-x/no-restricted-paths` accepts glob exceptions when the zone's `from` is a glob, and matches them against the imported file's absolute path (eslint-plugin-import-x 4.17.1 source, `.pipelines/providers-api-for-external-devs/2-design-doc/design-doc/lint-restricted-paths.txt`).
- observed: the Node-API and workspace-package rules match `packages/providers/**/*.ts` (read `eslint.config.mjs:410-431`).

design-doc-decision-7: The contract names the four model APIs, and the agent runs exactly those

**Serves:** spec-requirement-6, spec-acceptance-criterion-3, spec-acceptance-criterion-4, spec-acceptance-criterion-13, spec-acceptance-criterion-14
**Decision:** The contract defines the model APIs Studio runs as a union: `openai-completions`, `openai-responses`, `anthropic-messages` and `google-generative-ai`. `AiConnection.model` is typed to that union, so a provider whose connection names any other API fails typecheck in its folder, with the API named.

In `@studio/agent/shared/models.ts`, the connection stream has a stream for each API in the union. The agent fails typecheck if the union gains an API it has no stream for. When a connection names an API outside the union, for example one cast past the types, the turn ends with an error naming the API and no request is sent. The Node runtime and the browser agent both stream through this code. GitHub Copilot reads its models from pi's catalog under pi's wider `Api` type, so it narrows them to the union in its own folder.
**Alternatives:**
- Keeping the silent `openai-responses` fallback, with only a typecheck. Rejected: spec-requirement-6 forbids sending a request over a different API.
- A runtime check only, with no narrowed type. Rejected: it reports nothing until a user chats.
- Validating in each host that resolves a connection (`apps/cli/ai/auth.ts`, `apps/static/src/agent/index.ts`, the eval harness). Rejected in favor of the one stream every turn passes through.
**Trade-offs:** Adding a fifth API is Studio's decision: it changes the union and the agent together (spec-exclusion-3).
**Claims:**
- observed: `openai-completions`, `anthropic-messages` and `google-generative-ai` get their own stream, and any other API goes to `openai-responses` (read `packages/agent/shared/models.ts:17-29`).
- observed: every existing connection names one of the four APIs (pi 1.5.0 catalogs and the WordPress.com tiers, in `.pipelines/providers-api-for-external-devs/2-design-doc/design-doc/model-apis.txt`).
- observed: both runtimes stream through `createConnectionStream` (read `packages/agent/node/runtime/index.ts:337-343` and `packages/agent/browser/models.ts:17-26`).
- assumed: an error the stream raises before any request reaches the user as the chat's error, in both runtimes; see design-doc-assumption-4.

design-doc-decision-8: A host without native sites offers only WordPress.com for publishing

**Serves:** spec-requirement-2, spec-requirement-9, spec-acceptance-criterion-5, spec-acceptance-criterion-17
**Decision:** The providers `apps/ui` offers for publishing depend on the host:
- where the connector has native sites (the Desktop app and `studio ui`), every registered sites provider;
- elsewhere (Studio on the web), only WordPress.com.

This rule drives the Settings hosting rows, the Default hosting provider select, the publish tab and the command palette's hosting entries. It replaces today's static-export check, which it covers, since a static export needs native PHP. Studio on the web therefore offers the same publish providers as today, and a new archive provider never shows there as a control its connector would reject.
**Alternatives:**
- A new connector capability that names the hosting providers a host publishes to. Rejected: it would carry the same value as `nativeSites` in all three connectors. Publishing to a provider other than WordPress.com runs `studio push`, which only hosts with native sites run. Studio on the web publishes through WordPress.com's own sync.
- Having Studio on the web publish to new archive providers, another reading of spec-requirement-2. Not taken: the requirement's bullet for the web lists account, model and image services, and spec-acceptance-criterion-5 names the Desktop app and `studio ui`.
**Trade-offs:** An archive provider whose API accepts calls from a page, which the web could in principle publish to, stays hidden there.
**Claims:**
- observed: today the web offers any sites provider whose content isn't static, and reads its account from AI settings (read `apps/ui/src/data/queries/use-remote-sites.ts:24-52`).
- observed: Studio on the web's remote-site methods throw `UnsupportedError` for any provider but WordPress.com (read `apps/ui/src/data/core/connectors/static/index.ts:87-92`).
- observed: the web's AI settings list only AI providers' accounts (read `apps/static/src/agent/index.ts:262-282`).
- observed: the palette's hosting entries are hidden off native hosts only for static-export providers (read `apps/ui/src/data/settings-sections.ts:321-333`).
- observed: the publish tab queries every provider `usePublishProviders` returns (read `apps/ui/src/features/sync/publish-tab.tsx:46-63`).
- observed: Desktop and `studio ui` publish by running `studio push` (read `packages/common/sites/sync.ts:56-79`).

design-doc-decision-9: Tests outside the package never list every provider

**Serves:** spec-requirement-1, spec-acceptance-criterion-1, spec-acceptance-criterion-2
**Decision:** The tests outside `@studio/providers` that build or compare an `AiSettings` hold for whatever providers the registry contains. Their account maps follow the registry, and their assertions concern only the providers they exercise. A registered provider then adds an account that those tests treat as not connected, and changes none of them. Tests that mock a few providers' services by id, such as `apps/cli/commands/tests/push.test.ts`, already don't list every provider.
**Alternatives:** Making `AiSettings.accounts` partial, with a missing account meaning not connected. Rejected: every consumer that reads `accounts[ id ].connected` would change, for a fix that belongs in the tests.
**Trade-offs:** None.
**Claims:**
- observed: with a sample provider registered, typecheck failed in `packages/agent/protocol/sessions/tests/model.test.ts` and `apps/studio/src/modules/user-settings/lib/tests/settings-tracks.test.ts` (`.pipelines/providers-api-for-external-devs/1-spec/spec/probe/2-registered-repo-typecheck.txt`).
- observed: with the sample provider listed, four tests failed in `packages/common/lib/tests/ai-settings.test.ts` and `model.test.ts` (`.pipelines/providers-api-for-external-devs/1-spec/spec/probe/3-listed-tests.txt`).
- observed: `git grep` for tests that list the providers by name finds those three files and `apps/cli/commands/tests/push.test.ts`, which mocks only some providers.

design-doc-decision-10: The contract documents every value, and only WordPress.com may declare the Studio sign-in

**Serves:** spec-requirement-5, spec-requirement-3, spec-acceptance-criterion-12
**Decision:** Every field, method, parameter and result of the contract (`types.ts`, `errors.ts`, and the helpers of design-doc-decision-3) carries documentation that states:
- what the value means;
- whether a new provider supplies it or acts on it;
- what Studio does with it.

`AiConnection.piProvider` says how pi uses the name.

The `redirect` connect method, the Studio sign-in, is unavailable to a new provider. The descriptor helper rejects a `redirect` method for any provider other than WordPress.com, naming the kind, in the provider's descriptor. The consumer-facing `ConnectMethod` keeps the kind, so surfaces read WordPress.com's sign-in as today.

The other parts that work for one provider only stay available. Their documentation says they belong to WordPress.com, and what a new provider does with them:
- `requiresPaidAiCredits` and `paidDefaultModel` follow the WordPress.com account's paid credits;
- `push`'s options use the selection format WordPress.com sync defined: a provider without selective sync receives the whole site, and one with it receives what the user picked;
- `list`'s `planRequired` option;
- the `pull` steps, which are remote backups and a Reprint exporter;
- `sites.newSite: 'checkout'`, which is WordPress.com's checkout;
- `hasBackups`.
**Alternatives:**
- Documenting `redirect` as WordPress.com's and leaving it available. Rejected: a new provider that declares it passes typecheck. Settings then drop the method and hide the provider when it has no other, and `studio code`'s `/connect` runs the WordPress.com login. The provider would be left out of a surface, against spec-requirement-3.
- Removing every WordPress.com-only part from the contract a new provider sees, with WordPress.com typed through a wider internal contract. Rejected: these are WordPress.com behaviors Studio keeps (spec-exclusion-6), consumers read them through the shared types, and splitting the contract would add a second descriptor type for one provider. spec-requirement-5 accepts documenting them.
**Trade-offs:** A new provider can still set the documented WordPress.com-only values, against their documentation. The descriptor helper names WordPress.com as the one provider allowed the Studio sign-in.
**Claims:**
- observed: the CLI connects any `redirect` method by running the WordPress.com login (read `apps/cli/lib/providers.ts:138-152`), and disconnects it by signing out of Studio (read `apps/cli/ai/slash-commands.ts:323-327`).
- observed: Settings drop `redirect` methods and hide a provider left with no other method (read `apps/ui/src/features/settings/settings-view/ai-panel.tsx:28-33` and `providers-panel.tsx:187-193`).
- observed: `requiresPaidAiCredits` locks a model on WordPress.com's quota (read `apps/ui/src/features/composer/use-model-access.ts:38-43`).
- observed: the push options, `planRequired` and the pull steps are typed in `packages/providers/types.ts:242-285` and used through `packages/common/sites/remote-sites.ts:28-38`.
- observed: `checkout` opens the connector's WordPress.com checkout URL whatever the provider (read `apps/ui/src/features/sync/publish-panel/index.tsx:113,155-171`).
- assumed: the helper's rejection names the kind in the descriptor; see design-doc-assumption-2.

design-doc-decision-11: The package README is the complete guide to adding a provider

**Serves:** spec-requirement-4, spec-acceptance-criterion-1, spec-acceptance-criterion-2, spec-acceptance-criterion-11
**Decision:** `packages/providers/README.md`'s section on adding a provider covers:
- the steps, which are exactly the folder and the appended registration entry;
- for each capability, the parts a provider fills in, as design-doc-decision-3 requires them;
- the connect methods a new provider can use (`form`, `device`, `loopback`), and the apps that offer each (Studio on the web offers forms only);
- the four model APIs;
- which declared values Studio stores and that they never change: the provider id, model ids and connect-method ids;
- that a provider's code runs in Node and in the page;
- how to test a provider: its own `tests/`, the package tests and lint rule that check its registration, and `npm test -- packages/providers`.

`docs/design-docs/providers.md` states the same architecture: the registration, services found by folder, the lint rule, default storage, and the four APIs. The README points to the contract's reference documentation (design-doc-decision-10) instead of repeating it.
**Alternatives:** A generator command that creates a provider's folder. Not taken: the spec's "Considered and not required" leaves it out, and documentation alone meets spec-requirement-4.
**Trade-offs:** The README and the contract can drift. The README states the rules, and the contract documents the values.
**Claims:** observed: today's steps leave out `AiProviderId`, the id lists, `STORED_PROVIDER_IDS`, `AiModelId`, the lint folder list and the agent (read `packages/providers/README.md:57-59`, and `.pipelines/providers-api-for-external-devs/1-spec/spec/probe/README.md`).

## Interfaces

**A provider's folder (`packages/providers/<folder>/`)**
- `config.ts`: the zod schema of what Studio stores for the provider.
- `descriptor.ts`: the provider's descriptor, declared through the descriptor helper. It holds:
  - the literal id, label, description, learn-more URL, icon and logo;
  - `account`: the config schema, connect methods of kind `form`, `device` or `loopback` with stable ids, `describe`, and optionally `expiresAt` and `remember`;
  - optionally `ai`: models with stable ids, and the default model;
  - optionally `sites`: presentation and behavior flags.
- `services.ts`: the provider's services, declared through the services helper with the folder's descriptor and exported under the name the services entry reads. Their required parts follow design-doc-decision-3.
- Model connections: `AiConnection`, with `model.api` one of `openai-completions`, `openai-responses`, `anthropic-messages` and `google-generative-ai`.
- Imports: the descriptor and config import only each other and the package's shared surface files. The services may also import the folder's other modules, the package's shared modules and its npm dependencies.

**The registration (`registry.ts`)**
- One ordered list of descriptors. A new provider is one entry appended to it.
- Exports, unchanged in name and meaning:
  - lists: `PROVIDER_IDS`, `AI_PROVIDER_IDS`, `SITES_PROVIDER_IDS`;
  - the default: `DEFAULT_PROVIDER_ID` (`wpcom`);
  - functions: `getProvider( id )`, `getProviderSites( id )`, `normalizeProviderId( value, ids? )`, `toStoredProviderId( id )`, `formatRemoteSite`, `parseRemoteSite`;
  - types: `ProviderId`, `AiProviderId`, `SitesProviderId`, `ProviderConfigs`, `ProviderSites`, `ProviderSite`.

**Models (`models.ts`)**: `AiModelId` is every registered model id. `findAiModel( id )` returns the first provider in registration order that lists the id. `getAiModels( provider, account? )` and `getDefaultAiModel( provider, options? )` keep their behavior.

**The services entry (`@studio/providers/services`)**: `getProviderServices( id )` returns `ProviderServices< ProviderConfigs[ Id ], ProviderSite< Id > >`, synchronously. For a registered provider without services, it throws an error naming the provider and the folders whose `services.ts` exports none. Such a folder never affects another provider's lookup. `createTusUpload` stays.

**The provider lint rule (`eslint-plugin-studio`)**: for `@studio/providers`, it reports:
- an unregistered provider folder, in its descriptor;
- a registered provider without `services.ts`, at its registration entry;
- services not exported through the services helper, in `services.ts`.

**Studio's storage (`@studio/common`)**
- `readProviderConfig`, `writeProviderConfig`, `readFreshProviderConfig`, `forgetRejectedConfig` and `readSignInContext` take any registered provider. They store under `providerConfigs.<id>`, except WordPress.com (`authToken`) and Anthropic's API key (`anthropicApiKey`).
- `getRemoteSites`, `rememberRemoteSite` and `forgetRemoteSite` take any sites provider. They store in `remoteSites`, except WordPress.com (`connectedWpcomSites`). `forgetRemoteSites( localSiteId )` covers every sites provider.

**The agent's stream (`@studio/agent/shared/models.ts`)**: `createConnectionStream( ai )` streams a connection whose API is one of the four. For any other API, it ends the turn with an error naming the API and sends no request.

**`apps/ui`**: `usePublishProviders()` returns every registered sites provider when `capabilities.nativeSites` is true, and only WordPress.com otherwise. Where sites aren't native, the palette hides every hosting entry except WordPress.com's.

**Contracts narrowed by the change**
- `AiConnection.model.api` is limited to the four APIs:
  - among providers, GitHub Copilot narrows its catalog models;
  - among consumers, the two agent runtimes already handle only these.
- A descriptor's `defaultModel`, `paidDefaultModel` and `AccountDetails.models` accept only the provider's own model ids. WordPress.com and GitHub Copilot already conform.
- A `redirect` connect method is accepted only in WordPress.com's descriptor. WordPress.com is the only provider that declares one today.
- A folder's services must be declared through the services helper and exported where the services entry reads them. The six providers move to that.
- Publishing on Studio on the web is limited to WordPress.com, the same set as today for the six providers.

**Contracts widened by the change, and what each consumer newly admits**
- `ProviderId`, `AiProviderId` and `SitesProviderId` admit any registered provider's id:
  - `shared.json` admits it as a `providerConfigs`, `rememberedSignIns` and `remoteSites[].provider` key or value, and in `aiProvider`;
  - session entries record it;
  - the user preferences admit it as `defaultHostingProvider`;
  - Tracks admits it as a `sync_type` value;
  - `studio push --remote-site` admits it as a prefix;
  - Settings, the model picker and `studio code` render it through the generic provider row, the descriptor's logo and the descriptor's connect methods;
  - older builds read such an id as unknown: `normalizeProviderId` returns undefined, and they fall back to the saved selection or WordPress.com, as for any unknown id today.
- `AiModelId` admits any registered model id, which session entries record. An older build drops a recorded model it doesn't know and falls back to the provider's default.

## Dependencies

- Vite's `import.meta.glob` and its `vite/client` types, for the services entry. These are not new: `vite` is a root dev dependency, and `@studio/agent/shared/skills.ts` uses both in code the CLI and Studio on the web bundle.
- knip's Vite plugin, already enabled for `packages/providers`, follows the services glob.
- `eslint-plugin-import-x`'s `no-restricted-paths` with glob exceptions (4.17.1, already installed).
- `eslint-plugin-studio`, the repository's own plugin, gains the provider rule.
- `@earendil-works/pi-ai`'s `Model` type (1.5.0, already a dependency), narrowed to the four APIs.
- No new npm dependency, and no change to the bundle scripts: the SDKs of the four APIs already ship, and the Mistral and AWS SDKs stay stripped.

## Failure modes and observability

- **A provider folder that isn't registered:** an ESLint error in its descriptor.
- **A registered provider whose folder has no `services.ts`:** an ESLint error at its registration entry, naming the expected module. If lint is skipped, the package tests fail, and at run time `getProviderServices` throws naming the provider and the module. A surface shows that error when the user connects or chats, the way hosts show any thrown error today.
- **Services not declared through the services helper:** an ESLint error in the folder's `services.ts`. If lint is skipped and the services aren't exported where the services entry reads them, that provider's lookup throws, naming the folder. Every other provider's lookup still works.
- **Services missing a part their descriptor declares, or declaring one it doesn't:** a typecheck error in the folder's `services.ts`, naming the part.
- **A `redirect` connect method outside WordPress.com:** a typecheck error in the provider's descriptor.
- **A connection naming an API Studio doesn't run:** a typecheck error in the folder, naming the API. If it is cast past the types, the chat's turn ends with an error naming the API, and nothing is sent.
- **A surface file that imports beyond the boundary, or code that imports a Node API or another workspace package:** an ESLint error in the offending file of the folder.
- **A provider inserted before existing ones:** the package tests fail, since the six existing providers must lead the registration in today's order.
- **Two providers with the same id:** the package tests fail.
- **A build that doesn't resolve the services glob:** the services entry is empty, and every `getProviderServices` call throws naming its provider. The first connect or chat shows it, as do the end-to-end runs and the Desktop bundle check under Verification.
- **A stored config that no longer parses, or has expired:** read as not connected (unchanged).
- **A config the provider rejects:** forgotten in the Desktop app, `studio ui` and the CLI, with the provider's `remember` kept (unchanged).

## Verification

- new test at the package's types (checked by `npm run typecheck`) — design-doc-decision-1 — a registered provider's id, config, site and model ids enter `ProviderId`, `AiProviderId` or `SitesProviderId`, `ProviderConfigs`, `ProviderSites` and `AiModelId` through its registration alone.
- new test at the package's types (checked by `npm run typecheck`) — design-doc-decision-3, design-doc-decision-10, spec-acceptance-criterion-7, spec-acceptance-criterion-9 — typecheck rejects, naming the part or the kind:
  - services that lack a part their descriptor's capabilities or connect methods require (the model connection, push, create, pull, start);
  - services that declare a capability their descriptor doesn't;
  - a `redirect` method in a descriptor other than WordPress.com's.
- new test at the package's types (checked by `npm run typecheck`) — design-doc-decision-7, spec-acceptance-criterion-14 — a connection whose API is outside the four fails typecheck, naming the API.
- new test at the `eslint-plugin-studio` rule boundary — design-doc-decision-4, spec-acceptance-criterion-9, spec-acceptance-criterion-10 — the rule reports an unregistered folder in its descriptor, a registered folder without `services.ts` at its registration entry, and services not declared through the helper in `services.ts`. It reports nothing for a complete folder.
- new test at the package's registry boundary (`packages/providers/tests`) — design-doc-decision-1, spec-acceptance-criterion-17 — the six existing providers lead the registration in today's order, and the derived id lists equal today's for them.
- new test at the package's registry boundary (`packages/providers/tests`) — design-doc-decision-2, spec-acceptance-criterion-10 — every registered provider resolves through the services entry to services with its id, and ids are unique.
- existing test `packages/providers/tests/providers.test.ts` › "reads the id builds before `anthropic` stored, and keeps writing it" — design-doc-decision-5, spec-acceptance-criterion-16 — the stored-id exception and the identity default.
- existing tests in `packages/common/lib/tests/ai-settings.test.ts` — design-doc-decision-5, spec-acceptance-criterion-16 — configs stay where builds of every version read them:
  - "stores an accepted key where every build reads it, and makes it the default without another";
  - "keeps a subscription token in its own section, and clears the other method on write";
  - "replaces a ChatGPT sign-in with an OpenAI API key", for the per-id section;
  - "keeps the WordPress.com config in the Studio sign-in, and revokes it on disconnect";
  - "reads legacy values from cli.json and migrates them on write";
  - "selects only a connected provider, storing the id older builds read".
- existing tests in `packages/common/lib/tests/ai-settings.test.ts` › "disconnects a provider whose config expired or that the provider rejects" and "stores a renewed config, and forgets one the provider no longer accepts but its client" — design-doc-decision-5, spec-acceptance-criterion-8 — renewal and rejection run through the per-id store a new provider uses.
- existing tests in `packages/common/lib/tests/remote-sites.test.ts` › "keeps the Spaces a site publishes to, and forgets them with the site" and "records each sync and keeps the times of the others" — design-doc-decision-5, spec-acceptance-criterion-16 — connections stay in `connectedWpcomSites` for WordPress.com and in `remoteSites` for the others, and are forgotten with the local site.
- new test at `@studio/agent/shared/models` (`createConnectionStream`) — design-doc-decision-7, spec-acceptance-criterion-14 — a connection that names an API outside the four ends with an error naming the API, and no request goes out.
- existing tests `packages/agent/browser/tests/gemini-stream.test.ts` › "streams a Gemini reply through Google’s SDK with the connected key" and `packages/agent/node/runtime/tests/pi-runtime.test.ts` › "streams with the connection’s upstream model and error rewrite" — design-doc-decision-7, spec-acceptance-criterion-13 — connections over the supported APIs still stream in both runtimes.
- existing test `apps/ui/src/features/composer/chat-model-picker.test.tsx` › "offers only the models the connected account can run" — design-doc-decision-3, spec-acceptance-criterion-8 — the picker narrows to the account's models from what the descriptor and account declare.
- existing test suites of `packages/common`, `packages/agent`, `apps/cli`, `apps/studio` and `apps/ui` (`npm test`), with the three test files of design-doc-decision-9 following the registry — design-doc-decision-9, spec-acceptance-criterion-17 — the six providers behave as before in connecting, selection, fallback, models, images and publishing.
- end-to-end flow — design-doc-decision-1, design-doc-decision-2, design-doc-decision-4, design-doc-decision-6, design-doc-decision-9, design-doc-decision-11, spec-acceptance-criterion-1, spec-acceptance-criterion-2, spec-acceptance-criterion-11 — following only the README, a sample chat provider (API key form, one of the four APIs) and a sample sites provider (device sign-in) each change only their folder and one registration entry. `npm run typecheck`, ESLint on the changed files, `npm run knip` and `npm test` pass.
- end-to-end flow — design-doc-decision-6, spec-acceptance-criterion-15 — with the lint configuration unchanged, ESLint on a sample provider's folder reports:
  - a descriptor or config importing its services;
  - a Node API import;
  - another workspace package's import.

  It reports nothing for a folder within the boundaries.
- end-to-end flow in `studio ui`, Studio on the web and the Desktop app — design-doc-decision-1, design-doc-decision-2, design-doc-decision-5, design-doc-decision-7, spec-acceptance-criterion-3, spec-acceptance-criterion-13 — the sample chat provider meets each point of spec-acceptance-criterion-3 in each app, and its replies stream over its API.
- end-to-end flow in `studio code` — design-doc-decision-1, design-doc-decision-5, spec-acceptance-criterion-4 — `/connect`, `/provider`, `/model`, a restart and `/disconnect` with the sample chat provider.
- end-to-end flow in the settings and publish panel of `studio ui` and the Desktop app, and `studio push --remote-site <id>` — design-doc-decision-1, design-doc-decision-5, spec-acceptance-criterion-5, spec-acceptance-criterion-6 — the sample sites provider, and a sample offering both capabilities connected once, appear and publish as the criteria say.
- end-to-end flow in Studio on the web — design-doc-decision-8 — with a sample archive-publishing provider registered, the publish tab, Settings' hosting providers and the palette offer only WordPress.com, as before.
- end-to-end flow — design-doc-decision-3, spec-acceptance-criterion-7, spec-acceptance-criterion-8 — sample providers with a device sign-in, a loopback sign-in, several methods, a narrowed model set, image generation and an expiring credential behave as declared in Settings, the chat model picker, `/model` and a chat.
- end-to-end flow — design-doc-decision-5, spec-acceptance-criterion-16 — the new build reads a `shared.json`, session entries and Studio on the web settings written by the base build. Settings, `studio code` and the publish panel show the same accounts, defaults, connections and pins. The base build then reads back what the new build stored, the same way.
- inspection — design-doc-decision-10, spec-acceptance-criterion-12 — every value of the contract states its meaning, whether a new provider supplies it or acts on it, and what Studio does with it, and each WordPress.com-only part says so.
- inspection — design-doc-decision-11, spec-acceptance-criterion-11 — the README covers each point the criterion lists, in agreement with the contract.
- inspection of the services entry — design-doc-decision-2 — a folder whose `services.ts` exports no services is skipped and named in the error, and never breaks another provider's lookup.
- inspection of the Desktop main bundle — design-doc-decision-2 — it includes every provider folder's services (design-doc-assumption-1).

## Risks

- **A provider that offers both chat models and remote sites** gets two palette entries with the same settings target, and the hosting entry lands on its AI provider row. It is the same provider and connection, so spec-acceptance-criterion-6 still holds.
- **On Studio on the web, a form-connected provider whose credential expires** is not renewed in the page, which reads stored configs without a refresh, as today. It shows as disconnected once the credential expires. A config the provider rejects stays stored there, as it does today for the six providers. Only OpenAI's ChatGPT sign-in and GitHub Copilot renew a credential today, and the web offers neither (`.pipelines/providers-api-for-external-devs/2-design-doc/design-doc/observations.txt`).
- **A form-connected provider whose API rejects calls from a page** is still offered on Studio on the web, and fails there when connecting or chatting. No source shows such a provider (spec, "Considered and not required").
- **A service that offers image generation without chat models** can't be added as a provider without declaring models (design-doc-decision-3). No provider or source shows one.
- **Error messages from the capability-linked types** may be longer than a plain missing-property error (design-doc-assumption-2).

## Open assumptions

design-doc-assumption-1: The Desktop main build (electron-vite 6 on Vite 8) resolves `import.meta.glob` in `@studio/providers/services` the way the CLI and Studio on the web builds do — assumed: the Desktop main bundle includes every provider folder's services, and connecting a provider from the Desktop app's Settings works.

design-doc-assumption-2: Typecheck reports a missing capability part and an extra one in the provider's `services.ts`, naming the part, and a `redirect` method outside WordPress.com in its descriptor, naming the kind — assumed: the type tests of design-doc-decision-3 and design-doc-decision-10, and the sample-provider flow, show the errors at those locations with those names.

design-doc-assumption-3: Every TypeScript program that reaches the services entry, in `apps/cli`, `apps/local`, `apps/studio`, `apps/static`, `packages/agent` and `packages/providers`, accepts `vite/client` types without conflict — assumed: `npm run typecheck` passes with the services entry discovering folders.

design-doc-assumption-4: An error the connection stream raises before any request reaches the user as the chat's error, in both the Node runtime and the browser agent — assumed: the new `createConnectionStream` test, and a chat in `studio code` and in Studio on the web on a sample connection that names another API, show the error naming the API.

design-doc-assumption-5: TypeScript derives the id unions, type maps and `AiModelId` from the registration's inferred descriptor types without a circular reference, as long as provider code references only the contract and its own folder — assumed: `npm run typecheck` passes with the registration as the only source of those types.

design-doc-assumption-6: The provider lint rule reports each case of design-doc-decision-4 in the file named there, naming the missing part, when ESLint runs on a contribution's changed files — assumed: the rule's tests, and ESLint on a sample provider part-way through being added, show each report there.
