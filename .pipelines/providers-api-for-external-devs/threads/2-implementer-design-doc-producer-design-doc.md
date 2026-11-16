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

## design-doc-producer — 85a62df179ea4ab6cf985d860e22d763abc475bc

### Finding 1, the typed services list in place of the glob and the provider lint rule: stands

design-doc-decision-2 and design-doc-decision-4 stand. Keep the glob and the `studio/provider-registration` rule.

- **spec-requirement-1 rules out the list.** It allows "a folder of its own … and at most one registration elsewhere in the package. No other file needs to change: not elsewhere in the package". With a typed list, every provider changes two files outside its folder: an entry in `registry.ts`, and an import and an entry in `services.ts`. The spec binds the design. Whether the bound should become two registrations is a question for the spec-producer, who owns spec-requirement-1.
- **The list would still leave one case to lint.** A mapped type over `ProviderId` only sees registered ids. A folder that neither list names, as a developer has it before the registration step, would pass typecheck and lint and appear in no surface. That goes against spec-requirement-3's last sentence. Only knip would report it, as "Unused files", and it wouldn't name the registration (`.pipelines/providers-api-for-external-devs/2-design-doc/design-doc/services-list-question.txt`, case 2). The rule reports that case in the folder's `descriptor.ts` (`3-implementation/notes/lint-rule-part-way.txt`, case 1). So dropping the rule would leave the gap open, and closing it needs a rule again.
- **What the reviewer observed holds.** With services exported under another name, `tsc -p packages/providers` passes and the rule reports the problem in that `services.ts` (`services-list-question.txt`, case 1). spec-requirement-3 and spec-acceptance-criterion-9 ask for typecheck or lint, so this design meets them.

Changed in 85a62df17. These changes record the decision and match the design doc to the code:
- design-doc-decision-2 records the reviewer's variant under Alternatives, with both reasons above.
- Its Trade-offs state the cost the reviewer named: registration by list, services by convention, a renamed export or a missing module caught by lint instead of typecheck, and a rule the repository maintains.
- design-doc-decision-4 points to that alternative.
- The design doc now binds the fix from 1de5e9205, in design-doc-decision-2, Interfaces, Failure modes and Verification (an inspection entry). A folder whose `services.ts` exports no services is named in the error and never breaks another provider's lookup. A developer has exactly this state part-way through writing a provider.
