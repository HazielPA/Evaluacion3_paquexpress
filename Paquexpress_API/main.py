from fastapi import FastAPI, Depends, HTTPException, UploadFile, File, Form, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from fastapi.staticfiles import StaticFiles
from sqlalchemy import create_engine, Column, Integer, String, Text, DECIMAL, ForeignKey, TIMESTAMP
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, Session
from pydantic import BaseModel
from datetime import datetime, timedelta
import os
import shutil
import requests
import bcrypt  # ← Usamos bcrypt directamente (adiós passlib)

# ===================== CONFIG =====================
DATABASE_URL = "mysql+pymysql://root:root@localhost/paquexpress_db"
engine = create_engine(DATABASE_URL, pool_pre_ping=True)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

app = FastAPI(title="Paquexpress API - Entregas Seguras")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# JWT config
SECRET_KEY = "paquexpress2025superclave123456789"
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 1440

# ===================== MODELOS SQLALCHEMY =====================
class Agente(Base):
    __tablename__ = "Agentes"
    id_agente = Column(Integer, primary_key=True, index=True)
    nombre = Column(String(100))
    email = Column(String(100), unique=True, index=True)
    password_hash = Column(String(255))

class Paquete(Base):
    __tablename__ = "Paquetes"
    id_paquete = Column(Integer, primary_key=True, index=True)
    codigo_seguimiento = Column(String(20), unique=True, index=True)
    destinatario = Column(String(150))
    direccion = Column(Text)
    latitud = Column(DECIMAL(10,8))
    longitud = Column(DECIMAL(11,8))
    id_agente_asignado = Column(Integer, ForeignKey("Agentes.id_agente"))
    estado = Column(String(20), default="pendiente")

class RegistroEntrega(Base):
    __tablename__ = "RegistrosEntrega"
    id_registro = Column(Integer, primary_key=True)
    id_paquete = Column(Integer, ForeignKey("Paquetes.id_paquete"), unique=True)
    id_agente = Column(Integer, ForeignKey("Agentes.id_agente"))
    latitud = Column(DECIMAL(10,8))
    longitud = Column(DECIMAL(11,8))
    foto_ruta = Column(String(500))
    direccion_geocodificada = Column(Text)
    fecha_entrega = Column(TIMESTAMP, server_default="CURRENT_TIMESTAMP", default=datetime.utcnow)

Base.metadata.create_all(bind=engine)

# ===================== PYDANTIC MODELS =====================
class Token(BaseModel):
    access_token: str
    token_type: str
    agente_id: int

class PaqueteResponse(BaseModel):
    id_paquete: int
    codigo_seguimiento: str
    destinatario: str
    direccion: str
    latitud: float = None
    longitud: float = None

    class Config:
        from_attributes = True

# ===================== DEPENDENCIAS =====================
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# ===================== AUTH CON BCRYPT PURO (0 ERRORES) =====================
def verify_password(plain_password: str, hashed_password: str) -> bool:
    try:
        return bcrypt.checkpw(plain_password.encode('utf-8'), hashed_password.encode('utf-8'))
    except:
        return False

def create_access_token(data: dict):
    to_encode = data.copy()
    expire = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode.update({"exp": expire})
    return to_encode["sub"] + ".fakejwt2025"  # Token simple para desarrollo

@app.post("/login", response_model=Token)
async def login(form_data: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    user = db.query(Agente).filter(Agente.email == form_data.username).first()
    if not user or not verify_password(form_data.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Credenciales incorrectas")
    
    return {
        "access_token": create_access_token({"sub": str(user.id_agente)}),
        "token_type": "bearer",
        "agente_id": user.id_agente
    }

# ===================== RUTAS =====================
@app.get("/paquetes/pendientes/{agente_id}", response_model=list[PaqueteResponse])
async def get_paquetes(agente_id: int, db: Session = Depends(get_db)):
    paquetes = db.query(Paquete).filter(
        Paquete.id_agente_asignado == agente_id,
        Paquete.estado == "pendiente"
    ).all()
    return paquetes

@app.post("/entrega/completar")
async def completar_entrega(
    paquete_id: int = Form(...),
    latitud: float = Form(...),
    longitud: float = Form(...),
    file: UploadFile = File(...),
    db: Session = Depends(get_db)
):
    # Guardar foto
    os.makedirs("uploads", exist_ok=True)
    filename = f"{datetime.now().strftime('%Y%m%d_%H%M%S')}_{file.filename}"
    ruta = f"uploads/{filename}"
    with open(ruta, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)

    # Geocodificación inversa
    try:
        url = f"https://nominatim.openstreetmap.org/reverse?lat={latitud}&lon={longitud}&format=json"
        r = requests.get(url, headers={"User-Agent": "Paquexpress/1.0"}, timeout=10)
        direccion = r.json().get("display_name", "Sin dirección") if r.ok else "GPS capturado"
    except:
        direccion = "GPS capturado"

    # Guardar entrega
    entrega = RegistroEntrega(
        id_paquete=paquete_id,
        id_agente=1,  # En producción se saca del JWT
        latitud=latitud,
        longitud=longitud,
        foto_ruta=ruta,
        direccion_geocodificada=direccion
    )
    db.add(entrega)

    # Marcar paquete como entregado
    paquete = db.query(Paquete).filter(Paquete.id_paquete == paquete_id).first()
    if paquete:
        paquete.estado = "entregado"
    db.commit()

    return {"mensaje": "Entrega registrada con éxito", "foto_url": f"http://127.0.0.1:8000/{ruta}"}

# Servir fotos
app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")