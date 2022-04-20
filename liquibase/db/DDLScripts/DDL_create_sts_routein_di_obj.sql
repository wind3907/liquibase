DECLARE
  v_column_exists NUMBER := 0;  
BEGIN
  
  select count(*)
  into v_column_exists
  from all_objects
  where object_type = 'TYPE'
  and object_name = 'STS_ROUTEIN_DI_OBJ';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'create or replace TYPE  STS_ROUTEIN_DI_OBJ  AS OBJECT 
    (
    DCID VARCHAR2(4 CHAR) 
	,ROUTE_NO VARCHAR2(10 CHAR) 
	,ROUTE_DATE DATE 
	,CUST_ID VARCHAR2(14 CHAR) 
	,ALT_STOP_NO NUMBER(7,2) 
	,MANIFEST_NO NUMBER(7,0)
	,barcode VARCHAR2(11)
    ,prod_id VARCHAR2(9)
    ,quantity NUMBER(3,0)	
	,weight NUMBER(9,3)
    ,item_class varchar2(2)
	,invoice_num VARCHAR2(16)
	,wms_item_type VARCHAR2(4)
    ,item_id VARCHAR2(12)
    ,seq_no VARCHAR2(3)
	,tax_per_item NUMBER(9,2)
	,tax_tot NUMBER(9,2)
    ,add_chg_per_item NUMBER(9,2)
	,add_chg_tot NUMBER(9,2)
	,invoice_amt NUMBER(9,2)
    ,spc NUMBER(4,0)
	,descript VARCHAR2(40)
    ,price NUMBER(9,2)
    ,alt_prod_id VARCHAR2(20)
    ,time_stamp date 	
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
  and object_name = 'STS_ROUTEIN_DI_TAB';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'create or replace TYPE  STS_ROUTEIN_DI_TAB AS TABLE of sts_routein_di_obj';
  END IF;
END;
/ 	