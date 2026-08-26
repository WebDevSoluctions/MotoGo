class ApiConfig {
  ApiConfig._();

  /// URL da API MotoGo.
  /// Pode ser sobrescrita com:
  /// flutter run --dart-define=MOTOGO_API_URL=https://api.motogoapp.online/api
  static const String baseUrl = String.fromEnvironment(
    'MOTOGO_API_URL',
    defaultValue: 'https://api.motogoapp.online/api',
  );
}
