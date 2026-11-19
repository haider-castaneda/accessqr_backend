-- database/usuarios_accessqr.example.sql
-- Copia este archivo como usuarios_accessqr.sql, cambia la contraseña
-- e impórtalo desde phpMyAdmin con Importar a nivel de servidor.
 
CREATE USER IF NOT EXISTS 'accessqr_app'@'localhost'
  IDENTIFIED BY 'CAMBIA_ESTA_CONTRASENA';
CREATE USER IF NOT EXISTS 'accessqr_app'@'%'
  IDENTIFIED BY 'CAMBIA_ESTA_CONTRASENA';
 
-- La aplicacion solo puede ejecutar procedimientos y leer las vistas.
-- Nunca recibe SELECT, INSERT, UPDATE ni DELETE sobre las tablas.
GRANT EXECUTE ON accessqr.* TO 'accessqr_app'@'localhost';
GRANT EXECUTE ON accessqr.* TO 'accessqr_app'@'%';
GRANT SELECT ON accessqr.v_usuarios TO 'accessqr_app'@'localhost';
GRANT SELECT ON accessqr.v_usuarios_pendientes TO 'accessqr_app'@'localhost';
GRANT SELECT ON accessqr.v_usuarios_dentro TO 'accessqr_app'@'localhost';
GRANT SELECT ON accessqr.v_administradores TO 'accessqr_app'@'localhost';
GRANT SELECT ON accessqr.v_usuarios TO 'accessqr_app'@'%';
GRANT SELECT ON accessqr.v_usuarios_pendientes TO 'accessqr_app'@'%';
GRANT SELECT ON accessqr.v_usuarios_dentro TO 'accessqr_app'@'%';
GRANT SELECT ON accessqr.v_administradores TO 'accessqr_app'@'%';
FLUSH PRIVILEGES;
