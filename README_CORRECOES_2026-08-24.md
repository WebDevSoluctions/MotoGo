# MotoGo — correções 2026-08-24

## Matching de corridas por GPS

O endpoint `backend_patch/api/rides/pending_for_driver.php` agora exige localização GPS recente do motorista e calcula a distância entre a posição atual do motorista e a origem da corrida.

- raio operacional: 20 km;
- localização do motorista precisa estar atualizada nos últimos 2 minutos;
- corrida sem latitude/longitude de origem não é distribuída;
- matching usa distância geográfica, não cidade cadastrada.

Isso permite, por exemplo, que um motorista em Tiradentes receba uma corrida com origem em São João del-Rei, enquanto impede que uma corrida do Rio de Janeiro seja oferecida a esse motorista.

## Endereços

`RouteService` foi reforçado para:

- preservar rua, número, bairro, cidade e UF;
- tentar o endereço completo antes de simplificá-lo;
- usar o contexto de localização como viés de busca sem bloquear outras cidades;
- confirmar número quando o geocodificador devolver `house_number`;
- usar o geocoder nativo Android/iOS como fallback;
- melhorar o parser de formatos como `Rua X, 123, Centro, Tiradentes, MG` e `Rua X, Bairro Centro, Tiradentes, MG`.

O autocomplete também passa a preservar o número retornado pelo geocodificador.


## Cadastro de entregador a pé

Foi adicionada a modalidade `delivery_pedestre` no cadastro de motorista. Ela não exige CNH ou veículo, mas exige documento de identificação e selfie para análise. O motorista aprovado nessa modalidade deve receber somente corridas `delivery_pedestre`.
