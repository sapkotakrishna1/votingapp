<?php
header('Content-Type: application/json');
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST");
header("Access-Control-Allow-Headers: Content-Type");

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    echo json_encode(['error' => 'Only POST allowed']);
    exit;
}

if (!isset($_FILES['image'])) {
    echo json_encode(['error' => 'No image uploaded']);
    exit;
}

$image = $_FILES['image'];
$tempPath = $image['tmp_name'];

if (!file_exists($tempPath)) {
    echo json_encode(['error' => 'File upload failed']);
    exit;
}

// Add .png extension if missing
$tempPathWithExt = $tempPath . '.png';
rename($tempPath, $tempPathWithExt);
$tempPath = $tempPathWithExt;

// Output file
$outputFile = tempnam(sys_get_temp_dir(), 'ocr_');

// Full path to Tesseract executable
$tesseractPath = 'C:\Users\krishna\AppData\Local\Programs\Tesseract-OCR\tesseract.exe'; 
// <-- Make sure this is correct. Use double backslashes \\ on Windows

if (!file_exists($tesseractPath)) {
    echo json_encode(['error' => 'Tesseract executable not found']);
    exit;
}

try {
    // Build command
    $cmd = "\"$tesseractPath\" " . escapeshellarg($tempPath) . " " . escapeshellarg($outputFile) . " -l eng+nep";

    // Run command
    exec($cmd . " 2>&1", $output, $returnVar);

    if ($returnVar !== 0) {
        echo json_encode(['error' => 'Tesseract OCR failed', 'debug' => $output]);
        exit;
    }

    $text = file_get_contents($outputFile . ".txt");
    if ($text === false) $text = '';

    // Cleanup
    @unlink($outputFile . ".txt");
    @unlink($tempPath);

    echo json_encode(['text' => $text]);
} catch (Exception $e) {
    echo json_encode(['error' => $e->getMessage()]);
}
