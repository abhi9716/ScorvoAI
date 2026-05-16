#!/bin/bash
cd /home/melody/Project/ScorvoAI/backend
source venv/bin/activate
while true; do
    uvicorn main:app --host 0.0.0.0 --port 8000 >> /tmp/scorvoai.log 2>&1
    echo "Server crashed, restarting in 5s..." >> /tmp/scorvoai.log
    sleep 5
done
