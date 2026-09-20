prompt Creating BF_INCIDENT_PKG

create or replace package bf_incident_pkg authid definer as
  procedure open_timeline(
    p_result          out sys_refcursor,
    p_order_id        in number default null,
    p_session_id      in varchar2 default null,
    p_correlation_id  in varchar2 default null,
    p_from_timestamp  in timestamp with local time zone default null,
    p_to_timestamp    in timestamp with local time zone default null,
    p_max_rows        in pls_integer default 200
  );

  function evidence_bundle(
    p_order_id        in number default null,
    p_session_id      in varchar2 default null,
    p_correlation_id  in varchar2 default null,
    p_from_timestamp  in timestamp with local time zone default null,
    p_to_timestamp    in timestamp with local time zone default null,
    p_max_rows        in pls_integer default 200
  ) return clob;
end bf_incident_pkg;
/

create or replace package body bf_incident_pkg as
  function bounded_rows(p_max_rows in pls_integer) return pls_integer is
  begin
    return least(greatest(nvl(p_max_rows, 200), 1), 500);
  end bounded_rows;

  procedure open_timeline(
    p_result          out sys_refcursor,
    p_order_id        in number default null,
    p_session_id      in varchar2 default null,
    p_correlation_id  in varchar2 default null,
    p_from_timestamp  in timestamp with local time zone default null,
    p_to_timestamp    in timestamp with local time zone default null,
    p_max_rows        in pls_integer default 200
  ) is
    l_max_rows pls_integer := bounded_rows(p_max_rows);
  begin
    open p_result for
      select event_at, source_type, event_type, severity, order_id,
             apex_session_id, correlation_id, component_name, summary,
             detail_excerpt
        from bf_v_incident_timeline
       where (p_order_id is null or order_id = p_order_id)
         and (p_session_id is null or apex_session_id = p_session_id)
         and (p_correlation_id is null or correlation_id = p_correlation_id)
         and (p_from_timestamp is null or event_at >= p_from_timestamp)
         and (p_to_timestamp is null or event_at < p_to_timestamp)
       order by event_at, source_type, event_type
       fetch first l_max_rows rows only;
  end open_timeline;

  function evidence_bundle(
    p_order_id        in number default null,
    p_session_id      in varchar2 default null,
    p_correlation_id  in varchar2 default null,
    p_from_timestamp  in timestamp with local time zone default null,
    p_to_timestamp    in timestamp with local time zone default null,
    p_max_rows        in pls_integer default 200
  ) return clob is
    l_result clob;
    l_max_rows pls_integer := bounded_rows(p_max_rows);
  begin
    select json_object(
             'filters' value json_object(
               'orderId' value p_order_id,
               'sessionId' value p_session_id,
               'correlationId' value p_correlation_id,
               'from' value to_char(p_from_timestamp, 'YYYY-MM-DD"T"HH24:MI:SS.FF3'),
               'to' value to_char(p_to_timestamp, 'YYYY-MM-DD"T"HH24:MI:SS.FF3'),
               'sessionTimeZone' value sessiontimezone,
               'maxRows' value l_max_rows
             ),
             'evidence' value coalesce(
               (
                 select json_arrayagg(
                          json_object(
                            'eventAt' value to_char(event_at at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.FF3"Z"'),
                            'sourceType' value source_type,
                            'eventType' value event_type,
                            'severity' value severity,
                            'orderId' value order_id,
                            'sessionId' value apex_session_id,
                            'correlationId' value correlation_id,
                            'component' value component_name,
                            'summary' value summary,
                            'detailExcerpt' value detail_excerpt
                            returning clob
                          ) order by event_at, source_type, event_type
                          returning clob
                        )
                   from (
                     select *
                       from bf_v_incident_timeline
                      where (p_order_id is null or order_id = p_order_id)
                        and (p_session_id is null or apex_session_id = p_session_id)
                        and (p_correlation_id is null or correlation_id = p_correlation_id)
                        and (p_from_timestamp is null or event_at >= p_from_timestamp)
                        and (p_to_timestamp is null or event_at < p_to_timestamp)
                      order by event_at, source_type, event_type
                      fetch first l_max_rows rows only
                   )
               ),
               to_clob('[]')
             ) format json
             returning clob
           )
      into l_result
      from dual;
    return l_result;
  end evidence_bundle;
end bf_incident_pkg;
/
