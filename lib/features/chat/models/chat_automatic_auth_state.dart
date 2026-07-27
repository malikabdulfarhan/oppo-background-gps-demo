enum ChatAutomaticAuthState {
  unavailable,
  idle,
  restoring,
  signingIn,
  authenticated,
  sessionExpired,
  failed;

  String get label => switch (this) {
    unavailable => 'Not configured',
    idle => 'Ready',
    restoring => 'Restoring saved login',
    signingIn => 'Signing in securely',
    authenticated => 'Authenticated',
    sessionExpired => 'Sign-in required',
    failed => 'Unavailable',
  };
}
