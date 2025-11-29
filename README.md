# Evaluacion3_paquexpress
Archivos de la API y el Flutter

Se estandarizo la columna utilizada para el inicio de sesion.Archivo/ComponenteColumna OriginalColumna FinalPropositoTabla agentesusuarioemailSe renombro la columna para usar el correo electronico como identificador de login, resolviendo errores de columna desconocida (ERROR 1054).

Cambios en el Backend (FastAPI - main.py y database.py)
Se ajusto el codigo del backend para que fuera consistente con el campo email en la base de datos.

database.py
Se corrigio la definicion del modelo ORM para reflejar el cambio en la tabla agentes:

Python

class Agente(Base):
    __tablename__ = "agentes"
    # ...
    email = Column(String(50), unique=True, nullable=False, index=True) # <-- Cambio
    # ...

Se realizaron los cambios más importantes para la usabilidad y la corrección de errores de conexión.Código ModificadoCambio RealizadoPropósitobaseUrlhttp://10.0.2.2:8000 $\rightarrow$ http://127.0.0.1:8000Soluciona el error de conexión al ejecutar la aplicación en el navegador (Flutter Web), ya que 10.0.2.2 solo funciona para emuladores de Android.PaquexpressApp