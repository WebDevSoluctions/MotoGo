import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../config/colors.dart';

class AddressSearchResult {
  final String displayName;
  final String road;
  final String houseNumber;
  final String neighbourhood;
  final String city;
  final String state;
  final String postcode;
  final LatLng location;

  const AddressSearchResult({
    required this.displayName,
    required this.road,
    required this.houseNumber,
    required this.neighbourhood,
    required this.city,
    required this.state,
    required this.postcode,
    required this.location,
  });

  String get shortAddress {
    final parts = <String>[];
    if (road.isNotEmpty) {
      parts.add(houseNumber.isNotEmpty ? '$road, $houseNumber' : road);
    }
    if (neighbourhood.isNotEmpty) parts.add(neighbourhood);
    if (city.isNotEmpty) parts.add(city);
    if (state.isNotEmpty) parts.add(state);
    return parts.isEmpty ? displayName : parts.join(', ');
  }
}

class AddressSearchField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final ValueChanged<AddressSearchResult>? onSelected;
  final LatLng? nearby;
  final LatLng? avoidPoint;

  const AddressSearchField({
    super.key,
    required this.controller,
    required this.hint,
    required this.icon,
    this.onSelected,
    this.nearby,
    this.avoidPoint,
  });

  @override
  State<AddressSearchField> createState() => _AddressSearchFieldState();
}

class _AddressSearchFieldState extends State<AddressSearchField> {
  final Dio _dio = Dio();
  Timer? _debounce;
  List<AddressSearchResult> _results = [];
  bool _loading = false;
  bool _showResults = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _dio.close(force: true);
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    if (value.trim().length < 3) {
      setState(() {
        _results = [];
        _showResults = false;
        _loading = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _search(value.trim());
    });
  }

  Future<void> _search(String query) async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _showResults = true;
    });

    try {
      final queries = await _buildSearchQueries(query);
      final List<AddressSearchResult> list = [];

      for (var queryIndex = 0; queryIndex < queries.length; queryIndex++) {
        if (queryIndex > 0) {
          await Future<void>.delayed(const Duration(milliseconds: 1100));
        }
        final searchQuery = queries[queryIndex];
        final params = <String, dynamic>{
          'q': searchQuery,
          'format': 'jsonv2',
          'addressdetails': 1,
          'limit': 8,
          'countrycodes': 'br',
          'dedupe': 1,
        };

        // Quando temos a localização atual, usamos a região como
        // prioridade, mas NÃO bloqueamos resultados fora dela.
        // Isso permite pesquisar São João del-Rei estando em Tiradentes.
        if (widget.nearby != null) {
          const delta = 0.35;
          params['viewbox'] = [
            widget.nearby!.longitude - delta,
            widget.nearby!.latitude + delta,
            widget.nearby!.longitude + delta,
            widget.nearby!.latitude - delta,
          ].join(',');
          params['bounded'] = 0;
        }

        final response = await _dio.get(
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

        final data = response.data;
        if (data is! List) continue;

        for (final item in data) {
          if (item is! Map) continue;

          final lat = double.tryParse('${item["lat"]}');
          final lon = double.tryParse('${item["lon"]}');
          if (lat == null || lon == null) continue;

          final rawAddress = item['address'];
          final address = rawAddress is Map
              ? Map<String, dynamic>.from(rawAddress)
              : <String, dynamic>{};

          final result = AddressSearchResult(
            displayName: '${item["display_name"] ?? ''}',
            road: '${address["road"] ?? address["pedestrian"] ?? address["footway"] ?? ''}',
            houseNumber: '${address["house_number"] ?? ''}',
            neighbourhood:
                '${address["neighbourhood"] ?? address["suburb"] ?? address["quarter"] ?? address["residential"] ?? ''}',
            city:
                '${address["city"] ?? address["town"] ?? address["municipality"] ?? address["village"] ?? ''}',
            state: '${address["state"] ?? address["state_district"] ?? ''}',
            postcode: '${address["postcode"] ?? ''}',
            location: LatLng(lat, lon),
          );

          // Para o campo de destino, evita sugerir a mesma coordenada
          // da coleta. Se não houver outra opção, o fluxo principal
          // ainda valida a distância antes de calcular a rota.
          if (widget.avoidPoint != null) {
            final meters = const Distance().as(
              LengthUnit.Meter,
              result.location,
              widget.avoidPoint!,
            );
            if (meters < 25) continue;
          }

          final key =
              '${result.displayName}|${result.location.latitude.toStringAsFixed(5)}|${result.location.longitude.toStringAsFixed(5)}';

          if (!list.any((item) =>
              '${item.displayName}|${item.location.latitude.toStringAsFixed(5)}|${item.location.longitude.toStringAsFixed(5)}' ==
              key)) {
            list.add(result);
          }
        }

        if (list.length >= 6) break;
      }

      if (!mounted) return;

      // Se a API não devolveu o número, ainda mostramos a rua como
      // sugestão. O usuário pode então confirmar o número no fluxo.
      setState(() {
        _results = list.take(6).toList();
        _loading = false;
      });
    } catch (e) {
      debugPrint('Busca de endereço falhou: $e');
      if (!mounted) return;
      setState(() {
        _results = [];
        _loading = false;
      });
    }
  }

  Future<List<String>> _buildSearchQueries(String query) async {
    final original = query.trim();
    final normalized = original
        .replaceAll(
          RegExp(
            r'\b(n[úu]mero|nº|n°|num)\s*[:.-]?\s*\d+',
            caseSensitive: false,
          ),
          ' ',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final queries = <String>[];

    void add(String value) {
      final q = value
          .replaceAll(RegExp(r'\s+'), ' ')
          .replaceAll(RegExp(r',\s*,+'), ',')
          .trim()
          .replaceAll(RegExp(r',\s*Brasil\s*,?\s*Brasil$', caseSensitive: false), ', Brasil');

      if (q.isNotEmpty && !queries.contains(q)) {
        queries.add(q);
      }
    }

    // Primeiro preserva exatamente o que o usuário digitou.
    add('$original, Brasil');

    // Se o usuário está usando "número 701", também tentamos sem
    // a palavra "número", porque os geocoders entendem melhor "Rua X, 701".
    final numberMatch = RegExp(
      r'\b(?:n[úu]mero|num|n[º°])\s*[:.-]?\s*(\d+[A-Za-z]?)\b',
      caseSensitive: false,
    ).firstMatch(original);

    final number = numberMatch?.group(1) ??
        RegExp(r'(?:,|\s)\s*(\d+[A-Za-z]?)\s*$')
            .firstMatch(original)
            ?.group(1);

    if (number != null && number.isNotEmpty) {
      final withoutNumberWord = original
          .replaceFirst(
            RegExp(
              r'\b(?:n[úu]mero|num|n[º°])\s*[:.-]?\s*' +
                  RegExp.escape(number),
              caseSensitive: false,
            ),
            '',
          )
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

      add('$withoutNumberWord, Brasil');
    }

    // O ponto próximo serve apenas para priorizar a região no Nominatim.
    // Não fazemos reverse-geocoding do GPS durante a busca manual.
    // Assim uma falha momentânea do plugin de localização não bloqueia
    // a seleção de um endereço.

    // Caso o usuário tenha digitado "bairro X".
    final bairroMatch = RegExp(
      r'\b(?:bairro)\s+(.+?)(?=\s+numero\b|\s+n[º°]?\b|$)',
      caseSensitive: false,
    ).firstMatch(normalized);

    if (bairroMatch != null) {
      final bairro = bairroMatch.group(1)?.trim() ?? '';
      final semBairro = normalized
          .replaceFirst(bairroMatch.group(0)!, '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

      add('$semBairro, $bairro, Brasil');
    }

    // Fallback sem número: útil quando o provedor não possui o imóvel
    // cadastrado, mas conhece perfeitamente a rua/bairro.
    if (number != null && number.isNotEmpty) {
      final withoutNumber = original
          .replaceAll(
            RegExp(
              r'(?:,|\s)\s*(?:n[úu]mero|num|n[º°])?\s*' +
                  RegExp.escape(number) +
                  r'\s*$',
              caseSensitive: false,
            ),
            '',
          )
          .trim();
      add('$withoutNumber, Brasil');
    }

    return queries;
  }

  void _select(AddressSearchResult result) {
    // Preserva o número que o usuário digitou caso o provedor conheça
    // a rua, mas não tenha o imóvel individual cadastrado.
    final typedNumber = RegExp(
      r'(?:^|[,\s])(?:n[úu]mero|num|n[º°])?\s*([0-9]+[A-Za-z]?)\s*$',
      caseSensitive: false,
    ).firstMatch(widget.controller.text.trim())?.group(1);

    final selectedNumber = result.houseNumber.isNotEmpty
        ? result.houseNumber
        : typedNumber;

    var display = result.shortAddress;
    if (selectedNumber != null &&
        selectedNumber.isNotEmpty &&
        !RegExp(
          r',\s*' + RegExp.escape(selectedNumber) + r'\b',
        ).hasMatch(display)) {
      if (result.road.isNotEmpty) {
        final parts = <String>[
          '${result.road}, $selectedNumber',
          if (result.neighbourhood.isNotEmpty) result.neighbourhood,
          if (result.city.isNotEmpty) result.city,
          if (result.state.isNotEmpty) result.state,
        ];
        display = parts.join(', ');
      } else {
        display = '$display, $selectedNumber';
      }
    }

    widget.controller.text = display;
    widget.onSelected?.call(
      selectedNumber == result.houseNumber
          ? result
          : AddressSearchResult(
              displayName: result.displayName,
              road: result.road,
              houseNumber: selectedNumber ?? result.houseNumber,
              neighbourhood: result.neighbourhood,
              city: result.city,
              state: result.state,
              postcode: result.postcode,
              location: result.location,
            ),
    );

    _showResults = false;
    _results = [];
    FocusScope.of(context).unfocus();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: widget.controller,
          onChanged: _onChanged,
          onTap: () {
            if (_results.isNotEmpty) setState(() => _showResults = true);
          },
          decoration: InputDecoration(
            hintText: widget.hint,
            prefixIcon: Icon(widget.icon, color: AppColors.primary),
            suffixIcon: _loading
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        if (_showResults && _results.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(.08),
                  blurRadius: 16,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _results.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, index) {
                final result = _results[index];
                return Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    leading: const Icon(Icons.location_on_outlined, color: AppColors.primary),
                    title: Text(result.shortAddress, maxLines: 2, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                      result.postcode.isNotEmpty
                          ? '${result.neighbourhood.isEmpty ? '' : '${result.neighbourhood} • '}${result.postcode}'
                          : result.displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => _select(result),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
