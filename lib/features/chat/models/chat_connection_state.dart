enum ChatNetworkState {
  unknown,
  connecting,
  connected,
  disconnected;

  String get label => switch (this) {
    unknown => 'Unknown',
    connecting => 'Connecting',
    connected => 'Connected',
    disconnected => 'Disconnected',
  };
}

enum ChatAuthenticationState {
  loggedOut,
  loggingIn,
  loggedIn,
  authenticationExpired,
  kickedOffline;

  String get label => switch (this) {
    loggedOut => 'Logged out',
    loggingIn => 'Logging in',
    loggedIn => 'Logged in',
    authenticationExpired => 'Expired',
    kickedOffline => 'Kicked offline',
  };
}

enum ChatUserSigState {
  notAvailable,
  availableInMemory,
  expired;

  String get label => switch (this) {
    notAvailable => 'Not available',
    availableInMemory => 'Available in memory',
    expired => 'Expired',
  };
}
