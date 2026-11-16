# Readers of the provider contract outside `packages/providers`, at 5af8033b1

Produced with `git grep` over tracked files, excluding `packages/providers`, `*.test.ts`, `*.test.tsx` and `**/tests/**`:

```sh
git grep -nE '<pattern>' -- apps packages ':(exclude)packages/providers' ':(exclude)*.test.ts' ':(exclude)*.test.tsx' ':(exclude)**/tests/**'
```

Spot-checked by rerunning the commands for `learnMoreUrl`, `ConnectError.reason` and the list options (`connectedIds`, `planRequired`); the results matched.

## Values no reader outside the package reads

- `Provider.learnMoreUrl`: `git grep -nE 'learnMoreUrl'` finds only `sites.intro.learnMoreUrl`: `apps/ui/src/features/sync/publish-panel/connect-account.tsx:29`, `connected-view.tsx:191`, `publish-panel/index.tsx:485`.
- `sites.list` options (`connectedIds`, `planRequired`): written only for WordPress.com: `packages/common/sites/remote-sites.ts:34`, `apps/static/src/wpcom-services.ts:262`, `apps/cli/lib/sync-api.ts:58-61` (WordPress.com's own list). The other `connectedIds` hits are local variables (`apps/ui/src/data/queries/use-remote-sites.ts:114`, `packages/agent/node/sessions/manage.ts:185`).
- `sites.push` options (`optionsToSync`, `specificSelectionPaths`, `launchAfterPush`): written at `apps/cli/commands/push.ts:304` for every provider and `apps/static/src/wpcom-services.ts:421-425` for WordPress.com; read only by WordPress.com's push.
- `ConnectContext` (`redirectUri`, `hostId`, `remembered`): written by Studio (`packages/common/lib/provider-connect.ts:77-78`, `packages/common/lib/provider-config.ts:199-216`), read by providers (`packages/providers/openai/account.ts:73-108`).

## Values read only for WordPress.com

- `ConnectError.reason`: `packages/common/lib/auth-tracks.ts:121-127` (`getAuthFailureReason`), called only for the WordPress.com sign-in: `apps/studio/src/lib/deeplink/handlers/auth.ts:45`, `apps/cli/lib/wpcom-auth.ts:50`, `apps/local/src/index.ts:692`.
- `ai.paidDefaultModel`: read through `getDefaultAiModel` (`packages/providers/models.ts:55`) with `canUsePaidModels` from `apps/cli/commands/ai/index.ts:140-141`, `packages/agent/protocol/sessions/model.ts:68`, `apps/static/src/agent/index.ts:432-434`, `apps/ui/src/features/chats/session-view/index.tsx:158-162`, `apps/ui/src/features/sites/add-site-dialog/use-setup-prompt.tsx:78-80`.
- `AiModel.requiresPaidAiCredits`: `apps/cli/ai/slash-commands.ts:404`, `apps/ui/src/features/composer/use-model-access.ts:41`.
- `sites.pull.*`: `apps/cli/lib/sync-api.ts:72,99,117`, `apps/cli/lib/pull/pull-source.ts:106`, `apps/cli/lib/pull/reprint-key.ts:27`, `packages/common/sites/remote-sites.ts:66,81`, `apps/static/src/wpcom-services.ts:463,482,493`.
- `sites.hasBackups`: `apps/ui/src/features/sync/publish-panel/use-transfer-selection.ts:76`.
- push result `launchError`: `apps/cli/commands/push.ts:121-122,325-326,350-351`, `apps/static/src/wpcom-services.ts:439,448`.

## Values read for every provider

- `icon`, `logo`: `apps/ui/src/features/account/provider-logo/index.tsx:12-15`.
- `account.expiresAt`: `packages/common/lib/provider-config.ts:156`, `apps/static/src/agent/index.ts:246`.
- `account.remember`: `packages/common/lib/provider-config.ts:174-177,232`.
- `ConnectMethod.instructions`: `apps/cli/lib/providers.ts:139-141`, `apps/ui/src/features/settings/settings-view/ai-panel.tsx:54,195`.
- `AccountDetails.method`: `ai-panel.tsx:50`; `summary`: `ai-panel.tsx:214`; `note`, `links`: `apps/ui/src/features/composer/model-picker.tsx:80,85-86,151,154`; `models`: through `getAiModels` (`model-picker.tsx:91`, `apps/cli/ai/slash-commands.ts:399-401`).
- `AiModel.supportsImages`: `apps/ui/src/features/composer/composer.tsx:389`.
- `PendingConnect.url`, `code`, `handoff`: `apps/ui/src/data/queries/use-ai-settings.ts:79,82`, `apps/cli/lib/providers.ts:74-92`, `ai-panel.tsx:148,152`, `publish-panel/connect-account.tsx:37,42`, `spacefast-connect-dialog.tsx:54-55,110`.
- `AiConnection.piProvider`: `packages/agent/node/runtime/index.ts:318`; `apiKey`: `packages/agent/browser/models.ts:22`, `runtime/index.ts:337,340`; `headers`: `runtime/index.ts:342`; `model`: `runtime/index.ts:337-347`; `requestModelId`: `packages/agent/shared/models.ts:17,36-40`; `rewriteError`: `packages/agent/shared/models.ts:46`, `runtime-guards/error-rewrite.ts:19`.
- `GenerateImageResult.ok`, `bytes`, `error`, `filtered`: `packages/agent/shared/tools/generate-images.ts:202-216`.
- `PushStatus.phase`, `progress`: `apps/cli/commands/push.ts:155-170,191,306-318`, `apps/static/src/wpcom-services.ts:426-431`, `apps/ui/src/data/sync-activity.ts:55-62`, `packages/common/types/sync.ts:14-21`.
- `ProviderSitesInfo` `maxPushSize`, `pull`, `selective`, `content`, `newSite`, `intro`, `describe`, `issue`, `pushWarning`, `withDetails`: `apps/cli/commands/push.ts:204,231,254,486,568-575`, `apps/ui/src/features/sync/publish-panel/index.tsx:102,113,167,205,222,332,459,479-485`, `connected-view.tsx:121-125,166,185,191,205,250,276,301`, `connected-website.tsx:49`, `use-transfer-selection.ts:65,76,99,131-142`, `apps/ui/src/data/queries/use-remote-sites.ts:29`, `apps/ui/src/data/settings-sections.ts:331`, `apps/ui/src/features/sync/publish-tab.tsx:253`, `apps/cli/ai/host.ts:69`, `packages/agent/shared/tools/pull-site.ts:30`, `list-connected-remote-sites.ts:22-35`, `packages/common/lib/sync/constants.ts:4`.
- `account.refresh`: `packages/common/lib/provider-config.ts:254-262`; `account.disconnect`: `packages/common/lib/ai-settings.ts:110`, `apps/static/src/wpcom-auth.ts:92`; `ai.canGenerateImages`: `apps/cli/ai/auth.ts:124`, `apps/static/src/agent/index.ts:455`; `sites.create`: `packages/common/sites/remote-sites.ts:46-51`, `apps/cli/commands/push.ts:501,515`.
- `RemoteSiteError.code`: `apps/cli/lib/sync-api.ts:39-40`, then as `LoggerError.code` at `apps/cli/lib/utils.ts:14-16` and `apps/cli/lib/pull/pull-selection.ts:197`.

- `apps/static/src/wpcom-services.ts:273` calls `withWpcomDetails` from `@studio/providers/wpcom` directly; it is the function WordPress.com's presentation assigns to `withDetails` (read `packages/providers/wpcom.ts:7`, `packages/providers/wpcom/descriptor.ts:99`).
- The `missing_backup` code `apps/cli/lib/pull/pull-selection.ts:197` reads comes from WordPress.com's `latestBackupId` (`packages/providers/wpcom/sites/index.ts:264`).
