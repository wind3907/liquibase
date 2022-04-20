-- Before a row is inserted or updated,
-- Check the abc field to see if it is NULL. 
-- When NULL, default the value to 'A'. 
-- prpjro 12/16/97

CREATE OR REPLACE TRIGGER swms.abc_trigger
BEFORE INSERT OR UPDATE OF abc ON swms.pm
FOR EACH ROW
DECLARE
   abc_count NUMBER(10) := 0;
BEGIN

SELECT COUNT(*) 
  INTO abc_count
  FROM abc 
 WHERE abc = :new.abc;

IF (abc_count = 0) THEN
   :new.abc := 'A';
END IF;

END;
/

