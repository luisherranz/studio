# Probe: adding a provider today

A throwaway provider, `example` (an API-key form and one model over `openai-completions`), added on
the turn's base commit and reverted afterwards. `sample-provider.patch` is its final state (step 3).

1. The folder (`example/config.ts`, `descriptor.ts`, `services.ts`) and the README's first step, its
   id in `ProviderId` and `ProviderConfigs`: `1-readme-steps-providers-typecheck.txt`.
2. The README's "register it in registry.ts and services.ts", plus what typecheck then asked for
   (`STORED_PROVIDER_IDS`, the `AiModelId` union in `models.ts`), but not the id lists typecheck
   never asked for: package typecheck `2-registered-providers-typecheck.txt`, what the registry
   reports `2-registered-lists.json`, ESLint `2-registered-eslint.txt`, typecheck of the other
   workspaces `2-registered-repo-typecheck.txt`.
3. Its id added to `AiProviderId` and `AI_PROVIDER_IDS`, and a store in
   `packages/common/lib/provider-config.ts`: `3-listed-lists.json`, and the tests of the providers,
   `@studio/common`'s AI settings, the agent's protocol, Desktop's user settings, the CLI's AI, and
   `apps/ui`'s settings and model picker: `3-listed-tests.txt`.
