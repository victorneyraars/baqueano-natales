# Cheatsheet de Nombres Exactos

> Regla: Antes de escribir un import o referencia, verificar aca o hacer grep.

## Autenticacion
| Concepto | Nombre exacto |
|---|---|
| Request Google Login | GoogleLoginRequest |
| Funcion endpoint | login_google |
| Endpoint | POST /api/v1/auth/login-google |
| Dependencia user | CurrentUser |

## Turnos
- TurnoCreate, TurnoUpdate, TurnoResponse, TurnoListItemResponse

## Frontend Astro
- API_URL (src/config/api.ts), fetchPrestadorPorSlug(slug), Servicio (interface)

## Regla: Grep antes de escribir
Comando: grep -rn "class GoogleLogin" backend/

---
Mantenido por: Victor Neyra
