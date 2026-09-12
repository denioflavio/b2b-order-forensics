-- Required binds: :order_id, :session_id, :correlation_id, :from_ts, :to_ts, :max_rows.
-- This is a neutral JSON evidence projection; it does not assign a cause.
select app_demo.bf_incident_pkg.evidence_bundle(
         p_order_id => :order_id,
         p_session_id => :session_id,
         p_correlation_id => :correlation_id,
         p_from_timestamp => case when :from_ts is null then systimestamp - interval '7' day
                                  else to_timestamp_tz(:from_ts, 'YYYY-MM-DD"T"HH24:MI:SSTZH:TZM') end,
         p_to_timestamp => case when :to_ts is null then systimestamp
                                else to_timestamp_tz(:to_ts, 'YYYY-MM-DD"T"HH24:MI:SSTZH:TZM') end,
         p_max_rows => least(greatest(coalesce(:max_rows, 200), 1), 500)
       ) evidence_bundle
  from dual;
