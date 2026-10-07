String? validateInternationalPhone(String? value) {
  final normalized = (value ?? '').trim().replaceAll(RegExp(r'[\s()-]'), '');
  if (normalized.isEmpty) return 'Enter your phone number.';
  if (!RegExp(r'^\+[1-9][0-9]{7,14}$').hasMatch(normalized)) {
    return 'Include the country code, for example +1 202 555 0123.';
  }
  return null;
}
