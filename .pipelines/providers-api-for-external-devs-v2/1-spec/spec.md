# Spec: Add a provider to @studio/providers by changing only the package

## Overview

Adding a provider to `@studio/providers` today takes edits in many places. Inside the package, the new provider goes into its shared types and lists. Outside it, the change touches Studio's config storage in `@studio/common`, the lint configuration, and tests in other packages that list every provider by name. When the provider's models use an API Studio's agent doesn't run yet, it also touches the agent. The package README's "Adding a provider" steps leave some of these out. A developer who follows them gets a provider that passes typecheck but appears in no surface, and nothing reports it. Parts of the contract a provider implements belong to WordPress.com and don't say so. The package isn't open to external contributors yet, but Studio plans to open it.

After the change, a developer outside the Studio team adds a provider by changing only the package. The contract and the package documentation guide them, and the repository's checks report every part they leave out at the code they wrote. The provider then appears in every Studio surface its capabilities reach, in Node and in the page. The six existing providers, and the accounts and choices users have already saved, behave as before.

## Requirements

spec-requirement-1: A developer adds a new provider, with its own id, config and model ids, by changing only `@studio/providers`. No file outside the package needs to change: not Studio's apps, `@studio/common` or `@studio/agent`, not the repository's configuration or build scripts, and not other packages' tests. With only those changes, the repository's checks pass (`npm run typecheck`, ESLint on the changed files, `npm run knip` and `npm test`), and the provider works in every surface spec-requirement-2 names. A new provider is one for a service that offers chat models, image generation, a place to publish local sites, or several of these, as the six providers in the package do today. Its account connects with an API key form, a device sign-in, a loopback sign-in, or several of these. Its chat models use one of the APIs spec-requirement-6 names.

origin: derived Goal ("add a new provider to `@studio/providers` easily"). Observed input: the two most recent provider additions, Google Gemini and GitHub Copilot, each changed files outside the package, and a sample provider added by today's steps needed edits across the package's shared files and other packages.

- Adding Google Gemini changed `packages/common/lib/provider-config.ts`, `packages/agent/shared/models.ts`, `packages/agent/browser/models.ts`, `eslint.config.mjs`, the bundle scripts, and tests in `packages/common`, `packages/agent` and `apps/studio`. Inside the package it changed `types.ts`, `registry.ts`, `services.ts` and `models.ts`. observed: `git show --stat c0635aa23` and its diff.
- Adding GitHub Copilot changed `packages/common/lib/provider-config.ts`, `eslint.config.mjs`, and tests in `packages/common`, `packages/agent` and `apps/studio`, together with UI work for narrowing models to the account's plan. observed: `git show --stat aad3d2daa` and its diff.
- A new provider id and a new model id are each rejected by the package's types until added to the closed `ProviderId` and `AiModelId` unions. observed: probe, `.pipelines/providers-api-for-external-devs/1-spec/spec/probe/1-readme-steps-providers-typecheck.txt`.
- A sample provider (`.pipelines/providers-api-for-external-devs/1-spec/spec/probe/sample-provider.patch`), added and then reverted, was reported by ESLint in its own `descriptor.ts` and in `registry.ts`, `types.ts` and `models.ts` until its folder name was added to the list in `eslint.config.mjs:445`. observed: probe, `.pipelines/providers-api-for-external-devs/1-spec/spec/probe/2-registered-eslint.txt`.
- The same sample provider failed typecheck in `packages/common/lib/provider-config.ts:73`, `packages/agent/protocol/sessions/tests/model.test.ts` and `apps/studio/src/modules/user-settings/lib/tests/settings-tracks.test.ts`. observed: probe, `.pipelines/providers-api-for-external-devs/1-spec/spec/probe/2-registered-repo-typecheck.txt`.
- Once the sample provider was listed as an AI provider, four tests failed in `packages/common/lib/tests/ai-settings.test.ts` and `packages/agent/protocol/sessions/tests/model.test.ts`, because they enumerate every provider's account. observed: probe, `.pipelines/providers-api-for-external-devs/1-spec/spec/probe/3-listed-tests.txt`.
- A provider with remote sites also needs an entry in `packages/common/lib/remote-sites.ts:115`. observed: read `packages/common/lib/remote-sites.ts` and `packages/providers/README.md:59`.
- Today's providers combine capabilities independently: Anthropic, OpenAI, Google Gemini and GitHub Copilot offer AI only, Spacefast publishes without AI or pull, and WordPress.com offers both. They connect with forms, a loopback sign-in, device sign-ins and the Studio sign-in. observed: probe, `.pipelines/providers-api-for-external-devs/1-spec/spec/probe/4-capabilities-runtime.txt`.

spec-requirement-2: A new provider, once added as spec-requirement-1 describes, appears wherever its capabilities reach, with its label, description, logo and connect methods, and works there.
- A provider that offers chat models appears in Settings › Providers under AI providers. Once connected, it appears in the Default AI provider select, and its models appear in the chat model picker (only the ones its account runs, when the account narrows them). Chats run on its models. In `studio code`, it appears in `/connect`, `/disconnect`, `/provider` and `/model`.
- A provider that generates images generates them when it is the chat's provider. In the Desktop app, `studio ui` and `studio code`, it also generates them for a chat whose provider doesn't, when it is the first connected provider that offers images.
- A provider that offers remote sites appears in Settings › Providers under Hosting providers, and in the Default hosting provider select once connected. Its sites appear in a local site's publish panel, `studio push --remote-site <its id>[:<site>]` publishes to it, and Studio Code lists a local site's connected sites on it and publishes to them.
- A provider that offers both is listed in both places, and one connection serves both.
- Connecting it stores its config, which stays connected after Desktop, `studio ui` or the CLI restarts, and after Studio on the web reloads. A credential that expires is renewed before use, and the provider shows as disconnected once its config stops working.
- Studio on the web offers it with the connect methods the web supports today, and runs its account, model and image services in the page.

origin: derived Goal. Observed input: today, a registered provider reaches these surfaces only through the package's provider lists, and a provider registered by the README's steps is in none of them.

- The settings, the model picker, `studio code`'s commands, the publish panel, the agent's host and Studio on the web build their provider lists from the registry's id lists. observed: read `apps/ui/src/data/settings-sections.ts:48-56`, `apps/ui/src/features/settings/settings-view/providers-panel.tsx:186-192`, `apps/ui/src/features/composer/model-picker.tsx:23`, `apps/cli/ai/slash-commands.ts:268,310,466`, `apps/ui/src/data/queries/use-remote-sites.ts:28`, `apps/cli/ai/host.ts:63`, `apps/static/src/agent/index.ts:264` and `packages/common/lib/ai-settings.ts:54`.
- After the README's steps, the package typechecked with the sample provider in none of those lists. `normalizeProviderId( 'example' )` returned undefined and `findAiModel( 'example-large' )` returned nothing, while `getProvider( 'example' )` returned the provider. observed: probe, `.pipelines/providers-api-for-external-devs/1-spec/spec/probe/2-registered-providers-typecheck.txt` and `.pipelines/providers-api-for-external-devs/1-spec/spec/probe/2-registered-lists.json`.
- Once listed (`.pipelines/providers-api-for-external-devs/1-spec/spec/probe/3-listed-lists.json`), the sample provider passed the `apps/ui` settings and model-picker tests unchanged. observed: probe, `.pipelines/providers-api-for-external-devs/1-spec/spec/probe/3-listed-tests.txt`.
- Image generation comes from the chat's provider, and otherwise, in the agent the CLI hosts for the Desktop app, `studio ui` and `studio code`, from the first connected AI provider that offers it; Studio on the web falls back to WordPress.com. observed: read `apps/cli/ai/auth.ts:130-144`, `apps/cli/ai/host.ts:130`, `apps/cli/commands/ai/index.ts:172`, `apps/static/src/agent/index.ts:455` and `apps/static/src/agent/host.ts:524`.
- Settings render a hosting provider other than WordPress.com and Spacefast with the generic provider row, and fall back to the descriptor's logo when Studio bundles no icon for the provider. observed: read `apps/ui/src/features/settings/settings-view/providers-panel.tsx:140-175` and `provider-logo.tsx:5-7`.
- Studio on the web offers form methods and hides device and loopback sign-ins, and saves and reads accepted configs per provider in the page. observed: read `apps/ui/src/features/settings/settings-view/ai-panel.tsx:28-33` and `apps/static/src/agent/index.ts:219-298`.

spec-requirement-3: When a new provider is missing a part that a capability it declares needs, one of the checks spec-requirement-1 names fails. Its report names the missing part and points at code the developer wrote for the new provider, never at a file in another package. A new provider that passes those checks is never left out of a surface spec-requirement-2 names for the capabilities it declares.

origin: derived Goal ("a clear, well-defined API"). Observed input: a provider part-way through being written, as a developer has it while following the README.

- The sample provider's model ids were rejected in its own `descriptor.ts` until they were added to a shared union in `packages/providers/models.ts:9`, which the README doesn't mention. observed: probe, `.pipelines/providers-api-for-external-devs/1-spec/spec/probe/1-readme-steps-providers-typecheck.txt`.
- With the sample provider registered but left out of the AI provider list, typecheck passed and no surface listed it. observed: probe, `.pipelines/providers-api-for-external-devs/1-spec/spec/probe/2-registered-lists.json`.
- The missing config store was reported in `@studio/common`, not in the provider. observed: probe, `.pipelines/providers-api-for-external-devs/1-spec/spec/probe/2-registered-repo-typecheck.txt`.
- The lint errors were reported in the package's shared files, with a message that doesn't name the fix. observed: probe, `.pipelines/providers-api-for-external-devs/1-spec/spec/probe/2-registered-eslint.txt`.
- What surfaces read (`Provider.ai`, `Provider.sites`) and the matching services (`ProviderServices.ai`, `ProviderServices.sites`) are optional independently of each other. A provider that lists models without a model connection is reported only when a chat starts: "offers no AI models". observed: read `packages/providers/types.ts:173,179,305,320` and `apps/cli/ai/auth.ts:89-91`.

spec-requirement-4: The package's documentation is enough for a developer who has never worked on Studio to add a provider, and agrees with the contract. It lists every change the developer makes, all of them inside the package as spec-requirement-1 requires. For each capability, it describes the parts a provider fills in. It names the connect methods a new provider can use and the apps that offer each, and the model APIs spec-requirement-6 names. It says which of the values a provider declares Studio stores, and that those never change; that a provider's code runs in Node and in the page; and how to test the provider. A developer who follows only the documentation ends with a provider that meets spec-requirement-1 and spec-requirement-2.

origin: derived Goal ("a clear, well-defined API"). Observed input: the README's "Adding a provider" steps, followed as written, produce a provider that appears nowhere.

- The README's steps name `ProviderId`, `ProviderConfigs`, `registry.ts`, `services.ts`, `provider-config.ts`, `ProviderSites` and `remote-sites.ts`. observed: read `packages/providers/README.md:57-59`.
- The steps leave out `AiProviderId`, the registry's `AI_PROVIDER_IDS`, `SITES_PROVIDER_IDS` and `STORED_PROVIDER_IDS`, the `AiModelId` union, the folder list in `eslint.config.mjs`, and the agent's API support. observed: probe, `.pipelines/providers-api-for-external-devs/1-spec/spec/probe/README.md` steps 1-3.
- Provider ids, model ids and connect-method ids are stored, so they never change. observed: read `packages/providers/README.md:53-55` and `packages/providers/types.ts` (`ConnectMethod.id`).
- The package runs in Node and in the page, and each app offers a different set of connect methods. observed: read `packages/providers/README.md:63-68`, `apps/ui/src/features/settings/settings-view/ai-panel.tsx:28-33` and `apps/cli/lib/providers.ts:144-150`.

spec-requirement-5: Wherever a developer looks something up in the contract, it says, for every value Studio hands a provider and every value a provider gives back:
- what the value means;
- whether a new provider must supply it or act on it;
- what Studio does with it.

Some parts work for one provider only, or depend on another provider's account. Each of these is either unavailable to a new provider or says which provider it belongs to and what a new provider does with it:
- a `redirect` connect method, which is the Studio sign-in;
- models gated on paid AI credits, which are WordPress.com's;
- the push options, the `planRequired` list option and the pull steps that WordPress.com sync uses.

origin: from-intent Goal ("through a clear, well-defined API").

- The CLI connects any provider's `redirect` method by running the WordPress.com login, and disconnects it by signing out of Studio. observed: read `apps/cli/lib/providers.ts:144-145` and `apps/cli/ai/slash-commands.ts:323-327`.
- Settings drop `redirect` methods and hide a provider left with no other method. observed: read `apps/ui/src/features/settings/settings-view/ai-panel.tsx:28-33` and `providers-panel.tsx:187-192`.
- `requiresPaidAiCredits` locks a model, for any provider, unless the WordPress.com account has paid credits. observed: read `apps/ui/src/features/composer/use-model-access.ts:31-43` and `apps/cli/ai/slash-commands.ts:403-404`.
- Every sites provider's `push` receives WordPress.com's `PushSyncOptions`, defined in `wpcom/sites/site.ts`; `list` takes `planRequired`; and `pull` consists of remote backups, a Reprint exporter and its key. Spacefast ignores the push options. observed: read `packages/providers/types.ts:9,242,252,256-285`, `packages/providers/wpcom/sites/site.ts:51-67` and `packages/providers/spacefast/sites.ts`.

spec-requirement-6: A developer can tell from the contract which model APIs Studio's agent runs: `openai-completions`, `openai-responses`, `anthropic-messages` and `google-generative-ai`. A new provider whose models use one of these chats in the Desktop app, `studio ui`, `studio code`, and Studio on the web where its account connects, with no change outside the package. A provider whose model connection names any other API gets a report that names the API, either from one of the checks spec-requirement-1 names or as the chat's error, and its requests are never sent over a different API.

origin: derived Goal. Observed input: adding Google Gemini, a provider whose models use an API the agent didn't run, required changes to the agent.

- The agent picks how to stream from the connection's `model.api`. `openai-completions`, `anthropic-messages` and `google-generative-ai` have their own stream. Every other API is sent as `openai-responses`, including the six other APIs pi's type allows, such as `mistral-conversations` and `bedrock-converse-stream`. observed: read `packages/agent/shared/models.ts:17-29` and `node_modules/@earendil-works/pi-ai/dist/types.d.ts:20-21`.
- Gemini's addition changed `packages/agent/shared/models.ts` and `packages/agent/browser/models.ts`. observed: `git show c0635aa23 -- packages/agent`.

spec-requirement-7: The package's boundaries hold for a new provider as they do for the existing ones, with no change outside the package:
- its code uses no Node API, so it runs in the page as in Node;
- its code uses no other workspace package;
- what surfaces read of it, the provider as data, uses only code that is itself part of what surfaces read, never the provider's services.

A new provider that crosses one of these boundaries fails one of the checks spec-requirement-1 names, at the code that crosses it. A new provider that keeps within them passes those checks.

origin: derived Goal ("a well-defined API"). Observed input: the code a new provider adds, which today's surface boundary covers only when the provider's folder is listed by name in the repository's configuration.

- The package documents these three boundaries and checks them today. observed: read `packages/providers/README.md:18-21,61-68` and `eslint.config.mjs:33-45,410-457`.
- The surface boundary lists the provider folders by name, so the sample provider's `descriptor.ts` importing its own `config.ts` was reported as a violation. observed: read `eslint.config.mjs:433-457`, and probe, `.pipelines/providers-api-for-external-devs/1-spec/spec/probe/2-registered-eslint.txt`.
- The boundaries against Node APIs and other workspace packages cover every file in the package. observed: read `eslint.config.mjs:410-431`.

spec-requirement-8: Every account connected before the change stays connected after it, in Desktop, `studio ui`, the CLI and Studio on the web, with the same account summary. So do the selected chat provider, the default hosting provider, the remote sites connected to each local site, and the provider and model each chat is pinned to. A stored `anthropic-api-key` still names Anthropic, and the WordPress.com account is still the Studio sign-in. Builds from before the change keep reading what builds after it store.

origin: derived Goal. Observed input: the `shared.json`, session entries and Studio on the web settings that today's builds write for the six providers, which older builds also read. The change reshapes the API that reads and writes them.

- Configs are stored as follows:
  - WordPress.com in `authToken`;
  - an Anthropic API key in `anthropicApiKey`;
  - the other providers, and Anthropic's subscription token, in `providerConfigs.<id>`.

  Alongside them, `rememberedSignIns` and `signInHostId` are stored. observed: read `packages/common/lib/provider-config.ts:73-144,179-216`.
- The selected chat provider is stored in `aiProvider`, with Anthropic written as `anthropic-api-key` because older builds fall back to WordPress.com on an id they don't know, and session entries record the same stored ids. observed: read `packages/providers/registry.ts:62-84` and `packages/agent/protocol/sessions/model.ts:84-87`, and probe, `.pipelines/providers-api-for-external-devs/1-spec/spec/probe/4-capabilities-runtime.txt` (`legacyAnthropicRead`, `legacyAnthropicWrite`).
- Remote-site connections are stored in `connectedWpcomSites` for WordPress.com and `remoteSites` for the other providers, and the default hosting provider in the user preferences. observed: read `packages/common/lib/remote-sites.ts:115-133` and `packages/common/lib/user-settings/user-preferences.ts:106`.
- Studio on the web keeps configs per id in its stored AI settings. observed: read `apps/static/src/agent/index.ts:227-259`.

spec-requirement-9: WordPress.com, Anthropic, OpenAI, Google Gemini, GitHub Copilot and Spacefast behave as before in every surface: connecting, disconnecting, chatting, model lists, image generation, publishing and pulling. This holds when a new provider is also connected. WordPress.com stays first wherever Studio picks the first connected or ready provider. When a new provider lists a model id an existing provider also lists, that model keeps the existing provider's label, image support and paid-credit rule.

origin: derived Goal. Observed input: the six registered providers. GitHub Copilot already lists model ids that Anthropic, OpenAI and Google Gemini also list, as a new provider that resells models would.

- The order of the AI provider list decides fallback, and `findAiModel` returns the first provider that lists a model id. observed: read `packages/providers/registry.ts:18-24`, `packages/providers/models.ts:31-41`, `apps/cli/ai/auth.ts:39-48` and `packages/agent/protocol/sessions/model.ts:108-111`.
- GitHub Copilot lists `claude-sonnet-5-5`, `gpt-6.1-terra` and `gemini-4-argon`. observed: read `packages/providers/github-copilot/descriptor.ts:6-10`.
- Labels, image support and the paid-credit lock are read through `findAiModel`. observed: read `apps/ui/src/features/composer/model-picker.tsx:71,127`, `composer.tsx:389` and `use-model-access.ts:41`.

## Acceptance criteria

spec-acceptance-criterion-1: Given a new provider that serves chat models over one of the APIs spec-requirement-6 names and connects with an API key form, when a developer adds it by following the package documentation, then no file outside `@studio/providers` changes, and `npm run typecheck`, ESLint on the changed files, `npm run knip` and `npm test` all pass.

spec-acceptance-criterion-2: Given a new provider that publishes local sites, as a WordPress archive or as a static export, and connects with a device sign-in, when a developer adds it by following the package documentation, then no file outside `@studio/providers` changes, and `npm run typecheck`, ESLint on the changed files, `npm run knip` and `npm test` all pass.

spec-acceptance-criterion-3: Given the chat provider from spec-acceptance-criterion-1, when the user opens Settings › Providers in the Desktop app, `studio ui` and Studio on the web, then all of the following hold in each app:
- the provider is listed under AI providers with its label, logo and description;
- entering a key connects it, after which it appears in the Default AI provider select;
- the chat model picker lists its models;
- a chat on one of its models gets a reply;
- it is still connected after the app restarts or the page reloads.

spec-acceptance-criterion-4: Given the chat provider from spec-acceptance-criterion-1, when the user runs `studio code`, then:
- `/connect` offers it and asks for its form's fields;
- once it is connected, `/provider` switches to it and `/model` lists its models;
- it is still connected after `studio code` restarts;
- `/disconnect` removes it.

spec-acceptance-criterion-5: Given the sites provider from spec-acceptance-criterion-2, when the user opens Settings › Providers and a local site's publish panel in the Desktop app and `studio ui`, and runs `studio push --remote-site <its id>`, then:
- it is listed under Hosting providers, and connects through its device sign-in with the code shown in the row;
- once connected, it appears in the Default hosting provider select;
- the publish panel lists its sites;
- a push from the panel or from the CLI publishes the local site to the site picked.

spec-acceptance-criterion-6: Given a new provider that offers both chat models and remote sites, when the user connects it once from Settings in the Desktop app, then it is listed under AI providers and Hosting providers, its models are in the chat model picker and its sites in the publish panel, with no second connection.

spec-acceptance-criterion-7: Given new providers whose accounts connect through a device sign-in, through a loopback sign-in, or through a choice of several methods, when the user connects each from Settings in the Desktop app and from `/connect` in `studio code`, then each connects the way it declares and shows its account summary. Studio on the web offers only the methods it supports today.

spec-acceptance-criterion-8: Given a new provider that declares any of the account and model features below, when the user uses it in Settings, the chat model picker, `/model` and a chat, then each declared feature works with no change outside the package:
- an account that narrows the models it runs: the pickers offer only those models;
- image generation: its images are used when it is the chat's provider;
- a credential that expires and renews: Studio renews it before use, and shows the provider as disconnected once the provider rejects it.

spec-acceptance-criterion-9: Given a new provider added to the package that lists models but has no model connection, or presents remote sites but cannot push to them, when the developer runs the checks spec-requirement-1 names, then one of them fails with an error that names the missing part and points at code the developer wrote for that provider, not at a file in another package.

spec-acceptance-criterion-10: Given any new provider that passes the checks spec-requirement-1 names, when the user opens the surfaces spec-requirement-2 names for its declared capabilities, then the provider is listed in each of them.

spec-acceptance-criterion-11: Given only the package documentation, when a developer who has never worked on Studio looks up how to add a provider, then the documented steps list every change a developer makes to add the providers of spec-acceptance-criterion-1 and spec-acceptance-criterion-2, all of them inside the package. The documentation describes every part of the contract each capability needs, names the connect methods a new provider can use and the apps that offer each, names the four model APIs Studio runs, says which declared values are stored and never change and that the provider runs in Node and in the page, and says how to test the provider. Each of these agrees with the contract.

spec-acceptance-criterion-12: Given the contract in the package, when a developer looks up any value their provider declares, receives or returns, then the contract states what the value means, whether a new provider supplies or acts on it, and what Studio does with it. A `redirect` connect method, models gated on paid AI credits, the push options, the `planRequired` list option and the pull steps are each either unavailable to a new provider or state which provider they belong to and what a new provider does with them.

spec-acceptance-criterion-13: Given a new provider whose model connection uses `openai-completions`, `openai-responses`, `anthropic-messages` or `google-generative-ai`, when the user chats on one of its models in the Desktop app, `studio ui`, `studio code`, and Studio on the web where its account connects, then the reply streams over that API.

spec-acceptance-criterion-14: Given a new provider whose model connection names any other API, such as `mistral-conversations`, when the developer runs the checks spec-requirement-1 names or the user starts a chat on one of its models, then the developer is told that Studio doesn't run that API, by one of those checks or as the chat's error, and no request goes out over a different API.

spec-acceptance-criterion-15: Given a new provider whose code uses a Node API or another workspace package, or whose part that surfaces read uses its services code, when the developer runs the checks spec-requirement-1 names with nothing outside the package changed, then one of them fails at each such use. Given a new provider that keeps within those boundaries, the same checks pass.

spec-acceptance-criterion-16: Given `shared.json`, session entries and Studio on the web settings written by a build from before the change, with every provider each app offers connected, `aiProvider` set to `anthropic-api-key`, a default hosting provider, and WordPress.com sites and Spacefast Spaces connected to local sites, when a build from after the change starts, then Settings, `studio code` and the publish panel show:
- the same accounts connected, with the same summaries, and WordPress.com as the Studio sign-in;
- the same default AI provider and default hosting provider;
- the same connected sites.

Existing chats keep their pinned provider and model. When a build from before the change then reads what the new build stored, it shows the same.

spec-acceptance-criterion-17: Given the six existing providers, with or without a new provider also connected, when the user connects, disconnects, chats, picks models, generates images, publishes and pulls with each in Settings, the chat, the publish panel and `studio code`, then each behaves as before the change. WordPress.com stays first when Studio picks the first connected provider. A model id a new provider shares with an existing provider shows the existing provider's label, image support and paid-credit lock.

## Exclusions

spec-exclusion-1: Opening the package to external contributors: publishing it as a package other applications install, or setting up how outside contributions are accepted.

spec-exclusion-2: Loading providers that live outside Studio's source at run time, such as plugins or user configuration.

spec-exclusion-3: Studio's agent running model APIs beyond `openai-completions`, `openai-responses`, `anthropic-messages` and `google-generative-ai`.

spec-exclusion-4: Capabilities beyond an account, AI and remote sites, such as previews offered by a provider.

spec-exclusion-5: Providers bringing their own UI components. Surfaces render a new provider from what it declares.

spec-exclusion-6: Removing the places where surfaces name WordPress.com or Spacefast today: the Studio sign-in, WordPress.com's sync statuses and plan flows, and Spacefast's connect dialog in Settings. Which account is the Studio sign-in stays as it is.

spec-exclusion-7: New ways for an account to connect, and device or loopback sign-in in Studio on the web.

spec-exclusion-8: Shipping a provider for a service Studio doesn't offer today.

## Considered and not required

- Reading "external developers" as third parties who ship providers outside Studio's repository, loaded at run time, or who install the package into their own applications. Not taken: the Goal says "add a new provider to `@studio/providers`", intent-context-1 speaks of contributors to the package, `packages/providers/package.json` marks it private, and `docs/design-docs/providers.md` (Out of scope) compiles providers in.
- Reading "easily" as complete documented steps, with no bound on where a provider's changes go. Not taken: the two most recent additions changed `@studio/common`, `@studio/agent`, the lint configuration and other packages' tests (`git show --stat c0635aa23 aad3d2daa`), so a contributor to the package would have to change Studio itself.
- Reading a provider's addition as complete once the package's API returns it, whether or not it reaches Studio's surfaces. Not taken: surfaces list providers only from the registry's id lists, and the sample provider that `getProvider` returned appeared in none of them (`.pipelines/providers-api-for-external-devs/1-spec/spec/probe/2-registered-lists.json`).
- Reading "easily" as a generator that creates a new provider's files. No source shows one. observed: `packages/providers/README.md` points developers to "a folder laid out like the others", and spec-requirement-4 makes the documentation enough on its own.
- A new provider whose models use an API pi supports but Studio doesn't run, chatting with no change outside the package. Not taken: running such an API ships its SDK in every build. observed: `apps/studio/forge.config.ts:289-297` and `scripts/create-*-bundle.ts` strip the Mistral and AWS SDKs, and Gemini's addition removed `@google/genai` from those lists in c0635aa23. That makes it a decision for Studio, not part of a provider contribution.
- A provider whose account offers neither AI nor remote sites. No provider has that combination, and Settings list only AI and hosting providers. observed: `.pipelines/providers-api-for-external-devs/1-spec/spec/probe/4-capabilities-runtime.txt` and `apps/ui/src/data/settings-sections.ts:300-333`.
- A new host that pulls sites back. No provider except WordPress.com pulls. observed: `packages/providers/spacefast/descriptor.ts` has `pull: false`, and the SSH host in `docs/design-docs/providers.md` is planned.
- A provider connected with a form whose API rejects calls from a page, offered in Studio on the web. No source shows such a provider. observed: Studio on the web filters providers by connect-method kind only, in `apps/ui/src/features/settings/settings-view/ai-panel.tsx:28-33`.
- A new provider that needs an app icon bundled in `apps/ui`. Not needed: surfaces fall back to the descriptor's logo. observed: `apps/ui/src/features/settings/settings-view/provider-logo.tsx:5-7`.
- A new provider with its own connect dialog in Settings, as Spacefast has. Not needed: the generic provider row shows a device sign-in's code. observed: `apps/ui/src/features/settings/settings-view/ai-panel.tsx:147-163`, which GitHub Copilot connects through.
- A chat pinned to a model id no provider offers any more, restored after the change. Not needed: today such a chat already falls back to the provider's default model. observed: `packages/agent/protocol/sessions/model.ts:36-72`.
