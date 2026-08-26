# MotoGo — Fase 1 + Fase 2

Implementação adicional sem substituir o núcleo atual de corridas, Delivery, GPS, login, notificações ou painel.

## Fase 1
- Ponto Exato: confirmação da origem/destino diretamente no mapa.
- Compartilhar viagem: gera token único e página pública de acompanhamento.
- Corrida para outra pessoa: nome/telefone do passageiro chegam ao motorista.
- Agendamento: data/hora ficam no backend; o motorista só recebe a corrida quando chega o horário.
- Motorista favorito: favoritos reais no MySQL e prioridade quando o motorista estiver online/disponível.

## Fase 2
- Paradas múltiplas: até 4, com geocodificação e rota por trechos.
- MotoGo Points: 1 ponto por real em corrida concluída.
- Indicação: código único por usuário e recompensa de 100 pontos para cada lado.
- Cupons: cupons reais, limite de uso, validade, valor mínimo, serviço e uso único por usuário.

## API
Novos endpoints:
- `api/features.php`
- `api/rides/shared_track.php`
- `api/admin/coupons.php`

Migração SQL:
- `database/motogo_phase12.sql`

A API também cria as tabelas novas automaticamente quando os recursos são acessados.

## Teste local
1. Substitua os arquivos do MotoGo pela versão deste ZIP.
2. Substitua os arquivos do MotoGo API pela versão deste ZIP.
3. Rode `flutter clean` e `flutter pub get`.
4. Inicie a API local normalmente.
5. Teste no Chrome antes do A16.
6. Depois teste no A16.

## Atenção
O Flutter SDK não está disponível no ambiente que gerou este pacote, então a compilação Flutter não pôde ser executada aqui. A sintaxe dos arquivos PHP foi validada com `php -l` e os arquivos Flutter foram revisados estruturalmente. Faça `flutter analyze`/`flutter run` no seu PC antes de instalar no celular.
