---
status: done
---

# Implementation notes

## Done

- One ordered registration in `packages/providers/registry.ts`; every id list and provider type (`ProviderId`, `AiProviderId`, `SitesProviderId`, `ProviderConfigs`, `ProviderSites`, `ProviderSite`, `AiModelId`) derives from it. `defineProvider`, `defineServices`, `ServicesOf`, `ConfigOf`/`ModelIdOf`/`SiteOf` and `AI_APIS` in `types.ts`; the six providers moved to the helpers; the services entry finds each folder's `services` export with `import.meta.glob( './*/services.ts' )`. Package tests for the registration (`tests/providers.test.ts`) and type tests (`tests/contract.test.ts`). Commits 9ad5bb89e, 3118d2394 (glob visible to Vitest's module cache), 43953c1e4 (type tests that hold whatever else is registered).
- Lint rule `studio/provider-registration` (`tools/eslint-plugin-studio`), enabled for `registry.ts`, `*/descriptor.ts` and `*/services.ts`. Commit e309db1a9.
- The providers surface boundary matches folders with one brace glob. Commit 56662916b.
- Default config and connection stores in `@studio/common` (`lib/provider-config.ts`, `lib/remote-sites.ts`). Commit bf7afb859.
- Tests outside the package build accounts from `PROVIDER_IDS` (07dd29c70), and the publish tab test answers only for Spacefast (e48bb38ba).
- The agent streams exactly `AI_APIS`; any other API ends the turn with an error naming it, before a request. Commit ae241b84c.
- `apps/ui` publishes only to WordPress.com where `nativeSites` is false. Commit edeaca9a0.
- Hosting operations renew an expiring credential before listing, creating or pushing. Commit 69ef06883.
- README and `docs/design-docs/providers.md` (87e9f9414); contract and error docs for what a new provider handles (093f86fd5).

### Proofs run

- Contract type errors name the part, kind, model and API: `notes/contract-type-errors.txt`.
- A subagent wrote `sample-chat` (API key form, `openai-completions`) and `sample-hosting` (device sign-in, WordPress archive, create) from the README and `types.ts` only; I added `sample-both` (loopback + form, AI + static sites, narrowed models, images, renewing token). All in `notes/sample-providers.patch`, not committed. With them registered: typecheck, ESLint on the changed files, knip and `npm test` pass (`notes/sample-providers-checks.txt`; the full suite found the publish-tab test fixed in e48bb38ba).
- Lint on a sample part-way through (unregistered, no `services.ts`, wrong export): `notes/lint-rule-part-way.txt`. Boundary violations in a sample folder: `notes/lint-boundary-sample.txt`.
- `studio code` (`notes/studio-code-runs.txt`): first-run connect offers Sample Chat and asks for its key; a reply streams from a local Ollama over `openai-completions`; after a restart it is still connected (`Sample Qwen · Sample Chat`); `/model` lists its model; `/provider` lists it; `/disconnect sample-chat` removes it; `/connect` lists every provider and connects Sample Hosting by device code and Sample Both by loopback with a choice of methods; `/model` on Sample Both offers only the narrowed `Both Small`; a connection cast to `mistral-conversations` shows "Studio doesn’t run the mistral-conversations API, which sample-qwen connects over."
- `studio push --remote-site sample-hosting:site-1` uploaded a 13 MB archive (456 entries) to the fake host and recorded the connection under `sample-hosting` in `remoteSites`.
- `studio ui` (`notes/screenshots/`, light and dark): Sample Chat under AI providers and Sample Hosting under Hosting providers with the generic mark; connect by key; Default AI and hosting selects; device code shown in the row; model picker; chat reply; still connected after reload; publish panel lists the CLI-published site, creates `site-2` and pushes to it; Sample Both connected once by loopback shows under both groups, its sites in the publish panel, a static push of 55 files; its token renewed before a chat; after the host revoked it the chat shows the sign-in error and Settings show it disconnected.
- Images through the CLI host's `resolveImageGenerator`: Sample Both generates for its own chats and as the fallback for a chat on Sample Chat (fake host logged both prompts).
- Studio on the web (`dev:static`): Sample Chat and Sample Both under AI providers with forms only, Hosting providers only WordPress.com, connect by key in the page, still connected after reload, Default AI select lists it, Publish goes straight to WordPress.com.
- Storage round trip with the base build (`notes/storage-round-trip/`): identical reads both ways.
- Desktop main bundle (electron-vite) contains every folder's services, the samples included: `notes/desktop-main-bundle.txt`.

## Remaining

None.

## Decisions

- `defineProvider` infers the connect methods, model ids, site type and `sites.pull`/`sites.newSite` as their own type parameters rather than intersecting the whole argument: an intersection collapses a mistyped literal (a wrong `defaultModel`, a `redirect` kind) to `never`, and the message names nothing. `sites.pull` and `sites.newSite` are primitive-constrained parameters so their literals survive inference.
- The `redirect` rejection brands the kind (`'redirect' & { 'redirect is the Studio sign-in, which only WordPress.com declares': never }`), so the error lands on `kind` and names it.
- A provider annotates its site type in `sites.describe`'s parameter; `defineProvider` infers the site type from there.
- Each folder's services module exports `services`; parts typed separately use `ServicesOf< typeof xProvider >[ 'account' | 'ai' | 'sites' ]`.
- `services.ts` calls `import.meta.glob(` without a type argument: Vitest's file-system module cache skips only modules containing that literal, and a cached transform kept a stale folder list.
- The lint rule parses `registry.ts` with the parser ESLint lints with (`context.languageOptions.parser`); its tests use espree with JS-only fixtures.
- Hosting operations (`listAccountSites`, `createRemoteSite`, `studio push`) read the config through `readFreshProviderConfig`, so a provider with sites and a renewing credential is renewed before use (spec-requirement-2), as chats were. No existing hosting provider renews, so their behavior is unchanged.
- No agent-facing behavior changed (system prompt, tools, result shapes, skills), so no eval case applies.

## Failed approaches

- `defineProvider( descriptor: Descriptor & ProviderDescriptor<…> )`: with a detailed `Descriptor` constraint, inference fell back to the constraint and excess-property checks fired on every method; with a minimal one, literal conflicts collapsed parts to `never`.
- Driving the TUI with characters one at a time: arrow keys must be written as whole escape sequences.

## Assumptions

- design-doc-assumption-1: observed: `notes/desktop-main-bundle.txt` (electron-vite main build includes every folder's services). The Desktop app itself was not launched: no Desktop resource is provided, and its UI and shared operations ran in `studio ui`.
- design-doc-assumption-2: observed: `notes/contract-type-errors.txt`.
- design-doc-assumption-3: observed: `npm run typecheck` passes with `/// <reference types="vite/client" />` in `packages/providers/services.ts`.
- design-doc-assumption-4: observed: `studio code` shows the error naming the API (`notes/studio-code-runs.txt`, run 9); the browser agent's `createStreamFn` with the sample connection cast to `mistral-conversations` ended without a request (throwaway test, removed). The in-page chat on Studio on the web was not observed: a Playground site never started in the browser session, so turns waited on it.
- design-doc-assumption-5: observed: `npm run typecheck` passes with the registration as the only source of the id unions, type maps and `AiModelId`.
- design-doc-assumption-6: observed: `notes/lint-rule-part-way.txt`.
- ESLint on all 56 changed files needs `NODE_OPTIONS=--max-old-space-size=12288`; with the default heap typed linting runs out of memory. It then reports nothing.
- The `e2e`-tagged CLI tests failed when run together alongside the running servers; `apps/cli/commands/site/tests/create.e2e.test.ts` passes alone. They exercise site commands this change doesn't touch.
