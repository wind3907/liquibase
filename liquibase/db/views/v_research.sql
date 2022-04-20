CREATE OR REPLACE VIEW "SWMS"."V_RESEARCH" ("TRANS_ID",
    "TRANS_TYPE","PROD_ID","CUST_PREF_VENDOR","TRANS_DATE",
    "T_DATE","T_TIME","QTY","ROUTE_NO","REASON_CODE","ORDER_ID") 
    AS 
    select trans_id, trans_type, prod_id, cust_pref_vendor, 
    trans_date, 
       substr(to_char(trans_date, 'Mon DD YY'),1,9) t_date, 
       substr(to_char(to_char(trans_date,'fmHH'),'09'),2)||':'|| 
       substr(to_char(to_char(trans_date,'fmMI'),'09'),2)||' '|| 
       substr(to_char(trans_date,'fmPM'),1,2) t_time, 
       decode(trans_type, 'CNT', qty_expected, 
                          'SHT',0, 
                          'PIK', -abs(qty), qty) qty, 
       route_no, reason_code, order_id 
  from v_trans 
 where not(trans_type = 'PUT' and user_id = 'OPS') 
   and not(trans_type = 'ADJ' and (reason_code is NULL 
                                 or reason_code in ('AA', 'SY'))) 
   and trans_type not in (select trans_type 
                            from trans_type 
                           where inv_affecting = 'N' 
                             and trans_type not in ('SHT','CNT'));

