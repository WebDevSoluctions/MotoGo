import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static final AudioPlayer _player = AudioPlayer();
  static bool _initialized = false;
  static bool _timezoneInitialized = false;
  static int? _activeIncomingRideId;

  // IDs separados para não misturar notificações de clientes e motoristas.
  static const int _driverDailyBaseId = 81000;
  static const int _clientDailyBaseId = 82000;
  static const int _daysToSchedule = 60;

  static const List<Map<String, String>> _driverMessages = [
    {
      'title': '🏍️ Bom dia, campeão!',
      'body': 'O MotoGo já está esperando você. Bora trabalhar e aproveitar as corridas de hoje!',
    },
    {
      'title': '☀️ Novo dia, novas corridas!',
      'body': 'Fique online no MotoGo e aproveite as oportunidades de hoje.',
    },
    {
      'title': '🚀 Bora começar o dia?',
      'body': 'Seu próximo passageiro pode estar esperando. Fique disponível no MotoGo!',
    },
    {
      'title': '💚 Bom dia, motorista!',
      'body': 'Que hoje seja um dia de boas corridas e ótimos ganhos. Bora trabalhar!',
    },
    {
      'title': '🏍️ O MotoGo está online!',
      'body': 'Quando estiver pronto, fique online e confira as novas solicitações.',
    },
    {
      'title': '💰 Dia de trabalhar!',
      'body': 'Comece sua manhã no MotoGo e aproveite as corridas disponíveis.',
    },
    {
      'title': '🌅 Bom dia!',
      'body': 'Prepare sua moto ou carro e venha fazer parte das corridas de hoje.',
    },
    {
      'title': '🔥 Bora pra cima!',
      'body': 'O dia começou. Fique online no MotoGo quando estiver pronto para rodar.',
    },
    {
      'title': '🏁 Começando mais um dia',
      'body': 'Desejamos boas corridas e uma excelente jornada. Conte com o MotoGo!',
    },
    {
      'title': '📲 Tem corrida esperando?',
      'body': 'Abra o MotoGo, fique online e confira as solicitações disponíveis.',
    },
    {
      'title': '💚 Bom trabalho!',
      'body': 'Mais um dia para rodar, atender bem e aproveitar novas oportunidades.',
    },
    {
      'title': '☀️ Vamos começar?',
      'body': 'Se você já está pronto, fique online no MotoGo e bora para as corridas!',
    },
    {
      'title': '🏍️ Sua jornada começa aqui',
      'body': 'Fique disponível no MotoGo e acompanhe as novas solicitações durante o dia.',
    },
    {
      'title': '💪 Bom dia, parceiro!',
      'body': 'Que hoje renda boas corridas. Abra o MotoGo e fique online quando puder.',
    },
    {
      'title': '🚕 Dia novo, oportunidades novas!',
      'body': 'Motorista online faz a diferença. Bora aproveitar o movimento de hoje!',
    },
    {
      'title': '🌟 Excelente dia!',
      'body': 'Desejamos boas corridas, bons passageiros e uma ótima jornada no MotoGo.',
    },
    {
      'title': '🏍️ Partiu trabalhar?',
      'body': 'Quando estiver disponível, entre no MotoGo e comece sua jornada.',
    },
    {
      'title': '💚 MotoGo com você',
      'body': 'Fique atento às solicitações e aproveite seu dia de trabalho.',
    },
    {
      'title': '☀️ Bom dia!',
      'body': 'Seu dia pode começar com uma boa corrida. Fique online quando estiver pronto.',
    },
    {
      'title': '🚀 Vamos rodar!',
      'body': 'Mais um dia de oportunidades no MotoGo. Boa jornada, campeão!',
    },
  ];

  static const List<Map<String, String>> _clientMessages = [
    {
      'title': '☀️ Bom dia!',
      'body': 'Vai sair hoje? Peça sua corrida pelo MotoGo e chegue ao seu destino com praticidade.',
    },
    {
      'title': '🚕 Seu destino está esperando',
      'body': 'Abra o MotoGo, escolha seu destino e solicite sua corrida quando precisar.',
    },
    {
      'title': '💚 Bom dia!',
      'body': 'Precisa sair? O MotoGo está pronto para ajudar você a chegar ao seu destino.',
    },
    {
      'title': '📍 Vai para onde hoje?',
      'body': 'Informe seu endereço no MotoGo e veja as opções de viagem disponíveis.',
    },
    {
      'title': '☀️ Comece o dia com praticidade',
      'body': 'Quando precisar sair, conte com o MotoGo para solicitar sua corrida.',
    },
    {
      'title': '🏍️ Precisa de uma corrida?',
      'body': 'Abra o MotoGo, escolha o destino e faça sua solicitação em poucos passos.',
    },
    {
      'title': '💚 O MotoGo está com você',
      'body': 'Vai sair? Solicite sua corrida e acompanhe tudo pelo aplicativo.',
    },
    {
      'title': '🌅 Bom dia!',
      'body': 'Seu próximo destino está a poucos toques de distância. Peça sua corrida no MotoGo.',
    },
    {
      'title': '🚀 Vamos sair?',
      'body': 'Escolha seu destino e solicite uma corrida pelo MotoGo quando precisar.',
    },
    {
      'title': '📲 MotoGo na sua mão',
      'body': 'Precisa ir a algum lugar? Abra o app e solicite sua corrida.',
    },
    {
      'title': '☀️ Um ótimo dia para você!',
      'body': 'Quando precisar se deslocar, o MotoGo está pronto para atender você.',
    },
    {
      'title': '🏁 Vai começar o dia?',
      'body': 'Se precisar de transporte, informe seu destino e solicite sua corrida no MotoGo.',
    },
    {
      'title': '💚 Precisa chegar rápido?',
      'body': 'Consulte as opções do MotoGo e solicite sua viagem quando precisar.',
    },
    {
      'title': '📍 Novo dia, novo destino',
      'body': 'Digite seu endereço, confira a viagem e peça sua corrida pelo MotoGo.',
    },
    {
      'title': '🚕 Bom dia!',
      'body': 'Vai sair de casa? Deixe o MotoGo ajudar você no seu próximo deslocamento.',
    },
    {
      'title': '🌟 Tenha um excelente dia!',
      'body': 'Quando precisar de transporte, lembre-se do MotoGo.',
    },
    {
      'title': '🏍️ Bora para o próximo destino?',
      'body': 'Abra o MotoGo e solicite sua corrida de forma simples e prática.',
    },
    {
      'title': '☀️ Sua manhã pode ser mais fácil',
      'body': 'Precisa sair? Solicite uma corrida pelo MotoGo e acompanhe sua viagem.',
    },
    {
      'title': '💚 Bom dia!',
      'body': 'O MotoGo está pronto para ajudar você a chegar onde precisa.',
    },
    {
      'title': '📲 Vai sair hoje?',
      'body': 'Escolha seu destino no MotoGo e solicite sua corrida quando precisar.',
    },
  ];

  static Future<void> _initializeTimezone() async {
    if (_timezoneInitialized) return;
    tz.initializeTimeZones();

    // O MotoGo está sendo usado no Brasil. Mantemos o agendamento em
    // horário de Brasília para que 08:00 continue sendo 08:00 local.
    try {
      tz.setLocalLocation(tz.getLocation('America/Sao_Paulo'));
    } catch (_) {
      // Fallback seguro caso a base de fusos não contenha o identificador.
    }

    _timezoneInitialized = true;
  }

  static Future<void> initialize() async {
    if (_initialized) return;

    await _initializeTimezone();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();

    const settings = InitializationSettings(
      android: android,
      iOS: ios,
    );

    await _notifications.initialize(settings);

    final androidPlugin =
        _notifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.requestNotificationsPermission();

    final iosPlugin =
        _notifications.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();

    await iosPlugin?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );

    const channel = AndroidNotificationChannel(
  'motogo_rides_v2',
  'Corridas MotoGo',
  description: 'Alertas de novas corridas e solicitações.',
  importance: Importance.max,
  playSound: true,
  sound: RawResourceAndroidNotificationSound('ride_request'),
);
    await androidPlugin?.createNotificationChannel(channel);

    const dailyChannel = AndroidNotificationChannel(
      'motogo_daily',
      'Mensagens MotoGo',
      description: 'Mensagens diárias e lembretes do MotoGo.',
      importance: Importance.defaultImportance,
      playSound: true,
    );

    await androidPlugin?.createNotificationChannel(dailyChannel);

    _initialized = true;
  }

  static Future<void> prepareForUserInteraction() async {
    await initialize();
  }

  /// Agenda mensagens motivacionais para as próximas 60 manhãs.
  ///
  /// A lista é rotativa: cada dia recebe uma mensagem diferente e, depois
  /// de chegar ao fim da lista, começa novamente em outra posição.
  static Future<void> scheduleDailyMotivation({
    required String accountType,
  }) async {
    await initialize();

    final normalized = accountType.trim().toLowerCase();

    if (normalized != 'driver' && normalized != 'client') {
      return;
    }

    final int baseId = normalized == 'driver'
        ? _driverDailyBaseId
        : _clientDailyBaseId;

    final messages = normalized == 'driver'
        ? _driverMessages
        : _clientMessages;

    // Limpa somente as mensagens diárias deste tipo de conta.
    for (int i = 0; i < _daysToSchedule; i++) {
      await _notifications.cancel(baseId + i);
    }

    final now = tz.TZDateTime.now(tz.local);
    final startDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      8,
      0,
    );

    for (int i = 0; i < _daysToSchedule; i++) {
      final day = startDate.add(Duration(days: i));

      // Se 08:00 de hoje já passou, começa amanhã.
      if (day.isBefore(now)) {
        continue;
      }

      final yearStart = tz.TZDateTime(
        tz.local,
        day.year,
        1,
        1,
      );

      final calendarDayIndex =
          day.difference(yearStart).inDays;

      final message =
          messages[calendarDayIndex % messages.length];

      const android = AndroidNotificationDetails(
        'motogo_daily',
        'Mensagens MotoGo',
        channelDescription: 'Mensagens diárias e lembretes do MotoGo.',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        playSound: true,
      );

      const ios = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: false,
        presentSound: true,
      );

      const details = NotificationDetails(
        android: android,
        iOS: ios,
      );

      await _notifications.zonedSchedule(
        baseId + i,
        message['title'],
        message['body'],
        day,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: 'daily:$normalized:$i',
      );
    }
  }

  static Future<void> cancelDailyMotivation() async {
    await initialize();

    for (int i = 0; i < _daysToSchedule; i++) {
      await _notifications.cancel(_driverDailyBaseId + i);
      await _notifications.cancel(_clientDailyBaseId + i);
    }
  }

  static Future<void> showIncomingRide({
    required int rideId,
    required String passengerName,
    required String rideType,
    required double price,
    required String origin,
    required String destination,
  }) async {
    await initialize();

    try {
      _activeIncomingRideId = rideId;
      await _player.stop();
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.play(
        AssetSource('sounds/ride_request.wav'),
        volume: 1.0,
      );
    } catch (_) {}

    const android = AndroidNotificationDetails(
      'motogo_rides_v2',
      'Corridas MotoGo',
      channelDescription: 'Alertas de novas corridas e solicitações.',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    const ios = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: android,
      iOS: ios,
    );

    await _notifications.show(
      rideId,
      '🏍️ Nova corrida MotoGo',
      '$passengerName • R\$ ${price.toStringAsFixed(2)}',
      details,
      payload: 'ride:$rideId',
    );
  }

  static Future<void> stopIncomingRide({int? rideId}) async {
    if (rideId != null &&
        _activeIncomingRideId != null &&
        rideId != _activeIncomingRideId) {
      return;
    }

    _activeIncomingRideId = null;

    try {
      await _player.stop();
      await _player.setReleaseMode(ReleaseMode.release);
    } catch (_) {}
  }

  static Future<void> showChatMessage({required int rideId, required String senderName, required String message}) async {
    await initialize();
    const android = AndroidNotificationDetails('motogo_chat', 'Chat MotoGo', channelDescription: 'Mensagens das corridas.', importance: Importance.high, priority: Priority.high, playSound: true, enableVibration: true);
    const ios = DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true);
    await _notifications.show(300000 + rideId, '💬 $senderName', message, const NotificationDetails(android: android, iOS: ios), payload: 'chat:$rideId');
  }

  static Future<void> showEarningsUpdate({
    required int rideId,
    required double amount,
    required double todayTotal,
  }) async {
    await initialize();
    const android = AndroidNotificationDetails(
      'motogo_finance', 'Financeiro MotoGo',
      channelDescription: 'Atualizações de ganhos e saldo do motorista.',
      importance: Importance.high, priority: Priority.high, playSound: true,
    );
    const ios = DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true);
    await _notifications.show(
      400000 + rideId, '💰 Ganho recebido',
      'Você ganhou R\$ ${amount.toStringAsFixed(2)} nesta corrida. Hoje: R\$ ${todayTotal.toStringAsFixed(2)}',
      const NotificationDetails(android: android, iOS: ios), payload: 'earnings:$rideId',
    );
  }

  static Future<void> showRideStatus({
    required int rideId,
    required String status,
    required String message,
  }) async {
    await initialize();

    try {
      await _player.stop();
      await _player.play(
        AssetSource('sounds/ride_request.wav'),
        volume: 0.7,
      );
    } catch (_) {}

    const android = AndroidNotificationDetails(
      'motogo_rides_v2',
      'Corridas MotoGo',
      channelDescription: 'Atualizações das corridas.',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
    );

    const ios = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(android: android, iOS: ios);

    await _notifications.show(
      200000 + rideId,
      'MotoGo • $status',
      message,
      details,
      payload: 'ride:$rideId',
    );
  }
}
