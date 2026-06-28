# ABZU Sovereign BEAM IDE

```
  █████╗ ██████╗ ███████╗██╗   ██╗
 ██╔══██╗██╔══██╗╚══███╔╝██║   ██║
 ███████║██████╔╝  ███╔╝ ██║   ██║
 ██╔══██║██╔══██╗ ███╔╝  ██║   ██║
 ██║  ██║██████╔╝███████╗╚██████╔╝
 ╚═╝  ╚═╝╚═════╝ ╚══════╝ ╚═════╝
 SOVEREIGN ARRAY SHELL — ⬡ Ω ↺ Ψ Δ Λ Σ Φ α
```

**Phoenix LiveView · Elixir · Nx Arrays · J Language · BOB AI · WORM Chain · GitLab CI Live Feed**

A sovereign BEAM IDE where every action is sealed to an append-only WORM chain,
BOB (IBM Gamma → Sovereign) reasons over your code in three languages,
and GitLab CI pipelines stream live Frankenstein results directly into the editor.

---

## Architecture

```
 ┌─────────────────────────────────────────────────────────┐
 │           ABZU SOVEREIGN BEAM IDE  :4000                │
 │                                                         │
 │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐  │
 │  │  ELIXIR  │ │  NX      │ │    J     │ │ ⬡ GITLAB │  │
 │  │  EDITOR  │ │ ARRAYS   │ │ LANGUAGE │ │ LIVE FEED│  │
 │  │ (Monaco) │ │          │ │          │ │ (PubSub) │  │
 │  └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘  │
 │       └────────────┴────────────┘             │        │
 │                    │                          │        │
 │  ┌─────────────────▼──────────────────────────▼──────┐ │
 │  │           Phoenix LiveView (IdeLive)               │ │
 │  │   PubSub subscriber: "sovereign:gitlab"            │ │
 │  └────┬──────────────────────────────┬───────────────┘ │
 │       │                              │                 │
 │  ┌────▼──────┐           ┌───────────▼─────────────┐  │
 │  │ BOB Agent │           │  POST /api/pipeline_event│  │
 │  │ + CATCODE │           │  PipelineEventController │  │
 │  └───────────┘           └───────────┬─────────────┘  │
 │                                      │                 │
 │  ┌───────────────────────────────────────────────────┐ │
 │  │   WormChain (DETS — append-only, sha256 DJB2)    │ │
 │  └───────────────────────────────────────────────────┘ │
 └─────────────────────────────────────────────────────────┘
          ▲
          │  POST /api/pipeline_event
          │  X-Sovereign-Sig · X-Sovereign-Ts
          │
 ┌────────┴──────────────────────────────────────────────┐
 │  SnapKitty GitLab Connector  :4700                    │
 │  GitLab Webhook → ROBOB → Frankenstein workflow       │
 │    Brain (Claude Sonnet 4.6) → Hands (FAISS+Neo4j)   │
 │    → Legs (Granite Code 3B, RTX 3080) → Review       │
 │  https://github.com/SNAPKITTYWEST/snapkitty-gitlab    │
 └────────────────────────────────────────────────────────┘
```

---

## Quick Start

```bash
mix setup
mix phx.server
# → http://localhost:4000
```

---

## Languages

| Tab | Runtime | Default |
|---|---|---|
| ELIXIR | `Code.eval_string/1` in BEAM sandbox | Hello, sovereign |
| NX ARRAYS | Nx tensor ops + APL-style broadcasting | phi contraction sequence |
| J | J Language via `jRunner` (optional install) | Fibonacci fork |

---

## Features

### BOB AI Sidebar
- **COMPLETE** — extends your code with sovereign reasoning
- **EXPLAIN** — explains what the code does in any language
- **REPAIR** — fixes runtime errors (active when error panel shows)
- **CATCODE** gate screens every BOB response before display
- Every BOB response + verdict is WORM-sealed

### ⬡ GITLAB Live Feed
Real-time Frankenstein pipeline results streamed from the SnapKitty GitLab connector:

- Pipeline events appear instantly via Phoenix PubSub — no polling
- **Brain** output (purple) — Claude Sonnet 4.6 architect spec
- **Legs** output (cyan) — Granite Code 3B local GPU execution
- **Review** verdict (green) — PASS / WARN / BLOCK
- Event badge on tab shows live count
- Every event WORM-sealed to DETS ledger on arrival

### WORM Chain
- DETS-backed append-only ledger at `priv/worm-ledger.dets`
- SHA-256 DJB2 seal IDs
- Sidebar shows last 5 seals with action labels

---

## GitLab Pipeline Integration

Wire the [SnapKitty GitLab Connector](https://github.com/SNAPKITTYWEST/snapkitty-gitlab):

```bash
# snapkitty-gitlab .env
ABZU_URL=http://localhost:4000
ABZU_SECRET=sovereign-abzu-bridge
```

ABZU receives:
```
POST /api/pipeline_event
X-Sovereign-Sig: <sha256(secret:ts:body)[0:16]>
X-Sovereign-Ts:  <unix ms>
```

**Test manually:**
```bash
curl -X POST http://localhost:4000/api/pipeline_event \
  -H "Content-Type: application/json" \
  -H "X-Sovereign-Sig: test" \
  -H "X-Sovereign-Ts: $(date +%s)000" \
  -d '{
    "worm_hash": "abc123test",
    "payload": {
      "pipeline": "mr-review",
      "event": "Merge Request Hook",
      "context": {"repo": "my-repo", "branch": "feature/sovereign"},
      "result": {
        "final_out": "APPROVE — all sovereign checks passed",
        "steps": [
          {"step": "BRAIN", "output": "Architect spec...", "ms": 12000},
          {"step": "LEGS",  "output": "fn review() { ... }", "ms": 800}
        ]
      }
    }
  }'
```

Click the **⬡ GITLAB** tab — the event appears live.

---

## Environment Variables

| Variable | Default | Description |
|---|---|---|
| `BOB_ENDPOINT` | — | BOB AI backend (Bedrock proxy) |
| `ABZU_BRIDGE_SECRET` | `sovereign-abzu-bridge` | Shared secret for GitLab push sig |

---

## Stack

- **Elixir / OTP / Phoenix LiveView** — real-time UI, zero JS state
- **Phoenix PubSub** — instant broadcast to all IDE sessions
- **Nx** — tensor operations, APL-style array language on the BEAM
- **J Language** — ASCII APL, fork-style math verbs
- **Monaco Editor** — VS Code engine in the browser
- **DETS** — Erlang native disk storage for WORM ledger
- **BOB + CATCODE** — sovereign reasoning + integrity screening
- **Frankenstein** — Brain/Hands/Legs/Review workflow at `:4300`

⬡ Ω ↺ Ψ Δ Λ Σ Φ α
