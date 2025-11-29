from fastapi import FastAPI, HTTPException, UploadFile, File, Form
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from sqlalchemy import create_engine, Column, Integer, String, Text, DECIMAL, ForeignKey
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, Session
from pydantic import BaseModel
import os
import shutil
import requests
from datetime import datetime

# CONFIG DB
DATABASE_URL = "mysql+pymysql://root:root@localhost/paquexpress_db"
engine = create_engine(DATABASE_URL, pool_pre_ping=True)
SessionLocal = sessionmaker(bind=engine)
Base = declarative_base()

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# MODELOS
class Agente(Base):
    __tablename__ = "Agentes"
    id_agente = Column(Integer, primary_key=True)
    nombre = Column(String(100))
    email = Column(String(100), unique=True)

class Paquete(Base):
    __tablename__ = "Paquetes"
    id_paquete = Column(Integer, primary_key=True)
    codigo_seguimiento = Column(String(20), unique=True)
    destinatario = Column(String(150))
    direccion = Column(Text)
    latitud = Column(DECIMAL(10,8))
    longitud = Column(DECIMAL(11,8))
    id_agente_asignado = Column(Integer)
    estado = Column(String(20), default="pendiente")

class RegistroEntrega(Base):
    __tablename__ = "RegistrosEntrega"
    id_registro = Column(Integer, primary_key=True)
    id_paquete = Column(Integer, ForeignKey("Paquetes.id_paquete"), unique=True)
    id_agente = Column(Integer)
    latitud = Column(DECIMAL(10,8))
    longitud = Column(DECIMAL(11,8))
    foto_ruta = Column(String(500))
    direccion_geocodificada = Column(Text)

Base.metadata.create_all(bind=engine)

# PYDANTIC
class PaqueteResponse(BaseModel):
    id_paquete: int
    codigo_seguimiento: str
    destinatario: str
    direccion: str
    latitud: float = None
    longitud: float = None

    class Config:
        from_attributes = True

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# LOGIN SUPER SIMPLE (SIN JWT, SIN BCRYPT)
@app.post("/login")
async def login(username: str = Form(...), password: str = Form(...), db: Session = Depends(get_db)):
    if password != "123456":
        raise HTTPException(status_code=401, detail="Credenciales incorrectas")
    
    user = db.query(Agente).filter(Agente.email == username).first()
    if not user:
        raise HTTPException(status_code=401, detail="Credenciales incorrectas")
    
    return {"agente_id": user.id_agente}

# PAQUETES
@app.get("/paquetes/pendientes/{agente_id}", response_model=list[PaqueteResponse])
async def get_paquetes(agente_id: int, db: Session = Depends(get_db)):
    paquetes = db.query(Paquete).filter(
        Paquete.id_agente_asignado == agente_id,
        Paquete.estado == "pendiente"
    ).all()
    return paquetes

# ENTREGA
@app.post("/entrega/completar")
async def completar_entrega(
    paquete_id: int = Form(...),
    latitud: float = Form(...),
    longitud: float = Form(...),
    file: UploadFile = File(...),
    db: Session = Depends(get_db)
):
    os.makedirs("uploads", exist_ok=True)
    filename = f"{paquete_id}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.jpg"
    ruta = f"uploads/{filename}"
    with open(ruta, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)

    entrega = RegistroEntrega(
        id_paquete=paquete_id,
        id_agente=1,
        latitud=latitud,
        longitud=longitud,
        foto_ruta=ruta,
        direccion_geocodificada="Capturada"
    )
    db.add(entrega)

    paquete = db.query(Paquete).filter(Paquete.id_paquete == paquete_id).first()
    if paquete:
        paquete.estado = "entregado"
    db.commit()

    return {"mensaje": "Entrega registrada con éxito"}

app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")