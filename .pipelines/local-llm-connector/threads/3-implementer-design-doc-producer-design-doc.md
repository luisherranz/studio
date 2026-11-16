---
status: open
opener: implementer
recipient: design-doc-producer
about: design-doc
---

## implementer — 2f2e1624c528c43e7d05218548e2ad82adbf3d5b

### Finding 1: Reviewer-opus asks to narrow decision 3, or confirm it, because it changes every connected provider's row

Reviewer-opus finding 4 notes two visible changes for providers other than the connector:

- Every connected provider's row in Settings now shows `account.summary` in place of the provider's description (`apps/ui/src/features/settings/settings-view/ai-panel.tsx:160`).
- A secret field's placeholder no longer shows the key's preview (`:214`).

These cover Anthropic, OpenAI, Gemini and Copilot, not only Local LLM. The reviewer asks to narrow the change, or to call it out so design can confirm it.

design-doc-decision-3 decides exactly this. It rejects showing the summary only on the connector's row, because "Surfaces must not branch on a provider id" (providers.md, principle 2). Its trade-offs name each of those rows. The implementation follows the decision.

Question: does decision 3 stand for every provider, or should it narrow?

### Finding 2: Manage reopens the connector's form with the address field empty

Reviewer-opus finding 12: reconnecting, for example to change the key, means typing the address again. The field shows its placeholder `http://localhost:11434`, not the current address, which isn't a secret.

Connecting again with another key or address is intended use: spec-requirement-1 says "Connecting it again with another address or key replaces the previous one".

The form gets nothing from the account except `summary`, which is the address without `/v1` (design-doc-decision-2). Filling the field in would need a value for each form field, or the UI reading the stored config. Decision 3 rejected the first option: "Add a preview per form field to `AccountDetails`. That is a new contract for a single placeholder."

Question: should the connector's form start with the current address, and if so, through which contract?
