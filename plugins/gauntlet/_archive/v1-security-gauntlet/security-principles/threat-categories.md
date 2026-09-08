# Security Threat Categories

Seven threat categories used by `security-review` and any other security-relevant skill. Each category maps to one or more lenses applied by `security-finder` (master spec §3.3).

---

## 1. Authentication (AuthN)

**The question this lens answers:** Who can call this code — are auth checks present, and are there bypass paths?

**Detection signals:**
- OAuth callback missing `state` validation
- JWT `aud` hardcoded to base URL, not the requesting `resource`
- AI/agent API endpoint skipping auth check before processing

**Common attack vectors:**
- OAuth CSRF via missing state
- Cross-server token reuse when audience is unbound (OWASP-A07)

**Mitigations:**
- Validate `state` on every OAuth callback; bind JWT `aud` to `resource` parameter
- Rate-limit middleware applied to auth route handler; token expiry set on every newly issued credential

**Tundra-stack specifics:** Contentful's Security Review Process (Phase 3) asks about Okta/Gatekeeper auth, token expiry, and lifecycle. APS token exchange and OAuth flows must validate state, bind audience, and enforce expiry. AI platform API additions must inherit established auth middleware — new AI features are a common site for auth regression.

**Reference incidents:** INC-984 — missing OAuth `state` created CSRF exposure. FastMCP 2026-03 (GHSA-5h2m-4q8j-pqpj) — static JWT `aud` enabled cross-server token reuse.

---

## 2. Authorization (AuthZ)

**The question this lens answers:** Can this caller access this specific resource — are per-object and per-function checks enforced?

**Detection signals:**
- APS `lib/stores/policies/app/` modified without integration tests on affected access patterns
- `subjectId` passed to APS without asserting expected string format
- Object returned without per-object authorization check

**Common attack vectors:**
- Policy change removing an implicit permission apps relied on
- APS subject-prefix mismatch causes silent deny (OWASP-A01, OWASP-API01)

**Mitigations:**
- Deny by default; check authorization on every user-supplied-ID retrieval
- Integration-test APS policy changes against exact subject format and the `app reads own AppActionCall` pattern

**Tundra-stack specifics:** APS lookups are exact-match on subject prefix — mismatch silently denies without fallback. Regressions are invisible to unit tests; authorization-error-rate alerting is required to detect them before 30-hour gaps.

**Reference incidents:** INC-633 — APS policy tightening silently broke Merge App exports (30-hr detection gap). Tundra Slack 2026-01 — `subjectId` prefix mismatch broke AppActionCall creation. ServiceNow CVE-2025-12420 — AI platform API skipped identity validation; CVSS 9.3. Marketplace INC-485 (2025-07) — Wiz-driven S3 bucket policy hardening accidentally blocked all OAuth traffic for the Jira marketplace app. Marketplace INC-497 (2025-07) — Wiz-driven S3/CloudFront/OAI change returned 403 for Optimizely/Slack apps; 4-day detection gap. Marketplace INC-621 (2025-09) — Fastly `x-contentful-org-id` header set to sentinel string `no_org_id` bypassed Traffic Manager override; platform-wide 401s for 51 minutes.

---

## 3. Input Validation

**The question this lens answers:** Is untrusted input validated before reaching interpreters or LLM contexts?

**Detection signals:**
- GitHub Actions interpolating user-controlled fields into LLM prompt with `allowed_non_write_users: "*"`
- Agent system prompt lacking "ignore embedded instructions" directive
- String interpolation in ORM/SQL calls instead of parameter binding

**Common attack vectors:**
- Indirect prompt injection via Jira bodies, CMS entries, tool responses (LLM01:2025)
- SQL/command injection via unsanitized input (OWASP-A05)

**Mitigations:**
- Parameterized queries (no string interpolation in ORM/SQL calls); HTML context → DOMPurify/escapeHtml; JSON context → `JSON.stringify` (no manual concatenation)
- Explicit anti-injection instruction in any agent system prompt that reads user-controlled content
- Flag any GitHub Actions combining `issues`/`pull_request` triggers with LLM shell tool access

**Tundra-stack specifics:** `invoke_ai_action` returning `nextStepsGuidance` as a directive string is a confirmed tool-to-AI injection vector. The `remote-mcp-server` AGENTS.md prompt injection guard is the correct pattern — mark it protected from revert.

**Reference incidents:** No Tundra-internal incidents in this category. See Cline "Clinejection" 2026-02 for the canonical indirect-injection-to-code-execution chain. DevEx 2026-03 — `X-Contentful-App-Definition-Id` header in agents-api is spoofable by any authenticated user (client-supplied identity claim accepted without server-side validation against actual app installations).

---

## 4. Secrets & Credentials

**The question this lens answers:** Are credentials stored correctly — never in source, never in LLM context, never over-permissioned?

**Detection signals:**
- Literal API key or bearer token in system prompt or agent instructions
- Secret passed in LLM tool-use schema string rather than resolved server-side
- `package.json` `overrides` block without dated comment and companion cleanup ticket

**Common attack vectors:**
- Over-permissioned long-lived OAuth refresh token compromised via third-party integration
- Prompt injection directing agent to read and transmit environment secrets (OWASP-A04)

**Mitigations:**
- Approved vaults only: AWS Secrets Manager (Terraform-provisioned) for runtime; CircleCI vault orb for CI/CD; never commit plaintext secrets
- Scope OAuth tokens to minimum necessary permissions with inactivity expiry; MCP sessions use scoped delegation tokens, not org-admin CMA tokens

**Tundra-stack specifics:** Canonical secrets pattern: 1Password → AWS Secrets Manager (`service_tag` + `namespace_types` scoped) → CircleCI vault orb. Secrets Manager K8s sync has no approval gate — a compromised secret reaches pods within minutes.

**Reference incidents:** No Tundra-internal credential breach incidents. Salesloft/Drift 2025 — over-permissioned long-lived OAuth tokens compromised via AppExchange; 700+ orgs over ~6 weeks undetected. DevEx 2026-04 — Inngest TypeScript SDK v3.22–v3.53.1 exposed `process.env` environment variables (including `OPENAI_API_KEY`, `INNGEST_SIGNING_KEY`) via PATCH/DELETE requests to the serve handler; agents-api production secrets rotated as precaution (CAP-391 companion: GitHub webhook secrets inadvertently included in HTTP delivery headers 2025-09 to 2026-01 across multiple repos including agents-api).

---

## 5. Data Exposure

**The question this lens answers:** Can this code surface PII, tokens, or internal details to unauthorized consumers, logs, or LLM contexts?

**Detection signals:**
- `error.stack`, internal paths, or SQL fragments in client-facing error response
- Agent harness logging full tool call input/output without credential-string redaction
- API response serializing full model object rather than allowlisted fields (OWASP-API03)

**Common attack vectors:**
- Verbose error responses leaking reconnaissance data
- Cross-agent data leakage via full message history pass-through (LLM02:2025)

**Mitigations:**
- Error responses sanitized of stack traces, internal paths, and SQL fragments before reaching clients
- Pass typed structured handoff artifacts between agents — not full message history; strip tool outputs from evaluator context
- Allowlist-based serialization: return only fields the caller's role may see

**Tundra-stack specifics:** Tundra's app hosting layer must redact PII and tokens from error outputs before surfacing to app developers. Multi-agent workflows use structured file-based handoffs to prevent cross-agent data leakage.

**Reference incidents:** No Tundra-internal data exposure incidents in the strict sense. See OWASP LLM02:2025 for the canonical agentic-context pattern. (Adjacent: Inngest SDK 2026-04 exposed env-vars via HTTP diagnostic response — see Secrets & credentials; classified there rather than here because the root cause is a credential storage/exposure failure, not a data serialization failure.)

---

## 6. Supply chain

**The question this lens answers:** Are dependencies and the build pipeline free of known CVEs, typosquatting artifacts, and unverifiable packages?

**Detection signals:**
- `package.json` listing single-char (`i`, `n`) or bare CLI-word (`npm`, `install`) package names — typosquatting artifacts (EXT-7405)
- `package.json` `overrides` block — invisible to Dependabot and `npm audit` (EXT-7409/EXT-7410)
- GitHub Actions with `pull_request_target`/`issues` trigger interpolating user-controlled fields into shell steps

**Common attack vectors:**
- Compromised package published to registry and installed by automated bump (OWASP-A03)
- CI cache poisoning via AI agent shell access + untrusted input (Cline pattern)

**Mitigations:**
- `npm ci` in all CI/CD; commit `package-lock.json`; `min-release-age=7d` in `.npmrc`; `npm audit --audit-level=high` + `npm audit signatures`
- `actions/dependency-review-action` as required status check; Wiz SBOM for runtime CVE triage
- Triage workflow: direct vs. transitive compromise → Wiz SBOM query → lockfile history → evidence classification

**Tundra-stack specifics:** Renovate is the org-standard dependency bot — do not run Renovate and Dependabot simultaneously. Wiz SBOM is the primary incident-response triage tool for deployed runtime versions.

**Reference incidents:** EXT-7409 (72 Dependabot alerts, 2 critical). EXT-7405 (typosquatting artifacts). EXT-6370, EXT-6601 (runtime Node CVEs). Cline "Clinejection" 2026-02 (CI cache poisoning).

---

## 7. Blast Radius

**The question this lens answers:** If this code fails or misbehaves, how many tenants or systems are affected — is scope bounded by per-tenant isolation controls?

**Detection signals:**
- Org-scoped endpoint fanning out N×M downstream calls without per-tenant rate limiting
- Webhook transformation code processing user-supplied expressions without recursion depth limits
- `TokenContext` constructed without `userId` on a server-side multi-tenant backend

**Common attack vectors:**
- Single heavy tenant exhausting shared-shard resources (thundering herd)
- Unbound recursive expression loop starving queue consumer across entire shard

**Mitigations:**
- Per-tenant rate limiting and circuit breaking on org-scoped fan-out endpoints
- Recursion depth limits and CPU time bounds on user-supplied transformation expressions
- `userId#spaceId#environmentId#appDefinitionId` composite keys for multi-tenant token caches — omitting `userId` collapses tenant isolation (app-authorization-sdk-dynamodb canonical pattern)

**Tundra-stack specifics:** INC-1276: `staleTime: 0` React Query hooks + no per-tenant rate limit on app-installation fan-out allowed one org to DoS all tenants on shard 79 (~51 min). INC-350: one customer's webhook expression triggered an unbound recursive loop, causing queue message loss across shard 392. Both were non-adversarial — blast-radius review applies equally to accidental and intentional scenarios.

**Reference incidents:** INC-1276 — thundering-herd fan-out, extensibility-api 502s across shard 79. INC-350 — unbound recursive webhook loop, queue message loss across shard 392.
