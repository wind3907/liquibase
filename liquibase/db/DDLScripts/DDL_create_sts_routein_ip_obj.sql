DECLARE
  v_column_exists NUMBER := 0;  
BEGIN
  
  select count(*)
  into v_column_exists
  from all_objects
  where object_type = 'TYPE'
  and object_name = 'STS_ROUTEIN_IP_OBJ';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'create or replace TYPE sts_routein_ip_obj AS OBJECT
(
    dcid VARCHAR2(4 CHAR) 
	, route_no VARCHAR2(10 CHAR)
	, route_date DATE 
	, descript VARCHAR2(40)
	, input_value VARCHAR2(30)
	, prod_id VARCHAR2(9)
	, bar_code VARCHAR2(11)
	, id1 VARCHAR2(30)
	, id2 VARCHAR2(30)
	, id3 VARCHAR2(30)
	, id4 VARCHAR2(30)
	, time_stamp Date
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
  and object_name = 'STS_ROUTEIN_IP_TAB';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'create or replace TYPE STS_ROUTEIN_IP_TAB AS TABLE of sts_routein_ip_obj';
  END IF;
END;
/ 	