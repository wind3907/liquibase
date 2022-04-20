/******************************************************************************
**
** Script to insert new runsql script blue_chep_pallet_outbound_rpt.sh into scripts table.
** Jira card #OPCOF-712
**
*******************************************************************************/

DECLARE
        v_row_count NUMBER := 0;
BEGIN
    SELECT COUNT(*)
    INTO  v_row_count
    FROM  swms.scripts
    WHERE script_name = 'blue_chep_pallet_outbound_rpt.sh';

    IF v_row_count = 0 THEN
       INSERT INTO swms.scripts
                     (script_name,
                      application_func,
                      restartable,
                      run_count,
                      update_function,
                      print_options,
                      display_help)
              VALUES
                    ('blue_chep_pallet_outbound_rpt.sh',
                     'INVENTORY',
                     'Y',
                     0,
                     'N',
                     '-z1 -p12',
                     '   Displays the number of Blue Chep pallets Outbound by PO#');

        COMMIT;
    END IF;
END;
/
