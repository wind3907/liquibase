/****************************************************************************
*  FILE
*   fix_cascading_invalidations.sql
*
*  DESCRIPTION
*   Script to compile invalid objects in SWMS schema in case 
*    of cascading invalidations.
*
***************************************************************************/
SET ECHO ON
SET TIMING ON
SPOOL /tmp/swms/log/fix_cascading_invalidations.lis

SET SERVEROUTPUT ON SIZE 1000000
BEGIN
    FOR cur_rec IN (
        SELECT OWNER, OBJECT_NAME, OBJECT_TYPE,
            DECODE(OBJECT_TYPE, 'PACKAGE', 1, 'PACKAGE BODY', 2, 2) AS recompile_order
        FROM DBA_OBJECTS
        WHERE STATUS != 'VALID'
            AND OWNER = 'SWMS'
        ORDER BY 4
    ) LOOP
        BEGIN
            IF cur_rec.object_type = 'PACKAGE BODY' THEN
                EXECUTE IMMEDIATE 'ALTER PACKAGE "' || cur_rec.owner || '"."' || cur_rec.object_name || '" COMPILE BODY';
            ElSE
                EXECUTE IMMEDIATE 'ALTER ' || cur_rec.object_type || ' "' || cur_rec.owner || '"."' || cur_rec.object_name || '" COMPILE';
            END IF;
            DBMS_OUTPUT.PUT_LINE('Successfully Compiled, ' || cur_rec.object_type || ' of ' || cur_rec.object_name || '.');
        EXCEPTION
            WHEN OTHERS THEN
                NULL;
        END;
    END LOOP;
END;
/

SPOOL OFF;
