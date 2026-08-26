import 'package:flutter/material.dart';
import 'admin_vehicles_screen.dart';
import '../../services/api_service.dart';
import 'drivers/admin_drivers_screen.dart';
import 'admin_rides_screen.dart';
import 'admin_users_screen.dart';
import 'admin_settings_screen.dart';
import '../../services/auth_service.dart';
class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({
    super.key,
  });

  @override
  State<AdminHomeScreen> createState() =>
      _AdminHomeScreenState();
}

class _AdminHomeScreenState
    extends State<AdminHomeScreen> {

  // ============================================================
  // CONFIGURAÇÃO
  // ============================================================

  int _selectedIndex = 0;

  final Color primaryColor =
      const Color(0xFF00C985);

  final Color darkColor =
      const Color(0xFF17212B);

  // ============================================================
  // DASHBOARD REAL
  // ============================================================

  bool _isLoading = true;

  bool _apiOnline = false;

  String? _errorMessage;

  DateTime? _lastUpdate;

  Map<String, dynamic> _stats = {};

  Map<String, dynamic> _rideStatus = {};

  List<dynamic> _pendingVehicles = [];

  List<dynamic> _pendingDrivers = [];

  List<dynamic> _recentRides = [];

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _loadDashboard();
  }

  // ============================================================
  // CARREGAR DASHBOARD
  // ============================================================

  Future<void> _loadDashboard({
    bool showLoader = true,
  }) async {

    if (showLoader) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {

      final result =
          await ApiService.getAdminDashboard();

      if (!mounted) {
        return;
      }

      if (result['success'] == true) {

        setState(() {

          _stats =
              _asMap(
            result['stats'],
          );

          _rideStatus =
              _asMap(
            result['ride_status'],
          );

          _pendingVehicles =
              _asList(
            result['pending_vehicles_list'],
          );

          _pendingDrivers =
              _asList(
            result['pending_drivers_list'],
          );

          _recentRides =
              _asList(
            result['recent_rides'],
          );

          _isLoading = false;

          _apiOnline = true;

          _errorMessage = null;

          _lastUpdate =
              DateTime.now();
        });

      } else {

        setState(() {

          _isLoading = false;

          _apiOnline = false;

          _errorMessage =
              result['message']?.toString() ??
                  'Não foi possível carregar o dashboard.';
        });
      }

    } catch (e) {

      if (!mounted) {
        return;
      }

      setState(() {

        _isLoading = false;

        _apiOnline = false;

        _errorMessage =
            'Não foi possível conectar ao servidor.';
      });
    }
  }

  // ============================================================
  // CONVERTER MAP
  // ============================================================

  Map<String, dynamic> _asMap(
    dynamic value,
  ) {

    if (value is Map) {

      return Map<String, dynamic>.from(
        value,
      );
    }

    return {};
  }

  // ============================================================
  // CONVERTER LISTA
  // ============================================================

  List<dynamic> _asList(
    dynamic value,
  ) {

    if (value is List) {
      return List<dynamic>.from(
        value,
      );
    }

    return [];
  }

  // ============================================================
  // INT
  // ============================================================

  int _intValue(
    dynamic value,
  ) {

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }

  // ============================================================
  // DOUBLE
  // ============================================================

  double _doubleValue(
    dynamic value,
  ) {

    if (value is double) {
      return value;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }

  // ============================================================
  // FORMATA DINHEIRO
  // ============================================================

  String _money(
    dynamic value,
  ) {

    final number =
        _doubleValue(value);

    return 'R\$ ${number.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  // ============================================================
  // HORA DA ATUALIZAÇÃO
  // ============================================================

  String _lastUpdateText() {

    if (_lastUpdate == null) {
      return 'Ainda não atualizado';
    }

    final hour =
        _lastUpdate!.hour
            .toString()
            .padLeft(2, '0');

    final minute =
        _lastUpdate!.minute
            .toString()
            .padLeft(2, '0');

    return 'Atualizado às $hour:$minute';
  }

// ============================================================ 

// MENSAGEM 

// ============================================================ 

void _showMessage(String message) { 

  if (!mounted) return; 

  ScaffoldMessenger.of(context) 

    ..hideCurrentSnackBar() 

    ..showSnackBar( 

      SnackBar( 

        content: Text(message), 

        behavior: SnackBarBehavior.floating, 

      ), 

    ); 

} 

// ============================================================ 

// LOGOUT 

// ============================================================ 

Future<void> _logout() async { 

  if (!mounted) return; 

  // Limpa a sessão usando o AuthService, se disponível. 

  try { 

    final prefs = await AuthService.getPrefs(); 

    await prefs.remove('user_id'); 

    await prefs.remove('account_type'); 

    await prefs.remove('verification_status'); 

    await prefs.remove('token'); 

  } catch (_) { 

    // Se não houver sessão para limpar, 

    // continua para a tela de login. 

  } 

  if (!mounted) return; 

  Navigator.of(context).pushNamedAndRemoveUntil( 

    '/login', 

    (route) => false, 

  ); 

}

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {

    return Scaffold(
      backgroundColor:
          const Color(0xFFF5F7F6),

      body: SafeArea(
        child: LayoutBuilder(
          builder: (
            context,
            constraints,
          ) {

            final bool desktop =
                constraints.maxWidth >= 900;

            if (desktop) {

              return _buildDesktopLayout();
            }

            return _buildMobileLayout();
          },
        ),
      ),
    );
  }

  // ============================================================
  // DESKTOP
  // ============================================================

  Widget _buildDesktopLayout() {

    return Row(
      children: [

        _buildSidebar(),

        Expanded(
          child:
              _buildDashboardContent(),
        ),
      ],
    );
  }

  // ============================================================
  // MOBILE
  // ============================================================

  Widget _buildMobileLayout() {

    return Column(
      children: [

        _buildMobileHeader(),

        Expanded(
          child:
              _buildDashboardContent(),
        ),

        _buildMobileNavigation(),
      ],
    );
  }

  // ============================================================
  // SIDEBAR
  // ============================================================

  Widget _buildSidebar() {

    final int pendingDrivers =
        _intValue(
      _stats['pending_drivers'],
    );

    final int pendingVehicles =
        _intValue(
      _stats['pending_vehicles'],
    );

    return Container(
      width: 255,

      decoration:
          BoxDecoration(
        color: darkColor,

        boxShadow: [
          BoxShadow(
            color:
                Colors.black
                    .withOpacity(.08),

            blurRadius: 20,

            offset:
                const Offset(
              2,
              0,
            ),
          ),
        ],
      ),

      child: Column(
        children: [

          const SizedBox(
            height: 25,
          ),

          // ======================================================
          // LOGO
          // ======================================================

          Padding(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 22,
            ),

            child: Row(
              children: [

                Container(
                  width: 46,
                  height: 46,

                  decoration:
                      BoxDecoration(
                    color:
                        primaryColor,

                    borderRadius:
                        BorderRadius.circular(
                      14,
                    ),
                  ),

                  child:
                      const Icon(
                    Icons.two_wheeler,
                    color:
                        Colors.white,
                    size: 27,
                  ),
                ),

                const SizedBox(
                  width: 12,
                ),

                const Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,

                  children: [

                    Text(
                      'MotoGo',

                      style:
                          TextStyle(
                        color:
                            Colors.white,

                        fontSize:
                            20,

                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    Text(
                      'ADMIN',

                      style:
                          TextStyle(
                        color:
                            Color(
                          0xFF9AA7B2,
                        ),

                        fontSize:
                            10,

                        fontWeight:
                            FontWeight.w600,

                        letterSpacing:
                            1.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(
            height: 35,
          ),

          // ======================================================
          // MENU
          // ======================================================

          _sidebarItem(
            icon:
                Icons.dashboard_outlined,

            title:
                'Dashboard',

            index:
                0,
          ),

          _sidebarItem(
            icon:
                Icons.people_outline,

            title:
                'Motoristas',

            index:
                1,

            badge:
                pendingDrivers > 0
                    ? pendingDrivers
                        .toString()
                    : null,
          ),

          _sidebarItem(
            icon:
                Icons.directions_car_outlined,

            title:
                'Veículos',

            index:
                2,

            badge:
                pendingVehicles > 0
                    ? pendingVehicles
                        .toString()
                    : null,
          ),

          _sidebarItem(
            icon:
                Icons.local_taxi_outlined,

            title:
                'Corridas',

            index:
                3,
          ),

          _sidebarItem(
            icon:
                Icons.person_outline,

            title:
                'Usuários',

            index:
                4,
          ),

          _sidebarItem(
            icon:
                Icons.payments_outlined,

            title:
                'Pagamentos',

            index:
                5,

            badge:
                _intValue(_stats['pending_payments']) > 0
                    ? _intValue(_stats['pending_payments']).toString()
                    : null,
          ),

          const Spacer(),

          _sidebarItem(
            icon:
                Icons.settings_outlined,

            title:
                'Configurações',

            index:
                6,
          ),

          _sidebarItem(
            icon:
                Icons.logout,

            title:
                'Sair',

            index:
                7,

            danger:
                true,
          ),

          const SizedBox(
            height: 20,
          ),

          Padding(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 20,
            ),

            child: Text(
              'MotoGo Admin • v1.0',

              style:
                  TextStyle(
                color:
                    Colors.white
                        .withOpacity(.35),

                fontSize:
                    11,
              ),
            ),
          ),

          const SizedBox(
            height: 20,
          ),
        ],
      ),
    );
  }

// ============================================================
// ITEM SIDEBAR
// ============================================================

Widget _sidebarItem({
  required IconData icon,
  required String title,
  required int index,
  String? badge,
  bool danger = false,
}) {
  final bool selected =
      _selectedIndex == index;

  return Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: 12,
      vertical: 3,
    ),

    child: InkWell(
      borderRadius:
          BorderRadius.circular(12),

      onTap: () {

        // ======================================================
        // ATUALIZAR ITEM SELECIONADO
        // ======================================================

        setState(() {
          _selectedIndex = index;
        });

        // ======================================================
        // DASHBOARD
        // ======================================================

        if (index == 0) {
          _loadDashboard(
            showLoader: false,
          );

          return;
        }

        // ======================================================
        // MOTORISTAS
        // ======================================================

        if (index == 1) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  const AdminDriversScreen(),
            ),
          );

          return;
        }

        // ======================================================
        // VEÍCULOS
        // ======================================================

        if (index == 2) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  const AdminVehiclesScreen(),
            ),
          );

          return;
        }

        // ======================================================
        // OUTRAS SEÇÕES
        // ======================================================

        if (index == 3) {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminRidesScreen()));
          return;
        }

        if (index == 4) {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminUsersScreen()));
          return;
        }

        if (index == 5) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  const AdminPaymentsScreen(),
            ),
          );

          return;
        }

        if (index == 6) {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminSettingsScreen()));
          return;
        }

        // ======================================================
        // SAIR
        // ======================================================

        if (index == 7) {
          _logout();

          return;
        }
      },

      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 13,
        ),

        decoration: BoxDecoration(
          color: selected
              ? primaryColor.withOpacity(.14)
              : Colors.transparent,

          borderRadius:
              BorderRadius.circular(12),
        ),

        child: Row(
          children: [

            // ==================================================
            // ÍCONE
            // ==================================================

            Icon(
              icon,
              size: 21,

              color: danger
                  ? Colors.redAccent
                  : selected
                      ? primaryColor
                      : Colors.white70,
            ),

            const SizedBox(
              width: 13,
            ),

            // ==================================================
            // TÍTULO
            // ==================================================

            Expanded(
              child: Text(
                title,

                style: TextStyle(
                  color: danger
                      ? Colors.redAccent
                      : selected
                          ? Colors.white
                          : Colors.white70,

                  fontSize: 14,

                  fontWeight: selected
                      ? FontWeight.w600
                      : FontWeight.w400,
                ),
              ),
            ),

            // ==================================================
            // BADGE
            // ==================================================

            if (badge != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 3,
                ),

                decoration:
                    BoxDecoration(
                  color: primaryColor,

                  borderRadius:
                      BorderRadius.circular(20),
                ),

                child: Text(
                  badge,

                  style:
                      const TextStyle(
                    color: Colors.white,

                    fontSize: 10,

                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
  // ============================================================
  // HEADER MOBILE
  // ============================================================

  Widget _buildMobileHeader() {

    return Container(
      height: 70,

      padding:
          const EdgeInsets.symmetric(
        horizontal: 18,
      ),

      decoration:
          const BoxDecoration(
        color:
            Colors.white,
      ),

      child: Row(
        children: [

          Container(
            width: 42,
            height: 42,

            decoration:
                BoxDecoration(
              color:
                  primaryColor,

              borderRadius:
                  BorderRadius.circular(
                12,
              ),
            ),

            child:
                const Icon(
              Icons.two_wheeler,
              color:
                  Colors.white,
            ),
          ),

          const SizedBox(
            width: 12,
          ),

          const Column(
            mainAxisAlignment:
                MainAxisAlignment.center,

            crossAxisAlignment:
                CrossAxisAlignment.start,

            children: [

              Text(
                'MotoGo',

                style:
                    TextStyle(
                  fontSize:
                      18,

                  fontWeight:
                      FontWeight.bold,
                ),
              ),

              Text(
                'Painel administrativo',

                style:
                    TextStyle(
                  fontSize:
                      11,

                  color:
                      Colors.grey,
                ),
              ),
            ],
          ),

          const Spacer(),

          IconButton(
            onPressed:
                _isLoading
                    ? null
                    : () {
                        _loadDashboard();
                      },

            icon:
                _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child:
                            CircularProgressIndicator(
                          strokeWidth:
                              2,
                        ),
                      )
                    : const Icon(
                        Icons.refresh,
                      ),
          ),

          const CircleAvatar(
            radius: 20,

            backgroundColor:
                Color(0xFFE2F8F0),

            child:
                Icon(
              Icons.person,

              color:
                  Color(0xFF00C985),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DASHBOARD
  // ============================================================

  Widget _buildDashboardContent() {

    return RefreshIndicator(
      color:
          primaryColor,

      onRefresh: () {
        return _loadDashboard(
          showLoader: false,
        );
      },

      child: SingleChildScrollView(
        physics:
            const AlwaysScrollableScrollPhysics(),

        padding:
            const EdgeInsets.all(24),

        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,

          children: [

            _buildTopHeader(),

            const SizedBox(
              height: 28,
            ),

            if (_isLoading &&
                _stats.isEmpty)
              _buildInitialLoading(),

            if (_errorMessage != null &&
                _stats.isEmpty)
              _buildErrorCard(),

            if (_stats.isNotEmpty) ...[

              _buildStats(),

              const SizedBox(
                height: 28,
              ),

              _buildMainSections(),
            ],
          ],
        ),
      ),
    );
  }

  // ============================================================
  // LOADING INICIAL
  // ============================================================

  Widget _buildInitialLoading() {

    return Container(
      width:
          double.infinity,

      padding:
          const EdgeInsets.all(35),

      decoration:
          BoxDecoration(
        color:
            Colors.white,

        borderRadius:
            BorderRadius.circular(
          18,
        ),
      ),

      child: Column(
        children: [

          CircularProgressIndicator(
            color:
                primaryColor,
          ),

          const SizedBox(
            height: 15,
          ),

          const Text(
            'Carregando dados do MotoGo...',
            style:
                TextStyle(
              fontSize:
                  14,

              fontWeight:
                  FontWeight.w600,
            ),
          ),

          const SizedBox(
            height: 5,
          ),

          Text(
            'Consultando o servidor.',
            style:
                TextStyle(
              fontSize:
                  12,

              color:
                  Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ERRO
  // ============================================================

  Widget _buildErrorCard() {

    return Container(
      width:
          double.infinity,

      padding:
          const EdgeInsets.all(
        20,
      ),

      decoration:
          BoxDecoration(
        color:
            Colors.white,

        borderRadius:
            BorderRadius.circular(
          18,
        ),

        border:
            Border.all(
          color:
              Colors.red.withOpacity(.15),
        ),
      ),

      child: Row(
        children: [

          Container(
            width: 44,
            height: 44,

            decoration:
                BoxDecoration(
              color:
                  Colors.red.withOpacity(.10),

              shape:
                  BoxShape.circle,
            ),

            child:
                const Icon(
              Icons.cloud_off_outlined,

              color:
                  Colors.red,
            ),
          ),

          const SizedBox(
            width: 13,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [

                const Text(
                  'Não foi possível carregar o dashboard.',

                  style:
                      TextStyle(
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                const SizedBox(
                  height: 4,
                ),

                Text(
                  _errorMessage ??
                      'Erro desconhecido.',

                  style:
                      TextStyle(
                    fontSize:
                        12,

                    color:
                        Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(
            width: 10,
          ),

          TextButton(
            onPressed: () {
              _loadDashboard();
            },

            child:
                const Text(
              'Tentar novamente',
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TOP HEADER
  // ============================================================

  Widget _buildTopHeader() {

    return Row(
      children: [

        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,

            children: [

              const Text(
                'Dashboard',

                style:
                    TextStyle(
                  fontSize:
                      28,

                  fontWeight:
                      FontWeight.bold,

                  color:
                      Color(0xFF17212B),
                ),
              ),

              const SizedBox(
                height: 5,
              ),

              Text(
                'Visão geral do MotoGo',

                style:
                    TextStyle(
                  fontSize:
                      14,

                  color:
                      Colors.grey.shade600,
                ),
              ),

              const SizedBox(
                height: 4,
              ),

              Text(
                _lastUpdateText(),

                style:
                    TextStyle(
                  fontSize:
                      11,

                  color:
                      Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),

        // ========================================================
        // STATUS API
        // ========================================================

        Container(
          padding:
              const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 9,
          ),

          decoration:
              BoxDecoration(
            color:
                Colors.white,

            borderRadius:
                BorderRadius.circular(
              12,
            ),
          ),

          child: Row(
            children: [

              Container(
                width: 8,
                height: 8,

                decoration:
                    BoxDecoration(
                  color:
                      _apiOnline
                          ? primaryColor
                          : Colors.orange,

                  shape:
                      BoxShape.circle,
                ),
              ),

              const SizedBox(
                width: 8,
              ),

              Text(
                _apiOnline
                    ? 'Sistema online'
                    : 'Conectando...',

                style:
                    const TextStyle(
                  fontSize:
                      12,

                  fontWeight:
                      FontWeight.w600,
                ),
              ),

              const SizedBox(
                width: 8,
              ),

              InkWell(
                onTap:
                    _isLoading
                        ? null
                        : () {
                            _loadDashboard();
                          },

                borderRadius:
                    BorderRadius.circular(
                  20,
                ),

                child: Padding(
                  padding:
                      const EdgeInsets.all(
                    3,
                  ),

                  child: Icon(
                    Icons.refresh,

                    size: 16,

                    color:
                        primaryColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // ESTATÍSTICAS
  // ============================================================

  Widget _buildStats() {

    return LayoutBuilder(
      builder: (
        context,
        constraints,
      ) {

        final int columns =
            constraints.maxWidth >= 1100
                ? 4
                : constraints.maxWidth >= 650
                    ? 2
                    : 1;

        final double width =
            (constraints.maxWidth -
                    ((columns - 1) * 14)) /
                columns;

        final int drivers =
            _intValue(
          _stats['drivers'],
        );

        final int pendingDrivers =
            _intValue(
          _stats['pending_drivers'],
        );

        final int ridesToday =
            _intValue(
          _stats['rides_today'],
        );

        final int vehicles =
            _intValue(
          _stats['vehicles'],
        );

        final int pendingVehicles =
            _intValue(
          _stats['pending_vehicles'],
        );

        final double revenueToday =
            _doubleValue(
          _stats['revenue_today'],
        );

        return Wrap(
          spacing: 14,
          runSpacing: 14,

          children: [

            // ==================================================
            // MOTORISTAS
            // ==================================================

            SizedBox(
              width: width,

              child: _statCard(
                icon:
                    Icons.people_outline,

                title:
                    'Motoristas',

                value:
                    drivers.toString(),

                subtitle:
                    '$pendingDrivers pendentes',

                iconColor:
                    const Color(
                  0xFF4F7CFF,
                ),
              ),
            ),

            // ==================================================
            // CORRIDAS
            // ==================================================

            SizedBox(
              width: width,

              child: _statCard(
                icon:
                    Icons.local_taxi_outlined,

                title:
                    'Corridas hoje',

                value:
                    ridesToday.toString(),

                subtitle:
                    'Dados reais do servidor',

                iconColor:
                    primaryColor,
              ),
            ),

            // ==================================================
            // VEÍCULOS
            // ==================================================

            SizedBox(
              width: width,

              child: _statCard(
                icon:
                    Icons.directions_car_outlined,

                title:
                    'Veículos',

                value:
                    vehicles.toString(),

                subtitle:
                    '$pendingVehicles pendentes',

                iconColor:
                    const Color(
                  0xFFFFA726,
                ),
              ),
            ),

            // ==================================================
            // RECEITA
            // ==================================================

            SizedBox(
              width: width,

              child: _statCard(
                icon:
                    Icons.account_balance_wallet_outlined,

                title:
                    'Receita hoje',

                value:
                    _money(
                  revenueToday,
                ),

                subtitle:
                    'Corridas concluídas',

                iconColor:
                    const Color(
                  0xFF8E5CFF,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // CARD ESTATÍSTICA
  // ============================================================

  Widget _statCard({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    required Color iconColor,
  }) {

    return Container(
      padding:
          const EdgeInsets.all(
        20,
      ),

      decoration:
          BoxDecoration(
        color:
            Colors.white,

        borderRadius:
            BorderRadius.circular(
          18,
        ),

        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withOpacity(
              .025,
            ),

            blurRadius:
                15,

            offset:
                const Offset(
              0,
              5,
            ),
          ),
        ],
      ),

      child: Row(
        children: [

          Container(
            width: 48,
            height: 48,

            decoration:
                BoxDecoration(
              color:
                  iconColor.withOpacity(
                .10,
              ),

              borderRadius:
                  BorderRadius.circular(
                14,
              ),
            ),

            child:
                Icon(
              icon,

              color:
                  iconColor,

              size: 24,
            ),
          ),

          const SizedBox(
            width: 14,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [

                Text(
                  title,

                  style:
                      TextStyle(
                    fontSize:
                        12,

                    color:
                        Colors.grey.shade600,
                  ),
                ),

                const SizedBox(
                  height: 4,
                ),

                Text(
                  value,

                  style:
                      const TextStyle(
                    fontSize:
                        22,

                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                const SizedBox(
                  height: 3,
                ),

                Text(
                  subtitle,

                  style:
                      TextStyle(
                    fontSize:
                        11,

                    color:
                        Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SEÇÕES PRINCIPAIS
  // ============================================================

  Widget _buildMainSections() {

    return LayoutBuilder(
      builder: (
        context,
        constraints,
      ) {

        final bool wide =
            constraints.maxWidth >= 900;

        if (wide) {

          return Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,

            children: [

              Expanded(
                flex: 3,

                child:
                    _buildPendingVehicles(),
              ),

              const SizedBox(
                width: 18,
              ),

              Expanded(
                flex: 2,

                child:
                    _buildRideStatus(),
              ),
            ],
          );
        }

        return Column(
          children: [

            _buildPendingVehicles(),

            const SizedBox(
              height: 18,
            ),

            _buildRideStatus(),
          ],
        );
      },
    );
  }

  // ============================================================
  // VEÍCULOS PENDENTES
  // ============================================================

  Widget _buildPendingVehicles() {

    return _sectionCard(
      title:
          'Veículos pendentes',

      icon:
          Icons.directions_car_outlined,

      action:
          'Atualizar',

      onAction: () {
        _loadDashboard(
          showLoader: false,
        );
      },

      child:
          _pendingVehicles.isEmpty
              ? _buildEmptyState(
                  icon:
                      Icons.verified_outlined,

                  title:
                      'Nenhum veículo pendente',

                  subtitle:
                      'Não existem veículos aguardando aprovação.',
                )
              : Column(
                  children: [

                    for (
                      int i = 0;
                      i < _pendingVehicles.length;
                      i++
                    ) ...[

                      _buildRealVehicleItem(
                        _pendingVehicles[i],
                      ),

                      if (
                        i <
                            _pendingVehicles.length -
                                1
                      )
                        const Divider(
                          height: 1,
                        ),
                    ],

                    const SizedBox(
                      height: 15,
                    ),

                    Container(
                      width:
                          double.infinity,

                      padding:
                          const EdgeInsets.all(
                        13,
                      ),

                      decoration:
                          BoxDecoration(
                        color:
                            primaryColor
                                .withOpacity(
                          .07,
                        ),

                        borderRadius:
                            BorderRadius.circular(
                          12,
                        ),
                      ),

                      child: Row(
                        children: [

                          Icon(
                            Icons.info_outline,

                            size:
                                18,

                            color:
                                primaryColor,
                          ),

                          const SizedBox(
                            width: 8,
                          ),

                          Expanded(
                            child: Text(
                              '${_pendingVehicles.length} veículo(s) aguardando aprovação.',

                              style:
                                  TextStyle(
                                fontSize:
                                    12,

                                color:
                                    Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  // ============================================================
  // ITEM VEÍCULO REAL
  // ============================================================

  Widget _buildRealVehicleItem(
    dynamic rawVehicle,
  ) {

    final vehicle =
        _asMap(
      rawVehicle,
    );

    final String type =
        vehicle['vehicle_type']
                ?.toString() ??
            'moto';

    final String brand =
        vehicle['brand']
                ?.toString() ??
            '';

    final String model =
        vehicle['model']
                ?.toString() ??
            '';

    final String color =
        vehicle['color']
                ?.toString() ??
            'Cor não informada';

    final String plate =
        vehicle['plate']
                ?.toString() ??
            'Sem placa';

    final String year =
        vehicle['year']
                ?.toString() ??
            '';

    final dynamic driverId =
        vehicle['driver_id'];

    final String driverName =
        vehicle['driver_name']
                ?.toString() ??
            (driverId != null
                ? 'Motorista #$driverId'
                : 'Motorista não informado');

    final String vehicleName =
        '$brand $model'.trim().isEmpty
            ? 'Veículo não informado'
            : '$brand $model';

    final String details =
        '${_vehicleTypeName(type)} • '
        '$color • '
        '$plate'
        '${year.isNotEmpty ? ' • $year' : ''}';

    return _vehicleItem(
      driver:
          driverName,

      vehicle:
          vehicleName,

      details:
          details,

      vehicleType:
          type,
    );
  }

  // ============================================================
  // ITEM VEÍCULO
  // ============================================================

  Widget _vehicleItem({
    required String driver,
    required String vehicle,
    required String details,
    required String vehicleType,
  }) {

    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 15,
      ),

      child: Row(
        children: [

          Container(
            width: 46,
            height: 46,

            decoration:
                BoxDecoration(
              color:
                  const Color(
                0xFFE5F9F2,
              ),

              borderRadius:
                  BorderRadius.circular(
                13,
              ),
            ),

            child:
                Icon(
              _vehicleIcon(
                vehicleType,
              ),

              color:
                  primaryColor,
            ),
          ),

          const SizedBox(
            width: 12,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [

                Text(
                  vehicle,

                  style:
                      const TextStyle(
                    fontSize:
                        14,

                    fontWeight:
                        FontWeight.w600,
                  ),
                ),

                const SizedBox(
                  height: 3,
                ),

                Text(
                  driver,

                  style:
                      TextStyle(
                    fontSize:
                        12,

                    color:
                        Colors.grey.shade700,
                  ),
                ),

                const SizedBox(
                  height: 3,
                ),

                Text(
                  details,

                  style:
                      TextStyle(
                    fontSize:
                        11,

                    color:
                        Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),

          Container(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 9,
              vertical: 5,
            ),

            decoration:
                BoxDecoration(
              color:
                  const Color(
                0xFFFFF4D8,
              ),

              borderRadius:
                  BorderRadius.circular(
                20,
              ),
            ),

            child:
                const Text(
              'Pendente',

              style:
                  TextStyle(
                color:
                    Color(
                  0xFFB77900,
                ),

                fontSize:
                    10,

                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TIPO VEÍCULO
  // ============================================================

  String _vehicleTypeName(
    String type,
  ) {

    switch (type) {

      case 'carro':
        return 'Carro';

      case 'bicicleta':
        return 'Bicicleta';

      case 'moto':
      default:
        return 'Moto';
    }
  }

  // ============================================================
  // ÍCONE VEÍCULO
  // ============================================================

  IconData _vehicleIcon(
    String type,
  ) {

    switch (type) {

      case 'carro':
        return Icons.directions_car;

      case 'bicicleta':
        return Icons.pedal_bike;

      case 'moto':
      default:
        return Icons.two_wheeler;
    }
  }

  // ============================================================
  // STATUS DAS CORRIDAS
  // ============================================================

  Widget _buildRideStatus() {

    final int pending =
        _intValue(
      _rideStatus['pending'],
    );

    final int searching =
        _intValue(
      _rideStatus['searching'],
    );

    final int driverFound =
        _intValue(
      _rideStatus['driver_found'],
    );

    final int driverArriving =
        _intValue(
      _rideStatus['driver_arriving'],
    );

    final int driverArrived =
        _intValue(
      _rideStatus['driver_arrived'],
    );

    final int inProgress =
        _intValue(
      _rideStatus['in_progress'],
    );

    final int completed =
        _intValue(
      _rideStatus['completed'],
    );

    final int cancelled =
        _intValue(
      _rideStatus['cancelled'],
    );

    final int lookingForDriver =
        pending +
            searching;

    final int activeRides =
        driverFound +
            driverArriving +
            driverArrived +
            inProgress;

    return _sectionCard(
      title:
          'Corridas agora',

      icon:
          Icons.local_taxi_outlined,

      action:
          'Atualizar',

      onAction: () {
        _loadDashboard(
          showLoader: false,
        );
      },

      child:
          Column(
        children: [

          _rideStatusItem(
            title:
                'Em andamento',

            value:
                activeRides.toString(),

            color:
                primaryColor,

            icon:
                Icons.directions_car,
          ),

          _rideStatusItem(
            title:
                'Procurando motorista',

            value:
                lookingForDriver.toString(),

            color:
                const Color(
              0xFFFFA726,
            ),

            icon:
                Icons.search,
          ),

          _rideStatusItem(
            title:
                'Finalizadas',

            value:
                completed.toString(),

            color:
                const Color(
              0xFF4F7CFF,
            ),

            icon:
                Icons.check_circle_outline,
          ),

          _rideStatusItem(
            title:
                'Canceladas',

            value:
                cancelled.toString(),

            color:
                Colors.redAccent,

            icon:
                Icons.cancel_outlined,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ITEM STATUS
  // ============================================================

  Widget _rideStatusItem({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
  }) {

    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 10,
      ),

      child: Row(
        children: [

          Container(
            width: 40,
            height: 40,

            decoration:
                BoxDecoration(
              color:
                  color.withOpacity(
                .10,
              ),

              borderRadius:
                  BorderRadius.circular(
                11,
              ),
            ),

            child:
                Icon(
              icon,

              size:
                  20,

              color:
                  color,
            ),
          ),

          const SizedBox(
            width: 12,
          ),

          Expanded(
            child: Text(
              title,

              style:
                  const TextStyle(
                fontSize:
                    13,
              ),
            ),
          ),

          Text(
            value,

            style:
                const TextStyle(
              fontSize:
                  17,

              fontWeight:
                  FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ESTADO VAZIO
  // ============================================================

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {

    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 25,
      ),

      child: Column(
        children: [

          Container(
            width: 52,
            height: 52,

            decoration:
                BoxDecoration(
              color:
                  primaryColor
                      .withOpacity(
                .10,
              ),

              shape:
                  BoxShape.circle,
            ),

            child:
                Icon(
              icon,

              color:
                  primaryColor,

              size:
                  27,
            ),
          ),

          const SizedBox(
            height: 12,
          ),

          Text(
            title,

            style:
                const TextStyle(
              fontWeight:
                  FontWeight.w600,
            ),
          ),

          const SizedBox(
            height: 5,
          ),

          Text(
            subtitle,

            textAlign:
                TextAlign.center,

            style:
                TextStyle(
              fontSize:
                  12,

              color:
                  Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CARD DE SEÇÃO
  // ============================================================

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required String action,
    required Widget child,
    VoidCallback? onAction,
  }) {

    return Container(
      padding:
          const EdgeInsets.all(
        20,
      ),

      decoration:
          BoxDecoration(
        color:
            Colors.white,

        borderRadius:
            BorderRadius.circular(
          18,
        ),

        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withOpacity(
              .025,
            ),

            blurRadius:
                15,

            offset:
                const Offset(
              0,
              5,
            ),
          ),
        ],
      ),

      child: Column(
        children: [

          Row(
            children: [

              Container(
                width: 38,
                height: 38,

                decoration:
                    BoxDecoration(
                  color:
                      primaryColor
                          .withOpacity(
                    .10,
                  ),

                  borderRadius:
                      BorderRadius.circular(
                    11,
                  ),
                ),

                child:
                    Icon(
                  icon,

                  color:
                      primaryColor,

                  size:
                      20,
                ),
              ),

              const SizedBox(
                width: 11,
              ),

              Expanded(
                child: Text(
                  title,

                  style:
                      const TextStyle(
                    fontSize:
                        16,

                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),

              TextButton(
                onPressed:
                    onAction,

                child:
                    Text(
                  action,

                  style:
                      TextStyle(
                    color:
                        primaryColor,

                    fontSize:
                        12,

                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 10,
          ),

          child,
        ],
      ),
    );
  }

  // ============================================================
  // NAVEGAÇÃO MOBILE
  // ============================================================

  Widget _buildMobileNavigation() {

    return Container(
      height: 68,

      decoration:
          const BoxDecoration(
        color:
            Colors.white,

        border:
            Border(
          top:
              BorderSide(
            color:
                Color(
              0xFFE8ECEA,
            ),
          ),
        ),
      ),

      child: Row(
        mainAxisAlignment:
            MainAxisAlignment.spaceAround,

        children: [

          _mobileNavItem(
            icon:
                Icons.dashboard_outlined,

            title:
                'Início',

            index:
                0,
          ),

          _mobileNavItem(
            icon:
                Icons.people_outline,

            title:
                'Motoristas',

            index:
                1,
          ),

          _mobileNavItem(
            icon:
                Icons.directions_car_outlined,

            title:
                'Veículos',

            index:
                2,
          ),

          _mobileNavItem(
            icon:
                Icons.local_taxi_outlined,

            title:
                'Corridas',

            index:
                3,
          ),

          _mobileNavItem(
            icon:
                Icons.payments_outlined,

            title:
                'Pagamentos',

            index:
                5,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ITEM MOBILE
  // ============================================================

  Widget _mobileNavItem({
    required IconData icon,
    required String title,
    required int index,
  }) {

    final bool selected =
        _selectedIndex == index;

    return InkWell(
      onTap: () {

        setState(() {
          _selectedIndex =
              index;
        });

        if (index == 0) {
          _loadDashboard(
            showLoader: false,
          );
          return;
        }

        if (index == 1) {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminDriversScreen()));
          return;
        }

        if (index == 2) {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminVehiclesScreen()));
          return;
        }

        if (index == 3) {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminRidesScreen()));
          return;
        }

        if (index == 5) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const AdminPaymentsScreen(),
            ),
          );
        }
      },

      child: SizedBox(
        width: 62,

        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,

          children: [

            Icon(
              icon,

              size:
                  22,

              color:
                  selected
                      ? primaryColor
                      : Colors.grey.shade500,
            ),

            const SizedBox(
              height: 3,
            ),

            Text(
              title,

              style:
                  TextStyle(
                fontSize:
                    10,

                color:
                    selected
                        ? primaryColor
                        : Colors.grey.shade500,

                fontWeight:
                    selected
                        ? FontWeight.w600
                        : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// ADMIN - PAGAMENTOS
// ============================================================

class AdminPaymentsScreen extends StatefulWidget {
  const AdminPaymentsScreen({super.key});

  @override
  State<AdminPaymentsScreen> createState() =>
      _AdminPaymentsScreenState();
}

class _AdminPaymentsScreenState extends State<AdminPaymentsScreen> {
  final Color primaryColor = const Color(0xFF00C985);
  final Color darkColor = const Color(0xFF17212B);

  bool _loading = true;
  String? _error;
  String _filter = 'pending';
  List<dynamic> _payments = [];

  @override
  void initState() {
    super.initState();
    _loadPayments();
  }

  Future<void> _loadPayments({bool showLoader = true}) async {
    if (showLoader && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    final result = await ApiService.getAdminPayments(
      status: _filter,
    );

    if (!mounted) return;

    if (result['success'] == true) {
      setState(() {
        _payments = result['payments'] is List
            ? List<dynamic>.from(result['payments'])
            : [];
        _loading = false;
        _error = null;
      });
    } else {
      setState(() {
        _loading = false;
        _error = result['message']?.toString() ??
            'Não foi possível carregar os pagamentos.';
      });
    }
  }

  int _int(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  double _double(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _money(dynamic value) {
    return 'R\$ ${_double(value).toStringAsFixed(2).replaceAll('.', ',')}';
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'Em análise';
      case 'approved':
        return 'Aprovado';
      case 'rejected':
        return 'Recusado';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
        return const Color(0xFF16A36A);
      case 'rejected':
        return const Color(0xFFE24B4B);
      default:
        return const Color(0xFFF59E0B);
    }
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> _approve(Map<String, dynamic> payment) async {
    final id = _int(payment['id']);
    if (id <= 0) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Aprovar pagamento?'),
        content: Text(
          'Confirmar o pagamento de ${_money(payment["amount"])}?\n\n'
          'A fatura será marcada como paga e o motorista será liberado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Aprovar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _loading = true);

    final result = await ApiService.approvePayment(
      paymentId: id,
    );

    if (!mounted) return;

    if (result['success'] == true) {
      _message('Pagamento aprovado com sucesso.');
      await _loadPayments(showLoader: false);
    } else {
      setState(() => _loading = false);
      _message(result['message']?.toString() ??
          'Não foi possível aprovar o pagamento.');
    }
  }

  Future<void> _reject(Map<String, dynamic> payment) async {
    final controller = TextEditingController();

    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Recusar pagamento'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          maxLength: 500,
          decoration: const InputDecoration(
            labelText: 'Motivo da recusa',
            hintText: 'Ex.: comprovante ilegível ou valor incorreto.',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE24B4B),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final value = controller.text.trim();
              if (value.isEmpty) return;
              Navigator.pop(context, value);
            },
            child: const Text('Recusar'),
          ),
        ],
      ),
    );

    controller.dispose();

    if (reason == null || reason.trim().isEmpty) return;

    setState(() => _loading = true);

    final result = await ApiService.rejectPayment(
      paymentId: _int(payment['id']),
      reason: reason.trim(),
    );

    if (!mounted) return;

    if (result['success'] == true) {
      _message('Pagamento recusado.');
      await _loadPayments(showLoader: false);
    } else {
      setState(() => _loading = false);
      _message(result['message']?.toString() ??
          'Não foi possível recusar o pagamento.');
    }
  }

  void _showProof(Map<String, dynamic> payment) {
    final proof = payment['proof'];
    final path = proof is Map ? proof['path']?.toString() : null;
    final name = proof is Map ? proof['original_name']?.toString() : null;
    final paymentId = payment['id'] is num
    ? (payment['id'] as num).toInt()
    : int.tryParse(payment['id']?.toString() ?? '');

final url = ApiService.paymentProofUrl(
  path,
  paymentId: paymentId,
);

    if (url.isEmpty) {
      _message('Comprovante não encontrado.');
      return;
    }

    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 800,
            maxHeight: 750,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 15, 10, 10),
                child: Row(
                  children: [
                    const Icon(Icons.receipt_long_outlined),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        name?.isNotEmpty == true
                            ? name!
                            : 'Comprovante de pagamento',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: InteractiveViewer(
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Padding(
                      padding: EdgeInsets.all(40),
                      child: Text(
                        'Não foi possível carregar o comprovante.',
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusChip(String status) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _paymentCard(Map<String, dynamic> payment) {
    final driver = payment['driver'] is Map
        ? Map<String, dynamic>.from(payment['driver'])
        : <String, dynamic>{};
    final invoice = payment['invoice'] is Map
        ? Map<String, dynamic>.from(payment['invoice'])
        : <String, dynamic>{};

    final status = payment['status']?.toString() ?? 'pending';
    final name = driver['name']?.toString() ?? 'Motorista';
    final phone = driver['phone']?.toString() ?? '';
    final invoiceId = _int(payment['invoice_id']);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.04),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(
          color: const Color(0xFFE9EEEC),
        ),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.account_balance_wallet_outlined,
                  color: primaryColor,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (phone.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        phone,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 5),
                    Text(
                      'Fatura #$invoiceId',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              _statusChip(status),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F9F8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _info('Valor', _money(payment['amount'])),
                ),
                Expanded(
                  child: _info(
                    'Método',
                    (payment['payment_method']?.toString() ?? 'pix').toUpperCase(),
                  ),
                ),
                Expanded(
                  child: _info(
                    'Vencimento',
                    invoice['due_date']?.toString() ?? '-',
                  ),
                ),
              ],
            ),
          ),
          if (payment['rejection_reason'] != null &&
              payment['rejection_reason'].toString().trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Motivo da recusa: ${payment["rejection_reason"]}',
                style: const TextStyle(
                  color: Color(0xFFE24B4B),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const SizedBox(height: 15),
          Wrap(
            spacing: 9,
            runSpacing: 9,
            children: [
              OutlinedButton.icon(
                onPressed: () => _showProof(payment),
                icon: const Icon(Icons.visibility_outlined, size: 18),
                label: const Text('Ver comprovante'),
              ),
              if (status == 'pending') ...[
                ElevatedButton.icon(
                  onPressed: () => _approve(payment),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Aprovar'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _reject(payment),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFE24B4B),
                    side: const BorderSide(
                      color: Color(0xFFE24B4B),
                    ),
                  ),
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Recusar'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _info(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = _filter == 'pending' ? _payments.length : 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F6),
      appBar: AppBar(
        backgroundColor: darkColor,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Pagamentos',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _loading
                ? null
                : () => _loadPayments(),
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            child: Column(
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Financeiro dos motoristas',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (pendingCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3D6),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$pendingCount pendente${pendingCount == 1 ? '' : 's'}',
                          style: const TextStyle(
                            color: Color(0xFFB26A00),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _filterButton('pending', 'Pendentes'),
                      const SizedBox(width: 8),
                      _filterButton('approved', 'Pagos'),
                      const SizedBox(width: 8),
                      _filterButton('rejected', 'Recusados'),
                      const SizedBox(width: 8),
                      _filterButton('all', 'Todos'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading && _payments.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : _error != null && _payments.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.cloud_off_outlined,
                                size: 45,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _error!,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: () => _loadPayments(),
                                child: const Text('Tentar novamente'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => _loadPayments(showLoader: false),
                        child: _payments.isEmpty
                            ? ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: const [
                                  SizedBox(height: 110),
                                  Icon(
                                    Icons.receipt_long_outlined,
                                    size: 55,
                                    color: Colors.grey,
                                  ),
                                  SizedBox(height: 12),
                                  Center(
                                    child: Text(
                                      'Nenhum pagamento encontrado.',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : ListView.builder(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.all(18),
                                itemCount: _payments.length,
                                itemBuilder: (context, index) {
                                  final raw = _payments[index];
                                  if (raw is! Map) {
                                    return const SizedBox.shrink();
                                  }
                                  return _paymentCard(
                                    Map<String, dynamic>.from(raw),
                                  );
                                },
                              ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _filterButton(String value, String label) {
    final selected = _filter == value;
    return OutlinedButton(
      onPressed: () async {
        if (_filter == value) return;
        setState(() {
          _filter = value;
          _payments = [];
        });
        await _loadPayments();
      },
      style: OutlinedButton.styleFrom(
        backgroundColor: selected ? primaryColor : Colors.white,
        foregroundColor: selected ? Colors.white : darkColor,
        side: BorderSide(
          color: selected ? primaryColor : const Color(0xFFDDE4E0),
        ),
      ),
      child: Text(label),
    );
  }
}

