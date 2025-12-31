<?php
include 'config.php';
error_reporting(E_ALL & ~E_NOTICE & ~E_WARNING);

header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");
header("Content-Type: application/json");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') exit(0);

$data = $_POST;

// Get data safely
$fullname       = $conn->real_escape_string($data['fullname'] ?? '');
$citizen_number = $conn->real_escape_string($data['citizen_number'] ?? ''); // <-- Added
$party          = $conn->real_escape_string($data['party'] ?? '');
$district       = $conn->real_escape_string($data['district'] ?? '');
$dob            = $conn->real_escape_string($data['dob'] ?? '');
$education      = $conn->real_escape_string($data['education'] ?? '');
$vision         = $conn->real_escape_string($data['vision'] ?? '');
$details        = $conn->real_escape_string($data['details'] ?? '');
$address        = $conn->real_escape_string($data['address'] ?? '');
$photo_base64   = $data['photo'] ?? null;

// Decode base64 if exists
$photo_blob = null;
if ($photo_base64) {
    $photo_blob = base64_decode(preg_replace('#^data:image/\w+;base64,#i', '', $photo_base64));
}

// Prepare SQL with BLOB placeholder and citizen_number
$stmt = $conn->prepare("INSERT INTO candidates 
    (fullname, citizen_number, party, district, dob, education, vision, details, address, photo)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)");

// Use "b" for BLOB
$stmt->bind_param(
    "sssssssssb",
    $fullname,
    $citizen_number, // <-- Added
    $party,
    $district,
    $dob,
    $education,
    $vision,
    $details,
    $address,
    $null // placeholder for BLOB
);

// Send photo data if exists
$null = null;
if ($photo_blob) {
    $stmt->send_long_data(9, $photo_blob); // index 9 = 10th parameter
}

if ($stmt->execute()) {
    echo json_encode(["status" => "success", "message" => "Candidate added successfully"]);
} else {
    echo json_encode(["status" => "error", "message" => $stmt->error]);
}

$stmt->close();
$conn->close();
?>
