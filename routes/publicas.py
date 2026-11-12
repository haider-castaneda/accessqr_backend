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

def verificar_usuario(datos):
    documento = campo(datos, 'documento', 20)
    contrasena = campo(datos, 'contrasena', 200, recortar=False)
    filas = llamar_procedimiento('sp_obtener_usuario_login', (documento,))
    if not filas or not verificar_contrasena(contrasena, filas[0]['contrasena_hash']):
        raise ErrorBD('Documento o contraseña incorrectos', 401)
    usuario = filas[0]
    mensajes = {
        'pendiente': 'Tu cuenta aún está pendiente de aprobación',
        'rechazado': 'Tu solicitud fue rechazada. Comunícate con un administrador',
        'inactivo': 'Tu cuenta está inactiva. Comunícate con un administrador',
    }
    if usuario['estado'] != 'activo':
        raise ErrorBD(mensajes[usuario['estado']], 403)
    return usuario

@bp.route('/mi-qr', methods=['POST'])
def mi_qr():
    usuario = verificar_usuario(datos_json())
    filas = llamar_procedimiento('sp_obtener_token', (usuario['id_usuario'],))
    if not filas:
        raise ErrorBD('Tu QR todavía no está disponible', 404)
    return jsonify({
        'nombre': usuario['nombre'],
        'qr': generar_qr_base64(filas[0]['token_qr']),
    })

@bp.route('/recuperar-qr', methods=['POST'])
def recuperar_qr():
    usuario = verificar_usuario(datos_json())
    token = generar_token()
    llamar_procedimiento('sp_reponer_qr', (usuario['id_usuario'], token))
    return jsonify({
        'nombre': usuario['nombre'],
        'qr': generar_qr_base64(token),
    })
