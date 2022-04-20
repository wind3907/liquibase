/***************************************************************************
 Script to:
    1. insert two new rec_type rows into REC_TYPE table.
    
 Modification history:

 Date         Author      Comment
 -----------  ---------   ------------------------------------------------
 03-Mar-2022  vkal9662    Created - Jira 4033.

****************************************************************************/



DECLARE
    l_row_count  PLS_INTEGER := 0;
	l_row_count2  PLS_INTEGER := 0;
	
BEGIN

    SELECT COUNT(*) 
    INTO   l_row_count
    FROM   swms.rec_type
	where  rec_type ='IX';

    IF l_row_count = 0 THEN
 
		Insert into rec_type(rec_type, DESCRIP)
		Values('IX', 'Intercompany Crossdock PO');
    End If; 
	
	SELECT COUNT(*) 
    INTO   l_row_count2
    FROM   swms.rec_type
	where  rec_type ='IN';
	
	IF l_row_count2 = 0 THEN
       Insert into rec_type(rec_type, DESCRIP)
       Values('IN', 'Intercompany SN');
    End if;
	
    COMMIT;
   

EXCEPTION
    WHEN OTHERS THEN
        pl_log.ins_msg('WARN', 'OPCOF4033_DML_insert_ermtype', 
                       'Deployment DML to insert a row into rec_type table failed', 
                       SQLCODE, SQLERRM);
        RAISE;

END;
/
