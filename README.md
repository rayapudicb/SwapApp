# Swappy Mobile

Flutter participant client for the headless Swappy API. The current mobile
slice includes passwordless identity, event discovery, protected ticket-photo
import/OCR, My Tickets, versioned Post lifecycle operations, published Post
discovery, and incoming/outgoing Swap Requests. Capabilities without an
implemented contract remain explicit unavailable states.

The application contains no mock events, hardcoded participant, client-owned
swap completion, or default API endpoint.

## Run locally

For iOS Simulator development, use the guarded launcher. It verifies
PostgreSQL, starts the loopback-only API when necessary, waits for the exact
Swappy health response, boots the simulator, and launches the normal app entry
point:

```bash
./scripts/run_ios_local.sh
```

Use this command instead of launching an already-installed simulator build by
itself. The app cannot authenticate when its API process is stopped. The
launcher verifies the required local API capabilities—not only process
health—and stops the API process it started when Flutter exits. VS Code's
**Swappy iOS Simulator (local)** profile runs paired start/stop tasks.

Configure the API endpoint at build/run time. Android emulators normally use
the host bridge address. Cleartext HTTP is permitted only by the Android debug
manifest; release builds must use HTTPS.

```bash
flutter run --dart-define=SWAPPY_API_BASE_URL=http://10.0.2.2:3100
```

```bash
flutter run --dart-define=SWAPPY_API_BASE_URL=https://your-development-api.example
```

For an iOS simulator only after the API has passed the guarded preflight:

```bash
flutter run --dart-define=SWAPPY_API_BASE_URL=http://127.0.0.1:3100
```

Adding the camera/gallery plugin requires stopping the running app and doing a
full rebuild; hot reload alone cannot register a new native plugin.

If the Post tab still shows “How a trusted post works” and says posting is
unavailable, the simulator is running an older binary. Stop it and run the app
again; that screen is not present in the current source.

## Operational seat-swap flow

1. In **Post**, choose **Offer my seats**, add a private ticket photo if
   needed, confirm the detected details, and select the resulting ticket.
2. Save the Post draft with the seats wanted (or **Accept any seat**).
3. Open **My Posts** and publish the draft.
4. A second participant opens **Find seats** (globally or from an event), opens
   the published Post, and offers their own compatible published Post.
5. The target owner opens **Swap Requests** and selects or rejects the
   interest; the requester can withdraw it.

The accepted API is seat-for-seat: every Post contains an offered ticket and
the desired seat criteria, and every Swap Request links two published Posts.
A standalone wanted-seat-only Post is not part of the current server contract.

Without `SWAPPY_API_BASE_URL`, the app starts in a configuration-required state
and does not attempt a network request.

## Verify

```bash
flutter analyze
flutter test
```
