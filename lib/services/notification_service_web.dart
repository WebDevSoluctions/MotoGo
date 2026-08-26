import 'dart:html' as html;

import 'package:audioplayers/audioplayers.dart';

class NotificationService {
  static final AudioPlayer _player = AudioPlayer();
  static html.AudioElement? _webAudio;
  static bool _initialized = false;
  static int? _activeIncomingRideId;

  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      _webAudio = html.AudioElement()
        ..src = 'assets/assets/sounds/ride_request.wav'
        ..preload = 'auto'
        ..volume = 1.0;
      _webAudio!.setAttribute('playsinline', 'true');
      _webAudio!.loop = true;
      _webAudio!.load();
    } catch (_) {}
  }

  /// Deve ser chamado por uma ação real do motorista, como o botão
  /// "Ficar online". Isso prepara áudio e pede permissão para notificações.
  static Future<void> prepareForUserInteraction() async {
    await initialize();

    try {
      if (html.Notification.permission == 'default') {
        await html.Notification.requestPermission();
      }
    } catch (_) {}

    // O Chrome só permite liberar áudio de forma confiável a partir de
    // uma interação do usuário. Aqui fazemos a preparação nessa interação.
    try {
      final audio = _webAudio;
      if (audio != null) {
        audio.volume = 0.01;
        audio.currentTime = 0;
        await audio.play();
        audio.pause();
        audio.currentTime = 0;
        audio.volume = 1.0;
      }
    } catch (_) {
      // O alerta normal ainda será tentado quando chegar uma corrida.
    }
  }

  static Future<void> _playAlert({double volume = 1.0, bool loop = false}) async {
    await initialize();

    // Primeira tentativa: AudioElement do próprio navegador.
    try {
      final audio = _webAudio;
      if (audio != null) {
        audio.pause();
        audio.currentTime = 0;
        audio.volume = volume;
        audio.loop = loop;
        await audio.play();
        return;
      }
    } catch (_) {}

    // Fallback: audioplayers.
    try {
      await _player.stop();
      await _player.setReleaseMode(loop ? ReleaseMode.loop : ReleaseMode.release);
      await _player.setVolume(volume);
      await _player.play(
        AssetSource('sounds/ride_request.wav'),
        volume: volume,
      );
    } catch (_) {}
  }

  static void _showNotification({
    required String title,
    required String body,
    required String tag,
  }) {
    try {
      if (html.Notification.permission != 'granted') return;

      final notification = html.Notification(
        title,
        body: body,
        tag: tag,
      );

      notification.onClick.listen((_) {
        try {
          notification.close();
        } catch (_) {}
      });
    } catch (_) {}
  }

  static Future<void> scheduleDailyMotivation({required String accountType}) async {}

  static Future<void> cancelDailyMotivation() async {}

  static Future<void> showIncomingRide({
    required int rideId,
    required String passengerName,
    required String rideType,
    required double price,
    required String origin,
    required String destination,
  }) async {
    await initialize();

    _activeIncomingRideId = rideId;
    await _playAlert(volume: 1.0, loop: true);

    _showNotification(
      title: '🏍️ Nova corrida MotoGo',
      body:
          '$passengerName • R\$ ${price.toStringAsFixed(2)}\n'
          '$origin → $destination',
      tag: 'motogo-ride-$rideId',
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
      final audio = _webAudio;
      if (audio != null) {
        audio.pause();
        audio.currentTime = 0;
        audio.loop = false;
      }
    } catch (_) {}

    try {
      await _player.stop();
      await _player.setReleaseMode(ReleaseMode.release);
    } catch (_) {}
  }

  static Future<void> showChatMessage({required int rideId, required String senderName, required String message}) async {
    await initialize();
    _showNotification(title: '💬 $senderName', body: message, tag: 'motogo-chat-$rideId');
  }

  static Future<void> showEarningsUpdate({
    required int rideId,
    required double amount,
    required double todayTotal,
  }) async {
    await initialize();
    _showNotification(
      title: '💰 Ganho recebido',
      body: 'Você ganhou R\$ ${amount.toStringAsFixed(2)} nesta corrida. Hoje: R\$ ${todayTotal.toStringAsFixed(2)}',
      tag: 'motogo-earnings-$rideId',
    );
  }

  static Future<void> showRideStatus({
    required int rideId,
    required String status,
    required String message,
  }) async {
    await initialize();
    await stopIncomingRide();
    await _playAlert(volume: 0.7);

    _showNotification(
      title: 'MotoGo • $status',
      body: message,
      tag: 'motogo-status-$rideId-$status',
    );
  }
}
