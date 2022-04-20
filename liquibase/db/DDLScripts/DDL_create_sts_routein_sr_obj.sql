DECLARE
  v_column_exists NUMBER := 0;  
BEGIN
  
  select count(*)
  into v_column_exists
  from all_objects
  where object_type = 'TYPE'
  and object_name = 'STS_ROUTEIN_SR_OBJ';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'create or replace TYPE  STS_ROUTEIN_SR_OBJ  AS OBJECT 
    (
    DCID VARCHAR2(4 CHAR) 
	,ROUTE_NO VARCHAR2(10 CHAR) 
	,ROUTE_DATE DATE 
	,CUST_ID VARCHAR2(14 CHAR) 
	,ALT_STOP_NO NUMBER(7,2) 
	,MANIFEST_NO NUMBER(7,0)
    ,invoice_no VARCHAR2(16)	
    ,prod_id VARCHAR2(9)
    ,quantity NUMBER(3,0)
    ,credit_ref_num VARCHAR2(20)	
	,orig_wms_item_type VARCHAR2(4)
	,wms_item_type VARCHAR2(4)
	,disposition VARCHAR2(3)
	,return_reason_cd VARCHAR2(3)
    ,credit_amt NUMBER(9,2)
	,weight NUMBER(9,3)
	,return_prod_id VARCHAR2(9)	
	,return_qty NUMBER(3,0)
	,tax_per_item NUMBER(9,2)
	,tax_tot number(9,2)	
    ,add_chg_per_item NUMBER(9,2)
    ,add_chg_tot NUMBER(9,2)
    ,price NUMBER(9,2)
	,refusal_reason_cd VARCHAR2(3)	
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
  and object_name = 'STS_ROUTEIN_SR_TAB';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'create or replace TYPE STS_ROUTEIN_SR_TAB AS TABLE of sts_routein_sr_obj';
  END IF;
END;
/ 	