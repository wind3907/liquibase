
SET ECHO ON

/****************************************************************************
** Date:       09-AUG-2011
** Programmer: Brian Bent
** File:       CRQ27160_ins_script_run_sos_sls_clean.sql
** 
** Insert runsql "non_demand_repl_priority.sh".
**
** Records are inserted into tables:
**    - SCRIPTS
**
** Modification History:
**    Date     Designer Comments
**    -------- -------- ---------------------------------------------------
**    08/09/10 bben0556 Brian Bent
**                      Project:
*      R30.5--WIB#663--CRQ000000007533_Save_what_created_NDM_in_trans_RPL_record
**
****************************************************************************/

/****************************************************************************
*  Insert runsql non_demand_repl_priority.sh
****************************************************************************/

INSERT INTO scripts
   (script_name,
    application_func,
    restartable,
    run_count,
    last_run_date,
    last_run_user,
    update_function,
    print_options,
    display_help,
    option_no)
SELECT
    'non_demand_repl_priority.sh'   script_name,   
    'MAINTENANCE'            application_func,
    'Y'                      restartable,
    0                        run_count,
    NULL                     last_run_date,
    NULL                     last_run_user,
    'N'                      update_function,
    '-z1 -p12'               print_options,
'===== List Non-Demand Replenishments Showing the Task Priority ===== 
This script lists the non-demand replenishment transactions over a user
specified date range.  The listing includes the task priority and the highest
task priority that was displayed on the RF screen.'
                                           display_help,
   162 option_no
  FROM DUAL
/

