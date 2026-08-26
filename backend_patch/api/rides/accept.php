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

    echo json_encode([
        'success' => false,
        'message' => 'Método não permitido. Use POST.',
    ], JSON_UNESCAPED_UNICODE);

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

    $rideId = (int) (
        $input['ride_id'] ?? 0
    );

    $driverId = (int) (
        $input['driver_id'] ?? 0
    );

    // ============================================================
    // VALIDAÇÕES
    // ============================================================

    if ($rideId <= 0) {
        throw new InvalidArgumentException(
            'ID da corrida é obrigatório.'
        );
    }

    if ($driverId <= 0) {
        throw new InvalidArgumentException(
            'ID do motorista é obrigatório.'
        );
    }

    // ============================================================
    // CONEXÃO
    // ============================================================

    $db = Database::connect();
    ensureMotoGoFeatureSchema($db);

    // ============================================================
    // INICIAR TRANSAÇÃO
    // ============================================================

    $db->beginTransaction();

    // ============================================================
    // BUSCAR CORRIDA COM LOCK
    // ============================================================

    /*
     * FOR UPDATE impede que dois motoristas
     * aceitem a mesma corrida ao mesmo tempo.
     */

    $rideStmt = $db->prepare(
        'SELECT
            id,
            ride_code,
            user_id,
            driver_id,
            vehicle_id,
            ride_type,
            status,
            total_fare,
            created_at
         FROM rides
         WHERE id = :ride_id
         LIMIT 1
         FOR UPDATE'
    );

    $rideStmt->execute([
        ':ride_id' => $rideId,
    ]);

    $ride = $rideStmt->fetch(PDO::FETCH_ASSOC);

    // ============================================================
    // CORRIDA NÃO ENCONTRADA
    // ============================================================

    if (!$ride) {

        $db->rollBack();

        http_response_code(404);

        echo json_encode([
            'success' => false,
            'message' => 'Corrida não encontrada.',
        ], JSON_UNESCAPED_UNICODE);

        exit;
    }

    // ============================================================
    // VERIFICAR STATUS
    // ============================================================

    if ($ride['status'] !== 'pending') {

        $db->rollBack();

        http_response_code(409);

        echo json_encode([
            'success' => false,
            'message' =>
                'Esta corrida não está mais disponível.',
            'status' =>
                $ride['status'],
        ], JSON_UNESCAPED_UNICODE);

        exit;
    }

    // ============================================================
    // VERIFICAR SE JÁ POSSUI MOTORISTA
    // ============================================================

    if ($ride['driver_id'] !== null) {

        $db->rollBack();

        http_response_code(409);

        echo json_encode([
            'success' => false,
            'message' =>
                'Esta corrida já foi atribuída a um motorista.',
        ], JSON_UNESCAPED_UNICODE);

        exit;
    }

    // ============================================================
    // VERIFICAR EXPIRAÇÃO
    // ============================================================

    $expiryStmt = $db->prepare(
        "SELECT
            CASE
                WHEN created_at < DATE_SUB(
                    CURRENT_TIMESTAMP,
                    INTERVAL 10 MINUTE
                )
                THEN 1
                ELSE 0
            END AS is_expired
         FROM rides
         WHERE id = :ride_id
         LIMIT 1"
    );

    $expiryStmt->execute([
        ':ride_id' => $rideId,
    ]);

    $expiryResult = $expiryStmt->fetch(
        PDO::FETCH_ASSOC
    );

    $isExpired =
        isset($expiryResult['is_expired']) &&
        (int) $expiryResult['is_expired'] === 1;

    if ($isExpired) {

        // --------------------------------------------------------
        // CORRIDA EXPIROU
        // --------------------------------------------------------

        $expireStmt = $db->prepare(
            "UPDATE rides
             SET status = 'expired',
                 updated_at = CURRENT_TIMESTAMP
             WHERE id = :ride_id
               AND status = 'pending'
               AND driver_id IS NULL
               AND created_at < DATE_SUB(
                   CURRENT_TIMESTAMP,
                   INTERVAL 10 MINUTE
               )"
        );

        $expireStmt->execute([
            ':ride_id' => $rideId,
        ]);

        $db->commit();

        http_response_code(409);

        echo json_encode([
            'success' => false,
            'message' =>
                'Esta corrida expirou e não está mais disponível.',
            'status' =>
                'expired',
        ], JSON_UNESCAPED_UNICODE);

        exit;
    }

    // ============================================================
    // VERIFICAR SE ESTE MOTORISTA JÁ RECUSOU
    // ============================================================

    $rejectionStmt = $db->prepare(
        'SELECT
            id
         FROM ride_rejections
         WHERE ride_id = :ride_id
           AND driver_id = :driver_id
         LIMIT 1'
    );

    $rejectionStmt->execute([
        ':ride_id' =>
            $rideId,

        ':driver_id' =>
            $driverId,
    ]);

    $alreadyRejected =
        $rejectionStmt->fetch(
            PDO::FETCH_ASSOC
        );

    if ($alreadyRejected) {

        $db->rollBack();

        http_response_code(409);

        echo json_encode([
            'success' => false,
            'message' =>
                'Você já recusou esta corrida.',
        ], JSON_UNESCAPED_UNICODE);

        exit;
    }

    // ============================================================
    // VERIFICAR MOTORISTA
    // ============================================================

    $driverStmt = $db->prepare(
        'SELECT
            id,
            user_id,
            driver_type,
            online,
            available,
            verification_status,
            status
         FROM drivers
         WHERE id = :driver_id
         LIMIT 1
         FOR UPDATE'
    );

    $driverStmt->execute([
        ':driver_id' =>
            $driverId,
    ]);

    $driver = $driverStmt->fetch(
        PDO::FETCH_ASSOC
    );

    // ============================================================
    // MOTORISTA NÃO ENCONTRADO
    // ============================================================

    if (!$driver) {

        $db->rollBack();

        http_response_code(404);

        echo json_encode([
            'success' => false,
            'message' =>
                'Motorista não encontrado.',
        ], JSON_UNESCAPED_UNICODE);

        exit;
    }

    // ============================================================
    // MOTORISTA ATIVO
    // ============================================================

    if ($driver['status'] !== 'active') {

        $blockDriver = $db->prepare(
            "UPDATE drivers
             SET online = 0, available = 0, updated_at = CURRENT_TIMESTAMP
             WHERE id = :driver_id"
        );
        $blockDriver->execute([':driver_id' => $driverId]);

        $db->commit();

        http_response_code(403);

        echo json_encode([
            'success' => false,
            'message' =>
                'Motorista não está ativo.',
        ], JSON_UNESCAPED_UNICODE);

        exit;
    }

    // ============================================================
    // MOTORISTA APROVADO
    // ============================================================

    if (
        $driver['verification_status'] !== 'approved'
    ) {

        $blockDriver = $db->prepare(
            "UPDATE drivers
             SET online = 0, available = 0, updated_at = CURRENT_TIMESTAMP
             WHERE id = :driver_id"
        );
        $blockDriver->execute([':driver_id' => $driverId]);

        $db->commit();

        http_response_code(403);

        echo json_encode([
            'success' => false,
            'message' =>
                'Motorista ainda não foi aprovado.',
        ], JSON_UNESCAPED_UNICODE);

        exit;
    }

    // ============================================================
    // MOTORISTA ONLINE
    // ============================================================

    if ((int) $driver['online'] !== 1) {

        $db->rollBack();

        http_response_code(403);

        echo json_encode([
            'success' => false,
            'message' =>
                'Motorista está offline.',
        ], JSON_UNESCAPED_UNICODE);

        exit;
    }

    // ============================================================
    // MOTORISTA DISPONÍVEL
    // ============================================================

    if ((int) $driver['available'] !== 1) {

        $db->rollBack();

        http_response_code(409);

        echo json_encode([
            'success' => false,
            'message' =>
                'Motorista não está disponível.',
        ], JSON_UNESCAPED_UNICODE);

        exit;
    }

    // ============================================================
    // BLOQUEIO FINANCEIRO
    // ============================================================

    /*
     * O motorista não pode aceitar novas corridas
     * se existir uma fatura vencida.
     *
     * Consideramos vencida quando:
     *
     * 1. status = overdue
     *
     * OU
     *
     * 2. ainda não está paga e due_date já passou.
     */

    $overdueInvoiceStmt = $db->prepare(
        "SELECT
            id,
            amount,
            status,
            due_date,
            due_at,
            period_start,
            period_end
         FROM driver_invoices
         WHERE driver_id = :driver_id
           AND status <> 'paid'
           AND (
                status = 'overdue'
                OR (
                    COALESCE(due_at, CONCAT(due_date, ' 23:59:59')) IS NOT NULL
                    AND COALESCE(due_at, CONCAT(due_date, ' 23:59:59')) <= NOW()
                )
           )
         ORDER BY due_date ASC, id ASC
         LIMIT 1
         FOR UPDATE"
    );

    $overdueInvoiceStmt->execute([
        ':driver_id' => $driverId,
    ]);

    $overdueInvoice =
        $overdueInvoiceStmt->fetch(
            PDO::FETCH_ASSOC
        );

    if ($overdueInvoice) {

        // --------------------------------------------------------
        // GARANTIR STATUS OVERDUE
        // --------------------------------------------------------

        if (
            $overdueInvoice['status'] !== 'overdue'
        ) {

            $markOverdueStmt = $db->prepare(
                "UPDATE driver_invoices
                 SET status = 'overdue',
                     updated_at = CURRENT_TIMESTAMP
                 WHERE id = :invoice_id
                   AND status <> 'paid'"
            );

            $markOverdueStmt->execute([
                ':invoice_id' =>
                    (int) $overdueInvoice['id'],
            ]);
        }

        $db->rollBack();

        http_response_code(403);

        echo json_encode([
            'success' => false,

            'code' =>
                'invoice_overdue',

            'message' =>
                'Você possui uma fatura vencida. Regularize seu pagamento para continuar aceitando corridas.',

            'invoice' => [
                'id' =>
                    (int) $overdueInvoice['id'],

                'amount' =>
                    (float) $overdueInvoice['amount'],

                'status' =>
                    'overdue',

                'due_date' =>
                    $overdueInvoice['due_date'],

                'due_at' =>
                    $overdueInvoice['due_at'] ?? (($overdueInvoice['due_date'] ?? null) ? $overdueInvoice['due_date'] . ' 23:59:59' : null),

                'period_start' =>
                    $overdueInvoice['period_start'],

                'period_end' =>
                    $overdueInvoice['period_end'],
            ],
        ], JSON_UNESCAPED_UNICODE);

        exit;
    }

    // ============================================================
    // VERIFICAR COMPATIBILIDADE
    // ============================================================

    $requiredDriverType = match (
        $ride['ride_type']
    ) {

        'mototaxi' =>
            'moto',

        'carro' =>
            'carro',

        'delivery_moto' =>
            'moto',

        'delivery_pedestre' =>
            'delivery_pedestre',

        'delivery_bicicleta' =>
            'bicicleta',

        'viagem' =>
            in_array($driver['driver_type'], ['moto', 'carro'], true)
                ? $driver['driver_type']
                : null,

        default =>
            null,
    };

    if ($requiredDriverType === null) {

        $db->rollBack();

        throw new InvalidArgumentException(
            'Tipo de corrida não suportado.'
        );
    }

    // delivery_bicicleta é o tipo armazenado para o entregador
    // de bicicleta, enquanto a regra da corrida usa 'bicicleta'.
    // Normalizamos somente para a comparação, sem alterar o banco.
    $normalizedDriverType =
        $driver['driver_type'] === 'delivery_bicicleta'
            ? 'bicicleta'
            : $driver['driver_type'];

    // Entrega a pé é uma modalidade própria e não pode ser aceita
    // por moto, carro ou bicicleta.

    if (
        $normalizedDriverType
        !== $requiredDriverType
    ) {

        $db->rollBack();

        http_response_code(409);

        echo json_encode([
            'success' => false,
            'message' =>
                'Este motorista não pode aceitar este tipo de corrida.',
        ], JSON_UNESCAPED_UNICODE);

        exit;
    }

    // ============================================================
    // BUSCAR VEÍCULO APROVADO
    // ============================================================

    // Entregador de bicicleta não precisa de registro em vehicles.
    $vehicle = null;

    if ($requiredDriverType !== 'bicicleta') {
        $vehicleStmt = $db->prepare(
            'SELECT
                id,
                vehicle_type,
                brand,
                model,
                year,
                color,
                plate,
                status
             FROM vehicles
             WHERE
                driver_id = :driver_id
                AND vehicle_type = :vehicle_type
                AND status = :status
             ORDER BY id DESC
             LIMIT 1
             FOR UPDATE'
        );

        $vehicleStmt->execute([
            ':driver_id' => $driverId,
            ':vehicle_type' => $requiredDriverType,
            ':status' => 'approved',
        ]);

        $vehicle = $vehicleStmt->fetch(PDO::FETCH_ASSOC);

        if (!$vehicle) {
            $db->rollBack();
            http_response_code(409);
            echo json_encode([
                'success' => false,
                'message' => 'Motorista não possui veículo aprovado para esta corrida.',
            ], JSON_UNESCAPED_UNICODE);
            exit;
        }
    }

    // ============================================================
    // CALCULAR COMISSÃO
    // ============================================================

    /*
     * Comissão oficial da MotoGo:
     *
     * MotoGo = 10%
     * Motorista = 90%
     */

    $commissionPercent = 10.0;

    $grossAmount = round(
        (float) $ride['total_fare'],
        2
    );

    $commissionAmount = round(
        $grossAmount *
        ($commissionPercent / 100),
        2
    );

    $driverAmount = round(
        $grossAmount -
        $commissionAmount,
        2
    );

    // ============================================================
    // ATUALIZAR CORRIDA
    // ============================================================

    /*
     * Além do FOR UPDATE acima,
     * esta condição garante que a corrida
     * ainda está pendente e sem motorista.
     */

    $updateRide = $db->prepare(
        'UPDATE rides
         SET
            driver_id = :driver_id,
            vehicle_id = :vehicle_id,
            status = :status,
            updated_at = CURRENT_TIMESTAMP
         WHERE id = :ride_id
           AND status = :pending_status
           AND driver_id IS NULL'
    );

    $updateRide->execute([
        ':driver_id' =>
            $driverId,

        ':vehicle_id' =>
            $vehicle !== null ? (int) $vehicle['id'] : null,

        ':status' =>
            'driver_found',

        ':ride_id' =>
            $rideId,

        ':pending_status' =>
            'pending',
    ]);

    // ============================================================
    // GARANTIR QUE A CORRIDA FOI ATRIBUÍDA
    // ============================================================

    if ($updateRide->rowCount() !== 1) {

        $db->rollBack();

        http_response_code(409);

        echo json_encode([
            'success' => false,
            'message' =>
                'A corrida não está mais disponível.',
        ], JSON_UNESCAPED_UNICODE);

        exit;
    }

    // ============================================================
    // MOTORISTA FICA INDISPONÍVEL
    // ============================================================

    $updateDriver = $db->prepare(
        'UPDATE drivers
         SET available = 0
         WHERE id = :driver_id'
    );

    $updateDriver->execute([
        ':driver_id' =>
            $driverId,
    ]);

    // ============================================================
    // CRIAR COMISSÃO
    // ============================================================

    $commissionStmt = $db->prepare(
        'INSERT INTO commissions
        (
            ride_id,
            delivery_id,
            driver_id,
            gross_amount,
            commission_percent,
            commission_amount,
            driver_amount,
            status
        )
        VALUES
        (
            :ride_id,
            NULL,
            :driver_id,
            :gross_amount,
            :commission_percent,
            :commission_amount,
            :driver_amount,
            :status
        )'
    );

    $commissionStmt->execute([
        ':ride_id' =>
            $rideId,

        ':driver_id' =>
            $driverId,

        ':gross_amount' =>
            $grossAmount,

        ':commission_percent' =>
            $commissionPercent,

        ':commission_amount' =>
            $commissionAmount,

        ':driver_amount' =>
            $driverAmount,

        ':status' =>
            'pending',
    ]);

    $commissionId =
        (int) $db->lastInsertId();

    // ============================================================
    // CONFIRMAR TRANSAÇÃO
    // ============================================================

    $db->commit();

    // ============================================================
    // RESPOSTA
    // ============================================================

    http_response_code(200);

    echo json_encode([
        'success' => true,

        'message' =>
            'Corrida aceita com sucesso.',

        'ride' => [

            'id' =>
                $rideId,

            'ride_code' =>
                $ride['ride_code'],

            'status' =>
                'driver_found',

            'driver_id' =>
                $driverId,

            'vehicle_id' =>
                $vehicle !== null ? (int) $vehicle['id'] : null,
        ],

        'driver' => [

            'id' =>
                $driverId,

            'type' =>
                $driver['driver_type'],
        ],

        'vehicle' =>
            $vehicle !== null
                ? [
                    'id' => (int) $vehicle['id'],
                    'type' => $vehicle['vehicle_type'],
                    'brand' => $vehicle['brand'],
                    'model' => $vehicle['model'],
                    'year' => $vehicle['year'] !== null ? (int) $vehicle['year'] : null,
                    'color' => $vehicle['color'],
                    'plate' => $vehicle['plate'],
                ]
                : null,

        'commission' => [

            'id' =>
                $commissionId,

            'gross_amount' =>
                $grossAmount,

            'commission_percent' =>
                $commissionPercent,

            'commission_amount' =>
                $commissionAmount,

            'driver_amount' =>
                $driverAmount,

            'status' =>
                'pending',
        ],

    ], JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);

} catch (InvalidArgumentException $e) {

    if (
        isset($db) &&
        $db->inTransaction()
    ) {
        $db->rollBack();
    }

    http_response_code(422);

    echo json_encode([
        'success' => false,
        'message' =>
            $e->getMessage(),
    ], JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);

} catch (PDOException $e) {

    if (
        isset($db) &&
        $db->inTransaction()
    ) {
        $db->rollBack();
    }

    error_log(
        'Erro rides/accept.php: ' .
        $e->getMessage()
    );

    http_response_code(500);

    echo json_encode([
        'success' => false,
        'message' =>
            'Erro no banco de dados.',
    ], JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);

} catch (Throwable $e) {

    if (
        isset($db) &&
        $db->inTransaction()
    ) {
        $db->rollBack();
    }

    error_log(
        'Erro rides/accept.php: ' .
        $e->getMessage()
    );

    http_response_code(500);

    echo json_encode([
        'success' => false,
        'message' =>
            'Erro interno da API.',
    ], JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
}