"""
Configuración compartida de pytest.

Importante: setea DATABASE_URL ANTES de importar app.core.db, porque
`db.py` crea el engine al importar y falla si la URL está vacía.
Los tests que no necesitan DB usan una URL fake.
"""
import os

os.environ.setdefault(
    "DATABASE_URL",
    "postgresql://fake:fake@localhost:5432/fake_db",
)