SET ECHO ON

/****************************************************************************
** Date:       05-DEC-2012
** File:       CRQ40607_upd_scripts.sql
**
** Updates the Update_Function column in SCRIPTS table and deletes some unwanted records.
**
** Records are updated in table:
**    - SCRIPTS
**
** Modification History:
**
****************************************************************************/

/* Update the update_function flag to 'Y' for the following scripts - 'add_ibm_printer','evencube2','even_paltype','even_slottype','oddcube2','odd_paltype','odd_slott
ype','update_abc_days','upd_fifo_4_items_in_area_c.sh','update_cc','update_lexmark_filter','create_missing_labels.sh','del_t_batch.sh','change_loc_status.sh'
*/

update scripts set update_function='Y' where script_name in ('add_ibm_printer','evencube2','even_paltype','even_slottype','oddcube2','odd_paltype','odd_slott
ype','update_abc_days','upd_fifo_4_items_in_area_c.sh','update_cc','update_lexmark_filter','create_missing_labels.sh','del_t_batch.sh','change_loc_status.sh'
);


/* Update the update_function flag to 'N' for the following scripts - 'float_cube','qoh_gt_2wm','repl_cnt_by_day','repl_cnt_by_item','repl_cnt_g1w_by_item','repl_cnt_
l1w_by_item','show_repl.exe','wm_cub_gt_pkslt_cub','cool_item_in_order.sh'
*/

update scripts set update_function='N' where script_name in ('float_cube','qoh_gt_2wm','repl_cnt_by_day','repl_cnt_by_item','repl_cnt_g1w_by_item','repl_cnt_
l1w_by_item','show_repl.exe','wm_cub_gt_pkslt_cub','cool_item_in_order.sh');


/* Delete the following scripts from the SCRIPTS table - 'mike','passwd','itemloc','perkins','print_queues','ordersgo','trans_data','ordm_hist_info','pm_no_cost.sh','update
_abc_cc','clean_ndrepl_fl_batch','invalid_slot_dimensions','212_postvalidation.sh','whmove_create_inv.sql','HACCP_item_changes.sh
*/

delete from scripts where script_name in ('mike','passwd','itemloc','perkins','print_queues','ordersgo','trans_data','ordm_hist_info','pm_no_cost.sh','update
_abc_cc','clean_ndrepl_fl_batch','invalid_slot_dimensions','212_postvalidation.sh','whmove_create_inv.sql','HACCP_item_changes.sh');

COMMIT;
/
