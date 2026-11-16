# Spec: Generic local LLM connection

## Overview

People can connect a locally running LLM service to Studio and use its models for Studio Code conversations through one generic connection experience. Their service and model need not appear in Studio's built-in provider and model lists.

The change connects an existing service to Studio's existing chat workflows. It does not make Studio responsible for installing that service or obtaining its models.

## Requirements

spec-requirement-1: A person can add any locally running LLM provider through a generic connector, supplying the connection information needed to identify their service and a model it serves. Neither the service's brand nor the model's absence from Studio's built-in lists prevents configuration.

origin: from-intent 0-intent/intent.md#goal

observed: The running Providers settings offer only named providers, and the existing OpenAI connection form accepts a key but no service address; see [observations](spec/observations.md), [provider settings](spec/providers.txt), and [OpenAI form](spec/openai-form.txt). Model choices currently come from the built-in lists (`packages/providers/models.ts:9-27`).

assumed: Acceptance criterion 1 will confirm the new configuration and selection outcomes in running Studio.

spec-requirement-2: After choosing the local connection and model, a person can use them for Studio Code conversations. If the selected model requests a Studio Code site action, Studio handles it under its existing tool permissions and supplies its result to that local model for continuation in the same conversation. Studio does not require a hosted AI account, WordPress.com sign-in, or Studio AI credits for local inference. It requires credentials only when the local service requires them. Replies come from the selected local service and model; a failed local request is reported to the person rather than silently answered by a hosted provider.

origin: derived 0-intent/intent.md#goal people using provider-backed chat to build and edit sites in Providers settings and `studio code` (`spec/providers.txt`, `spec/code-help.txt`), with model-requested site actions handled by Studio Code's existing tools (`packages/agent/README.md:75-102`); the locally installed service exposes its model listings without credentials (`spec/local-service.txt`).

observed: Providers settings describe chat as building and editing sites; `studio code --help` describes the same site-building agent. With no connected provider, a running headless chat fails asking for WordPress.com connection (`spec/unconfigured-chat.txt`). The local service is reachable without credentials but currently has no installed models (`spec/local-service.txt`); no successful local-model inference has been observed.

assumed: Acceptance criteria 2-4 will confirm local replies, requested tool continuation, and failure behavior in running Studio.

spec-requirement-3: Studio remembers the saved local connection and provider selection for later use, and retains a conversation's chosen local model when that conversation is resumed. The person can change the connection information or the conversation's chosen model, and can disconnect the local service. Subsequent turns use the changed settings, and a disconnected service is no longer presented as connected.

origin: derived 0-intent/intent.md#goal people reusing and managing saved provider connections and conversation model choices in settings and the CLI (`apps/ui/src/features/settings/settings-view/ai-panel.tsx:77-104,199-245`; `apps/cli/lib/providers.ts:34-67,116-147`; `docs/design-docs/providers.md:14,83-87,93,105-109`).

observed: Existing provider workflows save form values for future use, allow reconnecting with new values, and offer Disconnect in settings and the CLI sources cited above. Conversations record their model choices (`docs/design-docs/providers.md:93`; `apps/static/src/agent/index.ts:432-437`).

assumed: Acceptance criteria 5-7 will confirm remembered choices and connection management for the local connector.

spec-requirement-4: The local connection, selection, chat, and connection-management outcomes are available in the Desktop app, `studio ui`, `studio code`, and Studio on the web when the local service is reachable from that surface. Desktop, `studio ui`, and `studio code` using the same user settings recognize the same saved local connection and provider selection; Studio on the web retains its settings within its own browser environment.

origin: derived 0-intent/intent.md#goal existing provider consumers in Desktop settings, the CLI, the local browser app, and Studio on the web (`apps/studio/src/modules/user-settings/lib/ipc-handlers.ts:151-196`; `apps/cli/lib/providers.ts:34-67`; `apps/local/src/index.ts:765-863`; `apps/static/src/agent/index.ts:219-259,401-480`).

observed: Those consumers already offer provider configuration and selection. The first three share saved provider settings (`docs/design-docs/providers.md:86,105`); the static web app keeps its AI settings in browser storage and runs its agent in the page (`apps/static/README.md:3,33-38,65-67`).

assumed: The acceptance outcomes in the named surfaces will confirm local-connector availability and the existing settings-sharing boundaries.

## Acceptance criteria

spec-acceptance-criterion-1: Given a reachable local LLM service and a model it serves, neither present in Studio's built-in lists, when the person adds them through the generic connector, then the local connection and model are available for selection in Studio's provider and model controls.

spec-acceptance-criterion-2: Given a selected local connection with the service's required credentials supplied, if any, and no hosted provider connected, when the person sends a chat message, then the selected local model's reply appears in that conversation without a hosted-account, sign-in, or AI-credit requirement.

spec-acceptance-criterion-3: Given a selected local model that requests a Studio site action during a conversation, when Studio handles that request, then the action follows the existing tool permissions, its result is available to the same local model, and the continuation appears in the same conversation.

spec-acceptance-criterion-4: Given a selected local connection whose service cannot be reached or rejects the requested model or credentials, when the person sends a message, then Studio reports the local request's failure in that chat and does not substitute a hosted model without the person's selection.

spec-acceptance-criterion-5: Given a saved local connection and provider selection, when the person returns to Studio or opens another Studio surface sharing their user settings, then those choices remain available without re-entering the connection information, and resuming a conversation retains its chosen local model. Studio on the web preserves its choices when returning to the same browser environment.

spec-acceptance-criterion-6: Given a saved local connection and a conversation using it, when the person changes the connection information or that conversation's chosen model, then the conversation's next turn uses the changed settings.

spec-acceptance-criterion-7: Given a connected local service, when the person disconnects it, then Studio no longer presents it as connected or treats it as ready for subsequent local chats.

## Exclusions

spec-exclusion-1: Adding a local provider does not install LLM server software, obtain model weights, or start and stop the external LLM service for the person.

spec-exclusion-2: The local connector does not add image generation, site hosting, publishing, sync, or preview services to the local provider.

spec-exclusion-3: Choosing local inference does not make Studio's remote site operations or other online services work offline, and does not remove browser restrictions on reaching a local service.

## Considered and not required

- Requiring a named local-provider brand or a model shipped in Studio — not the reading taken: the Goal says “any” provider through a generic connector, rather than expanding the built-in brand list.
- Automatically finding servers elsewhere on the computer or network — no observed Studio connection workflow requests a server scan; users explicitly connect a provider (`apps/cli/lib/providers.ts:116-147`; `spec/providers.txt`).
- Keeping several independently selectable saved endpoints under the generic connector at once — no observed consumer requests multiple configurations of one provider; current connection workflows retain one connected method at a time (`docs/design-docs/providers.md:79,87`). Any local provider can be chosen without requiring simultaneous profiles.
- Downloading weights, managing server processes, or supplying a provider plugin written by the user — no observed Studio provider consumer performs these operations; existing consumers connect to services, and user-supplied provider plugins are outside the documented workflows (`apps/cli/lib/providers.ts:116-150`; `docs/design-docs/providers.md:147-150`; `spec/local-service.txt`).
- Local image, hosting, sync, or preview requests — the Goal names LLM connection, while Studio treats those services as independent provider capabilities (`docs/design-docs/providers.md:13,19,116-118,126-138`).
- Making all Studio activity offline or bypassing page-origin/network restrictions — the Goal asks for a local LLM connection, not replacement of remote services; observed web consumers call services from the page and have explicit reachability restrictions (`apps/static/README.md:3,73-77`).
