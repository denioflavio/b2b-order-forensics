# B2B Order Forensics

An experimental Oracle APEX laboratory for a three-part series about AI-assisted incident investigation with VS Code and Codex. Claude Code is an alternative for the same evidence-first method, not a separately verified demonstration.

[Download the public source](https://github.com/denioflavio/b2b-order-forensics) or clone it:

```bash
git clone https://github.com/denioflavio/b2b-order-forensics.git
```

## What is included

- Database DDL: 11 tables and three evidence views.
- PL/SQL packages for orders, the session cart, logging, lab preparation and read-only evidence.
- APEXLang source for Home, My Orders, Products & Cart, Checkout, Order Details and authentication.
- A fictional ACME company and eight computer products, seeded without purchases.
- Parameterized investigation queries and reader-grant verification.
- Physical application specification and UX contract for the APEXLang workflow.

The application contains deliberate defects. It is not a production reference architecture, a complete storefront, or an autonomous remediation system. Integration is simulated. All source is available, including fault preparation; do not supply that preparation code as initial context when repeating an evidence-first investigation.

## The series

1. **The Incident Is the Prompt** — connect a support screenshot to runtime evidence, a backtrace and the relevant source.
2. **One Click, Two Orders** — distinguish repeated purchase intention from merely similar successful orders.
3. **The Missing Log Proves Nothing** — evaluate competing explanations when evidence is incomplete.

The articles remain editorial work in progress and are not included in the source distribution. The first awaits the author's recorded VS Code investigation; no timing benchmark or independent discovery is claimed.

## Installation and security

Read the [laboratory guide](docs/public-lab-guide.md) before running any SQL. The source targets APP_DEMO and application 107 as sample identifiers. Do not overwrite another application or run this in production.

Fresh installation requires a prepared APEX schema, an empty B2B namespace and separately provisioned BF_MCP_RO / BF_MCP_EVIDENCE_ROLE. It does not recreate the schema or delete previous data. The application requires compatible external APEXLang tooling; no compiler or generated Builder export is bundled. Validate live and obtain explicit import approval before deploying.

The Built-in SQL Toolset remains available, with evidence access restricted by database grants. Generic-query row/time limits are procedural, not a security guarantee supplied by MCP. Never give the investigator the administrative installation connection.

## Status and limitations

The source was deployed in the author's lab and used for recorded browser purchases: success, real overflow, pre-integration failure and controlled retry. Confirmation refresh was also checked. A fresh deployment from this public bundle, complete mobile/keyboard acceptance and concurrent-session testing have not been certified.

The checkout can retain its submit button after failure. Logging can fail silently. Good instrumentation does not imply good error handling, and absence of a log is not proof of absence of execution. See the guide for other limitations.

Distributed under the MIT license. No credentials, wallet, existing orders, raw logs or private editorial material are included.
