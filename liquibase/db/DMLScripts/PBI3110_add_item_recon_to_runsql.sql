SET ECHO ON

/****************************************************************************
** Date:       28-JUN-2011
** File:       PBI3110_add_item_recon_to_runsql.sql
**
** Insert runsql "run_item_recon.sh" that runs Item recon report.
**
** Records are inserted into tables:
**    - SCRIPTS
**
** Modification History:
**    Date     Designer Comments
**    -------- -------- ---------------------------------------------------
**    06/28/11 prppxx   PBI 3110
**                      Project: PBI3110_add_item_recon_to_runsql - Manually
**                      run Item Recon report.
**                      Initial creation for Canada companies 274, 264 etc.
**
****************************************************************************/

/****************************************************************************
*  Insert runsql run_item_recon.sh
****************************************************************************/

INSERT INTO scripts
   (script_name,
    application_func,
    restartable,
    run_count,
    last_run_date,
    last_run_user,
    update_function,
    option_no,
    display_help)
SELECT
    'run_item_recon.sh'   script_name,
    'MAINTENANCE'   application_func,
    'Y'                  restartable,
    0                    run_count,
    NULL                 last_run_date,
    NULL                 last_run_user,
    'N'                  update_function,
    144                  option_no,
'Run Item Recon report.' display_help
FROM DUAL
/
