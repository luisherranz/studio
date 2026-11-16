# Design Doc: Add a provider to @studio/providers from its own folder

## Overview

Today a provider exists in Studio only once it is written into hand-maintained lists. Inside `@studio/providers` there are the id unions (`ProviderId`, `AiProviderId`), the type maps (`ProviderConfigs`, `ProviderSites`), the model-id union (`AiModelId`), and the id lists and maps (`AI_PROVIDER_IDS`, `SITES_PROVIDER_IDS`, `PROVIDER_IDS`, `PROVIDERS`, `STORED_PROVIDER_IDS`, `SERVICES`). Outside the package there are Studio's per-provider config and connection stores in `@studio/common`, the folder list of the lint boundary, and tests that list every provider's account. Some of these lists typecheck when a provider is missing from them, and a provider left out of them appears in no surface. The contract also mixes in parts that only WordPress.com uses, without saying so. Separately, the agent sends any model API it doesn't recognize as `openai-responses`.

After the change, a provider is its folder plus one entry appended to an ordered registration in `registry.ts`. Every provider list and id union is derived from that registration, in its order. Each folder's services are found by the folder's layout, so the services entry needs no list of its own. A provider's contract is written in terms of its own id, config, site and model ids. Its services are checked against what its registered descriptor declares, so typecheck reports a missing part in the provider's folder. Studio stores any provider's config and remote-site connections in the shared sections by default; only the first providers keep their legacy fields. The lint boundary matches provider folders by pattern. The agent runs exactly the four model APIs the contract names and rejects any other by name. Studio on the web offers only the hosting providers it can publish to. The contract documents every value, and the package README is the complete guide to adding a provider.

## Architecture

New or reshaped inside `@studio/providers`:

- **A provider's folder** (`packages/providers/<id>/`): its config schema (`config.ts`); its descriptor (`descriptor.ts`), the browser-safe data surfaces read; its services (`services.ts`), what hosts run; its own modules and its `tests/`. The descriptor and config import only each other and the package's shared surface files. Neither half imports another workspace package or a Node API. A provider never reads or writes storage.
- **The registration** (`registry.ts`): the one ordered list of every provider's descriptor, existing providers first in today's order and new ones appended. From it come the id lists (`PROVIDER_IDS`, `AI_PROVIDER_IDS`, `SITES_PROVIDER_IDS`) and the types `ProviderId`, `AiProviderId`, `SitesProviderId`, `ProviderConfigs`, `ProviderSites` and `ProviderSite`. It also provides `getProvider` and `getProviderSites`, and keeps the stored-id exceptions, which hold Anthropic's legacy id only.
- **The contract** (`types.ts`): the descriptor and services shapes, expressed in a provider's own id, config, site and model ids. It holds the requirement that links a provider's services to its registered descriptor, the union of model APIs Studio runs, and the reference documentation of every value.
- **Models** (`models.ts`): `AiModelId` derived from the registered descriptors' models, and `findAiModel`, `getAiModels` and `getDefaultAiModel` with today's behavior.
- **The services entry** (`services.ts`): `getProviderServices( id )`, built from every folder's `services.ts`, found by the folder's layout.
- **The package's own tests** (`packages/providers/tests/`): registry-wide checks that hold for any provider set.

Changed once outside the package, so that a later provider needs no change there:

- `@studio/common/lib/provider-config.ts` and `@studio/common/lib/remote-sites.ts`: a default store for any provider, with overrides only where builds of every version read a legacy field.
- `eslint.config.mjs`: the surface boundary of `@studio/providers` matches any provider folder by pattern.
- `@studio/agent/shared/models.ts`: picks a stream for each of the four model APIs, and fails a turn whose connection names any other API.
- `apps/ui` (`data/queries/use-remote-sites.ts`, `data/settings-sections.ts`): a host without native sites offers WordPress.com only for publishing.
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

Data flow: the registration's descriptors feed every surface's lists, labels, connect forms, models and site presentation. A host asks the services entry for a provider's services. It hands them the config Studio reads from its store, and stores any config they return under the provider's id. The CLI, the Desktop main process and `studio ui` publish to any provider through `studio push`. Studio on the web publishes only to WordPress.com. A turn's model connection passes through the agent's stream, which runs it over its API or rejects it.

## Decisions

design-doc-decision-1: One ordered registration, from which every provider list and type derives

**Serves:** spec-requirement-1, spec-requirement-2, spec-requirement-3, spec-requirement-9, spec-acceptance-criterion-1, spec-acceptance-criterion-2, spec-acceptance-criterion-10, spec-acceptance-criterion-17
**Decision:** `registry.ts` holds a single ordered list of provider descriptors: the six existing providers in today's order (WordPress.com, Anthropic, OpenAI, Google Gemini, GitHub Copilot, Spacefast), with new providers appended. Everything else is derived from it, by capability, in its order:
- `PROVIDER_IDS` is the full list;
- `AI_PROVIDER_IDS` is the providers whose descriptor declares `ai`;
- `SITES_PROVIDER_IDS` is the ones that declare `sites`;
- `ProviderId`, `AiProviderId` and `SitesProviderId` are their ids;
- `ProviderConfigs`, `ProviderSites` and `ProviderSite` map each id to its descriptor's config and site types;
- `AiModelId` is every registered model id.

The derived exports keep their names, values for the six providers, and meaning, so their consumers don't change. Appending keeps WordPress.com first everywhere Studio picks the first connected or ready provider. It also keeps a model id shared with an existing provider resolving to the existing provider's listing, through `findAiModel`'s first match. The package's own tests hold the six existing providers at the head of the list. The hand-written unions, type maps, id lists and descriptor map are removed.
**Alternatives:** Discovering descriptors by folder with no registration. Rejected: discovery order is alphabetical, which would move WordPress.com from first to last and change fallback order and shared-model lookup. Discovery also loses the literal ids the unions need. Keeping the hand-written lists and checking them with a test was also rejected: adding a provider would still take edits in several places, and spec-requirement-1 allows one.
**Trade-offs:** The derived types are computed from the descriptors' inferred types, so a descriptor must keep its literal id and model ids (design-doc-decision-3). Order is a convention backed by a package test rather than by the type system.
**Claims:** observed: read `packages/providers/registry.ts:17-48`, `types.ts:13-45` and `models.ts:9-15`, the lists and maps a provider is written into today. observed: today's derived orders, `AI_PROVIDER_IDS` = wpcom, anthropic, openai, gemini, github-copilot and `PROVIDER_IDS` = that plus spacefast (read `registry.ts:18-35`), equal the registration order filtered by capability. observed: read `models.ts:31-41` (`findAiModel` returns the first provider listing an id) and `apps/cli/ai/auth.ts:39-48` (the first connected provider in `AI_PROVIDER_IDS` order). assumed: TypeScript derives the literal unions from the registration without a circular reference, see design-doc-assumption-5.

design-doc-decision-2: Each folder's services are found by the folder's layout

**Serves:** spec-requirement-1, spec-requirement-2, spec-requirement-3, spec-acceptance-criterion-1, spec-acceptance-criterion-2
**Decision:** The services entry (`@studio/providers/services`) collects the services that every provider folder's `services.ts` exports, using Vite's `import.meta.glob` on that file name. `getProviderServices( id )` keeps its signature and returns the services whose `id` is `id`. For a registered provider whose folder has no services, it throws an error that names the provider and the file it expects. The surface entry (`@studio/providers`) never reaches services code, so `apps/ui` bundles only descriptors as today. The package's own tests check that:
- every registered provider has services with its id and the parts its descriptor declares;
- every provider folder is registered;
- provider ids are unique.

The hand-written services map is removed.
**Alternatives:** A second, typed list in `services.ts`. Rejected: that is a second registration, which spec-requirement-1 rules out.

A registration that imports both halves. Rejected: the surface entry would import services code, so `apps/ui` would bundle the services or rely on tree-shaking to drop them, and the surface boundary in `eslint.config.mjs:433-457` would have to go.

Lazy `import()` of each services module from the registration. Rejected: `getProviderServices` would become asynchronous for every caller. `apps/ui` would bundle the services as chunks. The lint boundary reports dynamic imports too.

A type-only `typeof import( './<id>/services' )` in the registration entry. Rejected: it makes a missing services module a typecheck error, but only because the lint rule doesn't see type queries, and every registration entry would have to name both halves.

Generating the services map with a script. Rejected: it adds a build step, and a generated file changes with every provider.
**Trade-offs:** The services entry now relies on the bundler. Every consumer is built or tested with Vite: the CLI and `studio ui` server through `apps/cli/vite.config.*`, the Desktop main process through electron-vite, Studio on the web through Vite, and tests through Vitest. A provider folder with no `services.ts` is not a typecheck or lint error. The package tests and the first call report it.
**Claims:** observed: `@studio/agent` already discovers files this way in code the CLI and Studio on the web run (read `packages/agent/shared/skills.ts:1-18`, with `/// <reference types="vite/client" />`). observed: knip enables its Vite plugin for `packages/providers`, and it treats non-raw `import.meta.glob` targets as entries without analyzing their exports (`npx knip --workspace packages/providers --debug`, and knip's source, in `.pipelines/providers-api-for-external-devs/2-design-doc/lanes/opus/design-doc/knip-vite-glob.txt`). observed: every importer of `@studio/providers/services` is in `apps/cli`, `apps/local`, `apps/studio`, `apps/static`, or tests (`git grep -n "providers/services"`). assumed: electron-vite's main build resolves the glob, see design-doc-assumption-1. assumed: every TypeScript program that reaches the services entry accepts `vite/client` types, see design-doc-assumption-3.

design-doc-decision-3: A provider's contract is written in its own ids, and its services are checked against its registered descriptor

**Serves:** spec-requirement-1, spec-requirement-3, spec-acceptance-criterion-7, spec-acceptance-criterion-8, spec-acceptance-criterion-9
**Decision:** A provider declares its descriptor through a package helper. The helper infers the provider's literal id, config type, site type, model ids, which capabilities it declares, and the kinds of its connect methods. Within a descriptor:
- `ai.defaultModel`, `ai.paidDefaultModel` and `AccountDetails.models` accept only the provider's own model ids.

A provider declares its services through a second helper. It takes the provider's registered id, and requires exactly the parts the registered descriptor declares:
- `account.connect`, always;
- `account.start`, when a connect method is a `device` or `loopback` sign-in;
- `ai.model`, when the descriptor declares `ai`; image generation stays optional;
- `sites.list` and `sites.push`, when it declares `sites`;
- `sites.create`, when `sites.newSite` is `create`;
- `sites.pull`, when `sites.pull` is true;
- no `ai` or `sites` part for a capability the descriptor doesn't declare.

`account.refresh`, `account.disconnect`, `ai.generateImages` and `ai.canGenerateImages` stay optional. Typecheck therefore reports these mistakes in the provider's `services.ts`, naming the part or the id:
- a missing part;
- a part for a capability the descriptor doesn't declare;
- an id that isn't registered.

The consumer-facing types (`Provider`, `ProviderServices`, `AccountDetails` and the rest) keep their names and the meaning of their existing type parameters. Provider code references only the contract and its own types, never the derived unions of design-doc-decision-1, except through the services helper's registered id. The six existing providers move to the two helpers.
**Alternatives:** `satisfies Provider<…>` annotations on plain objects. Rejected: a provider that forgets to keep its id literal widens `ProviderId` to `string` without any error. Contract types alone, with no link from services to descriptor, were also rejected: they cannot tell that a provider listing models lacks a model connection, which is today's gap. Today's independent optional `Provider.ai`/`Provider.sites` and `ProviderServices.ai`/`ProviderServices.sites` were rejected as well: they let a provider list models with no model connection, reported only as "offers no AI models" when a chat starts.
**Trade-offs:** The contract's types become conditional on the descriptor, so a typecheck error can be longer than a plain missing-property error (design-doc-assumption-2). Services written without the helper escape the type check. The package's registry test then reports a missing part at test time.
**Claims:** observed: read `packages/providers/types.ts:173-179` and `305-320` (the descriptor's and services' capabilities are optional independently), and `apps/cli/ai/auth.ts:84-91` ("offers no AI models" at chat time). observed: the device and loopback providers (OpenAI, GitHub Copilot, Spacefast) implement `account.start`, and the form and redirect providers don't (read `packages/providers/{openai,github-copilot,spacefast}/account.ts`). observed: `defaultModel` and `AccountDetails.models` are typed as the global `AiModelId` (read `types.ts:97,175`). assumed: an omitted part is reported naming it, see design-doc-assumption-2.

design-doc-decision-4: Studio stores any provider's config and remote-site connections in the shared sections by default

**Serves:** spec-requirement-1, spec-requirement-2, spec-requirement-8, spec-acceptance-criterion-2, spec-acceptance-criterion-3, spec-acceptance-criterion-4, spec-acceptance-criterion-16
**Decision:** The config store resolves any provider to its `providerConfigs.<id>` section. Only two providers override that, with their storage unchanged:
- WordPress.com stays in `authToken`, the Studio sign-in;
- Anthropic keeps an API key in `anthropicApiKey`, and its subscription token in `providerConfigs.anthropic`.

The remote-site connection store resolves any sites provider to `remoteSites` entries tagged with its id. Only WordPress.com overrides that, with `connectedWpcomSites`. Forgetting a local site's connections covers every registered sites provider. In the registry, the stored-id mapping keeps Anthropic's `anthropic-api-key` as its one exception. Every other provider is stored under its id, so `normalizeProviderId` and `toStoredProviderId` behave as today. `rememberedSignIns`, `signInHostId`, the default hosting provider and Studio on the web's per-id configs need no change. The exception tables are Studio's storage, not part of the provider contract. Every write still goes through `shared.json`'s lock, as today. The exhaustive per-provider store maps are removed.
**Alternatives:** A per-provider storage field in the descriptor, for example a legacy field name. Rejected: it puts storage into the provider contract, against "providers own no storage" (`docs/design-docs/providers.md`, principle 5), and only two providers would ever use it. Keeping exhaustive maps that fall back to the default for unlisted ids would leave typecheck demanding an entry for every new id, as it does today.
**Trade-offs:** A new provider can never get a storage field of its own, only its section. This matches how OpenAI, Google Gemini, GitHub Copilot and Spacefast are stored today.
**Claims:** observed: read `packages/common/lib/provider-config.ts:69-144`. OpenAI, Google Gemini, GitHub Copilot and Spacefast use the same per-id section the default would. observed: read `packages/common/lib/remote-sites.ts:115-165`. Spacefast's store is the generic `remoteSitesStore( 'spacefast' )`. observed: read `packages/providers/registry.ts:62-84`. Every stored id equals the provider id except Anthropic's. observed: `shared.json`'s `providerConfigs`, `rememberedSignIns` and `remoteSites` are keyed by plain strings, and `aiProvider` is a plain string, so older builds keep parsing a file that names a provider they don't know (read `packages/common/lib/shared-config.ts:54-84`). observed: an unknown `defaultHostingProvider` reads back as no preference (read `packages/common/lib/user-settings/user-preferences.ts:191-195`).

design-doc-decision-5: The package's lint boundary matches provider folders by pattern

**Serves:** spec-requirement-7, spec-requirement-1, spec-acceptance-criterion-15
**Decision:** In `eslint.config.mjs`, the surface boundary of `@studio/providers` matches any provider folder by pattern instead of a list of names. Its restricted zone covers the package, and its exceptions are the package's shared surface files plus any folder's `descriptor.ts` and `config.ts`, and WordPress.com's `sites/site.ts`. As a result, ESLint:
- reports a surface file of any folder that imports anything else;
- lets a folder's descriptor import its own config with no configuration change.

The rules against Node APIs and other workspace packages already cover every file in the package and stay as they are.
**Alternatives:** Generating the folder list from the file system in `eslint.config.mjs`, as the config already does for `apps/ui` layers. Rejected: the rule takes glob exceptions directly, so the pattern is simpler and doesn't depend on the folders present when lint starts. A custom rule in `eslint-plugin-studio` was rejected too: the existing rule covers it.
**Trade-offs:** A provider's descriptor may import another provider's descriptor or config, as the six may today.
**Claims:** observed: read `eslint.config.mjs:33-45,433-457`. The exceptions list the six folders by name. observed: `import-x/no-restricted-paths` accepts glob exceptions when the zone's `from` is a glob, and matches them against the imported file's absolute path (eslint-plugin-import-x 4.17.1 source, `.pipelines/providers-api-for-external-devs/2-design-doc/lanes/opus/design-doc/lint-restricted-paths.txt`). observed: read `eslint.config.mjs:410-431`. The Node-API and workspace-package rules match `packages/providers/**/*.ts`.

design-doc-decision-6: The contract names the four model APIs, and the agent runs exactly those

**Serves:** spec-requirement-6, spec-acceptance-criterion-13, spec-acceptance-criterion-14, spec-acceptance-criterion-3, spec-acceptance-criterion-4
**Decision:** The contract defines the model APIs Studio runs as a union: `openai-completions`, `openai-responses`, `anthropic-messages` and `google-generative-ai`. `AiConnection.model` is typed to that union, so a provider whose connection names any other API fails typecheck in its folder, with the API named. In `@studio/agent/shared/models.ts`, the connection stream has a stream for each API in the union, and the agent fails typecheck if the union gains an API it has no stream for. For a connection whose API is outside the union, for example one cast past the types, the turn ends with an error naming the API, and no request is sent. Both the Node runtime and the browser agent stream through it. GitHub Copilot, which reads its models from pi's catalog under pi's wider `Api` type, narrows them to the union in its own folder.
**Alternatives:** Keeping the silent `openai-responses` fallback with only a typecheck. Rejected: spec-requirement-6 forbids sending a request over a different API. A runtime check only, with no narrowed type, was rejected because it reports nothing until a user chats. Validating in each host that resolves a connection (`apps/cli/ai/auth.ts`, `apps/static/src/agent/index.ts`, the eval harness) was rejected in favor of the one stream every turn passes through.
**Trade-offs:** Adding a fifth API is Studio's decision: it changes the union and the agent together (spec-exclusion-3).
**Claims:** observed: read `packages/agent/shared/models.ts:17-29`. `openai-completions`, `anthropic-messages` and `google-generative-ai` get their own stream, and anything else goes to `openai-responses`. observed: every existing connection names one of the four APIs (pi 1.5.0 catalogs and the WordPress.com tiers, in `.pipelines/providers-api-for-external-devs/2-design-doc/lanes/opus/design-doc/model-apis.txt`). observed: both runtimes stream through `createConnectionStream` (read `packages/agent/node/runtime/index.ts:337-343` and `packages/agent/browser/models.ts:17-26`). assumed: an error raised by the stream before any request reaches the user as the chat's error in both runtimes, see design-doc-assumption-4.

design-doc-decision-7: A host without native sites offers WordPress.com only for publishing

**Serves:** spec-requirement-2, spec-requirement-9, spec-acceptance-criterion-5, spec-acceptance-criterion-17
**Decision:** The providers `apps/ui` offers for publishing depend on the host:
- where the connector has native sites (the Desktop app and `studio ui`), every registered sites provider;
- elsewhere (Studio on the web), WordPress.com only.

This drives the Settings hosting rows, the Default hosting provider select, the publish tab and the command palette's hosting entries. The rule replaces today's static-export check, which it covers: static content needs native PHP. Studio on the web therefore offers the same publish providers as today, and a new sites provider never shows there as a control its connector would reject.
**Alternatives:** A new connector capability naming the hosting providers a host publishes to. Rejected: it would carry the same value as `nativeSites` in all three connectors. Publishing to a provider other than WordPress.com runs `studio push`, which only hosts with native sites run, and Studio on the web publishes through WordPress.com's own sync. Another reading of spec-requirement-2 would have Studio on the web publish to new archive providers. That reading was not taken: the requirement's web bullet lists account, model and image services, and spec-acceptance-criterion-5 names the Desktop app and `studio ui`.
**Trade-offs:** A provider that the web could in principle publish to, an archive provider whose API accepts the page, stays hidden there.
**Claims:** observed: read `apps/ui/src/data/queries/use-remote-sites.ts:26-41`. Today the web offers any sites provider whose content isn't static, and reads its account from AI settings. observed: read `apps/ui/src/data/core/connectors/static/index.ts:87-92`. Studio on the web's remote-site methods throw `UnsupportedError` for any provider but WordPress.com. observed: read `apps/static/src/agent/index.ts:262-282`. The web's AI settings list AI providers' accounts only. observed: read `apps/ui/src/features/sync/publish-tab.tsx:46-63`. The publish tab queries every provider `usePublishProviders` returns. observed: read `packages/common/sites/sync.ts:56-79`. Desktop and `studio ui` publish by running `studio push`.

design-doc-decision-8: Tests outside the package never list every provider

**Serves:** spec-requirement-1, spec-acceptance-criterion-1, spec-acceptance-criterion-2
**Decision:** The tests outside `@studio/providers` that build or compare an `AiSettings` hold for whatever providers the registry contains. Their account maps follow the registry, and their assertions concern only the providers they exercise. A registered provider then adds an account those tests treat as not connected, and changes none of them. Tests that mock a few providers' services by id, such as `apps/cli/commands/tests/push.test.ts`, already don't list every provider.
**Alternatives:** Making `AiSettings.accounts` partial, with a missing account meaning not connected. Rejected: every consumer that reads `accounts[ id ].connected` would change, for a fix that belongs in the tests.
**Trade-offs:** None.
**Claims:** observed: with a sample provider registered, typecheck failed in `packages/agent/protocol/sessions/tests/model.test.ts` and `apps/studio/src/modules/user-settings/lib/tests/settings-tracks.test.ts`, and four tests failed in `packages/common/lib/tests/ai-settings.test.ts` and `model.test.ts` (`.pipelines/providers-api-for-external-devs/1-spec/spec/probe/2-registered-repo-typecheck.txt`, `3-listed-tests.txt`). observed: `git grep` for tests listing the providers by name finds those three and `apps/cli/commands/tests/push.test.ts`, which mocks only some.

design-doc-decision-9: The contract documents every value, and names the parts that belong to one provider

**Serves:** spec-requirement-5, spec-acceptance-criterion-12
**Decision:** Every field, method, parameter and result of the contract (`types.ts`, `errors.ts`, and the helpers of design-doc-decision-3) carries documentation stating three things:
- what the value means;
- whether a new provider supplies it or acts on it;
- what Studio does with it.

The parts that work for one provider only stay in the contract. Their documentation says they are WordPress.com's, and what a new provider does with them:
- the `redirect` connect method is the Studio sign-in;
- `requiresPaidAiCredits` and `paidDefaultModel` follow the WordPress.com account's paid credits;
- `push`'s options use the selection format WordPress.com sync defined: a provider without selective sync receives the whole site, and one with it receives what the user picked;
- `list`'s `planRequired` option;
- the `pull` steps, which are remote backups and a Reprint exporter;
- `sites.newSite: 'checkout'` is WordPress.com's checkout;
- `hasBackups`.

`AiConnection.piProvider` says how pi uses the name.
**Alternatives:** Removing the WordPress.com-only parts from the contract a new provider sees, with WordPress.com typed through a wider internal contract. Rejected: these are WordPress.com behaviors Studio keeps (spec-exclusion-6), and consumers read them through the shared types. Splitting the contract would add a second descriptor type for one provider. spec-requirement-5 accepts either.
**Trade-offs:** A new provider can still set a WordPress.com-only value, against its documentation.
**Claims:** observed: read `apps/cli/lib/providers.ts:144-145` and `apps/cli/ai/slash-commands.ts:323-327`. The CLI connects any `redirect` method by signing in to Studio. observed: read `apps/ui/src/features/composer/use-model-access.ts:38-43`. `requiresPaidAiCredits` locks a model on WordPress.com's quota. observed: read `packages/providers/types.ts:242-285` and `packages/common/sites/remote-sites.ts:28-38`. observed: read `apps/ui/src/features/sync/publish-panel/index.tsx:113,152-170`. `checkout` opens the connector's WordPress.com checkout URL.

design-doc-decision-10: The package README is the complete guide to adding a provider

**Serves:** spec-requirement-4, spec-acceptance-criterion-11, spec-acceptance-criterion-1, spec-acceptance-criterion-2
**Decision:** `packages/providers/README.md`'s section on adding a provider covers:
- the steps, which are exactly the folder and the appended registration entry;
- for each capability, the parts a provider fills in, as design-doc-decision-3 requires them;
- the connect methods a new provider can use (`form`, `device`, `loopback`), and the apps that offer each: Studio on the web offers forms only;
- the four model APIs;
- which declared values Studio stores, and that they never change: provider id, model ids, connect-method ids;
- that a provider's code runs in Node and in the page;
- how to test a provider: its own `tests/`, the package tests that check its registration, and `npm test -- packages/providers`.

`docs/design-docs/providers.md` states the same architecture: the registration, services found by folder, default storage, and the four APIs. The README points to the contract's reference documentation (design-doc-decision-9) instead of repeating it.
**Alternatives:** A generator command that creates a provider's folder. Not taken: the spec's "Considered and not required" leaves it out, and documentation alone meets spec-requirement-4.
**Trade-offs:** The README and the contract can drift. The README states the rules, and the contract documents the values.
**Claims:** observed: read `packages/providers/README.md:57-59`. Today's steps leave out `AiProviderId`, the id lists, `STORED_PROVIDER_IDS`, `AiModelId`, the lint folder list and the agent (`.pipelines/providers-api-for-external-devs/1-spec/spec/probe/README.md`).

## Interfaces

**A provider's folder (`packages/providers/<id>/`)**
- `config.ts`: the zod schema of what Studio stores for the provider.
- `descriptor.ts`: the provider's descriptor, declared through the descriptor helper, with its literal id, its label, description, learn-more URL, icon and logo. It also holds `account` (config schema, connect methods with stable ids, `describe`, optional `expiresAt` and `remember`), and optionally `ai` (models with stable ids, default model) and `sites` (presentation and behavior flags).
- `services.ts`: the provider's services, declared through the services helper with the provider's registered id. Their required parts follow design-doc-decision-3.
- Model connections: `AiConnection` with `model.api` among `openai-completions`, `openai-responses`, `anthropic-messages` and `google-generative-ai`.
- Imports: the descriptor and config import only each other and the package's shared surface files. The services may also import the folder's other modules, the package's shared modules and its npm dependencies.

**The registration (`registry.ts`)**
- One ordered list of descriptors. A new provider is one entry appended to it.
- Exports, unchanged in name and meaning:
  - lists: `PROVIDER_IDS`, `AI_PROVIDER_IDS`, `SITES_PROVIDER_IDS`;
  - the default: `DEFAULT_PROVIDER_ID` (`wpcom`);
  - functions: `getProvider( id )`, `getProviderSites( id )`, `normalizeProviderId( value, ids? )`, `toStoredProviderId( id )`, `formatRemoteSite`, `parseRemoteSite`;
  - types: `ProviderId`, `AiProviderId`, `SitesProviderId`, `ProviderConfigs`, `ProviderSites`, `ProviderSite`.

**Models (`models.ts`)**: `AiModelId` (every registered model id), `findAiModel( id )` (the first provider in registration order that lists it), `getAiModels( provider, account? )` and `getDefaultAiModel( provider, options? )`, unchanged in behavior.

**The services entry (`@studio/providers/services`)**: `getProviderServices( id )` returns `ProviderServices< ProviderConfigs[ Id ], ProviderSite< Id > >`. For a registered provider whose folder has no services, it throws an error naming the provider. `createTusUpload` stays.

**Studio's storage (`@studio/common`)**
- `readProviderConfig`, `writeProviderConfig`, `readFreshProviderConfig`, `forgetRejectedConfig` and `readSignInContext` take any registered provider. They store under `providerConfigs.<id>`, except WordPress.com (`authToken`) and Anthropic's API key (`anthropicApiKey`).
- `getRemoteSites`, `rememberRemoteSite` and `forgetRemoteSite` take any sites provider. They store in `remoteSites`, except WordPress.com (`connectedWpcomSites`). `forgetRemoteSites( localSiteId )` covers every sites provider.

**The agent's stream (`@studio/agent/shared/models.ts`)**: `createConnectionStream( ai )` streams a connection whose API is one of the four. For any other API, it ends the turn with an error naming the API and sends no request.

**`apps/ui`**: `usePublishProviders()` returns every registered sites provider when `capabilities.nativeSites` is true, and WordPress.com only otherwise. The palette's hosting entries other than WordPress.com's are hidden where sites aren't native.

**Contracts narrowed by the change**
- `AiConnection.model.api` is limited to the four APIs. Affected:
  - providers: GitHub Copilot narrows its catalog models;
  - consumers: the two agent runtimes, which already handle only these.
- A descriptor's `defaultModel`, `paidDefaultModel` and `AccountDetails.models` accept only the provider's own model ids. WordPress.com and GitHub Copilot already conform.
- Publishing on Studio on the web is limited to WordPress.com, the same set as today for the six providers.

**Contracts widened by the change, and what each consumer newly admits**
- `ProviderId`, `AiProviderId` and `SitesProviderId` admit any registered provider's id:
  - `shared.json` admits it as a `providerConfigs`, `rememberedSignIns` and `remoteSites[].provider` key or value, and in `aiProvider`;
  - session entries record it;
  - the user preferences admit it as `defaultHostingProvider`;
  - Tracks admits it as a `sync_type` value;
  - `studio push --remote-site` admits it as a prefix;
  - Settings, the model picker and `studio code` render it through the generic provider row, the descriptor's logo and the descriptor's connect methods.
  - Older builds read such an id as unknown: `normalizeProviderId` returns undefined, and they fall back to the saved selection or WordPress.com, as for any unknown id today.
- `AiModelId` admits any registered model id: session entries record it. An older build drops a recorded model it doesn't know and falls back to the provider's default.

## Dependencies

- Vite's `import.meta.glob` and its `vite/client` types, for the services entry. These are not new: `vite` is a root dev dependency, and `@studio/agent/shared/skills.ts` uses both in code the CLI and Studio on the web bundle.
- knip's Vite plugin, already enabled for `packages/providers`, follows the services glob.
- `eslint-plugin-import-x`'s `no-restricted-paths` with glob exceptions (4.17.1, already installed).
- `@earendil-works/pi-ai`'s `Model` type (1.5.0, already a dependency), narrowed to the four APIs.
- No new npm dependency, and no change to the bundle scripts: the SDKs of the four APIs already ship, and the Mistral and AWS SDKs stay stripped.

## Failure modes and observability

- **A registered provider whose folder has no `services.ts`:** the package tests fail, naming the provider. At run time, `getProviderServices` throws naming the provider and the expected file. In a surface this shows as that error when the user connects or chats, the way the hosts surface any thrown error today.
- **A provider folder that isn't registered:** its services helper rejects the unregistered id at typecheck, in its own `services.ts`, and the package tests fail.
- **Services missing a part their descriptor declares, or declaring one it doesn't:** typecheck error in the folder's `services.ts`, naming the part.
- **A connection naming an API Studio doesn't run:** typecheck error in the folder, naming the API. If cast past the types, the chat's turn ends with an error naming the API, and nothing is sent.
- **A surface file that imports beyond the boundary, Node APIs or another workspace package:** ESLint error in the offending file of the folder.
- **A provider inserted before existing ones:** the package tests fail, since the six existing providers must lead the registration in today's order.
- **A build that doesn't resolve the services glob:** the services entry is empty, and every `getProviderServices` call throws naming its provider. The first connect or chat shows it, as do the AC1/AC2 runs and the Desktop build check under Verification.
- **A stored config that no longer parses, or has expired:** read as not connected (unchanged).
- **A config the provider rejects:** forgotten, with the provider's `remember` kept (unchanged).

## Verification

- new type test in `packages/providers` (checked by `npm run typecheck`) — design-doc-decision-1 — a registered provider's id, config, site and model ids enter `ProviderId`, `AiProviderId` or `SitesProviderId`, `ProviderConfigs`, `ProviderSites` and `AiModelId` through its registration alone.
- new type test in `packages/providers` (checked by `npm run typecheck`) — design-doc-decision-3, spec-acceptance-criterion-9, spec-acceptance-criterion-7 — typecheck rejects, naming the part or the id, services that:
  - lack a part their descriptor's capabilities or connect methods require (the model connection, push, create, pull, start);
  - declare a capability their descriptor doesn't;
  - name an unregistered provider.
- new type test in `packages/providers` (checked by `npm run typecheck`) — design-doc-decision-6, spec-acceptance-criterion-14 — a connection whose API is outside the four fails typecheck, naming the API.
- new test at the package's registry boundary (`packages/providers/tests`) — design-doc-decision-1, spec-acceptance-criterion-17 — the six existing providers lead the registration in today's order, and the derived id lists equal today's for them.
- new test at the package's registry boundary (`packages/providers/tests`) — design-doc-decision-2, design-doc-decision-3, spec-acceptance-criterion-10 — every registered provider resolves to services with its id and the parts its descriptor declares, every provider folder is registered, and ids are unique.
- existing test `packages/providers/tests/providers.test.ts` › "reads the id builds before `anthropic` stored, and keeps writing it" — design-doc-decision-4, spec-acceptance-criterion-16 — the stored-id exception and the identity default.
- existing tests `packages/common/lib/tests/ai-settings.test.ts` — design-doc-decision-4, spec-acceptance-criterion-16 — configs stay where builds of every version read them. The tests: "stores an accepted key where every build reads it…", "keeps a subscription token in its own section…", "replaces a ChatGPT sign-in with an OpenAI API key" (the per-id section), "keeps the WordPress.com config in the Studio sign-in…", "reads legacy values from cli.json…", and "selects only a connected provider, storing the id older builds read".
- existing tests `packages/common/lib/tests/remote-sites.test.ts` — design-doc-decision-4, spec-acceptance-criterion-16 — connections stay in `connectedWpcomSites` for WordPress.com and in `remoteSites` for others, and are forgotten with the local site. The tests: "keeps the Spaces a site publishes to, and forgets them with the site" and "records each sync and keeps the times of the others".
- new test at `@studio/agent/shared/models` (`createConnectionStream`) — design-doc-decision-6, spec-acceptance-criterion-14 — a connection naming an API outside the four ends with an error naming the API, and no request goes out.
- existing tests `packages/agent/browser/tests/gemini-stream.test.ts` and `packages/agent/node/runtime/tests/pi-runtime.test.ts` › "streams with the connection's upstream model and error rewrite" — design-doc-decision-6, spec-acceptance-criterion-13 — connections over the supported APIs still stream in both runtimes.
- existing test suites of `packages/common`, `packages/agent`, `apps/cli`, `apps/studio` and `apps/ui` (`npm test`), with the three test files of design-doc-decision-8 deriving from the registry — design-doc-decision-8, spec-acceptance-criterion-17 — the six providers behave as before in connecting, selection, fallback, models, images and publishing.
- end-to-end flow — design-doc-decision-1, design-doc-decision-2, design-doc-decision-5, design-doc-decision-8, design-doc-decision-10, spec-acceptance-criterion-1, spec-acceptance-criterion-2, spec-acceptance-criterion-11 — following only the README, a sample chat provider (API key form, one of the four APIs) and a sample sites provider (device sign-in) each change only their folder and one registration entry. `npm run typecheck`, ESLint on the changed files, `npm run knip` and `npm test` pass.
- end-to-end flow — design-doc-decision-5, spec-acceptance-criterion-15 — with the lint configuration unchanged, ESLint on a sample provider's folder reports:
  - a descriptor or config importing its services;
  - a Node API import;
  - another workspace package's import.

  It reports nothing for a folder within the boundaries.
- end-to-end flow in `studio ui` and Studio on the web, and in the Desktop app where it runs — design-doc-decision-1, design-doc-decision-4, design-doc-decision-6, spec-acceptance-criterion-3, spec-acceptance-criterion-13 — the sample chat provider meets each point of spec-acceptance-criterion-3 in each app, and its replies stream over its API.
- end-to-end flow in `studio code` — design-doc-decision-1, design-doc-decision-4, spec-acceptance-criterion-4 — `/connect`, `/provider`, `/model`, a restart and `/disconnect` with the sample chat provider.
- end-to-end flow in `studio ui` and the Desktop app's settings and publish panel, and `studio push --remote-site <id>` — design-doc-decision-1, design-doc-decision-4, spec-acceptance-criterion-5, spec-acceptance-criterion-6 — the sample sites provider, and a sample offering both capabilities connected once, appear and publish as the criteria say.
- end-to-end flow in Studio on the web — design-doc-decision-7 — with a sample archive-publishing provider registered, the publish tab and Settings' hosting providers offer WordPress.com only, as before.
- end-to-end flow — design-doc-decision-3, spec-acceptance-criterion-7, spec-acceptance-criterion-8 — sample providers with a device sign-in, a loopback sign-in, several methods, a narrowed model set, image generation, and an expiring credential behave as declared in Settings, the chat model picker, `/model` and a chat.
- end-to-end flow — design-doc-decision-4, spec-acceptance-criterion-16 — a `shared.json`, session entries and Studio on the web settings written by the base build are read by the new build in Settings, `studio code` and the publish panel with the same accounts, defaults, connections and pins. What the new build then stores is read back by the base build the same way.
- inspection — design-doc-decision-9, spec-acceptance-criterion-12 — every value of the contract states its meaning, whether a new provider supplies it or acts on it, and what Studio does with it, and each WordPress.com-only part says so.
- inspection — design-doc-decision-10, spec-acceptance-criterion-11 — the README covers each point the criterion lists, in agreement with the contract.
- inspection of the Desktop main bundle — design-doc-decision-2 — it includes every provider folder's services (design-doc-assumption-1).

## Risks

- **A provider folder without `services.ts`** passes typecheck and lint. The package tests and the first connect or chat report it, naming the provider. spec-requirement-3 asks typecheck or lint to report it, and here only the tests do. This is design-doc-decision-2's trade-off.
- **Services written without the services helper** escape the type check of their parts. The package's registry test reports a missing part, at test time instead of typecheck.
- **A provider offering both chat models and remote sites** gets two palette entries with the same setting target. The hosting entry lands on its AI provider row. It is the same provider and connection, so spec-acceptance-criterion-6 still holds.
- **On Studio on the web, a form-connected provider whose credential expires** is not renewed in the page, which reads stored configs without a refresh, as today. It shows as disconnected once the credential expires. No provider connects that way on the web today.
- **A new provider whose `piProvider` reuses a name pi knows** may get pi's provider-specific handling, such as Anthropic's token detection. The contract documents the name (design-doc-decision-9).
- **Error messages from the capability-linked types** may be longer than a plain missing-property error (design-doc-assumption-2).

## Open assumptions

design-doc-assumption-1: The Desktop main build (electron-vite 6 on Vite 8) resolves `import.meta.glob` in `@studio/providers/services` the way the CLI and Studio on the web builds do — assumed: the Desktop main build's bundle includes every provider folder's services, and connecting a provider from the Desktop app's Settings works.

design-doc-assumption-2: Typecheck reports a missing capability part, an extra one, and an unregistered id in the provider's `services.ts`, naming the part or the id — assumed: the type tests of design-doc-decision-3 and the sample-provider flow show the errors at that location with those names.

design-doc-assumption-3: Every TypeScript program that reaches the services entry, in `apps/cli`, `apps/local`, `apps/studio`, `apps/static`, `packages/agent` and `packages/providers`, accepts `vite/client` types without conflict — assumed: `npm run typecheck` passes with the services entry discovering folders.

design-doc-assumption-4: An error that the connection stream raises before any request reaches the user as the chat's error, in both the Node runtime and the browser agent — assumed: the new `createConnectionStream` test, plus a chat on a sample connection naming another API in `studio code` and in Studio on the web, shows the error naming the API.

design-doc-assumption-5: TypeScript derives the id unions, type maps and `AiModelId` from the registration's inferred descriptor types without a circular reference, as long as provider code references only the contract and its own types — assumed: `npm run typecheck` passes with the registration as the only source of those types.
