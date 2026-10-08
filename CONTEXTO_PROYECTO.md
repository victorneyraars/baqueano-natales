# Baqueano Natales — Contexto Completo del Proyecto

> **Última actualización:** 2026-10-08
> **Propósito:** Documento maestro que resume el estado completo del proyecto para retomar el trabajo en cualquier momento sin perder contexto.

---

## 📋 Changelog reciente

### 2026-10-08 — Fix login con Google (end-to-end)
- ✅ **Login con Google funcional end-to-end** (Google → Firebase → Backend → JWT → Home)
- ✅ **Persistencia de sesión funcional** (sobrevive al cierre de la app)
- 🔧 Migración de `google_sign_in` **v7 → v6** (v7 tenía bug conocido con Credential Manager)
- 🔧 Agregado `serverClientId` al constructor de `GoogleSignIn` (obligatorio para `idToken` en Android)
- 🔧 Deshabilitado Credential Manager vía `meta-data` en AndroidManifest
- 🔧 Agregado `network_security_config.xml` para permitir HTTP en dev
- 🔧 Cambio de `https://` a `http://` en `AppConfig.dev` (server no tiene SSL aún)
- ⚠️ **SHA-1 de debug cambió** (ver sección Firebase)
- ✅ **App admin verificada** (login + persistencia funcional en `flutter run --flavor admin`)

### 2026-10-08 (cont.) — Módulo comercios (backend)
- ✅ **Nuevo módulo `comercios`** con 3 tablas (categorias_comercio, comercios, horarios_comercio)
- ✅ Migración Alembic aplicada en producción (`d6654af1dbf2`)
- ✅ 20 endpoints nuevos (público, propietario, admin)
- ✅ 9 categorías base seedeadas en la DB
- ✅ Endpoint público `/api/v1/comercios/categorias` funcionando
- ⏳ Pendiente: frontend Flutter del módulo

### 2026-10-08 (cont.) — Fixes críticos y migración de emulador
- ✅ **Fix `DioClient.validateStatus`**: 4xx ahora se mapean a `ApiException` (antes intentaban parsear el body como modelo)
- ✅ **`Comercio.fromJson` defensivo**: parseo robusto con logging de campos null
- ✅ **Migración de emulador Android 17 → Android 14** (`Pixel6_API34`)
  - Motivo: Android 17 (API 37) tiene bugs sin resolver de IME (teclado virtual no se despliega) y OpenGL (crash con `swiftshader_indirect`)
  - Android 14 funciona perfecto: teclado físico Y virtual OK
- 📌 Tip de emulador: usar `-gpu swiftshader_indirect` en el launch

### 2026-10-08 (cont.) — Frontend comercios (cliente)
- ✅ Modelos Dart: `Categoria`, `Horario`, `Comercio` (+ enum `EstadoComercio`)
- ✅ Repositorio `ComercioRepository` con 20+ métodos (público, dueño, admin)
- ✅ Providers Riverpod (categorías, listado con filtros, detalle, admin)
- ✅ Widget `ComercioCard` reutilizable
- ✅ Pantalla lista de comercios (búsqueda + chips categorías + filtros destacados/delivery)
- ✅ Pantalla detalle (portada, logo, contacto, ubicación, horarios multi-franja)
- ✅ Router corregido (permite rutas autenticadas fuera de `/home`)
- ✅ Home linkeado a Comercios
- ✅ **Flujo end-to-end verificado en emulador** con comercio de prueba
- ⏳ Pendiente: pantallas dueño (mis comercios, crear/editar, horarios)
- ⏳ Pendiente: pantallas admin (verificar/rechazar, CRUD categorías)

### 2026-10-08 (cont.) — App admin verificada
- ✅ Login con Google funcional en flavor admin
- ✅ Home admin con tema morado + badge ADMIN
- ✅ SHA-1 nuevo registrado en Firebase para `cl.baqueanonatales.admin`

---

## 📌 Resumen ejecutivo

**Baqueano Natales** es una superapp regional para Puerto Natales, Chile (movilidad, delivery, comercio local). Actualmente en desarrollo activo con backend desplegado y app Flutter con login funcional completo.

**Estado actual:**
- ✅ Backend desplegado en producción (server nuevo)
- ✅ 3 módulos backend completos (auth, usuarios, admin)
- ✅ App Flutter con flavors (client + admin)
- ✅ Login con Google funcional **end-to-end**
- ✅ Persistencia de sesión funcional
- ✅ App admin verificada (login + Home con badge ADMIN)
- ✅ **Backend módulo comercios** (modelos, migración, endpoints, seed)
- ⏳ Pendiente: frontend Flutter del módulo comercios
- ⏳ Pendiente: features core restantes (mapa, delivery, carta QR, recompensas)

---

## 🖥️ Servidores

### Server nuevo (producción activa)
| Item | Valor |
|---|---|
| **Hostname** | `baqueano-natales-prod` |
| **IP pública** | `104.129.59.151` |
| **Proveedor** | RackNerd |
| **Panel** | `ctrl.racknerd.com` |
| **OS** | Ubuntu 24.04.5 LTS |
| **Hardware** | 3 vCPU / 4 GB RAM / 60 GB disco |
| **Acceso** | `ssh deploy@104.129.59.151` (clave SSH) |
| **Usuario** | `deploy` (sudo configurado) |

**Puertos abiertos (UFW):** 22 (SSH), 80 (HTTP), 443 (HTTPS).

**Estado actual del server:**
- ✅ HTTP (puerto 80) responde OK: `curl http://104.129.59.151/health` → `{"status":"ok"}`
- ❌ HTTPS (puerto 443) **no configurado** (Let's Encrypt es Fase 6)

**Servicios corriendo (Docker):**
- `baqueano_backend` — FastAPI en `127.0.0.1:8000`
- `baqueano_db` — PostgreSQL 16 en `127.0.0.1:5432`
- `baqueano_nginx` — Reverse proxy en `0.0.0.0:80,443`

**Path del proyecto:** `/home/deploy/baqueano-natales/`

### Server viejo (a decommissionar)
| Item | Valor |
|---|---|
| **Hostname** | `superapp-natales-backend` |
| **IP pública** | `161.118.240.229` |
| **IP privada** | `10.0.0.236` |
| **Proveedor** | Oracle Cloud |
| **OS** | Ubuntu 22.04.5 LTS |
| **Acceso** | `ssh ubuntu@161.118.240.229` |

**Estado:** corriendo el sistema viejo. **Será apagado** cuando la migración esté completa y validada.

---

## 📦 Repositorios GitHub

**Cuenta:** `victorneyraars`

| Repo | Descripción | Estado |
|---|---|---|
| `baqueano-natales` | Monorepo (backend + flutter + deploy + docs) | ✅ Activo |
| `baqueano-natales-legacy` | Repo viejo (build 400 del 24 agosto) | 📦 Archivado |
| `rnstp-service` | Microservicio RNSTP | ⏳ Vacío (a poblar) |
| `studiodigital360` | Otro proyecto (Next.js) | ✅ |
| `sealquilamarido-web` | Otro proyecto (Astro en Vercel) | ✅ |

**Rama principal:** `main`.

---

## 🏗️ Stack del backend

### Tecnologías
| Capa | Tecnología | Versión |
|---|---|---|
| **Lenguaje** | Python | 3.12 |
| **Framework** | FastAPI | 0.115.6 |
| **ORM** | SQLAlchemy | 2.0.36 (async) |
| **Migraciones** | Alembic | 1.14.0 |
| **BD** | PostgreSQL | 16 (contenedor) |
| **Driver async** | asyncpg | 0.30.0 |
| **Driver sync** | psycopg2-binary | 2.9.10 |
| **Validación** | Pydantic | 2.10.4 |
| **Firebase** | firebase-admin | 6.6.0 |
| **HTTP client** | httpx | 0.28.1 |
| **Rate limiting** | slowapi | 0.1.9 |
| **Procesamiento imágenes** | Pillow | 11.0.0 |
| **Validación archivos** | filetype | 1.2.0 |
| **Contenedores** | Docker | 29.8.2 |
| **Orquestación** | Docker Compose | 5.6.0 |
| **Reverse proxy** | Nginx | 1.27 (alpine) |

### Estructura del proyecto
```
backend/
├── app/
│   ├── core/                    # Configuración transversal
│   │   ├── config.py            # Pydantic Settings
│   │   ├── db.py                # SQLAlchemy async
│   │   ├── firebase.py          # Firebase Admin SDK
│   │   ├── logging.py           # Logs JSON
│   │   └── security.py          # JWT propio
│   ├── modules/                 # Por dominio de negocio
│   │   ├── auth/
│   │   │   ├── models.py        # Usuario + RolUsuario (enum)
│   │   │   ├── schemas.py
│   │   │   ├── deps.py          # get_current_user, require_admin
│   │   │   ├── services.py      # login con Google
│   │   │   └── routes.py
│   │   ├── usuarios/
│   │   │   ├── schemas.py
│   │   │   ├── services.py
│   │   │   └── routes.py
│   │   └── admin/
│   │       ├── schemas.py
│   │       ├── services.py
│   │       ├── routes.py
│   │       └── seed.py          # Promover admin
│   ├── shared/
│   │   └── storage/
│   │       ├── base.py          # Interfaz AvatarStorage (ABC)
│   │       └── local.py         # Implementación local
│   └── main.py
├── alembic/                     # Migraciones
├── secrets/                     # ⚠️ NO commitear
│   └── firebase-service-account.json
├── .dockerignore
├── .env.example
├── Dockerfile
└── requirements.txt
```

### Modelo de datos (actual)

**Tabla `usuarios`:**
```
id (UUID, PK)
firebase_uid (varchar 128, unique, not null)
email (varchar 255, unique, nullable)
phone (varchar 20, unique, nullable)
nombre (varchar 100, nullable)
apellido (varchar 100, nullable)
avatar_url (varchar 500, nullable)
rol (enum: cliente, comercio, prestador, admin)
verificado (bool, default false)
activo (bool, default true)
tiene_google (bool, default false)
tiene_whatsapp (bool, default false)
tiene_sms (bool, default false)
created_at (timestamp tz)
updated_at (timestamp tz)
ultimo_login (timestamp tz, nullable)

Índices: email, phone, firebase_uid, rol
```

### Endpoints activos

**Sistema:**
- `GET /health`
- `GET /`

**Auth:**
- `POST /api/v1/auth/google` — Login con Google (recibe id_token de Firebase)
- `GET /api/v1/auth/me` — Datos del usuario autenticado

**Usuarios:**
- `GET /api/v1/usuarios/me` — Perfil completo
- `PATCH /api/v1/usuarios/me` — Editar nombre/apellido
- `POST /api/v1/usuarios/me/avatar` — Subir avatar (multipart)
- `DELETE /api/v1/usuarios/me` — Desactivar cuenta (soft delete)
- `GET /api/v1/usuarios/{id}` — Perfil público

**Admin (requieren rol admin):**
- `GET /api/v1/admin/usuarios` — Listar con filtros + paginación
- `GET /api/v1/admin/usuarios/{id}` — Detalle
- `PATCH /api/v1/admin/usuarios/{id}/rol` — Cambiar rol
- `PATCH /api/v1/admin/usuarios/{id}/verificar` — Verificar/desverificar
- `PATCH /api/v1/admin/usuarios/{id}/reactivar` — Reactivar
- `DELETE /api/v1/admin/usuarios/{id}` — Desactivar
- `GET /api/v1/admin/estadisticas` — Métricas globales

---

## 📱 Stack de Flutter (PC Windows)

### Entorno de desarrollo
| Item | Valor |
|---|---|
| **Flutter SDK** | 3.47.6 (stable) |
| **Dart** | 3.13.5 |
| **DevTools** | 2.60.0 |
| **Flutter path** | `D:\dev\flutter` |
| **Android Studio** | 2026.2.1 Rabbit |
| **Android SDK** | API 37, build-tools 36.0.0 |
| **NDK** | 28.2.13676358 |
| **JDK** | 25 (bundled con Android Studio) |
| **VS Code** | 1.140.0 + extensión Flutter |
| **Emulador** | `Pixel6_API34` (Android 14 — RECOMENDADO) |
| **Emulador viejo** | `Pixel6_API37` (Android 17 — deprecado, tiene bugs de IME/GPU) |
| **PUB_CACHE** | `D:\DartCache` |

### Configuración crítica del PC
**Variable de entorno (User):**
```
PUB_CACHE=D:\DartCache
```

**`android/gradle.properties`:**
```
org.gradle.jvmargs=-Xmx8G -XX:MaxMetaspaceSize=4G -XX:ReservedCodeCacheSize=512m -XX:+HeapDumpOnOutOfMemoryError
android.useAndroidX=true
android.newDsl=false
android.builtInKotlin=false
kotlin.incremental=false
org.gradle.daemon=false
org.gradle.parallel=false
```

**Razón:** evitar el error de Kotlin daemon "different roots" entre `D:\` (proyecto) y `C:\` (pub-cache original). Trade-off: builds más lentos pero estables.

### Estructura del proyecto Flutter
```
flutter/
├── lib/
│   ├── main_client.dart             # Entry point cliente
│   ├── main_admin.dart              # Entry point admin
│   ├── core/
│   │   ├── config/
│   │   │   └── app_config.dart      # AppConfig + enum AppType/Environment
│   │   ├── network/
│   │   │   ├── api_exceptions.dart  # ApiException + variantes
│   │   │   └── dio_client.dart      # Dio con interceptores JWT
│   │   ├── storage/
│   │   │   └── secure_storage.dart  # flutter_secure_storage wrapper
│   │   └── theme/
│   │       └── app_theme.dart       # Verde (client) / morado (admin)
│   ├── features/
│   │   ├── auth/
│   │   │   ├── domain/
│   │   │   │   └── user.dart        # Modelo User
│   │   │   ├── data/
│   │   │   │   ├── auth_repository.dart
│   │   │   │   └── auth_notifier.dart
│   │   │   └── presentation/
│   │   │       ├── splash_screen.dart
│   │   │       └── login_screen.dart
│   │   └── home/
│   │       └── presentation/
│   │           └── home_screen.dart
│   └── shared/
│       └── router/
│           └── app_router.dart      # GoRouter + auto-redirect
├── android/
│   ├── app/
│   │   ├── build.gradle.kts         # Flavors client + admin + deps Credential Manager
│   │   ├── google-services.json     # Firebase (SÍ va al repo)
│   │   └── src/main/
│   │       ├── AndroidManifest.xml  # Con meta-data + networkSecurityConfig
│   │       ├── kotlin/cl/baqueanonatales/
│   │       │   └── MainActivity.kt
│   │       └── res/xml/
│   │           └── network_security_config.xml  # Permite HTTP solo a 104.129.59.151
│   └── gradle.properties
├── ios/
├── pubspec.yaml
└── README.md
```

### Dependencias Flutter
```yaml
dependencies:
  flutter: sdk: flutter
  cupertino_icons: ^1.0.8
  firebase_core: ^3.8.0
  firebase_auth: ^5.3.3
  google_sign_in: ^6.2.0    # v6 (v7 tiene bug con Credential Manager)
  dio: ^5.7.0
  flutter_secure_storage: ^9.2.2
  go_router: ^14.6.2
  flutter_riverpod: ^2.6.1

dev_dependencies:
  flutter_test: sdk: flutter
  flutter_lints: ^5.0.0
```

**Notas sobre versiones resueltas:**
- `firebase_core: 3.15.2` (resolvió más nueva)
- `firebase_auth: 5.7.0` (resolvió más nueva)
- `google_sign_in: 6.3.0` (API v6, estable)
- `dio: 5.11.1`
- `flutter_riverpod: 2.6.1`

### ⚠️ Configuración nativa Android (CRÍTICA para login con Google)

**1. `android/app/build.gradle.kts` — bloque `dependencies` obligatorio:**
```kotlin
dependencies {
    // Credential Manager (requerido por google_sign_in v7)
    implementation("androidx.credentials:credentials:1.3.0")
    implementation("androidx.credentials:credentials-play-services-auth:1.3.0")
    implementation("com.google.android.libraries.identity.googleid:googleid:1.1.1")
}
```
> Nota: aunque usamos v6, estas deps se dejaron por si se migra a v7 en el futuro. No molestan.

**2. `AndroidManifest.xml` — dos elementos obligatorios:**
```xml
<application
    android:networkSecurityConfig="@xml/network_security_config"
    ...>
    <!-- Deshabilitar Credential Manager para forzar el flujo clásico -->
    <meta-data
        android:name="com.google.android.gms.credentials.API_ENABLED"
        android:value="false" />
</application>
```

**3. `res/xml/network_security_config.xml`:**
```xml
<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
    <!-- Permitir HTTP sin cifrar SOLO para el server de desarrollo -->
    <domain-config cleartextTrafficPermitted="true">
        <domain includeSubdomains="true">104.129.59.151</domain>
    </domain-config>
</network-security-config>
```

**Razón:** Android 9+ bloquea HTTP en claro por defecto. Esta config permite HTTP **solo** al server de dev, manteniendo HTTPS como requerido para todo el resto.

### Arquitectura Flutter

**State management:** Riverpod 2.6.1 (StateNotifier + Provider).

**Navegación:** GoRouter 14.8.1 con auto-redirect según `authNotifierProvider`.

**HTTP:** Dio 5.11.1 con 2 interceptores:
1. **Request:** agrega `Authorization: Bearer <jwt>` si hay token guardado.
2. **Error:** mapea DioException a ApiException tipada.

**Storage:** `flutter_secure_storage` con `encryptedSharedPreferences: true` (Android Keystore).

**Config central:** `AppConfig` con `AppType` (client/admin) y `Environment` (dev/prod).

**API en dev:** `http://104.129.59.151` (HTTP, sin SSL — el server aún no tiene cert).
**API en prod:** `https://api.baqueanonatales.com` (cuando se haga el cutover DNS).

**AuthRepository — Google Sign-In v6:**
- `GoogleSignIn(scopes: [...], serverClientId: AppConfig.googleServerClientId)`
- `signIn()` → `GoogleSignInAccount`
- `googleUser.authentication` → `idToken` + `accessToken`
- **`serverClientId` es OBLIGATORIO** para obtener `idToken` en Android.

---

## 🔥 Firebase

### Proyecto Firebase
| Item | Valor |
|---|---|
| **Project ID** | `baqueano-natales-prod` |
| **Project Number** | `1072830106109` |
| **Plan** | Spark (gratuito) |

### Apps Android registradas
| Package | Rol | Client ID (Android) |
|---|---|---|
| `cl.baqueanonatales` | Cliente | `1072830106109-rb18p4oksc8607kr9c80i6mv92112kf5` (SHA-1 viejo) |
| `cl.baqueanonatales` | Cliente | `1072830106109-eh5i191lkg7d6185fr45c1difjvsqj66` (SHA-1 nuevo) |
| `cl.baqueanonatales.admin` | Admin | `1072830106109-0dao16e11pjkg0pnrnejpn3abumenfhv` (SHA-1 viejo) |

**Web Client ID (para serverClientId):**
```
1072830106109-c1b5cktisbj3khu8s9jmf7crn8ni0dh7.apps.googleusercontent.com
```

### ⚠️ Huellas SHA (CAMBIARON el 2026-10-08)

**SHA-1 de debug (ACTUAL):**
```
6E:0B:71:E0:63:01:E8:F7:CF:0E:3D:BC:1F:29:77:C8:D6:BE:63:3D
```

**SHA-256 de debug (ACTUAL):**
```
B2:A9:81:11:D4:55:81:B1:E8:5A:15:E7:6D:C1:5F:9E:20:0A:FE:72:FD:C5:EB:33:25:6E:97:82:B2:20:7C:BE
```

**SHA-1 viejo (ya no válido, pero registrado en Firebase):**
```
5C:1E:05:A3:10:92:65:4B:C7:7C:85:60:D7:F2:FB:6B:33:E0:B9:F5
```

**✅ Actualización 2026-10-08:** La app **`cl.baqueanonatales.admin`** ya tiene el SHA-1 nuevo registrado en Firebase. Se generó un client_id nuevo (`1072830106109-nv8q2jjt7kateq7cmqesg383entpu2sb`) que ya está en el `google-services.json` del repo.

**Nota:** El `debug.keystore` cambió (probablemente por reinstalación de Android Studio o cambio de PC). El SHA-1 viejo está en el doc antiguo y **ya no aplica**.

### Firebase Console
- URL: `https://console.firebase.google.com/project/baqueano-natales-prod`
- Authentication → Google habilitado
- OAuth consent screen: configurado (External, "Baqueano Natales")

### Service Account (backend)
- **Path en server:** `/home/deploy/baqueano-natales/backend/secrets/firebase-service-account.json`
- **Client email:** `firebase-adminsdk-fbsvc@baqueano-natales-prod.iam.gserviceaccount.com`
- **Mount en Docker:** `/app/secrets/firebase-service-account.json:ro`

---

## 🌐 Dominios y DNS

### Cloudflare
**Nameservers:**
- `april.ns.cloudflare.com`
- `simon.ns.cloudflare.com`

**Registros DNS actuales:**
| Dominio | Tipo | Apunta a | Estado |
|---|---|---|---|
| `api.baqueanonatales.com` | A | `161.118.240.229` (server viejo) | ⏳ Pendiente migrar a `104.129.59.151` |
| `baqueanonatales.com` | A | Vercel (`76.76.21.21`) | ✅ |
| `www.baqueanonatales.com` | CNAME | Vercel | ✅ |

**Estado:** el DNS de `api.baqueanonatales.com` **aún apunta al server viejo**. El cutover se hará cuando la migración esté validada.

### Vercel
- **Team:** `studio-digital-360`
- **Proyecto:** `baqueano-natales-web` (Astro)
- **URL producción:** `https://www.baqueanonatales.com`
- **Estado:** activo, sin tocar durante la migración

---

## 🔧 Fases del proyecto

### ✅ Fase 1 — Infraestructura (completada)
- Server nuevo provisionado y hardened
- Docker + Compose
- Backend FastAPI + Postgres + Nginx
- Healthchecks, logs JSON
- Documentación inicial (`docs/`)

### ✅ Fase 2 — Auth con Google (completada)
- Firebase Admin SDK integrado
- Endpoint `POST /api/v1/auth/google`
- Verificación de tokens
- JWT propio con roles
- Middleware `get_current_user` + `require_admin`

### ✅ Fase 3.1 — Módulo usuarios (completada)
- Modelo `Usuario` + migración
- CRUD de perfil
- Avatares con `LocalAvatarStorage` (interfaz ABC migrable a S3/Firebase)
- Nginx sirviendo `/media/` con caché 30d

### ✅ Fase 3.2 — Módulo admin (completada)
- 7 endpoints de gestión
- Filtros, paginación, validaciones
- Auto-admin por email (`ADMIN_EMAILS` en `.env`)
- Script de seed
- Fix crítico: `values_callable` en ENUM RolUsuario

### ✅ Fase 3.3 — Flutter base + login con Google (COMPLETADA 2026-10-08)
- Proyecto Flutter con estructura feature-first
- Flavors `client` (verde) + `admin` (morado)
- Router GoRouter con auto-redirect
- Splash + Login + Home
- **Login con Google funcional end-to-end** (Google → Firebase → Backend → JWT → Home)
- **Persistencia de sesión funcional** (sobrevive al cierre de la app)
- JWT guardado en secure storage
- Migración `google_sign_in` v7 → v6
- Configuración nativa Android completa (Credential Manager off, network security config)
- HTTP en dev (SSL pendiente para Fase 6)

### ✅ Fase 3.4 — Commit del código Flutter (COMPLETADA 2026-10-08)
- Todo el código Flutter commiteado y pusheado
- `CONTEXTO_PROYECTO.md` commiteado
- Fix del login commiteado

### ✅ Fase 3.5 — App admin con login (COMPLETADA 2026-10-08)
- ✅ SHA-1 nuevo registrado en `cl.baqueanonatales.admin` en Firebase Console
- ✅ `google-services.json` actualizado y commiteado
- ✅ Login con Google funcional end-to-end en flavor admin
- ✅ Home admin con tema morado + badge ADMIN
- ✅ Misma arquitectura que client (comparte `home_screen.dart` por ahora)

### ⏳ Fase 3.6 — Features core (pendiente)
- Mapa en vivo (Google Maps + WebSocket)
- Delivery (flujo de pedidos)
- Carta QR (menús interactivos)
- Recompensas (puntos por compras)

### ⏳ Fase 4 — CI/CD con GitHub Actions (pendiente)
- Tests en cada push
- Build APK automático
- Deploy backend automático vía SSH

### ⏳ Fase 5 — Play Store (pendiente)
- Crear keystore nuevo
- Activar Play App Signing
- Subir AAB a Play Console
- Completar metadata

### ⏳ Fase 6 — Cutover DNS + SSL (pendiente)
- Bajar TTL en Cloudflare
- Cambiar A record de `api.baqueanonatales.com` a `104.129.59.151`
- **Emitir certificado Let's Encrypt en el server nuevo**
- **Cambiar `AppConfig.dev` de `http://` a `https://`** (o dejar que prod lo use)
- Verificar HTTPS

### ⏳ Fase 7 — Decommission server viejo (pendiente)
- Apagar server viejo después de 1 semana sin incidentes
- Archivar repos viejos

---

## 🚨 Secretos expuestos (pendientes rotar)

**Durante el desarrollo, quedaron expuestos en chats/logs:**

| Secreto | Estado | Acción pendiente |
|---|---|---|
| `SECRET_KEY` (JWT) | ⚠️ Expuesto | Rotar en `.env` del server nuevo |
| `BOOSTR_API_KEY` | ⚠️ Expuesto | Regenerar desde Boostr |
| `RUTIFICADOR_API_KEY` | ⚠️ Expuesto | Regenerar desde Rutificador |
| `DIDIT_API_KEY` + `DIDIT_WEBHOOK_SECRET` | ⚠️ Expuesto | Regenerar en Didit |
| `RNSTP_API_KEY` | ⚠️ Expuesto | Regenerar |
| `FACEBOOK_PAGE_ACCESS_TOKEN` (x2) | ⚠️ Expuesto | Revocar en Meta + regenerar |
| `FACEBOOK_TOKEN_KEY` | ⚠️ Expuesto | Rotar |
| `GOOGLE_CLIENT_SECRET` | ⚠️ Expuesto | Regenerar en Google Cloud |
| `VERCEL_DEPLOY_HOOK_URL` | ⚠️ Expuesto | Regenerar en Vercel |
| `CLAVE_PRUEBAS`, `CLAVE_TAREAS` | ⚠️ Expuesto | Cambiar |
| Frase GPG de backups | 🚨 **MÁS CRÍTICO** | Rotar YA |
| GitHub PAT viejo | ⚠️ Expuesto | Revocar en GitHub |
| DuckDNS token | ⚠️ Expuesto | Descartado (no se usa DuckDNS) |
| Facebook token en `/root/main.py` del server nuevo | ⚠️ Expuesto | Revocar |

**⚠️ Rotación pendiente completa.** No se ha hecho todavía.

---

## 🗂️ Configuración crítica del server nuevo

### `docker-compose.yml`
3 servicios: `db`, `backend`, `nginx`.

**Volúmenes:**
- `postgres_data` — persistencia de DB
- `media_data` — avatares subidos
- `nginx_cache` — caché de Nginx

**Mounts del backend:**
- `./backend/app:/app/app` — hot reload en dev
- `./backend/secrets:/app/secrets:ro` — service account (read-only)
- `media_data:/app/media` — avatares

### `.env` (backend)
Variables clave:
```
ENVIRONMENT=production
DEBUG=false
POSTGRES_USER=baqueano_user
POSTGRES_PASSWORD=<ROTAR>
POSTGRES_DB=baqueano_natales
DATABASE_URL=postgresql://...
SECRET_KEY=<ROTAR>
FIREBASE_PROJECT_ID=baqueano-natales-prod
FIREBASE_SERVICE_ACCOUNT_PATH=/app/secrets/firebase-service-account.json
ADMIN_EMAILS=victorneyraars@gmail.com
PUBLIC_API_URL=https://api.baqueanonatales.com
AVATAR_STORAGE_PATH=/app/media/avatars
MAX_AVATAR_SIZE_BYTES=5242880
```

### Nginx
- Proxy reverso a `backend:8000`
- Rate limiting: 60/min general, 5/min en `/api/v1/auth/`
- Security headers (X-Content-Type-Options, X-Frame-Options, Referrer-Policy)
- Sirve `/media/` con caché 30d
- `server_tokens off`
- Upstream con `keepalive 32`

---

## 🛠️ Comandos rápidos

### Correr app Flutter (client)
```powershell
cd D:\dev\baqueano-natales\flutter
flutter run --flavor client -t lib/main_client.dart -d emulator-5554
```

### Correr app Flutter (admin)
```powershell
cd D:\dev\baqueano-natales\flutter
flutter run --flavor admin -t lib/main_admin.dart -d emulator-5554
```

### Rebuild limpio (cuando hay cambios nativos)
```powershell
cd D:\dev\baqueano-natales\flutter
flutter clean
flutter pub get
flutter run --flavor client -t lib/main_client.dart -d emulator-5554
```

### Matar procesos Flutter bloqueados
```powershell
Get-Process | Where-Object { $_.ProcessName -match "flutter|dart" } | Stop-Process -Force -ErrorAction SilentlyContinue
```

### Ver SHA-1 debug actual (¡cambió!)
```powershell
cd D:\dev\baqueano-natales\flutter\android
./gradlew signingReport
```

### Emulador Android 14 (recomendado)
```powershell
& "D:\Android\Sdk\emulator\emulator.exe" -avd Pixel6_API34 -no-snapshot-load -gpu swiftshader_indirect
```powershell
Get-Process | Where-Object { $_.ProcessName -match "emulator|qemu|adb" } | Stop-Process -Force -ErrorAction SilentlyContinue
& "D:\Android\Sdk\emulator\emulator.exe" -avd Pixel6_API37 -no-snapshot-load -wipe-data -gpu swiftshader_indirect
```

### Ver logs del backend (server)
```bash
ssh deploy@104.129.59.151 "cd baqueano-natales && docker compose logs --tail=50 backend"
```

### Rebuild backend (server)
```bash
ssh deploy@104.129.59.151 "cd baqueano-natales && docker compose build backend && docker compose up -d"
```

### Query DB (server)
```bash
ssh deploy@104.129.59.151 "cd baqueano-natales && docker compose exec -T db psql -U baqueano_user -d baqueano_natales -c 'SELECT id, email, rol FROM usuarios;'"
```

### Verificar salud del backend (HTTP dev)
```bash
curl http://104.129.59.151/health
```

---

## 📚 Documentación existente

**En el repo `baqueano-natales`:**

| Archivo | Contenido |
|---|---|
| `README.md` | Intro + estructura + stack |
| `docs/ARCHITECTURE.md` | Arquitectura detallada |
| `docs/DEPLOYMENT.md` | Guía de deploy paso a paso |
| `docs/DEVELOPMENT.md` | Convenciones + setup dev |
| `docs/DECISIONS/0001-docker-compose.md` | ADR inicial |
| `CONTEXTO_PROYECTO.md` | Este archivo |

---

## 🎯 Estado exacto al retomar

**Lo que está funcionando:**
- Server nuevo con backend corriendo en `104.129.59.151` (HTTP)
- Postgres 16 con tabla `usuarios`
- 14 endpoints activos
- 3 módulos backend completos
- App Flutter client con **login funcional end-to-end**
- App Flutter client con **persistencia de sesión funcional**
- Home con datos reales (nombre, email, rol ADMIN)
- Flujo verificado: Google Sign-In → Firebase → backend → JWT → Home

**Lo que queda pendiente inmediato:**
1. **Frontend Flutter del módulo comercios — parte 2** (Fase 3.6.0.c+d)
   - Pantallas dueño: mis comercios, crear/editar, horarios, enviar a revisión
   - Pantallas admin: verificar/rechazar/suspender, CRUD categorías
   - Diferenciar Home admin del Home client
   - (La parte cliente — lista + detalle + filtros — ya está ✅)
2. 🚨 **Rotar secretos expuestos** (ver sección "Secretos expuestos") — CRÍTICO
   - Prioridad alta: `SECRET_KEY` (JWT), frase GPG de backups, GitHub PAT viejo
   - **Nuevo:** `POSTGRES_PASSWORD` expuesto en chat 2026-10-08
3. **Features core restantes**: mapa, delivery, carta QR, recompensas
4. **Diferenciar Home admin** del Home client (ahora comparten `home_screen.dart`)

**Lo que falta por construir:**
- Features core (mapa, delivery, carta QR, recompensas) — Fase 3.6
- CI/CD (GitHub Actions) — Fase 4
- Play Store setup — Fase 5
- DNS cutover + SSL — Fase 6
- Decommission server viejo — Fase 7

---

## 🚀 Cómo retomar en un chat nuevo

**Al inicio del nuevo chat, pegar este documento completo.**

Luego, los primeros comandos a correr son:

1. **Verificar estado del repo:**
   ```powershell
   cd D:\dev\baqueano-natales
   git status
   git log --oneline -5
   ```

2. **Verificar server:**
   ```bash
   curl http://104.129.59.151/health
   ```

3. **Verificar emulador (si aplica):**
   ```powershell
   cd D:\dev\baqueano-natales\flutter
   flutter devices
   ```

**Con esto, se retoma el trabajo exactamente donde quedó.**

---

## 📝 Convenciones de código

**Backend (Python):**
- Estructura por módulos de dominio
- Async/await en todo
- Pydantic para validación
- SQLAlchemy 2.0 style (Mapped, mapped_column)
- Logs JSON estructurados

**Flutter (Dart):**
- Feature-first
- Riverpod para state
- GoRouter para navegación
- Nombres: `snake_case` archivos, `PascalCase` clases
- Lints: `flutter_lints: ^5.0.0`

**Commits Git:**
- `feat:` nueva feature
- `fix:` corrección
- `docs:` documentación
- `refactor:` sin cambio funcional
- `test:` tests
- `chore:` tareas varias

**Regla de oro de secretos:**
- `.env` → NUNCA al repo
- `secrets/` → NUNCA al repo
- `*.jks`, `*.keystore` → NUNCA al repo
- `google-services.json` → **SÍ va al repo** (es config pública)

---

**Fin del documento de contexto.**