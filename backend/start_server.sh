#!/bin/bash
cd /home/melody/Project/ScorvoAI/backend
source venv/bin/activate
exec uvicorn main:app --host 0.0.0.0 --port 8000 > /tmp/scorvoai.log 2>&1
