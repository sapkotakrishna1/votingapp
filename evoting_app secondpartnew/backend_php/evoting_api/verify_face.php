<?php
header('Content-Type: application/json');

/* =====================================================
   SAFE ERROR & EXCEPTION HANDLING (JSON ONLY)
===================================================== */
error_reporting(0);
ini_set('display_errors', 0);

set_exception_handler(function ($e) {
    http_response_code(500);
    echo json_encode([
        "success" => false,
        "error" => "SERVER_EXCEPTION",
        "message" => $e->getMessage()
    ]);
    exit;
});

set_error_handler(function ($severity, $message, $file, $line) {
    http_response_code(500);
    echo json_encode([
        "success" => false,
        "error" => "SERVER_ERROR",
        "message" => "$message at $file:$line"
    ]);
    exit;
});

/* =====================================================
   DB
===================================================== */
require "config.php";

/* =====================================================
   CORS
===================================================== */
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') exit;

/* =====================================================
   POST ONLY
===================================================== */
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(["success" => false, "error" => "Method not allowed"]);
    exit;
}

/* =====================================================
   INPUT
===================================================== */
$raw = file_get_contents("php://input");
$input = json_decode($raw, true);

if (!$input) {
    throw new Exception("Invalid JSON input");
}

$citizenID  = $input["citizenID"] ?? null;
$imageBase64 = $input["image"] ?? null;

if (!$citizenID || !$imageBase64) {
    throw new Exception("Missing citizenID or image");
}

/* =====================================================
   SAVE IMAGE
===================================================== */
$tempDir = __DIR__ . "/uploads";
if (!is_dir($tempDir)) mkdir($tempDir, 0777, true);

$tempImage = "$tempDir/{$citizenID}_verify.jpg";

$imageData = base64_decode($imageBase64, true);
if ($imageData === false) {
    throw new Exception("Invalid base64 image");
}

file_put_contents($tempImage, $imageData);

/* =====================================================
   RUN PYTHON
===================================================== */
$python = "C:\\Users\\krishna\\AppData\\Local\\Programs\\Python\\Python310\\python.exe";
$script = __DIR__ . "/generate_embedding.py";

$cmd = "\"$python\" \"$script\" \"$tempImage\" 2>&1";
$output = shell_exec($cmd);

if ($output === null) {
    throw new Exception("shell_exec disabled");
}

$output = trim($output);
$pythonResult = json_decode($output, true);

if (!$pythonResult || !isset($pythonResult["embedding"])) {
    throw new Exception("Python returned invalid JSON: " . $output);
}

$imageEmbedding = $pythonResult["embedding"];

/* =====================================================
   FETCH STORED EMBEDDING
===================================================== */
$stmt = $conn->prepare(
    "SELECT embedding FROM users WHERE citizen_number = ?"
);

if (!$stmt) {
    throw new Exception("DB prepare failed");
}

$stmt->bind_param("s", $citizenID);
$stmt->execute();
$res = $stmt->get_result();

if ($res->num_rows === 0) {
    throw new Exception("User not found");
}

$row = $res->fetch_assoc();
$storedEmbedding = json_decode($row["embedding"], true);

$stmt->close();
$conn->close();

if (!is_array($storedEmbedding)) {
    throw new Exception("Stored embedding invalid");
}

if (count($storedEmbedding) !== count($imageEmbedding)) {
    throw new Exception("Embedding length mismatch");
}

/* =====================================================
   COMPARE
===================================================== */
function euclidean($a, $b) {
    $sum = 0.0;
    $len = count($a);
    for ($i = 0; $i < $len; $i++) {
        $diff = $a[$i] - $b[$i];
        $sum += $diff * $diff;
    }
    return sqrt($sum);
}

$distance = euclidean($imageEmbedding, $storedEmbedding);
$match = $distance <= 0.5;

/* =====================================================
   RESPONSE (JSON ONLY)
===================================================== */
echo json_encode([
    "success"   => $match,
    "distance"  => $distance,
    "citizenID" => $citizenID,
    "status"    => $match ? "MATCH" : "NO_MATCH"
]);

/* =====================================================
   CLEANUP
===================================================== */
if (file_exists($tempImage)) unlink($tempImage);
exit;
