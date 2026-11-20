/// The password rule, matching the Supabase project setting: at least 8
/// characters with both letters and digits.
bool isStrongPassword(String password) =>
    password.length >= 8 &&
    RegExp('[A-Za-z]').hasMatch(password) &&
    RegExp(r'\d').hasMatch(password);
