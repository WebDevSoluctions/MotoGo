<?php
declare(strict_types=1);
require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../config/feature_schema.php';
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Headers: Content-Type');
header('Access-Control-Allow-Methods: GET, OPTIONS');
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(204); exit; }
try {
    if ($_SERVER['REQUEST_METHOD'] !== 'GET') { http_response_code(405); echo json_encode(['success'=>false,'message'=>'Método não permitido.'], JSON_UNESCAPED_UNICODE); exit; }
    $userId=(int)($_GET['user_id']??0);
    if($userId<=0) throw new InvalidArgumentException('Usuário inválido.');
    $db=Database::connect();
    ensureMotoGoLocationSchema($db);
    ensureMotoGoFeatureSchema($db);
    $s=$db->prepare('SELECT id,name,email,phone,city,state,profile_photo,status,created_at FROM users WHERE id=? LIMIT 1');
    $s->execute([$userId]);
    $u=$s->fetch(PDO::FETCH_ASSOC);
    if(!$u){http_response_code(404); echo json_encode(['success'=>false,'message'=>'Usuário não encontrado.'],JSON_UNESCAPED_UNICODE);exit;}
    $ratingStmt=$db->prepare("SELECT COALESCE(ROUND(AVG(rating),1),5.0) FROM client_ratings WHERE user_id=?");
    $ratingStmt->execute([$userId]);
    $clientRating=(float)$ratingStmt->fetchColumn();
    $ridesStmt=$db->prepare("SELECT COUNT(*) FROM rides WHERE user_id=? AND status='completed' AND ride_type NOT IN ('delivery_moto','delivery_bicicleta','delivery_pedestre')");
    $ridesStmt->execute([$userId]);
    $clientRides=(int)$ridesStmt->fetchColumn();
    $deliveryStmt=$db->prepare("SELECT COUNT(*) FROM rides WHERE user_id=? AND status='completed' AND ride_type IN ('delivery_moto','delivery_bicicleta','delivery_pedestre')");
    $deliveryStmt->execute([$userId]);
    $clientDeliveries=(int)$deliveryStmt->fetchColumn();
    echo json_encode(['success'=>true,'user'=>[
        'id'=>(int)$u['id'],'name'=>$u['name'],'email'=>$u['email'],'phone'=>$u['phone'],'city'=>$u['city'],'state'=>$u['state'],'profile_photo'=>$u['profile_photo'],'status'=>$u['status'],'created_at'=>$u['created_at'],
        'rating'=>$clientRating,'total_rides'=>$clientRides,'total_deliveries'=>$clientDeliveries
    ]],JSON_UNESCAPED_UNICODE);
} catch(InvalidArgumentException $e){http_response_code(422);echo json_encode(['success'=>false,'message'=>$e->getMessage()],JSON_UNESCAPED_UNICODE);} catch(Throwable $e){http_response_code(500);echo json_encode(['success'=>false,'message'=>'Erro ao carregar perfil.','error'=>$e->getMessage()],JSON_UNESCAPED_UNICODE);}
