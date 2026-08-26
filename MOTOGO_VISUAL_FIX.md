# MotoGo — correção visual dos serviços

- Assets de `assets/images/services/` foram declarados explicitamente no pubspec.yaml.
- A ordem da Home foi preservada: header, mensagem, ranking, busca, acesso rápido, serviços, atividade recente e mapa.
- Cards de serviços foram redesenhados para usar a ilustração à direita, evitando BOTTOM OVERFLOWED.
- Delivery mostra Moto e Bike no próprio card.
- Entrega a pé abre com `initialDeliveryType: pedestre`.
- Nenhuma regra de rota, pontos, paradas ou cálculo de tarifa foi removida.
