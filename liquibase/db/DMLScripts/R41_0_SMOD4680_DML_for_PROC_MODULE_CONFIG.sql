/****************************************************************************************
** Desc: Iteration 1 Enabled Modules
**
** Modification History:
**    Date          Designer           Comments
**    -----------  --------     ---------------------------------------------------------
**    11/09/2020    apri0734    SMOD-4680: Iteration 1 Enabled Modules
**    15/09/2020    nsel0716    SMOD-3434: Conditional Insert 
*****************************************************************************************/
DECLARE
    l_proc_enabled CHAR(1);
BEGIN

    $if swms.platform.SWMS_REMOTE_DB $then
        l_proc_enabled := 'Y';
    $else
        l_proc_enabled := 'N';
    $end

    INSERT INTO PROC_MODULE_CONFIG(PROC_MODULE, PLSQL_PACKAGE, ENABLED, ITERATION)
    SELECT 'TP_close_receipt','pl_rcv_po_close',l_proc_enabled,'01' FROM dual
    WHERE NOT EXISTS (select 1 from PROC_MODULE_CONFIG where PROC_MODULE = 'TP_close_receipt');

    INSERT INTO PROC_MODULE_CONFIG(PROC_MODULE, PLSQL_PACKAGE, ENABLED, ITERATION)
    SELECT 'TP_pallet_main2','pl_rcv_po_open',l_proc_enabled,'01' FROM dual
    WHERE NOT EXISTS (select 1 from PROC_MODULE_CONFIG where PROC_MODULE = 'TP_pallet_main2');

    INSERT INTO PROC_MODULE_CONFIG(PROC_MODULE, PLSQL_PACKAGE, ENABLED, ITERATION)
    SELECT 'TP_run_wk_sht','pl_run_worksheet',l_proc_enabled,'01' FROM dual
    WHERE NOT EXISTS (select 1 from PROC_MODULE_CONFIG where PROC_MODULE = 'TP_run_wk_sht');

    INSERT INTO PROC_MODULE_CONFIG(PROC_MODULE, PLSQL_PACKAGE, ENABLED, ITERATION)
    SELECT 'confirm_putaway','pl_confirm_putaway',l_proc_enabled,'01' FROM dual
    WHERE NOT EXISTS (select 1 from PROC_MODULE_CONFIG where PROC_MODULE = 'confirm_putaway');

    COMMIT;
END;
/
