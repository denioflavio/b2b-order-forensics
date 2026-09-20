create or replace view bf_v_incident_timeline as
select a.event_at,
       'ACCESS' source_type,
       'PAGE_ACCESS' event_type,
       'INFO' severity,
       a.order_id,
       a.apex_session_id,
       a.correlation_id,
       'APEX_PAGE_' || to_char(a.page_id) component_name,
       'Page ' || to_char(a.page_id) || ' request ' || a.request_value summary,
       cast('User: ' || a.app_user as varchar2(1000)) detail_excerpt
  from bf_access_log a
union all
select d.event_at,
       'DEBUG',
       case when d.component_name = 'ORDER.STATE' then 'STATE_TRANSITION' else 'DEBUG_EVENT' end,
       d.log_level,
       d.order_id,
       d.apex_session_id,
       d.correlation_id,
       d.component_name,
       d.message_text,
       cast(dbms_lob.substr(d.context_json, 1000, 1) as varchar2(1000))
  from bf_debug_event d
union all
select e.event_at,
       'ERROR',
       'DATABASE_ERROR',
       'ERROR',
       e.order_id,
       e.apex_session_id,
       e.correlation_id,
       e.action_name,
       to_char(e.sql_code) || ': ' || e.sql_error_message,
       cast(dbms_lob.substr(e.error_backtrace, 600, 1) || chr(10) ||
            dbms_lob.substr(e.error_stack, 400, 1) as varchar2(1000))
  from bf_error_log e
union all
select i.event_at,
       'INTEGRATION',
       'HTTP_RESPONSE',
       case when i.http_status >= 400 or i.business_code not in ('0', 'SUCCESS') then 'ERROR' else 'INFO' end,
       i.order_id,
       i.apex_session_id,
       i.correlation_id,
       i.endpoint,
       'HTTP ' || to_char(i.http_status) || coalesce(' / business ' || i.business_code, ''),
       substr(coalesce(i.business_message, i.response_excerpt), 1, 1000)
  from bf_integration_log i;

create or replace view bf_v_order_health as
with error_counts as (
  select order_id, count(*) error_count
    from bf_error_log
   group by order_id
), integration_counts as (
  select order_id,
         count(*) integration_count
    from bf_integration_log
   group by order_id
), duplicate_counts as (
  select request_hash, count(*) duplicate_order_count
    from bf_order
   where request_hash is not null
   group by request_hash
)
select o.order_id,
       o.order_number,
       o.status,
       o.total_amount,
       o.created_at,
       o.checkout_at,
       o.apex_session_id,
       o.correlation_id,
       o.request_hash,
       nvl(e.error_count, 0) error_count,
       nvl(i.integration_count, 0) integration_count,
       nvl(d.duplicate_order_count, 0) duplicate_order_count
  from bf_order o
  left join error_counts e on e.order_id = o.order_id
  left join integration_counts i on i.order_id = o.order_id
  left join duplicate_counts d on d.request_hash = o.request_hash;

create or replace view bf_v_error_pattern_summary as
with evidence as (
  select trunc(cast(event_at as timestamp), 'HH') period_hour,
         page_id,
         action_name,
         to_char(sql_code) pattern_code,
         cast(null as varchar2(500)) endpoint,
         correlation_id,
         order_id
    from bf_error_log
  union all
  select trunc(cast(event_at as timestamp), 'HH'),
         cast(null as number),
         'INTEGRATION_RESPONSE',
         business_code,
         endpoint,
         correlation_id,
         order_id
    from bf_integration_log
   where http_status >= 400
      or business_code not in ('0', 'SUCCESS')
)
select period_hour,
       page_id,
       action_name,
       pattern_code,
       endpoint,
       count(*) occurrence_count,
       count(distinct correlation_id) correlation_count,
       count(distinct order_id) order_count
  from evidence
 group by period_hour, page_id, action_name, pattern_code, endpoint;
