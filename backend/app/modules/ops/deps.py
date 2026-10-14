"""Dependencias del modulo ops.

Fase 1: solo re-exporta AdminUser del modulo auth (solo admin puede acceder).
"""
from app.modules.auth.deps import AdminUser  # noqa: F401

__all__ = ["AdminUser"]
