/******************************************************************************
**
** Script to insert new BRT trans type into trans_type table.
** Jira card #215 - route deletion.
**
*******************************************************************************/

DECLARE
	v_row_count NUMBER := 0;
BEGIN
    SELECT COUNT(*)
    INTO  v_row_count
    FROM  swms.trans_type
    WHERE trans_type = 'BRT';
    
    IF v_row_count = 0 THEN
       INSERT INTO swms.trans_type 
                     (trans_type, descrip, retention_days, inv_affecting)
              VALUES 
                     ('BRT', 'Backout Route', 55, 'N');

        COMMIT;
    END IF;
END;
/
