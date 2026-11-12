from flask import Blueprint, g, jsonify
from db import ErrorBD, consultar_vista, llamar_procedimiento
from routes.utilidades import campo, datos_json, limpiar, validar_contrasena
from seguridad import cifrar_contrasena, requiere_admin

bp = Blueprint('administradores', __name__, url_prefix='/api')

@bp.route('/administradores')
@requiere_admin
def listar():
    return jsonify(limpiar(consultar_vista('v_administradores')))

@bp.route('/administradores', methods=['POST'])
@requiere_admin
def crear():
    datos = datos_json()
    usuario_login = campo(datos, 'usuario_login', 50)
    nombre = campo(datos, 'nombre', 100)
    rol = campo(datos, 'rol', 20)
    if rol not in ('administrador', 'celador'):
        raise ErrorBD('El rol debe ser administrador o celador', 400)
    contrasena = campo(datos, 'contrasena', 200, recortar=False)
    contrasena_hash = cifrar_contrasena(validar_contrasena(contrasena))

    filas = llamar_procedimiento(
        'sp_crear_admin', (usuario_login, contrasena_hash, nombre, rol, g.id_personal)
    )
    return jsonify({'mensaje': 'Cuenta de personal creada', 'id_admin': filas[0]['id_admin']}), 201

@bp.route('/administradores/<int:id_admin>/estado', methods=['POST'])
@requiere_admin
def cambiar_estado(id_admin):
    estado = campo(datos_json(), 'estado', 20)
    if not consultar_vista('v_administradores', {'id_admin': id_admin}):
        raise ErrorBD('La cuenta no existe', 404)
    llamar_procedimiento('sp_estado_admin', (id_admin, estado, g.id_personal))
    return jsonify({'mensaje': f'Estado cambiado a {estado}'})
