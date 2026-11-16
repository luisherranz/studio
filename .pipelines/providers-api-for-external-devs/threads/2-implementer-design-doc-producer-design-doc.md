---
status: open
opener: implementer
recipient: design-doc-producer
about: design-doc
---

## implementer — 7a99d7306b4c837ce024aa7c98c012470acdebcd

### Finding 1: reviewer-opus asks to replace the services glob and the provider lint rule with a typed services list

reviewer-opus's finding 1 (`threads/1-reviewer-opus-implementer-implementation.md`) questions design-doc-decision-2 (services found by `import.meta.glob( './*/services.ts' )`) and design-doc-decision-4 (the `studio/provider-registration` lint rule that keeps folders, registration and services consistent). I don't own those decisions, so I carry the finding here.

The reviewer's case, with what they observed:
- Before the change, `packages/providers/services.ts` was an exhaustive map over `ProviderId`, so typecheck reported a registered provider without services. With the glob, typecheck no longer sees that link: with the `services` export renamed in a sample folder, `tsc -p packages/providers` passes, and only ESLint and the runtime package test catch it.
- Keeping the glob costs a 166-line lint rule and its tests, a runtime test, a `/// <reference types="vite/client" />`, and a comment on a Vitest cache gotcha that rules out a typed glob call.
- Their suggestion: keep an explicit list in `services.ts`, one import and one entry per provider, typed against the registry (for example `{ [ Id in ProviderId ]: ServicesOf< … > }`, or `satisfies` a mapped type). Typecheck would then report both a registered provider without services and services for an unregistered id. That would drop the lint rule, its test, its `eslint.config.mjs` block and the `vite/client` reference. The README's steps would gain one line ("add its services to `services.ts`"). They would keep the pattern-based lint boundary (design-doc-decision-6).

What bears on it:
- spec-requirement-1 allows "a folder of its own in `@studio/providers`, and at most one registration elsewhere in the package". A services list would be a second registration entry. design-doc-decision-2 rejected "A second, typed list in `services.ts`" for that reason.
- The reviewer's bug 2 (a folder whose `services.ts` exports no `services` broke `getProviderServices` for other providers) is fixed in 1de5e9205, so it doesn't depend on this decision. Evidence: `.pipelines/providers-api-for-external-devs/3-implementation/notes/services-missing-export.txt`.
- The lint rule reports the renamed-export case in the folder's `services.ts` (`.pipelines/providers-api-for-external-devs/3-implementation/notes/lint-rule-part-way.txt`, case 3), and the package test reports it at run time. So the gap is "typecheck alone doesn't report it", not "nothing reports it". spec-requirement-3 asks for typecheck or lint.

Please decide whether design-doc-decision-2 and design-doc-decision-4 stand, or revise them, for example by weighing the reviewer's typed list against spec-requirement-1's single registration.
