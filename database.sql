-- =====================================================================================
-- EDUCONTROL & CAMPUS PRO v1.0 - ERP ACADÉMICO, COLEGIATURAS, SOLVENCIAS QR & MINEDUC
-- Propietario y Desarrollador Principal: Kevin Alejandro Vásquez Ramos
-- Motor: MySQL 8.0+ / MariaDB
-- =====================================================================================

DROP DATABASE IF EXISTS educontrol_gt_db;
CREATE DATABASE educontrol_gt_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE educontrol_gt_db;

-- 1. TABLA DE ESTUDIANTES (CON CÓDIGO PERSONAL MINEDUC Y ESTADO DE SOLVENCIA)
CREATE TABLE estudiantes (
    id INT AUTO_INCREMENT PRIMARY KEY,
    codigo_mineduc VARCHAR(20) NOT NULL UNIQUE,
    carnet VARCHAR(20) NOT NULL UNIQUE,
    nombre_estudiante VARCHAR(120) NOT NULL,
    grado_carrera VARCHAR(80) NOT NULL,
    encargado_nombre VARCHAR(120) NOT NULL,
    telefono_whatsapp VARCHAR(20) NOT NULL DEFAULT '50255550000',
    mensualidad_q DECIMAL(10,2) NOT NULL DEFAULT 450.00,
    meses_mora INT NOT NULL DEFAULT 0,
    estado_solvencia ENUM('SOLVENTE', 'BLOQUEADO_MORA') DEFAULT 'SOLVENTE',
    promedio_general DECIMAL(5,2) NOT NULL DEFAULT 0.00,
    fecha_inscripcion DATE NOT NULL
);

-- 2. TABLA DE PAGOS DE COLEGIATURA (DISPARA TRIGGER DE DESBLOQUEO AUTOMÁTICO)
CREATE TABLE pagos_colegiatura (
    id INT AUTO_INCREMENT PRIMARY KEY,
    estudiante_id INT NOT NULL,
    recibo_serie VARCHAR(40) NOT NULL UNIQUE,
    mes_pagado VARCHAR(30) NOT NULL,
    monto_colegiatura DECIMAL(10,2) NOT NULL,
    mora_recargo DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    total_pagado DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    metodo_pago ENUM('EFECTIVO', 'BOLETA_BANCARIA', 'TARJETA_POS') DEFAULT 'BOLETA_BANCARIA',
    fecha_pago TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (estudiante_id) REFERENCES estudiantes(id) ON DELETE RESTRICT
);

-- 3. TABLA DE CALIFICACIONES POR BIMESTRE (DISPARA TRIGGER DE PROMEDIO Y VALIDA SOLVENCIA)
CREATE TABLE calificaciones_bimestre (
    id INT AUTO_INCREMENT PRIMARY KEY,
    estudiante_id INT NOT NULL,
    curso VARCHAR(80) NOT NULL,
    b1 INT NOT NULL CHECK (b1 BETWEEN 0 AND 100),
    b2 INT NOT NULL CHECK (b2 BETWEEN 0 AND 100),
    b3 INT NOT NULL CHECK (b3 BETWEEN 0 AND 100),
    b4 INT NOT NULL CHECK (b4 BETWEEN 0 AND 100),
    nota_final DECIMAL(5,2) NOT NULL DEFAULT 0.00,
    resultado ENUM('APROBADO', 'RECUPERACION') DEFAULT 'APROBADO',
    docente_titular VARCHAR(100) DEFAULT 'Kevin Alejandro Vásquez Ramos',
    FOREIGN KEY (estudiante_id) REFERENCES estudiantes(id) ON DELETE RESTRICT
);

-- 4. BITÁCORA FORENSE DE AUDITORÍA ACADÉMICA Y CAJA ESCOLAR
CREATE TABLE bitacora_escolar (
    id INT AUTO_INCREMENT PRIMARY KEY,
    carnet_ref VARCHAR(20) NOT NULL,
    evento VARCHAR(80) NOT NULL,
    detalle VARCHAR(255) NOT NULL,
    usuario_auditor VARCHAR(100) DEFAULT 'Kevin Alejandro Vásquez Ramos',
    fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =====================================================================================
-- 5. TRIGGERS TRANSACCIONALES: SOLVENCIA AUTOMÁTICA Y CÁLCULO DE NOTAS MINEDUC
-- =====================================================================================
DELIMITER $$

-- Trigger A: Procesar pago de colegiatura, calcular recargo por mora y actualizar solvencia
CREATE TRIGGER trg_procesar_pago_colegiatura
BEFORE INSERT ON pagos_colegiatura
FOR EACH ROW
BEGIN
    DECLARE v_mora_actual INT;
    DECLARE v_carnet VARCHAR(20);

    SELECT meses_mora, carnet INTO v_mora_actual, v_carnet
    FROM estudiantes WHERE id = NEW.estudiante_id FOR UPDATE;

    SET NEW.total_pagado = NEW.monto_colegiatura + NEW.mora_recargo;

    -- Reducir meses de mora y actualizar estado de solvencia para exámenes
    IF v_mora_actual > 0 THEN
        SET v_mora_actual = v_mora_actual - 1;
    END IF;

    UPDATE estudiantes
    SET meses_mora = v_mora_actual,
        estado_solvencia = IF(v_mora_actual = 0, 'SOLVENTE', 'BLOQUEADO_MORA')
    WHERE id = NEW.estudiante_id;

    INSERT INTO bitacora_escolar (carnet_ref, evento, detalle, usuario_auditor)
    VALUES (
        v_carnet,
        CONCAT('PAGO COLEGIATURA - ', NEW.mes_pagado),
        CONCAT('Recibo: ', NEW.recibo_serie, ' | Total: Q', NEW.total_pagado, ' | Estado: ', IF(v_mora_actual = 0, 'SOLVENTE', 'CON MORA')),
        'Kevin Alejandro Vásquez Ramos'
    );
END$$

-- Trigger B: Calcular promedio final de 4 unidades y determinar Aprobado (>=60 MINEDUC)
CREATE TRIGGER trg_calcular_nota_mineduc
BEFORE INSERT ON calificaciones_bimestre
FOR EACH ROW
BEGIN
    DECLARE v_carnet VARCHAR(20);
    SELECT carnet INTO v_carnet FROM estudiantes WHERE id = NEW.estudiante_id;

    SET NEW.nota_final = ROUND((NEW.b1 + NEW.b2 + NEW.b3 + NEW.b4) / 4.0, 2);
    SET NEW.resultado = IF(NEW.nota_final >= 60.00, 'APROBADO', 'RECUPERACION');

    UPDATE estudiantes SET promedio_general = NEW.nota_final WHERE id = NEW.estudiante_id;

    INSERT INTO bitacora_escolar (carnet_ref, evento, detalle, usuario_auditor)
    VALUES (
        v_carnet,
        CONCAT('ACTA DE NOTAS MINEDUC - ', NEW.curso),
        CONCAT('Promedio Final: ', NEW.nota_final, ' pts | Dictamen: ', NEW.resultado),
        'Kevin Alejandro Vásquez Ramos'
    );
END$$

DELIMITER ;

-- =====================================================================================
-- 6. DATOS SEMILLA INSTITUCIONALES (GUATEMALA)
-- =====================================================================================
INSERT INTO estudiantes (codigo_mineduc, carnet, nombre_estudiante, grado_carrera, encargado_nombre, telefono_whatsapp, mensualidad_q, meses_mora, estado_solvencia, fecha_inscripcion) VALUES
('K26-09182-GT', '2026-001', 'Diego Alejandro Morales', '5to Bachillerato en Computación', 'Roberto Morales', '50255551010', 480.00, 0, 'SOLVENTE', '2026-01-10'),
('M26-44819-GT', '2026-002', 'Valeria Sofía Castellanos', '4to Bachillerato en Ciencias y Letras', 'Claudia Castellanos', '50255552020', 450.00, 2, 'BLOQUEADO_MORA', '2026-01-12'),
('J26-77310-GT', '2026-003', 'Sebastián Andrés Gómez', '6to Perito en Electrónica Digital', 'Jorge Gómez', '50255553030', 520.00, 0, 'SOLVENTE', '2026-01-14'),
('L26-33912-GT', '2026-004', 'Camila Fernanda Reyes', '5to Bachillerato en Computación', 'Patricia Reyes', '50255554040', 480.00, 1, 'BLOQUEADO_MORA', '2026-01-15');

INSERT INTO calificaciones_bimestre (estudiante_id, curso, b1, b2, b3, b4) VALUES
(1, 'Programación II & Bases de Datos SQL', 92, 95, 90, 96),
(2, 'Mantenimiento y Redes de Computadoras', 75, 80, 78, 82),
(3, 'Electrónica Digital & Compuertas Lógicas', 88, 91, 86, 94),
(4, 'Programación II & Bases de Datos SQL', 58, 62, 55, 59);

INSERT INTO pagos_colegiatura (estudiante_id, recibo_serie, mes_pagado, monto_colegiatura, mora_recargo, metodo_pago) VALUES
(1, 'REC-EDU-00101', 'OCTUBRE 2026', 480.00, 0.00, 'BOLETA_BANCARIA'),
(3, 'REC-EDU-00102', 'OCTUBRE 2026', 520.00, 0.00, 'TARJETA_POS');