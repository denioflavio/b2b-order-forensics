# Running the experimental laboratory

This is source for an intentionally defective demonstration, not a production application. No cloud infrastructure, credentials, wallet, personal data or existing purchases are distributed. Your generated order IDs will differ from the article's IDs.

## Prerequisites and installation boundaries

The author's deployment used Oracle AI Database 26ai, APEX 26.1.4 and SQLcl 26.1.2 with Java 21. APEXLang source uses metadata version 26.1.0+3102. Other runtime versions have not been certified. APEXLang tooling is an external prerequisite, not vendored here. Database DDL and PL/SQL can be read independently of that tooling.

Use an isolated disposable APEX environment. The source targets workspace APEXFROMTHEFIELD, parsing schema APP_DEMO, alias B2B_FORENSICS and application ID 107. These are sample deployment identifiers, not access details for the author's environment. Check conflicts before adopting them. Adapting identifiers requires consistent changes across the SQL, APEXLang deployment configuration and contracts; do not overwrite an existing application.

Have your DBA provision APP_DEMO for APEX in that environment and a dedicated BF_MCP_RO account with zero quota and only CREATE SESSION, plus the empty role BF_MCP_EVIDENCE_ROLE assigned as its default role without delegation. Supply passwords through your organization's secure process, not source files or shell arguments. Do not assign broad CONNECT/RESOURCE/administrative roles as a shortcut. Provisioning credentials is deliberately not automated in this distribution.

The installer expects the role and reader to exist. It must run under an authorized installation account with the necessary APP_DEMO DDL, grants and dictionary access. It sets CURRENT_SCHEMA; that setting does not reduce the installer's privileges. The investigated database identity is separate from this administrator.

In SQLcl, authenticate securely to your own saved installation connection, change to the downloaded database directory, review install.sql and then invoke:

```sql
@install.sql
```

This is a fresh-install script, not an upgrade or reset. It refuses an occupied B2B namespace and does not call a drop script. It creates 11 tables, three views and five packages, grants three SELECTs and one EXECUTE to the evidence role, and seeds one synthetic company and eight products, with no purchases. It runs object/data verification and the reader privilege audit. DDL is not rolled back atomically: if installation fails, inspect the partial state and recover under DBA control. No destructive cleanup automation is included in this release.

The privilege audit checks this lab's explicit grants and quotas. It does not prove every possible privilege inherited through PUBLIC or every production security property. Review effective access in your own environment. Never connect an agent through the installation administrator.

## APEXLang application

Application source is under applications/b2b-order-forensics; physical specification and UX contracts are under .apexlang. Review deployment/defaults in the application before generation or validation. Use a compatible APEXLang compiler, strict formatting, grammar/UX/reference validation and compiler-truth audit, followed by live SQLcl apex validate. Import only after a successful live check and explicit approval, in the same authenticated SQLcl session. Preserve a pre-import backup for any existing application. Do not manually edit generated APEX SQL to implement changes.

No installation or import is performed by cloning this repository. The repository does not include the APEXLang compiler or generated APEX Builder export. The source snapshot was deployed in the author's laboratory; a clean installation from this public bundle has not yet been replayed in another environment.

## Try the buyer flow

Log in with your own APEX Accounts user. Open Products & Cart, add products, change quantities or remove a line, review the order and click Place order. The commercial reference exists before processing. Check My Orders and Order Details after a successful purchase. The integration is simulated; no real order or payment is sent.

The administrator-only lab selector chooses once per purchase intention: success with probability 1/2, or overflow, missing delivery configuration, and retry with probability 1/6 each. The default is RANDOM. Controlled modes CLEAN, OVERFLOW, PRE_INTEGRATION and RETRY support deterministic preparation. They are not buyer options. If an administrator changes the global selector for a test, coordinate users and restore RANDOM afterward. Do not change it through the MCP identity. Reading BF_LAB_PKG reveals these mechanisms; exclude it and editorial solutions from an investigator's initial context.

The retry scenario uses application-controlled resubmission, not cloned rows or proof of a human double click. A confirmation refresh should not create a new attempt. Independent concurrent-session validation is still required before claiming concurrency acceptance.

## Read-only evidence

The existing Built-in SQL Toolset can submit SQL and PL/SQL; the evidence account's grants, not the tool name or prompt, prevent access to the business mutations in this lab. Use only BF_V_ORDER_HEALTH, BF_V_INCIDENT_TIMELINE, BF_V_ERROR_PATTERN_SUMMARY and BF_INCIDENT_PKG. The evidence package is definer-rights and must remain reviewed and read-only.

Query templates are under database/queries. Set every required bind before running them, using your new order IDs and a bounded incident window. Keep a maximum of 500 rows and seven days; limits on generic queries remain procedural. BF_INCIDENT_PKG clamps rows but does not enforce a seven-day maximum. No BLOBs are exposed. Diagnostic excerpts can be truncated, and duplicate_order_count includes the current order (1 is not a duplicate).

Use an approval gate for tool calls, inspect effective identity, audit invocations and protect logs as sensitive data. Model-provider data policies, retention, prompt injection defenses, revocation and query-resource governance remain organization-specific responsibilities. No OAuth renewal or complete production hardening is claimed by this release.

## Known limitations

- A native database exception is deliberately exposed to the buyer; the checkout may retain Place order after failure. This is not recommended error UX.
- Logging uses autonomous transactions but can fail silently; absence of a row alone does not prove absence of execution.
- Recorded browser tests cover success, both exceptions, retry and confirmation refresh. Full mobile, keyboard and cross-session acceptance is not claimed.
- Improvements to validation, types and idempotency belong in separately tested fixes; this snapshot retains faults for investigation.
- No historic orders, raw verification logs, screenshots, editorial transcripts or solutions are shipped. Articles may refer to records that only existed in the author's lab.
