---
status: approved
opener: reviewer-astra
recipient: implementer
about: implementation
---

## reviewer-astra — eb8e753636efe8d05028e54369936099c5740da5

Approved from code review: I found no blocking correctness or scope issues against `d6f7bdc7e4e2f79b3129cb6bb6f9558f467ac697`.

The changes remove build-only files, preserve Studio's locale matching, and retain atomic installation of bundled PHP. Moving the Windows launcher into AppX staging is appropriately scoped to the only distribution that needs it.

I independently built the macOS ARM64 package. Its PHP payload is 18,496,796 bytes compressed versus 71,528,738 bytes of archive entries. Running the locale hook against Electron 44.9.1's actual Linux x64 locale files reduced their logical size from 8,988,721 to 3,618,590 bytes, with every symlink resolving. These are component measurements, not a before/after total installer benchmark; adding that benchmark to the PR would be useful but is not blocking.

### Checks

- **lint — passed:** ran ESLint without `--fix` on every added/modified JavaScript and TypeScript file since `924a8266928b68b570395ead0afd880b6c2ea4be`, including untracked files. No errors; only the multiple-project configuration warning.
- **typecheck — passed:** `npm run typecheck`.
- **tests — passed:** `npm test --` for the bundled-PHP migration, Forge config and locale tests (19 tests), followed by the migration directory and PHP dependency-management path/binary tests (28 tests, including the repeated bundled-PHP tests). Vitest excludes the Playwright files, so I also ran `npx playwright test apps/studio/e2e/package-composition.test.ts apps/studio/e2e/localization.test.ts --workers=1 --retries=0` against the fresh package: eight passed, the Windows-only test skipped. This exercised site creation, Japanese site language, Arabic RTL and restart persistence, German system language, Finnish-to-English fallback, and package composition. `npm run package` and `npm run cli:build` also succeeded.
- **knip — passed:** `npm run knip`, with no findings.
- **light-and-dark — passed:** launched the packaged desktop app with system languages `(fi,de)` and no saved locale. Inspected the Add site dialog in both emulated schemes: labels remained English and readable against their respective light/dark surfaces; Chromium's required-field message was English in both. No CSS or layout changes are introduced.
- **agent-evals — not applicable:** no agent prompt, tool contract, skill or instruction changes.
- **agents-md — passed:** checked the affected packaging, localization, CLI migration and native-PHP conventions and release/native-PHP documentation. No config-locking or runtime dependency-boundary regression found. Added comments explain non-obvious packaging behavior.
- **scope — passed:** the changes serve application-size reduction and its regression coverage; no unrelated refactor found.

### Remaining platform coverage

This machine has no Developer ID Application signing identity, so the package build skipped PHP signing. I have not verified signed/notarized distribution, Windows signing, the installed AppX `studio.exe` alias, or Windows/Linux application launches. Those remain release-CI/platform smoke-test responsibilities, not claims of this review. In particular, exercise first-run PHP from the signed distribution and the relocated AppX alias before release.

All launched test applications were cleaned up; the isolated CLI reports no running sites.
