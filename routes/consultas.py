from flask import Blueprint, jsonify, request
from db import ErrorBD, consultar_vista, llamar_procedimiento
from routes.utilidades import fecha_param, limpiar
from seguridad import requiere_admin

bp = Blueprint('consultas', __name__, url_prefix='/api')

def rango_fechas():
    desde = fecha_param('desde')
    hasta = fecha_param('hasta')
    if desde > hasta:
        raise ErrorBD('La fecha desde no puede ser mayor que la fecha hasta', 400)
    return desde, hasta

@bp.route('/dentro')
@requiere_admin
def dentro():
    return jsonify(limpiar(consultar_vista('v_usuarios_dentro')))

@bp.route('/indicadores')
@requiere_admin
def indicadores():
    return jsonify(limpiar(llamar_procedimiento('sp_indicadores'))[0])

@bp.route('/historial')
@requiere_admin
def historial():
    desde, hasta = rango_fechas()
    documento = request.args.get('documento') or None
    filas = llamar_procedimiento('sp_historial', (desde, hasta, documento))
    return jsonify(limpiar(filas))

@bp.route('/reportes')
@requiere_admin
def reportes():
    desde, hasta = rango_fechas()
    return jsonify(limpiar(llamar_procedimiento('sp_reporte', (desde, hasta))))
