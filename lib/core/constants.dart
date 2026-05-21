/// Backend API base URLs.
///
/// [kServerBaseUrl]       → localhost via Android emulator (10.0.2.2 maps to the host machine).
/// [kServerBaseUrlDevice] → host machine LAN IP for physical devices. Update this to your machine's IP.
const String kServerBaseUrl = 'http://10.0.2.2:8000';
const String kServerBaseUrlDevice = 'https://api.mainservicepc.com';
/// Maximum number of upload attempts before permanently marking a sync item as failed.
const int kMaxSyncAttempts = 3;

/// Secure-storage key for the JWT access token.
const String kAuthTokenKey = 'auth_token';
