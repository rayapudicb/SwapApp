# Mobile Agent Routing

Primary role: `../../.agents/skills/frontend-developer`.

Add Product Owner for scope, UI/UX Designer and Product Psychologist for flows and trust copy, Swap Engine Domain or Vertical Integration for exchange/provider behavior, Security for identity or sensitive data, QA for scenarios, QA Automation for repeatable device flows, and Code Reviewer before completion.

## Mobile rules

- Keep entitlement evidence, booking references, barcodes, provider tokens, and identity data out of logs, analytics, screenshots, and notifications.
- Server-configured screens may use only approved, versioned components and actions; never execute downloaded code.
- Model loading, empty, validation, offline, timeout, retry, conflict, cancellation, and recovery states.
- Use accessible semantics, scalable text, sufficient targets, and platform-appropriate navigation.
- Keep API base URLs and secrets out of source code.
- Run `flutter analyze` and `flutter test` for every completed slice.
