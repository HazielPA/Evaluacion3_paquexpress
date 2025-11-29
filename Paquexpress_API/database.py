# backend/database.py
from sqlalchemy import create_engine, Column, Integer, String, Text, DECIMAL, TIMESTAMP, ForeignKey, Enum
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, relationship
from datetime import datetime
import os

# ===========================================
# CONFIGURACIÓN DE BASE DE DATOS
# ===========================================
DATABASE_URL = "mysql+pymysql://root:root@localhost/paquexpress"
# Cambia "root:root" si usas otro usuario/contraseña

engine = create_engine(DATABASE_URL, echo=False, future=True)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()

# ===========================================
# MODELOS DE TABLAS
# ===========================================

class Agente(Base):
    __tablename__ = "agentes"
    
    id = Column(Integer, primary_key=True, index=True)
    nombre_completo = Column(String(100), nullable=False)
    usuario = Column(String(50), unique=True, nullable=False, index=True)
    password_hash = Column(String(255), nullable=False)
    creado_en = Column(TIMESTAMP, default=datetime.utcnow)

    paquetes = relationship("Paquete", back_populates="agente")


class Paquete(Base):
    __tablename__ = "paquetes"
    
    id = Column(Integer, primary_key=True, index=True)
    codigo_seguimiento = Column(String(20), unique=True, nullable=False)
    destinatario = Column(String(100), nullable=False)
    direccion = Column(Text, nullable=False)
    latitud = Column(DECIMAL(10, 8))
    longitud = Column(DECIMAL(11, 8))
    agente_id = Column(Integer, ForeignKey("agentes.id"))
    estado = Column(String(20), default="pendiente")  # pendiente / entregado

    agente = relationship("Agente", back_populates="paquetes")
    entrega = relationship("Entrega", uselist=False, back_populates="paquete")


class Entrega(Base):
    __tablename__ = "entregas"
    
    id = Column(Integer, primary_key=True, index=True)
    paquete_id = Column(Integer, ForeignKey("paquetes.id"), unique=True)
    foto_ruta = Column(String(255), nullable=False)
    latitud_entrega = Column(DECIMAL(10, 8), nullable=False)
    longitud_entrega = Column(DECIMAL(11, 8), nullable=False)
    direccion_geocodificada = Column(Text)
    fecha_entrega = Column(TIMESTAMP, default=datetime.utcnow)

    paquete = relationship("Paquete", back_populates="entrega")


# ===========================================
# FUNCIÓN PARA OBTENER SESIÓN
# ===========================================
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# ===========================================
# CREAR TABLAS (solo la primera vez o si no existen)
# ===========================================
def crear_tablas():
    Base.metadata.create_all(bind=engine)

# Si ejecutas este archivo directamente, crea las tablas
if __name__ == "__main__":
    print("Creando tablas en la base de datos paquexpress...")
    crear_tablas()
    print("Tablas creadas con éxito!")