<?php

declare(strict_types=1);

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../config/feature_schema.php';

header('Content-Type: application/json; charset=utf-8');

header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Headers: Content-Type');
header('Access-Control-Allow-Methods: POST, OPTIONS');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit;
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);

    echo json_encode(
        [
            'success' => false,
            'message' => 'Método não permitido. Use POST.',
        ],
        JSON_UNESCAPED_UNICODE
    );

    exit;
}

try {

    // ============================================================
    // CONFIGURAÇÃO DA MOTOgo
    // ============================================================

    /*
     * Comissão provisória da plataforma.
     *
     * Depois podemos colocar isso na tabela app_settings
     * para você alterar pelo painel administrativo.
     */
    $commissionPercent = 10.0;

    // O valor oficial pode ser alterado pelo administrador.
    // Será atualizado novamente após a conexão com o banco.

    // ============================================================
    // RECEBER JSON
    // ============================================================

    $input = json_decode(
        file_get_contents('php://input'),
        true
    );

    if (!is_array($input)) {
        throw new InvalidArgumentException(
            'JSON inválido.'
        );
    }

    // ============================================================
    // DADOS DO CLIENTE
    // ============================================================

    $userId = (int) (
        $input['user_id'] ?? 0
    );

    // ============================================================
    // TIPO DA CORRIDA
    // ============================================================

    $rideType = trim(
        (string) ($input['ride_type'] ?? '')
    );

    $allowedRideTypes = [
        'mototaxi',
        'carro',
        'delivery_moto',
        'delivery_bicicleta',
        'delivery_pedestre',
        'viagem',
    ];

    if (!in_array(
        $rideType,
        $allowedRideTypes,
        true
    )) {
        throw new InvalidArgumentException(
            'Tipo de corrida inválido. Use mototaxi, carro, delivery_moto, delivery_bicicleta ou delivery_pedestre.'
        );
    }

    // ============================================================
    // ORIGEM
    // ============================================================

    $originAddress = trim(
        (string) ($input['origin_address'] ?? '')
    );

    $originLatitude = $input['origin_latitude'] ?? null;

    $originLongitude = $input['origin_longitude'] ?? null;

    // ============================================================
    // DESTINO
    // ============================================================

    $destinationAddress = trim(
        (string) ($input['destination_address'] ?? '')
    );

    $destinationLatitude =
        $input['destination_latitude'] ?? null;

    $destinationLongitude =
        $input['destination_longitude'] ?? null;

    // ============================================================
    // DISTÂNCIA E DURAÇÃO
    // ============================================================

    $distanceKm = isset($input['distance_km'])
        ? (float) $input['distance_km']
        : 0.0;

    $durationMinutes = isset(
        $input['duration_minutes']
    )
        ? (float) $input['duration_minutes']
        : 0.0;

    // ============================================================
    // VALIDAÇÕES
    // ============================================================

    if ($userId <= 0) {
        throw new InvalidArgumentException(
            'ID do usuário é obrigatório.'
        );
    }

    if ($originAddress === '') {
        throw new InvalidArgumentException(
            'Endereço de origem é obrigatório.'
        );
    }

    if ($destinationAddress === '') {
        throw new InvalidArgumentException(
            'Endereço de destino é obrigatório.'
        );
    }

    if (
        $originLatitude === null ||
        $originLongitude === null
    ) {
        throw new InvalidArgumentException(
            'Localização de origem é obrigatória.'
        );
    }

    if (
        $destinationLatitude === null ||
        $destinationLongitude === null
    ) {
        throw new InvalidArgumentException(
            'Localização de destino é obrigatória.'
        );
    }

    if (
        !is_numeric($originLatitude) ||
        !is_numeric($originLongitude) ||
        !is_numeric($destinationLatitude) ||
        !is_numeric($destinationLongitude)
    ) {
        throw new InvalidArgumentException(
            'Coordenadas inválidas.'
        );
    }

    $originLatitude =
        (float) $originLatitude;

    $originLongitude =
        (float) $originLongitude;

    $destinationLatitude =
        (float) $destinationLatitude;

    $destinationLongitude =
        (float) $destinationLongitude;

    if (
        $originLatitude < -90 ||
        $originLatitude > 90 ||
        $destinationLatitude < -90 ||
        $destinationLatitude > 90
    ) {
        throw new InvalidArgumentException(
            'Latitude inválida.'
        );
    }

    if (
        $originLongitude < -180 ||
        $originLongitude > 180 ||
        $destinationLongitude < -180 ||
        $destinationLongitude > 180
    ) {
        throw new InvalidArgumentException(
            'Longitude inválida.'
        );
    }

    // ============================================================
    // OPCIONAIS — MOTOGO+
    // ============================================================

    $scheduledAt = trim((string)($input['scheduled_at'] ?? ''));
    $passengerName = trim((string)($input['passenger_name'] ?? ''));
    $passengerPhone = trim((string)($input['passenger_phone'] ?? ''));
    $favoriteDriverId = (int)($input['favorite_driver_id'] ?? 0);
    $stops = $input['stops'] ?? [];

    if ($scheduledAt !== '') {
        $scheduledDate = DateTime::createFromFormat('Y-m-d H:i:s', $scheduledAt);
        if (!$scheduledDate || $scheduledDate->getTimestamp() <= time()) {
            throw new InvalidArgumentException('O horário agendado precisa estar no futuro.');
        }
    } else {
        $scheduledAt = null;
    }

    if ($passengerName !== '' && mb_strlen($passengerName) < 2) {
        throw new InvalidArgumentException('Nome do passageiro inválido.');
    }

    if (!is_array($stops)) {
        throw new InvalidArgumentException('Paradas inválidas.');
    }
    if (count($stops) > 4) {
        throw new InvalidArgumentException('Você pode adicionar no máximo 4 paradas.');
    }
    foreach ($stops as $stop) {
        if (!is_array($stop) || !isset($stop['address'], $stop['latitude'], $stop['longitude'])) {
            throw new InvalidArgumentException('Cada parada precisa de endereço e coordenadas.');
        }
    }

    if ($favoriteDriverId > 0) {
        $fav = $db->prepare('SELECT 1 FROM favorite_drivers WHERE user_id=? AND driver_id=? LIMIT 1');
        $fav->execute([$userId, $favoriteDriverId]);
        if (!$fav->fetch()) {
            $favoriteDriverId = 0;
        }
    }
    if ($distanceKm < 0) {
        throw new InvalidArgumentException(
            'Distância inválida.'
        );
    }

    if ($durationMinutes < 0) {
        throw new InvalidArgumentException(
            'Duração inválida.'
        );
    }

    // ============================================================
    // CONEXÃO
    // ============================================================

    $db = Database::connect();
    ensureMotoGoFeatureSchema($db);

    // ============================================================
    // VERIFICAR CLIENTE
    // ============================================================

    $userStmt = $db->prepare(
        'SELECT
            id,
            status
         FROM users
         WHERE id = :user_id
         LIMIT 1'
    );

    $userStmt->execute(
        [
            ':user_id' => $userId,
        ]
    );

    $user = $userStmt->fetch();

    if (!$user) {
        http_response_code(404);

        echo json_encode(
            [
                'success' => false,
                'message' =>
                    'Usuário não encontrado.',
            ],
            JSON_UNESCAPED_UNICODE
        );

        exit;
    }

    if ($user['status'] !== 'active') {
        http_response_code(403);

        echo json_encode(
            [
                'success' => false,
                'message' =>
                    'Usuário não está ativo.',
            ],
            JSON_UNESCAPED_UNICODE
        );

        exit;
    }

    // ============================================================
    // CALCULAR TARIFA
    // ============================================================

    /*
     * Valores iniciais para teste.
     *
     * Depois vamos colocar isso em app_settings
     * para você alterar pelo painel.
     */

    // A tarifa oficial vem do painel administrativo.
    $db->exec("CREATE TABLE IF NOT EXISTS motogo_settings (
        setting_key VARCHAR(80) NOT NULL PRIMARY KEY,
        setting_value VARCHAR(255) NOT NULL,
        updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");

    $defaults = [
        'mototaxi_base'=>'5.00','mototaxi_per_km'=>'2.00',
        'car_base'=>'7.00','car_per_km'=>'3.00',
        'delivery_base'=>'7.00','delivery_per_km'=>'2.50',
        'bicycle_base'=>'6.00','bicycle_per_km'=>'1.80',
        'pedestrian_base'=>'5.00','pedestrian_per_km'=>'1.50',
        'commission_percent'=>'10.00','long_distance_limit_km'=>'50.00',
        'viagem_base'=>'80.00','viagem_per_km'=>'2.20',
    ];
    $seed = $db->prepare("INSERT IGNORE INTO motogo_settings (setting_key, setting_value) VALUES (:k,:v)");
    foreach ($defaults as $k=>$v) $seed->execute([':k'=>$k,':v'=>$v]);

    $settingStmt = $db->query("SELECT setting_key, setting_value FROM motogo_settings");
    $settings = [];
    foreach ($settingStmt->fetchAll(PDO::FETCH_ASSOC) as $row) $settings[$row['setting_key']] = (float)$row['setting_value'];

    switch ($rideType) {
        case 'mototaxi':
            $baseFare = $settings['mototaxi_base'];
            $pricePerKm = $settings['mototaxi_per_km'];
            break;
        case 'carro':
            $baseFare = $settings['car_base'];
            $pricePerKm = $settings['car_per_km'];
            break;
        case 'delivery_moto':
            $baseFare = $settings['delivery_base'];
            $pricePerKm = $settings['delivery_per_km'];
            break;
        case 'delivery_bicicleta':
            $baseFare = $settings['bicycle_base'];
            $pricePerKm = $settings['bicycle_per_km'];
            break;
        case 'delivery_pedestre':
            $baseFare = $settings['pedestrian_base'] ?? 5.00;
            $pricePerKm = $settings['pedestrian_per_km'] ?? 1.50;
            break;
        case 'viagem':
            $baseFare = $settings['viagem_base'];
            $pricePerKm = $settings['viagem_per_km'];
            break;
        default:
            throw new InvalidArgumentException('Tipo de corrida inválido.');
    }

    $longDistanceLimit = $settings['long_distance_limit_km'] ?? 50.0;

    // Acima do limite configurado, a solicitação passa a ser uma viagem longa.
    if ($distanceKm > $longDistanceLimit && $longDistanceLimit > 0) {
        $rideType = 'viagem';
        $baseFare = $settings['viagem_base'];
        $pricePerKm = $settings['viagem_per_km'];
    }

    $distanceFare =
        $distanceKm * $pricePerKm;

    $additionalFee = 0.00;

    $discount = 0.00;

    $totalFare =
        $baseFare
        + $distanceFare
        + $additionalFee
        - $discount;

    if ($totalFare < 0) {
        $totalFare = 0;
    }

    // ============================================================
    // COMISSÃO
    // ============================================================

    /*
     * A comissão é calculada agora e salva na corrida.
     *
     * O registro na tabela commissions será criado
     * quando houver motorista definido.
     */

    $commissionPercent = $settings['commission_percent'] ?? 10.0;

    $commissionAmount =
        $totalFare *
        ($commissionPercent / 100);

    $driverAmount =
        $totalFare -
        $commissionAmount;

    // ============================================================
    // GERAR CÓDIGO DA CORRIDA
    // ============================================================

    $rideCode =
        'MG'
        . date('YmdHis')
        . strtoupper(
            substr(
                bin2hex(
                    random_bytes(4)
                ),
                0,
                6
            )
        );

    // ============================================================
    // CRIAR CORRIDA
    // ============================================================

    $stmt = $db->prepare(
        'INSERT INTO rides
        (
            ride_code,
            user_id,
            ride_type,
            status,
            origin_address,
            destination_address,
            origin_latitude,
            origin_longitude,
            destination_latitude,
            destination_longitude,
            distance_km,
            duration_minutes,
            base_fare,
            distance_fare,
            additional_fee,
            discount,
            total_fare
        )
        VALUES
        (
            :ride_code,
            :user_id,
            :ride_type,
            :status,
            :origin_address,
            :destination_address,
            :origin_latitude,
            :origin_longitude,
            :destination_latitude,
            :destination_longitude,
            :distance_km,
            :duration_minutes,
            :base_fare,
            :distance_fare,
            :additional_fee,
            :discount,
            :total_fare
        )'
    );

    $stmt->execute(
        [
            ':ride_code' =>
                $rideCode,

            ':user_id' =>
                $userId,

            ':ride_type' =>
                $rideType,

            ':status' =>
                'pending',

            ':origin_address' =>
                $originAddress,

            ':destination_address' =>
                $destinationAddress,

            ':origin_latitude' =>
                $originLatitude,

            ':origin_longitude' =>
                $originLongitude,

            ':destination_latitude' =>
                $destinationLatitude,

            ':destination_longitude' =>
                $destinationLongitude,

            ':distance_km' =>
                $distanceKm,

            ':duration_minutes' =>
                $durationMinutes,

            ':base_fare' =>
                $baseFare,

            ':distance_fare' =>
                $distanceFare,

            ':additional_fee' =>
                $additionalFee,

            ':discount' =>
                $discount,

            ':total_fare' =>
                $totalFare,

        ]
    );

    $rideId =
        (int) $db->lastInsertId();

    // ============================================================
    // SALVAR RECURSOS MOTOGO+
    // ============================================================

    $featureStmt = $db->prepare(
        'INSERT INTO ride_features
        (ride_id, scheduled_at, passenger_name, passenger_phone, favorite_driver_id, stops_json)
        VALUES (:ride_id,:scheduled_at,:passenger_name,:passenger_phone,:favorite_driver_id,:stops_json)'
    );
    $featureStmt->execute([
        ':ride_id' => $rideId,
        ':scheduled_at' => $scheduledAt,
        ':passenger_name' => $passengerName !== '' ? $passengerName : null,
        ':passenger_phone' => $passengerPhone !== '' ? $passengerPhone : null,
        ':favorite_driver_id' => $favoriteDriverId > 0 ? $favoriteDriverId : null,
        ':stops_json' => $stops ? json_encode($stops, JSON_UNESCAPED_UNICODE) : null,
    ]);


    // ============================================================
    // RESPOSTA
    // ============================================================

    http_response_code(201);

    echo json_encode(
        [
            'success' => true,

            'message' =>
                'Corrida criada com sucesso.',

            'ride' => [

                'id' =>
                    $rideId,

                'ride_code' =>
                    $rideCode,

                'user_id' =>
                    $userId,

                'ride_type' =>
                    $rideType,

                'status' =>
                    'pending',

                'origin_address' =>
                    $originAddress,

                'destination_address' =>
                    $destinationAddress,

                'distance_km' =>
                    $distanceKm,

                'duration_minutes' =>
                    $durationMinutes,

                'base_fare' =>
                    round(
                        $baseFare,
                        2
                    ),

                'distance_fare' =>
                    round(
                        $distanceFare,
                        2
                    ),

                'additional_fee' =>
                    round(
                        $additionalFee,
                        2
                    ),

                'discount' =>
                    round(
                        $discount,
                        2
                    ),

                'total_fare' =>
                    round(
                        $totalFare,
                        2
                    ),

                'commission_percent' =>
                    $commissionPercent,

                'commission_amount' =>
                    round(
                        $commissionAmount,
                        2
                    ),

                'driver_amount' =>
                    round(
                        $driverAmount,
                        2
                    ),
            ],
        ],
        JSON_PRETTY_PRINT |
        JSON_UNESCAPED_UNICODE
    );

} catch (InvalidArgumentException $e) {

    http_response_code(422);

    echo json_encode(
        [
            'success' => false,
            'message' => $e->getMessage(),
        ],
        JSON_PRETTY_PRINT |
        JSON_UNESCAPED_UNICODE
    );

} catch (PDOException $e) {

    http_response_code(500);

    echo json_encode(
        [
            'success' => false,
            'message' =>
                'Erro no banco de dados.',
            'error' =>
                $e->getMessage(),
        ],
        JSON_PRETTY_PRINT |
        JSON_UNESCAPED_UNICODE
    );

} catch (Throwable $e) {

    http_response_code(500);

    echo json_encode(
        [
            'success' => false,
            'message' =>
                'Erro interno da API.',
            'error' =>
                $e->getMessage(),
        ],
        JSON_PRETTY_PRINT |
        JSON_UNESCAPED_UNICODE
    );
}