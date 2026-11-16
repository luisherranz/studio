# Spec: A smaller Studio application

## Overview

The Studio desktop application is about 1 GB installed on every platform it ships to. Its installers and update files are 220–440 MB, and every update downloads the whole application again. The first time Studio is used, it also copies PHP, WordPress and phpMyAdmin into its config folder, which adds about 240 MB.

This change makes the installed application, and every file users download to install or update it, smaller on every platform and architecture Studio ships. It doesn't move the saved bytes into Studio's config folder, and it doesn't take away anything Studio does today: creating and running sites offline, showing its interface in the user's language, the site tools, Studio Code, the terminal `studio` command, and updating from the previous release. Throughout, the baseline is Studio built from the trunk commit the change starts from, for the same platform and architecture and in the same packaging.

## Requirements

spec-requirement-1: On each platform and architecture Studio ships to, the installed Studio application takes fewer bytes on disk than the baseline's. The six pairs are macOS on Apple silicon and Intel, Windows on x64 and ARM64 (both the installer build and the Microsoft Store build), and Linux on x64 and ARM64.

origin: from-intent 0-intent/intent.md Goal

observed: nightly 2.3.0-dev166, unpacked from the update files the updates endpoint served, takes 1,067,584 KiB in 36,990 files on macOS arm64, 1,178,752 KiB on Windows x64 and 1,091,888 KiB on Linux x64. The Linux deb declares an Installed-Size of 985,345 KiB (`spec/nightly-2.3.0-dev166-installed-composition.txt`).

observed: on each of those platforms, nearly all of the size is the bundled CLI (about 496 MB: 225 MB of WordPress, phpMyAdmin and language files, 252 MB of Node packages), the Electron runtime (229–294 MB), the bundled Node (119–148 MB), the bundled PHP (69–98 MB) and the app archive (60 MB). The Windows build also carries a 57 MB `studio-cli.exe` (same file).

observed: the project measures app size as the bytes of the packaged macOS arm64 `Studio.app`, as metric `appSizeMac`, sent to CodeVitals from trunk (`tools/metrics/tests/app-size.test.ts`, `tools/metrics/README.md`).

observed: Studio ships to all six pairs. The 2.2.0 release and nightly 2.3.0-dev166 publish a build for each (`spec/release-2.2.0-download-sizes.txt`, `spec/nightly-2.3.0-dev166-download-sizes.txt`).

spec-requirement-2: Each file Studio offers for download to install or update it is smaller than the same file of the baseline. These are the macOS DMG and update zip (Apple silicon, Intel), the Windows setup program and update package (x64, ARM64), the Microsoft Store package (x64, ARM64), and the Linux deb (x64, ARM64).

origin: derived 0-intent/intent.md Goal. Users download the whole application to install it, and download it whole again on every update. The updates endpoint serves the full Studio.app zip, the full Windows package and the full deb, 362–400 MB per update on macOS and Windows for 2.2.0 (`spec/updates-endpoint-payloads.txt`, `spec/release-2.2.0-download-sizes.txt`).

observed: the 2.2.0 downloads, in bytes:

- DMG: 337,444,773 (arm64), 347,146,186 (x64)
- update zip: 362,018,385 (arm64), 371,967,470 (x64)
- Windows setup program: 388,692,784 (x64), 380,260,144 (arm64)
- Windows update package: 399,122,182 (x64), 390,678,164 (arm64)
- Microsoft Store package: 435,261,980 (x64), 426,982,299 (arm64)
- deb: 231,553,424 (x64), 223,397,436 (arm64)

Source: HEAD requests on the release's Apps CDN links (`spec/release-2.2.0-download-sizes.txt`).

spec-requirement-3: The disk Studio itself occupies on a user's computer, measured once Studio is installed and a site has been created and started, is smaller than the baseline's. This covers the installation plus every file Studio writes into its config folder for its own use (today, its copies of PHP, WordPress and phpMyAdmin). It excludes the user's sites, settings and chats.

origin: derived 0-intent/intent.md Goal. On first use, Studio copies its bundled PHP into its config folder and unpacks WordPress and phpMyAdmin there. Bytes taken out of the installation and written there on first use would leave the user's disk no better off.

observed: after `site create` with the CLI built at HEAD and a fresh config folder, that folder holds `php-bin` 70,040 KiB, `server-files/wordpress-versions/latest` 116,976 KiB and `server-files/phpmyadmin-versions` 53,364 KiB (`spec/head-first-site-config-folder.txt`).

observed: a packaged app copies its bundled PHP into the config folder on first run (read `apps/cli/migrations/06-install-bundled-default-php.ts`).

spec-requirement-4: With no network connection, a user can create a site with the latest WordPress and the PHP version Studio bundles, and start it. The new site gets the WordPress translation of the user's Studio language, and the user can import a WordPress export (WXR) file into it, as with the baseline.

origin: derived 0-intent/intent.md Goal. Studio is built for offline use of these:

- The create-site form forces the latest WordPress while offline, "the only version installable without a download" (read `apps/ui/src/features/sites/create-site-form/index.tsx`).
- The bundled PHP is copied "so first native-PHP startup works offline" (read `apps/cli/migrations/06-install-bundled-default-php.ts`).
- The WordPress importer is bundled "so the import works offline" (read `apps/cli/lib/dependency-management/paths.ts`).
- Language packs for the 20 non-English Studio languages are bundled and added to a new site in the user's Studio language (read `apps/cli/lib/language-packs.ts`, `apps/cli/lib/site-language.ts`, `packages/common/lib/wp-locales.ts`).

spec-requirement-5: On every platform, Studio's interface appears in each of the languages Studio is translated into (Arabic, Central Kurdish, Chinese (Simplified and Traditional), Dutch, French, German, Hebrew, Hungarian, Indonesian, Italian, Japanese, Korean, Polish, Portuguese (Brazil), Russian, Spanish, Swedish, Turkish, Ukrainian, Vietnamese) as with the baseline. This holds whether the language comes from the system language or is chosen under Settings → Language.

origin: derived 0-intent/intent.md Goal. Users run Studio in their own language: Studio picks its language by matching the locale the Electron runtime reports against its translations, and offers a Language setting.

observed: read `apps/studio/src/lib/locale-node.ts`, `packages/common/lib/locale.ts` and `apps/ui/src/features/settings/settings-view/index.tsx`.

observed: each platform's build ships 55 runtime locale files (`spec/nightly-2.3.0-dev166-installed-composition.txt`).

spec-requirement-6: The site features that use what Studio carries work as with the baseline:

- phpMyAdmin for a site
- Xdebug on a site
- `studio wp` commands
- creating a site from a Blueprint
- importing a backup or WXR file
- exporting a site
- a static export and publishing it to Spacefast
- pulling from and pushing to WordPress.com
- preview sites
- custom domains with HTTPS

origin: derived 0-intent/intent.md Goal. The user documentation shows users using each of these (`docs/user/docs/developer-tools/studio/` import-export.md, sync.md, preview-sites.md, xdebug.md, ssl-in-studio.md, cli.md, blueprints/). Their files ship in the application.

observed: the shipped files include phpMyAdmin, WP-CLI, the Blueprints runner, the WordPress importer, Simply Static, Reprint and the SQLite integration (`spec/nightly-2.3.0-dev166-installed-composition.txt`; read `apps/cli/lib/dependency-management/paths.ts`).

spec-requirement-7: Studio Code works as with the baseline: chats on each provider Studio offers (WordPress.com, Anthropic, OpenAI, Gemini, GitHub Copilot) and their models, the agent's tools, and the agent skills Studio installs into sites.

origin: derived 0-intent/intent.md Goal. Studio offers these providers in Settings (read `packages/providers/`). The application carries the agent, the providers' SDKs and the browser automation its tools use (`spec/nightly-2.3.0-dev166-installed-composition.txt`: `@earendil-works`, `openai`, `@anthropic-ai/sdk`, `@google/genai`, `playwright-core` under `cli/node_modules`, skills under `cli/wp-files/skills`).

spec-requirement-8: The `studio` command that the Settings switch "WordPress Studio CLI for terminal" installs runs from the user's terminal on every platform, including the Microsoft Store build. `studio ui` and `studio mcp` run from it, as with the baseline.

origin: derived 0-intent/intent.md Goal. "WordPress Studio CLI comes bundled with WordPress Studio" (`docs/user/docs/developer-tools/studio/cli.md`), and Settings installs it (read `apps/ui/src/features/settings/settings-view/studio-cli-section.tsx`, `apps/studio/src/modules/cli/lib/*-installation-manager.ts`). The Microsoft Store build runs it through `studio-cli.exe` (read `apps/studio/forge.config.ts`, `scripts/package-appx.mjs`).

spec-requirement-9: An installation of the previous release updates to the change's release the way its platform updates today. On macOS and the Windows installer build, that is the in-app updater. On Linux, it is installing the new deb the update notice points to. The Microsoft Store build updates through the Store. After the update, the user's existing sites, settings and chats keep working.

origin: derived 0-intent/intent.md Goal. Every user of the previous release receives the change as an update.

observed: read `apps/studio/src/updates.ts` (in-app updater on macOS and Windows, deb notice on Linux, Store builds skip the updater). The updates endpoint serves those payloads (`spec/updates-endpoint-payloads.txt`).

## Acceptance criteria

spec-acceptance-criterion-1: Given the change's build and the baseline build for any of the six platform and architecture pairs, when each is installed, then the change's installed application takes fewer bytes on disk, measured as the size of the installed application.

spec-acceptance-criterion-2: Given each install and update file of the change's build and the matching file of the baseline (DMG, update zip, Windows setup program, Windows update package, Microsoft Store package, deb, for each architecture), when their sizes are compared, then each of the change's files is smaller.

spec-acceptance-criterion-3: Given a fresh installation of the change's build and of the baseline on the same platform, when a site is created and started in each, then the change's installation plus the files Studio wrote into its config folder for its own use take fewer bytes on disk than the baseline's.

spec-acceptance-criterion-4: Given a fresh installation of the change's build on a computer with no network connection and Studio's language set to one of its translations, when the user creates a site and starts it, then the site runs, and its WP Admin shows the latest WordPress on the bundled PHP version in that language.

spec-acceptance-criterion-5: Given a site created by the change's build and no network connection, when the user imports a WXR file into it, then the file's posts appear in the site.

spec-acceptance-criterion-6: Given the system language, or Settings → Language, set to one of Studio's translations on any platform, when Studio opens, then its interface shows in that language.

spec-acceptance-criterion-7: Given a site in the change's build, when the user uses any feature that spec-requirement-6 lists, then that feature produces the same result in Studio and in the site as with the baseline.

spec-acceptance-criterion-8: Given the change's build connected to any provider Studio offers, when the user chats with Studio Code about a site and asks for work that uses its tools and skills, then the agent replies and its tools run as with the baseline.

spec-acceptance-criterion-9: Given the change's build on any platform, including the Microsoft Store build, with "WordPress Studio CLI for terminal" turned on in Settings, when the user runs `studio` commands, `studio ui` and `studio mcp` in a terminal, then each runs as with the baseline.

spec-acceptance-criterion-10: Given an installation of the previous release with sites, settings and chats, when it updates to the change's release through its platform's update path, then the updated Studio opens and shows the same sites, settings and chats, and its sites start.

## Exclusions

spec-exclusion-1: The size of the standalone Studio CLI bundle, the `wp-studio` npm package, Studio on the web, and the agent plugins Studio publishes is not required to change.

spec-exclusion-2: Studio's memory and CPU use while it runs is not required to change.

spec-exclusion-3: The number of files in the installation, and the time an update takes to install, are not required to change.

spec-exclusion-4: The size of the user's sites, backups and exports, and of what Studio downloads on demand today (other WordPress versions, other PHP versions, and the browser Studio Code downloads), is not required to change.

## Considered and not required

- Reading "size" as the number of files: the Goal says size. File count affects how long a macOS update takes to install, and trunk 0599ae89e already shipped a cut to it (observed: commit message and PR #5988).
- Reading "size" as memory use while running: the project measures app size as bytes on disk (observed: `tools/metrics/tests/app-size.test.ts`).
- Reading "size" as only the installed size, or only the download size: users pay both. They download the whole application on every update, and keep about 1 GB installed (observed: spec-requirement-1 and spec-requirement-2 evidence).
- Reading the Goal as met by a smaller build on one platform, such as the macOS arm64 build the app-size metric tracks: users on each of the six pairs get their own build (observed: release download list).
- A numeric size target: the intent sets none, so any decrease below the baseline on every pair meets it.
- Opening phpMyAdmin, making a static export, or applying a Blueprint with no network connection: no source shows offline use of these. They work offline today only because their files ship (observed: searching `apps/ui/src`, `apps/cli`, `apps/studio/src` and `packages/common` for "offline" finds bundled files kept for offline use only for site creation, first start and WXR import).
- Creating a site offline with a WordPress version other than the latest, or a PHP version other than the bundled one: these download today. The create-site form disables the WordPress version choice offline, and other PHP versions download on demand (observed: `apps/ui/src/features/sites/create-site-form/index.tsx`, `apps/cli/lib/dependency-management/php-binary.ts`).
- Platforms and package formats Studio doesn't ship, such as Windows ia32, Linux armhf, rpm or AppImage: Studio publishes none of them (observed: `spec/release-2.2.0-download-sizes.txt`, `fastlane/Fastfile` build list).

## Open assumptions

spec-assumption-1: The baseline's installed application is about 150 MB smaller than nightly 2.3.0-dev166's, because trunk 0599ae89e ships WordPress, phpMyAdmin and the language files zipped. At HEAD, the CLI ships 66,252 KiB of those files without language packs, against 224,524 KiB in dev166 (`spec/head-first-site-config-folder.txt`, `spec/nightly-2.3.0-dev166-installed-composition.txt`). — assumed: packaging the baseline for each pair and measuring it.

spec-assumption-2: Every installation and download can be made smaller than the baseline's on all six pairs while spec-requirement-3 through spec-requirement-9 hold. — assumed: measuring the change's builds against the baseline's, and running the features those requirements list on them.
