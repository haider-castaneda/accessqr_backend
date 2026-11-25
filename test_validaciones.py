"""Pruebas unitarias de las validaciones de entrada.

Se ejecutan con:   python -m pytest -v

No necesitan base de datos ni servidor encendido: comprueban funciones puras,
que es justamente lo que distingue una prueba unitaria de una prueba de API.
"""

import pytest

from db import ErrorBD
from routes.utilidades import (
    validar_contrasena,
    validar_documento,
    validar_telefono,
    validar_tipo_documento,
)


# ---------- documento ----------

def test_documento_valido():
    """Un documento de 10 digitos se acepta y se devuelve sin cambios."""
    assert validar_documento('1012345678') == '1012345678'


def test_documento_con_letras_es_rechazado():
    """Un documento con letras lanza ErrorBD con codigo 400."""
    with pytest.raises(ErrorBD) as excepcion:
        validar_documento('ABC12345')
    assert excepcion.value.codigo == 400
    assert 'solo números' in excepcion.value.mensaje


def test_documento_demasiado_corto_es_rechazado():
    """Menos de 5 digitos no es un documento valido."""
    with pytest.raises(ErrorBD):
        validar_documento('123')


# ---------- telefono ----------

def test_telefono_valido():
    assert validar_telefono('3124567890') == '3124567890'


def test_telefono_con_espacios_es_rechazado():
    with pytest.raises(ErrorBD):
        validar_telefono('312 456 7890')


# ---------- tipo de documento ----------

def test_tipo_documento_valido():
    assert validar_tipo_documento('CC') == 'CC'


def test_tipo_documento_invalido_es_rechazado():
    with pytest.raises(ErrorBD):
        validar_tipo_documento('PA')


# ---------- contrasena ----------

def test_contrasena_de_ocho_caracteres_se_acepta():
    """Ocho caracteres es el minimo exacto, asi que debe pasar."""
    assert validar_contrasena('Clave123') == 'Clave123'


def test_contrasena_corta_es_rechazada():
    with pytest.raises(ErrorBD) as excepcion:
        validar_contrasena('corta')
    assert excepcion.value.codigo == 400


def test_contrasena_demasiado_larga_es_rechazada():
    """bcrypt solo cifra los primeros 72 bytes, por eso se corta ahi."""
    with pytest.raises(ErrorBD):
        validar_contrasena('a' * 73)
