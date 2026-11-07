# Flujo de autenticación — Baqueano Natales (app cliente+prestador)

**Última actualización:** 2026-11-07
**Autores:** fix del bug "logout requiere doble intento"
**Estado:** implementado y verificado en v1.0.20+

---

## 1. Componentes

| Archivo | Rol |
|---|---|
| lib/features/auth/data/auth_repository.dart | Llamadas externas (Firebase, Google, backend, storage). Sin estado. |
| lib/features/auth/data/auth_notifier.dart | Estado global (AuthState). Notifica cambios a la UI y al router. |
| lib/features/auth/presentation/splash_screen.dart | Entry screen. Dispara restoreSession() solo en arranque inicial. |
| lib/features/auth/presentation/login_screen.dart | Botón "Continuar con Google". |
| lib/shared/router/app_router.dart | GoRouter con refreshListenable que escucha al notifier. |
| lib/core/network/dio_client.dart | Interceptor que inyecta Authorization: Bearer <JWT> en cada request. |
| lib/core/storage/secure_storage.dart | Wrapper sobre flutter_secure_storage (Keystore/Keychain). |

---

## 2. Diagrama de estados

                    ┌─────────────┐
       app start ──▶│   unknown   │
                    └──────┬──────┘
                           │ SplashScreen.initState
                           │ (guard: solo si unknown)
                           ▼
                    ┌─────────────┐
                    │   loading   │◀──── restoreSession() ──┐
                    └──────┬──────┘                          │
                           │                                 │
              ┌────────────┴────────────┐                    │
              │                         │                    │
     JWT válido                JWT inválido/ausente          │
              │                         │                    │
              ▼                         ▼                    │
    ┌──────────────────┐    ┌──────────────────────┐         │
    │  authenticated   │    │   unauthenticated    │         │
    └────┬────────┬────┘    └──────────┬───────────┘         │
         │        │                    │                     │
    logout    loginWithGoogle       manual                (no-op)
         │        │                    │                     │
         ▼        ▼                    ▼                     │
   ┌──────────┐   (vuelve a loading)                          │
   │loggingOut│                                               │
   └────┬─────┘                                               │
        │                                                     │
        │ _repository.logout() completa                       │
        │ try/finally garantiza unauthenticated               │
        ▼                                                     │
   ┌──────────────────────┐                                   │
   │   unauthenticated    │───────────────────────────────────┘
   └──────────────────────┘

**Regla clave:** loading es SOLO para restoreSession(). loggingOut es SOLO para logout(). Nunca se mezclan.

---

## 3. Flujo de login

1. Usuario en /login toca "Continuar con Google".
2. AuthNotifier.loginWithGoogle():
   - state = loading()
   - AuthRepository.loginWithGoogle():
     - GoogleSignIn.signIn() -> popup nativo
     - authentication -> idToken
     - FirebaseAuth.signInWithCredential() -> Firebase user
     - getIdToken() -> JWT de Firebase
     - POST /api/v1/auth/google -> JWT del backend
     - SecureStorage.saveAccessToken/UserId/Role()
   - state = authenticated(user)
3. _AuthChangeNotifier detecta cambio -> notifyListeners() -> GoRouter reevalúa redirect -> /home.
4. FCM token registrado async (_registrarFcmAsync).

**Errores:** cualquier ApiException -> state = unauthenticated(error: msg) -> snackbar en login.

---

## 4. Flujo de logout

1. Usuario en /home abre menú -> "Cerrar sesión".
2. HomeScreen._handleLogout():
   - showDialog de confirmación
   - Si confirma -> await notifier.logout()
3. AuthNotifier.logout():
   - Idempotencia: si state == loggingOut, return (evita doble ejecución).
   - state = loggingOut()
   - try { await _repository.logout(); } (ver sección 5)
   - finally { clearActiveMode(); state = unauthenticated(); }
4. _AuthChangeNotifier detecta cambio -> GoRouter reevalúa redirect:
   - loggingOut -> /login directo (sin pasar por splash)
   - unauthenticated -> /login (idempotente, ya está ahí)

---

## 5. AuthRepository.logout() — orden y por qué

1. Desregistrar FCM (best-effort)
   try { await _dio.delete('/api/v1/usuarios/me/fcm-token'); } catch (e) { log }

2. Firebase signOut (best-effort)
   try { await _firebaseAuth.signOut(); } catch (e) { log }

3. Google signOut (best-effort)
   try { await _googleSignIn.signOut(); } catch (e) { log }

4. Storage local (CRÍTICO, no atrapado)
   await SecureStorageService.clearAll();

**Por qué cada paso en su propio try/catch:**
Si Firebase falla (sin red, token inválido), no queremos que ese fallo impida el clearAll(). El usuario DEBE quedar deslogueado del dispositivo aunque los servicios externos no respondan.

**Por qué clearAll() NO se atrapa:**
Si el storage local falla, el token queda en Keystore y restoreSession() re-autenticaría al usuario en el próximo arranque. Es un fallo que el usuario debe ver (snackbar), no silenciar.

---

## 6. Race condition en logout (bug histórico, resuelto en v1.0.20+)

### Síntoma
El usuario tocaba "Cerrar sesión" una vez -> volvía al home por un instante -> tenía que tocar de nuevo.

### Causa raíz
1. logout() seteaba state = loading().
2. GoRouter redirigía a /splash.
3. SplashScreen.initState disparaba restoreSession() SIN GUARD.
4. restoreSession() leía el storage ANTES de que clearAll() corriera.
5. hasActiveSession() = true -> getCurrentUser() = 200 -> state = authenticated().
6. GoRouter volvía a /home.
7. Después, logout() seguía -> clearAll() -> state = unauthenticated().
8. Recién ahí /login.

### Fix
- Nuevo estado loggingOut separado de loading. El router va a /login directo, sin pasar por splash.
- Guard en SplashScreen.initState: solo dispara restoreSession() si state.status == unknown. Si estamos en loggingOut o unauthenticated, no hace nada.
- logout() con try/finally + idempotencia para doble click.

### Verificación
- Logout normal -> /login en <2s. Sin home intermedio.
- Doble click rápido -> segundo click es no-op.
- Logout sin red -> usuario en /login (best-effort) + snackbar de error si clearAll() falló.
- Logout durante restoreSession() (app recién abierta) -> esperar o guard de idempotencia.

---

## 7. Edge cases

### Token expirado (401)
- DioClient.onError con status == 401 lanza UnauthorizedException.
- restoreSession() catch -> await _repository.logout() -> state = unauthenticated().
- NO dispara snackbar: el usuario simplemente cae en /login.

### Logout sin red
- Firebase/Google signOut fallan rápido (timeout 15s en Dio, pero Google es nativo).
- clearAll() local no usa red -> funciona offline.
- Usuario en /login con sesión local borrada. Próximo login requiere red (obvio).

### App cerrada durante loggingOut
- Al reabrir, state = unknown -> SplashScreen dispara restoreSession().
- hasActiveSession() puede dar true o false según si clearAll() llegó a ejecutarse.
- Si true: token viejo -> getCurrentUser() puede dar 401 -> logout() interno -> unauthenticated.
- Si false: directo unauthenticated.
- Estado consistente en ambos casos.

### Firebase Auth sin red al reabrir
- _firebaseAuth.currentUser puede quedar cacheado localmente.
- restoreSession() chequea JWT del backend (no Firebase), así que si el JWT expiró o no existe, va a unauthenticated aunque Firebase diga que hay user.
- Es intencional: el backend es la fuente de verdad de la sesión.

---

## 8. Convenciones para futuras modificaciones

Al tocar este flujo, respetar:

1. loading es solo para restoreSession(). Si necesitás un estado intermedio para otra operación, agregá un enum nuevo (como loggingOut).
2. SplashScreen solo restaura si state == unknown. No tocar el guard sin leer la sección 6.
3. logout() siempre try/finally con state = unauthenticated() en el finally.
4. AuthRepository.logout() nunca propaga. Cada paso externo en su try/catch.
5. clearAll() es la operación crítica. Si falla, debe ser visible al usuario.
6. Agregar un test E2E cuando se agregue un nuevo estado al enum. Mínimo: logout -> login -> logout -> login, sin race.

---

## 9. Tests manuales (checklist)

- [ ] Login con Google (nueva cuenta) -> home -> logout -> login. Sin home intermedio.
- [ ] Logout offline (modo avión) -> /login, snackbar de error si aplica.
- [ ] Logout + doble click rápido -> una sola ejecución, /login en <2s.
- [ ] App reabierta después de logout -> /login directo (no home).
- [ ] Token expirado (esperar 1h) -> cualquier request 401 -> /login.
- [ ] Logout como prestador -> /login -> login como cliente -> home cliente (no taller).
