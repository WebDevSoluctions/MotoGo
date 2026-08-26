<?php

declare(strict_types=1);

require_once __DIR__ . '/../../config/database.php';

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Headers: Content-Type');
header('Access-Control-Allow-Methods: GET, OPTIONS');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit;
}

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    http_response_code(405);

    echo json_encode([
        'success' => false,
        'message' => 'Método não permitido. Use GET.',
    ], JSON_UNESCAPED_UNICODE);

    exit;
}

try {

    // ============================================================
    // DRIVER ID
    // ============================================================

    $driverId = (int) (
        $_GET['driver_id'] ?? 0
    );

    if ($driverId <= 0) {

        http_response_code(422);

        echo json_encode([
            'success' => false,
            'message' => 'ID do motorista é obrigatório.',
        ], JSON_UNESCAPED_UNICODE);

        exit;
    }

    // ============================================================
    // BANCO
    // ============================================================

    $db = Database::connect();

    // ============================================================
    // BUSCAR MOTORISTA
    // ============================================================

    $driverStmt = $db->prepare(
        'SELECT
            id,
            driver_type,
            online,
            available,
            verification_status,
            status
         FROM drivers
         WHERE id = :driver_id
         LIMIT 1'
    );

    $driverStmt->execute([
        ':driver_id' => $driverId,
    ]);

    $driver = $driverStmt->fetch(PDO::FETCH_ASSOC);

    // ============================================================
    // MOTORISTA NÃO ENCONTRADO
    // ============================================================

    if (!$driver) {

        http_response_code(404);

        echo json_encode([
            'success' => false,
            'message' => 'Motorista não encontrado.',
        ], JSON_UNESCAPED_UNICODE);

        exit;
    }

    // ============================================================
    // VALIDAR MOTORISTA ATIVO
    // ============================================================

    if ($driver['status'] !== 'active') {

        echo json_encode([
            'success' => true,
            'has_ride' => false,
            'message' => 'Motorista não está ativo.',
        ], JSON_UNESCAPED_UNICODE);

        exit;
    }

    // ============================================================
    // VALIDAR APROVAÇÃO
    // ============================================================

    if ($driver['verification_status'] !== 'approved') {

        echo json_encode([
            'success' => true,
            'has_ride' => false,
            'message' => 'Motorista ainda não foi aprovado.',
        ], JSON_UNESCAPED_UNICODE);

        exit;
    }

    // ============================================================
    // VALIDAR ONLINE
    // ============================================================

    if ((int) $driver['online'] !== 1) {

        echo json_encode([
            'success' => true,
            'has_ride' => false,
            'message' => 'Motorista está offline.',
        ], JSON_UNESCAPED_UNICODE);

        exit;
    }

    // ============================================================
    // VALIDAR DISPONIBILIDADE
    // ============================================================

    if ((int) $driver['available'] !== 1) {

        echo json_encode([
            'success' => true,
            'has_ride' => false,
            'message' => 'Motorista não está disponível.',
        ], JSON_UNESCAPED_UNICODE);

        exit;
    }

    // ============================================================
    // LOCALIZAÇÃO ATUAL DO MOTORISTA
    // ============================================================
    // A corrida só pode ser oferecida se o motorista estiver
    // fisicamente próximo do ponto de origem da solicitação.
    // Isso evita, por exemplo, uma corrida no Rio de Janeiro
    // aparecendo para um motorista em Tiradentes-MG.

    $locationStmt = $db->prepare(
        'SELECT current_latitude, current_longitude, last_location_at
         FROM drivers
         WHERE id = :driver_id
         LIMIT 1'
    );
    $locationStmt->execute([
        ':driver_id' => $driverId,
    ]);
    $driverLocation = $locationStmt->fetch(PDO::FETCH_ASSOC);

    if (!$driverLocation ||
        $driverLocation['current_latitude'] === null ||
        $driverLocation['current_longitude'] === null ||
        $driverLocation['last_location_at'] === null) {
        echo json_encode([
            'success' => true,
            'has_ride' => false,
            'message' => 'Aguardando localização GPS do motorista.',
        ], JSON_UNESCAPED_UNICODE);
        exit;
    }

    // Localização muito antiga não deve ser usada para distribuir corrida.
    $locationFreshStmt = $db->prepare(
        'SELECT 1
         FROM drivers
         WHERE id = :driver_id
           AND last_location_at >= DATE_SUB(CURRENT_TIMESTAMP, INTERVAL 2 MINUTE)
         LIMIT 1'
    );
    $locationFreshStmt->execute([
        ':driver_id' => $driverId,
    ]);
    if (!$locationFreshStmt->fetchColumn()) {
        echo json_encode([
            'success' => true,
            'has_ride' => false,
            'message' => 'Localização GPS do motorista desatualizada.',
        ], JSON_UNESCAPED_UNICODE);
        exit;
    }

    $driverLatitude = (float) $driverLocation['current_latitude'];
    $driverLongitude = (float) $driverLocation['current_longitude'];

    // Raio operacional para encontrar corridas próximas.
    // 20 km permite, por exemplo, Tiradentes <-> São João del-Rei,
    // mas impede uma corrida em outra região muito distante.
    $dispatchRadiusKm = 20.0;

    // ============================================================
    // TIPO DO MOTORISTA
    // ============================================================

    $driverType = (string) $driver['driver_type'];

    // ============================================================
    // TIPOS DE CORRIDA ACEITOS
    // ============================================================

    $rideTypes = [];

    switch ($driverType) {

        case 'moto':

            $rideTypes = [
                'mototaxi',
                'delivery_moto',
            ];

            break;

        case 'delivery_pedestre':
        case 'pedestre':

            // Entrega a pé é exclusiva para entregadores
            // cadastrados/aprovados nessa modalidade.
            $rideTypes = [
                'delivery_pedestre',
            ];

            break;

        case 'carro':

            $rideTypes = [
                'carro',
            ];

            break;

        case 'bicicleta':
        case 'delivery_bicicleta':

            // Entrega de bicicleta aceita solicitações
            // do tipo delivery_bicicleta.
            $rideTypes = [
                'delivery_bicicleta',
            ];

            break;

        default:

            echo json_encode([
                'success' => true,
                'has_ride' => false,
                'message' => 'Tipo de motorista não suportado.',
            ], JSON_UNESCAPED_UNICODE);

            exit;
    }

    // ============================================================
    // PLACEHOLDERS DOS TIPOS
    // ============================================================

    $typePlaceholders = [];

    foreach ($rideTypes as $index => $type) {

        $typePlaceholders[] =
            ':ride_type_' . $index;
    }

    $typesSql = implode(
        ', ',
        $typePlaceholders
    );

    // ============================================================
    // BUSCAR NOVA CORRIDA
    // ============================================================
    //
    // IMPORTANTE:
    //
    // Somente corridas pending criadas nos últimos 10 minutos
    // podem ser oferecidas como uma nova solicitação.
    //
    // Isso impede que corridas antigas de testes continuem
    // aparecendo para novos motoristas.
    //
    // Se o motorista já recusou a corrida, ela não volta
    // para esse mesmo motorista.
    //
    // Outro motorista poderá recebê-la.
    //
    // ============================================================

    $sql = "
        SELECT
            r.id,
            r.ride_code,
            r.user_id,
            r.driver_id,
            r.vehicle_id,
            r.ride_type,
            r.status,

            r.origin_address,
            r.destination_address,

            r.origin_latitude,
            r.origin_longitude,

            r.destination_latitude,
            r.destination_longitude,

            (
                6371 * ACOS(
                    LEAST(
                        1,
                        GREATEST(
                            -1,
                            COS(RADIANS(:driver_lat1))
                            * COS(RADIANS(r.origin_latitude))
                            * COS(RADIANS(r.origin_longitude) - RADIANS(:driver_lon))
                            + SIN(RADIANS(:driver_lat2))
                            * SIN(RADIANS(r.origin_latitude))
                        )
                    )
                )
            ) AS driver_origin_distance_km,

            r.distance_km,
            r.duration_minutes,

            r.total_fare,

            r.created_at,

            u.name AS passenger_name,
            u.phone AS passenger_phone,
            u.profile_photo AS passenger_photo

        FROM rides r

        INNER JOIN users u
            ON u.id = r.user_id

        WHERE

            -- =====================================================
            -- CORRIDA PRECISA ESTAR PENDENTE
            -- =====================================================

            r.status = :pending_status

            -- =====================================================
            -- AINDA NÃO FOI ATRIBUÍDA A OUTRO MOTORISTA
            -- =====================================================

            AND r.driver_id IS NULL

            -- =====================================================
            -- TIPO COMPATÍVEL COM O MOTORISTA
            -- =====================================================

            AND r.ride_type IN ($typesSql)

            -- A corrida precisa ter origem geográfica válida.
            AND r.origin_latitude IS NOT NULL
            AND r.origin_longitude IS NOT NULL

            -- =====================================================
            -- CORRIDA NOVA
            -- =====================================================
            --
            -- Evita entregar corridas antigas de testes.
            --

            AND r.created_at >=
                DATE_SUB(
                    CURRENT_TIMESTAMP,
                    INTERVAL 10 MINUTE
                )

            -- =====================================================
            -- MOTORISTA NÃO PODE RECEBER UMA CORRIDA QUE RECUSOU
            -- =====================================================

            AND NOT EXISTS (

                SELECT 1

                FROM ride_rejections rr

                WHERE
                    rr.ride_id = r.id

                    AND rr.driver_id =
                        :rejection_driver_id
            )

            -- =====================================================
            -- DISTÂNCIA ENTRE MOTORISTA E ORIGEM DA CORRIDA
            -- =====================================================
            -- O matching usa GPS, não cidade cadastrada.
            -- Ex.: Tiradentes pode receber São João del-Rei,
            -- mas não uma corrida do Rio de Janeiro.

        HAVING driver_origin_distance_km <= :dispatch_radius

        ORDER BY
            r.id ASC

        LIMIT 1
    ";

    // ============================================================
    // PREPARAR
    // ============================================================

    $rideStmt = $db->prepare($sql);

    // ============================================================
    // PARÂMETROS
    // ============================================================

    $params = [

        ':pending_status' =>
            'pending',

        ':rejection_driver_id' =>
            $driverId,

        ':driver_lat1' =>
            $driverLatitude,

        ':driver_lat2' =>
            $driverLatitude,

        ':driver_lon' =>
            $driverLongitude,

        ':dispatch_radius' =>
            $dispatchRadiusKm,
    ];

    foreach ($rideTypes as $index => $type) {

        $params[
            ':ride_type_' . $index
        ] = $type;
    }

    // ============================================================
    // EXECUTAR
    // ============================================================

    $rideStmt->execute($params);

    // ============================================================
    // RESULTADO
    // ============================================================

    $ride = $rideStmt->fetch(
        PDO::FETCH_ASSOC
    );

    // ============================================================
    // NENHUMA CORRIDA
    // ============================================================

    if (!$ride) {

        echo json_encode([
            'success' => true,
            'has_ride' => false,
            'message' =>
                'Nenhuma corrida disponível.',
        ], JSON_UNESCAPED_UNICODE);

        exit;
    }

    // ============================================================
    // CORRIDA ENCONTRADA
    // ============================================================

    echo json_encode([

        'success' => true,

        'has_ride' => true,

        'ride' => [

            'id' =>
                (int) $ride['id'],

            'ride_code' =>
                $ride['ride_code'],

            'user_id' =>
                (int) $ride['user_id'],

            'ride_type' =>
                $ride['ride_type'],

            'status' =>
                $ride['status'],

            'origin_address' =>
                $ride['origin_address'],

            'destination_address' =>
                $ride['destination_address'],

            'origin_latitude' =>
                $ride['origin_latitude'] !== null
                    ? (float) $ride['origin_latitude']
                    : null,

            'origin_longitude' =>
                $ride['origin_longitude'] !== null
                    ? (float) $ride['origin_longitude']
                    : null,

            'destination_latitude' =>
                $ride['destination_latitude'] !== null
                    ? (float) $ride['destination_latitude']
                    : null,

            'destination_longitude' =>
                $ride['destination_longitude'] !== null
                    ? (float) $ride['destination_longitude']
                    : null,

            'distance_km' =>
                $ride['distance_km'] !== null
                    ? (float) $ride['distance_km']
                    : null,

            'driver_origin_distance_km' =>
                $ride['driver_origin_distance_km'] !== null
                    ? (float) $ride['driver_origin_distance_km']
                    : null,

            'duration_minutes' =>
                $ride['duration_minutes'] !== null
                    ? (int) $ride['duration_minutes']
                    : null,

            'total_fare' =>
                (float) $ride['total_fare'],

            'created_at' =>
                $ride['created_at'],
        ],

        'passenger' => [

            'id' =>
                (int) $ride['user_id'],

            'name' =>
                $ride['passenger_name'],

            'phone' =>
                $ride['passenger_phone'],

            'profile_photo' =>
                $ride['passenger_photo'],
        ],

    ], JSON_UNESCAPED_UNICODE);

} catch (PDOException $e) {

    http_response_code(500);

    echo json_encode([

        'success' => false,

        'message' =>
            'Erro no banco de dados.',

        'error' =>
            $e->getMessage(),

    ], JSON_UNESCAPED_UNICODE);

} catch (Throwable $e) {

    http_response_code(500);

    echo json_encode([

        'success' => false,

        'message' =>
            'Erro interno da API.',

        'error' =>
            $e->getMessage(),

    ], JSON_UNESCAPED_UNICODE);
}