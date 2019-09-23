DELETE FROM mysql.user WHERE Host = 'localhost';
UPDATE mysql.user SET Host = '%' WHERE User = 'root';
FLUSH PRIVILEGES;
