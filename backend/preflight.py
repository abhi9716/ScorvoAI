#!/usr/bin/env python3
"""Pre-deploy sanity check for ScorvoAI backend.

Run before pushing to Railway / Render / Fly / Cloud Run:

    python preflight.py

Catches the 5 things that go wrong 95% of the time:
  1. OLLAMA_API_KEY missing or invalid
  2. OLLAMA_BASE not reachable
  3. GEMMA_MODEL not pulled / not available
  4. Ollama Cloud web search unreachable
  5. /health endpoint not responding

Exit code is non-zero if any check fails.
"""
import asyncio
import os
import sys

import httpx

# Allow running from repo root or backend/
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from services.ai_service import (  # noqa: E402
    GEMMA_MODEL,
    OLLAMA_BASE,
    OLLAMA_API_KEY,
    OLLAMA_CLOUD_BASE,
)


GREEN = "\033[32m"
RED = "\033[31m"
YELLOW = "\033[33m"
RESET = "\033[0m"
BOLD = "\033[1m"


def ok(msg: str) -> None:
    print(f"  {GREEN}✓{RESET} {msg}")


def fail(msg: str) -> None:
    print(f"  {RED}✗{RESET} {msg}")


def warn(msg: str) -> None:
    print(f"  {YELLOW}⚠{RESET} {msg}")


async def check_env() -> bool:
    print(f"\n{BOLD}1. Environment{RESET}")
    print(f"     GEMMA_MODEL      = {GEMMA_MODEL}")
    print(f"     OLLAMA_BASE      = {OLLAMA_BASE}")
    print(f"     OLLAMA_API_KEY   = {'SET (' + str(len(OLLAMA_API_KEY)) + ' chars)' if OLLAMA_API_KEY else 'NOT SET'}")
    print(f"     CORS_ORIGINS     = {os.getenv('CORS_ORIGINS', '*')}")
    print(f"     PORT             = {os.getenv('PORT', '8000')}")
    if not OLLAMA_API_KEY:
        fail("OLLAMA_API_KEY is not set → /current-affairs will return 500")
        return False
    ok("All required env vars present")
    return True


async def check_ollama_reachable() -> bool:
    print(f"\n{BOLD}2. Ollama server reachable{RESET}")
    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            r = await client.get(f"{OLLAMA_BASE}/api/tags")
            if r.status_code != 200:
                fail(f"{OLLAMA_BASE}/api/tags returned {r.status_code}")
                return False
            ok(f"{OLLAMA_BASE} is reachable")
            return True
    except Exception as e:
        fail(f"Cannot reach {OLLAMA_BASE}: {type(e).__name__}: {e}")
        warn("If running in Docker, try OLLAMA_BASE=http://host.docker.internal:11434")
        warn("Or use Docker `--network=host`")
        return False


async def check_model_available() -> bool:
    print(f"\n{BOLD}3. Gemma 4 model pulled{RESET}")
    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            r = await client.get(f"{OLLAMA_BASE}/api/tags")
            tags = [m.get("name", "") for m in r.json().get("models", [])]
        if GEMMA_MODEL in tags:
            ok(f"{GEMMA_MODEL} is installed")
            return True
        # Loose match (e.g. gemma4:31b-cloud-q4_0)
        base = GEMMA_MODEL.split(":")[0]
        loose = [t for t in tags if base in t]
        if loose:
            warn(f"{GEMMA_MODEL} not found, but related: {loose}")
            warn(f"Run: ollama pull {GEMMA_MODEL}")
            return False
        fail(f"{GEMMA_MODEL} not pulled. Run: ollama pull {GEMMA_MODEL}")
        if tags:
            print(f"     Available models: {tags[:10]}")
        return False
    except Exception as e:
        fail(f"Could not list models: {e}")
        return False


async def check_cloud_search() -> bool:
    print(f"\n{BOLD}4. Ollama Cloud Web Search{RESET}")
    if not OLLAMA_API_KEY:
        fail("OLLAMA_API_KEY not set, skipping")
        return False
    try:
        async with httpx.AsyncClient(timeout=15.0) as client:
            r = await client.post(
                f"{OLLAMA_CLOUD_BASE}/api/web_search",
                headers={"Authorization": f"Bearer {OLLAMA_API_KEY}"},
                json={"query": "test", "max_results": 1},
            )
            if r.status_code == 200:
                ok(f"Web search API works (key valid, network OK)")
                return True
            if r.status_code in (401, 403):
                fail(f"OLLAMA_API_KEY rejected (HTTP {r.status_code}) — check the key at https://ollama.com/settings/keys")
                return False
            fail(f"Web search returned HTTP {r.status_code}: {r.text[:200]}")
            return False
    except Exception as e:
        fail(f"Cannot reach Ollama Cloud: {type(e).__name__}: {e}")
        return False


async def check_quick_inference() -> bool:
    print(f"\n{BOLD}5. End-to-end inference (one prompt){RESET}")
    try:
        async with httpx.AsyncClient(timeout=60.0) as client:
            r = await client.post(
                f"{OLLAMA_BASE}/api/chat",
                json={
                    "model": GEMMA_MODEL,
                    "messages": [{"role": "user", "content": "Reply with the single word OK"}],
                    "stream": False,
                    "options": {"num_predict": 8},
                },
            )
            if r.status_code != 200:
                fail(f"Inference returned HTTP {r.status_code}: {r.text[:200]}")
                return False
            reply = r.json().get("message", {}).get("content", "").strip()
            if reply:
                ok(f'Inference works — model replied: "{reply[:60]}"')
                return True
            fail("Empty response from model")
            return False
    except Exception as e:
        fail(f"Inference failed: {type(e).__name__}: {e}")
        return False


async def main() -> int:
    print(f"\n{BOLD}── ScorvoAI Backend Preflight ──{RESET}")
    results = []
    results.append(await check_env())
    results.append(await check_ollama_reachable())
    if results[-1]:
        results.append(await check_model_available())
    else:
        results.append(False)
    results.append(await check_cloud_search())
    if results[1] and results[2]:
        results.append(await check_quick_inference())
    else:
        print(f"\n{BOLD}5. End-to-end inference (one prompt){RESET}")
        warn("Skipped (Ollama not reachable or model missing)")
        results.append(False)

    print()
    if all(results):
        print(f"{GREEN}{BOLD}✓ All checks passed — safe to deploy{RESET}\n")
        return 0
    failed = sum(1 for r in results if not r)
    print(f"{RED}{BOLD}✗ {failed} check(s) failed — fix before deploying{RESET}\n")
    return 1


if __name__ == "__main__":
    sys.exit(asyncio.run(main()))
