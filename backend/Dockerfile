# =========================================================
# Baqueano Natales - Backend FastAPI
# Multi-stage build con usuario no-root
# =========================================================

# ---------------------------------------------------------
# Stage 1: builder (compila dependencias)
# ---------------------------------------------------------
FROM python:3.12-slim AS builder

# Evitar que Python escriba .pyc y buffer de stdout
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

# Dependencias del sistema para compilar paquetes Python
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libpq-dev \
    libcairo2-dev \
    libpango1.0-dev \
    libgdk-pixbuf-2.0-dev \
    libffi-dev \
    shared-mime-info \
    && rm -rf /var/lib/apt/lists/*

# Instalar dependencias en un virtualenv aislado
WORKDIR /app
COPY requirements.txt .
RUN python -m venv /opt/venv && \
    /opt/venv/bin/pip install --upgrade pip && \
    /opt/venv/bin/pip install -r requirements.txt

# ---------------------------------------------------------
# Stage 2: runtime (imagen final liviana)
# ---------------------------------------------------------
FROM python:3.12-slim AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/opt/venv/bin:$PATH"

# Solo las libs runtime necesarias (no build-essential)
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 \
    curl \
    libcairo2 \
    libpango-1.0-0 \
    libpangoft2-1.0-0 \
    libgdk-pixbuf-2.0-0 \
    shared-mime-info \
    && rm -rf /var/lib/apt/lists/*

# Crear usuario no-root
RUN groupadd --gid 1000 appuser && \
    useradd --uid 1000 --gid appuser --shell /bin/bash --create-home appuser

# Copiar el virtualenv del stage anterior
COPY --from=builder /opt/venv /opt/venv

WORKDIR /app

# Copiar el código de la app (con ownership correcto)
COPY --chown=appuser:appuser . .

# Cambiar a usuario no-root
USER appuser

# Exponer el puerto interno (NO se publica al host)
EXPOSE 8000

# Healthcheck integrado
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Comando de arranque
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--no-access-log"]
