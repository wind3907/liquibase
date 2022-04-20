DECLARE
  v_column_exists NUMBER := 0;  
BEGIN
  
  select count(*)
  into v_column_exists
  from all_objects
  where object_type = 'TYPE'
  and object_name = 'STS_ROUTEIN_RT_OBJ';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'create or replace TYPE  STS_ROUTEIN_RT_OBJ  AS OBJECT 
    (
    DCID VARCHAR2(4 CHAR) 
	,ROUTE_NO VARCHAR2(10 CHAR) 
	,ROUTE_DATE DATE 
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
  and object_name = 'STS_ROUTEIN_RT_TAB';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'create or replace TYPE  STS_ROUTEIN_RT_TAB AS TABLE of sts_routein_rt_obj';
  END IF;
END;
/ 	