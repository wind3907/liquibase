DECLARE
  v_column_exists NUMBER := 0;  
BEGIN
  
  select count(*)
  into v_column_exists
  from all_objects
  where object_type = 'TYPE'
  and object_name = 'DRIVERPROEXPORTRESPONSE';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'create or replace TYPE DRIVERPROEXPORTRESPONSE AS OBJECT 
    (
    VALID VARCHAR2(5 CHAR) 
	,MSG VARCHAR2(100 CHAR) 
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
  and object_name = 'DRIVERPROEXPORTRESPONSE_TAB';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'create or replace TYPE DRIVERPROEXPORTRESPONSE_TAB AS TABLE of DRIVERPROEXPORTRESPONSE';
  END IF;
END;
/ 	