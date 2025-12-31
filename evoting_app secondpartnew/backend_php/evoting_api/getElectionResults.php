<?php
// ================== FORCE JSON ALWAYS ==================
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: *");

// ================== HANDLE OPTIONS ==================
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    echo json_encode([
        "success" => true,
        "results" => []
    ]);
    exit;
}

// ================== SHOW ERRORS TEMPORARILY ==================
// COMMENT THESE 2 LINES AFTER IT WORKS
error_reporting(E_ALL);
ini_set('display_errors', 1);

// ================== DB ==================
include 'config.php';

// ================== CHECK DISTRICT ==================
if (!isset($_POST['district'])) {
    echo json_encode([
        "success" => false,
        "message" => "district not provided",
        "results" => []
    ]);
    exit;
}

$district = $_POST['district'];

// ================== SQL ==================
$sql = "
SELECT name, votes, district, created_at
FROM election_results
ORDER BY created_at DESC, votes DESC
";

$stmt = $conn->prepare($sql);

if (!$stmt) {
    echo json_encode([
        "success" => false,
        "message" => "SQL prepare failed",
        "results" => []
    ]);
    exit;
}

$stmt->execute();
$result = $stmt->get_result();

// ================== GROUP DATA ==================
$groupedResults = [];

while ($row = $result->fetch_assoc()) {
    if ($row['district'] !== $district) continue;

    $date = substr($row['created_at'], 0, 10);

    if (!isset($groupedResults[$date])) {
        $groupedResults[$date] = [];
    }

    if (count($groupedResults[$date]) < 2) {
        $groupedResults[$date][] = [
            "name" => $row['name'],
            "votes" => (int)$row['votes'],
            "district" => $row['district'],
        ];
    }
}

// ================== FINAL RESPONSE ==================
echo json_encode([
    "success" => true,
    "results" => $groupedResults
]);
