import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';

class RouteResult {
  final List<LatLng> points;
  final double distanceKm;
  final double durationMinutes;

  const RouteResult({
    required this.points,
    required this.distanceKm,
    required this.durationMinutes,
  });
}

class RouteService {
  final Dio dio = Dio();

  Future<RouteResult?> calculateMultiStopRoute({
    required LatLng origin,
    required List<LatLng> stops,
    required LatLng destination,
  }) async {
    final points = <LatLng>[origin, ...stops, destination];
    if (points.length < 2) return null;

    var totalDistance = 0.0;
    var totalMinutes = 0.0;
    final allRoutePoints = <LatLng>[];

    for (var i = 0; i < points.length - 1; i++) {
      final route = await calculateRoute(
        origin: points[i],
        destination: points[i + 1],
      );

      if (route == null) return null;

      totalDistance += route.distanceKm;
      totalMinutes += route.durationMinutes;

      if (allRoutePoints.isEmpty) {
        allRoutePoints.addAll(route.points);
      } else {
        allRoutePoints.addAll(route.points.skip(1));
      }
    }

    return RouteResult(
      points: allRoutePoints,
      distanceKm: totalDistance,
      durationMinutes: totalMinutes,
    );
  }

  // ============================================================
  // GEOCODIFICAÇÃO
  // ============================================================

  Future<LatLng?> searchDestination(
    String query, {
    LatLng? nearby,
    LatLng? avoidPoint,
  }) async {
    final text = query.trim();
    if (text.isEmpty) return null;

    final parsed = _parseAddress(text);
    final queries = <String>[];

    void addQuery(String value) {
      final q = value
          .replaceAll(RegExp(r'\s+'), ' ')
          .replaceAll(RegExp(r',\s*,+'), ',')
          .trim();

      if (q.isNotEmpty && !queries.contains(q)) {
        queries.add(q);
      }
    }

    // 1) Busca literal.
    addQuery('$text, Brasil');

    // 2) Busca estruturada.
    if (parsed.street.isNotEmpty) {
      addQuery([
        parsed.street,
        if (parsed.number.isNotEmpty) parsed.number,
        if (parsed.neighborhood.isNotEmpty) parsed.neighborhood,
        if (parsed.city.isNotEmpty) parsed.city,
        if (parsed.state.isNotEmpty) parsed.state,
        'Brasil',
      ].join(', '));
    }

    // 3) Se houver um ponto próximo, ele é usado apenas como viewbox
    // no Nominatim. Não fazemos reverse-geocoding aqui: uma falha do
    // plugin de geocoding não pode impedir uma entrega por endereço.

    // 4) Busca sem número. Alguns mapas conhecem a rua, mas não possuem
    // o imóvel individual cadastrado.
    if (parsed.number.isNotEmpty) {
      addQuery([
        if (parsed.street.isNotEmpty) parsed.street,
        if (parsed.neighborhood.isNotEmpty) parsed.neighborhood,
        if (parsed.city.isNotEmpty) parsed.city,
        if (parsed.state.isNotEmpty) parsed.state,
        'Brasil',
      ].join(', '));
    }

    final candidates = <_Candidate>[];

    try {
      for (var queryIndex = 0; queryIndex < queries.length; queryIndex++) {
        if (queryIndex > 0) {
          await Future<void>.delayed(const Duration(milliseconds: 1100));
        }
        final searchQuery = queries[queryIndex];
        final params = <String, dynamic>{
          'q': searchQuery,
          'format': 'jsonv2',
          'addressdetails': 1,
          'limit': 10,
          'countrycodes': 'br',
          'dedupe': 1,
        };

        if (nearby != null) {
          const delta = 0.35;
          params['viewbox'] = [
            nearby.longitude - delta,
            nearby.latitude + delta,
            nearby.longitude + delta,
            nearby.latitude - delta,
          ].join(',');
          params['bounded'] = 0;
        }

        final response = await dio.get(
          'https://nominatim.openstreetmap.org/search',
          queryParameters: params,
          options: Options(
            headers: {
              'Accept': 'application/json',
              'Accept-Language': 'pt-BR,pt;q=0.9',
              'User-Agent': 'MotoGo/1.0 (app de mobilidade)',
            },
          ),
        );

        if (response.statusCode != 200 || response.data is! List) {
          continue;
        }

        for (final result in response.data) {
          if (result is! Map) continue;

          final latitude = double.tryParse('${result['lat']}');
          final longitude = double.tryParse('${result['lon']}');
          if (latitude == null || longitude == null) continue;

          final rawAddress = result['address'];
          final address = rawAddress is Map
              ? Map<String, dynamic>.from(rawAddress)
              : <String, dynamic>{};

          candidates.add(
            _Candidate(
              point: LatLng(latitude, longitude),
              houseNumber: address['house_number']?.toString() ?? '',
              road: address['road']?.toString() ??
                  address['pedestrian']?.toString() ??
                  address['footway']?.toString() ??
                  '',
              neighborhood: address['neighbourhood']?.toString() ??
                  address['suburb']?.toString() ??
                  address['quarter']?.toString() ??
                  address['residential']?.toString() ??
                  '',
              city: address['city']?.toString() ??
                  address['town']?.toString() ??
                  address['municipality']?.toString() ??
                  address['village']?.toString() ??
                  '',
              state: address['state']?.toString() ??
                  address['state_district']?.toString() ??
                  '',
              displayName: result['display_name']?.toString() ?? '',
              importance:
                  double.tryParse('${result['importance']}') ?? 0,
            ),
          );
        }

        if (candidates.length >= 30) break;
      }

      if (parsed.number.isNotEmpty) {
        final exact = candidates
            .where(
              (c) => _numbersMatch(parsed.number, c.houseNumber),
            )
            .toList();

        if (exact.isNotEmpty) {
          // Quando estamos procurando o destino, nunca devemos aceitar
          // silenciosamente o mesmo ponto da coleta. Se existirem outros
          // candidatos, priorizamos um ponto realmente diferente.
          final separatedExact = _removeTooCloseCandidates(
            exact,
            avoidPoint,
          );
          final pool = separatedExact.isNotEmpty ? separatedExact : exact;

          final exactBest = _bestCandidate(
            pool,
            parsed,
            nearby: nearby,
          );
          if (exactBest != null) return exactBest.point;
        }
      }

      // Primeiro tentamos candidatos que não coincidam com a origem.
      final separatedCandidates = _removeTooCloseCandidates(
        candidates,
        avoidPoint,
      );
      final candidatePool =
          separatedCandidates.isNotEmpty ? separatedCandidates : candidates;

      final best = _bestCandidate(
        candidatePool,
        parsed,
        nearby: nearby,
      );

      // Se há número, preferimos um imóvel com número confirmado.
      // Se o provedor não possui esse número, aceitamos uma rua fortemente
      // compatível como último recurso, para não bloquear a corrida.
      if (best != null) {
        if (parsed.number.isEmpty ||
            _streetMatches(parsed.street, best.road)) {
          return best.point;
        }
      }
    } catch (e) {
      debugPrint('Nominatim falhou para "$text": $e');
    }

    // Fallback nativo do Android/iOS. Tentamos também uma forma com
    // "Brasil" para aumentar a chance de o Geocoder reconhecer o endereço.
    final nativeQueries = <String>[
      text,
      '$text, Brasil',
      if (parsed.street.isNotEmpty)
        [
          parsed.street,
          if (parsed.number.isNotEmpty) parsed.number,
          if (parsed.neighborhood.isNotEmpty) parsed.neighborhood,
          if (parsed.city.isNotEmpty) parsed.city,
          if (parsed.state.isNotEmpty) parsed.state,
          'Brasil',
        ].join(', '),
    ];

    for (final nativeQuery in nativeQueries) {
      try {
        final nativeResults = await locationFromAddress(nativeQuery);
        if (nativeResults.isNotEmpty) {
          for (final native in nativeResults) {
            final point = LatLng(native.latitude, native.longitude);
            if (!_isTooClose(point, avoidPoint)) {
              return point;
            }
          }
        }
      } catch (e) {
        debugPrint('Geocoder nativo falhou para "$nativeQuery": $e');
      }
    }

    return null;
  }

  // Evita que uma busca de destino aceite a própria origem como destino.
  // 25 m cobre pequenas diferenças do geocoder sem impedir endereços
  // próximos que realmente sejam diferentes.
  bool _isTooClose(LatLng point, LatLng? other) {
    if (other == null) return false;
    final meters = const Distance().as(
      LengthUnit.Meter,
      point,
      other,
    );
    return meters < 25;
  }

  List<_Candidate> _removeTooCloseCandidates(
    List<_Candidate> source,
    LatLng? avoidPoint,
  ) {
    if (avoidPoint == null) return source;
    return source
        .where((candidate) => !_isTooClose(candidate.point, avoidPoint))
        .toList();
  }

  bool _streetMatches(String requested, String returned) {
    final a = _normalize(requested);
    final b = _normalize(returned);
    if (a.isEmpty || b.isEmpty) return false;
    return b.contains(a) || a.contains(b);
  }

  // ============================================================
  // PARSER DO ENDEREÇO
  // ============================================================

  _ParsedAddress _parseAddress(String text) {
    var value = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    var number = '';

    final explicit = RegExp(
      r'\b(?:numero|número|num|n[º°])\s*[:.\-]?\s*(\d+[A-Za-z]?)\b',
      caseSensitive: false,
    ).firstMatch(value);
    if (explicit != null) {
      number = explicit.group(1) ?? '';
      value = value.replaceFirst(explicit.group(0)!, ' ');
    } else {
      // Número no final: Rua X, 701 / Rua X 701
      final trailing = RegExp(r'(?:,|\s)\s*(\d+[A-Za-z]?)\s*$').firstMatch(value);
      if (trailing != null) {
        number = trailing.group(1) ?? '';
        value = value.substring(0, trailing.start).trim();
      }
    }

    final parts = value
        .split(',')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();

    var street = parts.isNotEmpty ? parts.first : value;
    var neighborhood = '';
    var city = '';
    var state = '';

    // Também entende "Rua X, Bairro Centro, Tiradentes, MG".
    if (parts.length > 1) {
      final middle = <String>[];
      for (var i = 1; i < parts.length; i++) {
        final part = parts[i];
        final bairro = RegExp(r'^bairro\s+(.+)$', caseSensitive: false).firstMatch(part);
        if (bairro != null) {
          neighborhood = bairro.group(1)!.trim();
        } else if (RegExp(r'^[A-Za-z]{2}$').hasMatch(part)) {
          state = part.toUpperCase();
        } else {
          middle.add(part);
        }
      }
      if (middle.isNotEmpty) {
        if (neighborhood.isEmpty && middle.length >= 2) {
          neighborhood = middle.first;
          city = middle[1];
          if (middle.length >= 3 && state.isEmpty) state = middle.last.toUpperCase();
        } else if (city.isEmpty) {
          city = middle.last;
          if (neighborhood.isEmpty && middle.length > 1) neighborhood = middle.first;
        }
      }
    } else {
      // Formato sem vírgulas: "Rua X bairro Centro Tiradentes MG"
      final bairro = RegExp(r'\bbairro\s+(.+)$', caseSensitive: false).firstMatch(value);
      if (bairro != null) {
        street = value.substring(0, bairro.start).trim();
        final tail = bairro.group(1)!.trim().split(RegExp(r'\s+'));
        if (tail.length >= 3 && RegExp(r'^[A-Za-z]{2}$').hasMatch(tail.last)) {
          state = tail.removeLast().toUpperCase();
          city = tail.removeLast();
          neighborhood = tail.join(' ');
        } else if (tail.length >= 2) {
          city = tail.removeLast();
          neighborhood = tail.join(' ');
        } else {
          neighborhood = tail.join(' ');
        }
      }
    }

    return _ParsedAddress(
      street: street,
      number: number,
      neighborhood: neighborhood,
      city: city,
      state: state,
    );
  }

  _Candidate? _bestCandidate(
    List<_Candidate> candidates,
    _ParsedAddress parsed, {
    LatLng? nearby,
  }) {
    if (candidates.isEmpty) {
      return null;
    }

    _Candidate? best;
    var bestScore = double.negativeInfinity;

    for (final candidate in candidates) {
      var score = candidate.importance;

      final requestedStreet =
          _normalize(parsed.street);

      final returnedStreet =
          _normalize(candidate.road);

      if (requestedStreet.isNotEmpty &&
          returnedStreet.isNotEmpty &&
          (returnedStreet.contains(
                requestedStreet,
              ) ||
              requestedStreet.contains(
                returnedStreet,
              ))) {
        score += 10;
      }

      if (parsed.neighborhood.isNotEmpty &&
          candidate.neighborhood.isNotEmpty &&
          _normalize(
            candidate.neighborhood,
          ).contains(
            _normalize(
              parsed.neighborhood,
            ),
          )) {
        score += 8;
      }

      if (parsed.state.isNotEmpty &&
          candidate.state.isNotEmpty &&
          _normalize(candidate.state).contains(_normalize(parsed.state))) {
        score += 3;
      }

      if (parsed.city.isNotEmpty &&
          candidate.city.isNotEmpty &&
          _normalize(
            candidate.city,
          ).contains(
            _normalize(
              parsed.city,
            ),
          )) {
        score += 5;
      }

      if (nearby != null) {
        final d = const Distance().as(LengthUnit.Kilometer, nearby, candidate.point);
        score += 1 / (1 + d);
      }

      if (parsed.number.isNotEmpty &&
          candidate.houseNumber.isNotEmpty &&
          _numbersMatch(
            parsed.number,
            candidate.houseNumber,
          )) {
        score += 100;
      }

      if (score > bestScore) {
        bestScore = score;
        best = candidate;
      }
    }

    return best;
  }

  bool _numbersMatch(
    String requested,
    String returned,
  ) {
    final requestedNumber =
        RegExp(r'\d+')
            .firstMatch(requested)
            ?.group(0);

    final returnedNumber =
        RegExp(r'\d+')
            .firstMatch(returned)
            ?.group(0);

    return requestedNumber != null &&
        returnedNumber != null &&
        requestedNumber == returnedNumber;
  }

  String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll(
          RegExp(r'[áàãâä]'),
          'a',
        )
        .replaceAll(
          RegExp(r'[éèêë]'),
          'e',
        )
        .replaceAll(
          RegExp(r'[íìîï]'),
          'i',
        )
        .replaceAll(
          RegExp(r'[óòõôö]'),
          'o',
        )
        .replaceAll(
          RegExp(r'[úùûü]'),
          'u',
        )
        .replaceAll('ç', 'c')
        .replaceAll(
          RegExp(r'[^a-z0-9 ]'),
          ' ',
        )
        .replaceAll(
          RegExp(r'\s+'),
          ' ',
        )
        .trim();
  }

  // ============================================================
  // CALCULAR ROTA
  // ============================================================
  // Usa os servidores públicos FOSSGIS/OSRM com perfis separados.
  // Isso mantém o MotoGo sem dependência de Google Billing e evita
  // calcular bike/a pé como se fossem carro.
  //
  // Perfis disponíveis no servidor:
  //   car  -> moto/mototaxi/viagem (rede viária motorizada)
  //   bike -> bicicleta
  //   foot -> caminhada
  //
  // O servidor é público e possui política de uso; não deve ser usado
  // como infraestrutura de alto volume em produção. Para o lançamento,
  // esta camada fica isolada para podermos trocar o endpoint futuramente
  // sem mexer na tela ou no restante do aplicativo.

  Future<RouteResult?> calculateRoute({
    required LatLng origin,
    required LatLng destination,
    String mode = 'car',
  }) async {
    if (!_validPoint(origin) || !_validPoint(destination)) {
      debugPrint(
        'Rota recusada: coordenadas inválidas. '
        'origem=$origin destino=$destination',
      );
      return null;
    }

    // Entregas e mototáxi usam a mesma rede motorizada que já funciona
    // no aplicativo. Bike/A pé continuam usando a mesma rede para o
    // cálculo de distância/preço; a compatibilidade do entregador e a
    // tarifa continuam separadas.
    final normalizedMode = _normalizeMode(mode);
    final coordinates = _coordinates(origin, destination);

    debugPrint(
      'CALC_ROUTE mode=$normalizedMode '
      'origin=${origin.latitude},${origin.longitude} '
      'destination=${destination.latitude},${destination.longitude}',
    );

    // 1) Mesmo roteador usado pelo fluxo de carro/mototáxi.
    final primaryBase =
        'https://routing.openstreetmap.de/routed-car';

    final primary = await _requestOsrmRoute(
      '$primaryBase/route/v1/driving/$coordinates',
      normalizedMode,
    );
    if (primary != null) return primary;

    // 2) Ponto de endereço pode cair alguns metros fora da via.
    // Fazemos snap dos dois pontos para a via mais próxima e tentamos
    // novamente. Isso é especialmente importante em endereços residenciais.
    final snappedPrimary = await _snapBothToRoad(
      origin,
      destination,
      'https://routing.openstreetmap.de/routed-car',
    );
    if (snappedPrimary != null) {
      final snappedRoute = await _requestOsrmRoute(
        'https://routing.openstreetmap.de/routed-car/route/v1/driving/'
        '${_coordinates(snappedPrimary[0], snappedPrimary[1])}',
        normalizedMode,
      );
      if (snappedRoute != null) return snappedRoute;
    }

    // 3) Segundo motor de emergência, também sem Google Billing.
    final publicBase = 'https://router.project-osrm.org';
    final publicRoute = await _requestOsrmRoute(
      '$publicBase/route/v1/driving/$coordinates',
      normalizedMode,
    );
    if (publicRoute != null) return publicRoute;

    // 4) Snap + segundo motor. Não altera os pontos salvos no pedido.
    final snappedPublic = await _snapBothToRoad(
      origin,
      destination,
      publicBase,
    );
    if (snappedPublic != null) {
      final snappedRoute = await _requestOsrmRoute(
        '$publicBase/route/v1/driving/'
        '${_coordinates(snappedPublic[0], snappedPublic[1])}',
        normalizedMode,
      );
      if (snappedRoute != null) return snappedRoute;
    }

    debugPrint(
      'CALC_ROUTE falhou em todos os motores. '
      'origem=$origin destino=$destination',
    );
    return null;
  }

  String _coordinates(LatLng origin, LatLng destination) =>
      '${origin.longitude},${origin.latitude};'
      '${destination.longitude},${destination.latitude}';

  Future<RouteResult?> _requestOsrmRoute(
    String url,
    String mode,
  ) async {
    try {
      final response = await dio.get(
        url,
        queryParameters: const {
          'overview': 'full',
          'geometries': 'geojson',
          'steps': 'false',
          'alternatives': 'false',
        },
        options: Options(
          receiveTimeout: const Duration(seconds: 12),
          sendTimeout: const Duration(seconds: 6),
          connectTimeout: const Duration(seconds: 6),
          headers: const {
            'Accept': 'application/json',
            'User-Agent': 'MotoGo/1.0 (app de mobilidade)',
          },
          validateStatus: (_) => true,
        ),
      );

      return _parseOsrmResponse(response, mode);
    } on DioException catch (e) {
      debugPrint('OSRM request falhou: ${e.type} ${e.message}');
      return null;
    } catch (e) {
      debugPrint('OSRM request erro: $e');
      return null;
    }
  }

  RouteResult? _parseOsrmResponse(Response response, String mode) {
    if (response.statusCode != 200) {
      debugPrint(
        'OSRM $mode HTTP ${response.statusCode}: ${response.data}',
      );
      return null;
    }

    final raw = response.data;
    if (raw is! Map) {
      debugPrint('OSRM $mode retornou resposta inválida.');
      return null;
    }

    final data = Map<String, dynamic>.from(raw);
    if (data['code'] != 'Ok') {
      debugPrint(
        'OSRM $mode code=${data['code']} message=${data['message'] ?? ''}',
      );
      return null;
    }

    final routes = data['routes'];
    if (routes is! List || routes.isEmpty || routes.first is! Map) {
      debugPrint('OSRM $mode não retornou nenhuma rota.');
      return null;
    }

    final route = Map<String, dynamic>.from(routes.first as Map);
    final distanceMeters = (route['distance'] as num?)?.toDouble();
    final durationSeconds = (route['duration'] as num?)?.toDouble();
    if (distanceMeters == null ||
        durationSeconds == null ||
        !distanceMeters.isFinite ||
        !durationSeconds.isFinite ||
        distanceMeters < 0 ||
        durationSeconds < 0) {
      debugPrint('OSRM $mode retornou distância/duração inválidas.');
      return null;
    }

    final geometry = route['geometry'];
    if (geometry is! Map) {
      debugPrint('OSRM $mode não retornou geometria.');
      return null;
    }

    final coordinates = geometry['coordinates'];
    if (coordinates is! List || coordinates.length < 2) {
      debugPrint('OSRM $mode retornou poucos pontos de geometria.');
      return null;
    }

    final points = <LatLng>[];
    for (final item in coordinates) {
      if (item is! List || item.length < 2) continue;
      final lon = (item[0] as num?)?.toDouble();
      final lat = (item[1] as num?)?.toDouble();
      if (lon == null || lat == null) continue;
      final point = LatLng(lat, lon);
      if (_validPoint(point)) points.add(point);
    }

    if (points.length < 2) {
      debugPrint('OSRM $mode não retornou pontos válidos.');
      return null;
    }

    return RouteResult(
      points: points,
      distanceKm: distanceMeters / 1000.0,
      durationMinutes: durationSeconds / 60.0,
    );
  }

  Future<LatLng?> _snapToRoad(LatLng point, String baseUrl) async {
    try {
      final response = await dio.get(
        '$baseUrl/nearest/v1/driving/'
        '${point.longitude},${point.latitude}',
        queryParameters: const {'number': 1},
        options: Options(
          receiveTimeout: const Duration(seconds: 8),
          sendTimeout: const Duration(seconds: 5),
          connectTimeout: const Duration(seconds: 5),
          headers: const {
            'Accept': 'application/json',
            'User-Agent': 'MotoGo/1.0 (app de mobilidade)',
          },
          validateStatus: (_) => true,
        ),
      );

      if (response.statusCode != 200 || response.data is! Map) return null;
      final data = response.data as Map;
      final waypoints = data['waypoints'];
      if (waypoints is! List || waypoints.isEmpty || waypoints.first is! Map) {
        return null;
      }

      final location = (waypoints.first as Map)['location'];
      if (location is! List || location.length < 2) return null;

      final lon = (location[0] as num?)?.toDouble();
      final lat = (location[1] as num?)?.toDouble();
      if (lon == null || lat == null) return null;

      final snapped = LatLng(lat, lon);
      return _validPoint(snapped) ? snapped : null;
    } catch (e) {
      debugPrint('Snap da coordenada falhou: $e');
      return null;
    }
  }

  Future<List<LatLng>?> _snapBothToRoad(
    LatLng origin,
    LatLng destination,
    String baseUrl,
  ) async {
    final snappedOrigin = await _snapToRoad(origin, baseUrl);
    final snappedDestination = await _snapToRoad(destination, baseUrl);
    if (snappedOrigin == null || snappedDestination == null) return null;

    debugPrint(
      'SNAP_ROUTE origem=${snappedOrigin.latitude},${snappedOrigin.longitude} '
      'destino=${snappedDestination.latitude},${snappedDestination.longitude}',
    );
    return <LatLng>[snappedOrigin, snappedDestination];
  }

  String _normalizeMode(String mode) {
    switch (mode.trim().toLowerCase()) {
      case 'bike':
      case 'bicycle':
      case 'bicicleta':
        return 'bike';
      case 'foot':
      case 'walk':
      case 'pedestrian':
      case 'pedestre':
      case 'a_pe':
        return 'foot';
      case 'car':
      case 'driving':
      case 'moto':
      case 'mototaxi':
      case 'carro':
      default:
        return 'car';
    }
  }

  bool _validPoint(LatLng point) {
    return point.latitude.isFinite &&
        point.longitude.isFinite &&
        point.latitude >= -90 &&
        point.latitude <= 90 &&
        point.longitude >= -180 &&
        point.longitude <= 180 &&
        !(point.latitude == 0 && point.longitude == 0);
  }

}

class _PolylineValue {
  final int index;
  final int value;

  const _PolylineValue(this.index, this.value);
}

class _ParsedAddress {
  final String street;
  final String number;
  final String neighborhood;
  final String city;
  final String state;

  const _ParsedAddress({
    required this.street,
    required this.number,
    required this.neighborhood,
    required this.city,
    required this.state,
  });
}

class _Candidate {
  final LatLng point;
  final String houseNumber;
  final String road;
  final String neighborhood;
  final String city;
  final String displayName;
  final String state;
  final double importance;

  const _Candidate({
    required this.point,
    required this.houseNumber,
    required this.road,
    required this.neighborhood,
    required this.city,
    required this.displayName,
    required this.state,
    required this.importance,
  });
}
