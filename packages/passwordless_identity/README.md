# Passwordless Identity

Reusable Flutter-facing passwordless identity module. It contains:

- typed OTP, session, continuation, reauthentication, and deletion contracts;
- an injected repository boundary and HTTP implementation;
- a testable session coordinator with refresh single-flight behavior;
- platform-backed refresh-session, pending-challenge, and
  installation-identifier storage; and
- accessible phone and OTP screens with injected application branding.

The package does not import Swappy profile, event, listing, or exchange code.
After authentication it exposes the server-owned `AuthContinuation`; the host
application maps `nextAction` and `nextStep` to its own routes.

Access tokens remain in memory. The secure refresh-session record contains the
opaque rotating refresh token and, only while a response is ambiguous, the
pending refresh idempotency operation needed for exact safe replay. A random
installation identifier is also stored with `flutter_secure_storage`.

An unexpired OTP entry step can resume after an application restart. The
default secure store retains only the opaque challenge identifier, masked
destination, expiry, and resend time. It never retains the phone number or OTP.
Custom session stores can opt into the same behavior by implementing
`PendingAuthChallengeStore`; existing `AuthSessionStore` implementations remain
compatible.

Ambiguous OTP request, resend, refresh, deletion-challenge,
deletion-verification, and deletion-command responses retain their operation
key for an exact retry. Definitive failures and successful completion clear the
applicable operation. Late responses from a cancelled phone flow are discarded;
a late verification success is also revoked on a best-effort basis. Secure
storage failures return a stable client error without leaving the coordinator
in a busy state.

The public HTTP repository ignores any OTP-like field in a challenge response.
An internal development host may wrap the repository from a separate,
non-release application entrypoint and enrich `internalVerificationCode`
through a separately gated loopback inspector. An internal-only host coordinator
may immediately submit the inspected code through the normal server verification
transaction; a failure remains on the OTP screen for a safe retry. A production
API must never return the OTP and must deliver it through an approved
out-of-band adapter.

The package is application-neutral: its HTTP base URI, transport, secure store,
clock, identifiers, branding, and continuation routing are injected or owned by
the host. It imports no Swappy profile, location, event, listing, swap, admin,
or provider code.

## Independent verification

From this directory:

```sh
flutter pub get --enforce-lockfile
dart analyze
flutter test
```

The repository CI runs these checks in a dedicated package job before the
mobile host application checks.
