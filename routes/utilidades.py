import datetime
import decimal
import re
from flask import request
from db import ErrorBD

def datos_json():
    datos = request.get_json(silent=True)
    if not isinstance(datos, dict):
        raise ErrorBD('Se esperaba un cuerpo JSON', 400)
    return datos

def campo(datos, nombre, maximo=None, opcional=False, recortar=True):
    valor = datos.get(nombre)
    if isinstance(valor, (int, float)) and not isinstance(valor, bool):
        valor = str(valor)
    if not isinstance(valor, str) or valor.strip() == '':
        if opcional:
            return None
        raise ErrorBD(f'Falta el campo {nombre}', 400)
    if recortar:
        valor = valor.strip()
    if maximo and len(valor) > maximo:
        raise ErrorBD(f'El campo {nombre} es demasiado largo', 400)
    return valor

def validar_documento(valor):
    if not re.fullmatch(r'[0-9]{5,20}', valor):
        raise ErrorBD('El documento debe tener solo números (entre 5 y 20)', 400)
    return valor

def validar_telefono(valor):
    if not re.fullmatch(r'[+]?[0-9]{7,15}', valor):
        raise ErrorBD('El teléfono debe tener entre 7 y 15 números', 400)
    return valor

def validar_tipo_documento(valor):
    if valor not in ('CC', 'TI', 'CE'):
        raise ErrorBD('El tipo de documento debe ser CC, TI o CE', 400)
    return valor

def validar_contrasena(valor):
    if len(valor) < 8:
        raise ErrorBD('La contraseña debe tener al menos 8 caracteres', 400)
    if len(valor.encode('utf-8')) > 72:
        raise ErrorBD('La contraseña es demasiado larga (máximo 72 bytes)', 400)
    return valor

def fecha_param(nombre):
    texto = request.args.get(nombre)
    if not texto:
        return datetime.date.today()
    try:
        return datetime.date.fromisoformat(texto)
    except ValueError:
        raise ErrorBD(f'La fecha {nombre} debe tener formato AAAA-MM-DD', 400)

def limpiar(filas):
    resultado = []
    for fila in filas:
        nueva = {}
        for clave, valor in fila.items():
            if isinstance(valor, (datetime.datetime, datetime.date)):
                valor = valor.isoformat()
            elif isinstance(valor, decimal.Decimal):
                valor = int(valor) if valor == valor.to_integral_value() else float(valor)
            nueva[clave] = valor
        resultado.append(nueva)
    return resultado