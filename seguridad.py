import datetime
from functools import wraps

import bcrypt
import jwt
from flask import g, jsonify, request

import config


def cifrar_contrasena(texto):
    return bcrypt.hashpw(texto.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')


def verificar_contrasena(texto, hash_guardado):
    try:
        return bcrypt.checkpw(texto.encode('utf-8'), hash_guardado.encode('utf-8'))
    except (ValueError, AttributeError):
        return False

def crear_token(id_personal, rol):
    ahora = datetime.datetime.now(datetime.timezone.utc)
    datos = {
        'sub': str(id_personal),
        'rol': rol,
        'iat': ahora,
        'exp': ahora + datetime.timedelta(hours=config.JWT_HORAS),
    }
    return jwt.encode(datos, config.JWT_SECRET, algorithm='HS256')

def leer_token(token):
    return jwt.decode(token, config.JWT_SECRET, algorithms=['HS256'])

def _proteger(roles_permitidos):
    def decorador(funcion):
        @wraps(funcion)
        def envoltura(*args, **kwargs):
            cabecera = request.headers.get('Authorization', '')
            if not cabecera.startswith('Bearer '):
                return jsonify({'error': 'Debes iniciar sesión'}), 401
            try:
                datos = leer_token(cabecera[7:])
            except jwt.ExpiredSignatureError:
                return jsonify({'error': 'La sesión venció, inicia sesión de nuevo'}), 401
            except jwt.InvalidTokenError:
                return jsonify({'error': 'Sesión no válida'}), 401
            if datos.get('rol') not in roles_permitidos:
                return jsonify({'error': 'No tienes permiso para esta acción'}), 403
            g.id_personal = int(datos['sub'])
            g.rol = datos['rol']
            return funcion(*args, **kwargs)
        return envoltura
    return decorador


requiere_personal = _proteger(('administrador', 'celador'))

requiere_admin = _proteger(('administrador',))

