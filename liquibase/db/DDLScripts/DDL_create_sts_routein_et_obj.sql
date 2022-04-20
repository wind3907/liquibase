DECLARE
  v_column_exists NUMBER := 0;  
BEGIN
  
  select count(*)
  into v_column_exists
  from all_objects
  where object_type = 'TYPE'
  and object_name = 'STS_ROUTEIN_ET_OBJ';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'create or replace TYPE STS_ROUTEIN_ET_OBJ AS OBJECT 
    (
	 dcid VARCHAR2(4 CHAR) 
	, route_no VARCHAR2(10 CHAR)
	, route_date DATE 
	, event_type VARCHAR2(30)
	, cust_id VARCHAR2(14)
	, prod_id VARCHAR2(9)
	, compartment VARCHAR2(1)
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
  and object_name = 'STS_ROUTEIN_ET_TAB';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'create or replace TYPE STS_ROUTEIN_ET_TAB AS TABLE of STS_ROUTEIN_ET_OBJ';
  END IF;
END;
/ 	