/// Constantes da aplicação
class AppConstants {
  // API
  static const String apiBaseUrl = 'https://estouaqui.rpa4all.com/api';
  static const String wsUrl = 'https://estouaqui.rpa4all.com';

  // Storage keys
  static const String tokenKey = 'auth_token';
  static const String userKey = 'current_user';

  // Mapa
  static const double defaultLatitude = -23.5505; // São Paulo
  static const double defaultLongitude = -46.6333;
  static const double defaultZoom = 12.0;
  static const double eventRadius = 50.0; // km

  // Estimativa de público
  static const Map<String, double> densityLevels = {
    'low': 0.5,      // Espaçado (ex: parque)
    'medium': 1.5,   // Moderado (ex: rua)
    'high': 3.0,     // Denso (ex: praça cheia)
    'very_high': 5.0, // Muito denso (ex: show)
  };

  // Categorias de evento
  static const Map<String, String> eventCategories = {
    'manifestacao': 'Manifestação',
    'protesto': 'Protesto',
    'marcha': 'Marcha',
    'ato_publico': 'Ato Público',
    'assembleia': 'Assembleia',
    'greve': 'Greve',
    'ocupacao': 'Ocupação',
    'vigilia': 'Vigília',
    'outro': 'Outro',
  };

  // Categorias com ícones
  static const Map<String, String> categoryEmojis = {
    'manifestacao': '✊',
    'protesto': '📢',
    'marcha': '🚶',
    'ato_publico': '🏛️',
    'assembleia': '🗣️',
    'greve': '🛑',
    'ocupacao': '🏕️',
    'vigilia': '🕯️',
    'outro': '📍',
  };
}
