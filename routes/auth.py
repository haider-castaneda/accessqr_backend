from flask import Blueprint, jsonify
from db import ErrorBD, llamar_procedimiento
from routes.utilidades import campo, datos_json
from seguridad import crear_token, verificar_contrasena

bp = Blueprint('auth', __name__, url_prefix='/api')

@bp.route('/login', methods=['POST'])
def login():
    datos = datos_json()
    usuario = campo(datos, 'usuario', 50)
    contrasena = campo(datos, 'contrasena', 200, recortar=False)

    filas = llamar_procedimiento('sp_obtener_admin', (usuario,))
    if not filas or not verificar_contrasena(contrasena, filas[0]['contrasena_hash']):
        raise ErrorBD('Usuario o contraseña incorrectos', 401)

    personal = filas[0]
    if personal['estado'] != 'activo':
        raise ErrorBD('Tu cuenta está inactiva, comunícate con un administrador', 403)

    return jsonify({
        'token': crear_token(personal['id_admin'], personal['rol']),
        'rol': personal['rol'],
        'nombre': personal['nombre'],
    })