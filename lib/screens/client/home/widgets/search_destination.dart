import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../../config/colors.dart';

class DestinationSearchResult {
  final String displayName;
  final LatLng location;

  const DestinationSearchResult({
    required this.displayName,
    required this.location,
  });
}

class SearchDestination extends StatefulWidget {
  final ValueChanged<DestinationSearchResult>? onDestinationSelected;

  const SearchDestination({
    super.key,
    this.onDestinationSelected,
  });

  @override
  State<SearchDestination> createState() =>
      _SearchDestinationState();
}

class _SearchDestinationState
    extends State<SearchDestination> {
  final TextEditingController _controller =
      TextEditingController();

  final FocusNode _focusNode = FocusNode();

  final Dio _dio = Dio();

  Timer? _debounce;

  List<DestinationSearchResult> _results = [];

  bool _loading = false;

  bool _showResults = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    _dio.close();

    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();

    if (value.trim().length < 3) {
      setState(() {
        _results = [];
        _loading = false;
        _showResults = false;
      });

      return;
    }

    _debounce = Timer(
      const Duration(milliseconds: 600),
      () {
        _searchAddress(value.trim());
      },
    );
  }

  Future<void> _searchAddress(String query) async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _showResults = true;
    });

    try {
      final response = await _dio.get(
        'https://nominatim.openstreetmap.org/search',
        queryParameters: {
          'q': '$query, Brasil',
          'format': 'json',
          'addressdetails': 1,
          'limit': 6,
          'countrycodes': 'br',
        },
        options: Options(
          headers: {
            'Accept': 'application/json',
            'User-Agent':
                'MotoGo/1.0 (app de mobilidade)',
          },
        ),
      );

      if (!mounted) return;

      final data = response.data;

      if (data is! List) {
        setState(() {
          _results = [];
          _loading = false;
        });

        return;
      }

      final results =
          <DestinationSearchResult>[];

      for (final item in data) {
        if (item is! Map) continue;

        final latValue = item['lat'];
        final lonValue = item['lon'];

        if (latValue == null ||
            lonValue == null) {
          continue;
        }

        final latitude =
            double.tryParse(
          latValue.toString(),
        );

        final longitude =
            double.tryParse(
          lonValue.toString(),
        );

        if (latitude == null ||
            longitude == null) {
          continue;
        }

        final name =
            item['display_name']?.toString();

        if (name == null || name.isEmpty) {
          continue;
        }

        results.add(
          DestinationSearchResult(
            displayName: name,
            location: LatLng(
              latitude,
              longitude,
            ),
          ),
        );
      }

      setState(() {
        _results = results;
        _loading = false;
      });
    } on DioException catch (e) {
      debugPrint(
        'Erro na busca de endereço: ${e.message}',
      );

      if (!mounted) return;

      setState(() {
        _results = [];
        _loading = false;
      });
    } catch (e) {
      debugPrint(
        'Erro na busca: $e',
      );

      if (!mounted) return;

      setState(() {
        _results = [];
        _loading = false;
      });
    }
  }

  void _selectDestination(
    DestinationSearchResult result,
  ) {
    _controller.text = _shortName(
      result.displayName,
    );

    _focusNode.unfocus();

    setState(() {
      _results = [];
      _showResults = false;
    });

    widget.onDestinationSelected?.call(
      result,
    );
  }

  String _shortName(String name) {
    final parts = name
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();

    if (parts.length <= 2) {
      return name;
    }

    return '${parts[0]}, ${parts[1]}';
  }

  void _clearSearch() {
    _controller.clear();

    setState(() {
      _results = [];
      _showResults = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius:
                BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color:
                    Colors.black.withOpacity(.05),
                blurRadius: 15,
                offset:
                    const Offset(0, 5),
              ),
            ],
          ),
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,

            onChanged:
                _onSearchChanged,

            onTap: () {
              if (_controller.text.length >= 3) {
                setState(() {
                  _showResults = true;
                });
              }
            },

            textInputAction:
                TextInputAction.search,

            decoration:
                InputDecoration(
              hintText:
                  'Para onde você quer ir?',

              helperText:
                  'Escolha um destino',

              prefixIcon:
                  Container(
                margin:
                    const EdgeInsets.all(8),
                decoration:
                    BoxDecoration(
                  color: AppColors.primary
                      .withOpacity(.12),
                  borderRadius:
                      BorderRadius.circular(
                    14,
                  ),
                ),
                child:
                    const Icon(
                  Icons.search,
                  color:
                      AppColors.primary,
                ),
              ),

              suffixIcon:
                  _loading
                      ? const Padding(
                          padding:
                              EdgeInsets.all(
                            14,
                          ),
                          child:
                              SizedBox(
                            width: 20,
                            height: 20,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          ),
                        )
                      : _controller
                              .text
                              .isNotEmpty
                          ? IconButton(
                              onPressed:
                                  _clearSearch,
                              icon:
                                  const Icon(
                                Icons.close,
                              ),
                            )
                          : null,

              filled: true,

              fillColor:
                  Colors.white,

              border:
                  OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(
                  20,
                ),
                borderSide:
                    BorderSide.none,
              ),

              enabledBorder:
                  OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(
                  20,
                ),
                borderSide:
                    BorderSide.none,
              ),

              focusedBorder:
                  OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(
                  20,
                ),
                borderSide:
                    BorderSide(
                  color:
                      AppColors.primary,
                  width: 1.5,
                ),
              ),

              contentPadding:
                  const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 16,
              ),
            ),
          ),
        ),

        if (_showResults)
          _buildResults(),
      ],
    );
  }

  Widget _buildResults() {
    if (_loading) {
      return const SizedBox(
        height: 80,
        child: Center(
          child:
              CircularProgressIndicator(),
        ),
      );
    }

    if (_results.isEmpty &&
        _controller.text.length >= 3) {
      return Container(
        margin:
            const EdgeInsets.only(top: 8),
        padding:
            const EdgeInsets.all(18),
        decoration:
            BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.circular(18),
        ),
        child: const Row(
          children: [
            Icon(
              Icons.location_off_outlined,
              color: Colors.grey,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Nenhum endereço encontrado.',
                style: TextStyle(
                  color: Colors.grey,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin:
          const EdgeInsets.only(top: 8),

      decoration:
          BoxDecoration(
        color: Colors.white,

        borderRadius:
            BorderRadius.circular(18),

        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withOpacity(.08),
            blurRadius: 20,
            offset:
                const Offset(0, 8),
          ),
        ],
      ),

      child: ListView.separated(
        shrinkWrap: true,

        physics:
            const NeverScrollableScrollPhysics(),

        itemCount:
            _results.length,

        separatorBuilder:
            (_, __) =>
                const Divider(
          height: 1,
          indent: 65,
        ),

        itemBuilder:
            (context, index) {
          final result =
              _results[index];

          return ListTile(
            contentPadding:
                const EdgeInsets.symmetric(
              horizontal: 15,
              vertical: 7,
            ),

            leading:
                Container(
              width: 42,
              height: 42,
              decoration:
                  BoxDecoration(
                color:
                    AppColors.primary
                        .withOpacity(.10),
                shape:
                    BoxShape.circle,
              ),
              child:
                  const Icon(
                Icons.location_on_outlined,
                color:
                    AppColors.primary,
              ),
            ),

            title:
                Text(
              _shortName(
                result.displayName,
              ),

              maxLines: 2,

              overflow:
                  TextOverflow.ellipsis,

              style:
                  const TextStyle(
                fontWeight:
                    FontWeight.w600,
              ),
            ),

            subtitle:
                Text(
              result.displayName,

              maxLines: 1,

              overflow:
                  TextOverflow.ellipsis,

              style:
                  const TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),

            onTap:
                () {
              _selectDestination(
                result,
              );
            },
          );
        },
      ),
    );
  }
}