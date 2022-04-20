/***************************************************************************
 Script to:
    1. insert a row into SAP_INTERFACE_PURGE for PUTAWAYLST_HIST.
    2. set add_date in putawaylst_hist for pre-existing rows.    

 Modification history:

 Date         Author      Comment
 -----------  ---------   ------------------------------------------------
 03-Feb-2022  pkab6563    Created - Jira OPCOF-3867: putawaylst_hist purge.

****************************************************************************/

-- 1. Insert row into sap_interface_purge

DECLARE
    l_row_count  PLS_INTEGER := 0;
BEGIN
    SELECT COUNT(*) 
    INTO   l_row_count
    FROM   swms.sap_interface_purge
    WHERE  table_name = 'PUTAWAYLST_HIST';

    IF l_row_count = 0 THEN
        INSERT INTO swms.sap_interface_purge
                    (
                      table_name, 
                      retention_days, 
                      description, 
                      upd_user, 
                      upd_date
                    )
               VALUES
                    (
                      'PUTAWAYLST_HIST',
                      20,
                      'History table for putawaylst',
                      REPLACE(user, 'OPS$'),
                      sysdate
                    );
        COMMIT;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        pl_log.ins_msg('WARN', 'OPCOF3867_DML_insert_update', 
                       'Deployment DML to insert a row into SAP_INTERFACE_PURGE for PUTAWAYLST_HIST failed', 
                       SQLCODE, SQLERRM);
        RAISE;

END;
/

-- 2. Update add_date

DECLARE
   l_count PLS_INTEGER := 0;
BEGIN
    SELECT COUNT(*)
    INTO   l_count
    FROM   swms.putawaylst_hist
    WHERE  add_date is null;

    IF l_count > 0 THEN
        UPDATE swms.putawaylst_hist
        SET    add_date = putaway_del_date
        WHERE  add_date is null;

        COMMIT;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        pl_log.ins_msg('WARN', 'OPCOF3867_DML_insert_update',
                       'Deployment DML to set ADD_DATE in PUTAWAYLST_HIST failed',
                       SQLCODE, SQLERRM);
        RAISE;

END;
/
