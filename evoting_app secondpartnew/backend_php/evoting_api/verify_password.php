<?php
// -------------------
// JSON output & error handling
// -------------------
ini_set('display_errors', 0); // hide PHP warnings in output
ini_set('display_startup_errors', 0);
error_reporting(0);

header('Content-Type: application/json');
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");

// -------------------
// Include DB config
// -------------------
include 'config.php'; // must define $conn

// -------------------
// Handle CORS preflight
// -------------------
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    echo json_encode(["success" => true]);
    exit;
}

// -------------------
// Only allow POST
// -------------------
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    echo json_encode(["success" => false, "message" => "Invalid request method"]);
    exit;
}

// -------------------
// Get JSON input
// -------------------
$input = file_get_contents("php://input");
$data = json_decode($input, true);

if (!$data || !is_array($data)) {
    echo json_encode(["success" => false, "message" => "Invalid JSON input"]);
    exit;
}

// -------------------
// Validate input
// -------------------
$citizenID = isset($data['citizenID']) ? trim($data['citizenID']) : '';
$password = isset($data['password']) ? trim($data['password']) : '';

if (empty($citizenID) || empty($password)) {
    echo json_encode(["success" => false, "message" => "citizenID or password not provided"]);
    exit;
}

// -------------------
// Fetch password hash
// -------------------
$stmt = $conn->prepare("SELECT password FROM users WHERE citizen_number=?");
if (!$stmt) {
    echo json_encode(["success" => false, "message" => "DB prepare failed: " . $conn->error]);
    exit;
}

$stmt->bind_param("s", $citizenID);
$stmt->execute();
$result = $stmt->get_result();

if (!$result) {
    echo json_encode(["success" => false, "message" => "DB query failed: " . $stmt->error]);
    exit;
}

// -------------------
// Verify password
// -------------------
if ($row = $result->fetch_assoc()) {
    $hashedPassword = $row['password'];

    if (password_verify($password, $hashedPassword)) {
        echo json_encode(["success" => true]);
    } else {
        echo json_encode(["success" => false, "message" => "Incorrect password"]);
    }
} else {
    echo json_encode(["success" => false, "message" => "User not found"]);
}

// -------------------
// Close
// -------------------
$stmt->close();
$conn->close();
exit;
?>
