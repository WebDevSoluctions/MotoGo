# MotoGo — Entrega a Pé

Nova modalidade `delivery_pedestre`, disponível somente no fluxo iniciado pelo Moto Express. Limite padrão de 2 km; tarifa padrão R$ 5,00 + R$ 1,50/km. O app envia `ride_type=delivery_pedestre` e `delivery_mode=pedestre`. O backend precisa aceitar esse novo tipo e filtrar entregadores habilitados para pedestre para que o roteamento real funcione.


## Cadastro do entregador a pé

A opção **Entrega a pé** agora aparece no cadastro de motorista.

- `driver_type=delivery_pedestre`;
- não solicita CNH;
- não solicita CRLV/veículo;
- solicita documento de identificação + selfie para análise;
- o entregador precisa ser aprovado antes de receber corridas;
- no backend, `delivery_pedestre` deve ser aceito no cadastro e usado como tipo exclusivo de roteamento para entrega a pé.

O cadastro de bicicleta existente foi mantido sem alteração no fluxo de documentos.
