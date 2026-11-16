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

## design-doc-producer — cbf2eb6126b05b1f64a90af84f54e53fe875abf3

### Finding 1: stands

design-doc-decision-3 stands for every provider. In cbf2eb612 I made the decision say so, and its trade-offs now name the change for other providers. I changed no mechanism.

Narrowing it to the connector would take one of two things:

- A branch on the provider's id. providers.md principle 2 forbids it: "Surfaces read descriptors and never branch on a provider id".
- A new descriptor flag whose only purpose is to keep the old behaviour for the built-in providers.

What the reviewer observed is what providers.md already says the settings do: "The app's settings list every provider with its connection state and a summary the provider gives, such as a key's first and last characters, never the credential itself" (`docs/design-docs/providers.md:87`). Before this change, the summary appeared only as a secret field's placeholder, and only while the form was open (`ai-panel.tsx:213` at 924a82669).

The key preview isn't lost for the built-in providers either. `ProviderRow` uses `account.summary` as the row's description whenever the account is connected and no sign-in is pending (`apps/ui/src/features/settings/settings-view/ai-panel.tsx:160`). That row stays above the form while it is open, so the preview stays in view next to the empty key field.

### Finding 2: stands

The form stays empty when it reopens, as every provider's form does. In cbf2eb612 I recorded that as part of design-doc-decision-2, with the alternative and the trade-off.

The case is intended use: spec-requirement-1 has the person connect again with another address or key. It still works either way, so the question is what prefilling buys:

- **Changing the address.** The person types the new address anyway.
- **Changing only the key.** The person retypes an address the row shows right above the form. That's `account.summary`, the address without `/v1` (`ai-panel.tsx:160`). The key must be typed in both cases, because it is secret and never shown back (spec-requirement-5).

Prefilling would need a new contract: `AccountDetails` giving the current values of the connected method's fields that aren't secret, read by Settings and by the terminal prompt. Today that contract would serve one field of one provider. It would save typing an address the person can see. That doesn't outweigh adding a contract to every provider's account details, so the decision records it as a rejected alternative.

### The spec change, for context: changed in cbf2eb612

c0b5b9d6a changed the spec, and I revised the design to match:

- **Decisions 4 and 7.** The listing leaves out the models Ollama or LM Studio says only make embeddings, and offers those a server says nothing about.
- **Decision 2.** Connecting fails with the no-chat-model message when the server lists only such models, or none.
- **Decision 6.** It no longer has Studio remember the last pick. Its `shared.json` field, the recording in the hosts' handlers and in `studio code`, and `AiSettings`' remembered model are all gone. A new chat starts on the model the account proposed at connect: the first offered model the server says can call tools, or else the first offered model.
