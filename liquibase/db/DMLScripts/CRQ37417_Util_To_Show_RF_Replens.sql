SET ECHO ON

/****************************************************************************
** Date:       28-JUN-2011
**
** Insert runsql "Util_To_Show_RF_Replens.sh".
**
** Records are inserted into tables:
**    - SCRIPTS
**
** Modification History:
**    Date     Designer Comments
**    -------- -------- ---------------------------------------------------
**
****************************************************************************/

/****************************************************************************
*  Insert runsql Util_To_Show_RF_Replens.sh
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
    'Util_To_Show_RF_Replens.sh'   script_name,
    'MAINTENANCE'            application_func,
    'Y'                      restartable,
    0                        run_count,
    NULL                     last_run_date,
    NULL                     last_run_user,
    'N'                      update_function,
    '-z1 -p12'               print_options,
'The script will display RF replenishment tasks as seen by RF users. '
                                              display_help,
   162 option_no
  FROM DUAL
/

