# Spec: Add a provider to @studio/providers from its own folder

## Overview

Adding a provider to `@studio/providers` today takes edits in many places. Inside the package, the new provider goes into its shared types and lists. Outside it, the change touches Studio's config storage in `@studio/common`, the lint configuration, and tests in other packages that list every provider by name. When the provider's models use an API Studio's agent doesn't run yet, it also touches the agent. The package README's "Adding a provider" steps leave some of these out. A developer who follows them gets a provider that passes typecheck but appears in no surface, and nothing reports it. Parts of the contract a provider implements belong to WordPress.com and don't say so. The package isn't open to external contributors yet, but Studio plans to open it.

After the change, a developer outside the Studio team adds a provider by adding its folder to the package and registering it once. The contract's types and the package documentation guide them, and every mistake is reported in their own files. The provider then appears in every Studio surface its capabilities reach. The six existing providers, and the accounts users have already connected, behave as before.

## Requirements

spec-requirement-1: A developer adds a new provider with two changes: a folder of its own in `@studio/providers`, and at most one registration elsewhere in the package. No other file needs to change: not elsewhere in the package, not in Studio's apps, `@studio/common` or `@studio/agent`, not the lint configuration, and not tests outside the new folder. With only those two changes, the provider typechecks, lints, passes knip and the test suites, and works in every surface spec-requirement-2 names. A new provider is one for a service that offers chat models, image generation, a place to publish local sites, or several of these, as the six providers in the package do today. Its account connects with an API key form, a device sign-in, a loopback sign-in, or several of these. Its chat models use one of the APIs spec-requirement-6 names.

origin: derived Goal ("add a new provider to `@studio/providers` easily"). Observed input: the two most recent provider additions, Google Gemini and GitHub Copilot, each changed files outside the package.

- Adding Google Gemini changed `packages/common/lib/provider-config.ts`, `packages/agent/shared/models.ts`, `packages/agent/browser/models.ts`, `eslint.config.mjs`, the bundle scripts, and tests in `packages/common`, `packages/agent` and `apps/studio`. Inside the package it changed `types.ts` (three places), `registry.ts` (three lists), `services.ts` and `models.ts`. observed: `git show --stat c0635aa23` and its diff.
- Adding GitHub Copilot changed `packages/common/lib/provider-config.ts`, `eslint.config.mjs`, and tests in `packages/common`, `packages/agent` and `apps/studio`, together with UI work for narrowing models to the account's plan. observed: `git show --stat aad3d2daa` and its diff.
- A sample provider (`.pipelines/providers-api-for-external-devs/1-spec/lanes/demands/spec/probe/sample-provider.patch`), added and then reverted, was reported by ESLint in its own `descriptor.ts` and in `registry.ts`, `types.ts` and `models.ts` until its folder name was added to the list in `eslint.config.mjs:445`. observed: probe, `.pipelines/providers-api-for-external-devs/1-spec/lanes/demands/spec/probe/2-registered-eslint.txt`.
- The same sample provider failed typecheck in `packages/common/lib/provider-config.ts:73`, `packages/agent/protocol/sessions/tests/model.test.ts` and `apps/studio/src/modules/user-settings/lib/tests/settings-tracks.test.ts`. observed: probe, `.pipelines/providers-api-for-external-devs/1-spec/lanes/demands/spec/probe/2-registered-repo-typecheck.txt`.
- Once the sample provider was listed as an AI provider, four tests failed in `packages/common/lib/tests/ai-settings.test.ts` and `packages/agent/protocol/sessions/tests/model.test.ts`, because they enumerate every provider's account. observed: probe, `.pipelines/providers-api-for-external-devs/1-spec/lanes/demands/spec/probe/3-listed-tests.txt`.
- A provider with remote sites also needs an entry in `packages/common/lib/remote-sites.ts:115`. observed: read `packages/common/lib/remote-sites.ts` and `packages/providers/README.md:59`.

spec-requirement-2: A registered new provider appears wherever its capabilities reach, with its label, description, logo and connect methods, and works there.
- A provider that offers chat models appears in Settings › Providers under AI providers. Once connected, it appears in the Default AI provider select, and its models appear in the chat model picker (only the ones its account runs, when the account narrows them). Chats run on its models. In `studio code`, it appears in `/connect`, `/disconnect`, `/provider` and `/model`.
- A provider that generates images generates them when it is the chat's provider, or when it is the first connected provider that offers images.
- A provider that offers remote sites appears in Settings › Providers under Hosting providers, and in the Default hosting provider select once connected. Its sites appear in a local site's publish panel, `studio push --remote-site <its id>[:<site>]` publishes to it, and Studio Code lists a local site's connected sites on it and publishes to them.
- Connecting it stores its config, which stays connected after Desktop, `studio ui` or the CLI restarts. A credential that expires is renewed before use, and the provider shows as disconnected once its config stops working.
- Studio on the web offers it with the connect methods the web supports today.

origin: derived Goal. Observed input: today, a registered provider reaches these surfaces only through the package's provider lists, and a provider registered by the README's steps is in none of them.

- The settings, the model picker, `studio code`'s commands, the publish panel and the agent's host build their provider lists from the registry's id lists. observed: read `apps/ui/src/data/settings-sections.ts:48-56`, `apps/ui/src/features/settings/settings-view/providers-panel.tsx:186-192`, `apps/ui/src/features/composer/model-picker.tsx:23`, `apps/cli/ai/slash-commands.ts:268,310,466`, `apps/ui/src/data/queries/use-remote-sites.ts:28`, `apps/cli/ai/host.ts:63` and `packages/common/lib/ai-settings.ts:54`.
- After the README's steps, the package typechecked with the sample provider in none of those lists. `normalizeProviderId( 'example' )` returned undefined and `findAiModel( 'example-large' )` returned nothing, while `getProvider( 'example' )` returned the provider. observed: probe, `.pipelines/providers-api-for-external-devs/1-spec/lanes/demands/spec/probe/2-registered-providers-typecheck.txt` and `.pipelines/providers-api-for-external-devs/1-spec/lanes/demands/spec/probe/2-registered-lists.json`.
- Once listed (`.pipelines/providers-api-for-external-devs/1-spec/lanes/demands/spec/probe/3-listed-lists.json`), the sample provider passed the `apps/ui` settings and model-picker tests unchanged. observed: probe, `.pipelines/providers-api-for-external-devs/1-spec/lanes/demands/spec/probe/3-listed-tests.txt`.
- Settings fall back to the descriptor's logo when Studio bundles no icon for the provider. observed: read `apps/ui/src/features/settings/settings-view/provider-logo.tsx:5-7`.
- Studio on the web offers form methods and hides device and loopback sign-ins. observed: read `apps/ui/src/features/settings/settings-view/ai-panel.tsx:28-33`.

spec-requirement-3: Typecheck or lint reports every part a new provider is missing for a capability it declares, and the report names the missing part. The report appears in the provider's folder or its registration, not in another package's file. A new provider that passes typecheck and lint is never left out of a surface spec-requirement-2 names for the capabilities it declares.

origin: derived Goal ("a clear, well-defined API"). Observed input: a provider part-way through being written, as a developer has it while following the README.

- The sample provider's model ids were rejected in its own `descriptor.ts` until they were added to a shared union in `packages/providers/models.ts:9`, which the README doesn't mention. observed: probe, `.pipelines/providers-api-for-external-devs/1-spec/lanes/demands/spec/probe/1-readme-steps-providers-typecheck.txt`.
- With the sample provider registered but left out of the AI provider list, typecheck passed and no surface listed it. observed: probe, `.pipelines/providers-api-for-external-devs/1-spec/lanes/demands/spec/probe/2-registered-lists.json`.
- The missing config store was reported in `@studio/common`, not in the provider. observed: probe, `.pipelines/providers-api-for-external-devs/1-spec/lanes/demands/spec/probe/2-registered-repo-typecheck.txt`.
- The lint errors were reported in the package's shared files, with a message that doesn't name the fix. observed: probe, `.pipelines/providers-api-for-external-devs/1-spec/lanes/demands/spec/probe/2-registered-eslint.txt`.
- What surfaces read (`Provider.ai`, `Provider.sites`) and the matching services (`ProviderServices.ai`, `ProviderServices.sites`) are optional independently of each other. A provider that lists models without a model connection is reported only when a chat starts: "offers no AI models". observed: read `packages/providers/types.ts:173,179,305,320` and `apps/cli/ai/auth.ts:89-91`.

spec-requirement-4: The package's documentation is enough for a developer who has never worked on Studio to add a provider. It lists the steps, which are exactly the changes spec-requirement-1 allows. For each capability, it describes the parts a provider fills in. It names the connect methods a new provider can use and the model APIs spec-requirement-6 names, and says how to test the provider. A developer who follows only the documentation ends with a provider that meets spec-requirement-1 and spec-requirement-2.

origin: derived Goal ("a clear, well-defined API"). Observed input: the README's "Adding a provider" steps, followed as written, produce a provider that appears nowhere.

- The README's steps name `ProviderId`, `ProviderConfigs`, `registry.ts`, `services.ts`, `provider-config.ts`, `ProviderSites` and `remote-sites.ts`. observed: read `packages/providers/README.md:57-59`.
- The steps leave out `AiProviderId`, the registry's `AI_PROVIDER_IDS`, `SITES_PROVIDER_IDS` and `STORED_PROVIDER_IDS`, the `AiModelId` union, the folder list in `eslint.config.mjs`, and the agent's API support. observed: probe, `.pipelines/providers-api-for-external-devs/1-spec/lanes/demands/spec/probe/README.md` steps 1-3.

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

spec-requirement-6: A developer can tell from the contract which model APIs Studio's agent runs: `openai-completions`, `openai-responses`, `anthropic-messages` and `google-generative-ai`. A new provider whose models use one of these chats in the Desktop app, `studio ui`, `studio code`, and Studio on the web where its account connects, with no change outside the package. A provider whose model connection names any other API gets a report that names the API, either from typecheck or as the chat's error, and its requests are never sent over a different API.

origin: derived Goal. Observed input: adding Google Gemini, a provider whose models use an API the agent didn't run, required changes to the agent.

- The agent picks how to stream from the connection's `model.api`. `openai-completions`, `anthropic-messages` and `google-generative-ai` have their own stream. Every other API is sent as `openai-responses`, including the six other APIs pi's type allows, such as `mistral-conversations` and `bedrock-converse-stream`. observed: read `packages/agent/shared/models.ts:17-29` and `node_modules/@earendil-works/pi-ai/dist/types.d.ts:20-21`.
- Gemini's addition changed `packages/agent/shared/models.ts` and `packages/agent/browser/models.ts`. observed: `git show c0635aa23 -- packages/agent`.

spec-requirement-7: The package's boundaries apply to a new provider's folder as they do to the existing ones, with no lint configuration change. ESLint reports a new provider's code that imports Node APIs or another workspace package. It also reports the provider's files that surfaces read when they import anything beyond each other and the package's shared surface files. A new provider whose files keep within these boundaries lints clean.

origin: derived Goal ("a well-defined API"). Observed input: the folder a new provider adds. Today the surface boundary covers only the folders listed by name.

- The surface boundary rule lists the provider folders by name, so the sample provider's `descriptor.ts` importing its own `config.ts` was reported as a violation. observed: read `eslint.config.mjs:33-45,433-457`, and probe, `.pipelines/providers-api-for-external-devs/1-spec/lanes/demands/spec/probe/2-registered-eslint.txt`.
- The rules against Node APIs and other workspace packages cover every file in the package. observed: read `eslint.config.mjs:410-431`.

spec-requirement-8: Every account connected before the change stays connected after it, in Desktop, `studio ui`, the CLI and Studio on the web. So do the selected chat provider, the default hosting provider, the remote sites connected to each local site, and the provider each chat is pinned to. Builds from before the change keep reading what builds after it store.

origin: derived Goal. Observed input: the `shared.json`, session entries and Studio on the web settings that today's builds write for the six providers. The change reshapes the API that reads and writes them.

- Configs are stored as follows:
  - WordPress.com in `authToken`;
  - an Anthropic API key in `anthropicApiKey`;
  - the other providers, and Anthropic's subscription token, in `providerConfigs.<id>`.

  Alongside them, `rememberedSignIns` and `signInHostId` are stored. observed: read `packages/common/lib/provider-config.ts:73-144,179-216`.
- The selected chat provider is stored in `aiProvider`, with Anthropic written as `anthropic-api-key`, and session entries record the same stored ids. observed: read `packages/providers/registry.ts:62-84` and `packages/agent/protocol/sessions/model.ts:84-87`.
- Remote-site connections are stored in `connectedWpcomSites` for WordPress.com and `remoteSites` for the other providers, and the default hosting provider in the user preferences. observed: read `packages/common/lib/remote-sites.ts:115-133` and `packages/common/lib/user-settings/user-preferences.ts:106`.
- Studio on the web keeps configs per id in its stored AI settings. observed: read `apps/static/src/agent/index.ts:227-259`.

spec-requirement-9: WordPress.com, Anthropic, OpenAI, Google Gemini, GitHub Copilot and Spacefast behave as before in every surface: connecting, disconnecting, chatting, model lists, image generation, publishing and pulling. This holds when a new provider is also connected. WordPress.com stays first wherever Studio picks the first connected or ready provider. When a new provider lists a model id an existing provider also lists, that model keeps the existing provider's label, image support and paid-credit rule.

origin: derived Goal. Observed input: the six registered providers. GitHub Copilot already lists model ids that Anthropic, OpenAI and Google Gemini also list, as a new provider that resells models would.

- The order of the AI provider list decides fallback, and `findAiModel` returns the first provider that lists a model id. observed: read `packages/providers/registry.ts:18-24`, `packages/providers/models.ts:31-41`, `apps/cli/ai/auth.ts:39-48` and `packages/agent/protocol/sessions/model.ts:108-111`.
- GitHub Copilot lists `claude-sonnet-5-5`, `gpt-6.1-terra` and `gemini-4-argon`. observed: read `packages/providers/github-copilot/descriptor.ts:6-10`.
- Labels, image support and the paid-credit lock are read through `findAiModel`. observed: read `apps/ui/src/features/composer/model-picker.tsx:71,127`, `composer.tsx:389` and `use-model-access.ts:41`.

## Acceptance criteria

spec-acceptance-criterion-1: Given a new provider that serves chat models over one of the APIs spec-requirement-6 names and connects with an API key form, when a developer adds it by following the package documentation, then it needs no change beyond its folder and at most one registration in the package, and `npm run typecheck`, ESLint on the changed files, `npm run knip` and `npm test` all pass.

spec-acceptance-criterion-2: Given a new provider that publishes local sites, as a WordPress archive or as a static export, and connects with a device sign-in, when a developer adds it by following the package documentation, then it needs no change beyond its folder and at most one registration in the package, and `npm run typecheck`, ESLint on the changed files, `npm run knip` and `npm test` all pass.

spec-acceptance-criterion-3: Given the chat provider from spec-acceptance-criterion-1, when the user opens Settings › Providers in the Desktop app, `studio ui` and Studio on the web, then all of the following hold in each app:
- the provider is listed under AI providers with its label, logo and description;
- entering a key connects it, after which it appears in the Default AI provider select;
- the chat model picker lists its models;
- a chat on one of its models gets a reply.

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

spec-acceptance-criterion-6: Given new providers whose accounts connect through a device sign-in, through a loopback sign-in, or through a choice of several methods, when the user connects each from Settings in the Desktop app and from `/connect` in `studio code`, then each connects the way it declares and shows its account summary. Studio on the web offers only the methods it supports today.

spec-acceptance-criterion-7: Given a new provider that declares any of the account and model features below, when the user uses it in Settings, the chat model picker, `/model` and a chat, then each declared feature works with no change outside the package:
- an account that narrows the models it runs: the pickers offer only those models;
- image generation: its images are used when it is the chat's provider;
- a credential that expires and renews: Studio renews it before use, and shows the provider as disconnected once the provider rejects it.

spec-acceptance-criterion-8: Given a new provider registered in the package that lists models but has no model connection, or presents remote sites but cannot push to them, when the developer runs typecheck and ESLint, then the error appears in the provider's folder or its registration and names the missing part.

spec-acceptance-criterion-9: Given any new provider that passes typecheck and ESLint, when the user opens the surfaces spec-requirement-2 names for its declared capabilities, then the provider is listed in each of them.

spec-acceptance-criterion-10: Given only the package documentation, when a developer who has never worked on Studio looks up how to add a provider, then the documented steps match the changes spec-acceptance-criterion-1 and spec-acceptance-criterion-2 allow. The documentation describes every part of the contract each capability needs, names the connect methods a new provider can use, names the four model APIs Studio runs, and says how to test the provider.

spec-acceptance-criterion-11: Given the contract in the package, when a developer looks up any value their provider declares, receives or returns, then the contract states what the value means, whether a new provider supplies or acts on it, and what Studio does with it. A `redirect` connect method, models gated on paid AI credits, the push and pull options, the `planRequired` list option and the pull steps are each either unavailable to a new provider or state which provider they belong to and what a new provider does with them.

spec-acceptance-criterion-12: Given a new provider whose model connection uses `openai-completions`, `openai-responses`, `anthropic-messages` or `google-generative-ai`, when the user chats on one of its models in the Desktop app, `studio ui`, `studio code`, and Studio on the web where its account connects, then the reply streams over that API.

spec-acceptance-criterion-13: Given a new provider whose model connection names any other API, such as `mistral-conversations`, when the developer typechecks it or the user starts a chat on one of its models, then the developer is told that Studio doesn't run that API, by typecheck or as the chat's error, and no request goes out over a different API.

spec-acceptance-criterion-14: Given a new provider's folder whose files surfaces read import its services code, or whose code imports a Node API or another workspace package, when ESLint runs on its files with the lint configuration unchanged, then ESLint reports each such import. When the folder keeps within those boundaries, ESLint reports nothing.

spec-acceptance-criterion-15: Given `shared.json`, session entries and Studio on the web settings written by a build from before the change, with every provider each app offers connected, `aiProvider` set to `anthropic-api-key`, a default hosting provider, and WordPress.com sites and Spacefast Spaces connected to local sites, when a build from after the change starts, then Settings, `studio code` and the publish panel show:
- the same accounts connected, with the same summaries;
- the same default AI provider and default hosting provider;
- the same connected sites.

Existing chats keep their pinned provider. When a build from before the change then reads what the new build stored, it shows the same.

spec-acceptance-criterion-16: Given the six existing providers, with or without a new provider also connected, when the user connects, disconnects, chats, picks models, generates images, publishes and pulls with each in Settings, the chat, the publish panel and `studio code`, then each behaves as before the change. WordPress.com stays first when Studio picks the first connected provider. A model id a new provider shares with an existing provider shows the existing provider's label, image support and paid-credit lock.

## Exclusions

spec-exclusion-1: Opening the package to external contributors: publishing it, or setting up how outside contributions are accepted.

spec-exclusion-2: Loading providers that live outside Studio's source at run time, such as plugins or user configuration.

spec-exclusion-3: Studio's agent running model APIs beyond `openai-completions`, `openai-responses`, `anthropic-messages` and `google-generative-ai`.

spec-exclusion-4: Capabilities beyond an account, AI and remote sites, such as previews offered by a provider.

spec-exclusion-5: Providers bringing their own UI components. Surfaces render a new provider from what it declares.

spec-exclusion-6: Removing the places where surfaces name WordPress.com or Spacefast today: the Studio sign-in, WordPress.com's sync statuses and plan flows, and Spacefast's connect dialog in Settings.

## Considered and not required

- Reading "external developers" as third parties who ship providers outside Studio's repository, loaded at run time. Not taken: the Goal says "add a new provider to `@studio/providers`", intent-context-1 speaks of contributors to the package, and `docs/design-docs/providers.md` (Out of scope) compiles providers in.
- A new provider whose models use an API pi supports but Studio doesn't run, chatting with no change outside the package. Not taken: running such an API ships its SDK in every build. observed: `apps/studio/forge.config.ts:289-297` and `scripts/create-*-bundle.ts` strip the Mistral and AWS SDKs, and Gemini's addition removed `@google/genai` from those lists in c0635aa23. That makes it a decision for Studio, not part of a provider contribution.
- A new host that pulls sites back. No provider except WordPress.com pulls. observed: `packages/providers/spacefast/descriptor.ts` has `pull: false`, and the SSH host in `docs/design-docs/providers.md` is planned.
- A provider connected with a form whose API rejects calls from a page, offered in Studio on the web. No source shows such a provider. observed: Studio on the web filters providers by connect-method kind only, in `apps/ui/src/features/settings/settings-view/ai-panel.tsx:28-33`.
- A new provider that needs an app icon bundled in `apps/ui`. Not needed: surfaces fall back to the descriptor's logo. observed: `apps/ui/src/features/settings/settings-view/provider-logo.tsx:5-7`.
- A new provider with its own connect dialog in Settings, as Spacefast has. Not needed: the generic provider row shows a device sign-in's code. observed: `apps/ui/src/features/settings/settings-view/ai-panel.tsx:147-163`, which GitHub Copilot connects through.
- Reading "easily" as a generator that creates a provider's folder. No source shows one. observed: `packages/providers/README.md` points developers to "a folder laid out like the others", and spec-requirement-4 makes the documentation enough on its own.
