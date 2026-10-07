# Mobile API integration status

Checked against the authoritative `swappy.yaml` and mobile handoff on
2026-08-13.

## Outcome

- 44 of the current 45 participant endpoints have typed mobile transports and
  real participant flows.
- The health endpoint is also integrated.
- No supplied endpoint has multiple competing mobile integrations.
- Legacy offer, proposal, top-up, participant-declared-inside, and seat-map
  placement APIs were removed because they are not part of the contract.
- The application uses server responses for session continuation, onboarding,
  discovery, protected ticket import/OCR, photo-checked ticket bundles,
  evidence/eligibility, entitlements, and intent lifecycle state. It does not
  create sample success data.

## Endpoint matrix

| Surface | Endpoints | Transport | Participant flow |
| --- | ---: | --- | --- |
| Authentication/session | 7 | Integrated | Integrated |
| Profile/onboarding | 3 | Integrated | Integrated |
| Account deletion | 3 | Integrated | Integrated |
| Event discovery/nearby | 2 | Integrated | Integrated |
| Event layout | 1 | Missing | Missing |
| Ticket import/upload/confirm | 6 | Integrated | Integrated |
| Ticket bundles/My Tickets | 2 | Integrated | Integrated |
| Evidence | 3 | Integrated | Photo-import submission is integrated; free-form submission remains gated |
| Entitlements | 2 | Integrated | List/detail integrated |
| Swap intents/Posts | 8 | Integrated | Photo/provider create, cash proposal, list/detail/update/publish/pause/resume/withdraw integrated |
| Public Posts | 2 | Integrated | Browse/list and latest detail integrated |
| Swap Requests | 6 | Integrated | Submit, list, detail, select, reject, and withdraw integrated |

Evidence submission is intentionally not exposed as a free-form mobile form.
The private ticket import flow produces its one-use `protectedObjectRef`, keeps
it in memory, and immediately consumes it through evidence submission. Raw
barcodes, booking credentials, and pasted provider payloads are never accepted
as substitutes.

## Production behavior

- A 401 refreshes once; a second 401 clears the local session and returns to
  sign-in.
- Requests and mutation retries are bound to the participant session that
  started them. They abort instead of reusing a different participant's token.
- Exchange commands use one cryptographically random idempotency key and an
  immutable body for bounded timeout/transport/503 retries only.
- Unknown mutation outcomes block new exchange commands until the same command
  is retried or receives a definitive result.
- 409 conflicts refetch authoritative server state and require participant
  review before a new action.
- Failed Post and Swap Request submissions keep the editor open with all input
  preserved. Event detail can open a `contextRef`-filtered public Post feed.
- Evidence, entitlement, discovery, proximity, and intent data are cleared on
  session changes; late responses cannot populate the next participant's UI.
- Nearby evaluation uses a fresh, foreground-only location observation and
  expires/clears the server result. No background location stream is used.
- Android blocks screenshots and recording globally. iOS obscures app-switcher
  previews and active screen recording/mirroring; iOS does not provide a
  supported API to preempt a one-off hardware screenshot.

## Explicitly not implemented

The current mobile app still lacks event-layout retrieval. Do not add mock or
guessed clients for agreements, mutual consent, holds, provider
execution/confirmation, payments, chat, or notifications. None are present in
the supplied contract.

Standalone wanted-seat-only Posts are also not implemented: the accepted
contract requires every Post to offer one ticket/bundle and every Swap Request
to link that target Post to the requester's compatible published Post.

## External prerequisites

- A configured production identity delivery provider; the fixed `1234` code is
  isolated to the internal development graph.
- A correctly migrated PostgreSQL runtime with the required audit, append-only,
  projection, and exchange persistence boundaries.
- Configured protected ticket storage, Ticketmaster Discovery, OCR processing,
  and the current database migration on the backend.
- Provider/organizer verification remains required before a ticket can be
  described as ownership-, validity-, or transfer-verified.
- Release API URLs must use HTTPS; local debug loopback may use HTTP.
