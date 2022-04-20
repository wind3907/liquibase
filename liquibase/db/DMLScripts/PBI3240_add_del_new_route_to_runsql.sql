SET ECHO ON

/****************************************************************************
** Date:       28-JUN-2011
** File:       PBI3240_add_del_new_route_to_runsql.sql
**
** Insert runsql "delete_new_route.sh" that deletes user keys in route if it's 
**               in 'NEW' status.
**
** Records are inserted into tables:
**    - SCRIPTS
**
** Modification History:
**    Date     Designer Comments
**    -------- -------- ---------------------------------------------------
**    06/28/11 prppxx   PBI 3240 
**                      Project: PBI3240-Add_runsql_to_delete_new_route.
**                      Activity: PBI3240-Add_delete_new_route_to_runsql.
**                      Initial creation in SWMS 12.3
**
****************************************************************************/

/****************************************************************************
*  Insert runsql delete_new_route.sh
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
    'delete_new_route.sh'   script_name,
    'MAINTENANCE'   application_func,
    'Y'                  restartable,
    0                    run_count,
    NULL                 last_run_date,
    NULL                 last_run_user,
    'N'                  update_function,
    145                  option_no,
'Delete a given route in NEW status.' display_help
FROM DUAL
/
