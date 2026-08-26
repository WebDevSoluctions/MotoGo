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
    // DADOS
    // ============================================================

    $latitude = $input['latitude'] ?? null;

    $longitude = $input['longitude'] ?? null;

    $type = trim(
        (string) ($input['type'] ?? '')
    );

    $radiusKm = isset($input['radius_km'])
        ? (float) $input['radius_km']
        : 5.0;

    // ============================================================
    // VALIDAR LATITUDE
    // ============================================================

    if (
        $latitude === null ||
        $latitude === ''
    ) {
        throw new InvalidArgumentException(
            'Latitude é obrigatória.'
        );
    }

    if (!is_numeric($latitude)) {
        throw new InvalidArgumentException(
            'Latitude inválida.'
        );
    }

    $latitude = (float) $latitude;

    if (
        $latitude < -90 ||
        $latitude > 90
    ) {
        throw new InvalidArgumentException(
            'Latitude fora do intervalo permitido.'
        );
    }

    // ============================================================
    // VALIDAR LONGITUDE
    // ============================================================

    if (
        $longitude === null ||
        $longitude === ''
    ) {
        throw new InvalidArgumentException(
            'Longitude é obrigatória.'
        );
    }

    if (!is_numeric($longitude)) {
        throw new InvalidArgumentException(
            'Longitude inválida.'
        );
    }

    $longitude = (float) $longitude;

    if (
        $longitude < -180 ||
        $longitude > 180
    ) {
        throw new InvalidArgumentException(
            'Longitude fora do intervalo permitido.'
        );
    }

    // ============================================================
    // TIPOS DE SERVIÇO
    // ============================================================

    $allowedTypes = [
        'mototaxi',
        'carro',
        'delivery_moto',
        'delivery_bicicleta',
        'delivery_pedestre',
    ];

    if (!in_array(
        $type,
        $allowedTypes,
        true
    )) {
        throw new InvalidArgumentException(
            'Tipo de serviço inválido.'
        );
    }

    // ============================================================
    // RAIO
    // ============================================================

    if ($radiusKm <= 0) {
        $radiusKm = 5.0;
    }

    if ($radiusKm > 50) {
        $radiusKm = 50.0;
    }

    // ============================================================
    // CONVERTER TIPO DO SERVIÇO
    // ============================================================

    $driverType = match ($type) {

        'mototaxi' =>
            'moto',

        'carro' =>
            'carro',

        'delivery_moto' =>
            'delivery_moto',

        'delivery_bicicleta' =>
            'delivery_bicicleta',

        'delivery_pedestre' =>
            'delivery_pedestre',

        default =>
            null,
    };

    if ($driverType === null) {
        throw new InvalidArgumentException(
            'Tipo de motorista inválido.'
        );
    }

    // ============================================================
    // CONEXÃO
    // ============================================================

    $db = Database::connect();
    ensureMotoGoFeatureSchema($db);

    // ============================================================
    // BUSCAR MOTORISTAS
    // ============================================================

    /*
     * IMPORTANTE:
     *
     * Cada parâmetro possui um nome diferente.
     *
     * Isso evita conflito com PDO quando
     * ATTR_EMULATE_PREPARES = false.
     */

    $sql = '
        SELECT

            d.id AS driver_id,

            d.user_id,

            d.driver_type,

            d.rating,

            d.total_rides,

            d.total_deliveries,

            d.current_latitude,

            d.current_longitude,

            d.last_location_at,

            u.name,

            u.profile_photo,

            v.id AS vehicle_id,

            v.vehicle_type,

            v.brand,

            v.model,

            v.year,

            v.color,

            v.plate,

            (
                6371 * ACOS(
                    LEAST(
                        1,
                        GREATEST(
                            -1,

                            COS(
                                RADIANS(:lat1)
                            )

                            *

                            COS(
                                RADIANS(
                                    d.current_latitude
                                )
                            )

                            *

                            COS(
                                RADIANS(
                                    d.current_longitude
                                )
                                -
                                RADIANS(:lon1)
                            )

                            +

                            SIN(
                                RADIANS(:lat2)
                            )

                            *

                            SIN(
                                RADIANS(
                                    d.current_latitude
                                )
                            )
                        )
                    )
                )
            ) AS distance_km

        FROM drivers d

        INNER JOIN users u
            ON u.id = d.user_id

        LEFT JOIN vehicles v
            ON v.driver_id = d.id
            AND v.status = "approved"

        WHERE

            d.driver_type = :driver_type

            AND d.online = 1

            AND d.available = 1

            AND d.status = "active"

            AND d.verification_status = "approved"

            AND d.current_latitude IS NOT NULL

            AND d.current_longitude IS NOT NULL

            AND d.last_location_at IS NOT NULL

            AND NOT EXISTS (
                SELECT 1
                FROM driver_invoices di
                WHERE di.driver_id = d.id
                  AND di.status <> \'paid\'
                  AND (
                        di.status = \'overdue\'
                        OR (
                            COALESCE(di.due_at, CONCAT(di.due_date, \' 23:59:59\')) IS NOT NULL
                            AND COALESCE(di.due_at, CONCAT(di.due_date, \' 23:59:59\')) <= NOW()
                        )
                  )
            )

        HAVING distance_km <= :radius

        ORDER BY distance_km ASC

        LIMIT 20
    ';

    // ============================================================
    // PREPARAR
    // ============================================================

    $stmt = $db->prepare($sql);

    // ============================================================
    // PARÂMETROS
    // ============================================================

    $stmt->bindValue(
        ':lat1',
        $latitude
    );

    $stmt->bindValue(
        ':lon1',
        $longitude
    );

    $stmt->bindValue(
        ':lat2',
        $latitude
    );

    $stmt->bindValue(
        ':driver_type',
        $driverType
    );

    $stmt->bindValue(
        ':radius',
        $radiusKm
    );

    // ============================================================
    // EXECUTAR
    // ============================================================

    $stmt->execute();

    $drivers = $stmt->fetchAll();

    // ============================================================
    // FORMATAR RESULTADOS
    // ============================================================

    $results = [];

    foreach ($drivers as $driver) {

        $results[] = [

            'driver' => [

                'id' =>
                    (int) $driver['driver_id'],

                'user_id' =>
                    (int) $driver['user_id'],

                'name' =>
                    $driver['name'],

                'profile_photo' =>
                    $driver['profile_photo'],

                'type' =>
                    $driver['driver_type'],

                'rating' =>
                    (float) $driver['rating'],

                'total_rides' =>
                    (int) $driver['total_rides'],

                'total_deliveries' =>
                    (int) $driver['total_deliveries'],
            ],

            'location' => [

                'latitude' =>
                    (float) $driver['current_latitude'],

                'longitude' =>
                    (float) $driver['current_longitude'],

                'distance_km' =>
                    round(
                        (float) $driver['distance_km'],
                        2
                    ),

                'last_location_at' =>
                    $driver['last_location_at'],
            ],

            'vehicle' =>
                $driver['vehicle_id'] !== null

                    ? [

                        'id' =>
                            (int) $driver['vehicle_id'],

                        'type' =>
                            $driver['vehicle_type'],

                        'brand' =>
                            $driver['brand'],

                        'model' =>
                            $driver['model'],

                        'year' =>
                            $driver['year'] !== null
                                ? (int) $driver['year']
                                : null,

                        'color' =>
                            $driver['color'],

                        'plate' =>
                            $driver['plate'],
                    ]

                    : null,
        ];
    }

    // ============================================================
    // RESPOSTA
    // ============================================================

    http_response_code(200);

    echo json_encode(
        [
            'success' => true,

            'message' =>
                count($results) > 0
                    ? 'Motoristas encontrados.'
                    : 'Nenhum motorista disponível próximo.',

            'search' => [

                'type' =>
                    $type,

                'latitude' =>
                    $latitude,

                'longitude' =>
                    $longitude,

                'radius_km' =>
                    $radiusKm,

                'total' =>
                    count($results),
            ],

            'drivers' =>
                $results,
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

    /*
     * Durante desenvolvimento mostramos
     * o erro real do MySQL para facilitar
     * a identificação de problemas.
     */

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