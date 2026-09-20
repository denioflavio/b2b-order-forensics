-- Transaction owner: each public write commits a durable order boundary.
create or replace package bf_order_pkg authid definer as
 function customer_id return number;
 procedure begin_checkout(p_items clob,p_session varchar2,p_user varchar2,p_key out varchar2,p_order out number);
 procedure receive_attempt(p_key varchar2,p_session varchar2,p_user varchar2,p_order out number);
 procedure process_order(p_order number,p_session varchar2,p_user varchar2);
end bf_order_pkg;
/
create or replace package body bf_order_pkg as
 function customer_id return number is l_id number;
 begin select customer_id into l_id from bf_customer where customer_code='ACME'; return l_id; end;
 procedure receive_attempt(p_key varchar2,p_session varchar2,p_user varchar2,p_order out number) is
  l_intent bf_order_intent%rowtype;
  l_attempt number;
  l_corr varchar2(64):=bf_log_pkg.new_correlation_id;
  l_context clob;
  l_service bf_order.delivery_service%type;
  l_account bf_order.delivery_account%type;
 begin
  select * into l_intent from bf_order_intent where request_hash=p_key for update;
  if l_intent.customer_id<>customer_id or l_intent.apex_session_id<>p_session or l_intent.app_user<>p_user
    or p_user is null or p_session is null then raise_application_error(-20080,'Purchase not available'); end if;
  -- The intention row serializes creation; the UNIQUE constraint is the invariant.
  select max(order_id) into p_order from bf_order where request_hash=p_key;
  if p_order is not null then
   insert into bf_submission_attempt(request_hash,order_id,correlation_id,outcome,app_user,apex_session_id)
    values(p_key,p_order,l_corr,'REPLAY',p_user,p_session);
   commit;
   return;
  end if;
  l_attempt:=1;
  l_service:=bf_lab_pkg.service_for(p_key);
  l_account:=bf_lab_pkg.account_for(p_key);
  insert into bf_order(order_number,customer_id,request_hash,attempt_no,status,created_by,apex_session_id,correlation_id,
                       delivery_service,delivery_account)
   values('O-'||lower(rawtohex(sys_guid())),l_intent.customer_id,p_key,l_attempt,'RECEIVED',p_user,p_session,l_corr,
          l_service,l_account)
   returning order_id into p_order;
  insert /*+ disable_parallel_dml no_parallel */ into bf_order_item(order_id,product_id,line_number,product_name,quantity,unit_price)
   select /*+ no_parallel */ p_order,j.product_id,j.line_no,j.product_name,j.quantity,j.unit_price
   from json_table(l_intent.request_json,'$.items[*]' columns(
     line_no for ordinality,product_id number path '$.productId',product_name varchar2(200) path '$.name',
     quantity number path '$.quantity',unit_price number path '$.price')) j;
  update bf_order set total_amount=(select sum(line_total) from bf_order_item where order_id=p_order) where order_id=p_order;
  insert into bf_submission_attempt(request_hash,order_id,correlation_id,outcome,app_user,apex_session_id)
   values(p_key,p_order,l_corr,'CREATED',p_user,p_session);
  commit;
  select json_object('state' value 'RECEIVED','requestKey' value p_key,'attempt' value l_attempt returning clob)
   into l_context from dual;
  bf_log_pkg.log_debug('INFO','ORDER.RECEIVE','Order received',l_context,p_session,l_corr,p_order);
 end;
 procedure begin_checkout(p_items clob,p_session varchar2,p_user varchar2,p_key out varchar2,p_order out number) is
  l_input json_array_t;
  l_snapshot json_array_t:=json_array_t();
  l_entry json_object_t;
  l_saved json_object_t;
  l_document json_object_t:=json_object_t();
  l_product bf_product%rowtype;
  l_id number;
  l_quantity number;
  l_customer number:=customer_id;
  l_request clob;
 begin
  if p_user is null or p_session is null or p_items is null or dbms_lob.getlength(p_items)>16000 then
   raise_application_error(-20081,'Unable to read your cart'); end if;
  l_input:=json_array_t.parse(p_items);
  if l_input.get_size<1 or l_input.get_size>50 then raise_application_error(-20082,'Add at least one product'); end if;
  for n in 0..l_input.get_size-1 loop
   l_entry:=treat(l_input.get(n) as json_object_t);
   l_id:=l_entry.get_number('productId');
   l_quantity:=l_entry.get_number('quantity');
   if l_quantity is null or l_quantity<>trunc(l_quantity) or l_quantity not between 1 and 99 then
    raise_application_error(-20083,'Quantity must be a whole number between 1 and 99'); end if;
   select * into l_product from bf_product where product_id=l_id and active_flag='Y';
   l_saved:=json_object_t();
   l_saved.put('productId',l_id); l_saved.put('quantity',l_quantity);
   l_saved.put('name',l_product.brand||' '||l_product.product_name); l_saved.put('price',l_product.unit_price);
   l_snapshot.append(l_saved);
  end loop;
  l_document.put('items',l_snapshot);
  l_request:=l_document.to_clob;
  p_key:=lower(rawtohex(sys_guid()));
  insert into bf_order_intent(request_hash,customer_id,request_json,app_user,apex_session_id)
   values(p_key,l_customer,l_request,p_user,p_session);
  bf_lab_pkg.assign_case(p_key);
  receive_attempt(p_key,p_session,p_user,p_order);
 exception when others then rollback; raise;
 end;
 procedure process_order(p_order number,p_session varchar2,p_user varchar2) is
  l_order bf_order%rowtype;
  l_customer number:=customer_id;
  l_action varchar2(100):='RECEIVE_ORDER';
  procedure event(p_component varchar2,p_message varchar2) is l_json clob;
  begin
   select json_object('state' value l_order.status,'deliveryService' value l_order.delivery_service,
    'deliveryAccountPresent' value case when l_order.delivery_account is null then 'N' else 'Y' end,
    'requestKey' value l_order.request_hash returning clob) into l_json from dual;
   bf_log_pkg.log_debug('INFO',p_component,p_message,l_json,p_session,l_order.correlation_id,p_order);
  end;
  procedure prepare_delivery is
   l_service_code varchar2(8 char);
  begin
   l_action:='PREPARE_DELIVERY';
   event('DELIVERY.PREPARE','Preparing delivery request');
   l_service_code:=l_order.delivery_service;
   event('DELIVERY.PREPARE','Delivery request prepared');
  end;
 begin
  select * into l_order from bf_order where order_id=p_order and customer_id=l_customer
   and created_by=p_user and apex_session_id=p_session for update;
  if p_user is null or p_session is null then raise_application_error(-20080,'Purchase not available'); end if;
  if l_order.status='COMPLETED' then rollback; return; end if;
  if l_order.status<>'RECEIVED' then rollback; raise_application_error(-20084,'This order cannot be submitted again'); end if;
  begin
   l_order.status:='PROCESSING';
   update bf_order set status='PROCESSING',checkout_at=systimestamp,updated_at=systimestamp where order_id=p_order;
   event('ORDER.STATE','Order processing started');
   bf_log_pkg.log_access(to_number(v('APP_ID')),to_number(v('APP_PAGE_ID')),p_session,'PLACE_ORDER',p_user,null,l_order.correlation_id,p_order);
   l_action:='VALIDATE_DELIVERY';
   event('DELIVERY.VALIDATE','Validating delivery configuration');
   if l_order.delivery_account is null then raise_application_error(-20071,'Delivery account is required'); end if;
   event('DELIVERY.VALIDATE','Delivery configuration validated');
   prepare_delivery;
   l_action:='DISPATCH_DELIVERY';
   event('INTEGRATION.DISPATCH','Dispatching simulated delivery request');
   bf_log_pkg.log_integration('/simulated/delivery/orders',200,'0','Request accepted',null,
     '{"accepted":true,"simulated":true}',l_order.correlation_id,p_order,p_session);
   l_order.status:='COMPLETED';
   update bf_order set status='COMPLETED',updated_at=systimestamp where order_id=p_order;
   event('ORDER.STATE','Order confirmed');
   commit;
  exception when others then
   bf_log_pkg.log_error(sqlcode,sqlerrm,dbms_utility.format_error_stack,dbms_utility.format_error_backtrace,
    to_number(v('APP_PAGE_ID')),l_action,p_session,p_order,l_order.correlation_id);
   l_order.status:='ERROR';
   update bf_order set status='ERROR',updated_at=systimestamp where order_id=p_order;
   event('ORDER.STATE','Order processing stopped');
   commit;
   raise;
  end;
 end;
end bf_order_pkg;
/
