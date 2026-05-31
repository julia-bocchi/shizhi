
from flask import Flask, request, jsonify

app = Flask(__name__)

@app.post("/api/v1/tts/briefing")
def tts_briefing():
      data = request.get_json() or {}
      text = data.get("text", "")

      if not text.strip():
          return jsonify({"code": 400, "message": "text不能为空"}), 400

      return jsonify({
          "audioUrl": "http://localhost:8000/static/demo.wav",
          "cached": False,
          "durationMs": 1200,
          "voice": data.get("voice", "housekeeper_default")
      })

if __name__ == "__main__":
    app.run("127.0.0.1", port=8000, debug=True)
