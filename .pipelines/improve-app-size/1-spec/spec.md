# Spec: A smaller Studio application

## Overview

The Studio desktop application takes 0.8–1.2 GB on disk once installed on each platform it ships to. Its installers and update files are 220–440 MB, and every update downloads the whole application again. On first use, Studio also writes its own copies of PHP, WordPress and phpMyAdmin into its config folder, which adds about 240 MB.

This change makes the installed application, and each file users download to install or update it, smaller on every platform and architecture Studio ships. The saved bytes don't move into Studio's config folder. Studio keeps everything it does today and needs no new installation step. That covers creating and running sites offline, showing its interface in the user's language, the site tools, Studio Code, the terminal `studio` command, and updating from the previous release. Throughout, the baseline is Studio built from the commit this change starts from, for the same platform and architecture and in the same packaging.

## Requirements

spec-requirement-1: On each platform and architecture Studio ships to, the installed Studio application takes less space on disk than the baseline's. The six pairs are macOS on Apple silicon and Intel, Windows on x64 and ARM64 (both the installer build and the Microsoft Store build), and Linux on x64 and ARM64.

origin: from-intent 0-intent/intent.md Goal

observed: the baseline packaged for macOS on Apple silicon measures 845,641,998 bytes on the project's app-size metric (`spec/baseline-macos-arm64-package.log`, `spec/baseline-macos-arm64-observation.log`).

observed: the project measures app size as the bytes of the packaged macOS Apple silicon `Studio.app`, as metric `appSizeMac` (read `tools/metrics/tests/app-size.test.ts`, `tools/metrics/README.md`).

observed: in nightly 2.3.0-dev166, unpacked from the update files the updates endpoint served, the installation takes 1,067,584 KiB on macOS arm64, 1,178,752 KiB on Windows x64 and 1,091,888 KiB on Linux x64. Nearly all of it is in five parts:

- the bundled CLI, about 496 MB: WordPress, phpMyAdmin and language files, plus Node packages
- the Electron runtime, 229–294 MB
- the bundled Node, 119–148 MB
- the bundled PHP, 69–98 MB
- the app archive, 60 MB

The Windows build also carries a 57 MB `studio-cli.exe`. That nightly predates trunk commit 0599ae89e, which the baseline includes and which ships WordPress, phpMyAdmin and the language files zipped (`spec/nightly-2.3.0-dev166-installed-composition.txt`).

observed: Studio ships to all six pairs. The 2.2.0 release publishes a build for each (`spec/release-2.2.0-download-sizes.txt`), and the user documentation offers the Microsoft Store build (read `docs/user/docs/developer-tools/studio/index.md`).

spec-requirement-2: Each file Studio offers for download to install or update it is smaller than the same file of the baseline. These are the macOS DMG and update zip (Apple silicon, Intel), the Windows setup program and update package (x64, ARM64), the Microsoft Store package (x64, ARM64), and the Linux deb (x64, ARM64).

origin: derived 0-intent/intent.md Goal. Users download the whole application to install it, and download it whole again on every update. Studio's updates endpoint serves the full macOS app zip, the full Windows update package and the full deb (`spec/updates-endpoint-payloads.txt`; read `apps/studio/src/updates.ts`).

observed: the 2.2.0 downloads, in bytes:

- DMG: 337,444,773 (arm64), 347,146,186 (x64)
- update zip: 362,018,385 (arm64), 371,967,470 (x64)
- Windows setup program: 388,692,784 (x64), 380,260,144 (arm64)
- Windows update package: 399,122,182 (x64), 390,678,164 (arm64)
- Microsoft Store package: 435,261,980 (x64), 426,982,299 (arm64)
- deb: 231,553,424 (x64), 223,397,436 (arm64)

Source: HEAD requests on the release's download links (`spec/release-2.2.0-download-sizes.txt`).

observed: the baseline's macOS Apple silicon update zip, built unsigned, is 351,685,241 bytes (`spec/baseline-macos-arm64-observation.log`).

spec-requirement-3: The disk space Studio itself takes on a user's computer is smaller than the baseline's, measured once Studio is installed and a site has been created and started. This counts the installation plus every file Studio writes into its config folder for its own use. It leaves out the user's sites, settings and chats.

origin: derived 0-intent/intent.md Goal. On first run and on creating the first site, which every user does, Studio writes its copies of PHP, WordPress and phpMyAdmin into its config folder. Bytes taken out of the installation and written there would leave the user's disk no better off.

observed: after `site create` with the CLI built at the baseline commit and a fresh config folder, that folder holds `php-bin` at 70,040 KiB, `server-files/wordpress-versions/latest` at 116,976 KiB and `server-files/phpmyadmin-versions` at 53,364 KiB (`spec/head-first-site-config-folder.txt`).

observed: a packaged Studio copies its bundled PHP into the config folder on first run (read `apps/cli/migrations/06-install-bundled-default-php.ts`).

spec-requirement-4: Installing Studio remains the only step before using it. Everything spec-requirement-5 through spec-requirement-10 list works on a computer that meets the platform's documented requirements, without the user installing PHP, Node.js or any other software.

origin: derived 0-intent/intent.md Goal. Users install only Studio: the installation instructions list operating-system requirements and no separate PHP or Node.js (read `README.md`, `docs/user/docs/developer-tools/studio/index.md`).

observed: the baseline packaged for macOS on Apple silicon runs its bundled `studio` command on the application's own Node (read `apps/studio/bin/studio-cli.sh`). That command creates a WordPress site and serves it with the bundled PHP (`spec/baseline-macos-arm64-observation.log`).

spec-requirement-5: With no network connection, a user can create a site with the latest WordPress and the PHP version Studio bundles, start it, and import a WordPress export (WXR) file into it, as with the baseline. When Studio's language is one of the following, the new site is in that language: Arabic, Chinese (Simplified or Traditional), Dutch, French, German, Hebrew, Hungarian, Indonesian, Italian, Japanese, Korean, Polish, Portuguese (Brazil), Russian, Spanish, Swedish, Turkish, Ukrainian or Vietnamese.

origin: derived 0-intent/intent.md Goal. Studio is built for offline use of these:

- The create-site form keeps the latest WordPress while offline, "the only version installable without a download" (read `apps/ui/src/features/sites/create-site-form/index.tsx`).
- The bundled PHP is copied "so first native-PHP startup works offline" (read `apps/cli/migrations/06-install-bundled-default-php.ts`).
- The WordPress importer is bundled "so the import works offline" (read `apps/cli/lib/dependency-management/paths.ts`, `apps/cli/lib/import-export/import/importers/wxr-importer.ts`).
- A new site with the latest WordPress takes its language from Studio's language, matched against a bundled list of translations, and gets that language's bundled WordPress translation (read `apps/cli/commands/site/create.ts`, `apps/cli/lib/site-language.ts`, `apps/cli/lib/language-packs.ts`, `packages/common/lib/wp-locales.ts`).

spec-requirement-6: On every platform, Studio's interface appears in each language Studio is translated into, as with the baseline. These are Arabic, Central Kurdish, Chinese (Simplified and Traditional), Dutch, French, German, Hebrew, Hungarian, Indonesian, Italian, Japanese, Korean, Polish, Portuguese (Brazil), Russian, Spanish, Swedish, Turkish, Ukrainian and Vietnamese. This holds whether the language comes from the system language or is chosen under Settings → Language.

origin: derived 0-intent/intent.md Goal. Users run Studio in their own language: Studio picks its language by matching the locale the Electron runtime reports against its translations, and offers a Language setting (read `apps/studio/src/lib/locale-node.ts`, `packages/common/translations/`, `apps/ui/src/features/settings/settings-view/index.tsx`).

observed: each platform's build ships 55 runtime locale files (`spec/nightly-2.3.0-dev166-installed-composition.txt`).

spec-requirement-7: The site features that use what Studio carries work as with the baseline:

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

origin: derived 0-intent/intent.md Goal. The user documentation shows users using each of these: `import-export.md`, `sync.md`, `preview-sites.md`, `xdebug.md`, `ssl-in-studio.md`, `cli.md` and `blueprints/`, under `docs/user/docs/developer-tools/studio/`.

observed: the shipped files include phpMyAdmin, WP-CLI, the Blueprints runner, the WordPress importer, Simply Static, Reprint and the SQLite integration (`spec/nightly-2.3.0-dev166-installed-composition.txt`; read `apps/cli/lib/dependency-management/paths.ts`).

spec-requirement-8: Studio Code works as with the baseline. That covers chats on each AI provider Studio offers (WordPress.com, Anthropic, OpenAI, Gemini, GitHub Copilot) with their models, the agent's tools, and the agent skills Studio installs into sites.

origin: derived 0-intent/intent.md Goal. Studio offers these providers in Settings (read `packages/providers/`). The application carries the agent, the providers' SDKs and the browser automation its tools use: `@earendil-works`, `openai`, `@anthropic-ai/sdk`, `@google/genai` and `playwright-core` under `cli/node_modules`, and skills under `cli/wp-files/skills` (`spec/nightly-2.3.0-dev166-installed-composition.txt`).

spec-requirement-9: Users can run the `studio` command from their terminal, with `studio ui` and `studio mcp`, as with the baseline. On the macOS, Windows installer and Linux builds, that is the command Settings → "WordPress Studio CLI for terminal" installs. On the Microsoft Store build, it is the `studio` command the Store installation provides.

origin: derived 0-intent/intent.md Goal. "WordPress Studio CLI comes bundled with WordPress Studio" (`docs/user/docs/developer-tools/studio/cli.md`).

observed: on the installer builds, Settings installs the command (read `apps/ui/src/features/settings/settings-view/studio-cli-section.tsx`, `apps/studio/src/modules/cli/lib/*-installation-manager.ts`).

observed: the Microsoft Store build doesn't offer that setting (`docs/user/docs/developer-tools/studio/cli.md`). Its package declares `studio.exe` as a command alias for the bundled `studio-cli.exe` launcher (read `scripts/package-appx.mjs`, `apps/studio/forge.config.ts`).

spec-requirement-10: An installation of the previous release updates to the change's release the way its platform updates today. On macOS and the Windows installer build, that is the in-app updater. On Linux, it is installing the new deb that the update notice points to. The Microsoft Store build updates through the Store. After the update, the user's existing sites, settings and chats keep working.

origin: derived 0-intent/intent.md Goal. Every user of the previous release receives the change as an update.

observed: read `apps/studio/src/updates.ts`: the in-app updater runs on macOS and Windows, Linux gets a deb notice, and Store builds skip the updater. The updates endpoint serves those payloads (`spec/updates-endpoint-payloads.txt`).

## Acceptance criteria

spec-acceptance-criterion-1: Given the change's build and the baseline build for any of the six platform and architecture pairs, when each is installed, then the change's installed application takes less space on disk.

spec-acceptance-criterion-2: Given each install and update file of the change's build and the matching file of the baseline, when their sizes are compared, then each of the change's files is smaller. The files are the DMG, update zip, Windows setup program, Windows update package, Microsoft Store package and deb, for each architecture.

spec-acceptance-criterion-3: Given a fresh installation of the change's build and of the baseline on the same platform, when a site is created and started in each, then the change's installation plus the files Studio wrote into its config folder for its own use take less space on disk than the baseline's.

spec-acceptance-criterion-4: Given the change's build installed on a computer that meets its platform's documented requirements and has no PHP or Node.js installed, when the user uses what spec-requirement-5 through spec-requirement-10 list, then each works without the user installing anything else.

spec-acceptance-criterion-5: Given a fresh installation of the change's build, no network connection, and Studio's language set to one that spec-requirement-5 names, when the user creates a site and starts it, then the site runs. Its WP Admin shows the latest WordPress, on the bundled PHP version, in that language.

spec-acceptance-criterion-6: Given a site created by the change's build and no network connection, when the user imports a WXR file into it, then the file's posts appear in the site.

spec-acceptance-criterion-7: Given the system language, or Settings → Language, set to one of Studio's translations on any platform, when Studio opens, then its interface shows in that language.

spec-acceptance-criterion-8: Given a site in the change's build, when the user uses any feature that spec-requirement-7 lists, then that feature produces the same result in Studio and in the site as with the baseline.

spec-acceptance-criterion-9: Given the change's build connected to any provider Studio offers, when the user chats with Studio Code about a site and asks for work that uses its tools and skills, then the agent replies and its tools run as with the baseline.

spec-acceptance-criterion-10: Given the change's build on any platform, with "WordPress Studio CLI for terminal" turned on in Settings, or on the Microsoft Store build as installed, when the user runs `studio` commands, `studio ui` and `studio mcp` in a terminal, then each runs as with the baseline.

spec-acceptance-criterion-11: Given an installation of the previous release with sites, settings and chats, when it updates to the change's release through its platform's update path, then the updated Studio opens. It shows the same sites, settings and chats, and its sites start.

## Exclusions

spec-exclusion-1: The size of the Studio CLI installed on its own (with the standalone installer or as the `wp-studio` npm package), of Studio on the web, and of the agent plugins Studio publishes is not required to change.

spec-exclusion-2: Studio's memory use, CPU use and startup time are not required to change.

spec-exclusion-3: The number of files in the installation, and the time an update takes to install, are not required to change.

spec-exclusion-4: The size of the user's sites, backups and exports is not required to change. Neither is the size of what Studio downloads on demand today: other WordPress versions, other PHP versions, the import engines `studio create --from` fetches, and the browser Studio Code's tools install when it's missing.

spec-exclusion-5: No size target is set beyond the baseline: any decrease below it, on each pair and each file, meets spec-requirement-1 through spec-requirement-3.

## Considered and not required

- Reading "size" as the number of files, or as memory use while running: the project measures app size as bytes on disk (observed: `tools/metrics/tests/app-size.test.ts`).
- Reading the Goal as the installed size alone, with download sizes not required: users download the whole application on every update, so they pay its download size as well (observed: `spec/updates-endpoint-payloads.txt`, `apps/studio/src/updates.ts`).
- Reading the Goal as the installation alone, leaving out the files Studio writes into its config folder: first use writes about 240 MB of Studio's own copies there (observed: `spec/head-first-site-config-folder.txt`).
- Meeting the Goal with a smaller build on one platform, such as the macOS Apple silicon build the app-size metric tracks: users on each of the six pairs get their own build (observed: `spec/release-2.2.0-download-sizes.txt`).
- Requiring the same bytes or percentage saved on every platform, architecture or package: the Goal asks for a smaller application, not equal savings.
- Opening phpMyAdmin, making a static export, or applying a Blueprint with no network connection: no source shows offline use of these. They work offline today only because their files ship (observed: searching `apps/ui/src`, `apps/cli`, `apps/studio/src` and `packages/common` for "offline" finds bundled files kept for offline use only for site creation, first start and WXR import).
- Creating a site offline with a WordPress version other than the latest, or a PHP version other than the bundled one: these download today. The create-site form disables the WordPress version choice offline, and other PHP versions download on demand (observed: `apps/ui/src/features/sites/create-site-form/index.tsx`, `apps/cli/lib/dependency-management/php-binary.ts`).
- A new site in Central Kurdish with no network connection: Studio bundles no WordPress translation for it (observed: `packages/common/lib/wp-locales.ts`).
- Platforms and package formats Studio doesn't ship, such as Windows ia32, Linux armhf, rpm or AppImage: Studio publishes none of them (observed: `spec/release-2.2.0-download-sizes.txt`, `fastlane/Fastfile` build list).

## Open assumptions

spec-assumption-1: Every installation and download can be made smaller than the baseline's on all six pairs while spec-requirement-3 through spec-requirement-10 hold. — assumed: measuring the change's builds against the baseline's, and running the features those requirements list on them.
