DECLARE
  v_column_exists NUMBER := 0;  
BEGIN
  
  select count(*)
  into v_column_exists
  from all_objects
  where object_type = 'TYPE'
  and object_name = 'STS_ROUTEIN_CW_OBJ';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'create or replace TYPE  STS_ROUTEIN_CW_OBJ  AS OBJECT 
    (
    DCID VARCHAR2(4 CHAR) 
	,ROUTE_NO VARCHAR2(10 CHAR) 
	,ROUTE_DATE DATE 
	,CUST_ID VARCHAR2(14 CHAR) 
	,ALT_STOP_NO NUMBER(7,2) 
	,MANIFEST_NO NUMBER(7,0)
    ,item_id VARCHAR2(12)	
    ,prod_id VARCHAR2(9)
	,invoice_num VARCHAR2(16)	
    ,seq_no VARCHAR2(3)	
    ,weight NUMBER(9,3)
	,weight_adj NUMBER(9,3)
	,tax_per_item NUMBER(9,2)
	,tax_tot NUMBER(9,2)
	,credit_amt NUMBER(9,2)
    ,price NUMBER(9,2)	
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
  and object_name = 'STS_ROUTEIN_CW_TAB';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'create or replace TYPE  STS_ROUTEIN_CW_TAB AS TABLE of sts_routein_cw_obj';
  END IF;
END;
/ 	