class NotificationService {
  static Future<void> initialize() async {}

  static Future<void> prepareForUserInteraction() async {}

  static Future<void> scheduleDailyMotivation({required String accountType}) async {}

  static Future<void> cancelDailyMotivation() async {}

  static Future<void> showIncomingRide({
    required int rideId,
    required String passengerName,
    required String rideType,
    required double price,
    required String origin,
    required String destination,
  }) async {}
  static Future<void> stopIncomingRide({int? rideId}) async {}

  static Future<void> showChatMessage({required int rideId, required String senderName, required String message}) async {}

  static Future<void> showEarningsUpdate({
    required int rideId, required double amount, required double todayTotal,
  }) async {}

  static Future<void> showRideStatus({
    required int rideId,
    required String status,
    required String message,
  }) async {}

}
