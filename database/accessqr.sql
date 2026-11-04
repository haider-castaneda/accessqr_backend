-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Servidor: 127.0.0.1:3307
-- Tiempo de generación: 04-11-2026 a las 01:42:07
-- Versión del servidor: 10.4.32-MariaDB
-- Versión de PHP: 8.2.12

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Base de datos: `accessqr`
--

DELIMITER $$
--
-- Procedimientos
--
CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_aprobar_usuario` (IN `p_id_usuario` INT, IN `p_token` VARCHAR(250), IN `p_id_admin` INT)   BEGIN
  IF fn_es_admin(p_id_admin) = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Solo un administrador activo puede aprobar usuarios';
  END IF;
  IF p_token IS NULL OR TRIM(p_token) = '' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Falta el token_qr generado por la aplicacion';
  END IF;
  UPDATE usuarios SET estado = 'activo', token_qr = p_token
   WHERE id_usuario = p_id_usuario AND estado = 'pendiente';
  IF ROW_COUNT() = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El usuario no existe o no esta pendiente';
  END IF;
  SELECT id_usuario, nombre, token_qr FROM usuarios WHERE id_usuario = p_id_usuario;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_cambiar_estado` (IN `p_id_usuario` INT, IN `p_estado` VARCHAR(20), IN `p_id_admin` INT)   BEGIN
  IF fn_es_admin(p_id_admin) = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Solo un administrador activo puede cambiar estados';
  END IF;
  IF p_estado NOT IN ('activo','inactivo') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Estado invalido: use activo o inactivo';
  END IF;
  UPDATE usuarios SET estado = p_estado WHERE id_usuario = p_id_usuario;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_convertir_visitante` (IN `p_documento` VARCHAR(20), IN `p_nombre` VARCHAR(100), IN `p_tipo_documento` VARCHAR(5), IN `p_telefono` VARCHAR(25), IN `p_contrasena_hash` VARCHAR(250), IN `p_tipo_usuario` VARCHAR(20))   BEGIN
  DECLARE v_id INT DEFAULT NULL;
  DECLARE v_tipo VARCHAR(20) DEFAULT NULL;

  IF p_tipo_usuario NOT IN ('aprendiz','instructor') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Tipo de usuario invalido: use aprendiz o instructor';
  END IF;

  IF p_telefono IS NULL OR TRIM(p_telefono) = ''
     OR p_contrasena_hash IS NULL OR TRIM(p_contrasena_hash) = '' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Se requieren telefono y contrasena';
  END IF;

  SELECT id_usuario, tipo_usuario INTO v_id, v_tipo
    FROM usuarios WHERE documento = p_documento;

  IF v_id IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No existe un usuario con ese documento';
  END IF;

  IF v_tipo <> 'visitante' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Ese documento ya pertenece a un aprendiz o instructor';
  END IF;

  IF fn_siguiente_movimiento(v_id) = 'salida' THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'El visitante esta adentro: el celador debe registrar su salida primero';
  END IF;

  UPDATE usuarios
     SET nombre = p_nombre, tipo_documento = p_tipo_documento, telefono = p_telefono,
         contrasena_hash = p_contrasena_hash, tipo_usuario = p_tipo_usuario,
         motivo_visita = NULL, estado = 'pendiente'
   WHERE id_usuario = v_id;

  SELECT id_usuario, nombre, tipo_usuario, estado FROM usuarios WHERE id_usuario = v_id;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_crear_admin` (IN `p_usuario_login` VARCHAR(50), IN `p_hash` VARCHAR(250), IN `p_nombre` VARCHAR(100), IN `p_rol` VARCHAR(20), IN `p_id_admin` INT)   BEGIN
  IF fn_es_admin(p_id_admin) = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Solo un administrador activo puede crear cuentas';
  END IF;
  INSERT INTO administradores (usuario_login, contrasena_hash, nombre, rol)
  VALUES (p_usuario_login, p_hash, p_nombre, p_rol);
  SELECT LAST_INSERT_ID() AS id_admin;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_estado_admin` (IN `p_id_objetivo` INT, IN `p_estado` VARCHAR(20), IN `p_id_admin` INT)   BEGIN
  IF fn_es_admin(p_id_admin) = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Solo un administrador activo puede cambiar estados';
  END IF;
  IF p_estado NOT IN ('activo','inactivo') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Estado invalido: use activo o inactivo';
  END IF;
  IF p_id_objetivo = p_id_admin AND p_estado = 'inactivo' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No puedes desactivar tu propia cuenta';
  END IF;
  UPDATE administradores SET estado = p_estado WHERE id_admin = p_id_objetivo;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_historial` (IN `p_desde` DATE, IN `p_hasta` DATE, IN `p_documento` VARCHAR(20))   BEGIN
  SELECT r.id_registro, u.nombre, u.documento, u.tipo_usuario, r.tipo_movimiento, r.fecha_hora
    FROM registros r JOIN usuarios u ON u.id_usuario = r.persona_id
   WHERE r.fecha_hora >= p_desde AND r.fecha_hora < DATE_ADD(p_hasta, INTERVAL 1 DAY)
     AND (p_documento IS NULL OR p_documento = '' OR u.documento = p_documento)
   ORDER BY r.fecha_hora DESC, r.id_registro DESC;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_indicadores` ()   BEGIN
  SELECT (SELECT COUNT(*) FROM v_usuarios_dentro) AS personas_dentro,
         (SELECT COUNT(*) FROM usuarios WHERE estado = 'pendiente') AS pendientes,
         (SELECT COUNT(*) FROM registros WHERE fecha_hora >= CURDATE()) AS movimientos_hoy;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_marcar_revisado` (IN `p_id_usuario` INT, IN `p_id_admin` INT)   BEGIN
  IF fn_es_staff(p_id_admin) = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Celador o administrador no valido o inactivo';
  END IF;
  UPDATE usuarios SET revisado = 1 WHERE id_usuario = p_id_usuario AND estado = 'pendiente';
  IF ROW_COUNT() = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El usuario no existe, no esta pendiente o ya estaba revisado';
  END IF;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_obtener_admin` (IN `p_usuario_login` VARCHAR(50))   BEGIN
  SELECT id_admin, nombre, rol, estado, contrasena_hash
    FROM administradores WHERE usuario_login = p_usuario_login;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_obtener_usuario_login` (IN `p_documento` VARCHAR(20))   BEGIN
  SELECT id_usuario, nombre, tipo_usuario, estado, contrasena_hash
    FROM usuarios WHERE documento = p_documento AND tipo_usuario <> 'visitante';
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_reabrir_usuario` (IN `p_id_usuario` INT, IN `p_id_admin` INT)   BEGIN
  IF fn_es_admin(p_id_admin) = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Solo un administrador activo puede reabrir usuarios';
  END IF;
  UPDATE usuarios SET estado = 'pendiente' WHERE id_usuario = p_id_usuario AND estado = 'rechazado';
  IF ROW_COUNT() = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El usuario no existe o no esta rechazado';
  END IF;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_rechazar_usuario` (IN `p_id_usuario` INT, IN `p_id_admin` INT)   BEGIN
  IF fn_es_admin(p_id_admin) = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Solo un administrador activo puede rechazar usuarios';
  END IF;
  UPDATE usuarios SET estado = 'rechazado' WHERE id_usuario = p_id_usuario AND estado = 'pendiente';
  IF ROW_COUNT() = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El usuario no existe o no esta pendiente';
  END IF;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_registrar_movimiento` (IN `p_token_qr` VARCHAR(250))   BEGIN
  DECLARE v_id INT DEFAULT NULL;
  DECLARE v_sig VARCHAR(10);

  SELECT id_usuario INTO v_id FROM usuarios WHERE token_qr = p_token_qr AND estado = 'activo';
  IF v_id IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'QR no valido o usuario no activo';
  END IF;

  SET v_sig = fn_siguiente_movimiento(v_id);
  INSERT INTO registros (persona_id, tipo_movimiento) VALUES (v_id, v_sig);

  SELECT u.nombre, u.documento, u.tipo_usuario, r.tipo_movimiento, r.fecha_hora
    FROM registros r JOIN usuarios u ON u.id_usuario = r.persona_id
   WHERE r.id_registro = LAST_INSERT_ID();
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_registrar_usuario` (IN `p_nombre` VARCHAR(100), IN `p_documento` VARCHAR(20), IN `p_tipo_documento` VARCHAR(5), IN `p_telefono` VARCHAR(25), IN `p_contrasena_hash` VARCHAR(250), IN `p_tipo_usuario` VARCHAR(20))   BEGIN
  IF p_tipo_usuario NOT IN ('aprendiz','instructor') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Tipo de usuario invalido para el registro';
  END IF;
  INSERT INTO usuarios (nombre, documento, tipo_documento, telefono, contrasena_hash, tipo_usuario)
  VALUES (p_nombre, p_documento, p_tipo_documento, p_telefono, p_contrasena_hash, p_tipo_usuario);
  SELECT LAST_INSERT_ID() AS id_usuario;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_registrar_visitante` (IN `p_nombre` VARCHAR(100), IN `p_documento` VARCHAR(20), IN `p_tipo_documento` VARCHAR(5), IN `p_motivo` VARCHAR(100))   BEGIN
  DECLARE v_id INT DEFAULT NULL;
  DECLARE v_tipo VARCHAR(20) DEFAULT NULL;
  DECLARE v_sig VARCHAR(10);

  SELECT id_usuario, tipo_usuario INTO v_id, v_tipo FROM usuarios WHERE documento = p_documento;

  IF v_id IS NULL THEN
    INSERT INTO usuarios (nombre, documento, tipo_documento, tipo_usuario, motivo_visita, estado)
    VALUES (p_nombre, p_documento, p_tipo_documento, 'visitante', p_motivo, 'activo');
    SET v_id = LAST_INSERT_ID();
  ELSEIF v_tipo <> 'visitante' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Ese documento pertenece a un aprendiz o instructor';
  ELSEIF fn_siguiente_movimiento(v_id) = 'entrada' THEN
    IF p_motivo IS NULL OR TRIM(p_motivo) = '' THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El visitante debe tener un motivo de visita';
    END IF;
    UPDATE usuarios SET motivo_visita = p_motivo, estado = 'activo' WHERE id_usuario = v_id;
  END IF;

  SET v_sig = fn_siguiente_movimiento(v_id);
  INSERT INTO registros (persona_id, tipo_movimiento) VALUES (v_id, v_sig);

  SELECT u.id_usuario, u.nombre, r.tipo_movimiento, r.fecha_hora
    FROM registros r JOIN usuarios u ON u.id_usuario = r.persona_id
   WHERE r.id_registro = LAST_INSERT_ID();
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_reponer_qr` (IN `p_id_usuario` INT, IN `p_token` VARCHAR(250))   BEGIN
  IF p_token IS NULL OR TRIM(p_token) = '' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Falta el token_qr generado por la aplicacion';
  END IF;
  UPDATE usuarios SET token_qr = p_token
   WHERE id_usuario = p_id_usuario AND estado = 'activo' AND tipo_usuario <> 'visitante';
  IF ROW_COUNT() = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Usuario no encontrado, no activo o visitante';
  END IF;
  SELECT id_usuario, nombre, token_qr FROM usuarios WHERE id_usuario = p_id_usuario;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_reporte` (IN `p_desde` DATE, IN `p_hasta` DATE)   BEGIN
  SELECT u.documento, u.nombre, u.tipo_usuario,
         SUM(r.tipo_movimiento = 'entrada') AS entradas,
         SUM(r.tipo_movimiento = 'salida')  AS salidas,
         MIN(r.fecha_hora) AS primer_movimiento,
         MAX(r.fecha_hora) AS ultimo_movimiento
    FROM registros r JOIN usuarios u ON u.id_usuario = r.persona_id
   WHERE r.fecha_hora >= p_desde AND r.fecha_hora < DATE_ADD(p_hasta, INTERVAL 1 DAY)
   GROUP BY u.id_usuario, u.documento, u.nombre, u.tipo_usuario
   ORDER BY u.nombre;
END$$

--
-- Funciones
--
CREATE DEFINER=`root`@`localhost` FUNCTION `fn_es_admin` (`p_id` INT) RETURNS TINYINT(1) READS SQL DATA BEGIN
  DECLARE v INT DEFAULT 0;
  SELECT COUNT(*) INTO v FROM administradores
   WHERE id_admin = p_id AND estado = 'activo' AND rol = 'administrador';
  RETURN v > 0;
END$$

CREATE DEFINER=`root`@`localhost` FUNCTION `fn_es_staff` (`p_id` INT) RETURNS TINYINT(1) READS SQL DATA BEGIN
  DECLARE v INT DEFAULT 0;
  SELECT COUNT(*) INTO v FROM administradores
   WHERE id_admin = p_id AND estado = 'activo';
  RETURN v > 0;
END$$

CREATE DEFINER=`root`@`localhost` FUNCTION `fn_siguiente_movimiento` (`p_id_usuario` INT) RETURNS VARCHAR(10) CHARSET utf8mb4 COLLATE utf8mb4_general_ci READS SQL DATA BEGIN
  DECLARE v_ultimo VARCHAR(10) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL;

  SELECT tipo_movimiento INTO v_ultimo
    FROM registros
   WHERE persona_id = p_id_usuario
   ORDER BY fecha_hora DESC, id_registro DESC
   LIMIT 1;

  IF v_ultimo = 'entrada' THEN
    RETURN 'salida';
  END IF;
  RETURN 'entrada';
END$$

DELIMITER ;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `administradores`
--

CREATE TABLE `administradores` (
  `id_admin` int(11) NOT NULL,
  `usuario_login` varchar(50) NOT NULL,
  `contrasena_hash` varchar(250) NOT NULL,
  `nombre` varchar(100) NOT NULL,
  `rol` enum('administrador','celador') NOT NULL DEFAULT 'celador',
  `estado` enum('activo','inactivo') NOT NULL DEFAULT 'activo',
  `fecha_creacion` datetime NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `administradores`
--

INSERT INTO `administradores` (`id_admin`, `usuario_login`, `contrasena_hash`, `nombre`, `rol`, `estado`, `fecha_creacion`) VALUES
(1, 'admin', '$2b$12$9y4kpLTFIK7wjX0DAPitLemiURoHuJiQPhFMT1PFN/jBLJoSO7e.e', 'Administrador Inicial', 'administrador', 'activo', '2026-10-28 17:13:43');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `registros`
--

CREATE TABLE `registros` (
  `id_registro` int(11) NOT NULL,
  `persona_id` int(11) NOT NULL,
  `tipo_movimiento` enum('entrada','salida') NOT NULL,
  `fecha_hora` datetime NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Disparadores `registros`
--
DELIMITER $$
CREATE TRIGGER `trg_registros_bi` BEFORE INSERT ON `registros` FOR EACH ROW BEGIN
  DECLARE v_estado VARCHAR(20) DEFAULT NULL;
  SELECT estado INTO v_estado FROM usuarios WHERE id_usuario = NEW.persona_id;
  IF v_estado IS NULL OR v_estado <> 'activo' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El usuario no esta activo: no puede registrar movimientos';
  END IF;
  IF NEW.tipo_movimiento <> fn_siguiente_movimiento(NEW.persona_id) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Movimiento invalido: debe alternar entrada y salida';
  END IF;
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `usuarios`
--

CREATE TABLE `usuarios` (
  `id_usuario` int(11) NOT NULL,
  `nombre` varchar(100) NOT NULL,
  `documento` varchar(20) NOT NULL,
  `tipo_documento` enum('CC','TI','CE') NOT NULL DEFAULT 'CC',
  `telefono` varchar(25) DEFAULT NULL,
  `contrasena_hash` varchar(250) DEFAULT NULL,
  `tipo_usuario` enum('aprendiz','instructor','visitante') NOT NULL,
  `token_qr` varchar(250) DEFAULT NULL,
  `estado` enum('pendiente','activo','inactivo','rechazado') NOT NULL DEFAULT 'pendiente',
  `fecha_registro` datetime NOT NULL DEFAULT current_timestamp(),
  `motivo_visita` varchar(100) DEFAULT NULL,
  `revisado` tinyint(1) NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Disparadores `usuarios`
--
DELIMITER $$
CREATE TRIGGER `trg_usuarios_bi` BEFORE INSERT ON `usuarios` FOR EACH ROW BEGIN
  IF NEW.tipo_usuario = 'visitante' THEN
    IF NEW.motivo_visita IS NULL OR TRIM(NEW.motivo_visita) = '' THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El visitante debe tener un motivo de visita';
    END IF;
  ELSE
    IF NEW.telefono IS NULL OR TRIM(NEW.telefono) = '' THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Aprendices e instructores requieren telefono';
    END IF;
    IF NEW.contrasena_hash IS NULL OR TRIM(NEW.contrasena_hash) = '' THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Aprendices e instructores requieren contrasena';
    END IF;
    IF NEW.estado <> 'pendiente' THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Todo aprendiz o instructor nuevo debe quedar pendiente';
    END IF;
    SET NEW.motivo_visita = NULL;
    SET NEW.revisado = 0;
  END IF;
  SET NEW.token_qr = NULL;
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `trg_usuarios_bu` BEFORE UPDATE ON `usuarios` FOR EACH ROW BEGIN
  IF NEW.estado <> OLD.estado THEN

    IF NOT (
         (OLD.estado = 'pendiente' AND NEW.estado IN ('activo','rechazado'))
      OR (OLD.estado = 'activo'    AND NEW.estado = 'inactivo')
      OR (OLD.estado = 'inactivo'  AND NEW.estado = 'activo')
      OR (OLD.estado = 'rechazado' AND NEW.estado = 'pendiente')
      OR (OLD.estado = 'activo'    AND NEW.estado = 'pendiente'
          AND OLD.tipo_usuario = 'visitante'
          AND NEW.tipo_usuario IN ('aprendiz','instructor'))
    ) THEN
      SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Cambio de estado no permitido';
    END IF;

    IF OLD.estado = 'pendiente' AND NEW.estado = 'activo'
       AND NEW.tipo_usuario <> 'visitante' AND OLD.revisado = 0 THEN
      SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'El celador debe revisar los datos antes de aprobar';
    END IF;

    IF NEW.estado IN ('pendiente','rechazado') THEN
      SET NEW.token_qr = NULL;
    END IF;

    IF NEW.estado = 'pendiente' THEN
      SET NEW.revisado = 0;
    END IF;
  END IF;

  IF NEW.estado <> 'activo' AND NEW.token_qr IS NOT NULL
     AND NOT (NEW.token_qr <=> OLD.token_qr) THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Solo un usuario activo puede recibir un token_qr';
  END IF;

  IF NEW.estado = 'activo' AND NEW.tipo_usuario <> 'visitante'
     AND (NEW.token_qr IS NULL OR TRIM(NEW.token_qr) = '') THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Un usuario activo debe tener token_qr (lo genera la aplicacion)';
  END IF;
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Estructura Stand-in para la vista `v_administradores`
-- (Véase abajo para la vista actual)
--
CREATE TABLE `v_administradores` (
`id_admin` int(11)
,`usuario_login` varchar(50)
,`nombre` varchar(100)
,`rol` enum('administrador','celador')
,`estado` enum('activo','inactivo')
,`fecha_creacion` datetime
);

-- --------------------------------------------------------

--
-- Estructura Stand-in para la vista `v_usuarios`
-- (Véase abajo para la vista actual)
--
CREATE TABLE `v_usuarios` (
`id_usuario` int(11)
,`nombre` varchar(100)
,`documento` varchar(20)
,`tipo_documento` enum('CC','TI','CE')
,`telefono` varchar(25)
,`tipo_usuario` enum('aprendiz','instructor','visitante')
,`estado` enum('pendiente','activo','inactivo','rechazado')
,`revisado` tinyint(1)
,`motivo_visita` varchar(100)
,`fecha_registro` datetime
);

-- --------------------------------------------------------

--
-- Estructura Stand-in para la vista `v_usuarios_dentro`
-- (Véase abajo para la vista actual)
--
CREATE TABLE `v_usuarios_dentro` (
`id_usuario` int(11)
,`nombre` varchar(100)
,`documento` varchar(20)
,`tipo_usuario` enum('aprendiz','instructor','visitante')
,`hora_ingreso` datetime
);

-- --------------------------------------------------------

--
-- Estructura Stand-in para la vista `v_usuarios_pendientes`
-- (Véase abajo para la vista actual)
--
CREATE TABLE `v_usuarios_pendientes` (
`id_usuario` int(11)
,`nombre` varchar(100)
,`documento` varchar(20)
,`tipo_documento` enum('CC','TI','CE')
,`telefono` varchar(25)
,`tipo_usuario` enum('aprendiz','instructor','visitante')
,`revisado` tinyint(1)
,`fecha_registro` datetime
);

-- --------------------------------------------------------

--
-- Estructura para la vista `v_administradores`
--
DROP TABLE IF EXISTS `v_administradores`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `v_administradores`  AS SELECT `administradores`.`id_admin` AS `id_admin`, `administradores`.`usuario_login` AS `usuario_login`, `administradores`.`nombre` AS `nombre`, `administradores`.`rol` AS `rol`, `administradores`.`estado` AS `estado`, `administradores`.`fecha_creacion` AS `fecha_creacion` FROM `administradores` ;

-- --------------------------------------------------------

--
-- Estructura para la vista `v_usuarios`
--
DROP TABLE IF EXISTS `v_usuarios`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `v_usuarios`  AS SELECT `usuarios`.`id_usuario` AS `id_usuario`, `usuarios`.`nombre` AS `nombre`, `usuarios`.`documento` AS `documento`, `usuarios`.`tipo_documento` AS `tipo_documento`, `usuarios`.`telefono` AS `telefono`, `usuarios`.`tipo_usuario` AS `tipo_usuario`, `usuarios`.`estado` AS `estado`, `usuarios`.`revisado` AS `revisado`, `usuarios`.`motivo_visita` AS `motivo_visita`, `usuarios`.`fecha_registro` AS `fecha_registro` FROM `usuarios` ;

-- --------------------------------------------------------

--
-- Estructura para la vista `v_usuarios_dentro`
--
DROP TABLE IF EXISTS `v_usuarios_dentro`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `v_usuarios_dentro`  AS SELECT `u`.`id_usuario` AS `id_usuario`, `u`.`nombre` AS `nombre`, `u`.`documento` AS `documento`, `u`.`tipo_usuario` AS `tipo_usuario`, `r`.`fecha_hora` AS `hora_ingreso` FROM (`usuarios` `u` join `registros` `r` on(`r`.`persona_id` = `u`.`id_usuario`)) WHERE `r`.`tipo_movimiento` = 'entrada' AND `r`.`id_registro` = (select `r2`.`id_registro` from `registros` `r2` where `r2`.`persona_id` = `u`.`id_usuario` order by `r2`.`fecha_hora` desc,`r2`.`id_registro` desc limit 1) ;

-- --------------------------------------------------------

--
-- Estructura para la vista `v_usuarios_pendientes`
--
DROP TABLE IF EXISTS `v_usuarios_pendientes`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `v_usuarios_pendientes`  AS SELECT `usuarios`.`id_usuario` AS `id_usuario`, `usuarios`.`nombre` AS `nombre`, `usuarios`.`documento` AS `documento`, `usuarios`.`tipo_documento` AS `tipo_documento`, `usuarios`.`telefono` AS `telefono`, `usuarios`.`tipo_usuario` AS `tipo_usuario`, `usuarios`.`revisado` AS `revisado`, `usuarios`.`fecha_registro` AS `fecha_registro` FROM `usuarios` WHERE `usuarios`.`estado` = 'pendiente' ;

--
-- Índices para tablas volcadas
--

--
-- Indices de la tabla `administradores`
--
ALTER TABLE `administradores`
  ADD PRIMARY KEY (`id_admin`),
  ADD UNIQUE KEY `usuario_login` (`usuario_login`);

--
-- Indices de la tabla `registros`
--
ALTER TABLE `registros`
  ADD PRIMARY KEY (`id_registro`),
  ADD KEY `idx_persona_fecha` (`persona_id`,`fecha_hora`);

--
-- Indices de la tabla `usuarios`
--
ALTER TABLE `usuarios`
  ADD PRIMARY KEY (`id_usuario`),
  ADD UNIQUE KEY `documento` (`documento`),
  ADD UNIQUE KEY `telefono` (`telefono`),
  ADD UNIQUE KEY `token_qr` (`token_qr`);

--
-- AUTO_INCREMENT de las tablas volcadas
--

--
-- AUTO_INCREMENT de la tabla `administradores`
--
ALTER TABLE `administradores`
  MODIFY `id_admin` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT de la tabla `registros`
--
ALTER TABLE `registros`
  MODIFY `id_registro` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT de la tabla `usuarios`
--
ALTER TABLE `usuarios`
  MODIFY `id_usuario` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- Restricciones para tablas volcadas
--

--
-- Filtros para la tabla `registros`
--
ALTER TABLE `registros`
  ADD CONSTRAINT `fk_registros_usuario` FOREIGN KEY (`persona_id`) REFERENCES `usuarios` (`id_usuario`) ON UPDATE CASCADE;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
