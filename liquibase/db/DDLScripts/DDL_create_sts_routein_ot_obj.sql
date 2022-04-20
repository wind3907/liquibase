DECLARE
  v_column_exists NUMBER := 0;  
BEGIN
  
  select count(*)
  into v_column_exists
  from all_objects
  where object_type = 'TYPE'
  and object_name = 'STS_ROUTEIN_OT_OBJ';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'create or replace TYPE  STS_ROUTEIN_OT_OBJ  AS OBJECT 
    (
    DCID VARCHAR2(4 CHAR) 
	,ROUTE_NO VARCHAR2(10 CHAR) 
	,ROUTE_DATE DATE 
	,CUST_ID VARCHAR2(14 CHAR) 
	,ALT_STOP_NO NUMBER(7,2) 
	,MANIFEST_NO NUMBER(7,0)	
    ,seq_no VARCHAR2(3)
	,prod_id VARCHAR2(9)
    ,wms_item_type VARCHAR2(4)
	,descript VARCHAR2(40)
    ,price NUMBER(9,2)
	,invoice_num VARCHAR2(16)	
    ,quantity NUMBER(3,0)
	,tax_per_item NUMBER(9,2)
	,alt_prod_id VARCHAR2(20)
	,weight NUMBER(9,3)
	,lot_no VARCHAR2(30)
	,item_id VARCHAR2(12)
	,barcode VARCHAR2(11)
	,add_chg_tot NUMBER(9,2)
	,add_chg_desc VARCHAR2(50)
    ,time_stamp date
    ,action varchar2(1)	
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
  and object_name = 'STS_ROUTEIN_OT_TAB';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'create or replace TYPE STS_ROUTEIN_OT_TAB AS TABLE of sts_routein_ot_obj';
  END IF;
END;
/ 	