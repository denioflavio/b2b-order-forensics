# Idempotent checkout variant

This separate variant fixes repeated purchase intention processing while keeping the original defective laboratory intact. The original source is still under database/ and applications/b2b-order-forensics at repository root.

## Contract

BF_ORDER_PKG keeps its public signatures. A key belongs to its original customer, user and APEX session. An authorized replay returns the same order ID. BF_ORDER has a UNIQUE constraint on REQUEST_HASH; the intention row lock serializes creation, and the existing order row lock serializes processing. BF_SUBMISSION_ATTEMPT records each accepted receipt with a fresh correlation, separately from BF_ORDER.

RECEIVED may be processed once; COMPLETED is returned without dispatch; ERROR cannot be automatically processed again. A new purchase has a new key even when its contents are equal. REQUEST_HASH is a generated intention identifier, despite the historic column name. Clients cannot replace the saved snapshot through receive_attempt.

The checkout retains the controlled second POST so the same demonstration exercises the fixed boundary. BF_CART_PKG reuses the returned order rather than finding or creating attempt number two. BF_APP_CONFIG supplies the application's allowed ID; package source no longer hard-codes 107.

The integration is simulated. Autonomous telemetry is not a transactional outbox. This fix does not establish exactly-once delivery to an external system across crashes; that requires a separate delivery protocol and recipient idempotency.

## Install into an isolated empty schema

Use the versions and external APEXLang prerequisites described in the root laboratory guide. The sample target is APP_DEMO_IDEM, workspace APEXFROMTHEFIELD, alias B2B_FORENSICS_IDEM. Never point these scripts at APP_DEMO.

1. Review database/provision.sql. It creates a schema without authentication, assigns a bounded tablespace quota and associates it with the workspace. It refuses an existing schema. Run as your authorized installation administrator.
2. Run database/install.sql. It refuses existing BF objects; creates reference data only; checks compilation. No MCP grants are added and no password is distributed.
3. Allocate an unused application ID using APEX_APPLICATION_INSTALL.GENERATE_APPLICATION_ID and record GET_APPLICATION_ID in the same session. Check for collisions again before import.
4. Set that ID in applications/b2b-order-forensics-idem/deployments/default.json and the matching UX contract, then insert one row in APP_DEMO_IDEM.BF_APP_CONFIG with CONFIG_ID=1 and APPLICATION_ID equal to the allocated ID. The author's sample is 101; do not assume it is free elsewhere.
5. Strict-format and validate APEXLang, audit compiler truth, run live apex validate, and obtain explicit post-check import approval. Import in the same authenticated SQLcl session. Use APEXLang source, never patched generated SQL.
6. Log in using your own workspace APEX account. The original and corrected apps use separate schemas and session collections.

DDL is not atomic. Inspect partial installations instead of rerunning blindly. No automatic drop/reset path is provided. If the app already exists, preserve a recoverable export before any update.

## Reproduce tests

Using a saved administrative SQLcl connection, run database/tests/idempotency.sql. It appends synthetic records only to APP_DEMO_IDEM, restores the previous scenario selector and asserts sequential replay, different keys, authorization, database uniqueness and original error behavior.

Run the concurrent test from the repository root:

```bash
python3 variants/idempotent/database/tests/concurrency.py --connection YOUR_SAVED_INSTALL_CONNECTION --output verification/concurrency
```

It creates one new synthetic intention and opens two real SQLcl connections using the same authorized logical identity. One connection holds the intention lock for five seconds. The test requires overlapping database intervals, matching returned IDs, one order, two attempt records and one simulated dispatch. Logs stay local and should not be committed. SQLcl concurrency is not evidence of browser-session concurrency.

Complete the buyer flow, navigation, authorization, keyboard and narrow viewport checks in the actual browser before claiming UI acceptance. An automated package test cannot substitute for those observations.

## Tested release and limits

On September 20, 2026 the author tested this variant with APEX 26.1.4 and Oracle Database 26ai. A fresh isolated schema installation, sequential package suite, direct uniqueness assertion and overlapping two-connection SQLcl test passed. Browser checks covered controlled replay, new purchases, error preservation, cart operations, invalid quantities, refresh/back/forward, signed-URL tampering and a 390x844 checkout. Cart isolation passed with authenticated Chrome/Safari contexts and alternating reloads. These are scoped checks, not a complete accessibility audit or a separate-user browser authorization test.

The original laboratory remains unchanged, including its deliberate duplicate-order behavior and empty-quantity UI defect. The corrected variant also repairs invalid empty quantity and checkout-button visibility. Separate user/session package checks are retained. No real external delivery or payment was tested; crash-safe exactly-once integration is outside this lab.

Releases: [original](https://github.com/denioflavio/b2b-order-forensics/tree/post-2-before), [corrected distribution](https://github.com/denioflavio/b2b-order-forensics/tree/post-2-after), [changes](https://github.com/denioflavio/b2b-order-forensics/compare/post-2-before...post-2-after). Runtime logs, order data and editorial screenshots are intentionally excluded. The tags identify source snapshots; they do not assert an independent historical deployed-byte audit.
