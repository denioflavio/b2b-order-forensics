-- Required binds: :from_ts, :to_ts, :pattern_code, :max_rows.
select period_hour, page_id, action_name, pattern_code, endpoint,
       occurrence_count, correlation_count, order_count
  from app_demo.bf_v_error_pattern_summary
 where period_hour >= case when :from_ts is null then systimestamp - interval '7' day
                           else to_timestamp_tz(:from_ts, 'YYYY-MM-DD"T"HH24:MI:SSTZH:TZM') end
   and period_hour < case when :to_ts is null then systimestamp
                          else to_timestamp_tz(:to_ts, 'YYYY-MM-DD"T"HH24:MI:SSTZH:TZM') end
   and (:pattern_code is null or pattern_code = :pattern_code)
 order by period_hour desc, occurrence_count desc
 fetch first least(greatest(coalesce(:max_rows, 100), 1), 500) rows only;
