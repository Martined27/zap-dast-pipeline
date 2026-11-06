# Authentication Notes — SPA & Bearer JWT Handling in ZAP

## The Problem with SPA JSON Authentication in DAST

OWASP Juice Shop (like most modern Angular/React SPAs) authenticates via a JSON endpoint:

```http
POST /rest/user/login HTTP/1.1
Content-Type: application/json

{"email":"zap-scanner@example.com","password":"ZapScanner!2026"}
```

Which returns a signed JWT inside a nested JSON object:

```json
{
  "authentication": {
    "token": "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...",
    "bid": 6,
    "umail": "zap-scanner@example.com"
  }
}
```

### Approaches Evaluated

| Approach | How It Works | Outcome / Tradeoff |
| :--- | :--- | :--- |
| **1. ZAP `jsonBasedAuthentication` inside context** | Configure ZAP context with `loginRequestUrl`, `loginRequestBody`, and session management. | Fragile for nested token paths (`.authentication.token`) when combined with `spiderAjax` headless browser threads, and requires extra session-management scripts to map the token into an `Authorization: Bearer` header. |
| **2. Pre-scan token acquisition in `entrypoint.sh` + ZAP `replacer` job (Selected)** | `entrypoint.sh` registers/logs in the test user via `curl`, extracts `.authentication.token` via `jq`, exports `ZAP_AUTH_HEADER_VALUE="Bearer <token>"`, and the Automation Framework `replacer` job injects `Authorization: Bearer <token>` on every request matching `${TARGET_URL}.*`. | **Deterministic, zero-config across both `spider`, `spiderAjax`, `requestor`, and `activeScan`.** Works identically for pre-issued CI tokens (`ZAP_AUTH_HEADER_VALUE`) and dynamic login endpoints (`AUTH_LOGIN_URL`). |

## Seeding Authenticated API Routes (`requestor` Job)

Even with a valid `Authorization` header attached to every request, a pure HTML spider on an Angular SPA won't immediately trigger all XHR data endpoints unless the UI state is driven through every view.

To guarantee deterministic coverage of authenticated API surfaces on every run, `plans/scan-juice-shop.yaml` pairs `spider` + `spiderAjax` with a `requestor` job that seeds key REST routes directly into ZAP's history tree before `activeScan` begins:
- `GET /rest/user/whoami`
- `GET /rest/products/search?q=apple`
- `GET /api/Products`
- `GET /rest/basket/1`
- `GET /api/Feedbacks/`
