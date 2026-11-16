# Spec: Reduce the installed Studio application size

## Overview

Reduce the size of the Studio desktop application users install, without removing its existing capabilities or adding installation prerequisites. Success is a positive reduction in the total bytes of installed application files and resources, not merely a smaller source checkout, download archive, or runtime memory measurement.

## Requirements

spec-requirement-1: The total byte size of the complete installed Studio desktop application's files and resources must be smaller than that of an equivalent pre-change production application for the same operating system and processor architecture.

origin: derived .pipelines/improve-app-size/0-intent/intent.md#goal the desktop application users download for their computer and install, as documented in README.md:11–17 and docs/user/docs/developer-tools/studio/index.md:23–31.

observed: The documented macOS installation copies the application into Applications. The existing application-size consumer measures the complete macOS Apple Silicon application bundle, rather than its download archive (`tools/metrics/tests/app-size.test.ts:8–17` and `tools/metrics/utils.ts:17–31`).

observed: The unchanged application source packages successfully for macOS Apple Silicon with `npm run make:macos-arm64`; the command and completed package output are recorded in `.pipelines/improve-app-size/1-spec/lanes/omits/spec/package-baseline.log`.

observed: The packaged baseline's existing application-size metric reports 845,641,998 bytes. Its ZIP download is 351,685,241 bytes; these are distinct measurements. Commands and results are recorded in `.pipelines/improve-app-size/1-spec/lanes/omits/spec/baseline-observation.log:1–24`.

spec-requirement-2: Users must retain Studio's existing documented desktop capabilities and supported desktop targets without new prerequisite installation steps. The smaller application must remain usable without users separately installing PHP or Node.js, including when using the CLI supplied with the desktop application.

origin: derived .pipelines/improve-app-size/0-intent/intent.md#goal users installing the desktop application and using local WordPress development, AI, previews, publishing, and the app-provided CLI, documented in README.md:19–55, docs/user/docs/developer-tools/studio/index.md:15–71, and docs/user/docs/developer-tools/studio/cli.md:3–26.

observed: README.md:15–17 offers macOS Intel and Apple Silicon, Windows x64 and ARM64, and Debian Linux x64 and ARM64 downloads. The desktop installation instructions list operating-system requirements but no separate PHP or Node.js installation. README.md:23 describes local WordPress development with a bundled PHP runtime; the desktop CLI launcher uses the application's supplied Node.js runtime (`apps/studio/bin/studio-cli.sh:3–14`).

observed: The packaged baseline's CLI displays its documented commands and creates a local WordPress site without manual PHP or Node.js setup. That site serves the default WordPress post with HTTP 200. The isolated observation and successful shutdown are recorded in `.pipelines/improve-app-size/1-spec/lanes/omits/spec/baseline-observation.log:26–92`; other documented desktop capabilities were not exercised in this observation.

## Acceptance criteria

spec-acceptance-criterion-1: Given equivalent pre-change and changed production applications for the same supported desktop operating system and processor architecture, when the total byte sizes of their complete installed application files and resources are compared, then the changed application has a lower byte total.

spec-acceptance-criterion-2: Given a user on an existing documented desktop target meeting its existing installation prerequisites, when they use the changed application, then its documented desktop capabilities, including the app-provided CLI, remain usable without additional prerequisite installation steps.

## Exclusions

spec-exclusion-1: No particular absolute application-size ceiling or percentage saving is promised beyond the positive reduction required above.

spec-exclusion-2: No independent reduction in the separately distributed CLI, Studio web deployment, or installer/archive download sizes is promised.

spec-exclusion-3: No reduction in users' WordPress site files, databases, out-of-installation caches, runtime memory, or startup times is promised.

## Considered and not required

- Treating a smaller download archive with unchanged installed application size as sufficient — not taken: the Goal names the application, the documented user installs that application, and the existing size consumer measures its complete installed bundle.
- Requiring identical byte or percentage savings across all operating systems, processor architectures, and installer formats — not taken: the Goal supplies no such quota; the selected outcome compares equivalent applications while retaining existing desktop target support.
- Treating the Goal as independent size or performance targets for other distributions or user-created data — not taken: the Goal names the Studio application; the CLI has a separate installation path (`docs/user/docs/developer-tools/studio/cli.md:3–5`), and site files and configuration remain outside the app when it is uninstalled (`docs/user/docs/developer-tools/studio/cli.md:44–48`).
