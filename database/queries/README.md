# Investigation query templates

These SELECT templates read the three granted evidence views and the read-only evidence API. They contain no business mutations. Their shapes are intended for MCP investigation and SQLcl reproduction; do not assume every template was executed in a recorded agent session.

Set every bind named in the file header before executing in SQLcl. Use your generated order reference and incident date, not the author's historical order IDs. Inspect timestamp formats and provide from/to values spanning at most seven days, with at most 500 rows. The scripts clamp row counts, but do not enforce the maximum interval between arbitrary supplied timestamps.

MCP must authenticate as BF_MCP_RO. An administrative SQLcl connection is only query-only by procedure when running these reviewed SELECTs, not read-only by database enforcement. Never expose that administrator as an agent fallback.

Start with 00_identity.sql. Continue with 20_order_health.sql and 10_incident_timeline.sql as appropriate, and 30_error_patterns.sql or 50_evidence_bundle.sql when needed. The package does not infer a root cause. Its default null time parameters do not establish a bounded window; supply explicit values.

Counts and excerpts have limits: duplicate_order_count includes the current order; timeline diagnostic excerpts may truncate text. Avoid broad queries and never interpret missing rows as conclusive proof.
