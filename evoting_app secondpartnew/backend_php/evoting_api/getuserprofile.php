<?php
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

header('Content-Type: application/json');
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");

include 'config.php';

// Handle OPTIONS request for CORS
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    echo json_encode(["success" => true]);
    exit;
}

// Only accept POST
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    echo json_encode(["success" => false, "message" => "Invalid request method"]);
    exit;
}

// Check POST param
if (!isset($_POST['citizen_number'])) {
    echo json_encode(["success" => false, "message" => "citizen_number not provided"]);
    exit;
}

$citizenNumber = $_POST['citizen_number'];

// Prepare query
$query = $conn->prepare("SELECT fullname, face_photo, district FROM users WHERE citizen_number=?");
if (!$query) {
    echo json_encode(["success" => false, "message" => "Prepare failed: ".$conn->error]);
    exit;
}

$query->bind_param("s", $citizenNumber);
$query->execute();
$result = $query->get_result();

$user = $result->fetch_assoc();

if ($user) {
    $face_photo = null;
    if (!empty($user['face_photo'])) {
        $face_photo = base64_encode($user['face_photo']); // BLOB to base64
    }

    echo json_encode([
        "success" => true,
        "fullname" => $user['fullname'],
        "face_photo" => $face_photo,
        "district" => $user['district']
    ]);
} else {
    echo json_encode(["success" => false, "message" => "User not found"]);
}
?>
