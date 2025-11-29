-- Base de datos: paquexpress
CREATE DATABASE IF NOT EXISTS paquexpress CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE paquexpress;

-- Tabla de agentes (repartidores)
CREATE TABLE agentes (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nombre_completo VARCHAR(100) NOT NULL,
    usuario VARCHAR(50) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tabla de paquetes asignados
CREATE TABLE paquetes (
    id INT AUTO_INCREMENT PRIMARY KEY,
    codigo_seguimiento VARCHAR(20) UNIQUE NOT NULL,
    destinatario VARCHAR(100) NOT NULL,
    direccion TEXT NOT NULL,
    latitud DECIMAL(10, 8),
    longitud DECIMAL(11, 8),
    agente_id INT,
    estado ENUM('pendiente', 'entregado') DEFAULT 'pendiente',
    FOREIGN KEY (agente_id) REFERENCES agentes(id)
);

-- Tabla de evidencias de entrega
CREATE TABLE entregas (
    id INT AUTO_INCREMENT PRIMARY KEY,
    paquete_id INT,
    foto_ruta VARCHAR(255) NOT NULL,
    latitud_entrega DECIMAL(10, 8) NOT NULL,
    longitud_entrega DECIMAL(11, 8) NOT NULL,
    direccion_geocodificada TEXT,
    fecha_entrega TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (paquete_id) REFERENCES paquetes(id)
);

-- Usuario de prueba (usuario: driver1 | contraseña: 12345)
INSERT INTO agentes (nombre_completo, usuario, password_hash) 
VALUES ('Juan Pérez López', 'driver1', '$2b$12$9f9Y5qX7z6v8b5n3m1k2lO0p8i7u6y5t4r3e2w1q0a9s8d7f6g5h4'); -- bcrypt de "12345"

-- Paquetes de ejemplo asignados al agente 1
INSERT INTO paquetes (codigo_seguimiento, destinatario, direccion, latitud, longitud, agente_id) VALUES
('PKX001234', 'María González', 'Av. Universidad 100, Santiago de Querétaro, QRO', -100.38896, 20.59416, 1),
('PKX001235', 'Carlos Ramírez', 'Calle 5 de Enero #45, Juriquilla, Querétaro', -100.4403, 20.7021, 1),
('PKX001236', 'Ana Martínez', 'Prolongación Zaragoza 200, Querétaro', -100.3778, 20.5879, 1);