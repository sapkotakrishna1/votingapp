<?php
require "config.php";

// --------------------------------------------------
// Clear output and set JSON header
// --------------------------------------------------
if (ob_get_length()) ob_clean();
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
header("Access-Control-Allow-Methods: GET, POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    echo json_encode(["success" => true]);
    exit;
}

// --------------------------------------------------
// Fetch users (INCLUDING FACE PHOTO)
// --------------------------------------------------
$sql = "
    SELECT 
        fullname,
        citizen_number,
        dob,
        district,
        phone,
        front_image,
        back_image,
        face_photo,
        approved
    FROM users
";

$result = $conn->query($sql);

$users = [];

if ($result) {
    while ($row = $result->fetch_assoc()) {

        // ---------------- FRONT IMAGE ----------------
        $row['front_image'] = !empty($row['front_image'])
            ? "data:image/jpeg;base64," . base64_encode($row['front_image'])
            : null;

        // ---------------- BACK IMAGE ----------------
        $row['back_image'] = !empty($row['back_image'])
            ? "data:image/jpeg;base64," . base64_encode($row['back_image'])
            : null;

        // ---------------- FACE PHOTO ----------------
        $row['face_photo'] = !empty($row['face_photo'])
            ? "data:image/jpeg;base64," . base64_encode($row['face_photo'])
            : null;

        // ---------------- APPROVED STATUS ----------------
        // Keep NULL as NULL (important for Flutter)
        if (is_null($row['approved'])) {
            $row['approved'] = null;
        } else {
            $row['approved'] = (int)$row['approved']; // 1 or 0
        }

        $users[] = $row;
    }
}

// --------------------------------------------------
// Return JSON
// --------------------------------------------------
echo json_encode(
    ["users" => $users],
    JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE
);

$conn->close();
?>
