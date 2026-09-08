# Contentful-Specific Security Patterns

Threat patterns specific to the Contentful platform and the Tundra stack (extensibility-api, APS, app proxy, Cloudflare Functions, CMA, Mastra). Each pattern maps to a threat category from `threat-categories.md`.

---

## Tenant isolation in multi-tenant operations

**Maps to threat category:** Authorization

**What:** The app authorization SDK uses a DynamoDB-backed token cache with composite keys (`userId#spaceId#environmentId#appDefinitionId`) to ensure a token fetched for one user cannot be served to another user or to a different tenant's space.

**Why it matters:** Omitting `userId` from the composite key collapses tenant isolation — a single app definition's token can be served across all users, an Authorization failure.

**Vulnerability shape:** A server-side backend that constructs a `TokenContext` without `userId` creates a shared token bucket keyed only on `spaceId#environmentId#appDefinitionId`. Any request for that app definition within those scoping dimensions receives the first user's token. Under concurrent load, this means User A's CMA token is transparently served to User B.

**Code patterns to flag:**
- `TokenContext` constructed without `userId` on any server-side (multi-tenant) backend
- In-process LRU cache layer above the SDK that ignores `expires_at` — serves expired tokens that the DynamoDB TTL would have evicted
- Any alternative token caching backend (Cloudflare Durable Objects, session storage) that does not replicate the full composite key structure

**Mitigations available:**
- Use the canonical `userId#spaceId#environmentId#appDefinitionId` composite key for every multi-tenant token cache; reject `TokenContext` construction with a missing `userId` at the type/runtime layer
- Honor `expires_at` on every cache layer above the SDK; do not introduce a wrapper cache that bypasses TTL eviction

---

## Multi-region data handling (US/EU)

**Maps to threat category:** Data Exposure

**What:** Contentful operates in US (us-east-1) and EU (eu-west-1) regions; AWS Secrets Manager secrets are region-scoped, and Kubernetes pod rollouts happen independently per region. The app framework and functions dispatch layer must not cross-region route requests that contain region-specific customer data.

**Why it matters:** Routing EU customer data through US infrastructure without consent is a data sovereignty failure with regulatory implications; it is a Data Exposure risk in the Contentful threat model.

**Vulnerability shape:** A new service that retrieves secrets from a hardcoded `us-east-1` endpoint while serving EU-region traffic either fails at runtime (wrong secret) or succeeds by retrieving a cross-region credential that was not provisioned for that region. A service that caches responses in a shared layer without region partitioning can serve US-tenant content to EU API callers.

**Code patterns to flag:**
- AWS SDK client initialized with a hardcoded region string (`us-east-1`) in a service deployed multi-region
- Shared response cache or DynamoDB table without a region partition key or per-region table configuration
- Terraform secrets module that does not include `regions_to_replicate_to` — secret not provisioned in EU region

**Mitigations available:**
- AWS SDK clients use `AWS_REGION` environment variable, not a hardcoded string
- Terraform secrets modules include `regions_to_replicate_to` for all secrets used in multi-region services
- Shared response caches partition by region (region key in DynamoDB, region-prefixed cache key)

**Reference incidents:** No Tundra-internal data-sovereignty incidents surfaced in the 24-month research window. Pattern sourced from AWS Secrets Manager runbook and multi-region deployment conventions.

---

## App-installation auth (X-Contentful-App-Definition-Id, agent registration on App Definitions)

**Maps to threat category:** Authorization

**What:** Apps installed into a Contentful space identify themselves using the `X-Contentful-App-Definition-Id` header. The app proxy validates this header to route requests and apply per-app authorization. Agent registration against an App Definition is the mechanism by which an AI agent claims app identity — the APS delegation flow grants a CMA-scoped token for that app's scope.

**Why it matters:** If the app definition ID header can be spoofed or if the app proxy does not validate it against the caller's authenticated session, a malicious app can impersonate a different app and receive its delegated token scope — an Authorization failure.

**Vulnerability shape:** An app proxy middleware that trusts `X-Contentful-App-Definition-Id` without cross-referencing the caller's installation record allows any authenticated caller to claim any installed app's identity. An agent that registers against an App Definition it does not legitimately own can acquire delegated CMA tokens for that app's spaces and environments.

**Code patterns to flag:**
- App proxy route handler that reads `X-Contentful-App-Definition-Id` without validating it against the caller's authenticated installation context
- Agent registration path that accepts an `appDefinitionId` claim without verifying the requesting agent is the authorized owner of that definition
- `TokenManager.getToken()` called with a `userId` derived from the `X-Contentful-App-Definition-Id` header rather than from the verified session

---

## CMA token scoping (space/environment scope, organization tokens, scoped delegation)

**Maps to threat category:** Secrets & Credentials / Blast Radius

**What:** Contentful Management API (CMA) tokens come in three forms: personal access tokens (org-scoped, full access), app-scoped tokens (space/environment scoped, issued via APS delegation), and organization tokens (org-admin level, used for management operations). The risk gradient is: personal/org tokens have the broadest access; delegation tokens are scoped to specific spaces and environments.

**Why it matters:** An agent or MCP session running with an org-admin CMA token has write access across all spaces — if compromised by prompt injection or credential theft, the blast radius is the entire organization. This is a Secrets & Credentials + Blast Radius failure.

**Vulnerability shape:** The Contentful MCP server accepts a CMA token at startup (via environment variable or user-provided credential). If the user provides an org-admin token, the server has no mechanism to warn about or refuse the over-permissioned credential. A prompt injection or tool-boundary violation in that session can modify or delete content across all spaces without further authentication.

**Code patterns to flag:**
- MCP server or agent harness that accepts a CMA token without checking its scope at startup — org-admin tokens accepted silently for read-only use cases
- Delegated token flow that uses a long-lived personal access token as the trust anchor rather than the user's session token — no expiry enforcement
- `TokenContext` `appDefinitionId` field hardcoded to a system value rather than derived from the verified app installation record

**Mitigations available:**
- Use scoped delegation tokens (APS token exchange) for all server-side app operations; never embed org-admin CMA tokens in agent environments
- Validate token scope at agent startup; warn (or refuse) when token scope exceeds what the operation requires

---

## Webhook signature validation

**Maps to threat category:** Input Validation

**What:** Contentful webhooks dispatch HTTP requests to caller-configured endpoints. Webhook payloads can carry Contentful content including user-authored field values. The Contentful webhook system supports HMAC signature headers that allow the receiving endpoint to verify the request originated from Contentful and was not tampered in transit.

**Why it matters:** An endpoint that processes webhook payloads without verifying the signature accepts requests from any source — enabling replay attacks and injection of forged payloads that can trigger downstream business logic. This is an Input Validation failure.

**Vulnerability shape:** A webhook handler that trusts the `X-Contentful-Topic` and payload body without verifying the HMAC signature will process any POST request that matches the route — including requests from non-Contentful sources. Combined with the SSRF risk (an attacker who can register webhooks can point them at internal services), this creates a bidirectional attack surface: both forging incoming webhooks and weaponizing outgoing webhooks.

**Code patterns to flag:**
- Webhook handler that does not validate a shared-secret HMAC signature before processing the payload
- Webhook destination URL accepted without validation against a scheme/destination allowlist (SSRF vector)
- Webhook transformation expression that processes user-supplied payload field values without recursion depth or CPU time limits (INC-350 pattern)

---

## Internal API patterns (extensibility-api auth flows)

**Maps to threat category:** Authorization

**What:** The extensibility-api is the internal backbone for app installation management, AppAction invocation, and APS policy enforcement. It sits behind the Contentful API gateway and inherits authentication from the gateway, but applies its own authorization layer via APS. New AI platform capabilities (agent registration, delegation token exchange) are added to this API surface.

**Why it matters:** New endpoints added to the extensibility-api that inherit authentication middleware but not the full APS authorization layer create the ServiceNow CVE-2025-12420 failure pattern — unauthenticated or under-authorized access to AI platform functions. This is an Authorization failure.

**Vulnerability shape:** An AI platform endpoint added on a faster development cycle than established extensibility-api routes may skip the APS policy check that governs per-app, per-space access. The endpoint may be authenticated (CMA token required) but not authorized (no check that the caller has access to the specific app definition or space being operated on). In a multi-tenant API, authentication without per-object authorization is structurally equivalent to BOLA (OWASP-API01).

**Code patterns to flag:**
- New extensibility-api route handler that calls authentication middleware but has no APS policy lookup before returning data or executing an operation
- APS policy file (`lib/stores/policies/app/`) modified without integration tests covering the affected access patterns — regressions are invisible to unit tests (INC-633 pattern)
- `subjectId` passed to APS without asserting the expected string format — exact-match prefix mismatch silently denies rather than falling back (2026-01 AppActionCall creation failure pattern)

**Reference incidents:** INC-633 (2025-09) — APS policy tightening broke Merge App exports; 30-hour detection gap. 2026-01 Slack incident — `subjectId` prefix mismatch broke AppActionCall creation in delegated auth path. ServiceNow CVE-2025-12420 — AI platform API skipped identity validation; CVSS 9.3.
