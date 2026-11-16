# Design Doc: A provider is its folder

## Overview

Today a provider exists in Studio only once it is written into hand-maintained lists. Inside `@studio/providers` these are the id and model-id unions, the per-provider type maps, and the id lists and maps (`ProviderId`, `AiProviderId`, `AiModelId`, `ProviderConfigs`, `ProviderSites`, `AI_PROVIDER_IDS`, `SITES_PROVIDER_IDS`, `PROVIDER_IDS`, `PROVIDERS`, `STORED_PROVIDER_IDS`, `SERVICES`). Outside it they are Studio's per-provider config and connection stores in `@studio/common`, the folder list of the lint boundary, and code typed over every provider id, which fails typecheck in other packages when a provider is added. A provider left out of `AI_PROVIDER_IDS` passes every check and appears in no surface. A provider's descriptor and services declare their capabilities independently, so models without a model connection are found only when a chat starts. The contract mixes in parts only WordPress.com uses without saying so, and the agent sends any model API it doesn't recognize as `openai-responses`.

After the change, a provider keeps its two halves: the descriptor that surfaces read and the services that hosts run, each in its own module of the provider's folder. Each of the package's two entries finds its half of every provider from the folders at build time, as `@studio/agent` finds its skills, so adding a provider is adding its folder, with no registration and no shared file to edit. The descriptor declares the provider's id. Studio picks providers in a fixed order: the six existing ones first, in today's order, then every other provider by id. To the rest of Studio, provider ids, model ids, configs and remote sites are data, and only WordPress.com keeps its own types, by name. No type outside the package depends on which providers exist, so adding one never fails a check there. Typecheck checks a provider against itself through the two helpers it declares its halves with, and the package's tests check every discovered provider, however it was declared. Studio stores any provider by default, the lint boundary matches provider folders by pattern, the agent runs exactly the four model APIs the contract names, and Studio on the web publishes only to WordPress.com. The contract and the README document the whole API.

## Architecture

New or reshaped inside `@studio/providers`:

- **A provider's folder** (`packages/providers/<folder>/`) holds:
  - its config schema (`config.ts`);
  - its descriptor module (`descriptor.ts`), the browser-safe data surfaces read;
  - its services module (`services.ts`), which hosts run;
  - its own modules and its `tests/`.

  The descriptor and the services each export their half under one name, the same in every folder. The descriptor and config import only each other and the package's shared surface files. No file of the folder imports another workspace package or a Node API, and a provider never reads or writes storage.
- **The registry** (`registry.ts`, in the surface entry) collects every folder's descriptor at build time and orders them. From that order it provides:
  - the runtime lists `PROVIDER_IDS`, `AI_PROVIDER_IDS` and `SITES_PROVIDER_IDS`;
  - `getProvider` and `getProviderSites`;
  - `normalizeProviderId` and `toStoredProviderId`, whose one exception is Anthropic's legacy stored id;
  - `formatRemoteSite` and `parseRemoteSite`.
- **The services entry** (`services.ts`) collects every folder's services at build time and provides `getProviderServices`.
- **The contract** (`types.ts`) holds:
  - the two authoring helpers a provider declares its halves with, which check its services against its own descriptor;
  - the consumer types surfaces and hosts read;
  - the union of model APIs Studio runs;
  - the reference documentation of every value.
- **Models** (`models.ts`): `findAiModel`, `getAiModels` and `getDefaultAiModel`, over the registry's order.
- **The package's own tests** (`packages/providers/tests/`): the checks of every discovered provider (design-doc-decision-4).

Changed once outside the package, so that a later provider needs no change there:

- `eslint.config.mjs`: the surface boundary of `@studio/providers` matches any provider folder by pattern.
- `@studio/common/lib/provider-config.ts` and `@studio/common/lib/remote-sites.ts` store any provider by default. Each keeps an override only where builds of every version read a legacy field.
- `@studio/agent/shared/models.ts`: a stream for each of the four model APIs, and a failed turn for a connection that names any other API.
- `apps/ui` (`data/queries/use-remote-sites.ts`, `data/settings-sections.ts`): a host without native sites offers only WordPress.com for publishing.
- Code typed with the removed id and map types, in `@studio/common`, `@studio/agent`, `apps/cli`, `apps/local`, `apps/studio`, `apps/static` and `apps/ui`, names `ProviderId`, `ProviderConfig< Id >` and `ProviderSite< Id >` instead. These are type-level changes.
- The tests outside the package that enumerate every provider's account: `packages/common/lib/tests/ai-settings.test.ts` and `packages/agent/protocol/sessions/tests/model.test.ts`.
- `packages/providers/README.md` and `docs/design-docs/providers.md`.

Untouched but relevant, because they already build everything from the runtime lists and the descriptors:

- the settings' provider rows and defaults (`apps/ui/src/features/settings/settings-view/`), with the generic row and the fallback to the descriptor's logo;
- the model picker and model access (`apps/ui/src/features/composer/`);
- `studio code`'s `/connect`, `/disconnect`, `/provider` and `/model` (`apps/cli/ai/slash-commands.ts`, `apps/cli/lib/providers.ts`);
- the resolution of the AI connection and the image generator (`apps/cli/ai/auth.ts`, `apps/cli/ai/host.ts`);
- `studio push` (`apps/cli/commands/push.ts`);
- the Desktop and `studio ui` handlers, which normalize the ids they receive against the runtime lists (`apps/studio/src/**/ipc-handlers.ts`, `apps/local/src/index.ts`);
- Studio on the web's per-id configs and settings (`apps/static/src/agent/index.ts`);
- the `shared.json` schema (`packages/common/lib/shared-config.ts`).

Data flow:

- At build time, Vite expands each entry's discovery into the provider folders' modules. `apps/ui` bundles descriptors only, and the hosts bundle descriptors and services.
- Surfaces read the runtime lists and the descriptors: lists, labels, connect forms, models and how remote sites are presented.
- A host asks the services entry for a provider's services by id. It hands them the config Studio reads from its store, and stores any config they return under the provider's id.
- The CLI, the Desktop main process and `studio ui` publish to any sites provider through `studio push`. Studio on the web publishes only to WordPress.com.
- A turn's model connection passes through the agent's stream, which runs it over its API or rejects it.

## Decisions

design-doc-decision-1: Each entry discovers its half of every provider from the package's folders, in Studio's order

**Serves:** spec-requirement-1, spec-requirement-2, spec-requirement-3, spec-requirement-9, spec-acceptance-criterion-1, spec-acceptance-criterion-2, spec-acceptance-criterion-5, spec-acceptance-criterion-6, spec-acceptance-criterion-10, spec-acceptance-criterion-17
**Decision:**
- A provider folder is a top-level folder of the package that holds a descriptor module. Its services module sits beside it.
- The surface entry (`@studio/providers`) collects every folder's descriptor, and the services entry (`@studio/providers/services`) every folder's services. Both use Vite's build-time glob import, as `@studio/agent` collects its skills, and neither lists a provider. The surface entry never reaches a services module, so `apps/ui` bundles descriptors only, as today.
- The descriptor declares the provider's id, which Studio stores. `getProvider( id )` returns the descriptor that declares `id`. `getProviderServices( id )` returns the services beside it, carrying the same id.
- Studio picks providers in one order: WordPress.com, Anthropic, OpenAI, Google Gemini, GitHub Copilot and Spacefast first, in today's order, then every other provider by id.
  - `PROVIDER_IDS` is that order.
  - `AI_PROVIDER_IDS` and `SITES_PROVIDER_IDS` filter it by the capability each descriptor declares. A provider that declares both is in both lists under one id, so one connection serves both.
  - `findAiModel` returns the first provider in that order that lists the model, so a model id a new provider shares keeps resolving to the existing provider's listing, and WordPress.com stays first wherever Studio picks the first connected or ready provider.
- `getProvider` and `getProviderServices` stay synchronous. For an id no descriptor declares, each throws an error that names the id. For a descriptor with no services beside it, `getProviderServices` throws an error that names the provider and the module it expects.
- Removed: the descriptor and services maps, the hand-written id lists, the id and model-id unions, and `types.ts`'s imports of each folder's config and site types.

**Alternatives:**
- One hand-written, ordered registration of descriptors, from which literal id unions derive, with services found by the glob. Not taken: every provider stays an edit to a shared file, and the literal unions keep Studio's types tied to the set of providers, the cause design-doc-decision-2 removes.
- A committed index of both halves that a package script writes from the folders, keeping literal unions and static imports. Not taken: the developer must remember a command, two branches that each add a provider conflict in the index, and the repository commits no generated source today. Its gain is the literal unions design-doc-decision-2 drops.
- Providers held only by Studio's hosts as one value each, with `apps/ui` rendering a catalog its host serves. Not taken: it would move 78 provider reads in `apps/ui`, the publish panel's per-site presentation and provider text's locale behind every connector. That brings a load at start that today's synchronous descriptors never show, and per-request locales to the `studio ui` server, which loads its locale once. Its gain, a provider that can't declare a capability without the code that serves it, the services helper's check gives (design-doc-decision-3).
- The folder's name as the provider's id, with no id in provider code. Rejected: renaming a folder would change a stored id, and the descriptor helper couldn't tell WordPress.com's descriptor from another's to reject the Studio sign-in at typecheck (design-doc-decision-10).
- Discovery ordered by folder name alone. Rejected: OpenAI would follow GitHub Copilot, so `findAiModel( 'gpt-6.1-terra' )`, which the eval harness picks a model's provider by, would return GitHub Copilot, and Settings would reorder their rows (spec-requirement-9).
- An order rank each descriptor declares. Rejected: every new provider would have to pick one, and two equal ranks still need a rule.
- A lazy `import()` of each folder's services. Rejected: `getProviderServices` would become asynchronous for every caller, including the module-level ones, `apps/ui` would bundle the services as chunks, and the lint boundary reports dynamic imports.

**Trade-offs:**
- Both entries depend on Vite's transform. A program that loads the package without Vite fails when it imports it. Every program that reaches the package today builds or tests through Vite.
- A missing services module is reported by the package's tests and, at run time, by `getProviderServices`, not by typecheck as today's exhaustive map reports it.
- The order names the six existing providers in a list that is never edited for a new one.

**Claims:**
- observed: read `packages/providers/registry.ts:17-84`, `services.ts:9-24`, `models.ts:9-15` and `types.ts:1-45`, the lists, unions and maps a provider is written into today.
- observed: `@studio/agent` discovers files this way, in code the CLI and Studio on the web run (read `packages/agent/shared/skills.ts:1-18`), and Vitest resolves it: `packages/agent/node/tests/plugin-skills.test.ts` passes against it (`.pipelines/providers-api-for-external-devs-v2/2-design-doc/design-doc/vitest-glob.txt`).
- observed: every build and test run that reaches the package goes through Vite (`.pipelines/providers-api-for-external-devs-v2/2-design-doc/design-doc/vite-glob-in-every-build.txt`):
  - Vite 8.3.5 adds its glob-import plugin to every build's plugin list unconditionally;
  - electron-vite 6.0.0 builds the Desktop main process as a Vite SSR build that bundles every dependency, with `@studio/providers` aliased to its source;
  - the CLI bundles the `@studio/*` packages, which it lists as dev dependencies;
  - the test projects alias the package to its source;
  - `scripts/` and `tools/capture-harness` don't reach the package, and `apps/mcp-ui` doesn't depend on it.
- observed: every program that will reach the discovering files typechecks with Vite's client types loaded, and `apps/cli`, `apps/static`, `apps/ui` and `packages/agent` load them today (`.pipelines/providers-api-for-external-devs-v2/2-design-doc/design-doc/vite-client-types.txt`).
- observed: knip enables its Vite plugin for `packages/providers`, and treats the targets of a non-raw `import.meta.glob` as entries without analyzing their exports (`.pipelines/providers-api-for-external-devs/2-design-doc/design-doc/knip-vite-glob.txt`).
- observed: no file in a provider folder imports the registry or models at run time, only types, so collecting the descriptors from the registry makes no import cycle (`.pipelines/providers-api-for-external-devs-v2/2-design-doc/design-doc/provider-typed-consumers.txt`).
- observed: today's orders. `AI_PROVIDER_IDS` is wpcom, anthropic, openai, gemini and github-copilot; `PROVIDER_IDS` adds spacefast; `SITES_PROVIDER_IDS` is wpcom and spacefast (read `registry.ts:17-35`). `findAiModel` returns the first provider that lists an id (read `models.ts:30-41`), the eval harness picks a model's provider through it (read `apps/cli/ai/eval-harnesses/studio.ts:157-160`), and the CLI falls back to the first connected provider in `AI_PROVIDER_IDS` order (read `apps/cli/ai/auth.ts:39-48`).
- observed: `apps/ui` reads provider values on 78 lines, the publish panel runs each site's presentation functions in the page, and the `studio ui` server loads its locale once at start (`.pipelines/providers-api-for-external-devs-v2/2-design-doc/design-doc/providers-in-apps-ui.txt` §1, §7 and §8).
- observed: the repository commits no generated TypeScript source (`.pipelines/providers-api-for-external-devs-v2/2-design-doc/design-doc/closed-types-and-generated-code.txt`).
- observed: the code these observations read is unchanged at this design's base (`.pipelines/providers-api-for-external-devs-v2/2-design-doc/design-doc/code-unchanged.txt`).
- assumed: the Desktop main build bundles every folder's descriptor and services; see design-doc-assumption-4.

design-doc-decision-2: To Studio, provider ids, model ids, configs and sites are data, and only WordPress.com keeps its own types, by name

**Serves:** spec-requirement-1, spec-requirement-2, spec-requirement-3, spec-acceptance-criterion-1, spec-acceptance-criterion-2, spec-acceptance-criterion-10
**Decision:**
- `ProviderId` and `AiModelId` are strings. Which providers exist and what each offers is runtime data: `PROVIDER_IDS`, `AI_PROVIDER_IDS`, `SITES_PROVIDER_IDS` and the descriptors.
- `AiProviderId`, `SitesProviderId`, `ProviderConfigs` and `ProviderSites` are removed. Code that used them names `ProviderId`, and reads which capability a provider offers from the lists.
- `ProviderConfig< Id >` and `ProviderSite< Id >` are WordPress.com's config and `SyncSite` when `Id` is `'wpcom'`. For any other id they are `unknown` and the base `RemoteSite`. They type the results of:
  - `getProvider` and `getProviderServices`;
  - Studio's functions keyed by a provider id: `readProviderConfig`, `writeProviderConfig`, `getRemoteSites`, `rememberRemoteSite`, `forgetRemoteSite`, `listAccountSites` and `createRemoteSite`;
  - the remote-site hooks and connector methods of `apps/ui`.

  Code that names WordPress.com keeps WordPress.com's types, and code that handles any provider handles the base types.
- `AiSettings.accounts` is keyed by `ProviderId`, and still holds an account for every provider the app lists.
- Outside the package, this decision changes types only. Hosts keep validating the ids they receive and read from storage against the runtime lists, as they do today.

**Alternatives:**
- Literal id unions and type maps derived from the providers. Not taken: a glob gives typecheck no provider's types, so they need a registration or a generated index (design-doc-decision-1). They also keep types outside the package tied to the set of providers. Six constructs outside the package are typed over every provider id today, and every typecheck failure the probe saw outside the package came from one of them.
- Keeping `AiProviderId` and `SitesProviderId` as aliases of `string`. Not taken: they would read as a narrowing the types no longer make. The runtime lists are the check.
- A typed map of the six existing providers' configs and sites. Rejected: it would be a second list, which new providers never enter, and no code outside the package reads another provider's own site fields.

**Trade-offs:**
- Studio's code loses compile-time checks that the closed unions gave: a misspelled literal id, such as `getProvider( 'wpcmo' )`, compiles and throws the first time it runs, and an AI-only provider's id passed where a sites provider is required compiles too. Studio's code passes a literal id only for WordPress.com, for Spacefast in its settings row, and in tests. Hosts already check ids and requested models at run time.
- The one-time change touches the code typed with the closed types: `ProviderId` on 94 lines outside the package, `AiProviderId` on 47, `SitesProviderId` on 93, `ProviderConfigs` on 17, `ProviderSites` on 30 and `AiModelId` on 72.
- The config store's Anthropic override reads Anthropic's API-key method from a config it receives as `unknown`.

**Claims:**
- observed: six constructs outside the package are typed over every provider id. Every typecheck failure the probe saw outside the package came from such a construct (`.pipelines/providers-api-for-external-devs-v2/2-design-doc/design-doc/provider-typed-consumers.txt` and `.pipelines/providers-api-for-external-devs/1-spec/spec/probe/2-registered-repo-typecheck.txt`).
- observed: the closed types' line counts outside the package, and no exhaustiveness checks (`satisfies never`, `assertNever`) over them (`.pipelines/providers-api-for-external-devs-v2/2-design-doc/design-doc/closed-types-and-generated-code.txt`).
- observed: every call outside the package that names one provider and reads its own types names WordPress.com, except Spacefast's settings row, which reads only descriptor data. No code outside the package reads a Space's own fields (`.pipelines/providers-api-for-external-devs-v2/2-design-doc/design-doc/provider-typed-consumers.txt`). The config store's Anthropic override reads Anthropic's `method` and `apiKey` (`.pipelines/providers-api-for-external-devs-v2/2-design-doc/design-doc/code-unchanged.txt`).
- observed: hosts validate the ids they receive against the runtime lists (`.pipelines/providers-api-for-external-devs-v2/2-design-doc/design-doc/provider-typed-consumers.txt`). Readers normalize stored and recorded ids through those lists (read `packages/agent/protocol/sessions/model.ts:81-93`, `packages/common/lib/ai-settings.ts:34-37` and `packages/common/lib/user-settings/user-preferences.ts:191-195`).

design-doc-decision-3: A provider is checked against itself: its services are typed against its own descriptor

**Serves:** spec-requirement-3, spec-requirement-1, spec-acceptance-criterion-7, spec-acceptance-criterion-8, spec-acceptance-criterion-9
**Decision:** The contract offers two authoring helpers.

The descriptor helper infers from the provider's own descriptor:
- its literal id;
- its config type, site type and model ids;
- which capabilities it declares;
- the kinds of its connect methods.

Within it, `ai.defaultModel`, `ai.paidDefaultModel` and `AccountDetails.models` accept only the provider's own model ids, and a `redirect` connect method is accepted only where the id is WordPress.com's (design-doc-decision-10).

The services helper takes the folder's descriptor and requires exactly the parts that descriptor declares:
- `account.connect`, always;
- `account.start`, when a connect method is a `device` or `loopback` sign-in;
- `ai.model`, when the descriptor declares `ai`;
- `sites.list` and `sites.push`, when it declares `sites`;
- `sites.create`, when `sites.newSite` is `create`;
- `sites.pull`, when `sites.pull` is true;
- no `ai` or `sites` part for a capability the descriptor doesn't declare.

`account.refresh`, `account.disconnect`, `ai.generateImages` and `ai.canGenerateImages` stay optional, and image generation stays part of `ai`. Typecheck therefore reports a missing part, or a part for an undeclared capability, in the provider's services module, naming the part.

The helpers' types are local to the provider: they reference no type derived from the set of providers. The consumer types (`Provider`, `ProviderServices`, `AccountDetails` and the rest) keep their names and shapes. The six existing providers move to the helpers.

**Alternatives:**
- `satisfies` or an annotation with the consumer types on plain objects. Rejected: they cannot tie a default model to the provider's own models, or services to their descriptor, unless the developer writes the type arguments by hand.
- Today's descriptor and services capabilities, optional independently of each other. Rejected: they let a provider list models with no model connection, which is reported only as "offers no AI models" when a chat starts.
- One provider value in which each part carries its code, so completeness is the value's shape. Not taken: surfaces would import the services with it, against spec-requirement-7's third boundary, unless providers left `apps/ui` (design-doc-decision-1).
- Only design-doc-decision-4's run-time check. Not taken alone: its report sits in `npm test`'s output, not at the line of the provider's file. It stays as the check for halves written without the helpers.
- Image generation as a capability of its own. Not taken: no provider or source shows a service that offers images without chat models.

**Trade-offs:** The helpers' types depend on the descriptor, so a typecheck error can be longer than a plain missing-property error (design-doc-assumption-1). Halves written without the helpers escape this check, and design-doc-decision-4 reports what they lack.
**Claims:**
- observed: the descriptor's and the services' capabilities are optional independently of each other (read `packages/providers/types.ts:173-179` and `305-320`). A missing model connection shows as "offers no AI models" at chat time (read `apps/cli/ai/auth.ts:84-91`).
- observed: the providers that connect with a device or loopback sign-in (OpenAI, GitHub Copilot, Spacefast) implement `account.start`, and the form and redirect providers don't (`.pipelines/providers-api-for-external-devs/2-design-doc/design-doc/observations.txt`).
- observed: `defaultModel`, `paidDefaultModel` and `AccountDetails.models` are typed as the global `AiModelId` (read `types.ts:97,173-178`), and image generation is an optional part of `ProviderServices.ai` (read `types.ts:305-319`).
- observed: each descriptor states its id as a literal (`.pipelines/providers-api-for-external-devs-v2/2-design-doc/design-doc/provider-typed-consumers.txt`).
- assumed: each omitted or extra part, a foreign default model and a `redirect` method outside WordPress.com are reported where this decision says, naming them; see design-doc-assumption-1.

design-doc-decision-4: The package's tests check every discovered provider

**Serves:** spec-requirement-3, spec-requirement-5, spec-requirement-9, spec-acceptance-criterion-9, spec-acceptance-criterion-10, spec-acceptance-criterion-12, spec-acceptance-criterion-17
**Decision:** The package's own tests, which `npm test` runs, check what the two entries discover. Each failure names the provider's folder, the module and what is missing or wrong:
- a folder whose descriptor has no services beside it, or whose services have no descriptor;
- services that lack a part their descriptor needs, or hold a part for a capability it doesn't declare, as design-doc-decision-3 lists them, whether or not they were declared through the helper;
- two descriptors that declare the same id;
- a `redirect` connect method in any descriptor but WordPress.com's (design-doc-decision-10);
- lists whose head isn't the six existing providers in today's order, or that differ from today's for those six.

A module the discovery misses, such as a misnamed descriptor, is a file nothing imports, which `npm run knip` reports at that file. Adding a provider never changes these tests. A provider that passes them, with typecheck, is in every list its descriptor's capabilities reach, and has services that hold every part those capabilities need.
**Alternatives:**
- A rule in `eslint-plugin-studio` that reads each folder and reports in the developer's descriptor or services module. Not taken: it is infrastructure outside the package whose result for one file depends on other files, and it would check how the services are written rather than what they hold. Its one gain is a report at a line of the developer's file, where the tests name that file.
- A type-level check that every discovered folder has services. Rejected: Vite's glob types are assertions, so a build-time discovery gives typecheck nothing to check.
- No run-time check, relying on the helpers. Rejected: halves written without the helpers would typecheck while lacking a part, and the provider would show in surfaces that then fail, against spec-acceptance-criterion-9.

**Trade-offs:** The report appears in `npm test`'s output, not at a line of the provider's file. The parts each capability and connect method needs are stated twice, in the helper's types and in this check. A part added to one and not the other weakens only the check of services written without the helper.
**Claims:**
- observed: `npm test` runs `vitest run` over the projects of `vitest.config.ts`, which include `packages/providers/vitest.config.ts` and its `**/*.test.ts` (read `package.json:62`, `vitest.config.ts:4-20` and `packages/providers/vitest.config.ts`).
- observed: the package's tests may use Node APIs, since the boundary rules ignore `packages/providers/**/tests/**` (read `eslint.config.mjs:413-414`).
- observed: knip reports a file of a provider folder that nothing imports as an unused file, at that file (`.pipelines/providers-api-for-external-devs-v2/2-design-doc/design-doc/knip-and-indexer-probe.txt`).
- assumed: each failure names the folder, the module and the part; see design-doc-assumption-3.

design-doc-decision-5: Studio stores any provider's config and remote-site connections in the shared sections by default

**Serves:** spec-requirement-1, spec-requirement-2, spec-requirement-8, spec-acceptance-criterion-2, spec-acceptance-criterion-3, spec-acceptance-criterion-4, spec-acceptance-criterion-5, spec-acceptance-criterion-6, spec-acceptance-criterion-8, spec-acceptance-criterion-16
**Decision:** The config store resolves any provider to its `providerConfigs.<id>` section. Two providers override that, and their storage doesn't change:
- WordPress.com stays in `authToken`, the Studio sign-in;
- Anthropic keeps an API key in `anthropicApiKey`, with today's fallback to `cli.json`, and its subscription token in `providerConfigs.anthropic`.

The remote-site connection store resolves any sites provider to `remoteSites` entries tagged with its id. Each entry keeps the site as the provider returned it, with Studio's sync times. Only WordPress.com overrides that, with `connectedWpcomSites`. Forgetting a local site's connections covers every provider in `SITES_PROVIDER_IDS`.

The stored-id mapping keeps one exception, Anthropic's `anthropic-api-key`. Every other provider is stored under its id, so `normalizeProviderId` and `toStoredProviderId` behave as today. Several parts already work for any id and don't change:
- renewal, and the forgetting of a config the provider rejects;
- `rememberedSignIns` and `signInHostId`;
- the default hosting provider;
- Studio on the web's per-id configs.

The overrides are Studio's storage, not part of the provider contract. Every write still goes through `shared.json`'s lock, and renewal through its per-provider lock, as today. The exhaustive per-provider store maps are removed.
**Alternatives:**
- A storage field the descriptor declares, such as a legacy field name. Rejected: it puts storage into the provider contract, against "Providers own no storage" (`docs/design-docs/providers.md`, principle 5), and only two providers would ever use it.
- Store maps keyed by every provider id that fall back to the default. Rejected: with design-doc-decision-2's string ids, they would no longer be checked for completeness, so they would only list the providers that use the default.
- Migrating every account into one new format. Rejected: builds from before the change would no longer read what new builds write (spec-requirement-8).

**Trade-offs:** A new provider never gets a storage field of its own, only its section. OpenAI, Google Gemini, GitHub Copilot and Spacefast are stored this way today.
**Claims:**
- observed: OpenAI, Google Gemini, GitHub Copilot and Spacefast use the per-id section the default would, and a provider added to the package fails typecheck at the exhaustive config store map (read `packages/common/lib/provider-config.ts:64-144`, and `.pipelines/providers-api-for-external-devs/1-spec/spec/probe/2-registered-repo-typecheck.txt`).
- observed: Spacefast's connection store is the generic store, which keeps the site as given (read `packages/common/lib/remote-sites.ts:69-133`).
- observed: every stored id equals the provider's id except Anthropic's (read `packages/providers/registry.ts:62-84`).
- observed: in `shared.json`, `providerConfigs`, `rememberedSignIns` and `remoteSites` are keyed by plain strings, and `aiProvider` is a plain string, so older builds keep parsing a file that names a provider they don't know (read `packages/common/lib/shared-config.ts:54-84`).
- observed: an unknown `defaultHostingProvider` reads back as no preference (read `packages/common/lib/user-settings/user-preferences.ts:191-195`).

design-doc-decision-6: The package's lint boundary matches provider folders by pattern

**Serves:** spec-requirement-7, spec-requirement-1, spec-acceptance-criterion-15
**Decision:** In `eslint.config.mjs`, the surface boundary of `@studio/providers` matches any provider folder by pattern, not by a list of names. Its restricted zone covers the package. Its exceptions are:
- the package's shared surface files;
- any folder's `descriptor.ts` and `config.ts`;
- WordPress.com's `sites/site.ts`.

The part of a provider that surfaces read is therefore its descriptor and config. With nothing outside the package changed, ESLint:
- reports, at the import, a surface file of any folder that imports anything else;
- lets a folder's descriptor import its own config.

The rules against Node APIs and other workspace packages already cover every file in the package and stay as they are. Each report lands in the provider's own file, which ESLint on the changed files covers. The discovery of design-doc-decision-1 reaches descriptors only from the surface entry and services only from the services entry, so it never carries a services module into what surfaces read.
**Alternatives:**
- Generating the folder list from the file system in `eslint.config.mjs`, as the config already does for `apps/ui`'s layers. Rejected: the rule takes glob exceptions directly, and a pattern doesn't depend on which folders exist when lint starts.
- A package test that checks each provider file's imports. Not taken: ESLint's existing rules already report each crossing at the import that crosses it.

**Trade-offs:** A provider's descriptor may import another provider's descriptor or config, as the six may today. A descriptor that imports a data module of its own folder other than its config is reported, so the README tells a developer to keep what surfaces read in those two files.
**Claims:**
- observed: the boundary's exceptions list the six folders by name (read `eslint.config.mjs:33-45,433-457`).
- observed: every descriptor imports only its own config, the package's shared surface files and npm packages, and WordPress.com's also imports `wpcom/sites/site.ts` (read the imports of `packages/providers/*/descriptor.ts`).
- observed: `import-x/no-restricted-paths` accepts glob exceptions when the zone's `from` is a glob, and matches them against the imported file's absolute path (eslint-plugin-import-x 4.17.1, `.pipelines/providers-api-for-external-devs/2-design-doc/design-doc/lint-restricted-paths.txt`).
- observed: the rules against Node APIs and workspace packages match `packages/providers/**/*.ts` and ignore only `tests/` (read `eslint.config.mjs:410-431`).

design-doc-decision-7: The contract names the four model APIs, and the agent runs exactly those

**Serves:** spec-requirement-6, spec-acceptance-criterion-3, spec-acceptance-criterion-4, spec-acceptance-criterion-13, spec-acceptance-criterion-14
**Decision:** The contract defines the model APIs Studio runs as a union: `openai-completions`, `openai-responses`, `anthropic-messages` and `google-generative-ai`. `AiConnection.model` is typed to that union, so a provider whose connection names any other API fails typecheck in its folder, with the API named.

In `@studio/agent/shared/models.ts`, the connection stream has one stream for each API in the union, and the agent fails typecheck if the union gains an API without one. A connection that names an API outside the union, for example one cast past the types, ends the turn with an error that names the API, and no request is sent. The Node runtime and the browser agent both stream through this code. GitHub Copilot reads its models from pi's catalog under pi's wider `Api` type, so it narrows them to the union in its own folder.
**Alternatives:**
- Keeping the `openai-responses` fallback, with only the narrowed type. Rejected: spec-requirement-6 forbids sending a request over a different API.
- A runtime check only, with no narrowed type. Rejected: nothing reports the API until a user chats.
- A check in each host that resolves a connection (`apps/cli/ai/auth.ts`, `apps/static/src/agent/index.ts`, the eval harness). Rejected: the one stream every turn passes through covers them all.

**Trade-offs:** Adding a fifth API is Studio's decision: it changes the union and the agent together (spec-exclusion-3).
**Claims:**
- observed: `openai-completions`, `anthropic-messages` and `google-generative-ai` get their own stream, and any other API goes to `openai-responses` (read `packages/agent/shared/models.ts:17-29`).
- observed: every existing connection names one of the four APIs (pi 1.5.0's catalogs and the WordPress.com tiers, `.pipelines/providers-api-for-external-devs/2-design-doc/design-doc/model-apis.txt`).
- observed: both runtimes stream through `createConnectionStream` (read `packages/agent/node/runtime/index.ts:336-343` and `packages/agent/browser/models.ts:17-26`). GitHub Copilot's connection takes its model from pi's catalog, typed `Model< Api >` (read `packages/providers/github-copilot/ai.ts:36-56`).
- assumed: an error the stream raises before any request reaches the user as the chat's error in both runtimes; see design-doc-assumption-2.

design-doc-decision-8: A host without native sites offers only WordPress.com for publishing

**Serves:** spec-requirement-2, spec-requirement-9, spec-acceptance-criterion-5, spec-acceptance-criterion-17
**Decision:** The providers `apps/ui` offers for publishing depend on the host:
- where the connector has native sites (the Desktop app and `studio ui`), every provider in `SITES_PROVIDER_IDS`, which publish through `studio push`;
- elsewhere (Studio on the web), only WordPress.com, which publishes there through its own sync.

This rule drives the Settings hosting rows, the Default hosting provider select, the publish tab and the command palette's hosting entries. It replaces today's check on static exports, which it covers, since a static export needs native PHP. Studio on the web therefore offers the same publish providers as today, and a new archive provider never shows there as a control its connector would reject.
**Alternatives:**
- A new connector capability that names the hosting providers a host publishes to, or a catalog the host serves. Rejected: it would carry the same information as `nativeSites` in all three connectors.
- Having Studio on the web publish to new archive providers in the page. Not taken: spec-requirement-2's bullet for the web names account, model and image services, and spec-acceptance-criterion-5 names the Desktop app and `studio ui`.

**Trade-offs:** An archive provider whose API accepts calls from a page, which the web could in principle publish to, stays hidden there.
**Claims:**
- observed: today the web offers any sites provider whose content isn't a static export (read `apps/ui/src/data/queries/use-remote-sites.ts:24-31`). Its connection state reads `accounts[ id ]` from the AI settings (read `use-remote-sites.ts:34-52`), which on the web hold AI providers' accounts only (read `apps/static/src/agent/index.ts:261-282`).
- observed: Studio on the web's remote-site methods throw `UnsupportedError` for any provider but WordPress.com (read `apps/ui/src/data/core/connectors/static/index.ts:87-92`).
- observed: off native hosts, the palette hides hosting entries only for providers that publish static exports (read `apps/ui/src/data/settings-sections.ts:320-333`).
- observed: the Settings hosting rows and the publish tab take their providers from `usePublishProviders` (read `apps/ui/src/features/settings/settings-view/providers-panel.tsx:186-192` and `apps/ui/src/features/sync/publish-tab.tsx:44-63`).
- observed: the Desktop app and `studio ui` publish by running `studio push` (read `packages/common/sites/sync.ts:56-79`).

design-doc-decision-9: Tests outside the package hold for any set of providers

**Serves:** spec-requirement-1, spec-acceptance-criterion-1, spec-acceptance-criterion-2, spec-acceptance-criterion-17
**Decision:** With design-doc-decision-2, no test outside the package can be typed over every provider id. The tests whose assertions enumerate every provider's account at run time are `packages/common/lib/tests/ai-settings.test.ts` and `packages/agent/protocol/sessions/tests/model.test.ts`. They build the accounts they compare from the runtime lists, and assert only on the providers they exercise. A discovered provider then adds an account those tests treat as not connected, and changes none of them.
**Alternatives:** Making `AiSettings.accounts` partial, with a missing account meaning not connected. Rejected: every consumer that reads `accounts[ id ].connected` would change, for a fix that belongs in the tests.
**Trade-offs:** A later test outside the package that compares the full set of accounts breaks again when a provider is added. See Risks.
**Claims:**
- observed: with a sample provider listed, four tests failed in `packages/common/lib/tests/ai-settings.test.ts` and `model.test.ts`, on their full accounts (`.pipelines/providers-api-for-external-devs/1-spec/spec/probe/3-listed-tests.txt`).
- observed: the typecheck failures the probe saw in `model.test.ts` and `apps/studio/src/modules/user-settings/lib/tests/settings-tracks.test.ts` were literals of `Record< ProviderId, ProviderAccount >` (`.pipelines/providers-api-for-external-devs/1-spec/spec/probe/2-registered-repo-typecheck.txt`). With string ids, such a literal holds for any set of providers.

design-doc-decision-10: The contract documents every value, and only WordPress.com may declare the Studio sign-in

**Serves:** spec-requirement-5, spec-requirement-3, spec-acceptance-criterion-12
**Decision:** Every field, method, parameter and result of the contract (`types.ts`, `errors.ts` and the helpers of design-doc-decision-3) carries documentation that states:
- what the value means;
- whether a new provider supplies it or acts on it;
- what Studio does with it.

`AiConnection.piProvider` says how pi uses the name. The descriptor's `id` says that Studio stores it, so it never changes.

The `redirect` connect method, the Studio sign-in, is unavailable to a new provider:
- the descriptor helper rejects a `redirect` method in any descriptor whose id isn't WordPress.com's, naming the kind, in that descriptor;
- the package's tests fail when any discovered descriptor but WordPress.com's declares one, naming the folder and the method (design-doc-decision-4);
- the README lists only `form`, `device` and `loopback` for a new provider.

The consumer-facing `ConnectMethod` keeps the kind, so surfaces read WordPress.com's sign-in as today.

The other parts that work for one provider only stay available. Their documentation says they belong to WordPress.com, and what a new provider does with them:
- `requiresPaidAiCredits` and `paidDefaultModel` follow the WordPress.com account's paid credits;
- `push`'s options use the selection format WordPress.com sync defined: a provider without selective sync receives the whole site, and one with it receives what the user picked;
- `list`'s `planRequired` option;
- the `pull` steps, which are remote backups and a Reprint exporter;
- `sites.newSite: 'checkout'`, which is WordPress.com's checkout;
- `hasBackups`.

**Alternatives:**
- Documenting `redirect` as WordPress.com's and leaving it available. Rejected: a new provider that declared it would pass every check. Settings then drop the method and hide the provider when it has no other, and `studio code`'s `/connect` runs the WordPress.com login. The provider would be left out of a surface, against spec-requirement-3.
- Rejecting `redirect` only in the package's tests. Not taken: the descriptor's literal id lets typecheck report it in the developer's descriptor.
- Removing every WordPress.com-only part from the contract a new provider sees, and typing WordPress.com through a wider internal contract. Rejected: these are WordPress.com behaviors Studio keeps (spec-exclusion-6), and consumers read them through the shared types. It would also add a second descriptor type for one provider, and spec-requirement-5 accepts documenting them.

**Trade-offs:** A new provider can still set the documented WordPress.com-only values against their documentation.
**Claims:**
- observed: the CLI connects any `redirect` method by running the WordPress.com login (read `apps/cli/lib/providers.ts:138-152`), and disconnects it by signing out of Studio (read `apps/cli/ai/slash-commands.ts:323-327`).
- observed: Settings drop `redirect` methods, and hide a provider left with no other method (read `apps/ui/src/features/settings/settings-view/ai-panel.tsx:28-33` and `providers-panel.tsx:186-192`).
- observed: only WordPress.com declares a `redirect` method today (`.pipelines/providers-api-for-external-devs/2-design-doc/design-doc/observations.txt`).
- observed: `requiresPaidAiCredits` locks a model on WordPress.com's quota (read `apps/ui/src/features/composer/use-model-access.ts:38-43`).
- observed: the push options, `planRequired` and the pull steps are typed in `packages/providers/types.ts:237-286`, with the options taken from `wpcom/sites/site.ts`, and used through `packages/common/sites/remote-sites.ts:28-38`.
- assumed: the helper's rejection names the kind in the descriptor; see design-doc-assumption-1.

design-doc-decision-11: The package README is the complete guide to adding a provider

**Serves:** spec-requirement-4, spec-acceptance-criterion-1, spec-acceptance-criterion-2, spec-acceptance-criterion-11
**Decision:** The section of `packages/providers/README.md` on adding a provider covers:
- every change a developer makes: one folder in the package, laid out as design-doc-decision-1 says, and nothing else;
- for each capability, the parts a provider fills in, as design-doc-decision-3 requires them;
- the connect methods a new provider can use (`form`, `device`, `loopback`), and the apps that offer each: Studio on the web offers forms only;
- the four model APIs;
- which declared values Studio stores, and that they never change: the provider id, model ids and connect-method ids;
- that a provider's code runs in Node and in the page, and that what surfaces read of it stays in its descriptor and config;
- how to test a provider: its own `tests/`, the package tests that check every discovered provider, and `npm test -- packages/providers`.

`docs/design-docs/providers.md` states the same architecture: providers discovered from their folders, the order, ids as data, the package tests, default storage and the four APIs. Its "Package layout" no longer says a provider is registered. The README points to the contract's reference documentation (design-doc-decision-10) instead of repeating it.
**Alternatives:** A generator command that creates a provider's files. Not taken: the spec's "Considered and not required" leaves it out, and documentation alone meets spec-requirement-4.
**Trade-offs:** The README and the contract can drift. The README states the rules, and the contract documents the values.
**Claims:** observed: today's steps name edits to `types.ts`, `registry.ts`, `services.ts`, `provider-config.ts` and `remote-sites.ts` (read `packages/providers/README.md:57-59`), and `docs/design-docs/providers.md:56` says adding a provider means adding a folder and registering it. The steps leave out `AiProviderId`, the id lists, `STORED_PROVIDER_IDS`, `AiModelId`, the lint folder list and the agent (`.pipelines/providers-api-for-external-devs/1-spec/spec/probe/README.md`).

## Interfaces

**A provider's folder (`packages/providers/<folder>/`)**
- A provider folder is a top-level folder of the package that holds a `descriptor.ts`.
- `config.ts`: the zod schema of what Studio stores for the provider.
- `descriptor.ts` exports the provider's descriptor under the name the contract gives every folder, declared through the descriptor helper. The descriptor holds:
  - its literal id, which Studio stores and which never changes, and its label, description, learn-more URL, icon and logo;
  - `account`: the config schema, connect methods of kind `form`, `device` or `loopback` with stable ids, `describe`, and optionally `expiresAt` and `remember`;
  - optionally `ai`: models with stable ids, and the default model;
  - optionally `sites`: presentation and behavior flags.
- `services.ts` exports the provider's services under the name the contract gives every folder, declared through the services helper with the folder's descriptor. Their required parts follow design-doc-decision-3.
- Model connections are `AiConnection`s, with `model.api` one of `openai-completions`, `openai-responses`, `anthropic-messages` and `google-generative-ai`.
- Imports: the descriptor and config import only each other and the package's shared surface files. The services may also import the folder's other modules, the package's shared modules and its npm dependencies.

**The surface entry (`@studio/providers`)**
- `PROVIDER_IDS`, `AI_PROVIDER_IDS` and `SITES_PROVIDER_IDS` are `readonly ProviderId[]`, in design-doc-decision-1's order. `DEFAULT_PROVIDER_ID` is `'wpcom'`.
- `getProvider< Id >( id )` returns `Provider< ProviderConfig< Id >, ProviderSite< Id > >`. It throws an error that names an id no descriptor declares.
- `getProviderSites( id )` returns the provider's `ProviderSitesInfo`.
- `normalizeProviderId( value, ids? )` and `toStoredProviderId( id )` have Anthropic's `anthropic-api-key` as their one exception.
- `formatRemoteSite` and `parseRemoteSite` are unchanged, over `SITES_PROVIDER_IDS`.
- `findAiModel( id )` returns the first provider in the order that lists the id. `getAiModels( provider, account? )` and `getDefaultAiModel( provider, options? )` keep their behavior.
- The descriptor and services helpers, and the union of model APIs Studio runs.
- Types:
  - `ProviderId` and `AiModelId` are `string`;
  - `ProviderConfig< Id >` is WordPress.com's config for `'wpcom'`, otherwise `unknown`;
  - `ProviderSite< Id >` is `SyncSite` for `'wpcom'`, otherwise `RemoteSite`;
  - `Provider`, `ProviderServices`, `AccountDetails`, `ConnectMethod`, `AiConnection` and the rest keep their names;
  - removed: `AiProviderId`, `SitesProviderId`, `ProviderConfigs` and `ProviderSites`.

**The services entry (`@studio/providers/services`)**: `getProviderServices< Id >( id )` returns `ProviderServices< ProviderConfig< Id >, ProviderSite< Id > >` synchronously, carrying `id`. For a provider whose folder has no services, it throws an error that names the provider and the module it expects. `createTusUpload` stays.

**The package's checks**
- `npm run typecheck` fails in the developer's folder, naming the part or the kind, for a missing services part, a part for an undeclared capability, a default model that isn't the provider's own, a `redirect` method outside WordPress.com, and a connection whose API is outside the four.
- `npm test` fails, naming the provider's folder, the module and the missing or wrong part, for each case of design-doc-decision-4.
- `npm run knip` reports a provider module the discovery misses as an unused file.

**Studio's storage (`@studio/common`)**
- `readProviderConfig`, `writeProviderConfig`, `readFreshProviderConfig`, `forgetRejectedConfig` and `readSignInContext` take any id in `PROVIDER_IDS`. They store under `providerConfigs.<id>`, except WordPress.com (`authToken`) and Anthropic's API key (`anthropicApiKey`).
- `getRemoteSites`, `rememberRemoteSite` and `forgetRemoteSite` take any id in `SITES_PROVIDER_IDS`. They store in `remoteSites`, except WordPress.com (`connectedWpcomSites`). `forgetRemoteSites( localSiteId )` covers every sites provider.
- Results are typed through `ProviderConfig< Id >` and `ProviderSite< Id >`.

**The agent's stream (`@studio/agent/shared/models.ts`)**: `createConnectionStream( ai )` streams a connection whose API is one of the four. For any other API, it ends the turn with an error that names the API, and sends no request.

**`apps/ui`**: `usePublishProviders()` returns every id in `SITES_PROVIDER_IDS` when `capabilities.nativeSites` is true, and only `'wpcom'` otherwise. Where sites aren't native, the palette hides every hosting entry except WordPress.com's.

**Contracts narrowed by the change**
- `AiConnection.model.api` is limited to the four APIs:
  - among providers, GitHub Copilot narrows its catalog models;
  - among consumers, the two agent runtimes already handle only these.
- A descriptor's `defaultModel`, `paidDefaultModel` and `AccountDetails.models` accept only the provider's own model ids. WordPress.com and GitHub Copilot already conform at run time.
- A provider's folder exports its descriptor and services under the contract's names, through the helpers. Services hold every part their descriptor needs, and none for a capability it doesn't declare. The six providers move to that.
- A `redirect` connect method is accepted only in WordPress.com's descriptor, which is the only one that declares one today.
- `getProvider` and `getProviderServices` throw for an id no descriptor declares, where today they return `undefined` past their types. Every caller passes an id from the runtime lists, or one it normalized against them (`.pipelines/providers-api-for-external-devs-v2/2-design-doc/design-doc/provider-typed-consumers.txt`).
- Publishing on Studio on the web is limited to WordPress.com, the same set as today for the six providers.

**Left without a purpose, and removed**
- The `PROVIDERS` and `SERVICES` maps, the hand-written id lists, `STORED_PROVIDER_IDS`'s identity entries, the id and model-id unions, and `types.ts`'s imports of each folder.
- `AiProviderId`, `SitesProviderId`, `ProviderConfigs` and `ProviderSites`.
- The surface zone's list of folder names in `eslint.config.mjs`.
- `@studio/common`'s exhaustive per-provider store maps.

**Contracts widened by the change, and what each consumer newly admits**
- `ProviderId` admits any string at compile time, where it admitted six literals. Consumers check membership at run time:
  - `setAiProvider`, `persistSelectedAiProvider`, `connectProvider` and `disconnectProvider` in `@studio/common` admit any id. The Desktop and `studio ui` handlers pass only ids they normalized against `AI_PROVIDER_IDS` or `PROVIDER_IDS`, and the CLI only ids from those lists.
  - The storage functions keyed by id admit any id. An id no descriptor declares throws from `getProvider`, naming it; callers pass ids from the lists.
  - The `apps/ui` connector's remote-site methods admit any id. Callers pass ids from `usePublishProviders` or `SITES_PROVIDER_IDS`, and the `studio ui` and Desktop handlers normalize the id against `SITES_PROVIDER_IDS`.
  - Tracks' `sync_type` admits any sites provider's id.
  - The config store's Anthropic override receives Anthropic's config as `unknown`.
- The set of providers at run time is every provider folder of the package:
  - `shared.json` admits a new id as a `providerConfigs`, `rememberedSignIns` and `remoteSites[].provider` key or value, and in `aiProvider`;
  - session entries record it;
  - the user preferences admit it as `defaultHostingProvider`, validated against `SITES_PROVIDER_IDS` when read;
  - `studio push --remote-site` admits it as a prefix;
  - Settings, the model picker and `studio code` render it through the generic provider row, the descriptor's logo and its connect methods;
  - older builds read such an id as unknown: `normalizeProviderId` returns `undefined`, and they fall back to the saved selection or WordPress.com, as for any unknown id today.
- `AiModelId` admits any string at compile time. Session entries record any listed model id. Readers keep a recorded model only when `findAiModel` finds it, and hosts check a requested model the same way. An older build drops a recorded model it doesn't know, and falls back to the provider's default.
- `ProviderConfig< Id >` and `ProviderSite< Id >` are `unknown` and `RemoteSite` for every provider but WordPress.com. Code outside the package that read another provider's own config or site fields would need a cast. No code does today except the config store's Anthropic override.

## Dependencies

- Vite's `import.meta.glob` and its `vite/client` types, for both entries and the package's tests. These are not new: `vite` is a root dev dependency, and `@studio/agent/shared/skills.ts` uses both in code the CLI and Studio on the web bundle and Vitest runs.
- knip's Vite plugin, already enabled for `packages/providers`, follows both globs.
- `eslint-plugin-import-x`'s `no-restricted-paths` with glob exceptions (4.17.1, already installed).
- `@earendil-works/pi-ai`'s `Model` type (1.5.0, already a dependency), narrowed to the four APIs.
- No new npm dependency, and no change to the bundle scripts: the SDKs of the four APIs already ship, and the Mistral and AWS SDKs stay stripped.

## Failure modes and observability

- **A descriptor with no services beside it, or services with no descriptor:** `npm test` fails, naming the folder and the module it expects. At run time, `getProviderServices` for such a provider throws, naming the provider and the module. A surface shows that error when the user connects or chats, the way hosts show any thrown error today.
- **A provider module the discovery misses, such as a misnamed descriptor:** `npm run knip` reports the file as unused. When the folder's other half is found, `npm test` also fails, naming the module it expects.
- **Services missing a part their descriptor declares, or holding one it doesn't:** a typecheck error in the folder's services module, naming the part, when the services are declared through the helper. Either way, `npm test` fails, naming the folder and the part.
- **A default model that isn't one of the provider's own:** a typecheck error in its descriptor.
- **A `redirect` connect method outside WordPress.com:** a typecheck error in the descriptor when it is declared through the helper. Either way, `npm test` fails, naming the folder and the method.
- **A connection naming an API Studio doesn't run:** a typecheck error in the folder, naming the API. If the API is cast past the types, the chat's turn ends with an error that names it, and nothing is sent.
- **A surface file that imports beyond the boundary, or code that imports a Node API or another workspace package:** an ESLint error at the import, in the offending file of the folder.
- **Two providers with the same id, or one of the six existing providers renamed, removed or reordered:** the package tests fail.
- **An id no descriptor declares passed to `getProvider` or `getProviderServices`:** an error that names the id, at the first call.
- **A program that loads the package without Vite:** `import.meta.glob` is not a function when the package is imported, so it fails at once. No program does so today.
- **A stored config that no longer parses, or has expired:** read as not connected (unchanged).
- **A config the provider rejects:** forgotten in the Desktop app, `studio ui` and the CLI, keeping what the provider's `remember` returns (unchanged).

## Verification

- new test at the package's registry boundary (`packages/providers/tests`) — design-doc-decision-1, design-doc-decision-4, spec-acceptance-criterion-17 — the six existing providers lead `PROVIDER_IDS`, `AI_PROVIDER_IDS` and `SITES_PROVIDER_IDS` in today's order, and the lists equal today's for them. `findAiModel` resolves every model id GitHub Copilot shares to the existing provider that lists it. `getProvider` and `getProviderServices` return the provider whose descriptor declares the id, and throw for an id none declares.
- new test at the package's registry boundary (`packages/providers/tests`) — design-doc-decision-1, design-doc-decision-3, design-doc-decision-4, design-doc-decision-10, spec-acceptance-criterion-9, spec-acceptance-criterion-10 — every discovered folder has both halves, ids are unique, every folder's services hold every part its descriptor needs and none for a capability it doesn't declare, and only WordPress.com's descriptor declares a `redirect` method.
- new test at the package's types (checked by `npm run typecheck`) — design-doc-decision-3, design-doc-decision-10, spec-acceptance-criterion-7, spec-acceptance-criterion-9, spec-acceptance-criterion-12 — typecheck rejects, naming the part or the kind:
  - services that lack a part their descriptor's capabilities or connect methods require (the model connection, list and push, create, pull, start);
  - services that declare a capability their descriptor doesn't;
  - a default model, paid default model or account model list outside the provider's own models;
  - a `redirect` method in a descriptor other than WordPress.com's.
- new test at the package's types (checked by `npm run typecheck`) — design-doc-decision-7, spec-acceptance-criterion-14 — a connection whose API is outside the four fails typecheck, naming the API.
- type system (`npm run typecheck` over every workspace) — design-doc-decision-2 — code that names WordPress.com keeps WordPress.com's config and site types, and the existing code that reads WordPress.com's own fields compiles. Code that handles any provider compiles against the base types.
- existing test `packages/providers/tests/providers.test.ts` › "reads the id builds before `anthropic` stored, and keeps writing it" — design-doc-decision-5, spec-acceptance-criterion-16 — the stored-id exception, and every other id stored as itself.
- existing tests in `packages/common/lib/tests/ai-settings.test.ts` — design-doc-decision-5, spec-acceptance-criterion-16 — configs stay where builds of every version read them:
  - "stores an accepted key where every build reads it, and makes it the default without another";
  - "keeps a subscription token in its own section, and clears the other method on write";
  - "replaces a ChatGPT sign-in with an OpenAI API key", for the default per-id section;
  - "keeps the WordPress.com config in the Studio sign-in, and revokes it on disconnect";
  - "reads legacy values from cli.json and migrates them on write";
  - "selects only a connected provider, storing the id older builds read";
  - "treats an unknown stored provider as the default".
- existing tests in `packages/common/lib/tests/ai-settings.test.ts` › "disconnects a provider whose config expired or that the provider rejects" and "stores a renewed config, and forgets one the provider no longer accepts but its client" — design-doc-decision-5, spec-acceptance-criterion-8 — renewal and rejection run through the default store a new provider uses.
- existing tests in `packages/common/lib/tests/remote-sites.test.ts` › "keeps the Spaces a site publishes to, and forgets them with the site" and "records each sync and keeps the times of the others" — design-doc-decision-5, spec-acceptance-criterion-16 — connections stay in `connectedWpcomSites` for WordPress.com and in `remoteSites` for the others, and are forgotten with the local site.
- new test at `@studio/agent/shared/models` (`createConnectionStream`) — design-doc-decision-7, spec-acceptance-criterion-14 — a connection that names an API outside the four ends with an error that names the API, and no request goes out.
- existing tests `packages/agent/browser/tests/gemini-stream.test.ts` › "streams a Gemini reply through Google’s SDK with the connected key" and `packages/agent/node/runtime/tests/pi-runtime.test.ts` › "streams with the connection’s upstream model and error rewrite" — design-doc-decision-7, spec-acceptance-criterion-13 — connections over the supported APIs still stream in both runtimes.
- existing test `apps/ui/src/features/composer/chat-model-picker.test.tsx` › "offers only the models the connected account can run" — design-doc-decision-3, spec-acceptance-criterion-8 — the picker narrows to the account's models from what the descriptor and account declare.
- existing test `packages/agent/protocol/sessions/tests/model.test.ts` › "runs on the selected provider, or the first connected one, WordPress.com first" — design-doc-decision-1, design-doc-decision-9, spec-acceptance-criterion-17 — fallback keeps WordPress.com first, with accounts built from the runtime lists.
- existing test suites of `packages/common`, `packages/agent`, `apps/cli`, `apps/studio` and `apps/ui` (`npm test`), with the two test files of design-doc-decision-9 building accounts from the runtime lists — design-doc-decision-2, design-doc-decision-8, design-doc-decision-9, spec-acceptance-criterion-17 — the six providers behave as before in connecting, selection, fallback, models, images and publishing.
- end-to-end flow — design-doc-decision-1, design-doc-decision-2, design-doc-decision-4, design-doc-decision-6, design-doc-decision-9, design-doc-decision-11, spec-acceptance-criterion-1, spec-acceptance-criterion-2, spec-acceptance-criterion-11 — following only the README, the chat provider of spec-acceptance-criterion-1 and the sites provider of spec-acceptance-criterion-2 are each added as one folder. No other file changes, inside or outside the package, and `npm run typecheck`, ESLint on the changed files, `npm run knip` and `npm test` pass.
- end-to-end flow — design-doc-decision-3, design-doc-decision-4, spec-acceptance-criterion-9 — a provider part-way through being written fails the checks in each case of design-doc-decision-3 and design-doc-decision-4, each report naming the provider's folder, the module and the missing part.
- end-to-end flow — design-doc-decision-6, spec-acceptance-criterion-15 — with nothing outside the package changed, ESLint on a new provider's files reports, at each import, a descriptor or config that imports its services, a Node API import and another workspace package's import, and reports nothing for a provider within the boundaries.
- end-to-end flow in `studio ui`, Studio on the web and the Desktop app — design-doc-decision-1, design-doc-decision-2, design-doc-decision-5, design-doc-decision-7, spec-acceptance-criterion-3, spec-acceptance-criterion-13 — the new chat provider meets each point of spec-acceptance-criterion-3 in each app, and its replies stream over its API. In the Desktop app, this also shows that the main process's bundle holds the discovered descriptors and services (design-doc-assumption-4).
- end-to-end flow in `studio code` — design-doc-decision-1, design-doc-decision-5, spec-acceptance-criterion-4 — the new chat provider meets each point of spec-acceptance-criterion-4.
- end-to-end flow in the settings and publish panel of `studio ui` and the Desktop app, and `studio push --remote-site <id>` — design-doc-decision-1, design-doc-decision-5, design-doc-decision-8, spec-acceptance-criterion-5, spec-acceptance-criterion-6 — the new sites provider, and a provider that offers both capabilities and is connected once, appear and publish as the criteria say.
- end-to-end flow in Studio on the web — design-doc-decision-8 — with a new archive-publishing provider in the package, the publish tab, Settings' hosting providers and the palette offer only WordPress.com, as before.
- end-to-end flow — design-doc-decision-3, spec-acceptance-criterion-7, spec-acceptance-criterion-8 — providers that declare each connect method, and each account and model feature the criteria list, behave as declared in Settings, the chat model picker, `/model` and a chat.
- end-to-end flow — design-doc-decision-2, design-doc-decision-5, spec-acceptance-criterion-16 — builds from before and after the change each read what the other stored, and show the same accounts, defaults, connections and pins, as spec-acceptance-criterion-16 states.
- inspection — design-doc-decision-10, spec-acceptance-criterion-12 — every value of the contract states its meaning, whether a new provider supplies it or acts on it, and what Studio does with it, and each WordPress.com-only part says so.
- inspection — design-doc-decision-11, spec-acceptance-criterion-11 — the README covers each point the criterion lists, in agreement with the contract.

## Risks

- **A program that loads `@studio/providers` without Vite**, such as a script run with `tsx` that imports `@studio/common`'s provider modules, fails when it imports the package. Every program that reaches the package today builds or tests through Vite (`.pipelines/providers-api-for-external-devs-v2/2-design-doc/design-doc/vite-glob-in-every-build.txt`).
- **A misspelled literal provider or model id in Studio's code** compiles, and throws or finds nothing at run time (design-doc-decision-2). Studio's code passes literal ids only for WordPress.com, for Spacefast in its settings row, and in tests.
- **A later test outside the package that compares the full set of accounts** fails when a provider is added (design-doc-decision-9).
- **A provider that offers both chat models and remote sites** gets two palette entries with the same settings target, and its hosting entry lands on its AI provider row. It is the same provider and connection, so spec-acceptance-criterion-6 still holds.
- **On Studio on the web, a form-connected provider whose credential expires** is not renewed in the page, which reads stored configs without a refresh, as today. It shows as disconnected once the credential expires. A config the provider rejects stays stored there, as it does today for the six providers. Today only OpenAI's ChatGPT sign-in and GitHub Copilot renew a credential, and the web offers neither (`.pipelines/providers-api-for-external-devs/2-design-doc/design-doc/observations.txt`).
- **A form-connected provider whose API rejects calls from a page** is still offered on Studio on the web, and fails there when connecting or chatting. No source shows such a provider (spec, "Considered and not required").
- **A service that offers image generation without chat models** can't be added as a provider without declaring models (design-doc-decision-3). No provider or source shows one.
- **Error messages from the helpers' types** may be longer than a plain missing-property error (design-doc-assumption-1).

## Open assumptions

design-doc-assumption-1: Typecheck reports, through the helpers, a missing capability part and one for an undeclared capability in the provider's services module, naming the part, and a default model outside the provider's own models and a `redirect` method outside WordPress.com in its descriptor, naming them — assumed: the type tests of design-doc-decision-3 and design-doc-decision-10 and the flow with a provider part-way through being written show the errors at those locations, with those names.

design-doc-assumption-2: An error the connection stream raises before any request reaches the user as the chat's error, in both the Node runtime and the browser agent — assumed: the new `createConnectionStream` test, and chats in `studio code` and in Studio on the web on a connection that names another API, show the error naming the API.

design-doc-assumption-3: The package's tests report each case of design-doc-decision-4 with a message that names the provider's folder, the module and the missing part — assumed: the flow with a provider part-way through being written shows each report.

design-doc-assumption-4: The Desktop main build bundles every folder's descriptor and services through the discovery, as the CLI and Studio on the web builds do. Vite 8.3.5 adds its glob-import plugin to every build, and electron-vite builds main as a Vite build that bundles `@studio/providers` from source (`.pipelines/providers-api-for-external-devs-v2/2-design-doc/design-doc/vite-glob-in-every-build.txt`) — assumed: connecting the new chat provider from the Desktop app's Settings and chatting on it works.
