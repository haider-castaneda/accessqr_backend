from flask import Blueprint, jsonify
from db import consultar_vista, llamar_procedimiento
from routes.utilidades import (campo, datos_json, limpiar, validar_documento,
                               validar_tipo_documento)
from seguridad import requiere_personal

bp = Blueprint('acceso', __name__, url_prefix='/api')

@bp.route('/lector/escaneo', methods=['POST'])
@requiere_personal
def escaneo():
    token = campo(datos_json(), 'token', 250)
    filas = llamar_procedimiento('sp_registrar_movimiento', (token,))
    return jsonify(limpiar(filas)[0])

@bp.route('/visitantes', methods=['POST'])
@requiere_personal
def visitantes():
    datos = datos_json()
    documento = validar_documento(campo(datos, 'documento', 20))
    motivo = campo(datos, 'motivo_visita', 100, opcional=True)
    existentes = consultar_vista('v_usuarios', {'documento': documento})

    if existentes:
        nombre = existentes[0]['nombre']
        tipo_documento = existentes[0]['tipo_documento']
    else:
        nombre = campo(datos, 'nombre', 100)
        tipo_documento = validar_tipo_documento(campo(datos, 'tipo_documento', 5))

    filas = llamar_procedimiento(
        'sp_registrar_visitante', (nombre, documento, tipo_documento, motivo)
    )
    return jsonify(limpiar(filas)[0]), 201
