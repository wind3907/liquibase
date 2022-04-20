DECLARE
  v_column_exists NUMBER := 0;  
BEGIN
  
  select count(*)
  into v_column_exists
  from all_objects
  where object_type = 'TYPE'
  and object_name = 'STS_ROUTEIN_IV_OBJ';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'create or replace TYPE  STS_ROUTEIN_IV_OBJ  AS OBJECT 
    (
    DCID VARCHAR2(4 CHAR) 
	,ROUTE_NO VARCHAR2(10 CHAR) 
	,ROUTE_DATE DATE 
	,CUST_ID VARCHAR2(14 CHAR) 
	,ALT_STOP_NO NUMBER(7,2) 
	,MANIFEST_NO NUMBER(7,0)	
    ,invoice_num VARCHAR2(16)	
    ,pd_on_acct VARCHAR2(10)
    ,credit_ref_num VARCHAR2(20)	
	,deliv_receipt_pdf VARCHAR2(40)
	,amt_due NUMBER(9,2)
	,event_type VARCHAR2(30)
	,credit_amt NUMBER(9,2)	
	,check_no VARCHAR2(12)
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
  and object_name = 'STS_ROUTEIN_IV_TAB';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'create or replace TYPE STS_ROUTEIN_IV_TAB AS TABLE of sts_routein_iv_obj';
  END IF;
END;
/ 	