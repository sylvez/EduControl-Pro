from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import mysql.connector
from mysql.connector import Error
import uuid

app = FastAPI(
    title="EduControl & Campus Pro v1.0 API",
    description="Propietario y Desarrollador Principal: Kevin Alejandro Vásquez Ramos",
    version="1.0.0"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

DB_CONFIG = {
    "host": "localhost",
    "user": "root",
    "password": "202502241",
    "database": "educontrol_gt_db"
}

def get_db():
    try:
        return mysql.connector.connect(**DB_CONFIG)
    except Error as e:
        raise HTTPException(status_code=500, detail=f"Error MySQL: {str(e)}")

class PagoColegiaturaCreate(BaseModel):
    estudiante_id: int
    mes_pagado: str = "OCTUBRE 2026"
    monto_colegiatura: float
    mora_recargo: float = 0.00
    metodo_pago: str = "BOLETA_BANCARIA"

class CalificacionCreate(BaseModel):
    estudiante_id: int
    curso: str
    b1: int
    b2: int
    b3: int
    b4: int

@app.get("/api/dashboard")
def obtener_campus_data():
    conn = get_db()
    cursor = conn.cursor(dictionary=True)
    try:
        cursor.execute("SELECT * FROM estudiantes ORDER BY id ASC")
        estudiantes = cursor.fetchall()

        cursor.execute("""
            SELECT c.*, e.carnet, e.codigo_mineduc, e.nombre_estudiante, e.grado_carrera, e.estado_solvencia
            FROM calificaciones_bimestre c
            JOIN estudiantes e ON c.estudiante_id = e.id
            ORDER BY c.id DESC
        """)
        calificaciones = cursor.fetchall()

        cursor.execute("SELECT * FROM bitacora_escolar ORDER BY id DESC LIMIT 100")
        bitacora = cursor.fetchall()

        return {
            "status": "ok",
            "propietario": "Kevin Alejandro Vásquez Ramos",
            "estudiantes": estudiantes,
            "calificaciones": calificaciones,
            "bitacora": bitacora
        }
    finally:
        cursor.close()
        conn.close()

@app.post("/api/pagos")
def registrar_pago_colegiatura(p: PagoColegiaturaCreate):
    conn = get_db()
    cursor = conn.cursor(dictionary=True)
    try:
        serie = f"REC-EDU-{str(uuid.uuid4())[:6].upper()}"
        cursor.execute("""
            INSERT INTO pagos_colegiatura (estudiante_id, recibo_serie, mes_pagado, monto_colegiatura, mora_recargo, metodo_pago)
            VALUES (%s, %s, %s, %s, %s, %s)
        """, (p.estudiante_id, serie, p.mes_pagado, p.monto_colegiatura, p.mora_recargo, p.metodo_pago))
        conn.commit()
        return {"mensaje": "Pago registrado y solvencia actualizada por Trigger SQL", "recibo": serie}
    except Error as e:
        conn.rollback()
        raise HTTPException(status_code=400, detail=e.msg)
    finally:
        cursor.close()
        conn.close()

@app.post("/api/calificaciones")
def registrar_acta_notas(c: CalificacionCreate):
    conn = get_db()
    cursor = conn.cursor(dictionary=True)
    try:
        cursor.execute("""
            INSERT INTO calificaciones_bimestre (estudiante_id, curso, b1, b2, b3, b4)
            VALUES (%s, %s, %s, %s, %s, %s)
        """, (c.estudiante_id, c.curso, c.b1, c.b2, c.b3, c.b4))
        conn.commit()
        return {"mensaje": "Acta de calificaciones procesada por Trigger MINEDUC"}
    except Error as e:
        conn.rollback()
        raise HTTPException(status_code=400, detail=e.msg)
    finally:
        cursor.close()
        conn.close()