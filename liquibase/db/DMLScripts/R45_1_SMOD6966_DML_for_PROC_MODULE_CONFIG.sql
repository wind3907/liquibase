/****************************************************************************************
** Desc: Iteration 5.1 Enabled Modules
**
** Modification History:
**    Date          Designer           Comments
**    -----------  --------     ---------------------------------------------------------
**    10/06/2021    apri0734    SMOD-6966: Iteration 5.1 Enabled Modules
*****************************************************************************************/
DECLARE
    l_proc_enabled CHAR(1) := 'Y';
BEGIN

    --  iteration 1
    UPDATE PROC_MODULE_CONFIG SET ENABLED = l_proc_enabled WHERE PROC_MODULE = 'TP_close_receipt';
    IF ( sql%rowcount = 0 ) THEN
        INSERT INTO PROC_MODULE_CONFIG(PROC_MODULE, PLSQL_PACKAGE, ENABLED, ITERATION)
        SELECT 'TP_close_receipt','pl_rcv_po_close',l_proc_enabled,'01' FROM dual
        WHERE NOT EXISTS (select 1 from PROC_MODULE_CONFIG where PROC_MODULE = 'TP_close_receipt');
    END IF;

    UPDATE PROC_MODULE_CONFIG SET ENABLED = l_proc_enabled WHERE PROC_MODULE = 'TP_pallet_main2';
    IF ( sql%rowcount = 0 ) THEN
        INSERT INTO PROC_MODULE_CONFIG(PROC_MODULE, PLSQL_PACKAGE, ENABLED, ITERATION)
        SELECT 'TP_pallet_main2','pl_rcv_po_open',l_proc_enabled,'01' FROM dual
        WHERE NOT EXISTS (select 1 from PROC_MODULE_CONFIG where PROC_MODULE = 'TP_pallet_main2');
    END IF;

    UPDATE PROC_MODULE_CONFIG SET ENABLED = l_proc_enabled WHERE PROC_MODULE = 'TP_run_wk_sht';
    IF ( sql%rowcount = 0 ) THEN
        INSERT INTO PROC_MODULE_CONFIG(PROC_MODULE, PLSQL_PACKAGE, ENABLED, ITERATION)
        SELECT 'TP_run_wk_sht','pl_run_worksheet',l_proc_enabled,'01' FROM dual
        WHERE NOT EXISTS (select 1 from PROC_MODULE_CONFIG where PROC_MODULE = 'TP_run_wk_sht');
    END IF;

    UPDATE PROC_MODULE_CONFIG SET ENABLED = l_proc_enabled WHERE PROC_MODULE = 'confirm_putaway';
    IF ( sql%rowcount = 0 ) THEN
        INSERT INTO PROC_MODULE_CONFIG(PROC_MODULE, PLSQL_PACKAGE, ENABLED, ITERATION)
        SELECT 'confirm_putaway','pl_confirm_putaway',l_proc_enabled,'01' FROM dual
        WHERE NOT EXISTS (select 1 from PROC_MODULE_CONFIG where PROC_MODULE = 'confirm_putaway');
    END IF;

    -- iteration 2
    UPDATE PROC_MODULE_CONFIG SET ENABLED = l_proc_enabled WHERE PROC_MODULE = 'replen_create';
    IF ( sql%rowcount = 0 ) THEN
        INSERT INTO PROC_MODULE_CONFIG(PROC_MODULE, PLSQL_PACKAGE, ENABLED, ITERATION)
        SELECT 'replen_create','pl_create_ndm',l_proc_enabled,'02' FROM dual
        WHERE NOT EXISTS (select 1 from PROC_MODULE_CONFIG where PROC_MODULE = 'replen_create');
    END IF;

    UPDATE PROC_MODULE_CONFIG SET ENABLED = l_proc_enabled WHERE PROC_MODULE = 'tp_cte_cc';
    IF ( sql%rowcount = 0 ) THEN
        INSERT INTO PROC_MODULE_CONFIG(PROC_MODULE, PLSQL_PACKAGE, ENABLED, ITERATION)
        SELECT 'tp_cte_cc','pl_tp_cte_cc',l_proc_enabled,'02' FROM dual
        WHERE NOT EXISTS (select 1 from PROC_MODULE_CONFIG where PROC_MODULE = 'tp_cte_cc');
    END IF;

    -- iteration 3
    UPDATE PROC_MODULE_CONFIG SET ENABLED = l_proc_enabled WHERE PROC_MODULE = 'CRT_order_proc';
    IF ( sql%rowcount = 0 ) THEN
        INSERT INTO PROC_MODULE_CONFIG(PROC_MODULE, PLSQL_PACKAGE, ENABLED, ITERATION)
        SELECT 'CRT_order_proc','pl_crt_order_proc',l_proc_enabled,'03' FROM dual
        WHERE NOT EXISTS (select 1 from PROC_MODULE_CONFIG where PROC_MODULE = 'CRT_order_proc');
    END IF;

    UPDATE PROC_MODULE_CONFIG SET ENABLED = l_proc_enabled WHERE PROC_MODULE = 'order_recovery';
    IF ( sql%rowcount = 0 ) THEN
        INSERT INTO PROC_MODULE_CONFIG(PROC_MODULE, PLSQL_PACKAGE, ENABLED, ITERATION)
        SELECT 'order_recovery','pl_order_recovery',l_proc_enabled,'03' FROM dual
        WHERE NOT EXISTS (select 1 from PROC_MODULE_CONFIG where PROC_MODULE = 'order_recovery');
    END IF;

    UPDATE PROC_MODULE_CONFIG SET ENABLED = l_proc_enabled WHERE PROC_MODULE = 'awm';
    IF ( sql%rowcount = 0 ) THEN
        INSERT INTO PROC_MODULE_CONFIG(PROC_MODULE, PLSQL_PACKAGE, ENABLED, ITERATION)
        SELECT 'awm','pl_awm',l_proc_enabled,'03' FROM dual
        WHERE NOT EXISTS (select 1 from PROC_MODULE_CONFIG where PROC_MODULE = 'awm');
    END IF;

    -- iteration 4
    UPDATE PROC_MODULE_CONFIG SET ENABLED = l_proc_enabled WHERE PROC_MODULE = 'receive_ret';
    IF ( sql%rowcount = 0 ) THEN
        INSERT INTO PROC_MODULE_CONFIG(PROC_MODULE, PLSQL_PACKAGE, ENABLED, ITERATION)
        SELECT 'receive_ret','pl_receive_return',l_proc_enabled,'04' FROM dual
        WHERE NOT EXISTS (select 1 from PROC_MODULE_CONFIG where PROC_MODULE = 'receive_ret');
    END IF;

    -- iteration 5
    UPDATE PROC_MODULE_CONFIG SET ENABLED = l_proc_enabled WHERE PROC_MODULE = 'TP_signoff_from_forklift_batch';
    IF ( sql%rowcount = 0 ) THEN
        INSERT INTO PROC_MODULE_CONFIG(PROC_MODULE, PLSQL_PACKAGE, ENABLED, ITERATION)
        SELECT 'TP_signoff_from_forklift_batch','pl_tp_signoff_from_fklft_batch',l_proc_enabled,'05' FROM dual
        WHERE NOT EXISTS (select 1 from PROC_MODULE_CONFIG where PROC_MODULE = 'TP_signoff_from_forklift_batch');
    END IF;

    COMMIT;
END;
/