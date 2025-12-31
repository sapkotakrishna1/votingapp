<?php
// Allow requests from any origin (CORS)
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");
header("Content-Type: application/json");

// Handle preflight
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

// Read JSON from Flutter
$data = json_decode(file_get_contents("php://input"), true);

require "config.php"; // DB connection

// Validate incoming data
if (!isset($data['results']) || !is_array($data['results'])) {
    echo json_encode([
        "status" => "error",
        "message" => "Invalid or missing results data"
    ]);
    exit();
}

$district = isset($data['district']) ? $conn->real_escape_string($data['district']) : "unknown";

// Prepared statement to avoid SQL Injection
$stmt = $conn->prepare(
    "INSERT INTO election_results (name, votes, district) 
     VALUES (?, ?, ?)"
);

if (!$stmt) {
    echo json_encode([
        "status" => "error",
        "message" => $conn->error
    ]);
    exit();
}

foreach ($data['results'] as $candidate) {
    $name = $candidate['name'];
    $votes = intval($candidate['voteCount']);

    $stmt->bind_param("sis", $name, $votes, $district);

    if (!$stmt->execute()) {
        echo json_encode([
            "status" => "error",
            "message" => $stmt->error
        ]);
        $stmt->close();
        $conn->close();
        exit();
    }
}

$stmt->close();
$conn->close();

echo json_encode(["status" => "success"]);
?>
