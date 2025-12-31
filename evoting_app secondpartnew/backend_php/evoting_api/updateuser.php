<?php
include 'config.php';

// -------------------- Headers --------------------
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') exit(0);

// Get JSON data from Flutter
$data = json_decode(file_get_contents('php://input'), true);

// User ID (or citizen number)
$citizen_number = $conn->real_escape_string($data['citizen_number'] ?? '');
if (!$citizen_number) {
    echo json_encode(["success" => false, "message" => "Citizen number is required"]);
    exit;
}

$fullname = $conn->real_escape_string($data['fullname'] ?? '');
$district = $conn->real_escape_string($data['district'] ?? '');
$dob = $conn->real_escape_string($data['dob'] ?? '');
$phone = $conn->real_escape_string($data['phone'] ?? '');
$photo_base64 = $data['photo'] ?? null;

// Convert base64 to binary BLOB if photo is provided
$photo_blob = null;
if ($photo_base64) {
    $photo_blob = base64_decode(preg_replace('#^data:image/\w+;base64,#i', '', $photo_base64));
}

if ($photo_blob !== null) {
    // Update with BLOB photo
    $stmt = $conn->prepare("UPDATE users 
        SET fullname=?, district=?, dob=?, phone=?, face_photo=? 
        WHERE citizen_number=?");

    if (!$stmt) {
        echo json_encode(["success" => false, "message" => "Prepare failed: " . $conn->error]);
        exit;
    }

    $null = null; // placeholder for blob
    $stmt->bind_param(
        "sssssb",
        $fullname,
        $district,
        $dob,
        $phone,
        $null,
        $citizen_number
    );

    $stmt->send_long_data(4, $photo_blob);

} else {
    // Update without changing photo
    $stmt = $conn->prepare("UPDATE users 
        SET fullname=?, district=?, dob=?, phone=? 
        WHERE citizen_number=?");

    if (!$stmt) {
        echo json_encode(["success" => false, "message" => "Prepare failed: " . $conn->error]);
        exit;
    }

    $stmt->bind_param(
        "sssss",
        $fullname,
        $district,
        $dob,
        $phone,
        $citizen_number
    );
}

if ($stmt->execute()) {
    echo json_encode(["success" => true, "message" => "User updated successfully"]);
} else {
    echo json_encode(["success" => false, "message" => "Error: " . $stmt->error]);
}

$stmt->close();
$conn->close();
?>
