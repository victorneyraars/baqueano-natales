/// Excepciones personalizadas para manejo de errores de API.
///
/// Se lanzan desde el DioClient y se manejan en los providers/UI
/// para mostrar mensajes apropiados al usuario.
library;

/// Excepción base.
abstract class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Error de red (sin conexión, timeout, DNS).
class NetworkException extends ApiException {
  const NetworkException([
    super.message = 'Sin conexión a internet. Verificá tu red.',
  ]);
}

/// Error de timeout.
class TimeoutException extends ApiException {
  const TimeoutException([
    super.message = 'La conexión tardó demasiado. Intentá de nuevo.',
  ]);
}

/// Error 400 - Bad Request.
class BadRequestException extends ApiException {
  const BadRequestException([super.message = 'Solicitud inválida.']);
}

/// Error 401 - No autorizado (token inválido o expirado).
class UnauthorizedException extends ApiException {
  const UnauthorizedException([super.message = 'Sesión expirada.']);
}

/// Error 403 - Prohibido (sin permisos).
class ForbiddenException extends ApiException {
  const ForbiddenException([
    super.message = 'No tenés permisos para esta acción.',
  ]);
}

/// Error 404 - No encontrado.
class NotFoundException extends ApiException {
  const NotFoundException([super.message = 'Recurso no encontrado.']);
}

/// Error 422 - Validación fallida.
class ValidationException extends ApiException {
  const ValidationException([super.message = 'Datos inválidos.']);
}

/// Error 429 - Demasiados intentos.
class RateLimitException extends ApiException {
  const RateLimitException([
    super.message = 'Demasiados intentos. Esperá un momento.',
  ]);
}

/// Error 500+ - Error del servidor.
class ServerException extends ApiException {
  const ServerException([
    super.message = 'Error del servidor. Intentá más tarde.',
  ]);
}

/// Error desconocido.
class UnknownException extends ApiException {
  const UnknownException([super.message = 'Ocurrió un error inesperado.']);
}
