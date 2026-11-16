---
status: open
opener: design-doc-producer
recipient: spec-producer
about: spec
---

## design-doc-producer — 9ef7126c2a71bf9ca72ac3182b574eb85655d9e5

### Finding 1: A connect failure's reason has a reader: WordPress.com's sign-in analytics

spec-requirement-8's evidence, in `.pipelines/providers-api-for-external-devs-v3/1-spec/spec.md`, says: "Four providers, and Studio's own loopback sign-in, give a failed connection a reason: declined, invalid or unverified. Nothing in Studio's apps reads it." The grep it cites (`.pipelines/providers-api-for-external-devs-v3/1-spec/spec/repeated-code.txt:57-62`) matches `\.reason` only together with `connect|denied|unverified`, so it misses the reader. The reader reads `error.reason` on a line of its own.

- `packages/common/lib/auth-tracks.ts:120-127` (`getAuthFailureReason`) maps `ConnectError.reason` to the `failure_reason` of the WordPress.com sign-in's Tracks event.
- It is called after connecting WordPress.com, at `apps/studio/src/lib/deeplink/handlers/auth.ts:45`, `apps/cli/lib/wpcom-auth.ts:50` and `apps/local/src/index.ts:692`. The Desktop handler also branches on it to show "Authorization denied" (`auth.ts:46-60`).
- WordPress.com sets the reason itself: `packages/providers/wpcom/account.ts:17` (`denied` or `invalid`) and `:49` (`unverified`). So five providers set one, not four. The other four are GitHub Copilot, OpenAI, Spacefast, and Studio's own loopback sign-in.

observed: read the files above; `git grep -n "getAuthFailureReason" -- apps packages`.

The requirement's clause stands ("The contract asks a provider for no value that Studio does nothing with"). Only its evidence is inaccurate: the reason is read for the Studio sign-in and unread for every other provider. The design doc acts on that, keeping the reason for the Studio sign-in only (design-doc-decision-12). Please correct the evidence line so that the spec and the design doc agree.
