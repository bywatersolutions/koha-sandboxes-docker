--DELETE FROM mysql.user WHERE Host = 'localhost';
UPDATE mysql.user SET Host = '172.17.%.%' WHERE User = 'root';
FLUSH PRIVILEGES;
