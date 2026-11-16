---
status: resolved
opener: implementer
recipient: design-doc-producer
about: design-doc
---

## implementer — 00644cf46261f8719c6d0ef239b5f844131a655d

### Finding 1: On macOS, a removed Electron Framework locale pack empties Chromium's strings instead of falling back to `en-US`

design-doc-decision-4 says that for a removed locale "Chromium falls back to `en-US`", and its trade-off says Chromium's own strings "follow `en-US`". design-doc-assumption-1 says that on macOS, with the framework pack removed and the app bundle's own `.lproj` kept, `app.getLocale()` returns `en-US`. Both are in `2-design-doc/design-doc.md`.

I tested this on the baseline macOS arm64 package (`apps/studio/out/Studio-darwin-arm64/Studio.app`, built from the baseline commit) with `app.asar` replaced by a probe app. The probe prints `app.getLocale()` and a Chromium-localized string: the validation message of an empty required `<input>`. The system language comes from `-AppleLanguages`. Evidence: `3-implementation/notes/mac-locale-probe.txt`, script `3-implementation/notes/scripts/mac-locale-probe.sh`.

- **The decision as written:** system language `fi`, the framework's `fi*.lproj` removed, the app bundle's `Contents/Resources/fi.lproj` kept. `app.getLocale()` is `fi`, not `en-US`, and the validation message is `""`. The baseline gives `fi` and `"Täytä tämä kenttä."`. Studio's own language doesn't change, because the matcher maps `fi` to English either way. But Chromium's built-in strings are empty, not English, for every user whose macOS language is one of the 30 removed locales.
- **Also removing the app bundle's `fi.lproj`:** `app.getLocale()` is `en-US` and the message is English. With system languages `(fi, de)` it becomes `de`, so Studio would show German where the baseline shows English. This is the alternative the decision rejects.
- **Replacing the framework's `fi*.lproj/locale.pak` with a symlink to `../en.lproj/locale.pak`:** `app.getLocale()` stays `fi` for `(fi)` and for `(fi, de)`, as in the baseline, so Studio's language is unchanged. Chromium's strings are English (`"Please fill out this field."`). Each symlink is a few bytes.

This bears on spec-requirement-6 and spec-acceptance-criterion-7, and on the Verification test that "Studio picks the same language from the system language as the baseline". On macOS, the kept-or-removed contract under Interfaces ("a pack is present exactly when…") doesn't yield the outcome the decision states.

### Finding 2: On Linux, a removed pack moves Chromium to the user's next listed language, which can change Studio's language from the baseline's

The decision states that a removed locale "mapped to English anyway". I tested Electron 44.9.1 linux-arm64 in a `node:24-bookworm` container with the same probe (`3-implementation/notes/linux-locale-probe.txt`, script `3-implementation/notes/scripts/linux-locale-probe.sh`):

- `LANG=fi_FI.UTF-8`, `LANGUAGE` unset, `fi.pak` removed: `en-US` with English strings, as the decision states.
- `LANG=fi_FI.UTF-8`, `LANGUAGE=fi:de`, `fi.pak` removed: `app.getLocale()` is `de` and the strings are German. The baseline gives `fi`. `getSupportedLocale` maps `de` to German, so Studio would show German where the baseline shows English. Chromium tries each language in `LANGUAGE` in order and takes the first that has a pack.
- `fi.pak` replaced by a symlink to `en-US.pak`: `fi` for both `LANGUAGE` values, as in the baseline, with English strings.

I couldn't observe Windows from this machine. Squirrel's nupkg and the Store's appx can't carry symlinks.

The decision-4 locale filtering is not built yet, so the rest of the change doesn't depend on how this is resolved. Which treatment of a removed locale should the packaging apply on each platform?

## design-doc-producer — bd346affbe72eccdcf557245385a87e83a6eb5eb

### Finding 1: changed in bd346affb

I reproduced it with your probe on the macOS arm64 package (Electron 44.9.1): `2-design-doc/design-doc/locale-pack-probes.txt`.

| Packs | `app.getLocale()` | Validation message |
|---|---|---|
| Framework's `fi*.lproj` removed | `fi` | `""` |
| Framework's `fi*.lproj` removed, `Contents/Resources/fi.lproj` too, system `(fi, de)` | `de` | — |
| Framework's `fi*.lproj` linked to `en.lproj/locale.pak`, system `(fi)` or `(fi, de)` | `fi` | `"Please fill out this field."` |

I also checked Danish. Removing `da` empties the strings. Linking it keeps `da` with English strings, both for `(da)` and for `(da, es)`. design-doc-assumption-1 is false, so I removed it.

design-doc-decision-4 no longer removes packs. All 55 locales keep a pack at the baseline's path:

- A locale that Studio's matcher maps to a translation, and English itself, keeps its own pack.
- Each of the other 28 locales carries the English pack's content. On macOS that includes the gendered variants.

Chromium's choice of app locale, `app.getLocale()`, Studio's language and the renderer's default locale stay as in the baseline, and Chromium's own strings are English for those 28. On macOS and Linux the pack is a symbolic link to the English pack, so the 30.1 MB macOS saving stands. Interfaces, Verification and Risks now say this. The new system-language end-to-end test also proves that Chromium's strings are never empty. A new inspection proves that a signed and notarized macOS build with the links verifies and passes Gatekeeper. design-doc-assumption-5 covers signing and installs until that runs.

### Finding 2: changed in bd346affb

I reproduced it with your Linux probe in `node:24-bookworm`. With `LANG=fi_FI.UTF-8 LANGUAGE=fi:de` and `fi.pak` removed, `app.getLocale()` is `de`. With `fi.pak` linked to `en-US.pak` it is `fi`, with English strings (`2-design-doc/design-doc/locale-pack-probes.txt`).

### Which treatment the packaging applies on each platform: changed in bd346affb

The same treatment on every platform: each locale Studio maps to English carries the English pack's content in place of its own.

- **macOS and Linux:** the pack is a symbolic link to the English pack: `en.lproj/locale.pak` on macOS, `en-US.pak` on Linux. Both formats carry links:
  - The macOS update zip holds the bundle's 14 links.
  - The deb's staging copy (fs-extra 9.1.0 `copy`, called by electron-installer-common `copyApplication`) recreates links with their original targets.
  
  Evidence: `2-design-doc/design-doc/locale-pack-aliases.txt`.
- **Windows:** the pack is a copy of `en-US.pak`, because the setup program, update package and Store package can't carry links. Measured on Electron 44.9.1 win32-x64: the 28 packs are 30,280,090 bytes, and 28 copies of `en-US.pak` (586,582 bytes each) take 16,424,296. That still saves 13,855,794 bytes installed and 1,435,149 with deflate. Keeping every pack on Windows would save nothing and leave Windows with different Chromium strings from the other platforms.

Windows itself isn't observed. The copies keep all 55 pack files present, as in the baseline, so Chromium keeps its choice if it chooses from the files present. That's design-doc-assumption-4, which the new system-language end-to-end test on Windows confirms.

## implementer — 16b35c9c89cd165245d2451c7affeaa79fca8e21

Resolved by the revised design-doc-decision-4 in bd346affb, which keeps a pack for every locale and gives the locales Studio maps to English the English pack. I'm building it as revised. Each macOS gendered variant links to the matching English variant: all 165 gendered packs are the same 18-byte empty pack, so their content doesn't change.
