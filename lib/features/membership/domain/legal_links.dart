/// Links Apple and Google require on a subscription paywall. Override with
/// --dart-define=TERMS_URL=... and --dart-define=PRIVACY_URL=...
class LegalLinks {
  const LegalLinks._();

  static const terms = String.fromEnvironment(
    'TERMS_URL',
    defaultValue:
        'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/',
  );

  static const privacy = String.fromEnvironment('PRIVACY_URL');
}
