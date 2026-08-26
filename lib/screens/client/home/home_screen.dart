import 'package:flutter/material.dart';

import 'package:motogo/config/colors.dart';

import 'package:motogo/widgets/custom_appbar.dart';
import 'package:motogo/widgets/section_title.dart';
import 'package:motogo/widgets/service_card.dart';

import '../ride/ride_request_screen.dart';
import 'package:motogo/screens/delivery/delivery_request_screen.dart';

import 'widgets/home_header.dart';
import 'widgets/search_destination.dart';
import 'widgets/quick_actions.dart';
import 'widgets/recent_activity.dart';
import 'widgets/map_placeholder.dart';
import 'widgets/bottom_panel.dart';
import 'widgets/faith_message_card.dart';
import 'widgets/ranking_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
  });

  // ============================================================
  // MOTOTÁXI
  // ============================================================

  void _openMotoTaxi(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const RideRequestScreen(
          rideType: 'mototaxi',
        ),
      ),
    );
  }

  // ============================================================
  // CARRO
  // ============================================================

  void _openCarRide(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const RideRequestScreen(
          rideType: 'carro',
        ),
      ),
    );
  }

  // ============================================================
  // DELIVERY
  // ============================================================

  void _openDelivery(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const DeliveryRequestScreen(),
      ),
    );
  }

  void _openMotoExpress(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const DeliveryRequestScreen(
          initialDeliveryType: 'moto',
            allowPedestrian: true,
        ),
      ),
    );
  }

  void _openBikeExpress(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const DeliveryRequestScreen(
          initialDeliveryType: 'bicicleta',
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          AppColors.background,

      // ========================================================
      // APP BAR
      // ========================================================

      appBar: const CustomAppBar(
        title: 'MotoGo',
      ),

      // ========================================================
      // BODY
      // ========================================================

      body: SafeArea(
        child: SingleChildScrollView(
          physics:
              const BouncingScrollPhysics(),

          padding:
              const EdgeInsets.fromLTRB(
            20,
            20,
            20,
            40,
          ),

          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,

            children: [

              // ==================================================
              // HEADER
              // ==================================================

              const HomeHeader(),

              const SizedBox(height: 16),

              const FaithMessageCard(),

              const SizedBox(height: 14),

              const ClientRankingCard(),

              const SizedBox(height: 28),

              // ==================================================
              // BUSCA DESTINO
              // ==================================================

              const SearchDestination(),

              const SizedBox(
                height: 30,
              ),

              // ==================================================
              // ACESSO RÁPIDO
              // ==================================================

              const SectionTitle(
                title: 'Acesso rápido',
              ),

              const SizedBox(
                height: 18,
              ),

              const QuickActions(),

              const SizedBox(
                height: 30,
              ),

              // ==================================================
              // SERVIÇOS
              // ==================================================

              const SectionTitle(
                title: 'Serviços',
              ),

              const SizedBox(height: 16),

              // ==================================================
              // SERVIÇOS
              // Responsivo: mantém o visual compacto no celular e
              // limita a largura no PC para não esticar os cards.
              // ==================================================
              LayoutBuilder(
                builder: (context, constraints) {
                  final availableWidth = constraints.maxWidth;
                  final contentWidth =
                      availableWidth > 1100 ? 1000.0 : availableWidth;
                  final spacing = availableWidth < 380 ? 8.0 : 12.0;
                  final cardWidth = (contentWidth - spacing) / 2;

                  return Center(
                    child: SizedBox(
                      width: contentWidth,
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        spacing: spacing,
                        runSpacing: spacing,
                        children: [
                          SizedBox(
                            width: cardWidth,
                            child: ServiceCard(
                              icon: Icons.two_wheeler,
                              title: 'Mototáxi',
                              imageAsset: 'assets/images/services/mototaxi.png',
                              heroAsset: 'assets/images/services/mototaxi_hero.png',
                              subtitle: 'Corrida rápida',
                              color: AppColors.primary,
                              compact: true,
                              onTap: () => _openMotoTaxi(context),
                            ),
                          ),
                          SizedBox(
                            width: cardWidth,
                            child: ServiceCard(
                              icon: Icons.directions_car,
                              title: 'Carro',
                              imageAsset: 'assets/images/services/carro.png',
                              heroAsset: 'assets/images/services/carro_hero.png',
                              subtitle: 'Conforto e segurança',
                              color: Colors.indigo,
                              compact: true,
                              onTap: () => _openCarRide(context),
                            ),
                          ),
                          SizedBox(
                            width: cardWidth,
                            child: ServiceCard(
                              icon: Icons.delivery_dining,
                              title: 'Moto Express',
                              imageAsset: 'assets/images/services/moto_express.png',
                              heroAsset: 'assets/images/services/moto_express_hero.png',
                              subtitle: 'Entrega rápida de moto',
                              color: const Color(0xFF0B8F4D),
                              badge: '⚡ EXPRESS',
                              compact: true,
                              onTap: () => _openMotoExpress(context),
                            ),
                          ),
                          SizedBox(
                            width: cardWidth,
                            child: ServiceCard(
                              icon: Icons.pedal_bike,
                              title: 'Bike Express',
                              imageAsset: 'assets/images/services/bike_express.png',
                              heroAsset: 'assets/images/services/bike_express_hero.png',
                              subtitle: 'Entrega econômica',
                              color: const Color(0xFF39B93B),
                              badge: 'ECONÔMICO',
                              compact: true,
                              onTap: () => _openBikeExpress(context),
                            ),
                          ),
                          SizedBox(
                            width: cardWidth,
                            child: ServiceCard(
                              icon: Icons.directions_walk,
                              title: 'Entrega a pé',
                              imageAsset: 'assets/images/services/pedestre.png',
                              heroAsset: 'assets/images/services/pedestre_hero.png',
                              subtitle: 'Ideal para curtas distâncias',
                              color: const Color(0xFFC42BAF),
                              badge: 'ATÉ 2 KM',
                              compact: true,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const DeliveryRequestScreen(
                                    initialDeliveryType: 'pedestre',
                                    allowPedestrian: true,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: cardWidth,
                            child: ServiceCard(
                              icon: Icons.local_shipping_outlined,
                              title: 'Delivery',
                              imageAsset: 'assets/images/services/delivery.png',
                              subtitle: 'Escolha Moto ou Bike',
                              color: const Color(0xFF008F68),
                              badge: 'DELIVERY',
                              compact: true,
                              choices: const [
                                ServiceChoice(
                                  label: 'Moto',
                                  imageAsset: 'assets/images/services/moto_express.png',
                                ),
                                ServiceChoice(
                                  label: 'Bike',
                                  imageAsset: 'assets/images/services/bike_express.png',
                                ),
                              ],
                              onTap: () => _openDelivery(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 22),

              // ==================================================
              // ATIVIDADE RECENTE
              // ==================================================

              const SectionTitle(
                title:
                    'Atividade recente',
              ),

              const SizedBox(
                height: 18,
              ),

              const RecentActivity(),

              const SizedBox(
                height: 30,
              ),

              // ==================================================
              // MAPA
              // ==================================================

              const SectionTitle(
                title: 'Mapa',
              ),

              const SizedBox(
                height: 18,
              ),

              const MapPlaceholder(),

              const SizedBox(
                height: 30,
              ),

              // ==================================================
              // PAINEL
              // ==================================================

              const BottomPanel(),

              const SizedBox(
                height: 40,
              ),
            ],
          ),
        ),
      ),
    );
  }
}