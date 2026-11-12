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
