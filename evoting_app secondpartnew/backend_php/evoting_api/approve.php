<?php
// --------------------------------------------------
// Clear any previous output and set JSON header
// --------------------------------------------------
ob_clean();
header("Content-Type: application/json");

// --------------------------------------------------
// Error logging
// --------------------------------------------------
ini_set('display_errors', 0);
ini_set('log_errors', 1);
ini_set('error_log', __DIR__ . '/php-error.log');
error_reporting(E_ALL);

// --------------------------------------------------
// CORS settings
// --------------------------------------------------
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    echo json_encode(["success" => true]);
    exit;
}

// --------------------------------------------------
// Include DB connection
// --------------------------------------------------
require "config.php";

// --------------------------------------------------
// Read JSON input
// --------------------------------------------------
$raw = file_get_contents("php://input");
$data = json_decode($raw, true);

if ($data === null) {
    echo json_encode(["error" => "Invalid JSON"]);
    exit;
}

// --------------------------------------------------
// Validate input
// --------------------------------------------------
if (!isset($data['citizen_number']) || !isset($data['approved'])) {
    echo json_encode(["error" => "Missing parameters"]);
    exit;
}

$citizen_number = $conn->real_escape_string($data['citizen_number']);
$approved = intval($data['approved']); // 1 = approve, 0 = reject

// --------------------------------------------------
// Update approved status
// --------------------------------------------------
$sql = "UPDATE users SET approved = $approved WHERE citizen_number = '$citizen_number'";

if ($conn->query($sql) === TRUE) {
    echo json_encode([
        "status" => "success",
        "message" => $approved ? "User approved" : "User rejected"
    ]);
} else {
    echo json_encode([
        "status" => "error",
        "message" => "Database error: " . $conn->error
    ]);
}

$conn->close();
?>
