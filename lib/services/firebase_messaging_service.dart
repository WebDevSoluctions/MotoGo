import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../firebase_options.dart';
import 'notification_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Quando o app está em segundo plano/encerrado,
  // mensagens FCM que possuem "notification" são
  // exibidas automaticamente pelo Android.
  //
  // Não chamamos showIncomingRide() aqui para evitar
  // notificações duplicadas.
  print(
    'MotoGo FCM background: ${message.messageId}',
  );
}

class FirebaseMessagingService {
  static final FirebaseMessaging _messaging =
      FirebaseMessaging.instance;

  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Android 13+
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    // Background
    FirebaseMessaging.onBackgroundMessage(
      firebaseMessagingBackgroundHandler,
    );

    // App aberto
    FirebaseMessaging.onMessage.listen(
      (RemoteMessage message) async {
        await _handleForegroundMessage(message);
      },
    );

    // Usuário tocou na notificação
    FirebaseMessaging.onMessageOpenedApp.listen(
      (RemoteMessage message) {
        _handleOpenedMessage(message);
      },
    );

    // App estava completamente fechado
    final initialMessage =
        await _messaging.getInitialMessage();

    if (initialMessage != null) {
      _handleOpenedMessage(initialMessage);
    }

    _initialized = true;
  }

  static Future<void> _handleForegroundMessage(
    RemoteMessage message,
  ) async {
    final data = message.data;

    if (data['type'] != 'incoming_ride') {
      return;
    }

    final rideId = int.tryParse(
      data['ride_id']?.toString() ?? '',
    );

    if (rideId == null) {
      return;
    }

    await NotificationService.showIncomingRide(
      rideId: rideId,
      passengerName:
          data['passenger_name']?.toString() ??
              'Passageiro',
      rideType:
          data['ride_type']?.toString() ??
              'mototaxi',
      price:
          double.tryParse(
                data['total_fare']?.toString() ?? '',
              ) ??
              0,
      origin:
          data['origin_address']?.toString() ?? '',
      destination:
          data['destination_address']?.toString() ?? '',
    );
  }

  static void _handleOpenedMessage(
    RemoteMessage message,
  ) {
    final data = message.data;

    if (data['type'] != 'incoming_ride') {
      return;
    }

    final rideId = data['ride_id'];

    print(
      'MotoGo: usuário abriu notificação da corrida $rideId',
    );

    // Depois conectamos aqui à tela da corrida.
  }
}