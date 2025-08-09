import os, subprocess, tempfile
from flask import Flask, request, send_file, Response
from flask_cors import CORS

app = Flask(__name__)
CORS(app)

AUDIVERIS_BIN = os.environ.get('AUDIVERIS_BIN', '/Applications/Audiveris.app/Contents/MacOS/Audiveris')

@app.route('/omr', methods=['POST'])
def omr():
    if 'file' not in request.files:
        return Response('No file uploaded', status=400)

    f = request.files['file']
    suffix = os.path.splitext(f.filename)[1] or '.pdf'

    with tempfile.TemporaryDirectory() as td:
        inp = os.path.join(td, 'in' + suffix)
        outd = os.path.join(td, 'out')
        os.makedirs(outd, exist_ok=True)
        f.save(inp)

        cmd = [AUDIVERIS_BIN, '-batch', '-export', '-output', outd, inp]
        proc = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)

        if proc.returncode != 0:
            return Response('Audiveris error:\n' + proc.stderr, status=500)

        xml_path = None
        for root, _, files in os.walk(outd):
            for name in files:
                if name.lower().endswith('.xml'):
                    xml_path = os.path.join(root, name)
                    break
            if xml_path:
                break

        if not xml_path:
            return Response('No MusicXML produced', status=500)

        return send_file(xml_path, mimetype='application/xml')

if __name__ == '__main__':
    app.run(host='127.0.0.1', port=8000, debug=True)