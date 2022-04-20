create or replace PACKAGE pl_run_worksheet AS
/*******************************************************************************
**Package:
**        pl_run_worksheet.sql. Migrated from TP_run_wk_sht.pc
**
**Description:
**        Opens Scheduled POs and run PO work sheet.
**
**Called by:
**        This is called from Forms/UI
*******************************************************************************/

    PROCEDURE p_execute_frm (
        i_userid          IN  VARCHAR2,
        i_func_parameters IN  VARCHAR2,
        o_status   OUT VARCHAR2
    );

END pl_run_worksheet;
/

create or replace PACKAGE BODY pl_run_worksheet IS
  ---------------------------------------------------------------------------
  -- pl_run_worksheet:
  --    Called from Oracle Forms for Scheduled POs
  --
  -- Description:
  --- Based on the Scheduled Hour PO Open is performed
  ---------------------------------------------------------------------------

    normal          NUMBER := 0;

  /*************************************************************************
  ** p_execute_frm
  **  Description: Main Program to be called from the PL/SQL wrapper/Forms
  **  Called By : DBMS_HOST_COMMAND_FUNC
  **  PARAMETERS:
  **      i_userid - User ID passed from Frontend as Input
  **      i_func_parameters - Function parameters passed from Frontend as Input
  **      o_out_status   - Output parameter returned to front end
  **
  ****************************************************************/

    PROCEDURE p_execute_frm (
        i_userid          IN  VARCHAR2,
        i_func_parameters IN  VARCHAR2,
        o_status          OUT VARCHAR2
    ) IS
        l_func_name   VARCHAR2(50) := 'pl_run_worksheet.p_execute_frm';
        v_count       NUMBER := 0;
        l_err_msg     VARCHAR2(4000);
        l_hour_passed_fr VARCHAR2(8);
        l_hour_passed_to VARCHAR2(8);
        v_prams_list  c_prams_list;
    BEGIN
        v_prams_list := F_SPLIT_PRAMS(i_func_parameters);
        v_count := v_prams_list.count;
        pl_text_log.ins_msg_async('INFO', l_func_name, 'F_SPLIT_PRAMS invoked...', sqlcode, sqlerrm);
        pl_text_log.ins_msg_async('INFO', l_func_name, 'F_SPLIT_PRAMS size:' || v_count, sqlcode, sqlerrm);

        IF v_count >= 2 THEN
            /* fromHour and toHour has been passed in the param list  */
            pl_text_log.ins_msg_async('INFO', l_func_name, 'Param List : ' || v_prams_list(1) || ',' || v_prams_list(2), sqlcode, sqlerrm);

            /* To hours and From hours are received as day fractions from Forms.
               Need to convert the day fraction to time of the day because pl_rcv_po_open.p_open_po_main expect in that format
             */
            SELECT
                TO_CHAR(TO_DATE(ROUND(TO_NUMBER(v_prams_list(1)) * 86400), 'sssss'), 'hh24:mi:ss'),
                TO_CHAR(TO_DATE(ROUND(TO_NUMBER(v_prams_list(2)) * 86400), 'sssss'), 'hh24:mi:ss')
            INTO l_hour_passed_fr, l_hour_passed_to
            FROM DUAL;

            pl_text_log.ins_msg_async('INFO', l_func_name, 'Schedule From Hour : ' || l_hour_passed_fr || ', Schedule To Hour : ' || l_hour_passed_to, sqlcode, sqlerrm);
            pl_rcv_po_open.p_open_po_main(NULL, l_hour_passed_fr, l_hour_passed_to, 'N', l_err_msg);
        ELSE
            /* fromHour and toHour has not been passed. Function has been invoked by swms_oper_daily.sh
            generate worksheets and labels according to syspar putaway_method */
            pl_text_log.ins_msg_async('INFO', l_func_name, 'fromHour and toHour has not been passed', sqlcode, sqlerrm);
            pl_rcv_po_open.p_open_po_main(NULL, NULL, NULL, 'N', l_err_msg);
        END IF;

        o_status := l_err_msg;
    EXCEPTION WHEN OTHERS THEN
        pl_text_log.ins_msg_async('WARN', l_func_name, 'Exception Raised at ' || l_func_name || 'for params ' || i_func_parameters, sqlcode, sqlerrm);
        o_status := 'FAILURE';
    END p_execute_frm;

END pl_run_worksheet;
/

grant execute on pl_run_worksheet to swms_user;
