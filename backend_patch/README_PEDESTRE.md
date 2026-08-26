# Patch do backend — Entrega a pé

A tela Flutter já envia `ride_type=delivery_pedestre`.

Copie os 5 arquivos desta pasta para o backend correspondente antes de testar a entrega a pé no servidor.

A regra implementada é:
- `delivery_pedestre` usa tarifa padrão R$ 5,00 + R$ 1,50/km;
- entregadores Moto/Moto Express podem receber a solicitação a pé;
- a corrida aparece como entrega a pé para o cliente;
- o contador de entregas inclui `delivery_pedestre`.

O limite de distância de 2 km continua sendo controlado no app pela configuração do `FareService`.


## Cadastro de entregador a pé

O app Flutter agora oferece a opção `delivery_pedestre` no cadastro de motorista.

Para essa modalidade:
- não é necessário CNH;
- não é necessário CRLV/veículo;
- o cadastro exige documento de identificação + selfie para análise;
- depois da aprovação, o entregador recebe somente corridas `delivery_pedestre`;
- moto, carro e bicicleta não devem receber uma corrida de entrega a pé.

### Importante no backend

O endpoint `/auth/register_driver.php` precisa aceitar `delivery_pedestre` como valor válido de `driver_type` e gravá-lo na coluna `drivers.driver_type`. A aprovação continua seguindo o fluxo normal de verificação.

Se o seu backend atualmente só aceita `moto`, `carro`, `delivery_moto` e `delivery_bicicleta`, atualize a lista de tipos permitidos antes de testar o cadastro a pé.
