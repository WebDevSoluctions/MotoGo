# MotoGo iOS — próximos passos

Esta pasta foi preparada para notificações iOS/APNs/FCM.

## O que foi ajustado

- AppDelegate preparado para APNs e notificações em primeiro plano.
- `UIBackgroundModes` com `remote-notification`.
- `Runner.entitlements` com `aps-environment` por configuração.
- `GoogleService-Info.plist` incluído nos Resources do target Runner.
- Removida a cópia indevida de `Flutter` dentro de `Assets.xcassets`.

## Ainda precisa ser feito na Apple/Firebase

1. Escolher um Bundle ID definitivo para o app. O projeto atual usa `com.example.motogo`; se mudar, baixe um novo `GoogleService-Info.plist` no Firebase para o mesmo Bundle ID.
2. No Apple Developer, criar/usar o App ID do MotoGo e ativar Push Notifications.
3. Criar uma chave APNs (ou certificado) e cadastrar no Firebase Cloud Messaging.
4. No Xcode, abrir `Runner.xcworkspace`/projeto, conferir Signing & Capabilities e selecionar sua equipe Apple.
5. Rodar `flutter clean`, `flutter pub get` e depois o build iOS/Archive em um Mac.
6. Testar primeiro em um iPhone físico; simulador não é suficiente para validar APNs/FCM.

## Importante

O zip recebido não contém `Podfile`/Pods. Isso não é necessariamente um erro: o projeto está usando a integração Swift Package do Flutter. O build em um Mac deve regenerar os arquivos temporários com `flutter pub get`.
