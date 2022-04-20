REM INSERTING into TRANS_TYPE
SET DEFINE OFF;

SET ECHO OFF
SET SCAN OFF
SET LINESIZE 300
SET PAGESIZE 60
SET SERVEROUTPUT ON SIZE UNLIMITED

DECLARE

  K_This_Script             CONSTANT  VARCHAR2(50 CHAR) := 'R1_DML_3577_add_new_trans_type.sql';

BEGIN

  DBMS_OUTPUT.PUT_LINE('Starting script '||K_This_Script);  

  Insert into TRANS_TYPE (TRANS_TYPE,
                          DESCRIP,
                          RETENTION_DAYS,
                          INV_AFFECTING)
    SELECT 'PUX',
           'Putaway Cross Dock',
           55,
           'Y'
    FROM dual
    WHERE NOT EXISTS (SELECT 'Checking if the transaction type exists'
                      FROM trans_type 
                      WHERE TRANS_TYPE = 'PUX');

  IF sql%found THEN 
      DBMS_OUTPUT.PUT_LINE('Added Transaction Type PUX');
      commit;
  END IF;

END;
/
