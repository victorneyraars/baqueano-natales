# Módulo `social`

Publicación en redes sociales (Facebook, Instagram, Google Business) de eventos del sistema.

## Por qué existe

Los prestadores y comercios de Puerto Natales necesitan promocionarse en redes para conseguir clientes. Este módulo les da esa capacidad sin depender de que publiquen a mano, y sin acoplar el sistema a una red específica.

## Modelo de datos

### cuentas_sociales
Cuentas conectadas a una red. Multi-tenant vía (propietario_tipo, propietario_id):
- propietario_tipo=baqueano, propietario_id=NULL → cuenta central
- propietario_tipo=prestador, propietario_id=<uuid> → cuenta del prestador
- propietario_tipo=comercio, propietario_id=<uuid> → cuenta del comercio

Restricción UNIQUE(red, external_id) evita conectar dos veces la misma página.

### tokens_sociales
Tokens OAuth cifrados con Fernet (app.core.crypto). Separado de la cuenta para poder rotar tokens sin perder la identidad.

### publicaciones_sociales
Cola de publicaciones. recurso_tipo + recurso_id identifican QUÉ se publica sin acoplar el módulo a los verticales.

### config_social
Configuración de qué se publica automáticamente y dónde. Fila global + opcional por propietario.

## Endpoints (Etapa 1: solo admin)

    GET    /api/v1/admin/social/cuentas
    POST   /api/v1/admin/social/cuentas
    GET    /api/v1/admin/social/cuentas/{id}
    PATCH  /api/v1/admin/social/cuentas/{id}
    DELETE /api/v1/admin/social/cuentas/{id}
    GET    /api/v1/admin/social/config
    PATCH  /api/v1/admin/social/config
    GET    /api/v1/admin/social/publicaciones
    POST   /api/v1/admin/social/publicaciones
    GET    /api/v1/admin/social/publicaciones/{id}

Todos requieren rol admin (AdminUser de deps.py).

## Roadmap

| Etapa | Qué | Estado |
|---|---|---|
| 1 | Esqueleto: modelos, schemas, services, deps, router admin | OK |
| 2 | OAuth Facebook | Pendiente |
| 3 | Publicación básica FB con worker + reintentos | Pendiente |
| 4 | Instagram vía Facebook | Pendiente |
| 5 | Integración con vertical prestadores | Pendiente |
| 6 | Frontend admin | Pendiente |
| 7 | Frontend propietario | Pendiente |
| 8 | Google Business Profile | Pendiente |
| 9 | Módulo promocion (plantillas + afiche SVG) | Pendiente |

## Decisiones de diseño

### Por qué recurso_tipo + recurso_id y no FK
Un FK duro a prestadores.id acoplaría este módulo a ese vertical. Con recurso_tipo + recurso_id, el módulo social no depende de ningún vertical. Regla: los verticales importan a social, no al revés.

### Por qué sin microservicio
El proyecto anterior usaba un microservicio separado. Agregaba dos deploys, dos logs y un salto HTTP extra por un beneficio nulo. Acá va todo en el mismo backend.

### Por qué no publicar tokens en responses
CuentaSocialResponse NUNCA incluye access_token ni refresh_token. Los tokens viven cifrados y solo se descifran en memoria cuando hace falta.

### Por qué fallar en startup si falta TOKEN_ENCRYPTION_KEY
Preferimos que el backend no arranque en producción a que guarde tokens en claro silenciosamente.

## Cómo agregar una red nueva (ej: LinkedIn)

1. Agregar el valor a Red en models.py
2. Generar migración que actualice el ENUM de Postgres (ALTER TYPE)
3. Agregar linkedin_service.py con la lógica de publicación
4. Agregar el flujo OAuth
5. Agregar publicar_en_linkedin a ConfigSocial + schema
6. Agregar test_linkedin_service.py

Ningún otro archivo cambia.

## Cómo correr los tests

Local (sin DB):
    cd backend
    .\.venv\Scripts\python.exe -m pytest tests/modules/social/ -v

Server (con DB):
    ssh deploy@104.129.59.151 "cd ~/baqueano-natales && docker compose exec -T backend pytest tests/ -v"

## Referencias

- Cifrado: app/core/crypto.py
- Configuración: app/core/config.py (TOKEN_ENCRYPTION_KEY)
- Mixins: app/core/mixins.py
- Patrón de referencia: app/modules/prestadores/