-- Session-scoped cart; durable checkout state survives a native APEX exception.
create or replace package bf_cart_pkg authid definer as
 procedure initialize;
 procedure new_cart;
 procedure set_quantity(p_product number,p_quantity number);
 procedure add_item(p_product number);
 function request_json return clob;
 procedure begin_checkout(p_order out number);
 procedure prepare_retry;
 procedure place_order;
 function current_order return number;
 function checkout_state return varchar2;
end bf_cart_pkg;
/
create or replace package body bf_cart_pkg as
 procedure require_session is l_application number;
 begin
  select application_id into l_application from bf_app_config where config_id=1;
  if nvl(v('APP_ID'),'0')<>to_char(l_application) or v('APP_SESSION') is null or v('APP_USER') is null
   or upper(v('APP_USER')) in ('NOBODY','APEX_PUBLIC_USER') then
   raise_application_error(-20080,'Sign in to continue'); end if;
 end;
 procedure initialize is
 begin
  require_session;
  if not apex_collection.collection_exists('BF_SHOP_CART') then apex_collection.create_collection('BF_SHOP_CART'); end if;
 end;
 procedure new_cart is
 begin
  require_session;
  apex_collection.create_or_truncate_collection('BF_SHOP_CART');
  if apex_collection.collection_exists('BF_SHOP_CHECKOUT') then apex_collection.delete_collection('BF_SHOP_CHECKOUT'); end if;
 end;
 function checkout_state return varchar2 is l_state varchar2(30);
 begin
  require_session;
  select c002 into l_state from apex_collections where collection_name='BF_SHOP_CHECKOUT' and seq_id=1;
  return l_state;
 exception when no_data_found then return 'NONE';
 end;
 function current_order return number is l_order number;
 begin
  require_session;
  select n001 into l_order from apex_collections where collection_name='BF_SHOP_CHECKOUT' and seq_id=1;
  return l_order;
 exception when no_data_found then return null;
 end;
 procedure set_quantity(p_product number,p_quantity number) is l_sequence number; l_count number;
 begin
  initialize;
  if p_quantity is null or p_quantity<>trunc(p_quantity) or p_quantity not between 0 and 99 then
   raise_application_error(-20083,'Quantity must be a whole number between 0 and 99'); end if;
  select count(*) into l_count from bf_product where product_id=p_product and active_flag='Y';
  if l_count<>1 then raise_application_error(-20081,'Product is not available'); end if;
  select max(seq_id) into l_sequence from apex_collections where collection_name='BF_SHOP_CART' and n001=p_product;
  if p_quantity=0 then
   if l_sequence is not null then apex_collection.delete_member('BF_SHOP_CART',l_sequence); end if;
  elsif l_sequence is null then apex_collection.add_member('BF_SHOP_CART',p_n001=>p_product,p_n002=>p_quantity);
  else apex_collection.update_member('BF_SHOP_CART',l_sequence,p_n001=>p_product,p_n002=>p_quantity);
  end if;
  if apex_collection.collection_exists('BF_SHOP_CHECKOUT') then apex_collection.delete_collection('BF_SHOP_CHECKOUT'); end if;
 end;
 procedure add_item(p_product number) is l_quantity number;
 begin
  initialize;
  select nvl(max(n002),0) into l_quantity from apex_collections where collection_name='BF_SHOP_CART' and n001=p_product;
  set_quantity(p_product,l_quantity+1);
 end;
 function request_json return clob is l_json clob;
 begin
  initialize;
  select json_arrayagg(json_object('productId' value n001,'quantity' value n002) order by seq_id returning clob)
   into l_json from apex_collections where collection_name='BF_SHOP_CART';
  if l_json is null then raise_application_error(-20082,'Add at least one product'); end if;
  return l_json;
 end;
 procedure begin_checkout(p_order out number) is l_key varchar2(64);
 begin
  initialize;
  if checkout_state in ('READY','RETRY_READY') then p_order:=current_order; return; end if;
  if checkout_state='WAIT_RETRY' then raise_application_error(-20084,'Your purchase is still being processed'); end if;
  bf_order_pkg.begin_checkout(request_json,v('APP_SESSION'),v('APP_USER'),l_key,p_order);
  apex_collection.create_or_truncate_collection('BF_SHOP_CHECKOUT');
  apex_collection.add_member('BF_SHOP_CHECKOUT',p_c001=>l_key,p_c002=>'READY',p_n001=>p_order);
  commit;
 end;
 procedure prepare_retry is l_key varchar2(64); l_order number; l_lock varchar2(64);
 begin
  require_session;
  if checkout_state<>'WAIT_RETRY' then return; end if;
  select c001 into l_key from apex_collections where collection_name='BF_SHOP_CHECKOUT' and seq_id=1;
  select request_hash into l_lock from bf_order_intent where request_hash=l_key
   and app_user=v('APP_USER') and apex_session_id=v('APP_SESSION') for update;
  bf_order_pkg.receive_attempt(l_key,v('APP_SESSION'),v('APP_USER'),l_order);
  apex_collection.update_member('BF_SHOP_CHECKOUT',1,p_c001=>l_key,p_c002=>'RETRY_READY',p_n001=>l_order);
  commit;
 end;
 procedure place_order is l_key varchar2(64); l_state varchar2(30); l_order number;
 begin
  require_session;
  select c001,c002,n001 into l_key,l_state,l_order from apex_collections where collection_name='BF_SHOP_CHECKOUT' and seq_id=1;
  if l_state='DONE' then return; end if;
  if l_state not in ('READY','RETRY_READY') then raise_application_error(-20084,'This purchase cannot be submitted again'); end if;
  begin
   bf_order_pkg.process_order(l_order,v('APP_SESSION'),v('APP_USER'));
  exception when others then
   apex_collection.update_member('BF_SHOP_CHECKOUT',1,p_c001=>l_key,p_c002=>'FAILED',p_n001=>l_order);
   commit;
   raise;
  end;
  if l_state='READY' and bf_lab_pkg.retry_required(l_key) then l_state:='WAIT_RETRY';
  else l_state:='DONE'; apex_collection.truncate_collection('BF_SHOP_CART'); end if;
  apex_collection.update_member('BF_SHOP_CHECKOUT',1,p_c001=>l_key,p_c002=>l_state,p_n001=>l_order);
  commit;
 end;
end bf_cart_pkg;
/
