<?php
header('Content-Type: application/json');
include 'config.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    echo json_encode(["success" => false, "message" => "Invalid request method"]);
    exit;
}

$data = $_POST;

$id = intval($data['id'] ?? 0);
if ($id <= 0) {
    echo json_encode(["success" => false, "message" => "Invalid candidate ID"]);
    exit;
}

$fullname = $conn->real_escape_string($data['fullname'] ?? '');
$party = $conn->real_escape_string($data['party'] ?? '');
$district = $conn->real_escape_string($data['district'] ?? '');
$dob = $conn->real_escape_string($data['dob'] ?? '');
$education = $conn->real_escape_string($data['education'] ?? '');
$vision = $conn->real_escape_string($data['vision'] ?? '');
$details = $conn->real_escape_string($data['details'] ?? '');
$photo_base64 = $data['photo'] ?? null;

// Convert base64 to binary BLOB
$photo_blob = null;
if ($photo_base64) {
    $photo_blob = base64_decode(preg_replace('#^data:image/\w+;base64,#i', '', $photo_base64));
}

if ($photo_blob !== null) {
    // Update with BLOB image
    $stmt = $conn->prepare("UPDATE candidates 
        SET fullname=?, party=?, district=?, dob=?, education=?, vision=?, details=?, photo=? 
        WHERE id=?");

    if (!$stmt) {
        echo json_encode(["success" => false, "message" => "Prepare failed: " . $conn->error]);
        exit;
    }

    // Bind parameters (s = string, i = integer)
    $null = null;
    $stmt->bind_param(
        "ssssssssi",
        $fullname,
        $party,
        $district,
        $dob,
        $education,
        $vision,
        $details,
        $null, // placeholder for blob
        $id
    );

    // Send the BLOB
    $stmt->send_long_data(7, $photo_blob);

} else {
    // Update without changing photo
    $stmt = $conn->prepare("UPDATE candidates 
        SET fullname=?, party=?, district=?, dob=?, education=?, vision=?, details=? 
        WHERE id=?");

    if (!$stmt) {
        echo json_encode(["success" => false, "message" => "Prepare failed: " . $conn->error]);
        exit;
    }

    $stmt->bind_param(
        "sssssssi",
        $fullname,
        $party,
        $district,
        $dob,
        $education,
        $vision,
        $details,
        $id
    );
}

if ($stmt->execute()) {
    echo json_encode(["success" => true, "message" => "Candidate updated successfully"]);
} else {
    echo json_encode(["success" => false, "message" => "Error: " . $stmt->error]);
}

$stmt->close();
$conn->close();
?>
