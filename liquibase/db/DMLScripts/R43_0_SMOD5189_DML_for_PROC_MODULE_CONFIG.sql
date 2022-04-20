/****************************************************************************************
** Desc: Iteration 2 Enabled Modules
**
** Modification History:
**    Date          Designer           Comments
**    -----------  --------     ---------------------------------------------------------
**    10/11/2020    nsel0716    SMOD-5189: Iteration 3 Enabled Modules
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
    SELECT 'CRT_order_proc','pl_crt_order_proc',l_proc_enabled,'03' FROM dual
    WHERE NOT EXISTS (select 1 from PROC_MODULE_CONFIG where PROC_MODULE = 'CRT_order_proc');

    INSERT INTO PROC_MODULE_CONFIG(PROC_MODULE, PLSQL_PACKAGE, ENABLED, ITERATION)
    SELECT 'order_recovery','pl_order_recovery',l_proc_enabled,'03' FROM dual
    WHERE NOT EXISTS (select 1 from PROC_MODULE_CONFIG where PROC_MODULE = 'order_recovery');

    INSERT INTO PROC_MODULE_CONFIG(PROC_MODULE, PLSQL_PACKAGE, ENABLED, ITERATION)
    SELECT 'awm','pl_awm',l_proc_enabled,'03' FROM dual
    WHERE NOT EXISTS (select 1 from PROC_MODULE_CONFIG where PROC_MODULE = 'awm');

    COMMIT;
END;
/
