import 'package:dio/dio.dart';

class GeocodeService {
  static final GeocodeService _instance = GeocodeService._internal();
  factory GeocodeService() => _instance;
  GeocodeService._internal() {
    _dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 8)));
  }

  late final Dio _dio;

  /// Reverse geocode using Nominatim (OpenStreetMap)
  Future<Map<String, dynamic>?> reverseGeocode(double lat, double lng) async {
    try {
      final res = await _dio.get('https://nominatim.openstreetmap.org/reverse', queryParameters: {
        'format': 'jsonv2',
        'lat': lat,
        'lon': lng,
        'addressdetails': 1,
      }, options: Options(headers: {'User-Agent': 'EstouAquiApp/1.0'}));

      if (res.statusCode == 200 && res.data != null) {
        final data = res.data as Map<String, dynamic>;
        final address = data['address'] as Map<String, dynamic>?;
        String display = data['display_name'] as String? ?? '';
        String city = '';
        if (address != null) {
          city = (address['city'] ?? address['town'] ?? address['village'] ?? '') as String;
        }
        return {
          'displayName': display,
          'address': address,
          'city': city,
        };
      }
    } catch (_) {}
    return null;
  }

  /// Lookup CEP using ViaCEP (Brazil)
  Future<Map<String, String>?> lookupCep(String cep) async {
    final onlyDigits = cep.replaceAll(RegExp(r'[^0-9]'), '');
    if (onlyDigits.length != 8) return null;
    try {
      final res = await _dio.get('https://viacep.com.br/ws/$onlyDigits/json/');
      if (res.statusCode == 200 && res.data != null && res.data['erro'] != true) {
        final data = res.data as Map<String, dynamic>;
        final logradouro = data['logradouro'] as String? ?? '';
        final bairro = data['bairro'] as String? ?? '';
        final localidade = data['localidade'] as String? ?? '';
        final uf = data['uf'] as String? ?? '';
        final address = [logradouro, bairro].where((s) => s.isNotEmpty).join(', ');
        final city = [localidade, uf].where((s) => s.isNotEmpty).join(' - ');
        return {'address': address, 'city': city};
      }
    } catch (_) {}
    return null;
  }
}
