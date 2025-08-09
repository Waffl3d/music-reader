import os
import subprocess
import tempfile
from flask import Flask, request, send_file, Response, jsonify
from flask_cors import CORS

app = Flask(__name__)
CORS(app)

# Path to Audiveris (Render build puts it here; override with env if needed)
AUDIVERIS_BIN = os.environ.get("AUDIVERIS_BIN", "/opt/audiveris/bin/audiveris")

@app.get("/")
def root():
    # Visiting the base URL returns a friendly status
    return jsonify(ok=True, hint="Use /health or POST /omr with a photo/PDF")

@app.get("/health")
def health():
    return jsonify(ok=True)

@app.post("/omr")
def omr():
    if "file" not in request.files:
        return Response("No file uploaded", status=400)

    f = request.files["file"]
    suffix = os.path.splitext(f.filename)[1] or ".pdf"

    with tempfile.TemporaryDirectory() as td:
        inp = os.path.join(td, "in" + suffix)
        outd = os.path.join(td, "out")
        os.makedirs(outd, exist_ok=True)
        f.save(inp)

        # Run Audiveris OMR → MusicXML
        cmd = [AUDIVERIS_BIN, "-batch", "-export", "-output", outd, inp]
        proc = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)

        if proc.returncode != 0:
            return Response("Audiveris error:\n" + proc.stderr, status=500)

        # Find the first produced MusicXML file
        xml_path = None
        for root_dir, _, files in os.walk(outd):
            for name in files:
                if name.lower().endswith(".xml"):
                    xml_path = os.path.join(root_dir, name)
                    break
            if xml_path:
                break

        if not xml_path:
            return Response("No MusicXML produced", status=500)

        return send_file(xml_path, mimetype="application/xml")

if __name__ == "__main__":
    # Local dev runner (Render/Gunicorn won't use this block)
    port = int(os.environ.get("PORT", 8000))  # Render provides PORT
    app.run(host="0.0.0.0", port=port, debug=True)
