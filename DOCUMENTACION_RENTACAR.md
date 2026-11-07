# Documentacion Tecnica — Rent a Car Vasquez

Ultima actualizacion: 2026-11-07
Estado: Motor operativo al 100%, pendientes solo comerciales

## 1. Arquitectura

### Stack
- Frontend: Next.js 16.4.3 + React 19 + Tailwind CSS 4 (App Router, output standalone)
- Backend: FastAPI + Python 3.12 + SQLAlchemy async + Pydantic
- Base de datos: PostgreSQL 16 (asyncpg)
- Infraestructura: Docker Compose (Nginx reverse proxy + Cloudflare)
- Almacenamiento: Cloudflare R2
- Notificaciones: SMTP + WhatsApp Business API

### Contenedores Docker
- baqueano_backend_prod — FastAPI principal
- baqueano_backend_dev — Backend desarrollo
- rentacarvasquez_web — Next.js web publica + admin
- baqueano_db — PostgreSQL
- baqueano_nginx — Reverse proxy

### URLs Produccion
- Web: https://rentacarvasquez.com
- Panel admin: https://rentacarvasquez.com/admin
- API prod: https://api.baqueanonatales.com
- API dev: https://api-dev.baqueanonatales.com

### Comandos de Deploy
Backend:
cd ~/baqueano-natales && docker compose -f docker-compose.yml -f docker-compose.prod.yml build backend-prod && docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d --force-recreate backend-prod

Frontend:
cd ~/rentacarvasquez-web && docker compose -f docker-compose.rentacar.yml build && docker compose -f docker-compose.rentacar.yml up -d --force-recreate

## 2. Base de Datos

### IDs Clave
- Prestador Vasquez: c9aa7037-a4de-4217-b6dc-fa5893062657
- Usuario Victor (admin): 8e43d7ca-7c95-4bc3-9301-9dfd569bda88
- Usuario Vasquez: 048cfa35-1aab-41b5-b1e7-6cf535a05c03
- DB: baqueano_natales_prod / usuario baqueano_prod_user

### Tablas del Modulo Rent a Car

rentacar_vehiculos: Flota. Columnas: id, prestador_id, patente, marca, modelo, anio, categoria, precio_dia (NUMERIC 10,2), disponible, imagen_url.

rentacar_reservas: Reservas. Columnas: id, vehiculo_id, cliente_id, nombre_cliente, email_cliente, telefono_cliente, fecha_inicio, fecha_fin, metodo_pago, precio_total, estado (pendiente/confirmada/en_curso/completada/cancelada), email_verificado, otp_code, gestionado_por, gestionado_at.

rentacar_bloqueos: Bloqueos de calendario. Columnas: id, vehiculo_id, reserva_id, fecha_inicio, fecha_fin, tipo (reserva/mantenimiento/manual).

rentacar_inspecciones: Inspecciones entrega/recepcion. Columnas: id, reserva_id, tipo (entrega/recepcion), kilometraje, nivel_combustible, fotos (JSONB, array Base64), firma_cliente (TEXT Base64), created_at, updated_at, firmado_at.

documentos_firma: Documentos firmables genericos. Columnas: id, token, tenant_id, tipo, payload (JSONB), estado, firmado_at, ip_firma, firma_base64.

## 3. Modulos Implementados

### 3.1 Reservas y Flujo OTP

Flujo completo:
1. Cliente reserva en web → reserva pendiente + OTP por email
2. Cliente ingresa OTP → email_verificado=true + notifica admin
3. Admin aprueba → reserva confirmada + email final + WhatsApp
4. Admin Check-out → reserva en_curso + inspeccion entrega
5. Admin Check-in → reserva completada + inspeccion recepcion

Endpoints publicos:
- POST /api/v1/public/rentacar/reservas
- POST /api/v1/public/rentacar/reservas/{id}/verificar-email
- POST /api/v1/public/rentacar/reservas/{id}/reenviar-otp
- GET /api/v1/public/rentacar/reservas/{id}/accion?token=...
- POST /api/v1/public/rentacar/reservas/{id}/accion?token=...

Endpoints propietario (JWT):
- GET /api/v1/mis-vehiculos-rentacar/reservas
- GET /api/v1/mis-vehiculos-rentacar/reservas/{id}
- PATCH /api/v1/mis-vehiculos-rentacar/reservas/{id}/estado
- PATCH /api/v1/mis-vehiculos-rentacar/reservas/{id}
- DELETE /api/v1/mis-vehiculos-rentacar/reservas/{id}
- POST /api/v1/mis-vehiculos-rentacar/reservas (crear manual)
- POST /api/v1/mis-vehiculos-rentacar/reservas/{id}/inspeccion
- GET /api/v1/mis-vehiculos-rentacar/reservas/{id}/inspecciones

### 3.2 Contratos Digitales (Firma Electronica)

Backend: app/modules/documents/
- models.py — DocumentoFirma
- services.py — Generacion PDF con ReportLab + firma incrustada
- routes.py — Endpoints /api/v1/documents/*

Endpoints:
- POST /api/v1/documents/crear
- GET /api/v1/documents/{token}/pdf
- GET /api/v1/documents/{token}/status
- POST /api/v1/documents/{token}/firmar

Frontend:
- components/core/SignaturePad.tsx (canvas firma, Apple Pencil compatible)
- app/firmar/[token]/page.tsx (pagina publica de firma)
- components/admin/TarjetaInspecciones.tsx (vista de inspecciones)

Generacion del contrato: boton "Generar Contrato de Arriendo" en detalle de reserva del panel admin.

### 3.3 Inspeccion Vehicular (Check-out / Check-in)

Wizard de 11 pasos guiados:
1. Frente
2. Parte Trasera
3. Lateral Izquierdo
4. Lateral Derecho
5. Rueda Delantera Izquierda
6. Rueda Delantera Derecha
7. Rueda Trasera Izquierda
8. Rueda Trasera Derecha
9. Parabrisas
10. Interior
11. Tablero (Km + Combustible)
12. Firma del cliente

Cada paso incluye:
- SVG esquematico (componente FotoReferencia.tsx)
- Instrucciones de encuadre
- Razon de negocio de cada foto
- Captura con capture="environment" (camara trasera)

Compresion de fotos: canvas HTML5, MAX_WIDTH=1000px, calidad JPEG 0.5 (~80-150 KB por foto).

Componentes:
- components/admin/InspeccionModal.tsx (wizard 11 pasos)
- components/admin/FotoReferencia.tsx (SVGs referenciales)
- components/admin/TarjetaInspecciones.tsx (visualizacion)
- components/admin/CompararInspecciones.tsx (comparador entrega vs devolucion)
- components/core/SignaturePad.tsx (canvas firma)

Visualizacion de galeria:
- Zoom con react-zoom-pan-pinch
- Pinch-to-zoom centrado en dedos
- Pan cuando zoomeada
- Double-tap para zoom en punto
- Swipe cuando NO zoomeada (cambia angulo)
- Descarga individual
- Modo inmersivo (toca para ocultar barras)
- Comparador con toggle Entrega/Devolucion

Bloqueo de scroll del body: tecnica position:fixed con preservacion de scrollY cuando cualquier lightbox esta abierto.

### 3.4 Calendario y Disponibilidad

Componente: components/admin/CalendarioTimeline.tsx
- Vista Timeline 14 dias
- Filas = vehiculos (con thumbnail)
- Columnas = dias
- Colores: verde (confirmada), amarillo (pendiente), gris (libre)
- Navegacion: 7 dias atras, Hoy, 7 dias adelante
- Click celda libre → abre ReservaModal (crear)
- Click celda ocupada → abre ReservaModal (editar)

Componente: components/admin/ReservaModal.tsx
- Crear/editar reservas manuales
- Calendario visual con dias bloqueados en rojo
- Desglose financiero con Neto + IVA + Ajustes
- Plantillas de ajuste (Early Bird, Semanal, Aeropuerto, etc.)
- Validacion de email
- No procesa pagos

Componente: components/HeroSearch.tsx (portada publica)
- Modal centrado para seleccion de fechas
- Redirige a /vehiculos?inicio=...&fin=...

### 3.5 Notificaciones (Emails)

Modulo: app/modules/notificaciones/reservas.py

Funciones:
- notificar_otp_cliente
- notificar_email_verificado_cliente
- notificar_nueva_reserva_prestador
- notificar_reserva_confirmada_cliente
- notificar_reserva_cancelada_cliente
- notificar_accion_colaboradores
- notificar_contrato_cliente

Flujo correcto implementado:
- Etapa 1 (crear reserva): solo OTP al cliente
- Etapa 2 (verificar OTP): email cliente "verificado" + alerta admin
- Etapa 3 (admin aprueba): email confirmacion al cliente

## 4. Panel de Administracion

Rutas:
- /admin/dashboard — Lista de reservas
- /admin/dashboard/calendario — Timeline 14 dias
- /admin/dashboard/[id] — Detalle con tarjeta inspecciones y botones:
  - Generar Contrato de Arriendo (azul)
  - Check-out (amarillo)
  - Check-in (morado)
  - Eliminar Reserva (rojo)
- /admin/dashboard/colaboradores — Gestion equipo
- /admin/dashboard/auditoria — Log de acciones

Autenticacion:
- Google Sign-In con Firebase
- JWT en localStorage con clave "jwt"
- authFetch en lib/admin-api.ts inyecta token automaticamente
- Superadmin: Victor con es_admin helper

## 5. Web Publica

Rutas:
- / — Portada con HeroSearch
- /vehiculos — Lista flota (filtro fechas)
- /vehiculos/[id] — Detalle + formulario reserva
- /puerto-natales — Landing geolocalizada
- /torres-del-paine — Landing geolocalizada
- /aeropuerto-pnt — Landing geolocalizada
- /contacto — Contacto
- /terminos — Terminos y Condiciones
- /privacidad — Politica de Privacidad
- /firmar/[token] — Pagina publica de firma

SEO:
- app/sitemap.ts — Sitemap dinamico
- app/robots.ts — Robots.txt con bloqueo /admin
- JSON-LD Schema.org en lib/seo.ts y lib/json-ld.ts
- Google Search Console verificado por DNS
- GA4: G-TZSNB9G3ZB
- GTM: GTM-MWL63KTV

## 6. Testing y Validacion

Pruebas manuales recomendadas:
1. Reserva publica end-to-end: web → OTP → verificacion → aprobacion admin
2. Contrato digital: generar desde admin → email → firmar en movil
3. Check-out: wizard 11 pasos → fotos → firma → estado en_curso
4. Check-in: wizard 11 pasos → estado completada
5. Comparador: fotos lado a lado + km recorridos
6. Calendario: crear reserva manual → verificar en calendario
7. Edicion: modificar fechas de reserva existente
8. Eliminacion: eliminar reserva → liberar calendario

Verificacion en DB:
docker exec baqueano_db psql -U baqueano_prod_user -d baqueano_natales_prod -c "SELECT tipo, kilometraje, JSONB_ARRAY_LENGTH(fotos) as fotos, LENGTH(firma_cliente) as firma_len FROM rentacar_inspecciones ORDER BY created_at DESC LIMIT 5;"

docker exec baqueano_db psql -U baqueano_prod_user -d baqueano_natales_prod -c "SELECT token, estado, firmado_at FROM documentos_firma ORDER BY created_at DESC LIMIT 5;"

docker exec baqueano_db psql -U baqueano_prod_user -d baqueano_natales_prod -c "SELECT nombre_cliente, estado, precio_total FROM rentacar_reservas ORDER BY created_at DESC LIMIT 5;"

## 7. Pendientes Comerciales (no tecnicos)

### 7.1 SERNATUR (Sello R)
- Estado: Iniciado, pendiente de completar
- Portal: https://registro.sernatur.cl/
- Documentos necesarios: RUT empresa, escritura, patente comercial, carpeta tributaria, cedula representante legal
- Beneficio: enlace .gob.cl en el perfil (SEO), confianza oficial

### 7.2 Directorios Rapidos
- Apple Business Connect: https://businessconnect.apple.com
- Bing Places: https://www.bingplaces.com
- InterPatagonia: https://www.interpatagonia.com
- TripAdvisor: crear listing como "Actividad"

### 7.3 Estrategia de Resenas
- Mensaje WhatsApp post-devolucion (disenado, pendiente implementar envio automatico)
- QR fisico para mostrador Miraflores 708
- Objetivo: 5-10 resenas de 5 estrellas en Google Business Profile

### 7.4 Mejoras Futuras (opcionales)
- App Flutter con flujo de inspeccion nativo
- Envio automatico WhatsApp desde backend (API WhatsApp Business)
- Notas por foto individual (ej. "Rayon en puerta trasera, ~5cm")
- Exportacion de inspecciones a PDF
- Panel de colaboradores con permisos granulares

## 8. Credenciales y Secrets

IMPORTANTE: Los siguientes datos NO deben estar en el codigo fuente. Se accede via variables de entorno del servidor (.env.prod):

- GTM Container ID: GTM-MWL63KTV
- GA4 Property ID: 562461404
- GA4 Measurement ID: G-TZSNB9G3ZB
- Service Account GA4: rentacar-analytics@baqueano-natales-prod.iam.gserviceaccount.com
- JSON GA4: /home/deploy/baqueano-natales/backend/secrets/ga4-service-account.json
- Cloudflare Zone ID: 3dd2b73b92db1bdfec1ba7a7fc6dfd6f
- Cloudflare API: en ~/baqueano-natales/.env.prod

## 9. Comandos Utiles

Ver logs:
docker logs baqueano_backend_prod --tail 50 -f
docker logs rentacarvasquez_web --tail 50 -f
docker logs baqueano_nginx --tail 50 -f

Reiniciar servicios:
docker compose -f docker-compose.yml -f docker-compose.prod.yml restart backend-prod
cd ~/baqueano-natales && docker compose restart

Verificar salud:
curl -s https://api.baqueanonatales.com/health
curl -sI https://rentacarvasquez.com/ | head -1

Limpiar cache Cloudflare (si es necesario):
curl -X POST "https://api.cloudflare.com/client/v4/zones/3dd2b73b92db1bdfec1ba7a7fc6dfd6f/purge_cache" -H "X-Auth-Email: $CLOUDFLARE_API_EMAIL" -H "X-Auth-Key: $CLOUDFLARE_API_KEY" -H "Content-Type: application/json" -d '{"purge_everything":true}'

## 10. Convenciones de Codigo

Ver CONVENCIONES_CODIGO.md para el estandar completo.

Este documento debe actualizarse cada vez que se agregue, modifique o elimine un modulo del ecosistema.
