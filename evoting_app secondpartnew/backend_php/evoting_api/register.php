<?php
/* ================== OUTPUT BUFFER & ERROR HANDLING ================== */
ob_start();

ini_set('display_errors', 0);
ini_set('log_errors', 1);
ini_set('error_log', __DIR__ . '/error_log.txt');
error_reporting(E_ALL);

file_put_contents(__DIR__.'/error_log.txt',
    "===== SCRIPT START ".date('Y-m-d H:i:s')." =====\n",
    FILE_APPEND
);

set_error_handler(function($severity, $message, $file, $line) {
    throw new ErrorException($message, 0, $severity, $file, $line);
});

register_shutdown_function(function() {
    $err = error_get_last();
    if ($err) {
        file_put_contents(__DIR__.'/error_log.txt',
            "Shutdown error: ".json_encode($err)."\n",
            FILE_APPEND
        );
    }
});

try {
    /* ================== HEADERS ================== */
    header("Access-Control-Allow-Origin: *");
    header("Access-Control-Allow-Methods: POST, OPTIONS");
    header("Access-Control-Allow-Headers: Content-Type");
    header("Content-Type: application/json");

    if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
        http_response_code(200);
        exit;
    }

    /* ================== DATABASE ================== */
    require "config.php";
    if (!$conn) throw new Exception("Database connection failed");

    /* ================== INPUT ================== */
    $fullname       = $_POST['fullname'] ?? null;
    $dob            = $_POST['dob'] ?? null;
    $district       = $_POST['district'] ?? null;
    $citizen_number = $_POST['citizen_number'] ?? null;
    $phone          = $_POST['phone'] ?? null;
    $password       = $_POST['password'] ?? null;
    $frontBase64    = $_POST['front_image'] ?? null;
    $backBase64     = $_POST['back_image'] ?? null;
    $faceBase64     = $_POST['face_image'] ?? null;

    if (
        !$fullname || !$dob || !$district || !$citizen_number ||
        !$phone || !$password ||
        !trim($frontBase64) || !trim($backBase64) || !trim($faceBase64)
    ) {
        http_response_code(400);
        throw new Exception("Missing required fields");
    }

    /* ================== DUPLICATE CHECK ================== */
    $stmt = $conn->prepare(
        "SELECT id FROM users WHERE citizen_number=? OR phone=?"
    );
    $stmt->bind_param("ss", $citizen_number, $phone);
    $stmt->execute();
    $stmt->store_result();

    if ($stmt->num_rows > 0) {
        http_response_code(409);
        throw new Exception("Citizen number or phone already exists");
    }
    $stmt->close();

    /* ================== BASE64 DECODE ================== */
    function decodeImage($base64) {
        $base64 = preg_replace('#^data:image/[^;]+;base64,#', '', $base64);
        return base64_decode(
            str_replace([" ", "\r", "\n"], "", $base64),
            true
        );
    }

    $frontData = decodeImage($frontBase64);
    $backData  = decodeImage($backBase64);
    $faceData  = decodeImage($faceBase64);

    if (!$frontData || !$backData || !$faceData) {
        http_response_code(422);
        throw new Exception("Invalid image data");
    }

    /* ================== FACE EMBEDDING (MANDATORY) ================== */
    $tmpFile = tempnam(sys_get_temp_dir(), 'face_') . ".jpg";
    file_put_contents($tmpFile, $faceData);

    $pythonPath = "C:\\Users\\krishna\\AppData\\Local\\Programs\\Python\\Python310\\python.exe";
    $scriptPath = __DIR__ . "\\generate_embedding.py";

    $cmd = "\"$pythonPath\" \"$scriptPath\" \"$tmpFile\" 2>&1";
    $output = shell_exec($cmd);

    unlink($tmpFile);

    file_put_contents(
        __DIR__.'/python_debug.txt',
        date('Y-m-d H:i:s')." - ".$output."\n",
        FILE_APPEND
    );

    $pyResult = json_decode(trim($output), true);

    if (
        !$pyResult ||
        !isset($pyResult['embedding']) ||
        count($pyResult['embedding']) !== 128
    ) {
        http_response_code(422);
        throw new Exception("Face not detected. Registration cancelled.");
    }

    $embedding = json_encode($pyResult['embedding']);

    /* ================== HASH PASSWORD ================== */
    $hashedPassword = password_hash($password, PASSWORD_DEFAULT);

    /* ================== INSERT USER + BLOBS ================== */
    $stmt = $conn->prepare("
        INSERT INTO users
        (fullname, dob, district, citizen_number, phone, password,
         front_image, back_image, face_photo, embedding)
        VALUES (?,?,?,?,?,?,?,?,?,?)
    ");

    $null = NULL;
    $stmt->bind_param(
        "ssssssbbbs",
        $fullname,
        $dob,
        $district,
        $citizen_number,
        $phone,
        $hashedPassword,
        $null,
        $null,
        $null,
        $embedding
    );

    $stmt->send_long_data(6, $frontData);
    $stmt->send_long_data(7, $backData);
    $stmt->send_long_data(8, $faceData);

    if (!$stmt->execute()) {
        http_response_code(500);
        throw new Exception("Database insert failed: ".$stmt->error);
    }

    $userId = $stmt->insert_id;
    $stmt->close();
    $conn->close();

    /* ================== SUCCESS ================== */
    ob_end_clean();
    echo json_encode([
        "success" => true,
        "message" => "Registration successful",
        "user_id" => $userId
    ]);

} catch (Exception $e) {
    ob_end_clean();
    file_put_contents(
        __DIR__.'/error_log.txt',
        date('Y-m-d H:i:s')." - Error: ".$e->getMessage()."\n",
        FILE_APPEND
    );
    echo json_encode([
        "success" => false,
        "error" => $e->getMessage()
    ]);
}
?>
