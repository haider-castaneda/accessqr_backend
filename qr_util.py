import base64
import io
import secrets

import qrcode


def generar_token():
    return secrets.token_hex(16)

def generar_qr_base64(token):
    imagen = qrcode.make(token)
    memoria = io.BytesIO()
    imagen.save(memoria, format='PNG')
    codificada = base64.b64encode(memoria.getvalue()).decode('ascii')
    return 'data:image/png;base64,' + codificada