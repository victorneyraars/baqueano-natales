/// Cliente HTTP centralizado basado en Dio.
///
/// Configura:
/// - URL base según AppConfig
/// - Timeouts
/// - Interceptor para agregar JWT automáticamente
/// - Interceptor para transformar errores en ApiException
/// - Acepta certificados autofirmados en dev
library;

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';

import 'package:baqueano_natales/core/config/app_config.dart';
import 'package:baqueano_natales/core/network/api_exceptions.dart';
import 'package:baqueano_natales/core/storage/secure_storage.dart';

class DioClient {
  DioClient._();

  static Dio? _dio;

  /// Instancia singleton de Dio configurada.
  static Dio get instance {
    _dio ??= _createDio();
    return _dio!;
  }

  static Dio _createDio() {
    final dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        // Solo 2xx son respuestas exitosas. Los 4xx/5xx se manejan
        // como errores en el interceptor (mapea a ApiException).
        validateStatus: (status) =>
            status != null && status >= 200 && status < 300,
      ),
    );

    // Acepta certificados autofirmados SOLO en dev
    if (AppConfig.environment == Environment.dev) {
      dio.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () {
          final client = HttpClient();
          client.badCertificateCallback = (
            X509Certificate cert,
            String host,
            int port,
          ) => true;
          return client;
        },
      );
    }

    // Interceptor: agrega el JWT a cada request (si existe)
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await SecureStorageService.getAccessToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          if (kDebugMode) {
            debugPrint('[Dio] ${options.method} ${options.uri}');
          }
          handler.next(options);
        },
      ),
    );

    // Interceptor: transforma errores en ApiException
    dio.interceptors.add(
      InterceptorsWrapper(
        onResponse: (response, handler) {
          if (kDebugMode) {
            debugPrint(
              '[Dio] ${response.statusCode} ${response.requestOptions.uri}',
            );
          }
          handler.next(response);
        },
        onError: (error, handler) {
          final apiException = _mapErrorToException(error);
          if (kDebugMode) {
            debugPrint('[Dio] ERROR ${error.type}: ${apiException.message}');
          }
          handler.reject(
            DioException(
              requestOptions: error.requestOptions,
              error: apiException,
              type: error.type,
              response: error.response,
            ),
          );
        },
      ),
    );

    return dio;
  }

  /// Mapea un DioException a una ApiException tipada.
  static ApiException _mapErrorToException(DioException error) {
    // Errores de red
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return const TimeoutException();
    }

    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.unknown) {
      return const NetworkException();
    }

    // Errores HTTP
    final statusCode = error.response?.statusCode;
    final detail = _extractDetail(error.response?.data);

    switch (statusCode) {
      case 400:
        return BadRequestException(detail ?? 'Solicitud inválida.');
      case 401:
        return UnauthorizedException(detail ?? 'Sesión expirada.');
      case 403:
        return ForbiddenException(detail ?? 'No tenés permisos.');
      case 404:
        return NotFoundException(detail ?? 'Recurso no encontrado.');
      case 422:
        return ValidationException(detail ?? 'Datos inválidos.');
      case 429:
        return RateLimitException(detail ?? 'Demasiados intentos.');
      default:
        if (statusCode != null && statusCode >= 500) {
          return ServerException(detail ?? 'Error del servidor.');
        }
        return UnknownException(detail ?? 'Error inesperado.');
    }
  }

  /// Extrae el campo `detail` del body de error del backend.
  static String? _extractDetail(dynamic data) {
    if (data is Map<String, dynamic>) {
      final detail = data['detail'];
      if (detail is String) return detail;
    }
    return null;
  }

  /// Resetea la instancia (útil en logout).
  static void reset() {
    _dio = null;
  }
}
