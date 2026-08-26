# MotoGo — melhorias finais desta versão

## GPS / Endereços
- A tela de solicitação de Mototáxi/Carro agora permite pesquisar também a origem manualmente.
- A mesma busca inteligente usada no Delivery é reutilizada para a origem.
- O botão de GPS continua usando a localização atual e substitui uma origem manual pela localização atual quando solicitado.
- As coordenadas da origem selecionada são usadas no cálculo da rota.
- Destino continua usando a busca inteligente existente.

## Viagem longa
- O limite padrão é 50 km e pode ser alterado no Painel ADM.
- Acima do limite, a solicitação passa automaticamente para o tipo `viagem`.
- A viagem usa tarifa própria configurável no Painel ADM.
- Valores padrão: R$ 80,00 de base + R$ 2,20/km.
- Viagens podem ser oferecidas a motoristas de moto ou carro.
- O backend também força o tipo `viagem` quando a distância ultrapassa o limite configurado, evitando inconsistência entre app e API.

## Importante
- A busca de endereço continua usando a estrutura existente do projeto (Nominatim/OSRM).
- As funcionalidades existentes não foram removidas.
- Antes de Android/Play Store, testar no Chrome e depois no Galaxy A16.
