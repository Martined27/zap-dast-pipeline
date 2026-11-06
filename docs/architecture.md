# Architecture & Pipeline Design

`zap-dast-pipeline` runs **OWASP ZAP** as a stateless, one-shot container driven declaratively by the **ZAP Automation Framework** (`-cmd -silent -autorun`).

```mermaid
flowchart LR
    subgraph Env["Environment / CI"]
        VARS[".env / CI Inputs<br/>(TARGET_URL, Credentials)"]
    end

    subgraph Runner["Stateless ZAP Container (zap-dast-pipeline)"]
        EP["entrypoint.sh<br/>1. Wait for target<br/>2. POST /rest/user/login -> JWT"]
        RENDER["run-plan.sh<br/>Scoped envsubst -> /tmp/plan.yaml"]
        ZAP["zap.sh -cmd -silent -autorun<br/>1. replacer (Bearer JWT)<br/>2. requestor (API seeds)<br/>3. spider + spiderAjax<br/>4. passiveScan-wait<br/>5. activeScan<br/>6. HTML + JSON reports"]
        NOTIFY["notify-webhook.sh<br/>Alert only if High >= 1"]
    end

    subgraph Target["Local Docker / Staging Target"]
        JS["OWASP Juice Shop (:3000)<br/>or Custom TARGET_URL"]
        DVGA["DVGA GraphQL (:5013)"]
    end

    VARS --> EP
    EP --> RENDER
    RENDER --> ZAP
    ZAP <-->|"Authenticated HTTP"| JS
    ZAP <-->|"Seeded POST /graphql"| DVGA
    ZAP --> NOTIFY
```

## Key Design Decisions

1. **Declarative Automation Framework YAML (No Daemon / REST API Orchestration):**
   Instead of starting ZAP in daemon mode and polling its REST API from external Python/Bash scripts, the entire scan lifecycle is declared in `plans/scan-juice-shop.yaml` and executed in a single `zap.sh -cmd -silent -autorun` invocation.
2. **Pre-installed Add-ons + `-silent` Startup:**
   ZAP's default startup checks the online marketplace for add-on updates, which can stall or hang headless CI runs. `Dockerfile` runs `scripts/install-addons.sh` during `docker build` to bake in `automation`, `spiderAjax`, `reports`, `replacer`, `graphql`, and `requestor`, and always invokes ZAP with `-silent`.
3. **Scoped `envsubst` Rendering:**
   `scripts/run-plan.sh` passes an explicit variable allowlist (`${TARGET_URL}`, `${ZAP_AUTH_HEADER_VALUE}`, etc.) to `envsubst` so ZAP's internal template tokens survive untouched.
4. **Signal-Over-Noise Webhook Alerting:**
   `scripts/notify-webhook.sh` parses the generated `traditional-json` report with `jq` and only posts to `WEBHOOK_URL` when `riskcode >= 3` (High) findings exist.
