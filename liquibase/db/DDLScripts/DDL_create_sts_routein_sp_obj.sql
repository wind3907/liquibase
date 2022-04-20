DECLARE
  v_column_exists NUMBER := 0;  
BEGIN
  
  select count(*)
  into v_column_exists
  from all_objects
  where object_type = 'TYPE'
  and object_name = 'STS_ROUTEIN_SP_OBJ';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'create or replace TYPE  STS_ROUTEIN_SP_OBJ  AS OBJECT 
    (
    DCID VARCHAR2(4 CHAR) 
	,ROUTE_NO VARCHAR2(10 CHAR) 
	,ROUTE_DATE DATE 
	,CUST_ID VARCHAR2(14 CHAR) 
	,ALT_STOP_NO NUMBER(7,2) 
	,MANIFEST_NO NUMBER(7,0)	
    ,prod_id VARCHAR2(9)
	,pack_qty_split number
	,refusal_reason_cd VARCHAR2(3)
	,invoice_amt NUMBER(9,2)
	,weight_adj NUMBER(9,3)	
	,multi_pick  varchar2(1)
	,qty_split number
	,invoice_num VARCHAR2(16)
	,wms_item_type VARCHAR2(4)
    ,quantity NUMBER(3,0)
    ,item_id VARCHAR2(12)	
    ,seq_no VARCHAR2(3)	
	,weight NUMBER(9,3)
	,tax_per_case NUMBER(9,2)
	,tax_tot NUMBER(9,2)
	,credit_amt NUMBER(9,2)
	,tax_per_item NUMBER(9,2)	
	,tax_tot_split NUMBER(9,2)
	,split_charge_amt NUMBER(9,2)
	,spc number(4,0)
	,return_qty number(3,0)
	,descript VARCHAR2(40)
    ,alt_prod_id VARCHAR2(20)
    ,price NUMBER(9,2)
    ,price_split NUMBER(9,2)	
    ,time_stamp date
    ,action	VARCHAR2(1)	
    )';

  END IF;
END;
/ 


DECLARE
  v_column_exists NUMBER := 0;  
BEGIN
  
  select count(*)
  into v_column_exists
  from all_objects
  where object_type = 'TYPE'
  and object_name = 'STS_ROUTEIN_SP_TAB';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'create or replace TYPE  STS_ROUTEIN_SP_TAB AS TABLE of sts_routein_sp_obj';
  END IF;
END;
/ 	