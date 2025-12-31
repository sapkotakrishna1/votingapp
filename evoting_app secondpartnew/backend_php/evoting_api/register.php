<?php
require "config.php";

// -------------------- Headers --------------------
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') exit(0);

// -------------------- Get POST data --------------------
$fullname       = $_POST['fullname'] ?? null;
$dob            = $_POST['dob'] ?? null;
$district       = $_POST['district'] ?? null;
$citizen_number = $_POST['citizen_number'] ?? null;
$phone          = $_POST['phone'] ?? null;
$password       = $_POST['password'] ?? null;
$frontBase64    = $_POST['front_image'] ?? null;
$backBase64     = $_POST['back_image'] ?? null;
$faceBase64     = $_POST['face_image'] ?? null; // Selfie

// -------------------- Validate required fields --------------------
if (!$fullname || !$dob || !$district || !$citizen_number || !$phone || !$password || !$frontBase64 || !$backBase64 || !$faceBase64) {
    http_response_code(400);
    echo json_encode(["error" => "Missing required fields"]);
    exit;
}

// -------------------- Validate citizen number --------------------
if (!preg_match('/^\d{2}-\d{2}-\d{2}-\d{5}$/', $citizen_number)) {
    http_response_code(422);
    echo json_encode(["error" => "Invalid citizen number format. Expected xx-xx-xx-xxxxx"]);
    exit;
}

// -------------------- Check if citizen number exists --------------------
$stmt = $conn->prepare("SELECT id FROM users WHERE citizen_number = ?");
$stmt->bind_param("s", $citizen_number);
$stmt->execute();
$stmt->store_result();
if ($stmt->num_rows > 0) {
    http_response_code(409);
    echo json_encode(["error" => "Citizen number already exists"]);
    $stmt->close();
    $conn->close();
    exit;
}
$stmt->close();

// -------------------- Check if phone number exists --------------------
$stmt = $conn->prepare("SELECT id FROM users WHERE phone = ?");
$stmt->bind_param("s", $phone);
$stmt->execute();
$stmt->store_result();
if ($stmt->num_rows > 0) {
    http_response_code(409);
    echo json_encode(["error" => "Phone number already exists"]);
    $stmt->close();
    $conn->close();
    exit;
}
$stmt->close();

// -------------------- Decode Base64 images --------------------
function decodeImage($base64) {
    $data = preg_replace('#^data:image/[^;]+;base64,#', '', $base64);
    return base64_decode(str_replace([' ', "\r", "\n"], '', $data));
}

$frontData = decodeImage($frontBase64);
$backData  = decodeImage($backBase64);
$faceData  = decodeImage($faceBase64);

// -------------------- Hash password --------------------
$hashed = password_hash($password, PASSWORD_DEFAULT);

// -------------------- Insert user into database --------------------
$stmt = $conn->prepare("
    INSERT INTO users (fullname, dob, district, citizen_number, phone, password, front_image, back_image, face_photo)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
");

$null = NULL;
$stmt->bind_param("ssssssbbb", $fullname, $dob, $district, $citizen_number, $phone, $hashed, $null, $null, $null);

$stmt->send_long_data(6, $frontData);
$stmt->send_long_data(7, $backData);
$stmt->send_long_data(8, $faceData);

if ($stmt->execute()) {
    $userId = $stmt->insert_id;

    // -------------------- Generate embedding using Python --------------------
    $tmpFile = tempnam(sys_get_temp_dir(), 'selfie_') . ".jpg";
    file_put_contents($tmpFile, $faceData);

    $cmd = "python3 generate_embedding.py " . escapeshellarg($tmpFile);
    $embeddingJson = shell_exec($cmd);

    if ($embeddingJson !== null && $embeddingJson !== "") {
        $stmt2 = $conn->prepare("UPDATE users SET embedding = ? WHERE id = ?");
        $stmt2->bind_param("si", $embeddingJson, $userId);
        $stmt2->execute();
        $stmt2->close();
    }

    http_response_code(200);
    echo json_encode(["success" => "Registration Successful"]);
} else {
    http_response_code(500);
    echo json_encode(["error" => $stmt->error]);
}

$stmt->close();
$conn->close();
?>
