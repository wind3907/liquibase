SET ECHO ON

/****************************************************************************
** Date:       28-JUN-2011
** File:       PBI3110_add_item_recon_to_runsql.sql
**
** Insert runsql "upd_fifo_4_items_in_area_c.sh".
**
** Records are inserted into tables:
**    - SCRIPTS
**
** Modification History:
**    Date     Designer Comments
**    -------- -------- ---------------------------------------------------
**    06/28/11 prppxx   CRQ27400
**                      Project: CRQ27400_Change_fifo_4_item_in_area_c.
**                      This script will update the fifo flag to A or S for 
**			all non-exp-date track, non-mfg-date track items
**                      in C area.
**			Initial creation due to performance in 11g.  
**
****************************************************************************/

/****************************************************************************
*  Insert runsql upd_fifo_4_items_in_area_c.sh
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
    'upd_fifo_4_items_in_area_c.sh'   script_name,
    'MAINTENANCE'            application_func,
    'Y'                      restartable,
    0                        run_count,
    NULL                     last_run_date,
    NULL                     last_run_user,
    'N'                      update_function,
    '-z1 -p12'               print_options,
'The script will update the fifo flag to A or S
for all non-exp/mfg date track items in area C. '
                                              display_help,
   146 option_no
  FROM DUAL
/

