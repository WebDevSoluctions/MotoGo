# MotoGo — Correção segura de localização de partida

Alterações desta versão:

- Mototáxi continua usando o mesmo fluxo de solicitação/recebimento.
- O marcador do motorista continua verde.
- A origem do passageiro continua sendo o marcador azul.
- O destino continua sendo o marcador vermelho.
- A origem enviada para a API agora usa `selectedOrigin` quando disponível, evitando que uma posição GPS anterior substitua um ponto confirmado.
- A localização automática do passageiro e da coleta faz até 5 leituras GPS e escolhe a leitura com melhor precisão, evitando aceitar imediatamente uma posição aproximada/cacheada.
- Ao confirmar manualmente um ponto no mapa, esse ponto passa a ser a origem oficial da corrida.
- A API não foi alterada nesta versão, para preservar o fluxo que já estava funcionando.

Teste recomendado no Android:
1. Ativar GPS e permissão de localização precisa.
2. Abrir o MotoGo pelo celular.
3. Solicitar Mototáxi.
4. Confirmar que o ponto azul está na posição real do passageiro.
5. No motorista, confirmar ponto azul (passageiro), verde (motorista) e vermelho (destino).
6. Aceitar a corrida e testar o fluxo normal até conclusão.
