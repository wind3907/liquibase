
DECLARE
  v_column_exists NUMBER := 0;  
  BEGIN
  
  select count(*)
  into v_column_exists
  from all_objects
  where object_type = 'TYPE'
  and object_name = 'STS_ROUTEIN_ST_OBJ';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'create or replace TYPE  STS_ROUTEIN_ST_OBJ  AS OBJECT
    (
    DCID VARCHAR2(4 CHAR) 
	,ROUTE_NO VARCHAR2(10 CHAR) 
	,ROUTE_DATE DATE 
	,CUST_ID VARCHAR2(14 CHAR) 
	,ALT_STOP_NO NUMBER(7,2) 
	,MANIFEST_NO NUMBER(7,0)
    ,DRIVER_SIGN_IND VARCHAR2(6)
	,DRIVER_ID VARCHAR2(24)
	,DELIV_SCAN_QTY VARCHAR2(3)
	,DELIV_MANUAL_PICK_QTY VARCHAR2(3)
	,ARRIVAL_TIME DATE
    ,DEPT_TIME DATE	
    ,STOP_WRK_DURATION NUMBER
    ,DELIV_RECEIPT_PDF VARCHAR2(40)
    ,GPS_LATITUDE VARCHAR2(40)
	,GPS_LONGTITUDE VARCHAR2(40)
	,GPS_DATE_TIME DATE	
    ) ';

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
  and object_name = 'STS_ROUTEIN_ST_TAB';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'create or replace type sts_routein_st_tab as table of sts_routein_st_obj';
  END IF;
END;
/ 	