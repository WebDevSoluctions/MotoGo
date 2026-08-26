import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../../config/api_config.dart';
import '../../../config/colors.dart';
import '../../../services/auth_service.dart';
import '../../../widgets/custom_appbar.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoriteAddress {
  final int id;
  final String label;
  final String address;
  final double? latitude;
  final double? longitude;
  final String iconType;

  const _FavoriteAddress({
    required this.id,
    required this.label,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.iconType,
  });

  factory _FavoriteAddress.fromMap(Map<String, dynamic> map) {
    return _FavoriteAddress(
      id: int.tryParse(map['id']?.toString() ?? '') ?? 0,
      label: map['label']?.toString() ?? 'Endereço',
      address: map['address']?.toString() ?? '',
      latitude: double.tryParse(map['latitude']?.toString() ?? ''),
      longitude: double.tryParse(map['longitude']?.toString() ?? ''),
      iconType: map['icon_type']?.toString() ?? 'place',
    );
  }
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  static const String baseUrl = ApiConfig.baseUrl;

  final Dio _dio = Dio();

  final List<_FavoriteAddress> _favorites = [];
  bool _isLoading = true;
  bool _isSaving = false;
  int? _userId;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  @override
  void dispose() {
    _dio.close(force: true);
    super.dispose();
  }

  Future<void> _loadFavorites() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final savedUserId = await AuthService.getUserId();
      final userId = int.tryParse(savedUserId ?? '');

      if (userId == null || userId <= 0) {
        throw Exception('Usuário não identificado. Faça login novamente.');
      }

      _userId = userId;

      final uri = Uri.parse(
        '$baseUrl/favorites/addresses.php',
      ).replace(
        queryParameters: {
          'action': 'list',
          'user_id': userId.toString(),
        },
      );

      final response = await http.get(
        uri,
        headers: const {
          'Accept': 'application/json',
        },
      );

      final data = _decodeResponse(response);

      if (data['success'] != true) {
        throw Exception(
          data['message']?.toString() ??
              'Não foi possível carregar seus endereços.',
        );
      }

      final rawFavorites = data['favorites'];

      final loaded = <_FavoriteAddress>[];

      if (rawFavorites is List) {
        for (final item in rawFavorites) {
          if (item is Map) {
            loaded.add(
              _FavoriteAddress.fromMap(
                Map<String, dynamic>.from(item),
              ),
            );
          }
        }
      }

      if (!mounted) return;

      setState(() {
        _favorites
          ..clear()
          ..addAll(loaded);
      });
    } catch (e) {
      if (!mounted) return;
      _showMessage(
        e.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _showAddDialog() async {
    await _showFavoriteEditor();
  }

  Future<void> _showEditDialog(_FavoriteAddress favorite) async {
    await _showFavoriteEditor(existing: favorite);
  }

  Future<void> _showFavoriteEditor({
    _FavoriteAddress? existing,
  }) async {
    final labelController = TextEditingController(
      text: existing?.label ?? '',
    );
    final addressController = TextEditingController(
      text: existing?.address ?? '',
    );

    LatLng? selectedLocation;

    if (existing?.latitude != null && existing?.longitude != null) {
      selectedLocation = LatLng(
        existing!.latitude!,
        existing.longitude!,
      );
    }

    String iconType = existing?.iconType ?? 'place';
    bool searching = false;
    List<_SearchPlace> results = [];

    try {
      final saved = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) {
          return StatefulBuilder(
            builder: (context, setModalState) {
              Future<void> searchAddress() async {
                final query = addressController.text.trim();

                if (query.length < 3) {
                  setModalState(() {
                    results = [];
                    searching = false;
                  });
                  return;
                }

                setModalState(() {
                  searching = true;
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
                      headers: const {
                        'Accept': 'application/json',
                        'User-Agent':
                            'MotoGo/1.0 (app de mobilidade)',
                      },
                    ),
                  );

                  final raw = response.data;
                  final loaded = <_SearchPlace>[];

                  if (raw is List) {
                    for (final item in raw) {
                      if (item is! Map) continue;

                      final lat = double.tryParse(
                        item['lat']?.toString() ?? '',
                      );
                      final lng = double.tryParse(
                        item['lon']?.toString() ?? '',
                      );
                      final name =
                          item['display_name']?.toString() ?? '';

                      if (lat == null ||
                          lng == null ||
                          name.isEmpty) {
                        continue;
                      }

                      loaded.add(
                        _SearchPlace(
                          name: name,
                          location: LatLng(lat, lng),
                        ),
                      );
                    }
                  }

                  setModalState(() {
                    results = loaded;
                    searching = false;
                  });
                } catch (_) {
                  setModalState(() {
                    results = [];
                    searching = false;
                  });

                  if (mounted) {
                    _showMessage(
                      'Não foi possível buscar o endereço.',
                    );
                  }
                }
              }

              return SafeArea(
                child: Container(
                  margin: const EdgeInsets.only(top: 70),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: 20,
                      right: 20,
                      top: 20,
                      bottom:
                          MediaQuery.of(context).viewInsets.bottom + 20,
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Container(
                              width: 45,
                              height: 5,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade300,
                                borderRadius:
                                    BorderRadius.circular(10),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            existing == null
                                ? 'Adicionar endereço'
                                : 'Editar endereço',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Salve um local para encontrar mais rápido na próxima corrida.',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            'Nome do favorito',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: labelController,
                            decoration: InputDecoration(
                              hintText: 'Ex.: Casa, Trabalho, Faculdade',
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              prefixIcon: const Icon(
                                Icons.bookmark_outline,
                              ),
                              border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Tipo',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _typeChip(
                                context,
                                setModalState,
                                label: 'Casa',
                                value: 'home',
                                icon: Icons.home_outlined,
                                selected: iconType == 'home',
                                onSelect: () {
                                  setModalState(() {
                                    iconType = 'home';
                                    if (labelController.text.trim().isEmpty) {
                                      labelController.text = 'Casa';
                                    }
                                  });
                                },
                              ),
                              _typeChip(
                                context,
                                setModalState,
                                label: 'Trabalho',
                                value: 'work',
                                icon: Icons.work_outline,
                                selected: iconType == 'work',
                                onSelect: () {
                                  setModalState(() {
                                    iconType = 'work';
                                    if (labelController.text.trim().isEmpty) {
                                      labelController.text = 'Trabalho';
                                    }
                                  });
                                },
                              ),
                              _typeChip(
                                context,
                                setModalState,
                                label: 'Outro',
                                value: 'place',
                                icon: Icons.place_outlined,
                                selected: iconType == 'place',
                                onSelect: () {
                                  setModalState(() {
                                    iconType = 'place';
                                  });
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Endereço',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: addressController,
                            textInputAction: TextInputAction.search,
                            onSubmitted: (_) => searchAddress(),
                            decoration: InputDecoration(
                              hintText:
                                  'Rua, número, cidade, bairro...',
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              prefixIcon: const Icon(
                                Icons.location_on_outlined,
                              ),
                              suffixIcon: IconButton(
                                tooltip: 'Buscar',
                                onPressed:
                                    searching
                                        ? null
                                        : searchAddress,
                                icon: searching
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child:
                                            CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.search),
                              ),
                              border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (results.isNotEmpty)
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius:
                                    BorderRadius.circular(14),
                                border: Border.all(
                                  color: Colors.grey.shade200,
                                ),
                              ),
                              child: Column(
                                children: results
                                    .map(
                                      (result) => ListTile(
                                        dense: true,
                                        leading: Container(
                                          width: 38,
                                          height: 38,
                                          decoration: BoxDecoration(
                                            color: AppColors.primary
                                                .withOpacity(.08),
                                            borderRadius:
                                                BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.location_on_outlined,
                                            color:
                                                AppColors.primary,
                                          ),
                                        ),
                                        title: Text(
                                          result.name,
                                          maxLines: 2,
                                          overflow:
                                              TextOverflow.ellipsis,
                                        ),
                                        subtitle: const Text(
                                          'Usar este endereço',
                                        ),
                                        onTap: () {
                                          addressController.text =
                                              result.name;
                                          selectedLocation =
                                              result.location;
                                          setModalState(() {
                                            results = [];
                                          });
                                        },
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                          if (selectedLocation != null)
                            Padding(
                              padding: const EdgeInsets.only(
                                top: 10,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 7),
                                  Expanded(
                                    child: Text(
                                      'Localização selecionada com coordenadas.',
                                      style: TextStyle(
                                        color:
                                            Colors.green.shade700,
                                        fontSize: 12,
                                        fontWeight:
                                            FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 22),
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: ElevatedButton(
                              onPressed: _isSaving
                                  ? null
                                  : () async {
                                      final label =
                                          labelController.text.trim();
                                      final address =
                                          addressController.text.trim();

                                      if (label.length < 2) {
                                        _showMessage(
                                          'Informe um nome para o favorito.',
                                        );
                                        return;
                                      }

                                      if (address.length < 3) {
                                        _showMessage(
                                          'Informe um endereço válido.',
                                        );
                                        return;
                                      }

                                      if (selectedLocation == null &&
                                          existing == null) {
                                        _showMessage(
                                          'Pesquise e selecione o endereço para salvar a localização.',
                                        );
                                        return;
                                      }

                                      Navigator.of(sheetContext).pop();

                                      await _saveFavorite(
                                        id: existing?.id,
                                        label: label,
                                        address: address,
                                        latitude:
                                            selectedLocation?.latitude ??
                                                existing?.latitude,
                                        longitude:
                                            selectedLocation?.longitude ??
                                                existing?.longitude,
                                        iconType: iconType,
                                      );
                                    },
                              child: Text(
                                _isSaving
                                    ? 'Salvando...'
                                    : existing == null
                                        ? 'Salvar endereço'
                                        : 'Salvar alterações',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      );

      // O salvamento já atualiza a lista após a confirmação da API.
    } finally {
      labelController.dispose();
      addressController.dispose();
    }
  }

  Widget _typeChip(
    BuildContext context,
    StateSetter setModalState, {
    required String label,
    required String value,
    required IconData icon,
    required bool selected,
    required VoidCallback onSelect,
  }) {
    return ChoiceChip(
      label: Text(label),
      avatar: Icon(
        icon,
        size: 18,
      ),
      selected: selected,
      onSelected: (_) => onSelect(),
      selectedColor: AppColors.primary.withOpacity(.15),
      labelStyle: TextStyle(
        color: selected
            ? AppColors.primary
            : Colors.grey.shade800,
        fontWeight: selected
            ? FontWeight.w700
            : FontWeight.w500,
      ),
    );
  }

  Future<void> _saveFavorite({
    int? id,
    required String label,
    required String address,
    double? latitude,
    double? longitude,
    required String iconType,
  }) async {
    if (_userId == null) return;

    if (!mounted) return;
    setState(() {
      _isSaving = true;
    });

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/favorites/addresses.php'),
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'action': id == null ? 'create' : 'update',
          'user_id': _userId,
          if (id != null) 'id': id,
          'label': label,
          'address': address,
          'latitude': latitude,
          'longitude': longitude,
          'icon_type': iconType,
        }),
      );

      final data = _decodeResponse(response);

      if (data['success'] != true) {
        throw Exception(
          data['message']?.toString() ??
              'Não foi possível salvar o endereço.',
        );
      }

      await _loadFavorites();

      if (mounted) {
        _showMessage(
          id == null
              ? 'Endereço salvo com sucesso.'
              : 'Endereço atualizado com sucesso.',
          success: true,
        );
      }
    } catch (e) {
      if (mounted) {
        _showMessage(
          e.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
      });
    }
  }

  Future<void> _deleteFavorite(
    _FavoriteAddress favorite,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Excluir endereço'),
          content: Text(
            'Deseja excluir "${favorite.label}"?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Excluir'),
            ),
          ],
        );
      },
    );

    if (confirm != true || _userId == null) return;

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/favorites/addresses.php'),
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'action': 'delete',
          'user_id': _userId,
          'id': favorite.id,
        }),
      );

      final data = _decodeResponse(response);

      if (data['success'] != true) {
        throw Exception(
          data['message']?.toString() ??
              'Não foi possível excluir o endereço.',
        );
      }

      await _loadFavorites();

      if (mounted) {
        _showMessage(
          'Endereço excluído.',
          success: true,
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showMessage(
        e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> _useFavorite(
    _FavoriteAddress favorite,
  ) async {
    // Mantemos a ação real pronta para integração com o fluxo de criação
    // de corrida: o endereço e as coordenadas já ficam disponíveis no objeto.
    //
    // Por enquanto, mostramos os dados e copiamos o endereço para a área de
    // interação da tela sem alterar a navegação existente do projeto.
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              20,
              10,
              20,
              24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  favorite.label,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  favorite.address,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _showMessage(
                        'Endereço selecionado: ${favorite.address}',
                        success: true,
                      );
                    },
                    icon: const Icon(
                      Icons.check_circle_outline,
                    ),
                    label: const Text(
                      'Usar este endereço',
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Map<String, dynamic> _decodeResponse(
    http.Response response,
  ) {
    try {
      final decoded = jsonDecode(response.body);

      if (decoded is Map<String, dynamic>) {
        if (response.statusCode >= 200 &&
            response.statusCode < 300) {
          return decoded;
        }

        return {
          'success': false,
          'message':
              decoded['message'] ?? 'Erro na API.',
          ...decoded,
        };
      }

      return {
        'success': false,
        'message': 'Resposta inválida da API.',
      };
    } catch (_) {
      return {
        'success': false,
        'message': 'Resposta inválida da API.',
      };
    }
  }

  void _showMessage(
    String message, {
    bool success = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor:
            success ? Colors.green.shade700 : null,
      ),
    );
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'home':
        return Icons.home;
      case 'work':
        return Icons.work;
      default:
        return Icons.place;
    }
  }

  Color _colorFor(String type) {
    switch (type) {
      case 'home':
        return Colors.green;
      case 'work':
        return Colors.blue;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const CustomAppBar(
        title: 'Favoritos',
      ),
      body: RefreshIndicator(
        onRefresh: _loadFavorites,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            20,
            20,
            20,
            28,
          ),
          children: [
            const Text(
              'Endereços Favoritos',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Salve seus locais mais utilizados.',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 24),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(
                  vertical: 60,
                ),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_favorites.isEmpty)
              _buildEmpty()
            else
              ..._favorites.map(
                (favorite) => Padding(
                  padding: const EdgeInsets.only(
                    bottom: 14,
                  ),
                  child: _buildFavoriteCard(favorite),
                ),
              ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 58,
              child: ElevatedButton.icon(
                onPressed:
                    _isSaving ? null : _showAddDialog,
                icon: const Icon(
                  Icons.add_location_alt,
                ),
                label: const Text(
                  'Adicionar Endereço',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 15),
      padding: const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 34,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(.10),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.location_on_outlined,
              color: AppColors.primary,
              size: 32,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Nenhum endereço salvo',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            'Adicione Casa, Trabalho ou outro local para usar novamente nas próximas corridas.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade600,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFavoriteCard(
    _FavoriteAddress favorite,
  ) {
    final color = _colorFor(favorite.iconType);

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () => _useFavorite(favorite),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.05),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: CircleAvatar(
            radius: 28,
            backgroundColor: color.withOpacity(.15),
            child: Icon(
              _iconFor(favorite.iconType),
              color: color,
              size: 28,
            ),
          ),
          title: Text(
            favorite.label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              favorite.address,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.grey.shade600,
              ),
            ),
          ),
          trailing: PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') {
                _showEditDialog(favorite);
              } else if (value == 'delete') {
                _deleteFavorite(favorite);
              } else if (value == 'use') {
                _useFavorite(favorite);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'use',
                child: Text('Usar este endereço'),
              ),
              PopupMenuItem(
                value: 'edit',
                child: Text('Editar'),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Text('Excluir'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchPlace {
  final String name;
  final LatLng location;

  const _SearchPlace({
    required this.name,
    required this.location,
  });
}
