#!/usr/bin/env python3
import subprocess
import sys
import time
import os

def main():
    while True:
        print(f"[{time.strftime('%Y-%m-%d %H:%M:%S')}] Starting uvicorn...")
        proc = subprocess.Popen(
            [sys.executable, "-m", "uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"],
            cwd=os.path.dirname(os.path.abspath(__file__)),
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL
        )
        proc.wait()
        print(f"[{time.strftime('%Y-%m-%d %H:%M:%S')}] Uvicorn stopped, restarting in 2s...")
        time.sleep(2)

if __name__ == "__main__":
    main()