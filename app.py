from flask import Flask, jsonify
from flask_cors import CORS

from db import ErrorBD


def crear_app():
    app = Flask(__name__)
    CORS(app, origins=['http://localhost:5173'])

    @app.errorhandler(ErrorBD)
    def manejar_error_bd(error):
        return jsonify({'error': error.mensaje}), error.codigo

    @app.route('/api/salud')
    def salud():
        return jsonify({'estado': 'ok'})

    return app


app = crear_app()