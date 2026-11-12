import traceback
from flask import Flask, jsonify
from flask_cors import CORS
from werkzeug.exceptions import HTTPException
from db import ErrorBD

def crear_app():
    app = Flask(__name__)
    CORS(app, origins=[
        'http://localhost:5173',
        'https://localhost:5173',
        r'https://192\.168\.\d+\.\d+:5173',
        r'https://10\.\d+\.\d+\.\d+:5173'
    ])

    @app.errorhandler(ErrorBD)
    def manejar_error_bd(error):
        return jsonify({'error': error.mensaje}), error.codigo

    @app.errorhandler(Exception)
    def manejar_error_general(error):
        if isinstance(error, HTTPException):
            mensajes = {404: 'Ruta no encontrada', 405: 'Método no permitido'}
            return jsonify({'error': mensajes.get(error.code, error.description)}), error.code
        traceback.print_exc()
        return jsonify({'error': 'Error interno del servidor'}), 500

    @app.route('/api/salud')
    def salud():
        return jsonify({'estado': 'ok'})

    from routes.acceso import bp as acceso_bp
    from routes.administradores import bp as administradores_bp
    from routes.auth import bp as auth_bp
    from routes.consultas import bp as consultas_bp
    from routes.gestion import bp as gestion_bp
    from routes.publicas import bp as publicas_bp

    for bp in (auth_bp, publicas_bp, gestion_bp, acceso_bp, consultas_bp, administradores_bp):
        app.register_blueprint(bp)

    return app

app = crear_app()