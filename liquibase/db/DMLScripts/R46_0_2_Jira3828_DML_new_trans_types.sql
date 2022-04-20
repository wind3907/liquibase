/******************************************************************************
**
** Script to insert new IAC and IAD trans types into trans_type table.
**
*******************************************************************************/

DECLARE
	l_row_count PLS_INTEGER := 0;
BEGIN
    SELECT COUNT(*)
    INTO  l_row_count
    FROM  trans_type
    WHERE trans_type = 'IAC';
    
    IF l_row_count = 0 THEN
       INSERT INTO trans_type 
                     (trans_type, descrip, retention_days, inv_affecting)
              VALUES 
                     ('IAC', 'Indirect Adjustment Change', 30, 'N');

        COMMIT;
    END IF;
END;
/

DECLARE
	l_row_count PLS_INTEGER := 0;
BEGIN
    SELECT COUNT(*)
    INTO  l_row_count
    FROM  trans_type
    WHERE trans_type = 'IAD';
    
    IF l_row_count = 0 THEN
       INSERT INTO trans_type 
                     (trans_type, descrip, retention_days, inv_affecting)
              VALUES 
                     ('IAD', 'Indirect Adjustment Deletion', 30, 'N');

        COMMIT;
    END IF;
END;
/
