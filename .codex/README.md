# Codex Agent (local) — configuration

This directory contains configuration to run a local Codex-style agent for this repository.

Files:
- `codex-agent.yaml` — main agent configuration (model, tools, memory).
- `agent.env.example` — environment variables example (copy to `agent.env` and set your API key).
- `docker-compose.codex.yml` — optional docker-compose service to run the agent (at repo root).

Usage (example):
1. Copy the env example and set your API key:

   ```bash
   cp .codex/agent.env.example .codex/agent.env
   # edit .codex/agent.env and set OPENAI_API_KEY
   ```

2. Start with docker-compose:

   ```bash
   docker compose -f docker-compose.codex.yml up -d
   ```

3. Check logs at `logs/codex-agent.log`.

Customize `codex-agent.yaml` to add or remove tools, adjust model settings, or change memory storage.
