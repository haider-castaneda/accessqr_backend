from flask import Blueprint, jsonify
from db import ErrorBD, consultar_vista, llamar_procedimiento
from qr_util import generar_qr_base64, generar_token
from routes.utilidades import (campo, datos_json, validar_contrasena,
                               validar_documento, validar_telefono,
                               validar_tipo_documento)
from seguridad import cifrar_contrasena, verificar_contrasena

bp = Blueprint('publicas', __name__, url_prefix='/api')

MENSAJE_REGISTRO = 'Registro recibido. Tu cuenta queda pendiente de aprobación por la administración'
TIPOS_USUARIO_REGISTRO = ('empleado', 'miembro', 'aprendiz', 'instructor')

@bp.route('/registro', methods=['POST'])
def registro():
    datos = datos_json()
    nombre = campo(datos, 'nombre', 100)
    tipo_documento = validar_tipo_documento(campo(datos, 'tipo_documento', 5))
    documento = validar_documento(campo(datos, 'documento', 20))
    telefono = validar_telefono(campo(datos, 'telefono', 25))
    tipo_usuario = campo(datos, 'tipo_usuario', 20)

    if tipo_usuario not in TIPOS_USUARIO_REGISTRO:
        raise ErrorBD(
            'El tipo de usuario debe ser empleado, miembro, aprendiz o instructor', 400
        )

    contrasena = campo(datos, 'contrasena', 200, recortar=False)
    if contrasena != datos.get('confirmar_contrasena'):
        raise ErrorBD('Las contraseñas no coinciden', 400)

    contrasena_hash = cifrar_contrasena(validar_contrasena(contrasena))
    existentes = consultar_vista('v_usuarios', {'documento': documento})

    if not existentes:
        llamar_procedimiento('sp_registrar_usuario', (
            nombre, documento, tipo_documento, telefono, contrasena_hash, tipo_usuario
        ))
    elif existentes[0]['tipo_usuario'] == 'visitante':
        llamar_procedimiento('sp_convertir_visitante', (
            documento, nombre, tipo_documento, telefono, contrasena_hash, tipo_usuario
        ))
    elif existentes[0]['estado'] == 'rechazado':
        raise ErrorBD('Tu solicitud anterior fue rechazada. Comunícate con un administrador', 409)
    else:
        raise ErrorBD('Este documento ya está registrado en el sistema', 409)

    return jsonify({'mensaje': MENSAJE_REGISTRO}), 201