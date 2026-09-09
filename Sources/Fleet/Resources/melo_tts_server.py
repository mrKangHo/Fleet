"""Fleet용 MeloTTS 로컬 합성 서버.

Swift 쪽 MeloTTSSpeechSynthesisService가 이 스크립트를 백그라운드 프로세스로 띄우고,
localhost HTTP로 텍스트를 보내 WAV 오디오를 돌려받는다. 모델을 프로세스 생애주기 동안
한 번만 로드해서, 매 발화마다 수 초씩 걸리는 모델 로딩을 피한다.
"""

import argparse
import os
import tempfile

from fastapi import FastAPI
from fastapi.responses import Response
from pydantic import BaseModel

app = FastAPI()
_model = None
_speaker_id = None


class SynthesizeRequest(BaseModel):
    text: str
    speed: float = 1.0


@app.on_event("startup")
def load_model() -> None:
    global _model, _speaker_id
    from melo.api import TTS

    _model = TTS(language="KR", device="cpu")
    _speaker_id = _model.hps.data.spk2id["KR"]


@app.get("/health")
def health() -> dict:
    return {"status": "ok", "ready": _model is not None}


@app.post("/synthesize")
def synthesize(req: SynthesizeRequest) -> Response:
    fd, out_path = tempfile.mkstemp(suffix=".wav")
    os.close(fd)
    try:
        _model.tts_to_file(req.text, _speaker_id, out_path, speed=req.speed)
        with open(out_path, "rb") as f:
            data = f.read()
    finally:
        if os.path.exists(out_path):
            os.unlink(out_path)
    return Response(content=data, media_type="audio/wav")


if __name__ == "__main__":
    import uvicorn

    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=8765)
    args = parser.parse_args()
    uvicorn.run(app, host="127.0.0.1", port=args.port, log_level="warning")
