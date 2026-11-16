# Spec: A providers API that external developers add a provider through

## Overview

A provider in `@studio/providers` is written today as two objects: what surfaces show of it and what it does. Each is split into an account, AI and remote sites, and nothing ties the two together. A provider can list models it can't connect to, or present sites it can't pull or create. It can name a default model it doesn't list, or run its operations under another provider's id. All of these compile, and each fails only when a user reaches it. Each provider also repeats checks and values that are the same for every provider: it re-checks a form's values, rejects a missing config, rejects a model it doesn't list, and states the same cost and limits on every model. Some parts of the contract belong to WordPress.com without saying so: the Studio sign-in, paid AI credits, and sync's push options and pull steps. Some values a provider supplies are read by nothing. Adding a provider also means editing shared lists and files outside the package that the README doesn't name. The newest providers, Meta and the xAI and Local LLM providers on their branches, each changed Studio's apps or other packages. The Local LLM provider also had to change the contract itself, because its models are the ones a server the user runs lists.

After the change, a developer outside the Studio team adds a provider through an API where each capability a provider offers is supplied whole. The repository's checks report a missing or contradictory part before anyone runs it. The developer writes only what is particular to the provider, and every value is explained where they look it up. They change only the package, guided by its documentation, and the provider works in every surface its capabilities reach. The seven existing providers, and everything users have saved, behave as before.

## Requirements

spec-requirement-1: A developer adds a new provider by changing only `@studio/providers`. The provider has its own id, config, connect methods and model ids. It offers chat models, remote sites, or both, and may generate images alongside its chat models. No file outside the package changes: not Studio's apps, `@studio/common` or `@studio/agent`, not the repository's lint configuration, and not other packages' tests. With only those changes, the repository's checks pass: typecheck, lint on the changed files, knip and the tests. The provider then appears and works in every surface its capabilities reach, as the existing providers do:
- Settings › Providers and the default AI and hosting provider selects;
- the chat model picker and chats;
- `studio code`'s `/connect`, `/disconnect`, `/provider` and `/model`;
- image generation;
- the publish panel, `studio push --remote-site <its id>`, and the agent's remote-site tools.

This holds in the Desktop app and `studio ui`, and in Studio on the web for the connect methods and the kinds of publishing the web offers.

origin: derived Goal ("external developers can add a new provider to `@studio/providers` easily") — the Google Gemini, GitHub Copilot and Meta providers as merged, and the xAI and Local LLM providers on their branches, each of which changed files outside the package

- Adding Meta changed the following, besides its own folder and the package's `types.ts`, `registry.ts`, `services.ts` and `models.ts`: `eslint.config.mjs`, `packages/common/lib/provider-config.ts`, and tests in `apps/studio`, `packages/agent` and `packages/common`. Adding Google Gemini also changed `packages/agent/shared/models.ts` and `packages/agent/browser/models.ts`. observed: `git show --stat eb3225c1f aad3d2daa c0635aa23`, saved in `.pipelines/providers-api-for-external-devs-v3/1-spec/spec/provider-additions-stat.txt`.
- The xAI branch changed the same files as Meta, and added an icon in `apps/ui`. The Local LLM branch changed 43 files outside the package, across `apps/cli`, `apps/local`, `apps/studio`, `apps/ui`, `packages/agent`, `packages/common` and `eslint.config.mjs`. observed: `git diff --stat` against each branch's merge base, saved in `.pipelines/providers-api-for-external-devs-v3/1-spec/spec/provider-branches-stat.txt`.
- The contract rejects a new provider id and a new model id until each is added to the package's shared lists of every provider id and every model id. observed: probe, `.pipelines/providers-api-for-external-devs-v3/1-spec/spec/contract-probe.ts.txt` cases 1 and 2, with the typecheck output in `.pipelines/providers-api-for-external-devs-v3/1-spec/spec/contract-probe-tsc.txt`.
- Surfaces find providers through the package's hand-kept id lists. observed: read `apps/ui/src/data/settings-sections.ts:53-56,300-331`, `apps/cli/ai/slash-commands.ts:268,310,466`, `apps/cli/ai/auth.ts:42,136`, `apps/cli/ai/host.ts:63` and `packages/common/lib/ai-settings.ts:54`.

spec-requirement-2: For each capability a provider offers, the developer supplies what surfaces show of it and what the provider does for it as one whole. A provider supplies nothing for a capability it doesn't offer: a chat provider supplies no sites, and a publishing provider no models or pulls. Before the provider runs, the repository's checks report each of the following at the new provider's code, naming the part:
- a provider that lists chat models but has no connection to them, or has a model connection but lists no models;
- a default model that isn't one of the models the provider lists;
- a provider that presents remote sites but can't list them or push to them;
- a provider that says its sites can be pulled, or that Studio creates new ones, without pulling or creating them;
- a push that takes a different kind of content from the kind the provider says it publishes, a WordPress archive or a static export;
- operations that run under another provider's id;
- an account description that names a connect method the provider doesn't declare.

origin: derived intent-proposal-1 ("the provider and providerService type basically, the different capabilities") and Goal ("a clear, well-defined API") — a provider written by copying another provider's folder, as `packages/providers/README.md:59` tells developers to, then edited part by part

- Today's providers combine capabilities independently: Anthropic, OpenAI, Google Gemini, GitHub Copilot and Meta offer AI only, Spacefast publishes without AI or pull, and WordPress.com offers both. observed: probe, `.pipelines/providers-api-for-external-devs-v3/1-spec/spec/api-observation.txt`, produced by `.pipelines/providers-api-for-external-devs-v3/1-spec/spec/observe-api.txt`.
- A copy of Anthropic's folder keeps Anthropic's id in its operations and Anthropic's default model. observed: read `packages/providers/anthropic/services.ts:7` and `packages/providers/anthropic/descriptor.ts:100`.
- The contract accepts each of these mismatches: case 3 (a default model the provider doesn't list, an undeclared method in the account description), case 4 (operations registered as Meta that name Google Gemini) and case 5 (models, pulls, Studio-created sites and archive pushes presented, none of them implemented). observed: probe, `.pipelines/providers-api-for-external-devs-v3/1-spec/spec/contract-probe-tsc.txt`.
- The model picker lists a provider's models from what surfaces show (`packages/providers/models.ts:23-29`). A chat on a provider with no model connection fails with "<provider> offers no AI models." observed: read `apps/cli/ai/auth.ts:89-91`.
- A pull, or creating a site, on a provider that doesn't implement it fails when the user tries it: "<provider> sites can't be pulled." and "Studio can't create <provider> sites." Spacefast's push refuses an archive itself, when it runs. observed: read `packages/common/sites/remote-sites.ts:46-49,62-65` and `packages/providers/spacefast/sites.ts:57`.
- Connecting stores the config under the id the operations carry, not the id they are registered under. Operations copied with another provider's id therefore overwrite that provider's account. observed: read `packages/common/lib/ai-settings.ts:81-88`.
- Settings mark the connected method by matching the account's method id against the declared ones. A method id the provider doesn't declare leaves none marked. observed: read `apps/ui/src/features/settings/settings-view/ai-panel.tsx:50,91`.

spec-requirement-3: A new provider can narrow the models it offers to the ones the connected account runs, and can say that a config can't generate images, as the existing providers do. The model pickers and `/model` then offer only the models the account runs. Studio never asks that config to generate images, and takes image generation from the next connected provider that offers it, as it does today.

origin: derived intent-proposal-1 ("the different capabilities") — GitHub Copilot, whose plan decides which of its models an account runs, and OpenAI, whose ChatGPT sign-in generates no images

- GitHub Copilot's account description lists the models the plan runs. observed: read `packages/providers/github-copilot/descriptor.ts:26-34`.
- OpenAI generates images only with an API key: the ChatGPT sign-in's config can't. observed: read `packages/providers/openai/ai.ts:50`, and probe, `.pipelines/providers-api-for-external-devs-v3/1-spec/spec/api-observation.txt` ("OpenAI image support by connection method").
- Image generation skips a provider whose config can't generate images, and takes the next connected provider that offers it. observed: read `apps/cli/ai/auth.ts:118-145`.

spec-requirement-4: A developer writing a provider writes only what is particular to it. They don't write any of the following:
- **A second check of a form's values.** In every app, a value the form's schema rejects shows the schema's message, and the provider isn't called. A field the schema accepts empty may be left empty. The provider receives the values as the schema parsed them, under the id of a method it declares.
- **A check for a missing config.** A provider's chat, image and site operations always receive a config. When the provider isn't connected, the user is told that the provider, by its name, isn't connected, and how to connect it.
- **A check that the model asked for is on the provider's list.** Studio asks a provider with a fixed list of models only for models on it.
- **The values every provider's model connection states identically today.** These are a zero cost, a 200,000-token context window and a 32,000-token output limit. A provider whose models have limits of their own still states them.

origin: derived Goal ("add a new provider … easily") — the checks and values each existing provider repeats, and the Local LLM provider's form, whose API key field may be left empty

- Each operation that needs a config rejects a missing one itself: 12 places across all seven providers. Each model connection rejects a model the provider doesn't list itself: six providers. Six providers state the same cost, and five the same context window and output limit; WordPress.com's appear as its tier limits. Four providers parse their form's values again with the form's own schema. observed: grep, `.pipelines/providers-api-for-external-devs-v3/1-spec/spec/repeated-code.txt`.
- Settings only check that every field is filled before calling the provider, so a field the schema accepts empty blocks the form. `studio code` checks each field against its schema. observed: read `apps/ui/src/features/settings/settings-view/ai-panel.tsx:61,228` and `apps/cli/lib/providers.ts:48-52`.
- Studio already checks that a model is on the provider's list before asking for a connection to it. observed: read `apps/studio/src/ipc-handlers.ts:381`, `apps/local/src/index.ts:2231`, `packages/agent/protocol/sessions/model.ts:70` and `apps/cli/commands/ai/index.ts:79`.
- `studio code` adds how to connect to a provider's not-connected message: "Use /connect <id> to connect it." observed: read `apps/cli/ai/auth.ts:104-112`.
- The Local LLM provider's form has a server address and an API key "only if your server asks for one", which the schema accepts empty. observed: read `local-llm/descriptor.ts` on `rp/local-llm-connector`, saved in `.pipelines/providers-api-for-external-devs-v3/1-spec/spec/local-llm-provider.diff.txt`.

spec-requirement-5: A provider can offer, as its chat models, the models a server the user runs lists, instead of a list known when Studio is built. Once it is connected, the following hold:
- The model pickers in the apps and `/model` in `studio code` offer the models the server lists at that time.
- A chat runs on the model picked.
- A conversation keeps its model when it is reopened.

Adding such a provider meets spec-requirement-1.

origin: derived Goal ("add a new provider … easily") — the Local LLM provider on `rp/local-llm-connector`, whose models a server such as Ollama or LM Studio lists

- To offer those models, the Local LLM provider added a second kind of AI capability to the contract, a model id scheme for the server's models, and an operation that lists them. It also changed 43 files outside the package. observed: `git diff` of `packages/providers/types.ts`, `models.ts` and `connection.ts` on that branch, saved in `.pipelines/providers-api-for-external-devs-v3/1-spec/spec/local-llm-provider.diff.txt`, and `.pipelines/providers-api-for-external-devs-v3/1-spec/spec/provider-branches-stat.txt`.
- Today a provider's models are a fixed list, and the contract accepts only model ids from the providers' lists. observed: read `packages/providers/types.ts:176-181` and `packages/providers/models.ts:10-17`.

spec-requirement-6: A provider can keep a connect method out of Studio on the web when that method can't complete in a page. Studio on the web then doesn't offer the method; the Desktop app, `studio ui` and `studio code` still do. Device and loopback sign-ins stay out of Studio on the web, as today.

origin: derived Goal ("add a new provider … easily") — the Local LLM provider's server address form, which only a process on the user's computer can check

- The Local LLM provider had to add a flag for this to the contract. observed: read `local-llm/descriptor.ts` and the `types.ts` diff on `rp/local-llm-connector`, saved in `.pipelines/providers-api-for-external-devs-v3/1-spec/spec/local-llm-provider.diff.txt`.
- Studio on the web chooses methods by kind alone: it offers every form, and leaves out device and loopback sign-ins. observed: read `apps/ui/src/features/settings/settings-view/ai-panel.tsx:28-33` and `docs/design-docs/providers.md:115`.

spec-requirement-7: A new provider's operations receive its own config and its own sites, and none of another provider's options. Each part of the contract below belongs to WordPress.com. Each is either unavailable to a new provider, or says it is WordPress.com's and what it does for any provider that uses it, and the apps then do that for that provider:
- the `redirect` connect method, which is the Studio sign-in;
- models gated on paid AI credits, and a default model for accounts that have them;
- the push options, which carry WordPress.com sync's selection of files and its launch after a push;
- the `planRequired` option when listing sites;
- pulling through a remote backup and a Reprint exporter with its key;
- a checkout on the provider's site to make a new site;
- backups that a selective pull browses;
- the push phases for a remote backup and a launch, and a push that ends with a launch error.

origin: derived Goal ("a clear, well-defined API") — a new provider written by copying WordPress.com's folder, which the contract accepts today, and Spacefast's push, which receives WordPress.com sync's options

- Each provider's operations receive its own config and its own sites. observed: read `packages/providers/types.ts:153-183,240-324` and `packages/providers/services.ts:10-25`.
- The contract accepts a `redirect` method and a model gated on paid AI credits on a provider other than WordPress.com. observed: probe, case 3 in `.pipelines/providers-api-for-external-devs-v3/1-spec/spec/contract-probe-tsc.txt`.
- For any provider's `redirect` method, `studio code` runs the WordPress.com login. When a provider's first method is a `redirect`, `/disconnect` signs out of Studio. Settings never offer a `redirect` method. observed: read `apps/cli/lib/providers.ts:144-145`, `apps/cli/ai/slash-commands.ts:323-327` and `apps/ui/src/features/settings/settings-view/ai-panel.tsx:28-33`.
- Any provider's model gated on paid AI credits is locked unless the WordPress.com account has bought credits. observed: read `apps/ui/src/features/composer/use-model-access.ts:38-42` and `apps/cli/ai/slash-commands.ts:404`.
- Every hosting provider's push receives WordPress.com sync's options, defined in WordPress.com's folder. The list takes `planRequired`, and a pull is remote backups and a Reprint exporter. Spacefast ignores the push options. observed: read `packages/providers/types.ts:10,132-134,147,226-229,240-288`, `packages/providers/wpcom/sites/site.ts:51-67` and `packages/providers/spacefast/sites.ts:55-74`.

spec-requirement-8: The contract explains every value Studio hands a provider and every value a provider gives back, where a developer looks it up. This covers the provider's identity and presentation, its account's config and connect methods, its connection's renewal and expiry, and each capability's operations, with their inputs and results. For each value it says:
- what the value means;
- whether a new provider must supply it or act on it;
- what Studio does with it.

The contract asks a provider for no value that Studio does nothing with.

origin: from-intent Goal ("through a clear, well-defined API")

- Four providers, and Studio's own loopback sign-in, give a failed connection a reason: declined, invalid or unverified. Nothing in Studio's apps reads it. observed: grep, `.pipelines/providers-api-for-external-devs-v3/1-spec/spec/repeated-code.txt`.
- The model connection's fields (the pi provider name, the key, the model) have no explanation beyond "Everything the runtime needs to register one model with pi". observed: read `packages/providers/types.ts:185-195`.

spec-requirement-9: The contract names the model APIs Studio's agent runs: `openai-completions`, `openai-responses`, `anthropic-messages` and `google-generative-ai`. A new provider whose models use one of these chats in the Desktop app, `studio ui`, `studio code`, and Studio on the web where its account connects. When a provider's model connection names any other API, the developer is told so, by the repository's checks or as the chat's error. Its requests are never sent over a different API.

origin: derived Goal ("a clear, well-defined API") — a model connection built from pi's catalog entry for the model, as the Google Gemini, Meta and OpenAI providers build theirs, for a service whose catalog uses another API

- pi's catalogs name the API of each model. Mistral's models are `mistral-conversations`, and Amazon Bedrock's are `bedrock-converse-stream`. observed: node probe of pi-ai 1.5.0's catalogs, `.pipelines/providers-api-for-external-devs-v3/1-spec/spec/pi-catalog-apis.txt`, and read `packages/providers/meta/ai.ts:14-19`.
- The contract accepts a connection on `mistral-conversations`. observed: probe, case 6 in `.pipelines/providers-api-for-external-devs-v3/1-spec/spec/contract-probe-tsc.txt`.
- The agent sends every API other than three as `openai-responses`. observed: read `packages/agent/shared/models.ts:21-28`.
- Adding Google Gemini needed `google-generative-ai` added to the agent. observed: `git show --stat c0635aa23 -- packages/agent`.

spec-requirement-10: The package's boundaries hold for a new provider with no change outside the package:
- its code uses no Node API, so it runs in the page as in Node;
- its code uses no other workspace package;
- what surfaces show of it — its label, logo, description, connect methods, forms and models — is available without its operations, so without credentials and without a request to its service.

The repository's checks report a new provider that crosses one of these boundaries, at the code that crosses it. A new provider that keeps within them passes.

origin: derived Goal ("add a new provider … easily") — Meta's addition, which had to add its folder's name to the boundary that keeps what surfaces read apart from the operations

- The boundary against Node APIs and other workspace packages covers every file in the package. The boundary for what surfaces read lists the provider folders by name. observed: read `eslint.config.mjs:410-457` and `git show eb3225c1f -- eslint.config.mjs`.
- Every existing provider's description, connect methods, forms and models are read with no request to a provider's service. observed: probe, `.pipelines/providers-api-for-external-devs-v3/1-spec/spec/api-observation.txt` ("Provider fetch calls: 0").

spec-requirement-11: The package's documentation is enough for a developer who has never worked on Studio to add a provider. It covers:
- every step of adding one, all inside the package;
- for each capability, the parts a provider supplies;
- which parts are the provider's to do and which Studio does for it;
- each kind of connect method, and the apps that offer it;
- the errors a provider reports, and what Studio does with each;
- which of its values Studio stores, which therefore never change;
- that its code runs in Node and in the page;
- the model APIs Studio runs;
- how to test a provider.

Every provider in the package follows what the documentation describes. A developer who copies any of them, as the documentation tells them to, starts from the documented API.

origin: derived Goal ("add a new provider … easily") — the README's steps for adding a provider, followed as written

- The README's steps name `ProviderId`, `ProviderConfigs`, `registry.ts`, `services.ts`, `provider-config.ts`, `ProviderSites` and `remote-sites.ts`. observed: read `packages/providers/README.md:57-59`.
- Adding Meta also changed the following, which the steps leave out:
  - the AI provider id type;
  - the registry's AI provider list and its stored ids;
  - the shared model id type;
  - the folder list in `eslint.config.mjs`;
  - three packages' tests.

  observed: `git show eb3225c1f`.

spec-requirement-12: The seven providers behave as before for users, in every surface. They are WordPress.com, Anthropic, OpenAI, Google Gemini, GitHub Copilot, Meta and Spacefast, and the following are unchanged:
- connecting with each method, and the account's summary, note and links;
- renewing a credential before use, and treating an expired config as disconnected;
- disconnecting;
- the models each offers, narrowed to the plan for GitHub Copilot;
- default models, including WordPress.com's default for accounts with paid AI credits;
- chats and their error messages;
- image generation, which a ChatGPT plan doesn't offer;
- publishing, pulling and selective sync;
- what Studio on the web leaves out: device and loopback sign-ins, and publishing a static export.

Wherever Studio picks the first connected or ready provider, WordPress.com stays first. A model id that several providers list keeps the first listing's label, image support and paid-credit lock.

origin: derived Goal ("add a new provider … easily") — the seven registered providers, which every surface reaches through the API this change reshapes

- WordPress.com is first in the AI provider list, whose order decides fallback. `findAiModel` returns the first provider that lists a model id. observed: read `packages/providers/registry.ts:18-26`, `packages/providers/models.ts:32-43` and `apps/cli/ai/auth.ts:39-48`.
- GitHub Copilot lists model ids that Anthropic, OpenAI and Google Gemini also list. observed: read `packages/providers/github-copilot/descriptor.ts:6-10`.
- Studio on the web publishes only to providers that take a WordPress archive, since a static export needs the site to run on native PHP. observed: read `apps/ui/src/data/queries/use-remote-sites.ts:24-31`.

spec-requirement-13: Everything users saved before the change reads the same after it. Builds from before the change keep reading what builds after it store. This covers:
- provider configs: WordPress.com's in `authToken`, an Anthropic API key in `anthropicApiKey`, and the others in `providerConfigs.<id>`;
- remembered sign-ins and the sign-in host id;
- the selected chat provider, with Anthropic stored as `anthropic-api-key`;
- the default hosting provider;
- remote-site connections, in `connectedWpcomSites` and `remoteSites`;
- the configs Studio on the web keeps;
- the provider and model each conversation is pinned to.

origin: derived Goal ("add a new provider … easily") — the `shared.json`, session entries and Studio on the web settings today's builds write, which are read and written through the API this change reshapes

- The storage is as listed above. Readers map `anthropic-api-key` to Anthropic because older builds fall back to WordPress.com on an id they don't know. observed: read:
  - `packages/common/lib/provider-config.ts:69-145,180-217`;
  - `packages/providers/registry.ts:65-88`;
  - `packages/common/lib/remote-sites.ts:115-133`;
  - `packages/common/lib/user-settings/user-preferences.ts:106`;
  - `apps/static/src/agent/index.ts:227-259`;
  - `packages/agent/protocol/sessions/model.ts:84-87`.
- Desktop and CLI builds of different versions read the same `shared.json` and session files, so persisted values are only ever added, or read through a mapping. observed: read `docs/design-docs/providers.md:24`, and probe, `.pipelines/providers-api-for-external-devs-v3/1-spec/spec/api-observation.txt` ("Anthropic persisted id").

## Acceptance criteria

spec-acceptance-criterion-1: Given a new provider that serves chat models over one of the four APIs Studio runs, connects with an API key form, and supplies nothing for images or remote sites, when a developer adds it following only the package documentation, then:
- no file outside `@studio/providers` changes, and the repository's checks pass;
- in the Desktop app, `studio ui` and Studio on the web, Settings list it under AI providers with its label, logo and description;
- connecting it with a key puts it in the Default AI provider select and its models in the chat model picker;
- a chat on one of its models gets a reply;
- it is still connected after the app restarts or the page reloads.

spec-acceptance-criterion-2: Given the provider of spec-acceptance-criterion-1, when the user runs `studio code`, then:
- `/connect` offers it and asks for its form's fields;
- `/provider` switches to it, `/model` lists its models, and a prompt gets a reply;
- `/disconnect` removes it.

spec-acceptance-criterion-3: Given a new provider that publishes a static export of local sites, connects with a device sign-in, and supplies nothing for AI or pulling, when a developer adds it following only the package documentation, then:
- no file outside the package changes, and the repository's checks pass;
- in the Desktop app and `studio ui`, it is listed under Hosting providers and connects with the code shown in its row;
- once connected, it appears in the Default hosting provider select, and the publish panel lists its sites and creates one;
- a push from the panel, or from `studio push --remote-site <its id>`, publishes the local site to it.

spec-acceptance-criterion-4: Given a new provider that offers chat models, image generation and remote sites, whose credential expires and renews, and that connects with a loopback sign-in or a choice of several methods, when the user connects it once from Settings in the Desktop app, then:
- it is listed under both AI providers and Hosting providers;
- its models are in the chat model picker, and a chat that asks for an image gets one from it;
- its sites are in the publish panel;
- its credential is renewed before use once it is about to expire.

spec-acceptance-criterion-5: Given a new provider with any one of the following, when the developer runs the repository's checks, then they fail at that provider's code with a report that names the part:
- chat models listed with no model connection, or a model connection with no models;
- a default model it doesn't list;
- sites it can't list or push to;
- sites that say they pull, or that Studio creates them, without doing so;
- a push that takes a different kind of content from the kind it says it publishes;
- operations under another provider's id;
- an account description with a method it doesn't declare.

spec-acceptance-criterion-6: Given a new provider whose account runs only some of its models, and one of whose connect methods gives a config that can't generate images, when the user connects it with that method, then the model pickers and `/model` offer only the models the account runs, and a chat that asks for an image gets it from another connected provider that offers images, never from this one.

spec-acceptance-criterion-7: Given a new provider with a form method that doesn't check the form's values itself, when the user submits the form in Settings in the Desktop app, `studio ui` and Studio on the web, and through `/connect` in `studio code`, then:
- a value the schema rejects shows the schema's message, and the provider isn't called;
- a field the schema accepts empty can be left empty;
- values the schema accepts reach the provider as the schema parsed them, with the id of a method it declares.

spec-acceptance-criterion-8: Given a new provider whose operations neither check for a missing config nor check the model asked for, when the user chats on it, generates images with it, or opens its sites while it isn't connected, then in each app and in `studio code` the user is told that the provider, by its name, isn't connected, and how to connect it. No surface asks it for a model that isn't on its list.

spec-acceptance-criterion-9: Given a new provider whose model connection states no cost or limits, when a chat runs on one of its models, then the agent runs it with the same cost, context window and output limit as the existing providers' models. Given a provider whose model connection states its own limits, the agent runs the model with those.

spec-acceptance-criterion-10: Given a new provider whose models are the ones a server the user runs lists, added following only the package documentation with no file outside the package changed, when the user connects it to a running server in the Desktop app, `studio ui` and `studio code`, then:
- the model pickers and `/model` offer the models the server lists at that time;
- a chat on one of them gets a reply;
- reopening the conversation keeps its model.

spec-acceptance-criterion-11: Given a new provider with a connect method it says can't complete in a page, when the user opens Settings › Providers, then Studio on the web doesn't offer that method, and the Desktop app and `studio ui` do. GitHub Copilot's and Spacefast's device sign-ins and OpenAI's ChatGPT sign-in stay out of Studio on the web.

spec-acceptance-criterion-12: Given a new provider, when its developer writes its operations and looks up the parts spec-requirement-7 lists, then its operations receive its own config and its own sites, and no other provider's options. Each listed part is either unavailable to it, or the contract says it is WordPress.com's and what it does for any provider. A new provider that uses one gets that behavior in `/connect` and `/disconnect`, in the model pickers and in the publish panel. `/connect` never runs the WordPress.com login, and `/disconnect` never signs out of Studio, for a provider other than WordPress.com.

spec-acceptance-criterion-13: Given the contract in the package, when a developer looks up any value their provider supplies, receives or returns, then the contract states:
- what it means;
- whether a new provider supplies it or acts on it;
- what Studio does with it.

No value the contract asks of a provider goes unread by Studio.

spec-acceptance-criterion-14: Given a new provider whose model connection uses one of the four APIs Studio runs, when the user chats on it in the Desktop app, `studio ui`, `studio code` and Studio on the web, then the reply streams over that API. Given one whose model connection names another API, such as `mistral-conversations`, the developer is told that Studio doesn't run that API, by the repository's checks or as the chat's error, and no request is sent over another API.

spec-acceptance-criterion-15: Given a new provider with code that uses a Node API, code that uses another workspace package, or a part surfaces show that uses its operations, when the developer runs the repository's checks with nothing outside the package changed, then they fail at each such use. Given a new provider that keeps within those boundaries, the same checks pass.

spec-acceptance-criterion-16: Given no provider connected, with a new provider added, when Settings › Providers and each provider's connect forms open in the Desktop app, `studio ui` and Studio on the web, then every provider is shown with its label, logo, description, connect methods and forms, with no request to any provider's service.

spec-acceptance-criterion-17: Given only the package documentation, when a developer who has never worked on Studio adds the providers of spec-acceptance-criterion-1, spec-acceptance-criterion-3 and spec-acceptance-criterion-10, then:
- the documented steps are every change they make, all inside the package;
- the documentation covers each item spec-requirement-11 lists, in agreement with the contract;
- every provider in the package uses only what the documentation describes.

spec-acceptance-criterion-18: Given the seven existing providers, with or without a new provider also connected, when the user does the following with each one in Settings, the chat, the publish panel and `studio code`, then each behaves as before the change: connects with each of its methods, chats, picks models, generates images, publishes, pulls and disconnects. Studio on the web still leaves out device and loopback sign-ins and publishing a static export. WordPress.com stays first where Studio picks the first connected provider. A model id a new provider shares with an existing provider shows the existing provider's label, image support and paid-credit lock.

spec-acceptance-criterion-19: Given `shared.json`, session files and Studio on the web settings written by a build from before the change, with:
- every provider each app offers connected;
- `aiProvider` stored as `anthropic-api-key`;
- a default hosting provider;
- WordPress.com sites and Spacefast Spaces connected to local sites,

when a build from after the change starts, then Settings, `studio code` and the publish panel show:
- the same accounts, with the same summaries;
- the same default providers;
- the same connected sites.

Existing chats keep their provider and model. A build from before the change shows the same after a build from after the change has written its settings.

## Exclusions

spec-exclusion-1: Opening the package to external contributors, such as publishing it for other applications to install or setting up how outside contributions are accepted.

spec-exclusion-2: Loading providers that live outside Studio's source at run time, such as plugins or user configuration.

spec-exclusion-3: Capabilities beyond an account, AI and remote sites, such as previews offered by a provider.

spec-exclusion-4: Studio's agent running model APIs beyond `openai-completions`, `openai-responses`, `anthropic-messages` and `google-generative-ai`.

spec-exclusion-5: Providers bringing their own UI components; surfaces render a provider from what it declares.

spec-exclusion-6: Changing which account is the Studio sign-in, or removing the places where surfaces name WordPress.com or Spacefast today: WordPress.com's settings rows and sync statuses, and Spacefast's connect dialog in Settings.

spec-exclusion-7: Device or loopback sign-ins, or publishing a static export, in Studio on the web, and new kinds of connect methods.

spec-exclusion-8: Shipping a provider Studio doesn't offer today. The xAI and Local LLM providers land in their own changes.

## Considered and not required

- Reading "external developers" as third parties who ship providers outside Studio's source, loaded at run time, or who install the package into their own applications — the Goal says "add a new provider to `@studio/providers`", intent-context-1 speaks of contributors to the package, the package is private (`packages/providers/package.json`), and providers are compiled in (`docs/design-docs/providers.md:148-151`).
- Reading the Goal as documenting the integration outside the package that a new provider needs, rather than removing it — the Goal names adding a provider "to `@studio/providers`", and every recent addition had to change Studio's apps or other packages (`.pipelines/providers-api-for-external-devs-v3/1-spec/spec/provider-additions-stat.txt`, `.pipelines/providers-api-for-external-devs-v3/1-spec/spec/provider-branches-stat.txt`).
- Reading intent-proposal-1 as limited to the two provider types — the proposal says Riad's suggestion is "not the only part to improve", and the shared lists and steps outside those types are part of adding a provider (`git show eb3225c1f`).
- Reporting a contradictory provider only when it runs, or not at all — the README tells developers to copy a provider's folder (`packages/providers/README.md:59`), and the copy keeps that provider's id in its operations and its default model (`packages/providers/anthropic/services.ts:7`, `packages/providers/anthropic/descriptor.ts:100`), which the contract accepts (`.pipelines/providers-api-for-external-devs-v3/1-spec/spec/contract-probe-tsc.txt`).
- Looking up a provider id that isn't registered — surfaces look up only registered ids (`packages/providers/registry.ts:41-57`), and an unknown saved chat provider already falls back to WordPress.com (`packages/common/lib/tests/ai-settings.test.ts:313-320`).
- Keeping today's exported TypeScript signatures for code outside Studio — the Goal and intent-proposal-1 ask to change the API, and intent-context-1 says the package isn't open to outside contributors yet; users' behavior and saved data are what spec-requirement-12 and spec-requirement-13 keep.
- Keeping account-narrowed models and config-dependent image generation to the existing providers only — GitHub Copilot and OpenAI express them through the same contract a new provider writes to (`packages/providers/github-copilot/descriptor.ts:26-34`, `packages/providers/openai/ai.ts:50`).
- A provider that generates images without chat models, or whose account offers neither AI nor remote sites — no provider has either, image generation is found among the AI providers (`apps/cli/ai/auth.ts:132-145`), and Settings list only AI and hosting providers (`apps/ui/src/data/settings-sections.ts:281-333`).
- A generator that writes a new provider's files — no source shows one; the README points developers to "a folder laid out like the others" (`packages/providers/README.md:59`), and spec-requirement-11 makes the documentation enough on its own.
- A new hosting provider that pulls sites back — only WordPress.com pulls, through its own backups and Reprint exporter (`packages/providers/types.ts:259-288`). Spacefast only publishes (`packages/providers/spacefast/descriptor.ts`, `pull: false`).
- A device or loopback sign-in, or a static export publish, that completes in a page — the device endpoints Studio uses reject the page's origin (`docs/design-docs/providers.md:115`), a static export needs the site on native PHP (`apps/ui/src/data/queries/use-remote-sites.ts:24-31`), and no provider shows otherwise.
- A provider operation that works without a config — every existing operation rejects a missing one (`.pipelines/providers-api-for-external-devs-v3/1-spec/spec/repeated-code.txt`).
- A new provider needing an icon bundled in `apps/ui` — Settings fall back to the logo the provider declares (`apps/ui/src/features/settings/settings-view/provider-logo.tsx:5-6`, `apps/ui/src/features/account/provider-logo/index.tsx:12-16`). Meta has none bundled (`git show --stat eb3225c1f`).
- A redesign of Settings or publishing — the intent names none, and Settings already render providers from what they declare (`apps/ui/src/data/settings-sections.ts:300-332`).
