
/**************************************************************************/
-- Package Specification
/**************************************************************************/
CREATE OR REPLACE PACKAGE swms.pl_common
IS

   -- sccs_id=@(#) src/schema/plsql/pl_common.sql, swms, swms.9, 10.2 2/17/09 1.12

   ---------------------------------------------------------------------------
   -- Package Name:
   --    pl_common
   --
   -- Description:
   --    Common procedures and functions within SWMS.
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    10/23/01 prpbcb   rs239a DN 10700  Created.
   --    02/20/02 prplhj   DN 10772 Added f_create_trans(), p_get_unique_lp().
   --    05/20/02 prphqb   DN 10787 Added functions to check pending puts
   --      f_get_putcount_b4swp for swap
   --      f_get_putcount_b4xfr for transfer
   --        f_get_putcount_b4hst for home slot transfer
   --    10/02/02 prpbcb   rs239a DN 11043  rs239b  DN 11074
   --                      RDC non-dependent changes.
   --                      Added function f_get_first_pick_slot.
   --
   --    01/05/05 prpbcb   Oracle 8 rs239b swms9 DN 11848
   --                      Add function f_wrap_line.
   --
   --    05/15/05 prpbcb   Oracle 8 rs239b swms9 DN 11490
   --                      Discrete selection changes.
   --                      Add function f_is_clam_bed_tracked_item.
   --                      It calls
   --                      pl_putaway_utilities.f_is_clam_bed_tracked_item
   --                      which returns a boolean.  We want to return 'Y' or
   --                      'N' so the function can be used in a SQL statement.
   --                      Add function f_is_cool_tracked_item.
   --                      It calls
   --                      pl_putaway_utilities.f_is_cool_tracked_item
   --                      which returns a boolean.  We want to return 'Y' or
   --                      'N' so the function can be used in a SQL statement.
   --
   --    02/22/07 prpbcb   DN 12214
   --                      Ticket: 326211
   --                      Project: 326211-Miniload Induction Qty Incorrect
   --                      Added function f_get_new_pallet_id.  It was
   --                      copied from pl_rcv_open_po_pallet_list.sql and
   --                      pl_rcv_open_po_pallet_list.sql was changed to call
   --                      it.  This was done because it was a local
   --                      function in pl_rcv_open_po_pallet_list and other
   --                      areas of SWMS need to use it.
   --    03/13/07 prppxx   D#12221
   --                      Add function f_loc_sort to handle order by location 
   --                      for a cursor proc_curdor in req_cc_area.pc.
   --    09/27/07 prppxx   D#12286
   --                      Add function f_get_dmd_repl_4swp to detect demand 
   --                      replenishment task for a given (home) slot.
   --              Add procedure p_del_cc to cancel cycle count. This is
   --              called by miniload program when inventory is deleted.
   --
   --    10/22/07 prpbcb   DN 12297
   --                      Ticket: 484515
   --                      Project: 484515-Menu Access Security
   --
   --                      Added function f_is_corporate_user.
   --
   --    05/20/08 prpbcb   DN 12388
   --                      Project:
   --                           607473-SWMS User Removed But Still a SOS User
   --                      Add procedure safe_to_delete_user() which check
   --                      it if OK to delete a user from the USR table.
   --    06/26/08 prpbcb   DN 12393
   --                      Project: 614893-Check Last Ship Slot Height
   --                      Added f_boolean_text.
   --
   --    02/12/09 prppxx   DN 12461
   --                      Project: CRQ6187-Prevent Swap with Pending putaway 
   --               	   to BCK Loc. Change f_get_putcount_b4swp to handle BCK loc.
   --
   --    11/16/15 chua6448 Charm 6000003010
   --                      Project: Modify the Swap Logic
   --
   --    01/11/16 skam7488 Charm #6000008481. Modified the logic to determine
   --                      the corporate user.
   --
   --    02/06/16 Sont9212 As part of live receiving, we added a check upc function which
   --                      Validates UPC and calculates the upc comp flag.
   --    07/12/18 mpha8134 Meat company changes: add function to check if 
   --                      a PO is an internal production PO 
   --
   --    11/28/18 sban3548 Prevent SWap with Pending putaway to FRONT Location with a
   --                      change to f_get_putcount_b4swp
   --
   --    10/24/19 sban3548 Added function to transfer child pallet out of BULK CDK pallet and 
   --						Transfer BULK CDK pallet to different reserve location in 4, 0, 2 rules
   --
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    06/30/21 bben0556 Brian Bent
   --                      Card:
   --                R47-xdock-OPCOF3380_OP_Site_1_Build_pallets_by_number_of_stops_syspar
   --
   --                      Added function "get_company_no" by copying and
   --                      modifing "f_get_company_no()" in pl_lm_sel.sql
   --
   --  08-Oct-2021 pkab6563 - Copied function get_user_equip_id(i_user_id)
   --                         from RDC SWMS for Jira 3700 to allow signoff
   --                         from forklift batches.
   ---------------------------------------------------------------------------

   ---------------------------------------------------------------------------
   -- Global Type Declarations
   ---------------------------------------------------------------------------

   ---------------------------------------------------------------------------
   -- Global Variables
   ---------------------------------------------------------------------------

   ---------------------------------------------------------------------------
   -- Public Constants
   ---------------------------------------------------------------------------

   ct_sql_success          NUMBER(1) := 0;
   ct_sql_no_data_found    NUMBER(4) := 1403;

   ---------------------------------------------------------------------------
   -- Public Modules
   ---------------------------------------------------------------------------

   -----------------------------------------------------------------------
   -- Function:
   --    f_get_syspar
   --
   -- Description:
   -- This function selects the value of a syspar.
   --
   -- Parameters:
   --    i_config_flag_name  - Name of the syspar.  Converted to upper case
   --                          in the select statement.
   --    i_value_if_null     - Value to use for the syspar if it is null
   --                          in the database or does not exist.
   --                          This is OPTIONAL.
   --
   
   -- Return Values:
   --    Value of the syspar.  If the syspar is not found or is null then
   --    i_value_if_null is returned if passed as a parameter otherwise
   --    null is returned.
   --
   -- Exceptions raised:
   --    -20001  An oracle error occurred.
   ---------------------------------------------------------------------
   FUNCTION f_get_syspar
      (i_config_flag_name IN sys_config.config_flag_name%TYPE,
       i_value_if_null    IN VARCHAR2 := NULL)
   RETURN VARCHAR2;

   -- Create transaction record (trans table.)
   -- Requirements on i_trans_rec (trans%ROWTYPE) argument:
   --   1) No trans_type, error (return -1).
   --   2) No trans_date, default to today's date.
   --   3) No user_id, default to current user.
   -- Requirements on i_upload_time_type argument that is used to set the
   -- upload_time column:
   --   1) no input or null, system sets to 01011980 to send up to SUS.
   --   2) = 'na'/'NA', system sets to null to NOT send to SUS.
   --   3) any non-null/'na' value, system sets to the value as date format of
   --      MMDDRR, where MM is month, DD is date and RR is year.
   -- Requirements on i_create_trans_type argument:
   --   no input or null, if trans_type doesn't exist before, error (return -3).
   --   nonnull, create a trans_type record from i_create_trans_type value if
   --     the trans_type record doesn't exist before. No effect if trans_type
   --     record exists. The format and order for i_create_trans_type must be in
   --     the following (each field is seperated by a '|'):
   --       <trans_type>|<retention_days>|<inv_affecting-Y/N>|<descrip>
   --     Retention days will default to 55, inv_affecting will default to N and
   --     description will default to 'No description available' if only
   --     trans_type is provided or any of the field value is not provided.
   -- Returns:
   --   sqlcode or
   --   -1 if no trans_type value is provided or
   --   -2 if i_upload_time_type is set and is not 'na' and the
   --  format is not MMDDRR or
   --   -3      if i_trans_rec.trans_type doesn't exist in trans_type table.
   FUNCTION f_create_trans (
     i_trans_rec  IN  trans%ROWTYPE,
     i_upload_time_type  IN  VARCHAR2 DEFAULT NULL,
     i_create_trans_type IN  VARCHAR2 DEFAULT NULL)
   RETURN NUMBER;

   -- Create transaction record (trans table.)
   -- This is an overloaded function with "IN trans%ROWTYPE". This function can
   -- be used when it is called using the NAMED PARAMETERS (i.e., using "=>"
   -- method.) Only trans_type value is required. See more details from the
   -- descriptions on the same overloaded function f_create_trans with parameter
   -- "IN trans%ROWTYPE".
   FUNCTION f_create_trans (
     i_trans_type  IN  trans.trans_type%TYPE,
     i_prod_id   IN  trans.prod_id%TYPE DEFAULT NULL,
     i_rec_id   IN  trans.rec_id%TYPE DEFAULT NULL,
     i_lot_id   IN  trans.lot_id%TYPE DEFAULT NULL,
     i_exp_date   IN  trans.exp_date%TYPE DEFAULT NULL,
     i_weight   IN  trans.weight%TYPE DEFAULT NULL,
     i_temp   IN  trans.temp%TYPE DEFAULT NULL,
     i_mfg_date   IN  trans.mfg_date%TYPE DEFAULT NULL,
     i_qty_expected  IN  trans.qty_expected%TYPE DEFAULT NULL,
     i_uom_expected  IN  trans.uom_expected%TYPE DEFAULT NULL,
     i_qty   IN  trans.qty%TYPE DEFAULT NULL,
     i_uom   IN  trans.uom%TYPE DEFAULT NULL,
     i_src_loc   IN  trans.src_loc%TYPE DEFAULT NULL,
     i_dest_loc   IN  trans.dest_loc%TYPE DEFAULT NULL,
     i_user_id   IN  trans.user_id%TYPE DEFAULT USER,
     i_order_id   IN  trans.order_id%TYPE DEFAULT NULL,
     i_route_no   IN  trans.route_no%TYPE DEFAULT NULL,
     i_stop_no   IN  trans.stop_no%TYPE DEFAULT NULL,
     i_truck_no   IN  trans.truck_no%TYPE DEFAULT NULL,
     i_cmt   IN  trans.cmt%TYPE DEFAULT NULL,
     i_old_status  IN  trans.old_status%TYPE DEFAULT NULL,
     i_new_status  IN  trans.new_status%TYPE DEFAULT NULL,
     i_reason_code  IN  trans.reason_code%TYPE DEFAULT NULL,
     i_adj_flag   IN  trans.adj_flag%TYPE DEFAULT NULL,
     i_pallet_id  IN  trans.pallet_id%TYPE DEFAULT NULL,
     i_order_line_id  IN  trans.order_line_id%TYPE DEFAULT NULL,
     i_batch_no   IN  trans.batch_no%TYPE DEFAULT NULL,
     i_sys_order_id  IN  trans.sys_order_id%TYPE DEFAULT NULL,
     i_sys_order_line_id IN  trans.sys_order_line_id%TYPE DEFAULT NULL,
     i_order_type  IN  trans.order_type%TYPE DEFAULT NULL,
     i_returned_prod_id  IN  trans.returned_prod_id%TYPE DEFAULT NULL,
     i_diff_weight  IN  trans.diff_weight%TYPE DEFAULT NULL,
     i_ilr_upload_time  IN  trans.ilr_upload_time%TYPE DEFAULT NULL,
     i_cust_pref_vendor  IN  trans.cust_pref_vendor%TYPE DEFAULT NULL,
     i_clam_bed_no  IN  trans.clam_bed_no%TYPE DEFAULT NULL,
     i_warehouse_id  IN  trans.warehouse_id%TYPE DEFAULT NULL,
     i_float_no   IN  trans.float_no%TYPE DEFAULT NULL,
     i_bck_dest_loc  IN  trans.bck_dest_loc%TYPE DEFAULT NULL,
     i_upload_time_type  IN  VARCHAR2 DEFAULT NULL,
     i_create_trans_type IN  VARCHAR2 DEFAULT NULL)
   RETURN NUMBER;

   -- Get unique license plate from the system.
   -- O_licPlate has the next license plate #. O_status has sqlcode.
   -- If o_status <> 0, o_licPlate has value of -1.
   PROCEDURE p_get_unique_lp (
     o_licPlate            OUT putawaylst.pallet_id%TYPE,
     o_status              OUT NUMBER);

   ---------------------------------------------------------------------
   -- Function:
   --    f_get_putcount_b4swp
   --
   -- Description:
   -- This function returns >0 for BAD, 0 for OK status of an inventory record
   -- before subjecting it to SWP
   -- The thinking is unless the item has been confirmed-putaway and all tracked
   -- attributes such as weight, temperature have been collected, the item is
   -- not available to be SWP.
   -- This does not apply to REPLENISHMENT nor ORDER PROCESSING
   --
   -- Parameters:
   --    i_srcloc            - FROM location that is the place where INV is
   --                          about to lose qty
   --    i_prodid            - item number
   --    i_cpv               - cpv
   --
   -- Return Values:
   --    >0 if BAD, 0 if OK to perform SWP operation
   --
   -- Exceptions raised:
   ---------------------------------------------------------------------
   FUNCTION f_get_putcount_b4swp
      (i_srcloc           IN putawaylst.dest_loc%TYPE)
   RETURN NUMBER;
   ---------------------------------------------------------------------
   -- Function:
   --    f_get_putcount_b4xfr
   --
   -- Description:
   -- This function returns >0 for BAD, 0 for OK status of an inventory record
   -- before subjecting it to XFR
   -- The thinking is unless the item has been confirmed-putaway
   -- the item is not available to be XFR.
   -- This does not apply to REPLENISHMENT nor ORDER PROCESSING
   --
   -- Parameters:
   --    i_palletid          - pallet_id that is the place where INV is
   --                          about to lose qty
   -- Return Values:
   --    >0 if BAD, 0 if OK to perform XFR operation
   --
   -- Exceptions raised:
   ---------------------------------------------------------------------
   FUNCTION f_get_putcount_b4xfr
      (i_palletid         IN putawaylst.pallet_id%TYPE)
   RETURN NUMBER;
   ---------------------------------------------------------------------
   -- Function:
   --    f_get_putcount_b4hst
   --
   -- Description:
   -- This function returns >0 for BAD, 0 for OK status of an inventory record
   -- before subjecting it to HST
   -- The thinking is unless the item has been confirmed-putaway and all tracked
   -- attributes such as weight, temperature have been collected, the item is
   -- not available to be HST.
   -- This does not apply to REPLENISHMENT nor ORDER PROCESSING
   --
   -- Parameters:
   --    i_srcloc            - FROM location that is the place where INV is
   --
   -- Return Values:
   --    >0 if BAD, 0 if OK to perform HST operation                               -- Exceptions raised:
   ---------------------------------------------------------------------
   FUNCTION f_get_putcount_b4hst
      (i_srcloc           IN putawaylst.dest_loc%TYPE)
   RETURN NUMBER;
   ---------------------------------------------------------------------

   -----------------------------------------------------------------------
   -- Function:
   --    f_get_first_pick_slot
   --
   -- Description:
   --    RCD non-dependent changes.
   --    This function returns the first pick slot for an item within a
   --    range of slots.  The slot range is optional.
   --
   --    For a slotted item and not searching over a location range the
   --    location returned will be the rank 1 case home slot.  If searching
   --    over a location range then the location returned is the lowest
   --    rank case home and if no case home found the lowest rank split
   --    home within the location range.  If the item is not within the
   --    location range null is returned.
   --
   --    For a floating item (not slotted in this context) and not
   --    searching over a location range the location returned will be the
   --    min(location) from inventory.  If searching over a location
   --    range the location returned will be the min(location) within
   --    the location range.  If the item is not within the location
   --    range null is returned.  If the item does not exist in inventory
   --    null is returned.
   --
   --    This function is used in form mh2sa.fmb and in reports mh2ra.sql
   --    and mh2rb.sql.  The form and the reports are used to edit the case
   --    and split dimemsions for an item.  There was a requirement to be
   --    able to order the items by location in the form and the on the
   --    reports so this function was created.
   --
   -- Parameters:
   --    i_prod_id          - Item
   --    i_cust_pref_vendor - Customer preferred vendor for the item.
   --    i_from_loc         - Starting location when looking over a location
   --                         range.  Optional.
   --    i_to_loc           - Ending location when looking over a location
   --                         range.  Optional.
   --
   -- Return Values:
   --    The first pick slot or null.
   --
   -- Exceptions raised:
   --    -20001  An oracle error occurred.
   --    -20002  Missing the from loc or the to loc.  Both must be
   --            entered or left null.
   ---------------------------------------------------------------------
   FUNCTION f_get_first_pick_slot
      (i_prod_id           IN   pm.prod_id%TYPE,
       i_cust_pref_vendor  IN   pm.cust_pref_vendor%TYPE,
       i_from_loc          IN   loc.logi_loc%TYPE DEFAULT NULL,
       i_to_loc            IN   loc.logi_loc%TYPE DEFAULT NULL)
   RETURN VARCHAR2;

   ------------------------------------------------------------------------
   -- Function:
   --    f_is_clam_bed_tracked_item
   --
   -- Description:
   --    This function determines if an item is clam bed tracked.
   --    Return 'Y' if item is clam bed tracked otherwise 'N'.
   --    It calls pl_putaway_utilities.f_is_clam_bed_tracked_item which
   --    returns a boolean.  We want to return 'Y' or 'N' so the function
   --    can be used in a SQL statement.
   ------------------------------------------------------------------------
   FUNCTION f_is_clam_bed_tracked_item
                 (i_category                IN pm.category%TYPE,
                  i_clam_bed_tracked_syspar IN sys_config.config_flag_val%TYPE)
   RETURN VARCHAR2;

   ------------------------------------------------------------------------
   -- Function:
   --    f_is_cool_tracked_item
   --
   -- Description:
   --    This function determines if an item is cool tracked.
   --    Return 'Y' if item is cool tracked otherwise 'N'.
   --    It calls pl_putaway_utilities.f_is_cool_tracked_item which
   --    returns a boolean.  We want to return 'Y' or 'N' so the function
   --    can be used in a SQL statement.
   ------------------------------------------------------------------------
   FUNCTION f_is_cool_tracked_item
                 (i_prod_id   IN pm.prod_id%TYPE,
                  i_cpv       IN pm.cust_pref_vendor%TYPE)
   RETURN VARCHAR2;

   ------------------------------------------------------------------------
   -- Function:
   --    f_wrap_line
   --
   -- Description:
   --    This function word wraps text to a specified length.  A CHR(10) is
   --    inserted into the text.
   ------------------------------------------------------------------------
   FUNCTION f_wrap_line(i_text      IN VARCHAR2,
                        i_wrap_len  IN PLS_INTEGER DEFAULT 60)
   RETURN VARCHAR2;


---------------------------------------------------------------------------
-- Function:
--    f_get_new_pallet_id
--
-- Description:
--    This function returns the next available LP.  The LP comes from
--    sequence pallet_id_seq.
--
-- Parameters:
--    None
--
-- Exceptions raised:
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Called by:  (list not complete)
--    - pl_rcv_open_po_pallet_list.f_get_new_pallet_id
--    - Form mm3sa.fmb
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    02/22/06 prpbcb   Created
---------------------------------------------------------------------------
FUNCTION f_get_new_pallet_id
RETURN VARCHAR2;

------------------------------------------------------------------------
-- Function:
--    f_loc_sort
--
-- Description:
--    This function is used to re-arrange the group and order
--    of the selected records in cursor prod_cursor (req_cc_area.pc).
--    It returns back with the number of 'PROD' type of cycle count
--    tasks group by items and in the order of location.
-- Called by: 
--    req_cc_area.pc
------------------------------------------------------------------------
FUNCTION f_loc_sort(i_area      IN VARCHAR2,
                    i_user_id      IN cc.user_id%TYPE DEFAULT NULL,
                    i_prod_id   IN pm.prod_id%TYPE,
                    i_cpv       IN pm.cust_pref_vendor%TYPE)
RETURN NUMBER;


---------------------------------------------------------------------
-- Function:
--    f_get_dmd_repl_4swp
--
-- Description:
-- This function returns >0 for BAD, 0 for OK status of an inventory record
-- before subjecting it to SWP
-- If the item has dmd-replenishment task existing, the item is
-- not available to be SWP.
--
-- Parameters:
--    i_srcloc            - FROM location that is the place where INV is
--                          about to lose qty
--    i_prodid            - item number
--    i_cpv               - cpv
--
-- Return Values:
--    >0 if BAD, 0 if OK to perform SWP operation
--
-- Exceptions raised:
---------------------------------------------------------------------
FUNCTION f_get_dmd_repl_4swp
      (i_srcloc           IN replenlst.dest_loc%TYPE)
RETURN NUMBER;

---------------------------------------------------------------------
-- Function:
--    f_get_ndm_repl_4swp
--
-- Description:
-- This function returns >0 for BAD, 0 for OK status of an inventory record
-- before subjecting it to SWP
-- If the item has ndm-replenishment task with not PRE/NEW status existing
-- the item is not available to be SWP.
--
-- Parameters:
--    i_loc_src_dest      - FROM location that is the place where INV has
--                          NDM replenishment
--
-- Return Values:
--    >0 if BAD, 0 if OK to perform SWP operation
--
-- Exceptions raised:
---------------------------------------------------------------------
FUNCTION f_get_ndm_repl_4swp(i_loc_src_dest IN replenlst.dest_loc%TYPE)
RETURN NUMBER;

---------------------------------------------------------------------
-- Function:
--    f_get_ndm_pre_new_repl_4swp
--
-- Description:
-- This function returns <0 for BAD, >=0 for OK status of an inventory record
-- before subjecting it to SWP
--
-- Parameters:
--    i_loc_src_dest      - FROM location that is the place where INV has
--                          NDM replenishment
--
-- Return Values:
--    <0 if BAD, >=0 is for the count of NDM replenishment with PRE/NEW 
--    status for one location
--
-- Exceptions raised:
---------------------------------------------------------------------
FUNCTION f_get_ndm_pre_new_repl_4swp(i_loc_src_dest IN replenlst.dest_loc%TYPE)
RETURN NUMBER;

---------------------------------------------------------------------
-- Function:
--    f_get_inv_hold_4swp
--
-- Description:
-- This function returns >0 for BAD, 0 for OK status of an inventory record
-- before subjecting it to SWP
-- If the item has hold inv existing, the item is
-- not available to be SWP.
--
-- Parameters:
--    i_loc_src_dest      - FROM location that is the place where INV has
--                          hold inventory
--
-- Return Values:
--    >0 if BAD, 0 if OK to perform SWP operation
--
-- Exceptions raised:
---------------------------------------------------------------------
FUNCTION f_get_inv_hold_4swp(i_loc_src_dest IN replenlst.dest_loc%TYPE)
RETURN NUMBER;

---------------------------------------------------------------------
-- Function:
--    f_check_ndm_pre_repl_4swp
--
-- Description:
-- This function returns >0 for BAD, 0 for OK status of an inventory has
-- NDM replenishment with PRE/NEW status only
--
-- Parameters:
--    i_loc_src_dest      - FROM location that is the place where INV has
--                          NDM replenishment with PRE/NEW status
--
-- Return Values:
--    >0 if BAD, 0 if OK to perform SWP operation
--
-- Exceptions raised:
---------------------------------------------------------------------
FUNCTION f_check_ndm_pre_repl_4swp(i_loc_src_dest IN replenlst.dest_loc%TYPE)
RETURN NUMBER;

---------------------------------------------------------------------
-- Procedure:
--    p_del_cc
--
-- Description:
-- This procedure cancels cycle count adjustment for the given pallet_id,
-- prod_id and insert CAR/CAD based on the input trans_type.
-- not available to be SWP.
--
-- Parameters:
--    i_logi_loc          - license plate number
--    i_phys_loc          - physical location
--    i_prod_id           - item number
--    i_cpv               - cpv
--    i_trans_typ     - transaction type
--
-- Return Values:
--    >0 if BAD, 0 if OK to perform SWP operation
--
-- Exceptions raised:
---------------------------------------------------------------------
PROCEDURE  p_del_cc (i_logi_loc      IN      cc.logi_loc%TYPE,
             i_phys_loc      IN      cc.phys_loc%TYPE,
                     i_prod_id       IN      cc.prod_id%TYPE,
             i_cpv       IN      cc.cust_pref_vendor%TYPE,
                     i_trans_typ     IN      trans.trans_type%TYPE DEFAULT 'CAD');


---------------------------------------------------------------------------
-- Function:
--    f_is_corporate_user
--
-- Description:
--    This function returns TRUE if the user is a Corporate user
--    otherwise FALSE is returned.
--
-- Parameters:
--    i_user_id    - User to check.
--
-- Exceptions raised:
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Called by:  (list not complete)
--    - Form mu1sa.fmb
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    10/22/07 prpbcb   Created
---------------------------------------------------------------------------
FUNCTION f_is_corporate_user(i_user_id  IN usr.user_id%TYPE)
RETURN BOOLEAN;


---------------------------------------------------------------------------
-- Procedure:
--    safe_to_delete_user
--
-- Description:
--    This procedure determines if it is OK to delete a user from the
--    USR table.
--
-- Parameters:
--    i_user_id               - User to check.
--    o_ok_to_delete_user_bln - TRUE if it is OK to delete the user
--                              FALSE otherwise.
--    o_msg                   - Reason why the user cannot be deleted.
--                              It is populated when o_ok_to_delete_user_bln
--                              is set to FALSE.
--
-- Exceptions raised:
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Called by:  (list not complete)
--    - Form mu1sa.fmb
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    05/20/08 prpbcb   Created
---------------------------------------------------------------------------
PROCEDURE safe_to_delete_user
             (i_user_id                IN  usr.user_id%TYPE,
              o_ok_to_delete_user_bln  OUT BOOLEAN,
              o_msg                    OUT VARCHAR2);


---------------------------------------------------------------------------
-- Function:
--    f_boolean_text
--
-- Description:
--    This function returns the string TRUE or FALSE for a boolean.
--
-- Parameters:
--    i_boolean - Boolean value
--  
-- Return Values:
--    'TRUE'  - When boolean is TRUE.
--    'FALSE' - When boolean is FALSE.
--
-- Exceptions raised:
--    pl_exc.e_database_error  - Got an oracle error.
-- 
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    07/10/08 prpbcb   Created.
--                      This was/is a private function in other packages.
--                      Added it here so it can be used by any package.
---------------------------------------------------------------------------
FUNCTION f_boolean_text(i_boolean IN BOOLEAN)
RETURN VARCHAR2;

--------------------------------------------------------------------------------
-- Function:
--    Check_upc
--
-- Description:
--    This function validates the UPC and also checks whether UPC need to be collected or Not.
--
-- Parameters:
--    i_prod_id        - Product Id for which the UPC data collect to be checked.
--    i_rec_id         - Po number.
--    i_func_name      - Describes the name of the option
--                       i.e "PUTAWAY" = 1, "RECEIVING" = 2, "CYCLE_CNT" = 3, "WAREHOUSE" = 4
--
-- Returns:
--   upc_comp_flag     Function will return one of the following values either N - Collect upc Data or Y - Not collect Data
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- --------------------------------------------------------
--    02/01/17 sont9212 Sunil Ontipalli, authored
--------------------------------------------------------------------------------
FUNCTION Check_upc( i_prod_id               IN  pm.prod_id%type
                   ,i_rec_id                IN  upc_info.rec_id%type
                   ,i_func_name             IN  PLS_INTEGER
                   )
  RETURN VARCHAR2;


-----------------------------------------------------------------------
--  Function:
--    f_is_internal_production_po
--
--  Description:
--    This function returns true if the erm_id passed in is set up to 
--    auto open the specialty PO. 'ENABLE_FINISH_GOODS' syspar must be
--    turned on and the erm.source_id must match the syspar 'SPECIALTY_VENDOR_ID'
--
--  Parameters:
--    i_erm_id IN erm.erm_id%TYPE
--
--  RETURN VALUES:
--    TRUE ENABLE_FINISH_GOODS syspar is 'Y' and if 
--          erm.source_id is equal to SPECIALTY_VENDOR_ID syspar and 
--    FALSE otherwise
--
--  Date       Designer  Comments
--  --------   --------  --------------------------------------------
--  06/25/18   mpha8134  Created
---------------------------------------------------------------------
FUNCTION f_is_internal_production_po(i_erm_id IN erm.erm_id%TYPE)
  RETURN BOOLEAN;

---------------------------------------------------------------------
--  FUNCTION:
--    f_is_raw_material_route
--
--  DESCRIPTION:
--    This function check to see if the route_no, passed as a parameter,
--    is a "raw material" route.
--  PARAMETERS:
--    i_route_no IN route.route_no%TYPE
--  
--  Date      Designer  Comments  
--  --------  --------  ---------------------------------------------
--  01/30/19  mpha8134  Created for Jira 707
---------------------------------------------------------------------
FUNCTION f_is_raw_material_route(i_route_no IN route.route_no%TYPE)
  RETURN CHAR;  

---------------------------------------------------------------------
--  FUNCTION:
--    f_cdk_pallet_transfer
--
--  DESCRIPTION:
--    This function is to transfer the cross dock pallet out of cross dock location 
-- 
--  PARAMETERS:
--    
--  
--  Date      Designer  Comments  
--  --------  --------  ---------------------------------------------
--  10/24/19  sban3548  Created for Jira-opcof-2614
---------------------------------------------------------------------
FUNCTION f_cdk_pallet_transfer(i_parent_child_flag IN NUMBER, 
								i_pallet_id IN inv.logi_loc%TYPE, 
								i_from_loc  IN inv.plogi_loc%TYPE,
								i_to_loc	IN inv.plogi_loc%TYPE)
RETURN NUMBER;

-----------------------------------------------------------------------
-- Function:
--    get_user_equip_id
--
-- Description:
--    This function returns the users equiment id.
--    If not found or an error the null is returned.
---------------------------------------------------------------------
FUNCTION get_user_equip_id(i_user_id  IN  usr.user_id%TYPE)
RETURN VARCHAR2;


-----------------------------------------------------------------------
-- Function:
--    get_company_no
--
-- Description:
--    This function returns the company number selected from the
--    MAINTENANCE table trimmed of any leading or trailing spaces.
--    If not found then NULL is returned.
--
--    It is expected the value in the MAINTENANCE table will have
--    this format:
--       <opco number>:<opco name>    Example: 024:Chicago
---------------------------------------------------------------------
FUNCTION get_company_no
RETURN VARCHAR2;

   ------------------------------------------------------------------------
   -- Function:
   --    f_zone_rule
   --
   -- Description:
   --    This function returns the rule id.
   ------------------------------------------------------------------------
   FUNCTION f_zone_rule(i_zone_id zone.zone_id%TYPE)
   RETURN zone.rule_id%type;


END pl_common;
/


/**************************************************************************/
-- Package Body
/**************************************************************************/
CREATE OR REPLACE PACKAGE BODY swms.pl_common
IS

   -- sccs_id=@(#) src/schema/plsql/pl_common.sql, swms, swms.9, 10.2 2/17/09 1.12

   ---------------------------------------------------------------------------
   -- Package Name:
   --    pl_common
   --
   -- Description:
   --    Common procedures and functions within SWMS.
   --
   --    Date     Designer Comments
   --    -------- -------  ----------------------------------------------------
   --    10/23/01 prpbcb   DN _____  Created.
   --    02/20/02 prplhj   DN 10772 Added f_create_trans(), p_get_unique_lp().
   ---------------------------------------------------------------------------

   ---------------------------------------------------------------------------
   -- Private Global Variables
   ---------------------------------------------------------------------------
   gl_pkg_name   VARCHAR2(20) := 'pl_common';   -- Package name.  Used in
                                                -- error messages.
      TYPE recCcProd IS RECORD (
        prod_id       pm.prod_id%TYPE,
        cpv           pm.cust_pref_vendor%TYPE,
        prod_cnt      number);
      TYPE tabCcProd IS TABLE OF recCcProd
        INDEX BY BINARY_INTEGER;

   ---------------------------------------------------------------------------
   -- Private Constants
   ---------------------------------------------------------------------------

   ---------------------------------------------------------------------------
   -- Private Modules
   ---------------------------------------------------------------------------


   ---------------------------------------------------------------------------
   -- Public Modules
   ---------------------------------------------------------------------------

   -----------------------------------------------------------------------
   -- Function:
   --    f_get_syspar
   --
   -- Description:
   -- This function selects the value of a syspar.
   --
   -- Parameters:
   --    i_config_flag_name  - Name of the syspar.  Converted to upper case
   --                          in the select statement.
   --    i_value_if_null     - Value to use the the syspar if it is null
   --                          in the database or does not exist.
   --                          This is OPTIONAL.
   --
   -- Return Values:
   --    Value of the syspar.  If the syspar is not found or is null then
   --    i_value_if_null is returned if passed as a parameter otherwise
   --    null is returned.
   --
   -- Exceptions raised:
   --    -20001  An oracle error occurred.
   ---------------------------------------------------------------------
   FUNCTION f_get_syspar
      (i_config_flag_name IN sys_config.config_flag_name%TYPE,
       i_value_if_null    IN VARCHAR2 := NULL)
   RETURN VARCHAR2 IS
      l_object_name   VARCHAR2(30) := gl_pkg_name || '.f_get_syspar';
      l_syspar_value  sys_config.config_flag_val%TYPE;
      l_sqlerrm       VARCHAR2(500);    -- SQLERRM

      CURSOR c_sys_config IS
         SELECT NVL(config_flag_val, i_value_if_null)
           FROM sys_config
          WHERE config_flag_name = UPPER(i_config_flag_name);
   BEGIN
      OPEN c_sys_config;
      FETCH c_sys_config INTO l_syspar_value;
      IF (c_sys_config%NOTFOUND) THEN
         l_syspar_value := i_value_if_null;
      END IF;
      CLOSE c_sys_config;

      RETURN(l_syspar_value);

   EXCEPTION
      WHEN OTHERS THEN
         l_sqlerrm := SQLERRM;  -- Save mesg in case cursor cleanup fails.

         IF (c_sys_config%ISOPEN) THEN    -- Cursor cleanup.
            CLOSE c_sys_config;
         END IF;

         RAISE_APPLICATION_ERROR(-20001, l_object_name ||
            'i_config_flag_name[' || i_config_flag_name || '] Error: ' ||
            l_sqlerrm);
   END f_get_syspar;

   ---------------------------------------------------------------------

   -- Create transaction from trans%ROWTYPE
   FUNCTION f_create_trans (
     i_trans_rec  IN  trans%ROWTYPE,
     i_upload_time_type  IN  VARCHAR2 DEFAULT NULL,
     i_create_trans_type IN  VARCHAR2 DEFAULT NULL)
   RETURN NUMBER IS
     l_trans_date  trans.trans_date%TYPE := i_trans_rec.trans_date;
     l_user  trans.user_id%TYPE := i_trans_rec.user_id;
     l_upload_time trans.upload_time%TYPE := i_trans_rec.upload_time;
     l_existed  NUMBER(1) := 0;
     l_trans_type trans_type.trans_type%TYPE;
     l_descrip  trans_type.descrip%TYPE := 'No description available';
     l_retention_days trans_type.retention_days%TYPE := 55;
     l_inv_affecting trans_type.inv_affecting%TYPE := 'N';
     l_temp1  VARCHAR2(50) := NULL;
     l_temp2  VARCHAR2(50) := NULL;
     l_temp3  VARCHAR2(50) := NULL;
     l_result  NUMBER(1);
     l_sep_idx  NUMBER(1) := 1;
     l_sep_count NUMBER(5) := 0;
     CURSOR c_get_trans_type (cp_ttype VARCHAR2) IS
       SELECT 1
       FROM trans_type
       WHERE trans_type = cp_ttype;
   BEGIN
     -- Error if no trans_type input
     IF RTRIM(LTRIM(i_trans_rec.trans_type)) IS NULL THEN
       RETURN -1;
     END IF;

     IF i_upload_time_type IS NULL THEN
       -- Need to upload the transaction to SUS
       SELECT TO_DATE('01011980', 'MMDDYYYY') INTO l_upload_time FROM DUAL;
     ELSIF UPPER(i_upload_time_type) = 'NA' THEN
       -- Transaction is for SWMS's reference only
       SELECT NULL INTO l_upload_time FROM DUAL;
     ELSE
       -- Input upload time must be in MMDDRR format
       BEGIN
         SELECT TO_DATE(i_upload_time_type, 'MMDDRR') INTO l_upload_time
         FROM DUAL;

       EXCEPTION
         WHEN OTHERS THEN
           RETURN -2;
       END;
     END IF;

     OPEN c_get_trans_type(i_trans_rec.trans_type);
     FETCH c_get_trans_type INTO l_existed;
     IF c_get_trans_type%NOTFOUND THEN
       IF i_create_trans_type IS NULL THEN
         -- Transaction type is not in trans_type table and no transaction type
         -- record being created at the same time. Error out.
         CLOSE c_get_trans_type;
         RETURN -3;
       END IF;
       -- Transaction type is not in trans_type table and i_create_trans_type
       -- has something in it. Create the trans_type record according to it.
       -- Count the # of seperators found
       LOOP
         l_result := INSTR(i_create_trans_type, '|', 1, l_sep_idx);
         EXIT WHEN l_result = 0;
         IF l_result > 0  THEN
           l_sep_count := l_sep_count + 1;
         END IF;
         l_sep_idx := l_sep_idx + 1;
       END LOOP;
       IF l_sep_count = 0 THEN
         -- No seperator at all. Use the trans_type and default anything else
         l_trans_type := UPPER(i_create_trans_type);
       ELSE
         -- At least one seperator is found
         l_temp1 := SUBSTR(i_create_trans_type,
                           1, INSTR(i_create_trans_type, '|') - 1);
         IF l_temp1 IS NULL THEN
           -- Transaction type value is there but no seperator at the end
           l_trans_type := UPPER(i_create_trans_type);
         ELSE
           l_trans_type := UPPER(l_temp1);
           -- Get fields after the transaction type value seperator
           l_temp1 := SUBSTR(i_create_trans_type,
                             INSTR(i_create_trans_type, '|') + 1);
           IF l_temp1 IS NOT NULL THEN
             -- Get retention day value
             l_temp2 := SUBSTR(l_temp1, 1, INSTR(l_temp1, '|') - 1);
             IF l_temp2 IS NULL THEN
               -- No seperator after retention day value
               l_temp2 := l_temp1;
             END IF;
             -- Check the format of retention day val. Use default if not valid
             BEGIN
               SELECT TO_NUMBER(l_temp2) INTO l_retention_days FROM DUAL;
             EXCEPTION
               WHEN OTHERS THEN
                 l_retention_days := 55;
             END;
             IF l_sep_count >= 2 THEN
               -- Get the fields after the retention day value seperatore
               l_temp1 := SUBSTR(l_temp1, INSTR(l_temp1, '|') + 1);
               IF l_temp1 IS NOT NULL THEN
                 -- Get the inv_affecting value
                 l_temp2 := UPPER(SUBSTR(l_temp1, 1, INSTR(l_temp1, '|') - 1));
                 IF l_temp2 IS NOT NULL THEN
                   l_temp3 := SUBSTR(l_temp2, INSTR(l_temp2, '|') - 1);
                   IF l_temp3 IS NULL THEN
                     -- Inv_affecting is the last field and without seperator
                     l_inv_affecting := l_temp2;
                   ELSE
                     l_inv_affecting := l_temp3;
                     IF l_temp2 NOT IN ('Y', 'N') THEN
                       -- Set to default if value is not Y/N
                       l_inv_affecting := 'N';
                     END IF;
                   END IF;
                 END IF;
               ELSE
                 IF SUBSTR(l_temp1, 1, 1) <> '|' THEN
                   -- There is a inv_affecting value input
                   l_inv_affecting := UPPER(l_temp1);
                 END IF;
               END IF;
             END IF;
             IF l_sep_count >= 3 THEN
               -- Get the field after the inv_affecing field seperator
               l_temp1 := SUBSTR(l_temp1, INSTR(l_temp1, '|') + 1);
               IF l_temp1 IS NOT NULL THEN
                 l_temp2 := SUBSTR(l_temp1, 1, INSTR(l_temp1, '|') - 1);
                 IF l_temp2 IS NOT NULL THEN
                   -- Description is there and with end seperator
                   l_descrip := l_temp2;
                 ELSE
                   l_descrip := l_temp1;
                 END IF;
               END IF;
             END IF;
           END IF;
         END IF;
       END IF;
       BEGIN
         INSERT INTO trans_type
           (trans_type, descrip, retention_days, inv_affecting)
           VALUES (l_trans_type, l_descrip, l_retention_days, l_inv_affecting);
       EXCEPTION
         WHEN OTHERS THEN
           RETURN SQLCODE;
       END;
     END IF;
     CLOSE c_get_trans_type;

     -- Set default transaction date and user if no inputs
     IF i_trans_rec.trans_date IS NULL THEN
       l_trans_date := SYSDATE;
     END IF;
     IF i_trans_rec.user_id IS NULL THEN
       l_user := USER;
     END IF;

     INSERT INTO trans
       (trans_id, trans_type, trans_date,
        prod_id, rec_id, lot_id,
        exp_date, weight, temp,
        mfg_date, qty_expected,
        uom_expected, qty, uom,
        src_loc, dest_loc, user_id,
        order_id, route_no, stop_no,
        truck_no, cmt, old_status,
        new_status, reason_code,
        adj_flag, pallet_id,
        upload_time, order_line_id,
        batch_no, sys_order_id,
        sys_order_line_id, order_type,
        returned_prod_id, diff_weight,
        ilr_upload_time, cust_pref_vendor,
        clam_bed_no, warehouse_id,
        float_no, bck_dest_loc)
       VALUES (trans_id_seq.NEXTVAL, i_trans_rec.trans_type, l_trans_date,
               i_trans_rec.prod_id, i_trans_rec.rec_id, i_trans_rec.lot_id,
               i_trans_rec.exp_date, i_trans_rec.weight, i_trans_rec.temp,
               i_trans_rec.mfg_date, i_trans_rec.qty_expected,
               i_trans_rec.uom_expected, i_trans_rec.qty, i_trans_rec.uom,
               i_trans_rec.src_loc, i_trans_rec.dest_loc, l_user,
               i_trans_rec.order_id, i_trans_rec.route_no, i_trans_rec.stop_no,
               i_trans_rec.truck_no, i_trans_rec.cmt, i_trans_rec.old_status,
               i_trans_rec.new_status, i_trans_rec.reason_code,
               i_trans_rec.adj_flag, i_trans_rec.pallet_id,
               l_upload_time, i_trans_rec.order_line_id,
               i_trans_rec.batch_no, i_trans_rec.sys_order_id,
               i_trans_rec.sys_order_line_id, i_trans_rec.order_type,
               i_trans_rec.returned_prod_id, i_trans_rec.diff_weight,
               i_trans_rec.ilr_upload_time, i_trans_rec.cust_pref_vendor,
               i_trans_rec.clam_bed_no, i_trans_rec.warehouse_id,
               i_trans_rec.float_no, i_trans_rec.bck_dest_loc);

     RETURN ct_sql_success;

   EXCEPTION
     WHEN OTHERS THEN
       RETURN SQLCODE;
   END;

   ---------------------------------------------------------------------

   -- Create transaction from trans named parameters
   FUNCTION f_create_trans (
     i_trans_type  IN  trans.trans_type%TYPE,
     i_prod_id   IN  trans.prod_id%TYPE DEFAULT NULL,
     i_rec_id   IN  trans.rec_id%TYPE DEFAULT NULL,
     i_lot_id   IN  trans.lot_id%TYPE DEFAULT NULL,
     i_exp_date   IN  trans.exp_date%TYPE DEFAULT NULL,
     i_weight   IN  trans.weight%TYPE DEFAULT NULL,
     i_temp   IN  trans.temp%TYPE DEFAULT NULL,
     i_mfg_date   IN  trans.mfg_date%TYPE DEFAULT NULL,
     i_qty_expected  IN  trans.qty_expected%TYPE DEFAULT NULL,
     i_uom_expected  IN  trans.uom_expected%TYPE DEFAULT NULL,
     i_qty   IN  trans.qty%TYPE DEFAULT NULL,
     i_uom   IN  trans.uom%TYPE DEFAULT NULL,
     i_src_loc   IN  trans.src_loc%TYPE DEFAULT NULL,
     i_dest_loc   IN  trans.dest_loc%TYPE DEFAULT NULL,
     i_user_id   IN  trans.user_id%TYPE DEFAULT USER,
     i_order_id   IN  trans.order_id%TYPE DEFAULT NULL,
     i_route_no   IN  trans.route_no%TYPE DEFAULT NULL,
     i_stop_no   IN  trans.stop_no%TYPE DEFAULT NULL,
     i_truck_no   IN  trans.truck_no%TYPE DEFAULT NULL,
     i_cmt   IN  trans.cmt%TYPE DEFAULT NULL,
     i_old_status  IN  trans.old_status%TYPE DEFAULT NULL,
     i_new_status  IN  trans.new_status%TYPE DEFAULT NULL,
     i_reason_code  IN  trans.reason_code%TYPE DEFAULT NULL,
     i_adj_flag   IN  trans.adj_flag%TYPE DEFAULT NULL,
     i_pallet_id  IN  trans.pallet_id%TYPE DEFAULT NULL,
     i_order_line_id  IN  trans.order_line_id%TYPE DEFAULT NULL,
     i_batch_no   IN  trans.batch_no%TYPE DEFAULT NULL,
     i_sys_order_id  IN  trans.sys_order_id%TYPE DEFAULT NULL,
     i_sys_order_line_id IN  trans.sys_order_line_id%TYPE DEFAULT NULL,
     i_order_type  IN  trans.order_type%TYPE DEFAULT NULL,
     i_returned_prod_id  IN  trans.returned_prod_id%TYPE DEFAULT NULL,
     i_diff_weight  IN  trans.diff_weight%TYPE DEFAULT NULL,
     i_ilr_upload_time  IN  trans.ilr_upload_time%TYPE DEFAULT NULL,
     i_cust_pref_vendor  IN  trans.cust_pref_vendor%TYPE DEFAULT NULL,
     i_clam_bed_no  IN  trans.clam_bed_no%TYPE DEFAULT NULL,
     i_warehouse_id  IN  trans.warehouse_id%TYPE DEFAULT NULL,
     i_float_no   IN  trans.float_no%TYPE DEFAULT NULL,
     i_bck_dest_loc  IN  trans.bck_dest_loc%TYPE DEFAULT NULL,
     i_upload_time_type  IN  VARCHAR2 DEFAULT NULL,
     i_create_trans_type    IN  VARCHAR2 DEFAULT NULL)
   RETURN NUMBER IS
     l_trans_row  trans%ROWTYPE := NULL;
   BEGIN
     l_trans_row.trans_type := i_trans_type;
     l_trans_row.prod_id := i_prod_id;
     l_trans_row.rec_id := i_rec_id;
     l_trans_row.lot_id := i_lot_id;
     l_trans_row.exp_date := i_exp_date;
     l_trans_row.weight := i_weight;
     l_trans_row.temp := i_temp;
     l_trans_row.mfg_date := i_mfg_date;
     l_trans_row.qty_expected:= i_qty_expected;
     l_trans_row.uom_expected:= i_uom_expected;
     l_trans_row.qty := i_qty;
     l_trans_row.uom := i_uom;
     l_trans_row.src_loc := i_src_loc;
     l_trans_row.dest_loc := i_dest_loc;
     l_trans_row.user_id := i_user_id;
     l_trans_row.order_id := i_order_id;
     l_trans_row.route_no := i_route_no;
     l_trans_row.stop_no := i_stop_no;
     l_trans_row.truck_no := i_truck_no;
     l_trans_row.cmt := i_cmt;
     l_trans_row.old_status := i_old_status;
     l_trans_row.new_status := i_new_status;
     l_trans_row.reason_code := i_reason_code;
     l_trans_row.adj_flag := i_adj_flag;
     l_trans_row.pallet_id := i_pallet_id;
     l_trans_row.order_line_id:= i_order_line_id;
     l_trans_row.batch_no := i_batch_no;
     l_trans_row.sys_order_id:= i_sys_order_id;
     l_trans_row.sys_order_line_id:= i_sys_order_line_id;
     l_trans_row.order_type := i_order_type;
     l_trans_row.returned_prod_id:= i_returned_prod_id;
     l_trans_row.diff_weight := i_diff_weight;
     l_trans_row.ilr_upload_time:= i_ilr_upload_time;
     l_trans_row.cust_pref_vendor:= i_cust_pref_vendor;
     l_trans_row.clam_bed_no := i_clam_bed_no;
     l_trans_row.warehouse_id:= i_warehouse_id;
     l_trans_row.float_no := i_float_no;
     l_trans_row.bck_dest_loc:= i_bck_dest_loc;

     RETURN f_create_trans(l_trans_row,
                           i_upload_time_type, i_create_trans_type);
   END;

   ---------------------------------------------------------------------

   -- Get unique license plate from the system.
   PROCEDURE p_get_unique_lp (
     o_licPlate  OUT putawaylst.pallet_id%TYPE,
     o_status  OUT NUMBER) IS
     l_true  BOOLEAN := TRUE;
     l_pallet  putawaylst.pallet_id%TYPE;
     l_existed  NUMBER(1) := 0;
   BEGIN
     o_status := ct_sql_success;
     o_licPlate := NULL;
     WHILE l_true LOOP
       BEGIN
         SELECT pallet_id_seq.NEXTVAL INTO l_pallet FROM DUAL;

       EXCEPTION
         WHEN OTHERS THEN
           o_status := SQLCODE;
           l_true := FALSE;
       END;
       IF l_true THEN
         BEGIN
           SELECT 1 INTO l_existed
           FROM inv
           WHERE logi_loc = l_pallet;

         EXCEPTION
           WHEN NO_DATA_FOUND THEN
             l_true := FALSE;
             o_status := ct_sql_success;
             o_licPlate := l_pallet;
           WHEN OTHERS THEN
             o_status := SQLCODE;
             l_true := FALSE;
         END;
       END IF;
     END LOOP;
   END;

   ---------------------------------------------------------------------

   FUNCTION f_get_putcount_b4swp
      (i_srcloc           IN putawaylst.dest_loc%TYPE)
   RETURN NUMBER IS
     rtcount NUMBER;
     put_loc loc.logi_loc%TYPE;
   BEGIN
     BEGIN
  SELECT bck_logi_loc
    INTO put_loc
          FROM loc_reference
   WHERE plogi_loc = i_srcloc;
     EXCEPTION
    WHEN OTHERS THEN
         put_loc := i_srcloc;
     END;
	--sban3548: Jira# 649: Added condition to check for FRONT Loc as well	
     SELECT count(*) INTO rtcount FROM putawaylst
     WHERE (dest_loc = put_loc OR dest_loc = i_srcloc) 
     AND ( putaway_put = 'N'
        OR 'Y' IN (NVL(catch_wt,'N'), NVL(clam_bed_trk,'N'),
                   NVL(exp_date_trk,'N'), NVL(lot_trk,'N'),
                   NVL(temp_trk,'N'), NVL(date_code,'N')));
     return rtcount;
   EXCEPTION
     WHEN OTHERS THEN
       rtcount := 1;
       return rtcount;
   END;
   ---------------------------------------------------------------------
   FUNCTION f_get_putcount_b4xfr
      (i_palletid         IN putawaylst.pallet_id%TYPE)
   RETURN NUMBER IS
     rtcount NUMBER;
   BEGIN
     SELECT count(*) INTO rtcount FROM putawaylst
     WHERE pallet_id = i_palletid
     AND   putaway_put = 'N';
     return rtcount;
   EXCEPTION
     WHEN OTHERS THEN
       rtcount := 1;
       return rtcount;
   END;

   ---------------------------------------------------------------------
   FUNCTION f_get_putcount_b4hst
      (i_srcloc           IN putawaylst.dest_loc%TYPE)
   RETURN NUMBER IS
     rtcount NUMBER;
   BEGIN
     SELECT count(*) INTO rtcount
      FROM putawaylst p, erm e
     WHERE p.dest_loc = i_srcloc
     AND   p.putaway_put = 'N'
     AND   p.rec_id = e.erm_id
     AND   e.erm_type != 'CM';
     return rtcount;
   EXCEPTION
     WHEN OTHERS THEN
       rtcount := 1;
       return rtcount;
   END;
   ---------------------------------------------------------------------

   -----------------------------------------------------------------------
   -- Function:
   --    f_get_first_pick_slot
   --
   -- Description:
   --    RCD non-dependent changes.
   --    This function returns the first pick slot for an item within a
   --    range of slots.  The slot range is optional.
   --
   --    For a slotted item and not searching over a location range the
   --    location returned will be the rank 1 case home slot.  If searching
   --    over a location range then the location returned is the lowest
   --    rank case home and if no case home found the lowest rank split
   --    home within the location range.  If the item is not within the
   --    location range null is returned.
   --
   --    For a floating item (not slotted in this context) and not
   --    searching over a location range the location returned will be the
   --    min(location) from inventory.  If searching over a location
   --    range the location returned will be the min(location) within
   --    the location range.  If the item is not within the location
   --    range null is returned.  If the item does not exist in inventory
   --    null is returned.
   --
   --    This function is used in form mh2sa.fmb and in reports mh2ra.sql
   --    and mh2rb.sql.  The form and the reports are used to edit the case
   --    and split dimemsions for an item.  There was a requirement to be
   --    able to order the items by location in the form and the on the
   --    reports so this function was created.
   --
   -- Parameters:
   --    i_prod_id          - Item
   --    i_cust_pref_vendor - Customer preferred vendor for the item.
   --    i_from_loc         - Starting location when looking over a location
   --                         range.  Optional.
   --    i_to_loc           - Ending location when looking over a location
   --                         range.  Optional.
   --
   -- Return Values:
   --    The first pick slot or null.
   --
   -- Exceptions raised:
   --    -20001  An oracle error occurred.
   --    -20002  Missing the from loc or the to loc.  Both must be
   --            entered or left null.
   ---------------------------------------------------------------------
   FUNCTION f_get_first_pick_slot
      (i_prod_id           IN   pm.prod_id%TYPE,
       i_cust_pref_vendor  IN   pm.cust_pref_vendor%TYPE,
       i_from_loc          IN   loc.logi_loc%TYPE DEFAULT NULL,
       i_to_loc            IN   loc.logi_loc%TYPE DEFAULT NULL)
   RETURN VARCHAR2 IS
      l_object_name   VARCHAR2(61) := gl_pkg_name || '.f_get_first_pick_slot';

      l_logi_loc  loc.logi_loc%TYPE;

      e_missing_loc   EXCEPTION;  -- Raised when the from or to location is
                                  -- missing.  Both must be not null or null.

      CURSOR c_pick_loc IS
         -- Item with home slot.
         SELECT l.logi_loc, DECODE(l.uom, 2, 0, l.uom) decoded_uom, l.rank
           FROM loc l
          WHERE l.prod_id = i_prod_id
            AND l.cust_pref_vendor = i_cust_pref_vendor
         UNION
         -- Floating item (not slotted for our purpose in this function).
         SELECT i.plogi_loc , 1 decoded_uom, 1 rank
           FROM inv i
          WHERE i.prod_id = i_prod_id
            AND i.cust_pref_vendor = i_cust_pref_vendor
            AND NOT EXISTS (SELECT 'x'
                              FROM loc L2
                             WHERE l2.prod_id = i.prod_id
                               AND l2.cust_pref_vendor = i.cust_pref_vendor)
          ORDER BY 2, 3, 1;

      CURSOR c_pick_loc_over_range IS
         -- Item with home slot.
         SELECT l.logi_loc, DECODE(l.uom, 2, 0, l.uom) decoded_uom, l.rank
           FROM loc l
          WHERE l.prod_id = i_prod_id
            AND l.cust_pref_vendor = i_cust_pref_vendor
            AND l.logi_loc BETWEEN i_from_loc AND i_to_loc
         UNION
         -- Floating item (not slotted for our purpose in this function).
         SELECT i.plogi_loc , 1 decoded_uom, 1 rank
           FROM inv i
          WHERE i.prod_id = i_prod_id
            AND i.cust_pref_vendor = i_cust_pref_vendor
            AND i.plogi_loc BETWEEN i_from_loc AND i_to_loc
            AND NOT EXISTS (SELECT 'x'
                              FROM loc L2
                             WHERE l2.prod_id = i.prod_id
                               AND l2.cust_pref_vendor = i.cust_pref_vendor)
          ORDER BY 2, 3, 1;

      r_pick_loc  c_pick_loc%ROWTYPE;

   BEGIN
      IF (i_from_loc IS NULL AND i_to_loc IS NULL) THEN
         OPEN c_pick_loc;
         FETCH c_pick_loc INTO r_pick_loc;
         CLOSE c_pick_loc;
      ELSIF (i_from_loc IS NOT NULL AND i_to_loc IS NOT NULL) THEN
         OPEN c_pick_loc_over_range;
         FETCH c_pick_loc_over_range INTO r_pick_loc;
         CLOSE c_pick_loc_over_range;
      ELSE
         RAISE e_missing_loc;
      END IF;

      RETURN(r_pick_loc.logi_loc);

   EXCEPTION
      WHEN e_missing_loc THEN
         RAISE_APPLICATION_ERROR(-20002, l_object_name ||
            'i_prod_id[' || i_prod_id || ']' ||
            ' CPV[' || i_cust_pref_vendor || ']'  ||
            ' i_from_loc[' || i_from_loc || ']'  ||
            ' i_to_loc[' || i_to_loc || ']'  ||
            '  From and to loc both must be not null.');
      WHEN OTHERS THEN
         RAISE_APPLICATION_ERROR(-20001, l_object_name ||
            'i_prod_id[' || i_prod_id || ']' ||
            ' CPV[' || i_cust_pref_vendor || '] Error: ' || SQLERRM);
   END f_get_first_pick_slot ;


   ------------------------------------------------------------------------
   -- Function:
   --    f_is_clam_bed_tracked_item
   --
   -- Description:
   --    This function determines if an item is clam bed tracked based on
   --    the category of the item and the clam bed track syspar.
   --    Return 'Y' if item is clam bed tracked otherwise 'N'.
   --    It calls pl_putaway_utilities.f_is_clam_bed_tracked_item which
   --    returns a boolean.  We want to return 'Y' or 'N' so the function
   --    can be used in a SQL statement.
   --
   -- Parameters:
   --    i_category                - Item category (pm.category).
   --    i_clam_bed_tracked_syspar - The clam bed track syspar.
   --
   -- Return Value:
   --    'Y' if the category is clam bed tracked otherwise 'N'.
   --
   -- Called by:  (list may not be complete)
   --
   -- Exceptions raised:
   --    pl_exc.e_data_error  - An error occurred.
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    06/29/04 prpbcb   Created.
   --                      Maybe we should move the function in
   --                      pl_putaway_utilities and put in pl_common and
   --                      overload it.
   ------------------------------------------------------------------------
   FUNCTION f_is_clam_bed_tracked_item
                 (i_category                IN pm.category%TYPE,
                  i_clam_bed_tracked_syspar IN sys_config.config_flag_val%TYPE)
   RETURN VARCHAR2 IS
      l_object_name   VARCHAR2(61) := gl_pkg_name ||
                                           '.f_is_clam_bed_tracked_item';

      l_return_value  VARCHAR2(1);
   BEGIN
      IF (pl_putaway_utilities.f_is_clam_bed_tracked_item(i_category,
                                     i_clam_bed_tracked_syspar) = TRUE) THEN
         l_return_value := 'Y';
      ELSE
         l_return_value := 'N';
      END IF;

      RETURN(l_return_value);

   EXCEPTION
      WHEN OTHERS THEN
         RAISE_APPLICATION_ERROR(pl_exc.ct_data_error, l_object_name ||
            ': ' || SQLERRM);
   END f_is_clam_bed_tracked_item;


   ------------------------------------------------------------------------
   -- Function:
   --    f_is_cool_tracked_item
   --
   -- Description:
   --    This function determines if an item is cool tracked.
   --    Return 'Y' if item is cool tracked otherwise 'N'.
   --    It calls pl_putaway_utilities.f_is_cool_tracked_item which
   --    returns a boolean.  We want to return 'Y' or 'N' so the function
   --    can be used in a SQL statement.
   --
   -- Parameters:
   --    i_prod_id    - Item to see if cool tracked.
   --    i_cpv        - Customer preferred vendor.
   --
   -- Return Value:
   --    'Y' if the category is cool tracked otherwise 'N'.
   --
   -- Called by:  (list may not be complete)
   --
   -- Exceptions raised:
   --    pl_exc.e_data_error  - An error occurred.
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    05/16/05 prpbcb   Created.
   --                      Maybe we should move the function in
   --                      pl_putaway_utilities and put in pl_common and
   --                      overload it.
   ------------------------------------------------------------------------
   FUNCTION f_is_cool_tracked_item
                 (i_prod_id   IN pm.prod_id%TYPE,
                  i_cpv       IN pm.cust_pref_vendor%TYPE)
   RETURN VARCHAR2 IS
      l_object_name   VARCHAR2(61) := gl_pkg_name ||
                                           '.f_is_clam_bed_tracked_item';

      l_return_value  VARCHAR2(1);
   BEGIN
      IF (pl_putaway_utilities.f_is_cool_tracked_item(i_prod_id,
                                                      i_cpv) = TRUE) THEN
         l_return_value := 'Y';
      ELSE
         l_return_value := 'N';
      END IF;

      RETURN(l_return_value);

   EXCEPTION
      WHEN OTHERS THEN
         RAISE_APPLICATION_ERROR(pl_exc.ct_data_error, l_object_name ||
            ': ' || SQLERRM);
   END f_is_cool_tracked_item;


   ------------------------------------------------------------------------
   -- Function:
   --    f_wrap_line
   --
   -- Description:
   --    This function word wraps text to a specified length.  A CHR(10) is
   --    inserted into the text.
   --
   --    Example:
   --       Function call
   --          the_text := pl_commmon.f_wrap_line('There is no time.', 6);
   --       will return a value of: ThereCHR(10)is noCHR(10)time.
   --
   -- Parameters:
   --    i_text      - The text to wrap.
   --    i_wrap_len  - Length to wrap the text.  If < 1 or > 1000 then
   --                  60 is used.
   --
   -- Return Value:
   --    Text with CHR(10) at the end of each line.
   --
   -- Called by:  (list may not be complete)
   --
   -- Exceptions raised:
   --    pl_exc.e_data_error  - An error occurred.
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    04/15/04 prpbcb   Created.
   --                      Initially created to wrap text for form alerts
   --                      displayed in GUI mode.
   ------------------------------------------------------------------------
   FUNCTION f_wrap_line(i_text    IN VARCHAR2,
                      i_wrap_len  IN PLS_INTEGER DEFAULT 60)
   RETURN VARCHAR2 IS
      l_object_name   VARCHAR2(61) := gl_pkg_name || '.f_wrap_line';

      l_line_len              PLS_INTEGER := LENGTH(i_text);
      l_return_line           VARCHAR2(2500) := NULL;
      l_wrap_len              PLS_INTEGER;   -- Wrap length
      l_first_space_position  PLS_INTEGER;   -- Position of 1st space in line
                                             --  chunk
      l_last_space_position   PLS_INTEGER;   -- Position of last space in line
                                             --  chunk
      l_start_position        PLS_INTEGER := 1; -- Position in the text
                                                -- to process next.
      l_temp_line             VARCHAR2(2500);   -- Chuck of text to wrap.
      l_temp_line_len         PLS_INTEGER;      -- Length of chunk.

      counter                 PLS_INTEGER := 0;  -- Work area
   BEGIN

      -- Restrict the wrap length.
      IF (i_wrap_len < 1 OR i_wrap_len > 1000) THEN
         l_wrap_len := 60;
      ELSE
         l_wrap_len := i_wrap_len;
      END IF;

      -- If text to wrap is null or all blanks then null returned.
      -- If the next to wrap is less than the wrap length then there is
      -- nothing to do.
      IF (i_text IS NULL OR LTRIM(i_text, ' ') IS NULL) THEN
         l_return_line := NULL;
      ELSIF (l_line_len <= l_wrap_len) THEN
         l_return_line := i_text;
      ELSE

         -- Word wrap the text.
         WHILE (l_start_position <= l_line_len) LOOP
            counter := counter + 1;

            -- Skip leading spaces.
            WHILE ((SUBSTR(i_text, l_start_position, 1) = ' ') AND
                      l_start_position <= l_line_len) LOOP
               l_start_position := l_start_position + 1;
            END LOOP;

            IF (l_start_position > l_line_len) THEN
               EXIT;  -- Only left with spaces at end of the text.  Ignore them.
            END IF;

            -- Get chunk if text.
            l_temp_line := SUBSTR(i_text, l_start_position, l_wrap_len);
            l_temp_line_len := LENGTH(l_temp_line);

            l_first_space_position := INSTR(l_temp_line, ' ');
            l_last_space_position := INSTR(l_temp_line, ' ', -1);
            l_temp_line := LTRIM(l_temp_line, ' ');

            -- If the last chararacter of the chunk is a space or the next
            -- character after the chunk is a space or at the end of the text
            -- or the chunk has no spaces then use the chunk as is.
            IF ( (l_temp_line_len = l_last_space_position) OR
                 (SUBSTR(i_text, (l_start_position + l_wrap_len), 1) = ' ') OR
                 (l_start_position + l_wrap_len > l_line_len) OR
                 (l_last_space_position = 0) )  THEN
               l_temp_line := LTRIM(l_temp_line, ' ');
               l_start_position := l_start_position + l_temp_line_len;
            ELSE
               l_temp_line := SUBSTR(l_temp_line, 1, l_last_space_position);
               l_start_position := l_start_position + l_last_space_position;
           END IF;

           IF (counter > 1) THEN
              l_return_line := l_return_line || CHR(10);
           END IF;

           l_return_line := l_return_line || RTRIM(l_temp_line, ' ');
         END LOOP;
      END IF;

      RETURN(l_return_line);
   EXCEPTION
      WHEN OTHERS THEN
         RAISE_APPLICATION_ERROR(pl_exc.ct_data_error, l_object_name ||
            ': ' || SQLERRM);

   END f_wrap_line;


---------------------------------------------------------------------------
-- Function:
--    f_get_new_pallet_id
--
-- Description:
--    This function returns the next available LP.  The LP comes from
--    sequence pallet_id_seq.
--
-- Parameters:
--    None
--
-- Exceptions raised:
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Called by:  (list not complete)
--    - pl_rcv_open_po_pallet_list.f_get_new_pallet_id
--    - Form mm3sa.fmb
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    02/22/06 prpbcb   Created
---------------------------------------------------------------------------
FUNCTION f_get_new_pallet_id
RETURN VARCHAR2
IS
   K_RDC_Blind  CONSTANT  VARCHAR2(1) := 'B';
   K_is_rdc               VARCHAR2(1) := UPPER( PL_Common.F_Get_SysPar( 'IS_RDC', 'N' ) );

   l_message       VARCHAR2(256);    -- Message buffer

   -- prpbcb  Will save a little execution time by not assigning object
   -- name to variable until needed.
   l_object_name   VARCHAR2(61);
   -- l_object_name   VARCHAR2(61) := gl_pkg_name || '.f_net_new_pallet_id';

   l_done_bln   BOOLEAN;      -- Flag
   l_dummy      VARCHAR2(1);  -- Work area
   l_pallet_id  putawaylst.pallet_id%TYPE;  -- LP to use for the pallet

   --
   -- This cursor is used to check if the LP already exists.
   --
   CURSOR c_check_for_pallet(cp_pallet_id  putawaylst.pallet_id%TYPE) IS
      SELECT 'x'
        FROM dual
       WHERE NOT EXISTS
                    (SELECT 'x'
                       FROM inv
                      WHERE logi_loc = cp_pallet_id)
         AND NOT EXISTS
                    (SELECT 'x'
                       FROM putawaylst
                      WHERE pallet_id = cp_pallet_id);
BEGIN
   l_done_bln := FALSE;

   WHILE (l_done_bln = FALSE) LOOP
      SELECT DECODE( K_is_rdc, 'Y', K_RDC_Blind ) ||
             pallet_id_seq.NEXTVAL INTO l_pallet_id FROM DUAL;

      BEGIN
         OPEN c_check_for_pallet(l_pallet_id);
         FETCH c_check_for_pallet INTO l_dummy;
         IF (c_check_for_pallet%FOUND) THEN
            l_done_bln := TRUE;
         END IF;
         CLOSE c_check_for_pallet;
      END;
   END LOOP;

   RETURN(l_pallet_id);
   
EXCEPTION
   WHEN OTHERS THEN
      l_object_name := gl_pkg_name || '.f_net_new_pallet_id';
      l_message := l_object_name
                   || ':  Failed to get the pallet id.';
      pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                           SQLCODE, SQLERRM);
      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error, 
                              l_object_name || ': ' || SQLERRM);
END f_get_new_pallet_id;

   ------------------------------------------------------------------------
   -- Function:
   --    f_loc_sort
   --
   -- Description:
   --    This function is used to re-arrange the group and order
   --    of the selected records in cursor prod_cursor (req_cc_area.pc).
   --    It returns the sequence number of 'PROD' type of cycle count
   --    tasks group by items and in the order of locations.
   -- Called by: 
   --    req_cc_area.pc
   ------------------------------------------------------------------------
   FUNCTION f_loc_sort(i_area      IN VARCHAR2,
                       i_user_id   IN cc.user_id%TYPE DEFAULT NULL,
                       i_prod_id   IN pm.prod_id%TYPE,
                       i_cpv       IN pm.cust_pref_vendor%TYPE)
   RETURN NUMBER
   IS

      iOrder        NUMBER := 0;
      r             tabCcProd;
      rcnt          number := 0;
      blnFound      boolean := FALSE;
      iFoundIdx     number := 0;
      CURSOR cc1 IS
        SELECT DISTINCT c.prod_id, c.cust_pref_vendor,
           MIN(c1.cc_priority), COUNT(c.status),
           NVL(l.logi_loc, 'ZZZZZZ')
        FROM cc_reason c1, pm p, loc l, cc c
        WHERE l.logi_loc = c.phys_loc
        AND p.prod_id = c.prod_id
        AND p.cust_pref_vendor = c.cust_pref_vendor
        AND c1.cc_reason_code = c.cc_reason_code
        AND c.status = 'NEW'
        AND c.type = 'PROD'
        AND (c.user_id IS NULL OR c.user_id = i_user_id)
        AND EXISTS (SELECT 'x'
                    FROM swms_sub_areas sa, aisle_info ai
                    WHERE sa.sub_area_code = ai.sub_area_code
                    AND   ai.name = SUBSTR(c.phys_loc,1,2)
                    AND   sa.sub_area_code LIKE upper(i_area))
        AND EXISTS (SELECT 1
                    FROM zone z, lzone lz
                    WHERE z.zone_id = lz.zone_id
                    AND   z.zone_type = 'PUT'
                    AND   lz.logi_loc = c.phys_loc
                    AND   ((z.rule_id <> 3) OR
                            ((z.rule_id = 3) AND
                             ((z.induction_loc <> c.phys_loc) OR
                              ((z.induction_loc= c.phys_loc) AND
                               (c.cc_reason_code NOT IN ('US', 'AB')))))))
          GROUP BY NVL(l.logi_loc, 'ZZZZZZ'), c.prod_id, c.cust_pref_vendor
          ORDER BY MIN(c1.cc_priority), NVL(l.logi_loc, 'ZZZZZZ'),
                   c.prod_id, c.cust_pref_vendor;
      BEGIN
        iOrder := 0;
        rcnt := 0;
        FOR c1 IN cc1 LOOP
          blnFound := FALSE;
          iFoundIdx := -1;
          FOR j IN 1 .. rcnt LOOP
            IF r(j).prod_id = c1.prod_id AND r(j).cpv = c1.cust_pref_vendor THEN
              blnFound := TRUE;
              EXIT;
            END IF;
          END LOOP;
          IF NOT blnFound THEN
                  rcnt := rcnt + 1;
            r(rcnt).prod_id := c1.prod_id;
            r(rcnt).cpv := c1.cust_pref_vendor;
            r(rcnt).prod_cnt := iOrder;
            iOrder := iOrder + 1;
            IF c1.prod_id = i_prod_id AND c1.cust_pref_vendor = i_cpv THEN
              iFoundIdx := iOrder;
              EXIT;
            END IF;
          END IF;
        END LOOP;

        RETURN iFoundIdx;
     END f_loc_sort;

  ---------------------------------------------------------------------

   FUNCTION f_get_dmd_repl_4swp
      (i_srcloc           IN replenlst.dest_loc%TYPE)
   RETURN NUMBER IS
     rtcount NUMBER;
   BEGIN
     SELECT count(*) INTO rtcount FROM replenlst
     WHERE (nvl(inv_dest_loc,dest_loc) = i_srcloc or SRC_LOC = i_srcloc)
     AND (type = 'DMD' OR (type = 'BLK') AND NVL(drop_qty,0) <> 0);

     return rtcount;
   EXCEPTION
     WHEN OTHERS THEN
       rtcount := 1;
       return rtcount;
   END f_get_dmd_repl_4swp;

   FUNCTION f_get_ndm_repl_4swp(i_loc_src_dest IN replenlst.dest_loc%TYPE)
   RETURN NUMBER IS
       v_count NUMBER;
   BEGIN
       SELECT count(*) INTO v_count FROM replenlst
       WHERE (dest_loc = i_loc_src_dest or inv_dest_loc = i_loc_src_dest or SRC_LOC= i_loc_src_dest)
             AND type = 'NDM' 
             AND status not in('NEW','PRE');
       return v_count;
   EXCEPTION
       WHEN OTHERS THEN
            v_count := 1;
            return v_count;
   END f_get_ndm_repl_4swp;

   FUNCTION f_get_ndm_pre_new_repl_4swp(i_loc_src_dest IN replenlst.dest_loc%TYPE)
   RETURN NUMBER IS
       v_count NUMBER;
   BEGIN
       SELECT count(*) INTO v_count FROM replenlst
       WHERE (dest_loc = i_loc_src_dest or inv_dest_loc = i_loc_src_dest or SRC_LOC= i_loc_src_dest)
             AND type = 'NDM' 
             AND status in('NEW','PRE');
       return v_count;
   EXCEPTION
       WHEN OTHERS THEN
            v_count := -1;
            return v_count;
   END f_get_ndm_pre_new_repl_4swp;

   FUNCTION f_get_inv_hold_4swp(i_loc_src_dest IN replenlst.dest_loc%TYPE)
   RETURN NUMBER IS
       v_count NUMBER;
   BEGIN
       SELECT count(*) INTO v_count FROM inv
       WHERE plogi_loc = i_loc_src_dest AND status='HLD';
       return v_count;
   EXCEPTION
       WHEN OTHERS THEN
            v_count := 1;
            return v_count;
   END f_get_inv_hold_4swp;

   FUNCTION f_check_ndm_pre_repl_4swp(i_loc_src_dest IN replenlst.dest_loc%TYPE)
   RETURN NUMBER IS
      out_status         NUMBER;
      tot_qoh            NUMBER;
      tot_qty_planned    NUMBER;
      tot_qty_alloc      NUMBER;
      tot_qty_dest_repl  NUMBER;
      tot_qty_src_repl   NUMBER;
   BEGIN  
      out_status:=0;
     
      select nvl(sum(qoh),0) , nvl(sum(qty_planned),0) ,nvl(sum(qty_alloc),0)
      INTO tot_qoh, tot_qty_planned, tot_qty_alloc
      from inv where plogi_loc= i_loc_src_dest;
      
      select nvl(sum(qty),0) 
      INTO tot_qty_dest_repl 
      from replenlst where nvl(inv_dest_loc,dest_loc)= i_loc_src_dest AND type = 'NDM' AND status in( 'NEW','PRE');
      
      select nvl(sum(qty),0)
      INTO tot_qty_src_repl 
      from replenlst where src_loc= i_loc_src_dest AND type = 'NDM' AND status in( 'NEW','PRE');
      
      IF (tot_qty_planned>0 AND tot_qty_planned<> tot_qty_dest_repl) OR 
         (tot_qty_alloc>0 AND tot_qty_alloc<> tot_qty_src_repl) THEN
         out_status:=1;
      END IF;
      return out_status;
      EXCEPTION
          WHEN OTHERS THEN
               out_status := 1;
               return out_status;
   END f_check_ndm_pre_repl_4swp;   
  ---------------------------------------------------------------------

   PROCEDURE  p_del_cc(i_logi_loc      IN      cc.logi_loc%TYPE,
           i_phys_loc      IN      cc.phys_loc%TYPE,
                       i_prod_id       IN      cc.prod_id%TYPE,
                       i_cpv           IN      cc.cust_pref_vendor%TYPE,
                       i_trans_typ     IN      trans.trans_type%TYPE DEFAULT 'CAD')
   IS
     lv_fname              VARCHAR2(50)  := 'p_del_cc';
     SKIP_REST       EXCEPTION;
   BEGIN
          
  BEGIN
  -- Delete from cc first.
    DELETE cc
     WHERE prod_id = i_prod_id
       AND cust_pref_vendor = i_cpv
       AND logi_loc = i_logi_loc;

    IF SQL%FOUND THEN
               INSERT INTO trans (trans_id,               trans_type,
                                     trans_date,             prod_id,
                                     cust_pref_vendor,       user_id,
                                     dest_loc,               pallet_id)
                         VALUES     (trans_id_seq.NEXTVAL,   'CCT',
                                     SYSDATE,                i_prod_id,
                                     i_cpv,       user,
                                     i_phys_loc,             i_logi_loc);
    END IF;
  END;
  -- Here we need to cancel the cycle count
  -- having CYC and ready to be adjusted.
  -- Reset the adj_flag in cc_edit table.
  BEGIN
    UPDATE trans
             SET adj_flag = 'N'
           WHERE pallet_id  = i_logi_loc
    AND prod_id = i_prod_id
    AND cust_pref_vendor = i_cpv
             AND trans_type = 'CYC'
             AND adj_flag   = 'Y';

    IF SQL%FOUND = FALSE THEN
       RAISE SKIP_REST;
    END IF;
  END;
  BEGIN
    UPDATE cc_edit
    SET adj_flag = 'N'
    WHERE logi_loc = i_logi_loc
    AND prod_id = i_prod_id
    AND cust_pref_vendor = i_cpv
    AND adj_flag = 'Y';

    IF SQL%FOUND = FALSE THEN
       RAISE SKIP_REST;
    END IF;
  END;

        -- Insert a CAR/CAD transaction to record this.
  -- CAR (cancel adjustment due to repl)
  -- CAD (cancel adjustment)
  BEGIN
           INSERT INTO trans (trans_id,               trans_type,
                              trans_date,             prod_id,
                              cust_pref_vendor,       user_id,
                              dest_loc,               pallet_id)
              VALUES         (trans_id_seq.NEXTVAL,   i_trans_typ,
                              SYSDATE,                i_prod_id,
                              i_cpv,          user,
                              i_phys_loc,        i_logi_loc);
     IF SQL%FOUND = FALSE THEN
    RAISE SKIP_REST;
     END IF;
  END;
--  COMMIT;
   EXCEPTION
  WHEN SKIP_REST THEN
               pl_log.ins_msg('WARN',lv_fname,
                                    'TABLE=cc_edit KEY=['
                                    ||i_logi_loc ||'],['
                                    ||i_phys_loc||']'
                                    ||' ACTION=UPDATE REASON='
                                    ||'Record doesn''t update in cc_edit/trans '
                                    ||'for input pallet id ['
                                    ||i_logi_loc||']' 
                                    ,NULL,SQLCODE);
   END p_del_cc;


---------------------------------------------------------------------------
-- Function:
--    f_is_corporate_user
--
-- Description:
--    This function returns TRUE if the user is a Corporate user
--    otherwise FALSE is returned.
--
-- Parameters:
--    i_user_id    - User to check.
--
-- Exceptions raised:
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Called by:  (list not complete)
--    - Form mu1sa.fmb
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    10/22/07 prpbcb   Created
--    01/11/16 skam7488 Modified the logic to determine the corporate user.  
---------------------------------------------------------------------------
FUNCTION f_is_corporate_user(i_user_id  IN usr.user_id%TYPE)
RETURN BOOLEAN
IS
   l_object_name   VARCHAR2(61);
   l_message       VARCHAR2(256);    -- Message buffer
   l_is_corp_usr   VARCHAR2(1);

   l_return_value  BOOLEAN;

BEGIN
   SELECT NVL(sr.corp_usr_flg,'N') INTO l_is_corp_usr
   FROM   SWMS_ROLE sr, USR u
   WHERE  u.user_id = i_user_id
   AND    sr.role_name = u.role_name;

   IF ( l_is_corp_usr = 'Y' ) THEN
      l_return_value := TRUE;
   ELSE
      l_return_value := FALSE;
   END IF;

   RETURN(l_return_value);

EXCEPTION
   WHEN NO_DATA_FOUND THEN
      l_return_value := FALSE;
      RETURN(l_return_value);

   WHEN OTHERS THEN
      l_object_name := gl_pkg_name || '.f_is_corporate_user';
      l_message := l_object_name
                   || ':  Failed to determine if corporate user.';
      pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                           SQLCODE, SQLERRM);
      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                              l_object_name || ': ' || SQLERRM);
      l_return_value := FALSE;
      RETURN(l_return_value);

END f_is_corporate_user;


---------------------------------------------------------------------------
-- Procedure:
--    safe_to_delete_user
--
-- Description:
--    This procedure determines if it is OK to delete a user from the
--    USR table.
--
--    A user cannot be deleted from the USR table if the user exists
--    in the SOS_USR_CONFIG table.  The user needs to be deleted
--    from SOS_USR_CONFIG first.
--
-- Parameters:
--    i_user_id               - User to check.
--    o_ok_to_delete_user_bln - TRUE if it is OK to delete the user
--                              FALSE otherwise.
--    o_msg                   - Reason why the user cannot be deleted.
--                              It is populated when o_ok_to_delete_user_bln
--                              is set to FALSE.
--
-- Exceptions raised:
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Called by:  (list not complete)
--    - Form mu1sa.fmb
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    05/20/08 prpbcb   Created
---------------------------------------------------------------------------
PROCEDURE safe_to_delete_user
               (i_user_id                IN  usr.user_id%TYPE,
                o_ok_to_delete_user_bln  OUT BOOLEAN,
                o_msg                    OUT VARCHAR2)
IS
   l_dummy                  VARCHAR2(1); -- Work area
   l_object_name            VARCHAR2(61);
   e_user_in_sos_config     EXCEPTION;

BEGIN
   --
   -- Initialization
   --
   o_ok_to_delete_user_bln := TRUE;

   --
   -- See if the user is in the SOS_USR_CONFIG table and if so then
   -- the user needs to be deleted from SOS_USR_CONFIG first.
   --
   BEGIN
      SELECT 'x'
        INTO l_dummy
        FROM sos_usr_config su
       WHERE su.user_id = REPLACE(i_user_id, 'OPS$');

      --
      -- If this point reached then the user is in the SOS_USR_CONFIG table.
      -- The user needs to be deleted from SOS first.
      --
      o_ok_to_delete_user_bln := FALSE;
      o_msg := 'Delete user ' || REPLACE(i_user_id, 'OPS$')
               || ' from SOS first.';
   EXCEPTION
      WHEN NO_DATA_FOUND THEN
         NULL;   -- User not in SOS_USR_CONFIG table.
   END;
EXCEPTION
   WHEN OTHERS THEN
      l_object_name := gl_pkg_name || '.safe_to_delete_user';
      pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name,
                 'Error  i_user_id[' || i_user_id || ']',
                 SQLCODE, SQLERRM,
                 'MAINTENANCE', gl_pkg_name);
      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error, 
                              l_object_name || ': ' || SQLERRM);
END safe_to_delete_user;


---------------------------------------------------------------------------
-- Function:
--    f_boolean_text
--
-- Description:
--    This function returns the string TRUE or FALSE for a boolean.
--
-- Parameters:
--    i_boolean - Boolean value
--  
-- Return Values:
--    'TRUE'  - When boolean is TRUE.
--    'FALSE' - When boolean is FALSE.
--
-- Exceptions raised:
--    pl_exc.e_database_error  - Got an oracle error.
-- 
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    07/10/08 prpbcb   Created.
--                      This was/is a private function in other packages.
--                      Added it here so it can be used by any package.
---------------------------------------------------------------------------
FUNCTION f_boolean_text(i_boolean IN BOOLEAN)
RETURN VARCHAR2
IS
   l_message       VARCHAR2(256);    -- Message buffer
   l_object_name   VARCHAR2(61);
BEGIN
   IF (i_boolean) THEN
      RETURN('TRUE');
   ELSE
      RETURN('FALSE');
   END IF;
EXCEPTION
   WHEN OTHERS THEN
      l_object_name := gl_pkg_name || '.f_boolean_text';
      l_message :=  l_object_name || '(i_boolean)';
      pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                     SQLCODE, SQLERRM,
                     pl_rcv_open_po_types.ct_application_function,
                     gl_pkg_name);
      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                              l_object_name || ': ' || SQLERRM);
END f_boolean_text;

--------------------------------------------------------------------------------
-- Function:
--    Check_upc
--
-- Description:
--    This function validates the UPC and also checks whether UPC need to be collected or Not.
--
-- Parameters:
--    i_prod_id        - Product Id for which the UPC data collect to be checked.
--    i_rec_id         - Po number.
--    i_func_name      - Describes the name of the option
--                       i.e "PUTAWAY" = 1, "RECEIVING" = 2, "CYCLE_CNT" = 3, "WAREHOUSE" = 4
--
-- Returns:
--   upc_comp_flag     Function will return one of the following values either N - Collect upc Data or Y - Not collect Data
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- --------------------------------------------------------
--    02/01/17 sont9212 Sunil Ontipalli, authored
--------------------------------------------------------------------------------

FUNCTION Check_upc         ( i_prod_id              IN  pm.prod_id%type
                            ,i_rec_id               IN  upc_info.rec_id%type
                            ,i_func_name            IN  PLS_INTEGER
                             )
RETURN VARCHAR2 IS
  This_Function   CONSTANT  VARCHAR2(30)  := 'Check_UPC';

  This_Message              VARCHAR2(2000);
    l_upc_scan_function       VARCHAR2(1);
    l_upc_validation          VARCHAR2(1);
    l_count                   NUMBER;
    l_upc_comp_flag           VARCHAR2(1);
    l_internal_upc            pm.internal_upc%type;
    l_external_upc            pm.external_upc%type;
    l_category                pm.category%type;
    l_split_trk               pm.split_trk%type;
    
  BEGIN               
    
     ---Getting the sys par for the UPC scan function--- 

      BEGIN
      
         SELECT config_flag_val 
           INTO l_upc_scan_function 
           FROM sys_config
          WHERE config_flag_name = 'UPC_SCAN_FUNCTION'; 
          
      EXCEPTION
       WHEN OTHERS THEN
         l_upc_scan_function := 'N';
      END;    
      
      
     ---Getting the sys par for the UPC Validation--- 

      BEGIN
      
         SELECT config_flag_val 
           INTO l_upc_validation
           FROM sys_config
          WHERE config_flag_name = 'UPC_VALIDATION';
          
      EXCEPTION
       WHEN OTHERS THEN
         l_upc_validation := 'N';
      END;  
      
 /*
     Check to see if UPC data has been collected  and sent up to AS400
     for the item on the purchase order    
 */
 
      BEGIN
      
       SELECT count(*)  
         INTO l_count
         FROM upc_info 
        WHERE prod_id  = i_prod_id
          AND rec_id   = i_rec_id;
          
      EXCEPTION
       WHEN OTHERS THEN
         l_count := 0;
      END;  
      
      IF l_count <> 0 THEN
      
       ---Data is already collected---
        l_upc_comp_flag := 'Y';
        
      ELSE        
       ---Data is not collected---
       
         BEGIN
           
            SELECT internal_upc, external_upc, category, split_trk
              INTO l_internal_upc, l_external_upc, l_category, l_split_trk
              FROM pm
             WHERE prod_id = i_prod_id;
             
         EXCEPTION
          WHEN OTHERS THEN
             This_Message := 'Error occured getting the data from pm for validating UPC for Prod Id:'||i_Prod_Id;
             PL_Sysco_Msg.Msg_Out( i_Level       => PL_Sysco_Msg.MsgLvl_Error
                          , i_ModuleName  => This_Function
                          , i_Message     => This_Message
                          , i_Category    => PL_RCV_Open_PO_Types.CT_Application_Function
                          , i_Add_DB_Msg  => FALSE
                          , i_ProgramName => $$PLSQL_UNIT
                          );
                          
              l_upc_comp_flag := 'Y';   
           This_Message := 'Check UPC Returns back the config_flag:'||l_upc_comp_flag;
                    
           PL_Log.Ins_Msg( 'INFO', This_Function, This_Message, null, null
                          , PL_RCV_Open_PO_Types.CT_Application_Function, 'PL_COMMON', 'N' ); 
             RETURN l_upc_comp_flag;                            
         END;

         --- UPC_Validation flag is Yes, and upc_scan_function is set to W then should not collect UPC as per functionality---
         IF l_upc_validation = 'Y' and (l_upc_scan_function = 'W')
         THEN
          l_upc_comp_flag := 'Y';
          RETURN l_upc_comp_flag;
         END IF;         

     IF SUBSTR(l_category, 1,2) = 11 THEN
         
         ---UPC data not required for category 11 as per the functionality---
         
           l_upc_comp_flag := 'Y';
           
         ELSE
         
       IF (PL_VALIDATIONS.validate_upc(l_external_upc) AND (l_split_trk = 'N' OR PL_VALIDATIONS.validate_upc(l_internal_upc)) ) THEN
            
                 IF ( l_upc_validation = 'N' ) 
                   THEN
                  l_upc_comp_flag := 'Y';
             ELSE 
                  l_upc_comp_flag := 'N';
             END IF; 
           ELSE        
                l_upc_comp_flag := 'N';                  
           END IF;
          
       END IF;
      
      END IF;  
      
      RETURN l_upc_comp_flag; 
      
  EXCEPTION

    WHEN OTHERS THEN
      -- Got some oracle error.  Log a message and raise an exception.
    IF sqlcode = -6502 THEN -- ORA-06502: numeric or value error
      RETURN 'N'; 
    ELSE
      This_Message := 'Unknown error occured when checking UPC for prod_id:'||i_Prod_Id;
      PL_Log.Ins_Msg( 'ERROR', This_Function, This_Message, sqlerrm, sqlcode
                          , PL_RCV_Open_PO_Types.CT_Application_Function, 'PL_COMMON', 'N' ); 
    
      Raise_Application_Error( PL_Exc.CT_Database_Error
                             ,    $$PLSQL_UNIT || '.'
                               || This_Function  || '-'
                               || PL_RCV_Open_PO_Types.CT_Application_Function || ': '
                               || This_Message
                             ); 
    END IF;
  END Check_upc;


-----------------------------------------------------------------------
--  Function:
--    f_is_internal_production_po
--
--  Description:
--    This function returns true if the erm_id passed in is set up to 
--    auto open the specialty PO. 'ENABLE_FINISH_GOODS' syspar must be
--    turned on and the erm.source_id must match the syspar 'SPECIALTY_VENDOR_ID'
--
--  Parameters:
--    i_erm_id IN erm.erm_id%TYPE
--
--  RETURN VALUES:
--    TRUE ENABLE_FINISH_GOODS syspar is 'Y' and if 
--          erm.source_id is equal to SPECIALTY_VENDOR_ID syspar and 
--    FALSE otherwise
--  
--  Date       Designer  Comments
--  --------   --------  -------------------------------------------
--  06/25/18   mpha8134  Created
--  01/21/19   mpha8134  Change from checking the special vendor syspar to 
--                       checking if the ERM.SOURCE_ID exists in the SWMS.VENDOR_PIT_ZONE table.
---------------------------------------------------------------------
FUNCTION f_is_internal_production_po(i_erm_id IN erm.erm_id%TYPE)
RETURN BOOLEAN IS

    l_count pls_integer;

BEGIN

    SELECT count(erm_id)
    INTO l_count
    FROM erm
    WHERE pl_common.f_get_syspar('ENABLE_FINISH_GOODS', 'N') = 'Y'
    and erm_id = i_erm_id
    and source_id in (select distinct vendor_id from vendor_pit_zone);

    IF l_count > 0 THEN
      RETURN TRUE;
    ELSE
      RETURN FALSE;
    END IF;

  EXCEPTION
    WHEN OTHERS THEN
      pl_log.ins_msg (
        'FATAL', 
        'f_is_internal_production_po',
        'Error when checking if the ERM.SOURCE_ID exists in the VENDOR_PIT_ZONE table. ERM_ID[' || i_erm_id || ']',
        SQLCODE, 
        SQLERRM,
        'RECEIVING',
        'pl_common');

      RETURN FALSE;

END f_is_internal_production_po;


---------------------------------------------------------------------
--  FUNCTION:
--    f_is_raw_material_route
--
--  DESCRIPTION:
--    This function check to see if the route_no, passed as a parameter,
--    is a "raw material" route.
--  PARAMETERS:
--    i_route_no IN route.route_no%TYPE
--  
--  Date      Designer  Comments  
--  --------  --------  ---------------------------------------------
--  01/30/19  mpha8134  Created for Jira 707
---------------------------------------------------------------------
FUNCTION f_is_raw_material_route(i_route_no IN route.route_no%TYPE)
RETURN CHAR IS

  l_count pls_integer := 0;

BEGIN

  
    SELECT count(g.cust_id)
  INTO l_count
  FROM ordm o, getmeat_cust_setup g
  WHERE pl_common.f_get_syspar('ENABLE_FINISH_GOODS', 'N') = 'Y'
  AND o.cust_id = g.cust_id
  AND o.route_no  = i_route_no;

  

  IF l_count > 0 THEN
    return 'Y';
  ELSE
    return 'N';
  END IF;

EXCEPTION WHEN OTHERS THEN
  pl_log.ins_msg (
        'FATAL', 
        'f_is_raw_material_route',
        'Error when checking if route[' || i_route_no || '] is a raw material route.',
        SQLCODE, 
        SQLERRM,
        'ORDER PROCESSING',
        'pl_common');

  return 'N';

END f_is_raw_material_route;

---------------------------------------------------------------------
--  FUNCTION:
--    f_cdk_pallet_transfer
--
--  DESCRIPTION:
--    This function is to transfer the cross dock pallet out of cross dock location 
-- 
--  PARAMETERS:
--    
--  
--  Date      Designer  Comments  
--  --------  --------  ---------------------------------------------
--  10/24/19  sban3548  Created for Jira-opcof-2614
---------------------------------------------------------------------
FUNCTION f_cdk_pallet_transfer(i_parent_child_flag IN NUMBER, 
								i_pallet_id IN inv.logi_loc%TYPE, 
								i_from_loc  IN inv.plogi_loc%TYPE,
								i_to_loc	IN inv.plogi_loc%TYPE)
RETURN NUMBER IS 
		PRAGMA AUTONOMOUS_TRANSACTION;
		l_status 	NUMBER := 0;
		l_count 	NUMBER := 0;
		l_rule_id 	NUMBER := 0;
		l_parent_pallet_id 	inv.parent_pallet_id%TYPE;
		l_return_status		NUMBER := 0;

		CURSOR c_child_pallets_cdk(p_parent_pallet_id VARCHAR2) IS
		SELECT logi_loc,prod_id, plogi_loc 
		  FROM inv
		 WHERE parent_pallet_id = p_parent_pallet_id;
		
BEGIN
		/* If the pallet is a child and transferred to NON-CDK location, other than rule 4 */
        IF i_parent_child_flag = 1 THEN 
            BEGIN		  
			--- check zone rule for to_loc and if it's transferred to zone rule 4 ?
      			    pl_log.ins_msg('INFO', 'f_cdk_pallet_transfer', 
								'Starting UPDATE of Pallet: ' || i_pallet_id 
								|| ' From: ' || i_from_loc || ' To: ' || i_to_loc, 
								SQLCODE, SQLERRM, 'INV ADMIN', 'pl_common', 'N');

 			     UPDATE swms.inv
				    SET plogi_loc = i_to_loc,
						parent_pallet_id = NULL, 
						status = 'AVL' 
				  WHERE plogi_loc = TRIM(i_from_loc)
					AND logi_loc = TRIM(i_pallet_id) 
					AND status = 'CDK';
                
				 DELETE swms.cross_dock_data_collect
				  WHERE pallet_id= i_pallet_id;
                				
				SELECT parent_pallet_id 
				  INTO l_parent_pallet_id  
				  FROM inv 
				 WHERE logi_loc = i_pallet_id;

			    SELECT COUNT(*) 
				  INTO l_count 
				  FROM inv 
				 WHERE parent_pallet_id = l_parent_pallet_id;
				
				 IF l_count=0 THEN 				-- If there is no child for this parent 
					DELETE swms.cross_dock_pallet_xref
					 WHERE parent_pallet_id = l_parent_pallet_id;		
					  
					DELETE swms.cross_dock_data_collect
					 WHERE parent_pallet_id = l_parent_pallet_id;
				 END IF;
				
				COMMIT;
				pl_log.ins_msg('INFO', 
						'f_cdk_pallet_transfer', 
						'Child Pallet: ' || i_pallet_id 
						|| ' has been transferred From: ' || i_from_loc 
						|| ' To:' || i_to_loc, 
						SQLCODE, SQLERRM, 
						'INV ADMIN', 'pl_common', 'N');

              EXCEPTION
                  WHEN NO_DATA_FOUND THEN
                        COMMIT;
						l_return_status := 0;
                  WHEN OTHERS THEN
                      ROLLBACK;
                      l_return_status := SQLCODE;
       			      pl_log.ins_msg('FATAL', 'f_cdk_pallet_transfer', 
								'Unable to transfer Pallet: ' || i_pallet_id 
								|| ' From: ' || i_from_loc || ' To: ' || i_to_loc, 
								SQLCODE, SQLERRM, 'INV ADMIN', 'pl_common', 'N');
              END;
		ELSIF i_parent_child_flag = 2 THEN 			-- If the scanned pallet is a parent LP 
            BEGIN
				FOR crec IN c_child_pallets_cdk (i_pallet_id)
				LOOP 
					 UPDATE swms.inv
						SET plogi_loc = i_to_loc 
					  WHERE plogi_loc = i_from_loc
						AND logi_loc = crec.logi_loc;

				END LOOP;
				
				COMMIT;				
			    pl_log.ins_msg('INFO', 'f_cdk_pallet_transfer', 
								'Parent Pallet: ' || i_pallet_id 
								|| ' has been transferred From:' || i_from_loc || ' To:' || i_to_loc, 
								SQLCODE, SQLERRM, 'INV ADMIN', 'pl_common', 'N');

			EXCEPTION
			  WHEN NO_DATA_FOUND THEN
                  COMMIT;
				  l_return_status := 0;
			  WHEN OTHERS THEN
                  ROLLBACK;
				  l_return_status := SQLCODE;
                  pl_log.ins_msg('FATAL', 'f_cdk_pallet_transfer', 
								'Unable to transfer Pallet: ' || i_pallet_id 
								|| ' From: ' || i_from_loc || ' To: ' || i_to_loc, 
								SQLCODE, SQLERRM, 'INV ADMIN', 'pl_common', 'N');

            END;
		END IF;
		
		RETURN l_return_status;	

EXCEPTION WHEN OTHERS THEN
			    pl_log.ins_msg('FATAL', 'f_cdk_pallet_transfer', 
								'Unable to transfer Pallet: ' || i_pallet_id 
								|| ' From: ' || i_from_loc || ' To: ' || i_to_loc, 
								SQLCODE, SQLERRM, 'INV ADMIN', 'pl_common', 'N');
		l_return_status := SQLCODE;
		RETURN l_return_status;	
END f_cdk_pallet_transfer;


-----------------------------------------------------------------------
-- Function:
--    get_company_no
--
-- Description:
--    This function returns the company number selected from the
--    MAINTENANCE table trimmed of any leading or trailing spaces.
--    If not found then NULL is returned.
--
--    It is expected the value in the MAINTENANCE table will have
--    this format:
--       <opco number>:<opco name>    Example: 024:Chicago
--
-- Parameters:
--    None
--
-- Return Values:
--    The company trimmed of spaces.  If not found then
--    NULL is returned.
--
-- Exceptions raised:
--    pl_exc.e_database_error     -  Oracle error occurred.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    02/06/18 bben0445 Brian Bent
--                      Created by copying and modifing f_get_company_no
--                      in pl_lm_sel.sql
---------------------------------------------------------------------
FUNCTION get_company_no
RETURN VARCHAR2
IS
   l_company_no  maintenance.attribute_value%TYPE;

   CURSOR c_company_no
   IS
   SELECT TRIM(SUBSTR(attribute_value,
                         1, INSTR(attribute_value, ':') -1))
     FROM maintenance
    WHERE component = 'COMPANY'
      AND attribute = 'MACHINE';
BEGIN
   OPEN c_company_no;
   FETCH c_company_no INTO l_company_no;
   IF (c_company_no%NOTFOUND) THEN
      l_company_no := NULL;
   END IF;
   CLOSE c_company_no;

   RETURN (l_company_no);

EXCEPTION
   WHEN OTHERS THEN
      pl_log.ins_msg
             (i_msg_type         => pl_log.ct_fatal_msg,
              i_procedure_name   => 'get_company_no',
              i_msg_text         => 'Failed to get the company number',
              i_msg_no           => SQLCODE,
              i_sql_err_msg      => SQLERRM,
              i_application_func => 'MAINTENANCE',
              i_program_name     => gl_pkg_name,
              i_msg_alert        => 'N');

      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                              'get_company_no' || ': ' || SQLERRM);
END get_company_no;

---------------------------------------------------------------------------
-- Function:
--    f_zone_rule
--
-- Description:
--    This function returns rule id using zone id. 
--
-- Parameters:
--    None
--
-- Exceptions raised:
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Called by:  (list not complete)
--    - form ml1sbn
--    - Form ml1sb1
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    03/18/22 kchi7065  Created OPCOF-4062
---------------------------------------------------------------------------
FUNCTION f_zone_rule(i_zone_id zone.zone_id%TYPE)
   RETURN zone.rule_id%type
IS
   l_object_name   VARCHAR2(30) := 'f_zone_rule';
   l_return_status zone.rule_id%type;
   CURSOR chk_zone (i_zone_id zone.zone_id%TYPE) IS
     SELECT rule_id
     FROM zone
     WHERE zone_id = i_zone_id;

BEGIN

  l_return_status := NULL;
  OPEN chk_zone (i_zone_id);
  FETCH chk_zone INTO l_return_status;
  IF ( chk_zone%notfound ) THEN

      l_return_status := NULL;

  END IF;
  CLOSE chk_zone;

  RETURN l_return_status;

EXCEPTION 
  WHEN OTHERS THEN
    pl_log.ins_msg('FATAL', 
                   l_object_name,
                   'Error in looking zone id '|| i_zone_id, 
                   SQLCODE, 
                   SQLERRM, 
                   'INV ADMIN', 
                   'pl_common', 
                   'N');
    l_return_status := SQLCODE;
    RETURN l_return_status;	
  END f_zone_rule; 

-----------------------------------------------------------------------
-- Function:
--    get_user_equip_id
--
-- Description:
--    This function returns the users equiment id.
--    If not found or an error the null is returned.
--
-- Parameters:
--    i_user_id
--
-- Return Values:
--    The user equipment id or NULL
--
-- Exceptions raised:
--    None.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    10/12/18 bben0445 Brian Bent
--                      Created.
---------------------------------------------------------------------
FUNCTION get_user_equip_id(i_user_id  IN  usr.user_id%TYPE)
RETURN VARCHAR2
IS
   l_object_name   VARCHAR2(30) := 'get_user_equip_id';

   l_equip_id   equip.equip_id%TYPE := NULL;
   l_rec_count  PLS_INTEGER;
BEGIN
   SELECT MAX(e.equip_id), COUNT(*) rec_count
     INTO l_equip_id, l_rec_count
     FROM equip e
    WHERE UPPER(REPLACE(e.user_id, 'OPS$', NULL)) = UPPER(REPLACE(i_user_id, 'OPS$', NULL));       -- Check without OPS$ and what the check upper case

   --
   -- Check if for whatever reason the user is assigned more than one equipment
   --
   IF (l_rec_count > 1) THEN
      pl_log.ins_msg
               (i_msg_type         => pl_log.ct_fatal_msg,
                i_procedure_name   => l_object_name,
                i_msg_text         =>
                      'TABLE=equip  ACTION=SELECT'
                   || '  KEY=[' || i_user_id || ']' || '(i_user_id)'
                   || '  MESSAGE="User for some reason assigned to '
                   || TO_CHAR(l_rec_count) || ' pieces of equipment.'
                   || '  Will use equipment id ' || l_equip_id,
                i_msg_no           => SQLCODE,
                i_sql_err_msg      => SQLERRM,
                i_application_func => 'YM',
                i_program_name     => gl_pkg_name,
                i_msg_alert        => 'N');
   END IF;

   RETURN (l_equip_id);

EXCEPTION
   WHEN OTHERS THEN
      pl_log.ins_msg
               (i_msg_type         => pl_log.ct_fatal_msg,
                i_procedure_name   => l_object_name,
                i_msg_text         =>
                      'TABLE=equip  ACTION=SELECT'
                   || '  KEY=[' || i_user_id || ']' || '(i_user_id)'
                   || '  MESSAGE="User not found.  Returning null."',
                i_msg_no           => SQLCODE,
                i_sql_err_msg      => SQLERRM,
                i_application_func => 'YM',
                i_program_name     => gl_pkg_name,
                i_msg_alert        => 'N');

   RETURN (NULL);    -- Return null
END get_user_equip_id;

END pl_common;
/
