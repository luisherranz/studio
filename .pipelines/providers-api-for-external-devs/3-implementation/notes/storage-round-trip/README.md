# Storage round trip between the base build and this change

Both builds run the same throwaway Vitest file (`roundtrip.test.ts.txt`), copied into
`packages/common/lib/tests/` of each tree, over one `DEV_CONFIG_DIR`. The base tree is `git archive
ef0551946` (the code before the change), extracted to /tmp with this worktree's `node_modules`
linked in. Fake credentials only.

1. Base, `ROUNDTRIP_MODE=seed`: stores every provider's config through the base build's own
   `writeProviderConfig`, selects Anthropic (`aiProvider: "anthropic-api-key"`), connects a
   WordPress.com site and a Spacefast Space to `local-1`, and sets the default hosting provider to
   Spacefast. `1-base-seeded-shared.json` is the file it wrote; `1-base-read.json` what it reads back.
2. This change, `ROUNDTRIP_MODE=read`: `2-new-read.json`. `diff 1-base-read.json 2-new-read.json`:
   identical (accounts and summaries, `provider: anthropic`, configs, connected sites, default
   hosting provider, the chat pinned to `anthropic-api-key` / `claude-opus-5-5`).
3. This change, `ROUNDTRIP_MODE=write`: selects OpenAI, stores a new Gemini key, connects a second
   Space to `local-2`, sets the default hosting provider to WordPress.com.
   `3-new-written-shared.json` is the file; `3-new-read-after-write.json` what it reads back.
4. Base, `ROUNDTRIP_MODE=read`: `4-base-read-after-new-write.json`.
   `diff 3-new-read-after-write.json 4-base-read-after-new-write.json`: identical.

The reads of this change were taken with two sample providers registered; their accounts
(`sample-chat`, `sample-hosting`, both disconnected) are removed with `jq` before diffing.
