from flask import Blueprint, g, jsonify, request
from db import ErrorBD, consultar_vista, llamar_procedimiento
from qr_util import generar_qr_base64, generar_token
from routes.utilidades import campo, datos_json, limpiar, validar_documento
from seguridad import requiere_admin, requiere_personal

bp = Blueprint('gestion', __name__, url_prefix='/api')

@bp.route('/pendientes')
@requiere_personal
def pendientes():
    return jsonify(limpiar(consultar_vista('v_usuarios_pendientes')))

@bp.route('/usuarios/<int:id_usuario>/revisar', methods=['POST'])
@requiere_personal
def revisar(id_usuario):
    llamar_procedimiento('sp_marcar_revisado', (id_usuario, g.id_personal))
    return jsonify({'mensaje': 'Usuario marcado como revisado'})

@bp.route('/usuarios/<int:id_usuario>/aprobar', methods=['POST'])
@requiere_admin
def aprobar(id_usuario):
    filas = llamar_procedimiento(
        'sp_aprobar_usuario', (id_usuario, generar_token(), g.id_personal)
    )
    return jsonify({
        'mensaje': 'Usuario aprobado',
        'id_usuario': filas[0]['id_usuario'],
        'nombre': filas[0]['nombre'],
    })

@bp.route('/usuarios/<int:id_usuario>/rechazar', methods=['POST'])
@requiere_admin
def rechazar(id_usuario):
    llamar_procedimiento('sp_rechazar_usuario', (id_usuario, g.id_personal))
    return jsonify({'mensaje': 'Usuario rechazado'})

@bp.route('/usuarios/<int:id_usuario>/reabrir', methods=['POST'])
@requiere_admin
def reabrir(id_usuario):
    llamar_procedimiento('sp_reabrir_usuario', (id_usuario, g.id_personal))
    return jsonify({'mensaje': 'Solicitud reabierta, el usuario vuelve a pendiente'})

@bp.route('/usuarios')
@requiere_admin
def usuarios():
    estado = request.args.get('estado')
    filtros = None
    if estado:
        if estado not in ('pendiente', 'activo', 'inactivo', 'rechazado'):
            raise ErrorBD('Estado no válido', 400)
        filtros = {'estado': estado}
    return jsonify(limpiar(consultar_vista('v_usuarios', filtros)))

@bp.route('/usuarios/<int:id_usuario>/estado', methods=['POST'])
@requiere_admin
def cambiar_estado(id_usuario):
    estado = campo(datos_json(), 'estado', 20)
    if not consultar_vista('v_usuarios', {'id_usuario': id_usuario}):
        raise ErrorBD('El usuario no existe', 404)
    llamar_procedimiento('sp_cambiar_estado', (id_usuario, estado, g.id_personal))
    return jsonify({'mensaje': f'Estado cambiado a {estado}'})

@bp.route('/qr/regenerar', methods=['POST'])
@requiere_personal
def regenerar_qr():
    documento = validar_documento(campo(datos_json(), 'documento', 20))
    encontrados = consultar_vista('v_usuarios', {'documento': documento})
    if not encontrados:
        raise ErrorBD('No existe un usuario con ese documento', 404)
    token = generar_token()
    llamar_procedimiento('sp_reponer_qr', (encontrados[0]['id_usuario'], token))
    return jsonify({
        'nombre': encontrados[0]['nombre'],
        'qr': generar_qr_base64(token),
    })
