/****************************************************************************************
** Desc: Iteration 4 Enabled Modules
**
** Modification History:
**    Date          Designer           Comments
**    -----------  --------     ---------------------------------------------------------
**    07/01/2021    nsel0716    SMOD-5600: Iteration 4 Enabled Modules
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
    SELECT 'receive_ret','pl_receive_return',l_proc_enabled,'04' FROM dual
    WHERE NOT EXISTS (select 1 from PROC_MODULE_CONFIG where PROC_MODULE = 'receive_ret');

    COMMIT;
END;
/