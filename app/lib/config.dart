/// Build-time settings, passed with `--dart-define-from-file env/<flavor>.json`.
library;

/// Where the API lives, without a trailing slash: `/api` on the web build,
/// which shares an origin with it, and a full URL anywhere else.
const kApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: '/api',
);

/// The Google OAuth web client. The ID tokens the phones send are minted for
/// it, which is how the server knows to accept them.
const kGoogleWebClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');

/// The Google OAuth iOS client.
const kGoogleIosClientId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');

/// The PostHog project key, public by design. Empty turns analytics off.
const kPostHogKey = String.fromEnvironment('POSTHOG_KEY');

/// Where PostHog lives: its US cloud.
const kPostHogHost = String.fromEnvironment(
  'POSTHOG_HOST',
  defaultValue: 'https://us.i.posthog.com',
);

/// [value], or null when it was not set.
String? nullIfEmpty(String value) => value.isEmpty ? null : value;
