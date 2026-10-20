/// Links Apple and Google require on a subscription paywall and for
/// account deletion. The pages live in /legal and are published by GitHub
/// Pages. Override with --dart-define=TERMS_URL=... and
/// --dart-define=PRIVACY_URL=... if you move them.
class LegalLinks {
  const LegalLinks._();

  static const _base = 'https://rvastrovastu.github.io/rvastrovastu/legal';

  static const terms = String.fromEnvironment(
    'TERMS_URL',
    defaultValue: '$_base/terms.html',
  );

  static const privacy = String.fromEnvironment(
    'PRIVACY_URL',
    defaultValue: '$_base/privacy.html',
  );

  /// Instructions for deleting an account without the app (Google Play
  /// asks for this link in the Data safety form).
  static const deleteAccount = '$_base/delete-account.html';
}
