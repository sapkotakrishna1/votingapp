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
// Extract and trim fields
// --------------------------------------------------
$citizen_number = trim($data['citizen_number'] ?? '');
$password = trim($data['password'] ?? '');

if (!$citizen_number || !$password) {
    echo json_encode(["error" => "Citizen number and password are required"]);
    exit;
}

// --------------------------------------------------
// USER LOGIN (hashed only) with approval check
// --------------------------------------------------
$stmt = $conn->prepare("SELECT id, fullname, password, district, approved FROM users WHERE citizen_number = ?");
if (!$stmt) {
    echo json_encode(["error" => "Server error"]);
    exit;
}

$stmt->bind_param("s", $citizen_number);
$stmt->execute();
$result = $stmt->get_result();

if ($result && $result->num_rows > 0) {
    $user = $result->fetch_assoc();

    // Check if approved
    if ($user['approved'] == 0) {
        echo json_encode(["error" => "Your account is pending wait for admin approval"]);
        exit;
    }

    $storedPass = trim($user['password']);
    if (password_verify($password, $storedPass)) {
        echo json_encode([
            "success" => true,
            "fullname" => $user['fullname'],
            "role" => "user",
            "district" => $user['district'] ?? "Unknown"
        ]);
        exit;
    } else {
        echo json_encode(["error" => "Invalid password"]);
        exit;
    }
}

// --------------------------------------------------
// ADMIN LOGIN (plain OR hashed)
// --------------------------------------------------
$stmt = $conn->prepare("SELECT id, fullname, district, password FROM admin WHERE citizen_number = ?");
if (!$stmt) {
    echo json_encode(["error" => "Server error"]);
    exit;
}

$stmt->bind_param("s", $citizen_number);
$stmt->execute();
$result = $stmt->get_result();

if (!$result || $result->num_rows === 0) {
    echo json_encode(["error" => "User not found"]);
    exit;
}

$admin = $result->fetch_assoc();
$storedPass = trim($admin['password']);
$adminLoginSuccess = false;

// Try hashed password first
if (@password_verify($password, $storedPass)) {
    $adminLoginSuccess = true;
// If not hashed, compare plain text
} elseif ($password === $storedPass) {
    $adminLoginSuccess = true;
}

if ($adminLoginSuccess) {
    echo json_encode([
        "success" => true,
        "fullname" => $admin['fullname'],
        "role" => "admin",
        "district" => $admin['district'] ?? "Unknown"
    ]);
    exit;
} else {
    echo json_encode(["error" => "Invalid password"]);
    exit;
}
?>
