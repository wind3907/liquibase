DECLARE
  v_column_exists NUMBER := 0;  
  BEGIN
  
  select count(*)
  into v_column_exists
  from all_objects
  where object_type = 'TYPE'
  and object_name = 'QUEUE_CHAR_TYPE';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'Create type queue_char_type as object( que_message varchar2(4000))';
  END IF;
 END;
/ 