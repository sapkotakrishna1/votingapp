<?php
require "config.php";

header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json");

// Fetch candidates
$sql = "SELECT id, fullname, party, address, district, education, details, dob, vision, photo FROM candidates ORDER BY id ASC";
$result = $conn->query($sql);

$candidates = [];

if ($result) {
    while ($row = $result->fetch_assoc()) {
        $photoBase64 = null;
        if (!empty($row['photo'])) {
            // send **only base64**, no data URI prefix
            $photoBase64 = base64_encode($row['photo']);
        }

        $candidates[] = [
            "id" => $row['id'],
            "fullname" => $row['fullname'],
            "party" => $row['party'],
            "district" => $row['district'],
            "address" => $row['address'],
            "education" => $row['education'],
            "details" => $row['details'],
            "dob" => $row['dob'],
            "vision" => $row['vision'],
            "photo" => $photoBase64
        ];
    }

    echo json_encode(["candidates" => $candidates]);
} else {
    http_response_code(500);
    echo json_encode(["error" => "Database query failed: " . $conn->error]);
}

$conn->close();
?>
