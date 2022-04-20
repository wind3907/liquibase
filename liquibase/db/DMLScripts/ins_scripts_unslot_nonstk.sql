
SET ECHO ON

/****************************************************************************
** Date:       NOV-26-2014
** File:       unslot_nonstk_item_qoh_zero.sh
** 
** Insert runsql "unslot_nonstk_item_qoh_zero" 
**
** Records are inserted into tables:
**    - SCRIPTS
**
****************************************************************************/

/****************************************************************************
*  unslot_nonstk_item_qoh_zero.sh
****************************************************************************/
delete from scripts where script_name like '%unslot_nonstk.sh';

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
    'unslotnonstk.sh'   script_name,   
    'MAINTENANCE'       application_func,
    'Y'                      restartable,
    0                        run_count,
    NULL                     last_run_date,
    NULL                     last_run_user,
    'Y'                      update_function,
    '-z1 -p12'               print_options,
'===== Unslot Non-Stock Item  ===== 
This program unslot non-stock item for inventory qoh+qty_alloc+qty_planned are zero.
It also checked for pending returns, putaway, replenishment and cycle count
before considering to be unslotted. It also check that there are no planned schedule POs
within 48 hours from this runtime SQL.'   
                                           display_help,
   162 option_no
  FROM DUAL
/

