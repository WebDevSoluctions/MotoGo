import 'package:flutter/material.dart';

/// Opção visual usada pelo card Delivery para mostrar Moto e Bike.
class ServiceChoice {
  final String label;
  final String imageAsset;

  const ServiceChoice({
    required this.label,
    required this.imageAsset,
  });
}

class ServiceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  final String? badge;
  final String? imageAsset;
  /// Ilustração/foto principal exibida em tamanho grande no card.
  final String? heroAsset;
  final bool compact;
  final List<ServiceChoice>? choices;

  const ServiceCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.badge,
    this.imageAsset,
    this.heroAsset,
    this.compact = false,
    this.choices,
  });

  @override
  Widget build(BuildContext context) {
    final cardHeight = compact ? 170.0 : 220.0;
    final radius = BorderRadius.circular(18);

    return SizedBox(
      height: cardHeight,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: radius,
              gradient: LinearGradient(
                colors: [color, Color.lerp(color, Colors.black, .10)!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(.22),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: radius,
              child: Stack(
                children: [
                  // Brilho discreto no fundo para dar profundidade.
                  Positioned(
                    right: -35,
                    bottom: -45,
                    child: Container(
                      width: 190,
                      height: 120,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(100),
                        color: Colors.white.withOpacity(.06),
                      ),
                    ),
                  ),

                  if (choices != null && choices!.isNotEmpty)
                    Positioned(
                      right: 10,
                      bottom: 10,
                      top: compact ? 38 : 46,
                      width: compact ? 235 : 220,
                      child: Row(
                        children: choices!
                            .take(2)
                            .map(
                              (choice) => Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 5),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(.10),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(.25),
                                      ),
                                    ),
                                    padding: const EdgeInsets.fromLTRB(5, 5, 5, 4),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Expanded(
                                          child: Image.asset(
                                            choice.imageAsset,
                                            fit: BoxFit.contain,
                                            filterQuality: FilterQuality.high,
                                            errorBuilder: (_, __, ___) => Icon(
                                              Icons.image_not_supported_outlined,
                                              color: Colors.white70,
                                              size: 28,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          choice.label,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    )
                  else if (heroAsset != null)
                    // A ilustração nunca sai da área do card.  O tamanho
                    // menor no modo compacto evita cortar rodas/pés/parte
                    // inferior das imagens no Android e no Chrome.
                    Positioned(
                      right: compact ? 4 : -2,
                      bottom: compact ? 2 : 0,
                      width: compact ? 205 : 320,
                      height: compact ? 132 : 185,
                      child: Image.asset(
                        heroAsset!,
                        fit: BoxFit.contain,
                        alignment: Alignment.bottomRight,
                        filterQuality: FilterQuality.high,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),

                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      compact ? 13 : 18,
                      compact ? 12 : 16,
                      compact ? 13 : 18,
                      compact ? 11 : 15,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: compact ? 46 : 56,
                              height: compact ? 46 : 56,
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(.90),
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: imageAsset != null
                                  ? Image.asset(
                                      imageAsset!,
                                      fit: BoxFit.contain,
                                      filterQuality: FilterQuality.high,
                                      errorBuilder: (_, __, ___) => Icon(
                                        icon,
                                        color: color,
                                        size: compact ? 25 : 30,
                                      ),
                                    )
                                  : Icon(
                                      icon,
                                      color: color,
                                      size: compact ? 25 : 30,
                                    ),
                            ),
                            const Spacer(),
                            if (badge != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(.18),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(.25),
                                  ),
                                ),
                                child: Text(
                                  badge!,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const Spacer(),
                        // Limita a área de texto para não sobrepor as ilustrações.
                        SizedBox(
                          width: choices != null
                              ? compact ? 145 : 190
                              : compact ? 185 : 235,
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: compact ? 17 : 22,
                              fontWeight: FontWeight.w900,
                              height: 1.05,
                            ),
                          ),
                        ),
                        const SizedBox(height: 3),
                        SizedBox(
                          width: choices != null
                              ? compact ? 155 : 205
                              : compact ? 190 : 250,
                          child: Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withOpacity(.84),
                              fontSize: compact ? 10.5 : 13,
                              height: 1.1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: const [
                            Text(
                              'Abrir',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(width: 7),
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              color: Colors.white,
                              size: 11,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
