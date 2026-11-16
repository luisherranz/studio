# Current-behavior observations

Observed source revision: `9db401ba3753f3b961bd610f0bf180d05e8734a1`.

The observations below describe the existing software, not an implementation of the requested connector. No solution code was written. Retained command output has absolute worktree paths removed and line endings and trailing whitespace normalized where needed.

## Running Studio

- Built this worktree with `npm run cli:build:ui`; both the UI and CLI builds completed. Output: [build.log](build.log).
- Started the built `studio ui --no-open --port 49391` with both `DEV_CONFIG_DIR` and `STUDIO_PROCESS_MANAGER_HOME` pointing into an isolated, temporary runtime folder under this supporting folder. No owner's Studio configuration was used. Startup output: [server.log](server.log).
- Opened `http://localhost:49391`, unchecked the anonymous-usage checkbox in the welcome dialog, and declined sign-in. No WordPress site was created.
- The empty workspace's sidebar controls did not remain reliably clickable during this observation. Used the supported settings search route, `http://localhost:49391/sites?settings=providers`, identified from `apps/ui/src/router/layout-root/index.tsx:104-117`, to open Providers settings.
- Read the running Providers settings. AI choices were WordPress.com, OpenAI, Anthropic, Google Gemini, and GitHub Copilot, with no local/custom connection control. Saved semantic browser output: [providers.txt](providers.txt).
- Opened OpenAI's Connect menu and selected API key. The form asked only for an OpenAI API key; it offered no server address or model input. No key was entered or submitted. Saved output: [openai-form.txt](openai-form.txt).
- Read `studio code --help` from the newly built CLI. It identifies Studio Code as the site's AI agent and documents interactive and headless conversations. Output: [code-help.txt](code-help.txt).
- Ran `studio code --json 'Say hello'` with the same isolated configuration and no connected account. It exited with status 1, emitted WordPress.com connection errors, and completed the turn as an error. Output: [unconfigured-chat.txt](unconfigured-chat.txt). This shows the unconfigured default path, not that every existing provider requires WordPress.com.

The settings observations agree with the fixed provider list in `packages/providers/registry.ts:17-48` and fixed model lists in `packages/providers/models.ts:9-27`. They establish the absence of a user-facing local-provider path in the observed app. They do not establish that Studio's underlying libraries cannot speak to a local service.

## Local service input

The installed Ollama client exposes a local server at its documented default `127.0.0.1:11434`. `ollama list`, and unauthenticated GET requests to `/api/tags` and `/v1/models`, returned no installed models. The two HTTP requests returned status 200. Commands and output, with line endings and trailing whitespace normalized: [local-service.txt](local-service.txt).

No local models were downloaded or selected, and no local inference request was made. These observations establish an actual local service with no credential needed for model listing; they do not establish successful inference, agent tool compatibility, compatibility with all local providers, or browser-origin access to that service.

## Scope evidence

The source observations used in the spec are existing consumers, not implementation prescriptions:

- Provider values are saved for future use, reconnected, and disconnected through existing user workflows: `apps/cli/lib/providers.ts:34-67,116-147`, `apps/ui/src/features/settings/settings-view/ai-panel.tsx:77-104,199-245`.
- Provider and model selection drive the existing site-building agent, whose tools act on sites when requested by the model: `docs/design-docs/providers.md:97-109`, `packages/agent/README.md:75-102`. The spec's tool-continuation outcome applies when a model returns such a request; it does not assume every locally served model can produce one.
- Desktop, CLI, and the local browser app consume the shared provider settings; the static web app has its own browser-backed configuration and runs the agent in the page: `docs/design-docs/providers.md:86,105,140-144`, `apps/static/README.md:3,33-38,65-67`.
- Provider capabilities other than conversational models are independent: `docs/design-docs/providers.md:13,19,116-138`.

The intent has only its Goal; there are no later constraint, proposal, or failure files in `0-intent/`. No provider brands, API dialects, latency targets, model-discovery method, or simultaneous local-connection profiles are specified there.

## Cleanup

The dedicated browser session was deleted and the observed UI process was stopped. No listener remained on its port.

`site stop --all` initially failed with `EINVAL` while addressing the daemon through a 162-byte socket path under the supporting folder. Repeating it against the same daemon directory through a temporary 90-byte path alias within the worktree succeeded: “No sites are currently running.” Output, with the absolute worktree path removed: [cleanup.log](cleanup.log). The alias and runtime data were removed after cleanup. No other local LLM process was stopped.
