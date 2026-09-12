-- Required binds: :order_id, :order_number, :from_ts, :to_ts, :max_rows.
select order_id, order_number, status, total_amount, created_at,
       checkout_at, apex_session_id, correlation_id, request_hash,
       error_count, integration_count, duplicate_order_count
  from app_demo.bf_v_order_health
 where (:order_id is null or order_id = :order_id)
   and (:order_number is null or order_number = :order_number)
   and created_at >= case when :from_ts is null then systimestamp - interval '7' day
                          else to_timestamp_tz(:from_ts, 'YYYY-MM-DD"T"HH24:MI:SSTZH:TZM') end
   and created_at < case when :to_ts is null then systimestamp
                         else to_timestamp_tz(:to_ts, 'YYYY-MM-DD"T"HH24:MI:SSTZH:TZM') end
 order by created_at desc
 fetch first least(greatest(coalesce(:max_rows, 100), 1), 500) rows only;
