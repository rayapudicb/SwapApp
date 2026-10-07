/// The legacy immediate-token authentication repository was removed.
///
/// Participant authentication is owned by `passwordless_identity` so every
/// account uses the same OTP, rotating-session, revocation, and continuation
/// contract. This marker remains temporarily to make stale imports fail with a
/// clear migration target instead of reintroducing compatibility endpoints.
@Deprecated('Use PasswordlessAuthCoordinator from passwordless_identity.')
final class LegacyAuthRepositoryRemoved {
  const LegacyAuthRepositoryRemoved._();
}
