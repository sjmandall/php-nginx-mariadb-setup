<?php
$host = 'mariadb';
$db   = 'appdb';
$user = 'appuser';
$pass = 'apppass123';
$dsn  = "mysql:host=$host;dbname=$db;charset=utf8mb4";

try {
    $pdo = new PDO($dsn, $user, $pass);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    echo "DB connection OK\n";
} catch (PDOException $e) {
    echo "DB connection FAILED: " . $e->getMessage() . "\n";
}
