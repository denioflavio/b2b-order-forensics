-- Required binds: :order_id, :session_id, :correlation_id, :from_ts, :to_ts, :max_rows.
select event_at, source_type, event_type, severity, order_id, apex_session_id,
       correlation_id, component_name, summary, detail_excerpt
  from app_demo.bf_v_incident_timeline
 where (:order_id is null or order_id = :order_id)
   and (:session_id is null or apex_session_id = :session_id)
   and (:correlation_id is null or correlation_id = :correlation_id)
   and event_at >= case when :from_ts is null then systimestamp - interval '7' day
                        else to_timestamp_tz(:from_ts, 'YYYY-MM-DD"T"HH24:MI:SSTZH:TZM') end
   and event_at < case when :to_ts is null then systimestamp
                       else to_timestamp_tz(:to_ts, 'YYYY-MM-DD"T"HH24:MI:SSTZH:TZM') end
 order by event_at, source_type, event_type
 fetch first least(greatest(coalesce(:max_rows, 200), 1), 500) rows only;
