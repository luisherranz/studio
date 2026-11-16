---
status: approved
opener: reviewer-opus
recipient: implementer
about: implementation
---

## reviewer-opus — eb8e753636efe8d05028e54369936099c5740da5

**Approve.** Every part of this change makes Studio smaller without changing what it does:

- the CLI's `node_modules` drop source maps and type declarations;
- the app archive drops those and Sentry's build tools;
- locale packs for languages Studio shows in English carry the English pack;
- PHP ships as one brotli archive;
- the Store-only CLI launcher leaves the Squirrel installer;
- the DMG uses LZMA.

Each part is small and tested. The two riskiest parts, locale packs and PHP signing, deliberately keep today's behavior. Nothing below blocks merging.

### What I checked beyond the diff

- **Locale packs, on the real Electron 44.9.1 layout.** I ran the `afterExtract` hook on the cached `electron-v44.9.1-darwin-arm64.zip`. It linked 112 of the 220 `*.lproj/locale.pak` files to the matching `en*.lproj` pack, gendered variants included, and every link resolves. The packs went from 49 MB to 20 MB. The kept set is English plus every locale `matchSupportedLocale` maps to a translation (Catalan→es, Afrikaans→nl, Malay→id, pt-PT→pt-br…). Packager and `electron-installer-debian` (`fs-extra` copy) keep symlinks.
- **PHP archive, round trip with the real `8.4.27-studio-1` package.** 68 MB becomes an 18.5 MB `.tar.br`; gzip -6 would give 26.3 MB. The unpacked `php` is byte-identical, runs, and loads `ext/xdebug.so`. Unpacking takes about 250 ms, so first launch won't notice it. Compressing at quality 11 took about 125 s on this Mac; quality 9 takes 16 s for 21.9 MB. That's fine for release builds, but expect about 2 extra minutes per platform/arch build.
- **PHP signing parity.** CDN binaries are ad-hoc signed. Until now, osx-sign re-signed the bundled copy with the app: Developer ID, hardened runtime, `default.darwin.plist`. On Windows, `@electron/windows-sign` signed its PE files through the Azure hook. `signPhpPackage` does the same:
  - `php.plist` is identical to osx-sign 2.7.1's `default.darwin.plist`;
  - identity discovery matches osx-sign's (`find-identity -v`, first `Developer ID Application:`);
  - Windows calls the same hook.

  `xdebug.so` gets signed by the same team, so library validation under the hardened runtime still lets PHP load it.
- **Excluded Sentry build tools.** `@sentry/node` 11.7.0 depends on `@sentry/bundler-plugins`, but reaches it only from its `./vite`, `./rollup`, `./webpack` and `./esbuild` subpath exports; its main entry never imports it.
- **CLI copy filter.** `vite-plugin-static-copy` 4.1.1 expands the source with tinyglobby (`onlyFiles`, `expandDirectories`, `dot`). On a fixture, the negated pattern dropped `.map`, `.d.ts`, `.d.mts` and `.d.cts` files, including ones in dot folders, and kept everything else. No CLI dependency reads `.d.ts` at runtime: the only hits in pi-coding-agent are jiti's extension list and embedded `package.json` strings. `vite.config.standalone.ts` merges the prod config, so the curl-installed bundle gets the filter too.
- **Forge still loads its config.** `forge.config.ts` now pulls in `@studio/common/lib/locale`, and with it every translation JSON. Loaded through `@electron-forge/core` 8.0.1's own jiti, the way `forge-config.js` loads it, the config resolves. The hooks are all there.
- **Store launcher.** Nothing in the Squirrel or deb installs refers to `studio-cli.exe`; `windows-installation-manager.ts` uses `studio-cli.bat`. electron2appx copies the packaged app to `pre-appx/app` before `finalSay`. The new `out/studio-cli-<arch>.exe` is git-ignored and outside the Buildkite artifact globs.

**Not run here:** `npm run package` and the new e2e tests. The machine has 13 GB free, and packaging in isolation copies the repo and reinstalls its dependencies. `package-composition.test.ts` and the two new localization tests only run against a packaged build. Three paths only run on a signed CI build: macOS PHP signing, notarization with links inside the framework, and the AppX alias. Before merging, please check that these pass:

- the Desktop e2e jobs on all three platforms;
- one signed macOS build and one signed Windows build. On the Mac, after first launch, `codesign -dv ~/.studio/php-bin/<id>/php` should show the Developer ID team and `flags=0x10000(runtime)`.

### Notes (non-blocking)

1. **Visible change for languages Studio doesn't translate.** On a Finnish system, Chromium's own strings (validation bubbles, `<input type=file>`, media controls) used to be in Finnish next to Studio's English UI; now they are English too. I think that's more consistent, and the e2e test pins it. Say so in the PR description so nobody takes it for a regression.
2. **`useEnglishLocalePacks` does nothing, silently, if the macOS layout moves.** When the `Electron Framework.framework/Versions/A/Resources` glob finds nothing, `resources` is `undefined`, so the second `globSync` runs in the cwd and matches nothing. The e2e test would catch it later. Throwing there would fail the build at the cause instead.
3. **Local `npm run make` DMGs stay zlib.** `format: 'ULMO'` is only in `scripts/make-dmg.mjs`, which CI uses (`SKIP_DMG` + `make:dmg-*`). The forge `MakerDMG` doesn't set `format`, so local DMGs are bigger than release ones. It's harmless; align it or leave it.
4. **`php.plist`** gives PHP camera, microphone, location, photos, USB and Bluetooth, because it mirrors osx-sign's defaults. Keeping parity is the right call for this PR; PHP itself only needs `allow-jit`, if anyone wants to narrow it later.
5. **On Windows the packs are copies.** The saving there is only the size difference between each pack and `en-US.pak`, and the nupkg and AppX compress each copy separately. Fine as is, but the Windows saving will be smaller than on macOS.

### Rules

- **lint**: `npx eslint`, without `--fix`, on the 12 JS/TS files changed since `924a826`: no errors.
- **typecheck**: `npm run typecheck` passes.
- **tests**: `npm test -- apps/cli/migrations/tests/06-install-bundled-default-php.test.ts apps/studio/src/tests/forge-config.test.ts apps/studio/src/lib`: 26 files, 255 tests pass. They include the new truncated-archive case and the macOS, Linux and Windows locale-pack cases. I didn't run the e2e files (see above).
- **knip**: `npm run knip` reports nothing.
- **light-and-dark**: not applicable: no `apps/ui` UI or CSS changes.
- **agent-evals**: not applicable: no system prompt, tool or skill changes.
- **agents-md**: followed.
  - `tar` was already a CLI dependency, with the same range as at the root.
  - `@yao-pkg/pkg` stays a root dev dependency.
  - Comments give reasons (why every locale keeps a pack, why PHP is signed before compressing) rather than narrating the change.
  - The native PHP design doc describes the archive.
- **scope**: everything serves the size goal.
  - `match-supported-locale.ts` lets the forge config and the e2e test share the runtime match without importing Electron.
  - Pulling `signWithAzure` out was needed to sign the launcher.
  - The removed `.gitignore` line is for a file nothing generates any more.
  - The two localization e2e tests guard the riskiest part, and are worth their two extra app launches.
