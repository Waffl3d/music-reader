import os
import shutil
import tempfile
import subprocess
from pathlib import Path

from flask import Flask, request, send_file, Response, jsonify
from flask_cors import CORS
from werkzeug.utils import secure_filename

app = Flask(__name__)
CORS(app)

# --- Config ---
# Render/Docker sets AUDIVERIS_BIN; default to 'audiveris' on PATH (Dockerfile symlinks it)
AUDIVERIS_BIN = os.environ.get("AUDIVERIS_BIN", "audiveris")

# Max upload (adjust as needed)
app.config["MAX_CONTENT_LENGTH"] = int(os.environ.get("MAX_UPLOAD_MB", "40")) * 1024 * 1024
# Audiveris run timeout (seconds)
OMR_TIMEOUT = int(os.environ.get("OMR_TIMEOUT", "360"))

# --- Routes ---

@app.get("/")
def root():
    return jsonify(ok=True, hint="Use /health, /version, or POST /omr with a photo/PDF")

@app.get("/health")
def health():
    return jsonify(ok=True)

@app.get("/version")
def version():
    try:
        r = subprocess.run([AUDIVERIS_BIN, "-version"],
                           stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                           text=True, timeout=15)
        return jsonify(ok=(r.returncode == 0), output=r.stdout.strip())
    except Exception as e:
        return jsonify(ok=False, error=str(e)), 500

@app.post("/omr")
def omr():
    if "file" not in request.files:
        return jsonify(error="missing 'file' field"), 400

    f = request.files["file"]
    if not f.filename:
        return jsonify(error="empty filename"), 400

    # Sanitize name, preserve extension (default .pdf if unknown)
    safe_name = secure_filename(f.filename)
    ext = Path(safe_name).suffix or ".pdf"

    work = tempfile.mkdtemp(prefix="omr_")
    try:
        inp = os.path.join(work, f"in{ext}")
        outd = os.path.join(work, "out")
        os.makedirs(outd, exist_ok=True)
        f.save(inp)

        # Run Audiveris (batch + export → MusicXML into outd)
        cmd = [AUDIVERIS_BIN, "-batch", "-export", "-output", outd, inp]
        proc = subprocess.run(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            timeout=OMR_TIMEOUT,
        )

        if proc.returncode != 0:
            return jsonify(error="audiveris failed", log=proc.stdout), 500

        # Find a produced MusicXML
        xml_path = None
        for root_dir, _, files in os.walk(outd):
            for name in files:
                if name.lower().endswith(".xml"):
                    xml_path = os.path.join(root_dir, name)
                    break
            if xml_path:
                break

        if not xml_path:
            return jsonify(error="no MusicXML produced", log=proc.stdout), 500

        # Correct MusicXML MIME (works with OSMD and browsers)
        return send_file(xml_path, mimetype="application/musicxml+xml")

    except subprocess.TimeoutExpired:
        return jsonify(error=f"audiveris timed out after {OMR_TIMEOUT}s"), 504
    except Exception as e:
        return jsonify(error=str(e)), 500
    finally:
        shutil.rmtree(work, ignore_errors=True)


if __name__ == "__main__":
    # Local dev only (Render runs via Gunicorn)
    port = int(os.environ.get("PORT", "8000"))
    app.run(host="0.0.0.0", port=port, debug=True)
