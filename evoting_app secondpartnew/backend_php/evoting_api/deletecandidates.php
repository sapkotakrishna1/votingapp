<?php
header('Content-Type: application/json');
include 'config.php';

$id = isset($_GET['id']) ? intval($_GET['id']) : 0;

if ($id <= 0) {
    echo json_encode(["status" => "error", "message" => "Invalid candidate ID"]);
    exit;
}

// Get existing photo filename
$photo_filename = null;
$res = $conn->query("SELECT photo FROM candidates WHERE id=$id");
if ($res && $res->num_rows > 0) {
    $row = $res->fetch_assoc();
    $photo_filename = $row['photo'];
}

// Delete candidate from database
$sql = "DELETE FROM candidates WHERE id=$id";
if ($conn->query($sql)) {
    // Delete photo from server
    if ($photo_filename && file_exists($photo_filename)) {
        unlink($photo_filename);
    }
    echo json_encode(["status" => "success", "message" => "Candidate deleted successfully"]);
} else {
    echo json_encode(["status" => "error", "message" => "Error: " . $conn->error]);
}

$conn->close();
?>
