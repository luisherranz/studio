---
status: open
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
