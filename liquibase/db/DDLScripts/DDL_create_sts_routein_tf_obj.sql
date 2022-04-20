DECLARE
  v_column_exists NUMBER := 0;  
BEGIN
  
  select count(*)
  into v_column_exists
  from all_objects
  where object_type = 'TYPE'
  and object_name = 'STS_ROUTEIN_TF_OBJ';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'create or replace TYPE sts_routein_tf_obj AS OBJECT
   (
     DCID VARCHAR2(4 CHAR) 
	,ROUTE_NO VARCHAR2(10 CHAR) 
	,ROUTE_DATE DATE 
	,CUST_ID VARCHAR2(14 CHAR) 
	,ALT_STOP_NO NUMBER(7,2) 
	,MANIFEST_NO NUMBER(7,0)	
	, time_stamp Date
	, code VARCHAR2(3 CHAR)
	, auth_code VARCHAR2(6 CHAR)
	, deliv_receipt_pdf varchar2(40 char)
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
  and object_name = 'STS_ROUTEIN_TF_TAB';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'create or replace TYPE STS_ROUTEIN_TF_TAB AS TABLE of sts_routein_tf_obj';
  END IF;
END;
/ 	