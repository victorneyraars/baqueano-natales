"""Fixtures especificas del modulo oficios."""
import pytest
import pytest_asyncio
from uuid import uuid4

from app.modules.auth.models import RolUsuario, Usuario
from app.modules.oficios.models import (
    MecanicaCategoriaServicio,
    ObjetoServicio,
    TipoObjetoServicio,
    TipoVehiculo,
    Vehiculo,
)
from app.modules.prestadores.models import (
    CategoriaOficio,
    EstadoPrestador,
    Prestador,
)


@pytest_asyncio.fixture
async def usuario_cliente(db):
    """Usuario con rol CLIENTE."""
    user = Usuario(
        firebase_uid=f"test_{uuid4().hex[:12]}",
        email=f"test_{uuid4().hex[:8]}@test.com",
        nombre="Test",
        apellido="Cliente",
        rol=RolUsuario.CLIENTE,
        activo=True,
    )
    db.add(user)
    await db.flush()
    return user


@pytest_asyncio.fixture
async def categoria_oficio(db):
    """Categoria de oficio para el prestador."""
    cat = CategoriaOficio(
        nombre=f"Test {uuid4().hex[:6]}",
        slug=f"test-{uuid4().hex[:6]}",
    )
    db.add(cat)
    await db.flush()
    return cat


@pytest_asyncio.fixture
async def prestador_test(db, usuario_cliente, categoria_oficio):
    """Prestador verificado perteneciente al usuario_cliente."""
    p = Prestador(
        usuario_id=usuario_cliente.id,
        categoria_id=categoria_oficio.id,
        nombre="Taller Test",
        slug=f"taller-test-{uuid4().hex[:6]}",
        estado=EstadoPrestador.VERIFICADO,
    )
    db.add(p)
    await db.flush()
    return p


@pytest_asyncio.fixture
async def objeto_servicio_test(db, usuario_cliente):
    """Objeto de servicio tipo VEHICULO del cliente."""
    obj = ObjetoServicio(
        tipo=TipoObjetoServicio.VEHICULO,
        propietario_id=usuario_cliente.id,
        alias="Auto test",
    )
    db.add(obj)
    await db.flush()
    return obj


@pytest_asyncio.fixture
async def vehiculo_test(db, objeto_servicio_test):
    """Vehiculo asociado al objeto_servicio_test."""
    v = Vehiculo(
        objeto_servicio_id=objeto_servicio_test.id,
        patente=f"TST{uuid4().hex[:4].upper()}",
        marca="Test",
        modelo="Model",
        anio=2020,
        tipo_vehiculo=TipoVehiculo.SEDAN,
        kilometraje_actual=1000,
    )
    db.add(v)
    await db.flush()
    return v


@pytest_asyncio.fixture
async def categoria_mecanica(db):
    """Categoria de mecanica (Frenos, etc)."""
    c = MecanicaCategoriaServicio(
        nombre=f"CatTest {uuid4().hex[:6]}",
        slug=f"cat-test-{uuid4().hex[:6]}",
        orden=0,
    )
    db.add(c)
    await db.flush()
    return c


@pytest_asyncio.fixture
async def turno_test(db, usuario_cliente, prestador_test, objeto_servicio_test):
    """Turno pendiente en el futuro."""
    from datetime import datetime, timedelta, timezone
    from app.modules.oficios.models import EstadoTurno, Turno

    t = Turno(
        cliente_id=usuario_cliente.id,
        prestador_id=prestador_test.id,
        objeto_servicio_id=objeto_servicio_test.id,
        fecha_inicio=datetime.now(timezone.utc) + timedelta(days=2),
        duracion_min=30,
        estado=EstadoTurno.PENDIENTE,
        motivo="Cambio de aceite",
    )
    db.add(t)
    await db.flush()
    return t
