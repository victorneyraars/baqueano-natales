# ADR 0001 — Usar Docker Compose para orquestación

- **Estado:** Aceptada
- **Fecha:** 2026-10-06
- **Decisores:** Victor Neyra

## Contexto

El proyecto Baqueano Natales necesita:

- **Portabilidad:** poder mover el stack entre servidores (dev, staging, prod) sin reescribir config.
- **Reproducibilidad:** el entorno de desarrollo debe ser idéntico al de producción.
- **Escalabilidad:** al menos 3 servicios (backend, DB, reverse proxy) que deben comunicarse.
- **Facilidad de migración:** posibilidad de pasar a Kubernetes sin reescribir la aplicación.
- **Bajo overhead operativo:** un equipo pequeño (1-2 personas) no puede mantener un Kubernetes desde el día uno.

## Decisión

**Usar Docker Compose como orquestador principal** para el stack, con:

- Un `docker-compose.yml` base compartido entre entornos.
- Overrides por entorno (`docker-compose.dev.yml`, `docker-compose.prod.yml`).
- Redes internas aisladas.
- Volúmenes persistentes para la base de datos.
- Healthchecks en cada servicio.

## Alternativas consideradas

### 1. systemd (procesos nativos)

**Ventajas:**
- Más ligero (sin overhead de Docker).
- Sin dependencias externas.
- Estándar de Linux.

**Desventajas:**
- No portable: cambiar de Ubuntu a Debian a Alpine implica reconfigurar todo.
- Diferencias entre dev (Mac/Windows) y prod (Linux).
- Sin aislamiento entre servicios.
- Migración a Kubernetes sería desde cero.

### 2. Kubernetes (k8s)

**Ventajas:**
- Orquestación robusta.
- Escalado automático.
- Estándar de la industria para grandes despliegues.

**Desventajas:**
- Overhead enorme para 3 servicios.
- Curva de aprendizaje alta.
- Necesita infraestructura adicional (control plane, ingress, storage).
- Overkill para un equipo de 1-2 personas.

### 3. Podman + systemd

**Ventajas:**
- Sin daemon central.
- Compatible con imágenes OCI.
- Más seguro que Docker (rootless).

**Desventajas:**
- Menos maduro que Docker Compose.
- Comunidad más pequeña.
- Menos herramientas de terceros.

## Consecuencias

### Positivas

- **Portabilidad total:** `docker compose up` funciona igual en cualquier Linux.
- **Reproducibilidad:** dev y prod usan la misma imagen.
- **Migración futura:** los Dockerfiles son reutilizables si pasamos a Kubernetes.
- **Aislamiento:** cada servicio corre en su propio contenedor.
- **Healthchecks:** Docker reinicia automáticamente servicios caídos.
- **Comunidad:** inmensa cantidad de ejemplos, herramientas, tutoriales.

### Negativas

- **Overhead de Docker:** ~100-200 MB de RAM extra por el daemon.
- **Curva de aprendizaje:** el equipo necesita saber Docker.
- **Necesita limpieza periódica:** `docker system prune` para evitar acumulación de imágenes viejas.

### Neutras

- **Persistencia:** volúmenes de Docker (o bind mounts).
- **Redes:** red bridge interna (`baqueano_net`).

## Implementación

El stack actual:

```yaml
services:
  db:        # PostgreSQL 16
  backend:   # FastAPI (Python 3.12)
  nginx:     # Reverse proxy
```

Para desarrollo, agregar `docker-compose.dev.yml` con hot reload.
Para producción, `docker-compose.prod.yml` con recursos limitados y logs rotados.

## Referencias

- [Docker Compose docs](https://docs.docker.com/compose/)
- [The Twelve-Factor App](https://12factor.net/)
- [ADR GitHub organization](https://adr.github.io/)
