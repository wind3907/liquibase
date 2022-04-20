DECLARE
  v_column_exists NUMBER := 0;  
BEGIN
  
  select count(*)
  into v_column_exists
  from all_objects
  where object_type = 'TYPE'
  and object_name = 'STS_ROUTEIN_TI_OBJ';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'create or replace TYPE sts_routein_ti_obj AS OBJECT
   (
     DCID VARCHAR2(4 CHAR) 
	,ROUTE_NO VARCHAR2(10 CHAR) 
	,ROUTE_DATE DATE 
	,CUST_ID VARCHAR2(14 CHAR) 
	,ALT_STOP_NO NUMBER(7,2) 
	,MANIFEST_NO NUMBER(7,0)
    ,item_id varchar2(12 char)
	,prod_id varchar2(9 char)
	,quantity NUMBER(3,0)
	,pack_qty_split NUMBER
	,weight number(9,3)
	,invoice_num varchar2(16 char)
	,seq_no varchar2(3 char)
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
  and object_name = 'STS_ROUTEIN_TI_TAB';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'create or replace TYPE STS_ROUTEIN_TI_TAB AS TABLE of sts_routein_ti_obj';
  END IF;
END;
/ 	