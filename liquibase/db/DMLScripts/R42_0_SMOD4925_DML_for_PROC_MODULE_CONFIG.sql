/****************************************************************************************
** Desc: Iteration 2 Enabled Modules
**
** Modification History:
**    Date          Designer           Comments
**    -----------  --------     ---------------------------------------------------------
**    12/10/2020    nsel0716    SMOD-4925: Iteration 2 Enabled Modules
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
    SELECT 'replen_create','pl_create_ndm',l_proc_enabled,'02' FROM dual
    WHERE NOT EXISTS (select 1 from PROC_MODULE_CONFIG where PROC_MODULE = 'replen_create');

    INSERT INTO PROC_MODULE_CONFIG(PROC_MODULE, PLSQL_PACKAGE, ENABLED, ITERATION)
    SELECT 'tp_cte_cc','pl_tp_cte_cc',l_proc_enabled,'02' FROM dual
    WHERE NOT EXISTS (select 1 from PROC_MODULE_CONFIG where PROC_MODULE = 'tp_cte_cc');

    COMMIT;
END;
/
